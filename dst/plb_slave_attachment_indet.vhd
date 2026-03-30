-------------------------------------------------------------------------------
-- $Id: plb_slave_attachment_indet.vhd,v 1.8 2006/08/31 14:28:45 avinasht Exp $
-------------------------------------------------------------------------------
-- PLB Slave attachment entity and architecture
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
-- Filename:        plb_slave_attachment_indet.vhd
-- Version:         v1_00_a
-- Description:     PLB slave attachment supporting single beat transfers,
--                  cache line, fixed length, and indeterminate bursts. Design
--                  supports high speed data transfer (1 clock per data beat)
--                  on the cacheline and burst transfers.
--                  This module is written to IEEE-93 vhdl specs.
--
-------------------------------------------------------------------------------
-- Structure:
--
--              plb_slave_attachment_indet.vhd
--                   |
--                   |- plb_address_decoder.vhd
--                   |
--                   |- addr_reg_cntr_brst_flex.vhd
--                   |        |
--                   |        |-- flex_counter.vhd
--                   |
--                   |
--                   |- srl_fifo2.vhd


-------------------------------------------------------------------------------
-- Author:      DET
-- History:
--  det     - Jan-17-2002 Initial version
--
--  det     - Feb-05-2002
-- ~~~~~~
--          - Full address decoder inclusion
--          - Address counter/register inclusion
--          - BE fix for cache line and burst transfers
-- ^^^^^^
--
--  det     - Feb-12-2002
-- ~~~~~~
--            - Timing changes to fix RdCE and RdReq relationship
--            - Timing changes to fix WrCE and WrReq relationship
--            - Other timing improvements in the address controller SM
-- ^^^^^^
--
--  det     - Feb-24-2002
-- ~~~~~~
--            - Change all async reset processes to sync reset processes.
-- ^^^^^^
--
--  det     - Mar-01-2002
-- ~~~~~~
--            - Fixed Master ID problem. Needed to latch and hold through
--              data phase completion.
-- ^^^^^^
--
--     DET     4/2/2002     PLB Burst Mods
-- ~~~~~~
--     - Incorporated the new addr_reg_cntr_brst component
-- ^^^^^^
--
--     DET     5/21/2002     Determinate TIming Transfers
-- ~~~~~~
--     - Added determinate timing function to IPIF interface.
-- ^^^^^^
--
--     DET     6/17/2002     Determinate Timing Cleanup
-- ~~~~~~
--     - Implemented MUX2SA_ToutSup input. It now will disable the
--       Data Phase WDT.
--     - Added the 'OMIT_BURST' If-Gen logic.
-- ^^^^^^
--
--
--     DET     7/22/2002     Determinate Timing Cleanup
-- ~~~~~~
--     - Corrected a problem with burst writes in Detirminate Timing
--  mode 0 (off) when the target temporarily withholds IP2Bus_WrAck
--  on the last data cycle of the burst.
-- ^^^^^^
--
--     DET     7/25/2002     Determinate Timing Cleanup
-- ~~~~~~
--     - Changed the GENERATE_SL_ERR process in the include burst generate
--  code to use the Response_Ack_i signal to enable clocking of the target
--  error reply to the PLB Bus.
-- ^^^^^^
--
--
--     DET     7/31/2002     Assertion debug support
-- ~~~~~~
--     - Added VHDL checking of data timeout, error, and retry assertions. Also
--  added checking of attempted indetirminate burst transfers and burst
--  transfers (when bursting is not enabled).
-- ^^^^^^
--
--     DET     8/13/2002     V1_00_b
-- ~~~~~~
--     - Corrected a problem with the data timeout during detirminate timing
--  operation (mode 2).
-- ^^^^^^
--
--
--     DET     8/29/2002     v1_00_b
-- ~~~~~~
--     - A problem was corrected in the non-burst code where the CS bus out
--  of the address decoder (the same as Bus2IP_CS) was inadvertently getting
--  set during a rearbitrate condition. This caused a problem for PLB SDRAM
--  because it was keying off of the rising edge of CS to initiate SDRAM access.
-- ^^^^^^
--
--
--     DET     9/3/2002     PLB Abort Revamp
-- ~~~~~~
--     - Beefed up PLB Abort functionality in the non-burst code section.
-- ^^^^^^
--
--
--     DET     9/4/2002     PLB Abort Revamp
-- ~~~~~~
--     - Beefed up PLB Abort functionality in the burst code section.
-- ^^^^^^
--
--
--
--     DET     11/19/2002     plb ipif Rev C update
-- ~~~~~~
--     - Changed the ipif_common library reference to ipif_common_v1_00_b.
-- ^^^^^^
--
--
--     DET     11/25/2002     Rev C update
-- ~~~~~~
--     - Fixed false assertion warnimg on detected burst transaction in code
--       that OMITS burst capability. No functional impact.
-- ^^^^^^
--
--     DET     3/25/2003     plb_ipif_v1_00_d
-- ~~~~~~
--     - Burst mode Size reduction/Fmax improvement
--        - New Address counter and BE generator (now structural)
--        - Optimized Determinate Timer (Revamped dtime parameter muxing)
--        - Revamped Burst Modee data phase State machines (Accounts for
--          1 more clock delay out of Address match decoder due to added
--          register stage for Fmax improvement).
--     - Non-Burst mode Size reduction/Fmax improvement
--        - New Address counter and BE generator (now structural)
--        - Revamped Non-burst Mode data phase State machines (Accounts for 1 more clock
--          delay out of Address match decoder due to added register stage
--          for Fmax improvement).
--     - Moved duplicated design elements from the burst and non-burst HDL
--       sections into a shared design grouping.
--          - PLB Command Validation.
--          - Optimized Address Decoder (PLB specific)
--          - Address Phase Controller State Machine.
--              - Implemented 'Wait' protocol in place of 'Rearbitrate' protocol.
--          - Data Phase WDT (Now Implemented structurally)
--     - Removed unused/obsoleted HDL
-- ^^^^^^
--
--     DET     4/4/2003     plb_ipif_v1_00_d
-- ~~~~~~
--     - Revamped Fixed Burst/Cacheline features
--          - Three parameter selected modes:
--              Single data beat command support only (no cacheline or bursting).
--              Fixed Burst/Cacheline support Slow Mode (multi-clock per databeat)
--              Fixed Burst/Cacheline support Fast Mode (single clock back to back databeats)
-- ^^^^^^
--
--     DET     4/7/2003     plb_ipif_v1_00_d
-- ~~~~~~
--     - Removed one Pipeline register delay for input data during write operations in Burst
--       Fast Mode. This afforded a common cycle count load value for various functions. This
--       boosted Fmax and reduced LUT usage.
-- ^^^^^^
--
--
--     DET     4/16/2003     plb_ipif_v1_00_d
-- ~~~~~~
--     - Added change to interpret IP2Bus_Retry assertion as a 'Busy' indication
--       from the IP. This causes a rearbitrate response from the Slave during
--       the address phase of commands. Assertion of IP2Bus_Retry during the data
--       phase of a comand has no effect.
-- ^^^^^^
--
--     DET     5/6/2003     plb_v1_00_d
-- ~~~~~~
--     - Changed the Bus2IP_RdReq generation logic to de-assert when the Address
--       and Control sequence has completed during Determinate Timing controlled
--       read operations (Burst Fast Mode change only!).
-- ^^^^^^
--
--
--     DET     5/19/2003     plb_v1_00_d
-- ~~~~~~
--     - Revamped control signals initiating data phase state machines to allow
--       for latency removal.
--     - Revamped Data state machines in all three modes to remove latency during
--       Wait asserted condition to next address acknowledge.
-- ^^^^^^
--
--
--     DET     6/5/2003     v1.00.e IPIF for PCI
-- ~~~~~~
--     - Added IP2Bus_Busy input signal lfor PCI application. When asserted, it will
--       force rearbitrates in place of 'wait' protocol.
-- ^^^^^^
--
--     DET     6/12/2003     PLB IPIF V1.00.e (PCI Bridge)
-- ~~~~~~
--     - Removed Determinate Timer function and associated C_ARD_DTIME_READ_ARRAY
--       and C_DTIME_WRITE_ARRAY parameters.
--     - Added IP Address Acknowledege to replace determinate timer.
--     - Added support for Indeterminate Bursts in Fast Burst Mode.
--
-- ^^^^^^
--
--     DET     6/20/2003     PLB IPIF V1.00.e (PCI Bridge)
-- ~~~~~~
--     - Added Bus2IP_PselHit bus to IPIC for PCI Bridge use.
--     - Added Bus2IP_RNW_Early to IPIC for PCI Bridge use.
--     - Added IP2Bus_BTerm to IPIC for future burst terminate optionfor IP.
--     - Added Bus2IP_IBurst to IPIC for Indeterminate Burst indication.
-- ^^^^^^
--
--
--     DET     6/26/2003     PLB IPIF v1.00.e (PCI Bridge)
-- ~~~~~~
--     - Added Indeterminate Burst Functionality to Slow Mode Burst option.
-- ^^^^^^
--
--     DET     7/1/2003     PLB IPIF V1.00.e  (PCI Brdge & DDR)
-- ~~~~~~
--     - Modified IPIF Write State Machine to incorporate Bus2IP_WrReq de-assertion
--       upon completion of the Address/Control portion of Fixed length and
--       Cacheline bursts.
-- ^^^^^^
--
--     DET     7/7/2003     V1.00.e  (PCI Bridge & DDR)
-- ~~~~~~
--     - In Fast Burst mode...Modified the burst_support module component
--       and instance to reflect changes for indeterminate burst writes
--       where the Bus2IP_Addr is being ticked ahead of the data (DDR situation).
--     - In Fast Burst mode...Corrected the PLB Write control state machine to
--       handle the indeterminate burst write scenario where the burst is
--       completed at the exact same clock as the write buffer going full.
--     - In Fast Burst mode...corrected write Buffer going full determination
--       which was off by one clock (late).
-- ^^^^^^
--
--     DET     7/11/2003     V1.00.e  (PCI Bridge and DDR)
-- ~~~~~~
--     - Corrected a bug in the Fast Burst Mode logic in the IPIF Write Control
--       State machine that broke the PCI Bridge Slave access. This bug was related
--       to the Bus2IP_WrReq de-assertion modification for DDR.
-- ^^^^^^
--
--     DET     7/16/2003     V1.00.e  (PCI Bridge & DDR)
-- ~~~~~~
--     - Corrected a sensitivity list omission from the PLB_WRITE_DATA_CONTROLLER
--       process in the Fast Burst mode generate statement.
-- ^^^^^^
--
--     DET     8/7/2003     V1_00_e  (PCIBridge and PLB DDR)
-- ~~~~~~
--     - Corrected a problem with the PLB_Abort logic. The abort was being masked
--       if the slave was busy with the data phase of another command at the
--       time of the abort assertion. The signal sig_cmd_abort is now used only
--       for data phase logic. A new signal is used for the Address Phase logic.
-- ^^^^^^
--
--
--     DET     11/12/2003     V1_00_e Granite sp2
-- ~~~~~~
--     - Corrected a bug when configured with Burst enabled and Fast Mode enabled.
--       The Sl_merr could be asserted outside the assertion of Sl_Mbusy if a
--       target error was asserted on the last databeat of a write transaction.
--       The Sl_Mbusy was extended for one extra PLB clock in this case so as to
--       overlap the assertion of the error assertion.
-- ^^^^^^
--
--     DET     11/14/2003     V1_00_e Granite SP2
-- ~~~~~~
--     - Removed Quad and Octal word width transfer requests from valid command
--       type checking. This IPIF will not respond to these widths.
--     - Corrected a sensitivity list omission in Burst enabled, Fast Xfer mode
--       in the process "CHECK_DATA_DONE".
-- ^^^^^^
--
--     DET     3/25/2004     ipif to v1_00_f
-- ~~~~~~
--     - Changed proc_common library reference to v2_00_a
--     - Removed ipif_common library reference
-- ^^^^^^
--
--
--     DET     4/7/2004     IPIF v1_00_f
-- ~~~~~~
--     - Corrected a bug found with fast mode burst and a throttling slave
--       during indeterminate burst reads.
--     - Corrected some indeterminate burst write timing at the end of the burst.
--     - Removed various commented out code sections as part of source cleanup.
-- ^^^^^^
--
--
--     DET     4/12/2004     IPIF to V1_00_f
-- ~~~~~~
--     - Updated unisim library reference to unisim.vcomponents.all
--     - Commented out Xilinx primitive component declarations
-- ^^^^^^
--  LCW Oct 14, 2004      -- updated for NCSim
--
--     DET     4/11/2005     v1_00_f (Halite)
-- ~~~~~~
--     - Fixed latch generation issue that surfaced with Halite XST.
--     - Problem addressed in CR206455.
-- ^^^^^^
--
--     DET     12/22/2005     v1_00_f for Iron SP1
-- ~~~~~~
--     - Incorporated fix of Indeterminate Burst hang up in the PLB
--       DDR application (Problem addressed in CR217002).
-- ^^^^^^
--
--     DET     02/02/2006     v1_00_f for Iron SP2 
-- ~~~~~~
--     - Incorporated the C_CACHLINE_ADDR_MODE parameter and routed it to the
--       modified address generation modules  (Enhancement addressed in
--       CR225048).
-- ^^^^^^
-- Avinash     8/31/2006  
-- ^^^^^^
-- Added rd_dphase_active signal in sensitivity list on PLB_RDDATA_CONTROLLER
-- process to fix FV problem.
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;     -- provides conv_std_logic_vector function
use ieee.std_logic_unsigned.CONV_INTEGER;  --Used in byte count compare 2 MA2SA_Num
use ieee.std_logic_arith.all;
use ieee.std_logic_arith.conv_std_logic_vector;


library proc_common_v2_00_a;
use proc_common_v2_00_a.proc_common_pkg.all;
use proc_common_v2_00_a.proc_common_pkg.log2;
use proc_common_v2_00_a.all;
use proc_common_v2_00_a.ipif_pkg.all;


-- Xilinx Primitive Library
library unisim;
use unisim.vcomponents.all;

library plb_ipif_v1_00_f;

-------------------------------------------------------------------------------
entity plb_slave_attachment_indet is
    generic (
        C_STEER_ADDR_SIZE : Integer := 10;

        C_ARD_ADDR_RANGE_ARRAY  : SLV64_ARRAY_TYPE :=
           (
            X"0000_0000_1000_0000", -- IPIF Interrupt base address
            X"0000_0000_1000_01FF", -- IPIF Interrupt high address
            X"0000_0000_1000_0200", -- IPIF Reset base address
            X"0000_0000_1000_02FF", -- IPIF Reset high address
            X"0000_0000_1000_2000", -- IPIF WrFIFO Registers base address
            X"0000_0000_1000_20FF", -- IPIF WrFIFO Registers high address
            X"0000_0000_1000_2100", -- IPIF WrFIFO Data base address
            X"0000_0000_1000_21ff", -- IPIF WrFIFO Data high address
            X"0000_0000_1000_2200", -- IPIF RdFIFO Registers base address
            X"0000_0000_1000_22FF", -- IPIF RdFIFO Registers high address
            X"0000_0000_1000_2300", -- IPIF RdFIFO Data base address
            X"0000_0000_1000_23FF", -- IPIF RdFIFO Data high address
            X"0000_0000_7000_0000", -- IP Registers base address
            X"0000_0000_7000_00FF", -- IP Registers high address
            X"0000_0000_8000_0000", -- IP user0 base address
            X"0000_0000_8FFF_FFFF", -- IP user0 high address
            X"0000_0000_9000_0000", -- IP user1 base address
            X"0000_0000_9FFF_FFFF"  -- IP user1 high address
           );

        C_ARD_DWIDTH_ARRAY     : INTEGER_ARRAY_TYPE :=
           (
            32,    -- IPIF Interrupt data width
            32,    -- IPIF Reset data width
            32,    -- IPIF WrFIFO Registers data width
            64,    -- IPIF WrFIFO Data data width
            32,    -- IPIF RdFIFO Registers data width
            64,    -- IPIF RdFIFO Data width
            32,    -- IP Registers data width
            64,    -- User0 data width
            8      -- User1 data width
           );

        C_ARD_NUM_CE_ARRAY   : INTEGER_ARRAY_TYPE :=
           (
            16,    -- IPIF Interrupt CE Number
            1,     -- IPIF Reset CE Number
            2,     -- IPIF WrFIFO Registers CE Number
            1,     -- IPIF WrFIFO Data data CE Number
            2,     -- IPIF RdFIFO Registers CE Number
            1,     -- IPIF RdFIFO Data CE Number
            8,     -- IP Registers CE Number
            1,     -- User0 CE Number
            1      -- User1 CE Number
           );


        C_PLB_NUM_MASTERS       : integer := 8;
        C_PLB_MID_WIDTH         : Integer := 3;
        C_PLB_ABUS_WIDTH        : integer := 32;
        C_PLB_DBUS_WIDTH        : integer := 64;
        C_IPIF_ABUS_WIDTH       : integer := 32;
        C_IPIF_DBUS_WIDTH       : integer := 64;
        C_SL_ATT_ADDR_SEL_WIDTH : integer := 2;
        C_SUPPORT_BURST         : boolean := false;
        C_FAST_DATA_XFER        : Boolean := false;
        C_BURST_PAGE_SIZE       : Integer := 1024;
        C_MA2SA_NUM_WIDTH       : integer := 4;
        C_SLN_BUFFER_DEPTH      : integer := 8;
        C_DPHASE_TIMEOUT        : Integer := 64;
        C_CACHLINE_ADDR_MODE    : Integer range 0 to 1 := 0
        );
    port(
        --System signals
        Bus_Reset       : in std_logic;
        Bus_Clk         : in std_logic;

        -- PLB Bus signals
        PLB_ABus        : in  std_logic_vector(0 to C_PLB_ABUS_WIDTH-1);
        PLB_PAValid     : in  std_logic;
        PLB_SAValid     : in  std_logic;
        PLB_rdPrim      : in  std_logic;
        PLB_wrPrim      : in  std_logic;
        PLB_masterID    : in  std_logic_vector(0 to C_PLB_MID_WIDTH -1);
        PLB_abort       : in  std_logic;
        PLB_busLock     : in  std_logic;
        PLB_RNW         : in  std_logic;
        PLB_BE          : in  std_logic_vector(0 to (C_PLB_DBUS_WIDTH/8)-1);
        PLB_Msize       : in  std_logic_vector(0 to 1);
        PLB_size        : in  std_logic_vector(0 to 3);
        PLB_type        : in  std_logic_vector(0 to 2);
        PLB_compress    : in  std_logic;
        PLB_guarded     : in  std_logic;
        PLB_ordered     : in  std_logic;
        PLB_lockErr     : in  std_logic;
        PLB_wrDBus      : in  std_logic_vector(0 to C_PLB_DBUS_WIDTH-1);
        PLB_wrBurst     : in  std_logic;
        PLB_rdBurst     : in  std_logic;
        PLB_pendReq     : in  std_logic;
        PLB_pendPri     : in  std_logic_vector(0 to 1);
        PLB_reqPri      : in  std_logic_vector(0 to 1);
        Sl_addrAck      : out std_logic;
        Sl_SSize        : out std_logic_vector(0 to 1);
        Sl_wait         : out std_logic;
        Sl_rearbitrate  : out std_logic;
        Sl_wrDAck       : out std_logic;
        Sl_wrComp       : out std_logic;
        Sl_wrBTerm      : out std_logic;
        Sl_rdDBus       : out std_logic_vector(0 to C_PLB_DBUS_WIDTH-1);
        Sl_rdWdAddr     : out std_logic_vector(0 to 3);
        Sl_rdDAck       : out std_logic;
        Sl_rdComp       : out std_logic;
        Sl_rdBTerm      : out std_logic;
        Sl_MBusy        : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        Sl_MErr         : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);

        -- Master Attachment Signals
        MA2SA_Select    : in std_logic := '0';
        MA2SA_XferAck   : in std_logic := '0';
        MA2SA_Rd        : in std_logic := '0';
        MA2SA_Num       : in std_logic_vector(0 to C_MA2SA_NUM_WIDTH-1)
                             := (others => '0');
        SA2MA_RdRdy     : out std_logic;
        SA2MA_WrAck     : out std_logic;
        SA2MA_Retry     : out std_logic;
        SA2MA_ErrAck    : out std_logic;

        -- Controls to the Byte Steering Module
        SA2Steer_Addr   : Out std_logic_vector(0 to C_STEER_ADDR_SIZE-1);
        SA2Steer_BE     : Out std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8-1);

        -- Controls to the IP/IPIF modules
        Bus2IP_masterID  : Out std_logic_vector(0 to C_PLB_MID_WIDTH-1);  -- ***PLB future
        Bus2IP_Ssize     : Out std_logic_vector(0 to 1);  -- ***PLB future
        Bus2IP_size      : Out std_logic_vector(0 to 3);  -- ***PLB future
        Bus2IP_type      : Out std_logic_vector(0 to 2);  -- ***PLB future

        Bus2IP_Addr      : out std_logic_vector (0 to C_PLB_ABUS_WIDTH-1);
        Bus2IP_Burst     : out std_logic;
        Bus2IP_IBurst    : Out std_logic;
        Bus2IP_RNW       : out std_logic;
        Bus2IP_BE        : out std_logic_vector (0 to C_IPIF_DBUS_WIDTH/8-1);
        Bus2IP_WrReq     : out std_logic;
        Bus2IP_RdReq     : out std_logic;
        Bus2IP_RNW_Early : Out std_logic; --- new  PCI v1.00.e
        Bus2IP_PselHit   : Out std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1); -- new  PCI v1.00.e
        Bus2IP_CS        : Out std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
        Bus2IP_DWidth    : Out std_logic_vector(0 to 2);
        Bus2IP_CE        : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);
        Bus2IP_RdCE      : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);
        Bus2IP_WrCE      : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);

        -- Write Data bus output to the IP/IPIF modules
        Bus2IP_Data      : out std_logic_vector (0 to C_IPIF_DBUS_WIDTH-1);

        --Inputs from the Read Data Bus Mux
        MUX2SA_Data      : in std_logic_vector (0 to C_IPIF_DBUS_WIDTH-1);

        -- Inputs from the Status Reply Mux
        MUX2SA_AddrAck   : In std_logic; -- new  PCI v1.00.e
        MUX2SA_Busy      : In std_logic; -- new  PCI v1.00.e
        MUX2SA_BTerm     : In std_logic; -- new  PCI v1.00.e
        MUX2SA_WrAck     : in std_logic;
        MUX2SA_RdAck     : in std_logic;
        MUX2SA_ErrAck    : in std_logic;
        MUX2SA_ToutSup   : in std_logic;
        MUX2SA_Retry     : in std_logic;

        -- Data Acknowledge Timeout Error to Interrupt Module
        SA2INT_DAck_Timeout : Out std_logic
        );
end entity plb_slave_attachment_indet;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

architecture implementation of plb_slave_attachment_indet is


-------------------------------------------------------------------------------
-- Function Declarations
-------------------------------------------------------------------------------

  -------------------------------------------------------------------
  -- Function
  --
  -- Function Name: check_to_value
  --
  -- Function Description:
  --  This function makes sure a minimum timeout value is passed to
  -- the WDT logic for the Data Phase timeout if the User specifies
  -- one that is too small. Currently, this is minimum is 8 clocks.
  --
  -------------------------------------------------------------------
  function check_to_value (timeout_value: integer) return integer is

     Constant MIN_VALUE_ALLOWED : integer := 8; -- 8 PLB clocks

     Variable to_value : Integer;

  begin

     If (timeout_value < MIN_VALUE_ALLOWED) Then

       to_value :=  MIN_VALUE_ALLOWED;

     else
       to_value := timeout_value;

     End if;

     return(to_value);

  end function check_to_value;




-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------

  Constant SLAVE_BUS_SIZE64 : std_logic_vector(0 to 1) := "01";


  Constant MAX_FIXED_XFER_COUNT  : integer := 16;


  Constant ALLOW_CACHELN         : boolean := C_SUPPORT_BURST;
  Constant ALLOW_BURST           : boolean := C_SUPPORT_BURST;


  Constant SLOW_MODE_BURSTXFER   : boolean := C_SUPPORT_BURST AND
                                              not(C_FAST_DATA_XFER);

  Constant FAST_MODE_BURSTXFER   : boolean := C_SUPPORT_BURST and
                                              C_FAST_DATA_XFER;








  -- xst workaround for constraining ports in address_decoder
  -- component declaration.
  Constant CS_BUS_SIZE : integer := C_ARD_ADDR_RANGE_ARRAY'length/2;
  Constant CE_BUS_SIZE : integer := calc_num_ce(C_ARD_NUM_CE_ARRAY);


-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------

    type PLB_ADDR_CNTRL_STATES is (
                        VALIDATE_REQ,
                        REARBITRATE,
                        GEN_WAIT,
                        GEN_ADDRACK
                        );



    -- Intermediate Slave Reply output signals (to PLB)
    signal sl_addrack_i        : std_logic;
    signal sl_ssize_i          : std_logic_vector(0 to 1);
    signal sl_wait_i           : std_logic;
    signal sl_rearbitrate_i    : std_logic;
    signal sl_wrdack_i         : std_logic;
    signal sl_wrcomp_i         : std_logic;
    signal sl_wrbterm_i        : std_logic;
    signal sl_rddbus_i         : std_logic_vector(0 to C_PLB_DBUS_WIDTH-1);
    signal sl_rdwdaddr_i       : std_logic_vector(0 to 3);
    signal sl_rddack_i         : std_logic;
    signal sl_rdcomp_i         : std_logic;
    signal sl_rdbterm_i        : std_logic;
    signal sl_mbusy_i          : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
    signal sl_merr_i           : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);


    -- Signals for combined address phase state machine
    signal addr_cntl_state         :  PLB_ADDR_CNTRL_STATES;
    Signal addr_cycle_flush        : std_logic;
    Signal sig_inhib_Addr_cntr_ld  : std_logic;


   -- PLB Read State Machine
    signal sl_rddack_ns        : std_logic;
    signal sl_rdcomp_ns        : std_logic;
    signal sl_rdbterm_ns       : std_logic;
    signal sl_rdwdaddr_ns      : std_logic_vector(0 to 3);
    signal rd_dphase_active_ns : std_logic;
    signal bus2ip_rdreq_ns     : std_logic;
    signal Bus2IP_RdBurst_ns   : std_logic;
    Signal clear_rd_ce         : std_logic;
    Signal rd_ce_ld_enable     : std_logic;
    Signal clear_sl_rd_busy    : std_logic;
    Signal clear_sl_rd_busy_ns : std_logic;

   -- PLB Write State Machine
    signal sl_wrdack_ns        : std_logic;
    signal sl_wrcomp_ns        : std_logic;
    signal sl_wrbterm_ns       : std_logic;


    -- Registered PLB input signals
    signal plb_abus_reg        : std_logic_vector(0 to C_PLB_ABUS_WIDTH-1);
    signal plb_pavalid_reg     : std_logic;
    signal plb_savalid_reg     : std_logic;
    signal plb_rdprim_reg      : std_logic;
    signal plb_wrprim_reg      : std_logic;
    signal plb_masterid_reg    : std_logic_vector(0 to C_PLB_MID_WIDTH -1);
    signal plb_abort_reg       : std_logic;
    signal plb_buslock_reg     : std_logic;
    signal plb_rnw_reg         : std_logic;
    signal plb_be_reg          : std_logic_vector(0 to (C_PLB_DBUS_WIDTH/8)-1);
    signal plb_msize_reg       : std_logic_vector(0 to 1);
    signal plb_size_reg        : std_logic_vector(0 to 3);
    signal plb_type_reg        : std_logic_vector(0 to 2);
    signal plb_compress_reg    : std_logic;
    signal plb_guarded_reg     : std_logic;
    signal plb_ordered_reg     : std_logic;
    signal plb_lockerr_reg     : std_logic;
    signal plb_wrdbus_reg      : std_logic_vector(0 to C_PLB_DBUS_WIDTH-1);
    signal plb_wrburst_reg     : std_logic;
    signal plb_rdburst_reg     : std_logic;
    signal plb_pendreq_reg     : std_logic;
    signal plb_pendpri_reg     : std_logic_vector(0 to 1);
    signal plb_reqpri_reg      : std_logic_vector(0 to 1);


    -- Intermediate IPIC signals
    Signal Bus2IP_Data_i       : std_logic_vector(0 to C_PLB_DBUS_WIDTH-1);
    signal Bus2IP_DWidth_i     : std_logic_vector(0 to 2);      -- ***PLB
    signal bus2ip_addr_i       : std_logic_vector(0 to C_PLB_ABUS_WIDTH-1);
    signal bus2ip_burst_i      : std_logic;
    signal bus2ip_rnw_i        : std_logic;
    signal bus2ip_be_i         : std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8-1);
    signal bus2ip_wrreq_i      : std_logic;
    signal bus2ip_rdreq_i      : std_logic;
    Signal Bus2IP_masterID_i   : std_logic_vector(0 to C_PLB_MID_WIDTH-1);
    signal bus2ip_type_i       : std_logic_vector(0 to 2);
    Signal bus2ip_size_i       : std_logic_vector(0 to 3);

    -- new internal signals
    Signal master_id             : integer range 0 to C_PLB_NUM_MASTERS-1;
    signal addr_cntr_clken_i     : std_logic;
    Signal Addr_cntr_load_en     : std_logic;
    Signal line_count_done       : std_logic;
    Signal line_count_almostdone : std_logic;
    Signal start_data_phase      : std_logic;
    Signal data_ack              : std_logic;
    Signal data_timeout          : std_logic;
    Signal error_reply           : std_logic;

    signal rdwdaddr              : std_logic_vector(0 to 3);
    Signal read_data_xfer        : std_logic;
    Signal SA2Steer_Addr_i       : std_logic_vector(0 to C_STEER_ADDR_SIZE-1);
    Signal SA2Steer_BE_i         : std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8-1);
    --Signal mux2sa_busy_reg       : std_logic;

  -- Combined transfer validation signals
    Signal valid_request           : std_logic;
    signal valid_plb_size          : boolean;
    signal valid_plb_type          : boolean;
    Signal single_transfer         : std_logic;
    Signal single_transfer_reg     : std_logic;
    Signal burst_transfer          : std_logic;
    Signal burst_transfer_reg      : std_logic;
    Signal cacheln_transfer        : std_logic;
    Signal cacheln_burst_reg       : std_logic;
    signal indeterminate_burst     : std_logic;
    signal indeterminate_burst_reg : std_logic;
    Signal wait_condition          : std_logic;
    Signal rearbitrate_condition   : std_logic;
    Signal do_the_cmd              : std_logic;

  -- Combined decoder signals
    Signal pselect_hit_i       : std_logic_vector(0 to CS_BUS_SIZE-1);
    Signal address_match       : std_logic;
    Signal address_match_early : std_logic;
    Signal decode_cs_ce_clr    : std_logic;
    Signal decode_ld_rw_ce     : std_logic;
    Signal decode_clr_rw_ce    : std_logic;
    Signal decode_s_h_cs       : std_logic;
    Signal decode_cs_clr       : std_logic;
    Signal CS_Early_i          : std_logic_vector(0 to CS_BUS_SIZE-1);
    Signal Bus2IP_CS_i         : std_logic_vector(0 to CS_BUS_SIZE-1);
    Signal Bus2IP_CE_i         : std_logic_vector(0 to CE_BUS_SIZE-1);
    Signal Bus2IP_RDCE_i       : std_logic_vector(0 to CE_BUS_SIZE-1);
    Signal Bus2IP_WRCE_i       : std_logic_vector(0 to CE_BUS_SIZE-1);


  -- Other Combined Logic signals
    Signal sig_addrphase_abort : std_logic;
    Signal sig_cmd_abort       : std_logic;
    Signal sl_data_ack         : std_logic;
    Signal set_sl_busy         : std_logic;
    Signal clear_sl_busy       : std_logic;
    Signal sl_busy             : std_logic;
    Signal bus2ip_iburst_i     : std_logic;

-------------------------------------------------------------------------------
-- begin the architecture logic
-------------------------------------------------------------------------------
    begin

     -- synthesis translate_off

     -------------------------------------------------------------
     -- Synchronous Process
     --
     -- Label: REPORT_WARNINGS
     --
     -- Process Description:
     --     This process is used only during simulation to generate
     -- user warnings.
     --
     -------------------------------------------------------------
     REPORT_WARNINGS : process (bus_clk)

        Variable newline : Character := cr;
        Variable report_inhibit_cnt : Integer := 5; -- 5 Bus_Clk clocks

        begin

          if (Bus_clk'event and Bus_clk = '1') then

             -- Inhibit warnings during sim initialization
             if (report_inhibit_cnt = 0) then
                null; -- stop down count
             else
                report_inhibit_cnt := report_inhibit_cnt-1;
             end if;


             if (Bus_Reset = '1' or
                 report_inhibit_cnt > 0) then

               null; -- do nothing

             else

                Assert (data_timeout = '0')
                Report "PLB IPIF data phase timeout assertion....  Addressed Target did not respond!"
                Severity warning;

                Assert (MUX2SA_ErrAck = '0')
                Report "Addressed target asserted Error signal!"
                Severity warning;

             End if;

          else
            null;
          end if;
        end process REPORT_WARNINGS;


     -- synthesis translate_on



    ------------------------------------------------------------------
    -- Misc. Logic Assignments

      -- PLB Output port connections
       Sl_addrAck       <=  sl_addrack_i    ;
       Sl_SSize         <=  sl_ssize_i      ;
       Sl_wait          <=  sl_wait_i       ;
       Sl_rearbitrate   <=  sl_rearbitrate_i;
       Sl_wrDAck        <=  sl_wrdack_i     ;
       Sl_wrComp        <=  sl_wrcomp_i     ;
       Sl_wrBTerm       <=  sl_wrbterm_i    ;
       Sl_rdDBus        <=  sl_rddbus_i     ;
       Sl_rdWdAddr      <=  sl_rdwdaddr_i   ;
       Sl_rdDAck        <=  sl_rddack_i     ;
       Sl_rdComp        <=  sl_rdcomp_i     ;
       Sl_rdBTerm       <=  sl_rdbterm_i    ;
       Sl_MBusy         <=  sl_mbusy_i      ;
       Sl_MErr          <=  sl_merr_i       ;


     --SESR/SEAR Support Signals
       Bus2IP_Ssize     <=  sl_ssize_i;
       Bus2IP_masterID  <=  Bus2IP_masterID_i;
       Bus2IP_size      <=  bus2ip_size_i;
       Bus2IP_type      <=  Bus2IP_type_i;


     -- IPIF output signals
       Bus2IP_Addr      <=  bus2ip_addr_i  ;
       Bus2IP_Burst     <=  bus2ip_burst_i ;
       Bus2IP_RNW       <=  bus2ip_rnw_i   ;
       Bus2IP_BE        <=  bus2ip_be_i    ;
       Bus2IP_WrReq     <=  bus2ip_wrreq_i ;
       Bus2IP_RdReq     <=  bus2ip_rdreq_i ;
       Bus2IP_Data      <=  Bus2IP_Data_i  ;
       Bus2IP_DWidth    <=  Bus2IP_DWidth_i;
       Bus2IP_RNW_early <=  plb_rnw_reg;
       Bus2IP_PselHit   <=  pselect_hit_i; -- new for PCI
       Bus2IP_CS        <=  Bus2IP_CS_i;
       Bus2IP_CE        <=  Bus2IP_CE_i;
       Bus2IP_RdCE      <=  Bus2IP_RdCE_i;
       Bus2IP_WrCE      <=  Bus2IP_WrCE_i;

       Bus2IP_IBurst    <=  bus2ip_iburst_i;

     -- Master Attachment support signals
       SA2MA_RdRdy     <=  '0';
       SA2MA_WrAck     <=  '0';
       SA2MA_Retry     <=  '0';
       SA2MA_ErrAck    <=  '0';


     -- WDT Error to Interrupt Module
       SA2INT_DAck_Timeout <= data_timeout;


       -- gen abort for data phase state machines
       sig_cmd_abort     <=  (PLB_Abort or plb_abort_reg) and
                              not(sl_busy);


       -- gen abort for address phase state machines.
       sig_addrphase_abort <=  PLB_Abort or plb_abort_reg;



     -- Fix the Slave Size response to the PLB DBus width
     -- note "00" = 32 bits wide
     --      "01" = 64 bits wide
     --      "10" = 128 bits wide
       sl_ssize_i(0 to 1)  <=
               CONV_STD_LOGIC_VECTOR(C_PLB_DBUS_WIDTH/64, 2);


     -- Byte steering support
       SA2Steer_Addr    <= SA2Steer_Addr_i;
       SA2Steer_BE      <= SA2Steer_BE_i;





 ------------------------------------------------------------------------------
 -- PROCESS
 --
 -- Register all PLB input signals
 ------------------------------------------------------------------------------
 REG_PLB_INPUTS : Process (Bus_clk)
   begin

      If (Bus_clk'EVENT and Bus_clk = '1')  then

         if (Bus_reset = '1') Then

            plb_pavalid_reg     <= '0';
            plb_abus_reg        <= (others => '0');
            plb_be_reg          <= (others => '0');
            plb_wrdbus_reg      <= (others => '0');
            plb_masterid_reg    <= (others => '0');
            plb_abort_reg       <= '0';
            plb_buslock_reg     <= '0';
            plb_rnw_reg         <= '0';
            plb_msize_reg       <= (others => '0');
            plb_size_reg        <= (others => '0');
            plb_type_reg        <= (others => '0');
            plb_ordered_reg     <= '0';
            plb_lockerr_reg     <= '0';
            plb_wrburst_reg     <= '0';
            plb_rdburst_reg     <= '0';
            plb_compress_reg    <= '0';
            plb_guarded_reg     <= '0';
            plb_savalid_reg     <= '0';
            plb_rdprim_reg      <= '0';
            plb_wrprim_reg      <= '0';
            plb_pendreq_reg     <= '0';
            plb_pendpri_reg     <= (others => '0');
            plb_reqpri_reg      <= (others => '0');


         else

            if (addr_cycle_flush = '1' or
                plb_abort_reg    = '1') Then  -- Clear pavalid on flush request or abort.
                                              -- This eliminates latent address
                                              -- decoding due to pipelining.
               plb_pavalid_reg     <=  '0';

            Else                           -- clock continously

               plb_pavalid_reg     <=  PLB_PAValid;

            End if;

            -- Register these signals continously
            plb_abort_reg       <=  PLB_abort  ;
            plb_wrdbus_reg      <=  PLB_wrDBus ;
            plb_abus_reg        <=  PLB_ABus    ;
            plb_savalid_reg     <=  PLB_SAValid ;
            plb_be_reg          <=  PLB_BE      ;
            plb_masterid_reg    <=  PLB_masterID;
            plb_buslock_reg     <=  PLB_busLock ;
            plb_rnw_reg         <=  PLB_RNW     ;
            plb_msize_reg       <=  PLB_Msize   ;
            plb_size_reg        <=  PLB_size    ;
            plb_type_reg        <=  PLB_type    ;
            plb_ordered_reg     <=  PLB_ordered ;
            plb_lockerr_reg     <=  PLB_lockErr ;
            plb_wrburst_reg     <=  PLB_wrBurst ;
            plb_rdburst_reg     <=  PLB_rdBurst ;
            plb_compress_reg    <=  PLB_compress;
            plb_guarded_reg     <=  PLB_guarded ;
            plb_rdprim_reg      <=  PLB_rdPrim  ;
            plb_wrprim_reg      <=  PLB_wrPrim  ;
            plb_pendreq_reg     <=  PLB_pendReq ;
            plb_pendpri_reg     <=  PLB_pendPri ;
            plb_reqpri_reg      <=  PLB_reqPri  ;

         End if;

      else

         null;

      end if;

   end process REG_PLB_INPUTS;






    ------------------------------------------------------------------------------
    -- PROCESS
    --
    -- PLB Size Validation
    -- This combinatorial process validates the PLB request attribute PLB_Size
    -- that is supported by this slave. It also detirmines if a cacheline or
    -- burst operation is being requested.
    ------------------------------------------------------------------------------
    VALIDATE_SIZE : process (plb_size_reg)
      Begin


         Case plb_size_reg Is

            -- Single Data beat transfer
            When "0000" =>   -- one to eight bytes

               valid_plb_size   <= true;
               single_transfer  <= '1';
               cacheln_transfer <= '0';
               burst_transfer   <= '0';

            -- Cacheline Transfer
            When "0001" |   -- 4 word cache-line
                 "0010" |   -- 8 word cache-line
                 "0011" =>  -- 16 word cache-line

               valid_plb_size   <= ALLOW_CACHELN;
               single_transfer  <= '0';
               cacheln_transfer <= '1';
               burst_transfer   <= '0';


            -- Burst Transfer (Fixed Length or indetirminate)
            when "1000" |    -- byte burst transfer
                 "1001" |    -- halfword burst transfer
                 "1010" |    -- word burst transfer
                 "1011" =>   -- double word burst transfer
                             -- Quad and Octal widths are not
                             -- allowed (requires 128 and 256 wide bus)

               valid_plb_size   <= ALLOW_BURST;
               single_transfer  <= '0';
               cacheln_transfer <= '0';
               burst_transfer   <= '1';

            When others   =>

               valid_plb_size   <= false;
               single_transfer  <= '0';
               cacheln_transfer <= '0';
               burst_transfer   <= '0';

         End case;


      End process; -- VALIDATE_SIZE


    ------------------------------------------------------------------------------
    -- PROCESS
    --
    -- PLB Size Validation
    -- This combinatorial process validates the PLB request attribute PLB_Type
    -- that is supported by this slave.
    ------------------------------------------------------------------------------
    VALIDATE_TYPE : process (plb_type_reg)
      Begin

         Case plb_type_reg Is
            When "000"   -- memory transfer

            => valid_plb_type <= true;

            When others   =>

               valid_plb_type <= false;

         End case;


      End process; -- VALIDATE_TYPE



    ------------------------------------------------------------------------------
    -- PROCESS
    --
    -- Access Validation
    -- This combinatorial process validates the PLB request attributes that are
    -- supported by this slave.
    ------------------------------------------------------------------------------
    VALIDATE_REQUEST : process (plb_pavalid_reg,
                                --sig_cmd_abort,
                                sig_addrphase_abort,
                                valid_plb_size,
                                valid_plb_type)
      Begin
        if (plb_pavalid_reg = '1')    and  -- Address Request
           (sig_addrphase_abort = '0') and
           (valid_plb_size)  and           -- a valid plb_size
           (valid_plb_type) then  -- Memory Xfer

          valid_request <= '1';
        else
          valid_request <= '0';
        End if;

      End process; -- VALIDATE_REQUEST



      -------------------------------------------------------------
      -- Combinational Process
      --
      -- Label: VALIDATE_BURST
      --
      -- Process Description:
      -- This process validates indetirminate vs fixed length burst
      -- transfers.
      --
      -------------------------------------------------------------
      VALIDATE_BURST : process (burst_transfer, plb_be_reg)
         begin

           if (burst_transfer = '1' and
               plb_be_reg(0 to 3) = "0000") then  -- indetirminate burst
             indeterminate_burst <= '1';
           else
             indeterminate_burst <= '0';
           end if;

         end process VALIDATE_BURST;



    ------------------------------------------------------------------------------
    -- Address Decoder Component Instance
    --
    -- This component decodes the specified base address pairs and outputs the
    -- specified number of chip enables and the target bus size.
    ------------------------------------------------------------------------------

    I_DECODER : entity plb_ipif_v1_00_f.plb_address_decoder
    generic map(
      C_BUS_AWIDTH             => C_PLB_ABUS_WIDTH,
      C_ARD_ADDR_RANGE_ARRAY   => C_ARD_ADDR_RANGE_ARRAY,
      C_ARD_DWIDTH_ARRAY       => C_ARD_DWIDTH_ARRAY,
      C_ARD_NUM_CE_ARRAY       => C_ARD_NUM_CE_ARRAY
      )
    port map (
      Bus_clk            =>  Bus_clk,
      Bus_rst            =>  Bus_reset,

      -- PLB Interface signals
      Address_In         =>  plb_abus_reg,
      Address_Valid      =>  plb_pavalid_reg,
      Bus_RNW            =>  plb_rnw_reg,

      -- Registering control signals
      cs_sample_hold_n   =>  decode_s_h_cs,
      cs_sample_hold_clr =>  decode_cs_clr,
      CS_CE_ld_enable    =>  Addr_cntr_load_en,
      Clear_CS_CE_Reg    =>  decode_cs_ce_clr,
      RW_CE_ld_enable    =>  decode_ld_rw_ce,
      Clear_RW_CE_Reg    =>  decode_clr_rw_ce,
      Clear_addr_match   =>  addr_cycle_flush,

      -- Decode output signals
      PSelect_Hit        =>  pselect_hit_i,
      Addr_Match_early   =>  address_match_early,
      Addr_Match         =>  address_match,
      CS_Out             =>  Bus2IP_CS_i,
      CS_OUT_Early       =>  CS_Early_i,
      CS_Size            =>  Bus2IP_DWidth_i,
      CE_Out             =>  Bus2IP_CE_i,
      RdCE_Out           =>  Bus2IP_RdCE_i,
      WrCE_Out           =>  Bus2IP_WrCE_i
      );




   -- detect a rearbitrate condition and set a flag if it exists
    rearbitrate_condition <= valid_request       and
                             address_match_early and
                             MUX2SA_Busy;             -- must be unregistered version for timing

   -- detect a wait condition and set a flag if it exists
    wait_condition  <=  valid_request       and
                        address_match_early and
                        sl_busy             and
                        not(clear_sl_busy);

   -- detect a command execute condition and set a flag if it exists
    do_the_cmd      <=  valid_request       and
                        address_match_early and
                        not(sl_busy);

    ------------------------------------------------------------------------------
    -- PROCESS
    --
    -- Address Controller State Machine
    -- This state machine controls the validation and address acknowledge
    -- of the incoming PLB bus requests. The local Slave
    -- Attachment decoder will reply with an address match signal should
    -- the incoming address match the assigned address ranges.
    --
    -- Note:
    -- Rearbitrates are initiated when the target asserts the MUX2SA_Busy
    -- signal prior to address phase completion.
    ------------------------------------------------------------------------------
    ADDRESS_CONTROLLER : Process (Bus_clk)
      begin

         if (Bus_clk'EVENT and Bus_clk = '1') then

            If (Bus_reset = '1') Then

               addr_cntl_state         <= VALIDATE_REQ;
               sl_wait_i               <= '0';
               sl_addrack_i            <= '0';
               set_sl_busy             <= '0';
               sl_rearbitrate_i        <= '0';
               addr_cycle_flush        <= '0';
               sig_inhib_Addr_cntr_ld  <= '0';

            else

              -- default conditions
               sl_wait_i               <= '0';
               sl_addrack_i            <= '0';
               set_sl_busy             <= '0';
               sl_rearbitrate_i        <= '0';
               addr_cycle_flush        <= '0';
               sig_inhib_Addr_cntr_ld  <= '0';

             -- States
               Case addr_cntl_state Is

                 When VALIDATE_REQ =>

                    if (sig_addrphase_abort = '1') then

                       addr_cntl_state    <= VALIDATE_REQ;
                       addr_cycle_flush   <= '1';

                    Elsif (rearbitrate_condition = '1') Then -- rearbitrate condition

                       sl_rearbitrate_i        <= '1';
                       addr_cycle_flush        <= '1';
                       addr_cntl_state         <= REARBITRATE;
                       sig_inhib_Addr_cntr_ld  <= '1';

                    Elsif (wait_condition = '1') Then -- wait condition

                       addr_cntl_state         <= GEN_WAIT;
                       sig_inhib_Addr_cntr_ld  <= '1';
                       sl_wait_i               <= '1';

                    elsif (do_the_cmd = '1') then  -- Do the command

                       addr_cntl_state          <= GEN_ADDRACK;
                       sl_wait_i                <= '1';
                       sl_addrack_i             <= '1';
                       set_sl_busy              <= '1';
                       addr_cycle_flush         <= '1';

                    else

                       addr_cntl_state    <= VALIDATE_REQ;

                    end if;


                 When GEN_WAIT =>

                    if (sig_addrphase_abort = '1') then

                      addr_cntl_state    <= VALIDATE_REQ;
                      addr_cycle_flush   <= '1';

                    Elsif (rearbitrate_condition = '1') Then

                       addr_cntl_state         <= REARBITRATE;
                       sl_rearbitrate_i        <= '1';
                       sl_wait_i               <= '1';
                       addr_cycle_flush        <= '1';
                       sig_inhib_Addr_cntr_ld  <= '1';

                    Elsif (clear_sl_busy = '1') Then

                      addr_cntl_state    <= GEN_ADDRACK;
                      sl_wait_i          <= '1';
                      sl_addrack_i       <= '1';
                      set_sl_busy        <= '1';
                      addr_cycle_flush   <= '1';

                    else

                      addr_cntl_state    <= GEN_WAIT;
                      sl_wait_i          <= '1';

                    end if;

                 When REARBITRATE =>

                    addr_cntl_state    <= VALIDATE_REQ;

                 When GEN_ADDRACK =>

                    addr_cntl_state    <= VALIDATE_REQ;

                 When others   =>

                    addr_cntl_state    <= VALIDATE_REQ;

               End case;

            End if;

         else

            null;

         end if;

      end process ADDRESS_CONTROLLER;






     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Register Master ID
     -- This process controls the registering of the PLB Master ID signals
     ------------------------------------------------------------------------------
     REGISTER_MID : process (Bus_clk)
       Begin

          If (Bus_clk'EVENT and Bus_clk = '1') Then

             If (Bus_reset = '1') Then

               master_id         <= 0;
               Bus2IP_masterID_i <= (others => '0');

             else

                If (decode_s_h_cs = '1') Then

                   master_id         <= CONV_INTEGER(plb_masterid_reg);
                   Bus2IP_masterID_i <= plb_masterid_reg;

                else

                    null;

                End if;

             End if;

          else
              null;
          End if;


       End process; -- REGISTER_MID






     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Generate the Slave Busy
     -- This process controls the registering and output of the Slave Busy signals
     -- onto the PLB Bus.
     ------------------------------------------------------------------------------
      GENERATE_SL_BUSY : process (Bus_clk)
        Begin

          if (Bus_clk'EVENT and Bus_clk = '1') Then

             sl_mbusy_i <= (others => '0'); -- all busy bits set to zero

             If (Bus_reset = '1' or
                 sig_cmd_abort = '1') Then

                sl_mbusy_i <= (others => '0');
                sl_busy    <= '0';

             elsif (set_sl_busy = '1' and
                    clear_sl_busy = '0') Then

                sl_mbusy_i(master_id) <= '1';  -- set specific bit for req master
                sl_busy               <= '1';

             Elsif (set_sl_busy = '0' and
                    clear_sl_busy = '1') Then

                sl_mbusy_i(master_id) <= '0';
                sl_busy               <= '0';

             else

                sl_mbusy_i(master_id) <= sl_busy; -- stay at sl_busy state

             end if;


          else

              null;

          End if;

        End process; -- GENERATE_SL_BUSY



     error_reply <= data_timeout or MUX2SA_ErrAck;

     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Generate the Slave Error Reply
     -- This process controls the registering and output of the Slave Merr signals
     -- onto the PLB Bus.
     ------------------------------------------------------------------------------
      GENERATE_SL_ERR : process (Bus_clk)
        Begin

           if (Bus_clk'EVENT and Bus_clk = '1') Then

              sl_merr_i <= (others => '0'); -- all error bits set to zero

              If (Bus_reset = '1') Then

                 sl_merr_i <= (others => '0');

              elsif (sl_data_ack = '1') Then

                 sl_merr_i(master_id) <= error_reply;

              else

                 sl_merr_i(master_id) <= '0'; -- no error

              end if;

           else

               null;

           End if;

        End process; -- GENERATE_SL_ERR




    --/////////////////////////////////////////////////////////////////////////////
    ------------------------------------------------------------
    -- If Generate
    --
    -- Label: OMIT_DATA_PHASE_WDT
    --
    -- If Generate Description:
    --  This IFGEN omits the dataphase watchdog timeout function.
    --
    --
    ------------------------------------------------------------
     OMIT_DATA_PHASE_WDT : if (C_DPHASE_TIMEOUT = 0) generate


       begin

           data_timeout  <= '0';


       end generate OMIT_DATA_PHASE_WDT;
    --\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\



    --/////////////////////////////////////////////////////////////////////////////
    ------------------------------------------------------------
    -- If Generate
    --
    -- Label: INCLUDE_DATA_PHASE_WDT
    --
    -- If Generate Description:
    --  This IFGEN implements the dataphase watchdog timeout
    -- function. The counter is allowed to count down when an active
    -- IPIF operation is ongoing. A data acknowledge from the target
    -- address space forces the counter to reload.
    --
    --
    ------------------------------------------------------------
     INCLUDE_DATA_PHASE_WDT : if (C_DPHASE_TIMEOUT > 0) generate


        Constant TIMEOUT_VALUE_TO_USE : integer := check_to_value(C_DPHASE_TIMEOUT);
        Constant COUNTER_WIDTH  : Integer := log2(TIMEOUT_VALUE_TO_USE-2)+1;
        Constant DPTO_LD_VALUE  : std_logic_vector(COUNTER_WIDTH-1 downto 0)
                                  := CONV_STD_LOGIC_VECTOR(TIMEOUT_VALUE_TO_USE-2,
                                                           COUNTER_WIDTH);

        Signal dpto_cntr_ld_en  : std_logic;

        Signal dpto_cnt_en      : std_logic;


       begin


        dpto_cntr_ld_en <= '1'
          When (sl_busy        = '0' or
                MUX2SA_ToutSup = '1')
          Else  sl_data_ack;

        dpto_cnt_en <= '1'; -- always enabled, load suppresses counting



        I_DPTO_COUNTER : entity proc_common_v2_00_a.Counter
          generic map(
            C_NUM_BITS    =>  COUNTER_WIDTH     --: Integer := 9
              )
          port map(
            Clk           =>  bus_clk,          --: in  std_logic;
            Rst           =>  '0',              --: in  std_logic;
            Load_In       =>  DPTO_LD_VALUE,    --: in  std_logic_vector(C_NUM_BITS - 1 downto 0);
            Count_Enable  =>  dpto_cnt_en,      --: in  std_logic;
            Count_Load    =>  dpto_cntr_ld_en,  --: in  std_logic;
            Count_Down    =>  '1',              --: in  std_logic;
            Count_Out     =>  open,             --: out std_logic_vector(C_NUM_BITS - 1 downto 0);
            Carry_Out     =>  data_timeout      --: out std_logic
            );




        end generate INCLUDE_DATA_PHASE_WDT;
    --\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\




-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- End of Combined HDL
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\













-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- Start NON-Burst Support HDL (Single Data Beat Only)
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--

 --////////////////////////////////////////////////////////////////////////////
 ------------------------------------------------------------
 -- If Generate
 --
 -- Label: GEN_SINGLE_ONLY_XFER
 --
 -- If Generate Description:
 -- This If-Generate includes the HDL design for support of
 -- single beat only transfers. The Command validation logic
 -- in the common HDL area of this module will not validate
 -- Cacheline and Burst operations when Single Only mode is
 -- selected. The PLB arbiter will therefor timeout on anything
 -- other than a single data beat transaction.
 --
 --
 ------------------------------------------------------------
 GEN_SINGLE_ONLY_XFER : if (C_SUPPORT_BURST = false) generate

    -- Type Declarations
       type PLB_DATA_CNTRL_STATES is (
                           IDLE,
                           WR_XFER,
                           RD_XFER
                           );

     -- Constant Declarations
       constant WRD_ADDR_LSB     : integer   := C_IPIF_ABUS_WIDTH -
                                                log2(C_PLB_DBUS_WIDTH/8)-1;

     -- Signal Declarations
       signal data_cntl_state     : PLB_DATA_CNTRL_STATES;
       Signal data_cntl_state_ns  : PLB_DATA_CNTRL_STATES;
       signal bus2ip_wrreq_ns     : std_logic;
       signal bus2ip_rdreq_ns     : std_logic;
       signal sl_wrdack_ns        : std_logic;
       signal sl_wrcomp_ns        : std_logic;
       signal clear_sl_busy_ns    : std_logic;
       signal sl_rddack_ns        : std_logic;
       signal sl_rdcomp_ns        : std_logic;


    begin

       -- synthesis translate_off

         -------------------------------------------------------------
         -- Synchronous Process
         --
         -- Label: REPORT_BURST_WARNINGS
         --
         -- Process Description:
         --     This process is used only during simulation to generate
         -- user warnings relating to attempted cacheline and burst
         -- transfers.
         --
         -------------------------------------------------------------
         REPORT_BURST_WARNINGS : process is

            Variable newline : Character := cr;

            begin

               if (burst_transfer = '0') then
                  Wait until (burst_transfer = '1');
               End if;

               if (address_match = '0') then
                 Wait until (address_match = '1' or burst_transfer = '0');
               End if;

               if (burst_transfer = '1' and address_match = '1') then

                  Assert false
                  Report "PLB IPIF Slave Warning ...Single Only transfer mode!" &
                         "     Burst transfer support is not enabled!" &
                         "     An attempted Burst transfer will be ignored!" &
                         "     Please verify the parameter settings for Burst support!"
                  Severity warning;

               end if;

              Wait on plb_abus_reg;

            end process REPORT_BURST_WARNINGS;




         -------------------------------------------------------------
         -- Synchronous Process
         --
         -- Label: REPORT_CACHELN_WARNINGS
         --
         -- Process Description:
         --     This process is used only during simulation to generate
         -- user warnings relating to attempted cacheline and burst
         -- transfers.
         --
         -------------------------------------------------------------
         REPORT_CACHELN_WARNINGS : process is

            Variable newline : Character := cr;

            begin


               if (cacheln_transfer = '0') then
                  Wait until (cacheln_transfer = '1');
               End if;

               if (address_match = '0') then
                  Wait until (address_match = '1' or cacheln_transfer = '0');
               End if;


               if (cacheln_transfer = '1' and address_match = '1') then

                  Assert false
                  Report "PLB IPIF Slave Warning...Single Only transfer mode!" &
                          "    Cacheline transfer support is not enabled!" &
                          "    An attempted cacheline transfer will be ignored!" &
                          "    Please verify the parameter setting for Cacheline support!"
                  Severity warning;

               end if;

              Wait on plb_abus_reg;


            end process REPORT_CACHELN_WARNINGS;

       -- synthesis translate_on



    ---------------------------------------------------------------------------
    -- misc assignments for single-only support

       bus2ip_iburst_i   <= '0'; -- no bursting allowed so tie off to logic '0'

       Bus2IP_Data_i     <=  plb_wrdbus_reg ;

       Bus2IP_Burst_i    <= '0'; -- no burst support so never assert

       SA2Steer_BE_i     <= bus2ip_be_i;

       SA2Steer_addr_i   <= bus2ip_addr_i(C_PLB_ABUS_WIDTH -
                                          C_STEER_ADDR_SIZE
                                          to
                                          C_PLB_ABUS_WIDTH-1);

       sl_data_ack       <= data_ack;


     -- Set to Zero unused outputs in single-only mode
       sl_rdbterm_i     <= '0';             -- bursts
       sl_wrbterm_i     <= '0';             -- bursts
       sl_rdwdaddr_i    <= (others => '0'); -- cachelines


    ---------------------------------------------------------------------------


    ------------------------------------------------------------------------------
    -- Create the load enables and clears for the address decoder for
    -- non-burst support operation mode


      Addr_cntr_load_en <=  set_sl_busy and
                            not(sig_cmd_abort);

      decode_clr_rw_ce  <=  data_ack or
                            sig_cmd_abort;  -- added PLB abort support

      decode_cs_ce_clr  <=  data_ack or
                            sig_cmd_abort;  -- added PLB abort support

      decode_s_h_cs      <=  not(sl_busy) or
                             (address_match and clear_sl_busy);

      decode_cs_clr      <=  clear_sl_busy and not(address_match);



    ------------------------------------------------------------------------------






    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Data Phase Support

      start_data_phase <=  set_sl_busy;

      data_ack         <=  MUX2SA_RdAck or  -- Read acknowledge
                           MUX2SA_WrAck or  -- Write Acknowledge
                           data_timeout;    -- Acknowledge Timeout


     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Data Controller State Machine
     -- This state machine controls the transfer of data to/from the PLB Bus
     ------------------------------------------------------------------------------
     DATA_CONTROLLER : Process (data_cntl_state,
                                start_data_phase,
                                addr_cntl_state,
                                sig_cmd_abort,
                                plb_rnw_reg,
                                data_ack)
       begin

        -- default conditions
         data_cntl_state_ns  <= IDLE;
         bus2ip_wrreq_ns     <= '0';
         bus2ip_rdreq_ns     <= '0';
         decode_ld_rw_ce     <= '0';
         sl_wrdack_ns        <= '0';
         sl_wrcomp_ns        <= '0';
         clear_sl_busy_ns    <= '0';
         sl_rddack_ns        <= '0';
         sl_rdcomp_ns        <= '0';


          Case data_cntl_state  Is

            When IDLE =>

               If (start_data_phase = '1' and
                   sig_cmd_abort    = '0') Then

                  If (plb_rnw_reg = '0') Then  -- write op

                    data_cntl_state_ns   <= WR_XFER;
                    decode_ld_rw_ce      <= '1';
                    bus2ip_wrreq_ns      <= '1';

                  Else                         -- read op

                    data_cntl_state_ns    <= RD_XFER;
                    decode_ld_rw_ce       <= '1';
                    bus2ip_rdreq_ns       <= '1';

                  End if;

               else

                  data_cntl_state_ns   <= IDLE;

               End if;


            When WR_XFER =>

               If (data_ack = '1') Then

                  data_cntl_state_ns   <= IDLE;
                  sl_wrdack_ns         <= '1';
                  sl_wrcomp_ns         <= '1';
                  clear_sl_busy_ns     <= '1';

               else

                  data_cntl_state_ns   <= WR_XFER;

               End if;


            When RD_XFER =>

               If (data_ack = '1') Then

                  data_cntl_state_ns  <= IDLE;
                  sl_rddack_ns        <= '1';
                  sl_rdcomp_ns        <= '1';
                  clear_sl_busy_ns    <= '1';

               else

                  data_cntl_state_ns  <= RD_XFER;

               End if;


            When others   =>

               data_cntl_state_ns    <= IDLE;

          End case;

       end process DATA_CONTROLLER;




    -------------------------------------------------------------
    -- Synchronous Process with Sync Reset
    --
    -- Label: DATA_CONTROLLER_SYNCD
    --
    -- Process Description:
    --  This process implements the registered portion of the
    --  DATA_CONTROLLER State Machine.
    --
    -------------------------------------------------------------
    DATA_CONTROLLER_SYNCD : process (bus_clk)
       begin
         if (Bus_Clk'event and Bus_Clk = '1') then
            if (Bus_reset = '1') then

               data_cntl_state     <=  IDLE;
               bus2ip_wrreq_i      <=  '0';
               bus2ip_rdreq_i      <=  '0';
               sl_wrdack_i         <=  '0';
               sl_wrcomp_i         <=  '0';
               clear_sl_busy       <=  '0';
               sl_rddack_i         <=  '0';
               sl_rdcomp_i         <=  '0';

            else

               data_cntl_state     <=  data_cntl_state_ns;
               bus2ip_wrreq_i      <=  bus2ip_wrreq_ns   ;
               bus2ip_rdreq_i      <=  bus2ip_rdreq_ns   ;
               sl_wrdack_i         <=  sl_wrdack_ns      ;
               sl_wrcomp_i         <=  sl_wrcomp_ns      ;
               clear_sl_busy       <=  clear_sl_busy_ns  ;
               sl_rddack_i         <=  sl_rddack_ns      ;
               sl_rdcomp_i         <=  sl_rdcomp_ns      ;

            end if;
         else
           null;
         end if;
       end process DATA_CONTROLLER_SYNCD;




     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Read Data Register
     -- This process controls the registering and output of the Slave read data
     -- onto the PLB Bus.
     ------------------------------------------------------------------------------
       READ_DATA_REGISTER : process (Bus_clk)
         Begin

            if (Bus_clk'EVENT and Bus_clk = '1') Then

               If (Bus_reset = '1') Then

                  sl_rddbus_i <= (others => '0');

               elsif (data_cntl_state <= RD_XFER and
                      MUX2SA_RdAck = '1') Then

                  sl_rddbus_i <= MUX2SA_Data;

               else

                  sl_rddbus_i <= (others => '0');

               End if;

            else

                null;

            End if;

         End process; -- READ_DATA_REGISTER




    -------------------------------------------------------------------------------
    --Process
    --
    -- Sample and hold the transfer qualifer signals to be output to the IPIF
    -- during the data phase of a bus transfer. In single only mode, these
    -- qualifiers are cleared upon the recept of the data acknowledge from the
    -- target or a data phase timeout occurs.
    -------------------------------------------------------------------------------
    S_AND_H_XFER_QUAL : process (Bus_clk)
       begin
          If (Bus_clk'EVENT and Bus_clk = '1') Then

             If (Bus_reset = '1' or
                 data_ack = '1') Then

                bus2ip_rnw_i            <= '0';
                bus2ip_size_i           <= (others => '0');
                Bus2IP_type_i           <= (others => '0');
                bus2ip_be_i             <= (others => '0');
                bus2ip_addr_i           <= (others => '0');

             else

                If (Addr_cntr_load_en = '1') Then

                   bus2ip_rnw_i            <=  plb_rnw_reg;
                   bus2ip_size_i           <=  plb_size_reg;
                   Bus2IP_type_i           <=  plb_type_reg;
                   bus2ip_be_i             <=  plb_be_reg;
                   bus2ip_addr_i           <=  plb_abus_reg;

                else

                    null;

                End if;

             End if;

          else
              null;
          End if;
       end process; -- S_AND_H_XFER_QUAL







    end generate GEN_SINGLE_ONLY_XFER;
--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\










-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- Start Burst Support HDL
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--

-- ////////////////////////////////////////////////////////////////////////////
 ------------------------------------------------------------
 -- If Generate
 --
 -- Label: GEN_FAST_MODE_BURSTXFER
 --
 -- If Generate Description:
 -- This If-Generate includes the HDL design for single beat,
 -- cache line, and fixed length burst transfers. It also
 -- enhances Cache line interactions to operate at up to 1 data
 -- beat per bus clock (the same as a burst transaction).
 --
 ------------------------------------------------------------
 GEN_FAST_MODE_BURSTXFER : if (FAST_MODE_BURSTXFER) generate


   -- Component Declarations for Burst support


     -- Xilinx Prim    component FDRSE
     -- Xilinx Prim      port(
     -- Xilinx Prim        Q   :  out   STD_ULOGIC;
     -- Xilinx Prim        C   :  in    STD_ULOGIC;
     -- Xilinx Prim        CE  :  in    STD_ULOGIC;
     -- Xilinx Prim        D   :  in    STD_ULOGIC;
     -- Xilinx Prim        R   :  in    STD_ULOGIC;
     -- Xilinx Prim        S   :  in    STD_ULOGIC
     -- Xilinx Prim        );
     -- Xilinx Prim    end component;


     -- Type declarations

      type PLB_WRDATA_CNTRL_STATES is (
                          PBWR_IDLE,
                          PBWR_INIT,
                          PBWR_BURST_FIXED,
                          PBWR_BURST_INDET,
                          PBWRITE_FLUSH
                          );

      type PLB_RDDATA_CNTRL_STATES is (
                          PBRD_IDLE,
                          PBRD_SINGLE_INIT,
                          PBRD_SINGLE,
                          PBRD_BURST_INIT,
                          PBRD_BURST_FIXED,
                          PBRD_BURST_INDET,
                          PBRD_BURST_INDET_DONE,
                          PBREAD_FLUSH
                          );


      Type IPIF_WR_CNTRL_STATES is (
                          IWR_IDLE,
                          IWR_INIT,
                          IWR_BURST_INDET1,
                          IWR_BURST_INDET2,
                          IWR_BURST_FIXED1,
                          IWR_SINGLE1,
                          IWR_SINGLE2
                          );


      constant WRD_ADDR_LSB     : integer   := C_STEER_ADDR_SIZE -
                                               log2(C_PLB_DBUS_WIDTH/8) - 1;

      Constant MAX_BUS_WIDTH_RATIO   : integer range 1 to 8 := 256/32; -- = 8

      signal plb_write_cntl_state    : PLB_WRDATA_CNTRL_STATES;
      signal plb_write_cntl_state_ns : PLB_WRDATA_CNTRL_STATES;
      signal plb_read_cntl_state     : PLB_RDDATA_CNTRL_STATES;
      signal plb_read_cntl_state_ns  : PLB_RDDATA_CNTRL_STATES;
      signal ipif_wr_cntl_state      : IPIF_WR_CNTRL_STATES;
      signal ipif_wr_cntl_state_ns   : IPIF_WR_CNTRL_STATES;
      Signal sig_wr_data_ack         : std_logic;
      Signal sig_rd_data_ack         : std_logic;
      Signal wr_buf_done_out         : std_logic;
      Signal wr_buf_rden             : std_logic;
      Signal wr_buf_empty            : std_logic;
      Signal wr_buf_burst_in         : std_logic;
      Signal wr_buf_burst_out        : std_logic;
      Signal wr_buf_data_in          : std_logic_vector(0 to C_PLB_DBUS_WIDTH+1);
      Signal wr_buf_data_out         : std_logic_vector(0 to C_PLB_DBUS_WIDTH+1);
      Signal wr_buf_move_data        : std_logic;
      Signal wrreq_out               : std_logic;
      signal wr_buff_addr_out        : std_logic_vector(0 to 3);
      Signal wrbuf_goingfull         : std_logic;
      Signal wrbuf_full              : std_logic;
      Signal sl_wrdack_i_dly1        : std_logic;
      Signal wr_buf_wren             : std_logic;
      Signal line_done_dly1          : std_logic;
      Signal last_wr_data            : std_logic;
      Signal wr_buf_done_in          : std_logic;
      Signal Bus2IP_WrBurst_i        : std_logic;
      Signal Bus2IP_RdBurst_i        : std_logic;
      Signal data_request_active     : std_logic;
      Signal Control_Ack_i           : std_logic;
      Signal Control_AlmostDone_i    : std_logic;
      Signal Control_Done_i          : std_logic;
      Signal Response_Ack_i          : std_logic;
      Signal Response_ack_dly1       : std_logic;
      Signal Response_AlmostDone_i   : std_logic;
      Signal Response_Done_i         : std_logic;
      Signal data_cycle_count        : Integer range 0 to MAX_FIXED_XFER_COUNT-1;
      Signal num_data_beats_minus1   : integer range 0 to MAX_FIXED_XFER_COUNT-1;
      Signal rd_dphase_active        : std_logic;
      Signal wr_dphase_active        : std_logic;

     -- IPIF Write State Machine
      Signal wr_ce_ld_enable     : std_logic;
      Signal clear_wr_ce         : std_logic;
      Signal clear_sl_wr_busy    : std_logic;
      Signal clear_sl_wr_busy_ns : std_logic;
      Signal bus2ip_wrburst_ns   : std_logic;
      Signal wr_dphase_active_ns : std_logic;
      Signal wr_buf_rden_ns      : std_logic;
      Signal bus2ip_wrreq_ns     : std_logic;
      Signal set_bus2ip_wrreq    : std_logic;
      Signal clr_bus2ip_wrreq    : std_logic;

    -- New Read SM signals
      Signal set_bus2ip_rdreq    : std_logic;
      Signal clr_bus2ip_rdreq    : std_logic;
      Signal last_read_data_ns   : std_logic;
      Signal last_read_data      : std_logic;
      
    -- Error assertion fix
      Signal fastbrst_clear_sl_wr_busy : std_logic;
      Signal extend_wr_busy      : std_logic;

    -- Misc Signals
      Signal rd_burst_done       : std_logic;
      Signal rd_data_ack         : std_logic;
      Signal rd_data_ack_ns      : std_logic;


    begin



 -- Misc. logic assignments



    ------------------------------------------------------------------------------
    -- Address decoder support
    --
    -- Create the load enables and clears for the decoder chip select (CS) and
    -- chip enable (CE) signals that need to be latched and held during the
    -- data phase of a request

     Addr_cntr_load_en  <=  address_match and
                            not(sl_busy) and
                            not(sig_inhib_Addr_cntr_ld);

     decode_cs_ce_clr   <=  (Response_Ack_i and Response_Done_i) or
                             sig_cmd_abort
                             when (indeterminate_burst_reg = '0')
                             else (Response_Ack_i and last_wr_data) or  -- indeterminate write case
                                   last_read_data_ns                or  -- indeterminate read case
                                   sig_cmd_abort;

     decode_ld_rw_ce    <=  wr_ce_ld_enable or rd_ce_ld_enable;

     decode_clr_rw_ce   <=  clear_rd_ce or clear_wr_ce;

     decode_s_h_cs      <=  not(sl_busy) or
                            (address_match and clear_sl_busy);

     decode_cs_clr      <=  clear_sl_busy and not(address_match);



    ------------------------------------------------------------------------------



    -------------------------------------------------------------------------------
    -- Data Phase Support


      bus2ip_iburst_i <= indeterminate_burst_reg;


      sl_data_ack      <=  Response_Ack_i;


      start_data_phase <=  set_sl_busy;



      sig_wr_data_ack  <=  MUX2SA_WrAck or  -- Write Acknowledge
                           data_timeout;    -- Acknowledge Timeout

      sig_rd_data_ack  <=  MUX2SA_RdAck or  -- Read acknowledge
                           data_timeout;    -- Acknowledge Timeout



      data_ack         <=  MUX2SA_RdAck or  -- Read acknowledge
                           MUX2SA_WrAck or  -- Write Acknowledge
                           data_timeout;    -- Acknowledge Timeout


      clear_sl_busy    <=  clear_sl_rd_busy or
                           fastbrst_clear_sl_wr_busy;

      fastbrst_clear_sl_wr_busy <=  (clear_sl_wr_busy and not(error_reply))
                                     or
                                     extend_wr_busy;

      -- Assign the PLB read word address
      rdwdaddr         <=  SA2Steer_addr_i(WRD_ADDR_LSB-2 to
                                          WRD_ADDR_LSB) & '0';




       sl_rddack_i    <=  rd_data_ack and not(rd_burst_done);








      -------------------------------------------------------------
      -- Synchronous Process with Sync Reset
      --
      -- Label: XTEND_BUSY
      --
      -- Process Description:
      -- This process detects the assertion of the Error Reply signal
      -- and generates a signal to extend the Sl_Mbusy assertion by
      -- one PLB Clock. This enables the Sl_Merr assertion to be under
      -- the umbrella of the Sl_Mbusy assertion.
      --
      -------------------------------------------------------------
      XTEND_BUSY : process (bus_clk)
         begin
           if (Bus_Clk'event and Bus_Clk = '1') then
              if (Bus_Reset = '1') then

                 extend_wr_busy <= '0';

              elsif (clear_sl_wr_busy = '1' and
                     error_reply = '1') then

                 extend_wr_busy <= '1';

              else

                 extend_wr_busy <= '0';

              end if;
           else
             null;
           end if;
         end process XTEND_BUSY;




     -------------------------------------------------------------
     -- Synchronous Process with Sync Reset
     --
     -- Label: DETECT_RDBURST_DONE
     --
     -- Process Description:
     --
     --
     -------------------------------------------------------------
     DETECT_RDBURST_DONE : process (bus_clk)
        begin
          if (Bus_Clk'event and Bus_Clk = '1') then
             if (Bus_reset          = '1' or
                 clear_sl_rd_busy = '1') then

                rd_burst_done <= '0';

             elsif (sl_rddack_i = '1'  and
                    PLB_rdBurst = '0'  and
                    cacheln_burst_reg = '0') then

               rd_burst_done <= '1';

             else
               null; -- hold state
             end if;
          else
            null;
          end if;
        end process DETECT_RDBURST_DONE;






    -------------------------------------------------------------
    -- Synchronous Process
    --
    -- Label: PLB_RDDATA_CONTROLLER
    --
    -- Process Description:
    -- This state machine controls the transfer of data to
    -- the PLB Bus (Reads).
    --
    --
    -------------------------------------------------------------
    PLB_RDDATA_CONTROLLER : process (plb_read_cntl_state,
                                     start_data_phase,
                                     plb_rnw_reg,
                                     addr_cntl_state,
                                     sig_cmd_abort,
                                     indeterminate_burst,
                                     single_transfer,
                                     Control_Ack_i,
                                     Control_done_i,
                                     Response_Ack_i,
                                     Response_AlmostDone_i,
                                     Response_Done_i,
                                     rdwdaddr,
                                     plb_rdburst_reg,
                                     PLB_rdBurst,
                                     sl_rddack_i,
                                     rd_dphase_active)
      begin

        -- default conditions
         Bus2IP_RdBurst_ns      <= '0';
         rd_data_ack_ns         <= '0';
         sl_rdcomp_ns           <= '0';
         sl_rdbterm_ns          <= '0';
         sl_rdwdaddr_ns         <= (others => '0');
         rd_dphase_active_ns    <= '0';
         rd_ce_ld_enable        <= '0';
         clear_rd_ce            <= '0';
         clear_sl_rd_busy_ns    <= '0';
         set_bus2ip_rdreq       <= '0';
         clr_bus2ip_rdreq       <= '0';
         last_read_data_ns      <= '0';


         Case plb_read_cntl_state Is

           When PBRD_IDLE =>

              If (start_data_phase = '1' and
                  plb_rnw_reg      = '1' and
                  sig_cmd_abort    = '0') Then

                 rd_ce_ld_enable      <= '1';
                 rd_dphase_active_ns  <= '1';
                 set_bus2ip_rdreq     <= '1';


                 If (indeterminate_burst = '1') Then  -- indeterminate burst request


                   plb_read_cntl_state_ns  <= PBRD_BURST_INDET;
                   Bus2IP_RdBurst_ns       <= '1';
                   rd_dphase_active_ns     <= '1';

                 Elsif (single_transfer = '0') Then  --  fixed burst or cacheln read

                   plb_read_cntl_state_ns  <= PBRD_BURST_FIXED;
                   Bus2IP_RdBurst_ns       <= '1';

                 else                         -- single beat read request

                   plb_read_cntl_state_ns  <= PBRD_SINGLE;

                 End if;

              else

                 plb_read_cntl_state_ns  <= PBRD_IDLE;
                 clr_bus2ip_rdreq        <= '1';

              End if;


           When PBRD_SINGLE =>


              clr_bus2ip_rdreq        <= '1';

              If (Response_Ack_i = '1') Then

                 plb_read_cntl_state_ns   <= PBREAD_FLUSH;
                 rd_data_ack_ns             <= '1';
                 sl_rdcomp_ns             <= '1';
                 clear_sl_rd_busy_ns      <= '1';
                 sl_rdwdaddr_ns           <= rdwdaddr;
                 clear_rd_ce              <= '1';

              else

                 plb_read_cntl_state_ns   <= PBRD_SINGLE;
                 rd_dphase_active_ns      <= '1';

              End if;


           When PBRD_BURST_INDET =>

               If (sl_rddack_i = '1'  and                 -- PLB DDR Bug Fix     
                   PLB_rdBurst = '0') Then                     
                                                               
                  rd_dphase_active_ns     <= '0';             
                  plb_read_cntl_state_ns  <= PBREAD_FLUSH;
                  last_read_data_ns       <= '1';
                  clear_rd_ce             <= '1';
                  clear_sl_rd_busy_ns     <= '1';
                  clr_bus2ip_rdreq        <= '1'; 
                  sl_rdcomp_ns            <= '1';
                  Bus2IP_RdBurst_ns       <= '0'; 
                                                             
               else                                            
                                                               
                   rd_dphase_active_ns     <= rd_dphase_active;
                   plb_read_cntl_state_ns  <= PBRD_BURST_INDET;   -- CR206455 fix 
                   Bus2IP_RdBurst_ns       <= '1';                                
                   rd_data_ack_ns          <=  Response_Ack_i;
                   
                   If (Control_Ack_i = '1' and   
                       PLB_rdBurst   = '0') Then 
                                                 
                      clr_bus2ip_rdreq    <= '1';
                                                 
                   End if;                       
                                                               
               End if;                                         
              
              
              -- If (sl_rddack_i = '1'  and                 -- PLB DDR Bug Fix
              --     PLB_rdBurst = '0') Then
              -- 
              --     rd_dphase_active_ns     <= '0';
              -- 
              -- else
              -- 
              --     rd_dphase_active_ns     <= rd_dphase_active;
              -- 
              -- End if;
              -- 
              -- rd_data_ack_ns   <=  Response_Ack_i;
              -- 
              -- If (Response_Ack_i = '1'   and
              --     PLB_rdBurst    = '0') Then
              -- 
              --     plb_read_cntl_state_ns  <= PBRD_BURST_INDET_DONE;
              --     sl_rdcomp_ns            <= '1';
              --     Bus2IP_RdBurst_ns       <= '0';
              -- 
              -- else
              -- 
              --     plb_read_cntl_state_ns  <= PBRD_BURST_INDET;   -- CR206455 fix
              --     Bus2IP_RdBurst_ns       <= '1';
              -- 
              -- 
              -- End if;
              -- 
              -- 
              -- If (Control_Ack_i = '1' and
              --     PLB_rdBurst   = '0') Then
              -- 
              --    clr_bus2ip_rdreq    <= '1';
              -- 
              -- End if;


           When  PBRD_BURST_INDET_DONE  =>

              If (Control_Ack_i = '1' and
                  PLB_rdBurst   = '0') Then

                 clr_bus2ip_rdreq    <= '1';

              End if;

  
              --If (Response_Ack_i = '1') Then
              If (sl_rddack_i = '1') Then         -- PLB DDR Bug Fix

                  plb_read_cntl_state_ns  <= PBREAD_FLUSH;
                  last_read_data_ns       <= '1';
                  clear_rd_ce             <= '1';
                  clear_sl_rd_busy_ns     <= '1';

              else

                  plb_read_cntl_state_ns  <= PBRD_BURST_INDET_DONE;

              End if;




           When PBRD_BURST_FIXED =>

              rd_data_ack_ns        <= Response_Ack_i;
              sl_rdwdaddr_ns        <= rdwdaddr;

              clr_bus2ip_rdreq      <= Control_Ack_i and
                                       Control_done_i;

              If (Response_Ack_i = '1'and
                  Response_Done_i = '1') Then

                 plb_read_cntl_state_ns  <= PBREAD_FLUSH;
                 sl_rdcomp_ns            <= '1';
                 clear_sl_rd_busy_ns     <= '1';
                 clear_rd_ce             <= '1';

              Elsif (Response_Ack_i = '1' and
                     Response_AlmostDone_i = '1') Then

                 plb_read_cntl_state_ns  <= PBRD_BURST_FIXED;
                 rd_dphase_active_ns     <= '1';
                 Bus2IP_RdBurst_ns       <= '0';
                 sl_rdbterm_ns           <= plb_rdburst_reg;


              else

                 plb_read_cntl_state_ns  <= PBRD_BURST_FIXED;
                 rd_dphase_active_ns     <= '1';
                 Bus2IP_RdBurst_ns       <= not(Response_Done_i);
                 sl_rdbterm_ns           <= '0';

              End if;


           When PBREAD_FLUSH =>

              plb_read_cntl_state_ns   <= PBRD_IDLE;
              clear_rd_ce              <= '1';


           When others   =>

              plb_read_cntl_state_ns   <= PBRD_IDLE;
              clear_rd_ce              <= '1';

         End case;


      end process PLB_RDDATA_CONTROLLER;




    -------------------------------------------------------------
    -- Synchronous Process with Sync Reset
    --
    -- Label: PLB_RD_SM_SYNCD
    --
    -- Process Description:
    --      This process registers outputs from the PLB Read Data
    --  state machine.
    --
    -------------------------------------------------------------
    PLB_RD_SM_SYNCD : process (bus_clk)
       begin
         if (Bus_Clk'event and Bus_Clk = '1') then
            if (Bus_reset = '1') then

              plb_read_cntl_state   <= PBRD_IDLE;
              Bus2IP_RdBurst_i      <= '0';
              rd_data_ack           <= '0';
              sl_rdcomp_i           <= '0';
              sl_rdbterm_i          <= '0';
              sl_rdwdaddr_i         <= (others => '0');
              rd_dphase_active      <= '0';
              clear_sl_rd_busy      <= '0';
              last_read_data        <= '0';

            else

              plb_read_cntl_state   <= plb_read_cntl_state_ns;
              Bus2IP_RdBurst_i      <= Bus2IP_RdBurst_ns   ;
              rd_data_ack           <= rd_data_ack_ns      ;
              sl_rdcomp_i           <= sl_rdcomp_ns        ;
              sl_rdbterm_i          <= sl_rdbterm_ns       ;
              sl_rdwdaddr_i         <= sl_rdwdaddr_ns      ;
              rd_dphase_active      <= rd_dphase_active_ns ;
              clear_sl_rd_busy      <= clear_sl_rd_busy_ns ;
              last_read_data        <= last_read_data_ns   ;

            end if;
         else
           null;
         end if;
       end process PLB_RD_SM_SYNCD;



    -- Instantiate the Register for the Bus2IP_RdReq signal generation.
    -- This is needed for Determinate Read Timing to terminate the RdReq
    -- when the Address & Control timing is complete but data transfer is
    -- not yet complete do to pipeline delays.
     I_RDREQ_FDRSE : FDRSE
     port map(
       Q  =>  bus2ip_rdreq_i,    -- : out std_logic;
       C  =>  Bus_Clk,           -- : in  std_logic;
       CE =>  '1',               -- : in  std_logic;
       D  =>  bus2ip_rdreq_i,    -- : in  std_logic;
       R  =>  clr_bus2ip_rdreq,  -- : in  std_logic
       S  =>  set_bus2ip_rdreq   -- : in  std_logic
     );



    -------------------------------------------------------------
    -- Synchronous Process
    --
    -- Label: PLB_WRITE_DATA_CONTROLLER
    --
    -- Process Description:
    -- This state machine controls the transfer of data from
    -- the PLB Bus (writes). The write data is put
    -- into an intermediate FIFO buffer. A second data write
    -- state machine is then activated to transfer data from the
    -- FIFO buffer to the IPIF.
    -------------------------------------------------------------
    PLB_WRITE_DATA_CONTROLLER : process (plb_write_cntl_state,
                                         start_data_phase,
                                         plb_rnw_reg,
                                         sig_cmd_abort,
                                         indeterminate_burst,
                                         burst_transfer,
                                         num_data_beats_minus1,
                                         single_transfer,
                                         wrbuf_goingfull,
                                         line_count_done,
                                         line_count_almostdone,
                                         burst_transfer_reg,
                                         PLB_wrBurst,
                                         sl_wrdack_i)
      begin


        plb_write_cntl_state_ns  <= PBWR_IDLE;
        sl_wrdack_ns             <= '0';
        sl_wrcomp_ns             <= '0';
        sl_wrbterm_ns            <= '0';

        Case plb_write_cntl_state Is

          When PBWR_IDLE =>


             If (start_data_phase = '1' and
                 plb_rnw_reg      = '0' and
                 sig_cmd_abort    = '0') Then


                If (indeterminate_burst = '1') Then

                   plb_write_cntl_state_ns   <= PBWR_BURST_INDET;
                   sl_wrdack_ns              <= not(wrbuf_goingfull);

                elsif (burst_transfer = '1' and
                       num_data_beats_minus1 = 1) Then  -- burst write request of 2 data beats

                   plb_write_cntl_state_ns   <= PBWR_BURST_FIXED;
                   sl_wrdack_ns              <= not(wrbuf_goingfull);
                   sl_wrbterm_ns             <= '1';  -- terminate on first Sl_wrDAck

                elsif (single_transfer = '0') Then  -- burst write of more than 2 data beats or
                                                    -- cacheln write request

                   plb_write_cntl_state_ns   <= PBWR_BURST_FIXED;
                   sl_wrdack_ns              <= not(wrbuf_goingfull);

                else  -- single data beat write

                   plb_write_cntl_state_ns   <= PBWRITE_FLUSH;
                   sl_wrdack_ns              <= '1';
                   sl_wrcomp_ns              <= '1';

                End if;

             else

                plb_write_cntl_state_ns <= PBWR_IDLE;

             End if;


          When PBWR_BURST_FIXED =>

            If (line_count_done = '1') Then

                plb_write_cntl_state_ns  <= PBWRITE_FLUSH;
                sl_wrdack_ns             <= '1';
                sl_wrcomp_ns             <= '1';

             else

                plb_write_cntl_state_ns  <= PBWR_BURST_FIXED;
                sl_wrdack_ns             <= not(wrbuf_goingfull);
                sl_wrbterm_ns            <= line_count_almostdone and
                                            burst_transfer_reg;

             End if;



          When PBWR_BURST_INDET =>

            if (PLB_wrBurst = '0' and    -- last write data beat
                sl_wrdack_i = '1') then  -- and is being ack'd

               plb_write_cntl_state_ns  <= PBWRITE_FLUSH;
               sl_wrcomp_ns             <= '1';

            else

               plb_write_cntl_state_ns  <= PBWR_BURST_INDET;
               sl_wrdack_ns             <= not(wrbuf_goingfull);

            end if;


          When PBWRITE_FLUSH =>

             plb_write_cntl_state_ns   <= PBWR_IDLE;


          When others   =>

             plb_write_cntl_state_ns   <= PBWR_IDLE;

        End case;


      end process PLB_WRITE_DATA_CONTROLLER;



    -------------------------------------------------------------
    -- Synchronous Process with Sync Reset
    --
    -- Label: PLB_WR_SM_SYNCD
    --
    -- Process Description:
    --     This process registers the syncronous outputs of the
    -- PLB Write state machine.
    --
    -------------------------------------------------------------
    PLB_WR_SM_SYNCD : process (bus_clk)
       begin
         if (Bus_Clk'event and Bus_Clk = '1') then
            if (Bus_Reset = '1') then

               plb_write_cntl_state   <= PBWR_IDLE;
               sl_wrdack_i            <= '0';
               sl_wrcomp_i            <= '0';
               sl_wrbterm_i           <= '0';

            else

               plb_write_cntl_state   <= plb_write_cntl_state_ns;
               sl_wrdack_i            <= sl_wrdack_ns ;
               sl_wrcomp_i            <= sl_wrcomp_ns ;
               sl_wrbterm_i           <= sl_wrbterm_ns;

            end if;
         else
           null;
         end if;
       end process PLB_WR_SM_SYNCD;



    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: SELECT_DONE_TO_WRBUF
    --
    -- Process Description:
    --  This process selects the appropriate source of the 'done'
    -- signal for input to the Write Buffer.
    --
    -------------------------------------------------------------
    SELECT_DONE_TO_WRBUF : process (line_done_dly1,
                                    single_transfer_reg,
                                    indeterminate_burst_reg,
                                    PLB_wrBurst)
       begin

         if (single_transfer_reg = '1') then
           wr_buf_done_in <= '1';
         Elsif (indeterminate_burst_reg = '1') Then
           wr_buf_done_in <= not(PLB_wrBurst);
         else
           wr_buf_done_in <= line_done_dly1;
         end if;

       end process SELECT_DONE_TO_WRBUF;



    -------------------------------------------------------------
    -- Synchronous Process
    --
    -- Label: GEN_wr_buf_wren
    --
    -- Process Description:
    -- This process generates the write enable to the write buffer.
    -- It is essentially an echo of sl_wrDAck response to the PLB
    --
    -------------------------------------------------------------
    GEN_WR_BUF_WREN : process (bus_clk)
       begin
         if (bus_clk'event and bus_clk = '1') then
            if (bus_reset = '1') then
              wr_buf_wren        <= '0';
            else
              wr_buf_wren       <= sl_wrdack_ns;
            end if;
         else
           null;
         end if;
       end process GEN_WR_BUF_WREN;


    -- Build the input data elements for the Wr Data Buffer

     wr_buf_burst_in  <=  PLB_wrBurst or
                         (cacheln_burst_reg and
                          not(line_done_dly1));

     wr_buf_data_in   <=  wr_buf_done_in &
                          wr_buf_burst_in &
                          PLB_wrDBus;

   -------------------------------------------------------------------------------
   -- Instantiate the FIFO implementing the Wr Data Buffer
   -------------------------------------------------------------------------------

     WR_DATA_BUFFER : entity proc_common_v2_00_a.srl_fifo2
       generic map(
         C_DWIDTH =>  C_PLB_DBUS_WIDTH+2,   --: positive;
         C_DEPTH  =>  16,                   --: positive;
         C_XON    =>  false                 --: boolean  := false  -- needed for mixed mode sims
         )
       port map(
         Clk         =>  bus_clk,           --: in  std_logic;
         Reset       =>  Bus_reset,         --: in  std_logic;
         FIFO_Write  =>  wr_buf_wren,       --: in  std_logic;
         Data_In     =>  wr_buf_data_in,    --: in  std_logic_vector(0 to C_DWIDTH-1);
         FIFO_Read   =>  wr_buf_move_data,  --: in  std_logic;
         Data_Out    =>  wr_buf_data_out,   --: out std_logic_vector(0 to C_DWIDTH-1);
         FIFO_Full   =>  wrbuf_full,        --: out std_logic;
         FIFO_Empty  =>  wr_buf_empty,      --: out std_logic;  -- new port
         Data_Exists =>  open,              --: out std_logic;
         Addr        =>  wr_buff_addr_out   --: out std_logic_vector(0 to 3)
         );


    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: GEN_WRBUF_GOINGFULL
    --
    -- Process Description:
    -- This process determines if there is at least one vacant
    -- storage location in the Write Buffer and it generates a
    -- signal to indicate the condition. Two storage locations are
    -- needed because there is a one clock delay between assertion of
    -- sl_wrAck_i and the next plb_wrdata_reg being available to write
    -- into the write buffer.
    -------------------------------------------------------------
    GEN_WRBUF_GOINGFULL : process (wr_buff_addr_out)
       begin

         if (wr_buff_addr_out < 14) then
           wrbuf_goingfull <= '0';
         else
           wrbuf_goingfull <= '1';
         end if;

       end process GEN_WRBUF_GOINGFULL;


    -------------------------------------------------------------
    -- Synchronous Process
    --
    -- Label: IPIF_WR_DATA_CONTROLLER
    --
    -- Process Description:
    -- This process implements a state machine that transfers
    -- write data from the intermediate WR FIFO buffer to the
    -- selected target device (IPIF element or IP)
    --
    -------------------------------------------------------------
    IPIF_WR_DATA_CONTROLLER : process (ipif_wr_cntl_state,
                                       start_data_phase,
                                       plb_rnw_reg,
                                       sig_cmd_abort,
                                       wr_buf_empty,
                                       wr_buf_burst_out,
                                       last_wr_data,
                                       indeterminate_burst_reg,
                                       burst_transfer_reg,
                                       cacheln_burst_reg,
                                       Response_Ack_i,
                                       Response_Done_i,
                                       Response_AlmostDone_i,
                                       bus2ip_wrburst_i,
                                       sig_wr_data_ack,
                                       Control_Ack_i,
                                       Control_AlmostDone_i,
                                       Control_Done_i
                                       )
       begin

         -- default conditions
          ipif_wr_cntl_state_ns  <= IWR_IDLE;
          wr_ce_ld_enable        <= '0';
          clear_wr_ce            <= '0';
          wr_buf_rden_ns         <= '0';
          clear_sl_wr_busy       <= '0';
          wr_dphase_active_ns    <= '0';
          bus2ip_wrburst_ns      <= '0';
          set_bus2ip_wrreq       <= '0';
          clr_bus2ip_wrreq       <= '0';
          wr_buf_move_data       <= '0';


          Case ipif_wr_cntl_state Is

            When IWR_IDLE =>

               If (start_data_phase = '1' and
                   plb_rnw_reg      = '0'  and
                   sig_cmd_abort    = '0') Then

                  ipif_wr_cntl_state_ns  <= IWR_INIT;

               else

                  ipif_wr_cntl_state_ns <= IWR_IDLE;

               End if;


            When IWR_INIT =>



               if (wr_buf_empty = '1') Then

                  ipif_wr_cntl_state_ns <= IWR_INIT;

               else

                  wr_buf_move_data      <= '1'; -- pop first write data value
                                                -- out of the write buffer
                  wr_dphase_active_ns   <= '1';
                  wr_ce_ld_enable       <= '1';
                  set_bus2ip_wrreq      <= '1';    -- new way (set the WrReq F-F)



                  -- Note: Test order is important! Don't change!
                  If (indeterminate_burst_reg = '1') Then
                    ipif_wr_cntl_state_ns <= IWR_BURST_INDET1;
                    bus2ip_wrburst_ns     <= '1';

                  elsif(burst_transfer_reg = '1' or
                        cacheln_burst_reg = '1') then
                    ipif_wr_cntl_state_ns <= IWR_BURST_FIXED1;
                    bus2ip_wrburst_ns     <= '1';

                  else
                    ipif_wr_cntl_state_ns <= IWR_SINGLE1;

                  End if;

               End if;


           When IWR_SINGLE1 =>


               clr_bus2ip_wrreq      <= '1'; -- new way (clear the WrReq F-F)

               if (Response_Ack_i = '1') then

                  ipif_wr_cntl_state_ns <= IWR_IDLE;
                  clear_sl_wr_busy      <= '1';
                  clear_wr_ce           <= '1';

               else

                  ipif_wr_cntl_state_ns <= IWR_SINGLE1;
                  wr_dphase_active_ns   <= '1';

               end if;



            When  IWR_BURST_INDET1 =>

               ipif_wr_cntl_state_ns <= IWR_BURST_INDET2;
               wr_dphase_active_ns   <= '1';
               wr_buf_move_data      <= sig_wr_data_ack;

               if (Response_Ack_i = '1') then   -- allow state change

                  bus2ip_wrburst_ns   <= wr_buf_burst_out;

               else                    -- don't change state

                  bus2ip_wrburst_ns   <= bus2ip_wrburst_i;

               end if;



            When  IWR_BURST_INDET2 =>

               if (Response_Ack_i = '1'and
                   last_wr_data = '1') then   -- last data beat to IPIC

                  ipif_wr_cntl_state_ns <= IWR_IDLE;
                  clear_sl_wr_busy      <= '1';
                  clear_wr_ce           <= '1';
                  clr_bus2ip_wrreq      <= '1'; -- new way (clear WrReq F-F)

               else

                  ipif_wr_cntl_state_ns <= IWR_BURST_INDET2;
                  wr_dphase_active_ns   <= '1';
                  wr_buf_move_data      <= sig_wr_data_ack;

                  clr_bus2ip_wrreq      <= Control_Ack_i and
                                           Control_AlmostDone_i;

                  if (Response_Ack_i = '1') then   -- allow state change

                     bus2ip_wrburst_ns   <= wr_buf_burst_out;

                  else                    -- don't change state

                     bus2ip_wrburst_ns   <= bus2ip_wrburst_i;

                  end if;

               End if;



           When IWR_BURST_FIXED1 =>

               if (Response_Ack_i = '1' and
                   Response_Done_i = '1') then

                  ipif_wr_cntl_state_ns <= IWR_IDLE;
                  clear_sl_wr_busy      <= '1';
                  clear_wr_ce           <= '1';
                  clr_bus2ip_wrreq      <= '1';

               else

                  ipif_wr_cntl_state_ns <= IWR_BURST_FIXED1;
                  wr_dphase_active_ns   <= '1';
                  wr_buf_move_data      <= sig_wr_data_ack;
                  clr_bus2ip_wrreq      <= Control_Ack_i and
                                           Control_done_i;

                  if (Response_Ack_i = '1') then   -- allow state change

                     bus2ip_wrburst_ns   <= not(Response_AlmostDone_i);

                  else                    -- don't change state

                     bus2ip_wrburst_ns   <= bus2ip_wrburst_i;

                  end if;

               end if;



            When others   =>

               ipif_wr_cntl_state_ns   <= IWR_IDLE;

          End case;

       end process IPIF_WR_DATA_CONTROLLER;



    -------------------------------------------------------------
    -- Synchronous Process with Sync Reset
    --
    -- Label: IPIF_WR_SM_SYNCD
    --
    -- Process Description:
    --  This process registers the outputs of the IPIF Write
    --  Data Controller State Machine.
    --
    -------------------------------------------------------------
    IPIF_WR_SM_SYNCD : process (bus_clk)
       begin
         if (Bus_Clk'event and Bus_Clk = '1') then
            if (bus_reset = '1') then

               ipif_wr_cntl_state  <= IWR_IDLE;
               bus2ip_wrburst_i    <= '0';
               wr_dphase_active    <= '0';

            else

               ipif_wr_cntl_state  <= ipif_wr_cntl_state_ns;
               bus2ip_wrburst_i    <= bus2ip_wrburst_ns    ;
               wr_dphase_active    <= wr_dphase_active_ns  ;

            end if;
         else
           null;
         end if;
       end process IPIF_WR_SM_SYNCD;


    -- Instantiate the Register for the Bus2IP_WrReq signal generation.
    -- This is needed for Terminating Bus2IP_WrReq signal
    -- when the Address & Control timing is complete but data transfer is
    -- not yet complete due to pipeline delays (Address preceeds data).
     I_WRREQ_FDRSE : FDRSE
     port map(
       Q  =>  bus2ip_wrreq_i,    -- : out std_logic;
       C  =>  Bus_Clk,           -- : in  std_logic;
       CE =>  '1',               -- : in  std_logic;
       D  =>  bus2ip_wrreq_i,    -- : in  std_logic;
       R  =>  clr_bus2ip_wrreq,  -- : in  std_logic
       S  =>  set_bus2ip_wrreq   -- : in  std_logic
     );




   ----------------------------------------------------------------------------
   -- Write Buffer misc. assignments


   wr_buf_burst_out  <=  wr_buf_data_out(1);

   wr_buf_done_out   <=  wr_buf_data_out(0);


   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: DO_WR_DATA_REG
   --
   -- Process Description:
   -- This process implements the wr data register. It registers
   -- the output of the intermediate Wr Data FIFO buffer.
   --
   -------------------------------------------------------------
   DO_WR_DATA_REG : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           if (bus_reset = '1' or clear_sl_wr_busy = '1') then

             Bus2IP_Data_i     <= (others => '0');
             last_wr_data      <= '0';

           elsif (wr_buf_move_data = '1') then

             Bus2IP_Data_i     <=  wr_buf_data_out(2 to C_PLB_DBUS_WIDTH+1);
             last_wr_data      <=  wr_buf_done_out;

           else

              null; -- Don't change state

           end if;
        else
          null;
        end if;
      end process DO_WR_DATA_REG;





    Bus2IP_Burst_i <= Bus2IP_WrBurst_i or Bus2IP_RdBurst_i;


    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: GEN_XFER_CYCLE_COUNT
    --
    -- Process Description:
    --  This process generates the data beat count required for
    --  a transaction. It uses the PLB Size and PLB BE control
    --  signals to calculate the required count value.
    --
    -------------------------------------------------------------
    GEN_XFER_CYCLE_COUNT : process (plb_size_reg,
                                    plb_be_reg)
       begin

          Case plb_size_reg Is

            When "0000" =>

               num_data_beats_minus1 <= 0;  -- 1 word xfer

            When "0001" =>

               num_data_beats_minus1 <= 1;  -- 4 word xfer (2 long words)

            When "0010" =>

               num_data_beats_minus1 <= 3;  -- 8 word xfer (4 long words)

            When "0011" =>

               num_data_beats_minus1 <= 7;  -- 16 word xfer (8 long words)

            When "1000" | "1001" | "1010" =>  -- burst transfer of bytes,
                                              -- halfwords, and words

               num_data_beats_minus1 <= (CONV_INTEGER(plb_be_reg(0 to 3)));

            When "1011"  =>  -- burst transfer of double words

               num_data_beats_minus1 <= (CONV_INTEGER(plb_be_reg(0 to 3)) *
                                              (64/C_IPIF_DBUS_WIDTH));


            When others   =>

               num_data_beats_minus1 <= 0;  -- undefined operations so assume 1 data beat

          End case;

       end process GEN_XFER_CYCLE_COUNT;




    ------------------------------------------------------------------------------
    -- PROCESS
    --
    -- Transfer counter control
    -- This process keeps track of how many data transfers into the write buffer
    -- occur during a write request.
    --
    -- This is primarily used during cache line writes and burst writes.
    ------------------------------------------------------------------------------
    WBUF_CYCLE_COUNTER : process (Bus_clk)
        Begin

          if (Bus_clk'EVENT and Bus_clk = '1') Then

             If (Bus_reset = '1') Then

                data_cycle_count <= 0;

             elsif (plb_write_cntl_state = PBWR_IDLE and
                    start_data_phase = '1') then

                data_cycle_count <= num_data_beats_minus1;

             Elsif (data_cycle_count /= 0) and
                   (sl_wrdack_ns = '1') Then

                data_cycle_count <= data_cycle_count-1;

             Else

                null; -- don't change states

             End if;

          else

             null;

          End if;

        End process WBUF_CYCLE_COUNTER;




      ------------------------------------------------------------------------------
      -- PROCESS
      --
      -- Check that the data phase is done
      -- When the data cycle counter has reached zero, signal a 'done' to the data
      -- controller state machine.
      ------------------------------------------------------------------------------
       CHECK_DATA_DONE : process (data_cycle_count,
                                  wr_buf_wren)
         Begin
            If (data_cycle_count = 2 and
                wr_buf_wren = '1') Then

                line_count_done       <= '0';
                line_count_almostdone <= '1';

             Elsif (data_cycle_count <= 1 and
                    wr_buf_wren = '1') Then

                line_count_done       <= '1';
                line_count_almostdone <= '0';

             else

                line_count_done       <= '0';
                line_count_almostdone <= '0';

            End if;
         End process CHECK_DATA_DONE;



       -------------------------------------------------------------
       -- Synchronous Process
       --
       -- Label: REG_LINE_DONE
       --
       -- Process Description:
       -- This process registers the line_count_done signal
       -- that is used during write operations.
       --
       -------------------------------------------------------------
       REG_LINE_DONE : process (bus_clk)
          begin
            if (bus_clk'event and bus_clk = '1') then
               if (bus_reset = '1') then
                 line_done_dly1 <= '0';

               elsif (plb_write_cntl_state = PBWR_BURST_FIXED or
                      plb_write_cntl_state = PBWRITE_FLUSH) then
                 line_done_dly1 <= line_count_done;

               else
                 line_done_dly1 <= '0';

               end if;
            else
              null;
            end if;
          end process REG_LINE_DONE;




    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: GEN_DATA_XFER
    --
    -- Process Description:
    -- This process generates the control signal that enables the
    -- latching of read data onto the PLB Read Data Bus during the
    -- Read Acknowledge clock cycle of the Data Transfer Phase.
    --
    -------------------------------------------------------------
    GEN_DATA_XFER : process (rd_dphase_active,
                             Response_Ack_i)
       begin

         if (rd_dphase_active = '1') then
           read_data_xfer <= Response_Ack_i;
         else
           read_data_xfer <= '0';

         end if;

       end process GEN_DATA_XFER;



     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Read Data Register
     -- This process controls the registering and output of the Slave read data
     -- onto the PLB Bus.
     ------------------------------------------------------------------------------
       READ_DATA_REGISTER : process (Bus_clk)
         Begin

            if (Bus_clk'EVENT and Bus_clk = '1') Then

               If (Bus_reset = '1') Then

                  sl_rddbus_i <= (others => '0');

               elsif (read_data_xfer = '1') Then

                  sl_rddbus_i <= MUX2SA_Data;

               else

                  sl_rddbus_i <= (others => '0');

               End if;

            else

                null;

            End if;

     End process READ_DATA_REGISTER; --





      data_request_active <= rd_dphase_active or wr_dphase_active;






       I_BURST_SUPPORT : entity plb_ipif_v1_00_f.burst_support
       generic map (
         C_MAX_DBEAT_CNT     =>    MAX_FIXED_XFER_COUNT   -- : Integer := 16;
         )
       port map(
         -- Input ports
         Bus_reset           =>  Bus_Reset,               -- : In std_logic;
         Bus_clk             =>  Bus_Clk,                 -- : In std_logic;
         RNW                 =>  plb_rnw_reg,             -- : In std_logic;
         Req_Init            =>  decode_s_h_cs,           -- : In std_logic;
         Req_Active          =>  data_request_active,     -- : In std_logic;
         Indet_Burst         =>  indeterminate_burst_reg, -- : In std_logic; -- '1' = Indeterminate burst operation
         Num_Data_Beats      =>  num_data_beats_minus1,   -- : In integer range 0 to C_MAX_DBEAT_CNT;
         Target_AddrAck      =>  MUX2SA_AddrAck,          -- : In std_logic;
         Target_DataAck      =>  data_ack,                -- : In std_logic;
         WrBuf_wen           =>  wr_buf_wren,             -- : In std_logic;

         -- Output signals
         Control_Ack         =>  Control_Ack_i,           -- : Out std_logic;
         Control_AlmostDone  =>  Control_AlmostDone_i,    -- : Out std_logic;
         Control_Done        =>  Control_Done_i,          -- : Out std_logic;
         Response_Ack        =>  Response_Ack_i,          -- : Out std_logic;
         Response_AlmostDone =>  Response_AlmostDone_i,   -- : Out std_logic;
         Response_Done       =>  Response_Done_i          -- : Out std_logic
         );





     -- Main IPIF Address counter instantiation
     I_BUS_ADDRESS_COUNTER : entity plb_ipif_v1_00_f.addr_reg_cntr_brst_flex
      Generic map (
         C_CACHLINE_ADDR_MODE => C_CACHLINE_ADDR_MODE,
         C_NUM_ADDR_BITS      => C_PLB_ABUS_WIDTH,
         C_PLB_DWIDTH         => C_PLB_DBUS_WIDTH
        )
      port map (
      -- Clock and Reset
        Bus_reset           => Bus_Reset,
        Bus_clk             => Bus_Clk,


      -- Inputs from Slave Attachment
        Single             => single_transfer,
        Cacheln            => cacheln_transfer,
        Burst              => burst_transfer,
        S_H_Qualifiers     => decode_s_h_cs,
        Xfer_done          => decode_cs_ce_clr,
        Addr_Load          => Addr_cntr_load_en,
        Addr_Cnt_en        => Control_Ack_i,
        Addr_Cnt_Size      => plb_size_reg,
        Address_In         => plb_abus_reg,
        BE_in              => plb_be_reg,

      -- BE Outputs
        BE_out             => bus2ip_be_i,

      -- IPIF & IP address bus source (AMUX output)
        Address_Out        => bus2ip_addr_i

       );





     -- Byte Steering Address counter instantiation
     I_STEER_ADDRESS_COUNTER : entity plb_ipif_v1_00_f.addr_reg_cntr_brst_flex
      Generic map (
         C_CACHLINE_ADDR_MODE => C_CACHLINE_ADDR_MODE,
         C_NUM_ADDR_BITS      => C_STEER_ADDR_SIZE,
         C_PLB_DWIDTH         => C_PLB_DBUS_WIDTH
        )
      port map (
       -- Clock and Reset
         Bus_reset           => Bus_Reset,
         Bus_clk             => Bus_Clk,


       -- Inputs from Slave Attachment
         Single             => single_transfer,
         Cacheln            => cacheln_transfer,
         Burst              => burst_transfer,
         S_H_Qualifiers     => decode_s_h_cs,
         Xfer_done          => decode_cs_ce_clr,
         Addr_Load          => Addr_cntr_load_en,
         Addr_Cnt_en        => Response_Ack_i,
         Addr_Cnt_Size      => plb_size_reg,
         Address_In         => plb_abus_reg(C_PLB_ABUS_WIDTH -
                                            C_STEER_ADDR_SIZE to
                                            C_PLB_ABUS_WIDTH-1),
         BE_in              => plb_be_reg,


       -- BE Outputs
         BE_out             => SA2Steer_BE_i,

       -- IPIF & IP address bus source (AMUX output)
         Address_Out        => SA2Steer_addr_i

        );




    -------------------------------------------------------------------------------
    --Process
    --
    -- Sample and hold the transfer qualifer signals to be output to the IPIF
    -- during the data phase of a bus transfer.
    -------------------------------------------------------------------------------
    S_AND_H_XFER_QUAL : process (Bus_clk)
       begin
          If (Bus_clk'EVENT and Bus_clk = '1') Then

             If (Bus_reset = '1' or decode_cs_ce_clr = '1') Then

                bus2ip_rnw_i            <= '0';
                bus2ip_size_i           <= (others => '0');
                Bus2IP_type_i           <= (others => '0');
                single_transfer_reg     <= '0';
                burst_transfer_reg      <= '0';
                indeterminate_burst_reg <= '0';
                cacheln_burst_reg       <= '0';

             else

                If (Addr_cntr_load_en = '1') Then

                   bus2ip_rnw_i            <=  plb_rnw_reg;
                   bus2ip_size_i           <=  plb_size_reg;
                   Bus2IP_type_i           <=  plb_type_reg;
                   single_transfer_reg     <=  single_transfer;
                   burst_transfer_reg      <=  burst_transfer;
                   indeterminate_burst_reg <=  indeterminate_burst;
                   cacheln_burst_reg       <=  cacheln_transfer;

                else

                    null;

                End if;

             End if;

          else
              null;
          End if;
       end process; -- S_AND_H_XFER_QUAL




    end generate GEN_FAST_MODE_BURSTXFER;
--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\














 --////////////////////////////////////////////////////////////////////////////
 ------------------------------------------------------------
 -- If Generate
 --
 -- Label: GEN_SLOW_MODE_BURSTXFER
 --
 -- If Generate Description:
 -- This If-Generate includes the HDL design for support of
 -- single beat and slow-mode cache line and burst transfers.
 -- Slow mode transferes require full handshake between the
 -- target and the PLB for each data beat.
 --
 ------------------------------------------------------------
 GEN_SLOW_MODE_BURSTXFER : if (SLOW_MODE_BURSTXFER) generate

    -- Type Declarations
       type PLB_DATA_CNTRL_STATES is (
                           IDLE,
                           WR_SINGLE,
                           WR_CL_BRST1,
                           WR_CL_BRST2,
                           WR_CL_BRST3,
                           WR_INDET1,
                           WR_INDET2,
                           WR_INDET3,
                           RD_SINGLE,
                           RD_CL_BRST1,
                           RD_CL_BRST2,
                           RD_INDET1,
                           RD_INDET2
                           --DATA_PIPE_FLUSH
                           );

     -- Constant Declarations
       constant WRD_ADDR_LSB     : integer   := C_IPIF_ABUS_WIDTH -
                                                log2(C_PLB_DBUS_WIDTH/8)-1;

     -- Signal Declarations
       signal data_cntl_state     : PLB_DATA_CNTRL_STATES;
       Signal data_cntl_state_ns  : PLB_DATA_CNTRL_STATES;
       signal bus2ip_wrreq_ns     : std_logic;
       signal bus2ip_rdreq_ns     : std_logic;
       signal sl_wrdack_ns        : std_logic;
       signal sl_wrcomp_ns        : std_logic;
       signal clear_sl_busy_ns    : std_logic;
       signal sl_rddack_ns        : std_logic;
       signal sl_rdcomp_ns        : std_logic;
       signal sl_rdwdaddr_ns      : std_logic_vector(0 to 3);
       signal sl_rdbterm_ns       : std_logic;
       signal sl_wrbterm_ns       : std_logic;

       Signal num_data_beats      : integer range 0 to MAX_FIXED_XFER_COUNT;
       Signal data_cycle_count    : Integer range 0 to 15;
       Signal start_rddata_phase  : std_logic;
       Signal start_wrdata_phase  : std_logic;

    begin




    ---------------------------------------------------------------------------
    -- misc assignments for non-burst support

       bus2ip_iburst_i   <= '0'; -- bursts mechanized as repeating singles on IPIC

       Bus2IP_Data_i     <=  plb_wrdbus_reg ;

       Bus2IP_Burst_i    <= '0'; -- bursts mechanized as repeating singles on IPIC

       SA2Steer_BE_i     <= bus2ip_be_i;

       SA2Steer_addr_i   <= bus2ip_addr_i(C_PLB_ABUS_WIDTH -
                                          C_STEER_ADDR_SIZE
                                          to
                                          C_PLB_ABUS_WIDTH-1);

       sl_data_ack       <= data_ack;

    ---------------------------------------------------------------------------


    ------------------------------------------------------------------------------
    -- Create the load enables and clears for the address decoder for
    -- non-burst support operation mode


      Addr_cntr_load_en <=  address_match and
                            not(sl_busy) and
                            not(sig_inhib_Addr_cntr_ld);

      decode_clr_rw_ce  <=  data_ack or
                            sig_cmd_abort;  -- added PLB abort support


      decode_cs_ce_clr  <=  clear_sl_busy_ns or
                            sig_cmd_abort;  -- added PLB abort support


      decode_s_h_cs      <=  not(sl_busy) or
                             (address_match and clear_sl_busy);

      decode_cs_clr      <=  clear_sl_busy and not(address_match);



    ------------------------------------------------------------------------------






    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Data Phase Support

      start_data_phase <=  set_sl_busy;

      start_rddata_phase <=  set_sl_busy and
                             plb_rnw_reg;



      start_wrdata_phase <= set_sl_busy and
                            not(plb_rnw_reg);


      data_ack         <=  MUX2SA_RdAck or  -- Read acknowledge
                           MUX2SA_WrAck or  -- Write Acknowledge
                           data_timeout;    -- Acknowledge Timeout

      -- Assign the PLB read word address
      rdwdaddr    <= bus2ip_addr_i(WRD_ADDR_LSB-2 to WRD_ADDR_LSB) & '0';


     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Data Controller State Machine
     -- This state machine controls the transfer of data to/from the PLB Bus
     ------------------------------------------------------------------------------
     DATA_CONTROLLER : Process (data_cntl_state,
                                start_rddata_phase,
                                start_wrdata_phase,
                                addr_cntl_state,
                                sig_cmd_abort,
                                plb_rnw_reg,
                                burst_transfer,
                                burst_transfer_reg,
                                indeterminate_burst,
                                single_transfer,
                                line_count_done,
                                line_count_almostdone,
                                data_ack,
                                rdwdaddr,
                                PLB_rdBurst,
                                PLB_wrBurst)

       begin

        -- default conditions
         data_cntl_state_ns  <= IDLE;
         bus2ip_wrreq_ns     <= '0';
         bus2ip_rdreq_ns     <= '0';
         decode_ld_rw_ce     <= '0';
         sl_wrdack_ns        <= '0';
         sl_wrcomp_ns        <= '0';
         clear_sl_busy_ns    <= '0';
         sl_rddack_ns        <= '0';
         sl_rdcomp_ns        <= '0';
         sl_rdwdaddr_ns      <= (others => '0');
         sl_rdbterm_ns       <= '0';
         sl_wrbterm_ns       <= '0';


          Case data_cntl_state  Is

            When IDLE =>

               If (start_rddata_phase = '1' and
                   sig_cmd_abort    = '0') Then

                  decode_ld_rw_ce      <= '1';
                  bus2ip_rdreq_ns      <= '1';

                  If (indeterminate_burst = '1') Then  -- indeterminate burst request
                                                       -- treat as a single read
                                                       -- Terminate on first xfer
                    data_cntl_state_ns  <= RD_INDET1;

                  Elsif (single_transfer = '0') Then  --  cacheln read or
                                                      --  fixed burst read
                    data_cntl_state_ns  <= RD_CL_BRST1;

                  else                                -- single beat read request

                    data_cntl_state_ns  <= RD_SINGLE;

                  End if;


               elsif (start_wrdata_phase = '1' and
                      sig_cmd_abort    = '0') Then


                  decode_ld_rw_ce      <= '1';
                  bus2ip_wrreq_ns      <= '1';

                  If (indeterminate_burst = '1') Then  -- indeterminate burst request
                                                       -- treat as a single read
                                                       -- Terminate on first xfer
                    data_cntl_state_ns  <= WR_INDET1;

                  Elsif (single_transfer = '0') Then  --  cacheln read or
                                                      --  fixed burst read
                    data_cntl_state_ns  <= WR_CL_BRST1;

                  else                                -- single beat read request

                    data_cntl_state_ns  <= WR_SINGLE;

                  End if;

               else

                  data_cntl_state_ns   <= IDLE;

               End if;


         --Write States

            When WR_SINGLE  =>

               if (data_ack = '1') Then

                  data_cntl_state_ns   <= IDLE;
                  sl_wrdack_ns         <= '1';
                  sl_wrcomp_ns         <= '1';
                  clear_sl_busy_ns     <= '1';

               Else

                  data_cntl_state_ns   <= WR_SINGLE;

               End if;

            When WR_CL_BRST1 =>

               If (line_count_done = '1') Then   -- WrAck and last xfer

                  data_cntl_state_ns   <= IDLE;
                  sl_wrdack_ns         <= '1';
                  sl_wrcomp_ns         <= '1';
                  clear_sl_busy_ns     <= '1';

               Elsif (line_count_almostdone = '1') Then  -- WrAck and one more xfer
                                                         -- to go
                  data_cntl_state_ns   <= WR_CL_BRST2;
                  sl_wrbterm_ns        <= burst_transfer_reg;
                  sl_wrdack_ns         <= '1';

               Elsif (data_ack = '1') Then               -- WrAck with more xfers
                                                         -- to go
                  data_cntl_state_ns   <= WR_CL_BRST2;
                  sl_wrdack_ns         <= '1';

               else                                      -- wait for WrAck

                  data_cntl_state_ns   <= WR_CL_BRST1;

               End if;


            When WR_CL_BRST2 =>  -- delay needed for PLB Wr Data input register

               data_cntl_state_ns    <= WR_CL_BRST3;


            When WR_CL_BRST3 =>        -- initiate the next Write request to the target

               data_cntl_state_ns    <= WR_CL_BRST1;
               decode_ld_rw_ce       <= '1';
               bus2ip_wrreq_ns       <= '1';



            when WR_INDET1 =>

              If (data_ack = '1'  and
                  PLB_wrBurst = '0') Then  -- indeterminate burst write completing

                  data_cntl_state_ns  <= IDLE;
                  sl_wrdack_ns        <= '1';
                  sl_wrcomp_ns        <= '1';
                  clear_sl_busy_ns    <= '1';

              Elsif (data_ack = '1') Then

                  data_cntl_state_ns  <= WR_INDET2;
                  sl_wrdack_ns        <= '1';

              else

                  data_cntl_state_ns  <= WR_INDET1;

              End if;



            when WR_INDET2 => -- delay needed for PLB Wr Data input register

               data_cntl_state_ns    <= WR_INDET3;


            when WR_INDET3 =>

               data_cntl_state_ns    <= WR_INDET1;
               decode_ld_rw_ce       <= '1';
               bus2ip_wrreq_ns       <= '1';



         -- Read States

            When RD_SINGLE =>

               if (data_ack = '1') Then

                  data_cntl_state_ns  <= IDLE;
                  sl_rddack_ns        <= '1';
                  sl_rdcomp_ns        <= '1';
                  clear_sl_busy_ns    <= '1';

               else

                  data_cntl_state_ns  <= RD_SINGLE;

               End if;


            When RD_CL_BRST1 =>

               If (line_count_done = '1') Then

                  data_cntl_state_ns  <= IDLE;
                  sl_rddack_ns        <= '1';
                  sl_rdcomp_ns        <= '1';
                  clear_sl_busy_ns    <= '1';
                  sl_rdwdaddr_ns      <= rdwdaddr;

               Elsif (line_count_almostdone = '1') Then

                  data_cntl_state_ns  <= RD_CL_BRST2;
                  sl_rddack_ns        <= '1';
                  sl_rdbterm_ns       <= burst_transfer_reg;
                  sl_rdwdaddr_ns      <= rdwdaddr;

               Elsif (data_ack = '1') Then

                  data_cntl_state_ns  <= RD_CL_BRST2;
                  sl_rddack_ns        <= '1';
                  sl_rdwdaddr_ns      <= rdwdaddr;

               else

                  data_cntl_state_ns  <= RD_CL_BRST1;

               End if;

            When RD_CL_BRST2  =>

               data_cntl_state_ns   <= RD_CL_BRST1;
               bus2ip_rdreq_ns      <= '1';
               decode_ld_rw_ce      <= '1';


            When RD_INDET1 =>

              If (data_ack = '1'  and
                  PLB_rdBurst = '0') Then  -- indeterminate burst read completing

                  data_cntl_state_ns  <= IDLE;
                  sl_rddack_ns        <= '1';
                  sl_rdcomp_ns        <= '1';
                  clear_sl_busy_ns    <= '1';

              Elsif (data_ack = '1') Then

                  data_cntl_state_ns  <= RD_INDET2;
                  sl_rddack_ns        <= '1';

              else

                  data_cntl_state_ns  <= RD_INDET1;

              End if;


            When RD_INDET2 =>

                  data_cntl_state_ns  <= RD_INDET1;
                  bus2ip_rdreq_ns     <= '1';
                  decode_ld_rw_ce     <= '1';


            When others   =>

               data_cntl_state_ns     <= IDLE;

          End case;

       end process DATA_CONTROLLER;




    -------------------------------------------------------------
    -- Synchronous Process with Sync Reset
    --
    -- Label: DATA_CONTROLLER_SYNCD
    --
    -- Process Description:
    --  This process implements the registered portion of the
    --  DATA_CONTROLLER State Machine.
    --
    -------------------------------------------------------------
    DATA_CONTROLLER_SYNCD : process (bus_clk)
       begin
         if (Bus_Clk'event and Bus_Clk = '1') then
            if (Bus_reset = '1') then

               data_cntl_state     <=  IDLE;
               bus2ip_wrreq_i      <=  '0';
               bus2ip_rdreq_i      <=  '0';
               sl_wrdack_i         <=  '0';
               sl_wrcomp_i         <=  '0';
               clear_sl_busy       <=  '0';
               sl_rddack_i         <=  '0';
               sl_rdcomp_i         <=  '0';
               sl_rdwdaddr_i       <=  (others => '0');
               sl_rdbterm_i        <=  '0';
               sl_wrbterm_i        <=  '0';

            else

               data_cntl_state     <=  data_cntl_state_ns;
               bus2ip_wrreq_i      <=  bus2ip_wrreq_ns   ;
               bus2ip_rdreq_i      <=  bus2ip_rdreq_ns   ;
               sl_wrdack_i         <=  sl_wrdack_ns      ;
               sl_wrcomp_i         <=  sl_wrcomp_ns      ;
               clear_sl_busy       <=  clear_sl_busy_ns  ;
               sl_rddack_i         <=  sl_rddack_ns      ;
               sl_rdcomp_i         <=  sl_rdcomp_ns      ;
               sl_rdwdaddr_i       <=  sl_rdwdaddr_ns    ;
               sl_rdbterm_i        <=  sl_rdbterm_ns     ;
               sl_wrbterm_i        <=  sl_wrbterm_ns     ;

            end if;
         else
           null;
         end if;
       end process DATA_CONTROLLER_SYNCD;





    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: GEN_DATA_XFER
    --
    -- Process Description:
    -- This process generates the control signal that enables the
    -- latching of read data onto the PLB Read Data Bus during the
    -- Read Acknowledge clock cycle of the Data Transfer Phase.
    --
    -------------------------------------------------------------
    GEN_DATA_XFER : process (data_cntl_state)
       begin

         if (data_cntl_state = RD_SINGLE or
             data_cntl_state = RD_CL_BRST1 or
             data_cntl_state = RD_INDET1) then
           read_data_xfer <= '1';
         else
           read_data_xfer <= '0';

         end if;

       end process GEN_DATA_XFER;



     ------------------------------------------------------------------------------
     -- PROCESS
     --
     -- Read Data Register
     -- This process controls the registering and output of the Slave read data
     -- onto the PLB Bus.
     ------------------------------------------------------------------------------
       READ_DATA_REGISTER : process (Bus_clk)
         Begin

            if (Bus_clk'EVENT and Bus_clk = '1') Then

               If (Bus_reset = '1') Then

                  sl_rddbus_i <= (others => '0');

               elsif (read_data_xfer = '1' and
                      MUX2SA_RdAck = '1') Then

                  sl_rddbus_i <= MUX2SA_Data;

               else

                  sl_rddbus_i <= (others => '0');

               End if;

            else

                null;

            End if;

         End process; -- READ_DATA_REGISTER






    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: GEN_XFER_CYCLE_COUNT
    --
    -- Process Description:
    --  This process generates the data beat count required for
    --  a transaction. It uses the PLB Size and PLB BE control
    --  signals to calculate the required count value.
    --
    -------------------------------------------------------------
    GEN_XFER_CYCLE_COUNT : process (plb_size_reg,
                                    plb_be_reg)
       begin

          Case plb_size_reg Is

            When "0000" =>

               num_data_beats <= 0;  -- 1 word xfer

            When "0001" =>

               num_data_beats <= 1;  -- 4 word xfer (2 long words)

            When "0010" =>

               num_data_beats <= 3;  -- 8 word xfer (4 long words)

            When "0011" =>

               num_data_beats <= 7;  -- 16 word xfer (8 long words)

            When "1000" | "1001" | "1010" =>  -- burst transfer of bytes,
                                              -- halfwords, and words

               num_data_beats <= (CONV_INTEGER(plb_be_reg(0 to 3)));

            When "1011"  =>  -- burst transfer of double words

               num_data_beats <= (CONV_INTEGER(plb_be_reg(0 to 3)) *
                                              (64/C_IPIF_DBUS_WIDTH));

            When others   =>

               num_data_beats <= 0;  -- undefined operations

          End case;

       end process GEN_XFER_CYCLE_COUNT;




    -------------------------------------------------------------
    -- Synchronous Process
    --
    -- Label: CYCLE_COUNTER
    --
    -- Process Description:
    -- This process keeps track of how many data beats to perform
    -- for a transfer. This is primarily used during cache line
    -- and burst operations.
    --
    -------------------------------------------------------------
    CYCLE_COUNTER : process (Bus_clk)
        Begin

          if (Bus_clk'EVENT and Bus_clk = '1') Then

             If (Bus_reset = '1') Then

                data_cycle_count <= 0;

             elsif (data_cntl_state = IDLE and
                    start_data_phase = '1') then

                data_cycle_count <= num_data_beats;

             elsif (data_cntl_state /= IDLE) and
                   (data_cycle_count = 0) and
                   (data_ack = '1') Then

                data_cycle_count <= 0;

             Elsif (data_cntl_state /= IDLE) and
                   (data_ack = '1') Then

                data_cycle_count <= data_cycle_count-1;

             Else

                null; -- don't change states

             End if;

          else

             null;

          End if;

        End process CYCLE_COUNTER;


    -------------------------------------------------------------
    -- Combinational Process
    --
    -- Label: CHECK_DATA_DONE
    --
    -- Process Description:
    -- When the data cycle counter has reached zero, signal a
    -- 'done' to the data controller state machine.
    --
    -------------------------------------------------------------
       CHECK_DATA_DONE : process (data_cycle_count, data_ack)
         Begin
            If (data_cycle_count = 1 and
                data_ack = '1')Then

                line_count_done       <= '0';
                line_count_almostdone <= '1';

             Elsif (data_cycle_count = 0 and
                    data_ack = '1') Then

                line_count_done       <= '1';
                line_count_almostdone <= '0';

             else

                line_count_done       <= '0';
                line_count_almostdone <= '0';

            End if;
         End process CHECK_DATA_DONE;




     -- Main IPIF Address counter instantiation
     I_ADDRESS_COUNTER : entity plb_ipif_v1_00_f.addr_reg_cntr_brst_flex
      Generic map (
         C_CACHLINE_ADDR_MODE => C_CACHLINE_ADDR_MODE,
         C_NUM_ADDR_BITS      => C_PLB_ABUS_WIDTH,
         C_PLB_DWIDTH         => C_PLB_DBUS_WIDTH
        )
      port map (
      -- Clock and Reset
        Bus_reset           => Bus_Reset,
        Bus_clk             => Bus_Clk,


      -- Inputs from Slave Attachment
        Single             => single_transfer,
        Cacheln            => cacheln_transfer,
        Burst              => burst_transfer,
        S_H_Qualifiers     => decode_s_h_cs,
        Xfer_done          => decode_cs_ce_clr,
        Addr_Load          => Addr_cntr_load_en,
        Addr_Cnt_en        => data_ack,
        Addr_Cnt_Size      => plb_size_reg,
        Address_In         => plb_abus_reg,
        BE_in              => plb_be_reg,

      -- BE Outputs
        BE_out             => bus2ip_be_i,

      -- IPIF & IP address bus source (AMUX output)
        Address_Out        => bus2ip_addr_i

       );




    -------------------------------------------------------------------------------
    --Process
    --
    -- Sample and hold the transfer qualifer signals to be output to the IPIF
    -- during the data phase of a bus transfer.
    -------------------------------------------------------------------------------
    S_AND_H_XFER_QUAL : process (Bus_clk)
       begin
          If (Bus_clk'EVENT and Bus_clk = '1') Then

             If (Bus_reset = '1' or
                 decode_cs_ce_clr = '1') Then

                bus2ip_rnw_i            <= '0';
                bus2ip_size_i           <= (others => '0');
                Bus2IP_type_i           <= (others => '0');
                burst_transfer_reg      <= '0';
                indeterminate_burst_reg <= '0';

             else

                If (Addr_cntr_load_en = '1') Then

                   bus2ip_rnw_i            <=  plb_rnw_reg;
                   bus2ip_size_i           <=  plb_size_reg;
                   Bus2IP_type_i           <=  plb_type_reg;
                   burst_transfer_reg      <=  burst_transfer;
                   indeterminate_burst_reg <=  indeterminate_burst;


                else

                    null;

                End if;

             End if;

          else
              null;
          End if;
       end process; -- S_AND_H_XFER_QUAL







    end generate GEN_SLOW_MODE_BURSTXFER;
--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\




end implementation;
