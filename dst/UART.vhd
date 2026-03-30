----------------------------------------------------------------------------
--
-- UART
--
---------------------------------------------------------------------------
--
-- project : UART
-- programmer : D.Buehler, INDEL AG
-- date : 17.06.2021
-- version : 1.00
-- language : VHDL
--
-- purpose
-- - Read / Write from UART
--
--------------------------------------------------------------------------------
--$Rev:: 4088 $
--$Author:: Leuthold $
--$Date:: 2016-10-25 10:52:29 +0200 (Di., 25 Okt 2016) $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;

-- library INDEL_pkg;
-- use INDEL_pkg.INDEL_pkg.all;

ENTITY UART IS
	PORT (
		i_clk : IN std_logic; -- Clock
 
		i_RX : IN std_logic; -- UART RX / TX
		o_TX : OUT std_logic;
 
		i_start : IN std_logic;
		o_done : OUT std_logic;
		i_data : IN std_logic_vector(7 DOWNTO 0) := (OTHERS => '0')
		);
	END UART;

	ARCHITECTURE impl OF UART IS
		CONSTANT DF_QUARTZ_US : INTEGER := 66; -- Time in MHz
		CONSTANT DF_BAUDRATE : INTEGER := 573; -- Define Baudrate => (DF_QUARTZ_US*1E6 / Desired Baudrate)
 
		SIGNAL RX : std_logic := '1'; -- RX / TX active low
		SIGNAL TX : std_logic := '1';
		SIGNAL start : std_logic := '0';

		SIGNAL rx_data : std_logic_vector(7 DOWNTO 0) := (OTHERS => '0'); -- rx_data buffer
		SIGNAL rx_data_cnt : unsigned(3 DOWNTO 0) := (OTHERS => '0'); -- counter
		SIGNAL cnt_uart : INTEGER RANGE 0 TO DF_BAUDRATE := 0; -- counter signals
		SIGNAL do_uart : std_logic := '0';
 
		SIGNAL tx_data : std_logic_vector(7 DOWNTO 0) := (OTHERS => '0'); -- tx_data buffer
		SIGNAL tx_data_cnt : INTEGER RANGE 0 TO 8 := 0; -- counter
		SIGNAL tx_counter : INTEGER RANGE 0 TO DF_BAUDRATE := 0;
 
		TYPE state_type_rx IS (idle_rx, wait_halfpulse, read_rx); -- States RX
		SIGNAL state_rx : state_type_rx;
 
		TYPE state_type_tx IS (idle_tx, write_tx, stop_tx); -- States TX
		SIGNAL state_tx : state_type_tx;
	BEGIN
		o_TX <= TX;
		RX <= i_RX;
		start <= i_start;
 
		TIMER_UART : PROCESS (i_clk) BEGIN
			IF (rising_edge(i_clk)) THEN
				IF (state_rx = wait_halfpulse) THEN
					cnt_uart <= cnt_uart + 1;
					IF (cnt_uart = (DF_BAUDRATE / 2 - 1)) THEN -- Halfpulse
						do_uart <= '1';
						cnt_uart <= 0;
					ELSE
						do_uart <= '0';
					END IF;
				ELSIF (state_rx = read_rx) THEN
					cnt_uart <= cnt_uart + 1;

					IF (cnt_uart = (DF_BAUDRATE - 1)) THEN -- Halfpulse
						do_uart <= '1';
						cnt_uart <= 0;
					ELSE
						do_uart <= '0';
					END IF;
				ELSE
					cnt_uart <= 0;
				END IF;
			END IF;
		END PROCESS TIMER_UART;
 
		UART_RX : PROCESS (i_clk) BEGIN
			IF (rising_edge(i_clk)) THEN
				CASE state_rx IS
					WHEN idle_rx => -- WAIT FOR STARTBIT
						-- start <= '0'; -- TEST APPLICATION--------------------------
						IF (RX = '0') THEN -- Startbit
							state_rx <= wait_halfpulse;
						END IF;
					WHEN wait_halfpulse => 
						IF (do_uart = '1') THEN
							rx_data <= (OTHERS => '0');
							state_rx <= read_rx;
						END IF;
					WHEN read_rx => -- RX: READ INPUT
						IF (do_uart = '1') THEN
							IF (rx_data_cnt <= 7) THEN
								rx_data_cnt <= rx_data_cnt + 1;

								rx_data <= std_logic_vector(shift_right(unsigned(rx_data), 1));
								rx_data(7) <= NOT RX;
							ELSE
								rx_data_cnt <= (OTHERS => '0');
								state_rx <= idle_rx;

								-- start <= '1'; -- TEST APPLICATION-------------------------
							END IF;
						END IF;
				END CASE;
			END IF;
		END PROCESS UART_RX;

		UART_TX : PROCESS (i_clk) BEGIN
			IF (rising_edge(i_clk)) THEN
				tx_counter <= tx_counter + 1;
				o_done <= '0';

				CASE state_tx IS
					WHEN idle_tx => 
						IF (start = '1') THEN -- Wait for done signal
							TX <= '0';
							--tx_data <= rx_data; -- TEST APPLICATION-----------------------
							tx_data <= i_data;

							state_tx <= write_tx;
						END IF;
						tx_counter <= 0;
					WHEN write_tx => -- TX: WRITE OUTPUT
						IF (tx_counter = (DF_BAUDRATE - 1)) THEN
							tx_counter <= 0;

							IF (tx_data_cnt <= 7) THEN
								tx_data_cnt <= tx_data_cnt + 1;

								tx_data(6 DOWNTO 0) <= tx_data(7 DOWNTO 1);
								TX <= tx_data(0);
							ELSE
								tx_data_cnt <= 0;
								state_tx <= stop_tx;
								TX <= '1'; -- Deactivate the TX -> stopbit
							END IF;
						END IF;
					WHEN stop_tx => 
						IF (tx_counter = (DF_BAUDRATE - 1)) THEN
							tx_counter <= 0;

							o_done <= '1';
							state_tx <= idle_tx;
						END IF;
				END CASE;
			END IF;
		END PROCESS UART_TX;

	--------------------------------------------------------------------------------
	END impl;
	--------------------------------------------------------------------------------
