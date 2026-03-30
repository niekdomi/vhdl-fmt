-- MODULE xxx Control
-- VHDL Architecture Indel_lib.xxx_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Template for internal bus members
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --

--                                                                            --
-- -------------------------------------------------------------------------- --
--                                                                            --
--                                                                            --
-- -------------------------------------------------------------------------- --
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

ENTITY Template_Member IS
   PORT    (
            GCLK                    : IN    std_logic;
            CLR_n                   : IN    std_logic;
            PPC_Dock                : INOUT router_dock_t_s_pkg
            );
END ENTITY Template_Member;


ARCHITECTURE Universal OF Template_Member IS
   CONSTANT Delay                  : natural := 1;
   CONSTANT Memory_Width           : natural := 10;
   SIGNAL   Burst_Vector           : burst_address_t_s_pkg;
   SIGNAL   Burst_Counter          : natural RANGE 0 TO 2;
   SIGNAL   Burst_OnGoing          : std_logic;
   SIGNAL   EN_Delay_Counter       : std_logic;
   SIGNAL   Wait_For_Data_On_Bus   : std_logic;
   SIGNAL   Wait_For_Burst_WR      : std_logic;
   SIGNAL   WE_INT                 : std_logic;
   SIGNAL   WE_INT_INT             : std_logic;
   SIGNAL   WE_INT_INT_INT         : std_logic;
   SIGNAL   WE_Burst_INT           : std_logic;
   SIGNAL   Internal_Address       : std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   

   COMPONENT Test_RAM
      PORT   (
              address                      : IN  std_logic_vector(9 DOWNTO 0);
              byteena                      : IN  std_logic_vector(7 DOWNTO 0);
              clock                        : IN  std_logic;
              data                         : IN  std_logic_vector(63 DOWNTO 0);
              wren                         : IN  std_logic;
              q                            : OUT std_logic_vector(63 DOWNTO 0)
              );
   END COMPONENT Test_RAM;


BEGIN

   -- It is simple to support bursting in the member entity. The following code has just to be added.

   Burst_Controller: PROCESS(GCLK, CLR_n)
   BEGIN
       IF (CLR_n = '0') THEN
           Burst_Vector <= (OTHERS => (OTHERS => '0'));
           Burst_OnGoing <= '0';
           Wait_For_Burst_WR <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
           IF (PPC_Dock.Router_Data.TS = '1') THEN
              CASE PPC_Dock.Router_Data.TBST IS
                 WHEN '1' =>
                    IF (PPC_Dock.Router_Data.WE = '1') THEN
                       Burst_OnGoing <= '0';
                       Wait_For_Burst_WR <= '1';
                    ELSE
                       Burst_OnGoing <= '1';
                       Wait_For_Burst_WR <= '0';
                    END IF;
                    Burst_Vector <= PPC_Dock.Router_Data.Burst_Vector;
                 WHEN '0' =>
                    Burst_OnGoing <= '0';
                    Burst_Vector <= (OTHERS => (OTHERS => '0'));
                    Wait_For_Burst_WR <= '0';
                 WHEN OTHERS => 
                    Burst_OnGoing <= '0';
                    Burst_Vector <= (OTHERS => (OTHERS => '0'));
                    Wait_For_Burst_WR <= '0';
              END CASE;
              Burst_Counter <= 0;
           ELSIF (Burst_OnGoing = '1') THEN
              IF (Burst_Counter = 2) THEN
                 Burst_OnGoing <= '0';
              ELSE
                 Burst_Counter <= (Burst_Counter + 1);
              END IF;
           ELSIF (Wait_For_Burst_WR = '1') THEN
              Wait_For_Burst_WR <= '0';
              Burst_OnGoing <= '1';
           END IF;
        END IF;
    END PROCESS Burst_Controller;


   -- Data Ready Delay
   Delay_Count: PROCESS(GCLK, CLR_n)
      VARIABLE Counter : natural;
   BEGIN
       IF (CLR_n = '0') THEN
           EN_Delay_Counter <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
          IF  (((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) OR ((Burst_OnGoing = '1') AND (WE_INT = '0'))) THEN
             EN_Delay_Counter <= '1';
          ELSIF (PPC_Dock.Acknowledge_Data.Ready_Acknowledge = '1') THEN
             EN_Delay_Counter <= '0';
          END IF;
       END IF;
   END PROCESS Delay_Count;

   PPC_Dock.Member_Data.Data_Ready <= EN_Delay_Counter;



   -- Concurrent add IRQ's:
   PPC_Dock.Member_Data.IRQ <= "00000000";

   
   -- Internal Write Enable
   WR_Enable: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Wait_For_Data_On_Bus <= '0';
         -- WE_INT <= '0'; -- Debug QFU, 11112008
         WE_INT_INT <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((PPC_Dock.Router_Data.WE = '1') AND (PPC_Dock.Router_Data.TS = '1')) THEN
            Wait_For_Data_On_Bus <= '1';
         ELSIF (Wait_For_Data_On_Bus = '1') THEN
            IF (PPC_Dock.Acknowledge_Data.Data_On_Bus = '1') THEN
               WE_INT_INT <= '1';
               Wait_For_Data_On_Bus <= '0';
            ELSE
               WE_INT_INT <= '0';
               Wait_For_Data_On_Bus <= '1';
            END IF;
         ELSIF ((WE_INT = '1') AND (Burst_OnGoing = '1')) THEN
            WE_INT_INT <= '1';
         ELSE
            WE_INT_INT <= '0';
         END IF;
      END IF;
   END PROCESS WR_Enable;


   -- Concurrent
   WE_INT <= WE_INT_INT; -- Debug QFU, 11112008

   Tschau: Test_RAM
       PORT  MAP (
                  address                      => Internal_Address,
                  byteena                      => PPC_Dock.Router_Data.BE,
                  clock                        => GCLK,
                  data                         => PPC_Dock.Router_Data.Router_Entity_Data,
                  wren                         => WE_INT,
                  q                            => PPC_Dock.Member_Data.Entity_Router_Data
                  );

   Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);
   Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);
END ARCHITECTURE Universal;