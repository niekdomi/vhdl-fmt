-------------------------------------------------------------------------------
--  $Id: plb_wr_datapath.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- plb_wr_datapath.vhd - entity/architecture pair
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
-- Filename:        plb_wr_datapath.vhd
-- Version:         v1.01a
-- Description:     This file contains the multiplexors that choose which
--                  master's write data bus is output to the slaves. It also
--                  routes either the slave write data ack or the watchdog
--                  timer write data ack to the requesting master.
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
use ieee.STD_LOGIC_1164.all;

-- PROC_COMMON library contains mux_onehot component
library proc_common_v1_00_b;
use proc_common_v1_00_b.all;
 
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--      C_PLB_DWIDTH                -- data bus width
--
-- Definition of Ports:
--      input Sl_wrDack             -- slave write data acknowledge
--      input WdtwrDAck             -- watchdog timer write data acknowledge
--      input ArbPriWrMasterReg     -- register holding write master id
--      input M_wrDBus              -- Master write data bus
--
--      output PLB_MWrDAck          -- write data ack to master
--      output PLB_wrDBus           -- write data bus to slaves
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_wr_datapath is
  generic (C_NUM_MASTERS    : integer := 8;
           C_PLB_DWIDTH     : integer := 64);
  port (
        Sl_wrDAck           : in STD_LOGIC;
        WdtWrDAck           : in STD_LOGIC;
        ArbPriWrMasterReg   : in STD_LOGIC_VECTOR(0 to C_NUM_MASTERS - 1 );
        M_wrDBus            : in STD_LOGIC_VECTOR(0 to (C_NUM_MASTERS*C_PLB_DWIDTH) - 1 );
        PLB_MWrDAck         : out STD_LOGIC_VECTOR(0 to C_NUM_MASTERS - 1 );
        PLB_wrDBus          : out STD_LOGIC_VECTOR(0 to C_PLB_DWIDTH - 1 )
        );
end plb_wr_datapath;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of plb_wr_datapath is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- define a signal for the mux select line
signal wr_dack      : std_logic_vector(0 to 0);

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- The one-hot carry chain mux is used to multiplex the winning master's data
-- bus onto PLB_wrDBus

component mux_onehot 
   generic( C_DW: integer := 32;
            C_NB: integer := 5 );
   port(
      D: in std_logic_vector(0 to C_DW*C_NB-1);
      S: in std_logic_vector(0 to C_NB-1);
      Y: out std_logic_vector(0 to C_DW-1));

end component;

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- Instantiate the one-hot carry chain mux to multiplex the winning master's 
-- write data onto the PLB_wrDBus. The data width of the bus is the width
-- of the PLB data bus. The number of buses is equal to the number of masters

I_WRDBUS_MUX: mux_onehot
        generic map (   C_DW => C_PLB_DWIDTH,
                        C_NB => C_NUM_MASTERS)
        port map    (
                        D => M_wrDBus,
                        S => ArbPriWrMasterReg,
                        Y => PLB_wrDBus
                    );
 
-- Send the wrDAck (from the slave or the WDT) to the winning master
MSTR_WRDACK_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate
    
    PLB_MWrDAck(i) <= ArbPriWrMasterReg(i) and (Sl_wrDAck or WdtWrDAck);

end generate MSTR_WRDACK_GENERATE;

                    
end simulation;

