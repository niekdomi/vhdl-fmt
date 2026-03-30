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
--	18.05.2011-le	: - spartan6 plls
--	01.07.2011-le	: - add 25 mhz clk output
--------------------------------------------------------------------------------
--$Rev:: 1998                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-07-01 11:24:59 +0200 (Fr., 01 Jul 2011)                         $
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
port (
	i_reset : in std_logic := L;
	-- phy
	i_PHY_CLK125 : in std_logic;
	-- clk outputs
	o_clkPHY : out std_logic;
	--o_clkPHY_90 : out std_logic;
	o_clkPHYdiv2 : out std_logic;
	
	o_clk25 : out std_logic;
	--o_clkref200MHz : out std_logic;
	o_dcm_locked : out std_logic
);
end RGMII_clk;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of RGMII_clk is

  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of STRUCTURE : architecture is "RGMII_clk,clk_wiz_v3_1,{component_name=pll,use_phase_alignment=false,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO,primtype_sel=PLL_BASE,num_out_clk=2,clkin1_period=8.000,clkin2_period=8.000,use_power_down=false,use_reset=true,use_locked=true,use_inclk_stopped=false,use_status=false,use_freeze=false,use_clk_valid=false,feedback_type=SINGLE,clock_mgr_type=AUTO,manual_override=false}";
  -- Input clock buffering / unused connectors
  signal clkin1      : std_logic;
  -- Output clock buffering / unused connectors
  signal clkfbout         : std_logic;
  signal clkout0          : std_logic;
  signal clkout1          : std_logic;
  signal clkout2          : std_logic;
  signal clkout3_unused   : std_logic;
  signal clkout4_unused   : std_logic;
  signal clkout5_unused   : std_logic;
  -- Unused status signals

begin



  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => clkin1,
    I => i_PHY_CLK125);


  -- Clocking primitive
  --------------------------------------
  -- Instantiation of the PLL primitive
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused

  pll_base_inst : PLL_BASE
  generic map
   (BANDWIDTH            => "OPTIMIZED",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "INTERNAL",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 4,
    CLKFBOUT_PHASE       => 0.000,
    CLKOUT0_DIVIDE       => 4,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT1_DIVIDE       => 8,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT2_DIVIDE       => 20,
    CLKOUT2_PHASE        => 0.000,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKIN_PERIOD         => 8.000,
    REF_JITTER           => 0.010)
  port map
    -- Output clocks
   (CLKFBOUT            => clkfbout,
    CLKOUT0             => clkout0,
    CLKOUT1             => clkout1,
    CLKOUT2             => clkout2,
    CLKOUT3             => clkout3_unused,
    CLKOUT4             => clkout4_unused,
    CLKOUT5             => clkout5_unused,
    -- Status and control signals
    LOCKED              => o_dcm_locked,
    RST                 => i_reset,
    -- Input clock control
    CLKFBIN             => clkfbout,
    CLKIN               => clkin1);

  -- Output buffering
  -------------------------------------


  clkout1_buf : BUFG
  port map
   (O   => o_clkPHY,
    I   => clkout0);



  clkout2_buf : BUFG
  port map
   (O   => o_clkPHYdiv2,
    I   => clkout1);



  clkout3_buf : BUFG
  port map
   (O   => o_clk25,
    I   => clkout2);



end architecture STRUCTURE;