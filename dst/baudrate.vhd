--------------------------------------------------------------------------------
--  baudrate.vhd
--------------------------------------------------------------------------------
--
--  project     : ppc-module
--  programmer  : C. LEuthold, INDEL AG
--  date        : 17.11.2003
--  version     : 1.00
--  language    : VHDL 
--  system      : ISP/EDK 6.1
--
--  purpose
--    
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 	Rev. 1.00	:	17.11.2003-le  :  
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.ALL;

entity Baud_Rate is
  port (
    Clk          	: in  std_logic;
    EN_16x_Baud  	: out std_logic;
    i_ratio			: in std_logic_vector(15 downto 0)   --ClkFreq/(16*baudrate)
    );

end entity Baud_Rate;

architecture VHDL_RTL of Baud_Rate is

	signal Count : std_logic_vector(15 downto 0);

begin  -- architecture VHDL_RTL
	
	Counter : process (Clk) is
  	begin  -- process Counter
    	if Clk'event and Clk = '1' then     -- rising clock edge
      		if (Count = 0) then
        		Count       <= i_ratio-1;
        		EN_16x_Baud <= '1';
      		else
       			Count       <= Count - 1;
        		EN_16x_Baud <= '0';
      		end if;
    	end if;
  	end process Counter;

end architecture VHDL_RTL;

