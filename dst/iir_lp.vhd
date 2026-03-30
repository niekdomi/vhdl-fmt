-------------------------------------------------------------------------------
-- iir_lp.vhd
-------------------------------------------------------------------------------
--
--	project     : iir_lp
--	programmer  : C. Leuthold, INDEL AG
--	date        : 30.04.2008
--	language    : VHDL 
--	system      : ise / Spartan3
--
--	purpose	
--		1. order iir low pass
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	30.04.2008-le - first steps
--------------------------------------------------------------------------------
--$Rev:: 409                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2008-04-25 17:11:32 +0200 (Fr, 25 Apr 2008)                          $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------

entity iir_lp is
generic (
	C_NO_OF_CH : positive := 1;
	C_DATA_LNG : positive := 16;
	C_MUL_SIZE : positive := 18;
	C_ROUND : integer range 0 to 1 := 1
);
port (
	i_Clk : in std_logic;
	i_adc_val : in signed(C_DATA_LNG-1 downto 0) := (others => L);
	i_ch_no : in unsigned(pkg_log2(C_NO_OF_CH-1) downto 0) := (others => L);
	i_calc : in std_logic := L;
	o_filtered_val : out signed(C_DATA_LNG-1 downto 0);
	o_new_val : out std_logic
);
end iir_lp;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of iir_lp is
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	constant DF_B_LNG : positive := 6;
	constant DF_NEG_B : unsigned(C_MUL_SIZE-2 downto 0) := conv_unsigned(62*2**(C_MUL_SIZE-DF_B_LNG-1), C_MUL_SIZE-1);
	constant DF_FILT_RES : positive := DF_B_LNG+C_DATA_LNG;
	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------
	type t_filt is array(0 to C_NO_OF_CH-1) of signed(DF_FILT_RES-1 downto 0);
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal filter_out : t_filt := (others => (others => L));
	signal filter_z1 : t_filt := (others => (others => L));
	signal filt_mul : signed(C_MUL_SIZE*2-1 downto 0) := (others => L);
	signal filter_in : signed(DF_FILT_RES-1 downto 0) := (others => L);
	signal filter_outXnB : signed(DF_FILT_RES-1 downto 0) := (others => L);
	signal index : natural range 0 to C_NO_OF_CH-1 := 0;
	
	function shorten(val : signed; lng, rnd : integer) return signed is
	variable res : signed(lng-1 downto 0);
	begin
		for i in 0 to lng-1 loop
			res(i) := val(val'high-lng+1+i);
		end loop;
		if (rnd/=0 and val'length>lng) then
			if (val(val'high-lng)=H) then
				res := res+1;
			end if;
		end if;
		return res;
	end shorten;
begin -- architecture ----------------------------------------------------------
	index <= CONV_INTEGER(i_ch_no);
	
	o_filtered_val <= shorten(filter_out(index),C_DATA_LNG,C_ROUND);
	
	filter_outXnB <= conv_signed(shorten(filt_mul,DF_FILT_RES+1,C_ROUND), DF_FILT_RES);
	filter_in <= conv_signed(i_adc_val, DF_FILT_RES);
	
	adc_filter : process(i_Clk)
	begin
		if rising_edge(i_Clk) then
			filt_mul <= shorten(filter_out(index),C_MUL_SIZE,C_ROUND)*DF_NEG_B;
			if (i_calc=H) then
				filter_out(index) <= filter_z1(index) + filter_in;
				filter_z1(index) <= filter_outXnB + filter_in;
				o_new_val <= H;
			else
				o_new_val <= L;
			end if;
		end if;
	end process adc_filter;
	
end architecture STRUCTURE; -- of iir_lp