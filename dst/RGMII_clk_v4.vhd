--------------------------------------------------------------------------------
--	RGMII_clk.vhd
--------------------------------------------------------------------------------
--
--	project     : RGMII_clk
--	programmer  : C. Leuthold, INDEL AG
--	date        : 05.02.2008
--	version     : 1.00
--	language    : VHDL
--	system      : ise / v4
--
--	purpose
--		Phy clocking: include a dcm and clock buffer (input and global)
--			outputs: phy clk 0°, 90°
--					 phy clk/2
--					 200MHz ref clk for IDELAYCTRL
--------------------------------------------------------------------------------
-- revision information
--	05.02.2008-le	: - split RGMII_if to interface and clocking
--	20.07.2011-le	: - add o_clkPHYdiv5 (used as 25MHZ C64 Clk)
--	
--------------------------------------------------------------------------------
--$Rev:: 2885                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-07-31 11:02:41 +0200 (Mi., 31 Jul 2013)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library Unisim;
use Unisim.vcomponents.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity RGMII_clk is
generic (
	C_DIV5 : integer range 0 to 1 := 0
);
port (
	i_reset : in std_logic := L;
	-- phy
	i_PHY_CLK125 : in std_logic;
	-- clk outputs
	o_clkPHY : out std_logic;
	o_clkPHY_90 : out std_logic;
	o_clkPHYdiv2 : out std_logic;
	o_clkref200MHz : out std_logic;
	o_clkPHYdiv5 : out std_logic;
	o_clk100 : out std_logic;
	o_dcm_locked : out std_logic
);
end RGMII_clk;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of RGMII_clk is
	----------------------------------------------------------------------------
	-- constants 
	----------------------------------------------------------------------------
	
	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------
	
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal net_gnd : std_logic := L;
	signal net_vcc : std_logic := H;
	-- resets
	signal phy_dcm_Rst : std_logic_vector(15 downto 0) := (others => H);
	signal idel_rst : std_logic_vector(15 downto 0) := (others => H);
	-- clocks / dcm
	signal phy_CLK125: std_logic;
	signal phy_CLK125_ibufg : std_logic;
	signal phy_CLK125_bufg : std_logic;
	signal phy_CLK125ub : std_logic;
	signal phy_CLK125_90 : std_logic;
	signal phy_CLK125_90ub : std_logic;
	signal phy_CLK125div2 : std_logic;
	signal phy_CLK125div2ub : std_logic;
	signal ref_clk_ub : std_logic;
	signal ref_clk : std_logic;
	signal phy_dcm_locked : std_logic;
	
	
	-- clocks / dcm
	signal phy_CLK125_2: std_logic;
	signal phy_CLK125ub_2 : std_logic;
	signal phy_CLK125div5 : std_logic;
	signal phy_CLK125div5ub : std_logic;
	signal clk100 : std_logic;
	signal clk100ub : std_logic;
	
	
begin -- architecture ----------------------------------------------------------
	net_gnd <= L;
	net_vcc <= H;
	
	o_clkPHY <= phy_CLK125;
	o_clkPHY_90 <= phy_CLK125_90;
	o_clkPHYdiv2 <= phy_CLK125div2;
	o_clkref200MHz <= ref_clk;
	o_dcm_locked <= phy_dcm_locked;
	
	o_clkPHYdiv5 <= phy_CLK125div5;
	o_clk100 <= clk100;
	
	-- clocking ----------------------------------------------------------------
	IBUFG_phy : IBUFG
	port map (
		O => phy_CLK125_ibufg, -- Clock buffer output
		I => i_PHY_CLK125 -- Clock buffer input (connect directly to top-level port)
	);
	
	process(phy_CLK125_ibufg)
	begin
		if rising_edge(phy_CLK125_ibufg) then
			phy_dcm_Rst <= phy_dcm_Rst(phy_dcm_Rst'high-1 downto 0) & i_reset;
		end if;
	end process;
	
	DCM_BASE_phy : DCM_BASE
	generic map (
		CLKDV_DIVIDE => 2.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
		CLKFX_DIVIDE => 5, -- Can be any interger from 1 to 32
		CLKFX_MULTIPLY => 8, -- Can be any integer from 2 to 32
		CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
		CLKIN_PERIOD => 8.0, -- Specify period of input clock in ns from 1.25 to 1000.00
		CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
		CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
		DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
		DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
		DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
		DFS_FREQUENCY_MODE => "LOW", -- LOW or HIGH frequency mode for frequency synthesis
		DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
		DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
		FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
		PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
		STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
	port map (
		CLK0 => phy_CLK125ub, -- 0 degree DCM CLK ouptput
		CLK180 => open, -- 180 degree DCM CLK output
		CLK270 => open, -- 270 degree DCM CLK output
		CLK2X => open, -- 2X DCM CLK output
		CLK2X180 => open, -- 2X, 180 degree DCM CLK out
		CLK90 => phy_CLK125_90ub, -- 90 degree DCM CLK output
		CLKDV => phy_CLK125div2ub, -- Divided DCM CLK out (CLKDV_DIVIDE)
		CLKFX => ref_clk_ub, -- DCM CLK synthesis out (M/D)
		CLKFX180 => open, -- 180 degree CLK synthesis out
		LOCKED => phy_dcm_locked, -- DCM LOCK status output
		CLKFB => phy_CLK125, -- DCM clock feedback
		CLKIN => phy_CLK125_bufg, -- Clock input (from IBUFG, BUFG or DCM)
		RST => phy_dcm_Rst(phy_dcm_Rst'high) -- DCM asynchronous reset input
	);
	
	BUFG_dcm_in : BUFG
	port map (
		O => phy_CLK125_bufg, -- Clock buffer output
		I => phy_CLK125_ibufg -- Clock buffer input
	);
	
	BUFG_phy : BUFG
	port map (
		O => phy_CLK125, -- Clock buffer output
		I => phy_CLK125ub -- Clock buffer input
	);
	
	BUFG_CLK : BUFG
	port map (
		O => phy_CLK125_90, -- Clock buffer output
		I => phy_CLK125_90ub -- Clock buffer input
	);
	
	BUFG_ref_clk : BUFG
	port map (
		O => ref_clk, -- Clock buffer output
		I => ref_clk_ub -- Clock buffer input
	);
	
	BUFG_CLK125div2 : BUFG
	port map (
		O => phy_CLK125div2, -- Clock buffer output
		I => phy_CLK125div2ub -- Clock buffer input
	);
	
	dcm_25_mhzout: if C_DIV5=1 generate
	
	begin
	
		DCM_BASE_c64 : DCM_BASE
		generic map (
			CLKDV_DIVIDE => 5.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
			CLKFX_DIVIDE => 5, -- Can be any interger from 1 to 32
			CLKFX_MULTIPLY => 4, -- Can be any integer from 2 to 32
			CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
			CLKIN_PERIOD => 8.0, -- Specify period of input clock in ns from 1.25 to 1000.00
			CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
			CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
			DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
			DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
			DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
			DFS_FREQUENCY_MODE => "LOW", -- LOW or HIGH frequency mode for frequency synthesis
			DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
			DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
			FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
			PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
			STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
		port map (
			CLK0 => phy_CLK125ub_2, -- 0 degree DCM CLK ouptput
			CLK180 => open, -- 180 degree DCM CLK output
			CLK270 => open, -- 270 degree DCM CLK output
			CLK2X => open, -- 2X DCM CLK output
			CLK2X180 => open, -- 2X, 180 degree DCM CLK out
			CLK90 => open, -- 90 degree DCM CLK output
			CLKDV => phy_CLK125div5ub, -- Divided DCM CLK out (CLKDV_DIVIDE)
			CLKFX => clk100ub, -- DCM CLK synthesis out (M/D)
			CLKFX180 => open, -- 180 degree CLK synthesis out
			LOCKED => open, -- DCM LOCK status output
			CLKFB => phy_CLK125_2, -- DCM clock feedback
			CLKIN => phy_CLK125_bufg, -- Clock input (from IBUFG, BUFG or DCM)
			RST => phy_dcm_Rst(phy_dcm_Rst'high) -- DCM asynchronous reset input
		);
		
		BUFG_phy2 : BUFG
		port map (
			O => phy_CLK125_2, -- Clock buffer output
			I => phy_CLK125ub_2 -- Clock buffer input
		);
		
		BUFG_CLK125div5 : BUFG
		port map (
			O => phy_CLK125div5, -- Clock buffer output
			I => phy_CLK125div5ub -- Clock buffer input
		);
		
		BUFG_CLK100 : BUFG
		port map (
			O => clk100, -- Clock buffer output
			I => clk100ub -- Clock buffer input
		);
	end generate dcm_25_mhzout;
	
end architecture STRUCTURE;