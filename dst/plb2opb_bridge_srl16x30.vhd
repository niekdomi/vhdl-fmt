-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_srl16x30.vhd,v 1.1 2004/05/13 20:28:16 mlovejoy Exp $
------------------------------------------------------------------------------- 
--  PLB to OPB Bridge Out, 30 Bit Wide Shift Register - Module
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
--  Filename:   plb2opb_bridge_srl16x30.vhd
--  Version:    v1.01a
--  Description:
--    This module is a 30 Bit Wide SRL made from SRL16 FPGA primitives. It
--    is a helper module used by the PLB interface block
--
--      If (A1=0) the pipeline delay is 1
--      If (A1=1) the pipeline delay is 3
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--
--            -- plb2opb_bridge.vhd
--               -- plb2opb_bridge_plb_if.vhd
--                  -- plb2opb_bridge_srl16x30.vhd
--               -- plb2opb_bridge_xfer_if.vhd
--               -- plb2opb_bridge_rcv_data_if.vhd
--               -- plb2opb_bridge_opb_if.vhd
--               -- plb2opb_bridge_besr.vhd
--               -- plb2opb_bridge_interrupt.vhd
--
-------------------------------------------------------------------------------
--  Author:
--  History:
--      KD          5/11/01         -- EA 2 Release
--      ALS         11/06/01        -- VHDL conversion
--      ALS         07/09/02        -- Version 1.00b
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

library unisim;
use unisim.vcomponents.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_srl16x30 is
    generic( C_DATA_WIDTH : integer := 30);
    port (
        Clk     : in std_logic;
        D       : in std_logic_vector (0 to C_DATA_WIDTH-1);
        Q       : out std_logic_vector (0 to C_DATA_WIDTH-1);
        A1      : in std_logic
        );
end plb2opb_bridge_srl16x30;
 
-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------
architecture plb2opb_bridge_srl16x30 of plb2opb_bridge_srl16x30 is

-------------------------------------------------------------------------------
--  Component Declaration
------------------------------------------------------------------------------- 
 
-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------
--  Instantiation of FPGA Primitives
-------------------------------------------------------------------------------
SRL_GENERATE: for i in 0 to C_DATA_WIDTH-1 generate
    SRL_I: SRL16
      port map (
            Q   => Q(i), --[out]
            A0  => '0', --[in]
            A1  => A1, --[in]
            A2  => '0', --[in]
            A3  => '0', --[in]
            CLK => Clk, --[in]
            D   => D(i) --[in]
            );
end generate SRL_GENERATE;

end ;

