-------------------------------------------------------------------------------
--  $Id: bus_control.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- bus_control.vhd - entity/architecture pair
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
-- Filename:        bus_control.vhd
-- Version:         v1.01a
-- Description:     This file contains the logic that maintains the state of
--                  the PLB.
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
---------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      No generics used             
--
-- Definition of Ports:
--      input  XComp            -- slave read or write complete 
--      input  WdtComp          -- watchdog timer complete 
--      input  PriReg           -- output of read/write data bus busy reg
--      input  SecReg           -- output of secondary read/write in prog reg 
--      input  Recompute        -- control signal from arbControlSm
--
--      output PriIn            -- new input to read/write data bus busy reg  
--      output SecIn            -- new input to secondary read/write in prog reg  
--      output Promote          -- promotes secondary to primary
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity bus_control is
  port (
        XComp       : in std_logic;
        WdtComp     : in std_logic;
        PriReg      : in std_logic;
        SecReg      : in std_logic;
        Recompute   : in std_logic;
        PriIn       : out std_logic;
        SecIn       : out std_logic;
        Promote     : out std_logic
        );
end bus_control;

 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of bus_control is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
signal priIn_i    : std_logic;      -- internal version of PriIn output
signal secIn_i    : std_logic;      -- internal version of SecIn output
signal comp       : std_logic;      -- OR of XComp and WDTComp
  
-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-- assign internal signals to outputs
PriIn   <= priIn_i;
SecIn   <= secIn_i;

-- promote secondary status to primary when the primary bus is busy, there is
-- a secondary transaction in progress, and either the slave or the WDT 
-- completed the transaction
Promote <= PriReg and SecReg and comp;


comp    <= XComp or WdtComp;

-------------------------------------------------------------------------------
-- PRI_SEC_PROCESS Process
-------------------------------------------------------------------------------
-- This process calculates the next state of the PLB bus based on the current
-- state of the bus and the arb_control_sm and the status of the current transaction

PRI_SEC_PROCESS:  process (comp, PriReg, SecReg, Recompute)

    variable case_var : std_logic_vector(3 downto 0);
    
begin

    case_var := comp & PriReg & SecReg & Recompute ;   
    
    case case_var is        -- nosynthesis parallel_case
        
        when "0000" =>
                priIn_i <= '0';
                secIn_i <= '0';
        when "0001" =>
                priIn_i <= '1';
                secIn_i <= '0';
        when "0100" =>
                priIn_i <= '1';
                secIn_i <= '0';
        when "0101" =>
                priIn_i <= '1';
                secIn_i <= '1';
        when "0110" =>
                priIn_i <= '1';
                secIn_i <= '1';
        when "1001" =>
                priIn_i <= '0';
                secIn_i <= '0';
        when "1100" =>
                priIn_i <= '0';
                secIn_i <= '0';
        when "1101" =>
                priIn_i <= '1';
                secIn_i <= '0';
        when "1110" =>
                priIn_i <= '1';
                secIn_i <= '0';
        when others =>
                priIn_i <= '0';
                secIn_i <= '0';
    end case;
    
end process PRI_SEC_PROCESS;
 
 
end simulation;

