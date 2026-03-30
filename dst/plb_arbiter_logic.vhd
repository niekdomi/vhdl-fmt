-------------------------------------------------------------------------------
--  $Id: plb_arbiter_logic.vhd,v 1.3 2004/11/23 01:15:02 jcanaris Exp $
-------------------------------------------------------------------------------
-- plb_arbiter_logic.vhd - entity/architecture pair
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
-- Filename:        plb_arbiter_logic.vhd
-- Version:         v1.01a
-- Description:     This file contains the arbitration and bus control logic
--                  for the PLB. The main bus control is done in the
--                  arb_registers and arb_control_sm modules. This file also
--                  contains the priority encoder, the watchdog timer, and
--                  all of the signal multiplexors.
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
--
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
--  LCW	Oct 15, 2004	  -- updated for NCSim
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

-- PROC_COMMON_PKG contains the function that creates NUM_MSTRS_PAD which is
-- the number of masters rounded up to the next power of 2
library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

library unisim;
use unisim.vcomponents.all;

library plb_v34_v1_02_a;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS        -- number of masters
--      C_MID_BITS           -- number of bits required to encode master IDs
--      C_PLB_AWIDTH         -- address bus width
--      C_PLB_DWIDTH         -- data bus width
--      C_DCR_INTFCE         -- include DCR interface
--      C_DCR_AWIDTH         -- DCR address width
--      C_DCR_DWIDTH         -- DCR data width
--      C_BASEADDR           -- DCR base address
--      C_HIGHADDR           -- DCR high address
--      C_IRQ_ACTIVE         -- active edge for interrupt (rising or falling)
--
-- Definition of Ports:
--      -- Masters' signals
--      input  M_RNW
--      input  M_abort
--      input  M_busLock
--      input  M_lockErr
--      input  M_priority
--      input  M_rdBurst
--      input  M_request
--      input  M_wrBurst
--
--      -- PLB signals
--      input  PLB_ABus
--      input  PLB_BE
--      output PLB_MAddrAck
--      output PLB_MBusy
--      output PLB_MErr
--      output PLB_MRdBTerm
--      output PLB_MRearbitrate
--      output PLB_MWrBTerm
--      output PLB_MSSize
--      output PLB_PAValid
--      output PLB_SAValid
--      output PLB_masterID
--      output PLB_pendPri
--      output PLB_rdPrim
--      output PLB_rdPrimReg
--      output PLB_reqPri
--      output PLB_wrPrim
--      output PLB_RNW
--      output PLB_abort
--      output PLB_busLock
--      output PLB_pendReq
--      output PLB_rdBurst
--      input  PLB_size
--      input  PLB_type
--      output PLB_wrBurst
--
--      -- Slave signals
--      input  Sl_MBusy
--      input  Sl_MErr
--      input  Sl_rdBTerm
--      input  Sl_SSize
--      input  Sl_wrBTerm
--      input  Sl_wrComp
--      input  Sl_addrAck
--      input  Sl_rdComp
--      input  Sl_rearbitrate
--      input  Sl_wait
--
--      -- Arbiter signals
--      output ArbAddrSelReg
--      input  ArbBurstReq
--      output ArbPriRdMasterRegReg
--      output ArbPriWrMasterReg
--      output ArbAddrVldReg
--
--      -- DCR signals
--      input  DCR_ABus
--      input  DCR_Read
--      input  DCR_Write
--      output PLB_dcrAck
--      output PLB_dcrDBus
--      input  DCR_DBus
--
--      -- Watch Dog Timer signals
--      output WdtRdDAck
--      output WdtWrDAck
--      output PLB_rdWdAddrWDT
--
--      -- Clock and reset
--      input  Clk
--      input  Rst
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity plb_arbiter_logic is
  generic (
           C_NUM_MASTERS        : integer   := 8;
           C_MID_BITS           : integer   := 3;
           C_PLB_AWIDTH         : integer   := 32;
           C_PLB_DWIDTH         : integer   := 64;
           C_DCR_INTFCE         : integer   := 1;
           C_DCR_AWIDTH         : integer   := 10;
           C_DCR_DWIDTH         : integer   := 32;
           C_BASEADDR           : std_logic_vector;
           C_HIGHADDR           : std_logic_vector;
           C_IRQ_ACTIVE         : std_logic := '1';
           C_NUM_PLB2OPB_BRIDGE  : integer;
           C_NUM_OPBCLK_PLB2OPB_REARB : integer
           );
  port (
        M_RNW                   : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_abort                 : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_busLock               : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_lockErr               : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_priority              : in std_logic_vector(0 to (C_NUM_MASTERS * 2) - 1 );
        M_rdBurst               : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_request               : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        M_wrBurst               : in std_logic_vector(0 to C_NUM_MASTERS - 1 );

        PLB_ABus                : in std_logic_vector(0 to C_PLB_AWIDTH - 1 );
        PLB_BE                  : in std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
        PLB_MAddrAck            : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MBusy               : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MErr                : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MRdBTerm            : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MRearbitrate        : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MWrBTerm            : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        PLB_MSSize              : out std_logic_vector(0 to (C_NUM_MASTERS * 2) - 1 );
        PLB_PAValid             : out std_logic;
        PLB_SAValid             : out std_logic;
        PLB_masterID            : out std_logic_vector(0 to C_MID_BITS-1 );
        PLB_pendPri             : out std_logic_vector(0 to 1 );
        PLB_rdPrim              : out std_logic;
        PLB_reqPri              : out std_logic_vector(0 to 1 );
        PLB_wrPrim              : out std_logic;
        PLB_RNW                 : out std_logic;
        PLB_abort               : out std_logic;
        PLB_busLock             : out std_logic;
        PLB_pendReq             : out std_logic;
        PLB_rdBurst             : out std_logic;
        PLB_size                : in std_logic_vector(0 to 3 );
        PLB_type                : in std_logic_vector(0 to 2);
        PLB_wrBurst             : out std_logic;

        Sl_MBusy                : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        Sl_MErr                 : in std_logic_vector(0 to C_NUM_MASTERS - 1 );
        Sl_rdBTerm              : in std_logic;
        Sl_SSize                : in std_logic_vector(0 to 1 );
        Sl_wrBTerm              : in std_logic;
        Sl_wrComp               : in std_logic;
        Sl_addrAck              : in std_logic;
        Sl_rdComp               : in std_logic;
        Sl_rearbitrate          : in std_logic;
        Sl_wait                 : in std_logic;

        ArbAddrSelReg           : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbBurstReq             : in std_logic;
        ArbPriRdMasterRegReg    : out std_logic_vector(0 to C_NUM_MASTERS - 1 );
        ArbPriWrMasterReg       : out std_logic_vector(0 to C_NUM_MASTERS-1 );
        ArbAddrVldReg           : out std_logic;

        DCR_ABus                : in std_logic_vector (0 to C_DCR_AWIDTH-1);
        DCR_Read                : in std_logic;
        DCR_Write               : in std_logic;
        PLB_dcrAck              : out std_logic;
        PLB_dcrDBus             : out std_logic_vector (0 to C_DCR_DWIDTH-1);
        DCR_DBus                : in std_logic_vector (0 to C_DCR_DWIDTH-1);

        WdtRdDAck               : out std_logic;
        WdtWrDAck               : out std_logic;
        PLB_rdWdAddrWDT         : out std_logic_vector(0 to 3);
        Bus_Error_Det           : out std_logic;

        Clk                     : in std_logic;
        Rst                     : in std_logic;
          --Fix to make compatible with OPB IPIF architecture
        PLB2OPB_rearb           : in std_logic_vector(0 to C_NUM_PLB2OPB_BRIDGE-1)
        );
end plb_arbiter_logic;


-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture implementation of plb_arbiter_logic is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
constant NUM_MSTRS_PAD  : integer   := (((pad_power2(C_NUM_MASTERS)-1)/4)+1)*4;

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

-- define internal versions of output signals
signal plb_pavalid_i          : std_logic;
signal plb_savalid_i          : std_logic;
signal plb_rnw_i              : std_logic;
signal plb_abort_i            : std_logic;
signal plb_pendreq_i          : std_logic;
signal plb_rdburst_i          : std_logic;
signal plb_wrburst_i          : std_logic;
signal plb_arbAddrVldReg_i    : std_logic;
signal arbreset_i             : std_logic;
signal wdtrddack_i            : std_logic;
signal wdtwrdack_i            : std_logic;
signal arbaddrselreg_i        : std_logic_vector(0 to C_NUM_MASTERS-1);
signal arbPriRdMasterRegReg_i : std_logic_vector(0 to C_NUM_MASTERS-1);
signal arbPriWrMasterReg_i    : std_logic_vector(0 to C_NUM_MASTERS-1);
signal plb_reqpri_i           : std_logic_vector(0 to 1);
signal plb_rdprimreg_i        : std_logic;
signal plb_buslock_i          : std_logic;

-- define padded buses
signal m_request_pad          : std_logic_vector(0 to NUM_MSTRS_PAD-1);
signal m_priority_pad         : std_logic_vector(0 to 2*NUM_MSTRS_PAD-1);
signal m_abort_pad            : std_logic_vector(0 to NUM_MSTRS_PAD-1);
signal arbaddrselreg_pad      : std_logic_vector(0 to NUM_MSTRS_PAD-1);
signal arbDisMReqReg_pad      : std_logic_vector(0 to NUM_MSTRS_PAD-1);

signal mstr_buslock           : std_logic;
signal sm_buslock             : std_logic;

-- arbcontrol state machine and bus control state machine signals
signal set_disables_state     : std_logic;

signal loadDisReg             : std_logic;
signal loadPriRd              : std_logic;
signal loadPriWr              : std_logic;
signal loadSecRd              : std_logic;
signal loadSecRdPriReg        : std_logic;
signal loadSecWr              : std_logic;
signal loadSecWrPriReg        : std_logic;
signal qualReq                : std_logic;
signal recomputeRdBits        : std_logic;
signal recomputeWrBits        : std_logic;
signal arbAValid              : std_logic;
signal arbDisMReqReg          : std_logic_vector(0 to C_NUM_MASTERS-1 );
signal arbDisMReqRegIn        : std_logic_vector(0 to C_NUM_MASTERS-1 );
signal arbPriRdBurstReg       : std_logic;
signal arbPriRdMasterReg      : std_logic_vector(0 to C_NUM_MASTERS-1 );
signal arbRdDBusBusyReg       : std_logic;
signal arbSecRdInProgPriorReg : std_logic_vector(0 to 1 );
signal arbSecRdInProgReg      : std_logic;
signal arbSecRdMasterReg      : std_logic_vector(0 to C_NUM_MASTERS-1 );
signal arbSecWrInProgPriorReg : std_logic_vector(0 to 1 );
signal arbSecWrInProgReg      : std_logic;
signal arbSecWrMasterReg      : std_logic_vector(0 to C_NUM_MASTERS-1 );
signal arbWrDBusBusyReg       : std_logic;
signal loadAddrSelReg         : std_logic;
signal rdPrimIn               : std_logic;
signal rdPrimReg              : std_logic;

-- Watch Dog Timer signals
signal wdtAddrAck             : std_logic;
signal wdtCountIsZero         : std_logic;
signal wdtRdBTerm             : std_logic;
signal wdtRdComp              : std_logic;
signal wdtTimeOutAct          : std_logic;
signal wdtTimeOutBusy         : std_logic;
signal wdtTimeOutReg          : std_logic;
signal wdtWrBTerm             : std_logic;
signal wdtWrComp              : std_logic;
signal wrPrimIn               : std_logic;

-- interrupt enable and sw reset
signal intr_en                : std_logic;
signal sw_rst                 : std_logic;
-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- Priority encoder selects master with highest priority bits. If there are two
-- masters with the same priority inputs, Master 0 has the highest priority
-- followed by Master 1, Master 2, etc.

-- Arbiter Control state machine controls the PLB transactions and the assertion
-- of PAValid, SAValid, etc.

-- gen_qual_req determines if any of the masters have request asserted without abort or
-- being disabled due to a bus lock

-- The muxed_signals block contains all of the signal multiplexors for the PLB control
-- signals and transaction qualifiers

-- ArbRegisters maintain the current state of the bus, i.e. whether primary and/or
-- secondary transactions are in progress

-- The watchdog timer will assert the addrAck if the slave has not responded within 16
-- clock cycles from the assertion of PAValid or SAValid. It will then assert the
-- appropriate number of dataAcks along with Merr to complete the transaction.

-- dcr_regs contain the PLB control registers with a DCR interface.  If
-- the design is parameterized to not include the DCR interface, zero
-- the DCR output signals and pass the bus through.

-- The bus_lock_sm asserts PLB_buslock when a master locks the bus
-- when PAValid asserts and negates PLB_buslock with the master's buslock signal.
-- It also generates a buslock signal for use by the arb_control_sm which asserts
-- with the master's buslock signal, but negates one clock later.

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- assign internal signals to outputs
-------------------------------------------------------------------------------

PLB_PAValid         <= plb_pavalid_i;
wdtWrDAck           <= wdtwrdack_i;
wdtRdDAck           <= wdtrddack_i;
PLB_wrBurst         <= plb_wrburst_i;
ArbAddrVldReg       <= plb_arbAddrVldReg_i;
PLB_RNW             <= plb_rnw_i;
PLB_rdBurst         <= plb_rdburst_i;
PLB_abort           <= plb_abort_i;
PLB_pendReq         <= plb_pendreq_i;
PLB_reqPri          <= plb_reqpri_i;
PLB_SAValid         <= plb_savalid_i;
ArbAddrSelReg       <= arbaddrselreg_i;
ArbPriRdMasterRegReg <= arbPriRdMasterRegReg_i;
ArbPriWrMasterReg   <= arbPriWrMasterReg_i;
PLB_busLock         <= plb_buslock_i;

-------------------------------------------------------------------------------
-- set extra bits in padded buses to '0'
-------------------------------------------------------------------------------

m_request_pad(0 to C_NUM_MASTERS-1) <= M_request;
REQPAD_GEN: if C_NUM_MASTERS /= NUM_MSTRS_PAD generate
    m_request_pad(C_NUM_MASTERS to NUM_MSTRS_PAD-1) <= (others => '0');
end generate REQPAD_GEN;

m_abort_pad(0 to C_NUM_MASTERS-1) <= M_abort;
ABRTPAD_GEN: if C_NUM_MASTERS /= NUM_MSTRS_PAD generate
 m_abort_pad(C_NUM_MASTERS to NUM_MSTRS_PAD-1) <= (others => '0');
end generate ABRTPAD_GEN;

m_priority_pad(0 to C_NUM_MASTERS*2-1) <= M_priority;
PRIORITYPAD_GEN: if C_NUM_MASTERS /= NUM_MSTRS_PAD generate
 m_priority_pad(C_NUM_MASTERS*2 to NUM_MSTRS_PAD*2-1) <= (others => '0');
end generate PRIORITYPAD_GEN;

arbaddrselreg_pad(0 to C_NUM_MASTERS-1) <= arbaddrselreg_i;
ADDRSELPAD_GEN: if C_NUM_MASTERS /= NUM_MSTRS_PAD generate
 arbaddrselreg_pad(C_NUM_MASTERS to NUM_MSTRS_PAD-1) <= (others => '0');
end generate ADDRSELPAD_GEN;

arbDisMReqReg_pad(0 to C_NUM_MASTERS-1) <= ArbDisMReqReg;
DISMREQ_GEN: if C_NUM_MASTERS /= NUM_MSTRS_PAD generate
 arbDisMReqReg_pad(C_NUM_MASTERS to NUM_MSTRS_PAD-1) <= (others => '0');
end generate DISMREQ_GEN;

-------------------------------------------------------------------------------
-- ARBRESET_PROCESS
-------------------------------------------------------------------------------
-- This process registers the system reset to create arbreset.
-------------------------------------------------------------------------------
ARBRESET_PROCESS: process (Clk)

begin

      if (Clk'event and Clk = '1') then
          arbreset_i <= Rst or sw_rst;
      end if;

end process ARBRESET_PROCESS;


-------------------------------------------------------------------------------
-- RDPRIMREG_PROCESS
-------------------------------------------------------------------------------
-- This process creates the registered component of the PLB_rdPrim output.
-------------------------------------------------------------------------------
rdPrimIn <= (Sl_rdComp) and (Sl_addrAck) and (arbRdDBusBusyReg) and
              (plb_savalid_i) and (plb_rnw_i) and not (plb_abort_i);

RDPRIMREG_PROCESS: process(Clk, arbreset_i)

begin

  if (Clk'event and Clk = '1' ) then

      if arbreset_i= RESET_ACTIVE then
          plb_rdprimreg_i <= '0';
      else
          plb_rdprimreg_i <= rdPrimIn;
      end if ;

  end if;

end process RDPRIMREG_PROCESS;

-------------------------------------------------------------------------------
-- Combinatorial Logic
-------------------------------------------------------------------------------
-- The following statements define the various combinatorial PLB arbiter signals
-------------------------------------------------------------------------------


PLB_rdPrim <= (((Sl_rdComp) and (arbSecRdInProgReg))) or ((plb_rdprimreg_i));


wrPrimIn <= (Sl_wrComp) and (Sl_addrAck) and (arbWrDBusBusyReg) and
              (plb_savalid_i) and (not(plb_rnw_i));

PLB_wrPrim <= (((Sl_wrComp) and (arbSecWrInProgReg))) or ((wrPrimIn));

plb_arbAddrVldReg_i <= (plb_pavalid_i) or (plb_savalid_i);


-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- Priority encoder selects master with highest priority bits. If there are two
-- masters with the same priority inputs, Master 0 has the highest priority
-- followed by Master 1, Master 2, etc.

I_PRIORITY_ENCODER: entity plb_v34_v1_02_a.plb_priority_encoder
  generic map   (C_NUM_MASTERS  => C_NUM_MASTERS,
                 C_NUM_MSTRS_PAD=> NUM_MSTRS_PAD)
  port map (
          M_abort               =>  m_abort_pad,
          M_priority            =>  m_priority_pad,
          M_request             =>  m_request_pad,
          LoadAddrSelReg        =>  loadAddrSelReg,
          ArbDisMReqReg         =>  arbDisMReqReg_pad,
          ArbSecRdInProgReg     =>  arbSecRdInProgReg,
          SecRdInProgPriorReg   =>  arbSecRdInProgPriorReg,
          ArbSecWrInProgReg     =>  arbSecWrInProgReg,
          SecWrInProgPriorReg   =>  arbSecWrInProgPriorReg,
          ArbAddrSelReg         =>  arbaddrselreg_i,
          PLB_pendPri           =>  PLB_pendPri,
          PLB_pendReq           =>  plb_pendreq_i,
          PLB_reqPri            =>  plb_reqpri_i,
          Clk                   =>  Clk,
          ArbReset              =>  arbreset_i
          );

-- Arbiter Control state machine controls the PLB transactions and the assertion
-- of PAValid, SAValid, etc.
I_ARBCONTROL_SM: entity plb_v34_v1_02_a.arb_control_sm
    generic map (C_NUM_MASTERS => C_NUM_MASTERS,
                 C_NUM_PLB2OPB_BRIDGE => C_NUM_PLB2OPB_BRIDGE,
                 C_NUM_OPBCLK_PLB2OPB_REARB =>
                          C_NUM_OPBCLK_PLB2OPB_REARB)
  port map (
            AAck                => Sl_addrAck,
            Abort               => plb_abort_i,
            ArbAddrSelReg       => arbaddrselreg_i,
            ArbRdDBusBusyReg    => arbRdDBusBusyReg,
            ArbWrDBusBusyReg    => arbWrDBusBusyReg,
            ArbSecRdInProgReg   => arbSecRdInProgReg,
            ArbSecWrInProgReg   => arbSecWrInProgReg,
            SM_busLock          => sm_buslock,
            PLB_busLock         => plb_buslock_i,
            Clk                 => Clk,
            QualReq             => qualReq,
            Read                => plb_rnw_i,
            Rearbitrate         => Sl_rearbitrate,
            Rst                 => arbreset_i,
            Sl_rdComp           => Sl_rdComp,
            Sl_wrComp           => Sl_wrComp,
            wdtAAck             => wdtAddrAck,
            wdtRdComp           => wdtRdComp,
            wdtWrComp           => wdtWrComp,
            Set_disables_state  => set_disables_state,
            DisMnReqIn          => arbDisMReqRegIn,
            LoadDisReg          => loadDisReg,
            LoadPriRd           => loadPriRd,
            LoadPriWr           => loadPriWr,
            LoadSecRd           => loadSecRd,
            LoadSecRdPriReg     => loadSecRdPriReg,
            LoadSecWr           => loadSecWr,
            LoadSecWrPriReg     => loadSecWrPriReg,
            loadAddrSelReg      => loadAddrSelReg,
            PAValid             => plb_pavalid_i,
            RecomputeRdBits     => recomputeRdBits,
            RecomputeWrBits     => recomputeWrBits,
            SAValid             => plb_savalid_i,
          --Fix to make compatible with OPB IPIF architecture
            PLB2OPB_rearb       => PLB2OPB_rearb);

-- gen_qual_req determines if any of the masters have request asserted without abort or
-- being disabled due to a bus lock
I_GENQUALREQ: entity plb_v34_v1_02_a.gen_qual_req
    generic map ( C_NUM_MASTERS => C_NUM_MASTERS)
    port map (
                QualReq         => qualReq,
                M_request       => M_request,
                arbDisMReqReg   => arbDisMReqReg,
                M_abort         => M_abort);

-- The muxed_signals block contains all of the signal multiplexors for the PLB control
-- signals and transaction qualifiers
I_MUXEDSIGNALS: entity plb_v34_v1_02_a.muxed_signals
    generic map ( C_NUM_MASTERS     => C_NUM_MASTERS,
                  C_NUM_MSTRS_PAD   => NUM_MSTRS_PAD,
                  C_MID_BITS        => C_MID_BITS
                )

  port map (
            M_busLock               => M_busLock,
            M_RNW                   => M_RNW,
            M_abort                 => M_abort,
            Sl_addrAck              => Sl_addrAck,
            Sl_SSize                => Sl_SSize,
            Sl_rearbitrate          => Sl_rearbitrate,
            Sl_MBusy                => Sl_MBusy,
            M_rdBurst               => M_rdBurst,
            Sl_rdBTerm              => Sl_rdBTerm,
            M_wrBurst               => M_wrBurst,
            Sl_wrBTerm              => Sl_wrBTerm,
            Sl_MErr                 => Sl_MErr,
            WdtAddrAck              => wdtAddrAck,
            WdtRdBTerm              => wdtRdBTerm,
            WdtWrBTerm              => wdtWrBTerm,
            ArbAddrSelReg           => arbaddrselreg_i,
            ArbAddrSelRegPad        => arbaddrselreg_pad,
            PLB_PAValid             => plb_pavalid_i,
            PLB_SAValid             => plb_savalid_i,
            ArbAValid               => arbAValid,
            ArbPriRdMasterReg       => arbPriRdMasterReg,
            ArbPriRdMasterRegReg    => arbPriRdMasterRegReg_i,
            ArbPriWrMasterReg       => arbPriWrMasterReg_i,
            WdtTimeOutBusy          => wdtTimeOutBusy,
            WdtRdDAck               => wdtrddack_i,
            WdtWrDAck               => wdtwrdack_i,
            ArbWrDBusBusyReg        => arbWrDBusBusyReg,
            Mstr_buslock            => mstr_buslock,
            PLB_masterID            => PLB_masterID,
            PLB_RNW                 => plb_rnw_i,
            PLB_abort               => plb_abort_i,
            PLB_MAddrAck            => PLB_MAddrAck,
            PLB_MSSize              => PLB_MSSize,
            PLB_MRearbitrate        => PLB_MRearbitrate,
            PLB_MBusy               => PLB_MBusy,
            PLB_rdBurst             => plb_rdburst_i,
            PLB_rdPrimReg           => plb_rdprimreg_i,
            PLB_MRdBTerm            => PLB_MRdBTerm,
            PLB_wrBurst             => plb_wrburst_i,
            PLB_MWrBTerm            => PLB_MWrBTerm,
            PLB_MErr                => PLB_MErr,
            ArbPriRdBurstReg        => arbPriRdBurstReg);

-- ArbRegisters maintain the current state of the bus, i.e. whether primary and/or
-- secondary transactions are in progress
I_ARBREGISTERS: entity plb_v34_v1_02_a.arb_registers
    generic map (C_NUM_MASTERS  => C_NUM_MASTERS )
    port map (
            LoadDisReg          => loadDisReg,
            LoadPriRd           => loadPriRd,
            LoadPriWr           => loadPriWr,
            LoadSecRd           => loadSecRd,
            LoadSecRdPriReg     => loadSecRdPriReg,
            LoadSecWr           => loadSecWr,
            LoadSecWrPriReg     => loadSecWrPriReg,
            PLB_reqPri          => plb_reqpri_i,
            RecomputeRdBits     => recomputeRdBits,
            RecomputeWrBits     => recomputeWrBits,
            Sl_rdComp           => Sl_rdComp,
            Sl_wrComp           => Sl_wrComp,
            ArbAddrSelReg       => arbaddrselreg_i,
            ArbBurstReq         => arbBurstReq,
            ArbDisMReqReg       => arbDisMReqReg,
            ArbDisMReqRegIn     => arbDisMReqRegIn,
            ArbPriRdBurstReg    => arbPriRdBurstReg,
            ArbPriRdMasterReg   => arbPriRdMasterReg,
            ArbPriRdMasterRegReg => arbPriRdMasterRegReg_i,
            ArbPriWrMasterReg   => arbPriWrMasterReg_i,
            ArbRdDBusBusyReg    => arbRdDBusBusyReg,
            ArbSecRdInProgPriorReg => arbSecRdInProgPriorReg,
            ArbSecRdInProgReg   => arbSecRdInProgReg,
            ArbSecRdMasterReg   => arbSecRdMasterReg,
            ArbSecWrInProgPriorReg => arbSecWrInProgPriorReg,
            ArbSecWrInProgReg   => arbSecWrInProgReg,
            ArbSecWrMasterReg   => arbSecWrMasterReg,
            ArbWrDBusBusyReg    => arbWrDBusBusyReg,
            WdtRdComp           => wdtRdComp,
            WdtWrComp           => wdtWrComp,
            Clk                 => Clk,
            ArbReset            => arbreset_i
            );

-- The watchdog timer will assert the addrAck if the slave has not responded within 16
-- clock cycles from the assertion of PAValid or SAValid. It will then assert the
-- appropriate number of dataAcks along with Merr to complete the transaction.
I_WDT: entity plb_v34_v1_02_a.watchdog_timer
  port map (
            Clk => Clk,
            ArbReset => arbreset_i,
            ArbAddrValidReg => plb_arbAddrVldReg_i,
            PLB_size => PLB_size,
            PLB_AValid => plb_pavalid_i,
            PLB_RNW => plb_rnw_i,
            PLB_rdBurst => plb_rdburst_i,
            PLB_wrBurst => plb_wrburst_i,
            PLB_abort => plb_abort_i,
            Sl_addrAck => Sl_addrAck,
            Sl_rearbitrate => Sl_rearbitrate,
            Sl_wait => Sl_wait,
            WdtAddrAck => wdtAddrAck,
            WdtRdBTerm => wdtRdBTerm,
            WdtWrBTerm => wdtWrBTerm,
            WdtRdComp => wdtRdComp,
            WdtWrComp => wdtWrComp,
            WdtRdDAck => wdtrddack_i,
            WdtWrDAck => wdtwrdack_i,
            PLB_rdWdAddrWDT => PLB_rdWdAddrWDT,
            WdtCountIsZero => wdtCountIsZero,
            WdtTimeOutReg => wdtTimeOutReg,
            WdtTimeOutAct => wdtTimeOutAct,
            WdtTimeOutBusy => wdtTimeOutBusy);

-- dcr_regs contain the PLB control registers with a DCR interface. If the design
-- is parameterized not to include a DCR interface, set the DCR ACK to zero and
-- pass the DCR data bus through.
DCR_GEN: if C_DCR_INTFCE = 1 generate
    I_DCR: entity plb_v34_v1_02_a.dcr_regs
      generic map ( C_NUM_MASTERS   => C_NUM_MASTERS,
                    C_PLB_AWIDTH    => C_PLB_AWIDTH,
                    C_PLB_DWIDTH    => C_PLB_DWIDTH,
                    C_DCR_AWIDTH    => C_DCR_AWIDTH,
                    C_DCR_DWIDTH    => C_DCR_DWIDTH,
                    C_BASEADDR      => C_BASEADDR,
                    C_HIGHADDR      => C_HIGHADDR
                  )
      port map (
                Clk                 => Clk,
                ArbReset            => arbreset_i,
                DCR_Write           => DCR_Write,
                DCR_Read            => DCR_Read,
                DCR_ABus            => DCR_ABus,
                DCR_DBus            => DCR_DBus,
                PLB_dcrAck          => PLB_dcrAck,
                PLB_dcrDBus         => PLB_dcrDBus,
                WdtCountIsZero      => wdtCountIsZero,
                WdtAddrAck          => wdtAddrAck,
                ArbAddrSelReg       => arbaddrselreg_i,
                Sl_addrAck          => Sl_addrAck,
                PLB_RNW             => plb_rnw_i,
                PLB_ABus            => PLB_ABus,
                PLB_BE              => PLB_BE,
                PLB_size            => PLB_size,
                PLB_type            => PLB_type,
                M_lockErr           => M_lockErr,
                Intr_en             => intr_en,
                SW_Rst              => sw_rst
                );
end generate DCR_GEN ;

NO_DCR_GEN: if C_DCR_INTFCE = 0 generate
    PLB_dcrAck  <= '0';
    PLB_dcrDBus <= DCR_DBus;
    sw_rst      <= '0';
    intr_en     <= '1';
end generate  NO_DCR_GEN;

PLB_INTR_I: entity plb_v34_v1_02_a.plb_interrupt
    generic map ( C_IRQ_ACTIVE => C_IRQ_ACTIVE)
  port map (
        Clk             =>  Clk,
        Rst             =>  arbreset_i,
        WdtCountIsZero  =>  wdtCountIsZero,
        WdtAddrAck      =>  wdtAddrAck ,
        Sl_addrAck      =>  Sl_addrAck,
        Intr_en         =>  intr_en,
        Bus_Error_Det   =>  Bus_Error_Det
        );

-- The bus_lock_sm asserts PLB_buslock when a master locks the bus
-- when PAValid asserts and negates PLB_buslock with the master's buslock signal.
-- It also generates a buslock signal for use by the arb_control_sm which asserts
-- with the master's buslock signal, but negates one clock later.

I_BUSLOCK_SM: entity plb_v34_v1_02_a.bus_lock_sm
  port map (
            Mstr_buslock        => mstr_buslock,
            Set_disables_state  => set_disables_state,
            Sl_rearbitrate      => Sl_rearbitrate,
            Sl_addrAck          => Sl_addrAck,
            Abort               => plb_abort_i,
            PLB_busLock         => plb_buslock_i,
            SM_busLock          => sm_busLock,
            Rst                 => arbreset_i,
            Clk                 => Clk);


end implementation;

