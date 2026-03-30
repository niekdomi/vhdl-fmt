-- Module BSAT_Package                                                        --
-- VHDL Package Indel_lib.BSAT_Package                                        --
--                                                                            --
-- InfoLink, GinLink            Copyright (c): INDEL AG                       --
-- BSAT                         Copyright (c): Besi Switzerland AG            --
--                                                                            --
-- Project:   BSAT                                                            --
--                                                                            --
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland                          --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- Package for BSAT specific constants and definitions.                       --
-- -------------------------------------------------------------------------- --
-- QFU, 07.06.2016: First draft                                               --
-- QFU, 19.08.2016: Added type defintitions for:							  --
--							- Commands, status ports for the slave			  --
-- QFU, 16.08.2017: Configuration records extended							  --
-- QFU, 11.10.2019: Added RX_FSM_Stati for prefetching.						  --
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


PACKAGE BSAT_Package IS


	--------------------------------------
	-- Assumptions concerning the protocol
	--------------------------------------
	-- There is a basic framework of all the protocols that can be handled by the the BSAT master:
	-- 1.) Master to Slave: (Protocol_Header & Protocol_Header_CRC & Protocol_Data & Protocol_Data_CRC).
	-- 2.) Slave to Master: (Protocol_Status & Protocol_Data & Protocol_Data_CRC).
	-- 3.) The protocol in both directions (each for its own) is not longer than 118Bits (otherswise another CRC8 polynom has to be selected).
	-- 4.) If somebody would like to change the protocol it can be done easily in this package however it is important that the types remain the same.

	------------------------------------------------------------------------------------------
	-- Preset constants, which can be used in all the declarations, definitions in the package
	------------------------------------------------------------------------------------------
	
	CONSTANT BSAT_CRC_Length_C_BS_PKG											: natural := 8;
	CONSTANT BSAT_Data_Word_Length_C_BS_PKG										: natural := 16;
	CONSTANT BSAT_RX_MAX_Data_Words_C_BS_PKG									: natural := 15;
	CONSTANT BSAT_TX_Count_MIN_Pause_Length_C_BS_PKG							: natural := 15;
	
	----------------------------------------------------------------
	-- BSAT Master to Slave (MS) protocol packet definition for Besi
	CONSTANT BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG							: natural := 4; -- 4 Bit, commands: I/O data, "slow status" data, broadcast to all devices, scan opcode
	CONSTANT BSAT_MS_Packet_Header_AD_Length_C_BS_PKG							: natural := 4; -- 4 Bit for max. theo. 16 SATs/ Slaves, actually used max.5. evtl. used AD 0xF as broadcast when needed at all.
	CONSTANT BSAT_MS_Packet_Header_PARAM_Length_C_BS_PKG						: natural := 8; -- 8 Bit still not defined. (parameter field)
	CONSTANT BSAT_MS_Packet_Header_CRC_Length_C_BS_PKG							: natural := BSAT_CRC_Length_C_BS_PKG; -- 8 Bit CRC of the header.
	CONSTANT BSAT_MS_Packet_User_Data_Length_C_BS_PKG							: natural := 64; -- 64 Bit user data.
	CONSTANT BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG						: natural := BSAT_CRC_Length_C_BS_PKG; -- 8 Bit data CRC.
	-- BSAT Master to Slave (MS) protocol packet definition for Besi END
	--------------------------------------------------------------------
	
	
	----------------------------------------------------------------
	-- BSAT Slave to Master (SM) protocol packet definition for Besi
	CONSTANT BSAT_SM_Packet_Status_Length_C_BS_PKG								: natural := 16; -- 16 Bit status word from a slave to the master.
	CONSTANT BSAT_SM_Packet_User_Data_Length_C_BS_PKG							: natural := 64; -- 64 Bit user data from slave.
	CONSTANT BSAT_SM_Packet_Data_CRC_Length_C_BS_PKG							: natural := BSAT_CRC_Length_C_BS_PKG; -- 8 Bit data CRC.
	-- BSAT Slave to Master (SM) protocol packet definition for Besi END
	--------------------------------------------------------------------
	
	-- The different interesting lengths of a Master to Slave packet
	CONSTANT BSAT_MS_Packet_Header_Length_wo_CRC_C_BS_PKG						: natural := (BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG + BSAT_MS_Packet_Header_AD_Length_C_BS_PKG + BSAT_MS_Packet_Header_PARAM_Length_C_BS_PKG);
	CONSTANT BSAT_MS_Packet_Header_Length_wt_CRC_C_BS_PKG						: natural := (BSAT_MS_Packet_Header_Length_wo_CRC_C_BS_PKG + BSAT_MS_Packet_Header_CRC_Length_C_BS_PKG);
	CONSTANT BSAT_MS_Packet_Data_Length_wo_CRC_C_BS_PKG							: natural := BSAT_MS_Packet_User_Data_Length_C_BS_PKG;
	CONSTANT BSAT_MS_Packet_Data_Length_wt_CRC_C_BS_PKG							: natural := (BSAT_MS_Packet_User_Data_Length_C_BS_PKG + BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG);
	CONSTANT BSAT_MS_Packet_Length_wo_CRCs_C_BS_PKG								: natural := (BSAT_MS_Packet_Header_Length_wo_CRC_C_BS_PKG + BSAT_MS_Packet_Data_Length_wo_CRC_C_BS_PKG);
	CONSTANT BSAT_MS_Packet_Length_wt_CRCs_C_BS_PKG								: natural := (BSAT_MS_Packet_Header_Length_wt_CRC_C_BS_PKG + BSAT_MS_Packet_Data_Length_wt_CRC_C_BS_PKG);
	CONSTANT BSAT_MS_Packet_Data_Word_Count_C_BS_PKG							: natural := Identifier_Words_Needed_F_I_PKG(BSAT_MS_Packet_User_Data_Length_C_BS_PKG, 1, BSAT_Data_Word_Length_C_BS_PKG);
	
	-- The different interesting lengths of a Slave to Master packet
	CONSTANT BSAT_SM_Packet_Data_Length_wo_CRC_C_BS_PKG							: natural := (BSAT_SM_Packet_Status_Length_C_BS_PKG + BSAT_SM_Packet_User_Data_Length_C_BS_PKG);
	CONSTANT BSAT_SM_Packet_Data_Length_wt_CRC_C_BS_PKG							: natural := (BSAT_SM_Packet_Data_Length_wo_CRC_C_BS_PKG + BSAT_SM_Packet_Data_CRC_Length_C_BS_PKG);
	CONSTANT BSAT_SM_Packet_Length_wo_CRC_C_BS_PKG								: natural := BSAT_SM_Packet_Data_Length_wo_CRC_C_BS_PKG;
	CONSTANT BSAT_SM_Packet_Length_wt_CRC_C_BS_PKG								: natural := BSAT_SM_Packet_Data_Length_wt_CRC_C_BS_PKG;
	CONSTANT BSAT_SM_Packet_Data_Word_Count_C_BS_PKG							: natural := Identifier_Words_Needed_F_I_PKG(BSAT_SM_Packet_User_Data_Length_C_BS_PKG, 1, BSAT_Data_Word_Length_C_BS_PKG);
	
	-- BSAT CMD constants and their meanings (a bit complicated, however this way round we can change the number of CMD bits without losing the functionality)
	CONSTANT BSAT_CMD_0_C_BS_PKG												: natural := 0;	-- BRCT
	CONSTANT BSAT_CMD_1_C_BS_PKG												: natural := 1;	-- Scan
	CONSTANT BSAT_CMD_2_C_BS_PKG												: natural := 2;
	CONSTANT BSAT_CMD_3_C_BS_PKG												: natural := 3;
	CONSTANT BSAT_CMD_4_C_BS_PKG												: natural := 4;
	CONSTANT BSAT_CMD_5_C_BS_PKG												: natural := 5;
	CONSTANT BSAT_CMD_6_C_BS_PKG												: natural := 6;
	CONSTANT BSAT_CMD_7_C_BS_PKG												: natural := 7;
	CONSTANT BSAT_CMD_8_C_BS_PKG												: natural := 8;	-- I/O
	CONSTANT BSAT_CMD_9_C_BS_PKG												: natural := 9;	-- I/O RD
	CONSTANT BSAT_CMD_10_C_BS_PKG												: natural := 10;	-- I/O WR
	CONSTANT BSAT_CMD_11_C_BS_PKG												: natural := 11;
	CONSTANT BSAT_CMD_12_C_BS_PKG												: natural := 12;
	CONSTANT BSAT_CMD_13_C_BS_PKG												: natural := 13;	-- RAM RD
	CONSTANT BSAT_CMD_14_C_BS_PKG												: natural := 14;	-- RAM WR
	CONSTANT BSAT_CMD_15_C_BS_PKG												: natural := 15;
	
	-----------------------------------------------------------------------
	-- BSAT protocol command definitions: Add and define new commands here.
	CONSTANT BSAT_MS_CMD_IO_WR_RD_C_BS_PKG										: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_8_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	CONSTANT BSAT_MS_CMD_IO_WR_C_BS_PKG											: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_10_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	CONSTANT BSAT_MS_CMD_IO_RD_C_BS_PKG											: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_9_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	CONSTANT BSAT_MS_CMD_RAM_RD_C_BS_PKG										: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_13_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	CONSTANT BSAT_MS_CMD_RAM_WR_C_BS_PKG										: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_14_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	CONSTANT BSAT_MS_CMD_BRCT_C_BS_PKG											: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_0_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	CONSTANT BSAT_MS_CMD_Scan_C_BS_PKG											: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_1_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	-- Dummy Template CONSTANT BSAT_MS_CMD_Dummy_C_BS_PKG						: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_CMD_Dummy_C_BS_PKG, BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG));
	-- BSAT protocol command definitions END
	----------------------------------------
	
	---------------------------------------------------------------------------------
	-- Preset constants, which can be used in all the declarations in the package END
	---------------------------------------------------------------------------------
	

   -------------------
   -- Type Declaration
   -------------------
   -- Definition of the BSAT protocol
	TYPE bsat_ms_header_bundle_t_bs_pkg			IS RECORD
														CMD				: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CMD_Length_C_BS_PKG) DOWNTO 0);
														AD				: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0);
														PARAM			: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_PARAM_Length_C_BS_PKG) DOWNTO 0);
													END RECORD;
																
	TYPE bsat_ms_header_crc_bundle_t_bs_pkg 	IS RECORD
														CRC_Value		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CRC_Length_C_BS_PKG) DOWNTO 0);
														CRC_OK			: std_logic;
														CRC_Error		: std_logic;
													END RECORD;
																
	TYPE bsat_ms_data_bundle_t_bs_pkg 			IS RECORD
														Data_Value		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_Length_C_BS_PKG) DOWNTO 0);
													END RECORD;
																
	TYPE bsat_ms_data_crc_bundle_t_bs_pkg 		IS RECORD
														CRC_Value		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG) DOWNTO 0);
														CRC_OK			: std_logic;
														CRC_Error		: std_logic;
													END RECORD;
																
	TYPE bsat_sm_status_bundle_t_bs_pkg 		IS RECORD
														Status_Value	: std_logic_vector(Return_Upper_F_I_PKG(BSAT_SM_Packet_Status_Length_C_BS_PKG) DOWNTO 0);
													END RECORD;
																
	TYPE bsat_sm_data_bundle_t_bs_pkg 			IS RECORD
														Data_Value		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_SM_Packet_User_Data_Length_C_BS_PKG) DOWNTO 0);
													END RECORD;
																
	TYPE bsat_sm_data_crc_bundle_t_bs_pkg 		IS RECORD
														CRC_Value		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_SM_Packet_Data_CRC_Length_C_BS_PKG) DOWNTO 0);
														CRC_OK			: std_logic;
														CRC_Error		: std_logic;
													END RECORD;
																
	TYPE bsat_prtcl_ms_bundle_t_bs_pkg 			IS RECORD
														Header			: bsat_ms_header_bundle_t_bs_pkg;
														Header_CRC		: bsat_ms_header_crc_bundle_t_bs_pkg;
														Data			: bsat_ms_data_bundle_t_bs_pkg;
														Data_CRC		: bsat_ms_data_crc_bundle_t_bs_pkg;
													END RECORD;
																
	TYPE bsat_prtcl_sm_bundle_t_bs_pkg 			IS RECORD
														Status			: bsat_sm_status_bundle_t_bs_pkg;
														Data			: bsat_sm_data_bundle_t_bs_pkg;
														Data_CRC		: bsat_sm_data_crc_bundle_t_bs_pkg;
													END RECORD;
																
																
	TYPE bsat_bus_dock_t_bs_pkg					IS RECORD
														MS_Packet		: bsat_prtcl_ms_bundle_t_bs_pkg;
														SM_Packet		: bsat_prtcl_sm_bundle_t_bs_pkg;
													END RECORD;
																
	-- In this array the actual, the last valid data, of the activated slaves can be found.
	TYPE bsat_sm_msg_array_t_bs_pkg 				IS ARRAY (natural RANGE <>) OF bsat_prtcl_sm_bundle_t_bs_pkg;
	
	-- In this array the actual, the last valid data, for the activated slaves can be found.
	TYPE bsat_ms_msg_array_t_bs_pkg 				IS ARRAY (natural RANGE <>) OF bsat_prtcl_ms_bundle_t_bs_pkg;
	
	-- In this array we can store the transmit data in the master for all the slaves.
	--TYPE bsat_ms_transmit_array_t_bs_pkg		IS ARRAY (natural RANGE <>) OF bsat_prtcl_ms_bundle_t_bs_pkg.Data.Data_value;-- Commented for HDL Designer compatibility.
	TYPE bsat_ms_transmit_array_t_bs_pkg		IS ARRAY (natural RANGE <>) OF std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_Length_C_BS_PKG) DOWNTO 0);
	
	-- In this array the actual data (transmit and receive) of, for all the slaves can be found.
	TYPE bsat_slaves_array_t_bs_pkg				IS ARRAY (natural RANGE <>) OF bsat_bus_dock_t_bs_pkg;
	
	-- In this array the scheduled BSAT transfers can be found.
	TYPE bsat_access_AD_sequence_t_bs_pkg		IS ARRAY	(natural RANGE <>) OF std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG +1 +1) DOWNTO 0);-- The additional Bits hold the information if the address is valid or not (4) and the BRDCST (5).
	
	
	-- Status records of the BSAT_Slave FSM
	TYPE bsat_s_rx_fsm_bundle_t_bs_pkg			IS RECORD
														RX_Active			: std_logic; -- The FSM is receiving a packet at the moment.
														Header_Ready		: std_logic;
														Header_CRC_OK		: std_logic;
														Header_CRC_Error	: std_logic;
														BRCT_Received		: std_logic;
														Data_WR_Strobe		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Data_Word_Count_C_BS_PKG) DOWNTO 0);
														Data_Ready			: std_logic;
														Data_CRC_Error		: std_logic;
														Data_Bit_Nr			: natural RANGE 0 TO BSAT_MS_Packet_User_Data_Length_C_BS_PKG;
														Data_Bit_Value		: std_logic;
														Data_Bit_Valid		: std_logic;
													END RECORD;
																
	TYPE bsat_s_tx_fsm_bundle_t_bs_pkg			IS RECORD
														TX_Active			: std_logic;
														Status_RD_Strobe	: std_logic;
														Data_RD_Strobe		: std_logic_vector(Return_Upper_F_I_PKG(BSAT_SM_Packet_Data_Word_Count_C_BS_PKG) DOWNTO 0);
													END RECORD;
															
															
	TYPE bsat_prtcl_fsm_bundle_t_bs_pkg			IS RECORD
														Header				: bsat_ms_header_bundle_t_bs_pkg;
														Header_CRC			: bsat_ms_header_crc_bundle_t_bs_pkg;
														Status				: bsat_sm_status_bundle_t_bs_pkg;
														Data				: bsat_sm_data_bundle_t_bs_pkg;
														Data_CRC			: bsat_sm_data_crc_bundle_t_bs_pkg;
													END RECORD;
																
	-- Configuration record of the BSAT Core (master & slave)
	TYPE bsat_cfg_core_bundle_t_bs_pkg			IS RECORD
														Core_Role			: natural RANGE 0 TO 1;
														Oversampling		: natural RANGE 0 TO 15;
														DS_Decoding			: natural RANGE 0 TO 1;
														IO_Mode				: natural RANGE 0 TO 1;
														TX_Debugging		: natural RANGE 0 TO 1;
														RX_Debugging		: natural RANGE 0 TO 1;
													END RECORD;
																
	-- Configuration record of the BSAT Controller (master)
	TYPE bsat_cfg_ctrl_bundle_t_bs_pkg			IS RECORD
														IO_Word_Width		: natural RANGE 0 TO 2; -- 0=16Bit, 1=32Bit, 2=64Bit. 
														RAM_Word_Width		: natural RANGE 0 TO 2; -- 0=16Bit, 1=32Bit, 2=64Bit.
														S_Port_Mode_EN		: natural RANGE 0 TO 1; -- 1 = "S-Port Handling needed".
														Exception_Mode		: natural RANGE 0 TO 1; -- 0 = via Status Bits, 1 via add. S-Port job
													END RECORD;
																
	-- Configuration record of the BSAT Node Controller (slave)
	TYPE bsat_cfg_node_ctrl_bundle_t_bs_pkg		IS RECORD
														Dummy2				: std_logic;
														Dummy3				: std_logic;
													END RECORD;
																
	-- Configuration record of the BSAT FSM Top (master)
	TYPE bsat_cfg_ctrl_top_bundle_t_bs_pkg		IS RECORD
														Core				: bsat_cfg_core_bundle_t_bs_pkg;
														Master_Controller	: bsat_cfg_ctrl_bundle_t_bs_pkg;
													END RECORD;
										
	-- Configuration record of the BSAT Node Top (slave)
	TYPE bsat_cfg_node_top_bundle_t_bs_pkg		IS RECORD
														Core				: bsat_cfg_core_bundle_t_bs_pkg;
														Node_Controller		: bsat_cfg_node_ctrl_bundle_t_bs_pkg;
													END RECORD;
	
	-- 2x32Bit I/O-Port record
	TYPE bsat_port_t_bs_pkg						IS RECORD
														IO_Port				: std_logic_vector(31 DOWNTO 0);
														IO_Strobe			: std_logic;
													END RECORD;
		
	-- Array of the 2x32Bit I/O-Port record
	TYPE bsat_port_array_t_bs_pkg				IS ARRAY (natural RANGE <>) OF bsat_port_t_bs_pkg;
	
	
	
   -----------------------
   -- Type Declaration END
   -----------------------

	
	
  
   -----------------------
   -- Constant Declaration
   -----------------------
   -- General constants
	CONSTANT BSAT_DS_Coding_C_BS_PKG								: natural RANGE 0 TO 1:= 1; -- 0 = same speed, 1 = doubled clock speed.
	CONSTANT BSAT_CRC_Polynom_C_BS_PKG								: std_logic_vector(7 DOWNTO 0):= x"97";
	CONSTANT BSAT_IO_Port_Width_max_C_BS_PKG						: natural RANGE 0 TO 64:= 64;
	CONSTANT BSAT_IO_SYNC_Word_Width_C_BS_PKG						: natural RANGE 0 TO 3:= 2; -- 0 = 16Bit, 1 = 32Bit, 2 = 64Bit.
	CONSTANT BSAT_RAM_SYNC_Word_Width_C_BS_PKG						: natural RANGE 0 TO 3:= 0; -- 0 = 16Bit, 1 = 32Bit, 2 = 64Bit.
	CONSTANT BSAT_Besi_IO_Port_Width_C_BS_PKG						: natural RANGE 0 TO 64:= 32;
	CONSTANT BSAT_Besi_IO_Port_max_C_BS_PKG							: natural RANGE 0 TO 3:= 2;
	CONSTANT BSAT_BRCT_AD_EN_C_BS_PKG								: natural RANGE 0 TO 1:= 1; -- Broadcast address enabled.-- In the broadcast case no data is returned by any slave.
	CONSTANT BSAT_BRCT_AD_DEF_C_BS_PKG								: natural RANGE 0 TO 15:= 15; -- Broadcast address definition
	CONSTANT BSAT_BRCT_AD_C_BS_PKG									: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(BSAT_BRCT_AD_DEF_C_BS_PKG, BSAT_MS_Packet_Header_AD_Length_C_BS_PKG));
	
	-- Constants to initialise the data structures
	CONSTANT NA_BSAT_HEADER_MS_BUNDLE_C_BS_PKG						: bsat_ms_header_bundle_t_bs_pkg:= ((OTHERS =>'0'),(OTHERS =>'0'),(OTHERS =>'0'));
	CONSTANT NA_BSAT_HEADER_CRC_MS_BUNDLE_C_BS_PKG					: bsat_ms_header_crc_bundle_t_bs_pkg:= ((OTHERS =>'0'), '0', '0');
	CONSTANT NA_BSAT_DATA_MS_BUNDLE_C_BS_PKG						: bsat_ms_data_bundle_t_bs_pkg:= (OTHERS =>(OTHERS =>'0'));
	CONSTANT NA_BSAT_DATA_CRC_MS_BUNDLE_C_BS_PKG					: bsat_ms_data_crc_bundle_t_bs_pkg:= ((OTHERS =>'0'), '0','0');
	CONSTANT NA_BSAT_PRTCL_MS_BUNDLE_C_BS_PKG						: bsat_prtcl_ms_bundle_t_bs_pkg:= (NA_BSAT_HEADER_MS_BUNDLE_C_BS_PKG,NA_BSAT_HEADER_CRC_MS_BUNDLE_C_BS_PKG,NA_BSAT_DATA_MS_BUNDLE_C_BS_PKG,NA_BSAT_DATA_CRC_MS_BUNDLE_C_BS_PKG);
	
	CONSTANT NA_BSAT_STATUS_SM_BUNDLE_C_BS_PKG						: bsat_sm_status_bundle_t_bs_pkg:= (OTHERS =>(OTHERS =>'0'));
	CONSTANT NA_BSAT_DATA_SM_BUNDLE_C_BS_PKG						: bsat_sm_data_bundle_t_bs_pkg:= (OTHERS =>(OTHERS =>'0'));
	CONSTANT NA_BSAT_DATA_CRC_SM_BUNDLE_C_BS_PKG					: bsat_sm_data_crc_bundle_t_bs_pkg:= ((OTHERS =>'0'), '0', '0');
	CONSTANT NA_BSAT_PRTCL_SM_BUNDLE_C_BS_PKG						: bsat_prtcl_sm_bundle_t_bs_pkg:= (NA_BSAT_STATUS_SM_BUNDLE_C_BS_PKG,NA_BSAT_DATA_SM_BUNDLE_C_BS_PKG,NA_BSAT_DATA_CRC_SM_BUNDLE_C_BS_PKG);
	
	CONSTANT NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG							: bsat_s_rx_fsm_bundle_t_bs_pkg:= ('0','0','0','0','0',(OTHERS =>'0'),'0','0',0,'0','0');
	CONSTANT NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG							: bsat_s_tx_fsm_bundle_t_bs_pkg:= ('0','0',(OTHERS =>'0'));
	
	CONSTANT NA_BSAT_PRTCL_FSM_BUNDLE_C_BS_PKG						: bsat_prtcl_fsm_bundle_t_bs_pkg:= (NA_BSAT_HEADER_MS_BUNDLE_C_BS_PKG,NA_BSAT_HEADER_CRC_MS_BUNDLE_C_BS_PKG,NA_BSAT_STATUS_SM_BUNDLE_C_BS_PKG,NA_BSAT_DATA_SM_BUNDLE_C_BS_PKG,NA_BSAT_DATA_CRC_SM_BUNDLE_C_BS_PKG);
	
	CONSTANT NA_BSAT_Port_C_BS_PKG									: bsat_port_t_bs_pkg:= ((OTHERS => '0'), '0');
	--CONSTANT	NA_BSAT_Port_Array_C_BS_PKG							: bsat_port_array_t_bs_pkg:= (OTHERS => NA_BSAT_Port_C_BS_PKG);
	
	-- BSAT constants related to the implementation of the BSAT Node
	
	
	
	
	
	
   -- ---------------
   -- General Remarks
   -- ---------------
   --
   --
   -- -------------------
   -- General Remarks END
   -- -------------------
   ---------------------------
   -- Constant Declaration END
   ---------------------------
   
   
   

   -----------------------
   -- Function Declaration
   -----------------------

   ---------------------------
   -- Function Declaration END
   ---------------------------
END PACKAGE BSAT_Package;


Package BODY BSAT_Package IS
   



END Package BODY BSAT_Package;