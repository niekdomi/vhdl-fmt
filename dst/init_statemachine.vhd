-------------------------------------------------------------------------------
-- $Id: init_statemachine.vhd,v 1.1 2004/10/15 16:12:22 gburch Exp $
-------------------------------------------------------------------------------
-- init_statemachine.vhd - entity/architecture pair
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
-- Filename:        init_statemachine.vhd
-- Version:         v1.00e
-- Description:     This state machine controls the power-up sequence of commands
--                  to the SDRAM.
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
--   ALS           05/07/02    First Version
--   ALS           06/15/02
-- ^^^^^^
-- Modified code for SDRAM
-- ~~~~~~
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
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

--  12.06.2006-le	add C_SDRAM_DRIVER_STRENGTH and set extended mode register
--					at init

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library proc_common_v2_00_a;
use proc_common_v2_00_a.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_SDRAM_AWIDTH        -- width of SDRAM address bus
--      C_SDRAM_BANK_AWIDTH   -- width of SDRAM bank address bus
--      C_SDRAM_BRST_LEN      -- length of SDRAM burst
--      C_SDRAM_CAS_LAT       -- SDRAM CAS latency
--
-- Definition of Ports:
--  -- inputs
--      Cmd_done            -- indicates Command SM is in IDLE state
--      Trefi_pwrup_end     -- indicates 100uS has passed
--
--  -- outputs
--      Precharge           -- instructs Command SM to do a PRECHARGE command
--      Load_mr             -- instructs Command SM to do a LOAD_MR command
--      Refresh             -- instructs Command SM to do a Refresh command
--      Register_data       -- data for the mode reg or extended mode reg
--      Register_sel        -- selects the mode reg or extended mode reg
--      Init_done           -- indicates initialization is complete
--                          -- NOTE: This signal could be a top-level output
--                             used as an interrupt to indicate init is done
--      SDRAM_CKE           -- clock enable for SDRAM
--
--    -- Clocks and reset
--      Clk                 
--      Rst               
---------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity init_statemachine is
  generic ( C_SDRAM_AWIDTH        : integer;
            C_SDRAM_BANK_AWIDTH   : integer;
            C_SDRAM_BRST_LEN      : integer;
            C_SDRAM_CAS_LAT       : integer;
            C_SDRAM_DRIVER_STRENGTH : integer := 0);
  port (
    -- inputs
    Cmd_done            : in  std_logic;
    Trefi_pwrup_end     : in  std_logic;

    -- outputs
    Precharge           : out std_logic;
    Load_mr             : out std_logic;
    Refresh             : out std_logic;
    Register_data       : out std_logic_vector(0 to C_SDRAM_AWIDTH-1);
    Register_sel        : out std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
    Init_done           : out std_logic;
    SDRAM_CKE           : out std_logic;
    
    -- Clocks and reset
    Clk                 : in  std_logic;
    Rst                 : in  std_logic
    );
end entity init_statemachine;


-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of init_statemachine is
-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
constant MR_SEL         : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1) := 
                                (others => '0');
constant EMR_SEL        : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1) := 
                                conv_std_logic_vector(2, C_SDRAM_BANK_AWIDTH);
constant BRST_LEN       : std_logic_vector(0 to 2) :=
                                conv_std_logic_vector(log2(C_SDRAM_BRST_LEN), 3);
constant BRST_TYPE      : std_logic := '0';     -- sequential burst type
constant CAS_LAT        : std_logic_vector(0 to 2) :=
                                conv_std_logic_vector(C_SDRAM_CAS_LAT, 3);
constant NORM_OP        : std_logic_vector(0 to 1) := (others => '0');
constant WRBRST         : std_logic := '0';     -- write burst follows burst len                                

constant NUM_RESERVE_BITS :integer := C_SDRAM_AWIDTH-10;
constant RESERVE_BITS   : std_logic_vector(0 to NUM_RESERVE_BITS-1) := (others => '0');
constant NORM_OP_REGDATA: std_logic_vector(0 to C_SDRAM_AWIDTH-1) :=
                    RESERVE_BITS & WRBRST & NORM_OP & CAS_LAT & BRST_TYPE & BRST_LEN;
constant DRIVER_STRENGTH: std_logic_vector(0 to 1) :=
                                conv_std_logic_vector(C_SDRAM_DRIVER_STRENGTH, 2);
constant EMR_DATA: std_logic_vector(0 to C_SDRAM_AWIDTH-1) :=
                    RESERVE_BITS & "000" & DRIVER_STRENGTH & "00" & "000";
-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
type INIT_STATE_TYPE is (RESET, PRECHARGE1, REFRESH1, REFRESH2, LMR, SET_OP_DONE);
signal initsm_ns        : INIT_STATE_TYPE;
signal initsm_cs        : INIT_STATE_TYPE;

-- combinational versions of registered outputs
signal precharge_cmb            : std_logic;
signal load_mr_cmb              : std_logic;
signal refresh_cmb              : std_logic;
signal init_done_cmb            : std_logic;
 
-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  -- architecture imp
-- set constant outputs
SDRAM_CKE       <= '1';

--------------------------------------------------------------------------------
-- Initialization State Machine
-- INITSM_CMB:     combinational process for determining next state
-- INITSM_REG:     state machine registers
--------------------------------------------------------------------------------
    -- Combinational process
INITSM_CMB: process (Trefi_pwrup_end, Cmd_done, initsm_cs)
begin
-- Set default values
precharge_cmb <= '0';
load_mr_cmb <= '0';
refresh_cmb <= '0';       
init_done_cmb <= '0';
initsm_ns <= initsm_cs;
-- mode register
Register_sel    <= MR_SEL;
Register_data   <= NORM_OP_REGDATA;

case initsm_cs is
-------------------------- RESET --------------------------
    when RESET =>
        -- reset state
        -- the register process will keep initsm_cs in IDLE
        -- when reset is released, the 200us counter will start
        -- when this counter finishes, move to the PRECHARGE1 state
        if Trefi_pwrup_end = '1' then
            initsm_ns <= PRECHARGE1;
            precharge_cmb <= '1';
        end if;
            
-------------------------- PRECHARGE1 --------------------------
    when PRECHARGE1 =>
        -- wait in this state for IDLE
        -- once IDLE asserts, prepare for REFRESH1 state
        if Cmd_done = '1' then
            initsm_ns <= REFRESH1;
            refresh_cmb <= '1';
        end if;
        
-------------------------- REFRESH1 --------------------------
    when REFRESH1 =>
        -- wait in this state for refresh period to end
        -- once cycle ends, prepare for REFRESH2 state
        if Cmd_done = '1' then
            initsm_ns <= REFRESH2;
            refresh_cmb <= '1';
        end if;
        
-------------------------- REFRESH2 --------------------------
    when REFRESH2 =>
        -- wait in this state for IDLE
        -- once IDLE asserts, prepare for SET_OP state
        -- select the Mode Register and set the data
        if Cmd_done = '1' then
            if (C_SDRAM_DRIVER_STRENGTH/=0) then
                initsm_ns <= LMR;
            else
                initsm_ns <= SET_OP_DONE;
            end if;
            load_mr_cmb <= '1';
        end if;
-------------------------- LOAD MODE REG --------------------------
    when LMR =>
        -- wait in this state for IDLE
        -- once IDLE asserts, prepare for SET_OP state
        -- select the Mode Register and set the data
        if Cmd_done = '1' then
            initsm_ns <= SET_OP_DONE;
            load_mr_cmb <= '1';
        end if;

-------------------------- SET_OP_DONE --------------------------
    when SET_OP_DONE =>
        -- once in this state, initialization is done
        -- state machine stays in this state until a reset
        -- sets the current state to IDLE and the process starts again.
        -- Extended Mode Register
        if (C_SDRAM_DRIVER_STRENGTH/=0) then
            Register_sel <= EMR_SEL;
            Register_data   <= EMR_DATA;
        end if;
        initsm_ns <= SET_OP_DONE;
        init_done_cmb <= '1';
-------------------------- DEFAULT --------------------------
    when others => 
        initsm_ns <= RESET;
end case;
end process INITSM_CMB;
    
INITSM_REG: process (Clk)
begin

    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE) then
            initsm_cs <= RESET;
            Precharge <= '0';
            Load_mr <= '0';
            Refresh <= '0';
            Init_done <= '0';
        else
            initsm_cs <= initsm_ns;
            Precharge <= precharge_cmb;
            Load_mr <= load_mr_cmb;
            Refresh <= refresh_cmb;
            Init_done <= init_done_cmb;
        end if;
    end if;
end process INITSM_REG;    


end imp;

