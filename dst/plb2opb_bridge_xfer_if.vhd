-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_xfer_if.vhd,v 1.2 2005/09/15 17:22:50 mlovejoy Exp $
-------------------------------------------------------------------------------
--  PLB to OPB Bridge Out, Transfer Interface - Module
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
--  Filename:     plb2opb_bridge_xfer_if.vhd
--  Version:      v1.01a
--  Description:
--    This module is the control and write data interface between the PLB
--    OPB interfaces.
--
--  VHDL-Standard:   VHDL'93
--
--  Design Notes:
--    This module facilitates the ability to use asynchronous clock domains
--    between PLB and OPB Busses. The OPB clock must always be slower or equal
--    to the PLB clock.
--
--    The parameter C_CLK_ASYNC adjusts the synchronization logic
--    to select between synchronous or asynchronous OPB/PLB clocks:
--
--      - C_CLK_ASYNC = 0 means the PLB and OPB clocks must be the same
--      clock signal or the OPB clock must be divided down from the PLB clock
--      by an integer multiple. The rising edges of the OPB clock must aligned
--      with the rising edge of the PLB clock.
--
--      - C_CLK_ASYNC = 1 means there does not have to be any timing
--      relationship between OPB and PLB clock except that the OPB clock
--      is slower or equal in frequency to the PLB clock. Note that setting
--      this flag also increases the latency of data transfers.
--
--    The parameter C_HIGH_SPEED sets whether to use BRAMs or LUT RAMs for the
--    FIFO:
--
--      - C_HIGH_SPEED = 0 means that BRAMs are used. BRAMs support lower OPB
--      clock frquencies but use less SLICE resources
--      - C_HIGH_SPEED = 1 means that Dual Port LUT ram + FFs are used
--      instead. This allows OPB to run at higher frequencies but uses an
--      extra 72 DP RAMs + 72 FFs.
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
--      KD          5/21/01     -- EA 2 Release
--      ALS         11/06/01    -- VHDL conversion
--      ALS         03/25/02    
-- ^^^^^^
--  Code cleanup - C_CLK_ASYNC is hardcoded to 1 and will not be user 
--  modifiable, therefore, removed the bypass of synchronization registers. 
--  C_HIGH_SPEED is hardcoded to 1 and will not be user modifiable, but the
--  code to use block ram instead of DPRAM has been left in in case the resource
--  utilization becomes an issue. 
-- ~~~~~~
--      ALS     07/09/02            -- Version 1.00b
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
use ieee.std_logic_UNSIGNED.all;


library proc_common_v1_00_b;
use proc_common_v1_00_b.family.all;
use proc_common_v1_00_b.proc_common_pkg.all;

library unisim;
use unisim.vcomponents.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_xfer_if is
  generic ( C_CLK_ASYNC         : integer := 1;
            C_HIGH_SPEED        : integer := 1;
            C_FAMILY            : string  := "virtex2p";
            C_XFER_RNW          : integer;
            C_XFER_DATA_WIDTH   : integer   := 72);
  port (
        Rst                 : in std_logic;
        PLB_Clk             : in std_logic;
        PLB_hold_buslock    : in std_logic;
        PLB_xfer_abort_flag : in std_logic;
        PLB_xfer_data       : in std_logic_vector (0 to C_XFER_DATA_WIDTH-1);
        PLB_xfer_start_flag : in std_logic;
        PLB_xfer_strobe     : in std_logic;
        PLB_xfer_abort_ack  : out std_logic;
        PLB_xfer_start_ack  : out std_logic;
        OPB_Clk             : in std_logic;
        OPB_xfer_abort_ack  : in std_logic;
        OPB_xfer_rd_addr    : in std_logic_vector (0 to 3);
        OPB_xfer_rd_data_rst1 : in std_logic;
        OPB_xfer_rd_data_rst2 : in std_logic;
        OPB_xfer_rd_data_rst3 : in std_logic;
        OPB_xfer_rd_en      : in std_logic;
        OPB_xfer_start_ack  : in std_logic;
        dout_XFER_RNW       : out std_logic;
        OPB_hold_buslock    : out std_logic;
        OPB_xfer_abort_flag : out std_logic;
        OPB_xfer_rd_data    : out std_logic_vector (0 to C_XFER_DATA_WIDTH-1);
        OPB_xfer_start_flag : out std_logic
        );
end plb2opb_bridge_xfer_if;
 
-------------------------------------------------------------------------------
--  Architecture section
------------------------------------------------------------------------------- 
architecture plb2opb_bridge_xfer_if of plb2opb_bridge_xfer_if is

-------------------------------------------------------------------------------
--  Constant Declarations
-------------------------------------------------------------------------------
constant ZERO_4     : std_logic_vector(0 to 3)  :=  "0000";
constant ZERO_16    : std_logic_vector(0 to 15) :=  x"0000";
constant ZERO_32    : std_logic_vector(0 to 31) :=  x"00000000";

-------------------------------------------------------------------------------
--  Signal Declarations
-------------------------------------------------------------------------------
signal bram_rd_addr             : std_logic_vector(0 to 8);
signal bram_rd_data             : std_logic_vector(0 to C_XFER_DATA_WIDTH-1);
signal bram_wr_addr             : std_logic_vector(0 to 8);
signal din                      : std_logic_vector(0 to C_XFER_DATA_WIDTH-1);
signal dout                     : std_logic_vector(0 to C_XFER_DATA_WIDTH-1);
signal ff_rst                   : std_logic;
signal OPB_xfer_abort_ack_d1    : std_logic;
signal OPB_xfer_abort_ack_d2    : std_logic;
signal OPB_xfer_abort_ack_d3    : std_logic;
signal OPB_xfer_start_ack_d1    : std_logic;
signal OPB_xfer_start_ack_d2    : std_logic;
signal OPB_xfer_start_ack_d3    : std_logic;
signal PLB_hold_buslock_d1      : std_logic;
signal PLB_hold_buslock_d2      : std_logic;
signal PLB_hold_buslock_d3      : std_logic;
signal PLB_xfer_abort_flag_d1   : std_logic;
signal PLB_xfer_abort_flag_d2   : std_logic;
signal PLB_xfer_abort_flag_d3   : std_logic;
signal PLB_xfer_start_flag_d1   : std_logic;
signal PLB_xfer_start_flag_d2   : std_logic;
signal PLB_xfer_start_flag_d3   : std_logic;
signal radr                     : std_logic_vector(0 to 3 );
signal rdata                    : std_logic_vector(0 to C_XFER_DATA_WIDTH -1 );
signal ren                      : std_logic;
signal wadr                     : std_logic_vector(0 to 3 );
signal wen                      : std_logic;
signal wr_addr                  : std_logic_vector(0 to 3 );
signal wr_addr_rst              : std_logic;
signal wr_addr_rst_d1           : std_logic;

-------------------------------------------------------------------------------
--  Component Declarations
-------------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
--  Pass Flags From PLB Clock Domain to OPB Clock Domain
-------------------------------------------------------------------------------

--  Pipeline PLB signals by 1 PLB_Clk to remove glitches from the signal
PLB_SIG_REGS: process (PLB_Clk)
begin
  if (PLB_Clk'event and PLB_Clk = '1' ) then
    PLB_xfer_abort_flag_d1 <= PLB_xfer_abort_flag;
    PLB_xfer_start_flag_d1 <= PLB_xfer_start_flag;
    PLB_hold_buslock_d1 <= PLB_hold_buslock;
  end if;
end process ;

--  Pipeline PLB signals by 1 OPB_Clk to remove glitches from the signal,
--  resync the signal to the new clock domain, and help remove metastability
PLB_SIG_OPB_FE_PIPE: process (OPB_Clk)
begin
    if (OPB_Clk'event and OPB_Clk = '0' ) then
        PLB_xfer_abort_flag_d2 <= PLB_xfer_abort_flag_d1;
        PLB_xfer_start_flag_d2 <= PLB_xfer_start_flag_d1;
        PLB_hold_buslock_d2 <= PLB_hold_buslock_d1;
    end if;
end process PLB_SIG_OPB_FE_PIPE;

PLB_SIG_OPB_RE_PIPE:process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    PLB_xfer_abort_flag_d3 <= PLB_xfer_abort_flag_d2;
    PLB_xfer_start_flag_d3 <= PLB_xfer_start_flag_d2;
    PLB_hold_buslock_d3 <= PLB_hold_buslock_d2;
  end if;
end process PLB_SIG_OPB_RE_PIPE;

OPB_xfer_abort_flag <= PLB_xfer_abort_flag_d3;
OPB_xfer_start_flag <= PLB_xfer_start_flag_d3;
OPB_hold_buslock    <= PLB_hold_buslock_d3;
    
-------------------------------------------------------------------------------
--  Pass Flags From OPB Clock Domain to PLB Clock Domain
-------------------------------------------------------------------------------

--  Pipeline OPB signals by 1 OPB_Clk to remove glitches from the signal
OPB_SIG_REGS:process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    OPB_xfer_abort_ack_d1 <= OPB_xfer_abort_ack;
    OPB_xfer_start_ack_d1 <= OPB_xfer_start_ack;
  end if;
end process OPB_SIG_REGS;

--  Pipeline OPB signals by 1 PLB_Clk to remove glitches from the signal,
--  resync the signal to the new clock domain, and help remove metastability
OPB_SIG_PLB_FE_PIPE: process (PLB_Clk)
begin
  if (PLB_Clk'event and PLB_Clk = '0' ) then
    OPB_xfer_abort_ack_d2 <= OPB_xfer_abort_ack_d1;
    OPB_xfer_start_ack_d2 <= OPB_xfer_start_ack_d1;
  end if;
end process OPB_SIG_PLB_FE_PIPE;

OPB_SIG_PLB_RE_PIPE: process (PLB_Clk)
begin
  if (PLB_Clk'event and PLB_Clk = '1' ) then
    OPB_xfer_abort_ack_d3 <= OPB_xfer_abort_ack_d2;
    OPB_xfer_start_ack_d3 <= OPB_xfer_start_ack_d2;
  end if;
end process OPB_SIG_PLB_RE_PIPE;

PLB_xfer_abort_ack <= OPB_xfer_abort_ack_d3;
PLB_xfer_start_ack <= OPB_xfer_start_ack_d3;
    

-------------------------------------------------------------------------------
--  Generate Write Address for Memory to Load in PLB Data
-------------------------------------------------------------------------------
WRADDR_RST_REG: process (PLB_Clk)
begin
  if (PLB_Clk'event and PLB_Clk = '1' ) then
    wr_addr_rst <= PLB_xfer_data(C_XFER_DATA_WIDTH-1) and PLB_xfer_strobe;  --  last data rcv'd
    wr_addr_rst_d1 <= wr_addr_rst;
  end if;
end process WRADDR_RST_REG;

WRADDR_CNTR: process (PLB_Clk)
begin
  if (PLB_Clk'event and PLB_Clk = '1' ) then
    if Rst=RESET_ACTIVE or PLB_xfer_abort_flag='1'or wr_addr_rst_d1='1' then
        --  Counter is cleared with abort flag or 
        --if last PLB Data word is written
        wr_addr <= "0000";
    elsif (PLB_xfer_strobe) = '1'  then
        --  Counter is incremented for each new write of PLB Data
        wr_addr <= wr_addr+ 1;
    end if ;
  end if;
end process WRADDR_CNTR;

-------------------------------------------------------------------------------
--  When C_HIGH_SPEED=1:
--  Instantiate Dual Port RAMs as an alternative to BRAMs. Uses more SLICE
--  resources but has better timing and doesn't use BRAMs.
-------------------------------------------------------------------------------
DUALPORT_RAM_GEN: if C_HIGH_SPEED = 1 generate
begin
    ff_rst <= OPB_xfer_rd_data_rst1 or OPB_xfer_rd_data_rst2 or
                OPB_xfer_rd_data_rst3;
    din <= PLB_xfer_data;
    wen <= PLB_xfer_strobe;
    wadr <= wr_addr;
    radr <= OPB_xfer_rd_addr;
    ren <= OPB_xfer_rd_en;
    
    RAM_FF_LOOP_GEN: for i in 0 to C_XFER_DATA_WIDTH-1 generate
        DPRAM_I: RAM16X1D
          port map (
            DPO     => dout(i), --[out]
            SPO     => open,    --[out]
            A0      => wadr(3), --[in]
            A1      => wadr(2), --[in]
            A2      => wadr(1), --[in]
            A3      => wadr(0), --[in]
            D       => din(i),  --[in]
            DPRA0   => radr(3), --[in]
            DPRA1   => radr(2), --[in]
            DPRA2   => radr(1), --[in]
            DPRA3   => radr(0), --[in]
            WCLK    => PLB_Clk, --[in]
            WE      => wen      --[in]
          );
        
        RAM_FF_I: FDRE
          port map (
            Q       => rdata(i),--[out]
            C       => OPB_Clk, --[in]
            CE      => ren,     --[in]
            D       => dout(i), --[in]
            R       => ff_rst   --[in]
          );                
    end generate RAM_FF_LOOP_GEN;
    
    dout_XFER_RNW <= dout(C_XFER_RNW);
    OPB_xfer_rd_data <= rdata;

end generate DUALPORT_RAM_GEN;

-------------------------------------------------------------------------------
--  When C_HIGH_SPEED=0:
--  Instantiate BRAMs which will buffer up OPB data and act as the
--  interface medium bewteen PLB and OPB logic
-------------------------------------------------------------------------------
BRAM_GEN: if C_HIGH_SPEED = 0 generate
begin
    bram_rd_addr <= "00"& OPB_xfer_rd_data_rst1
                    & OPB_xfer_rd_data_rst2& OPB_xfer_rd_data_rst3
                    & OPB_xfer_rd_addr(0 to 3);
    bram_wr_addr <= "00000"& wr_addr;
    
    -- instantiate different number of BRAMs depending on family type
    VIRTEX_BRAMS: if equalIgnoreCase(C_FAMILY,"virtex") generate
        GEN5_BRAMS: for i in 0 to 4 generate -- XFERDATA_WIDTH mod 16 ??
            BLOCK_RAM4_I: RAMB4_S16_S16
              port map (
                 --  A Port for PLB Writes
                 ADDRA  => bram_wr_addr(1 to 8),            --[in]
                 CLKA   => PLB_Clk,                         --[in]
                 DIA    => PLB_Xfer_data(i*16 to i*16 + 15), --[in]
                 DOA    => open,                            --[out]
                 ENA    => PLB_xfer_strobe,                 --[in]
                 RSTA   => '0',                             --[in]
                 WEA    => PLB_xfer_strobe,                 --[in]
                 --  B Port for OPB Reads
                 ADDRB  => bram_rd_addr(1 to 8),            --[in]
                 CLKB   => OPB_Clk,                         --[in]
                 DIB    => ZERO_16,                         --[in]
                 DOB    => bram_rd_data(i*16 to i*16 + 15), --[out]
                 ENB    => OPB_xfer_rd_en,                  --[in]
                 RSTB    =>'0',                             --[in]
                 WEB    => '0'                              --[in]
              );
        end generate GEN5_BRAMS;
    end generate VIRTEX_BRAMS;
    
    VIRTEXII_BRAMS: if equalIgnoreCase(C_FAMILY,"virtex2") or 
                       equalIgnoreCase(C_FAMILY,"virtex2p")generate
        GEN2_BRAMS: for i in 0 to 1 generate    -- XFERDATA_WIDTH mod 36??
            BLOCK_RAM16_I: RAMB16_S36_S36
                port map (
                  -- A port for PLB Writes
                  ADDRA => bram_wr_addr,                    --[in]
                  CLKA  => PLB_Clk,                         --[in]
                  DIA   => PLB_xfer_data(i*36 to i*36+31),  --[in]
                  DIPA  => PLB_xfer_data(i*36+32 to i*36+32+3), --[in]
                  DOA   => open,                            --[out]
                  DOPA  => open,                            --[out]
                  ENA   => PLB_xfer_strobe,                 --[in]
                  SSRA  => '0',                             --[in]
                  WEA   => PLB_xfer_strobe,                 --[in]
                  -- B port for OPB Reads
                  ADDRB => bram_rd_addr,                    --[in]
                  CLKB  => OPB_Clk,                         --[in]
                  DIB   => ZERO_32,                         --[in]
                  DIPB  => ZERO_4,                          --[in]
                  DOB   => bram_rd_data(i*36 to i*36+31),   --[out]
                  DOPB  => bram_rd_data(i*36+32 to i*36+32+3), --[out]
                  ENB   => OPB_xfer_rd_en,                  --[in]
                  SSRB  => '0',                             --[in]
                  WEB   => '0'                              --[in]
                );
        end generate GEN2_BRAMS;
    end generate VIRTEXII_BRAMS;
    
    OPB_xfer_rd_data <= bram_rd_data;
    
end generate BRAM_GEN;

end ;

