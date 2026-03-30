-- MODULE SGMII Control
-- VHDL Architecture Indel_lib.SGMII_Control.Universal
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

--                                                                            --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- This SGMII entity should deliver the data GMII conform. That means a       --
--  Carrier Extend is delivered as 0x0F with GMII_RX_ERR = '1' and            --
-- GMII_RX_DV = '0'. This way round it should be possible to examine the link --
-- speed without MDIO accesses.                                               --
--                                                                            --
-- Changed the clocking topology.                                             --
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
USE ieee.std_logic_unsigned.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.INFO_SAM3_Package_Take2.all;
-------------------------------
-- Entity library inclusion END
-------------------------------

ENTITY SGMII_Control IS
  PORT    (
           GCLK                    : IN   std_logic;
           GXCLK                   : IN   std_logic;
           FPGA_CLK                : IN   std_logic;
           CLR_n                   : IN   std_logic;
           -- User Interface
           GMII_TX_EN              : IN   std_logic;
           GMII_TX_ERR             : IN   std_logic;
           GMII_TXD                : IN   std_logic_vector(7 DOWNTO 0);
           GMII_RX_DV              : OUT  std_logic;
           GMII_RX_ERR             : OUT  std_logic;
           GMII_RXD                : OUT  std_logic_vector(7 DOWNTO 0);
           -- User Information
           PHY_Link_Status         : OUT  std_logic_vector(15 DOWNTO 0);
           GMII_RX_Data_Valid_EN   : OUT  std_logic;
           GMII_TX_CLK_EN          : OUT  std_logic;
           
           -- SGMII
           GX_RX                   : IN   std_logic;
           GX_TX                   : OUT  std_logic
           );
END ENTITY SGMII_Control;


ARCHITECTURE Universal OF SGMII_Control IS

   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL CLR                   : std_logic;
   SIGNAL GCLK_v                : std_logic_vector(0 DOWNTO 0);
   SIGNAL GX_RX_v               : std_logic_vector(0 DOWNTO 0);
   SIGNAL GX_TX_v               : std_logic_vector(0 DOWNTO 0);
   SIGNAL tx_clkout             : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_dataout            : std_logic_vector(7 DOWNTO 0);
   SIGNAL rx_syncstatus         : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_disperr            : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_ctrldetect         : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_errdetect          : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_rmfifodatadeleted  : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_rmfifodatainserted : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_rlv                : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_patterndetect      : std_logic_vector(0 DOWNTO 0);
   SIGNAL rx_runningdisp        : std_logic_vector(0 DOWNTO 0);
   SIGNAL RX_Pattern            : std_logic;
   SIGNAL TX_Pattern            : std_logic_vector(0 DOWNTO 0);
   SIGNAL GMII_RXD_INT          : std_logic_vector(7 DOWNTO 0);
   ------------
   ------------
   SIGNAL RX_Pattern_Detect     : std_logic_vector(0 DOWNTO 0);
   ------------
   ------------
   SIGNAL GX_PLL_Locked_INT     : std_logic_vector(0 DOWNTO 0);    
   ------------
   ------------
   
   -------------------------
   -- Signal Declaration END
   -------------------------


   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT GX_Transceiver
      PORT   (
              cal_blk_clk                  : IN  std_logic;
              gxb_powerdown                : IN  std_logic_vector(0 DOWNTO 0);
              pll_inclk                    : IN  std_logic;
              rx_analogreset               : IN  std_logic_vector(0 DOWNTO 0);
              rx_cruclk                    : IN  std_logic_vector(0 DOWNTO 0) :=  (OTHERS => '0');
              rx_datain                    : IN  std_logic_vector(0 DOWNTO 0);
              rx_digitalreset              : IN  std_logic_vector(0 DOWNTO 0);
              tx_ctrlenable                : IN  std_logic_vector(0 DOWNTO 0);
              tx_datain                    : IN  std_logic_vector(7 DOWNTO 0);
              tx_digitalreset              : IN  std_logic_vector(0 DOWNTO 0);
              pll_locked                   : OUT std_logic_vector(0 DOWNTO 0);
              rx_ctrldetect                : OUT std_logic_vector(0 DOWNTO 0);
              rx_dataout                   : OUT std_logic_vector(7 DOWNTO 0);
              rx_disperr                   : OUT std_logic_vector(0 DOWNTO 0);
              rx_errdetect                 : OUT std_logic_vector(0 DOWNTO 0);
              rx_patterndetect             : OUT std_logic_vector(0 DOWNTO 0);
              rx_rlv                       : OUT std_logic_vector(0 DOWNTO 0);
              rx_syncstatus                : OUT std_logic_vector(0 DOWNTO 0);
              tx_clkout                    : OUT std_logic_vector(0 DOWNTO 0);
              tx_dataout                   : OUT std_logic_vector(0 DOWNTO 0)
              );
   END COMPONENT GX_Transceiver;
   
   
   COMPONENT SGMII_Autonegotiation
      PORT   (
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
   END COMPONENT SGMII_Autonegotiation;


--   -- This is a GX transceiver in basic extended mode for UNH-IOL conformance.
--   COMPONENT SGMII_GX_Transceiver
--      PORT   (
--              cal_blk_clk               : IN   std_logic;
--              gxb_powerdown             : IN   std_logic_vector(0 DOWNTO 0);
--              pll_inclk                 : IN   std_logic;
--              rx_analogreset            : IN   std_logic_vector(0 DOWNTO 0);
--              rx_cruclk                 : IN   std_logic_vector(0 DOWNTO 0):=  (OTHERS => '0');
--              rx_datain                 : IN   std_logic_vector(0 DOWNTO 0);
--              rx_digitalreset           : IN   std_logic_vector(0 DOWNTO 0);
--              tx_ctrlenable             : IN   std_logic_vector(0 DOWNTO 0);
--              tx_datain                 : IN   std_logic_vector(7 DOWNTO 0);
--              tx_digitalreset           : IN   std_logic_vector(0 DOWNTO 0);
--              rx_ctrldetect             : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_dataout                : OUT  std_logic_vector(7 DOWNTO 0);
--              rx_disperr                : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_errdetect              : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_patterndetect          : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_rlv                    : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_rmfifodatadeleted      : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_rmfifodatainserted     : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_runningdisp            : OUT  std_logic_vector(0 DOWNTO 0);
--              rx_syncstatus             : OUT  std_logic_vector(0 DOWNTO 0);
--              tx_clkout                 : OUT  std_logic_vector(0 DOWNTO 0);
--              tx_dataout                : OUT  std_logic_vector(0 DOWNTO 0)
--              );
--   END COMPONENT SGMII_GX_Transceiver;


--   -- This is special carrier detect logic for UNH-IOL conformance.
--   COMPONENT GX_Carrier_Detection
--      PORT   (
--              GCLK                      : IN   std_logic; -- Connect to "tx_clkout" of ALT2GXB.
--              CLR_n                     : IN   std_logic; -- Connect to "rx_digitalreset" of ALT2GXB.
--              alt_dataout               : IN   std_logic_vector(7 DOWNTO 0); -- Connect to "rx_dataout" of ALT2GXB.
--              alt_sync                  : IN   std_logic; -- Connect to "rx_syncstatus" of ALT2GXB.
--              alt_disperr               : IN   std_logic; -- Connect to "rx_disperr" of ALT2GXB.
--              alt_ctrldetect            : IN   std_logic; -- Connect to "rx_ctrldetect" of ALT2GXB.
--              alt_errdetect             : IN   std_logic; -- Connect to "rx_errdetect" of ALT2GXB.
--              alt_rmfifodatadeleted     : IN   std_logic; -- Connect to "rx_rmfifodatadeleted" of ALT2GXB.
--              alt_rmfifodatainserted    : IN   std_logic; -- Connect to "rx_rmfifodatainserted" of ALT2GXB.
--              alt_runlengthviolation    : IN   std_logic; -- Connect to "rx_rlv" of ALT2GXB.
--              alt_patterndetect         : IN   std_logic; -- Connect to "rx_patterndetect" of ALT2GXB.
--              alt_runningdisp           : IN   std_logic; -- Connect to "rx_runningdisp" of ALT2GXB.
--
--              altpcs_dataout            : OUT  std_logic_vector(7 DOWNTO 0);
--              altpcs_sync               : OUT  std_logic;
--              altpcs_disperr            : OUT  std_logic;
--              altpcs_ctrldetect         : OUT  std_logic;
--              altpcs_errdetect          : OUT  std_logic;
--              altpcs_rmfifodatadeleted  : OUT  std_logic;
--              altpcs_rmfifodatainserted : OUT  std_logic;
--              altpcs_carrierdetect      : OUT  std_logic
--              );
--   END COMPONENT GX_Carrier_Detection;


   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : GX_Transceiver USE ENTITY Indel_lib.GX_Transceiver;
   FOR ALL : SGMII_Autonegotiation USE ENTITY Indel_lib.SGMII_Autonegotiation;
   FOR ALL : SGMII_GX_Transceiver USE ENTITY Indel_lib.SGMII_GX_Transceiver;
   FOR ALL : GX_Carrier_Detection USE ENTITY Indel_lib.GX_Carrier_Detection;

    -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------


BEGIN



   -- Concurrent 0: Assignemnts, based on the fact that the signals are vectors at the GX entity.
   GCLK_v(0) <= FPGA_CLK;
   -- GCLK_v(0) <= GCLK;-- Used for the "old" clocking.
   GX_RX_v(0) <= GX_RX;
   GX_TX <= GX_TX_v(0);

   -- Concurrent 1
   CLR <= NOT(CLR_n);

   Sync_CLK_Domain: IF (1 = 1) GENERATE
      SIGNAL GX_PLL_Locked_F        : std_logic;
      SIGNAL RX_Syncstatus_F        : std_logic;
      SIGNAL RX_Pattern_Detect_F    : std_logic;
      SIGNAL RX_Ctrldetect_F        : std_logic;
      SIGNAL GMII_RXD_INT_F         : std_logic_vector(7 DOWNTO 0);
      SIGNAL GX_TX_CTRL_EN_INT_GCLK : std_logic;
      SIGNAL GX_TX_Data_INT_GCLK    : std_logic_vector(7 DOWNTO 0);
      SIGNAL GX_TX_CTRL_EN_INT_TXCLK: std_logic_vector(0 DOWNTO 0);
      SIGNAL GX_TX_Data_INT_TXCLK   : std_logic_vector(7 DOWNTO 0);
      SIGNAL GX_TX_CTRL_EN_INT_F    : std_logic;
      SIGNAL GX_TX_Data_INT_F       : std_logic_Vector(7 DOWNTO 0);
      SIGNAL TX_CLK_OUT_v           : std_logic_vector(0 DOWNTO 0);
   BEGIN

      Destination_FPGA_CLK: PROCESS(FPGA_CLK, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            GX_PLL_Locked_F <= '0';
            RX_Syncstatus_F <= '0';
            RX_Pattern_Detect_F <= '0';
            RX_Ctrldetect_F <= '0';
            GMII_RXD_INT_F <= (OTHERS => '0');
         ELSIF (FPGA_CLK'EVENT AND FPGA_CLK = '1') THEN
            GX_PLL_Locked_F <= GX_PLL_Locked_INT(0);
            RX_Syncstatus_F <= rx_syncstatus(0);
            RX_Pattern_Detect_F <= RX_Pattern_Detect(0);
            RX_Ctrldetect_F <= rx_ctrldetect(0);
            GMII_RXD_INT_F <= GMII_RXD_INT;
         END IF;
      END PROCESS Destination_FPGA_CLK;
      
      
      Destination_GCLK: PROCESS(TX_CLK_OUT_v, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            GX_TX_CTRL_EN_INT_TXCLK(0) <= '0';
            GX_TX_Data_INT_TXCLK <= (OTHERS => '0');
         ELSIF (TX_CLK_OUT_v(0)'EVENT AND TX_CLK_OUT_v(0) = '1') THEN
            GX_TX_CTRL_EN_INT_TXCLK(0) <= GX_TX_CTRL_EN_INT_F;
            GX_TX_Data_INT_TXCLK <= GX_TX_Data_INT_F;
         END IF;
      END PROCESS Destination_GCLK;


   SGMII_Autonegotiator: SGMII_Autonegotiation
      PORT MAP (
                GCLK                         => FPGA_CLK,
                CLR_n                        => CLR_n,
                -- FPGA User Data for SGMII transmission
                User_TX_EN                   => GMII_TX_EN,
                User_TX_ER                   => GMII_TX_ERR,
                User_TX_Data                 => GMII_TXD,
                User_RX_DV                   => GMII_RX_DV,
                User_RX_ERR                  => GMII_RX_ERR,
                User_RX_Data                 => GMII_RXD,
                -- RX data from the GX receiver for autonegotiation functions
                GX_PLL_Locked                => GX_PLL_Locked_F,--GX_PLL_Locked_INT(0),
                GX_RX_SYNC_Status            => RX_Syncstatus_F,--rx_syncstatus(0), -- '1' = in sync
                GX_RX_Pattern_Detect         => RX_Pattern_Detect_F,--RX_Pattern_Detect(0),
                GX_RX_Control_Detect         => RX_Ctrldetect_F,--rx_ctrldetect(0),
                GX_RX_Data                   => GMII_RXD_INT_F,--GMII_RXD_INT,
                -- TX data to the GX transmitter
                GX_TX_CTRL_EN                => GX_TX_CTRL_EN_INT_F,
                GX_TX_ER                     => OPEN,
                GX_TX_Data                   => GX_TX_Data_INT_F,
                -- SGMII Status register
                SGMII_Link_Status            => PHY_Link_Status, -- The 16 Bit SGMII PHY register
                SGMII_RX_Data_Valid_EN       => GMII_RX_Data_Valid_EN,
                SGMII_TX_CLK_EN              => GMII_TX_CLK_EN      
                );
   
   
      SGMII_GX: GX_Transceiver
      PORT MAP (
                cal_blk_clk                  => GCLK,
                gxb_powerdown                => "0",-- Enabled CLR?
                pll_inclk                    => GXCLK,
                rx_analogreset               => "0",-- CLR?
                rx_cruclk                    => GCLK_v,
                rx_datain                    => GX_RX_v,
                rx_digitalreset              => "0",
                tx_ctrlenable                => GX_TX_CTRL_EN_INT_TXCLK,
                tx_datain                    => GX_TX_Data_INT_TXCLK,
                tx_digitalreset              => "0",
                pll_locked                   => GX_PLL_Locked_INT,
                rx_ctrldetect                => rx_ctrldetect,
                rx_dataout                   => GMII_RXD_Int,
                rx_disperr                   => OPEN,
                rx_errdetect                 => rx_errdetect,
                rx_patterndetect             => RX_Pattern_Detect,
                rx_rlv                       => OPEN,
                rx_syncstatus                => rx_syncstatus,
                tx_clkout                    => TX_CLK_OUT_v,
                tx_dataout                   => GX_TX_v
                );

   END GENERATE Sync_CLK_Domain;
   
   
   
   Sync_CLK_Domain_Old: IF (1 = 0) GENERATE
      SIGNAL GX_PLL_Locked_INT     : std_logic_vector(0 DOWNTO 0);
      SIGNAL GX_TX_CTRL_EN_INT     : std_logic_vector(0 DOWNTO 0);
      SIGNAL GMII_TX_INT           : std_logic_vector(7 DOWNTO 0);
      SIGNAL rx_syncstatus_SYN     : std_logic_vector(0 DOWNTO 0);
      SIGNAL rx_ctrldetect_SYN     : std_logic_vector(0 DOWNTO 0);
      SIGNAL RX_Pattern_Detect_SYN : std_logic_vector(0 DOWNTO 0);
      SIGNAL GMII_RXD_INT_SYN      : std_logic_vector(7 DOWNTO 0);
      SIGNAL GX_PLL_Locked_INT_SYN : std_logic_vector(0 DOWNTO 0);
      SIGNAL GX_TX_CTRL_EN_INT_SYN : std_logic_vector(0 DOWNTO 0);
      SIGNAL GMII_TX_INT_SYN       : std_logic_vector(7 DOWNTO 0);
      SIGNAL GX_TX_CLK             : std_logic_vector(0 DOWNTO 0);
   BEGIN

      SGMII_Autonegotiator: SGMII_Autonegotiation
      PORT MAP (
                GCLK                         => GCLK,
                CLR_n                        => CLR_n,
                -- FPGA User Data for SGMII transmission
                User_TX_EN                   => GMII_TX_EN,
                User_TX_ER                   => GMII_TX_ERR,
                User_TX_Data                 => GMII_TXD,
                User_RX_DV                   => GMII_RX_DV,
                User_RX_ERR                  => GMII_RX_ERR,
                User_RX_Data                 => GMII_RXD,
                -- RX data from the GX receiver for autonegotiation functions
                GX_PLL_Locked                => GX_PLL_Locked_INT_SYN(0),
                GX_RX_SYNC_Status            => rx_syncstatus_SYN(0), -- '1' = in sync
                GX_RX_Pattern_Detect         => RX_Pattern_Detect_SYN(0),
                GX_RX_Control_Detect         => rx_ctrldetect_SYN(0),
                GX_RX_Data                   => GMII_RXD_INT_SYN,
                -- TX data to the GX transmitter
                GX_TX_CTRL_EN                => GX_TX_CTRL_EN_INT(0),
                GX_TX_ER                     => OPEN,
                GX_TX_Data                   => GMII_TX_INT,
                -- SGMII Status register
                SGMII_Link_Status            => PHY_Link_Status, -- The 16 Bit SGMII PHY register
                SGMII_RX_Data_Valid_EN       => GMII_RX_Data_Valid_EN,
                SGMII_TX_CLK_EN              => GMII_TX_CLK_EN
                );
   
   
      SGMII_GX: GX_Transceiver
      PORT MAP (
                cal_blk_clk                  => GCLK,
                gxb_powerdown                => "0",-- Enabled CLR?
                pll_inclk                    => GXCLK,
                rx_analogreset               => "0",-- CLR?
                rx_cruclk                    => GCLK_v,
                --FPGA_CLK                     => FPGA_CLK_v,
                rx_datain                    => GX_RX_v,
                rx_digitalreset              => "0",
                tx_ctrlenable                => GX_TX_CTRL_EN_INT_SYN,
                tx_datain                    => GMII_TX_INT_SYN,
                tx_digitalreset              => "0",
                pll_locked                   => GX_PLL_Locked_INT,
                rx_ctrldetect                => rx_ctrldetect,
                rx_dataout                   => GMII_RXD_Int,
                rx_disperr                   => OPEN,
                rx_errdetect                 => rx_errdetect,
                rx_patterndetect             => RX_Pattern_Detect,
                rx_rlv                       => OPEN,
                rx_syncstatus                => rx_syncstatus,
                tx_clkout                    => GX_TX_CLK,
                tx_dataout                   => GX_TX_v
                );
                
                
   -- We use this register to enhance the speed during fitting.
   -- Otherwise we should disable the automatic GX clock assignments and use the rx_coreclk and tx_coreclock instead.
   -- But as long as we realize the fubctionality wihout this work we should try it the other way round. A further approach would be to disable
   -- the autonegotiation feature and to introduce a 100Mbit SGMII EtherCAT mode (this should significantly enhance the timing).
   Synchronize_GX_Data: PROCESS(GX_TX_CLK)
   BEGIN
      IF (CLR_n = '0') THEN
         GMII_TX_INT_SYN <= (OTHERS => '0');
         GX_TX_CTRL_EN_INT_SYN(0) <= '0';
         GMII_RXD_INT_SYN <= (OTHERS => '0');
         rx_ctrldetect_SYN(0) <= '0';
         RX_Pattern_Detect_SYN(0) <= '0';
         rx_syncstatus_SYN(0) <= '0';
         GX_PLL_Locked_INT_SYN(0) <= '0';
      ELSIF (GX_TX_CLK(0)'EVENT AND GX_TX_CLK(0) = '1') THEN
         GMII_TX_INT_SYN <= GMII_TX_INT;
         GX_TX_CTRL_EN_INT_SYN <= GX_TX_CTRL_EN_INT;
         GMII_RXD_INT_SYN <= GMII_RXD_INT;
         rx_ctrldetect_SYN <= rx_ctrldetect;
         RX_Pattern_Detect_SYN <= RX_Pattern_Detect;
         rx_syncstatus_SYN <= rx_syncstatus;
         GX_PLL_Locked_INT_SYN <= GX_PLL_Locked_INT;
      END IF;
   END PROCESS Synchronize_GX_Data;
   
   
   END GENERATE Sync_CLK_Domain_Old;
   
   
   -- We have to acquire the SGMII data via GX transceiver in extended mode.
   -- Important: this setting is using a transceiver in basic mode and needs additional logic for the carrier detection
--   GX_Transceiver: SGMII_GX_Transceiver
--      PORT MAP (
--                cal_blk_clk               => GCLK,
--                gxb_powerdown             => "0", -- enabled
--                pll_inclk                 => GXCLK,
--                rx_analogreset            => "0", -- normal operation
--                rx_cruclk                 => GCLK_v,
--                rx_datain                 => GX_RX_v, -- serial receive data
--                rx_digitalreset           => "0",--GX_Digital_Reset, -- normally '0',
--                tx_ctrlenable             => TX_Pattern,
--                tx_datain                 => GMII_RXD_Int, --GMII_TXD,
--                tx_digitalreset           => "0",--GX_Digital_Reset,
--                rx_ctrldetect             => rx_ctrldetect,
--                rx_dataout                => rx_dataout,
--                rx_disperr                => rx_disperr,
--                rx_errdetect              => rx_errdetect,
--                rx_patterndetect          => rx_patterndetect,
--                rx_rlv                    => rx_rlv,
--                rx_rmfifodatadeleted      => rx_rmfifodatadeleted,
--                rx_rmfifodatainserted     => rx_rmfifodatainserted,
--                rx_runningdisp            => rx_runningdisp,
--                rx_syncstatus             => rx_syncstatus,
--                tx_clkout                 => tx_clkout,
--                tx_dataout                => GX_TX_v
--                );
--
--
--   Carrier_Logic: GX_Carrier_Detection
--      PORT MAP (
--                GCLK                      => tx_clkout(0), -- Connect to "tx_clkout" of ALT2GXB.
--                CLR_n                     => CLR_n, -- Connect to "rx_digitalreset" of ALT2GXB.
--                alt_dataout               => rx_dataout, -- Connect to "rx_dataout" of ALT2GXB.
--                alt_sync                  => rx_syncstatus(0), -- Connect to "rx_syncstatus" of ALT2GXB.
--                alt_disperr               => rx_disperr(0), -- Connect to "rx_disperr" of ALT2GXB.
--                alt_ctrldetect            => rx_ctrldetect(0), -- Connect to "rx_ctrldetect" of ALT2GXB.
--                alt_errdetect             => rx_errdetect(0), -- Connect to "rx_errdetect" of ALT2GXB.
--                alt_rmfifodatadeleted     => rx_rmfifodatadeleted(0), -- Connect to "rx_rmfifodatadeleted" of ALT2GXB.
--                alt_rmfifodatainserted    => rx_rmfifodatainserted(0), -- Connect to "rx_rmfifodatainserted" of ALT2GXB.
--                alt_runlengthviolation    => rx_rlv(0), -- Connect to "rx_rlv" of ALT2GXB.
--                alt_patterndetect         => rx_patterndetect(0), -- Connect to "rx_patterndetect" of ALT2GXB.
--                alt_runningdisp           => rx_runningdisp(0), -- Connect to "rx_runningdisp" of ALT2GXB.
--
--                altpcs_dataout            => GMII_RXD_Int,
--                altpcs_sync               => OPEN,
--                altpcs_disperr            => OPEN,
--                altpcs_ctrldetect         => RX_Pattern,
--                altpcs_errdetect          => GMII_RX_ERR,
--                altpcs_rmfifodatadeleted  => OPEN,
--                altpcs_rmfifodatainserted => OPEN,
--                altpcs_carrierdetect      => OPEN
--                );




END ARCHITECTURE Universal;