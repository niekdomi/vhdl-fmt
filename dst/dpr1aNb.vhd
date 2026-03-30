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
--$Rev:: 719                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-03 11:23:19 +0100 (Mo., 03 Nov 2008)                         $
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

entity dpr1aNb is
	GENERIC (
		C_PORT_DWIDTH : INTEGER := 32;
		C_PORT_AWIDTH : INTEGER := 32;
		C_NUM_OF_BLOCKS : INTEGER range 1 to 4 := 4;
		C_PORT_B0_DWIDTH : INTEGER := 4;
		C_PORT_B0_AWIDTH : INTEGER := 15;
		C_B0_BRAM_IF_SUPPORT : INTEGER range 0 to 1 := 0;
		C_B0_BLOCK_ENABLED : INTEGER range 0 to 1 := 1;
		C_PORT_B1_DWIDTH : INTEGER := 8;
		C_PORT_B1_AWIDTH : INTEGER := 15;
		C_B1_BRAM_IF_SUPPORT : INTEGER range 0 to 1 := 0;
		C_B1_BLOCK_ENABLED : INTEGER range 0 to 1 := 1;
		C_PORT_B2_DWIDTH : INTEGER := 16;
		C_PORT_B2_AWIDTH : INTEGER := 16;
		C_B2_BRAM_IF_SUPPORT : INTEGER range 0 to 1 := 0;
		C_B2_BLOCK_ENABLED : INTEGER range 0 to 1 := 1;
		C_PORT_B3_DWIDTH : INTEGER := 32;
		C_PORT_B3_AWIDTH : INTEGER := 32;
		C_B3_BRAM_IF_SUPPORT : INTEGER range 0 to 1 := 1;
		C_B3_BLOCK_ENABLED : INTEGER range 0 to 1 := 1;
		-- generics without effect for xilinx ..._bram_if_cntlr
		C_MEMSIZE : INTEGER := 8192;
		C_NUM_WE : INTEGER := 4;
		C_FAMILY : STRING := "virtex2p"
	);
	PORT (
		-- instance GLOBAL
		-- PORT A for PPC405
		i_EN_A : IN STD_LOGIC;
		i_Clk_A : IN STD_LOGIC;
		i_Rst_A : IN STD_LOGIC;
		i_Data_A : IN STD_LOGIC_VECTOR(0 TO C_PORT_DWIDTH-1);   -- 32 or 64 bit
		o_Data_A : OUT STD_LOGIC_VECTOR(0 TO C_PORT_DWIDTH-1);  -- 32 or 64 bit
		i_Addr_A : IN STD_LOGIC_VECTOR(0 TO C_PORT_AWIDTH-1);
		i_WEN_A : IN STD_LOGIC_VECTOR(0 TO C_PORT_DWIDTH/8-1);  -- 4 or 8 ByteWriteEnables
		-- PORT B0
		i_EN_B0 : IN STD_LOGIC:='0';
		i_Clk_B0 : IN STD_LOGIC:='0';
		i_Rst_B0 : IN STD_LOGIC:='0';
		i_Data_B0 : IN STD_LOGIC_VECTOR(C_PORT_B0_DWIDTH-1 downto 0):=(others=>'0');
		o_Data_B0 : OUT STD_LOGIC_VECTOR(C_PORT_B0_DWIDTH-1 downto 0);
		o_Parity_AB0 : OUT std_logic_vector(3 downto 0);
		i_Addr_B0 : IN STD_LOGIC_VECTOR(0 to C_PORT_B0_AWIDTH-1):=(others=>'0');
		i_WEN_B0 : IN STD_LOGIC_VECTOR(0 to 3):=(others=>'0');
		-- PORT B1
		i_EN_B1 : IN STD_LOGIC:='0';
		i_Clk_B1 : IN STD_LOGIC:='0';
		i_Rst_B1 : IN STD_LOGIC:='0';
		i_Data_B1 : IN STD_LOGIC_VECTOR(C_PORT_B1_DWIDTH-1 downto 0):=(others=>'0');
		o_Data_B1 : OUT STD_LOGIC_VECTOR(C_PORT_B1_DWIDTH-1 downto 0);
		o_Parity_AB1 : OUT std_logic_vector(3 downto 0);
		i_Addr_B1 : IN STD_LOGIC_VECTOR(0 to C_PORT_B1_AWIDTH-1):=(others=>'0');
		i_WEN_B1 : IN STD_LOGIC_VECTOR(0 to 3):=(others=>'0');
		-- PORT B2
		i_EN_B2 : IN STD_LOGIC:='0';
		i_Clk_B2 : IN STD_LOGIC:='0';
		i_Rst_B2 : IN STD_LOGIC:='0';
		i_Data_B2 : IN STD_LOGIC_VECTOR(C_PORT_B2_DWIDTH-1 downto 0):=(others=>'0');
		o_Data_B2 : OUT STD_LOGIC_VECTOR(C_PORT_B2_DWIDTH-1 downto 0);
		o_Parity_AB2 : OUT std_logic_vector(3 downto 0);
		i_Addr_B2 : IN STD_LOGIC_VECTOR(0 to C_PORT_B2_AWIDTH-1):=(others=>'0');
		i_WEN_B2 : IN STD_LOGIC_VECTOR(0 to 3):=(others=>'0');
		-- PORT B3
		i_EN_B3 : IN STD_LOGIC:='0';
		i_Clk_B3 : IN STD_LOGIC:='0';
		i_Rst_B3 : IN STD_LOGIC:='0';
		i_Data_B3 : IN STD_LOGIC_VECTOR(C_PORT_B3_DWIDTH-1 downto 0):=(others=>'0');
		o_Data_B3 : OUT STD_LOGIC_VECTOR(C_PORT_B3_DWIDTH-1 downto 0);
		o_Parity_AB3 : OUT std_logic_vector(3 downto 0);
		i_Addr_B3 : IN STD_LOGIC_VECTOR(0 to C_PORT_B3_AWIDTH-1):=(others=>'0');
		i_WEN_B3 : IN STD_LOGIC_VECTOR(0 to 3):=(others=>'0')
	);
END dpr1aNb;

ARCHITECTURE IMP OF dpr1aNb IS

--------------------------------------------------------------------------------
-- types -----------------------------------------------------------------------
	type t_generic_arr is array (0 to 3) of integer;
	type t_data_arr is array (0 to 3) of std_logic_vector(127 downto 0);
	type t_dataa_arr is array (0 to 3) of std_logic_vector(31 downto 0);
	type t_addr_arr is array (0 to 3) of std_logic_vector(0 to 31);
	type t_sig_arr is array (0 to 3) of std_logic;
	type t_wen_arr is array (0 to 3) of std_logic_vector(0 to 3);
	type t_o_Parity_arr is array (0 to 3) of std_logic_vector(3 downto 0);
-- constants -------------------------------------------------------------------
	constant C_PORTB_DWIDTH : t_generic_arr := (C_PORT_B0_DWIDTH,C_PORT_B1_DWIDTH,C_PORT_B2_DWIDTH,C_PORT_B3_DWIDTH);
	constant C_PORTB_AWIDTH : t_generic_arr := (C_PORT_B0_AWIDTH,C_PORT_B1_AWIDTH,C_PORT_B2_AWIDTH,C_PORT_B3_AWIDTH);
	constant DF_BLOCK_ENABLE : t_generic_arr := (C_B0_BLOCK_ENABLED, C_B1_BLOCK_ENABLED, C_B2_BLOCK_ENABLED, C_B3_BLOCK_ENABLED);
--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------

	SIGNAL dina : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL douta : t_dataa_arr;

	SIGNAL dinb : t_data_arr;
	SIGNAL doutb : t_data_arr;
	SIGNAL dinbX : t_data_arr;
	SIGNAL doutbX : t_data_arr;
	signal WEN_B : t_wen_arr;
	signal En_B : t_sig_arr;
	signal Clk_B : t_sig_arr;
	signal Addr_B : t_addr_arr;
	signal Parity_A : t_o_Parity_arr;

	signal selector : std_logic_vector(0 to 1);
	signal wena : std_logic_vector(0 to 3);

	signal CS_seg : t_sig_arr;

	SIGNAL net_gnd0 : STD_LOGIC;
	SIGNAL net_gnd1 : STD_LOGIC_VECTOR(0 TO 0);
	SIGNAL net_gnd4 : STD_LOGIC_VECTOR(0 TO 3);
	SIGNAL net_gnd32 : STD_LOGIC_VECTOR(0 TO 31);

	constant ADDR_WIDTH : integer := 11; --log2(BRAM size in byte)
	constant DF_ADDR_HIGH : integer := C_PORT_AWIDTH-3;
BEGIN

--------------------------------------------------------------------------------
-- Power assignments
net_gnd0 <= '0';
net_gnd1 <= "0";
net_gnd4 <= "0000";
net_gnd32 <= "00000000000000000000000000000000";
--------------------------------------------------------------------------------
-- Port A
--------------------------------------------------------------------------------
D_64: if C_PORT_DWIDTH=64 generate
begin
	dina    <= i_Data_A(0 to 31) when i_Addr_A(DF_ADDR_HIGH)='0' else i_Data_A(32 to 63);
	wena    <= i_WEN_A(0 to 3) when i_Addr_A(DF_ADDR_HIGH)='0' else i_WEN_A(4 to 7);
end generate D_64;
D_32: if C_PORT_DWIDTH/=64 generate
begin
	dina    <= i_Data_A;
	wena    <= i_WEN_A(0 to 3);
end generate D_32;

blocksize1 : if C_NUM_OF_BLOCKS=1 generate
begin
	selector <= "00";
end generate blocksize1;
blocksize2 : if C_NUM_OF_BLOCKS=2 generate
begin
	selector <= '0' & i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH);
end generate blocksize2;
blocksize34 : if C_NUM_OF_BLOCKS>2 generate
begin
	selector <= i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH-ADDR_WIDTH);
end generate blocksize34;

ppc_cs : process(selector,i_En_A,douta,i_Addr_A)
begin
	CS_Seg <= (others => '0');
	o_Data_A <= (others => '0');
	for n in 0 to C_NUM_OF_BLOCKS-1 loop
		if (selector=n) then
			CS_Seg(n)  <= i_En_A;
			if C_PORT_DWIDTH=32 then
				o_Data_A <= douta(n);
			elsif C_PORT_DWIDTH=64 then
				o_Data_A <= douta(n) & douta(n);
			end if;
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
NO_BRAM_IF_SUP0 : if C_B0_BRAM_IF_SUPPORT=0 generate
begin
	Addr_B(0) <= i_Addr_B0 & net_gnd32(i_Addr_B0'length to Addr_B(0)'length-1);
end generate NO_BRAM_IF_SUP0;
BRAM_IF_SUP0 : if C_B0_BRAM_IF_SUPPORT=1 generate
begin
	Addr_B(0) <= i_Addr_B0(29-ADDR_WIDTH+1 to 29) & net_gnd32(0 to Addr_B(0)'length-ADDR_WIDTH-1);
end generate BRAM_IF_SUP0;
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
NO_BRAM_IF_SUP1 : if C_B1_BRAM_IF_SUPPORT=0 generate
begin
	Addr_B(1) <= i_Addr_B1 & net_gnd32(i_Addr_B1'length to Addr_B(1)'length-1);
end generate NO_BRAM_IF_SUP1;
BRAM_IF_SUP1 : if C_B1_BRAM_IF_SUPPORT=1 generate
begin
	Addr_B(1) <= i_Addr_B1(29-ADDR_WIDTH+1 to 29) & net_gnd32(0 to Addr_B(1)'length-ADDR_WIDTH-1);
end generate BRAM_IF_SUP1;
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
NO_BRAM_IF_SUP2 : if C_B2_BRAM_IF_SUPPORT=0 generate
begin
	Addr_B(2) <= i_Addr_B2 & net_gnd32(i_Addr_B2'length to Addr_B(2)'length-1);
end generate NO_BRAM_IF_SUP2;
BRAM_IF_SUP2 : if C_B2_BRAM_IF_SUPPORT=1 generate
begin
	Addr_B(2) <= i_Addr_B2(29-ADDR_WIDTH+1 to 29) & net_gnd32(0 to Addr_B(2)'length-ADDR_WIDTH-1);
end generate BRAM_IF_SUP2;
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
NO_BRAM_IF_SUP3 : if C_B3_BRAM_IF_SUPPORT=0 generate
begin
	Addr_B(3) <= i_Addr_B3 & net_gnd32(i_Addr_B3'length to Addr_B(3)'length-1);
end generate NO_BRAM_IF_SUP3;
BRAM_IF_SUP3 : if C_B3_BRAM_IF_SUPPORT=1 generate
begin
	Addr_B(3) <= i_Addr_B3(29-ADDR_WIDTH+1 to 29) & net_gnd32(0 to Addr_B(3)'length-ADDR_WIDTH-1);
end generate BRAM_IF_SUP3;
--------------------------------------------------------------------------------
-- block ram component imp.
--------------------------------------------------------------------------------
num_of_block : for j in 0 to C_NUM_OF_BLOCKS-1 generate
begin
	blockenabled : if DF_BLOCK_ENABLE(j)=1 generate
	begin
		block4bram : for i in 0 to 3 generate
		begin
			RamSel_4 : if C_PORTB_DWIDTH(j) = 4 generate
				constant C_AWIDTH_B : integer := 14;
			begin
				RAMB : RAMB16_S1_S9
				generic map (
					WRITE_MODE_A => "READ_FIRST", -- WRITE_FIRST, READ_FIRST or NO_CHANGE
					WRITE_MODE_B => "READ_FIRST"  -- WRITE_FIRST, READ_FIRST or NO_CHANGE
				)
				port map (
					-- port A is port B on BRAM
					DIB => dina(31-8*i DOWNTO 24-8*i),
					DOB => douta(j)(31-8*i DOWNTO 24-8*i),
					DIPB => net_gnd1,
					DOPB => Parity_A(j)(i downto i),
					ENB => CS_Seg(j),
					WEB => wena(i),
					SSRB => net_gnd0,
					CLKB => i_Clk_A,
					ADDRB => i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH+1 to DF_ADDR_HIGH),
					-- port B is port A on BRAM
					DIA => dinb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DOA => doutb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					ENA => En_B(j),
					WEA => WEn_B(j)(i),
					SSRA => net_gnd0,
					CLKA => Clk_B(j),
					ADDRA => Addr_B(j)(0 to C_AWIDTH_B-1)
				);
			end generate RamSel_4;
			RamSel_8 : if C_PORTB_DWIDTH(j) = 8 generate
				constant C_AWIDTH_B : integer := 13;
			begin
				RAMB : RAMB16_S2_S9
				generic map (
					WRITE_MODE_A => "READ_FIRST", -- WRITE_FIRST, READ_FIRST or NO_CHANGE
					WRITE_MODE_B => "READ_FIRST"  -- WRITE_FIRST, READ_FIRST or NO_CHANGE
				)
				port map (
					-- port A is port B on BRAM
					DIB => dina(31-8*i DOWNTO 24-8*i),
					DOB => douta(j)(31-8*i DOWNTO 24-8*i),
					DIPB => net_gnd1,
					DOPB => Parity_A(j)(i downto i),
					ENB => CS_Seg(j),
					WEB => wena(i),
					SSRB => net_gnd0,
					CLKB => i_Clk_A,
					ADDRB => i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH+1 to DF_ADDR_HIGH),
					-- port B is port A on BRAM
					DIA => dinb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DOA => doutb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					ENA => En_B(j),
					WEA => WEn_B(j)(i),
					SSRA => net_gnd0,
					CLKA => Clk_B(j),
					ADDRA => Addr_B(j)(0 to C_AWIDTH_B-1)
				);
			end generate RamSel_8;
			RamSel_16 : if C_PORTB_DWIDTH(j) = 16 generate
				constant C_AWIDTH_B : integer := 12;
			begin
				RAMB : RAMB16_S4_S9
				generic map (
					WRITE_MODE_A => "READ_FIRST", -- WRITE_FIRST, READ_FIRST or NO_CHANGE
					WRITE_MODE_B => "READ_FIRST"  -- WRITE_FIRST, READ_FIRST or NO_CHANGE
				)
				port map (
					-- port A is port B on BRAM
					DIB => dina(31-8*i DOWNTO 24-8*i),
					DOB => douta(j)(31-8*i DOWNTO 24-8*i),
					DIPB => net_gnd1,
					DOPB => Parity_A(j)(i downto i),
					ENB => CS_Seg(j),
					WEB => wena(i),
					SSRB => net_gnd0,
					CLKB => i_Clk_A,
					ADDRB => i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH+1 to DF_ADDR_HIGH),
					-- port B is port A on BRAM
					DIA => dinb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DOA => doutb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					ENA => En_B(j),
					WEA => WEn_B(j)(i),
					SSRA => net_gnd0,
					CLKA => Clk_B(j),
					ADDRA => Addr_B(j)(0 to C_AWIDTH_B-1)
				);
			end generate RamSel_16;
			RamSel_32 : if C_PORTB_DWIDTH(j) = 32 generate
				constant C_AWIDTH_B : integer := 11;
			begin
				RAMB : RAMB16_S9_S9
				generic map (
					WRITE_MODE_A => "READ_FIRST", -- WRITE_FIRST, READ_FIRST or NO_CHANGE
					WRITE_MODE_B => "READ_FIRST"  -- WRITE_FIRST, READ_FIRST or NO_CHANGE
				)
				port map (
					-- port A
					DIA => dina(31-8*i DOWNTO 24-8*i),
					DOA => douta(j)(31-8*i DOWNTO 24-8*i),
					DIPA => net_gnd1,
					DOPA => Parity_A(j)(i downto i),
					ENA => CS_Seg(j),
					WEA => wena(i),
					SSRA => net_gnd0,
					CLKA => i_Clk_A,
					ADDRA => i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH+1 to DF_ADDR_HIGH),
					-- port B
					DIB => dinb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DOB => doutb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DIPB => net_gnd4(0 to C_PORTB_DWIDTH(j)/4/8-1),
					DOPB => open,
					ENB => En_B(j),
					WEB => WEn_B(j)(i),
					SSRB => net_gnd0,
					CLKB => Clk_B(j),
					ADDRB => Addr_B(j)(0 to C_AWIDTH_B-1)
				);
			end generate RamSel_32;
			RamSel_64 : if C_PORTB_DWIDTH(j) = 64 generate
				constant C_AWIDTH_B : integer := 10;
			begin
				RAMB : RAMB16_S9_S18
				generic map (
					WRITE_MODE_A => "READ_FIRST", -- WRITE_FIRST, READ_FIRST or NO_CHANGE
					WRITE_MODE_B => "READ_FIRST"  -- WRITE_FIRST, READ_FIRST or NO_CHANGE
				)
				port map (
					-- port A
					DIA => dina(31-8*i DOWNTO 24-8*i),
					DOA => douta(j)(31-8*i DOWNTO 24-8*i),
					DIPA => net_gnd1,
					DOPA => Parity_A(j)(i downto i),
					ENA => CS_Seg(j),
					WEA => wena(i),
					SSRA => net_gnd0,
					CLKA => i_Clk_A,
					ADDRA => i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH+1 to DF_ADDR_HIGH),
					-- port B
					DIB => dinb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DOB => doutb(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DIPB => net_gnd4(0 to C_PORTB_DWIDTH(j)/4/8-1),
					DOPB => open,
					ENB => En_B(j),
					WEB => WEn_B(j)(i),
					SSRB => net_gnd0,
					CLKB => Clk_B(j),
					ADDRB => Addr_B(j)(0 to C_AWIDTH_B-1)
				);
			end generate RamSel_64;
			RamSel_128 : if C_PORTB_DWIDTH(j) = 128 generate
				constant C_AWIDTH_B : integer := 9;
			begin
				dinbX(j)(103 downto 96) <= dinb(j)(127 downto 120);	--c<-f
				dinbX(j)(71 downto 64) <= dinb(j)(119 downto 112);	--8<-e
				dinbX(j)(39 downto 32) <= dinb(j)(111 downto 104);	--4<-d
				dinbX(j)(7 downto 0) <= dinb(j)(103 downto 96);		--0<-c
				dinbX(j)(111 downto 104) <= dinb(j)(95 downto 88);	--d<-b
				dinbX(j)(79 downto 72) <= dinb(j)(87 downto 80);	--9<-a
				dinbX(j)(47 downto 40) <= dinb(j)(79 downto 72);	--5<-9
				dinbX(j)(15 downto 8) <= dinb(j)(71 downto 64);		--1<-8
				dinbX(j)(119 downto 112) <= dinb(j)(63 downto 56);	--e<-7
				dinbX(j)(87 downto 80) <= dinb(j)(55 downto 48);	--a<-6
				dinbX(j)(55 downto 48) <= dinb(j)(47 downto 40);	--6<-5
				dinbX(j)(23 downto 16) <= dinb(j)(39 downto 32);	--2<-4
				dinbX(j)(127 downto 120) <= dinb(j)(31 downto 24);	--f<-3
				dinbX(j)(95 downto 88) <= dinb(j)(23 downto 16);	--b<-2
				dinbX(j)(63 downto 56) <= dinb(j)(15 downto 8);		--7<-1
				dinbX(j)(31 downto 24) <= dinb(j)(7 downto 0);		--3<-0
	
				doutb(j)(127 downto 120) <= doutbX(j)(103 downto 96);--f<-c
				doutb(j)(119 downto 112) <= doutbX(j)(71 downto 64);--e<-8
				doutb(j)(111 downto 104) <= doutbX(j)(39 downto 32);--d<-4
				doutb(j)(103 downto 96) <= doutbX(j)(7 downto 0);	--c<-0
				doutb(j)(95 downto 88) <= doutbX(j)(111 downto 104);--b<-d
				doutb(j)(87 downto 80) <= doutbX(j)(79 downto 72);	--a<-9
				doutb(j)(79 downto 72) <= doutbX(j)(47 downto 40);	--9<-5
				doutb(j)(71 downto 64) <= doutbX(j)(15 downto 8);	--8<-1
				doutb(j)(63 downto 56) <= doutbX(j)(119 downto 112);--7<-e
				doutb(j)(55 downto 48) <= doutbX(j)(87 downto 80);	--6<-a
				doutb(j)(47 downto 40) <= doutbX(j)(55 downto 48);	--5<-6
				doutb(j)(39 downto 32) <= doutbX(j)(23 downto 16);	--4<-2
				doutb(j)(31 downto 24) <= doutbX(j)(127 downto 120);--3<-f
				doutb(j)(23 downto 16) <= doutbX(j)(95 downto 88);	--2<-b
				doutb(j)(15 downto 8) <= doutbX(j)(63 downto 56);	--1<-7
				doutb(j)(7 downto 0) <= doutbX(j)(31 downto 24);	--0<-3
	
				RAMB : RAMB16_S9_S36
				generic map (
					WRITE_MODE_A => "READ_FIRST", -- WRITE_FIRST, READ_FIRST or NO_CHANGE
					WRITE_MODE_B => "READ_FIRST"  -- WRITE_FIRST, READ_FIRST or NO_CHANGE
				)
				port map (
					-- port A
					DIA => dina(31-8*i DOWNTO 24-8*i),
					DOA => douta(j)(31-8*i DOWNTO 24-8*i),
					DIPA => net_gnd1,
					DOPA => Parity_A(j)(i downto i),
					ENA => CS_Seg(j),
					WEA => wena(i),
					SSRA => net_gnd0,
					CLKA => i_Clk_A,
					ADDRA => i_Addr_A(DF_ADDR_HIGH-ADDR_WIDTH+1 to DF_ADDR_HIGH),
					-- port B
					DIB => dinbX(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DOB => doutbX(j)(C_PORTB_DWIDTH(j)-1-C_PORTB_DWIDTH(j)/4*i DOWNTO C_PORTB_DWIDTH(j)-C_PORTB_DWIDTH(j)/4*(i+1)),
					DIPB => net_gnd4(0 to C_PORTB_DWIDTH(j)/4/8-1),
					DOPB => open,
					ENB => En_B(j),
					WEB => WEn_B(j)(i),
					SSRB => net_gnd0,
					CLKB => Clk_B(j),
					ADDRB => Addr_B(j)(0 to C_AWIDTH_B-1)
				);
			end generate RamSel_128;
		end generate block4bram;
	end generate blockenabled;
	blockdisabled : if DF_BLOCK_ENABLE(j)=0 generate
	begin
		doutb(j) <= (others => '0');
		Parity_A(j) <= (others => '0');
		douta(j) <=  (others => '0');
	end generate blockdisabled;
end generate num_of_block;
--------------------------------------------------------------------------------
END ARCHITECTURE IMP;
