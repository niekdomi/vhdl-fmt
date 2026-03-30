library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--library sincos_pkg;
--use sincos_pkg.sincos_pkg.all;

entity traking_filter is 
	generic(
		C_ALGLNG : integer := 12;
		C_FLTLNG : integer := 16;
		C_ADDRLNG : integer := 2;
		C_NO_SINCOS : integer := 1
	);
	port(
		i_clk : in std_logic;
		i_intclr : in std_logic := L;
		i_Ang : in signed(C_ALGLNG-1 downto 0) := (others => L);
		i_nw2 : in  signed(17 downto 0) := (others => L);
		i_nd2w : in signed(17 downto 0) := (others => L);
		o_Pos : out signed(C_FLTLNG-1 downto 0);
		o_Speed : out signed(C_FLTLNG-1 downto 0);
		o_ErrAng : out signed(C_FLTLNG-1 downto 0);
		i_addr : in std_logic_vector(C_ADDRLNG-1 downto 0) := (others => L);
		o_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H)
	);
end traking_filter;

architecture BEH of traking_filter is
	constant n : integer := 4;
	signal iAng : signed(C_FLTLNG-1 downto 0) := (others => L);
	type t_fltlng is array (0 to n) of signed(C_FLTLNG-1 downto 0);
	signal ErrAng : t_fltlng := (others => (others => L));

	signal speed : signed(C_FLTLNG downto 0) := (others => L);
	signal pos : signed(C_FLTLNG downto 0) := (others => L);
	signal err : signed(C_FLTLNG downto 0) := (others => L);
	signal ahalf : signed(C_FLTLNG downto 0) := (others => L);
	
	type t_intlng is array (0 to n) of signed(34 downto 0);
	signal i1 : t_intlng := (others => (others => L));
	signal i2 : t_intlng := (others => (others => L));
	
	type t_flt_addr is array (0 to n) of unsigned(i_addr'range);
	signal flt_addr : t_flt_addr := (others => (others => L));
	
	type t_fltram is array (0 to C_NO_SINCOS-1) of signed(34 downto 0);
	signal ri1 : t_fltram := (others => (others => L));
	signal ri2 : t_fltram := (others => (others => L));
	
	signal mul1 : signed(35 downto 0);
	signal mul2 : signed(35 downto 0);
	signal mul22 : signed(35 downto 0);
	signal gnd : signed(C_FLTLNG-1 downto C_ALGLNG) := (others => L);
	signal nw2 : signed (17 downto 0) := (others => L); 
	signal nd2w : signed(17 downto 0) := (others => L);
	signal sig1 : signed(17 downto C_FLTLNG) := (others => L);
	signal sig2 : signed(17 downto C_FLTLNG) := (others => L);
begin
	ahalf(0) <= H;
	o_Pos <= pos(C_FLTLNG downto 1);
	o_Speed <= speed(C_FLTLNG downto 1);
	o_ErrAng <= ErrAng(n);
	flt_addr(0) <= unsigned(i_addr);
	o_addr <= std_logic_vector(flt_addr(n));
	
	iAng <= i_Ang & gnd;
	
	process(i_clk)
	variable wr_i : integer := 0;
	begin
		if rising_edge(i_clk) then
			if (flt_addr(n) < C_NO_SINCOS) then
				wr_i := conv_integer(flt_addr(n));
				ri1(wr_i)  <= i1(n);
				ri2(wr_i) <= i2(n);
				if (i_intclr=H) then
					ri1(wr_i) <= (others => L);
					ri2(wr_i) <= (others => L);
				end if;
			end if;
		end if;
	end process;
	
	process(flt_addr,ri1,ri2)
	variable rd_i : integer := 0;
	begin
		if (flt_addr(0) < C_NO_SINCOS) then
			rd_i := conv_integer(flt_addr(0));
			i1(0) <= ri1(rd_i);
			i2(0) <= ri2(rd_i);
		else
			i1(0) <= (others => L);
			i2(0) <= (others => L);
		end if;
	end process;
	
	--sig1 <=  (others => ErrAng(1)(C_FLTLNG-1));
	--sig2 <=  (others => ErrAng(2)(C_FLTLNG-1));
	
	mul1 <= (ErrAng(1) & sig1)* nw2 + (i1(1)(i1(1)'high) & i1(1));
	mul2 <= (ErrAng(2) & sig2)*nd2w + (i1(2)(i1(2)'high) & i1(2));
	
	pos <= i2(n)((i2(n)'high) downto (i2(n)'high)-C_FLTLNG) + ahalf;
	err <= i2(0)((i2(0)'high) downto (i2(0)'high)-C_FLTLNG) + ahalf;
	speed <= i1(n)((i1(n)'high) downto (i1(n)'high)-C_FLTLNG) + ahalf;
	
	process(i_clk)
	begin
		if rising_edge(i_clk) then
			nw2 <= i_nw2;
			nd2w <= i_nd2w;
			flt_addr(1 to flt_addr'high) <= flt_addr(0 to flt_addr'high-1);
			-- 1.
			i1(1) <= i1(0);
			i2(1) <= i2(0);
			ErrAng(1) <= iAng - err(C_FLTLNG downto 1);
			-- 2
			i1(2) <= mul1(i1(1)'high downto 0);
			i2(2) <= i2(1);
			ErrAng(2) <= ErrAng(1);
			-- 3
			i1(3) <= i1(2);
			i2(3) <= i2(2);
			mul22 <= mul2;
			ErrAng(3) <= ErrAng(2);
			-- 4
			i1(4) <= i1(3);
			i2(4) <= i2(3) + mul22(i2(3)'high downto 0);
			ErrAng(4) <= ErrAng(3);
		end if;
	end process;

	
end BEH;

