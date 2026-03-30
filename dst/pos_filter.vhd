library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--library sincos_pkg;
--use sincos_pkg.sincos_pkg.all;

entity pos_filter is 
	generic(
		C_ALGLNG : integer := 12;
		C_POSLNG : integer := 32;
		C_ADDRLNG : integer := 2;
		C_NO_SINCOS : integer := 2
	);
	port(
		i_clk : in std_logic;
		i_clr : in std_logic := L;
		i_Ang : in signed(C_ALGLNG-1 downto 0) := (others => L);
		o_Pos : out signed(C_POSLNG-1 downto 0);
		o_ErrAng : out signed(C_ALGLNG-1 downto 0);
		i_addr : in std_logic_vector(C_ADDRLNG-1 downto 0) := (others => L);
		o_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H)
	);
end pos_filter;

architecture BEH of pos_filter is
	constant n : integer := 4;
	
	type t_fltlng is array (0 to n) of signed(C_ALGLNG-1 downto 0);
	signal ErrAng : t_fltlng := (others => (others => L));
	signal AngfltSub : t_fltlng := (others => (others => L));
	signal lAng : t_fltlng := (others => (others => L));
	
	type t_fltangram is array (0 to C_NO_SINCOS-1) of signed(C_ALGLNG-1 downto 0);
	signal rlAng : t_fltangram := (others => (others => L));
	
	
	type t_flt_addr is array (0 to n) of unsigned(i_addr'range);
	signal flt_addr : t_flt_addr := (others => (others => L));
	
	type t_fltposram is array (0 to C_NO_SINCOS-1) of signed(C_POSLNG-1 downto 0);
	signal rpos : t_fltposram := (others => (others => L));
	
	type t_fltpos is array (0 to n) of signed(C_POSLNG-1 downto 0);
	signal pos : t_fltpos := (others => (others => L));
	
	type t_fltdiflng is array (0 to C_NO_SINCOS-1, 0 to 16) of signed(C_ALGLNG-1 downto 0);
	signal AngdifFlt : t_fltdiflng := (others => (others => (others => L)));
	
	type t_fltmean is array (0 to n) of signed(C_ALGLNG-1+4 downto 0);
	signal Angfltmean : t_fltmean := (others => (others => L));
	
	type t_fltmeanram is array (0 to C_NO_SINCOS-1) of signed(C_ALGLNG-1+4 downto 0);
	signal rAngfltmean : t_fltmeanram := (others => (others => L));
	
begin

	o_Pos <= SHR(pos(n),"100");
	o_ErrAng <= ErrAng(n);
	flt_addr(0) <= unsigned(i_addr);
	o_addr <= std_logic_vector(flt_addr(n));
	
	process(i_clk)
	variable wr_i : integer range 0 to 2**C_ADDRLNG-1 := 0;
	begin
		if rising_edge(i_clk) then
			if (flt_addr(n) < C_NO_SINCOS) then
				wr_i := conv_integer(flt_addr(n));
				rpos(wr_i) <= pos(n);
				rAngfltmean(wr_i) <= Angfltmean(n);
				rlAng(wr_i) <= lAng(n);
				
				AngdifFlt(wr_i,0) <= ErrAng(n);
				for i in 0 to 15 loop
					AngdifFlt(wr_i,i+1) <= AngdifFlt(wr_i,i);
				end loop;
				
				if (i_clr=H) then
					rpos(wr_i) <= (others => L);
					rlAng(wr_i) <= (others => L);
					rAngfltmean(wr_i) <= (others => L);
					AngdifFlt(wr_i,0) <= (others => L);
				end if;
			end if;
		end if;
	end process;
	
	process(flt_addr,rpos,rAngfltmean,AngdifFlt)
	variable rd_i : integer range 0 to 2**C_ADDRLNG-1 := 0;
	begin
		if (flt_addr(0) < C_NO_SINCOS) then
			rd_i := conv_integer(flt_addr(0));
			pos(0) <= rpos(rd_i);
			Angfltmean(0) <= rAngfltmean(rd_i);
			lAng(0) <= rlAng(rd_i);
			AngfltSub(0) <= AngdifFlt(rd_i,16);
		else
			pos(0) <= (others => L);
		end if;
	end process;
	
	process(i_clk)
	variable Angfltmean_pl : signed(o_Pos'range);
	begin
		if rising_edge(i_clk) then
			flt_addr(1 to n) <= flt_addr(0 to n-1);
			-- 1.
			Pos(1) <= Pos(0);
			Angfltmean(1) <= Angfltmean(0);
			ErrAng(1) <= i_Ang - lAng(0);
			AngfltSub(1) <= AngfltSub(0);
			lAng(1) <= i_Ang;
			-- 2
			Pos(2) <= Pos(1);
			Angfltmean(2) <= Angfltmean(1) + ErrAng(1);
			ErrAng(2) <= ErrAng(1);
			AngfltSub(2) <= AngfltSub(1);
			lAng(2) <= lAng(1);
			-- 3
			Pos(3) <= Pos(2);
			Angfltmean(3) <= Angfltmean(2) - AngfltSub(2);
			ErrAng(3) <= ErrAng(2);
			lAng(3) <= lAng(2);
			-- 4
			Pos(4) <= Pos(3) + Angfltmean(3);
			Angfltmean(4) <= Angfltmean(3);
			ErrAng(4) <= ErrAng(3);
			lAng(4) <= lAng(3);
		end if;
	end process;

	
end BEH;

