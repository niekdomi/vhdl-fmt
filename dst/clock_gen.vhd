-------------------------------------------------------------------------------
-- $Id: clock_gen.vhd,v 1.1 2004/10/15 16:12:21 gburch Exp $
-------------------------------------------------------------------------------
-- clock_gen.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--
--  ***************************************************************************
--  **  Copyright(C) 2004 by Xilinx, Inc. All rights reserved.               **
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
-- Filename:        clock_gen.vhd
-- Version:         v1.00e
-- Description:     This file contains the logic to generate SDRAM_Clk,
--                  and Clk based on the generics. 
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--                  sdram_controller.vhd
--                      -- data_statemachine.vhd
--                      -- command_statemachine.vhd
--                      -- init_statemachine.vhd
--                      -- counters.vhd
--                      -- io_registers.vhd
--                      -- ipic_if.vhd
--                      -- clock_gen.vhd
-------------------------------------------------------------------------------
-- Author:          ALS
-- History:
-- ALS           06/11/02    First Version
-- ALS           06/15/02
-- ^^^^^^
--  Cleaned up code for SDRAM 
-- ~~~~~~
-- 
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--
--  ALS             09/09/02
--  ^^^^^^
--  Changed DCM to only be a DCM from SDRAM clock. The system clock used for the
--  rest of the logic should not come from this DCM. CLK output will now be a test
--  clock output, i.e, it will always equal SYS_CLK. The DCM in this file is only
--  useful if a SDRAM clock feedback exists. If this feedback does not exist, the
--  SDRAM_CLK_IN input should be grounded or connected to SYS_CLK.
-- ~~~~~~
--  ALS             10/06/03    Version D            
-- ^^^^^^
-- Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
-- for new PLB IPIF. Removed DCM generics.
-- ~~~~~~
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

library IEEE;
use IEEE.std_logic_1164.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--
-- Definition of Ports:
--  -- inputs
--      Sys_clk                 -- system clock
--      SDRAM_Clk_in            -- sdram clock input
--
--  -- outputs
--      Clk                     -- either SysClk or DCM output
--      SDRAM_Clk               -- SDRAM clock output
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity clock_gen is
  port (
        Sys_clk             : in  std_logic;
        SDRAM_Clk_in        : in  std_logic;
        Clk                 : out std_logic;
        SDRAM_Clk           : out std_logic
    );
end entity clock_gen;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of clock_gen is
-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Attribute declarations
----------------------------------------------------------------------------- 
-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  
    Clk <= Sys_clk;         
    SDRAM_Clk <= SDRAM_Clk_in;
end imp;