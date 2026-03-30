-- MODULE SPI Access
-- VHDL Architecture Indel_lib.SPI_Access.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --

-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- 30.01.2008:	Initial version                                                --
--                                                                            --
-- -------------------------------------------------------------------------- --
--                                                                            --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- All the SPI devices with ID 0x20 have a 24 bit address space with width 8. --
-- 128 MBit : AD(23..0)                                                       --
--  64 MBit : AD(22..0)                                                       --
--  32 MBit : AD(21..0)                                                       --
--  16 MBit : AD(20..0)                                                       --
--   8 MBit : AD(19..0)                                                       --
--   4 MBit : AD(18..0)                                                       --
-- -------------------------------------------------------------------------- --


--------------------------------------------------------------------------------
--$Rev:: 1395                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2010-04-07 15:20:19 +0200 (Mi., 07 Apr 2010)                         $
--------------------------------------------------------------------------------

---------------------------
-- Entity library inclusion
---------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.INFO_SAM3_Package_Take2.all;
USE Indel_lib.SPI_Package.all;
-------------------------------
-- Entity library inclusion END
-------------------------------

ENTITY SPI_Access IS
  GENERIC (
           Fast_Read     : IN    boolean;
           Dual_IO       : IN    boolean
           );
  PORT    (
           GCLK          : IN     std_logic;
           CLR_n         : IN     std_logic;
           -- Signals at the PPC side.
           Start_Transfer: IN     std_logic := '0';
           nSuspend      : IN     std_logic; -- Interrupt actual transfer for one with higher priority. ((1))
           Mode          : IN     std_logic_vector(7 DOWNTO 0);
           Words         : IN     natural RANGE 0 TO 65535; -- If number of words = 0 -> read continuously.
           Address       : IN     std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
           DIN           : IN     std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           SPI_Init_Done : OUT    std_logic; -- The SPI bus was synchronized
           Busy          : OUT    std_logic;
           Update        : OUT    std_logic;
           SPI_Wait      : OUT    std_logic;
           Actual_Word   : OUT    natural RANGE 0 TO 65535;
           DOUT          : OUT    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           -- The Clock Control interface
           SPI_CLK       : IN     std_logic; -- Global SPI clock
           CLK_EN        : IN     std_logic; -- Clock enable signal for the Access Controllers
           Run_AC        : IN     std_logic; -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
           Bit_Cnt       : IN     natural RANGE 0 TO 7; -- Which Bit should actually be in work?
           SPI_Stop      : OUT    std_logic; -- Is the actual bus transfer terminated or not?
           -- The Flash Device side.
           SPI_DOUT_DIN  : INOUT  std_logic;
           SPI_nCS       : OUT    std_logic;
           SPI_DIN_DOUT  : INOUT  std_logic
           );
END ENTITY SPI_Access;


-- ((1)): This is possible, because we try to read the address with the highest priority first. Afterwards we
-- execute additional accesses to fill up the ring buffer. Aim: Omitting single word read operations.


ARCHITECTURE Universal OF SPI_Access IS


   -- Debug constants of the old ASMI_Controller
   -----------------------
   -- Constant Declaration
   -----------------------
   --------------------------------
   -- ASMI_Master operational modes
   --------------------------------
   -- Introducing these additional "OPCODES" is made to gain speed. This way round the output of the dual ported RAM can be separated from the ASMI state machine.
   -- In addition the decoding needs no longer 8 Bits.
   CONSTANT  RD           :  std_logic_vector(7 DOWNTO 0) := "00000000";
   CONSTANT  WR           :  std_logic_vector(7 DOWNTO 0) := "00000001";
   CONSTANT  SECTOR_ERASE :  std_logic_vector(7 DOWNTO 0) := "00000010";
   CONSTANT  BLOCK_ERASE  :  std_logic_vector(7 DOWNTO 0) := "00010000";
   CONSTANT  PP           :  std_logic_vector(7 DOWNTO 0) := "00010001";
   CONSTANT  RID          :  std_logic_vector(7 DOWNTO 0) := "00010010";
   CONSTANT  BLER         :  std_logic_vector(7 DOWNTO 0) := "00010011";
   CONSTANT  SEER         :  std_logic_vector(7 DOWNTO 0) := "00010100";
   CONSTANT  BUER         :  std_logic_vector(7 DOWNTO 0) := "00010101";
   CONSTANT  FRD          :  std_logic_vector(7 DOWNTO 0) := "00010110";
   CONSTANT  WR_STATUS    :  std_logic_vector(7 DOWNTO 0) := "00010111";
   CONSTANT  RDSR         :  std_logic_vector(7 DOWNTO 0) := "00000011";
   CONSTANT  WRSR         :  std_logic_vector(7 DOWNTO 0) := "00000100";
   CONSTANT  Bulk_ERASE   :  std_logic_vector(7 DOWNTO 0) := "00000111";
   CONSTANT  FDRD         :  std_logic_vector(7 DOWNTO 0) := "00000101";
   CONSTANT  WREN         :  std_logic_vector(7 DOWNTO 0) := "00000110";
   ------------------------------------
   -- ASMI_Master operational modes END
   ------------------------------------
   
   -- We switch the default read command based on the constant in the "INFO_SAM3_Package_Take2" package.
   -- Actually the "Default_Read_Command is "FASR_READ" or "READ" only. We do not use the dual IO read for the dummy access.
   --CONSTANT Default_Fast_Read_Cmd  :  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(TWO_READ_C_SPI_PKG, FAST_READ_C_SPI_PKG, Dual_IO); --!!!!--
   CONSTANT Default_Read_Command   :  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(FAST_READ_C_SPI_PKG, READ_C_SPI_PKG, Fast_Read); --!!!!--
   --CONSTANT Default_Read_Command   :  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(Default_Fast_Read_Cmd, READ_C_SPI_PKG, Fast_Read); --!!!!--
   --CONSTANT Default_ASMI_Fast_RD_OP:  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(FDRD, FRD, Dual_IO); --!!!!--
   CONSTANT Default_ASMI_Read_OP   :  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(FRD, RD, Fast_Read); --!!!!--
   --CONSTANT Default_ASMI_Read_OP   :  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(Default_ASMI_Fast_RD_OP, RD, Fast_Read);
   ---------------------------
   -- Constant Declaration END
   ---------------------------


   -- Debug signals of the old ASMI_Controller
   SIGNAL ASMI_OPERATION           :  std_logic_vector(7 DOWNTO 0);           
   SIGNAL Seq                      :  natural RANGE 0 TO 15;   
   SIGNAL Byte_EN                  :  std_logic;
   SIGNAL RX_Byte                  :  std_logic_vector(7 DOWNTO 0);   
   SIGNAL Read_Int                 :  std_logic;   
   SIGNAL Write                    :  std_logic;
   SIGNAL Read_Status_Int          :  std_logic;
   SIGNAL ASMI_RD_Data_Int         :  std_logic_vector(7 DOWNTO 0);   --  reuse byte to save LEs
   SIGNAL Temp_Int                 :  std_logic_vector(7 DOWNTO 0);   
   SIGNAL ASMI_Wait_REQ_Int        :  std_logic;

   -- Debug ports of the old ASMI_Controller -------------------------------------------
   SIGNAL ASMI_RD_Data             :  std_logic_vector(7 DOWNTO 0);
   SIGNAL ASMI_Access_State        :  std_logic; -- Burst Mode: Next word ready
   SIGNAL ASMI_Access_Update       :  std_logic;
   SIGNAL Run                      :  std_logic;

   SIGNAL ASMI_CS_n                :  std_logic; -- Chip Select of the Flash device
   SIGNAL ASMI_Burst_EN            :  std_logic := '0'; -- Burst Mode enable
   SIGNAL ASMI_RC_Mode             :  std_logic_vector(7 DOWNTO 0) := (OTHERS => '0'); -- Remote Control OPCODE
   SIGNAL ASMI_RDSR_n              :  std_logic := '1'; -- Read the status register of the Flash
   SIGNAL ASMI_WRST                :  std_logic := '0'; -- Write the status register of the Flash
   SIGNAL ASMI_RD_n                :  std_logic := '1'; -- Enable Read Access to the Flash
   SIGNAL ASMI_WR_n                :  std_logic := '1'; -- Enable Write Access
   SIGNAL ASMI_SE                  :  std_logic := '0'; -- Enable Sector Erase Operation
   SIGNAL ASMI_BE                  :  std_logic := '0'; -- Enable Block Erase Operation
   SIGNAL ASMI_CE                  :  std_logic := '0'; -- Enable Bulk Erase Operation
   SIGNAL ASMI_PP                  :  std_logic := '0'; -- Write Bytes
   SIGNAL ASMI_AD                  :  std_logic_vector(23 DOWNTO 0):= X"FF1237"; -- Flash address input
   SIGNAL ASMI_WR_Data             :  std_logic_vector(7 DOWNTO 0):= X"DD"; -- Write data input
   SIGNAL ASMI_WREN                :  std_logic;
   SIGNAL ASMI_WRSR                :  std_logic;
   SIGNAL ASMI_Block_Erase         :  std_logic;
   SIGNAL ASMI_Sector_Erase        :  std_logic;
   SIGNAL ASMI_Bulk_Erase          :  std_logic;
   SIGNAL ASMI_FRD_n               :  std_logic;
   SIGNAL ASMI_FDRD_n              :  std_logic;
   SIGNAL FRead_Int                :  std_logic;
   SIGNAL FDRead_Int               :  std_logic;

   -- Signals of the Access_Controller
   SIGNAL CS_n                     :  std_logic;   
   SIGNAL CLK_ASMI                 :  std_logic; -- Clock to the SPI flash device f = 31.25 MHz or 62.5 MHz.
   SIGNAL Out_Buf                  :  std_logic_vector(7 DOWNTO 0);   
   SIGNAL Shift_In                 :  std_logic_vector(7 DOWNTO 0);   
   SIGNAL D_Out                    :  std_logic;   
   SIGNAL D_In                     :  std_logic;   
   SIGNAL RX_Byte_Int              :  std_logic_vector(7 DOWNTO 0);   
   SIGNAL Byte_EN_Int              :  std_logic;
   SIGNAL Stop                     :  std_logic;
   SIGNAL Start                    :  std_logic;
   SIGNAL TX_Byte                  :  std_logic_vector(7 DOWNTO 0);
   SIGNAL SPI_Init_Done_Int        :  std_logic;
   SIGNAL SPI_Init_Done_Int_Int    :  std_logic;
   SIGNAL Continuous_Access        :  std_logic;
   SIGNAL Update_INT               :  std_logic;
   SIGNAL Hallo                    :  std_logic;
   SIGNAL Read_ID                  :  std_logic;
   SIGNAL ASMI_RDID_n              :  std_logic;
   SIGNAL RID_Counter              :  natural RANGE 0 TO 2;
   SIGNAL Start_WR_AD              :  std_logic;
   SIGNAL Fast_Read_Lock           :  std_logic;
   SIGNAL Deselect_Counter         :  natural RANGE 0 TO 15; -- Wait-Counter to fullfill the 100ns deselect time of the SPI devices.
   SIGNAL SPI_DIN_DOUT_EN          :  std_logic;
   SIGNAL SPI_DOUT_DIN_EN          :  std_logic;
   SIGNAL TX_Byte_One              :  std_logic_vector(7 DOWNTO 0);
   SIGNAL TX_Byte_Two              :  std_logic_vector(7 DOWNTO 0);
   SIGNAL Dual_Mode_EN             :  std_logic; -- If we use 2 IO lines of the SPI flash
   SIGNAL D_Two_Out                :  std_logic;
   SIGNAL D_One_In                 :  std_logic;
   SIGNAL Out_Buf_Two              :  std_logic_vector(7 DOWNTO 0);
   
   
   
   ------------------------
   -- Component Declaration
   ------------------------
   -- Configurable access to bidirectional signals
   COMPONENT BIDIR_Control
      GENERIC     (
                   BIDIR_Mode           :  IN    natural RANGE 0 TO Defined_BIDIR_Mode_C_S_PKG := 3 -- Do we need registers for the data?
                   );
      PORT        (
                   BIDIR                :  INOUT std_logic; -- Bidirectional signal
                   BIDIR_CLK            :  IN    std_logic; -- Clock signal for the internal registers (if activated)
                   BIDIR_CLR_n          :  IN    std_logic; -- Reset signal
                   BIDIR_EN             :  IN    std_logic; -- Enable signal for the output bus driver
                   BIDIR_Data_IN        :  IN    std_logic; -- Data input signal
                   BIDIR_Data_OUT       :  OUT   std_logic -- Data output signal of the birectional line.
                   );
   END COMPONENT BIDIR_Control;


    -- PRAGMA SYNTHESIS_OFF
    FOR ALL : BIDIR_Control USE ENTITY Indel_lib.BIDIR_Control;
    -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------



BEGIN

   -- We have to generate a signal to indicate that the dummy read access was made.
   Init_Done: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         SPI_Init_Done_Int <= '0';
         SPI_Init_Done_Int_Int <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((ASMI_Access_State = '1') AND (ASMI_Access_Update = '1') AND (SPI_Init_Done_Int = '0')) THEN
            SPI_Init_Done_Int <= '1';
         END IF;
         SPI_Init_Done_Int_Int <= SPI_Init_Done_Int;
      END IF;
   END PROCESS Init_Done;


   -- Concurrent group 0
   SPI_Init_Done <= SPI_Init_Done_Int;
   ASMI_AD <= Address;
   ASMI_WR_Data <= DIN;
   
   
   -- Concurrent 1
   ASMI_RC_Mode <= Mode;
   
   
   SPI_Slow: IF NOT(Fast_Read) GENERATE
   BEGIN
      Save_Data: PROCESS(GCLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            Update_INT <= '0';
            Update <= '0';
         ELSIF (GCLK'EVENT AND GCLK = '1') THEN
            IF ((ASMI_Access_State = '1') AND ((ASMI_Access_Update = '1') OR (Start_WR_AD = '1')) AND (SPI_Init_Done_Int_Int = '1') AND (Update_INT = '0')) THEN
               Update <= '0';
               Update_INT <= '1';
            ELSIF (Update_INT = '1') THEN
               Update <= '1';
               Update_INT <= '0';
            ELSE
               Update <= '0';
               Update_INT <= '0';
            END IF;
         END IF;
      END PROCESS Save_Data;      
   END GENERATE SPI_Slow;
   
   
   SPI_Fast: IF (Fast_Read) GENERATE
   BEGIN
      Save_Data: PROCESS(GCLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            Update_INT <= '0';
         ELSIF (GCLK'EVENT AND GCLK = '1') THEN
            IF (((ASMI_Access_State = '1') OR (Seq = 8)) AND ((ASMI_Access_Update = '1') OR (Start_WR_AD = '1')) AND (SPI_Init_Done_Int_Int = '1') AND (Update_INT = '0')) THEN
               Update_INT <= '1';
            ELSIF (Update_INT = '1') THEN
               Update_INT <= '0';
            ELSE
               Update_INT <= '0';
            END IF;
         END IF;
      END PROCESS Save_Data;

      Update <= Update_INT;
   END GENERATE SPI_Fast;
   

   -- A certain number of words should be read out of the SPI flash. For this reason we have to count the
   -- number of words.
   Count_Words: PROCESS(GCLK, CLR_n)
      VARIABLE Word_Counter        : natural RANGE 0 TO 65535;
   BEGIN
      IF (CLR_n = '0') THEN
         Word_Counter := 0;
         ASMI_CS_n <= '1';
         ASMI_Burst_EN <= '0';
         ASMI_RD_n <= '1';
         Continuous_Access <= '0';
         Actual_Word <= 0;
         ASMI_RDSR_n <= '1';
         ASMI_WRST <= '0';
         ASMI_WR_n <= '1';
         ASMI_SE <= '0';
         ASMI_BE <= '0';
         ASMI_RDID_n <= '1';
         ASMI_WREN <= '0';
         ASMI_CE <= '0';
         ASMI_PP <= '0';
         ASMI_WRSR <= '0';
         ASMI_Block_Erase <= '0';
         ASMI_Sector_Erase <= '0';
         ASMI_Bulk_Erase <= '0';
         ASMI_FRD_n <= '1';
         ASMI_FDRD_n <= '1'; --!!!!--
         Hallo <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Start_Transfer = '1') THEN
            CASE Words IS
               WHEN 0 =>
                  Continuous_Access <= '1';
               WHEN OTHERS =>
                  Continuous_Access <= '0';
            END CASE;
            IF (ASMI_RC_Mode /= Default_Read_Command) THEN
               CASE ASMI_RC_Mode IS
                  WHEN X"88" => -- Write Sequence---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     Word_Counter := 0;
                     ASMI_Burst_EN <= '1';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"02" => -- Write Byte---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '1';
                     Word_Counter := 0;
                     ASMI_Burst_EN <= '1';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"05" => -- READ Status Byte---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '0';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '1';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     Word_Counter := 0;
                     ASMI_WREN <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"9F" => -- READ ID---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '0';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '1';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     Word_Counter := 0;
                     ASMI_WREN <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"06" => -- Write Enable
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '1';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     Word_Counter := 0;
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"01" => -- Write Status Register
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '1';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     Word_Counter := 0;
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"D8" => -- Block Erase
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '1';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     Word_Counter := 0;
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"20" => -- Sector Erase
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '1';
                     ASMI_Bulk_Erase <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     Word_Counter := 0;
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"C7" => -- Bulk Erase
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '1';
                     Word_Counter := 0;
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  When X"81" => -- Write Status Byte Sequence---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '1';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"8F" => -- Bulk Erase Sequence---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '1';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"83" => -- Block Erase Sequence---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '0';
                     ASMI_BE <= '1';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN X"8C" => -- Sector Erase Sequence---
                     ASMI_CS_n <= '0';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '0';
                     ASMI_SE <= '1';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     IF (Words = 1) THEN
                        Hallo <= '1';
                     ELSE
                        Hallo <= '0';
                     END IF;
                  WHEN OTHERS => -- Do Nothing---
                     ASMI_CS_n <= '1';
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                     ASMI_RDSR_n <= '1';
                     ASMI_RDID_n <= '1';
                     ASMI_WRST <= '0';
                     ASMI_WR_n <= '1';
                     ASMI_SE <= '0';
                     ASMI_BE <= '0';
                     ASMI_CE <= '0';
                     ASMI_PP <= '0';
                     ASMI_WREN <= '0';
                     ASMI_WRSR <= '0';
                     ASMI_Block_Erase <= '0';
                     ASMI_Sector_Erase <= '0';
                     ASMI_Bulk_Erase <= '0';
                     Word_Counter := 0;
                     ASMI_Burst_EN <= '1';
               END CASE;
            ELSE
               ASMI_CS_n <= '0';
               IF (Fast_Read) THEN
                  IF (Dual_IO) THEN --!!!!--
                     ASMI_RD_n <= '1'; --!!!!--
                     ASMI_FRD_n <= '1'; --!!!!--
                     ASMI_FDRD_n <= '0'; --!!!!--
                  ELSE --!!!!--
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '0';
                     ASMI_FDRD_n <= '1'; --!!!!--
                  END IF; --!!!!--
               ELSE
                  ASMI_RD_n <= '0';
                  ASMI_FRD_n <= '1';
                  ASMI_FDRD_n <= '1'; --!!!!--
               END IF;
               ASMI_RDSR_n <= '1';
               ASMI_RDID_n <= '1';
               ASMI_WRST <= '0';
               ASMI_WR_n <= '1';
               ASMI_SE <= '0';
               ASMI_BE <= '0';
               ASMI_CE <= '0';
               ASMI_PP <= '0';
               ASMI_WREN <= '0';
               ASMI_WRSR <= '0';
               ASMI_Block_Erase <= '0';
               ASMI_Sector_Erase <= '0';
               ASMI_Bulk_Erase <= '0';
               Word_Counter := 0;
               ASMI_Burst_EN <= '1';
            END IF;
         ELSIF (nSuspend = '0') THEN
            ASMI_CS_n <= '1';
            ASMI_Burst_EN <= '0';
            ASMI_RD_n <= '1';
            ASMI_FRD_n <= '1';
            ASMI_FDRD_n <= '1'; --!!!!--
            Continuous_Access <= '0';
            ASMI_RDSR_n <= '1';
            ASMI_RDID_n <= '1';
            ASMI_WRST <= '0';
            ASMI_WR_n <= '1';
            ASMI_SE <= '0';
            ASMI_BE <= '0';
            ASMI_CE <= '0';
            ASMI_PP <= '0';
            ASMI_WREN <= '0';
            ASMI_WRSR <= '0';
            ASMI_Block_Erase <= '0';
            ASMI_Sector_Erase <= '0';
            ASMI_Bulk_Erase <= '0';
         ELSIF (SPI_Init_Done_Int = '1') THEN
            IF (Continuous_Access = '0') THEN
               IF ((ASMI_Access_State = '1') AND (ASMI_Access_Update = '1') AND (ASMI_CS_n = '0') AND (CLK_EN = '1')) THEN
                  Word_Counter := (Word_Counter + 1);
                  ASMI_CS_n <= '0';
                  ASMI_Burst_EN <= '1';
                  IF (Fast_Read) THEN
                     IF (Dual_IO) THEN --!!!!--
                        ASMI_RD_n <= '1'; --!!!!--
                        ASMI_FRD_n <= '1'; --!!!!--
                        ASMI_FDRD_n <= '0'; --!!!!--
                     ELSE --!!!!--
                        ASMI_RD_n <= '1';
                        ASMI_FRD_n <= '0';
                        ASMI_FDRD_n <= '1'; --!!!!--
                     END IF; --!!!!--
                  ELSE
                     ASMI_RD_n <= '0';
                     ASMI_FRD_n <= '1';
                     ASMI_FDRD_n <= '1'; --!!!!--
                  END IF;
               ELSIF (Hallo = '1') THEN
                  Hallo <= '0';
               ELSIF (Word_Counter  = (Words - 1)) THEN
                  Word_Counter := 0;
                  ASMI_CS_n <= '1';
                  ASMI_Burst_EN <= '0';
                  ASMI_RD_n <= '1';
                  ASMI_FRD_n <= '1';
                  ASMI_FDRD_n <= '1'; --!!!!--
                  ASMI_RDID_n <= '1';
                  ASMI_RDSR_n <= '1';
                  ASMI_WRST <= '0';
                  ASMI_WR_n <= '1';
                  ASMI_SE <= '0';
                  ASMI_BE <= '0';
                  ASMI_CE <= '0';
                  ASMI_PP <= '0';
                  ASMI_WREN <= '0';
                  ASMI_WRSR <= '0';
                  ASMI_Block_Erase <= '0';
                  ASMI_Sector_Erase <= '0';
                  ASMI_Bulk_Erase <= '0';
               END IF;
            ELSE
               Word_Counter := 0;
               ASMI_CS_n <= '0';
               ASMI_Burst_EN <= '1';
               IF (Fast_Read) THEN
                  IF (Dual_IO) THEN --!!!!--
                     ASMI_RD_n <= '1'; --!!!!--
                     ASMI_FRD_n <= '1'; --!!!!--
                     ASMI_FDRD_n <= '0'; --!!!!--
                  ELSE --!!!!--
                     ASMI_RD_n <= '1';
                     ASMI_FRD_n <= '0';
                     ASMI_FDRD_n <= '1'; --!!!!--
                  END IF; --!!!!--
               ELSE
                  ASMI_RD_n <= '0';
                  ASMI_FRD_n <= '1';
                  ASMI_FDRD_n <= '1'; --!!!!--
               END IF;
               ASMI_SE <= '0';
               ASMI_BE <= '0';
               ASMI_CE <= '0';
               ASMI_PP <= '0';
               ASMI_WRSR <= '0';
               ASMI_Block_Erase <= '0';
               ASMI_Sector_Erase <= '0';
               ASMI_Bulk_Erase <= '0';
            END IF;
         END IF;
      Actual_Word <= Word_Counter;
      END IF;
   END PROCESS Count_Words;



   Busy <= NOT(Stop);
   
   
   
   -----------------------------------------
   -- Access per device
   -----------------------------------------

   -- Concurrent 1
   SPI_Wait <= ASMI_Wait_REQ_Int;

   -- Concurrent 2
   ASMI_RD_Data <= ASMI_RD_Data_Int;

   DOUT <= ASMI_RD_Data;

   -- Concurrent 3
   Activate_RD: IF (NOT(Fast_Read)) GENERATE
   BEGIN
      Read_Int <= (NOT(ASMI_CS_n) AND NOT(ASMI_RD_n));
      FRead_Int <= '0';
      FDRead_Int <= '0';
   END GENERATE Activate_RD;
   
   
   -- Concurrent 4
   Read_ID <=(NOT(ASMI_CS_n) AND NOT(ASMI_RDID_n));

   -- Concurrent 5
   Write <= (NOT(ASMI_CS_n) AND NOT(ASMI_WR_n));

   -- Concurrent 6
   Read_Status_Int <= (NOT(ASMI_CS_n) AND NOT(ASMI_RDSR_n));
   
   -- Concurrent 7
   Activate_Fast_RD: IF ((Fast_Read) AND NOT(Dual_IO)) GENERATE
   BEGIN
      FRead_Int <= (NOT(ASMI_CS_n) AND NOT(ASMI_FRD_n));
      Read_Int <= '0';
      FDRead_Int <= '0';
   END GENERATE Activate_Fast_RD;
   
   
   -- Concurrent 8 --!!!!--
   Activate_Fast_Dual_RD: IF ((Fast_Read) AND (Dual_IO)) GENERATE
   BEGIN
      FDRead_Int <= (NOT(ASMI_CS_n) AND NOT(ASMI_FDRD_n)); --!!!!--
      Read_Int <= '0';
      FRead_Int <= '0';
   END GENERATE Activate_Fast_Dual_RD;
   

   -- Concurrent 9
   ASMI_RD_Data_Int <= RX_Byte;
   

   -- Concurrent 10
   WITH ASMI_OPERATION SELECT
   Temp_Int <= PP_C_SPI_PKG WHEN WR,
               WRST_C_SPI_PKG WHEN WRSR,
               SE_C_SPI_PKG WHEN SECTOR_ERASE,
               BE_C_SPI_PKG WHEN BLOCK_ERASE,
               PP_C_SPI_PKG WHEN PP,
               WREN_C_SPI_PKG WHEN WREN,
               CE_C_SPI_PKG WHEN OTHERS;

   -- Concurrent 11
   ASMI_Access_Update <= Byte_EN;

   -- Note: After reset, we must do one dummy access(RD) to sync 
   --       the ASMI(EPCS) device serial sequence.  If you do not initiate this access
   --       then the 1st "real" access can be ignored!!
   ASMI_Master: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Start <= '1';
         Stop <= '0';    
         Seq <= 0;    
         Run <= '1'; --  to start the initial dummy READ
         ASMI_OPERATION <= Default_ASMI_Read_OP;
         ASMI_Wait_REQ_Int <= '1';
         TX_Byte <= Default_Read_Command;
         RID_Counter <= 0;
         Start_WR_AD <= '0';
         Fast_Read_Lock <= '0';
         Deselect_Counter <= 0;
         SPI_DIN_DOUT_EN <= '0'; --!!!!--
         SPI_DOUT_DIN_EN <= '1'; --!!!!--
         TX_Byte_One <= (OTHERS => '0'); --!!!!--
         TX_Byte_Two <= (OTHERS => '0'); --!!!!--
         Dual_Mode_EN <= '0'; --!!!!--
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (CLK_EN = '1') THEN
            CASE Run IS
               WHEN '0' =>
                  ASMI_Wait_REQ_Int <= '1'; --  terminates the last ACCESS...
                  --IF (((ASMI_Wait_REQ_Int AND (Read_Int OR FRead_Int OR Write OR Read_Status_Int OR Read_ID)) = '1') AND (((Bit_Cnt = 0) AND (CLK_ASMI = '0')) OR (Stop = '1'))) THEN --!!!!--
                  IF (((ASMI_Wait_REQ_Int AND (Read_Int OR FRead_Int OR FDRead_Int OR Write OR Read_Status_Int OR Read_ID)) = '1') AND (((Bit_Cnt = 0) AND (CLK_ASMI = '0')) OR (Stop = '1'))) THEN --!!!!--
                     Run <= '1'; --  latch-in & run the sequence..
                     Seq <= 0;    
                     IF (Read_Int = '1') THEN
                        ASMI_OPERATION <= RD;
                     ELSIF (Read_Status_Int = '1') THEN
                        ASMI_OPERATION <= RDSR; --!!!!!!--
                     ELSIF (Read_ID = '1') THEN
                        ASMI_OPERATION <= RID;
                     ELSIF (FRead_Int = '1') THEN
                        ASMI_OPERATION <= FRD;
                     ELSIF (FDRead_Int = '1') THEN --!!!!--
                        ASMI_OPERATION <= FDRD; --!!!!--
                     ELSE
                        IF (ASMI_SE = '1') THEN
                           -- it's a write with SE set!
                           ASMI_OPERATION <= SECTOR_ERASE;
                        ELSIF (ASMI_BE = '1') THEN
                           ASMI_OPERATION <= BLOCK_ERASE;
                        ELSIF (ASMI_CE = '1') THEN
                           -- it's a write with BE set!
                           ASMI_OPERATION <= BULK_ERASE;
                        ELSIF (ASMI_WRST = '1') THEN
                           -- it's a status write access sequence
                           ASMI_OPERATION <= WRSR;
                        ELSIF (ASMI_WRSR = '1') THEN
                           ASMI_OPERATION <= WR_STATUS;
                        ELSIF (ASMI_WREN = '1') THEN
                           ASMI_OPERATION <= WREN;
                        ELSIF (ASMI_PP = '1') THEN
                           ASMI_OPERATION <= PP;
                        ELSIF (ASMI_Block_Erase = '1') THEN
                           ASMI_OPERATION <= BLER;
                        ELSIF (ASMI_Sector_Erase = '1') THEN
                           ASMI_OPERATION <= SEER;
                        ELSIF (ASMI_Bulk_Erase = '1') THEN
                           ASMI_OPERATION <= BUER;
                        ELSE
                           -- if (write)
                           ASMI_OPERATION <= WR;    
                        END IF;
                     END IF;
                  END IF;
                  TX_Byte <= (OTHERS => '0');
                  SPI_DIN_DOUT_EN <= '0'; --!!!!--
                  SPI_DOUT_DIN_EN <= '1'; --!!!!--
               WHEN '1' =>
                  CASE Seq IS
                     WHEN 4 =>
                        TX_Byte <= ASMI_AD(23 DOWNTO 16);
                        TX_Byte_One <= (ASMI_AD(22) & ASMI_AD(20) & ASMI_AD(18) & ASMI_AD(16) & ASMI_AD(14) & ASMI_AD(12) & ASMI_AD(10) & ASMI_AD(8)); --!!!!--
                        TX_Byte_Two <= (ASMI_AD(23) & ASMI_AD(21) & ASMI_AD(19) & ASMI_AD(17) & ASMI_AD(15) & ASMI_AD(13) & ASMI_AD(11) & ASMI_AD(9)); --!!!!--
                     WHEN 5 =>
                        TX_Byte <= ASMI_AD(15 DOWNTO 8);
                     WHEN 6 =>
                        TX_Byte <= ASMI_AD(7 DOWNTO 0);
                        TX_Byte_One <= (ASMI_AD(6) & ASMI_AD(4) & ASMI_AD(2) & ASMI_AD(0) & X"0"); --!!!!--
                        TX_Byte_Two <= (ASMI_AD(7) & ASMI_AD(5) & ASMI_AD(3) & ASMI_AD(1) & X"0"); --!!!!--
                     WHEN 7 =>
                        TX_Byte <= ASMI_WR_Data; -- only valid in WRITE... for READ this is dummy data.
                     WHEN OTHERS =>
                        NULL;
                  END CASE;
                  
                  CASE ASMI_OPERATION IS
                     WHEN RDSR => --!!!!!!--
                        CASE Seq IS
                           WHEN 0 =>
                              Start <= '1';
                              Stop <= '0';
                              TX_Byte <= RDSR_C_SPI_PKG;
                              Seq <= Seq + 1;
                           WHEN 1 =>
                              IF (Byte_EN = '1') THEN
                                 TX_Byte <= (OTHERS => '0');
                                 Seq <= 8;
                              END IF;
                           WHEN OTHERS =>
                              IF (Byte_EN = '1') THEN
                                 Stop <= '1';
                                 Seq <= Seq + 1;
                                 Run <= '0';
                                 ASMI_Wait_REQ_Int <= '0';
                                 TX_Byte <= RX_Byte;
                              END IF;
                        END CASE;
                        SPI_DIN_DOUT_EN <= '0'; --!!!!--
                        SPI_DOUT_DIN_EN <= '1'; --!!!!--
                     WHEN RID =>
                        CASE Seq IS
                           WHEN 0 =>
                              Start <= '1';
                              Stop <= '0';
                              TX_Byte <= RDID_C_SPI_PKG;
                              Seq <= Seq + 1;
                           WHEN 1 =>
                              IF (Byte_EN = '1') THEN
                                 TX_Byte <= (OTHERS => '0');
                                 Seq <= 8;
                                 RID_Counter <= 0;
                              END IF;
                           WHEN OTHERS =>
                              IF (Byte_EN = '1') THEN
                                 IF (RID_Counter = 2) THEN
                                    Stop <= '1';
                                    Seq <= Seq + 1;
                                    Run <= '0';
                                    ASMI_Wait_REQ_Int <= '0';
                                    RID_Counter <= 0;
                                 ELSE
                                    RID_Counter <= (RID_Counter + 1);
                                 END IF;
                                 TX_Byte <= RX_Byte;
                              END IF;
                        END CASE;
                        SPI_DIN_DOUT_EN <= '0'; --!!!!--
                        SPI_DOUT_DIN_EN <= '1'; --!!!!--
                     WHEN RD =>
                        CASE Seq IS
                           WHEN 0 =>
                              Start <= '1';    
                              Stop <= '0';    
                              TX_Byte <= READ_C_SPI_PKG;    
                              Seq <= 4;    
                           WHEN 4 | 5 | 6 |7 =>
                              IF (Byte_EN = '1') THEN
                                 Seq <= Seq + 1;    
                              END IF;
                           WHEN OTHERS  =>
                              IF (Byte_EN = '1') THEN
                                 IF (ASMI_Burst_EN = '0') THEN
                                    Stop <= '1'; 
                                    Seq <= Seq + 1;    
                                    Run <= '0';
                                    ASMI_Wait_REQ_Int <= '0';
                                 END IF;
                                 TX_Byte <= RX_Byte;
                              END IF;
                        END CASE;
                        SPI_DIN_DOUT_EN <= '0'; --!!!!--
                        SPI_DOUT_DIN_EN <= '1'; --!!!!--
                     WHEN FRD =>
                        CASE Seq IS
                           WHEN 0 =>
                              Start <= '1';    
                              Stop <= '0';    
                              TX_Byte <= FAST_READ_C_SPI_PKG;    
                              Seq <= 4;    
                           WHEN 4 | 5 | 6 | 7 =>
                              IF (Byte_EN = '1') THEN
                                 IF ((Fast_Read_Lock = '0') AND (Seq = 7)) THEN
                                    Seq <= Seq;
                                    Fast_Read_Lock <= '1';
                                 ELSE
                                    Seq <= Seq + 1;
                                 END IF; 
                              END IF;
                           WHEN OTHERS  =>
                              IF (Byte_EN = '1') THEN
                                 IF (ASMI_Burst_EN = '0') THEN
                                    Stop <= '1'; 
                                    Seq <= Seq + 1;    
                                    Run <= '0';
                                    ASMI_Wait_REQ_Int <= '0';
                                 END IF;
                                 TX_Byte <= RX_Byte;
                                 Fast_Read_Lock <= '0';
                              END IF;
                        END CASE;
                        SPI_DIN_DOUT_EN <= '0'; --!!!!--
                        SPI_DOUT_DIN_EN <= '1'; --!!!!--
                     WHEN FDRD => --!!!!--
                        CASE Seq IS --!!!!--
                           WHEN 0 => --!!!!--
                              Start <= '1'; --!!!!--
                              Stop <= '0'; --!!!!--
                              TX_Byte <= TWO_READ_C_SPI_PKG; --!!!!--
                              Seq <= 4;
                              SPI_DIN_DOUT_EN <= '0'; --!!!!--
                              SPI_DOUT_DIN_EN <= '1'; --!!!!--
                              Dual_Mode_EN <= '0'; --!!!!--
                           WHEN 4 | 5 | 6 | 7 =>  --!!!!--
                              IF (Byte_EN = '1') THEN --!!!!--
                                 IF (Seq = 7) THEN --!!!!--
                                    SPI_DIN_DOUT_EN <= '0'; --!!!!--
                                    SPI_DOUT_DIN_EN <= '0'; --!!!!--
                                    IF (Fast_Read_Lock = '0') THEN --!!!!--
                                       Seq <= Seq; --!!!!--
                                       Fast_Read_Lock <= '1'; --!!!!--
                                    ELSE --!!!!--
                                       Seq <= (Seq + 1); --!!!!--
                                    END IF; --!!!!--
                                 ELSE --!!!!--
                                    SPI_DIN_DOUT_EN <= '1'; --!!!!--
                                    SPI_DOUT_DIN_EN <= '1'; --!!!!--
                                    Seq <= Seq + 1; --!!!!--
                                 END IF; --!!!!--
                                 Dual_Mode_EN <= '1'; --!!!!--
                              END IF; --!!!!--
                           WHEN OTHERS => --!!!!--
                              IF (Byte_EN = '1') THEN --!!!!--
                                 IF (ASMI_Burst_EN = '0') THEN --!!!!--
                                    Stop <= '1'; --!!!!--
                                    Seq <= Seq + 1; --!!!!--
                                    Run <= '0'; --!!!!--
                                    ASMI_Wait_REQ_Int <= '0'; --!!!!--
                                    SPI_DIN_DOUT_EN <= '0'; --!!!!--
                                    SPI_DOUT_DIN_EN <= '0'; --!!!!--
                                    Dual_Mode_EN <= '0'; --!!!!--
                                 END IF; --!!!!--
                                 Fast_Read_Lock <= '0';
                                 --TX_Byte <= (RX_Byte_Two(3) & RX_Byte_One(3) & RX_Byte_Two(2) & RX_Byte_One(2) & RX_Byte_Two(1) & RX_Byte_One(1) & RX_Byte_Two(0) & RX_Byte_One(0)); --!!!!--
                                 TX_Byte <= RX_Byte; --!!!!--
                              END IF; --!!!!--
                        END CASE; --!!!!--
                     WHEN WR | WRSR | SECTOR_ERASE | BLOCK_ERASE | BULK_ERASE | WREN | PP | BLER | SEER | BUER | WR_STATUS =>
                        CASE Seq IS
                           -- WREN
                           WHEN 0 =>
                              Start <= '1';    
                              Stop <= '0';
                              IF (ASMI_OPERATION = PP) THEN
                                 Seq <= 4;
                                 TX_Byte <= PP_C_SPI_PKG;
                              ELSIF (ASMI_OPERATION = BLER) THEN
                                 Seq <= 4;
                                 TX_Byte <= BE_C_SPI_PKG;
                              ELSIF (ASMI_OPERATION = SEER) THEN
                                 Seq <= 4;
                                 TX_Byte <= SE_C_SPI_PKG;
                              ELSIF (ASMI_OPERATION = BUER) THEN
                                 Seq <= Seq + 1;
                                 TX_Byte <= CE_C_SPI_PKG;
                              ELSIF (ASMI_OPERATION = WR_STATUS) THEN
                                 Seq <= 7;
                                 TX_Byte <= WRST_C_SPI_PKG;
                              ELSE
                                 TX_Byte <= WREN_C_SPI_PKG;    
                                 Seq <= Seq + 1;
                              END IF;
                           WHEN 1 =>
                              IF (Byte_EN = '1') THEN
                                 Stop <= '1';    
                                 IF ((ASMI_OPERATION = WREN) OR (ASMI_OPERATION = BUER)) THEN
                                    Run <= '0'; --!!
                                    ASMI_Wait_REQ_Int <= '0';
                                    Seq <= Seq;
                                 ELSE
                                    Seq <= Seq + 1;
                                 END IF; --!!
                              END IF;
                           WHEN 2 =>
                              IF (Deselect_Counter = 11) THEN
                                 Seq <= Seq + 1;
                                 Deselect_Counter <= 0;
                              ELSE
                                 Deselect_Counter <= (Deselect_Counter + 1);
                              END IF;
                           WHEN 3 =>
                              Start <= '1';    
                              Stop <= '0';    
                              TX_Byte <= Temp_Int;
                              IF (ASMI_OPERATION = BULK_ERASE) THEN
                                 Seq <= 8;
                              ELSIF (ASMI_OPERATION = WRSR) THEN
                                 Seq <= 7;
                              ELSE 
                                 Seq <= (Seq + 1);
                              END IF;   
                           WHEN 4 | 5 | 6 =>
                              IF (Byte_EN = '1') THEN
                                 Seq <= Seq + 1;    
                              END IF;
                           -- PP/SE command
                           WHEN 7 =>
                              CASE ASMI_OPERATION IS
                                 WHEN SECTOR_ERASE | BLOCK_ERASE => -- BLER | SEER -- Testing, 22.06.2009
--------                                 WHEN SECTOR_ERASE | BLOCK_ERASE | BLER | SEER => -- BLER | SEER -- Testing, 22.06.2009
                                    Seq <= Seq + 1; --  do stop now or the erase will abort!!
                                 WHEN BLER | SEER =>
                                    IF (Byte_EN = '1') THEN -- Debug QFU, 01.04.2009
                                       Run <= '0';    
                                       ASMI_Wait_REQ_Int <= '0';
                                       Stop <= '1';
                                       Seq <= Seq;
                                    END IF; -- Debug QFU, 01.04.2009
                                 WHEN OTHERS  =>
                                    IF (Byte_EN = '1') THEN
                                       Seq <= Seq + 1; --  for the WR, need to output the txByte
                                       Start_WR_AD <= '1';
                                    END IF;
                              END CASE;
                           WHEN 8 =>
                              IF (Byte_EN = '1') THEN
                                 IF (ASMI_Burst_EN = '0') THEN
                                    Stop <= '1'; 
                                    IF ((ASMI_OPERATION = PP) OR (ASMI_OPERATION = WR_STATUS)) THEN -- Debug QFU, 13.01.2009
                                       Run <= '0';    
                                       ASMI_Wait_REQ_Int <= '0';
                                    ELSE
                                       Seq <= Seq + 1;
                                    END IF;
                                 ELSE
                                    TX_Byte <= ASMI_WR_Data; -- Debug QFU, 09.01.2008
                                 END IF;
                              END IF;
                              Start_WR_AD <= '0';
                           WHEN 9 =>
                              IF (Deselect_Counter = 10) THEN
                                 Seq <= Seq + 1;
                                 Deselect_Counter <= 0;
                              ELSE
                                 Deselect_Counter <= (Deselect_Counter + 1);
                              END IF;
                           -- Wait for WIP to clear....
                           WHEN 10 => -- Attention: Needed for Winbond/Nexflash devices!!!
                              Seq <= Seq + 1;
                           WHEN 11 =>
                              Start <= '1';    
                              Stop <= '0';    
                              TX_Byte <= RDSR_C_SPI_PKG;    
                              Seq <= Seq + 1;    
                           WHEN 12 =>
                              IF (Byte_EN = '1') THEN
                                 TX_Byte <= (OTHERS => '0'); --  dummy data while we read...
                                 Seq <= Seq + 1;    
                              END IF;
                           WHEN OTHERS  =>
                              IF (Byte_EN = '1') THEN
--                                 IF (RX_Byte(0) = '0') THEN
                                 IF (D_In = '0') THEN
                                    -- WIP bit "cleared"
                                    Stop <= '1';    
                                    Seq <= Seq + 1;    
                                    Run <= '0';    
                                    ASMI_Wait_REQ_Int <= '0';
                                 END IF;
                                 TX_Byte <= RX_Byte;
                              END IF; 
                        END CASE;
                        SPI_DIN_DOUT_EN <= '0'; --!!!!--
                        SPI_DOUT_DIN_EN <= '1'; --!!!!--
                     WHEN OTHERS =>
                        NULL;
                  END CASE;
                --(ASMI_OPERATION)
               WHEN OTHERS =>
                  NULL;
            END CASE;
            --(Run)
         ELSE
            IF (CLK_EN = '0') THEN ---------------------!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!-----------------------------!!!!!!!!!!!!!!!!!!!!-----------
               ASMI_Wait_REQ_Int <= '1'; -- needed, because we are using a CLK_EN
            END IF;
         END IF;
      END IF;
   END PROCESS ASMI_Master;


   -- Output of the ASMI Ready_Control signal 
   ASMI_Access_State_Control: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         ASMI_Access_State <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Seq = 8) THEN
            ASMI_Access_State <= '1';
         ELSE
            ASMI_Access_State <= '0';
         END IF;
      END IF;
   END PROCESS ASMI_Access_State_Control;
   -----------------------------------------
   -- Access per device END
   -----------------------------------------



   ----------------------------------------------------------------
   -- Byte Level Control
   ----------------------------------------------------------------

   -- Concurrent 1
   RX_Byte <= RX_Byte_Int;

   -- Concurrent 2
   Byte_EN <= Byte_EN_Int;


   -- This is the low level state machine which controls the timing of each byte that is transmitted.
   Fast_Access: IF (Fast_Read) GENERATE
   BEGIN
      Dual_IO_Access: IF (Dual_IO) GENERATE --!!!!--
      BEGIN --!!!!--
         Access_Controller: PROCESS(GCLK, CLR_n)
         BEGIN
            IF (CLR_n = '0') THEN   
               CS_n <= '1';    
               Out_Buf <= (OTHERS => '0');
               Out_Buf_Two <= (OTHERS => '0'); --!!!!--
               Byte_EN_Int <= '0';
               Shift_In <= (OTHERS => '0');    
               RX_Byte_Int <= (OTHERS => '0');
            ELSIF (GCLK'EVENT AND GCLK = '1') THEN
               IF (CLK_EN = '1') THEN
                  CASE Run_AC IS
                     WHEN '0' =>
                        IF (Stop = '1') THEN
                           CS_n <= '1';
                        ELSIF (Start = '1') THEN
                           CS_n <= '0';
                           IF (Dual_Mode_EN = '1') THEN --!!!!--
                              Out_Buf <= TX_Byte_One; --!!!!--
                              Out_Buf_Two <= TX_Byte_Two; --!!!!--
                           ELSE --!!!!--
                              Out_Buf <= TX_Byte;
                              Out_Buf_Two <= (OTHERS => '0'); --!!!!--
                           END IF; --!!!!--
                        END IF;
                     WHEN '1' =>
                        IF (Run = '0') THEN --!!!!!!--
                           CS_n <= '1'; --!!!!!!--
                        END IF; --!!!!!!--
                        IF (Bit_Cnt = 0) THEN
                           Byte_EN_Int <= NOT(CLK_ASMI);
                        ELSIF ((Dual_Mode_EN = '1') AND (Bit_Cnt = 4)) THEN --!!!!--
                           Byte_EN_Int <= NOT(CLK_ASMI); --!!!!--
                        ELSE
                           Byte_EN_Int <= '0';
                        END IF;
                        IF (CLK_ASMI = '1') THEN
                           IF (Dual_Mode_EN = '1') THEN --!!!!--
                              Out_Buf <= (Out_Buf(6 DOWNTO 0) & '0'); --!!!!--
                              Out_Buf_Two <= (Out_Buf_Two(6 DOWNTO 0) & '0'); --!!!!--
                              IF ((Bit_Cnt = 0) OR (Bit_Cnt = 4)) THEN --!!!!--
                                 --RX_Byte_Int <= (Shift_In(5 DOWNTO 0) & D_One_In & D_In); --!!!!--
                                 RX_Byte_Int <= (Shift_In(5 DOWNTO 0) & D_In & D_One_In); --!!!!!!--
                              ELSE --!!!!--
                                 --Shift_In <= (Shift_In(5 DOWNTO 0) & D_One_In & D_In); --!!!!--
                                 Shift_In <= (Shift_In(5 DOWNTO 0) & D_In & D_One_In); --!!!!!!--
                              END IF; --!!!!--
                           ELSE --!!!!--
                              Out_Buf <= (Out_Buf(6 DOWNTO 0) & '0'); -- TX shift byte out (msb 1st)
                              Out_Buf_Two <= (OTHERS => '0'); --!!!!--
                              IF (Bit_Cnt = 0) THEN
                                 RX_Byte_Int <= (Shift_In(6 DOWNTO 0) & D_In); -- RX
                              ELSE
                                 Shift_In <= (Shift_In(6 DOWNTO 0) & D_In); -- RX
                              END IF;
                           END IF; --!!!!--
                        END IF;
                     WHEN OTHERS =>
                        NULL;
                  END CASE;
               END IF;
            END IF;
         END PROCESS Access_Controller;
      END GENERATE Dual_IO_Access; --!!!!--

      Single_IO_Access: IF NOT(Dual_IO) GENERATE --!!!!--
      BEGIN --!!!!--
         Access_Controller: PROCESS(GCLK, CLR_n)
         BEGIN
            IF (CLR_n = '0') THEN   
               CS_n <= '1';    
               Out_Buf <= (OTHERS => '0');
               Out_Buf_Two <= (OTHERS => '0'); --!!!!--    
               Byte_EN_Int <= '0';    
               Shift_In <= (OTHERS => '0');    
               RX_Byte_Int <= (OTHERS => '0');
               
            ELSIF (GCLK'EVENT AND GCLK = '1') THEN
               IF (CLK_EN = '1') THEN
                  CASE Run_AC IS
                     WHEN '0' =>
                        IF (Stop = '1') THEN
                           CS_n <= '1';
                        ELSIF (Start = '1') THEN
                           CS_n <= '0';
                           Out_Buf <= TX_Byte;
                        END IF;
                     WHEN '1' =>
                        IF (Bit_Cnt = 0) THEN
                           Byte_EN_Int <= NOT(CLK_ASMI);
                        ELSE
                           Byte_EN_Int <= '0';
                        END IF;
                        IF (CLK_ASMI = '1') THEN
                           Out_Buf <= (Out_Buf(6 DOWNTO 0) & '0'); -- TX shift byte out (msb 1st)
                           IF (Bit_Cnt = 0) THEN
                              RX_Byte_Int <= (Shift_In(6 DOWNTO 0) & D_In); -- RX
                           ELSE
                              Shift_In <= (Shift_In(6 DOWNTO 0) & D_In); -- RX
                           END IF;
                        END IF;
                     WHEN OTHERS =>
                        NULL;
                  END CASE;
               END IF;
               Out_Buf_Two <= (OTHERS => '0'); --!!!!--
            END IF;
         END PROCESS Access_Controller;
      END GENERATE Single_IO_Access; --!!!!--
   END GENERATE Fast_Access;


   Slow_Access: IF NOT(Fast_Read) GENERATE
   BEGIN
   
      -- Concurrent
      Out_Buf_Two <= (OTHERS => '0'); --!!!!--
      
      Access_Controller: PROCESS(GCLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN   
            CS_n <= '1';    
            Out_Buf <= (OTHERS => '0');    
            Byte_EN_Int <= '0';    
            Shift_In <= (OTHERS => '0');    
            RX_Byte_Int <= (OTHERS => '0');
         ELSIF (GCLK'EVENT AND GCLK = '1') THEN
            IF (CLK_EN = '1') THEN
               CASE Run_AC IS
                  WHEN '0' =>
                     IF (Stop = '1') THEN
                        CS_n <= '1';
                     ELSIF (Start = '1') THEN
                        CS_n <= '0';
                        Out_Buf <= TX_Byte;
                     END IF;
                  WHEN '1' =>
                     IF (Bit_Cnt = 0) THEN
                        Byte_EN_Int <= NOT(CLK_ASMI);
                     ELSE
                        Byte_EN_Int <= '0';
                     END IF;
                     IF (CLK_ASMI = '1') THEN
                        Out_Buf <= (Out_Buf(6 DOWNTO 0) & '0'); -- TX shift byte out (msb 1st)
                     END IF;
                  WHEN OTHERS =>
                     NULL;
               END CASE;
            ELSIF (CLK_EN = '0') THEN
               IF (Run_AC = '1') THEN
                  IF (CLK_ASMI = '1') THEN
                     IF (Bit_Cnt = 0) THEN
                        RX_Byte_Int <= (Shift_In(6 DOWNTO 0) & D_In); -- RX
                     ELSE
                        Shift_In <= (Shift_In(6 DOWNTO 0) & D_In); -- RX
                     END IF;
                  END IF;
               END IF;
            END IF;
         END IF;
      END PROCESS Access_Controller;
   END GENERATE Slow_Access;
   
   
  

   -- Concurrent Port Assignments
   D_Out <= Out_Buf(7);
   D_Two_Out <= Out_Buf_Two(7); --!!!!--
   --SPI_DOUT_DIN <= D_Out; --!!
   SPI_nCS <= CS_n;
   CLK_ASMI <= SPI_CLK;
   --D_In <=SPI_DIN_DOUT; --!!
   SPI_Stop <= Stop;
   

   Single_IO_Operation: IF NOT(Dual_IO) GENERATE --!!!!--
   BEGIN --!!!!--
      SPI_OUT: BIDIR_Control --!!
         GENERIC MAP ( --!!
                      BIDIR_Mode           => 0 -- Do we need registers for the data? --!!
                      ) --!!
         PORT MAP    ( --!!
                      BIDIR                => SPI_DOUT_DIN, -- Bidirectional signal --!!
                      BIDIR_CLK            => GCLK, -- Clock signal for the internal registers (if activated) --!!
                      BIDIR_CLR_n          => CLR_n, -- Reset signal --!!
                      BIDIR_EN             => '1', -- Enable signal for the output bus driver --!!
                      BIDIR_Data_IN        => D_Out, -- Data input signal --!!
                      BIDIR_Data_OUT       => OPEN -- Data output signal of the birectional line. --!!
                      ); --!!
                   
                   
      SPI_IN: BIDIR_Control --!!
         GENERIC MAP ( --!!
                      BIDIR_Mode           => 0 -- Do we need registers for the data? --!!
                      ) --!!
         PORT MAP    ( --!!
                      BIDIR                => SPI_DIN_DOUT, -- Bidirectional signal --!!
                      BIDIR_CLK            => GCLK, -- Clock signal for the internal registers (if activated) --!!
                      BIDIR_CLR_n          => CLR_n, -- Reset signal --!!
                      BIDIR_EN             => '0', -- Enable signal for the output bus driver --!!
                      BIDIR_Data_IN        => '0', -- Data input signal --!!
                      BIDIR_Data_OUT       =>  D_In-- Data output signal of the birectional line. --!!
                      ); --!!
   END GENERATE Single_IO_Operation; --!!!!--

   Dual_IO_Operation: IF ((Dual_IO) AND (Fast_Read)) GENERATE --!!!!--
   BEGIN --!!!!--
      SPI_OUT: BIDIR_Control --!!
         GENERIC MAP ( --!!
                      BIDIR_Mode           => 0 -- Do we need registers for the data? --!!
                      ) --!!
         PORT MAP    ( --!!
                      BIDIR                => SPI_DOUT_DIN, -- Bidirectional signal --!!
                      BIDIR_CLK            => GCLK, -- Clock signal for the internal registers (if activated) --!!
                      BIDIR_CLR_n          => CLR_n, -- Reset signal --!!
                      BIDIR_EN             => SPI_DOUT_DIN_EN, -- Enable signal for the output bus driver --!!!!--
                      BIDIR_Data_IN        => D_Out, -- Data input signal --!!
                      BIDIR_Data_OUT       => D_One_In -- Data output signal of the birectional line. --!!!!--
                      ); --!!
                   
                   
      SPI_IN: BIDIR_Control --!!
         GENERIC MAP ( --!!
                      BIDIR_Mode           => 0 -- Do we need registers for the data? --!!
                      ) --!!
         PORT MAP    ( --!!
                      BIDIR                => SPI_DIN_DOUT, -- Bidirectional signal --!!
                      BIDIR_CLK            => GCLK, -- Clock signal for the internal registers (if activated) --!!
                      BIDIR_CLR_n          => CLR_n, -- Reset signal --!!
                      BIDIR_EN             => SPI_DIN_DOUT_EN, -- Enable signal for the output bus driver --!!!!--
                      BIDIR_Data_IN        => D_Two_Out, -- Data input signal --!!
                      BIDIR_Data_OUT       => D_In-- Data output signal of the birectional line. --!!
                      ); --!!
   END GENERATE Dual_IO_Operation; --!!!!--
   
   ----------------------------------------------------------------
   -- Byte Level Control END
   ----------------------------------------------------------------


END ARCHITECTURE Universal;