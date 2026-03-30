-- MODULE BIDIR Control
-- VHDL Architecture Indel_lib.BIDIR_Control.Universal
--
-- InfoLink, GinLink, INFO-PCIe Copyright (c): INDEL AG
--
-- Project:   INFO-PCIe
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Entity for the functionality related to BIDIR buses                        --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG01: 03.07.2006:   Initial version. Can be used  for tests with the PLX   --
-- RDK, too.                                                                  --
-- IG02: 14.07.2006:   "Open drain" option added for I2C buses                --
-- -------------------------------------------------------------------------- --



---------------------------
-- Entity library inclusion
---------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.INFO_SAM3_Package.all;
-------------------------------
-- Entity library inclusion END
-------------------------------


--------------------------------------------------------------------------------
-- Entity declaration
--------------------------------------------------------------------------------
ENTITY BIDIR_Control IS
   GENERIC     (
                BIDIR_Function       :  IN    natural RANGE 0 TO Defined_BIDIR_Function_C_S_PKG := 0;
                BIDIR_Mode           :  IN    natural RANGE 0 TO Defined_BIDIR_Mode_C_S_PKG := 0
                );
   PORT        (
                BIDIR_CLK            :  IN    std_logic; -- Clock signal for the internal registers (if activated)
                BIDIR_CLR_n          :  IN    std_logic; -- Reset signal
                BIDIR_EN             :  IN    std_logic; -- Enable signal for the output driver
                BIDIR                :  INOUT std_logic; -- Bidirectional signal
                BIDIR_Data_IN        :  IN    std_logic; -- Data input signal
                BIDIR_Data_OUT       :  OUT   std_logic -- Data output signal of the birectional line.
                );
END ENTITY BIDIR_Control;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------




ARCHITECTURE Universal OF BIDIR_Control IS
BEGIN

      
      -- It is an input port.
      --Mode_Input: IF (BIDIR_Function = 0) GENERATE
      --BEGIN
         -- Not registered.
         --In_Topology_No_Register: IF (BIDIR_Topology = 0) GENERATE
         --BEGIN
            --BIDIR_Data_OUT <= BIDIR;
         --END GENERATE In_Topology_No_Register;

         
      --END GENERATE Mode_Input;


      -- The signal is an output
      --Mode_Output: IF (BIDIR_Mode = 1) GENERATE
      --BEGIN
         
      --END GENERATE Mode_Output;


      -- It is a bidirectional port
      --Mode_In_Out: IF (BIDIR_Mode = 2) GENERATE
      --BEGIN
         -- The fastest, possible way to switch the bidirectional bus.
         
         
         Topology_No_Register: IF (BIDIR_Mode = 0) GENERATE -- Without any registers
         BEGIN     
            Assign_0: PROCESS(BIDIR, BIDIR_EN, BIDIR_Data_IN)
            BEGIN
               BIDIR_Data_OUT <= BIDIR;
               IF (BIDIR_EN = '1') THEN
                  BIDIR <= BIDIR_Data_IN;
               ELSE
                  BIDIR <= 'Z';
               END IF;
            END PROCESS Assign_0;
         END GENERATE Topology_No_Register;


         -- The input data to the bidirectional line is registered.
         Topology_IN_Register: IF (BIDIR_Mode = 1) GENERATE -- With input register
            SIGNAL IN_DFF     : std_logic;
         BEGIN
            Input_Register: PROCESS(BIDIR_CLK, BIDIR_CLR_n)
            BEGIN
               IF (BIDIR_CLR_n = '0') THEN
                  IN_DFF <= '0';
               ELSIF (BIDIR_CLK'EVENT AND BIDIR_CLK = '1') THEN
                  IN_DFF <= BIDIR_Data_IN;
               END IF;
            END PROCESS Input_Register;

            Assign_1: PROCESS(BIDIR_EN, BIDIR, IN_DFF)
            BEGIN
               BIDIR_Data_OUT <= BIDIR;
               IF (BIDIR_EN = '1') THEN
                  BIDIR <= IN_DFF;
               ELSE
                  BIDIR <= 'Z';
               END IF;
            END PROCESS Assign_1;
         END GENERATE Topology_IN_Register;


         -- The output data from the bidirectional line is registered.
         Topology_OUT_Register: IF (BIDIR_Mode = 2) GENERATE -- With output register
            SIGNAL OUT_DFF    : std_logic;
         BEGIN
            Output_Register: PROCESS(BIDIR_CLK, BIDIR_CLR_n)
            BEGIN
               IF (BIDIR_CLR_n = '0') THEN
                  BIDIR_Data_OUT <= '0';
               ELSIF (BIDIR_CLK'EVENT AND BIDIR_CLK = '1') THEN
                  BIDIR_Data_OUT <= OUT_DFF;
               END IF;
            END PROCESS Output_Register;

            Assign_2: PROCESS(BIDIR_EN, BIDIR, BIDIR_Data_IN)
            BEGIN
               OUT_DFF <= BIDIR;
               IF (BIDIR_EN = '1') THEN
                  BIDIR <= BIDIR_Data_IN;
               ELSE
                  BIDIR <= 'Z';
               END IF;
            END PROCESS Assign_2;
         END GENERATE Topology_OUT_Register;


         -- Input and output data of the bidirectional line is registered.
         Topology_IN_OUT_Register: IF (BIDIR_Mode = 3) GENERATE -- With input and output registers
            SIGNAL IN_DFF     : std_logic;
            SIGNAL OUT_DFF    : std_logic;
         BEGIN
            Input_Output_Registers: PROCESS(BIDIR_CLK, BIDIR_CLR_n)
            BEGIN
               IF (BIDIR_CLR_n = '0') THEN
                  BIDIR_Data_OUT <= '0';
                  IN_DFF <= '0';
               ELSIF (BIDIR_CLK'EVENT AND BIDIR_CLK = '1') THEN
                  BIDIR_Data_OUT <= OUT_DFF;
                  IN_DFF <= BIDIR_Data_IN;
               END IF;
            END PROCESS Input_Output_Registers;

            Assign_3: PROCESS(BIDIR, BIDIR_EN, IN_DFF)
            BEGIN
               OUT_DFF <= BIDIR;
               IF (BIDIR_EN = '1') THEN
                  BIDIR <= IN_DFF;
               ELSE
                  BIDIR <= 'Z';
               END IF;
            END PROCESS Assign_3;
         END GENERATE Topology_IN_OUT_Register;

         -- Open drain with input and output registers
         Topology_IN_OUT_Register_Open_Drain: IF (BIDIR_Mode = 4) GENERATE -- With input and output registers (open drain)
            SIGNAL IN_DFF     : std_logic;
            SIGNAL OUT_DFF    : std_logic;
         BEGIN
            Input_Output_Registers: PROCESS(BIDIR_CLK, BIDIR_CLR_n)
            BEGIN
               IF (BIDIR_CLR_n = '0') THEN
                  BIDIR_Data_OUT <= '0';
                  IN_DFF <= '0';
               ELSIF (BIDIR_CLK'EVENT AND BIDIR_CLK = '1') THEN
                  BIDIR_Data_OUT <= OUT_DFF;
                  IN_DFF <= BIDIR_Data_IN;
               END IF;
            END PROCESS Input_Output_Registers;

            Assign_4: PROCESS(BIDIR_CLR_n, BIDIR, BIDIR_EN, IN_DFF)
            BEGIN
               OUT_DFF <= BIDIR;
               IF ((BIDIR_CLR_n = '0') OR (BIDIR_EN = '0') OR (IN_DFF = '1')) THEN
                  BIDIR <= 'Z';
               ELSE
                  BIDIR <= '0';
               END IF;
            END PROCESS Assign_4;
         END GENERATE Topology_IN_OUT_Register_Open_Drain;



   --END GENERATE Mode_In_Out;

END ARCHITECTURE Universal;
