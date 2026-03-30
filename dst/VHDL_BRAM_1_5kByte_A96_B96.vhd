--------------------------------------------------------------------------------
--
--  BRAM_1_5kByte_A96_B96.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : C. Leuthold, INDEL AG
--  date        : 27.10.2017-FB
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	27.10.2017-FB	first 96Bit version (code from VHDL_BRAM_4kByte_A32_B32) 
--------------------------------------------------------------------------------
--$Rev:: 4637                   $
--$Author:: fbaschung                $
--$Date:: 2017-11-08 14:57:34 +0100 (Mi., 08 Nov 2017)        $
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

ENTITY BRAM_1_5kByte_A96_B96 is 

	generic (
		BRAM_Init		: tSLV_Nx96(0 to 127) := (others => (others => '0'))
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic 					:= '0';
		i_BRAM_EN_A   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_A  	: IN  std_logic_vector(11 downto 0) := (others => '0');
		i_BRAM_Addr_A 	: IN  std_logic_vector( 6 downto 0) := (others => '0');
		i_BRAM_Dout_A 	: IN  std_logic_vector(95 downto 0) := (others => '0');
		o_BRAM_Din_A  	: OUT std_logic_vector(95 downto 0) := (others => '0');
		
		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector(11 downto 0) := (others => '0');
		i_BRAM_Addr_B 	: IN  std_logic_vector( 6 downto 0) := (others => '0');
		i_BRAM_Dout_B 	: IN  std_logic_vector(95 downto 0) := (others => '0');
		o_BRAM_Din_B  	: OUT std_logic_vector(95 downto 0) := (others => '0')
	);
END;

ARCHITECTURE impl OF BRAM_1_5kByte_A96_B96 IS

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------
	shared variable RAM : tSLV_Nx96(0 to 127) := BRAM_Init;
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
				
				for i in 0 to 11 loop
				
					if i_BRAM_WEN_A(i) = '1' then
						RAM(conv_integer(i_BRAM_Addr_A))(i*8+7 downto i*8+0) := i_BRAM_Dout_A(i*8+7 downto i*8+0);
					end if;
					
				end loop;

			end if;
		end if;
	end process;

	process (i_BRAM_Clk_B)
	begin
		if rising_edge(i_BRAM_Clk_B) then
			if i_BRAM_EN_B = '1' then
				o_BRAM_Din_B <= RAM(conv_integer(i_BRAM_Addr_B));
				
				for i in 0 to 11 loop
				
					if i_BRAM_WEN_B(i) = '1' then
						RAM(conv_integer(i_BRAM_Addr_B))(i*8+7 downto i*8+0) := i_BRAM_Dout_B(i*8+7 downto i*8+0);
					end if;
					
				end loop;
				
			end if;
		end if;
	end process;


END ARCHITECTURE impl;
