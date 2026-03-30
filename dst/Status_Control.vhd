-- MODULE Status Control
-- VHDL Architecture Indel_lib.Status_Control.Universal
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

ENTITY Status_Control IS
   PORT    (
            GCLK                       : IN    std_logic;
            CLR_n                      : IN    std_logic;
            PPC_Dock                   : INOUT router_dock_t_s_pkg;
            InfoLink_Job_IRQ_EN        : OUT   std_logic;
            InfoLink_RXC_IRQ_EN        : OUT   std_logic;
            InfoLink_TX_RX_Seq_Restart : OUT   std_logic;
            InfoLink_Run_EN            : OUT   std_logic;
            InfoLink_OverRun_EN        : OUT   std_logic;
            InfoLink_Job_IRQ           : IN    std_logic;
            InfoLink_RXC_IRQ           : IN    std_logic;
            InfoLink_RX_Error          : IN    std_logic;
            InfoLink_OverRun           : IN    std_logic;
            InfoLink_Or1ms             : IN    std_logic;
            InfoLink_LED_REC           : IN    std_logic;
            LED_OK                     : OUT   std_logic;
            LED_Error                  : OUT   std_logic;
            SD_SCL_OUT                 : OUT   std_logic;
            SD_SDA_IN                  : IN    std_logic;
            SD_SDA_OUT                 : OUT   std_logic;
            FPGA_SCL_OUT               : OUT   std_logic;
            FPGA_SDA_IN                : IN    std_logic;
            FPGA_SDA_OUT               : OUT   std_logic;
            RTC_SCL_OUT                : OUT   std_logic;
            RTC_SDA_IN                 : IN    std_logic;
            RTC_SDA_OUT                : OUT   std_logic;
            FPGA_VBAT                  : IN    std_logic;
            FAN_Toggle                 : OUT   std_logic;
            FPGA_FAN                   : OUT   std_logic
            );
END ENTITY Status_Control;


ARCHITECTURE Universal OF Status_Control IS
   CONSTANT Delay                             : natural := 1;
   CONSTANT Memory_Width                      : natural := 10;
   SIGNAL   Burst_Vector                      : burst_address_t_s_pkg;
   SIGNAL   Burst_Counter                     : natural RANGE 0 TO 2;
   SIGNAL   Burst_OnGoing                     : std_logic;
   SIGNAL   EN_Delay_Counter                  : std_logic;
   SIGNAL   Wait_For_Data_On_Bus              : std_logic;
   SIGNAL   Wait_For_Burst_WR                 : std_logic;
   SIGNAL   WE_INT                            : std_logic;
   SIGNAL   WE_INT_INT                        : std_logic;
   SIGNAL   WE_INT_INT_INT                    : std_logic;
   SIGNAL   WE_Burst_INT                      : std_logic;
   SIGNAL   Internal_Address                  : std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   SIGNAL   Member_Data                       : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   Write_Registers_BE                : std_logic_vector(7 DOWNTO 0);
   SIGNAL   Register_AD_FC000000              : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   Register_AD_FC000008              : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   Register_AD_FC000000_INT          : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   Register_AD_FC000008_INT          : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   I2C_SDA_IN                        : std_logic; -- Combined internal I2C bus SDA line (consists of the external RTC and FPGA SDA lines).
   SIGNAL   Access_FC00000008_Toggle_INT      : std_logic;
   SIGNAL   Saved_Access_FC00000008_Toggle    : std_logic;
   SIGNAL   FAN_Toggle_INT                    : std_logic;
   SIGNAL   LED_Error_INT                     : std_logic;
   SIGNAL   LED_OK_INT                        : std_logic;
   SIGNAL   FPGA_FAN_INT                      : std_logic;


BEGIN


   -- Concurrent Assignments
   SD_SCL_OUT <= Register_AD_FC000000(1);-- 0xFC000000 (1)
   SD_SDA_OUT <= Register_AD_FC000000(2);-- 0xFC000000 (2)
   
   FPGA_SCL_OUT <= Register_AD_FC000000(9);-- 0xFC000001 (1)
   FPGA_SDA_OUT <= Register_AD_FC000000(10);-- 0xFC000001 (2)
   
   RTC_SCL_OUT <= Register_AD_FC000000(9);-- 0xFC000001 (1)
   RTC_SDA_OUT <= Register_AD_FC000000(10);-- 0xFC000001 (2)
   
   
   --FPGA_FAN <= Register_AD_FC000008(8); --Debug QFU, 18.12.2008
   
   FPGA_FAN <= FPGA_FAN_INT;
   
   FAN_Toggle <= FAN_Toggle_INT;
   
   
   -- Concurrent combine FPGA- and RTC-I2C busses
   -- To save battery power if the SAM is not running, the RTC has it's own I2C bus, which we combine in the FPGA with the EEPROM and LM75 I2C bus.
   I2C_SDA_IN <= (FPGA_SDA_IN AND RTC_SDA_IN);
   
   InfoLink_Job_IRQ_EN <= Register_AD_FC000008(0);
   InfoLink_RXC_IRQ_EN <= Register_AD_FC000008(4);
   InfoLink_TX_RX_Seq_Restart <= Register_AD_FC000008(5);
   InfoLink_Run_EN <= Register_AD_FC000008(6);
   InfoLink_OverRun_EN <= Register_AD_FC000008(7);
   
   --LED_Error <= Register_AD_FC000008(12);
   --LED_OK <= Register_AD_FC000008(13);
   
   
   LED_Error <= LED_Error_INT;
   LED_OK <= LED_OK_INT;
   
   
   
   ------------------------------------------------------------------------------------------
   -- Access Control for the FAN: We have to make sure that the software can disable the FAN,
   -- but we detect a not running 1ms...
   ------------------------------------------------------------------------------------------
   Detect_FAN_Access: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Saved_Access_FC00000008_Toggle <= '0';
         LED_Error_INT <= '0';
         LED_OK_INT <= '0';
         FPGA_FAN_INT <= '0';
         FAN_Toggle_INT <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         LED_Error_INT <= Register_AD_FC000008(12);
         LED_OK_INT <= Register_AD_FC000008(13);
         FPGA_FAN_INT <= Register_AD_FC000008(8);
         IF (Access_FC00000008_Toggle_INT /= Saved_Access_FC00000008_Toggle) THEN
            IF (((Register_AD_FC000008(12) /= LED_Error_INT) OR (Register_AD_FC000008(13) /= LED_OK_INT)) AND (Register_AD_FC000008(8) = FPGA_FAN_INT)) THEN
               FAN_Toggle_INT <= FAN_Toggle_INT;
            ELSE
               FAN_Toggle_INT <= NOT(FAN_Toggle_INT);
            END IF;
            Saved_Access_FC00000008_Toggle <= Access_FC00000008_Toggle_INT;
         ELSE
            Saved_Access_FC00000008_Toggle <= Saved_Access_FC00000008_Toggle;
            FAN_Toggle_INT <= FAN_Toggle_INT;
         END IF;
      END IF;
   END PROCESS Detect_FAN_Access;
   


   -- ---------------------------------------------------------------------------------------------
   -- Remarks Reading (if **_INT is directly connected to PPC_Dock.Member_Data.Entity_Router_Data):
   -- ---------------------------------------------------------------------------------------------
   -- Register_AD_FC000000_INT(31 DOWNTO 24): 0xFC000000 (76543210)
   -- Register_AD_FC000000_INT(23 DOWNTO 16): 0xFC000001 (76543210)
   -- Register_AD_FC000000_INT(15 DOWNTO 8): 0xFC000002 (76543210)
   -- Register_AD_FC000000_INT(7 DOWNTO 0): 0xFC000003 (76543210)
   -- Register_AD_FC000000_INT(63 DOWNTO 56): 0xFC000004 (76543210)
   -- Register_AD_FC000000_INT(55 DOWNTO 48): 0xFC000005 (76543210)
   -- Register_AD_FC000000_INT(47 DOWNTO 40): 0xFC000006 (76543210)
   -- Register_AD_FC000000_INT(39 DOWNTO 32): 0xFC000007 (76543210)
   
   -- Register_AD_FC000008_INT(31 DOWNTO 24): 0xFC000008 (76543210)
   -- Register_AD_FC000008_INT(23 DOWNTO 16): 0xFC000009 (76543210)
   -- Register_AD_FC000008_INT(15 DOWNTO 8): 0xFC00000A (76543210)
   -- Register_AD_FC000008_INT(7 DOWNTO 0): 0xFC00000B (76543210)
   -- Register_AD_FC000008_INT(63 DOWNTO 56): 0xFC00000C (76543210)
   -- Register_AD_FC000008_INT(55 DOWNTO 48): 0xFC00000D (76543210)
   -- Register_AD_FC000008_INT(47 DOWNTO 40): 0xFC00000E (76543210)
   -- Register_AD_FC000008_INT(39 DOWNTO 32): 0xFC00000F (76543210)
   -- ---------------------------------------------------------------------------------------------
   --
   -- ---------------------------------------------------------------------------------------------
   
   
   Assign_Read_Register: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         -- Addresses 0xFC000000 to 0xFC000007:
         Register_AD_FC000000_INT(48) <= '0'; -- 0xFC000005 (0), FPGA_VBAT
         Register_AD_FC000000_INT(50) <= '0'; -- 0xFC000005 (2), InfoLink_REC
         Register_AD_FC000000_INT(26 DOWNTO 25) <= (OTHERS => '0'); -- 0xFC000000 (21), I2C SDRAM
         Register_AD_FC000000_INT(18 DOWNTO 17) <= (OTHERS => '0'); -- 0xFC000001 (21), I2C FPGA
         -- Addresses 0xFC000008 to 0xFC00000F:
         Register_AD_FC000008_INT(24) <= '0'; -- 0xFC000008 (0), InfoLink_Job_IRQ_EN
         Register_AD_FC000008_INT(31 DOWNTO 28) <= (OTHERS => '0'); -- 0xFC000008 (7654), (InfoLink_OverRun_EN & InfoLink_Run_EN & InfoLink_TX_RX_Seq_Restart & InfoLink_RXC_IRQ & InfoLink_RXC_IRQ)
         Register_AD_FC000008_INT(16) <= '0'; -- 0xFC000009 (1), Fan, actually not connected
         Register_AD_FC000008_INT(21 DOWNTO 20) <= (OTHERS => '0'); -- 0xFC000009 (54), (LED_OK & LED_Error)
         Register_AD_FC000008_INT(56) <= '0'; -- 0xFC00000C (0), InfoLink_Job_IRQ
         Register_AD_FC000008_INT(63 DOWNTO 60) <= (OTHERS => '0'); -- 0xFC00000C (7654), (InfoLink_Or1ms & InfoLink_OverRun & InfoLink_RX_Error & )
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         -- Addresses 0xFC000000 to 0xFC000007:
         Register_AD_FC000000_INT(26 DOWNTO 25) <= (SD_SDA_IN & Register_AD_FC000000(1)); -- 0xFC000000 (21), I2C SDRAM
         Register_AD_FC000000_INT(18 DOWNTO 17) <= (I2C_SDA_IN & Register_AD_FC000000(9)); -- 0xFC000001 (21), I2C FPGA
         Register_AD_FC000000_INT(48) <= NOT(FPGA_VBAT); -- 0xFC000005 (0), FPGA_VBAT
         Register_AD_FC000000_INT(50) <= InfoLink_LED_REC; -- 0xFC000005 (2), InfoLink_REC LED
         -- Addresses 0xFC000008 to 0xFC00000F:
         Register_AD_FC000008_INT(24) <= Register_AD_FC000008(0); -- 0xFC000008 (0), InfoLink_Job_IRQ_EN
         Register_AD_FC000008_INT(31 DOWNTO 28) <= (Register_AD_FC000008(7) & Register_AD_FC000008(6) & Register_AD_FC000008(5) & Register_AD_FC000008(4)); -- 0xFC000008 (7654), (InfoLink_OverRun_EN & InfoLink_Run_EN & InfoLink_TX_RX_Seq_Restart & InfoLink_RXC_IRQ
         Register_AD_FC000008_INT(16) <= Register_AD_FC000008(8); -- 0xFC000009 (1), Fan
         Register_AD_FC000008_INT(21 DOWNTO 20) <= (Register_AD_FC000008(13) & Register_AD_FC000008(12)); -- 0xFC000009 (54), (LED_OK & LED_Error)
         Register_AD_FC000008_INT(56) <= InfoLink_Job_IRQ; -- 0xFC00000C (0), InfoLink_Job_IRQ
         Register_AD_FC000008_INT(63 DOWNTO 60) <= (InfoLink_Or1ms & InfoLink_OverRun & InfoLink_RX_Error & InfoLink_RXC_IRQ); -- 0xFC00000C (7654), (InfoLink_Or1ms & InfoLink_OverRun & InfoLink_RX_Error & InfoLink_RXC_IRQ)  
      END IF;
   END PROCESS Assign_Read_Register;
   
   
   -- Concurrent group (0xFC000000 - 0xFC000007)
   Register_AD_FC000000_INT(24) <= '0'; -- 0xFC000000 (0)
   Register_AD_FC000000_INT(31 DOWNTO 27) <= "00000"; -- 0xFC000000 (76543)
   Register_AD_FC000000_INT(15 DOWNTO 8) <= X"FF"; -- 0xFC000002 (76543210)
   Register_AD_FC000000_INT(7 DOWNTO 0) <= X"FF"; -- 0xFC000003 (76543210)
   Register_AD_FC000000_INT(63 DOWNTO 56) <= X"00"; -- 0xFC000004, if no test points (76543210)
   Register_AD_FC000000_INT(47 DOWNTO 40) <= X"FF"; -- 0xFC000006 (76543210)
   Register_AD_FC000000_INT(39 DOWNTO 32) <= X"FF"; -- 0xFC000007 (76543210)
   Register_AD_FC000000_INT(16) <= '0'; -- 0xFC000001 (0)
   Register_AD_FC000000_INT(23 DOWNTO 19) <= "00000"; -- 0xFC000001 (76543)
   Register_AD_FC000000_INT(49) <= '0'; -- 0xFC000005 (1)
   Register_AD_FC000000_INT(55 DOWNTO 51) <= "00000"; -- 0xFC000005 (76543)
   -- Concurrent group(0xFC000008 - 0xFC00000F)
   Register_AD_FC000008_INT(27 DOWNTO 25) <= "000"; -- 0xFC000008 (321)
   Register_AD_FC000008_INT(19 DOWNTO 17) <= "000"; -- 0xFC000009 (321)
   Register_AD_FC000008_INT(23 DOWNTO 22) <= "00"; -- 0xFC000009 (76)
   Register_AD_FC000008_INT(15 DOWNTO 8) <= X"FF"; -- 0xFC00000A (76543210)
   Register_AD_FC000008_INT(7 DOWNTO 0) <= X"FF"; -- 0xFC00000B (76543210)
   Register_AD_FC000008_INT(59 DOWNTO 57) <= "000"; -- 0xFC00000C (321)
   Register_AD_FC000008_INT(55 DOWNTO 48) <= X"00"; -- 0xFC00000D (76543210)
   Register_AD_FC000008_INT(47 DOWNTO 40) <= X"FF"; -- 0xFC00000E (76543210)
   Register_AD_FC000008_INT(39 DOWNTO 32) <= X"FF"; -- 0xFC00000F (76543210)


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
   PPC_Dock.Member_Data.Write_Delay <= '0';
   PPC_Dock.Member_Data.Slow_Burst <= '0';

   
   -- Internal Write Enable
   WR_Enable: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Wait_For_Data_On_Bus <= '0';
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


   WE_INT <= WE_INT_INT;

   Write_Registers: PROCESS(GCLK, CLR_n)
   BEGIN
       IF (CLR_n = '0') THEN
           Register_AD_FC000000 <= (OTHERS => '0');
           Register_AD_FC000008 <= (OTHERS => '0');
           Access_FC00000008_Toggle_INT <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
           IF (WE_INT = '1') THEN
              CASE PPC_Dock.Router_Data.AD(0) IS
                 WHEN '0' =>
                    IF (PPC_Dock.Router_Data.BE(2) = '1') THEN
                       Register_AD_FC000000(15 DOWNTO 8) <= PPC_Dock.Router_Data.Router_Entity_Data(23 DOWNTO 16);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN
                       Register_AD_FC000000(7 DOWNTO 0) <= PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 24);
                    END IF;
                 WHEN '1' =>
                    IF (PPC_Dock.Router_Data.BE(2) = '1') THEN
                       Register_AD_FC000008(15 DOWNTO 8) <= PPC_Dock.Router_Data.Router_Entity_Data(23 DOWNTO 16);
                       Access_FC00000008_Toggle_INT <= NOT(Access_FC00000008_Toggle_INT);
                    END IF;
                    IF (PPC_Dock.Router_Data.BE(3) = '1') THEN
                       Register_AD_FC000008(7 DOWNTO 0) <= PPC_Dock.Router_Data.Router_Entity_Data(31 DOWNTO 24);
                    END IF;
                 WHEN OTHERS =>
                    Register_AD_FC000000(15 DOWNTO 8) <= Register_AD_FC000000(15 DOWNTO 8);
                    Register_AD_FC000000(7 DOWNTO 0) <= Register_AD_FC000000(7 DOWNTO 0);
                    Register_AD_FC000008(15 DOWNTO 8) <= Register_AD_FC000008(15 DOWNTO 8);
                    Register_AD_FC000008(7 DOWNTO 0) <= Register_AD_FC000008(7 DOWNTO 0);
                    Access_FC00000008_Toggle_INT <= Access_FC00000008_Toggle_INT;
              END CASE;
           END IF;
           Register_AD_FC000000(63 DOWNTO 16) <= (OTHERS => '0');
           Register_AD_FC000008(63 DOWNTO 16) <= (OTHERS => '0');
       END IF;
   END PROCESS Write_Registers;
   
   
   Read_Registers: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Member_Data <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF  (((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) OR ((Burst_OnGoing = '1') AND (WE_INT = '0'))) THEN
            CASE PPC_Dock.Router_Data.AD(0) IS
               WHEN '0' =>
                  Member_Data <= (Register_AD_FC000000_INT(63 DOWNTO 26) & Register_AD_FC000000(1) & Register_AD_FC000000_INT(24 DOWNTO 18) & Register_AD_FC000000(9) & Register_AD_FC000000_INT(16 DOWNTO 0));
               WHEN '1' =>
                  --Member_Data <= Register_AD_FC000008_INT; -- Debug QFU, 24.02.2009
                  Member_Data <= (Register_AD_FC000008_INT(63 DOWNTO 22) & Register_AD_FC000008(13) & Register_AD_FC000008(12) & Register_AD_FC000008_INT(19 DOWNTO 0));
               WHEN OTHERS =>
                  NULL;
            END CASE;
         END IF;
      END IF;
   END PROCESS Read_Registers;
   
   PPC_Dock.Member_Data.Entity_Router_Data <= Member_Data;


END ARCHITECTURE Universal;