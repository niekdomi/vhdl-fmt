-------------------------------------------------------------------------------
-- $Id: io_registers.vhd,v 1.1 2004/10/15 16:12:22 gburch Exp $
-------------------------------------------------------------------------------
-- io_registers.vhd - entity/architecture pair
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
-- Filename:        io_registers.vhd
-- Version:         v1.00e
-- Description:     This file contains all of the io_registers for the SDRAM design.
--                  The output registers are either positive edge or negative
--                  edge registers depending on the C_USE_POSEDGE_OUTREGS 
--                  generic. The input registers are always positive edge registers.
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
--   ALS           06/11/02    First Version
--   ALS           06/15/02
-- ^^^^^^
--  Modifications for SDRAM
-- ~~~~~~
--   ALS            06/25/02
-- ^^^^^^
--  Added attributes in a manner so that XST would put the registers in the IOBs.
--  Added support for SpartanII, Virtex, and VirtexE
-- ~~~~~~
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--  ALS             08/28/02
-- ^^^^^^
--  Instantiated negative edge flip-flops to prevent clock being inverted in a LUT
-- ~~~~~~
--  ALS             03/31/03    
-- ^^^^^^
--  Added generic to allow use of either positive edge or negative edge output
--  registers.
-- ~~~~~~  
--  ALS             10/06/03    Version D            
-- ^^^^^^
-- Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
-- for new PLB IPIF.
-- ~~~~~~
--  GAB             10/13/04    Version E
-- ^^^^^^
--  Updated to use proc_common_v2_00_a library
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
use proc_common_v2_00_a.proc_common_pkg.all;
use proc_common_v2_00_a.family.all;


library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_SDRAM_AWIDTH          -- width of SDRAM address bus
--      C_SDRAM_BANK_AWIDTH     -- width of SDRAM bank address bus
--      C_SDRAM_DWIDTH          -- length of SDRAM burst
--      C_IPIF_DWIDTH           -- SDRAM CAS latency
--      C_FAMILY                -- target FPGA family
--      C_USE_POSEDGE_OUTREGS   -- use positive edge output registers if 1
--                              -- use negative edge output registers if 0
--
-- Definition of Ports:
--  -- inputs
--      Write_data              -- data to be written to SDRAM
--      Write_data_en           -- data enable for SDRAM
--      Write_data_mask         -- data mask for SDRAM
--      DQM_rst                 -- data mask reset
--      DQM_set                 -- data mask set
--      Read_data_en            -- enable for input register
--      RASn                    -- RASn for SDRAM
--      CASn                    -- CASn for SDRAM
--      WEn                     -- WEn for SDRAM
--      BankAddr                -- bank address for SDRAM
--      Addr                    -- address for SDRAM
--      SDRAM_DQ_i              -- data input from SDRAM
--
--  -- outputs
--      SDRAM_ReadData          -- data read from SDRAM
--      SDRAM_DQ_o              -- dq output to ddr
--      SDRAM_DQ_t              -- dq output enable 
--      SDRAM_DQM               -- ddr data mask
--      SDRAM_RASn              -- RASn output to ddr
--      SDRAM_CASn              -- CASn output to ddr
--      SDRAM_WEn               -- WEn output to ddr
--      SDRAM_BankAddr          -- bank address output to ddr
--      SDRAM_Addr              -- address output to ddr
--
--    -- Clocks and reset
--      Clk 
--      Rst               
---------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity io_registers is
  generic ( C_SDRAM_AWIDTH          : integer;
            C_SDRAM_BANK_AWIDTH     : integer;
            C_SDRAM_DWIDTH          : integer;
            C_IPIF_DWIDTH           : integer;
            C_FAMILY                : string;
            C_USE_POSEDGE_OUTREGS   : integer
            );
  port (
        Write_data              : in  std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        Write_data_en           : in  std_logic;
        Write_data_mask         : in  std_logic_vector(0 to C_SDRAM_DWIDTH/8-1);
        DQM_rst                 : in  std_logic;
        DQM_set                 : in  std_logic;
        RASn                    : in  std_logic;
        CASn                    : in  std_logic;
        WEn                     : in  std_logic;
        BankAddr                : in  std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        Addr                    : in  std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        SDRAM_ReadData          : out std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        SDRAM_DQ_i              : in  std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        SDRAM_DQ_o              : out std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        SDRAM_DQ_t              : out std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        SDRAM_DQM               : out std_logic_vector(0 to C_SDRAM_DWIDTH/8-1);
        SDRAM_RASn              : out std_logic;       
        SDRAM_CASn              : out std_logic;
        SDRAM_WEn               : out std_logic;
        SDRAM_BankAddr          : out std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        SDRAM_Addr              : out std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        Clk                     : in  std_logic;
        Rst                     : in  std_logic
    );
    
end entity io_registers;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of io_registers is
-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
-- determine if Virtex2 or Virtex2P type IOBs or if  Virtex, VirtexE,
-- or Spartan type IOBs
-- Virtex2 and Virtex2P IOBS have both set and reset, others do not
constant V2IOBS     : boolean   := derived(C_FAMILY, virtex2);  

-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
signal clk_n                : std_logic;
signal dq_oe                : std_logic;

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  
-- create the control signals
dq_oe               <= not(Write_data_en);
-------------------------------------------------------------------------------
-- Instantiate the IOB Output registers
-------------------------------------------------------------------------------
---------------------- NEGATIVE EDGE OUTPUT REGISTERS--------------------------
NEGEDGE_OUTREGS_GEN: if C_USE_POSEDGE_OUTREGS=0 generate
    attribute iob   : string;
    attribute iob of SDRAM_RASN_REG     : label is "true";
    attribute iob of SDRAM_CASN_REG     : label is "true";
    attribute iob of SDRAM_WEN_REG      : label is "true";

begin    

    SDRAM_DQ_REG_GEN: for i in 0 to C_SDRAM_DWIDTH-1 generate
        attribute iob   : string;
        attribute iob of SDRAM_DQ_REG_I : label is "true";
        attribute iob of SDRAM_DQT_REG_I : label is "true";
        begin
        -- use SDRAM register to generate DQ_o
        SDRAM_DQ_REG_I: FDRE_1
          port map (
            Q   => SDRAM_DQ_o(i),  --[out]
            C   => Clk,          --[in]
            CE  => Write_data_en,  --[in]
            D   => Write_data(i),  --[in]
            R   => Rst             --[in]
          );
        -- use regular register with io attribute for tri-state control  
        SDRAM_DQT_REG_I: FDS_1
          port map (
            Q   => SDRAM_DQ_t(i), --[out]
            C   => Clk,           --[in]
            D   => dq_oe,         --[in]
            S   => Rst            --[in]
          );      
    end generate SDRAM_DQ_REG_GEN;

    SDRAM_DQM_REG_GEN: for i in 0 to C_SDRAM_DWIDTH/8-1 generate
        begin

        -- if Virtex2 type IOBS, use both synchronous set and reset
        V2DQM_GEN: if V2IOBS generate
            attribute iob   : string;
            attribute iob of SDRAM_DQM_REG_I : label is "true";
            begin
            SDRAM_DQM_REG_I: FDRSE_1
              port map (
                Q   => SDRAM_DQM(i),                --[out]
                C   => Clk,                         --[in]
                CE  => Write_data_en,               --[in]
                D   => Write_data_mask(i),          --[in]
                R   => DQM_rst,                     --[in]
                S   => DQM_set                      --[in]
              );
         end generate V2DQM_GEN;

         -- if not V2 IOBs, create signal for write data mask that uses DQM_set
         -- since both set and reset are not available in IOB regs
         NOT_V2DQM_GEN: if not(V2IOBS) generate
            signal dqm_d    : std_logic;
            attribute iob   : string;
            attribute iob of SDRAM_DQM_REG_I : label is "true";
            begin
                dqm_d <= '1' when DQM_set = '1' 
                        else Write_data_mask(i);
                SDRAM_DQM_REG_I: FDRE_1
                  port map (
                    Q   => SDRAM_DQM(i),                --[out]
                    C   => Clk,                         --[in]
                    CE  => Write_data_en,               --[in]
                    D   => dqm_d,                       --[in]
                    R   => DQM_rst                      --[in]
                  );
         end generate NOT_V2DQM_GEN;      
    end generate SDRAM_DQM_REG_GEN;

    -- Can use regular registers with attributes for the rest of the control signals
    -- SDRAM address
    SDRAM_ADDR_REG_GEN: for i in 0 to C_SDRAM_AWIDTH-1 generate
        attribute iob   : string;
        attribute iob of SDRAM_ADDR_REG_I : label is "true";
        begin
        SDRAM_ADDR_REG_I: FDR_1
          port map (
            Q   => SDRAM_Addr(i), --[out]
            C   => Clk,         --[in]
            D   => Addr(i),     --[in]
            R   => Rst          --[in]
          );
    end generate SDRAM_ADDR_REG_GEN;

    -- SDRAM Bank Address
    SDRAM_BANKADDR_REG_GEN: for i in 0 to C_SDRAM_BANK_AWIDTH-1 generate
        attribute iob   : string;
        attribute iob of SDRAM_BANKADDR_REG_I : label is "true";
        begin
        SDRAM_BANKADDR_REG_I: FDR_1
          port map (
            Q   => SDRAM_BankAddr(i), --[out]
            C   => Clk,             --[in]
            D   => BankAddr(i),     --[in]
            R   => Rst              --[in]
          );
    end generate SDRAM_BANKADDR_REG_GEN;

    -- SDRAM RASn, CASn, and WEn
    SDRAM_RASN_REG: FDS_1
      port map (
        Q   => SDRAM_RASn,--[out]
        C   => Clk,     --[in]
        D   => RASn,    --[in]
        S   => Rst      --[in]
      );
    SDRAM_CASN_REG: FDS_1
      port map (
        Q   => SDRAM_CASn,--[out]
        C   => Clk,     --[in]
        D   => CASn,    --[in]
        S   => Rst      --[in]
      );
    SDRAM_WEN_REG: FDS_1
      port map (
        Q   => SDRAM_WEn, --[out]
        C   => Clk,     --[in]
        D   => WEn,     --[in]
        S   => Rst      --[in]
      );
end generate NEGEDGE_OUTREGS_GEN;

---------------------- POSITIVE EDGE OUTPUT REGISTERS--------------------------
POSEDGE_OUTREGS_GEN: if C_USE_POSEDGE_OUTREGS=1 generate
    attribute iob                       : string;
    attribute iob of SDRAM_RASN_REG     : label is "true";
    attribute iob of SDRAM_CASN_REG     : label is "true";
    attribute iob of SDRAM_WEN_REG      : label is "true";

begin    
    SDRAM_DQ_REG_GEN: for i in 0 to C_SDRAM_DWIDTH-1 generate
        attribute iob   : string;
        attribute iob of SDRAM_DQ_REG_I : label is "true";
        attribute iob of SDRAM_DQT_REG_I : label is "true";
        begin
        -- use SDRAM register to generate DQ_o
        SDRAM_DQ_REG_I: FDRE
          port map (
            Q   => SDRAM_DQ_o(i),  --[out]
            C   => Clk,          --[in]
            CE  => Write_data_en,  --[in]
            D   => Write_data(i),  --[in]
            R   => Rst             --[in]
          );
        -- use regular register with io attribute for tri-state control  
        SDRAM_DQT_REG_I: FDS
          port map (
            Q   => SDRAM_DQ_t(i), --[out]
            C   => Clk,           --[in]
            D   => dq_oe,         --[in]
            S   => Rst            --[in]
          );      
    end generate SDRAM_DQ_REG_GEN;

    SDRAM_DQM_REG_GEN: for i in 0 to C_SDRAM_DWIDTH/8-1 generate
        begin

        -- if Virtex2 type IOBS, use both synchronous set and reset
        V2DQM_GEN: if V2IOBS generate
            attribute iob   : string;
            attribute iob of SDRAM_DQM_REG_I : label is "true";
            begin
            SDRAM_DQM_REG_I: FDRSE
              port map (
                Q   => SDRAM_DQM(i),                --[out]
                C   => Clk,                         --[in]
                CE  => Write_data_en,               --[in]
                D   => Write_data_mask(i),          --[in]
                R   => DQM_rst,                     --[in]
                S   => DQM_set                      --[in]
              );
         end generate V2DQM_GEN;

         -- if not V2 IOBs, create signal for write data mask that uses DQM_set
         -- since both set and reset are not available in IOB regs
         NOT_V2DQM_GEN: if not(V2IOBS) generate
            signal dqm_d    : std_logic;
            attribute iob   : string;
            attribute iob of SDRAM_DQM_REG_I : label is "true";
            begin
                dqm_d <= '1' when DQM_set = '1' 
                        else Write_data_mask(i);
                SDRAM_DQM_REG_I: FDRE
                  port map (
                    Q   => SDRAM_DQM(i),                --[out]
                    C   => Clk,                         --[in]
                    CE  => Write_data_en,               --[in]
                    D   => dqm_d,                       --[in]
                    R   => DQM_rst                      --[in]
                  );
         end generate NOT_V2DQM_GEN;      
    end generate SDRAM_DQM_REG_GEN;

    -- Can use regular registers with attributes for the rest of the control signals
    -- SDRAM address
    SDRAM_ADDR_REG_GEN: for i in 0 to C_SDRAM_AWIDTH-1 generate
        attribute iob   : string;
        attribute iob of SDRAM_ADDR_REG_I : label is "true";
        begin
        SDRAM_ADDR_REG_I: FDR
          port map (
            Q   => SDRAM_Addr(i), --[out]
            C   => Clk,         --[in]
            D   => Addr(i),     --[in]
            R   => Rst          --[in]
          );
    end generate SDRAM_ADDR_REG_GEN;

    -- SDRAM Bank Address
    SDRAM_BANKADDR_REG_GEN: for i in 0 to C_SDRAM_BANK_AWIDTH-1 generate
        attribute iob   : string;
        attribute iob of SDRAM_BANKADDR_REG_I : label is "true";
        begin
        SDRAM_BANKADDR_REG_I: FDR
          port map (
            Q   => SDRAM_BankAddr(i), --[out]
            C   => Clk,             --[in]
            D   => BankAddr(i),     --[in]
            R   => Rst              --[in]
          );
    end generate SDRAM_BANKADDR_REG_GEN;

    -- SDRAM RASn, CASn, and WEn
    SDRAM_RASN_REG: FDS
      port map (
        Q   => SDRAM_RASn,--[out]
        C   => Clk,     --[in]
        D   => RASn,    --[in]
        S   => Rst      --[in]
      );
    SDRAM_CASN_REG: FDS
      port map (
        Q   => SDRAM_CASn,--[out]
        C   => Clk,     --[in]
        D   => CASn,    --[in]
        S   => Rst      --[in]
      );
    SDRAM_WEN_REG: FDS
      port map (
        Q   => SDRAM_WEn, --[out]
        C   => Clk,     --[in]
        D   => WEn,     --[in]
        S   => Rst      --[in]
      );
end generate POSEDGE_OUTREGS_GEN;

-------------------------------------------------------------------------------
-- IOB input SDRAM registers - always positive edge
-------------------------------------------------------------------------------
INPUT_SDRAM_REGS_GEN: for i in 0 to C_SDRAM_DWIDTH -1 generate
    attribute iob   : string;
    attribute iob of RDDATA_REG : label is "true";
    begin
    RDDATA_REG: FDRE
      port map (
        Q   => SDRAM_ReadData(i), --[out]
        C   => Clk,               --[in]
        CE  => '1',               --[in]
        D   => SDRAM_DQ_i(i),     --[in]
        R   => Rst                --[in]
      );

end generate INPUT_SDRAM_REGS_GEN;


end imp;