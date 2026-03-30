-------------------------------------------------------------------------------
--  $Id: plb_v34.vhd,v 1.4 2004/06/07 18:29:41 mlovejoy Exp $
-------------------------------------------------------------------------------
-- plb_v34.vhd - entity/architecture pair
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
-- Filename:        plb_v34.vhd
-- Version:         v1.01a
-- Description:     This file is the top-level VHDL file for the Xilinx PLB
--                  arbiter. It instantiates the necessary components to 
--                  build the Xilinx PLB Arbiter Design.
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
--                  --  BusLockSM.vhd
--
--                  --  watchdog_timer.vhd
--                      --  down_counter.vhd
--
--                  --  dcr_regs.vhd
-- 
--                  --  plb_interrupt.vhd
--
-------------------------------------------------------------------------------
-- @BEGIN_CHANGELOG EDK_Gm_SP2
--04/15/04
--  Rev'd device to v1_02_a
--  Modified operation to make plb2opb bridge operation (previously based on
--  IBM architecture) compatible with Xilinx OPB IPIF architecture.
--  Specifically, added timer in arbitration state machine for read operations
--  that delays asserting grant to any master that receieved a rearbitration
--  response from the plb2opb bridge during a read operation. The delay is
--  set by the parameter C_NUM_OPBCLK_PLB2OPB_REARB.  A new signal,
--  PLB2OPB_rearb, was required to signal plb arbiter that the plb2opb bridge
--  asserted the rearbitration signal. Multiple plb2opb bridge are supported.
--  This plb v34 logic module is compatible with only plb2opb_bridge_v1_01_a.
-- @END_CHANGELOG
-------------------------------------------------------------------------------
-- Author:      ALS
-- History:
--  ALS         02/20/02        -- First version, created from plb_arbiter_v1_01_a 
--  ALS         02/22/02        
-- ^^^^^^
-- Added library declaration for max2 and log2 functions in port declaration of
-- PLB_MasterID. Changed Clk and Rst to PLB_Clk and PLB_Rst.
-- ~~~~~~
--  ALS         02/26/02
--  Added generic C_MID_WIDTH so that the max2 and log2 functions are no longer
--  required in the port declaration of PLB_masterID. This generic will be 
--  calculated by the GUI. Also added a power-up reset function. PLB_Rst is now
--  an output, changed ArbReset from an output to an input named SYS_Rst.
-- ^^^^^^
--  ALS         04/16/02        -- Version v1.01a
-- ^^^^^^
--  Changed generics C_MID_WIDTH, C_NUM_MASTERS, C_NUM_SLAVES to C_PLB_MID_WIDTH,
--  C_PLB_NUM_MASTERS, and C_PLB_NUM_SLAVES. Added max fan-out synthesis 
--  directives.
-- ^^^^^^
-- ^^^^^^
--  MLL         02/20/04        -- Version v1.01a
-- ^^^^^^
--  Fix to make compatible with OPB IPIF architecture. In arb_control_sm.vhd,
--  added counter to block clearing of mask in arbitration if plb2opb bridge
--  asserts rearbitrate on a read operation. This required adding
--  C_NUM_OPBCLK_PLB2OPB_REARB generic and PLB2OPB_rearb vector signal at this
--  level and passed down to arb_control_sm.vhd. Also rev'd to v1.02a.
--  asserted the rearbitration signal. Multiple plb2opb bridge were to be
--  supported with the parameter C_NUM_PLB2OPB_BRIDGE, but it was found that
--  edk support was not what was described to be and what was used in the design,
--  so a workaround was implemented to accomodate the real EDK device index
--  scheme. This plb v34 logic module is compatible with only plb2opb_bridge_v1_01_a.
-- ^^^^^^
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
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_PLB_NUM_MASTERS   -- number of masters on the PLB
--          C_PLB_NUM_SLAVES    -- number of slaves on the PLB
--          C_PLB_MID_WIDTH     -- number of bits to encode the number of masters
--          C_PLB_AWIDTH        -- PLB address bus width
--          C_PLB_DWIDTH        -- PLB data bus width
--          C_DCR_INTFCE        -- include DCR interface
--          C_BASEADDR          -- DCR base address
--          C_HIGHADDR          -- DCR high address
--          C_DCR_AWIDTH        -- DCR address bus width
--          C_DCR_DWIDTH        -- DCR data bus width
--          C_EXT_RESET_HIGH    -- external reset is active high
--          C_IRQ_ACTIVE        -- active interrupt edge (rising or falling)
--
-- Definition of Ports:
--
--      -- DCR signals
--          input DCR_ABus     
--          input DCR_Read          
--          input DCR_Write 
--          input DCR_DBus
--          output PLB_dcrAck 
--          output PLB_dcrDBus
--  
--      -- Master signals
--          input M_ABus            
--          input M_BE              
--          input M_RNW             
--          input M_abort           
--          input M_busLock         
--          input M_compress        
--          input M_guarded         
--          input M_lockErr         
--          input M_MSize           
--          input M_ordered         
--          input M_priority        
--          input M_rdBurst         
--          input M_request         
--          input M_size            
--          input M_type            
--          input M_wrBurst         
--          input M_wrDBus          
--  
--      -- PLB signals
--          output PLB_ABus             
--          output PLB_BE           
--          output PLB_MAddrAck         
--          output PLB_MBusy        
--          output PLB_MErr             
--          output PLB_MRdBTerm         
--          output PLB_MRdDAck      
--          output PLB_MRdDBus      
--          output PLB_MRdWdAddr    
--          output PLB_MRearbitrate 
--          output PLB_MWrBTerm         
--          output PLB_MWrDAck      
--          output PLB_MSSize           
--          output PLB_PAValid      
--          output PLB_RNW          
--          output PLB_SAValid      
--          output PLB_abort        
--          output PLB_busLock      
--          output PLB_compress         
--          output PLB_guarded      
--          output PLB_lockErr      
--          output PLB_masterID         
--          output PLB_MSize        
--          output PLB_ordered      
--          output PLB_pendPri      
--          output PLB_pendReq      
--          output PLB_rdBurst      
--          output PLB_rdPrim       
--          output PLB_reqPri       
--          output PLB_size             
--          output PLB_type             
--          output PLB_wrBurst      
--          output PLB_wrDBus       
--          output PLB_wrPrim       
--  
--      -- Slave signals
--          input Sl_MBusy          
--          input Sl_MErr           
--          input Sl_addrAck        
--          input Sl_rdBTerm        
--          input Sl_rdComp         
--          input Sl_rdDAck         
--          input Sl_rdDBus         
--          input Sl_rdWdAddr       
--          input Sl_rearbitrate    
--          input Sl_SSize          
--          input Sl_wait           
--          input Sl_wrBTerm        
--          input Sl_wrComp         
--          input Sl_wrDAck        
--
--      -- Output from Slave OR gates
--          output PLB_SaddrAck     
--          output PLB_SMErr        
--          output PLB_SMBusy       
--          output PLB_SrdBTerm     
--          output PLB_SrdComp      
--          output PLB_SrdDAck      
--          output PLB_SrdDBus      
--          output PLB_SrdWdAddr    
--          output PLB_Srearbitrate 
--          output PLB_Sssize       
--          output PLB_Swait        
--          output PLB_SwrBTerm     
--          output PLB_SwrComp      
--          output PLB_SwrDAck      
--
--      -- arbiter output indicating either PAValid or SAValid is asserted
--          output ArbAddrVldReg    
--                      
--      -- Clock, Interrupt, and Resets
--          input PLB_Clk
--          input SYS_Rst
--          output Bus_Error_Det
--          output PLB_Rst
--
-------------------------------------------------------------------------------
 
library ieee;
use ieee.std_logic_1164.all;

library plb_v34_v1_02_a;
use plb_v34_v1_02_a.all;

-- UNISIM library contains the SRL16 and FDS primitives required for the power-on
-- reset logic
library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_v34 is
    generic (
             C_PLB_NUM_MASTERS  : integer := 4;  
             C_PLB_NUM_SLAVES   : integer := 8;
             C_PLB_MID_WIDTH    : integer := 2;
             C_PLB_AWIDTH       : integer := 32;  
             C_PLB_DWIDTH       : integer := 64; 
             C_DCR_INTFCE       : integer := 1;
             -- set BASEADDR and HIGHADDR defaults to unused state
             C_BASEADDR         : std_logic_vector := "1111111111"; 
             C_HIGHADDR         : std_logic_vector := "0000000000";
             C_DCR_AWIDTH       : integer := 10;
             C_DCR_DWIDTH       : integer := 32;
             C_EXT_RESET_HIGH   : integer   := 1;
             C_IRQ_ACTIVE       : std_logic := '1';
             C_NUM_OPBCLK_PLB2OPB_REARB: integer := 25
             );
    port (
          DCR_ABus          : in std_logic_vector(0 to C_DCR_AWIDTH - 1 );
          DCR_DBus          : in std_logic_vector(0 to C_DCR_DWIDTH - 1 );
          DCR_Read          : in std_logic;
          DCR_Write         : in std_logic;
          PLB_dcrAck        : out std_logic;
          PLB_dcrDBus       : out std_logic_vector(0 to C_DCR_DWIDTH - 1 );
          M_ABus            : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * C_PLB_AWIDTH) - 1 );
          M_BE              : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * (C_PLB_DWIDTH / 8)) - 1 );
          M_RNW             : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_abort           : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_busLock         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_compress        : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_guarded         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_lockErr         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_MSize           : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * 2) - 1 );
          M_ordered         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_priority        : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * 2) - 1 );
          M_rdBurst         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_request         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_size            : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * 4) - 1 );
          M_type            : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * 3) - 1 );
          M_wrBurst         : in std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          M_wrDBus          : in std_logic_vector(0 to (C_PLB_NUM_MASTERS * C_PLB_DWIDTH) - 1 );
          PLB_ABus          : out std_logic_vector(0 to C_PLB_AWIDTH - 1 );
          PLB_BE            : out std_logic_vector(0 to (C_PLB_DWIDTH / 8) - 1 );
          PLB_MAddrAck      : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MBusy         : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MErr          : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MRdBTerm      : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MRdDAck       : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MRdDBus       : out std_logic_vector(0 to (C_PLB_NUM_MASTERS*C_PLB_DWIDTH)-1);
          PLB_MRdWdAddr     : out std_logic_vector(0 to (C_PLB_NUM_MASTERS * 4) - 1 );
          PLB_MRearbitrate  : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MWrBTerm      : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MWrDAck       : out std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
          PLB_MSSize        : out std_logic_vector(0 to (C_PLB_NUM_MASTERS * 2) - 1 );
          PLB_PAValid       : out std_logic;
          PLB_RNW           : out std_logic;
          PLB_SAValid       : out std_logic;
          PLB_abort         : out std_logic;
          PLB_busLock       : out std_logic;
          PLB_compress      : out std_logic;
          PLB_guarded       : out std_logic;
          PLB_lockErr       : out std_logic;
          PLB_masterID      : out std_logic_vector(0 to C_PLB_MID_WIDTH-1);
          PLB_MSize         : out std_logic_vector(0 to 1 );
          PLB_ordered       : out std_logic;
          PLB_pendPri       : out std_logic_vector(0 to 1 );
          PLB_pendReq       : out std_logic;
          PLB_rdBurst       : out std_logic;
          PLB_rdPrim        : out std_logic;
          PLB_reqPri        : out std_logic_vector(0 to 1 );
          PLB_size          : out std_logic_vector(0 to 3 );
          PLB_type          : out std_logic_vector(0 to 2 );
          PLB_wrBurst       : out std_logic;
          PLB_wrDBus        : out std_logic_vector(0 to C_PLB_DWIDTH - 1 );
          PLB_wrPrim        : out std_logic;
          
          Sl_addrAck        : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1 );
          Sl_MErr           : in std_logic_vector(0 to C_PLB_NUM_SLAVES*C_PLB_NUM_MASTERS - 1 );
          Sl_MBusy          : in std_logic_vector(0 to C_PLB_NUM_SLAVES*C_PLB_NUM_MASTERS - 1 );
          Sl_rdBTerm        : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1);
          Sl_rdComp         : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1);
          Sl_rdDAck         : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1);
          Sl_rdDBus         : in std_logic_vector(0 to C_PLB_NUM_SLAVES*C_PLB_DWIDTH - 1 );
          Sl_rdWdAddr       : in std_logic_vector(0 to C_PLB_NUM_SLAVES*4 - 1 );
          Sl_rearbitrate    : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1 );
          Sl_SSize          : in std_logic_vector(0 to C_PLB_NUM_SLAVES*2 - 1 );
          Sl_wait           : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1 );
          Sl_wrBTerm        : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1 );
          Sl_wrComp         : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1 );
          Sl_wrDAck         : in std_logic_vector(0 to C_PLB_NUM_SLAVES - 1 );

          -- Outputs of Slave OR gates are only used in simulation to connect
          -- to the IBM PLB Monitor
          PLB_SaddrAck      : out std_logic;
          PLB_SMErr         : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);   
          PLB_SMBusy        : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);   
          PLB_SrdBTerm      : out std_logic;   
          PLB_SrdComp       : out std_logic;
          PLB_SrdDAck       : out std_logic;
          PLB_SrdDBus       : out std_logic_vector(0 to C_PLB_DWIDTH-1);   
          PLB_SrdWdAddr     : out std_logic_vector(0 to 3);
          PLB_Srearbitrate  : out std_logic;
          PLB_Sssize        : out std_logic_vector(0 to 1);
          PLB_Swait         : out std_logic;
          PLB_SwrBTerm      : out std_logic;
          PLB_SwrComp       : out std_logic;
          PLB_SwrDAck       : out std_logic;
          --Fix to make compatible with OPB IPIF architecture
          PLB2OPB_rearb     : in std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
          ArbAddrVldReg     : out std_logic;
          SYS_Rst           : in std_logic;
          Bus_Error_Det     : out std_logic;
          PLB_Rst           : out std_logic;
          PLB_Clk           : in std_logic
          );
 
    -- fan-out attributes for Synplicity
    attribute syn_maxfan                  : integer;
    attribute syn_maxfan   of PLB_Clk     : signal is 10000;
    attribute syn_maxfan   of PLB_Rst     : signal is 10000;
    --fan-out attributes for XST
    attribute MAX_FANOUT                  : string;
    attribute MAX_FANOUT   of PLB_Clk     : signal is "10000";
    attribute MAX_FANOUT   of PLB_Rst     : signal is "10000";
 
end plb_v34;
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of plb_v34 is

-----------------------------------------------------------------------------
-- Constant Declarations
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Signal Declarations
-----------------------------------------------------------------------------
-- internal arbiter registers
signal arbAddrSelReg        : std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
signal arbBurstReq          : std_logic;
signal arbPriRdMasterRegReg : std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );
signal arbPriWrMasterReg    : std_logic_vector(0 to C_PLB_NUM_MASTERS - 1 );

--   internal versions of output signals
signal plb_abus_i           : std_logic_vector(0 to C_PLB_AWIDTH - 1 );
signal plb_be_i             : std_logic_vector(0 to C_PLB_DWIDTH/8-1);
signal plb_size_i           : std_logic_vector(0 to 3 );
signal plb_type_i           : std_logic_vector(0 to 2);
signal plb_rst_i            : std_logic;

signal plb_saddrack_i       : std_logic;   
signal plb_smerr_i          : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
signal plb_smbusy_i         : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
signal plb_srdbterm_i       : std_logic;   
signal plb_srdcomp_i        : std_logic;
signal plb_srddack_i        : std_logic;
signal plb_srddbus_i        : std_logic_vector(0 to C_PLB_DWIDTH-1); 
signal plb_srdwdaddr_i      : std_logic_vector(0 to 3);
signal plb_srearbitrate_i   : std_logic;
signal plb_sssize_i         : std_logic_vector(0 to 1);
signal plb_swait_i          : std_logic;
signal plb_swrbterm_i       : std_logic;
signal plb_swrcomp_i        : std_logic;
signal plb_swrdack_i        : std_logic;

--   Data ACKs and rdWdAddr from watchdog timer
signal wdtRdDAck            : std_logic;
signal wdtWrDAck            : std_logic;
signal plb_rdWdAddrWDT      : std_logic_vector(0 to 3);

-- Power-on reset signals and attributes
signal srl_time_out         : std_logic; 
signal ext_rst_i            : std_logic; 
signal por_FF_out           : std_logic; 

attribute INIT              : string; 
attribute INIT of POR_SRL_I : label is "FFFF"; 

-----------------------------------------------------------------------------
-- Component Declarations
-----------------------------------------------------------------------------

-- PLB_ADDRPATH contains the address bus and control signal multiplexors
component plb_addrpath
    generic (
            C_NUM_MASTERS : INTEGER := 8;
            C_PLB_AWIDTH : INTEGER := 32;
            C_PLB_DWIDTH : INTEGER := 64
            );
    port (
        M_compress  : in std_logic_vector(0 to C_NUM_MASTERS - 1);
        M_guarded   : in std_logic_vector(0 to C_NUM_MASTERS - 1);
        M_ordered   : in std_logic_vector(0 to C_NUM_MASTERS - 1);
        M_lockErr   : in std_logic_vector(0 to C_NUM_MASTERS - 1);
        ArbAddrSelReg : in std_logic_vector(0 to C_NUM_MASTERS - 1);
        M_ABus      : in std_logic_vector(0 to (C_NUM_MASTERS * C_PLB_AWIDTH)-1);
        M_BE        : in std_logic_vector(0 to (C_NUM_MASTERS * C_PLB_DWIDTH / 8)-1);
        M_size      : in std_logic_vector(0 to (C_NUM_MASTERS * 4) - 1);
        M_type      : in std_logic_vector(0 to (C_NUM_MASTERS * 3) - 1);
        M_MSize     : in std_logic_vector(0 to (C_NUM_MASTERS * 2) - 1);
        PLB_compress : out std_logic;
        PLB_guarded : out std_logic;
        PLB_ordered : out std_logic;
        PLB_lockErr : out std_logic;
        ArbBurstReq : out std_logic;
        PLB_ABus    : out std_logic_vector(0 to C_PLB_AWIDTH - 1 );
        PLB_BE      : out std_logic_vector(0 to C_PLB_DWIDTH / 8 - 1 );
        PLB_size    : out std_logic_vector(0 to 3 );
        PLB_type    : out std_logic_vector(0 to 2 );
        PLB_MSize   : out std_logic_vector(0 to 1 )
        );
end component plb_addrpath;

-- PLB_WR_DATAPATH contains the write data bus multiplexors
component plb_wr_datapath
    generic (
            C_NUM_MASTERS : INTEGER := 8;
            C_PLB_DWIDTH : INTEGER := 64
            );
    port (
        Sl_wrDAck       : in std_logic;
        WdtWrDAck       : in std_logic;
        ArbPriWrMasterReg : in std_logic_vector(0 to C_NUM_MASTERS-1);
        M_wrDBus        : in std_logic_vector(0 to (C_NUM_MASTERS * C_PLB_DWIDTH)-1);
        PLB_MWrDAck     : out std_logic_vector(0 to C_NUM_MASTERS-1);
        PLB_wrDBus      : out std_logic_vector(0 to C_PLB_DWIDTH-1)
        );
end component plb_wr_datapath;

-- PLB_RD_DATAPATH contains the read data bus multiplexors
component plb_rd_datapath
    generic (
            C_NUM_MASTERS : INTEGER := 8;
            C_PLB_DWIDTH : INTEGER := 64
            );
    port (
        Sl_rdDAck           : in std_logic;
        WdtRdDAck           : in std_logic;
        ArbPriRdMasterRegReg : in std_logic_vector(0 to C_NUM_MASTERS-1);
        Sl_rdWdAddr         : in std_logic_vector(0 to 3 );
        PLB_rdWdAddrWDT     : in std_logic_vector(0 to 3 );
        PLB_MRdDAck         : out std_logic_vector(0 to C_NUM_MASTERS-1);
        PLB_MRdDBus         : out std_logic_vector(0 to (C_NUM_MASTERS*C_PLB_DWIDTH)-1);
        PLB_MRdWdAddr       : out std_logic_vector(0 to (C_NUM_MASTERS*4)-1);
        Sl_rdDBus           : in std_logic_vector(0 to C_PLB_DWIDTH-1)
        );
end component plb_rd_datapath;

-- PLB_SLAVE_ORS contains the slave OR gates
component plb_slave_ors 
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
end component plb_slave_ors;
 
-- PLB_ARBITER_LOGIC contains the arbitration logic, bus control logic, 
--  dcr interface, and interrupt logic.
component plb_arbiter_logic
    generic (
            C_NUM_MASTERS   : integer := 8;
            C_MID_BITS      : integer := 3;
            C_PLB_AWIDTH    : integer := 32;
            C_PLB_DWIDTH    : integer := 64;
            C_DCR_INTFCE    : integer := 1;
            C_DCR_AWIDTH    : integer := 10;
            C_DCR_DWIDTH    : integer := 32;
            C_BASEADDR      : std_logic_vector;
            C_HIGHADDR      : std_logic_vector;
            C_IRQ_ACTIVE    : std_logic := '1';
            C_NUM_PLB2OPB_BRIDGE: integer;
            C_NUM_OPBCLK_PLB2OPB_REARB: integer
            );
    port (
        M_RNW           : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_abort         : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_busLock       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_lockErr       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_priority      : in std_logic_vector(0 to (C_NUM_MASTERS * 2) - 1 );
        M_rdBurst       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_request       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_wrBurst       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_ABus        : in std_logic_vector(0 to C_PLB_AWIDTH - 1 );
        PLB_BE          : in std_logic_vector(0 to C_PLB_DWIDTH / 8 - 1 );
        PLB_MAddrAck    : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MBusy       : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MErr        : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MRdBTerm    : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MRearbitrate : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MWrBTerm    : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MSSize      : out std_logic_vector(0 to (C_NUM_MASTERS * 2) - 1 );
        PLB_PAValid     : out std_logic;
        PLB_SAValid     : out std_logic;
        PLB_masterID    : out std_logic_vector(0 to C_MID_BITS-1 );
        PLB_pendPri     : out std_logic_vector(0 to 1 );
        PLB_rdPrim      : out std_logic;
        PLB_reqPri      : out std_logic_vector(0 to 1 );
        PLB_wrPrim      : out std_logic;
        PLB_RNW         : out std_logic;
        PLB_abort       : out std_logic;
        PLB_busLock     : out std_logic;
        PLB_pendReq     : out std_logic;
        PLB_rdBurst     : out std_logic;
        PLB_size        : in std_logic_vector(0 to 3 );
        PLB_type        : in std_logic_vector(0 to 2);
        PLB_wrBurst     : out std_logic;
        Sl_MBusy        : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        Sl_MErr         : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        Sl_rdBTerm      : in std_logic;
        Sl_SSize        : in std_logic_vector(0 to 1 );
        Sl_wrBTerm      : in std_logic;
        Sl_wrComp       : in std_logic;
        Sl_addrAck      : in std_logic;
        Sl_rdComp       : in std_logic;
        Sl_rearbitrate  : in std_logic;
        Sl_wait         : in std_logic;
        ArbAddrSelReg   : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        ArbBurstReq     : in std_logic;
        ArbPriRdMasterRegReg : out std_logic_vector(0 to C_NUM_MASTERS - 1);
        ArbPriWrMasterReg : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        ArbAddrVldReg   : out std_logic;
        DCR_ABus        : in std_logic_vector(0 to C_DCR_AWIDTH - 1 );
        DCR_Read        : in std_logic;
        DCR_Write       : in std_logic;
        PLB_dcrAck      : out std_logic;
        PLB_dcrDBus     : out std_logic_vector(0 to C_DCR_DWIDTH - 1 );
        DCR_DBus        : in std_logic_vector(0 to C_DCR_DWIDTH - 1 );
        WdtRdDAck       : out std_logic;
        WdtWrDAck       : out std_logic;
        PLB_rdWdAddrWDT : out std_logic_vector(0 to 3);
        Bus_Error_Det   : out std_logic;
        Clk             : in std_logic;
        Rst             : in std_logic;
          --Fix to make compatible with OPB IPIF architecture
        PLB2OPB_rearb   : in std_logic_vector(0 to C_PLB_NUM_SLAVES-1)
        );
end component plb_arbiter_logic;


-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

--  Assign output signals to the internal signals
PLB_Abus    <= plb_abus_i;
PLB_BE      <= plb_be_i;
PLB_size    <= plb_size_i;
PLB_type    <= plb_type_i;
PLB_Rst     <= plb_rst_i;

-- Outputs of Slave OR gates are only used in simulation to connect to the
-- IBM PLB Monitor
PLB_SaddrAck        <= plb_saddrack_i;    
PLB_SMErr           <= plb_smerr_i;       
PLB_SMBusy          <= plb_smbusy_i;      
PLB_SrdBTerm        <= plb_srdbterm_i;    
PLB_SrdComp         <= plb_srdcomp_i;     
PLB_SrdDAck         <= plb_srddack_i;     
PLB_SrdDBus         <= plb_srddbus_i;     
PLB_SrdWdAddr       <= plb_srdwdaddr_i;   
PLB_Srearbitrate    <= plb_srearbitrate_i;
PLB_Sssize          <= plb_sssize_i;      
PLB_Swait           <= plb_swait_i;       
PLB_SwrBTerm        <= plb_swrbterm_i;    
PLB_SwrComp         <= plb_swrcomp_i;     
PLB_SwrDAck         <= plb_swrdack_i;             

-----------------------------------------------------------------------------
-- Power-on Reset Process
-----------------------------------------------------------------------------
-- This process starts with a flip-flop that is set upon configuration or
-- power-up which outputs the reset for the PLB bus. This flip-flop is also
-- synchronously set by an external reset if one is available. A zero is 
-- shifted through an SRL16 so that 16 clocks later, the flip-flop clocks
-- in a zero and the reset is negated. The output of this flip-flop is 
-- registered once more to insure synchronization with the PLB_Clk. Note that
-- this power-up reset does not take into account if the DCMs are Locked. It
-- is assumed that the external reset signal has accounted for this.
-----------------------------------------------------------------------------
PLB_RST_PROCESS: process (SYS_Rst) is 
    variable ext_rst_input : std_logic; 
begin 
    if C_EXT_RESET_HIGH = 0 then 
      ext_rst_input := not(SYS_Rst); 
    else 
      ext_rst_input := SYS_Rst; 
    end if; 
    ext_rst_i <= ext_rst_input; 
end process PLB_RST_PROCESS; 
  
POR_SRL_I: SRL16 
-- synthesis translate_off 
    generic map ( 
      INIT => X"FFFF") 
-- synthesis translate_on 
    port map ( 
      D   => '0', 
      CLK => PLB_Clk, 
      A0  => '1', 
      A1  => '1', 
      A2  => '1', 
      A3  => '1', 
      Q   => srl_time_out); 
  
  POR_FF1_I: FDS 
    port map ( 
      Q   => por_FF_out, 
      D   => srl_time_out, 
      C   => PLB_Clk, 
      S   => ext_rst_i); 

  POR_FF2_I: FDS 
    port map ( 
      Q   => plb_rst_i, 
      D   => por_FF_out, 
      C   => PLB_Clk, 
      S   => '0'); 
 
-----------------------------------------------------------------------------
-- Component Instantiations
-----------------------------------------------------------------------------
 
--   Instantiate the Address path multiplexors
I_PLB_ADDRPATH: plb_addrpath
    generic map (C_NUM_MASTERS  => C_PLB_NUM_MASTERS,
                 C_PLB_AWIDTH   => C_PLB_AWIDTH,
                 C_PLB_DWIDTH   => C_PLB_DWIDTH)
    port map (
              M_compress        => M_compress,
              M_guarded         => M_guarded,
              M_ordered         => M_ordered,
              M_lockErr         => M_lockErr,
              ArbAddrSelReg     => arbAddrSelReg,
              M_ABus            => M_ABus,
              M_BE              => M_BE,
              M_size            => M_size,
              M_type            => M_type,
              M_MSize           => M_MSize,
              PLB_compress      => PLB_compress,
              PLB_guarded       => PLB_guarded,
              PLB_ordered       => PLB_ordered,
              PLB_lockErr       => PLB_lockErr,
              ArbBurstReq       => arbBurstReq,
              PLB_ABus          => plb_abus_i,
              PLB_BE            => plb_be_i,
              PLB_size          => plb_size_i,
              PLB_type          => plb_type_i,
              PLB_MSize         => PLB_MSize);

--   Instantiate the Write databus multiplexors
I_PLB_WR_DATAPATH: plb_wr_datapath
    generic map (C_NUM_MASTERS  => C_PLB_NUM_MASTERS,
                 C_PLB_DWIDTH   => C_PLB_DWIDTH)
    port map (
              Sl_wrDAck         => plb_swrdack_i,
              WdtWrDAck         => wdtWrDAck,
              ArbPriWrMasterReg => arbPriWrMasterReg,
              M_wrDBus          => M_wrDBus,
              PLB_MWrDAck       => PLB_MWrDAck,
              PLB_wrDBus        => PLB_wrDBus);

--   Instantiate the Read databus multiplexors
I_PLB_RD_DATAPATH: plb_rd_datapath
    generic map (C_NUM_MASTERS  => C_PLB_NUM_MASTERS,
                 C_PLB_DWIDTH   => C_PLB_DWIDTH)
    port map (
              Sl_rdDAck         => plb_srddack_i,
              WdtRdDAck         => wdtRdDAck,
              ArbPriRdMasterRegReg => arbPriRdMasterRegReg,
              Sl_rdWdAddr       => plb_srdwdaddr_i,
              PLB_rdWdAddrWDT   => plb_rdWdAddrWDT,
              PLB_MRdDAck       => PLB_MRdDAck,
              PLB_MRdDBus       => PLB_MRdDBus,
              PLB_MRdWdAddr     => PLB_MRdWdAddr,
              Sl_rdDBus         => plb_srddbus_i);
              
--   Instantiate the Slave OR gates
I_PLB_SLAVE_ORS: plb_slave_ors 
  generic map(  C_NUM_MASTERS   => C_PLB_NUM_MASTERS,
                C_NUM_SLAVES    => C_PLB_NUM_SLAVES,
                C_PLB_DWIDTH    => C_PLB_DWIDTH )
  port map (
        Sl_addrAck          => Sl_addrAck,     
        Sl_MErr             => Sl_MErr,        
        Sl_MBusy            => Sl_MBusy,        
        Sl_rdBTerm          => Sl_rdBTerm,     
        Sl_rdComp           => Sl_rdComp,      
        Sl_rdDAck           => Sl_rdDAck,       
        Sl_rdDBus           => Sl_rdDBus,      
        Sl_rdWdAddr         => Sl_rdWdAddr,    
        Sl_rearbitrate      => Sl_rearbitrate, 
        Sl_SSize            => Sl_SSize,       
        Sl_wait             => Sl_wait,         
        Sl_wrBTerm          => Sl_wrBTerm,     
        Sl_wrComp           => Sl_wrComp,      
        Sl_wrDAck           => Sl_wrDAck,       
        
        PLB_SaddrAck        => plb_saddrack_i,    
        PLB_SMErr           => plb_smerr_i,       
        PLB_SMBusy          => plb_smbusy_i,      
        PLB_SrdBTerm        => plb_srdbterm_i,    
        PLB_SrdComp         => plb_srdcomp_i,     
        PLB_SrdDAck         => plb_srddack_i,     
        PLB_SrdDBus         => plb_srddbus_i,     
        PLB_SrdWdAddr       => plb_srdwdaddr_i,   
        PLB_Srearbitrate    => plb_srearbitrate_i,
        PLB_Sssize          => plb_sssize_i,      
        PLB_Swait           => plb_swait_i,       
        PLB_SwrBTerm        => plb_swrbterm_i,    
        PLB_SwrComp         => plb_swrcomp_i,     
        PLB_SwrDAck         => plb_swrdack_i             
        );

--  Instantiate the PLB Arbiter
I_PLB_ARBITER_LOGIC: plb_arbiter_logic
    generic map (C_NUM_MASTERS  => C_PLB_NUM_MASTERS,
                 C_MID_BITS     => C_PLB_MID_WIDTH,
                 C_PLB_AWIDTH   => C_PLB_AWIDTH,
                 C_DCR_INTFCE   => C_DCR_INTFCE,
                 C_DCR_AWIDTH   => C_DCR_AWIDTH,
                 C_DCR_DWIDTH   => C_DCR_DWIDTH,
                 C_BASEADDR     => C_BASEADDR,
                 C_HIGHADDR     => C_HIGHADDR,
                 C_IRQ_ACTIVE   => C_IRQ_ACTIVE,
                 C_NUM_PLB2OPB_BRIDGE   =>
                          C_PLB_NUM_SLAVES,
                 C_NUM_OPBCLK_PLB2OPB_REARB =>
                          C_NUM_OPBCLK_PLB2OPB_REARB)
    port map (
              M_RNW             => M_RNW,
              M_abort           => M_abort,
              M_busLock         => M_busLock,
              M_lockErr         => M_lockErr,
              M_priority        => M_priority,
              M_rdBurst         => M_rdBurst,
              M_request         => M_request,
              M_wrBurst         => M_wrBurst,
              PLB_ABus          => plb_abus_i,
              PLB_BE            => plb_be_i,
              PLB_MAddrAck      => PLB_MAddrAck,
              PLB_MBusy         => PLB_MBusy,
              PLB_MErr          => PLB_MErr,
              PLB_MRdBTerm      => PLB_MRdBTerm,
              PLB_MRearbitrate  => PLB_MRearbitrate,
              PLB_MWrBTerm      => PLB_MWrBTerm,
              PLB_MSSize        => PLB_MSSize,
              PLB_PAValid       => PLB_PAValid,
              PLB_SAValid       => PLB_SAValid,
              PLB_masterID      => PLB_masterID,
              PLB_pendPri       => PLB_pendPri,
              PLB_rdPrim        => PLB_rdPrim,
              PLB_reqPri        => PLB_reqPri,
              PLB_wrPrim        => PLB_wrPrim,
              PLB_RNW           => PLB_RNW,
              PLB_abort         => PLB_abort,
              PLB_busLock       => PLB_busLock,
              PLB_pendReq       => PLB_pendReq,
              PLB_rdBurst       => PLB_rdBurst,
              PLB_size          => plb_size_i,
              PLB_type          => plb_type_i,
              PLB_wrBurst       => PLB_wrBurst,
              Sl_MBusy          => plb_smbusy_i,
              Sl_MErr           => plb_smerr_i,
              Sl_rdBTerm        => plb_srdbterm_i,
              Sl_SSize          => plb_sssize_i,
              Sl_wrBTerm        => plb_swrbterm_i,
              Sl_wrComp         => plb_swrcomp_i,
              Sl_addrAck        => plb_saddrack_i,
              Sl_rdComp         => plb_srdcomp_i,
              Sl_rearbitrate    => plb_srearbitrate_i,
              Sl_wait           => plb_swait_i,
              ArbAddrSelReg     => arbAddrSelReg,
              ArbBurstReq       => arbBurstReq,
              ArbPriRdMasterRegReg => arbPriRdMasterRegReg,
              ArbPriWrMasterReg => arbPriWrMasterReg,
              ArbAddrVldReg     => ArbAddrVldReg,
              DCR_ABus          => DCR_ABus,
              DCR_Read          => DCR_Read,
              DCR_Write         => DCR_Write,
              PLB_dcrAck        => PLB_dcrAck,
              PLB_dcrDBus       => PLB_dcrDBus,
              DCR_DBus          => DCR_DBus,
              WdtRdDAck         => wdtRdDAck,
              WdtWrDAck         => wdtWrDAck,
              PLB_rdWdAddrWDT   => plb_rdWdAddrWDT,
              Bus_Error_Det     => Bus_Error_Det,
              Clk               => PLB_Clk,
              Rst               => plb_rst_i,
          --Fix to make compatible with OPB IPIF architecture
              PLB2OPB_rearb     => PLB2OPB_rearb);
end simulation;

