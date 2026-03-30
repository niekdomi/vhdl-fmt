-- MODULE Exception Control
-- VHDL Architecture Indel_lib.natural.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Entity used for the exception handling in the FPGA                         --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG01: 23.07.2007:   Initial version. Can be used  for tests with the PLX   --
-- RDK, too.                                                                  --
-- IG02: 12.09.2006:   Additions                                              --
-- IG03: 06.08.2008:   Added hold functionality for the ethernet interrupt.   --
-- -------------------------------------------------------------------------- --
--                                                                            --
--                                                                            --
-- Remarks: Actually we clear all the interrrupts during the PPC reset via    --
-- PPC_nRST.                                                                  --
-- Interrupts (meaning for compatibility with SAM2):                          --
-- Int(0): UART0 active low              Int(1): UART1 active low             --
-- Int(2): LAN (E)active low             Int(3): (1394) active low Ginlink    --
-- Int(4): EXT0  active low              Int(5): EXT1  active low             --
-- Int(6): --    active low              Int(7): --    active low             --
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


--------------------------------------------------------------------------------
-- Entity declaration
--------------------------------------------------------------------------------
ENTITY Exception_Control IS
   GENERIC    (
               Firmware_Version_C          : std_logic_vector(7 DOWNTO 0)
                );
   PORT        (
                GCLK                       : IN    std_logic;
                CLR_n                      : IN    std_logic;
                PPC_nRST                   : IN    std_logic;
                RU_Status                  : IN    std_logic_vector(7 DOWNTO 0);
                IRQs                       : IN    irq_array_t_s_pkg;
                Config_WR_Port             : IN    std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
                Config_RD_Port             : OUT   std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
                SDRAM_Configuration        : OUT   std_logic_vector(7 DOWNTO 0);
                PPC_nINT                   : OUT   std_logic;
                PPC_nSMI                   : OUT   std_logic;
                PPC_nMCP                   : OUT   std_logic
                );
END ENTITY Exception_Control;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------



ARCHITECTURE Universal OF Exception_Control IS
   SIGNAL IR_INT                    : std_logic;
   SIGNAL IRQ_Mask                  : std_logic_vector(7 DOWNTo 0);
   SIGNAL Hold_IRQ2_d               : std_logic; -- Ethernet
   SIGNAL Hold_IRQ2_q               : std_logic; -- Ethernet
   SIGNAL Hold_IRQ3_d               : std_logic; -- GinLink
   SIGNAL Hold_IRQ3_q               : std_logic; -- GinLink
   SIGNAL RU_Status_INT             : std_logic_vector(7 DOWNTO 0);
   SIGNAL SDRAM_Configuration_INT   : std_logic_vector(7 DOWNTO 0);
   
   
BEGIN
   
   --------------------
   -- PPC_nSMI Handling
   --------------------
   PPC_nSMI <= NOT(IRQs(MM_ILDPR_C_S_PKG)(0) OR IRQs(MM_ILDPR_C_S_PKG)(1) OR IRQs(MM_ILDPR_C_S_PKG)(2));
   ------------------------
   -- PPC_nSMI Handling END
   ------------------------
   
   
   --------------------
   -- PPC_nMCP Handling
   --------------------
   
   -- Machine Check exception is actually not used.
   PPC_nMCP <= '1';
   ------------------------
   -- PPC_nMCP Handling END
   ------------------------
   



   --------------------
   -- PPC_nIRQ Handling
   --------------------
   Hold_IRQ2_d <= (IRQs(MM_Ethernet_C_S_PKG)(7) OR (Hold_IRQ2_q AND IRQ_Mask(2)));
   Hold_IRQ3_d <= (IRQs(MM_F7_C_S_PKG)(7) OR (Hold_IRQ3_q AND IRQ_Mask(3)));
   
   
   Make_Level_Triggered: PROCESS(GCLK, CLR_n, PPC_nRST)
   BEGIN
      IF ((CLR_n = '0') OR (PPC_nRST = '0')) THEN
         Hold_IRQ2_q <= '0';
         Hold_IRQ3_q <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         Hold_IRQ2_q <= Hold_IRQ2_d;
         Hold_IRQ3_q <= Hold_IRQ3_d;
      END IF;
   END PROCESS Make_Level_Triggered;


   Assign_IRQ: PROCESS(IRQs, IRQ_Mask, Hold_IRQ2_q, Hold_IRQ3_q)
   BEGIN
      IR_Int <= ((IRQs(MM_UART_C_S_PKG)(0) AND IRQ_Mask(0)) OR -- UART0
                 (IRQs(MM_UART_C_S_PKG)(1) AND IRQ_Mask(1)) OR -- UART1
                 (Hold_IRQ2_q AND IRQ_Mask(2)) OR -- Ethernet
                 (Hold_IRQ3_q AND IRQ_Mask(3)) OR -- GinLink
                 (IRQs(MM_External_A_C_S_PKG)(0) AND IRQ_Mask(4))
                 );
   END PROCESS Assign_IRQ;


   Sample_Assigned_IRQ: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         PPC_nINT <= '1';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         PPC_nINT <= NOT(IR_INT);
      END IF;
   END PROCESS Sample_Assigned_IRQ;
   ------------------------
   -- PPC_nIRQ Handling END
   ------------------------ 
  
   
   -- The interrupt signal has to be level triggered.
   Config_RD_Port <= (X"0000" & RU_Status_INT & X"00" & Firmware_Version_C & "000000" & SDRAM_Configuration_INT(1 DOWNTO 0) & IRQ_Mask & "000" & IRQs(MM_External_A_C_S_PKG)(0) &Hold_IRQ3_q & Hold_IRQ2_q & IRQs(MM_UART_C_S_PKG)(1) & IRQs(MM_UART_C_S_PKG)(0));
   
   -- Concurrent
   IRQ_Mask(7 DOWNTO 0) <= Config_WR_Port(15 DOWNTO 8);
   SDRAM_Configuration_INT <= Config_WR_Port(23 DOWNTO 16);
   SDRAM_Configuration <= SDRAM_Configuration_INT;
   
   -- Sample the RU status signals
   Remote_Update_Status_Sampling: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         RU_Status_INT <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         RU_Status_INT <= RU_Status;
      END IF;
   END PROCESS Remote_Update_Status_Sampling;
   

END ARCHITECTURE Universal;