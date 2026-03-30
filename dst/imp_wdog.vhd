--------------------------------------------------------------------------------
--	wdog.vhd
--------------------------------------------------------------------------------
--
--	project		: IMP-BUS Slave
--	programmer	: S. Bärtschi, INDEL AG
--	date		: 09.03.2009
--	language	: VHDL
--
--	Purpose		: wdog function. 
--				  Useable to disable any outputs in case of an error.
--					
--	 			  The o_DataE (Data Output Enable) signal stays H as long the i_Reset 
--				  input gets triggered periodically.
--				  
--				  Otherwise if the i_Reset signal is missing for some time the o_DataE is set 
--				  to L then.
--
--				  The wdog Time is configurable by the C_COUTERLENGTH generic and the clock periode.
--				  The internal oscillator of the maxII device 
--				  is quite unprecise (possible frequency between 3 and 5.5 MHz)!!! 
--
--	With C_COUTERLENGTH=14 (counter counts to 0x4000) and 3 MHz to 5.5 MHz clock 
--  the wdog time will be between 3ms and 5ms
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	Rev. 0.00 : 09.03.2009-sbä : created  
--------------------------------------------------------------------------------
--$Rev:: 895                                                                   $
--$Author:: Baertschi                                                          $
--$Date:: 2009-02-27 08:59:11 +0100 (Fr, 27 Feb 2009)                          $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
USE ieee.numeric_std.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library oszillator;
use oszillator.all;


--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity imp_wdog is
	generic (
		C_COUNTERLENGTH : natural range 1 to 24 := 14; 
		C_INTERNAL_CLOCK : natural range 0 to 1 := 1
	);
	port (
		i_Clk : 	in std_logic := H;			-- Counter clock
		i_Reset :	in std_logic;				-- Event input
		o_DataE :	out std_logic				-- Enable for the Data Outputs
	);
end imp_wdog;
architecture arch_imp_wdog of imp_wdog is
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal counter: unsigned(C_COUNTERLENGTH downto 0):= (others => L);	
	signal clk: std_logic;
	signal wdog : std_logic := L;
	signal osc_sig : std_logic := L;
	

-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin											-- of architecture BEHAVIOR_NAME
-- processes -------------------------------------------------------------------
	
	wdog <= counter(C_COUNTERLENGTH);
	o_DataE <= not wdog;
	clk <= osc_sig when C_INTERNAL_CLOCK=1 else i_clk;
			
			
--	-- the Watchdog counter
	wdog_cnt : process (clk, i_Reset)
	begin
		if i_Reset = H then
			counter <= (others => L );	
		elsif rising_edge(clk) then
			if	wdog=L then				
				counter <= counter + 1;		
			end if;
		end if;
	end process;	
	
	
	-- The Oszillator
	oszillator_inst : entity oszillator.oszillator(RTL) PORT MAP (
		oscena  => H,
		osc	 => osc_sig
	);
	
end arch_imp_wdog;
--------------------------------------------------------------------------------

