-- Module BSAT Control
-- VHDL Architecture Indel_lib.BSAT_Control.Universal
--
-- InfoLink, GinLink Copyright (c): INDEL AG
-- BSAT (c): Besi Switzerland
--
-- Project:   Dragon GinLink/ BSAT Integration
-- 
-- qfu, 216
-- 16.05.2016
-- This entity is the wrapper for the BSAT Master functionality
-- 
--
-- 
--
--
--
-- History:
--	1.	Initial version
--	2.	Draft 0.1, I/O access only, 30.01.2018
--	3.	Swapped 32Bit words (low/ high 16Bit) based on the fact that we are now looking at them  as 2x32Bit, 19.02.2018
--	4.	Integrated the S-Port functionality from 2016 and made some adjustements.
--	5.	New feature: we are now delaying the S-Port access if a IO accesses are within th same COP burst till all IO accesses
--		are terminated. This way round we can omit additional jitter because S-Port accesses are only partially aiming
--		into the BSAT space, 22.02.2018.
--	6.	We allow now communication to the BSAT's even if the board with the BSAT master was not identified successfully by the mc master.
--	7.	Changes that the bus is even running theoretically @16kHz with 8 modules (this means 8 modules + 1 S-Port).
--	8.	Scanning functionality adapted: Now it is done with a dedicated BSAT-CMD. This way round we can add features easier in the future. 
--	9.	Updated/ enhanced the scanning features. Now the supply mode of the BSAT can be chosen and the scanning can be controlled via software, too. (QFU, 28.11.2018)
--	10.	Corrected bug concerning "BSAT_Supply" mode: Wait for the defined delay in each case! (sBusScan state Master FSM) (QFU, 14.01.2020)
--
--
-- 
------------------------------------------------------------------------------
--$Rev:: 5535                                                                $
--$Author:: qfu_m                                                            $
--$Date:: 2020-03-20 10:52:01 +0100 (Fr., 20 MÃ¤r 2020)                      $
------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.GinLink_Package.all;
USE Indel_lib.Besi_Package.all;
USE Indel_lib.BSAT_Package.all;

ENTITY BSAT_Control IS
    GENERIC (
			BSAT_Supply						: natural RANGE 0 TO 2:= 1; -- 0 = The BSAT gets it power directly, 1 = from a PROFET that is always active, 2 = Power is controlled via "PlugPlay_Node_OE" of the Hammer.
            BSAT_CFG_Core_Role				: natural RANGE 0 TO 1:= 0;
			BSAT_CFG_Core_Oversampling		: natural RANGE 0 TO 8:= 8;
			BSAT_CFG_Core_DS_Coding			: natural RANGE 0 TO 1:= 1;
			BSAT_CFG_Core_IO_Mode			: natural RANGE 0 TO 1:= 0;
			BSAT_CFG_Core_TX_Debug			: natural RANGE 0 TO 1:= 0;
			BSAT_CFG_Core_RX_Debug			: natural RANGE 0 TO 1:= 0;
			BSAT_CFG_FSM_IO_Word_Width		: natural RANGE 0 TO 2:= 2;
			BSAT_CFG_FSM_RAM_Word_width		: natural RANGE 0 TO 2:= 0;
			BSAT_CFG_FSM_S_Port_EN			: natural RANGE 0 TO 1:= 1;
			BSAT_CFG_FSM_EXCEPT_Mode		: natural RANGE 0 TO 1:= 1
			);
    PORT    (
            CLK250					: IN 	std_logic;
            CLK125					: IN	std_logic;
			CLK62_5					: IN	std_logic;
            CLR_n_CLK125			: IN	std_logic;
			CLR_n_CLK62_5        	: IN	std_logic;  -- 62.5MHz reset
			-- BSAT external signals
            BSAT_Serial_TX_EN		: OUT	std_logic:= '0'; -- BSAT driver enable
		    BSAT_Serial_TX			: OUT	std_logic:= '1'; -- BSAT TX data output
		    BSAT_Serial_RX_nEN		: OUT	std_logic:= '0'; -- BSAT RX output not enable 
			BSAT_Serial_RX			: IN	std_logic;
			-- BSAT interface
            BSAT_WR_AD				: OUT	std_logic_vector(2 DOWNTO 0):= "111"; -- D: COP to SAT
            BSAT_WR_Data			: IN	std_logic_vector(63 DOWNTO 0); -- D: COP to SAT
            BSAT_WR_ST				: IN	std_logic_vector(7 DOWNTO 0);
			BSAT_WR_Word			: IN	std_logic_vector(4 DOWNTO 0);
            BSAT_RD_AD				: OUT	std_logic_vector(2 DOWNTO 0):= "111";
            BSAT_RD_WREN			: OUT	std_logic:= '0'; -- D: SAT to COP
            BSAT_RD_Data			: OUT	std_logic_vector(63 DOWNTO 0):= (OTHERS => '0');-- D: SAT to COP
			-- BSAT Bus Control
			BSAT_Bus_Control		: IN	std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');
            -- The slow S-Port data for the the BSAT's
            BSAT_Status_In			: OUT	std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');
			BSAT_Sum_Errors			: OUT	std_logic_vector(31 DOWNTO 0);
            BSAT_AD_RDY				: IN	std_logic:= '0';
            BSAT_WR_RD_n			: IN	std_logic:= '0';
            BSAT_Address			: IN	std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');
            BSAT_Data_RDY			: IN	std_logic:= '0';
            BSAT_Data_Out			: IN	std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');
            BSAT_Data_In			: OUT	std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');
			-- Hammer ready for BSAT Scan Initialization
			BSAT_Scan_Init_EN		: IN	std_logic;
			-- Scanning results for the m/c SW
			BSAT_Scan_Result		: OUT	std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');	-- Was a BSAT module found during scanning?- Mapped to address 0x1F0B.
			-- "Summary Bit" of all the "HID_Changed" Bits of the BSAT slaves.
			BSAT_HID_changed		: OUT std_logic:= '0'
            );
END BSAT_Control;


ARCHITECTURE Universal OF BSAT_Control IS
   
	------------------------
	-- COMPONENT Declaration
	------------------------
	COMPONENT BSAT_Core
	GENERIC	(
			BSAT_Core_Role				: natural RANGE 0 TO 1:= 1; -- Slave = 1, Master = 0,
			BSAT_Oversampling			: natural RANGE 0 TO 15:= 8;
			BSAT_DS_Decoding			: natural RANGE 0 TO 1:= 0;
			BSAT_IO_Mode_EN      		: natural RANGE 0 TO 1:= 0;
			BSAT_TX_Debugging			: natural RANGE 0 TO 1:= 1; -- Allows to instantiate a signal that shows the actual 16bit TX data.
			BSAT_RX_Debugging			: natural RANGE 0 TO 1:= 1 -- Allows to instantiate a signal that shows the actual 16bit RX data.
			);
	PORT	(
			CLK125						: IN	std_logic;
			CLK250						: IN	std_logic:= '0'; -- This is an aditional clock that can be used as fast source for the the InfoLink encoder and decoder only (higher oversampling).
            CLR_n_CLK125				: IN  	std_logic;
			-- BSAT external bus signals
            BSAT_Serial_TX_EN			: OUT	std_logic:= '0'; -- BSAT driver enable, has to be connected to the external RS485 transmitter.
		    BSAT_Serial_TX_Data			: OUT	std_logic:= '1'; -- BSAT TX data output.
			BSAT_Serial_RX_nEN			: OUT	std_logic:= '0'; -- Could perhaps be used for short/ open detection with certain receivers...
		    BSAT_Serial_RX_Data			: IN	std_logic;
			-- BSAT external module signals
			BSAT_Module_AD				: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0):= (OTHERS => '1'); -- Address switch input signal.
			-- BSAT status signals
			BSAT_Transfer_Start  		: IN  	std_logic:= '0';
			BSAT_Ready           		: OUT	std_logic;
			-- BSAT FSM status signals
			BSAT_RX_FSM_Status			: OUT	bsat_s_rx_fsm_bundle_t_bs_pkg:= NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG;
			BSAT_TX_FSM_Status			: OUT	bsat_s_tx_fsm_bundle_t_bs_pkg:= NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG;
			-- BSAT complete interface
			BSAT_MS						: INOUT bsat_prtcl_ms_bundle_t_bs_pkg:= NA_BSAT_PRTCL_MS_BUNDLE_C_BS_PKG;
			BSAT_SM						: INOUT bsat_prtcl_sm_bundle_t_bs_pkg:= NA_BSAT_PRTCL_SM_BUNDLE_C_BS_PKG;
			-- BSAT IO signals
			BSAT_IO_Port_In				: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0):= (OTHERS => '0');
			BSAT_IO_Port_Out			: OUT	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0)
			);
	END COMPONENT BSAT_Core;
	
	
	COMPONENT Safety_Counter --For GinLink Slave (passive)
	PORT	(
			CLK125                     	: IN	std_logic; -- 125 MHz CLK
			CLK62_5                    	: IN	std_logic; -- 62.5 MHz CLK
			CLR_n   	               	: IN	std_logic;
			GinLink_Safety				: IN	std_logic_vector(31 DOWNTO 0);
			GinWDog						: IN	std_logic_vector(7 DOWNTO 0);
			Gin_Safety_WDog_CLK62_5		: OUT	std_logic;
			Gin_Safety_WDog_CLK125		: OUT	std_logic;
			Gin_Safety_WDog_PLS_CLK62_5	: OUT	std_logic;
			Gin_Safety_WDog_PLS_CLK125	: OUT	std_logic
			);
	END COMPONENT Safety_Counter;
	
	
	
	
	-- PRAGMA SYNTHESIS_OFF
	FOR ALL : BSAT_Core USE ENTITY Indel_lib.BSAT_Core;
	FOR ALL : Safety_Counter USE ENTITY Indel_lib.Safety_Counter;
	-- PRAGMA SYNTHESIS_ON
	----------------------------
	-- COMPONENT Declaration END
	----------------------------
	
	
	------------------------------------------------------
	-- Constant Declarations for Architecture B_SAT_Master
	------------------------------------------------------
	CONSTANT BSAT_Status_Present		: std_logic:= '1'; -- Is always the case when the BSAT_Control entity is instantiated...
	CONSTANT BSAT_Supply_Mode			: std_logic_vector(1 DOWNTO 0):= (STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_Supply,2)));
	----------------------------------------------------------
	-- Constant Declarations for Architecture B_SAT_Master END
	----------------------------------------------------------
	
	
	---------------------------------------------------
	-- Signal Declaration for Architecture BSAT_Master
	---------------------------------------------------
	SIGNAL CLR_n                      	: std_logic;
	SIGNAL Test_Counter                	: natural;
	SIGNAL BSAT_Transfer_Start         	: std_logic;
	SIGNAL BSAT_Ready                  	: std_logic;
	SIGNAL BSAT_Transfer_Running       	: std_logic;
	
	-- Status signals for address 0x1F0B in the S-Port memory map
	SIGNAL BSAT_Status_Addresses_Used	: std_logic_vector(7 DOWNTO 0):= "00000000";
	SIGNAL BSAT_Status_TX_Line_Error	: std_logic:= '0';
	SIGNAL BSAT_Status_RX_Line_Error	: std_logic:= '0';
	SIGNAL BSAT_Status_Timeout			: std_logic:= '0';
	SIGNAL BSAT_Status_Scan_Done		: std_logic:= '0';
	SIGNAL BSAT_Status_Bus_Info			: std_logic:= '0';
	
	-- Local BSAT HID_Changed signal
	SIGNAL BSAT_HID_Changed_Slaves		: std_logic_vector(7 DOWNTO 0):= (OTHERS => '0');
	
	-- The Broadcast word
	SIGNAL BSAT_BRCT_Data_Word			: std_logic_vector(63 DOWNTO 0):= (OTHERS => '0');
	
	-- Test signals
	SIGNAL BSAT_Test_Output0			: std_logic:= '0';
	SIGNAL BSAT_Test_Output2			: std_logic:= '0';
	SIGNAL BSAT_Test_Output2_Int		: std_logic:= '0';
	SIGNAL BSAT_Bus_Control_Int			: std_logic_vector(15 DOWNTO 0):= (OTHERS => '0');
	SIGNAL Rescan_Request				: std_logic;
	SIGNAL Rescan_Acknowledge			: std_logic;
	SIGNAL BusScan_Start_Delay_Expired	: std_logic:= '0';
	-------------------------------------------------------
	-- Signal Declaration for Architecture BSAT_Master END
	-------------------------------------------------------
	
	
	
BEGIN

	-- Concurrent 0
	CLR_n <= CLR_n_CLK125;
	
	-- Concurrent 1
	BSAT_Scan_Result <= (BSAT_Status_Present & BSAT_Status_Bus_Info & BSAT_Supply_Mode & BSAT_Status_Scan_Done & BSAT_Status_Timeout & BSAT_Status_RX_Line_Error & BSAT_Status_TX_Line_Error & BSAT_Status_Addresses_Used);
	
	-- Concurrent 2
	BSAT_Status_In(14 DOWNTO 0) <= ("111" & x"373");
	
	-- Concurrent 3
	BSAT_BRCT_Data_Word <= (OTHERS => '0');
	
	-- Concurrent 4 Debug output for Dieter:
	Register_the_Test_Signal: PROCESS(CLK125, CLR_n)
	BEGIN
		IF (CLR_n = '0') THEN
			BSAT_Test_Output2_Int <= '0';
		ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
			BSAT_Test_Output2_Int <= (NOT(BSAT_Test_Output2_Int) AND BSAT_Test_Output2);
		END IF;
	END PROCESS Register_the_Test_Signal;
	

	
	------------------
	-- Resync Scanning
	-----------------
	Resync_Scan: PROCESS(CLK125, CLR_n)
	BEGIN
		IF (CLR_n = '0') THEN
			BSAT_Bus_Control_Int <= (OTHERS => '0');
		ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
			BSAT_Bus_Control_Int <= BSAT_Bus_Control;
		END IF;
	END PROCESS Resync_Scan;
	----------------------
	-- Resync Scanning END
	----------------------
	
	
	-------------
	-- B_SAT Core
	-------------
	Instantiate_BSAT_Master_Core: IF (ON_C_I_PKG = ON_C_I_PKG) GENERATE
	
		-------------------
		-- Type Declaration
		-------------------
		TYPE bsat_controller_state IS
			(
			sInit,
			sBusScan,
			sBusScan_Waiting,
			sBusScan_End,
			sIdle,
			sIO_RD_WR,
			sIO_RD_WR_Waiting,
			sRAM_RD,
			sRAM_WR,
			sRAM_SPORT,
			sRAM_SPORT_Waiting
			);
		-----------------------
		-- Type Declaration END
		-----------------------
	
	
		-----------------------
		-- CONSTANT Declaration
		-----------------------
		CONSTANT	BSAT_Core_CFG				:	bsat_cfg_core_bundle_t_bs_pkg := (BSAT_CFG_Core_Role,BSAT_CFG_Core_Oversampling,BSAT_CFG_Core_DS_Coding,BSAT_CFG_Core_IO_Mode,BSAT_CFG_Core_TX_Debug,BSAT_CFG_Core_RX_Debug);
		CONSTANT	BSAT_FSM_CFG				:	bsat_cfg_ctrl_bundle_t_bs_pkg := (BSAT_CFG_FSM_IO_Word_Width,BSAT_CFG_FSM_RAM_Word_width,BSAT_CFG_FSM_S_Port_EN,BSAT_CFG_FSM_EXCEPT_Mode);
		CONSTANT	BSAT_Control_CFG			:	bsat_cfg_ctrl_top_bundle_t_bs_pkg := (BSAT_Core_CFG,BSAT_FSM_CFG);
		---------------------------
		-- CONSTANT Declaration END
		---------------------------
		
		
		---------------------
		-- SIGNAL Declaration
		---------------------
		SIGNAL	BSAT_MS_Data					:	bsat_prtcl_ms_bundle_t_bs_pkg:= NA_BSAT_PRTCL_MS_BUNDLE_C_BS_PKG;
		SIGNAL	BSAT_SM_Data					:	bsat_prtcl_sm_bundle_t_bs_pkg:= NA_BSAT_PRTCL_SM_BUNDLE_C_BS_PKG;
		SIGNAL	BSAT_TX_FSM_Status				:	bsat_s_tx_fsm_bundle_t_bs_pkg:= NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG;
		SIGNAL	BSAT_RX_FSM_Status				:	bsat_s_rx_fsm_bundle_t_bs_pkg:= NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG;
		SIGNAL	BSAT_IO_Transfer_AD_Array		:	bsat_access_AD_sequence_t_bs_pkg(Besi_BSAT_Count_C_B_PKG DOWNTO 0):= (OTHERS => (OTHERS => '0')); -- QFU, 28.06.2018
		SIGNAL	BSAT_IO_Feeder_SEQ_Counter		:	natural RANGE 0 TO 7:= 0;
		SIGNAL	BSAT_IO_Teaser_SEQ_Counter		:	natural RANGE 0 TO 15:= 0;
		SIGNAL	BSAT_IO_ACT_Transfer_Counter	:	natural RANGE 0 TO 7:= 0;
		SIGNAL	BSAT_Ctrl_Seq_State				:	bsat_controller_state;
		SIGNAL	New_IO_Transfer					:	std_logic:= '0';
		SIGNAL	NEW_RAM_Transfer				:	std_logic:= '0';
		SIGNAL	New_SPort_Transfer				:	std_logic:= '0';
		SIGNAL	IO_Transfer_Running				:	std_logic:= '0';
		SIGNAL	IO_Transfer_Running_Int			:	std_logic:=	'0';
		SIGNAL	IO_BRCT_Lock					:	std_logic:=	'0'; -- We allow S-Port accesses to BSAT's even if the Hammer is not identified!
		SIGNAL	SPort_Transfer_Running			:	std_logic:= '0';
		SIGNAL	SPort_Transfer_Running_Int		:	std_logic:=	'0';
		SIGNAL	IO_Address						:	std_logic_vector(3 DOWNTO 0);
		SIGNAL	BSAT_RD_Data_Int				:	std_logic_vector(63 DOWNTO 0);
		SIGNAL	BSAT_MS_CMD_SPort				:	std_logic_vector(3 DOWNTO 0);
		SIGNAL	SPort_COP_BSAT_Info				:	std_logic_vector(47 DOWNTO 0);
		SIGNAL	SPort_BSAT_COP_Info				:	std_logic_vector(47 DOWNTO 0);
		SIGNAL	SPort_BSAT_Data_Ready			:	std_logic;
		SIGNAL	Init_Delayed_SPort_Transfer		:	std_logic:= '0';
		SIGNAL	SPort_Delay_Counter				:	natural RANGE 0 TO 127:= 63;--84
		SIGNAL	RX_Data_Ready_Int				:	std_logic:= '0';
		SIGNAL	P_RX_FSM_Data_Ready				:	std_logic:= '0';
		SIGNAL	BusScan_Counter					:	natural RANGE 0 TO 7:= 0;
		SIGNAL	BusScan_Running					:	std_logic:= '0';
		SIGNAL	BusScan_Synched					:	std_logic:= '0';
		-------------------------
		-- SIGNAL Declaration END
		-------------------------
		
		

		
	BEGIN
		
		
		-----------------------------------
		-- The BSAT_Core in the Master role
		-----------------------------------
		BSAT_Master_Core: BSAT_Core
		GENERIC MAP		(
						BSAT_Core_Role			=> BSAT_Control_CFG.Core.Core_Role, -- Slave = 1, Master = 0,
						BSAT_Oversampling		=> BSAT_Control_CFG.Core.Oversampling,
						BSAT_DS_Decoding		=> BSAT_Control_CFG.Core.DS_Decoding,
						BSAT_IO_Mode_EN      	=> BSAT_Control_CFG.Core.IO_Mode, -- Simple I/O-Mode active?
						BSAT_TX_Debugging		=> BSAT_Control_CFG.Core.TX_Debugging, -- Allows to instantiate a signal that shows the actual 16bit TX data.
						BSAT_RX_Debugging		=> BSAT_Control_CFG.Core.RX_Debugging -- Allows to instantiate a signal that shows the actual 16bit RX data.
						)
		PORT MAP		(
						CLK125					=> CLK125,
						CLK250					=> CLK250, -- This is an aditional clock that can be used as fast source for the the InfoLink encoder and decoder only (higher oversampling).
						CLR_n_CLK125			=> CLR_n_CLK125,
						-- BSAT external bus signals
						BSAT_Serial_TX_EN		=> BSAT_Serial_TX_EN, -- BSAT driver enable, has to be connected to the external RS485 transmitter.
						BSAT_Serial_TX_Data		=> BSAT_Serial_TX, -- BSAT TX data output.
						BSAT_Serial_RX_nEN		=> BSAT_Serial_RX_nEN,
						BSAT_Serial_RX_Data		=> BSAT_Serial_RX,
						-- BSAT external module signals
						BSAT_Module_AD			=> (OTHERS => '1'), -- Address switch input signal.
						-- BSAT status signals
						BSAT_Transfer_Start 	=> BSAT_Transfer_Start, --*************: M/S?????
						BSAT_Ready          	=> BSAT_Ready, --*************: M/S?????
						-- BSAT FSM status signals
						BSAT_RX_FSM_Status		=> BSAT_RX_FSM_Status,
						BSAT_TX_FSM_Status		=> BSAT_TX_FSM_Status,
						-- BSAT complete interface
						BSAT_MS					=> BSAT_MS_Data,
						BSAT_SM					=> BSAT_SM_Data,
						-- BSAT IO signals
						BSAT_IO_Port_In			=> (OTHERS => '0'),
						BSAT_IO_Port_Out		=> OPEN
						);
		---------------------------------------
		-- The BSAT_Core in the Master role END
		---------------------------------------
		
		-- Concurrent 0, WR data
		-- Do it again for the data that is written to the COP bus.- It is really needed 2 times, sot that it matches the INCO representation.
		BSAT_RD_Data <= (BSAT_RD_Data_Int(47 DOWNTO 32) & BSAT_RD_Data_Int(63 DOWNTO 48) & BSAT_RD_Data_Int(15 DOWNTO 0) & BSAT_RD_Data_Int(31 DOWNTO 16));
		
		-- Concurrent 1, RX debug data
		BSAT_Test_Output0 <= BSAT_SM_Data.Data_CRC.CRC_Error;
		BSAT_Test_Output2 <= BSAT_SM_Data.Data_CRC.CRC_OK;
		
		
		
		-- Concurrent 3
		BSAT_Status_In(15) <= SPort_BSAT_Data_Ready; -- The data is ready for GinLink...
		
		---!!-----------
		----------!!----
		-- No 64Bit RAM access planned?
		New_RAM_Transfer <= '0';
		---!!-----------
		----------!!----
		
		
		------------------
		-- BSAT Master FSM
		------------------
		BSAT_Master_Controller: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				BSAT_Ctrl_Seq_State <= sInit;
				BSAT_Transfer_Start <= '0';
				IO_Transfer_Running <= '0';
				SPort_Transfer_Running <= '0';
				BSAT_IO_Teaser_SEQ_Counter <= 0;
				BSAT_IO_ACT_Transfer_Counter <= 0;
				BSAT_WR_AD <= (OTHERS => '0');
				BSAT_Status_Scan_Done <= '0';
				BusScan_Counter <= 0;
				BusScan_Running <= '0';
				BSAT_Status_RX_Line_Error <='0';
				BSAT_Status_Scan_Done <= '0';
				BSAT_Status_Addresses_Used <= (OTHERS => '0');
				BusScan_Synched <= '0';
				Rescan_Acknowledge <= '0';
				BSAT_MS_Data.Header.CMD <= BSAT_MS_CMD_BRCT_C_BS_PKG; -- We are sending a BRCT in the error case...
				BSAT_MS_Data.Header.AD <= (OTHERS => '0');
				BSAT_MS_Data.Header.PARAM <= (OTHERS => '0');
				BSAT_MS_Data.Data.Data_value <= (OTHERS => '0');
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				CASE BSAT_Ctrl_Seq_State IS
					WHEN sInit =>
						BSAT_Ctrl_Seq_State <= sBusScan;
						Rescan_Acknowledge <= '0';
						BusScan_Counter <= 0;
						BSAT_Status_RX_Line_Error <='0';
						BusScan_Synched <= '0';
					WHEN sBusScan =>
						IF (BusScan_Start_Delay_Expired = '1') THEN
							BSAT_Ctrl_Seq_State <= sBusScan_Waiting;
							BSAT_Transfer_Start <= '1';
						ELSE
							BSAT_Ctrl_Seq_State <= sBusScan;
							BSAT_Transfer_Start <= '0';
						END IF;
						BusScan_Running <= '1';
						BSAT_Status_Scan_Done <= '0';
						BSAT_MS_Data.Header.CMD <= BSAT_MS_CMD_Scan_C_BS_PKG;
						BSAT_MS_Data.Header.AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(BusScan_Counter,BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
						BSAT_MS_Data.Header.PARAM <= (OTHERS => '0');
						BSAT_MS_Data.Data.Data_value <= (OTHERS => '0');
					WHEN sBusScan_End =>
						BSAT_Ctrl_Seq_State <= sIdle;
						BSAT_Status_Scan_Done <= '1';
						BSAT_Transfer_Start <= '0';
						BusScan_Running <= '0';
					WHEN sIdle =>
						IF (New_IO_Transfer = '1') THEN
							BSAT_Ctrl_Seq_State <= sIO_RD_WR;
							IO_Transfer_Running <= '1';
							BSAT_WR_AD <= BSAT_IO_Transfer_AD_Array(BSAT_IO_Teaser_SEQ_Counter)(2 DOWNTO 0);
						ELSIF (New_SPort_Transfer = '1') THEN
							BSAT_Ctrl_Seq_State <= sRAM_SPort;
							SPort_Transfer_Running <= '1';
						ELSE
							-- We can reinitiate a BSAT bus scan with this command...
							IF ((BSAT_Bus_Control_Int(0) = '1') OR (Rescan_Request = '1')) THEN----
								BSAT_Ctrl_Seq_State <= sInit;
								Rescan_Acknowledge <= '1';
							ELSE
								BSAT_Ctrl_Seq_State <= sIdle;
								BSAT_Transfer_Start <= '0';
								IO_Transfer_Running <= '0';
								SPort_Transfer_Running <= '0';
								BSAT_WR_AD <= BSAT_WR_Word(4 DOWNTO 2);
								BSAT_IO_Teaser_SEQ_Counter <= 0;
								BSAT_IO_ACT_Transfer_Counter <= 0;
							END IF;
						END IF;
					WHEN sIO_RD_WR =>
						BSAT_Ctrl_Seq_State <= sIO_RD_WR_Waiting;
						BSAT_MS_Data.Header.CMD <= BSAT_MS_CMD_IO_WR_RD_C_BS_PKG;
						BSAT_MS_Data.Header.AD <= BSAT_IO_Transfer_AD_Array(BSAT_IO_Teaser_SEQ_Counter)(3 DOWNTO 0);
						BSAT_MS_Data.Header.PARAM <= (OTHERS => '0');
						IF (BSAT_IO_Transfer_AD_Array(BSAT_IO_Teaser_SEQ_Counter)(5)) = '1' THEN -- It is a BRCT...do just send the BRCT word.
							BSAT_MS_Data.Data.Data_value <= BSAT_BRCT_Data_Word;
						ELSE
							BSAT_MS_Data.Data.Data_value <= (BSAT_WR_Data(47 DOWNTO 32) & BSAT_WR_Data(63 DOWNTO 48) & BSAT_WR_Data(15 DOWNTO 0) & BSAT_WR_Data(31 DOWNTO 16));
						END IF;	
						BSAT_Transfer_Start <= '1';
						BSAT_IO_Teaser_SEQ_Counter <= (BSAT_IO_Teaser_SEQ_Counter + 1);
					WHEN sIO_RD_WR_Waiting =>
						IF (BSAT_IO_Teaser_SEQ_Counter = 9) THEN
							BSAT_Ctrl_Seq_State <= sIdle;
							IO_Transfer_Running <= '0';
							BSAT_IO_Teaser_SEQ_Counter <= 0;
							BSAT_Transfer_Start <= '0';
						ELSIF (BSAT_Ready = '1') THEN -- TX path of the master...
							CASE  BSAT_IO_Transfer_AD_Array(BSAT_IO_Teaser_SEQ_Counter)(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG + 2) DOWNTO BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) IS
								WHEN "00"	=> -- No broadcast, no next transfer
									IF (BSAT_RX_FSM_Status.RX_Active = '0') THEN -- Ongoing transfer failing
										BSAT_Ctrl_Seq_State <= sIdle; -- Terminate, no further IO accesses scheduled.
										IO_Transfer_Running <= '0';
										BSAT_IO_Teaser_SEQ_Counter <= 0;
									ELSE
										BSAT_Ctrl_Seq_State <= sIO_RD_WR_Waiting; -- Ongoing transfer working
									END IF;
								WHEN "01"	=> -- No broadcast, next transfer
									IF (BSAT_RX_FSM_Status.RX_Active = '0') THEN -- Ongoing transfer failing
										BSAT_IO_ACT_Transfer_Counter <= (BSAT_IO_ACT_Transfer_Counter + 1); -- Do not store the RX data from bus.
									END IF;
									BSAT_Ctrl_Seq_State <= sIO_RD_WR;
								WHEN "11" | "10"	=> -- Broadcast, next transfer| broadcast, no next transfer => error
									BSAT_Ctrl_Seq_State <= sIdle;
									IO_Transfer_Running <= '0';
									BSAT_IO_Teaser_SEQ_Counter <= 0;
								WHEN OTHERS =>
									NULL;
							END CASE;
						ELSIF ((P_RX_FSM_Data_Ready = '1') AND (IO_Transfer_Running = '1')) THEN -- RX path of the master...
							IF (BSAT_IO_Transfer_AD_Array(BSAT_IO_ACT_Transfer_Counter)(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG + 1)) = '0') THEN -- QFU, 28.06.2018
								BSAT_Ctrl_Seq_State <= sIdle;
								IO_Transfer_Running <= '0';
								BSAT_IO_Teaser_SEQ_Counter <= 0;
							ELSE
								BSAT_IO_ACT_Transfer_Counter <= (BSAT_IO_ACT_Transfer_Counter + 1);
							END IF;
						END IF;
						-- If the actually addressed slave does not answer, we have to skip this transfer...
						IF ((BSAT_RX_FSM_Status.RX_Active = '0') AND (BSAT_Ready = '1')) THEN
							BSAT_IO_ACT_Transfer_Counter <= (BSAT_IO_ACT_Transfer_Counter + 1);
						END IF;
						BSAT_WR_AD <= BSAT_IO_Transfer_AD_Array(BSAT_IO_Teaser_SEQ_Counter)(2 DOWNTO 0);
						BSAT_Transfer_Start <= '0';
					WHEN sRAM_RD =>
						BSAT_Ctrl_Seq_State <= sIdle;
					WHEN sRAM_WR =>
						BSAT_Ctrl_Seq_State <= sIdle;
					WHEN sRAM_SPORT =>
						BSAT_Ctrl_Seq_State <= sRAM_SPORT_Waiting;
						BSAT_MS_Data.Header.CMD <= BSAT_MS_CMD_SPort;
						BSAT_MS_Data.Header.AD <= BSAT_Address(11 DOWNTO 8);
						BSAT_MS_Data.Header.PARAM <= BSAT_Address(7 DOWNTO 0);
						BSAT_MS_Data.Data.Data_value <= (SPort_COP_BSAT_Info(47 DOWNTO 0) & BSAT_Data_Out);
						BSAT_Transfer_Start <= '1';
					WHEN sRAM_SPORT_Waiting =>
						IF ((BSAT_RX_FSM_Status.Data_Ready = '1') AND (SPort_Transfer_Running = '1')) THEN
							BSAT_Ctrl_Seq_State <= sIdle;
							SPort_Transfer_Running <= '0';
						ELSIF ((BSAT_Ready = '1') AND (BSAT_RX_FSM_Status.RX_Active = '0')) THEN -- No answer from the addressed slave, abort transfer, inform master...
							BSAT_Ctrl_Seq_State <= sIdle;
							SPort_Transfer_Running <= '0';
							--BSAT_Transfer_Abort(AD)....
						ELSIF (BSAT_RX_FSM_Status.Data_CRC_Error = '1') THEN
							BSAT_Ctrl_Seq_State <= sIdle;
							SPort_Transfer_Running <= '0';
							--BSAT_TRansfer_Abort(AD)
						END IF;
						BSAT_Transfer_Start <= '0';
					WHEN sBusScan_Waiting =>
						-- Opt. A: There is a slave @address x answering the request, opt. B: no slave @address y returns an answer.
						IF (((P_RX_FSM_Data_Ready = '1') AND (BusScan_Running = '1')) OR ((BSAT_Ready = '1') AND (BSAT_RX_FSM_Status.RX_Active = '0'))) THEN
							BSAT_Status_Addresses_Used(BusScan_Counter) <= P_RX_FSM_Data_Ready; -- Slave x answered our request...
							IF (BusScan_Counter = Return_Upper_F_I_PKG(Besi_BSAT_Count_C_B_PKG)) THEN
								BusScan_Counter <= 0;
								-- a.) BSAT synched, b.) at least one slave returned an answer or c.) no answer and "Scan Abord" requested by SW...
								IF ((BusScan_Synched = '1') AND (((P_RX_FSM_Data_Ready & BSAT_Status_Addresses_Used(6 DOWNTO 0)) /= x"00") OR (BSAT_Bus_Control_Int(1) = '1'))) THEN
									BusScan_Running <= '0';
									BSAT_Ctrl_Seq_State <= sBusScan_End;
								ELSE
									BSAT_Ctrl_Seq_State <= sBusScan;
									BusScan_Synched <= '1';
								END IF;
							ELSE
								BusScan_Counter <= (BusScan_Counter +1);
								BSAT_Ctrl_Seq_State <= sBusScan;
							END IF;
						END IF;
						BSAT_Transfer_Start <= '0';
					WHEN OTHERS =>
						NULL;
				END CASE;
			END IF;
		END PROCESS BSAT_Master_Controller;
		
		
		-- BSAT Master helpers...
		-- We are delaying the running singals so that we have enough time to sample them...
		Delay_Transfer_Running: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				IO_Transfer_Running_Int <= '0';
				SPort_Transfer_Running_Int <= '0';
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IO_Transfer_Running_Int <= IO_Transfer_Running;
				SPort_Transfer_Running_Int <= SPort_Transfer_Running;
			END IF;
		END PROCESS Delay_Transfer_Running;
		
		
		-- A single pulse of the certain Core FSM signal is more appropriate for the use in the master FSM...
		Pulsed_Core_FSM: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				P_RX_FSM_Data_Ready <= '0';
				RX_Data_Ready_Int <= '0';
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				RX_Data_Ready_Int <= BSAT_RX_FSM_Status.Data_Ready;
				P_RX_FSM_Data_Ready <= (BSAT_RX_FSM_Status.Data_Ready AND NOT(RX_Data_Ready_Int));
			END IF;
		END PROCESS Pulsed_Core_FSM;
	   ----------------------
		-- BSAT Master FSM END
		----------------------
		
		
		---------------
		-- I/O Transfer
		---------------
		-- The actual solution does support 16, 32 and 64Bit modi. Just the 64Bit mode is tested.
		-- The mode defines how many Bits have to be updated on the COP port when we start a transfer.
		BSAT_IO_Transfer_Initiate: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				New_IO_Transfer <= '0';
				BSAT_IO_Transfer_AD_Array <= (OTHERS => (OTHERS => '0'));
				BSAT_IO_Feeder_SEQ_Counter <= 0;
				IO_BRCT_Lock <= '0';
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN	
				IF ((BSAT_Control_CFG.Master_Controller.IO_Word_Width = 0) AND (UNSIGNED(BSAT_WR_ST) > 0)) THEN -- 16Bit mode...
					New_IO_Transfer <= '1';
					BSAT_IO_Transfer_AD_Array(BSAT_IO_Feeder_SEQ_Counter) <= ('0' & '1' & '0' & BSAT_WR_Word(4 DOWNTO 2));
				ELSIF ((BSAT_Control_CFG.Master_Controller.IO_Word_Width = 1) AND (UNSIGNED(BSAT_WR_ST) > 0) AND (BSAT_WR_Word(0) = '1')) THEN -- 32Bit mode...
					New_IO_Transfer <= '1';
					BSAT_IO_Transfer_AD_Array(BSAT_IO_Feeder_SEQ_Counter) <= ('0' & '1' & '0' & BSAT_WR_Word(4 DOWNTO 2));
				ELSIF ((BSAT_Control_CFG.Master_Controller.IO_Word_Width = 2) AND (UNSIGNED(BSAT_WR_ST) > 0) AND (BSAT_WR_Word(1 DOWNTO 0) = "11")) THEN -- 64Bit mode...
					IF (BSAT_WR_ST = x"FF") THEN
						IF (IO_BRCT_Lock = '0') THEN
							BSAT_IO_Transfer_AD_Array(BSAT_IO_Feeder_SEQ_Counter) <= ('1' & '1' & BSAT_BRCT_AD_C_BS_PKG); -- Address valid + defined as broadcast.
							IO_BRCT_Lock <= '1';
							IF (IO_Transfer_Running = '0') THEN
								New_IO_Transfer <= '1';
							END IF;
						ELSE
							New_IO_Transfer <= '0';
						END IF;
					ELSE
						BSAT_IO_Transfer_AD_Array(BSAT_IO_Feeder_SEQ_Counter) <= ('0' & '1'& '0' & BSAT_WR_Word(4 DOWNTO 2)); --Address valid/ We do support 8 slaves only.
						BSAT_IO_Feeder_SEQ_Counter <= (BSAT_IO_Feeder_SEQ_Counter + 1); -- Update the pointer to the actual next free element.
						IF (IO_Transfer_Running = '0') THEN
							New_IO_Transfer <= '1';
						END IF;
						IO_BRCT_Lock <= '0';
					END IF;
				ELSIF ((IO_Transfer_Running = '0') AND (New_IO_Transfer = '0')) THEN
					BSAT_IO_Feeder_SEQ_Counter <= 0;
					BSAT_IO_Transfer_AD_Array <= (OTHERS => (OTHERS => '0'));
				ELSE
					New_IO_Transfer <= '0';
					IO_BRCT_Lock <= '0';
				END IF;
			END IF;
		END PROCESS BSAT_IO_Transfer_Initiate;
		
		
		BSAT_IO_Data_Store: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				BSAT_RD_AD <= (OTHERS => '1');
				BSAT_RD_Data_Int <= (OTHERS => '0');
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF ((BSAT_RX_FSM_Status.Data_Ready = '1') AND (IO_Transfer_Running_Int = '1')) THEN
					BSAT_RD_WREN <= '1';
					BSAT_RD_Data_Int <= BSAT_SM_Data.Data.Data_Value;
				ELSIF (BSAT_RX_FSM_Status.RX_Active = '1') THEN
					BSAT_RD_AD <= BSAT_IO_Transfer_AD_Array(BSAT_IO_ACT_Transfer_Counter)(2 DOWNTO 0);
					BSAT_RD_WREN <= '0';
				ELSE
					BSAT_RD_WREN <= '0';
				END IF;
			END IF;
		END PROCESS;
		-------------------
		-- I/O Transfer END
		-------------------
		
		
		
		
	-- Dummy data nothing else to transmit?
	SPort_COP_BSAT_Info <= x"112233445566";	

		
	------------------
	-- S-Port Handling
	------------------
	Instantiate_S_Port_Handling: IF (BSAT_Control_CFG.Master_Controller.S_Port_Mode_EN = ON_C_I_PKG) GENERATE
	BEGIN
		BSAT_S_Port_Interface: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				New_SPort_Transfer <= '0';
				BSAT_Data_In <= (OTHERS => '0');
				SPort_BSAT_Data_Ready <= '0';
				Init_Delayed_SPort_Transfer <= '0';
				SPort_Delay_Counter <= 0;
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (BSAT_AD_RDY = '1') THEN
					IF (BSAT_WR_RD_n = '1') THEN
						BSAT_MS_CMD_SPort <= BSAT_MS_CMD_RAM_WR_C_BS_PKG;
					ELSE
						BSAT_MS_CMD_SPort <= BSAT_MS_CMD_RAM_RD_C_BS_PKG;
					END IF;
				ELSIF (BSAT_Data_RDY = '1') THEN
					Init_Delayed_SPort_Transfer <= '1';
					SPort_Delay_Counter <= BSAT_SPort_MIN_Transaction_Delay_C_B_PKG;
				ELSIF ((BSAT_RX_FSM_Status.Data_Ready = '1') AND (SPort_Transfer_Running_Int = '1')) THEN
					BSAT_Data_In <= BSAT_SM_Data.Data.Data_Value(15 DOWNTO 0);
					SPort_BSAT_COP_Info <= BSAT_SM_Data.Data.Data_Value(63 DOWNTO 16);
					SPort_BSAT_Data_Ready <= '1'; -- We have to Update the register in the "Gin_Control" entity*.
				ELSIF ((BSAT_Ready = '1') AND (BSAT_RX_FSM_Status.RX_Active = '0') AND (SPort_Transfer_Running_Int = '1')) THEN
					BSAT_Data_In <= (OTHERS => '0');
					SPort_BSAT_COP_Info <= (OTHERS => '0');
					SPort_BSAT_Data_Ready <= '1'; -- We clear the register- a BSAT bus error occured.
				ELSIF (Init_Delayed_SPort_Transfer = '1') THEN
					IF (SPort_Delay_Counter = 0) THEN
						SPort_Delay_Counter <= BSAT_SPort_MIN_Transaction_Delay_C_B_PKG;
						IF (IO_Transfer_Running = '0') THEN
							New_SPort_Transfer <= '1';
							Init_Delayed_SPort_Transfer <= '0';
						END IF;
					ELSE
						SPort_Delay_Counter <= (SPort_Delay_Counter - 1);
						New_SPort_Transfer <= '0';
					END IF;
				ELSE
					New_SPort_Transfer <= '0';
					SPort_BSAT_Data_Ready <= '0';
					Init_Delayed_SPort_Transfer <= '0';
				END IF;
			END IF;
		END PROCESS BSAT_S_Port_Interface;
		
		
		
		-- We have to store the Status information. This has to be done after each successful transfer (not only S-Port).
		Save_S_Port_Status: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				BSAT_Sum_Errors <= (OTHERS => '0');
				BSAT_HID_Changed_Slaves <= (OTHERS => '0');
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (BSAT_RX_FSM_Status.Data_Ready = '1') THEN
					-- Assign the BSAT User errors:
					BSAT_Sum_Errors(3*Byte_Width_C_I_PKG + TO_INTEGER(UNSIGNED(BSAT_Address(10 DOWNTO 8)))) <= BSAT_SM_Data.Status.Status_Value(4);
					-- Assign the BSAT Sum and Node errors:
					BSAT_Sum_Errors(TO_INTEGER(UNSIGNED(BSAT_Address(10 DOWNTO 8)))) <= BSAT_SM_Data.Status.Status_Value(1);
					BSAT_Sum_Errors((Byte_Width_C_I_PKG + 1 + 2*TO_INTEGER(UNSIGNED(BSAT_Address(10 DOWNTO 8)))) DOWNTO (Byte_Width_C_I_PKG + 2*TO_INTEGER(UNSIGNED(BSAT_Address(10 DOWNTO 8))))) <= BSAT_SM_Data.Status.Status_Value(3 DOWNTO 2);
					-- Do the same for the HID_Changed Bits...
					BSAT_HID_Changed_Slaves(TO_INTEGER(UNSIGNED(BSAT_Address(10 DOWNTO 8)))) <= BSAT_SM_Data.Status.Status_Value(0);
					-- Sugesstion for more efficient "HID changed" handling:
					--BSAT_Sum_Errors(3*Byte_Width_C_I_PKG + TO_INTEGER(UNSIGNED(BSAT_Address(10 DOWNTO 8)))) <= BSAT_SM_Data.Status.Status_Value(0); -- Map the Bits to the new S-Port.
				END IF;
			END IF;
		END PROCESS Save_S_Port_Status;
					
					
		
		-- There needs to be an OR function for the BSAT HID_Changed Bits
		BSAT_HIDs: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				BSAT_HID_changed <= '0';
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (UNSIGNED(BSAT_HID_Changed_Slaves) > 0) THEN
					BSAT_HID_changed <= '1';
				ELSE
					BSAT_HID_changed <= '0';
				END IF;
			END IF;
		END PROCESS BSAT_HIDs;
			
	END GENERATE Instantiate_S_Port_Handling;
	
	-----------------
	-- * Take care!!!
	-- The SW does a very special thing during a "read" S-Port access:
	-- From a logical point of view such a S-Port access is conducted by a.) writing the needed address to the COP bus, b.) reading from this address via COP bus afterwards.
	-- However the SW does just a "read" to the COP bus and is sending the marker pattern afterwards. This way round they do not have to setup more than one access!
	-- We have to make sure in the HW that we can return data during this "pattern time/ during the time the pattern address is there".
	-----------------
	----------------------
	-- S-Port Handling END
	----------------------
	
	
	END GENERATE Instantiate_BSAT_Master_Core;
	----------------
	-- BSAT Core END
	----------------
	
	
	
	
	
	
	----------------------
	-- BSAT Slave Scanner
	----------------------
	Instantiate_BSAT_Slave_Scanner: IF (ON_C_I_PKG = ON_C_I_PKG) GENERATE -- After booting up we are looking how many SAT boards are mounted on the Hammer.
		SIGNAL	Scan_Delay_Init						:	std_logic_vector(3 DOWNTO 0);
		SIGNAL	Scan_Delay							:	std_logic_vector(3 DOWNTO 0);
		SIGNAL	Rescan_PLS_62_5						:	std_logic;
		SIGNAL	Delay_Counter_Expired				:	std_logic;
		SIGNAL	Direct_Request						:	std_logic;
		SIGNAL 	BusScan_Start_Delay_Expired_62_5	: 	std_logic:= '0';
	BEGIN	
		
		-- The BSAT is externally powered, not via Hammer.
		BSAT_Supply_Mode_0: IF (BSAT_Supply = 0) GENERATE
		BEGIN
			-- Nothing has to be done...
			-- The scan during the init is late enough...
			Scan_Delay_Init	 <= (OTHERS => '0');
			BusScan_Start_Delay_Expired_62_5 <= '1';
		END GENERATE BSAT_Supply_Mode_0;
		
		
		-- We start with a fixed, configured delay time.
		BSAT_Supply_Mode_1: IF (BSAT_Supply = 1) GENERATE
			SIGNAL	Delay_Starter		:	std_logic;
		BEGIN
			Scan_EN: PROCESS(CLK62_5, CLR_n_CLK62_5)
			BEGIN
				IF (CLR_n_CLK62_5 = '0') THEN
					Delay_Starter <= '0';
					Scan_Delay_Init	<= (OTHERS =>'0');
					BusScan_Start_Delay_Expired_62_5 <= '0';
				ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
					IF ((Delay_Starter = '0') AND (BSAT_Bus_Control(15 DOWNTO 12) /= X"0")) THEN -- We wait till the TDP_RAM_Controller provides us the needed data.
						Scan_Delay_Init	<= X"F"; -- We are loading the constant value directly now. This way round it works even if the *.hex file is empty.
						Delay_Starter <= '1';
					ELSIF (Rescan_PLS_62_5 = '1') THEN
						Scan_Delay_Init <= (OTHERS => '0');
						BusScan_Start_Delay_Expired_62_5 <= '1';
					END IF;
				END IF;
			END PROCESS Scan_EN;
		END GENERATE BSAT_Supply_Mode_1;
		
		
		-- In this mode the scan delay starts after the Hammer output was enabled with Plug &Play.
		BSAT_Supply_Mode_2: IF (BSAT_Supply = 2) GENERATE
			SIGNAL	BSAT_Scan_Init_EN_Int	:	std_logic;	
		BEGIN
			-- We are starting the delay counter. After the counter expires, the scannning starts.
			Scan_EN:	PROCESS(CLK62_5, CLR_n_CLK62_5)
			BEGIN
				IF (CLR_n_CLK62_5 = '0') THEN
					BSAT_Scan_Init_EN_Int <= '0';
					Scan_Delay_Init	<= (OTHERS => '0');
					BusScan_Start_Delay_Expired_62_5 <= '0';
				ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
					BSAT_Scan_Init_EN_Int <= BSAT_Scan_Init_EN;
					IF ((BSAT_Scan_Init_EN = '1') AND (BSAT_Scan_Init_EN_Int = '0')) THEN
						Scan_Delay_Init	<= X"F"; -- We are loading the constant value directly now. This way round it works even if the *.hex file is empty.
						BusScan_Start_Delay_Expired_62_5 <= '0';
					ELSIF (Rescan_PLS_62_5 = '1') THEN
						Scan_Delay_Init <= (OTHERS => '0');
						BusScan_Start_Delay_Expired_62_5 <= '1';
					END IF;
				END IF;
			END PROCESS Scan_EN;
		END GENERATE BSAT_Supply_Mode_2;
		
		
		-- We make sur that there is a probability to enter the scan proceeding (at least once) even if the SW does not full-fill the needed requirements. 
		Scan_Init: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				Rescan_Request <= '0';
				BusScan_Start_Delay_Expired <= '0';
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (Delay_Counter_Expired = '1') THEN
					IF (Rescan_Acknowledge = '0') THEN
						Rescan_Request <= '1';
					ELSE
						Rescan_Request <= '0';-- !!!!!*****!!!!!!! What should we do in this error situation? ********
					END IF;
				ELSIF (Rescan_Acknowledge = '1') THEN
					Rescan_Request <= '0';
				END IF;
				BusScan_Start_Delay_Expired <= BusScan_Start_Delay_Expired_62_5;
			END IF;
		END PROCESS Scan_Init;
		
		
		-- What are we trying to do here (I have to write it down because I did not longer knew it myself when I fixed the bug...)?
		-- The S-Port memory *.hex file is loaded by default with a delay value of 0xF = 67.109ms.
		-- As soon as the TDP_RAM controller delivers this value (in BSAT_Supply mode = '1') or PlugPlayOE (BSAT_Supply mode = '2') the delay counter is loaded with a value /= 0x0.
		-- This means the delay counter is started. 
		Scan_Delay <= Scan_Delay_Init WHEN (BusScan_Start_Delay_Expired_62_5 = '0') ELSE BSAT_Bus_Control(15 DOWNTO 12);
 
		---------------------
		-- Scan Delay Counter
		---------------------
		-- We are using the GinLink Safety_Counter for this functionality, too...
		Delay_Counter_Inst: Safety_Counter
			PORT MAP	(
						CLK125							=> CLK125, -- 125 MHz CLK
						CLK62_5							=> CLK62_5, -- 62.5 MHz CLK
						CLR_n							=> CLR_n_CLK62_5,
						GinLink_Safety					=> X"000000" & X"0" & Scan_Delay,
						GinWDog							=> (OTHERS => '0'),
						Gin_Safety_WDog_CLK62_5			=> OPEN,
						Gin_Safety_WDog_CLK125			=> OPEN,
						Gin_Safety_WDog_PLS_CLK62_5		=> Rescan_PLS_62_5,
						Gin_Safety_WDog_PLS_CLK125		=> Delay_Counter_Expired
						);
		--------------------------
		-- Scan Delay  Counter END
		--------------------------
	
	END GENERATE Instantiate_BSAT_Slave_Scanner;
	--------------------------
	-- B_SAT Slave Scanner END
	--------------------------

END Universal;
	