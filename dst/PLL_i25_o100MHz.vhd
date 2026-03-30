--------------------------------------------------------------------------------
--
--  PLL		25MHz to 100MHz
--
--------------------------------------------------------------------------------
--
--  project	 : C64
--  programmer  : F.Baschung, INDEL AG
--  date		: 21.05.2004
--  version	 : 1.00
--  language	: VHDL
--  system	  : Project Navigator
--
--  purpose
--  	- generates Clocks and reset for Gin-MGT
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--$Rev:: 823																   $
--$Author:: leuthold														   $
--$Date:: 2008-12-18 15:37:50 +0100 (Do, 18. Dez 2008)						 $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;


entity PLL_i25_o100 is

	port (
		i_Reset  	: in std_logic;
		i_Q25 	 	: in std_logic;
   		o_Q100  	: OUT std_logic;
		o_Q25	 	: OUT std_logic;
		o_Q80	 	: OUT std_logic;
   		o_LOCKED	: OUT std_logic
	);

end PLL_i25_o100;

architecture imp of PLL_i25_o100 is
--------------------------------------------------------------------------------
	signal Q100 			: std_logic;
	signal Q25_PLL 			: std_logic;
	signal LOCKED 			: std_logic;
-- Output clock buffering / unused connectors
	signal clkfbout			: std_logic;
	signal clkfbout_buf		: std_logic;
	signal clkout0			: std_logic;
	signal clkout1		   	: std_logic;
	signal clkout2			: std_logic;
	signal clkout3_unused	: std_logic;
	signal clkout4_unused	: std_logic;
	signal clkout5_unused	: std_logic;

--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	:	std_logic := '1';
	constant	L	:	std_logic := '0';
	constant	Z	:	std_logic := 'Z';

begin

-------------------------------------------------------------------------------
--	Clock-Buffers
-------------------------------------------------------------------------------
	o_Q100 	 <= Q100;
	o_Q25	 <= Q25_PLL;
	o_LOCKED <= LOCKED;


	uDCM_Q100Buf : BUFG
		port map (
			I => clkout0,
			O => Q100
		);

	uDCM_Q25Buf : BUFG
		port map (
			I => clkout1,
			O => Q25_PLL
		);
		
	uDCM_Q80Buf : BUFG
		port map (
			I => clkout2,
			O => o_Q80
		);

-------------------------------------------------------------------------------
-- just for PLL-feedback
	uDCM_QfbBuf : BUFG
		port map (
			I => clkfbout,
			O => clkfbout_buf
		);

-------------------------------------------------------------------------------
--	PLL
-------------------------------------------------------------------------------
uPLL_Base : PLL_BASE
	Generic map (
		BANDWIDTH			=> "LOW",
--		CLK_FEEDBACK		=> "CLKFBOUT",
		COMPENSATION		=> "SYSTEM_SYNCHRONOUS",
		DIVCLK_DIVIDE		=> 1,
		CLKFBOUT_MULT		=> 16,			-- 25*20 = 400
		CLKFBOUT_PHASE		 => 0.000,

		CLKOUT0_DIVIDE		=> 4,			-- 500/4 = 100
		CLKOUT0_PHASE		=> 0.000,
		CLKOUT0_DUTY_CYCLE	=> 0.500,

		CLKOUT1_DIVIDE		=> 16,			-- 400/16 = 25
		CLKOUT1_PHASE		=> 0.000,
		CLKOUT1_DUTY_CYCLE	=> 0.500,
		
		CLKOUT2_DIVIDE		=> 5,			-- 400/20 = 25
		CLKOUT2_PHASE		=> 0.000,
		CLKOUT2_DUTY_CYCLE	=> 0.500,

		CLKIN_PERIOD		 => 40.000,		-- ns
		REF_JITTER		=> 0.1	   -- *CLKIN_PERIOD
	) Port map (
		-- Output clocks
		CLKFBOUT		=> clkfbout,
		CLKOUT0			=> clkout0,
		CLKOUT1			=> clkout1,
		CLKOUT2			=> clkout2,
		CLKOUT3			=> clkout3_unused,
		CLKOUT4			=> clkout4_unused,
		CLKOUT5			=> clkout5_unused,
		-- Status and control signals
		LOCKED			=> LOCKED,
		RST				=> i_Reset,
		-- Input clock control
		CLKFBIN			=> clkfbout_buf,
		CLKIN			=> i_Q25
	);
-------------------------------------------------------------------------------

end;

