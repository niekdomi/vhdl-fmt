-------------------------------------------------------------------------------
-- boot_ram_sys_isocm.vhd
--------------------------------------------------------------------------------
--
--	project     : boot_ram_sys_isocm
--	programmer  : C. Leuthold, INDEL AG
--	date        : 04.01.2006
--	version     : 1.00
--	language    : VHDL 
--	system      : ise / v2p
--
--------------------------------------------------------------------------------
--	purpose
--
--	dualport ram 4, 8 or 16 brams (8k, 16k or 32k) as bootram in ppc_module.vhd
--	side a: 32 bit databus (opb)
--	side b: 64 bit databus (isocm)
--
--	initialized with:
--	jump to flash
--	ffffffec   3c20efff     lis     r1,0xefff
--	fffffff0   6021fffc     ori     r1,r1,0xfffc
--	fffffff4   7c2803a6     mtlr    r1
--	fffffff8   4e800020     blr
--	fffffffc   4bfffff0     b       0xffffffec
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	30.10.2006-le: - first steps... tested on sac / max4
--	05.12.2006-le: - change init. ffffffec 3c20e3ff lis r1,0xe3ff
--					 to           ffffffec 3c20efff lis r1,0xefff
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

Library UNISIM;
use UNISIM.vcomponents.all;


entity boot_ram_sys_isocm is
	generic (
		C_NUM_OF_BRAMS : INTEGER := 4 -- 4, 8 or 16
	);
	port (
		BRAM_Rst_A : in std_logic := L;
		BRAM_Clk_A : in std_logic := L;
		BRAM_EN_A : in std_logic := L;
		BRAM_WEN_A : in std_logic_vector(0 to 3) := (others => L);
		BRAM_Addr_A : in std_logic_vector(0 to 31) := (others => L);
		BRAM_Din_A : out std_logic_vector(0 to 31);
		BRAM_Dout_A : in std_logic_vector(0 to 31) := (others => L);
		BRAM_Rst_B : in std_logic := L;
		BRAM_Clk_B : in std_logic := L;
		BRAM_EN_B : in std_logic := L;
		BRAM_WEN_B : in std_logic_vector(0 to C_NUM_OF_BRAMS-1) := (others => L);
		BRAM_Addr_B : in std_logic_vector(0 to 31) := (others => L);
		BRAM_Din_B : out std_logic_vector(0 to 63);
		BRAM_Dout_B : in std_logic_vector(0 to 63) := (others => L)
	);
end boot_ram_sys_isocm;

architecture STRUCTURE of boot_ram_sys_isocm is
	-- Internal signals

	signal dina : std_logic_vector(31 downto 0);
	signal douta : std_logic_vector(31 downto 0);
	signal dinb : std_logic_vector(63 downto 0);
	signal doutb : std_logic_vector(63 downto 0);
	signal net_gnd : std_logic_vector(15 downto 0);
	signal gnd : std_logic;

begin

	-- Internal assignments

	dina(31 downto 0) <= BRAM_Dout_A(0 to 31);
	BRAM_Din_A(0 to 31) <= douta(31 downto 0);
	net_gnd <= (others => L);
	gnd <= L;
	
	ramsize_8k : if (C_NUM_OF_BRAMS=4) generate
	begin
		dinb(63 downto 56) <= BRAM_Dout_B(32 to 39);
		dinb(47 downto 40) <= BRAM_Dout_B(40 to 47);
		dinb(31 downto 24) <= BRAM_Dout_B(48 to 55);
		dinb(15 downto  8) <= BRAM_Dout_B(56 to 63);
		dinb(55 downto 48) <= BRAM_Dout_B( 0 to  7);
		dinb(39 downto 32) <= BRAM_Dout_B( 8 to 15);
		dinb(23 downto 16) <= BRAM_Dout_B(16 to 23);
		dinb( 7 downto  0) <= BRAM_Dout_B(24 to 31);
		
		BRAM_Din_B(32 to 39) <= doutb(63 downto 56);
		BRAM_Din_B(40 to 47) <= doutb(47 downto 40);
		BRAM_Din_B(48 to 55) <= doutb(31 downto 24);
		BRAM_Din_B(56 to 63) <= doutb(15 downto  8);
		BRAM_Din_B( 0 to  7) <= doutb(55 downto 48);
		BRAM_Din_B( 8 to 15) <= doutb(39 downto 32);
		BRAM_Din_B(16 to 23) <= doutb(23 downto 16);
		BRAM_Din_B(24 to 31) <= doutb( 7 downto  0);
	
	
		ram_block_8k_0 : RAMB16_S9_S18
		generic map (
			INIT_3F => X"4b4e7c603c000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(19 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31 downto 24),
			DIPA => net_gnd(0 downto 0),
			DOA => douta(31 downto 24),
			DOPA => open,
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(19 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63 downto 48),
			DIPB => net_gnd(1 downto 0),
			DOB => doutb(63 downto 48),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(0)
		);
	
		ram_block_8k_1 : RAMB16_S9_S18
		generic map (
			INIT_3F => X"ff80282120000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(19 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(23 downto 16),
			DIPA => net_gnd(0 downto 0),
			DOA => douta(23 downto 16),
			DOPA => open,
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(19 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(47 downto 32),
			DIPB => net_gnd(1 downto 0),
			DOB => doutb(47 downto 32),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(1)
		);
		-- init jump to flash:
		ram_block_8k_2 : RAMB16_S9_S18
		generic map (
			INIT_3F => X"ff0003ffef000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(19 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(15 downto 8),
			DIPA => net_gnd(0 downto 0),
			DOA => douta(15 downto 8),
			DOPA => open,
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(19 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(31 downto 16),
			DIPB => net_gnd(1 downto 0),
			DOB => doutb(31 downto 16),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(2)
		);
	
		ram_block_8k_3 : RAMB16_S9_S18
		generic map (
			INIT_3F => X"f020a6fcff000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(19 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(7 downto 0),
			DIPA => net_gnd(0 downto 0),
			DOA => douta(7 downto 0),
			DOPA => open,
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(19 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(15 downto 0),
			DIPB => net_gnd(1 downto 0),
			DOB => doutb(15 downto 0),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(3)
		);
	end generate ramsize_8k;
	
	ramsize_16k : if (C_NUM_OF_BRAMS=8) generate
	begin
		dinb(59 downto 56) <= BRAM_Dout_B( 0 to  3);
		dinb(51 downto 48) <= BRAM_Dout_B( 4 to  7);
		dinb(43 downto 40) <= BRAM_Dout_B( 8 to 11);
		dinb(35 downto 32) <= BRAM_Dout_B(12 to 15);
		dinb(27 downto 24) <= BRAM_Dout_B(16 to 19);
		dinb(19 downto 16) <= BRAM_Dout_B(20 to 23);
		dinb(11 downto  8) <= BRAM_Dout_B(24 to 27);
		dinb( 3 downto  0) <= BRAM_Dout_B(28 to 31);
		dinb(63 downto 60) <= BRAM_Dout_B(32 to 35);
		dinb(55 downto 52) <= BRAM_Dout_B(36 to 39);
		dinb(47 downto 44) <= BRAM_Dout_B(40 to 43);
		dinb(39 downto 36) <= BRAM_Dout_B(44 to 47);
		dinb(31 downto 28) <= BRAM_Dout_B(48 to 51);
		dinb(23 downto 20) <= BRAM_Dout_B(52 to 55);
		dinb(15 downto 12) <= BRAM_Dout_B(56 to 59);
		dinb( 7 downto  4) <= BRAM_Dout_B(60 to 63);
		
		BRAM_Din_B( 0 to  3) <= doutb(59 downto 56);
		BRAM_Din_B( 4 to  7) <= doutb(51 downto 48);
		BRAM_Din_B( 8 to 11) <= doutb(43 downto 40);
		BRAM_Din_B(12 to 15) <= doutb(35 downto 32);
		BRAM_Din_B(16 to 19) <= doutb(27 downto 24);
		BRAM_Din_B(20 to 23) <= doutb(19 downto 16);
		BRAM_Din_B(24 to 27) <= doutb(11 downto  8);
		BRAM_Din_B(28 to 31) <= doutb( 3 downto  0);
		
		BRAM_Din_B(32 to 35) <= doutb(63 downto 60);
		BRAM_Din_B(36 to 39) <= doutb(55 downto 52);
		BRAM_Din_B(40 to 43) <= doutb(47 downto 44);
		BRAM_Din_B(44 to 47) <= doutb(39 downto 36);
		BRAM_Din_B(48 to 51) <= doutb(31 downto 28);
		BRAM_Din_B(52 to 55) <= doutb(23 downto 20);
		BRAM_Din_B(56 to 59) <= doutb(15 downto 12);
		BRAM_Din_B(60 to 63) <= doutb( 7 downto  4);
	
		ram_block_16k_0 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"4476300000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31 downto 28),
			DOA => douta(31 downto 28),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63 downto 56),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(63 downto 56),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(0)
		);
		
		ram_block_16k_1 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"bec0c00000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(27 downto 24),
			DOA => douta(27 downto 24),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(55 downto 48),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(55 downto 48),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(1)
		);
		
		ram_block_16k_2 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"f822200000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(23 downto 20),
			DOA => douta(23 downto 20),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(47 downto 40),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(47 downto 40),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(2)
		);
		
		ram_block_16k_3 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"f081000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(19 downto 16),
			DOA => douta(19 downto 16),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(39 downto 32),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(39 downto 32),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(3)
		);
		
		ram_block_16k_4 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"f00fe00000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(15 downto 12),
			DOA => douta(15 downto 12),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(31 downto 24),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(31 downto 24),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(4)
		);
		
		ram_block_16k_5 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"f03ff00000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(11 downto 8),
			DOA => douta(11 downto 8),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(23 downto 16),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(23 downto 16),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(5)
		);
		
		ram_block_16k_6 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"f2aff00000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(7 downto 4),
			DOA => douta(7 downto 4),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(15 downto 8),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(15 downto 8),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(6)
		);
		
		ram_block_16k_7 : RAMB16_S4_S9
		generic map (
			INIT_3F => X"006cf00000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(18 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(3 downto 0),
			DOA => douta(3 downto 0),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(18 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(7 downto 0),
			DIPB => net_gnd(0 downto 0),
			DOB => doutb(7 downto 0),
			DOPB => open,
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(7)
		);
	end generate ramsize_16k;
	
	ramsize_32k : if (C_NUM_OF_BRAMS=16) generate
	begin
		dinb(60+1 downto 60) <= BRAM_Dout_B( 0 to  1);
		dinb(56+1 downto 56) <= BRAM_Dout_B( 2 to  3);
		dinb(52+1 downto 52) <= BRAM_Dout_B( 4 to  5);
		dinb(48+1 downto 48) <= BRAM_Dout_B( 6 to  7);
		dinb(44+1 downto 44) <= BRAM_Dout_B( 8 to  9);
		dinb(40+1 downto 40) <= BRAM_Dout_B(10 to 11);
		dinb(36+1 downto 36) <= BRAM_Dout_B(12 to 13);
		dinb(32+1 downto 32) <= BRAM_Dout_B(14 to 15);
		dinb(28+1 downto 28) <= BRAM_Dout_B(16 to 17);
		dinb(24+1 downto 24) <= BRAM_Dout_B(18 to 19);
		dinb(20+1 downto 20) <= BRAM_Dout_B(20 to 21);
		dinb(16+1 downto 16) <= BRAM_Dout_B(22 to 23);
		dinb(12+1 downto 12) <= BRAM_Dout_B(24 to 25);
		dinb( 8+1 downto  8) <= BRAM_Dout_B(26 to 27);
		dinb( 4+1 downto  4) <= BRAM_Dout_B(28 to 29);
		dinb( 0+1 downto  0) <= BRAM_Dout_B(30 to 31);
		dinb(62+1 downto 62) <= BRAM_Dout_B(32 to 33);
		dinb(58+1 downto 58) <= BRAM_Dout_B(34 to 35);
		dinb(54+1 downto 54) <= BRAM_Dout_B(36 to 37);
		dinb(50+1 downto 50) <= BRAM_Dout_B(38 to 39);
		dinb(46+1 downto 46) <= BRAM_Dout_B(40 to 41);
		dinb(42+1 downto 42) <= BRAM_Dout_B(42 to 43);
		dinb(38+1 downto 38) <= BRAM_Dout_B(44 to 45);
		dinb(34+1 downto 34) <= BRAM_Dout_B(46 to 47);
		dinb(30+1 downto 30) <= BRAM_Dout_B(48 to 49);
		dinb(26+1 downto 26) <= BRAM_Dout_B(50 to 51);
		dinb(22+1 downto 22) <= BRAM_Dout_B(52 to 53);
		dinb(18+1 downto 18) <= BRAM_Dout_B(54 to 55);
		dinb(14+1 downto 14) <= BRAM_Dout_B(56 to 57);
		dinb(10+1 downto 10) <= BRAM_Dout_B(58 to 59);
		dinb( 6+1 downto  6) <= BRAM_Dout_B(60 to 61);
		dinb( 2+1 downto  2) <= BRAM_Dout_B(62 to 63);
		
		BRAM_Din_B( 0 to  1) <= doutb(60+1 downto 60);
		BRAM_Din_B( 2 to  3) <= doutb(56+1 downto 56);
		BRAM_Din_B( 4 to  5) <= doutb(52+1 downto 52);
		BRAM_Din_B( 6 to  7) <= doutb(48+1 downto 48);
		BRAM_Din_B( 8 to  9) <= doutb(44+1 downto 44);
		BRAM_Din_B(10 to 11) <= doutb(40+1 downto 40);
		BRAM_Din_B(12 to 13) <= doutb(36+1 downto 36);
		BRAM_Din_B(14 to 15) <= doutb(32+1 downto 32);
		BRAM_Din_B(16 to 17) <= doutb(28+1 downto 28);
		BRAM_Din_B(18 to 19) <= doutb(24+1 downto 24);
		BRAM_Din_B(20 to 21) <= doutb(20+1 downto 20);
		BRAM_Din_B(22 to 23) <= doutb(16+1 downto 16);
		BRAM_Din_B(24 to 25) <= doutb(12+1 downto 12);
		BRAM_Din_B(26 to 27) <= doutb( 8+1 downto  8);
		BRAM_Din_B(28 to 29) <= doutb( 4+1 downto  4);
		BRAM_Din_B(30 to 31) <= doutb( 0+1 downto  0);
		BRAM_Din_B(32 to 33) <= doutb(62+1 downto 62);
		BRAM_Din_B(34 to 35) <= doutb(58+1 downto 58);
		BRAM_Din_B(36 to 37) <= doutb(54+1 downto 54);
		BRAM_Din_B(38 to 39) <= doutb(50+1 downto 50);
		BRAM_Din_B(40 to 41) <= doutb(46+1 downto 46);
		BRAM_Din_B(42 to 43) <= doutb(42+1 downto 42);
		BRAM_Din_B(44 to 45) <= doutb(38+1 downto 38);
		BRAM_Din_B(46 to 47) <= doutb(34+1 downto 34);
		BRAM_Din_B(48 to 49) <= doutb(30+1 downto 30);
		BRAM_Din_B(50 to 51) <= doutb(26+1 downto 26);
		BRAM_Din_B(52 to 53) <= doutb(22+1 downto 22);
		BRAM_Din_B(54 to 55) <= doutb(18+1 downto 18);
		BRAM_Din_B(56 to 57) <= doutb(14+1 downto 14);
		BRAM_Din_B(58 to 59) <= doutb(10+1 downto 10);
		BRAM_Din_B(60 to 61) <= doutb( 6+1 downto  6);
		BRAM_Din_B(62 to 63) <= doutb( 2+1 downto  2);
	
		ram_block_32k_0 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"5500000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*0 downto 30-2*0),
			DOA => douta(31-2*0 downto 30-2*0),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*0 downto 60-4*0),
			DOB => doutb(63-4*0 downto 60-4*0),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(0)
		);
		
		ram_block_32k_1 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"0ec0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*1 downto 30-2*1),
			DOA => douta(31-2*1 downto 30-2*1),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*1 downto 60-4*1),
			DOB => doutb(63-4*1 downto 60-4*1),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(1)
		);
		
		ram_block_32k_2 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"bcc0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*2 downto 30-2*2),
			DOA => douta(31-2*2 downto 30-2*2),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*2 downto 60-4*2),
			DOB => doutb(63-4*2 downto 60-4*2),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(2)
		);
		
		ram_block_32k_3 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"e000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*3 downto 30-2*3),
			DOA => douta(31-2*3 downto 30-2*3),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(0),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*3 downto 60-4*3),
			DOB => doutb(63-4*3 downto 60-4*3),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(3)
		);
		
		ram_block_32k_4 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"e000000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*4 downto 30-2*4),
			DOA => douta(31-2*4 downto 30-2*4),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*4 downto 60-4*4),
			DOB => doutb(63-4*4 downto 60-4*4),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(4)
		);
		
		ram_block_32k_5 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"ca80000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*5 downto 30-2*5),
			DOA => douta(31-2*5 downto 30-2*5),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*5 downto 60-4*5),
			DOB => doutb(63-4*5 downto 60-4*5),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(5)
		);
		
		ram_block_32k_6 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"c800000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*6 downto 30-2*6),
			DOA => douta(31-2*6 downto 30-2*6),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*6 downto 60-4*6),
			DOB => doutb(63-4*6 downto 60-4*6),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(6)
		);
		
		ram_block_32k_7 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"c100000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*7 downto 30-2*7),
			DOA => douta(31-2*7 downto 30-2*7),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(1),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*7 downto 60-4*7),
			DOB => doutb(63-4*7 downto 60-4*7),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(7)
		);
		
		ram_block_32k_8 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"c3c0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*8 downto 30-2*8),
			DOA => douta(31-2*8 downto 30-2*8),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*8 downto 60-4*8),
			DOB => doutb(63-4*8 downto 60-4*8),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(8)
		);
		
		ram_block_32k_9 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"c380000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*9 downto 30-2*9),
			DOA => douta(31-2*9 downto 30-2*9),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*9 downto 60-4*9),
			DOB => doutb(63-4*9 downto 60-4*9),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(9)
		);
		
		ram_block_32k_10 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"c3c0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*10 downto 30-2*10),
			DOA => douta(31-2*10 downto 30-2*10),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*10 downto 60-4*10),
			DOB => doutb(63-4*10 downto 60-4*10),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(10)
		);
		
		ram_block_32k_11 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"cfc0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*11 downto 30-2*11),
			DOA => douta(31-2*11 downto 30-2*11),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(2),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*11 downto 60-4*11),
			DOB => doutb(63-4*11 downto 60-4*11),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(11)
		);
		
		ram_block_32k_12 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"cbc0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*12 downto 30-2*12),
			DOA => douta(31-2*12 downto 30-2*12),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*12 downto 60-4*12),
			DOB => doutb(63-4*12 downto 60-4*12),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(12)
		);
		
		ram_block_32k_13 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"ebc0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*13 downto 30-2*13),
			DOA => douta(31-2*13 downto 30-2*13),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*13 downto 60-4*13),
			DOB => doutb(63-4*13 downto 60-4*13),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(13)
		);
		
		ram_block_32k_14 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"07c0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*14 downto 30-2*14),
			DOA => douta(31-2*14 downto 30-2*14),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*14 downto 60-4*14),
			DOB => doutb(63-4*14 downto 60-4*14),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(14)
		);
		
		ram_block_32k_15 : RAMB16_S2_S4
		generic map (
			INIT_3F => X"08c0000000000000000000000000000000000000000000000000000000000000"
		)
		port map (
			ADDRA => BRAM_Addr_A(17 to 29),
			CLKA => BRAM_Clk_A,
			DIA => dina(31-2*15 downto 30-2*15),
			DOA => douta(31-2*15 downto 30-2*15),
			ENA => BRAM_EN_A,
			SSRA => BRAM_Rst_A,
			WEA => BRAM_WEN_A(3),
			ADDRB => BRAM_Addr_B(17 to 28),
			CLKB => BRAM_Clk_B,
			DIB => dinb(63-4*15 downto 60-4*15),
			DOB => doutb(63-4*15 downto 60-4*15),
			ENB => BRAM_EN_B,
			SSRB => BRAM_Rst_B,
			WEB => BRAM_WEN_B(15)
		);
		
	end generate ramsize_32k;

end architecture STRUCTURE;