--------------------------------------------------------------------------------
--$Rev:: 5416                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-11-22 13:53:46 +0100 (Fr., 22 Nov 2019)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity tb is
end tb;

architecture arc_tb of tb is

constant DF_CLK_TIME : time := (1.0 us)/66.0;

constant H          : std_logic := '1';
constant L          : std_logic := '0';
constant Z          : std_logic := 'Z';

signal clk 			: std_logic := L;
signal Switch		: std_logic_vector(7 downto 0) := (others => L);
signal nSwitch		: std_logic_vector(7 downto 0) := (others => L);
signal Seg			: std_logic_vector(6 downto 0) := (others => L);



begin
	
	clocki : process
	begin
		clk <= L;
		wait for DF_CLK_TIME / 2.0;
		clk <= H;
		wait for DF_CLK_TIME / 2.0;
	end process clocki;
	
	inputs : process
	
	begin
		wait for 1000 ns;
		Switch <= std_logic_vector(unsigned(Switch)+1);
	end process inputs;
	
	
	nSwitch <= not Switch;
	
	divice_under_test: entity work.Siebensegment
	port map (
		 i_clk => clk,
		-- switch
		 in_switch => nSwitch,
		 o_7Seg	 => Seg
	);
	
end arc_tb;