-- Module SPI_Package                                                         --
-- VHDL Package Indel_lib.SPI_Package                                         --
--                                                                            --
-- InfoLink, GinLink, INFO-PCIe, INFO-SAM3, SAM4 Copyright (c): INDEL AG      --
--                                                                            --
-- Project:   SPI Access                                                      --
--                                                                            --
-- INDEL AG, Tuefiwis 26, 8332 Russikon, Switzerland                          --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- Package for SPI Flash specific constants and definitions.                  --
-- -------------------------------------------------------------------------- --
-- Within this package you can find definitions related to SPI devices. In a  --
-- first step SPI flash devices of the X25Y.... family are supported. The max.--
-- speed is not defined in the package based on the fact that multiple buses  --
-- with different max. speeds can be found in a design. Where identical       --
-- OPCODES with different meanings exist, the one with the broadest support   --
-- is chosen.                                                                 --
-- Added 32 Bit address commands                                              --
-- Added QPI mode                                                             --
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
--$Rev:: 3750                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2015-04-07 11:23:18 +0200 (Di., 07 Apr 2015)                         $
--------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;


PACKAGE SPI_Package IS





   -------------------
   -- Type Declaration
   -------------------


   -----------------------
   -- Type Declaration END
   -----------------------



   -----------------------
   -- Constant Declaration
   -----------------------



   -----------------
   --  SPI OP Codes:
   -----------------
   --  The names of the opcodes are identical to the data in the Macronix datasheets.


   ---------------
   -- WRITE ENABLE
   ---------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  WREN_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"06";
   
   ----------------
   -- WRITE DISABLE
   ----------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  WRDI_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"04";
   
   --------------
   -- READ STATUS
   --------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 1 to infinite,
   CONSTANT  RDSR_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"05";
   
   -------------
   -- READ BYTES
   -------------
	-- Mode: SPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 0,
   -- Data Bytes: 1 to infinite,
   CONSTANT  READ_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"03";

   ------------------
   -- FAST READ BYTES
   ------------------
	-- Mode: SPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 1,
   -- Data Bytes: 1 to infinite
   CONSTANT  FAST_READ_C_SPI_PKG    :  std_logic_vector(7 DOWNTO 0) := X"0B";

   -----------------
   -- TWO READ BYTES
   -----------------
	-- Mode: SPI
   -- Address Bytes: 2,
   -- Dummy Bytes: 1,
   -- Data Bytes: 1 to infinite, MSB is on SI/SIO0, count base is 4 Bit
   CONSTANT  TWO_READ_C_SPI_PKG     :  std_logic_vector(7 DOWNTO 0) := X"BB";
	
	--------------
   -- TREAD BYTES
   --------------
	-- Mode: SPI
   -- Address Bytes: 2,
   -- Dummy Bytes: *,
   -- Data Bytes: 1 to infinite, MSB is on SI/SIO0, count base is 4 Bit
   CONSTANT  TREAD_C_SPI_PKG     :  std_logic_vector(7 DOWNTO 0) := X"3B";
	
	------------------
   -- QUAD READ BYTES
   ------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 6,
   -- Data Bytes: 1 to infinite, MSB is on SI/SIO0, count base is 2 Bit
   CONSTANT  QUAD_READ_C_SPI_PKG    :  std_logic_vector(7 DOWNTO 0) := X"EB";
	
	---------------
   --  QREAD BYTES
   ---------------
	-- Mode: SPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: *,
   -- Data Bytes: 1 to infinite, MSB is on SI/SIO0, count base is 2 Bit
   CONSTANT  QREAD_C_SPI_PKG        :  std_logic_vector(7 DOWNTO 0) := X"6B";
   
   ---------------
   -- WRITE STATUS
   ---------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 1,
   CONSTANT  WRST_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"01";
   
   --------------
   -- WRITE BYTES
   --------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 0,
   -- Data Bytes: 1 to 256,
   CONSTANT  PP_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"02";

   -------------------------
   -- CONTINUOUS WRITE BYTES
   -------------------------
	-- Mode: SPI
   -- Address Bytes: 3,
   -- Dummy Bytes: 0,
   -- Data Bytes: 1 to 256,
   CONSTANT  CPP_C_SPI_PKG          :  std_logic_vector(7 DOWNTO 0) := X"AD";

   ------------------
   -- DEEP POWER DOWN
   ------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT DP_C_SPI_PKG            :  std_logic_vector(7 DOWNTO 0) := X"B9"; -- enters deep power down mode.
   
   ------------------
   -- READ SILICON ID
   ------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 3,
   -- Data Bytes: 1 to infinite,
   -- Additional function: release from deep power down mode
   CONSTANT RSID_C_SPI_PKG          :  std_logic_vector(7 DOWNTO 0) := X"AB";
   
  -----------------------
  -- READ Manufacturer ID
  -----------------------
 	-- Mode: SPI
  -- Address Bytes: 1, if AD 0 x"0" then manufacturer ID first, else device ID first
  -- Dummy Bytes: 3,
  -- Data Bytes: 1 to infinite,
  CONSTANT RMID_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"90";

  ---------------------------
  -- TWO READ Manufacturer ID
  ---------------------------
 	-- Mode: SPI
  -- Address Bytes: 1, if AD 0 x"0" then manufacturer ID first, else device ID first
  -- Dummy Bytes: 3,
  -- Data Bytes: 1 to infinite,
  CONSTANT RM2ID_C_SPI_PKG          :  std_logic_vector(7 DOWNTO 0) := X"EF";

  ----------------------------
  -- JEDEC RDID IDENTIFICATION
  ----------------------------
 	-- Mode: SPI
  -- Address Bytes: 0
  -- Dummy Bytes: 0,
  -- Data Bytes: outputs: 1 byte manufacturer ID & 2 byte device ID.
  CONSTANT RDID_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"9F";
   
   -------------
   -- ERASE BULK
   -------------
   -- Chip erase
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  CE_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"C7"; -- command 0.
	
	-------------
   -- ERASE BULK
   -------------
   -- Chip erase
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  CE_A_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"60"; -- command 1.
   
   --------------
   -- ERASE BLOCK
   --------------
   -- Erase selcted block
	-- Mode: SPI/ QPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  BE_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"D8"; -- the "old" block erase (check sector size).

	--------------
   -- ERASE BLOCK
   --------------
   -- Erase selcted block
	-- Mode: SPI/ QPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  BE_A_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"52"; -- the "new" block erase (check sector size, normally 32k).
	
   ---------------
   -- ERASE SECTOR
   ---------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 3, 4
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  SE_C_SPI_PKG           :  std_logic_vector(7 DOWNTO 0) := X"20"; -- the "new" sector erase.

   --------------------
   -- ENTER SECURED OTP
   --------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  ENSO_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"B1"; -- enter the 512 bit secured mode

   -------------------
   -- EXIT SECURED OTP
   -------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  EXSO_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"C1"; -- exit the 512 bit secured mode

   -------------------------
   -- READ SECURITY REGISTER
   -------------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  RDSCUR_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"2B"; -- read the security register.

   --------------------------
   -- WRITE SECURITY REGISTER
   --------------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  WRSCUR_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"2F"; -- write security registers- can not be undone.

   ----------------------
   -- ENABLE SO TO OUTPUT
   ----------------------
	-- Mode: SPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  ESRY_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"70"; -- enable the status register at the SO port.

   -----------------------
   -- DISABLE SO TO OUTPUT
   -----------------------
	-- Mode: SPI
   -- Address Bytes: 0,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  DSRY_C_SPI_PKG         :  std_logic_vector(7 DOWNTO 0) := X"80"; -- disable the status register at the SO port.
	
	----------------------
   -- READ DATA 4 BYTE AD
   ----------------------
	-- Mode: SPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  READ4B_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"13"; -- read data using 4 byte address.
	
   ---------------------------
   -- FAST READ DATA 4 BYTE AD
   ---------------------------
	-- Mode: SPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  FREAD4B_C_SPI_PKG      :  std_logic_vector(7 DOWNTO 0) := X"0C"; -- fast read data using 4 byte address.
	
	------------------------
   -- 2 READ DATA 4 BYTE AD
   ------------------------
	-- Mode: SPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  TREAD4B_C_SPI_PKG      :  std_logic_vector(7 DOWNTO 0) := X"BC"; -- two read data using 4 byte address.

	---------------------------
   -- DUAL READ DATA 4 BYTE AD
   ---------------------------
	-- Mode: SPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  DREAD4B_C_SPI_PKG      :  std_logic_vector(7 DOWNTO 0) := X"3C"; -- dual read data using 4 byte address.
	
   ------------------------
   -- 4 READ DATA 4 BYTE AD
   ------------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  FOURREAD4B_C_SPI_PKG   :  std_logic_vector(7 DOWNTO 0) := X"EC"; -- 4 read data using 4 byte address.
	
	---------------------------
   -- QUAD READ DATA 4 BYTE AD
   ---------------------------
	-- Mode: SPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  QREAD4B_C_SPI_PKG      :  std_logic_vector(7 DOWNTO 0) := X"6C"; -- quad read data using 4 byte address.
	
	-----------------------
   -- WRITE DATA 4 BYTE AD
   -----------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  WRITE4B_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"12"; -- write data using 4 byte address.
	
	-------------------------
   -- 4 WRITE DATA 4 BYTE AD
   -------------------------
	-- Mode: SPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  FOURWRITE4B_C_SPI_PKG   :  std_logic_vector(7 DOWNTO 0) := X"3E"; -- 4 write data using 4 byte address.
	
	------------------------
   -- BLOCK ERASE 4 BYTE AD
   ------------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  BE4B_C_SPI_PKG          :  std_logic_vector(7 DOWNTO 0) := X"DC"; -- block erase using 4 byte address.
	
	-----------------------------
   -- 32KB BLOCK ERASE 4 BYTE AD 
   -----------------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  BE32KB4B_C_SPI_PKG      :  std_logic_vector(7 DOWNTO 0) := X"5C"; -- 32kb block erase using 4 byte address.
	
	-------------------------
   -- SECTOR ERASE 4 BYTE AD
   -------------------------
	-- Mode: SPI/ QPI
   -- Address Bytes: 4,
   -- Dummy Bytes: 0,
   -- Data Bytes: 0,
   CONSTANT  SE4B_C_SPI_PKG          :  std_logic_vector(7 DOWNTO 0) := X"21"; -- block erase using 4 byte address.
	
	

   ----------------
   -- SPI Sequences
   ----------------
   -- This are opcodes for custom sequences (always check if a supplier uses this word as a single command).
   CONSTANT  WR_SEQ_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"88"; -- (WREN_C_SPI_PKG & PP_C_SPI_PKG & RDSR_C_SPI_PKG)
   CONSTANT  WR_ST_SEQ_C_SPI_PKG    :  std_logic_vector(7 DOWNTO 0) := X"81"; -- (WREN_C_SPI_PKG & WRST_C_SPI_PKG & RDSR_C_SPI_PKG)
   CONSTANT  SE_SEQ_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"8C"; -- (WREN_C_SPI_PKG & SE_C_SPI_PKG & RDSR_C_SPI_PKG)
   CONSTANT  BE_SEQ_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"83"; -- (WREN_C_SPI_PKG & BE_C_SPI_PKG & RDSR_C_SPI_PKG)
   CONSTANT  CE_SEQ_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"8F"; -- (WREN_C_SPI_PKG & CE_C_SPI_PKG & RDSR_C_SPI_PKG)
   --------------------
   -- SPI Sequences END
   --------------------

   -------------------
   -- SPI OP Codes END
   -------------------


   ----------------------
   -- SPI Manufacturer ID
   ----------------------
   -- Manufacturer ID's which were not checked are set to X"00".
   CONSTANT  Macronix_MFID_C_SPI_PKG  :  std_logic_vector(7 DOWNTO 0) := X"C2";
   CONSTANT  Numonyx_MFID_C_SPI_PKG   :  std_logic_vector(7 DOWNTO 0) := X"20";
   CONSTANT  Spansion_MFID_C_SPI_PKG  :  std_logic_vector(7 DOWNTO 0) := X"01";
   CONSTANT  Intel_MFID_C_SPI_PKG     :  std_logic_vector(7 DOWNTO 0) := X"00";
   CONSTANT  Winbond_MFID_C_SPI_PKG   :  std_logic_vector(7 DOWNTO 0) := X"EF";
   CONSTANT  Atmel_MFID_C_SPI_PKG     :  std_logic_vector(7 DOWNTO 0) := X"1F";
   CONSTANT  SST_MFID_C_SPI_PKG       :  std_logic_vector(7 DOWNTO 0) := X"BF";
   --------------------------
   -- SPI Manufacturer ID END
   --------------------------


   -----------------
   -- SPI Dummy data
   -----------------
   -- There are opcodes where you have to deliver dummy data-
   CONSTANT Dummy_Data_C_SPI_PKG      :  std_logic_vector(7 DOWNTO 0) := X"00";
   ---------------------
   -- SPI Dummy data END
   ---------------------


   ------------------------
   -- SPI Flash Memory Size
   ------------------------
   -- The size of the device can be read out.
   --CONSTANT SPI_Flash_Size_C_SPI_PKG  :  std_logic_vector(7 DOWNTO 0) := X
   CONSTANT  SPI_Address_C_SPI_PKG     : natural := 24;
   ----------------------------
   -- SPI Flash Memory Size END
   ----------------------------


   ------------------
   -- SPI device type
   ------------------
   CONSTANT SFlash_Type_C_SPI_PKG              : std_logic_vector(7 DOWNTO 0) := X"20";
   ----------------------
   -- SPI device type END
   ----------------------


   ---------------------------
   -- Constant Declaration END
   ---------------------------




   -----------------------
   -- Function Declaration
   -----------------------

   ---------------------------
   -- Function Declaration END
   ---------------------------


END PACKAGE SPI_Package;





Package BODY SPI_Package IS



END Package BODY SPI_Package;