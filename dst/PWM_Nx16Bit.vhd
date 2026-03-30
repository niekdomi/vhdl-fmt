--------------------------------------------------------------------------------
--
-- 12Bit PWM
--
--------------------------------------------------------------------------------
--
--	project		: 12Bit PWM
--	programmer	: F:Baschung, INDEL AG
--	date		: 04.09.2008
--	language	: VHDL
--	system		: Project Navigator
--
--	purpose
--		- 12Bit PWM
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.03.2013-FB - erste Version
--------------------------------------------------------------------------------
--$Rev:: 2571                                                                  $
--$Author:: Administrator                                                      $
--$Date:: 2012-12-09 08:35:38 +0100 (So, 09 Dez 2012)                          $
--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
entity PWM_16Bit is
	generic (
		g_NrOfPwm 			: integer := 4;
		g_PWM_Range			: integer := 10000
	);
	port (
		i_CLK				: in  std_logic;
		i_Qdiv				: in  std_logic								:= '1';
		i_VAL_x				: in  tSLV_Nx16(0 to g_NrOfPwm-1);
		o_PWM_x				: out std_logic_vector(g_NrOfPwm-1 downto 0)
	);
end;
--------------------------------------------------------------------------------

architecture impl of PWM_16Bit is

--------------------------------------------------------------------------------
	signal	Qdiv		: std_logic := '0';
	signal	PwmCnt		: std_logic_vector(15 downto 0) := x"0000";
	signal	PWM_Range		: std_logic_vector(15 downto 0);
	signal	PwmStart	: std_logic := '0';

--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';

--------------------------------------------------------------------------------
begin -- of architecture PWM_16Bit
--------------------------------------------------------------------------------

	PWM_Range <= std_logic_vector(to_unsigned(g_PWM_Range,16));

--------------------------------------------------------------------------------
--	PWM percent counter 0..xxx
--------------------------------------------------------------------------------
	process (PwmCnt) begin

			if (PwmCnt >= PWM_Range) then	-- or restart if 100% reached
				PwmStart <= H;
			else
				PwmStart <= L;
			end if;

	end process;

	process (i_CLK,i_Qdiv) begin
		if rising_edge(i_CLK) and i_Qdiv=H then

			if (PwmStart = H) then
				PwmCnt <= x"0000";	-- restart PWM
			else
				PwmCnt <= PwmCnt + 1;
			end if;

		end if;
	end process;

--------------------------------------------------------------------------------
--	PWM 0..4096
--------------------------------------------------------------------------------
inst_PWM_Comp:  for i in 0 to g_NrOfPWM-1 generate begin

	process (i_CLK,i_Qdiv) begin
		if rising_edge(i_CLK) and i_Qdiv=H then
			o_PWM_x(i) <= L;
			if (PwmCnt < i_VAL_x(i)) then
				o_PWM_x(i) <= H;
			end if;
		end if;
	end process;

end generate;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
