--------------------------------------------------------------------------------
--	cop_mas2_module.vhd
--------------------------------------------------------------------------------
--
--	project     : cop_mas2
--	programmer  : C. Leuthold, INDEL AG
--	date        : 29.08.2013
--	language    : VHDL
--
--	purpose
--	basemodule for cop_mas2 board.
--	HPS Pins
--	Extern CopBus
--	Intern CopBus
--	2 RGMII for GinLink (master or slave) and Ethernet
--------------------------------------------------------------------------------
-- revision information
--	29.08.2013-le	: - first steps
--	20.11.2013-le	: - update to quartus 13.1
--	10.04.2014-le	: - add generic to distinguish SEA4 and SEA2
--	28.04.2014-le	: - add JTAG pins of 9er slave
--	16.05.2014-le	: - 8k/3portram: adjustments ans support for cop-mas2
--	04.08.2014-le	: - update to Quartus 14.0
--					  - UART1: rs422 support
--					  - add subtype
--	02.10.2014-le	: - support 2 Ethernets instant of ginlink
--	03.02.2015-le	: - uart1 tx: wrong on RevA (Prt SXC6), configure as input
--	17.02.2015-le	: - Support Memory controller for COP-HIL
--					  - cop_mas2_arm: bram_if add waitrequest Output
--					  - cop_mas2_arm: correct irq connection in qsys, remove irq_if
--	29.06.2015-le	: - add ports and generics for crc check
--	26.05.2016-le	: - cop master: add a second irq with own mask and timer for fast irq
--	27.06.2016-le	: - cop_master: hold C64_WrDat for a clk, intern C64_Dat_HOE is faster then extern oe!
--	06.09.2016-le	: - ginslave: support ginlink diagnostic
--	22.12.2016-le	: - cop_master: need generic C_GIN_MASTERnSLAVE together with C_ENABLE_3PORT_MASTER=1
--	13.02.2018-le	: - support tunneling Ethernetframes from/to ginlink
--	25.06.2019-vz	: - add generic to patch eeprom address
--	25.06.2019-le	: - cop_master: enable Memory read register, switchable over 
--						generic g_MEM_RdD_REG on top
--	10.12.2019-le	: - use registers address definition from INDEL_pkg
--	10.06.2020-vz	: - all i2c tristate buffers removed, these should always be created on top-level
--	12.06.2020-vz	: - add handshake signal to/from C64_EEPROMER to share i2c bus with another i2c master
--						used in cv_sodimm_max4x10
--	08.02.2021-vz	: - added support for pwm fan output, set C_PWMFAN=1 if the board has a fan like imp-mas3.
--						added SCL and SDA in Flags for I2C GPIO mode (only available if C_BRAMIF_nCOPBUS=1)
--	10.02.2021-vz	: - added support for info-link and imp-bus used in imp-mas3. By now the instances of
--						the info and imp sequencer is in the project imp_mas3.vhd file.
--
--------------------------------------------------------------------------------
--$Rev:: 5784                                                                  $
--$Author:: Zuellig                                                            $
--$Date:: 2021-02-10 13:28:28 +0100 (Mi., 10 Feb 2021)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.std_logic_unsigned.ALL;

library pll;
use pll.ALL;

library RGMII_if;
use RGMII_if.ALL;

library gin_slave;
use gin_slave.ALL;

library gin_link;
use gin_link.ALL;
use gin_link.PCK_CRC32_D8.all;

library gin_master;
use gin_master.ALL;

library gin_eth;
use gin_eth.ALL;

library C64_Master;
use C64_Master.All;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity cop_mas2_module is
	generic (
		C_TARGET				: integer range 0 to 15;
		C_TARGET_SUBTYPE		: integer range 0 to 15 := 0;
		C_GIN_MASTERnSLAVE		: integer range 0 to 1 := 0;
		C_FPGA_SEA2				: integer range 0 to 1 := 0;
		C_REVISION				: std_logic_vector(11 downto 0) := x"100";
		C_SVN_REV_TOP			: std_logic_vector(15 downto 0) := x"0000";
		C_DEV_BUILD				: integer := 12;-- 0 for releases
		C_BRAMIF_nCOPBUS		: integer range 0 to 1 := 0;
		C_SPIM0					: integer range 0 to 1 := 1;
		C_PWMFAN				: integer range 0 to 1 := 0;
		DF_TESTMODE				: integer range 0 to 1 := 0;
		C_EMG_SYS				: integer range 0 to 1 := 0;
		C_ENABLE_3PORT_MASTER	: in natural range 0 to 1 := 0;
		C_DUAL_ETH				: integer range 0 to 1 := 0;
		C_ENABLE_COP_HIL		: in natural range 0 to 1 := 0;
		-- patch to change eeprom address 
		g_patch_ee_addr			: in integer range 0 to 1 := 0;
		g_patch_addr_f			: in std_logic_vector(3 downto 0) := x"0"; -- from
		g_patch_addr_t			: in std_logic_vector(3 downto 0) := x"0"; -- to
		g_CRCChecker			: in integer range 0 to 1 := 0;
		C_TUNNEL				: in integer range 0 to 1 := 0
	);
	port (
		-- HPS Pins ------------------------------------------------------------
		hps_memory_mem_a         : out   std_logic_vector(14 downto 0);                   -- memory.mem_a
		hps_memory_mem_ba        : out   std_logic_vector(2 downto 0);                    --       .mem_ba
		hps_memory_mem_ck        : out   std_logic;                                       --       .mem_ck
		hps_memory_mem_ck_n      : out   std_logic;                                       --       .mem_ck_n
		hps_memory_mem_cke       : out   std_logic;                                       --       .mem_cke
		hps_memory_mem_cs_n      : out   std_logic;                                       --       .mem_cs_n
		hps_memory_mem_ras_n     : out   std_logic;                                       --       .mem_ras_n
		hps_memory_mem_cas_n     : out   std_logic;                                       --       .mem_cas_n
		hps_memory_mem_we_n      : out   std_logic;                                       --       .mem_we_n
		hps_memory_mem_reset_n   : out   std_logic;                                       --       .mem_reset_n
		hps_memory_mem_dq        : inout std_logic_vector(31 downto 0) := (others => '0');--       .mem_dq
		hps_memory_mem_dqs       : inout std_logic_vector(3 downto 0)  := (others => '0');--       .mem_dqs
		hps_memory_mem_dqs_n     : inout std_logic_vector(3 downto 0)  := (others => '0');--       .mem_dqs_n
		hps_memory_mem_odt       : out   std_logic;                                       --       .mem_odt
		hps_memory_mem_dm        : out   std_logic_vector(3 downto 0);                    --       .mem_dm
		hps_memory_oct_rzqin     : in    std_logic                     := '0';            --       .oct_rzqin
		hps_qspi_IO0             : inout std_logic                     := '0';            -- hps_io.hps_io_qspi_inst_IO0
		hps_qspi_IO1             : inout std_logic                     := '0';            --       .hps_io_qspi_inst_IO1
		hps_qspi_IO2             : inout std_logic                     := '0';            --       .hps_io_qspi_inst_IO2
		hps_qspi_IO3             : inout std_logic                     := '0';            --       .hps_io_qspi_inst_IO3
		hps_qspi_SS0             : out   std_logic;                                       --       .hps_io_qspi_inst_SS0
		hps_qspi_SS1             : out   std_logic;                                       --       .hps_io_qspi_inst_SS1
		hps_qspi_CLK             : out   std_logic;                                       --       .hps_io_qspi_inst_CLK
		hps_sdio_CMD             : inout std_logic                     := '0';            --       .hps_io_sdio_inst_CMD
		hps_sdio_D0              : inout std_logic                     := '0';            --       .hps_io_sdio_inst_D0
		hps_sdio_D1              : inout std_logic                     := '0';            --       .hps_io_sdio_inst_D1
		hps_sdio_CLK             : out   std_logic;                                       --       .hps_io_sdio_inst_CLK
		hps_sdio_D2              : inout std_logic                     := '0';            --       .hps_io_sdio_inst_D2
		hps_sdio_D3              : inout std_logic                     := '0';            --       .hps_io_sdio_inst_D3
		hps_uart0_RX             : in    std_logic                     := '0';            --       .hps_io_uart0_inst_RX
		hps_uart0_TX             : out   std_logic;                                       --       .hps_io_uart0_inst_TX
		hps_uart1_RX             : inout std_logic                     := '0';            --       .hps_io_uart1_inst_RX
		hps_uart1_TX             : inout std_logic                     := '0';            --       .hps_io_uart1_inst_TX
		hps_i2c0_SDA             : inout std_logic                     := '0';            --       .hps_io_i2c0_inst_SDA
		hps_i2c0_SCL             : inout std_logic                     := '0';            --       .hps_io_i2c0_inst_SCL
		hps_can0_RX              : in    std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO17
		hps_can0_TX              : out   std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO18
		hps_gpio_GPIO00          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO19
		hps_gpio_GPIO01          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO20
		hps_gpio_GPIO02          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO21
		hps_gpio_GPIO03          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO22
		hps_gpio_GPIO04          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO23
		hps_gpio_GPIO05          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO24
		hps_gpio_GPIO06          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO25
		hps_gpio_GPIO07          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO26
		hps_gpio_GPIO08          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO48
		hps_gpio_GPIO09          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO49
		hps_gpio_GPIO10          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO50
		hps_gpio_GPIO11          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO51
		hps_gpio_GPIO12          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO52
		hps_gpio_GPIO13          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO53
		hps_gpio_GPIO14          : inout std_logic                     := '0';            --       .hps_io_gpio_inst_GPIO54
		hps_gpio_GPIO15          : inout std_logic                     := '0';
		hps_gpio_GPIO16          : inout std_logic                     := '0';
		hps_gpio_GPIO17          : inout std_logic                     := '0';
		hps_gpio_GPIO18          : inout std_logic                     := '0';
		hps_gpio_GPIO19          : inout std_logic                     := '0';
		hps_gpio_GPIO20          : inout std_logic                     := '0';
		hps_gpio_GPIO21          : inout std_logic                     := '0';
		hps_gpio_GPIO22          : inout std_logic                     := '0';
		hps_gpio_GPIO23          : inout std_logic                     := '0';
		hps_gpio_GPIO24          : inout std_logic                     := '0';
		hps_gpio_GPIO25          : inout std_logic                     := '0';
		hps_gpio_GPIO26          : inout std_logic                     := '0';
		hps_gpio_GPIO27          : inout std_logic                     := '0';
		hps_gpio_GPIO28          : inout std_logic                     := '0';
		hps_gpio_GPIO37          : inout std_logic                     := '0';
		hps_gpio_GPIO40          : inout std_logic                     := '0';
		hps_gpio_GPIO41          : inout std_logic                     := '0';
		hps_gpio_GPIO42          : inout std_logic                     := '0';
		hps_gpio_GPIO43          : inout std_logic                     := '0';
		hps_gpio_GPIO44          : inout std_logic                     := '0';
		hps_gpio_GPIO48          : inout std_logic                     := '0';
		hps_gpio_GPIO49          : inout std_logic                     := '0';
		hps_gpio_GPIO50          : inout std_logic                     := '0';
		hps_gpio_GPIO51          : inout std_logic                     := '0';
		hps_gpio_GPIO52          : inout std_logic                     := '0';
		hps_gpio_GPIO53          : inout std_logic                     := '0';
		hps_gpio_GPIO54          : inout std_logic                     := '0';
		hps_gpio_GPIO57          : inout std_logic                     := '0';
		hps_gpio_GPIO58          : inout std_logic                     := '0';
		hps_gpio_GPIO59          : inout std_logic                     := '0';
		hps_gpio_GPIO60          : inout std_logic                     := '0';
		-- FPGA Pins -----------------------------------------------------------
		i_FPGA_clk25			: in	std_logic;
		o_clk125				: out	std_logic;
		o_clk62_5				: out	std_logic;
		o_clk25					: out	std_logic;
		o_Bus_WDog_Gin_3		: out	std_logic;
		o_periph_rst			: out	std_logic;
		-- Ethernet ------------------------------------------------------------
		no_PHY_RESET	: out std_logic;
		i_PHY_RXC0		: in std_logic;
		o_PHY_TXD0		: out std_logic_vector(3 downto 0);
		o_PHY_TXEN0		: out std_logic;
		i_PHY_RXD0		: in std_logic_vector(3 downto 0);
		i_PHY_RXDV0		: in std_logic;
		o_PHY_GTXCLK0	: out std_logic;
		i_PHY_RXC1		: in std_logic;
		o_PHY_TXD1		: out std_logic_vector(3 downto 0);
		o_PHY_TXEN1		: out std_logic;
		i_PHY_RXD1		: in std_logic_vector(3 downto 0);
		i_PHY_RXDV1		: in std_logic;
		o_PHY_GTXCLK1	: out std_logic;
		o_PHY_MDC		: out std_logic_vector(1 downto 0);
		b_PHY_MDIO		: inout std_logic_vector(1 downto 0);
		-- either bram or copbus depending on C_BRAMIF_nCOPBUS
		o_BRAM_Clk		: out std_logic;
		o_BRAM_EN 		: out std_logic;
		o_BRAM_Addr 	: out std_logic_vector(21 downto 0);
		o_BRAM_WEN 		: out std_logic_vector( 3 downto 0);
		o_BRAM_Dp2r 	: out std_logic_vector(31 downto 0);
		i_BRAM_Dr2p		: in std_logic_vector(31 downto 0) := (others => L);
		-- infolink and impbus flags
		i_IbIlsFlags	: in	std_logic_vector(31 downto 0) := (others => L);
		i_IlmFlags		: in	std_logic_vector(31 downto 0) := (others => L);
		o_IbIlsFlags	: out	std_logic_vector(31 downto 0);
		o_IlmFlags		: out	std_logic_vector(31 downto 0);
		o_il_reg_sync	: out	std_logic;
		i_il_reg_done	: in	std_logic := L;
		i_il_IRQs		: in	std_logic_vector(2 downto 0) := (others => L);	--! InfoIRQs
		i_ib_IRQs		: in	std_logic_vector(1 downto 0) := (others => L);	--! IMPIRQs
		-- COP-BUS intern ------------------------------------------------------
		i_SlvInt_Ack_OE		: in std_logic := L;
		i_SlvInt_Slv2Mas	: in std_logic_vector(15 downto 0) := (others => L);
		i_SlvInt_Dat_HOE	: in std_logic := L;
		i_SlvInt_Dat_LOE	: in std_logic := L;
		o_SlvInt_Mas2Slv	: out std_logic_vector(15 downto 0);
		o_SlvInt_Reset		: out std_logic;
		o_SlvInt_CLKen		: out std_logic;
		o_SlvInt_SEL		: out std_logic;
		o_SlvInt_Bend		: out std_logic;
		-- COP-BUS extern ------------------------------------------------------
		o_C64_Reset		: out	std_logic;
		o_C64_CLK		: out	std_logic;
		no_C64_CLK		: out	std_logic;
		o_C64_SEL		: out	std_logic;
		o_C64_Bend		: out	std_logic;
		b_C64_Data		: inout	std_logic_vector(15 downto 0) := (others => L);
		nb_C64_Ack		: inout	std_logic := H;
		o_C64_RES		: out	std_logic;
		o_C64_I2C_SCL	: out	std_logic;
		i_C64_I2C_SDA	: in	std_logic := H;
		o_C64_I2C_SDA	: out	std_logic;
		o_C96_I2C_SCL	: out	std_logic;
		i_C96_I2C_SDA	: in	std_logic := H;
		o_C96_I2C_SDA	: out	std_logic;
		i_eep_i2c_acpt	: in	std_logic := H;
		o_eep_i2c_req	: out	std_logic;
		i_TestModeOE	: in 	std_logic := L;
		i_HWRev			: in 	std_logic_vector(3 downto 0);
		i_AddrSw		: in 	std_logic_vector(3 downto 0);
		i_FAN_Tacho		: in	std_logic := H;
		no_FAN_PWM		: out	std_logic;
		b_lv_GS			: inout std_logic_vector(3 downto 0);
		b_mram_clk		: inout std_logic;
		b_mram_cs		: inout std_logic;
		b_mram_si		: inout std_logic;
		b_mram_so		: inout std_logic;
		b_jtagTCK		: inout	std_logic := L;
		b_jtagTMS		: inout	std_logic := L;
		b_jtagTDI		: inout	std_logic := L;
		b_jtagTDO		: inout	std_logic := L;
		i_fpga_uart1_RX	: in 	std_logic := L;
		o_fpga_uart1_TX	: out 	std_logic;
		b_hilDA			: inout std_logic_vector(15 downto 0) := (others => L);
		ni_hilBusy		: in 	std_logic := L;
		o_hilWnR		: out	std_logic;
		no_hilRes		: out	std_logic;
		no_hilCs		: out	std_logic;
		no_hilAl		: out	std_logic;
		o_AddrWrite		: out	std_logic;
		o_sameaddr		: out	std_logic
	);
end entity cop_mas2_module;

architecture rtl of cop_mas2_module is

	component cop_mas2_arm is
		port (
			hps_io_qspi_inst_IO0_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_qspi_inst_IO0
			hps_io_qspi_inst_IO1_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_qspi_inst_IO1
			hps_io_qspi_inst_IO2_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_qspi_inst_IO2
			hps_io_qspi_inst_IO3_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_qspi_inst_IO3
			hps_io_qspi_inst_SS0_from_the_hps_0           : out   std_logic;                                        -- hps_io_qspi_inst_SS0
			hps_0_hps_io_hps_io_qspi_inst_SS1            : out   std_logic;                                        -- hps_io_qspi_inst_SS1
			hps_io_qspi_inst_CLK_from_the_hps_0           : out   std_logic;                                        -- hps_io_qspi_inst_CLK
			hps_io_sdio_inst_CMD_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_sdio_inst_CMD
			hps_io_sdio_inst_D0_to_and_from_the_hps_0     : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D0
			hps_io_sdio_inst_D1_to_and_from_the_hps_0     : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D1
			hps_io_sdio_inst_CLK_from_the_hps_0           : out   std_logic;                                        -- hps_io_sdio_inst_CLK
			hps_io_sdio_inst_D2_to_and_from_the_hps_0     : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D2
			hps_io_sdio_inst_D3_to_and_from_the_hps_0     : inout std_logic                     := 'X';             -- hps_io_sdio_inst_D3
			hps_io_uart0_inst_RX_to_the_hps_0             : in    std_logic                     := 'X';             -- hps_io_uart0_inst_RX
			hps_io_uart0_inst_TX_from_the_hps_0           : out   std_logic;                                        -- hps_io_uart0_inst_TX
			hps_io_i2c0_inst_SDA_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_i2c0_inst_SDA
			hps_io_i2c0_inst_SCL_to_and_from_the_hps_0    : inout std_logic                     := 'X';             -- hps_io_i2c0_inst_SCL
			hps_0_hps_io_hps_io_can0_inst_RX              : in    std_logic                     := 'X';             -- hps_io_can0_inst_RX
			hps_0_hps_io_hps_io_can0_inst_TX            : out   std_logic;                                        -- hps_io_can0_inst_TX
			hps_io_gpio_inst_GPIO00_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO00
			hps_io_gpio_inst_GPIO01_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO01
			hps_io_gpio_inst_GPIO02_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO02
			hps_io_gpio_inst_GPIO03_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO03
			hps_io_gpio_inst_GPIO04_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO04
			hps_io_gpio_inst_GPIO05_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO05
			hps_io_gpio_inst_GPIO06_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO06
			hps_io_gpio_inst_GPIO07_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO07
			hps_io_gpio_inst_GPIO08_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO08
			hps_io_gpio_inst_GPIO09_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO09
			hps_io_gpio_inst_GPIO10_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO10
			hps_io_gpio_inst_GPIO11_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO11
			hps_io_gpio_inst_GPIO12_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO12
			hps_io_gpio_inst_GPIO13_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO13
			hps_io_gpio_inst_GPIO14_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO14
			hps_io_gpio_inst_GPIO15_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO15
			hps_io_gpio_inst_GPIO16_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO16
			hps_io_gpio_inst_GPIO17_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO17
			hps_io_gpio_inst_GPIO18_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO18
			hps_io_gpio_inst_GPIO19_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO19
			hps_io_gpio_inst_GPIO20_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO20
			hps_io_gpio_inst_GPIO21_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO21
			hps_io_gpio_inst_GPIO22_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO22
			hps_io_gpio_inst_GPIO23_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO23
			hps_io_gpio_inst_GPIO24_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO24
			hps_io_gpio_inst_GPIO25_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO25
			hps_io_gpio_inst_GPIO26_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO26
			hps_io_gpio_inst_GPIO27_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO27
			hps_io_gpio_inst_GPIO28_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO28
			hps_io_gpio_inst_GPIO37_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO37
			hps_io_gpio_inst_GPIO40_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO40
			hps_io_gpio_inst_GPIO41_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO41
			hps_io_gpio_inst_GPIO42_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO42
			hps_io_gpio_inst_GPIO43_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO43
			hps_io_gpio_inst_GPIO44_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO44
			hps_io_gpio_inst_GPIO48_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO48
			hps_io_gpio_inst_GPIO49_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO49
			hps_io_gpio_inst_GPIO50_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO50
			hps_io_gpio_inst_GPIO51_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO51
			hps_io_gpio_inst_GPIO52_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO52
			hps_io_gpio_inst_GPIO53_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO53
			hps_io_gpio_inst_GPIO54_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO54
			hps_io_gpio_inst_GPIO57_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO57
			hps_io_gpio_inst_GPIO58_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO58
			hps_io_gpio_inst_GPIO59_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO59
			hps_io_gpio_inst_GPIO60_to_and_from_the_hps_0 : inout std_logic                     := 'X';             -- hps_io_gpio_inst_GPIO60
			hps_0_hps_io_hps_io_gpio_inst_LOANIO63        : inout std_logic                     := '0';             --                     .hps_io_gpio_inst_LOANIO63
			hps_0_hps_io_hps_io_gpio_inst_LOANIO64        : inout std_logic                     := '0';             --                     .hps_io_gpio_inst_LOANIO64
			mem_a_from_the_hps_0                          : out   std_logic_vector(14 downto 0);                    -- mem_a
			mem_ba_from_the_hps_0                         : out   std_logic_vector(2 downto 0);                     -- mem_ba
			mem_ck_from_the_hps_0                         : out   std_logic;                                        -- mem_ck
			mem_ck_n_from_the_hps_0                       : out   std_logic;                                        -- mem_ck_n
			mem_cke_from_the_hps_0                        : out   std_logic;                                        -- mem_cke
			mem_cs_n_from_the_hps_0                       : out   std_logic;                                        -- mem_cs_n
			mem_ras_n_from_the_hps_0                      : out   std_logic;                                        -- mem_ras_n
			mem_cas_n_from_the_hps_0                      : out   std_logic;                                        -- mem_cas_n
			mem_we_n_from_the_hps_0                       : out   std_logic;                                        -- mem_we_n
			mem_reset_n_from_the_hps_0                    : out   std_logic;                                        -- mem_reset_n
			mem_dq_to_and_from_the_hps_0                  : inout std_logic_vector(31 downto 0) := (others => 'X'); -- mem_dq
			mem_dqs_to_and_from_the_hps_0                 : inout std_logic_vector(3 downto 0)  := (others => 'X'); -- mem_dqs
			mem_dqs_n_to_and_from_the_hps_0               : inout std_logic_vector(3 downto 0)  := (others => 'X'); -- mem_dqs_n
			mem_odt_from_the_hps_0                        : out   std_logic;                                        -- mem_odt
			mem_dm_from_the_hps_0                         : out   std_logic_vector(3 downto 0);                     -- mem_dm
			oct_rzqin_to_the_hps_0                        : in    std_logic                     := 'X';             -- oct_rzqin
			clk_axi                                       : in    std_logic                     := 'X';             -- clk
			h2f_reset_reset_n                             : out   std_logic;                                        -- reset_n
			reset_n                                       : in    std_logic                     := 'H';             -- reset_n
			bram_if_0_s0_address                          : out   std_logic_vector(21 downto 0);                    -- address
			bram_if_0_s0_readdata                         : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			bram_if_0_s0_write                            : out   std_logic;                                        -- write
			bram_if_0_s0_writedata                        : out   std_logic_vector(31 downto 0);                    -- writedata
			bram_if_0_s0_byteenable                       : out   std_logic_vector(3 downto 0);                     -- byteenable
			bram_if_0_s0_chipselect                       : out   std_logic;                                        -- chipselect
			bram_if_0_reset_reset                         : out   std_logic;                                        -- reset
			bram_if_1_s0_address                          : out   std_logic_vector(21 downto 0);                    -- address
			bram_if_1_s0_readdata                         : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			bram_if_1_s0_write                            : out   std_logic;                                        -- write
			bram_if_1_s0_writedata                        : out   std_logic_vector(31 downto 0);                    -- writedata
			bram_if_1_s0_byteenable                       : out   std_logic_vector(3 downto 0);                     -- byteenable
			bram_if_1_s0_chipselect                       : out   std_logic;                                        -- chipselect
			bram_if_1_reset_reset                         : out   std_logic;                                        -- reset
			bram_if_2_s0_address                          : out   std_logic_vector(21 downto 0);                    -- address
			bram_if_2_s0_readdata                         : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			bram_if_2_s0_write                            : out   std_logic;                                        -- write
			bram_if_2_s0_writedata                        : out   std_logic_vector(31 downto 0);                    -- writedata
			bram_if_2_s0_byteenable                       : out   std_logic_vector(3 downto 0);                     -- byteenable
			bram_if_2_s0_chipselect                       : out   std_logic;                                        -- chipselect
			bram_if_2_reset_reset                         : out   std_logic;                                        -- reset
			registers_s0_address                          : out   std_logic_vector(18 downto 0);                    --         registers_s0.address
			registers_s0_readdata                         : in    std_logic_vector(31 downto 0) := (others => '0'); --                     .readdata
			registers_s0_write                            : out   std_logic;                                        --                     .write
			registers_s0_writedata                        : out   std_logic_vector(31 downto 0);                    --                     .writedata
			registers_s0_byteenable                       : out   std_logic_vector(3 downto 0);                     --                     .byteenable
			registers_s0_chipselect                       : out   std_logic;                                        --                     .chipselect
			registers_s0_waitrequest                      : in    std_logic                     := '0';             --                     .waitrequest
			registers_reset_reset                         : out   std_logic;                                        --      registers_reset.reset
			hps_0_f2h_irq0_irq                            : in    std_logic_vector(31 downto 0) := (others => 'X'); -- irq
			hps_0_f2h_irq1_irq                            : in    std_logic_vector(31 downto 0) := (others => 'X'); --           f2h_irq_p1.irq
			hps_0_spim0_txd                               : out   std_logic;                                        --          hps_0_spim0.txd
			hps_0_spim0_rxd                               : in    std_logic                     := '0';             --                     .rxd
			hps_0_spim0_ss_in_n                           : in    std_logic                     := '0';             --                     .ss_in_n
			hps_0_spim0_ssi_oe_n                          : out   std_logic;                                        --                     .ssi_oe_n
			hps_0_spim0_ss_0_n                            : out   std_logic;                                        --                     .ss_0_n
			hps_0_spim0_ss_1_n                            : out   std_logic;                                        --                     .ss_1_n
			hps_0_spim0_ss_2_n                            : out   std_logic;                                        --                     .ss_2_n
			hps_0_spim0_ss_3_n                            : out   std_logic;                                        --                     .ss_3_n
			hps_0_spim0_sclk_out_clk                      : out   std_logic;                                         -- hps_0_spim0_sclk_out.clk
			hps_0_uart1_cts                               : in    std_logic                     := '0';             --          hps_0_uart1.cts
			hps_0_uart1_dsr                               : in    std_logic                     := '0';             --                     .dsr
			hps_0_uart1_dcd                               : in    std_logic                     := '0';             --                     .dcd
			hps_0_uart1_ri                                : in    std_logic                     := '0';             --                     .ri
			hps_0_uart1_dtr                               : out   std_logic;                                        --                     .dtr
			hps_0_uart1_rts                               : out   std_logic;                                        --                     .rts
			hps_0_uart1_out1_n                            : out   std_logic;                                        --                     .out1_n
			hps_0_uart1_out2_n                            : out   std_logic;                                        --                     .out2_n
			hps_0_uart1_rxd                               : in    std_logic                     := '0';             --                     .rxd
			hps_0_uart1_txd                               : out   std_logic;                                        --                     .txd
			hps_0_h2f_loan_io_in                          : out   std_logic_vector(66 downto 0);                    --    hps_0_h2f_loan_io.in
			hps_0_h2f_loan_io_out                         : in    std_logic_vector(66 downto 0) := (others => '0'); --                     .out
			hps_0_h2f_loan_io_oe                          : in    std_logic_vector(66 downto 0) := (others => '0')  --                     .oeattribute noprune: boolean;
		);
	end component cop_mas2_arm;

	component  chip_id is
	port (
		clkin      : in  std_logic                     := '0'; --  clkin.clk
		reset      : in  std_logic                     := '0'; --  reset.reset
		data_valid : out std_logic;                            -- output.valid
		chip_id    : out std_logic_vector(63 downto 0)         --       .data
	);
	end component  chip_id;

	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	constant g_NoBufferPair : integer  := 4;
	
	function getMultiBuf (NoBufferPair : integer) return std_logic is
	variable res : std_logic := L;
	begin
		if (NoBufferPair>1) then
			res := H;
		end if;
		return res;
	end function getMultiBuf;
	
	constant DF_FLAGS : std_logic_vector(7 downto 0) := CONV_STD_LOGIC_VECTOR(C_TARGET_SUBTYPE, 4) & "00" & getMultiBuf(g_NoBufferPair*C_DUAL_ETH) & getMultiBuf(g_NoBufferPair);

	constant DF_REVISION : std_logic_vector(31 downto 0) := pkg_rev_reg(C_TARGET, C_DEV_BUILD, DF_FLAGS, C_FPGA_SEA2*2 + C_GIN_MASTERnSLAVE, C_REVISION);
	constant DF_SVN_REV : std_logic_vector(31 downto 0) := C_SVN_REV_TOP & get_dec_from_string(" $Rev:: 5784   $ ", 16);

	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------

	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal net_gnd			: std_logic := L;
	signal net_vcc			: std_logic := H;
	signal GND32			: std_logic_vector(31 downto 0) := (others => L);

	signal clk125			: std_logic;
	signal clk62_5			: std_logic;
	signal clk25			: std_logic;
	signal busclk			: std_logic;
	signal phy_dcm_Locked	: std_logic;

--------------------------------------------------------------------------------
-- GMII
--------------------------------------------------------------------------------
	signal GMII_RxDat0		: std_logic_vector(7 downto 0);
	signal GMII_RxDv0		: std_logic;
	signal GMII_RxErr0		: std_logic;
	signal GMII_TxDat0		: std_logic_vector(7 downto 0);
	signal GMII_TxDv0		: std_logic;
	signal GMII_TxErr0		: std_logic;

	signal Gin_GMII_RxDat	: std_logic_vector(7 downto 0);
	signal Gin_GMII_RxDv	: std_logic;
	signal Gin_GMII_RxErr	: std_logic;
	signal Gin_GMII_TxDat	: std_logic_vector(7 downto 0);
	signal Gin_GMII_TxDv	: std_logic;
	signal Gin_GMII_TxErr	: std_logic;

	signal triGMII_RxDat1	: std_logic_vector(7 downto 0);
	signal triGMII_RxDv1	: std_logic;
	signal triGMII_RxErr1	: std_logic;
	signal triGMII_TxDat1	: std_logic_vector(7 downto 0);
	signal triGMII_TxDv1	: std_logic;
	signal triGMII_TxErr1	: std_logic;

--------------------------------------------------------------------------------
-- Ethernet
--------------------------------------------------------------------------------
	signal Eth_IRQs			: std_logic_vector( 7 downto 0) := (others => L);

	signal Eth_GMII_RxDat	: std_logic_vector( 7 downto 0);
	signal Eth_GMII_RxDv	: std_logic;
	signal Eth_GMII_RxErr	: std_logic;
	signal Eth_GMII_TxDat	: std_logic_vector( 7 downto 0);
	signal Eth_GMII_TxDv	: std_logic;
	signal Eth_GMII_TxErr	: std_logic;
	signal Eth_GMII_Q125en	: std_logic := H;
	signal Eth_GMII_data_en	: std_logic := H;
	signal Eth_GMII_TX_Busy	: std_logic := L;

	signal TxEthRun			: std_logic;
	signal RxEthRun			: std_logic;
--------------------------------------------------------------------------------
-- GinLink Master
--------------------------------------------------------------------------------
	signal GinMasIRQ		: std_logic;
--------------------------------------------------------------------------------
-- GinLink Slave
--------------------------------------------------------------------------------
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

	signal Gin_Wdogs		: std_logic_vector( 7 downto 0);
	signal Gin_TlgSyn		: std_logic_vector( 7 downto 0) := (others => L);
	signal GF_Flags			: std_logic_vector(15 downto 0);
	signal Gin_SlvFlags		: std_logic_vector(31 downto 0) := (others => L);

	signal GinSlvIRQ		: std_logic;
	signal PgIRQs			: std_logic_vector( 7 downto 0) := (others => L);
--------------------------------------------------------------------------------
-- MII
--------------------------------------------------------------------------------
	signal MII_Clk			: std_logic;
	signal MII_Do			: std_logic;
	signal MII_T			: std_logic;
	signal MII_Di			: std_logic;
	signal Phy0_LEDgn		: std_logic;
	signal Phy0_LEDyel		: std_logic;
	signal Phy1_LEDgn		: std_logic;
	signal Phy1_LEDyel		: std_logic;
	signal Phy0_LineStat	: std_logic_vector(15 downto 0);
	signal Phy1_LineStat	: std_logic_vector(15 downto 0);

	signal linkState0		: std_logic := L;
	signal linkState1		: std_logic := L;
--------------------------------------------------------------------------------
-- Wdog
--------------------------------------------------------------------------------
	signal EthTx_LedDog		: std_logic;
	signal EthTx_LedDog_2	: std_logic;

	signal nWDog_Gin    	: std_logic;
	signal bwGinFrm_LedDog	: std_logic;
	signal fwGinFrm_LedDog	: std_logic;

--------------------------------------------------------------------------------
-- GE_LED Flasher
--------------------------------------------------------------------------------
	signal Flash_1000		: std_logic;
	signal Flash_0100		: std_logic;
	signal Flash_0010		: std_logic;
	signal Flash_0001		: std_logic;

	signal Flash_1100		: std_logic;
	signal Flash_0011		: std_logic;
	signal Flash_1010		: std_logic;
	signal Flash_0101		: std_logic;
	signal Flash_1110		: std_logic;

	signal Q200ms			: std_logic;

--------------------------------------------------------------------------------

	signal Cop_IRQs			: std_logic_vector(1 downto 0) := "00";

	signal CrcErrCnt0		: std_logic_vector(3 downto 0) := x"0";
	signal CrcErrCnt1		: std_logic_vector(3 downto 0) := x"0";
	signal CrcError0		: std_logic := L;
	signal CrcError1		: std_logic := L;

	signal phy_rst_cnt		: std_logic_vector(17 downto 0) := (others => H);
	signal phy_rst			: std_logic := H;

	signal Eth_BRAM_Clk		: std_logic;
	signal Eth_BRAM_EN		: std_logic;
	signal Eth_BRAM_write	: std_logic;
	signal Eth_BRAM_BEN		: std_logic_vector( 3 downto 0);
	signal Eth_BRAM_WEN		: std_logic_vector( 3 downto 0);
	signal Eth_BRAM_Addr	: std_logic_vector(21 downto 0);
	signal Eth_BRAM_Dp2r	: std_logic_vector(31 downto 0);
	signal Eth_BRAM_Dr2p	: std_logic_vector(31 downto 0);
	signal Tun_BRAM_Dr2p	: std_logic_vector(31 downto 0);
	signal EthTun_BRAM_Dr2p	: std_logic_vector(31 downto 0);
	signal Tun_BRAM_EN		: std_logic;
	signal EthTun_BRAM_EN	: std_logic;
	signal dbg_bram_en		: std_logic;

	signal Gin_BRAM_Clk		: std_logic;
	signal Gin_BRAM_EN		: std_logic;
	signal Gin_BRAM_write	: std_logic;
	signal Gin_BRAM_BEN		: std_logic_vector( 3 downto 0);
	signal Gin_BRAM_WEN		: std_logic_vector( 3 downto 0);
	signal Gin_BRAM_Addr	: std_logic_vector(21 downto 0);
	signal Gin_BRAM_Dp2r	: std_logic_vector(31 downto 0);
	signal Gin_BRAM_Dr2p	: std_logic_vector(31 downto 0);

	signal C64_BRAM_Clk		: std_logic;
	signal C64_BRAM_EN		: std_logic;
	signal C64_BRAM_write	: std_logic;
	signal C64_BRAM_BEN		: std_logic_vector( 3 downto 0);
	signal C64_BRAM_WEN		: std_logic_vector( 3 downto 0);
	signal C64_BRAM_Addr	: std_logic_vector(21 downto 0);
	signal C64_BRAM_Dp2r	: std_logic_vector(31 downto 0);
	signal C64_BRAM_Dr2p	: std_logic_vector(31 downto 0);

	signal Reg_BRAM_Clk		: std_logic;
	signal Reg_BRAM_EN		: std_logic;
	signal Reg_BRAM_write	: std_logic;
	signal Reg_BRAM_wait	: std_logic := L;
	signal Reg_BRAM_BEN		: std_logic_vector( 3 downto 0);
	signal Reg_BRAM_WEN		: std_logic_vector( 3 downto 0);
	signal Reg_BRAM_Addr	: std_logic_vector(21 downto 0);
	signal Reg_BRAM_Dp2r	: std_logic_vector(31 downto 0);
	signal Reg_BRAM_Dr2p	: std_logic_vector(31 downto 0);
	signal ext_mem_data		: std_logic_vector(31 downto 0) := (others => L);
	signal ext_mem_wait		: std_logic := L;

	signal h2f_reset_reset_n : std_logic;

	signal Sw_Gin_Eth		: std_logic;
	signal Sw_Gin_Eth_fi	: std_logic_vector( 2 downto 0) := (others => L);
	signal AddrSw			: std_logic_vector( 3 downto 0) := (others => L);
	signal AddrSw_n1		: std_logic_vector( 3 downto 0) := (others => L);

	signal f2h_irq			: std_logic_vector(31 downto 0) := (others => L);-- irq

	signal cnt				: std_logic_vector(31 downto 0) := (others => L);

	signal DF_GINFLAG_INIT	: std_logic_vector(31 downto 0) := x"00000000";
	signal GinFlags			: std_logic_vector(31 downto 0) := DF_GINFLAG_INIT;
	constant GF_RING		: integer := 0;
	constant GF_AUTOCLOSE	: integer := 1;
	constant GF_ECAT		: integer := 4;
	constant GF_MULTIBUF	: integer := 5;
	constant GF_ECAT_2		: integer := 8;
	constant GF_MULTIBUF_2	: integer := 9;
	constant GF_8K3P		: integer := 16;
	constant GF_MRAM		: integer := 24;
	-- all implemented features must bee enabled in gs mask  
	constant GF_MASK		: std_logic_vector(31 downto 0) := x"01010333";

	signal DF_FLAG_INIT 	: std_logic_vector(31 downto 0) := x"00000000";
	signal Flags 			: std_logic_vector(31 downto 0) := DF_FLAG_INIT;
	constant F_UART1RX 		: integer := 16;
	constant DF_FLG_FAN		: integer := 6;
	constant FLG_FAN_PWM_L	: integer := 24;
	constant FLG_FAN_PWM_H	: integer := FLG_FAN_PWM_L+6;
	signal new_fan_val		: std_logic;
	
	constant DF_FLG_SCL		: integer := 14;
	constant DF_FLG_SDA		: integer := 15;
	signal C96_I2C_SDA		: std_logic;

	signal ENETnECAT		: std_logic := L;
	signal ENETnECAT_1		: std_logic := L;

	signal MulitBufEn		: std_logic := L;
	signal MulitBufEn_1		: std_logic := L;
	
	signal Eth_IRQs_2		: std_logic_vector( 7 downto 0) := (others => L);
	signal ENETnECAT_2		: std_logic := L;
	signal ENETnECAT_2_1	: std_logic := L;
	signal MulitBufEn_2		: std_logic := L;
	signal MulitBufEn_2_1	: std_logic := L;
	
	signal gin_flg_ringmode			: std_logic := L;
	signal gin_flg_ringmode_1		: std_logic := L;

	signal gin_flg_AutoCloseEN		: std_logic := L;
	signal gin_flg_AutoCloseEN_1	: std_logic := L;

	signal gin_fPhyLinkDown			: std_logic;
	signal gin_bPhyLinkDown			: std_logic;

	signal Phy1_LEDStat				: std_logic_vector(15 downto 0);
	signal Phy0_LEDStat				: std_logic_vector(15 downto 0);
	signal speed 					: std_logic_vector(1 downto 0);
	signal GMII_Q125en				: std_logic;
	signal GMII_data_en				: std_logic;

	signal hps_0_spim0_txd			: std_logic;
	signal hps_0_spim0_rxd			: std_logic;
	signal hps_0_spim0_ss_in_n		: std_logic;
	signal hps_0_spim0_ssi_oe_n		: std_logic;
	signal hps_0_spim0_ss_0_n		: std_logic;
	signal hps_0_spim0_ss_1_n		: std_logic;
	signal hps_0_spim0_ss_2_n		: std_logic;
	signal hps_0_spim0_ss_3_n		: std_logic;
	signal hps_0_spim0_sclk_out_clk	: std_logic;

	signal periph_rst : std_logic	:= H;

	signal chip_id64				: std_logic_vector(63 downto 0);
	signal chip_id64_1				: std_logic_vector(63 downto 0);
	signal data_valid				: std_logic;
	
	signal gc2Port_SP_EN		: std_logic := L;
	signal gc2Port_SP_WEN		: std_logic_vector( 3 downto 0) := (others => L);
	signal gc2Port_SP_Addr		: std_logic_vector(15 downto 0) := (others => L);
	signal gc2Port_SP_Dc2g		: std_logic_vector(31 downto 0) := (others => L);
	signal gc2Port_SP_Dg2c		: std_logic_vector(31 downto 0) := (others => L);
	
	signal fpga_uart1_RX		: std_logic := L;
	signal fpga_uart1_TX		: std_logic := L;
	
	signal hps_0_h2f_loan_io_in		: std_logic_vector(66 downto 0) := (others => L);
	signal hps_0_h2f_loan_io_out	: std_logic_vector(66 downto 0) := (others => L);
	signal hps_0_h2f_loan_io_oe		: std_logic_vector(66 downto 0) := (others => L);
	
	signal TunIRQ					: std_logic := L;
	
	attribute noprune: boolean;
	attribute noprune of C64_BRAM_Clk	: signal is true;
	attribute noprune of C64_BRAM_EN	: signal is true;
	attribute noprune of C64_BRAM_write	: signal is true;
	attribute noprune of C64_BRAM_BEN	: signal is true;
	attribute noprune of C64_BRAM_WEN	: signal is true;
	attribute noprune of C64_BRAM_Addr	: signal is true;
	attribute noprune of C64_BRAM_Dp2r	: signal is true;
	attribute noprune of C64_BRAM_Dr2p	: signal is true;
	attribute noprune of f2h_irq		: signal is true;
	
begin

	arm_inst : cop_mas2_arm
	port map (
		hps_0_hps_io_hps_io_qspi_inst_SS1             => hps_qspi_SS1                ,
		hps_io_qspi_inst_IO0_to_and_from_the_hps_0     => hps_qspi_IO0                ,
		hps_io_qspi_inst_IO1_to_and_from_the_hps_0     => hps_qspi_IO1                ,
		hps_io_qspi_inst_IO2_to_and_from_the_hps_0     => hps_qspi_IO2                ,
		hps_io_qspi_inst_IO3_to_and_from_the_hps_0     => hps_qspi_IO3                ,
		hps_io_qspi_inst_SS0_from_the_hps_0            => hps_qspi_SS0                ,
		hps_io_qspi_inst_CLK_from_the_hps_0            => hps_qspi_CLK                ,
		hps_io_sdio_inst_CMD_to_and_from_the_hps_0     => hps_sdio_CMD                ,
		hps_io_sdio_inst_D0_to_and_from_the_hps_0      => hps_sdio_D0                 ,
		hps_io_sdio_inst_D1_to_and_from_the_hps_0      => hps_sdio_D1                 ,
		hps_io_sdio_inst_CLK_from_the_hps_0            => hps_sdio_CLK                ,
		hps_io_sdio_inst_D2_to_and_from_the_hps_0      => hps_sdio_D2                 ,
		hps_io_sdio_inst_D3_to_and_from_the_hps_0      => hps_sdio_D3                 ,
		hps_io_uart0_inst_RX_to_the_hps_0              => hps_uart0_RX                ,
		hps_io_uart0_inst_TX_from_the_hps_0            => hps_uart0_TX                ,
		hps_io_i2c0_inst_SDA_to_and_from_the_hps_0     => hps_i2c0_SDA                ,
		hps_io_i2c0_inst_SCL_to_and_from_the_hps_0     => hps_i2c0_SCL                ,
		hps_0_hps_io_hps_io_can0_inst_RX               => hps_can0_RX                 ,
		hps_0_hps_io_hps_io_can0_inst_TX             => hps_can0_TX                 ,
		hps_io_gpio_inst_GPIO00_to_and_from_the_hps_0  => hps_gpio_GPIO00             ,
		hps_io_gpio_inst_GPIO01_to_and_from_the_hps_0  => hps_gpio_GPIO01             ,
		hps_io_gpio_inst_GPIO02_to_and_from_the_hps_0  => hps_gpio_GPIO02             ,
		hps_io_gpio_inst_GPIO03_to_and_from_the_hps_0  => hps_gpio_GPIO03             ,
		hps_io_gpio_inst_GPIO04_to_and_from_the_hps_0  => hps_gpio_GPIO04             ,
		hps_io_gpio_inst_GPIO05_to_and_from_the_hps_0  => hps_gpio_GPIO05             ,
		hps_io_gpio_inst_GPIO06_to_and_from_the_hps_0  => hps_gpio_GPIO06             ,
		hps_io_gpio_inst_GPIO07_to_and_from_the_hps_0  => hps_gpio_GPIO07             ,
		hps_io_gpio_inst_GPIO08_to_and_from_the_hps_0  => hps_gpio_GPIO08             ,
		hps_io_gpio_inst_GPIO09_to_and_from_the_hps_0  => hps_gpio_GPIO09             ,
		hps_io_gpio_inst_GPIO10_to_and_from_the_hps_0  => hps_gpio_GPIO10             ,
		hps_io_gpio_inst_GPIO11_to_and_from_the_hps_0  => hps_gpio_GPIO11             ,
		hps_io_gpio_inst_GPIO12_to_and_from_the_hps_0  => hps_gpio_GPIO12             ,
		hps_io_gpio_inst_GPIO13_to_and_from_the_hps_0  => hps_gpio_GPIO13             ,
		hps_io_gpio_inst_GPIO14_to_and_from_the_hps_0  => hps_gpio_GPIO14             ,
		hps_io_gpio_inst_GPIO15_to_and_from_the_hps_0  => hps_gpio_GPIO15             ,
		hps_io_gpio_inst_GPIO16_to_and_from_the_hps_0  => hps_gpio_GPIO16             ,
		hps_io_gpio_inst_GPIO17_to_and_from_the_hps_0  => hps_gpio_GPIO17             ,
		hps_io_gpio_inst_GPIO18_to_and_from_the_hps_0  => hps_gpio_GPIO18             ,
		hps_io_gpio_inst_GPIO19_to_and_from_the_hps_0  => hps_gpio_GPIO19             ,
		hps_io_gpio_inst_GPIO20_to_and_from_the_hps_0  => hps_gpio_GPIO20             ,
		hps_io_gpio_inst_GPIO21_to_and_from_the_hps_0  => hps_gpio_GPIO21             ,
		hps_io_gpio_inst_GPIO22_to_and_from_the_hps_0  => hps_gpio_GPIO22             ,
		hps_io_gpio_inst_GPIO23_to_and_from_the_hps_0  => hps_gpio_GPIO23             ,
		hps_io_gpio_inst_GPIO24_to_and_from_the_hps_0  => hps_gpio_GPIO24             ,
		hps_io_gpio_inst_GPIO25_to_and_from_the_hps_0  => hps_gpio_GPIO25             ,
		hps_io_gpio_inst_GPIO26_to_and_from_the_hps_0  => hps_gpio_GPIO26             ,
		hps_io_gpio_inst_GPIO27_to_and_from_the_hps_0  => hps_gpio_GPIO27             ,
		hps_io_gpio_inst_GPIO28_to_and_from_the_hps_0  => hps_gpio_GPIO28             ,
		hps_io_gpio_inst_GPIO37_to_and_from_the_hps_0  => hps_gpio_GPIO37             ,
		hps_io_gpio_inst_GPIO40_to_and_from_the_hps_0  => hps_gpio_GPIO40             ,
		hps_io_gpio_inst_GPIO41_to_and_from_the_hps_0  => hps_gpio_GPIO41             ,
		hps_io_gpio_inst_GPIO42_to_and_from_the_hps_0  => hps_gpio_GPIO42             ,
		hps_io_gpio_inst_GPIO43_to_and_from_the_hps_0  => hps_gpio_GPIO43             ,
		hps_io_gpio_inst_GPIO44_to_and_from_the_hps_0  => hps_gpio_GPIO44             ,
		hps_io_gpio_inst_GPIO48_to_and_from_the_hps_0  => hps_gpio_GPIO48             ,
		hps_io_gpio_inst_GPIO49_to_and_from_the_hps_0  => hps_gpio_GPIO49             ,
		hps_io_gpio_inst_GPIO50_to_and_from_the_hps_0  => hps_gpio_GPIO50             ,
		hps_io_gpio_inst_GPIO51_to_and_from_the_hps_0  => hps_gpio_GPIO51             ,
		hps_io_gpio_inst_GPIO52_to_and_from_the_hps_0  => hps_gpio_GPIO52             ,
		hps_io_gpio_inst_GPIO53_to_and_from_the_hps_0  => hps_gpio_GPIO53             ,
		hps_io_gpio_inst_GPIO54_to_and_from_the_hps_0  => hps_gpio_GPIO54             ,
		hps_io_gpio_inst_GPIO57_to_and_from_the_hps_0  => hps_gpio_GPIO57             ,
		hps_io_gpio_inst_GPIO58_to_and_from_the_hps_0  => hps_gpio_GPIO58             ,
		hps_io_gpio_inst_GPIO59_to_and_from_the_hps_0  => hps_gpio_GPIO59             ,
		hps_io_gpio_inst_GPIO60_to_and_from_the_hps_0  => hps_gpio_GPIO60             ,

		hps_0_hps_io_hps_io_gpio_inst_LOANIO64 =>   hps_uart1_RX,
		hps_0_hps_io_hps_io_gpio_inst_LOANIO63 =>   hps_uart1_TX,

		mem_a_from_the_hps_0                           => hps_memory_mem_a            ,
		mem_ba_from_the_hps_0                          => hps_memory_mem_ba           ,
		mem_ck_from_the_hps_0                          => hps_memory_mem_ck           ,
		mem_ck_n_from_the_hps_0                        => hps_memory_mem_ck_n         ,
		mem_cke_from_the_hps_0                         => hps_memory_mem_cke          ,
		mem_cs_n_from_the_hps_0                        => hps_memory_mem_cs_n         ,
		mem_ras_n_from_the_hps_0                       => hps_memory_mem_ras_n        ,
		mem_cas_n_from_the_hps_0                       => hps_memory_mem_cas_n        ,
		mem_we_n_from_the_hps_0                        => hps_memory_mem_we_n         ,
		mem_reset_n_from_the_hps_0                     => hps_memory_mem_reset_n      ,
		mem_dq_to_and_from_the_hps_0                   => hps_memory_mem_dq           ,
		mem_dqs_to_and_from_the_hps_0                  => hps_memory_mem_dqs          ,
		mem_dqs_n_to_and_from_the_hps_0                => hps_memory_mem_dqs_n        ,
		mem_odt_from_the_hps_0                         => hps_memory_mem_odt          ,
		mem_dm_from_the_hps_0                          => hps_memory_mem_dm           ,
		oct_rzqin_to_the_hps_0                         => hps_memory_oct_rzqin        ,
		clk_axi                                        => busclk                      ,
		h2f_reset_reset_n                              => h2f_reset_reset_n           ,
		bram_if_0_s0_address                           => Gin_BRAM_Addr               ,
		bram_if_0_s0_readdata                          => Gin_BRAM_Dr2p               ,
		bram_if_0_s0_write                             => Gin_BRAM_write              ,
		bram_if_0_s0_writedata                         => Gin_BRAM_Dp2r               ,
		bram_if_0_s0_byteenable                        => Gin_BRAM_BEN                ,
		bram_if_0_s0_chipselect                        => Gin_BRAM_EN                 ,
		bram_if_0_reset_reset                          => open                        ,
		bram_if_1_s0_address                           => Eth_BRAM_Addr               ,
		bram_if_1_s0_readdata                          => EthTun_BRAM_Dr2p            ,
		bram_if_1_s0_write                             => Eth_BRAM_write              ,
		bram_if_1_s0_writedata                         => Eth_BRAM_Dp2r               ,
		bram_if_1_s0_byteenable                        => Eth_BRAM_BEN                ,
		bram_if_1_s0_chipselect                        => EthTun_BRAM_EN              ,
		bram_if_1_reset_reset                          => open                        ,
		bram_if_2_s0_address                           => C64_BRAM_Addr               ,
		bram_if_2_s0_readdata                          => C64_BRAM_Dr2p               ,
		bram_if_2_s0_write                             => C64_BRAM_write              ,
		bram_if_2_s0_writedata                         => C64_BRAM_Dp2r               ,
		bram_if_2_s0_byteenable                        => C64_BRAM_BEN                ,
		bram_if_2_s0_chipselect                        => C64_BRAM_EN                 ,
		bram_if_2_reset_reset                          => open                        ,
		registers_s0_address                           => Reg_BRAM_Addr(18 downto 0)  ,
		registers_s0_readdata                          => Reg_BRAM_Dr2p               ,
		registers_s0_write                             => Reg_BRAM_write              ,
		registers_s0_writedata                         => Reg_BRAM_Dp2r               ,
		registers_s0_byteenable                        => Reg_BRAM_BEN                ,
		registers_s0_chipselect                        => Reg_BRAM_EN                 ,
		registers_reset_reset                          => open                        ,
		registers_s0_waitrequest                       => Reg_BRAM_wait               ,
		hps_0_f2h_irq0_irq                             => f2h_irq                     ,
		hps_0_f2h_irq1_irq                             => f2h_irq                     ,
		hps_0_spim0_txd                                => hps_0_spim0_txd             ,
		hps_0_spim0_rxd                                => hps_0_spim0_rxd             ,
		hps_0_spim0_ss_in_n                            => hps_0_spim0_ss_in_n         ,
		hps_0_spim0_ssi_oe_n                           => hps_0_spim0_ssi_oe_n        ,
		hps_0_spim0_ss_0_n                             => hps_0_spim0_ss_0_n          ,
		hps_0_spim0_ss_1_n                             => hps_0_spim0_ss_1_n          ,
		hps_0_spim0_ss_2_n                             => hps_0_spim0_ss_2_n          ,
		hps_0_spim0_ss_3_n                             => hps_0_spim0_ss_3_n          ,
		hps_0_spim0_sclk_out_clk                       => hps_0_spim0_sclk_out_clk,
		hps_0_uart1_rxd => fpga_uart1_RX,
		hps_0_uart1_txd => fpga_uart1_TX,
		hps_0_h2f_loan_io_in  => hps_0_h2f_loan_io_in   ,
		hps_0_h2f_loan_io_out => hps_0_h2f_loan_io_out  ,
		hps_0_h2f_loan_io_oe  => hps_0_h2f_loan_io_oe

	);
	
	fpga_uart1_RX <= i_fpga_uart1_RX when Flags(F_UART1RX)=L else hps_0_h2f_loan_io_in(63);
	o_fpga_uart1_TX <= fpga_uart1_TX;
	
	hps_0_h2f_loan_io_out(64) <= fpga_uart1_TX;
	hps_0_h2f_loan_io_oe(64) <= H when i_HWRev>x"1" else L;-- uart1 tx: wrong on RevA (Prt SXC6)
	

	use_spim0: if C_SPIM0=1 generate
	begin
		b_mram_clk <= hps_0_spim0_sclk_out_clk;
		b_mram_cs <= not(not(hps_0_spim0_ss_0_n) or GinFlags(GF_MRAM));
		b_mram_si <= hps_0_spim0_txd when hps_0_spim0_ssi_oe_n=L else Z;
		hps_0_spim0_rxd <= b_mram_so;
		hps_0_spim0_ss_in_n <= H;
	end generate use_spim0;
	
	no_spim0: if C_SPIM0=0 generate
	begin
		b_mram_clk <=Z;
		b_mram_cs <= Z;
		b_mram_si <= Z;
		b_mram_so <= Z;
		hps_0_spim0_ss_in_n <= L;
	end generate no_spim0;

	b_lv_GS <= (others => Z);

	Gin_BRAM_Clk <= busclk;
	Eth_BRAM_Clk <= busclk;
	C64_BRAM_Clk <= busclk;
	Reg_BRAM_Clk <= busclk;

	f2h_irq(00) <= GinMasIRQ;
	f2h_irq(01) <= Eth_IRQs(7);-- RX Irq
	f2h_irq(02) <= Eth_IRQs(3);-- ICU
	f2h_irq(03) <= Cop_IRQs(0);
	f2h_irq(04) <= GinSlvIRQ;
	f2h_irq(05) <= Eth_IRQs_2(3);-- ICU
	f2h_irq(06) <= Cop_IRQs(1);
	f2h_irq(07) <= TunIRQ;
	f2h_irq(08) <= i_il_IRQs(0); -- Info Master
	f2h_irq(09) <= i_il_IRQs(1); -- Info Slave
	f2h_irq(10) <= i_il_IRQs(2); -- Info Slave
	f2h_irq(11) <= i_ib_IRQs(0); -- ICU
	
	no_cop_hil: if C_ENABLE_COP_HIL=0 generate
	begin
		o_hilWnR <= L;
		no_hilRes <= L;
		no_hilAl <= H;
		no_hilCs <= H;
	end generate no_cop_hil;
	
	cop_hil: if C_ENABLE_COP_HIL=1 generate
		signal nHil_CEn : std_logic;
		signal nHil_busy : std_logic;
		signal nHil_busy_n1 : std_logic;
		signal nHil_busy_n2 : std_logic;
		signal nHil_busy_n3 : std_logic;
		signal mc_RnW : std_logic;
		signal mc_nBE : std_logiC_vector(1 downto 0);
		signal mc_data_I : std_logiC_vector(15 downto 0);
		signal hil_data : std_logiC_vector(15 downto 0);
		signal mc_Addr : std_logic_vector(13 downto 0);
		
		type t_hil_asseq is (hil_a0,hil_a1,hil_a2,hil_d);
		signal hil_asseq : t_hil_asseq := hil_a0;
		
		constant DF_BUSY_ABORT : integer := 56;
		signal busy_abort_cnt : std_logic_vector(pkg_log2(DF_BUSY_ABORT)-1 downto 0) := (others => L);
		signal hilDA : std_logic_vector(15 downto 0);
		signal busy_done : std_logic := L;
	begin
	
		no_hilRes <= not periph_rst;
		
		-- cs		--___________---
		-- hilD		XXAAADDDDDDDDXXX
		-- hilAL	--__------------
		-- hilCS	-----________---
		--
		
		-- return a error when timeout or no module connected
		hilDA <= x"a2a2" when (busy_abort_cnt=DF_BUSY_ABORT-1) or (nHil_busy=L) else b_hilDA;
		nHil_CEn <= not(Reg_BRAM_Addr(18) and Reg_BRAM_EN);
		mc_nBE(1) <= not(Reg_BRAM_BEN(0)) when mc_Addr(0)=L else not(Reg_BRAM_BEN(2));
		mc_nBE(0) <= not(Reg_BRAM_BEN(1)) when mc_Addr(0)=L else not(Reg_BRAM_BEN(3));
		mc_RnW <= not(Reg_BRAM_write);
		mc_Addr <= Reg_BRAM_Addr(12 downto 0) & not(Reg_BRAM_BEN(0) or Reg_BRAM_BEN(1));
		
		ext_mem_wait <= not(nHil_busy);
		ext_mem_data <= hilDA(7 downto 0) & hilDA(15 downto 8) & hilDA(7 downto 0) & hilDA(15 downto 8);
		
		
		cop_hil_seq : process(Reg_BRAM_Clk)
		begin
			if rising_edge(Reg_BRAM_Clk) then
				-- sync busy and handle timeout
				nHil_busy_n1 <= ni_hilBusy;
				nHil_busy_n2 <= nHil_busy_n1;
				nHil_busy_n3 <= nHil_busy_n2;
				
				if (nHil_CEn=L) then
					if (busy_abort_cnt=DF_BUSY_ABORT-1) then
						nHil_busy <= H; -- end extmem ctrl.
					else
						busy_abort_cnt <= busy_abort_cnt + 1;
					end if;
					case hil_asseq is
					when hil_a0 =>
						if (nHil_busy_n2=H) then
							no_hilAl <= L;
							no_hilCs <= H;
							b_hilDA <= mc_nBE & mc_Addr(13 downto 0);
							hil_asseq <= hil_a1;
						end if;
					when hil_a1 =>
						no_hilAl <= L;
						no_hilCs <= H;
						b_hilDA <= mc_nBE & mc_Addr(13 downto 0);
						hil_asseq <= hil_a2;
					when hil_a2 =>
						no_hilAl <= H;
						no_hilCs <= H;
						b_hilDA <= mc_nBE & mc_Addr(13 downto 0);
						hil_asseq <= hil_d;
					when hil_d =>
						no_hilAl <= H;
						no_hilCs <= L;
						o_hilWnR <= not mc_RnW;
						if (mc_RnW=H) then
							b_hilDA <= (others => Z);
						else
							if mc_Addr(0)=L then
								b_hilDA <= Reg_BRAM_Dp2r(7 downto 0) & Reg_BRAM_Dp2r(15 downto 8);
							else
								b_hilDA <= Reg_BRAM_Dp2r(23 downto 16) & Reg_BRAM_Dp2r(31 downto 24);
							end if;
						end if;
						if (nHil_busy_n2=H and nHil_busy_n3=L) then
							-- com x/c module generate always a busy. us __-- to 
							-- dedect a module or return with error
							nHil_busy <= H;
						end if;
						hil_asseq <= hil_d;
					end case;
				else
					no_hilAl <= H;
					no_hilCs <= H;
					o_hilWnR <= L;
					b_hilDA <= (others => Z);
					hil_asseq <= hil_a0;
					busy_abort_cnt <= (others => L);
					nHil_busy <= L;
				end if;
			end if;
		end process cop_hil_seq;
	end generate cop_hil;
	
	bram_wr : for i in 0 to 3 generate
	begin
		Eth_BRAM_WEN(i) <= Eth_BRAM_BEN(i) and Eth_BRAM_write;-- when C_TUNNEL=0 else Eth_BRAM_BEN(i) and Eth_BRAM_write and not Eth_BRAM_Addr(16);
		Gin_BRAM_WEN(i) <= Gin_BRAM_BEN(i) and Gin_BRAM_write;
		C64_BRAM_WEN(i) <= C64_BRAM_BEN(i) and C64_BRAM_write;
		Reg_BRAM_WEN(i) <= Reg_BRAM_BEN(i) and Reg_BRAM_write;
	end generate bram_wr;
	
	no_eth_bram_mux : if not(C_TUNNEL=1 and C_GIN_MASTERnSLAVE=1 and C_DUAL_ETH=0) generate
	begin
		Eth_BRAM_EN <= EthTun_BRAM_EN;
		EthTun_BRAM_Dr2p <= Eth_BRAM_Dr2p;
	end generate no_eth_bram_mux;
	
	eth_bram_mux : if (C_TUNNEL=1 and C_GIN_MASTERnSLAVE=1 and C_DUAL_ETH=0) generate
		type t_out_select is (tunram,ethram,debram);
		signal out_select_p			: t_out_select := ethram;
		signal out_select_r			: t_out_select := ethram;
		signal out_select			: t_out_select := ethram;
	begin	
		process (Eth_BRAM_Addr,Tun_BRAM_Dr2p,Eth_BRAM_Dr2p)
		begin

			Eth_BRAM_EN <= L;
			Tun_BRAM_EN <= L;
			dbg_bram_en <= L;
			if (Eth_BRAM_Addr(16)=H) then-- 32bit addr (0x40000)
				Tun_BRAM_EN <= EthTun_BRAM_EN;
			elsif (Eth_BRAM_Addr(17)=H) then-- 32bit addr (0x80000)
				dbg_bram_en <= EthTun_BRAM_EN;
			else
				Eth_BRAM_EN <= EthTun_BRAM_EN;
			end if;

			case out_select is
			when tunram => EthTun_BRAM_Dr2p <= Tun_BRAM_Dr2p;
			when debram => EthTun_BRAM_Dr2p <= x"01234567";
			when ethram => EthTun_BRAM_Dr2p <= Eth_BRAM_Dr2p;
			end case;

		end process;

	--	outreg_en: if g_OUTREG_A=1 generate
	--		out_select <= out_select_p;
	--	end generate outreg_en;
	--
	--	outreg_dis: if g_OUTREG_A=0 generate
			out_select <= out_select_r;
	--	end generate outreg_dis;

		process (Eth_BRAM_Clk) begin
			if rising_edge(Eth_BRAM_Clk) then
				if Eth_BRAM_EN=H then
					out_select_r <= ethram;
				elsif Tun_BRAM_EN=H then
					out_select_r <= tunram;
				elsif dbg_bram_en=H then
					out_select_r <= debram;
				end if;
				out_select_p <= out_select_r;
			end if;
		end process;
	
	end generate eth_bram_mux;
	
	
	
	read_reg : process(Reg_BRAM_Clk)
	begin
		if rising_edge(Reg_BRAM_Clk) then
			if (C_ENABLE_COP_HIL=1) then
				Reg_BRAM_wait <= not Reg_BRAM_EN;
			else
				Reg_BRAM_wait <= L;
			end if;
			if (Reg_BRAM_Addr(18)=H and C_ENABLE_COP_HIL=1) then -- Reg_BRAM_Addr in 0xff300000..0xff3fffff
				Reg_BRAM_Dr2p <= ext_mem_data;
				Reg_BRAM_wait <= ext_mem_wait;
			else
				if (Reg_BRAM_Addr(3 downto 0)=DF_REG_FLG_RANGE) then
					Reg_BRAM_Dr2p <= Flags;
					Reg_BRAM_Dr2p(DF_FLG_SDA) <= C96_I2C_SDA;
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_GFL_RANGE) then
					Reg_BRAM_Dr2p <= GinFlags;
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_C16_RANGE) then
					Reg_BRAM_Dr2p <= x"0" & cnt(11 downto 0) & x"1" & cnt(11 downto 0);
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_MII_RANGE) then
					Reg_BRAM_Dr2p <= Phy0_LEDStat & Phy1_LEDStat;
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_CNT_RANGE) then
					Reg_BRAM_Dr2p <= cnt;--mii_done & "000" & x"000" & MII_rxPhyX;
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_IDH_RANGE) then
					Reg_BRAM_Dr2p <= chip_id64(63 downto 32);
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_IDL_RANGE) then
					Reg_BRAM_Dr2p <= chip_id64(31 downto 0);
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_ILM_RANGE) then
					Reg_BRAM_Dr2p <= i_IlmFlags;
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_IMP_RANGE) then
					Reg_BRAM_Dr2p <= i_IbIlsFlags;
				elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_SVN_RANGE) then
					Reg_BRAM_Dr2p <= DF_SVN_REV;
				else
					Reg_BRAM_Dr2p <= DF_REVISION;
				end if;
			end if;
		end if;
	end process read_reg;

	write_reg : process(Reg_BRAM_Clk)
	begin
		if rising_edge(Reg_BRAM_Clk) then
			if (Reg_BRAM_EN=H) then
				if (Reg_BRAM_Addr(18)=H and C_ENABLE_COP_HIL=1) then -- Reg_BRAM_Addr in 0xff300000..0xff3fffff
					
				else
					if (Reg_BRAM_Addr(3 downto 0)=DF_REG_FLG_RANGE) then
						for i in 0 to 3 loop
							if (Reg_BRAM_WEN(i)=H) then
								Flags(7+8*i downto 8*i) <= Reg_BRAM_Dp2r(7+8*i downto 8*i);
							end if;
							if (Reg_BRAM_WEN(3)=H) then
								new_fan_val <= H;
							end if;
						end loop;
					elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_GFL_RANGE) then
						for i in 0 to 3 loop
							if (Reg_BRAM_WEN(i)=H) then
								GinFlags(7+8*i downto 8*i) <= Reg_BRAM_Dp2r(7+8*i downto 8*i) and GF_MASK(7+8*i downto 8*i);
							end if;
						end loop;
						if (C_GIN_MASTERnSLAVE=0 or C_DUAL_ETH=1) then
							-- not implementet in gin slave
							GinFlags(GF_RING) <= L;
							GinFlags(GF_AUTOCLOSE) <= L;
						end if;
						if (C_DUAL_ETH=0) then
							-- not implementet
							GinFlags(GF_ECAT_2) <= L;
							GinFlags(GF_MULTIBUF_2) <= L;
						end if;
						if (C_GIN_MASTERnSLAVE=1 or C_DUAL_ETH=1 or C_ENABLE_3PORT_MASTER=0) then
							-- not implementet in gin master, slave without 3p or dualeth
							GinFlags(GF_8K3P) <= L;
						end if;
					elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_ILM_RANGE) then
						for i in 0 to 3 loop
							if (Reg_BRAM_WEN(i)=H) then
								o_IlmFlags(7+8*i downto 8*i) <= Reg_BRAM_Dp2r(7+8*i downto 8*i);
							end if;
						end loop;
						o_il_reg_sync <= H;
					elsif (Reg_BRAM_Addr(3 downto 0)=DF_REG_IMP_RANGE) then
						for i in 0 to 3 loop
							if (Reg_BRAM_WEN(i)=H) then
								o_IbIlsFlags(7+8*i downto 8*i) <= Reg_BRAM_Dp2r(7+8*i downto 8*i);
							end if;
						end loop;
					
					end if;
				end if;
			end if;
			cnt <= cnt+1;
			Flags(13 downto 0) <= hps_0_h2f_loan_io_in(64) & hps_0_h2f_loan_io_in(63) & b_lv_GS & i_HWRev & i_AddrSw;
			
			-- handshake infolink
			if (i_il_reg_done = H) then
				o_il_reg_sync <= L;
			end if;
			
			if new_fan_val=H then -- hold two clks
				new_fan_val <= L;
			end if;
			
			if (periph_rst=H) then
				Flags(31 downto 0) <= DF_FLAG_INIT;
				GinFlags <= DF_GINFLAG_INIT;
				cnt <= (others => L);
				new_fan_val <= L;
				o_il_reg_sync <= L;
				o_IbIlsFlags <= (others => L);
				
			end if;
		end if;
	end process write_reg;

	fpga_pll : entity pll.pll
	port map (
		refclk	=> i_FPGA_clk25,
		outclk_0	=> clk25,
		outclk_1	=> clk125,
		outclk_2	=> clk62_5,
	--	outclk_3	=> busclk,
		locked	=> phy_dcm_Locked
	);
	
	busclk <= clk125;
	periph_rst <= not h2f_reset_reset_n or not phy_dcm_Locked;
	o_periph_rst <= periph_rst;

	fpga_id : chip_id
	port map (
		clkin => clk62_5,
		data_valid => data_valid,
		chip_id => chip_id64_1
	);

	no_PHY_RESET <= not phy_rst;

	process (clk125) begin
		if rising_edge(clk125) then
			-- chip id syncer
			chip_id64 <= chip_id64_1;
			-- phy reset
			if (phy_rst_cnt/=0) then
				phy_rst_cnt <= phy_rst_cnt - 1;
				phy_rst <= H;
			else
				phy_rst <= L;
			end if;
			if periph_rst=H then
				phy_rst_cnt <= (others => H);
			end if;
		end if;
	end process;


	std_eth: if (C_DUAL_ETH=0) generate
		phy_if0 : entity RGMII_if.RGMII_if
		generic map (
			C_ELASTIC_BUF_LAT => 5,
			C_USE_EXTRA_REG => 1
		)
		port map (
			i_tx_clk		=> clk125,
			-- user interface
			o_data			=> GMII_RxDat0,
			o_data_valid	=> GMII_RxDv0,
			o_data_error	=> GMII_RxErr0,
			i_data			=> GMII_TxDat0,
			i_data_valid	=> GMII_TxDv0,
			i_data_error	=> GMII_TxErr0,
			-- rgmii ---------------------------------------------------------------
			i_PHY_RXC		=> i_PHY_RXC0,
			o_PHY_TXD		=> o_PHY_TXD0,
			o_PHY_TXEN		=> o_PHY_TXEN0,
			i_PHY_RXD		=> i_PHY_RXD0,
			i_PHY_RXDV		=> i_PHY_RXDV0,
			o_PHY_GTXCLK	=> o_PHY_GTXCLK0
		);
	end generate std_eth;
	
	dual_eth: if (C_DUAL_ETH=1) generate
		signal speed_2 : std_logic_vector(1 downto 0);
		signal GMII_Q125en_2 : std_logic;
		signal GMII_data_en_2 : std_logic;
		signal TxEthRun_2 : std_logic;
		signal RxEthRun_2 : std_logic;
	begin
		
		Eth_GMII_RxDat	<= triGMII_RxDat1;
		Eth_GMII_RxDv	<= triGMII_RxDv1;
		Eth_GMII_RxErr	<= triGMII_RxErr1;

		triGMII_TxDat1	<= Eth_GMII_TxDat;
		triGMII_TxDv1	<= Eth_GMII_TxDv;
		triGMII_TxErr1	<= Eth_GMII_TxErr;
		
		Eth_GMII_data_en <= GMII_data_en;
		Eth_GMII_Q125en <= GMII_Q125en;
		Eth_GMII_TX_Busy <= L;
	
		speed_2 <= Phy0_LEDStat(4 downto 3);
		
		phy_if0 : entity RGMII_if.TriSpeedRGMII
		generic map (
			C_ELASTIC_BUF_LAT => 5,
			C_USE_EXTRA_REG => 1
		)
		port map (
			i_speed			=> speed_2		, -- 10:"10" 100:"01" else 1000
			i_disable		=> L			,
			i_clk125		=> clk125		,
			i_clk62_5		=> clk62_5		,
			o_GMII_RX_Data_Valid_EN	=> GMII_data_en_2	,
			o_GMII_TX_CLK_EN		=> GMII_Q125en_2	,
			-- user interface
			o_GMII_RxDat	=> GMII_RxDat0,
			o_GMII_RxDv 	=> GMII_RxDv0,
			o_GMII_RxErr	=> GMII_RxErr0,
			i_GMII_TxDat	=> GMII_TxDat0,
			i_GMII_TxDv 	=> GMII_TxDv0,
			i_GMII_TxErr	=> GMII_TxErr0,
			-- rgmii ---------------------------------------------------------------
			i_PHY_RXC		=> i_PHY_RXC0,
			o_PHY_TXD		=> o_PHY_TXD0,
			o_PHY_TXEN		=> o_PHY_TXEN0,
			i_PHY_RXD		=> i_PHY_RXD0,
			i_PHY_RXDV		=> i_PHY_RXDV0,
			o_PHY_GTXCLK	=> o_PHY_GTXCLK0
		);
		
		uSecond_Ethernet: entity gin_eth.ge_wrap
		generic map (
			g_fpga_type => 1,
			g_EtherCAT => 1,
			g_powerLink => 1,
			--g_OUTREG_A => 1,
			g64_n32BitRam => 0,
			g_NoBufferPair => g_NoBufferPair
		)
		port map (
			i_ppc_dom_clk		=> busclk		, --used for irq synch.
			o_IRQs				=> Eth_IRQs_2	,
			i_Q125				=> clk125		,
			i_Q62_5				=> clk62_5		,
			i_ENETnECAT			=> ENETnECAT_2	,
			i_MulitBufEn		=> MulitBufEn_2	,
			i_GMII_RX_Data_Valid_EN	=> GMII_data_en_2	,
			i_GMII_TX_CLK_EN		=> GMII_Q125en_2	,
			o_GMII_TxDat		=> GMII_TxDat0	,
			o_GMII_TxDv			=> GMII_TxDv0	,
			o_GMII_TxErr		=> GMII_TxErr0	,
			i_GMII_RxDat		=> GMII_RxDat0	,
			i_GMII_RxDv			=> GMII_RxDv0	,
			i_GMII_RxErr		=> GMII_RxErr0	,
			o_TxEthRun			=> TxEthRun_2	,
			o_RxEthRun			=> RxEthRun_2	,
			i_BRAM_Clk			=> Gin_BRAM_Clk	,
			i_BRAM_EN			=> Gin_BRAM_EN	,
			i_BRAM_WEN			=> Gin_BRAM_WEN	,
			i_BRAM_Addr			=> Gin_BRAM_Addr(15 downto 0),
			i_BRAM_Dout			=> Gin_BRAM_Dp2r,
			o_BRAM_Din			=> Gin_BRAM_Dr2p
		);
		
		uWrap_EthLdog: entity gin_link.Gin_WatchDog_800ms
		port map (
			i_Q62_5			=> clk62_5		,
			i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
			i_Probe			=> TxEthRun_2	,	-- bwGinFrames ?
			o_Wdog			=> EthTx_LedDog_2
		);
			
	end generate dual_eth;

	speed <= Phy1_LEDStat(4 downto 3) when Sw_Gin_Eth=H or C_GIN_MASTERnSLAVE=1 or C_DUAL_ETH=1 else "00";

	phy_if1 : entity RGMII_if.TriSpeedRGMII
	generic map (
		C_ELASTIC_BUF_LAT => 5,
		C_USE_EXTRA_REG => 1
	)
	port map (
		i_speed			=> speed		, -- 10:"10" 100:"01" else 1000
		i_disable		=> gin_flg_ringmode, -- disabel when ringmode
		i_clk125		=> clk125		,
		i_clk62_5		=> clk62_5		,
		o_GMII_RX_Data_Valid_EN	=> GMII_data_en	,
		o_GMII_TX_CLK_EN		=> GMII_Q125en	,
		-- user interface
		o_GMII_RxDat		=> triGMII_RxDat1,
		o_GMII_RxDv 		=> triGMII_RxDv1,
		o_GMII_RxErr		=> triGMII_RxErr1,
		i_GMII_TxDat		=> triGMII_TxDat1,
		i_GMII_TxDv 		=> triGMII_TxDv1,
		i_GMII_TxErr		=> triGMII_TxErr1,
		-- rgmii ---------------------------------------------------------------
		i_PHY_RXC		=> i_PHY_RXC1,
		o_PHY_TXD		=> o_phy_TXD1,
		o_PHY_TXEN		=> o_phy_TXEN1,
		i_PHY_RXD		=> i_PHY_RXD1,
		i_PHY_RXDV		=> i_PHY_RXDV1,
		o_PHY_GTXCLK	=> o_phy_GTXCLK1
	);


	u_GE_MII: 	entity gin_link.GE_MIISeq
	generic map (
		C_ADDR_4_1 => "0000",
		C_PHY => "BCM54210"
	)
	port map (
		i_Q62_5				=> clk62_5			,
		o_MII_Clk			=> MII_Clk			,
		o_MII_Dout			=> MII_Do			,
		o_MII_T				=> MII_T			,
		o_MII_Dinp			=> MII_Di			,
		i_Phy0_LED1			=> Phy0_LEDgn		,
		i_Phy0_LED2			=> Phy0_LEDyel		,
		i_Phy1_LED1			=> Phy1_LEDgn		,
		i_Phy1_LED2			=> Phy1_LEDyel		,
		o_Phy0_LineStat		=> Phy0_LineStat	,
		o_Phy1_LineStat		=> Phy1_LineStat	,
		o_Phy0_LEDStat		=> Phy0_LEDStat		,
		o_Phy1_LEDStat		=> Phy1_LEDStat		,
		o_linkState0		=> linkState0		,
		o_linkState1		=> linkState1
	);

	MII_Di <= b_PHY_MDIO(0) and b_PHY_MDIO(1);

	o_PHY_MDC(0) <= MII_Clk;
	o_PHY_MDC(1) <= MII_Clk;
	b_PHY_MDIO(0) <= Z when MII_T=H else MII_Do;
	b_PHY_MDIO(1) <= Z when MII_T=H else MII_Do;

	process (linkState0,linkState1,Flash_1100,Flash_0011,Flash_1010,Flash_0101,Flash_1110,fwGinFrm_LedDog,EthTx_LedDog,gin_flg_ringmode,Sw_Gin_Eth,bwGinFrm_LedDog,EthTx_LedDog_2,Gin_SlvFlags) begin

		if (C_GIN_MASTERnSLAVE=1 or C_DUAL_ETH=1) then -- ginmaster
			bwGinxChanger <= H;
		else -- ginslave
			-- if Phy1_LineDown, then bwGinxChanger
			bwGinxChanger <= not linkState1 or Sw_Gin_Eth;
		end if;
		
		-- phy0 leds
		if C_DUAL_ETH=0 then
			if (linkState0 = L) then
				Phy0_LEDgn <= Flash_1100;
				if (gin_flg_ringmode = L) then
					Phy0_LEDyel <= Flash_0011;
				else
					Phy0_LEDyel <= L;
				end if;
			else
				Phy0_LEDgn <= H;
				if (gin_flg_ringmode = L) then
					if (fwGinFrm_LedDog = L) then
						Phy0_LEDyel <= L;
					else
						Phy0_LEDyel <= H;
					end if;
				else
					Phy0_LEDyel <= L;
				end if;
				-- override only on regular ginlink state
				if (Gin_SlvFlags(4)=H) then
					Phy0_LEDgn  <= Gin_SlvFlags(0);
				end if;
				if (Gin_SlvFlags(5)=H) then
					Phy0_LEDyel  <= Gin_SlvFlags(1);
				end if;
			end if;
		else -- ethernet
			if (linkState0 = L) then
				Phy0_LEDgn <= Flash_1010;
				Phy0_LEDyel <= Flash_0101;
			else
				Phy0_LEDgn <= Flash_1110;
				if (EthTx_LedDog_2 = L) then
					Phy0_LEDyel <= L;
				else
					Phy0_LEDyel <= Flash_1110;
				end if;
			end if;
		end if;
		-- phy1 leds
		if (C_GIN_MASTERnSLAVE=0 and Sw_Gin_Eth=L and  C_DUAL_ETH=0) then -- ginslave and no eth
			if (linkState0 = L) then
				Phy1_LEDgn  <= L;
				Phy1_LEDyel <= L;
			else
				if (fwGinFrm_LedDog = L) then
					Phy1_LEDgn  <= L;
					Phy1_LEDyel <= L;
				else
					if (linkState1 = L) then
						Phy1_LEDgn  <= L;
						Phy1_LEDyel <= L;
					else
						Phy1_LEDgn  <= H;
						if (bwGinFrm_LedDog = L) then
							Phy1_LEDyel <= L;
						else
							Phy1_LEDyel <= H;
						end if;
						-- override only on regular ginlink state
						if (Gin_SlvFlags(6)=H) then
							Phy1_LEDgn  <= Gin_SlvFlags(2);
						end if;
						if (Gin_SlvFlags(7)=H) then
							Phy1_LEDyel  <= Gin_SlvFlags(3);
						end if;
					end if;
				end if;
			end if;
		elsif (C_GIN_MASTERnSLAVE=1 and gin_flg_ringmode = H and  C_DUAL_ETH=0) then -- ginmaster and no eth
			if (linkState1 = L) then
				Phy1_LEDgn <= L;
				Phy1_LEDyel <= Flash_0011;
			else
				Phy1_LEDgn <= H;
				if (fwGinFrm_LedDog = L) then
					Phy1_LEDyel <= Flash_0011;
				else
					Phy1_LEDyel <= H;
				end if;
			end if;
		else -- ethernet
			if (linkState1 = L) then
				Phy1_LEDgn <= Flash_1010;
				Phy1_LEDyel <= Flash_0101;
			else
				Phy1_LEDgn <= Flash_1110;
				if (EthTx_LedDog = L) then
					Phy1_LEDyel <= L;
				else
					Phy1_LEDyel <= Flash_1110;
				end if;
			end if;
		end if;
	end process;

	uWrap_bwGinLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5      ,
		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
		i_Probe			=> bwGinRun 	,	-- bwGinFrames ?
		o_Wdog			=> bwGinFrm_LedDog
	);

	uWrap_fwGinLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5		,
		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
		i_Probe			=> fwGinRun		,	-- bwGinFrames ?
		o_Wdog			=> fwGinFrm_LedDog
	);

	uWrap_EthLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5		,
		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
		i_Probe			=> TxEthRun		,	-- bwGinFrames ?
		o_Wdog			=> EthTx_LedDog
	);

	uGin_LED_Flasher : entity gin_link.Gin_LED_Flasher
	port map (
		i_Q62_5			=> clk62_5		,
		i_SynchFlash	=> net_gnd		,
		o_Flash_1000	=> Flash_1000	,
		o_Flash_0100	=> Flash_0100	,
		o_Flash_0010	=> Flash_0010	,
		o_Flash_0001	=> Flash_0001	,
		o_Q200ms		=> Q200ms
	);

	Flash_1100 <= Flash_1000 or Flash_0100;
	Flash_0011 <= not Flash_1100;
	Flash_1010 <= Flash_1000 or Flash_0010;
	Flash_0101 <= not Flash_1010;
	Flash_1110 <= not Flash_0001;
	
	Sw_Gin_Eth_fi(0) <= H when AddrSw(2)=H or (C_EMG_SYS=1 and AddrSw(0)=H)else L;

	synchSw_Gin : process(clk62_5)
	begin
		if rising_edge(clk62_5) then
			if (Q200ms=H) then
				Sw_Gin_Eth_fi(Sw_Gin_Eth_fi'high downto 1) <= Sw_Gin_Eth_fi(Sw_Gin_Eth_fi'high-1 downto 0);
			end if;
			if (Sw_Gin_Eth_fi=0) then
				Sw_Gin_Eth <= L;
			elsif (Sw_Gin_Eth_fi=((2**Sw_Gin_Eth_fi'length)-1)) then
				Sw_Gin_Eth <= H;
			end if;
		end if;
	end process synchSw_Gin;
	

	syncring : process(clk125)
	begin
		if rising_edge(clk125) then
			AddrSw_n1 <= i_AddrSw;
			AddrSw <= AddrSw_n1;
			gin_flg_ringmode_1 <= GinFlags(GF_RING);
			gin_flg_AutoCloseEN_1 <= GinFlags(GF_AUTOCLOSE);
			if (C_GIN_MASTERnSLAVE=1 and C_DUAL_ETH=0) then
				gin_flg_ringmode <= gin_flg_ringmode_1;
				gin_flg_AutoCloseEN <= gin_flg_AutoCloseEN_1;
			else
				gin_flg_ringmode <= L;
				gin_flg_AutoCloseEN <= L;
			end if;
		end if;
	end process syncring;

	gin_fPhyLinkDown <= not linkState0;-- when gin_flg_ringmode=L else not linkState0 and not linkState1;
	gin_bPhyLinkDown <= not linkState1;

	-- ethernet ----------------------------------------------------------------
	uTop_Ethernet: entity gin_eth.ge_wrap
	generic map (
		g_fpga_type		=> 1,
		g_EtherCAT		=> 1,
		g_powerLink		=> 1,
		--g_OUTREG_A => 1,
		g64_n32BitRam	=> 0,
		g_NoBufferPair	=> g_NoBufferPair
	)
	port map (
		i_ppc_dom_clk		=> busclk		, --used for irq synch.
		o_IRQs				=> Eth_IRQs		,
		i_Q125				=> clk125		,
		i_Q62_5				=> clk62_5		,
		i_ENETnECAT			=> ENETnECAT	,
		i_MulitBufEn		=> MulitBufEn	,
		i_GMII_RX_Data_Valid_EN	=> Eth_GMII_data_en	,
		i_GMII_TX_CLK_EN	=> Eth_GMII_Q125en	,
		i_GMII_TX_Busy		=> Eth_GMII_TX_Busy	,
		o_GMII_TxDat		=> ETH_GMII_TxDat	,
		o_GMII_TxDv			=> ETH_GMII_TxDv	,
		o_GMII_TxErr		=> ETH_GMII_TxErr	,
		i_GMII_RxDat		=> Eth_GMII_RxDat	,
		i_GMII_RxDv			=> Eth_GMII_RxDv	,
		i_GMII_RxErr		=> Eth_GMII_RxErr	,
		o_TxEthRun			=> TxEthRun		,
		o_RxEthRun			=> RxEthRun		,
		i_BRAM_Clk			=> Eth_BRAM_Clk	,
		i_BRAM_EN			=> Eth_BRAM_EN	,
		i_BRAM_WEN			=> Eth_BRAM_WEN	,
		i_BRAM_Addr			=> Eth_BRAM_Addr(15 downto 0),
		i_BRAM_Dout			=> Eth_BRAM_Dp2r,
		o_BRAM_Din			=> Eth_BRAM_Dr2p
	);

	sync62_5 : process(clk62_5)
	begin
		if rising_edge(clk62_5) then
			ENETnECAT_1 <= not GinFlags(GF_ECAT);
			ENETnECAT <= ENETnECAT_1;
			
			MulitBufEn_1 <= GinFlags(GF_MULTIBUF);
			MulitBufEn <= MulitBufEn_1;
			
			ENETnECAT_2_1 <= not GinFlags(GF_ECAT_2);
			ENETnECAT_2 <= ENETnECAT_2_1;
			
			MulitBufEn_2_1 <= GinFlags(GF_MULTIBUF_2);
			MulitBufEn_2 <= MulitBufEn_2_1;
		end if;
	end process sync62_5;

--	checker0: entity work.crc_checker
--	port map (
--		i_clk125 => clk125,
--		i_GMII_RxDat => GMII_RxDat0,
--		i_GMII_RxDv => GMII_RxDv0,
--		o_CrcError => CrcError0
--	);
--
--	checker1: entity work.crc_checker
--	port map (
--		i_clk125 => clk125,
--		i_GMII_RxDat => triGMII_RxDat1,
--		i_GMII_RxDv => triGMII_RxDv1,
--		o_CrcError => CrcError1
--	);

	process (clk125) begin
		if rising_edge(clk125) then
			if (CrcError0=H) then
				CrcErrCnt0 <= CrcErrCnt0 + 1;
			end if;
			if (CrcError1=H) then
				CrcErrCnt1 <= CrcErrCnt1 + 1;
			end if;
		end if;
	end process;

	-- gin master --------------------------------------------------------------
	gm : if (C_GIN_MASTERnSLAVE=1 and C_DUAL_ETH=0) generate
		signal TxSlot_0 : std_logic;
		signal Mac2Tun_D			: std_logic_vector(15 downto 0) := (others => L);
		signal Mac2Tun_Req			: std_logic := L;
		signal Mac2Tun_En			: std_logic := L;
		signal ExtRxDv				: std_logic;
		signal ExtRxData			: std_logic_vector(15 downto 0);
	begin
		Gin_GMII_RxDat	<= GMII_RxDat0 when gin_flg_ringmode=L else triGMII_RxDat1;
		Gin_GMII_RxDv	<= GMII_RxDv0  when gin_flg_ringmode=L else triGMII_RxDv1;
		Gin_GMII_RxErr	<= GMII_RxErr0 when gin_flg_ringmode=L else triGMII_RxErr1;

		Eth_GMII_RxDat	<= triGMII_RxDat1;
		Eth_GMII_RxDv	<= triGMII_RxDv1;
		Eth_GMII_RxErr	<= triGMII_RxErr1;

		triGMII_TxDat1	<= Eth_GMII_TxDat;
		triGMII_TxDv1	<= Eth_GMII_TxDv;
		triGMII_TxErr1	<= Eth_GMII_TxErr;

		GMII_TxDat0		<= GIN_GMII_TxDat;
		GMII_TxDv0		<= GIN_GMII_TxDv;
		GMII_TxErr0		<= GIN_GMII_TxErr;
		
		Eth_GMII_data_en <= GMII_data_en;
		Eth_GMII_Q125en <= GMII_Q125en;
		Eth_GMII_TX_Busy <= L;
		
		Gin_TlgSyn(7 downto 1) <= (others => L);

		uTop_GMaster: entity gin_master.gm_wrap
		generic map (
			--g_OUTREG_A => 1,
			g64_n32BitRam	=> 0,
			gLoop_Delay		=> 0,
			g_Tunnel		=> C_TUNNEL,
			g_TX_DATA_Z1	=> 1
		)
		PORT MAP(
			i_ppc_dom_clk		=> busclk		, -- unused
			i_Q125				=> clk125		,
			i_Q62_5				=> clk62_5		,
			o_IRQ				=> GinMasIRQ	,
			o_TxSlot_0			=> TxSlot_0		,
			o_SynCopMas			=> Gin_TlgSyn(0),
			o_fwGMII_TxDat		=> GIN_GMII_TxDat	,
			o_fwGMII_TxDv		=> GIN_GMII_TxDv	,
			o_fwGMII_TxErr		=> GIN_GMII_TxErr	,
			i_bwGMII_RxDat		=> Gin_GMII_RxDat,
			i_bwGMII_RxDv		=> Gin_GMII_RxDv	,
			i_bwGMII_RxErr		=> Gin_GMII_RxErr,
			i_AutoCloseEN		=> gin_flg_AutoCloseEN,
			i_fPhyLinkDown		=> gin_fPhyLinkDown,
			i_bPhyLinkDown		=> gin_bPhyLinkDown,
			i_GinRing			=> gin_flg_ringmode,
			o_EthRun			=> open			,
			o_GinRun			=> fwGinRun		,
			o_Mac2Tun_En		=> Mac2Tun_En	,
			i_Mac2Tun_Req		=> Mac2Tun_Req	,
			i_ExtTxData			=> Mac2Tun_D	,
			o_ExtRxDv			=> ExtRxDv		,
			o_ExtRxData			=> ExtRxData	,
			i_BRAM_Clk			=> Gin_BRAM_Clk	,
			i_BRAM_EN			=> Gin_BRAM_EN	,
			i_BRAM_WEN			=> Gin_BRAM_WEN	,
			i_BRAM_Addr			=> Gin_BRAM_Addr(15 downto 0),
			i_BRAM_Dout			=> Gin_BRAM_Dp2r,
			o_BRAM_Din			=> Gin_BRAM_Dr2p
		);

		uWrap_GinIrqWdog: entity gin_link.Gin_WatchDog_1ms
		port map (
			i_Q62_5			=> clk62_5,
			i_Probe			=> TxSlot_0,	
			o_Wdog			=> nWDog_Gin
		);
		
		tunnel: if (C_TUNNEL=1) generate
			signal Tun_IRQs			: std_logic_vector(7 downto 0) := (others => L);
			signal Tun_BRAM_Clk		: std_logic;
			signal Tun_BRAM_WEN		: std_logic_vector(3 downto 0);
			signal Tun_BRAM_Addr	: std_logic_vector(21 downto 0);
			signal Tun_BRAM_Dp2r	: std_logic_vector(31 downto 0);
		begin
		
			Tun_BRAM_WEN <= Eth_BRAM_WEN;
			Tun_BRAM_Clk <= Eth_BRAM_Clk;
			Tun_BRAM_Addr <= Eth_BRAM_Addr;
			Tun_BRAM_Dp2r <= Eth_BRAM_Dp2r;
			
			TunIRQ <= Tun_IRQs(3); -- ICU

			uTop_Ethernet: entity gin_eth.GE_TunnelMAC
			generic map (
				--g_OUTREG_A => DF_OUTREG,
				g64_n32BitRam => 0,
				g_NoBufferPair => g_NoBufferPair
			)
			port map (
				i_ppc_dom_clk		=> busclk		, --used for irq synch.
				o_IRQs				=> Tun_IRQs		,
				i_Q62_5				=> clk62_5		,
				i_MulitBufEn		=> H			,
				o_Mac2Tun_D			=> Mac2Tun_D	,
				o_Mac2Tun_Req		=> Mac2Tun_Req	,
				i_Mac2Tun_En		=> Mac2Tun_En	,	
				i_Tun2Mac_D			=> ExtRxData	,
				i_Tun2Mac_Dv		=> ExtRxDv		,
				o_TxEthRun			=> open			,
				o_RxEthRun			=> open			,
				i_BRAM_Clk			=> Tun_BRAM_Clk	,
				i_BRAM_EN			=> Tun_BRAM_EN	,
				i_BRAM_WEN			=> Tun_BRAM_WEN	,
				i_BRAM_Addr			=> Tun_BRAM_Addr(15 downto 0),
				i_BRAM_Dout			=> Tun_BRAM_Dp2r,
				o_BRAM_Din			=> Tun_BRAM_Dr2p
			);
			
		end generate tunnel;

	end generate gm;

	-- gin salve ---------------------------------------------------------------

	ms3 : if C_GIN_MASTERnSLAVE=0 and C_DUAL_ETH=0 generate
		signal Mac2Tun_D		: std_logic_vector(15 downto 0) := (others => L);
		signal Mac2Tun_En		: std_logic := L;
		signal Mac2Tun_Req_ack	: std_logic := L;
		signal Mac2Tun_Req		: std_logic := L;
		signal Tun2Mac_D		: std_logic_vector(15 downto 0) := (others => L);
		signal Tun2Mac_Dv		: std_logic := L;
		signal Eth2Gin_Dat		: std_logic_vector( 7 downto 0) := (others => L);
		signal Eth2Gin_Dv		: std_logic := L;
		signal Eth2Gin_Err		: std_logic := L;
		signal Gin2Eth_Dat		: std_logic_vector( 7 downto 0) := (others => L);
		signal Gin2Eth_Dv		: std_logic := L;
		signal Gin2Eth_Err		: std_logic := L;
		signal Eth2Gin_Busy		: std_logic := L;
	begin
		-- Gin and Eth ;bw_con == Ethernet
		Gin_bwGMII_RxDat	<= triGMII_RxDat1   when Sw_Gin_Eth=L else x"00";
		Gin_bwGMII_RxDv		<= triGMII_RxDv1    when Sw_Gin_Eth=L else L;
		Gin_bwGMII_RxErr	<= triGMII_RxErr1   when Sw_Gin_Eth=L else L;
		Eth_GMII_RxDat		<= triGMII_RxDat1   when Sw_Gin_Eth=H else Gin2Eth_Dat;
		Eth_GMII_RxDv		<= triGMII_RxDv1    when Sw_Gin_Eth=H else Gin2Eth_Dv;
		Eth_GMII_RxErr		<= triGMII_RxErr1   when Sw_Gin_Eth=H else Gin2Eth_Err;

		triGMII_TxDat1		<= Gin_fwGMII_TxDat when Sw_Gin_Eth=L else Eth_GMII_TxDat;
		triGMII_TxDv1		<= Gin_fwGMII_TxDv  when Sw_Gin_Eth=L else Eth_GMII_TxDv;
		triGMII_TxErr1		<= Gin_fwGMII_TxErr when Sw_Gin_Eth=L else Eth_GMII_TxErr;
		
		Eth2Gin_Dat			<= Eth_GMII_TxDat when Sw_Gin_Eth=L else x"00";
		Eth2Gin_Dv			<= Eth_GMII_TxDv  when Sw_Gin_Eth=L else L;
		Eth2Gin_Err			<= Eth_GMII_TxErr when Sw_Gin_Eth=L else L;
		
		Eth_GMII_data_en	<= GMII_data_en	when Sw_Gin_Eth=H else H;
		Eth_GMII_Q125en		<= GMII_Q125en	when Sw_Gin_Eth=H else H;
		Eth_GMII_TX_Busy	<= L			when Sw_Gin_Eth=H else Eth2Gin_Busy;

		Gin_fwGMII_RxDat	<= GMII_RxDat0;
		Gin_fwGMII_RxDv		<= GMII_RxDv0;
		Gin_fwGMII_RxErr	<= GMII_RxErr0;

		GMII_TxDat0		<= Gin_bwGMII_TxDat;
		GMII_TxDv0		<= Gin_bwGMII_TxDv;
		GMII_TxErr0		<= Gin_bwGMII_TxErr;

		g_2port_mas : if (C_ENABLE_3PORT_MASTER = 0) generate
			uTop_GSlave: entity gin_slave.gs_wrap
			generic map (
				g64_n32BitRam	=> 0,
				g_Tunnel		=> C_TUNNEL
			)
			port map (
				i_Q62_5			=> clk62_5,
				i_Q125			=> clk125,
				i_xChanger		=> bwGinxChanger,
				o_PgIRQs		=> PgIRQs,
				o_IRQ			=> GinSlvIRQ	,
				o_PgWdogs		=> Gin_Wdogs,
				o_PgTlgSyn		=> Gin_TlgSyn,
				o_GF_Flags		=> GF_Flags,
				o_SlvFlags		=> Gin_SlvFlags,
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
				i_BRAM_Clk		=> Gin_BRAM_Clk,
				i_BRAM_EN		=> Gin_BRAM_EN,
				i_BRAM_WEN		=> Gin_BRAM_WEN,
				i_BRAM_Addr		=> Gin_BRAM_Addr(15 downto 0),
				i_BRAM_Dout		=> Gin_BRAM_Dp2r,
				o_BRAM_Din		=> Gin_BRAM_Dr2p,
				i_linkState0	=> linkState0,
				i_linkState1	=> linkState1,
				i_Mac2Tun_D		=> Mac2Tun_D	,
				i_Mac2Tun_Req	=> Mac2Tun_Req	,
				o_Mac2Tun_En	=> Mac2Tun_En	,
				o_Mac2Tun_Req_ack=> Mac2Tun_Req_ack	,
				o_Tun2Mac_D		=> Tun2Mac_D	,
				o_Tun2Mac_Dv	=> Tun2Mac_Dv
			);
		end generate g_2port_mas;
		
		g_3port_mas : if (C_ENABLE_3PORT_MASTER = 1) generate
			uTop_GSlave: entity gin_slave.gs_8k_wrap
			generic map (
				g64_n32BitRam	=> 0,
				-- FirstPort to CPU
				g_FirstPort	=> 1,
				-- Second Port 32Bit to C64-Master)
				g_SecondPort 	=> 1,
				g_Tunnel		=> C_TUNNEL
			)
			port map (
				i_Q62_5			=> clk62_5,
				i_Q125			=> clk125,
				i_xChanger		=> bwGinxChanger,
				o_PgIRQs		=> PgIRQs,
				o_IRQ			=> GinSlvIRQ	,
				o_PgWdogs		=> Gin_Wdogs,
				o_PgTlgSyn		=> Gin_TlgSyn,
				o_GF_Flags		=> GF_Flags,
				o_SlvFlags		=> Gin_SlvFlags,
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
				i_FP_Clk		=> Gin_BRAM_Clk,
				i_FP_EN			=> Gin_BRAM_EN,
				i_FP_WEN		=> Gin_BRAM_WEN,
				i_FP_Addr		=> Gin_BRAM_Addr(15 downto 0),
				i_FP_WrData		=> Gin_BRAM_Dp2r,
				o_FP_RdData		=> Gin_BRAM_Dr2p,
				-- second-port to C64-master, always 32Bit
				i_SP_Clk		=> clk125,
				i_SP_EN			=> gc2Port_SP_EN,
				i_SP_WEN 		=> gc2Port_SP_WEN,
				i_SP_Addr		=> gc2Port_SP_Addr,
				i_SP_WrData		=> gc2Port_SP_Dc2g,
				o_SP_RdData		=> gc2Port_SP_Dg2c,
				i_linkState0	=> linkState0,
				i_linkState1	=> linkState1,
				i_8k3p_Enable	=> GinFlags(GF_8K3P),
				i_Mac2Tun_D		=> Mac2Tun_D	,
				i_Mac2Tun_Req	=> Mac2Tun_Req	,
				o_Mac2Tun_En	=> Mac2Tun_En	,
				o_Mac2Tun_Req_ack=> Mac2Tun_Req_ack	,
				o_Tun2Mac_D		=> Tun2Mac_D	,
				o_Tun2Mac_Dv	=> Tun2Mac_Dv
			);
		end generate g_3port_mas;
		
		uWrap_GinIrqWdog: entity gin_link.Gin_WatchDog_1ms
		port map (
			i_Q62_5			=> clk62_5      ,
			i_Probe			=> Gin_Wdogs(3) ,	-- fast-channel access
			o_Wdog			=> nWDog_Gin
		);
		
		tt: if C_TUNNEL/=0 generate
		begin
		
			uTunnel2GMII: entity gin_eth.GE_Tunnel2GMII
			generic map (
				C_NO_OF_TXBUFFER => 0, -- for connecting to gin_eth, no buffers are necessary
				C_NO_OF_RXBUFFER => 1
			)
			port map (
				i_Q125			=> clk125	,
				i_Q62_5			=> clk62_5	,
				i_GMII_RX_Data_Valid_EN	=> H	,
				i_GMII_TX_CLK_EN		=> H	,
				
				o_GMII_TxDat	=> Gin2ETH_Dat	,	
				o_GMII_TxDv		=> Gin2ETH_Dv	,	
				o_GMII_TxErr	=> Gin2ETH_Err	,	

				i_GMII_RxDat	=> ETH2Gin_Dat	,
				i_GMII_RxDv		=> ETH2Gin_Dv	,
				i_GMII_RxErr	=> ETH2Gin_Err	,
				
				o_Mac2Tun_D		=> Mac2Tun_D	,
				o_Mac2Tun_Req	=> Mac2Tun_Req	,
				i_Mac2Tun_En	=> Mac2Tun_En	,
				i_Mac2Tun_Req_ack => Mac2Tun_Req_ack,
				i_Tun2Mac_D		=> Tun2Mac_D	,
				i_Tun2Mac_Dv	=> Tun2Mac_Dv	,
				
				o_RX_busy => Eth2Gin_Busy
			);
			
		end generate tt;
		
	end generate;
--------------------------------------------------------------------------------
-- synch signals from 62.5mHz to busclk
--------------------------------------------------------------------------------
	clk_dom_change : process(busclk) begin
		if rising_edge(busclk) then
			o_Bus_WDog_Gin_3 <= not nWDog_Gin;
		end if;
	end process;

	o_clk125 <= clk125;
	o_clk62_5 <= clk62_5;
	o_clk25 <= clk25;
	
	copbus : if C_BRAMIF_nCOPBUS=0 generate
	signal ByteAdr : std_logic_vector(15 downto 0);
	begin
		ByteAdr <= "0" & C64_BRAM_Addr(12 downto 0) & "00";	
			process(C64_BRAM_Clk) begin
				if rising_edge(C64_BRAM_Clk) then

					
					if ((ByteAdr=x"0320" or ByteAdr=x"0328" or ByteAdr=x"0324" or ByteAdr=x"032C") and C64_BRAM_WEN/=0) then
						o_AddrWrite <= H;
					else
						o_AddrWrite <= L;
					end if;
					
				end if;
			end process;

	
	
		inst_cop_mas : entity C64_Master.cop_master
		generic map (
			C_REVISION		=> C_REVISION	,
			C_DEV_BUILD		=> C_DEV_BUILD	,
			DF_TESTMODE		=> DF_TESTMODE	,
			C_EMG_SYS		=> C_EMG_SYS	,
			g64_n32BitRam	=> 0			,
			g_Extern_Q25	=> 0			,
			g_patch_ee_addr	=> g_patch_ee_addr,
			g_patch_addr_f	=> g_patch_addr_f,	
			g_patch_addr_t	=> g_patch_addr_t,	
			C_ENABLE_3PORT_MASTER => C_ENABLE_3PORT_MASTER,
			C_GIN_MASTERnSLAVE	=> C_GIN_MASTERnSLAVE,
			g_CRCChecker => g_CRCChecker,
			g_MEM_RdD_REG => 1
		)
		port map (
			i_Q125 			=> clk125		,
			i_Q25 			=> clk25		,
			i_TlgIrq		=> Gin_TlgSyn	,	-- clk_dom 62.5 to 125
			o_IRQs			=> Cop_IRQs		,
			i_GinLink_Wdog	=> not nWDog_Gin,  -- clk_dom 62.5 to 125 

			i_BRAM_Clk		=> C64_BRAM_Clk,
			i_BRAM_EN		=> C64_BRAM_EN,
			i_BRAM_WEN		=> C64_BRAM_WEN,
			i_BRAM_Addr		=> C64_BRAM_Addr(15 downto 0),
			i_BRAM_Dp2r		=> C64_BRAM_Dp2r,
			o_BRAM_Dr2p		=> C64_BRAM_Dr2p,
			
			o_SP_EN			=> gc2Port_SP_EN,
			o_SP_WEN		=> gc2Port_SP_WEN,
			o_SP_Addr		=> gc2Port_SP_Addr,
			o_SP_Dc2g		=> gc2Port_SP_Dc2g,
			i_SP_Dg2c		=> gc2Port_SP_Dg2c,

			i_SlvInt_Ack_OE		=> i_SlvInt_Ack_OE,
			i_SlvInt_Slv2Mas	=> i_SlvInt_Slv2Mas,
			i_SlvInt_Dat_HOE	=> i_SlvInt_Dat_HOE,
			i_SlvInt_Dat_LOE	=> i_SlvInt_Dat_LOE,
			o_SlvInt_Mas2Slv	=> o_SlvInt_Mas2Slv,
			o_SlvInt_Reset		=> o_SlvInt_Reset,
			o_SlvInt_ClkEn		=> o_SlvInt_ClkEn,
			o_SlvInt_SEL		=> o_SlvInt_SEL,
			o_SlvInt_Bend		=> o_SlvInt_Bend,

			o_C64_Reset		=> o_C64_Reset,
			o_C64_CLK		=> o_C64_CLK,
			no_C64_CLK		=> no_C64_CLK,
			o_C64_SEL		=> o_C64_SEL,
			o_C64_Bend		=> o_C64_Bend,
			b_C64_Data		=> b_C64_Data,
			nb_C64_Ack		=> nb_C64_Ack,
			o_C64_RES		=> o_C64_RES,
			
			o_C64_I2C_SCL 	=> o_C64_I2C_SCL,
			i_C64_I2C_SDA 	=> i_C64_I2C_SDA,
			o_C64_I2C_SDA   => o_C64_I2C_SDA,
			o_C96_I2C_SCL	=> o_C96_I2C_SCL,
			i_C96_I2C_SDA	=> i_C96_I2C_SDA,
			o_C96_I2C_SDA 	=> o_C96_I2C_SDA,
			i_eep_i2c_acpt	=> i_eep_i2c_acpt,
			o_eep_i2c_req	=> o_eep_i2c_req,
			
			i_HWRev			=> i_HWRev,
			i_AddrSw		=> AddrSw,
			b_jtagTCK		=> b_jtagTCK,
			b_jtagTMS		=> b_jtagTMS,
			b_jtagTDI		=> b_jtagTDI,
			b_jtagTDO		=> b_jtagTDO,
			i_TestModeOE	=> i_TestModeOE,
			i_8k3p_Enable	=> GinFlags(GF_8K3P)
		);
	end generate copbus;

	no_copbus : if C_BRAMIF_nCOPBUS=1 generate
		o_BRAM_Clk			<= C64_BRAM_Clk;
		o_BRAM_EN			<= C64_BRAM_EN;
		o_BRAM_WEN			<= C64_BRAM_WEN;
		o_BRAM_Addr			<= C64_BRAM_Addr(21 downto 0);
		o_BRAM_Dp2r			<= C64_BRAM_Dp2r;
		C64_BRAM_Dr2p		<= i_BRAM_Dr2p;
		
		-- for rtc over gpio i2c
		o_C96_I2C_SCL		<= Flags(DF_FLG_SCL);
		C96_I2C_SDA			<= i_C96_I2C_SDA;
		o_C96_I2C_SDA		<= Flags(DF_FLG_SDA);
				
		o_SlvInt_Mas2Slv	<=  (others => L);
		o_SlvInt_Reset		<=  H;

		o_SlvInt_CLKen		<=  L;
		o_SlvInt_SEL		<=  L;
		o_SlvInt_Bend		<=  L;
		o_C64_Reset			<=  H;
		o_C64_CLK			<=  L;
		no_C64_CLK			<=  L;
		o_C64_SEL			<=  L;
		o_C64_Bend			<=  L;
		o_C64_res			<=  L;
		o_C64_I2C_SCL		<=  H;
	end generate no_copbus;
			
		
	FanPwmCtrl : if (C_PWMFAN=1) generate
		signal Tacho			: std_logic := L;
		signal nFan				: std_logic := L;
		
		signal FanPwm			: std_logic_vector(6 downto 0) := (others => L);
		signal FanPwmCnt		: std_logic_vector(6 downto 0) := (others => L);
		signal precnt			: std_logic_vector(16 downto 0) := (others => L);
		signal postcnt			: std_logic_vector(4 downto 0) := (others => L);
		signal FanPwmOut		: std_logic := L;
		signal FanPwmWr			: std_logic := L;
		signal postcnten		: std_logic := L;
		signal new_fan_val_n	: std_logic_vector(2 downto 0) := (others => L);
	begin
		--no_FAN_PWM <= L when FanPwmOut=H else Z;
		-- tri-state in top entity only
		no_FAN_PWM <= FanPwmOut;

		fan_ctrl : process(clk125)
		begin
			if rising_edge(clk125) then 
				new_fan_val_n <= new_fan_val_n(new_fan_val_n'high-1 downto 0) & new_fan_val;
				precnt <= precnt + 1;
				postcnten <= L;
				-- prescale to
				if (precnt=0) then
					FanPwmCnt <= FanPwmCnt + 1;
					-- reset 
					if (FanPwmCnt=99) then
						FanPwmCnt <= (others => L);
						postcnten <= H;
					end if;
					
					if (FanPwmCnt>=FanPwm) then
						FanPwmOut <= L;
					else
						FanPwmOut <= H;
					end if;

					if (FanPwmCnt=FanPwm or FanPwm>99) then
						--tacho <= i_FAN_Tacho;
					end if;
				end if;

				if (new_fan_val_n(new_fan_val_n'high-1)=H and new_fan_val_n(new_fan_val_n'high)=L) then
					FanPwm <= Flags(FLG_FAN_PWM_H downto FLG_FAN_PWM_L);
					FanPwmWr <= H;
				end if;
				
				-- wdog
				if (postcnten=H) then
					postcnt <= postcnt + 1;
					if (postcnt=0) then
						if (FanPwmWr=L) then
							FanPwm <= conv_std_logic_vector(100,7);
						end if;
						FanPwmWr <= L;
					end if;
				end if;
			end if;
		end process fan_ctrl;
	end generate FanPwmCtrl;	

--------------------------------------------------------------------------------
end architecture rtl;-- of cop_mas2_module
