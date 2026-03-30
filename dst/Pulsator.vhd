---------------------------------------------------------------------------
--
--  Dispenster Puls Generator
--
---------------------------------------------------------------------------
--
--  project     : Pulsator
--  programmer  : F:Baschung, INDEL AG
--  date        : 02.11.2008
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose  
--  	- generate n pulses with t lenght and f freq
--
---------------------------------------------------------------------------
--	Forderungen:
--
--	AUS         	Pulse_n = 0	
--	n Pulse 		Pulse_n = n			Freq_t = 1/f		Pulse_t = t	
--	endlos Pulse 	Pulse_n = FFFF		Freq_t = 1/f		Pulse_t = t	
--	endlos EIN  	Pulse_n = FFFF		Freq_t = xxxx		Pulse_t = FFFF	
--
--	Puls Kontroll-Zähler
---------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	02.11.2008-fb : - create
--	06.11.2008-le : - add svn keywords
--					- add generics for vectorsize of Timers and Counters
--	28.01.2008-le : - correct size of FreqScaler
--	10.02.2008-le : - add endless pules counter
--					- add i_enable
--	27.10.2010-le : - add generic C_EXT_1MHZPRESCAL and input i_PS1MHz for
--						extern prescaler
--	31.05.2011-le : - redesigned to correct very small pulse errors (~1..3us)
--	31.05.2011-ms :	- add PulseCnt_l variable to avoid PulseCnt singal delay
--------------------------------------------------------------------------------
--$Rev:: 1957                                                                  $
--$Author:: suter                                                              $
--$Date:: 2011-05-31 16:46:27 +0200 (Di., 31 Mai 2011)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity Pulsator is 
	generic (
		g_iClk_kHz : integer := 100000;
		C_CNT_BITS : integer := 16;
		C_TIME_BITS : integer := 16;
		C_EXT_1MHZPRESCAL : integer range 0 to 1  := 0
   );
	port (
		i_CLK			: in  std_logic;
		i_PS1MHz		: in  std_logic := L;
		i_enable		: in  std_logic;
		i_Freq_t		: in  std_logic_vector(C_TIME_BITS-1 downto 0);
		i_Pulse_t		: in  std_logic_vector(C_TIME_BITS-1 downto 0);
		i_Pulse_n		: in  std_logic_vector(C_CNT_BITS-1 downto 0);
		o_EndlessCnt	: out std_logic_vector(C_CNT_BITS-1 downto 0);
		o_PulseCnt 		: out std_logic_vector(C_CNT_BITS-1 downto 0);
		o_Pulse			: out std_logic
    );
end;    

architecture impl of Pulsator is
--------------------------------------------------------------------------------
--	Configuration
--------------------------------------------------------------------------------
--	Der Prescaler muss aus i_Clk 1MHz machen
	constant	t_1MHz		: integer := (g_iClk_kHz/1000)-1;
	constant DF_CONT : std_logic_vector(C_CNT_BITS-1 downto 0) := (others => H);
	constant DF_ON : std_logic_vector(C_TIME_BITS-1 downto 0) := (others => H);
--------------------------------------------------------------------------------
	signal	Prescaler	: std_logic_vector(pkg_log2(t_1MHz)-1 downto 0) := (others => L);
	signal	Q1MHz		: std_logic := L;

	signal	from_disable: std_logic := L;
	signal	done		: std_logic := L;

	signal	FreqScaler	: std_logic_vector(C_TIME_BITS-1 downto 0) := (others => L);
		
	signal	PulseCnt	: std_logic_vector(C_CNT_BITS-1 downto 0) := (others => L);
	signal	EndlessCnt	: std_logic_vector(C_CNT_BITS-1 downto 0) := (others => L);

	signal	LastPulse	: std_logic := L;
	signal	PulseOut	: std_logic := L;
--------------------------------------------------------------------------------
begin -- of architecture Pulsator
--------------------------------------------------------------------------------
	o_PulseCnt <= PulseCnt;
	o_EndlessCnt <= EndlessCnt;
	o_Pulse <= PulseOut;
--------------------------------------------------------------------------------
--	1MHz puls
--------------------------------------------------------------------------------
int_prescale : if C_EXT_1MHZPRESCAL=0 generate
begin
	process (i_CLK) begin
		if rising_edge(i_CLK) then 
			if (Prescaler >= t_1MHz) then
				Q1MHz <= H;
				Prescaler <= (others => L);
			else
				Q1MHz <= L;
				Prescaler <= Prescaler + 1;
			end if; 
			
		end if;	
	end process;
end generate int_prescale;

ext_prescale : if C_EXT_1MHZPRESCAL/=0 generate
begin
	Q1MHz <= i_PS1MHz;
end generate ext_prescale;

--------------------------------------------------------------------------------
--	Enable / Disable 
--------------------------------------------------------------------------------
	process (i_CLK) 
	variable PulseCnt_l :std_logic_vector(PulseCnt'range);
	begin
		if rising_edge(i_CLK) then
			if Q1MHz=H then
				-- pulse cnt
				LastPulse <= PulseOut;
				
				if (i_Pulse_n/=0 and i_enable=H and from_disable=H) then
					-- clear after reenable
					PulseCnt_l := (others => L);
				else
					PulseCnt_l := PulseCnt;
					if (LastPulse /= PulseOut) then
						if (PulseOut = L) then
							PulseCnt_l := PulseCnt + 1;
						end if;
					end if;
				end if;
				PulseCnt <= PulseCnt_l;
				if (LastPulse /= PulseOut) then
					if (PulseOut = L) then
						EndlessCnt <= EndlessCnt + 1;
					end if;
				end if;
				-- start when number of pulse > 0, for restart write 0 and then the number of pulse
				if (i_Pulse_n=0 or i_enable=L) then
					FreqScaler <= (others => L);
					FreqScaler(0) <= H;
					from_disable <= H;
					PulseOut <= L;
					done <= L;
				else
					if from_disable=H then
						from_disable <= L;
						PulseOut <= L;
					else
						-- freq
						if (FreqScaler >= i_Freq_t) then
							FreqScaler <= (others => L);
							FreqScaler(0) <= H;
						else
							FreqScaler <= FreqScaler + 1;
						end if;
						-- pulse
						if ((i_Pulse_n=DF_CONT) or (PulseCnt_l<i_Pulse_n)) and done=L then
							if (i_Pulse_t = DF_ON) then
								-- always on
								PulseOut <= H;
							elsif (FreqScaler <= i_Pulse_t) then
								-- pwm on time
								PulseOut <= H;
							else
								PulseOut <= L;
							end if;
						else
							done <= H;
							PulseOut <= L;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
