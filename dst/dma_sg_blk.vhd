-------------------------------------------------------------------------------
-- $Id: dma_sg_blk.vhd,v 1.3 2001/10/15 22:48:56 ostlerf Exp $
-------------------------------------------------------------------------------
-- dma_sg_blk.vhd - VHD design file 
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        dma_sg_blk.vhd
--
-- Description:     VHDL design file that is a wrapper around the IPIF dma_sg_blk
--                  module. It is primarily used to include/remove the dma_sg_blk
--                  from the IPIF per user parameterization.
--
-------------------------------------------------------------------------------
-- Structure:   
--              
--              dma_sg_blk.vhd
--                     |
--                     |---> dma_sg_pkg.vhd
--                     |---> dma_sg_cmp.vhd
--                     |---> cntrl_reg.vhd (entity)
--                     |---> dma_sg.vhd (entity)
--                     |---> dma_sg_sim.vhd (architecture)
--                     |---> srl_fifo.vhd  (entity)
--                     |---> srl_fifo_imp.vhd  (architecture)
--                  
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
--
-- History:
--  DET      July 27, 2001      -- First version adapted from Visual HDL output
--
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
use ieee.STD_LOGIC_1164.all;
use ieee.STD_LOGIC_ARITH.all;
use ieee.STD_LOGIC_UNSIGNED.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.dma_sg_pkg.all;
use opb_ipif_v1_23_a.dma_sg_cmp.all;

-------------------------------------------------------------------------------



entity dma_sg_blk is
  generic (
           C_DMA_BLK_ID             : INTEGER := 255;
           C_DMA_CHAN_NUM           : INTEGER := 2;
           C_DMA_CH1_TYPE           : INTEGER := 2;
           C_DMA_CH2_TYPE           : INTEGER := 3;
           C_DMA_ALLOW_BURST        : BOOLEAN := True;
           C_DMA_BAR                : std_logic_vector := X"70002300";
           C_DMA_MAX_LENGTH_SIZE    : INTEGER := 11;
           C_DMA_INTR_COALESCE      : BOOLEAN := True;
           C_IP_REG_BAR             : std_logic_vector := X"70001100";
           C_RXL_FIFO_BAR           : std_logic_vector := X"70000000";
           C_TXL_FIFO_BAR           : std_logic_vector := X"70000000";
           C_TXS_FIFO_BAR           : std_logic_vector := X"70000000";
           C_RXS_FIFO_BAR           : std_logic_vector := X"70000000";
           C_SG_PACKET_WAIT_UNIT_NS : INTEGER := 1000000;
           C_OPB_ABUS_WIDTH         : INTEGER := 32;
           C_OPB_DBUS_WIDTH         : INTEGER := 32;
           C_OPB_CLK_PERIOD_PS      : INTEGER := 16000;
           C_B                      : INTEGER := 4;
           C_M                      : INTEGER := 26
           );
  port (
        Bus2IP_Addr_i : in std_logic_vector(0 to C_M - 1 );
        Bus2IP_BE_sa : in std_logic_vector(0 to C_B - 1 );
        Bus2IP_Burst_sa : in std_logic;
        Bus2IP_Clk_i : in std_logic;
        Bus2IP_Data_sa : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        Bus2IP_DMA_Ack : out std_logic;
        Bus2IP_Freeze_i : in std_logic;
        Bus2IP_MstError_i : in std_logic;
        Bus2IP_MstLastAck_i : in std_logic;
        Bus2IP_MstRdAck_i : in std_logic;
        Bus2IP_MstRetry_i : in std_logic;
        Bus2IP_MstTimeOut_i : in std_logic;
        Bus2IP_MstWrAck_i : in std_logic;
        Bus2IP_RdReq_sa : in std_logic;
        Bus2IP_Reset_i : in std_logic;
        Bus2IP_WrReq_sa : in std_logic;
        DMA2Bus_Addr : out std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
        DMA2Bus_Data : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        DMA2Intr_Intr : out std_logic_vector(0 to 1 );
        DMA2IP_Addr : out std_logic_vector(0 to C_M - 1 );
        DMA_MstBE : out std_logic_vector(0 to C_B - 1 );
        DMA_MstBurst : out std_logic;
        DMA_MstBusLock : out std_logic;
        DMA_MstRdReq : out std_logic;
        DMA_MstWrReq : out std_logic;
        DMA_RdCE : in std_logic;
        DMA_SG_Error : out std_logic;
        DMA_SG_RdAck : out std_logic;
        DMA_SG_Retry : out std_logic;
        DMA_SG_ToutSup : out std_logic;
        DMA_SG_WrAck : out std_logic;
        DMA_WrCE : in std_logic;
        IP2Bus_DMA_Req : in std_logic;
        IP2DMA_RxLength_Empty : in std_logic;
        IP2DMA_RxStatus_Empty : in std_logic;
        IP2DMA_TxLength_Full : in std_logic;
        IP2DMA_TxStatus_Empty : in std_logic;
        Mstr_sel_ma : in std_logic;
        RFIFO2DMA_AlmostEmpty : in std_logic;
        RFIFO2DMA_Empty : in std_logic;
        RFIFO2DMA_Occupancy : in std_logic_vector(0 to 9 );
        WFIFO2DMA_AlmostFull : in std_logic;
        WFIFO2DMA_Full : in std_logic;
        WFIFO2DMA_Vacancy : in std_logic_vector(0 to 9 )
        );
 
 
end dma_sg_blk;
 
 
------------------------------------------------------------------------------- 
architecture implementation of dma_sg_blk is
 
    constant RX_LEN_FIFO_BAR     : INTEGER := CONV_INTEGER (C_RXL_FIFO_BAR);  --  Cooresponds to the IP RX Length FIFO address
    constant TX_LEN_FIFO_BAR     : INTEGER := CONV_INTEGER (C_TXL_FIFO_BAR);  --  Cooresponds to the IP TX Length FIFO address
    constant TX_STAT_FIFO_BAR    : INTEGER := CONV_INTEGER (C_TXS_FIFO_BAR);  --  Cooresponds to the IP TX Status FIFO address
    constant RX_STAT_FIFO_BAR    : INTEGER := CONV_INTEGER (C_RXS_FIFO_BAR);  --  Cooresponds to the IP RX Status FIFO address
    constant DMA_LENGTH_MS_INDEX : INTEGER := C_OPB_DBUS_WIDTH -
                                              C_DMA_MAX_LENGTH_SIZE;
 
 
begin  -- architecture
 
  
    I_DMA_SG_CONTROLLER: dma_sg
    generic map (C_OPB_DBUS_WIDTH,
                 C_OPB_ABUS_WIDTH,
                 C_M,
                 C_B,
                 C_OPB_CLK_PERIOD_PS,
                 C_SG_PACKET_WAIT_UNIT_NS,
                 (C_DMA_CH1_TYPE, C_DMA_CH2_TYPE),
                 (DMA_LENGTH_MS_INDEX, DMA_LENGTH_MS_INDEX),
                 (TX_LEN_FIFO_BAR, RX_LEN_FIFO_BAR),
                 (TX_STAT_FIFO_BAR, RX_STAT_FIFO_BAR),
                 (C_DMA_INTR_COALESCE, C_DMA_INTR_COALESCE),
                 (C_DMA_BLK_ID, C_DMA_BLK_ID),
                 C_DMA_BAR,
                 C_DMA_ALLOW_BURST)
      port map (
                DMA2Bus_Data          => DMA2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
                DMA2Bus_Addr          => DMA2Bus_Addr(0 to C_OPB_ABUS_WIDTH - 1),
                DMA_MstBE             => DMA_MstBE(0 to C_B - 1),
                DMA_MstWrReq          => DMA_MstWrReq,
                DMA_MstRdReq          => DMA_MstRdReq,
                DMA_MstBurst          => DMA_MstBurst,
                DMA_MstBusLock        => DMA_MstBusLock,
                DMA2IP_Addr           => DMA2IP_Addr(0 to C_M - 1),
                DMA_WrAck             => DMA_SG_WrAck,
                DMA_RdAck             => DMA_SG_RdAck,
                DMA_Retry             => DMA_SG_Retry,
                DMA_Error             => DMA_SG_Error,
                DMA_ToutSup           => DMA_SG_ToutSup,
                Bus2IP_MstWrAck_i     => Bus2IP_MstWrAck_i,
                Bus2IP_MstRdAck_i     => Bus2IP_MstRdAck_i,
                Mstr_sel_ma           => Mstr_sel_ma,
                Bus2IP_MstRetry_i     => Bus2IP_MstRetry_i,
                Bus2IP_MstError_i     => Bus2IP_MstError_i,
                Bus2IP_MstTimeOut_i   => Bus2IP_MstTimeOut_i,
                Bus2IP_BE_sa          => Bus2IP_BE_sa(0 to C_B - 1),
                Bus2IP_WrReq_sa       => Bus2IP_WrReq_sa,
                Bus2IP_RdReq_sa       => Bus2IP_RdReq_sa,
                Bus2IP_Clk_i          => Bus2IP_Clk_i,
                Bus2IP_Reset_i        => Bus2IP_Reset_i,
                Bus2IP_Freeze_i       => Bus2IP_Freeze_i,
                Bus2IP_Addr_i         => Bus2IP_Addr_i(0 to C_M - 1),
                Bus2IP_Data_sa        => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
                Bus2IP_Burst_sa       => Bus2IP_Burst_sa,
                WFIFO2DMA_Vacancy     => WFIFO2DMA_Vacancy(0 to 9),
                Bus2IP_MstLastAck_i   => Bus2IP_MstLastAck_i,
                DMA_RdCE              => DMA_RdCE,
                DMA_WrCE              => DMA_WrCE,
                IP2DMA_RxStatus_Empty => IP2DMA_RxStatus_Empty,
                IP2DMA_RxLength_Empty => IP2DMA_RxLength_Empty,
                IP2DMA_TxStatus_Empty => IP2DMA_TxStatus_Empty,
                IP2DMA_TxLength_Full  => IP2DMA_TxLength_Full,
                IP2Bus_DMA_Req        => IP2Bus_DMA_Req,
                Bus2IP_DMA_Ack        => Bus2IP_DMA_Ack,
                DMA2Intr_Intr         => DMA2Intr_Intr(0 to 1));
 
 
--    ------------------------------------------------------------------------------
--    -- Include DMA in the IPIF
--    ------------------------------------------------------------------------------
--    INCLUDE_DMA : if (C_DMA_PRESENT = True) generate
--       
--       constant RX_LEN_FIFO_BAR     : INTEGER := CONV_INTEGER (C_RXL_FIFO_BAR);  --  Cooresponds to the IP RX Length FIFO address
--       constant TX_LEN_FIFO_BAR     : INTEGER := CONV_INTEGER (C_TXL_FIFO_BAR);  --  Cooresponds to the IP TX Length FIFO address
--       constant TX_STAT_FIFO_BAR    : INTEGER := CONV_INTEGER (C_TXS_FIFO_BAR);  --  Cooresponds to the IP TX Status FIFO address
--       constant RX_STAT_FIFO_BAR    : INTEGER := CONV_INTEGER (C_RXS_FIFO_BAR);  --  Cooresponds to the IP RX Status FIFO address
--       constant DMA_LENGTH_MS_INDEX : INTEGER := C_OPB_DBUS_WIDTH -
--                                                 C_DMA_MAX_LENGTH_SIZE;
--       begin
--       
--       DMA_SG_Controller: dma_sg
--       generic map (C_OPB_DBUS_WIDTH,
--                    C_OPB_ABUS_WIDTH,
--                    C_M,
--                    C_B,
--                    C_OPB_CLK_PERIOD_PS,
--                    C_SG_PACKET_WAIT_UNIT_NS,
--                    (C_DMA_CH1_TYPE, C_DMA_CH2_TYPE),
--                    (DMA_LENGTH_MS_INDEX, DMA_LENGTH_MS_INDEX),
--                    (TX_LEN_FIFO_BAR, RX_LEN_FIFO_BAR),
--                    (TX_STAT_FIFO_BAR, RX_STAT_FIFO_BAR),
--                    (C_DMA_INTR_COALESCE, C_DMA_INTR_COALESCE),
--                    (C_DMA_BLK_ID, C_DMA_BLK_ID),
--                    C_DMA_BAR,
--                    C_DMA_ALLOW_BURST)
--         port map (
--                   DMA2Bus_Data          => DMA2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
--                   DMA2Bus_Addr          => DMA2Bus_Addr(0 to C_OPB_ABUS_WIDTH - 1),
--                   DMA_MstBE             => DMA_MstBE(0 to C_B - 1),
--                   DMA_MstWrReq          => DMA_MstWrReq,
--                   DMA_MstRdReq          => DMA_MstRdReq,
--                   DMA_MstBurst          => DMA_MstBurst,
--                   DMA_MstBusLock        => DMA_MstBusLock,
--                   DMA2IP_Addr           => DMA2IP_Addr(0 to C_M - 1),
--                   DMA_WrAck             => DMA_SG_WrAck,
--                   DMA_RdAck             => DMA_SG_RdAck,
--                   DMA_Retry             => DMA_SG_Retry,
--                   DMA_Error             => DMA_SG_Error,
--                   DMA_ToutSup           => DMA_SG_ToutSup,
--                   Bus2IP_MstWrAck_i     => Bus2IP_MstWrAck_i,
--                   Bus2IP_MstRdAck_i     => Bus2IP_MstRdAck_i,
--                   Mstr_sel_ma           => Mstr_sel_ma,
--                   Bus2IP_MstRetry_i     => Bus2IP_MstRetry_i,
--                   Bus2IP_MstError_i     => Bus2IP_MstError_i,
--                   Bus2IP_MstTimeOut_i   => Bus2IP_MstTimeOut_i,
--                   Bus2IP_BE_sa          => Bus2IP_BE_sa(0 to C_B - 1),
--                   Bus2IP_WrReq_sa       => Bus2IP_WrReq_sa,
--                   Bus2IP_RdReq_sa       => Bus2IP_RdReq_sa,
--                   Bus2IP_Clk_i          => Bus2IP_Clk_i,
--                   Bus2IP_Reset_i        => Bus2IP_Reset_i,
--                   Bus2IP_Freeze_i       => Bus2IP_Freeze_i,
--                   Bus2IP_Addr_i         => Bus2IP_Addr_i(0 to C_M - 1),
--                   Bus2IP_Data_sa        => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
--                   Bus2IP_Burst_sa       => Bus2IP_Burst_sa,
--                   WFIFO2DMA_Vacancy     => WFIFO2DMA_Vacancy(0 to 9),
--                   Bus2IP_MstLastAck_i   => Bus2IP_MstLastAck_i,
--                   DMA_RdCE              => DMA_RdCE,
--                   DMA_WrCE              => DMA_WrCE,
--                   IP2DMA_RxStatus_Empty => IP2DMA_RxStatus_Empty,
--                   IP2DMA_RxLength_Empty => IP2DMA_RxLength_Empty,
--                   IP2DMA_TxStatus_Empty => IP2DMA_TxStatus_Empty,
--                   IP2DMA_TxLength_Full  => IP2DMA_TxLength_Full,
--                   IP2Bus_DMA_Req        => IP2Bus_DMA_Req,
--                   Bus2IP_DMA_Ack        => Bus2IP_DMA_Ack,
--                   DMA2Intr_Intr         => DMA2Intr_Intr(0 to 1));
--                 
--                 
--      end generate INCLUDE_DMA; 
--                 
              
              
--    ------------------------------------------------------------------------------
--    -- Don't include DMA in the IPIF . Drive all outputs to zero.
--    ------------------------------------------------------------------------------
--   
--    REMOVE_DMA : if (C_DMA_PRESENT = False) generate
--   
--           Bus2IP_DMA_Ack      <=  '0';    
--           DMA2Bus_Addr        <=  (others => '0');    
--           DMA2Bus_Data        <=  (others => '0');    
--           DMA2Intr_Intr       <=  (others => '0');    
--           DMA2IP_Addr         <=  (others => '0');    
--           DMA_MstBE           <=  (others => '0');    
--           DMA_MstBurst        <=  '0';    
--           DMA_MstBusLock      <=  '0';    
--           DMA_MstRdReq        <=  '0';    
--           DMA_MstWrReq        <=  '0';    
--           DMA_SG_Error        <=  '0';    
--           DMA_SG_RdAck        <=  '0';    
--           DMA_SG_Retry        <=  '0';    
--           DMA_SG_ToutSup      <=  '0';    
--           DMA_SG_WrAck        <=  '0';    
--    
--    
--      end generate REMOVE_DMA; 
--   
              
              
end implementation;

