-------------------------------------------------------------------------------
-- $Id: multiple_datawidth.vhd,v 1.2 2006/09/15 10:01:20 kravi Exp $
-------------------------------------------------------------------------------
-- multiple_datawidth_rd.vhd - entity/architecture pair
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
-- Filename:        multiple_datawidth.vhd
-- Version:         v1.12.a
-- Description:     This file contains the logic which supports ddr_controller
--                  interface with DDR SDRAM with data width dobule than master
--                  data width for read operation.
--                  This design instantiate srl16_fifo (synchronous FIFO)
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--                  ddr_controller.vhd
--                      -- init_statemachine.vhd
--                      -- clock_gen.vhd
--                      -- counters.vhd
--                      -- command_statemachine.vhd
--                      -- multiple_datawidth.vhd
--                      -- data_statemachine.vhd
--                      -- io_registers.vhd
--                      -- read_data_path.vhd
--                      -- ipic_if.vhd
--
-------------------------------------------------------------------------------
-- Author:        Nitin Kabra
-- History:
-- Nitin Kabra    10/11/04    First Version
-- ^^^^^^
-- Updated from the dw64_rd.vhd from ddr_v1_11_a. Used comb_Bus2IP_CS to reset
-- Addr_sel_FIFO. This avoids write in the Addr_sel_FIFO during read abourt.
-- ~~~~~~
-- Nitin Kabra    02/21/05
-- ^^^^^^
-- Combined multiple_datawidth_rd and multiple_datawidth_wr in multiple_datawidth.
-- ~~~~~~
--  Nitin Kabra            03/30/05
-- ^^^^^^
--  Modified the generation of MW_BE_out: -
--  When DDR data width is equal or double the IPIF data width. As only rising 
--  edge is used for writting to DDR SDRAM -
--  1. Removed muxing when C_DDR_DWIDTH = C_IPIF_DWIDTH
--  2. Muxed only for the (0 to C_DDR_DWIDTH/8-1) bits of MW_BE_out.
--
--  Signal Addr_sel is made (0 to 0)
-- ~~~~~~
--  Nitin Kabra            03/30/05
-- ^^^^^^
--  1. Deleted unused "Addr28_fifo_wren" from Definition of Ports in comments.
--  2. All parameters in the entiy are assigned to default values as published
--     in document.
-- ~~~~~~
--  Avinash     8/23/2006  v3.00.a
-- ^^^^^^
-- Upgraded library version to ddr_v3_00_a
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
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library proc_common_v2_00_a;
use proc_common_v2_00_a.coregen_comp_defs.all;
use proc_common_v2_00_a.proc_common_pkg.all;

library unisim;
use unisim.all;

-- synopsys translate_off
library XilinxCoreLib;
-- synopsys translate_on

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_DDR_DWIDTH       -- ddr data width
--      C_IPIF_DWIDTH      -- ipif data width
--      C_FIFO_DEPTH_LOG2X -- number of bits required to encode occupancy
--
-- Definition of Ports:
--      -- inputs
--      IPIC_be            -- Byte enable input from ipic_if.
--      Read_Data          -- 128-data input from Read Data FIFO
--      Data_FIFO_Rden     -- read enable for Read Data FIFO
--      Addr_sel           -- 28, 29 th bit of address - used for MUX selection 
--      Comb_Bus2IP_CS     -- Bus2IP_CS from ipic_if.
--      Read_data_done     -- read cycle complete
--
--      -- outputs
--      MW_BE_out          -- Byte enable output for data state machine.
--      MW_Readdata        -- read data out
--
--      -- Clocks and reset
--      Clk                -- bus clock
--      Rst                -- reset
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity multiple_datawidth is
  generic ( 
        C_DDR_DWIDTH            : integer := 32;
        C_IPIF_DWIDTH           : integer := 64;
        C_FIFO_DEPTH_LOG2X      : integer
        );
  port (
        IPIC_be             : in  std_logic_vector(0 to ((C_IPIF_DWIDTH/8)-1));
        Read_data           : in  std_logic_vector(0 to C_DDR_DWIDTH-1);
        Data_FIFO_Rden      : in  std_logic;
        Addr_sel_fifo_wren  : in  std_logic;
        Addr_sel            : in  std_logic_vector(0 to 0);
        comb_Bus2IP_CS      : in  std_logic;
        Read_data_done      : in  std_logic;

        --Outputs
        MW_BE_out           : out std_logic_vector(0 to ((C_DDR_DWIDTH/8)-1));
        MW_ReadData         : out std_logic_vector(0 to C_IPIF_DWIDTH-1);

        -- Clocks and reset
        Clk                 : in  std_logic;
        Rst                 : in  std_logic
    );
end entity multiple_datawidth;

-------------------------------------------------------------------------------
-- Architecture section
-------------------------------------------------------------------------------

architecture imp of multiple_datawidth is

-------------------------------------------------------------------------------
-- Constant declarations
-------------------------------------------------------------------------------
constant DATA_MASK_ONES  : std_logic_vector(0 to ((C_IPIF_DWIDTH/8)-1))
                           := (others => '0');

-------------------------------------------------------------------------------
-- Signal declarations
-------------------------------------------------------------------------------
signal addr_sel_d1          : std_logic_vector(0 to 0);
signal mux_sel              : std_logic_vector(0 to 0);

signal addr_sel_fifo_rden   : std_logic;
signal addr_sel_fifo_rst    : std_logic;
signal addr_sel_fifo_empty  : std_logic;

signal read_data_done_d1    : std_logic;
signal read_data_done_d2    : std_logic;
signal read_data_done_re    : std_logic;
signal read_data_done_re_d1 : std_logic;


-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- ADDR_SEL_REG_PROCESS
-------------------------------------------------------------------------------
-- This process will register the Addr_sel on Addr_sel_d
-------------------------------------------------------------------------------
  ADDR_SEL_REG: process(Clk)
    begin
      if Clk'event and Clk='1' then
        if Rst = '1' then
          addr_sel_d1 <= (others => '0');
        else
          addr_sel_d1 <= addr_sel;
        end if;
    end if;
  end process ADDR_SEL_REG;


-------------------------------------------------------------------------------
-- Generate the data mask when C_DDR_DWIDTH/C_IPIF_DWIDTH=2
-------------------------------------------------------------------------------
DDR2XBUS_BE_GEN: if ((C_DDR_DWIDTH/C_IPIF_DWIDTH)=2) generate

  begin

      MW_BE_out(0 to C_DDR_DWIDTH/16-1) <= IPIC_be when addr_sel_d1 = "0" else
                                           DATA_MASK_ONES;

      MW_BE_out(C_DDR_DWIDTH/16 to C_DDR_DWIDTH/8-1) <= IPIC_be 
                                    when addr_sel_d1 = "1" else DATA_MASK_ONES;

end generate DDR2XBUS_BE_GEN;


-------------------------------------------------------------------------------
-- Generate the read enable for the Addr_sel FIFO
-- Since the Addr_sel FIFO is an SRL16 FIFO, the first entry in the FIFO
-- appears on the outputs, therefore, a read enable is not needed at the 
-- beginning of a cycle to get out the first data. All follow-on reads 
-- are generated one clock after the read enable to the Read Data FIFO. The 
-- Addr_sel FIFO read enable stays asserted until the FIFO is emptied.
-------------------------------------------------------------------------------
FIFO_READEN_REG: process (Clk)
begin
    if Clk'event and Clk = '1' then 
        if Rst = '1' or addr_sel_fifo_empty = '1' then
            addr_sel_fifo_rden <= '0'; 
        elsif Data_FIFO_Rden = '1' then 
            addr_sel_fifo_rden <= '1'; 
        end if;
    end if;
end process FIFO_READEN_REG;


-------------------------------------------------------------------------------
-- Registering read_data_done and detecting edge
-------------------------------------------------------------------------------
READ_DATA_DONE_REG: process (Clk)
begin
    if Clk'event and Clk = '1' then
        if Rst = '1' then
            read_data_done_d1       <= '0';
            read_data_done_d2       <= '0';
            read_data_done_re_d1    <= '0';
        else
            read_data_done_d1       <= Read_data_done; 
            read_data_done_d2       <= read_data_done_d1;
            read_data_done_re_d1    <= read_data_done_re;
        end if;
    end if;
end process READ_DATA_DONE_REG;

read_data_done_re <= Read_data_done and not read_data_done_d1;

    -- make reset two clocks wide
    addr_sel_fifo_rst <= read_data_done_re or read_data_done_re_d1 or 
                         Rst or (not comb_Bus2IP_CS);

-------------------------------------------------------------------------------
-- Instantiate the FIFOs
-------------------------------------------------------------------------------
    ADDR_SEL_SYNC_FIFO_I: entity proc_common_v2_00_a.srl16_fifo
        generic map (
                        C_FIFO_WIDTH        => 1,
                        C_FIFO_DEPTH_LOG2X  => C_FIFO_DEPTH_LOG2X,
                        C_INCLUDE_VACANCY   => true
                    )
        port map (
            Bus_clk     =>  Clk ,
            Bus_rst     =>  addr_sel_fifo_rst ,
            Wr_Req      =>  Addr_sel_fifo_wren,
            Wr_Data     =>  addr_sel,
            Rd_Req      =>  addr_sel_fifo_rden,
            Rd_Data     =>  mux_sel,
            Full        =>  open,
            Almostfull  =>  open,
            Empty       =>  addr_sel_fifo_empty,
            Almostempty =>  open,
            Vacancy     =>  open
            );


-------------------------------------------------------------------------------
--Generate the MW_ReadData when C_DDR_DWIDTH/C_IPIF_DWIDTH=2
-------------------------------------------------------------------------------
    DDR2XBUS_READDATA_GEN: if C_DDR_DWIDTH/C_IPIF_DWIDTH=2 generate

        MW_ReadData <= Read_data((C_DDR_DWIDTH/2) to (C_DDR_DWIDTH-1)) 
                       when (mux_sel = "1") else
                       Read_data(0 to ((C_DDR_DWIDTH/2)-1));

    end generate DDR2XBUS_READDATA_GEN;

end imp;
-------------------------------------------------------------------------------
-- End of file multiple_datawidth.vhd
-------------------------------------------------------------------------------