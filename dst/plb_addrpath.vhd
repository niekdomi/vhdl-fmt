-------------------------------------------------------------------------------
--  $Id: plb_addrpath.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- plb_addrpath.vhd - entity/architecture pair
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
-- Filename:        plb_addrpath.vhd
-- Version:         v1.01a
-- Description:     This file contains the address and transaction qualifier
--                  multiplexors.
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
use ieee.std_logic_1164.all;

-- PROC_COMMON library contains mux_onehot component
library proc_common_v1_00_b;
use proc_common_v1_00_b.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_NUM_MASTERS               -- number of masters
--          C_PLB_AWIDTH                -- address bus width
--          C_PLB_DWIDTH                -- data bus width
--
-- Definition of Ports:
--      --  Master signals
--          input M_compress
--          input M_guarded
--          input M_ordered
--          input M_lockErr
--          input M_ABus
--          input M_BE
--          input M_size
--          input M_type
--          input M_MSize
--
--      -- Arbitration signals
--          input ArbAddrSelReg         -- contains the ID of the bus master
--          output ArbBurstReq
--
--      -- PLB signals
--          output PLB_compress
--          output PLB_guarded
--          output PLB_ordered
--          output PLB_lockErr
--          output PLB_ABus
--          output PLB_BE
--          output PLB_size
--          output PLB_type
--          output PLB_MSize
--
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_addrpath is
  generic ( C_NUM_MASTERS   : integer   := 8;
            C_PLB_AWIDTH    : integer   := 32;
            C_PLB_DWIDTH    : integer   := 64
          );
  port (
        M_compress      : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_guarded       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_ordered       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_lockErr       : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        ArbAddrSelReg   : in std_logic_vector (0 to C_NUM_MASTERS - 1);
        M_ABus          : in std_logic_vector(0 to (C_NUM_MASTERS * C_PLB_AWIDTH) - 1 );
        M_BE            : in std_logic_vector(0 to (C_NUM_MASTERS * C_PLB_DWIDTH/8) - 1 );
        M_size          : in std_logic_vector(0 to (C_NUM_MASTERS * 4) - 1 );
        M_type          : in std_logic_vector(0 to (C_NUM_MASTERS * 3) - 1 );
        M_MSize         : in std_logic_vector(0 to (C_NUM_MASTERS * 2) - 1 );
        PLB_compress    : out std_logic;
        PLB_guarded     : out std_logic;
        PLB_ordered     : out std_logic;
        PLB_lockErr     : out std_logic;
        ArbBurstReq     : out std_logic;
        PLB_ABus        : out std_logic_vector (0 to C_PLB_AWIDTH - 1);
        PLB_BE          : out std_logic_vector(0 to C_PLB_DWIDTH/8 -1 );
        PLB_size        : out std_logic_vector(0 to 3 );
        PLB_type        : out std_logic_vector(0 to 2 );
        PLB_MSize       : out std_logic_vector(0 to 1 )
        );
end plb_addrpath;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture implementation of plb_addrpath is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- declare internal versions of output signals
signal plb_size_i       : std_logic_vector(0 to 3);

-- the following signals are declared as std logic vectors 0 to 0 so that the
-- type matches the type required by mux_onehot
signal plb_compress_i   : std_logic_vector(0 to 0);
signal plb_guarded_i    : std_logic_vector(0 to 0);
signal plb_ordered_i    : std_logic_vector(0 to 0);
signal plb_lockerr_i    : std_logic_vector(0 to 0);

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- The one-hot carry chain mux is used to multiplex the winning master's address
-- and control signals to the PLB

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
 
-- Assign output signals 
PLB_size        <= plb_size_i;
PLB_compress    <= plb_compress_i(0);
PLB_guarded     <= plb_guarded_i(0);
PLB_ordered     <= plb_ordered_i(0);
PLB_lockErr     <= plb_lockerr_i(0);

--    arbBurstReq generation
ArbBurstReq <= plb_size_i(0);
 
-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- Instantiate the one-hot carry mux to multiplex the winning master's address
-- bus onto the PLB address bus
I_PLBADDR_MUX: mux_onehot
    generic map ( C_DW  => C_PLB_AWIDTH,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_ABus,
                  S     => ArbAddrSelReg,
                  Y     => PLB_ABus
                );
                
-- Instantiate the one-hot carry mux to multiplex the winning master's byte 
-- enables onto the PLB byte enables
I_PLBBE_MUX: mux_onehot
    generic map ( C_DW  => C_PLB_DWIDTH/8,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_BE,
                  S     => ArbAddrSelReg,
                  Y     => PLB_BE
                );
-- Instantiate the one-hot carry mux to multiplex the winning master's size
-- onto the PLB size
I_PLBSIZE_MUX: mux_onehot
    generic map ( C_DW  => 4,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_size,
                  S     => ArbAddrSelReg,
                  Y     => plb_size_i
                );
 
-- Instantiate the one-hot carry mux to multiplex the winning master's type
-- onto the PLB type
I_PLBTYPE_MUX: mux_onehot
    generic map ( C_DW  => 3,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_type,
                  S     => ArbAddrSelReg,
                  Y     => PLB_type
                );

-- Instantiate the one-hot carry mux to multiplex the winning master's compress
-- signal onto the PLB compress signal
I_PLBCMPRS_MUX: mux_onehot
    generic map ( C_DW  => 1,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_compress,
                  S     => ArbAddrSelReg,
                  Y     => plb_compress_i(0 to 0)
                );

-- Instantiate the one-hot carry mux to multiplex the winning master's guarded
-- signal onto the PLB guarded signal
I_PLBGUARDED_MUX: mux_onehot
    generic map ( C_DW  => 1,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_guarded,
                  S     => ArbAddrSelReg,
                  Y     => plb_guarded_i(0 to 0)
                );


-- Instantiate the one-hot carry mux to multiplex the winning master's ordered
-- signal onto the PLB ordered signal
I_PLBORDERED_MUX: mux_onehot
    generic map ( C_DW  => 1,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_ordered,
                  S     => ArbAddrSelReg,
                  Y     => plb_ordered_i(0 to 0)
                );
 
-- Instantiate the one-hot carry mux to multiplex the winning master's lock
-- error signal onto the PLB lock error signal
I_PLBLOCKERR_MUX: mux_onehot
    generic map ( C_DW  => 1,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_lockErr,
                  S     => ArbAddrSelReg,
                  Y     => plb_lockerr_i(0 to 0)
                );
 
-- Instantiate the one-hot carry mux to multiplex the winning master's msize
-- signal onto the PLB msize signal
I_PLBMSIZE_MUX: mux_onehot
    generic map ( C_DW  => 2,
                  C_NB  => C_NUM_MASTERS
                )
    port map    ( D     => M_MSize,
                  S     => ArbAddrSelReg,
                  Y     => PLB_MSize
                );
 
end implementation;

