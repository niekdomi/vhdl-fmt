--------------------------------------------------------------------------------
--	TriSpeed.vhd
--------------------------------------------------------------------------------
--
--	project     : TriSpeed
--	programmer  : C. Leuthold, INDEL AG
--	date        : 16.11.2010
--	language    : VHDL
--
--	purpose
--		TriSpeed Ethernet
--
--------------------------------------------------------------------------------
-- revision information
--	14.02.2011-le	: - first steps
--	11.09.2012-le	: - correct last data enables
--					  - run rgmii at 1G when disabled and route the data thru, 
--						but disable mac data and clk enables
--	18.11.2016-le	: - add C_PHY_TIMING to switch timming of tx clk
--------------------------------------------------------------------------------
--$Rev:: 4693                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-21 16:22:50 +0100 (Do., 21 Dez 2017)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library RGMII_if;
use RGMII_if.all;


--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity TriSpeedRGMII is
generic (
	C_ELASTIC_BUF_LAT : integer range 3 to 8 := 5;
	C_USE_EXTRA_REG : integer range 0 to 2 := 0;
	C_PHY_TIMING : integer range 0 to 1 := 0
);
port (
	-- tx clocks
	i_clk125 : in std_logic;
	i_clk62_5 : in std_logic;
	-- speed selector (LED Status Register (4..3))
	i_speed : in std_logic_vector(1 downto 0); -- 10:"10" 100:"01" else 1000
	i_disable : in std_logic := L;
	-- mac
	o_GMII_RX_Data_Valid_EN	: out std_logic;
	o_GMII_TX_CLK_EN		: out std_logic;
	o_GMII_RxDat : out std_logic_vector(7 downto 0);
	o_GMII_RxDv : out std_logic;
	o_GMII_RxErr : out std_logic;
	i_GMII_TxDat : in std_logic_vector(7 downto 0);
	i_GMII_TxDv : in std_logic;
	i_GMII_TxErr : in std_logic;
	-- rgmii
	i_PHY_RXC : in std_logic := L;
	o_PHY_TXD : out std_logic_vector(3 downto 0);
	o_PHY_TXEN : out std_logic;
	i_PHY_RXD : in std_logic_vector(3 downto 0) := (others => L);
	i_PHY_RXDV : in std_logic := L;
	o_PHY_GTXCLK : out std_logic
);
end TriSpeedRGMII;

architecture STRUCTURE of TriSpeedRGMII is
	signal clk125en			: std_logic := L;
	signal data_en : std_logic := L;
	signal HighNible : std_logic := L;
	signal data_slow : std_logic_vector(7 downto 0) := (others => L);
	signal data_slow_lw : std_logic_vector(3 downto 0) := (others => L);
	signal clkcnt : unsigned(6 downto 0) := (others => L);
	
	signal GMII_RxDv_slow	: std_logic := L;
	signal RGMII_RxDv_slow_1	: std_logic := L;
	signal GMII_RxErr_Slow	: std_logic := L;
	
	signal GMII_TxData : std_logic_vector(7 downto 0) := (others => L);
	signal GMII_TxData_l : std_logic_vector(7 downto 0) := (others => L);
	signal hn : std_logic := L;
	
	signal RGMII_clk_en			: std_logic := L;
	signal RGMII_clk_en_n1		: std_logic := L;
	signal TXclk1				: std_logic := H;
	signal TXclk2				: std_logic := L;
	signal GMII_TxDv			: std_logic := L;
	signal GMII_TxErr			: std_logic := L;
	
	type t_speed is (DF_10,DF_100,DF_1000);
	signal speed : t_speed;
	
	signal tlg62_5 : std_logic := L;
	signal tlg62_5_1 : std_logic := L;
	
	signal start : std_logic := L;
	
	signal RGMII_TxDat : std_logic_vector(7 downto 0);
	signal RGMII_TxDv : std_logic;
	signal RGMII_TxErr : std_logic;
	signal RGMII_RxDat : std_logic_vector(7 downto 0);
	signal RGMII_RxDv : std_logic;
	signal RGMII_RxErr : std_logic;
	
begin
	
	process(i_clk62_5)
	begin
		if rising_edge(i_clk62_5) then
			tlg62_5 <= not tlg62_5;
		end if;
	end process;
	
	o_GMII_TX_CLK_EN <= clk125en;
	o_GMII_RX_Data_Valid_EN <= data_en;
	
	RGMII_TxDat <= i_GMII_TxDat when speed=DF_1000 else GMII_TxData;
	RGMII_TxDv <= i_GMII_TxDv when speed=DF_1000 else GMII_TxDv;
	RGMII_TxErr <= i_GMII_TxErr when speed=DF_1000 else GMII_TxErr;
	
	o_GMII_RxDat <= RGMII_RxDat when speed=DF_1000 else data_slow;
	o_GMII_RxDv <= RGMII_RxDv when speed=DF_1000 else GMII_RxDv_slow;
	o_GMII_RxErr <= RGMII_RxErr when speed=DF_1000 else GMII_RxErr_slow;
	
	slow : process(i_clk125)
	begin
		if rising_edge(i_clk125) then
			if (i_disable=H) then
				-- disabel mac interface
				GMII_TxData <= (others => L);
				GMII_TxDv <= L;
				GMII_TxErr <= L;
				
				data_slow <= (others => L);
				GMII_RxDv_slow <= L;
				GMII_RxErr_slow <= L;
				
				data_en <= L;
				clk125en <= L;
				
				-- let rgmii_if enabled at full speed
				speed <= DF_1000;
				TXclk1 <= H;
				TXclk2 <= L;
				RGMII_clk_en <= H;
			else
				if (i_speed = "10") then
					speed <= DF_10;
				elsif (i_speed = "01") then
					speed <= DF_100;
				else
					speed <= DF_1000;
				end if;
				tlg62_5_1 <= tlg62_5;
				RGMII_clk_en_n1 <= RGMII_clk_en;
				data_en <= L;
				clk125en <= L;
				if (speed=DF_100) then
					if (clkcnt=0) then
						GMII_TxData <= i_GMII_TxDat(3 downto 0) & i_GMII_TxDat(3 downto 0);
						GMII_TxData_l <= i_GMII_TxDat(7 downto 4) & i_GMII_TxDat(7 downto 4);
						GMII_TxDv <= i_GMII_TxDv;
						GMII_TxErr <= L;
					elsif (clkcnt=5) then
						GMII_TxData <= GMII_TxData_l(7 downto 4) & GMII_TxData_l(7 downto 4);
					end if;
					-- clock
					if C_PHY_TIMING=1 then
						if (clkcnt=0) then
							TXclk1 <= L;
							TXclk2 <= L;
						elsif (clkcnt=2) then
							TXclk1 <= L;
							TXclk2 <= H;
						elsif (clkcnt=3) then
							TXclk1 <= H;
							TXclk2 <= H;
						elsif (clkcnt=5) then
							TXclk1 <= L;
							TXclk2 <= L;
						elsif (clkcnt=7) then
							TXclk1 <= L;
							TXclk2 <= H;
						elsif (clkcnt=8) then
							TXclk1 <= H;
							TXclk2 <= H;
						end if;
					else
						if (clkcnt=0) then
							TXclk1 <= L;
							TXclk2 <= H;
						elsif (clkcnt=1) then
							TXclk1 <= H;
							TXclk2 <= H;
						elsif (clkcnt=3) then
							TXclk1 <= L;
							TXclk2 <= L;
						elsif (clkcnt=5) then
							TXclk1 <= L;
							TXclk2 <= H;
						elsif (clkcnt=6) then
							TXclk1 <= H;
							TXclk2 <= H;
						elsif (clkcnt=8) then
							TXclk1 <= L;
							TXclk2 <= L;
						end if;
					end if;
				elsif (speed=DF_10) then
					if (clkcnt=0) then
						GMII_TxData <= i_GMII_TxDat(3 downto 0) & i_GMII_TxDat(3 downto 0);
						GMII_TxData_l <= i_GMII_TxDat(7 downto 4) & i_GMII_TxDat(7 downto 4);
						GMII_TxDv <= i_GMII_TxDv;
						GMII_TxErr <= L;
					elsif (clkcnt=50) then
						GMII_TxData <= GMII_TxData_l(7 downto 4) & GMII_TxData_l(7 downto 4);
					end if;
					-- clock
					if C_PHY_TIMING=1 then
						if (clkcnt=0) then
							TXclk1 <= L;
							TXclk2 <= L;
						elsif (clkcnt=25) then
							TXclk1 <= H;
							TXclk2 <= H;
						elsif (clkcnt=50) then
							TXclk1 <= L;
							TXclk2 <= L;
						elsif (clkcnt=75) then
							TXclk1 <= H;
							TXclk2 <= H;
						end if;
					else
						if (clkcnt=1) then
							TXclk1 <= H;
							TXclk2 <= H;
						elsif (clkcnt=26) then
							TXclk1 <= L;
							TXclk2 <= L;
						elsif (clkcnt=51) then
							TXclk1 <= H;
							TXclk2 <= H;
						elsif (clkcnt=76) then
							TXclk1 <= L;
							TXclk2 <= L;
						end if;
					end if;
				else -- 1000
					
				end if;
				
				-- CLK EN
				if (speed=DF_100) then
					RGMII_clk_en <= L;
					
					if (clkcnt=3) then
						RGMII_clk_en <= H;
					elsif (clkcnt=5) then
						clk125en <= H;
					elsif (clkcnt=8) then
						RGMII_clk_en <= H;
					end if;
					
					clkcnt <= clkcnt +1;
					if (clkcnt>=9) then
						if (tlg62_5=tlg62_5_1) then
							clkcnt <= (others => L);
						end if;
					end if;
				elsif (speed=DF_10) then
					RGMII_clk_en <= L;
					
					if (clkcnt=30) then
						RGMII_clk_en <= H;
					elsif (clkcnt=50) then
						clk125en <= H;
					elsif (clkcnt=80) then
						RGMII_clk_en <= H;
					end if;
					
					clkcnt <= clkcnt +1;
					if (clkcnt>=99) then
						if (tlg62_5=tlg62_5_1) then
							clkcnt <= (others => L);
						end if;
					end if;
				else -- 1000
					RGMII_clk_en <= H;
					TXclk1 <= H;
					TXclk2 <= L;
					clk125en <= H;
					clkcnt <= (others => L);
				end if;
				
				-- MII nibel to GMII byte
				if (speed/=DF_1000) then
					if (RGMII_clk_en_n1=H) then
						RGMII_RxDv_slow_1 <= RGMII_RxDv;
						if (RGMII_RxDv=H and RGMII_RxDv_slow_1=L and RGMII_RxDat(3 downto 0)=x"5") then
							start <= H;
							HighNible <= L;
						elsif (start=H and RGMII_RxDat(3 downto 0)=x"5") then
							HighNible <= H;
							data_slow_lw <= x"5";
							data_slow <= x"55";
							data_en <= H;
							GMII_RxDv_slow <= H;
							GMII_RxErr_slow <= L;
						else
							start <= L;
							if (RGMII_RxDv=H) then
								if (HighNible=H) then
									data_slow(3 downto 0) <= data_slow_lw;
									data_slow(7 downto 4) <= RGMII_RxDat(3 downto 0);
									GMII_RxDv_slow <= H;
									GMII_RxErr_slow <= L;
									HighNible <= L;
									data_en <= H;
								else
									data_slow_lw <= RGMII_RxDat(3 downto 0);
									GMII_RxDv_slow <= H;
									GMII_RxErr_slow <= L;
									HighNible <= H;
								end if;
							elsif (RGMII_RxDv_slow_1=H) then 
								if (HighNible=H) then
									data_slow(3 downto 0) <= data_slow_lw;
									data_slow(7 downto 4) <= RGMII_RxDat(3 downto 0);
									GMII_RxDv_slow <= H;
									GMII_RxErr_slow <= L;
									HighNible <= L;
									data_en <= H;
									RGMII_RxDv_slow_1 <= H; --one more
								else
									GMII_RxDv_slow <= H;
									GMII_RxErr_slow <= L;
									HighNible <= H;
								end if;
							else
								if (HighNible=H) then
									HighNible <= L;
									data_en <= H;
								else
									HighNible <= H;
								end if;
								GMII_RxDv_slow <= L;
								GMII_RxErr_slow <= L;
								data_slow <= (others => L);
							end if;
						end if;
					end if;
				else
					data_en <= H;
				end if;
			end if;
		end if;
	end process slow;
	
	
	phy_if1 : entity RGMII_if.RGMII_if
	generic map (
		C_ELASTIC_BUF_LAT => C_ELASTIC_BUF_LAT,
		C_USE_EXTRA_REG => C_USE_EXTRA_REG
	)
	port map (
		i_tx_clk		=> i_clk125,
		i_RXFIFO_clk_en	=> RGMII_clk_en,
		i_clk1			=> TXclk1,
		i_clk2			=> TXclk2,
		-- user interface
		o_data			=> RGMII_RxDat,
		o_data_valid	=> RGMII_RxDv,
		o_data_error	=> RGMII_RxErr,
		i_data			=> RGMII_TxDat,
		i_data_valid	=> RGMII_TxDv,
		i_data_error	=> RGMII_TxErr,
		-- rgmii
		i_PHY_RXC		=> i_PHY_RXC,
		o_PHY_TXD		=> o_phy_TXD,
		o_PHY_TXEN		=> o_phy_TXEN,
		i_PHY_RXD		=> i_PHY_RXD,
		i_PHY_RXDV		=> i_PHY_RXDV,
		o_PHY_GTXCLK	=> o_phy_GTXCLK
	);

end architecture STRUCTURE;
