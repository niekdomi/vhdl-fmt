-------------------------------------------------------------------------------
--  $Id: arb_addr_sel.vhd,v 1.1 2004/05/13 20:36:04 mlovejoy Exp $
-------------------------------------------------------------------------------
-- arb_addr_sel.vhd - entity/architecture pair
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
-- Filename:        arb_addr_sel.vhd
-- Version:         v1.01a
-- Description:     This file contains the register which holds the priority
--                  encoder's output indicating the master which is controlling
--                  the bus. This register is loaded at the appropriate time 
--                  as indicated by the LoadAddrSelReg which is output from
--                  the arb_control_sm.
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
-- Author:      BLT
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
--      combinatorial signals:                  "*_cmb" 
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
 
-- PROC_COMMON_PKG contains the RESET_ACTIVE constant
library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--
-- Definition of Ports:
--      input PrioencdrOutput       -- output from priority encoder
--      input LoadAddrSelReg        -- indicates the ArbAddrSelReg should load
--      output ArbAddrSelReg        -- one-hot bus indicating which master has
--                                  -- won arbitration
--
--      input Clk                   -- clock
--      input ArbReset              -- reset
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity arb_addr_sel is
  generic ( C_NUM_MASTERS   : integer   := 8);
  port (
        Clk             : in std_logic;
        PrioencdrOutput : in std_logic_vector(0 to C_NUM_MASTERS-1 );
        LoadAddrSelReg  : in std_logic;
        ArbReset        : in std_logic;
        ArbAddrSelReg   : out std_logic_vector(0 to C_NUM_MASTERS-1 )
        );
end arb_addr_sel;
 
 

-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of arb_addr_sel is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- define internal version of output signal
signal arbAddrSelReg_i : std_logic_vector(0 to C_NUM_MASTERS -1 );



-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-- assign internal signal to output
ArbAddrSelReg <= arbAddrSelReg_i;

-------------------------------------------------------------------------------
-- ARBADDRSELREG_PROCESS
-------------------------------------------------------------------------------
-- This process registers the priority encoder output at the appropriate
-- arbitration state indicated by LoadAddrSelReg
-------------------------------------------------------------------------------

ARBADDRSELREG_PROCESS:process (Clk)
  begin
    if (Clk'event and Clk = '1') then
        if (ArbReset)= RESET_ACTIVE then
            arbAddrSelReg_i <= (others => '0');
        elsif (LoadAddrSelReg)='1' then
            arbAddrSelReg_i <= PrioencdrOutput;
        else
            arbAddrSelReg_i <= arbAddrSelReg_i;
        end if;
    end if;
  end process ARBADDRSELREG_PROCESS;
 
 
end simulation;

