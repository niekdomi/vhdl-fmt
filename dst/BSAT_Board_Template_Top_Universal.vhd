-- Module BSAT Board Template Top                                  			  --
-- VHDL Package Indel_lib.BSAT_Board_Template_Top                             --
--                                                                            --
-- InfoLink, GinLink            Copyright (c): INDEL AG                       --
-- BSAT                         Copyright (c): Besi Switzerland AG            --
--                                                                            --
-- Project:   BSAT                                                            --
--                                                                            --
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland                          --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- This is a top board template for a BSAT slave. It can be used on IP's      --
--	5005-3347 board.																				--
--	General, important remarks can be found in the comment of the					--
--	BSAT_Downloading_Flash_Control entity.													--
-- -------------------------------------------------------------------------- --
-- QFU, 12.01.2018: First draft, V08, simple I/O mode is working, work on     --
--				"complex" mode is going on (sub entity "BSAT_Node_Control").  		--
-- QFU, 19.02.2018: Updated with 2x32Bit ports & "BSAT_Node_Control".			--
--	QFU, 01.10.2018: Added Flash_Loader example.											--
--	QFU, 01.11.2018: Changed rocord ports the separated ports so that they are --
--				comparable to the GinLink entity interface (only on top).			--
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





ENTITY BSAT_Board_Template_Top IS
--	GENERIC	(
--				);
	PORT		(
				-- General signals
				FPGA_CLK25					: IN	std_logic:= '1';
				-- BSAT external bus signals
	         BSAT_Serial_TX_EN			: OUT	std_logic:= '0'; -- BSAT driver enable, has to be connected to the external RS485 transmitter.
			  	BSAT_Serial_TX_Data		: OUT	std_logic:= '1'; -- BSAT TX data output.
				--BSAT_Serial_RX_nEN		: OUT	std_logic:= '0'; -- Could perhaps be used for short/ open detection with certain receivers...
			   BSAT_Serial_RX_Data		: IN	std_logic;
				-- BSAT external module signals
				BSAT_Module_nAD			: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0):= (OTHERS => '1'); -- Address switch input signal.
				--BSAT_Module_MID			: IN	std_logic_vector(7 DOWNTO 0):= (OTHERS => '1'); -- Used if the board support external real MID's.
				-- IO Signals
				CHA            			: IN	std_logic:= '0';
				CHB            			: IN	std_logic:= '0';
				CHI            			: IN	std_logic:= '0';
				CONFIG_N       			: IN	std_logic_vector (3 DOWNTO 0);
				ENC_SUP_STAT_N 			: IN	std_logic:= '1';
				FAULT1_N       			: IN	std_logic:= '1';
				FAULT2_N       			: IN	std_logic:= '1';
				SEN0_N         			: IN	std_logic:= '1';
				SEN1_N         			: IN	std_logic:= '1';
				SPI_SDI        			: IN	std_logic:= '0';
				VMOT_24_STAT_N 			: IN	std_logic:= '1';
				VMOT_54_STAT_N 			: IN	std_logic:= '1';
				LED_GN_N       			: OUT	std_logic:= '0';
				LED_YE_N      				: OUT	std_logic:= '0';
				MOTEN         	 			: OUT	std_logic_vector (4 DOWNTO 1):=(OTHERS => '0');
				MOTIN          			: OUT	std_logic_vector (4 DOWNTO 1):=(OTHERS => '0');
				RESET1_N       			: OUT	std_logic:= '1';
				RESET2_N       			: OUT	std_logic:= '1';
				SLEEP1_N       			: OUT	std_logic:= '1';
				SLEEP2_N       			: OUT	std_logic:= '1';
				SPI_CS_N       			: OUT	std_logic:= '1';
				SPI_SCK        			: OUT	std_logic:= '0';
				SPI_SDO        			: OUT	std_logic:= '0'
				);
END BSAT_Board_Template_Top;



LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.BSAT_Package.all;
USE Indel_lib.Besi_Package.all;


ARCHITECTURE Universal OF BSAT_Board_Template_Top IS


	-------------------
	-- Type Declaration
	-------------------
	
	-----------------------
	-- Type Declaration END
	-----------------------


	-----------------------
	-- Constant Declaration
	-----------------------
	-- Configuration of the slave...
	CONSTANT	Auxiliary_System_C		:	natural RANGE 0 TO 1:= 0;
	CONSTANT	Port_Count_C				:	natural RANGE 0 TO 2:= 2;
	CONSTANT	HID_Count_C					:	natural RANGE 0 TO 32:= 5;
	CONSTANT	Error_Count_Port0_C		:	natural RANGE 0 TO 32:= 2;
	CONSTANT	Error_Count_Port1_C		:	natural RANGE 0 TO 32:= 3;
	CONSTANT	Error_Count_PortU_C		:	natural RANGE 0 TO 32:= 0;
	CONSTANT	User_RAM_EN_C				:	natural RANGE 0 TO 1:= 1;
	CONSTANT	FeatureID_C					:	natural RANGE 0 TO 255:= 3;
	CONSTANT	BugfixID_C					:	natural RANGE 0 TO 255:= 6;
	CONSTANT	BuildID_C					:	natural RANGE 0 TO 255:= 1;
	CONSTANT	EXT_MID_Port_Width_C		:	natural RANGE 0 TO 8:= 0; -- Number of MID Bits that are routed out of the FPGA (needed for generating a working debug MID).
	CONSTANT	INC_MID_C					:	natural RANGE 0 TO 255:= 1;
	-- Name and number of my board
	CONSTANT	BSAT_Board_Type_C			:	string:= "MOT_V02"; -- See software guides concerning allowed characters an the naming in general (at least look in the BSAT memory map).
	CONSTANT	BSAT_Board_Number_C		:	string:=	"5005-3347";
	CONSTANT	Besi_Target_Device		:	target_device_bundle_t_b_pkg:= (5,2,1,0,1,0,0); -- MAX10,M08(see MAX10 package),dualBoot,SPI_Flash,MFD_Stored,RAM_Loader,RAM_Size=0. The dual boot paramter plays a centrel role...look in the BSAT_Downloading_Flash_Control comments.
	---------------------------
	-- Constant Declaration END
	---------------------------
	
	
	---------------------
   -- Signal Declaration
   ---------------------
	SIGNAL	CLK62_5					:	std_logic;
	SIGNAL	CLK125					:	std_logic;
	SIGNAL	ECLK125					:	std_logic;
	SIGNAL	CLK250					:	std_logic;
	SIGNAL	ADCCLK10					:	std_logic;
	SIGNAL	CLR_n						:	std_logic;
	SIGNAL	GPLL_Locked				:	std_logic;
	SIGNAL	BSAT_External_MID		:	std_logic_vector(7 DOWNTO 0);
	SIGNAL	BSAT_Port_A_Out		:	std_logic_vector(Return_Upper_F_I_PKG(32) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	BSAT_Port_B_Out		:	std_logic_vector(Return_Upper_F_I_PKG(32) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	BSAT_Port_A_WR_ST		:	std_logic:= '0';
	SIGNAL	BSAT_Port_B_WR_ST		:	std_logic:= '0';
	SIGNAL	BSAT_Port_A_In			:	std_logic_vector(Return_Upper_F_I_PKG(32) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	BSAT_Port_B_In			:	std_logic_vector(Return_Upper_F_I_PKG(32) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	BSAT_Port_A_RD_ST		:	std_logic:= '0';
	SIGNAL	BSAT_Port_B_RD_ST		:	std_logic:= '0';
	SIGNAL	BSAT_Data_In			:	bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count_C) DOWNTO 0);
	SIGNAL	BSAT_Data_Out			:	bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count_C) DOWNTO 0);
	SIGNAL	Ports_RD_ST				:	std_logic_vector(Return_Upper_F_I_PKG(Port_Count_C) DOWNTO 0);
	SIGNAL	Ports_WR_ST				:	std_logic_vector(Return_Upper_F_I_PKG(Port_Count_C) DOWNTO 0);
	SIGNAL	BSAT_FSM_RX_Status	:	bsat_s_rx_fsm_bundle_t_bs_pkg;
	SIGNAL	BSAT_FSM_TX_Status	:	bsat_s_tx_fsm_bundle_t_bs_pkg;
	SIGNAL	BSAT_Node_Status		:	besi_node_status_bundle_t_b_pkg:= NA_BESI_NODE_STATUS_BUNDLE_C_B_PKG;
	SIGNAL	Slave_Errors			:	bsat_port_array_t_b_pkg(1 DOWNTO 0);
	SIGNAL	Slave_Error_CLRs		:	bsat_port_array_t_b_pkg(1 DOWNTO 0);
	SIGNAL	Slave_Errors_User		:	std_logic_vector(Return_Upper_F_I_PKG(Error_Count_PortU_C) DOWNTO 0);
	SIGNAL	Slave_Error_CLRs_User:	std_logic_vector(Return_Upper_F_I_PKG(Error_Count_PortU_C) DOWNTO 0);
	SIGNAL	HID						:	std_logic_vector(Return_Upper_F_I_PKG(HID_Count_C) DOWNTO 0):= (OTHERS => '0');
	SIGNAL	User_Port				:	bsat_user_ram_port_bundle_t_b_pkg:= NA_BSAT_USER_RAM_PORT_BUNDL_C_B_PKG;
	SIGNAL	Flash_Port				:	bsat_flash_port_bundle_t_b_pkg:= NA_BSAT_FLASH_PORT_BUNDLE_C_B_PKG;
	-------------------------
   -- Signal Declaration END
   -------------------------


	------------------------
	-- COMPONENT Declaration
	------------------------
	COMPONENT PLL
	PORT		(
				areset	: IN  std_logic:= '0';
				inclk0	: IN  std_logic:= '0';
				c0			: OUT std_logic;
				c1			: OUT std_logic;
				c2			: OUT std_logic;
				c3			: OUT std_logic;
				c4			: OUT std_logic;
				locked	: OUT std_logic 
				);
	END COMPONENT PLL;
	
	
	COMPONENT BSAT_Node
	GENERIC	(
				Auxiliary_System			:	natural RANGE 0 TO 1:= 0; -- 0 = Standard Node, 1 = Auxiliary Node (to be stored in Auxiliary Flash range)
				Port_Count					:	natural RANGE 0 TO 2:= 2;
				Port_Error_Count    		:	bsat_error_number_array_t_b_pkg(0 TO 1):= (OTHERS=> 0); -- Number of errors per port. e.g. (5,2,12,OTHERS=>0)
				HID_Count					:	natural RANGE 0 TO 32:= 5;
				User_Port_EN				:	natural RANGE 0 TO 1:= 0;
				User_Port_Error_Count	:	natural RANGE 0 TO 32:= 0;
				BSAT_Board_Type			:	string:= "MOT_V01";
				BSAT_Board_Number			:	string:= "5005-3347";
				EXT_MID_Port_Width		:	natural RANGE 0 TO 8:= 0; -- Number of MID Bits that are routed out of the FPGA (needed for generating a working debug MID).
				FeatureID					:	natural RANGE 0 TO 255;
				BugfixID						:	natural RANGE 0 TO 255;
				BuildID						:	natural RANGE 0 TO 255:= 1;
				INC_MID						:	natural RANGE 0 TO 255;
				Target_Family				:	natural RANGE 0 TO 15; -- 1=C1&C2, 2=C3&C4, 3=C5, 4=C10, 5=M10	
				Target_Variation			:	natural RANGE 0 TO 7; -- See device packages
				Target_Boot_Mode			:	natural RANGE 0 TO 1; -- see device packages
				Target_SPI_Flash			:	natural RANGE 0 TO 7; -- SPI flash device type ("Config_Device)
				Target_MFD_Storage		:	natural RANGE 0 TO 1;
				Target_RAM_Loader			:	natural RANGE 0 TO 1; -- Do we have to 
				Target_RAM_Size			:	natural RANGE 0 TO 16#3DFF#
				);
	PORT		(
				-- General signals
				CLK250						: IN		std_logic:= '0';
				CLK125						: IN		std_logic;
				CLK62_5						: IN		std_logic:= '0';
				CLR_n							: IN		std_logic:= '0';
				-- BSAT external bus signals
	         BSAT_Serial_TX_EN			: OUT		std_logic:= '0'; -- BSAT driver enable, has to be connected to the external RS485 transmitter.
			   BSAT_Serial_TX_Data		: OUT		std_logic:= '1'; -- BSAT TX data output.
				BSAT_Serial_RX_nEN		: OUT		std_logic:= '0'; -- Could perhaps be used for short/ open detection with certain receivers...
			   BSAT_Serial_RX_Data		: IN		std_logic;
				-- BSAT external module signals
				BSAT_Module_AD				: IN		std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0):= (OTHERS => '1'); -- Address switch input signal.
				BSAT_Module_MID			: IN		std_logic_vector(7 DOWNTO 0):= (OTHERS => '0');
				-- IO Ports
				Ports_In						: IN		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => (OTHERS => '0'));
				Ports_Out					: OUT		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0);
				Ports_RD_ST					: OUT		std_logic_vector(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => '0');
				Ports_WR_ST					: OUT		std_logic_vector(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => '0');
				-- Node Ports
				HID							: IN		std_logic_vector(Return_Upper_F_I_PKG(HID_Count) DOWNTO 0):= (OTHERS => '0');
				Errors						: IN		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => (OTHERS => '0'));
				Error_CLRs					: OUT		bsat_port_array_t_b_pkg(Return_Upper_F_I_PKG(Port_Count) DOWNTO 0):= (OTHERS => (OTHERS => '0'));
				-- User Port
				User_Port_AD_Ready		: OUT		std_logic;
				User_Port_Data_Ready		: OUT		std_logic;
				User_Port_WREN				: OUT		std_logic;
				User_Port_AD				: OUT		std_logic_vector(7 DOWNTO 0);
				BSAT_User_Port_Data		: OUT		std_logic_vector((Return_Selection_natural_F_I_PKG(BSAT_M_CFG_FSM_S_Port_EN_C_B_PKG,ON_C_I_PKG,0,48) +15) DOWNTO 0);
				User_Port_BSAT_Data		: IN		std_logic_vector((Return_Selection_natural_F_I_PKG(BSAT_M_CFG_FSM_S_Port_EN_C_B_PKG,ON_C_I_PKG,0,48) +15) DOWNTO 0);
				Errors_User_Port			: IN		std_logic_vector(Return_Upper_F_I_PKG(User_Port_Error_Count) DOWNTO 0);
				Error_CLRs_User_Port		: OUT		std_logic_vector(Return_Upper_F_I_PKG(User_Port_Error_Count) DOWNTO 0);
				-- Flash Port
				Flash_Port					: INOUT	bsat_flash_port_bundle_t_b_pkg:= NA_BSAT_FLASH_PORT_BUNDLE_C_B_PKG;
				-- Interface to external devices: MCU, SPI, etc.
				External_Ports				: INOUT	bsat_external_port_bundle_t_b_pkg:= NA_BSAT_EXTERNAL_PORTS_BUNDLE_C_B_PKG;
				-- Status information of the Node
				Status_Scan_Done			: OUT		std_logic;
				Status_ID_Successful		: OUT		std_logic;
				Status_PlugPlay_OE		: OUT		std_logic;
				Status_PlugPlay_WDog		: OUT		std_logic;
				Status_BSAT_Error			: OUT		std_logic;
				Status_nStatus_LED		: OUT		std_logic
				);
	END COMPONENT BSAT_Node;
	
	
	COMPONENT User_RAM
	PORT	(
			address_a	: IN	std_logic_vector(4 DOWNTO 0);
			address_b	: IN	std_logic_vector(3 DOWNTO 0);
			clock_a		: IN	std_logic:= '1';
			clock_b		: IN 	std_logic;
			data_a		: IN	std_logic_vector(15 DOWNTO 0);
			data_b		: IN	std_logic_vector(31 DOWNTO 0);
			wren_a		: IN	std_logic:= '0';
			wren_b		: IN	std_logic:= '0';
			q_a			: OUT	std_logic_vector(15 DOWNTO 0);
			q_b			: OUT	std_logic_vector(31 DOWNTO 0)
			);
	END COMPONENT User_RAM;
	
	   -- PRAGMA SYNTHESIS_OFF
	FOR ALL : PLL USE ENTITY Indel_lib.PLL;
	FOR ALL : BSAT_Node USE ENTITY Indel_lib.BSAT_Node;
	FOR ALL : User_RAM USE ENTITY Indel_lib.User_RAM;
	-- PRAGMA SYNTHESIS_ON
	----------------------------
	-- COMPONENT Declaration END
	----------------------------
	
	BEGIN
	
		-- Debug 0
		SPI_SCK <= Flash_Port.Trigger;
	
		-- Concurrent 0
		LED_GN_N <= BSAT_Node_Status.nStatus_LED;
		LED_YE_N <= '1';
		
		-- Concurrent 1
		-- Assign the real MID:
		--BSAT_External_MID <= BSAT_Module_MID;
		BSAT_External_MID <= X"01";
	
		--------------------------
		-- Global clock generation
		--------------------------
		-- Attention: The PLL entity instantiation is configured for 25MHz.
		Global_PLL: PLL
		PORT MAP	(
					areset	=> '0', -- Asynchronous external RST signal, change to the solution used in your design!!!
					inclk0	=> FPGA_CLK25, -- Input base clock
					c0			=> ADCCLK10, -- Out 0, 10MHz, ADC clock, has to be 
					c1			=> CLK125, -- Out 1, 125MHz
					c2			=> CLK62_5, -- Out 2, 62.5MHz
					c3			=> ECLK125, -- Out 3, 125MHz phase shifted
					c4			=> CLK250, -- Out 4, 250MHz
					locked	=> GPLL_Locked -- Lock signal of the global PLL
					);
		------------------------------
		-- Global clock generation END
		------------------------------
		
		
		-- Concurrent 2, implement the appropriate solution for your design (sync., etc.)
		CLRReg: PROCESS(CLK125)
			VARIABLE clr_cnt : natural RANGE 0 TO 3 := 0;
		BEGIN
			IF (CLK125'EVENT AND CLK125 = '1') THEN
				IF clr_cnt >= 3 THEN
					CLR_n <= '1';
				ELSE
					CLR_n <= '0';
					clr_cnt := clr_cnt + 1;
				END IF;
			END IF;
		END PROCESS CLRReg;
	
	
	
		------------
		-- The Slave
		------------
		BSAT_Slave: BSAT_Node
			GENERIC MAP	(
							Auxiliary_System			=>	Auxiliary_System_C,-- 0 = Standard Node, 1 = Auxiliary Node (to be stored in Auxiliary Flash range)
							Port_Count					=>	Port_Count_C,
							Port_Error_Count    		=>	(Error_Count_Port0_C,Error_Count_Port1_C),-- Number of errors per port. e.g. (5,2,12,OTHERS=>0)
							HID_Count					=>	HID_Count_C,
							User_Port_EN				=>	User_RAM_EN_C,
							User_Port_Error_Count	=>	Error_Count_PortU_C,
							BSAT_Board_Type			=>	BSAT_Board_Type_C,
							BSAT_Board_Number			=>	BSAT_Board_Number_C,
							EXT_MID_Port_Width		=>	EXT_MID_Port_Width_C, -- Number of MID Bits that are routed out of the FPGA (needed for generating a working debug MID).
							FeatureID					=>	FeatureID_C,
							BugfixID						=>	BugfixID_C,
							BuildID						=>	BuildID_C,
							INC_MID						=>	INC_MID_C,
							Target_Family				=>	Besi_Target_Device.Family,
							Target_Variation			=>	Besi_Target_Device.Variation,
							Target_Boot_Mode			=>	Besi_Target_Device.Boot_Mode,
							Target_SPI_Flash			=>	Besi_Target_Device.SPI_Flash,
							Target_MFD_Storage		=>	Besi_Target_Device.MFD_Storage,
							Target_RAM_Loader			=>	Besi_Target_Device.RAM_Loader,
							Target_RAM_Size			=>	Besi_Target_Device.RAM_Size
							)
			PORT MAP		(
							-- General signals
							CLK250						=>	CLK250,
							CLK125						=>	CLK125,
							CLK62_5						=> CLK62_5,
							CLR_n							=> CLR_n,
							-- BSAT external bus signals
	         			BSAT_Serial_TX_EN			=> BSAT_Serial_TX_EN, -- BSAT driver enable, has to be connected to the external RS485 transmitter.
			   			BSAT_Serial_TX_Data		=> BSAT_Serial_TX_Data, -- BSAT TX data output.
							BSAT_Serial_RX_nEN		=> OPEN,--BSAT_Serial_RX_nEN, -- Could perhaps be used for short/ open detection with certain receivers...
			   			BSAT_Serial_RX_Data		=> BSAT_Serial_RX_Data,
							-- BSAT external module signals
							BSAT_Module_AD				=> NOT(BSAT_Module_nAD), -- Address switch input signal.
							BSAT_Module_MID			=>	BSAT_External_MID, -- External MID input signal.
							-- IO Ports
							Ports_In						=>	BSAT_Data_In,
							Ports_Out					=>	BSAT_Data_Out,
							Ports_RD_ST					=>	Ports_RD_ST,
							Ports_WR_ST					=>	Ports_WR_ST,
							-- Node Ports
							HID							=> HID,
							Errors						=> Slave_Errors,
							Error_CLRs					=> Slave_Error_CLRs,
							-- User Port
							User_Port_AD_Ready		=>	User_Port.BSAT_AD_Ready,
							User_Port_Data_Ready		=>	User_Port.BSAT_Data_Ready,
							User_Port_WREN				=>	User_Port.BSAT_WREN,
							User_Port_AD				=>	User_Port.BSAT_AD,
							BSAT_User_Port_Data		=>	User_Port.BSAT_Data,
							User_Port_BSAT_Data		=>	User_Port.User_Data,
							Errors_User_Port			=> Slave_Errors_User,
							Error_CLRs_User_Port		=> Slave_Error_CLRs_User,
							-- Flash Port
							Flash_Port					=> Flash_Port,
							-- Interface to external devices: MCU, SPI, etc.
							External_Ports				=>	OPEN,
							-- Status information of the Node
							Status_Scan_Done			=>	BSAT_Node_Status.Scan_Done,
							Status_ID_Successful		=>	BSAT_Node_Status.ID_Successful,
							Status_PlugPlay_OE		=>	BSAT_Node_Status.PlugPlay_OE,
							Status_PlugPlay_WDog		=>	BSAT_Node_Status.PlugPlay_WDog,
							Status_BSAT_Error			=>	BSAT_Node_Status.BSAT_Error,
							Status_nStatus_LED		=>	BSAT_Node_Status.nStatus_LED
							);
		----------------
		-- The Slave END
		----------------
							
	
		-- Concurrent Errors:
		Slave_Errors(0)(1 DOWNTO 0) <= BSAT_Port_A_Out(1 DOWNTO 0);
		Slave_Errors(0)(31 DOWNTO 2) <= (OTHERS => '0');
		Slave_Errors(1)(2 DOWNTO 0) <= BSAT_Port_A_Out(6 DOWNTO 4);
		Slave_Errors(1)(31 DOWNTO 3) <= (OTHERS => '0');
		Slave_Errors_User <= (OTHERS => '0');
		HID <= BSAT_Port_B_Out(Return_Upper_F_I_PKG(HID_Count_C) DOWNTO 0);
		

	
		-- IO Ports:
		Assign_Outputs: PROCESS(CLK125, CLR_n)
		BEGIN
			IF (CLR_n = '0') THEN
				BSAT_Port_A_Out <= (OTHERS => '0');
				BSAT_Port_B_Out <= (OTHERS => '0');
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (Ports_WR_ST(0) = '1') THEN
					BSAT_Port_A_Out	<= BSAT_Data_Out(0);
				END IF;
				IF (Ports_WR_ST(1) = '1') THEN
					BSAT_Port_B_Out	<= BSAT_Data_Out(1);
				END IF;
			END IF;
		END PROCESS Assign_Outputs;
	
	
		-- "Test Design"
		Assign_Inputs: PROCESS(CLK125, CLR_n)
		BEGIN
			IF (CLR_n = '0') THEN
				BSAT_Data_In <= (OTHERS => (OTHERS => '0'));
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (Ports_RD_ST(0) = '1') THEN
					BSAT_Data_In(0) <= NOT(BSAT_Port_A_Out);
				END IF;
				IF (Ports_RD_ST(1) = '1') THEN
					BSAT_Data_In(1) <= NOT(BSAT_Port_B_Out);
				END IF;
			END IF;
		END PROCESS Assign_Inputs;
	
	

		-- Example how to initialize the RAM. The "user logic side" of the RAM is mapped to the user flash space in this example to be able th read it back via software.
		--		This example is used to show two things: a.) the User_RAM Space, b.) the RAM_Loader to initialize the RAM in "dual boot mode".
		User_RAM_Loader_Example:	IF ((Besi_Target_Device.Boot_Mode = 1) AND (User_RAM_EN_C = 1)) GENERATE
			SIGNAL	User_WREN				: std_logic;
			SIGNAL	Flash_Loader_WREN		: std_logic;
		BEGIN
		
			User_WREN <= User_Port.BSAT_WREN  WHEN (User_Port.BSAT_AD(7 DOWNTO 5) = "000") ELSE '0';
			Flash_Loader_WREN <= Flash_Port.Loader_WREN WHEN (Flash_Port.Loader_AD(7 DOWNTO 4) = "0000") ELSE '0';
			---------------
			-- The User RAM
			---------------
			Example_RAM: User_RAM
			PORT MAP	(
						address_a	=> User_Port.BSAT_AD(4 DOWNTO 0),
						address_b	=> Flash_Port.Loader_AD(3 DOWNTO 0),
						clock_a		=> CLK62_5,
						clock_b		=> Flash_Port.Loader_CLK,
						data_a		=> User_Port.BSAT_Data,
						data_b		=> Flash_Port.Loader_Data,
						wren_a		=> User_WREN,
						wren_b		=> Flash_Loader_WREN,
						q_a			=> User_Port.User_Data,
						q_b			=> OPEN
						);
			-------------------
			-- The User RAM END
			-------------------
		END GENERATE User_RAM_Loader_Example;
		
		
		-- There is no User_RAM to instantiate.
		No_User_RAM: IF (User_RAM_EN_C = 0) GENERATE
		BEGIN
			User_Port.User_Data <= (OTHERS => '0');
		END GENERATE No_User_RAM;
		
			
	
	END ARCHITECTURE Universal;