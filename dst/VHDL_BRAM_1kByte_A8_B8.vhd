--------------------------------------------------------------------------------
--
--  BRAM_1kByte_A8_B8.vhd
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

--------------------------------------------------------------------------------
ENTITY BRAM_1kByte_A8_B8 is

	generic (
		BRAM_Init		: tSLV_Nx8(0 to 1023) := (others => (others => L))
	);
	port (
		i_BRAM_Clk_A  	: in  std_logic 					:= L;
		i_BRAM_EN_A   	: in  std_logic 					:= H;
		i_BRAM_WEN_A  	: in  std_logic 					:= L;
		i_BRAM_Addr_A 	: in  std_logic_vector( 9 downto 0) := (others => L);
		i_BRAM_Dout_A 	: in  std_logic_vector( 7 downto 0) := (others => L);
		o_BRAM_Din_A  	: out std_logic_vector( 7 downto 0) := (others => L);

		i_BRAM_Clk_B  	: in  std_logic 					:= L;
		i_BRAM_EN_B   	: in  std_logic 					:= H;
		i_BRAM_WEN_B  	: in  std_logic 					:= L;
		i_BRAM_Addr_B 	: in  std_logic_vector( 9 downto 0) := (others => L);
		i_BRAM_Dout_B 	: in  std_logic_vector( 7 downto 0) := (others => L);
		o_BRAM_Din_B  	: out std_logic_vector( 7 downto 0) := (others => L)
	);
END;

-------------------------------------------------------------------------------
ARCHITECTURE impl OF BRAM_1kByte_A8_B8 IS
--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------
	shared variable RAM : tSLV_Nx8(0 to 1023) := BRAM_Init;

--------------------------------------------------------------------------------
BEGIN
--------------------------------------------------------------------------------

	process (i_BRAM_Clk_A)
	begin
		if rising_edge(i_BRAM_Clk_A) then
			if i_BRAM_EN_A = H then
				if i_BRAM_WEN_A = H then
					RAM(conv_integer(i_BRAM_Addr_A)) := i_BRAM_Dout_A;
				end if;
				o_BRAM_Din_A <= RAM(conv_integer(i_BRAM_Addr_A));
			end if;
		end if;
	end process;

	process (i_BRAM_Clk_B)
	begin
		if rising_edge(i_BRAM_Clk_B) then
			if i_BRAM_EN_B = H then
				if i_BRAM_WEN_B = H then
					RAM(conv_integer(i_BRAM_Addr_B)) := i_BRAM_Dout_B;
				end if;
				o_BRAM_Din_B <= RAM(conv_integer(i_BRAM_Addr_B));
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
END ARCHITECTURE impl;
--------------------------------------------------------------------------------
