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
--  	- Controll sevensegment with a multiplexer
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
	port (
		i_clk		: in  std_logic;
		in_switch	: in  std_logic_vector(7 downto 0);
		o_7seg		: out std_logic_vector(6 downto 0);
		o_enable	: out std_logic_vector(3 downto 0) := (others => '0');
		o_led		: out std_logic_vector(7 downto 9)
	);
end sevensegment;

architecture impl of sevensegment is
	constant DF_QUARTZ_US : integer := 66;
	constant DF_SEG_DELAY : integer := 5;
	
	type	returnvalue	is array(0 to 3) of std_logic_vector(6 downto 0);
	
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

	signal start	: std_logic := '0'; 		-- Variables for the division
	signal done 	: std_logic := '0';
	signal divisor	: std_logic_vector(13 downto 0) := (others => '0');
	signal dividend : std_logic_vector(13 downto 0) := (others => '0');
	signal result	: std_logic_vector(13 downto 0) := (others => '0');
	signal rest		: std_logic_vector(13 downto 0) := (others => '0');
	signal number	: integer range 0 to 13 := 1234;
	
	signal us_cnt	: unsigned(7 downto 0) := (others => '0'); 		-- Timer variables
	signal ms_cnt	: unsigned(9 downto 0) := (others => '0');
	signal us_tick		: std_logic := '0'; 		-- every us 1 clock high
	signal ms_tick		: std_logic := '0'; 		-- every ms 1 clock high
	
	signal sevenseg : returnvalue := (others => '0'); 		-- sevensegment output
	signal SegRegistered : std_logic_vector(o_7Seg'range) := (others => '0');
	
	signal cnt_multiplex	: integer range 0 to 4 := 0;
	signal en_switcher 		: integer range 0 to 4 := 0;
	
	type state_type is (idle, seg0, seg1, seg2, seg3); 		-- States for the multiplexer
	signal state : state_type;
	
begin
	o_7seg <= not segRegistered;

	timer: process(i_clk) begin
		if (rising_edge(i_clk)) then
			us_cnt <= us_cnt + 1;
			us_tick <= '0';
			ms_tick <= '0';
			
			if (us_cnt = DF_QUARTZ_US -1) then 		-- us counter
				us_cnt <= (others => '0');
				us_tick <= '1';
			end if;
			if (us_tick = '1') then
				ms_cnt <= ms_cnt + 1;
				
				if (ms_cnt = 999) then 		-- ms counter
					ms_cnt <= (others => '0');
					ms_tick <= '1';
				end if;
			end if;
		end if;
	end process timer;
	
	multiplexer: process (i_clk) begin
		if (rising_edge(i_clk)) then
			if (ms_tick = '1') then
				cnt_multiplex <= cnt_multiplex + 1;
				
				if (cnt_multiplex >= DF_SEG_DELAY) then
				cnt_multiplex <= 0;
				
				case state is
					when idle =>
						dividend <= std_logic_vector(to_unsigned(number, number'length));
						
						if (en_switcher = 0) then
							divisor <= 10;
							start <= '1';
							
							if (done = '1') then
								state <= seg0;
							end if;
						elsif (en_switcher = 1) then
							divisor <= 10;
							start <= '1';
							
							if (done = '1') then
								state <= seg1;
							end if;
						elsif (en_switcher = 2) then
							divisor <= 100;
							start <= '1';
							
							if (done = '1') then
								state <= seg2;
							end if;
						else
							divisor <= 1000;
							start <= '1';
							
							if (done = '1') then
								state <= seg3;
							end if;
						end if;
					when seg0 =>
						o_enable <= "1000";
						-- rest
						SegRegistered <= SiebenSeg2(rest);
						
						en_switcher <= 1;
						state <= idle;
					when seg1 =>
						o_enable <= "0100";
						--result
						SegRegistered <= SiebenSeg2(result);
						
						en_switcher <= 2;
						state <= idle;
					when seg2 =>
						o_enable <= "0010";
						--result
						SegRegistered <= SiebenSeg2(result);
						
						en_switcher <= 3;
						state <= idle;
					when seg3 =>
						o_enable <= "0001";
						--result
						SegRegistered <= SiebenSeg2(result);
						
						en_switcher <= 0;
						state <= idle;
				end case;
			end if;
		end if;
	end process multiplexer;
	
	dividierer: entity work.division
	generic map (
		DF_BIT_WIDTH => divisor'length
	)
	port map (
		 i_clk => i_clk,
		 i_start => start,
		 i_divisor => divisor,
		 i_dividend	 => dividend,
		 o_result => result,
		 o_rest => rest,
		 o_done=> done
	);

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
