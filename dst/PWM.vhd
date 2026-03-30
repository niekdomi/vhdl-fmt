--------------------------------------------------------------------------------
--  PWM
--------------------------------------------------------------------------------
--
--  project     : PWM
--  programmer  : C. LEuthold, INDEL AG
--  date        :
--  version     : 1.00
--  language    : VHDL
--  system      :
--
--  purpose     : 1-PH PWM-component
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00a  :   07.09.2004-le  : - disc.
--  Rev. 1.00b  :   06.10.2004-le  : deattim min. calc move to top
--  Rev. 1.00e	:   25.07.2005-le  : -  C_DT_CNT_LENGTH = 0 -> no deattime
--	11.05.2007-le	add svn keywords
--	12.07.2013-le	zero of pwm do not work after stop.
--					dt <= dead_time at stop
--	28.11.2013-le	add a clockenabel
--	24.12.2014-le	add o_switchpoint. is H when pwm edge switch
--------------------------------------------------------------------------------
--$Rev:: 3704                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2014-12-24 14:28:26 +0100 (Mi., 24 Dez 2014)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity PWM is
	generic (
		C_PWM_CNT_LENGTH 	: integer := 16;
		C_DT_CNT_LENGTH 	: integer := 8
	);
	port (
		i_Clk       : in    std_logic;                  -- clock input
		i_clken		: in	std_logic := '1';-- clocken input
		i_Reset     : in    std_logic;                  -- reset input H-active
		-- config inputs
		i_dead_time	: in	std_logic_vector(C_DT_CNT_LENGTH downto 0) := (others => '0'); -- dead time of bridge
		-- actual PwmCnt value
		i_PwmCnt	: in	std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0);-- PwmCnt
		-- PWM controll
		i_Stop		: in	std_logic := '0';					-- extern IGBT-Disable
		i_PWM_val	: in	std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0);
		o_switchpoint: out	std_logic; 
		-- IGBT outputs
		o_a 		: out	std_logic;              	 -- IGBT-output
		o_b			: out	std_logic

	);
end;                                                    -- of entity PWM

architecture behavior_PWM of PWM is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
	constant H          : std_logic := '1';
	constant L          : std_logic := '0';
	constant Z          : std_logic := 'Z';

-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal clk			: std_logic;
	signal rst 			: std_logic;
	signal dt			: std_logic_vector(C_DT_CNT_LENGTH-1 downto 0):=(others => L);
	signal dead_time    : std_logic_vector(C_DT_CNT_LENGTH-1 downto 0):=(others => L);
	signal cmp			: std_logic := L;
	signal cmp_old		: std_logic := L;
	signal a			: std_logic := L;
	signal b			: std_logic := L;

-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin                                                   -- of architecture PWM

	o_a <= a;
	o_b	<= b;
	clk <= i_Clk;
	rst <= i_Reset;

	comp1 : process(i_PwmCnt, i_PWM_val, rst)
	begin
		if rst = '1' then
			cmp <= L;
		elsif i_PwmCnt<i_PWM_val then
			cmp <= H;
		else
			cmp <= L;
		end if;
	end process;
	
	switchpoint : process (rst, clk)
	begin
		if (rst = '1') then
			cmp_old <= L;
			o_switchpoint <= L;
		elsif rising_edge(clk) then
			if i_clken=H then
				o_switchpoint <= L;
				cmp_old <= cmp;
				if (cmp/=cmp_old) then
					o_switchpoint <= H;
				end if;
			end if;
		end if;
	end process;
	

with_deadtime : if C_DT_CNT_LENGTH>0 generate
--------------------------------------------------------------------------------
--	Tod-Zeit
--------------------------------------------------------------------------------
begin
	dead_time <= i_dead_time(dead_time'range);
	TodZ : process (rst, clk)
	begin
		if (rst = '1') then
			dt <= (others => L);
			--cmp_old <= L;
		elsif rising_edge(clk) then
			if i_clken=H then
				-- cmp       ___--------___
				-- cmp_old   ____--------___
				-- load dt   ___-_______-___
				-- dt
				if (i_Stop=L) then
					if (dt=0) then
						if (cmp/=cmp_old) then
							dt <= dead_time;
						end if;
					else
						dt <= dt - 1;
					end if;
				else
					dt <= dead_time;
				end if;
				--cmp_old <= cmp;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
-- Output's
--------------------------------------------------------------------------------
-- cmp		______________----------------________________
-- dt		0000000000000003210000000000000321000000000000
-- a		__________________-------------_______________
-- b		---------------___________________------------
--------------------------------------------------------------------------------
	Outputs_dt: process (rst, clk) begin
		if (rst = '1') then
		-- asynch reset statements
			a		<= L;
			b		<= L;
		elsif rising_edge(clk) then
			if i_clken=H then
			-- clocked statements
				if (i_Stop=L) then
					-- a
					if    (b=L) and (dt=1) and (cmp=H) then a <=H;-- on after dt
					elsif (b=L) and (a =H) and (cmp=H) then a <=H;-- hold
					else a <= L;
					end if;
					-- b
					if    (a=L) and (dt=1) and (cmp=L) then b <=H;-- on after dt
					elsif (a=L) and (b =H) and (cmp=L) then b <=H;-- hold
					else b <= L;
					end if;
				else
					a <= L;
					b <= L;
				end if;
			end if;
		end if;
	end process;
end generate with_deadtime;

without_deadtime : if C_DT_CNT_LENGTH=0 generate
--------------------------------------------------------------------------------
-- Output's
--------------------------------------------------------------------------------
-- cmp		______________----------------________________
-- a		_______________----------------_______________
-- b		---------------________________------------
--------------------------------------------------------------------------------
	Outputs_ndt: process (rst, clk) begin
		if (rst = '1') then
		-- asynch reset statements
			a		<= L;
			b		<= L;
		elsif rising_edge(clk) then
			if i_clken=H then
			-- clocked statements
				if (i_Stop=L) then
					a <= cmp;
					b <= not cmp;
				else
					a <= L;
					b <= L;
				end if;
			end if;
		end if;
	end process;
end generate without_deadtime;

end behavior_PWM;                                  -- END of architecture PWM
--------------------------------------------------------------------------------

