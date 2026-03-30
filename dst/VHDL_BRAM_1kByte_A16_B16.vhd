--------------------------------------------------------------------------------
--
--  BRAM_1kByte_A16_B16.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F. Baschung, INDEL AG
--  date        : 20.06.2011
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
--	20.06.2011-FB	A16_B16 von Leutholds A32_B32 abgeleitet
--------------------------------------------------------------------------------
--$Rev:: 1973                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-06-16 08:57:47 +0200 (Do, 16 Jun 2011)                          $
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

ENTITY BRAM_1kByte_A16_B16 is

	generic (
		BRAM_Init		: tSLV_Nx16(0 to 511) := (others => (others => '0'))
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic 					:= '0';
		i_BRAM_EN_A   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_A  	: IN  std_logic_vector( 1 downto 0) := (others => '0');
		i_BRAM_Addr_A 	: IN  std_logic_vector( 8 downto 0) := (others => '0');
		i_BRAM_Dout_A 	: IN  std_logic_vector(15 downto 0) := (others => '0');
		o_BRAM_Din_A  	: OUT std_logic_vector(15 downto 0) := (others => '0');

		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 1 downto 0) := (others => '0');
		i_BRAM_Addr_B 	: IN  std_logic_vector( 8 downto 0) := (others => '0');
		i_BRAM_Dout_B 	: IN  std_logic_vector(15 downto 0) := (others => '0');
		o_BRAM_Din_B  	: OUT std_logic_vector(15 downto 0) := (others => '0')
	);
END;

ARCHITECTURE impl OF BRAM_1kByte_A16_B16 IS

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------
	shared variable RAM : tSLV_Nx16(0 to 511) := BRAM_Init;

BEGIN

--------------------------------------------------------------------------------
-- Power assignments

--------------------------------------------------------------------------------
-- Lower-level assignments
--------------------------------------------------------------------------------

	process (i_BRAM_Clk_A)
	begin
		if rising_edge(i_BRAM_Clk_A) then
			if i_BRAM_EN_A = '1' then
				o_BRAM_Din_A <= RAM(conv_integer(i_BRAM_Addr_A));
				if i_BRAM_WEN_A(0) = '1' then
					RAM(conv_integer(i_BRAM_Addr_A))( 7 downto 0) := i_BRAM_Dout_A( 7 downto 0);
				end if;
				if i_BRAM_WEN_A(1) = '1' then
					RAM(conv_integer(i_BRAM_Addr_A))(15 downto 8) := i_BRAM_Dout_A(15 downto 8);
				end if;
			end if;
		end if;
	end process;

	process (i_BRAM_Clk_B)
	begin
		if rising_edge(i_BRAM_Clk_B) then
			if i_BRAM_EN_B = '1' then
				o_BRAM_Din_B <= RAM(conv_integer(i_BRAM_Addr_B));
				if i_BRAM_WEN_B(0) = '1' then
					RAM(conv_integer(i_BRAM_Addr_B))( 7 downto 0) := i_BRAM_Dout_B( 7 downto 0);
				end if;
				if i_BRAM_WEN_B(1) = '1' then
					RAM(conv_integer(i_BRAM_Addr_B))(15 downto 8) := i_BRAM_Dout_B(15 downto 8);
				end if;
			end if;
		end if;
	end process;


END ARCHITECTURE impl;
