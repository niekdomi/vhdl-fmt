-- Module MAX10 Remote Update Block													--
-- Enhanced VHDL version of an Intel Verilog IP										--
--																					--
--																					--
-- InfoLink, GinLink			Copyright (c): INDEL AG								--
-- BSAT							Copyright (c): Besi Switzerland AG					--
--																					--
-- Project:		BSAT																--
--																					--
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland								--
--																					--
-- --------------------------------------------------------------------------		--
-- FSM for the RU hardware block in MAX10 devices.									--
-- We modified the default Intel/Altera code based on the fact that booting			--
-- is always done to image 0 even if image 1 is selected ext. with the pin.			--
-- Additionally take care: The Intel FSM consisted of 2 comb processes...			--
--	... and instantiates latches: Was it really an aim of Intel?...the most			--
--	horrible FSM I have ever seen.													--
-- --------------------------------------------------------------------------		--
--	With this RU-Block it is possible to reboot a MAX10 to the AUX system			--
--	without removing power and even if the STD system is working via Touchpad		--
--	--------------------------------------------------------------------------		--
--	History:																		--
-- QFU, 23.01.2019:	First test draft for Paedi.										--
--	QFU, 23.01.2019:	First release after initial tests on real board.			--
--							Debug output removed.									--
--																					--
-- Remarks:																			--
--																					--
-- MSM_CS values:		"0010":	Image 0 is being loaded								--
--							"0011":	Image 1 is being loaded after revert of images	--
--							"0100":	Image 1 is being loaded							--
--							"0101":	Image 0 is being loaded after revert of images	--
--																					--
--	Config_Current:	MSM_CS value													--
--	Config1:				nConfig & CRCError & nStatus & WDTimer & MSM_CS value	--
--	Config2:				nConfig & CRCError & nStatus & WDTimer & MSM_CS value	--
--																					--
-- Time relation of the different Configs:											--
--		Config2 => Reboot => Config1 => Reboot => Config_Current					--
--	--------------------------------------------------------------------------		--
--------------------------------------------------------------------------------
--$Rev:: 5304                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2019-05-13 16:32:50 +0200 (Mo., 13 Mai 2019)                         $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;



ENTITY MAX10_Remote_Update IS
	GENERIC	(
			Auxiliary_System	:	natural RANGE 0 TO 1 := 0; -- Is the actual firmware an AUX system?- Yes: => Stay in CFM0.
			Ignore_Config_SEL	:	natural RANGE 0 TO 1 := 0 -- Design has no Touchpad make sure it starts in AUX when STD corrupted.
			);
	PORT	(
			CLK					: IN	std_logic;
			nRuRST				: IN	std_logic;
			ReloadApplication	: IN	std_logic;
			Boot_Errors			: OUT	std_logic_vector(7 DOWNTO 0);
			ApplicationError	: OUT	std_logic
			);
END ENTITY MAX10_Remote_Update;



ARCHITECTURE Universal OF MAX10_Remote_Update IS
	

	-------------------
	-- Type Declaration
	-------------------
	-- The FSM state definitions for the RU block...
	TYPE 	ru_fsm_state IS
			(
			sRESET,
			sRD_APP_1_PREP,
			sRD_AP_1_WR_1,   
			sRD_AP_1_WR_2,   
			sRD_AP_1_CAPTURE,
			sRD_AP_1_READ,   
			sRD_AP_1_STR,    
			sRD_AP_2_PREP,   
			sRD_AP_2_WR_1,   
			sRD_AP_2_WR_2,   
			sRD_AP_2_CAPTURE,
			sRD_AP_2_READ,   
			sRD_AP_2_STR,    
			sRD_AP_3_PREP,  
			sRD_AP_3_WR_1,   
			sRD_AP_3_WR_2,   
			sRD_AP_3_CAPTURE,
			sRD_AP_3_READ,
			sRD_AP_3_STR,
			sCHK_CONFIG,
			sWR_1_PREP,
			sWR_1_WRITE,
			sWR_1_UPDATE,
			sWR_2_PREP,
			sWR_2_WRITE,
			sWR_2_UPDATE,
			sDELAY,      
			sRECONFIG,
			sIDLE
			);
	-----------------------
	-- Type Declaration END
	-----------------------


	---------------------
	-- Signal Declaration
	---------------------
	SIGNAL RU_Master_SEQ_State		:	ru_fsm_state;					-- FSM state signal
	-- Internal Signals
	SIGNAL	RuDout					:	std_logic;						-- Serial output data signal from RU_Block.
	SIGNAL	RuDinVal				:	std_logic_vector(13 DOWNTO 0);	-- Value to store on a load
	SIGNAL	RuDinLd					:	std_logic;						-- Load a new value
	SIGNAL	RuDinSft				:	std_logic;						-- Shift the value one bit
	SIGNAL	RuDoutStr				:	std_logic;						-- Store data from module
	SIGNAL	BitCntVal				:	natural RANGE 0 TO 63;			-- Value to store on a load
 	SIGNAL 	BitCntLd				:	std_logic;						-- Load a new value
 	SIGNAL 	BitCntDec				:	std_logic;						-- Decrement bit counter
 	SIGNAL 	Config1Str				:	std_logic;						-- Store the configuration bits
 	SIGNAL	Config2Str				:	std_logic;						-- Store the configuration bits
 	SIGNAL	Config3Str				:	std_logic;						-- Store the configuration bits
 	SIGNAL	RuShiftNLd				:	std_logic;						-- ShiftNLd input to module
 	SIGNAL	RuCaptNUpdt				:	std_logic;						-- CaptNUpdt input to module
 	SIGNAL	RuConfig				:	std_logic;						-- Config input to module
 	SIGNAL	DelayLd					:	std_logic;						-- Load delay register with 10s delay
 	SIGNAL	WatchdogKick			:	std_logic_vector(4 DOWNTO 0);	-- Register to kick the watchdog timer
 	SIGNAL	WD_Counter 				:	natural RANGE 0 TO 31;			--
 	SIGNAL	RuDin 					:	std_logic_vector(13 DOWNTO 0);	-- Shift register for data input to module, RuDin(0) is shifted in...
 	SIGNAL	RuDoutReg 				:	std_logic_vector(33 DOWNTO 0);	-- Shift register for data output from module
 	SIGNAL	Config1 				:	std_logic_vector(7 DOWNTO 0);	-- Configuration from the ambiguous Application 1
 	SIGNAL	Config2 				:	std_logic_vector(7 DOWNTO 0);	-- Configuration from the ambiguous Application 2
 	SIGNAL	ConfigCurrent 			:	std_logic_vector(3 DOWNTO 0);	-- Configuration from the current state
 	SIGNAL	BitCnt 					:	natural RANGE 0 TO 63;			-- Bit counter for handling shift operations
 	SIGNAL	DelayCnt 				:	natural RANGE 0 TO 31;			-- Delay counter
 	SIGNAL	ApplicationError_Int	:	std_logic;						
	-------------------------
	-- Signal Declaration END
	-------------------------
	
	
	------------------------
	-- COMPONENT Declaration
	------------------------
	COMPONENT fiftyfivenm_rublock IS
		PORT	(
				clk			: IN	std_logic := '0';
				shiftnld	: IN	std_logic := '0';
				captnupdt	: IN	std_logic := '0';
				regin		: IN	std_logic := '0';
				rsttimer	: IN	std_logic := '0';
				rconfig		: IN	std_logic := '0';
				regout		: OUT	std_logic
				);
	END COMPONENT;
	----------------------------
	-- COMPONENT Declaration END
	----------------------------
	

BEGIN
	
	-- Concurrent 0
	ApplicationError <= ApplicationError_Int;
	
	-- Concurrent 1
	Boot_Errors <= (Config1(7 DOWNTO 4) & ConfigCurrent);


	Count_Delay: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF ((nRuRST = '0') OR (DelayLd = '1'))THEN
				DelayCnt <= 10; -- Tclk = 32ns => delay = 320ns.
			ELSIF (DelayCnt /= 0) THEN
				DelayCnt <= (DelayCnt - 1);
			ELSE
				DelayCnt <= DelayCnt;
			END IF;
		END IF;
	END PROCESS Count_Delay;


	-- Shift register for write data
	Shift_Register_WR: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				RuDin <= (OTHERS => '0');
			ELSIF (RuDinLd = '1') THEN
				RuDin <= RuDinVal;
			ELSIF (RuDinSft = '1') THEN
				RuDin <= ('0' & RuDin(13 DOWNTO 1)); -- RuDin(0) is shifted into the RU_Block.
			ELSE
				RuDin <= RuDin;
			END IF;
		END IF;
	END PROCESS Shift_Register_WR;


	-- Shift register for read data
	Shift_Register_RD: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				RuDoutReg <= (OTHERS => '0');
			ELSIF (RuDoutStr = '1') THEN
				RuDoutReg <= (RuDout & RuDoutReg(33 DOWNTO 1)); -- RuDout becomes RuDoutReg(33)...
			ELSE
				RuDoutReg <= RuDoutReg;
			END IF;
		END IF;
	END PROCESS Shift_Register_RD;


	-- Register to store register data (Config1)
	Store_Config1: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				Config1 <= (OTHERS => '0');
			ELSIF (Config1Str = '1') THEN
				Config1 <= (RuDoutReg(31 DOWNTO 28) & RuDoutReg(25 DOWNTO 22)); -- (nConfig & CRCError & nStatus & WDTimer & MSM_CS)
			ELSE
				Config1 <= Config1;
			END IF;
		END IF;
	END PROCESS Store_Config1;


	-- Register to store register data (Config2)
	Store_Config2: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				Config2 <= (OTHERS => '0');
			ELSIF (Config2Str = '1') THEN
				Config2 <= (RuDoutReg(31 DOWNTO 28) & RuDoutReg(25 DOWNTO 22)); -- (nConfig & CRCError & nStatus & WDTimer & MSM_CS)
			ELSE
				Config2 <= Config2;
			END IF;
		END IF;
	END PROCESS Store_Config2;


	-- Register to store register data (current status)
	Store_Current: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				ConfigCurrent <= (OTHERS => '0');
			ELSIF (Config3Str = '1') THEN
				ConfigCurrent <= RuDoutReg(33 DOWNTO 30); -- Actual MSM_CS only...
			ELSE
				ConfigCurrent <= ConfigCurrent;
			END IF;
		END IF;
	END PROCESS Store_Current;


	-- Bit counter for tracking writes and reads
	Count_Bits: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				BitCnt <= 0;
			ELSIF (BitCntLd = '1') THEN
				BitCnt <= BitCntVal;
			ELSIF ((BitCntDec = '1') AND (BitCnt /= 0)) THEN
				BitCnt <= (BitCnt - 1);
			ELSE
				BitCnt <= BitCnt;
			END IF;
		END IF;
	END PROCESS Count_Bits;


	-- FSM
	RU_FSM:	PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			-- Default values...not the nicest way to do it.
			RuDinVal    <= (OTHERS =>'0');
    		RuDinLd     <= '0';
    		RuDinSft    <= '0';
    		RuDoutStr   <= '0';
    		BitCntVal   <= 0;
    		BitCntLd    <= '0';
    		BitCntDec   <= '0';
    		Config1Str  <= '0';
    		Config2Str  <= '0';
    		Config3Str  <= '0';
    		RuShiftNLd  <= '0'; --**--
    		RuCaptNUpdt <= '1'; --**--
    		RuConfig    <= '0';
    		DelayLd     <= '0';
			IF (nRuRST = '0') THEN
				RU_Master_SEQ_State <= sRESET;
			ELSE
				CASE RU_Master_SEQ_State IS
					WHEN sRESET	=>
						--Stay here until delay counter is running out.
						IF (DelayCnt = 0) THEN
							RU_Master_SEQ_State <= sRD_APP_1_PREP;
							RuDinVal	<= "00000000000001"; -- Need to shift in two bits as "01"
          				RuDinLd <= '1'; -- Store the value
						ELSE
							RU_Master_SEQ_State <= sRESET;
						END IF;
					------------------------------
					-- Read Application 1 register
					WHEN sRD_APP_1_PREP =>
						-- Store serial input bits and move on
						RU_Master_SEQ_State <= sRD_AP_1_WR_1;
						RuDinSft	<= '1'; -- Shift bits in
						RuShiftNLd <= '1'; -- Shift bits in
					WHEN sRD_AP_1_WR_1 =>
						-- Write in one bit for setting capture address and move on
						RU_Master_SEQ_State <= sRD_AP_1_WR_2;
						RuDinSft	<= '1'; -- Shift bits in
						RuShiftNLd <= '1'; -- Shift bits in
					WHEN sRD_AP_1_WR_2 =>
						-- Write in one bit for setting capture address and move on
						RU_Master_SEQ_State <= sRD_AP_1_CAPTURE;
						BitCntVal <= 34; -- We will read out 34 bits
						BitCntLd	<= '1'; -- Store the value
					WHEN sRD_AP_1_CAPTURE =>
						RU_Master_SEQ_State <= sRD_AP_1_READ;
						BitCntDec <= '1'; -- Count this bit as done
						RuDoutStr <= '1'; -- Store the incoming bit
						RuShiftNLd <= '1'; -- Shift bits out
					WHEN sRD_AP_1_READ =>
						IF (BitCnt <= 1) THEN
							RU_Master_SEQ_State <= sRD_AP_1_STR;
							Config1Str <= '1'; -- Store relevant bits
						ELSE
							RU_Master_SEQ_State <= sRD_AP_1_READ;
							BitCntDec <= '1'; -- Count this bit as done
							RuDoutStr <= '1'; -- Store the incoming bit
							RuShiftNLd <= '1'; -- Shift bits out
						END IF;
					WHEN sRD_AP_1_STR =>
						-- Store value and move on
						RU_Master_SEQ_State <= sRD_AP_2_PREP;
						RuDinVal	<= "00000000000010"; -- Need to shift in two bits as "10".
						RuDinLd <= '1'; -- Store the value
					------------------------------
					-- Read Application 2 register
					WHEN sRD_AP_2_PREP =>
						-- Store serial input bits and move on
						RU_Master_SEQ_State <= sRD_AP_2_WR_1;
						RuDinSft	<= '1'; -- Shift bits in
						RuShiftNLd	<= '1'; -- Shift bits in
					WHEN sRD_AP_2_WR_1 =>
						-- Write in one bit for setting capture address and move on
						RU_Master_SEQ_State <= sRD_AP_2_WR_2;
						RuDinSft	<= '1'; -- Shift bits in
						RuShiftNLd	<= '1'; -- Shift bits in
					WHEN sRD_AP_2_WR_2 =>
						-- Write in one bit for setting capture address and move on
						RU_Master_SEQ_State <= sRD_AP_2_CAPTURE;
						BitCntVal <= 34; -- We will read out 34 bits
						BitCntLd	<= '1'; -- Store the value
					WHEN sRD_AP_2_CAPTURE =>
						-- Capture the value we want to read and move on
						RU_Master_SEQ_State <= sRD_AP_2_READ;
						BitCntDec <= '1'; -- Count this bit as done
						RuDoutStr <= '1'; -- Store the incoming bit
						RuShiftNLd <= '1'; -- Shift bits out
					WHEN sRD_AP_2_READ =>
						-- Final Bit, move on
						IF (BitCnt <= 1) THEN
							RU_Master_SEQ_State <= sRD_AP_2_STR;
							Config2Str <= '1'; -- Store relevant bits
						ELSE
							RU_Master_SEQ_State <= sRD_AP_2_READ;
							BitCntDec <= '1'; -- Count this bit as done
							RuDoutStr <= '1'; -- Store the incoming bit
							RuShiftNLd <= '1'; -- Shift bits out
						END IF;
					WHEN sRD_AP_2_STR =>
						-- Store value and move on
						RU_Master_SEQ_State <= sRD_AP_3_PREP;
						RuDinVal	<= (OTHERS => '0'); -- Need to shift in two bits as "00".
						RuDinLd <= '1'; -- Store the value
					-------------------------------
					-- Read current status register
					WHEN sRD_AP_3_PREP =>
						-- Store serial input bits and move on
						RU_Master_SEQ_State <= sRD_AP_3_WR_1;
						RuDinSft <= '1'; -- Shift bits in
						RuShiftNLd <= '1'; -- Shift bits in
					WHEN sRD_AP_3_WR_1 =>
						-- Write in one bit for setting capture address and move on
						RU_Master_SEQ_State <= sRD_AP_3_WR_2;
						RuDinSft	<= '1'; -- Shift bits in
						RuShiftNLd <= '1'; -- Shift bits in
					WHEN sRD_AP_3_WR_2 =>
						-- Write in one bit for setting capture address and move on
						RU_Master_SEQ_State <= sRD_AP_3_CAPTURE;
						BitCntVal <= 34; -- We will read out 34 bits
						BitCntLd	<= '1'; -- Store the value
					WHEN sRD_AP_3_CAPTURE =>
						-- Capture the value we want to read and move on
						RU_Master_SEQ_State <= sRD_AP_3_READ;
						BitCntDec <= '1'; -- Count this bit as done
						RuDoutStr <= '1'; -- Store the incoming bit
						RuShiftNLd <= '1'; -- Shift bits out
					WHEN sRD_AP_3_READ =>
						-- Final Bit, move on
						IF (BitCnt <= 1) THEN
							RU_Master_SEQ_State <= sRD_AP_3_STR;
							Config3Str <= '1'; -- Store relevant bits
						ELSE
							RU_Master_SEQ_State <= sRD_AP_3_READ;
							BitCntDec <= '1'; -- Count this bit as done
							RuDoutStr <= '1'; -- Store the incoming bit
							RuShiftNLd <= '1'; -- Shift bits out
						END IF;
					WHEN sRD_AP_3_STR =>
						-- Store value and move on
						RU_Master_SEQ_State <= sCHK_CONFIG;
					--------------------------------------------
					-- Check configuration and decide what to do
					WHEN sCHK_CONFIG =>
						IF (Auxiliary_System = 0) THEN
							-- A normal load to image 0 was done, go for image 1
							IF (ConfigCurrent = x"2") THEN
								RU_Master_SEQ_State <= sWR_1_PREP;
								RuDinVal	<= "01000000000000"; -- Set to enable bit overwrites
								RuDinLd <= '1'; -- Store the value
								BitCntVal <= 41; -- We will write all 41 bits
								BitCntLd <= '1'; -- Store the value
							-- Some other reason, don't automatically do anything
							ELSE
								RU_Master_SEQ_State <= sIDLE;
							END IF;
						ELSE
							RU_Master_SEQ_State <= sIDLE;
						END IF;
					-------------------------------------------------------------
					-- Write reconfig register to allow overwrites and then do it
					WHEN sWR_1_PREP =>
						-- Get data ready and move on
						RU_Master_SEQ_State <= sWR_1_WRITE;
						BitCntDec <= '1'; -- Count this bit as done
						RuDinSft <= '1'; -- Shift bits in
						RuShiftNLd <= '1'; -- Shift bits out
						RuCaptNUpdt <= '0'; -- Update config from input
					WHEN sWR_1_WRITE =>
						-- Final Bit, move on
						IF (BitCnt <= 1) THEN
							RU_Master_SEQ_State <= sWR_1_UPDATE;
							RuCaptNUpdt <= '0'; -- Update config from input
							DelayLd <= '1'; -- Load delay register
						ELSE
							RU_Master_SEQ_State <= sWR_1_WRITE;
							BitCntDec <= '1'; -- Count this bit as done
							RuDinSft	<= '1'; -- Shift bits in
							RuShiftNLd <= '1'; -- Shift bits out
							RuCaptNUpdt <= '0'; -- Update config from input
						END IF;
					WHEN sWR_1_UPDATE =>
						-- Latch data into config register and move on
						RU_Master_SEQ_State <= sWR_2_PREP;
						RuDinVal	<= "11000000000000"; -- Set to enable bit overwrites and to do image 1
						RuDinLd <= '1'; -- Store the value
						BitCntVal <= 41; -- We will write in all 41 bits
						BitCntLd	<= '1'; -- Store the value
					WHEN sWR_2_PREP =>
						-- Get data ready and move on
						RU_Master_SEQ_State <= sWR_2_WRITE;
						BitCntDec <= '1'; -- Count this bit as done
						RuDinSft	<= '1'; -- Shift bits in
						RuShiftNLd <= '1'; -- Shift bits out
						RuCaptNUpdt	<= '0'; -- Update config from input
					WHEN sWR_2_WRITE =>
						-- Final Bit, move on
						IF (BitCnt <= 1) THEN
							RU_Master_SEQ_State <= sWR_2_UPDATE;
							RuCaptNUpdt	<= '0'; -- Update config from input
							DelayLd <= '1'; -- Load delay register
						ELSE
							RU_Master_SEQ_State <= sWR_2_WRITE;
							BitCntDec <= '1'; -- Count this bit as done
							RuDinSft	<= '1'; -- Shift bits in
							RuShiftNLd <= '1'; -- Shift bits out
							RuCaptNUpdt <= '0'; -- Update config from input
						END IF;
					WHEN sWR_2_UPDATE =>
						-- Latch data into config register and move on
						RU_Master_SEQ_State <= sDELAY;
					WHEN sDELAY =>
						-- Stay here until delay counter is up
						IF (DelayCnt = 0) THEN
							RU_Master_SEQ_State <= sRECONFIG;
						ELSE
							RU_Master_SEQ_State <= sDELAY;
						END IF;
					WHEN sRECONFIG =>
						-- Once in reconfig, we stay until reset
						RU_Master_SEQ_State <= sRECONFIG;
						RuConfig <= '1'; -- Start a reconfig
					--------------------------
					-- Completed, stay in idle
					WHEN sIDLE =>
						IF (ReloadApplication = '1') THEN
							RU_Master_SEQ_State <= sWR_1_PREP;
						ELSE
							RU_Master_SEQ_State <= sIDLE;
						END IF;
					WHEN OTHERS => 
						NULL;
				END CASE;
			END IF;
		END IF;
	END PROCESS RU_FSM;
	-- FSM END


	---------------------------
	-- Instantiate the RU block
	---------------------------
	RU_Block: fiftyfivenm_rublock
	PORT MAP (
				clk 		=>	CLK,
				shiftnld 	=>	RuShiftNLd,
				captnupdt 	=>	RuCaptNUpdt,
				regin 		=>	RuDin(0),
				rsttimer	=>	WatchdogKick(4),
				rconfig 	=>	RuConfig,
				regout 		=>	RuDout
				);
	-------------------------------
	-- Instantiate the RU block END
	-------------------------------


	-- WDog counter, continuously running as soon as out of reset.
	WDog_Counter: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				WD_Counter <= 0;
			ELSE
				WD_Counter <= (WD_Counter + 1);
			END IF;
		END IF;
	END PROCESS WDog_Counter;

	WatchdogKick <= STD_LOGIC_VECTOR(TO_UNSIGNED(WD_Counter, 5));


	--	Set the application error if we did not just load the STD image
	Set_ERR_Output: PROCESS(CLK)
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (nRuRST = '0') THEN
				ApplicationError_Int <= '0';
			ELSIF ((ConfigCurrent /= "0011") AND (ConfigCurrent /= "0100")) THEN
				ApplicationError_Int <= '1';
			ELSE
				ApplicationError_Int <= '0';
			END IF;
		END IF;
	END PROCESS Set_ERR_Output;



 	END ARCHITECTURE Universal;
