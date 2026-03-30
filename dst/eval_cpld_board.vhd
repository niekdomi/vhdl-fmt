----------------------------------------------------------------------------
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

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity eval_cpld_board is
	port (
		i_clk		: in  std_logic; 		-- Clock
		
		in_switch	: in  std_logic_vector(7 downto 0); 		-- Switches & Leds
		o_led		: out std_logic_vector(7 downto 0);
		
		o_7seg		: out std_logic_vector(6 downto 0); 		-- Sevensegment Pins
		o_enable	: out std_logic_vector(3 downto 0) := (others => '0');
		
		i_RX 		: in std_logic; 		-- UART RX / TX
		o_TX 		: out std_logic;
		
		i_adcvalue  : in std_logic; 		-- ADC Pins
		o_adcclk    : out std_logic;
		o_cs	    : out std_logic;
		o_di	    : out std_logic
	);
end eval_cpld_board;

architecture impl of eval_cpld_board is
	constant DF_QUARTZ_US   : integer := 66; 		-- Time in MHz
	constant DF_SEG_DELAY   : integer := 5; 		-- Time in ms
	constant DF_SAMPLES	    : integer := 314;
	constant DF_SAMPLES_TEST: integer := 312;
	constant DF_NUMB_OF_BIT : integer := 8;
	
	signal done_uart : std_logic := '0'; 		-- Signals for UART
	signal start_uart : std_logic := '0';
	signal data_uart : std_logic_vector(7 downto 0) := (others => '0');
	signal char1 : std_logic_vector(7 downto 0) := (others => '0');
	signal char2 : std_logic_vector(7 downto 0) := (others => '0');
	signal char3 : std_logic_vector(7 downto 0) := (others => '0');
	signal char4 : std_logic_vector(7 downto 0) := (others => '0');
	
	type state_type_uart is (idle, number1, number2, number3, number4, BS);-- LF, CR);
	signal state_uart : state_type_uart;
	type state_type_characters is (idle, number1, number2, number3, number4);
	signal state_uart_characters : state_type_characters;
	
	signal start_adc : std_logic := '0'; 		-- Signals for the SPI ADC 
	signal adc_done  : std_logic := '0';
	signal adc_poti	 : std_logic_vector(7 downto 0) := (others => '0');
	signal adc_ext	 : std_logic_vector(7 downto 0) := (others => '0');
	signal adcvalue  : std_logic_vector(15 downto 0) := (others => '0');

	signal start_filter : std_logic := '0'; 		-- Signals for the ADC Filter
	signal done_filter  : std_logic := '0';
	signal adcvalue_filtered : std_logic_vector(DF_NUMB_OF_BIT+pkg_log2(DF_SAMPLES) downto 0) := (others => '0');
	signal adcvalue_to_filter : std_logic_vector(7 downto 0) := (others => '0');
	
	signal number 	  : std_logic_vector(13 downto 0) := (others => '0'); 		-- Display number
	signal dec_number : std_logic_vector(7 downto 0) := (others => '0');
	signal new_value  : std_logic := '0';
	signal enable	  : std_logic_vector(3 downto 0);
	
	signal blink : std_logic := '0'; 		-- Test signal
	signal blink2: std_logic := '0';
	signal samples_int : integer range 0 to DF_SAMPLES;
	signal bs_counter : integer range 0 to 5 := 0;
begin
	o_led(3 downto 0) <= in_switch(3 downto 0);
	o_led(7) <= blink; 		-- Filter finished
	o_led(6) <= blink2; 	-- ADC new value

	process (i_clk) begin
		if(rising_edge(i_clk)) then
			if (in_switch(7) = '1') then
				samples_int <= DF_SAMPLES;
			else
				samples_int <= DF_SAMPLES_TEST;
			end if;
		end if;
	end process;
	
	adc_spi: process (i_clk) begin
		if (rising_edge (i_clk)) then
			start_adc <= '1';
			start_filter <= '0';	
			
			if (adc_done = '1') then
				start_filter <= '1';
				blink2 <= not blink2;
				if (in_switch(0) = '1') then
					adcvalue_to_filter <= adcvalue(15 downto 8); 		-- msb to lsb
				else
					adcvalue_to_filter <= adcvalue(7 downto 0); 		-- lsb to msb
				end if;
			end if;		
		end if;
	end process adc_spi;
	
	adc_filter_proc: process (i_clk) begin
		if (rising_edge (i_clk)) then
			if (done_filter = '1') then
				blink <= not blink;
				number <= adcvalue_filtered(adcvalue_filtered'high downto (adcvalue_filtered'length - number'length)); 		-- Write filtered value
			end if;
		end if;
	end process adc_filter_proc;
	
	adcValue_to_uart: process (i_clk) begin 		-- Send the ADC value over UART
		if (rising_edge(i_clk)) then
			start_uart <= '0';
			
			case state_uart is
				when idle =>
					case state_uart_characters is
						when idle =>
							if ((done_filter = '1') and (in_switch(6) = '1')) then
								state_uart_characters <= number1;
							end if;
						when number1 =>
							if ((new_value = '1') and (enable(3) = '1')) then
								char4 <= dec_number or x"30";
								state_uart_characters <= number2;
							end if;
						when number2 =>
							if (new_value = '1') then
								char3 <= dec_number or x"30";
								state_uart_characters <= number3;
							end if;
						when number3 =>
							if (new_value = '1') then
								char2 <= dec_number or x"30";
								state_uart_characters <= number4;
							end if;
						when number4 =>
							if (new_value = '1') then
								char1 <= dec_number or x"30";
								state_uart_characters <= idle;
								
								state_uart <= number1;
							end if;
					end case;
				when number1 =>
					start_uart <= '1';
					data_uart <= char1;
					state_uart <= number2;
				when number2 =>
					if (done_uart = '1') then
						start_uart <= '1';
						data_uart <= char2;
						state_uart <= number3;
					end if;
				when number3 =>
					if (done_uart = '1') then
						start_uart <= '1';
						data_uart <= char3;
						state_uart <= number4;
					end if;
				when number4 =>
					if (done_uart = '1') then
						start_uart <= '1';
						data_uart <= char4;
						state_uart <= BS;
						-- if (in_switch(5) = '1') then
							-- state_uart <= LF;
						-- else
							-- state_uart <= CR;
						-- end if;
					end if;
				-- when LF =>
					-- if (done_uart = '1') then
						-- start_uart <= '1';
						-- data_uart <= x"0A"; 		-- Line feed, new line
						-- if (in_switch(4) = '1') then
							-- state_uart <= CR;
						-- else
							-- state_uart <= idle;
						-- end if;
					-- end if;
				-- when CR =>
					-- if (done_uart = '1') then
						-- start_uart <= '1';
						-- data_uart <= x"0D"; 		-- Carriage return
						-- state_uart <= idle;
					-- end if;
				when BS => 		-- Backspace
					if (done_uart = '1') then
						bs_counter <= bs_counter + 1;
						if (bs_counter = 4) then
							state_uart <= idle;
							bs_counter <= 0;
						else
							start_uart <= '1';
							data_uart <= x"08"; 		-- Carriage return
						end if;
					end if; 
			end case;
		end if;
	end process adcValue_to_uart;
	
	sevensegment: entity work.sevensegment 		-- Include sevensegment
	generic map (
		DF_QUARTZ_FREQ => DF_QUARTZ_US,
		DF_SEG_DELAY => 5
	)
	port map (
		i_clk		=> i_clk,
		o_7seg		=> o_7seg,
		o_enable 	=> enable,
		i_number 	=> number,
		
		o_dec_number => dec_number,
		o_new_value  => new_value 
	);
	
	o_enable <= enable;
	
	spi_adc: entity work.spi_adcTCL0832 		-- Include SPI_ADC
	port map (
		i_clk	   => i_clk,
		i_start	   => start_adc,
		o_adcvalue => adcvalue,
		i_adcvalue => i_adcvalue,
		o_adcclk   => o_adcclk,
		o_cs	   => o_cs,
		o_di	   => o_di,
		o_done 	   => adc_done,
		
		i_not_even => in_switch(1),
		i_not_diff => '1'
	);
	
	adc_filter: entity work.ADC_filter 		-- Include ADC Filter
	generic map (
		--DF_SAMPLES		   => samples_int,
		DF_HYSTERESIS_BITS => 2,
		DF_NUMB_OF_BIT	   => DF_NUMB_OF_BIT
	)
	port map (
		DF_SAMPLES 			=> samples_int,
		i_clk				=> i_clk,
		i_adcvalue_raw		=> adcvalue_to_filter,
		o_adcvalue_filtered => adcvalue_filtered,
		i_start_filter		=> start_filter,
		o_done_filter		=> done_filter
	);	

	UART: entity work.UART 		-- Include ADC Filter
	port map (
		i_clk => i_clk, 		-- Clock
		i_data => data_uart,
		i_RX => i_RX, 		-- UART RX / TX
		o_TX => o_TX,
		i_start => start_uart,
		o_done => done_uart
	);
	
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
