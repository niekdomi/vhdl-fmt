library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--library sincos_pkg;
--use sincos_pkg.sincos_pkg.all;

entity sincos is 
	generic(
		C_ADCLNG : integer := 16;
		C_ALGLNG : integer := 12;
		C_FLTLNG : integer := 14;
		C_POSLNG : integer := 32;
		C_NO_SINCOS : integer := 1;
		C_ADDRLNG : integer := 1
	);
	port(
		i_clk : in std_logic;
		i_intclr : in std_logic := L;
		i_sin : in std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		i_cos : in std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		i_sinOffset : in std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		i_cosOffset : in std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		i_sinGain : in std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		i_sinPase : in std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		i_nw2 : in std_logic_vector(17 downto 0) := (others => L);
		i_nd2w : in std_logic_vector(17 downto 0) := (others => L);
		i_AngMask : in std_logic_vector(C_ALGLNG-1 downto 0) := (others => L);
		o_angle : out std_logic_vector(C_ALGLNG-1 downto 0);
		o_magnitude : out std_logic_vector(C_ALGLNG-1 downto 0);
		o_Pos : out std_logic_vector(C_POSLNG-1 downto 0);
		o_Speed : out std_logic_vector(C_FLTLNG-1 downto 0);
		o_ErrAng : out std_logic_vector(C_ALGLNG-1 downto 0);
		o_sin : out std_logic_vector(C_ADCLNG-1 downto 0);
		o_cos : out std_logic_vector(C_ADCLNG-1 downto 0);
		i_addr : in std_logic_vector(C_ADDRLNG-1 downto 0) := (others => L);
		o_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H); -- addr out for pos, speed and errang
		o_sc_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H); -- addr out for sin and cos
		o_flt_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H) -- addr out for angle and magnitude
	);
end sincos;

architecture BEH of sincos is
	type t_addr is array (0 to 2) of std_logic_vector(C_ADDRLNG-1 downto 0);
	type t_adclng is array (0 to 2) of signed(C_ADCLNG-1 downto 0);
	signal sin : t_adclng := (others => (others => L));
	signal cos : t_adclng := (others => (others => L));
	signal sinGain : t_adclng := (others => (others => L));
	signal sinPase : t_adclng := (others => (others => L));
	signal addr : t_addr := (others => (others => H));
	
	signal Ang : signed(C_ALGLNG-1 downto 0) := (others => L);
	signal Mag : signed(C_ALGLNG-1 downto 0) := (others => L);
	
	signal flt_addr : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
	
	signal nw2 :  signed(17 downto 0) := (others => L);
	signal nd2w : signed(17 downto 0) := (others => L);
	signal sPos : signed(C_POSLNG-1 downto 0) := (others => L);
	signal sSpeed : signed(C_FLTLNG-1 downto 0) := (others => L);
	signal sErrAng : signed(C_ALGLNG-1 downto 0) := (others => L);
	
	signal isin : signed(C_ADCLNG-1 downto 0);
	signal icos : signed(C_ADCLNG-1 downto 0);
	
	signal sinmul : signed(C_ADCLNG*2 downto 0);
	signal cosmul : signed(C_ADCLNG*2-1 downto 0);
	
	signal sinres : signed(C_ADCLNG-1 downto 0);
	signal cosres : signed(C_ADCLNG-1 downto 0);
	
	signal gnd : signed(C_ADCLNG downto 0) := (others => L);

begin

	atan : entity work.arctan
	generic map (
		C_LNG => C_ALGLNG,
		C_ADDRLNG => C_ADDRLNG
	)
	port map (
		i_clk => i_clk,
		i_sin => isin(C_ALGLNG-1 downto 0),
		i_cos => icos(C_ALGLNG-1 downto 0),
		o_angle => Ang,
		o_magnitude => Mag,
		i_addr => addr(2),
		o_addr => flt_addr
	);
	
	isin <= SHR(sin(2),conv_unsigned(C_ADCLNG-C_ALGLNG,4));
	icos <= SHR(cos(2),conv_unsigned(C_ADCLNG-C_ALGLNG,4));
	
	--filter : entity work.traking_filter
	--generic map (
	--	C_ALGLNG => C_ALGLNG,
	--	C_FLTLNG => C_FLTLNG,
	--	C_ADDRLNG => C_ADDRLNG,
	--	C_NO_SINCOS => C_NO_SINCOS
	--)
	--port map (
	--	i_clk => i_clk,
	--	i_intclr => i_intclr,
	--	i_Ang => Ang,
	--	i_nw2  => nw2,
	--	i_nd2w => nd2w,
	--	o_Pos => sPos,
	--	o_Speed => sSpeed,
	--	o_ErrAng => sErrAng,
	--	i_addr => flt_addr,
	--	o_addr => o_addr
	--);
	
	filter : entity work.pos_filter
	generic map (
		C_ALGLNG => C_ALGLNG,
		C_POSLNG => C_POSLNG,
		C_ADDRLNG => C_ADDRLNG,
		C_NO_SINCOS => C_NO_SINCOS
	)
	port map (
		i_clk => i_clk,
		i_clr => i_intclr,
		i_Ang => Ang,
		o_Pos => sPos,
		o_ErrAng => sErrAng,
		i_addr => flt_addr,
		o_addr => o_addr
	);
	
	nw2  <= signed(i_nw2 );
	nd2w <= signed(i_nd2w);
	
	o_angle <= std_logic_vector(Ang);
	o_magnitude <= std_logic_vector(Mag);
	o_flt_addr <= flt_addr;
	o_Pos <= std_logic_vector(sPos);
	o_Speed <= std_logic_vector(sSpeed);
	o_ErrAng <= std_logic_vector(sErrAng);
	o_sin <= std_logic_vector(sin(2));
	o_cos <= std_logic_vector(cos(2));
	o_sc_addr <= addr(2);
	

	sinmul <= signed(i_sin)*unsigned(i_sinGain) + (i_sinOffset(C_ADCLNG-1) & i_sinOffset(C_ADCLNG-1) & signed(i_sinOffset) & gnd(C_ADCLNG-2 downto 0));
	sinres <= sinmul(2*C_ADCLNG) & sinmul(2*C_ADCLNG-3 downto C_ADCLNG+2-3);
	
	cosmul <= signed(cos(1))*sinPase(1) + (sin(1) & gnd(C_ADCLNG-1 downto 0));
	cosres <= cosmul(2*C_ADCLNG-1 downto C_ADCLNG);
	
	process(i_clk)
	begin
		if rising_edge(i_clk) then
		-- input signal adjustments --------------------------------------------
			-- 1. offset (!!!sinoffset = sinoffset*sinGain)
			sin(1) <=sinres;
			cos(1) <= signed(i_cos) + signed(i_cosOffset);
			sinGain(1) <= signed(i_sinGain);
			sinPase(1) <= signed(i_sinPase);
			addr(1) <= i_addr;
			-- 2. pahse
			sin(2) <= cosres;
			cos(2) <= cos(1);
			addr(2) <= addr(1);
		end if;
	end process;

	
end BEH;

