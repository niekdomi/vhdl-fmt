-------------------------------------------------------------------------------
--  $Id: arb_registers.vhd,v 1.2 2004/11/23 01:15:02 jcanaris Exp $
-------------------------------------------------------------------------------
-- arb_registers.vhd - entity/architecture pair
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
-- Filename:        arb_registers.vhd
-- Version:         v1.01a
-- Description:     This file contains the registers which maintain the state
--                  of the PLB such as read data bus busy, write data bus
--                  busy, secondary read/write in progress, primary read
--                  master, etc.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--          plb_v34.vhd
--              --  plb_addrpath.vhd
--                  --  mux_onehot_imp.vhd
--
--              --  plb_rd_datapath.vhd
--
--              --  plb_wr_datapath.vhd
--                  --  mux_onehot_imp.vhd
--
--              --  plb_slave_ors.vhd
--
--              --  plb_arbiter_logic.vhd
--                  --  muxed_signals.vhd
--                      --  mux_onehot_imp.vhd
--                      --  or_bits.vhd
--
--                  --  arb_control_sm.vhd
--
--                  --  arb_registers.vhd
--                      --  bus_controlvhd
--
--                  --  plb_priority_encoder.vhd
--                      --  priority_encoder.vhd
--                          --  qual_request.vhd
--                      --  arb_addr_sel.vhd
--                      --  mux_onehot_imp.vhd
--                      --  pend_request.vhd
--                      --  pending_priority.vhd
--                          --  qual_priority.vhd
--
--                  --  gen_qual_req.vhd
--
--                  --  buslocksm.vhd
--
--                  --  watchdog_timer.vhd
--                      --  down_counter.vhd
--
--                  --  dcr_regs.vhd
--
--                  --  plb_interrupt.vhd
--
-------------------------------------------------------------------------------
-- Author:      BLT
-- History:
--      ALS     02/20/02        -- created from plb_arbiter_v1_01_a
--      ALS     04/16/02        -- Version v1.01a
--  LCW	Oct 15, 2004	  -- updated for NCSim
---------------------------------------------------------------------------------
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

-- PROC_COMMON_PKG contains the constant RESET_ACTIVE
library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

library unisim;
use unisim.vcomponents.all;

library plb_v34_v1_02_a;
use plb_v34_v1_02_a.bus_control;




-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--
-- Definition of Ports:
--      -- register load signals
--      input  LoadDisReg
--      input  LoadPriRd
--      input  LoadPriWr
--      input  LoadSecRd
--      input  LoadSecRdPriReg
--      input  LoadSecWr
--      input  LoadSecWrPriReg
--
--      -- PLB signals
--      input  PLB_reqPri           -- current priority of active transaction
--      input  Sl_rdComp            -- slave read complete
--      input  Sl_wrComp            -- slave write complete
--      input  WdtRdComp            -- watchdog timer read complete
--      input  WdtWrComp            -- watchdog timer write complete
--
--      -- control signals
--      input  RecomputeRdBits      -- transitions read bus control SM
--      input  RecomputeWrBits      -- transitions write bus control SM
--
--      -- arbiter signals
--      input  ArbAddrSelReg        -- master currently controlling the PLB
--      input  ArbBurstReq          -- current transaction burst status
--      input  ArbDisMReqRegIn      -- input to the disable master request reg
--
--      -- clock and reset
--      input  Clk
--      input  ArbReset
--
--      output ArbDisMReqReg        -- disabled masters
--      output ArbPriRdBurstReg     -- primary read transaction burst status
--      output ArbPriRdMasterReg    -- primary read transaction master
--      output ArbPriRdMasterRegReg -- primary read transaction master, delayed
--      output ArbPriWrMasterReg    -- primary write transaction master
--      output ArbRdDBusBusyReg     -- status of read data bus
--      output ArbSecRdInProgPriorReg -- priority of secondary read transaction
--      output ArbSecRdInProgReg    -- status of secondary read
--      output ArbSecRdMasterReg    -- secondary read transaction master
--      output ArbSecWrInProgPriorReg -- priority of secondary write transaction
--      output ArbSecWrInProgReg    -- status of secondary write
--      output ArbSecWrMasterReg    -- secondary write transaction master
--      output ArbWrDBusBusyReg     -- status of write data bus
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity arb_registers is
  generic (C_NUM_MASTERS        : integer := 8);
  port (
        LoadDisReg              : in std_logic;
        LoadPriRd               : in std_logic;
        LoadPriWr               : in std_logic;
        LoadSecRd               : in std_logic;
        LoadSecRdPriReg         : in std_logic;
        LoadSecWr               : in std_logic;
        LoadSecWrPriReg         : in std_logic;
        PLB_reqPri              : in std_logic_vector(0 to 1);
        RecomputeRdBits         : in std_logic;
        RecomputeWrBits         : in std_logic;
        Sl_rdComp               : in std_logic;
        Sl_wrComp               : in std_logic;
        ArbAddrSelReg           : in std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbBurstReq             : in std_logic;
        ArbDisMReqReg           : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbDisMReqRegIn         : in std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbPriRdBurstReg        : out std_logic;
        ArbPriRdMasterReg       : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbPriRdMasterRegReg    : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbPriWrMasterReg       : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbRdDBusBusyReg        : out std_logic;
        ArbSecRdInProgPriorReg  : out std_logic_vector(0 to 1);
        ArbSecRdInProgReg       : out std_logic;
        ArbSecRdMasterReg       : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbSecWrInProgPriorReg  : out std_logic_vector(0 to 1);
        ArbSecWrInProgReg       : out std_logic;
        ArbSecWrMasterReg       : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbWrDBusBusyReg        : out std_logic;
        WdtRdComp               : in std_logic;
        WdtWrComp               : in std_logic;
        Clk                     : in std_logic;
        ArbReset                : in std_logic
        );
end arb_registers;


-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of arb_registers is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

-- define internal versions of output signals

  signal arbPriRdMasterReg_i    : std_logic_vector(0 to C_NUM_MASTERS-1 );
  signal arbRdDBusBusyReg_i     : std_logic;
  signal arbSecRdInProgReg_i    : std_logic;
  signal arbSecRdMasterReg_i    : std_logic_vector(0 to C_NUM_MASTERS-1 );
  signal arbSecWrInProgReg_i    : std_logic;
  signal arbSecWrMasterReg_i    : std_logic_vector(0 to C_NUM_MASTERS-1 );
  signal arbWrDBusBusyReg_i     : std_logic;

-- internal register and register control signals
  signal priRdBurstEn           : std_logic;
  signal priRdEn                : std_logic;
  signal priWrEn                : std_logic;
  signal promoteRead            : std_logic;
  signal promoteWrite           : std_logic;
  signal arbPriRdBurstIn        : std_logic;
  signal arbPriRdMasterIn       : std_logic_vector(0 to C_NUM_MASTERS-1 );
  signal arbPriWrBurstIn        : std_logic;
  signal arbPriWrMasterIn       : std_logic_vector(0 to C_NUM_MASTERS-1 );
  signal arbSecRdBurstReg       : std_logic;
  signal arbSecWrBurstReg       : std_logic;

  signal priInRd                : std_logic ;
  signal secInRd                : std_logic ;
  signal priInWr                : std_logic ;
  signal secInWr                : std_logic ;


-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- bus_control is a simple state machine which maintains the state of primary
-- and secondary transactions based on the current state of the PLB, control
-- signals from the arb_control_sm, and whether transactions have completed

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- Signal assignments
-------------------------------------------------------------------------------
-- assign outputs to internal versions
arbSecWrInProgReg     <= arbSecWrInProgReg_i;
arbRdDBusBusyReg      <= arbRdDBusBusyReg_i;
arbPriRdMasterReg     <= arbPriRdMasterReg_i;
arbSecRdInProgReg     <= arbSecRdInProgReg_i;
arbWrDBusBusyReg      <= arbWrDBusBusyReg_i;
arbSecWrMasterReg     <= arbSecWrMasterReg_i;
arbSecRdMasterReg     <= arbSecRdMasterReg_i;

-- assign register enable signals
priWrEn         <= LoadPriWr or promoteWrite;
priRdEn         <= LoadPriRd or promoteRead;
priRdBurstEn    <= LoadPriRd or promoteRead;

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- bus_control is a simple state machine which maintains the state of primary
-- and secondary transactions based on the current state of the PLB, control
-- signals from the arb_control_sm, and whether transactions have completed

 I_RD_BUSCTRL: entity plb_v34_v1_02_a.bus_control
    port map (
              XComp => Sl_rdComp,
              wdtComp => wdtRdComp,
              PriReg => arbRdDBusBusyReg_i,
              SecReg => arbSecRdInProgReg_i,
              Recompute => RecomputeRdBits,
              PriIn => priInRd,
              SecIn => secInRd,
              Promote => promoteRead);

 I_WR_BUSCTRL: entity plb_v34_v1_02_a.bus_control
    port map (
              XComp => Sl_wrComp,
              wdtComp => wdtWrComp,
              PriReg => arbWrDBusBusyReg_i,
              SecReg => arbSecWrInProgReg_i,
              Recompute => RecomputeWrBits,
              PriIn => priInWr,
              SecIn => secInWr,
              Promote => promoteWrite);

-------------------------------------------------------------------------------
-- Register Processes
-------------------------------------------------------------------------------
-- The following processes define the various registers which maintain the
-- state of the PLB.


PRI_RDMSTR_REG:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbPriRdMasterReg_i <= (others => '0');
        else
            if (priRdEn)='1' then
                arbPriRdMasterReg_i <= arbPriRdMasterIn;
            end if ;
        end if ;
    end if;
end process PRI_RDMSTR_REG;


PRI_RDMSTR_REGREG:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbPriRdMasterRegReg <= (others => '0');
        else
            arbPriRdMasterRegReg <= arbPriRdMasterReg_i;
        end if ;
    end if;
end process ;


SEC_RDMSTR_REG:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbSecRdMasterReg_i <= (others => '0');
        else
            if (LoadSecRd)='1' then
                arbSecRdMasterReg_i <= arbAddrSelReg;
            end if ;
        end if ;
    end if;
end process SEC_RDMSTR_REG;


RD_DBUSBUSY_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbRdDBusBusyReg_i <= '0';
        else
            arbRdDBusBusyReg_i <= priInRd;
        end if ;
    end if;
end process RD_DBUSBUSY_PROCESS;


SEC_RDINPROGREG_PROCESS:  process (Clk)
begin
    if  (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbSecRdInProgReg_i <= '0';
        else
            arbSecRdInProgReg_i <= secInRd;
        end if ;
    end if;
end process SEC_RDINPROGREG_PROCESS;


PRI_WRMSTRREG_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbPriWrMasterReg <= (others => '0');
        else
            if (priWrEn)='1' then
                arbPriWrMasterReg <= arbPriWrMasterIn;
            end if ;
        end if ;
    end if;
end process PRI_WRMSTRREG_PROCESS;


SEC_WRMSTRREG_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbSecWrMasterReg_i <= (others => '0');
        else
            if (LoadSecWr)='1' then
                arbSecWrMasterReg_i <= arbAddrSelReg;
            end if ;
        end if ;
    end if;
end process SEC_WRMSTRREG_PROCESS;


WR_DBUS_BUSYREG:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbWrDBusBusyReg_i <= '0';
        else
            arbWrDBusBusyReg_i <= priInWr;
        end if ;
    end if;
end process WR_DBUS_BUSYREG;


SEC_WRINPROG_REG_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbSecWrInProgReg_i <= '0';
        else
            arbSecWrInProgReg_i <= secInWr;
        end if ;
    end if;
end process SEC_WRINPROG_REG_PROCESS;


DIS_REQREG_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbDisMReqReg <= (others => '0');
        else
            if (LoadDisReg)='1' then
                arbDisMReqReg <= arbDisMReqRegIn;
            end if ;
        end if ;
    end if;
end process ;


PRI_RDMSTRIN_PROCESS:  process (promoteRead, arbAddrSelReg, arbSecRdMasterReg_i)
begin
    case promoteRead is
      when '0' =>
        arbPriRdMasterIn <= arbAddrSelReg;
      when others  =>
        arbPriRdMasterIn <= arbSecRdMasterReg_i;
    end case  ;
end process ;


PRI_WRMSTRIN_PROCESS:  process (promoteWrite, arbAddrSelReg, arbSecWrMasterReg_i)
begin
    case promoteWrite is
      when '0' =>
        arbPriWrMasterIn <= arbAddrSelReg;
      when others  =>
        arbPriWrMasterIn <= arbSecWrMasterReg_i;
    end case  ;
end process ;


SEC_RDPRIORREG_PROCESS:  process (Clk)
begin
    if  (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbSecRdInProgPriorReg <= (others => '0');
        else
            if (LoadSecRdPriReg)='1' then
                arbSecRdInProgPriorReg <= PLB_reqPri;
            end if ;
        end if ;
    end if;
end process SEC_RDPRIORREG_PROCESS;


SEC_WRPRIORREG_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            arbSecWrInProgPriorReg <= (others => '0');
        else
            if (LoadSecWrPriReg)='1' then
                arbSecWrInProgPriorReg <= PLB_reqPri;
            end if ;
        end if ;
    end if;
end process SEC_WRPRIORREG_PROCESS;


PRI_RDBURSTIN_PROCESS:  process (promoteRead, arbBurstReq, arbSecRdBurstReg)
begin
    case promoteRead is
      when '0' =>
        arbPriRdBurstIn <= arbBurstReq;
      when others  =>
        arbPriRdBurstIn <= arbSecRdBurstReg;
    end case  ;
end process PRI_RDBURSTIN_PROCESS;

PRI_RDBURSTREG_PROCESS:  process (Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            ArbPriRdBurstReg <= '0';
        else
            if (priRdBurstEn)='1' then
                ArbPriRdBurstReg <= arbPriRdBurstIn;
            end if ;
        end if ;
    end if;
end process PRI_RDBURSTREG_PROCESS;


SEC_RDBURSTREG_PROCESS:  process(Clk)
begin
    if (Clk'event and Clk = '1' ) then
        if (ArbReset = RESET_ACTIVE) then
            ArbSecRdBurstReg <= '0';
        else
            if (LoadSecRd)='1' then
                ArbSecRdBurstReg <= ArbBurstReq;
            end if ;
        end if ;
    end if;
end process SEC_RDBURSTREG_PROCESS;



end simulation;

