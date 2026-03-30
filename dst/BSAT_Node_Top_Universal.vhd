-- Module BSAT Node Top                                     					--
-- VHDL Package Indel_lib.BSAT_Node_Top                                   		--
--                                                                            	--
-- InfoLink, GinLink            Copyright (c): INDEL AG                       	--
-- BSAT                         Copyright (c): Besi Switzerland AG            	--
--                                                                            	--
-- Project:   BSAT                                                            	--
--                                                                            	--
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland                          	--
--                                                                            	--
-- -------------------------------------------------------------------------- 	--
-- Package for BSAT specific constants and definitions.                       	--
-- -------------------------------------------------------------------------- 	--
--	QFU, 12.01.2018: First draft, V08, simple I/O mode is working, work on     	--
--				"complex" mode is going on (sub entity "BSAT_Node_Control").	--
--	QFU, 19.02.2018: Splitted the 64Bit I/O data into 2x32Bit					--
--	QFU, 25.09.2018: New port definitions and gernerics added.					--
--	QFU, 12.10.2018: Added MID functionality for the BSAT's.					--
--	QFU, 01.11.2018: Spreaded out all the record signals for the top module.	--
--	QFU, 11.10.2019: Added prefetching ports, generic.							--
--	QFU, 21.01.2020: "BSAT_NODE_Sub_Core_CFG" constant set-up via Besi Pkg, too	--
--------------------------------------------------------------------------------
--$Rev:: 5535                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2020-03-20 10:52:01 +0100 (Fr., 20 MÃ¤r 2020)                        $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;


LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.BSAT_Package.all;
USE Indel_lib.Besi_Package.all;



ENTITY bsat_node IS
	GENERIC		(
				Auxiliary_System			:	natural RANGE 0 TO 1:= 0; -- 0 = Standard Node, 1 = Auxiliary Node (to be stored in Auxiliary Flash range)
				Port_Count					:	natural RANGE 0 TO 2:= 2;
				Port_Error_Count    		:	bsat_error_number_array_t_b_pkg(0 TO 1):= (OTHERS=> 0); -- Number of errors per port. e.g. (5,2,12,OTHERS=>0)
				Prefetching_EN				:	natural	RANGE 0 TO 1:= 0; -- 1 = Allows to output RX data before CRC checks are executed for prefetching, paging.
				HID_Count					:	natural RANGE 0 TO 32:= 5;
				User_Port_EN				:	natural RANGE 0 TO 1:= 0;
				User_Port_Error_Count		:	natural RANGE 0 TO 32:= 0;
				BSAT_Board_Type				:	string:= "MOT_V01";
				BSAT_Board_Number			:	string:= "5005-3347";
				EXT_MID_Port_Width			:	natural RANGE 0 TO 8:= 0; -- Number of MID Bits that are routed out of the FPGA (needed for generating a working debug MID).
				FeatureID					:	natural RANGE 0 TO 255;
				BugfixID					:	natural RANGE 0 TO 255;
				BuildID						:	natural RANGE 0 TO 255:= 1;
				INC_MID						:	natural RANGE 0 TO 255;
				Target_Family				:	natural RANGE 0 TO 15; -- 1=C1&C2, 2=C3&C4, 3=C5, 4=C10, 5=M10	
				Target_Variation			:	natural RANGE 0 TO 7; -- See device packages
				Target_Boot_Mode			:	natural RANGE 0 TO 1; -- see device packages
				Target_SPI_Flash			:	natural RANGE 0 TO 7; -- SPI flash device type ("Config_Device)
				Target_MFD_Storage			:	natural RANGE 0 TO 1; -- Are we storing the MFD in the device?
				Target_RAM_Loader			:	natural RANGE 0 TO 1; -- Do we have to instantiate the RAM loader (normally not used)?
				Target_RAM_Size				:	natural RANGE 0 TO 16#3DFF#
				);
	PORT		(
				-- General signals
				CLK250						:	IN		std_logic:= '0';
				CLK125						:	IN		std_logic;
				CLK62_5						:	IN		std_logic:= '0';
				CLR_n						:	IN		std_logic:= '0';
				-- BSAT external bus signals
				BSAT_Serial_TX_EN			:	OUT		std_logic:= '0'; -- BSAT driver enable, has to be connected to the external RS485 transmitter.
				BSAT_Serial_TX_Data			:	OUT		std_logic:= '1'; -- BSAT TX data output.
				BSAT_Serial_RX_nEN			:	OUT		std_logic:= '0'; -- Could perhaps be used for short/ open detection with certain receivers...
			  	BSAT_Serial_RX_Data			:	IN		std_logic;
				-- BSAT external module signals
				BSAT_Module_AD				:	IN		std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0):= (OTHERS => '1'); -- Address switch input signal.
				BSAT_Module_MID				:	IN		std_logic_vector(7 DOWNTO 0):= (OTHERS => '0');
				-- IO Ports
				Ports_In					:	IN		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => (OTHERS => '0'));
				Ports_Out					:	OUT		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0);
				Ports_RD_ST					:	OUT		std_logic_vector(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => '0');
				Ports_WR_ST					:	OUT		std_logic_vector(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => '0');
				-- Prefetching IO Ports
				Prefetched_Bit_Valid		:	OUT		std_logic:= '0';
				Prefetched_Bit_Nr			:	OUT		natural:= 0;
				Prefetched_Bit_Data			:	OUT		std_logic:= '0';
				-- Node Ports
				HID							:	IN		std_logic_vector(Return_Upper_F_I_PKG(HID_Count) DOWNTO 0);
				Errors						: 	IN		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => (OTHERS => '0'));
				Error_CLRs					: 	OUT		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => (OTHERS => '0'));
				-- User Port
				User_Port_AD_Ready			:	OUT		std_logic;
				User_Port_Data_Ready		:	OUT		std_logic;
				User_Port_WREN				:	OUT		std_logic;
				User_Port_AD				:	OUT		std_logic_vector(7 DOWNTO 0);
				BSAT_User_Port_Data			:	OUT		std_logic_vector((Return_Selection_natural_F_I_PKG(BSAT_M_CFG_FSM_S_Port_EN_C_B_PKG,ON_C_I_PKG,0,48) +15) DOWNTO 0);
				User_Port_BSAT_Data			:	IN		std_logic_vector((Return_Selection_natural_F_I_PKG(BSAT_M_CFG_FSM_S_Port_EN_C_B_PKG,ON_C_I_PKG,0,48) +15) DOWNTO 0);
				Errors_User_Port			:	IN		std_logic_vector(Return_Upper_F_I_PKG(User_Port_Error_Count) DOWNTO 0);
				Error_CLRs_User_Port		:	OUT		std_logic_vector(Return_Upper_F_I_PKG(User_Port_Error_Count) DOWNTO 0);
				-- Flash Port
				Flash_Port					:	INOUT	bsat_flash_port_bundle_t_b_pkg:= NA_BSAT_FLASH_PORT_BUNDLE_C_B_PKG;
				-- Interface to external devices: MCU, SPI, etc.
				External_Ports				:	INOUT	bsat_external_port_bundle_t_b_pkg:= NA_BSAT_EXTERNAL_PORTS_BUNDLE_C_B_PKG;
				-- Status information of the Node
				Status_Scan_Done			:	OUT		std_logic;
				Status_ID_Successful		:	OUT		std_logic;
				Status_PlugPlay_OE			:	OUT		std_logic;
				Status_PlugPlay_WDog		:	OUT		std_logic;
				Status_BSAT_Error			:	OUT		std_logic;
				Status_nStatus_LED			:	OUT		std_logic
				);
END bsat_node;


LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.BSAT_Package.all;


ARCHITECTURE Universal OF bsat_node IS


	-------------------
	-- Type Declaration
	-------------------
	--
	-----------------------
	-- Type Declaration END
	-----------------------


	-----------------------
	-- Constant Declaration
	-----------------------
	CONSTANT	BSAT_NODE_Sub_Core_CFG 		:	bsat_cfg_core_bundle_t_bs_pkg:= (1,BSAT_M_CFG_Core_Oversampling_C_B_PKG,BSAT_M_CFG_Core_DS_Coding_C_B_PKG,BSAT_M_CFG_Core_IO_Mode_C_B_PKG,BSAT_M_CFG_Core_TX_Debug_C_B_PKG,BSAT_M_CFG_Core_RX_Debug_C_B_PKG); -- (Core_Role, Oversampling, DS_Decoding, IO_Mode,TX_Debugging, RX_Debugging)
	CONSTANT	BSAT_NODE_Sub_Ctrl_CFG		:	bsat_cfg_node_ctrl_bundle_t_bs_pkg:= ('0','0'); -- (Dummy2, Dummy3) Take care: Actual just used for a bug in Quartus 17.1!!!
	CONSTANT	BSAT_Node_CFG				:	bsat_cfg_node_top_bundle_t_bs_pkg:= (BSAT_NODE_Sub_Core_CFG,BSAT_NODE_Sub_Ctrl_CFG);
	CONSTANT	Besi_Node_CFG				:	bsat_slave_cfg_def_bundle_t_b_pkg:= (Auxiliary_System,Port_Count,HID_Count,Port_Error_Count(0),Port_Error_Count(1),User_Port_Error_Count,User_Port_EN,EXT_MID_Port_Width); -- (Port_Count,HID_Count,Error_Port_0_Count,Error_Port_1_Count,Error_Port_U_Count,User_RAM_EN,Ext_MID_Nr)
	CONSTANT	Besi_Target_Device			:	target_device_bundle_t_b_pkg:= (Target_Family,Target_Variation,Target_Boot_Mode,Target_SPI_Flash,Target_MFD_Storage,Target_RAM_Loader,Target_RAM_Size);	
	CONSTANT	InterfaceID					:	natural RANGE 0 TO 255:= 0;
	CONSTANT	Besi_Design_Version			:	besi_user_versioning_bundle_t_b_pkg:= (InterfaceID,FeatureID,BugfixID,BuildID,INC_MID);
	---------------------------
	-- Constant Declaration END
	--------------------------
	
	
	---------------------
   -- Signal Declaration
   ---------------------
	SIGNAL	BSAT_MS							:	bsat_prtcl_ms_bundle_t_bs_pkg:= NA_BSAT_PRTCL_MS_BUNDLE_C_BS_PKG;
	SIGNAL	BSAT_SM							:	bsat_prtcl_sm_bundle_t_bs_pkg:= NA_BSAT_PRTCL_SM_BUNDLE_C_BS_PKG;
	SIGNAL	BSAT_RX_FSM_Status				:	bsat_s_rx_fsm_bundle_t_bs_pkg:= NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG;
	SIGNAL	BSAT_TX_FSM_Status				:	bsat_s_tx_fsm_bundle_t_bs_pkg:= NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG;
	SIGNAL	BSAT_IO_Port_In					:	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	BSAT_IO_Port_Out				:	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	User_Port						: 	bsat_user_ram_port_bundle_t_b_pkg:= NA_BSAT_USER_RAM_PORT_BUNDL_C_B_PKG;
	SIGNAL	IO_Ports_In						:	bsat_port_array_t_bs_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0);
	SIGNAL	IO_Ports_Out					:	bsat_port_array_t_bs_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0);
	SIGNAL	IO_Errors						:	bsat_slave_errors_s_bundle_t_b_pkg:= ((OTHERS => '0'),(OTHERS => '0'),(OTHERS => '0'));
	SIGNAL	IO_Error_CLRs					:	bsat_slave_error_clrs_bundle_t_b_pkg;
	SIGNAL	Node_Status						: 	besi_node_status_bundle_t_b_pkg:= NA_BESI_NODE_STATUS_BUNDLE_C_B_PKG;
	SIGNAL	BSAT_Transfer_Start				:	std_logic;
	SIGNAL	BSAT_Transfer_Start_Master		:	std_logic:= '0';
	-------------------------
   -- Signal Declaration END
   -------------------------


	------------------------
	-- COMPONENT Declaration
	------------------------
	COMPONENT BSAT_Core
	   GENERIC 		(
					BSAT_Core_Role			: natural RANGE 0 TO 1:= 1; -- Slave = 1, Master = 0,
					BSAT_Oversampling		: natural RANGE 0 TO 15:= 8;
					BSAT_DS_Decoding		: natural RANGE 0 TO 1:= 0;
					BSAT_IO_Mode_EN      	: natural RANGE 0 TO 1:= 0; -- Enable the simple I/O mode: 1 = "ON", 0 = "OFF"
					BSAT_TX_Debugging		: natural RANGE 0 TO 1:= 1; -- Allows to instantiate a signal that shows the actual 16bit TX data.
					BSAT_RX_Debugging		: natural RANGE 0 TO 1:= 1 -- Allows to instantiate a signal that shows the actual 16bit RX data.
					);
		PORT		(
					CLK125					: IN	std_logic;
					CLK250					: IN	std_logic:= '0'; -- This is an aditional clock that can be used as fast source for the the InfoLink encoder and decoder only (higher oversampling).
					CLR_n_CLK125			: IN	std_logic;
					-- BSAT external bus signals
					BSAT_Serial_TX_EN		: OUT	std_logic:= '0'; -- BSAT driver enable, has to be connected to the external RS485 transmitter.
					BSAT_Serial_TX_Data		: OUT	std_logic:= '1'; -- BSAT TX data output.
					BSAT_Serial_RX_nEN		: OUT	std_logic:= '0'; -- Could perhaps be used for short/ open detection with certain receivers...
					BSAT_Serial_RX_Data		: IN	std_logic;
					-- BSAT external module signals
					BSAT_Module_AD			: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0):= (OTHERS => '1'); -- Address switch input signal.
					-- BSAT status signals
					BSAT_Transfer_Start 	: IN	std_logic:= '0';
					BSAT_Ready           	: OUT	std_logic;
					-- BSAT FSM status signals
					BSAT_RX_FSM_Status		: OUT	bsat_s_rx_fsm_bundle_t_bs_pkg:= NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG;
					BSAT_TX_FSM_Status		: OUT	bsat_s_tx_fsm_bundle_t_bs_pkg:= NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG;
					-- BSAT complete interface
					BSAT_MS					: INOUT	bsat_prtcl_ms_bundle_t_bs_pkg:= NA_BSAT_PRTCL_MS_BUNDLE_C_BS_PKG;
					BSAT_SM					: INOUT	bsat_prtcl_sm_bundle_t_bs_pkg:= NA_BSAT_PRTCL_SM_BUNDLE_C_BS_PKG;
					-- BSAT IO signals
					BSAT_IO_Port_In			: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0):= (OTHERS => '0');
					BSAT_IO_Port_Out		: OUT	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0)
					);
	END COMPONENT BSAT_Core;
	
	
	COMPONENT BSAT_Node_Control
		GENERIC		(
					Besi_BSAT_Board_Type	: string;
					Besi_BSAT_Board_Number	: string;
					Besi_Node_CFG			: bsat_slave_cfg_def_bundle_t_b_pkg; -- (Auxiliary_System,Port_Count,HID_Count,Error_Port_0_Count,Error_Port_1_Count,Error_Port_U_Count,User_RAM_EN)
					Besi_Design_Version		: besi_user_versioning_bundle_t_b_pkg:= NA_BESI_USER_VERSIONING_BUNDLE_C_B_PKG;
					Besi_Target_Device		: target_device_bundle_t_b_pkg:=NA_BESI_TARGET_DEVICE_BUNDLE_C_B_PKG
					);
		PORT		(
					-- General signals	
					CLK125					: IN	std_logic;
					CLK62_5					: IN	std_logic:= '0';
					CLR_n_CLK125			: IN	std_logic;
					-- BSAT data signals
					BSAT_MS					: INOUT	bsat_prtcl_ms_bundle_t_bs_pkg;
					BSAT_SM					: INOUT	bsat_prtcl_sm_bundle_t_bs_pkg;
					-- BSAT FSM status signals
					BSAT_RX_FSM_Status		: INOUT	bsat_s_rx_fsm_bundle_t_bs_pkg;
					BSAT_TX_FSM_Status		: INOUT	bsat_s_tx_fsm_bundle_t_bs_pkg;
					-- I/O real time data
					BSAT_IO_Ports_In		: INOUT	bsat_port_array_t_bs_pkg;
					BSAT_IO_Ports_Out		: OUT	bsat_port_array_t_bs_pkg;
					-- Node Ports
					Module_MID				: IN	std_logic_vector(7 DOWNTO 0):= (OTHERS => '0');
					HID						: IN	std_logic_vector(Return_Upper_F_I_PKG(Besi_Node_CFG.HID_Count) DOWNTO 0):= (OTHERS => '0');
					Errors					: IN	bsat_slave_errors_s_bundle_t_b_pkg:= ((OTHERS => '0'),(OTHERS => '0'),(OTHERS => '0'));
					Error_CLRs				: OUT	bsat_slave_error_clrs_bundle_t_b_pkg:= ((OTHERS => '0'),(OTHERS => '0'),(OTHERS => '0'));
					User_Port				: INOUT	bsat_user_ram_port_bundle_t_b_pkg:= NA_BSAT_USER_RAM_PORT_BUNDL_C_B_PKG;
					Flash_Port				: INOUT	bsat_flash_port_bundle_t_b_pkg;
					External_Ports			: INOUT	bsat_external_port_bundle_t_b_pkg:= NA_BSAT_EXTERNAL_PORTS_BUNDLE_C_B_PKG;
					Node_Status				: OUT	besi_node_status_bundle_t_b_pkg:= NA_BESI_NODE_STATUS_BUNDLE_C_B_PKG
					);
	END COMPONENT BSAT_Node_Control;

	-- PRAGMA SYNTHESIS_OFF
	FOR ALL : BSAT_Core USE ENTITY Indel_lib.BSAT_Core;
	FOR ALL : BSAT_Node_Control USE ENTITY Indel_lib.BSAT_Node_Control;
	-- PRAGMA SYNTHESIS_ON
	----------------------------
	-- COMPONENT Declaration END
	----------------------------

BEGIN

	-- Concurrent BSAT Core Role:
	BSAT_Transfer_Start 	<= '0' WHEN (BSAT_Node_CFG.Core.Core_Role = 1) ELSE BSAT_Transfer_Start_Master;
	
	-- We are splitting the Status signals, too...
	Status_Scan_Done		<= Node_Status.Scan_Done;
	Status_ID_Successful	<= Node_Status.ID_Successful;
	Status_PlugPlay_OE		<= Node_Status.PlugPlay_OE;
	Status_PlugPlay_WDog	<= Node_Status.PlugPlay_WDog;
	Status_BSAT_Error		<= Node_Status.BSAT_Error;
	Status_nStatus_LED		<= Node_Status.nStatus_LED;

	
	----------------
	-- The BSAT-Core
	----------------
	Core_Instantiation: BSAT_Core
	   GENERIC MAP		(
						BSAT_Core_Role				=> 	BSAT_Node_CFG.Core.Core_Role, -- Slave = 1, Master = 0,
						BSAT_Oversampling			=> 	BSAT_Node_CFG.Core.Oversampling, -- Oversampling factor
						BSAT_DS_Decoding			=> 	BSAT_Node_CFG.Core.DS_Decoding, -- Double speed encoding/decoding
						BSAT_IO_Mode_EN				=> 	BSAT_Node_CFG.Core.IO_Mode, -- Enable the simple I/O mode: 1 = "ON", 0 = "OFF"
						BSAT_TX_Debugging			=> 	BSAT_Node_CFG.Core.TX_Debugging, -- Allows to instantiate a signal that shows the actual 16bit TX data (SignalTap II).
						BSAT_RX_Debugging			=> 	BSAT_Node_CFG.Core.RX_Debugging -- Allows to instantiate a signal that shows the actual 16bit RX data (SignalTap II).
						)
		PORT MAP		(
						CLK125						=>	CLK125,
						CLK250						=>	CLK250, -- This is an aditional clock that can be used as fast source for the the InfoLink encoder and decoder only (higher oversampling).
						CLR_n_CLK125				=> 	CLR_n,
						-- BSAT external bus signals
	            		BSAT_Serial_TX_EN			=>	BSAT_Serial_TX_EN, -- BSAT driver enable, has to be connected to the external RS485 transmitter.
			      		BSAT_Serial_TX_Data			=>	BSAT_Serial_TX_Data, -- BSAT TX data output.
						BSAT_Serial_RX_nEN			=>	BSAT_Serial_RX_nEN, -- Could perhaps be used for short/ open detection with certain receivers...
			      		BSAT_Serial_RX_Data			=>	BSAT_Serial_RX_Data,
						-- BSAT external module signals
						BSAT_Module_AD				=>	BSAT_Module_AD, -- Address switch input signal.
						-- BSAT status signals
						BSAT_Transfer_Start			=>	'0',
						BSAT_Ready					=>	OPEN,
						-- BSAT FSM status signals
						BSAT_RX_FSM_Status			=>	BSAT_RX_FSM_Status,
						BSAT_TX_FSM_Status			=>	BSAT_TX_FSM_Status,
						-- BSAT complete interface
						BSAT_MS						=>	BSAT_MS, -- Disabled
						BSAT_SM						=>	BSAT_SM, -- Disabled
						-- BSAT IO signals
						BSAT_IO_Port_In				=>	BSAT_IO_Port_In,
						BSAT_IO_Port_Out			=>	BSAT_IO_Port_Out
						);
	--------------------
	-- The BSAT-Core END
	--------------------
	
	---------------------------------------------
	-- The simple mode, I/O communication only...
	Simple_IO_Mode_EN:	IF (BSAT_Node_CFG.Core.IO_Mode = ON_C_I_PKG) GENERATE
	BEGIN
	
		Two_Ports:	IF (Besi_Node_CFG.Port_Count = 2) GENERATE
		BEGIN
			BSAT_IO_Port_In			<= 	(Ports_In(1) & Ports_In(0));
			Ports_Out(0)			<= 	BSAT_IO_Port_Out(31 DOWNTO 0);
			Ports_Out(1)			<= 	BSAT_IO_Port_Out(63 DOWNTO 32);
			Ports_RD_ST(0)			<= 	BSAT_TX_FSM_Status.Data_RD_Strobe(0);
			Ports_RD_ST(1)			<= 	BSAT_TX_FSM_Status.Data_RD_Strobe(2);
			Ports_WR_ST(0)			<=	BSAT_RX_FSM_Status.Data_Ready;
			Ports_WR_ST(1)			<=	BSAT_RX_FSM_Status.Data_Ready;
			
		END GENERATE Two_Ports; 
		
		One_Port:	IF (Besi_Node_CFG.Port_Count = 1) GENERATE
		BEGIN
			BSAT_IO_Port_In			<= 	((OTHERS => '0') & Ports_In(0));
			Ports_Out(0)			<= 	BSAT_IO_Port_Out(31 DOWNTO 0);
			Ports_RD_ST(0)			<= 	BSAT_TX_FSM_Status.Data_RD_Strobe(0);
			Ports_WR_ST(0)			<=	BSAT_RX_FSM_Status.Data_Ready;
		END GENERATE One_Port;
		
		No_Port:	IF (Besi_Node_CFG.Port_Count = 0) GENERATE
		BEGIN
			BSAT_IO_Port_In			<= 	(OTHERS => '0');
			Ports_Out(0)			<= 	(OTHERS => '0');
			Ports_RD_ST				<= 	(OTHERS => '0');
			Ports_WR_ST				<=	(OTHERS => '0');
		END GENERATE No_Port;
		
		Node_Status <= NA_BESI_NODE_STATUS_BUNDLE_C_B_PKG;
		
	END GENERATE Simple_IO_Mode_EN;
	--
	-------------------------------
	
	
	----------------------------------------------------------
	-- The complex mode with error handling and downloading...
	Simple_IO_Mode_nEN:	IF (BSAT_Node_CFG.Core.IO_Mode = OFF_C_I_PKG) GENERATE
	BEGIN
	
		-- Separated User_RAM assignments.
		User_Port_AD_Ready			<=	User_Port.BSAT_AD_Ready;
		User_Port_Data_Ready		<=	User_Port.BSAT_Data_Ready;
		User_Port_WREN				<=	User_Port.BSAT_WREN;
		User_Port_AD				<=	User_Port.BSAT_AD;
		BSAT_User_Port_Data			<=	User_Port.BSAT_Data;
		User_Port.User_Data			<=	User_Port_BSAT_Data;
		
		-- Yes, we have a User Port
		User_RAM_Error_Handling: IF (Besi_Node_CFG.User_RAM_EN = ON_C_I_PKG) GENERATE
		BEGIN
		
			User_Port_Errors_32:	IF (Besi_Node_CFG.Error_Port_U_Count = 32) GENERATE
			BEGIN
				IO_Errors.Errors_Port_U <= Errors_User_Port;
			END GENERATE User_Port_Errors_32;
			
			User_Port_Errors_0: IF (Besi_Node_CFG.Error_Port_U_Count = 0) GENERATE
				CONSTANT	User_Port_Zeroes:	std_logic_vector(31 DOWNTO Besi_Node_CFG.Error_Port_U_Count):= (OTHERS => '0');
			BEGIN
				IO_Errors.Errors_Port_U <= User_Port_Zeroes;
			END GENERATE User_Port_Errors_0;
			
			User_Port_Errors_n:	IF ((Besi_Node_CFG.Error_Port_U_Count < 32) AND (Besi_Node_CFG.Error_Port_U_Count /= 0)) GENERATE
				CONSTANT	User_Port_Zeroes:	std_logic_vector(31 DOWNTO Besi_Node_CFG.Error_Port_U_Count):= (OTHERS => '0');
			BEGIN
				IO_Errors.Errors_Port_U <= (User_Port_Zeroes & Errors_User_Port);
			END GENERATE User_Port_Errors_n;
			
			Error_CLRs_User_Port <= IO_Error_CLRs.Error_CLRs_Port_U(Return_Upper_F_I_PKG(Besi_Node_CFG.Error_Port_U_Count) DOWNTO 0);
		END GENERATE User_RAM_Error_Handling;
		
		-- No User Port
		No_User_RAM_Error_Handling: IF (Besi_Node_CFG.User_RAM_EN = OFF_C_I_PKG) GENERATE
		BEGIN
			IO_Errors.Errors_Port_U <= (OTHERS => '0');
			Error_CLRs_User_Port <= (OTHERS => '0');
		END GENERATE No_User_RAM_Error_Handling;
	
	
		-- We have to assign the data to the records.
		Two_Ports:	IF (Besi_Node_CFG.Port_Count = 2) GENERATE
		BEGIN
			IO_Ports_In(0).IO_Port	<=	Ports_In(0);
			IO_Ports_In(1).IO_Port	<=	Ports_In(1);
			Ports_OUT(0)			<=	IO_Ports_Out(0).IO_Port;
			Ports_OUT(1)			<=	IO_Ports_Out(1).IO_Port;
			Ports_RD_ST(0)			<=	IO_Ports_In(0).IO_Strobe;
			Ports_RD_ST(1)			<=	IO_Ports_In(1).IO_Strobe;
			Ports_WR_ST(0)			<=	IO_Ports_Out(0).IO_Strobe;
			Ports_WR_ST(1)			<=	IO_Ports_Out(1).IO_Strobe;
			IO_Errors.Errors_Port_0	<=	Errors(0);
			IO_Errors.Errors_Port_1	<=	Errors(1);
			Error_CLRs(0)			<=	IO_Error_CLRs.Error_CLRs_Port_0;
			Error_CLRs(1)			<=	IO_Error_CLRs.Error_CLRs_Port_1;
		END GENERATE Two_Ports; 
		
		One_Port:	IF (Besi_Node_CFG.Port_Count = 1) GENERATE
		BEGIN
			IO_Ports_In(0).IO_Port	<=	Ports_In(0);
			Ports_OUT(0)			<=	IO_Ports_Out(0).IO_Port;
			Ports_RD_ST(0)			<=	IO_Ports_In(0).IO_Strobe;
			Ports_WR_ST(0)			<=	IO_Ports_Out(0).IO_Strobe;
			IO_Errors.Errors_Port_0	<=	Errors(0);
			IO_Errors.Errors_Port_1	<=	(OTHERS => '0');
			Error_CLRs(0)			<=	IO_Error_CLRs.Error_CLRs_Port_0;
		END GENERATE One_Port;
		
		No_Port:	IF (Besi_Node_CFG.Port_Count = 0) GENERATE
		BEGIN
			IO_Ports_In(0).IO_Port	<=	(OTHERS => '0');
			Ports_OUT(0)			<=	(OTHERS => '0');
			Ports_RD_ST				<=	(OTHERS => '0');
			Ports_WR_ST				<=	(OTHERS => '0');
			IO_Errors.Errors_Port_0	<=	(OTHERS => '0');
			IO_Errors.Errors_Port_1	<=	(OTHERS => '0');
		END GENERATE No_Port;
		

		---------------------------
		-- The BSAT Node Controller
		---------------------------
		BSAT_Node_Controller: BSAT_Node_Control
			GENERIC MAP		(
							Besi_BSAT_Board_Type	=> 	BSAT_Board_Type,
							Besi_BSAT_Board_Number	=> 	BSAT_Board_Number,
							Besi_Node_CFG			=>	Besi_Node_CFG, -- (Auxiliary_System,Port_Count,HID_Count,Error_Port_0_Count,Error_Port_1_Count,Error_Port_U_Count,User_RAM_EN)
							Besi_Design_Version		=> 	Besi_Design_Version,
							Besi_Target_Device		=>	Besi_Target_Device
							)
			PORT MAP		(
							-- General signals
							CLK125					=>	CLK125,
							CLK62_5					=> 	CLK62_5,
							CLR_n_CLK125			=> 	CLR_n,
							-- BSAT data signals
							BSAT_MS					=>	BSAT_MS,
							BSAT_SM					=>	BSAT_SM,
							-- BSAT FSM status signals
							BSAT_RX_FSM_Status		=>	BSAT_RX_FSM_Status,
							BSAT_TX_FSM_Status		=>	BSAT_TX_FSM_Status,
							-- I/O real time data
							BSAT_IO_Ports_In		=> 	IO_Ports_In,
							BSAT_IO_Ports_Out		=> 	IO_Ports_Out,
							-- Node Ports
							Module_MID				=>	BSAT_Module_MID,
							HID						=> 	HID,
							Errors					=> 	IO_Errors,
							Error_CLRs				=> 	IO_Error_CLRs,
							User_Port				=> 	User_Port,
							Flash_Port				=>	Flash_Port,
							External_Ports			=>	External_Ports,
							Node_Status				=>	Node_Status
							);
		-------------------------------
		-- The BSAT Node Controller END
		-------------------------------
			
		-- Concurrent 0
		BSAT_IO_Port_In <= (OTHERS => '0');
		
	END GENERATE Simple_IO_Mode_nEN;
	--
	--------------------------------
	
	
	--------------------------------
	-- Prefetching of the IO data...
	
	Prefetching_Disabled: IF (Prefetching_EN = 0) GENERATE
	BEGIN
		Prefetched_Bit_Valid	<=	'0';
		Prefetched_Bit_Nr		<=	0;
		Prefetched_Bit_Data		<=	'0';
	END GENERATE Prefetching_Disabled;
	

	Prefetching_Enabled: IF (Prefetching_EN = 1) GENERATE
	BEGIN
		Prefetched_Bit_Valid	<=	BSAT_RX_FSM_Status.Data_Bit_Valid;
		Prefetched_Bit_Nr		<=	BSAT_RX_FSM_Status.Data_Bit_Nr;
		Prefetched_Bit_Data		<=	BSAT_RX_FSM_Status.Data_Bit_Value;
	END GENERATE Prefetching_Enabled;
	--
	--------------------------
					
					
END ARCHITECTURE Universal;