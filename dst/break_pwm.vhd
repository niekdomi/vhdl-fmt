--------------------------------------------------------------------------------
--  break_pwm.vhd
--------------------------------------------------------------------------------
--
--	project     : 
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 24.04.2008
--	version     : 
--	language    : VHDL
--
--	purpose
--		break_pwm
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	24.04.2008-le:	- start
--	27.07.2009-le:	- add C_MODE: 0: max frequency switching / 1: normal fix frequency switching
--	03.05.2010-le:	- move reset at value 0 to clk en section
--------------------------------------------------------------------------------
--$Rev:: 1416                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2010-05-03 16:17:07 +0200 (Mo., 03 Mai 2010)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity break_pwm is
	generic (
		C_LNG : positive := 7;
		C_100PERC: positive := 100;
		C_MODE : integer range 0 to 1 := 0 -- 0: max frequency switching / 1: normal fix frequency switching
	);
	port (
		i_clk : in std_logic;
		i_reset : in std_logic;
		i_clk_en	: in	std_logic;
		o_PWM		: out std_logic;
		i_value : in std_logic_vector(C_LNG-1 downto 0)
	);
end;                                                -- of entity break_pwm

architecture behavior_break_pwm of break_pwm is
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal dout  : std_logic := L;
	signal cmp  : std_logic := L;
	signal dif   : unsigned(C_LNG-1 downto 0) := (others => L);
	signal value : unsigned(C_LNG-1 downto 0) := (others => L);
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin
	
		o_PWM <= dout;
		
		value <= unsigned(i_value);
		--sub <= dif - value;
		cmp <= H when value>dif else L;
		
		process (i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_reset=H) then
					dout <= L;
					dif <= (others => L);
				elsif (i_clk_en=H) then
					if (value=0) then
						dout <= L;
						dif <= (others => L);
					else
						if (C_MODE=0) then
							if (cmp=H) then
								dout <= H;
								dif <= dif - value + C_100PERC;
							else
								dout <= L;
								dif <= dif - value;
							end if;
						else
							if (cmp=H) then
								dout <= H;
							else
								dout <= L;
							end if;
							if (dif<C_100PERC-1) then
								dif <= dif + 1;
							else
								dif <= (others => L);
							end if;
						end if;
					end if;
				end if;
			end if;
		end process;
	
end behavior_break_pwm;
--------------------------------------------------------------------------------

