--------------------------------------------------------------------------------
--	CPLD_Board.vhd
--------------------------------------------------------------------------------
--
--	project     : CPLD_Board
--	programmer  : N. Ochsenbein, INDEL AG
--	date        : 21.03.2012
--	version     : 1.00
--	language    : VHDL
--	system      : CPLD-Board
--
--	purpose
--		Auf der 7-Segmentanzeige wird der Ausgelesene ADC-Wert des Kanals CH0
-- 		wahlweise in Hex oder Dezimal angezeigt.
--		Den analogen Wert vom Kanal CH0 kann mit dem Poti bis E4/228, was 4.5V
--		entspricht verstellt werden.
--		Die Anzeige wird mit dem Schalter S0 umgeschaltet. (Aus = Hex, Ein = Dez)
--------------------------------------------------------------------------------
-- revision information
--	29.03.2012-no	: - Erste Schritte
--	30.03.2012-no	: - Volle FunktionalitÃÂ¤t
--	04.11.2019-le	: - adjustments for signed input
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--$Rev:: 5396                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-11-04 11:08:34 +0100 (Mo., 04 Nov 2019)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity rc_filter is
generic (
	C_FILTER_LENGTH : positive := 14; -- um die Bitzahl des zu filternden Signals anzugeben
	C_FILTER_SHIFT : positive := 2 -- mit diesem Wert wird die Filterkonstante verÃ¤ndert
);
port (
	i_clk 		: in  std_logic;
	i_newVal	: in  std_logic;
	i_val 	: in  std_logic_vector(C_FILTER_LENGTH-1 downto 0);
	o_val	: out std_logic_vector(C_FILTER_LENGTH-1 downto 0)
);
end rc_filter;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of rc_filter is
	----------------------------------------------------------------------------
	-- constants 
	----------------------------------------------------------------------------
	constant H 			: std_logic := '1';
	constant L 			: std_logic := '0';
	constant Z 			: std_logic := 'Z';
	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal dif : signed(C_FILTER_LENGTH+C_FILTER_SHIFT downto 0);
	signal filter : signed(C_FILTER_LENGTH+C_FILTER_SHIFT downto 0) := (others => L);
	signal filler : std_logic_vector(C_FILTER_SHIFT-1 downto 0) := (others => L);
	
	-- Errechnet den 2er log der Zahl
	function pkg_log2(value : natural) return integer is
	begin
		if value=0 then
			return 1;
		end if;
		for i in 0 to 31 loop
			if ((2**i)>=value) then
				return i;
			end if;
		end loop;
		return -1;
	end pkg_log2;

begin -- architecture ----------------------------------------------------------
	
	dif <= signed(i_val(i_val'high) & i_val & filler)-filter; -- Eingangsvariabel wird in signed verwandelt
										--die bereits signed Ausgangsvariabel wird abgezogen
	o_val <= std_logic_vector(filter(C_FILTER_LENGTH+C_FILTER_SHIFT-1 downto C_FILTER_SHIFT));
	-- Die oberen Bits der Ausgangsvariabel werden in einen std_logic_vector verwandelt
	
	RCFilter: process(i_clk)
	begin
		if (rising_edge(i_clk)) then
			
			
			if (i_newVal = H) then -- Wird nur ausgefÃ¼hrt, wenn ein neuer Wert mÃ¶glich wÃ¤re bzw. der Filter "aufgerufen" wird
				-- Hier wird die Differenz um die zu teilende Anzahl Bits geschoben dazugezÃ¤hlt
				filter <= filter + shr(dif, conv_unsigned(C_FILTER_SHIFT,pkg_log2(C_FILTER_SHIFT+1)));
			end if;
		end if;
	end process RCFilter;


end architecture STRUCTURE;
