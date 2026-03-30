-- Module Arria_GX_Package
-- VHDL Package Indel_lib.Indel_Package
--                                                                           
-- Project: General
--                                                                      
-- -------------------------------------------------------------------------- --
-- This Package consists of Altera Arria GX specific constants anf functions. --
-- created by qfu, Indel AG.                                                  --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- History:                                                                   --
-- IB-Code: IG00                                                              --
-- 1.) Initial   version                                                      --
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
--$Rev:: 1389                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2010-04-07 14:04:42 +0200 (Mi., 07 Apr 2010)                         $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

PACKAGE Arria_GX_Package IS
  
   -----------------------
   -- Constant Declaration
   -----------------------
   -- Remot Update constants
   CONSTANT RU_PAR_AD_Trig_C_A_PKG       : std_logic_vector(2 DOWNTO 0):= "000"; -- Reconfiguration trigger conditions
   CONSTANT RU_PAR_AD_WD_Timeout_C_A_PKG : std_logic_vector(2 DOWNTO 0):= "010"; -- Watchdog timeout value, width of 12
   CONSTANT RU_PAR_AD_WD_EN_C_A_PKG      : std_logic_vector(2 DOWNTO 0):= "011"; -- Watchdog Enable, width of 1
   CONSTANT RU_PAR_AD_PG_Sel_C_A_PKG     : std_logic_vector(2 DOWNTO 0):= "100"; -- Start address of the configuration image (7).
   CONSTANT RU_PAR_AD_Mode_C_A_PKG       : std_logic_vector(2 DOWNTO 0):= "101"; -- Configuration mode (A_nF), width 1
   ---------------------------
   -- Constant Declaration END
   ---------------------------


   -------------------
   -- Type Declaration
   -------------------

   TYPE arria_rublock_config_bundle_t_a_pkg  IS RECORD
                                                   Reconfig_Trigger_Condition   : std_logic_vector(4 DOWNTO 0);
                                                   Watchdog_Timeout             : std_logic_vector(11 DOWNTO 0);
                                                   Watchdog_EN                  : std_logic;
                                                   Boot_Startaddress            : std_logic_vector(6 DOWNTO 0);
                                                   Configuration_Mode_A_nF      : std_logic;
                                                END RECORD arria_rublock_config_bundle_t_a_pkg;

   -----------------------
   -- Type Declaration END
   -----------------------

END PACKAGE Arria_GX_Package;