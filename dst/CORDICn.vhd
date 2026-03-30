library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity CORDICn is 
	generic(
		n : integer := 10;
		xyz : integer := 10;
		p : integer := 2;
		C_ADDRLNG : integer := 2
	);
	port(
		i_clk : in STD_LOGIC;
		i_x : in signed(xyz-1 downto 0) := (others => L);
		i_y : in signed(xyz-1 downto 0) := (others => L);
		i_z : in signed(xyz-1 downto 0) := (others => L);
		o_x : out signed(xyz-1 downto 0);
		o_y : out signed(xyz-1 downto 0);
		o_z : out signed(xyz-1 downto 0);
		i_addr : in std_logic_vector(C_ADDRLNG-1 downto 0) := (others => L);
		o_addr : out std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H)
	);
end CORDICn;

architecture BEH of CORDICn is
	type t_xyz is array (0 to n) of signed(xyz downto 0);
	type t_addr is array (0 to n) of std_logic_vector(C_ADDRLNG-1 downto 0);
	signal x : t_xyz := (others => (others => L));
	signal y : t_xyz := (others => (others => L));
	signal z : t_xyz := (others => (others => L));
	signal addr : t_addr := (others => (others => H));
	signal cx : t_xyz := (others => (others => L));
	signal cy : t_xyz := (others => (others => L));
	signal cz : t_xyz := (others => (others => L));
	signal caddr : t_addr := (others => (others => H));
	--arctg(2**-i)/pi
	type t_arctg is array (0 to 15) of signed(17 downto 0);
	constant arctg : t_arctg := (	"001000000000000000",
									"000100101110010000",
									"000010011111101101",
									"000001010001000100",
									"000000101000101100",
									"000000010100010111",
									"000000001010001100",
									"000000000101000110",
									"000000000010100011",
									"000000000001010001",
									"000000000000101001",
									"000000000000010100",
									"000000000000001010",
									"000000000000000101",
									"000000000000000011",
									"000000000000000001");
									
	type t_shift is array (0 to 15) of unsigned(3 downto 0);
	constant shift : t_shift := (	"0000",
									"0001",
									"0010",
									"0011",
									"0100",
									"0101",
									"0110",
									"0111",
									"1000",
									"1001",
									"1010",
									"1011",
									"1100",
									"1101",
									"1110",
									"1111");
	constant pos180 : signed(10 downto 0) := "01111111111";
	constant neg180 : signed(10 downto 0) := "10000000000";
begin
	
	o_addr <= addr(n);
	o_x <= x(n)(xyz downto 1);
	o_y <= y(n)(xyz downto 1);
	o_z <= z(n)(xyz downto 1);
	
	cordic : process(i_x,i_y,i_z,x,y,z,i_addr,addr)
	begin
		caddr(0) <= i_addr;
		cx(0) <= i_x(xyz-1)&i_x;
		cy(0) <= i_y(xyz-1)&i_y;
		cz(0) <= i_z(xyz-1)&i_z;
		for i in 0 to n-1 loop
			caddr(i+1) <= addr(i);
			if (y(i)(y(i)'high)=L) then
				cx(i+1) <= x(i) - SHR(y(i),shift(i));
				cy(i+1) <= y(i) + SHR(x(i),shift(i));
				cz(i+1) <= z(i) - arctg(i)(arctg(i)'high downto arctg(i)'high-z(i)'high);
			else
				cx(i+1) <= x(i) + SHR(y(i),shift(i));
				cy(i+1) <= y(i) - SHR(x(i),shift(i));
				cz(i+1) <= z(i) + arctg(i)(arctg(i)'high downto arctg(i)'high-z(i)'high);
			end if;
		end loop;
	end process cordic;
	
	
	pipes : for i in 0 to n generate
	begin
		reg : if ((n mod p)=(i mod p) and i>0) generate
			process(i_clk)
			begin
				if rising_edge(i_clk) then
					addr(i) <= caddr(i);
					x(i) <= cx(i);
					y(i) <= cy(i);
					z(i) <= cz(i);
				end if;
			end process;
		end generate reg;
		
		comb : if ((n mod p)/=(i mod p) or i=0) generate
			addr(i) <= caddr(i);
			x(i) <= cx(i);
			y(i) <= cy(i);
			z(i) <= cz(i);
		end generate comb;
	end generate pipes;
		

end BEH;

