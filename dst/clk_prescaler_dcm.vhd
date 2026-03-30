----------------------------------------------------------------------------
----------------------------------------------------------------------------
--                                                                        --
--  OneWireMaster                                                         --
--   A synthesizable 1-wire master peripheral                             --
--   Copyright 2010 Maxim Integrated Products                             --
--                                                                        --
----------------------------------------------------------------------------
--                                                                        --
--  Purpose:  Provides timing and control of Dallas 1-wire bus            --
--            through a memory-mapped peripheral                          --
--  File:     clk_prescaler_dcm.vhd                                         --
--  Date:     July 22, 2011                                                --
--  Version:  v1.000                                                      --
--  Authors:  Stewart Merkel                                              --
--            Maxim Integrated Products                                   --
--                                                                        --
--  Note:     This source code is available for use without license.      --
--            Maxim Integrated Products is not responsible for the        --
--            functionality or utility of this product.                   --
--                                                                        --
--  REV:      Removal of gated clocks created in clk_prescaler for        --
--            use with Xilinx FPGA - English                              --
--            "CHANGE DCM ATTRIBUTES FOR YOUR CLOCK"                      --
----------------------------------------------------------------------------
Library UNISIM;
use UNISIM.vcomponents.all;
library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity clk_prescaler is
    port(
      CLK         : in std_logic;
      CLK_EN      : in std_logic;
      div_1       : in std_logic;
      div_2       : in std_logic;
      div_3       : in std_logic;
      MR          : in std_logic;
      pre_0       : in std_logic;
      pre_1       : in std_logic;
      clk_1us     : out std_logic);
end entity clk_prescaler;



architecture rtl_clk_prescaler of clk_prescaler is
 
   SIGNAL CLKFB            :  std_logic;    
   SIGNAL CLKDV            :  std_logic; 
	


begin
   -- BUFGCE: Global Clock Buffer with Clock Enable (active high)
   --         Spartan-3A
   -- Xilinx HDL Language Template, version 13.1
   BUFGCE_inst : BUFGCE
   port map (
      O => clk_1us,   -- Clock buffer ouptput
      CE => CLK_EN, -- Clock enable input
      I => CLKDV    -- Clock buffer input
   );

   -- End of BUFGCE_inst instantiation

   -- DCM_SP: Digital Clock Manager Circuit
   --         Spartan-3A
   -- Xilinx HDL Language Template, version 13.1

   DCM_SP_inst : DCM_SP
   generic map (
      CLKDV_DIVIDE => 16.0, --  Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
                           --     7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
      CLKFX_DIVIDE => 1,   --  Can be any interger from 1 to 32
      CLKFX_MULTIPLY => 4, --  Can be any integer from 1 to 32
      CLKIN_DIVIDE_BY_2 => FALSE, --  TRUE/FALSE to enable CLKIN divide by two feature
      CLKIN_PERIOD => 62.5, --  Specify period of input clock
      CLKOUT_PHASE_SHIFT => "NONE", --  Specify phase shift of "NONE", "FIXED" or "VARIABLE" 
      CLK_FEEDBACK => "1X",         --  Specify clock feedback of "NONE", "1X" or "2X" 
      DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- "SOURCE_SYNCHRONOUS", "SYSTEM_SYNCHRONOUS" or
                                             --     an integer from 0 to 15
      DLL_FREQUENCY_MODE => "LOW",     -- "HIGH" or "LOW" frequency mode for DLL
      DUTY_CYCLE_CORRECTION => TRUE, --  Duty cycle correction, TRUE or FALSE
      PHASE_SHIFT => 0,        --  Amount of fixed phase shift from -255 to 255
      STARTUP_WAIT => FALSE) --  Delay configuration DONE until DCM_SP LOCK, TRUE/FALSE
   port map (
      CLK0 => CLKFB,     -- 0 degree DCM CLK ouptput
      CLK180 => OPEN, -- 180 degree DCM CLK output
      CLK270 => OPEN, -- 270 degree DCM CLK output
      CLK2X => OPEN,   -- 2X DCM CLK output
      CLK2X180 => OPEN, -- 2X, 180 degree DCM CLK out
      CLK90 => OPEN,   -- 90 degree DCM CLK output
      CLKDV => CLKDV,   -- Divided DCM CLK out (CLKDV_DIVIDE)
      CLKFX => OPEN,   -- DCM CLK synthesis out (M/D)
      CLKFX180 => OPEN, -- 180 degree CLK synthesis out
      LOCKED => OPEN, -- DCM LOCK status output
      PSDONE => OPEN, -- Dynamic phase adjust done output
      STATUS => OPEN, -- 8-bit DCM status bits output
      CLKFB => CLKFB,   -- DCM clock feedback
      CLKIN => CLK,   -- Clock input (from IBUFG, BUFG or DCM)
      PSCLK => OPEN,   -- Dynamic phase adjust clock input
      PSEN => '0',     -- Dynamic phase adjust enable input
      PSINCDEC => OPEN, -- Dynamic phase adjust increment/decrement
      RST => '0'        -- DCM asynchronous reset input
   );

   -- End of DCM_SP_inst instantiation


end architecture rtl_clk_prescaler;
