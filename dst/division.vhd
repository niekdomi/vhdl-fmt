---------------------------------------------------------------------------
--
--  Dividierer
--
---------------------------------------------------------------------------
--
--  project     : division
--  programmer  : D.Buehler, INDEL AG
--  date        : 27.04.2021
--  version     : 1.00
--  language    : VHDL
--
--  purpose
--  	- Das Dividieren von zwei Zahlen
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

entity division is
	generic (
		DF_BIT_WIDTH : integer range 1 to 16 := 14
	);
	port (
		i_clk		: in std_logic;
		i_start		: in std_logic;
		o_done		: out std_logic;
		i_divisor	: in std_logic_vector(DF_BIT_WIDTH - 1 downto 0);
		i_dividend	: in std_logic_vector(DF_BIT_WIDTH - 1 downto 0);
		o_result	: out std_logic_vector(DF_BIT_WIDTH - 1 downto 0);	
		o_rest		: out std_logic_vector(DF_BIT_WIDTH - 1 downto 0)
	);
end division;

architecture impl of division is
	constant DF_0 : std_logic_vector((DF_BIT_WIDTH - 1) downto 0) := (others => '0');
	
	function log2 (numerus : integer) return integer is 		-- Calculate the logarithm of a Number
		variable temp      : integer := numerus;
		variable logarithm : integer := 1;
		
	begin
		while (temp > 1) loop
			temp := temp / 2;
			logarithm := logarithm + 1;
		end loop;
		
		return logarithm;
	end function log2;
	
	signal numb_of_bits 	: unsigned(log2(DF_BIT_WIDTH) - 1 downto 0) := (others => '0');
	signal divisor			: unsigned((2*DF_BIT_WIDTH) - 1 downto 0) := (others => '0');
	signal dividend			: unsigned((2*DF_BIT_WIDTH) - 1 downto 0) := (others => '0');
	signal result			: unsigned(DF_BIT_WIDTH - 1 downto 0) := (others => '0');
	signal rest				: unsigned(DF_BIT_WIDTH - 1 downto 0) := (others => '0');

	type state_type is (idle, divide, output);
	signal state : state_type;

begin
	o_result <= std_logic_vector(result);
	o_rest <= std_logic_vector(rest);
	
	process (i_clk) begin
		if (rising_edge(i_clk)) then
			o_done <= '0';
			
			case state is
				when idle => 		-- idle: wait for i_start command
					divisor <= unsigned(i_divisor & DF_0) ;
					dividend <= unsigned(i_dividend & DF_0);
					
					if (i_start = '1') then 		-- If i_start is HIGH then start to divide
						numb_of_bits <= to_unsigned(DF_BIT_WIDTH, numb_of_bits'length);
						result <= (others => '0');
						state <= divide;
					end if;
				when divide => 		-- solve the division
					if (numb_of_bits > 0) then 		-- Check every digit (14 bit)
						numb_of_bits <= numb_of_bits - 1;
					
						if ((shift_left(dividend, 1)) >= divisor) then 		-- Division
							dividend <= shift_left(dividend, 1) - divisor;
							result <= shift_left(result, 1) + 1; 		-- Result (without decimals!)
						else
							dividend <= shift_left(dividend, 1);
							result <= shift_left(result, 1);
						end if;				
					else
						state <= output;
					end if;
				when output =>
					rest <= (dividend(2*DF_BIT_WIDTH - 1 downto DF_BIT_WIDTH)); 		-- Remaining value
					o_done <= '1';
					if (i_start = '0') then 
						state <= idle;
					end if;
					
			end case;
		end if;
	end process;
end architecture impl;