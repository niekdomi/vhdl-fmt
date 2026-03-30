-- Module ASMI Atom
-- VHDL Architecture Indel_lib.ASMI_Atom.Universal
--
--
-- Project:       General, Base Functionality
-- Technology:    Altera Tornado, Magellan, Cuda
-- Actual version first used in: INFO-PCIe
-- 
-- Indel AG, qfu
--
-- Last changes:
-- 16.10.07
--
--
--
--
--
-- With this entity the functionality of the Arria GX, Cyclone I & II & III, Stratix II & III ASMI hardware block can be instantiated.
-- 
--
-- History:
-- IB-Code: IG34, 02.08.2004
--    1.) Initial version based on information from louis.surtees@ebv.com, who delivered the name of
--        the spiblock (tornado for Cyclone I).
-- IB-Code: IG40, 15.03.2007, (PCIe)
--    1.) Changes to reflect the official release of the Altera Serial Flash Loader (SFL)
--    2.) Generic to activate the bridge functionality from JTAG to SPI.
--    3.) Spiblock name changed to the "new" name "CYCLONE_spiblock".
-- IB-Code: INFO-SAM3, 16.10.2007
--    1.) Changes for additional Altera FPGA families.
-- IB-Code: SAM4, 10.04.2015
--    1.) Changes for the Cyclone V device.
--    2.) Added QSPI functionality, for the SPIBLOCK.
--    3.) The Altserial_Flash_loader was replaced by Altera with the Altera_serial_flash_loader entity.
--
--
-- Remarks:
--    1.) Simulation functionality does not reflect reality.
--    2.) Library "Flash_Memory" is used to simulate the ST Flash MP25P40. The code for the simulation can be downloaded at www.st.com.
--
--

--------------------------------------------------------------------------------
--$Rev:: 3910                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-03-10 09:41:57 +0100 (Do., 10 MÃ¤r 2016)                        $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

--LIBRARY arriagx;
--USE arriagx.all;


-- PRAGMA TRANSLATE_OFF
-- -- For simulation only.
--LIBRARY Flash_Memory;
-- PRAGMA TRANSLATE_ON



-------------------------------------------------
-------------------------------------------------
ENTITY ASMI_Atom IS
   GENERIC (
            ASMI_JTAG_Bridge_EN     : IN   natural:= 0; -- Do we need the bridge functionality?
            ASMI_QSPI_Support_EN    : IN   natural:= 0; -- Do we have device connected that supports QSPI access?
            ASMI_Access_EN          : IN   natural:= 1; -- Is ASMI access from the user logic needed?
            FPGA_Family             : IN   natural RANGE 0 TO 15:= 8 -- Default: Arria GX 
            );
   PORT    (
            ASMI_ASDO               : IN   std_logic:= '0';
            ASMI_Access_Granted     : IN   std_logic:= '1';
            ASMI_DCLK               : IN   std_logic:= '0';
            ASMI_CS_n               : IN   std_logic:= '1';
            ASMI_OE_n               : IN   std_logic:= '1';
            ASMI_Data0              : OUT  std_logic;
            ASMI_Access_Request     : OUT  std_logic;
            -- QSPI signals
            ASMI_QASD               : IN   std_logic_vector(3 DOWNTO 0):= (OTHERS => '0');
            ASMI_QOE_n              : IN   std_logic_vector(3 DOWNTO 0):= (OTHERS => '1');
            ASMI_QData              : OUT  std_logic_vector(3 DOWNTO 0)
            );
END ENTITY ASMI_Atom;
-------------------------------------------------
-------------------------------------------------


ARCHITECTURE Universal OF ASMI_Atom IS

   -- Concurrent function
   FUNCTION To_String (Nat_In: natural) RETURN string IS
   BEGIN
      IF (Nat_In = 1) THEN
         RETURN "ON";
      ELSE
         RETURN "OFF";
      END IF;
   END FUNCTION To_String;
   -- Concurrent function END
   

   CONSTANT Share_Access     : string:= To_String(ASMI_Access_EN);

   SIGNAL Data0_Int          : std_logic;
   SIGNAL Access_Request_Int : std_logic;


   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT Altserial_Flash_Loader
      GENERIC   (
                 enable_shared_access   : string;
                 lpm_type               : string
                 );
      PORT     (
                scein                  : IN  std_logic;
                dclkin                 : IN  std_logic;
                data0out               : OUT std_logic;
                sdoin                  : IN  std_logic;
                asmi_access_granted    : IN  std_logic;
                asmi_access_request    : OUT std_logic;
                noe                    : IN  std_logic 
                );
   END COMPONENT;


   COMPONENT Altera_serial_flash_loader
      GENERIC  (
                INTENDED_DEVICE_FAMILY  : string  := "";
                ENHANCED_MODE           : boolean := true;
                ENABLE_SHARED_ACCESS    : string  := "OFF";
                ENABLE_QUAD_SPI_SUPPORT : boolean := false;
                NCSO_WIDTH              : integer := 1
                );
      PORT    (
               dclk_in                  : IN  std_logic                    := 'X';             -- dclkin
               ncso_in                  : IN  std_logic                    := 'X';             -- scein
               data_in                  : IN  std_logic_vector(3 DOWNTO 0) := (OTHERS => 'X'); -- data_in
               data_oe                  : IN  std_logic_vector(3 DOWNTO 0) := (OTHERS => 'X'); -- data_oe
               noe_in                   : IN  std_logic                    := 'X';             -- noe
               asmi_access_granted      : IN  std_logic                    := 'X';             -- asmi_access_granted
               data_out                 : OUT std_logic_vector(3 DOWNTO 0);                    -- data_out
               asmi_access_request      : OUT std_logic                                        -- asmi_access_request
               );
   END COMPONENT Altera_serial_flash_loader;


   COMPONENT CYCLONE_SPIBLOCK
      PORT      (
                 oe       : IN  std_logic;
                 scein    : IN  std_logic;
                 dclkin   : IN  std_logic;
                 sdoin    : IN  std_logic;
                 data0out : OUT std_logic
                 );
   END COMPONENT;


   COMPONENT  arriagx_asmiblock
      PORT      ( 
                 data0out : OUT std_logic;
                 dclkin   : IN  std_logic;
                 oe       : IN  std_logic := '0';
                 scein    : IN  std_logic;
                 sdoin    : IN  std_logic
                 );
   END COMPONENT;


   COMPONENT cyclonev_asmiblock 
      Port      (
                 dclk     : in  std_logic;
                 sce      : in  std_logic;
                 oe       : in  std_logic;
                 data0out : in  std_logic;
                 data1out : in  std_logic;
                 data2out : in  std_logic;
                 data3out : in  std_logic;
                 data0oe  : in  std_logic;
                 data1oe  : in  std_logic;
                 data2oe  : in  std_logic;
                 data3oe  : in  std_logic;
                 data0in  : out std_logic;
                 data1in  : out std_logic;
                 data2in  : out std_logic;
                 data3in  : out std_logic
                 );
   END COMPONENT;




   -- PRAGMA SYNTHESIS_OFF
   --COMPONENT M25P40
      --PORT  (
             --VCC      : IN  real;
             --C        : IN  std_logic;
             --D        : IN  std_logic;
             --S        : IN  std_logic;
             --W        : IN  std_logic;
             --HOLD     : IN  std_logic;
             --Q        : OUT std_logic
             --);
   --END COMPONENT ;
   --FOR ALL: M25P40 USE ENTITY Flash_Memory.M25P40;
   -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------

BEGIN
   
   -- Concurrent 1
   ASMI_Data0 <= Data0_Int;
   ASMI_Access_Request <= Access_Request_Int;
	
	
   -- PRAGMA SYNTHESIS_OFF
   -- Debug QFU
   --Serial_Flash: M25P40
   --PORT MAP (
               --VCC      => 3.3,
               --C        => DCLK,
               --D        => SDO,
               --S        => SCE,
               --W        => '1',
               --HOLD     => '1',
               --Q        => Data0_Int
               --);
   -- Debug QFU END
   -- PRAGMA SYNTHESIS_ON


   ASMI_Bridge: IF (ASMI_JTAG_Bridge_EN = 1) GENERATE
   BEGIN
      Arria_GX_SFL: IF (FPGA_Family = 8) GENERATE
      BEGIN
--         SFL: Altserial_Flash_Loader
--            GENERIC MAP (
--                         enable_shared_access => Share_Access,
--                         lpm_type             => "altserial_flash_loader"
--                         )
--         PORT MAP       (
--                         scein                => ASMI_CS_n,
--                         dclkin               => ASMI_DCLK,
--                         sdoin                => ASMI_ASDO,
--                         asmi_access_granted  => asmi_access_granted,
--                         noe                  => ASMI_OE_n,
--                         data0out             => Data0_Int,
--                         asmi_access_request  => Access_Request_Int
--                         );
      END GENERATE Arria_GX_SFL;
   

      Cyclone_V_SFL: IF (FPGA_Family = 10) GENERATE
      BEGIN
         SFL: Altera_serial_flash_loader
            GENERIC MAP (
                         INTENDED_DEVICE_FAMILY   => "Cyclone V",
                         ENHANCED_MODE            => true,
                         ENABLE_SHARED_ACCESS     => "ON",
                         ENABLE_QUAD_SPI_SUPPORT  => false,
                         NCSO_WIDTH               => 1
                         )
            PORT MAP    (
                         dclk_in                 => ASMI_DCLK,--: IN  std_logic                    := 'X';             -- dclkin
                         ncso_in                 => ASMI_CS_n,--: IN  std_logic                    := 'X';             -- scein
                         data_in                 => ASMI_QASD,--: IN  std_logic_vector(3 DOWNTO 0) := (OTHERS => 'X'); -- data_in
                         data_oe                 => ASMI_QOE_n,--: IN  std_logic_vector(3 DOWNTO 0) := (OTHERS => 'X'); -- data_oe
                         noe_in                  => ASMI_OE_n,--: IN  std_logic                    := 'X';             -- noe
                         asmi_access_granted     => asmi_access_granted,--: IN  std_logic                    := 'X';             -- asmi_access_granted
                         data_out                => ASMI_QDATA,--: OUT std_logic_vector(3 DOWNTO 0);                    -- data_out
                         asmi_access_request     => Access_Request_Int--: OUT std_logic                                        -- asmi_access_request
                         );
      END GENERATE Cyclone_V_SFL;
   END GENERATE ASMI_Bridge;


   ASMI_Access_Only: IF ((ASMI_JTAG_Bridge_EN = 0) AND (ASMI_Access_EN = 1)) GENERATE
   BEGIN
      -- We have a Cyclone device...
      Cyclone_I_ASMI: IF ((FPGA_Family = 4) OR (FPGA_Family = 5)) GENERATE
      BEGIN
         ASMI_Spiblock: CYCLONE_SPIBLOCK
         PORT MAP    (
                      oe       => ASMI_OE_n,-- This signal of the HW is an active low signal.
                      scein    => ASMI_CS_n,
                      dclkin   => ASMI_DCLK,
                      sdoin    => ASMI_ASDO,
                      data0out => Data0_Int
                      );
      END GENERATE Cyclone_I_ASMI;

      -- We have an Arria GX...             
      Arria_GX_ASMI: IF (FPGA_Family = 8) GENERATE
      BEGIN
         ASMI_Spiblock: arriagx_asmiblock
         PORT MAP      ( 
                        data0out => Data0_Int,
                        dclkin   => ASMI_DCLK,
                        oe       => ASMI_OE_n,-- This signal of the HW is an active low signal.
                        scein    => ASMI_CS_n,
                        sdoin    => ASMI_ASDO
                        );
      END GENERATE Arria_GX_ASMI;

      -- We have a Cyclone V device...
      Cyclone_V_ASMI: IF (FPGA_Family = 10) GENERATE
      BEGIN
      ASMI_Spiblock: cyclonev_asmiblock 
         PORT MAP      (
                        dclk        => ASMI_DCLK,
                        sce         => ASMI_CS_n,
                        oe          => ASMI_OE_n,
                        -- QSPI Bit 0 is used for "normal" SPI.
                        data0out    => ASMI_QASD(0),
                        data1out    => ASMI_QASD(1),
                        data2out    => ASMI_QASD(2),
                        data3out    => ASMI_QASD(3),
                        data0oe     => ASMI_QOE_n(0),
                        data1oe     => ASMI_QOE_n(1),
                        data2oe     => ASMI_QOE_n(2),
                        data3oe     => ASMI_QOE_n(3),
                        data0in     => ASMI_QDATA(0),
                        data1in     => ASMI_QDATA(1),
                        data2in     => ASMI_QDATA(2),
                        data3in     => ASMI_QData(3)
                        );
      END GENERATE Cyclone_V_ASMI;

      -- Concurrent 2
      Access_Request_Int <= '0';
   END GENERATE ASMI_Access_Only;
   
   
   ASMI_No_Functionality: IF ((ASMI_JTAG_Bridge_EN = 0) AND (ASMI_Access_EN = 0)) GENERATE
   BEGIN
      Access_Request_Int <= '0';
      Data0_Int <= '0';
   END GENERATE ASMI_No_Functionality;



END Universal;