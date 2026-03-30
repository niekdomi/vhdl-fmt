-- MODULE GX GE Carrier Detection
-- VHDL Architecture Indel_lib.GX_Carrier_Detection.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- 
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland
--
--
-- --------------------------------------------------------------------------------------------
-- This code is a working variant of the not working Altera example "carrier_detect_logicVHDL".
-- --------------------------------------------------------------------------------------------  
-- It works together with the new GX transmitter "GE extended" mode only!
-- See application note AN537.
--
--------------------------------------------------------------------------------
--$Rev:: 2287                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2012-05-31 17:09:09 +0200 (Do., 31 Mai 2012)                         $
--------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

ENTITY GX_Carrier_Detection IS
   PORT   (
           GCLK:                      IN   std_logic; -- Connect to "tx_clkout" of ALT2GXB.
           CLR_n:                     IN   std_logic; -- Connect to "rx_digitalreset" of ALT2GXB.
           alt_dataout:               IN   std_logic_vector(7 DOWNTO 0); -- Connect to "rx_dataout" of ALT2GXB.
           alt_sync:                  IN   std_logic; -- Connect to "rx_syncstatus" of ALT2GXB.
           alt_disperr:               IN   std_logic; -- Connect to "rx_disperr" of ALT2GXB.
           alt_ctrldetect:            IN   std_logic; -- Connect to "rx_ctrldetect" of ALT2GXB.
           alt_errdetect:             IN   std_logic; -- Connect to "rx_errdetect" of ALT2GXB.
           alt_rmfifodatadeleted:     IN   std_logic; -- Connect to "rx_rmfifodatadeleted" of ALT2GXB.
           alt_rmfifodatainserted:    IN   std_logic; -- Connect to "rx_rmfifodatainserted" of ALT2GXB.
           alt_runlengthviolation:    IN   std_logic; -- Connect to "rx_rlv" of ALT2GXB.
           alt_patterndetect:         IN   std_logic; -- Connect to "rx_patterndetect" of ALT2GXB.
           alt_runningdisp:           IN   std_logic; -- Connect to "rx_runningdisp" of ALT2GXB.

           altpcs_dataout:            OUT  std_logic_vector(7 DOWNTO 0);
           altpcs_sync:               OUT  std_logic;
           altpcs_disperr:            OUT  std_logic;
           altpcs_ctrldetect:         OUT  std_logic;
           altpcs_errdetect:          OUT  std_logic;
           altpcs_rmfifodatadeleted:  OUT  std_logic;
           altpcs_rmfifodatainserted: OUT  std_logic;
           altpcs_carrierdetect:      OUT  std_logic
           );
END GX_Carrier_Detection;
-- -------------------------------------------------------------------------------

ARCHITECTURE Universal OF GX_Carrier_Detection IS

-- reg altpcs_dataout
-- pipelined 1
   SIGNAL alt_dataout_reg1                     : std_logic_vector(7 DOWNTO 0);
   SIGNAL alt_sync_reg1                        : std_logic;
   SIGNAL alt_disperr_reg1                     : std_logic;
   SIGNAL alt_ctrldetect_reg1                  : std_logic;
   SIGNAL alt_errdetect_reg1                   : std_logic;
   SIGNAL alt_rmfifodatadeleted_reg1           : std_logic;
   SIGNAL alt_rmfifodatainserted_reg1          : std_logic;
   SIGNAL alt_patterndetect_reg1               : std_logic;
   SIGNAL alt_runningdisp_reg1                 : std_logic;
   SIGNAL alt_runlengthviolation_latched       : std_logic;
   SIGNAL altpcs_carrierdetect_temp            : std_logic;
-- -------------------------------------------------------------------------------

BEGIN

Register_GX_Signals: PROCESS(GCLK, CLR_n)
BEGIN
   IF (CLR_n = '0') THEN 
      -- pipelined 1
      alt_dataout_reg1            <= "00000000";
      alt_sync_reg1               <= '0';
      alt_disperr_reg1            <= '0';
      alt_ctrldetect_reg1         <= '0';
      alt_errdetect_reg1          <= '0';
      alt_rmfifodatadeleted_reg1  <= '0';
      alt_rmfifodatainserted_reg1 <= '0';
      alt_patterndetect_reg1      <= '0';
      alt_runningdisp_reg1        <= '0';
      altpcs_dataout              <= "00000000";
      altpcs_disperr              <= '0';
      altpcs_ctrldetect           <= '0';
      altpcs_errdetect            <= '0';
      altpcs_rmfifodatadeleted    <= '0';
      altpcs_rmfifodatainserted   <= '0';
   ELSIF (GCLK'EVENT AND GCLK = '1') THEN
      -- pipelined 1
      alt_dataout_reg1            <= alt_dataout;
      alt_sync_reg1               <= alt_sync;
      alt_disperr_reg1            <= alt_disperr;
      alt_ctrldetect_reg1         <= alt_ctrldetect;
      alt_errdetect_reg1          <= alt_errdetect;
      alt_rmfifodatadeleted_reg1  <= alt_rmfifodatadeleted;
      alt_rmfifodatainserted_reg1 <= alt_rmfifodatainserted;
      alt_patterndetect_reg1      <= alt_patterndetect;
      alt_runningdisp_reg1        <= alt_runningdisp;
      altpcs_dataout              <= alt_dataout_reg1;
      altpcs_disperr              <= alt_disperr_reg1;
      altpcs_ctrldetect           <= alt_ctrldetect_reg1;
      altpcs_errdetect            <= alt_errdetect_reg1;
      altpcs_rmfifodatadeleted    <= alt_rmfifodatadeleted_reg1;
      altpcs_rmfifodatainserted   <= alt_rmfifodatainserted_reg1;
   END IF;
END PROCESS Register_GX_Signals;


-- Concurrent 1
altpcs_sync <= '0';

   
Plausiblity_Check: PROCESS(GCLK, CLR_n)
BEGIN
   IF (CLR_n = '0') THEN
      alt_runlengthviolation_latched <= '0';
   ELSIF (GCLK'EVENT AND GCLK ='1') THEN
      IF ((altpcs_carrierdetect_temp = '0') OR (alt_sync = '0')) THEN
         alt_runlengthviolation_latched <= '0';
      ELSIF ((alt_runlengthviolation = '1') AND (alt_sync = '1')) THEN
         alt_runlengthviolation_latched <= '1';
      END IF;
   END IF;
END PROCESS Plausiblity_Check;


-- carrier_detect signal generation
Carrier_Signal_Generation: PROCESS(GCLK, CLR_n)
BEGIN
   IF (CLR_n = '0') THEN
      altpcs_carrierdetect_temp <= '1';
   ELSIF (GCLK'EVENT AND GCLK = '1') THEN
      IF ((alt_sync_reg1 = '1' AND alt_dataout_reg1 = "00011100" AND alt_ctrldetect_reg1 = '1' AND alt_errdetect_reg1 = '1'  
            AND alt_disperr_reg1 = '1' AND alt_patterndetect_reg1 = '1' AND alt_runlengthviolation_latched = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "11111100" AND alt_ctrldetect_reg1 = '1' AND alt_patterndetect_reg1 = '1' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10011100" AND alt_ctrldetect_reg1 = '1' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10111100" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10101100" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10110100" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10100111" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' AND alt_runningdisp_reg1 = '1' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10100001" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0'
            AND alt_runningdisp_reg1 = '1' AND alt_runlengthviolation_latched = '1' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "10100010" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0'
            AND alt_runningdisp_reg1 = '1'  
            AND ((alt_runningdisp = '1' AND alt_errdetect_reg1 = '1' AND alt_disperr_reg1 = '1') OR                                                                                
            (alt_runningdisp = '0' AND alt_errdetect_reg1 = '1' AND alt_disperr_reg1 = '0' ))  ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 ="01000011" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "01010011" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "01001011" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "01000111" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0' AND alt_runningdisp_reg1 = '0' ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "01000001" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0'
            AND alt_runningdisp_reg1 = '0' AND alt_runlengthviolation_latched = '1' 
            AND ((alt_runningdisp = '1' AND alt_errdetect_reg1 = '1' AND alt_disperr_reg1 = '0') OR                                                                                
            (alt_runningdisp = '0' AND alt_errdetect_reg1 = '1' AND alt_disperr_reg1 = '1' )) ) OR
            (alt_sync_reg1 = '1' AND alt_dataout_reg1 = "01000010" AND alt_ctrldetect_reg1 = '0' AND alt_patterndetect_reg1 = '0'
            AND alt_runningdisp_reg1 = '0' AND ((alt_runningdisp = '1' AND alt_errdetect_reg1 = '1' AND alt_disperr_reg1 = '0') OR
            (alt_runningdisp = '0' AND alt_errdetect_reg1 = '1' AND alt_disperr_reg1 = '1')))) THEN
         altpcs_carrierdetect_temp <= '0';
      ELSE
         altpcs_carrierdetect_temp <=  '1';
      END IF;
   END IF;
END PROCESS Carrier_Signal_Generation;

-- Concurrent 2
altpcs_carrierdetect <= altpcs_carrierdetect_temp;

END ARCHITECTURE Universal;

