--------------------------------------------------------------------------------
-- GIN_TTL_base.vhd
--------------------------------------------------------------------------------
--
--	project		: GIN-TTL Base Black Box Wrapper
--	programmer	: Q. Fueglistaller, INDEL AG
--	date		: 19.01.2017
--	language	: VHDL
--	system		: GIN-PASS
--
--	purpose
--				GIN-TTL Base Wrapper
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 16.06.2017-qfu:	rev.09 (has to be in sync. with the functional version)
--					- Check in of the GIN-TTL Base that can be used as wrapper entity, too.
--						(tristate signals can be routed through the wrapper as directd signals.
--						This way round they remain functional during netlist generation.
--					- Updated the PLL entity with an additional 250MHz clock output.
--					- Important: For the possibility to simply generate a black box of the
--						GIN-TTL Base entity every time, make sure that you are using the VHDL
--						representation of all the RAM blocks within the GIN-TTL Base entity.
--						If you are using the "old" kind of blocks that are dated back to Spartan 3,
--						the "black box" can not be instantiated in a Spartan 6. This is because it is
--						using "non native" hardware blocks.

--------------------------------------------------------------------------------
--$Rev:: 4512                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2017-06-16 09:07:02 +0200 (Fr., 16 Jun 2017)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

library RGMII_if;
use RGMII_if.ALL;

library gin_slave;
use gin_slave.ALL;

library gin_link;
use gin_link.ALL;

library C64_Master;
use C64_Master.All;

library C64_Slave;
use C64_Slave.All;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library Unisim;
use Unisim.vcomponents.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity GIN_TTL_base is
generic (
	Revision		: in std_logic_vector(7 downto 0) := x"07"; -- 0x8x für not released
	DF_TESTMODE		: in integer range 0 to 1 := 0;
	C_EMG_SYS		: in integer range 0 to 1 := 0;
	C_SWAP_PHY		: in integer range 0 to 1 := 0; -- 0: input = phy0 (X9)
	C_WO_PHY_OUT	: in integer range 0 to 1 := 0; -- 1: without PhyOut
	C_USE_EXTRA_REG : integer range 0 to 1 := 0;
	-- w/wo TB for I2C-Pins
	C_I2C_TRSBUF	: in integer range 0 to 1 := 0; -- 1: with (internal) tristate buffers
	-- w/wo TB for SPI-Pins
	C_SPI_TRSTBUF	: in integer range 0 to 1 := 1; -- 1: with (internal) tristate buffers
	-- patch to change eeprom address 
	C_PATCH_EE_ADDR	: in integer range 0 to 1 := 0;
	C_PATCH_ADDR_F	: in std_logic_vector(3 downto 0) := x"0"; -- from
	C_PATCH_ADDR_T	: in std_logic_vector(3 downto 0) := x"0" -- to
);
port (
	i_extern_CLK25 		: in std_logic;
	-- i2c bus (GIN-TTL eeprom) ------------------------------------------------
	b_SCL 				: inout std_logic;
	o_SCL 				: out std_logic:= '1';
	b_SDA 				: inout std_logic;
	o_SDA 				: out std_logic:= '1';
	-- 250MHz clock output, for example for SerialSAT    
	o_CLK250			: out  std_logic;
	-- jtag port ---------------------------------------------------------------
	o_jtagTCK 			: out std_logic;
	o_jtagTMS 			: out std_logic;
	i_jtagTDO 			: in std_logic;
	o_jtagTDI 			: out std_logic; 
	-- SPI ---------------------------------------------------------------------
	no_SPI_CS 			: inout std_logic;
	o_SPI_CLK 			: inout std_logic;
	o_SPI_D 			: inout std_logic;
	i_SPI_Q 			: in std_logic := '0';
	-- g_SPI_TrstBuf = 0:	SPI_OE
	o_SPI_OE 			: out	std_logic;
	-- Ethernet ----------------------------------------------------------------
	no_PHY_RESET 		: out std_logic;
	i_PHY_CLK125 		: in std_logic:='0';
	i_PHY_RXC0 			: in std_logic;
	o_PHY_TXD0 			: out std_logic_vector(3 downto 0);
	o_PHY_TXEN0 		: out std_logic;
	i_PHY_RXD0 			: in std_logic_vector(3 downto 0);
	i_PHY_RXDV0 		: in std_logic;
	o_PHY_GTXCLK0 		: out std_logic;
	i_PHY_RXC1 			: in std_logic;
	o_PHY_TXD1 			: out std_logic_vector(3 downto 0);
	o_PHY_TXEN1 		: out std_logic;
	i_PHY_RXD1 			: in std_logic_vector(3 downto 0);
	i_PHY_RXDV1 		: in std_logic;
	o_PHY_GTXCLK1 		: out std_logic;
	o_PHY_MDC 			: inout std_logic_vector(1 downto 0);
	b_PHY_MDIO 			: inout std_logic_vector(1 downto 0);
	o_MII_T 			: out std_logic;
	o_MII_Do 			: out std_logic;

	-- leds --------------------------------------------------------------------
	o_ErrorLED 			: out std_logic;
	o_OkLED 			: out std_logic;
	
	i_AddrSw 			: in std_logic_vector(3 downto 0);
	no_EEP_Wen 			: inout std_logic;
	ni_HWRev 			: in  std_logic_vector( 3 downto 0);
	
	o_SlvInt_CLK125		: out std_logic;
	o_SlvInt_CLK_EN		: out std_logic;
	
	-- i2c bus (Slave eeprom) --------------------------------------------------
	b_SlvInt_SCL		: inout std_logic;
	b_SlvInt_SDA		: inout std_logic; 
	
	-- WatchDog signals of GinLink (800ms, normally used for LEDs) -------------
	o_fwGinFrm_LedDog	: out std_logic;
	o_bwGinFrm_LedDog	: out std_logic;
	
	-- COP-BUS intern ------------------------------------------------------
	i_SlvInt_Ack_OE		: in std_logic := L;
	i_SlvInt_Slv2Mas	: in std_logic_vector(15 downto 0) := (others => L);
	i_SlvInt_Dat_HOE	: in std_logic := L;
	i_SlvInt_Dat_LOE	: in std_logic := L;
	o_SlvInt_Mas2Slv	: out std_logic_vector(15 downto 0);
	o_SlvInt_Reset		: out std_logic;
	o_SlvInt_CLK		: out std_logic;
	o_SlvInt_SEL		: out std_logic;
	o_SlvInt_Bend		: out std_logic
  );
end GIN_TTL_base;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of GIN_TTL_base is



begin -- architecture ----------------------------------------------------------



end architecture STRUCTURE;
