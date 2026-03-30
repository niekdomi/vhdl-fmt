-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_rcv_data_if_fifo.vhd,v 1.1 2004/05/13 20:28:16 mlovejoy Exp $
-------------------------------------------------------------------------------
--  PLB to OPB Bridge Out, Receive Data Interface FIFO - Module
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
-- Filename:       plb2opb_bridge_rcv_data_if_fifo.vhd
-- Version:        v1.01a
-- Description:
--      This module provides the fifo interface between OPB and PLB logic to 
--      send back read data and status information to the PLB logic. It allows 
--      OPB and PLB busses to be operating at different clock frequencies. 
--      Note that the OPB clock must be running at the same speed as the PLB 
--      clock or slower.
--
-- VHDL-Standard:   VHDL'93
--
--  Design Notes:
--
--    The parameter C_CLK_ASYNC adjusts the synchronization logic
--    to select between synchronous or asynchronous OPB/PLB clocks:
--
--      - C_CLK_ASYNC = 0 means the PLB and OPB clocks must be the same
--      clock signal or the OPB clock must be divided down from the PLB clock
--      by an integer multiple (down to 1/16X). The rising edges of the OPB
--      clock must be phase aligned with the rising edge of the PLB clock.
--
--      - C_CLK_ASYNC = 1 means there does not have to be any timing
--      relationship between OPB and PLB clock except that the OPB clock
--      is slower or equal in frequency to the PLB clock.
--      Note that setting this flag increases the latency of data
--      transfers and utilizes more FPGA resources.
--
--      This logic is only instantiated when C_CLK_ASYNC = 1.
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
--      KD          5/21/01         -- EA 2 Release
--      ALS         11/06/01        -- VHDL conversion
--      ALS         07/09/02        -- Version 1.00b
-- -----------------------------------------------------------------------------
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

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_rcv_data_if_fifo is
  generic (C_DATA_WIDTH : integer   := 32);
  port (
        Rst     : in std_logic;
        Din     : in std_logic_vector (0 to C_DATA_WIDTH-1);
        Wclk    : in std_logic;
        Wen     : in std_logic;
        Dout    : out std_logic_vector (0 to C_DATA_WIDTH-1);
        Rclk    : in std_logic;
        Ren     : out std_logic
        );
end plb2opb_bridge_rcv_data_if_fifo;
 
-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------
architecture plb2opb_bridge_rcv_data_if_fifo of plb2opb_bridge_rcv_data_if_fifo is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
signal ren_i : std_logic;
signal waddr : std_logic_vector(0 to 1 );
signal waddr_rclk_synced : std_logic_vector(0 to 1 );
signal raddr : std_logic_vector(0 to 1 );

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin

Ren <= ren_i;

--  gray code counter for FIFO write addr
WADDR_CNTR: process (Wclk)
begin
  if (Wclk'event and Wclk = '1' ) then
    if Rst = RESET_ACTIVE  then
      waddr <= "00";
    elsif (Wen) = '1'  then
        waddr(0) <= waddr(1);
        waddr(1) <= not(waddr(0));
    end if ;
  end if;
end process WADDR_CNTR;

--  sync write address from OPB to PLB clock domains
WADDR_RCLK_SYNC: process (Rclk)
begin
  if (Rclk'event and Rclk = '1' ) then
    if Rst= RESET_ACTIVE then
      waddr_rclk_synced <= (others => '0');
    else
      waddr_rclk_synced <= waddr;
    end if ;
  end if;
end process WADDR_RCLK_SYNC;

--  automatically read data from FIFO when read and write addresses do not match
--ren_i <= '1' when (waddr_rclk_synced /= raddr)
--         else '0';
ren_i <= '0' when (waddr_rclk_synced = raddr)
        else '1';
        
--  gray code counter for FIFO read addr
RADDR_CNTR: process (Rclk)
begin
  if (Rclk'event and Rclk = '1' ) then
    if Rst = RESET_ACTIVE  then
      raddr <= (others => '0');
    elsif ren_i = '1'  then
        raddr(0) <= raddr(1);
        raddr(1) <= not(raddr(0));
    end if ;
  end if;
end process RADDR_CNTR;


--  dual port memory declarations
DUALPORT_MEM_GEN: for i in 0 to C_DATA_WIDTH-1 generate
    RAM_I: RAM16X1D
      port map (
        DPO     => Dout(i),     --[out]
        SPO     => open,        --[out]
        A0      => waddr(1),    --[in]
        A1      => waddr(0),    --[in]
        A2      => '0',         --[in]
        A3      => '0',         --[in]
        D       => Din(i),      --[in]
        DPRA0   => raddr(1),    --[in]
        DPRA1   => raddr(0),    --[in]
        DPRA2   => '0',         --[in]
        DPRA3   => '0',         --[in]
        WCLK    => Wclk,        --[in]
        WE      => Wen          --[in]
        );
end generate DUALPORT_MEM_GEN;

end ;

