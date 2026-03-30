--------------------------------------------------------------------------------
--
--  dpr1aNb  1.00a
--
--------------------------------------------------------------------------------
--
--  project     : ppc-card, imp2, sac2
--  programmer  : C. Leuthold, INDEL AG
--  date        : 25.04.2005
--  version     : 1.00a
--  language    : VHDL
--  system      : ISE / EDK
--
--  purpose
--      dual port ram 1 port to 1..4 port
--      all ports have a size of 2048byte
--      all b ports have a i_WEN_B* size of 4 (C_PORT_B*_DWIDTH/4 bit per pin)
--      port a has a i_WEN_A
--------------------------------------------------------------------------------
--  1.00a       : universal module of dpr1a3b_v1_00_b
--                parameterized:
--                  number of port b 1..4
--                  datawide port b 4, 8, 16, 32, 64 and 128
--                  opb/dsocm bram intrface support
--
--	09.11.2006-le : add outputs Parity_A(j)(0 to 3)
--
--	19.03.2007-le : process ppc_cs: add def. value for o_Data_A
--					to avoid latches for C_NUM_OF_BLOCKS=3
--
--	21.03.2007-le : change WRITE_MODE_A/B from default WRITE_FIRST to READ_FIRST
--					to avoid invalid data when on port writ and the other read 
--					the same address.
--	
--	30.03.2007-le : change def. value for o_Data_A from 0 to douta(C_NUM_OF_BLOCKS-1)
--	11.05.2007-le	add svn keywords
--	14.05.2007-le : undo change def. value for o_Data_A from 0 to douta(C_NUM_OF_BLOCKS-1) 
--	03.11.2008-le : add generic C_BX_BLOCK_ENABLED, to remove blocks
--					e.g. do not need block0 but need block 1 and 3
--------------------------------------------------------------------------------
--$Rev:: 1058                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-06-11 12:31:38 +0200 (Do., 11 Jun 2009)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- dpr1aNb.vhd
-- 25.04.2005 Indel Ag, C. Leuthold
--
--  GENERICS:
--  C_PORT_DWIDTH       : port A datawidth pos. val. 32 and 64
--  C_PORT_AWIDTH       : port A addrwidth pos. val. 32
--  C_NUM_OF_BLOCKS     : number of B ports pos. val. 1..4
--  C_PORT_B*_DWIDTH    : port B* datawidth pos. val. 4, 8, 16, 32, 64 and 128
--  C_PORT_B*_AWIDTH    : port B* addrwidth pos. val. ln(2048/C_PORT_B*_DWIDTH)/ln(2) .. 32
--  C_B*_BRAM_IF_SUPPORT: 0 or 1: 1 -> support connection to a opb-bram or dsocm-bram controller
--                        if 1 C_PORT_B*_AWIDTH and C_PORT_B*_DWIDTH  have to be 32
--
--
--  C_NUM_OF_BLOCKS       1    2    3    4
--  Addr 17 Addr 18
--                     +----+----+----+----+
--      0     0     P  |seg0|seg0|seg0|seg0|
--                  o  +----+----+----+----+
--      0     1     r  |seg0|seg1|seg1|seg1|
--                  t  +----+----+----+----+
--      1     0     A  |seg0|seg0|seg2|seg2|
--                     +----+----+----+----+
--      1     1        |seg0|seg1|----|seg3|
--                     +----+----+----+----+
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

library unisim;
use unisim.vcomponents.ALL;

library dpr1aNb;
use dpr1aNb.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity dpr1aNb is
	generic (
		C_PORT_DWIDTH : integer := 64;
		C_PORT_AWIDTH : integer := 32;
		C_NUM_OF_BLOCKS : integer range 1 to 4 := 4;
		
		C_PORT_B0_DWIDTH : integer := 4;
		C_PORT_B0_AWIDTH : integer := 15;
		C_B0_BRAM_IF_SUPPORT : integer range 0 to 1 := 0;
		C_B0_BLOCK_ENABLED : integer range 0 to 1 := 1;
		C_B0_RAM_EN_MASK : std_logic_vector(3 downto 0) := "1111";
		C_B0_HALF_SIZE : integer := 0;
		
		C_PORT_B1_DWIDTH : integer := 8;
		C_PORT_B1_AWIDTH : integer := 15;
		C_B1_BRAM_IF_SUPPORT : integer range 0 to 1 := 0;
		C_B1_BLOCK_ENABLED : integer range 0 to 1 := 1;
		C_B1_RAM_EN_MASK : std_logic_vector(3 downto 0) := "1111";
		C_B1_HALF_SIZE : integer := 0;
		
		C_PORT_B2_DWIDTH : integer := 16;
		C_PORT_B2_AWIDTH : integer := 16;
		C_B2_BRAM_IF_SUPPORT : integer range 0 to 1 := 0;
		C_B2_BLOCK_ENABLED : integer range 0 to 1 := 1;
		C_B2_RAM_EN_MASK : std_logic_vector(3 downto 0) := "1111";
		C_B2_HALF_SIZE : integer := 0;
		
		C_PORT_B3_DWIDTH : integer := 32;
		C_PORT_B3_AWIDTH : integer := 32;
		C_B3_BRAM_IF_SUPPORT : integer range 0 to 1 := 1;
		C_B3_BLOCK_ENABLED : integer range 0 to 1 := 1;
		C_B3_RAM_EN_MASK : std_logic_vector(3 downto 0) := "1111";
		C_B3_HALF_SIZE : integer := 0;
		-- generics without effect for xilinx ..._bram_if_cntlr
		C_MEMSIZE : integer := 8192;
		C_NUM_WE : integer := 4;
		C_FAMILY : string := "virtex2p"
	);
	port (
		-- instance GLOBAL
		-- PORT A for PPC405
		i_EN_A : in std_logic;
		i_Clk_A : in std_logic;
		i_Rst_A : in std_logic;
		i_Data_A : in std_logic_vector(0 to C_PORT_DWIDTH-1);   -- 64 bit
		o_Data_A : out std_logic_vector(0 to C_PORT_DWIDTH-1);  -- 64 bit
		i_Addr_A : in std_logic_vector(0 to C_PORT_AWIDTH-1);
		i_WEN_A : in std_logic_vector(0 to C_PORT_DWIDTH/8-1);  -- 8 ByteWriteEnables
		-- PORT B0
		i_EN_B0 : in std_logic:=L;
		i_Clk_B0 : in std_logic:=L;
		i_Rst_B0 : in std_logic:=L;
		i_Data_B0 : in std_logic_vector(C_PORT_B0_DWIDTH-1 downto 0):=(others=>L);
		o_Data_B0 : out std_logic_vector(C_PORT_B0_DWIDTH-1 downto 0);
		o_Parity_AB0 : out std_logic_vector(3 downto 0);
		i_Addr_B0 : in std_logic_vector(C_PORT_B0_AWIDTH-1 downto 0):=(others=>L);
		i_WEN_B0 : in std_logic_vector(3 downto 0):=(others=>L);
		-- PORT B1
		i_EN_B1 : in std_logic:=L;
		i_Clk_B1 : in std_logic:=L;
		i_Rst_B1 : in std_logic:=L;
		i_Data_B1 : in std_logic_vector(C_PORT_B1_DWIDTH-1 downto 0):=(others=>L);
		o_Data_B1 : out std_logic_vector(C_PORT_B1_DWIDTH-1 downto 0);
		o_Parity_AB1 : out std_logic_vector(3 downto 0);
		i_Addr_B1 : in std_logic_vector(C_PORT_B1_AWIDTH-1 downto 0):=(others=>L);
		i_WEN_B1 : in std_logic_vector(3 downto 0):=(others=>L);
		-- PORT B2
		i_EN_B2 : in std_logic:=L;
		i_Clk_B2 : in std_logic:=L;
		i_Rst_B2 : in std_logic:=L;
		i_Data_B2 : in std_logic_vector(C_PORT_B2_DWIDTH-1 downto 0):=(others=>L);
		o_Data_B2 : out std_logic_vector(C_PORT_B2_DWIDTH-1 downto 0);
		o_Parity_AB2 : out std_logic_vector(3 downto 0);
		i_Addr_B2 : in std_logic_vector(C_PORT_B2_AWIDTH-1 downto 0):=(others=>L);
		i_WEN_B2 : in std_logic_vector(3 downto 0):=(others=>L);
		-- PORT B3
		i_EN_B3 : in std_logic:=L;
		i_Clk_B3 : in std_logic:=L;
		i_Rst_B3 : in std_logic:=L;
		i_Data_B3 : in std_logic_vector(C_PORT_B3_DWIDTH-1 downto 0):=(others=>L);
		o_Data_B3 : out std_logic_vector(C_PORT_B3_DWIDTH-1 downto 0);
		o_Parity_AB3 : out std_logic_vector(3 downto 0);
		i_Addr_B3 : in std_logic_vector(C_PORT_B3_AWIDTH-1 downto 0):=(others=>L);
		i_WEN_B3 : in std_logic_vector(3 downto 0):=(others=>L)
	);
end dpr1aNb;

architecture IMP of dpr1aNb is

--------------------------------------------------------------------------------
-- types -----------------------------------------------------------------------
	type t_generic_arr is array (0 to 3) of integer;
	type t_data_arr is array (0 to 3) of std_logic_vector(127 downto 0);
	type t_dataa_arr is array (0 to 3) of std_logic_vector(64 downto 0);
	type t_addr_arr is array (0 to 3) of std_logic_vector(31 downto 0);
	type t_sig_arr is array (0 to 3) of std_logic;
	type t_wen_arr is array (0 to 3) of std_logic_vector(3 downto 0);
	type t_o_Parity_arr is array (0 to 3) of std_logic_vector(3 downto 0);
-- constants -------------------------------------------------------------------
	constant C_PORTB_DWIDTH : t_generic_arr := (C_PORT_B0_DWIDTH,C_PORT_B1_DWIDTH,C_PORT_B2_DWIDTH,C_PORT_B3_DWIDTH);
	constant C_PORTB_AWIDTH : t_generic_arr := (C_PORT_B0_AWIDTH,C_PORT_B1_AWIDTH,C_PORT_B2_AWIDTH,C_PORT_B3_AWIDTH);
	constant DF_BLOCK_ENABLE : t_generic_arr := (C_B0_BLOCK_ENABLED, C_B1_BLOCK_ENABLED, C_B2_BLOCK_ENABLED, C_B3_BLOCK_ENABLED);
	constant DF_RAM_EN_MASK : t_wen_arr := (C_B0_RAM_EN_MASK, C_B1_RAM_EN_MASK, C_B2_RAM_EN_MASK, C_B3_RAM_EN_MASK);
	constant DF_HALF_SIZE : t_generic_arr := (C_B0_HALF_SIZE, C_B1_HALF_SIZE, C_B2_HALF_SIZE, C_B3_HALF_SIZE);
--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------
	signal douta : t_dataa_arr;

	signal dinb : t_data_arr;
	signal doutb : t_data_arr;
	signal dinbX : t_data_arr;
	signal doutbX : t_data_arr;
	signal WEN_B : t_wen_arr;
	signal En_B : t_sig_arr;
	signal Clk_B : t_sig_arr;
	signal Addr_B : t_addr_arr := (others => (others => L));
	signal Parity_A : t_o_Parity_arr;

	signal selector : std_logic_vector(1 downto 0);

	signal CS_seg : t_sig_arr;

	signal net_gnd0 : std_logic;
	signal net_gnd1 : std_logic_vector(0 downto 0);
	signal net_gnd4 : std_logic_vector(3 downto 0);
	signal net_gnd32 : std_logic_vector(31 downto 0);

	constant ADDR_WIDTH : integer := 11; --log2(BRAM size in byte)
	constant DF_ADDR_HIGH : integer := C_PORT_AWIDTH-3;
	
	signal x_BRAM_WEN : std_logic_vector(7 downto 0);
	signal x_BRAM_Dout : std_logic_vector(63 downto 0);
	signal x_BRAM_Addr : std_logic_vector(9 downto 0);
	
begin

--------------------------------------------------------------------------------
-- Power assignments
net_gnd0 <= L;
net_gnd1 <= "0";
net_gnd4 <= "0000";
net_gnd32 <= "00000000000000000000000000000000";
--------------------------------------------------------------------------------
-- Port A
--------------------------------------------------------------------------------

blocksize1 : if C_NUM_OF_BLOCKS=1 generate
begin
	selector <= "00";
end generate blocksize1;
blocksize2 : if C_NUM_OF_BLOCKS=2 generate
begin
	selector <= L & i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH);
end generate blocksize2;
blocksize34 : if C_NUM_OF_BLOCKS>2 generate
begin
	selector <= i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH-ADDR_WIDTH);
end generate blocksize34;

ppc_cs : process(selector,i_En_A,douta,i_Addr_A)
begin
	CS_Seg <= (others => L);
	o_Data_A <= (others => L);
	for n in 0 to C_NUM_OF_BLOCKS-1 loop
		if (selector=n) then
			CS_Seg(n) <= i_En_A;
			o_Data_A <= douta(n);
		end if;
	end loop;
end process ppc_cs;
--------------------------------------------------------------------------------
-- Port B0
--------------------------------------------------------------------------------
o_Parity_AB0 <= Parity_A(0);
data0 : for d in 0 to C_PORT_B0_DWIDTH-1 generate
begin
	dinb(0)(d) <= i_Data_B0(d);
	o_Data_B0(d) <= doutb(0)(d);
end generate data0;
En_B(0) <= i_EN_B0;
WEn_B(0) <= i_WEN_B0;
Clk_B(0) <= i_Clk_B0;

Addr_B(0)(C_PORT_B0_AWIDTH-1 downto 0) <= i_Addr_B0;

--------------------------------------------------------------------------------
-- Port B1
--------------------------------------------------------------------------------
o_Parity_AB1 <= Parity_A(1);
data1 : for d in 0 to C_PORT_B1_DWIDTH-1 generate
begin
	dinb(1)(d) <= i_Data_B1(d);
	o_Data_B1(d) <= doutb(1)(d);
end generate data1;
En_B(1) <= i_EN_B1;
WEn_B(1) <= i_WEN_B1;
Clk_B(1) <= i_Clk_B1;

Addr_B(1)(C_PORT_B1_AWIDTH-1 downto 0) <= i_Addr_B1;

--------------------------------------------------------------------------------
-- Port B2
--------------------------------------------------------------------------------
o_Parity_AB2 <= Parity_A(2);
data2 : for d in 0 to C_PORT_B2_DWIDTH-1 generate
begin
	dinb(2)(d) <= i_Data_B2(d);
	o_Data_B2(d) <= doutb(2)(d);
end generate data2;
En_B(2) <= i_EN_B2;
WEn_B(2) <= i_WEN_B2;
Clk_B(2) <= i_Clk_B2;

Addr_B(2)(C_PORT_B2_AWIDTH-1 downto 0) <= i_Addr_B2;

--------------------------------------------------------------------------------
-- Port B3
--------------------------------------------------------------------------------
o_Parity_AB3 <= Parity_A(3);
data3 : for d in 0 to C_PORT_B3_DWIDTH-1 generate
begin
	dinb(3)(d) <= i_Data_B3(d);
	o_Data_B3(d) <= doutb(3)(d);
end generate data3;
En_B(3) <= i_EN_B3;
WEn_B(3) <= i_WEN_B3;
Clk_B(3) <= i_Clk_B3;

Addr_B(3)(C_PORT_B3_AWIDTH-1 downto 0) <= i_Addr_B3;

--------------------------------------------------------------------------------
-- block ram component imp.
--------------------------------------------------------------------------------
x_BRAM_WEN  <= crossbits(i_WEN_A(0 to 7));
x_BRAM_Dout <= crossbits(i_Data_A(0 to 63));
x_BRAM_Addr <= crossbits(i_Addr_A(28-(x_BRAM_Addr'length-1) to 28));

num_of_block : for j in 0 to C_NUM_OF_BLOCKS-1 generate
begin
	blockenabled : if DF_BLOCK_ENABLE(j)=1 generate
	begin
		RamSel_32 : if C_PORTB_DWIDTH(j) = 32 generate
			constant C_AWIDTH_B : integer := 11;
			signal x_BRAM_Din : std_logic_vector(63 downto 0);
		begin
			
			douta(j) <= crossbits(x_BRAM_Din);
			
			full_size : if (DF_HALF_SIZE(j)=0) generate
			begin
				block4bram : entity dpr1aNb.BRAM_8kByte_A64_B32
				generic map (
					C_RAM_EN_MASK => DF_RAM_EN_MASK(j)
				)
				port map (
					i_BRAM_Clk_A => i_Clk_A,
					i_BRAM_EN_A => CS_Seg(j),
					i_BRAM_WEN_A => x_BRAM_WEN,
					i_BRAM_Addr_A => x_BRAM_Addr,
					i_BRAM_Dout_A => x_BRAM_Dout,
					o_BRAM_Din_A => x_BRAM_Din,
					i_BRAM_Clk_B => Clk_B(j),
					i_BRAM_EN_B => En_B(j),
					i_BRAM_WEN_B => WEn_B(j),
					i_BRAM_Addr_B => Addr_B(j)(C_AWIDTH_B-1 downto 0),
					i_BRAM_Dout_B => dinb(j)(C_PORTB_DWIDTH(j)-1 downto 0),
					o_BRAM_Din_B => doutb(j)(C_PORTB_DWIDTH(j)-1 downto 0)
				);
			end generate full_size;
			
			half_size : if (DF_HALF_SIZE(j)/=0) generate
				signal AAddr : std_logic_vector(8 downto 0);
				signal BAddr : std_logic_vector(C_AWIDTH_B-2 downto 0);
			begin
				xx : for i in 0 to 8 generate
				begin
					AAddr(i) <= x_BRAM_Addr(i) when (DF_HALF_SIZE(j)>i) else x_BRAM_Addr(i+1);
				end generate xx;
				yy : for i in 0 to C_AWIDTH_B-2 generate
				begin
					BAddr(i) <= Addr_B(j)(i) when ((DF_HALF_SIZE(j)+1)>i) else Addr_B(j)(i+1);
				end generate yy;
				block4bram : entity dpr1aNb.BRAM_4kByte_A64_B32
				port map (
					i_BRAM_Clk_A => i_Clk_A,
					i_BRAM_EN_A => CS_Seg(j),
					i_BRAM_WEN_A => x_BRAM_WEN,
					i_BRAM_Addr_A => AAddr,
					i_BRAM_Dout_A => x_BRAM_Dout,
					o_BRAM_Din_A => x_BRAM_Din,
					i_BRAM_Clk_B => Clk_B(j),
					i_BRAM_EN_B => En_B(j),
					i_BRAM_WEN_B => WEn_B(j),
					i_BRAM_Addr_B => BAddr,
					i_BRAM_Dout_B => dinb(j)(C_PORTB_DWIDTH(j)-1 downto 0),
					o_BRAM_Din_B => doutb(j)(C_PORTB_DWIDTH(j)-1 downto 0)
				);
			end generate half_size;
		end generate RamSel_32;
		RamSel_64 : if C_PORTB_DWIDTH(j) = 64 generate
			constant C_AWIDTH_B : integer := 10;
			signal x_BRAM_Din : std_logic_vector(63 downto 0);
		begin
			
			douta(j) <= crossbits(x_BRAM_Din);
			
			full_size : if (DF_HALF_SIZE(j)=0) generate
			begin
			block4bram : entity dpr1aNb.BRAM_8kByte_A64_B64
			generic map (
				C_RAM_EN_MASK => DF_RAM_EN_MASK(j)
			)
			port map (
				i_BRAM_Clk_A => i_Clk_A,
				i_BRAM_EN_A => CS_Seg(j),
				i_BRAM_WEN_A => x_BRAM_WEN,
				i_BRAM_Addr_A => x_BRAM_Addr,
				i_BRAM_D_A => x_BRAM_Dout,
				o_BRAM_D_A => x_BRAM_Din,
				i_BRAM_Clk_B => Clk_B(j),
				i_BRAM_EN_B => En_B(j),
				i_BRAM_WEN_B => WEn_B(j),
				i_BRAM_Addr_B => Addr_B(j)(C_AWIDTH_B-1 downto 0),
				i_BRAM_D_B => dinb(j)(C_PORTB_DWIDTH(j)-1 downto 0),
				o_BRAM_D_B => doutb(j)(C_PORTB_DWIDTH(j)-1 downto 0)
			);
			end generate full_size;
			
			half_size : if (DF_HALF_SIZE(j)/=0) generate
				signal AAddr : std_logic_vector(8 downto 0);
				signal BAddr : std_logic_vector(C_AWIDTH_B-2 downto 0);
			begin
				xx : for i in 0 to 8 generate
				begin
					AAddr(i) <= x_BRAM_Addr(i) when (DF_HALF_SIZE(j)>i) else x_BRAM_Addr(i+1);
					BAddr(i) <= Addr_B(j)(i) when (DF_HALF_SIZE(j)>i) else Addr_B(j)(i+1);
				end generate xx;
				block4bram : entity dpr1aNb.BRAM_4kByte_A64_B64
				port map (
					i_BRAM_Clk_A => i_Clk_A,
					i_BRAM_EN_A => CS_Seg(j),
					i_BRAM_WEN_A => x_BRAM_WEN,
					i_BRAM_Addr_A => AAddr,
					i_BRAM_D_A => x_BRAM_Dout,
					o_BRAM_D_A => x_BRAM_Din,
					i_BRAM_Clk_B => Clk_B(j),
					i_BRAM_EN_B => En_B(j),
					i_BRAM_WEN_B => WEn_B(j),
					i_BRAM_Addr_B => BAddr,
					i_BRAM_D_B => dinb(j)(C_PORTB_DWIDTH(j)-1 downto 0),
					o_BRAM_D_B => doutb(j)(C_PORTB_DWIDTH(j)-1 downto 0)
				);
			end generate half_size;
		end generate RamSel_64;
		RamSel_128 : if C_PORTB_DWIDTH(j) = 128 generate
			constant C_AWIDTH_B : integer := 9;
			signal x_BRAM_Din : std_logic_vector(63 downto 0);
		begin
			
			douta(j) <= crossbits(x_BRAM_Din);
			
			block4bram : entity dpr1aNb.BRAM_8kByte_A64_B128
			generic map (
				C_RAM_EN_MASK => DF_RAM_EN_MASK(j)
			)
			port map (
				i_BRAM_Clk_A => i_Clk_A,
				i_BRAM_EN_A => CS_Seg(j),
				i_BRAM_WEN_A => x_BRAM_WEN,
				i_BRAM_Addr_A => x_BRAM_Addr,
				i_BRAM_D_A => x_BRAM_Dout,
				o_BRAM_D_A => x_BRAM_Din,
				i_BRAM_Clk_B => Clk_B(j),
				i_BRAM_EN_B => En_B(j),
				i_BRAM_WEN_B => WEn_B(j),
				i_BRAM_Addr_B => Addr_B(j)(C_AWIDTH_B-1 downto 0),
				i_BRAM_D_B => dinb(j)(C_PORTB_DWIDTH(j)-1 downto 0),
				o_BRAM_D_B => doutb(j)(C_PORTB_DWIDTH(j)-1 downto 0)
			);
		end generate RamSel_128;
	end generate blockenabled;
	
	blockdisabled : if DF_BLOCK_ENABLE(j)=0 generate
	begin
		doutb(j) <= (others => L);
		Parity_A(j) <= (others => L);
		douta(j) <=  (others => L);
	end generate blockdisabled;
end generate num_of_block;
--------------------------------------------------------------------------------
end architecture IMP;
