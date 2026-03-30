--------------------------------------------------------------------------------
--
--	GinLink WathDog 800ms
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
--		- 800ms Wdog 
--		- synched with LED-Flasher 	
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	17.10.2008-FB	erste Version
--	18.12.2008-le : - add svn keywords
--	18.05.2011-le : - avoid synthesis warnings:
--						remove others clause
--------------------------------------------------------------------------------
--$Rev:: 1945                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-05-18 16:50:45 +0200 (Mi., 18 Mai 2011)                         $
--------------------------------------------------------------------------------
                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
--	17.10.2008-FB	erste Version
--------------------------------------------------------------------------------

entity Gin_WatchDog_800ms is 
	port (
		i_Q62_5			: IN  std_logic;
 		i_Probe			: IN  std_logic := '0';
 		i_SynchFlash	: IN  std_logic := '0';
		o_Wdog			: OUT std_logic := '0'
    );
end;    

architecture impl of Gin_WatchDog_800ms is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
	signal	Wdog		: std_logic := L;
	signal	LastLed		: std_logic := L;
	signal	LedSet		: std_logic := L;
	
    type tGin_WD800_seq is (
    	s0,s1,s2,s3,s4,s5
    );

	signal	Gin_WD800_seq	: tGin_WD800_seq 	:= s0;

--------------------------------------------------------------------------------
--	Configuration
-------------------------------------------------------------------------------- 
--	62.5MHz == 16ns * 65535 = 1.048ms 
	constant Cfg_1ms : std_logic_vector(15 downto 0) := x"FFFF" ;

--------------------------------------------------------------------------------	
begin -- of architecture GE_MIISeq    
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	LED synch pulse
--------------------------------------------------------------------------------
--	Led 	__+----__ 
--	LedSet  __-______
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 

			LedSet <= L;
    	
    	    if (i_SynchFlash = LastLed) then
   	     else
    	    	LastLed <= i_SynchFlash;
				if (i_SynchFlash = H) then
					LedSet <= H;
				end if;
    	    end if; 

		end if;	
    end process;

--------------------------------------------------------------------------------
--	find single_off, single_on, multiply_off_on	
--------------------------------------------------------------------------------
--			   single                  single      multi  	
--		   	     On                     Off         On
-- led		__--____--____--____--____--____--____--____--____--____--____
-- probe	_____-___________------------_---------_-_-_------
-- State	00000111233333000111222222222344011111234555222222
-- Wdog		________------______------------______------------

	o_Wdog <= Wdog;
	
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
	   		case (Gin_WD800_seq) is 

			when s0 =>	--- OFF, wait for at least a single on -----------------
				Wdog <= L;
				if (i_Probe = H) then
					Gin_WD800_seq <= s1;
                end if;

			when s1 =>	---	OFF, got a on, synch with LED  ---------------------
				Wdog <= L;
				if (LedSet = H) then 
					Gin_WD800_seq <= s2;
                end if;

			when s2 =>	---	ON, test if single off -----------------------------
				Wdog <= H;
				if (i_Probe = L) then
					Gin_WD800_seq <= s3;
                end if;

			when s3 =>	--- ON, got a off, wait for next on	--------------------
				Wdog <= H;
				if (i_Probe = H) then
					Gin_WD800_seq <= s4;
				else	
					if (LedSet = H) then 
						Gin_WD800_seq <= s0;
	                end if;
                end if;

			when s4 =>	--- ON, got a on, single off or multi off/on -----------
				Wdog <= H;
				if (i_Probe = L) then
					Gin_WD800_seq <= s5;
				else	
					if (LedSet = H) then 
						Gin_WD800_seq <= s0;
	                end if;
                end if;

			when s5 =>	---	multiply off/on ------------------------------------
				Wdog <= H;
				if (LedSet = H) then 
					Gin_WD800_seq <= s2;
                end if;


			when others => null;
			end case;   
			
		end if;	
    end process;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
