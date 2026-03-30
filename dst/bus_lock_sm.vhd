-------------------------------------------------------------------------------
-- $Id: bus_lock_sm.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- bus_lock_sm.vhd - entity/architecture pair
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
-- Filename:        bus_lock_sm.vhd
-- Version:         v1.01a
-- Description:     This file asserts PLB_busLock when PAValid is 
--                  asserted and if the controlling master has asserted its
--                  busLock signal. PLB_busLock is then negated when the 
--                  master negates its busLock.
--
--                  This file also generates SM_busLock which is used by the
--                  arb_control_sm to determine if the bus is locked. This signal
--                  is necessary because the bus remains locked one clock after
--                  the master negates its buslock signal. SM_busLock will 
--                  assert with the master's buslock signal but negates one
--                  clock later.
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
use ieee.STD_LOGIC_1164.all;

-- PROC_COMMON_PKG contains the constant RESET_ACTIVE
library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      No generics used      
--
-- Definition of Ports:
--      input  Mstr_buslock         -- buslock signal from master controlling PLB
--      input  Set_disables_state   -- state variable from arbcontrolSM
--      input  Sl_rearbitrate       -- slave needs arbiter to rearbitrate the bus
--      input  Sl_addrAck           -- slave address acknowledge
--      input  Abort                -- abort signal from master controlling PLB
--      input  Rst
--      input  Clk
--
--      output PLB_busLock          -- PLB buslock signal
--      output SM_busLock           -- buslock signal for arbcontrolSM
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity bus_lock_sm is
    port (
          Mstr_buslock          : in std_logic;
          Set_disables_state    : in std_logic;
          Sl_rearbitrate        : in std_logic;
          Sl_addrAck            : in std_logic;
          Abort                 : in std_logic;
          
          PLB_busLock           : out std_logic;
          SM_busLock            : out std_logic;
          
          Rst                   : in std_logic;
          Clk                   : in std_logic
          );
 
end bus_lock_sm;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture implementation of bus_lock_sm is

-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------
-- registered version of PLB_busLock and SM_busLock outputs 
signal plb_buslock_reg  : std_logic;
signal sm_buslock_reg   : std_logic;

-- internal rearbitrate signal which is only asserted if the slave rearbitrate
-- signal is asserted and addr_ack is negated
signal rearbitrate    : std_logic;

 
-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
rearbitrate <= '1' when (Sl_rearbitrate = '1' and Sl_addrAck = '0')
                     else '0';

-------------------------------------------------------------------------------
-- PLB_busLock Generation
--
-- PLB_busLock must assert when PAValid asserts and must negate when the 
-- selected master negates its Mn_buslock signal. It also must negate whenever
-- a rearbitrate signal has been asserted. Therefore, PLB_busLock will
-- assert whenever the arb_control_sm is in the Set_disables_state and the master's 
-- abort signal is negated. If the slave issues a rearbitrate, PLB_busLock must
-- negate. Otherwise, PLB_busLock stays asserted until the master negates its
-- bus lock signal.
--
-- In order to not incur a register delay when a master negates its buslock, a
-- register is used to generate a registered version of PLB_busLock. The output
-- of this register is then gated with the master's buslock signal.
--
------------------------------------------------------------------------------- 

PLBBUSLOCK_REG_PROCESS: process (Clk)
begin

    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE) then
            plb_buslock_reg <= '0';
        else
            if ( rearbitrate='0' and Mstr_buslock='1' and
                (plb_buslock_reg='1' or (Set_disables_state='1' and abort='0')) ) then
                plb_buslock_reg <= '1';
            else
                plb_buslock_reg <= '0';
            end if;
        end if;
    end if;
end process PLBBUSLOCK_REG_PROCESS;

PLB_busLock <= plb_buslock_reg and Mstr_buslock;

-------------------------------------------------------------------------------
-- SM_busLock Generation
--
-- The SM_buslock signal will assert when the selected master's busLock signal
-- asserts but will negate one clock later. This signal is used by the 
-- arb_control_sm to correctly handle bus lock situations. Note that this signal
-- doesn't reflect the actual locked state of the bus since the PLB doesn't
-- consider the bus truly locked until the slave addrAcks the buslock request.
-- This signal will assert when the Master asserts busLock - it does not wait
-- for the slave addrAck. This is so the arb_control_sm can correctly wait for
-- both buses to be idle before issuing PAValid. This signal does wait to negate
-- for one clock after the Master bus lock negates so that the arb_control_sm will
-- still see the bus as locked even though the master's signal has been negated.
-- The PLB specification requires that the bus remain locked for one clock after
-- the master's buslock signal is negated.
-------------------------------------------------------------------------------
SMBUSLOCK_REG_PROCESS: process (Clk)
begin
    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE) then
            sm_buslock_reg <= '0';
        else
            sm_buslock_reg <= Mstr_buslock;
        end if;
    end if;
end process SMBUSLOCK_REG_PROCESS;

SM_busLock <= sm_buslock_reg or Mstr_buslock;

end implementation;

