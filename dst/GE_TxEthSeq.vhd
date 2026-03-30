---------------------------------------------------------------------------
--
--  Ethernet Tx	Main Sequencer
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
---------------------------------------------------------------------------
--	100MBit:	24.07.2006-fb
--	Startet mit 	1x FB55
--	dann folgt 	   34x 5555
--	dann folgt  	5x D5D5
--	dann jeweils 	5x BbBb
--	Am Schluss 		1x FDF7
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
--  27.03.2010-FB	ECAT Tx-Irq-Timer-Reload auch wenn kein Pkt gesendet wird
--	30.03.2010 QFU TX-Buffers exchanged so that they match the IRQ numbers
--	12.08.2011-le	add signal to switch between Ethernet and Ethercat when
--						g_EtherCAT is enabled.
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	13.02.2018-le	- add a tx busy input
--------------------------------------------------------------------------------
--$Rev:: 4748                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-02-13 10:51:22 +0100 (Di., 13 Feb 2018)                         $
--------------------------------------------------------------------------------

entity GE_TxEthSeq is 
    generic (
        g_EtherCAT	    : in  natural range 0 to 1 := 0;
		g_Tunnel	    : in  natural range 0 to 1 := 0
    );
	port (
		i_Q62_5			: IN  std_logic;
		i_Q62_5en		: IN  std_logic := '1';
		
		i_ENETnECAT		: in std_logic := '0'; -- switch between Ethernet and Ethercat when g_EtherCAT is enabled

		i_ECAT_Start_L	: IN  std_logic := '1';
		i_ECAT_Start_H	: IN  std_logic := '1'; 
		o_ECAT_Rst		: OUT std_logic;
		
		i_Mac2Tun_En	: in std_logic := '0';
		o_Mac2Tun_Req	: out std_logic;
		i_TX_Busy		: in std_logic := '0';
		
		o_TxCharIsK 	: Out std_logic_vector( 1 downto 0);
		o_TxData 		: Out std_logic_vector(15 downto 0);
		o_EthRun		: OUT std_logic;
		o_CrcRun		: OUT std_logic;
		o_Odd			: OUT std_logic;
		
		i_MEM_RdData	: in  std_logic_vector(31 downto 0);		
		o_MEM_WrData	: out std_logic_vector(31 downto 0);		
		o_MEM_Adr		: out std_logic_vector(10 downto 0);		
		o_MEM_WR		: out std_logic_vector( 3 downto 0);
		o_WrBufTgl		: out std_logic;		
		o_TxIRQs		: out std_logic_vector(7 downto 0)	-- to PPC
	    );
end;    

architecture impl of GE_TxEthSeq is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
    type sGE_EthTxSeq is (
    	sIdle,sNoHd1,sNoHd2,
    	sEthHd1,sEthHd2,sEthHd3,sWait,
    	sWend_L,sWend_H,
    	sEvenEnd,sOddEnd_L,sOddEnd_H,sOddEnd2,
    	sEnd6,sEnd7,sEnd8,sEnd9,
    	sIFG
    );

	signal MyMac 		: std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_FB";				
	signal NoBroadcast	: std_logic := L;
	signal IgnoreOvrrun	: std_logic := L;

	signal GE_EthTxSeq	: sGE_EthTxSeq := sIdle;		
	signal EthCnt		: std_logic_vector(11 downto 0) := x"000";		
	signal EthRun		: std_logic := L;
	signal CrcRun		: std_logic := L;

--------------------------------------------------------------------------------
	type 	tIRQ_Cmp is array(0 to 1) of  std_logic_vector(9 downto 0);
	signal 	IRQ_CNT		: tIRQ_Cmp := (others => (others=>L));
	signal 	TxIRQ		: std_logic_vector(1 downto 0)	:= "00";-- IRQ to PPC
	signal 	IRQ			: std_logic	:= L;						-- IRQ to PPC

--------------------------------------------------------------------------------
	signal TxData		: std_logic_vector(15 downto 0) := x"0000";

	signal MEM_Adr		: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	signal MEM_Adr_P1	: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	signal MEM_WrData	: std_logic_vector(31 downto 0) := x"00000000";	-- data to dp-ram		
	signal MEM_RdData	: std_logic_vector(31 downto 0) := x"00000000";	-- data from dp-ram	
	signal MEM_WR		: std_logic_vector( 3 downto 0) := "0000";		-- byte-writes 

    signal WrBufTgl		: std_logic := '0';								-- TxBuf toggle
    signal ECAT_Rst		: std_logic := '0';								-- TxBuf toggle

	constant Cfg_TxStat 	: std_logic_vector(11 downto 0) := x"000";
	constant Cfg_IrqTim		: std_logic_vector(11 downto 0) := x"002";
	constant Cfg_TxOkCnt	: std_logic_vector(11 downto 0) := x"004";
	constant Cfg_TxErrCnt	: std_logic_vector(11 downto 0) := x"005";
	constant Cfg_TxOvrCnt	: std_logic_vector(11 downto 0) := x"006";
	constant Cfg_TxBuf		: std_logic_vector(11 downto 0) := x"010";	-- +1 first = 010
--	constant Cfg_TxStat1	: std_logic_vector(11 downto 0) := x"800";
--	constant Cfg_TxBuf1		: std_logic_vector(11 downto 0) := x"810";

	signal Mac2Tun_En : std_logic := L;
	signal OddTun : std_logic := L;
--------------------------------------------------------------------------------	
begin -- of architecture GE_TxEthSeq    
--------------------------------------------------------------------------------

--	outputs --------------------------------------------------------------------
    o_EthRun 	<= EthRun;
    o_CrcRun 	<= CrcRun;
	o_Odd		<= OddTun when g_Tunnel=1 else EthCnt(0);

	o_MEM_WrData 	<= MEM_WrData;		
      MEM_RdData 	<= i_MEM_RdData after 2 ns;
	o_MEM_WR		<= MEM_WR;
	o_WrBufTgl		<= WrBufTgl;  
	o_ECAT_Rst		<= ECAT_Rst;

	-- MEM_Adr(11) is not used and will be eliminated! (only fill-bit for x"000")
	o_MEM_Adr 	<= MEM_Adr(10 downto 0);

	o_TxIRQs <= IRQ & TxIRQ & "00000";

    ----------------------------------------------------------------------------
	-- IRQ-Timers
    ----------------------------------------------------------------------------
    --  2 Slot-Timer
    --  10 Bit each
    -- 160 ns resoltuion @100MBit EtherCAT speed
    -- 2^10 * 160ns = 163.84us max 
    
	process (i_Q62_5) begin 
		if rising_edge(i_Q62_5) then
			if (i_Q62_5en=H) then
				TxIRQ(1 downto 0) <= "00";
				
				if ((GE_EthTxSeq = sNoHd2) 
				or  (GE_EthTxSeq = sEthHd2)) then   
					if (WrBufTgl = H) then
						--low word, TX-Buffer 1
						IRQ_CNT(CONV_INTEGER(1)) <= Mem_RdData( 9 downto 0);
					else
				   --high word, TX-Buffer 0
						IRQ_CNT(CONV_INTEGER(0)) <= Mem_RdData(25 downto 16);
					end if;
				else	
				    for i in 0 to 1 loop
						if (IRQ_CNT(i) > "0000000000") then
							IRQ_CNT(i) <= IRQ_CNT(i) - 1;
						end if;	
						if (IRQ_CNT(i) = "0000000001") then
							TxIRQ(i) <= H;
						end if;          
					end loop;
				end if;
			end if;
		end if;	
    end process;

--------------------------------------------------------------------------------
--	GE_EthTxSequencer
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			if (i_Q62_5en=H) then
				if (g_Tunnel=1) then
					o_Mac2Tun_Req <= L;
					Mac2Tun_En <= i_Mac2Tun_En;
				end if;
				OddTun <= L;
				IRQ 		<= L;
--    				o_TxData 	<= x"BC50";
				o_TxData 	<= x"0000";
				o_TxCharIsK <= "11";   
   				case (GE_EthTxSeq) is 
				
				when sIdle =>	---	Idle, wait to PktStart -------------------------
        			EthRun 	 <= L;
        			CrcRun 	 <= L;
        			-- EthCAT toggle timer restart
        			ECAT_Rst <= Mem_RdData(29); 
					if (g_Tunnel=1) then
						EthRun <= L;
						o_TxData <= (others => L);
						if (Mem_RdData(28)=H and i_TX_Busy=L) then
							WrBufTgl <= L;
							GE_EthTxSeq <= sEthHd1;
						elsif (Mem_RdData(12)=H and i_TX_Busy=L) then
							WrBufTgl <= H;
							GE_EthTxSeq <= sEthHd1;
						else
							GE_EthTxSeq <= sIdle;
						end if;
						if ((Mem_RdData(28) = L) 
						or  (Mem_RdData(12) = L)) then
							-- set TxBuffer empty IRQ
							IRQ <= H;
						end if;
					else
						if (g_EtherCAT=1 and i_ENETnECAT=L) then
							-- fix tx-timed ethercat 
							if (i_ECAT_Start_L = H) then 
								WrBufTgl <= L;
								if (Mem_RdData(28)=H and i_TX_Busy=L) then
									o_TxData 	<= x"5555";
									o_TxCharIsK <= "00";   
									GE_EthTxSeq <= sEthHd1;
									EthRun <= H;
								else  
									GE_EthTxSeq <= sNoHd1;
								end if;
							end if;
									
							if (i_ECAT_Start_H = H) then 	
								WrBufTgl <= H;
								if (Mem_RdData(12)=H and i_TX_Busy=L) then
									o_TxData 	<= x"5555";
									o_TxCharIsK <= "00";   
									GE_EthTxSeq <= sEthHd1;
									EthRun <= H;
								else
									GE_EthTxSeq <= sNoHd1;
								end if;
							end if;	
												
						else
							-- normal ethernet
							if (Mem_RdData(28)=H and i_TX_Busy=L) then
								WrBufTgl <= L;
								o_TxData 	<= x"5555";
								o_TxCharIsK <= "00";   
								GE_EthTxSeq <= sEthHd1;
								EthRun <= H;
							else if (Mem_RdData(12)=H and i_TX_Busy=L) then
									WrBufTgl <= H;
									o_TxData 	<= x"5555";
									o_TxCharIsK <= "00";   
									GE_EthTxSeq <= sEthHd1;
									EthRun <= H;
								else
								end if;
							end if;	            	
						end if;
						
						if ((Mem_RdData(28) = L) 
						or  (Mem_RdData(12) = L)) then
							-- set TxBuffer empty IRQ
							IRQ <= H;
						end if;
					end if;
					
				when sNoHd1 =>	--- no pkt, reload tx-irq-timer only ---------------
   					GE_EthTxSeq <= sNoHd2;
				when sNoHd2 =>	--- no pkt, reload tx-irq-timer only ---------------
   					GE_EthTxSeq <= sIdle;
				
				when sEthHd1 =>	--- EthPreamble ------------------------------------	
					if (WrBufTgl = H) then
						EthCnt <= Mem_RdData(11 downto 0);
					else
						EthCnt <= Mem_RdData(27 downto 16);
					end if;
        		    o_TxData 	<= x"5555";
    				o_TxCharIsK <= "00";   
					GE_EthTxSeq <= sEthHd2;
					if (g_Tunnel=1) then
						o_TxData <= (others => L);
					end if;
					
				when sEthHd2 =>	--- EthPreamble ------------------------------------
        		    o_TxData 	<= x"5555";
    				o_TxCharIsK <= "00";   
					GE_EthTxSeq <= sEthHd3;
					if (g_Tunnel=1) then
						o_TxData <= (others => L);
					end if;
					
				when sEthHd3 =>	--- EthPreamble ------------------------------------	
					-- send placeholder for 32-Bit CRC (made by MGT)
					EthCnt <= EthCnt + 4;    		                                    
					
					o_TxData 	<= x"55D5";
					o_TxCharIsK <= "00";   
					GE_EthTxSeq <= sWend_L;
					if (g_Tunnel=1) then
						GE_EthTxSeq <= sWait;
						o_TxData <= (others => L);
					end if;
				
				when sWait =>
					o_TxData 	<= x"DEAD";
					o_TxCharIsK <= "00";
					GE_EthTxSeq <= sWait;
					o_Mac2Tun_Req <= H;
					if (i_Mac2Tun_En=H and Mac2Tun_En=L) then
						-- wait on slot start.
						o_TxData 	<= "0000" & EthCnt; 
						GE_EthTxSeq <= sWend_L;	
						EthRun <= H;
					end if;
					
				when sWend_L =>		--- send til EthPkt-End ------------------------
					o_TxData 	<= Mem_RdData(31 downto 16);
					o_TxCharIsK <= "00";
					if (g_Tunnel=1) then
						if (EthCnt = 5) then
							OddTun <= H;
						end if;
						if (EthCnt>4) then
							CrcRun <= H;
						else	
							CrcRun <= L;
						end if;
					else
						if (EthCnt > 5) then
							CrcRun <= H;
						else	
							CrcRun <= L;
						end if;
					end if;
					
					if (EthCnt >= 4) then
						GE_EthTxSeq <= sWend_H;
					else 
						if (EthCnt = 3) then	
							GE_EthTxSeq <= sOddEnd_H;
						else	
							GE_EthTxSeq <= sEvenEnd;
						end if;
					end if;
					EthCnt <= EthCnt - 2;
					
				when sWend_H =>		--- send til EthPkt-End ------------------------
					o_TxData 	<= Mem_RdData(15 downto 0);
    				o_TxCharIsK <= "00";
					if (g_Tunnel=1) then
						if (EthCnt = 5) then
							OddTun <= H;
						end if;
						if (EthCnt>4) then
							CrcRun <= H;
						else	
							CrcRun <= L;
						end if;
					else
						if (EthCnt <= 5) then
							CrcRun <= L;
						end if;
					end if;
        		
					if (EthCnt >= 4) then
    					GE_EthTxSeq <= sWend_L;
    				else 
    					if (EthCnt = 3) then	
	    					GE_EthTxSeq <= sOddEnd_L;
	    				else	   
	    					GE_EthTxSeq <= sEvenEnd;
	    				end if;	
    				end if;
					
					EthCnt <= EthCnt - 2; 
        		
				when sEvenEnd =>		--- Even-Byte End --------------------------
--	        		    o_TxData 	<= x"FDF7";
        		    o_TxData 	<= x"0000";
    				o_TxCharIsK <= "11";   
					GE_EthTxSeq <= sEnd6;
        		    
				when sOddEnd_L =>		--- Odd-Byte End ---------------------------
					o_TxData 	<= Mem_RdData( 7 downto  0) & x"FD";
    				o_TxCharIsK <= "01";   
					GE_EthTxSeq <= sOddEnd2;
        		
				when sOddEnd_H =>		--- Odd-Byte End ---------------------------
					o_TxData 	<= Mem_RdData(23 downto 16) & x"FD";
    				o_TxCharIsK <= "01";   
					GE_EthTxSeq <= sOddEnd2;
        		
				when sOddEnd2 =>		--- Extended-Byte End ----------------------
					o_TxData 	<= x"F7F7";
    				o_TxCharIsK <= "11";   
					GE_EthTxSeq <= sEnd6;
        		
				when sEnd6 =>		--- End ----------------------------------------
					if (g_Tunnel=1 and Mac2Tun_En=L) then
						-- slot was too short, do not clear TxStatus and update Ok Counter  
						GE_EthTxSeq <= sIFG;
					else
						GE_EthTxSeq <= sEnd7;
					end if;
				when sEnd7 =>
					GE_EthTxSeq <= sEnd8;
				when sEnd8 =>
					GE_EthTxSeq <= sEnd9;
				when sEnd9 => 
					-- InterFramGab = 96ns = 12*8ns = 6x16Bit
					--	1	2	3	4	5	6
					-- 	e6	e7	e8	e9	ifg	idle
					GE_EthTxSeq <= sIFG;
        		
				when sIFG =>
   					GE_EthTxSeq <= sIdle;
										
					when others => null;
				end case;
			end if;
		end if;	
    end process;

--------------------------------------------------------------------------------
--	GE_MemorySequencer
--------------------------------------------------------------------------------
--	synchron part of MemorySequencer
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			if (i_Q62_5en=H) then
				if (GE_EthTxSeq = sWend_L) then 
    				-- da die Daten 1 Clk später aus dem Ram kommen, 
    				-- muss schon bei Wned_L die Adr+1 gemacht werden 
        		   	MEM_Adr_P1 <= MEM_Adr + 1;
        		else
        		   	MEM_Adr_P1 <= MEM_Adr;
				end if;
			end if;
		end if;	
    end process;

--	asynchron part of MemorySequencer
	process (GE_EthTxSeq,WrBufTgl,MEM_Adr_P1,MEM_RdData) begin
		MEM_Adr 	<= Cfg_TxStat;
		MEM_WR 		<= "0000";
        MEM_WrData 	<= x"00000000";

		case (GE_EthTxSeq) is 		
		when sIdle 		---	Idle, wait to PktStart -------------------------	
		   | sNoHd2 =>	--- no pkt, reload tx-timer only -------------------
			-- point to TxStatus
			MEM_Adr <= Cfg_TxStat;

		when sNoHd1		--- no pkt, reload tx-timer only -------------------
		   | sEthHd1 =>	--- EthPreamble ------------------------------------	
			-- read Tx-IRQ_Timer init-value
			MEM_Adr <= Cfg_IrqTim;

		when sEthHd3
			| sWait =>		--- EthPreamble --------------------------------
			-- read next TxBuffer
			MEM_Adr <= "00" & WrBufTgl & Cfg_TxBuf(8 downto 0);
			
		when sWend_L =>		--- Wait til Pkt-End ---------------------------
			-- hold last adr 
            MEM_Adr <= MEM_Adr_P1;
            
		when sWend_H =>		--- Wait til Pkt-End ---------------------------
        	MEM_Adr <= MEM_Adr_P1;

		when sEnd6 =>		--- End ----------------------------------------
			-- read Tx Ok Counter 
        	MEM_Adr 	<= Cfg_TxOkCnt;
                                                
		when sEnd7 =>		--- End ----------------------------------------
			-- Ok/Err Counter + 1
        	MEM_Adr 	<= Cfg_TxOkCnt;
            MEM_WrData 	<= MEM_RdData + 1;
			MEM_WR 		<= "1111"; 

		when sEnd8 =>		--- End ----------------------------------------
			-- point to TxStatus and clear it
			MEM_Adr <= Cfg_TxStat;
	        MEM_WrData 	<= x"00000000";
            if (WrBufTgl = H) then
				MEM_WR <= "0011"; 
            else 
				MEM_WR <= "1100"; 
            end if;
			
		when others => null;
		end case;
end process;
	  
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------