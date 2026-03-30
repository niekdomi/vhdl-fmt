---------------------------------------------------------------------------
--
--  ADC_filter
--
---------------------------------------------------------------------------
--
--  project     : ADC_filter.vhd
--  programmer  : D.Buehler, INDEL AG
--  date        : 28.05.2021
--  version     : 1.00
--  language    : VHDL
--
--  purpose
--  	- Filter for ADC values
--
--------------------------------------------------------------------------------
--$Rev:: 4088                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-10-25 10:52:29 +0200 (Di., 25 Okt 2016)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity ADC_filter is
	generic (
	--DF_SAMPLES			: integer := 20;
	DF_HYSTERESIS_BITS  : integer := 2;
	DF_NUMB_OF_BIT		: integer := 8
	);
	port (
		DF_SAMPLES : in integer := 20;
		i_clk				: in std_logic;
		i_adcvalue_raw		: in std_logic_vector(DF_NUMB_OF_BIT - 1 downto 0);
		o_adcvalue_filtered : out std_logic_vector(DF_NUMB_OF_BIT+9 downto 0);--pkg_log2(DF_SAMPLES) downto 0);
		i_start_filter		: in std_logic;
		o_done_filter		: out std_logic
	);
end ADC_filter;

architecture impl of ADC_filter is
	constant DF_FILTER_METHOD	: std_logic := '1'; 		-- If '1' -> The average of X samples will be determined 
	-- constant DF_SAMPLES			: integer := 4;				-- otherwise it uses a hysteresis
	-- constant DF_HYSTERESIS_BITS  : integer := 2;
	-- constant DF_NUMB_OF_BIT		: integer := 16;
	
	signal adcvalue_raw		 : std_logic_vector(DF_NUMB_OF_BIT - 1 downto 0) := (others => '0');
	signal adcvalue_filtered : std_logic_vector(DF_NUMB_OF_BIT+9 downto 0):= (others=>'0');--pkg_log2(DF_SAMPLES) downto 0) := (others => '0');
	
	signal sample_buffer : std_logic_vector(DF_NUMB_OF_BIT+9 downto 0):= (others=>'0');--pkg_log2(DF_SAMPLES) downto 0) := (others => '0');
	signal uns_rawvalue		: unsigned(DF_NUMB_OF_BIT - 1 downto 0) := (others => '0');
	signal uns_rawvalue_old : unsigned(DF_NUMB_OF_BIT - 1 downto 0) := (others => '0');
	
	signal counter_samples : integer range 0 to 322247 := 0;  -- DF_SAMPLES
	signal start_filter	: std_logic := '0';
	
	type state_type is (count, shift, output);
	signal state : state_type;

begin
	adcvalue_raw 		<= i_adcvalue_raw;
	start_filter 		<= i_start_filter;
	o_adcvalue_filtered <= adcvalue_filtered;
	
	filter: process(i_clk) begin
		if (rising_edge(i_clk)) then
			if (DF_FILTER_METHOD = '1') then 		-- The average of X samples
				o_done_filter <= '0';
				
				if (start_filter = '1') then 		-- Wait on start command
					case state is
						when count =>
							if (counter_samples >= (DF_SAMPLES - 1)) then 		-- Take X samples
								counter_samples <= 0;
								state <= shift;
							else
								counter_samples <= counter_samples + 1;
								sample_buffer <= std_logic_vector(unsigned(sample_buffer) + unsigned(adcvalue_raw)); 		-- Fill buffer with the ADC value
							end if;
						when shift =>
							--sample_buffer <= std_logic_vector(shift_right(unsigned(sample_buffer), pkg_log2(DF_SAMPLES))); 		-- Shift the buffer back
																																	-- to get the average value
							state <= output;
						when output =>
							adcvalue_filtered <= sample_buffer;		-- Return the average value
							sample_buffer <= (others => '0');
							
							o_done_filter <= '1';
							state <= count;
					end case;
				end if;
			else 		-- Hysteresis
				if (start_filter = '1') then
					uns_rawvalue <= unsigned(adcvalue_raw);
					
					if ( (uns_rawvalue < (uns_rawvalue_old - DF_HYSTERESIS_BITS / 2)) or (uns_rawvalue > (uns_rawvalue_old + DF_HYSTERESIS_BITS / 2)) ) then
						uns_rawvalue_old <= uns_rawvalue;	 	-- Check if the new value is higher or lower than the old value, if yes it returns the new one
						adcvalue_filtered <= std_logic_vector(uns_rawvalue);
					end if;
				end if;
			end if;
		end if;
	
	end process filter;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------