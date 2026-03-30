-------------------------------------------------------------------------------
--  $Id: gen_qual_req.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- gen_qual_req.vhd - entity/architecture pair
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
--  Filename:        gen_qual_req.vhd
--  Version:         v1.01a
--  Description:     This logic asserts QualReq if any master is requesting the
--                   bus and is not disabled and has not asserted its abort 
--                   signal. The QualReq signal is used to transition the 
--                   arb_control_sm from the IDLE state to the MASTERSEL1 state.
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
--  Author:      Bert Tise
--  History:
--      ALS     02/20/02        -- created from plb_arbiter_v1_01_a
--      ALS     04/16/02        -- Version v1.01a
-- -----------------------------------------------------------------------------
--  Naming Conventions:
--       active low signals:                     "*_n"
--       clock signals:                          "clk", "clk_div#", "clk_#x"
--       reset signals:                          "rst", "rst_n"
--       generics:                               "C_*"
--       user defined types:                     "*_TYPE"
--       state machine next state:               "*_ns"
--       state machine current state:            "*_cs"
--       combinatorial signals:                  "*_cmb"
--       pipelined or register delay signals:    "*_d#"
--       counter signals:                        "*cnt*"
--       clock enable signals:                   "*_ce"
--       internal version of output port         "*_i"
--       device pins:                            "*_pin"
--       ports:                                  - Names begin with Uppercase
--       processes:                              "*_PROCESS"
--       component instantiations:               "<ENTITY_>I_<#|FUNC>
-- -----------------------------------------------------------------------------
 
library ieee;
use ieee.STD_LOGIC_1164.all;
 
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--
-- Definition of Ports:
--      input M_request             -- array of all master request signals
--      input M_abort               -- array of all master abort signals
--      input ArbDisMReqReg         -- register holding disabled masters
--
--      output QualReq              -- valid request is waiting
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity gen_qual_req is
    generic (C_NUM_MASTERS  : integer   := 8);
    port (
            QualReq         : out std_logic;
            M_request       : in  std_logic_vector(0 to C_NUM_MASTERS-1);
            ArbDisMReqReg   : in  std_logic_vector(0 to C_NUM_MASTERS-1);
            M_abort         : in  std_logic_vector(0 to C_NUM_MASTERS-1)
         );
end gen_qual_req;
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of gen_qual_req is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- temp signal to hold intermediate OR values
signal temp     : std_logic_vector(0 to C_NUM_MASTERS-1) := (others => '0'); 
 
-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-- Loop through each master. AND the master's request with its inverted abort
-- signal and inverted bit in the disable register. Then OR all of these
-- results to determine if a valid request is pending.

QUAL_REQ_GEN: for i in 0 to C_NUM_MASTERS -1 generate

        ZERO: if i = 0 generate
        
            temp(i) <= (M_request(i) and not ArbDisMReqReg(i) and not M_abort(i));
            
        end generate ZERO;
        
        OTHER_BITS: if i /= 0 generate
        
            temp(i) <= temp(i-1) or (M_request(i) and not ArbDisMReqReg(i) and not M_abort(i));
            
        end generate OTHER_BITS;
        
end generate QUAL_REQ_GEN;
        

QualReq <= temp(C_NUM_MASTERS-1);

 
end simulation;

