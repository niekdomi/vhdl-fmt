-- MODULE SPI Memory Space Control
-- VHDL Architecture Indel_lib.SPI_Space_Control.Universal
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
-- It is possible that we have more than one device that is part of a single  --
-- space. For this reason we need an entity which controls the access to the  --
-- PPC signals.                                                               --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --


--------------------------------------------------------------------------------
--$Rev:: 1395                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2010-04-07 15:20:19 +0200 (Mi., 07 Apr 2010)                         $
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
ENTITY SPI_Space_Control IS
   GENERIC     (
                Fast_Read                  : IN    boolean
                );
   PORT        (
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
END ENTITY SPI_Space_Control;
--------------------------------------------------------------------------------
-- Entity declaration END
--------------------------------------------------------------------------------







--------------------------------------------------------------------------------

ARCHITECTURE Universal OF SPI_Space_Control IS
   
   
   -----------------------
   -- Constant Declaration
   -----------------------
   -- We switch the default read command based on the constant in the "INFO_SAM3_Package_Take2" package (used for the dummy read access at least).
   CONSTANT Default_Read_Command          :  std_logic_vector(7 DOWNTO 0) := Return_Value_std_logic_vector_F_I_PKG(FAST_READ_C_SPI_PKG, READ_C_SPI_PKG, Fast_Read);
   ---------------------------
   -- Constant Declaration END
   ---------------------------

   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL Flash_SPI_Data_INT              : std_logic_vector(Return_Upper_F_I_PKG(Byte_C_I_PKG) DOWNTO 0);
   SIGNAL Flash_Member_Data               : std_logic_vector(63 DOWNTO 0);
   SIGNAL Flash_Data_Ready                : std_logic;
   SIGNAL Flash_SPI_Transfer_OnGoing      : std_logic;
   SIGNAL Flash_Next_Access_Waiting       : std_logic;
   SIGNAL Flash_Update_Counter            : natural RANGE 0 TO 255;

   SIGNAL Flash_Config_Access             : std_logic;
   SIGNAL Lock_Config_Access              : std_logic;
   SIGNAL Disable_Config_Access           : std_logic;

   SIGNAL Flash_Config_Bytes_INT          : std_logic_vector(8 DOWNTO 0);
   SIGNAL Flash_SPI_Requested_Words_INT   : natural RANGE 0 TO 65535;
   SIGNAL Flash_Config_Terminated_INT     : std_logic;
   SIGNAL Config_Status_Counter           : natural RANGE 0 TO 3;

   SIGNAL SPI_Word_AD                     : std_logic_vector(2 DOWNTO 0);
   SIGNAL SPI_Requested_Read_Words        : std_logic_vector(3 DOWNTO 0);
   -------------------------
   -- Signal Declaration END
   -------------------------
   
BEGIN
   
   -- Concurrent 0
   Flash_SPI_Data_INT <= Change_Endianess_F_S_PKG(Flash_SPI_RD_Data);
   
   -- Little/Big endian as always...
   -- We have to register the SPI write data:
   SPI_WR_Data_Registered: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Flash_SPI_WR_Data <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((Flash_Config_Cmd = X"81") OR (Flash_Config_Cmd = X"01")) THEN
            Flash_SPI_WR_Data <= Flash_Config_Data;
         ELSE
            Flash_SPI_WR_Data <= Change_Endianess_F_S_PKG(Flash_Config_Data);
         END IF;
      END IF;
   END PROCESS SPI_WR_Data_Registered;

   -- Concurrent 1
   Flash_Config_Buffer_AD <= STD_LOGIC_VECTOR(TO_UNSIGNED(Flash_Update_Counter,8));


   -- At the moment we use two different access modes, based on the fact that the Winbond device does not work in the fast mode for the FPGA flash (8 Bit access).
   Define_Access_Mode_Fast: IF (Default_Read_Command = FAST_READ_C_SPI_PKG) GENERATE
      SIGNAL BE       : std_logic_vector(7 DOWNTO 0);
   BEGIN
   
         -- Concurrent 2
         -- We assign our BE signals to a local signal with a shorter name...
         BE <= PPC_Dock.Router_Data.BE;
         
         -- SPI start address for the serial device to reduce the read access time
         SPI_Word_AD(0) <= ((NOT(BE(3)) AND BE(2)) OR (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND BE(0)) OR (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0)) AND NOT(BE(7)) AND BE(6)) OR (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0)) AND NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND BE(4)));
         SPI_Word_AD(1) <= ((NOT(BE(3)) AND NOT(BE(2)) AND BE(1)) OR (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND BE(0)) OR (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0)) AND NOT(BE(7)) AND NOT(BE(6)) AND BE(5)) OR (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0)) AND NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND BE(4)));
         SPI_Word_AD(2) <= (NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0)));

         -- Number of requested words for the read access
         SPI_Requested_Read_Words(3) <= (BE(7) AND BE(6) AND BE(5) AND BE(4) AND BE(3) AND BE(2) AND BE(1) AND BE(0));
         SPI_Requested_Read_Words(2) <= ((BE(7) AND BE(6) AND BE(5) AND BE(4) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND BE(3) AND BE(2) AND BE(1) AND BE(0)));
         SPI_Requested_Read_Words(1) <= ((BE(7) AND BE(6) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND BE(5) AND BE(4) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND BE(3) AND BE(2) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND BE(1) AND BE(0)));
         SPI_Requested_Read_Words(0) <= ((BE(7) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND BE(6) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND BE(5) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND BE(4) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND BE(3) AND NOT(BE(2)) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND BE(2) AND NOT(BE(1)) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND BE(1) AND NOT(BE(0))) OR (NOT(BE(7)) AND NOT(BE(6)) AND NOT(BE(5)) AND NOT(BE(4)) AND NOT(BE(3)) AND NOT(BE(2)) AND NOT(BE(1)) AND BE(0)));
   END GENERATE Define_Access_Mode_Fast;


   Define_Access_Mode_Slow: IF (Default_Read_Command = READ_C_SPI_PKG) GENERATE
   BEGIN
      SPI_Word_AD <= "000";
      SPI_Requested_Read_Words <= "1000";
   END GENERATE Define_Access_Mode_Slow;


   -- Concurrent 3
   -- A "0" means that we want to write the whole page => 256 Bytes
   Flash_Config_Bytes_INT <= "100000000" WHEN (Flash_Config_Bytes = X"00") ELSE ('0' & Flash_Config_Bytes);

   -- Concurrent 4
   Flash_SPI_Requested_Words <= Flash_SPI_Requested_Words_INT;

   -- Concurrent 5
   Flash_Config_Terminated <= Flash_Config_Terminated_INT;

 
   -- We have to assign the Status Data during a Configuration access.
   Assign_Status: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Flash_Config_Status <= (OTHERS => '0');
         Config_Status_Counter <= 0;
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((Lock_Config_Access = '1') AND (Flash_SPI_WREN = '1')) THEN
            CASE Config_Status_Counter IS
               WHEN 0 =>
                  Flash_Config_Status(7 DOWNTO 0) <= Flash_SPI_RD_Data;
                  Flash_Config_Status(23 DOWNTO 8) <= (OTHERS => '0');
                  Config_Status_Counter <= (Config_Status_Counter + 1);
               WHEN 1 =>
                  Flash_Config_Status(15 DOWNTO 8) <= Flash_SPI_RD_Data;
                  Config_Status_Counter <= (Config_Status_Counter + 1);
               WHEN 2 =>
                  Flash_Config_Status(23 DOWNTO 16) <= Flash_SPI_RD_Data;
                  Config_Status_Counter <= (Config_Status_Counter + 1);
               WHEN 3 =>
                  Flash_Config_Status(7 DOWNTO 0) <= Flash_SPI_RD_Data;
                  Config_Status_Counter <= 0;
               WHEN OTHERS =>
                  Flash_Config_Status(23 DOWNTO 0) <= (OTHERS => '0');
                  Config_Status_Counter <= 0;
            END CASE;
         ELSIF (Lock_Config_Access = '0') THEN
            Config_Status_Counter <= 0;
         END IF;
      END IF;
   END PROCESS Assign_Status;
   
   
   
   Flash_Access_Counter: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Flash_SPI_Access_AD <= (OTHERS => '0');
         Flash_SPI_Transfer_OnGoing <= '0';
         Flash_Start_Access <= '0';
         Flash_Next_Access_Waiting <= '0';
         Flash_Update_Counter <= 0;
         Flash_Member_Data <= (OTHERS => '0');
         Flash_Data_Ready <= '0';
         Flash_SPI_Requested_Words_INT <= 8;
         Flash_SPI_Mode_0 <= Default_Read_Command; -- Needed to be able to initiate the first dummy read after booting (synchronizing the SPI bus).
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Flash_SPI_Init_Done = '1') THEN
            IF ((PPC_Dock.Router_Data.TS = '1') AND (Flash_SPI_Transfer_OnGoing = '0')) THEN
               IF (Lock_Config_Access = '1') THEN
                  Flash_Member_Data <= (Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data);
                  Flash_Data_Ready <= '1';
                  Flash_Next_Access_Waiting <= '0';
               ELSE
                  Flash_SPI_Access_AD <= (PPC_Dock.Router_Data.AD & SPI_Word_AD);
                  Flash_SPI_Transfer_OnGoing <= '1';
                  Flash_Start_Access <= '1';
                  Flash_Update_Counter <= TO_INTEGER(UNSIGNED(SPI_Word_AD));
                  Flash_Data_Ready <= '0';
                  Flash_SPI_Requested_Words_INT <= TO_INTEGER(UNSIGNED(SPI_Requested_Read_Words));
                  Flash_SPI_Mode_0 <= Default_Read_Command;
               END IF;
            ELSIF ((PPC_Dock.Router_Data.TS = '1') AND (Flash_SPI_Transfer_OnGoing = '1')) THEN
               IF (Lock_Config_Access = '1') THEN
                  Flash_Member_Data <= (Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data & Flash_SPI_RD_Data);
                  Flash_Data_Ready <= '1';
                  Flash_Next_Access_Waiting <= '0';
               ELSE
                  Flash_Next_Access_Waiting <= '1';
                  Flash_Data_Ready <= '0';
                  Flash_SPI_Access_AD <= (PPC_Dock.Router_Data.AD & SPI_Word_AD);
                  Flash_SPI_Requested_Words_INT <= TO_INTEGER(UNSIGNED(SPI_Requested_Read_Words));
                  Flash_SPI_Mode_0 <= Default_Read_Command;
               END IF;
            ELSIF ((Flash_Next_Access_Waiting = '1') AND (Flash_SPI_Transfer_OnGoing = '0')) THEN
               Flash_Start_Access <= '1';
               Flash_Update_Counter <= TO_INTEGER(UNSIGNED(SPI_Word_AD));
               Flash_SPI_Transfer_OnGoing <= '1';
               Flash_Next_Access_Waiting <= '0';
               Flash_Data_Ready <= '0';
               Flash_SPI_Requested_Words_INT <= TO_INTEGER(UNSIGNED(SPI_Requested_Read_Words));
               Flash_SPI_Mode_0 <= Default_Read_Command;
            ELSIF ((Flash_SPI_Transfer_OnGoing = '1') AND (Flash_SPI_WREN = '1') AND (Lock_Config_Access = '0')) THEN
               CASE Flash_Update_Counter IS
                  WHEN 0 =>
                     Flash_Member_Data(31 DOWNTO 24) <= Flash_SPI_Data_INT;
                  WHEN 1 =>
                     Flash_Member_Data(23 DOWNTO 16) <= Flash_SPI_Data_INT;
                  WHEN 2 =>
                     Flash_Member_Data(15 DOWNTO 8) <= Flash_SPI_Data_INT;
                  WHEN 3 =>
                     Flash_Member_Data(7 DOWNTO 0) <= Flash_SPI_Data_INT;
                  WHEN 4 =>
                     Flash_Member_Data(63 DOWNTO 56) <= Flash_SPI_Data_INT;
                  WHEN 5 =>
                     Flash_Member_Data(55 DOWNTO 48) <= Flash_SPI_Data_INT;
                  WHEN 6 =>
                     Flash_Member_Data(47 DOWNTO 40) <= Flash_SPI_Data_INT;
                  WHEN 7 =>
                     Flash_Member_Data(39 DOWNTO 32) <= Flash_SPI_Data_INT;
                  WHEN OTHERS =>
                     Flash_Member_Data(7 DOWNTO 0) <= Flash_SPI_Data_INT;
               END CASE;
               IF (Flash_Update_Counter = ((TO_INTEGER(UNSIGNED(SPI_Requested_Read_Words)) -1) + TO_INTEGER(UNSIGNED(SPI_Word_AD)))) THEN
                  Flash_Update_Counter <= 0;
                  Flash_Data_Ready <= '1';
                  Flash_SPI_Transfer_OnGoing <= '0';
               ELSE
                  Flash_Update_Counter <= (Flash_Update_Counter + 1);
                  Flash_Data_Ready <= '0';
                  Flash_Start_Access <= '0';
               END IF;
               Flash_SPI_Mode_0 <= Default_Read_Command;
            ELSIF (Flash_Config_Access = '1') THEN
               Flash_SPI_Access_AD <= Flash_Config_AD;
               Flash_SPI_Transfer_OnGoing <= '1';
               Flash_Start_Access <= '1';
               Flash_Update_Counter <= 0;
               Flash_Data_Ready <= '1';
               Flash_SPI_Mode_0 <= Flash_Config_Cmd;
               IF ( (Flash_Config_Cmd = X"20") OR (Flash_Config_Cmd = X"D8") OR (Flash_Config_Cmd = X"01") OR(Flash_Config_Cmd = X"C7") OR (Flash_Config_Cmd = X"9F") OR (Flash_Config_Cmd = X"05") OR (Flash_Config_Cmd = X"06") OR (Flash_Config_Cmd = X"81") OR (Flash_Config_Cmd = X"8F") OR (Flash_Config_Cmd = X"83") OR (Flash_Config_Cmd = X"8C")) THEN
                  Flash_SPI_Requested_Words_INT <= 1;
               ELSE
                  Flash_SPI_Requested_Words_INT <= TO_INTEGER(UNSIGNED(Flash_Config_Bytes_INT));
               END IF;
            ELSIF ((Flash_SPI_Transfer_OnGoing = '1') AND ((Flash_SPI_WREN = '1') OR (Flash_SPI_Wait = '0')) AND (Lock_Config_Access = '1')) THEN
               IF (Flash_Update_Counter = (Flash_SPI_Requested_Words_INT - 1)) THEN
                  Flash_Update_Counter <= 0;
                  Flash_Data_Ready <= '1';
                  Flash_SPI_Transfer_OnGoing <= '0';
               ELSE
                  Flash_Update_Counter <= (Flash_Update_Counter + 1);
                  Flash_Data_Ready <= '1';
                  Flash_Start_Access <= '0';
               END IF;
            ELSE
               Flash_Start_Access <= '0';
               Flash_Data_Ready <= '0';
               Flash_SPI_Mode_0 <= Default_Read_Command;
            END IF;
         ELSIF ((PPC_Dock.Router_Data.TS = '1') AND (Flash_SPI_Init_Done = '0')) THEN
               Flash_Next_Access_Waiting <= '1';
               Flash_SPI_Access_AD <= (PPC_Dock.Router_Data.AD & "000");
               Flash_Data_Ready <= '0';
               Flash_SPI_Transfer_OnGoing <= '0';
               Flash_SPI_Requested_Words_INT <= 8;
               Flash_SPI_Mode_0 <= Default_Read_Command;
         END IF;
      END IF;
   END PROCESS Flash_Access_Counter;
   
   
   -- We lock the access to the flash device during a configuration operation (no concurrent read).        
   Config_Access_Controller: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Flash_Config_Access <= '0';
         Lock_Config_Access <= '0';
         Disable_Config_Access <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Flash_Config_Cmd = X"00") THEN
            Flash_Config_Access <= '0';
            Disable_Config_Access <= '0';
         ELSIF (Flash_SPI_Wait = '0') THEN
            Lock_Config_Access <= '0';
            Flash_Config_Access <= '0';
         ELSIF (Flash_Config_Cmd /= X"00") THEN
            IF (Lock_Config_Access = '0') THEN
               IF ((Flash_Config_Cmd = X"20") OR (Flash_Config_Cmd = X"D8") OR (Flash_Config_Cmd = X"01") OR (Flash_Config_Cmd = X"C7") OR (Flash_Config_Cmd = X"88") OR (Flash_Config_Cmd = X"05") OR (Flash_Config_Cmd = X"02") OR (Flash_Config_Cmd = X"06") OR (Flash_Config_Cmd = X"9F") OR (Flash_Config_Cmd = X"81") OR (Flash_Config_Cmd = X"8F") OR (Flash_Config_Cmd = X"83") OR (Flash_Config_Cmd = X"8C")) THEN
                  IF (Disable_Config_Access = '0') THEN
                     Flash_Config_Access <= '1';
                     Lock_Config_Access <= '1';
                     Disable_Config_Access <= '1';
                  ELSE
                     Flash_Config_Access <= '0';
                     Lock_Config_Access <= '0';
                     Disable_Config_Access <= '1';
                  END IF;
               END IF;
            ELSE
               Lock_Config_Access <= '1';
               Flash_Config_Access <= '0';
            END IF;
         END IF;
      END IF;
   END PROCESS Config_Access_Controller;
   
   
   -- We have to make sure that the command is deleted at the PPC memory address after the termination of the operation.
   Flash_Config_ACK: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Flash_Config_Terminated_INT <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (Lock_Config_Access = '1') THEN
            IF (Flash_SPI_Wait = '0') THEN
               Flash_Config_Terminated_INT <= '1';
            ELSE
               Flash_Config_Terminated_INT <= '0';
            END IF;
         ELSIF (Flash_Config_Terminated_INT = '1') THEN
            IF (Flash_Config_Cmd = X"00") THEN
               Flash_Config_Terminated_INT <= '0';
            ELSE
               Flash_Config_Terminated_INT <= '1';
            END IF;
         ELSE
            Flash_Config_Terminated_INT <= '0';
         END IF;
      END IF;
   END PROCESS Flash_Config_ACK;

   
   -- Concurrent 6
   PPC_Dock.Member_Data.IRQ <= (OTHERS => '0');
   PPC_Dock.Member_Data.Write_Delay <= '0';
   PPC_Dock.Member_Data.Slow_Burst <= '0';
   PPC_Dock.Member_Data.Data_Ready <= Flash_Data_Ready;
   PPC_Dock.Member_Data.Entity_Router_Data <= Flash_Member_Data;

END ARCHITECTURE Universal;