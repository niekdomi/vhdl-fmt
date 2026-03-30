-------------------------------------------------------------------------------
--$Id: plb2opb_bridge_plb_if.vhd,v 1.2 2006/06/13 20:32:24 mlovejoy Exp $
------------------------------------------------------------------------------
-- PLB to OPB Bridge, PLB Interface - Module
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
-- Filename:        plb2opb_bridge_plb_if.vhd
-- Version:         v1.01a
-- Description:
--   This module is the PLB interface for the PLB to OPB Bridge. It is
--   responsible for decoding PLB transactions and generating the
--   necessary commands for the OPB to execute. It is also responsible
--   for handling read and write data transfers on the PLb side.
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
-- Author:
-- History:
--   KD         5/11/01         -- EA 2 Release
--  ALS         11/01/01        -- VHDL conversion
--  ALS         12/13/01        -- incorporated compliance test modifications
--  ALS         12/19/01        -- corrected sensitivity list for BRST_LAST process
--  ALS         01/15/02    
-- ^^^^^^
--  Modified parameters to match design spec. Incorporated design spec changes.
-- ~~~~~~
--  ALS         03/04/02    
-- ^^^^^^
--  Added C_NUM_ADDR_RNG parameter.
-- ~~~~~
--  ALS         03/13/02
-- ^^^^^^
--  Added constants and parameters.
-- ~~~~~~
--  ALS         03/19/02
-- ^^^^^
--  Added support for the C_NO_PLB_BURST parameter.
-- ~~~~~~
--      ALS     07/09/02            -- Version 1.00b
-- ^^^^^^
--  C_INCLUDE_BGI_TRANSABORT generic is no longer used.
-- ~~~~~~
--      MLL     01/09/04            -- Version 1.01a
-- ^^^^^^
--  Modify operation to make bridge operation (previously based on IBM 
--  architecture) compatible with Xilinx OPB IPIF architecture. Specifically,
--  delayed addrack on reads until data is received by bridge. Wait is asserted
--  until xferack crosses time-domain boundaries. Wait is released when OPB_retry
--  is asserted. This allows arbiter to timeout.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;
 
library unisim;
use unisim.vcomponents.all;

library plb2opb_bridge_v1_01_a;
use plb2opb_bridge_v1_01_a.plb2opb_bridge_pkg.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;
use proc_common_v1_00_b.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_plb_if is
  generic (
        C_PLB_NUM_MASTERS       : integer := 16;
        C_PLB_MID_WIDTH         : integer := 4;
        C_PLB_AWIDTH            : integer := 32;
        C_PLB_DWIDTH            : integer := 64;
        C_OPB_AWIDTH            : integer := 32;
        C_OPB_DWIDTH            : integer := 32;
        C_NUM_ADDR_RNG          : integer := 1;
        C_RNG0_BASEADDR         : std_logic_vector := X"00000000";
        C_RNG0_HIGHADDR         : std_logic_vector := X"0003FFFF"; 

        C_RNG1_BASEADDR         : std_logic_vector := X"00000000";
        C_RNG1_HIGHADDR         : std_logic_vector := X"0003FFFF"; 

        C_RNG2_BASEADDR         : std_logic_vector := X"00000000";
        C_RNG2_HIGHADDR         : std_logic_vector := X"0003FFFF"; 

        C_RNG3_BASEADDR         : std_logic_vector := X"00000000";
        C_RNG3_HIGHADDR         : std_logic_vector := X"0003FFFF"; 
        
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
        BGO_addrAck         : out std_logic ;
        BGO_MBusy           : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        BGO_MErr            : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        BGO_rearbitrate     : out std_logic ;
        BGO_SSize           : out std_logic_vector (0 to 1);
        BGO_wait            : out std_logic ;
        PLB_rdPrim          : in std_logic;
        PLB_SAValid         : in std_logic;
        PLB_wrPrim          : in std_logic;
        PLB_wrBurst         : in std_logic;
        PLB_wrDBus          : in std_logic_vector (0 to C_PLB_DWIDTH-1);
        BGO_wrBTerm         : out std_logic ;
        BGO_wrComp          : out std_logic;
        BGO_wrDAck          : out std_logic;
        PLB_rdBurst         : in std_logic;
        BGO_rdBTerm         : out std_logic ;
        BGO_rdComp          : out std_logic;
        BGO_rdDAck          : out std_logic;
        BGO_rdDBus          : out std_logic_vector(0 to C_PLB_DWIDTH-1);
        BGO_rdWdAddr        : out std_logic_vector(0 to 3 );
        PLB_xfer_abort_ack  : in std_logic;
        PLB_xfer_start_ack  : in std_logic;
        PLB_hold_buslock    : out std_logic;
        PLB_xfer_abort_flag : out std_logic ;
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
end plb2opb_bridge_plb_if;
 
-------------------------------------------------------------------------------
--  Architecture section
------------------------------------------------------------------------------- 
architecture plb2opb_bridge_plb_if of plb2opb_bridge_plb_if is

-------------------------------------------------------------------------------
-- Constant declarations
-------------------------------------------------------------------------------
constant MAX_ADDR_RNGS  : integer := 4;
type ADDR_ARRAY_TYPE is array ( 0 to MAX_ADDR_RNGS-1) of std_logic_vector(0 to C_PLB_AWIDTH-1);
constant BASEADDR_ARRAY : ADDR_ARRAY_TYPE := (C_RNG0_BASEADDR, C_RNG1_BASEADDR,
                                              C_RNG2_BASEADDR, C_RNG3_BASEADDR);
constant HIGHADDR_ARRAY : ADDR_ARRAY_TYPE := (C_RNG0_HIGHADDR, C_RNG1_HIGHADDR,
                                              C_RNG2_HIGHADDR, C_RNG3_HIGHADDR);

type DECODE_WIDTH_ARRAY_TYPE is array (0 to MAX_ADDR_RNGS-1) of integer;
constant RNG_DECODE_WIDTH : DECODE_WIDTH_ARRAY_TYPE :=
                           ( Addr_Bits(C_RNG0_BASEADDR,C_RNG0_HIGHADDR),
                             Addr_Bits(C_RNG1_BASEADDR,C_RNG1_HIGHADDR),
                             Addr_Bits(C_RNG2_BASEADDR,C_RNG2_HIGHADDR),
                             Addr_Bits(C_RNG3_BASEADDR,C_RNG3_HIGHADDR) );

constant AWIDTH_MASKED : integer := C_PLB_AWIDTH-WRD_ADDR_BITS;

-- create constants for the range address generics so that the indices of the std_logic_vector
-- are known and these vectors can be sliced. Since these generics are unconstrainted and 
-- are assigned as strings, the indices can be 1 to C_PLB_AWIDTH.
constant AWIDTH_MINUS_ONEK : integer := C_PLB_AWIDTH-ONEK_ADDR_BITS;
constant RNG0_HIGHADDR : std_logic_vector(0 to C_PLB_AWIDTH-1) := C_RNG0_HIGHADDR;
constant RNG1_HIGHADDR : std_logic_vector(0 to C_PLB_AWIDTH-1) := C_RNG1_HIGHADDR;
constant RNG2_HIGHADDR : std_logic_vector(0 to C_PLB_AWIDTH-1) := C_RNG2_HIGHADDR;
constant RNG3_HIGHADDR : std_logic_vector(0 to C_PLB_AWIDTH-1) := C_RNG3_HIGHADDR;

constant HIGHADDR_BUS   : std_logic_vector(0 to MAX_ADDR_RNGS*AWIDTH_MINUS_ONEK-1) :=
                RNG0_HIGHADDR(0 to AWIDTH_MINUS_ONEK-1) & 
                RNG1_HIGHADDR(0 to AWIDTH_MINUS_ONEK-1) & 
                RNG2_HIGHADDR(0 to AWIDTH_MINUS_ONEK-1) & 
                RNG3_HIGHADDR(0 to AWIDTH_MINUS_ONEK-1);

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
-- Signal declarations
-------------------------------------------------------------------------------
-- internal versions of output signals
signal BGO_addrAck_i            : std_logic;
signal BGO_MBusy_i              : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
signal BGO_rearbitrate_i        : std_logic;
signal BGO_wrComp_i             : std_logic;   
signal BGO_wrDAck_i             : std_logic;   
signal BGO_rdComp_i             : std_logic;   
signal BGO_rdDAck_i             : std_logic;   
signal plb_xfer_abort_flag_i    : std_logic;    
signal plb_xfer_start_flag_i    : std_logic;    
signal master_id_decode_i       : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);

signal abort_flag_hold          : std_logic;
signal addr_valid               : std_logic;
signal access_valid             : std_logic;
signal access_valid_d           : std_logic;
signal access_valid_rearb       : std_logic;
signal access_valid_rst         : std_logic;
signal addrAck                  : std_logic;
signal addrAck_d1               : std_logic;
signal addrAck_d2               : std_logic;
signal at_1k_bndry              : std_logic;
signal at_1k_bndry_d1           : std_logic;
signal at_1k_bndry_d2           : std_logic;
signal at_1k_bndry_next         : std_logic;
signal at_1k_bndry_wrbterm      : std_logic;
signal at_1k_guard_bndry        : std_logic;
signal at_1k_guard_bndry_d1     : std_logic;
signal be_decode0               : std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
signal be_decode1               : std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
signal be_decode2               : std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
signal be_decode3               : std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
signal bndry_ABus_reg           : std_logic_vector(0 to 7 ); --??
signal bndry_PLB_ABus           : std_logic_vector(0 to 7 ); --??
signal brst_cnt                 : std_logic_vector(0 to 3 ); -- largest fixed burst is 16
signal brst_last                : std_logic;
signal brst_last_ce             : std_logic;
signal brst_last_d              : std_logic;
signal brst_last_rst            : std_logic;
signal brst_last_set            : std_logic;
signal brst_len                 : std_logic_vector(0 to 3 ); -- largest fixed burst is 16
signal brst_len_eq_zero1        : std_logic;
signal brst_len_eq_zero2        : std_logic;
signal brst_len_eq_zero3        : std_logic;
signal brst_len_eq_zero4        : std_logic;
signal brst_len_eq_zero         : std_logic;
signal brst_len0                : std_logic_vector(0 to 3 );
signal brst_len1                : std_logic_vector(0 to 3 );
signal brst_len2                : std_logic_vector(0 to 3 );
signal brst_len3                : std_logic_vector(0 to 3 );
signal burst_or_line_xfer       : std_logic ;
signal busy                     : std_logic;
signal busy_on                  : std_logic;
signal byte_addr_hi             : std_logic_vector(0 to 1 );
signal byte_addr_lo             : std_logic_vector(0 to 1 );
signal byte_addr                : std_logic_vector(0 to 1 );
signal cs                       : std_logic_vector(0 to C_NUM_ADDR_RNG-1);
signal end_of_wr_burst          : std_logic;
signal err_detect               : std_logic;
signal guarded_i                : std_logic;
signal master_rd_abort          : std_logic;
signal mbusy_clr                : std_logic;
signal msize                    : std_logic_vector(0 to 1 );
signal muxcy_o1                 : std_logic;
signal muxcy_o2                 : std_logic;
signal opb_ABus                 : std_logic_vector(0 to C_OPB_AWIDTH-1);
signal opb_ABus_inc             : std_logic_vector(0 to AWIDTH_MASKED);
signal opb_ABus_next            : std_logic_vector(0 to AWIDTH_MASKED);
signal opb_ABus_reg             : std_logic_vector(0 to AWIDTH_MASKED);
signal opb_BE                   : std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
signal opb_busLock              : std_logic;
signal opb_DBus                 : std_logic_vector(0 to C_OPB_DWIDTH-1);
signal opb_last_data            : std_logic;
signal opb_RNW                  : std_logic;
signal opb_RNW_n                : std_logic;
signal opb_seqAddr              : std_logic;
signal plb_abus_masked          : std_logic_vector(0 to AWIDTH_MASKED);
signal plb_size_masked          : std_logic_vector(0 to 3);
signal plb_rdburst_masked       : std_logic;
signal plb_wrburst_masked       : std_logic;
signal PLB_wrBurst_d1           : std_logic;
signal PLB_wrBurst_d2           : std_logic;
signal plb_wrDBus_d1            : std_logic_vector(0 to C_PLB_DWIDTH-1);
signal plb_xfer_strobe_rd       : std_logic;
signal plb_xfer_strobe_wr       : std_logic;
signal plb_xfer_strobe_wr_d1    : std_logic;
signal rd_busy                  : std_logic;
signal rdComp_com               : std_logic;
signal rdDAck_com               : std_logic;
signal rcv_last_write_status    : std_logic;
signal selected_high_addr       : std_logic_vector(0 to C_PLB_AWIDTH-ONEK_ADDR_BITS-1);
signal size                     : std_logic_vector(0 to 3 );
signal BGO_wrComp_d             : std_logic;
signal BGO_wrComp_rst           : std_logic;
signal BGO_wrComp_set           : std_logic;
signal start_flag_hold          : std_logic;
signal stop_rdburst             : std_logic;
signal stop_rdburst_d1          : std_logic;
signal stop_wrburst             : std_logic;
signal stop_wrburst_d1          : std_logic;
signal valid_term1              : std_logic;
signal valid_term2              : std_logic;
signal valid_term3              : std_logic_vector(0 to 0);
signal wr_active                : std_logic;
signal wr_busy                  : std_logic;
signal wrBTerm_if_PAValid       : std_logic;
signal wrBTerm_if_PAValid_d     : std_logic;
signal wrBTerm_if_PAValid_rst   : std_logic;
signal wrBTerm_if_PAValid_set   : std_logic;
signal xfer_cntr_expires        : std_logic;
signal xfer_is_32               : std_logic;
signal xfer_is_wr_burst         : std_logic;
signal xfer_qual_load_en        : std_logic;
  
  
-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
component plb2opb_bridge_srl16x30
    generic(C_DATA_WIDTH : integer := 30);
      port (
            Clk     : in std_logic ;
            D       : in std_logic_vector(0 to C_DATA_WIDTH-1);
            Q       : out std_logic_vector(0 to C_DATA_WIDTH-1);
            A1      : in std_logic 
            );
end component;

-- PSELECT is used to decode the upper address bits
component pselect is
  
  generic (
    C_AB     : integer := 9;
    C_AW     : integer := 32;
    C_BAR    : std_logic_vector
    );
  port (
    A        : in   std_logic_vector(0 to C_AW-1);
    AValid   : in   std_logic;
    CS       : out  std_logic
    );
end component pselect;

component or_gate 
  generic (
    C_OR_WIDTH   : natural range 1 to 32 := 17;
    C_BUS_WIDTH  : natural range 1 to 64 := 1;
    C_USE_LUT_OR : boolean := TRUE
    );
  port (
    A : in  std_logic_vector(0 to C_OR_WIDTH*C_BUS_WIDTH-1);
    Y : out std_logic_vector(0 to C_BUS_WIDTH-1)
    );
end component or_gate;

component mux_onehot 
   generic( C_DW: integer := 32;
            C_NB: integer := 5 );
   port(
      D: in std_logic_vector(0 to C_DW*C_NB-1);
      S: in std_logic_vector(0 to C_NB-1);
      Y: out std_logic_vector(0 to C_DW-1));

end component mux_onehot;


-------------------------------------------------------------------------------
--  Begin architecture
-------------------------------------------------------------------------------
--  unused PLB inputs: (and reasons why)
--  PLB_compress - don't use this attribute
--  PLB_ordered  - all transactions are completed in order anyways
--  PLB_rdPrim   - don't acknowledge secondary read requests
--  PLB_wrPrim   - don't acknowledge secondary write requests

begin
 
  PLB_xfer_abort_flag   <= plb_xfer_abort_flag_i;
  BGO_rearbitrate       <= BGO_rearbitrate_i;
  BGO_wrComp            <= BGO_wrComp_i;
  BGO_wrDAck            <= BGO_wrDAck_i;
  BGO_MBusy             <= BGO_MBusy_i;
  Master_id_decode      <= master_id_decode_i;
  PLB_xfer_start_flag   <= plb_xfer_start_flag_i;
  BGO_addrAck           <= BGO_addrAck_i;
  BGO_rdComp            <= BGO_rdComp_i;
  BGO_rdDAck            <= BGO_rdDAck_i;

-- If C_NO_PLB_BURST = 1, then
-- mask PLB_size(0) to 0 so that logic is reduced in synthesis (plb_size_masked).
-- Also mask PLB_wrBurst and PLB_rdBurst to 0.
-- If C_NO_PLB_BURST = 0 , the plb_size_masked = PLB_size, plb_rdburst_masked
-- = PLB_rdBurst and plb_wrburst_masked = PLB_wrBurst.
PLB_SIZE_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
    plb_size_masked <= '0'& PLB_size(1 to 3);
    plb_wrburst_masked <= '0';
    plb_rdburst_masked <= '0';
end generate PLB_SIZE_NOBURST_GEN;
PLB_SIZE_BURST_GEN: if C_NO_PLB_BURST=0 generate
    plb_size_masked <= PLB_size;
    plb_wrburst_masked <= PLB_wrBurst;
    plb_rdburst_masked <= PLB_rdBurst;
end generate PLB_SIZE_BURST_GEN;
 
-------------------------------------------------------------------------------
--  Look For Valid Transaction Requests
-------------------------------------------------------------------------------
--  Comparators check if the PLB address is between the upper and lower address
--  limits specified by the user parameters. Additional logic looks to see if
--  the PLB size and type values are also valid. The address and qualifier
--  checking takes a full clock cycle and asserts "access_valid" to allow
--  the Bridge to accept the transaction on the next cycle.
--  Changes to the plb2opb bridge to be compatible with the IPIF M/S
--  architecture was based on "access_valid" taking a full clock AFTER
--  PLB_PAValid was asserted. 061306 the CE for access_valid register was
--  qualified with PLB_PAValid being asserted.
-------------------------------------------------------------------------------              
--  Check PLB Transfer Qualifier
--  Address and Qualifier Decode is in the critical path so the logic terms
--  that help decode valid transaction requests must be carefully structured
VALIDTERM1_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
    -- only accept nonburst and nonreserved size values
    valid_term1 <= '1' when ((PLB_size(0 to 1) /= "01")) and 
                    ((PLB_size(0) /= '1'))
                else '0';    
end generate VALIDTERM1_NOBURST_GEN;
VALIDTERM1_BURST_GEN: if C_NO_PLB_BURST=0 generate
    -- only accept non reserved size values
    valid_term1 <= '1' when ((PLB_size(0 to 1) /= "01")) and 
                    ((PLB_size(0 to 2) /= "111"))
                else '0';      
end generate VALIDTERM1_BURST_GEN;                
valid_term2 <= '1' when ((PLB_type(0 to 2) = "000"))
                else '0';  --  check type is memory

addr_valid <= (PLB_PAValid or PLB_SAValid);

-- decode the address for the used address ranges
PSELECTS_GEN: for i in 0 to C_NUM_ADDR_RNG-1 generate
        PLB_RNG_PSELECT_I: pselect
            generic map (C_AB   => RNG_DECODE_WIDTH(i),
                         C_AW   => C_PLB_AWIDTH,
                         C_BAR  => BASEADDR_ARRAY(i))
            port map (A         => PLB_ABus,
                      AValid    => addr_valid,
                      CS        => cs(i));
end generate PSELECTS_GEN;

-- OR together the chip selects from the different address ranges
CS_OR_I: or_gate 
  generic map(
                C_OR_WIDTH   => C_NUM_ADDR_RNG,
                C_BUS_WIDTH  => 1,
                C_USE_LUT_OR => TRUE
                )
  port map (
            A => cs(0 to C_NUM_ADDR_RNG-1),
            Y => valid_term3
    );

--  The next set of muxcy instantiations are equivalent to:
--  assign access_valid_d = valid_term1 & valid_term2 & valid_term3;
MUXCY1_I: MUXCY
  port map (
            O   => muxcy_o1,        --[out]
            CI  => '1',             --[in]
            DI  => '0',             --[in]
            S   => valid_term1      --[in]
            );

MUXCY2_I: MUXCY
  port map (
            O   => muxcy_o2,        --[out]
            CI  => muxcy_o1,        --[in]
            DI  => '0',             --[in]
            S   => valid_term2      --[in]
            );
MUXCY3_I: MUXCY
  port map (
            O   => access_valid_d,  --[out]
            CI  => muxcy_o2,        --[in]
            DI  => '0',             --[in]
            S   => valid_term3(0)   --[in]
            );


access_valid_rst <=  '1'
            when BGO_addrAck_i='1' or PLB_abort='1' 
                or Rst=RESET_ACTIVE or BGO_rearbitrate_i='1'
            else '0';

-- register access_valid
ACCESS_VALID_REG: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if (access_valid_rst or busy)='1' then
        access_valid <= '0';
    elsif(PLB_PAValid = '1') then
        access_valid <= access_valid_d;
    end if ;
  end if;
end process ;


ACCESS_VALID_REARB_REG: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if access_valid_rst ='1' then
        access_valid_rearb <= '0';
    else
        access_valid_rearb <= access_valid_d;
    end if;
  end if ;
end process ;

SEL_HIGHADDR_GEN: if C_NO_PLB_BURST=0 generate
    -- determine the current selected high address
    SELECTED_HIGH_ADDR_MUX: mux_onehot  
       generic map( C_DW => AWIDTH_MINUS_ONEK ,
                    C_NB => C_NUM_ADDR_RNG)
       port map(
                --    D   => HIGHADDR_BUS(0 to C_NUM_ADDR_RNG*(C_PLB_AWIDTH-ONEK_ADDR_BITS)-1),
                    D   => HIGHADDR_BUS(0 to C_NUM_ADDR_RNG*AWIDTH_MINUS_ONEK-1),
                    S   => cs,
                    Y   => selected_high_addr);
end generate SEL_HIGHADDR_GEN;                    

NOSEL_HIGHADDR_GEN: if C_NO_PLB_BURST /= 0 generate
    selected_high_addr <= (others => '0');
end generate NOSEL_HIGHADDR_GEN;    
-------------------------------------------------------------------------------
--  AddrAck, Rearbitrate, SSize, and Wait
-------------------------------------------------------------------------------
BGO_addrAck_i <= PLB_PAValid and access_valid and not(busy);
GEN_32BIT_SLAVE: if C_PLB_DWIDTH = 32 generate
    BGO_SSize <= (others => '0');
end generate GEN_32BIT_SLAVE;
GEN_64BIT_SLAVE: if C_PLB_DWIDTH = 64 generate
    BGO_SSize(0 to 1) <= '0' & BGO_addrAck_i;
end generate GEN_64BIT_SLAVE;

            --Fix to make compatible with IPIF architecture
--BGO_rearbitrate_i <= PLB_PAValid and access_valid_rearb and busy;
BGO_rearbitrate_i <= PLB_PAValid and access_valid_rearb and
                     (busy and not(Block_BGO_rearbitrate));
BGO_wait <= '0';

--  Compute PLB addrAck qualified by PLB Abort
addrAck <= PLB_PAValid and access_valid and not(busy) and not(PLB_abort);
ADDRACK_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst=RESET_ACTIVE then
        addrAck_d1 <= '0';
        addrAck_d2 <= '0';
    else
        addrAck_d1 <= addrAck;
        addrAck_d2 <= addrAck_d1;
    end if ;
  end if;
end process ;

-------------------------------------------------------------------------------
--  Logic to generate OPB signals required by the transaction
-------------------------------------------------------------------------------
--  The Write Data and Transaction Qualifiers used by the OPB Master are
--  computed by decoding the PLB information. The OPB signals are then
--  pipelined and can later be loaded into a BRAM or DPRAM based FIFO.
--  The OPB signals generated are essentially a set of vectors that can
--  just be fed out over OPB with minimal processing on the OPB side.
-------------------------------------------------------------------------------
xfer_qual_load_en <= ((not(PLB_PAValid) or not(access_valid))) and not(busy);

--  Generate OPB Read/Write flag 
OPBRNW_PROCESS: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst = RESET_ACTIVE then
        opb_RNW <= '0';
        msize <= (others => '0');
    elsif (xfer_qual_load_en)='1' then
        opb_RNW <= PLB_RNW;
        msize <= PLB_MSize;
    end if ;
  end if;
end process ;

--  Determine if data transferred over data bus arrives at 32 or 64 bits at
--  a time. 32 bit xfer if (MSize == 00) or (Size = 8,9,10) or
--  (Size = 0 and BE/ABus says that only 1 word is xferred)
PLB32_XFERIS32_GEN: if C_PLB_DWIDTH = 32 generate
    xfer_is_32 <= '1';
end generate PLB32_XFERIS32_GEN;
PLB64_XFERIS32_NOBURST_GEN: if  C_PLB_DWIDTH=64 and C_NO_PLB_BURST=1 generate
    XFERIS32_REG: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if xfer_qual_load_en = '1' then
            if PLB_MSize= "00" then
                xfer_is_32 <= '1';
            elsif (plb_size_masked = "0000" and 
               (PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS)='1' or 
                    PLB_BE(C_PLB_DWIDTH/16 to C_PLB_DWIDTH/8-1) = "0000")) then
                xfer_is_32 <= '1';
            else
                xfer_is_32 <= '0';
            end if;
        end if;
     end if;
    end process ;
end generate PLB64_XFERIS32_NOBURST_GEN;   
PLB64_XFERIS32_BURST_GEN: if  C_PLB_DWIDTH=64 and C_NO_PLB_BURST=0 generate
    XFERIS32_REG: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if xfer_qual_load_en = '1' then
            if PLB_MSize= "00" then
                xfer_is_32 <= '1';
            elsif ((plb_size_masked(0 to 1) = "10" and plb_size_masked(2 to 3) /= "11") or
                   (plb_size_masked = "0000" and 
                   (PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS)='1' or PLB_BE(C_PLB_DWIDTH/16 to C_PLB_DWIDTH/8-1) = "0000"))) then
                xfer_is_32 <= '1';
            else
                xfer_is_32 <= '0';
            end if;
        end if;
     end if;
    end process ;
end generate PLB64_XFERIS32_BURST_GEN;   
    

--  Generate OPB Byte Enables 
--  gen byte enables for size 0-7 (note that BE for size 4-7 is don't care)
BYTE_DECODE0_GEN: for i in 0 to C_PLB_DWIDTH/8 -1 generate
        be_decode0(i) <= '1' when (plb_size_masked(0)='0' and (PLB_BE(i) = '1' or (plb_size_masked(2 to 3) /= "00")))
                        else '0';
end generate BYTE_DECODE0_GEN;

BYTE_DECODE_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
    OPB_BE_REG: process (Clk)
    begin
      if(Clk'event and Clk = '1' ) then
        if Rst = RESET_ACTIVE then
            opb_BE <= (others => '0');
        elsif (xfer_qual_load_en)='1' then
            opb_BE <= be_decode0;
        end if ;
      end if;
    end process OPB_BE_REG;
end generate BYTE_DECODE_NOBURST_GEN;   

BYTE_DECODE_BURST_GEN: if C_NO_PLB_BURST = 0 generate    
    --  gen byte enables for size 8 (8 bit byte bursts)
    BYTE_DECODE1_GEN: for i in 0 to C_PLB_DWIDTH/16 -1 generate
        be_decode1(i) <= '1' 
            when (plb_size_masked(0)='1' and PLB_ABus(C_OPB_AWIDTH-2 to C_OPB_AWIDTH-1) = i)
            else '0';
        be_decode1(i+4) <= be_decode1(i);
    end generate BYTE_DECODE1_GEN;

    --  gen byte enables for size 9 (16 bit halfword bursts)
    BYTE_DECODE2_GEN: for i in 0 to C_PLB_DWIDTH/32 -1 generate
        -- bits 0,1,4,5 = '1' when even halfword (A(30)=0)
        be_decode2(i*4 to i*4+1) <= "11"  
                when (plb_size_masked(0)='1' and plb_size_masked(3)='1' and PLB_ABus(30)='0')
               else (others => '0'); 
        -- bits 2,3,6,7 ='1' when odd halfword (A(30)=1)
        be_decode2(i*4+2 to i*4+3) <= "11" 
                when (plb_size_masked(0)='1' and plb_size_masked(3)='1' and PLB_ABus(30)='1')
               else (others => '0'); 
    end generate BYTE_DECODE2_GEN;

    --  gen byte enables for size 10-15 (note that BE for size 14-15 is don't care)
    be_decode3(0 to C_PLB_DWIDTH/8-1) <= (others => '1') 
                when plb_size_masked(0)='1' and (plb_size_masked(1)='1' or plb_size_masked(2)='1')
                else (others => '0');

    OPB_BE_REG: process (Clk)
    begin
      if(Clk'event and Clk = '1' ) then
        if Rst = RESET_ACTIVE then
            opb_BE <= (others => '0');
        elsif (xfer_qual_load_en)='1' then
            opb_BE <= be_decode0 or be_decode1 or be_decode2 or be_decode3;
        end if ;
      end if;
    end process ;
end generate BYTE_DECODE_BURST_GEN;    

--  Generate OPB Addresses 
--  lowest 4 bits of word address may need to be masked off to zero
--  if a cacheline read occurs since OPB reads are not target word first
plb_abus_masked(0 to C_PLB_AWIDTH-OCTWRD_ADDR_BITS-1) <= PLB_ABus(0 to C_PLB_AWIDTH-OCTWRD_ADDR_BITS-1);

--  mask off for 16 word lines
plb_abus_masked(C_PLB_AWIDTH-OCTWRD_ADDR_BITS) <= PLB_ABus(C_PLB_AWIDTH-OCTWRD_ADDR_BITS) and 
        not(not(plb_size_masked(0)) and plb_size_masked(2) and plb_size_masked(3));      
--  mask off for 8/16 word lines
plb_abus_masked(C_PLB_AWIDTH-QUADWRD_ADDR_BITS) <= PLB_ABus(C_PLB_AWIDTH-QUADWRD_ADDR_BITS) and 
                        not(not(plb_size_masked(0)) and plb_size_masked(2));  
--  mask off for 4/8/16 word lines
plb_abus_masked(C_PLB_AWIDTH-DBLWRD_ADDR_BITS) <= PLB_ABus(C_PLB_AWIDTH-DBLWRD_ADDR_BITS) and 
                    not(not(plb_size_masked(0)) and ((plb_size_masked(2) or plb_size_masked(3))));     
--  mask off for 4/8/16 word lines
plb_abus_masked(C_PLB_AWIDTH-WRD_ADDR_BITS) <= PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS) and 
        not(not(plb_size_masked(0)) and ((plb_size_masked(2) or plb_size_masked(3)))); 
        
--  compute if next OPB addr is loaded from PLB or incremented from current val
opb_ABus_inc(0 to AWIDTH_MASKED) <= opb_ABus_reg(0 to AWIDTH_MASKED) + 1;
opb_ABus_next(0 to AWIDTH_MASKED) <= opb_ABus_inc(0 to AWIDTH_MASKED) 
                        when (BGO_addrAck_i = '1' or busy ='1') 
                        else plb_abus_masked(0 to AWIDTH_MASKED);

OPB_ABUS_REG_PROCESS: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    opb_ABus_reg(0 to AWIDTH_MASKED) <= opb_ABus_next(0 to AWIDTH_MASKED);
  end if;
end process OPB_ABUS_REG_PROCESS;

opb_RNW_n <= not(opb_RNW);

--  Use SRL to allow pipeline delay on opb_ABus to be varied between 1 and 3
OPB_ABUS_SRL_I: plb2opb_bridge_srl16x30
    generic map( C_DATA_WIDTH => AWIDTH_MASKED+1)
    port map (
                A1  => opb_RNW_n,                              --  I
                Clk => Clk,                                    --  I
                D   => opb_ABus_next(0 to AWIDTH_MASKED),      --  I[0:29]
                Q   => opb_ABus(0 to AWIDTH_MASKED));          --  O[0:29]



--  flag if the OPB address is on a 1K boundary (opb_ABus[22:29] == 8'hFE).
--  If so, bursts will need to be terminated if the region is guarded
-- Flag 1K for OPB addresses that are on 1K double word boundary
-- Flag 1K for PLB addresses that are on a 1K word boundary
BNDRY_1K_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if BGO_addrAck_i = '1' or busy = '1' then
        if opb_ABus_reg(C_OPB_AWIDTH-ONEK_ADDR_BITS to C_OPB_AWIDTH-WRD_ADDR_BITS) = x"FE" then
            at_1k_bndry <= '1';
        else    
            at_1k_bndry <= '0';
        end if;
    else
        if PLB_Abus(C_PLB_AWIDTH-ONEK_ADDR_BITS to C_PLB_AWIDTH-WRD_ADDR_BITS) = x"FF" then
            at_1k_bndry <= '1';
        else
            at_1k_bndry <= '0';
        end if;
    end if;
    if (xfer_qual_load_en)='1' then
        at_1k_bndry_d1 <= '0';
        at_1k_bndry_d2 <= '0';
    else
        at_1k_bndry_d1 <= at_1k_bndry;
        at_1k_bndry_d2 <= at_1k_bndry_d1;
    end if ;
  end if;
end process BNDRY_1K_REG;

BEADDR_NOTEQUAL_DWIDTHS: if C_OPB_DWIDTH=32 and C_PLB_DWIDTH=64 generate
    --  lower two address bits depend on byte enable values and word addr[29]
    BYTE_ADDR8_PROCESS: process (opb_BE)
    begin
        if opb_BE(4) = '1' then 
            byte_addr_hi <= "00";
        elsif opb_BE(5) = '1' then
            byte_addr_hi <= "01";
        elsif opb_BE(6) = '1' then
            byte_addr_hi <= "10";
        else
            byte_addr_hi <= "11";
        end if;

        if opb_BE(0) = '1' then
            byte_addr_lo <= "00";
        elsif opb_BE(1) = '1' then
            byte_addr_lo <= "01";
        elsif opb_BE(2) = '1' then
            byte_addr_lo <= "10";
        else
            byte_addr_lo <= "11";
        end if;
    end process BYTE_ADDR8_PROCESS;
      
    opb_ABus(C_OPB_AWIDTH-2 to C_OPB_AWIDTH-1) <= byte_addr_hi when opb_ABus(C_OPB_AWIDTH-WRD_ADDR_BITS)='1' 
                    else byte_addr_lo;
end generate BEADDR_NOTEQUAL_DWIDTHS;  

BEADDR_EQUAL_DWIDTHS: if C_OPB_DWIDTH = 32 and C_PLB_DWIDTH=32 generate
    --  lower two address bits depend on byte enable values
    BYTE_ADDR4_PROCESS: process (opb_BE)
    begin
        if opb_BE(0) = '1' then
            byte_addr <= "00";
        elsif opb_BE(1) = '1' then
            byte_addr <= "01";
        elsif opb_BE(2) = '1' then
            byte_addr <= "10";
        else
            byte_addr <= "11";
        end if;
    end process BYTE_ADDR4_PROCESS;
    
    opb_ABus(C_OPB_AWIDTH-2 to C_OPB_AWIDTH-1) <= byte_addr;
    
end generate  BEADDR_EQUAL_DWIDTHS;
        

--  Generate OPB Write Data 
--  just pipeline in data from PLB to improve timing, mask off to zero on reads
PLBDATA_PIPE: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if wr_busy='0' then  
        plb_wrDBus_d1 <= (others => '0');
    elsif BGO_wrDAck_i='1' then
        plb_wrDBus_d1 <= PLB_wrDBus;
    end if ;
  end if;
end process ;

-- Generate OPB dbus based on the size of the PLB Dbus
WRDATA_EQUAL_DWIDTHS: if C_OPB_DWIDTH = 32 and C_PLB_DWIDTH=32 generate
    opb_DBus <= plb_wrDBus_d1;
end generate WRDATA_EQUAL_DWIDTHS;

WRDATA_NOTEQUAL_DWIDTHS: if C_OPB_DWIDTH=32 and C_PLB_DWIDTH=64 generate
    opb_DBus <= plb_wrDBus_d1(C_PLB_DWIDTH/2 to C_PLB_DWIDTH-1) 
                    when (opb_ABus(C_OPB_AWIDTH-WRD_ADDR_BITS)='1' and xfer_is_32 = '0') 
                    else plb_wrDBus_d1(0 to C_PLB_DWIDTH/2-1);
end generate WRDATA_NOTEQUAL_DWIDTHS;

-------------------------------------------------------------------------------
--  Generate control signals into PLB<->OPB Async Interface module
-------------------------------------------------------------------------------
--  This group of logic controls the loading of data into the FIFO going
--  over to the OPB side. It controls the number of OPB cycles to be requested
--  and sets the appropriate busLock and seqAddr bits.
-------------------------------------------------------------------------------
--  Calculate OPB Burst Length 
--  Compute number of OPB bus cycles to generate depending on the
--  transfer qualifiers. (brst_len = 0 is for a 1-word transfer,
--  brst_len = 15 is for a 16-word transfer)


BRST_LEN_PROCESS: process(plb_size_masked, PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS), PLB_BE, PLB_MSize)
begin

    --  compute length of transfer if size = 0   : Non-Burst
    brst_len0(0 to 2) <= "000";
    if C_PLB_DWIDTH = 64 then
        if plb_size_masked = "0000" and PLB_MSize /= "00" and PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS) = '0' and
            (or_reduce(PLB_BE(4 to 7)) = '1') then
                brst_len0(3) <= '1';
        else
                brst_len0(3) <= '0';
        end if;
    else
        brst_len0(3) <= '0';
    end if;
    
    --  compute length of transfer if size = 1-3 : 4-8-16 Cacheline
    --  (len for size 4-7 is don't care)
    
    if plb_size_masked(0) = '0' then
        if plb_size_masked(2 to 3) = "11" then
            brst_len1(0) <= '1';
        else
            brst_len1(0) <= '0';
        end if;
        if plb_size_masked(2) = '1' then
            brst_len1(1) <= '1';
        else
            brst_len1(1) <= '0';
        end if;
        if plb_size_masked(2 to 3) /= "00" then
            brst_len1(2 to 3) <= "11";
        else
            brst_len1(2 to 3) <= "00";
        end if;
    else
        brst_len1 <= (others => '0');
    end if;

    -- if bursts are not supported, brst_len2 an brst_len3 are 0
    -- otherwise, length of transfer always zero if size = 8-9 : Byte-Halfword Burst
    --  (byte/halfword burst are terminated after one data transfer)
    
    if C_NO_PLB_BURST = 1 then
        brst_len2 <= (others => '0');
        brst_len3 <= (others => '0');
    else
        --  compute length of transfer if size = 10  : Word Burst
        if plb_size_masked = "1010" then
            if PLB_BE(0 to 3) = "0000" then
                brst_len2 <= (others => '1');
            else
                brst_len2 <= PLB_BE(0 to 3);
            end if;
        else
            brst_len2 <= (others => '0');
        end if;

        --  compute length of transfer if size = 11-13 : Double Word Burst
        --  (len for size 14-15 is don't care), quad/octal burst will terminate early

        for i in 0 to 2 loop
           if plb_size_masked(0)='1' and 
               (plb_size_masked(1) = '1' or (and_reduce(plb_size_masked(2 to 3)) = '1')) and
               ((PLB_BE(i+1)='1') or (PLB_BE(0) = '1') or (PLB_BE(0 to 3)="0000")) then
               brst_len3(i) <= '1';
           else
               brst_len3(i) <= '0';
           end if;      
        end loop;
        if plb_size_masked(0)='1' and 
                (plb_size_masked(1) = '1' or (and_reduce(plb_size_masked(2 to 3)) = '1')) then
                brst_len3(3) <= '1';
        else
                brst_len3(3) <= '0';
        end if; 
    end if;
    
end process;        

-------------------------------------------------------------------------------
--  Logic to Count Data Beats 
-------------------------------------------------------------------------------
BURSTLEN_ZERO_PROCESS: process(plb_size_masked, PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS), 
                               PLB_BE, PLB_MSize)
--  flag when burst length is zero since it means burst ends right away
--  burst_len can be zero when size = 0,8,or 9, or when bursts are not supported
begin
    if C_NO_PLB_BURST = 1 then
        brst_len_eq_zero1 <= '0';
    else
        if plb_size_masked(0 to 2) = "100" then
            brst_len_eq_zero1 <= '1';
        else
            brst_len_eq_zero1 <= '0';
        end if;
    end if;
    
    if plb_size_masked = "0000" then
        brst_len_eq_zero2 <= '1';
    else
        brst_len_eq_zero2 <= '0';
    end if;
    --  32 bit master or upper word addressed    

    if PLB_ABus(C_PLB_AWIDTH-WRD_ADDR_BITS) = '1' or PLB_MSize = "00" then
        brst_len_eq_zero3 <= '1';
    else
        brst_len_eq_zero3 <= '0';    
    end if;
    
    if C_PLB_DWIDTH=32 then
        brst_len_eq_zero4 <= '1';
    else
        --  no byte enables in upper word active
        if PLB_BE(4 to 7) = "0000" then 
            brst_len_eq_zero4 <= '1';
        else
            brst_len_eq_zero4 <= '0';   
        end if;
    end if;
end process BURSTLEN_ZERO_PROCESS;

brst_len_eq_zero <= (brst_len_eq_zero1) or 
                    (brst_len_eq_zero2 and (brst_len_eq_zero3 or brst_len_eq_zero4));
                        
    
--  latch length, size and guarded attributes since this information is needed
--  by logic that generates OPB transactions and counts data beats
PLBATTR_BRSTCNT_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
        
    PLB_ATTR_PROCESS: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if Rst = RESET_ACTIVE then
            brst_len <= (others => '0');
            size <= (others => '0');
        elsif (xfer_qual_load_en)='1' then
            -- brst_len is a pipeline register containing 
            -- ((num_words_to_transfer) - 1)
            brst_len <= brst_len0 or brst_len1 or brst_len2 or brst_len3;
            size <= plb_size_masked;
        end if ;
     end if;
    end process PLB_ATTR_PROCESS;

    guarded_i <= '0';   -- no bursts, therefore guarded is 0

    -- since no bursts, stop read/write burst signals =0
    stop_rdburst <= '0';
    stop_rdburst_d1 <= '0';
    stop_wrburst <= '0';
    stop_wrburst_d1 <= '0';

    --  count data beats for read bursts. 
    BRSTCNT_PROCESS: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if Rst = RESET_ACTIVE then
            brst_cnt <= "0000";
         elsif (addrAck)='1' then
                brst_cnt <= brst_len;
         elsif brst_cnt /= "0000" then
               brst_cnt <= brst_cnt - 1;
         end if ;
      end if ;
    end process BRSTCNT_PROCESS ;
    
end generate PLBATTR_BRSTCNT_NOBURST_GEN;

PLBATTR_BRSTCNT_BURST_GEN: if C_NO_PLB_BURST=0 generate
    PLB_ATTR_PROCESS: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if (xfer_qual_load_en)='1' then
            -- brst_len is a pipeline register containing 
            -- ((num_words_to_transfer) - 1)
            brst_len <= brst_len0 or brst_len1 or brst_len2 or brst_len3;
            --  transfer considered guarded if burst transfer approaches upper
            --  address boundary of bridge. This causes bursts to be terminated before
            --  crossing the slave's address boundaries
            -- selected_high_addr contains the currently accessed high address range
            if plb_size_masked(0) = '1' and 
                (PLB_guarded = '1' or 
                (PLB_ABus(0 to C_PLB_AWIDTH-ONEK_ADDR_BITS-1) = 
                            selected_high_addr(0 to C_PLB_AWIDTH-ONEK_ADDR_BITS-1))) then
                guarded_i <= '1';
            else
                guarded_i <= '0';
            end if;
            size <= plb_size_masked;
        end if ;
     end if;
    end process PLB_ATTR_PROCESS;

    --  terminate burst if master negates rd/wr Burst and xfer is burst (size[0]=1)
    stop_rdburst <= size(0) and opb_RNW and busy and not(plb_rdburst_masked);
    stop_wrburst <= size(0) and not(opb_RNW) and not(plb_wrburst_masked) 
                    and ((xfer_is_32 or opb_ABus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS)));
    BURSTTERM_PROCESS: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if xfer_qual_load_en='1' then
            stop_rdburst_d1 <= '0';
            stop_wrburst_d1 <= '0';
        else
            stop_rdburst_d1 <= stop_rdburst;
            stop_wrburst_d1 <= stop_wrburst;
        end if ;
      end if;
    end process BURSTTERM_PROCESS;

    --  count data beats for read bursts. When region is guarded and at the 1K
    --  address boundary, the burst must be terminated
    BRSTCNT_PROCESS: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if stop_rdburst_d1 = '1'  or stop_wrburst_d1 = '1' 
            or Rst = RESET_ACTIVE or 
            (guarded_i = '1' and at_1k_bndry = '1') then
            brst_cnt <= "0000";
         elsif (addrAck)='1' then
                brst_cnt <= brst_len;
         elsif brst_cnt /= "0000" then
               brst_cnt <= brst_cnt - 1;
         end if ;
      end if ;
    end process BRSTCNT_PROCESS ;

end generate PLBATTR_BRSTCNT_BURST_GEN;    

-------------------------------------------------------------------------------
--  Generate OPB busLock, seqAddr, last data flag 
-------------------------------------------------------------------------------
--  detect the end of a burst (should map to FDRSE to minimize logic levels)
WRBURST_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
    plb_wrburst_d1 <= '0';
    plb_wrburst_d2 <= '0';


    BRSTLAST_CTRL: process(xfer_qual_load_en, brst_len_eq_zero, Rst, size(0),
                            OPB_RNW, brst_len, brst_cnt,addrAck, opb_Abus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS),
                            plb_wrburst_masked, PLB_wrBurst_d1, plb_rdburst_masked, busy, xfer_is_32)
    begin

        if (xfer_qual_load_en='1' and brst_len_eq_zero='0') or
            Rst = RESET_ACTIVE then
            brst_last_rst <= '1';
        else
            brst_last_rst <= '0';
        end if;

        if (xfer_qual_load_en='1' and brst_len_eq_zero='1') or
            (OPB_RNW='1' and (brst_len = "0001" or brst_cnt = "0010")) or
            (OPB_RNW='0' and (addrAck = '0' and brst_cnt = "0000")) then
            brst_last_set <= '1';
        else
            brst_last_set <= '0';
        end if;

        brst_last_d <= '0';
        brst_last_ce <= '0';
        
    end process  BRSTLAST_CTRL;

    BRSTLAST_REG: process (Clk)
    begin
      if (Clk'event and Clk = '1' )then
        if (brst_last_rst)='1' then
          brst_last <= '0';
        elsif (brst_last_set)='1' then
            brst_last <= '1';
        end if ;
      end if ;
    end process BRSTLAST_REG;

    opb_last_data <=  brst_last;

    --  seqAddr asserted except for last xfer. Also off when size = 0 (single)
    -- size(0) is hard coded to 0 so it doesn't need to be checked.
    -- since size values 4 -7 are reserved, don't need to check size(1)
    burst_or_line_xfer <= size(2) or size(3);

    opb_seqAddr <= not(opb_last_data) and burst_or_line_xfer;

    opb_busLock <= not(opb_last_data);
end generate WRBURST_NOBURST_GEN;     
        
WRBURST_BURST_GEN: if C_NO_PLB_BURST = 0 generate
    WRBURST_PROCESS: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if (xfer_qual_load_en)='1' then
            PLB_wrBurst_d1 <= '1';
            PLB_wrBurst_d2 <= '1';
        else
            PLB_wrBurst_d1 <= plb_wrburst_masked;
            PLB_wrBurst_d2 <= PLB_wrBurst_d1;
        end if ;
      end if;
    end process ;

    BRSTLAST_CTRL: process(xfer_qual_load_en, brst_len_eq_zero, Rst, size(0),
                            OPB_RNW, brst_len, brst_cnt,addrAck, opb_Abus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS),
                            plb_wrburst_masked, PLB_wrBurst_d1, plb_rdburst_masked, busy, xfer_is_32)
    begin

        if (xfer_qual_load_en='1' and brst_len_eq_zero='0') or
            Rst = RESET_ACTIVE then
            brst_last_rst <= '1';
        else
            brst_last_rst <= '0';
        end if;

        if (xfer_qual_load_en='1' and brst_len_eq_zero='1') or
            (OPB_RNW='1' and (brst_len = "0001" or brst_cnt = "0010")) or
            (OPB_RNW='0' and (addrAck = '0' and brst_cnt = "0000")) then
                brst_last_set <= '1';
        else
            brst_last_set <= '0';
        end if;

        if OPB_RNW = '1' then 
            if busy = '1' and plb_rdburst_masked = '0' then
                brst_last_d <= '1';
            else
                brst_last_d <= '0';
            end if;
        else  
            if xfer_is_32 = '1' then
                if plb_wrburst_masked = '0' then
                    brst_last_d <= '1';
                else
                    brst_last_d <= '0';
                end if;
            else
                if (PLB_wrBurst_d1 = '0' and opb_Abus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS) = '0') then
                    brst_last_d <= '1';
                else
                    brst_last_d <= '0';
                end if;
            end if;
        end if;
        brst_last_ce <= size(0);
    end process  BRSTLAST_CTRL;

    BRSTLAST_REG: process (Clk)
    begin
      if (Clk'event and Clk = '1' )then
        if (brst_last_rst)='1' then
          brst_last <= '0';
        elsif (brst_last_set)='1' then
            brst_last <= '1';
        elsif (brst_last_ce)='1' then
              brst_last <= brst_last_d;
        end if ;
      end if ;
    end process BRSTLAST_REG;

    --  delay burst terminate signals for writes to account for write pipeline delay
    BRSTLAST_WRITEPIPE: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if addrAck='1' then
            at_1k_guard_bndry <= '0';
            at_1k_guard_bndry_d1 <= '0';
        else
            at_1k_guard_bndry <= guarded_i and at_1k_bndry;
            at_1k_guard_bndry_d1 <= at_1k_guard_bndry;
        end if ;
     end if;
    end process ;

    opb_last_data <= ((guarded_i and at_1k_bndry) or brst_last) when opb_RNW = '1'
                     else ((guarded_i and at_1k_bndry_d2) or brst_last);

    --  seqAddr asserted except for last xfer. Also off when size = 0 (single),
    --  8 (byte burst), or 9 (halfword burst)
    burst_or_line_xfer <= size(1) or size(2) or ((not(size(0)) and size(3)));

    opb_seqAddr <= not(opb_last_data) and burst_or_line_xfer;

    opb_busLock <= not(opb_last_data);
end generate WRBURST_BURST_GEN;     

-------------------------------------------------------------------------------
--  Write Data into AsyncInterface to OPB 
-------------------------------------------------------------------------------
--  send data over to OPB side through async interface
PLB_xfer_data(XFER_DBUS_START to XFER_DBUS_END) <= OPB_DBus;
PLB_xfer_data(XFER_ABUS_START to XFER_ABUS_END) <= opb_Abus;
PLBXFER_64BE_GEN: if C_PLB_DWIDTH=64 generate
    PLB_xfer_data(XFER_BE_START to XFER_BE_END)<= opb_BE(4 to 7) 
                                        when opb_ABus(C_OPB_AWIDTH-WRD_ADDR_BITS)='1' 
                                         else opb_BE(0 to 3);
end generate PLBXFER_64BE_GEN;
PLBXFER_32BE_GEN: if C_PLB_DWIDTH=32 generate
        PLB_xfer_data(XFER_BE_START to XFER_BE_END)<= opb_BE(0 to 3);
end generate PLBXFER_32BE_GEN;
PLB_xfer_data(XFER_RNW)<=opb_RNW;
PLB_xfer_data(XFER_BUSLOCK)<=opb_busLock;
PLB_xfer_data(XFER_SEQADDR)<=opb_seqAddr;
PLB_xfer_data(XFER_LASTWRD)<=opb_last_data;

--  strobe to load rd/wr data into BRAM/DPRAM in async interface
plb_xfer_strobe_rd <= opb_RNW and ((addrAck or (or_reduce(brst_cnt))));
PLB_WRSTROBE: process (Clk)
begin
    if Clk'event and Clk = '1' then 
        if Rst = RESET_ACTIVE then
            plb_xfer_strobe_wr <= '0';
            plb_xfer_strobe_wr_d1 <= '0';
        else
            plb_xfer_strobe_wr <= not(opb_RNW) and ((addrAck or (or_reduce(brst_cnt))));
            plb_xfer_strobe_wr_d1 <= plb_xfer_strobe_wr;
        end if;
    end if;
end process PLB_WRSTROBE;
PLB_xfer_strobe <= plb_xfer_strobe_rd or plb_xfer_strobe_wr_d1;

-------------------------------------------------------------------------------
--  Start Handshaking Signals with OPB Master
-------------------------------------------------------------------------------
--  start/start_ack tell the OPB Master when it can begin to transfer data
--  out over OPB. Since the PLB and OPB logic are async to each other, an
--  async handshaking mechanism is needed to tell the OPB to start a transfer.
-------------------------------------------------------------------------------
--  PLB_xfer_start_flag is asserted when a valid PLB transaction has been
--  accepted and is held ON until OPB logic acknowledges receipt of start signal
START_FLAG_PROCESS: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if PLB_xfer_start_ack='1' or Rst=RESET_ACTIVE then
        start_flag_hold <= '0';
    elsif ((opb_RNW='1' and addrAck='1') or
           (opb_RNW='0' and addrAck_d2='1')) then
            start_flag_hold <= '1';
    end if ;
  end if;
end process START_FLAG_PROCESS;

--  delay start flag on writes since write data experiences pipeline delay
plb_xfer_start_flag_i <= (addrAck or start_flag_hold) when opb_RNW = '1'
                        else (addrAck_d2 or start_flag_hold);

-------------------------------------------------------------------------------
--  PLB Write Data Path Logic
-------------------------------------------------------------------------------
--  Need to know when the last write data transfer occurs so the BGO_wrComp
--  and BGO_wrBTerm signals can be generated. Since PLB signals need to
--  be driven out of flip flops with as few levels of logic as posible,
--  the logic generating BGO_wrDAck/BGO_wrComp/BGO_wrBTerm must be carefully
--  structured.

--  Flag when logic is busy performing writes
WRBUSY_PROCESS: process(Clk)
begin
  if Clk'event and Clk = '1' then
    if (Rst = RESET_ACTIVE or 
        (PLB_rcv_strobe = '1' and PLB_rcv_data(RCV_LASTWRD) = '1')) then
        wr_busy <= '0';
    elsif (addrAck and not(opb_RNW))='1' then
         wr_busy <= '1';
    end if ;
  end if ;
end process WRBUSY_PROCESS;

-- Generate the write data path control signals based on whether bursts are
-- supported or not
WRDATAPATH_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
    --  Generate BGO_wrDAck so signal comes out of flip flops. During 64 bit
    --  transfers, the write data acks have to have wait states inserted
    --  to allow time for the 64 bit data to be muxed down into 2 32-bit
    --  transfers
    WRDACK_PROCESS: process (Clk)
    begin
      if Clk'event and Clk = '1' then
        if BGO_wrComp_i = '1' then
            BGO_wrDAck_i <= '0';
        else
            BGO_wrDAck_i <= not(opb_RNW) and 
                           (addrAck or (or_reduce(brst_cnt))) 
                           and (xfer_is_32 or not(opb_ABus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS)));
        end if ;
      end if;
    end process WRDACK_PROCESS;

    --  Generate BGO_wrComp so signal comes out of flip flops. Use a FDRS
    --  flip flop and distribute the logic over the inputs to reduce logic levels
    BGO_wrComp_rst <= opb_RNW or BGO_wrComp_i or 
                    not(addrAck or (or_reduce(brst_cnt)));
    BGO_wrComp_set <= '1' when  brst_cnt = "0001"
                    else '0';
    BGO_wrComp_d <= '1' when (addrAck='1' and brst_len = "0000")
                    else '0';

    SLWRCOMP_PROCESS: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if BGO_wrComp_rst='1' then
            BGO_wrComp_i <= '0';
        elsif BGO_wrComp_set='1' then
            BGO_wrComp_i <= '1';
        else
          BGO_wrComp_i <= BGO_wrComp_d;
        end if ;
     end if ;
    end process SLWRCOMP_PROCESS;

    --  Since no bursts, BGO_wrBTerm =0
    bndry_ABus_reg <= (others => '0');
    bndry_PLB_ABus <= (others => '0');

    wrBTerm_if_PAValid_rst <= '1';
    wrBTerm_if_PAValid_set <= '0';
    wrBTerm_if_PAValid_d <= '0';
    wrBTerm_if_PAValid <= '0';
    xfer_is_wr_burst <=  '0';
    xfer_cntr_expires <= '0';
    wr_active <= '0';
    at_1k_bndry_wrbterm <= '0';
    end_of_wr_burst <= '0';
    BGO_wrBTerm <= '0';
    
end generate WRDATAPATH_NOBURST_GEN;

WRDATAPATH_BURST_GEN: if C_NO_PLB_BURST = 0 generate

    --  Generate BGO_wrDAck so signal comes out of flip flops. During 64 bit
    --  transfers, the write data acks have to have wait states inserted
    --  to allow time for the 64 bit data to be muxed down into 2 32-bit
    --  transfers
    WRDACK_PROCESS: process (Clk)
    begin
      if Clk'event and Clk = '1' then
        if ((size(0) = '1' and plb_wrburst_masked='0' and BGO_wrDAck_i = '1') or
            BGO_wrComp_i = '1') then
            BGO_wrDAck_i <= '0';
        else
            BGO_wrDAck_i <= not(opb_RNW) and 
                           (addrAck or (or_reduce(brst_cnt))) 
                           and (xfer_is_32 or not(opb_ABus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS)));
        end if ;
      end if;
    end process WRDACK_PROCESS;

    --  Generate BGO_wrComp so signal comes out of flip flops. Use a FDRS
    --  flip flop and distribute the logic over the inputs to reduce logic levels
    BGO_wrComp_rst <= opb_RNW or BGO_wrComp_i or 
                    not(addrAck or (or_reduce(brst_cnt)));
    BGO_wrComp_set <= '1' 
            when ((guarded_i='1' and at_1k_bndry='1') or 
                 (size(0)='1' and plb_wrburst_masked='0' and (xfer_is_32='1' or opb_ABus_reg(C_OPB_AWIDTH-WRD_ADDR_BITS)='1')) 
                  or brst_cnt = "0001")
            else '0';
    BGO_wrComp_d <= '1' when (addrAck='1' and brst_len = "0000")
                    else '0';

    SLWRCOMP_PROCESS: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if BGO_wrComp_rst='1' then
            BGO_wrComp_i <= '0';
        elsif BGO_wrComp_set='1' then
            BGO_wrComp_i <= '1';
        else
          BGO_wrComp_i <= BGO_wrComp_d;
        end if ;
     end if ;
    end process SLWRCOMP_PROCESS;

    --  Generate BGO_wrBTerm with one logic level from flop

    --  determine if BGO_wrBTerm needs to be immediately asserted after first
    --  data transfer because xfer is a burst of one. This only happens when:
    --   - size is 8 or 9 (byte/halfword burst)
    --   - data transfer crosses boundary that is a 1K guarded address or it
    --     crosses the uppermost address of the bridge's address region
    --   - The address boundary also depends on if data transfers are 32 or 64 bits
    --  Use a FDRS flip flop and distribute the logic over the inputs to reduce
    --  logic levels

    bndry_ABus_reg <= "11111110" when (xfer_is_32='1') 
                    else "11111101";
    bndry_PLB_ABus <= "11111110" when (or_reduce(PLB_MSize)='1' and plb_size_masked > "1010")
                    else "11111111";
    wrBTerm_if_PAValid_rst <= '1' 
                    when (plb_size_masked(0)='0' or PLB_RNW='1' or busy='1' or
                          BGO_addrAck_i='1' or 
                          ((PLB_ABus(C_PLB_AWIDTH-ONEK_ADDR_BITS to C_PLB_AWIDTH-WRD_ADDR_BITS) /= bndry_PLB_ABus)
                                        and (plb_size_masked(0 to 2) /= "100")))
                    else '0';

    wrBTerm_if_PAValid_set <= '1' when (PLB_guarded='1' or (plb_size_masked(0 to 2) = "100"))
                                else '0';

    wrBTerm_if_PAValid_d <= '1' when (PLB_ABus(0 to C_PLB_AWIDTH-ONEK_ADDR_BITS-1) = 
                                    selected_high_addr(0 to C_PLB_AWIDTH-ONEK_ADDR_BITS-1))
                                else '0';

    WRBTERM_PAVALID_PROCESS: process (Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if (wrBTerm_if_PAValid_rst)='1' then
            wrBTerm_if_PAValid <= '0';
        elsif (wrBTerm_if_PAValid_set)='1' then
            wrBTerm_if_PAValid <= '1';
        else
            wrBTerm_if_PAValid <= wrBTerm_if_PAValid_d;
        end if ;
      end if ;
    end process WRBTERM_PAVALID_PROCESS;

    --  determine if BGO_wrBTerm needs to be asserted on the second or later
    --  data transfer because the burst has to be terminated due to guarded
    --  or address space boundaries or due to burst length

    xfer_is_wr_burst <= '1' 
                    when (size(0)='1' and opb_RNW='0' and (addrAck='1' or busy='1'))
                    else '0';
    xfer_cntr_expires <= '1' 
                    when ((addrAck='1' and brst_len = "0001")
                         or (busy='1' and brst_cnt(0 to 2)= "001" and (xfer_is_32 /= brst_cnt(3))))
                    else '0';

    WRACTIVE_REG: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if plb_wrburst_masked='0' then
            wr_active <= '0';
        elsif xfer_qual_load_en = '1' and plb_size_masked(0)='1' and PLB_RNW='0' then
            wr_active <= '1';
        end if ;
      end if ;
    end process WRACTIVE_REG;

    WRBTERM_1K_BNDRY_PROCESS: process(opb_ABus_reg, bndry_ABus_reg, BGO_addrAck_i,
                                        busy, bndry_PLB_ABus,PLB_ABus)
    begin
        if BGO_addrAck_i = '1' or busy = '1' then
            if (opb_ABus_reg(C_OPB_AWIDTH-ONEK_ADDR_BITS to C_OPB_AWIDTH-WRD_ADDR_BITS) = bndry_ABus_reg) then
                at_1k_bndry_wrbterm <= '1';
            else 
                at_1k_bndry_wrbterm <= '0';
            end if;
        else
            if PLB_ABus(C_PLB_AWIDTH-ONEK_ADDR_BITS to C_PLB_AWIDTH-WRD_ADDR_BITS) = bndry_PLB_ABus then
                at_1k_bndry_wrbterm <= '1';
            else 
                at_1k_bndry_wrbterm <= '0';
            end if;
        end if;
    end process WRBTERM_1K_BNDRY_PROCESS;

    WRBURST_END: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if (xfer_qual_load_en='1' or wr_active='0') then
            end_of_wr_burst <= '0';
        else
            end_of_wr_burst <= xfer_is_wr_burst and 
                            ((guarded_i and at_1k_bndry_wrbterm) or xfer_cntr_expires);
        end if ;
     end if;
    end process ;

    --  Generate BGO_wrBTerm - notice that it only requires 1 LUT (4 inputs)
    --                        with each input coming out of a register
    BGO_wrBTerm <= (wrBTerm_if_PAValid and PLB_PAValid and access_valid) or
                    end_of_wr_burst;
end generate WRDATAPATH_BURST_GEN; 

-------------------------------------------------------------------------------
--  PLB Read Data Path Logic
-------------------------------------------------------------------------------
--  PLB_rcv_data[0:31]  = OPB Read Data
--  PLB_rcv_data[32:35] = OPB Read Word Address
--  PLB_rcv_data[36]    = OPB Error Detected During Read
--  PLB_rcv_data[37]    = OPB End of Data Transfer Flag
--  When Reads are active then PLB Slave Read ports can be driven otherwise
--  they have to be zeroed out
RDBUSY_PROCESS: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst=RESET_ACTIVE or rdComp_com='1' then
        rd_busy <= '0';
    elsif addrAck='1' and opb_RNW='1' then
        rd_busy <= '1';
    end if ;
  end if ;
end process RDBUSY_PROCESS;

-- Drive the BGO read data bus - logic depends on the PLB data bus size
RDDATA_PLB32_GEN: if C_PLB_DWIDTH=C_OPB_DWIDTH generate
    -- plb and opb are same data widths, simply register read data
    -- with receive data strobe
    SL_RDDATA_PROCESS: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if Rst=RESET_ACTIVE or rd_busy='0' then
            BGO_rdDBus <= (others => '0');
        elsif PLB_rcv_strobe ='1' then
                BGO_rdDBus(0 to C_PLB_DWIDTH-1) <= PLB_rcv_data(0 to C_OPB_DWIDTH-1);
        end if;
      end if ;
    end process SL_RDDATA_PROCESS;
end generate  RDDATA_PLB32_GEN;

RDDATA_PLB64_GEN: if C_PLB_DWIDTH=C_OPB_DWIDTH*2 generate
    --  Drive 64 bit Read data. Upper and lower words are latched depending
    --  on the read word address and whether the master expects to see the data
    --  as a 32 bit or 64 bit piece.
    SL_RDDATA_PROCESS: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if Rst=RESET_ACTIVE or rd_busy='0' then
            BGO_rdDBus <= (others => '0');
        elsif PLB_rcv_strobe ='1' then
            if xfer_is_32 ='1' or PLB_rcv_data(RCV_RDWDADDR_END)='0' then
                BGO_rdDBus(0 to C_PLB_DWIDTH/2-1) <= PLB_rcv_data(0 to C_OPB_DWIDTH-1);
            end if;
            if xfer_is_32='1' or PLB_rcv_data(RCV_RDWDADDR_END)='1' then
                BGO_rdDBus(C_PLB_DWIDTH/2 to C_PLB_DWIDTH-1) <= PLB_rcv_data(0 to C_OPB_DWIDTH-1);           
            end if ;
        end if;
      end if ;
    end process SL_RDDATA_PROCESS;
end generate  RDDATA_PLB64_GEN;

--  Send back RdWdAddr on cacheline xfers and zero out lowest word address
--  during 64 bit transfers
-- no need to do separate generate for no burst support since size(0)=0 in that case
RDWDADDR_PROCESS: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst=RESET_ACTIVE or rd_busy='0' or PLB_rcv_strobe='0' or size(0)='1' then
        BGO_rdWdAddr <= "0000";
    else
        BGO_rdWdAddr(0 to 2) <= PLB_rcv_data(RCV_RDWDADDR_START to RCV_RDWDADDR_END-1);
        if PLB_rcv_data(RCV_RDWDADDR_END) = '1' and msize = "00" then
            BGO_rdWdAddr(3) <= '1';
        else
            BGO_rdWdAddr(3) <= '0';
        end if;
  end if ;
 end if;
end process RDWDADDR_PROCESS;

--  Assert rdComp with last RdAck
RDCOMPACK_NOBURST_GEN: if C_NO_PLB_BURST=1 generate
    rdComp_com <= PLB_rcv_strobe and rd_busy and PLB_rcv_data(RCV_LASTWRD);

    --  Read Acknowledges are sent on every data word when the master expects data
    --  in 32 bit quantities or when a new 64 bit boudary is crossed
    rdDAck_com <= (xfer_is_32 or PLB_rcv_data(RCV_RDWDADDR_END) or PLB_rcv_data(RCV_LASTWRD));
    
    -- Bterm = '0' when bursts are not supported
    BGO_rdBTerm <= '0';
end generate RDCOMPACK_NOBURST_GEN;

RDCOMPACK_BURST_GEN: if C_NO_PLB_BURST=0 generate
    rdComp_com <= PLB_rcv_strobe and rd_busy and 
                (PLB_rcv_data(RCV_LASTWRD) or 
                (size(0) and not(plb_rdburst_masked) and 
                (xfer_is_32 or PLB_rcv_data(RCV_RDWDADDR_END))));
                
    --  Read Acknowledges are sent on every data word when the master expects data
    --  in 32 bit quantities, when a new 64 bit boudary is crossed or when
    --  a burst ends.                
     rdDAck_com <= (xfer_is_32 or PLB_rcv_data(RCV_RDWDADDR_END) or PLB_rcv_data(RCV_LASTWRD)) 
                    and not(BGO_rdDAck_i and size(0) and not(plb_rdburst_masked));

    --  Assert BTerm at the end of a burst transfer, one cycle before last RdAck
    BGO_rdBTerm <= PLB_rcv_strobe and PLB_rcv_data(37) and size(0) and rd_busy;
                   
end generate RDCOMPACK_BURST_GEN;

RDCOMP_PROCESS: process(Clk)
begin
  if(Clk'event and Clk = '1' ) then
    if Rst = RESET_ACTIVE then
        BGO_rdComp_i <= '0';
    else
        BGO_rdComp_i <= rdComp_com;
    end if;
  end if;
end process RDCOMP_PROCESS;

RDDACK_PROCESS: process(Clk)
begin
  if(Clk'event and Clk = '1' ) then
    if Rst = RESET_ACTIVE or PLB_rcv_strobe='0' or rd_busy='0' then
        BGO_rdDAck_i <= '0';
    else
        BGO_rdDAck_i <= rdDAck_com;
    end if;
  end if;
end process RDDACK_PROCESS;


-------------------------------------------------------------------------------
--  Abort Handshaking Signals with OPB Master
-------------------------------------------------------------------------------
--  abort/abort_ack tell the OPB Master when it should abort an ongoing
--  data transfer. Since the PLB and OPB logic are async to each other, an
--  async handshaking mechanism is needed to tell the OPB to abort a transfer.
-------------------------------------------------------------------------------
-- if bursts are not supported, abort flag is not necessary
ABORT_NOBURST_GEN: if C_NO_PLB_BURST=1 generate
    master_rd_abort <= '0';
    abort_flag_hold <= '0';
    plb_xfer_abort_flag_i <= '0';
end generate ABORT_NOBURST_GEN;

ABORT_BURST_GEN: if C_NO_PLB_BURST=0 generate
    --  check when master aborts a read burst prematurely (before last data word
    --  requested could be sent) - This will start the FSM that tells the
    --  OPB to stop sending read data.
    master_rd_abort <= size(0) and not(plb_rdburst_masked) and PLB_rcv_strobe and rd_busy
                        and not(PLB_rcv_data(RCV_LASTWRD)) and 
                        ((xfer_is_32 or PLB_rcv_data(RCV_RDWDADDR_END)));

    --  PLB_xfer_abort_flag is asserted when a valid PLB transaction has been
    --  terminated and held ON until OPB logic acknowledges receipt of abort signal
    ABORT_FLAG_PROCESS: process(Clk)
    begin
      if (Clk'event and Clk = '1' ) then
        if PLB_xfer_abort_ack='1' or Rst=RESET_ACTIVE then
            abort_flag_hold <= '0';
        elsif (master_rd_abort)='1' then
            abort_flag_hold <= '1';
        end if ;
      end if ;
    end process ABORT_FLAG_PROCESS;

    --  PLB_xfer_abort_flag is asserted when the PLB master prematurely terminates
    --  a fixed length read burst or when a variable length read burst is completed
    --  in less that 16 words
    plb_xfer_abort_flag_i <= master_rd_abort or abort_flag_hold;

end generate  ABORT_BURST_GEN;
-------------------------------------------------------------------------------
--  Generate local "busy" signal
-------------------------------------------------------------------------------
--  Busy turned on when addrack is asserted to the PLB Arbiter and stays on
--  until read/write completes and all handshaking flags are deasserted.
BUSY_NOBURST_GEN: if C_NO_PLB_BURST = 1 generate
    busy_on <= rd_busy or plb_xfer_start_flag_i or PLB_xfer_start_ack or 
            ((wr_busy and not(PLB_rcv_strobe and PLB_rcv_data(RCV_LASTWRD))));
end generate BUSY_NOBURST_GEN;
BUSY_BURST_GEN: if C_NO_PLB_BURST = 0 generate
    busy_on <= plb_xfer_abort_flag_i or PLB_xfer_abort_ack or rd_busy or
            plb_xfer_start_flag_i or PLB_xfer_start_ack or 
            ((wr_busy and not(PLB_rcv_strobe and PLB_rcv_data(RCV_LASTWRD))));
end generate BUSY_BURST_GEN;

BUSY_PROCESS: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst=RESET_ACTIVE then
        busy <= '0';
    elsif addrAck='1' then
        busy <= '1';
    else
        busy <= busy_on;
    end if ;
  end if ;
end process BUSY_PROCESS;

-------------------------------------------------------------------------------
--  Generate PLB Busy/Error Flags
-------------------------------------------------------------------------------
MSTR_ID_GENERATE: for i in 0 to C_PLB_NUM_MASTERS-1 generate
    MSTR_ID_PROCESS: process(Clk)
    begin
        if (Clk'event and Clk = '1' ) then
            if (xfer_qual_load_en)='1' then
                if PLB_masterID = conv_std_logic_vector(i, C_PLB_MID_WIDTH) then
                    master_id_decode_i(i) <= '1';
                else
                    master_id_decode_i(i) <= '0';
                end if;
            end if;
        end if;
    end process MSTR_ID_PROCESS;
end generate MSTR_ID_GENERATE;


RCV_LSTWR_PROCESS: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    rcv_last_write_status <= not(opb_RNW) and 
                            PLB_rcv_strobe and PLB_rcv_data(RCV_LASTWRD);
  end if;
end process RCV_LSTWR_PROCESS;

mbusy_clr <= '1' 
        when Rst=RESET_ACTIVE or BGO_rdComp_i='1' or rcv_last_write_status='1'
        else '0';

BGO_MBusy_PROCESS: process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if mbusy_clr='1' then
        BGO_MBusy_i <= (others => '0');
    elsif addrAck = '1' then
        BGO_MBusy_i <= master_id_decode_i or BGO_MBusy_i;
    end if;
  end if ;
end process BGO_MBusy_PROCESS;

ERR_DETECT_PROCESS: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
   -- err_detect <= PLB_rcv_strobe and PLB_rcv_data(36);
    if Rst = RESET_ACTIVE or xfer_qual_load_en = '1' then
        err_detect <= '0';
    elsif PLB_rcv_strobe = '1' and PLB_rcv_data(RCV_ERR) = '1' then
        err_detect <= '1';
    elsif opb_RNW = '0' or BGO_rdDAck_i = '1' then
        err_detect <= '0';
    end if;        
  end if;
end process ERR_DETECT_PROCESS;

BGO_MErr_PROCESS: process (master_id_decode_i, err_detect, BGO_rdDAck_i, opb_RNW)
begin
    if err_detect = '1' and (BGO_rdDAck_i = '1' or opb_RNW='0') then
        BGO_MErr <= master_id_decode_i;
    else
        BGO_MErr <= (others => '0');
    end if;
end process BGO_MErr_PROCESS;

LOCKERR_PROCESS: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if (xfer_qual_load_en)='1' then
        Lock_err <= PLB_lockErr;
    end if ;
  end if;
end process LOCKERR_PROCESS;

-------------------------------------------------------------------------------
--  Process PLB busLock operations
-------------------------------------------------------------------------------
PLB_BUSLOCK_PROCESS:process(Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst=RESET_ACTIVE then
        PLB_hold_buslock <= '0';
    elsif BGO_addrAck_i = '1' and PLB_abort = '0' and PLB_busLock = '1' then
      PLB_hold_buslock <= '1';
    elsif PLB_busLock = '0' and busy = '0' then
        PLB_hold_buslock <= '0';
    end if ;
  end if ;
end process PLB_BUSLOCK_PROCESS;


end ;

