--------------------------------------------------------------------------------
--
--	GinLink WathDog
--
--------------------------------------------------------------------------------
--
--  project     : Ethernet Phy MII 
--  programmer  : F:Baschung, INDEL AG
--  date        : 10.07.2006
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose              
--		- 1ms Wdog 	
--			(wdog-time is a little more, 1.048ms to get no jitter-errors)
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	17.10.2008-FB	erste Version
--	18.12.2008-le : - add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 823                                                                   $
--$Author:: leuthold                                                           $
--$Date:: 2008-12-18 15:37:50 +0100 (Do., 18 Dez 2008)                         $
--------------------------------------------------------------------------------
                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity Gin_WatchDog_1ms is 
	port (
		i_Q62_5			: IN  std_logic;
 		i_Probe			: IN  std_logic := '0';
		o_Wdog			: OUT std_logic := '0'
    );
end;    

architecture impl of Gin_WatchDog_1ms is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
	signal	Timer		: std_logic_vector(15 downto 0) := x"0000" ;
	signal	Wdog		: std_logic := L;
	signal	LastSynch	: std_logic := L;
	signal	Preset		: std_logic := L;
	
--------------------------------------------------------------------------------
--	Configuration
-------------------------------------------------------------------------------- 
--	62.5MHz == 16ns * 65535 = 1.048ms 
	constant Cfg_1ms : std_logic_vector(15 downto 0) := x"FFFF" ;

--------------------------------------------------------------------------------	
begin -- of architecture GE_MIISeq    
--------------------------------------------------------------------------------
	o_Wdog <= Wdog;
	
--------------------------------------------------------------------------------
--	probe _+- puls
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 

			Preset <= L;
    	
    	    if (i_Probe = LastSynch) then
			else
    	    	LastSynch <= i_Probe;
--				if (i_Probe = H) then
					Preset <= H;
--				end if;
    	    end if; 

		end if;	
    end process;

--------------------------------------------------------------------------------
--	
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
	   		Wdog <= L;
	   		
    	    if (Preset = H) then
    	    	Wdog <= H;
				Timer <= Cfg_1ms;
    	    else 
    	     	if (Timer > 0) then
    	    		Wdog <= H;
					Timer <= Timer - 1;
				end if;	
    	    end if; 
    	    
		end if;	
    end process;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
