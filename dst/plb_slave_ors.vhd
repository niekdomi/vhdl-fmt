-------------------------------------------------------------------------------
--  $Id: plb_slave_ors.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- plb_slave_ors.vhd - entity/architecture pair
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
-- Filename:        plb_slave_ors.vhd
-- Version:         v1.01a
-- Description:     This file contains the OR gates for the slave inputs
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

-- PROC_COMMON library contains OR Gate component
library proc_common_v1_00_b;
use proc_common_v1_00_b.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_NUM_MASTERS
--          C_NUM_SLAVES                -- number of slaves
--          C_PLB_DWIDTH                -- data bus width
--
-- Definition of Ports:
--      --  Slave signals
--          input Sl_addrAck(0 to C_NUM_SLAVES-1)
--          input Sl_MErr(0 to C_NUM_SLAVES*C_NUM_MASTERS-1)
--          input Sl_MBusy(0 to C_NUM_SLAVES*C_NUM_MASTERS-1)
--          input Sl_rdBTerm(0 to C_NUM_SLAVES-1)
--          input Sl_rdComp(0 to C_NUM_SLAVES-1)
--          input Sl_rdDAck(0 to C_NUM_SLAVES-1)
--          input Sl_rdDBus(0 to C_NUM_SLAVES*C_PLB_DWIDTH-1)
--          input Sl_rdWdAddr(0 to C_NUM_SLAVES*4-1)
--          input Sl_rearbitrate(0 to C_NUM_SLAVES-1)
--          input Sl_SSize(0 to C_NUM_SLAVES*2-1)
--          input Sl_wait(0 to C_NUM_SLAVES-1)
--          input Sl_wrBTerm(0 to C_NUM_SLAVES-1)
--          input Sl_wrComp(0 to C_NUM_SLAVES-1)
--          input Sl_wrDAck(0 to C_NUM_SLAVES-1)
--
--      -- PLB signals (output of slave OR gate)
--          output PLB_SaddrAck
--          output PLB_SMErr(0 to C_NUM_MASTERS-1)
--          output PLB_SMBusy(0 to C_NUM_MASTERS-1)
--          output PLB_SrdBTerm
--          output PLB_SrdComp
--          output PLB_SrdDAck
--          output PLB_SrdDBus(0 to C_PLB_DWIDTH-1)
--          output PLB_SrdWdAddr(0 to3)
--          output PLB_Srearbitrate
--          output PLB_Sssize(0 to 1)
--          output PLB_Swait
--          output PLB_SwrBTerm
--          output PLB_SwrComp
--          output PLB_SwrDAck
--
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_slave_ors is
  generic ( C_NUM_MASTERS   : integer   := 8;
            C_NUM_SLAVES    : integer   := 8;
            C_PLB_DWIDTH    : integer   := 64
          );
  port (
        Sl_addrAck      : in std_logic_vector(0 to C_NUM_SLAVES - 1 );
        Sl_MErr         : in std_logic_vector(0 to C_NUM_SLAVES*C_NUM_MASTERS - 1 );
        Sl_MBusy        : in std_logic_vector(0 to C_NUM_SLAVES*C_NUM_MASTERS - 1 );
        Sl_rdBTerm      : in std_logic_vector(0 to C_NUM_SLAVES - 1);
        Sl_rdComp       : in std_logic_vector(0 to C_NUM_SLAVES - 1);
        Sl_rdDAck       : in std_logic_vector(0 to C_NUM_SLAVES - 1);
        Sl_rdDBus       : in std_logic_vector(0 to C_NUM_SLAVES*C_PLB_DWIDTH - 1 );
        Sl_rdWdAddr     : in std_logic_vector(0 to C_NUM_SLAVES*4 - 1 );
        Sl_rearbitrate  : in std_logic_vector(0 to C_NUM_SLAVES - 1 );
        Sl_SSize        : in std_logic_vector(0 to C_NUM_SLAVES*2 - 1 );
        Sl_wait         : in std_logic_vector(0 to C_NUM_SLAVES - 1 );
        Sl_wrBTerm      : in std_logic_vector(0 to C_NUM_SLAVES - 1 );
        Sl_wrComp       : in std_logic_vector(0 to C_NUM_SLAVES - 1 );
        Sl_wrDAck       : in std_logic_vector(0 to C_NUM_SLAVES - 1 );
        
        PLB_SaddrAck    : out std_logic;
        PLB_SMErr       : out std_logic_vector(0 to C_NUM_MASTERS-1);   
        PLB_SMBusy      : out std_logic_vector(0 to C_NUM_MASTERS-1);   
        PLB_SrdBTerm    : out std_logic;   
        PLB_SrdComp     : out std_logic;
        PLB_SrdDAck     : out std_logic;
        PLB_SrdDBus     : out std_logic_vector(0 to C_PLB_DWIDTH-1);   
        PLB_SrdWdAddr   : out std_logic_vector(0 to 3);
        PLB_Srearbitrate: out std_logic;
        PLB_Sssize      : out std_logic_vector(0 to 1);
        PLB_Swait       : out std_logic;
        PLB_SwrBTerm    : out std_logic;
        PLB_SwrComp     : out std_logic;
        PLB_SwrDAck     : out std_logic
        
        );

end plb_slave_ors;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture implementation of plb_slave_ors is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
signal plb_saddrack_i       : std_logic_vector(0 to 0);
signal plb_smerr_i          : std_logic_vector(0 to C_NUM_MASTERS-1); 
signal plb_smbusy_i         : std_logic_vector(0 to C_NUM_MASTERS-1); 
signal plb_srdbterm_i       : std_logic_vector(0 to 0);   
signal plb_srdcomp_i        : std_logic_vector(0 to 0);
signal plb_srddack_i        : std_logic_vector(0 to 0);
signal plb_srddbus_i        : std_logic_vector(0 to C_PLB_DWIDTH-1);  
signal plb_srdwdaddr_i      : std_logic_vector(0 to 3);
signal plb_srearbitrate_i   : std_logic_vector(0 to 0);
signal plb_sssize_i         : std_logic_vector(0 to 1);
signal plb_swait_i          : std_logic_vector(0 to 0);
signal plb_swrbterm_i       : std_logic_vector(0 to 0);
signal plb_swrcomp_i        : std_logic_vector(0 to 0);
signal plb_swrdack_i        : std_logic_vector(0 to 0);

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- The OR_GATE ORs the slave inputs

component or_gate is
  generic (
    C_OR_WIDTH   : natural range 1 to 32 := 17;
    C_BUS_WIDTH  : natural range 1 to 64 := 1;
    C_USE_LUT_OR : boolean := TRUE
    );
  port (
    A : in  std_logic_vector(0 to C_OR_WIDTH*C_BUS_WIDTH-1);
    Y : out std_logic_vector(0 to C_BUS_WIDTH-1)
    );
end component or_gate;
 
 
-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
-- assign internal signals to output ports
PLB_SaddrAck        <=   plb_saddrack_i(0);    
PLB_SMErr           <=   plb_smerr_i;       
PLB_SMBusy          <=   plb_smbusy_i;      
PLB_SrdBTerm        <=   plb_srdbterm_i(0);    
PLB_SrdComp         <=   plb_srdcomp_i(0);     
PLB_SrdDAck         <=   plb_srddack_i(0);     
PLB_SrdDBus         <=   plb_srddbus_i;     
PLB_SrdWdAddr       <=   plb_srdwdaddr_i;  
PLB_Srearbitrate    <=   plb_srearbitrate_i(0);
PLB_Sssize          <=   plb_sssize_i ;     
PLB_Swait           <=   plb_swait_i(0);       
PLB_SwrBTerm        <=   plb_swrbterm_i(0);    
PLB_SwrComp         <=   plb_swrcomp_i(0);     
PLB_SwrDAck         <=   plb_swrdack_i(0);     

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- Set the generics on the OR gates to use MUXCY, not LUTs

-- Instantiate the Slave OR gates for Sl_addrAck
ADDRACK_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_addrAck,
                  Y => plb_saddrack_i);

-- Instantiate the Slave OR gates for Sl_MErr
MERR_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => C_NUM_MASTERS,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_MErr,
                  Y => plb_smerr_i);                  

-- Instantiate the Slave OR gates for Sl_MBusy
MBUSY_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => C_NUM_MASTERS,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_MBusy,
                  Y => plb_smbusy_i);

-- Instantiate the Slave OR gates for Sl_rdBTerm
RDBTERM_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_rdBTerm,
                  Y => plb_srdbterm_i); 

-- Instantiate the Slave OR gates for Sl_rdComp
RDCOMP_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_rdComp,
                  Y => plb_srdcomp_i);

-- Instantiate the Slave OR gates for Sl_rdDAck
RDDACK_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_rdDAck,
                  Y => plb_srddack_i);

-- Instantiate the Slave OR gates for Sl_rdDBus
-- For now, simply OR the busses - this assumes 64-bit PLB and 64-bit slaves
-- NEED TO ADD BUS MIRRORING LOGIC!!!
RDBUS_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => C_PLB_DWIDTH,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_rdDBus,
                  Y => plb_srddbus_i);

-- Instantiate the Slave OR gates for Sl_rdWdAddr
RDWDADDR_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 4,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_rdWdAddr,
                  Y => plb_srdwdaddr_i);

-- Instantiate the Slave OR gates for Sl_rearbitrate
REARB_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_rearbitrate,
                  Y => plb_srearbitrate_i);

-- Instantiate the Slave OR gates for Sl_SSize
SSIZE_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 2,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_SSize,
                  Y => plb_sssize_i);

-- Instantiate the Slave OR gates for Sl_wait
WAIT_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_wait,
                  Y => plb_swait_i);

-- Instantiate the Slave OR gates for Sl_wrBTerm
WRBTERM_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_wrBTerm,
                  Y => plb_swrbterm_i);

-- Instantiate the Slave OR gates for Sl_wrComp
WRCOMP_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_wrComp,
                  Y => plb_swrcomp_i);

-- Instantiate the Slave OR gates for Sl_wrDAck
WRDACK_OR: or_gate
    generic map (C_OR_WIDTH     => C_NUM_SLAVES,
                 C_BUS_WIDTH    => 1,
                 C_USE_LUT_OR   => TRUE)
    port map    ( A => Sl_wrDAck,
                  Y => plb_swrdack_i);
                  
end implementation;



