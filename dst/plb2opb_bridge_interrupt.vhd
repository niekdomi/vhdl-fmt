-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_interrupt.vhd,v 1.1 2004/05/13 20:28:15 mlovejoy Exp $
-------------------------------------------------------------------------------
--  PLB to OPB Bridge Out, Bus Error Interrupt - Module
-------------------------------------------------------------------------------
--
--  ***************************************************************************
--  **  Copyright(C) 2003 by Xilinx, Inc. All rights reserved.               **
--  **                                                                       **
--  **  This text contains proprietary, confidential                         **
--  **  information of Xilinx, Inc. , is distributed by                      **
--  **  under license from Xilinx, Inc., and may be used,                    **
--  **  copied and/or disclosed only pursuant to the terms                   **
--  **  of a valid license agreement with Xilinx, Inc.                       **
--  **                                                                       **
--  **  Unmodified source code is guaranteed to place and route,             **
--  **  function and run at speed according to the datasheet                 **
--  **  specification. Source code is provided "as-is", with no              **
--  **  obligation on the part of Xilinx to provide support.                 **
--  **                                                                       **
--  **  Xilinx Hotline support of source code IP shall only include          **
--  **  standard level Xilinx Hotline support, and will only address         **
--  **  issues and questions related to the standard released Netlist        **
--  **  version of the core (and thus indirectly, the original core source). **
--  **                                                                       **
--  **  The Xilinx Support Hotline does not have access to source            **
--  **  code and therefore cannot answer specific questions related          **
--  **  to source HDL. The Xilinx Support Hotline will only be able          **
--  **  to confirm the problem in the Netlist version of the core.           **
--  **                                                                       **
--  **  This copyright and support notice must be retained as part           **
--  **  of this text at all times.                                           **
--  ***************************************************************************
--
-------------------------------------------------------------------------------
--  Filename:     plb2opb_bridge_interrupt.vhd
--  Version:      v1.01a
--  Description:
--    This module generates an edge-type interrupt whenever a bus error is 
--    detected. The active state of the interrupt is determined by the
--    C_IRQ_ACTIVE parameter. The pulse is one-clock wide.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--            -- plb2opb_bridge.vhd
--               -- plb2opb_bridge_plb_if.vhd
--                  -- plb2opb_bridge_srl16x30.vhd
--               -- plb2opb_bridge_xfer_if.vhd
--               -- plb2opb_bridge_rcv_data_if.vhd
--               -- plb2opb_bridge_opb_if.vhd
--               -- plb2opb_bridge_besr.vhd
--               -- plb2opb_bridge_interrupt.vhd
--
-------------------------------------------------------------------------------
-- Author:      
-- History:
--      ALS         01/15/02    -- Creation
--      ALS         07/09/02    -- Version 1.00b
-- ^^^^^^
--  C_INCLUDE_BGI_TRANSABORT generic is no longer used.
-- ~~~~~~
------------------------------------------------------------------------------- 
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
-- 
 
library ieee;
use ieee.std_logic_1164.all;
 
library unisim;
use unisim.vcomponents.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_interrupt is
    generic( C_IRQ_ACTIVE   : std_logic := '1'
            );
  port (
        Clk             : in std_logic;
        Rst             : in std_logic;
        Err_ack_det     : in std_logic;
        Timeout_det     : in std_logic;
        Intr_en         : in std_logic;
        Bus_Error_Det   : out std_logic
        );
end plb2opb_interrupt;
 
-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------
architecture plb2opb_interrupt of plb2opb_interrupt is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- internal signal for output
signal bus_error_det_i      : std_logic;

-- d input to registers
signal bus_error_det_d      : std_logic;

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin
-- assign internal signal to output
Bus_Error_Det <= bus_error_det_i;

RISING_EDGE_GEN: if C_IRQ_ACTIVE = '1' generate

    bus_error_det_d <= not(bus_error_det_i) and (Err_ack_det or Timeout_det);
    
    INTERRUPT_REFF_I: FDRE
      port map (
                Q   => bus_error_det_i,     --[out]
                C   => Clk,                 --[in]
                CE  => Intr_en,             --[in]
                D   => bus_error_det_d,     --[in]
                R   => Rst                  --[in]
                );
end generate RISING_EDGE_GEN;

FALLING_EDGE_GEN: if C_IRQ_ACTIVE = '0' generate

    bus_error_det_d <= not(bus_error_det_i and (Err_ack_det or Timeout_det));

    INTERRUPT_FEFF_I: FDSE
      port map (
                Q   => bus_error_det_i,     --[out]
                C   => Clk,                 --[in]
                CE  => Intr_en,             --[in]
                D   => bus_error_det_d,     --[in]
                S   => Rst                  --[in]
                );
end generate FALLING_EDGE_GEN;

end ;

