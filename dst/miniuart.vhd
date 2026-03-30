--------------------------------------------------------------------------------
--  miniuart.vhd
--------------------------------------------------------------------------------
--
--	project     : 
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 24.04.2008
--	version     : 
--	language    : VHDL
--
--	purpose
--		miniuart
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	30.04.2008-le:	- start
--------------------------------------------------------------------------------
--$Rev:: 685                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-10-22 10:15:36 +0200 (Mi, 22 Okt 2008)                          $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library miniuart;
use miniuart.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity miniuart is
	generic (
		C_EXT_BR_GENERATOR : integer range 0 to 1 := 0
	);
	port (
		i_clk : in std_logic;
		i_reset : in std_logic;
		i_clk_en : in std_logic := L;
		--serial data
		o_TX		: out std_logic;
		i_RX		: in std_logic;
		-- config
		i_cfg : in  std_logic_vector(1 downto 0) := "00";
		i_br : in  std_logic_vector(9 downto 0) := "0000110101";
		-- rx
		o_Data : out std_logic_vector(7 downto 0);
		o_DataStr : out std_logic;
		o_PErr : out std_logic;
		o_Ferr : out std_logic;
		-- tx
		i_Data : in std_logic_vector(7 downto 0);
		o_ready : out std_logic;
		i_send : in std_logic
	);
end;                                                -- of entity miniuart

architecture behavior_miniuart of miniuart is
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal br_cnt : unsigned(9 downto 0) := (others => L);
	signal clk_en : std_logic := L;
	signal rx : std_logic := L;
	signal rx_n1 : std_logic := L;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin

	sync_rx : process (i_clk)
	begin
		if rising_edge(i_clk) then
			rx_n1 <= i_RX;
			rx <= rx_n1;
		end if;
	end process sync_rx;
	
	int_br_gen : if C_EXT_BR_GENERATOR=0 generate
	begin
		baudrate : process (i_clk)
		begin
			if rising_edge(i_clk) then
				if br_cnt = 0 then
					br_cnt <= unsigned(i_br);
					clk_en <= H;
				else
					br_cnt <= br_cnt - 1;
					clk_en <= L;
				end if;
			end if;
		end process baudrate;
	end generate int_br_gen;
		
	ext_br_gen : if C_EXT_BR_GENERATOR=1 generate
	begin
		clk_en <= i_clk_en;
	end generate ext_br_gen;
	
	rx_inst : entity miniuart.miniuart_rx
	port map (
		i_clk => i_clk,
		i_reset => i_reset,
		i_clk_en => clk_en,
		--serial data
		i_RX => rx,
		-- interface
		i_cfg => i_cfg,
		o_Data => o_Data,
		o_DataStr=>o_DataStr,
		o_PErr => o_PErr,
		o_Ferr => o_Ferr
	);
	
	tx_inst : entity miniuart.miniuart_tx
	port map (
		i_clk => i_clk,
		i_reset => i_reset,
		i_clk_en => clk_en,
		--serial data
		o_TX => o_TX,
		-- interface
		i_cfg => i_cfg,
		i_Data => i_Data,
		o_ready => o_ready,
		i_send => i_send
	);
	
end behavior_miniuart;
--------------------------------------------------------------------------------

