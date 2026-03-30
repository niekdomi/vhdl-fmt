------------------------------------------------------------------------------
-- INDEL_pkg.vhd
-------------------------------------------------------------------------------
--
--	project		: INDEL PACKAGE
--	programmer	: C. Leuthold, INDEL AG
--	date		: 15.03.2006
--	version		: 1.00
--	language	: VHDL PACKAGE
--	system		: ise / v2p
--	
--	purpose	
--------------------------------------------------------------------------------
--	revision information
--	15.03.2006-le	: - first steps
--	01.11.2006-le	: add function vector_or()
--	21.11.2006-le	: add constant DF_PKG_TARGET_MAX4
--	21.11.2006-le	: add flags to pkg_rev_reg()
--					  add flag defines
--	12.03.2007-le	: add DF_PKG_TARGET_SBB
--	11.05.2007-le	: add svn keywords 
--	25.05.2007-le	: change pkg_log2: return 1 instead of 0 if value 0 to avoid
--						syntehesize errors (xst 9.1)
--	03.07.2007-le	: add DF_PKG_TARGET_SAC3x3
--	03.07.2007-le	: change DF_PKG_TARGET_SAC3x3 to 6
--	03.07.2007-le	: add defines for opbif_extmem 
--						DF_PKG_TARGET_LAN and DF_PKG_TARGET_NO_LAN
--	05.10.2007-le	: add constant DF_PKG_IMP_CRC_POLY
--					  add function crc_gen(..) to generate crcs with bit or 
--						vector input
--					  add function Return_Upper_F_I_PKG(..) 
--					  add functions min(..) and max(..) for integers 
--	10.10.2007-le	: add constant DF_PKG_IMP_CRC_INIT
--	05.02.2008-le	: add constants and func. for fpga types
--	05.02.2008-le	: change imp crc to a good 6 bit poly for 8-25 bit (find all 1, 2, 3 and 5 bit errors)
--	25.03.2008-le	: add DF_PKG_TARGET_HEAT
--	15.04.2008-le	: add function get_dec_from_string(..)
--	06.01.2009-le	: add function get_uprounded_div(..)
--					  add constant DF_PKG_TARGET_MAX10
--	19.05.2009-le	: add chr, str and dbg_int_out for debug output of constants
--	02.10.2009-rk	: add constant DF_PKG_TARGET_ZKMESS
--	16.07.2010-le	: add DF_PKG_TARGET_AX42
--					  add ramtype 64mb ddr
--					  add DF_PKG_TARGET_FLASH_MRAM for opbif_extmem: c/mram, flash but no lan
--	20.08.2010-le	: add function get_hex_from_string
--	11.10.2010-le	: add DF_PKG_TARGET_C64ACTIVEMASTER      
--	27.01.2011-fb	: add Array-Types tSLV_Nx__ and tSLV_NxNx__ 
--	07.06.2011-le	: rename Return_Upper_F_I_PKG to Return_Upper
--	27.08.2012-le	: support p2020 platform
--	20.09.2012-le	: add return value in assert of pkg_p2020_speed to suppress imp. warnings
--	25.09.2012-le	: add ginflags definitions
--	13.01.2014-ll	: add pkg_rev_reg without ram_width for cop-mas2
--	10.02.2016-le	: support p50xx platform (GIN-SAM4)
--	22.01.2018-le	: move constants for encoder serial interface to package
--	24.01.2018-vz	: add tSLV_NxNx96
--	13.04.2018-le	: add constants for BISS
--	16.07.2019-le	: add constant DF_PKG_TARGET_EMG for emergency fpgas
--------------------------------------------------------------------------------
--$Rev:: 5350                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-07-31 16:52:16 +0200 (Mi., 31 Jul 2019)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

package INDEL_pkg is
	
	constant H : std_logic := '1';
	constant L : std_logic := '0';
	constant Z : std_logic := 'Z';
	                                                        --  43210
	                                                        -- "10101"; -- g.704
	                                                        -- "00101"; -- usb token
	constant DF_PKG_IMP_CRC_POLY : std_logic_vector(5 downto 0) := "101100";-- 01011
	constant DF_PKG_IMP_CRC_INIT : std_logic_vector(5 downto 0) := "111111";
	
	-- defines for opbif_extmem
	constant DF_PKG_TARGET_LAN : integer := 0;
	constant DF_PKG_TARGET_NO_LAN : integer := 1;
	constant DF_PKG_TARGET_FLASH_MRAM : integer := 100;
	
	constant DF_PKG_TARGET_IMP2 : integer := 0;
	constant DF_PKG_TARGET_SAC2 : integer := 1;
	constant DF_PKG_TARGET_MAX2 : integer := 2;
	constant DF_PKG_TARGET_IT_MAS2 : integer := 3;
	constant DF_PKG_TARGET_MAX4 : integer := 4;
	constant DF_PKG_TARGET_SBB : integer := 5;
	constant DF_PKG_TARGET_SAC3x3 : integer := 6;
	constant DF_PKG_TARGET_HEAT : integer := 7;
	constant DF_PKG_TARGET_MAX10 : integer := 8;
	constant DF_PKG_TARGET_ZKMESS : integer := 9;
	constant DF_PKG_TARGET_AX42 : integer := 10;
	constant DF_PKG_TARGET_C64ACTIVEMASTER : integer := 11;
	constant DF_PKG_TARGET_EMG : integer := 15;
	
	constant DF_PKG_TARGETP2020_PCIE : integer := 0;
	constant DF_PKG_TARGETP2020_MAS4 : integer := 1;
	
	constant DF_PKG_TARGETP50xx_SAM4 : integer := 0;
	
	constant DF_PKG_P2020_1200 : integer := 0;
	constant DF_PKG_P2020_1000 : integer := 1;
	
	constant DF_PKG_CARD_TYP_IMP2 : std_logic_vector(2 downto 0) := "100";
	constant DF_PKG_CARD_TYP_SAC2 : std_logic_vector(2 downto 0) := "011";
	
	constant DF_FLG_ISOCM_32 : std_logic_vector := "0010";
	constant DF_FLG_CIRQ : std_logic_vector := "0001";
	
	constant DF_PKG_FPGA_TYPE_V2P : integer := 0;
	constant DF_PKG_FPGA_TYPE_V4 : integer := 1;
	
	constant DF_PKG_SDRAM : integer := 0;
	constant DF_PKG_DDR_SDRAM : integer := 1;
	
	-- registers COP-MAS2, IMP-MAS4, GIN-PCIe, GIN-SAM4
	constant DF_REG_FLG_RANGE : integer := 0;
	constant DF_REG_GFL_RANGE : integer := 1;
	constant DF_REG_C16_RANGE : integer := 2;
	constant DF_REG_FFL_RANGE : integer := 3;
	constant DF_REG_CNT_RANGE : integer := 4;
	constant DF_REG_REQ_RANGE : integer := 5;
	constant DF_REG_CAN_RANGE : integer := 6;
	constant DF_REG_MII_RANGE : integer := 7;
	constant DF_REG_IDH_RANGE : integer := 8;
	constant DF_REG_IDL_RANGE : integer := 9;
	constant DF_REG_ILM_RANGE : integer := 12;
	constant DF_REG_IMP_RANGE : integer := 13;
	constant DF_REG_REV_RANGE : integer := 15;--last
	constant DF_REG_SVN_RANGE : integer := DF_REG_REV_RANGE-1;
	
	-- ginflags
	constant DF_GINRING : integer := 0;
	constant DF_GINAUTOCLOSE : integer := 1;
	constant DF_GF_RING : integer := DF_GINRING;
	constant DF_GF_AUTOCLOSE : integer := DF_GINAUTOCLOSE;
	constant DF_GF_ECAT : integer := 4;
	constant DF_GF_MULTIBUF : integer := 5;
	constant DF_GF_ECAT_2 : integer := 8;
	constant DF_GF_MULTIBUF_2 : integer := 9;
	constant DF_GF_MRAM : integer := 24;
	
	-- encoder serial interface selector
	constant DF_SEL_END : std_logic_vector(1 downto 0) := "00";
	constant DF_SEL_SSI : std_logic_vector(1 downto 0) := "01";
	constant DF_SEL_HIP : std_logic_vector(1 downto 0) := "10";
	constant DF_SEL_BIS : std_logic_vector(1 downto 0) := "11";
	-- encoder serial interface
	constant DF_ESI_GPIO		: integer := 0;
	constant DF_ESI_SSI			: integer := 1;
	constant DF_ESI_RS485		: integer := 2;
	constant DF_ESI_RS422		: integer := 3;
	constant DF_ESI_ENDAT		: integer := 4;
	constant DF_ESI_HIPER		: integer := 5;
	constant DF_ESI_INC			: integer := 6;
	constant DF_ESI_RES			: integer := 7;
	constant DF_ESI_RES2ENC		: integer := 8;
	constant DF_ESI_SSI_CONT	: integer := 9;-- 9
	constant DF_ESI_RS485_INV	: integer := 10;-- A
	constant DF_ESI_RS422_INV	: integer := 11;-- B
	constant DF_ESI_ENDAT_CONT	: integer := 12;-- C
	constant DF_ESI_BISS		: integer := 13;-- D
	constant DF_ESI_BISS_CONT	: integer := 14;-- E
	constant DF_ESI_EXTEND		: integer := 15;-- F

	type	tSLV_Nx2	is array(natural RANGE <>)					of std_logic_vector( 1 downto 0); 
	type	tSLV_Nx4	is array(natural RANGE <>)					of std_logic_vector( 3 downto 0); 
	type	tSLV_Nx8	is array(natural RANGE <>)					of std_logic_vector( 7 downto 0); 
    type	tSLV_Nx12	is array(natural RANGE <>)					of std_logic_vector(11 downto 0); 
	type	tSLV_Nx16	is array(natural RANGE <>)					of std_logic_vector(15 downto 0); 
	type	tSLV_Nx18	is array(natural RANGE <>)					of std_logic_vector(17 downto 0); 
	type	tSLV_Nx24	is array(natural RANGE <>)					of std_logic_vector(23 downto 0); 
	type	tSLV_Nx32	is array(natural RANGE <>)					of std_logic_vector(31 downto 0); 
	type	tSLV_Nx64	is array(natural RANGE <>)					of std_logic_vector(63 downto 0); 
	type	tSLV_Nx96	is array(natural RANGE <>)					of std_logic_vector(95 downto 0); 

	type	tSIG_Nx18	is array(natural RANGE <>)					of signed(17 downto 0); 
	type	tSIG_Nx32	is array(natural RANGE <>)					of signed(31 downto 0); 

	-- how to use example:
   	-- constant BRAM_Init : tSLV_Nx32(0 to 1023) := (
	-- 	448/4 => g_C96_Rev,  	-- 0x1C0    GAL_Revision
	-- 	768/4 => x"90000C35",  	-- 0x300	start 8kHz 40ns Timer, dis OverRun
	-- 	796/4 => x"11090080",  	-- 0x31C    read C96-EEP 
	--  	others => (others => '0'));       
    type	tSLV_NxNx2 	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector( 1 downto 0); 
    type	tSLV_NxNx4 	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector( 3 downto 0); 
    type	tSLV_NxNx8 	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector( 7 downto 0); 
    type	tSLV_NxNx16	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector(15 downto 0); 
    type	tSLV_NxNx24	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector(23 downto 0); 
    type	tSLV_NxNx32	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector(31 downto 0); 
    type	tSLV_NxNx64	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector(63 downto 0);
	type	tSLV_NxNx96	is array(natural RANGE <>,natural RANGE <>) of std_logic_vector(95 downto 0); 
	                                           
	function pkg_log2(value : natural) return integer;
	
	function pkg_rev_reg(target : integer; build_nr : integer;ram_width : integer; hw_rev : integer; gal_rev : integer) return std_logic_vector;
	
	function pkg_rev_reg(target : integer; build_nr : integer;ram_width : integer; hw_rev : integer; gal_rev : std_logic_vector) return std_logic_vector;
	
	function pkg_rev_reg(target : integer; build_nr : integer; flags : std_logic_vector; ram_width : integer; hw_rev : integer; gal_rev : std_logic_vector) return std_logic_vector;
	
	function pkg_rev_reg(target : integer; build_nr : integer; flags : std_logic_vector; hw_rev : integer; gal_rev : std_logic_vector) return std_logic_vector;
	-- confusing name crossbits: conversion of TO <= DOWNTO or DOWNTO <= TO. unusable for DOWNTO <= DOWNTO
	function crossbits(X : std_logic_vector) return std_logic_vector;
	
	function vector_or(inputs : std_logic_vector) return std_logic;
	
	function max(L, R: integer) return integer;
	
	function min(L, R: integer) return integer;
	
	function Return_Upper(Count: natural) return natural;
	
	function crc_gen(input : std_logic; last_crc_val : std_logic_vector; crc_poly : std_logic_vector) return std_logic_vector;
	
	function crc_gen(input : std_logic_vector; last_crc_val : std_logic_vector; crc_poly : std_logic_vector) return std_logic_vector;
	
	function get_fpga_type_str(input : integer) return string;
	
	function get_dec_from_string(str : string; lng : positive) return std_logic_vector;
	
	function get_hex_from_string(str : string; lng : positive) return std_logic_vector;
	function get_hex_from_string(str : string; lng : positive; abort : character) return std_logic_vector;
	
	function get_uprounded_div(a,b : positive) return positive;
	
	function chr(int: integer) return character;
	
	function str(int: integer; base: integer) return string;
	
	procedure dbg_int_out(int:in integer);
	
	procedure dbg_int_out(name:in string; int:in integer);
	
	function pkg_p2020_speed(speed: integer) return std_logic_vector;
	
	function getMultiBuf (NoBufferPair : integer) return std_logic;
	
end INDEL_pkg;

package body INDEL_pkg is

	function pkg_log2(value : natural) return integer is
	begin
		if value=0 then
			return 1;
		end if;
		for i in 0 to 31 loop
			if ((2**i)>=value) then
				return i;
			end if;
		end loop;
		return -1;
	end pkg_log2;
	
	function pkg_rev_reg(target : integer; build_nr : integer;ram_width : integer; hw_rev : integer; gal_rev : integer) return std_logic_vector is
	begin
		return pkg_rev_reg(target, build_nr, ram_width, hw_rev, CONV_STD_LOGIC_VECTOR(gal_rev, 12));
	end pkg_rev_reg;
	
	function pkg_rev_reg(target : integer; build_nr : integer; ram_width : integer; hw_rev : integer; gal_rev : std_logic_vector) return std_logic_vector is
	begin
		return pkg_rev_reg(target, build_nr, "0000", ram_width, hw_rev, gal_rev);
	end pkg_rev_reg;
	
	function pkg_rev_reg(target : integer; build_nr : integer; flags : std_logic_vector; ram_width : integer; hw_rev : integer; gal_rev : std_logic_vector) return std_logic_vector is
	variable rev_reg : std_logic_vector(31 downto 0) := (others => L);
	begin
		rev_reg(31 downto 28) := CONV_STD_LOGIC_VECTOR(target, 4);
		rev_reg(27 downto 24) := CONV_STD_LOGIC_VECTOR(build_nr, 4);
		rev_reg(23 downto 20) := flags(3 downto 0);
		-- ram type
		if (ram_width=32) then -- ppc-card 32mb 32bit sd / ppc-card4 32mb 16bit ddr
			rev_reg(19 downto 16) := x"0";
		elsif (ram_width=16) then -- ppc-card 16mb 16bit sd
			rev_reg(19 downto 16) := x"1";
		elsif (ram_width=64) then -- c96-ppc-card4/ppc-card4 64mb 16bit ddr
			rev_reg(19 downto 16) := x"2";
		else
			rev_reg(19 downto 16) := x"F";
			assert 1<0
			report "unsupported sdram type" severity error;
		end if;
		rev_reg(15 downto 12) := CONV_STD_LOGIC_VECTOR(hw_rev, 4);
		rev_reg(11 downto 0) := gal_rev(11 downto 0);
		return rev_reg;
	end pkg_rev_reg;
	
	function pkg_rev_reg(target : integer; build_nr : integer; flags : std_logic_vector; hw_rev : integer; gal_rev : std_logic_vector) return std_logic_vector is
	variable rev_reg : std_logic_vector(31 downto 0) := (others => L);
	begin
		rev_reg(31 downto 28) := CONV_STD_LOGIC_VECTOR(target, 4);
		rev_reg(27 downto 24) := CONV_STD_LOGIC_VECTOR(build_nr, 4);
		rev_reg(23 downto 16) := flags(7 downto 0);
		rev_reg(15 downto 12) := CONV_STD_LOGIC_VECTOR(hw_rev, 4);
		rev_reg(11 downto 0) := gal_rev(11 downto 0);
		return rev_reg;
	end pkg_rev_reg;
	
	-- confusing name crossbits: conversion of TO <= DOWNTO or DOWNTO <= TO. unusable for DOWNTO <= DOWNTO
	function crossbits(X : std_logic_vector) return std_logic_vector is
	variable ret_dt : std_logic_vector(X'length-1 downto 0) := (others => L);
	variable ret_t : std_logic_vector(0 to X'length-1) := (others => L);
	begin
		for i in 0 to X'length-1 loop
			ret_dt(i) := X(X'high-i);
			ret_t(i) := X(X'high-i);
		end loop;
		if X'high=X'left then	-- downto2to
			return ret_t;
		else					-- to2downto
			return ret_dt;
		end if;
	end crossbits;
	
	function vector_or(inputs : std_logic_vector) return std_logic is
	constant floatvalue : std_logic := '0';
	begin
	if inputs'Length = 0 then
		return floatvalue;
	else
		for i in inputs'Range loop
			if inputs(i) = '1' then
				return '1';
			end if;
		end loop ;
		return '0';
	end if;
	end;
	
	function max(L, R: integer) return integer is
	begin
	if L > R then
		return L;
	else
		return R;
	end if;
	end;
	
	function min(L, R: integer) return integer is
	begin
	if L < R then
		return L;
	else
		return R;
	end if;
	end;
	
	-----------------------------------------------------------------------
	-- With the help of this function we always have the correct port width
	-----------------------------------------------------------------------
	function Return_Upper(Count: natural) return natural is
		constant Result: natural := ((ABS(Count - 1) + Count - 1)/2);
	begin
		return Result;
	end Return_Upper;
	---------------------------------------------------------------------------
	-- With the help of this function we always have the correct port width END
	---------------------------------------------------------------------------
	
	----------------------------------------------------------------------------
	-- calculate a crc with one bit input
	----------------------------------------------------------------------------
	-- implementation:                   x^: 43210
	--	  Polynomial = x^5 + x^4 + x^2 + 1 = 10101
	--
	--	      x^4         x^3     x^2         x^1     x^0    
	--	     +---+       +---+   +---+       +---+   +---+     
	--	+--<-|Q D|<-XOR<-|Q D|<--|Q D|<-XOR<-|Q D|<--|Q D|<-+-<-XOR<--input
	--	|    |   |   ^   |   |   |   |   ^   |   |   |   |  |    ^
	--	|    +---+   |   +---+   +---+   |   +---+   +---+  |    |
	--	|            +-------------------+------------------+    |
	--	+--------------------------------------------------------+
	--
	--	input: H / L
	--	last_crc_val: register
	--								  x^: 76543210
	--	crc_poly: x^8 + x^5 + x^4 + 1 -> "00110001" (the highes x^8)
	--				crc_poly(crc_poly'low) is ignored and always H!!!!
	--
	--  for choos a crc, have a look to: 
	--  http://users.ece.cmu.edu/~koopman/crc/index.html
	--
	--	there existng differnt ways of the poly notation, different ways of bit 
	--	endanness and/or inversion :) 
	--  
	--  there are also different types of sr/xor implementation... 
	--	e.g. without first xor. if you shift in a L for 5 clocks (5 FFs), the 
	--	result is the same... x^5 + x^4 + x^2 + 1
	--	      x^4         x^3     x^2         x^1     x^0    
	--	     +---+       +---+   +---+       +---+   +---+     
	--	+--<-|Q D|<-XOR<-|Q D|<--|Q D|<-XOR<-|Q D|<--|Q D|<-+---input
	--	|    +---+   ^   +---+   +---+   ^   +---+   +---+  |    
	--	+------------+-------------------+------------------+  
	--
	----------------------------------------------------------------------------
	function crc_gen(input : std_logic; last_crc_val : std_logic_vector; crc_poly : std_logic_vector) return std_logic_vector is
	variable crc : std_logic_vector(last_crc_val'range);
	variable feedback : std_logic;
	begin
		assert last_crc_val'left=crc_poly'left
		report "crc_gen: wrong inputs vectors (size or endianness)!" severity error;
		feedback := last_crc_val(last_crc_val'high) xor input;
		crc(crc'low) := feedback;
		for i in last_crc_val'low+1 to last_crc_val'high loop
			if (crc_poly(i)=H) then
				crc(i) := last_crc_val(i-1) xor feedback;
			else
				crc(i) := last_crc_val(i-1);
			end if;
		end loop;
		return crc;
	end crc_gen;
	
	----------------------------------------------------------------------------
	-- calculate a crc with vector input from high to low in one step
	--
	--	input: std_logic_vector
	--	last_crc_val: register
	--	crc_poly: x^8 + x^5 + x^4 + 1 -> "00110001"
	----------------------------------------------------------------------------
	function crc_gen(input : std_logic_vector; last_crc_val : std_logic_vector; crc_poly : std_logic_vector) return std_logic_vector is
	variable crc : std_logic_vector(last_crc_val'range) := last_crc_val;
	begin
		for i in input'high downto input'low loop
			crc := crc_gen(input(i), crc, crc_poly);
		end loop;
		return crc;
	end crc_gen;
	
	----------------------------------------------------------------------------
	function get_fpga_type_str(input : integer) return string is
	begin
		case input is
		when DF_PKG_FPGA_TYPE_V2P =>
			return "virtex2p";
		when DF_PKG_FPGA_TYPE_V4 =>
			return "virtex4";
		when others =>
			return "";
		end case;
	end get_fpga_type_str;
	
	----------------------------------------------------------------------------
	-- return a decimal number as std_locig_vector (pimary used for svn rev. no)
	-- "1234" return conv_std_logic_vector(1234, lng)
	-- "xxx1 234abcd 5yyy" return conv_std_logic_vector(12345, lng)
	----------------------------------------------------------------------------
	function get_dec_from_string(str : string; lng : positive) return std_logic_vector is
	variable ret : std_logic_vector(lng-1 downto 0) := (others => L);
	variable val : integer := 0;
	variable dec : integer := 0;
	begin
		for i in 1 to str'length loop
			case str(i) is
			when '0' =>
				val := val*10+0;
			when '1' =>
				val := val*10+1;
			when '2' =>
				val := val*10+2;
			when '3' =>
				val := val*10+3;
			when '4' =>
				val := val*10+4;
			when '5' =>
				val := val*10+5;
			when '6' =>
				val := val*10+6;
			when '7' =>
				val := val*10+7;
			when '8' =>
				val := val*10+8;
			when '9' =>
				val := val*10+9;
			when others =>
				null;
			end case;
		end loop;
		ret := conv_std_logic_vector(val, ret'length);
		return ret;
	end function get_dec_from_string;
	
	----------------------------------------------------------------------------
	-- return a decimal number as std_locig_vector from hex str
	-- "12ac" return conv_std_logic_vector(4780, lng)
	-- "xxx1 234abcd 5yyy" return conv_std_logic_vector(dec(0x1234abcd5), lng)
	----------------------------------------------------------------------------
	function get_hex_from_string(str : string; lng : positive; abort : character) return std_logic_vector is
	variable ret : unsigned(lng-1 downto 0) := (others => L);
	begin
		for i in 1 to str'length-1 loop
			if abort/='0' and abort=str(i) then
				exit;
			end if;
			case str(i) is
			when '0' =>
				ret := SHL(ret, "100")+0;
			when '1' =>
				ret := SHL(ret, "100")+1;
			when '2' =>
				ret := SHL(ret, "100")+2;
			when '3' =>
				ret := SHL(ret, "100")+3;
			when '4' =>
				ret := SHL(ret, "100")+4;
			when '5' =>
				ret := SHL(ret, "100")+5;
			when '6' =>
				ret := SHL(ret, "100")+6;
			when '7' =>
				ret := SHL(ret, "100")+7;
			when '8' =>
				ret := SHL(ret, "100")+8;
			when '9' =>
				ret := SHL(ret, "100")+9;
			when 'A' =>
				ret := SHL(ret, "100")+10;
			when 'B' =>
				ret := SHL(ret, "100")+11;
			when 'C' =>
				ret := SHL(ret, "100")+12;
			when 'D' =>
				ret := SHL(ret, "100")+13;
			when 'E' =>
				ret := SHL(ret, "100")+14;
			when 'F' =>
				ret := SHL(ret, "100")+15;
			when 'a' =>
				ret := SHL(ret, "100")+10;
			when 'b' =>
				ret := SHL(ret, "100")+11;
			when 'c' =>
				ret := SHL(ret, "100")+12;
			when 'd' =>
				ret := SHL(ret, "100")+13;
			when 'e' =>
				ret := SHL(ret, "100")+14;
			when 'f' =>
				ret := SHL(ret, "100")+15;
			when others =>
				null;
			end case;
		end loop;
		--ret := conv_std_logic_vector(val, ret'length);
		return std_logic_vector(ret);
	end function get_hex_from_string;
	
	function get_hex_from_string(str : string; lng : positive) return std_logic_vector is
	begin
		return get_hex_from_string(str, lng, '0');
	end function get_hex_from_string;
	----------------------------------------------------------------------------
	-- retrun the largest value for: a/returnvalue=<b
	----------------------------------------------------------------------------
	function get_uprounded_div(a,b : positive) return positive is 
	variable v : positive;
	begin
		v := a/b;
		if (v*b=a) then
			return v;
		else 
			return v+1;
		end if;
	end function;
	
	
	-- converts an integer into a character
	-- for 0 to 9 the obvious mapping is used, higher
	-- values are mapped to the characters A-Z
	-- (this is usefull for systems with base > 10)
	-- (adapted from Steve Vogwell's posting in comp.lang.vhdl)

	function chr(int: integer) return character is
	variable c: character;
	begin
		case int is
			when  0 => c := '0';
			when  1 => c := '1';
			when  2 => c := '2';
			when  3 => c := '3';
			when  4 => c := '4';
			when  5 => c := '5';
			when  6 => c := '6';
			when  7 => c := '7';
			when  8 => c := '8';
			when  9 => c := '9';
			when 10 => c := 'A';
			when 11 => c := 'B';
			when 12 => c := 'C';
			when 13 => c := 'D';
			when 14 => c := 'E';
			when 15 => c := 'F';
			when 16 => c := 'G';
			when 17 => c := 'H';
			when 18 => c := 'I';
			when 19 => c := 'J';
			when 20 => c := 'K';
			when 21 => c := 'L';
			when 22 => c := 'M';
			when 23 => c := 'N';
			when 24 => c := 'O';
			when 25 => c := 'P';
			when 26 => c := 'Q';
			when 27 => c := 'R';
			when 28 => c := 'S';
			when 29 => c := 'T';
			when 30 => c := 'U';
			when 31 => c := 'V';
			when 32 => c := 'W';
			when 33 => c := 'X';
			when 34 => c := 'Y';
			when 35 => c := 'Z';
			when others => c := '?';
		end case;
		return c;
	end chr;
	
	-- convert integer to string using specified base
	-- (adapted from Steve Vogwell's posting in comp.lang.vhdl)

	function str(int: integer; base: integer) return string is
	variable temp:      string(1 to 10);
	variable num:       integer;
	variable abs_int:   integer;
	variable len:       integer := 1;
	variable power:     integer := 1;

	begin

		-- bug fix for negative numbers
		abs_int := abs(int);
		
		num     := abs_int;
		
		while num >= base loop                     -- Determine how many
			len := len + 1;                          -- characters required
			num := num / base;                       -- to represent the
		end loop ;                                 -- number.
		
		for i in len downto 1 loop                 -- Convert the number to
			temp(i) := chr(abs_int/power mod base);-- a string starting
			power := power * base;                 -- with the right hand
		end loop ;                                 -- side.
	
		-- return result and add sign if required
		if int < 0 then 
			return '-'& temp(1 to len);
		else
			return temp(1 to len);
		end if;

	end str;

	-- convert integer to string, using base 10
	function str(int: integer) return string is
	
	begin
	
		return str(int, 10) ;
	
	end str;

	procedure dbg_int_out(int:in integer) is
	begin
		assert 1 < 0
		report str(int)
		severity NOTE;
	end dbg_int_out;
	
	procedure dbg_int_out(name:in string; int:in integer) is
	begin
		assert 1 < 0
		report name & ": " & str(int)
		severity NOTE;
	end dbg_int_out;
	
	function pkg_p2020_speed(speed: integer) return std_logic_vector is
	begin
		if (speed=DF_PKG_P2020_1200) then
			return "0010"; -- pll ccb 6:1 , sys and ddr clk 100Mhz: core 1.2G, ccb 600mhz, ddr 400mhz, lb 150mhz
		elsif (speed=DF_PKG_P2020_1000) then
			return "1010"; -- pll ccb 6:1 , sys and ddr clk 83.3Mhz: core 1.0G, ccb 500mhz, ddr 333mhz, lb 125mhz
		else
			assert 1<0
			report "unsupported p2020 speed" severity error;
			return "0000";
		end if;
	end pkg_p2020_speed;
	
	function getMultiBuf (NoBufferPair : integer) return std_logic is
	variable res : std_logic := L;
	begin
		if (NoBufferPair>1) then
			res := H;
		end if;
		return res;
	end function getMultiBuf;
	
end INDEL_pkg;

--------------------------------------------------------------------------------