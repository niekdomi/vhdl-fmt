-- Module Cyclone_V_GX_Package
-- VHDL Package Indel_lib.Indel_Package
--                                                                           
-- Project: General
--                                                                      
-- -------------------------------------------------------------------------- --
-- This Package consists of Cyclone V GX specific constants and functions.    --
-- created by qfu, Indel AG.                                                  --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- History:                                                                   --
-- IB-Code: IG00                                                              --
-- 1.) Initial   version                                                      --
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
--$Rev:: 3753                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2015-04-09 11:13:23 +0200 (Do., 09 Apr 2015)                         $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

PACKAGE Cyclone_V_GX_Package IS
  
   -----------------------
   -- Constant Declaration
   -----------------------
   -- Remot Update constants
   CONSTANT RU_PAR_AD_Trig_C_CV_PKG       : std_logic_vector(2 DOWNTO 0):= "000"; -- Reconfiguration trigger conditions
   CONSTANT RU_PAR_AD_WD_Timeout_C_CV_PKG : std_logic_vector(2 DOWNTO 0):= "010"; -- Watchdog timeout value, width of 12
   CONSTANT RU_PAR_AD_WD_EN_C_CV_PKG      : std_logic_vector(2 DOWNTO 0):= "011"; -- Watchdog Enable, width of 1
   CONSTANT RU_PAR_AD_PG_Sel_C_CV_PKG     : std_logic_vector(2 DOWNTO 0):= "100"; -- Start address of the configuration image (7). Check!!!
   CONSTANT RU_PAR_AD_Mode_C_CV_PKG       : std_logic_vector(2 DOWNTO 0):= "101"; -- Configuration mode (A_nF), width 1
   ---------------------------
   -- Constant Declaration END
   ---------------------------


   -------------------
   -- Type Declaration
   -------------------

   TYPE cyclone_v_rublock_config_bundle_t_a_pkg  IS RECORD
                                                   Reconfig_Trigger_Condition   : std_logic_vector(4 DOWNTO 0);
                                                   Watchdog_Timeout             : std_logic_vector(11 DOWNTO 0);
                                                   Watchdog_EN                  : std_logic;
                                                   Boot_Startaddress            : std_logic_vector(31 DOWNTO 0);
                                                   Configuration_Mode_A_nF      : std_logic;
                                                END RECORD cyclone_v_rublock_config_bundle_t_a_pkg;

-- The reconfiguration trigger conditions are in CV devices are as follows:
--    Bit 4: wdtimer_source => user WDog timout
--    Bit 3: nconfig_source => external assertion of the nCONFIG signal.
--    Bit 2: runconfig_source => configuration reset was triggered from internal logic.
--    Bit 1: nstatus_source => nSTATUS signal externally asserted.
--    Bit 0: crc_error_source => CRC error during application configuration.
-- Watchdog_Timeout:
-- 
-- Boot_Startaddresses (starting with Quartus 13.0):
--    24Bit AD devices Boot_Startaddress(31 DOWNTO 0) <= AD(23 DOWNTO 2) & "00".
--    32Bit AD devices Boot_Startaddress(31 DOWNTO 0) <= AD(31 DOWNTO 2) & "00".
   -----------------------
   -- Type Declaration END
   -----------------------

END PACKAGE Cyclone_V_GX_Package;