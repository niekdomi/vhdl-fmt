-------------------------------------------------------------------------------
--  $Id: qual_priority.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- qual_priority.vhd - entity/architecture pair
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
-- Filename:        qual_priority.vhd
-- Version:         v1.01a
-- Description:     This file decodes the master's priority bits if its request
--                  is asserted. Unlike QualReq, this file doesn't examine the
--                  master's abort signal or the master disable register.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--          plb_v34.vhd
--              --  plb_addrpath.vhd
--                  --  mux_onehot_imp.vhd
--
--              --  plb_rd_datapath.vhd
--
--              --  plb_wr_datapath.vhd
--                  --  mux_onehot_imp.vhd
--
--              --  plb_slave_ors.vhd
--
--              --  plb_arbiter_logic.vhd
--                  --  muxed_signals.vhd
--                      --  mux_onehot_imp.vhd
--                      --  or_bits.vhd
--
--                  --  arb_control_sm.vhd
--
--                  --  arb_registers.vhd
--                      --  bus_controlvhd
--
--                  --  plb_priority_encoder.vhd
--                      --  priority_encoder.vhd
--                          --  qual_request.vhd
--                      --  arb_addr_sel.vhd
--                      --  mux_onehot_imp.vhd
--                      --  pend_request.vhd
--                      --  pending_priority.vhd
--                          --  qual_priority.vhd
--
--                  --  gen_qual_req.vhd
--
--                  --  buslocksm.vhd
--
--                  --  watchdog_timer.vhd
--                      --  down_counter.vhd
--
--                  --  dcr_regs.vhd
-- 
--                  --  plb_interrupt.vhd
--
-------------------------------------------------------------------------------
-- Author:      ALS
-- History:
--      ALS     02/20/02        -- created from plb_arbiter_v1_01_a
--      ALS     04/16/02        -- Version v1.01a
-------------------------------------------------------------------------------
-- 
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
use ieee.STD_LOGIC_1164.all;
 
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      No generics used              
--
-- Definition of Ports:
--      input Request               -- master's request signal
--      input Priority              -- master's priority signals
--
--      output Lvl1_n               -- master's priority was lvl 1 (active low)
--      output Lvl2_n               -- master's priority was lvl 2 (active low)
--      output Lvl3_n               -- master's priority was lvl 3 (active low)
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity qual_priority is
  port (
        Request : in std_logic;
        Priority : in std_logic_vector(0 to 1 );
        Lvl1_n : out std_logic;
        Lvl2_n : out std_logic;
        Lvl3_n : out std_logic
        );
end qual_priority;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture qual_priority of qual_priority is


-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- QUALPRI_PROCESS
-------------------------------------------------------------------------------
-- This process decodes the priority bits of the masters which are currently
-- requesting the bus
-------------------------------------------------------------------------------

QUALPRI_PROCESS:process(Request, Priority)
  begin   
    
    -- set default values
    lvl1_n <= '1';
    lvl2_n <= '1';
    lvl3_n <= '1';
    
    if (request)='1' then
      case Priority is
 
        when "00" =>
          null;
 
        when "01" =>
          lvl1_n <= '0';
 
        when "10" =>
          lvl2_n <= '0';
 
        when "11" =>
          lvl3_n <= '0';
 
        when others  =>
          lvl1_n <= 'X';
          lvl2_n <= 'X';
          lvl3_n <= 'X';
      end case;
    end if;
  end process QUALPRI_PROCESS;
 
 
end ;

