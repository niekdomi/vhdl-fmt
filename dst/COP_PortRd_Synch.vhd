--------------------------------------------------------------------------------
--
--  COP	Port-Rd Synch
--
--------------------------------------------------------------------------------
--
--  project	 : COP_PortRd_Synch
--  programmer  : F:Baschung, INDEL AG
--  date		: 26.10.2012
--  version	 : 1.00
--  language	: VHDL
--  system	  : Project Navigator
--
--  purpose
--  	Wenn zB ADA immer mit 32kHz sampeln soll (für Filter), egal wie schnell
--		die Ports vom Master abgefragt werden (32,16,8,4,1kHz), braucht es
--		frei laufende 32kHz Pulse, die bei jedem PortBlock-Rd synchronisiert
--		werden.
--
--		Der Port_Rd sollte zusammenhängend sein (Burst-RD).
--   	Der SynchPulse kann um einen festenWert vor/nach verschoben werden
--	  Bei +shift kommt der Puls xns nach fallender Flanke von Rd
--	  Bei -shift kommt der Puls xns vor steigender Flanke von Rd
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	26.10.2012-FB	erste Version
--------------------------------------------------------------------------------
--$Rev:: 2694                  $
--$Author:: leuthold                 $
--$Date:: 2013-01-25 12:07:31 +0100 (Fr., 25 Jan 2013)       $
--------------------------------------------------------------------------------
--ToDO
--ToDO		VORSICHT !!
--ToDO
--ToDO		funktioniert erst mit shift = -2560  für DEND-ADA
--ToDO
--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--------------------------------------------------------------------------------
entity COP_PortRdSynch is
	generic (
		-- PulsShift in ns,	+ later, - earlier	(0...+-15us)
		-- Vorsicht, dazu kommt +-640ns Jitter
		SynchPuls_shift_ns		: in  	integer	:= -6200
	);
	port (
		 i_Q25					: in 	std_logic;
		 i_COP_Port_Rd			: in 	std_logic;
		 o_SynchPulse_32kHz		: out	std_logic
	);
end COP_PortRdSynch;

--------------------------------------------------------------------------------
architecture impl of COP_PortRdSynch is
--------------------------------------------------------------------------------
	function wrap_int(val, MAX : integer) return integer is
		variable maxval : integer;
	begin
		if (val < MAX) then
			maxval := val;
		else
			maxval := val - MAX;
		end if;
		if (val < 0) then
			maxval := val + MAX;
		end if;
		return maxval;
	end function;


--------------------------------------------------------------------------------
	constant H 				: std_logic	:= '1';
	constant L 				: std_logic	:= '0';
--------------------------------------------------------------------------------
	constant cT_8kHz		: integer	:=	3125-1;	-- 25MHz / 8kHz
	constant cT_Faster		: integer	:=	cT_8kHz-4;
	constant cT_Slower		: integer	:=	cT_8kHz+4;

	-- offset, damit +-shift nicht ausserhalb 0...3125 fällt
--	constant cT_Cntoffs		: integer	:=	0;
	constant cT_Cntoffs		: integer	:=	cT_8kHz / 8;
--	constant cT_Cntoffs		: integer	:=	320;	-- x"140"	== 12.8us

	constant cT_32kHz_0		: integer	:=	   0+cT_Cntoffs;	-- 0140 1/4	abgerundet
	constant cT_32kHz_1		: integer	:=	 781+cT_Cntoffs;	-- 044D	1/4	abgerundet
	constant cT_32kHz_2		: integer	:=	1562+cT_Cntoffs;	-- 075A	2/4	abgerundet
	constant cT_32kHz_3		: integer	:=	2344+cT_Cntoffs;	-- 0A68	3/4	aufgerundet

	-- shift in ticks		25MHz = 40ns
	constant cT_Shift	 	: integer	:=	SynchPuls_shift_ns / 40;

	constant cT_Pulse_0		: integer	:=	wrap_int(cT_32kHz_0+cT_Shift , cT_8kHz);	-- 0100
	constant cT_Pulse_1		: integer	:=	wrap_int(cT_32kHz_1+cT_Shift , cT_8kHz);	-- 0100
	constant cT_Pulse_2		: integer	:=	wrap_int(cT_32kHz_2+cT_Shift , cT_8kHz);	-- 0100
	constant cT_Pulse_3		: integer	:=	wrap_int(cT_32kHz_3+cT_Shift , cT_8kHz);	-- 0100

	-- Jitter tollerance
	constant cT_JTol_ns		: integer	:=	640;
	constant cT_JTol		: integer	:=	cT_JTol_ns / 40;	-- 640/40 = 16

	constant cT_Min_0		: integer	:=	wrap_int(cT_32kHz_0-cT_JTol , cT_8kHz);	-- 0140 - 0010
	constant cT_Min_1		: integer	:=	wrap_int(cT_32kHz_1-cT_JTol , cT_8kHz); -- 044D - 0010
	constant cT_Min_2		: integer	:=	wrap_int(cT_32kHz_2-cT_JTol , cT_8kHz); -- 075A - 0010
	constant cT_Min_3		: integer	:=	wrap_int(cT_32kHz_3-cT_JTol , cT_8kHz); -- 0A68 - 0010

	constant cT_Max_0		: integer	:=	wrap_int(cT_32kHz_0+cT_JTol , cT_8kHz); -- 0140 + 0010
	constant cT_Max_1		: integer	:=	wrap_int(cT_32kHz_1+cT_JTol , cT_8kHz); -- 044D + 0010
	constant cT_Max_2		: integer	:=	wrap_int(cT_32kHz_2+cT_JTol , cT_8kHz); -- 075A + 0010
	constant cT_Max_3		: integer	:=	wrap_int(cT_32kHz_3+cT_JTol , cT_8kHz); -- 0A68 + 0010

--------------------------------------------------------------------------------
--	synch ADC convert to masters timing
	signal	COP_Port_Rd_1	: std_logic 					:= L;
	signal	Tls_Rd_Edge		: std_logic 					:= L;

	signal	Tls_8kHz_Cnt	: integer range 0 to 4095		:= 0;
	-- 25MHz / 781.25 = 32kHz 		(*4 = 3125)	(*32 = 250000)
	signal	Tls_8kHz_Max	: integer range 0 to 4095		 := cT_8kHz;

	signal	Tls_Pulse_32kHz	: std_logic 					:= L;

	signal	debug			: integer;
	signal	debug0			: integer;
	signal	debug1			: integer;
	signal	debug2			: integer;
	signal	debug3			: integer;

----------------------------------------------------------------------------------
begin

--------------------------------------------------------------------------------
--	Tlg syncher
-------------------------------------------------------------------------------
--	Bei 25MHz geht erst wieder 8kHz ganzzahlig auf, daher Cnt bis 3125
--
--	Da der GinLink mit 1,4,8,16,32kHz arbeiten kann, muss ich mit all
--	diesen Zugriffen klar kommen.
--
--	Ich mache die 3125 +1,0,-1, je nachden ob ich zuschnell oder zu langsam bin
-------------------------------------------------------------------------------
	o_SynchPulse_32kHz <= Tls_Pulse_32kHz;

--------------------------------------------------------------------------------
--	find first Read edge 	(_+- for +shift, -+_ for -shift)
--------------------------------------------------------------------------------
	process (i_Q25) begin
		if rising_edge(i_Q25) then
			-- t-1
			COP_Port_Rd_1 <= i_COP_Port_Rd;

		   	Tls_Rd_Edge <= L;
		   	if (SynchPuls_shift_ns > 0) then
		   		-- +shift, we use falling egde
				if (i_COP_Port_Rd = L) and (COP_Port_Rd_1 = H) then
					Tls_Rd_Edge <= H;
				end if;
			else
		   		-- -shift, we use rising egde
				if (i_COP_Port_Rd = H) and (COP_Port_Rd_1 = L) then
					Tls_Rd_Edge <= H;
				end if;
			end if;
		end if;
	end process;


--------------------------------------------------------------------------------
--	8kHz Counter
--------------------------------------------------------------------------------
	process (i_Q25) begin
		if rising_edge(i_Q25) then
			if (Tls_8kHz_Cnt < Tls_8kHz_Max) then
				Tls_8kHz_Cnt <= Tls_8kHz_Cnt + 1;
			else
				Tls_8kHz_Cnt <= 0;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	generate 8kHz*4 = 32kHz Pulses
--------------------------------------------------------------------------------
	debug0 <= cT_Pulse_0;
	debug1 <= cT_Pulse_1;
	debug2 <= cT_Pulse_2;
	debug3 <= cT_Pulse_3;

	process (i_Q25) begin
		if rising_edge(i_Q25) then
			Tls_Pulse_32kHz <= L;
			--------------------------------------------------------------------
			case (Tls_8kHz_Cnt) is
			--------------------------------------------------------------------
			when cT_Pulse_0 =>	Tls_Pulse_32kHz <= H;	debug <= 0;
			when cT_Pulse_1 =>	Tls_Pulse_32kHz <= H;	debug <= 1;
			when cT_Pulse_2 =>	Tls_Pulse_32kHz <= H;	debug <= 2;
			when cT_Pulse_3 =>	Tls_Pulse_32kHz <= H;	debug <= 3;
			--------------------------------------------------------------------
			when others => null;
			end case;
			--------------------------------------------------------------------
		end if;
	end process;

--------------------------------------------------------------------------------
--	adjust Tlg Read
--------------------------------------------------------------------------------
--ToDO	geht erst mit fix-offset von x"140"

	process (i_Q25) begin
		if rising_edge(i_Q25) then
			if (Tls_Rd_Edge = H) then
   				Tls_8kHz_Max <= cT_8kHz;

				----------------------------------------------------------------
				case (conv_std_logic_vector(Tls_8kHz_Cnt,12)(11 downto 8)) is
				----------------------------------------------------------------
				when x"1" =>	-- center = 0140
					if (Tls_8kHz_Cnt < cT_Min_0) then
						Tls_8kHz_Max <= cT_Faster;
					elsif (Tls_8kHz_Cnt > cT_Max_0) then
						Tls_8kHz_Max <= cT_Slower;
					end if;

				----------------------------------------------------------------
				when x"4" =>	-- center = 044D
					if (Tls_8kHz_Cnt < cT_Min_1) then
						Tls_8kHz_Max <= cT_Faster;
					elsif (Tls_8kHz_Cnt > cT_Max_1) then
						Tls_8kHz_Max <= cT_Slower;
					end if;

				----------------------------------------------------------------
				when x"7" =>	-- center = 075A
					if (Tls_8kHz_Cnt < cT_Min_2) then
						Tls_8kHz_Max <= cT_Faster;
					elsif (Tls_8kHz_Cnt > cT_Max_2) then
						Tls_8kHz_Max <= cT_Slower;
					end if;

				----------------------------------------------------------------
				when x"A" =>	-- center = 0A68
					if (Tls_8kHz_Cnt < cT_Min_3) then
						Tls_8kHz_Max <= cT_Faster;
					elsif (Tls_8kHz_Cnt > cT_Max_3) then
						Tls_8kHz_Max <= cT_Slower;
					end if;
				----------------------------------------------------------------
				when others =>
					-- sweep to next quadrant
					Tls_8kHz_Max <= cT_Faster;
				end case;
				----------------------------------------------------------------
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
