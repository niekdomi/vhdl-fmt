-------------------------------------------------------------------------------
-- $Id: sdram_controller.vhd,v 1.6 2005/06/03 14:27:35 gburch Exp $
-------------------------------------------------------------------------------
-- sdram_controller.vhd - entity/architecture pair
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
-- Filename:        sdram_controller.vhd
-- Version:         v1.00e
-- Description:     sdram controller with IPIC interface
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
-------------------------------------------------------------------------------
-- @BEGIN_CHANGELOG EDK_H_SP1
--
--  - Fixed problem with data state machine getting out of sync with the 
--    command state machine.
--
--  - Fixed problem with cycle not being timed correctly when the clock period
--    was slow relative to the timing parameters.
--
--  - Fixed problem with command state machine getting hung up in the Load
--    Mode state if the SDRAM was accessed prior to initialization being 
--    completed.  Subsequent accesses would continually result in a
--    retry being issued by the memory controller. This problem only affected
--    opb_sdram.
--
-- @END_CHANGELOG
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- @BEGIN_CHANGELOG EDK_H_SP2
--
-- Fixed problem with the command state machine getting stuck when a 
-- refresh cycle interrupted a write burst cycle at the end of the 
-- burst or when a read or write burst cycle crossed a row or bank boundary
-- on the last data beat of the burst.  This only affects opb_sdram.
--
-- Fixed issue where rearbitration was not occurring as specified by the 
-- core specification during SDRAM initialization.  This only affects 
-- plb_sdram.
--
-- @END_CHANGELOG
-------------------------------------------------------------------------------
-- Author:          ALS
-- History:
--   ALS           06/10/02    First Version
-- ^^^^^^
--      First version of sdram controller
-- ~~~~~~
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--  ALS             03/31/03    
-- ^^^^^^
--  Added generic to allow use of either positive edge or negative edge output
--  registers and another generic to allow setting of the simulation initialization
--  time. Added output SDRAM_INIT_DONE to indicate that the initialization period
--  has completed. ToutSup is now asserted when Bus2IP_CS asserts. ErrAck is no
--  longer asserted during initialization in response to transactions.
-- ~~~~~~
--  ALS             10/06/03    Version D            
-- ^^^^^^
-- Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
-- for new PLB IPIF.
-- ~~~~~~
--  GAB             11/26/03
-- ^^^^^^
-- Finished adding PLB burst support, and multiple SDRAM width logic
-- Improved read cycle and write cycle latency
-- ~~~~~~
--  GAB             10/29/04    Version E
-- ^^^^^^
--  Improved slows paths throughout design. 
--
--  Updated to use proc_common_v2_00_a library
--
--  Moved Twr_load and Twr_cnt_en from data_statemachine to command_statemachine
-- ~~~~~~
--  GAB             02/09/05
-- ^^^^^^
--  Fixed problem with data_done not being reset correctly which caused
--  the data statemachine to get out of sync with the command statemachine
--  Modified command_statemachine.vhd and data_statemachine.vhd.
--  This fixes CR201881.  
--
--  Fixed problem when clock period was slow relative to the timing parameters.
--  When the counter's starting count was 0 the down counter would roll over to
--  all 1's and then count down to the terminal count of '1'.  This causes an
--  extra long time between the different phases of the sdram cycle. Modified
--  command_statemachine.vhd, counters.vhd, and sdram_controller.vhd. This 
--  fixes CR199798.
--
--  Removed retry in the LOAD_MR_CMD state and the check for negation of 
--  Bus2IP_CS.  This fixes a problem where the command statemachine would
--  get stuck in the Load Mode Register state if the sdram was accessed
--  during initialization.  Modified command_statemachine.vhd. This
--  fixes CR203354
--
-- ~~~~~~
--  GAB             03/31/05
-- ^^^^^^
--  Fixed issue with command state machine getting hung in the ACT_CMD state
--  when Trefi_end occured at the last data beat of a write burst.  On 
--  OPB_SDRAM, WrReq would negate before the refresh completed thus the write
--  cycle would fail to complete.  In the hung state, the opb_ipif would issue
--  retries because the write buffer still held data.
--  A similar issue would also occur if a read burst or write burst ended at
--  a row or bank boundary.  This fixes CR209179.
--
--  Modified IP2Bus_Busy to drive busy regardless of Bus2IP_CS in ipic_if.vhd.
--  First cycles plb_ipif with write_buffer was sln_addrack 'ing an initial
--  cycle prior to SDRAM initialization when the ipif should have rearbitrated.
--  This fixes CR208645.
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

--  12.06.2006-le	add C_SDRAM_DRIVER_STRENGTH

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_bit.all;

library sdram_v1_00_e;
use sdram_v1_00_e.command_statemachine;
use sdram_v1_00_e.data_statemachine;
use sdram_v1_00_e.init_statemachine;
use sdram_v1_00_e.counters;
use sdram_v1_00_e.io_registers;
use sdram_v1_00_e.ipic_if;
use sdram_v1_00_e.clock_gen;

library proc_common_v2_00_a;
use proc_common_v2_00_a.proc_common_pkg.max2;
use proc_common_v2_00_a.proc_common_pkg.log2;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_INCLUDE_BURST_SUPPORT     -- supports bursts(cacheline) transfers
--      C_USE_POSEDGE_OUTREGS       -- use positive edge output registers if 1
--                                  -- use negative edge output registers if 0
--      C_INCLUDE_HIGHSPEED_PIPE    -- high frequency option (adds pipeline)
--                                  -- should be set to 0 if C_USE_POSEDGE_OUTREGS=1
--      C_FAMILY                    -- target FPGA family
--      C_SDRAM_TMRD                -- Load Mode Register command cycle time
--      C_SDRAM_TWR                 -- write recovery time
--      C_SDRAM_TCCD                -- read/write to read/write
--      C_SDRAM_TRAS                -- delay after ACTIVE command before
--                                  -- PRECHARGE command
--      C_SDRAM_TRC                 -- delay after ACTIVE command before
--                                  -- another ACTIVE or AUTOREFRESH command
--      C_SDRAM_TRFC                -- delay after AUTOREFRESH before another command
--      C_SDRAM_TRCD                -- delay after ACTIVE before READ/WRITE
--      C_SDRAM_TRRD                -- delay after ACTIVE row a before ACTIVE 
--                                  -- row b
--      C_SDRAM_TREF                -- refresh to refresh command interval
--      C_SDRAM_TREFI               -- average periodic refresh command interval
--      C_SDRAM_TRP                 -- delay after PRECHARGE command
--      C_SDRAM_CAS_LAT             -- CAS latency
--      C_SDRAM_DWIDTH              -- total SDRAM data width
--      C_SDRAM_AWIDTH              -- SDRAM row address width
--      C_SDRAM_COL_AWIDTH          -- SDRAM column address width
--      C_SDRAM_BANK_AWIDTH         -- SDRAM bank address width
--      C_SDRAM_BRST_LEN            -- SDRAM burst lenght (IPIF_DWIDTH/SDRAM_DWIDTH)
--      C_IPIF_DWIDTH               -- IPIC data width
--      C_IPIF_AWIDTH               -- IPIC address width
--      C_CLK_PERIOD                -- bus clock period in ps
--      C_OPB_BUS                   -- OPB bus 
--      C_PLB_BUS                   -- PLB bus
--      C_SIM_INIT_TIME_PS          -- initialization time for SIMULATION ONLY in pico-seconds
--
-- Definition of Ports:
--  -- IPIC
--    Bus2IP_Addr                   -- Processor bus address                
--    Bus2IP_BE                     -- Processor bus byte enables
--    Bus2IP_Data                   -- Processor data
--    Bus2IP_RNW                    -- Processor read not write
--    Bus2IP_RdReq                  -- Processor read request
--    Bus2IP_WrReq                  -- Processor write request
--    Bus2IP_Burst                  -- Processor burst
--    Bus2IP_IBurst                 -- Processor indeterminate burst
--    Bus2IP_CS                     -- SDRAM memory is being accessed
--
--    -- IPIC outputs
--    IP2Bus_Data                   -- Data to processor bus
--    IP2Bus_AddrAck                -- Address acknowledge
--    IP2Bus_RdAck                  -- Read acknowledge
--    IP2Bus_WrAck                  -- Write acknowledge
--    IP2Bus_Retry                  -- Retry indicator
--    IP2Bus_ToutSup                -- Suppress watch dog timer
--    IP2Bus_Busy                   -- IP Busy signal
--    
--    -- SDRAM interface signals
--    SDRAM_Clk                     -- SDRAM clock             
--    SDRAM_CKE                     -- SDRAM clock enable
--    SDRAM_CSn                     -- SDRAM chip select
--    SDRAM_RASn                    -- SDRAM row address strobe
--    SDRAM_CASn                    -- SDRAM column address strobe
--    SDRAM_WEn                     -- SDRAM write enable
--    SDRAM_DQM                     -- SDRAM data mask
--    SDRAM_BankAddr                -- SDRAM bank address
--    SDRAM_Addr                    -- SDRAM address
--    SDRAM_DQ_o                    -- SDRAM DQ output
--    SDRAM_DQ_i                    -- SDRAM DQ input
--    SDRAM_DQ_t                    -- SDRAM DQ output enable
--
--    -- Timer or interrrupt signals
--    SDRAM_Init_done               -- SDRAM power-up/reset initialization is
--                                  -- complete
--                                  
--    -- Clocks and reset          
--    SDRAM_Clk_in                  -- SDRAM clock feedback or PLB/OPB clock                 
--    Sys_Clk                       -- PLB/OPB clock
--    Rst                           -- Reset
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------

entity sdram_controller is
    generic (
        C_INCLUDE_BURST_SUPPORT   : integer  := 0;
        C_USE_POSEDGE_OUTREGS     : integer  := 0;
        C_INCLUDE_HIGHSPEED_PIPE  : integer  := 1;
        C_FAMILY                  : string   := "virtex2";
        C_SDRAM_TMRD              : integer  := 2;
        C_SDRAM_TWR               : integer  := 15000;
        C_SDRAM_TCCD              : integer  := 1;
        C_SDRAM_TRAS              : integer  := 40000;
        C_SDRAM_TRC               : integer  := 65000;
        C_SDRAM_TRFC              : integer  := 75000;
        C_SDRAM_TRCD              : integer  := 20000;
        C_SDRAM_TRRD              : integer  := 15000;
        C_SDRAM_TREF              : integer  := 64;
        C_SDRAM_TREFI             : integer  := 7812500;
        C_SDRAM_TRP               : integer  := 20000;
        C_SDRAM_CAS_LAT           : integer  := 2;
        C_SDRAM_DWIDTH            : integer  := 32;
        C_SDRAM_AWIDTH            : integer  := 13;
        C_SDRAM_COL_AWIDTH        : integer  := 9;
        C_SDRAM_BANK_AWIDTH       : integer  := 2;
        C_SDRAM_BRST_LEN          : integer  := 8;
        C_IPIF_DWIDTH             : integer  := 32; 
        C_IPIF_AWIDTH             : integer  := 32; 
        C_CLK_PERIOD              : integer  := 10000;
        C_OPB_BUS                 : integer  := 0;
        C_PLB_BUS                 : integer  := 1;
        -- the following generics are only used in simulation
        C_SIM_INIT_TIME_PS        : integer  := 100000000;  -- default to 100uS (real init time)
        C_SDRAM_DRIVER_STRENGTH : integer  := 0
     );  
  port (
        -- IPIC inputs
        Bus2IP_Addr         : in  std_logic_vector(0 to C_IPIF_AWIDTH-1);
        Bus2IP_BE           : in  std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
        Bus2IP_Data         : in  std_logic_vector(0 to C_IPIF_DWIDTH-1);
        Bus2IP_RNW          : in  std_logic;
        Bus2IP_RdReq        : in  std_logic;
        Bus2IP_WrReq        : in  std_logic;
        Bus2IP_Burst        : in  std_logic;
        Bus2IP_CS           : in  std_logic;


        -- IPIC outputs
        IP2Bus_Data         : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
        IP2Bus_AddrAck      : out std_logic;
        IP2Bus_RdAck        : out std_logic;
        IP2Bus_WrAck        : out std_logic;
        IP2Bus_ErrAck       : out std_logic;
        IP2Bus_Retry        : out std_logic;
        IP2Bus_ToutSup      : out std_logic;
        IP2Bus_Busy         : out std_logic;

        -- SDRAM interface signals
        SDRAM_Clk           : out std_logic;
        SDRAM_CKE           : out std_logic;
        SDRAM_CSn           : out std_logic;
        SDRAM_RASn          : out std_logic;
        SDRAM_CASn          : out std_logic;
        SDRAM_WEn           : out std_logic;
        SDRAM_DQM           : out std_logic_vector(0 to C_SDRAM_DWIDTH/8-1);
        SDRAM_BankAddr      : out std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
        SDRAM_Addr          : out std_logic_vector(0 to C_SDRAM_AWIDTH-1);
        SDRAM_DQ_o          : out std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        SDRAM_DQ_i          : in  std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        SDRAM_DQ_t          : out std_logic_vector(0 to C_SDRAM_DWIDTH-1);
        
        -- Timer/Interrupt signals
        SDRAM_Init_done     : out std_logic;

        -- Clocks and reset
        SDRAM_Clk_in        : in  std_logic;
        Sys_Clk             : in  std_logic;
        Rst                 : in  std_logic
    );
end entity sdram_controller;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of sdram_controller is
-----------------------------------------------------------------------------
-- Function declarations
-----------------------------------------------------------------------------
type INTEGER_ARRAY is array (natural range <>) of integer;
-- 
-- Function max returns the max integer in the array
--
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
--
-- Function get_init_clocks returns the number of clocks for the initialization
-- time. If simulation, the initialization time is set by C_SIM_INIT_TIME_PS.
-- Otherwise, it is 100us.
--
function get_init_clocks return integer is
    variable init_clocks : integer;
begin

    -- the following assignment is used in synthesis
    init_clocks := ((100000000-1)/C_CLK_PERIOD)+1;
    
    -- the following assignment is used in simulation
    -- synthesis translate off
    init_clocks := ((C_SIM_INIT_TIME_PS-1)/C_CLK_PERIOD)+1;
    -- synthesis translate on
    
    return init_clocks;
end get_init_clocks;
-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
-- create integer values of the delay parameters divided by clock frequency
-- to round values to next integer
constant SDRAM_TWR_CLKS    : integer range 1 to 31 := ((C_SDRAM_TWR-1)/C_CLK_PERIOD)+1;
constant SDRAM_TRAS_CLKS   : integer range 1 to 31 := ((C_SDRAM_TRAS-1)/C_CLK_PERIOD)+1;
constant SDRAM_TRC_CLKS    : integer range 1 to 31 := ((C_SDRAM_TRC-1)/C_CLK_PERIOD)+1;
constant SDRAM_TRFC_CLKS   : integer range 1 to 31 := ((C_SDRAM_TRFC-1)/C_CLK_PERIOD)+1;
constant SDRAM_TRCD_CLKS   : integer range 1 to 31 := ((C_SDRAM_TRCD-1)/C_CLK_PERIOD)+1;
constant SDRAM_TRRD_CLKS   : integer range 1 to 31 := ((C_SDRAM_TRRD-1)/C_CLK_PERIOD)+1;
constant SDRAM_TREFI_CLKS  : integer := ((C_SDRAM_TREFI-1)/C_CLK_PERIOD)+1;
constant SDRAM_TRP_CLKS    : integer range 1 to 31 := ((C_SDRAM_TRP-1)/C_CLK_PERIOD)+1;

constant CNT_100US_CLKS    : integer := get_init_clocks;

-- set width of counters
constant RCCNT_WIDTH    : integer := max2(1,log2(SDRAM_TRC_CLKS));
constant RRDCNT_WIDTH   : integer := max2(1,log2(SDRAM_TRRD_CLKS));
constant RASCNT_WIDTH   : integer := max2(1,log2(SDRAM_TRAS_CLKS));

-- width of the REFI and initialization counter is the max of the number of clocks for
-- REFI and initialization
constant REFICNT_WIDTH  : integer := max2(log2(SDRAM_TREFI_CLKS),log2(CNT_100US_CLKS+1));

constant WRCNT_WIDTH    : integer := max2(1,log2(SDRAM_TWR_CLKS));

constant MRDCNT_WIDTH     : integer := max2(1,log2(C_SDRAM_TMRD));
constant RFCCNT_WIDTH     : integer := max2(1,log2(SDRAM_TRFC_CLKS));
constant RPCNT_WIDTH      : integer := max2(1,log2(SDRAM_TRP_CLKS));
constant RCDCNT_WIDTH     : integer := max2(1,log2(SDRAM_TRCD_CLKS));
constant BRSTLENCNT_WIDTH : integer := max2(1,log2(C_SDRAM_BRST_LEN));

                                        
-- create std_logic_vectors for counter load values
constant RCCNT          : std_logic_vector(0 to RCCNT_WIDTH-1) :=
                        conv_std_logic_vector(SDRAM_TRC_CLKS-1, RCCNT_WIDTH);
constant RRDCNT         : std_logic_vector(0 to RRDCNT_WIDTH-1) :=
                        conv_std_logic_vector(SDRAM_TRRD_CLKS-1, RRDCNT_WIDTH);
constant RASCNT         : std_logic_vector(0 to RASCNT_WIDTH-1) :=
                        conv_std_logic_vector(SDRAM_TRAS_CLKS-1, RASCNT_WIDTH);
                        

-- Set REFICNT to SDRAM_TREFI_CLKS - X where X is enough margin 
-- to do a refresh properly knowing that the state machine may be in another command 
-- use the max of the margin and the refresh clocks for testing fast refresh rates 
-- counter is wide enough because it is sized for at least 200 clocks 
constant REF_MARGIN : integer   := 32; 
constant REF_CLKS   : integer   := max2(SDRAM_TREFI_CLKS-REF_MARGIN, REF_MARGIN); 
constant REFICNT    : std_logic_vector(0 to REFICNT_WIDTH-1) := 
                       conv_std_logic_vector(REF_CLKS-1, REFICNT_WIDTH); 


--constant ADJSTD_TWR     : integer := max2(0,SDRAM_TWR_CLKS-2);

constant WRCNT          : std_logic_vector(0 to WRCNT_WIDTH-1) :=
                        conv_std_logic_vector(SDRAM_TWR_CLKS-1,WRCNT_WIDTH);

constant ADJSTD_TWR     : integer := max2(0,SDRAM_TWR_CLKS-2);
constant ADJ_WRCNT      : std_logic_vector(0 to WRCNT_WIDTH-1) :=
                        conv_std_logic_vector(ADJSTD_TWR,WRCNT_WIDTH);



constant CNT_100US      : std_logic_vector(0 to REFICNT_WIDTH-1) :=
                        conv_std_logic_vector(CNT_100US_CLKS, REFICNT_WIDTH);

constant MRDCNT         : std_logic_vector(0 to MRDCNT_WIDTH-1) :=
                        conv_std_logic_vector(C_SDRAM_TMRD-1, MRDCNT_WIDTH);

constant RFCCNT         : std_logic_vector(0 to RFCCNT_WIDTH-1) :=
                        conv_std_logic_vector(SDRAM_TRFC_CLKS-1, RFCCNT_WIDTH);


constant ADJSTD_TRP     : integer := max2(0,SDRAM_TRP_CLKS-2);
constant RPCNT          : std_logic_vector(0 to RPCNT_WIDTH-1) :=
                        conv_std_logic_vector(ADJSTD_TRP, RPCNT_WIDTH);

                       
constant RCDCNT         : std_logic_vector(0 to RCDCNT_WIDTH-1) :=
                        conv_std_logic_vector(SDRAM_TRCD_CLKS-1, RCDCNT_WIDTH);
                        
constant BRSTLENCNT     : std_logic_vector(0 to BRSTLENCNT_WIDTH-1) :=
                        conv_std_logic_vector(C_SDRAM_BRST_LEN-1, BRSTLENCNT_WIDTH);

-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
signal trc_load             : std_logic;
signal trrd_load            : std_logic;
signal tras_load            : std_logic;
signal trefi_load           : std_logic;
signal gpcnt_end            : std_logic;
signal trc_end              : std_logic;
signal trrd_end             : std_logic;
signal tras_end             : std_logic;
signal trefi_pwrup_end      : std_logic;
signal twr_load             : std_logic;
signal twr_cnt_en           : std_logic;
signal twr_end              : std_logic;
signal twr_rst              : std_logic;
signal sdram_brst_end       : std_logic;  
signal Trfc_end             : std_logic;
signal Trcd_end             : std_logic;
signal Tmrd_end             : std_logic;
signal Trp_end              : std_logic;
signal Tbrstlen_end         : std_logic;
signal Trfc_load            : std_logic;
signal Trcd_load            : std_logic;
signal Tmrd_load            : std_logic;
signal Trp_load             : std_logic;
signal Tbrstlen_load        : std_logic;

signal refresh              : std_logic;
signal precharge            : std_logic;
signal load_mr              : std_logic;
signal register_data        : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal register_sel         : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
signal cmd_done             : std_logic;  
signal init_done            : std_logic;

signal data_done            : std_logic;
signal rst_data_done        : std_logic;
signal write_data           : std_logic_vector(0 to C_SDRAM_DWIDTH-1);
signal write_data_mask      : std_logic_vector(0 to C_SDRAM_DWIDTH/8-1);
signal dqm_rst              : std_logic;
signal dqm_set              : std_logic;
signal write_data_en        : std_logic;
signal sdram_readdata       : std_logic_vector(0 to C_SDRAM_DWIDTH-1);
signal read_data            : std_logic_vector(0 to C_IPIF_DWIDTH-1);

signal rdack                : std_logic;
signal wrack                : std_logic;
signal rd_addrack           : std_logic;
signal wr_addrack           : std_logic;
signal errack               : std_logic;
signal retry                : std_logic;
signal toutsup              : std_logic;
signal read_op              : std_logic;
signal write_op             : std_logic;
signal burst                : std_logic;
signal read_pause           : std_logic;

signal row_addr             : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal col_addr             : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal bank_addr            : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);
signal ipic_wrdata          : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal ipic_be              : std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
signal pend_rdreq           : std_logic;
signal pend_wrreq           : std_logic;
signal same_row             : std_logic;
signal same_bank            : std_logic;
signal same_rowbank_regce   : std_logic;
signal reset_pendrdreq      : std_logic;
signal reset_pendwrreq      : std_logic;
signal sdram_idle           : std_logic;

signal pend_read            : std_logic;
signal pend_write           : std_logic;
signal rst_pend_rd          : std_logic;
signal rst_pend_wr          : std_logic;

signal bus2ip_rdreq_d1      : std_logic;
signal bus2ip_wrreq_d1      : std_logic;

signal rasn                 : std_logic;
signal casn                 : std_logic;
signal wen                  : std_logic;
signal addr                 : std_logic_vector(0 to C_SDRAM_AWIDTH-1);
signal bankaddr             : std_logic_vector(0 to C_SDRAM_BANK_AWIDTH-1);


-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  -- architecture imp

-- assign output signals
SDRAM_Init_done <= init_done;

-- assign constant signals
SDRAM_CSn <= '0';


-- Instantiate the components
CMDSM_I: entity sdram_v1_00_e.command_statemachine 
  generic map ( C_SDRAM_AWIDTH        => C_SDRAM_AWIDTH,
                C_SDRAM_COL_AWIDTH    => C_SDRAM_COL_AWIDTH,                
                C_SDRAM_BANK_AWIDTH   => C_SDRAM_BANK_AWIDTH,                
                C_OPB_BUS             => C_OPB_BUS,             
                C_PLB_BUS             => C_PLB_BUS,             
                C_INCLUDE_HIGHSPEED_PIPE => C_INCLUDE_HIGHSPEED_PIPE,
                C_INCLUDE_BURSTS      => C_INCLUDE_BURST_SUPPORT
                )                 
  port map(
        Bus2IP_CS               => Bus2IP_CS        ,
        Burst                   => burst            ,
        Row_addr                => row_addr         ,
        Col_addr                => col_addr         ,
        Bank_addr               => bank_addr        ,
        Pend_rdreq              => pend_rdreq       ,
        Pend_wrreq              => pend_wrreq       ,
        Same_row                => same_row         ,
        Same_bank               => same_bank        ,
        Read_op                 => read_op          ,
        Write_op                => write_op         ,
        Retry                   => retry            ,
        Toutsup                 => toutsup          ,
        Reset_pendrdreq         => reset_pendrdreq  ,
        Reset_pendwrreq         => reset_pendwrreq  ,
        SDRAM_idle              => sdram_idle       ,
        Rd_AddrAck              => rd_addrack       ,
        Wr_AddrAck              => wr_addrack       ,
        Same_rowbank_regce      => same_rowbank_regce ,
        ErrAck                  => errack           ,
        Refresh                 => refresh          ,
        Precharge               => precharge        ,
        Load_mr                 => load_mr          ,
        Register_data           => register_data    ,
        Register_sel            => register_sel     ,
        Init_done               => init_done        ,
        Cmd_done                => cmd_done         ,
        Data_done               => data_done        ,
        Rst_data_done           => rst_data_done    ,
        Pend_write              => pend_write       ,
        Rst_pend_wr             => rst_pend_wr      ,
        Pend_read               => pend_read        ,
        Rst_pend_rd             => rst_pend_rd      ,
        Read_pause              => Read_pause       ,
        Trefi_end               => trefi_pwrup_end  ,
        Trc_end                 => trc_end         ,
        Trrd_end                => trrd_end         ,
        Tras_end                => tras_end         ,
        Twr_end                 => twr_end          ,
        Trfc_end                => Trfc_end         ,
        Trcd_end                => Trcd_end         ,
        Tmrd_end                => Tmrd_end         ,
        Trp_end                 => Trp_end          ,
        Tbrstlen_end            => Tbrstlen_end     ,
        SDRAM_brst_end          => sdram_brst_end   ,
        Trefi_load              => trefi_load       ,
        Trc_load                => trc_load         ,
        Trrd_load               => trrd_load        ,
        Tras_load               => tras_load        ,
        Twr_cnt_en              => twr_cnt_en       ,
        Twr_load                => twr_load         ,
        Twr_rst                 => twr_rst          ,
        Trfc_load               => Trfc_load        ,
        Trcd_load               => Trcd_load        ,
        Tmrd_load               => Tmrd_load        ,
        Trp_load                => Trp_load         ,
        Tbrstlen_load           => Tbrstlen_load    ,
        SDRAM_RASn              => rasn             ,
        SDRAM_CASn              => casn             ,
        SDRAM_WEn               => wen              ,
        SDRAM_Addr              => addr             ,
        SDRAM_BankAddr          => bankaddr         ,
        DQM_rst                 => dqm_rst          ,
        DQM_set                 => dqm_set          ,
        Clk                     => Sys_Clk          ,
        Rst                     => Rst               
      );                        


INITSM_I: entity sdram_v1_00_e.init_statemachine 
  generic map ( C_SDRAM_AWIDTH        =>  C_SDRAM_AWIDTH     ,    
                C_SDRAM_BANK_AWIDTH   =>  C_SDRAM_BANK_AWIDTH,    
                C_SDRAM_BRST_LEN      =>  C_SDRAM_BRST_LEN  ,    
                C_SDRAM_CAS_LAT       =>  C_SDRAM_CAS_LAT,
                C_SDRAM_DRIVER_STRENGTH => C_SDRAM_DRIVER_STRENGTH)
  port map(
    Cmd_done            =>   cmd_done       ,                                           
    Trefi_pwrup_end     =>   trefi_pwrup_end,                                           
    Precharge           =>   precharge      ,                                           
    Load_mr             =>   load_mr        ,                                           
    Refresh             =>   refresh        ,                                           
    Register_data       =>   register_data  ,                                           
    Register_sel        =>   register_sel   , 
    Init_done           =>   init_done      ,
    SDRAM_CKE           =>   SDRAM_CKE      ,
    Clk                 =>   Sys_Clk        ,                                           
    Rst                 =>   Rst                                                        
    );

CNTRS_I: entity sdram_v1_00_e.counters 
  generic map ( 
                C_RFCCNT_WIDTH      => RFCCNT_WIDTH     ,
                C_RCDCNT_WIDTH      => RCDCNT_WIDTH     ,
                C_MRDCNT_WIDTH      => MRDCNT_WIDTH     ,
                C_RPCNT_WIDTH       => RPCNT_WIDTH      ,
                C_BRSTLENCNT_WIDTH  => BRSTLENCNT_WIDTH ,
  
                C_RCCNT_WIDTH       =>  RCCNT_WIDTH ,
                C_RRDCNT_WIDTH      =>  RRDCNT_WIDTH ,
                C_RASCNT_WIDTH      =>  RASCNT_WIDTH ,
                C_REFICNT_WIDTH     =>  REFICNT_WIDTH,
                C_WRCNT_WIDTH       =>  WRCNT_WIDTH  ,

                C_RFCCNT            => RFCCNT       ,
                C_RCDCNT            => RCDCNT       ,
                C_MRDCNT            => MRDCNT       ,
                C_RPCNT             => RPCNT        ,
                C_BRSTLENCNT        => BRSTLENCNT   ,


                C_RCCNT             =>  RCCNT       ,
                C_RRDCNT            =>  RRDCNT       ,
                C_RASCNT            =>  RASCNT       ,
                C_REFICNT           =>  REFICNT      ,
                C_100US_CNT         =>  CNT_100US    ,
                C_WRCNT             =>  WRCNT        ,    
                C_ADJWRCNT          =>  ADJ_WRCNT 
            )
  port map (
        Trc_load                => trc_load         ,                                           
        Trrd_load               => trrd_load         ,                                           
        Tras_load               => tras_load         ,                                           
        Trefi_load              => trefi_load        ,                                           
        Init_done               => init_done         ,
        Twr_load                => twr_load          ,
        Twr_cnt_en              => twr_cnt_en        ,
        Twr_rst                 => twr_rst           ,
        Trfc_load               => Trfc_load        ,
        Trcd_load               => Trcd_load        ,
        Tmrd_load               => Tmrd_load        ,
        Trp_load                => Trp_load         ,
        Tbrstlen_load           => Tbrstlen_load    ,
        SDRAM_brst_end          => sdram_brst_end    ,
        Trc_end                 => trc_end          ,                                           
        Trrd_end                => trrd_end          ,                                           
        Tras_end                => tras_end          ,                                           
        Trefi_pwrup_end         => trefi_pwrup_end   ,                                           
        Twr_end                 => twr_end           ,                                           
        Trfc_end                => Trfc_end         ,
        Trcd_end                => Trcd_end         ,
        Tmrd_end                => Tmrd_end         ,
        Trp_end                 => Trp_end          ,
        Tbrstlen_end            => Tbrstlen_end     ,
        Clk                     => Sys_Clk            ,                                           
        Rst                     => Rst                                                           
    );

DATASM_I: entity sdram_v1_00_e.data_statemachine 
  generic map ( C_SDRAM_DWIDTH              => C_SDRAM_DWIDTH,
                C_SDRAM_BRST_LEN            => C_SDRAM_BRST_LEN,
                C_SDRAM_CAS_LAT             => C_SDRAM_CAS_LAT,      
                C_USE_POSEDGE_OUTREGS       => C_USE_POSEDGE_OUTREGS,
                C_INCLUDE_HIGHSPEED_PIPE    => C_INCLUDE_HIGHSPEED_PIPE,
                C_IPIF_DWIDTH               => C_IPIF_DWIDTH,
                C_INCLUDE_BURSTS            => C_INCLUDE_BURST_SUPPORT)
  port map (
        -- inputs
        IPIC_wrdata         =>  ipic_wrdata     , 
        IPIC_be             =>  ipic_be         ,
        SDRAM_ReadData      =>  sdram_readdata  ,
        Pend_write          =>  pend_write      ,                                            
        Pend_read           =>  pend_read       ,                                            
        Bus2IP_RNW          =>  Bus2IP_RNW      , 
        Bus2IP_Burst        =>  Bus2IP_Burst    ,
        Bus2IP_CS           =>  Bus2IP_CS       ,
        Twr_end             =>  twr_end         ,
        Rst_data_done       =>  rst_data_done   ,
        WrAck               =>  WrAck           ,                                            
        RdAck               =>  rdack           ,
        Read_data           =>  read_data       ,
        Write_data_en       =>  write_data_en   ,
        Write_data          =>  write_data      ,
        Write_data_mask     =>  write_data_mask ,
        Data_done           =>  data_done       , 
        SDRAM_brst_end      =>  sdram_brst_end  ,                                            
        Read_pause          =>  Read_pause      ,
        Rst_pend_rd         =>  rst_pend_rd     ,
        Rst_pend_wr         =>  rst_pend_wr     ,

        Clk                 =>  Sys_Clk         ,                                            
        Rst                 =>  Rst                                                        
    );

IO_REG_I: entity sdram_v1_00_e.io_registers 
  generic map ( C_SDRAM_AWIDTH        => C_SDRAM_AWIDTH,
                C_SDRAM_BANK_AWIDTH   => C_SDRAM_BANK_AWIDTH,  
                C_SDRAM_DWIDTH        => C_SDRAM_DWIDTH,       
                C_IPIF_DWIDTH         => C_IPIF_DWIDTH,
                C_FAMILY              => C_FAMILY,
                C_USE_POSEDGE_OUTREGS => C_USE_POSEDGE_OUTREGS
                )
  port map(
        Write_data          => write_data     , 
        Write_data_en       => write_data_en  , 
        Write_data_mask     => write_data_mask, 
        DQM_rst             => dqm_rst      ,
        DQM_set             => dqm_set      ,
        RASn                => rasn           , 
        CASn                => casn           , 
        WEn                 => wen            , 
        BankAddr            => bankaddr       , 
        Addr                => addr           ,
        SDRAM_ReadData      => sdram_readdata   ,
        SDRAM_DQ_i          => SDRAM_DQ_i       ,
        SDRAM_DQ_o          => SDRAM_DQ_o       , 
        SDRAM_DQ_t          => SDRAM_DQ_t       , 
        SDRAM_DQM           => SDRAM_DQM        , 
        SDRAM_RASn          => SDRAM_RASn       , 
        SDRAM_CASn          => SDRAM_CASn       , 
        SDRAM_WEn           => SDRAM_WEn        , 
        SDRAM_BankAddr      => SDRAM_BankAddr   , 
        SDRAM_Addr          => SDRAM_Addr       , 
        Clk                 => Sys_Clk          , 
        Rst                 => rst              
    );

IPIC_IF_I: entity sdram_v1_00_e.ipic_if 
  generic map ( C_SDRAM_AWIDTH        => C_SDRAM_AWIDTH , 
                C_SDRAM_DWIDTH        => C_SDRAM_DWIDTH,
                C_SDRAM_COL_AWIDTH    => C_SDRAM_COL_AWIDTH, 
                C_SDRAM_BANK_AWIDTH   => C_SDRAM_BANK_AWIDTH,
                C_INCLUDE_BURSTS      => C_INCLUDE_BURST_SUPPORT,
                C_IPIF_AWIDTH         => C_IPIF_AWIDTH ,   
                C_IPIF_DWIDTH         => C_IPIF_DWIDTH 
                )
  port map (
        Bus2IP_CS               =>  Bus2IP_CS        ,
        Bus2IP_RNW              =>  Bus2IP_RNW       ,
        Bus2IP_Addr             =>  Bus2IP_Addr      ,
        Bus2IP_Burst            =>  Bus2IP_Burst     ,
        Bus2IP_Data             =>  Bus2IP_Data      ,
        Bus2IP_BE               =>  Bus2IP_BE        ,
        Bus2IP_RdReq            =>  Bus2IP_RdReq     ,
        Bus2IP_WrReq            =>  Bus2IP_WrReq     ,
        IP2Bus_ErrAck           =>  IP2Bus_ErrAck    ,
        IP2Bus_Retry            =>  IP2Bus_Retry     ,
        IP2Bus_Busy             =>  IP2Bus_Busy      ,
        IP2Bus_AddrAck          =>  IP2Bus_AddrAck   ,
        IP2Bus_WrAck            =>  IP2Bus_WrAck     ,
        IP2Bus_RdAck            =>  IP2Bus_RdAck     ,
        IP2Bus_ToutSup          =>  IP2Bus_ToutSup   ,
        IP2Bus_data             =>  IP2Bus_data      ,
        WrAck                   =>  wrack            ,
        RdAck                   =>  rdack            ,
        Rd_Addrack              =>  rd_addrack       ,
        Wr_AddrAck              =>  wr_addrack       ,
        ErrAck                  =>  errack           ,             
        Toutsup                 =>  toutsup          ,             
        Read_data               =>  read_data        ,
        Retry                   =>  retry            ,
        Init_done               =>  init_done        ,
        Read_op                 =>  read_op          ,
        Write_op                =>  write_op         ,
        IPIC_wrdata             =>  ipic_wrdata      ,
        IPIC_be                 =>  ipic_be          ,
        Burst                   =>  burst            ,
        Reset_pendrdreq         =>  reset_pendrdreq  ,
        Reset_pendwrreq         =>  reset_pendwrreq  ,
        SDRAM_idle              =>  sdram_idle       ,
        Row_addr                =>  row_addr         ,
        Col_addr                =>  col_addr         ,
        Bank_addr               =>  bank_addr        ,
        Pend_rdreq              =>  pend_rdreq       ,
        Pend_wrreq              =>  pend_wrreq       ,
        Pend_write              =>  pend_write      ,                                            
        Pend_read               =>  pend_read       ,                                            
        Same_row                =>  same_row         ,
        Same_bank               =>  same_bank        ,
        Same_rowbank_regce      => same_rowbank_regce ,
        Clk                     =>  Sys_Clk          ,
        Rst                     =>  rst              
      );

CLKGEN_I: entity sdram_v1_00_e.clock_gen 
  port map (
        Sys_clk             =>  Sys_clk,             
        SDRAM_Clk_in        =>  SDRAM_Clk_in,             
        Clk                 =>  open,             
        SDRAM_Clk           =>  SDRAM_Clk                     
    );

end imp;

