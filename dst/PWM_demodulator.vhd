--------------------------------------------------------------------------------
--  PWM_demodulator
--------------------------------------------------------------------------------
--
--  project     : INFO-SAC2
--  programmer  : Christof Leuthold, INDEL AG
--  date        : 09.05.2005
--  version     : 1.00
--  language    : VHDL
--  system      : ispLever 3.0
--
--  purpose
--  	PWM_demodulator:
--		measuring PWM period and the on-time of PWM
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	Rev. 1.00a  :   09.05.2005-le:
--	29.05.2006-le	add save_overrun <= L to reset
--	27.11.2006-le	add generic C_COUNT_POS_nNEG: reset pwm periodcounter and save PWM100 and PWMHigh with 1: rising edge / 0: falling edge
--					add generic C_COUNT_POS_nNEG: count 1: pos / 0: neg pulse for PWMHigh
--					add i_reser_counter: if unconnected or H, reset all periods, if a H-pulsel, reset at next period
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 5263                                                                  $
--$Author:: leuthold_wg                                                        $
--$Date:: 2019-03-19 18:22:28 +0100 (Di., 19 MÃ¤r 2019)                        $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.ALL;

library UNISIM;
use UNISIM.VComponents.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity PWM_demodulator is
	generic (
		C_BIT_RES	: integer := 12;
		C_REG_LNG	: integer := 16;
		C_POS_nNEG_PWMSTART : integer := 0; -- reset pwm periodcounter and save PWM100 and PWMHigh with 1: rising edge / 0: falling edge
		C_COUNT_POS_nNEG : integer := 1; -- count 1: pos / 0: neg pulse for PWMHigh
		C_CNT_OVERRUN_IN_PWM100 : integer := 1;
		C_ChipScope_Implemented : integer := 0
	);
	port (
		i_Clk       : in    std_logic;					-- clock input
		i_Reset    	: in    std_logic;					-- reset input H-active
		--PWM_demodulator Pins
		i_PWM		: in	std_logic;
		-- interface
		o_overrun	: out 	std_logic;
		o_PWM100    : out	std_logic_vector(C_REG_LNG-1 downto 0);
		o_PWMHigh	: out	std_logic_vector(C_REG_LNG-1 downto 0);
		i_reser_counter : in std_logic := '1';
		o_NewVal	: out	std_logic
	);
end; -- of entity PWM_demodulator

architecture behavior_PWM_demodulator of PWM_demodulator is
-- component declarations ------------------------------------------------------
	component FD is
	port (Q : out std_logic;
		  C : in  std_logic;
		  D : in  std_logic);
	end component FD;
	-------------------------------------------------------------------
	--
	--  ILA core component declaration
	--
	-------------------------------------------------------------------
	component ila_sd_2048
		port
		(
			control     : in    std_logic_vector(35 downto 0);
			clk         : in    std_logic;
			trig0       : in    std_logic_vector(30 downto 0)
		);
	end component;
	-------------------------------------------------------------------
	--
	--  ICON core component declaration
	--
	-------------------------------------------------------------------
	component icon_sd_c
		port
		(
			control0    :   inout std_logic_vector(35 downto 0)
		);
	end component;

-- constants -------------------------------------------------------------------
	constant H          : std_logic := '1';
	constant L          : std_logic := '0';
	constant Z          : std_logic := 'Z';
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal PWMHigh		: std_logic_vector(C_BIT_RES-1 downto 0) := (others => L);
	signal PWM100		: std_logic_vector(C_BIT_RES-1 downto 0) := (others => L);
	signal cnt_periode	: std_logic_vector(C_BIT_RES-1 downto 0) := CONV_STD_LOGIC_VECTOR(1,C_BIT_RES);
	signal cnt_pulse	: std_logic_vector(C_BIT_RES-1 downto 0) := CONV_STD_LOGIC_VECTOR(1,C_BIT_RES);
	signal sPWM			: std_logic;
	signal sPWMPre		: std_logic;
	signal sPWMold		: std_logic := L;
	signal save_overrun	: std_logic := L;
	signal overrun		: std_logic := L;
	signal risingedge	: std_logic;
	signal fallingedge	: std_logic;
	signal reser_counter : std_logic;
	-------------------------------------------------------------------
	--
	--  ILA core signal declarations
	--
	-------------------------------------------------------------------
	signal control    	: std_logic_vector(35 downto 0);
	signal trig0      	: std_logic_vector(30 downto 0);
	signal cs_clk	  	: std_logic := L;
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin -- of architecture PWM_demodulator
	CNT_OVERRUN_IN_PWM100 : if C_CNT_OVERRUN_IN_PWM100=1 generate
	begin
		o_PWM100(C_REG_LNG-2 downto C_BIT_RES) <= (others => L);
		o_PWM100(C_REG_LNG-1) <= save_overrun or overrun;
	end generate CNT_OVERRUN_IN_PWM100;
	NO_CNT_OVERRUN_IN_PWM100 : if C_CNT_OVERRUN_IN_PWM100=0 generate
	begin
		o_PWM100(C_REG_LNG-1 downto C_BIT_RES) <= (others => L);
	end generate NO_CNT_OVERRUN_IN_PWM100;

	o_PWMHigh(C_REG_LNG-1 downto C_BIT_RES) <= (others => L);
	o_PWM100(C_BIT_RES-1 downto 0) <= PWM100;
	o_PWMHigh(C_BIT_RES-1 downto 0) <= PWMHigh;
	o_overrun <= save_overrun or overrun;

-- synchronisation -------------------------------------------------------------
	dat_ff1 : FD
	port map
	(
		Q => sPWMPre,
		C => i_Clk,
		D => i_PWM
	);
	dat_ff2 : FD
	port map
	(
		Q => sPWM,
		C => i_Clk,
		D => sPWMPre
	);

-- processes -------------------------------------------------------------------
	risingedge <= H when sPWMold=L and sPWM=H else L;
	fallingedge <= H when sPWMold=H and sPWM=L else L;
	
	process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
			PWM100 <= (others => L);
			PWMHigh <= (others => L);
			cnt_periode <= CONV_STD_LOGIC_VECTOR(1,C_BIT_RES);
			cnt_pulse <= CONV_STD_LOGIC_VECTOR(1,C_BIT_RES);
			sPWMold <= L;
			overrun <= L;
			save_overrun <= L;
		elsif rising_edge(i_Clk) then
		-- clocked statements
			o_NewVal <= L;
			sPWMold <= sPWM;
			reser_counter <= i_reser_counter or reser_counter;
			if (((C_POS_nNEG_PWMSTART=1 and risingedge=H) or (C_POS_nNEG_PWMSTART=0 and fallingedge=H))) then -- _- or -_ of sPWM
				if (reser_counter=H) then
					-- reset cnt with init-value
					cnt_periode <= CONV_STD_LOGIC_VECTOR(1,C_BIT_RES);
					cnt_pulse <= CONV_STD_LOGIC_VECTOR(1,C_BIT_RES);
					save_overrun <= overrun;
					overrun <= L;
					reser_counter <= L;--i_reser_counter; --reset
				end if;
				PWM100 <= cnt_periode;
				PWMHigh <= cnt_pulse;
				o_NewVal <= H;
			else
				cnt_periode <= cnt_periode + 1;
				if ((C_COUNT_POS_nNEG=1 and sPWM=H) or (C_COUNT_POS_nNEG=0 and sPWM=L)) then
					cnt_pulse <= cnt_pulse + 1;
				end if;
			end if;
			if (cnt_periode=0) then
				overrun <= H;
			end if;
		end if;
	end process;

-- debug -----------------------------------------------------------------------
	cs_imp_inst: if C_ChipScope_Implemented=1 generate
	begin
		trig0(C_BIT_RES*2+1 downto 0) <= sPWM & save_overrun & PWM100 & PWMHigh;
		trig0(trig0'high downto C_BIT_RES*2+2) <= (others => L);
		cs_clk <= i_Clk;
		------------------------------------------------------------------------
		--
		--  ILA core instance
		--
		------------------------------------------------------------------------
		i_ila : ila_sd_2048
		port map
		(
			control   => control,
			clk       => cs_clk,
			trig0     => trig0
		);
		------------------------------------------------------------------------
		--
		--  ICON core instance
		--
		------------------------------------------------------------------------
		i_icon : icon_sd_c
		port map
		(
			control0    => control
		);
	end generate cs_imp_inst;

end behavior_PWM_demodulator; -- END of architecture PWM_demodulator
--------------------------------------------------------------------------------

