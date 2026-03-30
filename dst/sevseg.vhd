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

entity sevensegment is
	generic (
		DF_QUARTZ_FREQ : positive; 		-- Time in MHz
		DF_SEG_DELAY : positive		-- Time in ms
	);
	port (
		i_clk		: in  std_logic;
		o_7seg		: out std_logic_vector(6 downto 0);
		o_enable	: out std_logic_vector(3 downto 0) := (others => '0');
		i_number	: in std_logic_vector(13 downto 0);
		
		o_dec_number : out std_logic_vector(7 downto 0);
		o_new_value : out std_logic
	);
end sevensegment;

architecture impl of sevensegment is
	
	
	type hexSeg is array(0 to 15) of std_logic_vector(o_7seg'range);
	constant arraySeg : hexSeg := (	"0111111",		-- 0
									"0000110",		-- 1
									"1011011",		-- 2
									"1001111",		-- 3
									"1100110",		-- 4
									"1101101",		-- 5
									"1111101",		-- 6
									"0000111",		-- 7
									"1111111",		-- 8
									"1101111",		-- 9
									"1110111",		-- A
									"1111100",		-- B
									"0111001",		-- C
									"1011110",		-- D
									"1111001",		-- E
									"1110001" 		-- F
									);
--------------------------------------------------------------------------------

	signal start	: std_logic := '0'; 		-- Signals for the division
	signal done 	: std_logic := '0';
	signal divisor	: std_logic_vector(13 downto 0) := (others => '0');
	signal dividend : std_logic_vector(13 downto 0) := (others => '0');
	signal result	: std_logic_vector(13 downto 0) := (others => '0');
	signal rest		: std_logic_vector(13 downto 0) := (others => '0');

	signal SegRegistered : std_logic_vector(o_7Seg'range) := (others => '0'); 		-- Signals for multiplexer & sevensegment
	signal cnt_multiplex : integer range 0 to 4 := 0;
	signal en_switcher 	 : integer range 0 to 4 := 0;
	
	signal ms_tick	: std_logic := '0'; 		-- every ms 1 clock high
	signal ms_cnt	: unsigned(16 downto 0) := (others => '0');	 	-- ms counter
	
	type state_type is (inp, idle, seg0, seg1, seg2, seg3); 		-- States for the multiplexer
	signal state : state_type;
	
begin
	o_7seg <= not segRegistered;

	timer: process(i_clk) begin 		-- ms tick
		if (rising_edge(i_clk)) then
			ms_cnt <= ms_cnt + 1;
			ms_tick <= '0';

			if (ms_cnt >= (DF_QUARTZ_FREQ * 1000 - 1)) then
				ms_cnt <= (others => '0');
				ms_tick <= '1';
			end if;
		end if;
	end process timer;	
		
	multiplexer: process (i_clk) begin
		if (rising_edge(i_clk)) then
			o_new_value <= '0';
			
			if (ms_tick = '1') then
				cnt_multiplex <= cnt_multiplex + 1;
			end if;			
				
			case state is
				when idle =>
					o_enable <= "0000";
					
					if (en_switcher = 0) then
						start <= '1';
						dividend <= i_number;
						divisor <= std_logic_vector(to_unsigned(10, 14));
						
						if (done = '1') then
							start <= '0';
							state <= seg0;
						end if;
					elsif (en_switcher = 1) then
						start <= '1';
						if (done = '1') then
							start <= '0';
							
							state <= seg1;
						end if;
					elsif (en_switcher = 2) then
						start <= '1';
						if (done = '1') then
							start <= '0';
							state <= seg2;
						end if;
					else
						start <= '1';
						if (done = '1') then
							start <= '0';
							state <= seg3;
						end if;
					end if;
				when seg0 => 						-- Display Digit 0
					o_enable <= "1000";
					-- rest
					dividend <= result;
					SegRegistered <= arraySeg(to_integer(unsigned(rest)));
					
					o_dec_number <= rest(7 downto 0);
					o_new_value <= '1';
					
					en_switcher <= 1;
					state <= inp;
				when seg1 => 						-- Display Digit 1
					o_enable <= "0100";
					--result
					dividend <= result;
					SegRegistered <= arraySeg(to_integer(unsigned(rest)));
					
					o_dec_number <= rest(7 downto 0);
					o_new_value <= '1';
					
					en_switcher <= 2;
					state <= inp;
				when seg2 => 						-- Display Digit 2
					o_enable <= "0010";
					--result
					dividend <= result;
					SegRegistered <= arraySeg(to_integer(unsigned(rest)));
					
					o_dec_number <= rest(7 downto 0);
					o_new_value <= '1';
					
					en_switcher <= 3;
					state <= inp;
				when seg3 => 						-- Display Digit 3
					o_enable <= "0001";
					--result
					dividend <= result;
					SegRegistered <= arraySeg(to_integer(unsigned(rest)));
					
					o_dec_number <= rest(7 downto 0);
					o_new_value <= '1';
					
					en_switcher <= 0;
					state <= inp;
				when inp =>
					if (cnt_multiplex >= DF_SEG_DELAY) then
						cnt_multiplex <= 0;
						state <= idle;
					end if;
			end case;

		end if;
	end process multiplexer;
	
	dividierer: entity work.division
	generic map (
		DF_BIT_WIDTH => divisor'length
	)
	port map (
		i_clk 	   => i_clk,
		i_start    => start,
		i_divisor  => divisor,
		i_dividend => dividend,
		o_result   => result,
		o_rest 	   => rest,
		o_done	   => done
	);
	
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------