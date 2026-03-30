-- Module BSAT Core 
-- VHDL Architecture Indel_lib.BSAT_Core.Universal
--
-- InfoLink, GinLink Copyright (c): INDEL AG
-- BSAT (c): Besi Switzerland
--
-- Project:   Dragon GinLink_Integration
-- 
-- qfu, 225
-- 15.06.2016
-- This entity is the wrapper for the BSAT slave functionality
-- 
--
-- Description, remarks (status 12.12.2019):
-- 
-- 1.) The address switch signal is sampled each time after the start of a new data packet is detected on the bus.
-- This is done this way round that a hot plug functionality could be implmented somehow in the future.
-- 2.) How to make sure that the actual values are read at the sme time in the BSAT slave?- 
-- The BSAT slave has 4 different RD-Strobe signals. If you want to make sure that the whole 64Bit are sampled at the same time,
-- take the singal "Data_RD_Strobe(0)" as EN signal to store the values for the input signals for the slave. If the 64Bit data
-- consist of two 32Bit words, use the "Data_RD_Strobe(0)" and "Data_RD_Strobe(2)" signals. I you have divided the 64Bit into four
-- 16Bit values use all the "Data_RD_Strobe(3..0)" signals.
--
-- History:
--		1.	Initial version
--		2.	The separate master and slave FSM's are united into the "core". This way round protocol changes that influence the master
--			and the slave can be handled in the same file. => Reduced danger that master and slave are drifting away from each other.
--		3.	Added changes for the master role.
--		4.	Bugfix, "New_TX_Transfer" is disabled now in RX FSM one state after activating it in the slave role.
--		5.	Corrected the Header-CRC calculation when the LSB in the Header.PARAM word is a '1'.
--		6.	Deactivated the "hack" that was used during the tests of Dieter Wettstein by default.
--		7.	Simplest plausibility checks to disable receiveing in the master as long as no data is sent at all.
--		8.	Additional specific Broadcast signal and configurable address added in the FSM RX record so that the broadcast situation can be identified better.
--		9.	Predriving capability added when the core is used in slave mode (see signal "Pre_BSAT_Serial_TX_EN").
--		10.	Changed the filler Bits for CRC data (RX sDATA3) in the TX Slave case to 0x00 so that there is no o_Pause signal genrated when there is a jitter of 4ns.
--		11.	Added the simplest and most flexible solution to allow the prefetching for the receive data (on Bit level) before the CRC check is executed.
--			Take care: The transmission on the BSAT bus is done aligned to the COP bus. This means native word width is 16Bit, MSB first. Conclusion:
--			Looking at it on a Bit number level: => 15,14,...,1,0,31,30,...,17,16,47,46,...,33,32,63,62,...,49,48.
--			For Besi this means: Port0(15)...Port(0) & Port0(31)...Port0(16) & Port1(15)...Port1(0) & Port1(31)...Port1(16).
--		12.	Clear the "BSAT_RX_Packet.Data.Data_Value" not already at the end of the RX packet, wait till the RX sInit FSM state instead. (12.12.2019)
--		13.	For Besi internal tests it is now possible the run the BSAT bus with half the speed. (23.01.2020)
--			
--
-- ---------------------------------------------------------------------------
-- 
-- ---------------------------------------------------------------------------
-- -- Remarks to the implementation:
-- ---------------------------------------------------------------------------
-- 1.) All the data types are defined in the BSAT package.
-- 2.) The "BSAT_MS" and "BSAT_SM" records hold the bus data- "BSAT_TX_FSM_Status" and "BSAT_TX_FSM_Status" indicate the FSM state.
--
-- ---------------------------------------------------------------------------
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
USE Indel_lib.BSAT_Package.all;



ENTITY BSAT_Core IS
   GENERIC 	(
			BSAT_Core_Role			: natural RANGE 0 TO 1:= 1; -- Slave = 1, Master = 0,
			BSAT_Oversampling		: natural RANGE 0 TO 15:= 8;
			BSAT_DS_Decoding		: natural RANGE 0 TO 1:= 0;
			BSAT_IO_Mode_EN      	: natural RANGE 0 TO 1:= 0; -- Enable the simple I/O mode: 1 = "ON", 0 = "OFF"
			BSAT_TX_Debugging		: natural RANGE 0 TO 1:= 1; -- Allows to instantiate a signal that shows the actual 16bit TX data.
			BSAT_RX_Debugging		: natural RANGE 0 TO 1:= 1 -- Allows to instantiate a signal that shows the actual 16bit RX data.
			);
	PORT	(
			CLK125					: IN	std_logic;
			CLK250					: IN	std_logic:= '0'; -- This is an aditional clock that can be used as fast source for the the InfoLink encoder and decoder only (higher oversampling).
            CLR_n_CLK125			: IN  	std_logic;
			-- BSAT external bus signals
            BSAT_Serial_TX_EN		: OUT	std_logic:= '0'; -- BSAT driver enable, has to be connected to the external RS485 transmitter.
		    BSAT_Serial_TX_Data		: OUT	std_logic:= '1'; -- BSAT TX data output.
			BSAT_Serial_RX_nEN		: OUT	std_logic:= '0'; -- Could perhaps be used for short/ open detection with certain receivers...
		    BSAT_Serial_RX_Data		: IN	std_logic;
			-- BSAT external module signals
			BSAT_Module_AD			: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0):= (OTHERS => '1'); -- Address switch input signal.
			-- BSAT status signals
			BSAT_Transfer_Start  	: IN  	std_logic:= '0';
			BSAT_Ready           	: OUT	std_logic;
			-- BSAT FSM status signals
			BSAT_RX_FSM_Status		: OUT	bsat_s_rx_fsm_bundle_t_bs_pkg:= NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG;
			BSAT_TX_FSM_Status		: OUT	bsat_s_tx_fsm_bundle_t_bs_pkg:= NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG;
			-- BSAT complete interface
			BSAT_MS					: INOUT bsat_prtcl_ms_bundle_t_bs_pkg:= NA_BSAT_PRTCL_MS_BUNDLE_C_BS_PKG;
			BSAT_SM					: INOUT bsat_prtcl_sm_bundle_t_bs_pkg:= NA_BSAT_PRTCL_SM_BUNDLE_C_BS_PKG;
			-- BSAT IO signals
			BSAT_IO_Port_In			: IN	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0):= (OTHERS => '0');
			BSAT_IO_Port_Out		: OUT	std_logic_vector(Return_Upper_F_I_PKG(BSAT_IO_Port_Width_max_C_BS_PKG) DOWNTO 0)
			);
END BSAT_Core;




ARCHITECTURE Universal OF BSAT_Core IS



	--------------------
	-- Type Declarations
	--------------------
	TYPE bsat_core_rx_state IS
		(
		sStart,
		sInit,
		sIdle,
		sHeader,
		sCRC_Header,
		sHeader_CRC_Error,
		sStatus,
		sData,
		sData0,
		sData1,
		sData2,
		sData3,
		sCRC_Data,
		sData_CRC_Error,
		sRX_Terminate,
		sIgnore,
		sEnd,
		sPause,
		sStop
		);
	
	TYPE bsat_core_tx_state IS
		(
		sInit,
		sIdle,
		sScan,
		sRun,
		sStart,
		sHeader,
		sCRC_Header,
		sStatus,
		sDATA,
		sData0,
		sData1,
		sData2,
		sData3,
		sCRC_Data,
		sEnd,
		sPause,
		sStop
		);
	------------------------
	-- Type Declarations END
	------------------------



	-----------------------
	-- Constant Declaration
	-----------------------
	CONSTANT BSAT_TX_Packet_Data_CRC_Length	: natural := Return_Selection_natural_F_I_PKG(BSAT_Core_Role,1,BSAT_SM_Packet_Data_CRC_Length_C_BS_PKG,BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG);
	CONSTANT BSAT_RX_Packet_Data_CRC_Length	: natural := Return_Selection_natural_F_I_PKG(BSAT_Core_Role,1,BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG,BSAT_SM_Packet_Data_CRC_Length_C_BS_PKG);
	---------------------------
	-- Constant Declaration END
	---------------------------


	------------------------------------------------
	-- Signal Declaration for Architecture BSAT_Core
	------------------------------------------------
	SIGNAL CLK_DEC							: std_logic;
	SIGNAL CLK_ENC							: std_logic;
	SIGNAL CLR_n							: std_logic;
	SIGNAL Test_Counter						: natural;
	SIGNAL BSAT_Transfer_Running			: std_logic;
	SIGNAL New_TX_Transfer					: std_logic;
	SIGNAL Delay_Lock						: std_logic :='0';
	SIGNAL BSAT_Serial_TX_EN_Int			: std_logic;
	SIGNAL Pre_BSAT_Serial_TX_EN			: std_logic := '0';
	
	SIGNAL BSAT_TX_Seq_EN					: std_logic;
	SIGNAL BSAT_RX_Seq_EN					: std_logic;
	SIGNAL BSAT_TX_Seq_State				: bsat_core_tx_state;
	SIGNAL BSAT_RX_Seq_State				: bsat_core_rx_state;
	SIGNAL BSAT_TX_SR						: std_logic_vector(15 DOWNTO 0);
	SIGNAL BSAT_RX_SR						: std_logic_vector(15 DOWNTO 0);
	SIGNAL BSAT_TX_Word_Data				: std_logic_vector(15 DOWNTO 0);
	SIGNAL BSAT_RX_Word_Data				: std_logic_vector(15 DOWNTO 0);

	SIGNAL BSAT_TX_CRC						: std_logic_vector(Return_Upper_F_I_PKG(BSAT_CRC_Length_C_BS_PKG) DOWNTO 0);
	SIGNAL BSAT_RX_CRC						: std_logic_vector(Return_Upper_F_I_PKG(BSAT_CRC_Length_C_BS_PKG) DOWNTO 0);
	
	SIGNAL GLB_RX_Counter					: natural RANGE 0 TO 127 := 0;
	SIGNAL TX_Count							: natural RANGE 0 TO 63 := 0;
	SIGNAL RX_Count							: natural RANGE 0 TO 63 := 0;
	SIGNAL Data_Bit_Counter					: natural RANGE 0 TO 63 := 0; -- RX Databit Counter for prefetching.
	
	SIGNAL BSAT_TXr							: std_logic:='0';
	SIGNAL BSAT_RXr							: std_logic;
	SIGNAL RX_Pause							: std_logic;
	SIGNAL RX_Pause_Int						: std_logic;
	SIGNAL BC1								: std_logic;
	SIGNAL BC2								: std_logic;
	SIGNAL BSAT_TX_Pause					: std_logic;
	
	SIGNAL BSAT_RX_Packet					: bsat_prtcl_fsm_bundle_t_bs_pkg; -- We are using a default data type for eccessing the data in the FSM (RX and TX).
	SIGNAL BSAT_TX_Packet					: bsat_prtcl_fsm_bundle_t_bs_pkg;
	
	SIGNAL BSAT_RX_FSM_Status_Int			: bsat_s_rx_fsm_bundle_t_bs_pkg; -- This record holds the status information of the FSM
	SIGNAL BSAT_TX_FSM_Status_Int			: bsat_s_tx_fsm_bundle_t_bs_pkg;
	
	SIGNAL BSAT_Module_AD_Int				: std_logic_vector(Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_AD_Length_C_BS_PKG) DOWNTO 0);
	
	SIGNAL BSAT_RX_ACT_Data_Word			: natural RANGE 0 TO BSAT_RX_MAX_Data_Words_C_BS_PKG :=0;
	SIGNAL BSAT_TX_ACT_Data_Word			: natural RANGE 0 TO BSAT_RX_MAX_Data_Words_C_BS_PKG :=0;
	
	-- Debugging
	SIGNAL BSAT_IO_Port_Out_Int				: std_logic_vector(63 DOWNTO 0);
	SIGNAL RX_Data_Dummy					: std_logic_vector(63 DOWNTO 0);
	SIGNAL RX_Data_Dummy_Int				: std_logic_vector(63 DOWNTO 0);
	
	SIGNAL TX_Header_ACT					: std_logic_vector(15 DOWNTO 0):=(OTHERS => '0');
	SIGNAL TX_Data_ACT						: std_logic_vector(63 DOWNTO 0);
	----------------------------------------------------
	-- Signal Declaration for Architecture BSAT_Core END
	----------------------------------------------------



	------------------------
	-- COMPONENT Declaration
	------------------------
	COMPONENT InfoLink_Decoder 
	GENERIC	( 
			C_CLK_DIV_22MHZ 				: integer :=4;	--88MHz
			C_NO_FIBRE_DESKEW 				: integer RANGE 0 TO 1 :=0; -- 0-> invert input and deskew of h pulse
			C_CONTINUOUS_BITCLK 			: integer RANGE 0 TO 1 :=0;
			C_DS_DECODING 					: integer range 0 to 1 :=0	-- allows to run InfoLink cecoder with doubled CLK frequency compared to the rest of the design.
			);
	PORT	(     
			-- Std-Ports
			i_Clk							: IN	std_logic; -- clock 
			i_Rst							: IN	std_logic; -- reset
			-- Info-Link-ports 
			-- LINK
			i_RX							: IN	std_logic; -- Info-Link input
			-- Codec
			o_RXd							: OUT	std_logic; -- RX-data output decoded	
			o_RErr							: OUT	std_logic; -- RX-Error  
			o_Paus							: OUT	std_logic; -- Pause      
			o_BitClk						: OUT	std_logic; -- RXCnt(x);    
			o_LiErr							: OUT	std_logic; -- dignosis link-error
			i_clrLiErr						: IN	std_logic;
			o_bc1							: OUT	std_logic;
			o_bc2							: OUT	std_logic
			);
	END COMPONENT InfoLink_Decoder;
	
	
	
	COMPONENT InfoLink_Encoder
	GENERIC	( 
			C_CLK_DIV_22MHZ 				: integer :=3;
			C_EXTERNAL_BITCLK 				: integer RANGE 0 TO 1 :=0;
			C_DS_ENCODING 					: integer range 0 to 1 :=0 -- allows to run InfoLink cecoder with doubled CLK frequency compared to the rest of the design.
			);
	PORT	(     
			-- Std-Ports
			i_Clk							: IN	std_logic; -- clock 
			i_Rst							: IN	std_logic; -- reset
			-- Info-link-Ports 
			-- LINK
			o_TX							: OUT	std_logic; -- Info-Link output 
			-- Encoder                    			
			i_TXd							: IN	std_logic; -- TX-data input decoded  
			i_Pause							: IN	std_logic; -- H: don't send (TX=H)
			i_TXErr							: IN	std_logic; -- H: generate modulations errors
			o_BitClk						: OUT	std_logic; -- __-_____-_____-			
			i_bc1							: IN	std_logic:='0';
			i_bc2							: IN	std_logic:='0'
			);
	END COMPONENT InfoLink_Encoder;
	

	-- PRAGMA SYNTHESIS_OFF
	FOR ALL : InfoLink_Decoder USE ENTITY Indel_lib.InfoLink_Decoder;
	FOR ALL : InfoLink_Encoder USE ENTITY Indel_lib.InfoLink_Encoder;
	-- PRAGMA SYNTHESIS_ON
	----------------------------
	-- COMPONENT Declaration END
	----------------------------
	
	
BEGIN

	---------------------
	-- Core Configuration
	---------------------
	-- Slave Role
	Slave_Role: IF (BSAT_Core_Role = ON_C_I_PKG) GENERATE
	BEGIN
		-- The received data from the master is assigned to the output ports of the entity.
		-- Header Bits...
		BSAT_MS.Header.CMD <= BSAT_RX_Packet.Header.CMD;
		BSAT_MS.Header.AD <= BSAT_RX_Packet.Header.AD;
		BSAT_MS.Header.PARAM <= BSAT_RX_Packet.Header.PARAM;
		BSAT_MS.Header_CRC.CRC_Value <= BSAT_RX_Packet.Header_CRC.CRC_Value;
		BSAT_MS.Header_CRC.CRC_OK <= BSAT_RX_Packet.Header_CRC.CRC_OK;
		BSAT_MS.Header_CRC.CRC_Error <= BSAT_RX_Packet.Header_CRC.CRC_Error;
		-- Data Bits...
		BSAT_MS.Data.Data_Value <= BSAT_RX_Packet.Data.Data_Value;
		BSAT_MS.Data_CRC.CRC_Value <= BSAT_RX_Packet.Data_CRC.CRC_Value;
		BSAT_MS.Data_CRC.CRC_OK <= BSAT_RX_Packet.Data_CRC.CRC_OK;
		BSAT_MS.Data_CRC.CRC_Error <= BSAT_RX_Packet.Data_CRC.CRC_OK;
		
		-- We are assigning the status word in the slave mode...
		--BSAT_TX_Packet.Status.Status_Value <= BSAT_SM.Status.Status_Value;
		
		-------------------
		-- I/O Mode Enabled
		-------------------
		-- The simple IO-mode is used.
		Slave_IO_Mode_EN: IF (BSAT_IO_Mode_EN = ON_C_I_PKG) GENERATE
		BEGIN
			BSAT_TX_Packet.Data.Data_Value <= BSAT_IO_Port_In;
			BSAT_IO_Port_Out <= BSAT_IO_Port_Out_Int;
		END GENERATE Slave_IO_Mode_EN;
		-----------------------
		-- I/O Mode Enabled END
		-----------------------
		
		--------------------
		-- I/O Mode Disabled
		--------------------
		-- The extended user interface is in operation.
		Slave_IO_Mode_DISABLE: IF (BSAT_IO_Mode_EN = OFF_C_I_PKG) GENERATE
		BEGIN
			BSAT_TX_Packet.Data.Data_Value <= BSAT_SM.Data.Data_Value;
			BSAT_IO_Port_Out <= (OTHERS => '0');
		END GENERATE Slave_IO_Mode_DISABLE;
		------------------------
		-- I/O Mode Disabled END
		------------------------
		
		BSAT_Ready <= '0';
		
		-- No open/ short detection
		BSAT_Serial_RX_nEN <= '0';
		
		-- We pre-Enable the TX-Driver, when we are in slave mode...
		-- With the additional register we make sure that the I/O cell does not affet the FSM timing.
		Register_TX_Driver: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				BSAT_Serial_TX_EN <= '0';
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				BSAT_Serial_TX_EN <= (BSAT_Serial_TX_EN_Int OR Pre_BSAT_Serial_TX_EN);
			END IF;
		END PROCESS Register_TX_Driver;
		
		
		--------------------------------------------------
		-- We have a special function to allow fast paging
		--------------------------------------------------
		Generate_Hello: IF (1 = 1) GENERATE
			SIGNAL	BSAT_RX_Seq_EN_Int	: std_logic;
			SIGNAL	BSAT_RX_SR_Int		: std_logic_vector(15 DOWNTO 0);
		BEGIN
			Hello: PROCESS(CLK125, CLR_n_CLK125)
			BEGIN
				IF (CLR_n_CLK125 = '0') THEN
					BSAT_RX_Seq_EN_Int <= '0';
					BSAT_RX_SR_Int <= (OTHERS =>'0');
				ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
					BSAT_RX_Seq_EN_Int <= BSAT_RX_Seq_EN;
					IF (BSAT_RX_Seq_EN_Int = '1') THEN
						BSAT_RX_SR_Int <= BSAT_RX_SR;
					END IF;
				END IF;
			END PROCESS Hello;
		END GENERATE Generate_Hello;
		------------------------------------------------------
		-- We have a special function to allow fast paging END
		------------------------------------------------------
		
		
		--------------------
		-- Debugging Enabled
		--------------------
		Not_Really: PROCESS(CLK125)
		BEGIN
			IF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (BSAT_RX_FSM_Status_Int.Data_Ready = '1') THEN
					IF (BSAT_RX_Word_Data = X"AAAA") THEN
						BSAT_TX_Packet.Status.Status_Value <= x"6666";
					ELSIF (BSAT_TX_Word_Data = X"AAAA") THEN
						BSAT_TX_Packet.Status.Status_Value <= x"3333";
					ELSE
						BSAT_TX_Packet.Status.Status_Value <= BSAT_SM.Status.Status_Value;
					END IF;
				END IF;
			END IF;
		END PROCESS;
		------------------------
		-- Debugging Enabled END
		------------------------
		
	END GENERATE Slave_Role;
	
	
	-- Master Role
	Master_Role: IF (BSAT_Core_Role = OFF_C_I_PKG) GENERATE
	BEGIN
		BSAT_SM.Data_CRC.CRC_Value <= BSAT_RX_Packet.Data_CRC.CRC_Value;
		BSAT_SM.Data_CRC.CRC_OK <= BSAT_RX_Packet.Data_CRC.CRC_OK;
		BSAT_SM.Data_CRC.CRC_Error <= BSAT_RX_Packet.Data_CRC.CRC_Error;
		
		BSAT_Transfer_Setup: PROCESS(CLK125, CLR_n_CLK125)
		BEGIN
			IF (CLR_n_CLK125 = '0') THEN
				TX_Header_ACT <= (OTHERS => '0');
				TX_Data_ACT	<= (OTHERS => '0');
			ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
				IF ((BSAT_Transfer_Start = '1') AND (New_TX_Transfer = '0')) THEN
					TX_Header_ACT <= (BSAT_MS.Header.CMD & BSAT_MS.Header.AD & BSAT_MS.Header.PARAM);
					TX_Data_ACT <= BSAT_MS.Data.Data_Value;
				END IF;
			END IF;
			BSAT_TX_Packet.Data.Data_Value <= TX_Data_ACT;
		END PROCESS BSAT_Transfer_Setup;
		
		-- Concurrent, ready signal
		BSAT_Ready <= (NOT(BSAT_Transfer_Start) AND NOT(New_TX_Transfer));
		
		-- No open/ short detection
		BSAT_Serial_RX_nEN <= '0';
		
		-- As a master there is no pre-enabling of the TX driver, because it is always enabled.
		BSAT_Serial_TX_EN <= BSAT_Serial_TX_EN_Int;
		
		
		-- We have to make sure that the FSM is not too fast for the serial bus operations during scanning (just in half speed mode when the core is used in a master).
		Delay_RST_New_Transfer_SS_Decoding: IF (BSAT_DS_Decoding = 0) GENERATE
			SIGNAL TX_EN_Lock_Counter	: natural RANGE 0 TO 7:= 0;
		BEGIN
			Delay_Feedback: PROCESS(CLK125, CLR_n_CLK125)
			BEGIN
				IF (CLR_n_CLK125 = '0') THEN
					Delay_Lock <= '0';
					TX_EN_Lock_Counter <= 0;
				ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
					IF (TX_EN_Lock_Counter = 7) THEN
						IF (BSAT_Transfer_Start = '1') THEN
							TX_EN_Lock_Counter <= 0;
							Delay_Lock <= '1';
						ELSE
							Delay_Lock <= '0';
						END IF;
					ELSE
						TX_EN_Lock_Counter <= (TX_EN_Lock_Counter + 1);
						Delay_Lock <= '1';
					END IF;
				END IF;
			END PROCESS Delay_Feedback;
		END GENERATE Delay_RST_New_Transfer_SS_Decoding;
		
		-- Normal BSAT speed set...nothing special during scanning.
		No_Delay_RST_New_Transfer_DS_Decoding: IF (BSAT_DS_Decoding = 1) GENERATE
		BEGIN
			Delay_Lock <= '0';
		END GENERATE No_Delay_RST_New_Transfer_DS_Decoding;
		
		--------------------
		-- Debugging Enabled
		--------------------
		Not_Really: PROCESS(CLK125)
		BEGIN
			IF (CLK125'EVENT AND CLK125 = '1') THEN
				IF (BSAT_RX_FSM_Status_Int.Data_Ready = '1') THEN
					IF (BSAT_RX_Word_Data = X"AAAA") THEN
						BSAT_SM.Status.Status_Value <= x"3333";
					ELSIF (BSAT_TX_Word_Data = X"AAAA") THEN
						BSAT_SM.Status.Status_Value <= x"6666";
					ELSE
						BSAT_SM.Status.Status_Value <= BSAT_RX_Packet.Status.Status_Value;
					END IF;
					BSAT_SM.Data.Data_Value <= BSAT_RX_Packet.Data.Data_Value; -- Assign the data when CRC OK.
				END IF;
			END IF;
		END PROCESS;
		------------------------
		-- Debugging Enabled END
		------------------------
		
	END GENERATE Master_Role;
	-------------------------
	-- Core Configuration END
	-------------------------
	
	
	
	

	-- Concurrent 1
	BSAT_TXr <= BSAT_TX_SR(BSAT_TX_SR'HIGH);

	-- We assign the data to ports
	BSAT_RX_FSM_Status <= BSAT_RX_FSM_Status_Int;
	BSAT_TX_FSM_Status <= BSAT_TX_FSM_Status_Int;
	

	-- We are doubling the clock for the decoder/ encoder
	Double_Speed_DEC_ENC: IF (BSAT_DS_Decoding = 1) GENERATE
	BEGIN
		CLK_DEC <= CLK250;
		CLK_ENC <= CLK250;
	END GENERATE Double_Speed_DEC_ENC;
	
	-- We are using the same speed for encoding/ decoding.
	Single_Speed_DEC_ENC: IF (BSAT_DS_Decoding = 0) GENERATE
	BEGIN
		CLK_DEC <= CLK125;
		CLK_ENC <= CLK125;
	END GENERATE Single_Speed_DEC_ENC;

	---------------
	-- BSAT Decoder
	---------------
	-- We are using  delay modulation mark encoding/ decoding for the BSAT bus.
	BSAT_Decoder: InfoLink_Decoder 
	GENERIC MAP	( 
				C_CLK_DIV_22MHZ 			=> BSAT_Oversampling/2,
				C_NO_FIBRE_DESKEW 			=> 1,	-- 0-> invert input and deskew of the pulse
				C_CONTINUOUS_BITCLK 		=> 1,
				C_DS_DECODING				=> BSAT_DS_Decoding
				)
	PORT MAP	(     
				-- std-ports
				i_Clk						=> CLK_DEC,-- clock 
				i_Rst						=> '0',-- Reset
				-- InfoLink-Ports 
				-- LINK
				i_RX						=> BSAT_Serial_RX_Data, -- BSAT input data from RS485 receiver
				-- Codec
				o_RXd						=> BSAT_RXr, -- RX-data output decoded	
				o_RErr						=> OPEN, -- RX-Error  
				o_Paus						=> RX_Pause,-- Pause      
				o_BitClk					=> BSAT_RX_Seq_EN, 
				o_LiErr						=> OPEN, -- Diagnostic link-error
				i_clrLiErr					=> '0',
				o_bc1						=> BC1, -- Sync output 1 for the bit clock
				o_bc2						=> BC2 -- Sync output 2 for the bit clock
				);
	-------------------
	-- BSAT Decoder END
	-------------------
	
	
	---------------
	-- BSAT Encoder
	---------------
	-- We are using delay modulation mark encoding/ decoding for the BSAT bus.
	BSAT_Encoder: InfoLink_Encoder
	GENERIC MAP	( 
				C_CLK_DIV_22MHZ 			=> BSAT_Oversampling/2,
				C_EXTERNAL_BITCLK 			=> BSAT_Core_Role,
				C_DS_ENCODING				=> BSAT_DS_Decoding
				)
	PORT MAP	(     
				-- Std-Ports
				i_Clk						=> CLK_ENC, -- Clock 
				i_Rst						=> '0', -- Reset
				-- InfoLink-Ports 
				-- LINK
				o_TX						=> BSAT_Serial_TX_Data, -- BSAT output data to RS485 transmitter
				-- Encoder                    			
				i_TXd						=> BSAT_TXr, -- TX-data input decoded  
				i_Pause						=> BSAT_TX_Pause, -- H: don't send (TX=H)
				i_TXErr						=> '0', -- H: generate modulations errors
				o_BitClk					=> BSAT_TX_Seq_EN, -- __-_____-_____-			
				i_bc1						=> BC1, -- Sync input 1 for the bit clock
				i_bc2						=> BC2 -- Sync input 2 for the bit clock
				);
	-------------------
	-- BSAT Encoder END
	-------------------


	-- Absolute RX_Counter and RX Pause slope detection.
	BSAT_Global_RX_Counter: PROCESS(CLK125, CLR_n_CLK125)
	BEGIN
		IF (CLK125'EVENT AND CLK125 = '1') THEN
			RX_Pause_Int <= RX_Pause;
			IF ((RX_Pause = '0') AND (RX_Pause_Int = '1')) THEN
				GLB_RX_Counter <= 0;
			ELSIF (BSAT_RX_Seq_EN = '1') THEN
				IF (GLB_RX_Counter < 127) THEN
					GLB_RX_Counter <= (GLB_RX_Counter + 1);
				ELSE
					GLB_RX_Counter <= GLB_RX_Counter;
				END IF;
			END IF;
		END IF;
	END PROCESS BSAT_Global_RX_Counter;
	 
					
	------------------
	-- The BSAT-RX FSM
	------------------
	BSAT_RX_Sequencer: PROCESS(CLK125, CLR_n_CLK125)		
	BEGIN
		IF (CLR_n_CLK125 = '0') THEN
			BSAT_RX_SR <= (OTHERS => '1');
			BSAT_Module_AD_Int <= (OTHERS => '1');
			New_TX_Transfer <= '0';
			BSAT_RX_FSM_Status_Int <= NA_BSAT_RX_FSM_BUNDLE_C_BS_PKG; -- We are clearing the status information.
			BSAT_RX_ACT_Data_Word <= 0;
			BSAT_IO_Port_Out_Int <= (OTHERS => '0');
			Pre_BSAT_Serial_TX_EN <= '0';
			Data_Bit_Counter <= 0;
		ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
			IF (BSAT_Core_Role = OFF_C_I_PKG) THEN -- Master
				IF ((BSAT_Transfer_Start = '1') AND (New_TX_Transfer = '0')) THEN
					New_TX_Transfer <= '1';
				ELSIF ((BSAT_TX_Seq_State = sPause) AND (TX_Count = 0) AND (Delay_Lock = '0')) THEN -- (Delay_Lock: make sure that we are not too fast...)
					New_TX_Transfer <= '0';
				END IF;
			END IF;
			IF (BSAT_Core_Role = ON_C_I_PKG) THEN -- Slave
				IF ((BSAT_TX_Seq_State = sPause) AND (TX_Count = 0)) THEN
					New_TX_Transfer <= '0';
				END IF;
			END IF;
			IF ((RX_Pause = '0') AND (RX_Pause_Int = '1')) THEN
				IF (BSAT_Core_Role = OFF_C_I_PKG) THEN -- Master. We are doing a plausibility check. It can not be the response of a slave.
					IF ((NOT(BSAT_TX_Seq_State = sIdle)) AND (NOT(BSAT_TX_Seq_State = sStart)) AND (NOT(BSAT_TX_Seq_State = sHeader)) AND (NOT(BSAT_TX_Seq_State = sCRC_Header))) THEN
						BSAT_RX_Seq_State <= sStart;
					END IF;
					Pre_BSAT_Serial_TX_EN <= '0';-- We make sure that the not used signal is defined at least (the signal is used in slave mode only).
				END IF;
				IF (BSAT_Core_Role = ON_C_I_PKG) THEN --Slave
					BSAT_RX_Seq_State <= sStart;
					New_TX_Transfer <= '0';
					BSAT_Module_AD_Int <= BSAT_Module_AD;
					Pre_BSAT_Serial_TX_EN <= '0';-- We are disabling the TX pre-driver (the signal is used in slave mode only).
				END IF;
				BSAT_RX_Word_Data <= (OTHERS => '0');
			ELSIF (BSAT_RX_Seq_EN = '1') THEN
				-- The RX shift register
				BSAT_RX_SR <= (BSAT_RX_SR(BSAT_RX_SR'HIGH-1 DOWNTO 0) & BSAT_RXr);
				-- The RX CRC
				BSAT_RX_CRC <= CRC_Gen_F_I_PKG(BSAT_RXr, BSAT_RX_CRC, BSAT_CRC_Polynom_C_BS_PKG);
				CASE BSAT_RX_Seq_State IS
					-- Desc: Let it begin...
					WHEN sStart =>
						BSAT_RX_Seq_State <= sInit;
						BSAT_RX_FSM_Status_Int.RX_Active <= '1';
						BSAT_RX_ACT_Data_Word <= 16#A#;
					-- Desc: Initialize the FSM and CRC8 generator.
					WHEN sInit =>
						IF (BSAT_Core_Role = ON_C_I_PKG) THEN --Slave
							RX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_Length_wo_CRC_C_BS_PKG);
							BSAT_RX_Seq_State <= sHeader;
							BSAT_RX_ACT_Data_Word <= 16#B#;
						ELSE -- Master
							RX_Count <= Return_Upper_F_I_PKG(BSAT_SM_Packet_Status_Length_C_BS_PKG);
							BSAT_RX_Seq_State <= sStatus;
							BSAT_RX_ACT_Data_Word <= 16#D#;
						END IF;
						BSAT_RX_CRC <= (OTHERS => '1');
						BSAT_RX_Packet <= NA_BSAT_PRTCL_FSM_BUNDLE_C_BS_PKG;
					-- Desc: Wait for next packet...
					WHEN sIdle => 
						BSAT_RX_Seq_State <= sIdle;
						BSAT_RX_FSM_Status_Int.Header_CRC_Error <= '0';
						BSAT_RX_FSM_Status_Int.Data_CRC_Error <= '0';
						BSAT_RX_FSM_Status_Int.Header_CRC_OK <= '0';
						BSAT_RX_FSM_Status_Int.BRCT_Received <= '0';
						BSAT_RX_FSM_Status_Int.RX_Active <= '0';
					-- Desc: Receive the header of a packet.
					WHEN sHeader =>
						IF (RX_Count = 0) THEN
							BSAT_RX_Seq_State <= sCRC_Header;
							RX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CRC_Length_C_BS_PKG);
							BSAT_RX_Packet.Header.CMD <= BSAT_RX_SR(14 DOWNTO 11);
							BSAT_RX_Packet.Header.AD <= BSAT_RX_SR(10 DOWNTO 7);
							-- Pre-enable the TX driver in slave role during CRC checking (-> the Slave to master path is not tristated during CRC checking...)
							IF (BSAT_RX_SR(10 DOWNTO 7) = BSAT_Module_AD_Int) THEN
								Pre_BSAT_Serial_TX_EN <= '1';
							ELSE
								Pre_BSAT_Serial_TX_EN <= '0';
							END IF;
							BSAT_RX_Packet.Header.PARAM <= (BSAT_RX_SR(6 DOWNTO 0) & BSAT_RXr);
							BSAT_RX_ACT_Data_Word <= 16#C#;
						ELSE
							RX_Count <= (RX_Count - 1);
						END IF;
					-- Desc: Receive the CRC checksum of the header.
					WHEN sCRC_Header =>
						IF (RX_Count = 0) THEN
							BSAT_RX_Packet.Header_CRC.CRC_Value <= BSAT_RX_CRC;
							BSAT_RX_ACT_Data_Word <= 16#0#;
							IF (CRC_Gen_F_I_PKG(BSAT_RXr, BSAT_RX_CRC, BSAT_CRC_Polynom_C_BS_PKG) = x"00") THEN
								IF (BSAT_RX_Packet.Header.AD = BSAT_Module_AD_Int) THEN
									BSAT_RX_Seq_State <= sData0;
									RX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
									BSAT_RX_CRC <= (OTHERS => '1');
									New_TX_Transfer <= '1';
									BSAT_RX_FSM_Status_Int.Header_Ready <= '1'; -- The header is ready for the actual slave.
									BSAT_RX_FSM_Status_Int.BRCT_Received <= '0'; -- No broadcast, for this slave only.
								ELSIF ((BSAT_RX_Packet.Header.AD = BSAT_BRCT_AD_C_BS_PKG) AND (BSAT_BRCT_AD_EN_C_BS_PKG = ON_C_I_PKG)) THEN
									BSAT_RX_Seq_State <= sData0;
									RX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
									BSAT_RX_CRC <= (OTHERS => '1');
									New_TX_Transfer <= '0'; -- We do not return any data
									BSAT_RX_FSM_Status_Int.Header_Ready <= '1'; -- The header is ready for this slave, too.
									BSAT_RX_FSM_Status_Int.BRCT_Received <= '1'; -- Broadcast message received
									Pre_BSAT_Serial_TX_EN <= '0';-- We use no TX pre-driver during broadcasting (the signal is used in normal slave mode accesses only).
								ELSE
									BSAT_RX_Seq_State <= sIgnore;
									New_TX_Transfer <= '0';
									BSAT_RX_FSM_Status_Int.Header_Ready <= '0'; -- The header is not for the actual slave.
									Pre_BSAT_Serial_TX_EN <= '0';-- We are disabling the TX pre-driver if a slave is not addressed at all (slave mode only).
								END IF;
								BSAT_RX_Packet.Header_CRC.CRC_OK <= '1';
								BSAT_RX_FSM_Status_Int.Header_CRC_OK <= '1'; -- The header was received without CRC error, look at the "Header_Ready" signal if it is for the actual slave.
							ELSE
								BSAT_RX_Seq_State <= sHeader_CRC_Error;
								BSAT_RX_Packet.Header_CRC.CRC_OK <= '0';
								New_TX_Transfer <= '0';
								Pre_BSAT_Serial_TX_EN <= '0';-- We are disabling the TX pre-driver in an error case (slave mode only).
							END IF;
							-- We reset the prefetch information
							Data_Bit_Counter <= 0;
							BSAT_RX_FSM_Status_Int.Data_Bit_Nr <= 0;
							BSAT_RX_FSM_Status_Int.Data_Bit_Value <= '0';
							BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '0';
						ELSE
							RX_Count <= (RX_Count - 1);
						END IF;
					WHEN sStatus =>
						IF (RX_Count = 0) THEN
							BSAT_RX_Seq_State <= sData0;
							RX_Count <= Return_Upper_F_I_PKG(BSAT_SM_Packet_User_Data_Length_C_BS_PKG/4);
							BSAT_RX_Packet.Status.Status_Value <= (BSAT_RX_SR(14 DOWNTO 0) & BSAT_RXr);
							BSAT_RX_ACT_Data_Word <= 16#0#; -- Master mode
							IF (BSAT_RX_Debugging = ON_C_I_PKG) THEN
								BSAT_RX_Word_Data <= (BSAT_RX_SR(14 DOWNTO 0) & BSAT_RXr);
							END IF;
						ELSE
							RX_Count <= (RX_Count - 1);
						END IF;
						-- Desc: Receive the first 16Bit of the user data.
					WHEN sData =>
						IF (RX_Count = 0) THEN
							IF (BSAT_RX_ACT_Data_Word = Return_Upper_F_I_PKG(BSAT_MS_Packet_Data_Word_Count_C_BS_PKG)) THEN
								BSAT_RX_Seq_State <= sCRC_Data;
								RX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG);
								BSAT_RX_ACT_Data_Word <= BSAT_RX_MAX_Data_Words_C_BS_PKG;
								Pre_BSAT_Serial_TX_EN <= '0';-- We are disabling the TX pre-driver (slave mode only).
							ELSE 
								BSAT_RX_Seq_State <= sData;
								RX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
								BSAT_RX_ACT_Data_Word <= (BSAT_RX_ACT_Data_Word + 1);
							END IF;
							BSAT_RX_Packet.Data.Data_Value(Return_Upper_F_I_PKG((BSAT_RX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG) DOWNTO (BSAT_RX_ACT_Data_Word*BSAT_Data_Word_Length_C_BS_PKG)) <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) - 1) DOWNTO 0) & BSAT_RXr);
							IF (BSAT_RX_Debugging = ON_C_I_PKG) THEN
								BSAT_RX_Word_Data <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) -1) DOWNTO 0) & BSAT_RXr);
							END IF;
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe(BSAT_RX_ACT_Data_Word) <= '1';
						ELSE
							RX_Count <= (RX_Count - 1);
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe <= (OTHERS => '0');
						END IF;
						BSAT_RX_FSM_Status_Int.Header_Ready <= '0';
						Data_Bit_Counter <= (Data_Bit_Counter + 1);
						BSAT_RX_FSM_Status_Int.Data_Bit_Nr <= Data_Bit_Counter;
						BSAT_RX_FSM_Status_Int.Data_Bit_Value <= BSAT_RXr;
						BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '1';
					WHEN sData0 =>
						IF (RX_Count = 0) THEN 
							BSAT_RX_Seq_State <= sData1;
							RX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_RX_ACT_Data_Word <= (BSAT_RX_ACT_Data_Word + 1);
							BSAT_RX_Packet.Data.Data_Value(Return_Upper_F_I_PKG((BSAT_RX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG) DOWNTO (BSAT_RX_ACT_Data_Word*BSAT_Data_Word_Length_C_BS_PKG)) <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) - 1) DOWNTO 0) & BSAT_RXr);
							IF (BSAT_RX_Debugging = ON_C_I_PKG) THEN
								BSAT_RX_Word_Data <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) -1) DOWNTO 0) & BSAT_RXr);
							END IF;
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe(BSAT_RX_ACT_Data_Word) <= '1';
							Pre_BSAT_Serial_TX_EN <= '0';-- We are disabling the TX pre-driver (slave mode only).
						ELSE
							RX_Count <= (RX_Count - 1);
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe <= (OTHERS => '0');
						END IF;
						BSAT_RX_FSM_Status_Int.Header_Ready <= '0';
						Data_Bit_Counter <= (Data_Bit_Counter + 1);
						BSAT_RX_FSM_Status_Int.Data_Bit_Nr <= Data_Bit_Counter;
						BSAT_RX_FSM_Status_Int.Data_Bit_Value <= BSAT_RXr;
						BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '1';
					WHEN sData1 =>
						IF (RX_Count = 0) THEN
							BSAT_RX_Seq_State <= sData2;
							RX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_RX_ACT_Data_Word <= (BSAT_RX_ACT_Data_Word + 1);
							BSAT_RX_Packet.Data.Data_Value(Return_Upper_F_I_PKG((BSAT_RX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG) DOWNTO (BSAT_RX_ACT_Data_Word*BSAT_Data_Word_Length_C_BS_PKG)) <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) - 1) DOWNTO 0) & BSAT_RXr);
							IF (BSAT_RX_Debugging = ON_C_I_PKG) THEN
								BSAT_RX_Word_Data <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) -1) DOWNTO 0) & BSAT_RXr);
							END IF;
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe(BSAT_RX_ACT_Data_Word) <= '1';
						ELSE
							RX_Count <= (RX_Count - 1);
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe <= (OTHERS => '0');
						END IF;
						Data_Bit_Counter <= (Data_Bit_Counter + 1);
						BSAT_RX_FSM_Status_Int.Data_Bit_Nr <= Data_Bit_Counter;
						BSAT_RX_FSM_Status_Int.Data_Bit_Value <= BSAT_RXr;
						BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '1';
					WHEN sData2 =>
						IF (RX_Count = 0) THEN
							BSAT_RX_Seq_State <= sData3;
							RX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_RX_ACT_Data_Word <= (BSAT_RX_ACT_Data_Word + 1);
							BSAT_RX_Packet.Data.Data_Value(Return_Upper_F_I_PKG((BSAT_RX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG) DOWNTO (BSAT_RX_ACT_Data_Word*BSAT_Data_Word_Length_C_BS_PKG)) <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) - 1) DOWNTO 0) & BSAT_RXr);
							IF (BSAT_RX_Debugging = ON_C_I_PKG) THEN
								BSAT_RX_Word_Data <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) -1) DOWNTO 0) & BSAT_RXr);
							END IF;
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe(BSAT_RX_ACT_Data_Word) <= '1';
						ELSE
							RX_Count <= (RX_Count - 1);
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe <= (OTHERS => '0');
						END IF;
						Data_Bit_Counter <= (Data_Bit_Counter + 1);
						BSAT_RX_FSM_Status_Int.Data_Bit_Nr <= Data_Bit_Counter;
						BSAT_RX_FSM_Status_Int.Data_Bit_Value <= BSAT_RXr;
						BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '1';
					WHEN sData3 =>
						IF (RX_Count = 0) THEN
							BSAT_RX_Seq_State <= sCRC_Data;
							RX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_CRC_Length_C_BS_PKG);
							BSAT_RX_ACT_Data_Word <= BSAT_RX_MAX_Data_Words_C_BS_PKG;
							BSAT_RX_Packet.Data.Data_Value(Return_Upper_F_I_PKG((BSAT_RX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG) DOWNTO (BSAT_RX_ACT_Data_Word*BSAT_Data_Word_Length_C_BS_PKG)) <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) - 1) DOWNTO 0) & BSAT_RXr);
							IF (BSAT_RX_Debugging = ON_C_I_PKG) THEN
								BSAT_RX_Word_Data <= (BSAT_RX_SR((Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG) -1) DOWNTO 0) & BSAT_RXr);
							END IF;
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe(BSAT_RX_ACT_Data_Word) <= '1';
						ELSE
							RX_Count <= (RX_Count - 1);
							BSAT_RX_FSM_Status_Int.Data_WR_Strobe <= (OTHERS => '0');
						END IF;
						Data_Bit_Counter <= (Data_Bit_Counter + 1);
						BSAT_RX_FSM_Status_Int.Data_Bit_Nr <= Data_Bit_Counter;
						BSAT_RX_FSM_Status_Int.Data_Bit_Value <= BSAT_RXr;
						BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '1';
					WHEN sCRC_Data =>
						IF (RX_Count = 0) THEN
							IF (CRC_Gen_F_I_PKG(BSAT_RXr, BSAT_RX_CRC, BSAT_CRC_Polynom_C_BS_PKG) = x"00") THEN
								BSAT_RX_Packet.Data_CRC.CRC_OK <= '1';
								BSAT_RX_Packet.Data_CRC.CRC_Value <= BSAT_RX_CRC;
								BSAT_RX_Seq_State <= sRX_Terminate;
								BSAT_RX_FSM_Status_Int.Data_Ready <= '1';
								IF (BSAT_IO_Mode_EN = ON_C_I_PKG) THEN
									BSAT_IO_Port_Out_Int <= BSAT_RX_Packet.Data.Data_Value;
								END IF;
							ELSE
								BSAT_RX_Seq_State <= sData_CRC_Error;
								BSAT_RX_Packet.Data_CRC.CRC_OK <= '0';
								BSAT_RX_Packet.Data_CRC.CRC_Error <= '1';
								BSAT_RX_FSM_Status_Int.Data_Ready <= '0';
							END IF;
						ELSE
							RX_Count <= (RX_Count - 1);
							BSAT_RX_FSM_Status_Int.Data_Ready <= '0';
						END IF;
						BSAT_RX_FSM_Status_Int.Data_WR_Strobe <= (OTHERS => '0');
					WHEN sRX_Terminate =>
						BSAT_RX_Seq_State <= sIdle;
						BSAT_RX_FSM_Status_Int.RX_Active <= '0';
						BSAT_RX_FSM_Status_Int.Data_Ready <= '0';
						BSAT_RX_FSM_Status_Int.Header_CRC_OK <= '0';
						BSAT_RX_FSM_Status_Int.BRCT_Received <= '0';
					WHEN sIgnore =>
						BSAT_RX_Seq_State <= sIdle;
					WHEN sHeader_CRC_Error =>
						BSAT_RX_FSM_Status_Int.Header_CRC_Error <= '1';
						BSAT_RX_Seq_State <= sIdle;
					WHEN sData_CRC_Error =>
						BSAT_RX_FSM_Status_Int.Data_CRC_Error <= '1';
						BSAT_RX_Seq_State <= sIdle;
					WHEN OTHERS =>
						NULL;
				END CASE;
			ELSE
				-- Nothing else to do?
				BSAT_RX_FSM_Status_Int.Data_Bit_Valid <= '0';
			END IF;
		END IF;
	END PROCESS BSAT_RX_Sequencer;
	----------------------
	-- The BSAT-RX FSM END
	----------------------
	
	
	------------------
	-- The BSAT-TX FSM
	------------------
	-- We are clocking the TX sequencer with the TX-Bit clock because it is related to the RX-Bit clock via the BC1 an BC2 signals.
	BSAT_TX_Sequencer: PROCESS(CLK125, CLR_n_CLK125)		
	BEGIN
		IF (CLR_n_CLK125 = '0') THEN
			BSAT_TX_Pause <= '1';
			TX_Count <= 0;
			BSAT_TX_ACT_Data_Word <= 0;
			BSAT_TX_SR <= (OTHERS => '0');
			BSAT_TX_Word_Data <= (OTHERS => '0');
			BSAT_TX_Seq_State <= sIdle;
			BSAT_TX_CRC <= (OTHERS => '1');
			BSAT_Serial_TX_EN_Int <= '0';
			BSAT_TX_FSM_Status_Int <= NA_BSAT_TX_FSM_BUNDLE_C_BS_PKG;
		ELSIF (CLK125'EVENT AND CLK125 = '1') THEN
			-- We have to enable the output driver
			IF (BSAT_Core_Role = ON_C_I_PKG) THEN -- Slave role...
				IF (New_TX_Transfer = '1') THEN
					BSAT_Serial_TX_EN_Int <= '1'; -- Enable the output driver.
				END IF;
			ELSE
				BSAT_Serial_TX_EN_Int <= '1'; -- Really always enabled in master role?
			END IF;
			IF (BSAT_TX_Seq_EN = '1') THEN
				TX_Count <= (TX_Count - 1);
				BSAT_TX_Pause <= '0';
				BSAT_TX_SR(BSAT_TX_SR'HIGH DOWNTO 0) <= (BSAT_TX_SR(BSAT_TX_SR'HIGH-1 DOWNTO 0) & '0');
				BSAT_TX_CRC <= CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG);
				CASE BSAT_TX_Seq_State IS
					WHEN sInit =>
						BSAT_TX_Seq_State <= sIdle;
					WHEN sScan =>
						BSAT_TX_Seq_State <= sIdle;
					WHEN sIdle =>
						IF (New_TX_Transfer = '1') THEN
							BSAT_TX_Seq_State <= sStart;
							BSAT_TX_Pause <= '0';
							BSAT_TX_FSM_Status_Int.TX_Active <= '1';
							BSAT_TX_FSM_Status_Int.Status_RD_Strobe <= '1';
						ELSE
							BSAT_TX_Pause <= '1';
							BSAT_TX_FSM_Status_Int.TX_Active <= '0';
							BSAT_TX_FSM_Status_Int.Status_RD_Strobe <= '0';
						END IF;
						TX_Count <= 0;
						BSAT_TX_CRC <= (OTHERS => '1');
					WHEN sStart =>
						IF (BSAT_Core_Role = ON_C_I_PKG) THEN -- Slave role...
							BSAT_TX_Seq_State <= sStatus;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_SM_Packet_Status_Length_C_BS_PKG);
							BSAT_TX_SR<= BSAT_TX_Packet.Status.Status_Value;
							IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
								BSAT_TX_Word_Data <= BSAT_TX_Packet.Status.Status_Value;
							END IF;
						ELSE -- Master
							BSAT_TX_Seq_State <= sHeader;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_Length_wo_CRC_C_BS_PKG);
							BSAT_TX_SR<= TX_Header_ACT;
							IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
								BSAT_TX_Word_Data <= TX_Header_ACT;
							END IF;
						END  IF;
						BSAT_TX_CRC <= (OTHERS => '1');
						BSAT_TX_FSM_Status_Int.Status_RD_Strobe <= '0';
						BSAT_TX_ACT_Data_Word <= 0;
					WHEN sHeader =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sCRC_Header;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_Header_CRC_Length_C_BS_PKG);
							BSAT_TX_SR <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00");
							IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
								BSAT_TX_Word_Data <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00");
							END IF;
							BSAT_TX_ACT_Data_Word <= 16#0#;
						ELSE
							TX_Count <= (TX_Count - 1);
						END IF;
					WHEN sCRC_Header =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sData0;
							BSAT_TX_SR <= BSAT_TX_Packet.Data.Data_Value(15 DOWNTO 0);
							IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
								BSAT_TX_Word_Data <= BSAT_TX_Packet.Data.Data_Value(15 DOWNTO 0);
							END IF;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_Length_C_BS_PKG/4);
							BSAT_TX_CRC <= (OTHERS => '1');
							BSAT_TX_ACT_Data_Word <= (BSAT_TX_ACT_Data_Word + 1);
						ELSE
							BSAT_TX_CRC <= BSAT_TX_CRC;
							TX_Count <= (TX_Count - 1);
						END IF;
					WHEN sStatus =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sData0;
							BSAT_TX_SR <= BSAT_TX_Packet.Data.Data_Value(15 DOWNTO 0);
							IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
								BSAT_TX_Word_Data <= BSAT_TX_Packet.Data.Data_Value(15 DOWNTO 0);
							END IF;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
							BSAT_TX_ACT_Data_Word <= (BSAT_TX_ACT_Data_Word + 1);
						ELSIF (TX_Count = 1) THEN
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe(0) <= '1';
						ELSE
							TX_Count <= (TX_Count - 1);
						END IF;
					-- We could use this sData state instead of the sData0 to sData3 states. However it is painful during debugging...
--					WHEN sDATA =>
--						IF (TX_Count = 0) THEN
--							IF (BSAT_TX_ACT_Data_Word = Return_Upper_F_I_PKG(BSAT_MS_Packet_Data_Word_Count_C_BS_PKG)) THEN
--								BSAT_TX_Seq_State <= sCRC_Data;
--								IF (BSAT_Core_Role = 1) THEN -- Slave
--									BSAT_TX_SR <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"FF"); -- Case diff. really
--									IF (BSAT_TX_Debugging = 1) THEN
--										BSAT_TX_Word_Data <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"FF");
--									END IF;
--								ELSE -- Master
--									BSAT_TX_SR <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00"); -- needed?
--									IF (BSAT_TX_Debugging = 1) THEN
--										BSAT_TX_Word_Data <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00");
--									END IF;
--								END IF;
--								TX_Count <= Return_Upper_F_I_PKG(BSAT_TX_Packet_Data_CRC_Length);
--								BSAT_TX_ACT_Data_Word <= BSAT_RX_MAX_Data_Words_C_BS_PKG;
--							ELSE 
--								BSAT_TX_Seq_State <= sData;
--								TX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
--								BSAT_TX_ACT_Data_Word <= (BSAT_TX_ACT_Data_Word + 1);
--								BSAT_TX_SR <= BSAT_TX_Packet.Data.Data_Value((Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_Length_C_BS_PKG) - BSAT_TX_ACT_Data_Word*(BSAT_Data_Word_Length_C_BS_PKG)) DOWNTO (BSAT_MS_Packet_User_Data_Length_C_BS_PKG - (BSAT_TX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG));
--								IF (BSAT_TX_Debugging = 1) THEN
--									BSAT_TX_Word_Data <= BSAT_TX_Packet.Data.Data_Value((Return_Upper_F_I_PKG(BSAT_MS_Packet_User_Data_Length_C_BS_PKG) - BSAT_TX_ACT_Data_Word*(BSAT_Data_Word_Length_C_BS_PKG)) DOWNTO (BSAT_MS_Packet_User_Data_Length_C_BS_PKG - (BSAT_TX_ACT_Data_Word + 1)*BSAT_Data_Word_Length_C_BS_PKG));
--								END IF;
--							END IF;
--						ELSIF (TX_Count = 1) THEN
--							BSAT_TX_FSM_Status_Int.Data_RD_Strobe(BSAT_TX_ACT_Data_Word) <= '1';
--						ELSE
--							TX_Count <= (TX_Count - 1);
--							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
--						END IF;
					WHEN sData0 =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sData1;
							BSAT_TX_SR <= BSAT_TX_Packet.Data.Data_Value(31 DOWNTO 16);
							IF (BSAT_TX_Debugging = 1) THEN
								BSAT_TX_Word_Data <= BSAT_TX_Packet.Data.Data_Value(31 DOWNTO 16);
							END IF;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						ELSIF (TX_Count = 1) THEN
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe(1) <= '1';
							BSAT_TX_ACT_Data_Word <= (BSAT_TX_ACT_Data_Word + 1);
						ELSE
							TX_Count <= (TX_Count - 1);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						END IF;
					WHEN sData1 =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sData2;
							BSAT_TX_SR <= BSAT_TX_Packet.Data.Data_Value(47 DOWNTO 32);
							IF (BSAT_TX_Debugging = 1) THEN
								BSAT_TX_Word_Data <= BSAT_TX_Packet.Data.Data_Value(47 DOWNTO 32);
							END IF;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						ELSIF (TX_Count = 1) THEN
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe(2) <= '1';
							BSAT_TX_ACT_Data_Word <= (BSAT_TX_ACT_Data_Word + 1);
						ELSE
							TX_Count <= (TX_Count - 1);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						END IF;
					WHEN sData2 =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sData3;
							BSAT_TX_SR <= BSAT_TX_Packet.Data.Data_Value(63 DOWNTO 48);
							IF (BSAT_TX_Debugging = 1) THEN
								BSAT_TX_Word_Data <= BSAT_TX_Packet.Data.Data_Value(63 DOWNTO 48);
							END IF;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_Data_Word_Length_C_BS_PKG);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						ELSIF (TX_Count = 1) THEN
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe(3) <= '1';
							BSAT_TX_ACT_Data_Word <= (BSAT_TX_ACT_Data_Word + 1);
						ELSE
							TX_Count <= (TX_Count - 1);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						END IF;
					WHEN sData3 =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sCRC_Data;
							TX_Count <= Return_Upper_F_I_PKG(BSAT_TX_Packet_Data_CRC_Length);
							IF (BSAT_Core_Role = ON_C_I_PKG) THEN -- Slave
								BSAT_TX_SR <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00"); -- Case diff. really
								IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
									BSAT_TX_Word_Data <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"FF");
								END IF;
							ELSE -- Master
								BSAT_TX_SR <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00"); -- needed?
								IF (BSAT_TX_Debugging = ON_C_I_PKG) THEN
									BSAT_TX_Word_Data <= (CRC_Gen_F_I_PKG(BSAT_TXr,BSAT_TX_CRC,BSAT_CRC_Polynom_C_BS_PKG) & x"00");
								END IF;
							END IF;
						ELSE
							TX_Count <= (TX_Count - 1);
							BSAT_TX_FSM_Status_Int.Data_RD_Strobe <= (OTHERS => '0');
						END IF;
					WHEN sCRC_Data =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <= sEnd;
							BSAT_TX_CRC <= (OTHERS => '1');
						ELSE
							BSAT_TX_CRC <= BSAT_TX_CRC;
							TX_Count <= (TX_Count - 1);
						END IF;
					WHEN sEnd =>
						BSAT_TX_Seq_State <= sPause;
						BSAT_TX_CRC <= (OTHERS => '1');
						TX_Count <= BSAT_TX_Count_MIN_Pause_Length_C_BS_PKG; -- How long is the min. pause length?
					WHEN sPause =>
						IF (TX_Count = 0) THEN
							BSAT_TX_Seq_State <=	sIdle;
							IF (BSAT_Core_Role = ON_C_I_PKG) THEN -- Slave
								BSAT_Serial_TX_EN_Int <= '0';
							ELSE -- Master
								BSAT_Serial_TX_EN_Int <= '1';-- Really let it switched on?
							END IF;
						ELSE
							TX_Count <= (TX_Count - 1);
						END IF;
						BSAT_TX_Pause <= '1';
					WHEN OTHERS =>
						NULL;
				END CASE;
			ELSE
				-- Nothing else to do?
			END IF;
		END IF;
	END PROCESS BSAT_TX_Sequencer;
	----------------------
	-- The BSAT-TX FSM END
	----------------------
	

END Universal;
