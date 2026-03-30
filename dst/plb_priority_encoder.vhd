-------------------------------------------------------------------------------
-- $Id: plb_priority_encoder.vhd,v 1.2 2004/11/23 01:15:02 jcanaris Exp $
------------------------------------------------------------------------------
-- plb_priority_encoder.vhd - entity/architecture pair
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
-- Filename:        plb_priority_encoder.vhd
-- Version:         v1.01a
-- Description:     Priority encoder selects the master with highest priority
--                  on the M_priority bits. If there are two masters with the
--                  same priority inputs, Master 0 has the highest priority
--                  followed by Master 1, Master 2, etc. This is described as
--                  fixed priority.
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
--      ALS     02/22/02        -- corrected init string on avoid_map_error LUT
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
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

-- PROC_COMMON library contains mux_onehot component
library proc_common_v1_00_b;
use proc_common_v1_00_b.all;

library unisim;
use unisim.vcomponents.all;

library plb_v34_v1_02_a;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_NUM_MASTERS               -- number of masters
--          C_NUM_MSTRS_PAD             -- number of masters padded to next
--                                      -- power of 2
--
-- Definition of Ports:
--      -- Master Signals
--          input M_abort               -- array containing all master aborts
--          input M_priority            -- array containing all master priority
--          input M_request             -- array containing all master requests
--
--      -- Bus State Signals
--          input ArbDisMReqReg         -- masters with disabled requests
--          input ArbSecRdInProgReg     -- secondary read in progress
--          input SecRdInProgPriorReg   -- priority of secondary read
--          input ArbSecWrInProgReg     -- secondary write in progress
--          input SecWrInProgPriorReg   -- priority of secondary write
--          input LoadAddrSelReg        -- indicates when priority encoder
--                                      -- output can be registered
--      -- Outputs
--          output ArbAddrSelReg        -- one-hot register indicating which
--                                      -- master has the bus
--          output PLB_pendPri          -- highest priority of all pending rqsts
--          output PLB_pendReq          -- indicates a request is pending
--          output PLB_reqPri           -- indicates the priority of the rqst
--
--      -- Clock and Reset
--          input Clk
--          input ArbReset
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_priority_encoder is
    generic (
             C_NUM_MASTERS  : integer   := 8;
             C_NUM_MSTRS_PAD: integer   := 8
             );
    port (
          ArbAddrSelReg     : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
          ArbDisMReqReg     : in std_logic_vector(0 to C_NUM_MSTRS_PAD - 1 );
          ArbReset          : in std_logic;
          ArbSecRdInProgReg : in std_logic;
          ArbSecWrInProgReg : in std_logic;
          Clk               : in std_logic;
          LoadAddrSelReg    : in std_logic;
          M_abort           : in std_logic_vector(0 to C_NUM_MSTRS_PAD - 1 );
          M_priority        : in std_logic_vector(0 to C_NUM_MSTRS_PAD * 2 - 1 );
          M_request         : in std_logic_vector(0 to C_NUM_MSTRS_PAD - 1 );
          PLB_pendPri       : out std_logic_vector(0 to 1 );
          PLB_pendReq       : out std_logic;
          PLB_reqPri        : out std_logic_vector(0 to 1 );
          SecRdInProgPriorReg : in std_logic_vector(0 to 1 );
          SecWrInProgPriorReg : in std_logic_vector(0 to 1 )
          );


end plb_priority_encoder;

-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of plb_priority_encoder is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

signal arbAddrSelReg_i  : std_logic_vector(0 to C_NUM_MASTERS - 1 );
signal plb_pendReq_i    : std_logic;
signal prioencdrOutput  : std_logic_vector(0 to C_NUM_MSTRS_PAD - 1 );

-- dummy signal to provide connection for prioencdroutputs that are unused
-- map reports an error for muxcy outputs that are not connected
-- this signal will simply be the and_reduce function of the unused muxcy outputs
signal avoid_map_error  : std_logic := '0';

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- Priority encoder determines winning master based on priority bits. If there
-- is a tie, Master 0 has priority, then Master 1, Master 2, etc.

-- The pending priority component determines the highest level priority bits
-- of all requesting masters and secondary transactions

-- The pend_request component asserts PLB_pendReq if any masters are requesting
-- the bus or there is a secondary transaction in progress

-- Arb_addr_sel contains the register that holds the output of the priority
-- encoder. It is loaded at the appropriate time when LoadAddrSelReg is
-- asserted. LoadAddrSelReg is an output of arb_control_sm

-- The mux_onehot component implements a mux with one-hot select signals
-- using the carry chain multiplexors

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------
-- assign internal signals to the outputs
-------------------------------------------------------------------------------
ArbAddrSelReg   <= arbAddrSelReg_i;
PLB_pendReq     <= plb_pendReq_i;

-------------------------------------------------------------------------------
-- Component instantiations
-------------------------------------------------------------------------------
-- Priority encoder determines winning master based on priority bits. If there
-- is a tie, Master 0 has priority, then Master 1, Master 2, etc. This component
-- uses the padded number of masters and padded buses.
I_PRIOR_ENC: entity plb_v34_v1_02_a.priority_encoder
    generic map (C_NUM_MASTERS  => C_NUM_MSTRS_PAD)
    port map (
              M_request         => M_request(0 to C_NUM_MSTRS_PAD-1),
              M_priority        => M_priority(0 to C_NUM_MSTRS_PAD*2-1),
              M_abort           => M_abort(0 to C_NUM_MSTRS_PAD-1),
              ArbDisMReqReg     => ArbDisMReqReg(0 to C_NUM_MSTRS_PAD-1),
              PrioencdrOutput   => prioencdrOutput
              );
AVOID_MAPERR_GEN: if C_NUM_MASTERS /= C_NUM_MSTRS_PAD generate
AVOID_MAP_ERR_LUT: LUT4
  generic map(INIT => X"1111")
  port map (
    O => avoid_map_error, --[out]
    I0 => prioencdrOutput(C_NUM_MSTRS_PAD-1), --[in]
    I1 => prioencdrOutput(C_NUM_MSTRS_PAD-2), --[in]
    I2 => prioencdrOutput(C_NUM_MSTRS_PAD-3), --[in]
    I3 => prioencdrOutput(C_NUM_MSTRS_PAD-4) --[in]
  );
end generate AVOID_MAPERR_GEN;

-- The pending priority component determines the highest level priority bits
-- of all requesting masters and secondary transactions. It doesn't need the
-- padded version of buses or number of masters.
I_PEND_PRIOR: entity plb_v34_v1_02_a.pending_priority
    generic map (C_NUM_MASTERS  => C_NUM_MASTERS)
    port map (
              M_request         => M_request(0 to C_NUM_MASTERS-1),
              M_priority        => M_priority(0 to C_NUM_MASTERS*2 -1),
              ArbSecRdInProgReg => ArbSecRdInProgReg,
              SecRdInProgPriorReg => SecRdInProgPriorReg,
              ArbSecWrInProgReg => ArbSecWrInProgReg,
              SecWrInProgPriorReg => SecWrInProgPriorReg,
              PLB_pendPri       => PLB_pendPri
              );

-- The pend_request component asserts PLB_pendReq if any masters are requesting
-- the bus or there is a secondary transaction in progress. It doesn't operate
-- on the padded version of buses or masters.
I_PEND_REQ: entity plb_v34_v1_02_a.pend_request
    generic map (C_NUM_MASTERS  => C_NUM_MASTERS)
    port map (
              M_request         => M_request(0 to C_NUM_MASTERS-1),
              ArbSecRdInProgReg => ArbSecRdInProgReg,
              ArbSecWrInProgReg => ArbSecWrInProgReg,
              PLB_pendReq       => plb_pendReq_i
              );

-- Arb_addr_sel contains the register that holds the output of the priority
-- encoder. It is loaded at the appropriate time when LoadAddrSelReg is
-- asserted. LoadAddrSelReg is an output of arb_control_sm. It doesn't operate
-- on the padded version of the priority encoder output or the number of
-- masters.
I_ARBADDRSEL: entity plb_v34_v1_02_a.arb_addr_sel
    generic map (C_NUM_MASTERS  => C_NUM_MASTERS)
    port map (
              Clk               => Clk,
              PrioencdrOutput   => prioencdrOutput(0 to C_NUM_MASTERS-1),
              LoadAddrSelReg    => LoadAddrSelReg,
              ArbReset          => ArbReset,
              ArbAddrSelReg     => arbAddrSelReg_i
              );

-- The mux_onehot component implements a mux with one-hot select signals
-- using the carry chain multiplexors. PLB_reqPri reflects the priority
-- of the master controlling the bus. It doesn't operate on the padded
-- version of buses or number of masters.
I_REQ_PRIOR: entity proc_common_v1_00_b.mux_onehot
    generic map (C_DW       => 2,
                 C_NB       => C_NUM_MASTERS)
    port map (
              D             => M_priority(0 to C_NUM_MASTERS*2 -1),
              S             => arbAddrSelReg_i,
              Y             => PLB_reqPri
              );

end simulation;

