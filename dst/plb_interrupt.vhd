-------------------------------------------------------------------------------
--  $Id: plb_interrupt.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- plb_interrupt.vhd - entity/architecture pair
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
--  Filename:     plb_interrupt.vhd
--  Version:      v1.01a
--  Description:
--    This module generates an edge-type interrupt whenever a bus error is 
--    detected. The active state of the interrupt is determined by the
--    C_IRQ_ACTIVE parameter. The pulse is one-clock wide.
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
-- Author:      
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
use ieee.std_logic_UNSIGNED.all;
 
library unisim;
use unisim.vcomponents.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.all;
use proc_common_v1_00_b.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_IRQ_ACTIVE                -- active edge of interrupt - rising or falling
--
-- Definition of Ports:
--      input  Clk                  -- clock
--      input  Rst                  -- reset
--      input  WdtCountIsZero       -- watchdog timeout
--      input  WdtAddrAck           -- watchdog timer address ack
--      input  Sl_addrAck           -- slave address ack
--      input  Intr_en              -- interrupt enable
--
--      output Bus_Error_Det        -- edge interrupt
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_interrupt is
    generic( C_IRQ_ACTIVE   : std_logic := '1'
            );
  port (
        Clk             : in std_logic;
        Rst             : in std_logic;
        WdtCountIsZero  : in std_logic;
        WdtAddrAck      : in std_logic;
        Sl_addrAck      : in std_logic;
        Intr_en         : in std_logic;
        Bus_Error_Det   : out std_logic
        );
end plb_interrupt;
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture plb_interrupt of plb_interrupt is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- internal signal for output
signal bus_error_det_i      : std_logic;

-- d input to registers
signal bus_error_det_d      : std_logic;

-- PLB Bus pipeline signals
signal wdtcountiszero_d1    : std_logic;
signal wdtaddrack_d1        : std_logic;
signal sl_addrack_d1        : std_logic;

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
-- assign internal signal to output
Bus_Error_Det <= bus_error_det_i;

-- register PLB bus input signals
PLB_BUS_REGS: process (Clk)
begin
    if Clk'event and Clk = '1' then
        if Rst = RESET_ACTIVE then
            wdtcountiszero_d1 <= '0';
            wdtaddrack_d1 <= '0';
            sl_addrack_d1 <= '0';
        else
           wdtcountiszero_d1 <= wdtCountIsZero;
           wdtaddrack_d1 <= wdtAddrAck;
           sl_addrack_d1 <= Sl_addrAck;
        end if;
    end if;
end process PLB_BUS_REGS;

RISING_EDGE_GEN: if C_IRQ_ACTIVE = '1' generate

    bus_error_det_d <= not(bus_error_det_i) and wdtcountiszero_d1 and
                        wdtaddrack_d1 and not(sl_addrack_d1);
    
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

    bus_error_det_d <= not(bus_error_det_i and wdtcountiszero_d1 and
                        wdtaddrack_d1 and not(sl_addrack_d1));

    INTERRUPT_FEFF_I: FDSE
      port map (
                Q   => bus_error_det_i,     --[out]
                C   => Clk,                 --[in]
                CE  => Intr_en,             --[in]
                D   => bus_error_det_d,     --[in]
                S   => Rst                  --[in]
                );
end generate FALLING_EDGE_GEN;

end;

