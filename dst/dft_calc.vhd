---------------------------------------------------------------------------
--
--	dft_calc.vhd
--
---------------------------------------------------------------------------
--
--	project : dft
--	programmer : C. Leuthold, INDEL AG
--	date : 15.02.2012
--	version : 1.00
--	language : VHDL
--	system : Project Navigator
--
--	purpose
--		- used for piplined calc of re and im
--			a: adc value
--			b: cos for real part, sin for imaginary part
--			c: integrator input
--			res: accumulated integrator
--			res = ((a*b)>>C_POINT) +c

--------------------------------------------------------------------------------
--$Rev:: 2710                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-02-01 16:24:17 +0100 (Fr, 01 Feb 2013)                          $
--------------------------------------------------------------------------------
---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;


--------------------------------------------------------------------------------
entity dft_calc is
	generic (
		C_LNG : positive := 32;
		C_AB_LNG : positive := 17;
		C_INDEXLNG : positive := 2;
		C_POINT : positive := 14
	);
	port (
		i_CLK : in std_logic;
		i_Start : in std_logic;
		i_index : in unsigned(C_INDEXLNG-1 downto 0);
		i_a : in signed(C_AB_LNG-1 downto 0);
		i_b : in signed(C_AB_LNG-1 downto 0);
		i_c : in signed(C_LNG-1 downto 0);
		o_index : out unsigned(C_INDEXLNG-1 downto 0);
		o_res : out signed(C_LNG-1 downto 0);
		o_done : out std_logic
	);
end;

architecture impl of dft_calc is
--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';
	signal c : signed(C_LNG-1 downto 0) := (others => L);
	signal mac : signed(2*C_AB_LNG-1 downto 0) := (others => L);
	signal index : unsigned(C_INDEXLNG-1 downto 0);
	signal done : std_logic := '0';
--------------------------------------------------------------------------------

begin

	process (i_CLK) begin
		if rising_edge(i_CLK) then
			--1: a*b + 0.5
			mac <= (i_a * i_b) + 2**C_POINT;
			c <= i_c;
			index <= i_index;
			done <= i_Start;
			--2 accu
			o_res <= c + mac(2*C_AB_LNG-1 downto C_POINT+1);
			o_index <= index;
			o_done <= done;
		end if;
	end process;
	
--------------------------------------------------------------------------------
end;
