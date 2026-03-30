--------------------------------------------------------------------------------
--  miniuart_tx.vhd
--------------------------------------------------------------------------------
--
--	project     : 
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 24.04.2008
--	version     : 
--	language    : VHDL
--
--	purpose
--		miniuart_tx
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

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity miniuart_tx is

	port (
		i_clk : in std_logic;
		i_reset : in std_logic;
		i_clk_en	: in	std_logic;
		--serial data
		o_TX		: out std_logic;
		-- interface
		i_cfg : in  std_logic_vector(1 downto 0) := (others => L);
		i_Data : in std_logic_vector(7 downto 0);
		o_ready : out std_logic;
		i_send : in std_logic
	);
end;                                                -- of entity miniuart_tx

architecture behavior_miniuart_tx of miniuart_tx is
-- constants -------------------------------------------------------------------
	constant DF_PARITY : integer := 0;
	constant DF_ODD : integer := 1;
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal parity  : std_logic := L;
	signal parity_out  : std_logic := L;
	signal cmp : std_logic := L;
	signal restart  : std_logic := L;
	signal TxData : std_logic_vector(i_Data'high+3 downto 0) := (others => L);
	signal clk_div : std_logic_vector(15 downto 0) := x"8000";
	signal sh_cnt : unsigned(3 downto 0) := "1010";
	signal index : natural range 0 to 10;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin

	o_ready <= cmp and not restart and not i_send;
	cmp <= H when (sh_cnt=10 or (sh_cnt=9 and i_cfg(DF_PARITY)=L)) else L;
	index <= conv_integer(sh_cnt);
	TxData <= H & parity_out & i_Data & L;
	o_TX <= TxData(index);
	parity_out <= (parity xor i_cfg(DF_ODD)) when i_cfg(DF_PARITY)=H else H;
	
	TX : process (i_clk)
	begin
		if rising_edge(i_clk) then
			restart <= cmp and (i_send or restart);
			if (i_reset=H) then
				sh_cnt <= "1010";
			elsif (i_clk_en=H) then
				clk_div <= clk_div(0) & clk_div(clk_div'high downto 1);
				if (clk_div(0)=H) then
					if (restart=H) then
						sh_cnt <= "0000";
						parity <= L;
					else
						parity <= TxData(index) xor parity;
						if (cmp=H) then
							sh_cnt <= "1010";
						else
							sh_cnt <= sh_cnt + 1;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process TX;
	
end behavior_miniuart_tx;
--------------------------------------------------------------------------------

