---------------------------------------------------------------------------
--
--	GinLink LED Flasher
--
---------------------------------------------------------------------------
--
--  project     : Ethernet Phy MII 
--  programmer  : F:Baschung, INDEL AG
--  date        : 10.07.2006
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose              
--		- Flash timing for all LEDs, 800ms, 1/4 on, 3/4 off
--		so the LED can flah with
--		
--  	- As GinMaster: - generate a free running flash-timing _-___-___ 
--						- send this flash-bit in GinLink header to all slaves 
--		- As GinSlave:	- generate a free running flash-timing _-___-___ 
--						- synch this with GinMaster if GinLink UP
--
---------------------------------------------------------------------------
--	18.12.2008-le : - add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 4030                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-09-06 15:04:39 +0200 (Di., 06 Sep 2016)                         $
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
--	09.10.2008-FB	erste Version
--	20.12.2008-FB	alle einzel 1/4 signale dazu
--------------------------------------------------------------------------------

entity Gin_LED_Flasher is 
	port (
		i_Q62_5			: IN  std_logic;
 		i_SynchFlash	: IN  std_logic := '0';

		o_Flash_1000	: OUT std_logic := '0';
		o_Flash_0100	: OUT std_logic := '0';
		o_Flash_0010	: OUT std_logic := '0';
		o_Flash_0001	: OUT std_logic := '0';

		o_Flash_1100	: OUT std_logic := '0';
		o_Flash_1010	: OUT std_logic := '0';
		o_Q200ms		: OUT std_logic := '0'
    );
end;    

architecture impl of Gin_LED_Flasher is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
	signal	Prescaler	: std_logic_vector(24 downto 0) := '0' & x"000000" ;
	signal	Q200ms		: std_logic := '0';

--------------------------------------------------------------------------------
	signal	FlashQuad	: std_logic_vector(3 downto 0) := "0000";
	signal	LastSynch	: std_logic := L;
	signal	Reset		: std_logic := L;
	
--------------------------------------------------------------------------------
--	Configuration
-------------------------------------------------------------------------------- 
--	62.5MHz == 16ns * 12'500'000 = 200ms 

	constant Cfg_200ms : integer := 12500000-1;
	constant zero : integer := 0;

--------------------------------------------------------------------------------	
begin -- of architecture GE_MIISeq    
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
	o_Flash_1000 <= FlashQuad(0); 
	o_Flash_0100 <= FlashQuad(1); 
	o_Flash_0010 <= FlashQuad(2); 
	o_Flash_0001 <= FlashQuad(3); 

	o_Flash_1100 <= FlashQuad(0) or FlashQuad(1); 
	o_Flash_1010 <= FlashQuad(0) or FlashQuad(2); 
	
	o_Q200ms <= Q200ms;

--------------------------------------------------------------------------------
--	synch puls
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
			Reset <= L;
    	
    	    if (LastSynch /= i_SynchFlash) then
    	    	LastSynch <= i_SynchFlash;
				if (i_SynchFlash = H) then
					Reset <= H;
				end if;
    	    end if; 

		end if;	
    end process;

--------------------------------------------------------------------------------
--	Prescaler 62.5MHz == 16ns * 12'500'000 = 200ms 
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
   	    	Q200ms <= L;
   	    	
    	    if (Reset = H) then 
				Prescaler <= (others =>'0');
    	    else
	    	    if (Prescaler >= Cfg_200ms) then
	    	    	Q200ms <= H;
					Prescaler <= (others =>'0');
	    	    else
					Prescaler <= Prescaler + 1;
				end if;	
    	    end if; 
    	    
		end if;	
    end process;

--------------------------------------------------------------------------------
--	LED States
--------------------------------------------------------------------------------
--		_-___-___-
--		_--__--__-
--		_-_-_-_-_-

	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
			if (Reset = H) then
				-- synch it with GinMasters Blink-Bit    	    
				FlashQuad <= "1000";
			else
				if (Q200ms=H) then	
		    	    case (FlashQuad) is 
		    	    when "0000"
		    	       | "0001" =>
			    	    FlashQuad 	<= "1000";

		    	    when "1000" =>
			    	    FlashQuad 	<= "0100";
			    	    
		    	    when "0100" =>
			    	    FlashQuad 	<= "0010";
					
		    	    when "0010" =>
			    	    FlashQuad 	<= "0001";
					
					
					when others => null; -------------------------------------------
					end case;
				end if;
			end if;
		end if;	
    end process;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
