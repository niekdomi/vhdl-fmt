---------------------------------------------------------------------------
--
--  GIN-Frame Tx-Sequencer
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

LIBRARY gin_link;
USE gin_link.ALL;

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   21.05.2004-FB	erste Version
---------------------------------------------------------------------------
-- 	Rev. 1.01   24.01.2006-FB	
--		Master-Zeiten -1, damit 12.5us stimmt !? (stimmt es jetzt wirklich?)
---------------------------------------------------------------------------
-- 	Rev. 1.02   21.01.2011-FB	
--		Wenn GinLink angehalten wird -> Set ActSlot=0
--		Damit startet der GinLink immer richtig mit Slot-0 
---------------------------------------------------------------------------
--	23.01.2014-le - add a output to sync cop master
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink

--------------------------------------------------------------------------------
--$Rev:: 4869                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-25 17:22:07 +0200 (Mi., 25 Apr 2018)                         $
--------------------------------------------------------------------------------

entity GM_TxSeq is
	generic (
		g_Tunnel		: in natural range 0 to 1 := 0;
		g_TX_DATA_Z1	: in natural range 0 to 1 := 0
	);
	port (
		i_Q125		 	: in  std_logic;    
		i_Q62_5		 	: in  std_logic;
	
		i_MEM_RdData	: in  std_logic_vector(31 downto 0);		
		o_MEM_WrData	: out std_logic_vector(31 downto 0);		
		o_MEM_Adr		: out std_logic_vector(10 downto 0);		
		o_MEM_WR		: out std_logic;                           

		o_TxSlot_0		: out std_logic;  						-- for TransTimer
		o_TxIRQs		: out std_logic_vector(11 downto 0);	-- to PPC
		
		o_SynCopMas		: out std_logic;       
	
		o_TxCharIsK 	: out std_logic_vector( 1 downto 0);
		o_TxData 		: out std_logic_vector(15 downto 0);
		
		o_Mac2Tun_En : out std_logic;
		i_Mac2Tun_Req : in std_logic := '0';
		i_ExtTxData : in  std_logic_vector(15 downto 0) := (others => '0');
		i_ManageRx : in std_logic := '0';
		i_SlaveNr : in  std_logic_vector(15 downto 0) := (others => '0');
		o_SlaveDone : out std_logic;
		o_dbgExtData : out std_logic
    );
end;    

architecture impl of GM_TxSeq is   

--------------------------------------------------------------------------------
    type sGM_TxSeq is (
    	sIdle0,sIdle1,sIdle2,sIdle,
    	sSlotTim,sSlotTim1,sSlotTim2,sStart,sStartExt,sStart1,
    	sETH_Start,sETH_IP_UDP_H,sETH_IP_UDP_L,sETH_IP_UDP_LNG,sETH_IP_UDP_CSUM,sEth_HdCRC_H,sEth_HdCRC_L,
    	sGF_StartOfFrame,sGF_HdBlink,sGF_HdLen,sGF_Sfty_H,sGF_Sfty_L,sGF_HdCRC_H,sGF_HdCRC_L,
    	sGSF_StartOfHeader,sGSF_Cmd,sGSF_Adr_H,sGSF_Adr_L,sGSF_Len,sGSF_Int,sGSF_Sfty_H,sGSF_Sfty_L,sGSF_HdCRC_H,sGSF_HdCRC_L,
    	sGSF_StartOfData,sGSF_Dat_H,sGSF_Dat_L,sGSF_Sla,sGSF_DatCRC_H,sGSF_DatCRC_L,
    	sWaitUdpEnd,sETH_CRC_H,sETH_CRC_L,
    	sETH_IP_UDPEnd,sEnd_AddGFcnt,sEnd_NextSlot,sEnd_ShowSlot
    );
	
	signal	GM_TxSeq			: sGM_TxSeq := sIdle;		    				-- main sequencer
          	
	signal	MEM_Adr			: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	signal	MEM_AdrZ1		: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	signal	MEM_WrData		: std_logic_vector(31 downto 0) := x"00000000";	-- data to   dp-ram		
	signal	MEM_RdData		: std_logic_vector(31 downto 0) := (others => '0');				-- data from dp-ram		
	signal	MEM_RdData_P1	: std_logic_vector(31 downto 0) := x"00000000";	-- data from dp-ram	
	signal	MEM_WR			: std_logic := '0';								-- write 
          	
	signal	TxLowData		: std_logic_vector(15 downto 0) := x"0000";		-- latched data 
	signal	TxHighData		: std_logic_vector(15 downto 0) := x"0000";		-- latched data 
	signal	TxLowDataZ1		: std_logic_vector(15 downto 0) := x"0000";		-- latched data 
	signal	TxHighDataZ1	: std_logic_vector(15 downto 0) := x"0000";		-- latched data
	signal	MEM_RdDataX		: std_logic_vector(31 downto 0);
	signal	TxData			: std_logic_vector(15 downto 0) := x"0000";		-- what we want to send	
	signal	TxCharIsK		: std_logic_vector( 1 downto 0) := "00";
	      	                 	
	signal	NrOfGSF			: std_logic_vector( 4 downto 0) := "00000";		-- Nr of GinSubFrames		
	signal	NrOfSlots		: std_logic_vector( 3 downto 0) := "0000";		-- nr of Slots
	signal	ActSlot			: std_logic_vector( 3 downto 0) := "0000";		-- Slot Cnt
	signal	EthCnt			: std_logic_vector(11 downto 0) := x"000";		-- Eth Cnt
	signal	UdpWordCnt		: std_logic_vector(11 downto 0) := x"000";		-- Udp Cnt
	signal	GinByteCnt		: std_logic_vector(11 downto 0) := x"000";		-- Gin Cnt
	signal	pGSF_Nr			: std_logic_vector( 4 downto 0) := "00000";		-- GinSubFrame Cnt
          	
          	
	signal	TxSlot_0		: std_logic := '0';
          	
	signal	Timer			: std_logic_vector(31 downto 0) := x"00000000";	-- safety-timer

--------------------------------------------------------------------------------
--	Slot Cycle Timer
--------------------------------------------------------------------------------
	signal	Time			: std_logic_vector(15 downto 0)	:= x"03E0";		-- 1us first cycle MainTimer

--------------------------------------------------------------------------------
--	Slot IRQ-Timer	
--------------------------------------------------------------------------------
--	10 Slot IRQ-Timer, 10Bit each, 128ns resolution
	signal 	TxIRQ			: std_logic_vector( 9 downto 0)	:= "0000000000";-- IRQ to PPC
	signal 	IRQ_Timer		: std_logic_vector(13 downto 0) := "00" & x"000";
	signal 	IRQ_Tim			: std_logic_vector( 9 downto 0) := (others => '0'); 
	
	type 	tIRQ_Cmp is array(0 to 9) of  std_logic_vector(9 downto 0);
	signal 	IRQ_CNT			: tIRQ_Cmp := (others => (others => '0'));

--------------------------------------------------------------------------------
--	32Bit EthCRC
--------------------------------------------------------------------------------
   	signal	EthTxCRC		: std_logic_vector (31 downto 0) := x"00000000"; 
   	signal	LxCRC32			: std_logic_vector (31 downto 0) := x"00000000"; 

   	signal	EthCRCinp		: std_logic_vector (15 downto 0) := x"0000"; 
	signal 	EthCrcClr		: std_logic := '0';
	signal 	EthCrcRun	 	: std_logic := '0';

--------------------------------------------------------------------------------
--	dQ62_5 to be in phse with Q62_6 _+-
--------------------------------------------------------------------------------
	signal 	Q31_25 			: std_logic := '0';
	signal 	Q31_25_1		: std_logic := '0';   
	signal	dQ62_5			: std_logic := '0';								-- Q62_5 as signal
	
--------------------------------------------------------------------------------

--attribute KEEP : string;
--attribute KEEP of TxIRQ	: signal is "TRUE";

--------------------------------------------------------------------------------
--	Configuration
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	DP-Ram Memory
--------------------------------------------------------------------------------
 	constant CfgSlot_Act	: std_logic_vector(11 downto 0) := x"000";
	constant CfgSlot_Tim	: std_logic_vector(11 downto 0) := x"001";
	constant CfgSlot_Irq	: std_logic_vector(11 downto 0) := x"002";
	constant CfgSlot_GSF	: std_logic_vector(11 downto 0) := x"004";
	
	constant CfgNrOfSlot	: std_logic_vector(11 downto 0) := x"060";	-- 0180
	constant CfgActSlot		: std_logic_vector(11 downto 0) := x"061";  -- 0184
	constant CfgGF_TT		: std_logic_vector(11 downto 0) := x"064";  -- 0190
	constant CfgGF_Err		: std_logic_vector(11 downto 0) := x"066";  -- 0198
	constant CfgGF_Cnt		: std_logic_vector(11 downto 0) := x"067";  -- 019C
	
	constant CfgExtTxCnt	: std_logic_vector(11 downto 0) := x"068";	-- 01A0
	constant CfgExtCnt		: std_logic_vector(11 downto 0) := x"069";	-- 01A4

	constant CfgEthHd		: std_logic_vector(11 downto 0) := x"070";	-- 01C0

	constant CfgGSF_Hd		: std_logic_vector(11 downto 0) := x"080";	-- 0200
	constant CfgGSF_Hd_n	: std_logic_vector(11 downto 0) := x"082"; 	-- HighWord
	constant CfgGSF_Hd_p	: std_logic_vector(11 downto 0) := x"084"; 	-- pBaseAdr
	constant CfgGSF_Err		: std_logic_vector(11 downto 0) := x"086"; 	-- GSF_CRC errors
	constant CfgGSF_Cnt		: std_logic_vector(11 downto 0) := x"087"; 	-- GSF_Counter
	-- 0180..0187	for GF-0
	-- 0180..01FF	for GF-0..GF-F

--------------------------------------------------------------------------------
--	offsets/values in GIN-Frame
--------------------------------------------------------------------------------
    constant ETH_CRC_start 		: integer := 2;
    constant UDP_LENGHT_OFS 	: integer := 22;
    constant UDP_CSUM_OFS 		: integer := 23;
    constant GIN_HEADER_OFS 	: integer := 24;
    constant GIN_BLINK_OFS 		: integer := 25;
    constant GIN_SUBHEADER_OFS 	: integer := 28;
    
    -- GinSubFrm Counter
    constant GIN_SUBHD_Len_OFS  : integer :=  3;
    constant GIN_SUBHD_CSUM_OFS : integer :=  5;

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';
	
	signal SynCopMas : std_logic := L;

	signal	MEM_AdrInc		: std_logic_vector(11 downto 0) := x"000";		-- act dp-ram adr		
	
	constant DF_EXT_GSF_LNG : std_logic_vector(15 downto 0) := x"0600";
	constant DF_EXT_UDP_LNG : std_logic_vector(15 downto 0) := DF_EXT_GSF_LNG+54;
	signal ExtData : std_logic := L;
	signal Mac2Tun_send : std_logic := L;
	
	signal Mac2Tun_En : std_logic := L;
	signal ExtTxData : std_logic_vector(15 downto 0) := (others => L);
	
	signal TunTxWait : std_logic_vector(3 downto 0) := (others => L);
	signal TunTxFirst : std_logic := L;
--------------------------------------------------------------------------------
begin -- of architecture GM_TxSeq    
--------------------------------------------------------------------------------
	o_Mac2Tun_En <= Mac2Tun_En;
	o_dbgExtData <= ExtData;
--------------------------------------------------------------------------------
--	generate dQ62_5 signal to be in phase with _+- of Q62_5 
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then
        	Q31_25 <= not Q31_25;
		end if;	
    end process;

	process (i_Q125) begin
    	if rising_edge(i_Q125) then
        	Q31_25_1 <= Q31_25;
		end if;	
    end process;

	process (i_Q125) begin
    	if rising_edge(i_Q125) then
        	dQ62_5 <= (not Q31_25 and not Q31_25_1) or (Q31_25 and Q31_25_1);
		end if;	
    end process;


	-- Panik-Register	(Q62_5 max delay 2ns)
--	process (i_Q125) begin
--    	if falling_edge(i_Q125) then
--        	dQ62_5 <= i_dQ62_5;
--		end if;	
--    end process;
--------------------------------------------------------------------------------

--	outputs --------------------------------------------------------------------
	-- MEM_Adr(11) is not used and will be eliminated!
	o_MEM_Adr 	<=   MEM_Adr(10 downto 0);
	o_MEM_WrData 	<=   MEM_WrData;		
	  MEM_RdData 	<= i_MEM_RdData;
	o_MEM_Wr		<=   MEM_Wr;		
			        	
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
            o_TxCharIsK <= TxCharIsK;
            o_TxData	<= TxData;
        end if;
    end process;        

	o_TxSlot_0		<=   TxSlot_0 ;

--	o_TxIRQs <= x"000";
	o_TxIRQs <= "00" & TxIRQ;
		              
--******************************************************************************
--		Safety-Timer
--******************************************************************************
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
			Timer <= Timer + 1;
		end if;	
    end process;

--******************************************************************************
--
--		IRQ
--
--******************************************************************************

    ----------------------------------------------------------------------------
	-- IRQ-Timer
    ----------------------------------------------------------------------------
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
			if  ((GM_TxSeq = sSlotTim)
			and	 (ActSlot = 0)) 	then
				IRQ_Timer <= "00000000000000";
			else
				IRQ_Timer <= IRQ_Timer + 1;
			end if;
		end if;	
    end process;

    ----------------------------------------------------------------------------
	-- IRQ-Timers
    ----------------------------------------------------------------------------
    --  10 Slot-Timer
    --  10 Bit each
    -- 128 ns resoltuion (8 x 16ns)
    
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
            TxIRQ <= "0000000000";
			o_SynCopMas <= L;
			if (GM_TxSeq = sETH_Start and (g_Tunnel=0 or ExtData=L)) then 
				IRQ_CNT(CONV_INTEGER(ActSlot)) <= IRQ_Tim;
			else	
				if (IRQ_Timer(2 downto 0) = "111") then  
				    for i in 0 to 9 loop
						if (IRQ_CNT(i) > "0000000000") then
							IRQ_CNT(i) <= IRQ_CNT(i) - 1;
						end if;	
						if (IRQ_CNT(i) = "0000000001") then
							TxIRQ(i) <= H;
							if (i=0) then
								o_SynCopMas <= SynCopMas;
							end if;
						end if;          
					end loop;
				
				end if;
			end if;
								
		end if;	
    end process;

    ----------------------------------------------------------------------------
	-- IRQ-Comperator
    ----------------------------------------------------------------------------
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
		end if;	
    end process;

--******************************************************************************
--
--		GM Tx Sequencer
--
--******************************************************************************
--	12.32us -> 12.5us 	180ns
--	62.5MHz = 16ns @ 180ns = 11.25 Takte 
--	11 11 11 12 11 11 11 12
--------------------------------------------------------------------------------
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then 
			ExtTxData <= i_ExtTxData;
			TunTxFirst <= L;
    		-- time - ganze 16ns, behalte 0..15ns fragmente
	   		Time(15 downto 4) <= Time(15 downto 4) - 1;
	   		
   		    EthCnt 		<= x"000";    
   		    if (UdpWordCnt > 0) then
		   		UdpWordCnt	<= UdpWordCnt - 1;
		   	end if;	
			TxSlot_0 	<= L;

    		case GM_TxSeq is  
    		
            -------------------------------------------------------------------- 
			--	wait to next 12.5us slot
            -------------------------------------------------------------------- 
			when sIdle =>	--- wait to next Cycle -----------------------------
				-- load nr of slots
				NrOfSlots <= MEM_RdData(27 downto 24);
				-- point to first GSF_Nr (Byte-Adr)
                pGSF_Nr <= CfgSlot_GSF(2 downto 0) & "00";

	            EthCrcClr <= H;
				Mac2Tun_En <= L;
				ExtData <= L;
				Mac2Tun_send <= L;
				
				-- damit CycleTime in ns, nur ...1, sonst 1 zu lang 
				if (Time(15 downto 4) = X"001") then
					-- korrigiere auf 16ns 
					Time <= ("00000000" & Time(3 downto 0)) + MEM_RdData(15 downto 0);
					-- check if GinLink active
					if (MEM_RdData(28) = H) then
						GM_TxSeq <= sIdle0;
					else  
						-- next ReStart with SLot-0
						ActSlot <= x"0";		    
					end if;
					if (TunTxWait/=0) then
						TunTxWait <= TunTxWait-1;
					end if;
				end if;

            -------------------------------------------------------------------- 
			--	Load IRQ_Timer 
            -------------------------------------------------------------------- 
			when sIdle0 =>	--- prepare Mmem_adr -------------------------------
				-- save IRQ-Time [ns]/128 	
				IRQ_Tim <= MEM_RdData(16 downto 7);
				GM_TxSeq <= sSlotTim;	    

			--------------------------------------------------------------------
			--	Slot Timer
			--------------------------------------------------------------------
			when sSlotTim => 
				-- -1, so we can test if equal ActSlot
				NrOfSlots <= NrOfSlots - 1;

			    -- check if SlotTimer = 00
				if (MEM_RdData(7 downto 0) = x"00") then
					GM_TxSeq <= sSlotTim1;	    
				else   
					-- skip it and pos to next Slot
					GM_TxSeq <= sSlotTim2;	    
				end if;

			when sSlotTim1 =>
				-- reload timer
				GM_TxSeq <= sStart;	    

			when sSlotTim2 =>
				if (g_Tunnel=0) then
					-- skip it this time and pos to next Slot
					GM_TxSeq <= sEnd_NextSlot;
				else
					GM_TxSeq <= sStartExt;
				end if;
--				IRQ_Ena(CONV_INTEGER(ActSlot)) <= L;
			 
			--------------------------------------------------------------------
			--	Start
			--------------------------------------------------------------------
			when sStart =>
				-- read nr of GSF	
				NrOfGSF <= MEM_RdData(4 downto 0);

				-- check if Slot active ?
				if (MEM_RdData(28) = H) then
					GM_TxSeq <= sStart1;
--					IRQ_Ena(CONV_INTEGER(ActSlot)) <= MEM_RdData(30);
				else
					if (g_Tunnel=0) then
						-- skip it and pos to next Slot
						GM_TxSeq <= sEnd_NextSlot;
					else
						GM_TxSeq <= sStartExt;
					end if;
--					IRQ_Ena(CONV_INTEGER(ActSlot)) <= L;
				end if;
				
			when sStartExt =>
				if (Time(15 downto 4) > (CONV_INTEGER(DF_EXT_UDP_LNG+10)/2)) then
					ExtData <= H;
					GM_TxSeq <= sStart1;
					NrOfGSF <= "00001";
					if (i_Mac2Tun_Req=H and TunTxWait=0) then
						-- data ready to send
						Mac2Tun_send <= H;
						TunTxWait <= x"9";
					else
						Mac2Tun_send <= L;
					end if;
				else
					-- skip it and pos to next Slot
					GM_TxSeq <= sEnd_NextSlot;	  
				end if;
			when sStart1 =>
				GM_TxSeq <= sETH_Start;
			--------------------------------------------------------------------
			--	Eth , IP , UDP Header
			--------------------------------------------------------------------
			when sETH_Start =>	--- Send Eth Preamble --------------------------
				GM_TxSeq <= sETH_IP_UDP_L;

			when sETH_IP_UDP_L =>	--- Send EthFrame --------------------------
                if (EthCnt = ETH_CRC_start) then
					EthCrcClr <= L;
                end if;
                -- load UDP-Lenght 
				--if (EthCnt = UDP_LENGHT_OFS-1) then
				--	GM_TxSeq <= sETH_IP_UDP_LNG;
				--else
					GM_TxSeq <= sETH_IP_UDP_H;
				--end if;
	   		    EthCnt <= EthCnt + 1; 

			when sETH_IP_UDP_H =>	--- Send EthFrame --------------------------
				if (EthCnt = UDP_LENGHT_OFS-1) then
					GM_TxSeq <= sETH_IP_UDP_LNG;
				else
					GM_TxSeq <= sETH_IP_UDP_L;	    
       			end if;	
	   		    EthCnt <= EthCnt + 1; 

			when sETH_IP_UDP_LNG =>
				-- load Udp-word-counter (byte_len/2) 
				if (g_Tunnel/=0 and ExtData=H) then
					UdpWordCnt <= DF_EXT_UDP_LNG(12 downto 1);
				else
					UdpWordCnt <= MEM_RdDataX(12 downto 1);
				end if;
				GM_TxSeq <= sETH_IP_UDP_CSUM;
			when sETH_IP_UDP_CSUM =>
				GM_TxSeq <= sEth_HdCRC_H;
			--------------------------------------------------------------------
			--------------------------------------------------------------------
			--	EthHeader Csum
			--------------------------------------------------------------------
			when sEth_HdCRC_H => 
				GM_TxSeq <= sEth_HdCRC_L;	    
			when sEth_HdCRC_L => 
				GM_TxSeq <= sGF_StartOfFrame;	    
			
			--------------------------------------------------------------------
			--	Start of GinHeader
 			--------------------------------------------------------------------
			when sGF_StartOfFrame =>
				GM_TxSeq <= sGF_HdBlink;	    
			
			--------------------------------------------------------------------
			--	GinHeader Blink
 			--------------------------------------------------------------------
			when sGF_HdBlink =>
				if (ActSlot = 0 and (g_Tunnel=0 or ExtData=L)) then
					TxSlot_0 <= H;
				end if;
				GM_TxSeq <= sGF_HdLen;	    
				
			--------------------------------------------------------------------
			--	GinHeader NrOfGinFrames
			--------------------------------------------------------------------
			when sGF_HdLen =>
				GM_TxSeq <= sGF_Sfty_H;	    
				
			--------------------------------------------------------------------
			--	GinHeader Safety
			--------------------------------------------------------------------
			when sGF_Sfty_H => 
				GM_TxSeq <=  sGF_Sfty_L;
			when sGF_Sfty_L =>
				if (ActSlot=0 and (g_Tunnel=0 or ExtData=L)) then
					if (MEM_RdDataX(5 downto 0)=0) then
						SynCopMas <= H;
					else
						SynCopMas <= L;
					end if;
				end if;
				GM_TxSeq <= sGF_HdCRC_H;	    
			
			--------------------------------------------------------------------
			--	GinHeader Csum
			--------------------------------------------------------------------
			when sGF_HdCRC_H => 
				GM_TxSeq <= sGF_HdCRC_L;	    
			when sGF_HdCRC_L => 
				GM_TxSeq <= sGSF_StartOfHeader;	    
			
			--------------------------------------------------------------------
			--	GinSubFrame Header
			--------------------------------------------------------------------
			when sGSF_StartOfHeader => 
				GM_TxSeq <= sGSF_Cmd;
					    
			when sGSF_Cmd => 
				GM_TxSeq <= sGSF_Adr_H;
					    
			when sGSF_Adr_H => 
				GM_TxSeq <= sGSF_Adr_L;	
				    
			when sGSF_Adr_L => 
				GM_TxSeq <= sGSF_Len;
					    					    
			when sGSF_Len => 
				-- load Nr of Gin-Words
				if (g_Tunnel/=0 and ExtData=H) then
					GinByteCnt <= DF_EXT_GSF_LNG(11 downto 0);
				else
					GinByteCnt <= MEM_RdDataX(27 downto 17)&L;
				end if;
				GM_TxSeq <= sGSF_Int;
					    
			when sGSF_Int => 
				GM_TxSeq <= sGSF_Sfty_H;	    

			--------------------------------------------------------------------
			--	GinSubHeader Safety
			--------------------------------------------------------------------
			when sGSF_Sfty_H => 
				GM_TxSeq <= sGSF_Sfty_L;	    
			when sGSF_Sfty_L => 
				GM_TxSeq <= sGSF_HdCRC_H;
				if (g_Tunnel/=0 and ExtData=H) then
					Mac2Tun_En <= Mac2Tun_send;
				end if;
			
			--------------------------------------------------------------------
			--	GinSubFrame Header Csum
			--------------------------------------------------------------------
			when sGSF_HdCRC_H =>
				GM_TxSeq <= sGSF_HdCRC_L;	    
			when sGSF_HdCRC_L => 
				GM_TxSeq <= sGSF_StartOfData;	    
			
            --------------------------------------------------------------------
			--	GinSubFrame Data
            --------------------------------------------------------------------
			when sGSF_StartOfData => 
                -- point to next GSF_Nr, so we can get next GSF while DatCRC
				if (g_Tunnel=0 or ExtData=L) then
					pGSF_Nr <= pGSF_Nr + 1;
				end if;

				-- Check if Length reached
				if (GinByteCnt = x"000") then
					GM_TxSeq <= sGSF_Sla;
				else	
					GM_TxSeq <= sGSF_Dat_H;
					TunTxFirst <= H;
				end if;
       		    -- decrement, so we can test to 00
       		    GinByteCnt <= GinByteCnt - 2;

			when sGSF_Dat_H => 
									
				-- Check if Length reached
				if (GinByteCnt = x"000") then
					GM_TxSeq <= sGSF_Sla;
				else	
					GM_TxSeq <= sGSF_Dat_L;
				end if;
       		    GinByteCnt <= GinByteCnt - 2;

			when sGSF_Dat_L => 
									
				-- Check if Length reached
				if (GinByteCnt = x"000") then
					GM_TxSeq <= sGSF_Sla;
				else	
					GM_TxSeq <= sGSF_Dat_H;
				end if;
       		    GinByteCnt <= GinByteCnt - 2;

			--------------------------------------------------------------------
			--	GinSubFrame Slave Atached
			--------------------------------------------------------------------
			when sGSF_Sla =>
                NrOfGSF <= NrOfGSF - 1;
				GM_TxSeq <= sGSF_DatCRC_H;			           
			
			--------------------------------------------------------------------
			--	GinSubFrame Csum
			--------------------------------------------------------------------
			when sGSF_DatCRC_H => 
				GM_TxSeq <= sGSF_DatCRC_L;	    

			when sGSF_DatCRC_L => 
				if not(NrOfGSF = 0) then
					GM_TxSeq <= sGSF_StartOfHeader;	    
				else
					if (UdpWordCnt <= 4) then
						GM_TxSeq <= sETH_CRC_H;
					else		    
						GM_TxSeq <= sWaitUdpEnd;	    
					end if;	
				end if;	
			
			--------------------------------------------------------------------
			--	wait untill UDP-Lenght reached
			--------------------------------------------------------------------
			when sWaitUdpEnd => 
				if (UdpWordCnt <= 4) then
					GM_TxSeq <= sETH_CRC_H;	    
					Mac2Tun_En <= L;
				end if;	
			
			--------------------------------------------------------------------
			--	send Ethernet end of packet CRC
			--------------------------------------------------------------------
			when sETH_CRC_H => 
				GM_TxSeq <= sETH_CRC_L;	    
			when sETH_CRC_L => 
				GM_TxSeq <= sETH_IP_UDPEnd;	    

			when sETH_IP_UDPEnd => 
				GM_TxSeq <= sEnd_AddGFcnt;	    
			when sEnd_AddGFcnt => 
				GM_TxSeq <= sEnd_NextSlot;	
				    
			--------------------------------------------------------------------
			--	Add GF_Counter
			--------------------------------------------------------------------
			when sEnd_NextSlot => 
				-- next Slot
				if (ActSlot >= NrOfSlots) then
					ActSlot <= "0000";
				else
					ActSlot <= ActSlot + 1;
				end if;
				GM_TxSeq <= sEnd_ShowSlot;
			
			when sEnd_ShowSlot => 
				GM_TxSeq <= sIdle;	    
			
			when others => null; -----------------------------------------------
			end case;
		end if;	
    end process;
    
--==============================================================================
--
--	asynchron MEM_Adr
--
--==============================================================================
--	VORSICHT:
--	---------
--	Der Pfad RdData zu WrData kann bis zu 11ns benötigen
--	Damit ist es nicht möglich, einen Add +1 in einen State zu machen
--------------------------------------------------------------------------------
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
    		MEM_AdrZ1 <= MEM_Adr;
			MEM_AdrInc <= MEM_AdrZ1+1;
		end if;
	end process;	
	--MEM_AdrInc <= MEM_AdrZ1 + 1;
	
	process (i_Q125) begin
    	if rising_edge(i_Q125) then
        	MEM_RdData_P1 <= MEM_RdData + 1;
		end if;	
    end process;

	process (dQ62_5,GM_TxSeq,MEM_RdData,MEM_AdrZ1,ActSlot,pGSF_Nr,MEM_RdData_P1,ExtData,MEM_AdrInc,Mac2Tun_send) 	
	begin 
		MEM_WR 		<= L;	
		MEM_WrData 	<= x"00000000";	
		MEM_Adr 	<= MEM_AdrZ1;

    		case GM_TxSeq is  
            -------------------------------------------------------------------- 
			--	load config data
            -------------------------------------------------------------------- 
			when sIdle =>	
	   		    -- point to SlotCommand-0
				MEM_Adr <= CfgNrOfSlot(11 downto 0);

			when sIdle0 =>	
	   		    -- point to SlotCommand-0
				MEM_Adr  <= CfgSlot_Irq(11 downto 7) & ActSlot & CfgSlot_Irq(2 downto 0);

			--------------------------------------------------------------------
			--	Slot Timer   	;	Reload or Sub the Slot-Timer
			--------------------------------------------------------------------
			when sSlotTim =>
				MEM_Adr  <= CfgSlot_Tim(11 downto 7) & ActSlot & CfgSlot_Tim(2 downto 0);

			when sSlotTim1 =>
				-- Reload 8-Bit Slot-Timer
				MEM_WrData <= MEM_RdData(31 downto 8) & MEM_RdData(23 downto 16);
				if (dQ62_5 = L) then
					if (g_Tunnel/=0) then
						MEM_WR <= not ExtData;
					else
						MEM_WR <= H;
					end if;
				end if;

			when sSlotTim2 =>
				-- decrement Slot-Timer
				MEM_WrData <= MEM_RdData(31 downto 8) & (MEM_RdData(7 downto 0) - 1);
				if (dQ62_5 = L) then
					if (g_Tunnel/=0) then
						MEM_WR <= not ExtData;
					else
						MEM_WR <= H;
					end if;
				end if;

			--------------------------------------------------------------------
			--	Start
			--------------------------------------------------------------------
			when sStart
				|sStartExt =>
				if (dQ62_5 = H) then
					MEM_Adr  <= CfgSlot_Act(11 downto 7) & ActSlot & CfgSlot_Act(2 downto 0);
				else	
					-- start Ethernet-Frame 
					MEM_Adr <= CfgEthHd;
				end if;	

			--------------------------------------------------------------------
			--	Eth , IP , UDP Header , GF_HeaderStart
			--------------------------------------------------------------------	
			when sETH_Start
				|sETH_IP_UDP_H
				|sEth_HdCRC_L
				|sGF_HdBlink =>
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=1) then
						MEM_Adr <= MEM_AdrInc;
					end if;
				end if;
				
			when sETH_IP_UDP_L
				|sETH_IP_UDP_LNG
				|sGF_StartOfFrame
				|sGF_HdLen =>
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=0) then
						MEM_Adr <= MEM_AdrInc;
					end if;
				end if;
			
			--------------------------------------------------------------------
			--	GinHeader Blink  	; check if Single-Shot Slot
			--------------------------------------------------------------------
			when sGF_Sfty_H =>
				-- TxData needs still the ram-data
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=1) then
						MEM_Adr  <= CfgSlot_Act(11 downto 7) & ActSlot & CfgSlot_Act(2 downto 0);
					end if;
				end if;
			when sGF_Sfty_L =>
				if (g_TX_DATA_Z1=0) then
					-- TxData needs still the ram-data
					if (dQ62_5 = L) then
						MEM_Adr  <= CfgSlot_Act(11 downto 7) & ActSlot & CfgSlot_Act(2 downto 0);
					end if;
				else
					-- clear Slot-Active-Bit
					MEM_WrData <= MEM_RdData(31 downto 29) & L & MEM_RdData(27 downto 26) & H&L & MEM_RdData(23 downto 0);
					if ((dQ62_5 = L)
					and (MEM_RdData(24) = H) ) then
						if (g_Tunnel/=0) then
							MEM_WR <= not ExtData;
						else
							MEM_WR <= H;
						end if;	
					end if;
				end if;

			when sGF_HdCRC_H =>
				if (g_TX_DATA_Z1=0) then
					-- clear Slot-Active-Bit
					MEM_WrData <= MEM_RdData(31 downto 29) & L & MEM_RdData(27 downto 26) & H&L & MEM_RdData(23 downto 0);
					if ((dQ62_5 = L) 
					and (MEM_RdData(24) = H) ) then
						if (g_Tunnel/=0) then
							MEM_WR <= not ExtData;
						else
							MEM_WR <= H;
						end if;	
					end if;
				else
					if (dQ62_5 = H) then
						-- point to SlotGinFrame# n
						MEM_Adr <= CfgSlot_GSF(11 downto 7) & ActSlot & pGSF_Nr(4 downto 2);
					else
						-- load GsF-Data Pointer
						case (pGSF_Nr(1 downto 0)) is
						when "00" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(27 downto 24) & CfgGSF_Hd(2 downto 0);
						when "01" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(19 downto 16) & CfgGSF_Hd(2 downto 0);
						when "10" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(11 downto  8) & CfgGSF_Hd(2 downto 0);
						when "11" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData( 3 downto  0) & CfgGSF_Hd(2 downto 0);
						when others => null;
						end case;				
					end if;
				end if;

			--------------------------------------------------------------------
			--	GinHeader Csum
			--------------------------------------------------------------------
			when sGF_HdCRC_L =>
				if (g_TX_DATA_Z1=0) then
					if (dQ62_5 = H) then
						-- point to SlotGinFrame# n
						MEM_Adr <= CfgSlot_GSF(11 downto 7) & ActSlot & pGSF_Nr(4 downto 2);
					else
						-- load GsF-Data Pointer
						case (pGSF_Nr(1 downto 0)) is
						when "00" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(27 downto 24) & CfgGSF_Hd(2 downto 0);
						when "01" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(19 downto 16) & CfgGSF_Hd(2 downto 0);
						when "10" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(11 downto  8) & CfgGSF_Hd(2 downto 0);
						when "11" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData( 3 downto  0) & CfgGSF_Hd(2 downto 0);
						when others => null;
						end case;				
					end if;
				end if;
			
 			--------------------------------------------------------------------
			--	GinSubFrame Header
			--------------------------------------------------------------------
			when sGSF_Cmd
				|sGSF_Adr_L
				|sGSF_Int
				|sGSF_Sfty_L =>
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=0) then
						MEM_Adr <= MEM_AdrInc;
					end if;
				end if;
	
			when sGSF_StartOfHeader
				|sGSF_Adr_H
				|sGSF_Len
				|sGSF_Sfty_H =>
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=1) then
						MEM_Adr <= MEM_AdrInc;
					end if;
				end if;
						
			--------------------------------------------------------------------
			--	GinSubFrame Header Csum
			--------------------------------------------------------------------
			--when sGSF_HdCRC_H => 
			when sGSF_HdCRC_L =>
				if (dQ62_5 = L) then
					-- load GSF-Data Pointer
					-- convert byte-adr to 32-Bit-Adr
					if (g_TX_DATA_Z1=1) then
						MEM_Adr <= MEM_RdData(13 downto 2);
					end if;
				end if;

			when sGSF_StartOfData => 
				if (dQ62_5 = L) then
					-- load GSF-Data Pointer
					-- convert byte-adr to 32-Bit-Adr
					if (g_TX_DATA_Z1=0) then
						MEM_Adr <= MEM_RdData(13 downto 2);
					end if;
				end if;

			--------------------------------------------------------------------
			--	GinSubFrame Data
			--------------------------------------------------------------------
			when sGSF_Dat_L => 
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=0) then
						MEM_Adr <= MEM_AdrInc;
					end if;
				end if;
			when sGSF_Dat_H => 
				if (dQ62_5 = L) then
					if (g_TX_DATA_Z1=1) then
						MEM_Adr <= MEM_AdrInc;
					end if;
				end if;
				
			--------------------------------------------------------------------
			--	GinSubFrame Data-Csum
			--------------------------------------------------------------------
			when sGSF_DatCRC_H =>
				if (g_TX_DATA_Z1=1) then
					if (dQ62_5 = H) then
						-- point to next SlotGinFrame# n
						MEM_Adr <=  CfgSlot_GSF(11 downto 7) & ActSlot & pGSF_Nr(4 downto 2);
					else	
						-- load GsF-Data Pointer
						case (pGSF_Nr(1 downto 0)) is
						when "00" =>
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(27 downto 24) & CfgGSF_Hd(2 downto 0);
						when "01" =>
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(19 downto 16) & CfgGSF_Hd(2 downto 0);
						when "10" =>
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(11 downto  8) & CfgGSF_Hd(2 downto 0);
						when "11" =>
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData( 3 downto  0) & CfgGSF_Hd(2 downto 0);
						when others => null;
						end case;
					end if; 
				end if;
			when sGSF_DatCRC_L =>
				if (g_TX_DATA_Z1=0) then
					if (dQ62_5 = H) then
						-- point to next SlotGinFrame# n
						MEM_Adr <=  CfgSlot_GSF(11 downto 7) & ActSlot & pGSF_Nr(4 downto 2);
					else	
						-- load GsF-Data Pointer
						case (pGSF_Nr(1 downto 0)) is
						when "00" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(27 downto 24) & CfgGSF_Hd(2 downto 0);
						when "01" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(19 downto 16) & CfgGSF_Hd(2 downto 0);
						when "10" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData(11 downto  8) & CfgGSF_Hd(2 downto 0);
						when "11" => 
						MEM_Adr  <= CfgGSF_Hd(11 downto 7) & MEM_RdData( 3 downto  0) & CfgGSF_Hd(2 downto 0);
						when others => null;
						end case;				
					end if;
				end if;
			--------------------------------------------------------------------
			--	End of GF
			--------------------------------------------------------------------
--			when sEnd_GF =>
			--------------------------------------------------------------------
			--	Ethernet end of packet
			--------------------------------------------------------------------
			-- Da es probleme mit diesem Addieren gegeben hat, benutze ich jetzt
			-- zwei States zum addieren. Dann reicht die zeit sicher.
--			when sETH_CRC_H =>   
--			when sETH_CRC_H =>   
			when sETH_IP_UDPEnd =>
				if (g_Tunnel/=0 and ExtData=H) then
					if (Mac2Tun_send=H) then
						MEM_Adr  <= CfgExtTxCnt;
					else
						MEM_Adr  <= CfgExtCnt;
					end if;
				else
					MEM_Adr  <= CfgGF_Cnt;
				end if;

			when sEnd_AddGFcnt =>   
                MEM_WrData <= MEM_RdData_P1;
				if (dQ62_5 = L) then
					MEM_WR <= H;
    			end if;

			--------------------------------------------------------------------
			-- Show act-slot-nr
			--------------------------------------------------------------------
			when sEnd_ShowSlot =>   
				MEM_Adr  <= CfgActSlot;
                MEM_WrData <= x"000000" &"0000" & ActSlot;
				if (dQ62_5 = L) then
					if (g_Tunnel/=0) then
						MEM_WR <= not ExtData;
					else
						MEM_WR <= H;
					end if;
				end if;   
				
			when others => null; ----------------------------------------------- 
			end case;
    end process;
    
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	asynchron TxData
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
    
--	we need this unclocked TxData to build the realtime-CRC, 
--	which includes also the running CRC in the new CRC
--	!! lass es wie es ist, es geht nicht anders !!	

	TxLowData <= TxLowDataZ1 when g_TX_DATA_Z1=1 else MEM_RdData(15 downto 0);
	TxHighData <= TxHighDataZ1 when g_TX_DATA_Z1=1 else MEM_RdData(31 downto 16);
	MEM_RdDataX <= TxHighData & TxLowData;

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			--if (RamSelectorZ1=H and g_TX_DATA_Z1=1) then
			--	TxHighDataZ1 <= i_DM_Data(31 downto 16);
			--	TxLowDataZ1 <= i_DM_Data(15 downto 0);
			--else
				TxHighDataZ1 <= MEM_RdData(31 downto 16);
				TxLowDataZ1 <= MEM_RdData(15 downto 0);
			--end if;
		end if;
	end process;

	process (GM_TxSeq,TxHighData,TxLowData,ActSlot,NrOfGSF,EthTxCRC,LxCRC32,ExtData,Mac2Tun_send) begin 
	   		TxCharIsK 	<= "11";
	   		TxData		<= x"0000";
			o_SlaveDone <= L;
    		case GM_TxSeq is  

			--------------------------------------------------------------------
			--	Eth , IP , UDP Header
			--------------------------------------------------------------------
			when sETH_Start =>	--- Send Eth Preamble --------------------------
				--  preamble /s/ 
	   			TxCharIsK 	<= "00";
				TxData 	<= TxHighData;
			
			when sETH_IP_UDP_H =>	--- Send EthFrame --------------------------
	   			TxCharIsK 	<= "00";
				TxData 	<= TxHighData;

			when sETH_IP_UDP_L =>	--- Send EthFrame --------------------------
	   			TxCharIsK 	<= "00";
				TxData 	<= TxLowData;

			when sETH_IP_UDP_LNG =>	--- Send EthFrame --------------------------
				TxCharIsK 	<= "00";
				if (g_Tunnel/=0 and ExtData=H) then
					TxData <= DF_EXT_UDP_LNG;
				else
					TxData 	<= TxLowData;
				end if;

			when sETH_IP_UDP_CSUM =>	--- Send EthFrame --------------------------
				TxCharIsK 	<= "00";
				TxData 	<= TxHighData;

			--------------------------------------------------------------------
			--	GinHeader Start A55A
			--------------------------------------------------------------------
			when sGF_StartOfFrame => --- Send GF_HeaderStart ------------------------
	   			TxCharIsK 	<= "00";
				TxData 	<= TxLowData;

			--------------------------------------------------------------------
			--	GinHeader Blink
			--------------------------------------------------------------------
			when sGF_HdBlink =>
	   			TxCharIsK 	<= "00";
				TxData 		<= TxHighData(15 downto 4) & ActSlot;
				
			--------------------------------------------------------------------
			--	GinHeader NrOfGinFrames
			--------------------------------------------------------------------
			when sGF_HdLen =>
				-- send NrOfGinFrames
	   			TxCharIsK 	<= "00";
				TxData 		<= "00000000000" & NrOfGSF;
				
			--------------------------------------------------------------------
			--	GinSubFrame Header
			--------------------------------------------------------------------
			when sGF_Sfty_H
				|sGSF_StartOfHeader
				|sGSF_Adr_H
				|sGSF_Len
				|sGSF_Sfty_H =>
				
	   			TxCharIsK 	<= "00";
				if (g_Tunnel/=0 and ExtData=H) then
					if (GM_TxSeq=sGF_Sfty_H) then
						TxData <= TxHighData;
					elsif (GM_TxSeq=sGSF_StartOfHeader) then
						TxData <= x"5AA5";
					elsif (GM_TxSeq=sGSF_Len) then
						TxData <= DF_EXT_GSF_LNG;
					else
						TxData <= x"0000";
					end if;
				else
					TxData <= TxHighData;
				end if;

			when sGF_Sfty_L
				|sGSF_Cmd
				|sGSF_Adr_L
				|sGSF_Int 
				|sGSF_Sfty_L => 
				
	   			TxCharIsK 	<= "00";
				if (g_Tunnel/=0 and ExtData=H) then
					if (GM_TxSeq=sGF_Sfty_L) then
						TxData <= TxLowData;
					elsif (GM_TxSeq=sGSF_Cmd) then
						TxData <= x"0008"; -- page 8, read or write command
						TxData(8) <= Mac2Tun_send;
						TxData(4) <= not Mac2Tun_send;
					else
						TxData <= x"0000";
					end if;
				else
					TxData <= TxLowData;
				end if;
			--------------------------------------------------------------------
			--	GinSubFrame Data
			--------------------------------------------------------------------
			when sGSF_StartOfData => 
				TxCharIsK <= "00";
				if (g_Tunnel/=0 and ExtData=H) then
					TxData <= x"DAAD";
				else
					TxData <= TxHighData;
				end if;

			when sGSF_Dat_H => 
				TxCharIsK <= "00";
				if (g_Tunnel/=0 and ExtData=H) then
					if (Mac2Tun_send=H) then
						TxData <= ExtTxData;
					else
						if (TunTxFirst=H) then
							-- DAAD for first come first serve or SlaveNr|0x8000 to select a Slave
							if (i_ManageRx=H) then
								o_SlaveDone <= H;
								TxData <= i_SlaveNr; -- only the addressed slave, takes it when he need it
							else
								TxData <= x"DAAD"; -- the first slave, who needs it, takes it
							end if;
						else
							TxData <= x"0000";
						end if;
					end if;
				else
					TxData <= TxHighData;
				end if;
			
			when sGSF_Dat_L => 
				TxCharIsK <= "00";
				if (g_Tunnel/=0 and ExtData=H) then
					if (Mac2Tun_send=H) then
						TxData <= ExtTxData;
					else
						TxData <= x"0000";
					end if;
				else
					TxData <= TxLowData;
				end if;
			
			--------------------------------------------------------------------
			--	GinSubFrame Slave Atached
			--------------------------------------------------------------------
			when sGSF_Sla =>
	   			TxCharIsK 	<= "00";
				TxData 		<= x"0000"; 
			
			--------------------------------------------------------------------
			--	wait untill UDP-Lenght reached
			--------------------------------------------------------------------
			when sWaitUdpEnd => 
	   			TxCharIsK 	<= "00";
				TxData 		<= x"0000"; 

			--------------------------------------------------------------------
			-- CRC's
			--------------------------------------------------------------------
			when sEth_HdCRC_H
			   | sGF_HdCRC_H
			   | sGSF_HdCRC_H
			   | sGSF_DatCRC_H 
			   | sETH_CRC_H =>
	   			TxCharIsK 	<= "00"; 
	   			TxData <= EthTxCRC(31 downto 16);
			
			when sEth_HdCRC_L
			   | sGF_HdCRC_L
			   | sGSF_HdCRC_L
			   | sGSF_DatCRC_L
			   | sETH_CRC_L =>
	   			TxCharIsK 	<= "00";
	   			TxData <= LxCRC32(15 downto 0);
			
			--------------------------------------------------------------------
			--	Ethernet end of packet
			--------------------------------------------------------------------
			when sETH_IP_UDPEnd =>   
		   		TxCharIsK 	<= "11";
				TxData 		<= x"0000";             	-- EOP, Extend

			when others => null; ----------------------------------------------- 
			end case;

    end process;
	
--------------------------------------------------------------------------------
--	CRC-generator
--------------------------------------------------------------------------------
	uTxSeq_TxCRC: entity gin_link.GIN_Eth_CRC_D16 
	PORT MAP(
		i_Q62_5		=> i_Q62_5    ,
	    i_Data	    => TxData     ,
	    i_CrcClr    => EthCrcClr  ,
	    i_CrcRun    => EthCrcRun  ,
	    o_EthCRC    => EthTxCRC
	);
	EthCrcRun <= H;
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
       		LxCRC32 <= EthTxCRC;
		end if;
	end process;		
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
