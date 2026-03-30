--------------------------------------------------------------------------------
--
-- LED PWM_Flasher
--
--------------------------------------------------------------------------------
--
--	project		: LED_PWM_Flasher
--	programmer	: F:Baschung, INDEL AG
--	date		: 04.09.2008
--	language	: VHDL
--	system		: Project Navigator
--
--	purpose
--		- LED PWM and/or Flasher
--
--------------------------------------------------------------------------------
--	if NrOfPeriods(11) = H then always LED_PWM on
--	if Percent(7) = H then invers LED_output
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	04.09.2008-FB - erste Version
--	06.01.2009-le - add svn keywords
--	02.02.2012-le - add generic for external prescaler
--	09.12.2012-FB - 4-Bit FlashCounter added
--	08.06.2018-le - unwanted Flash, if increase the NrOfPeriods
--					Flash puls: compare CycleCnt and NrOfPeriods only when triggered
--------------------------------------------------------------------------------
--$Rev:: 4915                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-06-08 10:18:24 +0200 (Fr., 08 Jun 2018)                         $
--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity LED_PWM_Flasher is
	generic (
		g_iClk_kHz 	: integer := 100000;
		C_EXT_2MHZPRESCAL : integer range 0 to 1  := 0
	);
	port (
		i_CLK			: in  std_logic;
		i_PS2MHz		: in  std_logic;
		i_Trigger		: in  std_logic;
		i_NrOfPeriods	: in  std_logic_vector(11 downto 0);

		i_Percent_x1	: in  std_logic_vector( 7 downto 0);
		i_Percent_x2	: in  std_logic_vector( 7 downto 0);

		o_FlashRun		: out std_logic;
		o_FlashCnt		: out std_logic_vector( 3 downto 0);
		o_Flash 		: out std_logic;
		o_LED_x1		: out std_logic;
		o_LED_x2		: out std_logic
	);
end;

architecture impl of LED_PWM_Flasher is

--------------------------------------------------------------------------------
	signal	Prescaler	: std_logic_vector( 5 downto 0) := "000000";
	signal	Q2MHz		: std_logic := '0';
	signal	Trigger_t1	: std_logic := '0';
	signal	Trigger_t2	: std_logic := '0';
	signal	Trigger		: std_logic := '0';

	signal	PwmCnt		: std_logic_vector( 6 downto 0) := "0000000";
	signal	PwmStart	: std_logic := '0';
	signal	CycleCnt	: std_logic_vector(10 downto 0) := "00000000000";

	signal	Flash		: std_logic := '0';
	signal	Flash_t1	: std_logic := '0';

	signal	FlashRunCnt	: std_logic_vector(4 downto 0) := "00000";
	signal	FlashRun	: std_logic := '0';

	signal	FlashCnt	: std_logic_vector(3 downto 0) := (others => '0');

--------------------------------------------------------------------------------
--	Configuration
--------------------------------------------------------------------------------
--	Der LED-PWM soll mit 20kHz laufen und 0..100% ansteuerbar sein.
--	Der Prescaler muss also aus i_Clk 2MHz machen
	constant	t_2MHz	: integer := (g_iClk_kHz/2000)-1;

--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';


--------------------------------------------------------------------------------
begin -- of architecture LED_PWM_Flasher
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	2MHz puls
--------------------------------------------------------------------------------
	int_prescale : if C_EXT_2MHZPRESCAL=0 generate
	begin
		process (i_CLK) begin
			if rising_edge(i_CLK) then
	
				if (Prescaler >= t_2MHz) then
					Q2MHz <= H;
					Prescaler <= "000000";
				else
					Q2MHz <= L;
					Prescaler <= Prescaler + 1;
				end if;
	
			end if;
		end process;
	end generate int_prescale;
	

	ext_prescale : if C_EXT_2MHZPRESCAL/=0 generate
	begin
		Q2MHz <= i_PS2MHz;
	end generate ext_prescale;
	

--------------------------------------------------------------------------------
--	Trigger puls
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) and Q2MHz=H then

			Trigger_t1 <= i_Trigger;
			Trigger_t2 <= Trigger_t1;

		end if;
	end process;

	process (Trigger_t1,Trigger_t2) begin

		if ((Trigger_t1 = H) and (Trigger_t2 = L)) then
			Trigger <= H;
		else
			Trigger <= L;
		end if;

	end process;

--------------------------------------------------------------------------------
--	PWM percent counter 0..99
--------------------------------------------------------------------------------
	process (Trigger,PwmCnt) begin

			if (Trigger = H)			-- synch PWM to trigger
			or (PwmCnt >= 99) then		-- or restart if 100% reached
				PwmStart <= H;
			else
				PwmStart <= L;
			end if;

	end process;

	process (i_CLK) begin
		if rising_edge(i_CLK) and Q2MHz=H then

			if (PwmStart = H) then
				PwmCnt <= "0000000";	-- restart PWM
			else
				PwmCnt <= PwmCnt + 1;
			end if;

		end if;
	end process;

--------------------------------------------------------------------------------
-- 	Flash puls
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) and Q2MHz=H then
			if (i_NrOfPeriods(11) = H) then
				CycleCnt <= "00000000001";
				Flash <= H;
			else
				if (Trigger = H) then
					CycleCnt <= "00000000001"; -- this is nr one
					Flash <= H; -- so we do always at least one flash
				else
					if (PwmStart = H and Flash=H) then
						if (CycleCnt < i_NrOfPeriods(10 downto 0)) then
							CycleCnt <= CycleCnt + 1;
						else 
							Flash <= L;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	o_Flash <= Flash;

--------------------------------------------------------------------------------
--	Flash done counter
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) and Q2MHz=H then
        	Flash_t1 <= Flash;
        	if (Flash = L) and (Flash_t1 = H) then	
				-- count flash_done
				FlashCnt <= FlashCnt + 1;
			end if;	
		end if;
	end process;

	o_FlashCnt <= FlashCnt;

--------------------------------------------------------------------------------
-- 	FlashRun Output  >= 1ms
--------------------------------------------------------------------------------
-- just for software, at least 1ms

	process (i_CLK) begin
		if rising_edge(i_CLK) and Q2MHz=H then
			if (i_NrOfPeriods(11) = H) then
				FlashRunCnt <= "00000";
				FlashRun <= H;
			else
				if (Trigger = H) then
					FlashRunCnt <= "00000"; -- this is nr one
					FlashRun <= H; -- so we do always at least one flash
				else
					if (PwmStart = H) then
						if (FlashRunCnt < 19) then	-- 20x50us = 1ms
							FlashRunCnt <= FlashRunCnt + 1;
							FlashRun <= H;
						else
							FlashRun <= L;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	o_FlashRun <= FlashRun or Flash;

--------------------------------------------------------------------------------
--	LED
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) and Q2MHz=H then
			if (Flash = H) then
				if (PwmCnt < i_Percent_x1(6 downto 0)) then
					o_LED_x1 <= not i_Percent_x1(7);
				else
					o_LED_x1 <= i_Percent_x1(7);
				end if;
				if (PwmCnt < i_Percent_x2(6 downto 0)) then
					o_LED_x2 <= not i_Percent_x2(7);
				else
					o_LED_x2 <= i_Percent_x2(7);
				end if;
			else
				o_LED_x1 <= L;
				o_LED_x2 <= L;
			end if;
		end if;
	end process;


--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
