--------------------------------------------------------------------------------
--
--  BRAM_8kByte_A32_B32.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : C. Leuthold, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	05.02.2008-le	add svn keywords
--	13.02.2012-le	change to read first
--------------------------------------------------------------------------------
--$Rev:: 3142                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-12-13 11:03:09 +0100 (Fr, 13 Dez 2013)                          $
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

ENTITY BRAM_16kByte_A32_B32 is

	generic (
		BRAM_Init		: tSLV_Nx32(0 to 4095) := (others => (others => '0'));
		g_OUTREG_A		: in integer range 0 to 1 := 0
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic 					:= '0';
		i_BRAM_EN_A   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_A  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_A 	: IN  std_logic_vector(11 downto 0) := "000000000000";
		i_BRAM_Dout_A 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_A  	: OUT std_logic_vector(31 downto 0) := x"00000000";

		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector(11 downto 0) := "000000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
END;

ARCHITECTURE impl OF BRAM_16kByte_A32_B32 IS

	

BEGIN



END ARCHITECTURE impl;
