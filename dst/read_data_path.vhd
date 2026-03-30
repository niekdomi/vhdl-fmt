-------------------------------------------------------------------------------
-- $Id: read_data_path.vhd,v 1.6 2006/09/15 10:01:20 kravi Exp $
-------------------------------------------------------------------------------
-- read_data_path.vhd - entity/architecture pair
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
-- Filename:        read_data_path.vhd
-- Version:         v1.12.a
-- Description:     This file contains the logic to synchronize the read data
--                  for the DDR design.
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
-- Author:          ALS
-- History:
--   ALS           05/15/02    First Version
--
--   ALS            06/07/02
-- ^^^^^^
--  Changed read data path to use an asynchronous FIFO to capture data and 
--  re-align to internal FPGA clock
-- ~~~~~~
-- 
--  ALS             06/11/02
-- ^^^^^^
--  Since FDDRSE is only in Virtex2 and Virtex2P, don't need generate statements
--  for different FIFO types.
-- ~~~~~~
--  ALS             07/16/02
-- ^^^^^^
--  When C_INCLUDE_BURSTS=1, the IP2Bus_RdAck signal must precede the data by
--  one clock so the FIFO_EMPTY signal is negated and used to generate RdAck
--  without the register delay.
-- ~~~~~~
--  ALS             09/25/02
-- ^^^^^^
--  To allow for either pullups or pulldowns on DQS, will now register DQS on 
--  both falling and rising edge of DDR clock and verify that it is 0 and then 1
--  before writing data to the FIFO
-- ~~~~~~
--  ALS             07/08/03
-- ^^^^^^
--  Removed instantiation of Coregen FIFO - instead modified code so that 
--  XST would call Coregen to instantiate the FIFO.
-- ~~~~~~
--  JLJ             11/11/03
-- ^^^^^^
--  Version D: Add logic to support ECC check bit read registers. Add async FIFO
--  for ECC check bits.
-- ~~~~~~
--  JLJ             02/16/04
-- ^^^^^^
--  Remove C_INCLUDE_BURSTS generic parameter.  Not being used.
-- ~~~~~~
--  JLJ             02/19/04
-- ^^^^^^
--  Use coregen_comp_defs to use package in proc_common_v2_00_a.
-- ~~~~~~
--  JLJ             03/18/04
-- ^^^^^^
--  Updated to version v1.11a.  Added support for Virtex4 (uses family.vhd in
--  proc_common_v2_00_a).  Also updated to proc_common_v2_00_a.
-- ~~~~~~
--  Nitin Kabra     02/21/05
-- ^^^^^^
--  Added signal FIFO_Rden. This is used for reading FIFO in multiple_datawidth
--  module.
-- ~~~~~~
--  JLJ             10/4/05
-- ^^^^^^
--  Merge FIFO read enable signal, fifo_rden with ECC FIFO read enable signal,
--  fifo_rden_ecc when ECC logic is enabled.
-- ~~~~~~
--  Nitin Kabra             11/6/05     
-- ^^^^^^
--  Modified to fix the bugs in timing sinulation with ECC.
--  1. Added parameter C_DDR_CAS_LAT & C_REG_DIMM
--  2. Added signals input port Rd_addrack.
--  3. Seperated the fifo control signals (write & read) using conditional
--     generate.
-- ~~~~~~
--  Nitin Kabra             03/03/06     
-- ^^^^^^
--  1. Initialized signal vector rd_addr_ack_bus on reset.
--  2. Assigned default values (as published in design doc) to all generics
--     in entity declaration.
--  3. Removed reset on signal vector rd_addr_ack_bus back to the original code.
-- ~~~~~~
--  Avinash     8/24/2006  v3.00.a
-- ^^^^^^
-- Upgraded library version to ddr_v3_00_a
-- Added generate condition for fifo when (C_IPIF_DWIDTH/C_DDR_DWIDTH=4)
-- When (C_IPIF_DWIDTH/C_DDR_DWIDTH=4) the first 32-bit of dd_readdata is
-- registered.
-- The 64-bit of ddr_readdata is written in fifo when second 32 bit of dd_readdata
-- is available. 
-- The fifo write control depends on the delayed fifo_wren and 
-- non delayed fifo_wren signal.
-- ~~~~~~
--  Avinash     8/28/2006  v3.00.a
-- ^^^^^^
-- Added generate condition for (C_IPIF_DWIDTH/C_DDR_DWIDTH=1)
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
use unisim.vcomponents.all;

-- synopsys translate_off
library XilinxCoreLib;
-- synopsys translate_on

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_IPIF_DWIDTH         -- width of the IPIF data bus
--      C_DDR_DWIDTH          -- ddr data width
--      C_FAMILY              -- target FPGA family type
--      C_INCLUDE_ECC_SUPPORT -- include ECC support
--      C_DDR_CAS_LAT         -- Device CAS latency
--      C_REG_DIMM            -- support registered ddr dimm
--      NUM_ECC_BITS          -- number of ECC check bits
--
-- Definition of Ports:
--      -- inputs
--      DDR_ReadData        -- data input from DDR
--      DDR_ReadData_ECC    -- check bit data input from DDR
--      DDR_ReadDQS         -- data strobe input from DDR
--      DDR_ReadDQS_ECC     -- ECC data strobe input from DDR
--      DDR_read_data_en    -- gates the DDR input FIFO write enable
--      Read_data_en        -- read data enable - used to reset FIFO
--
--      -- outputs
--      Read_data           -- read data synchronized to FPGA clock
--      ECC_chk_bits_rd     -- ECC check bit read data synchronized to 
--                             FPGA clock
--      RdAck               -- read data acknowledge
--      FIFO_Rden           -- fifo read enable for address sel FIFO in 
--                             multiple_datawidth module
--      Rd_addrack          -- read address acknowledge
--
--      -- Clocks and reset
--      Clk                 -- bus clock
--      Clk_ddr_rddata      -- DDR feedback clock shifted 90
--      Rst               
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity read_data_path is
  generic ( 
        C_IPIF_DWIDTH         : integer := 64;
        C_DDR_DWIDTH          : integer := 32;
        C_FAMILY              : string  := "virtex2p";
        C_INCLUDE_ECC_SUPPORT : integer := 0;
        C_DDR_CAS_LAT         : integer := 2;
        C_REG_DIMM            : integer := 0;
        NUM_ECC_BITS          : integer := 7
        );
  port (
        DDR_ReadData          : in  std_logic_vector(0 to (2*C_DDR_DWIDTH)-1);
        DDR_ReadData_ECC      : in  std_logic_vector(0 to NUM_ECC_BITS*2-1); 
        DDR_ReadDQS           : in  std_logic_vector(0 to C_DDR_DWIDTH/8-1);
        DDR_ReadDQS_ECC       : in  std_logic;                               
        DDR_read_data_en      : in  std_logic;
        Read_data_en          : in  std_logic;
        RdAck_rst             : in  std_logic;
        Read_data             : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
        ECC_chk_bits_rd       : out std_logic_vector(0 to NUM_ECC_BITS*2-1); 
        RdAck                 : out std_logic;
        FIFO_Rden             : out std_logic;
        Rd_addrack            : in  std_logic;
        -- Clocks and reset
        Clk                   : in  std_logic;
        Clk_ddr_rddata        : in  std_logic;
        Rst                   : in  std_logic
    );
end entity read_data_path;

-------------------------------------------------------------------------------
-- Architecture section
-------------------------------------------------------------------------------

architecture imp of read_data_path is
-------------------------------------------------------------------------------
-- Constant declarations
-------------------------------------------------------------------------------

constant ZERO_EMPTY       : std_logic_vector(0 to C_DDR_DWIDTH*2/16-1)
                            := (others => '0');
constant ZERO_EMPTY_i     : std_logic_vector(0 to C_DDR_DWIDTH*4/16-1)
                            := (others => '0');                            
--constant ONE              : std_logic_vector(0 to C_DDR_DWIDTH*2/16-1)
--                            := (others => '1');                            
constant DELAY_RDADDR_ACK : integer := C_DDR_CAS_LAT + C_REG_DIMM + 1;

-------------------------------------------------------------------------------
-- Signal declarations
-------------------------------------------------------------------------------
-- fifo control signals
signal fifo_rden_i     : std_logic;
signal fifo_wren       : std_logic_vector(0 to C_DDR_DWIDTH*2/16-1);
signal fifo_wren_d1    : std_logic_vector(0 to C_DDR_DWIDTH*2/16-1);
signal fifo_wren_i     : std_logic_vector(0 to C_DDR_DWIDTH*4/16-1); 
signal fifo_wren_gate  : std_logic_vector(0 to C_DDR_DWIDTH*2/16-1);
signal fifo_empty      : std_logic_vector(0 to C_DDR_DWIDTH*2/16-1);
signal fifo_empty_i    : std_logic_vector(0 to C_DDR_DWIDTH*4/16-1);
signal fifo_rst        : std_logic;

-- internal signals
signal read_data_i     : std_logic_vector(0 to 2*C_DDR_DWIDTH-1);
signal ddr_readdata_reg: std_logic_vector(0 to 2*C_DDR_DWIDTH-1);
signal rdack_i         : std_logic;
signal fifo_empty_ecc  : std_logic;

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin


-------------------------------------------------------------------------------
-- Set output signals
-------------------------------------------------------------------------------
FIFO_Rden <= fifo_rden_i;

-- Create generate for fifo_rden signal when ECC is disabled
FIFO_RDEN_GEN: if C_INCLUDE_ECC_SUPPORT = 0 generate

  ---------------------------------------------------------------------------
  -- FIFO control signals
  ---------------------------------------------------------------------------
  -- write the FIFOs when the DDR asserts the data strobe
  FIFO_WREN_GEN: for i in 0 to 2*C_DDR_DWIDTH/16-1 generate
  begin
        FIFO_WREN_GATE_PROCESS: process(Clk_ddr_rddata)
        begin
            if Clk_ddr_rddata'event and Clk_ddr_rddata = '1' then
                if DDR_read_data_en = '0' then
                    fifo_wren_gate(i) <= '0';
                elsif DDR_ReadDQS(i)='0' then
                    fifo_wren_gate(i) <= '1';
                end if;
            end if;
        end process FIFO_WREN_GATE_PROCESS;
        
        fifo_wren(i)  <= '1' when (DDR_ReadDQS(i)='1' and 
                               fifo_wren_gate(i)='1')         
                          else '0';
                          
  end generate FIFO_WREN_GEN;
  
end generate FIFO_RDEN_GEN;

  -----------------------------------------------------------
  -- Generate statement when (C_IPIF_DWIDTH/C_DDR_DWIDTH=4)
  -----------------------------------------------------------
  GEN_FIFO_WREN_BUS4XDDR: if (C_IPIF_DWIDTH/C_DDR_DWIDTH=4) generate
  begin
      
      -------------------------------------------------------
      --Process to register the first 32-bit of ddr_readdata
      -------------------------------------------------------
    
         REG_RDDATA_PROCESS: process(Clk_ddr_rddata)
           begin
            if Clk_ddr_rddata'event and Clk_ddr_rddata = '1' then
                  ddr_readdata_reg <= DDR_ReadData;
            end if;   
         end process REG_RDDATA_PROCESS;
         
      -----------------------------------------------------------
      --process to generate the delayed single clock pulse of
      --fifo_wren signal.
      -----------------------------------------------------------
      FIFO_WREN_GEN1: for i in 0 to 2*C_DDR_DWIDTH/16-1 generate
      begin
        FIFO_WREN_PROCESS: process(Clk_ddr_rddata)
         begin
             if Clk_ddr_rddata'event and Clk_ddr_rddata = '1' then
                if DDR_read_data_en = '0' then
                    fifo_wren_d1(i) <= '0';
                 elsif fifo_wren(i) = '1' then
                    fifo_wren_d1(i) <= not(fifo_wren_d1(i));
                 else
                    fifo_wren_d1(i) <= '0';
                 end if;
             end if;
        end process FIFO_WREN_PROCESS;
       end generate FIFO_WREN_GEN1;  
      ----------------------------------------------------------   
      -- Replicating 2-bit fifo_wren_d1 signal to generate
      -- 4-bit fifo_wren_i signal.
      ----------------------------------------------------------
         fifo_wren_i <= fifo_wren_d1 & fifo_wren_d1; 
      ----------------------------------------------------------         
                   
  end generate GEN_FIFO_WREN_BUS4XDDR;
      
      
--------------------------------------------------
--ecc
--------------------------------------------------     

-- Create generate for fifo_rden signal when ECC is enabled
FIFO_RDEN_GEN_ECC: if C_INCLUDE_ECC_SUPPORT = 1 generate

signal rd_addr_ack_bus : std_logic_vector(0 to DELAY_RDADDR_ACK);
signal fifo_write      : std_logic;

begin

    RD_ADDR_ACK_REG_PROCESS: process (Clk_ddr_rddata)
        begin
            if(Clk_ddr_rddata'event and Clk_ddr_rddata='1')then
                rd_addr_ack_bus(0) <= Rd_addrack;
            end if;
    end process RD_ADDR_ACK_REG_PROCESS;
    
    READDR_ACK_REG_GEN : for i in 0 to DELAY_RDADDR_ACK-1 generate
    
        READDR_ACK_REG_PROCESS: process (Clk_ddr_rddata)
            begin
                if(Clk_ddr_rddata'event and Clk_ddr_rddata='1')then
                    rd_addr_ack_bus(i+1) <= rd_addr_ack_bus(i);
                end if;
        end process READDR_ACK_REG_PROCESS;
    
    end generate READDR_ACK_REG_GEN;
    
    fifo_write <= rd_addr_ack_bus(DELAY_RDADDR_ACK);

    ---------------------------------------------------------------------------
    -- FIFO control signals
    ---------------------------------------------------------------------------
    -- write the FIFOs when the DDR asserts the data strobe
    FIFO_WREN_GEN: for i in 0 to 2*C_DDR_DWIDTH/16-1 generate
    begin
        FIFO_WREN_GATE_PROCESS: process(Clk_ddr_rddata)
        begin
            if Clk_ddr_rddata'event and Clk_ddr_rddata = '1' then
                if DDR_read_data_en = '0' then
                    fifo_wren_gate(i) <= '0';
                elsif DDR_ReadDQS(i)='0' then
                    fifo_wren_gate(i) <= '1';
                end if;
            end if;
        end process FIFO_WREN_GATE_PROCESS;

        fifo_wren(i) <= '1' when (DDR_ReadDQS(i)='1' and fifo_wren_gate(i)='1' 
                              and fifo_write='1')
                             else '0';

    end generate FIFO_WREN_GEN;
    
end generate FIFO_RDEN_GEN_ECC;

------------------------------------------------------------
-- Create generate for fifo_rden signal when ECC is enabled
------------------------------------------------------------
GEN_FIFORDEN_ECC: if (C_INCLUDE_ECC_SUPPORT = 1 and C_DDR_DWIDTH=32) generate
-- read the FIFOs when all FIFOs are not empty
    fifo_rden_i <= '1' when (fifo_empty = ZERO_EMPTY and fifo_empty_ecc = '0')
                     else '0';
end generate GEN_FIFORDEN_ECC;

------------------------------------------------------------
-- Create generate for fifo_rden signal when ECC is disable and 
-- C_DDR_DWIDTH= 32 or 64.
------------------------------------------------------------
GEN_FIFORDEN_NOECC: if (C_INCLUDE_ECC_SUPPORT = 0 and (C_DDR_DWIDTH=32
                      or C_DDR_DWIDTH=64)) generate
-- read the FIFOs when all FIFOs are not empty
    fifo_rden_i <= '1' when fifo_empty = ZERO_EMPTY
                     else '0';
end generate GEN_FIFORDEN_NOECC;



--------------------------------------------------
--ecc end
--------------------------------------------------


-- reset the FIFOs when the read data phase is over
FIFO_RST_REG: process(Clk)
begin
    if Clk'event and Clk = '1' then
        if Rst = RESET_ACTIVE then
            fifo_rst <= RESET_ACTIVE;
        else
            fifo_rst <= not(Read_data_en);
        end if;
     end if;
end process FIFO_RST_REG;
-------------------------------------------------------------------------------
-- Generate RdAck
-------------------------------------------------------------------------------
RDACK_PROCESS: process(Clk)
begin
    if Clk'event and Clk='1' then
       if Rst = RESET_ACTIVE or RdAck_rst = '1' then
            rdack_i <= '0';
        else
            rdack_i <= fifo_rden_i;
        end if;
    end if;
end process RDACK_PROCESS;

          
          RdAck <= rdack_i;
-------------------------------------------------------------------------------
-- Instantiate the FIFOs when (C_IPIF_DWIDTH/C_DDR_DWIDTH=1)
-- 
-------------------------------------------------------------------------------
-- use one FIFO for each DQS. Since there are 8 bytes from the DDR each 
-- clock,one DQS bit corresponds to 8-bit data. Therefore, instantiate 8-bit 
-- wide FIFOs
-------------------------------------------------------------------------------
-- DDR_Readdata bus width is 128-bit if C_DDR_DWIDTH=64,
-- but only upper 64-bit of DDR_Readdata bus is connected to FIFO's
-------------------------------------------------------------------------------
GEN_RD_DATA_BUS1XDDR: if (C_IPIF_DWIDTH/C_DDR_DWIDTH=1) generate

    FIFO_GEN: for i in 0 to C_DDR_DWIDTH/8-1 generate
        V2_ASYNCH_FIFO_I: async_fifo_v4_0
        generic map(
            c_enable_rlocs     => 0,
            c_data_width       => 8,
            c_fifo_depth       => 15,
            c_has_almost_full  => 0,
            c_has_almost_empty => 0,
            c_has_wr_count     => 0,
            c_has_rd_count     => 0,
            c_wr_count_width   => 2,
            c_rd_count_width   => 2,
            c_has_rd_ack       => 0,
            c_rd_ack_low       => 0,
            c_has_rd_err       => 0,
            c_rd_err_low       => 0,
            c_has_wr_ack       => 0,
            c_wr_ack_low       => 0,
            c_has_wr_err       => 0,
            c_wr_err_low       => 0,
            c_use_blockmem     => 0
            )
        port map (
            din          => DDR_ReadData(i*8 to i*8+7),
            wr_en        => fifo_wren(i),
            wr_clk       => Clk_ddr_rddata,
            rd_en        => fifo_rden_i,
            rd_clk       => Clk,
            ainit        => fifo_rst,
            dout         => read_data_i(i*8 to i*8+7),
            full         => open,
            empty        => fifo_empty(i),
            almost_full  => open,
            almost_empty => open,
            wr_count     => open,
            rd_count     => open,
            rd_ack       => open,
            rd_err       => open,
            wr_ack       => open,
            wr_err       => open
            );
    end generate FIFO_GEN;
    
 --Passing upper 64-bit of read_data_i bus   
 Read_data <= read_data_i(0 to C_DDR_DWIDTH-1);

end generate GEN_RD_DATA_BUS1XDDR;

-------------------------------------------------------------------------------
-- Instantiate the FIFOs when (C_IPIF_DWIDTH/C_DDR_DWIDTH=2)
-- 
-------------------------------------------------------------------------------
-- use one FIFO for each DQS. Since there are two bytes from the DDR each 
-- clock,one DQS bit corresponds to 16-bit data. Therefore, instantiate 16-bit 
-- wide FIFOs
-------------------------------------------------------------------------------
GEN_RD_DATA_BUS2XDDR: if (C_IPIF_DWIDTH/C_DDR_DWIDTH=2) generate

    FIFO_GEN: for i in 0 to 2*C_DDR_DWIDTH/16-1 generate
        V2_ASYNCH_FIFO_I: async_fifo_v4_0
        generic map(
            c_enable_rlocs     => 0,
            c_data_width       => 16,
            c_fifo_depth       => 15,
            c_has_almost_full  => 0,
            c_has_almost_empty => 0,
            c_has_wr_count     => 0,
            c_has_rd_count     => 0,
            c_wr_count_width   => 2,
            c_rd_count_width   => 2,
            c_has_rd_ack       => 0,
            c_rd_ack_low       => 0,
            c_has_rd_err       => 0,
            c_rd_err_low       => 0,
            c_has_wr_ack       => 0,
            c_wr_ack_low       => 0,
            c_has_wr_err       => 0,
            c_wr_err_low       => 0,
            c_use_blockmem     => 0
            )
        port map (
            din          => DDR_ReadData(i*16 to i*16+15),
            wr_en        => fifo_wren(i),
            wr_clk       => Clk_ddr_rddata,
            rd_en        => fifo_rden_i,
            rd_clk       => Clk,
            ainit        => fifo_rst,
            dout         => read_data_i(i*16 to i*16+15),
            full         => open,
            empty        => fifo_empty(i),
            almost_full  => open,
            almost_empty => open,
            wr_count     => open,
            rd_count     => open,
            rd_ack       => open,
            rd_err       => open,
            wr_ack       => open,
            wr_err       => open
            );
    end generate FIFO_GEN;
       
   Read_data <= read_data_i;
   
end generate GEN_RD_DATA_BUS2XDDR;


-------------------------------------------------------------------------------
-- Generating READ DATA depending on the DDR Data width
-- when (C_IPIF_DWIDTH/C_DDR_DWIDTH=4)
-------------------------------------------------------------------------------
GEN_RD_DATA_BUS4XDDR: if (C_IPIF_DWIDTH/C_DDR_DWIDTH=4) generate

    signal ddr_readdata_64 : std_logic_vector(0 to 4*C_DDR_DWIDTH-1);
    signal read_data_64    : std_logic_vector(0 to C_IPIF_DWIDTH-1);
    
    begin
    
       --creating 64-Bit ddr read data bus
       ddr_readdata_64 <= ddr_readdata_reg & DDR_ReadData;
    -------------------------------------------------------------------------------
    -- Instantiate the FIFOs
    -------------------------------------------------------------------------------
    -- use one FIFO for each DQS. Since there are two bytes from the DDR each 
    -- clock,one DQS bit corresponds to 16-bit data. Therefore, instantiate 16-bit 
    -- wide FIFOs
              
        FIFO_GEN: for i in 0 to 4*C_DDR_DWIDTH/16-1 generate
        
            V2_ASYNCH_FIFO_I: async_fifo_v4_0
            generic map(
                c_enable_rlocs     => 0,
                c_data_width       => 16,
                c_fifo_depth       => 15,
                c_has_almost_full  => 0,
                c_has_almost_empty => 0,
                c_has_wr_count     => 0,
                c_has_rd_count     => 0,
                c_wr_count_width   => 2,
                c_rd_count_width   => 2,
                c_has_rd_ack       => 0,
                c_rd_ack_low       => 0,
                c_has_rd_err       => 0,
                c_rd_err_low       => 0,
                c_has_wr_ack       => 0,
                c_wr_ack_low       => 0,
                c_has_wr_err       => 0,
                c_wr_err_low       => 0,
                c_use_blockmem     => 0
                )
            port map (
                din          => ddr_readdata_64(i*16 to i*16+15),
                wr_en        => fifo_wren_i(i),
                wr_clk       => Clk_ddr_rddata,
                rd_en        => fifo_rden_i,
                rd_clk       => Clk,
                ainit        => fifo_rst,
                dout         => read_data_64(i*16 to i*16+15),
                full         => open,
                empty        => fifo_empty_i(i),
                almost_full  => open,
                almost_empty => open,
                wr_count     => open,
                rd_count     => open,
                rd_ack       => open,
                rd_err       => open,
                wr_ack       => open,
                wr_err       => open
                );
    end generate FIFO_GEN;
       

          Read_data <= read_data_64;
    
          -- read the FIFOs when all FIFOs are not empty
          fifo_rden_i <= '1' when fifo_empty_i = ZERO_EMPTY_i
                          else '0';
end generate GEN_RD_DATA_BUS4XDDR;

-- Generate FIFO for ECC check bit data if C_INCLUDE_ECC_SUPPORT = 1
ECC_FIFO_GEN: if C_INCLUDE_ECC_SUPPORT = 1 generate

signal fifo_wren_ecc_gate : std_logic;
signal fifo_wren_ecc      : std_logic;
signal ecc_chk_bits_rd_i  : std_logic_vector (0 to NUM_ECC_BITS*2-1);

begin

    FIFO_WREN_ECC_GATE_PROCESS: process(Clk_ddr_rddata)
    begin
        if Clk_ddr_rddata'event and Clk_ddr_rddata = '1' then
            if DDR_read_data_en = '0' then
                fifo_wren_ecc_gate <= '0';
            elsif DDR_ReadDQS_ECC = '0' then
                fifo_wren_ecc_gate <= '1';
            end if;
        end if;
    end process FIFO_WREN_ECC_GATE_PROCESS;

    fifo_wren_ecc  <= '1' when (DDR_ReadDQS_ECC='1' and fifo_wren_ecc_gate='1')
                          else '0';


    V2_ASYNCH_FIFO_I: async_fifo_v4_0
    generic map(
        c_enable_rlocs     => 0,
        c_data_width       => (NUM_ECC_BITS*2),
        c_fifo_depth       => 15,
        c_has_almost_full  => 0,
        c_has_almost_empty => 0,
        c_has_wr_count     => 0,
        c_has_rd_count     => 0,
        c_wr_count_width   => 2,
        c_rd_count_width   => 2,
        c_has_rd_ack       => 0,
        c_rd_ack_low       => 0,
        c_has_rd_err       => 0,
        c_rd_err_low       => 0,
        c_has_wr_ack       => 0,
        c_wr_ack_low       => 0,
        c_has_wr_err       => 0,
        c_wr_err_low       => 0,
        c_use_blockmem     => 1
        )
    port map (
        din          => DDR_ReadData_ECC,
        wr_en        => fifo_wren_ecc,
        wr_clk       => Clk_ddr_rddata,
        rd_en        => fifo_rden_i,
        rd_clk       => Clk,
        ainit        => fifo_rst,
        dout         => ecc_chk_bits_rd_i,
        full         => open,
        empty        => fifo_empty_ecc,
        almost_full  => open,
        almost_empty => open,
        wr_count     => open,
        rd_count     => open,
        rd_ack       => open,
        rd_err       => open,
        wr_ack       => open,
        wr_err       => open 
        );

    ECC_chk_bits_rd <= ecc_chk_bits_rd_i;

end generate ECC_FIFO_GEN;

end imp;
-------------------------------------------------------------------------------
-- End of File read_data_path.vhd
-------------------------------------------------------------------------------