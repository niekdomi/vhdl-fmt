-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_opb_if.vhd,v 1.6 2005/09/15 17:22:50 mlovejoy Exp $
-------------------------------------------------------------------------------
--  PLB to OPB Bridge Out, OPB Interface - Module
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
--  Filename:       plb2opb_bridge_opb_if.vhd
--  Version:        v1.01a
--  Description:
--    This module is the OPB Master interface for the PLB to OPB Bridge. It is
--    responsible for generating OPB transactions on the OPB bus and for
--    communicating back status and read data to the PLB interface.
--
-- VHDL-Standard:   VHDL'93
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
--  Author:
--  History:
--      KD      5/22/01     -- EA 2 Release
--      ALS     11/06/01    -- VHDL conversion
--      ALS     12/13/01    -- incorporated compliance test modifications
--      ALS     01/15/02    
-- ^^^^^^
--      Modified code to match updated design spec. Logic to support retry_req
--      signal is now renamed BGI_TRANS_ABORT and is parameterizable. The 
--      parameter is hard-coded to include this logic and is not user
--      modifiable at this time.
-- ~~~~~~
--      ALS     04/01/02
-- ^^^^^^
--      Added constants for RCV data and XFER data bit indices.
-- ~~~~~~
--      ALS     07/04/02
-- ^^^^^^
--      Fixed counter value for BGI_TRANSABORT_CNT
-- ~~~~~~
--      ALS     07/09/02            -- Version 1.00b
-- ^^^^^^
--  C_INCLUDE_BGI_TRANSABORT generic is no longer used.
-- ~~~~~~
--      MLL     01/09/04            -- Version 1.01a
-- ^^^^^^
--  Remove ILA component
-- ~~~~~~
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
use ieee.std_logic_ARITH.all;
use ieee.std_logic_UNSIGNED.all;
 
library unisim;
use unisim.vcomponents.all;

library plb2opb_bridge_v1_01_a;
use plb2opb_bridge_v1_01_a.plb2opb_bridge_pkg.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_opb_if is
  generic ( C_OPB_DWIDTH                : integer := 32;
            C_OPB_AWIDTH                : integer := 32;
            C_RCV_DATA_WIDTH            : integer := 38;
            C_XFER_DATA_WIDTH           : integer := 72;
            C_BGI_TRANSABORT_CNT        : integer := 8;
            C_BGI_TRANSABORT_CNT_WIDTH   : integer := 3
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
        Err_byte_enable         : out std_logic_vector(0 to C_OPB_DWIDTH/8 -1);
        Err_rd_wr_n             : out std_logic;
        Timeout_det             : out std_logic
        );
end plb2opb_bridge_opb_if;
 
-------------------------------------------------------------------------------
--  Architecture section
------------------------------------------------------------------------------- 
architecture plb2opb_bridge_opb_if of plb2opb_bridge_opb_if is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------

constant BGI_TRANSABORT_CNT : std_logic_vector(0 to C_BGI_TRANSABORT_CNT_WIDTH-1) 
                := conv_std_logic_vector(C_BGI_TRANSABORT_CNT-1,C_BGI_TRANSABORT_CNT_WIDTH);

-- bit ranges for the PLB-OPB xfer data
constant XFER_DBUS_START    : integer   := 0;
constant XFER_DBUS_END      : integer   := C_OPB_DWIDTH-1;
constant XFER_ABUS_START    : integer   := XFER_DBUS_END+1;
constant XFER_ABUS_END      : integer   := XFER_ABUS_START+C_OPB_AWIDTH-1;
constant XFER_BE_START      : integer   := XFER_ABUS_END+1;
constant XFER_BE_END        : integer   := XFER_BE_START+C_OPB_DWIDTH/8-1;
constant XFER_RNW           : integer   := XFER_BE_END+1;
constant XFER_BUSLOCK       : integer   := XFER_BE_END+2;
constant XFER_SEQADDR       : integer   := XFER_BE_END+3;
constant XFER_LASTWRD       : integer   := XFER_BE_END+4;

-- bit ranges for the OPB-PLB rcv data
constant RCV_DBUS_START     : integer   := 0;
constant RCV_DBUS_END       : integer   := C_OPB_DWIDTH-1;
constant RCV_RDWDADDR_START : integer   := RCV_DBUS_END+1;
constant RCV_RDWDADDR_END   : integer   := RCV_RDWDADDR_START+3;
constant RCV_ERR            : integer   := RCV_RDWDADDR_END+1;
constant RCV_LASTWRD        : integer   := RCV_RDWDADDR_END+2;

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- internal versions of output signals
signal BGO_ABus_i             : std_logic_vector(0 to C_OPB_AWIDTH-1) := (others => '0');
signal BGO_BE_i               : std_logic_vector(0 to C_OPB_DWIDTH/8 -1) := (others => '0');
signal BGO_request_i          : std_logic := '0';
signal BGO_RNW_i              : std_logic := '0';  
signal BGO_select_i           : std_logic := '0';
signal bgi_trans_abort_i      : std_logic := '0';

signal hold_buslock           : std_logic;
signal last_word              : std_logic;
signal BGO_select_set         : std_logic;
signal BGO_select_rst         : std_logic;
signal BGO_select_ce          : std_logic;
signal BGO_request_set        : std_logic;
signal BGO_request_rst        : std_logic;
signal BGO_request_ce         : std_logic;
signal opb_xfer_pend          : std_logic := '0';
signal opb_xfer_pend_d        : std_logic;
signal opb_xfer_pend_set      : std_logic;
signal opb_xfer_start_flag_d1 : std_logic;
signal bgi_transabort_cntr    : std_logic_vector(0 to C_BGI_TRANSABORT_CNT_WIDTH-1 );
signal retry_last             : std_logic;
signal rst_d1                 : std_logic;
signal rst_d2                 : std_logic;
signal start_xfer             : std_logic;
signal timeout_last           : std_logic;
signal xfer_next_word         : std_logic;
signal xfer_rd_addr           : std_logic_vector(0 to 3 );
signal xfer_rd_addr_inc       : std_logic_vector(0 to 3 );

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--  Begin architecture
------------------------------------------------------------------------------- 
begin
-- assign outputs
BGO_ABus      <= BGO_ABus_i;
BGO_select    <= BGO_select_i;
BGO_BE        <= BGO_BE_i;
BGO_request   <= BGO_request_i;
BGO_RNW       <= BGO_RNW_i;

-------------------------------------------------------------------------------
--  Main Control Logic. When a transfer is pending it requests control
--  of the OPB Bus and transfers data. It must also respond to Timeouts
--  and Retries
-------------------------------------------------------------------------------
--  Generate a pulse for one clock cycle when a new transfer starts
OPB_XFERSTRT_REG: process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    opb_xfer_start_flag_d1 <= OPB_xfer_start_flag;
  end if;
end process OPB_XFERSTRT_REG;

start_xfer <= OPB_xfer_start_flag and not(opb_xfer_start_flag_d1);

--  Signal Back to PLB side that the start signal was received
OPB_xfer_start_ack <= OPB_xfer_start_flag;

--  Flag when a word has been transferred and the next word can be driven out
xfer_next_word <= BGO_select_i and not(OPB_retry) and 
                ((OPB_xferAck or OPB_timeout));

--  Flag when last word is being transferred
last_word <= OPB_xfer_rd_data(XFER_LASTWRD)or OPB_xfer_abort_flag;

--  Signal that a data transfer is in progress
opb_xfer_pend_d     <= not(opb_xfer_pend and last_word);
opb_xfer_pend_set   <= not(opb_xfer_pend) and start_xfer;

OPB_XFER_PEND_FDRSE_I: fdrse
  port map (
    Q   => opb_xfer_pend, --[out]
    C   => OPB_Clk, --[in]
    CE  => xfer_next_word, --[in]
    D   => opb_xfer_pend_d, --[in]
    R   => Rst, --[in]
    S   => opb_xfer_pend_set --[in]
  );

--  Acknowledge an abort after any ongoing OPB transfer has completed
OPB_xfer_abort_ack <= OPB_xfer_abort_flag and not(opb_xfer_pend);

--  Signal that the last data transfer ended in retry or timeout so
--  OPB master signals can take the appropriate actions
RETRY_TIMEOUT_REGS: process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    retry_last <= BGO_select_i and OPB_retry;
    timeout_last <= BGO_select_i and not(OPB_retry) and OPB_timeout and
                    not(OPB_xferAck);
  end if;
end process RETRY_TIMEOUT_REGS;

--  Generate BGO_request signal on OPB. Logic is organized so that
--  signals with critical timing go through a minimal number of logic levels
BGO_request_rst <= '1' 
            when (BGO_select_i = '1' and 
                (OPB_retry ='1' or (OPB_timeout = '1' and (OPB_xferAck='0')))) 
            else '0';
BGO_request_set <= not(OPB_MnGrant) and not(Rst) and
                ((opb_xfer_pend and retry_last) or (not(opb_xfer_pend) and start_xfer)); 

BGO_request_ce <= OPB_MnGrant or Rst;                
                    
BGO_request_fdr: FDRSE
  port map (
    Q   => BGO_request_i,     --[out]
    C   => OPB_Clk,         --[in]
    CE  => BGO_request_ce,     --[in]
    D   => '0',             --[in]
    R   => BGO_request_rst,   --[in]
    S   => BGO_request_set    --[in]
  );

--  Generate BGO_select signal on OPB. Logic is organized so that
--  signals with critical timing go through a minimal number of logic levels
BGO_select_set <= ((start_xfer or opb_xfer_pend) and 
                 (OPB_MnGrant or timeout_last)) and
                not(BGO_select_i and last_word and OPB_xferAck);
BGO_select_ce <= (BGO_select_i and last_word and OPB_xferAck) or
                not(opb_xfer_pend);
BGO_select_rst <= '1' 
    when (BGO_select_i='1' and
         (OPB_retry='1' or (OPB_timeout='1' and OPB_xferAck='0')))
         or Rst = RESET_ACTIVE
    else '0';

BGO_select_fdrse: FDRSE
  port map (
    Q   => BGO_select_i,      --[out]
    C   => OPB_Clk,         --[in]
    CE  => BGO_select_ce,     --[in]
    D   => '0',             --[in]
    R   => BGO_select_rst,    --[in]
    S   => BGO_select_set     --[in]
  );

--  Logic to hold OPB busLock if PLB busLock is asserted
HOLDOPB_BUSLOCK_PROCESS: process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    if Rst = RESET_ACTIVE  then
      hold_buslock <= '0';
    elsif OPB_hold_buslock='1' and 
         (start_xfer='1' or opb_xfer_pend='1') and 
         OPB_MnGrant='1' then
        hold_buslock <= '1';
    elsif OPB_hold_buslock= '0' or 
            (BGO_select_i= '1'and OPB_retry= '1') then
        hold_buslock <= '0';
    end if ;
  end if;
end process HOLDOPB_BUSLOCK_PROCESS;

--  Connect OPB Signals to Transfer FIFO Outputs
BGO_DBus      <= OPB_xfer_rd_data(XFER_DBUS_START to XFER_DBUS_END);
BGO_ABus_i    <= OPB_xfer_rd_data(XFER_ABUS_START to XFER_ABUS_END);
BGO_BE_i      <= OPB_xfer_rd_data(XFER_BE_START to XFER_BE_END);
BGO_RNW_i     <= OPB_xfer_rd_data(XFER_RNW);
BGO_busLock   <= OPB_xfer_rd_data(XFER_BUSLOCK) 
            or ((timeout_last and opb_xfer_pend)) or hold_buslock;
BGO_seqAddr   <= OPB_xfer_rd_data(XFER_SEQADDR);

-------------------------------------------------------------------------------
--  Memory Output Port Control Logic. Sets the address to the memory so data
--  can be read out and transferred over OPB. When the Master is not driving
--  the OPB Bus, the memory output must be reset to all zeroes.
-------------------------------------------------------------------------------

--  enable operation of the xfer memory only when needed to save power
--  (i.e. BRAM EN should not be asserted when memory not in use)

OPB_xfer_rd_en <= '1' 
                when start_xfer='1' or opb_xfer_pend='1'
                else '0';

--  Generate read address from memory and increment when necessary so correct
--  OPB data is supplied.
xfer_rd_addr_inc <= xfer_rd_addr + 1;

RDADDR_CNTR: process (OPB_Clk)
begin
  if OPB_Clk'event and OPB_Clk = '1' then
    if opb_xfer_pend='0' or Rst = RESET_ACTIVE  then
      xfer_rd_addr <= (others => '0');
    elsif xfer_next_word='1' then
        xfer_rd_addr <= xfer_rd_addr + 1;
    end if ;
  end if;
end process ;

OPB_xfer_rd_addr <= xfer_rd_addr_inc 
                when (BGO_select_i='1' and OPB_xferAck= '1') 
                else xfer_rd_addr;
                
--  Generate reset signal to transfer memory so output from memory is cleared
--  when OPB master does not have control of the bus.
--  If any bit out of OPB_xfer_rd_data_rst1-3 is high, then clear the output
MEM_RESET: process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    rst_d1 <= Rst;
    rst_d2 <= rst_d1;
  end if;
end process MEM_RESET;

OPB_xfer_rd_data_rst1 <= (OPB_retry or (OPB_timeout and not(OPB_xferAck)));
OPB_xfer_rd_data_rst2 <= (OPB_xferAck and last_word) or 
                         (not(opb_xfer_pend) and not(OPB_xfer_start_flag));
OPB_xfer_rd_data_rst3 <= (not(OPB_MnGrant) and not(BGO_select_i) and 
                          not(timeout_last)) or rst_d2;
  
  
-------------------------------------------------------------------------------
--  Send Back Read Data/Status Flags from Current OPB Transfer Back to PLB Logic
-------------------------------------------------------------------------------
OPB_rcv_data(RCV_DBUS_START to RCV_DBUS_END) <= OPB_DBus;
OPB_rcv_data(RCV_RDWDADDR_START to RCV_RDWDADDR_END) <= BGO_ABus_i(26 to 29);
OPB_rcv_data(RCV_ERR) <= OPB_errAck or (OPB_timeout and not(OPB_xferAck));
OPB_rcv_data(RCV_LASTWRD) <= last_word;
OPB_rcv_strobe <= xfer_next_word;


-------------------------------------------------------------------------------
--  Flag Any Errors for BEAR/BESR Logic to Process
-------------------------------------------------------------------------------
ERR_REGS: process (OPB_Clk)
begin
  if (OPB_Clk'event and OPB_Clk = '1' ) then
    Err_ack_det <= BGO_select_i and OPB_xferAck and OPB_errAck;
    Err_addr <= BGO_ABus_i;
    Err_byte_enable <= BGO_BE_i;
    Err_rd_wr_n <= BGO_RNW_i;
    Timeout_det <= BGO_select_i and not(OPB_xferAck) and not(OPB_retry)
                   and OPB_timeout;
  end if;
end process ;

-------------------------------------------------------------------------------
--  Generate BGI_Trans_Abort Signal to Bridge-In
-------------------------------------------------------------------------------
--  If Bridge Out waits more than C_BGI_TRANSABORT_CNT cycles for
--  grant during a read, it asserts BGI_Trans_Abort to force bridge-In to
--  abort any read requests pending
    BGI_TRANSABORT_CNTR_PROCESS: process (OPB_Clk)
    begin
      if (OPB_Clk'event and OPB_Clk = '1' ) then
        if Rst=RESET_ACTIVE or OPB_MnGrant='1' or BGO_select_i='1' or BGO_request_i='0' then
          bgi_transabort_cntr <= (others => '0');
        elsif bgi_transabort_cntr /= BGI_TRANSABORT_CNT then
            bgi_transabort_cntr <= bgi_transabort_cntr+1;
        end if ;
      end if;
    end process BGI_TRANSABORT_CNTR_PROCESS;

    BGI_Trans_Abort_REG: process (OPB_Clk)
    begin
      if (OPB_Clk'event and OPB_Clk = '1' ) then
        if Rst=RESET_ACTIVE then
            bgi_trans_abort_i <= '0';
        --elsif bgi_transabort_cntr = BGI_TRANSABORT_CNT then
        --Add qualifier to assert only on read operations
        elsif (bgi_transabort_cntr = BGI_TRANSABORT_CNT and
               dout_XFER_RNW = '1') then
            bgi_trans_abort_i <= '1';
        else
            bgi_trans_abort_i <= '0';
        end if;
      end if;
    end process BGI_Trans_Abort_REG;
    
 BGI_Trans_abort <= bgi_trans_abort_i;
 

end ;

