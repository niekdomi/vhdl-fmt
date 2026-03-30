--------------------------------------------------------------------------------
--	RGMII_if_v4.vhd
--------------------------------------------------------------------------------
--
--	project     : RGMII_if
--	programmer  : C. Leuthold, INDEL AG
--	date        : 01.02.2008
--	version     : 1.00
--	language    : VHDL
--	system      : ise / v2p
--
--	purpose
--		RGMII interface for virtex 4
--		Gigabit:
--		  txclk 125mhz, clk enable always H. byte in and output.
--		  rx data are synchronized to tx_clk.
--		10 and 100Mbps
--		  This interface will operate at 10 and 100Mbps speeds exactly the same 
--		  way it does at Gigabit speed with the exception that the data may be 
--		  duplicated on the falling edge of the appropriate clock:
--		  TXdata: set external i_data(0..3)=i_data(4..8). txclk use a clk enable
--		  the rxclk is 25mhz or 2,5mhz from phy. nible output.
--		
--------------------------------------------------------------------------------
-- revision information
--	18.05.2011-le	: - create rgmii if for spartan 6
--	07.06.2011-le	: - rename rx clk enable
--	18.01.2017-le	: - add generic C_IOSTANDARD to avoid ise warnings on e.g.
--						3.3V io banks
--	13.04.2017-le	: - correct input ddr to remove a 4ns crossing
--------------------------------------------------------------------------------
--$Rev:: 4414                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-04-13 13:17:58 +0200 (Do., 13 Apr 2017)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library Unisim;
use Unisim.vcomponents.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity RGMII_if is
generic (
	C_ELASTIC_BUF_LAT : integer range 3 to 8 := 5;
	C_DATA_DELAY_TABS : integer range 0 to 255 := 20;
	C_USE_EXTRA_REG : integer range 0 to 1 := 0;
	C_IOSTANDARD : string :=  "LVCMOS25"
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
	o_PHY_RXCBUF : out std_logic;
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
	----------------------------------------------------------------------------
	-- constants 
	----------------------------------------------------------------------------
	--constant C_DATA_DELAY_TABS : integer := 5; -- v4 idelay tab is 75ps
	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------
	
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal net_gnd : std_logic := L;
	signal net_vcc : std_logic := H;
	-- clocks
	signal phy_RX_clk : std_logic;
	signal nphy_RX_clk : std_logic;
	signal RX_C_ibufg : std_logic;
	signal RX_C2_ibufg : std_logic;
	-- rx
	signal rx_d : std_logic_vector(7 downto 0);
	signal rx_err : std_logic;
	signal rx_en : std_logic;
	
	signal rx_d_1 : std_logic_vector(7 downto 0);
	signal rx_err_1 : std_logic;
	signal rx_en_1 : std_logic;
	
	
	signal rx_err_dec : std_logic;
	signal rx_we : std_logic;
	signal w_addr : std_logic_vector(3 downto 0) := (others => L);
	signal start_read : std_logic_vector(C_ELASTIC_BUF_LAT downto 0) := (others => L);
	signal cnt : std_logic_vector(2 downto 0) := (others => L);
	signal r_addr : std_logic_vector(3 downto 0) := (others => L);
	signal PHY_RXD_delayed : std_logic_vector(3 downto 0);
	signal PHY_RXDV_delayed : std_logic;
	
	signal eb_RX_en : std_logic;
	signal eb_RX_err : std_logic;
	signal eb_RX_d : std_logic_vector(7 downto 0);
	
	signal rx_data_valid : std_logic;
	signal rx_data_error : std_logic;
	signal rx_data : std_logic_vector(7 downto 0);
	
	-- tx
	signal tx_err : std_logic;
	
	
	signal Q1 : std_logic_vector(4 downto 0) := (others => L);
	signal Q2 : std_logic_vector(4 downto 0) := (others => L);
	
	signal ntx_clk   : std_logic;
	signal clk2_n1   : std_logic;
	signal data_n1   : std_logic_vector(3 downto 0);
	signal tx_err_n1 : std_logic;
	
	signal rx_d_1_d0 : std_logic_vector(3 downto 0);
	signal rx_en_1_d0 : std_logic;
	
begin -- architecture ----------------------------------------------------------
	net_gnd <= L;
	net_vcc <= H;
	-- rx clocking -------------------------------------------------------------
	-- RX-data clocking --------------------------------------------------------
	ibufg_clk_inst : IBUFG
	generic map (
		IOSTANDARD => C_IOSTANDARD)
	port map (
		I => i_PHY_RXC,
		O => RX_C_ibufg
	);
	
	clkout_buf_inst : BUFG
	port map (
		O => phy_RX_clk,
		I => RX_C_ibufg
	);
	nphy_RX_clk <= not phy_RX_clk;
	
	o_PHY_RXCBUF <= phy_RX_clk;
	-- RX-data -----------------------------------------------------------------
	
	PHY_RXDV_delayed <= i_PHY_RXDV after C_DATA_DELAY_TABS* 75 ps;
	PHY_RXD_delayed <= i_PHY_RXD after C_DATA_DELAY_TABS* 75 ps;
	
	iddr2_inst : IDDR2
	generic map (
		DDR_ALIGNMENT  => "C0",--"NONE",
		INIT_Q0        => '0',
		INIT_Q1        => '0',
		SRTYPE         => "ASYNC")
	port map (
		Q0             => rx_en_1_d0,
		Q1             => rx_err_1,
		C0             => phy_RX_clk,
		C1             => nphy_RX_clk,
		CE             => '1',
		D              => PHY_RXDV_delayed,
		R              => '0',
		S              => '0'
	);
	
	
	rx_data_ddrffs : for i in 0 to 3 generate
	begin
		iddr2_inst : IDDR2
		generic map (
			DDR_ALIGNMENT  => "C0",--"NONE",
			INIT_Q0        => '0',
			INIT_Q1        => '0',
			SRTYPE         => "ASYNC")
		port map (
			Q0             => rx_d_1_d0(i),
			Q1             => rx_d_1(i+4),
			C0             => phy_RX_clk,
			C1             => nphy_RX_clk,
			CE             => '1',
			D              => PHY_RXD_delayed(i),
			R              => '0',
			S              => '0'
		);
	end generate rx_data_ddrffs;
	
	process(phy_RX_clk)
	begin
		if (rising_edge(phy_RX_clk)) then
			rx_d_1(3 downto 0) <= rx_d_1_d0;
			rx_en_1 <= rx_en_1_d0;
			
		end if;
	end process;
	
direct_route : if C_USE_EXTRA_REG=0 generate
begin	
	rx_d <= rx_d_1;
	rx_en <= rx_en_1;
	rx_err <= rx_err_1;
end generate direct_route;

extra_reg : if C_USE_EXTRA_REG/=0 generate	
begin	
	process(phy_RX_clk)
	begin
		if (rising_edge(phy_RX_clk)) then
			rx_d <= rx_d_1;
			rx_en <= rx_en_1;
			rx_err <= rx_err_1;
			
		end if;
	end process;
end generate extra_reg;
	
	-- rx elastic buffer -------------------------------------------------------
	rx_err_dec <= rx_en xor rx_err;
	rx_we <= H;
	wr_ctrl : process(phy_RX_clk)
	begin
		if (rising_edge(phy_RX_clk)) then
			if (rx_en=L or rx_err=L) then
				w_addr <= w_addr + 1;
				if cnt=C_ELASTIC_BUF_LAT-1 then
					start_read(0) <= L;
					w_addr <= (others => L);
				else
					cnt <= cnt + 1;
				end if;
			elsif (rx_en=H and rx_err=H) then
				w_addr <= w_addr + 1;
				start_read(0) <= H;
				cnt <= (others => L);
			end if;
		end if;
	end process wr_ctrl;
	
	rx_data_valid <= L when (start_read(C_ELASTIC_BUF_LAT-1)=L and start_read(C_ELASTIC_BUF_LAT)=L) else eb_RX_en;
	rx_data_error <= eb_RX_err;
	rx_data <= eb_RX_d;
	
	o_data_valid <= rx_data_valid;
	o_data_error <= rx_data_error;
	o_data <= rx_data;
	
	rd_ctrl : process(i_tx_clk)
	begin
		if (rising_edge(i_tx_clk)) then
			if (i_RXFIFO_clk_en=H) then
				start_read(start_read'high downto 1) <= start_read(start_read'high-1 downto 0);
				if (start_read(C_ELASTIC_BUF_LAT-1)=L and start_read(C_ELASTIC_BUF_LAT)=L) then
					r_addr <= (others => L);
				else
					r_addr <= r_addr + 1;
				end if;
			end if;
		end if;
	end process rd_ctrl;
	
	async_rx_fifo : for i in 0 to 7 generate
		RAM16X1D_data : RAM16X1D
		generic map (
			INIT => X"0000")
		port map (
			WCLK => phy_RX_clk,		-- Write clock input
			WE => rx_we,			-- Write enable input
			SPO => open,			-- R/W 1-bit data output for A0-A3
			D => rx_d(i),			-- Write 1-bit data input
			A0 => w_addr(0),		-- R/W address[0] input bit
			A1 => w_addr(1),		-- R/W address[1] input bit
			A2 => w_addr(2),		-- R/W address[2] input bit
			A3 => w_addr(3),		-- R/W address[3] input bit
			DPO => eb_RX_d(i),		-- Read-only 1-bit data output for DPRA
			DPRA0 => r_addr(0),		-- Read-only address[0] input bit
			DPRA1 => r_addr(1),		-- Read-only address[1] input bit
			DPRA2 => r_addr(2),		-- Read-only address[2] input bit
			DPRA3 => r_addr(3)		-- Read-only address[3] input bit
		);
	end generate async_rx_fifo;
	
	RAM16X1D_RX_en : RAM16X1D
	generic map (
		INIT => X"0000")
	port map (
		WCLK => phy_RX_clk,	-- Write clock input
		WE => rx_we,		-- Write enable input
		SPO => open,		-- R/W 1-bit data output for A0-A3
		D => rx_en,			-- Write 1-bit data input
		A0 => w_addr(0),	-- R/W address[0] input bit
		A1 => w_addr(1),	-- R/W address[1] input bit
		A2 => w_addr(2),	-- R/W address[2] input bit
		A3 => w_addr(3),	-- R/W address[3] input bit
		DPO => eb_RX_en,	-- Read-only 1-bit data output for DPRA
		DPRA0 => r_addr(0),	-- Read-only address[0] input bit
		DPRA1 => r_addr(1),	-- Read-only address[1] input bit
		DPRA2 => r_addr(2),	-- Read-only address[2] input bit
		DPRA3 => r_addr(3)	-- Read-only address[3] input bit
	);
	
	RAM16X1D_RX_err : RAM16X1D
	generic map (
		INIT => X"0000")
	port map (
		WCLK => phy_RX_clk,	-- Write clock input
		WE => rx_we,		-- Write enable input
		SPO => open,		-- R/W 1-bit data output for A0-A3
		D => rx_err_dec,	-- Write 1-bit data input
		A0 => w_addr(0),	-- R/W address[0] input bit
		A1 => w_addr(1),	-- R/W address[1] input bit
		A2 => w_addr(2),	-- R/W address[2] input bit
		A3 => w_addr(3),	-- R/W address[3] input bit
		DPO => eb_RX_err,	-- Read-only 1-bit data output for DPRA
		DPRA0 => r_addr(0),	-- Read-only address[0] input bit
		DPRA1 => r_addr(1),	-- Read-only address[1] input bit
		DPRA2 => r_addr(2),	-- Read-only address[2] input bit
		DPRA3 => r_addr(3)	-- Read-only address[3] input bit
	);
	
	-- tx-data -----------------------------------------------------------------
	-- Clock forwarding circuit using the double data-rate register Virtex-4/5
	tx_clk : ODDR2
	generic map(
		--DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
		DDR_ALIGNMENT => "NONE",
		INIT => '0',				-- Initial value for Q port ('1' or '0')
		SRTYPE => "SYNC")			-- Reset Type ("ASYNC" or "SYNC")
	port map (
		Q => o_PHY_GTXCLK,		-- 1-bit DDR output
		C0 => i_tx_clk,		-- 1-bit clock input
		C1 => ntx_clk,		-- 1-bit clock input
		CE => net_vcc,		-- 1-bit clock enable input
		D0 => i_clk1,				-- 1-bit data input (positive edge)
		D1 => clk2_n1,				-- 1-bit data input (negative edge)
		R => i_tx_disable,		-- 1-bit reset input
		S => net_gnd			-- 1-bit set input
	);
	
	tx_err <= i_data_valid xor i_data_error;
	tx_ctr : ODDR2
	generic map(
		--DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
		DDR_ALIGNMENT => "NONE",
		INIT => '0',				-- Initial value for Q port ('1' or '0')
		SRTYPE => "SYNC")			-- Reset Type ("ASYNC" or "SYNC")
	port map (
		Q => o_PHY_TXEN,		-- 1-bit DDR output
		C0 => i_tx_clk,		-- 1-bit clock input
		C1 => ntx_clk,		-- 1-bit clock input
		CE => net_vcc,--i_tx_clk_en,		-- 1-bit clock enable input
		D0 => i_data_valid,		-- 1-bit data input (positive edge)
		D1 => tx_err_n1,			-- 1-bit data input (negative edge)
		R => i_tx_disable,		-- 1-bit reset input
		S => net_gnd			-- 1-bit set input
	);
	
	tx_data : for i in 0 to 3 generate
		tx_data_ff : ODDR2
		generic map(
			--DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
			DDR_ALIGNMENT => "NONE",
			INIT => '0',				-- Initial value for Q port ('1' or '0')
			SRTYPE => "SYNC")			-- Reset Type ("ASYNC" or "SYNC")
		port map (
			Q => o_PHY_TXD(i),	-- 1-bit DDR output
			C0 => i_tx_clk,		-- 1-bit clock input
			C1 => ntx_clk,		-- 1-bit clock input
			CE => net_vcc,--i_tx_clk_en,	-- 1-bit clock enable input
			D0 => i_data(i),	-- 1-bit data input (positive edge)
			D1 => data_n1(i),	-- 1-bit data input (negative edge)
			R => i_tx_disable,	-- 1-bit reset input
			S => net_gnd		-- 1-bit set input
		);
	end generate tx_data;
	
	
	same_edge : process(i_tx_clk)
	begin
		if (rising_edge(i_tx_clk)) then
			clk2_n1 <= i_clk2;
			data_n1 <= i_data(7 downto 4);
			tx_err_n1 <= tx_err;
		end if;
	end process same_edge;
	
	ntx_clk <= not i_tx_clk;
	
end architecture STRUCTURE;
