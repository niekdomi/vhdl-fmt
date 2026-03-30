-- MODULE PCI Control
-- VHDL Architecture Indel_lib.PCI_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Hilscher module interface- the bidirectional signals get unidirectional    --
-- outside of the entity based on the fact, that the bit numbers have to be   --
-- assigned first.                                                            --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --

--                                                                            --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- To Do: If there is no 64 Bit access needed, we can reduce the accesses to  --
--        down to the number of the really needed accesses.                   --
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

ENTITY PCI_Control IS
  PORT (
        GCLK                      : IN    std_logic; -- 125MHz
        CLR_n                     : IN    std_logic;
        PPC_Dock                  : INOUT router_dock_t_s_pkg;
        PCI_CLK                   : OUT   std_logic; -- out
        PCI_nFRAME                : OUT   std_logic; -- out
        PCI_nBE                   : OUT   std_logic_vector(3 DOWNTO 0); -- out
        PCI_nDEVSEL               : IN    std_logic; -- in
        PCI_nIRDY                 : OUT   std_logic; -- out
        PCI_nTRDY                 : IN    std_logic; -- in
        PCI_nINTA                 : IN    std_logic; -- in
        PCI_nINTA                 : IN    std_logic; -- interrupt line really needed in this entity?
        PCI_AD_EN                 : OUT   std_logic_vector(Return_Upper_F_I_PKG(PCI_AD_Width_C_S_PKG) DOWNTO 0); -- Hilscher address output
        PCI_Controller_AD         : IN    std_logic_vector(Return_Upper_F_I_PKG(PCI_AD_Width_C_S_PKG) DOWNTO 0); -- Hilscher in out data signals
        Controller_PCI_AD         : OUT   std_logic_vector(Return_Upper_F_I_PKG(PCI_AD_Width_C_S_PKG) DOWNTO 0) -- Hilscher out data signals
        );
END ENTITY PCI_Control;


ARCHITECTURE Universal OF Measurement_Control IS

   -------------------
   -- Type Declaration
   -------------------
   TYPE STATE_TYPE IS
      (
       Init,
       Start,
       Mode_Write0,
       Mode_Write1,
       Mode_Write2,
       Mode_Write3,
       Mode_Write4,
       Mode_Write5,
       Mode_Write6,
       Mode_Write7,
       Mode_Read0,
       Mode_Read1,
       Mode_Read2,
       Mode_Read3,
       Mode_Read4,
       Mode_Read5,
       Mode_Read6,
       Mode_Read7,
       Mode_Pause0,
       Mode_Pause1,
       Mode_Pause2,
       Mode_Pause3,
       Mode_Pause4,
       Mode_Pause5,
       Stop
       );
   -----------------------
   -- Type Declaration END
   -----------------------
   
   
   ---------------------------
   -- State Vector Declaration
   ---------------------------
   ATTRIBUTE state_vector : string;
   ATTRIBUTE state_vector OF Universal : ARCHITECTURE IS "current_state";
   -------------------------------
   -- State Vector Declaration END
   -------------------------------
   
   
   -----------------------
   -- Constant Declaration
   -----------------------
   CONSTANT PCI_Command_MEM_RD    : std_logic_vector(3 DOWNTO 0):= "0110";
   CONSTANT PCI_Command_MEM_WR    : std_logic_vector(3 DOWNTO 0):= "0111"; 
   ---------------------------
   -- Constant Declaration END
   ---------------------------
   
   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL current_state           : STATE_TYPE;
   SIGNAL next_state              : STATE_TYPE;
   SIGNAL Low_AD                  : std_logic_vector(2 DOWNTO 0);

   SIGNAL Sample_Counter          : natural RANGE 0 TO 15;
   SIGNAL Member_Data             : std_logic_vector(63 DOWNTO 0);
   SIGNAL Data_Ready              : std_logic;
   SIGNAL Sample_Data             : std_logic;
   SIGNAL Wait_For_Data_On_Bus    : std_logic;
   
   
   ---------------
   ---------------
   SIGNAL PCI_CLK_Int             : std_logic;
   SIGNAL PCI_INTA_Int            : std_logic;
   ---------------
   ---------------
    
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

  
   

   
--   PPC_Hilscher_BE <= PPC_Dock.Router_Data.BE; -- Needed for ModelSim, otherwise the entity can not be simulated.
   
   
   -- Concurrent 1
   PPC_Dock.Member_Data.IRQ <= "00000000";
   --PPC_Dock.Member_Data.IRQ <= ("0000000" & PCI_INTA_Int); -- Assign the synchronized PCI nINTA line.
--   PPC_Dock.Member_Data.Write_Delay <= '0';
--   PPC_Dock.Member_Data.Entity_Router_Data <= (OTHERS => '0'); --Member_Data;
--   PPC_Dock.Member_Data.Data_Ready <= '1'; --Data_Ready;
   PPC_Dock.Member_Data.Slow_Burst <= '0'; --'1';
   
   
   
   PCI_CLK <= PCI_CLK_Int;
   
  
   
   
   
   ------------------------
   ------------------------
   
   Sample_PCI_nINTA: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         PCI_INTA_Int <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         PCI_INTA_Int <= NOT(PCI_nINTA);
      END IF;
   END PROCESS Sample_PCI_nINTA;
   
   
   PCI_Module_Interface: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         current_state <= Init;
         PCI_CLK_Int <= '0';
         PCI_nFRAME <= '1';
         PCI_nBE <= (OTHERS => '0');
         Controller_PCI_AD <= (OTHERS => '0');
         PCI_nIRDY <= '1';
         PCI_AD_EN <= (OTHERS => '0');
         PPC_Dock.Member_Data.Data_Ready <= '0';
         PPC_Dock.Member_Data.Write_Delay <= '0';
         PPC_Dock.Member_Data.Entity_Router_Data <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         current_state <= next_state;
         CASE current_state IS
         WHEN Init =>
            PCI_CLK_Int <= '0';
            PCI_nFRAME <= '1';
            PCI_nBE <= (OTHERS => '0');
            Controller_PCI_AD <= (OTHERS => '0');
            PCI_nIRDY <= '1';
            PPC_Dock.Member_Data.Write_Delay <= '0';
         WHEN Start =>
            PCI_nFRAME <= '1';
            PPC_Dock.Member_Data.Data_Ready <= '0';
            IF (PPC_Dock.Router_Data.TS = '1') THEN
               IF (PPC_Dock.Router_Data.WE = '1') THEN
                  PCI_nBE <= PCI_Command_MEM_WR;
                  PPC_Dock.Member_Data.Write_Delay <= '1';
               ELSE
                  PCI_nBE <= PCI_Command_MEM_RD;
               END IF;
               PCI_nFRAME <= '0';
               PCI_CLK_Int <= '0';
               PCI_AD_EN <= (OTHERS => '1');
               Controller_PCI_AD <= ("00000000000" & PPC_Dock.Router_Data.AD);
            ELSE
               PCI_nFRAME <= '1';
               --PCI_CLK_Int <= '1';
               PCI_CLK_Int <= NOT(PCI_CLK_Int);
               PCI_AD_EN <= (OTHERS => '0');
               Controller_PCI_AD <= (OTHERS => '0');
            END IF;
         WHEN Mode_Write0 =>
            PCI_CLK_Int <= '1';
            PCI_nFRAME <= '0';
         WHEN Mode_Write1 =>
            PCI_CLK_Int <= '0';
            PCI_nFRAME <= '1';
            PCI_nIRDY <= '0';
            PCI_nBE <= (NOT(PPC_Dock.Router_Data.BE(3)) & NOT(PPC_Dock.Router_Data.BE(2)) & NOT(PPC_Dock.Router_Data.BE(1)) & NOT(PPC_Dock.Router_Data.BE(0)));
            Controller_PCI_AD <= PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 0);
         WHEN Mode_Write2 =>
            PCI_CLK_Int <= '1';
         WHEN Mode_Write3 =>
            PCI_CLK_Int <= '0';
            PCI_nFRAME <= '1';
            PCI_nIRDY <= '1';
            PCI_AD_EN <= (OTHERS => '0');
            Controller_PCI_AD <= (OTHERS => '0');
            PPC_Dock.Member_Data.Write_Delay <= '0';
         WHEN Mode_Write4 =>
            PCI_CLK_Int <= '1';
         WHEN Mode_Write5 =>
            PCI_CLK_Int <= '0';
         WHEN Mode_Write6 =>
            PCI_CLK_Int <= '1';
         WHEN Mode_Write7 =>
            PCI_CLK_Int <= '0';
         WHEN Mode_Read0 =>
            PCI_CLK_Int <= '1';
            PCI_nFRAME <= '0';
         WHEN Mode_Read1 =>
            PCI_CLK_Int <= '0';
            PCI_nIRDY <= '0';
            PCI_nBE <= (OTHERS => '0');
            PCI_AD_EN <= (OTHERS => '0');
         WHEN Mode_Read2 =>
            PCI_CLK_Int <= '1';
         WHEN Mode_Read3 =>
            PCI_CLK_Int <= '0';
         WHEN Mode_Read4 =>
            PCI_CLK_Int <= '1';
            PPC_Dock.Member_Data.Entity_Router_Data <= (PCI_Controller_AD & PCI_Controller_AD);
            PPC_Dock.Member_Data.Data_Ready <= '1';
         WHEN Mode_Read5 =>
            PCI_CLK_Int <= '0';
            PCI_nFRAME <= '1';
            PCI_nIRDY <= '1';
            PPC_Dock.Member_Data.Data_Ready <= '0';
         WHEN Mode_Read6 =>
            PCI_CLK_Int <= '1';
         WHEN Mode_Read7 =>
            PCI_CLK_Int <= '0';
         WHEN Stop =>
            PCI_CLK_Int <= '0';
            PCI_nFRAME <= '1';
         WHEN OTHERS =>
            PCI_CLK_Int <= '0';
            PCI_nFRAME <= '1';
         END CASE;
      END IF;
   END PROCESS PCI_Module_Interface;
   
   
   Choose_Next_State: PROCESS(current_state, PPC_Dock.Router_Data.TS, PPC_Dock.Router_Data.WE)
   BEGIN
      CASE current_state IS
      WHEN Init =>
         next_state <= Start;
      WHEN Start =>
         IF (PPC_Dock.Router_Data.TS = '1') THEN
            IF (PPC_Dock.Router_Data.WE = '1') THEN
               next_state <= Mode_Write0;
            ELSE
               next_state <= Mode_Read0;
            END IF;
         ELSE
            next_state <= Start;
         END IF;
      WHEN Mode_Write0 =>
         next_state <= Mode_Write1;
      WHEN Mode_Write1 =>
         next_state <= Mode_Write2;
      WHEN Mode_Write2 =>
         next_state <= Mode_Write3;
      WHEN Mode_Write3 =>
         next_state <= Mode_Write4;
      WHEN Mode_Write4 =>
         next_state <= Mode_Write5;
      WHEN Mode_Write5 =>
         next_state <= Mode_Write6;
      WHEN Mode_Write6 =>
         next_state <= Mode_Write7;
      WHEN Mode_Write7 =>
         next_state <= Start;
      WHEN Mode_Read0 =>
         next_state <= Mode_Read1;
      WHEN Mode_Read1 =>
         next_state <= Mode_Read2;
      WHEN Mode_Read2 =>
         next_state <= Mode_Read3;
      WHEN Mode_Read3 =>
         next_state <= Mode_Read4;
      WHEN Mode_Read4 =>
         next_state <= Mode_Read5;
      WHEN Mode_Read5 =>
         next_state <= Mode_Read6;
      WHEN Mode_Read6 =>
         next_state <= Mode_Read7;
      WHEN Mode_Read7 =>
         next_state <= Start;
         next_state <= Start;
      WHEN Stop =>
         next_state <= Start;
      WHEN OTHERS =>
         next_state <= Start;
      END CASE;
   END PROCESS Choose_Next_State;


END ARCHITECTURE Universal;