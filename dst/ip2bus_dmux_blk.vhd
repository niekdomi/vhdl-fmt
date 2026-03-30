-------------------------------------------------------------------------------
-- $Id: ip2bus_dmux_blk.vhd,v 1.4 2004/11/23 00:59:54 jcanaris Exp $
-------------------------------------------------------------------------------
-- ip2bus_dmux_blk.vhd - VHD design file
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        ip2bus_dmux_blk.vhd
--
-- Description:     VHDL design file that is a wrapper around the IPIF data
--                  MUX design.
--
-------------------------------------------------------------------------------
-- Structure:
--
--              ip2bus_dmux_blk.vhd
--                    ip2bus_dmux.vhd
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
--
-- History:
--  DET      Aug 21, 2001      -- First version adapted from Visual HDL output
--  LCW	Oct 12, 2004	 -- updated for NCSim
--
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
---------------------------------------------------------------------------------

library IEEE;
use IEEE.Std_Logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.ip2bus_dmux;



entity ip2bus_dmux_blk is
  generic (
           C_DBUS_WIDTH : INTEGER := 32
           );
  port (
        DMA2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
        Intr2Bus_DBus : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
        IP2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
        IP2Bus_Data_sa : out std_logic_vector(0 to C_DBUS_WIDTH - 1 );
        Reset2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
        RFIFO2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
        WFIFO2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 )
        );


end ip2bus_dmux_blk;


architecture implementation of ip2bus_dmux_blk is


begin

  I_IP2BUS_DMUX: entity opb_ipif_v1_23_a.ip2bus_dmux
    generic map (C_DBUS_WIDTH)
    port map (
              IP2Bus_Data => IP2Bus_Data(0 to C_DBUS_WIDTH - 1),
              WFIFO2Bus_Data => WFIFO2Bus_Data(0 to C_DBUS_WIDTH - 1),
              RFIFO2Bus_Data => RFIFO2Bus_Data(0 to C_DBUS_WIDTH - 1),
              DMA2Bus_Data => DMA2Bus_Data(0 to C_DBUS_WIDTH - 1),
              IRPT2Bus_Data => Intr2Bus_DBus(0 to C_DBUS_WIDTH - 1),
              Reset2Bus_Data => Reset2Bus_Data(0 to C_DBUS_WIDTH - 1),
              IP2Bus_Data_sa => IP2Bus_Data_sa(0 to C_DBUS_WIDTH - 1));

end implementation;

