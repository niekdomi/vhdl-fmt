--------------------------------------------------------------------------------
--
--  Allegro_SM_if 	(Allegro stepper interface)
--
--------------------------------------------------------------------------------
--
--  project     : COP_DVT_HEAD_SM (original)
--  programmer  : F:Baschung, INDEL AG (S. Nüesch)
--  date        : 01.03.2011
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- En,Dir,Clk for Stepper-Motor IC A3977, A4980 or similar (Allegro)
--		- two modi:
--			- continuously:	generate pulse everytime after i_SM_DIV/125MHz
--							direction defined by MSB of i_SM_DIV
--			- manually: 	generate pulse when i_SM_CNT is changed (signed!)
--							(doesn't really matter what kind of change)
--							direction defined if change positive or negativ
--	Todo
--		- maybe add register to choose how many sequential pulses should be
--		  generated (would need additional control logic like start,done,etc.!)
--			-> would be useful, e.g. for GIN-OCT (better control over pulse count)
--		- maybe change concept a little bit and use only one general clock...
--		- leave SM_DIV_CNT at old value, when SM_DIV is set to 0?
--			-> so no contouring/following error anymore in SW driver?
--			(discuss with SW team, should also be possible in sw itself?)
--	Note
--		- if the clock-divider part isn't clocked faster then the control part
--		(e.g. both processes clocked with 25 MHz) the SM_ONE_x-pulses will be
--		detected more than once in the control part, thus the counter value will
--		be amiss.
--			-> it would be possible to detect edge of SM_ONE_x-pulse instead of
--			value
--		- in clock-divider mode (continuously) there is a dead-time if you change
--		from 0 (not running) to divider-value (pulse not instantly generated)
--			-> one div_clock-cycle later (count from 0 to SM_DIV first)
--		- there is also the possibility of swallowing the last pulse when you
--		stop (change divider to 0)
--			-> especially dangerous if stepper frequency is the same as the
--			bus frequency!!!
--
--			addition: "swallow" pulses and pulse counter together. There shouldn't
--			be a scenario where the pulse is executed but not counted...
--			(except hw pins will be deactivated in the 1 us time frame before SM_CLK)
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	26.11.2013-STN	- 32-Bit Zähler hinzugefügt
--	31.10.2013-STN	- Überlauf von -8 zu 7 und umgekehrt berücksichtigt
--	11.10.2013-STN	- kommentiert und minimal angepasst für GIN-TTL-Head
--	09.12.2012-FB	- erste Version (COP_DVT_HEAD_SM)
--------------------------------------------------------------------------------
--$Rev:: 3353                                                                  $
--$Author:: Nueesch                                                            $
--$Date:: 2014-04-29 15:59:24 +0200 (Di., 29 Apr 2014)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
entity ALLEGRO_SM_IF is
	port (
		 i_Q25			: in	std_logic;
		 i_Q125			: in	std_logic;
		 i_SM_EN		: in	std_logic;
		 i_SM_CNT		: in	std_logic_vector(3 downto 0);	-- manually
		 i_SM_DIV		: in	std_logic_vector(31 downto 0);	-- continuously

		-- SN-PIns
		 o_SM_EN		: out	std_logic;
		 o_SM_DIR		: out	std_logic;
		 o_SM_CLK		: out	std_logic;
		 
		 o_SM_PULSE_CNT	: out	std_logic_vector(31 downto 0)
	);
end ALLEGRO_SM_IF;

--------------------------------------------------------------------------------
architecture impl of ALLEGRO_SM_IF is
--------------------------------------------------------------------------------
    constant H 				: std_logic	:= '1';
    constant L 				: std_logic	:= '0';
--------------------------------------------------------------------------------
	signal	sSM_CNT			: signed(3 downto 0)			:= (others => '0');
	signal	sLAST_SM_CNT	: signed(3 downto 0)			:= (others => '0');
	signal	SM_CLK_CNT		: integer range 0 to 128		:= 0; -- for timing controlling
	signal	sSM_DIV			: signed(31 downto 0)			:= (others => '0');
	signal	sSM_DIV_CNT		: signed(31 downto 0)			:= (others => '0');
	signal	SM_ONE_POS		: std_logic						:= '0';
	signal	SM_ONE_NEG		: std_logic						:= '0';
	
	signal	SM_EN			: std_logic						:= '0';
	signal	SM_PULSE_CNT	: std_logic_vector(31 downto 0)	:= (others => '0');

	-- Q25:	3us = 3*25 = 75
 	constant	cT3us		: integer range 0 to 128	:= 75;
	-- Q25:	2us = 2*25 = 25
 	constant	cT2us		: integer range 0 to 128	:= 50;
--------------------------------------------------------------------------------

begin

--------------------------------------------------------------------------------
--	Test-Points
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	In / Out
--------------------------------------------------------------------------------
	o_SM_EN <= SM_EN;
	o_SM_PULSE_CNT <= SM_PULSE_CNT;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	-- convert to signed
	sSM_DIV <= signed(i_SM_DIV);

	process(i_Q125) begin
		if rising_edge(i_Q125) then
			if (sSM_DIV = 0) then
				sSM_DIV_CNT <= (others => '0');
			else
				if (i_SM_DIV(31) = L) then
					if (sSM_DIV_CNT > sSM_DIV) then
						sSM_DIV_CNT <= (others => '0');
						SM_ONE_POS <= H;
					else
						sSM_DIV_CNT <= sSM_DIV_CNT + 1;
					end if;
				else
					if (sSM_DIV_CNT < sSM_DIV) then
						sSM_DIV_CNT <= (others => '0');
						SM_ONE_NEG <= H;
					else
						sSM_DIV_CNT <= sSM_DIV_CNT - 1;
					end if;
				end if;
			end if;

			-- pulse already seen?
			-- 	ignore SM_ONE_x-pulse if SM_CLK-cycle is already active (due to manual SM_CNT)
			--	or clear pulse if seen by other process
			if (SM_CLK_CNT > 0) then
				SM_ONE_POS <= L;
				SM_ONE_NEG <= L;
			end if;

		end if;
	end process;

--******************************************************************************
--
--	 Stepper-Motor IC A3977 or similar	(Allegro)
--
--******************************************************************************
--	min DIR before CLK _+-		200ns 		--> 1us				(setup-time)
--	min DIR after  CLK _+-		200ns       --> till next puls	(hold-time)
--	min CLK high		_+--+_	1us         --> 2us
--	min CLK low			-+__+-	1us         --> till next puls
--------------------------------------------------------------------------------
	-- convert to signed
	sSM_CNT <= signed(i_SM_CNT);

	process(i_Q25) begin
		if rising_edge(i_Q25) then
			-- timer running
			if (SM_CLK_CNT > 0) then
				SM_CLK_CNT <= SM_CLK_CNT - 1;
			end if;
			
			SM_EN <= i_SM_EN;
			
			-- pulse in positive direction
			if ((sSM_CNT > sLAST_SM_CNT) or (SM_ONE_POS = H)) then
				-- set direction 1 us before clk (setup)
				SM_CLK_CNT <= cT3us;
				o_SM_DIR <= L;
				SM_PULSE_CNT <= SM_PULSE_CNT + 1;

			-- pulse in negative direction
			elsif ((sSM_CNT < sLAST_SM_CNT) or (SM_ONE_NEG = H)) then
				-- set direction 1 us before clk (setup)
				SM_CLK_CNT <= cT3us;
				o_SM_DIR <= H;
				SM_PULSE_CNT <= SM_PULSE_CNT - 1;
			end if;
			
			-- handle change of sign from -8 to 7, and vice versa, special,
			-- so that continuous cycles are possible
			-- Note: overwrite of previous DIR-assignment
			if(sLAST_SM_CNT = -8 and sSM_CNT = 7) then -- keep negative direction
				o_SM_DIR <= H;
				SM_PULSE_CNT <= SM_PULSE_CNT - 1;
			elsif(sLAST_SM_CNT = 7 and sSM_CNT = -8) then -- keep positive direction
				o_SM_DIR <= L;
				SM_PULSE_CNT <= SM_PULSE_CNT + 1;
			end if;
			
			-- delete pulse counter if SM_EN isn't activ!
			-- Note: overwrite of previous SM_PULSE_CNT-assignment
			if(SM_EN = '0') then
				SM_PULSE_CNT <= (others => '0');
			end if;
				
			sLAST_SM_CNT <= sSM_CNT;

			----------------------------------------------------------------
			case SM_CLK_CNT is
			----------------------------------------------------------------
			when cT2us	=> o_SM_CLK <= H;
			when 0	  	=> o_SM_CLK <= L;
			----------------------------------------------------------------
			when others => null;
			end case;
			----------------------------------------------------------------
		end if;
	end process;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
