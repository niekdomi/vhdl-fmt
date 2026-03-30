--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity SINC3 is 
	generic (
    	C_BIT_RES	: integer := 10;
    	C_CLK_EN	: integer := 1
    );
	port(
		clk, RESN, MOUT, MCLK, CNR : in std_logic;
		CN5 : out std_logic_vector(C_BIT_RES-1 downto 0));
end SINC3;

architecture RTL of SINC3 is

signal DN0, DN1, DN3, DN5 : std_logic_vector(C_BIT_RES-1 downto 0):=(others => '0');
signal CN1, CN2, CN3, CN4 : std_logic_vector(C_BIT_RES-1 downto 0):=(others => '0');
signal DELTA1 : std_logic_vector(C_BIT_RES-1 downto 0):=(others => '0');

begin

	process(clk, RESn)
	begin
		if RESn = '1' then
			DELTA1 <= (others => '0');
		--elsif MCLK'event and MCLK = '1' then 
		elsif rising_edge(clk) then
			if MCLK = '1' or C_CLK_EN=0 then
				if MOUT = '1' then
					DELTA1 <= DELTA1 + 1;
				end if; 
			end if;
		end if;
	end process; 
	
	process(RESN, clk)
	begin
		if RESN = '1' then
			CN1 <= (others => '0');
			CN2 <= (others => '0'); 
		--elsif MCLK'event and MCLK = '1' then    
		elsif rising_edge(clk) then
			if MCLK = '1' or C_CLK_EN=0 then
				CN1 <= CN1 + DELTA1;
				CN2 <= CN2 + CN1; 
			end if;
		end if;
	end process;   
	
	process(RESN, clk)
	begin
		if RESN = '1' then
			DN0 <= (others => '0');
			DN1 <= (others => '0');
			DN3 <= (others => '0');
			DN5 <= (others => '0');
		--elsif CNR'event and CNR = '1' then 
		elsif rising_edge(clk) then  
			if CNR = '1' and (MCLK = '1' or C_CLK_EN=0) then
				DN0 <= CN2;
				DN1 <= DN0;
				DN3 <= CN3;
				DN5 <= CN4;      
			end if;
		end if;
	end process;
	
	CN3 <= DN0 - DN1;
	CN4 <= CN3 - DN3;
	CN5 <= CN4 - DN5;
end RTL;