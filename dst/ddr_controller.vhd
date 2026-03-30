-------------------------------------------------------------------------------
-- $Id: ddr_controller.vhd,v 1.5 2006/09/15 10:01:20 kravi Exp $
-------------------------------------------------------------------------------
-- ddr_controller.vhd - entity/architecture pair
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
-- Filename:        ddr_controller.vhd
-- Version:         v1.12.a
-- Description:     DDR controller with IPIC interface
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
-------------------------------------------------------------------------------
-- Author:          ALS
-- History:
--   ALS           05/02/02    First Version
-- ^^^^^^
--      First version of DDR controller
-- ~~~~~~
--   ALS            06/05/02
-- ^^^^^^
--      Replaced C_CLK_FREQ with C_CLK_PERIOD
-- ~~~~~~
--  ALS             06/07/02
-- ^^^^^^
--      Made modifications for FIFO implementation of read data path. Added
--      C_FAMILY generic.
-- ~~~~~~
--  ALS             07/12/02
-- ^^^^^^

--      Added C_REG_DIMM generic. When C_REG_DIMM=1, add a 1-clock pipeline
--      delay to write_data, write_data_mask, write_data_en, write_dqs_en.
--      Also, add 1 to the CAS_LATENCY to account for the register delay in
--      the DIMM. Changed generic C_INCLUDE_CLK90_GEN to C_INCLUDE_CLK90_DCM
--      and added generic C_INCLUDE_DDRCLK_DCM so that the inclusion of the
--      DDR clock DCM and the output registers to generate the DDR clock output
-- ~~~~~~
--  ALS             06/25/03
-- ^^^^^^
--      Version C:
--      Use latest IPIFs to remove latency and support indeterminate bursts
--      Add INIT_DONE as output pin
--      Provide C_SIM_INIT_TIME parameter to allow simulation to run faster
--      Remove XST workarounds
--      Assert TOUTSUP during transfers
-- ~~~~~~
--  JLJ             11/11/03
-- ^^^^^^
--      Version D:
--      Add support for ECC capability.  Add ports and register logic for ECC
--      check bits.  Include C_INCLUDE_ECC_SUPPORT parameter and NUM_ECC_BITS
--      constant on generic mapping. Seperate IP2Bus_AddrAck into 
--      IP2Bus_RdAddrAck and IP2Bus_WrAddrAck.
-- ~~~~~~
--  JLJ             02/13/04
-- ^^^^^^
--      Add Bus2IP_CS as port on data_statemachine module.
-- ~~~~~~
--  JLJ             02/16/04
-- ^^^^^^
--      Removed C_PULLUPS generic.  If this parameter was set to 1, the DDR DQS
--      lines had pullups.  If this parameter was set to 0, then pulldowns were
--      assumed.  The new default setting will assume pullups.
--      Added bursting optimizations.  C_INCLUDE_BURSTS parameter is now used in 
--      command_statemachine, data_statemachine, and ipic_if.  Removed
--      C_INCLUDE_BURSTS parameter on generic map for read_data_path module.
-- ~~~~~~
--  JLJ             02/18/04
-- ^^^^^^
--      Add Sys_Clk_n, Clk90_in_n, and DDR_Clk90_in_n signals on port mapping
--      for DDR core. This update of the core requires global inversion on
--      clock inputs to prevent any duty cycle distortion as system frequencies
--      increase.
-- ~~~~~~
--  JLJ             02/20/04
-- ^^^^^^
--      Add support for multiple memory banks with new parameter,
--      C_NUM_BANKS_MEM. Supported number of memory banks is 1 to 4.  Create
--      logic for DDR_CSn in command_statemachine, but register output logic in
--      IOB (in io_registers module).
-- ~~~~~~
--  JLJ             02/25/04
-- ^^^^^^
--      Create multiple DDR clock pairs to support clocking requirements of
--      certain DDR SDRAM DIMM vendors. Added support for up to 3 differential
--      DDR clock pairs. Renamed DDR_Clk and DDR_Clkn to DDR_Clk0 and
--      DDR_Clk0n. Added ports DDR_Clk1, DDR_Clk1n, DDR_Clk2, DDR_Clk2n. Added
--      support for 2 output DDR clock enables. Renamed DDR_CKE to DDR_CKE0,
--      and added DDR_CKE1.
-- ~~~~~~
--  JLJ             03/18/04
-- ^^^^^^
--      Updated to version v1.11a.  Added support for Virtex4 (uses family.vhd
--      in proc_common_v2_00_a).  Also updated to proc_common_v2_00_a.
-- ~~~~~~
--  JLJ             04/06/04
-- ^^^^^^
--      Added parameter, C_NUM_CLK_PAIRS for the number of differential DDR
--      clock pairs needed in design.  Renamed DDR_Clk0, DDR_Clk0n, DDR_Clk1,
--      DDR_Clk1n, DDR_Clk2, & DDR_Clk2n to DDR_Clk (0:C_NUM_CLK_PAIRS-1) and 
--      DDR_Clkn (0:C_NUM_CLK_PAIRS-1).
--
--      Renamed DDR_CKE0 and DDR_CKE1 to DDR_CKE (0:C_NUM_BANKS_MEM-1).  Each
--      bank of DDR memory will have a dedicated CKE.
-- ~~~~~~
--  JLJ             04/08/04
-- ^^^^^^
--      Modified data_statemachine module Bus2IP_Burst port mapping. New
--      assignment is burst signal from ipic_if module.
-- ~~~~~~
--  NITIN           05/07/04
-- ^^^^^^
--      Updated to version v1.11a. Added support for 64-bit data interface
--      (added instances for dw_64_wr and dw_64_rd).
-- ^^^^^^
--  NITIN          05/13/04
-- ^^^^^^
--      Added instantiation for illegal combination of generics 
--      C_DDR_DWIDTH=64 and C_ECC_SUPPORT=1.(Updated for review comments)
-- ~~~~~~
--  NITIN          05/14/04
-- ^^^^^^
--      Removed assignment for signals DDR_Clk, DDR_Clkn, DDR_CKE and
--      DDR_Init_done from instantiation ILLEGAL_ECC_64_GEN for illegal
--      combination of generics C_DDR_DWIDTH=64 and C_ECC_SUPPORT=1.
--      This is to avoid the multiple driver for these signals. As these
--      signals are assigned in clock_gen and init_statemachine. 
-- ~~~~~~
--  JLJ             08/09/04
-- ^^^^^^
--      Remove component declaration for Virtex-4 primitives, IDDR & ODDR, in
--      io_registers and clock_gen modules.
-- ~~~~~~
--  ALS             09/29/04
-- ^^^^^^
--  Modified the support for 64-bit - now all 128-bits of DDR data is captured
--  in the Read Data FIFO and the muxing of the low and high double words based
--  off Bus2IP_Addr(28) now occurs after the Read Data FIFO. This reduces the 
--  amount of logic on the DDR clock as well as the number of signals required
--  to cross clock domains. Also, generated new signal, Addr28_fifo_wren, to 
--  write Bus2IP_Addr(28) into the Addr28 FIFO so that the write will happen 
--  very early and there'll be plenty of time for the empty flag to negate
-- ~~~~~~
--  Nitin Kabra      10/11/04
-- ^^^^^^
--  Remvoed, new signal, Addr28_fifo_wren
-- ~~~~~~
--  Nitin Kabra      1/10/05
-- ^^^^^^
--  Change the lebel for generate condidions when C_DDR_DWIDTH/C_IPIF_DWIDTH=1,
--  C_DDR_DWIDTH/C_IPIF_DWIDTH=2 and C_IPIF_DWIDTH/C_DDR_DWIDTH=2.
--  Removed the seperate generate statements for OPB and PLB. This is combined
--  in one generate statement.
-- ~~~~~~
--  Nitin Kabra      1/10/05
-- ^^^^^^
--  Combined read_data_path_64 and read_data_path in one file read_data_path.
-- ~~~~~~
--  Nitin Kabra          03/15/05
-- ^^^^^^^
--  Added generic C_EXTRA_TSU which enables extra set up on DDR_CSn,DDR_RASn,
--  DDR_CASn,DDR_WEn,DDR_BankAddr,DDR_Addr.
-- ~~~~~~
--  Nitin Kabra            06/30/05
-- ^^^^^^
--  Added clk90 input to data_statemachine.  Add register stage for 
--  write_dqs_en & write_dqs_ecc_en signals in data_statemachine to cross
--  Clk to Clk90 boundary prior to IOB.
--  Added clk90 input to command_statemachine.  Add register stage for dqs_rst, 
--  dqs_setrst, dqs_oe, dqs_ecc_rst, dqs_ecc_setrst, and dqs_ecc_oe signals to 
--  cross Clk to Clk90 boundary prior to IOB.
-- ~~~~~~
--  Nitin Kabra          07/18/05
-- ^^^^^^^
--  Removed unused parameter C_DDR_TREFC to fix CR #206616. Also removed 
--  constant DDR_TREFC_CLKS (unused) as this is generated using C_DDR_TREFC
-- ~~~~~~~
-- ~~~~~~
--  Nitin Kabra             11/6/05     
-- ^^^^^^
--  Modified to fix the bugs in timing sinulation with ECC in read_data_path.vhd
--  1. Added parameter C_DDR_CAS_LAT & C_REG_DIMM
--  2. Added signals input port Rd_addrack.
-- ~~~~~~
--  Nitin Kabra             02/24/06     
-- ^^^^^^
--  1. Removed "IP2Bus_AddrAck" from definition of ports.
--  2. Added "IP2Bus_WrAddrAck" & "IP2Bus_RdAddrAck" in definition of ports.
--  3. Removed unused input port "Bus2IP_RNW" from enity section &
--     "definition of ports" in comment section.
--  4. Removed commented assignment (below) to constant "CASLATCNT"
--     conv_std_logic_vector(C_DDR_CAS_LAT+C_REG_DIMM-2, CASLATCNT_WIDTH);
--  5. Broke the line having more than 80 characters.
-- ~~~~~~
--  USM                   07/14/06
-- ^^^^^^
--  Added RD_DATAEN_PROCESS to register the read_data_en signal in 
--  data_statemachine.vhd.
-- ~~~~~~
--  Nitin Kabra          08/09/06
-- ^^^^^^^
--  Reverting back - added unused parameter C_DDR_TREFC to follow the 
--  versioning guidlines to fix CR #236217.
-- ~~~~~~~
--  Avinash              8/25/2006     v3.00.a
-- ^^^^^^
-- Upgraded library version to ddr_v3_00_a
-- Added generate condition C_IPIF_DWIDTH/C_DDR_DWIDTH=4
-- Added new port wr_up_lo_data_sel between data_statemachine 
-- and io_register module.
-- Removed parameter C_DDR_TREFC.
-- ~~~~~~
--  Avinash              8/25/2006     v3.00.a
-- ^^^^^^
-- Replaced read_data_path_mw module with read_data_path module 
-- when C_IPIF_DWIDTH/C_DDR_DWIDTH=1 generate condition
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
use proc_common_v2_00_a.all;

library ddr_v3_00_a;
use ddr_v3_00_a.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_EXTRA_TSU             -- Enables extra set up on DDR_CSn, DDR_RASn,
--                                 DDR_CASn, DDR_WEn, DDR_BankAddr, DDR_Addr.
--      C_FAMILY                -- target FPGA family
--      C_NUM_BANKS_MEM         -- supported number of memory banks
--      C_NUM_CLK_PAIRS         -- supported number of DDR clock pairs
--      C_REG_DIMM              -- support registered ddr dimm
--      C_DDR_TMRD              -- Load Mode Register command cycle time
--      C_DDR_TWR               -- write recovery time
--      C_DDR_TRAS              -- delay after ACTIVE command before
--                              -- PRECHARGE command
--      C_DDR_TRC               -- delay after ACTIVE command before
--                              -- another ACTIVE or AUTOREFRESH command
--      C_DDR_TRFC              -- delay after AUTOREFRESH before another
--                              -- command
--      C_DDR_TRCD              -- delay after ACTIVE before READ/WRITE
--      C_DDR_TRRD              -- delay after ACTIVE row a before ACTIVE 
--                              -- row b
--      C_DDR_TRP               -- delay after PRECHARGE command
--      C_DDR_TREFC             -- refresh to refresh command interval
--      C_DDR_TREFI             -- average periodic refresh command interval
--      C_DDR_CAS_LAT           -- Device CAS latency
--      C_DDR_DWIDTH            -- DDR data width of each device
--      C_DDR_AWIDTH            -- DDR row address width
--      C_DDR_COL_AWIDTH        -- DDR column address width
--      C_DDR_BANK_AWIDTH       -- DDR bank address width
--      C_DDR_BRST_SIZE         -- DDR burst size
--      C_IPIF_DWIDTH           -- IPIC data width
--      C_IPIF_AWIDTH           -- IPIC address width
--      C_INCLUDE_BURSTS        -- include support for bus burst transactions
--      C_CLK_PERIOD            -- processor bus clock period
--      C_OPB_BUS               -- processor bus is OPB
--      C_PLB_BUS               -- processor bus is PLB
--      C_SIM_INIT_TIME_PS      -- DDR initialization time to be used in
--                              -- simulation
--      C_INCLUDE_ECC_SUPPORT   -- Include ECC support
--      NUM_ECC_BITS            -- Number of ECC bits
--
-- Definition of Ports:
--    -- IPIC
--    Bus2IP_Addr       -- Processor bus address
--    Bus2IP_BE         -- Processor bus byte enables
--    Bus2IP_Data       -- Processor data
--    Bus2IP_RdReq      -- Processor read request
--    Bus2IP_WrReq      -- Processor write request
--    Bus2IP_Burst      -- Processor burst
--    Bus2IP_IBurst     -- Processor indeterminate burst
--    Bus2IP_CS         -- DDR memory is being accessed
--    ECC_chk_bits_wr   -- ECC check bits to write from ECC logic
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    ECC_chk_bits_rd   -- ECC check bits read from memory
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--
--    -- IPIC outputs
--    IP2Bus_Data       -- Data to processor bus
--    IP2Bus_WrAddrAck  -- Write address phase acknowledge (inc address count)
--    IP2Bus_RdAddrAck  -- Read address phase acknowledge (inc address count)
--    IP2Bus_Busy       -- IP busy (issue re-arbitrate during address
--                      --  phase)
--    IP2Bus_RdAck      -- Read acknowledge
--    IP2Bus_WrAck      -- Write acknowledge
--    IP2Bus_Retry      -- Retry indicator
--    IP2Bus_ToutSup    -- Suppress watch dog timer
--    
--    -- DDR interface signals
--    DDR_Clk           -- DDR clock output(s)
--    DDR_Clkn          -- DDR inverted clock output(s)
--    DDR_CKE           -- DDR clock enable(s)
--    DDR_CSn           -- DDR chip select(s)
--    DDR_RASn          -- DDR row address strobe
--    DDR_CASn          -- DDR column address strobe
--    DDR_WEn           -- DDR write enable
--    DDR_DM            -- DDR data mask
--    DDR_BankAddr      -- DDR bank address
--    DDR_Addr          -- DDR address
--    DDR_DQ_o          -- DDR DQ output
--    DDR_DQ_i          -- DDR DQ input
--    DDR_DQ_t          -- DDR DQ output enable
--    DDR_DQS_i         -- DDR DQS input
--    DDR_DQS_o         -- DDR DQS output
--    DDR_DQS_t         -- DDR DQS output enable
--    DDR_DM_ECC        -- DDR ECC data mask
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    DDR_DQ_ECC_o      -- DDR ECC DQ output
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    DDR_DQ_ECC_i      -- DDR ECC DQ input
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    DDR_DQ_ECC_t      -- DDR ECC DQ output enable
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    DDR_DQS_ECC_i     -- DDR ECC DQS input
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    DDR_DQS_ECC_o     -- DDR ECC DQS output
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--    DDR_DQS_ECC_t     -- DDR ECC DQS output enable
--                      -- (when C_INCLUDE_ECC_SUPPORT=1)
--
--    -- Clocks and reset
--    Sys_Clk           -- PLB clock 
--    Sys_Clk_n         -- PLB clock shifted by 180
--    Clk90_in          -- PLB clock shifted 90
--    Clk90_in_n        -- PLB clock shifted by 270
--    DDR_Clk90_in      -- DDR clock feedback shifted 90
--    DDR_Clk90_in_n    -- DDR clock feedback shifted by 270
--    Rst               -- System reset
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity ddr_controller is
    generic (
        C_EXTRA_TSU             : integer  := 0;
        C_FAMILY                : string   := "virtex2";
        C_NUM_BANKS_MEM         : integer range 1 to 4 := 1;
        C_NUM_CLK_PAIRS         : integer range 1 to 4 := 1;
        C_REG_DIMM              : integer  := 0;
        C_DDR_TMRD              : integer  := 15000;
        C_DDR_TWR               : integer  := 15000;
        C_DDR_TWTR              : integer  := 1;
        C_DDR_TRAS              : integer  := 40000;
        C_DDR_TRC               : integer  := 65000;
        C_DDR_TRFC              : integer  := 75000;
        C_DDR_TRCD              : integer  := 20000;
        C_DDR_TRRD              : integer  := 15000;
        C_DDR_TREFI             : integer  := 7800000;
        C_DDR_TRP               : integer  := 20000;
        C_DDR_CAS_LAT           : integer  := 2;
        C_DDR_DWIDTH            : integer  := 32;
        C_DDR_AWIDTH            : integer  := 13;
        C_DDR_COL_AWIDTH        : integer  := 9;
        C_DDR_BANK_AWIDTH       : integer  := 2;
        C_DDR_BRST_SIZE         : integer  := 8;
        C_IPIF_DWIDTH           : integer  := 64;
        C_IPIF_AWIDTH           : integer  := 32;
        C_INCLUDE_BURSTS        : integer  := 1;
        C_CLK_PERIOD            : integer  := 10000;
        C_OPB_BUS               : integer  := 0;
        C_PLB_BUS               : integer  := 1;
        -- simulation only generic (set to 200us)
        C_SIM_INIT_TIME_PS      : integer  := 200000000;
        C_INCLUDE_ECC_SUPPORT   : integer   := 0;
        NUM_ECC_BITS            : integer   := 7
     );
  port (
        -- IPIC inputs
        Bus2IP_Addr         : in  std_logic_vector(0 to C_IPIF_AWIDTH-1);
        Bus2IP_BE           : in  std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
        Bus2IP_Data         : in  std_logic_vector(0 to C_IPIF_DWIDTH-1);
        Bus2IP_RdReq        : in  std_logic;
        Bus2IP_WrReq        : in  std_logic;
        Bus2IP_Burst        : in  std_logic;
        Bus2IP_IBurst       : in  std_logic;
        Bus2IP_CS           : in  std_logic_vector(0 to C_NUM_BANKS_MEM-1);
        ECC_chk_bits_wr     : in  std_logic_vector (0 to NUM_ECC_BITS*2-1);
        ECC_chk_bits_rd     : out std_logic_vector (0 to NUM_ECC_BITS*2-1);

        -- IPIC outputs
        IP2Bus_Data         : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
        IP2Bus_WrAddrAck    : out std_logic;
        IP2Bus_RdAddrAck    : out std_logic;
        IP2Bus_Busy         : out std_logic;
        IP2Bus_RdAck        : out std_logic;
        IP2Bus_WrAck        : out std_logic;
        IP2Bus_ErrAck       : out std_logic;
        IP2Bus_Retry        : out std_logic;
        IP2Bus_ToutSup      : out std_logic;

        -- DDR interface signals
        DDR_Clk             : out std_logic_vector(0 to C_NUM_CLK_PAIRS-1);
        DDR_Clkn            : out std_logic_vector(0 to C_NUM_CLK_PAIRS-1);
        DDR_CKE             : out std_logic_vector(0 to C_NUM_BANKS_MEM-1);
        DDR_CSn             : out std_logic_vector(0 to C_NUM_BANKS_MEM-1);
        DDR_RASn            : out std_logic;
        DDR_CASn            : out std_logic;
        DDR_WEn             : out std_logic;
        DDR_DM              : out std_logic_vector(0 to C_DDR_DWIDTH/8-1);
        DDR_BankAddr        : out std_logic_vector(0 to C_DDR_BANK_AWIDTH-1);
        DDR_Addr            : out std_logic_vector(0 to C_DDR_AWIDTH-1);
        DDR_DQ_o            : out std_logic_vector(0 to C_DDR_DWIDTH-1);
        DDR_DQ_i            : in  std_logic_vector(0 to C_DDR_DWIDTH-1);
        DDR_DQ_t            : out std_logic_vector(0 to C_DDR_DWIDTH-1);
        DDR_DQS_i           : in  std_logic_vector(0 to C_DDR_DWIDTH/8-1);
        DDR_DQS_o           : out std_logic_vector(0 to C_DDR_DWIDTH/8-1);
        DDR_DQS_t           : out std_logic_vector(0 to C_DDR_DWIDTH/8-1);

        -- DDR ECC interface signals
        DDR_DM_ECC          : out std_logic;
        DDR_DQ_ECC_o        : out std_logic_vector(0 to NUM_ECC_BITS-1);
        DDR_DQ_ECC_i        : in  std_logic_vector(0 to NUM_ECC_BITS-1);
        DDR_DQ_ECC_t        : out std_logic_vector(0 to NUM_ECC_BITS-1);
        DDR_DQS_ECC_i       : in  std_logic;
        DDR_DQS_ECC_o       : out std_logic;
        DDR_DQS_ECC_t       : out std_logic;

        -- Timer/Interrupt signals
        DDR_Init_done       : out std_logic;

        -- Clocks and reset
        Sys_Clk             : in  std_logic;
        Sys_Clk_n           : in  std_logic;
        Clk90_in            : in  std_logic;
        Clk90_in_n          : in  std_logic;
        DDR_Clk90_in        : in  std_logic;
        DDR_Clk90_in_n      : in  std_logic;
        Rst                 : in  std_logic
    );
end entity ddr_controller;

-------------------------------------------------------------------------------
-- Architecture section
-------------------------------------------------------------------------------

architecture imp of ddr_controller is
-------------------------------------------------------------------------------
-- Function declarations
-------------------------------------------------------------------------------
type INTEGER_ARRAY is array (natural range <>) of integer;

-------------------------------------------------------------------------------
-- Name: max
-------------------------------------------------------------------------------
-- Description: function max returns the max value of an array
-------------------------------------------------------------------------------

function max(indata : INTEGER_ARRAY ) return integer is
  variable max_val : integer;
begin
  max_val := 0;
  for i in 0 to indata'length-1 loop
    if indata(i) > max_val then
        max_val := indata(i);
    end if;
 end loop;

 return max_val;
end max;

-------------------------------------------------------------------------------
-- Name: get_init_clocks
-------------------------------------------------------------------------------
-- Description: Function get_init_clocks returns the number of clocks for the
--              initialization time. If simulation, the initialization time is
--              set by C_SIM_INIT_TIME_PS. Otherwise, it is 200us.
-------------------------------------------------------------------------------

function get_init_clocks return integer is
    variable init_clocks : integer;
begin

    -- the following assignment is used in synthesis
    init_clocks := ((200000000-1)/C_CLK_PERIOD)+1;

    -- the following assignment is used in simulation
    -- synthesis translate off
    init_clocks := ((C_SIM_INIT_TIME_PS-1)/C_CLK_PERIOD)+1;
    -- synthesis translate on

    return init_clocks;
end get_init_clocks;

-------------------------------------------------------------------------------
-- Constant declarations
-------------------------------------------------------------------------------
-- create integer values of the delay parameters divided by clock frequency
-- to round values to next integer
constant DDR_TMRD_CLKS   : integer range 1 to 31 := 
                           ((C_DDR_TMRD-1)/C_CLK_PERIOD)+1;
constant DDR_TWR_CLKS    : integer range 1 to 31 := 
                           ((C_DDR_TWR-1)/C_CLK_PERIOD)+1;
constant DDR_TRAS_CLKS   : integer range 1 to 31 := 
                           ((C_DDR_TRAS-1)/C_CLK_PERIOD)+1;
constant DDR_TRC_CLKS    : integer range 1 to 31 := 
                           ((C_DDR_TRC-1)/C_CLK_PERIOD)+1;
constant DDR_TRFC_CLKS   : integer range 1 to 31 := 
                           ((C_DDR_TRFC-1)/C_CLK_PERIOD)+1;
constant DDR_TRCD_CLKS   : integer range 1 to 31 := 
                           ((C_DDR_TRCD-1)/C_CLK_PERIOD)+1;
constant DDR_TRRD_CLKS   : integer range 1 to 31 := 
                           ((C_DDR_TRRD-1)/C_CLK_PERIOD)+1;
constant DDR_TREFI_CLKS  : integer := ((C_DDR_TREFI-1)/C_CLK_PERIOD)+1;
constant DDR_TRP_CLKS    : integer range 1 to 31 := 
                           ((C_DDR_TRP-1)/C_CLK_PERIOD)+1;

-- set the number of clocks for the 200uS counter to the generic
-- C_SIM_INIT_TIME_PS for simulation by calling function get_init_clocks
constant CNT_200US_CLKS  : integer := get_init_clocks;

--
-- set width of counters
--
constant RCCNT_WIDTH     : integer := max2(1,log2(DDR_TRC_CLKS));
constant RRDCNT_WIDTH    : integer := max2(1,log2(DDR_TRRD_CLKS));
constant RASCNT_WIDTH    : integer := max2(1,log2(DDR_TRAS_CLKS));

-- width of the REFI and initialization counter is the max of the
-- number of clocks for REFI and initialization
-- (sim_init_time or 200us and 200 clks)
constant INITCNTR_WIDTH  : integer := max2(log2(CNT_200US_CLKS+1),log2(200));
constant REFICNT_WIDTH   : integer := max2(log2(DDR_TREFI_CLKS),
                                                INITCNTR_WIDTH);

constant BRSTCNT_WIDTH   : integer := max2(1,log2(C_DDR_BRST_SIZE/2)); 
constant WRCNT_WIDTH     : integer := max2(1,log2(DDR_TWR_CLKS));

-- add one to CAS latency if C_REG_DIMM
constant CASLATCNT_WIDTH : integer := max2(1,log2(C_DDR_CAS_LAT+C_REG_DIMM));

-- general purpose counter is used to count Tmrd, Trfc, Trp and Trcd
-- set this counter width from the max of these values
constant CNTR_WIDTH      : INTEGER_ARRAY := ( max2(1,log2(DDR_TMRD_CLKS)), 
                                             max2(1,log2(DDR_TRFC_CLKS)),
                                             max2(1,log2(DDR_TRP_CLKS)),
                                             max2(1,log2(DDR_TRCD_CLKS)));

constant GPCNT_WIDTH     : integer := max(CNTR_WIDTH);

--
-- create std_logic_vectors for counter load values
--
constant RCCNT      : std_logic_vector(0 to RCCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TRC_CLKS-1, RCCNT_WIDTH);
constant RRDCNT     : std_logic_vector(0 to RRDCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TRRD_CLKS-1, RRDCNT_WIDTH);
constant RASCNT     : std_logic_vector(0 to RASCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TRAS_CLKS-1, RASCNT_WIDTH);
-- Set REFICNT to DDR_TREFI_CLKS - X where X is enough margin 
-- to do a refresh properly knowing that the state machine may be in another
-- command use the max of the margin and the refresh clocks for testing fast
-- refresh rates counter is wide enough because it is sized for at least 200
-- clocks
constant REF_MARGIN : integer   := 32;
constant REF_CLKS   : integer   := max2(DDR_TREFI_CLKS-REF_MARGIN, REF_MARGIN);
constant REFICNT    : std_logic_vector(0 to REFICNT_WIDTH-1) :=
                      conv_std_logic_vector(REF_CLKS-1, REFICNT_WIDTH);
constant WRCNT      : std_logic_vector(0 to WRCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TWR_CLKS-1, WRCNT_WIDTH);
constant BRSTCNT    : std_logic_vector(0 to BRSTCNT_WIDTH-1) :=
                      conv_std_logic_vector(C_DDR_BRST_SIZE/2-1, 
                                             BRSTCNT_WIDTH);
-- determine brstcnt/2 to mark when new command can be applied 
constant CMDCNT     : std_logic_vector(0 to BRSTCNT_WIDTH-1) :=
                      conv_std_logic_vector(C_DDR_BRST_SIZE/2-1, 
                                             BRSTCNT_WIDTH);

-- add one to CAS latency if C_REG_DIMM
constant CASLATCNT  : std_logic_vector(0 to CASLATCNT_WIDTH-1) :=
                      conv_std_logic_vector(C_DDR_CAS_LAT+C_REG_DIMM-1, 
                                             CASLATCNT_WIDTH);
constant CNT_200US  : std_logic_vector(0 to REFICNT_WIDTH-1) :=
                      conv_std_logic_vector(CNT_200US_CLKS-1, REFICNT_WIDTH);
constant CNT_200CLK : std_logic_vector(0 to REFICNT_WIDTH-1) :=
                      conv_std_logic_vector(200-1, REFICNT_WIDTH);

constant MRDCNT     : std_logic_vector(0 to GPCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TMRD_CLKS-1, GPCNT_WIDTH);
constant RFCCNT     : std_logic_vector(0 to GPCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TRFC_CLKS-1, GPCNT_WIDTH);
constant RPCNT      : std_logic_vector(0 to GPCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TRP_CLKS-1, GPCNT_WIDTH);
constant RCDCNT     : std_logic_vector(0 to GPCNT_WIDTH-1) :=
                      conv_std_logic_vector(DDR_TRCD_CLKS-1, GPCNT_WIDTH);

-------------------------------------------------------------------------------
-- Signal declarations
-------------------------------------------------------------------------------
signal gpcnt_load           : std_logic;
signal gpcnt_en             : std_logic;
signal gpcnt_data           : std_logic_vector(0 to GPCNT_WIDTH-1);
signal trc_load             : std_logic;
signal trrd_load            : std_logic;
signal tras_load            : std_logic;
signal trefi_load           : std_logic;
signal tpwrup_load          : std_logic;
signal tbrst_load           : std_logic;
signal tbrst_cnt_en         : std_logic;
signal tcmd_load            : std_logic;
signal tcmd_cnt_en          : std_logic;
signal tcaslat_load         : std_logic;
signal tcaslat_cnt_en       : std_logic;
signal tcaslat_end          : std_logic;
signal gpcnt_end            : std_logic;
signal trc_end              : std_logic;
signal trrd_end             : std_logic;
signal tras_end             : std_logic;
signal trefi_pwrup_end      : std_logic;
signal twr_load             : std_logic;
signal twr_rst              : std_logic;
signal twr_cnten            : std_logic;
signal twr_end              : std_logic;
signal ddr_brst_end         : std_logic;
signal tcmd_end             : std_logic;

signal refresh              : std_logic;
signal precharge            : std_logic;
signal load_mr              : std_logic;
signal register_data        : std_logic_vector(0 to C_DDR_AWIDTH-1);
signal register_sel         : std_logic_vector(0 to C_DDR_BANK_AWIDTH-1);
signal cmd_done             : std_logic;
signal init_done            : std_logic;

signal read_data_done       : std_logic;
signal read_data_done_rst   : std_logic;
signal ipic_be              : std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
signal ipic_wrdata          : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal write_data_en        : std_logic;
signal wr_up_lo_data_sel    : std_logic;
signal write_dqs_en         : std_logic_vector(0 to C_DDR_DWIDTH/8-1);
signal dq_oe_cmb            : std_logic;
signal dqs_oe               : std_logic_vector(0 to C_DDR_DWIDTH/8-1);
signal dqs_rst              : std_logic_vector(0 to C_DDR_DWIDTH/8-1);
signal dqs_setrst           : std_logic_vector(0 to C_DDR_DWIDTH/8-1);
signal read_data_en         : std_logic;
signal ddr_read_data_en     : std_logic;
signal ddr_read_dqs         : std_logic_vector(0 to C_DDR_DWIDTH/8-1);
signal rdack                : std_logic;
signal rdack_rst            : std_logic;
signal read_pause           : std_logic;
signal wrack                : std_logic;
signal retry                : std_logic;
signal rd_addrack           : std_logic;
signal wr_addrack           : std_logic;
signal read_dqs_ce          : std_logic;
signal burst                : std_logic;

signal row_addr             : std_logic_vector(0 to C_DDR_AWIDTH-1);
signal col_addr             : std_logic_vector(0 to C_DDR_AWIDTH-1);
signal bank_addr            : std_logic_vector(0 to C_DDR_BANK_AWIDTH-1);
signal pend_rdreq           : std_logic;
signal pend_wrreq           : std_logic;
signal same_row             : std_logic;
signal same_bank            : std_logic;
signal reset_pendrdreq      : std_logic;
signal reset_pendwrreq      : std_logic;
signal toutsup              : std_logic;
signal pend_read            : std_logic;
signal pend_write           : std_logic;

signal csn                  : std_logic_vector(0 to C_NUM_BANKS_MEM-1);
signal rasn                 : std_logic;
signal casn                 : std_logic;
signal wen                  : std_logic;
signal addr                 : std_logic_vector(0 to C_DDR_AWIDTH-1);
signal bankaddr             : std_logic_vector(0 to C_DDR_BANK_AWIDTH-1);

signal clk_i                : std_logic;
signal clk_n_i              : std_logic;
signal clk90_i              : std_logic;
signal clk90_n_i            : std_logic;
signal clk_ddr_rddata_i     : std_logic;
signal clk_ddr_rddata_n_i   : std_logic;

signal comb_Bus2IP_CS       : std_logic;

-------------------------------------------------------------------------------
-- Component declarations
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------

begin  

-- assign output signals
DDR_Init_done <= init_done;

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------

-- Same component instantiation regardless of C_INCLUDE_ECC_SUPPORT and
-- C_DDR_DWIDTH
INITSM_I: entity ddr_v3_00_a.init_statemachine(imp)
generic map (
             C_NUM_BANKS_MEM     =>  C_NUM_BANKS_MEM,
             C_DDR_AWIDTH        =>  C_DDR_AWIDTH,
             C_DDR_BANK_AWIDTH   =>  C_DDR_BANK_AWIDTH,
             C_DDR_BRST_SIZE     =>  C_DDR_BRST_SIZE,
             C_DDR_CAS_LAT       =>  C_DDR_CAS_LAT
            )
port map(
         Cmd_done         =>  cmd_done,
         Trefi_pwrup_end  =>  trefi_pwrup_end,
         Precharge        =>  precharge,
         Load_mr          =>  load_mr,
         Tpwrup_load      =>  tpwrup_load,
         Refresh          =>  refresh,
         Register_data    =>  register_data,
         Register_sel     =>  register_sel,
         Init_done        =>  init_done,
         DDR_CKE          =>  DDR_CKE,
         Clk              =>  clk_i,
         Rst              =>  Rst
         );

CNTRS_I: entity ddr_v3_00_a.counters(imp)
generic map (
             C_GPCNT_WIDTH        =>  GPCNT_WIDTH,
             C_RCCNT_WIDTH        =>  RCCNT_WIDTH,
             C_RRDCNT_WIDTH       =>  RRDCNT_WIDTH,
             C_RASCNT_WIDTH       =>  RASCNT_WIDTH,
             C_REFICNT_WIDTH      =>  REFICNT_WIDTH,
             C_WRCNT_WIDTH        =>  WRCNT_WIDTH,
             C_BRSTCNT_WIDTH      =>  BRSTCNT_WIDTH,
             C_CASLATCNT_WIDTH    =>  CASLATCNT_WIDTH,
             C_RCCNT              =>  RCCNT,
             C_RRDCNT             =>  RRDCNT,
             C_RASCNT             =>  RASCNT,
             C_REFICNT            =>  REFICNT,
             C_200US_CNT          =>  CNT_200US,
             C_200CK_CNT          =>  CNT_200CLK,
             C_WRCNT              =>  WRCNT,
             C_BRSTCNT            =>  BRSTCNT,
             C_CMDCNT             =>  CMDCNT,
             C_CASLATCNT          =>  CASLATCNT,
             C_DDR_BRST_SIZE      =>  C_DDR_BRST_SIZE,
             C_CASLAT             =>  C_DDR_CAS_LAT+C_REG_DIMM
             )
port map (
          GPcnt_load      => gpcnt_load,
          GPcnt_en        => gpcnt_en,
          GPcnt_data      => gpcnt_data,
          Trc_load        => trc_load,
          Trrd_load       => trrd_load,
          Tras_load       => tras_load,
          Trefi_load      => trefi_load,
          Tpwrup_load     => tpwrup_load,
          Tbrst_load      => tbrst_load,
          Tbrst_cnt_en    => tbrst_cnt_en,
          Init_done       => init_done,
          Tcmd_load       => tcmd_load,
          Tcmd_cnt_en     => tcmd_cnt_en,
          Tcaslat_load    => tcaslat_load,
          Tcaslat_cnt_en  => tcaslat_cnt_en,
          Twr_load        => twr_load,
          Twr_rst         => twr_rst,
          Twr_cnten       => twr_cnten,
          GPcnt_end       => gpcnt_end,
          Trc_end         => trc_end,
          Trrd_end        => trrd_end,
          Tras_end        => tras_end,
          Trefi_pwrup_end => trefi_pwrup_end,
          Twr_end         => twr_end,
          DDR_brst_end    => ddr_brst_end,
          Tcmd_end        => tcmd_end,
          Tcaslat_end     => tcaslat_end,
          Clk             => clk_i,
          Rst             => Rst
          );

CLKGEN_I: entity ddr_v3_00_a.clock_gen(imp) 
generic map ( 
             C_NUM_CLK_PAIRS  =>  C_NUM_CLK_PAIRS,
             C_FAMILY         =>  C_FAMILY
             )
port map (
          Sys_clk            =>  Sys_clk,
          Sys_clk_n          =>  Sys_clk_n,
          Clk90_in           =>  Clk90_in,
          Clk90_in_n         =>  Clk90_in_n,
          DDR_Clk90_in       =>  DDR_Clk90_in,
          DDR_Clk90_in_n     =>  DDR_Clk90_in_n,
          Clk                =>  clk_i,
          Clk_n              =>  clk_n_i,
          Clk90              =>  clk90_i,
          Clk90_n            =>  clk90_n_i,
          Clk_ddr_rddata     =>  clk_ddr_rddata_i,
          Clk_ddr_rddata_n   =>  clk_ddr_rddata_n_i,
          DDR_Clk            =>  DDR_Clk,
          DDR_Clkn           =>  DDR_Clkn
          );

-------------------------------------------------------------------------------
-- Name: W_ECC
-------------------------------------------------------------------------------
-- Description: Support registers and port connections for generating ECC logic
--              when C_INCLUDE_ECC_SUPPORT = 1 and C_DDR_DWIDTH = 32. This is 
--              applied only when interface is PLB
-------------------------------------------------------------------------------

W_ECC: if C_INCLUDE_ECC_SUPPORT = 1 and C_DDR_DWIDTH = 32 generate

-- Only create signals if C_INCLUDE_ECC_SUPPORT = 1
signal write_data_ecc       : std_logic_vector(0 to NUM_ECC_BITS*2-1);
signal write_data_ecc_mask  : std_logic_vector (0 to C_IPIF_DWIDTH/32-1);
signal write_data_ecc_en    : std_logic;
signal write_dqs_ecc_en     : std_logic;
signal dqs_ecc_rst          : std_logic;
signal dqs_ecc_setrst       : std_logic;
signal dqs_ecc_oe           : std_logic;
signal dq_ecc_oe_cmb        : std_logic;
signal ddr_readdata_ecc     : std_logic_vector(0 to NUM_ECC_BITS*2-1);
signal ddr_read_dqs_ecc     : std_logic;
signal ecc_wrdata           : std_logic_vector(0 to NUM_ECC_BITS*2-1);
signal ecc_rddata           : std_logic_vector(0 to NUM_ECC_BITS*2-1);

signal read_data            : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal ddr_readdata         : std_logic_vector(0 to C_IPIF_DWIDTH-1); 
signal write_data           : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal write_data_mask      : std_logic_vector(0 to C_IPIF_DWIDTH/8-1);

begin

    -- In this configuration, there is no Addr28 FIFO, set its
    -- occupancy value to zero

    COMMAND_STATEMACHINE_I : entity ddr_v3_00_a.command_statemachine(imp)
    generic map (
                C_DDR_AWIDTH              => C_DDR_AWIDTH,
                C_DDR_DWIDTH              => C_DDR_DWIDTH,          
                C_DDR_COL_AWIDTH          => C_DDR_COL_AWIDTH,      
                C_DDR_BANK_AWIDTH         => C_DDR_BANK_AWIDTH,     
                C_REG_DIMM                => C_REG_DIMM,
                C_MRDCNT                  => MRDCNT,
                C_RFCCNT                  => RFCCNT,
                C_RCDCNT                  => RCDCNT,
                C_RPCNT                   => RPCNT,
                C_GP_CNTR_WIDTH           => GPCNT_WIDTH,
                C_OPB_BUS                 => C_OPB_BUS,
                C_PLB_BUS                 => C_PLB_BUS,
                C_INCLUDE_BURSTS          => C_INCLUDE_BURSTS,
                C_INCLUDE_ECC_SUPPORT     => C_INCLUDE_ECC_SUPPORT,
                C_NUM_BANKS_MEM           => C_NUM_BANKS_MEM
                )
    port map (
              Comb_Bus2IP_CS        => comb_Bus2IP_CS,    -- in
              Bus2IP_CS             => Bus2IP_CS,         -- in
              Row_addr              => row_addr,          -- in
              Col_addr              => col_addr,          -- in
              Bank_addr             => bank_addr,         -- in
              Bus2IP_RdReq          => Bus2IP_RdReq,      -- in
              Bus2IP_WrReq          => Bus2IP_WrReq,      -- in
              Pend_rdreq            => pend_rdreq,        -- in
              Pend_wrreq            => pend_wrreq,        -- in
              Same_row              => same_row,          -- in
              Same_bank             => same_bank,         -- in
              Read_dqs_ce           => read_dqs_ce,       -- out
              Retry                 => retry,             -- out
              Rd_AddrAck            => rd_addrack,        -- out
              Wr_AddrAck            => wr_addrack,        -- out
              Reset_pendrdreq       => reset_pendrdreq,   -- out
              Reset_pendwrreq       => reset_pendwrreq,   -- out
              ToutSup               => toutsup,           -- out
              Refresh               => refresh,           -- in
              Precharge             => precharge,         -- in
              Load_mr               => load_mr,           -- in
              Register_data         => register_data,     -- in
              Register_sel          => register_sel,      -- in
              Init_done             => init_done,         -- in
              Cmd_done              => cmd_done,          -- out
              Read_data_done        => read_data_done,    -- in
              Read_data_done_rst    => read_data_done_rst,-- out
              Pend_write            => pend_write,        -- out
              Pend_read             => pend_read,         -- out
              Read_pause            => read_pause,        -- out
              Trefi_end             => trefi_pwrup_end,   -- in
              Trc_end               => trc_end,           -- in
              Trrd_end              => trrd_end,          -- in
              Tras_end              => tras_end,          -- in
              Twr_end               => twr_end,           -- in
              GPcnt_end             => gpcnt_end,         -- in
              Tcmd_end              => tcmd_end,          -- in
              Twr_rst               => twr_rst,           -- out
              Tcmd_load             => tcmd_load,         -- out
              Tcmd_cnt_en           => tcmd_cnt_en,       -- out
              Trefi_load            => trefi_load,        -- out
              Trc_load              => trc_load,          -- out
              Trrd_load             => trrd_load,         -- out
              Tras_load             => tras_load,         -- out
              GPcnt_load            => gpcnt_load,        -- out
              GPcnt_en              => gpcnt_en,          -- out
              GPcnt_data            => gpcnt_data,        -- out
              DDR_CSn               => csn,               -- out
              DDR_RASn              => rasn,              -- out
              DDR_CASn              => casn,              -- out
              DDR_WEn               => wen,               -- out
              DDR_Addr              => addr,              -- out
              DDR_BankAddr          => bankaddr,          -- out
              DQ_oe_cmb             => dq_oe_cmb,         -- out
              DQS_oe                => dqs_oe,            -- out
              DQS_rst               => dqs_rst,           -- out
              DQS_setrst            => dqs_setrst,        -- out
              DQ_ECC_oe_cmb         => dq_ecc_oe_cmb,     -- out
              DQS_ECC_oe            => dqs_ecc_oe,        -- out
              DQS_ECC_rst           => dqs_ecc_rst,       -- out
              DQS_ECC_setrst        => dqs_ecc_setrst,    -- out
              Clk                   => clk_i,             -- in
              Clk90                 => clk90_i,           -- in
              Rst                   => rst                -- in
              );

    DATASM_I: entity ddr_v3_00_a.data_statemachine(imp)
    generic map (
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_REG_DIMM            => C_REG_DIMM,
                 C_INCLUDE_BURSTS      => C_INCLUDE_BURSTS,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 NUM_ECC_BITS          => NUM_ECC_BITS 
                 )
    port map (
              IPIC_wrdata           =>  ipic_wrdata,
              ECC_chk_bits_wr       =>  ecc_wrdata,
              IPIC_be               =>  ipic_be,
              Bus2IP_Burst          =>  burst,
              Comb_Bus2IP_CS        =>  comb_Bus2IP_CS,
              Pend_write            =>  pend_write,
              Pend_read             =>  pend_read,
              DDR_brst_end          =>  ddr_brst_end,
              Tcaslat_end           =>  tcaslat_end,
              Twr_end               =>  twr_end,
              Read_data_done_rst    =>  read_data_done_rst,
              Read_pause            =>  read_pause,
              RdAck                 =>  rdack,
              WrAck                 =>  WrAck,
              Read_data_en          =>  read_data_en,
              Write_data_en         =>  write_data_en,
              Wr_up_lo_data_sel     =>  Wr_up_lo_data_sel,
              Write_data_ecc_en     =>  write_data_ecc_en,
              Write_dqs_en          =>  write_dqs_en,
              Write_dqs_ecc_en      =>  write_dqs_ecc_en,
              Write_data            =>  write_data,
              Write_data_ecc        =>  write_data_ecc,
              Write_data_mask       =>  write_data_mask,
              Write_data_ecc_mask   =>  write_data_ecc_mask,
              Read_data_done        =>  read_data_done,
              Tbrst_cnt_en          =>  tbrst_cnt_en,
              Tbrst_load            =>  tbrst_load,
              Tcaslat_load          =>  tcaslat_load,
              Tcaslat_cnt_en        =>  tcaslat_cnt_en,
              Twr_load              =>  twr_load,
              Twr_cnten             =>  twr_cnten,
              RdAck_rst             =>  rdack_rst,
              Clk                   =>  clk_i,
              Clk90                 =>  clk90_i,
              Rst                   =>  Rst
              );


    IO_REG_I: entity ddr_v3_00_a.io_registers(imp)
    generic map (
                 C_EXTRA_TSU           => C_EXTRA_TSU,
                 C_DDR_AWIDTH          => C_DDR_AWIDTH,
                 C_DDR_BANK_AWIDTH     => C_DDR_BANK_AWIDTH,
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_FAMILY              => C_FAMILY,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 NUM_ECC_BITS          => NUM_ECC_BITS,
                 C_NUM_BANKS_MEM       => C_NUM_BANKS_MEM
                 )
    port map (
              Write_data            => write_data,
              Write_data_ecc        => write_data_ecc,
              Wr_up_lo_data_sel     => Wr_up_lo_data_sel,
              Write_data_en         => write_data_en,
              Write_data_ecc_en     => write_data_ecc_en,
              Write_dqs_en          => write_dqs_en,
              Write_dqs_ecc_en      => write_dqs_ecc_en,
              Read_dqs_ce           => read_dqs_ce,
              Write_data_mask       => write_data_mask,
              Write_data_ecc_mask   => write_data_ecc_mask,
              Read_data_en          => read_data_en,
              DQ_oe_cmb             => dq_oe_cmb,
              DQ_ECC_oe_cmb         => dq_ecc_oe_cmb,
              DQS_oe                => dqs_oe,
              DQS_ECC_oe            => dqs_ecc_oe,
              DQS_rst               => dqs_rst,
              DQS_ECC_rst           => dqs_ecc_rst,
              DQS_setrst            => dqs_setrst,
              DQS_ECC_setrst        => dqs_ecc_setrst,
              CSn                   => csn,
              RASn                  => rasn,
              CASn                  => casn,
              WEn                   => wen,
              BankAddr              => bankaddr,
              Addr                  => addr,
              DDR_ReadData          => ddr_readdata,
              DDR_ReadData_ECC      => ddr_readdata_ecc,
              DDR_read_data_en      => ddr_read_data_en,
              DDR_DQ_i              => DDR_DQ_i,
              DDR_DQ_o              => DDR_DQ_o,
              DDR_DQ_t              => DDR_DQ_t,
              DDR_DM                => DDR_DM,
              DDR_Read_DQS          => ddr_read_dqs,
              DDR_Read_DQS_ECC      => ddr_read_dqs_ecc,
              DDR_DQS_I             => DDR_DQS_i,
              DDR_DQS_o             => DDR_DQS_o,
              DDR_DQS_t             => DDR_DQS_t,
              DDR_DM_ECC            => DDR_DM_ECC,
              DDR_DQ_ECC_o          => DDR_DQ_ECC_o,
              DDR_DQ_ECC_i          => DDR_DQ_ECC_i,
              DDR_DQ_ECC_t          => DDR_DQ_ECC_t,
              DDR_DQS_ECC_i         => DDR_DQS_ECC_i,
              DDR_DQS_ECC_o         => DDR_DQS_ECC_o,
              DDR_DQS_ECC_t         => DDR_DQS_ECC_t,
              DDR_CSn               => DDR_CSn,
              DDR_RASn              => DDR_RASn,
              DDR_CASn              => DDR_CASn,
              DDR_WEn               => DDR_WEn,
              DDR_BankAddr          => DDR_BankAddr,
              DDR_Addr              => DDR_Addr,
              Clk                   => clk_i,
              Clk_n                 => clk_n_i,
              Clk90                 => clk90_i,
              Clk90_n               => clk90_n_i,
              Clk_ddr_rddata        => clk_ddr_rddata_i,
              Clk_ddr_rddata_n      => clk_ddr_rddata_n_i,
              Rst                   => rst
              );

    IPIC_IF_I : entity ddr_v3_00_a.ipic_if(imp)
    generic map(
                C_NUM_BANKS_MEM       => C_NUM_BANKS_MEM,     -- integer
                C_DDR_AWIDTH          => C_DDR_AWIDTH,        -- integer
                C_DDR_DWIDTH          => C_DDR_DWIDTH,        -- integer
                C_DDR_COL_AWIDTH      => C_DDR_COL_AWIDTH,    -- integer
                C_DDR_BANK_AWIDTH     => C_DDR_BANK_AWIDTH,   -- integer
                C_IPIF_AWIDTH         => C_IPIF_AWIDTH,       -- integer
                C_IPIF_DWIDTH         => C_IPIF_DWIDTH,       -- integer
                C_INCLUDE_BURSTS      => C_INCLUDE_BURSTS,    -- integer
                C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                NUM_ECC_BITS          => NUM_ECC_BITS
                )
    port map (
              Bus2IP_CS             => Bus2IP_CS,           -- in
              Bus2IP_Addr           => Bus2IP_Addr,         -- in
              Bus2IP_Burst          => Bus2IP_Burst,        -- in
              Bus2IP_IBurst         => Bus2IP_IBurst,       -- in
              Bus2IP_Data           => Bus2IP_Data,         -- in
              ECC_chk_bits_wr_in    => ECC_chk_bits_wr,     -- in
              Bus2IP_BE             => Bus2IP_BE,           -- in
              Bus2IP_RdReq          => Bus2IP_RdReq,        -- in
              Bus2IP_WrReq          => Bus2IP_WrReq,        -- in
              IP2Bus_ErrAck         => IP2Bus_ErrAck,       -- out
              IP2Bus_Retry          => IP2Bus_Retry,        -- out
              IP2Bus_Busy           => IP2Bus_Busy,         -- out
              IP2Bus_WrAddrAck      => IP2Bus_WrAddrAck,    -- out
              IP2Bus_RdAddrAck      => IP2Bus_RdAddrAck,    -- out
              IP2Bus_WrAck          => IP2Bus_WrAck,        -- out
              IP2Bus_RdAck          => IP2Bus_RdAck,        -- out
              IP2Bus_ToutSup        => IP2Bus_ToutSup,      -- out
              IP2Bus_data           => IP2Bus_data,         -- out
              ECC_chk_bits_rd_out   => ECC_chk_bits_rd,     -- out
              Wr_AddrAck            => wr_addrack,          -- in
              Rd_AddrAck            => rd_addrack,          -- in
              WrAck                 => wrack,               -- in
              RdAck                 => rdack,               -- in
              ToutSup               => toutsup,             -- in
              Read_data             => read_data,           -- in
              ECC_chk_bits_rd_in    => ecc_rddata,          -- in
              Retry                 => retry,               -- in
              Init_done             => init_done,           -- in
              Comb_Bus2IP_CS        => comb_Bus2IP_CS,      -- out
              IPIC_wrdata           => ipic_wrdata,         -- out
              ECC_chk_bits_wr_out   => ecc_wrdata,          -- out
              IPIC_be               => ipic_be,             -- out
              Burst                 => burst,               -- out
              Reset_pendrdreq       => reset_pendrdreq,     -- in
              Reset_pendwrreq       => reset_pendwrreq,     -- in
              Row_addr              => row_addr,            -- out
              Col_addr              => col_addr,            -- out
              Bank_addr             => bank_addr,           -- out
              Pend_rdreq            => pend_rdreq,          -- out
              Pend_wrreq            => pend_wrreq,          -- out
              Same_row              => same_row,            -- out
              Same_bank             => same_bank,           -- out
              Clk                   => clk_i,               -- in
              Rst                   => rst                  -- in
              );

    RDDATA_PATH_I: entity ddr_v3_00_a.read_data_path(imp)
    generic map (
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_FAMILY              => C_FAMILY,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 C_DDR_CAS_LAT         => C_DDR_CAS_LAT,
                 C_REG_DIMM            => C_REG_DIMM,
                 NUM_ECC_BITS          => NUM_ECC_BITS
                 )
    port map (
              DDR_ReadData          => ddr_readdata,
              DDR_ReadData_ECC      => ddr_readdata_ecc,
              DDR_ReadDQS           => ddr_read_dqs,
              DDR_ReadDQS_ECC       => ddr_read_dqs_ecc,
              DDR_read_data_en      => ddr_read_data_en,
              Read_data_en          => read_data_en,
              RdAck_rst             => rdack_rst,
              Read_data             => read_data,
              ECC_chk_bits_rd       => ecc_rddata,
              RdAck                 => rdack,
              FIFO_Rden             => open,
              Rd_addrack            => rd_addrack,
              Clk                   => clk_i,
              Clk_ddr_rddata        => clk_ddr_rddata_i,
              Rst                   => Rst
              );

end generate W_ECC;

-------------------------------------------------------------------------------
-- Name: WO_ECC_BUS2XDDR
-------------------------------------------------------------------------------
-- Description: No ECC logic to be instantiated/supported when
--              C_INCLUDE_ECC_SUPPORT = 0 and C_IPIF_DWIDTH/C_DDR_DWIDTH=2
--              This will generate the design when bus data width is twice the
--              DDR data width.
-------------------------------------------------------------------------------

WO_ECC_BUS2XDDR: if C_INCLUDE_ECC_SUPPORT = 0 and( (C_IPIF_DWIDTH/C_DDR_DWIDTH=2) or 
                    (C_IPIF_DWIDTH/C_DDR_DWIDTH=4) ) 
                 generate
                                 
constant ZERO_ECC_BITS         : std_logic_vector(0 to NUM_ECC_BITS*2-1)
                                 := (others => '0');      
constant ZERO_DQ_ECC_BITS      : std_logic_vector(0 to NUM_ECC_BITS-1)
                                  := (others => '0');
constant WRITE_DATA_ECC_MASK_1 : std_logic_vector(0 to C_IPIF_DWIDTH/32-1)
                                 := (others => '1');

signal read_data            : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal ddr_readdata         : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal write_data           : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal write_data_mask      : std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
signal ddr_readdata_i       : std_logic_vector(0 to 2*C_DDR_DWIDTH-1);

begin

    ddr_readdata_i <= ddr_readdata(0 to 2*C_DDR_DWIDTH-1);

    -- In this configuration, there is no Addr28 FIFO, set its
    -- occupancy value to zero

    COMMAND_STATEMACHINE_I : entity ddr_v3_00_a.command_statemachine(imp)
    generic map (
                 C_DDR_AWIDTH            => C_DDR_AWIDTH,
                 C_DDR_DWIDTH            => C_DDR_DWIDTH,
                 C_DDR_COL_AWIDTH        => C_DDR_COL_AWIDTH,
                 C_DDR_BANK_AWIDTH       => C_DDR_BANK_AWIDTH,
                 C_REG_DIMM              => C_REG_DIMM,
                 C_MRDCNT                => MRDCNT,
                 C_RFCCNT                => RFCCNT,
                 C_RCDCNT                => RCDCNT,
                 C_RPCNT                 => RPCNT,
                 C_GP_CNTR_WIDTH         => GPCNT_WIDTH,
                 C_OPB_BUS               => C_OPB_BUS,
                 C_PLB_BUS               => C_PLB_BUS,
                 C_INCLUDE_BURSTS        => C_INCLUDE_BURSTS,
                 C_INCLUDE_ECC_SUPPORT   => C_INCLUDE_ECC_SUPPORT,
                 C_NUM_BANKS_MEM         => C_NUM_BANKS_MEM
                 )
    port map (
              Comb_Bus2IP_CS        => comb_Bus2IP_CS,    -- in
              Bus2IP_CS             => Bus2IP_CS,         -- in
              Row_addr              => row_addr,          -- in
              Col_addr              => col_addr,          -- in
              Bank_addr             => bank_addr,         -- in
              Bus2IP_RdReq          => Bus2IP_RdReq,      -- in
              Bus2IP_WrReq          => Bus2IP_WrReq,      -- in
              Pend_rdreq            => pend_rdreq,        -- in
              Pend_wrreq            => pend_wrreq,        -- in
              Same_row              => same_row,          -- in
              Same_bank             => same_bank,         -- in
              Read_dqs_ce           => read_dqs_ce,       -- out
              Retry                 => retry,             -- out
              Rd_AddrAck            => rd_addrack,        -- out
              Wr_AddrAck            => wr_addrack,        -- out
              Reset_pendrdreq       => reset_pendrdreq,   -- out
              Reset_pendwrreq       => reset_pendwrreq,   -- out
              ToutSup               => toutsup,           -- out
              Refresh               => refresh,           -- in
              Precharge             => precharge,         -- in
              Load_mr               => load_mr,           -- in
              Register_data         => register_data,     -- in
              Register_sel          => register_sel,      -- in
              Init_done             => init_done,         -- in
              Cmd_done              => cmd_done,          -- out
              Read_data_done        => read_data_done,    -- in
              Read_data_done_rst    => read_data_done_rst,-- out
              Pend_write            => pend_write,        -- out
              Pend_read             => pend_read,         -- out
              Read_pause            => read_pause,        -- out
              Trefi_end             => trefi_pwrup_end,   -- in
              Trc_end               => trc_end,           -- in
              Trrd_end              => trrd_end,          -- in
              Tras_end              => tras_end,          -- in
              Twr_end               => twr_end,           -- in
              GPcnt_end             => gpcnt_end,         -- in
              Tcmd_end              => tcmd_end,          -- in
              Twr_rst               => twr_rst,           -- out
              Tcmd_load             => tcmd_load,         -- out
              Tcmd_cnt_en           => tcmd_cnt_en,       -- out
              Trefi_load            => trefi_load,        -- out
              Trc_load              => trc_load,          -- out
              Trrd_load             => trrd_load,         -- out
              Tras_load             => tras_load,         -- out
              GPcnt_load            => gpcnt_load,        -- out
              GPcnt_en              => gpcnt_en,          -- out
              GPcnt_data            => gpcnt_data,        -- out
              DDR_CSn               => csn,               -- out
              DDR_RASn              => rasn,              -- out
              DDR_CASn              => casn,              -- out
              DDR_WEn               => wen,               -- out
              DDR_Addr              => addr,              -- out
              DDR_BankAddr          => bankaddr,          -- out
              DQ_oe_cmb             => dq_oe_cmb,         -- out
              DQS_oe                => dqs_oe,            -- out
              DQS_rst               => dqs_rst,           -- out
              DQS_setrst            => dqs_setrst,        -- out
              DQ_ECC_oe_cmb         => open,              -- out
              DQS_ECC_oe            => open,              -- out
              DQS_ECC_rst           => open,              -- out
              DQS_ECC_setrst        => open,              -- out
              Clk                   => clk_i,             -- in
              Clk90                 => clk90_i,           -- in
              Rst                   => rst                -- in
              );

    DATASM_I: entity ddr_v3_00_a.data_statemachine(imp)
    generic map (
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_REG_DIMM            => C_REG_DIMM,
                 C_INCLUDE_BURSTS      => C_INCLUDE_BURSTS,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 NUM_ECC_BITS          => NUM_ECC_BITS
                 )
    port map (
              IPIC_wrdata           =>  ipic_wrdata,
              ECC_chk_bits_wr       =>  ZERO_ECC_BITS,
              IPIC_be               =>  ipic_be,
              Bus2IP_Burst          =>  burst,
              Comb_Bus2IP_CS        =>  comb_Bus2IP_CS,
              Pend_write            =>  pend_write,
              Pend_read             =>  pend_read,
              DDR_brst_end          =>  ddr_brst_end,
              Tcaslat_end           =>  tcaslat_end,
              Twr_end               =>  twr_end,
              Read_data_done_rst    =>  read_data_done_rst,
              Read_pause            =>  read_pause,
              RdAck                 =>  rdack,
              WrAck                 =>  WrAck,
              Read_data_en          =>  read_data_en,
              Write_data_en         =>  write_data_en,
              Wr_up_lo_data_sel     =>  wr_up_lo_data_sel,
              Write_data_ecc_en     =>  open,
              Write_dqs_en          =>  write_dqs_en,
              Write_dqs_ecc_en      =>  open,
              Write_data            =>  write_data,
              Write_data_ecc        =>  open,
              Write_data_mask       =>  write_data_mask,
              Write_data_ecc_mask   =>  open,
              Read_data_done        =>  read_data_done,
              Tbrst_cnt_en          =>  tbrst_cnt_en,
              Tbrst_load            =>  tbrst_load,
              Tcaslat_load          =>  tcaslat_load,
              Tcaslat_cnt_en        =>  tcaslat_cnt_en,
              Twr_load              =>  twr_load,
              Twr_cnten             =>  twr_cnten,
              RdAck_rst             =>  rdack_rst,
              Clk                   =>  clk_i,
              Clk90                 =>  clk90_i,
              Rst                   =>  Rst
              );

    IO_REG_I: entity ddr_v3_00_a.io_registers(imp)
    generic map (
                 C_EXTRA_TSU            =>  C_EXTRA_TSU,
                 C_DDR_AWIDTH           => C_DDR_AWIDTH,
                 C_DDR_BANK_AWIDTH      => C_DDR_BANK_AWIDTH,
                 C_DDR_DWIDTH           => C_DDR_DWIDTH,
                 C_IPIF_DWIDTH          => C_IPIF_DWIDTH,
                 C_FAMILY               => C_FAMILY,
                 C_INCLUDE_ECC_SUPPORT  => C_INCLUDE_ECC_SUPPORT,
                 NUM_ECC_BITS           => NUM_ECC_BITS,
                 C_NUM_BANKS_MEM        => C_NUM_BANKS_MEM
                 )
    port map (
              Write_data            => write_data,
              Write_data_ecc        => ZERO_ECC_BITS,
              Write_data_en         => write_data_en,
              Wr_up_lo_data_sel     => wr_up_lo_data_sel,
              Write_data_ecc_en     => '0',
              Write_dqs_en          => write_dqs_en,
              Write_dqs_ecc_en      => '0',
              Read_dqs_ce           => read_dqs_ce,
              Write_data_mask       => write_data_mask,
              Write_data_ecc_mask   => WRITE_DATA_ECC_MASK_1,
              Read_data_en          => read_data_en,
              DQ_oe_cmb             => dq_oe_cmb,
              DQ_ECC_oe_cmb         => '0',
              DQS_oe                => dqs_oe,
              DQS_ECC_oe            => '0',
              DQS_rst               => dqs_rst,
              DQS_ECC_rst           => '0',
              DQS_setrst            => dqs_setrst,
              DQS_ECC_setrst        => '0',
              CSn                   => csn,
              RASn                  => rasn,
              CASn                  => casn,
              WEn                   => wen,
              BankAddr              => bankaddr,
              Addr                  => addr,
              DDR_ReadData          => ddr_readdata,
              DDR_ReadData_ECC      => open,
              DDR_read_data_en      => ddr_read_data_en,
              DDR_DQ_i              => DDR_DQ_i,
              DDR_DQ_o              => DDR_DQ_o,
              DDR_DQ_t              => DDR_DQ_t,
              DDR_DM                => DDR_DM,
              DDR_Read_DQS          => ddr_read_dqs,
              DDR_Read_DQS_ECC      => open,
              DDR_DQS_I             => DDR_DQS_i,
              DDR_DQS_o             => DDR_DQS_o,
              DDR_DQS_t             => DDR_DQS_t,
              DDR_DM_ECC            => open,
              DDR_DQ_ECC_o          => open,
              DDR_DQ_ECC_i          => ZERO_DQ_ECC_BITS,
              DDR_DQ_ECC_t          => open,
              DDR_DQS_ECC_i         => '0',
              DDR_DQS_ECC_o         => open,
              DDR_DQS_ECC_t         => open,
              DDR_CSn               => DDR_CSn,
              DDR_RASn              => DDR_RASn,
              DDR_CASn              => DDR_CASn,
              DDR_WEn               => DDR_WEn,
              DDR_BankAddr          => DDR_BankAddr,
              DDR_Addr              => DDR_Addr,
              Clk                   => clk_i,
              Clk_n                 => clk_n_i,
              Clk90                 => clk90_i,
              Clk90_n               => clk90_n_i,
              Clk_ddr_rddata        => clk_ddr_rddata_i,
              Clk_ddr_rddata_n      => clk_ddr_rddata_n_i,
              Rst                   => rst
              );

    IPIC_IF_I : entity ddr_v3_00_a.ipic_if(imp)
    generic map (
                 C_NUM_BANKS_MEM       => C_NUM_BANKS_MEM,
                 C_DDR_AWIDTH          => C_DDR_AWIDTH,
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_DDR_COL_AWIDTH      => C_DDR_COL_AWIDTH,
                 C_DDR_BANK_AWIDTH     => C_DDR_BANK_AWIDTH,
                 C_IPIF_AWIDTH         => C_IPIF_AWIDTH,
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_INCLUDE_BURSTS      => C_INCLUDE_BURSTS,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 NUM_ECC_BITS          => NUM_ECC_BITS
                 )
    port map (
              Bus2IP_CS             => Bus2IP_CS,           -- in
              Bus2IP_Addr           => Bus2IP_Addr,         -- in
              Bus2IP_Burst          => Bus2IP_Burst,        -- in
              Bus2IP_IBurst         => Bus2IP_IBurst,       -- in
              Bus2IP_Data           => Bus2IP_Data ,        -- in
              ECC_chk_bits_wr_in    => ZERO_ECC_BITS,       -- in
              Bus2IP_BE             => Bus2IP_BE,           -- in
              Bus2IP_RdReq          => Bus2IP_RdReq,        -- in
              Bus2IP_WrReq          => Bus2IP_WrReq,        -- in
              IP2Bus_ErrAck         => IP2Bus_ErrAck,       -- out
              IP2Bus_Retry          => IP2Bus_Retry,        -- out
              IP2Bus_Busy           => IP2Bus_Busy,         -- out
              IP2Bus_WrAddrAck      => IP2Bus_WrAddrAck,    -- out
              IP2Bus_RdAddrAck      => IP2Bus_RdAddrAck,    -- out
              IP2Bus_WrAck          => IP2Bus_WrAck,        -- out
              IP2Bus_RdAck          => IP2Bus_RdAck,        -- out
              IP2Bus_ToutSup        => IP2Bus_ToutSup,      -- out
              IP2Bus_data           => IP2Bus_data,         -- out
              ECC_chk_bits_rd_out   => open,                -- out
              Wr_AddrAck            => wr_addrack,          -- in
              Rd_AddrAck            => rd_addrack,          -- in
              WrAck                 => wrack,               -- in
              RdAck                 => rdack,               -- in
              ToutSup               => toutsup,             -- in
              Read_data             => read_data,           -- in
              ECC_chk_bits_rd_in    => ZERO_ECC_BITS,       -- in
              Retry                 => retry,               -- in
              Init_done             => init_done,           -- in
              Comb_Bus2IP_CS        => comb_Bus2IP_CS,      -- out
              IPIC_wrdata           => ipic_wrdata,         -- out
              ECC_chk_bits_wr_out   => open,                -- out
              IPIC_be               => ipic_be,             -- out
              Burst                 => burst,               -- out
              Reset_pendrdreq       => reset_pendrdreq,     -- in
              Reset_pendwrreq       => reset_pendwrreq,     -- in
              Row_addr              => row_addr,            -- out
              Col_addr              => col_addr,            -- out
              Bank_addr             => bank_addr,           -- out
              Pend_rdreq            => pend_rdreq,          -- out
              Pend_wrreq            => pend_wrreq,          -- out
              Same_row              => same_row,            -- out
              Same_bank             => same_bank,           -- out
              Clk                   => clk_i,               -- in
              Rst                   => rst                  -- in
              );

    RDDATA_PATH_I: entity ddr_v3_00_a.read_data_path(imp) 
    generic map (
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_FAMILY              => C_FAMILY,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 C_DDR_CAS_LAT         => open,
                 C_REG_DIMM            => open,
                 NUM_ECC_BITS          => NUM_ECC_BITS
                 )
    port map (
              DDR_ReadData          => ddr_readdata_i,
              DDR_ReadData_ECC      => ZERO_ECC_BITS,
              DDR_ReadDQS           => ddr_read_dqs,
              DDR_ReadDQS_ECC       => '0',
              DDR_read_data_en      => ddr_read_data_en,
              Read_data_en          => read_data_en,
              RdAck_rst             => rdack_rst,
              Read_data             => read_data,
              ECC_chk_bits_rd       => open,
              RdAck                 => rdack,
              FIFO_Rden             => open,
              Rd_addrack            => '0',
              Clk                   => clk_i,
              Clk_ddr_rddata        => clk_ddr_rddata_i,
              Rst                   => Rst
              );

end generate WO_ECC_BUS2XDDR;

-------------------------------------------------------------------------------
-- Name: WO_ECC_BUS1XDDR
-------------------------------------------------------------------------------
-- Description: No ECC logic to be instantiated/supported when 
--              C_IPIF_DWIDTH/C_DDR_DWIDTH=1, when C_INCLUDE_ECC_SUPPORT = 0
--              and C_IPIF_DWIDTH/C_DDR_DWIDTH = 1. This will generate the
--              design when bus data width is equal to the DDR data width.
-------------------------------------------------------------------------------

WO_ECC_BUS1XDDR: if C_INCLUDE_ECC_SUPPORT = 0  and 
                    C_IPIF_DWIDTH/C_DDR_DWIDTH = 1 generate

constant ZERO_ECC_BITS         : std_logic_vector(0 to NUM_ECC_BITS*2-1)
                                := (others => '0');
constant ZERO_DQ_ECC_BITS      : std_logic_vector(0 to NUM_ECC_BITS-1)
                                := (others => '0');
constant WRITE_DATA_ECC_MASK_1 : std_logic_vector(0 to 2*C_DDR_DWIDTH/32-1)
                                := (others => '1');

constant DATA_MASK_ONES  : std_logic_vector(0 to ((C_IPIF_DWIDTH/8)-1))
                           := (others => '1');
constant WRITE_DATA_ONES  : std_logic_vector(0 to (C_IPIF_DWIDTH-1))
                           := (others => '1');

signal  ipic_wr_data_64    : std_logic_vector(0 to C_DDR_DWIDTH*2-1);
signal  write_data         : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal  write_data_mask    : std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
signal  ddr_readdata       : std_logic_vector(0 to 2*C_DDR_DWIDTH-1);
signal  mw_data_mask       : std_logic_vector(0 to C_DDR_DWIDTH*2/8-1);
signal  data_fifo_rden     : std_logic;
signal  read_data          : std_logic_vector(0 to C_DDR_DWIDTH-1);

begin
    ipic_wr_data_64 <= write_data & write_data;--ipic_wrdata ;
    mw_data_mask    <= write_data_mask & DATA_MASK_ONES;


    COMMAND_STATEMACHINE_I : entity ddr_v3_00_a.command_statemachine(imp)
    generic map (
                 C_DDR_AWIDTH               => C_DDR_AWIDTH,
                 C_DDR_DWIDTH               => C_DDR_DWIDTH,
                 C_DDR_COL_AWIDTH           => C_DDR_COL_AWIDTH,
                 C_DDR_BANK_AWIDTH          => C_DDR_BANK_AWIDTH,
                 C_REG_DIMM                 => C_REG_DIMM,
                 C_MRDCNT                   => MRDCNT,
                 C_RFCCNT                   => RFCCNT,
                 C_RCDCNT                   => RCDCNT,
                 C_RPCNT                    => RPCNT,
                 C_GP_CNTR_WIDTH            => GPCNT_WIDTH,
                 C_OPB_BUS                  => C_OPB_BUS,
                 C_PLB_BUS                  => C_PLB_BUS,
                 C_INCLUDE_BURSTS           => C_INCLUDE_BURSTS,
                 C_INCLUDE_ECC_SUPPORT      => C_INCLUDE_ECC_SUPPORT,
                 C_NUM_BANKS_MEM            => C_NUM_BANKS_MEM
                 )
    port map (
              Comb_Bus2IP_CS       => comb_Bus2IP_CS,
              Bus2IP_CS            => Bus2IP_CS,
              Row_addr             => row_addr,
              Col_addr             => col_addr,
              Bank_addr            => bank_addr,
              Bus2IP_RdReq         => Bus2IP_RdReq,
              Bus2IP_WrReq         => Bus2IP_WrReq,
              Pend_rdreq           => pend_rdreq,
              Pend_wrreq           => pend_wrreq,
              Same_row             => same_row,
              Same_bank            => same_bank,
              Read_dqs_ce          => read_dqs_ce,
              Retry                => retry,
              Rd_AddrAck           => rd_addrack,
              Wr_AddrAck           => wr_addrack,
              Reset_pendrdreq      => reset_pendrdreq,
              Reset_pendwrreq      => reset_pendwrreq,
              ToutSup              => toutsup,
              Refresh              => refresh,
              Precharge            => precharge,
              Load_mr              => load_mr,
              Register_data        => register_data,
              Register_sel         => register_sel,
              Init_done            => init_done,
              Cmd_done             => cmd_done, 
              Read_data_done       => read_data_done,
              Read_data_done_rst   => read_data_done_rst,
              Pend_write           => pend_write,        -- out
              Pend_read            => pend_read,         -- out
              Read_pause           => read_pause,        -- out
              Trefi_end            => trefi_pwrup_end,   -- in
              Trc_end              => trc_end,           -- in
              Trrd_end             => trrd_end,          -- in
              Tras_end             => tras_end,          -- in
              Twr_end              => twr_end,           -- in
              GPcnt_end            => gpcnt_end,         -- in
              Tcmd_end             => tcmd_end,          -- in
              Twr_rst              => twr_rst,           -- out
              Tcmd_load            => tcmd_load,         -- out
              Tcmd_cnt_en          => tcmd_cnt_en,       -- out
              Trefi_load           => trefi_load,        -- out
              Trc_load             => trc_load,          -- out
              Trrd_load            => trrd_load,         -- out
              Tras_load            => tras_load,         -- out
              GPcnt_load           => gpcnt_load,        -- out
              GPcnt_en             => gpcnt_en,          -- out
              GPcnt_data           => gpcnt_data,        -- out 
              DDR_CSn              => csn,               -- out 
              DDR_RASn             => rasn,              -- out
              DDR_CASn             => casn,              -- out
              DDR_WEn              => wen,               -- out
              DDR_Addr             => addr,              -- out 
              DDR_BankAddr         => bankaddr,          -- out 
              DQ_oe_cmb            => dq_oe_cmb,         -- out
              DQS_oe               => dqs_oe,            -- out
              DQS_rst              => dqs_rst,           -- out
              DQS_setrst           => dqs_setrst,        -- out
              DQ_ECC_oe_cmb        => open,              -- out
              DQS_ECC_oe           => open,              -- out
              DQS_ECC_rst          => open,              -- out
              DQS_ECC_setrst       => open,              -- out
              Clk                  => clk_i,             -- in
              Clk90                => clk90_i,           -- in
              Rst                  => rst                -- in
              );


    DATASM_I: entity ddr_v3_00_a.data_statemachine(imp) 
        generic map ( 
                     C_DDR_DWIDTH          => C_DDR_DWIDTH,
                     C_IPIF_DWIDTH         => C_DDR_DWIDTH,
                     C_REG_DIMM            => C_REG_DIMM,
                     C_INCLUDE_BURSTS      => C_INCLUDE_BURSTS,
                     C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                     NUM_ECC_BITS          => NUM_ECC_BITS
                     )
        port map (
                  IPIC_wrdata           =>  IPIC_wrdata,
                  ECC_chk_bits_wr       =>  ZERO_ECC_BITS,
                  IPIC_be               =>  ipic_be,
                  Bus2IP_Burst          =>  burst,
                  Comb_Bus2IP_CS        =>  comb_Bus2IP_CS,
                  Pend_write            =>  pend_write,
                  Pend_read             =>  pend_read,
                  DDR_brst_end          =>  ddr_brst_end,
                  Tcaslat_end           =>  tcaslat_end,
                  Twr_end               =>  twr_end,
                  Read_data_done_rst    =>  read_data_done_rst,
                  Read_pause            =>  read_pause,
                  RdAck                 =>  rdack,
                  WrAck                 =>  WrAck,
                  Read_data_en          =>  read_data_en,
                  Write_data_en         =>  write_data_en,
                  Wr_up_lo_data_sel     =>  wr_up_lo_data_sel,
                  Write_data_ecc_en     =>  open,
                  Write_dqs_en          =>  write_dqs_en,
                  Write_dqs_ecc_en      =>  open,
                  Write_data            =>  write_data,
                  Write_data_ecc        =>  open,
                  Write_data_mask       =>  write_data_mask,
                  Write_data_ecc_mask   =>  open,
                  Read_data_done        =>  read_data_done,
                  Tbrst_cnt_en          =>  tbrst_cnt_en,
                  Tbrst_load            =>  tbrst_load,
                  Tcaslat_load          =>  tcaslat_load,
                  Tcaslat_cnt_en        =>  tcaslat_cnt_en,
                  Twr_load              =>  twr_load,
                  Twr_cnten             =>  twr_cnten,
                  RdAck_rst             =>  rdack_rst,
                  Clk                   =>  clk_i,
                  Clk90                 =>  clk90_i,
                  Rst                   =>  Rst
                  );


    IO_REG_I: entity ddr_v3_00_a.io_registers(imp)
      generic map ( 
                   C_EXTRA_TSU           => C_EXTRA_TSU,
                   C_DDR_AWIDTH          => C_DDR_AWIDTH,
                   C_DDR_BANK_AWIDTH     => C_DDR_BANK_AWIDTH,
                   C_DDR_DWIDTH          => C_DDR_DWIDTH,
                   C_IPIF_DWIDTH         => C_DDR_DWIDTH*2,
                   C_FAMILY              => C_FAMILY,
                   C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                   NUM_ECC_BITS          => NUM_ECC_BITS,
                   C_NUM_BANKS_MEM       => C_NUM_BANKS_MEM
                   )
      port map (
                Write_data            => ipic_wr_data_64,
                Write_data_ecc        => ZERO_ECC_BITS,
                Write_data_en         => write_data_en,
                Wr_up_lo_data_sel     => wr_up_lo_data_sel,
                Write_data_ecc_en     => '0',
                Write_dqs_en          => write_dqs_en,
                Write_dqs_ecc_en      => '0',
                Read_dqs_ce           => read_dqs_ce,
                Write_data_mask       => mw_data_mask,
                Write_data_ecc_mask   => WRITE_DATA_ECC_MASK_1,
                Read_data_en          => read_data_en,
                DQ_oe_cmb             => dq_oe_cmb,
                DQ_ECC_oe_cmb         => '0',
                DQS_oe                => dqs_oe,
                DQS_ECC_oe            => '0',
                DQS_rst               => dqs_rst,
                DQS_ECC_rst           => '0',
                DQS_setrst            => dqs_setrst,
                DQS_ECC_setrst        => '0',
                CSn                   => csn,
                RASn                  => rasn,
                CASn                  => casn,
                WEn                   => wen,
                BankAddr              => bankaddr,
                Addr                  => addr,
                DDR_ReadData          => ddr_readdata,
                DDR_ReadData_ECC      => open,
                DDR_read_data_en      => ddr_read_data_en,
                DDR_DQ_i              => DDR_DQ_i,
                DDR_DQ_o              => DDR_DQ_o,
                DDR_DQ_t              => DDR_DQ_t,
                DDR_DM                => DDR_DM,
                DDR_Read_DQS          => ddr_read_dqs,
                DDR_Read_DQS_ECC      => open,
                DDR_DQS_I             => DDR_DQS_i,
                DDR_DQS_o             => DDR_DQS_o,
                DDR_DQS_t             => DDR_DQS_t,
                DDR_DM_ECC            => open,
                DDR_DQ_ECC_o          => open,
                DDR_DQ_ECC_i          => ZERO_DQ_ECC_BITS,
                DDR_DQ_ECC_t          => open,
                DDR_DQS_ECC_i         => '0',
                DDR_DQS_ECC_o         => open,
                DDR_DQS_ECC_t         => open,
                DDR_CSn               => DDR_CSn,
                DDR_RASn              => DDR_RASn,
                DDR_CASn              => DDR_CASn,
                DDR_WEn               => DDR_WEn,
                DDR_BankAddr          => DDR_BankAddr,
                DDR_Addr              => DDR_Addr,
                Clk                   => clk_i,
                Clk_n                 => clk_n_i,
                Clk90                 => clk90_i,
                Clk90_n               => clk90_n_i,
                Clk_ddr_rddata        => clk_ddr_rddata_i,
                Clk_ddr_rddata_n      => clk_ddr_rddata_n_i,
                Rst                   => rst
                );

    IPIC_IF_I : entity ddr_v3_00_a.ipic_if(imp)
      generic map (
                   C_NUM_BANKS_MEM       => C_NUM_BANKS_MEM,
                   C_DDR_AWIDTH          => C_DDR_AWIDTH,
                   C_DDR_DWIDTH          => C_DDR_DWIDTH,
                   C_DDR_COL_AWIDTH      => C_DDR_COL_AWIDTH,
                   C_DDR_BANK_AWIDTH     => C_DDR_BANK_AWIDTH,
                   C_IPIF_AWIDTH         => C_IPIF_AWIDTH,
                   C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                   C_INCLUDE_BURSTS      => C_INCLUDE_BURSTS,
                   C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                   NUM_ECC_BITS          => NUM_ECC_BITS
                   )
      port map (
                Bus2IP_CS           => Bus2IP_CS,           -- in
                Bus2IP_Addr         => Bus2IP_Addr,         -- in
                Bus2IP_Burst        => Bus2IP_Burst,        -- in
                Bus2IP_IBurst       => Bus2IP_IBurst,       -- in
                Bus2IP_Data         => Bus2IP_Data,         -- in
                ECC_chk_bits_wr_in  => ZERO_ECC_BITS,       -- in
                Bus2IP_BE           => Bus2IP_BE,           -- in
                Bus2IP_RdReq        => Bus2IP_RdReq,        -- in
                Bus2IP_WrReq        => Bus2IP_WrReq,        -- in
                IP2Bus_ErrAck       => IP2Bus_ErrAck,       -- out
                IP2Bus_Retry        => IP2Bus_Retry,        -- out
                IP2Bus_Busy         => IP2Bus_Busy,         -- out
                IP2Bus_WrAddrAck    => IP2Bus_WrAddrAck,    -- out
                IP2Bus_RdAddrAck    => IP2Bus_RdAddrAck,    -- out
                IP2Bus_WrAck        => IP2Bus_WrAck,        -- out
                IP2Bus_RdAck        => IP2Bus_RdAck,        -- out
                IP2Bus_ToutSup      => IP2Bus_ToutSup,      -- out
                IP2Bus_data         => IP2Bus_data,         -- out
                ECC_chk_bits_rd_out => open,                -- out
                Wr_AddrAck          => wr_addrack,          -- in
                Rd_AddrAck          => rd_addrack,          -- in
                WrAck               => wrack,               -- in
                RdAck               => rdack,               -- in
                ToutSup             => toutsup,             -- in
                Read_data           => read_data,           -- in
                ECC_chk_bits_rd_in  => ZERO_ECC_BITS,       -- in
                Retry               => retry,               -- in
                Init_done           => init_done,           -- in
                Comb_Bus2IP_CS      => comb_Bus2IP_CS,      -- out
                IPIC_wrdata         => ipic_wrdata,         -- out
                ECC_chk_bits_wr_out => open,                -- out
                IPIC_be             => ipic_be,             -- out
                Burst               => burst,               -- out
                Reset_pendrdreq     => reset_pendrdreq,     -- in
                Reset_pendwrreq     => reset_pendwrreq,     -- in
                Row_addr            => row_addr,            -- out
                Col_addr            => col_addr,            -- out
                Bank_addr           => bank_addr,           -- out
                Pend_rdreq          => pend_rdreq,          -- out
                Pend_wrreq          => pend_wrreq,          -- out
                Same_row            => same_row,            -- out
                Same_bank           => same_bank,           -- out
                Clk                 => clk_i,               -- in
                Rst                 => rst                  -- in
                );

    RDDATA_PATH_I: entity ddr_v3_00_a.read_data_path(imp) 
    generic map (
                 C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                 C_DDR_DWIDTH          => C_DDR_DWIDTH,
                 C_FAMILY              => C_FAMILY,
                 C_INCLUDE_ECC_SUPPORT => C_INCLUDE_ECC_SUPPORT,
                 NUM_ECC_BITS          => NUM_ECC_BITS
                 )
    port map (
              DDR_ReadData      =>  ddr_readdata,
              DDR_ReadData_ECC  =>  ZERO_ECC_BITS,
              DDR_ReadDQS       =>  ddr_read_dqs,
              DDR_ReadDQS_ECC   =>  '0',
              DDR_read_data_en  =>  ddr_read_data_en,
              Read_data_en      =>  read_data_en,
              RdAck_rst         =>  rdack_rst,
              Read_data         =>  read_data,
              ECC_chk_bits_rd   =>  open,
              RdAck             =>  rdack,
              FIFO_Rden         =>  data_fifo_rden,
              Rd_addrack        => '0',
              Clk               =>  clk_i,
              Clk_ddr_rddata    =>  clk_ddr_rddata_i,
              Rst               =>  Rst
              );

end generate WO_ECC_BUS1XDDR;

end imp;

-------------------------------------------------------------------------------
-- End of file ddr_controller.vhd
-------------------------------------------------------------------------------