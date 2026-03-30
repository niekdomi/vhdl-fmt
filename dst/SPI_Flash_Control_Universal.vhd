-- MODULE SPI Flash Control
-- VHDL Architecture Indel_lib.SPI_Flash_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Entity used for the SPI flash access                                       --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- IG01: 11.01.2008:   Initial version.                                       --
-- IG02: 20.11.2008:   Changes, so that the accesses can be synchronized,     --
--                     when the clock is used by more than one bus.           --
--                                                                            --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- The SPI physical address is at 0x000000. It is mounted into the memory     --
-- space with the help of the access enables of the router mechanism.         --
--                                                                            --
-- The devices are numbered as follows:                                       --
-- Boot Flash: 0                                                              --
-- Flash 0   : 1                                                              --
-- Flash 1   : 2                                                              --
-- Flash 2   : 3                                                              --
-- Flash 3   : 4                                                              --
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
USE Indel_lib.SPI_Package.all;
USE Indel_lib.INFO_SAM3_Package_Take2.all;
-------------------------------
-- Entity library inclusion END
-------------------------------


--------------------------------------------------------------------------------
-- Entity declaration
--------------------------------------------------------------------------------
ENTITY SPI_Flash_Control IS
   PORT        (
                GCLK                       : IN    std_logic; -- System Clock
                SPI_Access_CLK             : IN    std_logic; -- Clock for the SPI FSM
                CLR_n                      : IN    std_logic; -- Deglitched external reset
                -- Router Dock signal
                Boot_PPC_Dock              : INOUT router_dock_t_s_pkg;
                Flash_PPC_Dock             : INOUT router_dock_t_s_pkg;
                -- Signals to/ from the external SPI device
                SPI_CLK                    : OUT   std_logic;
                -- SPI Boot System Flash
                SPI_BOOT_nCS               : OUT   std_logic;
                SPI_BOOT_DIN_DOUT0         : INOUT std_logic;
                SPI_BOOT_DOUT_DIN0         : INOUT std_logic;
                -- SPI Standard Flash 0
                SPI_EME_nCS0               : OUT   std_logic;
                SPI_EME_DIN_DOUT0          : INOUT std_logic;
                SPI_EME_DOUT_DIN0          : INOUT std_logic;
                -- SPI Standard Flash 1
                SPI_EME_nCS1               : OUT   std_logic;
                SPI_EME_DIN_DOUT1          : INOUT std_logic;
                SPI_EME_DOUT_DIN1          : INOUT std_logic;
                -- SPI Standard Flash 2
                SPI_EME_nCS2               : OUT   std_logic;
                SPI_EME_DIN_DOUT2          : INOUT std_logic;
                SPI_EME_DOUT_DIN2          : INOUT std_logic;
                -- SPI Standard Flash 3
                SPI_EME_nCS3               : OUT   std_logic;
                SPI_EME_DIN_DOUT3          : INOUT std_logic;
                SPI_EME_DOUT_DIN3          : INOUT std_logic;
                -- Config signals
                Boot_Config_Cmd            : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Boot_Config_AD             : IN    std_logic_vector(Return_Upper_F_I_PKG(24) DOWNTO 0);
                Boot_Config_Bytes          : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Boot_Config_Data           : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Boot_Config_Buffer_AD      : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Boot_Config_Status         : OUT   std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
                Boot_Config_Terminated     : OUT   std_logic;
                Flash_Config_Cmd           : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_AD            : IN    std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
                Flash_Config_Bytes         : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Data          : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Buffer_AD     : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Status        : OUT   std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Terminated    : OUT   std_logic
                );
END ENTITY SPI_Flash_Control;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------




ARCHITECTURE Universal OF SPI_Flash_Control IS

   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL SPI_CLK_INT                     : std_logic; -- Internal SPI clock
   SIGNAL Run_AC                          : std_logic; -- Access Control Status signal: each access is at least 8 Bit.
   SIGNAL Any_Access_On_Going             : std_logic; -- Is there an access on a bus ongoing?
   SIGNAL CLK_EN                          : std_logic; -- Clock enable signal to control the speed of the SPI bus if we are to fast for old devices
   SIGNAL SPI_Stop                        : std_logic_vector(4 DOWNTO 0); -- Status vector with the transfers on the four different SPI busses.
   SIGNAL Bit_Cnt                         : natural RANGE 0 TO 7;
   -------------------------
   -- Signal Declaration END
   -------------------------


   ------------------------
   -- Component Declaration
   ------------------------  
   COMPONENT SPI_Space_Control
      GENERIC  (
                Fast_Read                 : IN    boolean
                );
      PORT     (
                GCLK                      : IN    std_logic; -- System Clock
                CLR_n                     : IN    std_logic; -- Deglitched external reset
                -- Router Dock signal
                PPC_Dock                  : INOUT router_dock_t_s_pkg;
                -- Access signals
                Flash_SPI_Init_Done       : IN    std_logic;
                Flash_SPI_WREN            : IN    std_logic;
                Flash_SPI_Wait            : IN    std_logic;
                Flash_SPI_RD_Data         : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_SPI_WR_Data         : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_SPI_Mode_0          : OUT   std_logic_vector(7 DOWNTO 0);
                Flash_Start_Access        : OUT   std_logic;
                Flash_SPI_Requested_Words : OUT   natural RANGE 0 TO 65535 := 8;
                Flash_SPI_Access_AD       : OUT   std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
                -- Config signals
                Flash_Config_Cmd          : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_AD           : IN    std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
                Flash_Config_Bytes        : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Data         : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Buffer_AD    : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Status       : OUT   std_logic_vector(Return_Upper_F_I_PKG(3*Byte_C_I_PKG) DOWNTO 0);
                Flash_Config_Terminated   : OUT   std_logic
                );
   END COMPONENT SPI_Space_Control;


   COMPONENT SPI_Access
     GENERIC   (
                Fast_Read                 : IN    boolean;
                Dual_IO                   : IN    boolean
                );
      PORT     (
                GCLK                      : IN    std_logic;
                CLR_n                     : IN    std_logic;
                -- Signals at the PPC side.
                Start_Transfer            : IN    std_logic := '0';
                nSuspend                  : IN    std_logic;
                Mode                      : IN    std_logic_vector(7 DOWNTO 0);
                Words                     : IN    natural RANGE 0 TO 65535; -- If number of words = 0 -> read continuously.
                Address                   : IN    std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
                DIN                       : IN    std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                SPI_Init_Done             : OUT   std_logic; -- The SPI bus was synchronized
                Busy                      : OUT   std_logic;
                Update                    : OUT   std_logic;
                SPI_Wait                  : OUT   std_logic;
                Actual_Word               : OUT   natural RANGE 0 TO 65535;
                DOUT                      : OUT   std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
                -- The Clock Control interface
                SPI_CLK                   : IN    std_logic; -- Global SPI clock
                CLK_EN                    : IN    std_logic; -- Clock enable signal for the Access Controllers
                Run_AC                    : IN    std_logic; -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                Bit_Cnt                   : IN    natural RANGE 0 TO 7; -- Which Bit should actually be in work?
                SPI_Stop                  : OUT   std_logic; -- Is the actual bus transfer terminated or not?
                -- The Flash Device side.
                SPI_DOUT_DIN              : INOUT std_logic;
                SPI_nCS                   : OUT   std_logic;
                SPI_DIN_DOUT              : INOUT std_logic
                );
   END COMPONENT SPI_Access;


   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : SPI_Space_Control USE ENTITY Indel_lib.SPI_Space_Control;
   FOR ALL : SPI_Access USE ENTITY Indel_lib.SPI_Access;
   -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------


BEGIN


   -------------
   -- Boot Space
   -------------
   Boot_Space_EN: IF (Config_SPI_Boot_Space_EN_C_S_PKG) GENERATE
      SIGNAL Boot_SPI_Init_Done         : std_logic;
      SIGNAL Boot_SPI_WREN              : std_logic;
      SIGNAL Boot_SPI_RD_Data           : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
      SIGNAL Boot_SPI_WR_Data           : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
      SIGNAL Boot_Start_Access          : std_logic;
      SIGNAL Boot_SPI_Requested_Words   : natural RANGE 0 TO 65535;
      SIGNAL Boot_SPI_Access_AD         : std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
      SIGNAL Boot_SPI_Mode_0            : std_logic_vector(7 DOWNTO 0);
      SIGNAL Boot_SPI_Wait              : std_logic;
   BEGIN
      Boot_Space: SPI_Space_Control
         GENERIC MAP (
                      Fast_Read               => TRUE
                      )
         PORT MAP (
                   GCLK                       => GCLK,
                   CLR_n                      => CLR_n,
                   -- Router Dock signal
                   PPC_Dock                   => Boot_PPC_Dock,
                   -- Access signals
                   Flash_SPI_Init_Done        => Boot_SPI_Init_Done,
                   Flash_SPI_WREN             => Boot_SPI_WREN,
                   Flash_SPI_Wait             => Boot_SPI_Wait,
                   Flash_SPI_RD_Data          => Boot_SPI_RD_Data,
                   Flash_SPI_WR_Data          => Boot_SPI_WR_Data,
                   Flash_SPI_Mode_0           => Boot_SPI_Mode_0,
                   Flash_Start_Access         => Boot_Start_Access,
                   Flash_SPI_Requested_Words  => Boot_SPI_Requested_Words,
                   Flash_SPI_Access_AD        => Boot_SPI_Access_AD,
                   -- Config signals
                   Flash_Config_Cmd           => Boot_Config_Cmd,
                   Flash_Config_AD            => Boot_Config_AD,
                   Flash_Config_Bytes         => Boot_Config_Bytes,
                   Flash_Config_Data          => Boot_Config_Data,
                   Flash_Config_Buffer_AD     => Boot_Config_Buffer_AD,
                   Flash_Config_Status        => Boot_Config_Status,
                   Flash_Config_Terminated    => Boot_Config_Terminated
                   );


      -- For accessing the SPI Flash, we use the SPI_Access entity. This module allows us to identify the flash chip
      -- and to choose the best possible transfer method.
      Boot_Accessor: SPI_Access
         GENERIC MAP (
                      Fast_Read               => TRUE,
                      Dual_IO                 => FALSE
                      )
         PORT MAP (
                   GCLK                       => SPI_Access_CLK,
                   CLR_n                      => CLR_n,
                   -- Signals at the PPC side.
                   Start_Transfer             => Boot_Start_Access,
                   nSuspend                   => '1', -- This signal can be used to intercept an ongoing access if a transfer with higher priority has to be initiated
                   Mode                       => Boot_SPI_Mode_0, -- Read, FRead, Write, CWrite, RDStatus, WRStatus, DualRead, DualWrite, etc.
                   Words                      => Boot_SPI_Requested_Words, -- If number of words = 0 -> read continuously.
                   Address                    => Boot_SPI_Access_AD, -- 24 bit address, MSB first
                   DIN                        => Boot_SPI_WR_Data, -- 8 bit input data.
                   SPI_Init_Done              => Boot_SPI_Init_Done, -- The SPI bus was synchronized
                   Busy                       => OPEN, -- Busy signal which is a sign for an ongoing access.
                   Update                     => Boot_SPI_WREN, -- WR signal to the ring buffer TDP RAM.
                   SPI_Wait                   => Boot_SPI_Wait,
                   Actual_Word                => OPEN,
                   DOUT                       => Boot_SPI_RD_Data,--SPI_Data, -- 8 bit output data
                   -- The Clock Control interface
                   SPI_CLK                    => SPI_CLK_INT, -- Global SPI clock
                   CLK_EN                     => CLK_EN,
                   Run_AC                     => Run_AC, -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                   Bit_Cnt                    => Bit_Cnt,--Bit_Cnt_INT, -- Which Bit should actually be in work?
                   SPI_Stop                   => SPI_Stop(0), -- Is the actual bus transfer terminated or not?
                   -- The Flash Device side.
                   SPI_DOUT_DIN               => SPI_BOOT_DOUT_DIN0, -- This pin is normally the output to the flash device. In dual mode it can be used as input, too.
                   SPI_nCS                    => SPI_BOOT_nCS,
                   SPI_DIN_DOUT               => SPI_BOOT_DIN_DOUT0
                   );       
   END GENERATE Boot_Space_EN;
   
   
   No_Boot_Space: IF NOT(Config_SPI_Boot_Space_EN_C_S_PKG) GENERATE
   BEGIN
      Boot_PPC_Dock.Member_Data <= NA_Member_Bundle_C_S_PKG;
      SPI_BOOT_nCS <= '1';
      SPI_Stop(0) <= '1';
   END GENERATE No_Boot_Space;
   -----------------
   -- Boot Space END
   -----------------


   --------------
   -- Flash Space
   --------------
   Flash_Space_EN: IF (Config_SPI_Flash_Space_EN_C_S_PKG) GENERATE
      SIGNAL Flash_SPI_Init_Done         : std_logic;
      SIGNAL Flash_SPI_WREN              : std_logic;
      SIGNAL Flash_SPI_RD_Data           : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
      SIGNAL Flash_SPI_WR_Data           : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
      SIGNAL Flash_Start_Access          : std_logic;
      SIGNAL Flash_SPI_Requested_Words   : natural RANGE 0 TO 65535;
      SIGNAL Flash_SPI_Access_AD         : std_logic_vector(Return_Upper_F_I_PKG(SPI_Address_C_SPI_PKG) DOWNTO 0);
      SIGNAL Flash_SPI_Mode_0            : std_logic_vector(7 DOWNTO 0);
      SIGNAL Flash_SPI_Wait              : std_logic;
   BEGIN
      Flash_Space: SPI_Space_Control
         GENERIC MAP (
                      Fast_Read               => TRUE
                      )
         PORT MAP (
                   GCLK                       => GCLK,
                   CLR_n                      => CLR_n,
                   -- Router Dock signal
                   PPC_Dock                   => Flash_PPC_Dock,
                   -- Access signals
                   Flash_SPI_Init_Done        => Flash_SPI_Init_Done,
                   Flash_SPI_WREN             => Flash_SPI_WREN,
                   Flash_SPI_Wait             => Flash_SPI_Wait,
                   Flash_SPI_RD_Data          => Flash_SPI_RD_Data,
                   Flash_SPI_WR_Data          => Flash_SPI_WR_Data,
                   Flash_SPI_Mode_0           => Flash_SPI_Mode_0,
                   Flash_Start_Access         => Flash_Start_Access,
                   Flash_SPI_Requested_Words  => Flash_SPI_Requested_Words,
                   Flash_SPI_Access_AD        => Flash_SPI_Access_AD,
                   -- Config signals
                   Flash_Config_Cmd           => Flash_Config_Cmd,
                   Flash_Config_AD            => Flash_Config_AD,
                   Flash_Config_Bytes         => Flash_Config_Bytes,
                   Flash_Config_Data          => Flash_Config_Data,
                   Flash_Config_Buffer_AD     => Flash_Config_Buffer_AD,
                   Flash_Config_Status        => Flash_Config_Status,
                   Flash_Config_Terminated    => Flash_Config_Terminated
                   );


      -- For accessing the SPI Flash, we use the SPI_Access entity. This module allows us to identify the flash chip
      -- and to choose the best possible transfer method.    
      Flash_0_Device_EN: IF (Config_SPI_Flash_0_EN_C_S_PKG) GENERATE
      BEGIN
         Flash_Accessor: SPI_Access
            GENERIC MAP (
                         Fast_Read               => TRUE,
                         Dual_IO                 => TRUE --FALSE
                         )
            PORT MAP (
                      GCLK                       => SPI_Access_CLK,
                      CLR_n                      => CLR_n,
                      -- Signals at the PPC side.
                      Start_Transfer             => Flash_Start_Access,
                      nSuspend                   => '1', -- This signal can be used to intercept an ongoing access if a transfer with higher priority has to be initiated
                      Mode                       => Flash_SPI_Mode_0, -- Read, FRead, Write, CWrite, RDStatus, WRStatus, DualRead, DualWrite, etc.
                      Words                      => Flash_SPI_Requested_Words, -- If number of words = 0 -> read continuously.
                      Address                    => Flash_SPI_Access_AD, -- 24 bit address, MSB first
                      DIN                        => Flash_SPI_WR_Data, -- 8 bit input data.
                      SPI_Init_Done              => Flash_SPI_Init_Done, -- The SPI bus was synchronized
                      Busy                       => OPEN, -- Busy signal which is a sign for an ongoing access.
                      Update                     => Flash_SPI_WREN, -- WR signal to the ring buffer TDP RAM.
                      SPI_Wait                   => Flash_SPI_Wait,
                      Actual_Word                => OPEN,
                      DOUT                       => Flash_SPI_RD_Data,--SPI_Data, -- 8 bit output data
                      -- The Clock Control interface
                      SPI_CLK                    => SPI_CLK_INT, -- Global SPI clock
                      CLK_EN                     => CLK_EN,
                      Run_AC                     => Run_AC, -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                      Bit_Cnt                    => Bit_Cnt,--Bit_Cnt_INT, -- Which Bit should actually be in work?
                      SPI_Stop                   => SPI_Stop(1), -- Is the actual bus transfer terminated or not?
                      -- The Flash Device side.
                      SPI_DOUT_DIN               => SPI_EME_DOUT_DIN0, -- This pin is normally the output to the flash device. In dual mode it can be used as input, too.
                      SPI_nCS                    => SPI_EME_nCS0,
                      SPI_DIN_DOUT               => SPI_EME_DIN_DOUT0
                      );
      END GENERATE Flash_0_Device_EN;
      
      
      Flash_0_Device_nEN: IF NOT(Config_SPI_Flash_0_EN_C_S_PKG) GENERATE
      BEGIN
         SPI_EME_nCS0 <= '1';
         Flash_SPI_WREN <= '0';
         Flash_SPI_RD_Data <= (OTHERS => '0');
         SPI_Stop(1) <= '1';
      END GENERATE Flash_0_Device_nEN;
                   

      Flash_1_Device_EN: IF (Config_SPI_Flash_1_EN_C_S_PKG) GENERATE
      BEGIN      
         Flash_Accessor_1: SPI_Access
            GENERIC MAP (
                         Fast_Read               => TRUE,
                         Dual_IO                 => FALSE
                         )
            PORT MAP (
                      GCLK                       => SPI_Access_CLK,
                      CLR_n                      => CLR_n,
                      -- Signals at the PPC side.
                      Start_Transfer             => Flash_Start_Access,
                      nSuspend                   => '1', -- This signal can be used to intercept an ongoing access if a transfer with higher priority has to be initiated
                      Mode                       => X"00", -- Read, FRead, Write, CWrite, RDStatus, WRStatus, DualRead, DualWrite, etc.
                      Words                      => Flash_SPI_Requested_Words, -- If number of words = 0 -> read continuously.
                      Address                    => Flash_SPI_Access_AD, -- 24 bit address, MSB first
                      DIN                        => "00000000", -- 8 bit input data.
                      SPI_Init_Done              => Flash_SPI_Init_Done, -- The SPI bus was synchronized
                      Busy                       => OPEN, -- Busy signal which is a sign for an ongoing access.
                      Update                     => Flash_SPI_WREN, -- WR signal to the ring buffer TDP RAM.
                      Actual_Word                => OPEN,
                      DOUT                       => OPEN,--Flash_SPI_RD_Data,--SPI_Data, -- 8 bit output data
                      -- The Clock Control interface
                      SPI_CLK                    => SPI_CLK_INT, -- Global SPI clock
                      CLK_EN                     => CLK_EN,
                      Run_AC                     => Run_AC, -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                      Bit_Cnt                    => Bit_Cnt,--Bit_Cnt_INT, -- Which Bit should actually be in work?
                      SPI_Stop                   => SPI_Stop(2), -- Is the actual bus transfer terminated or not?
                      -- The Flash Device side.
                      SPI_DOUT_DIN               => SPI_EME_DOUT_DIN1, -- This pin is normally the output to the flash device. In dual mode it can be used as input, too.
                      SPI_nCS                    => SPI_EME_nCS1,
                      SPI_DIN_DOUT               => SPI_EME_DIN_DOUT1
                      );
      END GENERATE Flash_1_Device_EN;


      Flash_1_Device_nEN: IF NOT(Config_SPI_Flash_1_EN_C_S_PKG) GENERATE
      BEGIN
         SPI_EME_nCS1 <= '1';
         -- Flash_SPI_WREN <= '0';
         -- Flash_SPI_Data <= (OTHERS => '0');
         SPI_Stop(2) <= '1';
      END GENERATE Flash_1_Device_nEN;
      

      Flash_2_Device_EN: IF (Config_SPI_Flash_2_EN_C_S_PKG) GENERATE
      BEGIN 
         Flash_Accessor_2: SPI_Access
            GENERIC MAP (
                         Fast_Read               => TRUE,
                         Dual_IO                 => FALSE
                         )
            PORT MAP (
                      GCLK                       => SPI_Access_CLK,
                      CLR_n                      => CLR_n,
                      -- Signals at the PPC side.
                      Start_Transfer             => Flash_Start_Access,
                      nSuspend                   => '1', -- This signal can be used to intercept an ongoing access if a transfer with higher priority has to be initiated
                      Mode                       => X"00", -- Read, FRead, Write, CWrite, RDStatus, WRStatus, DualRead, DualWrite, etc.
                      Words                      => Flash_SPI_Requested_Words, -- If number of words = 0 -> read continuously.
                      Address                    => Flash_SPI_Access_AD, -- 24 bit address, MSB first
                      DIN                        => "00000000", -- 8 bit input data.
                      SPI_Init_Done              => Flash_SPI_Init_Done, -- The SPI bus was synchronized
                      Busy                       => OPEN, -- Busy signal which is a sign for an ongoing access.
                      Update                     => Flash_SPI_WREN, -- WR signal to the ring buffer TDP RAM.
                      Actual_Word                => OPEN,
                      DOUT                       => OPEN,--Flash_SPI_RD_Data,--SPI_Data, -- 8 bit output data
                      -- The Clock Control interface
                      SPI_CLK                    => SPI_CLK_INT, -- Global SPI clock
                      CLK_EN                     => CLK_EN,
                      Run_AC                     => Run_AC, -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                      Bit_Cnt                    => Bit_Cnt,--Bit_Cnt_INT, -- Which Bit should actually be in work?
                      SPI_Stop                   => SPI_Stop(3), -- Is the actual bus transfer terminated or not?
                      -- The Flash Device side.
                      SPI_DOUT_DIN               => SPI_EME_DOUT_DIN2, -- This pin is normally the output to the flash device. In dual mode it can be used as input, too.
                      SPI_nCS                    => SPI_EME_nCS2,
                      SPI_DIN_DOUT               => SPI_EME_DIN_DOUT2
                      );
      END GENERATE Flash_2_Device_EN;


      Flash_2_Device_nEN: IF NOT(Config_SPI_Flash_2_EN_C_S_PKG) GENERATE
      BEGIN
         SPI_EME_nCS2 <= '1';
         -- Flash_SPI_WREN <= '0';
         -- Flash_SPI_Data <= (OTHERS => '0');
         SPI_Stop(3) <= '1';
      END GENERATE Flash_2_Device_nEN;


      Flash_3_Device_EN: IF (Config_SPI_Flash_3_EN_C_S_PKG) GENERATE
      BEGIN
         Flash_Accessor_3: SPI_Access
            GENERIC MAP (
                         Fast_Read               => TRUE,
                         Dual_IO                 => FALSE
                         )
            PORT MAP (
                      GCLK                       => SPI_Access_CLK,
                      CLR_n                      => CLR_n,
                      -- Signals at the PPC side.
                      Start_Transfer             => Flash_Start_Access,
                      nSuspend                   => '1', -- This signal can be used to intercept an ongoing access if a transfer with higher priority has to be initiated
                      Mode                       => X"00", -- Read, FRead, Write, CWrite, RDStatus, WRStatus, DualRead, DualWrite, etc.
                      Words                      => Flash_SPI_Requested_Words, -- If number of words = 0 -> read continuously.
                      Address                    => Flash_SPI_Access_AD, -- 24 bit address, MSB first
                      DIN                        => "00000000", -- 8 bit input data.
                      SPI_Init_Done              => Flash_SPI_Init_Done, -- The SPI bus was synchronized
                      Busy                       => OPEN, -- Busy signal which is a sign for an ongoing access.
                      Update                     => Flash_SPI_WREN, -- WR signal to the ring buffer TDP RAM.
                      Actual_Word                => OPEN,
                      DOUT                       => OPEN,--Flash_SPI_RD_Data,--SPI_Data, -- 8 bit output data
                      -- The Clock Control interface
                      SPI_CLK                    => SPI_CLK_INT, -- Global SPI clock
                      CLK_EN                     => CLK_EN,
                      Run_AC                     => Run_AC, -- Control of the transfer on Byte level: '0' = not started, '1' = ongoing
                      Bit_Cnt                    => Bit_Cnt,--Bit_Cnt_INT, -- Which Bit should actually be in work?
                      SPI_Stop                   => SPI_Stop(4), -- Is the actual bus transfer terminated or not?
                      -- The Flash Device side.
                      SPI_DOUT_DIN               => SPI_EME_DOUT_DIN3, -- This pin is normally the output to the flash device. In dual mode it can be used as input, too.
                      SPI_nCS                    => SPI_EME_nCS3,
                      SPI_DIN_DOUT               => SPI_EME_DIN_DOUT3
                      );           
      END GENERATE Flash_3_Device_EN;


      Flash_3_Device_nEN: IF NOT(Config_SPI_Flash_3_EN_C_S_PKG) GENERATE
      BEGIN
         SPI_EME_nCS3 <= '1';
         -- Flash_SPI_WREN <= '0';
         -- Flash_SPI_Data <= (OTHERS => '0');
         SPI_Stop(4) <= '1';
      END GENERATE Flash_3_Device_nEN;      
                  
      
   END GENERATE Flash_Space_EN;
   
   
   No_Flash_Space: IF NOT(Config_SPI_Flash_Space_EN_C_S_PKG) GENERATE
   BEGIN
      Flash_PPC_Dock.Member_Data <= NA_Member_Bundle_C_S_PKG;
      SPI_EME_nCS0 <= '1';
      SPI_EME_nCS1 <= '1';
      SPI_EME_nCS2 <= '1';
      SPI_EME_nCS3 <= '1';
      SPI_Stop(4 DOWNTO 1) <= (OTHERS => '1');
   END GENERATE No_Flash_Space;
   ------------------
   -- Flash Space END
   ------------------

   
   ------------------------------------------------
   -- Clock generation for all PPC flashes (global)
   ------------------------------------------------
   -- Based on the fact, that we have just one SPI clock line for all the PPC flashes, we
   -- have to generate the CLK_ASMI signal globally. In addition all the FSM need to synchronize theirself to the clock.
   
   -- We want to use the slow read command:
   SPI_Slow_Read: IF NOT(Config_PPC_SPI_FAST_READ_C_S_PKG) GENERATE
   BEGIN
      Slow_CLK_EN: PROCESS(SPI_Access_CLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            CLK_EN <= '0';
         ELSIF (SPI_Access_CLK'EVENT AND SPI_Access_CLK = '1') THEN
            CLK_EN <= NOT(CLK_EN);
         END IF;
      END PROCESS Slow_CLK_EN;
   END GENERATE SPI_Slow_Read;

   -- We want to use the fast read command:
   SPI_Fast_Read: IF (Config_PPC_SPI_FAST_READ_C_S_PKG) GENERATE
   BEGIN
      CLK_EN <= '1';
   END GENERATE SPI_Fast_Read;
   

   SPI_CLK_Generation: PROCESS(SPI_Access_CLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         SPI_CLK_INT <= '0'; 
         Run_AC <= '0';
         Bit_Cnt <= 7;
      ELSIF (SPI_Access_CLK'EVENT AND SPI_Access_CLK = '1') THEN
         IF (CLK_EN = '1') THEN
            CASE Run_AC IS
               WHEN '0' =>
                  IF (Any_Access_On_Going = '1') THEN
                     Run_AC <= '1';
                     Bit_Cnt <= 7;
                     SPI_CLK_INT <= '0';
                  ELSE --
                     Run_AC <= '0';
                     Bit_Cnt <= 7;
                     SPI_CLK_INT <= '0';
                  END IF; --
               WHEN '1' =>
                  SPI_CLK_INT <= NOT(SPI_CLK_INT);
                  IF (SPI_CLK_INT = '1') THEN
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
   END PROCESS SPI_CLK_Generation;


   -- Concurrent, used to check if more than one transfer is ongoing.
   Any_Access_On_Going <= (NOT(SPI_Stop(0)) OR NOT(SPI_Stop(1)) OR NOT(SPI_Stop(2)) OR NOT(SPI_Stop(3)) OR NOT(SPI_Stop(4)));
   SPI_CLK <= SPI_CLK_INT;
   ----------------------------------------------------
   -- Clock generation for all PPC flashes (global) END
   ----------------------------------------------------


END ARCHITECTURE Universal;