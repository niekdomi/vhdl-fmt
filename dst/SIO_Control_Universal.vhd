-- MODULE SIO Control
-- VHDL Architecture Indel_lib.SIO_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --

-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- 28.02.2008                                                                 --
-- This is a wrapper for the opencores.org 16550 UART. It allows us to        --
-- connect this part directly to the internal PPC bus                         --
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

ENTITY SIO_Control IS
  GENERIC (
           SIO_Number : natural RANGE 0 TO 3
           );
  PORT    (
           GCLK                       : IN    std_logic; -- System Clock
           CLR_n                      : IN    std_logic; -- Deglitched external reset
           -- Router Dock signal
           PPC_Dock                   : INOUT router_dock_t_s_pkg;
           -- Baud Rate Clock
           BRCLK                      : IN    std_logic;
           -- SIO signals
           SIO_SEL                    : IN    std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0);
           SIO_nRX                    : IN    std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0); -- SIO receive signals
           SIO_nTX                    : OUT   std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0); -- SIO transmit signals
           SIO_nDSR                   : IN    std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0); -- SIO data set ready
           SIO_nDTR                   : OUT   std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0); -- SIO data terminal ready
           SIO_EN                     : OUT   std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0); -- SIO mode of operation
           Config_RD_Port             : IN    std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
           Config_WR_Port             : OUT   std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
           -- Config signals
           Boot_Config_Cmd            : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Boot_Config_AD             : OUT   std_logic_vector(Return_Upper_F_I_PKG(24) DOWNTO 0);
           Boot_Config_Bytes          : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Boot_Config_Data           : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Boot_Config_Buffer_AD      : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Boot_Config_Status         : IN    std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
           Boot_Config_Terminated     : IN    std_logic;
           Flash_Config_Cmd           : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Flash_Config_AD            : OUT   std_logic_vector(Return_Upper_F_I_PKG(24) DOWNTO 0);
           Flash_Config_Bytes         : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Flash_Config_Data          : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Flash_Config_Buffer_AD     : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           Flash_Config_Status        : IN    std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
           Flash_Config_Terminated    : IN    std_logic;
           --
           FPGA_Config_Cmd            : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           FPGA_Config_AD             : OUT   std_logic_vector(Return_Upper_F_I_PKG(24) DOWNTO 0);
           FPGA_Config_Bytes          : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           FPGA_Config_Data           : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           FPGA_Config_Buffer_AD      : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
           FPGA_Config_Status         : IN    std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
           FPGA_Config_Terminated     : IN    std_logic
           --
           );
END ENTITY SIO_Control;




ARCHITECTURE Universal OF SIO_Control IS


   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT UART_16550 IS
   PORT (
         GCLK    : IN  std_logic; -- GCLK
         BRCLK   : IN  std_logic; -- CLK125
         CLR_n   : IN  std_logic; -- NOT(CLR_n)
         CS      : IN  std_logic; -- NOT(CS_n)
         WR      : IN  std_logic; -- Router_SIO_Dock.WR
         BE      : IN  std_logic_vector(Return_Upper_F_I_PKG(Router_BE_Width_C_S_PKG) DOWNTO 0);
         WR_Data : IN  std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);

         sRX     : IN  std_logic; -- NOT(SIO_nRX(0))
         CTSn    : IN  std_logic := '1'; -- '0'
         DSRn    : IN  std_logic := '1'; -- SIO_nDSR(0)
         RIn     : IN  std_logic := '1'; 
         DCDn    : IN  std_logic := '1';

         sTX     : OUT std_logic; -- NOT(SIO_nTX(0))
         DTRn    : OUT std_logic; -- SIO_nDTR(0)
         RTSn    : OUT std_logic;
         OUT1n   : OUT std_logic;
         OUT2n   : OUT std_logic;
         TXRDYn  : OUT std_logic;
         RXRDYn  : OUT std_logic;

         IRQ     : OUT std_logic;
         BCLK    : OUT std_logic;
         RD_Data : OUT std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0)
         );
   END COMPONENT UART_16550;

   -- --------------------------------------------------------------
   -- Address Map UART 16550
   -- --------------------------------------------------------------
   -- Address   R/W   Mnemonic   LCR(7)   Function
   -- --------------------------------------------------------------
   -- 000       R     RBR        0        Receiver Buffer Register (FIFO)
   -- 000       W     THR        0        Transmitter Holding Register (FIFO)
   -- 000       R,W   DLL        1        Divisor Latch LSB (Baud Rate Generator)
   -- 001       R,W   IER        0        Interrrupt Enable Register
   -- 001       R,W   DLM        1        Divisor Latch MSB (Baud Rate Generator)
   -- 010       R     IIR        X        Interrupt Identification Register
   -- 010       W     FCR        X        FIFO Control Register
   -- 011       R,W   LCR        X        Line Control Register
   -- 100       R,W   MCR        X        Modem Control Register
   -- 101       R     LSR        X        Line Status Register
   -- 110       R     MSR        X        Modem Status Register
   -- 111       R,W   SCR        X        Scratch Register (no UART Control or Status)
   
   
   COMPONENT TDP_Flash_RAM
   PORT (
         address_a      : IN  std_logic_vector(4 DOWNTO 0);
         address_b      : IN  std_logic_vector(4 DOWNTO 0);
         byteena_a      : IN  std_logic_vector(7 DOWNTO 0) :=  (OTHERS => '1');
         byteena_b      : IN  std_logic_vector(7 DOWNTO 0) :=  (OTHERS => '1');
         clock_a        : IN  std_logic;
         clock_b        : IN  std_logic;
         data_a         : IN  std_logic_vector(63 DOWNTO 0);
         data_b         : IN  std_logic_vector(63 DOWNTO 0);
         wren_a         : IN  std_logic  := '1';
         wren_b         : IN  std_logic  := '1';
         q_a            : OUT std_logic_vector(63 DOWNTO 0);
         q_b            : OUT std_logic_vector(63 DOWNTO 0)
         );
   END COMPONENT TDP_Flash_RAM;
   
   

   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : UART_16550 USE ENTITY Indel_lib.UART_16550;
   FOR ALL : TDP_Flash_RAM USE ENTITY Indel_lib.TDP_Flash_RAM;
   -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------
   
   
   
   CONSTANT Memory_Width               : natural:= 5;

   SIGNAL TX_INT                       :        std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0);
   SIGNAL SIO_RX_INT                   :        std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0);
   SIGNAL SIO_nDSR_INT                 :        std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0);
   SIGNAL SIO_nDTR_INT                 :        std_logic_vector(Return_Upper_F_I_PKG(SIO_Number) DOWNTO 0);
   SIGNAL UART_0_TS                    :        std_logic;
   SIGNAL UART_1_TS                    :        std_logic;
   SIGNAL UART_0_WE                    :        std_logic;
   SIGNAL UART_1_WE                    :        std_logic;
   SIGNAL UART_0_IRQ                   :        std_logic;
   SIGNAL UART_1_IRQ                   :        std_logic;
   SIGNAL Member_Data                  :        std_logic_vector(63 DOWNTO 0);
   SIGNAL Data_Ready                   :        std_logic;
   SIGNAL UART_0_RD_Data               :        std_logic_vector(63 DOWNTO 0);
   SIGNAL UART_1_RD_Data               :        std_logic_vector(63 DOWNTO 0);
   SIGNAL UART_WR_Data                 :        std_logic_vector(63 DOWNTO 0);
   SIGNAL Config_WR_Data               :        std_logic_vector(63 DOWNTO 0);
   SIGNAL Config_RD_Data               :        std_logic_vector(63 DOWNTO 0);
   SIGNAL Burst_Vector                 :        burst_address_t_s_pkg;
   SIGNAL Burst_OnGoing                :        std_logic;
   SIGNAL Wait_For_Burst_WR            :        std_logic;
   SIGNAL Burst_Counter                :        natural RANGE 0 TO 2;
   SIGNAL EN_Delay_Counter             :        std_logic;
   SIGNAL WE_INT                       :        std_logic;
   SIGNAL WE_INT_INT                   :        std_logic;
   SIGNAL Wait_For_Data_On_Bus         :        std_logic;
   SIGNAL UART_0_Delay_Ready           :        std_logic;
   SIGNAL UART_1_Delay_Ready           :        std_logic;
   SIGNAL Wait_For_EN_Delay            :        std_logic;
   SIGNAL UART_BE                      :        std_logic_vector(7 DOWNTO 0);
   SIGNAL Config_WR_Port_INT           :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Flash0_0                     :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Flash0_1                     :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Internal_Address             :        std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   SIGNAL Flash_0_RAM_Data             :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Flash_0_WREN                 :        std_logic;
   SIGNAL Flash_Config_Data_INT        :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Wait_For_Data_On_Bus_Second  :        std_logic;
   SIGNAL Boot0_0                      :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Boot0_1                      :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Boot_Internal_Address        :        std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   SIGNAL Boot_0_RAM_Data              :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL Boot_0_WREN                  :        std_logic;
   SIGNAL Boot_Config_Data_INT         :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL FPGA_0                       :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL FPGA_1                       :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL FPGA_Internal_Address        :        std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   SIGNAL FPGA_0_RAM_Data              :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL FPGA_0_WREN                  :        std_logic;
   SIGNAL FPGA_Config_Data_INT         :        std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
 


BEGIN
      
   -- The memory map within this module's address space is as it follows:
   -- 0xFE000000: UART0
   -- 0xFE000020: UART1
   -- 0xFE000060: IRQ register
   -- 0xFE000061: IRQ Mask register
   -- 0xFE000062: SDRAM Configuration
   -- 0xFE000063: FPGA Firmware Revision 0
   -- 0xFE000064: FPGA Firmware Revision 1 (reserved)
   -- 0xFE000065: FPGA Remote Update Hardware Block (SAM3 Hardware Status Information)
   -- 0xFE000200: Control Boot Flash
   -- 0xFE000300: Buffer Boot Flash
   -- 0xFE000400: Control Flash 0
   -- 0xFE000500: Buffer Flash 0
   -- 0xFE000600: Reserved Control Flash 1
   -- 0xFE000700: Reserved Buffer Flash 1
   -- 0xFE000800: Control FPGA Configuration Flash
   -- 0xFE000900: Buffer FPGA Configuration Flash
      
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
           Wait_For_EN_Delay <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
          IF  (((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) OR ((Burst_OnGoing = '1') AND (WE_INT = '0'))) THEN
             IF (((UART_0_WE = '1') AND (PPC_Dock.Router_Data.AD(8 DOWNTO 0) = "000000000")) OR ((UART_1_WE = '1') AND (PPC_Dock.Router_Data.AD(8 DOWNTO 0) = "000000100"))) THEN
                EN_Delay_Counter <= '0';
                Wait_For_EN_Delay <= '1';
             ELSIF ((PPC_Dock.Router_Data.AD(8 DOWNTO 5) = "0101") OR (PPC_Dock.Router_Data.AD(8 DOWNTO 5) = "0011") OR (PPC_Dock.Router_Data.AD(8 DOWNTO 5) = "1001")) THEN
                EN_Delay_Counter <= '0';
                Wait_For_EN_Delay <= '1';
             ELSE
                EN_Delay_Counter <= '1';
                Wait_For_EN_Delay <= '0';
             END IF;
          ELSIF (Wait_For_EN_Delay = '1') THEN
             Wait_For_EN_Delay <= '0';
             EN_Delay_Counter <= '1';
          ELSIF (PPC_Dock.Acknowledge_Data.Ready_Acknowledge = '1') THEN
             EN_Delay_Counter <= '0';
             Wait_For_EN_Delay <= '0';
          END IF;
       END IF;
   END PROCESS Delay_Count;

   PPC_Dock.Member_Data.Data_Ready <= EN_Delay_Counter;


   -- Concurrent add IRQ's:
   PPC_Dock.Member_Data.IRQ <= ("000000" & UART_1_IRQ & UART_0_IRQ);
   PPC_Dock.Member_Data.Write_Delay <= '0';
   PPC_Dock.Member_Data.Slow_Burst <= '0';

   
   -- Internal Write Enable
   WR_Enable: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Wait_For_Data_On_Bus <= '0';
         WE_INT <= '0';
         WE_INT_INT <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((PPC_Dock.Router_Data.WE = '1') AND (PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Acknowledge_Data.Data_On_Bus = '1')) THEN
            WE_INT_INT <= '1';
            Wait_For_Data_On_Bus <= '0';
         ELSIF ((PPC_Dock.Router_Data.WE = '1') AND (PPC_Dock.Router_Data.TS = '1')) THEN
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
         WE_INT <= WE_INT_INT;
      END IF;
   END PROCESS WR_Enable;


   Access_Registers: PROCESS(GCLK, CLR_n)
   BEGIN
       IF (CLR_n = '0') THEN
           Member_Data <= (OTHERS => '0');
           UART_0_TS <= '0';
           UART_1_TS <= '0';
           UART_0_WE <= '0';
           UART_1_WE <= '0';
           UART_0_Delay_Ready <= '0';
           UART_1_Delay_Ready <= '0';
           Config_WR_Port_INT <= (OTHERS => '0');
           Boot0_0 <= (OTHERS => '0');
           Boot0_1 <= (OTHERS => '0');
           Flash0_0 <= (OTHERS => '0');
           Flash0_1 <= (OTHERS => '0');
           FPGA_0 <= (OTHERS => '0');
           FPGA_1 <= (OTHERS => '0');         
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
           Flash0_1(55 DOWNTO 32) <= Flash_Config_Status;
           Boot0_1(55 DOWNTO 32) <= Boot_Config_Status;
           FPGA_1(55 DOWNTO 32) <= FPGA_Config_Status;
           -- WRITE Access
           IF (WE_INT_INT = '1') THEN
              CASE PPC_Dock.Router_Data.AD(8 DOWNTO 0) IS
                 WHEN "000000000" => -- WR UART0
                    UART_0_TS <= '1';
                    UART_1_TS <= '0';
                    UART_0_WE <= '1';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    Config_WR_Port_INT <= Config_RD_Port;
                 WHEN "000000100" => -- WR UART1
                    UART_0_TS <= '0';
                    UART_1_TS <= '1';
                    UART_0_WE <= '0';
                    UART_1_WE <= '1';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    Config_WR_Port_INT <= Config_RD_Port;
                 WHEN "000001100" => -- WR IRQ, IRQ Mask
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(2) = '1') THEN
                       Config_WR_Port_INT(15 DOWNTO 8) <= Config_WR_Data(15 DOWNTO 8);
                    ELSE
                       Config_WR_Port_INT(15 DOWNTO 8) <= Config_WR_Port_INT(15 DOWNTO 8);
                    END IF;
                    ----------------
                    ---------------- 24.08.2009
                    IF (PPC_Dock.Router_Data.BE(1) = '1') THEN
                       Config_WR_Port_INT(23 DOWNTO 16) <= Config_WR_Data(23 DOWNTO 16);
                    ELSE
                       Config_WR_Port_INT(23 DOWNTO 16) <= Config_WR_Port_INT(23 DOWNTO 16);
                    END IF;
                    ----------------
                    ---------------- 24.08.2009 END
                    Config_WR_Port_INT(63 DOWNTO 24) <= Config_RD_Port(63 DOWNTO 24); -- 24.08.2009
                    --Config_WR_Port_INT(63 DOWNTO 16) <= Config_RD_Port(63 DOWNTO 16); -- 24.08.2009
                    Config_WR_Port_INT(7 DOWNTO 0) <= Config_RD_Port(7 DOWNTO 0);  
                 WHEN "001000000" => -- WR Boot Flash Command, Address
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN -- Command
                       Boot0_0(7 DOWNTO 0) <= Config_WR_Data(7 DOWNTO 0);
                    ELSE
                       Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(7) = '1') THEN -- Address
                       Boot0_0(39 DOWNTO 32) <= Config_WR_Data(39 DOWNTO 32);
                    ELSE
                       Boot0_0(39 DOWNTO 32) <= Boot0_0(39 DOWNTO 32);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(6) = '1') THEN
                       Boot0_0(47 DOWNTO 40) <= Config_WR_Data(47 DOWNTO 40);
                    ELSE
                       Boot0_0(47 DOWNTO 40) <= Boot0_0(47 DOWNTO 40);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(5) = '1') THEN
                       Boot0_0(55 DOWNTO 48) <= Config_WR_Data(55 DOWNTO 48);
                    ELSE
                       Boot0_0(55 DOWNTO 48) <= Boot0_0(55 DOWNTO 48);
                    END IF;
                    Boot0_0(63 DOWNTO 56) <= (OTHERS => '0');
                    Boot0_0(31 DOWNTO 8) <= (OTHERS => '0');
                    ------------- 
                    ------------- Debug QFU, 25.06.09
                    Config_WR_Port_INT <= Config_RD_Port;
                    ------------- Debug QFU, 25.06.09 END
                    -------------
                 WHEN "001000001" => -- WR Boot Flash Offset, Number
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN -- Offset
                       Boot0_1(7 DOWNTO 0) <= Config_WR_Data(7 DOWNTO 0);
                    ELSE
                       Boot0_1(7 DOWNTO 0) <= Boot0_1(7 DOWNTO 0);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(2) = '1') THEN -- Number of Bytes
                       Boot0_1(15 DOWNTO 8) <= Config_WR_Data(15 DOWNTO 8);
                    ELSE
                       Boot0_1(15 DOWNTO 8) <= Boot0_1(15 DOWNTO 8);
                    END IF;
                    Boot0_1(63 DOWNTO 56) <= (OTHERS => '0');
                    Boot0_1(31 DOWNTO 16) <= (OTHERS => '0');
                    ------------- 
                    ------------- Debug QFU, 25.06.09
                    Config_WR_Port_INT <= Config_RD_Port;
                    ------------- Debug QFU, 25.06.09 END
                    -------------
                 WHEN "010000000" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN -- Command
                       Flash0_0(7 DOWNTO 0) <= Config_WR_Data(7 DOWNTO 0);
                    ELSE
                       Flash0_0(7 DOWNTO 0) <= Flash0_0(7 DOWNTO 0);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(7) = '1') THEN -- Address
                       Flash0_0(39 DOWNTO 32) <= Config_WR_Data(39 DOWNTO 32);
                    ELSE
                       Flash0_0(39 DOWNTO 32) <= Flash0_0(39 DOWNTO 32);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(6) = '1') THEN
                       Flash0_0(47 DOWNTO 40) <= Config_WR_Data(47 DOWNTO 40);
                    ELSE
                       Flash0_0(47 DOWNTO 40) <= Flash0_0(47 DOWNTO 40);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(5) = '1') THEN
                       Flash0_0(55 DOWNTO 48) <= Config_WR_Data(55 DOWNTO 48);
                    ELSE
                       Flash0_0(55 DOWNTO 48) <= Flash0_0(55 DOWNTO 48);
                    END IF;
                    Flash0_0(63 DOWNTO 56) <= (OTHERS => '0');
                    Flash0_0(31 DOWNTO 8) <= (OTHERS => '0');
                    ------------- 
                    ------------- Debug QFU, 25.06.09
                    Config_WR_Port_INT <= Config_RD_Port;
                    ------------- Debug QFU, 25.06.09 END
                    -------------
                 WHEN "010000001" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN -- Offset
                       Flash0_1(7 DOWNTO 0) <= Config_WR_Data(7 DOWNTO 0);
                    ELSE
                       Flash0_1(7 DOWNTO 0) <= Flash0_1(7 DOWNTO 0);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(2) = '1') THEN -- Number of Bytes
                       Flash0_1(15 DOWNTO 8) <= Config_WR_Data(15 DOWNTO 8);
                    ELSE
                       Flash0_1(15 DOWNTO 8) <= Flash0_1(15 DOWNTO 8);
                    END IF;
                    Flash0_1(63 DOWNTO 56) <= (OTHERS => '0');
                    Flash0_1(31 DOWNTO 16) <= (OTHERS => '0');
                    ------------- 
                    ------------- Debug QFU, 25.06.09
                    Config_WR_Port_INT <= Config_RD_Port;
                    ------------- Debug QFU, 25.06.09 END
                    -------------
                 WHEN "100000000" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN -- Command
                       FPGA_0(7 DOWNTO 0) <= Config_WR_Data(7 DOWNTO 0);
                    ELSE
                       FPGA_0(7 DOWNTO 0) <= FPGA_0(7 DOWNTO 0);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(7) = '1') THEN -- Address
                       FPGA_0(39 DOWNTO 32) <= Config_WR_Data(39 DOWNTO 32);
                    ELSE
                       FPGA_0(39 DOWNTO 32) <= FPGA_0(39 DOWNTO 32);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(6) = '1') THEN
                       FPGA_0(47 DOWNTO 40) <= Config_WR_Data(47 DOWNTO 40);
                    ELSE
                       FPGA_0(47 DOWNTO 40) <= FPGA_0(47 DOWNTO 40);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(5) = '1') THEN
                       FPGA_0(55 DOWNTO 48) <= Config_WR_Data(55 DOWNTO 48);
                    ELSE
                       FPGA_0(55 DOWNTO 48) <= FPGA_0(55 DOWNTO 48);
                    END IF;
                    FPGA_0(63 DOWNTO 56) <= (OTHERS => '0');
                    FPGA_0(31 DOWNTO 8) <= (OTHERS => '0');
                    ------------- 
                    ------------- Debug QFU, 25.06.09
                    Config_WR_Port_INT <= Config_RD_Port;
                    ------------- Debug QFU, 25.06.09 END
                    -------------
                 WHEN "100000001" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    UART_0_WE <= '0';
                    UART_1_WE <= '0';
                    UART_0_Delay_Ready <= '0';
                    UART_1_Delay_Ready <= '0';
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN -- Offset
                       FPGA_1(7 DOWNTO 0) <= Config_WR_Data(7 DOWNTO 0);
                    ELSE
                       FPGA_1(7 DOWNTO 0) <= FPGA_1(7 DOWNTO 0);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(2) = '1') THEN -- Number of Bytes
                       FPGA_1(15 DOWNTO 8) <= Config_WR_Data(15 DOWNTO 8);
                    ELSE
                       FPGA_1(15 DOWNTO 8) <= FPGA_1(15 DOWNTO 8);
                    END IF;
                    FPGA_1(63 DOWNTO 56) <= (OTHERS => '0');
                    FPGA_1(31 DOWNTO 16) <= (OTHERS => '0');
                    ------------- 
                    ------------- Debug QFU, 25.06.09
                    Config_WR_Port_INT <= Config_RD_Port;
                    ------------- Debug QFU, 25.06.09 END
                    -------------
                 WHEN OTHERS =>
                    NULL;
              END CASE;
           -- READ Access
           ELSIF  (((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) OR ((Burst_OnGoing = '1') AND (WE_INT = '0'))) THEN
              CASE PPC_Dock.Router_Data.AD(8 DOWNTO 0) IS
                 WHEN "000000000" =>
                    IF (UART_0_WE = '1') THEN
                       UART_0_Delay_Ready <= '1';
                       UART_0_TS <= '0';
                       UART_1_TS <= '0';
                    ELSE
                       UART_0_Delay_Ready <= '0';
                       UART_0_TS <= '1';
                       UART_1_TS <= '0';
                    END IF;
                    Member_Data <= UART_0_RD_Data(39 DOWNTO 32) & UART_0_RD_Data(47 DOWNTO 40) & UART_0_RD_Data(55 DOWNTO 48) & UART_0_RD_Data(63 DOWNTO 56) & UART_0_RD_Data(7 DOWNTO 0) & UART_0_RD_Data(15 DOWNTO 8) & UART_0_RD_Data(23 DOWNTO 16) & UART_0_RD_Data(31 DOWNTO 24);
                 WHEN "000000100" =>
                    IF (UART_1_WE = '1') THEN
                       UART_1_Delay_Ready <= '1';
                       UART_0_TS <= '0';
                       UART_1_TS <= '0';
                    ELSE
                       UART_1_Delay_Ready <= '0';
                       UART_0_TS <= '0';
                       UART_1_TS <= '1';
                    END IF;
                    Member_Data <= UART_1_RD_Data(39 DOWNTO 32) & UART_1_RD_Data(47 DOWNTO 40) & UART_1_RD_Data(55 DOWNTO 48) & UART_1_RD_Data(63 DOWNTO 56) & UART_1_RD_Data(7 DOWNTO 0) & UART_1_RD_Data(15 DOWNTO 8) & UART_1_RD_Data(23 DOWNTO 16) & UART_1_RD_Data(31 DOWNTO 24);
                 WHEN "000001100" =>
                    Member_Data <= Config_RD_Data(39 DOWNTO 32) & Config_RD_Data(47 DOWNTO 40) & Config_RD_Data(55 DOWNTO 48) & Config_RD_Data(63 DOWNTO 56) & Config_RD_Data(7 DOWNTO 0) & Config_RD_Data(15 DOWNTO 8) & Config_RD_Data(23 DOWNTO 16) & Config_RD_Data(31 DOWNTO 24);
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                 WHEN "001000000" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= Boot0_0(39 DOWNTO 32) & Boot0_0(47 DOWNTO 40) & Boot0_0(55 DOWNTO 48) & Boot0_0(63 DOWNTO 56) & Boot0_0(7 DOWNTO 0) & Boot0_0(15 DOWNTO 8) & Boot0_0(23 DOWNTO 16) & Boot0_0(31 DOWNTO 24);
                 WHEN "001000001" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= Boot0_1(39 DOWNTO 32) & Boot0_1(47 DOWNTO 40) & Boot0_1(55 DOWNTO 48) & Boot0_1(63 DOWNTO 56) & Boot0_1(7 DOWNTO 0) & Boot0_1(15 DOWNTO 8) & Boot0_1(23 DOWNTO 16) & Boot0_1(31 DOWNTO 24);
                 WHEN "001100000"|"001100001"|"001100010"|"001100011"|"001100100"|"001100101"|"001100110"|"001100111"|"001101000"|"001101001"|"001101010"|"001101011"|"001101100"|"001101101"|"001101110"|"001101111"|"001110000"|"001110001"|"001110010"|"001110011"|"001110100"|"001110101"|"001110110"|"001110111"|"001111000"|"001111001"|"001111010"|"001111011"|"001111100"|"001111101"|"001111110"|"001111111" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= Boot_0_RAM_Data;
                 WHEN "010000000" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= Flash0_0(39 DOWNTO 32) & Flash0_0(47 DOWNTO 40) & Flash0_0(55 DOWNTO 48) & Flash0_0(63 DOWNTO 56) & Flash0_0(7 DOWNTO 0) & Flash0_0(15 DOWNTO 8) & Flash0_0(23 DOWNTO 16) & Flash0_0(31 DOWNTO 24);
                 WHEN "010000001" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= Flash0_1(39 DOWNTO 32) & Flash0_1(47 DOWNTO 40) & Flash0_1(55 DOWNTO 48) & Flash0_1(63 DOWNTO 56) & Flash0_1(7 DOWNTO 0) & Flash0_1(15 DOWNTO 8) & Flash0_1(23 DOWNTO 16) & Flash0_1(31 DOWNTO 24);
                 WHEN "010100000"|"010100001"|"010100010"|"010100011"|"010100100"|"010100101"|"010100110"|"010100111"|"010101000"|"010101001"|"010101010"|"010101011"|"010101100"|"010101101"|"010101110"|"010101111"|"010110000"|"010110001"|"010110010"|"010110011"|"010110100"|"010110101"|"010110110"|"010110111"|"010111000"|"010111001"|"010111010"|"010111011"|"010111100"|"010111101"|"010111110"|"010111111" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= Flash_0_RAM_Data;
                 WHEN "100000000" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= FPGA_0(39 DOWNTO 32) & FPGA_0(47 DOWNTO 40) & FPGA_0(55 DOWNTO 48) & FPGA_0(63 DOWNTO 56) & FPGA_0(7 DOWNTO 0) & FPGA_0(15 DOWNTO 8) & FPGA_0(23 DOWNTO 16) & FPGA_0(31 DOWNTO 24);
                 WHEN "100000001" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= FPGA_1(39 DOWNTO 32) & FPGA_1(47 DOWNTO 40) & FPGA_1(55 DOWNTO 48) & FPGA_1(63 DOWNTO 56) & FPGA_1(7 DOWNTO 0) & FPGA_1(15 DOWNTO 8) & FPGA_1(23 DOWNTO 16) & FPGA_1(31 DOWNTO 24);
                 WHEN "100100000"|"100100001"|"100100010"|"100100011"|"100100100"|"100100101"|"100100110"|"100100111"|"100101000"|"100101001"|"100101010"|"100101011"|"100101100"|"100101101"|"100101110"|"100101111"|"100110000"|"100110001"|"100110010"|"100110011"|"100110100"|"100110101"|"100110110"|"100110111"|"100111000"|"100111001"|"100111010"|"100111011"|"100111100"|"100111101"|"100111110"|"100111111" =>
                    UART_0_TS <= '0';
                    UART_1_TS <= '0';
                    Member_Data <= FPGA_0_RAM_Data;
                 WHEN OTHERS =>
                    Member_Data <= (OTHERS => '0');
              END CASE;
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              Config_WR_Port_INT <= Config_RD_Port;
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSIF (UART_0_Delay_Ready = '1') THEN
              UART_0_Delay_Ready <= '0';
              UART_0_TS <= '1';
              UART_1_TS <= '0';
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              Member_Data <= UART_0_RD_Data(39 DOWNTO 32) & UART_0_RD_Data(47 DOWNTO 40) & UART_0_RD_Data(55 DOWNTO 48) & UART_0_RD_Data(63 DOWNTO 56) & UART_0_RD_Data(7 DOWNTO 0) & UART_0_RD_Data(15 DOWNTO 8) & UART_0_RD_Data(23 DOWNTO 16) & UART_0_RD_Data(31 DOWNTO 24);
              Config_WR_Port_INT <= Config_RD_Port;
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSIF (UART_1_Delay_Ready = '1') THEN
              UART_1_Delay_Ready <= '0';
              UART_0_TS <= '0';
              UART_1_TS <= '1';
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              Member_Data <= UART_1_RD_Data(39 DOWNTO 32) & UART_1_RD_Data(47 DOWNTO 40) & UART_1_RD_Data(55 DOWNTO 48) & UART_1_RD_Data(63 DOWNTO 56) & UART_1_RD_Data(7 DOWNTO 0) & UART_1_RD_Data(15 DOWNTO 8) & UART_1_RD_Data(23 DOWNTO 16) & UART_1_RD_Data(31 DOWNTO 24);
              Config_WR_Port_INT <= Config_RD_Port;
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSIF (PPC_Dock.Router_Data.AD(8 DOWNTO 5) = "0011") THEN
              UART_0_TS <= '0';
              UART_1_TS <= '0';
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              UART_0_Delay_Ready <= '0';
              UART_1_Delay_Ready <= '0';
              Member_Data <= Boot_0_RAM_Data;
              ------------- 
              ------------- Debug QFU, 25.06.09
              Config_WR_Port_INT <= Config_RD_Port;
              ------------- Debug QFU, 25.06.09 END
              -------------
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSIF (PPC_Dock.Router_Data.AD(8 DOWNTO 5) = "0101") THEN
              UART_0_TS <= '0';
              UART_1_TS <= '0';
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              UART_0_Delay_Ready <= '0';
              UART_1_Delay_Ready <= '0';
              Member_Data <= Flash_0_RAM_Data;
              ------------- 
              ------------- Debug QFU, 25.06.09
              Config_WR_Port_INT <= Config_RD_Port;
              ------------- Debug QFU, 25.06.09 END
              -------------
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSIF (PPC_Dock.Router_Data.AD(8 DOWNTO 5) = "1001") THEN
              UART_0_TS <= '0';
              UART_1_TS <= '0';
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              UART_0_Delay_Ready <= '0';
              UART_1_Delay_Ready <= '0';
              Member_Data <= FPGA_0_RAM_Data;
              ------------- 
              ------------- Debug QFU, 25.06.09
              Config_WR_Port_INT <= Config_RD_Port;
              ------------- Debug QFU, 25.06.09 END
              -------------
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSIF (Flash_Config_Terminated = '1') THEN
              Flash0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ------------- 
              ------------- Debug QFU, 25.06.09
              Config_WR_Port_INT <= Config_RD_Port;
              ------------- Debug QFU, 25.06.09 END
              -------------
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
--           ELSIF (Boot_Config_Terminated = '1') THEN
--              Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
--              ------------- 
--              ------------- Debug QFU, 25.06.09
--              Config_WR_Port_INT <= Config_RD_Port;
--              ------------- Debug QFU, 25.06.09 END
--              -------------
           ELSIF (FPGA_Config_Terminated = '1') THEN
              FPGA_0(7 DOWNTO 0) <= (OTHERS => '0');
              ------------- 
              ------------- Debug QFU, 25.06.09
              Config_WR_Port_INT <= Config_RD_Port;
              ------------- Debug QFU, 25.06.09 END
              -------------
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           ELSE
              UART_0_TS <= '0';
              UART_1_TS <= '0';
              UART_0_WE <= '0';
              UART_1_WE <= '0';
              UART_0_Delay_Ready <= '0';
              UART_1_Delay_Ready <= '0';
              Config_WR_Port_INT <= Config_RD_Port;
              --------------------
              -------------------- 26.06.09
              --------------------
              IF (Boot_Config_Terminated = '1') THEN
                 Boot0_0(7 DOWNTO 0) <= (OTHERS => '0');
              ELSE
                 Boot0_0(7 DOWNTO 0) <= Boot0_0(7 DOWNTO 0);
              END IF;
              --------------------
              -------------------- 26.06.09
              --------------------
           END IF;
       END IF;
   END PROCESS Access_Registers;
   
   
   PPC_Dock.Member_Data.Entity_Router_Data <= Member_Data;
   
   
   
   -- Concurrent Assignment Configuration Register
   Config_RD_Data <= Config_RD_Port;
   Config_WR_Port <= Config_WR_Port_INT;
   
   
   -- Concurrent Change direction
   Config_WR_Data <= PPC_Dock.Router_Data.Router_Entity_Data(39 DOWNTO 32) & PPC_Dock.Router_Data.Router_Entity_Data(47 DOWNTO 40) & PPC_Dock.Router_Data.Router_Entity_Data(55 DOWNTO 48) & PPC_Dock.Router_Data.Router_Entity_Data(63 DOWNTO 56) & PPC_Dock.Router_Data.Router_Entity_Data(7 DOWNTO 0) & PPC_Dock.Router_Data.Router_Entity_Data(15 DOWNTO 8) & PPC_Dock.Router_Data.Router_Entity_Data(23 DOWNTO 16) & PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 24);


   Boot_Flash_0_Buffer: TDP_Flash_RAM
   PORT MAP (
             address_a      => Boot_Internal_Address,
             address_b      => Boot_Config_Buffer_AD(7 DOWNTO 3),
             byteena_a      => PPC_Dock.Router_Data.BE,
             byteena_b      => (OTHERS => '0'),
             clock_a        => GCLK,
             clock_b        => GCLK,
             data_a         => PPC_Dock.Router_Data.Router_Entity_Data,
             data_b         => (OTHERS => '0'),
             wren_a         => Boot_0_WREN,
             wren_b         => '0',
             q_a            => Boot_0_RAM_Data,
             q_b            => Boot_Config_Data_INT
             );
             
             
   Boot_Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);
   Boot_Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);
   Boot_0_WREN <= (WE_INT AND NOT(PPC_Dock.Router_Data.AD(8)) AND NOT(PPC_Dock.Router_Data.AD(7)) AND PPC_Dock.Router_Data.AD(6) AND PPC_Dock.Router_Data.AD(5));
   
   -- Concurrent 1
   Boot_Config_Cmd <= Boot0_0(7 DOWNTO 0);
   Boot_Config_AD <= Boot0_0(55 DOWNTO 32);
   Boot_Config_Bytes <= Boot0_1(15 DOWNTO 8);
   
   
   
   -- Concurrent: We have to select the correct word within the 64Bit address of the RAM data based on the fact that it is not
   -- possible to instantiate RAM width the data width of 8 and 64Bit.
   Boot_RAM_MUX: PROCESS(Boot_Config_Buffer_AD(2 DOWNTO 0), Boot_Config_Data_INT)
   BEGIN
      CASE Boot_Config_Buffer_AD(2 DOWNTO 0) IS
         WHEN "000" =>
            Boot_Config_Data <= Boot_Config_Data_INT(31 DOWNTO 24);
         WHEN "001" =>
            Boot_Config_Data <= Boot_Config_Data_INT(23 DOWNTO 16);
         WHEN "010" =>
            Boot_Config_Data <= Boot_Config_Data_INT(15 DOWNTO 8);
         WHEN "011" =>
            Boot_Config_Data <= Boot_Config_Data_INT(7 DOWNTO 0);
         WHEN "100" =>
            Boot_Config_Data <= Boot_Config_Data_INT(63 DOWNTO 56);
         WHEN "101" =>
            Boot_Config_Data <= Boot_Config_Data_INT(55 DOWNTO 48);
         WHEN "110" =>
            Boot_Config_Data <= Boot_Config_Data_INT(47 DOWNTO 40);
         WHEN "111" =>
            Boot_Config_Data <= Boot_Config_Data_INT(39 DOWNTO 32);
         WHEN OTHERS =>
            NULL;
      END CASE;
   END PROCESS Boot_RAM_MUX; 
   

   Standard_Flash_0_Buffer: TDP_Flash_RAM
   PORT MAP (
             address_a      => Internal_Address,
             address_b      => Flash_Config_Buffer_AD(7 DOWNTO 3),
             byteena_a      => PPC_Dock.Router_Data.BE,
             byteena_b      => (OTHERS => '0'),
             clock_a        => GCLK,
             clock_b        => GCLK,
             data_a         => PPC_Dock.Router_Data.Router_Entity_Data,
             data_b         => (OTHERS => '0'),
             wren_a         => Flash_0_WREN,
             wren_b         => '0',
             q_a            => Flash_0_RAM_Data,
             q_b            => Flash_Config_Data_INT
             );
             
             
   Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);
   Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);
   Flash_0_WREN <= (WE_INT AND NOT(PPC_Dock.Router_Data.AD(8)) AND PPC_Dock.Router_Data.AD(7) AND NOT(PPC_Dock.Router_Data.AD(6)) AND PPC_Dock.Router_Data.AD(5));
   
   -- Concurrent 1
   Flash_Config_Cmd <= Flash0_0(7 DOWNTO 0);
   Flash_Config_AD <= Flash0_0(55 DOWNTO 32);
   Flash_Config_Bytes <= Flash0_1(15 DOWNTO 8);
   
   
   
   -- Concurrent: We have to select the correct word within the 64Bit address of the RAM data based on the fact that it is not
   -- possible to instantiate RAM width the data width of 8 and 64Bit.
   Flash_RAM_MUX: PROCESS(Flash_Config_Buffer_AD(2 DOWNTO 0), Flash_Config_Data_INT)
   BEGIN
      CASE Flash_Config_Buffer_AD(2 DOWNTO 0) IS
         WHEN "000" =>
            Flash_Config_Data <= Flash_Config_Data_INT(31 DOWNTO 24);
         WHEN "001" =>
            Flash_Config_Data <= Flash_Config_Data_INT(23 DOWNTO 16);
         WHEN "010" =>
            Flash_Config_Data <= Flash_Config_Data_INT(15 DOWNTO 8);
         WHEN "011" =>
            Flash_Config_Data <= Flash_Config_Data_INT(7 DOWNTO 0);
         WHEN "100" =>
            Flash_Config_Data <= Flash_Config_Data_INT(63 DOWNTO 56);
         WHEN "101" =>
            Flash_Config_Data <= Flash_Config_Data_INT(55 DOWNTO 48);
         WHEN "110" =>
            Flash_Config_Data <= Flash_Config_Data_INT(47 DOWNTO 40);
         WHEN "111" =>
            Flash_Config_Data <= Flash_Config_Data_INT(39 DOWNTO 32);
         WHEN OTHERS =>
            NULL;
      END CASE;
   END PROCESS Flash_RAM_MUX;
   
   
   

   FPGA_Flash_0_Buffer: TDP_Flash_RAM
   PORT MAP (
             address_a      => FPGA_Internal_Address,
             address_b      => FPGA_Config_Buffer_AD(7 DOWNTO 3),
             byteena_a      => PPC_Dock.Router_Data.BE,
             byteena_b      => (OTHERS => '0'),
             clock_a        => GCLK,
             clock_b        => GCLK,
             data_a         => PPC_Dock.Router_Data.Router_Entity_Data,
             data_b         => (OTHERS => '0'),
             wren_a         => FPGA_0_WREN,
             wren_b         => '0',
             q_a            => FPGA_0_RAM_Data,
             q_b            => FPGA_Config_Data_INT
             );
             
             
   FPGA_Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);
   FPGA_Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);
   FPGA_0_WREN <= (WE_INT AND PPC_Dock.Router_Data.AD(8) AND NOT(PPC_Dock.Router_Data.AD(7)) AND NOT(PPC_Dock.Router_Data.AD(6)) AND PPC_Dock.Router_Data.AD(5));
   
   -- Concurrent 1
   FPGA_Config_Cmd <= FPGA_0(7 DOWNTO 0);
   FPGA_Config_AD <= FPGA_0(55 DOWNTO 32);
   FPGA_Config_Bytes <= FPGA_1(15 DOWNTO 8);
   
   
   
   -- Concurrent: We have to select the correct word within the 64Bit address of the RAM data based on the fact that it is not
   -- possible to instantiate RAM width the data width of 8 and 64Bit.
   FPGA_RAM_MUX: PROCESS(FPGA_Config_Buffer_AD(2 DOWNTO 0), FPGA_Config_Data_INT)
   BEGIN
      CASE FPGA_Config_Buffer_AD(2 DOWNTO 0) IS
         WHEN "000" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(31 DOWNTO 24);
         WHEN "001" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(23 DOWNTO 16);
         WHEN "010" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(15 DOWNTO 8);
         WHEN "011" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(7 DOWNTO 0);
         WHEN "100" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(63 DOWNTO 56);
         WHEN "101" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(55 DOWNTO 48);
         WHEN "110" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(47 DOWNTO 40);
         WHEN "111" =>
            FPGA_Config_Data <= FPGA_Config_Data_INT(39 DOWNTO 32);
         WHEN OTHERS =>
            NULL;
      END CASE;
   END PROCESS FPGA_RAM_MUX; 
   
   
   
   
   

   -- Concurrent group assignments
   SIO_nTX <= NOT(TX_INT);
   SIO_RX_INT <= NOT(SIO_nRX);
   SIO_nDSR_INT <= NOT(SIO_nDSR);
   SIO_nDTR <= NOT(SIO_nDTR_INT);
   
   
   UART_BE_Delay: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         UART_BE <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         UART_BE <= PPC_Dock.Router_Data.BE(4) & PPC_Dock.Router_Data.BE(5) & PPC_Dock.Router_Data.BE(6) & PPC_Dock.Router_Data.BE(7) & PPC_Dock.Router_Data.BE(0) & PPC_Dock.Router_Data.BE(1) & PPC_Dock.Router_Data.BE(2) & PPC_Dock.Router_Data.BE(3);
      END IF;
   END PROCESS UART_BE_Delay;
   

   -- Concurrent
   UART_WR_Data <= PPC_Dock.Router_Data.Router_Entity_Data(39 DOWNTO 32) &  PPC_Dock.Router_Data.Router_Entity_Data(47 DOWNTO 40) & PPC_Dock.Router_Data.Router_Entity_Data(55 DOWNTO 48) & PPC_Dock.Router_Data.Router_Entity_Data(63 DOWNTO 56) & PPC_Dock.Router_Data.Router_Entity_Data(7 DOWNTO 0) & PPC_Dock.Router_Data.Router_Entity_Data(15 DOWNTO 8) & PPC_Dock.Router_Data.Router_Entity_Data(23 DOWNTO 16) & PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 24);


   --------
   -- COM 0
   --------
   SIO_0: UART_16550
   PORT MAP (
             GCLK    => GCLK,
             BRCLK   => BRCLK,
             CLR_n   => CLR_n,
             CS      => UART_0_TS, 
             WR      => UART_0_WE,
             BE      => UART_BE,
             WR_Data => UART_WR_Data,

             sRX     => SIO_RX_INT(0),
             CTSn    => '0', -- clear to send
             DSRn    => SIO_nDSR_INT(0),--SIO_nDSR(0),
             RIn     => SIO_SEL(0),
             DCDn    => '0', -- data carrier detect

             sTX     => TX_INT(0), -- has to be inverted
             DTRn    => SIO_nDTR_INT(0),--SIO_nDTR(0),
             RTSn    => OPEN,
             OUT1n   => SIO_EN(0),
             OUT2n   => OPEN,
             TXRDYn  => OPEN,
             RXRDYn  => OPEN,

             IRQ     => UART_0_IRQ,
             BCLK    => OPEN,
             RD_Data => UART_0_RD_Data
             );
   ------------
   -- COM 0 END
   ------------


   --------
   -- COM 1
   --------
   SIO_1: UART_16550
   PORT MAP (
             GCLK    => GCLK,
             BRCLK   => BRCLK,
             CLR_n   => CLR_n,
             CS      => UART_1_TS,
             WR      => UART_1_WE,
             BE      => UART_BE,
             WR_Data => UART_WR_Data,

             sRX     => SIO_RX_INT(1),
             CTSn    => '0', -- clear to send
             DSRn    => SIO_nDSR_INT(1),--SIO_nDSR(1),
             RIn     => SIO_SEL(1),
             DCDn    => '0', -- data carrier detect

             sTX     => TX_INT(1), -- has to be inverted
             DTRn    => SIO_nDTR_INT(1),--SIO_nDTR(1),
             RTSn    => OPEN,
             OUT1n   => SIO_EN(1),
             OUT2n   => OPEN,
             TXRDYn  => OPEN,
             RXRDYn  => OPEN,

             IRQ     => UART_1_IRQ,
             BCLK    => OPEN,
             RD_Data => UART_1_RD_Data
             );
   ------------
   -- COM 1 END
   ------------

END ARCHITECTURE Universal;