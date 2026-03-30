---------------------------------------------------------------------------
--
--  Ethernet Rx	Main Sequencer
--
---------------------------------------------------------------------------
--
--  project     : Ethernet MiniMac
--  programmer  : F:Baschung, INDEL AG
--  date        : 10.07.2006
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- Receive Ethernet-Frames 
--		
--		- if Flag NoBroadcast  = 0:	accept MacBroadcast
--		- if Flag AllBroadcast = 0:	accept Arp Broadcast only 
--
--		so if you need no Broadcasts at all,	set NoBroadcast = 1
--		or if you need other broadcasts, 		set AllBroadcast = 1
--                                                        
--	==>	!! Diese Bits werden nur nach dem Empfang eines RxPkt übernommen !!
---------------------------------------------------------------------------
                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--library INDEL_pkg;
--use INDEL_pkg.INDEL_pkg.all;

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
--	10.07.2006-FB	erste Version
--	05.02.2008-le	add svn keywords
--	17.03.2010-FB	EtherCAT Buffer-Toggle implemented
--                  MacAdr-compare at and of pkt (get act MyMac from CfgArea)
--	10.09.2010-le	change rx irq to level triggerd, cleared when status=0
--	12.08.2011-le	add signal to switch between Ethernet and Ethercat when
--						g_EtherCAT is enabled.      
--	24.05.2012-fb	Multicast x1-xx-xx-xx-xx-xx added
--	30.05.2012-fb	Enable Multicast funkt schon beim ersten Frame
--	16.06.2013-le	add Cfg_NoMacCheck: 0 = check MacAddr ; 1 = handle all packages
--	13.01.2014-le	add support for more then two rx buffers
--	21.12.2017-le	adjust sensitivity list
--	19.03.2019-le	too long packages destroy the config area 0..0x40
--					add a new error for too long packages (>0x600)
--	29.03.2019-le	too long packages destroy the config area 0..0x40
--					add a new error for too long packages (max size of buffer 0x800-0x40)
--------------------------------------------------------------------------------
--$Rev:: 5269                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-03-29 15:35:59 +0100 (Fr., 29 MÃ¤r 2019)                        $
--------------------------------------------------------------------------------

entity GE_RxEthSeq is 
    generic (
        g_EtherCAT	    : in  natural range 0 to 1 := 0;
		g_NoBufferPair	: in  positive range 1 to 4 := 1
    );
	port (
		i_Q62_5			: IN  std_logic;
		i_Q62_5en		: IN  std_logic := '1';

		i_ENETnECAT		: in std_logic := '1'; -- switch between Ethernet and Ethercat when g_EtherCAT is enabled
		i_ECAT_Toggle	: IN  std_logic := '0';
		
		i_MulitBufEn	: in std_logic := '0'; -- enable more then two rx buffers

		i_RxCharIsK 	: IN  std_logic_vector( 1 downto 0);
		i_RxData 		: IN  std_logic_vector(15 downto 0);
		i_RxCrcErr		: IN  std_logic;
		o_EthError		: OUT std_logic;				-- EthFraming Error 
		o_EthRun			: OUT std_logic;

		i_MEM_RdData	: in  std_logic_vector(31 downto 0);		
		o_MEM_WrData	: out std_logic_vector(31 downto 0);		
		o_MEM_Adr		: out std_logic_vector(11 downto 0);		
		o_MEM_WR			: out std_logic_vector(3 downto 0);
		o_WrBufTgl		: out std_logic;		
		o_IRQ				: out std_logic_vector(2*g_NoBufferPair-1 downto 0)
    );
end;    

architecture impl of GE_RxEthSeq is   
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
    type sGE_EthRxSeq is (
    	sIdle,sEthHd1,--sEthHd2,sEthHd3,
    	sDestMac1,sDestMac2,sDestMac3,
    	sSrcMac1,sSrcMac2,sSrcMac3,
    	sCkhBcType,
    	sWend_L,sWend_H,
    	sChkCrc,sChkMac2,sChkMac3,
    	sOkEnd1 ,sOkEnd2,sOkEnd3,sEnd4,
    	sMacErr1,sMacErr2,sMacErr3,
    	sOvrRun,
    	sErrEnd1,sErrEnd2,sErrEnd3,
		sLngErr1,sLngErr2,sLngErr3,
    	sRdCfg1,sRdCfg2,
    	sEnd9
    );
    
    constant H : std_logic := '1';
    constant L : std_logic := '0'; 

	signal Dest_Mac 		: std_logic_vector(47 downto 0) := x"00_00_00_00_00_00";				
	alias	Multicast		: std_logic is Dest_Mac(40); -- x1-xx-xx-xx-xx-xx
	signal Cfg_NoBroadcast	: std_logic := L;
	signal Cfg_AllBroadcast	: std_logic := L;
	signal Cfg_EnMulticast	: std_logic := L;
	signal Cfg_NoMacCheck	: std_logic := L;

	signal GE_EthRxSeq	: sGE_EthRxSeq := sIdle;		
	signal EthCnt		: std_logic_vector(11 downto 0) := x"000";		
	signal EthError		: std_logic := L;
	signal MacError		: std_logic := L;
	signal EthRun		: std_logic := L;

	signal Broadcast	: std_logic := L;
	signal LowWord		: std_logic := L;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	signal MEM_Adr		: std_logic_vector(15 downto 0) := x"0000";		-- act dp-ram adr		
	signal MEM_Adr_P1	: std_logic_vector(15 downto 0) := x"0000";		-- act dp-ram adr		
	signal MEM_WrData	: std_logic_vector(31 downto 0) := x"00000000";	-- data to dp-ram		
	signal MEM_RdData	: std_logic_vector(31 downto 0) := x"00000000";	-- data from dp-ram	
	signal MEM_WR		: std_logic_vector( 3 downto 0) := "0000";		-- byte-writes 

	signal WrBufTgl		: std_logic := '0';								-- RxBuf toggle
	signal IRQ			: std_logic_vector(2*g_NoBufferPair-1 downto 0) := (others => L);		-- IRQ to PPC
	signal NoBufPair	: std_logic_vector(1 downto 0) := "00";
	signal overflow		: std_logic := '0';
	signal overflow_l	: std_logic := '0';	

	constant Cfg_RxStat 	: std_logic_vector(15 downto 0) := x"0000";
	constant Cfg_RxOkCnt	: std_logic_vector(15 downto 0) := x"0004";
	constant Cfg_MacErrCnt	: std_logic_vector(15 downto 0) := x"0005";
	constant Cfg_RxOvrCnt	: std_logic_vector(15 downto 0) := x"0006";
	constant Cfg_RxErrCnt	: std_logic_vector(15 downto 0) := x"0007";
	constant Cfg_RxLngErrCnt: std_logic_vector(15 downto 0) := x"0008";
	constant Cfg_Mac		: std_logic_vector(15 downto 0) := x"000C";	-- 00C & 00D
	constant Cfg_RxBuf		: std_logic_vector(15 downto 0) := x"0010";	-- +1 first = 010
--	constant Cfg_RxStat1	: std_logic_vector(15 downto 0) := x"0800";
--	constant Cfg_RxBuf1		: std_logic_vector(15 downto 0) := x"0810";

--------------------------------------------------------------------------------	
begin -- of architecture GE_RxEthSeq    
--------------------------------------------------------------------------------

--	outputs --------------------------------------------------------------------
    o_EthRun 	<= EthRun;
   	o_EthError  <= EthError;   	   	


	o_MEM_WrData 	<= MEM_WrData;		
      MEM_RdData 	<= i_MEM_RdData after 10 ps;
	o_MEM_WR		<= MEM_WR;
	o_WrBufTgl		<= WrBufTgl;

	o_MEM_Adr 	<= MEM_Adr(11 downto 0);

	o_IRQ 	<= IRQ;

--------------------------------------------------------------------------------
--	GE_EthRxSequencer
--------------------------------------------------------------------------------
--	IFG:	96ns@GBit, 960ns100MBit
--	== max 6 States between two pakets  
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			if (i_Q62_5en=H) then
	        	IRQ	<= (others => L);
				overflow_l <= overflow;
   				case (GE_EthRxSeq) is 
				
				when sIdle =>	--- wait to 5555 55D5 EthPreamble ------------------
					EthError <= L;
					MacError <= L;
        			EthRun 	 <= L;
					overflow_l <= L;
            	
    				if (g_EtherCAT=1 and i_ENETnECAT=L) then 
    					WrBufTgl <= i_ECAT_Toggle;	
    				end if;
    				
					if (i_RxData = x"55D5" and i_RxCharIsK = "00") then
						if (((WrBufTgl = H) and (MEM_RdData(12) = '0'))
						or  ((WrBufTgl = L) and (MEM_RdData(28) = '0'))) then
    						GE_EthRxSeq <= sDestMac1;
						else
    						GE_EthRxSeq <= sOvrRun;
						end if;
					end if;
								
				when sDestMac1 =>	---	save Mac to Dest_Mac ----------------
					-- save Dest-Mac (test it later)
					Dest_Mac(47 downto 32) <= i_RxData;
            	
					Broadcast <= L; 
        		    if (i_RxData = x"FFFF") then  	-- if Broadcast (ARP) then..
						Broadcast <= H;
        		    	if (Cfg_NoBroadcast = H) then
							MacError <= H;
        		    	end if;
    				else 
	    		    	--if (i_RxData /= Dest_Mac(47 downto 32)) then
						--	MacError <= H;
	    				--end if;	 
    				end if;	
					GE_EthRxSeq <= sDestMac2;
        		
				when sDestMac2 =>	---	test if Mac = Dest_Mac ----------------
					EthCnt <= x"000";	-- start here, because we also save the CRC    		
					-- save Dest-Mac (test it later)
					Dest_Mac(31 downto 16) <= i_RxData;
            	
					if (Broadcast = H) then
	    		        if (i_RxData /= x"FFFF") then
							MacError <= H;
	    				end if;	 
					else
	    		      	--if (i_RxData /= Dest_Mac(31 downto 16)) then
						--	MacError <= H;
	    				--end if;	 
					end if;
					GE_EthRxSeq <= sDestMac3;
    				
				when sDestMac3 =>	---	test if Mac = Dest_Mac ----------------
					EthCnt <= EthCnt + 2;
					-- save Dest-Mac (test it later)
					Dest_Mac(15 downto 0) <= i_RxData;
            	
					if (Broadcast = H) then
	    		        if (i_RxData /= x"FFFF") then
							MacError <= H;
	    				end if;	 
					else
	    		    	--if (i_RxData /= Dest_Mac(15 downto 0)) then
	    		        --	MacError <= H;
	    				--end if;	 
					end if;
					GE_EthRxSeq <= sSrcMac1;
        		
				when sSrcMac1 =>	--- Src Mac 1 ------------------------------
					EthCnt <= EthCnt + 2;
					GE_EthRxSeq <= sSrcMac2;
					
				when sSrcMac2 =>	--- Src Mac 2 ------------------------------
					EthCnt <= EthCnt + 2;
					GE_EthRxSeq <= sSrcMac3;
					
				when sSrcMac3 =>	--- Src Mac 3 ------------------------------
					EthCnt <= EthCnt + 2;
					GE_EthRxSeq <= sCkhBcType;
        		
				when sCkhBcType =>	--- test if ARP broadcast -------------------
					EthCnt <= EthCnt + 2;
					if (Broadcast = H) then
        		    	if (Cfg_AllBroadcast = L) then
							-- is this an ARP ?
				            if (i_RxData /= x"0806") then
				    			-- do we have to check for an EtherCat Ethertype?
				    			if ((g_EtherCAT=1 and i_ENETnECAT=L) and (i_RxData = X"88A4")) then
				    			--if (i_RxData = X"88A4") then
				    				MacError <= MacError;
				    			else
									MacError <= H;
								end if;
				    		end if;
						end if;      
					end if;	
					GE_EthRxSeq <= sWend_L;
					
				when sWend_L =>		--- Wait til UDP-End -----------------------
					-- wait till special charakter
					if (i_RxCharIsK = "00") then
    					GE_EthRxSeq <= sWend_H;
						EthCnt <= EthCnt + 2;
					else
        		    	EthRun <= L; -- End EthPkt
        		
						-- check if normal EthEnd 
	    		        if (i_RxCharIsK(1) = H) then
        					GE_EthRxSeq <= sChkCrc;
        		        else 
							EthCnt <= EthCnt + 1;
        					GE_EthRxSeq <= sChkCrc;
				        end if;    
	    		    end if;				
					
				when sWend_H =>		--- Wait til UDP-End -----------------------
					-- wait till special charakter
					if (i_RxCharIsK = "00") then
						EthCnt <= EthCnt + 2;
    					GE_EthRxSeq <= sWend_L;
					else
        		    	EthRun <= L; -- End EthPkt
        		
						-- check if normal EthEnd 
	    		        if (i_RxCharIsK(1) = H) then
        					GE_EthRxSeq <= sChkCrc;
        		        else 
							EthCnt <= EthCnt + 1;
        					GE_EthRxSeq <= sChkCrc;
				        end if;    
	    		    end if;
					
				when sChkCrc =>
					-- check if CRC ok and MacOk
        			if ((i_RxCrcErr = H) OR (EthError = H)) then
	    				-- CheckSum Error
						GE_EthRxSeq <= sErrEnd1;          
	    			else
						if (overflow_l=H) then
							GE_EthRxSeq <= sLngErr1;
	    				elsif (MacError = H) then
        					GE_EthRxSeq <= sMacErr1;
	    				else 
	    					if (Broadcast = H) then 
	    						-- broadcast, no Mac-check 
	        					GE_EthRxSeq <= sOkEnd1;
	    		    		else                          
	    		    			-- we have to check the mac 
	        					GE_EthRxSeq <= sChkMac2;
	        				end if;	
    					end if;	
        			end if;
        		
				when sChkMac2 =>	--- check Dest-Mac -------------------------
					-- Cfg_NoBroadcast: 1 = no Broadcast al all
					Cfg_NoBroadcast  <= MEM_RdData(0);
					-- Cfg_AllBroadcast: 0 = Arp only ; 1 = All ; 0 = Arp only
        		    Cfg_AllBroadcast <= MEM_RdData(1);
					-- Cfg_EnMulticast: 0 = Multicat dis ; 1 = Multicat enabled
        		    Cfg_EnMulticast <= MEM_RdData(2);
        			-- Cfg_NoMacCheck: 0 = check MacAddr ; 1 = handle all packages
        			Cfg_NoMacCheck <= MEM_RdData(3);
					
    	    		if ((Cfg_NoMacCheck=L)
    	    		   and (Multicast = L)
    	    	       and (MEM_RdData(31 downto 16) /= Dest_Mac(15 downto 0))) then
    					GE_EthRxSeq <= sMacErr1;
    				else
						GE_EthRxSeq <= sChkMac3;
	    		    end if;
	    		    
				when sChkMac3 =>	--- check Dest-Mac -------------------------
    	    		if ((Cfg_NoMacCheck=L)
    	    		   and (((Multicast = L) and (MEM_RdData(31 downto 0) /= Dest_Mac(47 downto 16)))
    				   -- if Multicast, but not enabled
    				   or ((Multicast = H) and (Cfg_EnMulticast = L)))) then
	    				GE_EthRxSeq <= sMacErr1;    
    					GE_EthRxSeq <= sMacErr1;
					else
						GE_EthRxSeq <= sOkEnd2;
	    		    end if;
        		
				when sOkEnd1 =>
					GE_EthRxSeq <= sOkEnd2;
            	
				when sOkEnd2 =>
					if (g_EtherCAT=1 and i_ENETnECAT=L) then 
						if (WrBufTgl=L) then
							IRQ(0) <= H;
						else
							IRQ(1) <= H;
						end if;
					-- switch to next RxData Buffer
					--if (g_EtherCAT=0 or i_ENETnECAT=H) then
					else
						WrBufTgl <= not WrBufTgl;
						IRQ(conv_integer(NoBufPair & WrBufTgl)) <= H;
						if WrBufTgl=H then
							if ((NoBufPair=g_NoBufferPair-1))  then
								NoBufPair <= (others => L);
							else
								NoBufPair <= NoBufPair + 1;
							end if;
						end if;
					end if;
					GE_EthRxSeq <= sOkEnd3;
            	
				when sOkEnd3 =>		--- End ------------------------------------
					-- OkCnt+1
					-- we got the CfgBits already
					GE_EthRxSeq <= sEnd4;
				when sEnd4 =>	--- restart --------------------------------
					-- MemAdr to Status for idle
					GE_EthRxSeq <= sIdle;
        		
				when sMacErr1 =>	--- Error-End ------------------------------
					GE_EthRxSeq <= sMacErr2;
				when sMacErr2 =>
					GE_EthRxSeq <= sMacErr3;
				when sMacErr3 =>         
					-- MacErrCnr+1
					-- we got the CfgBits already
					GE_EthRxSeq <= sEnd4;
										
				when sOvrRun =>	--- Overrun ------------------------------------
					if (i_RxCharIsK /= "00") then
   						GE_EthRxSeq <= sErrEnd3;
					end if;
            	
				when sErrEnd1 =>	--- Error-End ------------------------------
					GE_EthRxSeq <= sErrEnd2;
				when sErrEnd2 =>
					GE_EthRxSeq <= sErrEnd3;
				when sErrEnd3 =>	--- End ------------------------------------
					-- ErrCnt+1 
					-- we miss the CfgBits, so go and read them...
					GE_EthRxSeq <= sRdCfg1;

				when sLngErr1 =>	--- Error-End ------------------------------
					GE_EthRxSeq <= sLngErr2;
				when sLngErr2 =>
   					GE_EthRxSeq <= sLngErr3;
				when sLngErr3 =>	--- End ------------------------------------
					-- ErrCnt+1 
					-- we miss the CfgBits, so go and read them...
					GE_EthRxSeq <= sRdCfg1;
            	
				when sRdCfg1 =>	--- read Config --------------------------------
					GE_EthRxSeq <= sRdCfg2;
				when sRdCfg2 =>	--- read Config --------------------------------
					-- Cfg_NoBroadcast: 1 = no Broadcast al all
					Cfg_NoBroadcast  <= MEM_RdData(0);
					-- Cfg_AllBroadcast: 0 = Arp only ; 1 = All ; 0 = Arp only
        		    Cfg_AllBroadcast <= MEM_RdData(1);
					-- Cfg_EnMulticast: 0 = Multicat dis ; 1 = Multicat enabled
        		    Cfg_EnMulticast <= MEM_RdData(2);
        			-- Cfg_NoMacCheck: 0 = check MacAddr ; 1 = handle all packages
        			Cfg_NoMacCheck <= MEM_RdData(3);
					
					-- MemAdr to Status for idle
					GE_EthRxSeq <= sIdle;
            	
					when others => null;
				end case;
				if ((i_MulitBufEn=L))  then
					NoBufPair <= (others => L);
				end if;
			end if;
		end if;	
    end process;

--------------------------------------------------------------------------------
--	EthRx MemorySequencer
--------------------------------------------------------------------------------
	process (GE_EthRxSeq) begin
   			LowWord <= L;
   			
    		if (GE_EthRxSeq = sDestMac2) 
    		or (GE_EthRxSeq = sSrcMac1) 
    		or (GE_EthRxSeq = sSrcMac3) 
    		or (GE_EthRxSeq = sWend_L) then  
    			LowWord <= H;
			end if;

	end process;
	
	overflow <= H when MEM_Adr_P1=x"1ff" else L;

--	synchron part of MemorySequencer
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			if (i_Q62_5en=H) then
    			if (LowWord = H and overflow=L) then  
	    			-- next memory-adr 
	        	   	MEM_Adr_P1 <= MEM_Adr + 1;
	        	else
	        	   	MEM_Adr_P1 <= MEM_Adr;
				end if;
			end if;
		end if;	
    end process;


--	asynchron part of MemorySequencer
	process (GE_EthRxSeq,WrBufTgl,i_RxData,MEM_Adr_P1,EthCnt,MEM_RdData,NoBufPair) begin
		MEM_Adr 	<= x"0000";
		MEM_WR 		<= "0000";
        MEM_WrData 	<= x"00000000";

		case (GE_EthRxSeq) is 
		
		when sEnd4
		   | sRdCfg2
		   | sIdle =>	--- Idle -------------------------------------------	
			-- read RxBuffer Satus
        	MEM_Adr <= Cfg_RxStat + NoBufPair;

--		when sEthHd2 =>	--- EthPreamble ------------------------------------	
--			-- read RxBuffer Satus
--       	MEM_Adr <= Cfg_RxStat;

--		when sEthHd3 =>	--- EthPreamble ------------------------------------	
			
		when sDestMac1 => ---	test if Mac = GinMac -----------------------
			-- select RxData Buffer 0/1
        	MEM_Adr <= "0000" & NoBufPair & WrBufTgl & (Cfg_RxBuf(8 downto 0));
			MEM_WrData(31 downto 16) <= i_RxData;
--			MEM_WR <= "1111"; 
			MEM_WR <= "1100"; 
			
		when sDestMac3
		   | sSrcMac2    
		   | sCkhBcType  
		   | sWend_H => ---	write to high word -----------------------------
			MEM_Adr <= MEM_Adr_P1;	
			MEM_WrData(31 downto 16) <= i_RxData;
			MEM_WR <= "1100"; 
			
		when sDestMac2 
		   | sSrcMac1   
		   | sSrcMac3   
		   | sWend_L =>	---	write to low word ------------------------------
			MEM_Adr <= MEM_Adr_P1;	
			MEM_WrData(15 downto 0) <= i_RxData;
			MEM_WR <= "0011"; 
						
		when sRdCfg1 
		   | sChkCrc =>		--- Chk CRC ---------------------------------------- 
        	MEM_Adr <= Cfg_Mac+1;
		
		when sChkMac2 =>	--- Chk MAC ----------------------------------------
        	MEM_Adr <= Cfg_Mac;


		when sOkEnd1 		--- Ok-End -----------------------------------------
		   | sChkMac3 =>    --- Chk MAC-----------------------------------------
			-- write RxBuffer Satus
        	MEM_Adr <= Cfg_RxStat + NoBufPair;
            MEM_WrData <=  x"1" & EthCnt & x"1" & EthCnt;
			
			if (WrBufTgl = H) then
				MEM_WR <= "0011";
			else
				MEM_WR <= "1100";
			end if;	

		when sOkEnd2 =>		--- Ok-End -------------------------------------
			-- write Rx Ok Counter
        	MEM_Adr <= Cfg_RxOkCnt;


		when sMacErr1 =>	--- MacError-End -------------------------------
			-- write RxBuffer Satus
        	MEM_Adr <= Cfg_RxStat  + NoBufPair;
            MEM_WrData <=  x"2" & EthCnt & x"2" & EthCnt;
			
			if (WrBufTgl = H) then
				MEM_WR <= "0011";
			else
				MEM_WR <= "1100";
			end if;	

		when sMacErr2 =>	--- MacError-End -------------------------------
			-- write Rx Err Counter
        	MEM_Adr <= Cfg_MacErrCnt;
                                                 
                                                 
		when sErrEnd1 =>	--- Error-End ----------------------------------
			-- write RxBuffer Satus
        	MEM_Adr <= Cfg_RxStat + NoBufPair;
            MEM_WrData <=  x"4" & EthCnt & x"4" & EthCnt;
			
			if (WrBufTgl = H) then
				MEM_WR <= "0011";
			else
				MEM_WR <= "1100";
			end if;	

		when sErrEnd2 =>	--- Error-End ----------------------------------
			-- write Rx Err Counter
        	MEM_Adr <= Cfg_RxErrCnt;
			
		when sLngErr1 =>	--- Error-End ----------------------------------
			-- write RxBuffer Satus
			MEM_Adr <= Cfg_RxStat + NoBufPair;
			MEM_WrData <=  x"8" & EthCnt & x"8" & EthCnt;
			
			if (WrBufTgl = H) then
				MEM_WR <= "0011";
			else
				MEM_WR <= "1100";
			end if;	

		when sLngErr2 =>	--- Error-End ----------------------------------
			-- write Rx Err Counter
        	MEM_Adr <= Cfg_RxLngErrCnt;

		when sOvrRun =>		---	Orverrun -----------------------------------
			-- write Rx Err Counter
        	MEM_Adr <= Cfg_RxOvrCnt;

		when sOkEnd3
		   | sMacErr3
		   | sErrEnd3
		   | sLngErr3 =>	--- End ----------------------------------------
        	MEM_Adr <= MEM_Adr_P1;
			-- Ok/Err Counter + 1
            MEM_WrData <= MEM_RdData + 1;
			MEM_WR <= "1111"; 

			when others => null;
		end case;
    end process;
	  
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
