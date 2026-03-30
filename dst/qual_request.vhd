-------------------------------------------------------------------------------
--  $Id: qual_request.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- qual_request.vhd - entity/architecture pair
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
-- Filename:        qual_request.vhd
-- Version:         v1.01a
-- Description:     This file qualifies a master request with the master's 
--                  abort signal and the arbiter disable request register. It
--                  then decodes the priority bits of that master, generating
--                  signals indicating which priority level the master is
--                  requesting.
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

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      No generics used
--
-- Definition of Ports:
--      input Request               -- master's request signal
--      input ArbDisReqReg          -- bit indicating if this master is disabled
--      input Abort                 -- master's abort signal
--      input Priority              -- master's priority bits
--
--      output Lvl0                 -- indicates master had a level 1 request
--      output Lvl1                 -- indicates master had a level 2 request
--      output Lvl2                 -- indicates master had a level 3 request
--      output Lvl3                 -- indicates master had a level 4 request
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity qual_request is
    port (
          Request       : in std_logic;
          ArbDisReqReg  : in std_logic;
          Abort         : in std_logic;
          Priority      : in std_logic_vector(0 to 1 );
          Lvl0          : out std_logic;
          Lvl1          : out std_logic;
          Lvl2          : out std_logic;
          Lvl3          : out std_logic
          );
 
end qual_request;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of qual_request is
 
 
-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------
-- QUAL_REQ_PROCESS
-------------------------------------------------------------------------------
-- This process qualifies the master's request with abort and ArbDisReqReg
-- and then decodes the master's priority into the appropriate priority level
-- signal
-------------------------------------------------------------------------------
QUAL_REQ_PROCESS:process (Request, ArbDisReqReg, Priority, abort)
begin   

-- initialize all level signals to 0
Lvl0 <= '0';
Lvl1 <= '0';
Lvl2 <= '0';
Lvl3 <= '0';

if (Request AND NOT (ArbDisReqReg) AND NOT (Abort)) = '1' then
    
    -- valid request signal, decode the priority bits
    
    case Priority is

        when "00" =>
                Lvl0 <= '1';

        when "01" =>
                Lvl1 <= '1';

        when "10" =>
                Lvl2 <= '1';

        when "11" =>
                Lvl3 <= '1';

        when others  =>
                Lvl0 <= 'X';
                Lvl1 <= 'X';
                Lvl2 <= 'X';
                Lvl3 <= 'X';
    end case;
end if;

end process;

end simulation;

