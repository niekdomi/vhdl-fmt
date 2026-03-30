-------------------------------------------------------------------------------
--  $Id: pend_request.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- pend_request.vhd - entity/architecture pair
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
-- Filename:        pending_request.vhd
-- Version:         v1.01a
-- Description:     This file simply ORs together the Master's requests along
--                  with the state of the secondary read/write transactions
--                  to determine if there is a pending request.
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
library ieee;
use ieee.std_logic_1164.all;

-- UNISIM library is required when Xilinx primitives are instantiated
library unisim;
use unisim.vcomponents.all;

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
--
--      -- Secondary Read/Write signals
--          input   arbSecRdInProgReg   -- indicates there is a secondary read
--                                      -- in progress
--          input   arbSecWrInProgReg   -- indicates there is a secondary write
--                                      -- in progress
--      -- Output
--          output  PLB_pendReq         -- pending request
--      
-------------------------------------------------------------------------------
-- 
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity pend_request is
    generic (
            C_NUM_MASTERS       : integer   := 8
            );
    port    (
            M_request           : in    std_logic_vector(0 to C_NUM_MASTERS-1);
            ArbSecRdInProgReg   : in    std_logic;
            ArbSecWrInProgReg   : in    std_logic;
            PLB_pendReq         : out   std_logic
            );
end pend_request;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of pend_request is
-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- No constants are required for this design
-------------------------------------------------------------------------------
-- Signal and Type Declarations
------------------------------------------------------------------------------- 
-- Carry chain mux outputs
-- the carry chain mux implements an OR of all of the master's request signals 
-- plus the secondary read and secondary write in progress signals
signal req_mux      : std_logic_vector(0 to (C_NUM_MASTERS-1) +2);

-- Select lines are the request signals and ArbSecRd/WrInProgReg NEGATED
signal arbSecRdInProgReg_n  : std_logic;
signal arbSecWrInProgReg_n  : std_logic;
signal m_request_n          : std_logic_vector(0 to C_NUM_MASTERS-1);

-- Define signals for '1' and '0'
signal zero                 : std_logic := '0';
signal one                  : std_logic := '1';

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-- generate negated signals for mux selects
arbSecRdInProgReg_n <= not(ArbSecRdInProgReg);
arbSecWrInProgReg_n <= not(ArbSecWrInProgReg);


-------------------------------------------------------------------------------
-- NEGATE_REQS 
-------------------------------------------------------------------------------
-- This generates the active low Master request signals to correctly configure 
-- the MUXCY chain as an OR gate
NEGATE_REQS_GENERATE: for i in 0 to C_NUM_MASTERS -1 generate
        m_request_n(i) <= not(M_request(i));
end generate NEGATE_REQS_GENERATE;
    
-------------------------------------------------------------------------------
-- Generate the carry chain to determine if there is a pending request.
-- The carry chain essentially implements a wide OR. The first mux in the
-- chain is for the secondary write, followed by the secondary read, then
-- followed by masters 0 - C_NUM_MASTERS-1
-------------------------------------------------------------------------------  
I_REQ_MUX0: MUXCY
    port map (
            O   => req_mux(0),
            CI  => zero,
            DI  => one,
            S   => arbSecWrInProgReg_n
            );
I_REQ_MUX1: MUXCY
    port map (
            O   => req_mux(1),
            CI  => req_mux(0),
            DI  => one,
            S   => arbSecRdInProgReg_n
            );
-- generate the carry muxes for the masters
REQ_MASTERS_MUXES: for n in 2 to (C_NUM_MASTERS-1)+2 generate

        I_MASTERREQ_MUX:   MUXCY
            port map (
                    O   => req_mux(n),
                    CI  => req_mux(n-1),
                    DI  => one,
                    S   => m_request_n(n-2)
                    );
                    
end generate REQ_MASTERS_MUXES;

-------------------------------------------------------------------------------
-- Generate Pending Request output signal
-------------------------------------------------------------------------------
PLB_pendReq <= req_mux((C_NUM_MASTERS-1)+2);

end ;

