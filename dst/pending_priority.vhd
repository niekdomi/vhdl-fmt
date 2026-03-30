-------------------------------------------------------------------------------
--  $Id: pending_priority.vhd,v 1.2 2004/11/23 01:15:02 jcanaris Exp $
-------------------------------------------------------------------------------
-- pending_priority.vhd - entity/architecture pair
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
-- Filename:        pending_priority.vhd
-- Version:         v1.01a
-- Description:     This file outputs the highest priority of all requesting
--                  master and the priorities of the secondary read/write
--                  transactions.
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
--  LCW	Oct 15, 2004	  -- updated for NCSim
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
library ieee;
use ieee.std_logic_1164.all;

-- UNISIM library is required whenever Xilinx primitives are instantiated
library unisim;
use unisim.vcomponents.all;

library plb_v34_v1_02_a;
use plb_v34_v1_02_a.qual_priority;




-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_NUM_MASTERS               -- number of PLB masters
--
-- Definition of Ports:
--
--      -- Master interface signals
--          input   M_request           -- array of masters requests
--          input   M_priority          -- array of masters priorities
--
--      -- Secondary Read/Write signals
--          input   ArbSecRdInProgReg   -- indicates there is a secondary read
--                                      -- in progress
--          input   SecRdInProgPriorReg -- priority of secondary read
--          input   ArbSecWrInProgReg   -- indicates there is a secondary write
--                                      -- in progress
--          input   SecWrInProgPriorReg -- priority of secondary write
--
--      -- Output
--          output  PLB_pendPri         -- pending priority
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity pending_priority is
    generic (
            C_NUM_MASTERS       : integer   := 8
            );
    port    (
            M_request           : in    std_logic_vector(0 to C_NUM_MASTERS-1);
            M_priority          : in    std_logic_vector(0 to C_NUM_MASTERS*2-1);
            ArbSecRdInProgReg   : in    std_logic;
            SecRdInProgPriorReg : in    std_logic_vector(0 to 1);
            ArbSecWrInProgReg   : in    std_logic;
            SecWrInProgPriorReg : in    std_logic_vector(0 to 1);
            PLB_pendPri         : out   std_logic_vector(0 to 1)
            );
end pending_priority;


-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of pending_priority is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- No constants are required for this design
-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------
-- Decoded master levels
signal m_lvl3_n             : std_logic_vector(0 to C_NUM_MASTERS-1);
signal m_lvl2_n             : std_logic_vector(0 to C_NUM_MASTERS-1);
signal m_lvl1_n             : std_logic_vector(0 to C_NUM_MASTERS-1);

-- Secondary read/write levels
signal secrd_lvl3_n         : std_logic;
signal secrd_lvl2_n         : std_logic;
signal secrd_lvl1_n         : std_logic;

signal secwr_lvl3_n         : std_logic;
signal secwr_lvl2_n         : std_logic;
signal secwr_lvl1_n         : std_logic;

-- Carry chain mux outputs
-- the carry chain mux implements an OR of all of the master's level signals
-- plus the secondary read and secondary write level signals
signal lvl3_mux             : std_logic_vector(0 to (C_NUM_MASTERS+2) -1);
signal lvl2_mux             : std_logic_vector(0 to (C_NUM_MASTERS+2) -1);
signal lvl1_mux             : std_logic_vector(0 to (C_NUM_MASTERS+2) -1);

-- Define signals for the output of the wide or gate
-- these signals represent whether there is any request at this level
signal pendpri_lvl3         : std_logic;
signal pendpri_lvl2         : std_logic;
signal pendpri_lvl1         : std_logic;

-- Define signals for '1' and '0'
signal zero                 : std_logic := '0';
signal one                  : std_logic := '1';

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- MUXCYs (carry chain muxes) are used to implement OR function of master's lvl
-- signals and the secondary read/write lvl signals

-- QUAL_PRIORITY decodes the master's priority bits into the lvl signal IF the
-- master's request is asserted

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- Instantiate the qual_priority components for the secondary read/write
-- signals and the masters
-------------------------------------------------------------------------------
I_SECRD_LVL: entity plb_v34_v1_02_a.qual_priority
    port map (
            Request     => ArbSecRdInProgReg,
            Priority    => SecRdInProgPriorReg,
            Lvl1_n      => secrd_lvl1_n,
            Lvl2_n      => secrd_lvl2_n,
            Lvl3_n      => secrd_lvl3_n
             );

I_SECWR_LVL: entity plb_v34_v1_02_a.qual_priority
    port map (
            Request     => ArbSecWrInProgReg,
            Priority    => SecWrInProgPriorReg,
            Lvl1_n      => secwr_lvl1_n,
            Lvl2_n      => secwr_lvl2_n,
            Lvl3_n      => secwr_lvl3_n
             );

MASTER_LVLS: for n in 0 to C_NUM_MASTERS-1 generate

        I_QUAL_MASTERS_PRIORITY: entity plb_v34_v1_02_a.qual_priority
            port map (
                    Request     => M_request(n),
                    Priority    => M_priority(2*n to (2*n)+1),
                    Lvl1_n      => m_lvl1_n(n),
                    Lvl2_n      => m_lvl2_n(n),
                    Lvl3_n      => m_lvl3_n(n)
                    );
end generate MASTER_LVLS;
-------------------------------------------------------------------------------
-- Generate the carry chain to determine if there is a level3 request.
-- The carry chain essentially implements a wide OR. The first mux in the
-- chain is for the secondary write, followed by the secondary read, then
-- followed by masters 0 - C_NUM_MASTERS-1
-------------------------------------------------------------------------------
I_LVL3_MUX0: MUXCY
    port map (
            O   => lvl3_mux(0),
            CI  => zero,
            DI  => one,
            S   => secwr_lvl3_n
            );
I_LVL3_MUX1: MUXCY
    port map (
            O   => lvl3_mux(1),
            CI  => lvl3_mux(0),
            DI  => one,
            S   => secrd_lvl3_n
            );
-- generate the carry muxes for the masters
LVL3_MASTERS_MUXES: for n in 2 to (C_NUM_MASTERS-1)+2 generate

        I_MASTER_MUX:   MUXCY
            port map (
                    O   => lvl3_mux(n),
                    CI  => lvl3_mux(n-1),
                    DI  => one,
                    S   => m_lvl3_n(n-2)
                    );

end generate LVL3_MASTERS_MUXES;

-------------------------------------------------------------------------------
-- Generate the carry chain to determine if there is a level2 request.
-- The carry chain essentially implements a wide OR. The first mux in the
-- chain is for the secondary write, followed by the secondary read, then
-- followed by masters 0 - C_NUM_MASTERS-1
-------------------------------------------------------------------------------
I_LVL2_MUX0: MUXCY
    port map (
            O   => lvl2_mux(0),
            CI  => zero,
            DI  => one,
            S   => secwr_lvl2_n
            );
I_LVL2_MUX1: MUXCY
    port map (
            O   => lvl2_mux(1),
            CI  => lvl2_mux(0),
            DI  => one,
            S   => secrd_lvl2_n
            );
-- generate the carry muxes for the masters
LVL2_MASTERS_MUXES: for n in 2 to (C_NUM_MASTERS-1)+2 generate

        I_MASTER_MUX:   MUXCY
            port map (
                    O   => lvl2_mux(n),
                    CI  => lvl2_mux(n-1),
                    DI  => one,
                    S   => m_lvl2_n(n-2)
                    );

end generate LVL2_MASTERS_MUXES;

-------------------------------------------------------------------------------
-- Generate the carry chain to determine if there is a level1 request.
-- The carry chain essentially implements a wide OR. The first mux in the
-- chain is for the secondary write, followed by the secondary read, then
-- followed by masters 0 - C_NUM_MASTERS-1
-------------------------------------------------------------------------------
I_LVL1_MUX0: MUXCY
    port map (
            O   => lvl1_mux(0),
            CI  => zero,
            DI  => one,
            S   => secwr_lvl1_n
            );
I_LVL1_MUX1: MUXCY
    port map (
            O   => lvl1_mux(1),
            CI  => lvl1_mux(0),
            DI  => one,
            S   => secrd_lvl1_n
            );
-- generate the carry muxes for the masters
LVL1_MASTERS_MUXES: for n in 2 to (C_NUM_MASTERS-1)+2 generate

        I_MASTER_MUX:   MUXCY
            port map (
                    O   => lvl1_mux(n),
                    CI  => lvl1_mux(n-1),
                    DI  => one,
                    S   => m_lvl1_n(n-2)
                    );

end generate LVL1_MASTERS_MUXES;

-------------------------------------------------------------------------------
-- Generate Pending Priority output signals
-------------------------------------------------------------------------------
pendpri_lvl3 <= lvl3_mux((C_NUM_MASTERS-1)+2);
pendpri_lvl2 <= lvl2_mux((C_NUM_MASTERS-1)+2);
pendpri_lvl1 <= lvl1_mux((C_NUM_MASTERS-1)+2);

PLB_pendPri(0) <= '1' when pendpri_lvl3 = '1' or  pendpri_lvl2 = '1'
                  else '0';

PLB_pendPri(1) <= '1' when pendpri_lvl3 = '1' or
                  (pendpri_lvl1 = '1' and pendpri_lvl2 = '0')
                  else '0';

end simulation;
