--------------------------------------------------------------------------------
--
--  BRAM_4kByte_A64_B32.vhd
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

ENTITY BRAM_4kByte_A64_B32 is 
    --scheisse!
	generic (
		BRAM_Init		: tSLV_Nx32(0 to 1023) := (others => (others => '0'));
		g_OUTREG_A		: in integer range 0 to 1 := 0;
		g_INIT_FILE		: string := ""
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic 					:= '0';
		i_BRAM_EN_A   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_A  	: IN  std_logic_vector( 7 downto 0) := "00000000";
		i_BRAM_Addr_A 	: IN  std_logic_vector( 8 downto 0) := "000000000";
		i_BRAM_Dout_A 	: IN  std_logic_vector(63 downto 0) := x"0000000000000000";
		o_BRAM_Din_A  	: OUT std_logic_vector(63 downto 0) := x"0000000000000000";
		
		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector( 9 downto 0) := "0000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
END;

ARCHITECTURE impl OF BRAM_4kByte_A64_B32 IS

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------

	-- Declare the RAM signal.
	shared variable RAM : tSLV_Nx32(0 to 1023) := BRAM_Init;
	
	
	signal BRAM_Din_A : std_logic_vector(63 downto 0);
	signal BRAM_Dout_A : std_logic_vector(63 downto 0);
	signal BRAM_WEN_A : std_logic_vector(7 downto 0);
	
	
BEGIN
	
--------------------------------------------------------------------------------
-- Power assignments

--------------------------------------------------------------------------------
-- Lower-level assignments
--------------------------------------------------------------------------------
	BRAM_Dout_A	   <= i_BRAM_Dout_A;--(31 downto 16)
    				--& i_BRAM_Dout_A(63 downto 48)
    				--& i_BRAM_Dout_A(15 downto  0)                 
    				--& i_BRAM_Dout_A(47 downto 32);

    o_BRAM_Din_A   <= BRAM_Din_A;--(47 downto 32)
    				--& BRAM_Din_A(15 downto  0)
    				--& BRAM_Din_A(63 downto 48)
    				--& BRAM_Din_A(31 downto 16);

	BRAM_WEN_A     <= i_BRAM_WEN_A;--(3 downto 2)
					--& i_BRAM_WEN_A(7 downto 6)
					--& i_BRAM_WEN_A(1 downto 0)
					--& i_BRAM_WEN_A(5 downto 4);
	
	
	
	
	
	process (i_BRAM_Clk_A)
	variable Addr : integer := 0;
	begin
		if rising_edge(i_BRAM_Clk_A) then
			Addr := 2*conv_integer(i_BRAM_Addr_A);
			if i_BRAM_EN_A = '1' then
				BRAM_Din_A(31 downto 0) <= RAM(Addr+1);
				BRAM_Din_A(63 downto 32) <= RAM(Addr);
				for i in 0 to 3 loop
					if BRAM_WEN_A(i) = '1' then
						RAM(Addr+1)(7+i*8 downto i*8) := BRAM_Dout_A(7+i*8 downto i*8);
					end if;
					if BRAM_WEN_A(4+i) = '1' then
						RAM(Addr)(7+i*8 downto i*8) := BRAM_Dout_A(7+i*8+32 downto i*8+32);
					end if;
				end loop;
			end if;
		end if;
	end process;

	process (i_BRAM_Clk_B)
	variable Addr : integer := 0;
	begin
		if rising_edge(i_BRAM_Clk_B) then
			Addr := conv_integer(i_BRAM_Addr_B);
			if i_BRAM_EN_B = '1' then
				o_BRAM_Din_B <= RAM(Addr);
				for i in 0 to 3 loop
					if i_BRAM_WEN_B(i) = '1' then
						RAM(Addr)(7+i*8 downto i*8) := i_BRAM_Dout_B(7+i*8 downto i*8);
					end if;
				end loop;
			end if;
		end if;
	end process;


END ARCHITECTURE impl;
