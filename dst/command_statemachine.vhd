-------------------------------------------------------------------------------
-- $Id: command_statemachine.vhd,v 1.6 2005/06/03 14:27:35 gburch Exp $
-------------------------------------------------------------------------------
-- command_statemachine.vhd - entity/architecture pair
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
-- Filename:        command_statemachine.vhd
-- Version:         v1.00e
-- Description:     This state machine controls the application of commands
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
-- 
--  ALS             06/04/02
-- ^^^^^^
--  Simplified state machine by removing READ_DATA and WRITE_DATA states. Since
--  READ_CMD and WRITE_CMD states issue the commands, there is no need for the
--  READ_DATA and WRITE_DATA states.
-- ~~~~~~
--  ALS             06/06/02
-- ^^^^^^
--  In states that assert RETRY, must wait for Bus2IP_CS to negate before going
--  back to IDLE so that the bus has had time to react to the retry.
-- ~~~~~~
--  ALS             06/15/02
-- ^^^^^^
--  Modified code for SDRAM - don't need command counter- use SDRAM_BRST_End
-- ~~~~~~
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--  ALS             07/29/02
--  Code cleanup and optimization - add pipe stage to all SDRAM signals when 
--  generic is set. This includes DQM_set and DQM_rst.
-- ~~~~~~
--  ALS             10/06/03    Version D            
-- ^^^^^^
-- Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
-- for new PLB IPIF.
-- ~~~~~~
--  GAB             11/26/03 
-- ^^^^^^
-- Finished adding PLB burst support to read state machine
-- Added waitbrstlen signal.  Due to latency reductions, the READ_CMD was being
-- entered coincident with sdram_burst_end signal and gp_cnt had not reached
-- C_BRSTLEN_CNT, therefore state machine would get stuck in READ_CMD. 
-- ~~~~~~

-- Pankaj           04/27/04    Version D
--  ^^^^^^^^
-- Modifide the command state machine not to wait for Bus2IP_CS signal in write transaction 
-- before leaving the refresh state.
-- ~~~~~~
-- Pankaj           06/05/04
-- ^^^^^^
-- Modified the command state machine to no longer assert Retry in the ACTIVE_CMD, WAIT_TRAS, and
-- PRECHARGE_CMD states when this core is used for the OPB bus. This prevents RETRY from asserting
-- with XFERACK.
-- ~~~~~~
--  GAB             10/07/04    Version E
-- ^^^^^^
--  Registered pend_read and pend_write to break slow paths in core.  This mod
--  required registering sdram control logic.
--
--  Added additional 'else' clause to READ_CMD to allow for exitting state on
--  negation of Bus2IP_CS.  Fixes lock up condition.
--
--  Added Same_rowbank_regce signal to register same row/bank in ipic_if.vhd.
--  This fixes late registering of same row/bank information. (ALS)
--
--  Added rst_data_done_cmb to PRECHARGE state to fix done being held over into
--  a read cycle from a write cycle. (ALS)
--
--  Moved Twr_load and Twr_cnt_en from the data statemachine to the command
--  statemachine to fix issue with Twr time being 1 clock too long
--
--  Updated to use proc_common_v2_00_a library
-- ~~~~~~
--  GAB             02/09/05
-- ^^^^^^
--  Added a reset to data done (rst_data_done_cmb <= '1') to idle state to fix
--  problem with command statemachine getting out of sync with data statemachine
--
--  Removed retry in the LOAD_MR_CMD state and the check for negation of 
--  Bus2IP_CS.  This fixes a problem where the command statemachine would
--  get stuck in the Load Mode Register state if the sdram was accessed
--  during initialization.  This fixes CR203354.
-- ~~~~~~
--
--  GAB             06/03/05
-- ^^^^^^
--  Fixed issue with command state machine getting hung in the ACT_CMD state
--  when Trefi_end occured at the last data beat of a write burst or if the
--  read or write crossed a row/bank boundry on the last data beat of a burst.
--  On OPB_SDRAM, WrReq would negate before the state machine could return to
--  the ACT_CMD state thus the write or read cycle would fail to complete.
--  On writes, in the hung state, the opb_ipif would issue retries because
--  the write buffer still held data.  On reads the opb bus would timeout, 
--  failing to finish al of the reads.  This fixes CR209179.
-- ~~~~~~
--
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
--      C_SDRAM_AWIDTH              -- SDRAM address width          
--      C_SDRAM_COL_AWIDTH          -- SDRAM column address width 
--      C_SDRAM_BANK_AWIDTH         -- SDRAM bank address width
--      C_MRDCNT                    -- Tmrd clock cycles         
--      C_RFCCNT                    -- Trfc clock cycles
--      C_RCDCNT                    -- Trcd clock cycles        
--      C_RPCNT                     -- Trp clock cycles 
--      C_BRSTLEN_CNT               -- SDRAM burst lenght count (IPIF_DWIDTH/SDRAM_DWIDTH)
--      C_GP_CNTR_WIDTH             -- Width of general purpose counter
--      C_OPB_BUS                   -- Processor bus is OPB
--      C_PLB_BUS                   -- Processor bus is PLB
--      C_INCLUDE_HIGHSPEED_PIPE    -- include pipeline stage on write data
--      C_INCLUDE_BURSTS            -- support bus burst transactions
--
-- Definition of Ports:
--  -- IPIC inputs
--      -- inputs
--      Bus2IP_CS           -- indicates SDRAM controller has been selected
--      Burst               -- processor burst transaction
--      Row_addr            -- row address
--      Col_addr            -- column address
--      Bank_addr           -- bank address
--      Pend_rdreq          -- pending read request
--      Pend_wrreq          -- pending write request
--      Same_row            -- access is within the same row
--      Same_bank           -- access is within the same bank
--      Read_op             -- read operation
--      Write_op            -- write operation
--      --outputs
--      Retry               -- retry signal
--      Toutsup             -- timeout suppress signal
--      Reset_pendrdreq     -- reset pending read request
--      Reset_pendwrreq     -- reset pending write request
--      SDRAM_Idle          -- SDRAM state machine is IDLE
--      Rd_AddrAck          -- read acknowledge for burst 
--      Wr_AddrAck          -- write acknowledge for burst

--  -- Init SM interface
--      --inputs
--      Refresh             -- issue refresh command
--      Precharge           -- issue precharge command
--      Load_mr             -- issue load_mr command
--      Register_data       -- data for the Mode or Extended Mode registers
--      Register_sel        -- selects either the Mode or Extended Mode register
--      Init_done           -- indicates initialization sequence is complete
--      -- outputs
--      CMD_done            -- output indicating command sm is in IDLE state
--
--  -- Data SM interface
--      -- inputs
--      Data_done           -- done with data transmission/reception
--      Rst_pend_wr         -- reset pending write
--      Rst_pend_rd         -- reset pending read
--      Rst_data_done       -- reset data done flag
--      -- outputs
--      Pend_write          -- start transmitting write data
--      Pend_read           -- start receiving read data
--      Read_pause          -- read transfer is interrupted
--
--  -- Counters interface
--      -- inputs 
--      Trefi_end           -- time to issue a refresh command
--      Trc_end             -- end of active row to active row delay
--      Trrd_end            -- end of active row to active row delay
--      Tras_end            -- end of active to precharge delay
--      Twr_end             -- end of write to precharge delay
--      GPcnt_end           -- general purpose timer ended
--      SDRAM_brst_end      -- brst len counter ended
--
--      -- outputs          
--      Trefi_load          -- re-load refresh interval timer
--      Trc_load            -- load active row to active row timer
--      Trrd_load           -- load active row to active row timer
--      Tras_load           -- load active to precharge timer
--      Twr_rst             -- reset the Twr counter
--      Twr_load            -- load write data to precharge timer
--      Twr_cnt_en          -- enable write data to precharge timer
--      GPcnt_load          -- load the general purpose timer
--      GPcnt_data          -- count to load into the general purpose timer
--
--  -- SDRAM outputs
--      SDRAM_RASn          -- Row address strobe
--      SDRAM_CASn          -- Column address strobe
--      SDRAM_WEn           -- Write enable
--      SDRAM_Addr          -- address
--      SDRAM_BankAddr      -- bank address
--      DQM_rst             -- data mask reset
--      DQM_set             -- data mask set
--
--    -- Clocks and reset
--      Clk                 
--      Rst               
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity command_statemachine is
  generic ( C_SDRAM_AWIDTH          : integer;
            C_SDRAM_COL_AWIDTH      : integer;
            C_SDRAM_BANK_AWIDTH     : integer;
            C_OPB_BUS               : integer  := 0;
            C_PLB_BUS               : integer  := 1;
            C_INCLUDE_HIGHSPEED_PIPE: integer  := 1;
            C_INCLUDE_BURSTS        : integer  := 0
            );
  port (
    -- IPIC 
        Bus2IP_CS               : in  std_logic;
        Burst                   : in  std_logic;
        Row_addr                : in  std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        Col_addr                : in  std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        Bank_addr               : in  std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        Pend_rdreq              : in  std_logic;
        Pend_wrreq              : in  std_logic;
        Same_row                : in  std_logic;
        Same_bank               : in  std_logic;
        Read_op                 : in  std_logic;
        Write_op                : in  std_logic;
        Retry                   : out std_logic;
        Toutsup                 : out std_logic;
        Reset_pendrdreq         : out std_logic;
        Reset_pendwrreq         : out std_logic;
        SDRAM_Idle              : out std_logic;
        Rd_AddrAck              : out std_logic;
        Wr_AddrAck              : out std_logic;
        ErrAck                  : out std_logic;
        Same_rowbank_regce      : out std_logic;
        
    -- Init SM interface
        Refresh                 : in  std_logic;
        Precharge               : in  std_logic;
        Load_mr                 : in  std_logic;
        Register_data           : in  std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        Register_sel            : in  std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        Init_done               : in  std_logic;
        Cmd_done                : out std_logic;        
    
    -- Data SM interface
        Data_done               : in  std_logic;
        Rst_data_done           : out std_logic;
        Pend_write              : out std_logic;
        Rst_pend_wr             : in  std_logic;
        Pend_read               : out std_logic;
        Rst_pend_rd             : in  std_logic;
        Read_pause              : out std_logic;
    
    -- Counters interface
        Trefi_end               : in  std_logic;       
        Trc_end                 : in  std_logic;
        Trrd_end                : in  std_logic;
        Tras_end                : in  std_logic;
        Twr_end                 : in  std_logic;

        Trfc_end                : in  std_logic;
        Trcd_end                : in  std_logic;
        Tmrd_end                : in  std_logic;
        Trp_end                 : in  std_logic;
        Tbrstlen_end            : in  std_logic;
        

        SDRAM_brst_end          : in  std_logic;
        Trefi_load              : out std_logic;
        Trc_load                : out std_logic;
        Trrd_load               : out std_logic;
        Tras_load               : out std_logic;
        Twr_load                : out std_logic;
        Twr_cnt_en              : out std_logic;
        Twr_rst                 : out std_logic;

        Trfc_load               : out std_logic;
        Trcd_load               : out std_logic;
        Tmrd_load               : out std_logic;
        Trp_load                : out std_logic;
        Tbrstlen_load           : out std_logic;


    
    -- SDRAM interface
        SDRAM_RASn              : out std_logic;
        SDRAM_CASn              : out std_logic;
        SDRAM_WEn               : out std_logic;
        SDRAM_Addr              : out std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        SDRAM_BankAddr          : out std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        DQM_rst                 : out std_logic;
        DQM_set                 : out std_logic;
    
      -- Clocks and reset
        Clk                     : in  std_logic;
        Rst                     : in  std_logic
      );
end entity command_statemachine;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of command_statemachine is

-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
-- setup constants for the SDRAM command (RCW = Ras, Cas, Wen)
-- RAS = bit 0
-- CAS = bit 1
-- WEN = bit 2
constant NOP_RCW        : std_logic_vector(0 to 2) := "111";
constant ACTIVE_RCW     : std_logic_vector(0 to 2) := "011";
constant READ_RCW       : std_logic_vector(0 to 2) := "101";
constant WRITE_RCW      : std_logic_vector(0 to 2) := "100";
constant PRECHARGE_RCW  : std_logic_vector(0 to 2) := "010";
constant REFRESH_RCW    : std_logic_vector(0 to 2) := "001";
constant LOAD_MR_RCW    : std_logic_vector(0 to 2) := "000";

-- Precharge command has data value
constant PRECHARGE_DATA : std_logic_vector(0 to C_SDRAM_AWIDTH-1) := (others => '1');


-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
type COMMAND_STATE_TYPE is (IDLE, LOAD_MR_CMD, REFRESH_CMD, ACT_CMD, READ_CMD,
                         WRITE_CMD, SET_BRST_RDACK, WAIT_TRAS,  
                         PRECHARGE_CMD, WAIT_TRRD, WAIT_TWR);
signal cmdsm_ns         : COMMAND_STATE_TYPE;
signal cmdsm_cs         : COMMAND_STATE_TYPE;

-- other needed signals
signal pend_read_cmb        : std_logic;
signal pend_read_reg        : std_logic;
signal pend_write_cmb     : std_logic;
signal pend_write_reg       : std_logic;
signal RCW_cmd              : std_logic_vector(0 to 2);
signal cmd_done_cmb         : std_logic;
signal reset_pendwrreq_cmb  : std_logic;
signal reset_pendrdreq_cmb  : std_logic;
signal rst_data_done_cmb    : std_logic;
signal dqm_rst_cmb          : std_logic;
signal dqm_set_cmb          : std_logic;
signal rst_write_state      : std_logic;
signal rst_read_state       : std_logic;
signal read_state_cmb       : std_logic;
signal write_state_cmb      : std_logic;
signal read_state           : std_logic;
signal write_state          : std_logic;

signal sdram_addr_i         : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal sdram_bankaddr_i     : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);

signal wr_addrack_cmb       : std_logic;
signal rd_addrack_cmb       : std_logic;
signal read_pause_cmb       : std_logic;
signal read_pause_i         : std_logic;

signal wait4brstlen_cmb     : std_logic; 
signal wait4brstlen         : std_logic; 

signal reg_sdram_addr       : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal reg_sdram_bankaddr   : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
signal reg_sdram_rasn       : std_logic; 
signal reg_sdram_casn       : std_logic;     
signal reg_sdram_wen        : std_logic; 
signal reg_dqm_rst          : std_logic; 
signal reg_dqm_set          : std_logic; 

signal bus2ip_cs_d1         : std_logic;

-- GAB 06/03/05 
-- Added to fix hang issue when burst write interrupt by refresh
signal write_not_done       : std_logic;
signal rst_wr_not_done      : std_logic;
signal set_wr_not_done      : std_logic;
signal read_not_done        : std_logic;
signal rst_rd_not_done      : std_logic;
signal set_rd_not_done      : std_logic;

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  -- architecture imp

-- assign outputs
--Pend_read       <= pend_read_cmb;
--Pend_write      <= pend_write_cmb;
Pend_read       <= pend_read_reg;
Pend_write      <= pend_write_reg;

Read_pause      <= read_pause_i;

--Wr_AddrAck      <= wr_addrack_cmb;
Rst_data_done   <= rst_data_done_cmb;

--------------------------------------------------------------------------------
-- Command State Machine
-- CMDSM_CMB:     combinational process for determining next state
-- CMDSM_REG:     state machine registers
--------------------------------------------------------------------------------
    -- Combinational process
CMDSM_CMB: process (Bus2IP_CS, Read_op, Write_op, Row_addr, Col_addr, Bank_addr, 
                    Refresh, Precharge, Load_mr, Register_data, Register_sel,
                    Data_done, Trefi_end, Trrd_end, Tras_end, Twr_end, 
                    Trfc_end, Trcd_end, Tmrd_end, Trp_end, Tbrstlen_end,
                    Burst, Pend_rdreq, Pend_wrreq, Same_row, write_not_done,read_not_done,
                    Same_bank, SDRAM_brst_end, Trc_end, pend_read_reg, pend_write_reg,
                    cmdsm_cs, write_state, read_state, read_pause_i,pend_write_cmb)

begin
-- Set default values
-- Note: the SDRAM interface signals will be registered in IOB registers for better timing
RCW_cmd <= (others => '1');
sdram_addr_i <= (others => '0');
sdram_bankaddr_i <= (others => '0');
cmd_done_cmb <= '0';       
--pend_write_cmb <=  pend_write_reg;
--pend_read_cmb <= pend_read_reg;
pend_write_cmb  <=  '0';
pend_read_cmb   <=  '0';
Trefi_load <= '0';
Trc_load <= '0';
Trrd_load <= '0';
Tras_load <= '0';
--GPcnt_load <= '0';
--GPcnt_data <= (others => '1');
cmdsm_ns <= cmdsm_cs;
reset_pendrdreq_cmb <= '0';
reset_pendwrreq_cmb <= '0';
rst_data_done_cmb <= '0';
dqm_set_cmb <= '0';
dqm_rst_cmb <= '0';
rst_read_state <= '0';
rst_write_state <= '0';
write_state_cmb <= write_state;
read_state_cmb <= read_state;
rd_addrack_cmb <= '0';
Wr_AddrAck_cmb <= '0';
ErrAck <= '0';
Twr_load    <= '0';
Twr_cnt_en  <= '0';
Twr_rst <= '0';
Toutsup <= '0';
Retry <= '0';
read_pause_cmb <= read_pause_i;
wait4brstlen_cmb <= wait4brstlen; 
Same_rowbank_regce <= '0';

Trfc_load       <= '0';
Trcd_load       <= '0';
Tmrd_load       <= '0';
Trp_load        <= '0';
Tbrstlen_load   <= '0';

-- GAB 06/03/05
-- Added to fix hang issue when
-- burst write interrupt by refresh
rst_wr_not_done <= '0';
set_wr_not_done <= '0';
rst_rd_not_done <= '0';
set_rd_not_done <= '0';

case cmdsm_cs is
-------------------------- IDLE --------------------------
    when IDLE =>
        -- reset state
        Twr_rst             <= '1';
        rst_read_state      <= '1';
        rst_write_state     <= '1';
        rst_data_done_cmb   <= '1';
        -- setup the command so that once its registered,
        -- it'll line up with the state  
        if Refresh='1' or 
            (init_done = '1' and Trefi_end='1') then
            cmdsm_ns    <= REFRESH_CMD;
            RCW_cmd     <= REFRESH_RCW;
            -- reload the refresh interval timer
            Trefi_load  <= '1';
            -- load the general purpose counter to time refresh
            -- command to another command delay
            --GPcnt_load  <= '1';
            --GPcnt_data  <= C_RFCCNT;
            Trfc_load   <= '1';
            
            -- assert Retry
             Retry       <= '1';
        elsif Bus2IP_CS = '1' and Init_done = '1'  then
            -- prepare for ACTIVE command
            cmdsm_ns        <= ACT_CMD;
            RCW_cmd         <= ACTIVE_RCW;
            sdram_addr_i    <= Row_addr;
            sdram_bankaddr_i<= Bank_addr;
            -- load the general purpose counter to time Trcd
            --GPcnt_load      <= '1';
            --GPcnt_data      <= C_RCDCNT;
            Trcd_load       <= '1';
            -- load the RAS counter to time Tras
            Tras_load       <= '1';
            -- load the RRD counter to time Trrd
            Trrd_load       <= '1';
            -- load the RC counter to time Trc
            Trc_load        <= '1';
            dqm_rst_cmb     <= '1';
        elsif Load_mr = '1' then
            cmdsm_ns        <= LOAD_MR_CMD;
            RCW_cmd         <= LOAD_MR_RCW;
            sdram_addr_i    <= Register_data;
            sdram_bankaddr_i<= Register_sel;
            --GPcnt_load      <= '1';
            --GPcnt_data      <= C_MRDCNT;
            Tmrd_load       <= '1';
        elsif Precharge = '1' then
            cmdsm_ns        <= PRECHARGE_CMD;
            RCW_cmd         <= PRECHARGE_RCW;
            sdram_addr_i    <= PRECHARGE_DATA;
            --GPcnt_load      <= '1';
            --GPcnt_data      <= C_RPCNT;
            Trp_load        <= '1';
        end if;    
        
-------------------------- REFRESH_CMD --------------------------
    when REFRESH_CMD =>
        -- start timing refresh command cycle. 
        Retry   <= '1';
        ToutSup <= '1';
                
        if C_OPB_BUS = 1 then 
                    -- When timer expires 
                    -- return to IDLE state if write transaction 
                    -- because write buffer is controlling Bus2IP_CS 
                    -- if read, must wait for Bus2IP_CS to negate so that the bus 
                    -- has reacted to the retry 
                    if Trfc_end = '1' then 
                        if read_state= '1' or Read_op = '1' then 
                            if Bus2IP_CS = '0' then 
                                cmd_done_cmb <= '1'; 
                                cmdsm_ns <= IDLE; 
                            end if; 
                        else 
                            cmd_done_cmb <= '1'; 
                            cmdsm_ns <= IDLE; 
                        end if; 
                    end if; 
         end if; 


        if C_PLB_BUS = 1 then
            -- when timer expires, return to IDLE state if CS is negated
            -- Data phase can't abort on PLB, so if CS is still valid
            -- go to ACT state
            if Trfc_end = '1'then
                cmd_done_cmb <= '1';
                
                if Bus2IP_CS = '1' then
                    cmdsm_ns        <= ACT_CMD;
                    RCW_cmd         <= ACTIVE_RCW;
                    sdram_addr_i    <= Row_addr;
                    sdram_bankaddr_i<= Bank_addr;
                    -- load the general purpose counter to time Trcd
                    --GPcnt_load  <= '1';
                    --GPcnt_data  <= C_RCDCNT;
                    Trcd_load   <= '1';
                    -- load the RAS counter to time Tras
                    Tras_load   <= '1';
                    -- load the RRD counter to time Trrd
                    Trrd_load   <= '1';
                    -- load the RC counter to time Trc
                    Trc_load    <= '1';
                    -- Reset DQM's
                    dqm_rst_cmb <= '1';
                else
                    cmdsm_ns <= IDLE;
                end if;
            end if;
        end if;

-------------------------- LOAD_MR_CMD --------------------------
    when LOAD_MR_CMD =>
        -- assert the count enable to start timing LOAD_MR command
        -- cycle.
--        Retry <= '1';
        ToutSup <= '1';
        -- When timer expires, return to IDLE state
        if Tmrd_end = '1' then
            cmd_done_cmb    <= '1';
            cmdsm_ns        <= IDLE;
        end if;
           
-------------------------- ACT_CMD --------------------------
    when ACT_CMD =>
    --    Retry <= '1';
        Toutsup <= '1';
        Same_rowbank_regce <= '1';
        
        if Trefi_end = '1' then

            if C_PLB_BUS=1 then  
               Retry <= '1';       
            end if;              

            -- refresh command
            -- must go to PRECHARGE state to close row
            if Tras_end = '1' then
                cmdsm_ns        <= PRECHARGE_CMD;
                RCW_cmd         <= PRECHARGE_RCW;
                sdram_addr_i    <= PRECHARGE_DATA;
                --GPcnt_load      <= '1';
                --GPcnt_data      <= C_RPCNT;
                Trp_load        <= '1';
            else
                cmdsm_ns        <= WAIT_TRAS;
            end if;            
        elsif Bus2IP_CS = '0' then
            -- CS has negated (master abort)
            -- must go to to precharge to close row                
            if Tras_end = '1' then
                cmdsm_ns        <= PRECHARGE_CMD;
                RCW_cmd         <= PRECHARGE_RCW;
                sdram_addr_i    <= PRECHARGE_DATA;
                --GPcnt_load      <= '1';
                --GPcnt_data      <= C_RPCNT;
                Trp_load        <= '1';
            else
                cmdsm_ns        <= WAIT_TRAS;
            end if;
        elsif Trcd_end = '1' then
            -- Has Trcd time expired?
            if read_state = '1' then

                -- GAB 06/03/05 Hang Fix
                -- Re-entering Read State 
                -- therefore reset read not done flag
                if(C_OPB_BUS = 1)then
                    rst_rd_not_done     <= '1';       
                end if;

                -- need to continue an interrupted read transaction
                -- wait for data to be completed
                if Data_done = '1' then
                    -- prepare for READ_CMD state
                    RCW_cmd             <= READ_RCW;
                    sdram_addr_i        <= Col_addr;
                    sdram_bankaddr_i    <= bank_addr;
                    cmdsm_ns            <= READ_CMD;
                    pend_read_cmb       <= '1';
                    reset_pendrdreq_cmb <= '1';
                    rd_addrack_cmb          <= '1';
                    -- load general purpose counter to time when
                    -- next command can be issued
                    --GPcnt_load          <= '1';
                    --GPcnt_data          <= C_BRSTLEN_CNT;
                    Tbrstlen_load       <= '1';
                    -- release read data done reset
                    rst_data_done_cmb   <= '1';
                end if;
            
            -- Trcd is complete
            elsif Pend_rdreq ='1' or Read_op = '1' 
            or read_not_done = '1'  then

                -- GAB 06/03/05 Hang Fix
                -- Re-entering Read State 
                -- therefore reset read not done flag
                if(C_OPB_BUS = 1)then
                    rst_rd_not_done     <= '1';       
                end if;

                pend_read_cmb       <= '1';
                reset_pendrdreq_cmb <= '1';
                rd_addrack_cmb          <= '1';
                -- prepare for READ_CMD state
                RCW_cmd             <= READ_RCW;
                sdram_addr_i        <= Col_addr;
                sdram_bankaddr_i    <= bank_addr;
                cmdsm_ns            <= READ_CMD;
                -- load general purpose counter to time when
                -- next command can be issued
                --GPcnt_load <= '1';
                --GPcnt_data <= C_BRSTLEN_CNT;
                Tbrstlen_load   <= '1';
            elsif Pend_wrreq = '1' or Write_op = '1' 
            or write_not_done = '1' then
                
                -- GAB 06/03/05 Hang Fix
                -- Re-entering Write State 
                -- therefore reset write not done flag
                if(C_OPB_BUS = 1)then
                    rst_wr_not_done     <= '1';        
                end if;
                
                Twr_rst             <= '1';
                pend_write_cmb      <= '1';
                reset_pendwrreq_cmb <= '1';
                -- prepare for WRITE_CMD state
                RCW_cmd             <= WRITE_RCW;
                sdram_addr_i        <= Col_addr;
                sdram_bankaddr_i    <= bank_addr;
                cmdsm_ns            <= WRITE_CMD;
                Wr_AddrAck_cmb      <= '1';
            end if; -- if Pend_rdreq
        end if; -- if Trefi_end
        
-------------------------- READ_CMD --------------------------
    when READ_CMD =>
        -- when SDRAM burst ends, see if transaction is a burst
        -- so that a new command can be issued
        -- Can't service a refresh command during a read with
        -- this IPIF version
        ToutSup <= '1';
        read_state_cmb <= '1';
        if SDRAM_brst_end = '1' or wait4brstlen = '1' then

            -------------- BURST Support --------------
            if C_INCLUDE_BURSTS = 1 then 
                if Trefi_end = '1' then
                    if Tbrstlen_end = '1' then
                        -- refresh command
                        -- Must wait for TRAS to end before precharging
                        -- Assert read pause
                        read_pause_cmb <= '1';
                        wait4brstlen_cmb <= '0';
                        if Tras_end = '1' then
                            cmdsm_ns        <= PRECHARGE_CMD;
                            RCW_cmd         <= PRECHARGE_RCW;
                            sdram_addr_i    <= PRECHARGE_DATA;
                            --GPcnt_load      <= '1';
                            --GPcnt_data      <= C_RPCNT;
                            Trp_load        <= '1';
                        else
                            cmdsm_ns        <= WAIT_TRAS;
                        end if;
                    else
                        wait4brstlen_cmb <= '1';
                    end if;                
--                elsif Burst = '1' and Read_op = '1' then 
                elsif Burst = '1' or Read_op = '1' then 
                    -- More reads therefore clear done flag
                    rst_data_done_cmb <= '1';
                    if Tbrstlen_end = '1' then     -- can issue another read command
                        wait4brstlen_cmb <= '0';
                        if Same_row = '1' then
                            -- access is to the same row, can repeat read command
                            RCW_cmd             <= READ_RCW;
                            sdram_addr_i        <= Col_addr;
                            sdram_bankaddr_i    <= bank_addr;
                            cmdsm_ns            <= READ_CMD;
                            pend_read_cmb       <= '1';
                            -- load general purpose counter to time when
                            -- next command can be issued
                            --GPcnt_load          <= '1';
                            --GPcnt_data          <= C_BRSTLEN_CNT;
                            Tbrstlen_load       <= '1';
                            rd_addrack_cmb          <= '1';
                        else

                            -- GAB 06/03/05 Hang Fix
                            -- Leaving Read State before done with burst
                            -- therefore set read not done flag
                            if(Read_op = '1' and Burst = '1' and C_OPB_BUS = 1)then
                                set_rd_not_done <= '1';
                            end if;

                            -- access is to a different row
                            -- if same bank, have to precharge
                            -- assert read_pause
                            read_pause_cmb <= '1';
                            if Same_bank = '1' then
                                if Tras_end = '1' then
                                    cmdsm_ns        <= PRECHARGE_CMD;
                                    RCW_cmd         <= PRECHARGE_RCW;
                                    sdram_addr_i    <= PRECHARGE_DATA;
                                    --GPcnt_load      <= '1';
                                    --GPcnt_data      <= C_RPCNT;
                                    Trp_load        <= '1';
                                else
                                    cmdsm_ns        <= WAIT_TRAS;
                                end if;    
                            else
                                -- different bank - can go to ACTIVE
                                -- if Trrd has expired, prepare for ACTIVE cmd, else
                                -- wait for Trrd to expire
                                if Trrd_end = '1' then
                                    RCW_cmd         <= ACTIVE_RCW;
                                    sdram_addr_i    <= Row_addr;
                                    sdram_bankaddr_i<= Bank_addr;
                                    cmdsm_ns        <= ACT_CMD;
                                    -- load the general purpose counter to time Trcd
                                    --GPcnt_load  <= '1';
                                    --GPcnt_data  <= C_RCDCNT;
                                    Trcd_load   <= '1';
                                    -- load the RAS counter to time Tras
                                    Tras_load   <= '1';
                                    -- load the RC counter to time Trc
                                    Trc_load    <= '1';
                                else
                                    cmdsm_ns    <= WAIT_TRRD;
                                end if;
                            end if; -- if same bank, different row
                        end if; -- if same row
                    else
                        wait4brstlen_cmb <= '1';
                    end if; -- if Tbrstlen_end     
                else
                    if Tbrstlen_end = '1' then     -- can issue another read command
                        wait4brstlen_cmb <= '0';
                        pend_read_cmb <= '0';
                         -- if Tras has expired, go to PRECHARGE, 
                         -- otherwise wait for Tras to expire
                         if Tras_end = '1' then
                             cmdsm_ns       <= PRECHARGE_CMD;
                             RCW_cmd        <= PRECHARGE_RCW;
                             sdram_addr_i   <= PRECHARGE_DATA;
                             --GPcnt_load     <= '1';
                             --GPcnt_data     <= C_RPCNT;
                             Trp_load       <= '1';
                         else
                             cmdsm_ns <= WAIT_TRAS;
                         end if; -- if tras_end
                     else
                        wait4brstlen_cmb <= '1';
                     end if; -- if Tbrstlen_end
                end if; -- if Read_op              
            -------------- NO BURST Support --------------
            else
                if Tbrstlen_end = '1' then     -- can issue another read command
                    wait4brstlen_cmb <= '0';
                    pend_read_cmb <= '0';
                     -- if Tras has expired, go to PRECHARGE, 
                     -- otherwise wait for Tras to expire
                     if Tras_end = '1' then
                         cmdsm_ns       <= PRECHARGE_CMD;
                         RCW_cmd        <= PRECHARGE_RCW;
                         sdram_addr_i   <= PRECHARGE_DATA;
                         --GPcnt_load     <= '1';
                         --GPcnt_data     <= C_RPCNT;
                         Trp_load       <= '1';
                     else
                         cmdsm_ns <= WAIT_TRAS;
                     end if; -- if tras_end
                 else
                    wait4brstlen_cmb <= '1';
                 end if; -- if Tbrstlen_end
            end if; -- if C_INCLUDE_BURSTS
--        elsif(bus2ip_cs_d1 = '0')then
        elsif(bus2ip_cs = '0')then
            wait4brstlen_cmb <= '0';
            pend_read_cmb <= '0';
             -- if Tras has expired, go to PRECHARGE, 
             -- otherwise wait for Tras to expire
             if Tras_end = '1' then
                 cmdsm_ns       <= PRECHARGE_CMD;
                 RCW_cmd        <= PRECHARGE_RCW;
                 sdram_addr_i   <= PRECHARGE_DATA;
                 --GPcnt_load     <= '1';
                 --GPcnt_data     <= C_RPCNT;
                 Trp_load       <= '1';
             else
                 cmdsm_ns <= WAIT_TRAS;
             end if; -- if tras_end
        end if; -- if SDRAM_brst_end
        
-------------------------- WRITE_CMD --------------------------
    when WRITE_CMD =>
        ToutSup <= '1';
        -- when SDRAM burst ends, see if transaction is a burst
        -- so that a new command can be issued
        -- If there is a need for a refresh command, (Trefi_end=1)
        -- don't service a pending request
        if SDRAM_brst_end = '1' then
        
            -------------- BURST Support --------------
            if C_INCLUDE_BURSTS = 1 then
                if Trefi_end = '1' then

                    -- GAB 06/03/05 Hang Fix
                    -- Leaving Write State before done with burst
                    -- therefore set write not done flag
                    if(Write_op = '1' and Burst = '1' and C_OPB_BUS = 1)then
                        set_wr_not_done <= '1';
                    end if;

                    -- refresh command
                    -- must first wait for Twr to expire and then issue
                    -- PRECHARGE
                    Twr_load  <= '1';
                    if Twr_end = '1' then
                         -- data transmission is done
                         -- if Tras has expired, go to PRECHARGE, 
                         -- otherwise wait for Tras and Twr to expire
                         if Tras_end = '1' then

                             cmdsm_ns       <= PRECHARGE_CMD;
                             RCW_cmd        <= PRECHARGE_RCW;
                             sdram_addr_i   <= PRECHARGE_DATA;
                             --GPcnt_load     <= '1';
                             --GPcnt_data     <= C_RPCNT;
                             Trp_load       <= '1';
                         else
                             cmdsm_ns <= WAIT_TRAS;
                         end if;
                    else
                        cmdsm_ns <= WAIT_TWR;
                    end if;

                elsif Write_op = '1' and Burst = '1' then
                    -- write burst
                    if Same_row = '1' then
                        -- access is to the same row, issue write command
                        RCW_cmd         <= WRITE_RCW;
                        sdram_addr_i    <= Col_addr;
                        sdram_bankaddr_i<= bank_addr;
                        cmdsm_ns        <= WRITE_CMD;
                        pend_write_cmb  <= '1';
                        wr_addrack_cmb  <= '1';
                    else

                        -- GAB 06/03/05 Hang Fix
                        -- Leaving Write State before done with burst
                        -- therefore set write not done flag
                        if(Write_op = '1' and Burst = '1' and C_OPB_BUS = 1)then
                            set_wr_not_done <= '1';
                        end if;
                        
                        -- access is to a different row
                        -- if same bank, have to PRECHARGE
                        -- wait for Twr
                        if Same_bank = '1' then
                            -- data transmission is done
                            -- if Tras has expired, go to PRECHARGE, 
                            -- otherwise wait for Tras and Twr to expire
                            Twr_load  <= '1';
                            if Twr_end = '1' then
                                if Tras_end = '1' then
                                     cmdsm_ns       <= PRECHARGE_CMD;
                                     RCW_cmd        <= PRECHARGE_RCW;
                                     sdram_addr_i   <= PRECHARGE_DATA;
                                     --GPcnt_load     <= '1';
                                     --GPcnt_data     <= C_RPCNT;
                                     Trp_load       <= '1';
                                else
                                     cmdsm_ns <= WAIT_TRAS;
                                end if;
                            else
                                cmdsm_ns <= WAIT_TWR;
                            end if;
                        else
                            -- different bank, can go to ACTIVE
                            -- if Trrd has expired, prepare for ACTIVE cmd, else
                            -- wait for Trrd to expire
                            if Trrd_end = '1' then
                                RCW_cmd         <= ACTIVE_RCW;
                                sdram_addr_i    <= Row_addr;
                                sdram_bankaddr_i<= Bank_addr;
                                -- load the general purpose counter to time Trcd
                                --GPcnt_load      <= '1';
                                --GPcnt_data      <= C_RCDCNT;
                                Trcd_load       <= '1';
                                -- load the RAS counter to time Tras
                                Tras_load       <= '1';
                                cmdsm_ns        <= ACT_CMD;
                            else
                                cmdsm_ns        <= WAIT_TRRD;
                            end if; -- if trrd_end
                        end if; -- if same bank
                    end if; -- if same row
                else
                    pend_write_cmb <= '0';
                    Twr_load  <= '1';
                    if Twr_end = '1' then
                         -- data transmission is done
                         -- if Tras has expired, go to PRECHARGE, 
                         -- otherwise wait for Tras and Twr to expire
                         if Tras_end = '1' then
                             cmdsm_ns       <= PRECHARGE_CMD;
                             RCW_cmd        <= PRECHARGE_RCW;
                             sdram_addr_i   <= PRECHARGE_DATA;
                             --GPcnt_load     <= '1';
                             --GPcnt_data     <= C_RPCNT;
                             Trp_load       <= '1';
                         else
                             cmdsm_ns <= WAIT_TRAS;
                         end if; -- if tras_end
                    else
                        cmdsm_ns <= WAIT_TWR;
                    end if; -- if twr_end               
                end if; -- if trefi_end or bus2ip_wrreq

            -------------- NO BURST Support --------------
            else 
                pend_write_cmb <= '0';
                Twr_load  <= '1';
                if Twr_end = '1' then
                     -- data transmission is done
                     -- if Tras has expired, go to PRECHARGE, 
                     -- otherwise wait for Tras and Twr to expire
                     if Tras_end = '1' then
                         cmdsm_ns       <= PRECHARGE_CMD;
                         RCW_cmd        <= PRECHARGE_RCW;
                         sdram_addr_i   <= PRECHARGE_DATA;
                         --GPcnt_load     <= '1';
                         --GPcnt_data     <= C_RPCNT;
                         Trp_load       <= '1';
                     else
                         cmdsm_ns <= WAIT_TRAS;
                     end if; -- if tras_end
                else
                    cmdsm_ns <= WAIT_TWR;
                end if; -- if twr_end               
            end if; -- if C_INCLUDE_BURSTS
        end if; -- if sdram_brst_end    

-------------------------- WAIT_TWR --------------------------
    when WAIT_TWR =>
        ToutSup <= '1';
        Twr_cnt_en  <= '1';
        if Twr_end = '1' then
            if Tras_end = '1' then       
                cmdsm_ns        <= PRECHARGE_CMD;
                RCW_cmd         <= PRECHARGE_RCW;
                sdram_addr_i    <= PRECHARGE_DATA;
                --GPcnt_load      <= '1';
                --GPcnt_data      <= C_RPCNT;
                Trp_load        <= '1';
            else
                cmdsm_ns        <= WAIT_TRAS;
            end if;
       end if;
        
-------------------------- PRECHARGE_CMD --------------------------
    when PRECHARGE_CMD =>
        Twr_rst     <= '1';

        if Trefi_end = '1' or read_state = '0' or read_op = '1' then
            -- either refresh or initialization or write xfer
            -- or an interrupted read burst
            -- assert ToutSup
            -- ToutSup is not asserted if waiting for data_done
            ToutSup <= '1';
        end if;

        -- go to IDLE state once Trp and Trc have expired
        -- Note: if came to this state to do a REFRESH, Trefi_end will
        -- still be asserted, so will get to REFRESH state through IDLE
        if Trp_end = '1' and Trc_end = '1' then
            if read_state = '0' and write_state = '0' then
                -- either refresh or initialization or write xfer
                -- go to IDLE
                cmd_done_cmb        <= '1';
                dqm_set_cmb         <= '1';
                rst_data_done_cmb   <= '1'; 
                cmdsm_ns            <= IDLE;                
            else 
                -- end of read transaction or interrupted read, must wait for data_done
                if Data_done = '1' then
                    dqm_set_cmb         <= '1';
                    cmd_done_cmb        <= '1';
                    rst_data_done_cmb   <= '1';
                    cmdsm_ns            <= IDLE;
                end if;
            end if;
        end if;
        if Trefi_end='1' and C_PLB_BUS=1 then
            -- refresh
            -- assert Retry
            Retry <= '1'; 
        end if;
        
-------------------------- WAIT_TRAS --------------------------
    when WAIT_TRAS =>
        -- go to PRECHARGE_CMD state once Tras has expired
        -- if came to this state to do a REFRESH, set retry or toutsup
        if Trefi_end = '1'  then
            -- assert TOUTSUP
            Toutsup <= '1';
        end if;
        if Tras_end = '1' then
            cmdsm_ns        <= PRECHARGE_CMD;
            RCW_cmd         <= PRECHARGE_RCW;
            sdram_addr_i    <= PRECHARGE_DATA;
            --GPcnt_load      <= '1';
            --GPcnt_data      <= C_RPCNT;
            Trp_load        <= '1';
        end if;
        
-------------------------- WAIT_TRRD --------------------------
    when WAIT_TRRD =>
        ToutSup <= '1';
        -- keep the Trrd counter enabled
        -- go to ACT_CMD state once Trrd has expired
        if Trrd_end = '1' then
            RCW_cmd         <= ACTIVE_RCW;
            sdram_addr_i    <= Row_addr;
            sdram_bankaddr_i<= Bank_addr;
            -- load the general purpose counter to time Trcd
            --GPcnt_load      <= '1';
            --GPcnt_data      <= C_RCDCNT;
            Trcd_load       <= '1';
            -- load the RAS counter to time Tras
            Tras_load       <= '1';
            -- load the RC counter to time Trc
            Trc_load        <= '1';
            cmdsm_ns        <= ACT_CMD;
        end if;
        
-------------------------- DEFAULT --------------------------
    when others => 
        cmd_done_cmb <= '1';
        cmdsm_ns <= IDLE;
end case;
end process CMDSM_CMB;


-------------------------------------------------------------------------------
-- Register States
-------------------------------------------------------------------------------
CMDSM_REG: process (Clk)
begin

    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE) then
            cmdsm_cs        <= IDLE;
            SDRAM_Idle      <= '1';        -- sdram idle indicates the state of the sdram
            Cmd_done        <= '0'; 
            pend_read_reg   <= '0';
            pend_write_reg  <= '0';
            read_state      <= '0';
            write_state     <= '0';
            wait4brstlen    <= '0'; 

            reg_sdram_addr      <= (others => '0');
            reg_sdram_bankaddr  <= (others => '0');
            reg_sdram_rasn      <= '1';
            reg_sdram_casn      <= '1';
            reg_sdram_wen       <= '1';
            reg_dqm_rst         <= '1';
            reg_dqm_set         <= '0';
            
            bus2ip_cs_d1        <= Bus2IP_CS;

        else
            cmdsm_cs        <= cmdsm_ns;
            wait4brstlen    <=   wait4brstlen_cmb; 

            if rst_read_state = '1' then
                read_state <= '0';
            else
                read_state <= read_state_cmb;
            end if;
            if rst_write_state = '1' then
                write_state <= '0';
            else
                write_state <= write_state_cmb;
            end if;
            if cmdsm_ns <= IDLE then
                SDRAM_Idle <= '1';
            else
                SDRAM_Idle <= '0';
            end if;
            Cmd_done <= cmd_done_cmb; 
--            if Rst_pend_rd = RESET_ACTIVE then
--                pend_read_reg <= '0';
--            elsif pend_read_cmb = '1' then
--                pend_read_reg <= '1';
--            end if;
--            if Rst_pend_wr = RESET_ACTIVE then
--                pend_write_reg <= '0';
--            elsif pend_write_cmb = '1' then 
--                pend_write_reg <= '1';
--            end if;
            pend_read_reg  <= pend_read_cmb;
            pend_write_reg <= pend_write_cmb;

            reg_sdram_addr      <= sdram_addr_i;
            reg_sdram_bankaddr  <= sdram_bankaddr_i;
            reg_sdram_rasn      <= RCW_cmd(0);
            reg_sdram_casn      <= RCW_cmd(1);
            reg_sdram_wen       <= RCW_cmd(2);
            reg_dqm_rst         <= dqm_rst_cmb;
            reg_dqm_set         <= dqm_set_cmb;
        end if;
    end if;
end process CMDSM_REG;    

Reset_pendwrreq <= reset_pendwrreq_cmb;
Reset_pendrdreq <= reset_pendrdreq_cmb;

Wr_AddrAck      <= wr_addrack_cmb;
Rd_AddrAck      <= rd_addrack_cmb;

-------------------------------------------------------------------------------
-- Read Pause Register
-------------------------------------------------------------------------------
BURST_GEN : if C_INCLUDE_BURSTS = 1 generate
reg_pause : process (Clk)
        begin
            if (Clk'event and Clk = '1') then
                if (Rst = RESET_ACTIVE) then
                    read_pause_i <= '0';
                else
                    if Data_done = '1' then
                        read_pause_i <= '0';
                    else
                        read_pause_i <= read_pause_cmb;
                    end if;
                end if; -- if Rst
            end if; -- if Clk'event
        end process reg_pause;
end generate;

NO_BURST_GEN : if C_INCLUDE_BURSTS = 0 generate
    read_pause_i <= '0'; 
end generate;


-- GAB 06/03/05
-- Added to fix issue with state machine hanging when
-- write burst was interrupted by refresh cycle at end of burst
-- and when a write burst or read burst ended at a row or bank
-- boundry crossing
GEN_FOR_OPB : if C_OPB_BUS = 1 and C_INCLUDE_BURSTS = 1 generate

    WR_NOT_FINISHED : process(Clk)
        begin
            if (Clk'event and Clk = '1') then
                if (Rst = RESET_ACTIVE) then
                    write_not_done <= '0';
                else
                    if(rst_wr_not_done = '1')then
                        write_not_done <= '0';
                    elsif(set_wr_not_done = '1')then
                        write_not_done <= '1';
                    end if;
                end if;
            end if;
        end process WR_NOT_FINISHED;

    RD_NOT_FINISHED : process(Clk)
        begin
            if (Clk'event and Clk = '1') then
                if (Rst = RESET_ACTIVE) then
                    read_not_done <= '0';
                else
                    if(rst_rd_not_done = '1')then
                        read_not_done <= '0';
                    elsif(set_rd_not_done = '1')then
                        read_not_done <= '1';
                    end if;
                end if;
            end if;
        end process RD_NOT_FINISHED;

end generate;

GEN_NOT_OPB : if C_OPB_BUS = 0 or C_INCLUDE_BURSTS = 0 generate
    write_not_done  <= '0';
    read_not_done   <= '0';
end generate;

-------------------------------------------------------------------------------
-- Register signals to the SDRAM if C_INCLUDE_HIGHSPEED_PIPE is asserted
-- otherwise, output them combinationally
-------------------------------------------------------------------------------
--NO_HIGHSPEED_PIPE_GEN: if C_INCLUDE_HIGHSPEED_PIPE=0 generate
--    SDRAM_Addr      <= sdram_addr_i;
--    SDRAM_BankAddr  <= sdram_bankaddr_i;
--    SDRAM_RASn      <= RCW_cmd(0);
--    SDRAM_CASn      <= RCW_cmd(1);
--    SDRAM_WEn       <= RCW_cmd(2);
--    DQM_rst         <= dqm_rst_cmb;
--    DQM_set         <= dqm_set_cmb;
--end generate NO_HIGHSPEED_PIPE_GEN;
--
--HIGHSPEED_PIPE_GEN: if C_INCLUDE_HIGHSPEED_PIPE=1 generate
--
--    HIGHSPEED_PIPE_PROCESS: process (Clk)
--        begin
--            if Clk'event and Clk = '1' then
--                if Rst = RESET_ACTIVE then
--                    SDRAM_Addr      <= (others => '0');
--                    SDRAM_BankAddr  <= (others => '0');
--                    SDRAM_RASn      <= '1';
--                    SDRAM_CASn      <= '1';
--                    SDRAM_WEn       <= '1';
--                    DQM_rst         <= '1';
--                    DQM_set         <= '0';
--                else
--                    SDRAM_Addr      <= sdram_addr_i;
--                    SDRAM_BankAddr  <= sdram_bankaddr_i;
--                    SDRAM_RASn      <= RCW_cmd(0);
--                    SDRAM_CASn      <= RCW_cmd(1);
--                    SDRAM_WEn       <= RCW_cmd(2);
--                    DQM_rst         <= dqm_rst_cmb;
--                    DQM_set         <= dqm_set_cmb;
--                end if;
--        end if;
--    end process HIGHSPEED_PIPE_PROCESS;
--end generate HIGHSPEED_PIPE_GEN;

NO_HIGHSPEED_PIPE_GEN: if C_INCLUDE_HIGHSPEED_PIPE=0 generate
    SDRAM_Addr      <= reg_sdram_addr;    
    SDRAM_BankAddr  <= reg_sdram_bankaddr;
    SDRAM_RASn      <= reg_sdram_rasn;    
    SDRAM_CASn      <= reg_sdram_casn;    
    SDRAM_WEn       <= reg_sdram_wen;     
    DQM_rst         <= reg_dqm_rst;      
    DQM_set         <= reg_dqm_set;       
end generate NO_HIGHSPEED_PIPE_GEN;

HIGHSPEED_PIPE_GEN: if C_INCLUDE_HIGHSPEED_PIPE=1 generate

    HIGHSPEED_PIPE_PROCESS: process (Clk)
        begin
            if Clk'event and Clk = '1' then
                if Rst = RESET_ACTIVE then
                    SDRAM_Addr      <= (others => '0');
                    SDRAM_BankAddr  <= (others => '0');
                    SDRAM_RASn      <= '1';
                    SDRAM_CASn      <= '1';
                    SDRAM_WEn       <= '1';
                    DQM_rst         <= '1';
                    DQM_set         <= '0';
                else
                    SDRAM_Addr      <= reg_sdram_addr;    
                    SDRAM_BankAddr  <= reg_sdram_bankaddr;
                    SDRAM_RASn      <= reg_sdram_rasn;    
                    SDRAM_CASn      <= reg_sdram_casn;    
                    SDRAM_WEn       <= reg_sdram_wen;     
                    DQM_rst         <= reg_dqm_rst;      
                    DQM_set         <= reg_dqm_set;       
                end if;
        end if;
    end process HIGHSPEED_PIPE_PROCESS;
end generate HIGHSPEED_PIPE_GEN;
                    
end imp;

