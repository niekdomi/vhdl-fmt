-- MODULE Configuration Control
-- VHDL Architecture Indel_lib.Configuration_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- This entity is used to manage the loading of different FPGA designs.       --
-- There is dedicated hardware in the SAM3 FPGA, that allows- after a         --
-- factory design is loaded into the FPGA- to select the needed application   --
-- based on the running design. In addition- if there goes something wrong    --
-- with the downloading procedure of a new application, the FPGA falls always --
-- back to the default (factory) configuration Config_0_Factory.              -- 
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG01: 23.12.2008:   Initial version.                                       --
--                                                                            --
-- -------------------------------------------------------------------------- --

-- -------------------------------------------------------------------------- --
-- Notes:                                                                     --
-- Idea: We locate a pseudo Boot Map for the FPGA in the SPI flash. 0xFFFFFF  --
-- contains only the selector for the appropriate system (0x5 + 0 to 7). If   --
-- the number is not correctly formated, the Factory System remains activated.--
-- The software can overwrite the Boot-Vector at address 0xFFFFFF. This is a  --
-- logical not a physical address that is mapped in the FPGA based on the SPI --
-- size ID. The number at this address is read by the Factory System during   --
-- startup and written to the config register of the remote update block.     --
-- After arming the WatchDog_Counter and setting the application Bit, the     --
-- Factory System initiates a reboot at the specified start address. In       --
-- addition to the vector the version of each configuration mapping, the      --
-- configuration, FPGA_Rev and other data can be found there. Based on the    --
-- fact that this data is not in the remote update block, it can be read by   --
-- the SW, too. This means it would be possible to see in the INCO Explorer   --
-- which FPGA configurations are available on this master. The SW can         --
-- initiate a reboot into another system. But based on the fact that this is  --
-- only possible via Factory System, a new downloaded system can be marked as --
-- corrupted in the Boot Table so that it can be seen by the SW, too.         --
-- The entries within the configuration table are updated as soon as an       --
-- Application System runs successful for the first time. This way round we   --
-- can check if a system booted at least one time successfully. The vector is --
-- the only data in the top most block, so that it can be erased with the     --
-- block erase command by the FSM. Every system that should have the          --
-- possibility to change the running application, needs to erase the top most --
-- block. Config data in ROM?- Perhaps the simplest possibility.              --
-- -------------------------------------------------------------------------- --

-- -------------------------------------------------------------------------- --
-- Remark: Actually we are using slow accesses for the FPGA reads,            --
-- based on the fact that I can not assign the timing to the internal ASMI HW --
-- block with a frequency higher than 40 MHz.                                 --
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
USE Indel_lib.Arria_GX_Package.all;
USE Indel_lib.SPI_Package.all;
-------------------------------
-- Entity library inclusion END
-------------------------------




--------------------------------------------------------------------------------
-- Entity declaration
--------------------------------------------------------------------------------
ENTITY Configuration_Control IS
   PORT  (
          GCLK                   : IN    std_logic;
          CLK62_5                : IN    std_logic;
          RU_CLK                 : IN    std_logic; -- Remote Update Clock, fmax ca. 40MHz, not specified!!!!
          CLR_n                  : IN    std_logic;
          PPC_Dock               : INOUT router_dock_t_s_pkg;
          -- FPGA Configuration signals
          FPGA_Config_Cmd        : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
          FPGA_Config_AD         : IN    std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
          FPGA_Config_Bytes      : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
          FPGA_Config_Data       : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
          FPGA_Config_Buffer_AD  : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
          FPGA_Config_Status     : OUT   std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
          FPGA_Config_Terminated : OUT   std_logic;
          -- Remote Update Status
          RU_Status              : OUT   std_logic_vector(7 DOWNTO 0)
          );
END ENTITY Configuration_Control;



ARCHITECTURE Universal OF Configuration_Control IS

   -------------------
   -- Type Declaration
   -------------------
   TYPE STATE_TYPE IS
      (
       Init,
       Start,
       Write_Protect,
       s0,
       s1,
       s2,
       s3,
       s4,
       s5,
       s6,
       s6_Debug0,
       s6_Debug1,
       s6_Debug2,
       s6_Debug3,
       s6_Debug4,
       s6_Debug5,
       s6_Debug6,
       s6_Debug7,
       s6_Debug8,
       s6_Debug9,
       s6_Debug10,
       s6_Debug11,
       s7,
       s8,
       s9,
       s10,
       s11,
       s12,
       s13,
       s14,
       s15,
       s16,
       s17,
       s18,
       s19,
       s20,
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

   ---------------------------
   -- Constant Declaration END
   ---------------------------


   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL current_state              : STATE_TYPE;
   SIGNAL next_state                 : STATE_TYPE;
   SIGNAL RUpdate_Data_In            : std_logic_vector(11 DOWNTO 0);
   SIGNAL RUpdate_Param              : std_logic_vector(2 DOWNTO 0);
   SIGNAL RUpdate_Read_Param         : std_logic;
   SIGNAL RUpdate_Write_Param        : std_logic;
   SIGNAL RUpdate_Reconfig           : std_logic;
   SIGNAL RUpdate_Reset              : std_logic;
   SIGNAL RUpdate_Reset_Timer        : std_logic;
   SIGNAL RUpdate_Busy               : std_logic;
   SIGNAL RUpdate_Data_Out           : std_logic_vector(11 DOWNTO 0);
   SIGNAL RUpdate_Configuration      : arria_rublock_config_bundle_t_a_pkg;
   SIGNAL FPGA_WDI                   : std_logic;
   SIGNAL ASMI_nCS                   : std_logic;
   SIGNAL ASMI_CLK                   : std_logic;
   SIGNAL ASMI_DIN                   : std_logic;
   SIGNAL ASMI_DOUT                  : std_logic;
   SIGNAL CLK_EN                     : std_logic;
   SIGNAL Run_AC                     : std_logic;
   SIGNAL Bit_Cnt                    : natural RANGE 0 TO 7;
   SIGNAL ASMI_Stop                  : std_logic;
   SIGNAL ASMI_Init_Done             : std_logic;
   SIGNAL ASMI_Start_Transfer        : std_logic;
   SIGNAL ASMI_Start_Transfer_Config : std_logic;
   SIGNAL ASMI_Start_Transfer_Space  : std_logic;
   SIGNAL ASMI_Update_Data           : std_logic;
   SIGNAL ASMI_Read_Data             : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
   SIGNAL ASMI_Write_Data            : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
   SIGNAL ASMI_Wait                  : std_logic;
   SIGNAL ASMI_AD                    : std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
   SIGNAL ASMI_Space_AD              : std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
   SIGNAL ASMI_Words                 : natural RANGE 0 TO 65535;
   SIGNAL ASMI_Space_Words           : natural RANGE 0 TO 65535;
   SIGNAL ASMI_SPI_Mode_0            : std_logic_vector(7 DOWNTO 0);
   SIGNAL ASMI_Read_Data_Turned      : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
   SIGNAL Config_Termination         : std_logic;
   SIGNAL Flash_Boot_Startaddress    : std_logic_vector(6 DOWNTO 0);
   SIGNAL Start_Write_Protect        : std_logic;
   SIGNAL Local_FPGA_Config_Cmd      : std_logic_vector(7 DOWNTO 0);
   SIGNAL Local_FPGA_Config_Data     : std_logic_vector(7 DOWNTO 0);
   SIGNAL FPGA_Config_Terminated_Int : std_logic;
   SIGNAL Write_Protected            : std_logic;
   -------------------------
   -- Signal Declaration END
   -------------------------
   
   ------------------------
   -- Component Declaration
   ------------------------  
   COMPONENT General_WatchDog_Counter
      PORT    ( 
               SCLK          : IN     std_logic;
               CLR_n         : IN     std_logic;
               FPGA_WDI      : OUT    std_logic
               );
   END COMPONENT General_WatchDog_Counter;
   
   
   -- Remote update hardware block of the Arria GX FPGA.
   COMPONENT ASMI_Update
      PORT    (
               Clock         : IN     std_logic ;
               Data_in       : IN     std_logic_vector(11 DOWNTO 0);
               Param         : IN     std_logic_vector(2 DOWNTO 0);
               Read_param    : IN     std_logic ;
               Reconfig      : IN     std_logic ;
               Reset         : IN     std_logic ;
               Reset_timer   : IN     std_logic ;
               Write_param   : IN     std_logic ;
               Busy          : OUT    std_logic ;
               Data_out      : OUT    std_logic_vector(11 DOWNTO 0)
               );
   END COMPONENT ASMI_Update;
   
   
   COMPONENT SPI_Space_Control
      GENERIC (
               Fast_Read                  : IN    boolean
               );
      PORT    (
               GCLK                       : IN    std_logic; -- System Clock
               CLR_n                      : IN    std_logic; -- Deglitched external reset
               -- Router Dock signal
               PPC_Dock                   : INOUT router_dock_t_s_pkg;
               -- Access signals
               Flash_SPI_Init_Done        : IN    std_logic;
               Flash_SPI_WREN             : IN    std_logic;
               Flash_SPI_Wait             : IN    std_logic;
               Flash_SPI_RD_Data          : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               Flash_SPI_WR_Data          : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               Flash_SPI_Mode_0           : OUT   std_logic_vector(7 DOWNTO 0);
               Flash_Start_Access         : OUT   std_logic;
               Flash_SPI_Requested_Words  : OUT   natural RANGE 0 TO 65535 := 8;
               Flash_SPI_Access_AD        : OUT   std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
               -- Config signals
               Flash_Config_Cmd           : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               Flash_Config_AD            : IN    std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
               Flash_Config_Bytes         : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               Flash_Config_Data          : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               Flash_Config_Buffer_AD     : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               Flash_Config_Status        : OUT   std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
               Flash_Config_Terminated    : OUT   std_logic
               );
   END COMPONENT SPI_Space_Control;


   COMPONENT SPI_Access
      GENERIC (
               Fast_Read     : IN    boolean;
               Dual_IO       : IN    boolean
               );
      PORT    (
               GCLK          : IN     std_logic;
               CLR_n         : IN     std_logic;
               -- Signals at the PPC side.
               Start_Transfer: IN     std_logic := '0';
               nSuspend      : IN     std_logic; -- Interrupt actual transfer for one with higher priority. ((1))
               Mode          : IN     std_logic_vector(7 DOWNTO 0);
               Words         : IN     natural RANGE 0 TO 65535; -- If number of words = 0 -> read continuously.
               Address       : IN     std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
               DIN           : IN     std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               SPI_Init_Done : OUT    std_logic; -- The SPI bus was synchronized
               Busy          : OUT    std_logic;
               Update        : OUT    std_logic;
               SPI_Wait      : OUT    std_logic;
               Actual_Word   : OUT    natural RANGE 0 TO 65535;
               DOUT          : OUT    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
               -- The Clock Control interface
               SPI_CLK       : IN     std_logic; -- Global SPI clock
               CLK_EN        : IN     std_logic; -- Clock enable signal for the Access Controllers
               Run_AC        : IN     std_logic; -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
               Bit_Cnt       : IN     natural RANGE 0 TO 7; -- Which Bit should actually be in work?
               SPI_Stop      : OUT    std_logic; -- Is the actual bus transfer terminated or not?
               -- The Flash Device side.
               SPI_DOUT_DIN  : INOUT  std_logic; --!!--
               SPI_nCS       : OUT    std_logic;
               SPI_DIN_DOUT  : INOUT  std_logic --!!--
               );
   END COMPONENT SPI_Access;
   
   
   -- ASMI interface and JTAG bridge
   COMPONENT ASMI_Atom IS
      GENERIC (
               ASMI_JTAG_Bridge_EN  : IN  natural:= 0; -- Do we need the bridge functionality?
               ASMI_Access_EN       : IN  natural:= 1 -- Is ASMI access from the user logic needed?
               );
      PORT    (
               ASMI_ASDO            : IN  std_logic;
               ASMI_Access_Granted  : IN  std_logic;
               ASMI_DCLK            : IN  std_logic;
               ASMI_CS_n            : IN  std_logic;
               ASMI_OE_n            : IN  std_logic;
               ASMI_Data0           : OUT std_logic;
               ASMI_Access_Request  : OUT std_logic
               );
   END COMPONENT ASMI_Atom;
   
   
   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : General_WatchDog_Counter USE ENTITY Indel_lib.General_WatchDog_Counter;
   FOR ALL : ASMI_Update USE ENTITY Indel_lib.ASMI_Update;
   FOR ALL : SPI_Space_Control USE ENTITY Indel_lib.SPI_Space_Control;
   FOR ALL : SPI_Access USE ENTITY Indel_lib.SPI_Access;
   FOR ALL : ASMI_Atom USE ENTITY Indel_lib.ASMI_Atom;
   -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------
   
   
BEGIN


   -- Concurrent 0
   RUpdate_Reset <= NOT(CLR_n);
   RUpdate_Reset_Timer <= FPGA_WDI;
   
   -- Concurrent 1
   RU_Status <= ('0' & RUpdate_Configuration.Configuration_Mode_A_nF & RUpdate_Configuration.Watchdog_EN & RUpdate_Configuration.Reconfig_Trigger_Condition);


   -- Our WatchDog Counter: Output frequency = 62.5/14 = 4.4642 MHz
   FPGA_WatchDog_Counter: General_WatchDog_Counter
      PORT MAP   ( 
                  SCLK        => RU_CLK,
                  CLR_n       => CLR_n,
                  FPGA_WDI    => FPGA_WDI
                  );


   -- The Remote Update block for the FPGA in active serial mode.
   ASMI_Remote_Update: ASMI_Update
      PORT MAP   (
                  Clock                 => RU_CLK,
                  Data_in               => RUpdate_Data_In,
                  Param                 => RUpdate_Param,
                  Read_param            => RUpdate_Read_Param,
                  Reconfig              => RUpdate_Reconfig,
                  Reset                 => RUpdate_Reset,
                  Reset_timer           => RUpdate_Reset_Timer,
                  Write_param           => RUpdate_Write_Param,
                  Busy                  => RUpdate_Busy,
                  Data_out              => RUpdate_Data_Out
                  );  
               


   -- The ASMI Bridge and interface
   ASMI_Shuttle: ASMI_Atom
      GENERIC MAP (
                   ASMI_JTAG_Bridge_EN  => 0, -- Do we need the bridge functionality?
                   ASMI_Access_EN       => 1  -- Is ASMI access from the user logic needed?
                   )
      PORT MAP    (
                   ASMI_ASDO            => ASMI_DOUT,
                   ASMI_Access_Granted  => '0',
                   ASMI_DCLK            => ASMI_CLK,
                   ASMI_CS_n            => ASMI_nCS,
                   ASMI_OE_n            => '0',
                   ASMI_Data0           => ASMI_DIN,--OPEN,--ASMI_DIN,-------------!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!ModelSIM
                   ASMI_Access_Request  => OPEN
                   );


   ASMI_Access: SPI_Access
      GENERIC MAP (
                   Fast_Read            => Config_FPGA_SPI_FAST_READ_C_S_PKG,
                   Dual_IO              => FALSE
                   )
      PORT MAP    (
                   GCLK                 => GCLK,
                   CLR_n                => CLR_n,
                   -- Signals at the PPC side.
                   Start_Transfer       => ASMI_Start_Transfer,
                   nSuspend             => '1', -- Interrupt actual transfer for one with higher priority. ((1))
                   Mode                 => ASMI_SPI_Mode_0,
                   Words                => ASMI_Words,
                   Address              => ASMI_AD,
                   DIN                  => ASMI_Write_Data,
                   SPI_Init_Done        => ASMI_Init_Done, -- The SPI bus was synchronized
                   Busy                 => OPEN,
                   Update               => ASMI_Update_Data,
                   SPI_Wait             => ASMI_Wait,
                   Actual_Word          => OPEN, -- natural
                   DOUT                 => ASMI_Read_Data, -- Byte
                   -- The Clock Control interface
                   SPI_CLK              => ASMI_CLK, -- Global SPI clock
                   CLK_EN               => CLK_EN, -- Clock enable signal for the Access Controllers
                   Run_AC               => Run_AC, -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                   Bit_Cnt              => Bit_Cnt, -- Which Bit should actually be in work?
                   SPI_Stop             => ASMI_Stop, -- Is the actual bus transfer terminated or not?
                   -- The Flash Device side.
                   SPI_DOUT_DIN         => ASMI_DOUT,
                   SPI_nCS              => ASMI_nCS,
                   SPI_DIN_DOUT         => ASMI_DIN
                   );


ASMI_Space_Controller: SPI_Space_Control
      GENERIC MAP (
                   Fast_Read                 => Config_FPGA_SPI_FAST_READ_C_S_PKG
                   )
      PORT MAP   (
                  GCLK                       => GCLK, -- System Clock
                  CLR_n                      => CLR_n, -- Deglitched external reset
                  -- Router Dock signal
                  PPC_Dock                   => PPC_Dock,
                  -- Access signals
                  Flash_SPI_Init_Done        => ASMI_Init_Done,
                  Flash_SPI_WREN             => ASMI_Update_Data,
                  Flash_SPI_Wait             => ASMI_Wait,
                  Flash_SPI_RD_Data          => ASMI_Read_Data,
                  Flash_SPI_WR_Data          => ASMI_Write_Data,
                  Flash_SPI_Mode_0           => ASMI_SPI_Mode_0,
                  Flash_Start_Access         => ASMI_Start_Transfer_Space, 
                  Flash_SPI_Requested_Words  => ASMI_Space_Words,   
                  Flash_SPI_Access_AD        => ASMI_Space_AD,
                  -- Config signals
                  Flash_Config_Cmd           => Local_FPGA_Config_Cmd,--FPGA_Config_Cmd,
                  Flash_Config_AD            => FPGA_Config_AD,
                  Flash_Config_Bytes         => FPGA_Config_Bytes,
                  Flash_Config_Data          => Local_FPGA_Config_Data,--FPGA_Config_Data,
                  Flash_Config_Buffer_AD     => FPGA_Config_Buffer_AD,
                  Flash_Config_Status        => FPGA_Config_Status,
                  Flash_Config_Terminated    => FPGA_Config_Terminated_Int
                  );

   -- Concurrent
   FPGA_Config_Terminated <= FPGA_Config_Terminated_Int;


   -- Configuration Status
   Configuration_Status: PROCESS(CLR_n, Config_Termination, ASMI_Start_Transfer_Config, ASMI_Start_Transfer_Space, ASMI_Space_AD, ASMI_Space_Words)
   BEGIN
      IF (CLR_n = '0') THEN
         ASMI_AD <= X"7FFFFF";
         ASMI_Words <= 1;
         ASMI_Start_Transfer <= ASMI_Start_Transfer_Config;
      ELSIF (Config_Termination = '0') THEN
         ASMI_AD <= X"7FFFFF";
         ASMI_Words <= 1;
         ASMI_Start_Transfer <= ASMI_Start_Transfer_Config;
      ELSE
         ASMI_AD <= ASMI_Space_AD;
         ASMI_Words <= ASMI_Space_Words;
         ASMI_Start_Transfer <= ASMI_Start_Transfer_Space;
      END IF;
   END PROCESS Configuration_Status;
   
   
   -- We write protect the flash during each start procedure.
   Write_Protect_Flash: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Local_FPGA_Config_Cmd <= (OTHERS => '0');
         Local_FPGA_Config_Data <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Write_Protected = '0') THEN
            Local_FPGA_Config_Data <= X"BC";
            IF (FPGA_Config_Terminated_Int = '1') THEN
               Local_FPGA_Config_Cmd <= X"00";
            ELSIF (Start_Write_Protect = '1') THEN
               Local_FPGA_Config_Cmd <= X"81";
            END IF;
         ELSE
            Local_FPGA_Config_Cmd <= FPGA_Config_Cmd;
            Local_FPGA_Config_Data <= FPGA_Config_Data;
         END IF;
      END IF;
   END PROCESS Write_Protect_Flash;
   
   
   
   -- Concurrent 0: we have to change the endianess of the data, so that it is compatible with the PPC use
   ASMI_Read_Data_Turned <= Change_Endianess_F_S_PKG(ASMI_Read_Data);
   
   
   Configuration_Controller: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         current_state <= Init;
         RUpdate_Configuration <= ((OTHERS => '0'),(OTHERS => '0'),'0',(OTHERS => '0'),'0');
         ASMI_Start_Transfer_Config <= '0';
         RUpdate_Reconfig <= '0';
         RUpdate_Param <= "000";
         RUpdate_Data_In <= (OTHERS => '0');
         RUpdate_Read_Param <= '0';
         RUpdate_Write_Param <= '0';
         Config_Termination <= '0';
         Flash_Boot_Startaddress <= (OTHERS => '0');
         Start_Write_Protect <= '0';
         Write_Protected <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         current_state <= next_state;
         CASE current_state IS
         WHEN Init =>
            Config_Termination <= '1';
            RUpdate_Configuration <= ((OTHERS => '0'),(OTHERS => '0'),'0',(OTHERS => '0'),'0');
            ASMI_Start_Transfer_Config <= '0';
         WHEN Start =>
            ASMI_Start_Transfer_Config <= '0';
         WHEN Write_Protect =>
            Start_Write_Protect <= '1';
         WHEN s0 =>
            ASMI_Start_Transfer_Config <= '1';
            Start_Write_Protect <= '0';
            Write_Protected <= '1';
            Config_Termination <= '0';
         WHEN s1 =>
            ASMI_Start_Transfer_Config <= '1';
         WHEN s2 =>
            ASMI_Start_Transfer_Config <= '0';
         WHEN s3 =>
            IF (ASMI_Read_Data_Turned(7 DOWNTO 4) = "0101") THEN -- If there is no header at the Flash address 0xFFFFFF, we have to make sure that we rest in the factory system.
               Flash_Boot_Startaddress <= Config_FPGA_Boot_Start_C_S_PKG(TO_INTEGER(UNSIGNED(ASMI_Read_Data_Turned(3 DOWNTO 0))));
               -- If the system number is outside the scope /= 0, 1, 2, 3, 4, 5, 6- we have to make sure that we remain in the Factory System.
            ELSE
               Flash_Boot_Startaddress <= "0000000"; -- Our header is corrupted.
            END IF;
         -- Read trigger condition of the reboot.
            RUpdate_Param <= RU_PAR_AD_Trig_C_A_PKG;
         WHEN s4 =>
            RUpdate_Read_Param <= '1';
         WHEN s5 =>
            RUpdate_Read_Param <= '0';
         WHEN s6 =>
            RUpdate_Configuration.Reconfig_Trigger_Condition <= RUpdate_Data_Out(4 DOWNTO 0);
         -- Read watch dog timeout settings.
            RUpdate_Param <= RU_PAR_AD_WD_Timeout_C_A_PKG;
         WHEN s6_Debug0 =>
            RUpdate_Read_Param <= '1';
         WHEN s6_Debug1 =>
            RUpdate_Read_Param <= '0';
         WHEN s6_Debug2 =>
            RUpdate_Configuration.Watchdog_Timeout <= RUpdate_Data_Out(11 DOWNTO 0);
         -- Read configured watch dog enable Bit.
            RUpdate_Param <= RU_PAR_AD_WD_EN_C_A_PKG;
         WHEN s6_Debug3 =>
            RUpdate_Read_Param <= '1';
         WHEN s6_Debug4 =>
            RUpdate_Read_Param <= '0';
         WHEN s6_Debug5 =>
            RUpdate_Configuration.Watchdog_EN <= RUpdate_Data_Out(0);
         -- Read configured boot startup address.
            RUpdate_Param <= RU_PAR_AD_PG_Sel_C_A_PKG;
         WHEN s6_Debug6 =>
            RUpdate_Read_Param <= '1';
         WHEN s6_Debug7 =>
            RUpdate_Read_Param <= '0';
         WHEN s6_Debug8 =>
            RUpdate_Configuration.Boot_Startaddress <= RUpdate_Data_Out(6 DOWNTO 0);
         -- Read the setting of the Factory/ Application Bit.
            RUpdate_Param <= RU_PAR_AD_Mode_C_A_PKG;
         WHEN s6_Debug9 =>
            RUpdate_Read_Param <= '1';
         WHEN s6_Debug10 =>
            RUpdate_Read_Param <= '0';
         WHEN s6_Debug11 =>
            RUpdate_Configuration.Configuration_Mode_A_nF <= RUpdate_Data_Out(0);
         -- Write the new watch dog timeout settings.
            RUpdate_Param <= RU_PAR_AD_WD_Timeout_C_A_PKG;
            RUpdate_Data_In <= Config_FPGA_WD_Timeout_C_S_PKG; -- new value
         WHEN s7 =>
            RUpdate_Write_Param <= '1';
         WHEN s8 =>
            RUpdate_Write_Param <= '0';
         WHEN s9 =>
         -- Write the new watch dog enable setting based on the kind of the new system.
            RUpdate_Param <= RU_PAR_AD_WD_EN_C_A_PKG;
            IF (Flash_Boot_Startaddress = "0000000") THEN
               RUpdate_Data_In <= X"000"; -- new value
            ELSE
               RUpdate_Data_In <= X"001"; -- new value
            END IF;
         WHEN s10 =>
            RUpdate_Write_Param <= '1';
         WHEN s11 =>
            RUpdate_Write_Param <= '0';
         WHEN s12 =>
         -- Write the new boot address to the remote update block.
            RUpdate_Param <= RU_PAR_AD_PG_Sel_C_A_PKG;
            RUpdate_Data_In <= ("00000" & Flash_Boot_Startaddress);
         WHEN s13 =>
            RUpdate_Write_Param <= '1';
         WHEN s14 =>
            RUpdate_Write_Param <= '0';
         WHEN s15 =>
         -- Write the new configuration mode (Factory or Application).
            RUpdate_Param <= RU_PAR_AD_Mode_C_A_PKG;
            IF (Flash_Boot_Startaddress = "0000000") THEN
               RUpdate_Data_In <= X"000";
            ELSE
               RUpdate_Data_In <= X"001";
            END IF;
         WHEN s16 =>
            RUpdate_Write_Param <= '1';
         WHEN s17 =>
            RUpdate_Write_Param <= '0';
         WHEN s18 =>
            IF (Flash_Boot_Startaddress /= "0000000") THEN -- If it is an Application, we have to reboot the FPGA.
               RUpdate_Reconfig <= '0';
               IF (RUpdate_Configuration.Reconfig_Trigger_Condition = "00000") THEN
                  RUpdate_Reconfig <= '1'; -- Do the reboot...
               ELSE
                  RUpdate_Reconfig <= '0';
               END IF;
            ELSE
               RUpdate_Reconfig <= '0';
            END IF;
         WHEN s20 =>
            Config_Termination <= '1';
         WHEN Stop =>
         WHEN OTHERS =>
            NULL;
         END CASE;
      END IF;
   END PROCESS Configuration_Controller;


   nextstate : PROCESS(current_state,ASMI_Init_Done,ASMI_Update_Data,RUpdate_Busy,FPGA_Config_Terminated_Int)
   BEGIN
      CASE current_state IS
      WHEN Init =>
            next_state <= Start;
      WHEN Start =>
         IF (ASMI_Init_Done = '1') THEN
            next_state <= Write_Protect;-- s0
         ELSE
            next_state <= Start;
         END IF;
      WHEN Write_Protect =>
         IF (FPGA_Config_Terminated_Int = '1') THEN
            next_state <= s0;
         ELSE
            next_state <= Write_Protect;
         END IF;
      WHEN s0 =>
            next_state <= s1;
      WHEN s1 =>
            next_state <= s2;
      WHEN s2 =>
         IF (ASMI_Update_Data = '1') THEN
            next_state <= s3;
         ELSE
            next_state <= s2;
         END IF;
      WHEN s3 =>
            next_state <= s4;
      WHEN s4 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s5;
         ELSE
            next_state <= s4;
         END IF;
      WHEN s5 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s6;
         ELSE
            next_state <= s5;
         END IF;
      WHEN s6 =>
         next_state <= s6_Debug0;
      WHEN s6_Debug0 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s6_Debug1;
         ELSE
            next_state <= s6_Debug0;
         END IF;
      WHEN s6_Debug1 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s6_Debug2;
         ELSE
            next_state <= s6_Debug1;
         END IF;
      WHEN s6_Debug2 =>
         next_state <= s6_Debug3;
      WHEN s6_Debug3 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s6_Debug4;
         ELSE
            next_state <= s6_Debug3;
         END IF;
      WHEN s6_Debug4 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s6_Debug5;
         ELSE
            next_state <= s6_Debug4;
         END IF;
      WHEN s6_Debug5 =>
         next_state <= s6_Debug6;
      WHEN s6_Debug6 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s6_Debug7;
         ELSE
            next_state <= s6_Debug6;
         END IF;
      WHEN s6_Debug7 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s6_Debug8;
         ELSE
            next_state <= s6_Debug7;
         END IF;
      WHEN s6_Debug8 =>
         next_state <= s6_Debug9;
      WHEN s6_Debug9 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s6_Debug10;
         ELSE
            next_state <= s6_Debug9;
         END IF;
      WHEN s6_Debug10 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s6_Debug11;
         ELSE
            next_state <= s6_Debug10;
         END IF;
      WHEN s6_Debug11 =>
         next_state <= s7;
      WHEN s7 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s8;
         ELSE
            next_state <= s7;
         END IF;
      WHEN s8 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s9;
         ELSE
            next_state <= s8;
         END IF;
      WHEN s9 =>
            next_state <= s10;
      WHEN s10 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s11;
         ELSE
            next_state <= s10;
         END IF;
      WHEN s11 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s12;
         ELSE
            next_state <= s11;
         END IF;
      WHEN s12 =>
            next_state <= s13;
      WHEN s13 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s14;
         ELSE
            next_state <= s13;
         END IF;
      WHEN s14 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s15;
         ELSE
            next_state <= s14;
         END IF;
      WHEN s15 =>
            next_state <= s16;
      WHEN s16 =>
         IF (RUpdate_Busy = '1') THEN
            next_state <= s17;
         ELSE
            next_state <= s16;
         END IF;
      WHEN s17 =>
         IF (RUpdate_Busy = '0') THEN
            next_state <= s18;
         ELSE
            next_state <= s17;
         END IF;
      WHEN s18 =>
            next_state <= s19;
      WHEN s19 =>
            next_state <= s20;
      WHEN s20 =>
            next_state <= Stop;
      WHEN Stop =>
            next_state <= Stop;
      WHEN OTHERS =>
         next_state <= Start;
      END CASE;
   END PROCESS nextstate;
              
                   
   --------------------------------------
   -- Clock generation for the ASMI block
   --------------------------------------
   FPGA_SPI_Slow_Read: IF NOT(Config_FPGA_SPI_FAST_READ_C_S_PKG) GENERATE
   BEGIN
      Slow_CLK_EN: PROCESS(GCLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            CLK_EN <= '0';
         ELSIF (GCLK'EVENT AND GCLK = '1') THEN
            CLK_EN <= NOT(CLK_EN);
         END IF;
      END PROCESS Slow_CLK_EN;
   END GENERATE FPGA_SPI_Slow_Read;


   FPGA_SPI_Fast_Read: IF (Config_FPGA_SPI_FAST_READ_C_S_PKG) GENERATE
   BEGIN
      CLK_EN <= '1';
   END GENERATE FPGA_SPI_Fast_Read;
   

   ASMI_CLK_Generation: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         ASMI_CLK <= '0'; 
         Run_AC <= '0';
         Bit_Cnt <= 7;
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (CLK_EN = '1') THEN
            CASE Run_AC IS
               WHEN '0' =>
                  IF (ASMI_Stop = '0') THEN
                     Run_AC <= '1';
                     Bit_Cnt <= 7;
                     ASMI_CLK <= '0';
                  ELSE --
                     Run_AC <= '0';
                     Bit_Cnt <= 7;
                     ASMI_CLK <= '0';
                  END IF; --
               WHEN '1' =>
                  ASMI_CLK <= NOT(ASMI_CLK);
                  IF (ASMI_CLK = '1') THEN
                     IF (Bit_Cnt = 0) THEN
                        Run_AC <= '0';
                        Bit_Cnt <= 7;
                     ELSE
                        Bit_Cnt <= (Bit_Cnt - 1);
                     END IF;
                  END IF;
               WHEN OTHERS =>
                  NULL;
            END CASE;
         END IF;
      END IF;
   END PROCESS ASMI_CLK_Generation;
   ------------------------------------------
   -- Clock generation for the ASMI block END
   ------------------------------------------

   -- We have to access the remote update block hardware in the FPGA by reading and writing the appropriate values.


END Universal;