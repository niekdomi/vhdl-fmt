--------------------------------------------------------------------------------
--
--  BRAM_4kByte_A32_B32.vhd
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
--	25.04.2018-le	add dummy generic "g_INIT_FILE"
--------------------------------------------------------------------------------
--$Rev:: 4867                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-25 16:57:30 +0200 (Mi., 25 Apr 2018)                         $
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

ENTITY BRAM_4kByte_A32_B32 is 

	generic (
		BRAM_Init		: tSLV_Nx32(0 to 1023) := (others => (others => '0'));
		g_INIT_FILE		: string := ""
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic 					:= '0';
		i_BRAM_EN_A   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_A  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_A 	: IN  std_logic_vector( 9 downto 0) := "0000000000";
		i_BRAM_Dout_A 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_A  	: OUT std_logic_vector(31 downto 0) := x"00000000";
		
		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector( 9 downto 0) := "0000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
END;

ARCHITECTURE impl OF BRAM_4kByte_A32_B32 IS

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------
	shared variable RAM : tSLV_Nx32(0 to 1023) := BRAM_Init;
	--signal RAM : tMEM := MEM;
	
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
					RAM(conv_integer(i_BRAM_Addr_A))(7 downto 0) := i_BRAM_Dout_A(7 downto 0);
				end if;
				if i_BRAM_WEN_A(1) = '1' then
					RAM(conv_integer(i_BRAM_Addr_A))(15 downto 8) := i_BRAM_Dout_A(15 downto 8);
				end if;
				if i_BRAM_WEN_A(2) = '1' then
					RAM(conv_integer(i_BRAM_Addr_A))(23 downto 16) := i_BRAM_Dout_A(23 downto 16);
				end if;
				if i_BRAM_WEN_A(3) = '1' then
					RAM(conv_integer(i_BRAM_Addr_A))(31 downto 24) := i_BRAM_Dout_A(31 downto 24);
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
					RAM(conv_integer(i_BRAM_Addr_B))(7 downto 0) := i_BRAM_Dout_B(7 downto 0);
				end if;
				if i_BRAM_WEN_B(1) = '1' then
					RAM(conv_integer(i_BRAM_Addr_B))(15 downto 8) := i_BRAM_Dout_B(15 downto 8);
				end if;
				if i_BRAM_WEN_B(2) = '1' then
					RAM(conv_integer(i_BRAM_Addr_B))(23 downto 16) := i_BRAM_Dout_B(23 downto 16);
				end if;
				if i_BRAM_WEN_B(3) = '1' then
					RAM(conv_integer(i_BRAM_Addr_B))(31 downto 24) := i_BRAM_Dout_B(31 downto 24);
				end if;
				
			end if;
		end if;
	end process;


END ARCHITECTURE impl;
