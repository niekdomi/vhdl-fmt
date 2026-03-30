
-- MODULE General WatchDog Counter
-- VHDL Architecture Indel_lib.General_WatchDog_Counter.Universal
--
-- InfoLink, GinLink, INFO-PCIe Copyright (c): INDEL AG
--
-- Project:   INFO-PCIe
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- WatchDog Counter for the external part mounted on the board.               --
-- f_FPGA_WDI = 14*f_SCLK                                                     --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG01: 30.06.2006:   Initial version. Can be used  for tests with the PLX   --
-- RDK, too.                                                                  --
-- -------------------------------------------------------------------------- --



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
ENTITY General_WatchDog_Counter IS
   PORT   ( 
           SCLK        : IN     std_logic;
           CLR_n       : IN     std_logic;
           FPGA_WDI    : OUT    std_logic
           );
END General_WatchDog_Counter;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------



ARCHITECTURE Universal OF General_WatchDog_Counter IS
   -------------------
   -- Type Declaration
   -------------------
   TYPE state_type IS (
                       Start,
                       s1,
                       s2,
                       s3,
                       s4,
                       s5,
                       s6,
                       s7,
                       s8,
                       s9,
                       s10,
                       s11,
                       s12,
                       s0
                       );
   -----------------------
   -- Type Declaration END
   -----------------------

   ------------------------
   -- Attribute Declaration
   ------------------------
   ATTRIBUTE state_vector              : string;
   ATTRIBUTE state_vector OF Universal : ARCHITECTURE IS "Current_State";
   ----------------------------
   -- Attribute Declaration END
   ----------------------------


   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL Current_State      : state_type ;
   SIGNAL Next_State         : state_type ;

   SIGNAL WatchDog_cld       : std_logic  ;
   -------------------------
   -- Signal Declaration END
   -------------------------

BEGIN

   Clocked: PROCESS(SCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Current_State <= Start;
         WatchDog_cld <= '0';
      ELSIF (SCLK'EVENT AND SCLK = '1') THEN
         Current_State <= Next_State;
         CASE Current_State IS
            WHEN Start =>
               WatchDog_cld <= '0';
            WHEN s0 =>
               WatchDog_cld <= '1';
            WHEN OTHERS =>
               NULL;
         END CASE;
      END IF;
   END PROCESS clocked;



   Nextstate: PROCESS(Current_State)
   BEGIN
      CASE Current_State IS
         WHEN Start =>
            next_state <= s1;
         WHEN s1 =>
            Next_State <= s2;
         WHEN s2 =>
            Next_State <= s3;
         WHEN s3 =>
            Next_State <= s4;
         WHEN s4 =>
            Next_State <= s5;
         WHEN s5 =>
            Next_State <= s6;
         WHEN s6 =>
            Next_State <= s0;
         WHEN s7 =>
            Next_State <= s8;
         WHEN s8 =>
            Next_State <= s9;
         WHEN s9 =>
            Next_State <= s10;
         WHEN s10 =>
            Next_State <= s11;
         WHEN s11 =>
            Next_State <= s12;
         WHEN s12 =>
            Next_State <= Start;
         WHEN s0 =>
            Next_State <= s7;
         WHEN OTHERS =>
            Next_State <= Start;
         END CASE;
   END PROCESS Nextstate;

   -- Concurrent 1
   FPGA_WDI <= WatchDog_cld;

END ARCHITECTURE Universal;