-------------------------------------------------------------------------------
--  $Id: arb_control_sm.vhd,v 1.2 2004/05/21 18:48:30 mlovejoy Exp $
-------------------------------------------------------------------------------
-- arb_control_sm.vhd - entity/architecture pair
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
-- Filename:        arb_control_sm.vhd
-- Version:         v1.01a
-- Description:     This file contains the arbiter control state machine which
--                  controls the PLB bus. It asserts PAValid and SAValid at
--                  the appropriate times and generates the bus state signals
--                  for arb_registers.
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
-- ^^^^^^
--  MLL         02/20/04        -- Version v1.01a
-- ^^^^^^
--  Fix to make compatible with OPB IPIF architecture. In arb_control_sm.vhd,
--  added counter to block clearing of mask in arbitration if plb2opb bridge
--  asserts rearbitrate on a read operation. This required adding
--  C_NUM_OPBCLK_PLB2OPB_REARB generic and PLB2OPB_rearb vector signal at this
--  level and passed down to arb_control_sm.vhd. Also rev'd to v2.00a.
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
 
-- PROC_COMMON_PKG contains the RESET_ACTIVE constant
library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--
-- Definition of Ports:
--      input  AAck                 -- slave address ack
--      input  Abort                -- PLB abort
--      input  ArbAddrSelReg        -- master controlling bus
--      input  ArbRdDBusBusyReg     -- read data bus busy
--      input  ArbWrDBusBusyReg     -- write data bus busy
--      input  ArbSecRdInProgReg    -- secondary read in progress
--      input  ArbSecWrInProgReg    -- secondary write in progress
--      input  SM_busLock           -- PLB buslock condition
--      input  PLB_busLock          -- PLB buslock signal
--      input  Clk                  -- clock
--      input  QualReq              -- =1 if any master has a qualified request
--      input  Read                 -- PLB_RNW
--      input  Rearbitrate          -- slave re-arbitrate 
--      input  Reset                -- reset
--      input  Sl_rdComp            -- slave read complete
--      input  Sl_wrComp            -- slave write complete
--      input  WdtAAck              -- watchdog timer address ack
--      input  WdtRdComp            -- watchdog timer read complete
--      input  WdtWrComp            -- watchdog timer write complete
--
--      output Set_disables_state   -- indicates state machine is in this state
--      output DisMnReqIn           -- disable master requests - one-hot bus
--      output LoadDisReg           -- load disable master request register
--      output LoadPriRd            -- load primary read master register
--      output LoadPriWr            -- load primary write master register
--      output LoadSecRd            -- load secondary read master register
--      output LoadSecRdPriReg      -- load secondary read priority register
--      output LoadSecWr            -- load secondary write master register
--      output LoadSecWrPriReg      -- load secondary write priority register
--      output LoadAddrSelReg       -- load priority encoder output into register
--      output PAValid              -- primary address valid
--      output RecomputeRdBits      -- transitions read bus control SM
--      output RecomputeWrBits      -- transitions write bus control SM
--      output SAValid              -- secondary address valid
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity arb_control_sm is
  generic (C_NUM_MASTERS    : integer   := 8;
           C_NUM_PLB2OPB_BRIDGE: integer;
           C_NUM_OPBCLK_PLB2OPB_REARB : integer);
  port (
        AAck                : in std_logic;
        Abort               : in std_logic;
        ArbAddrSelReg       : in std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbRdDBusBusyReg    : in std_logic;
        ArbWrDBusBusyReg    : in std_logic;
        ArbSecRdInProgReg   : in std_logic;
        ArbSecWrInProgReg   : in std_logic;
        SM_busLock          : in std_logic;
        PLB_busLock         : in std_logic;
        Clk                 : in std_logic;
        QualReq             : in std_logic;
        Read                : in std_logic;
        Rearbitrate         : in std_logic;
        Rst                 : in std_logic;
        Sl_rdComp           : in std_logic;
        Sl_wrComp           : in std_logic;
        WdtAAck             : in std_logic;
        WdtRdComp           : in std_logic;
        WdtWrComp           : in std_logic;
        Set_disables_state  : out std_logic;
        DisMnReqIn          : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        LoadDisReg          : out std_logic;
        LoadPriRd           : out std_logic;
        LoadPriWr           : out std_logic;
        LoadSecRd           : out std_logic;
        LoadSecRdPriReg     : out std_logic;
        LoadSecWr           : out std_logic;
        LoadSecWrPriReg     : out std_logic;
        LoadAddrSelReg      : out std_logic;
        PAValid             : out std_logic;
        RecomputeRdBits     : out std_logic;
        RecomputeWrBits     : out std_logic;
        SAValid             : out std_logic;
          --Fix to make compatible with OPB IPIF architecture
        PLB2OPB_rearb       : in std_logic_vector(0 to C_NUM_PLB2OPB_BRIDGE-1)
        );
end arb_control_sm;
 
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of arb_control_sm is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- define one-hot constants for the state machine states
constant IDLE               : std_logic_vector(7 downto 0) := "00000001";
constant BUSLOCK_STATE      : std_logic_vector(7 downto 0) := "00000010";
constant DISABLE            : std_logic_vector(7 downto 0) := "00000100";
constant MASTERSEL1         : std_logic_vector(7 downto 0) := "00001000";
constant READSTATE          : std_logic_vector(7 downto 0) := "00010000";
constant RELEASE_DISABLES   : std_logic_vector(7 downto 0) := "00100000";
constant SET_DISABLES       : std_logic_vector(7 downto 0) := "01000000";
constant WRITESTATE         : std_logic_vector(7 downto 0) := "10000000";

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- state machine signals
signal arbctrl_sm_cs, arbctrl_sm_ns : std_logic_vector(7 downto 0 );

-- combinational versions of PAValid and SAValid 
signal pavalid_cmb : std_logic;
signal savalid_cmb : std_logic;
   --Fix to make compatible with OPB IPIF architecture
signal PLB2OPB_rearb_or : std_logic;
signal PLB2OPB_rearb_or_vector: std_logic_vector(0 to PLB2OPB_rearb'length-1);
signal Set_Cnt_on_plb2opb_rearb_en: std_logic;
signal Clear_Cnt_on_plb2opb_rearb_en: std_logic;
signal Cnt_on_plb2opb_rearb_en: std_logic;

signal Cnt_on_plb2opb_rearb: integer range 0 to C_NUM_OPBCLK_PLB2OPB_REARB+1;

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------
-- Output state condition
-------------------------------------------------------------------------------
Set_disables_state  <= '1' when arbctrl_sm_cs = SET_DISABLES
                        else '0';
                        
-------------------------------------------------------------------------------
-- Arbiter Control State Machine
--
-- ARBCTRL_SM_CMB_PROCESS:      combinational next-state logic
-- ARBCTRL_SM_REGS_PROCESS:     registered process of the state machine
-------------------------------------------------------------------------------
-- These processes control the bus transactions and state of the PLB

ARBCTRL_SM_CMB_PROCESS: process (QualReq, SM_busLock, Cnt_on_plb2opb_rearb,
                                PLB_busLock, Abort, 
                                arbRdDBusBusyReg, arbSecRdInProgReg, 
                                arbWrDBusBusyReg, arbSecWrInProgReg, 
                                arbAddrSelReg, Read, 
                                Sl_rdComp, wdtRdComp, AAck, wdtAAck, 
                                Rearbitrate, PLB2OPB_rearb_or, Sl_wrComp,
                                wdtWrComp, arbctrl_sm_cs)
                                
begin

-- assign default values for state machine outputs

DisMnReqIn <= (others => '0');
LoadDisReg <= '0';    
LoadPriRd <= '0';
LoadPriWr <= '0';    
LoadSecRd <= '0';    
LoadSecRdPriReg <= '0';    
LoadSecWr <= '0';    
LoadSecWrPriReg <= '0';    
loadAddrSelReg <= '0';    
pavalid_cmb <= '0';    
RecomputeRdBits <= '0';    
RecomputeWrBits <= '0';    
savalid_cmb <= '0';    

--Fix to make compatible with OPB IPIF architecture
Set_Cnt_on_plb2opb_rearb_en <= '0';
Clear_Cnt_on_plb2opb_rearb_en <= '0';

arbctrl_sm_ns <= arbctrl_sm_cs;


case arbctrl_sm_cs is

      ----------------------------- IDLE State --------------------------------
      when IDLE =>

        if ((not(QualReq))='1') then
            arbctrl_sm_ns <= IDLE;

            -- insure that masters are disabled only one clock after buslock negates
            -- by resetting the disable request register
            --Fix to make compatible with OPB IPIF architecture
            --(added Rearbitrate_cnt qualifier)
            if (PLB_busLock='0' and Cnt_on_plb2opb_rearb = 0) then
                DisMnReqIn <= (others => '0');
                LoadDisReg <= '1';
                Clear_Cnt_on_plb2opb_rearb_en <= '1';
            end if ;

            --Fix to make compatible with OPB IPIF architecture
            --(added Rearbitrate_cnt qualifier)
        elsif ((QualReq)='1' and
                Cnt_on_plb2opb_rearb = 0) then
            -- at least one master is requesting without abort or being disabled
            -- load priority encoder output and transition to master select state
            loadAddrSelReg <= '1';
            Clear_Cnt_on_plb2opb_rearb_en <= '1';
            arbctrl_sm_ns <= MASTERSEL1;
        else
        
          arbctrl_sm_ns <= IDLE;
        end if;

      ----------------------------- BUSLOCK State -----------------------------
      when BUSLOCK_STATE =>

        if ((Abort)='1') then
          arbctrl_sm_ns <= IDLE;

        elsif (not(arbRdDBusBusyReg) and not(arbSecRdInProgReg) and
               not(arbWrDBusBusyReg) and not(arbSecWrInProgReg)) = '1' then
            
            -- both buses are idle, disable other masters
            arbctrl_sm_ns <= SET_DISABLES;

        else
            -- wait for buses to become idle
            arbctrl_sm_ns <= BUSLOCK_STATE;
            
        end if;

      ----------------------------- DISABLE State -----------------------------
      when DISABLE =>
            
            -- set masters to be disable and load into register
            DisMnReqIn <= arbAddrSelReg;
            LoadDisReg <= '1';

            arbctrl_sm_ns <= IDLE;

      ----------------------------- MASTERSEL1 State --------------------------
      when MASTERSEL1 =>
  
        if (SM_busLock = '0') then
            
            -- bus is not locked, reset master disable register
            DisMnReqIn <= (others => '0');
            LoadDisReg <= '1';
            
        end if ;

        if (not(Read) and not(arbWrDBusBusyReg) and not(arbSecWrInProgReg))='1' then
            -- primary write transaction
            LoadPriWr <= '1'; 
        end if ;

        if (not(Read) and arbWrDBusBusyReg and not(arbSecWrInProgReg))='1' then
            --secondary write transaction
            LoadSecWr <= '1';
            LoadSecWrPriReg <= '1';
        end if ;


        if (Abort or (Read and arbRdDBusBusyReg and arbSecRdInProgReg)
           or (not(Read) and arbWrDBusBusyReg and arbSecWrInProgReg)) ='1' then
            -- master aborted or both buses are busy, go back to IDLE
            arbctrl_sm_ns <= IDLE;

        elsif (SM_busLock='1') then
        
          arbctrl_sm_ns <= BUSLOCK_STATE;

        elsif (Read and not(Abort) and not (arbRdDBusBusyReg and arbSecRdInProgReg)) ='1' then
            -- read transaction and either a primary or secondary slot is free
            arbctrl_sm_ns <= READSTATE;

            if (not(arbRdDBusBusyReg) or (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp)))='1' then
                -- primary transaction, assert PAValid
                pavalid_cmb <= '1';
            end if ;

            if (arbRdDBusBusyReg and not(arbSecRdInProgReg) and not(Sl_rdComp or wdtRdComp))='1' then
                -- secondary transaction, assert SAValid
                savalid_cmb <= '1';
            end if ;

            if (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp))='1' then
                -- if transaction completes in one clock, load register
                LoadPriRd <= '1';
            end if ;


        elsif (not(Read) and not(Abort) and 
               not(arbWrDBusBusyReg and arbSecWrInProgReg))='1' then
            -- write transaction and either a primary or secondary slot is free
            arbctrl_sm_ns <= WRITESTATE;

            if (not(arbWrDBusBusyReg) or (arbWrDBusBusyReg 
                and (Sl_wrComp or wdtWrComp)))='1' then
                -- primary transaction that has not yet completed, assert PAValid
                pavalid_cmb <= '1';
            end if ;

            if (arbWrDBusBusyReg and not(arbSecWrInProgReg) and
                not(Sl_wrComp or wdtWrComp))='1' then
                -- secondary transaction, assert SAValid
                savalid_cmb <= '1';
            end if ;

            if (arbWrDBusBusyReg and (Sl_wrComp or wdtWrComp))='1' then
                -- if transaction completes in one clock, load register
                LoadPriWr <= '1';
            end if ;

        else

            arbctrl_sm_ns <= MASTERSEL1;

        end if;

      ----------------------------- READ State --------------------------------
      when READSTATE =>

        if (not(arbRdDBusBusyReg) or 
           (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp)))='1' then
            pavalid_cmb <= '1';
        end if ;

        if (arbRdDBusBusyReg and not(arbSecRdInProgReg) and
            not(Sl_rdComp or wdtRdComp))='1' then
            savalid_cmb <= '1';
        end if ;

        if (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp))='1' then
          LoadPriRd <= '1';
        end if ;

        if (Abort ='1') then
          pavalid_cmb <= '0';
          savalid_cmb <= '0';

          arbctrl_sm_ns <= IDLE;

        elsif (AAck or wdtAAck)='1' then
          pavalid_cmb <= '0';
          savalid_cmb <= '0';

          RecomputeRdBits <= '1';

          if ((not(arbRdDBusBusyReg) and not(arbSecRdInProgReg)) or 
              (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp)))='1' then
            LoadPriRd <= '1';
          end if ;

          if (arbRdDBusBusyReg and not(arbSecRdInProgReg) and
             not(Sl_rdComp or wdtRdComp))='1' then
            LoadSecRd <= '1';
            LoadSecRdPriReg <= '1';
          end if ;

          arbctrl_sm_ns <= IDLE;

        elsif ((Rearbitrate)='1') then
          pavalid_cmb <= '0';
          savalid_cmb <= '0';
          --Fix to make compatible with OPB IPIF architecture
          if(PLB2OPB_rearb_or = '1') then
             Set_Cnt_on_plb2opb_rearb_en <= '1';
          end if;

          arbctrl_sm_ns <= DISABLE;

        else
          arbctrl_sm_ns <= READSTATE;

        end if;

      ------------------------ RELEASE_DISABLES State -------------------------
      when RELEASE_DISABLES =>

        DisMnReqIn <= (others => '0');
        LoadDisReg <= '1';
        arbctrl_sm_ns <= IDLE;

      ------------------------- SET_DISABLES State ----------------------------
      when SET_DISABLES =>

        DisMnReqIn <= not(arbAddrSelReg);
        LoadDisReg <= '1';

        if (Read)='1' then
          LoadPriRd <= '1';  
        end if ;

        if (not(Read))='1' then
          LoadPriWr <= '1';
        end if ;

        if ((Abort)='1') then
          arbctrl_sm_ns <= RELEASE_DISABLES;

        elsif ((not(Read) and not(Abort))='1') then

          if (not(arbWrDBusBusyReg) or (arbWrDBusBusyReg and
             (Sl_wrComp or wdtWrComp)))='1' then
            pavalid_cmb <= '1'; 
          end if ;

          if (arbWrDBusBusyReg and not(arbSecWrInProgReg) and
             not(Sl_wrComp or wdtWrComp))='1' then
            savalid_cmb <= '1';
          end if ;

          if (arbWrDBusBusyReg and (Sl_wrComp or wdtWrComp))='1' then
            LoadPriWr <= '1';
          end if ;

          arbctrl_sm_ns <= WRITESTATE;

        elsif (Read and not(Abort)) ='1' then

          if (not(arbRdDBusBusyReg) or 
             (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp))) ='1' then
            pavalid_cmb <= '1';
          end if ;

          if (arbRdDBusBusyReg and not(arbSecRdInProgReg) and
             not(Sl_rdComp or wdtRdComp))='1' then
            savalid_cmb <= '1';
          end if ;

          if (arbRdDBusBusyReg and (Sl_rdComp or wdtRdComp))='1' then
            LoadPriRd <= '1';
          end if ;

          arbctrl_sm_ns <= READSTATE;

        else
          arbctrl_sm_ns <= SET_DISABLES;
        end if;

      ----------------------------- WRITE State -------------------------------
      when WRITESTATE =>

        if (not(arbWrDBusBusyReg) or 
            (arbWrDBusBusyReg and (Sl_wrComp or wdtWrComp)))='1' then
          pavalid_cmb <= '1'; 
        end if ;

        if (arbWrDBusBusyReg and not(arbSecWrInProgReg) and
            not(Sl_wrComp or wdtWrComp))='1' then
          savalid_cmb <= '1';
        end if ;

        if (arbWrDBusBusyReg and (Sl_wrComp or wdtWrComp))='1' then
          LoadPriWr <= '1';
        end if ;

        if ((Abort)='1') then
          pavalid_cmb <= '0';
          savalid_cmb <= '0';

          arbctrl_sm_ns <= IDLE;
          

        elsif (AAck or wdtAAck) ='1' then
          pavalid_cmb <= '0';
          savalid_cmb <= '0';
          RecomputeWrBits <= '1';

          if ((not(arbWrDBusBusyReg) and not(arbSecWrInProgReg)) 
               or (arbWrDBusBusyReg and (Sl_wrComp or wdtWrComp)))='1' then
            LoadPriWr <= '1';
          end if ;

          if (arbWrDBusBusyReg and not(arbSecWrInProgReg) and
             not (Sl_wrComp or wdtWrComp))='1' then
            LoadSecWr <= '1';
            LoadSecWrPriReg <= '1';
          end if ;

          arbctrl_sm_ns <= IDLE;

        elsif ((Rearbitrate)='1') then
          pavalid_cmb <= '0';
          savalid_cmb <= '0';

          arbctrl_sm_ns <= DISABLE;

        else
          arbctrl_sm_ns <= WRITESTATE;
        end if;

      ---------------------------- Default State ------------------------------
      when others =>

        arbctrl_sm_ns <= IDLE;

end case;

end process ARBCTRL_SM_CMB_PROCESS;
 
 
ARBCTRL_SM_REG_PROCESS: process (Clk)
begin
 
    if (Clk'event and Clk = '1' ) then
      if (Rst = RESET_ACTIVE) then
        PAValid <= '0';
        SAValid <= '0';
        arbctrl_sm_cs <= IDLE;
      else
        PAValid <= pavalid_cmb;
        SAValid <= savalid_cmb;
        arbctrl_sm_cs <= arbctrl_sm_ns;
      end if;
    end if;
end process ARBCTRL_SM_REG_PROCESS;
  
   --Fix to make compatible with OPB IPIF architecture
--Or PLB2OPB_rearb signals for multiple plb2opb_bridges
PLB2OPB_rearb_or_generate: for i in 0 to PLB2OPB_rearb'length-1 generate
  Len_EQ_1: if(i = 0) generate
      PLB2OPB_rearb_or_vector(0) <= PLB2OPB_rearb(0);
  end generate;
  Len_GT_1: if(i > 0) generate
      PLB2OPB_rearb_or_vector(i) <= PLB2OPB_rearb_or_vector(i-1) or
                                    PLB2OPB_rearb(i);
  end generate;
end generate PLB2OPB_rearb_or_generate;
PLB2OPB_rearb_or <= PLB2OPB_rearb_or_vector(PLB2OPB_rearb'length-1);

Cnt_on_plb2opb_rearb_en_PROCESS: process(Clk)
begin
   if(Clk'event and Clk = '1') then
      if(Rst = RESET_ACTIVE or
          Clear_Cnt_on_plb2opb_rearb_en = '1') then
         Cnt_on_plb2opb_rearb_en <= '0';
      elsif(Set_Cnt_on_plb2opb_rearb_en = '1') then
         Cnt_on_plb2opb_rearb_en <= '1';
      end if;
   end if;
end process Cnt_on_plb2opb_rearb_en_PROCESS;
  
Counter_when_plb2opb_brdg_rearb_PROCESS: process(Clk)
begin
   if(Clk'event and Clk = '1') then
      if(Rst = RESET_ACTIVE or
          (Cnt_on_plb2opb_rearb_en = '0' and
           Set_Cnt_on_plb2opb_rearb_en = '0') or
          Clear_Cnt_on_plb2opb_rearb_en = '1') then
         Cnt_on_plb2opb_rearb <= 0;
      elsif(Set_Cnt_on_plb2opb_rearb_en = '1') then
         Cnt_on_plb2opb_rearb <= C_NUM_OPBCLK_PLB2OPB_REARB + 1;
      elsif(Cnt_on_plb2opb_rearb_en = '1') then
         Cnt_on_plb2opb_rearb <= Cnt_on_plb2opb_rearb - 1;
      end if;
   end if;
end process Counter_when_plb2opb_brdg_rearb_PROCESS;
  
end simulation;

