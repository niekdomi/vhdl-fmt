library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity arctan is 
	generic(
		C_LNG : integer := 12;
		C_ADDRLNG : integer := 2
	);
	port(
		i_clk : in STD_LOGIC;
		i_sin : in signed(C_LNG-1 downto 0) := (others => L);
		i_cos : in signed(C_LNG-1 downto 0) := (others => L);
		o_angle : out signed(C_LNG-1 downto 0) := (others => L);
		o_magnitude : out signed(C_LNG-1 downto 0);
		i_addr : in std_logic_vector(C_ADDRLNG-1 downto 0) := (others => L);
		o_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H)
	);
end arctan;

architecture BEH of arctan is
	
	constant helper: signed(C_LNG-3 downto 0) := (others => H);
	constant pos45: signed(C_LNG-1 downto 0) := "00"& helper;
	constant pos90: signed(C_LNG-1 downto 0) := "01"& helper;
	
	signal X: signed(C_LNG-1 downto 0) := (others => L);
	signal Y: signed(C_LNG-1 downto 0) := (others => L);
	signal Z: signed(C_LNG-1 downto 0) := (others => L);
	signal Ang: signed(C_LNG-1 downto 0) := (others => L);
	signal Mag: signed(C_LNG-1 downto 0) := (others => L);
	signal iaddr : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
	signal oaddr : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
begin

	algo: entity work.CORDICn
	generic map (
		n => C_LNG,
		xyz => C_LNG,
		p => 3,
		C_ADDRLNG => C_ADDRLNG
	)
	port map ( 
		i_clk => i_clk,
		i_x => X,
		i_y => Y,
		i_Z => Z,
		o_z => Ang,
		o_x => Mag,
		i_addr => iaddr,
		o_addr => oaddr
	);
		
	process(i_clk)
	begin
		if rising_edge(i_clk) then
			iaddr <= i_addr;
			o_addr <= oaddr;
			if i_cos(C_LNG-1)/=L then
				X <= i_cos;
				Y <= i_sin;
				Z <= pos90;
			else
				X <= -i_cos;
				Y <= -i_sin;
				Z <= -pos90;
			end if;
			o_angle <= Ang+pos45;
			o_magnitude <= abs(Mag);
		end if;
	end process;
		

end BEH;

