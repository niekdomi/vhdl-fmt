-------------------------------------------------------------------------------
-- $Id: reset_control.vhd,v 1.4 2004/11/23 00:59:54 jcanaris Exp $
-------------------------------------------------------------------------------
-- reset_control.vhd   v1.01a
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        reset_control.vhd
--
-- Description:     This VHDL design file is for the Point Design of the Mauna
--                  Loa Ethernet IPIF Reset support block.
--
-------------------------------------------------------------------------------
-- Structure:
--
--              reset_control.vhd
--                 |
--                 |
--                 |-- ipif_reset.vhd
--
--
-------------------------------------------------------------------------------
-- Author:      Doug Thorpe
--
-- History:
--  Doug Thorpe  Aug 21, 2001 -- V1.01a (initial release)
--  LCW	Oct 12, 2004	 -- updated for NCSim
--
--
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
--      combinatorial signals:                  "*_com"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.ipif_reset;



entity reset_control is
  generic (
           C_IPIF_MIR_ENABLE : BOOLEAN := True;
           C_IPIF_TYPE : INTEGER := 1;
           C_IPIF_BLK_ID : INTEGER := 255;
           C_IPIF_REVISION : INTEGER := 1;
           C_IPIF_MINOR_VERSION : INTEGER := 0;
           C_IPIF_MAJOR_VERSION : INTEGER := 0;
           C_OPB_DBUS_WIDTH : INTEGER := 32  --  Width of the input and output data buses
           );
  port (
        Bus2IP_Clk_i : in std_logic;
        Bus_DBus : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        IP_Reset_RdCE : in std_logic;
        IP_Reset_WrCE : in std_logic;
        Reset : in std_logic;
        Reset2Bus_DBus : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        Reset2Bus_Error : out std_logic;
        Reset2Bus_RdAck : out std_logic;
        Reset2Bus_Retry : out std_logic;
        Reset2Bus_ToutSup : out std_logic;
        Reset2Bus_WrAck : out std_logic;
        Reset2IP_Reset : out std_logic
        );


end reset_control;


architecture implementation of reset_control is



begin

  I_RESET_CONTROLLER: entity opb_ipif_v1_23_a.ipif_reset
    generic map (C_OPB_DBUS_WIDTH,
                 C_IPIF_MIR_ENABLE,
                 C_IPIF_TYPE,
                 C_IPIF_BLK_ID,
                 C_IPIF_REVISION,
                 C_IPIF_MINOR_VERSION,
                 C_IPIF_MAJOR_VERSION)
    port map (
              Reset => Reset,
              Bus2IP_Clk_i => Bus2IP_Clk_i,
              IP_Reset_WrCE => IP_Reset_WrCE,
              IP_Reset_RdCE => IP_Reset_RdCE,
              Bus_DBus => Bus_DBus(0 to C_OPB_DBUS_WIDTH - 1),
              Reset2IP_Reset => Reset2IP_Reset,
              Reset2Bus_DBus => Reset2Bus_DBus(0 to C_OPB_DBUS_WIDTH - 1),
              Reset2Bus_WrAck => Reset2Bus_WrAck,
              Reset2Bus_RdAck => Reset2Bus_RdAck,
              Reset2Bus_Error => Reset2Bus_Error,
              Reset2Bus_Retry => Reset2Bus_Retry,
              Reset2Bus_ToutSup => Reset2Bus_ToutSup);
end implementation;

