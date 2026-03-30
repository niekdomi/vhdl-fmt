-------------------------------------------------------------------------------
--$Id: plb2opb_bridge.vhd,v 1.11 2006/06/13 20:32:23 mlovejoy Exp $
------------------------------------------------------------------------------
-- PLB to OPB Bridge Out - Top Level Module
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
-- Filename:       plb2opb_bridge.vhd
-- Version:        v1.01a
-- Description:
--   This module is the top level file for the PLB Slave to OPB Master
--   Bridge.
--
-- VHDL-Standard:   VHDL'93
--
-- Design Notes:
--   - PLB Slave interface supports the 64 bit PLB protocol.
--   - OPB Master interface supports only the 32 Bit OPB Byte Enable transfer
--     protocol
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
-- @BEGIN_CHANGELOG EDK_Gm_SP2
--04/15/04
--  Rev'd device to v1_01_a
--  Modified operation to make bridge operation (previously based on IBM
--  architecture) compatible with Xilinx OPB IPIF architecture. Specifically,
--  delayed addrack on reads until data is received by bridge. Wait is asserted
--  until xferack crosses time-domain boundaries. Wait is released when OPB_retry
--  is asserted and rearbitrate is asserted. 
--  A new signal, PLB2OPB_rearb, was required to signal plb arbiter that the
--  plb2opb bridge asserted the rearbitration signal.
--  This bridge is compatible with only plb_v34_v1_02_a.
-- @END_CHANGELOG
-- @BEGIN_CHANGELOG EDK_H_SP2
--05/03/05
--  Added qualifier to assert bgi_trans_abort_i only on read operations.
--  This bug can cause permanent retry condition when an opb master is
--  attempting to write to an opb master/slave ipif device that will retry
--  due to an attempt to read from a plb slave. The change was made in
--  plb2opb_bridge_opb_if.vhd. bgi_trans_abort_i should not have been asserted
--  on write operations.
-- @END_CHANGELOG
-- @BEGIN_CHANGELOG EDK_I_SP1
--09/13/05
--  Corrected qualifier to assert bgi_trans_abort_i only on read operations.
--  The wrong file was checked in EDK_H_SP2. A quick fix for a customer problem
--  was checked in by mistake and was not a robust implementation to assert
--  bgi_trans_abort_i only on read operations. It would only stop trans_abort_i
--  under certain write conditions conditions. This update has undergone more
--  testing.
-- @END_CHANGELOG
-- @BEGIN_CHANGELOG EDK_Im_SP1
--05/22/06
--  Added qualifier to PLB rearbitrate following a PLB abort with OPB retry.
--  Without the qualifier, a PLB read from OPB could return data to PLB
--  without AddrAck in the sequence when a delayed PLB Abort of an OPB read
--  occurs followed by another PLB read of OPB and an OPB Retry is asserted
--  on the aborted read that was not stopped on the OPB because the abort
--  occurred too late on the PLB. For data to returned on the PLB without an
--  AddrAck, precise timing of the OPB retry relative to the second PLB read
--  from OPB is required. Furthermore, this is only a problem with the
--  processor is fetching instructions from the OPB and asserts PLB abort on
--  a read operation [CR<232028>].
--
--  Pipelined internal signal (PLB_RNW_and_PAValid) to shorten path of
--  AddrAck for improved system timing. This register breaks the path from
--  both PAValid and PLB_RNW with AddrAck output. The PLB_RNW path experienced
--  an increased delay in V4 parts when ppc was accessing the plb2opb bridge
--  due to increased delay in gasket output signal routing. However, this
--  change will benefit all systems (both V2p and V4) with faster build times
--  to meet timing. External signal timing of ports signals has not changed.
--  [CR<231724>]. In testing this change, a bug was found and fixed in
--  plb2opb_bridge_plb_if.vhd where an addrack could occur if the plb_abus
--  was driven with valid address but PAValid was not asserted.
-- @END_CHANGELOG
-------------------------------------------------------------------------------
-- Author:
-- History:
--     KD       5/22/01             -- EA 2 Release
--     ALS      11/01/01            -- VHDL conversion
--     ALS      01/15 - 17/02
-- ^^^^^^
--  Modified signal names and generics to be more consistent with Bus naming
--  standards and the OPB2PLB bridge. Made changes to start implementing the
--  design spec. Added plb2opb_bridge_interrupt module. Added software reset
--  bit to the BGO_CTRL_REG. This will be an output from plb2opb_bridge_besr
--  which will be OR'd with BGO_Rst in this top-level file. The output of this
--  OR will be the reset signal connected to all modules.
-- ^^^^^^
--      ALS     01/31/02
-- ^^^^^^
--  Added additional address ranges.
-- ~~~~~~
--      ALS     03/04/02
-- ^^^^^^
--  Added C_NUM_ADDR_RNG parameter.
-- ~~~~~~
--      ALS     03/22/02
-- ^^^^^^
--  Added C_PLB_MID_WIDTH parameter and added PLB_Rst input even though its
--  not used just to provide consistent PLB slave interface. Added synthesis
--  attributes to allow high fan-out on the PLB_Clk, OPB_Clk, and OPB_Rst
--  signals.
-- ~~~~~~
--      ALS     07/09/02            -- Version 1.00b
-- ^^^^^^
--  C_INCLUDE_BGI_TRANSABORT generic is no longer used.
-- ~~~~~~
--      ALS     08/26/03
-- ^^^^^^
--  C_CLK_ASYNC is no longer used but remains in the generic list to maintain
--  compatibility with systems that may have instantiated the bridge with this
--  generic. A constant, CLK_ASYNC, will be set to 1 so that the fifo buffer 
--  between the PLB and OPB sides is always present. This constant will be used
--  in place of the C_CLK_ASYNC generic.
--  C_HIGH_SPEED is no longer used but remains in the generic list to maintain
--  compatibility with systems that may have instantiated the bridge with this
--  generic. A constant, HIGH_SPEED, will be set to 1 so that  Dual Port LUT ram
--  and flip-flops are used instead of BRAM.
-- ~~~~~~
--      MLL     01/09/04            -- Version 1.01a
-- ^^^^^^
--  Modify operation to make bridge operation (previously based on IBM 
--  architecture) compatible with Xilinx OPB IPIF architecture. Specifically,
--  delayed addrack on reads until data is received by bridge. Wait is asserted
--  until xferack crosses time-domain boundaries. Wait is released when OPB_retry
--  is asserted and rearbitrate is asserted. 
--  NOTE: 1 LUT was required in PAValid input to block while bridge recovers from
--  OPB_retry on read or PLB abort. A register can be inserted if higher speed is
--  required.
--  NOTE: 1 LUT was required in addrAck output to allow early addrAck on write,
--  and MUX in addrAck on read after data received.
-- ~~~~~~
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics/parameters:                    "C_*"
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
 
library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
 
library plb2opb_bridge_v1_01_a;
use plb2opb_bridge_v1_01_a.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;
use proc_common_v1_00_b.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NO_PLB_BURST             -- PLB burst/cacheline transactions converted to singles
--      C_DCR_INTFCE               -- Include DCR interface
--      C_FAMILY                   -- Target FGPA family
--      C_NUM_ADDR_RNG             -- Number of bridge address ranges
--      C_RNG(0:3)_BASEADDR        -- Base addresses for the address ranges
--      C_RNG(0:3)_HIGHADDR        -- High addresses for the address ranges
--      C_PLB_AWIDTH               -- PLB address bus width
--      C_PLB_DWIDTH               -- PLB data bus width
--      C_PLB_NUM_MASTERS          -- Number of PLB masters
--      C_PLB_MID_WIDTH            -- Number of bits to encode number of PLB masters
--      C_OPB_AWIDTH               -- OPB address bus width
--      C_OPB_DWIDTH               -- OPB data bus width
--      C_DCR_BASEADDR             -- DCR base address
--      C_DCR_HIGHADDR             -- DCR high address
--      C_DCR_AWIDTH               -- DCR address bus width
--      C_DCR_DWIDTH               -- DCR data bus width
--      C_IRQ_ACTIVE               -- Active level of interrupt
--      C_BGI_TRANSABORT_CNT       -- Number of clocks before asserting BGI_TRANSABORT
--------  Following generics are not user modifiable ------------------------
--      C_CLK_ASYNC                
--      C_HIGH_SPEED            
--      C_INCLUDE_BGI_TRANSABORT
--
-- Definition of Ports:
--      PLB_Rst                     -- PLB bus reset                   
--      PLB_Clk                     -- PLB clock       
--      OPB_Rst                     -- OPB bus reset        
--      OPB_Clk                     -- OPB clock
--      Bus_Error_Det               -- OPB bus error detect
--      BGI_Trans_Abort             -- signals the OPB2PLB bridge to release transaction
--      PLB_abort                   -- PLB master abort
--      PLB_ABus                    -- PLB address bus
--      PLB_BE                      -- PLB byte enables
--      PLB_busLock                 -- PLB bus lock
--      PLB_compress                -- PLB compress
--      PLB_guarded                 -- PLB guarded
--      PLB_lockErr                 -- PLB lock error
--      PLB_masterID                -- PLB master ID
--      PLB_MSize                   -- PLB master size
--      PLB_ordered                 -- PLB ordered transaction
--      PLB_PAValid                 -- PLB primary address valid
--      PLB_RNW                     -- PLB read not write
--      PLB_size                    -- PLB size
--      PLB_type                    -- PLB type
--      BGO_addrAck                 -- Bridge PLB address acknowledge
--      BGO_MBusy                   -- Bridge PLB master busy
--      BGO_MErr                    -- Bridge PLB master error
--      BGO_rearbitrate             -- Bridge PLB rearbitrate
--      BGO_SSize                   -- Bridge PLB slave size
--      BGO_wait                    -- Bridge PLB wait
--      PLB_rdPrim                  -- PLB indication to promote pipelined read transaction
--      PLB_SAValid                 -- PLB secondary address valid
--      PLB_wrPrim                  -- PLB indication to promote pipelined write transaction
--      PLB_wrBurst                 -- PLB write burst
--      PLB_wrDBus                  -- PLB write data bus
--      BGO_wrBTerm                 -- Bridge PLB write burst terminate
--      BGO_wrComp                  -- Bridge PLB write complete
--      BGO_wrDAck                  -- Bridge PLB write data acknowledge
--      PLB_rdBurst                 -- PLB read burst
--      BGO_rdBTerm                 -- Bridge PLB read burst terminate
--      BGO_rdComp                  -- Bridge PLB read complete
--      BGO_rdDAck                  -- Bridge PLB read data acknowledge
--      BGO_rdDBus                  -- Bridge PLB read data bus
--      BGO_rdWdAddr                -- Bridge PLB read word addres
--      OPB_DBus                    -- OPB data bus
--      OPB_errAck                  -- OPB error acknowledge
--      OPB_MnGrant                 -- OPB master grant
--      OPB_retry                   -- OPB retry
--      OPB_timeout                 -- OPB timeout
--      OPB_xferAck                 -- OPB xferack
--      BGO_ABus                    -- Bridge OPB address bus
--      BGO_BE                      -- Bridge OPB byte enables
--      BGO_busLock                 -- Bridge OPB bus lock
--      BGO_DBus                    -- Bridge OPB data bus
--      BGO_request                 -- Bridge OPB request
--      BGO_RNW                     -- Bridge OPB read not write
--      BGO_select                  -- Bridge OPB select
--      BGO_seqAddr                 -- Bridge OPB sequential address
--      DCR_ABus                    -- DCR address bus
--      DCR_DBus                    -- DCR data bus
--      DCR_Read                    -- DCR read
--      DCR_Write                   -- DCR write
--      BGO_dcrAck                  -- Bridge DCR acknowledge
--      BGO_dcrDBus                 -- Bridge DCR output data bus
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity section
-------------------------------------------------------------------------------
entity plb2opb_bridge is
  generic (
        C_NO_PLB_BURST      : integer := 0;
        C_DCR_INTFCE        : integer := 1;

        C_FAMILY            : string  := "virtex2p";
        
        C_NUM_ADDR_RNG      : integer   := 1;
                
        C_RNG0_BASEADDR     : std_logic_vector := X"00000000";
        C_RNG0_HIGHADDR     : std_logic_vector := X"0003FFFF"; 

        C_RNG1_BASEADDR     : std_logic_vector := X"00000000";
        C_RNG1_HIGHADDR     : std_logic_vector := X"00000000"; 

        C_RNG2_BASEADDR     : std_logic_vector := X"00000000";
        C_RNG2_HIGHADDR     : std_logic_vector := X"00000000"; 

        C_RNG3_BASEADDR     : std_logic_vector := X"00000000";
        C_RNG3_HIGHADDR     : std_logic_vector := X"00000000"; 
        
        
        C_PLB_AWIDTH        : integer := 32;
        C_PLB_DWIDTH        : integer := 64;
        
        C_PLB_NUM_MASTERS   : integer := 8;
        C_PLB_MID_WIDTH     : integer := 3;


        C_OPB_AWIDTH        : integer := 32;
        C_OPB_DWIDTH        : integer := 32;
        
        C_DCR_BASEADDR      : std_logic_vector := "0000000000";
        C_DCR_HIGHADDR      : std_logic_vector := "0000000111";
        C_DCR_AWIDTH        : integer := 10;
        C_DCR_DWIDTH        : integer := 32;
        
        C_IRQ_ACTIVE        : std_logic := '1';
        
        C_BGI_TRANSABORT_CNT   : integer   := 31;

        -- the following generics are not user modifiable
        C_CLK_ASYNC             : integer := 1; 
        C_HIGH_SPEED            : integer := 1; 
        C_INCLUDE_BGI_TRANSABORT: integer := 1  -- no longer used
        );

  port (
        PLB_Rst         : in std_logic;         -- unused input
        PLB_Clk         : in std_logic;
        OPB_Rst         : in std_logic;
        OPB_Clk         : in std_logic;
        Bus_Error_Det   : out std_logic;
        BGI_Trans_Abort : out std_logic;
        PLB_abort       : in std_logic;
        PLB_ABus        : in std_logic_vector (0 to C_PLB_AWIDTH-1);
        PLB_BE          : in std_logic_vector (0 to C_PLB_DWIDTH/8-1);
        PLB_busLock     : in std_logic;
        PLB_compress    : in std_logic;
        PLB_guarded     : in std_logic;
        PLB_lockErr     : in std_logic;
        PLB_masterID    : in std_logic_vector (0 to C_PLB_MID_WIDTH-1);
        PLB_MSize       : in std_logic_vector (0 to 1);
        PLB_ordered     : in std_logic;
        PLB_PAValid     : in std_logic;
        PLB_RNW         : in std_logic;
        PLB_size        : in std_logic_vector (0 to 3);
        PLB_type        : in std_logic_vector (0 to 2);
        BGO_addrAck     : out std_logic;
        BGO_MBusy       : out std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
        BGO_MErr        : out std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
        BGO_rearbitrate : out std_logic;
        BGO_SSize       : out std_logic_vector (0 to 1);
        BGO_wait        : out std_logic;
        PLB_rdPrim      : in std_logic;
        PLB_SAValid     : in std_logic;
        PLB_wrPrim      : in std_logic;
        PLB_wrBurst     : in std_logic;
        PLB_wrDBus      : in std_logic_vector (0 to C_PLB_DWIDTH-1);
        BGO_wrBTerm     : out std_logic;
        BGO_wrComp      : out std_logic;
        BGO_wrDAck      : out std_logic;
        PLB_rdBurst     : in std_logic;
        BGO_rdBTerm     : out std_logic;
        BGO_rdComp      : out std_logic;
        BGO_rdDAck      : out std_logic;
        BGO_rdDBus      : out std_logic_vector (0 to C_PLB_DWIDTH-1);
        BGO_rdWdAddr    : out std_logic_vector (0 to 3) ;
        OPB_DBus        : in std_logic_vector (0 to C_OPB_DWIDTH-1);
        OPB_errAck      : in std_logic;
        OPB_MnGrant     : in std_logic;
        OPB_retry       : in std_logic;
        OPB_timeout     : in std_logic;
        OPB_xferAck     : in std_logic;
        BGO_ABus        : out std_logic_vector (0 to C_OPB_AWIDTH-1);
        BGO_BE          : out std_logic_vector (0 to C_OPB_DWIDTH/8-1) ;
        BGO_busLock     : out std_logic;
        BGO_DBus        : out std_logic_vector (0 to C_OPB_DWIDTH-1);
        BGO_request     : out std_logic;
        BGO_RNW         : out std_logic;
        BGO_select      : out std_logic;
        BGO_seqAddr     : out std_logic;
        DCR_ABus        : in std_logic_vector (0 to C_DCR_AWIDTH-1);
        DCR_DBus        : in std_logic_vector (0 to C_DCR_DWIDTH-1);
        DCR_Read        : in std_logic;
        DCR_Write       : in std_logic;
        BGO_dcrAck      : out std_logic;
        BGO_dcrDBus     : out std_logic_vector (0 to C_DCR_DWIDTH-1);
        --Fix to make compatible with IPIF architecture
        PLB2OPB_rearb   : out std_logic
        );
        
    -- fan-out attributes for Synplicity
    attribute syn_maxfan                  : integer;
    attribute syn_maxfan   of PLB_Clk     : signal is 10000;
    attribute syn_maxfan   of OPB_Clk     : signal is 10000;
    attribute syn_maxfan   of OPB_Rst     : signal is 10000;
    --fan-out attributes for XST
    attribute MAX_FANOUT                  : string;
    attribute MAX_FANOUT   of PLB_Clk     : signal is "10000";
    attribute MAX_FANOUT   of OPB_Clk     : signal is "10000";
    attribute MAX_FANOUT   of OPB_Rst     : signal is "10000";

end plb2opb_bridge;
  
-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------
architecture plb2opb_bridge of plb2opb_bridge is

-------------------------------------------------------------------------------
--  Constant Declaration
-------------------------------------------------------------------------------
-- define the following constantd to be used in place of the C_CLK_ASYNC and
-- C_HIGH_SPEED generics Set this so that the FIFO buffer between the PLB and 
-- OPB busses is always instantiated and is implemented using Dual port RAMs
constant CLK_ASYNC          : integer := 1;  
constant HIGH_SPEED         : integer := 1;

constant BGI_TRANSABORT_CNT_WIDTH : integer := max2(1,log2(C_BGI_TRANSABORT_CNT));

constant RCV_CTRL_BITS      : integer := 2; -- error and last word
constant RCV_RDWDADDR_BITS  : integer := 4; -- PLB rdwd addr bits
constant XFER_CTRL_BITS     : integer := 4; -- RNW, Buslock, Seqaddr, last word
constant RCV_DATA_WIDTH     : integer := C_OPB_DWIDTH +
                                         RCV_RDWDADDR_BITS +       
                                         RCV_CTRL_BITS;
constant XFER_DATA_WIDTH    : integer := C_OPB_DWIDTH +
                                         C_OPB_AWIDTH +
                                         C_OPB_DWIDTH/8 +
                                         XFER_CTRL_BITS;                                        
constant XFER_RNW           : integer := C_OPB_DWIDTH +
                                         C_OPB_AWIDTH +
                                         C_OPB_DWIDTH/8;

-------------------------------------------------------------------------------
--  Signal Declaration
-------------------------------------------------------------------------------
signal err_ack_det          : std_logic ;
signal err_addr             : std_logic_vector(0 to C_OPB_AWIDTH-1 );
signal err_byte_enable      : std_logic_vector(0 to C_OPB_DWIDTH/8-1 );
signal err_rd_wr_n          : std_logic ;
signal lock_err             : std_logic ;
signal master_id_decode     : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
signal intr_en              : std_logic;
signal opb_hold_buslock     : std_logic ;
signal opb_rcv_data         : std_logic_vector(0 to RCV_DATA_WIDTH-1);
signal opb_rcv_data_strobe  : std_logic ;
signal opb_xfer_abort_ack   : std_logic ;
signal opb_xfer_abort_flag  : std_logic ;
signal opb_xfer_rd_addr     : std_logic_vector(0 to 3 );
signal dout_XFER_RNW        : std_logic ;
signal opb_xfer_rd_data     : std_logic_vector(0 to XFER_DATA_WIDTH-1);
--Fix to make compatible with IPIF architecture
signal opb_xfer_rd_data_rst1_int: std_logic ;
signal opb_xfer_rd_data_rst1 : std_logic ;
signal opb_xfer_rd_data_rst2 : std_logic ;
signal opb_xfer_rd_data_rst3 : std_logic ;
signal opb_xfer_rd_en       : std_logic ;
signal opb_xfer_start_ack   : std_logic ;
signal opb_xfer_start_flag  : std_logic ;
signal plb_hold_buslock     : std_logic ;
signal plb_rcv_data         : std_logic_vector(0 to RCV_DATA_WIDTH-1);
signal plb_rcv_data_strobe  : std_logic ;
signal plb_xfer_abort_ack   : std_logic ;
signal plb_xfer_abort_flag  : std_logic ;
signal plb_xfer_data        : std_logic_vector(0 to XFER_DATA_WIDTH-1);
signal plb_xfer_start_ack   : std_logic ;
signal plb_xfer_start_flag  : std_logic ;
signal plb_xfer_strobe      : std_logic ;
signal rst                  : std_logic;
signal sw_rst               : std_logic;
signal timeout_det          : std_logic ;
--Fix to make compatible with IPIF architecture
signal BGO_RNW_int          : std_logic;
signal BGO_select_int       : std_logic;
signal BGO_select_1dly      : std_logic;
signal BGO_select_negedge   : std_logic;
signal Wait_on_Rd           : std_logic;
signal Wait_on_Rd_2dly      : std_logic;
signal Read_inprog          : std_logic;
signal Read_inprog_1dly     : std_logic;
signal Read_inprog_negedge  : std_logic;
signal Read_inprog_negedge_regd: std_logic;
signal Read_inprog_negedge_regd_OPBside: std_logic;
signal Read_inprog_negedge_regd_synch1: std_logic;
signal Read_inprog_negedge_regd_OPBside_1dly: std_logic;
signal OPBside_reset_Read_inprog_negedge_regd: std_logic;
signal PLB_SAValid_int      : std_logic;
signal PLB_PAValid_int      : std_logic;
signal PLB_PAValid_1dly     : std_logic;
signal PLB_PAValid_neg_edge : std_logic;
signal PLB_rdBurst_int      : std_logic;
signal BGO_rdDBus_int       : std_logic_vector(0 to C_PLB_DWIDTH-1);
signal BGO_rdDBus_int_1dly  : std_logic_vector(0 to C_PLB_DWIDTH-1);
signal BGO_rdDBus_int_2dly  : std_logic_vector(0 to C_PLB_DWIDTH-1);
signal BGO_rdWdAddr_int     : std_logic_vector (0 to 3) ;
signal BGO_rdWdAddr_1dly    : std_logic_vector (0 to 3) ;
signal BGO_rdWdAddr_2dly    : std_logic_vector (0 to 3) ;
signal BGO_rdBTerm_int      : std_logic;
signal BGO_rdBTerm_int_1dly : std_logic;
signal BGO_rdBTerm_int_2dly : std_logic;
signal BGO_rdComp_int       : std_logic;
signal BGO_rdComp_int_1dly  : std_logic;
signal BGO_rdComp_int_2dly  : std_logic;
signal BGO_rdDAck_int       : std_logic;
signal BGO_rdDAck_int_1dly  : std_logic;
signal BGO_rdDAck_int_2dly  : std_logic;
signal BGO_addrAck_int      : std_logic;
signal BGO_addrAck_dlydonRd : std_logic;
signal PLB_RNW_and_PAValid  : std_logic;
signal PLB_RNW_and_PAValid_regd: std_logic;
signal BGO_rearbitrate_int  : std_logic;
signal BGO_wait_int         : std_logic;
signal PLB_size_int         : std_logic_vector (0 to 3);
signal BGO_MBusy_int        : std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
signal BGO_MBusy_int_1dly   : std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
signal BGO_MBusy_int_2dly   : std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
signal BGO_MErr_int         : std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
signal BGO_MErr_int_1dly    : std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
signal BGO_MErr_int_2dly    : std_logic_vector (0 to C_PLB_NUM_MASTERS-1);
signal OPB_retry_onRd       : std_logic;
signal OPB_retry_onRd_CE    : std_logic;
signal Block_OPB_retry_onRd : std_logic;
signal Block_OPB_retry_onRd_CE: std_logic;
signal OPB_retry_onRd_regd  : std_logic;
signal OPB_retry_onRd_regd_synch1: std_logic;
signal Hold_Busy_til_Rearb_onOPBRetry: std_logic;
signal OPB_retry_onRd_PLBside: std_logic;
signal PLBside_reset_OPB_retry_onRd: std_logic;
signal OPB_retry_onRd_PLBside_1dly: std_logic;
signal BGO_SSize_int        : std_logic_vector (0 to 1);
signal OPB_timeout_onRd     : std_logic;
signal OPB_timeout_onRd_regd: std_logic;
signal OPB_timeout_onRd_regd_synch1: std_logic;
signal OPB_timeout_onRd_PLBside: std_logic;
signal Block_on_OPB_tout_onRd : std_logic;
signal PLBside_reset_OPB_timeout_onRd: std_logic;
signal OPB_timeout_onRd_PLBside_1dly: std_logic;
signal Block_on_Term_Rd_after_tout: std_logic;
signal Block_on_Term_Rd_after_tout_EN: std_logic;
signal Block_on_Term_Rd_after_tout_CE: std_logic;
signal PLB_abort_int        : std_logic;
signal PLB_abort_onRd       : std_logic;
signal PLB_abort_onRd_regd  : std_logic;
signal PLB_abort_regd_clear : std_logic;
signal PLB_abort_onRd_regd_synch1: std_logic;
signal PLB_abort_onRd_OPBside: std_logic;
signal PLB_abort_onRd_OPBside_1dly: std_logic;
signal Block_output_on_PLBabort: std_logic;
signal Block_output_on_PLBabort_OPBside: std_logic;
signal Block_output_on_PLBabort_regd: std_logic;
signal OPB_rst_on_PLB_abort : std_logic;
 
--  Component Declarations
-------------------------------------------------------------------------------
component plb2opb_bridge_plb_if
  generic (
        C_PLB_NUM_MASTERS       : integer := 16;
        C_PLB_MID_WIDTH         : integer := 4;
        C_PLB_AWIDTH            : integer := 32;
        C_PLB_DWIDTH            : integer := 64;
        C_OPB_AWIDTH            : integer := 32;
        C_OPB_DWIDTH            : integer := 32;
        C_NUM_ADDR_RNG          : integer := 1;
        C_RNG0_BASEADDR         : std_logic_vector;
        C_RNG0_HIGHADDR         : std_logic_vector; 
        C_RNG1_BASEADDR         : std_logic_vector;
        C_RNG1_HIGHADDR         : std_logic_vector; 
        C_RNG2_BASEADDR         : std_logic_vector;
        C_RNG2_HIGHADDR         : std_logic_vector; 
        C_RNG3_BASEADDR         : std_logic_vector;
        C_RNG3_HIGHADDR         : std_logic_vector; 
        C_RCV_DATA_WIDTH        : integer := 38;
        C_XFER_DATA_WIDTH       : integer := 72;
        C_NO_PLB_BURST          : integer := 0
        );
  port (
        Clk                 : in std_logic;
        Rst                 : in std_logic;
        PLB_abort           : in std_logic;
        PLB_ABus            : in std_logic_vector (0 to C_PLB_AWIDTH-1);
        PLB_BE              : in std_logic_vector (0 to C_PLB_DWIDTH/8 -1);
        PLB_busLock         : in std_logic;
        PLB_compress        : in std_logic;
        PLB_guarded         : in std_logic;
        PLB_lockErr         : in std_logic;
        PLB_masterID        : in std_logic_vector (0 to C_PLB_MID_WIDTH-1);
        PLB_MSize           : in std_logic_vector (0 to 1);
        PLB_ordered         : in std_logic;
        PLB_PAValid         : in std_logic;
        PLB_RNW             : in std_logic;
        PLB_size            : in std_logic_vector (0 to 3);
        PLB_type            : in std_logic_vector (0 to 2);
        BGO_addrAck         : out std_logic;
        BGO_MBusy           : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        BGO_MErr            : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        BGO_rearbitrate     : out std_logic;
        BGO_SSize           : out std_logic_vector (0 to 1);
        BGO_wait            : out std_logic;
        PLB_rdPrim          : in std_logic;
        PLB_SAValid         : in std_logic;
        PLB_wrPrim          : in std_logic;
        PLB_wrBurst         : in std_logic;
        PLB_wrDBus          : in std_logic_vector (0 to C_PLB_DWIDTH-1);
        BGO_wrBTerm         : out std_logic ;
        BGO_wrComp          : out std_logic;
        BGO_wrDAck          : out std_logic;
        PLB_rdBurst         : in std_logic;
        BGO_rdBTerm         : out std_logic;
        BGO_rdComp          : out std_logic;
        BGO_rdDAck          : out std_logic;
        BGO_rdDBus          : out std_logic_vector(0 to C_PLB_DWIDTH-1);
        BGO_rdWdAddr        : out std_logic_vector(0 to 3 );
        PLB_xfer_abort_ack  : in std_logic;
        PLB_xfer_start_ack  : in std_logic;
        PLB_hold_buslock    : out std_logic;
        PLB_xfer_abort_flag : out std_logic;
        PLB_xfer_data       : out std_logic_vector (0 to C_XFER_DATA_WIDTH-1);
        PLB_xfer_start_flag : out std_logic ;
        PLB_xfer_strobe     : out std_logic ;
        PLB_rcv_data        : in std_logic_vector (0 to C_RCV_DATA_WIDTH-1);
        PLB_rcv_strobe      : in std_logic;
        Lock_err            : out std_logic;
        Master_id_decode    : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
            --Fix to make compatible with IPIF architecture
        Block_BGO_rearbitrate: in std_logic
        );
end component plb2opb_bridge_plb_if;

component plb2opb_bridge_xfer_if
  generic ( C_CLK_ASYNC         : integer   := 0;
            C_HIGH_SPEED        : integer   := 1;
            C_FAMILY            : string := "virtex2p";
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
        OPB_hold_buslock    : out std_logic;
        OPB_xfer_abort_flag : out std_logic;
        OPB_xfer_rd_data    : out std_logic_vector (0 to C_XFER_DATA_WIDTH-1);
        dout_XFER_RNW       : out std_logic;
        OPB_xfer_start_flag : out std_logic
        );
end component plb2opb_bridge_xfer_if;

component plb2opb_bridge_rcv_data_if
  generic (C_CLK_ASYNC       : integer := 0;
           C_RCV_DATA_WIDTH  : integer := 38);
  port (
        PLB_Clk         : in std_logic;
        OPB_Clk         : in std_logic;
        Rst             : in std_logic;
        OPB_rcv_data    : in std_logic_vector (0 to C_RCV_DATA_WIDTH-1);
        OPB_rcv_strobe  : in std_logic;
        PLB_rcv_data    : out std_logic_vector(0 to C_RCV_DATA_WIDTH-1);
        PLB_rcv_strobe  : out std_logic
        );
end component plb2opb_bridge_rcv_data_if;

component plb2opb_bridge_opb_if
  generic ( C_OPB_DWIDTH                : integer := 32;
            C_OPB_AWIDTH                : integer := 32;
            C_RCV_DATA_WIDTH            : integer := 38;
            C_XFER_DATA_WIDTH           : integer := 72;
            C_BGI_TRANSABORT_CNT        : integer := 8;
            C_BGI_TRANSABORT_CNT_WIDTH  : integer := 3
          );
  port (
        OPB_Clk                 : in std_logic;
        Rst                     : in std_logic;
        BGI_Trans_Abort         : out std_logic;
        OPB_DBus                : in std_logic_vector(0 to C_OPB_DWIDTH-1);
        OPB_errAck              : in std_logic;
        OPB_MnGrant             : in std_logic;
        OPB_retry               : in std_logic;
        OPB_timeout             : in std_logic;
        OPB_xferAck             : in std_logic;
        BGO_ABus                : out std_logic_vector(0 to C_OPB_AWIDTH-1);
        BGO_BE                  : out std_logic_vector(0 to C_OPB_DWIDTH/8 -1);
        BGO_busLock             : out std_logic;
        BGO_DBus                : out std_logic_vector(0 to C_OPB_DWIDTH-1);
        BGO_request             : out std_logic;
        BGO_RNW                 : out std_logic;
        BGO_select              : out std_logic;
        BGO_seqAddr             : out std_logic;
        OPB_hold_buslock        : in std_logic;
        dout_XFER_RNW           : in std_logic;
        OPB_xfer_abort_flag     : in std_logic;
        OPB_xfer_rd_data        : in std_logic_vector (0 to C_XFER_DATA_WIDTH-1);
        OPB_xfer_start_flag     : in std_logic;
        OPB_xfer_abort_ack      : out std_logic;
        OPB_xfer_rd_addr        : out std_logic_vector (0 to 3);
        OPB_xfer_rd_data_rst1   : out std_logic;
        OPB_xfer_rd_data_rst2   : out std_logic;
        OPB_xfer_rd_data_rst3   : out std_logic;
        OPB_xfer_rd_en          : out std_logic;
        OPB_xfer_start_ack      : out std_logic;
        OPB_rcv_data            : out std_logic_vector (0 to C_RCV_DATA_WIDTH-1);
        OPB_rcv_strobe          : out std_logic;
        Err_ack_det             : out std_logic;
        Err_addr                : out std_logic_vector(0 to C_OPB_AWIDTH-1 );
        Err_byte_enable         : out std_logic_vector(0 to C_OPB_DWIDTH/8-1 );
        Err_rd_wr_n             : out std_logic;
        Timeout_det             : out std_logic
        );
end component plb2opb_bridge_opb_if;

component plb2opb_bridge_besr
    generic( C_DCR_BASEADDR     : std_logic_vector;
             C_DCR_HIGHADDR     : std_logic_vector;
             C_DCR_AWIDTH       : integer := 10;
             C_DCR_DWIDTH       : integer := 32;
             C_PLB_NUM_MASTERS  : integer := 16;
             C_OPB_AWIDTH       : integer := 32;
             C_OPB_DWIDTH       : integer := 32
            );
  port (
        Clk             : in std_logic;
        Rst             : in std_logic;
        Err_ack_det     : in std_logic;
        Err_addr        : in std_logic_vector(0 to C_OPB_AWIDTH-1);
        Err_byte_enable : in std_logic_vector (0 to C_OPB_DWIDTH/8-1); -- what to use here
        Err_rd_wr_n     : in std_logic;
        Lock_err        : in std_logic;
        Master_id_decode : in std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        Timeout_det     : in std_logic;
        DCR_ABus        : in std_logic_vector(0 to C_DCR_AWIDTH-1);
        DCR_DBus        : in std_logic_vector(0 to C_DCR_DWIDTH-1);
        DCR_Read        : in std_logic;
        DCR_Write       : in std_logic;
        BGO_dcrAck      : out std_logic;
        BGO_dcrDBus     : out std_logic_vector(0 to C_DCR_DWIDTH-1);
        Intr_en         : out std_logic;
        SW_rst          : out std_logic
        );
end component plb2opb_bridge_besr;

component plb2opb_interrupt
    generic( C_IRQ_ACTIVE   : std_logic := '1'
            );
  port (
        Clk             : in std_logic;
        Rst             : in std_logic;
        Err_ack_det     : in std_logic;
        Timeout_det     : in std_logic;
        Intr_en         : in std_logic;
        Bus_Error_Det   : out std_logic
        );
end component plb2opb_interrupt;  

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin
-------------------------------------------------------------------------------
-- Create reset signal from sw_rst and OPB_Rst
-------------------------------------------------------------------------------
--Fix to make compatible with IPIF architecture
--rst <= sw_rst or OPB_Rst;
rst <= sw_rst or OPB_Rst or OPB_retry_onRd or OPB_rst_on_PLB_abort;

-------------------------------------------------------------------------------
--  PLB Interface Module Declaration. Decode PLB transaction and queue up
--     data transfer commands for the OPB to perform
-------------------------------------------------------------------------------

PLB_IF_I: plb2opb_bridge_plb_if
  generic map (
        C_PLB_NUM_MASTERS       => C_PLB_NUM_MASTERS,
        C_PLB_MID_WIDTH         => C_PLB_MID_WIDTH,
        C_PLB_AWIDTH            => C_PLB_AWIDTH,
        C_PLB_DWIDTH            => C_PLB_DWIDTH,
        C_OPB_AWIDTH            => C_OPB_AWIDTH,
        C_OPB_DWIDTH            => C_OPB_DWIDTH,
        C_NUM_ADDR_RNG          => C_NUM_ADDR_RNG,
        C_RNG0_BASEADDR         => C_RNG0_BASEADDR,
        C_RNG0_HIGHADDR         => C_RNG0_HIGHADDR,
        C_RNG1_BASEADDR         => C_RNG1_BASEADDR,
        C_RNG1_HIGHADDR         => C_RNG1_HIGHADDR,
        C_RNG2_BASEADDR         => C_RNG2_BASEADDR,
        C_RNG2_HIGHADDR         => C_RNG2_HIGHADDR,
        C_RNG3_BASEADDR         => C_RNG3_BASEADDR,
        C_RNG3_HIGHADDR         => C_RNG3_HIGHADDR,
        C_RCV_DATA_WIDTH        => RCV_DATA_WIDTH,
        C_XFER_DATA_WIDTH       => XFER_DATA_WIDTH,
        C_NO_PLB_BURST          => C_NO_PLB_BURST
        )
  port map (
            Clk                 => PLB_Clk,                            
            Rst                 => rst,                          
            --  PLB Signals
            --Fix to make compatible with IPIF architecture
            --PLB_abort           => PLB_abort,          --  I
            PLB_abort           => PLB_abort_int,      --  I
            PLB_ABus            => PLB_ABus,           --  I [0:31]
            PLB_BE              => PLB_BE,             --  I [0:7]
            PLB_busLock         => PLB_busLock,        --  I
            PLB_compress        => PLB_compress,       --  I
            PLB_guarded         => PLB_guarded,        --  I
            PLB_lockErr         => PLB_lockErr,        --  I
            PLB_masterID        => PLB_masterID,       --  I [0:3]
            PLB_MSize           => PLB_MSize,          --  I [0:1]
            PLB_ordered         => PLB_ordered,        --  I
            --Fix to make compatible with IPIF architecture
            --PLB_PAValid         => PLB_PAValid,        --  I
            PLB_PAValid         => PLB_PAValid_int,    --  I
            --PLB_rdBurst         => PLB_rdBurst,        --  I
            PLB_rdBurst         => PLB_rdBurst_int,    --  I
            PLB_rdPrim          => PLB_rdPrim,         --  I
            PLB_RNW             => PLB_RNW,            --  I
            --Fix to make compatible with IPIF architecture
            --PLB_SAValid         => PLB_SAValid,        --  I
            PLB_SAValid         => PLB_SAValid_int,      --  I
            --PLB_size            => PLB_size,           --  I [0:3]
            PLB_size            => PLB_size_int,           --  I [0:3]
            PLB_type            => PLB_type,           --  I [0:2]
            PLB_wrBurst         => PLB_wrBurst,        --  I
            PLB_wrDBus          => PLB_wrDBus,         --  I [0:63]
            PLB_wrPrim          => PLB_wrPrim,         --  I
            --Fix to make compatible with IPIF architecture
            --BGO_addrAck         => BGO_addrAck,        --  O
            BGO_addrAck         => BGO_addrAck_int,        --  O
            --BGO_MBusy           => BGO_MBusy,          --  O [0:15]
            BGO_MBusy           => BGO_MBusy_int,        --  O [0:15]
            --BGO_MErr            => BGO_MErr,           --  O [0:15]
            BGO_MErr            => BGO_MErr_int,         --  O [0:15]
            --Fix to make compatible with IPIF architecture
            --BGO_rdBTerm         => BGO_rdBTerm,        --  O
            BGO_rdBTerm         => BGO_rdBTerm_int,     --  O
            --BGO_rdComp          => BGO_rdComp,         --  O
            BGO_rdComp          => BGO_rdComp_int,      --  O
            --BGO_rdDAck          => BGO_rdDAck,         --  O
            BGO_rdDAck          => BGO_rdDAck_int,      --  O
            --BGO_rdDBus          => BGO_rdDBus,         --  O [0:63]
            BGO_rdDBus          => BGO_rdDBus_int,     --  O [0:63]
            --Fix to make compatible with IPIF architecture
            --BGO_rdWdAddr        => BGO_rdWdAddr,       --  O [0:3]
            BGO_rdWdAddr        => BGO_rdWdAddr_int,     --  O [0:3]
            --BGO_rearbitrate     => BGO_rearbitrate,    --  O
            BGO_rearbitrate     => BGO_rearbitrate_int,--  O
            --Fix to make compatible with IPIF architecture
            --BGO_SSize           => BGO_SSize,          --  O [0:1]
            BGO_SSize           => BGO_SSize_int,      --  O [0:1]
            --BGO_wait            => BGO_wait,           --  O
            BGO_wait            => BGO_wait_int,       --  O
            BGO_wrBTerm         => BGO_wrBTerm,        --  O
            BGO_wrComp          => BGO_wrComp,         --  O
            BGO_wrDAck          => BGO_wrDAck,         --  O
            --  PLB Transfer Information Going to OPB            
            PLB_hold_buslock    => plb_hold_buslock,   --  O
            PLB_xfer_abort_ack  => plb_xfer_abort_ack, --  I
            PLB_xfer_abort_flag => plb_xfer_abort_flag,--  O
            PLB_xfer_data       => plb_xfer_data,      --  O [0:71]
            PLB_xfer_start_ack  => plb_xfer_start_ack, --  I
            PLB_xfer_start_flag => plb_xfer_start_flag,--  O
            PLB_xfer_strobe     => plb_xfer_strobe,    --  O
            --  PLB Read Data Coming Back
            PLB_rcv_data        => plb_rcv_data,       --  I [0:37]
            PLB_rcv_strobe      => plb_rcv_data_strobe,--  I
            --  Error Detection Signals
            Lock_err            => lock_err,           --  O
            Master_id_decode    => master_id_decode,   --  O [0:15] 
            Block_BGO_rearbitrate=> Wait_on_Rd_2dly);
                                                         
-------------------------------------------------------------------------------
--  Transfer Interface Module Declaration. Decouples PLB and OPB logic
--    from each other and sycnhronizes data passing between PLB and OPB.
--    This module allows the PLB and OPB to run in different clock domains
-------------------------------------------------------------------------------
XFER_IF_I: plb2opb_bridge_xfer_if
  generic map ( C_CLK_ASYNC         => CLK_ASYNC,
                C_HIGH_SPEED        => HIGH_SPEED,
                C_FAMILY            => C_FAMILY,
                C_XFER_RNW          => XFER_RNW,
                C_XFER_DATA_WIDTH   => XFER_DATA_WIDTH)
  port map (
            --  Global Signal
            Rst                 => rst,                 --  I
            --  PLB Interface Side
            PLB_Clk             => PLB_Clk,                 --  I
            PLB_hold_buslock    => plb_hold_buslock,        --  I
            PLB_xfer_abort_ack  => plb_xfer_abort_ack,      --  O
            PLB_xfer_abort_flag => plb_xfer_abort_flag,     --  I
            PLB_xfer_data       => plb_xfer_data,           --  I [0:71]
            PLB_xfer_start_ack  => plb_xfer_start_ack,      --  O
            PLB_xfer_start_flag => plb_xfer_start_flag,     --  I
            PLB_xfer_strobe     => plb_xfer_strobe,         --  I
            --  OPB Interface Side
            OPB_Clk             => OPB_Clk,                 --  I
            OPB_hold_buslock    => opb_hold_buslock,        --  O
            OPB_xfer_abort_ack  => opb_xfer_abort_ack,      --  I
            OPB_xfer_abort_flag => opb_xfer_abort_flag,     --  O
            OPB_xfer_rd_addr    => opb_xfer_rd_addr,        --  I [0:3]
            OPB_xfer_rd_data    => opb_xfer_rd_data,        --  O [0:71]
            --Fix to make compatible with IPIF architecture
            --OPB_xfer_rd_data_rst1 => opb_xfer_rd_data_rst1, --  I
            OPB_xfer_rd_data_rst1 => opb_xfer_rd_data_rst1_int, --  I
            OPB_xfer_rd_data_rst2 => opb_xfer_rd_data_rst2, --  I
            OPB_xfer_rd_data_rst3 => opb_xfer_rd_data_rst3, --  I
            OPB_xfer_rd_en      => opb_xfer_rd_en,          --  I
            OPB_xfer_start_ack  => opb_xfer_start_ack,      --  I
            dout_XFER_RNW => dout_XFER_RNW,                 --  O
            OPB_xfer_start_flag => opb_xfer_start_flag);    --  O

-------------------------------------------------------------------------------
--  Receive Data Interface Module Declaration. Passes OPB read data back to
--    PLB and sycnhronizes the data across different clock domains
-------------------------------------------------------------------------------
RCV_DATA_IF_I: plb2opb_bridge_rcv_data_if
  generic map (C_CLK_ASYNC      => CLK_ASYNC,
               C_RCV_DATA_WIDTH => RCV_DATA_WIDTH)
  port map (
            PLB_Clk         => PLB_Clk,              --  I
            OPB_Clk         => OPB_Clk,              --  I
            Rst             => rst,              --  I
            OPB_rcv_data    => opb_rcv_data,         --  I 
            OPB_rcv_strobe  => opb_rcv_data_strobe,  --  I
            PLB_rcv_data    => plb_rcv_data,         --  O 
            PLB_rcv_strobe  => plb_rcv_data_strobe); --  O

-------------------------------------------------------------------------------
--  OPB Interface Module Declaration. Performs OPB transactions that were
--    decoded by PLB interface. Flas any errors that were detected
-------------------------------------------------------------------------------
OPB_IF_I: plb2opb_bridge_opb_if
  generic map ( C_OPB_DWIDTH                => C_OPB_DWIDTH,
                C_OPB_AWIDTH                => C_OPB_AWIDTH,
                C_RCV_DATA_WIDTH            => RCV_DATA_WIDTH,
                C_XFER_DATA_WIDTH           => XFER_DATA_WIDTH,
                C_BGI_TRANSABORT_CNT        => C_BGI_TRANSABORT_CNT,
                C_BGI_TRANSABORT_CNT_WIDTH  => BGI_TRANSABORT_CNT_WIDTH
              )
  port map (
            OPB_Clk             => OPB_Clk,                 --  I
            Rst                 => rst,                 --  I
            BGI_Trans_Abort     => BGI_Trans_Abort,         --  O
            --  OPB Master Interface
            BGO_ABus            => BGO_ABus,                --  O 
            BGO_BE              => BGO_BE,                  --  O 
            BGO_busLock         => BGO_busLock,             --  O
            BGO_DBus            => BGO_DBus,                --  O
            BGO_request         => BGO_request,             --  O
            --Fix to make compatible with IPIF architecture
            --BGO_RNW             => BGO_RNW,                 --  O
            BGO_RNW             => BGO_RNW_int,             --  O
            --BGO_select          => BGO_select,              --  O
            BGO_select          => BGO_select_int,          --  O
            BGO_seqAddr         => BGO_seqAddr,             --  O
            OPB_DBus            => OPB_DBus,                --  I 
            OPB_errAck          => OPB_errAck,              --  I
            OPB_MnGrant         => OPB_MnGrant,             --  I
            OPB_retry           => OPB_retry,               --  I
            OPB_timeout         => OPB_timeout,             --  I
            OPB_xferAck         => OPB_xferAck,             --  I
            --  OPB Transfer Information from the PLB Interface
            OPB_hold_buslock    => opb_hold_buslock,        --  I
            OPB_xfer_abort_ack  => opb_xfer_abort_ack,      --  O
            dout_XFER_RNW       => dout_XFER_RNW,           --  I
            OPB_xfer_abort_flag => opb_xfer_abort_flag,     --  I
            OPB_xfer_rd_addr    => opb_xfer_rd_addr,        --  O 
            OPB_xfer_rd_data    => opb_xfer_rd_data,        --  I 
            OPB_xfer_rd_data_rst1 => opb_xfer_rd_data_rst1, --  O,
            OPB_xfer_rd_data_rst2 => opb_xfer_rd_data_rst2, --  O,
            OPB_xfer_rd_data_rst3 => opb_xfer_rd_data_rst3, --  O,
            OPB_xfer_rd_en      => opb_xfer_rd_en,          --  O
            OPB_xfer_start_ack  => opb_xfer_start_ack,      --  O
            OPB_xfer_start_flag => opb_xfer_start_flag,     --  I
            --  Receive Data Sent Back from OPB
            OPB_rcv_data        => opb_rcv_data,            --  O 
            OPB_rcv_strobe      => opb_rcv_data_strobe,     --  O
            --  Error Detection Signals
            Err_ack_det         => err_ack_det,             --  O
            Err_addr            => err_addr,                --  O 
            Err_byte_enable     => err_byte_enable,         --  O 
            Err_rd_wr_n         => err_rd_wr_n,             --  0
            Timeout_det         => timeout_det);            --  O

-------------------------------------------------------------------------------
--  Bus Error Status Register Module Declaration. Load error information into
--    status registers and provide DCR interface so CPU can access the
--    error status information.
--  This logic is only included if the parameter C_DCR_INTRFCE = '1'
-------------------------------------------------------------------------------
INCLUDE_DCR_GEN: if C_DCR_INTFCE = 1 generate
    BEAR_BESR_I: plb2opb_bridge_besr
      generic map(  C_DCR_BASEADDR     =>  C_DCR_BASEADDR,               
                    C_DCR_HIGHADDR     =>  C_DCR_HIGHADDR,
                    C_DCR_AWIDTH        =>  C_DCR_AWIDTH,               
                    C_DCR_DWIDTH        =>  C_DCR_DWIDTH,               
                    C_PLB_NUM_MASTERS   =>  C_PLB_NUM_MASTERS,               
                    C_OPB_AWIDTH        =>  C_OPB_AWIDTH,
                    C_OPB_DWIDTH        =>  C_OPB_DWIDTH
                )
      port map (
                Clk                 => OPB_Clk,         --  I
                Rst                 => rst,             --  I
                --  Error detection signals
                Err_ack_det         => err_ack_det,     --  I
                Err_addr            => err_addr,        --  I 
                Err_byte_enable     => err_byte_enable, --  I 
                Err_rd_wr_n         => err_rd_wr_n,     --  I
                Lock_err            => lock_err,        --  I
                Master_id_decode    => master_id_decode,--  I 
                Timeout_det         => timeout_det,     --  I
                --  DCR Slave Interface
                DCR_ABus            => DCR_ABus,        --  I 
                DCR_DBus            => DCR_DBus,        --  I 
                DCR_Read            => DCR_Read,        --  I
                DCR_Write           => DCR_Write,       --  I
                BGO_dcrAck          => BGO_dcrAck,      --  O
                BGO_dcrDBus         => BGO_dcrDBus,     --  O 
                Intr_en             => intr_en,         --  O
                SW_rst              => sw_rst           --  O
                );      --  I
end generate INCLUDE_DCR_GEN;

-------------------------------------------------------------------------------
-- Assign DCR associated outputs to default values if DCR is not included
-------------------------------------------------------------------------------
NO_DCR_GEN: if C_DCR_INTFCE = 0 generate
    BGO_dcrAck      <= '0';
    BGO_dcrDBus     <= (others => '0');
    intr_en         <= '1';     -- leave interrupts enabled
    sw_rst          <= '0';
end generate NO_DCR_GEN;

-------------------------------------------------------------------------------
--  Bridge Interrupt Module Declaration. Provides an edge-type interrupt when
--  bus error has been detected if interrupts are enabled. Active interrupt 
--  state is parameterizable.
-------------------------------------------------------------------------------
BUSERR_INTR_I: plb2opb_interrupt 
    generic map ( C_IRQ_ACTIVE   => C_IRQ_ACTIVE)
    port map (
        Clk             => OPB_Clk,
        Rst             => Rst,
        Err_ack_det     => err_ack_det,
        Timeout_det     => timeout_det,
        Intr_en         => intr_en,
        Bus_Error_Det   => Bus_Error_Det
        );

--********************************************************************
--Fix to make compatible with IPIF architecture
--Pipeline signals to PLB read bus
Delay_1dly_ack_bterm_comp_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or Block_output_on_PLBabort = '1') then
         BGO_rdBTerm_int_1dly <= '0';
         BGO_rdComp_int_1dly <= '0';
         BGO_rdDAck_int_1dly <= '0';
      else
         BGO_rdBTerm_int_1dly <= BGO_rdBTerm_int;
         BGO_rdComp_int_1dly <= BGO_rdComp_int;
         BGO_rdDAck_int_1dly <= BGO_rdDAck_int;
      end if;
   end if;
end process Delay_1dly_ack_bterm_comp_PROCESS;

Delay_1dly_busy_Merr_PROCESS: process(PLB_Clk)
--Must clear when writes are complete
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or Block_output_on_PLBabort = '1') then
         BGO_MBusy_int_1dly <= (others => '0');
         BGO_MErr_int_1dly <= (others => '0');
      elsif(Read_inprog = '1') then
         BGO_MBusy_int_1dly <= BGO_MBusy_int;
         BGO_MErr_int_1dly <= BGO_MErr_int;
      end if;
   end if;
end process Delay_1dly_busy_Merr_PROCESS;

Delay_2dly_ack_bterm_comp_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or Block_output_on_PLBabort = '1') then
         BGO_rdBTerm_int_2dly <= '0';
         BGO_rdComp_int_2dly <= '0';
         BGO_rdDAck_int_2dly <= '0';
      else
         BGO_rdBTerm_int_2dly <= BGO_rdBTerm_int_1dly;
         BGO_rdComp_int_2dly <= BGO_rdComp_int_1dly;
         BGO_rdDAck_int_2dly <= BGO_rdDAck_int_1dly;
      end if;
   end if;
end process Delay_2dly_ack_bterm_comp_PROCESS;

Delay_2dly_busy_Merr_PROCESS: process(PLB_Clk)
--Must clear when writes are complete
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or Block_output_on_PLBabort = '1' or
         OPB_retry_onRd_PLBside = '1') then
         --OPB_retry_onRd_PLBside is rearb signal on plb-side
         --Clears when Hold_Busy inhibits
         BGO_MBusy_int_2dly <= (others => '0');
         BGO_MErr_int_2dly <= (others => '0');
      elsif(Read_inprog = '1'and
            Hold_Busy_til_Rearb_onOPBRetry = '0') then
         BGO_MBusy_int_2dly <= BGO_MBusy_int_1dly;
         BGO_MErr_int_2dly <= BGO_MErr_int_1dly;
      end if;
   end if;
end process Delay_2dly_busy_Merr_PROCESS;

Hold_Busy_til_Rearb_onOPBRetry_PROCESS: process(PLB_Clk)
--Must Hold Busy on retry since rst of bridge occurs
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or OPB_retry_onRd_PLBside = '1') then
         --OPB_retry_onRd_PLBside is rearb signal on plb-side
         Hold_Busy_til_Rearb_onOPBRetry <= '0';
      elsif(OPB_retry_onRd = '1') then
         --OPB_retry can be multiple PLB clocks
         Hold_Busy_til_Rearb_onOPBRetry <= '1';
      end if;
   end if;
end process Hold_Busy_til_Rearb_onOPBRetry_PROCESS;

BGO_rdBTerm <= BGO_rdBTerm_int_2dly;
BGO_rdComp <= BGO_rdComp_int_2dly;
BGO_rdDAck <= BGO_rdDAck_int_2dly;

--Select MBusy to be pipelined on read only
Set_BGO_MBusyErr_PROCESS: process(Read_inprog,
                               BGO_MBusy_int_2dly, BGO_MBusy_int,
                               BGO_MErr_int_2dly, BGO_MErr_int)
begin
   if(Read_inprog = '1') then
      BGO_MBusy <= BGO_MBusy_int_2dly;
      BGO_MErr <= BGO_MErr_int_2dly;
   else
      BGO_MBusy <= BGO_MBusy_int;
      BGO_MErr <= BGO_MErr_int;
   end if;
end process Set_BGO_MBusyErr_PROCESS;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Pipeline data and address to PLB read bus and clear on last dack
Delay_1dly_data_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or Block_output_on_PLBabort = '1' or
         BGO_rdComp_int_2dly = '1') then
         BGO_rdDBus_int_1dly <= (others => '0');
         BGO_rdWdAddr_1dly <= (others => '0');
      else
         BGO_rdDBus_int_1dly <= BGO_rdDBus_int;
         BGO_rdWdAddr_1dly <= BGO_rdWdAddr_int;
      end if;
   end if;
end process Delay_1dly_data_PROCESS;

Delay_2dly_data_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1'or BGO_rdComp_int_2dly = '1' or
         Block_output_on_PLBabort = '1' or
         BGO_rdComp_int_2dly = '1') then
         BGO_rdDBus_int_2dly <= (others => '0');
         BGO_rdWdAddr_2dly <= (others => '0');
      elsif(BGO_rdDAck_int_1dly = '1') then
         BGO_rdDBus_int_2dly <= BGO_rdDBus_int_1dly;
         BGO_rdWdAddr_2dly <= BGO_rdWdAddr_1dly;
      end if;
   end if;
end process Delay_2dly_data_PROCESS;

BGO_rdDBus <= BGO_rdDBus_int_2dly;
BGO_rdWdAddr <= BGO_rdWdAddr_2dly;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Generate PLB_RNW_and_PAValid

I_PLB_RNW_and_PAValid: LUT2
   generic map(
      INIT => X"8"
      )
   port map(
      O => PLB_RNW_and_PAValid,
      I0 => PLB_RNW,
      I1 => PLB_PAValid
      );

PLB_RNW_and_PAValid_regd_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or BGO_addrAck_dlydonRd = '1' or
         OPB_retry_onRd_PLBside = '1' or
         PLB_abort = '1') then
         PLB_RNW_and_PAValid_regd <= '0';
      else
         PLB_RNW_and_PAValid_regd <= PLB_RNW_and_PAValid;
      end if;
   end if;
end process PLB_RNW_and_PAValid_regd_PROCESS;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Generate addrAck on read operations and block when a timeout has
--occurred on read
I_BGO_addrAck: LUT4
   generic map(
      INIT => X"08F0"
      )
   port map(
      O => BGO_addrAck_dlydonRd,
      I0 => BGO_rdDAck_int,
      I1 => Wait_on_Rd,
      I2 => BGO_addrAck_int,
      I3 => PLB_RNW_and_PAValid_regd
      );

BGO_addrAck <= BGO_addrAck_dlydonRd;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Generate Wait signal on read operation

Wait_on_Rd_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or BGO_rdDAck_int = '1' or
         OPB_retry_onRd_PLBside = '1' or
         PLB_abort = '1') then
         Wait_on_Rd <= '0';
         --OPB_rst_on_PLB_abort can be muliple clocks in PLB-side
      elsif(PLB_RNW_and_PAValid = '1' and BGO_addrAck_int = '1' and
            PLB_abort = '0') then
         Wait_on_Rd <= '1';
      end if;
   end if;
end process Wait_on_Rd_PROCESS;

Wait_on_Rd_2dly_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or BGO_rdDAck_int_2dly = '1' or
         OPB_retry_onRd_PLBside = '1' or
         PLB_abort = '1') then
         Wait_on_Rd_2dly <= '0';
      elsif(PLB_RNW_and_PAValid = '1' and BGO_addrAck_int = '1') then
         Wait_on_Rd_2dly <= '1';
      end if;
   end if;
end process Wait_on_Rd_2dly_PROCESS;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Assert wait normally (_int) or by Wait_on_Rd

BGO_wait <= BGO_wait_int or Wait_on_Rd;

--********************************************************************
--Generate Read_inprogress flag; reset 
Read_inprog_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or OPB_retry_onRd_PLBside = '1' or
        BGO_rdComp_int_2dly = '1' or
         OPB_rst_on_PLB_abort = '1') then
         --OPB_rst_on_PLB_abort can be multiple PLB clocks
         Read_inprog <= '0';
      elsif(PLB_RNW_and_PAValid = '1' and BGO_addrAck_int = '1' and
            PLB_abort = '0') then
         Read_inprog <= '1';
      end if;
   end if;
end process Read_inprog_PROCESS;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Assert PLB_rdBurst_int with addrAck_int (i.e. Wait_on_Rd) as
--normally occurred before Wait_on_Rd
PLB_size_int <= PLB_size;
PLB_rdBurst_int <= PLB_rdBurst or (Wait_on_Rd and PLB_size_int(0));

--********************************************************************
--Fix to make compatible with IPIF architecture
--Generate OPB_retry_onRd

BGO_RNW <= BGO_RNW_int;
OPB_retry_onRd <= OPB_retry and BGO_RNW_int and
                  not(Block_OPB_retry_onRd);

--Block_OPB_retry_onRd in opb time-domain
--Read_inprog is in plb time-domain but overlaps 
Block_OPB_retry_onRd_CE <= Read_inprog and BGO_select_int and
                           BGO_RNW_int and OPB_xferAck;

   I_Block_OPB_retry_onRd: FDRE
   port map(
      Q => Block_OPB_retry_onRd,
      C => OPB_Clk,
      CE => Block_OPB_retry_onRd_CE,
      D => '1',
      R => Read_inprog_negedge_regd_OPBside
      );

--Generate Read_inprog_negedge
   I_Read_inprog_regd: FDRSE
   port map(
      Q => Read_inprog_1dly,
      C => PLB_Clk,
      CE => '1',
      D => Read_inprog,
      R => rst,
      S => '0'
      );

   I_Read_inprog_negedge: LUT2
      generic map(
      INIT => X"4"
      )
   port map(
      O => Read_inprog_negedge,
      I0 => Read_inprog,
      I1 => Read_inprog_1dly
      );

--Register Read_inprog_negedge (always 1 OPB clock) and asynchronously clear
I_Read_inprog_negedge_Reg: FDCPE
   port map(
      Q => Read_inprog_negedge_regd,
      D => '1',
      C => PLB_Clk,
      CE => Read_inprog_negedge,
      CLR => OPBside_reset_Read_inprog_negedge_regd,
      PRE => '0'
      );

--Synchronize Read_inprog_negedge to OPB-side and synchronously reset
   I_Read_inprog_negedge_regd_OPBside_synch1: FDRE
   port map(
      Q => Read_inprog_negedge_regd_synch1,
      C => OPB_Clk,
      CE => '1',
      D => Read_inprog_negedge_regd,
      R => OPBside_reset_Read_inprog_negedge_regd
      );

   I_Read_inprog_negedge_regd_OPBside_synch2: FDRE
   port map(
      Q => Read_inprog_negedge_regd_OPBside,
      C => OPB_Clk,
      CE => '1',
      D => Read_inprog_negedge_regd_synch1,
      R => OPBside_reset_Read_inprog_negedge_regd
      );

--Delay for strobe on Positive edge on OPB-side
I_Read_inprog_negedge_OPBside_1dly: FDRSE
   port map(
      Q => Read_inprog_negedge_regd_OPBside_1dly,
      C => OPB_Clk,
      CE => '1',
      D => Read_inprog_negedge_regd_OPBside,
      R => OPBside_reset_Read_inprog_negedge_regd,
      S => '0'
      );

--Generate OPBside_reset_Read_inprog_negedge_regd
I_OPBside_reset_Read_inprog_negedge_regd: LUT3
      generic map(
      INIT => X"F2"
      )
   port map(
      O => OPBside_reset_Read_inprog_negedge_regd,
      I0 => Read_inprog_negedge_regd_OPBside,
      I1 => Read_inprog_negedge_regd_OPBside_1dly,
      I2 => OPB_Rst
      );

--******************************************************************************
--Register OPB_retry (always 1 OPB clock) and asynchronously clear
I_A_side_Reg: FDCPE
   port map(
      Q => OPB_retry_onRd_regd,
      D => '1',
      C => OPB_Clk,
      CE => OPB_retry_onRd_CE,
      CLR => PLBside_reset_OPB_retry_onRd,
      PRE => '0'
      );

OPB_retry_onRd_CE <= OPB_retry_onRd and not(Block_output_on_PLBabort);

--Synchronize OPB_retry to PLB-side and synchronously reset
   I_OPB_retry_onRd_synch1: FDRE
   port map(
      Q => OPB_retry_onRd_regd_synch1,
      C => PLB_Clk,
      CE => '1',
      D => OPB_retry_onRd_regd,
      R => PLBside_reset_OPB_retry_onRd
      );

   I_OPB_retry_onRd_synch2: FDRE
   port map(
      Q => OPB_retry_onRd_PLBside,
      C => PLB_Clk,
      CE => '1',
      D => OPB_retry_onRd_regd_synch1,
      R => PLBside_reset_OPB_retry_onRd
      );

--Delay for strobe on Positive edge on PLB-side
I_B_Strobe_out_1dly: FDSE
   port map(
      Q => OPB_retry_onRd_PLBside_1dly,
      C => PLB_Clk,
      CE => '1',
      D => OPB_retry_onRd_PLBside,
      S => PLBside_reset_OPB_retry_onRd
      );

--Generate B_side_Reset of Pos edge strobe and B_reset
I_B_side_Reg_CLR: LUT3
      generic map(
      INIT => X"F2"
      )
   port map(
      O => PLBside_reset_OPB_retry_onRd,
      I0 => OPB_retry_onRd_PLBside,
      I1 => OPB_retry_onRd_PLBside_1dly,
      I2 => PLB_Rst
      );

--********************************************************************
   --Generate PLB_PAValid_neg_edge
   I_PLB_PAValid_1dly: FDRSE
   port map(
      Q => PLB_PAValid_1dly,
      C => PLB_Clk,
      CE => '1',
      D => PLB_PAValid,
      R => PLB_Rst,
      S => '0'
      );

   I_PLB_PAValid_neg_edge: LUT2
      generic map(
      INIT => X"4"
      )
   port map(
      O => PLB_PAValid_neg_edge,
      I0 => PLB_PAValid,
      I1 => PLB_PAValid_1dly
      );

--********************************************************************
--Fix to make compatible with IPIF architecture

--Block PAValid if Wait_on_Rd
PLB_PAValid_int <= PLB_PAValid and not(Wait_on_Rd) and
                   not(Block_on_Term_Rd_after_tout);
PLB_SAValid_int <= PLB_SAValid and not(Wait_on_Rd) and
                   not(Block_on_Term_Rd_after_tout);

--********************************************************************
--Fix to make compatible with IPIF architecture

--Rearbitrate normally (_int) if not Waiting on read or
--on OPB retry on read
BGO_rearbitrate <= (BGO_rearbitrate_int and not(Wait_on_Rd))
                    or OPB_retry_onRd_PLBside;

--PLB arbiter only responds to this signal in read operation
PLB2OPB_rearb <=  OPB_retry_onRd_PLBside;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Copied from plb2opb_bridge_plb_if and modified
--concatenated delayed addrAck
GEN_32BIT_SLAVE: if C_PLB_DWIDTH = 32 generate
    BGO_SSize <= (others => '0');
end generate GEN_32BIT_SLAVE;
GEN_64BIT_SLAVE: if C_PLB_DWIDTH = 64 generate
    --BGO_SSize(0 to 1) <= '0' & BGO_addrAck_i;
    BGO_SSize(0 to 1) <= '0' & BGO_addrAck_dlydonRd;
end generate GEN_64BIT_SLAVE;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Block output on PLB abort until OPB_rst
--Generate signal to Block pipelined output on PLBabort
Block_output_on_PLBabort_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or rst = '1') then
         Block_output_on_PLBabort_regd <= '0';
      elsif(PLB_abort_onRd = '1') then
         Block_output_on_PLBabort_regd <= '1';
      end if;
   end if;
end process Block_output_on_PLBabort_PROCESS;

Block_output_on_PLBabort_OPBside_PROCESS: process(OPB_Clk)
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(rst = '1') then
         Block_output_on_PLBabort_OPBside <= '0';
      else
         Block_output_on_PLBabort_OPBside <= 
                      Block_output_on_PLBabort;
      end if;
   end if;
end process Block_output_on_PLBabort_OPBside_PROCESS;

--Generate PLB_side_Reset of Pos edge strobe and PLB_reset
I_Block_output_on_PLBabort: LUT3
      generic map(
      INIT => X"F8"
      )
   port map(
      O => Block_output_on_PLBabort,
      I0 => PLB_abort,
      I1 => Wait_on_Rd,
      I2 => Block_output_on_PLBabort_regd
      );

--********************************************************************
--Fix to make compatible with IPIF architecture
--Generate OPB_timeout_onRd

OPB_timeout_onRd <= OPB_timeout and BGO_RNW_int;

--Register OPB_timeout (always 1 OPB clock) and asynchronously clear
I_OPB_timeout_Reg: FDCPE
   port map(
      Q => OPB_timeout_onRd_regd,
      D => '1',
      C => OPB_Clk,
      CE => OPB_timeout_onRd,
      CLR => PLBside_reset_OPB_timeout_onRd,
      PRE => '0'
      );

--Synchronize OPB_timeout to PLB-side and synchronously reset
   I_OPB_timeout_onRd_synch1: FDRE
   port map(
      Q => OPB_timeout_onRd_regd_synch1,
      C => PLB_Clk,
      CE => '1',
      D => OPB_timeout_onRd_regd,
      R => PLBside_reset_OPB_timeout_onRd
      );

   I_OPB_timeout_onRd_synch2: FDRE
   port map(
      Q => OPB_timeout_onRd_PLBside,
      C => PLB_Clk,
      CE => '1',
      D => OPB_timeout_onRd_regd_synch1,
      R => PLBside_reset_OPB_timeout_onRd
      );

--Delay for strobe on Positive edge on PLB-side
I_OPB_timeout_Strobe_out_1dly: FDSE
   port map(
      Q => OPB_timeout_onRd_PLBside_1dly,
      C => PLB_Clk,
      CE => '1',
      D => OPB_timeout_onRd_PLBside,
      S => PLBside_reset_OPB_timeout_onRd
      );

--Generate B_side_Reset of Pos edge strobe and B_reset
I_OPB_timeout_side_Reg_CLR: LUT3
      generic map(
      INIT => X"F2"
      )
   port map(
      O => PLBside_reset_OPB_timeout_onRd,
      I0 => OPB_timeout_onRd_PLBside,
      I1 => OPB_timeout_onRd_PLBside_1dly,
      I2 => PLB_Rst
      );

--********************************************************************
--Fix to make compatible with IPIF architecture
--Generate signal to Block PAValid on read timeout at completion of
--timeout procedure to stop addr ack if a write request is being
--made during this time; requires PAValid be low (3 cycle arbitration
--is assumed)

Block_on_Term_Rd_after_tout_EN_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or BGO_rdComp_int_2dly = '1') then
         Block_on_Term_Rd_after_tout_EN <= '0';
      elsif(OPB_timeout_onRd_PLBside = '1') then
         Block_on_Term_Rd_after_tout_EN <= '1';
      end if;
   end if;
end process Block_on_Term_Rd_after_tout_EN_PROCESS;

Block_on_Term_Rd_after_tout_CE <= Block_on_Term_Rd_after_tout_EN and
             not(PLB_PAValid) and 
             (BGO_rdBTerm_int or BGO_rdBTerm_int_1dly or
              BGO_rdBTerm_int_2dly);

Block_on_Term_Rd_after_tout_PROCESS: process(PLB_Clk)
begin
   if(PLB_Clk'event and PLB_Clk = '1') then
      if(PLB_Rst = '1' or BGO_rdComp_int_2dly = '1') then
         Block_on_Term_Rd_after_tout <= '0';
      elsif(Block_on_Term_Rd_after_tout_CE = '1') then
         Block_on_Term_Rd_after_tout <= '1';
      end if;
   end if;
end process Block_on_Term_Rd_after_tout_PROCESS;

--********************************************************************
--Fix to make compatible with IPIF architecture
--Gate PLB_abort by Read_inprogress
--Pass PLB_abort to submodule if read not inprogress
PLB_abort_onRd <= PLB_abort and Wait_on_Rd;
PLB_abort_int <= PLB_abort and not(Read_inprog);

--Synchronize PLB abort to OPB-side if Read in progress
--Register PLB_abort (always 1 PLB clock) and asynchronously clear
I_PLB_abort_Reg: FDCPE
   port map(
      Q => PLB_abort_onRd_regd,
      D => '1',
      C => PLB_Clk,
      CE => PLB_abort_onRd,
      CLR => PLB_abort_regd_clear,
      PRE => '0'
      );

--Synchronize to PLB-side and synchronously reset
   I_PLB_abort_onRd_synch1: FDRE
   port map(
      Q => PLB_abort_onRd_regd_synch1,
      C => OPB_Clk,
      CE => '1',
      D => PLB_abort_onRd_regd,
      R => PLB_abort_regd_clear
      );

   I_PLB_abort_onRd_synch2: FDRE
   port map(
      Q => PLB_abort_onRd_OPBside,
      C => OPB_Clk,
      CE => '1',
      D => PLB_abort_onRd_regd_synch1,
      R => PLB_abort_regd_clear
      );

--Delay for strobe on Positive edge on OPB-side
I_PLB_abort_onRd_OPBside_1dly: FDSE
   port map(
      Q => PLB_abort_onRd_OPBside_1dly,
      C => OPB_Clk,
      CE => '1',
      D => PLB_abort_onRd_OPBside,
      S => PLB_abort_regd_clear
      );

--Generate PLB_side_Reset of Pos edge strobe and PLB_reset
I_PLB_abort_regd_clear: LUT3
      generic map(
      INIT => X"F2"
      )
   port map(
      O => PLB_abort_regd_clear,
      I0 => PLB_abort_onRd_OPBside,
      I1 => PLB_abort_onRd_OPBside_1dly,
      I2 => OPB_Rst
      );

--********************************************************************
--Fix to make compatible with IPIF architecture
--Pass PLB_abort_onRd_OPBside to OPB rst if BGO_select_int is low or
--wait for neg edge of BGO_select_int if OPB xfer in progress

BGO_select <= BGO_select_int;
opb_xfer_rd_data_rst1_int <= opb_xfer_rd_data_rst1 or
                             OPB_rst_on_PLB_abort;

--Generate OPB_side_Reset on PLB abort
I_OPB_rst_on_PLB_abort: LUT4
      generic map(
      INIT => X"3200"
      )
   port map(
      O => OPB_rst_on_PLB_abort,
      I0 => PLB_abort_onRd_OPBside,
      I1 => BGO_select_int,
      I2 => BGO_select_negedge,
      I3 => Block_output_on_PLBabort_OPBside
      );

--Generate BGO_select_negedge
   I_BGO_select_regd: FDRSE
   port map(
      Q => BGO_select_1dly,
      C => OPB_Clk,
      CE => '1',
      D => BGO_select_int,
      R => rst,
      S => '0'
      );

   I_BGO_select_negedge: LUT2
      generic map(
      INIT => X"4"
      )
   port map(
      O => BGO_select_negedge,
      I0 => BGO_select_int,
      I1 => BGO_select_1dly
      );

end;
