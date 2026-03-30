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
--	01.02.2008-le	: - first steps
--	05.02.2008-le	: - split RGMII_if to interface and clocking
--	27.02.2008-le	: - add i_tx_disable input. reset all outputs to gnd 
--					  - add generic C_RX_DELAYED_FROM_PHY to remove rxclk 2ns delay
--	12.09.2008-le	: - ajust wr_ctrl
--					  - add clk enable to support 10 and 100Mbps
--	22.10.2008-le	: - change C_DATA_DELAY_TABS from 18 to 20 (ca. 140ps more delay)
--	07.06.2011-le	: - rename rx clk enable
--------------------------------------------------------------------------------
--$Rev:: 1966                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-06-07 11:08:17 +0200 (Di., 07 Jun 2011)                         $
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
	C_ELASTIC_BUF_LAT : integer range 3 to 8 := 5
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
	constant C_DATA_DELAY_TABS : integer := 20; -- v4 idelay tab is 75ps
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
	signal RX_C_ibufg : std_logic;
	-- rx
	signal rx_d : std_logic_vector(7 downto 0);
	signal rx_err : std_logic;
	signal rx_en : std_logic;
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
	
begin -- architecture ----------------------------------------------------------
	net_gnd <= L;
	net_vcc <= H;
	-- rx clocking -------------------------------------------------------------
	-- RX-data clocking --------------------------------------------------------
	IBUFG_RX_C : IBUFG
	port map (
		O => RX_C_ibufg, -- Clock buffer output
		I => i_PHY_RXC -- Clock buffer input (connect directly to top-level port)
	);
	
	BUFR_RX_C : BUFR
	port map (
		O => phy_RX_clk, -- Clock buffer output
		I => RX_C_ibufg, -- Clock buffer input
		CE => H, -- Clock enable input
		CLR => L -- Clock buffer reset input
	);
	
	o_PHY_RXCBUF <= phy_RX_clk;
	-- RX-data -----------------------------------------------------------------
	rx_data_delay : IDELAY
	generic map (
		IOBDELAY_TYPE => "FIXED",
		IOBDELAY_VALUE => C_DATA_DELAY_TABS
	)
	port map (
		I => i_PHY_RXDV,
		O => PHY_RXDV_delayed,
		C => net_gnd,
		CE =>net_gnd,
		INC =>net_gnd,
		RST =>net_gnd
	);
	rx_ctr_ddrff : IDDR
	generic map (
		DDR_CLK_EDGE => "SAME_EDGE_PIPELINED", -- "OPPOSITE_EDGE", "SAME_EDGE" 
		                                 -- or "SAME_EDGE_PIPELINED" 
		INIT_Q1 => '0',		-- Initial value of Q1: '0' or '1'
		INIT_Q2 => '0',		-- Initial value of Q2: '0' or '1'
		SRTYPE => "SYNC")	-- Set/Reset type: "SYNC" or "ASYNC" 
	port map (
		Q1 => rx_en,		-- 1-bit output for positive edge of clock 
		Q2 => rx_err,		-- 1-bit output for negative edge of clock
		C => phy_RX_clk,	-- 1-bit clock input
		CE => net_vcc,		-- 1-bit clock enable input
		D => PHY_RXDV_delayed,	-- 1-bit DDR data input
		R => net_gnd,		-- 1-bit reset
		S => net_gnd		-- 1-bit set
	);
	
	rx_data_ddrffs : for i in 0 to 3 generate
	begin
		rx_data_delay : IDELAY
		generic map (
			IOBDELAY_TYPE => "FIXED",
			IOBDELAY_VALUE => C_DATA_DELAY_TABS
		)
		port map (
			I => i_PHY_RXD(i),
			O => PHY_RXD_delayed(i),
			C => net_gnd,
			CE =>net_gnd,
			INC =>net_gnd,
			RST =>net_gnd
		);
		rx_data_ddrff : IDDR
		generic map (
			DDR_CLK_EDGE => "SAME_EDGE_PIPELINED", -- "OPPOSITE_EDGE", "SAME_EDGE" 
			                                 -- or "SAME_EDGE_PIPELINED" 
			INIT_Q1 => '0',		-- Initial value of Q1: '0' or '1'
			INIT_Q2 => '0',		-- Initial value of Q2: '0' or '1'
			SRTYPE => "SYNC")	-- Set/Reset type: "SYNC" or "ASYNC" 
		port map (
			Q1 => rx_d(i),		-- 1-bit output for positive edge of clock 
			Q2 => rx_d(i+4),	-- 1-bit output for negative edge of clock
			C => phy_RX_clk,	-- 1-bit clock input
			CE => net_vcc,		-- 1-bit clock enable input
			D => PHY_RXD_delayed(i),	-- 1-bit DDR data input
			R => net_gnd,		-- 1-bit reset
			S => net_gnd		-- 1-bit set
		);
	end generate rx_data_ddrffs;
	
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
	tx_clk : ODDR
	generic map(
		DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
		INIT => '0',				-- Initial value for Q port ('1' or '0')
		SRTYPE => "SYNC")			-- Reset Type ("ASYNC" or "SYNC")
	port map (
		Q => o_PHY_GTXCLK,		-- 1-bit DDR output
		C => i_tx_clk,			-- 1-bit clock input
		CE => net_vcc,		-- 1-bit clock enable input
		D1 => i_clk1,				-- 1-bit data input (positive edge)
		D2 => i_clk2,				-- 1-bit data input (negative edge)
		R => i_tx_disable,		-- 1-bit reset input
		S => net_gnd			-- 1-bit set input
	);
	
	tx_err <= i_data_valid xor i_data_error;
	tx_ctr : ODDR
	generic map(
		DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
		INIT => '0',				-- Initial value for Q port ('1' or '0')
		SRTYPE => "SYNC")			-- Reset Type ("ASYNC" or "SYNC")
	port map (
		Q => o_PHY_TXEN,		-- 1-bit DDR output
		C => i_tx_clk,			-- 1-bit clock input
		CE => net_vcc,--i_tx_clk_en,		-- 1-bit clock enable input
		D1 => i_data_valid,		-- 1-bit data input (positive edge)
		D2 => tx_err,			-- 1-bit data input (negative edge)
		R => i_tx_disable,		-- 1-bit reset input
		S => net_gnd			-- 1-bit set input
	);
	
	tx_data : for i in 0 to 3 generate
		tx_data_ff : ODDR
		generic map(
			DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
			INIT => '0',				-- Initial value for Q port ('1' or '0')
			SRTYPE => "SYNC")			-- Reset Type ("ASYNC" or "SYNC")
		port map (
			Q => o_PHY_TXD(i),	-- 1-bit DDR output
			C => i_tx_clk,		-- 1-bit clock input
			CE => net_vcc,--i_tx_clk_en,	-- 1-bit clock enable input
			D1 => i_data(i),	-- 1-bit data input (positive edge)
			D2 => i_data(i+4),	-- 1-bit data input (negative edge)
			R => i_tx_disable,	-- 1-bit reset input
			S => net_gnd		-- 1-bit set input
		);
	end generate tx_data;
end architecture STRUCTURE;
