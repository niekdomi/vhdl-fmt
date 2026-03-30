-- MODULE Hilscher Control
-- VHDL Architecture Indel_lib.Hilscher_Control.Universal
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

ENTITY Hilscher_Control IS
  PORT (
        GCLK                      : IN    std_logic; -- 125MHz
        CLR_n                     : IN    std_logic;
        PPC_Dock                  : INOUT router_dock_t_s_pkg;
        Hilscher_nINT             : IN    std_logic; -- interrupt line really needed in this entity?
        Hilscher_nBusy            : IN    std_logic; -- used to insert wait states.
        Hilscher_nCS              : OUT   std_logic; -- Hilscher nCS
        Hilscher_nRD              : OUT   std_logic; -- Hilscher nRead
        Hilscher_nWR              : OUT   std_logic; -- Hilscher nWrite
        Hilscher_nRES             : OUT   std_logic; -- Hilscher nReset: has to be low for more than 10us!
        Hilscher_nBHE             : OUT   std_logic; -- Hilscher not Bus High Enable
        PCI_AD_EN                 : OUT   std_logic_vector(Return_Upper_F_I_PKG(PCI_AD_Width_C_S_PKG) DOWNTO 0); -- Hilscher address output
        PCI_Hilscher_AD           : IN    std_logic_vector(Return_Upper_F_I_PKG(PCI_AD_Width_C_S_PKG) DOWNTO 0); -- Hilscher in data signals
        Hilscher_PCI_AD           : OUT   std_logic_vector(Return_Upper_F_I_PKG(PCI_AD_Width_C_S_PKG) DOWNTO 0) -- Hilscher out data signals
        );
END ENTITY Hilscher_Control;


ARCHITECTURE Universal OF Hilscher_Control IS

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
       Mode_Read0,
       Mode_Read1,
       Mode_Read2,
       Mode_Read3,
       Mode_Read4,
       Mode_Read5,
       Mode_Read6,
       Mode_Pause0,
       Mode_Pause1,
       Mode_Pause2,
       Mode_Pause3,
       Mode_Pause4,
       Mode_Pause5,
       s0,
       s1,
       s2,
       s3,
       s4,
       s5,
       s6,
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
   
   
   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL current_state           : STATE_TYPE;
   SIGNAL next_state              : STATE_TYPE;
   SIGNAL Hilscher_AD             : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_AD_Width_C_S_PKG) DOWNTO 0); -- 14 Bit
   SIGNAL Hilscher_D_EN           : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_D_Width_C_S_PKG) DOWNTO 0); -- 16 Bit
   SIGNAL Hilscher_D_IN           : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_D_Width_C_S_PKG) DOWNTO 0); -- 16 Bit
   SIGNAL Hilscher_D_OUT          : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_D_Width_C_S_PKG) DOWNTO 0); -- 16 Bit
   SIGNAL Low_AD                  : std_logic_vector(2 DOWNTO 0);
   SIGNAL Access_Waiting          : std_logic;
   SIGNAL Hilscher_AD_Int         : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_AD_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Hilscher_nRD_Int        : std_logic;
   SIGNAL Hilscher_nWR_Int        : std_logic;
   SIGNAL Hilscher_D_EN_Int       : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_D_Width_C_S_PKG) DOWNTO 0);
   SIGNAL PPC_BE_Int              : std_logic_vector(Return_Upper_F_I_PKG(Router_BE_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Hilscher_PPC_Data       : std_logic_vector(Return_Upper_F_I_PKG(Hilscher_D_Width_C_S_PKG) DOWNTO 0); -- 16 Bit, 8 Bit used
   SIGNAL Hilscher_INT_Int        : std_logic;
   SIGNAL Hilscher_nBusy_Int      : std_logic;
   SIGNAL Hilscher_nBHE_Int       : std_logic;
   SIGNAL Hilscher_nRES_INT       : std_logic_vector(0 DOWNTO 0);
   -------------------------
   -- Signal Declaration END
   -------------------------
   
   
   
   --------------
   -- Debug Block
   --------------
    COMPONENT PPC_nRST_Source
       PORT   (
               probe                        : IN  std_logic_vector(0 DOWNTO 0);
               source_clk                   : IN  std_logic;
               source                       : OUT std_logic_vector(0 DOWNTO 0)
               );
    END COMPONENT PPC_nRST_Source;
   ------------------
   -- Debug Block END
   ------------------
    
    FOR ALL : PPC_nRST_Source USE ENTITY Indel_lib.PPC_nRST_Source;


BEGIN

   -- Mapping of The Hilscher signals to the PCI lines:
   --         PCI_AD(31):- not used for option Hilscher
   --         PCI_AD(30):- not used for option Hilscher
   --         PCI_AD(29):Hilscher_D(14)
   --         PCI_AD(28):Hilscher_D(15)
   --         PCI_AD(27):Hilscher_D(12) 
   --         PCI_AD(26):Hilscher_D(13)
   --         PCI_AD(25):Hilscher_D(10) 
   --         PCI_AD(24):Hilscher_D(11)
   --         PCI_AD(23):Hilscher_D(8)
   --         PCI_AD(22):Hilscher_D(9)
   --         PCI_AD(21):Hilscher_AD(12) 
   --         PCI_AD(20):Hilscher_AD(13) 
   --         PCI_AD(19):Hilscher_AD(10) 
   --         PCI_AD(18):Hilscher_AD(11) 
   --         PCI_AD(17):Hilscher_AD(8) 
   --         PCI_AD(16):Hilscher_AD(9) 
   --         PCI_AD(15):Hilscher_AD(6) 
   --         PCI_AD(14):Hilscher_AD(7)  
   --         PCI_AD(13):Hilscher_AD(4) 
   --         PCI_AD(12):Hilscher_AD(5) 
   --         PCI_AD(11):Hilscher_AD(2) 
   --         PCI_AD(10):Hilscher_AD(3) 
   --         PCI_AD(9):Hilscher_AD(0) 
   --         PCI_AD(8):Hilscher_AD(1) 
   --         PCI_AD(7):Hilscher_D(6) 
   --         PCI_AD(6):Hilscher_D(7)
   --         PCI_AD(5):Hilscher_D(4) 
   --         PCI_AD(4):Hilscher_D(5)
   --         PCI_AD(3):Hilscher_D(2)
   --         PCI_AD(2):Hilscher_D(3) 
   --         PCI_AD(1):Hilscher_D(0) 
   --         PCI_AD(0):Hilscher_D(1)   
   
   

   -- Concurrent 0
   -- We have to assign the EN signals to the appropriate PCI_AD line
   PCI_AD_EN(31 DOWNTO 30) <= (OTHERS => '0');
   PCI_AD_EN(29 DOWNTO 22) <= (Hilscher_D_EN(14) & Hilscher_D_EN(15) & Hilscher_D_EN(12) & Hilscher_D_EN(13) & Hilscher_D_EN(10) & Hilscher_D_EN(11) & Hilscher_D_EN(8) & Hilscher_D_EN(9));
   --PCI_AD_EN(29 DOWNTO 22) <= (OTHERS => '0');
   PCI_AD_EN(21 DOWNTO 8) <=  (OTHERS => '1'); -- the Hilscher address outputs are always enabled.
   PCI_AD_EN(7 DOWNTO 0) <= (Hilscher_D_EN(6) & Hilscher_D_EN(7) & Hilscher_D_EN(4) & Hilscher_D_EN(5) & Hilscher_D_EN(2) & Hilscher_D_EN(3) & Hilscher_D_EN(0) & Hilscher_D_EN(1));
   
   -- The same has to be done with our address lines Hilscher_AD(13 DOWNTO 0)...
   Hilscher_PCI_AD(21 DOWNTO 8) <= (Hilscher_AD(12) & Hilscher_AD(13) & Hilscher_AD(10) & Hilscher_AD(11) & Hilscher_AD(8) & Hilscher_AD(9) & Hilscher_AD(6) & Hilscher_AD(7) & Hilscher_AD(4) & Hilscher_AD(5) & Hilscher_AD(2) & Hilscher_AD(3) & Hilscher_AD(0) & Hilscher_AD(1));
   
   -- And for the Hilscher data output lines...
   Hilscher_PCI_AD(29 DOWNTO 22) <= (Hilscher_D_OUT(14) & Hilscher_D_OUT(15) & Hilscher_D_OUT(12) & Hilscher_D_OUT(13) & Hilscher_D_OUT(10) & Hilscher_D_OUT(11) & Hilscher_D_OUT(8) & Hilscher_D_OUT(9));
   Hilscher_PCI_AD(7 DOWNTO 0) <= (Hilscher_D_OUT(6) & Hilscher_D_OUT(7) & Hilscher_D_OUT(4) & Hilscher_D_OUT(5) & Hilscher_D_OUT(2) & Hilscher_D_OUT(3) & Hilscher_D_OUT(0) & Hilscher_D_OUT(1));
   
   -- Not used outputs...
   Hilscher_PCI_AD(31 DOWNTO 30) <= (OTHERS => '0');
   
   -- The input data Hilscher_D_IN(15 DOWNTO 0)...
   Hilscher_D_IN(15 DOWNTO 8) <= (PCI_Hilscher_AD(28) & PCI_Hilscher_AD(29) & PCI_Hilscher_AD(26) & PCI_Hilscher_AD(27) & PCI_Hilscher_AD(24) & PCI_Hilscher_AD(25) & PCI_Hilscher_AD(22) & PCI_Hilscher_AD(23));
   Hilscher_D_IN(7 DOWNTO 0) <= (PCI_Hilscher_AD(6) & PCI_Hilscher_AD(7) & PCI_Hilscher_AD(4) & PCI_Hilscher_AD(5) & PCI_Hilscher_AD(2) & PCI_Hilscher_AD(3) & PCI_Hilscher_AD(0) & PCI_Hilscher_AD(1));
   
   
   -------------------
   -- Debug 11.03.2009
   -------------------
   -- Debug Hilscher Booting
--   Test_It: PPC_nRST_Source
--       PORT MAP  (
--               probe           => Hilscher_nRES_INT,
--               source_clk      => GCLK,
--               source          => Hilscher_nRES_INT
--               );
               
               
   Hilscher_nRES_INT(0) <= '1';
   Hilscher_nRES <= Hilscher_nRES_INT(0);

   --Hilscher_nBHE <= '0'; -- '1'
   -----------------------
   -- Debug 11.03.2009 END
   -----------------------
   
   -- Concurrent 1
   PPC_Dock.Member_Data.IRQ <= ("0000000" & Hilscher_INT_Int);
   --PPC_Dock.Member_Data.Entity_Router_Data <= (Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(7 DOWNTO 0));
   PPC_Dock.Member_Data.Entity_Router_Data <= (Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(15 DOWNTO 8) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(15 DOWNTO 8) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(15 DOWNTO 8) & Hilscher_PPC_Data(7 DOWNTO 0) & Hilscher_PPC_Data(15 DOWNTO 8));
   PPC_Dock.Member_Data.Slow_Burst <= '0'; --'1';
   
   
   
   Sample_Hilscher_nINT: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Hilscher_INT_Int <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         Hilscher_INT_Int <= NOT(Hilscher_nINT);
      END IF;
   END PROCESS Sample_Hilscher_nINT;
   
   
   Sample_Hilscher_nBusy: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Hilscher_nBusy_Int <= '1';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         Hilscher_nBusy_Int <= Hilscher_nBusy;
      END IF;
   END PROCESS Sample_Hilscher_nBusy;
       
   
   
   -- Address decoding for the 8 Bit Hilscher interface.
   Create_Address_Lines: PROCESS(PPC_Dock.Router_Data.BE)
   BEGIN
      CASE PPC_Dock.Router_Data.BE IS
         WHEN X"08" =>
            Low_AD <= "000";
            Hilscher_nBHE_Int <= '1'; --
         WHEN X"04" =>
            Low_AD <= "001";
            Hilscher_nBHE_Int <= '0'; --
         WHEN X"02" =>
            Low_AD <= "010";
            Hilscher_nBHE_Int <= '1'; --
         WHEN X"01" =>
            Low_AD <= "011";
            Hilscher_nBHE_Int <= '0'; --
         WHEN X"80" =>
            Low_AD <= "100";
            Hilscher_nBHE_Int <= '1'; --
         WHEN X"40" =>
            Low_AD <= "101";
            Hilscher_nBHE_Int <= '0'; --
         WHEN X"20" =>
            Low_AD <= "110";
            Hilscher_nBHE_Int <= '1'; --
         WHEN X"10" =>
            Low_AD <= "111";
            Hilscher_nBHE_Int <= '0'; --
         WHEN X"0C" => --
            Hilscher_nBHE_Int <= '0'; --
            Low_AD <= "000"; --
         WHEN X"03" => --
            Low_AD <= "010"; --
            Hilscher_nBHE_Int <= '0'; --
         WHEN X"C0" => --
            Low_AD <= "100"; --
            Hilscher_nBHE_Int <= '0'; --
         WHEN X"30" => --
            Low_AD <= "110"; --
            Hilscher_nBHE_Int <= '0'; --
         WHEN OTHERS =>
            Low_AD <= "000";
            Hilscher_nBHE_Int <= '1'; --
      END CASE;
   END PROCESS Create_Address_Lines;
   



   -- This lines is used during simulation with ModelSim, based on the fact that the simulator can not work with a case statement releated to a record element.
   --   Low_AD <= "000";


   ------------------------------------------------------------------------------------------------------
   -- Hilscher interface FSM: The deselect time needs to be streched to more than 41.8ns ("Pause Modes").
   ------------------------------------------------------------------------------------------------------
   Hilscher_Module_Interface: PROCESS(GCLK, CLR_n)
      VARIABLE   Actual_Access_Time : natural RANGE 0 TO 31;
   BEGIN
      IF (CLR_n = '0') THEN
         current_state <= Init;
         Hilscher_nCS <= '1';
         Hilscher_nRD <= '1';
         Hilscher_nWR <= '1';
         Hilscher_AD <= (OTHERS => '0');
         Hilscher_AD_Int <= (OTHERS => '0');
         Hilscher_D_EN <= X"0000"; 
         Hilscher_D_OUT <= X"0000";
         Hilscher_PPC_Data <= X"0000";
         PPC_Dock.Member_Data.Data_Ready <= '0';
         Actual_Access_Time := 0;
         Access_Waiting <= '0';
         Hilscher_nRD_Int <= '1';
         Hilscher_nWR_Int <= '1';
         Hilscher_D_EN_Int <= X"0000";
         PPC_Dock.Member_Data.Write_Delay <= '0';
         PPC_BE_Int <= (OTHERS => '0');
         --Hilscher_nBHE <= '1'; --
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Actual_Access_Time = 27) THEN
            Actual_Access_Time := 0;
            PPC_Dock.Member_Data.Data_Ready <= '1';
            current_state <= Start;
            Hilscher_PPC_Data <= X"0000";--
            Access_Waiting <= '0';
            PPC_Dock.Member_Data.Write_Delay <= '0';
            Hilscher_D_EN_Int <= X"0000"; --
            Hilscher_D_EN <= X"0000"; --
         ELSE
            current_state <= next_state;
            CASE current_state IS
            WHEN Init =>
               Hilscher_nCS <= '1';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '1';
               --
               Hilscher_AD <= (OTHERS => '0');
               Hilscher_AD_Int <= (OTHERS => '0');
               Hilscher_D_EN <= X"0000"; 
               Hilscher_D_OUT <= X"0000";
               Hilscher_PPC_Data <= X"0000";
               PPC_Dock.Member_Data.Data_Ready <= '0';
               Actual_Access_Time := 0;
               Access_Waiting <= '0';
               Hilscher_nRD_Int <= '1';
               Hilscher_nWR_Int <= '1';
               Hilscher_D_EN_Int <= X"0000";
               PPC_Dock.Member_Data.Write_Delay <= '0';
            WHEN Start =>
               IF (Access_Waiting = '1') THEN
                  Access_Waiting <= '0';
                  Hilscher_nCS <= '0';
                  Hilscher_AD <= Hilscher_AD_Int;
                  Hilscher_nRD <= Hilscher_nRD_Int;
                  Hilscher_nWR <= Hilscher_nWR_Int;
                  Hilscher_D_EN <= Hilscher_D_EN_Int;
               ELSIF (PPC_Dock.Router_Data.TS = '1') THEN
                  Hilscher_nCS <= '0';
                  Hilscher_AD <= (PPC_Dock.Router_Data.AD(10 DOWNTO 0) & Low_AD);
                  Actual_Access_Time := 1;
                  PPC_BE_Int <= PPC_Dock.Router_Data.BE;
                  Hilscher_nBHE <= Hilscher_nBHE_Int; -- Debug QFU, 19.10.2009
                  IF (PPC_Dock.Router_Data.WE = '1') THEN
                     Hilscher_nRD <= '1';
                     Hilscher_nWR <= '0';
                     Hilscher_D_EN <= X"FFFF";
                     ----- QFU Debug, 14052009
                     PPC_Dock.Member_Data.Write_Delay <= '1';
                     ----- QFU Debug, 14052009
                  ELSE
                     Hilscher_nRD <= '0';
                     Hilscher_nWR <= '1';
                     Hilscher_D_EN <= X"0000";
                     ----- QFU Debug, 14052009
                     PPC_Dock.Member_Data.Write_Delay <= '0';
                     ----- QFU Debug, 14052009
                  END IF;
               ELSE
                  Hilscher_nCS <= '1';
                  Hilscher_nRD <= '1';
                  Hilscher_nWR <= '1';
                  Hilscher_D_EN <= X"0000";
                  Actual_Access_Time := 0;
                  --Hilscher_nBHE <= '1'; --
                  ----- QFU Debug, 14052009
                  PPC_Dock.Member_Data.Write_Delay <= '1';
                  ----- QFU Debug, 14052009
               END IF;
               PPC_Dock.Member_Data.Data_Ready <= '0';
            WHEN Mode_Write0 =>
               Hilscher_nCS <= '0';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '0';
               --Hilscher_D_EN <= X"00FF";
               Hilscher_D_EN <= X"FFFF";--

               CASE PPC_BE_Int IS
                  WHEN "00001000" => -- X"08"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 24));
                  WHEN "00000100" => -- X"04"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(23 DOWNTO 16));
                  WHEN "00000010" => -- X"02"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(15 DOWNTO 8));
                  WHEN "00000001" => -- X"01"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(7 DOWNTO 0));
                  WHEN "10000000" => -- X"80"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(63 DOWNTO 56));
                  WHEN "01000000" => -- X"40"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(55 DOWNTO 48));
                  WHEN "00100000" => -- X"20"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(47 DOWNTO 40));
                  WHEN "00010000" => -- X"01"
                     Hilscher_D_OUT <= (X"00" & PPC_Dock.Router_Data.Router_Entity_Data(39 DOWNTO 32));
                  WHEN X"0C" => --
                     Hilscher_D_OUT <= (PPC_Dock.Router_Data.Router_Entity_Data(23 DOWNTO 16) & PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 24)); --
                  WHEN X"03" => --
                     Hilscher_D_OUT <= (PPC_Dock.Router_Data.Router_Entity_Data(7 DOWNTO 0) & PPC_Dock.Router_Data.Router_Entity_Data(15 DOWNTO 8)); --
                  WHEN X"C0" => --
                     Hilscher_D_OUT <= (PPC_Dock.Router_Data.Router_Entity_Data(55 DOWNTO 48) & PPC_Dock.Router_Data.Router_Entity_Data(63 DOWNTO 56)); --
                  WHEN X"30" => --
                     Hilscher_D_OUT <= (PPC_Dock.Router_Data.Router_Entity_Data(39 DOWNTO 32) & PPC_Dock.Router_Data.Router_Entity_Data(47 DOWNTO 40)); --
                  WHEN OTHERS =>
                     Hilscher_D_OUT <= (X"00" & X"00");
               END CASE;
               Actual_Access_Time := (Actual_Access_Time + 1);
            WHEN Mode_Read0 =>
               Hilscher_nCS <= '0';
               Hilscher_nRD <= '0';
               Hilscher_nWR <= '1';
               Actual_Access_Time := (Actual_Access_Time + 1);
            WHEN Mode_Read1 =>
               Hilscher_nCS <= '0';
               Hilscher_nRD <= '0';
               Hilscher_nWR <= '1';
               Actual_Access_Time := (Actual_Access_Time + 1);
            WHEN Mode_Read2 =>
               Hilscher_nCS <= '1';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '1';
               --Hilscher_nBHE <= '1';--
               IF ((PPC_BE_Int = X"0C") OR (PPC_BE_Int = X"03") OR (PPC_BE_Int = X"C0") OR (PPC_BE_Int = X"30")) THEN --
                  Hilscher_PPC_Data <= Hilscher_D_IN; --
               ELSE --
                  Hilscher_PPC_Data <= (Hilscher_D_IN(7 DOWNTO 0) & Hilscher_D_IN(7 DOWNTO 0)); --
               END IF; --
               PPC_Dock.Member_Data.Data_Ready <= '1';
               Actual_Access_Time := (Actual_Access_Time + 1);
            WHEN Mode_Write1 =>
               Hilscher_nCS <= '0';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '0';
               Actual_Access_Time := (Actual_Access_Time + 1);
            WHEN Mode_Write2 =>
               Hilscher_nCS <= '1';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '1';
               Hilscher_D_EN <= X"0000";
               --Hilscher_nBHE <= '1';--
               --PPC_Dock.Member_Data.Write_Delay <= '0';--?????????????????????????????????????????????????????????????????????????????????????
               Actual_Access_Time := (Actual_Access_Time + 1);
            When Mode_Pause0|Mode_Pause1|Mode_Pause2|Mode_Pause3|Mode_Pause4|Mode_Pause5 =>
               PPC_Dock.Member_Data.Data_Ready <= '0';
               Actual_Access_Time := (Actual_Access_Time + 1);
               Hilscher_nCS <= '1';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '1';
               Hilscher_D_EN <= X"0000";
               IF ((PPC_Dock.Router_Data.TS = '1') AND (Access_Waiting = '0')) THEN
                  Hilscher_AD_Int <= (PPC_Dock.Router_Data.AD(10 DOWNTO 0) & Low_AD);
                  Access_Waiting <= '1';
                  IF (PPC_Dock.Router_Data.WE = '1') THEN
                     Hilscher_nRD_Int <= '1';
                     Hilscher_nWR_Int <= '0';
                     Hilscher_D_EN_Int <= X"FFFF";
                     PPC_Dock.Member_Data.Write_Delay <= '1';
                  ELSE
                     Hilscher_nRD_Int <= '0';
                     Hilscher_nWR_Int <= '1';
                     Hilscher_D_EN_Int <= X"0000";
                     ----- QFU Debug, 14052009
                     PPC_Dock.Member_Data.Write_Delay <= '0';
                     ----- QFU Debug, 14052009
                  END IF;
               ELSIF (Access_Waiting = '1') THEN
                  Hilscher_nRD_Int <= Hilscher_nRD_Int;
                  Hilscher_nWR_Int <= Hilscher_nWR_Int;
                  Hilscher_D_EN_Int <= Hilscher_D_EN_Int;
               ELSE
                  Hilscher_nRD_Int <= '1';
                  Hilscher_nWR_Int <= '1';
                  Hilscher_D_EN_Int <= X"0000";
               END IF;
               -- Debug QFU, 14052009
               IF (current_state = Mode_Pause4) THEN
                  PPC_Dock.Member_Data.Write_Delay <= '0';
               END IF;
               -- Debug QFU, 14052009      
            WHEN OTHERS =>
               Hilscher_nCS <= '1';
               Hilscher_nRD <= '1';
               Hilscher_nWR <= '1';
               Hilscher_AD <= "00000000000000";
               Hilscher_D_EN <= X"0000";
               Hilscher_D_OUT <= X"0000";
               Hilscher_PPC_Data <= X"0000";
               PPC_Dock.Member_Data.Data_Ready <= '1';
               Actual_Access_Time := 0;
            END CASE;
         END IF;
      END IF;
   END PROCESS Hilscher_Module_Interface;
   -----------------------------
   -- Hilscher interface FSM END
   -----------------------------
   
   
   
   ------------------------
   -- Choose the next state
   ------------------------
   Choose_Next_State: PROCESS(current_state, PPC_Dock.Router_Data.TS, PPC_Dock.Router_Data.WE, Hilscher_nBusy_Int, Access_Waiting, Hilscher_nWR_Int)
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
         ELSIF (Access_Waiting = '1') THEN
            IF (Hilscher_nWR_Int = '0') THEN
               next_state <= Mode_Write0;
            ELSE
               next_state <= Mode_Read0;
            END IF;
         ELSE
            next_state <= Start;
         END IF;
      WHEN Mode_Write0 =>
         IF (Hilscher_nBusy_Int = '0') THEN
            next_state <= Mode_Write1;
         ELSE
            next_state <= Mode_Write0;
         END IF;
      WHEN Mode_Read0 =>
         IF (Hilscher_nBusy_Int = '0') THEN
            next_state <= Mode_Read1;
         ELSE
            next_state <= Mode_Read0;
         END IF;
      WHEN Mode_Read1 =>
         IF (Hilscher_nBusy_Int = '1') THEN
            next_state <= Mode_Read2;
         ELSE
            next_state <= Mode_Read1;
         END IF;
      WHEN Mode_Read2 =>
         next_state <= Mode_Pause0;
      WHEN Mode_Write1 =>
         IF (Hilscher_nBusy_Int = '1') THEN
            next_state <= Mode_Write2;
         ELSE
            next_state <= Mode_Write1;
         END IF;
      WHEN Mode_Write2 =>
         next_state <= Mode_Pause0;
      WHEN Mode_Pause0 =>
         next_state <= Mode_Pause1;
      WHEN Mode_Pause1 =>
         next_state <= Mode_Pause2;
      WHEN Mode_Pause2 =>
         next_state <= Mode_Pause3;
      WHEN Mode_Pause3 =>
         next_state <= Mode_Pause4;
      WHEN Mode_Pause4 =>
         next_state <= Start; 
      WHEN OTHERS =>
         next_state <= Init; 
      END CASE;
   END PROCESS Choose_Next_State;
   ----------------------------
   -- Choose the next state END
   ----------------------------


END ARCHITECTURE Universal;