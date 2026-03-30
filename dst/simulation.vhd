--------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.math_real.all;

entity simulation is
end simulation;

architecture arc_simulation of simulation is

	constant DF_CLK_TIME  : time := (1.0 us)/1000.0;
	constant DF_BIT_WIDTH : integer range 1 to 16 := 14;

	function log2 (numerus : integer) return integer is 		-- Calculate the logarithm of a Number
		variable temp      : integer := numerus;
		variable logarithm : integer := 1;
		
	begin
		while (temp > 1) loop
			temp := temp / 2;
			logarithm := logarithm + 1;
		end loop;
		
		return logarithm;
	end function log2;
	
	signal clk 			: std_logic := '0';
	signal i_start		: std_logic := '0';
	signal o_done		: std_logic;
	signal i_divisor	: std_logic_vector(DF_BIT_WIDTH - 1 downto 0) := (others => '0');
	signal i_dividend	: std_logic_vector(DF_BIT_WIDTH - 1 downto 0) := (others => '0');
	signal o_result		: std_logic_vector(DF_BIT_WIDTH - 1 downto 0);
	signal o_rest		: std_logic_vector(DF_BIT_WIDTH - 1 downto 0);
	
	signal int_division : integer;
	signal int_rest : integer;
	signal real_division : real;
	signal loginput : integer := 0;
	signal logoutput : integer := 0;
	
	function intToStlv (intvalue : integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(intvalue, i_dividend'length));
	end function intToStlv;
begin
	
	clock : process
	begin
		clk <= '0';
		wait for DF_CLK_TIME / 2.0;
		clk <= '1';
		wait for DF_CLK_TIME / 2.0;
	end process clock;
	
	divice_under_test : entity work.division
	generic map (
		DF_BIT_WIDTH => DF_BIT_WIDTH
	)
	port map (
		i_clk 		=> clk,
		i_start		=> i_start,
		o_done		=> o_done,
		i_divisor	=> i_divisor,
		i_dividend	=> i_dividend,
		o_result	=> o_result,
		o_rest		=> o_rest
	);
	
	inputs : process
		variable int_res : integer:=0;
	begin
		i_dividend <= intToStlv(137);
		i_divisor <= intToStlv(0);
		wait for DF_CLK_TIME * 9.0;
		wait until rising_edge(clk);
		i_start <= '1';
	--	int_division <= to_integer(unsigned(i_dividend))/to_integer(unsigned(i_divisor));
	--	int_rest <= (to_integer(unsigned(i_dividend)) mod to_integer(unsigned(i_divisor)));
	--	real_division <= real(to_integer(unsigned(i_dividend)))/real(to_integer(unsigned(i_divisor)));
		
		wait until rising_edge(clk);
		i_start <= '0';
		wait until rising_edge(clk);
		wait until o_done = '1';
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		
		i_divisor <= std_logic_vector(to_unsigned(1,DF_BIT_WIDTH));
		i_dividend <= std_logic_vector(to_unsigned(0,DF_BIT_WIDTH));
		
		while 1=0 loop
			wait until rising_edge(clk);
			i_start <= '1';
			wait until rising_edge(clk);
			i_start <= '0';
			wait until o_done='1';
			wait until rising_edge(clk);
			
			int_res := to_integer(unsigned(i_dividend))/to_integer(unsigned(i_divisor));
			assert unsigned(o_result)=int_res report "feher unsigned" severity  failure;
			assert unsigned(o_rest)=(to_integer(unsigned(i_dividend))rem to_integer(unsigned(i_divisor))) report "feher rest unsigned" severity  failure;
			if (unsigned(i_dividend) = 2**(DF_BIT_WIDTH)-1) then
				i_dividend <= std_logic_vector(to_unsigned(0,DF_BIT_WIDTH));
				i_divisor <= std_logic_vector(unsigned(i_divisor)+1);
			else
				i_dividend <= std_logic_vector(unsigned(i_dividend)+1);
			end if;
			if (unsigned(i_divisor) = 2**(DF_BIT_WIDTH)-1) then
				assert false report "ende" severity  failure;
			end if;
			
			
			
		end loop;
		
		wait;
	end process inputs;
	
	logtest : process
	begin
		logoutput <= log2(loginput);
		loginput <= loginput + 1;
		wait until rising_edge(clk);
		
	end process logtest;
		
	
end architecture arc_simulation;

