-------------------------------------------------------------------------------
-- $Id: master_attachment.vhd,v 1.4 2004/11/23 00:59:54 jcanaris Exp $
-------------------------------------------------------------------------------
-- master_attachment.vhd - VHD design file
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        master_attachment.vhd
--
-- Description:     VHDL design file that is a wrapper around the IPIF
--                  master_attachment module. It is primarily used to
--                  include/remove the master_attachment from the IPIF
--                  per user parameterization.
--
-------------------------------------------------------------------------------
-- Structure:
--
--              master_attachment.vhd
--                     |
--                     |---> mst_attach.vhd
--
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
--
-- History:
--  DET      July 23, 2001      -- First version adapted from Visual HDL output
--  LCW	Oct 12, 2004 	 -- updated for NCSim
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
use IEEE.Std_Logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.mst_attach;



-------------------------------------------------------------------------------

entity master_attachment is
  generic (
           C_OPB_ABUS_WIDTH     : INTEGER := 32;
           C_OPB_DBUS_WIDTH     : INTEGER := 32;
           C_B                  : INTEGER := 4;
           C_MA2SA_NUM_WIDTH    : INTEGER := 4
           );
  port (
        Bus2IP_Clk_i        : in std_logic;
        Bus2IP_MstError_i   : out std_logic;
        Bus2IP_MstLastAck_i : out std_logic;
        Bus2IP_MstRdAck_i   : out std_logic;
        Bus2IP_MstRetry_i   : out std_logic;
        Bus2IP_MstTimeOut_i : out std_logic;
        Bus2IP_MstWrAck_i   : out std_logic;
        Bus_MnGrant         : out std_logic;
        Bus_Reset_i         : in std_logic;
        DMA2BUS_Addr        : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
        DMA_MstBE           : in std_logic_vector(0 to C_B - 1 );
        DMA_MstBurst        : in std_logic;
        DMA_MstBusLock      : in std_logic;
        DMA_MstRdReq        : in std_logic;
        DMA_MstWrReq        : in std_logic;
        IP2Bus_Addr         : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
        IP2Bus_MstBE        : in std_logic_vector(0 to C_B - 1 );
        IP2Bus_MstBurst     : in std_logic;
        IP2Bus_MstBusLock   : in std_logic;
        IP2Bus_MstRdReq     : in std_logic;
        IP2Bus_MstWrReq     : in std_logic;
        MA2SA_num           : out std_logic_vector(0 to C_MA2SA_NUM_WIDTH - 1 );
        MA2SA_Rd            : out std_logic;
        MA2SA_select        : out std_logic;
        MA2SA_XferAck       : out std_logic;
        Mn_ABus             : out std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
        Mn_BE               : out std_logic_vector(0 to C_B - 1 );
        Mn_busLock          : out std_logic;
        Mn_request          : out std_logic;
        Mn_RNW              : out std_logic;
        Mn_select           : out std_logic;
        Mn_seqAddr          : out std_logic;
        Mstr_sel_ma         : out std_logic;
        OPB_errAck          : in std_logic;
        OPB_MnGrant         : in std_logic;
        OPB_retry           : in std_logic;
        OPB_timeout         : in std_logic;
        OPB_xferAck         : in std_logic;
        SA2MA_RdRdy         : in std_logic;
        SA2MA_WrAck         : in std_logic
        );


end master_attachment;



-------------------------------------------------------------------------------
architecture implementation of master_attachment is


     signal DMA2Bus_MstAddr : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 3 );
     signal IP2Bus_MstAddr  : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 3 );
     signal Mn_ABus_gtd     : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 3 );




begin -- architecture



      DMA2Bus_MstAddr                     <= DMA2Bus_Addr(0 to C_OPB_ABUS_WIDTH-3);
      IP2Bus_MstAddr                      <= IP2Bus_Addr(0 to C_OPB_ABUS_WIDTH-3);
      Mn_ABus(0 to C_OPB_ABUS_WIDTH-3)    <= Mn_ABus_gtd;

      Mn_ABUS(C_OPB_ABUS_WIDTH-2 to C_OPB_ABUS_WIDTH-1) <= (others => '0');





    I_MASTER_ATTACHMENT: entity opb_ipif_v1_23_a.mst_attach
      generic map (C_OPB_ABUS_WIDTH,
                   C_OPB_DBUS_WIDTH,
                   C_MA2SA_NUM_WIDTH)
      port map (
                Reset                => Bus_Reset_i,
                OPB_Clk              => Bus2IP_Clk_i,
                OPB_MnGrant          => OPB_MnGrant,
                OPB_XferAck          => OPB_xferAck,
                OPB_ErrAck           => OPB_errAck,
                OPB_TimeOut          => OPB_timeout,
                OPB_Retry            => OPB_retry,
                Mn_Request           => Mn_request,
                Mn_Select            => Mn_select,
                Mn_RNW_gtd           => Mn_RNW,
                Mn_SeqAddr_gtd       => Mn_seqAddr,
                Mn_BusLock_gtd       => Mn_busLock,
                Mn_BE_gtd            => Mn_BE(0 to C_B - 1),
                Mn_ABus_gtd          => Mn_ABus_gtd(0 to C_OPB_ABUS_WIDTH - 3),
                Bus_MnGrant          => Bus_MnGrant,
                MA2SA_Select         => MA2SA_select,
                MA2SA_XferAck        => MA2SA_XferAck,
                MA2SA_Rd             => MA2SA_Rd,
                MA2SA_Num            => MA2SA_num(0 to C_MA2SA_NUM_WIDTH - 1),
                SA2MA_RdRdy          => SA2MA_RdRdy,
                SA2MA_WrAck          => SA2MA_WrAck,
                Mstr_Sel_ma          => Mstr_sel_ma,
                IP2Bus_MstAddr       => IP2Bus_MstAddr(0 to C_OPB_ABUS_WIDTH - 3),
                IP2Bus_MstBE         => IP2Bus_MstBE(0 to C_B - 1),
                IP2Bus_MstWrReq      => IP2Bus_MstWrReq,
                IP2Bus_MstRdReq      => IP2Bus_MstRdReq,
                IP2Bus_MstBurst      => IP2Bus_MstBurst,
                IP2Bus_MstBusLock    => IP2Bus_MstBusLock,
                Bus2IP_MstWrAck_ma   => Bus2IP_MstWrAck_i,
                Bus2IP_MstRdAck_ma   => Bus2IP_MstRdAck_i,
                Bus2IP_MstRetry_ma   => Bus2IP_MstRetry_i,
                Bus2IP_MstError_ma   => Bus2IP_MstError_i,
                Bus2IP_MstTimeOut_ma => Bus2IP_MstTimeOut_i,
                Bus2IP_MstLastAck_ma => Bus2IP_MstLastAck_i,
                DMA2Bus_MstAddr      => DMA2Bus_MstAddr(0 to C_OPB_ABUS_WIDTH - 3),
                DMA2Bus_MstBE        => DMA_MstBE(0 to C_B - 1),
                DMA2Bus_MstWrReq     => DMA_MstWrReq,
                DMA2Bus_MstRdReq     => DMA_MstRdReq,
                DMA2Bus_MstBurst     => DMA_MstBurst,
                DMA2Bus_MstBusLock   => DMA_MstBusLock);



 --   INCLUDE_MASTER : if (C_ADD_MASTER = True) generate
 --
 --       signal DMA2Bus_MstAddr : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 3 );
 --       signal IP2Bus_MstAddr  : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 3 );
 --       signal Mn_ABus_gtd     : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 3 );
 --
 --     begin
 --
 --        DMA2Bus_MstAddr                     <= DMA2Bus_Addr(0 to C_OPB_ABUS_WIDTH-3);
 --        IP2Bus_MstAddr                      <= IP2Bus_Addr(0 to C_OPB_ABUS_WIDTH-3);
 --        Mn_ABus(0 to C_OPB_ABUS_WIDTH-3)    <= Mn_ABus_gtd;
 --
 --        Mn_ABUS(C_OPB_ABUS_WIDTH-2 to C_OPB_ABUS_WIDTH-1) <= (others => '0');
 --
 --
 --        master_attachment: entity opb_ipif_v1_23_a.mst_attach
 --          generic map (C_OPB_ABUS_WIDTH,
 --                       C_OPB_DBUS_WIDTH,
 --                       C_MA2SA_NUM_WIDTH)
 --          port map (
 --                    Reset                => Bus_Reset_i,
 --                    OPB_Clk              => Bus2IP_Clk_i,
 --                    OPB_MnGrant          => OPB_MnGrant,
 --                    OPB_XferAck          => OPB_xferAck,
 --                    OPB_ErrAck           => OPB_errAck,
 --                    OPB_TimeOut          => OPB_timeout,
 --                    OPB_Retry            => OPB_retry,
 --                    Mn_Request           => Mn_request,
 --                    Mn_Select            => Mn_select,
 --                    Mn_RNW_gtd           => Mn_RNW,
 --                    Mn_SeqAddr_gtd       => Mn_seqAddr,
 --                    Mn_BusLock_gtd       => Mn_busLock,
 --                    Mn_BE_gtd            => Mn_BE(0 to C_B - 1),
 --                    Mn_ABus_gtd          => Mn_ABus_gtd(0 to C_OPB_ABUS_WIDTH - 3),
 --                    Bus_MnGrant          => Bus_MnGrant,
 --                    MA2SA_Select         => MA2SA_select,
 --                    MA2SA_XferAck        => MA2SA_XferAck,
 --                    MA2SA_Rd             => MA2SA_Rd,
 --                    MA2SA_Num            => MA2SA_num(0 to C_MA2SA_NUM_WIDTH - 1),
 --                    SA2MA_RdRdy          => SA2MA_RdRdy,
 --                    SA2MA_WrAck          => SA2MA_WrAck,
 --                    Mstr_Sel_ma          => Mstr_sel_ma,
 --                    IP2Bus_MstAddr       => IP2Bus_MstAddr(0 to C_OPB_ABUS_WIDTH - 3),
 --                    IP2Bus_MstBE         => IP2Bus_MstBE(0 to C_B - 1),
 --                    IP2Bus_MstWrReq      => IP2Bus_MstWrReq,
 --                    IP2Bus_MstRdReq      => IP2Bus_MstRdReq,
 --                    IP2Bus_MstBurst      => IP2Bus_MstBurst,
 --                    IP2Bus_MstBusLock    => IP2Bus_MstBusLock,
 --                    Bus2IP_MstWrAck_ma   => Bus2IP_MstWrAck_i,
 --                    Bus2IP_MstRdAck_ma   => Bus2IP_MstRdAck_i,
 --                    Bus2IP_MstRetry_ma   => Bus2IP_MstRetry_i,
 --                    Bus2IP_MstError_ma   => Bus2IP_MstError_i,
 --                    Bus2IP_MstTimeOut_ma => Bus2IP_MstTimeOut_i,
 --                    Bus2IP_MstLastAck_ma => Bus2IP_MstLastAck_i,
 --                    DMA2Bus_MstAddr      => DMA2Bus_MstAddr(0 to C_OPB_ABUS_WIDTH - 3),
 --                    DMA2Bus_MstBE        => DMA_MstBE(0 to C_B - 1),
 --                    DMA2Bus_MstWrReq     => DMA_MstWrReq,
 --                    DMA2Bus_MstRdReq     => DMA_MstRdReq,
 --                    DMA2Bus_MstBurst     => DMA_MstBurst,
 --                    DMA2Bus_MstBusLock   => DMA_MstBusLock);
 --
 --
 --
 --
 --
 --     end generate INCLUDE_MASTER;
 --
 --
 --
 --
 --
 --   REMOVE_MASTER : if (C_ADD_MASTER = False) generate
 --
 --          Bus2IP_MstError_i   <=  '0';
 --          Bus2IP_MstLastAck_i <=  '0';
 --          Bus2IP_MstRdAck_i   <=  '0';
 --          Bus2IP_MstRetry_i   <=  '0';
 --          Bus2IP_MstTimeOut_i <=  '0';
 --          Bus2IP_MstWrAck_i   <=  '0';
 --          Bus_MnGrant         <=  '0';
 --          MA2SA_num           <=  (others => '0');
 --          MA2SA_Rd            <=  '0';
 --          MA2SA_select        <=  '0';
 --          MA2SA_XferAck       <=  '0';
 --          Mn_ABus             <=  (others => '0');
 --          Mn_BE               <=  (others => '0');
 --          Mn_busLock          <=  '0';
 --          Mn_request          <=  '0';
 --          Mn_RNW              <=  '0';
 --          Mn_select           <=  '0';
 --          Mn_seqAddr          <=  '0';
 --          Mstr_sel_ma         <=  '0';
 --
 --     end generate REMOVE_MASTER;
 --





end implementation;

