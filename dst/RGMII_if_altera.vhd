--------------------------------------------------------------------------------
--	RGMII_if_altera.vhd
--------------------------------------------------------------------------------
--
--	project     : RGMII_if
--	programmer  : C. Leuthold, INDEL AG
--	date        : 16.11.2010
--	language    : VHDL
--
--	purpose
--		RGMII interface wrapper for altera fpgas:
--			tested in cyclone 1,4 and arria gx
--	used files:
--		RGMII_Control.vhd
--		RGMII_IN.vhd
--		RGMII_IN_CTRL.vhd
--		RGMII_OUT.vhd
--		RGMII_OUT_CTRL.vhd
--		RGMII_RX_Buffer.vhd
--
--------------------------------------------------------------------------------
-- revision information
--	16.11.2010-le	: - first steps
--	07.06.2011-le	: - add clk enables to support 10/100 speeds
--	23.07.2013-le	: - ddr input ff use inverted clk. invert the clk for all other ff to avoid a 4ns stage
--					: - add generic to generate a extra register level betwin ddrios and first combinations
--	05.02.2018-vz	: - add a dummy generic "C_IOSTANDARD", it's only used by xilinx ise tool
--------------------------------------------------------------------------------
--$Rev:: 4746                                                                  $
--$Author:: Zuellig                                                            $
--$Date:: 2018-02-05 08:58:45 +0100 (Mo., 05 Feb 2018)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity RGMII_if is
generic (
	C_ELASTIC_BUF_LAT : integer range 3 to 8 := 5;
	C_USE_EXTRA_REG : integer range 0 to 2 := 0;
	C_IOSTANDARD 	: string := "LVCMOS33"
);
port (
	-- tx clocks
	i_tx_clk : in std_logic;
	i_RXFIFO_clk_en : in std_logic := H;
	i_clk1 : in std_logic := H;
	i_clk2 : in std_logic := L;
	-- user interface
	o_data : out std_logic_vector(7 downto 0);
	o_data_valid : out std_logic;
	o_data_error : out std_logic;
	i_data : in std_logic_vector(7 downto 0) := (others => L);
	i_data_valid : in std_logic := L;
	i_data_error : in std_logic := L;
	-- rgmii
	i_PHY_RXC : in std_logic := L;
	--o_PHY_RXCBUF : out std_logic;
	o_PHY_TXD : out std_logic_vector(3 downto 0);
	o_PHY_TXEN : out std_logic;
	i_PHY_RXD : in std_logic_vector(3 downto 0) := (others => L);
	i_PHY_RXDV : in std_logic := L;
	o_PHY_GTXCLK : out std_logic;
	--
	i_tx_disable : in std_logic := L
);
end RGMII_if;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of RGMII_if is
	signal CLR_n : std_logic := H;
	
begin -- architecture ----------------------------------------------------------

	phy_if : entity work.RGMII_Control
	generic map (
		RGMII_RX_BUF_LAT_C_S_PKG => C_ELASTIC_BUF_LAT,
		C_USE_DDRFF_CLK => 1,
		C_USE_EXTRA_REG => C_USE_EXTRA_REG
	)
	PORT MAP  (
		GCLK           => i_tx_clk,
		CLR_n          => CLR_n,
		i_RXFIFO_clk_en=> i_RXFIFO_clk_en,
		i_clk1         => i_clk1,
		i_clk2         => i_clk2,
		-- User Interface
		GMII_TX_EN     => i_data_valid,
		GMII_TX_ERR    => i_data_error,
		GMII_TXD       => i_data,
		GMII_RX_DV     => o_data_valid,
		GMII_RX_ERR    => o_data_error,
		GMII_RXD       => o_data,
		-- RGMII
		PHY_RXC        => i_PHY_RXC,
		PHY_RXDV       => i_PHY_RXDV,
		PHY_RXD        => i_PHY_RXD,
		TX_Disable     => i_tx_disable,
		PHY_GTXCLK     => o_PHY_GTXCLK,
		PHY_TXEN       => o_PHY_TXEN,
		PHY_TXD        => o_PHY_TXD
	);
end architecture STRUCTURE;
