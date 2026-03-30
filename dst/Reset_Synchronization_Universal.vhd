-- MODULE Reset Synchronization
-- VHDL Architecture Indel_lib.Reset_Synchronization.Universal
--
-- InfoLink, GinLink, INFO-PCIe Copyright (c): INDEL AG
--
-- Project:   INFO-PCIe
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- We have to synchronize the external asynchronous reset signal.             --
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- IG01: 17.07.2006:   Initial version.                                       --
--                                                                            --
--	08.04.2008-le: - add to lib. esart
--------------------------------------------------------------------------------
--$Rev:: 387                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2008-04-08 13:36:31 +0200 (Di., 08 Apr 2008)                         $
--------------------------------------------------------------------------------



---------------------------
-- Entity library inclusion
---------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
-------------------------------
-- Entity library inclusion END
-------------------------------




--------------------------------------------------------------------------------
-- Entity declaration
--------------------------------------------------------------------------------
ENTITY Reset_Synchronization is
   PORT      (
              SCLK          : IN   std_logic;
              ACLR_n        : IN   std_logic;
              CLR_n         : OUT  std_logic;
              CLR           : OUT  std_logic
              );
END ENTITY Reset_Synchronization;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------

ARCHITECTURE Universal OF Reset_Synchronization IS
   SIGNAL ACLR_n_INT       : std_logic;
   SIGNAL ACLR_n_180_INT   : std_logic;
BEGIN
   Synchronize: PROCESS(SCLK)
   BEGIN
      IF (SCLK'EVENT AND SCLK = '0') THEN
         ACLR_n_INT <= ACLR_n;
         CLR_n <= ACLR_n_INT;
			CLR <= NOT(ACLR_n_INT);
      END IF;
   END PROCESS Synchronize;
END ARCHITECTURE Universal;