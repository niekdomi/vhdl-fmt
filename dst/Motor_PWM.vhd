--------------------------------------------------------------------------------
--	Motor_PWM
--------------------------------------------------------------------------------
--
--	project		: Motor_PWM
--	programmer	: C. Leuthold, INDEL AG
--	date		:
--	version		: 1.00
--	language	: VHDL
--	system		:
--
--	purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00	:	07.09.2004-le : - disc.
--  Rev. 1.00e	:	21.04.2005-le : - adjustment for max4
--										new generics
--										C_NR_3PH_PWM : number of 3ph-pwm-units
--										new ports
--										i_Stop and PWM_OUTS(o_Ua..) -> vector C_NR_3PH_PWM-1..0
--										i_PWM_UVW -> vector C_NR_3PH_PWM*C_REG_LENGTH-1..0
--					25.07.2005-le : - C_DT_CNT_LENGTH = 0 -> no deadtime
--					25.07.2005-le : - new C_MIN_PULSE !!untested!!
--					28.07.2005-le : - add break pwm
--					16.09.2005-le : - add o_cPWM0, a triggerpulse at pwmcnt=0
--					04.10.2005-le : - add C_BREAK_PWM for enable / disable
--										break pwm
--					21.10.2005-le : - add output o_run
--	29.11.2006-le : add generic C_NO_INPUT_REGISTER: if 1 -> do not save i_PWM_x at pwm0
--					add generic C_ENABLE_OVERSAMPLING if 1 use input i_oversampling(2..0) for PWM oversampling 0..7
--	01.12.2006-le : add o_SinCycle for singen with half freq
--	22.05.2007-le : add
--------------------------------------------------------------------------------
--	01.03.2006-le:	lib adjustments for repository 
--	11.05.2007-le	add svn keywords
--	22.05.2007-le	add C_NUM_SINGEN for multiple sinGens (sac3x3):
--						out o_SinGenPWM as vector (C_NUM_SINGEN-1 downto 0),
--						data as i_dprData(C_NUM_SINGEN*C_SIN_CNT_LENGTH-1 downto 0)
--						in ram
--	29.04.2009-le	new single ram multi sinusgenerator with gain and phaseshift
--	24.07.2009-le	add 16bit signed value out for C_NEW_SINGEN
--	01.03.2010-le	add support half freq.
--	27.04.2010-le	correct pwm watchdog
--	29.04.2010-le	add o_cPWM180
--	16.07.2010-le	add a fourth pwm for ax42
--	22.07.2010-le	correct inputs for pwm x
--	18.12.2012-le	add i_shift(C_NR_3PH_PWM-1 downto 0) to shift a pwm_counter 
--						of a selected axis 180°
--	16.07.2013-le	add i_clearcnt to clear pwm counter
--	28.11.2013-le	add a clockenabel
--	22.09.2014-le	add C_SIN32KHZPLUS. switch between old stile "half freq" and 
--						32khz and more for the bit 0x8 in the factor nibble
--	04.12.2014-le	correct clear pwm counter when half freq is selected
--	24.12.2014-le	add o_switchpoint. is H when pwm edge switch
--	12.04.2018-le	add comparator convSt3
--------------------------------------------------------------------------------
--$Rev:: 4832                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-12 17:44:22 +0200 (Do., 12 Apr 2018)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

library SinusGenerator;
use SinusGenerator.all;

library PWM;
use PWM.PWM;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity Motor_PWM is
	generic (
		C_REG_LENGTH		: integer := 16;
		C_PWM_CNT_LENGTH	: integer := 14;
		C_DT_CNT_LENGTH 	: integer := 8;	-- if 0 -> no deattime
		C_DT_MIN			: integer := 128;
		C_SIN_CNT_LENGTH	: integer := 0;	-- if 0 -> no sin_gen
		C_NUM_SINGEN		: integer := 1;
		C_ADDR_LENGTH		: integer := 32;
		C_NR_3PH_PWM		: integer := 3;
		C_BREAK_PWM			: integer := 0;
		C_MIN_PULSE			: integer := 0;	-- if 0 -> no min pulse else min 1/2pulse must be > C_MIN_PULSE
		C_NO_INPUT_REGISTER : integer := 0;
		C_ENABLE_OVERSAMPLING : integer := 0;
		C_NEW_SINGEN : integer := 0;
		C_SIN32KHZPLUS : integer range 0 to 1 := 0
	);
	port (
		i_Clk		: in	std_logic;		-- clock input
		i_clken		: in	std_logic := '1';-- clocken input
		i_Reset		: in	std_logic;		-- reset input H-active
		-- Dualport Ram access
		o_dprEN		: OUT	std_logic;
		o_dprClk	: OUT	std_logic;
		o_dprRst	: OUT	std_logic;
		o_dprWEN	: OUT	std_logic_vector(3 downto 0);
		o_dprData	: out	STD_LOGIC_VECTOR(31 downto 0);
		i_dprData	: in	STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
		o_dprAddr	: OUT	std_logic_vector(C_ADDR_LENGTH-1 downto 0);	-- DP-RAM Adr
		-- interrupt
		o_INT		: out	std_logic;		-- int. rising-edge
		-- start of convert
		o_convSt	: out	std_logic;		-- pwmCnt=i_Conv_St and UP => o_convSt=H
		o_convSt2	: out	std_logic;		-- pwmCnt=i_Conv_St and UP => o_convSt=H
		o_convSt3	: out	std_logic;		-- pwmCnt=i_Conv_St and UP => o_convSt=H
		o_convSt180	: out	std_logic;		-- i_PWM_100-pwmCnt=i_Conv_St and DOWN => o_convSt180=H
		o_convSt2_180: out	std_logic;		-- i_PWM_100-pwmCnt=i_Conv_St and DOWN => o_convSt180=H
		o_cPWM0		: out	std_logic;		-- pwmCnt=0 => o_cPWM0=H
		o_cPWM180	: out	std_logic;
		o_PWM_cnt	: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		-- config inputs
		i_PWM_100	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- maximum of PwmCnt
		i_clearcnt  : in    std_logic := '0';
		i_PWM_INT	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- PwmCnt=i_PWM_INT activate IRQ
		i_dead_time	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- dead time of bridge
		i_index_val	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- ((SIN_TAB_LNG-1)*(2**C_SHIFT))/i_PWM_100
		i_SIN_phase	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- sin phase 0=0°/i_PWM_100=180°
		i_Conv_St	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- pwmCnt=i_Conv_St => o_convSt=H
		i_Conv_St2	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- pwmCnt=i_Conv_St => o_convSt=H
		i_Conv_St3	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');-- pwmCnt=i_Conv_St => o_convSt=H
		i_oversampling	: in	std_logic_vector(2 downto 0) := "001";
		
		i_half_freq	: in	std_logic := '0';
		o_PwmDown	: out	std_logic;
		-- 3PH-PWM controll
		i_Stop		: in	std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others => '0');		-- extern IGBT-Disable
		i_PWM_U		: in	std_logic_vector(C_NR_3PH_PWM*C_REG_LENGTH-1 downto 0) := (others => '0');
		i_PWM_V		: in	std_logic_vector(C_NR_3PH_PWM*C_REG_LENGTH-1 downto 0) := (others => '0');
		i_PWM_W		: in	std_logic_vector(C_NR_3PH_PWM*C_REG_LENGTH-1 downto 0) := (others => '0');
		i_PWM_X		: in	std_logic_vector(C_NR_3PH_PWM*C_REG_LENGTH-1 downto 0) := (others => '0');
		-- break pwm
		i_PWM_break	: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => '0');
		no_break	: out	std_logic;
		o_break		: out	std_logic;
		-- IGBT outputs invers
		no_Ua		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- U IGBT-output
		no_Ub		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		no_Va		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- V IGBT-output
		no_Vb		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		no_Wa		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- W IGBT-output
		no_Wb		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		no_Xa		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- X IGBT-output
		no_Xb		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		-- IGBT outputs
		o_Ua		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- U IGBT-output
		o_Ub		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		o_Va		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- V IGBT-output
		o_Vb		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		o_Wa		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- W IGBT-output
		o_Wb		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		o_Xa		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- X IGBT-output
		o_Xb		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		-- sinus geni
		o_SinPWM	: out	std_logic_vector(C_NUM_SINGEN-1 downto 0);
		no_SinPWM	: out	std_logic_vector(C_NUM_SINGEN-1 downto 0);
		o_SinVal	: out	std_logic_vector(C_NUM_SINGEN*16-1 downto 0); -- value out 16bit signed
		i_gain		: in	std_logic_vector(C_NUM_SINGEN*C_SIN_CNT_LENGTH-1 downto 0) := (others => '0');
		i_phase		: in	std_logic_vector(C_NUM_SINGEN*C_SIN_CNT_LENGTH-1 downto 0) := (others => '0');
		o_SinCycle	: out	std_logic;
		-- ppc watchdog
		o_PPC_Wdog	: out	std_logic;
		o_run		: out	std_logic;
		o_switchpoint_u		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- U IGBT-output
		o_switchpoint_v		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		o_switchpoint_w		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);	-- V IGBT-output
		o_switchpoint_x		: out	std_logic_vector(C_NR_3PH_PWM-1 downto 0);
		i_shift		: in	std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others => '0')
	);
end;														--of entity Motor_PWM

architecture behavior_Motor_PWM of Motor_PWM is
-- constants -------------------------------------------------------------------
	constant H		: std_logic := '1';
	constant L		: std_logic := '0';
	constant Z		: std_logic := 'Z';

-- types -----------------------------------------------------------------------
	type t_pwm_val is array(C_NR_3PH_PWM-1 downto 0) of std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0);
-- signals ---------------------------------------------------------------------
	signal clk			: std_logic;
	signal rst 			: std_logic;
	signal PwmCnt		: std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0) := (others =>L);
	signal PwmDblCnt	: std_logic_vector(C_PWM_CNT_LENGTH downto 0) := (others =>L);
	signal PwmCnt_mp	: std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0) := (others =>L);
	signal PwmCnt_max	: std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0) := (others =>L);
	signal PwmDown		: std_logic := L;
	signal PwmDblDown	: std_logic := L;
	signal PwmVal_U		: t_pwm_val := (others =>(others =>L));
	signal Ua			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal Ub			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal PwmVal_V		: t_pwm_val := (others =>(others =>L));
	signal Va			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal Vb			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal PwmVal_W		: t_pwm_val := (others =>(others =>L));
	signal Wa			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal Wb			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal PwmVal_X		: t_pwm_val := (others =>(others =>L));
	signal Xa			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal Xb			: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal StopPWM		: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others =>L);
	signal pwm_break	: std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0) := (others =>L);
	signal run			: std_logic :=L;
	signal SinGenPWM	: std_logic_vector(C_NUM_SINGEN-1 downto 0) := (others =>L);
	signal PWM_100		: std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0) := (others =>L);
	signal dead_time	: std_logic_vector(C_DT_CNT_LENGTH downto 0)  := (others => L);
	signal PPC_Wdog		: std_logic_vector(3 downto 0)  :=(others => H);
	signal PPC_Wdog_tgl	: std_logic := L;
	signal sin_sync		: std_logic := L;
	signal sinCycle		: std_logic := L;
	
	signal clearcntold   : std_logic := L;
	signal oversampling	: std_logic_vector(3 downto 0) := (others => L);
	
	signal shift		: std_logic_vector(C_NR_3PH_PWM-1 downto 0) := (others => L);
	signal half_freq	: std_logic := L;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin                                                   -- of architecture NAME
	clk <= i_Clk;
	rst <= i_Reset;
	o_SinPWM <= SinGenPWM;
	no_SinPWM <= not(SinGenPWM);
	o_SinCycle <= sinCycle;
	run <= L when PWM_100=0 else H;
	o_run <= run;
with_deadtime : if C_DT_CNT_LENGTH>0 generate
	dead_time <= L & i_dead_time(C_DT_CNT_LENGTH-1 downto 0) when
					i_dead_time(C_DT_CNT_LENGTH-1 downto 0) > C_DT_MIN else
					CONV_STD_LOGIC_VECTOR(C_DT_MIN,C_DT_CNT_LENGTH+1);
end generate with_deadtime;
--------------------------------------------------------------------------------
--	Up/Down Counter
--------------------------------------------------------------------------------
	o_PWM_cnt(C_PWM_CNT_LENGTH-1 downto 0) <= PwmCnt;
	o_PWM_cnt(C_REG_LENGTH-2 downto C_PWM_CNT_LENGTH) <= (others => L);
	o_PWM_cnt(C_REG_LENGTH-1) <= PwmDown;
	
	o_PwmDown <= PwmDblDown;
	
	no_input_reg : if C_NO_INPUT_REGISTER=1 generate
		PWM_100 <= i_PWM_100(C_PWM_CNT_LENGTH-1 downto 0);
		process (i_PWM_U, i_PWM_V, i_PWM_W) begin
			for i in C_NR_3PH_PWM-1 downto 0 loop
				PwmVal_U(i) <= i_PWM_U(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
				PwmVal_V(i) <= i_PWM_V(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
				PwmVal_W(i) <= i_PWM_W(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
				PwmVal_X(i) <= i_PWM_X(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
			end loop;
			pwm_break <= i_PWM_break(C_PWM_CNT_LENGTH-1 downto 0);
		end process;
	end generate no_input_reg;
	
	process(clk)
	begin
		if rising_edge(clk) then
			if i_clken=H then
				-- PWM counter
				o_cPWM180 <= L;
				clearcntold <= i_clearcnt;
				if (i_clearcnt=H and clearcntold=L ) then
					PwmCnt <=  (0 => H, others => L);
					PwmDown <= H;
				elsif (PwmCnt=0) then
					PwmCnt <= PwmCnt + 1;
					PwmDown <= L;
				elsif (PwmCnt>=PWM_100) then
					PwmCnt <= PwmCnt - 1;
					PwmDown <= H;
					o_cPWM180 <= H;
				elsif PwmDown=L then
					PwmCnt <= PwmCnt + 1;
				else --PwmDown=H
					PwmCnt <= PwmCnt - 1;
				end if;
				if (C_ENABLE_OVERSAMPLING=1) then
					-- PWM counter
					if (i_clearcnt=H and clearcntold=L ) then
						if (half_freq=L) then
							PwmDblCnt <=  (0 => H, others => L);
							PwmDblDown <= H;
						else
							if (PwmDown=H) then -- clear prior regular 0
								if (PwmDblDown=L) then
									PwmDblCnt <= (PWM_100 & L);
									PwmDblDown <= L;
								else
									PwmDblCnt <=  (0 => H, others => L);
									PwmDblDown <= H;
								end if;
							else -- clear after regular 0
								if (PwmDblDown=H) then
									PwmDblCnt <= (PWM_100 & L);
									PwmDblDown <= L;
								else
									PwmDblCnt <=  (0 => H, others => L);
									PwmDblDown <= H;
								end if;
							end if;
						end if;
					elsif (PwmDblCnt<oversampling and half_freq=L) then
						PwmDblCnt <= (others => L);
						PwmDblCnt(oversampling'range) <= oversampling;
						PwmDblDown <= L;
					elsif (PwmDblCnt>=(PWM_100 & L)) then
						PwmDblCnt <= PwmDblCnt - oversampling;
						PwmDblDown <= H;
					elsif PwmDblDown=L then
						PwmDblCnt <= PwmDblCnt + oversampling;
					else --PwmDown=H
						if (PwmDblCnt=0 and half_freq=H) then
							PwmDblCnt <= (others => L);
						else
							PwmDblCnt <= PwmDblCnt - oversampling;
						end if;
					end if;
				end if;
				
				-- Load
				o_cPWM0 <= L;
				if (C_NEW_SINGEN=1) then
					sin_sync <= L;
				end if;
				if (PwmCnt=1) and (PwmDown=H) then
					if C_NO_INPUT_REGISTER=0 then
						for i in C_NR_3PH_PWM-1 downto 0 loop
							PwmVal_U(i) <= i_PWM_U(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
							PwmVal_V(i) <= i_PWM_V(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
							PwmVal_W(i) <= i_PWM_W(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
							PwmVal_X(i) <= i_PWM_X(i*C_REG_LENGTH+C_PWM_CNT_LENGTH-1 downto i*C_REG_LENGTH);
						end loop;
						PWM_100 <= i_PWM_100(C_PWM_CNT_LENGTH-1 downto 0);
						pwm_break <= i_PWM_break(C_PWM_CNT_LENGTH-1 downto 0);
					end if;
					PPC_Wdog_tgl <= i_PWM_100(C_REG_LENGTH-1); -- save laste
					if (PPC_Wdog_tgl=i_PWM_100(C_REG_LENGTH-1)) then -- check toggle
						PPC_Wdog(0) <= H;
					else
						PPC_Wdog(0) <= L;
					end if;
					PPC_Wdog(3 downto 1) <= PPC_Wdog(2 downto 0); -- save wdogs errors
					o_cPWM0 <= H;
					if PwmDblDown=H or half_freq=L then
						PwmDblCnt <= (others => L);
						PwmDblDown <= L;
					end if;
					-- old-style half ferq: index(15), new-style index(11) 
					if ((i_index_val(C_REG_LENGTH-1-4*C_SIN32KHZPLUS)=H ) and (C_SIN_CNT_LENGTH>0)) then
						sinCycle <= not sinCycle;
					else
						sinCycle <= L;
					end if;
					if (C_NEW_SINGEN=1) then
						sin_sync <= not sinCycle;
					end if;
					if i_PWM_100(C_REG_LENGTH-1)=H then --save on wdog=1 to synch half frequency
						half_freq <= i_half_freq;
						shift <= i_shift;
						if (i_half_freq=L) then
							oversampling <= i_oversampling & L;
						else
							oversampling <= "0001";
						end if;
					end if;
				elsif run=L then
					if C_NO_INPUT_REGISTER=0 then
						PWM_100 <= i_PWM_100(C_PWM_CNT_LENGTH-1 downto 0);
					end if;
				end if;
				
				if (run=L) then
					o_PPC_Wdog <= H;
				elsif (PPC_Wdog="0000") then -- correct toggle
					o_PPC_Wdog <= L;
				elsif (PPC_Wdog="0001") then -- accept one wdog error
					o_PPC_Wdog <= L;
				elsif (PPC_Wdog="0011") then -- accept one wdog error
					o_PPC_Wdog <= L;
				elsif (PPC_Wdog="0110") then -- accept one wdog error
					o_PPC_Wdog <= L;
				elsif (PPC_Wdog="1100") then -- accept one wdog error
					o_PPC_Wdog <= L;
				elsif (PPC_Wdog="1000") then -- accept one wdog error
					o_PPC_Wdog <= L;
				else
					o_PPC_Wdog <= H;
				end if;
				-- reset statements
				if (rst = '1') then
					PwmDown <= L;
					PwmCnt <= (others => L);
					if C_NO_INPUT_REGISTER=0 then
						for i in C_NR_3PH_PWM-1 downto 0 loop
							PwmVal_U(i) <= (others => L);
							PwmVal_V(i) <= (others => L);
							PwmVal_W(i) <= (others => L);
							PwmVal_X(i) <= (others => L);
						end loop;
					end if;
					PwmDblCnt <= (others => L);
					o_PPC_Wdog <= H;
					o_cPWM0 <= L;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	interrupt
--------------------------------------------------------------------------------
	process ( clk)
	begin
		if rising_edge(clk) then
			if i_clken=H then
				-- o_INT edge triggerd
				if (PwmDown=i_PWM_INT(i_PWM_INT'high)) and (PwmCnt=i_PWM_INT(C_PWM_CNT_LENGTH-1 downto 0)) and (run=H) then
					o_INT <= H;
				else
					o_INT <= L;
				end if;
				-- reset statements
				if (rst = '1') then
					o_INT <= L;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	ADC Sample & HOLD ; Start Of Convert
--------------------------------------------------------------------------------
	ADCsh: process (clk)
	begin
		if rising_edge(clk) then
			if i_clken=H then
			-- clocked statements
				-- o_convSt
				if (PwmDown=i_Conv_St(i_Conv_St'high)) and (PwmCnt=(i_Conv_St(C_PWM_CNT_LENGTH-1 downto 0))) and (run=H) then
					o_convSt <= H;	-- center of deadtime
				else o_convSt <= L;
				end if;
				-- o_convSt180
				if (PwmDown/=i_Conv_St(i_Conv_St'high)) and (PwmCnt=(PWM_100-i_Conv_St(C_PWM_CNT_LENGTH-1 downto 0))) and (run=H) then
					o_convSt180 <= H;	-- +180°
				else o_convSt180 <= L;
				end if;
				-- o_convSt2
				if (PwmDown=i_Conv_St2(i_Conv_St2'high)) and (PwmCnt=(i_Conv_St2(C_PWM_CNT_LENGTH-1 downto 0))) and (run=H) then
					o_convSt2 <= H;	-- center of deadtime
				else o_convSt2 <= L;
				end if;
				-- o_convSt2
				if (PwmDown=i_Conv_St3(i_Conv_St3'high)) and (PwmCnt=(i_Conv_St3(C_PWM_CNT_LENGTH-1 downto 0))) and (run=H) then
					o_convSt3 <= H;	-- center of deadtime
				else o_convSt3 <= L;
				end if;
				-- o_convSt180
				if (PwmDown/=i_Conv_St2(i_Conv_St2'high)) and (PwmCnt=(PWM_100-i_Conv_St2(C_PWM_CNT_LENGTH-1 downto 0))) and (run=H) then
					o_convSt2_180 <= H;	-- +180°
				else o_convSt2_180 <= L;
				end if;
				if (C_SIN_CNT_LENGTH>0 and C_NEW_SINGEN=0) then
					-- sinGen sync
					if (PwmDown=i_SIN_phase(i_Conv_St'high)) and (PwmCnt=(i_SIN_phase(C_PWM_CNT_LENGTH-1 downto 0))) and (run=H) then
						sin_sync <= not sinCycle;
					else sin_sync <= L;
					end if;
				end if;
				-- reset statements
				if (rst = '1') then
					o_convSt <= L;
					o_convSt2 <= L;
					o_convSt3 <= L;
					o_convSt180 <= L;
					o_convSt2_180 <= L;
					--o_cPWM0 <= L;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	pwm inst.
--------------------------------------------------------------------------------
no_min_pulse : if C_MIN_PULSE=0 generate begin
	PwmCnt_mp <= PwmDblCnt(C_PWM_CNT_LENGTH downto 1) when (C_ENABLE_OVERSAMPLING=1) else PwmCnt;
end generate no_min_pulse;
min_pulse : if C_MIN_PULSE>0 generate begin
	PwmCnt_max <= PWM_100-CONV_STD_LOGIC_VECTOR(C_MIN_PULSE,C_PWM_CNT_LENGTH);
	process(clk)
	begin
		if rising_edge(clk) then
			if i_clken=H then
				if PwmDblCnt(C_PWM_CNT_LENGTH downto 1)<C_MIN_PULSE then
					PwmCnt_mp <= CONV_STD_LOGIC_VECTOR(C_MIN_PULSE,C_PWM_CNT_LENGTH);
				elsif PwmDblCnt(C_PWM_CNT_LENGTH downto 1)>PwmCnt_max then
					PwmCnt_mp <= PwmCnt_max;
				else
					if (C_ENABLE_OVERSAMPLING=1) then
						PwmCnt_mp <= PwmDblCnt(C_PWM_CNT_LENGTH downto 1);
					else
						PwmCnt_mp <= PwmCnt;
					end if;
				end if;
			end if;
		end if;
	end process;
end generate min_pulse;

	PWMs : for i in 0 to C_NR_3PH_PWM-1 generate
		signal lPwmCnt_mp	: std_logic_vector(C_PWM_CNT_LENGTH-1 downto 0) := (others =>L);
	begin
		

		no_Ua(i) <= not(Ua(i));
		no_Ub(i) <= not(Ub(i));
		no_Va(i) <= not(Va(i));
		no_Vb(i) <= not(Vb(i));
		no_Wa(i) <= not(Wa(i));
		no_Wb(i) <= not(Wb(i));
		no_Xa(i) <= not(Xa(i));
		no_Xb(i) <= not(Xb(i));
		
		o_Ua(i) <= Ua(i);
		o_Ub(i) <= Ub(i);
		o_Va(i) <= Va(i);
		o_Vb(i) <= Vb(i);
		o_Wa(i) <= Wa(i);
		o_Wb(i) <= Wb(i);
		o_Xa(i) <= Xa(i);
		o_Xb(i) <= Xb(i);
		
		process(shift,PWM_100,PwmCnt_mp)
		begin
			if (shift(i)=H) then
				if PWM_100>=PwmCnt_mp then
					lPwmCnt_mp <= PWM_100 - PwmCnt_mp;
				else 
					lPwmCnt_mp <= (others => L);
				end if;
			else
				lPwmCnt_mp <= PwmCnt_mp;
			end if;
		end process;
		
		StopPWM(i) <= i_Stop(i) or not(run);
		
		pwm_u : entity PWM.PWM
		generic map (
			C_PWM_CNT_LENGTH	=> C_PWM_CNT_LENGTH,
			C_DT_CNT_LENGTH		=> C_DT_CNT_LENGTH
		)
		port map(
			i_Clk				=> clk,			--: in	std_logic;					-- clock input
			i_clken				=> i_clken,
			i_Reset				=> rst,			--: in	std_logic;					-- reset input H-active
			i_dead_time			=> dead_time,	--: in	std_logic_vector(C_DT_CNT_LENGTH downto 0); -- dead time of bridge
			i_PwmCnt			=> lPwmCnt_mp,	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);-- PwmCnt
			i_Stop				=> StopPWM(i),	--: in	std_logic;					-- extern IGBT-Disable
			i_PWM_val			=> PwmVal_U(i),	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);
			o_switchpoint		=> o_switchpoint_u(i),
			o_a					=> Ua(i),		--: out	std_logic;					-- IGBT-output
			o_b					=> Ub(i)		--: out	std_logic
		);

		pwm_v : entity PWM.PWM
		generic map (
			C_PWM_CNT_LENGTH	=> C_PWM_CNT_LENGTH,
			C_DT_CNT_LENGTH		=> C_DT_CNT_LENGTH
		)
		port map(
			i_Clk				=> clk,			--: in	std_logic;					-- clock input
			i_clken				=> i_clken,
			i_Reset				=> rst,			--: in	std_logic;					-- reset input H-active
			i_dead_time			=> dead_time,	--: in	std_logic_vector(C_DT_CNT_LENGTH downto 0); -- dead time of bridge
			i_PwmCnt			=> lPwmCnt_mp,	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);-- PwmCnt
			i_Stop				=> StopPWM(i),	--: in	std_logic;					-- extern IGBT-Disable
			i_PWM_val			=> PwmVal_V(i),	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);
			o_switchpoint		=> o_switchpoint_v(i),
			o_a 				=> Va(i),		--: out	std_logic;					-- IGBT-output
			o_b					=> Vb(i)		--: out	std_logic
		);

		pwm_w : entity PWM.PWM
		generic map (
			C_PWM_CNT_LENGTH	=> C_PWM_CNT_LENGTH,
			C_DT_CNT_LENGTH		=> C_DT_CNT_LENGTH
		)
		port map(
			i_Clk				=> clk,			--: in	std_logic;					-- clock input
			i_clken				=> i_clken,
			i_Reset				=> rst,			--: in	std_logic;					-- reset input H-active
			i_dead_time			=> dead_time,	--: in	std_logic_vector(C_DT_CNT_LENGTH downto 0); -- dead time of bridge
			i_PwmCnt			=> lPwmCnt_mp,	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);-- PwmCnt
			i_Stop				=> StopPWM(i),	--: in	std_logic;					-- extern IGBT-Disable
			i_PWM_val			=> PwmVal_W(i),	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);
			o_switchpoint		=> o_switchpoint_w(i),
			o_a 				=> Wa(i),		--: out	std_logic;					-- IGBT-output
			o_b					=> Wb(i)		--: out	std_logic
		);
		
		pwm_x : entity PWM.PWM
		generic map (
			C_PWM_CNT_LENGTH	=> C_PWM_CNT_LENGTH,
			C_DT_CNT_LENGTH		=> C_DT_CNT_LENGTH
		)
		port map(
			i_Clk				=> clk,			--: in	std_logic;					-- clock input
			i_clken				=> i_clken,
			i_Reset				=> rst,			--: in	std_logic;					-- reset input H-active
			i_dead_time			=> dead_time,	--: in	std_logic_vector(C_DT_CNT_LENGTH downto 0); -- dead time of bridge
			i_PwmCnt			=> lPwmCnt_mp,	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);-- PwmCnt
			i_Stop				=> StopPWM(i),	--: in	std_logic;					-- extern IGBT-Disable
			i_PWM_val			=> PwmVal_X(i),	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);
			o_switchpoint		=> o_switchpoint_x(i),
			o_a 				=> Xa(i),		--: out	std_logic;					-- IGBT-output
			o_b					=> Xb(i)		--: out	std_logic
		);
	end generate PWMs;
	
	breakPWM : if C_BREAK_PWM=1 generate begin
	pwm_b : entity PWM.PWM
	generic map (
		C_PWM_CNT_LENGTH 	=> C_PWM_CNT_LENGTH,
		C_DT_CNT_LENGTH  	=> 0
	)
	port map(
		i_Clk				=> clk,			--: in	std_logic;					-- clock input
		i_clken				=> i_clken,
		i_Reset				=> rst,			--: in	std_logic;					-- reset input H-active
		i_PwmCnt			=> PwmCnt_mp,	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);-- PwmCnt
		i_PWM_val			=> pwm_break,	--: in	std_logic_vector(C_PWM_CNT_LENGTH downto 0);
		o_a 				=> o_break,		--: out	std_logic;					-- IGBT-output
		o_b					=> no_break		--: out	std_logic
	);
	end generate breakPWM;
--------------------------------------------------------------------------------
--	sinus geni inst.
--------------------------------------------------------------------------------

	sinus_generator : if C_SIN_CNT_LENGTH>0 generate
	begin
	
		sinus : entity SinusGenerator.SinGen
		generic map (
			C_SIN_CNT_LENGTH	=> C_SIN_CNT_LENGTH,
			C_FAKT_LENGTH		=> 3+C_SIN32KHZPLUS,
			C_NUM_SINGEN		=> C_NUM_SINGEN,
			C_ADDR_LENGTH		=> C_ADDR_LENGTH,
			C_NEW_SINGEN		=> C_NEW_SINGEN
		)
		PORT MAP(
			i_Clk			=> clk,
			i_clken			=> i_clken,
			i_Reset			=> rst,
			o_dprEN			=> o_dprEN,
			o_dprClk		=> o_dprClk,
			o_dprRst		=> o_dprRst,
			o_dprWEN		=> o_dprWEN,
			o_dprData		=> o_dprData,
			i_dprData		=> i_dprData,
			o_dprAddr		=> o_dprAddr,
			i_PWMcntMax		=> i_index_val(C_SIN_CNT_LENGTH-1 downto 0),
			i_Faktor		=> i_index_val(C_REG_LENGTH-2+C_SIN32KHZPLUS downto C_REG_LENGTH-4),
			i_sync			=> sin_sync,
			o_SinGenPWM		=> SinGenPWM,
			i_gain			=> i_gain,
			i_phase			=> i_phase,
			o_SinVal		=> o_SinVal
		);
		
	end generate sinus_generator;
	
end behavior_Motor_PWM;
--------------------------------------------------------------------------------

