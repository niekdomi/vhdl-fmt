-- MODULE SGMII Autonegotiation
-- VHDL Architecture Indel_lib.SGMII_Autonegotiation.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- We do a trivial autonegotiation: The standard defines a complex hand       --
-- shaking for this process. But if you study the SGMII Cisco 1.8 document    --
-- and the Altera IP core PDF and match the two documents together there is a --
-- simple solution to the SGMII autonegotiation process:                      --
-- 1.) You have nothing own to send to the PHY                                --
-- 2.) You can just repeat what the PHY is transmitting                       --
-- 3.) You can simply connect the RX and TX lines!                            --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- We have to make sure that SGMII_TX_CLK_EN signal is generated with the old --
-- link settings even if the link is open or opened and not closed again.     --
--                                                                            --
-- Bugfix for certain PHY's that look for more than one "Carrier_Extend"      --
-- ordered set, based on the number of bytes starting with the K23.7 to the  --
-- K29.7 (End of packet) code group. Marvell and Broadcom PHY's do not take   --
-- care for the number as soon as there is at least one group. Vitesse Semi   --
-- parts test the packet for the correct number even if the link is in full   --
-- duplex mode, even if the IEEE standard mentions that the extension is only --
-- needed in GE half duplex mode.                                             --
--                                                                            --
-- 10MBit/s mode enabled.                                                     --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
--$Rev:: 2287                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2012-05-31 17:09:09 +0200 (Do., 31 Mai 2012)                         $
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

ENTITY SGMII_Autonegotiation IS
  PORT (
        GCLK                      : IN    std_logic; -- 125MHz
        CLR_n                     : IN    std_logic;
        -- FPGA User Data for SGMII transmission
        User_TX_EN                : IN    std_logic;
        User_TX_ER                : IN    std_logic;
        User_TX_Data              : IN    std_logic_vector(7 DOWNTO 0);
        User_RX_DV                : OUT   std_logic;
        User_RX_ERR               : OUT   std_logic;
        User_RX_Data              : OUT   std_logic_vector(7 DOWNTO 0);
        -- RX data from the GX receiver for autonegotiation functions
        GX_PLL_Locked             : IN    std_logic;
        GX_RX_SYNC_Status         : IN    std_logic; -- '1' = in sync
        GX_RX_Pattern_Detect      : IN    std_logic;
        GX_RX_Control_Detect      : IN    std_logic;
        GX_RX_Data                : IN    std_logic_vector(7 DOWNTO 0);
        -- TX data to the GX transmitter
        GX_TX_CTRL_EN             : OUT   std_logic;
        GX_TX_ER                  : OUT   std_logic;
        GX_TX_Data                : OUT   std_logic_vector(7 DOWNTO 0);
        -- SGMII Status register
        SGMII_Link_Status         : OUT   std_logic_vector(15 DOWNTO 0);
        SGMII_RX_Data_Valid_EN    : OUT   std_logic;
        SGMII_TX_CLK_EN           : OUT   std_logic
        );
END ENTITY SGMII_Autonegotiation;


ARCHITECTURE Universal OF SGMII_Autonegotiation IS

   -- Meaning of the SGMII_Link_Status register (it conforms to the Cisco SGMII Standard, Rev. 1.8):
   -- This information is sent from the PHY to the MAC
   -- SGMII_Link_Status(0) = '1'
   -- SGMII_Link_Status(1) = '0', reserved for future use
   -- SGMII_Link_Status(2) = '0', reserved for future use
   -- SGMII_Link_Status(3) = '0', reserved for future use
   -- SGMII_Link_Status(4) = '0', reserved for future use
   -- SGMII_Link_Status(5) = '0', reserved for future use
   -- SGMII_Link_Status(6) = '0', reserved for future use
   -- SGMII_Link_Status(7) = '0', reserved for future use
   -- SGMII_Link_Status(8) = '0', reserved for future use
   -- SGMII_Link_Status(9) = '0', reserved for future use
   -- SGMII_Link_Status(10) = Speed(0)
   -- SGMII_Link_Status(11) = Speed(1), Speed: "00" = 10Mbps, "01" = 100Mbps, "10" = 1Gbps, "11" = reserved
   -- SGMII_Link_Status(12) = Duplex Mode: '1' = full duplex, '0' = half duplex
   -- SGMII_Link_Status(13) = '0', reserved for future use
   -- SGMII_Link_Status(14) = Reserved for Autonegotiation Acknowledge
   -- SGMII_Link_Status(15) = Link: '1' = link up, '0' = link down


   -------------------
   -- Type Declaration
   -------------------
  
   -----------------------
   -- Type Declaration END
   -----------------------
   
   
   ---------------------------
   -- State Vector Declaration
   ---------------------------

   -------------------------------
   -- State Vector Declaration END
   -------------------------------
   
   
   -----------------------
   -- Constant Declaration
   -----------------------
   CONSTANT SGMII_Autoneg_D21_5        : std_logic_vector(7 DOWNTO 0):= X"B5";
   COnstant SGMII_Autoneg_D2_2         : std_logic_vector(7 DOWNTO 0):= X"42";
   
   ---------------------------
   -- Constant Declaration END
   ---------------------------
   
   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL SGMII_Pattern_Detected           : std_logic;
   SIGNAL SGMII_Configuration              : std_logic;
   SIGNAL GX_RX_Stored_Data                : std_logic_vector(31 DOWNTO 0);
   SIGNAL GX_RX_Stored_Pattern_Detect      : std_logic_vector(3 DOWNTO 0);
   SIGNAL GX_RX_Stored_Control_Detect      : std_logic_vector(3 DOWNTO 0);

   SIGNAL GX_TX_Stored_Data                : std_logic_vector(31 DOWNTO 0);
   SIGNAL GX_TX_Stored_EN                  : std_logic_vector(3 DOWNTO 0);
   SIGNAL GX_TX_Stored_ERR                 : std_logic_vector(3 DOWNTO 0);

   SIGNAL SGMII_Config_Count               : natural RANGE 0 TO 3;
   SIGNAL SGMII_User_Mode                  : std_logic;
   SIGNAL SGMII_PHY_Configuration          : std_logic_vector(15 DOWNTO 0);
   SIGNAL RX_SGMII_Idle                    : std_logic;
   SIGNAL TX_SGMII_Idle                    : std_logic;
   SIGNAL TX_SGMII_Packet_Start            : std_logic;
   SIGNAL TX_SGMII_Delayed_Packet          : std_logic;
   SIGNAL TX_SGMII_Shift_Packet            : std_logic;
   SIGNAL TX_SGMII_Delayed_Packet_End      : std_logic;
   SIGNAL TX_SGMII_Carrier_Extend          : std_logic;
   SIGNAL TX_SGMII_ODD_nEVEN_Bit_NR        : std_logic;
            
   SIGNAL User_RX_DV_INT                   : std_logic;
   SIGNAL User_RX_ERR_INT                  : std_logic;
   SIGNAL User_RX_Data_INT                 : std_logic_vector(7 DOWNTO 0);
   SIGNAL User_GX_TX_CTRL_EN               : std_logic;
   SIGNAL User_GX_TX_Data                  : std_logic_vector(7 DOWNTO 0);
   SIGNAL GX_TX_CTRL_EN_INT                : std_logic;
   SIGNAL GX_TX_ER_INT                     : std_logic;
   SIGNAL GX_TX_Data_INT                   : std_logic_vector(7 DOWNTO 0);
   
   SIGNAL Carrier_Extend_Counter           : natural RANGE 0 TO 63;
   SIGNAL SGMII_Link_Speed_Counter_EN      : std_logic;
   SIGNAL SGMII_Link_Speed_Counter_EN_INT  : std_logic;
   SIGNAL SGMII_Link_Speed_Counter         : natural RANGE 0 TO 127;
   SIGNAL SGMII_RX_Data_Valid_EN_INT       : std_logic;
   SIGNAL SGMII_TX_CLK_EN_INT              : std_logic;
   SIGNAL SGMII_TX_CLK_EN_Counter          : natural RANGE 0 TO 127;
   SIGNAL SGMII_Old_Link_Speed             : std_logic_vector(1 DOWNTO 0);
   
   SIGNAL User_TX_EN_INT                   : std_logic;
   SIGNAL User_TX_ER_INT                   : std_logic;
   SIGNAL User_TX_Data_INT                 : std_logic_vector(7 DOWNTO 0);
   SIGNAL Timeout_Elapsed                  : std_logic;
   SIGNAL Timeout_Lock                     : std_logic;
   SIGNAL User_TX_EN_INT_Stored            : std_logic;
   SIGNAL SGMII_User_Mode_Stored           : std_logic;
   SIGNAL User_Mode_Idle_Counter           : natural RANGE 0 TO 1023;
   SIGNAL User_Mode_Idle_Counter_INT       : natural RANGE 0 TO 1023;
   -------------------------
   -- Signal Declaration END
   -------------------------
   
   ------------------------
   -- Component Declaration
   ------------------------

   ----------------------------
   -- Component Declaration END
   ----------------------------

BEGIN

   -- Concurrent 0
   SGMII_Link_Status <= SGMII_PHY_Configuration;
   SGMII_RX_Data_Valid_EN <= SGMII_RX_Data_Valid_EN_INT;
   SGMII_TX_CLK_EN <= SGMII_TX_CLK_EN_INT;


   -- We store the RX data in a shift register: - we have to replace the K27.7 by a an additional 0x55......
   Store_RX_Data: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         GX_RX_Stored_Control_Detect <= (OTHERS => '0');
         GX_RX_Stored_Pattern_Detect <= (OTHERS => '0');
         GX_RX_Stored_Data <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         GX_RX_Stored_Control_Detect <= (GX_RX_Stored_Control_Detect(2 DOWNTO 0) & GX_RX_Control_Detect);
         GX_RX_Stored_Pattern_Detect <= (GX_RX_Stored_Pattern_Detect(2 DOWNTO 0) & GX_RX_Pattern_Detect);
         GX_RX_Stored_Data <= (GX_RX_Stored_Data(23 DOWNTO 0) & GX_RX_Data);
      END IF;
   END PROCESS Store_RX_Data;


   -- We store the TX data in a shift register, too. Based on the fact that we have to delay the outgoing data
   -- when the IDLE sequence is not finished.
   Store_TX_Data: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         GX_TX_Stored_EN <= (OTHERS => '0');
         GX_TX_Stored_ERR <= (OTHERS => '0');
         GX_TX_Stored_Data <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         GX_TX_Stored_EN <= (GX_TX_Stored_EN(2 DOWNTO 0) & User_TX_EN_INT);
         GX_TX_Stored_ERR <= (GX_TX_Stored_ERR(2 DOWNTO 0) & User_TX_ER_INT);
         GX_TX_Stored_Data <= (GX_TX_Stored_Data(23 DOWNTO 0) & User_TX_Data_INT);
      END IF;
   END PROCESS Store_TX_Data;
   
   
   
   -- We send data to the GX transmitter only if a certain amount of IDLE's could be inserted after the link is up.
   Switch_TX_Data: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         User_TX_EN_INT <= '0';
         User_TX_ER_INT <= '0';
         User_TX_Data_INT <= (OTHERS => '0');
         Timeout_Lock <= '0';
         User_TX_EN_INT_Stored <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         User_TX_EN_INT_Stored <= User_TX_EN;
         IF (Timeout_Elapsed = '1') THEN
            IF (Timeout_Lock = '0') THEN
               IF ((User_TX_EN_INT_Stored = '0') AND (User_TX_EN = '1')) THEN
                  User_TX_EN_INT <= User_TX_EN;
                  User_TX_ER_INT <= User_TX_ER;
                  User_TX_Data_INT <= User_TX_Data;
                  Timeout_Lock <= '1';
               ELSE
                  User_TX_EN_INT <= '0';
                  User_TX_ER_INT <= '0';
                  User_TX_Data_INT <= (OTHERS => '0');
                  Timeout_Lock <= '0';
               END IF;
            ELSE
               User_TX_EN_INT <= User_TX_EN;
               User_TX_ER_INT <= User_TX_ER;
               User_TX_Data_INT <= User_TX_Data;
               Timeout_Lock <= '1';
            END IF;
         ELSE
            User_TX_EN_INT <= '0';
            User_TX_ER_INT <= '0';
            User_TX_Data_INT <= (OTHERS => '0');
            Timeout_Lock <= '0';
         END IF;
      END IF;
   END PROCESS Switch_TX_Data;
   
   
   
   -- We make sure that the link is IDLE for a certain amount in time...
   Init_User_Mode_Counter: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Timeout_Elapsed <= '0';
         SGMII_User_Mode_Stored <= '0';
         User_Mode_Idle_Counter <= 0;
         User_Mode_Idle_Counter_INT <= 0;
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         SGMII_User_Mode_Stored <= SGMII_User_Mode;
         IF ((SGMII_PHY_Configuration(15 DOWNTO 14) = "11") AND (SGMII_User_Mode_Stored = '0') AND (SGMII_User_Mode = '1')) THEN
            Timeout_Elapsed <= '0';
            User_Mode_Idle_Counter <= 0;
            User_Mode_Idle_Counter_INT <= 0;
         ELSIF (SGMII_User_Mode = '1') THEN
            IF (User_Mode_Idle_Counter = 1023) THEN
               Timeout_Elapsed <= '1';
               User_Mode_Idle_Counter <= User_Mode_Idle_Counter;
               User_Mode_Idle_Counter_INT <= 0;
            ELSE
               IF (User_Mode_Idle_Counter_INT = 1023) THEN
                  User_Mode_Idle_Counter <= (User_Mode_Idle_Counter + 1);
                  User_Mode_Idle_Counter_INT <= 0;
               ELSE
                  User_Mode_Idle_Counter_INT <= (User_Mode_Idle_Counter_INT + 1);
                  User_Mode_Idle_Counter <= User_Mode_Idle_Counter;
               END IF;
               Timeout_Elapsed <= '0';
            END IF;
         ELSE
            Timeout_Elapsed <= '0';
            User_Mode_Idle_Counter <= 0;
            User_Mode_Idle_Counter_INT <= 0;
         END IF;
      END IF;
   END PROCESS Init_User_Mode_Counter;
   



   -- We try to find out the actual status of the link, so that we can decide if we have to switch to autonegotiation.
   Detect_Autonegotiation: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         SGMII_User_Mode <= '0';
         SGMII_PHY_Configuration <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((GX_RX_Stored_Control_Detect(3) = '1') AND (GX_RX_Stored_Pattern_Detect(3) = '1')) THEN 
            IF ((GX_RX_Stored_Data(23 DOWNTO 16) = SGMII_Autoneg_D21_5) OR (GX_RX_Stored_Data(23 DOWNTO 16) = SGMII_Autoneg_D2_2)) THEN -- Autonegotiation packets are transmitted...
               SGMII_User_Mode <= '0';
               IF (GX_RX_Stored_Data(15 DOWNTO 8) = "00000001") THEN -- the link is up and running...
                  SGMII_PHY_Configuration <= (GX_RX_Stored_Data(7 DOWNTO 0) & GX_RX_Stored_Data(15 DOWNTO 8));
               ELSE
                  SGMII_PHY_Configuration <= (OTHERS => '0');
               END IF;
            ELSE
               SGMII_User_Mode <= '1';
               SGMII_PHY_Configuration <= SGMII_PHY_Configuration;
            END IF;
         ELSE
            SGMII_User_Mode <= SGMII_User_Mode;
            SGMII_PHY_Configuration <= SGMII_PHY_Configuration;
         END IF;
      END IF;
   END PROCESS Detect_Autonegotiation;


   -- We connect the RX input directly to the TX output ;-)
   Loop_Autonegotiation_Data: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         GX_TX_CTRL_EN_INT <= '0';
         GX_TX_ER_INT <= '0';
         GX_TX_Data_INT <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (SGMII_User_Mode = '1') THEN -- Normal mode of operation
            GX_TX_CTRL_EN_INT <= User_GX_TX_CTRL_EN;
            GX_TX_ER_INT <= '0';
            GX_TX_Data_INT <= User_GX_TX_Data;
         ELSE -- Autonegotiation mode
            GX_TX_CTRL_EN_INT <= GX_RX_Stored_Control_Detect(0);
            GX_TX_ER_INT <= '0';
            GX_TX_Data_INT <= GX_RX_Stored_Data(7 DOWNTO 0);
         END IF;
      END IF;
   END PROCESS Loop_Autonegotiation_Data;
   
   
   
   Enable_Generate_SGMII_Data_Valid: IF (SGMII_GEN_Data_Valid_EN_C_S_PKG) GENERATE
   BEGIN
      -- Based on the stored autonegotiation data, the "SGMII_Data_Valid" signal has to be generated.
      -- This signal can be used as clock enable in the MAC entity to acquire the link data. We need such a
      -- signal, because the data is transmitted 1x, 10x or 100x fold over the SGMII interface at the
      -- different link speeds (1000, 100, 10 MBit/s).
      -- Attention: There are PHY's (like our Marvell 88E1112) which send the first preamble byte only (n-1) times!
      -- Example 100MBit/s: 1 x K27.7 + 1 x 9 x h55 + 6 x 10 x h55 + 1 x hD5 +.....................
      Generate_SGMII_Data_Valid: PROCESS(GCLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            SGMII_RX_Data_Valid_EN_INT <= '0';
            SGMII_Link_Speed_Counter_EN_INT <= '0';
            SGMII_Link_Speed_Counter <= 0;
         ELSIF (GCLK'EVENT AND GCLK = '1') THEN
            IF (SGMII_PHY_Configuration(15 DOWNTO 14) = "11") THEN -- Link up (15), Acknowledge ok (14)
               CASE SGMII_PHY_Configuration(11 DOWNTO 10) IS -- Link Speed
                  WHEN "00" => -- 10 Mbps
                     IF (SGMII_Link_Speed_Counter_EN = '1') THEN
                        IF ((SGMII_Link_Speed_Counter_EN_INT = '0') OR (SGMII_Link_Speed_Counter = 99)) THEN -- The MAC needs every 100'th byte.
                           SGMII_RX_Data_Valid_EN_INT <= '1';
                           SGMII_Link_Speed_Counter <= 0;
                        ELSE
                           SGMII_RX_Data_Valid_EN_INT <= '0';
                           SGMII_Link_Speed_Counter <= (SGMII_Link_Speed_Counter + 1);
                        END IF;
                     ELSIF (SGMII_Link_Speed_Counter_EN = '0') THEN
                        IF (SGMII_Link_Speed_Counter = 99) THEN -- The MAC needs every 100'th byte.
                           SGMII_RX_Data_Valid_EN_INT <= '1';
                           SGMII_Link_Speed_Counter <= 0;
                        ELSE
                           SGMII_RX_Data_Valid_EN_INT <= '0';
                           SGMII_Link_Speed_Counter <= (SGMII_Link_Speed_Counter + 1);
                        END IF;
                     ELSE
                        SGMII_RX_Data_Valid_EN_INT <= '0';
                        SGMII_Link_Speed_Counter <= 0;
                     END IF;
                  WHEN "01" => -- 100 Mbps
                     IF (SGMII_Link_Speed_Counter_EN = '1') THEN
                        IF ((SGMII_Link_Speed_Counter_EN_INT = '0') OR (SGMII_Link_Speed_Counter = 9)) THEN -- The MAC needs every 10'th byte.
                           SGMII_RX_Data_Valid_EN_INT <= '1';
                           SGMII_Link_Speed_Counter <= 0;
                        ELSE
                           SGMII_RX_Data_Valid_EN_INT <= '0';
                           SGMII_Link_Speed_Counter <= (SGMII_Link_Speed_Counter + 1);
                        END IF;
                     ELSIF (SGMII_Link_Speed_Counter_EN = '0') THEN
                        IF (SGMII_Link_Speed_Counter = 9) THEN -- The MAC needs every 10'th byte
                           SGMII_RX_Data_Valid_EN_INT <= '1';
                           SGMII_Link_Speed_Counter <= 0;
                        ELSE
                           SGMII_RX_Data_Valid_EN_INT <= '0';
                           SGMII_Link_Speed_Counter <= (SGMII_Link_Speed_Counter + 1);
                        END IF;
                     ELSE
                        SGMII_RX_Data_Valid_EN_INT <= '0';
                        SGMII_Link_Speed_Counter <= 0;
                     END IF;
                  WHEN "10" => -- 1000 Mbps
                     SGMII_RX_Data_Valid_EN_INT <= '1'; -- The MAC needs every byte.
                     SGMII_Link_Speed_Counter <= 0;
                  WHEN "11" => -- Reserved
                     SGMII_RX_Data_Valid_EN_INT <= '0'; -- The MAC needs no byte.
                     SGMII_Link_Speed_Counter <= 0;
                  WHEN OTHERS =>
                     SGMII_RX_Data_Valid_EN_INT <= '0'; -- The MAC needs no byte.
                     SGMII_Link_Speed_Counter <= 0;
               END CASE;
            ELSE
               SGMII_RX_Data_Valid_EN_INT <= '0';
               SGMII_Link_Speed_Counter <= 0;
            END IF;
            SGMII_Link_Speed_Counter_EN_INT <= SGMII_Link_Speed_Counter_EN;
         END IF;
      END PROCESS Generate_SGMII_Data_Valid;
      
      

      -- Generate TX CLK EN for the MAC
      Generate_TX_CLK_EN: PROCESS(GCLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            SGMII_TX_CLK_EN_INT  <= '0';
            SGMII_TX_CLK_EN_Counter <=  0;
            SGMII_Old_Link_Speed <= "01"; -- 100MBit/s, so that the EtherCAT IRQ is generated for the CPU even if the link is open.
         ELSIF (GCLK'EVENT AND GCLK = '1') THEN
            IF (SGMII_PHY_Configuration(15 DOWNTO 14) = "11") THEN -- Link up (15), Acknowledge ok (14)
               CASE SGMII_PHY_Configuration(11 DOWNTO 10) IS -- Link Speed
                  WHEN "00" => -- 10 Mbps
                     IF (SGMII_TX_CLK_EN_Counter = 99) THEN -- The MAC needs every 100'th byte.
                        SGMII_TX_CLK_EN_INT <= '1';
                        SGMII_TX_CLK_EN_Counter <= 0;
                     ELSE
                        SGMII_TX_CLK_EN_INT <= '0';
                        SGMII_TX_CLK_EN_Counter <= (SGMII_TX_CLK_EN_Counter + 1);
                     END IF;
                     SGMII_Old_Link_Speed <= "00";
                  WHEN "01" => -- 100Mbps
                     IF (SGMII_TX_CLK_EN_Counter = 9) THEN -- The MAC needs every 10'th byte.
                        SGMII_TX_CLK_EN_INT <= '1';
                        SGMII_TX_CLK_EN_Counter <= 0;
                     ELSE
                        SGMII_TX_CLK_EN_INT <= '0';
                        SGMII_TX_CLK_EN_Counter <= (SGMII_TX_CLK_EN_Counter + 1);
                     END IF;
                     SGMII_Old_Link_Speed <= "01";
                  WHEN "10" => -- 1000Mbps
                     SGMII_TX_CLK_EN_INT  <= '1';
                     SGMII_TX_CLK_EN_Counter <=  0;
                     SGMII_Old_Link_Speed <= "10";
                  WHEN "11" => -- Reserved
                     SGMII_TX_CLK_EN_INT  <= '0';
                     SGMII_TX_CLK_EN_Counter <=  0;
                     SGMII_Old_Link_Speed <= "11";
                  WHEN OTHERS =>
                     SGMII_TX_CLK_EN_INT  <= '0';
                     SGMII_TX_CLK_EN_Counter <=  0;
                     SGMII_Old_Link_Speed <= "11";
               END CASE;
            ELSE
               CASE SGMII_Old_Link_Speed IS -- Link Speed
                  WHEN "00" => -- 10 Mbps
                     IF (SGMII_TX_CLK_EN_Counter = 99) THEN -- The MAC needs every 100'th byte.
                        SGMII_TX_CLK_EN_INT <= '1';
                        SGMII_TX_CLK_EN_Counter <= 0;
                     ELSE
                        SGMII_TX_CLK_EN_INT <= '0';
                        SGMII_TX_CLK_EN_Counter <= (SGMII_TX_CLK_EN_Counter + 1);
                     END IF;
                  WHEN "01" => -- 100Mbps
                     IF (SGMII_TX_CLK_EN_Counter = 9) THEN -- The MAC needs every 10'th byte.
                        SGMII_TX_CLK_EN_INT <= '1';
                        SGMII_TX_CLK_EN_Counter <= 0;
                     ELSE
                        SGMII_TX_CLK_EN_INT <= '0';
                        SGMII_TX_CLK_EN_Counter <= (SGMII_TX_CLK_EN_Counter + 1);
                     END IF;
                  WHEN "10" => -- 1000Mbps
                     SGMII_TX_CLK_EN_INT  <= '1';
                     SGMII_TX_CLK_EN_Counter <=  0;
                  WHEN "11" => -- Reserved
                     SGMII_TX_CLK_EN_INT  <= '0';
                     SGMII_TX_CLK_EN_Counter <=  0;
                  WHEN OTHERS =>
                     SGMII_TX_CLK_EN_INT  <= '0';
                     SGMII_TX_CLK_EN_Counter <=  0;
               END CASE;
            END IF;
         END IF;
      END PROCESS Generate_TX_CLK_EN;
      -- END Generate TX CLK EN for the MAC
      
      
   END GENERATE Enable_Generate_SGMII_Data_Valid;


   Disable_Generate_SGMII_Data_Valid: IF NOT(SGMII_GEN_Data_Valid_EN_C_S_PKG) GENERATE
   BEGIN
      SGMII_RX_Data_Valid_EN_INT <= '0';
      SGMII_TX_CLK_EN_INT <= '1';
   END GENERATE Disable_Generate_SGMII_Data_Valid;

   -- Concurrent 1
   GX_TX_CTRL_EN <= GX_TX_CTRL_EN_INT;
   GX_TX_ER <= GX_TX_ER_INT;
   GX_TX_Data <= GX_TX_Data_INT;


   -- We have to synchronize the TX data with the RX data (autonegotiation mode) or with the MAC GMII TX data, based on the actual mode.
   TX_SGMII_GEN: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         TX_SGMII_Idle <= '0';
         TX_SGMII_Delayed_Packet <= '0';
         TX_SGMII_Shift_Packet <= '0';
         TX_SGMII_Packet_Start <= '0';
         TX_SGMII_Delayed_Packet_End <= '0';
         TX_SGMII_Carrier_Extend <= '0';
         User_GX_TX_CTRL_EN <= '0';
         User_GX_TX_Data <= (OTHERS => '0');
         Carrier_Extend_Counter <= 0;
         TX_SGMII_ODD_nEVEN_Bit_NR <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((GX_TX_Stored_EN(2) = '0') AND  (GX_TX_Stored_EN(3) = '0') AND (TX_SGMII_Delayed_Packet_End = '0') AND (TX_SGMII_Carrier_Extend = '0') AND (GX_TX_Stored_Data(23 DOWNTO 16) = X"00")) THEN
            IF (GX_TX_Data_INT = X"BC") THEN -- IDLE
               TX_SGMII_Idle <= '1';
               TX_SGMII_Packet_Start <= '0';
               User_GX_TX_CTRL_EN <= '1';
               User_GX_TX_Data <= X"BC";
            ELSIF (TX_SGMII_Idle = '1') THEN
               TX_SGMII_Idle <= '0';
               TX_SGMII_Packet_Start <= '0';
               User_GX_TX_CTRL_EN <= '0';
               User_GX_TX_Data <= X"50";
            ELSE
               TX_SGMII_Idle <= '1';
               TX_SGMII_Packet_Start <= '0';
               User_GX_TX_CTRL_EN <= '1';
               User_GX_TX_Data <= X"BC";
            END IF;
            TX_SGMII_Delayed_Packet <= '0';
            TX_SGMII_Shift_Packet <= '0';
            TX_SGMII_Delayed_Packet_End <= '0';
            TX_SGMII_Carrier_Extend <= '0';
            Carrier_Extend_Counter <= 0;
            TX_SGMII_ODD_nEVEN_Bit_NR <= '0';
         ELSIF ((GX_TX_Stored_EN(2) = '1') AND (GX_TX_Stored_Data(23 DOWNTO 16) = X"55") AND (GX_TX_Stored_EN(3) = '0')) THEN -- Start of Packet
            IF (TX_SGMII_Idle = '1') THEN
               TX_SGMII_Idle <= '0';
               TX_SGMII_Delayed_Packet <= '1';
               TX_SGMII_Packet_Start <= '0';
               User_GX_TX_CTRL_EN <= '0';
               User_GX_TX_Data <= X"50";
            ELSE
               TX_SGMII_Idle <= '0';
               TX_SGMII_Delayed_Packet <= '0';
               TX_SGMII_Packet_Start <= '1';
               User_GX_TX_CTRL_EN <= '1';
               User_GX_TX_Data <= X"FB";
               TX_SGMII_ODD_nEVEN_Bit_NR <= '1';
            END IF;
            TX_SGMII_Shift_Packet <= '0';
            TX_SGMII_Delayed_Packet_End <= '0';
            TX_SGMII_Carrier_Extend <= '0';
         ELSIF ((GX_TX_Stored_EN(2) = '0') AND (GX_TX_Stored_EN(3) = '1')) THEN
            TX_SGMII_Idle <= '0';
            TX_SGMII_Packet_Start <= '0';
            TX_SGMII_Delayed_Packet <= '0';
            TX_SGMII_Shift_Packet <= '0';
            IF (TX_SGMII_Shift_Packet = '1') THEN
               TX_SGMII_Delayed_Packet_End <= '1';
               TX_SGMII_Carrier_Extend <= '0';
               User_GX_TX_CTRL_EN <= '0';
               User_GX_TX_Data <= GX_TX_Stored_Data(31 DOWNTO 24);
               TX_SGMII_ODD_nEVEN_Bit_NR <= NOT(TX_SGMII_ODD_nEVEN_Bit_NR);
            ELSE
               TX_SGMII_Delayed_Packet_End <= '0';
               TX_SGMII_Carrier_Extend <= '1';
               User_GX_TX_CTRL_EN <= '1';
               User_GX_TX_Data <= X"FD";
            END IF;
         ELSIF (TX_SGMII_Delayed_Packet_End = '1') THEN
            TX_SGMII_Idle <= '0';
            TX_SGMII_Delayed_Packet <= '0';
            TX_SGMII_Packet_Start <= '0';
            TX_SGMII_Shift_Packet <= '0';
            TX_SGMII_Delayed_Packet_End <= '0';
            TX_SGMII_Carrier_Extend <= '1';
            User_GX_TX_CTRL_EN <= '1';
            User_GX_TX_Data <= X"FD";
         ELSIF (TX_SGMII_Carrier_Extend = '1') THEN -- Carrier Extend
            IF (TX_SGMII_ODD_nEVEN_Bit_NR = '0') THEN 
               TX_SGMII_Idle <= '0';
               TX_SGMII_Delayed_Packet <= '0';
               TX_SGMII_Packet_Start <= '0';
               TX_SGMII_Shift_Packet <= '0';
               TX_SGMII_Delayed_Packet_End <= '0';
               TX_SGMII_Carrier_Extend <= '0';
               User_GX_TX_CTRL_EN <= '1';
               User_GX_TX_Data <= X"F7";
               Carrier_Extend_Counter <= 0;
            ELSE
               TX_SGMII_Idle <= '0';
               TX_SGMII_Delayed_Packet <= '0';
               TX_SGMII_Packet_Start <= '0';
               TX_SGMII_Shift_Packet <= '0';
               TX_SGMII_Delayed_Packet_End <= '0';
               TX_SGMII_Carrier_Extend <= '1';
               User_GX_TX_CTRL_EN <= '1';
               User_GX_TX_Data <= X"F7";
               Carrier_Extend_Counter <= (Carrier_Extend_Counter + 1);
               TX_SGMII_ODD_nEVEN_Bit_NR <= NOT(TX_SGMII_ODD_nEVEN_Bit_NR);
            END IF;
         ELSIF (TX_SGMII_Delayed_Packet = '1') THEN
            TX_SGMII_Idle <= '0';
            TX_SGMII_Delayed_Packet <= '0';
            TX_SGMII_Packet_Start <= '1';
            TX_SGMII_Shift_Packet <= '1';
            TX_SGMII_Delayed_Packet_End <= '0';
            TX_SGMII_Carrier_Extend <= '0';
            User_GX_TX_CTRL_EN <= '1';
            User_GX_TX_Data <= X"FB";
            TX_SGMII_ODD_nEVEN_Bit_NR <= '1';
         ELSIF (TX_SGMII_Packet_Start = '1') THEN
            TX_SGMII_Idle <= '0';
            TX_SGMII_Packet_Start <= '0';
            TX_SGMII_Delayed_Packet <= '0';
            TX_SGMII_Delayed_Packet_End <= '0';
            TX_SGMII_Carrier_Extend <= '0';
            User_GX_TX_CTRL_EN <= '0';
            IF (TX_SGMII_Shift_Packet = '1') THEN
               User_GX_TX_Data <= GX_TX_Stored_Data(31 DOWNTO 24);
            ELSE
               User_GX_TX_Data <= GX_TX_Stored_Data(23 DOWNTO 16);
            END IF;
            TX_SGMII_ODD_nEVEN_Bit_NR <= NOT(TX_SGMII_ODD_nEVEN_Bit_NR);
         ELSE
            TX_SGMII_Idle <= '0';
            TX_SGMII_Packet_Start <= '0';
            TX_SGMII_Delayed_Packet <= '0';
            TX_SGMII_Delayed_Packet_End <= '0';
            TX_SGMII_Carrier_Extend <= '0';
            User_GX_TX_CTRL_EN <= '0';
            IF (TX_SGMII_Shift_Packet = '1') THEN
               User_GX_TX_Data <= GX_TX_Stored_Data(31 DOWNTO 24);
            ELSE
               User_GX_TX_Data <= GX_TX_Stored_Data(23 DOWNTO 16);
            END IF;
            TX_SGMII_ODD_nEVEN_Bit_NR <= NOT(TX_SGMII_ODD_nEVEN_Bit_NR);
         END IF;
      END IF;
   END PROCESS TX_SGMII_GEN;


   -- We format the data and insert an additional 0x55 into the Preamble and generate the GMII and the Speed_EN signals.
   RX_GMII_GEN: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         RX_SGMII_Idle <= '0';
         User_RX_DV_INT <= '0';
         User_RX_ERR_INT <= '0';
         User_RX_Data_INT <= (OTHERS => '0');
         SGMII_Link_Speed_Counter_EN <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF (GX_RX_Stored_Control_Detect(1) = '1') THEN
            IF (GX_RX_Stored_Pattern_Detect(1) = '1') THEN
               RX_SGMII_Idle <= '1';
               User_RX_DV_INT <= '0';
               User_RX_ERR_INT <= '0';
               User_RX_Data_INT <= (OTHERS => '0');
               SGMII_Link_Speed_Counter_EN <= '0';
            ELSE
               CASE GX_RX_Stored_Data(15 DOWNTO 8) IS
                  WHEN X"FB" => -- Start Of Packet
                     RX_SGMII_Idle <= '0';
                     User_RX_DV_INT <= '1';
                     User_RX_ERR_INT <= '0';
                     User_RX_Data_INT <= X"55";-- We have to make the SGMII interface compatible with the RGMII MAC
                     SGMII_Link_Speed_Counter_EN <= '1';
                  WHEN X"FD" => -- End Of Packet, signal it
                     RX_SGMII_Idle <= '1';
                     User_RX_DV_INT <= '0';
                     User_RX_ERR_INT <= '0';
                     User_RX_Data_INT <= (OTHERS => '0');
                     SGMII_Link_Speed_Counter_EN <= '0';
                  WHEN X"F7" => -- Carrier Extend, discard
                     RX_SGMII_Idle <= '1';
                     User_RX_DV_INT <= '0';
                     User_RX_ERR_INT <= '0';
                     User_RX_Data_INT <= (OTHERS => '0');
                     SGMII_Link_Speed_Counter_EN <= '0';
                  WHEN X"FE" => -- Error Propagation, throw away
                     RX_SGMII_Idle <= '0';
                     SGMII_Link_Speed_Counter_EN <= '0';
                  WHEN OTHERS =>
                     RX_SGMII_Idle <= '1';
                     User_RX_DV_INT <= '0';
                     User_RX_ERR_INT <= '0';
                     User_RX_Data_INT <= (OTHERS => '0');
                     SGMII_Link_Speed_Counter_EN <= '0';
               END CASE;
            END IF;
         ELSIF (RX_SGMII_Idle = '1') THEN
            User_RX_DV_INT <= '0';
            User_RX_ERR_INT <= '0';
            User_RX_Data_INT <= (OTHERS => '0');
            SGMII_Link_Speed_Counter_EN <= '0';
         ELSE -- There is nothing special to do with the received data, we can just use them.
            User_RX_DV_INT <= User_RX_DV_INT;
            User_RX_ERR_INT <= User_RX_ERR_INT;
            User_RX_Data_INT <= GX_RX_Stored_Data(15 DOWNTO 8);
            SGMII_Link_Speed_Counter_EN <= SGMII_Link_Speed_Counter_EN;
         END IF;
      END IF;
   END PROCESS RX_GMII_GEN;


   -- Concurrent 3
   User_RX_DV <= User_RX_DV_INT;
   User_RX_ERR <= User_RX_ERR_INT;
   User_RX_Data <= User_RX_Data_INT;


END ARCHITECTURE Universal;