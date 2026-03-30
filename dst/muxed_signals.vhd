-------------------------------------------------------------------------------
--  $Id: muxed_signals.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- muxed_signals.vhd - entity/architecture pair
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
--  Filename:        muxed_signals.vhd
--  Version:         v1.01a
--  Description:     This file contains the multiplexors which route the 
--                   the controlling master's signals to the PLB bus and 
--                   the slave's signal to the controlling master.
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
use ieee.std_logic_1164.all;

-- PROC_COMMON_PKG contains the log2 function
-- PROC_COMMON library contains or_bits and mux_onehot components
library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;
use proc_common_v1_00_b.all;
  
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--      C_NUM_MSTRS_PAD             -- number of masters padded to power of 2
--      C_MID_BITS                  -- number of bits to encode master id
--
-- Definition of Ports:
--      -- Master signals
--      input  M_busLock
--      input  M_RNW    
--      input  M_abort  
--      input  M_rdBurst
--      input  M_wrBurst
--      
--      -- Slave signals
--      input  Sl_addrAck    
--      input  Sl_SSize      
--      input  Sl_rearbitrate
--      input  Sl_MBusy      
--      input  Sl_rdBTerm
--      input  Sl_wrBTerm
--      input  Sl_MErr
--
--      -- Arbiter signals
--      input  ArbAddrSelReg   
--      input  ArbAddrSelRegPad
--      input  ArbPriRdMasterReg   
--      input  ArbPriRdMasterRegReg
--      input  ArbPriWrMasterReg   
--      input  ArbWrDBusBusyReg
--      input  ArbPriRdBurstReg
--      output ArbAValid
--
--      -- Watchdog Timer signals
--      input  WdtAddrAck 
--      input  WdtRdBTerm 
--      input  WdtWrBTerm 
--      input  WdtTimeOutBusy
--      input  WdtRdDAck    
--      input  WdtWrDAck     
--
--      -- PLB signals
--      input  PLB_PAValid
--      input  PLB_SAValid
--      input  PLB_rdPrimReg
--      output PLB_masterID     
--      output PLB_RNW          
--      output PLB_abort        
--      output PLB_MAddrAck     
--      output PLB_MSSize           
--      output PLB_MRearbitrate 
--      output PLB_MBusy        
--      output PLB_rdBurst
--      output PLB_MRdBTerm     
--      output PLB_wrBurst      
--      output PLB_MWrBTerm     
--      output PLB_MErr  
--      output Mstr_buslock
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity muxed_signals is
    generic ( C_NUM_MASTERS     : integer   := 8;
              C_NUM_MSTRS_PAD   : integer   := 8;
              C_MID_BITS        : integer   := 3 
            );
    port (
        M_busLock           : in std_logic_vector (0 to C_NUM_MASTERS-1);
        M_RNW               : in std_logic_vector (0 to C_NUM_MASTERS-1);
        M_abort             : in std_logic_vector (0 to C_NUM_MASTERS-1);
        Sl_addrAck          : in std_logic;
        Sl_SSize            : in std_logic_vector (0 to 1);
        Sl_rearbitrate      : in std_logic;
        Sl_MBusy            : in std_logic_vector (0 to C_NUM_MASTERS-1);
        M_rdBurst           : in std_logic_vector (0 to C_NUM_MASTERS-1);
        Sl_rdBTerm          : in std_logic;
        M_wrBurst           : in std_logic_vector (0 to C_NUM_MASTERS-1);
        Sl_wrBTerm          : in std_logic;
        Sl_MErr             : in std_logic_vector (0 to C_NUM_MASTERS-1);
        WdtAddrAck          : in std_logic;
        WdtRdBTerm          : in std_logic;
        WdtWrBTerm          : in std_logic;
        ArbAddrSelReg       : in std_logic_vector (0 to C_NUM_MASTERS-1);
        ArbAddrSelRegPad    : in std_logic_vector (0 to C_NUM_MSTRS_PAD-1);
        PLB_PAValid         : in std_logic;
        PLB_SAValid         : in std_logic;
        ArbAValid           : out std_logic;
        ArbPriRdMasterReg   : in std_logic_vector (0 to C_NUM_MASTERS-1);
        ArbPriRdMasterRegReg: in std_logic_vector (0 to C_NUM_MASTERS-1);
        ArbPriWrMasterReg   : in std_logic_vector (0 to C_NUM_MASTERS-1);
        WdtTimeOutBusy      : in std_logic;
        WdtRdDAck           : in std_logic;
        WdtWrDAck           : in std_logic;
        ArbWrDBusBusyReg    : in std_logic;
        Mstr_buslock        : out std_logic;
        PLB_masterID        : out std_logic_vector (0 to C_MID_BITS-1);
        PLB_RNW             : out std_logic;
        PLB_abort           : out std_logic;
        PLB_MAddrAck        : out std_logic_vector (0 to C_NUM_MASTERS-1);
        PLB_MSSize              : out std_logic_vector (0 to (C_NUM_MASTERS * 2)-1);
        PLB_MRearbitrate    : out std_logic_vector (0 to C_NUM_MASTERS-1);
        PLB_MBusy           : out std_logic_vector (0 to C_NUM_MASTERS-1);
        PLB_rdBurst         : out std_logic;
        PLB_rdPrimReg       : in  std_logic;
        PLB_MRdBTerm        : out std_logic_vector (0 to C_NUM_MASTERS-1);
        PLB_wrBurst         : out std_logic;
        PLB_MWrBTerm        : out std_logic_vector (0 to C_NUM_MASTERS-1);
        PLB_MErr            : out std_logic_vector (0 to C_NUM_MASTERS-1);
        ArbPriRdBurstReg    : in std_logic
        );
end muxed_signals;

 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture implementation of muxed_signals is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- internal versions of output signals
signal arbAValid_i : std_logic;

-- when number of masters=2, a special case exists because 2 is a power of 2,
-- but is not a multiple of 4. Therefore, NUM_MSTRS_PAD =4 (padded to nearest
-- multiple of 4), but C_MID_BITS = 1 (log2(2)) not =2 (log2(4)). Therefore
-- the calculation of the master id doesn't work properly for this case. 
-- define an internal signal for the master id. When number of masters >2, the
-- output PLB_masterID will simply equal this signal, otherwise it will be
-- bit 1 of this signal.
signal plb_masterid_i   : std_logic_vector(0 to log2(C_NUM_MSTRS_PAD)-1);

-- intermediate burst signals
signal rd_burst     : std_logic_vector(0 to 0);
signal wr_burst     : std_logic_vector(0 to 0);

-- create internal versions of output signals which need to be 
-- std_logic_vector(0 to 0) to properly attach to the mux_onehot
signal buslock_i    : std_logic_vector(0 to 0);
signal plb_rnw_i    : std_logic_vector(0 to 0);
signal plb_abort_i  : std_logic_vector(0 to 0);

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- The one-hot carry chain mux is used to multiplex the winning master's 
-- control signals onto the PLB control signals

component mux_onehot 
   generic( C_DW: integer := 32;
            C_NB: integer := 5 );
   port(
      D: in std_logic_vector(0 to C_DW*C_NB-1);
      S: in std_logic_vector(0 to C_NB-1);
      Y: out std_logic_vector(0 to C_DW-1));

end component;
 
-- The OR_BITS component is used to OR together consecutive bits within sections
-- of a bus. This component is used to generate PLB_masterID
component or_bits
    generic( C_NUM_BITS     : integer   := 8;
             C_START_BIT    : integer   := 8;
             C_BUS_SIZE     : integer   := 16);
    port(
        In_Bus  : in std_logic_vector(0 to C_BUS_SIZE-1);
        Sig     : in std_logic;
        Or_out  : out std_logic
        );
end component;

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- BusLock generation
-------------------------------------------------------------------------------
--
--  3-19-01 ALS - Removed qualification with PLB_PAValid
--  3-20-01 ALS - Change PLB_busLock to BusLock; arbiter control state machine
--                now generates PLB_busLock
--  5-01-01 ALS - Changed name of BusLock to Mstr_buslock
--
-- Use one-hot carry mux for BusLock generation

BUSLOCK_MUX: mux_onehot
    generic map (   C_DW    => 1,
                    C_NB    => C_NUM_MASTERS)
    port map    (
                    D       => M_busLock,
                    S       => ArbAddrSelReg,
                    Y       => busLock_i(0 to 0)
                );
Mstr_buslock <= busLock_i(0);

-------------------------------------------------------------------------------
-- PLB_masterID generation
-------------------------------------------------------------------------------
-- Note this logic uses the padded version of C_NUM_MASTERS to insure that 
-- the calculations are on a constant which is a power of 2
-- Have to loop for the number of bits required for the padded number of masters

PLB_MID_GENERATE: for i in 0 to log2(C_NUM_MSTRS_PAD)-1 generate

signal temp_or  : std_logic_vector(0 to 2**i) := (others => '0');

begin
    OR_GENERATE: for j in 1 to 2**i generate
        
        BUS_OR: or_bits
            generic map ( C_NUM_BITS    => C_NUM_MSTRS_PAD/2**(i+1),
                          C_START_BIT   => C_NUM_MSTRS_PAD/2**(i+1)
                                            + (j-1)*C_NUM_MSTRS_PAD/2**i,
                          C_BUS_SIZE    => C_NUM_MSTRS_PAD
                        )
            port map (
                        In_Bus      => ArbAddrSelRegPad,
                        Sig         => temp_or(j-1),
                        Or_out      => temp_or(j)
                     );
    end generate OR_GENERATE;
    
    plb_masterid_i(i) <= temp_or(2**i);
    
end generate PLB_MID_GENERATE;

-- If number of masters <= 2, then PLB_masterID is only 1 bit, so need to get
-- LSB from plb_masterid_i. Otherwise, PLB_masterID = plb_masterid_i.

TWOMSTR_GEN: if C_NUM_MASTERS <= 2 generate
    PLB_masterID(0) <= plb_masterid_i(1);
end generate TWOMSTR_GEN;

OTHERMSTR_GEN: if C_NUM_MASTERS > 2 generate
    PLB_masterID <= plb_masterid_i;
end generate OTHERMSTR_GEN; 

-------------------------------------------------------------------------------
-- PLB_RNW generation
-------------------------------------------------------------------------------
-- Use one-hot carry mux for PLB_RNW generation

RNW_MUX: mux_onehot
    generic map (   C_DW    => 1,
                    C_NB    => C_NUM_MASTERS)
    port map    (
                    D       => M_RNW,
                    S       => ArbAddrSelReg,
                    Y       => plb_rnw_i(0 to 0)
                );
PLB_RNW <= plb_rnw_i(0);

-------------------------------------------------------------------------------
-- PLB_abort generation
-------------------------------------------------------------------------------
-- Use one-hot carry mux for PLB_abort generation

ABORT_MUX: mux_onehot
    generic map (   C_DW    => 1,
                    C_NB    => C_NUM_MASTERS)
    port map    (
                    D       => M_abort,
                    S       => ArbAddrSelReg,
                    Y       => plb_abort_i(0 to 0)
                );
PLB_abort <= plb_abort_i(0);

-------------------------------------------------------------------------------
-- ArbAValid generation - this signal is used internally as well as in the 
-- Priority encoder
-------------------------------------------------------------------------------
ArbAValid <= arbAValid_i;
arbAValid_i <= PLB_PAValid or PLB_SAValid;

-------------------------------------------------------------------------------
-- PLB_MAddrAck generation
-------------------------------------------------------------------------------
MADDRACK_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

    PLB_MAddrAck(i) <= arbAValid_i and arbAddrSelReg(i) and 
                    ((Sl_addrAck or wdtAddrAck));

end generate MADDRACK_GENERATE;

-------------------------------------------------------------------------------
-- PLB_MSSize     generation
-------------------------------------------------------------------------------
MSSIZE_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

    PLB_MSSize(i*2 to (i*2)+1) <= Sl_SSize when arbAddrSelReg(i) = '1'
                                    else (others => '0');

end generate MSSIZE_GENERATE;

-------------------------------------------------------------------------------
-- PLB_MRearbitrate generation
-------------------------------------------------------------------------------
MREARB_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

    PLB_MRearbitrate(i) <= PLB_PAValid and arbAddrSelReg(i) and Sl_rearbitrate;

end generate MREARB_GENERATE;

-------------------------------------------------------------------------------
-- PLB_MBusy generation
-------------------------------------------------------------------------------
MBUSY_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

    PLB_MBusy(i) <= Sl_MBusy(i) or (wdtTimeOutBusy and arbAddrSelReg(i));

end generate MBUSY_GENERATE;


-------------------------------------------------------------------------------
-- PLB_rdBurst generation
-------------------------------------------------------------------------------
-- Use one-hot carry mux for rd_burst generation then AND with arbPriRdBurstReg
-- 4-26-01 ALS
-- Added PLB_rdPrimReg term to PLB_rdBurst - PLB_rdBurst must assert 1 clock after
-- PLB_rdPrim. In most cases this occurs, however in the case where PLB_SAValid,
-- Sl_rdComp, Sl_addrAck,etc. all assert in the same clock, PLB_rdPrim is 
-- is registered so that it asserts one clock after addrAck. However, this then
-- aligns PLB_rdPrim with PLB_rdBurst. Since PLB_rdBurst must assert one clock
-- after PLB_rdPrim, check that PLB_rdPrimReg is zero before assertion. 
-- PLB_rdPrimReg only asserts for one clock, therefore in this situation, 
-- PLB_rdBurst will be delayed one clock.

RDBURST_MUX: mux_onehot
    generic map (   C_DW    => 1,
                    C_NB    => C_NUM_MASTERS)
    port map    (
                    D       => M_rdBurst,
                    S       => ArbPriRdMasterReg,
                    Y       => rd_burst
                );

PLB_rdBurst <= '1' when rd_burst = "1" and arbPriRdBurstReg = '1' 
                   and PLB_rdPrimReg = '0'
                else '0';


-------------------------------------------------------------------------------
-- PLB_MRdBTerm generation
-------------------------------------------------------------------------------
MRDBTERM_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

  PLB_MRdBTerm(i) <= arbPriRdMasterReg(i) and ((Sl_rdBTerm or wdtRdBTerm));

end generate MRDBTERM_GENERATE;

-------------------------------------------------------------------------------
-- PLB_wrBurst generation
-------------------------------------------------------------------------------
-- Use one-hot carry mux for wr_burst generation then AND with PLB_PAValid
-- OR arbWrDBusBusyReg to generate PLB_wrBurst

WRBURST_MUX: mux_onehot
    generic map (   C_DW    => 1,
                    C_NB    => C_NUM_MASTERS)
    port map    (
                    D       => M_wrBurst,
                    S       => ArbPriWrMasterReg,
                    Y       => wr_burst
                );
PLB_wrBurst <= '1' when ( wr_burst = "1" and 
                          (PLB_PAValid = '1' or arbWrDBusBusyReg = '1') )
                    else '0';

-------------------------------------------------------------------------------
-- PLB_MWrBTerm generation
-------------------------------------------------------------------------------
MWRBTERM_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

  PLB_MWrBTerm(i) <= arbPriWrMasterReg(i) and ((Sl_wrBTerm or wdtWrBTerm));

end generate MWRBTERM_GENERATE;
                
-------------------------------------------------------------------------------
-- PLB_MErr generation
-------------------------------------------------------------------------------
MERR_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate

  PLB_MErr(i) <= Sl_MErr(i) 
                 or (arbPriRdMasterRegReg(i) and wdtRdDAck) 
                 or (arbPriWrMasterReg(i) and wdtWrDAck);

end generate MERR_GENERATE;

 
end implementation;

