-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_rcv_data_if.vhd,v 1.2 2004/11/23 01:06:22 jcanaris Exp $
-------------------------------------------------------------------------------
--  PLB to OPB Bridge Out, Receive Data Interface - Module
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
--  Filename:           plb2opb_bridge_rcv_data_if.vhd
--  Version:            v1.01a
--  Description:
--    This module interfaces between OPB and PLB logic to send back read data
--    and status information to the PLB logic. It allows OPB and PLB busses
--    to be operating at different clock frequencies. Note that the OPB clock
--    must be running at the same speed as the PLB clock or slower.
--
--  VHDL-Standard:   VHDL'93
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
--      MLL         03/08/04        -- Added reset to TFLOPLOW_CNTR process.
--                                     CR 176200
--  LCW	Oct 18, 2004	  -- updated for NCSim
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
use ieee.std_logic_UNSIGNED.all;

library unisim;
use unisim.vcomponents.all;

library plb2opb_bridge_v1_01_a;
use plb2opb_bridge_v1_01_a.plb2opb_bridge_rcv_data_if_fifo;




library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_rcv_data_if is
  generic (C_CLK_ASYNC       : integer := 0;
           C_RCV_DATA_WIDTH  : integer   := 38);
  port (
        PLB_Clk         : in std_logic;
        OPB_Clk         : in std_logic;
        Rst             : in std_logic;
        OPB_rcv_data    : in std_logic_vector (0 to C_RCV_DATA_WIDTH-1);
        OPB_rcv_strobe  : in std_logic;
        PLB_rcv_data    : out std_logic_vector(0 to C_RCV_DATA_WIDTH-1);
        PLB_rcv_strobe  : out std_logic
        );
end plb2opb_bridge_rcv_data_if;

-------------------------------------------------------------------------------
--  Architecture section
-------------------------------------------------------------------------------
architecture plb2opb_bridge_rcv_data_if of plb2opb_bridge_rcv_data_if is

-------------------------------------------------------------------------------
-- Signal Declaration
-------------------------------------------------------------------------------
signal async_fifo_dout      : std_logic_vector(0 to C_RCV_DATA_WIDTH-1);
signal async_fifo_ren       : std_logic;
signal opb_clk_en_async     : std_logic;
signal opb_clk_en_sync      : std_logic;
signal srl_din              : std_logic;
signal srl_dout             : std_logic;
signal srl_val              : std_logic_vector(0 to 3 );
signal tflop                : std_logic;
signal tflop_d1             : std_logic;
signal tflop_low_cntr       : std_logic_vector(0 to 3 );
signal tflop_period         : std_logic_vector(0 to 3 );

-------------------------------------------------------------------------------
-- Component Declaration
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--  Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
--  Logic to control the transfer of data from OPB to PLB logic when
--  the two clocks are synchronous to each other.
-------------------------------------------------------------------------------
SYNC_CLK_GEN: if C_CLK_ASYNC=0 generate
begin
    --  Connect a toggling flip flop to the OPB clock to measure the period of
    --  the OPB clock relative to the PLB clock.
    TFLOP_REG:process (OPB_Clk)
    begin
        if (OPB_Clk'event and OPB_Clk = '1' ) then
            if Rst = RESET_ACTIVE  then
                tflop <= '0';
            else
                tflop <= not(tflop);
            end if ;
        end if;
    end process TFLOP_REG;

    TFLOP_PLB_REG: process (PLB_Clk)
    begin
        if PLB_Clk'event and PLB_Clk='1' then
            tflop_d1 <= tflop;
        end if;
    end process TFLOP_PLB_REG;

    TFLOPLOW_CNTR: process (PLB_Clk)
    begin
        if (PLB_Clk'event and PLB_Clk = '1' ) then
            if(tflop='1' or Rst = RESET_ACTIVE)  then
                tflop_low_cntr <= (others => '0');
            else
                tflop_low_cntr <= tflop_low_cntr + 1;
            end if ;
        end if;
    end process TFLOPLOW_CNTR;

    TFLOPPERIOD_REG: process (PLB_Clk)
    begin
        if (PLB_Clk'event and PLB_Clk = '1' ) then
            if tflop='1' and tflop_d1='0' then
                tflop_period <= tflop_low_cntr;
            end if ;
        end if;
    end process TFLOPPERIOD_REG;

    --  whenever an edge on the toggle flip flop is detected in the PLB clock
    --  domain, send a pulse down a shift register to generate a clock enable
    --  pulse that is timing aligned with the OPB clock edges
    srl_din <= tflop xor tflop_d1;
    srl_val <= tflop_period- 2;

    OPB_CLK_EN_SRL_I: srl16
    port map (
        Q   => srl_dout,   --[out]
        A0  => srl_val(3), --[in]
        A1  => srl_val(2), --[in]
        A2  => srl_val(1), --[in]
        A3  => srl_val(0), --[in]
        CLK => PLB_Clk,    --[in]
        D   => srl_din     --[in]
        );

    opb_clk_en_sync <= '1' when ((tflop_period = "0001") or srl_dout='1')
                    else '0';

    --  Register the PLB data and strobe signals for best timing
    PLBSYNC_REGS: process (PLB_Clk)
    begin
        if (PLB_Clk'event and PLB_Clk = '1' ) then
            -- added reset 11/9/01 als
            if Rst = RESET_ACTIVE then
                PLB_rcv_data <= (others => '0');
                PLB_rcv_strobe <= '0';
            else
                PLB_rcv_data <= OPB_rcv_data ;
                PLB_rcv_strobe <= opb_clk_en_sync and OPB_rcv_strobe ;
            end if;
        end if;
    end process PLBSYNC_REGS;

end generate SYNC_CLK_GEN;

-------------------------------------------------------------------------------
--  Instantiate FIFO to handle transfer of data from OPB to PLB logic when
--  the two clocks are asynchronous to each other. A simple 4 deep
--  fifo is implemented
-------------------------------------------------------------------------------
ASYNC_CLK_GEN: if C_CLK_ASYNC = 1 generate
begin
    ASYNC_FIFO_I: entity plb2opb_bridge_v1_01_a.plb2opb_bridge_rcv_data_if_fifo
        generic map ( C_DATA_WIDTH => C_RCV_DATA_WIDTH)
        port map (
            Rst     => Rst,
            Din     => OPB_rcv_data,
            Wclk    => OPB_Clk,
            Wen     => OPB_rcv_strobe,
            Dout    => async_fifo_dout,
            Rclk    => PLB_Clk,
            Ren     => async_fifo_ren);

    --  Register the PLB data and strobe signals for best timing
    PLBASYNC_REGS:process (PLB_Clk)
    begin
        if (PLB_Clk'event and PLB_Clk = '1' ) then
            -- added reset 11/9/01 als
            if Rst = RESET_ACTIVE then
                PLB_rcv_data <= (others => '0');
                PLB_rcv_strobe <= '0';
            else
                PLB_rcv_data <= async_fifo_dout ;
                PLB_rcv_strobe <= async_fifo_ren ;
            end if;
        end if;
    end process ;

end generate ASYNC_CLK_GEN;

end ;

