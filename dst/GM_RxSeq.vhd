---------------------------------------------------------------------------
--
--  Master GIN-Frame Rx-Sequencer
--
---------------------------------------------------------------------------
--
--  project     : GIN_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- Generate and send Eth/IP/UDP/GIN-Frames
--
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   21.05.2004-FB	erste Version
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
---------------------------------------------------------------------------

--------------------------------------------------------------------------------
--$Rev:: 4697                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-22 13:46:20 +0100 (Fr., 22 Dez 2017)                         $
--------------------------------------------------------------------------------

entity GM_RxSeq is
	generic (
		g_Tunnel		: in natural range 0 to 1 := 0
	);
	port (
		i_Q125		 	: in  std_logic;
		i_Q62_5		 	: in  std_logic;
	
		i_MEM_RdData	: in  std_logic_vector(31 downto 0);		
		i_EthCRC		: in  std_logic_vector(31 downto 0);		
		o_MEM_WrData	: out std_logic_vector(31 downto 0);		
		o_MEM_Adr		: out std_logic_vector(10 downto 0);		
		o_MEM_WR		: out std_logic;
		o_GinError		: out std_logic;						-- GinFrame Error
		o_RxIRQs	 	: out std_logic_vector(15 downto 0);

		i_TxSlot_0		: in  std_logic;
		i_EthRun		: in  std_logic;                    	-- EthFrams is running
		i_GinRun		: in  std_logic;                    	-- GinFrams is running
		i_sUdpCsum		: in  std_logic;
		i_EthError		: in  std_logic;                        -- EthernetFrame Error
	
		i_RxCharIsK 	: in std_logic_vector( 1 downto 0);
		i_RxData 		: in std_logic_vector(15 downto 0);
		
		o_ExtDv			: out std_logic;
		o_ExtData		: out std_logic_vector(15 downto 0)
    );
end;    

architecture impl of GM_RxSeq is   

--------------------------------------------------------------------------------
    type sGM_RxSeq is (
    	sIdle,
    	sEth_HdCRC_H,sEth_HdCRC_L,
    	sGF_StartOfFrame,sGF_HdBlink,sGF_HdLen,sGF_Sfty_H,sGF_Sfty_L,sGF_HdCRC_L,sGF_HdCRC_H,
    	sGSF_StartOfFrame,sGSF_Cmd,sGSF_Adr_H,sGSF_Adr_L,sGSF_Len,sGSF_Int,sGSF_Sfty_H,sGSF_Sfty_L,sGSF_HdCRC_L,sGSF_HdCRC_H,
    	sGSF_StartOfData,sGSF_Dat_H,sGSF_Dat_L,sGSF_LastDat_H,sGSF_LastDat_L,
    	sGSF_Sla,sGSF_DatCRC_L,sGSF_DatCRC_H,
    	sErrEnd,sErrEnd2,sErrWaitEnd,
    	sTTEnd,sTTEnd1,
    	sOkEnd,sOkEnd1,sOkWaitEnd,sExtWaitEnd,sExtWaitEnd1
    );
	
	signal GM_RxSeq			: sGM_RxSeq := sIdle;		    				-- main sequencer

	signal MEM_Adr			: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	signal MEM_AdrZ1		: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	signal MEM_WrData		: std_logic_vector(31 downto 0) := x"00000000";	-- data to   dp-ram		
	signal MEM_RdData		: std_logic_vector(31 downto 0);				-- data from dp-ram		
	signal MEM_RdData_P1	: std_logic_vector(31 downto 0) := x"00000000";	-- data from dp-ram	
	signal MEM_WR			: std_logic := '0';								-- write 

	signal TransTime		: std_logic_vector(27 downto 0) := x"0000000";	-- transmission time TxSlot0-RxSLot0
	signal TransTimeRunning	: std_logic := '0';								-- TT is running
	signal RxSlot_0			: std_logic := '0';								-- TT is running

	signal TxData			: std_logic_vector(15 downto 0) := x"0000";		-- what we want to send	
	signal TxCharIsK		: std_logic_vector( 1 downto 0) :=  "00";
	                        	
	signal GinIdx			: std_logic_vector(15 downto 0) := x"0000";		-- GinFrame header flags 
	signal GSF_IRQ			: std_logic_vector(15 downto 0) := x"0000";		-- SubFrame header flags		
	signal ActSlot			: std_logic_vector( 5 downto 0) := "000000";	-- ActSlot Cnt
	signal NrOfGSF			: std_logic_vector( 4 downto 0) :=  "00000";	-- Nr of GinSubFrames		
	signal GSF_Len			: std_logic_vector(11 downto 0) := x"000";		-- Gin Cnt
	signal pGSF_Nr			: std_logic_vector( 4 downto 0) :=  "00000";	-- point to GSF-Nr
	signal ActGSF_Nr		: std_logic_vector( 3 downto 0) :=  "0000";		-- actual GSF-Nr
	signal WrDatBuf31_16	: std_logic_vector(15 downto 0) := x"0000";		-- latched wr-data		
	signal GinFrmOk			: std_logic := '0';								-- SubFrame was ok
	signal GSF_DatXchd		: std_logic := '0';								-- Write-Data have changed

--------------------------------------------------------------------------------
--	Configuration
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	DP-Ram Memory
--------------------------------------------------------------------------------	

--------------------------------------------------------------------------------
	constant CfgSlot		: std_logic_vector(11 downto 0) := x"000";
	constant CfgSlot_Act	: std_logic_vector(11 downto 0) := x"000";
	constant CfgSlot_Tim	: std_logic_vector(11 downto 0) := x"001";
	constant CfgSlot_Irq	: std_logic_vector(11 downto 0) := x"002";
	constant CfgSlot_GSF	: std_logic_vector(11 downto 0) := x"004";
	
	constant CfgNrOfSlot	: std_logic_vector(11 downto 0) := x"060";	-- 0180
	constant CfgActSlot		: std_logic_vector(11 downto 0) := x"061";  -- 0184
	constant CfgGF_TT		: std_logic_vector(11 downto 0) := x"064";  -- 0190
	constant CfgGF_Err		: std_logic_vector(11 downto 0) := x"066";  -- 0198
	constant CfgGF_Cnt		: std_logic_vector(11 downto 0) := x"067";  -- 019C
	
	constant CfgExtRxCnt	: std_logic_vector(11 downto 0) := x"068";	-- 01A0
	constant CfgExtCnt		: std_logic_vector(11 downto 0) := x"069";	-- 01A4

	constant CfgEthHd		: std_logic_vector(11 downto 0) := x"070";	-- 01C0

	constant CfgGSF_Hd		: std_logic_vector(11 downto 0) := x"080"; -- 0200
	constant CfgGSF_Hd_n	: std_logic_vector(11 downto 0) := x"082"; -- HighWord
	constant CfgGSF_Hd_p	: std_logic_vector(11 downto 0) := x"084"; -- pBaseAdr
	constant CfgGSF_DatXchd	: std_logic_vector(11 downto 0) := x"085"; -- GSF_Data Changed
	constant CfgGSF_Sla		: std_logic_vector(11 downto 0) := x"086"; -- GSF_SLA
	constant CfgGSF_Cnt		: std_logic_vector(11 downto 0) := x"087"; -- GSF_Counter
	-- 0180..0187	for GF-0
	-- 0180..01FF	for GF-0..GF-F



--------------------------------------------------------------------------------
--	offsets/values in GIN-Frame
--------------------------------------------------------------------------------
    constant UDP_LENGHT_OFS 	: integer := 22;
    constant UDP_CRC_OFS 		: integer := 23;
    constant GIN_HEADER_OFS 	: integer := 24;
    constant GIN_BLINK_OFS 		: integer := 25;
    constant GIN_SUBHEADER_OFS 	: integer := 28;
    
    -- GinSubFrm Counter
    constant GIN_SUBHD_CRC_OFS : integer :=  5;

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';
--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------
   	signal	EthCRC_1	: std_logic_vector (31 downto 0) := x"00000000"; 
    signal 	RxCRC_Equ_L	: std_logic := L;                    -- CheckSumm is ok
    signal 	RxCRC_Equ_H	: std_logic := L;                    -- CheckSumm is ok
	
	signal page8		: std_logic := L;
	signal page8RX		: std_logic := L;
	signal ExtFirst		: std_logic := L;
	signal ExtDv		: std_logic := L;

--------------------------------------------------------------------------------
begin -- of architecture GM_RxSeq    
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	Rx GinSubFrame IRQs
--------------------------------------------------------------------------------
	process (GM_RxSeq,GSF_IRQ,GinFrmOk) begin
		
		if (GinFrmOk = H) then
			-- GF was ok, so make a single IRQ-puls
			o_RxIRQs <= GSF_IRQ;
		else
			o_RxIRQs <= x"0000";
		end if;	    
		
	end process;	

--	outputs --------------------------------------------------------------------
	-- MEM_Adr(11) is not used and will be eliminated!
	o_MEM_Adr 	<=   MEM_Adr(10 downto 0);
	o_MEM_WrData 	<=   MEM_WrData;		
	  MEM_RdData 	<= i_MEM_RdData;
	o_MEM_Wr		<=   MEM_Wr;		


	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
    		if (i_TxSlot_0 = H) then
    			TransTimeRunning <= H; 
	    		TransTime <= x"0000000";
    		end if;
    		if (RxSlot_0 = H) then
    			TransTimeRunning <= L; 
    		end if;
			
			if (TransTimeRunning = H) then
	    		TransTime <= TransTime + 1;
    		end if;	
    			
		end if;
	end process;	
			        	
--******************************************************************************
--
--		GM Rx Sequencer
--
--******************************************************************************
	process (i_Q62_5) begin 

    	if rising_edge(i_Q62_5) then
			o_GinError 	<= L;
	   		GinFrmOk	<= L;
			RxSlot_0 	<= L;
			o_ExtDv <= L;
			o_ExtData <= (others => L);
	   		
			-- check if Ethernet Franing Error
          	if  ((i_EthError = H) 
          	and  (GM_RxSeq /= sErrEnd2)				-- already counting error
          	and  (GM_RxSeq /= sErrWaitEnd)) then	-- error already counted
            	GM_RxSeq <= sErrEnd;				-- count this error
          	else								
	    		case GM_RxSeq is  
	    		
                ----------------------------------------------------------------                        
				--	Gin Header
                ----------------------------------------------------------------                        
				when sIdle =>	--- wait for GF-Start of Header ----------------
	                GSF_IRQ <= x"0000";
					-- point to first GSF_Nr (Byte-Adr)
					pGSF_Nr <= CfgSlot_GSF(2 downto 0) & "00";
		                
	   				if	(i_GinRun = H) then
	    				GM_RxSeq <= sEth_HdCRC_L;
		    		end if;	       
	
				--------------------------------------------------------------------
				--	EthHeader Csum
				--------------------------------------------------------------------
				when sEth_HdCRC_L => 
					GM_RxSeq <= sGF_StartOfFrame;	    
				
				--------------------------------------------------------------------
				--	Start of GinHeader
	 			--------------------------------------------------------------------
				when sGF_StartOfFrame =>
					GM_RxSeq <= sGF_HdBlink;	    
				
				----------------------------------------------------------------
				--	GinHeader Blink
	 			----------------------------------------------------------------
				when sGF_HdBlink =>
					GinIdx <= i_RxData;
					ActSlot <= i_RxData(5 downto 0);
					if (i_RxData(3 downto 0) = 0) then
						RxSlot_0 <= H;
					end if;
					GM_RxSeq <= sGF_HdLen;	    
					
				----------------------------------------------------------------
				--	GinHeader NrOfGinFrames
				----------------------------------------------------------------
				when sGF_HdLen =>
					-- load NrOfGSF 
					NrOfGSF <= i_RxData(4 downto 0);
					GM_RxSeq <= sGF_Sfty_H;	    
					
				--------------------------------------------------------------------
				--	GinHeader Safety
				--------------------------------------------------------------------
				when sGF_Sfty_H => 
					GM_RxSeq <= sGF_Sfty_L;	    
				when sGF_Sfty_L => 
					GM_RxSeq <= sGF_HdCRC_H;	    
				
				----------------------------------------------------------------
				--	GinHeader CRC
				----------------------------------------------------------------
				--	Cfg points to SlotGinFrame #
				----------------------------------------------------------------
				when sGF_HdCRC_H =>	
                    if (RxCRC_Equ_H = H)	then
	    				GM_RxSeq <= sGF_HdCRC_L;
	    			else
	    				GM_RxSeq <= sErrEnd;
	    			end if;	
	    				
				when sGF_HdCRC_L =>
                    if (RxCRC_Equ_L = H)	then
	    				GM_RxSeq <= sGSF_StartOfFrame;
	    			else
	    				GM_RxSeq <= sErrEnd;
	    			end if;	

				----------------------------------------------------------------
				--	GinSubFrame Header
				----------------------------------------------------------------
				when sGSF_StartOfFrame =>	--- check if Start of Frame ----------------
    				GM_RxSeq <= sGSF_Cmd;
	                	
				when sGSF_Cmd =>	--- save Cmd -------------------------------
					if (g_Tunnel/=0) then
						ExtDv <=L;
						if (i_RxData(3 downto 0)="1000") then -- page 8
							page8 <= H;
							if (i_RxData(6 downto  4)="001") then -- cmd rd
								page8RX <= H;
							else
								page8RX <= L;
							end if;
						else
							page8RX <= L;
							page8 <= L;
						end if;
					end if;
					GM_RxSeq <= sGSF_Adr_H;
				when sGSF_Adr_H =>	--- save Adr ------------------------------- 
		            case (pGSF_Nr(1 downto 0)) is
		            when "00" => ActGSF_Nr <= MEM_RdData(27 downto 24);
		            when "01" => ActGSF_Nr <= MEM_RdData(19 downto 16);
		            when "10" => ActGSF_Nr <= MEM_RdData(11 downto  8);
		            when "11" => ActGSF_Nr <= MEM_RdData( 3 downto  0);
		            when others => null;
					end case;
					GM_RxSeq <= sGSF_Adr_L;
	                	
				when sGSF_Adr_L =>	--- save Adr -------------------------------
	    			GM_RxSeq <= sGSF_Len;
	                	
				when sGSF_Len =>	--- save Len -------------------------------
	                GSF_Len <= i_RxData(11 downto 0);
	    			GM_RxSeq <= sGSF_Int;
	                	
				when sGSF_Int =>	--- save Int -------------------------------
	                GSF_IRQ <= GSF_IRQ or i_RxData;
	    			GM_RxSeq <= sGSF_Sfty_H;
	    			
				--------------------------------------------------------------------
				--	GinSubHeader Safety
				--------------------------------------------------------------------
				when sGSF_Sfty_H => 
					GM_RxSeq <= sGSF_Sfty_L;	    
				when sGSF_Sfty_L => 
					GM_RxSeq <= sGSF_HdCRC_H;	    
				
				--------------------------------------------------------------------
				--	GinSubFrame Header Csum
				--------------------------------------------------------------------
				when sGSF_HdCRC_H =>
                    if (RxCRC_Equ_H = H) then 
		    			GM_RxSeq <= sGSF_HdCRC_L;
	    			else
    					GM_RxSeq <= sErrEnd;
    				end if;	

				when sGSF_HdCRC_L =>
--	       		    GSF_Len <= GSF_Len - 2;
                    if (RxCRC_Equ_L = H) then 
    					GM_RxSeq <= sGSF_StartOfData;
	    			else
    					GM_RxSeq <= sErrEnd;
    				end if;	
					
                ----------------------------------------------------------------                        
				--	Memory Data
                ----------------------------------------------------------------                        
				when sGSF_StartOfData => --- check if Start of Data ---------
	       		    GSF_Len <= GSF_Len - 4;		-- -2 so we can test to 00
					if (GSF_Len = x"000") then
						GM_RxSeq <= sGSF_Sla;
					else	
    					GM_RxSeq <= sGSF_Dat_H;
						if (g_Tunnel/=0) then
							ExtFirst <= H;
						end if;
					end if;

				when sGSF_Dat_H =>	--- Mem Data 31..16 ------------------------
	       		    GSF_Len <= GSF_Len - 2;
	    			WrDatBuf31_16 <= i_RxData;
					if (g_Tunnel/=0 and page8=H and page8RX=H) then
						ExtFirst <= L;
						o_ExtData <= i_RxData;
						o_ExtDv <= ExtDv;
						if (ExtFirst=H) then
							ExtDv <= not i_RxData(15);
							o_ExtDv <= not i_RxData(15);
						end if;
					end if;
					if (GSF_Len = x"000") then
						GM_RxSeq <= sGSF_LastDat_L;
					else	
    					 GM_RxSeq <= sGSF_Dat_L;
					end if;

				when sGSF_Dat_L =>	--- Mem Data 15..0 -------------------------
	       		    GSF_Len <= GSF_Len - 2;
					if (g_Tunnel/=0 and page8=H and page8RX=H) then
						o_ExtData <= i_RxData;
						o_ExtDv <= ExtDv;
					end if;
					if (GSF_Len = x"000") then
						GM_RxSeq <= sGSF_LastDat_H;
					else	
    					GM_RxSeq <= sGSF_Dat_H;
					end if;
			
				when sGSF_LastDat_H =>	--- Mem Data 31..16 --------------------
					if (g_Tunnel/=0 and page8=H and page8RX=H) then
						o_ExtData <= i_RxData;
						o_ExtDv <= ExtDv;
					end if;
					GM_RxSeq <= sGSF_Sla;
				when sGSF_LastDat_L =>	--- Mem Data 15..0 ---------------------
					if (g_Tunnel/=0 and page8=H and page8RX=H) then
						o_ExtData <= i_RxData;
						o_ExtDv <= ExtDv;
					end if;
					GM_RxSeq <= sGSF_Sla;

				----------------------------------------------------------------
				--	GinSubFrame Slave Atached
				----------------------------------------------------------------
				when sGSF_Sla =>
					NrOfGSF <= NrOfGSF - 1;
					GM_RxSeq <= sGSF_DatCRC_H;
				
				--------------------------------------------------------------------
				--	GinSubFrame Data-CRC
				--------------------------------------------------------------------
				when sGSF_DatCRC_H =>
                    if (RxCRC_Equ_H = H)	then
	   					GM_RxSeq <= sGSF_DatCRC_L;
	    			else
    					GM_RxSeq <= sErrEnd;
    				end if;	

				when sGSF_DatCRC_L =>	--- check CRC -----------------------------
	                -- increment GSF_Nr pointer
	                pGSF_Nr <= pGSF_Nr + 1;
					if (RxCRC_Equ_L = H)	then
						---	Check if we have more GIN-Frames -------------------
						if (NrOfGSF > 0) then
							GM_RxSeq <= sGSF_StartOfFrame;
						else
							if (g_Tunnel/=0 and page8=H) then
								GM_RxSeq <= sExtWaitEnd;
							else
								GinFrmOk <= H;        			-- Frame ok, IRQ
								GM_RxSeq <= sOkWaitEnd;
							end if;
						end if;	 
					else
						GM_RxSeq <= sErrEnd;
					end if;	
	            ----------------------------------------------------------------                        
				--	Ok-End, wait to end of GinFrame
	            ----------------------------------------------------------------                        
				when sOkWaitEnd =>	--- Wait to EndOFGinFrame ------------------
	   				if	(i_GinRun = L) then
  						GM_RxSeq <= sTTEnd;
	    			end if;
				
				when sExtWaitEnd =>	--- Wait to EndOFGinFrame ------------------
					if (i_GinRun = L) then
						GM_RxSeq <= sExtWaitEnd1;
					end if;
				when sExtWaitEnd1 =>	--- Wait to EndOFGinFrame ------------------
					GM_RxSeq <= sIdle;

	            ----------------------------------------------------------------                        
				--	Ok-End, write TransmissionTime
	            ----------------------------------------------------------------                        
				when sTTEnd =>		--- get TT-Adr ----------- 
					if (TransTimeRunning = L) then
						GM_RxSeq <= sTTEnd1;
					else
						GM_RxSeq <= sOkEnd;
					end if;	
					
				when sTTEnd1 =>	--- write TT ---------------
					GM_RxSeq <= sOkEnd;

	            ----------------------------------------------------------------                        
				--	Ok-End, count GinFrames
	            ----------------------------------------------------------------                        
				when sOkEnd =>	--- count GF -----------------------------------
					GM_RxSeq <= sOkEnd1;
				when sOkEnd1 =>	--- count GF -----------------------------------
					GM_RxSeq <= sIdle;

                ----------------------------------------------------------------                        
				--	Error End, Add ErrorCounter + 1
                ----------------------------------------------------------------                        
				-- Für ein Inc einer DPRam-Zelle +1 braucht es zwei States
				--	1 	Adr anlegen
				--	2   WrData = RdData + 1 ; WR
				
				when sErrEnd =>		--- Error, Inc Error-Counter ---------------
					o_GinError <= H;
  					GM_RxSeq <= sErrEnd2;
				when sErrEnd2 =>	--- write Error-Counter -------------------- 
  					GM_RxSeq <= sErrWaitEnd;
				when sErrWaitEnd =>	--- Wait to EndOFGinFrame ------------------
	   				if	(i_GinRun = L) then
  						GM_RxSeq <= sIdle;
	    			end if;
			
			when others => null; -----------------------------------------------
			end case;
 		  end if;
		end if;	
    end process;
    
--------------------------------------------------------------------------------
--	asynchron MEM_Adr
--------------------------------------------------------------------------------
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
    		MEM_AdrZ1 <= MEM_Adr;
    		if (GM_RxSeq = sGSF_Dat_L) then  
				MEM_AdrZ1 <= MEM_AdrZ1 + 1;
			end if;
			EthCRC_1 <= i_EthCRC;
    	end if;
    end process;		

	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then

			case GM_RxSeq is  
			when sGSF_StartOfFrame =>	--- write data -------------------------------
	        	GSF_DatXchd <= L;
	
			when sGSF_Dat_L =>	--- write data -------------------------------
				if (MEM_RdData /= MEM_WrData) then
					GSF_DatXchd <= H;
				end if;
	
			when others => null; ----------------------------------------------- 
			end case;

        end if;
    end process;		

--------------------------------------------------------------------------------
--	asynchron Rx Data RAM access
--------------------------------------------------------------------------------
	process (i_Q125) begin
    	if rising_edge(i_Q125) then
        	MEM_RdData_P1 <= MEM_RdData + 1;
		end if;	
    end process;
    
	process (GM_RxSeq,MEM_RdData,MEM_AdrZ1,ActSlot,WrDatBuf31_16,i_RxData,TransTime,MEM_RdData_P1,pGSF_Nr, ActGSF_Nr,ExtDv,page8)
	begin 

		MEM_Adr 	<= MEM_AdrZ1;
		MEM_WR 		<= L;	
		MEM_WrData 	<= x"00000000";

		case GM_RxSeq is  

		--------------------------------------------------------------------
		-- count GinSubFrames
		--------------------------------------------------------------------            	
		when sGSF_Cmd =>	--- save Cmd -------------------------------
			-- we need three steps to get das GSF_DatabaseAdr
			-- 1. point to ConfigData(slot).GSF_Nr
			MEM_Adr <= CfgSlot(11 downto 9) & ActSlot & pGSF_Nr(4 downto 2);
			
		when sExtWaitEnd =>
			if (g_Tunnel/=0) then
				if (ExtDv=H) then
					MEM_Adr <= CfgExtRxCnt;
				else
					MEM_Adr <= CfgExtCnt;
				end if;
			end if;
			
		when sExtWaitEnd1 =>
			if (g_Tunnel/=0) then
				-- count received ExtGinSubFrames
				MEM_WrData <= MEM_RdData_P1;
				MEM_WR <= H;
			end if;
			
		when sGSF_Adr_H =>	--- save Adr -------------------------------
--synchron	ActGSF_Nr <= MEM_RdData(3 downto 0); 	

		when sGSF_Adr_L =>	--- save Adr -------------------------------
			-- load GSF_Cnt_pointer
			MEM_Adr  <= CfgGSF_Cnt(11 downto 7) & ActGSF_Nr & CfgGSF_Cnt(2 downto 0);

		--------------------------------------------------------------------
    	-- load GSF_Data Adr
		--------------------------------------------------------------------
		when sGSF_Len =>                
			-- count received GinSubFrames
    		MEM_WrData <= MEM_RdData_P1;
			if (g_Tunnel/=0) then
				MEM_WR <= not page8;
			else
				MEM_WR <= H;
			end if;
			
--		when sGSF_Int => 
		
		when sGSF_HdCRC_L => 
			-- 2. point to GSF_Headr(GinSubFrame).DataBaseAdr 
			MEM_Adr <= CfgGSF_Hd_p(11 downto 7) & ActGSF_Nr & CfgGSF_Hd_p(2 downto 0);

		--------------------------------------------------------------------
		--	GinSubFrame Data
		--------------------------------------------------------------------
		when sGSF_StartOfData => 
			-- 3. load GsF-DataBaseAdr
			-- convert Byte-Adr to 32-Bit-Adr
			MEM_Adr <= MEM_RdData(13 downto 2);

		when sGSF_Dat_H => 

		when sGSF_Dat_L => 
			-- write Data	   high-word & low-word	
    		MEM_WrData <= WrDatBuf31_16 & i_RxData;
			if (g_Tunnel/=0) then
				MEM_WR <= not page8;
			else
				MEM_WR <= H;
			end if;

		when sGSF_LastDat_H =>
			-- write Data	   high-word & low-word	
    		MEM_WrData <= i_RxData & x"0000";
			if (g_Tunnel/=0) then
				MEM_WR <= not page8;
			else
				MEM_WR <= H;
			end if;

		when sGSF_LastDat_L =>
			-- write Data	   high-word & low-word	
    		MEM_WrData <= WrDatBuf31_16 & i_RxData;
			if (g_Tunnel/=0) then
				MEM_WR <= not page8;
			else
				MEM_WR <= H;
			end if;

		--------------------------------------------------------------------
		--	Slave attached
		--------------------------------------------------------------------
		when sGSF_Sla =>	--- Nr Of Salves attached --------------------------
			-- 2. point to GSF_Headr(GinSubFrame).DataBaseAdr
			MEM_Adr  <= CfgGSF_Sla(11 downto 7) & ActGSF_Nr & CfgGSF_Sla(2 downto 0);
    		MEM_WrData <= x"0000" & i_RxData;
			if (g_Tunnel/=0) then
				MEM_WR <= not page8;
			else
				MEM_WR <= H;
			end if;
								
		--------------------------------------------------------------------
		--	Ok-End , TT-End , wite Transmissions-Time
		--------------------------------------------------------------------
		when sTTEnd =>	--- Ok 

		when sTTEnd1 =>	--- write Transmission-Time ------------------------
			-- mit Q62_5 ist 1=16ns ; store x16 = ns
			MEM_Adr  	<= CfgGF_TT;
    		MEM_WrData 	<= TransTime & "0000";
			MEM_WR 		<= H;  
			 
		--------------------------------------------------------------------
		--	OK-End , count received OK-GinFrames
		--------------------------------------------------------------------
		when sOkEnd =>	--- Ok End, count GinFrames ----------------------------
			MEM_Adr  <= CfgGF_Cnt;

		when sOkEnd1 =>	--- count GinFrames ------------------------------------
	   		MEM_WrData <= MEM_RdData_P1;
			MEM_WR <= H;   
			 
		--------------------------------------------------------------------
		--	Error-End , count received Error-GinFrames
		--------------------------------------------------------------------
		when sErrEnd =>		--- Error, Inc Error-Counter ---------------
			MEM_Adr  <= CfgGF_Err;

		when sErrEnd2 =>	--- write Error-Counter -------------------- 
			-- count Errors
    		MEM_WrData <= MEM_RdData_P1;
			MEM_WR <= H;   

		when others => null; ----------------------------------------------- 
		end case;
    end process;
        
--******************************************************************************
--
--		Memory WriteBuffer-Toggle
--
--******************************************************************************
--	process (i_Q62_5) begin
--    	if rising_edge(i_Q62_5) then
--    		
--    		if ((GinFrmOk = H)        		-- was the whole frame ok
--				---	Daten OK, umschalten auf neuen Buffer --------------
----                WrBufTgl( CONV_INTEGER(Cmd_Pg) ) <= not WrBufTgl( CONV_INTEGER(Cmd_Pg) );
--            end if;                      
--
--		end if;                      
--    end process;
                                  
--------------------------------------------------------------------------------
--	CheckSumm Comperator	
--------------------------------------------------------------------------------
	process (i_RxData,i_EthCRC,EthCRC_1) begin
        if (i_RxData = i_EthCRC(31 downto 16))	then
			RxCRC_Equ_H <= H;
		else	
			RxCRC_Equ_H <= L;
		end if;
        if (i_RxData = EthCRC_1(15 downto 0))	then
			RxCRC_Equ_L <= H;
		else	
			RxCRC_Equ_L <= L;
		end if;

	end process;                  
	
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
