-------------------------------------------------------------------------------
-- $Id: onehot2encoded.vhd,v 1.2 2003/03/31 19:15:36 anitas Exp $
-------------------------------------------------------------------------------
-- onehot2encoded.vhd - entity/architecture pair
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
-- Filename:        onehot2encoded.vhd
-- Version:         v1.02d
-- Description:     This file converts a one-hot bus to an encoded bus.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   General use module
-------------------------------------------------------------------------------
-- Author:      ALS
-- History:
--  ALS         08/28/01        -- Version 1.01a creation to include IPIF v1.22a
--  ALS         10/04/01        -- Version 1.02a creation to include IPIF v1.23a
--  ALS         11/27/01
-- ^^^^^^
--  Version 1.02b created to fix registered grant problem.
-- ~~~~~~
--  ALS         01/26/02
-- ^^^^^^
--  Created version 1.02c to fix problem with registered grants, and buslock when
--  the buslock master is holding request high and performing conversion cycles.
-- ~~~~~~
--  ALS         01/09/03
-- ^^^^^^
--  Created version 1.02d to register OPB_timeout to improve timing
-- ~~~~~~
-- 
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

-------------------------------------------------------------------------------
-- OPB_ARB_PKG includes necessary constants and functions
-------------------------------------------------------------------------------
library opb_arbiter_v1_02_d;
use opb_arbiter_v1_02_d.opb_arb_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_1HOT_BUS_SIZE -- number of bits in the 1-hot bus
--
-- Definition of Ports:
--          Bus_1hot        -- input 1-hot bus
--          Bus_enc         -- output encoded bus
--
-------------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity onehot2encoded is
    generic (
            C_1HOT_BUS_SIZE : integer   := 8
            );
    port    (
            Bus_1hot     : in    std_logic_vector(0 to C_1HOT_BUS_SIZE-1);
            Bus_enc      : out   std_logic_vector(0 to log2(C_1HOT_BUS_SIZE)-1)
            );
end onehot2encoded;


-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------
architecture implementation of onehot2encoded is 

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- encoder logic requires that the 1hot bus be padded to next power of 2
constant PAD_1HOT_BUS_SIZE : integer := pad_power2(C_1HOT_BUS_SIZE);

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
signal pad_1hot_bus : std_logic_vector(0 to PAD_1HOT_BUS_SIZE-1) := (others => '0');

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- OR_BITS is used to determine if segments of the 1-hot bus are '1'
component or_bits 
    generic (
            C_NUM_BITS      : integer   := 8;
            C_START_BIT     : integer   := 8;
            C_BUS_SIZE      : integer   := 16);
    port    (
            In_bus          : in std_logic_vector(0 to C_BUS_SIZE-1);
            Sig             : in std_logic;
            Or_out          : out std_logic     
            );
end component or_bits;

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- Padded bus generation
-------------------------------------------------------------------------------
pad_1hot_bus(0 to C_1HOT_BUS_SIZE-1) <= Bus_1hot;

-------------------------------------------------------------------------------
-- Encoded Bus generation
-------------------------------------------------------------------------------
-- Note this logic uses the padded version of the 1hot bus to insure that 
-- the calculations are on a constant which is a power of 2

ENC_BUS_GEN: for i in 0 to log2(PAD_1HOT_BUS_SIZE)-1 generate

signal temp_or  : std_logic_vector(0 to 2**i) := (others => '0');

begin

    OR_GENERATE: for j in 1 to 2**i generate
        
        BUS_OR: or_bits
            generic map ( C_NUM_BITS    => PAD_1HOT_BUS_SIZE/2**(i+1),
                          C_START_BIT   => PAD_1HOT_BUS_SIZE/2**(i+1)
                                            + (j-1)*PAD_1HOT_BUS_SIZE/2**i,
                          C_BUS_SIZE    => PAD_1HOT_BUS_SIZE
                        )
            port map (
                        In_Bus      => pad_1hot_bus,
                        Sig         => temp_or(j-1),
                        Or_out      => temp_or(j)
                     );
    end generate OR_GENERATE;
    
    Bus_enc(i) <= temp_or(2**i);
    
end generate ENC_BUS_GEN;

end implementation;
