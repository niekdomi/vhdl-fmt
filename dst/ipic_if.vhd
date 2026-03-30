-------------------------------------------------------------------------------
-- $Id: ipic_if.vhd,v 1.2 2005/06/03 14:27:35 gburch Exp $
-------------------------------------------------------------------------------
-- ipic_if.vhd - entity/architecture pair
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
-- Filename:        ipic_if.vhd
-- Version:         v1.00e
-- Description:     This file interfaces to the IPIC and sets signals for the
--                  command state machine. 
--                  NOTE: this is an early version of this file which will work
--                  with the current IPIF. Once the IPIF supports address
--                  pipelining, this file will need to be modified to obtain
--                  better performance.
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
--   ALS           05/14/02    First Version
--
--   ALS           06/4/02
-- ^^^^^^
--  Fixed address bus assignments based on SDRAM data widths
-- ~~~~~~
--  ALS            06/06/02
-- ^^^^^^
--  Added reset of pendrdreq and pendwrreq when CS negates. Qualified read_op
--  and write_op with RNW.
-- ~~~~~~
--  ALS            06/15/02
-- ^^^^^^
--  Minor cleanups
-- ~~~~~~
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--   ALS            04/01/03
-- ^^^^^^
--  Modified ToutSup to assert whenever Bus2IP_CS asserts.
-- ~~~~~~
--  ALS             10/06/03    Version D            
-- ^^^^^^
-- Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
-- for new PLB IPIF.
-- ~~~~~~
--  GAB             11/26/03
-- ^^^^^^
--  Modified same_row, same_bank logic to hold state until acknowledged by the
--  command state machine with a pend_read or pend_write.
--  Qualified bus2ip_rdack with bus2ip_cs to prevent read ack's from occuring
--  after bus2ip_cs negates like can occur during indeterminate bursts.
-- ~~~~~~
--  GAB             10/06/04    Version E
-- ^^^^^^
--  Qualified IP2Bus_Retry with WrAck and RdAck to prevent driving both to 
--  IPIF at the same time.
--
--  Modified same_row/same_bank registers to register info with 
--  Same_rowbank_regce which is driven from the ACT_CMD state in
--  command_statemachine.  Fixes late registering or same row/bank flags.
--
--  Updated to use proc_common_v2_00_a library
-- ~~~~~~
--  GAB             06/02/05
-- ^^^^^^
-- Modified IP2Bus_Busy to drive busy regardless of Bus2IP_CS.  First cycles
-- plb_ipif with write_buffer was sln_addrack 'ing an initial cycle
-- prior to SDRAM initialization when the ipif should have rearbitrated
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

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_SDRAM_AWIDTH      -- SDRAM address width 
--      C_SDRAM_DWIDTH      -- SDRAM data width
--      C_SDRAM_COL_AWIDTH  -- SDRAM column aSDRAMess width
--      C_SDRAM_BANK_AWIDTH -- SDRAM bank aSDRAMess width
--      C_INCLUDE_BURSTS    -- support bus burst transactions
--      C_IPIF_DWIDTH       -- IPIF data width
--      C_IPIF_AWIDTH       -- IPIF address width
--
-- Definition of Ports:
--      Bus2IP_CS           -- indicates SDRAM SDRAM controller has been selected
--      Bus2IP_RNW          -- read/write
--      Bus2IP_Addr         -- address
--      Bus2IP_Burst        -- burst
--      Bus2IP_Data         -- data from processor bus
--      Bus2IP_BE           -- byte enables
--      Bus2IP_RdReq        -- read req
--      Bus2IP_WrReq        -- write req
--      Bus2IP_ErrAck       -- error acknowledge
--      Bus2IP_Retry        -- retry
--      IP2Bus_WrAck        -- write acknowledge
--      IP2Bus_RdAck        -- read acknowledge
--      IP2Bus_ToutSup      -- suppress timeout counter
--      IP2Bus_data         -- read data from SDRAM
--      WrAck               -- write acknowledge
--      RdAck               -- read acknowledge
--      Rd_AddrAck          -- burst read acknowledge (used for determinate timer)
--      Brst_wrAck          -- burst write acknowledge
--      Err_ack             -- error acknowledge
--      Toutsup             -- suppress timeout counter
--      Read_data           -- data read from SDRAM
--      Retry               -- retry transaction
--      Init_done           -- initialization is complete
--      Read_op             -- read operation
--      Write_op            -- write operation
--      IPIC_wrdata         -- data to be written to SDRAM
--      IPIC_be             -- byte enables from bus
--      Burst               -- bus burst transaction
--      Reset_pendrdreq     -- reset pending read request
--      Reset_pendwrreq     -- reset pending write request
--      SDRAM_idle          -- SDRAM is idle
--      Row_addr            -- row address
--      Col_addr            -- column address
--      Bank_addr           -- bank address
--      Pend_write          -- start transmitting write data
--      Pend_read           -- start receiving read data
--      Pend_rdreq          -- pending read request
--      Pend_wrreq          -- pending write request
--      Same_row            -- pending transaction is for the same row
--      Same_bank           -- pending transaction is for the same bank
--
--    -- Clocks and reset
--      Clk                 
--      Rst               
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity ipic_if is
  generic ( C_SDRAM_AWIDTH      : integer;
            C_SDRAM_DWIDTH      : integer;
            C_SDRAM_COL_AWIDTH  : integer;
            C_SDRAM_BANK_AWIDTH : integer;
            C_INCLUDE_BURSTS    : integer;
            C_IPIF_AWIDTH       : integer;
            C_IPIF_DWIDTH       : integer );
  port (
        Bus2IP_CS               : in  std_logic;
        Bus2IP_RNW              : in  std_logic;
        Bus2IP_Addr             : in  std_logic_vector(0 to C_IPIF_AWIDTH-1);
        Bus2IP_Burst            : in  std_logic;
        Bus2IP_Data             : in  std_logic_vector(0 to C_IPIF_DWIDTH-1);
        Bus2IP_BE               : in  std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
        Bus2IP_RdReq            : in  std_logic;
        Bus2IP_WrReq            : in  std_logic;
        IP2Bus_ErrAck           : out std_logic;
        IP2Bus_Retry            : out std_logic;
        IP2Bus_Busy             : out std_logic;
        IP2Bus_AddrAck          : out std_logic;
        IP2Bus_WrAck            : out std_logic;
        IP2Bus_RdAck            : out std_logic;
        IP2Bus_ToutSup          : out std_logic;
        IP2Bus_data             : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
        WrAck                   : in  std_logic;
        RdAck                   : in  std_logic;
        Rd_AddrAck              : in  std_logic;
        Wr_AddrAck              : in  std_logic;
        ErrAck                  : in  std_logic;
        Toutsup                 : in  std_logic;
        Read_data               : in  std_logic_vector(0 to C_IPIF_DWIDTH-1);
        Retry                   : in  std_logic;
        Init_done               : in  std_logic;
        Read_op                 : out std_logic;
        Write_op                : out std_logic;
        IPIC_wrdata             : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
        IPIC_be                 : out std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
        Burst                   : out std_logic;
        Reset_pendrdreq         : in  std_logic;
        Reset_pendwrreq         : in  std_logic;      
        SDRAM_idle              : in  std_logic;
        Row_addr                : out std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        Col_addr                : out std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        Bank_addr               : out std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        Pend_rdreq              : out std_logic;
        Pend_wrreq              : out std_logic;
        Pend_write              : in  std_logic;
        Pend_read               : in  std_logic;
        Same_row                : out std_logic;
        Same_bank               : out std_logic;
        Same_rowbank_regce      : in  std_logic;
        Clk                     : in  std_logic;
        Rst                     : in  std_logic
      );
end entity ipic_if;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of ipic_if is

-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------

constant SDRAM_ADDR_OFFSET  : integer := log2(C_SDRAM_DWIDTH/8);
constant IPIF_ADDR_OFFSET   : integer := log2(C_IPIF_DWIDTH/8);
-- starting column address bit must be offset by the SDRAM address offset
-- ending column address bit must be offset by the IPIF address offset
-- difference between the two address offsets are zero'd
constant COLADDR_STARTBIT   : integer := C_IPIF_AWIDTH - (C_SDRAM_COL_AWIDTH+SDRAM_ADDR_OFFSET);
constant COLADDR_ENDBIT     : integer := C_IPIF_AWIDTH-IPIF_ADDR_OFFSET-1; 
constant NUM_ZEROADDR_BITS  : integer := IPIF_ADDR_OFFSET-SDRAM_ADDR_OFFSET;
constant ZEROADDR_BITS      : std_logic_vector(0 to NUM_ZEROADDR_BITS-1) := (others => '0');                                

constant ROWADDR_STARTBIT   : integer := COLADDR_STARTBIT - C_SDRAM_AWIDTH;
constant ROWADDR_ENDBIT     : integer := ROWADDR_STARTBIT + C_SDRAM_AWIDTH-1;
constant BANKADDR_STARTBIT  : integer := ROWADDR_STARTBIT - C_SDRAM_BANK_AWIDTH;
constant BANKADDR_ENDBIT    : integer := BANKADDR_STARTBIT + C_SDRAM_BANK_AWIDTH-1;

constant ZERO_COL_PAD       : std_logic_vector(0 to C_SDRAM_AWIDTH-C_SDRAM_COL_AWIDTH-1)
                                := (others => '0');
-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
-- internal versions of output signals
signal row_addr_i           : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal bank_addr_i          : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
signal same_row_i           : std_logic;
signal same_bank_i          : std_logic;
signal same_row_reg         : std_logic;
signal same_bank_reg        : std_logic;
signal ip2bus_retry_i       : std_logic;
signal pend_wrreq_i         : std_logic;
signal pend_rdreq_i         : std_logic;

-- Same_row and Same_bank signals
signal last_row_lsb         : std_logic;
signal last_bank_lsb        : std_logic;

-- Xfer qualifiers  rising edge detect signals
signal cs_d1, cs_re         : std_logic;
signal wrreq_d1, wrreq_re   : std_logic;
signal rdreq_d1, rdreq_re   : std_logic;

-----------------------------------------------------------------------------
-- Component declarations
-----------------------------------------------------------------------------

 
-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  -- architecture imp
-- assign output signals
Row_addr <= row_addr_i;
Bank_addr <= bank_addr_i;
IP2Bus_Retry <= ip2bus_retry_i and not(RdAck or WrAck);
Pend_rdreq <= pend_rdreq_i;
Pend_wrreq <= pend_wrreq_i;


-- determine read/write operations
Read_op <= Bus2IP_RdReq; 
Write_op <= Bus2IP_WrReq; 

-- determine bank, row, and column addresses
bank_addr_i <= Bus2IP_Addr(BANKADDR_STARTBIT to BANKADDR_ENDBIT);
row_addr_i  <= Bus2IP_Addr(ROWADDR_STARTBIT to ROWADDR_ENDBIT);
-- have to test address constants to determine column address
EQUAL_OFFSETS_GEN: if SDRAM_ADDR_OFFSET = IPIF_ADDR_OFFSET generate
    Col_addr    <= ZERO_COL_PAD & Bus2IP_Addr(COLADDR_STARTBIT to COLADDR_ENDBIT);
end generate EQUAL_OFFSETS_GEN;

NOTEQUAL_OFFSETS_GEN: if SDRAM_ADDR_OFFSET /= IPIF_ADDR_OFFSET generate
    Col_addr    <= ZERO_COL_PAD & Bus2IP_Addr(COLADDR_STARTBIT to COLADDR_ENDBIT) & ZEROADDR_BITS;
end generate NOTEQUAL_OFFSETS_GEN;    

--burst simply passes to core 
BURSTSIG_GEN: if C_INCLUDE_BURSTS=1 generate
    Burst <= Bus2IP_Burst;
end generate BURSTSIG_GEN;
NOBURSTSIG_GEN: if C_INCLUDE_BURSTS=0 generate
    Burst <= '0';
end generate NOBURSTSIG_GEN;

-- when an ACK is received, register the bank address LSB and row address LSB
-- then compare to current bank address LSB and row address LSB to see if in
-- same row and same bank
-- when go to new IPIF, will need a full comparator (could use pselect)
LAST_BNKRW_PROCESS: process(Clk)
begin
    if Clk'event and Clk = '1' then
        if Rst = RESET_ACTIVE then
            last_row_lsb <= '0';
            last_bank_lsb <= '0';
        else
            last_row_lsb <= row_addr_i(C_SDRAM_AWIDTH-1);
            last_bank_lsb <= bank_addr_i(C_SDRAM_BANK_AWIDTH-1);
        end if;
    end if;
end process LAST_BNKRW_PROCESS;

same_row_i <= '1' when last_row_lsb = row_addr_i(C_SDRAM_AWIDTH-1)
            else '0';
same_bank_i <= '1' when last_bank_lsb = bank_addr_i(C_SDRAM_BANK_AWIDTH-1)
            else '0';

reg_same_row : process(Clk)
begin
    if(Clk'EVENT and Clk = '1')then
        if(Rst = RESET_ACTIVE)then
            same_row_reg    <= '1';
        elsif(same_row_i = '0')then            
            same_row_reg    <= '0';
--        elsif(pend_read = '1' or pend_write = '1')then           
        elsif(Same_rowbank_regce = '1')then
            same_row_reg    <= '1';
        end if;
    end if;
end process reg_same_row;

reg_same_bank : process(Clk)
begin
    if(Clk'EVENT and Clk = '1')then
        if(Rst = RESET_ACTIVE)then
            same_bank_reg    <= '1';
        elsif(same_bank_i = '0')then            
            same_bank_reg    <= '0';
--        elsif(pend_read = '1' or pend_write = '1')then           
        elsif(Same_rowbank_regce = '1')then
            same_bank_reg    <= '1';
        end if;
    end if;
end process reg_same_bank;

Same_row <= same_row_i and same_row_reg;
Same_bank <= same_bank_i and same_bank_reg;

XFERSIGS_RE_PROCESS: process(Clk)
begin
    if Clk'event and Clk='1' then
        if Rst=RESET_ACTIVE then
            cs_d1       <= '0';
            wrreq_d1    <= '0';
            rdreq_d1    <= '0';
        else
            cs_d1       <= Bus2IP_CS;
            wrreq_d1    <= Bus2IP_WrReq;
            rdreq_d1    <= Bus2IP_RdReq;
        end if;
    end if;
end process XFERSIGS_RE_PROCESS; 

cs_re <= Bus2IP_CS and not(cs_d1);
wrreq_re <= Bus2IP_WrReq and not(wrreq_d1);
rdreq_re <= Bus2IP_RdReq and not(rdreq_d1);

-------------------------------------------------------------------------------
-- AddrAck, RdAck, WrAck, Data, and BE signals
-------------------------------------------------------------------------------
IP2Bus_AddrAck  <= Rd_AddrAck or Wr_AddrAck after 1 ns;
IP2Bus_RdAck    <= RdAck and Bus2IP_CS;
IP2Bus_data     <= Read_data;
IP2Bus_WrAck    <= WrAck and Bus2IP_CS;
IPIC_wrdata     <= Bus2IP_data;
IPIC_be         <= Bus2IP_BE;    

-- ErrAck is set to gnd
IP2Bus_ErrAck <= '0';

-- 
TOUTSUP_PROCESS: process(Clk)
begin
    if Clk'event and Clk = '1' then
        if Rst = RESET_ACTIVE  then
            IP2Bus_ToutSup <= '0';
        else
            IP2Bus_ToutSup <= ToutSup;
        end if;
    end if;
end process TOUTSUP_PROCESS;

--
RETRY_PROCESS: process(Clk)
begin
    if Clk'event and Clk = '1' then
        if Rst = RESET_ACTIVE  or Bus2IP_CS = '0' then
            ip2bus_retry_i <= '0';
        elsif Bus2IP_CS = '1' then
            ip2bus_retry_i <= Retry or not(Init_done);
        end if;
    end if;
end process RETRY_PROCESS;

-- Modified to drive busy regardless of Bus2IP_CS.  First cycles
-- plb_ipif with write_buffer was sln_addrack 'ing an initial cycle
-- prior to SDRAM initialization when the ipif should have rearbitrated
BUSY_PROCESS: process(Clk)
begin
    if Clk'event and Clk = '1' then
        IP2Bus_Busy <= Retry or not(Init_done);
    end if;
end process BUSY_PROCESS;


-- determine pending read and write requests
PEND_REQ_PROCESS: process(Clk)
begin
    if Clk'event and Clk='1' then
        if Rst = RESET_ACTIVE then
           pend_rdreq_i <= '0';
           pend_wrreq_i <= '0';
        else
           if Reset_pendrdreq = RESET_ACTIVE or Bus2IP_CS = '0' then
               pend_rdreq_i <= '0';
           elsif rdreq_re = '1'  then
               pend_rdreq_i <= '1';
           end if;
           if Reset_pendwrreq = RESET_ACTIVE or Bus2IP_CS = '0' then
               pend_wrreq_i <= '0';
           elsif wrreq_re = '1' then
               pend_wrreq_i <= '1';
           end if;
        end if;
    end if;
end process PEND_REQ_PROCESS;


end imp;

