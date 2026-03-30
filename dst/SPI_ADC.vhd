---------------------------------------------------------------------------
--
--  Siebensegment
--
---------------------------------------------------------------------------
--
--  project     : Siebensegment
--  programmer  : D.Buehler, INDEL AG
--  date        : 06.05.2021
--  version     : 1.00
--  language    : VHDL
--
--  purpose
--  	- Controll sevensegments with a multiplexer
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

entity spi_adcTCL0832 is
	port (
		i_clk		: in  std_logic;
		i_start		: in  std_logic;
		i_adcvalue	: in  std_logic;
		o_adcvalue	: out std_logic_vector(15 downto 0);
		o_done		: out std_logic;
		o_adcclk	: out std_logic;
		o_cs		: out std_logic;
		o_di		: out std_logic;
		
		i_not_even : in std_logic := '0';
		i_not_diff : in std_logic := '0'
	);
end spi_adcTCL0832;

architecture impl of spi_adcTCL0832 is
	
	constant DF_QUARTZ_US    : integer := 66; 		-- Clock in MHZ
	constant DF_FREQ_SPI     : integer := 660; 		-- Clock in kHz = ((DF_QUARTZ_US * 1E9 / Desired Frequency))
	--constant DF_ADC_NOT_DIF  : std_logic := '0';
	--constant DF_ADC_NOT_EVEN : std_logic := '0';
	constant DF_REGISTER_METHOD : std_logic := '0'; 		-- Choose which method should be used to create the ADC- value
	
	signal cs : std_logic := '1';
	signal di : std_logic := '0';
	signal adcclk : std_logic := '0';
	signal done : std_logic := '0';
	
	signal o_adc_state : std_logic;
	
	signal us_cnt	: unsigned(7 downto 0) := (others => '0'); 		-- Timer variable
	signal cnt_freq	: integer range 0 to DF_FREQ_SPI := 0;
	
	signal adc_wait	: integer range 0 to 5 := 0;
	signal adc_fill_buffer : integer range 0 to 16 := 0;
	signal adcvalue	: std_logic_vector(15 downto 0) := (others => '0');--(others => '0');
	
	type state_type is (idle, start, getBit, config, finito); 		-- States for the multiplexer
	signal state : state_type;
	
begin
	o_adcvalue <= adcvalue;
	o_done	 <= done;
	o_adcclk <= adcclk;
	o_cs	 <= cs;
	o_di	 <= di;
		
	-- timer: process(i_clk) begin
		-- if (rising_edge(i_clk)) then
			-- us_cnt <= us_cnt + 1;
			
			-- if (us_cnt = DF_QUARTZ_US - 1) then 		-- us counter
				-- us_cnt <= (others => '0');
			-- end if;
		-- end if;
	-- end process timer;
	
	adcclock: process (i_clk) begin
		if (rising_edge(i_clk)) then
			if (cnt_freq = (DF_FREQ_SPI / 2 - 1)) then
				if (adcclk = '1') then
					adcclk <= '0';
				else
					adcclk <= '1';
				end if;
			end if;
			if (cnt_freq = (DF_FREQ_SPI - 1)) then
				cnt_freq <= 0; 		-- Reset the counter
				
				if (adcclk = '1') then
					adcclk <= '0';
				else
					adcclk <= '1';
				end if;
			else
				cnt_freq <= cnt_freq + 1;
			end if;	
		end if;
	end process adcclock;
	
	readAdcValue: process (i_clk) begin
		if (rising_edge(i_clk)) then
			done <= '0';
			if (cnt_freq = DF_FREQ_SPI - 1) then
				case state is
					when idle =>
						if (i_start = '1') then
							--done <= '0';
							state <= start;
						end if;
					when start =>
						cs <= '0';
						di <= '1'; 		-- Set startbit
						state <= config;
					when config =>
						adc_wait <= adc_wait + 1;
						if (adc_wait = 0) then
							di <= i_not_diff;
						elsif (adc_wait = 1) then
							di <= i_not_even;
						else
							adc_wait <= 0;
							state <= getBit;
						end if;
					when getBit =>
						if (DF_REGISTER_METHOD = '1') then 		-- Shift-register method is enabled
							if (adc_fill_buffer >= 15) then
								if (adc_fill_buffer = 16) then
									adc_fill_buffer <= 0;
									state <= finito;
								else
									adc_fill_buffer <= adc_fill_buffer + 1;
								end if;
							else
								adcvalue <= adcvalue(14 downto 0) & i_adcvalue;
								
								adc_fill_buffer <= adc_fill_buffer + 1;
							end if;
						else
							if (adc_fill_buffer = 16) then
								adc_fill_buffer <= 0;
								state <= finito;
							else
								adcvalue(adc_fill_buffer) <= i_adcvalue; -- write the values into a vector
								adc_fill_buffer <= adc_fill_buffer + 1;
							end if;
						end if;
					when finito =>
						cs <= '1';
						done <= '1';
						state <= idle;
				end case;
			end if;
		end if;
	end process readAdcValue;
	
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------