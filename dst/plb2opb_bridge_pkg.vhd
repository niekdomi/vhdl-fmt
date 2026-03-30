-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_pkg.vhd,v 1.1 2004/05/13 20:28:16 mlovejoy Exp $
-------------------------------------------------------------------------------
-- PLB2OPB_Bridge - Package
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
-- Filename:        plb2opb_bridge_pkg.vhd
-- Version:         v1.01a
-- Description:     This file contains the constants and functions used in the 
--                  plb2opb_bridge design.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:       
--
-------------------------------------------------------------------------------
-- Author:      ALS
-- History:
--  ALS         11/05/01        -- Created from ipif_pkg.vhd
--  ALS         01/04/02        -- added max2 function
--  ALS         07/09/02        -- Version 1.00b
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
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
-- need conversion function to convert reals/integers to std logic vectors
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


package plb2opb_bridge_pkg is
-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- address bits for word, double word, etc
constant WRD_ADDR_BITS      : integer   := 3;
constant DBLWRD_ADDR_BITS   : integer   := 4;
constant QUADWRD_ADDR_BITS  : integer   := 5;
constant OCTWRD_ADDR_BITS   : integer   := 6;
constant ONEK_ADDR_BITS     : integer   := 10;


-------------------------------------------------------------------------------
-- Type Declarations
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Function and Procedure Declarations
-------------------------------------------------------------------------------
end plb2opb_bridge_pkg;

package body plb2opb_bridge_pkg is
-------------------------------------------------------------------------------
-- Function Definitions
-------------------------------------------------------------------------------

end package body plb2opb_bridge_pkg;
