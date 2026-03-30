-- Module BSAT Downloading Flash Control 	                                 	--
-- VHDL Package Indel_lib.BSAT_Downloading_Flash_Control								--
--																										--
--                                                                            --
-- InfoLink, GinLink            Copyright (c): INDEL AG                       --
-- BSAT                         Copyright (c): Besi Switzerland AG            --
--                                                                            --
-- Project:   BSAT                                                            --
--                                                                            --
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland                          --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- Wrapper for the flash interface and the Downloading functionality.         --
-- -------------------------------------------------------------------------- --
-- QFU, 06.03.2018: First draft.																--
-- Remarks:																							--
--																										--
--	Data flow: DL_Feeder => DL_Buffer => DL_Teaser => Flash_FSM => UFM_IP		--
--	As mentioned below: The master software is sending a burst of 128 16Bit		--
--	words till there is a pause with a cycle frequency related duration. De-	--
--	fined in the SW. Our buffer is too big: However a smaller buffer needs the	--
--	same amount of RAM in the MAX10 devices and we would need a new entity.		--
--	This chosen burst size is used to make	sure that the download procedure		--
--	works with "normal" SPI flash based conf. devices, too							--
--	(128x16Bit = 256x8Bit).																		--
-- First DL draft (QFU, 04.10.2018). Missing:	a.) Sequences,						--
--																b.) Only sector erases			--
--																										--
--	Reduced CLK_RU speed (QFU, 19.10.2018)													--
-- Added the lock sequences (QFU, 26.10.2018)											--
--	(QFU, 01.11.2018):																			--
--	Added the manufacturing data loader for the string compare- LED status		--
--																										--
--	(QFU, 20.12.2018):																			--
-- The signal "Flash_Sector_Erase_Done" is cleared in the "Lock_FSM" now in	--
-- the "sIdle" state, too when an "init" word of a sequence is recognized.		--
--	This way round the following sequence does not longer fail even if the		--
--	SW reads back the "Flash_Sector_Erase_Done" before the erasing starts in	--
--	the HW. Download -> Rebooting -> MFD Erasing/Writing -> Downloading			--
--	(fails- data transfer before erase finished) -> Rebooting.						--
--																										--
-- Warning: We can do dual boot with intialized RAM with the help of this		--
--				entity without using the additonal "RAM_Loader" that can be found	--
--				in the FSM, too. For this reason do not change the special code	--
--				here- Intel IP core included!!! because it is modified.				--
--	How does it work:																				--
--				We create the AUX system in dual boot compressed mode with			--
--				256kbits UFM. We have to set the generics accordingly, too.			--
--				Afterwards we switch to the STD system and choose the Quartus		--
--				settings: single boot compressed image w. RAM init, 256kbits UFM	--
--				This way round we have the MAX10 setup that it is possible to use	--
--				designs with memory intiatlization in dual boot mode.					--
--	(QFU, 23.01.2019):																			--
--	Added "Auxiliary_System" generic for RU-Block touchpad functionality.		--
--	--------------------------------------------------------------------------	--
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


ENTITY BSAT_Downloading_Flash_Control IS
	GENERIC	(
				Besi_Target_Device		:	target_device_bundle_t_b_pkg:=NA_BESI_TARGET_DEVICE_BUNDLE_C_B_PKG;
				Auxiliary_System			:	natural RANGE 0 TO 1:= 0
				);
	PORT		(
				-- General signals
				CLK62_5						: IN		std_logic:= '0';
	         CLR_n							: IN		std_logic;
				-- Node signals
				Flash_WR_Access			: IN		std_logic_vector(0 DOWNTO 0); -- WR access is triggered by the data access address!!!
				Flash_WR_AD					: IN		std_logic_vector(Return_Upper_F_I_PKG(32) DOWNTO 0);
				Flash_WR_Data				: IN		std_logic_vector(Return_Upper_F_I_PKG(16) DOWNTO 0);
				Flash_RD_Access			: IN		std_logic_vector(1 DOWNTO 0); -- RD access is triggered by the address access address (1)!!!
				Flash_RD_AD					: IN		std_logic_vector(Return_Upper_F_I_PKG(32) DOWNTO 0);
				Flash_RD_Data				: OUT		std_logic_vector(Return_Upper_F_I_PKG(16) DOWNTO 0);
				Flash_DL_Data_End			: IN		std_logic;
				Flash_DL_WR_Access		: IN		std_logic_vector(0 DOWNTO 0);
				Flash_DL_WR_Data			: IN		std_logic_vector(Return_Upper_F_I_PKG(16) DOWNTO 0);
				Flash_DL_Done				: OUT		std_logic:= '0';
				Flash_Port					: INOUT	bsat_flash_port_bundle_t_b_pkg:= NA_BSAT_FLASH_PORT_BUNDLE_C_B_PKG;
				Flash_Node_Access			: IN		std_logic_vector(1 DOWNTO 0):=(OTHERS => '0');
				Flash_Range_Select		: IN		std_logic_vector(2 DOWNTO 0):=(OTHERS => '0'); -- no defined range.
				Flash_Sequence				: IN		std_logic_vector(7 DOWNTO 0):=(OTHERS => '0');
				Flash_Erase_Request		: IN		std_logic:= '0';
				Flash_Sector_Erase_Done	: OUT		std_logic:= '0';
				Flash_Unlock_Request		: IN		std_logic:= '0';
				Flash_Lock_Request		: IN		std_logic:= '0';
				Flash_Lock_Status			: OUT		std_logic:= '0';
				Flash_Board_Info_Ready	: OUT		std_logic:= '0';
				Flash_Board_MFD			: OUT		std_logic_vector(79 DOWNTO 0):=(OTHERS => '0');
				RU_ReloadApplication		: IN		std_logic:= '1';
				Debug_RAM_Load_Request	: IN		std_logic:= '0';
				RU_Status					: OUT		std_logic_vector(7 DOWNTO 0);
				RU_ApplicationError		: OUT		std_logic:= '0'
				);
END BSAT_Downloading_Flash_Control;


LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.Besi_Package.all;
USE Indel_lib.BSAT_Package.all;
-- Target Device packages...
USE Indel_lib.MAX10_Package.all;


ARCHITECTURE Universal OF BSAT_Downloading_Flash_Control IS


	-------------------
	-- Type Declaration
	-------------------
	TYPE feeder_fsm_state IS
	(
	sRead,
	sWrite
	);
	
	TYPE teaser_fsm_state IS
	(
	sIdle,
	sLoad_space,
	sCheck,
	sAcknowledge_read,
	sWait_start,
	sWait_termination
	);
	
	TYPE lock_fsm_state IS
	(
	sInit,
	sIdle,
	sCalcSpace,
	sCheck_DL_EN,
	sCheck_Reboot_EN,
	sCheck_Unlock_EN,
	sWait_SEQ_Erase_Start,
	sWait_SEQ_Erase_End,
	sWait_DL_SEQ_Erase_Start,
	sWait_DL_SEQ_Erase_End,
	sWait_DL_End,
	sWait_DL_WR_Last
	);
	-----------------------
	-- Type Declaration END
	-----------------------

	
	---------------------
   -- Signal Declaration
   ---------------------
	SIGNAL	Flash_RD_Mode					:	std_logic;
	SIGNAL	Flash_RD_Access_Stored		:	std_logic;
	SIGNAL	Flash_WR_Access_Stored		:	std_logic;
	SIGNAL	Flash_DL_WR_Access_Stored	:	std_logic;
	SIGNAL	Flash_Node_Access_Stored	:	std_logic_vector(1 DOWNTO 0);
	SIGNAL	Flash_DL_AD						:	std_logic_vector(16 DOWNTO 0);
	SIGNAL	Flash_RD_Data_Valid			:	std_logic;
	SIGNAL	Feeder_Mode						:	feeder_fsm_state;
	SIGNAL	Teaser_Mode						:	teaser_fsm_state;
	SIGNAL	Node_Buffer_AD					:	std_logic_vector(7 DOWNTO 0):= (OTHERS => '0');
	SIGNAL	Node_Buffer_WR_EN				:	std_logic;
	SIGNAL	Node_Buffer_Data				:	std_logic_vector(17 DOWNTO 0);
	SIGNAL	Buffer_Node_Data				:	std_logic_vector(17 DOWNTO 0);
	SIGNAL	Flash_Buffer_AD				:	std_logic_vector(7 DOWNTO 0):= (OTHERS => '0');
	SIGNAL	Flash_Buffer_WR_EN			:	std_logic;
	SIGNAL	Flash_Buffer_Data				:	std_logic_vector(17 DOWNTO 0);
	SIGNAL	Buffer_Flash_Data				:	std_logic_vector(17 DOWNTO 0);
	SIGNAL	DL_Cache_Full					:	std_logic;
	SIGNAL	DL_Offset_AD_Start			:	std_logic_vector(16 DOWNTO 0);
	SIGNAL	DL_Offset_AD					:	natural RANGE 0 TO 1023; -- Base offset flash AD count value.
	SIGNAL	DL_WR_Data						:	std_logic_vector(31 DOWNTO 0);
	SIGNAL	RAM_Loader_Offset_AD_Start	:	std_logic_vector(16 DOWNTO 0);
	SIGNAL	RAM_Loader_Offset_AD_END	:	std_logic_vector(16 DOWNTO 0);
	SIGNAL	Flash_Buffer_AD_Counter		:	natural RANGE 0 TO 255; -- Teaser flash count value = 16Bit word
	SIGNAL	Flash_DL_Running				:	std_logic;
	SIGNAL	Next_DL_Word					:	std_logic;
	SIGNAL	Actual_DL_CSR_Unprotected	:	std_logic_vector(4 DOWNTO 0);
	SIGNAL	Actual_DL_CSR_Erase_Sel		:	std_logic_vector(2 DOWNTO 0);
	SIGNAL	Actual_ER_CSR_Unprotected	:	std_logic_vector(4 DOWNTO 0);
	SIGNAL	Actual_ER_CSR_Erase_Sel		:	std_logic_vector(2 DOWNTO 0);
	SIGNAL	Lock_SEQ							:	lock_fsm_state;
	SIGNAL	Lock_SEQ_Counter				:	natural RANGE 0 TO 7;
	SIGNAL	Lock_Erase_EN					:	std_logic;
	SIGNAL	Lock_Erase_EN_Int				:	std_logic:= '0';
	SIGNAL	Locked_Reboot_EN				:	std_logic;
	SIGNAL	Locked_Unlock_EN				:	std_logic;
	SIGNAL	Lock_State						:	std_logic_vector(7 DOWNTO 0);
	SIGNAL	Flash_SEC_Erase_REQ			:	std_logic:= '0';
	SIGNAL	Flash_SEC_Run2					:	std_logic:=	'0';
	SIGNAL	Flash_DL_Run					:	std_logic:= '0';
	SIGNAL	Flash_SEQ_Erase_Running		:	std_logic:= '0';
	SIGNAL	No_Further_Data				:	std_logic:= '0';
	-------------------------
   -- Signal Declaration END
   -------------------------

	

	------------------------
	-- COMPONENT Declaration
	------------------------
	COMPONENT MAX10_Remote_Update
		GENERIC	(
					Auxiliary_System			:	natural RANGE 0 TO 1 := 0; -- Is the actual firmware an AUX system?- Yes: => Stay in CFM0.
					Ignore_Config_SEL			:	natural RANGE 0 TO 1 := 0 -- Design has no Touchpad make sure it starts in AUX when STD corrupted.
					);
		PORT		(
					CLK							: IN	std_logic;
					nRuRST						: IN	std_logic;
					ReloadApplication			: IN	std_logic;
					Boot_Errors					: OUT	std_logic_vector(7 DOWNTO 0);
					ApplicationError			: OUT	std_logic
					);
	END COMPONENT MAX10_Remote_Update;


	COMPONENT UFM_Flash
		GENERIC	(
					Dual_Boot					: string  := "FALSE"
					);
		PORT 		(
					clock                   : in  std_logic                     := '0';             --    clk.clk
					avmm_csr_addr           : in  std_logic                     := '0';             --    csr.address
					avmm_csr_read           : in  std_logic                     := '0';             --       .read
					avmm_csr_writedata      : in  std_logic_vector(31 downto 0) := (others => '0'); --       .writedata
					avmm_csr_write          : in  std_logic                     := '0';             --       .write
					avmm_csr_readdata       : out std_logic_vector(31 downto 0);                    --       .readdata
					avmm_data_addr          : in  std_logic_vector(16 downto 0) := (others => '0'); --   data.address
					avmm_data_read          : in  std_logic                     := '0';             --       .read
					avmm_data_writedata     : in  std_logic_vector(31 downto 0) := (others => '0'); --       .writedata
					avmm_data_write         : in  std_logic                     := '0';             --       .write
					avmm_data_readdata      : out std_logic_vector(31 downto 0);                    --       .readdata
					avmm_data_waitrequest   : out std_logic;                                        --       .waitrequest
					avmm_data_readdatavalid : out std_logic;                                        --       .readdatavalid
					avmm_data_burstcount    : in  std_logic_vector(7 downto 0)  := (others => '0'); --       .burstcount
					reset_n                 : in  std_logic                     := '0'              -- nreset.reset_n
					);
	END COMPONENT UFM_Flash;


	COMPONENT BSAT_System_RAM
		PORT		(
					address_a					: IN	std_logic_vector(7 DOWNTO 0);
					address_b					: IN	std_logic_vector(7 DOWNTO 0);
					clock_a						: IN	std_logic:= '1';
					clock_b						: IN	std_logic;
					data_a						: IN	std_logic_vector(17 DOWNTO 0);
					data_b						: IN	std_logic_vector(17 DOWNTO 0);
					wren_a						: IN	std_logic:= '0';
					wren_b						: IN	std_logic:= '0';
					q_a							: OUT	std_logic_vector(17 DOWNTO 0);
					q_b							: OUT	std_logic_vector(17 DOWNTO 0)
					);
	END COMPONENT BSAT_System_RAM;


   -- PRAGMA SYNTHESIS_OFF
		FOR ALL:	MAX10_Remote_Update USE ENTITY Indel_lib.MAX10_Remote_Update;
		FOR ALL:	UFM_Flash USE ENTITY Indel_lib.UFM_Flash;
		FOR ALL:	BSAT_System_RAM USE ENTITY Indel_lib.BSAT_System_RAM;
	-- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- COMPONENT Declaration END
   ----------------------------

BEGIN

	-----------------------------------
	-- General Part, not device related
	-----------------------------------
	-- Debug downloading...remove the signal afterwards.
	Flash_Port.Trigger <= Flash_Board_Info_Ready;
	
	
	-- Feeback of the Lock Status (we do not allow that the SW polls it like on Hammer boards).
	Flash_Lock_Feedback: PROCESS(cLK62_5, CLR_n)
	BEGIN
		IF (CLR_n = '0') THEN
			Flash_Lock_Status <= '1';
		ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
			Flash_Lock_Status <= NOT(Locked_Unlock_EN);
		END IF;
	END PROCESS Flash_Lock_Feedback;
	
	
	
	-------------------------------------------------------------------
	-- We are using lock sequences based on cyclic codes (galois space)
	-------------------------------------------------------------------
	-- We are using a simplified "Lock FSM"
	Lock_FSM: PROCESS(CLK62_5, CLR_n)
	BEGIN
		IF (CLR_n = '0') THEN
			Flash_Node_Access_Stored <= (OTHERS => '0');
			Lock_Erase_EN <= '0';
			Locked_Reboot_EN <= '0';
			Locked_Unlock_EN <= '0';
			Lock_State <= (OTHERS => '0');
			Lock_SEQ_Counter <= 0;
			Lock_SEQ <= sInit;
			Flash_DL_Run <= '0';
			Flash_DL_Done <= '0';
			Flash_Sector_Erase_Done <= '0';
		ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
				CASE Lock_SEQ IS
					WHEN sInit =>
						Lock_SEQ <= sIdle;
						Lock_State <= (OTHERS => '1');
						Flash_Node_Access_Stored <= Flash_Node_Access;
						Locked_Reboot_EN <= '0';
						Locked_Unlock_EN <= '0';
						Flash_DL_Run <= '0';
						Flash_DL_Done <= '0';
						Flash_Sector_Erase_Done <= '0';
					WHEN sIdle =>
						IF (Flash_Node_Access(0) /= Flash_Node_Access_Stored(0)) THEN
							IF (Lock_SEQ_Counter = 6) THEN
								IF (Flash_Sequence = BSAT_DL_Start_Token_End_C_B_PKG) THEN
									Lock_SEQ <= sCheck_DL_EN;
								ELSIF (Flash_Sequence = BSAT_Reboot_Token_End_C_B_PKG) THEN
									Lock_SEQ <= sCheck_Reboot_EN;
								ELSIF (Flash_Sequence = BSAT_Unlock_Token_End_C_B_PKG) THEN
									Lock_SEQ <= sCheck_Unlock_EN;
								ELSE
									Lock_SEQ <= sInit;
									Lock_SEQ_Counter <= 0;
								END IF;
							ELSE
								IF (Flash_Sequence = BSAT_DL_Start_Token_Init_C_B_PKG) OR (Flash_Sequence = BSAT_Reboot_Token_Init_C_B_PKG) OR (Flash_Sequence = BSAT_Unlock_Token_Init_C_B_PKG) THEN
									Lock_SEQ <= sCalcSpace;
									Flash_DL_Done <= '0';
									Flash_DL_Run <= '0';
									Flash_Sector_Erase_Done <= '0';
								ELSIF (Flash_Sequence = Lock_State) THEN
									Lock_SEQ <= sCalcSpace;
								ELSE
									Lock_SEQ <= sIdle;
									Lock_SEQ_Counter <= 0;
								END IF;
							END IF;
							Flash_Node_Access_Stored <= Flash_Node_Access;
						ELSIF (Flash_Node_Access(1) /= Flash_Node_Access_Stored(1)) THEN
							IF (Flash_Lock_Request = '1') THEN
								Locked_Unlock_EN <= '0';
							END IF;
							Lock_SEQ <= sIdle;
							Flash_Node_Access_Stored <= Flash_Node_Access;
						ELSE
							Lock_SEQ <= sIdle;
						END IF;
					WHEN sCalcSpace =>
						Lock_SEQ <= sIdle;
						Lock_SEQ_Counter <= (Lock_SEQ_Counter + 1);
						Lock_State(0) <= (Flash_Sequence(0) XOR Flash_Sequence(7));
						Lock_State(1) <= ((Flash_Sequence(0) XOR Flash_Sequence(1)) XOR Flash_Sequence(7));
						Lock_State(2) <= ((Flash_Sequence(0) XOR Flash_Sequence(1)) XOR (Flash_Sequence(2) XOR Flash_Sequence(7)));
						Lock_State(3) <= Flash_Sequence(2);
						Lock_State(4) <= Flash_Sequence(3);
						Lock_State(5) <= (Flash_Sequence(1) XOR Flash_Sequence(4));
						Lock_State(6) <= Flash_Sequence(5);
						Lock_State(7) <= ((Flash_Sequence(2) XOR Flash_Sequence(5)) XOR Flash_Sequence(6));
					WHEN sCheck_DL_EN =>
						IF (Flash_Node_Access(0) /= Flash_Node_Access_Stored(0)) THEN
							IF (Flash_Erase_Request = '1') THEN
								Lock_SEQ <= sWait_DL_SEQ_Erase_Start;
								Lock_Erase_EN <= '1';
							ELSE
								Lock_SEQ <= sIdle;
								Lock_Erase_EN <= '0';
							END IF;
							Lock_SEQ_Counter <= 0;
							Flash_Node_Access_Stored <= Flash_Node_Access;
						ELSE
							Lock_SEQ <= sCheck_DL_EN;
							Lock_Erase_EN <= '0';
						END IF;
					WHEN sCheck_Reboot_EN =>
						IF (Flash_Node_Access(0) /= Flash_Node_Access_Stored(0)) THEN
							IF (RU_ReloadApplication = '1') THEN
								Locked_Reboot_EN <= '1';
							ELSE
								Locked_Reboot_EN <= '0';
							END IF;
							Lock_SEQ <= sIdle;
							Lock_SEQ_Counter <= 0;
							Flash_Node_Access_Stored <= Flash_Node_Access;
						ELSE
							Lock_SEQ <= sCheck_Reboot_EN;
							Locked_Reboot_EN <= '0';
						END IF;
					WHEN sCheck_Unlock_EN =>
						IF (Flash_Node_Access(1) /= Flash_Node_Access_Stored(1)) THEN
							IF (Flash_Unlock_Request = '1') THEN
								Lock_SEQ <= sIdle;
								Locked_Unlock_EN <= '1';
							ELSE
								Lock_SEQ <= sIdle;
								Locked_Unlock_EN <= '0';
							END IF;
							Lock_SEQ_Counter <= 0;
							Flash_Node_Access_Stored <= Flash_Node_Access;
						ELSIF (Flash_Node_Access(0) /= Flash_Node_Access_Stored(0)) THEN
							IF (Flash_Erase_Request = '1') THEN
								Lock_SEQ <= sWait_SEQ_Erase_Start;
								Lock_Erase_EN <= '1';
							ELSE
								Lock_SEQ <= sIdle;
								Lock_Erase_EN <= '0';
							END IF;
							Lock_SEQ_Counter <= 0;
							Flash_Node_Access_Stored <= Flash_Node_Access;
						ELSE
							Lock_SEQ <= sCheck_Unlock_EN;
							Lock_Erase_EN <= '0';
							Locked_Unlock_EN <= '0';
						END IF;
					WHEN sWait_SEQ_Erase_Start =>
						IF (Flash_SEQ_Erase_Running = '1') THEN
							Lock_SEQ <= sWait_SEQ_Erase_End;
						ELSE
							Lock_SEQ <= sWait_SEQ_Erase_Start;
						END IF;
					WHEN sWait_SEQ_Erase_End =>
						IF (Flash_SEQ_Erase_Running = '0') THEN
							Lock_SEQ <= sIdle;
							Flash_Sector_Erase_Done <= '1';
						ELSE
							Lock_SEQ <= sWait_SEQ_Erase_End;
						END IF;
						Lock_Erase_EN <= '0';
					WHEN sWait_DL_SEQ_Erase_Start =>
						IF (Flash_SEQ_Erase_Running = '1') THEN
							Lock_SEQ <= sWait_DL_SEQ_Erase_End;
						ELSE
							Lock_SEQ <= sWait_DL_SEQ_Erase_Start;
						END IF;
					WHEN sWait_DL_SEQ_Erase_End =>
						IF (Flash_SEQ_Erase_Running = '0') THEN
							Lock_SEQ <= sWait_DL_End;
							Flash_DL_Run <= '1';
							Flash_Sector_Erase_Done <= '1';
						ELSE
							Lock_SEQ <= sWait_DL_SEQ_Erase_End;
						END IF;
						Lock_Erase_EN <= '0';
					WHEN sWait_DL_End => 
						IF (No_Further_Data = '1') THEN
							Lock_SEQ <= sWait_DL_WR_Last;
							Flash_DL_Run <= '0';
						ELSE
							Lock_SEQ <= sWait_DL_End;
						END IF;
					WHEN sWait_DL_WR_Last =>
						IF (Flash_DL_Running = '0') THEN
							Lock_SEQ <= sIdle;
							Flash_DL_Done <= '1';
						ELSE
							Lock_SEQ <= sWait_DL_WR_Last;
						END IF;
					WHEN OTHERS =>
						NULL;
				END CASE;
		END IF;
	END PROCESS Lock_FSM;
	-----------------------------------------------------------------------
	-- We are using lock sequences based on cyclic codes (galois space) END
	-----------------------------------------------------------------------
	
	
	-------------------------
	-- Download buffer feeder
	-------------------------
	DL_Feeder: PROCESS(CLK62_5, CLR_n)
		VARIABLE	Node_Buffer_AD_Counter: natural RANGE 0 TO 255;
	BEGIN
		IF (CLR_n = '0') THEN
			Feeder_Mode <= sRead;
			Flash_DL_WR_Access_Stored <= '0';
			Node_Buffer_WR_EN <= '0';
			Node_Buffer_Data	<= (OTHERS => '0');
			Node_Buffer_AD_Counter:= 0;
			DL_Cache_Full <= '0';
		ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
			IF (Flash_DL_Run = '1') THEN
				IF (Flash_DL_WR_Access(0) /= Flash_DL_WR_Access_Stored) THEN
					CASE Feeder_Mode IS
						WHEN sRead	=>
							IF ((Buffer_Node_Data(17) = '0') AND (Buffer_Node_Data(8) = '0')) THEN
								Node_Buffer_WR_EN <= '1';
								Node_Buffer_Data <= ('1' & Flash_DL_WR_Data(15 DOWNTO 8) & '1' & Flash_DL_WR_Data(7 DOWNTO 0));
								Feeder_Mode <= sWrite;
								DL_Cache_Full <= '0';
							ELSE
								DL_Cache_Full <= '1';
							END IF;
						WHEN sWrite	=>
							Node_Buffer_WR_EN <= '0';
							Flash_DL_WR_Access_Stored <= Flash_DL_WR_Access(0);
							Feeder_Mode <= sRead;
							-- It is a circular buffer...start counting at the intial address again.
							IF (Node_Buffer_AD_Counter = 255) THEN
								Node_Buffer_AD_Counter := 0;
							ELSE
								Node_Buffer_AD_Counter := (Node_Buffer_AD_Counter + 1);
							END IF;
						WHEN OTHERS =>
							NULL;
					END CASE;
				ELSE
					Node_Buffer_WR_EN <= '0';
				END IF;
			ELSE
				Node_Buffer_AD_Counter:= 0; -- Clear the counter after each download.
				Node_Buffer_Data <= (OTHERS => '0');
				Flash_DL_WR_Access_Stored <= Flash_DL_WR_Access(0); -- Make sure that we catch the first word as soon as the DL starts...
			END IF;	
		END IF;
		Node_Buffer_AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(Node_Buffer_AD_Counter,8)); -- Assign the variable.
	END PROCESS DL_Feeder;
	-----------------------------
	-- Download buffer feeder END
	-----------------------------
		
	
	------------------
	-- Download buffer
	------------------
	-- We take the too big "BSAT_System_RAM" block because it needs the same number of memory blocks (1) like a buffer of half the size...
	-- However take care: By using a TDP RAM block with different word sizes the needed blocks is doubled in MAX10 chips.
	DL_Buffer: BSAT_System_RAM
		PORT MAP	(
					address_a				=>	Node_Buffer_AD,
					address_b				=>	Flash_Buffer_AD,
					clock_a					=> CLK62_5, -- Node Side
					clock_b					=> CLK62_5, -- UFM side
					data_a					=> Node_Buffer_Data,
					data_b					=>	Flash_Buffer_Data,
					wren_a					=>	Node_Buffer_WR_EN,
					wren_b					=>	Flash_Buffer_WR_EN,
					q_a						=>	Buffer_Node_Data,
					q_b						=>	Buffer_Flash_Data
					);
	----------------------
	-- Download buffer END
	----------------------
					
					
	------------------
	-- Download Teaser
	------------------
	-- We present the needed data out of the buffer (32bit) to a flash FSM.
	DL_Teaser: PROCESS(CLK62_5, CLR_n)
	BEGIN
		IF (CLR_n = '0') THEN
			Teaser_Mode <= sIdle;
			Flash_Buffer_WR_EN <= '0';
			Flash_Buffer_Data <= (OTHERS => '0');
			Next_DL_Word <= '0';
			Flash_Buffer_AD_Counter <= 0;
			DL_Offset_AD <= 0;
			DL_WR_Data <= (OTHERS => '0');
			Flash_DL_AD <= (OTHERS => '0');
			No_Further_Data <= '0';
		ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
			CASE Teaser_Mode IS
				WHEN	sIdle			=>
					IF (Flash_DL_Run = '1') THEN
						Teaser_Mode <= sLoad_space;
					ELSE
						Teaser_Mode <= sIdle;
						Flash_DL_AD <= (OTHERS => '0');
					END IF;
					No_Further_Data <= '0';
				WHEN 	sLoad_space	=>
					DL_Offset_AD <= TO_INTEGER(UNSIGNED(DL_Offset_AD_Start(16 DOWNTO 7))); -- DL_Offset_AD_Start;--Flash_Range_Select
					Flash_Buffer_AD_Counter <= 0;
					Teaser_Mode <= sCheck;
				WHEN	sCheck		=>
					IF ((Buffer_Flash_Data(17) = '1') AND (Buffer_Flash_Data(8) = '1')) THEN
						IF (Flash_Buffer_AD(0) = '0') THEN
							DL_WR_Data(31 DOWNTO 16) <= (Buffer_Flash_Data(16 DOWNTO 9) & Buffer_Flash_Data(7 DOWNTO 0)); -- UFM data
						ELSE
							DL_WR_Data(15 DOWNTO 0) <= (Buffer_Flash_Data(16 DOWNTO 9) & Buffer_Flash_Data(7 DOWNTO 0)); -- UFM data
						END IF;
						-- We have to update the read indicator...
						Flash_Buffer_WR_EN <= '1';
						Flash_Buffer_Data <= (OTHERS => '0');
						Teaser_Mode <= sAcknowledge_Read;
					ELSE
						IF (Flash_DL_Run = '0') THEN
							Teaser_Mode <= sIdle;
						ELSE
							IF (Flash_DL_Data_End = '1') THEN
								No_Further_Data <= '1';
							END IF;
							Teaser_Mode <= sCheck;
						END IF;
					END IF;
				WHEN	sAcknowledge_Read	=>
					Flash_Buffer_WR_EN <= '0';
					IF (Flash_Buffer_AD_Counter = 255) THEN
						Flash_Buffer_AD_Counter <= 0;
						DL_Offset_AD <= (DL_Offset_AD + 1);
					ELSE
						Flash_Buffer_AD_Counter <= (Flash_Buffer_AD_Counter + 1);
					END IF;
					IF (Flash_Buffer_AD(0) = '1') THEN
						Next_DL_Word <= '1';
						Flash_DL_AD <= (STD_LOGIC_VECTOR(TO_UNSIGNED(DL_Offset_AD,10)) & Flash_Buffer_AD(7 DOWNTO 1)); -- Put the complete address together.
						Teaser_Mode <= sWait_start;
					ELSE
						Teaser_Mode <= sCheck;
					END IF;
				WHEN	sWait_start	=>
					IF (Flash_DL_Running = '1') THEN
						Next_DL_Word <= '0';
						Teaser_Mode <= sWait_termination;
					ELSE
						Teaser_Mode <= sWait_Start;
					END IF;
				WHEN	sWait_termination	=>
					IF (Flash_DL_Running = '0') THEN
						Teaser_Mode <= sCheck;
					ELSE
						Teaser_Mode <= sWait_termination;
					END IF;
				WHEN	OTHERS	=>
					NULL;
			END CASE;
		END IF;
	END PROCESS DL_Teaser;
	Flash_Buffer_AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(Flash_Buffer_AD_Counter,8));
	----------------------
	-- Download Teaser END
	----------------------
	
	

	-------------------------------
	-- Flash Access based on device
	-------------------------------
	-- We will have a "block" for each device familiy and within this block we assign the generally needed parameters.
	
	---------------
	-- It's a MAX10
	---------------
	MAX10_Device_Used: IF (Besi_Target_Device.Family = Target_Device_M10_C_B_PKG) GENERATE
		
		-------------------
		-- Type Declaration
		-------------------
		TYPE ufm_fsm_state IS
		(
		sUFM_Init,
		sStart,
		sInit,
		sIdle,
		sReset,
		sRead_CSR_Status,
		sWrite_CSR_Control,
		sLoad_MFD0,
		sLoad_MFD1,
		sLoad_User_RAM0,
		sLoad_User_RAM1,
		sUnlock_Sector,
		sProgram,
		sRead_single0,
		sRead_single1,
		sWrite_single0,
		sWrite_single1,
		sWrite_download0,
		sWrite_download1,
		sErase_Sector0,
		sErase_Sector1,
		sErase_Sector2,
		--	sErase_Page0,
		--	sErase_Page1,
		sIgnore,
		sWait_MFD_termination,
		sWait_termination,
		sEnd,
		sPause,
		sStop
		);
		-----------------------
		-- Type Declaration END
		-----------------------

	
		-----------------------
		-- Constant Declaration
		-----------------------
		CONSTANT	MAX10_Settings			:	max10_settings_bundle_t_mx_pkg:= (Besi_Target_Device.Variation,Besi_Target_Device.Boot_Mode,Besi_Target_Device.MFD_Storage,Besi_Target_Device.RAM_Loader,Besi_Target_Device.RAM_Size);
												-- Device:			natural	RANGE 0 TO 7;-- 0 = M02, 1 = M04, 2 = M08, 3 = M16, 4 = M25, 5 = M40, 6 = M50, 7 = not defined (see defined constants, too).
												-- Boot_Mode:		natural	RANGE 0 TO 1;-- 0 = single Configuration, 1 = dual Configuration
												-- MFD_EN:			natural	RANGE 0 TO 1;-- 0 = no manufacturing data saved in the flash, 1 = use the flash for manufacturing data, too.
												-- RAM_Loader_EN:	natural	RANGE 0 TO 1;-- 0 = no user RAM loading in dual boot mode, 1 = RAM loading in dual boot mode active.
												-- RAM_Size
		CONSTANT MAX10_Flash_CFG		:	max10_setup_bundle_t_mx_pkg:= Setup_MAX10_F_MX_PKG(MAX10_Settings);
		CONstant	Dual_Boot_String		:	string:=Return_Comparison_boolean_string_F_I_PKG(Besi_Target_Device.Boot_Mode,ON_C_I_PKG);
		-----------------------
		-- Constant Declaration
		-----------------------
		
		
		---------------------
		-- Signal Declaration
		---------------------
		SIGNAL	CLK_RU						:	std_logic;
		SIGNAL	UFM_CSR						:	ufm_csr_port_bundle_t_mx_pkg;
		SIGNAL	UFM_Data						:	ufm_data_port_bundle_t_mx_pkg;
		SIGNAL	UFM_Master_SEQ_State		:	ufm_fsm_state;
		SIGNAL	UFM_Word_Select			:	std_logic_vector(1 DOWNTO 0);
		SIGNAL	UFM_Byte_Lock				:	std_logic;
		SIGNAL	Flash_DL_Run_Int			:	std_logic;
		SIGNAL	Actual_Range				:	max10_range_access_bundle_t_mx_pkg:= NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG;
		SIGNAL	Actual_DL_Range			:	max10_range_access_bundle_t_mx_pkg:= NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG;
		SIGNAL	RAM_Loader_Counter		:	natural RANGE 0 TO 16#3DFF#;
		SIGNAL	Flash_MFD					:	std_logic_vector(127 DOWNTO 0):= (OTHERS => '0');
		SIGNAL	Debug_RAM_Load_Request_Int : std_logic;
		-------------------------
		-- Signal Declaration END
		-------------------------
	BEGIN
		
		-- We continuously assign the selected range based on the chosen device type to a local signal
		Actual_Range <= Setup_MAX10_Range_Access_F_MX_PKG(TO_INTEGER(UNSIGNED(Flash_Range_Select)),MAX10_Flash_CFG);
	
		-- By calling the MAX10 package functions we get the correct range data for the chip at the point in time when the DL is activated.
		UFM_DL_Range_Select: PROCESS(CLK62_5, CLR_n)
		BEGIN
			IF (CLR_n = '0') THEN
				Actual_DL_Range <= NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG;
				Flash_DL_Run_Int <= '0';
			ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
				IF ((Flash_DL_Run = '1') AND (Flash_DL_Run_Int = '0')) THEN
					Actual_DL_Range <= Actual_Range;
				ELSIF (Flash_DL_Run = '0') THEN
					Actual_DL_Range <= NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG;
				END IF;
				Flash_DL_Run_Int <= Flash_DL_Run;
			END IF;
		END PROCESS UFM_DL_Range_Select;
		
		
		-- We assign the values to local signals. This way round way can add another FPGA family later on.
		DL_Offset_AD_Start <= STD_LOGIC_VECTOR(TO_UNSIGNED(Actual_DL_Range.Range_Start,17));
		Actual_DL_CSR_Unprotected <=Actual_DL_Range.CSR_Unprotected;
		Actual_DL_CSR_Erase_Sel <= Actual_DL_Range.CSR_Erase_Sel;	
	
	
		-- Concurrent 0
		-- We detect the rising slope of the command as long as we have no other logic (for debugging only).
		Slope_Sector_Erase: PROCESS(CLK62_5, CLR_n)
		BEGIN
			IF (CLR_n = '0') THEN
				Lock_Erase_EN_Int <= '0';
				Flash_SEC_Erase_REQ <= '0';
				Actual_ER_CSR_Unprotected <= NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG.CSR_Unprotected;
				Actual_ER_CSR_Erase_Sel <= NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG.CSR_Erase_Sel;
			ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
				IF ((Lock_Erase_EN_Int = '0') AND (Lock_Erase_EN = '1')) THEN
					Flash_SEC_Erase_REQ <= '1';
					Actual_ER_CSR_Unprotected <=Actual_Range.CSR_Unprotected;
					Actual_ER_CSR_Erase_Sel <= Actual_Range.CSR_Erase_Sel;	
				ELSE
					Flash_SEC_Erase_REQ <= '0';
				END IF;
				Lock_Erase_EN_Int <= Lock_Erase_EN;
			END IF;
		END PROCESS Slope_Sector_Erase;
		
		
		-- Assign the CLK for the RAM Loader...
		Flash_Port_Used: IF (Besi_Target_Device.RAM_Loader = 1) GENERATE
		BEGIN
			Flash_Port.Loader_CLK <= CLK62_5;
		END GENERATE Flash_Port_Used;
		
		-- No RAM Loader, Loader_CLK not used at all.
		No_RAM_Loader: IF (Besi_Target_Device.RAM_Loader = 0) GENERATE 
		BEGIN
			Flash_Port.Loader_CLK <= '0';
		END GENERATE No_RAM_Loader;
		
		-- Assign the MFD board data...
		MFD_Reader_Used: IF (Besi_Target_Device.MFD_Storage = 1) GENERATE
		BEGIN
			Flash_Board_MFD <= Flash_MFD(103 DOWNTO 24); -- Shift because Besi is storing ("0x01 & 0x00 & 0x0D") in the MFD space first (as a header).
		END GENERATE MFD_Reader_Used;
		
		-- No  MFD Reader
		No_MFD_Reader: IF (Besi_Target_Device.MFD_Storage = 0) GENERATE
		BEGIN
			Flash_Board_MFD <= (OTHERS  => '0');
		END GENERATE No_MFD_Reader;
		
		----------------
		-- UFM Flash FSM
		----------------
		Flash_FSM: PROCESS(CLK62_5, CLR_n)
		BEGIN
			IF (CLR_n = '0') THEN
				UFM_Master_SEQ_State <= sUFM_Init;
				UFM_CSR.AD <= '0';
				UFM_CSR.WR <= '0';
				UFM_CSR.RD <= '0';
				UFM_CSR.WR_Data <= (OTHERS => '0');
				UFM_Data.AD <= (OTHERS => '0');
				UFM_Data.RD <= '0';
				UFM_Data.WR <= '0';
				UFM_Data.WR_Data <= (OTHERS => '0');
				UFM_Data.Burst_Count <= (OTHERS => '0');
				UFM_Word_Select <= (OTHERS => '0');
				UFM_Byte_Lock <= '0';
				Flash_RD_Access_Stored <= '0';
				Flash_WR_Access_Stored <= '0';
				Flash_RD_Data <= (OTHERS => '0');
				Flash_DL_Running <= '0';
				Flash_SEC_Run2 <= '0';
				RAM_Loader_Counter <= 0;
				Flash_Port.Loader_Running <= '0';
				Flash_Port.Loader_Finished <= '0';
				Flash_SEQ_Erase_Running <= '0';
				Flash_Board_Info_Ready <= '0';
				Flash_MFD <= (OTHERS => '0');
			ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
				Flash_RD_Access_Stored <= Flash_RD_Access(1); --uiuiui
				Flash_WR_Access_Stored <= Flash_WR_Access(0); --uiuiui
				CASE UFM_Master_SEQ_State IS
					-- Take care- do not remove: the UFM IP core is doing what it likes after booting...
					-- For this reason we have to make sure it settled down...
					WHEN sUFM_Init =>
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Idle_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sStart;
						ELSE
							UFM_Master_SEQ_State <= sUFM_Init;
						END IF;
					WHEN sStart =>
						IF (Besi_Target_Device.MFD_Storage = 1) THEN
							-- Yes, we have to read the board number string...
							UFM_Master_SEQ_State <= sLoad_MFD0;			
							-- Load the inital offset
							UFM_Data.AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(MAX10_Flash_CFG.Ranges.MAN_Start,17));
							RAM_Loader_Counter <= MAX10_Flash_CFG.Ranges.MAN_Start;
							UFM_Data.Burst_Count <= "00000001";
							UFM_Data.RD <= '1';
							-- Status update for output signal
							Flash_Board_Info_Ready <= '0';
							Flash_MFD <= (OTHERS => '0');
						ELSE
							UFM_Master_SEQ_State <= sInit;
						END IF;
					WHEN sLoad_MFD0 =>
						UFM_Data.RD <= '0';
						UFM_Data.Burst_Count <= "00000000";
						IF (UFM_Data.RD_Data_VD = '1') THEN
							Flash_MFD((TO_INTEGER(TO_UNSIGNED(RAM_Loader_Counter,2))*32 + 31) DOWNTO (TO_INTEGER(TO_UNSIGNED(RAM_Loader_Counter,2))*32)) <= (UFM_Data.RD_Data(7 DOWNTO 0) & UFM_Data.RD_Data(15 DOWNTO 8) & UFM_Data.RD_Data(23 DOWNTO 16) & UFM_Data.RD_Data(31 DOWNTO 24));
							IF (RAM_Loader_Counter < (MAX10_Flash_CFG.Ranges.MAN_Start + 3)) THEN
								UFM_Master_SEQ_State <= sLoad_MFD1;
								RAM_Loader_Counter <= (RAM_Loader_Counter + 1);
							ELSE
								UFM_Master_SEQ_State <= sWait_MFD_termination;
								Flash_Board_Info_Ready <= '1';
							END IF;
						ELSE
							UFM_Master_SEQ_State <= sLoad_MFD0;
						END IF;
					WHEN sLoad_MFD1 =>
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Idle_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sLoad_MFD0;
							UFM_Data.AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(RAM_Loader_Counter,17));
							UFM_Data.Burst_Count <= "00000001";
							UFM_Data.RD <= '1';
						ELSE
							UFM_Master_SEQ_State <= sLoad_MFD1;
						END IF;
					WHEN sInit =>
						IF ((Besi_Target_Device.Boot_Mode = 1) AND (Besi_Target_Device.RAM_Loader = 1)) THEN
							-- Yes, we have to load the RAM...
							UFM_Master_SEQ_State <= sLoad_User_RAM0;
							-- Load the inital offset
							UFM_Data.AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(MAX10_Flash_CFG.Ranges.RAM_Start,17));
							RAM_Loader_Counter <= MAX10_Flash_CFG.Ranges.RAM_Start;
							UFM_Data.Burst_Count <= "00000001";
							UFM_Data.RD <= '1';
							-- Status update for the Flash_Port
							Flash_Port.Loader_Running <= '1';
							Flash_Port.Loader_Finished <= '0';
						ELSE
							UFM_Master_SEQ_State <= sIdle;
						END IF;
					--* As soon as we are in UserMode, we are loading the user RAM.
					WHEN sLoad_User_RAM0 =>
						UFM_Data.RD <= '0';
						UFM_Data.Burst_Count <= "00000000";
						IF (UFM_Data.RD_Data_VD = '1') THEN
							Flash_Port.Loader_WREN <= '1';
							Flash_Port.Loader_AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(RAM_Loader_Counter,14));
							Flash_Port.Loader_Data <= UFM_Data.RD_Data;
							IF (RAM_Loader_Counter < MAX10_Flash_CFG.Ranges.RAM_END) THEN
								UFM_Master_SEQ_State <= sLoad_User_RAM1;
								RAM_Loader_Counter <= (RAM_Loader_Counter + 1);
							ELSE
								UFM_Master_SEQ_State <= sWait_termination;
								Flash_Port.Loader_Running <= '0';
								Flash_Port.Loader_Finished <= '1';
							END IF;
						ELSE
							UFM_Master_SEQ_State <= sLoad_User_RAM0;
						END IF;
					WHEN sLoad_User_RAM1 =>
						Flash_Port.Loader_WREN <= '0';
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Idle_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sLoad_User_RAM0;
							UFM_Data.AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(RAM_Loader_Counter,17));
							UFM_Data.Burst_Count <= "00000001";
							UFM_Data.RD <= '1';
						ELSE
							UFM_Master_SEQ_State <= sLoad_User_RAM1;
						END IF;
					WHEN sIdle =>
						-- The master started sending download data...
						IF ((Flash_DL_Run = '1') AND (Next_DL_Word = '1')) THEN
							Flash_DL_Running <= '1';
							UFM_Master_SEQ_State <= sWrite_download0;
							-- Prepare the DL write
							UFM_Data.AD <= Flash_DL_AD;
							UFM_Data.WR_Data <= DL_WR_Data;
							UFM_Data.Burst_Count <= "00000001";
							-- Setup the configuration registers..
							UFM_CSR.AD <= '1';
							UFM_CSR.RD <= '0';
							UFM_CSR.WR <= '1';
							UFM_CSR.WR_Data <= (Padding_Top_CSR_Ctrl_C_MX_PKG & Actual_DL_CSR_Unprotected & None_CSR_Erase_Sel_C_MX_PKG & No_PG_CSR_Erase_Sel_C_MX_PKG);
						-- A single RD access was detected...
						ELSIF (Flash_RD_Access(1)/= Flash_RD_Access_Stored) THEN
							UFM_Master_SEQ_State <= sRead_single0;
							-- Check if it is the virtual manufacturing address 0x00FFxyzx: To be compatible with the Hammers, we have sadly not directly implemented the 32Bit mode X"FFFF"(had needed an m/c SW change ;-().
							IF (Flash_RD_AD(23 DOWNTO 16) = X"FF") THEN
								UFM_Data.AD <= (STD_LOGIC_VECTOR(TO_UNSIGNED(MAX10_Flash_CFG.Ranges.MAN_Start,17))(16 DOWNTO 8) & Flash_RD_AD(9 DOWNTO 2));
							-- "Normal", real addresses
							ELSE
								UFM_Data.AD <= Flash_RD_AD(18 DOWNTO 2);-- 32Bit flash addresses...
							END IF;
							UFM_Word_Select <= Flash_RD_AD(1 DOWNTO 0);
							IF (Flash_RD_AD(1 DOWNTO 0) = "11") THEN
								UFM_Data.Burst_Count <= "00000010";-- We have to make sure that we are compatible to all the Besi tools ;-(
							ELSE
								UFM_Data.Burst_Count <= "00000001";
							END IF;
							UFM_Data.RD <= '1';
						-- A single WR access was initiated by the master...
						ELSIF (Flash_WR_Access(0)/= Flash_WR_Access_Stored) THEN
							IF ((TO_INTEGER(UNSIGNED(Flash_WR_AD(18 DOWNTO 2))) < MAX10_Flash_CFG.Ranges.UFM0_Start) OR ((Flash_WR_AD(23 DOWNTO 16) = X"FF") AND (Locked_Unlock_EN = '1'))) THEN -- Hint UFM0 is the "higher" sector!!!
								UFM_Master_SEQ_State <= sWrite_single0;
								IF (Flash_WR_AD(23 DOWNTO 16) = X"FF") THEN
									UFM_Data.AD <= (STD_LOGIC_VECTOR(TO_UNSIGNED(MAX10_Flash_CFG.Ranges.MAN_Start,17))(16 DOWNTO 8) & Flash_WR_AD(9 DOWNTO 2));-- Virtual MFD address
									UFM_CSR.WR_Data <= (Padding_Top_CSR_Ctrl_C_MX_PKG & UFM0_CSR_Unprotected_C_MX_PKG & None_CSR_Erase_Sel_C_MX_PKG & No_PG_CSR_Erase_Sel_C_MX_PKG); -- Dummy (padding) & WR_protection(5...1) "
								ELSE
									UFM_Data.AD <= Flash_WR_AD(18 DOWNTO 2);-- 32Bit flash addresses...UFM1
									UFM_CSR.WR_Data <= (Padding_Top_CSR_Ctrl_C_MX_PKG & UFM1_CSR_Unprotected_C_MX_PKG & None_CSR_Erase_Sel_C_MX_PKG & No_PG_CSR_Erase_Sel_C_MX_PKG); -- Dummy (padding) & WR_protection(5...1) "
								END IF;
								CASE Flash_WR_AD(1 DOWNTO 0) IS
									WHEN "00" =>
										UFM_Data.WR_Data <= (Flash_WR_Data & x"FFFF");
									WHEN "01" =>
										UFM_Data.WR_Data <= (x"FF" & Flash_WR_Data & x"FF");
									WHEN "10" =>
										UFM_Data.WR_Data <= (x"FFFF" & Flash_WR_Data);
									WHEN "11" =>
										UFM_Data.WR_Data <= (Flash_WR_Data(7 DOWNTO 0) & x"FFFFFF");
									WHEN OTHERS =>
										NULL;
								END cASE;
								UFM_Data.Burst_Count <= "00000001";
								UFM_CSR.AD <= '1';
								UFM_CSR.RD <= '0';
								UFM_CSR.WR <= '1';
							ELSE
								UFM_Master_SEQ_State <= sIdle;
							END IF;
						ELSIF ((Flash_SEC_Erase_REQ	= '1') OR (Flash_SEC_Run2 = '1')) THEN -- Max. erase time = 350ms.
							UFM_Master_SEQ_State <= sErase_Sector0;
							UFM_Data.AD <= (OTHERS => '0');
							UFM_Data.WR_Data <= (OTHERS => '0');
							UFM_Data.Burst_Count <= "00000001";
							UFM_CSR.AD <= '1';
							UFM_CSR.RD <= '0';
							UFM_CSR.WR <= '1';
							-- The STD System in dual boot mode consists of two different flash sectors...
							IF ((Actual_ER_CSR_Unprotected = CFM12_CSR_Unprotected_C_MX_PKG) AND (Flash_SEC_Run2 = '0'))THEN
								Flash_SEC_Run2 <= '1';
								UFM_CSR.WR_Data <= (Padding_Top_CSR_Ctrl_C_MX_PKG & CFM1_CSR_Unprotected_C_MX_PKG & CFM1_CSR_Erase_Sel_C_MX_PKG & No_PG_CSR_Erase_Sel_C_MX_PKG); -- Dummy (padding) & WR_protection(5...1) "
							ELSE
								Flash_SEC_Run2 <= '0';
								UFM_CSR.WR_Data <= (Padding_Top_CSR_Ctrl_C_MX_PKG & Actual_ER_CSR_Unprotected & Actual_ER_CSR_Erase_Sel & No_PG_CSR_Erase_Sel_C_MX_PKG); -- Dummy (padding) & WR_protection(5...1) ";
							END IF;
							Flash_SEQ_Erase_Running <= '1';
	--					ELSIF (Flash_Page_Erase_REQ	= '1') THEN -- Max. erase time is 350ms, too (like for sector erase)!
						ELSE
							UFM_Master_SEQ_State <= sIdle;
							UFM_CSR.AD <= '0';
							UFM_CSR.RD <= '0';
							UFM_CSR.WR <= '0';
							UFM_Data.RD <= '0';
							UFM_Data.WR <= '0';
							Flash_SEQ_Erase_Running <= '0';
						END IF;
					WHEN sRead_single0 =>
							UFM_Data.RD <= '0';
							UFM_Data.Burst_Count <= "00000000";
						IF (UFM_Data.RD_Data_VD = '1') THEN
							CASE UFM_Word_Select IS
								WHEN "00" =>
									UFM_Master_SEQ_State <= sWait_termination;
									Flash_RD_Data <= UFM_Data.RD_Data(31 DOWNTO 16);
								WHEN "01" =>
									UFM_Master_SEQ_State <= sWait_termination;
									Flash_RD_Data <= UFM_Data.RD_Data(23 DOWNTO 8);
								WHEN "10" =>
									UFM_Master_SEQ_State <= sWait_termination;
									Flash_RD_Data <= UFM_Data.RD_Data(15 DOWNTO 0);
								WHEN "11" =>
									IF (UFM_Byte_Lock = '0') THEN
										UFM_Master_SEQ_State <= sRead_single0;
										Flash_RD_Data(7 DOWNTO 0) <= (UFM_Data.RD_Data(31 DOWNTO 24));
										UFM_Byte_Lock <= '1';
									ELSE
										UFM_Master_SEQ_State <= sWait_termination;
										Flash_RD_Data(15 DOWNTO 8) <= (UFM_Data.RD_Data(7 DOWNTO 0));
										UFM_Byte_Lock <= '0';
									END IF;
								WHEN OTHERS =>
									NULL;
							END CASE;
						ELSE
							UFM_Master_SEQ_State <= sRead_single0;
						END IF;
					WHEN sWrite_download0 =>
						-- Finally write the data...
						UFM_Master_SEQ_State <= sWrite_download1;
						UFM_CSR.AD <= '1';
						UFM_CSR.RD <= '1';
						UFM_CSR.WR <= '0';
						UFM_Data.WR <= '1';
					WHEN sWrite_download1 =>
						-- Wait till the write access is terminated:- Take care!- This can take between 34us and 305us!!!
						IF (UFM_Data.Wait_RQ = '0') THEN
							Flash_DL_Running <= '0';
							UFM_Master_SEQ_State <= sIdle;
							UFM_Data.WR <= '0';
						ELSE
							UFM_Master_SEQ_State <= sWrite_download1;
						END IF;
						UFM_CSR.AD <= '0';
					WHEN sWrite_single0 =>
						UFM_Master_SEQ_State <= sWrite_single1;
						UFM_CSR.AD <= '1';
						UFM_CSR.RD <= '1';
						UFM_CSR.WR <= '0';
						UFM_Data.WR <= '1';
					WHEN sWrite_single1 =>
						IF (UFM_Data.Wait_RQ = '0') THEN
							UFM_Master_SEQ_State <= sIdle;
							UFM_Data.WR <= '0';
						ELSE
							UFM_Master_SEQ_State <= sWrite_single1;
						END IF;
						UFM_CSR.AD <= '0';
					WHEN sErase_Sector0 =>
						UFM_Master_SEQ_State <= sErase_Sector1;
						UFM_CSR.AD <= '0';
						UFM_CSR.RD <= '1';
						UFM_CSR.WR <= '0';
						UFM_Data.WR <= '0';
					WHEN sErase_Sector1 =>
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Busy_Erase_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sErase_Sector2;
						ELSE
							UFM_Master_SEQ_State <= sErase_Sector1;
						END IF;
					WHEN sErase_Sector2 =>
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Idle_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sIdle; 
						ELSE
							UFM_Master_SEQ_State <= sErase_Sector2;
						END IF;
					--WHEN sErase_Page0 =>
					--		UFM_Master_SEQ_State <= sErase_Page1;
					--WHEN sErase_Page1 =>
					--		UFM_Master_SEQ_State <= sIdle;
					WHEN sWait_termination =>
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Idle_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sIdle;
						ELSE
							UFM_Master_SEQ_State <= sWait_termination;
						END IF;
						UFM_CSR.RD <= '0';
						Flash_Port.Loader_WREN <= '0';
					WHEN sWait_MFD_termination =>
						IF (UFM_CSR.RD_Data(1 DOWNTO 0) = UFM_CSR_Idle_C_MX_PKG) THEN
							UFM_Master_SEQ_State <= sInit;
						ELSE
							UFM_Master_SEQ_State <= sWait_MFD_termination;
						END IF;
						UFM_CSR.RD <= '0';
						Flash_Board_Info_Ready <= '0';
					WHEN OTHERS =>
						NULL;
				END CASE;
			END IF;
		END PROCESS Flash_FSM;
		--------------------
		-- UFM Flash FSM END
		--------------------
	
	
		------------
		-- UFM Flash
		------------
		UFM_Block: UFM_Flash
		GENERIC MAP	(
						Dual_Boot					=> Dual_Boot_String			--		Boot_Mode single or dual 
						)
		PORT MAP		(
						clock                   => CLK62_5,            		--		clk.clk
						avmm_csr_addr           => UFM_CSR.AD,		    		--    csr.address
						avmm_csr_read           => UFM_CSR.RD,   				--       .read
						avmm_csr_writedata      => UFM_CSR.WR_Data,			--       .writedata
						avmm_csr_write          => UFM_CSR.WR,					--       .write
						avmm_csr_readdata       => UFM_CSR.RD_Data,			--       .readdata
						avmm_data_addr          => UFM_Data.AD,				--   	data.address
						avmm_data_read          => UFM_Data.RD,				--       .read
						avmm_data_writedata     => UFM_Data.WR_Data,			--       .writedata
						avmm_data_write         => UFM_Data.WR,				--       .write
						avmm_data_readdata      => UFM_Data.RD_Data,			--       .readdata
						avmm_data_waitrequest   => UFM_Data.Wait_RQ,			--       .waitrequest
						avmm_data_readdatavalid => UFM_Data.RD_Data_VD,		--       .readdatavalid
						avmm_data_burstcount    => UFM_Data.Burst_Count,	--       .burstcount
						reset_n                 => CLR_n							-- 	nreset.reset_n
						);
		----------------
		-- UFM Flash END
		----------------
		
		
		-- We need a slower local CLK_RU clock without global resources...
		RU_Clock: PROCESS(CLK62_5,CLR_n)
		BEGIN
			IF (CLR_n = '0') THEN
				CLK_RU <= '0';
			ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
				CLK_RU <= NOT(CLK_RU);
			END IF;
		END PROCESS RU_Clock;
		
		
		----------------------------
		-- MAX10 Remote Update Block
		----------------------------
		-- Yes, in contrast to the Intel statement the RemoteUpdate block exists for the MAX10, too...
		RU_HW: MAX10_Remote_Update
		GENERIC MAP	(
						Auxiliary_System		=>	Auxiliary_System,
						Ignore_Config_SEL		=>	0
						)
		PORT MAP		(
						CLK						=> CLK_RU,
						nRuRST					=> CLR_n,
						ReloadApplication		=> Locked_Reboot_EN,
						Boot_Errors				=>	RU_Status,
						ApplicationError		=> RU_ApplicationError
						);
		--------------------------------
		-- MAX10 Remote Update Block END
		--------------------------------
	END GENERATE MAX10_Device_Used;
	-------------------
	-- It's a MAX10 END
	-------------------
	
	-----------------------------------
	-- Flash Access based on device END
	-----------------------------------

END ARCHITECTURE Universal;