--------------------------------------------------------------------------------
-- GIN_TTL_base.vhd
--------------------------------------------------------------------------------
--
--	project		: GIN-TTL
--	programmer	: C.Leuthold, INDEL AG
--	date		: 23.01.2013
--	language	: VHDL
--	system		: GIN-PASS
--
--	purpose
--				GIN-slave with 60 TTL IOs + Temp sensor
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- Revison 0x05
--	22.01.2013-le : - create
--	08.10.2013-le : - move to library
--	31.01.2014-stn: - added C_SWAP_PHY to swap GINLink-IN and GINLink-OUT
--					  for custom fpgas (like DVT-AT-HEAD)
--	05.02.2014-stn:	rev.06
--					- added o_fwGinFrm_LedDog and o_bwGinFrm_LedDog (800ms-
--					WatchDogs, normally used for LEDs, but now for DVT-AT-HEAD)
--	18.02.2014-stn:	rev.07
--					- added external eeprom if (0..7, in this case of internal slave)
--					- changed name of internal eeprom if
--					- added generics to patch i2c eeprom address
--					(reference project gin-ttl_oct)
--					- added C_WO_PHY_OUT to deactivate the GIN-Out phy
--	04.04.2014-stn:	rev.08
--					- added C_SPI_TRSTBUF generic and o_SPI_OE output
--					(to g_SPI_TrstBuf of C64_SlaveSeq)
-- 16.06.2017-qfu:	rev.09
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
--	21.12.2017-le	:	rev.0a
--					reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	24.04.2018-le	:	rev.0b
--					- b_PHY_MDIO and o_PHY_MDC to in and out
--					- rename o_SlvInt_CLK
--------------------------------------------------------------------------------
--$Rev:: 5720                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2020-10-27 19:07:51 +0100 (Di., 27 Okt 2020)                         $
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

library gin_eth;
use gin_eth.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity GIN_TTL_base is
generic (
	Revision			: in std_logic_vector(7 downto 0) := x"0b"; -- 0x8x für not released
	DF_TESTMODE		: in integer range 0 to 1 := 0;
	C_COPIMP		: in integer range 0 to 1 := 0;	-- 1 for GIN-IMP-PAS
	C_TUNNEL		: in integer range 0 to 2 := 0; -- 1: ginEth Tunnel enabled, 2: also enabled, but used on 2. phy (C_WO_PHY_OUT=1)
	C_EMG_SYS		: in integer range 0 to 1 := 0;
	C_SWAP_PHY		: in integer range 0 to 1 := 0; -- 0: input = phy0 (X9)
	C_WO_PHY_OUT	: in integer range 0 to 1 := 0; -- 1: without PhyOut
	C_USE_EXTRA_REG	: integer range 0 to 1 := 0;
	-- w/wo TB for I2C-Pins
	C_I2C_TRSBUF	: in integer range 0 to 1 := 1; -- 1: with (internal) tristate buffers
	-- w/wo TB for SPI-Pins
	C_SPI_TRSTBUF	: in integer range 0 to 1 := 1; -- 1: with (internal) tristate buffers
	-- patch to change eeprom address 
	C_PATCH_EE_ADDR	: in integer range 0 to 1 := 0;
	C_PATCH_ADDR_F	: in std_logic_vector(3 downto 0) := x"0"; -- from
	C_PATCH_ADDR_T	: in std_logic_vector(3 downto 0) := x"0" -- to
);
port (
	i_extern_CLK25 	: in std_logic;
	o_clk125 			: out	std_logic;
	o_clk62_5 			: out	std_logic;
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
	o_PHY_MDC 			: out std_logic_vector(1 downto 0);
	b_PHY_MDIO 			: in std_logic_vector(1 downto 0);
	o_MII_T 			: out std_logic;
	o_MII_Do 			: out std_logic;

	-- leds --------------------------------------------------------------------
	o_ErrorLED 			: out std_logic;
	o_OkLED 			: out std_logic;
	
	i_AddrSw 			: in std_logic_vector(3 downto 0);
	no_EEP_Wen 			: inout std_logic;
	ni_HWRev 			: in  std_logic_vector( 3 downto 0);
	
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
	o_SlvInt_CLK_notfornewdesigns: out std_logic; -- please use 125Mhz and ClkEn
	o_SlvInt_CLK125		: out std_logic;
	o_SlvInt_CLK_EN		: out std_logic;
	o_SlvInt_SEL		: out std_logic;
	o_SlvInt_Bend		: out std_logic;
	-- tunnel
	i_GinETH_data_en	: in  std_logic := L;
	i_GinETH_clk_en		: in  std_logic := L;
	o_GinETH_TxDat		: out std_logic_vector(7 downto 0);
	o_GinETH_TxDv		: out std_logic;
	o_GinETH_TxErr		: out std_logic;
	i_GinETH_RxDat		: in  std_logic_vector(7 downto 0) := (others => L);
	i_GinETH_RxDv		: in  std_logic := L;
	i_GinETH_RxErr		: in  std_logic := L;
	o_Phy1_LEDStat		: out std_logic_vector(15 downto 0)
  );
end GIN_TTL_base;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of GIN_TTL_base is
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	constant C_GIN_MASTERnSLAVE : integer range 0 to 1 := 0;
	constant C_DUAL_ETH : integer range 0 to 1 := 0;
	constant gin_flg_ringmode : std_logic := L;
	constant EthTx_LedDog_2 : std_logic := L;

	constant CFG_PHY0_PD : std_logic_vector(31 downto 0) :=
		"0101"&"00000"&"00000"&"10"&"0001100101000000"; -- power down phy0
	constant CFG_PHY1_PD : std_logic_vector(31 downto 0) :=
		"0101"&"00001"&"00000"&"10"&"0001100101000000"; -- power down phy1
	constant CFG_PHYX_NOP : std_logic_vector(31 downto 0) := x"00000000"; -- no operation
	-- now standby power down mode used
	-- but there is also another mode: ultra low power down (iddq, 17h=0d06h -> access 15h)
	signal PhyX : std_logic_vector(31 downto 0) := (others => L);

	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------

	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------

	signal net_gnd : std_logic := L;
	signal net_vcc : std_logic := H;
	signal GND32 : std_logic_vector(31 downto 0) := (others => L);

	signal TestV32_2 : std_logic_vector(31 downto 0) := (others => L);

	signal clk125 		: std_logic;
	signal clk62_5 	: std_logic;
	signal clk25 		: std_logic;
	signal phy_dcm_Locked : std_logic;

	signal Phy_reset : std_logic;

--------------------------------------------------------------------------------
--	GMII
--------------------------------------------------------------------------------
	signal Gin_GMII_RxDat0	: std_logic_vector(7 downto 0);
	signal Gin_GMII_RxDv0	: std_logic;
	signal Gin_GMII_RxErr0	: std_logic;
	signal Gin_GMII_TxDat0	: std_logic_vector(7 downto 0);
	signal Gin_GMII_TxDv0	: std_logic;
	signal Gin_GMII_TxErr0	: std_logic;

	signal Gin_GMII_RxDat1	: std_logic_vector(7 downto 0);
	signal Gin_GMII_RxDv1	: std_logic;
	signal Gin_GMII_RxErr1	: std_logic;
	signal Gin_GMII_TxDat1	: std_logic_vector(7 downto 0);
	signal Gin_GMII_TxDv1	: std_logic;
	signal Gin_GMII_TxErr1	: std_logic;

--------------------------------------------------------------------------------
--	GinLink Slave
--------------------------------------------------------------------------------
	signal Gin_BRAM_EN		: std_logic := H;
	signal Gin_BRAM_WEN		: std_logic_vector( 3 downto 0);
	signal Gin_BRAM_Addr	: std_logic_vector(15 downto 0);
	signal Gin_BRAM_Dout	: std_logic_vector(31 downto 0);
	signal Gin_BRAM_Din		: std_logic_vector(31 downto 0);
	signal BRAM_ByteAddr	: std_logic_vector(15 downto 0);

	signal Gin_fwGMII_RxDat	: std_logic_vector(7 downto 0);
	signal Gin_fwGMII_RxDv	: std_logic;
	signal Gin_fwGMII_RxErr	: std_logic;
	signal Gin_fwGMII_TxDat	: std_logic_vector(7 downto 0);
	signal Gin_fwGMII_TxDv	: std_logic;
	signal Gin_fwGMII_TxErr	: std_logic;

	signal Gin_bwGMII_RxDat	: std_logic_vector(7 downto 0);
	signal Gin_bwGMII_RxDv	: std_logic;
	signal Gin_bwGMII_RxErr	: std_logic;
	signal Gin_bwGMII_TxDat	: std_logic_vector(7 downto 0);
	signal Gin_bwGMII_TxDv	: std_logic;
	signal Gin_bwGMII_TxErr	: std_logic;

	signal fwGinRun			: std_logic;
	signal bwGinRun			: std_logic;
	signal bwGinxChanger	: std_logic;

	signal Gin_IRQs			: std_logic_vector( 7 downto 0);
	signal Gin_Wdogs		: std_logic_vector( 7 downto 0);
	signal Gin_TlgSyn		: std_logic_vector( 7 downto 0);
	signal GF_Flags			: std_logic_vector(15 downto 0);
	signal cIntCnt 			: std_logic;
	signal Gin_SlvFlags		: std_logic_vector(31 downto 0) := (others => L);
--------------------------------------------------------------------------------
--	MII
--------------------------------------------------------------------------------
	signal	MII_Clk			: std_logic;
	signal	MII_Do			: std_logic;
	signal	MII_T			: std_logic;
	signal	MII_Di			: std_logic;
	signal	Phy0_LEDgn		: std_logic;
	signal	Phy0_LEDyel		: std_logic;
	signal	Phy1_LEDgn		: std_logic;
	signal	Phy1_LEDyel		: std_logic;
	-- signals to change GIN-In and GIN-Out (with C_SWAP_PHY):
	signal	PhyIn_LEDgn		: std_logic;
	signal	PhyIn_LEDyel	: std_logic;
	signal	PhyOut_LEDgn	: std_logic;
	signal	PhyOut_LEDyel	: std_logic;
	signal PhyIn_linkState : std_logic := L;
	signal PhyOut_linkState : std_logic := L;

	signal linkState0 : std_logic := L;
	signal linkState1 : std_logic := L;

--------------------------------------------------------------------------------
--	Wdog
--------------------------------------------------------------------------------

	signal	bwGinFrm_LedDog	: std_logic;
	signal	fwGinFrm_LedDog	: std_logic;

--------------------------------------------------------------------------------
--	GE_LED Flasher
--------------------------------------------------------------------------------
	signal	Flash_1000		: std_logic;
	signal	Flash_0100		: std_logic;
	signal	Flash_0010		: std_logic;
	signal	Flash_0001		: std_logic;

	signal	Flash_1100		: std_logic;
	signal	Flash_0011		: std_logic;
	
	signal Flash_0101		: std_logic;
	signal Flash_1010		: std_logic;
	signal Flash_1110		: std_logic;

	signal	Bus_TlgSyn		: std_logic_vector( 7 downto 0);

--------------------------------------------------------------------------------
-- 	C64 Master
--------------------------------------------------------------------------------
	signal C64_Reset		: std_logic;
	signal C64_CLK			: std_logic;
	signal C64_nCLK			: std_logic;
	signal C64_SEL			: std_logic;
	signal C64_Bend			: std_logic;
	signal C64_Ack			: std_logic;
	signal C64_Ack_OE		: std_logic;
	signal C64_WrDat		: std_logic_vector(15 downto 0);
	signal C64_RdDat		: std_logic_vector(15 downto 0);
	signal C64_Dat_HOE		: std_logic;
	signal C64_Dat_LOE		: std_logic;
	signal C64_CLK_EN		: std_logic;

--------------------------------------------------------------------------------
--	local C64 Slave #9
--------------------------------------------------------------------------------
	constant DF_TYP : tSLV_Nx8(0 to 1) := (x"F0", x"EE"); -- typ(std, emg)
	constant g_SlaveApp_Rev	: std_logic_vector(15 downto 0) := DF_TYP(C_EMG_SYS) & (Revision + DF_TESTMODE*128+ DF_TESTMODE*32);	-- typ,vers 
--------------------------------------------------------------------------------  

	signal Slv_GF_Flags		: std_logic_vector(15 downto 0)	:= (others => '0');
	signal Card_Rd_Status	: std_logic_vector(11 downto 0);
	signal Card_Wr_Status	: std_logic_vector(15 downto 0);
	signal HWRev			: std_logic_vector(3 downto 0);

	-- slave Rd/Wr
	signal Slv_Addr			: std_logic_vector( 7 downto 0);
	signal Slv_RdData		: std_logic_vector(15 downto 0);
	signal Slv_WrData		: std_logic_vector(15 downto 0);
	signal Slv_WrEn			: std_logic;
	signal Slv_RdEn			: std_logic;

--------------------------------------------------------------------------------  
--	Slave #9 bus-signals
--------------------------------------------------------------------------------  
	signal Slv9_C64_Ack_OE	: std_logic;
	signal Slv9_C64_WrDat	: std_logic_vector(15 downto 0);
	signal Slv9_C64_Dat_HOE	: std_logic;
	signal Slv9_C64_Dat_LOE	: std_logic; 
	
	signal SlvInt_C64_Ack_OE	: std_logic;
	signal SlvInt_C64_WrDat	: std_logic_vector(15 downto 0);
	signal SlvInt_C64_Dat_HOE	: std_logic;
	signal SlvInt_C64_Dat_LOE	: std_logic;
	
	signal AddrSw : std_logic_vector(7 downto 0);
	
	signal Slv9_Testmode	: std_logic_vector(15 downto 0);
	constant cfg_TestMode	: std_logic_vector := x"F0";
	signal clk_reset : std_logic;

	
	--i2c signals----------------------------------------------------------
	signal C96_I2C_SDA : std_logic := '1'; -- internal (GIN-TTL, #9)
	signal C96_I2C_SCL : std_logic := '1';
	signal C64_I2C_SDA : std_logic := '1'; -- "external" (internal slave, not #9)
	signal C64_I2C_SCL : std_logic := '1';

	signal nOkLED           : std_logic :='0';
	signal nErrorLED        : std_logic :='0';
	
	signal Mac2Tun_D		: std_logic_vector(15 downto 0) := (others => L);
	signal Mac2Tun_En		: std_logic;
	signal Mac2Tun_Req_ack	: std_logic;
	signal Mac2Tun_Req		: std_logic;
	signal Tun2Mac_D		: std_logic_vector(15 downto 0);
	signal Tun2Mac_Dv		: std_logic;
	
	signal txcnt: std_logic_vector(15 downto 0) := (others => L);
	signal rxcnt: std_logic_vector(15 downto 0) := (others => L);
	signal txcnt2: std_logic_vector(15 downto 0) := (others => L);
	signal rxcnt2: std_logic_vector(15 downto 0) := (others => L);
	signal EthTx_LedDog		: std_logic := L;

begin -- architecture ----------------------------------------------------------

	o_OkLED <= not nOkLED;
	o_ErrorLED <= not nErrorLED;
	
	o_fwGinFrm_LedDog <= fwGinFrm_LedDog;
	o_bwGinFrm_LedDog <= bwGinFrm_LedDog;
	
	o_clk125 <= clk125;
	o_clk62_5 <= clk62_5;

phy_clk : entity work.PLL
	port map (-- Clock in ports
		CLK_IN25 => i_extern_CLK25,
		-- Clock out ports
		CLK_25 => clk25,
		CLK_62_5 => clk62_5,
		CLK_125 => clk125,
		CLK_250 => o_CLK250,
		LOCKED => phy_dcm_Locked
	);

--------------------------------------------------------------------------------
-- Instantiate IDELAYCTRL for the IDELAY in Fixed Tap Delay Mode
--------------------------------------------------------------------------------	
	no_PHY_RESET <= phy_dcm_Locked;
	
--------------------------------------------------------------------------------
--	Phy-0
--------------------------------------------------------------------------------
-- with Phy-0
w_phy_if0 : if (C_WO_PHY_OUT = 0 or C_SWAP_PHY = 0) generate
begin
	phy_if0 : entity RGMII_if.RGMII_if
	generic map (
		C_ELASTIC_BUF_LAT => 5,
		C_USE_EXTRA_REG => C_USE_EXTRA_REG,
		C_IOSTANDARD => "LVCMOS33"
	)
	port map (
		i_tx_clk		=> clk125,
		-- user interface
		o_data			=> Gin_GMII_RxDat0,
		o_data_valid	=> Gin_GMII_RxDv0,
		o_data_error	=> Gin_GMII_RxErr0,
		i_data			=> Gin_GMII_TxDat0,
		i_data_valid	=> Gin_GMII_TxDv0,
		i_data_error	=> Gin_GMII_TxErr0,
		-- rgmii ---------------------------------------------------------------
		i_PHY_RXC		=> i_PHY_RXC0,
		o_PHY_TXD		=> o_PHY_TXD0,
		o_PHY_TXEN		=> o_PHY_TXEN0,
		i_PHY_RXD		=> i_PHY_RXD0,
		i_PHY_RXDV		=> i_PHY_RXDV0,
		o_PHY_GTXCLK	=> o_PHY_GTXCLK0
	);
end generate;
-- without Phy-0
wo_phy_if0 : if (not(C_WO_PHY_OUT = 0 or C_SWAP_PHY = 0)) generate
begin
	o_phy_TXD0 <= (others => L);
	o_phy_TXEN0 <= L;
	o_phy_GTXCLK0 <= L;
end generate;

--------------------------------------------------------------------------------
--	Phy-1
--------------------------------------------------------------------------------
-- with Phy-1
w_phy_if1 : if (C_WO_PHY_OUT = 0 or C_SWAP_PHY = 1) generate
begin
	phy_if1 : entity RGMII_if.RGMII_if
	generic map (
		C_ELASTIC_BUF_LAT => 5,
		C_USE_EXTRA_REG => C_USE_EXTRA_REG,
		C_IOSTANDARD => "LVCMOS33"
	)
	port map (
		i_tx_clk		=> clk125,
		-- user interface
		o_data			=> Gin_GMII_RxDat1,
		o_data_valid	=> Gin_GMII_RxDv1,
		o_data_error	=> Gin_GMII_RxErr1,
		i_data			=> Gin_GMII_TxDat1,
		i_data_valid	=> Gin_GMII_TxDv1,
		i_data_error	=> Gin_GMII_TxErr1,
		-- rgmii ---------------------------------------------------------------
		i_PHY_RXC		=> i_PHY_RXC1,
		o_PHY_TXD		=> o_phy_TXD1,
		o_PHY_TXEN		=> o_phy_TXEN1,
		i_PHY_RXD		=> i_PHY_RXD1,
		i_PHY_RXDV		=> i_PHY_RXDV1,
		o_PHY_GTXCLK	=> o_phy_GTXCLK1
	);
end generate;
-- without Phy-1
wo_phy_if1 : if (not(C_WO_PHY_OUT = 0 or C_SWAP_PHY = 1)) generate
begin
	o_phy_TXD1 <= (others => L);
	o_phy_TXEN1 <= L;
	o_phy_GTXCLK1 <= L;
end generate;

--------------------------------------------------------------------------------
--	Phy connections (dependant on C_SWAP_PHY)
--------------------------------------------------------------------------------	
	Gin_fwGMII_RxDat	<= Gin_GMII_RxDat0	when C_SWAP_PHY=0 else Gin_GMII_RxDat1;
	Gin_fwGMII_RxDv		<= Gin_GMII_RxDv0	when C_SWAP_PHY=0 else Gin_GMII_RxDv1;
	Gin_fwGMII_RxErr	<= Gin_GMII_RxErr0	when C_SWAP_PHY=0 else Gin_GMII_RxErr1;

	Gin_GMII_TxDat0		<= Gin_bwGMII_TxDat	when C_SWAP_PHY=0 else Gin_fwGMII_TxDat;
	Gin_GMII_TxDv0		<= Gin_bwGMII_TxDv	when C_SWAP_PHY=0 else Gin_fwGMII_TxDv;
	Gin_GMII_TxErr0		<= Gin_bwGMII_TxErr	when C_SWAP_PHY=0 else Gin_fwGMII_TxErr;
	
	Gin_bwGMII_RxDat	<= Gin_GMII_RxDat1	when C_SWAP_PHY=0 else Gin_GMII_RxDat0;
	Gin_bwGMII_RxDv		<= Gin_GMII_RxDv1	when C_SWAP_PHY=0 else Gin_GMII_RxDv0;
	Gin_bwGMII_RxErr	<= Gin_GMII_RxErr1	when C_SWAP_PHY=0 else Gin_GMII_RxErr0;

	Gin_GMII_TxDat1		<= Gin_fwGMII_TxDat	when C_SWAP_PHY=0 else Gin_bwGMII_TxDat;
	Gin_GMII_TxDv1		<= Gin_fwGMII_TxDv	when C_SWAP_PHY=0 else Gin_bwGMII_TxDv;
	Gin_GMII_TxErr1		<= Gin_fwGMII_TxErr	when C_SWAP_PHY=0 else Gin_bwGMII_TxErr;

--------------------------------------------------------------------------------
--	GE_MII
--------------------------------------------------------------------------------

	u_GE_MII: 	entity 	gin_link.GE_MIISeq
	generic map (
		C_ADDR_4_1 => "0000",
		C_PHY => "BCM54210"
	)
	port map (
		i_Q62_5				=> clk62_5			,
		o_MII_Clk	        => MII_Clk	       	,
		o_MII_Dout	        => MII_Do	       	,
		o_MII_T		        => MII_T		   	,
		o_MII_Dinp		    => MII_Di	       	,
		i_Phy0_LED1			=> Phy0_LEDgn	   	,
		i_Phy0_LED2			=> Phy0_LEDyel	   	,
		i_Phy1_LED1			=> Phy1_LEDgn	   	,
		i_Phy1_LED2			=> Phy1_LEDyel	   	,
		o_linkState0		=> linkState0		,
		o_linkState1		=> linkState1		,
		o_Phy1_LEDStat		=> o_Phy1_LEDStat	,
		i_PhyX				=> PhyX
	);
	-- additional config registers if PhyOut isn't used and is in power down mode
	PhyX <= CFG_PHY0_PD when not(C_WO_PHY_OUT = 0 or C_SWAP_PHY = 0 or C_TUNNEL=2) else
			CFG_PHY1_PD when not(C_WO_PHY_OUT = 0 or C_SWAP_PHY = 1 or C_TUNNEL=2) else
			CFG_PHYX_NOP;
	-- note: fpga revision doesn't differentiate between assembly option without phy and assembly option with phy which is not used.
	-- So the pins o_PHY_MDC and b_PHY_MDIO are active, even if there is no phy assembled
	-- (because it's used to power down the phy if it is assembled...)
	
	MII_Di <= b_PHY_MDIO(0) and b_PHY_MDIO(1);
	o_PHY_MDC(0) <= MII_Clk;
	o_PHY_MDC(1) <= MII_Clk;
	
	o_MII_T <= MII_T;
	o_MII_Do <= MII_Do;
	
	Phy0_LEDgn			<= PhyIn_LEDgn		when C_SWAP_PHY=0 else PhyOut_LEDgn;
	Phy0_LEDyel			<= PhyIn_LEDyel		when C_SWAP_PHY=0 else PhyOut_LEDyel;
	Phy1_LEDgn			<= PhyOut_LEDgn		when C_SWAP_PHY=0 else PhyIn_LEDgn;
	Phy1_LEDyel			<= PhyOut_LEDyel	when C_SWAP_PHY=0 else PhyIn_LEDyel;
	PhyIn_linkState		<= linkState0		when C_SWAP_PHY=0 else linkState1;
	PhyOut_linkState	<= linkState1		when C_SWAP_PHY=0 else linkState0;
	
	-- if Phy1_LineDown, then bwGinxChanger (or Phy2 if swapped)
	-- new: xchange if PhyOut is deactivated (C_WO_PHY_OUT=1)
	bwGinxChanger <= not PhyOut_linkState when C_WO_PHY_OUT=0 else H;
	
	ledflasher : process (PhyOut_linkState, PhyIn_linkState, Flash_1100, Flash_0011,
						  fwGinFrm_LedDog, bwGinFrm_LedDog) begin
		if (PhyIn_linkState = L) then
			PhyIn_LEDgn   <= 	 Flash_1100;
			PhyIn_LEDyel  <=	 Flash_0011;
			PhyOut_LEDgn  <= 	 L;
			PhyOut_LEDyel <=	 L;
		else
			PhyIn_LEDgn <= H;
			if (fwGinFrm_LedDog = L) then
				PhyIn_LEDyel  <=	 L;
				PhyOut_LEDgn  <= 	 L;
				PhyOut_LEDyel <=	 L;
			else
				PhyIn_LEDyel <= H;
				if (PhyOut_linkState = L) then
					PhyOut_LEDgn  <= 	 L;
					PhyOut_LEDyel <=	 L;
				else
					if(C_WO_PHY_OUT=0) then
						PhyOut_LEDgn <= H;
					else
						PhyOut_LEDgn <= L;
					end if;
					if (bwGinFrm_LedDog = L) then
						PhyOut_LEDyel <=	 L;
					else
						PhyOut_LEDyel <=	 H;
					end if;
				end if;
			end if;
		end if;
		
		if (C_TUNNEL=2) then
			if (PhyOut_linkState = L) then
				PhyOut_LEDgn <= Flash_1010;
				PhyOut_LEDyel <= Flash_0101;
			else
				PhyOut_LEDgn <= Flash_1110;
				if (EthTx_LedDog = L) then
					PhyOut_LEDyel <= L;
				else
					PhyOut_LEDyel <= Flash_1110;
				end if;
			end if;
		end if;
	end process ledflasher;

--------------------------------------------------------------------------------
--	GinSalve instance
--------------------------------------------------------------------------------
	Gin_BRAM_EN <= H;

	uTop_GSlave: entity gin_slave.gs_wrap
	generic map (
		g64_n32BitRam	=> 0,
		gIs_C96Slave	=> 1,
		g_COPIMP		=> C_COPIMP,
		g_Tunnel		=> INDEL_pkg.INDEL_pkg.min(1,C_TUNNEL) -- 0 when C_TUNNEL=0 else 1
	)
	port map (
		i_Q62_5			=> clk62_5,
		i_Q125			=> clk125,
		i_xChanger		=> bwGinxChanger,
		o_PgIRQs		=> Gin_IRQs,
		o_PgWdogs		=> Gin_Wdogs,
		o_PgTlgSyn		=> Gin_TlgSyn,
		o_GF_Flags		=> GF_Flags,
		o_fwGMII_TxDat	=> Gin_fwGMII_TxDat,
		o_fwGMII_TxDv	=> Gin_fwGMII_TxDv,
		o_fwGMII_TxErr	=> Gin_fwGMII_TxErr,
		i_fwGMII_RxDat	=> Gin_fwGMII_RxDat,
		i_fwGMII_RxDv	=> Gin_fwGMII_RxDv,
		i_fwGMII_RxErr	=> Gin_fwGMII_RxErr,
		o_bwGMII_TxDat	=> Gin_bwGMII_TxDat,
		o_bwGMII_TxDv	=> Gin_bwGMII_TxDv,
		o_bwGMII_TxErr	=> Gin_bwGMII_TxErr,
		i_bwGMII_RxDat	=> Gin_bwGMII_RxDat,
		i_bwGMII_RxDv	=> Gin_bwGMII_RxDv,
		i_bwGMII_RxErr	=> Gin_bwGMII_RxErr,
		o_fwGinRun		=> fwGinRun,
		o_bwGinRun		=> bwGinRun,
		i_BRAM_Clk		=> clk125,
		i_BRAM_EN		=> Gin_BRAM_EN,
		i_BRAM_WEN		=> Gin_BRAM_WEN,
		i_BRAM_Addr		=> Gin_BRAM_Addr,
		i_BRAM_Dout		=> Gin_BRAM_Dout,
		o_BRAM_Din		=> Gin_BRAM_Din,
		i_linkState0	=> PhyIn_linkState,
		i_linkState1	=> PhyOut_linkState,
		i_Mac2Tun_D		=> Mac2Tun_D	,
		i_Mac2Tun_Req	=> Mac2Tun_Req	,
		o_Mac2Tun_En	=> Mac2Tun_En	,
		o_Mac2Tun_Req_ack=> Mac2Tun_Req_ack	,
		o_Tun2Mac_D		=> Tun2Mac_D	,
		o_Tun2Mac_Dv	=> Tun2Mac_Dv
	);
	
	tt: if C_TUNNEL/=0 generate
	begin
	
		uTunnel2GMII: entity gin_eth.GE_Tunnel2GMII
		port map (
			i_Q125			=> clk125	,
			i_Q62_5			=> clk62_5	,
			i_GMII_RX_Data_Valid_EN	=> i_GinETH_data_en	,
			i_GMII_TX_CLK_EN		=> i_GinETH_clk_en	,
			
			o_GMII_TxDat	=> o_GinETH_TxDat	,	
			o_GMII_TxDv		=> o_GinETH_TxDv	,	
			o_GMII_TxErr	=> o_GinETH_TxErr	,	

			i_GMII_RxDat	=> i_GinETH_RxDat	,
			i_GMII_RxDv		=> i_GinETH_RxDv	,
			i_GMII_RxErr	=> i_GinETH_RxErr	,
			
			o_Mac2Tun_D		=> Mac2Tun_D	,
			o_Mac2Tun_Req	=> Mac2Tun_Req	,
			i_Mac2Tun_En	=> Mac2Tun_En	,
			i_Mac2Tun_Req_ack => Mac2Tun_Req_ack,
			i_Tun2Mac_D		=> Tun2Mac_D	,
			i_Tun2Mac_Dv	=> Tun2Mac_Dv
		);

		uWrap_EthLdog: entity gin_link.Gin_WatchDog_800ms
		port map (
			i_Q62_5			=> clk62_5		,
			i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
			i_Probe			=> Tun2Mac_Dv	,
			o_Wdog			=> EthTx_LedDog
		);
		
	end generate tt;

	Bus_TlgSyn <= Gin_TlgSyn;
--------------------------------------------------------------------------------
--	GinLink WatchDogs
--------------------------------------------------------------------------------

	uWrap_bwGinLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5      ,
		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
		i_Probe			=> bwGinRun 	, 	-- bwGinFrames ?
		o_Wdog			=> bwGinFrm_LedDog
	);

	uWrap_fwGinLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5      ,
		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
		i_Probe			=> fwGinRun 	, 	-- bwGinFrames ?
		o_Wdog			=> fwGinFrm_LedDog
	);

--------------------------------------------------------------------------------
--	main Led-Flasher
--------------------------------------------------------------------------------
	uGin_LED_Flasher : entity gin_link.Gin_LED_Flasher
	port map (
		i_Q62_5			=> clk62_5      ,
		i_SynchFlash	=> GF_Flags(8)	,	--GinFrame Flag 8 = BlinkBit

		o_Flash_1000	=> Flash_1000  ,
		o_Flash_0100    => Flash_0100  ,
		o_Flash_0010    => Flash_0010  ,
		o_Flash_0001    => Flash_0001
	);

	Flash_1100 <= Flash_1000 or Flash_0100;
	Flash_0011 <= not Flash_1100;
	Flash_0101 <= not Flash_1010; 
	Flash_1010 <= Flash_1000 or Flash_0010; 
	Flash_1110 <= Flash_1000 or Flash_0100 or Flash_0010;
	

--******************************************************************************
--
--		C64 Master
--
--******************************************************************************
	uWrap_C64MasSeq: entity C64_Master.C64_MasSeq
	generic map (
		g_Extern_Q25	=> 0					,
		-- patch to change eeprom address 
		g_patch_ee_addr	=> C_PATCH_EE_ADDR	,
		g_patch_addr_f	=> C_PATCH_ADDR_F	,
		g_patch_addr_t	=> C_PATCH_ADDR_T
	)
	port map (
		i_Q125 			=> clk125			,
		--i_Q25 			=> clk25				, --g_Extern_Q25=1
		i_TlgIrq		=> Bus_TlgSyn		,
		i_MEM_RdData	=> Gin_BRAM_Din		,
		o_MEM_WrData	=> Gin_BRAM_Dout	,
		o_MEM_ByteAddr	=> BRAM_ByteAddr	,
		o_MEM_WR		=> Gin_BRAM_WEN		,
		-- C64-Bus
		o_C64_Reset		=> C64_Reset		,
		o_C64_CLK		=> C64_CLK			,
		o_C64_CLK_EN	=> C64_CLK_EN		,
		o_C64_SEL		=> C64_SEL			,
		o_C64_Dat_HOE	=> C64_Dat_HOE		,
		o_C64_Dat_LOE	=> C64_Dat_LOE		,
		o_C64_Ack_OE	=> C64_Ack_OE		, -- not important for internal use only
		o_C64_Bend		=> C64_Bend			,
		o_C64_WrDat		=> C64_WrDat		,
		i_C64_RdDat		=> C64_RdDat		,
		i_C64_Ack_Int	=> C64_Ack			,
		i_C64_Ack_Ext	=> L				,
		o_C64_I2C_SCL	=> C64_I2C_SCL		, -- "external" (internal slave)
		o_C64_I2C_SDA	=> C64_I2C_SDA		,
		i_C64_I2C_SDA	=> b_SlvInt_SDA		,
		o_C96_I2C_SCL	=> C96_I2C_SCL		, -- internal (GIN-TTL)
		o_C96_I2C_SDA	=> C96_I2C_SDA		,
		i_C96_I2C_SDA	=> b_SDA		
	);
	
	
	
--------------------------------------------------------------------------------
-- generating bidirektional inout for I2C (EEPROM bus)
--------------------------------------------------------------------------------	

int_tristate: if (C_I2C_TRSBUF = 0) generate
begin
	o_SCL <= C96_I2C_SCL;
	o_SDA <= C96_I2C_SDA;
end generate int_tristate;

ext_tristate: if (C_I2C_TRSBUF = 1) generate
begin
	b_SCL <= Z when C96_I2C_SCL=H else L;
	b_SDA <= Z when C96_I2C_SDA=H else L;
end generate ext_tristate;

	
	b_SlvInt_SCL <= Z when C64_I2C_SCL=H else L;
	b_SlvInt_SDA <= Z when C64_I2C_SDA=H else L;
	
	-- convert ByteAddr to 32Bit-Addr 
	-- ByteAddr(15) will maybe later used as IMP-Bus Ram select
	Gin_BRAM_Addr(14) <= L;
	Gin_BRAM_Addr(15) <= L;
	Gin_BRAM_Addr(13 downto 0) <= BRAM_ByteAddr(15 downto 2);

--------------------------------------------------------------------------------
--	switch extern/intern C64 access
--------------------------------------------------------------------------------
	process (Slv9_C64_Ack_OE,i_SlvInt_Ack_OE) begin
		-- local C64_Slave access?                
		if (Slv9_C64_Ack_OE = H)
		or (i_SlvInt_Ack_OE = H and C_EMG_SYS=0) then 
			C64_Ack <= H;
		else
			C64_Ack <= L;
		end if;	
	end process;

	process (Slv9_C64_Dat_HOE,Slv9_C64_Dat_LOE,Slv9_C64_WrDat,
			 i_SlvInt_Dat_HOE,i_SlvInt_Dat_LOE,i_SlvInt_Slv2Mas) begin
		-- local C64_Slave access?                
		if (Slv9_C64_Dat_HOE = H) then 
			C64_RdDat(15 downto 8) <= Slv9_C64_WrDat(15 downto 8);
		elsif (i_SlvInt_Dat_HOE = H) then
			C64_RdDat(15 downto 8) <= i_SlvInt_Slv2Mas(15 downto 8);
		else
			C64_RdDat(15 downto 8) <= (others => L);
		end if;	

		-- local C64_Slave access?                
		if (Slv9_C64_Dat_LOE = H) then 
			C64_RdDat(7 downto 0) <= Slv9_C64_WrDat(7 downto 0);
		elsif (i_SlvInt_Dat_LOE = H) then
			C64_RdDat(7 downto 0) <= i_SlvInt_Slv2Mas(7 downto 0);
		else
			C64_RdDat(7 downto 0) <= (others => L);
		end if;	
	end process;
	
	o_SlvInt_Mas2Slv 	<= C64_WrDat;
	o_SlvInt_Reset		<= C64_Reset;
	o_SlvInt_CLK_notfornewdesigns <= C64_CLK;
	o_SlvInt_SEL		<= C64_SEL;
	o_SlvInt_Bend		<= C64_Bend;
	
	o_SlvInt_CLK125	<= clk125;
	o_SlvInt_CLK_EN	<= C64_CLK_EN;
	
--******************************************************************************
--
--	local, inernal	C64-Slave
--
--******************************************************************************
--	there is always a local C64-Slave in every Gin-Passive Master 
--
--	we need it also to access the local C96-JTAG-port
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	Ok-LED 		(GinFrame_Flags(8) = globales Bink-Bit) 
--	Err-LED 	
--------------------------------------------------------------------------------
	process(Slv_GF_Flags,Card_Wr_Status) begin
		if C_EMG_SYS=0 then
			case (Card_Wr_Status( 9 downto  8)) is
			--------------------------------------------------------------------
			when "00" =>	nErrorLED <= not L;
			when "01" =>    nErrorLED <= not Slv_GF_Flags(8);
			when "10" =>    nErrorLED <=     Slv_GF_Flags(8);
			when "11" =>    nErrorLED <= not H;
			--------------------------------------------------------------------
			when others => null;
			end case;
			--------------------------------------------------------------------
		else 
			-- emg sys: fix on
			nErrorLED <= L;
		end if;
	end process;

--------------------------------------------------------------------------------
--
--	Card Status Rd/Wr
--
--------------------------------------------------------------------------------
	-- live-bits and read-back bits
	-- Card_Wr_Status(15): EEprom
	-- Card_Wr_Status(14): slave internal
	-- Card_Wr_Status(13..12): okLed state
	-- Card_Wr_Status will be cleared after i_C64_Reset
	Card_Rd_Status <= Card_Wr_Status(11 downto 8) & AddrSw;
	
	HWRev <= not ni_HWRev;

--------------------------------------------------------------------------------
--	Read	Inp, Status
--------------------------------------------------------------------------------
	process(Slv_Addr, Slv_RdEn, Card_Rd_Status) begin  
		Slv_RdData <= x"CCCC";
		if (Slv_RdEn=H) then 
			--------------------------------------------------------------------
			case Slv_Addr is
			when cfg_TestMode =>
				if DF_TESTMODE=1 then
					Slv_RdData <= Slv9_Testmode;
				end if;
			when others => null;
			end case;
			--------------------------------------------------------------------
		end if;
	end process;

--------------------------------------------------------------------------------
--	Write	Outputs 
--------------------------------------------------------------------------------
	process(C64_Reset,clk125) begin
		-- global Reset 
		if (C64_Reset = H) then
			-- clear LEDs 
			
			-- clear all outputs
		elsif rising_edge(clk125) then
			if (C64_CLK_EN = '1') then
				AddrSw <= "0000" & i_AddrSw;
				if (Slv_WrEn=H) then 
					------------------------------------------------------------
					case Slv_Addr is
					when cfg_TestMode => 
						if DF_TESTMODE=1 then
							Slv9_Testmode <= Slv_WrData;
						end if;
					when others => null;
					end case;
					------------------------------------------------------------
			end if;
		end if;
		end if;
	end process;
	
--------------------------------------------------------------------------------
--	C64 BusSlave instance
--------------------------------------------------------------------------------

	uC64_SlaveSeq: entity C64_Slave.C64_SlaveSeq
	generic map (
		g_App_Rev		=> g_SlaveApp_Rev	,
		g_TrstBuf		=> 0				,
		g_SPI_TrstBuf	=> C_SPI_TRSTBUF	,
		-- clock the slave with the same global clock like the C64-Master
		g_m_sync_clk	=> 1				,
		g_IntNExt		=> 1
	)
	port map (
		-- internal Slave fix in Module_9 !!!
		 i_AddrSw		=> x"9"				,
		-- C64-Bus
		 i_C64_Reset	=> C64_Reset		,
		 i_C64_SEL		=> C64_SEL          ,
		 i_C64_Bend		=> C64_Bend         ,
		-- g_m_sync_clk=0
		 i_clk25		=> L				,
		-- synchronous clocking for internal slaves g_m_sync_clk=1
		 i_CLK125		=> CLK125			,
		 i_C64_CLK_EN	=> C64_CLK_EN		,
		i_C64_DatBus	=> C64_WrDat	    ,
		o_C64_DatBus	=> Slv9_C64_WrDat   ,
		o_C64_Dat_HOE	=> Slv9_C64_Dat_HOE ,
		o_C64_Dat_LOE	=> Slv9_C64_Dat_LOE ,
		o_C64_Ack_OE	=> Slv9_C64_Ack_OE  ,
		-- JTAG Pins
		 o_JTAG_TCK		=> o_jtagTCK		,
		 o_JTAG_TMS		=> o_jtagTMS		,
		 o_JTAG_TDI		=> o_jtagTDI		,
		 i_JTAG_TDO		=> i_jtagTDO			,
		-- SPI Pin
		 o_SPI_CLK		=>  o_SPI_CLK		,
		no_SPI_CS		=> no_SPI_CS		,
		 o_SPI_D		=>  o_SPI_D			,
		 i_SPI_Q		=>  i_SPI_Q			,
		 o_SPI_OE		=>  o_SPI_OE		,
		-- local application Rd/Wr 
		 o_Addr			=> Slv_Addr			,
		 i_RdData		=> Slv_RdData		,
		 o_WrData		=> Slv_WrData		,
		 o_WrEn			=> Slv_WrEn			,
		 o_RdEn			=> Slv_RdEn			,
		 -- status
		 i_Card_Status	=> Card_Rd_Status	,
		 o_Card_Status	=> Card_Wr_Status	,
		-- GinFrams_Flags		
		 o_GF_Flags		=> Slv_GF_Flags		,
		no_EEP_Wen		=> no_EEP_Wen		,
		no_OkLED		=> nOkLED			,
		 i_HWRev		=> HWRev
	);

end architecture STRUCTURE;
