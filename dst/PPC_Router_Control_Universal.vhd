-- MODULE PPC Router Control
-- VHDL Architecture Indel_lib.PPC_Router_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --

-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- Combination of the two entities PPC_Control and Router_Control for higher  --
-- flexibility.                                                               --
--                                                                            --
-- -------------------------------------------------------------------------- --
--                                                                            --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Big, little endian mapping:                                                --
-- External:   Sampled:        Rotated:         Adapted:                      --
-- *PPC_A(0) = *             = *              = *                        MS   --
-- *PPC_A(1) = *             = *              = *                             --
-- *PPC_A(2) = *             = *              = *                             --
-- PPC_A(3)  = PPC_AD_IN(3)  = PPC_AD_INT(31) = NOT(SDRAM_Transfer)           --
-- PPC_A(4)  = PPC_AD_IN(4)  = PPC_AD_INT(30) = router.AD(24)                 --
-- PPC_A(5)  = PPC_AD_IN(5)  = PPC_AD_INT(29) = router.AD(23)                 --
-- PPC_A(6)  = PPC_AD_IN(6)  = PPC_AD_INT(28) = router.AD(22)                 --
-- PPC_A(7)  = PPC_AD_IN(7)  = PPC_AD_INT(27) = router.AD(21)                 --
-- PPC_A(8)  = PPC_AD_IN(8)  = PPC_AD_INT(26) = router.AD(20)                 --
-- PPC_A(9)  = PPC_AD_IN(9)  = PPC_AD_INT(25) = router.AD(19)                 --
-- PPC_A(10) = PPC_AD_IN(10) = PPC_AD_INT(24) = router.AD(18)                 --
-- PPC_A(11) = PPC_AD_IN(11) = PPC_AD_INT(23) = router.AD(17)                 --
-- PPC_A(12) = PPC_AD_IN(12) = PPC_AD_INT(22) = router.AD(16)                 --
-- PPC_A(13) = PPC_AD_IN(13) = PPC_AD_INT(21) = router.AD(15)                 --
-- PPC_A(14) = PPC_AD_IN(14) = PPC_AD_INT(20) = router.AD(14)                 --
-- PPC_A(15) = PPC_AD_IN(15) = PPC_AD_INT(19) = router.AD(13)                 --
-- PPC_A(16) = PPC_AD_IN(16) = PPC_AD_INT(18) = router.AD(12)                 --
-- PPC_A(17) = PPC_AD_IN(17) = PPC_AD_INT(17) = router.AD(11)                 --
-- PPC_A(18) = PPC_AD_IN(18) = PPC_AD_INT(16) = router.AD(10)                 --
-- PPC_A(19) = PPC_AD_IN(19) = PPC_AD_INT(15) = router.AD(9)                  --
-- PPC_A(20) = PPC_AD_IN(20) = PPC_AD_INT(14) = router.AD(8)                  --
-- PPC_A(21) = PPC_AD_IN(21) = PPC_AD_INT(13) = router.AD(7)                  --
-- PPC_A(22) = PPC_AD_IN(22) = PPC_AD_INT(12) = router.AD(6)                  --
-- PPC_A(23) = PPC_AD_IN(23) = PPC_AD_INT(11) = router.AD(5)                  --
-- PPC_A(24) = PPC_AD_IN(24) = PPC_AD_INT(10) = router.AD(4)                  --
-- PPC_A(25) = PPC_AD_IN(25) = PPC_AD_INT(9)  = router.AD(3)                  --
-- PPC_A(26) = PPC_AD_IN(26) = PPC_AD_INT(8)  = router.AD(2)                  --
-- PPC_A(27) = PPC_AD_IN(27) = PPC_AD_INT(7)  = router.AD(1)          DW_S(1) --
-- PPC_A(28) = PPC_AD_IN(28) = PPC_AD_INT(6)  = router.AD(0)          DW_S(0) --
-- PPC_A(29) = PPC_AD_IN(29) = PPC_AD_INT(5)  = PPC_Access_Size(2)            --
-- PPC_A(30) = PPC_AD_IN(30) = PPC_AD_INT(4)  = PPC_Access_Size(1)            --
-- PPC_A(31) = PPC_AD_IN(31) = PPC_AD_INT(3)  = PPC_Access_Size(0)       LS   --
--                                                                            --
-- * not connected                                                            --
--                                                                            --
-- DW_S: These two address bits define the order during burst access          --
-- "00"=> DW0, DW1, DW2, DW3, "01"=> DW1, DW2, DW3, DW0, "10"=>  DW2, DW3,    --
-- DW0, DW1, "11"=> DW3, DW0, DW1, DW2                                        --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG01: 23.05.2006:   Initial version. Can be used  for tests with the PLX   --
-- RDK, too.                                                                  --
-- IG02: 28.09.2006:   Changes to solve the burst problem. => subversion      --
-- -------------------------------------------------------------------------- --
-- Remarks:                                                                   --
-- The two processes "Address_Tenure" and "Data_Tenure" are used, because the --
-- address and data transfers are separated from each other. This means a new --
-- transfer request on the address bus can occur before the data bus is free  --
-- to fullfill the request. We control the transfers by the PPC_nTA signal    --
-- and not by the PPC_nAACK line. The worst case timing can be seen if a      --
-- SDRAM burst read access is followed by a write access to a destination in  --
-- the FGPA.                                                                  --
-- -------------------------------------------------------------------------- --


--------------------------------------------------------------------------------
--$Rev:: 1393                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2010-04-07 14:48:19 +0200 (Mi., 07 Apr 2010)                         $
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
-------------------------------
-- Entity library inclusion END
-------------------------------


   -----------------------------------------------------------------------------
   -- Entity declaration
   -----------------------------------------------------------------------------
   ENTITY PPC_Router_Control IS
       PORT       (
                   PPC_CLK                    : IN    std_logic;
                   PPC_CLK_180                : IN    std_logic;
                   PPC_CLR_n                  : IN    std_logic;
                   PPC_nRST                   : IN    std_logic;
                   -- Interface to the PowerPC
                   PPC_nTS                    : IN    std_logic;
                   PPC_nTBST                  : IN    std_logic;
                   PPC_TT1                    : IN    std_logic; -- Transfer type TT0, 2 and 4 omitted. => see PPC documentation
                   PPC_TT3                    : IN    std_logic; -- Transfer type TT0, 2 and 4 omitted. => see PPC documentation
                   PPC_TSIZ                   : IN    std_logic_vector(2 DOWNTO 0);
                   PPC_A                      : IN    std_logic_vector(Return_Upper_F_I_PKG(PPC_AD_Width_C_S_PKG) DOWNTO PPC_Byte_AD_Width_C_S_PKG); -- (31..3)
                   PPC_D                      : INOUT std_logic_vector(Return_Upper_F_I_PKG(PPC_Data_Width_C_S_PKG) DOWNTO 0);
                   PPC_nTA                    : OUT   std_logic;
                   PPC_nAACK                  : OUT   std_logic;
                   -- Interface to the FPGA
                   PPC_Router                 : INOUT router_port_t_s_pkg(Return_Upper_F_I_PKG(Config_Router_Elements_C_S_PKG) DOWNTO 0);
                   -- Interface to the SDRAM Controller
                   SDRAM_AD                   : OUT   std_logic_vector(Return_Upper_F_I_PKG(PPC_AD_Width_C_S_PKG) DOWNTO (PPC_Byte_AD_Width_C_S_PKG + 1));
                   SD_REQ                     : IN    std_logic;
                   SD_AACK                    : IN    std_logic;
                   SD_TA                      : IN    std_logic;
                   SD_TS                      : OUT   std_logic;
                   SD_Gnt                     : OUT   std_logic;
                   SD_TT1                     : OUT   std_logic;
                   SD_TT3                     : OUT   std_logic;
                   SD_nTBST                   : OUT   std_logic;
                   SD_TSIZ                    : OUT   std_logic_vector(2 DOWNTO 0)
                   );
   END ENTITY PPC_Router_Control;
   -----------------------------------------------------------------------------
   -- Entity declaration END
   -----------------------------------------------------------------------------






ARCHITECTURE Universal OF PPC_Router_Control IS
   
   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL FPGA_PPC_Data               : std_logic_vector(Return_Upper_F_I_PKG(PPC_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL PPC_FPGA_Data               : std_logic_vector(Return_Upper_F_I_PKG(PPC_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL PPC_FPGA_Data_EC            : std_logic_vector(Return_Upper_F_I_PKG(PPC_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL PPC_Access_Size             : std_logic_vector(5 DOWNTO 0);
   SIGNAL PPC_Data_Driver_EN          : std_logic_vector(Return_Upper_F_I_PKG(PPC_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL PPC_Data_Driver_EN_INT      : std_logic_vector(Return_Upper_F_I_PKG(PPC_Data_Width_C_S_PKG) DOWNTO 0);

   SIGNAL Router_nAACK                : std_logic;
   SIGNAL Router_nTA                  : std_logic;
   SIGNAL PPC_nTA_INT                 : std_logic;
   SIGNAL SD_Access_Active            : std_logic;
   SIGNAL SD_Delay                    : std_logic;
   SIGNAL SD_TS_INT                   : std_logic;

   -- Sampled input signals (adds a 8 ns delay to the address tenure)
   SIGNAL PPC_nTS_IN                  : std_logic;
   SIGNAL PPC_AD_IN                   : std_logic_vector(Return_Upper_F_I_PKG(PPC_AD_Width_C_S_PKG) DOWNTO PPC_Byte_AD_Width_C_S_PKG); -- Synchronized PPC_A signals
   SIGNAL PPC_nTBST_IN                : std_logic;
   SIGNAL PPC_TSIZ_IN                 : std_logic_vector(2 DOWNTO 0);
   SIGNAL PPC_TT1_IN                  : std_logic;
   SIGNAL PPC_TT3_IN                  : std_logic;
   SIGNAL PPC_BE                      : std_logic_vector(7 DOWNTO 0);

   -- Sampled input signals (the same signals as above, the endianess is changed for the bus signals)
   SIGNAL PPC_nTS_INT                 : std_logic;
   SIGNAL PPC_AD_INT                  : std_logic_vector(Return_Upper_F_I_PKG(PPC_AD_Width_C_S_PKG) DOWNTO PPC_Byte_AD_Width_C_S_PKG); -- Changed endianess.
   SIGNAL PPC_nTBST_INT               : std_logic;
   SIGNAL PPC_TSIZ_INT                : std_logic_vector(2 DOWNTO 0);
   SIGNAL PPC_TT1_INT                 : std_logic;
   SIGNAL PPC_TT3_INT                 : std_logic;
   SIGNAL PPC_BE_INT                  : std_logic_vector(7 DOWNTO 0);

   -- Internal signals
   SIGNAL PPC_Router_INT              : router_port_t_s_pkg(3 DOWNTO 0);

-----------------
-----------------
   SIGNAL Router_Data                 : router_bundle_t_s_pkg;
   SIGNAL Saved_Router_Data           : router_bundle_t_s_pkg;
   SIGNAL Member_Data                 : member_bundle_t_s_pkg;
   SIGNAL Acknowledge_Data            : acknowledge_bundle_t_s_pkg;
   SIGNAL Router_Array                : router_array_t_s_pkg(Return_Upper_F_I_PKG(Config_Router_Elements_C_S_PKG) DOWNTO 0);
   SIGNAL Member_Array                : member_array_t_s_pkg(Return_Upper_F_I_PKG(Config_Router_Elements_C_S_PKG) DOWNTO 0);
   SIGNAL Acknowledge_Array           : acknowledge_array_t_s_pkg(Return_Upper_F_I_PKG(Config_Router_Elements_C_S_PKG) DOWNTO 0);

-----------------
-----------------
   SIGNAL Burst_Order                 : std_logic_vector(1 DOWNTO 0);
   SIGNAL Burst_Vector                : burst_address_t_s_pkg;

   SIGNAL AD_FIFO_WR_Data             : std_logic_vector(7 DOWNTO 0);
   SIGNAL AD_FIFO_WR_REQ              : std_logic;
   SIGNAL AD_FIFO_RD_Data             : std_logic_vector(7 DOWNTO 0);
   SIGNAL AD_FIFO_RD_ACK              : std_logic;
   SIGNAL AD_FIFO_RD_Empty            : std_logic;

   SIGNAL Address_Tenure_Pending      : std_logic;

   SIGNAL Router_Transfer             : std_logic;

   SIGNAL AD_Only_Transfer            : std_logic;
   SIGNAL SDRAM_Transfer              : std_logic;
   SIGNAL Burst_Transfer              : std_logic;
   SIGNAL PPC_WR_nRD_Transfer         : std_logic;
   SIGNAL Delayed_SD_Transfer         : std_logic;

   SIGNAL MM_Select_Space             : std_logic_vector(3 DOWNTO 0);
   SIGNAL MM_RD_Selector              : natural RANGE 0 TO 15;
   SIGNAL MM_WR_Selector              : natural RANGE 0 TO 15;
   SIGNAL Saved_Router_MM_WR_Selector : natural RANGE 0 TO 15;

   SIGNAL Data_ACK_Fast_Lock          : std_logic;
   SIGNAL Burst_EN                    : std_logic;
   SIGNAL Burst_Terminated            : std_logic;
   
   SIGNAL Burst_Termination_Hint      : std_logic;

   SIGNAL PPC_nAACK_INT               : std_logic;
   SIGNAL PPC_nAACK_Control           : std_logic;
   
   SIGNAL Control_nData_On_Bus        : std_logic;
   SIGNAL Lock_nData_On_Bus           : std_logic;
   SIGNAL Burst_Count_Value           : natural RANGE 0 TO 3;
   -------------------------
   -- Signal Declaration END
   -------------------------

   ------------------------
   -- Component Declaration
   ------------------------
   -- Configurable access to bidirectional buses
   COMPONENT BIDIR_Bus_Control
      GENERIC     (
                   BIDIR_Bus_Width      :  IN    natural RANGE 0 TO MAX_Range_C_S_PKG := 2; -- Number of needed bits
                   BIDIR_Bus_Mode       :  IN    natural RANGE 0 TO Defined_BIDIR_Mode_C_S_PKG := 3 -- Do we need registers for the data?
                   );
      PORT        (
                   BIDIR_Bus            :  INOUT std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0); -- Bidirectional bus signal
                   BIDIR_INREG_CLK      :  IN    std_logic; -- GCLK Clock signal for the internal registers (if activated)
                   BIDIR_OUTREG_CLK     :  IN    std_logic; -- GCLK_PLL
                   BIDIR_CLR_n          :  IN    std_logic; -- Low active reset signal
                   BIDIR_Bus_EN         :  IN    std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0); -- Enable signal for the output bus drivers
                   BIDIR_Data_IN        :  IN    std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0); -- Data input signal
                   BIDIR_Data_OUT       :  OUT   std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0) -- Data output signal of the birectional bus.
                   );
   END COMPONENT BIDIR_Bus_Control;


   COMPONENT AD_Tenure_FIFO IS
      GENERIC     (
                   AD_Tenure_FIFO_Depth      : natural RANGE 0 TO 16 := 4;
                   AD_Tenure_FIFO_Data_Width : natural RANGE 0 TO 64 := 8
                   );
      PORT        (
                   PPC_CLK                   : IN    std_logic;
                   PPC_CLR_n                 : IN    std_logic;
                   AD_FIFO_WR_REQ            : IN    std_logic;
                   AD_FIFO_WR_Data           : IN    std_logic_vector(Return_Upper_F_I_PKG(AD_Tenure_FIFO_Data_Width) DOWNTO 0);
                   AD_FIFO_RD_ACK            : IN    std_logic;
                   AD_FIFO_RD_Empty          : OUT   std_logic;
                   AD_FIFO_RD_Data           : OUT   std_logic_vector(Return_Upper_F_I_PKG(AD_Tenure_FIFO_Data_Width) DOWNTO 0)
                   );
   END COMPONENT AD_Tenure_FIFO;


    -- PRAGMA SYNTHESIS_OFF
    FOR ALL : BIDIR_Bus_Control USE ENTITY Indel_lib.BIDIR_Bus_Control;
    FOR ALL : AD_Tenure_FIFO USE ENTITY Indel_lib.AD_Tenure_FIFO;
    -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------

BEGIN

   -- We have to synchronize all the 60x signals of the PPC-Bus
   Synchronize_60x: PROCESS(PPC_CLK, PPC_CLR_n, PPC_nRST)
   BEGIN
      IF ((PPC_CLR_n = '0') OR (PPC_nRST = '0')) THEN
         PPC_nTS_IN <= '1';
         PPC_AD_IN <= (OTHERS => '0');
         PPC_nTBST_IN <= '1';
         PPC_TSIZ_IN <= (OTHERS => '0');
         PPC_TT1_IN <= '0';
         PPC_TT3_IN <= '0';
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
         PPC_nTS_IN <= PPC_nTS;
         PPC_AD_IN <= PPC_A;
         PPC_nTBST_IN <= PPC_nTBST;
         PPC_TSIZ_IN <= PPC_TSIZ;
         PPC_TT1_IN <= PPC_TT1;
         PPC_TT3_IN <= PPC_TT3;
      END IF;
   END PROCESS Synchronize_60x;


   -- Concurrent group 1: assign the sampled signals
   PPC_nTS_INT <= PPC_nTS_IN;
   PPC_AD_INT <= Change_Endianess_Address_F_S_PKG(PPC_AD_IN);
   PPC_nTBST_INT <= PPC_nTBST_IN;
   PPC_TSIZ_INT <= PPC_TSIZ_IN;
   PPC_TT1_INT <= PPC_TT1_IN;
   PPC_TT3_INT <= PPC_TT3_IN;

   -- Concurrent 2 Kind of transfer
   AD_Only_Transfer <= NOT(PPC_TT3_INT); -- Is the data bus needed for the actual transfer?
   Burst_Transfer <= NOT(PPC_nTBST_INT); -- Is it a Burst Transfer or not?
   SDRAM_Transfer <= NOT(PPC_AD_IN(3)); -- See memory map of the card.
   PPC_WR_nRD_Transfer <= NOT(PPC_TT1_INT); -- WR/nRD signal of the PPC-Bus seen from the bus master's point of view (processor).

   -- Concurrent 3: Generation of the internal BE's based on the three LS address bits and the transfer size.
   PPC_Access_Size <= (PPC_TSIZ_INT(0) & PPC_TSIZ_INT(1) & PPC_TSIZ_INT(2) & PPC_AD_INT(5) & PPC_AD_INT(4) & PPC_AD_INT(3));
   

   PPC_Control_BE: PROCESS(PPC_nTBST_INT, PPC_Access_Size)
   BEGIN
      IF (PPC_nTBST_INT = '0') THEN
         PPC_BE <= (OTHERS => '1');
      ELSE
         CASE PPC_Access_Size IS
            -- 1 Byte
            WHEN "001000" =>
               PPC_BE <= "00000001";
            WHEN "001001" =>
               PPC_BE <= "00000010";
            WHEN "001010" =>
               PPC_BE <= "00000100";
            WHEN "001011" =>
               PPC_BE <= "00001000";
            WHEN "001100" =>
               PPC_BE <= "00010000";
            WHEN "001101" =>
               PPC_BE <= "00100000";
            WHEN "001110" =>
               PPC_BE <= "01000000";
            WHEN "001111" =>
               PPC_BE <= "10000000";
            -- 2 Byte
            WHEN "010000" =>
               PPC_BE <= "00000011";
            WHEN "010001" =>
               PPC_BE <= "00000110";
            WHEN "010010" =>
               PPC_BE <= "00001100";
            WHEN "010011" =>
               PPC_BE <= "00011000";
            WHEN "010100" =>
               PPC_BE <= "00110000";
            WHEN "010101" =>
               PPC_BE <= "01100000";
            WHEN "010110" =>
               PPC_BE <= "11000000";
            WHEN "010111" =>
               PPC_BE <= "10000000";
            -- 3 Byte
            WHEN "011000" =>
               PPC_BE <= "00000111";
            WHEN "011001" =>
               PPC_BE <= "00001110";
            WHEN "011010" =>
               PPC_BE <= "00011100";
            WHEN "011011" =>
               PPC_BE <= "00111000";
            WHEN "011100" =>
               PPC_BE <= "01110000";
            WHEN "011101" =>
               PPC_BE <= "11100000";
            WHEN "011110" =>
               PPC_BE <= "11000000";
            WHEN "011111" =>
               PPC_BE <= "10000000";
            -- 4 Byte
            WHEN "100000" =>
               PPC_BE <= "00001111";
            WHEN "100001" =>
               PPC_BE <= "00011110";
            WHEN "100010" =>
               PPC_BE <= "00111100";
            WHEN "100011" =>
               PPC_BE <= "01111000";
            WHEN "100100" =>
               PPC_BE <= "11110000";
            WHEN "100101" =>
               PPC_BE <= "11100000";
            WHEN "100110" =>
               PPC_BE <= "11000000";
            WHEN "100111" =>
               PPC_BE <= "10000000";
            -- 8 Byte
            WHEN "000000" =>
               PPC_BE <= "11111111";
            WHEN "000001" =>
               PPC_BE <= "11111111";
            WHEN "000010" =>
               PPC_BE <= "11111111";
            WHEN "000011" =>
               PPC_BE <= "11111111";
            WHEN "000100" =>
               PPC_BE <= "11111111";
            WHEN "000101" =>
               PPC_BE <= "11111111";
            WHEN "000110" =>
               PPC_BE <= "11111111";
            WHEN "000111" =>
               PPC_BE <= "11111111";
            -- all the other cases
            WHEN OTHERS   =>
               PPC_BE <= "00000000";
         END CASE;
      END IF;
   END PROCESS PPC_Control_BE;



   -- SDRAM Controller 
--   SDRAM_TS: PROCESS(PPC_CLK, PPC_CLR_n, PPC_nRST) --!!--
--   BEGIN --!!--
--      IF ((PPC_CLR_n = '0') OR (PPC_nRST = '0'))THEN --!!--
--         SD_TS_INT <= '0'; --!!--
--         Delayed_SD_Transfer <= '0'; --!!--
--      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN --!!--
--         IF (((PPC_nTS_IN = '0') AND (PPC_TT3_IN = '1') AND (PPC_AD_INT(31) = '0')) OR ((SD_TS_INT = '1') AND (SD_AACK = '0'))) THEN --!!--
--            IF (Router_Transfer = '1') THEN --!!--
--               SD_TS_INT <= '0'; --!!
--               Delayed_SD_Transfer <= '1'; --!!--
--            ELSE --!!--
--               SD_TS_INT <= '1'; --!!--
--               Delayed_SD_Transfer <= '0'; --!!--
--            END IF; --!!--
--         ELSIF (Delayed_SD_Transfer = '1') THEN --!!--
--            IF (Router_Transfer = '0') THEN --!!--
--               SD_TS_INT <= '1'; --!!--
--               Delayed_SD_Transfer <= '0'; --!!--
--            ELSE --!!--
--               SD_TS_INT <= '0'; --!!--
--               Delayed_SD_Transfer <= '1'; --!!--
--            END IF; --!!--
--         ELSE --!!--
--            SD_TS_INT <= '0'; --!!--
--            Delayed_SD_Transfer <= '0'; --!!--
--         END IF; --!!--
--      END IF; --!!--
--   END PROCESS SDRAM_TS; --!!--
   
   
   
----------------------------------------------------------------
----------------------------------------------------------------
-- SDRAM_Controller_Test: Beschleunigen, - 1 Zyklus
-- The SDRAM-Controller transfer starts one cycle earlier.
-- 04.10.2009
----------------------------------------------------------------
----------------------------------------------------------------
   SDRAM_TS: PROCESS(PPC_CLK, PPC_CLR_n, PPC_nRST) --!!--
   BEGIN --!!--
      IF ((PPC_CLR_n = '0') OR (PPC_nRST = '0'))THEN --!!--
         SD_TS_INT <= '0'; --!!--
         Delayed_SD_Transfer <= '0'; --!!--
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN --!!--
         IF (((PPC_nTS = '0') AND (PPC_TT3 = '1') AND (PPC_A(3) = '0')) OR ((SD_TS_INT = '1') AND (SD_AACK = '0'))) THEN --!!--
            IF (Router_Transfer = '1') THEN --!!--
               SD_TS_INT <= '0'; --!!--
               Delayed_SD_Transfer <= '1'; --!!--
            ELSE --!!--
               SD_TS_INT <= '1'; --!!--
               Delayed_SD_Transfer <= '0'; --!!--
            END IF; --!!--
         ELSIF (Delayed_SD_Transfer = '1') THEN --!!--
            IF (Router_Transfer = '0') THEN --!!--
               SD_TS_INT <= '1'; --!!--
               Delayed_SD_Transfer <= '0'; --!!--
            ELSE --!!--
               SD_TS_INT <= '0'; --!!--
               Delayed_SD_Transfer <= '1'; --!!--
            END IF; --!!--
         ELSE --!!--
            SD_TS_INT <= '0'; --!!--
            Delayed_SD_Transfer <= '0'; --!!--
         END IF; --!!--
      END IF; --!!--
   END PROCESS SDRAM_TS; --!!--
----------------------------------------------------------------
----------------------------------------------------------------
   
   
   
   
   
   -- Concurrent group 4
   --SD_Gnt <= SD_REQ; --!!!!-- 06.10.2009
   SD_Gnt <= '1'; --!!!!-- 06.10.2009
   SD_TS <= SD_TS_INT;
   SD_TT1 <= PPC_TT1_IN;
   SD_TT3 <= PPC_TT3_IN;
   SD_nTBST <= PPC_nTBST_IN;
   SD_TSIZ <= PPC_TSIZ_IN;
   SDRAM_AD <= PPC_AD_IN(31 DOWNTO 4);
   

   -- Concurrent 5
   PPC_FPGA_Data_EC <= Change_Endianess_F_S_PKG(PPC_FPGA_Data(63 DOWNTO 0));


   -- Concurrent 6
   PPC_BE_INT <= (PPC_BE(4)&PPC_BE(5)&PPC_BE(6)&PPC_BE(7)&PPC_BE(0)&PPC_BE(1)&PPC_BE(2)&PPC_BE(3));

   -- We have to check the PPC Address Bus:
   -- To foresee the future is not our business. But there is something we know for sure...
   -- After applying a nHRESET the PPC is going to jump to address 0xFFF00100. For this
   -- reason we can try to make this fact working for us. => Will be activated after the first tests with the MRAM controller.
   -- Remark: The lousy "WE_xx_Delay_yy_zz" signals can be removed as soon as the PCI2 SDRAM controller is optimized. For this
   -- reason you can not find an FSM here.


------------------------------
------------------------------
   -- Concurrent 7
   MM_Select_Space <= (PPC_AD_IN(4) & PPC_AD_IN(5) & PPC_AD_IN(6) & PPC_AD_IN(7));

   -- Concurrent 8
   MM_WR_Selector <= NATURAL(TO_INTEGER(UNSIGNED(MM_Select_Space)));
   
   -- Concurrent 9
   MM_RD_Selector <= NATURAL(TO_INTEGER(UNSIGNED(AD_FIFO_RD_Data(3 DOWNTO 0))));

   -- Concurrent 10: Bundle the address FIFO WR data
   AD_FIFO_WR_Data <= (AD_Only_Transfer & Burst_Transfer & SDRAM_Transfer & PPC_WR_nRD_Transfer & MM_Select_Space);

   -- Concurrent 11 Burst Double Word order detection
   Burst_Order <= (PPC_AD_IN(27) & PPC_AD_IN(28));


   -- Concurrent 12: Router port assignment
   Port_Assignment: FOR m IN 0 TO (PPC_Router'length - 1) GENERATE
   BEGIN
      PPC_Router(m).Router_Data <= Router_Array(m);
      PPC_Router(m).Acknowledge_Data <= Acknowledge_Array(m);
      Member_Array(m) <= PPC_Router(m).Member_Data;
   END GENERATE Port_Assignment;

   --------------------------------------------
   -- Burst Processing (part of Address Tenure)
   --------------------------------------------
   Burst_Processing: PROCESS(Burst_Order)
   BEGIN
      CASE Burst_Order IS
         WHEN "00" =>
            Burst_Vector <= ("01","10","11");
         WHEN "01" =>
            Burst_Vector <= ("10","11","00");
         WHEN "10" =>
            Burst_Vector <= ("11","00","01");
         WHEN "11" =>
            Burst_Vector <= ("00","01","10");
         WHEN OTHERS => 
            Burst_Vector <= ("00","00","00");
      END CASE;
   END PROCESS Burst_Processing;
   ------------------------------------------------
   -- Burst Processing (part of Address Tenure) END
   ------------------------------------------------


   -----------------
   -- Address Tenure
   -----------------
      ------------------------
      ---- Used signals:
      --TS                 : std_logic;
      --TBST               : std_logic;
      --Burst_Vector       : burst_address_t_s_pkg;
      --WE                 : std_logic;
      --AD                 : std_logic_vector(Return_Upper_F_I_PKG(Router_AD_Width_C_S_PKG) DOWNTO 0);
      --BE                 : std_logic_vector(Return_Upper_F_I_PKG(Router_BE_Width_C_S_PKG) DOWNTO 0);
      --IRQ                : std_logic_vector(Return_Upper_F_I_PKG(Router_IRQ_Width_C_S_PKG) DOWNTO 0);
      --Router_Entity_Data : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
      --Entity_Router_Data : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
      --Data_Ready         : std_logic;
      ------------------------
   Address_Tenure: PROCESS(PPC_CLK, PPC_CLR_n)
   BEGIN
      IF (PPC_CLR_n = '0') THEN
         Router_Array <= (OTHERS => NA_Router_Bundle_C_S_PKG);
         Saved_Router_Data <= NA_Router_Bundle_C_S_PKG;
         Saved_Router_MM_WR_Selector <= 0;
         Address_Tenure_Pending <= '0';
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
         IF ((PPC_nTS_INT = '0') AND (AD_Only_Transfer = '0') AND (PPC_AD_IN(3) = '1')) THEN
            IF ((MM_WR_Selector = Saved_Router_MM_WR_Selector) AND (Router_Transfer = '1')) THEN
               Address_Tenure_Pending <= '1';
            ELSIF ((Address_Tenure_Pending = '1') AND (Router_Transfer = '0') AND (MM_RD_Selector = Saved_Router_MM_WR_Selector) AND (MM_WR_Selector /= Saved_Router_MM_WR_Selector)) THEN
               Router_Array(Saved_Router_MM_WR_Selector).TS <= '1';
               Router_Array(Saved_Router_MM_WR_Selector).TBST <= Saved_Router_Data.TBST;
               Router_Array(Saved_Router_MM_WR_Selector).WE <= Saved_Router_Data.WE;
               Router_Array(Saved_Router_MM_WR_Selector).Burst_Vector <= Saved_Router_Data.Burst_Vector;
               Router_Array(Saved_Router_MM_WR_Selector).BE <= Saved_Router_Data.BE;
               Router_Array(Saved_Router_MM_WR_Selector).AD <= Saved_Router_Data.AD;
               Router_Array(MM_WR_Selector).TS <= '1';
               Router_Array(MM_WR_Selector).TBST <= Burst_Transfer;
               Router_Array(MM_WR_Selector).WE <= PPC_WR_nRD_Transfer;
               Router_Array(MM_WR_Selector).Burst_Vector <= Burst_Vector;
               Router_Array(MM_WR_Selector).BE <= PPC_BE_INT;
               Router_Array(MM_WR_Selector).AD <= PPC_AD_INT(26 DOWNTO 6);
               Address_Tenure_Pending <= '0';
            ELSE
               Router_Array(MM_WR_Selector).TS <= '1';
               Router_Array(MM_WR_Selector).TBST <= Burst_Transfer;
               Router_Array(MM_WR_Selector).WE <= PPC_WR_nRD_Transfer;
               Router_Array(MM_WR_Selector).Burst_Vector <= Burst_Vector;
               Router_Array(MM_WR_Selector).BE <= PPC_BE_INT;
               Router_Array(MM_WR_Selector).AD <= PPC_AD_INT(26 DOWNTO 6);
               Address_Tenure_Pending <= '0';
            END IF;
            Saved_Router_MM_WR_Selector <= MM_WR_Selector;
            Saved_Router_Data.TS <= '1';
            Saved_Router_Data.TBST <= Burst_Transfer;
            Saved_Router_Data.WE <= PPC_WR_nRD_Transfer;
            Saved_Router_Data.Burst_Vector <= Burst_Vector;
            Saved_Router_Data.BE <= PPC_BE_INT;
            Saved_Router_Data.AD <= PPC_AD_INT(26 DOWNTO 6);
         ELSIF ((Address_Tenure_Pending = '1') AND (Router_Transfer = '0') AND (MM_RD_Selector = Saved_Router_MM_WR_Selector)) THEN
            Router_Array(Saved_Router_MM_WR_Selector).TS <= '1';
            Router_Array(Saved_Router_MM_WR_Selector).TBST <= Saved_Router_Data.TBST;
            Router_Array(Saved_Router_MM_WR_Selector).WE <= Saved_Router_Data.WE;
            Router_Array(Saved_Router_MM_WR_Selector).Burst_Vector <= Saved_Router_Data.Burst_Vector;
            Router_Array(Saved_Router_MM_WR_Selector).BE <= Saved_Router_Data.BE;
            Router_Array(Saved_Router_MM_WR_Selector).AD <= Saved_Router_Data.AD;
            Address_Tenure_Pending <= '0';
         ELSE
            Reset_AD_Router: FOR m IN 0 TO (PPC_Router'length - 1) LOOP -- actually I see no other possibility to initialize the array.
               -- Is it really needed to reset the WE signal?- Timing: This means that the data has to be ready on the bus!!!
               Router_Array(m).TS <= '0';
               Router_Array(m).TBST <= '0';
               Router_Array(m).WE <= '0';
            END LOOP Reset_AD_Router;
         END IF;
         Data_Bus_Assignment: FOR m IN 0 TO Return_Upper_F_I_PKG(Config_Router_Elements_C_S_PKG) LOOP -- all memory space registers are assigned.
            Router_Array(m).Router_Entity_Data <= (PPC_FPGA_Data_EC(31 DOWNTO 0) & PPC_FPGA_Data_EC(63 DOWNTO 32));
         END LOOP Data_Bus_Assignment;
      END IF;
   END PROCESS Address_Tenure;
   ---------------------
   -- Address Tenure END
   ---------------------
   


   -- Address Tenure FIFO WR Request
   AD_FIFO_WR_REQ <= NOT(PPC_nTS_INT); -- We write only to the Address Tenure FIFO when we are not in the reset condition.

   

   -- Address Tenure Acknowledge
   -- With the help of the following lines we can use the Router in "sequential" mode (PPC_nAACK controlled transfers).
   Router_Mode_Together: IF (Router_Mode_C_S_PKG = 0) GENERATE
      SIGNAL PPC_nAACK_Together_INT  : std_logic;
      SIGNAL SD_TA_INT               : std_logic;
   BEGIN
      PPC_nAACK <= (NOT(PPC_nAACK_Together_INT) OR (PPC_nAACK_Control AND NOT(SD_TA_INT)));
      
      Together_nAACK: PROCESS(PPC_CLK, PPC_CLR_n)
      BEGIN
         IF (PPC_CLR_n = '0') THEN
            PPC_nAACK_Together_INT <= '1';
            SD_TA_INT <= '0';
         ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
            PPC_nAACK_Together_INT <= (PPC_nAACK_Control AND NOT(SD_TA_INT));
            SD_TA_INT <= SD_TA;
         END IF;
      END PROCESS Together_nAACK;
   END GENERATE Router_Mode_Together;

   
   -- We can use the Router in  "overlapping" mode, too (PPC_nTA controlled transfers).
   Router_Mode_Separated: IF (Router_Mode_C_S_PKG = 1) GENERATE
      SIGNAL SD_AACK_INT                 : std_logic;
   BEGIN
      -- Concurrent Port assignment
      SD_AACK_INT <= SD_AACK;
      PPC_nAACK <= NOT((NOT(PPC_nTS_INT) AND PPC_AD_IN(3)) OR SD_AACK_INT);
   END GENERATE Router_Mode_Separated;


   ----------------------
   -- Address Tenure FIFO
   ----------------------
   Address_Tenure_FIFO: AD_Tenure_FIFO
      GENERIC MAP    (
                      AD_Tenure_FIFO_Depth      => 5, --- add constant to the package
                      AD_Tenure_FIFO_Data_Width => 8 --- add constant to the package
                      )
      PORT MAP       (
                      PPC_CLK                   => PPC_CLK,
                      PPC_CLR_n                 => PPC_CLR_n,
                      AD_FIFO_WR_REQ            => AD_FIFO_WR_REQ,
                      AD_FIFO_WR_Data           => AD_FIFO_WR_Data,
                      AD_FIFO_RD_ACK            => AD_FIFO_RD_ACK,
                      AD_FIFO_RD_Empty          => AD_FIFO_RD_Empty,
                      AD_FIFO_RD_Data           => AD_FIFO_RD_Data
                      );
   --------------------------
   -- Address Tenure FIFO END
   --------------------------






   -------------------
   -- Transfer Control
   -------------------
   Transfer_Status: PROCESS(PPC_CLK, PPC_CLR_n)
   BEGIN
      IF (PPC_CLR_n = '0') THEN
         Router_Transfer <= '0';
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
	      IF ((Router_Transfer = '0') AND (((PPC_nTS_INT = '0') AND (AD_Only_Transfer = '0') AND (PPC_AD_IN(3) = '1')) OR ((Address_Tenure_Pending = '1')))) THEN
	         Router_Transfer <= '1';
	      ELSIF ((Router_Transfer = '1') AND (((AD_FIFO_RD_ACK = '1') AND (AD_FIFO_RD_Data(5) = '0')) OR (Member_Array(MM_RD_Selector).Data_Ready = '1'))) THEN
	            Router_Transfer <= '0';
         END IF;
      END IF;
   END PROCESS Transfer_Status;
   -----------------------
   -- Transfer Control END
   -----------------------


   -------------------------
   -- Assigning PPC Data Bus
   -------------------------
   Data_Out: PROCESS(Member_Array, MM_RD_Selector)
   BEGIN
      FPGA_PPC_Data <= Change_Endianess_F_S_PKG((Member_Array(MM_RD_Selector).Entity_Router_Data(31 DOWNTO 0) & Member_Array(MM_RD_Selector).Entity_Router_Data(63 DOWNTO 32))); -- Data to PPC
   END PROCESS Data_Out;
   -----------------------------
   -- Assigning PPC Data Bus END
   -----------------------------


   ------------------
   -- Driver Enabling
   ------------------
   Enable_Drivers: PROCESS(PPC_CLK, PPC_CLR_n)
   BEGIN
      IF (PPC_CLR_n = '0') THEN
        PPC_Data_Driver_EN <= (OTHERS => '0');
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
         IF (((NOT(AD_FIFO_RD_Empty) AND NOT(AD_FIFO_RD_Data(7)) AND NOT(AD_FIFO_RD_Data(5)) AND NOT(AD_FIFO_RD_Data(4))) = '1') AND (Member_Array(MM_RD_Selector).Data_Ready = '1')) THEN
            PPC_Data_Driver_EN <= (OTHERS => '1');
         ELSE
            PPC_Data_Driver_EN <= (OTHERS => '0');
         END IF;
      END IF;
   END PROCESS Enable_Drivers;
   ----------------------
   -- Driver Enabling END
   ----------------------


   -- Burst Enable
   Burst_EN <= (NOT(AD_FIFO_RD_Empty) AND AD_FIFO_RD_Data(6) AND NOT(AD_FIFO_RD_ACK));

   ----------------
   -- Burst Counter
   ----------------
   Data_Burst_Counter: PROCESS(PPC_CLK, PPC_CLR_n)
      VARIABLE Burst_Counter : natural RANGE 0 TO 3;
   BEGIN
      IF (PPC_CLR_n = '0') THEN
         Burst_Counter := 0;
         Burst_Terminated <= '0';
         Burst_Termination_Hint <= '0';
         Burst_Count_Value <= 0;
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
         IF (Burst_EN = '1') THEN
            CASE AD_FIFO_RD_Data(4) IS
               WHEN '0' =>
                  IF (((Member_Array(MM_RD_Selector).Data_Ready = '1') AND (AD_FIFO_RD_Data(5) = '0')) OR (SD_TA = '1')) THEN -- AD_FIFO_RD_Data(5) was added to make sure that the FSM does not start to early during a SDRAM access
                     IF (Burst_Counter = 3) THEN
                        Burst_Counter := 0;
                        Burst_Terminated <= '1';
                        Burst_Termination_Hint <= '0';
                     ELSIF (Burst_Counter = 1) THEN
                        Burst_Counter := (Burst_Counter + 1);
                        Burst_Terminated <= '0';
                        Burst_Termination_Hint <= '0';
                     ELSIF (Burst_Counter = 2) THEN
                        Burst_Counter := (Burst_Counter + 1);
                        Burst_Terminated <= '0';
                        Burst_Termination_Hint <= '1';
                     ELSE
                        Burst_Counter := (Burst_Counter + 1);
                        Burst_Terminated <= '0';
                        Burst_Termination_Hint <= '0';
                     END IF;
                  ELSE
                     Burst_Counter := Burst_Counter;
                     Burst_Terminated <= '0';
                     Burst_Termination_Hint <= '0';
                  END IF;
               WHEN '1' =>
                  IF ((AD_FIFO_RD_Data(5) = '0') OR (SD_TA = '1')) THEN
                     IF (Burst_Counter = 1) THEN
                        Burst_Counter := (Burst_Counter + 1);
                        Burst_Terminated <= '0';
                     ELSIF (Burst_Counter = 3) THEN -- (Burst_Counter = 2) -- Delayed "Burst_Terminated" one CLK cycle, so that the "Data_On_Bus signal is generated one cycle later for SDRAM burst WR with following MRAM WR.
                        Burst_Counter := 0;
                        Burst_Terminated <= '1';
                     ELSE
                        Burst_Counter := (Burst_Counter + 1);
                        Burst_Terminated <= '0';
                     END IF;
                     Burst_Termination_Hint <= '0';
                  END IF;
               WHEN OTHERS =>
                  Burst_Counter := 0;
                  Burst_Terminated <= '0';
                  Burst_Termination_Hint <= '0';
            END CASE;
         ELSE
            Burst_Counter := 0;
            Burst_Terminated <= '0';
            Burst_Termination_Hint <= '0';
         END IF;
         Burst_Count_Value <= Burst_Counter;
      END IF;
   END PROCESS Data_Burst_Counter;
   --------------------
   -- Burst Counter END
   --------------------


   --------------------
   -- Ready Acknowledge
   --------------------
   Data_ACK: FOR m IN 0 TO (PPC_Router'length - 1) GENERATE
   BEGIN
      Acknowledge_Array(m).Ready_Acknowledge <= Member_Array(m).Data_Ready WHEN ((m = MM_RD_Selector) AND (AD_FIFO_RD_Data(4) = '0')) ELSE '0';
      Acknowledge_Array(m).Data_On_Bus <= NOT(Control_nData_On_Bus) WHEN (m = MM_RD_Selector) ELSE '0';
   END GENERATE Data_ACK;
   ------------------------
   -- Ready Achnowledge END
   ------------------------

   --------------
   -- Data Tenure
   --------------
   Data_Bus_Tenure: PROCESS(PPC_CLK, PPC_CLR_n)
   BEGIN
      IF (PPC_CLR_n = '0') THEN
         PPC_nTA_INT <= '1';
         PPC_nAACK_Control <= '1';
         AD_FIFO_RD_ACK <= '0';
         Control_nData_On_Bus <= '1';
         Lock_nData_On_Bus <= '0';
      ELSIF (PPC_CLK'EVENT AND PPC_CLK = '1') THEN
         IF ((AD_FIFO_RD_Empty = '0') AND (AD_FIFO_RD_ACK = '0'))THEN
            CASE AD_FIFO_RD_Data(7 DOWNTO 4) IS
               -- Address_Only_Transfers
               WHEN "1000"|"1001"|"1010"|"1011"|"1100"|"1101"|"1110"|"1111" => -- 0x8/0x9/0xA/0xB/0xC/0xD/0xE/0xF
                  AD_FIFO_RD_ACK <= '1';
                  PPC_nTA_INT <= '0';
                  PPC_nAACK_Control <= '0';
                  Control_nData_On_Bus <= '0';
               -- Single Router Write
               WHEN "0001" => -- 0x1
                  IF ((Member_Array(MM_RD_Selector).Write_Delay = '1') AND (Lock_nData_On_Bus = '0')) THEN
                     AD_FIFO_RD_ACK <= '0';
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '0';
                     Lock_nData_On_Bus <= '1';
                  ELSIF ((Member_Array(MM_RD_Selector).Write_Delay = '1') AND (Lock_nData_On_Bus = '1')) THEN
                     AD_FIFO_RD_ACK <= '0';
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                     Lock_nData_On_Bus <= '1';
                  ELSIF ((Member_Array(MM_RD_Selector).Write_Delay = '0') AND (Lock_nData_On_Bus = '1')) THEN
                     AD_FIFO_RD_ACK <= '1';
                     PPC_nTA_INT <= '0';
                     PPC_nAACK_Control <= '0';
                     Control_nData_On_Bus <= '1';
                     Lock_nData_On_Bus <= '0';
                  ELSE
                     AD_FIFO_RD_ACK <= '1';
                     PPC_nTA_INT <= '0';
                     PPC_nAACK_Control <= '0';
                     Control_nData_On_Bus <= '0';
                  END IF;
               -- Burst Router_Write
               WHEN "0101" => -- 0x5
                  IF (Burst_Terminated = '1') THEN
                     AD_FIFO_RD_ACK <= '1';
                  ELSE
                     AD_FIFO_RD_ACK <= '0';
                  END IF;
                  PPC_nTA_INT <= '0';
                  PPC_nAACK_Control <= '0';
                  Control_nData_On_Bus <= '0';
               -- Single Router_Read
               WHEN "0000" => -- 0x0
                  IF (Member_Array(MM_RD_Selector).Data_Ready = '1') THEN
                     AD_FIFO_RD_ACK <= '1';
                     PPC_nTA_INT <= '0';
                     PPC_nAACK_Control <= '0';
                     Control_nData_On_Bus <= '0';
                  ELSE
                     AD_FIFO_RD_ACK <= '0';
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                  END IF;
               -- Burst Router_Read
               WHEN "0100" => -- 0x4
                  IF (Member_Array(MM_RD_Selector).Data_Ready = '1') THEN
                     PPC_nTA_INT <= '0';
                     IF (Member_Array(MM_RD_Selector).Slow_Burst = '1') THEN
                        IF (Burst_Count_Value = 3) THEN 
                           AD_FIFO_RD_ACK <= '1';
                           PPC_nAACK_Control <= '0';
                        ELSE
                           AD_FIFO_RD_ACK <= '0';
                           PPC_nAACK_Control <= '1';
                        END IF;
                     ELSE
                        PPC_nAACK_Control <= '0';
                        Control_nData_On_Bus <= '0';
                        IF (Burst_Termination_Hint = '1') THEN
                           AD_FIFO_RD_ACK <= '1';
                        ELSE
                           AD_FIFO_RD_ACK <= '0';
                        END IF;
                     END IF;
                  ELSE
                     AD_FIFO_RD_ACK <= '0';
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                  END IF;
               -- SDRAM Controller single Data Transfers: RD, WR
               WHEN "0010"|"0011" => -- 0x2/0x3
                  IF (SD_TA = '1') THEN
                     AD_FIFO_RD_ACK <= '1';
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                  ELSE
                     AD_FIFO_RD_ACK <= '0';
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                  END IF;
               -- SDRAM Controller burst Data Transfers: RD, WR ------ Was machen wir in diesen Faellen?
               WHEN "0110"|"0111" => -- 0x6/0x7
                  IF (SD_TA = '1') THEN -- Erst hier mit Zaehlen beginnen?
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                  ELSE
                     PPC_nTA_INT <= '1';
                     PPC_nAACK_Control <= '1';
                     Control_nData_On_Bus <= '1';
                  END IF;
                  IF (Burst_Terminated = '1') THEN
                     AD_FIFO_RD_ACK <= '1';
                  ELSE
                     AD_FIFO_RD_ACK <= '0';
                  END IF;
               WHEN OTHERS =>
                  AD_FIFO_RD_ACK <= '0';
                  PPC_nTA_INT <= '1';
                  PPC_nAACK_Control <= '1';
                  Control_nData_On_Bus <= '1';
                  Lock_nData_On_Bus <= '0';
            END CASE;
         ELSE
            AD_FIFO_RD_ACK <= '0';
            PPC_nTA_INT <= '1';
            PPC_nAACK_Control <= '1';
            Control_nData_On_Bus <= '1';
            Lock_nData_On_Bus <= '0';
         END IF;
      END IF;
   END PROCESS Data_Bus_Tenure;
   ------------------
   -- Data Tenure END
   ------------------

   -- Concurrent y
   PPC_nTA <= (PPC_nTA_INT AND NOT(SD_TA));



   -- We have to control the bidirectional PPC Data Bus signals
   PPC_Data_Bus: BIDIR_Bus_Control
   GENERIC MAP (
                BIDIR_Bus_Width    => PPC_Data_Width_C_S_PKG,
                BIDIR_Bus_Mode     => 3
                )
   PORT MAP    (
                BIDIR_Bus          => PPC_D,
                BIDIR_INREG_CLK    => PPC_CLK,
                BIDIR_OUTREG_CLK   => PPC_CLK,
                BIDIR_CLR_n        => PPC_CLR_n,
                BIDIR_Bus_EN       => PPC_Data_Driver_EN,
                BIDIR_Data_IN      => FPGA_PPC_Data,
                BIDIR_Data_OUT     => PPC_FPGA_Data
                );

END ARCHITECTURE Universal;