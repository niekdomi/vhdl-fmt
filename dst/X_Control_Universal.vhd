-- MODULE X Bus Control
-- VHDL Architecture Indel_lib.X_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Used to access the   X bus. There are two main components on the X bus:    --
-- The MRAM and the USB controller                                            --
-- This part of the design needs just to be lean- nothing else.               --
--                                                                            --
--                                                                            --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG00: 23.01.2009:   Initial version, MRAM only                             --
-- IG01: 27.05.2009    Update for the USB controller                          --
-- -------------------------------------------------------------------------- --
-- Remarks:                                                                   --
--                                                                            --
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


--------------------------------------------------------------------------------
-- Entity declaration
--------------------------------------------------------------------------------
ENTITY X_Control IS
   PORT        (
                X_CLK                    : IN    std_logic;
                X_CLR_n                  : IN    std_logic;
                -- MRAM internal signals
                MRAM_nOE                 : IN    std_logic;
                MRAM_nWE                 : IN    std_logic;
                MRAM_AD                  : IN    std_logic_vector(Return_Upper_F_I_PKG(MRAM_AD_Width_C_S_PKG) DOWNTO 0); -- MRAM address input
                MRAM_X_Bus_Data          : IN    std_logic_vector(Return_Upper_F_I_PKG(MRAM_D_Width_C_S_PKG) DOWNTO 0); -- MRAM internal data to the X_Bus
                X_Bus_MRAM_Data          : OUT   std_logic_vector(Return_Upper_F_I_PKG(MRAM_D_Width_C_S_PKG) DOWNTO 0); -- X_Bus data to the internal MRAM Controller
                -- USB internal signals
                USB_nOE                  : IN    std_logic;
                USB_nWE                  : IN    std_logic;
                USB_AD                   : IN    std_logic_vector(Return_Upper_F_I_PKG(USB_AD_Width_C_S_PKG) DOWNTO 0);
                USB_X_Bus_Data           : IN    std_logic_vector(Return_Upper_F_I_PKG(USB_D_Width_C_S_PKG) DOWNTO 0);
                X_Bus_USB_Data           : OUT   std_logic_vector(Return_Upper_F_I_PKG(USB_D_Width_C_S_PKG) DOWNTO 0);
                -- X-Bus signals
                X_nOE                    : OUT   std_logic; -- X output enable
                X_nWE                    : OUT   std_logic; -- X write enable
                X_A                      : OUT   std_logic_vector(Return_Upper_F_I_PKG(X_AD_Width_C_S_PKG) DOWNTO 0); -- X (MRAM, USB) address output signals
                X_D                      : INOUT std_logic_vector(Return_Upper_F_I_PKG(X_D_Width_C_S_PKG) DOWNTO 0) -- X (MRAM, USB) data signals
                );
END ENTITY X_Control;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------




ARCHITECTURE Universal OF X_Control IS

   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL Data_To_X_Bus_INT          : std_logic_vector(Return_Upper_F_I_PKG(X_D_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Data_From_X_Bus_INT        : std_logic_vector(Return_Upper_F_I_PKG(X_D_Width_C_S_PKG) DOWNTO 0);
   SIGNAL X_Bus_EN_INT               : std_logic_vector(Return_Upper_F_I_PKG(X_D_Width_C_S_PKG) DOWNTO 0);
   -------------------------
   -- Signal Declaration END
   -------------------------
   
   
   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT BIDIR_Bus_Control
   GENERIC     (
                BIDIR_Bus_Width      :  IN    natural RANGE 0 TO MAX_Range_C_S_PKG := 2; -- Number of needed bits
                BIDIR_Bus_Function   :  IN    natural RANGE 0 TO Defined_BIDIR_Function_C_S_PKG := 0;
                BIDIR_Bus_Mode       :  IN    natural RANGE 0 TO Defined_BIDIR_Mode_C_S_PKG := 0
                );
   PORT        (
                BIDIR_INREG_CLK      :  IN    std_logic; -- GCLKClock signal for the internal registers (if activated)
                BIDIR_OUTREG_CLK     :  IN    std_logic; -- GCLK_PLL
                BIDIR_CLR_n          :  IN    std_logic; -- Reset signal
                BIDIR_Bus_EN         :  IN    std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0); -- Enable signal for the output bus drivers
                BIDIR_Bus            :  INOUT std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0); -- Bidirectional bus signal
                BIDIR_Data_IN        :  IN    std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0); -- Data input signal
                BIDIR_Data_OUT       :  OUT   std_logic_vector(Return_Upper_F_I_PKG(BIDIR_Bus_Width) DOWNTO 0) -- Data output signal of the birectional bus.
                );
   END COMPONENT BIDIR_Bus_Control;
   
   FOR ALL : BIDIR_Bus_Control USE ENTITY Indel_lib.BIDIR_Bus_Control;
   ----------------------------
   -- Component Declaration END
   ----------------------------


BEGIN


   -- Debug Concurrent USB 0, 27052009
   X_Bus_USB_Data <= (OTHERS => '0');
   -- Debug Concurrent USB 0, 27052009 END


   -- Concurrent 0
   X_nOE <= MRAM_nOE;
   X_nWE <= MRAM_nWE;
   
   -- Concurrent 1
   X_A <= MRAM_AD;
   
   -- Concurrent 2
   Data_To_X_Bus_INT(15 DOWNTO 0) <= MRAM_X_Bus_Data;
   Data_To_X_Bus_INT(31 DOWNTO 16) <= (OTHERS => '0');
   X_Bus_MRAM_Data <= Data_From_X_Bus_INT(15 DOWNTO 0);
   
   -- Concurrent 3
   X_Bus_EN_INT <= (OTHERS => '1') WHEN (MRAM_nOE = '1') ELSE (OTHERS => '0');
   


   X_Bus_Data: BIDIR_Bus_Control
   GENERIC MAP (
                BIDIR_Bus_Width      => X_D_Width_C_S_PKG,
                BIDIR_Bus_Function   => 0,
                BIDIR_Bus_Mode       => 0
                )
   PORT MAP    (
                BIDIR_INREG_CLK      => X_CLK,
                BIDIR_OUTREG_CLK     => X_CLK,
                BIDIR_CLR_n          => X_CLR_n,
                BIDIR_Bus_EN         => X_Bus_EN_INT, -- Enable signal for the output bus drivers
                BIDIR_Bus            => X_D, -- Bidirectional bus signal
                BIDIR_Data_IN        => Data_To_X_Bus_INT, -- Data input signal
                BIDIR_Data_OUT       => Data_From_X_Bus_INT -- Data output signal of the birectional bus.
                );

END ARCHITECTURE Universal;