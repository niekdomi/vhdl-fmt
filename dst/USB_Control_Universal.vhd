-- MODULE USB Control
-- VHDL Architecture Indel_lib.USB_Control.Universal
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

ENTITY USB_Control IS
  PORT (
        GCLK                      : IN    std_logic; -- 125MHz
        CLR_n                     : IN    std_logic;
        USB_CLK12                 : IN    std_logic; -- 62.5MHz
        PPC_Dock                  : INOUT router_dock_t_s_pkg; -- 0xF3
        USB_nCS                   : OUT   std_logic; -- USB chip select
        USB_A                     : OUT   std_logic_vector(Return_Upper_F_I_PKG(USB_AD_Width_C_S_PKG) DOWNTO 0); -- USB address output
        X_Bus_USB_Data            : IN    std_logic_vector(Return_Upper_F_I_PKG(USB_D_Width_C_S_PKG) DOWNTO 0); -- USB input data signals
        USB_X_Bus_Data            : OUT   std_logic_vector(Return_Upper_F_I_PKG(USB_D_Width_C_S_PKG) DOWNTO 0) --USB output data signals
        );
END ENTITY USB_Control;


ARCHITECTURE Universal OF USB_Control IS
   SIGNAL MRAM_AD_INT             : std_logic_vector(15 DOWNTO 0);
   SIGNAL MRAM_BE_INT             : std_logic_vector(7 DOWNTO 0);
   SIGNAL MRAM_AD_Counter         : natural RANGE 0 TO 15;
   SIGNAL Sample_Counter          : natural RANGE 0 TO 15;
   SIGNAL MRAM_Data               : std_logic_vector(15 DOWNTO 0);
   SIGNAL MRAM_Transfer_1         : std_logic;
   SIGNAL MRAM_Transfer_2         : std_logic;
   SIGNAL MRAM_Transfer_3         : std_logic;
   SIGNAL MRAM_Transfer_4         : std_logic;
   SIGNAL MRAM_Transfer_Runs      : std_logic;
   SIGNAL Member_Data             : std_logic_vector(63 DOWNTO 0);
   SIGNAL Data_Ready              : std_logic;
   SIGNAL Sample_Data             : std_logic;
   SIGNAL Start_MRAM_Access       : std_logic;
   SIGNAL Write_MRAM_Access       : std_logic;
   SIGNAL MRAM_WR_Data            : std_logic_vector(15 DOWNTO 0);
   SIGNAL MRAM_Write_Delay        : std_logic;
   SIGNAL MRAM_Burst_Vector_INT   : burst_address_t_s_pkg;
   SIGNAL MRAM_Burst_Counter      : natural RANGE 0 TO 3;
   SIGNAL MRAM_Burst_Access       : std_logic;

BEGIN

   -- Concurrent 0
--   MRAM_Data <= Change_Endianess_F_S_PKG(X_Bus_MRAM_Data);
--   MRAM_X_Bus_Data <= Change_Endianess_F_S_PKG(MRAM_WR_Data);
   
   -- Concurrent 1
   PPC_Dock.Member_Data.IRQ <= "00000000";
   PPC_Dock.Member_Data.Write_Delay <= '0';
--   PPC_Dock.Member_Data.Write_Delay <= MRAM_Write_Delay;
   PPC_Dock.Member_Data.Entity_Router_Data <= (OTHERS => '0');
--   PPC_Dock.Member_Data.Entity_Router_Data <= Member_Data;
   PPC_Dock.Member_Data.Data_Ready <= '1';
--   PPC_Dock.Member_Data.Data_Ready <= Data_Ready;
   PPC_Dock.Member_Data.Slow_Burst <= '0';
--   PPC_Dock.Member_Data.Slow_Burst <= '1';
 
   
   
   


--   Read_Access: PROCESS(MRAM_CLK, MRAM_CLR_n)
--   BEGIN
--      IF (MRAM_CLR_n = '0') THEN
--         MRAM_AD_INT <= (OTHERS => '0');
--         Start_MRAM_Access <= '0';
--         Write_MRAM_Access <= '0';
--         MRAM_BE_INT <= (OTHERS => '0');
--         MRAM_Write_Delay <= '0';
--         MRAM_Burst_Vector_INT <= (OTHERS => (OTHERS => '0'));
--         MRAM_Burst_Counter <= 0;
--         MRAM_Burst_Access <= '0';
--      ELSIF (MRAM_CLK'EVENT AND MRAM_CLK = '1') THEN
--         IF ((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) THEN
--            MRAM_AD_INT <= PPC_Dock.Router_Data.AD(15 DOWNTO 0);
--            Start_MRAM_Access <= '1';
--            Write_MRAM_Access <= '0';
--            MRAM_Write_Delay <= '0';
--            MRAM_Burst_Counter <= 0;
--            IF (PPC_Dock.Router_Data.TBST = '1') THEN
--               MRAM_Burst_Vector_INT <= PPC_Dock.Router_Data.Burst_Vector;
--               MRAM_Burst_Access <= '1';
--            ELSE
--               MRAM_Burst_Vector_INT <= (OTHERS => (OTHERS => '0'));
--               MRAM_Burst_Access <= '0';
--            END IF;
--         ELSIF ((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '1')) THEN
--            MRAM_AD_INT <= PPC_Dock.Router_Data.AD(15 DOWNTO 0);
--            Start_MRAM_Access <= '1';
--            Write_MRAM_Access <= '1';
--            MRAM_Write_Delay <= '1';
--            MRAM_BE_INT <= PPC_Dock.Router_Data.BE;
--            MRAM_Burst_Counter <= 0;
--            IF (PPC_Dock.Router_Data.TBST = '1') THEN
--               MRAM_Burst_Vector_INT <= PPC_Dock.Router_Data.Burst_Vector;
--               MRAM_Burst_Access <= '1';
--            ELSE
--               MRAM_Burst_Vector_INT <= (OTHERS => (OTHERS => '0'));
--               MRAM_Burst_Access <= '0';
--            END IF;
--         ELSIF (MRAM_Transfer_Runs = '1') THEN
--            Start_MRAM_Access <= '0';
--         ELSIF (Data_Ready = '1') THEN
--            Write_MRAM_Access <= '0';
--            MRAM_Write_Delay <= '0';
--            IF (MRAM_Burst_Access = '1') THEN
--               IF (MRAM_Burst_Counter = 2) THEN
--                  MRAM_Burst_Counter <= 0;
--                  MRAM_Burst_Access <= '0';
--               ELSE
--                  MRAM_Burst_Counter <= (MRAM_Burst_Counter + 1);
--               END IF;
--               MRAM_AD_INT <= (MRAM_AD_INT(15 DOWNTO 2) & MRAM_Burst_Vector_INT(MRAM_Burst_Counter));
--               Start_MRAM_Access <= '1';
--               Write_MRAM_Access <= '0';
--               MRAM_Write_Delay <= '0';
--            END IF;
--         ELSE
--            MRAM_Write_Delay <= '1';
--         END IF;
--      END IF;
--   END PROCESS Read_Access;
--      
--
--   Save_Read_Data: PROCESS(MRAM_CLK, MRAM_CLR_n)
--   BEGIN
--      IF (MRAM_CLR_n = '0') THEN
--         Data_Ready <= '0';   
--         Member_Data <= (OTHERS => '0');
--      ELSIF (MRAM_CLK'EVENT AND MRAM_CLK = '1') THEN
--         IF (Sample_Data = '1') THEN
--            IF (Sample_Counter = 0) THEN
--               Member_Data(31 DOWNTO 16) <= MRAM_Data;
--               Data_Ready <= '0';
--            ELSIF (Sample_Counter = 1) THEN
--               Member_Data(15 DOWNTO 0) <= MRAM_Data;
--               Data_Ready <= '0';
--            ELSIF (Sample_Counter = 2) THEN
--               Member_Data(63 DOWNTO 48) <= MRAM_Data;
--               Data_Ready <= '0';
--            ELSIF (Sample_Counter = 3) THEN
--               Member_Data(47 DOWNTO 32) <= MRAM_Data;
--               Data_Ready <= '1';
--            END IF;
--         ELSE
--            Data_Ready <= '0';
--         END IF;
--      END IF;
--   END PROCESS Save_Read_Data;
--   
--
--
--   MRAM_Access: PROCESS(MRAM_CLK, MRAM_CLR_n)
--   BEGIN
--      IF (MRAM_CLR_n = '0') THEN
--         MRAM_nCS <= '1';
--         MRAM_AD_Counter <= 0;
--         MRAM_Transfer_1 <= '0';
--         MRAM_Transfer_2 <= '0';
--         MRAM_Transfer_3 <= '0';
--         MRAM_Transfer_4 <= '0';
--         MRAM_Transfer_Runs <= '0';
--         Sample_Data <= '0';
--         Sample_Counter <= 0;
--         MRAM_WR_Data <= (OTHERS => '0');
--         MRAM_nOE <= '0';
--         MRAM_nWE <= '1';
--         MRAM_nUB <= '0';
--         MRAM_nLB <= '0';
--      ELSIF (MRAM_CLK'EVENT AND MRAM_CLK = '1') THEN
--         IF ((MRAM_Transfer_Runs = '0') AND ((MRAM_AD_Counter /= 0) OR (Start_MRAM_Access = '1')))  THEN
--            MRAM_nCS <= '0';
--            MRAM_A <= (MRAM_AD_INT & STD_LOGIC_VECTOR(TO_UNSIGNED(MRAM_AD_Counter, 2)));
--            IF ((Start_MRAM_Access = '1') AND (Write_MRAM_Access = '1')) THEN
--               IF (PPC_Dock.Acknowledge_Data.Data_On_Bus = '1') THEN
--                  MRAM_Transfer_Runs <= '1';
--                  MRAM_Transfer_1 <= '1';
--                  MRAM_Transfer_2 <= '0';
--                  MRAM_Transfer_3 <= '0';
--                  MRAM_Transfer_4 <= '0';
--               ELSE
--                  MRAM_Transfer_Runs <= '0';
--                  MRAM_Transfer_1 <= '0';
--                  MRAM_Transfer_2 <= '0';
--                  MRAM_Transfer_3 <= '0';
--                  MRAM_Transfer_4 <= '0';
--               END IF;
--            ELSE
--               MRAM_Transfer_Runs <= '1';
--               MRAM_Transfer_1 <= '1';
--               MRAM_Transfer_2 <= '0';
--               MRAM_Transfer_3 <= '0';
--               MRAM_Transfer_4 <= '0';
--            END IF;
--            Sample_Data <= '0';
--            IF (Write_MRAM_Access = '1') THEN
--               CASE MRAM_AD_Counter IS
--                  WHEN 0 =>
--                     MRAM_WR_Data <= PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 16);
--                     MRAM_nUB <= NOT(MRAM_BE_INT(2));
--                     MRAM_nLB <= NOT(MRAM_BE_INT(3));
--                  WHEN 1 =>
--                     MRAM_WR_Data <= PPC_Dock.Router_Data.Router_Entity_Data(15 DOWNTO 0);
--                     MRAM_nUB <= NOT(MRAM_BE_INT(0));
--                     MRAM_nLB <= NOT(MRAM_BE_INT(1));
--                  WHEN 2 =>
--                     MRAM_WR_Data <= PPC_Dock.Router_Data.Router_Entity_Data(63 DOWNTO 48);
--                     MRAM_nUB <= NOT(MRAM_BE_INT(6));
--                     MRAM_nLB <= NOT(MRAM_BE_INT(7));
--                  WHEN 3 =>
--                     MRAM_WR_Data <= PPC_Dock.Router_Data.Router_Entity_Data(47 DOWNTO 32);
--                     MRAM_nUB <= NOT(MRAM_BE_INT(4));
--                     MRAM_nLB <= NOT(MRAM_BE_INT(5));
--                  WHEN OTHERS =>
--                     MRAM_WR_Data <= (OTHERS => '0');
--                     MRAM_nUB <= '1';
--                     MRAM_nLB <= '1';
--               END CASE;
--               MRAM_nOE <= '1';
--            ELSE
--               MRAM_nOE <= '0';
--               MRAM_nUB <= '0';
--               MRAM_nLB <= '0';
--            END IF;
--         ELSIF (MRAM_Transfer_1 = '1') THEN
--            MRAM_nCS <= '0';
--            MRAM_Transfer_1 <= '0';
--            MRAM_Transfer_2 <= '1';
--            MRAM_Transfer_3 <= '0';
--            MRAM_Transfer_4 <= '0';
--            IF (Write_MRAM_Access = '1') THEN
--               MRAM_nWE <= '0';
--            END IF;
--         ELSIF (MRAM_Transfer_2 = '1') THEN
--            MRAM_nCS <= '0';
--            MRAM_Transfer_1 <= '0';
--            MRAM_Transfer_2 <= '0';
--            MRAM_Transfer_3 <= '1';
--            MRAM_Transfer_4 <= '0';
--            MRAM_Transfer_Runs <= '1';
--         ELSIF (MRAM_Transfer_3 = '1') THEN
--            IF (Write_MRAM_Access = '1') THEN
--               MRAM_nCS <= '1';
--               MRAM_nOE <= '1';
--               MRAM_nWE <= '1';
--               MRAM_nUB <= '1';
--               MRAM_nLB <= '1';
--            ELSE
--               MRAM_nCS <= '0';
--            END IF;
--            MRAM_Transfer_1 <= '0';
--            MRAM_Transfer_2 <= '0';
--            MRAM_Transfer_3 <= '0';
--            MRAM_Transfer_4 <= '1';
--            MRAM_Transfer_Runs <= '1';
--         ELSIF (MRAM_Transfer_4 = '1') THEN
--            MRAM_Transfer_1 <= '0';
--            MRAM_Transfer_2 <= '0';
--            MRAM_Transfer_3 <= '0';
--            MRAM_Transfer_4 <= '0';
--            MRAM_Transfer_Runs <= '0';
--            IF (MRAM_AD_Counter = 3) THEN
--               MRAM_AD_Counter <= 0;
--            ELSE
--               MRAM_AD_Counter <= (MRAM_AD_Counter + 1);
--            END IF;
--            Sample_Counter <= MRAM_AD_Counter;
--            IF (Write_MRAM_Access = '1') THEN
--               MRAM_nCS <= '1';
--            ELSE
--               MRAM_nCS <= '0';
--            END IF;
--            Sample_Data <= '1';    
--         ELSE
--            Sample_Data <= '0';
--            MRAM_nCS <= '1';
--            MRAM_nOE <= '1';
--         END IF;
--      END IF;
--   END PROCESS MRAM_Access;


END ARCHITECTURE Universal;