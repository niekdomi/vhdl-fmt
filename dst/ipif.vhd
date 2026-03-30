-------------------------------------------------------------------------------
-- $Id: ipif.vhd,v 1.6 2001/11/30 21:35:11 ostlerf Exp $
-------------------------------------------------------------------------------
-- ipif.vhd -  Version v1.22a           
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        ipif.vhd
--
-- Description:     This is the top level design file for the Mauna Loa IPIF
--                  function It provides a standardized interface between the
--                  IP and the OPB Bus. It also provides data transfer support
--                  via DMA, Scatter/Gather, and fifo buffering.
--                  
--
-------------------------------------------------------------------------------
-- Structure:   
--
--                  ipif.vhd
--                    \
--                    \-- reset_control.vhd
--                    \      ipif_reset.vhd
--                    \
--                    \
--                    \-- interrupt_control.vhd
--                    \
--                    \-- bus2ip_amux.vhd                            
--                    \   
--                    \-- ip2bus_dmux.vhd                  
--                    \      ip2bus_dmux.vhd       
--                    \                     
--                    \-- ip2bus_srmux.vhd         
--                    \      ip2bus_srmux.vhd              
--                    \                  
--                    \-- addr_decode.vhd                   
--                    \          sramdecode.vhd                 
--                    \          regdecode.vhd 
--                    \                        
--                    \-- slave_attachment.vhd                     
--                    \                   
--                    \-- master_attachment.vhd
--                    \      mst_attach.vhd       
--                    \  
--                    \-- dma_sg_blk.vhd
--                    \      dma_sg_pkg.vhd 
--                    \      dma_sg_cmp.vhd
--                    \      dma_sg.vhd
--                    \         dma_sg_sim.vhd    
--                    \            srl_fifo.vhd      
--                    \            ctrl_reg.vhd
--                    \            ld_arith_reg.vhd      
--                    \   
--                    \-- rdfifo.vhd                      
--                    \      rpfifo_top.vhd             
--                    \          ipif_control_rd.vhd      
--                    \          rdpfifo_dp_cntl.vhd        
--                    \    
--                    \          dp512x32_v3_2_rden_ve.edn  
--                    \             or
--                    \          dp512x32_v3_2_rden_vii.edn  
--                    \                  
--                    \                      
--                    \-- wrfifo.vhd                            
--                    \     wpfifo_top.vhd                   
--                    \          ipif_control_wr.vhd          
--                    \          wrpfifo_dp_cntl.vhd          
--                    \    
--                    \          dp512x32_v3_2_rden_ve.edn  
--                    \             or
--                    \          dp512x32_v3_2_rden_vii.edn  
--                                          
--                                                  
-------------------------------------------------------------------------------
-- Author:      <Farrell Ostler, Mike Lovejoy, and Doug Thorpe>
--
-- History:
--
--  D. Thorpe   Aug-16-2001    -- Version v1.22a
--
--  DET         Aug-23-2001    -- no version change
--              - corrected some file header errors
--              - corrected some generic default values
--  
--  DET         Aug-29-2001    -- no version change
--              - corrected the spelling of the C_VIRTEX_II parameter
--  
--  FO          Sep-26-2001
--              - Adapted to the wrapper-removed, generic-adjusted
--                versions of slave_attachment and addr_decode generated
--                by AS.
--  
--  ALS         Sep-27-2001
--              - added ipif_pkg which contains log2 function
--              - changed the address widths of SRAM, WRFIFO, and RDFIFO to
--                log2 of their size
--              - changed the data widths of SRAM, WRFIFO, and RDFIFO to 
--                represent the number of bits instead of the number of bytes
--                and made these constants set to the C_IPIF_DBUS_WIDTH generic
--
--  FO          Oct-15-2001
--              - Simplified address calculations for generics.
--              - Removed dependency of arithmetic into msb to get past XST.
--
--  FO          Oct-16-2001
--              - Fixed assertion checking low-order zeroes for C_DEV_BASEADDR.
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
-------------------------------------------------------------------------------
library IEEE;
use IEEE.Std_Logic_1164.all;
use ieee.STD_LOGIC_UNSIGNED.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.dma_sg_pkg.all;
use opb_ipif_v1_23_a.dma_sg_cmp.all;
use opb_ipif_v1_23_a.ipif_pkg.all;
-------------------------------------------------------------------------------


entity ipif is
  generic (
           C_DEV_BLK_ID : INTEGER := 1;  
                    --  Platform Builder Assiged Device ID number (unique
                    --  for each device)
                    
           C_DEV_MIR_ENABLE : BOOLEAN := true;  
                    --  Used to Enable/Disable Module ID functions
                    
           C_DEV_ADDR_DECODE_WIDTH : INTEGER := 4;  
                    -- Number of upper order OPB Address Bus bits used for
                    -- device OPB selection
                    
           C_DEV_BASEADDR : std_logic_vector := X"80000000";  
                    -- Assigned Base Address for this device (system byte 
                    --address)
                    
           C_DEV_BURST_ENABLE : BOOLEAN := false;  
                    -- Burst Enable for IPIF Interface
                    
           C_DEV_MAX_BURST_SIZE : INTEGER := 64;  
                    -- Maximum burst size to be supported (in bytes)
                    
           C_RESET_PRESENT : BOOLEAN := false;  
                    -- 'true' specifies inclusion of the IPIF S/W Reset function
                    
           C_INTERRUPT_PRESENT : BOOLEAN := false;  
                    -- 'true' specifies inclusion of the IPIF Interrupt 
                    -- Support function

           C_INCLUDE_DEV_ISC : BOOLEAN := true;
                    -- 'true' specifies that the full device interrupt
                    -- source controller structure will be included;
                    -- 'false' specifies that only the global interrupt
                    -- enable is present in the device interrupt source
                    -- controller and that the only source of interrupts
                    -- in the device is the IP interrupt source controller

           C_INCLUDE_DEV_PENCODER : BOOLEAN := false;  
                    -- 'true' will include the Device IID in the IPIF Interrupt
                    -- function
                    
           C_IP_MASTER_PRESENT : BOOLEAN := false;  
                    -- 'true' specifies that the IP has Bus Master capability
                    
           C_IP_REG_PRESENT : BOOLEAN := false;  
                    -- 'true' specifies that the IP has register(s) needing 
                    -- address decoding
                    
           C_IP_REG_BASEADDR_OFFSET : std_logic_vector := X"00000044";  
                    -- The address offset of the start of the IP registers from
                    -- Device BAR (in bytes)
                    
           C_IP_REG_NUM : INTEGER := 1;  
                    -- Number of required IP register chip enables.
                    
           C_IP_IRPT_NUM : INTEGER := 22;  
                    -- Number of required IP Interrupts to IPIF Interrupt function
                    
           C_IP_SRAM_PRESENT : BOOLEAN := false;  
                    -- 'true' specifies that the IP requires SRAM type 
                    -- chip enables
                    
           C_IP_SRAM_BASEADDR_OFFSET : std_logic_vector := X"00001000";
                    --  The address offset from Device BAR (in bytes) of the 
                    --  start of the SRAM decode
                    
           C_IP_SRAM_SIZE : INTEGER := 256;  
                    --  The required size of decoded SRAM space (in bytes)
                    
           C_WRFIFO_PRESENT : BOOLEAN := false;  
                    --  'true' specifies that a WrFIFO is required
                    
           C_WRFIFO_BASEADDR_OFFSET : std_logic_vector := X"00002100"; 
                    --  The address offset from Device BAR (in bytes)
                    
           C_WRFIFO_REG_BASEADDR_OFFSET : std_logic_vector := X"00002000"; 
                    --  The address offset from Device BAR (in bytes)
                    
           C_RDFIFO_PRESENT : BOOLEAN := false;  
                    --  'true' specifies that a RdFIFO is required
                    
           C_RDFIFO_BASEADDR_OFFSET : std_logic_vector := X"00002200";  
                    --  The address offset from Device BAR (in bytes)
                    
           C_RDFIFO_REG_BASEADDR_OFFSET : std_logic_vector := X"00002010"; 
                    --  The address offset from Device BAR (in bytes)
                    
           C_DMA_PRESENT : BOOLEAN := false;  
                    --  'true' specifies that a DMA function is required
                    
           C_DMA_REG_BASEADDR_OFFSET : std_logic_vector := X"00002300";  
                    --  The address offset from Device BAR (in bytes)
                    
           C_DMA_CHAN_NUM : INTEGER := 2;  
                    --  The number of desired DMA/SG channels (1 or 2)
                    
           C_DMA_CH1_TYPE : INTEGER := 2; 
                    --  0 = Simple DMA, 1 = SG, 2 = Tx, 3 = Rx
                    
           C_DMA_CH2_TYPE : INTEGER := 3;  
                    --  0 = Simple DMA, 1 = SG, 2 = Tx, 3 = Rx
                    
           C_DMA_ALLOW_BURST : BOOLEAN := true;  
                    -- 'true' allows DMA to initiate burst transfers, 'false'
                    -- inhibits DMA initiated bursts
                    
           C_DMA_LENGTH_WIDTH : INTEGER := 11;  
                    --  Maximum number of bits to use for DMA/SG 'Length" 
                    --  parameters
                    
           C_DMA_INTR_COALESCE : BOOLEAN := true;  
                    --  'true' specifies that the DMA/SG interrupt coalescing
                    --  feature is enabled
                    
           C_DMA_PACKET_WAIT_UNIT_NS : INTEGER := 1000000;  
                    -- Specifies the length of time of the basic unit of the
                    -- DMA PWB register
                    
           C_DMA_TXL_FIFO_IPCE : INTEGER := 8;  
                    --  The IP Reg CE number selecting the TXLength FIFO
                    
           C_DMA_TXS_FIFO_IPCE : INTEGER := 9;  
                    --  The IP Reg CE number selecting the TXStatus FIFO
                    
           C_DMA_RXL_FIFO_IPCE : INTEGER := 7;  
                    --  The IP Reg CE number selecting the RXLength FIFO
                    
           C_DMA_RXS_FIFO_IPCE : INTEGER := 15;  
                    --  The IP Reg CE number selecting the RXSTATUS FIFO
                    
           C_OPB_ABUS_WIDTH : INTEGER := 32;  
                    --  width of OPB Address Bus (in bits)
                    
           C_OPB_DBUS_WIDTH : INTEGER := 32;  
                    --  Width of the OPB Data Bus (in bits)
                    
           C_OPB_BE_NUM : INTEGER := 4;  
                    --  Number of OPB Bus byte enables used
                    
           C_OPB_CLK_PERIOD_PS : INTEGER := 10000;  
                    --  The period of the OPB Bus clock in ps (10000 = 10ns)
                    
           C_IPIF_ABUS_WIDTH : INTEGER := 26;
                    -- The number of low-order host-bus address bits that form
                    -- the byte address, Bus2IP_Addr(0 to C_IPIF_ABUS_WIDTH-1),
                    -- that is used by the IP (and IPIF-resident services).
                    -- Set this to C_OPB_ABUS_WIDTH - C_DEV_ADDR_DECODE_WIDTH-u,
                    -- where u is the number of host-bus address bits to be
                    -- left undecoded. C_IPIF_ABUS_WIDTH must be large enough
                    -- that all addresses to which the device responds
                    -- are differentiated from each other.

           C_IPIF_DBUS_WIDTH : INTEGER := 32;  
                    --  Set this equal to C_OPB_DBUS_WIDTH
                    
           C_VIRTEX_II : Boolean := false
                    -- Select the target architecture type
                    -- true = Virtex II, false = Virtex E
           );
  port (
        OPB_ABus : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) := (others
         => '0');
         
        OPB_DBus : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 ) := (others
         => '0');
        
        Sln_DBus : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        
        Mn_ABus : out std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
        
        IP2Bus_Addr : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) := (others
         => '0');
        
        Bus2IP_Addr : out std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 );
        
        Bus2IP_Data : out std_logic_vector(0 to C_IPIF_DBUS_WIDTH - 1 );
        
        Bus2IP_Reg_RdCE : out std_logic_vector(0 to C_IP_REG_NUM - 1 );
        
        Bus2IP_Reg_WrCE : out std_logic_vector(0 to C_IP_REG_NUM - 1 );
        
        Bus2IP_SRAM_CE : out std_logic;
        
        IP2Bus_Data : in std_logic_vector(0 to C_IPIF_DBUS_WIDTH - 1 ) := (
        others  => '0');
        
        IP2Bus_WrAck : in std_logic := '0';
        
        IP2Bus_RdAck : in std_logic := '0';
        
        IP2Bus_Retry : in std_logic := '0';
        
        IP2Bus_Error : in std_logic := '0';
        
        IP2Bus_ToutSup : in std_logic := '0';
        
        IP2DMA_RxLength_Empty : in std_logic := '0';
        
        IP2DMA_RxStatus_Empty : in std_logic := '0';
        
        IP2DMA_TxLength_Full : in std_logic := '0';
        
        IP2DMA_TxStatus_Empty : in std_logic := '0';
        
        IP2IP_Addr : in std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) := (others
         => '0');
        
        IP2RFIFO_Data : in std_logic_vector(0 to 31 ) := (others  => '0');
        
        IP2RFIFO_WrMark : in std_logic := '0';
        
        IP2RFIFO_WrRelease : in std_logic := '0';
        
        IP2RFIFO_WrReq : in std_logic := '0';
        
        IP2RFIFO_WrRestore : in std_logic := '0';
        
        IP2WFIFO_RdMark : in std_logic := '0';
        
        IP2WFIFO_RdRelease : in std_logic := '0';
        
        IP2WFIFO_RdReq : in std_logic := '0';
        
        IP2WFIFO_RdRestore : in std_logic := '0';
        
        IP2Bus_MstBE : in std_logic_vector(0 to C_OPB_BE_NUM - 1 ) := (others
         => '0');
        
        IP2Bus_MstWrReq : in std_logic := '0';
        
        IP2Bus_MstRdReq : in std_logic := '0';
        
        IP2Bus_MstBurst : in std_logic := '0';
        
        IP2Bus_MstBusLock : in std_logic := '0';
        
        Bus2IP_MstWrAck : out std_logic;
        
        Bus2IP_MstRdAck : out std_logic;
        
        Bus2IP_MstRetry : out std_logic;
        
        Bus2IP_MstError : out std_logic;
        
        Bus2IP_MstTimeOut : out std_logic;
        
        Bus2IP_MstLastAck : out std_logic;
        
        Bus2IP_BE : out std_logic_vector(0 to C_OPB_BE_NUM - 1 );
        
        Bus2IP_WrReq : out std_logic;
        
        Bus2IP_RdReq : out std_logic;
        
        Bus2IP_Burst : out std_logic;
        
        Mn_request : out std_logic;
        
        Mn_busLock : out std_logic;
        
        Mn_select : out std_logic;
        
        Mn_RNW : out std_logic;
        
        Mn_BE : out std_logic_vector(0 to C_OPB_BE_NUM - 1 );
        
        Mn_seqAddr : out std_logic;
        
        OPB_MnGrant : in std_logic := '0';
        
        OPB_xferAck : in std_logic := '0';
        
        OPB_errAck : in std_logic := '0';
        
        OPB_retry : in std_logic := '0';
        
        OPB_timeout : in std_logic := '0';
        
        Freeze : in std_logic := '0';
        
        RFIFO2IP_AlmostFull : out std_logic;
        
        RFIFO2IP_Full : out std_logic;
        
        RFIFO2IP_Vacancy : out std_logic_vector(0 to 9 );
        
        RFIFO2IP_WrAck : out std_logic;
        
        OPB_select : in std_logic := '0';
        
        OPB_RNW : in std_logic := '0';
        
        OPB_seqAddr : in std_logic := '0';
        
        OPB_BE : in std_logic_vector(0 to C_OPB_BE_NUM - 1 ) := (others  => '0');
        
        Sln_xferAck : out std_logic;
        
        Sln_errAck : out std_logic;
        
        Sln_toutSup : out std_logic;
        
        Sln_retry : out std_logic;
        
        WFIFO2IP_AlmostEmpty : out std_logic;
        
        WFIFO2IP_Data : out std_logic_vector(0 to 31 );
        
        WFIFO2IP_Empty : out std_logic;
        
        WFIFO2IP_Occupancy : out std_logic_vector(0 to 9 );
        
        WFIFO2IP_RdAck : out std_logic;
        
        Bus2IP_Clk : out std_logic;
        
        Bus2IP_DMA_Ack : out std_logic;
        
        Bus2IP_Freeze : out std_logic;
        
        Bus2IP_Reset : out std_logic;
        
        IP2Bus_Clk : in std_logic := '0';
        
        IP2Bus_DMA_Req : in std_logic := '0';
        
        IP2Bus_IntrEvent : in std_logic_vector(0 to C_IP_IRPT_NUM - 1 ) := (
        others  => '0');
        
        IP2INTC_Irpt : out std_logic;
        
        OPBClk : in std_logic := '0';
        
        Reset : in std_logic := '0'
        );
 
 
end ipif;

 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Architecture


 
architecture implementation of ipif is

    
 -- MIR Constants
  
  constant IPIF_MAJOR_VERSION : INTEGER range 0 to 15 := 1;  
            --  set Major Version of this IPIF here (reflected in IPIF MIR)
            --  Now set to Major Version 1 for v1.22b
  
  constant IPIF_MINOR_VERSION : INTEGER range 0 to 127:= 23;  
            --  set Minor Version of this IPIF here (reflected in IPIF MIR)
            --  Example: 21(dec) = minor version '22'
            --  Now set to 22 for v1.22a
  
  constant IPIF_REVISION : INTEGER := 0;  
            --  set Revision of this IPIF here (reflected in IPIF MIR)
            --  0 = a, 1 = b, 2 = c, etc.
            --  Now set to 0 (which is a) for v1.22a
            
  constant IPIF_TYPE : INTEGER := 1;  
            --  set interface type for this IPIF here (reflected in IPIF MIR)
            --  Always '1' for OPB ipif interface type
  
  
  
 -- Other constants 
  
  constant LOGIC_LOW : std_logic := '0';

  constant ZERO_IPIF_ABUS_WIDTH
                     : std_logic_vector(C_DEV_ADDR_DECODE_WIDTH to
                                        C_OPB_ABUS_WIDTH-1)
                     := (others => '0');
  
  
        constant INTERRUPT_REG_BASEADDR_OFFSET
                     : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1)
                     := x"00000000";

        constant RESET_REG_BASEADDR_OFFSET
                     : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1)
                     := x"00000040";
  
  constant INTERRUPT_REG_NUM : INTEGER := 16;  
            --  Number of Interrupt module register CE (fixed at 16)
  
  constant INTERRUPT_REG_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       INTERRUPT_REG_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                              to C_OPB_ABUS_WIDTH - 1);
  
  constant SLN_BUFFER_DEPTH : INTEGER := C_DEV_MAX_BURST_SIZE / 4;  
            --  IPIF read buffer size for Burst reads (in bus words)
  
  constant RESET_REG_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       RESET_REG_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                        to C_OPB_ABUS_WIDTH - 1);
  
  
  constant REG_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       C_IP_REG_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                       to C_OPB_ABUS_WIDTH - 1);
  constant IP_REG_BASEADDR : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) := 
               C_DEV_BASEADDR(0 to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1) & REG_BASE;
 
  
  constant SRAM_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                        C_IP_SRAM_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                        to C_OPB_ABUS_WIDTH - 1);
  

  constant WRFIFO_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                         C_WRFIFO_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                         to C_OPB_ABUS_WIDTH - 1);

  constant WRFIFO_REG_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       C_WRFIFO_REG_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                           to C_OPB_ABUS_WIDTH - 1);
  
  constant RDFIFO_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       C_RDFIFO_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                       to C_OPB_ABUS_WIDTH - 1);
  

  constant RDFIFO_REG_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       C_RDFIFO_REG_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                           to C_OPB_ABUS_WIDTH - 1);
  
  
  constant DMA_BASE : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 ) :=
                       C_DMA_REG_BASEADDR_OFFSET(   C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH
                                        to C_OPB_ABUS_WIDTH - 1);

  constant DMA_REG_BASEADDR : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) := 
               C_DEV_BASEADDR(0 to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1) & DMA_BASE;
  

  constant INT_DMA_REG_SIZE : INTEGER := C_DMA_CHAN_NUM * 64;
  
  
  constant IP_TXL_FIFO_BASEADDR : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) :=
                 C_DEV_BASEADDR(0 to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1)
               & (  C_IP_REG_BASEADDR_OFFSET(C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH to
                                             C_OPB_ABUS_WIDTH - 1
                                            )
                  + C_DMA_TXL_FIFO_IPCE*4
                 );
  
  constant IP_TXS_FIFO_BASEADDR : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) :=
                 C_DEV_BASEADDR(0 to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1)
               & (  C_IP_REG_BASEADDR_OFFSET(C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH to
                                             C_OPB_ABUS_WIDTH - 1
                                            )
                  + C_DMA_TXS_FIFO_IPCE*4
                 );
  
  constant IP_RXS_FIFO_BASEADDR : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) :=
                 C_DEV_BASEADDR(0 to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1)
               & (  C_IP_REG_BASEADDR_OFFSET(C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH to
                                             C_OPB_ABUS_WIDTH - 1
                                            )
                  + C_DMA_RXS_FIFO_IPCE*4
                 );
  
  constant IP_RXL_FIFO_BASEADDR : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 ) :=
                 C_DEV_BASEADDR(0 to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1)
               & (  C_IP_REG_BASEADDR_OFFSET(C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH to
                                             C_OPB_ABUS_WIDTH - 1
                                            )
                  + C_DMA_RXL_FIFO_IPCE*4
                 );
  
  constant DEV_IS_SLAVE_ONLY : BOOLEAN := not(C_DMA_PRESENT or
                                          C_IP_MASTER_PRESENT);
  
  constant DEV_NEEDS_MASTER : BOOLEAN := C_DMA_PRESENT or C_IP_MASTER_PRESENT;
  
  constant DMA_USE_BURST : BOOLEAN := C_DMA_ALLOW_BURST and C_DEV_BURST_ENABLE;
  
-- Set the data widths of the various IPIF submodules
  constant REG_DATA_WIDTH           : integer   := C_IPIF_DBUS_WIDTH;
  constant SRAM_DATA_WIDTH          : integer   := C_IPIF_DBUS_WIDTH;
  constant WRFIFO_DATA_WIDTH        : integer   := C_IPIF_DBUS_WIDTH;
  constant WRFIFO_REG_DATA_WIDTH    : integer   := C_IPIF_DBUS_WIDTH;
  constant RDFIFO_DATA_WIDTH        : integer   := C_IPIF_DBUS_WIDTH;
  constant RDFIFO_REG_DATA_WIDTH    : integer   := C_IPIF_DBUS_WIDTH;
  constant DMA_SRAM_DATA_WIDTH      : integer   := C_IPIF_DBUS_WIDTH;
  constant INTERRUPT_REG_DATA_WIDTH : integer   := C_IPIF_DBUS_WIDTH;
  constant IP_RESET_REG_DATA_WIDTH  : integer   := C_IPIF_DBUS_WIDTH;

-- Calculate the number of address bits required to represent the depth of the 
-- various IPIF submodules
  constant SRAM_ADDR_WIDTH          : integer   := log2(C_IP_SRAM_SIZE);
  constant WRFIFO_ADDR_WIDTH        : integer   := log2(C_DEV_MAX_BURST_SIZE);
  constant RDFIFO_ADDR_WIDTH        : integer   := log2(C_DEV_MAX_BURST_SIZE);
  -- Farrell, please check the constant below - ALS
  constant DMA_SRAM_ADDR_WIDTH      : integer   := log2(INT_DMA_REG_SIZE);
  
  -- signal used as a constant (when constant fails to be a globally
  -- static expression).
  signal CONST_ALL_IP_BYTES_ENABLED :
      std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1) := (others => '1');

 -- Signal declarations
  signal Addr_Cntr_ClkEN_sa : std_logic;
  signal Addr_sel_sa : std_logic_vector(0 to 1 );
  signal Asyn_SRAM_RdCE : std_logic;
  signal Asyn_SRAM_WrCE : std_logic;
  signal Bus2IP_Addr_i : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 );
  signal Bus2IP_Addr_sa : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 );
  signal Bus2IP_BE_sa : std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 - 1 );
  signal Bus2IP_BE_i  : std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 - 1 );
  signal Bus2IP_Burst_sa : std_logic;
  signal Bus2IP_Clk_i : std_logic;
  signal Bus2IP_Data_sa : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal Bus2IP_Freeze_i : std_logic;
  signal Bus2IP_MstError_i : std_logic;
  signal Bus2IP_MstLastAck_i : std_logic;
  signal Bus2IP_MstRdAck_i : std_logic;
  signal Bus2IP_MstRetry_i : std_logic;
  signal Bus2IP_MstTimeOut_i : std_logic;
  signal Bus2IP_MstWrAck_i : std_logic;
  signal Bus2IP_RangeSel_sa : std_logic;
  signal Bus2IP_RdReq_sa : std_logic;
  signal Bus2IP_Reset_i : std_logic;
  signal Bus2IP_RNW_sa : std_logic;
  signal Bus2IP_WrReq_sa : std_logic;
  signal Bus_MnGrant : std_logic;
  signal Bus_Reset_i : std_logic;
  signal const_zero : std_logic := '0';
  signal DMA2Bus_Addr : std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
  signal DMA2Bus_Data : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal DMA2Intr_Intr : std_logic_vector(0 to 1 );
  signal DMA2IP_Addr : std_logic_vector(0 to C_IPIF_ABUS_WIDTH - 1 );
  signal DMA_MstBE : std_logic_vector(0 to C_OPB_BE_NUM - 1 );
  signal DMA_MstBurst : std_logic;
  signal DMA_MstBusLock : std_logic;
  signal DMA_MstRdReq : std_logic;
  signal DMA_MstWrReq : std_logic;
  signal DMA_RdCE : std_logic;
  signal DMA_SG_Error : std_logic;
  signal DMA_SG_RdAck : std_logic;
  signal DMA_SG_Retry : std_logic;
  signal DMA_SG_ToutSup : std_logic;
  signal DMA_SG_WrAck : std_logic;
  signal DMA_WrCE : std_logic;
  signal Interrupt_RdCE : std_logic_vector(0 to INTERRUPT_REG_NUM - 1 );
  signal Interrupt_WrCE : std_logic_vector(0 to INTERRUPT_REG_NUM - 1 );
  signal Intr2Bus_DBus : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal Intr2Bus_DevIntr : std_logic;
  signal Intr2Bus_Error : std_logic;
  signal Intr2Bus_RdAck : std_logic;
  signal Intr2Bus_Retry : std_logic;
  signal Intr2Bus_ToutSup : std_logic;
  signal Intr2Bus_WrAck : std_logic;
  signal IP2Bus_Data_sa : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal IP2Bus_Error_sa : std_logic;
  signal IP2Bus_RdAck_sa : std_logic;
  signal IP2Bus_Retry_sa : std_logic;
  signal IP2Bus_ToutSup_sa : std_logic;
  signal IP2Bus_WrAck_sa : std_logic;
  signal IP_Reset_RdCE : std_logic;
  signal IP_Reset_WrCE : std_logic;
  signal IPIF_Lvl_Interrupts : std_logic_vector(0 to 3 );
  signal IPIF_Reg_Interrupts : std_logic_vector(0 to 1 );
  signal MA2SA_num : std_logic_vector(0 to 3 );
  signal MA2SA_Rd : std_logic;
  signal MA2SA_select : std_logic;
  signal MA2SA_XferAck : std_logic;
  signal Mstr_sel_ma : std_logic;
  signal RdFIFO2Bus_Data : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal RdFIFO2Intr_DeadLock : std_logic;
  signal RdFIFO_RdCE : std_logic;
  signal RdFIFO_Reg_RdCE : std_logic_vector(0 to 1 );
  signal RdFIFO_Reg_WrCE : std_logic_vector(0 to 1 );
  signal RdFIFO_WrCE : std_logic;
  signal Reset2Bus_DBus : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal RFIFO2DMA_AlmostEmpty : std_logic;
  signal RFIFO2DMA_Empty : std_logic;
  signal RFIFO2DMA_Occupancy : std_logic_vector(0 to 9 );
  signal RFIFO_Error : std_logic;
  signal RFIFO_RdAck : std_logic;
  signal RFIFO_Retry : std_logic;
  signal RFIFO_ToutSup : std_logic;
  signal RFIFO_WrAck : std_logic;
  signal Rst2Bus_Error : std_logic;
  signal Rst2Bus_RdAck : std_logic;
  signal Rst2Bus_Retry : std_logic;
  signal Rst2Bus_ToutSup : std_logic;
  signal Rst2Bus_WrAck : std_logic;
  signal SA2MA_RdRdy : std_logic;
  signal SA2MA_WrAck : std_ulogic;
  signal WFIFO2DMA_AlmostFull : std_logic;
  signal WFIFO2DMA_Full : std_logic;
  signal WFIFO2DMA_Vacancy : std_logic_vector(0 to 9 );
  signal WFIFO_Error : std_logic;
  signal WFIFO_RdAck : std_logic;
  signal WFIFO_Retry : std_logic;
  signal WFIFO_ToutSup : std_logic;
  signal WFIFO_WrAck : std_logic;
  signal WrFIFO2Bus_Data : std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
  signal WrFIFO2Intr_DeadLock : std_logic;
  signal WrFIFO_RdCE : std_logic;
  signal WrFIFO_Reg_RdCE : std_logic_vector(0 to 1 );
  signal WrFIFO_Reg_WrCE : std_logic_vector(0 to 1 );
  signal WrFIFO_WrCE : std_logic;
  
  
  
-------------------------------------------------------------------------------  
-- components 
  
  component master_attachment
      generic (
               C_OPB_ABUS_WIDTH : INTEGER := 32;
               C_OPB_DBUS_WIDTH : INTEGER := 32;
               C_B : INTEGER := 4;
               C_MA2SA_NUM_WIDTH : INTEGER := 4
               );
      port (
            Bus2IP_Clk_i : in std_logic;
            Bus2IP_MstError_i : out std_logic;
            Bus2IP_MstLastAck_i : out std_logic;
            Bus2IP_MstRdAck_i : out std_logic;
            Bus2IP_MstRetry_i : out std_logic;
            Bus2IP_MstTimeOut_i : out std_logic;
            Bus2IP_MstWrAck_i : out std_logic;
            Bus_MnGrant : out std_logic;
            Bus_Reset_i : in std_logic;
            DMA2BUS_Addr : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
            DMA_MstBE : in std_logic_vector(0 to C_B - 1 );
            DMA_MstBurst : in std_logic;
            DMA_MstBusLock : in std_logic;
            DMA_MstRdReq : in std_logic;
            DMA_MstWrReq : in std_logic;
            IP2Bus_Addr : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
            IP2Bus_MstBE : in std_logic_vector(0 to C_B - 1 );
            IP2Bus_MstBurst : in std_logic;
            IP2Bus_MstBusLock : in std_logic;
            IP2Bus_MstRdReq : in std_logic;
            IP2Bus_MstWrReq : in std_logic;
            MA2SA_num : out std_logic_vector(0 to C_MA2SA_NUM_WIDTH - 1 );
            MA2SA_Rd : out std_logic;
            MA2SA_select : out std_logic;
            MA2SA_XferAck : out std_logic;
            Mn_ABus : out std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
            Mn_BE : out std_logic_vector(0 to C_B - 1 );
            Mn_busLock : out std_logic;
            Mn_request : out std_logic;
            Mn_RNW : out std_logic;
            Mn_select : out std_logic;
            Mn_seqAddr : out std_logic;
            Mstr_sel_ma : out std_logic;
            OPB_errAck : in std_logic;
            OPB_MnGrant : in std_logic;
            OPB_retry : in std_logic;
            OPB_timeout : in std_logic;
            OPB_xferAck : in std_logic;
            SA2MA_RdRdy : in std_logic;
            SA2MA_WrAck : in std_logic
            );
  end component;
  
  
  component addr_decode
    generic (
            C_IPIF_ABUS_WIDTH       : integer;  
            C_IPIF_DBUS_WIDTH       : integer;
            C_SRAM_CE               : boolean := false;     
                                     
            C_SRAM_BASE             : std_logic_vector := "00";
            C_SRAM_ADDR_WIDTH       : integer := 0;
            C_SRAM_DATA_WIDTH       : integer := 0;

            C_REG_CE                : boolean := false;     
            C_REG_BASE              : std_logic_vector := "00";
            C_IP_REG_NUM            : integer := 0;                      
            C_REG_DATA_WIDTH        : integer := 0;    

            C_WRFIFO_CE             : boolean := false;     
            C_WRFIFO_BASE           : std_logic_vector := "00";
            C_WRFIFO_ADDR_WIDTH     : integer := 0;
            C_WRFIFO_DATA_WIDTH     : integer := 0;         
            C_WRFIFO_REG_BASE       : std_logic_vector := "00";
            C_WRFIFO_REG_NUM        : integer := 0;         
            C_WRFIFO_REG_DATA_WIDTH : integer := 0;         

  
            C_RDFIFO_CE             : boolean := false;     
            C_RDFIFO_BASE           : std_logic_vector := "00";
            C_RDFIFO_ADDR_WIDTH     : integer := 0;
            C_RDFIFO_DATA_WIDTH     : integer := 0;         
            C_RDFIFO_REG_BASE       : std_logic_vector := "00";
            C_RDFIFO_REG_NUM        : integer := 0;          
            C_RDFIFO_REG_DATA_WIDTH : integer := 0;          

            C_DMA_CE                : boolean := false;     
            C_DMA_BASE              : std_logic_vector := "00";
            C_DMA_SRAM_ADDR_WIDTH   : integer := 0;
            C_DMA_SRAM_DATA_WIDTH   : integer := 0;          

            C_INTERRUPT_CE          : boolean := false;     
            C_INTERRUPT_REG_BASE    : std_logic_vector := "00";
            C_INTERRUPT_REG_NUM     : integer := 0;          
            C_INTERRUPT_REG_DATA_WIDTH: integer := 0;        

 
            C_IP_RESET_CE           : boolean := false;     
            C_IP_RESET_REG_BASE     : std_logic_vector := "00";
            C_IP_RESET_REG_NUM      : integer := 0;          
            C_IP_RESET_REG_DATA_WIDTH: integer := 0          
            );

    port    (
        Reset               : in std_logic;

        Bus2IP_RangeSel     : in std_logic;
        Bus2IP_Addr_sa      : in std_logic_vector (0 to C_IPIF_ABUS_WIDTH-1);
        Bus2IP_BE_sa        : in std_logic_vector (0 to C_IPIF_DBUS_WIDTH/8-1);

        Bus2IP_RNW_sa       : in std_logic;
        Bus2IP_Clk          : in std_logic;
        Bus2IP_Burst_sa     : in std_logic;

        IP2Bus_WrAck_sa     : in std_logic;
        IP2Bus_RdAck_sa     : in std_logic;


        Asyn_SRAM_WrCE      : out std_logic;
        Asyn_SRAM_RdCE      : out std_logic;
--        Bus2IP_SRAM_WrCE    : out std_logic;
--        Bus2IP_SRAM_RdCE    : out std_logic;
        Bus2IP_SRAM_CE      : out std_logic;

        Bus2IP_Reg_WrCE     : out std_logic_vector (0 to C_IP_REG_NUM-1);
        Bus2IP_Reg_RdCE     : out std_logic_vector (0 to C_IP_REG_NUM-1);

        Asyn_WrFIFO_WrCE    : out std_logic;
        Asyn_WrFIFO_RdCE    : out std_logic;
        WrFIFO_WrCE         : out std_logic;
        WrFIFO_RdCE         : out std_logic;
        WrFIFO_Reg_WrCE     : out std_logic_vector (0 to C_WRFIFO_REG_NUM-1);
        WrFIFO_Reg_RdCE     : out std_logic_vector (0 to C_WRFIFO_REG_NUM-1);

        Asyn_RdFIFO_WrCE    : out std_logic;
        Asyn_RdFIFO_RdCE    : out std_logic;
        RdFIFO_WrCE         : out std_logic;
        RdFIFO_RdCE         : out std_logic;
        RdFIFO_Reg_WrCE     : out std_logic_vector (0 to C_RDFIFO_REG_NUM-1);
        RdFIFO_Reg_RdCE     : out std_logic_vector (0 to C_RDFIFO_REG_NUM-1);

     --   Asyn_DMA_SRAM_WrCE  : out std_logic;
     --   Asyn_DMA_SRAM_RdCE  : out std_logic;
        DMA_WrCE            : out std_logic;
        DMA_RdCE            : out std_logic;

        Interrupt_WrCE      : out std_logic_vector (0 to C_INTERRUPT_REG_NUM-1);
        Interrupt_RdCE      : out std_logic_vector (0 to C_INTERRUPT_REG_NUM-1);

        --IP_Reset_WrCE      : out std_logic_vector (0 to C_IP_RESET_REG_NUM-1);
        --IP_Reset_RdCE      : out std_logic_vector (0 to C_IP_RESET_REG_NUM-1)
        IP_Reset_RdCE       : out std_logic;
        IP_Reset_WrCE       : out std_logic
        );
  end component;

component bus2ip_amux is
  Generic (
           C_IPIF_ABUS_WIDTH    : Integer;
           C_IPIF_DBUS_WIDTH    : integer
          ); 
    port (
       -- Clock and Reset
         Bus2IP_Reset_i     : In  std_logic;
         Bus2IP_Clk_i       : In  std_logic;
       
       -- Select control from the Master Attachment
         Mstr_sel_ma        : In  std_logic;
       
       -- Slave Attachment I/O
         Addr_Cntr_ClkEN_sa  : In  std_logic;
         Addr_sel_sa        : In  std_logic_vector(0 to 1);
         Bus2IP_Addr_sa     : in  std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
    
       -- Address Bus inputs from the IP Master
         IP2IP_Addr         : in  std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
         
       -- Address Bus inputs from the DMA/SG engine
         DMA2IP_Addr        : in  std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
         
       -- IPIF & IP address bus source (AMUX output)
         Bus2IP_Addr_i      : out std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);

       -- Byte-enable channels
         Bus2IP_BE_sa       : in  std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1);
         IP2IP_BE           : in  std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1);
         DMA2IP_BE          : in  std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1);
         Bus2IP_BE_i        : out std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1)

         );
end component;

  
component slave_attachment
    generic (
        C_OPB_ABUS_WIDTH        : integer;        
        C_OPB_DBUS_WIDTH        : integer;           
        C_IPIF_ABUS_WIDTH       : integer;           
        C_IPIF_DBUS_WIDTH       : integer;
        C_DEV_ADDR_DECODE_WIDTH : integer;          
        C_SL_ATT_ADDR_SEL_WIDTH : integer;           
        C_SLAVE_ATT_BASE        : std_logic_vector;  
        C_SLN_BURST             : boolean;           
        C_SLN_ONLY              : boolean;           
        C_MA2SA_NUM_WIDTH       : integer :=4;       
        C_SLN_BUFFER_DEPTH      : integer :=8        
        );
    port(        
        Reset           : in std_logic;
        OPB_Clk         : in std_logic;
        OPB_Select      : in std_logic;
        OPB_RNW         : in std_logic;
        OPB_SeqAddr     : in std_logic;
        OPB_BE          : in std_logic_vector (0 to C_OPB_DBUS_WIDTH/8-1);
        OPB_ABus        : in std_logic_vector (0 to C_OPB_ABUS_WIDTH-1);
        OPB_DBus        : in std_logic_vector (0 to C_OPB_DBUS_WIDTH-1);
        Sln_DBus_gtd    : out std_logic_vector (0 to C_OPB_DBUS_WIDTH-1);
        Sln_XferAck     : out std_logic;
        Sln_ErrAck      : out std_logic;
        Sln_ToutSup     : out std_logic;
        Sln_Retry       : out std_logic;
        Bus_MnGrant     : in std_logic := '0';
        MA2SA_Select    : in std_logic := '0';
        MA2SA_XferAck   : in std_logic := '0';
        MA2SA_Rd        : in std_logic := '0';
        MA2SA_Num       : in std_logic_vector(0 to C_MA2SA_NUM_WIDTH-1)
                             := (others => '0');
        SA2MA_RdRdy     : out std_logic;
        SA2MA_WrAck     : out std_logic;
        Addr_Sel        : out std_logic_vector (0 to C_SL_ATT_ADDR_SEL_WIDTH-1);
        Addr_Cntr_ClkEn : out std_logic;
        Bus2IP_Burst_sa : out std_logic;
        Bus2IP_RNW_sa   : out std_logic;
        Bus2IP_BE_sa    : out std_logic_vector (0 to C_IPIF_DBUS_WIDTH/8-1);
        Bus2IP_Addr_sa  : out std_logic_vector (0 to C_IPIF_ABUS_WIDTH-1);
        Bus2IP_Data_sa  : out std_logic_vector (0 to C_IPIF_DBUS_WIDTH-1);
        Bus2IP_RangeSel : out std_logic;
        Bus2IP_WrReq_sa : out std_logic;
        Bus2IP_RdReq_sa : out std_logic;
        IP2Bus_Data_sa  : in std_logic_vector (0 to C_IPIF_DBUS_WIDTH-1);
        IP2Bus_WrAck_sa : in std_logic;
        IP2Bus_RdAck_sa : in std_logic;
        IP2Bus_ErrAck_sa: in std_logic;
        IP2Bus_ToutSup_sa: in std_logic;
        IP2Bus_Retry_sa : in std_logic
        );
end component;
  

  component ip2bus_dmux_blk
      generic (
               C_DBUS_WIDTH : INTEGER := 32
               );
      port (
            DMA2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
            Intr2Bus_DBus : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
            IP2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
            IP2Bus_Data_sa : out std_logic_vector(0 to C_DBUS_WIDTH - 1 );
            Reset2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
            RFIFO2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 );
            WFIFO2Bus_Data : in std_logic_vector(0 to C_DBUS_WIDTH - 1 )
            );
  end component;
  
  
  component interrupt_control
      generic (
               C_INTERRUPT_REG_NUM : integer := 16;
               C_NUM_IPIF_IRPT_SRC : integer := 4;
               C_NUM_IP_IRPTS : integer := 32;
               C_INCLUDE_DEV_PENCODER : boolean := true;
               C_INCLUDE_DEV_ISC      : boolean := true;
               C_IPIF_DBUS_WIDTH : integer := 32
               );
      port (
            Bus2IP_Clk_i : in std_logic;
            Bus2IP_Data_sa : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            Bus2IP_RdReq_sa : in std_logic;
            Bus2IP_Reset_i : in std_logic;
            Bus2IP_WrReq_sa : in std_logic;
            Interrupt_RdCE : in std_logic_vector(0 to C_INTERRUPT_REG_NUM - 1 );
            Interrupt_WrCE : in std_logic_vector(0 to C_INTERRUPT_REG_NUM - 1 );
            Intr2Bus_DBus : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            Intr2Bus_DevIntr : out std_logic;
            Intr2Bus_Error : out std_logic;
            Intr2Bus_RdAck : out std_logic;
            Intr2Bus_Retry : out std_logic;
            Intr2Bus_ToutSup : out std_logic;
            Intr2Bus_WrAck : out std_logic;
            IP2Bus_IntrEvent : in std_logic_vector(0 to C_NUM_IP_IRPTS - 1 );
            IPIF_Lvl_Interrupts : in std_logic_vector(0 to C_NUM_IPIF_IRPT_SRC -
            1 );
            IPIF_Reg_Interrupts : in std_logic_vector(0 to 1 )
            );
  end component;
  
  
  component reset_control
      generic (
               C_IPIF_MIR_ENABLE : BOOLEAN := True;
               C_IPIF_TYPE : INTEGER := 1;
               C_IPIF_BLK_ID : INTEGER := 255;
               C_IPIF_REVISION : INTEGER := 1;
               C_IPIF_MINOR_VERSION : INTEGER := 0;
               C_IPIF_MAJOR_VERSION : INTEGER := 0;
               C_OPB_DBUS_WIDTH : INTEGER := 32
               );
      port (
            Bus2IP_Clk_i : in std_logic;
            Bus_DBus : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            IP_Reset_RdCE : in std_logic;
            IP_Reset_WrCE : in std_logic;
            Reset : in std_logic;
            Reset2Bus_DBus : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            Reset2Bus_Error : out std_logic;
            Reset2Bus_RdAck : out std_logic;
            Reset2Bus_Retry : out std_logic;
            Reset2Bus_ToutSup : out std_logic;
            Reset2Bus_WrAck : out std_logic;
            Reset2IP_Reset : out std_logic
            );
  end component;
  
  
  component rdfifo
      generic (
               C_OPB_DBUS_WIDTH : INTEGER := 32;
               C_B : INTEGER := 4;
               C_RFIFO_MIR_ENABLE : BOOLEAN := True;
               C_RFIFO_BLK_ID : INTEGER := 255;
               C_VERTEX_II : Boolean := true
               );
      port (
            Bus2IP_BE_sa : in std_logic_vector(0 to C_B - 1 );
            Bus2IP_Burst_sa : in std_logic;
            Bus2IP_Clk_i : in std_logic;
            Bus2IP_Data_sa : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            Bus2IP_RdReq_sa : in std_logic;
            Bus2IP_Reset_i : in std_logic;
            Bus2IP_WrReq_sa : in std_logic;
            IP2RFIFO_Data : in std_logic_vector(0 to 31 );
            IP2RFIFO_WrMark : in std_logic;
            IP2RFIFO_WrRelease : in std_logic;
            IP2RFIFO_WrReq : in std_logic;
            IP2RFIFO_WrRestore : in std_logic;
            RdFIFO2Bus_Data : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            RdFIFO2Intr_DeadLock : out std_logic;
            RdFIFO_RdCE : in std_logic;
            RdFIFO_Reg_RdCE : in std_logic_vector(0 to 1 );
            RdFIFO_Reg_WrCE : in std_logic_vector(0 to 1 );
            RdFIFO_WrCE : in std_logic;
            RFIFO2DMA_AlmostEmpty : out std_logic;
            RFIFO2DMA_Empty : out std_logic;
            RFIFO2DMA_Occupancy : out std_logic_vector(0 to 9 );
            RFIFO2IP_AlmostFull : out std_logic;
            RFIFO2IP_Full : out std_logic;
            RFIFO2IP_Vacancy : out std_logic_vector(0 to 9 );
            RFIFO2IP_WrAck : out std_logic;
            RFIFO_Error : out std_logic;
            RFIFO_RdAck : out std_logic;
            RFIFO_Retry : out std_logic;
            RFIFO_ToutSup : out std_logic;
            RFIFO_WrAck : out std_logic
            );
  end component;
  
  
  component wrfifo
      generic (
               C_OPB_DBUS_WIDTH : INTEGER := 32;
               C_B : INTEGER := 4;
               C_WFIFO_MIR_ENABLE : BOOLEAN := True;
               C_WFIFO_BLK_ID : INTEGER := 254;
               C_VERTEX_II : Boolean := true
               );
      port (
            Bus2IP_BE_sa : in std_logic_vector(0 to C_B - 1 );
            Bus2IP_Burst_sa : in std_logic;
            Bus2IP_Clk_i : in std_logic;
            Bus2IP_Data_sa : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            Bus2IP_RdReq_sa : in std_logic;
            Bus2IP_Reset_i : in std_logic;
            Bus2IP_WrReq_sa : in std_logic;
            IP2WFIFO_RdMark : in std_logic;
            IP2WFIFO_RdRelease : in std_logic;
            IP2WFIFO_RdReq : in std_logic;
            IP2WFIFO_RdRestore : in std_logic;
            WFIFO2DMA_AlmostFull : out std_logic;
            WFIFO2DMA_Full : out std_logic;
            WFIFO2DMA_Vacancy : out std_logic_vector(0 to 9 );
            WFIFO2IP_AlmostEmpty : out std_logic;
            WFIFO2IP_Data : out std_logic_vector(0 to 31 );
            WFIFO2IP_Empty : out std_logic;
            WFIFO2IP_Occupancy : out std_logic_vector(0 to 9 );
            WFIFO2IP_RdAck : out std_logic;
            WFIFO_Error : out std_logic;
            WFIFO_RdAck : out std_logic;
            WFIFO_Retry : out std_logic;
            WFIFO_ToutSup : out std_logic;
            WFIFO_WrAck : out std_logic;
            WrFIFO2Bus_Data : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
            WrFIFO2Intr_DeadLock : out std_logic;
            WrFIFO_RdCE : in std_logic;
            WrFIFO_Reg_RdCE : in std_logic_vector(0 to 1 );
            WrFIFO_Reg_WrCE : in std_logic_vector(0 to 1 );
            WrFIFO_WrCE : in std_logic
            );
  end component;
  
  
  component ip2bus_srmux_blk
      port (
            DMA_SG_Error : in std_logic;
            DMA_SG_RdAck : in std_logic;
            DMA_SG_Retry : in std_logic;
            DMA_SG_ToutSup : in std_logic;
            DMA_SG_WrAck : in std_logic;
            Intr2Bus_Error : in std_logic;
            Intr2Bus_RdAck : in std_logic;
            Intr2Bus_Retry : in std_logic;
            Intr2Bus_ToutSup : in std_logic;
            Intr2Bus_WrAck : in std_logic;
            IP2Bus_Error : in std_logic;
            IP2Bus_Error_sa : out std_logic;
            IP2Bus_RdAck : in std_logic;
            IP2Bus_RdAck_sa : out std_logic;
            IP2Bus_Retry : in std_logic;
            IP2Bus_Retry_sa : out std_logic;
            IP2Bus_ToutSup : in std_logic;
            IP2Bus_ToutSup_sa : out std_logic;
            IP2Bus_WrAck : in std_logic;
            IP2Bus_WrAck_sa : out std_logic;
            RFIFO_Error : in std_logic;
            RFIFO_RdAck : in std_logic;
            RFIFO_Retry : in std_logic;
            RFIFO_ToutSup : in std_logic;
            RFIFO_WrAck : in std_logic;
            Rst2Bus_Error : in std_logic;
            Rst2Bus_RdAck : in std_logic;
            Rst2Bus_Retry : in std_logic;
            Rst2Bus_ToutSup : in std_logic;
            Rst2Bus_WrAck : in std_logic;
            WFIFO_Error : in std_logic;
            WFIFO_RdAck : in std_logic;
            WFIFO_Retry : in std_logic;
            WFIFO_ToutSup : in std_logic;
            WFIFO_WrAck : in std_logic
            );
  end component;
  
  
  component dma_sg_blk
      generic (
               C_DMA_BLK_ID : INTEGER := 255;
               C_DMA_CHAN_NUM : INTEGER := 2;
               C_DMA_CH1_TYPE : INTEGER := 2;
               C_DMA_CH2_TYPE : INTEGER := 3;
               C_DMA_ALLOW_BURST : BOOLEAN := True;
               C_DMA_BAR : std_logic_vector := X"70002300";
               C_DMA_MAX_LENGTH_SIZE : INTEGER := 11;
               C_DMA_INTR_COALESCE : BOOLEAN := True;
               C_IP_REG_BAR : std_logic_vector := X"70001100";
               C_RXL_FIFO_BAR : std_logic_vector := X"70000000";
               C_TXL_FIFO_BAR : std_logic_vector := X"70000000";
               C_TXS_FIFO_BAR : std_logic_vector := X"70000000";
               C_RXS_FIFO_BAR : std_logic_vector := X"70000000";
               C_SG_PACKET_WAIT_UNIT_NS : INTEGER := 1000000;
               C_OPB_ABUS_WIDTH : INTEGER := 32;
               C_OPB_DBUS_WIDTH : INTEGER := 32;
               C_OPB_CLK_PERIOD_PS : INTEGER := 16000;
               C_B : INTEGER := 4;
               C_M : INTEGER := 26
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
  end component;
 



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Instantiate the components

begin

    -- Perform consistency checks

    -- synthesis translate_off


    ----------------------------------------------------------------------------
    -- Confirm that the device base address generic is the right width.
    ----------------------------------------------------------------------------
    assert C_DEV_BASEADDR'length = C_OPB_ABUS_WIDTH
      report
        "IPIF constraint, " &
        "C_DEV_BASEADDR'length = C_OPB_ABUS_WIDTH" &
        ", doesn't hold."
      severity failure;


    ----------------------------------------------------------------------------
    -- Confirm that the two generics that decompose the host bus address
    -- are within range. The inequality check allows for undecoded host-bus
    -- address bits.
    ----------------------------------------------------------------------------
    assert C_DEV_ADDR_DECODE_WIDTH + C_IPIF_ABUS_WIDTH <= C_OPB_ABUS_WIDTH
      report
        "IPIF constraint, " &
        "C_DEV_ADDR_DECODE_WIDTH + C_IPIF_ABUS_WIDTH <= C_OPB_ABUS_WIDTH" &
        ", doesn't hold."
      severity failure;


    ----------------------------------------------------------------------------
    -- Confirm that the device base address is zero at all bits decoded by the 
    -- device, i.e., C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH to C_OPB_ABUS_WIDTH-1.
    -- Also confirm that any undecoded address bits, i.e.,
    -- C_DEV_ADDR_DECODE_WIDTH to C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-1,
    -- are zero. (This enforces a common way to specify base addresses
    -- that have undecoded bits.)
    ----------------------------------------------------------------------------
    assert C_DEV_BASEADDR(C_DEV_ADDR_DECODE_WIDTH to C_OPB_ABUS_WIDTH-1) =
           ZERO_IPIF_ABUS_WIDTH 
      report
        "IPIF constraint, " &
        "C_DEV_BASEADDR(C_DEV_ADDR_DECODE_WIDTH to C_OPB_ABUS_WIDTH-1) = zero" &
        ", doesn't hold."
      severity failure;


    -- ToDo. Add check that C_IPIF_ABUS_WIDTH are enough bits to
    -- distinguish all addresses local to the device.
  --assert 
  --    report "IPIF constraint, " &
  --           "" &
  --           ", doesn't hold."
  --    severity failure;

    -- synthesis translate_on
 
      
      
      
      
 ------------------------------------------------------------------------------                       
  INCLUDE_MASTER : if (DEV_NEEDS_MASTER = True) generate
      
     I_MASTER_ATTACHMENT: master_attachment
       generic map (C_OPB_ABUS_WIDTH,
                    C_OPB_DBUS_WIDTH,
                    C_OPB_BE_NUM,
                    4)
       port map (
                 Bus2IP_Clk_i => Bus2IP_Clk_i,
                 Bus2IP_MstError_i => Bus2IP_MstError_i,
                 Bus2IP_MstLastAck_i => Bus2IP_MstLastAck_i,
                 Bus2IP_MstRdAck_i => Bus2IP_MstRdAck_i,
                 Bus2IP_MstRetry_i => Bus2IP_MstRetry_i,
                 Bus2IP_MstTimeOut_i => Bus2IP_MstTimeOut_i,
                 Bus2IP_MstWrAck_i => Bus2IP_MstWrAck_i,
                 Bus_MnGrant => Bus_MnGrant,
                 Bus_Reset_i => Bus_Reset_i,
                 DMA2BUS_Addr => DMA2Bus_Addr(0 to C_OPB_ABUS_WIDTH - 1),
                 DMA_MstBE => DMA_MstBE(0 to C_OPB_BE_NUM - 1),
                 DMA_MstBurst => DMA_MstBurst,
                 DMA_MstBusLock => DMA_MstBusLock,
                 DMA_MstRdReq => DMA_MstRdReq,
                 DMA_MstWrReq => DMA_MstWrReq,
                 IP2Bus_Addr => IP2Bus_Addr(0 to C_OPB_ABUS_WIDTH - 1),
                 IP2Bus_MstBE => IP2Bus_MstBE(0 to C_OPB_BE_NUM - 1),
                 IP2Bus_MstBurst => IP2Bus_MstBurst,
                 IP2Bus_MstBusLock => IP2Bus_MstBusLock,
                 IP2Bus_MstRdReq => IP2Bus_MstRdReq,
                 IP2Bus_MstWrReq => IP2Bus_MstWrReq,
                 MA2SA_num => MA2SA_num(0 to 3),
                 MA2SA_Rd => MA2SA_Rd,
                 MA2SA_select => MA2SA_select,
                 MA2SA_XferAck => MA2SA_XferAck,
                 Mn_ABus => Mn_ABus(0 to C_OPB_ABUS_WIDTH - 1),
                 Mn_BE => Mn_BE(0 to C_OPB_BE_NUM - 1),
                 Mn_busLock => Mn_busLock,
                 Mn_request => Mn_request,
                 Mn_RNW => Mn_RNW,
                 Mn_select => Mn_select,
                 Mn_seqAddr => Mn_seqAddr,
                 Mstr_sel_ma => Mstr_sel_ma,
                 OPB_errAck => OPB_errAck,
                 OPB_MnGrant => OPB_MnGrant,
                 OPB_retry => OPB_retry,
                 OPB_timeout => OPB_timeout,
                 OPB_xferAck => OPB_xferAck,
                 SA2MA_RdRdy => SA2MA_RdRdy,
                 SA2MA_WrAck => SA2MA_WrAck);
 
  end generate INCLUDE_MASTER;  
                          
    
    
                           
                           
  REMOVE_MASTER : if (DEV_NEEDS_MASTER = False) generate
    
           Bus2IP_MstError_i   <=  '0'; 
           Bus2IP_MstLastAck_i <=  '0'; 
           Bus2IP_MstRdAck_i   <=  '0'; 
           Bus2IP_MstRetry_i   <=  '0'; 
           Bus2IP_MstTimeOut_i <=  '0'; 
           Bus2IP_MstWrAck_i   <=  '0'; 
           Bus_MnGrant         <=  '0'; 
           MA2SA_num           <=  (others => '0'); 
           MA2SA_Rd            <=  '0'; 
           MA2SA_select        <=  '0'; 
           MA2SA_XferAck       <=  '0'; 
           Mn_ABus             <=  (others => '0'); 
           Mn_BE               <=  (others => '0'); 
           Mn_busLock          <=  '0'; 
           Mn_request          <=  '0'; 
           Mn_RNW              <=  '0'; 
           Mn_select           <=  '0'; 
           Mn_seqAddr          <=  '0'; 
           Mstr_sel_ma         <=  '0'; 
       
  end generate REMOVE_MASTER;  
                          
 ------------------------------------------------------------------------------                       
  
  
 
  I_ADDR_DECODE: addr_decode
    generic map (
            C_IPIF_ABUS_WIDTH       => C_IPIF_ABUS_WIDTH, 
            C_IPIF_DBUS_WIDTH       => C_IPIF_DBUS_WIDTH, 
                                     
            C_SRAM_CE               => C_IP_SRAM_PRESENT,
            C_SRAM_BASE             => SRAM_BASE,
            C_SRAM_ADDR_WIDTH       => SRAM_ADDR_WIDTH,
            C_SRAM_DATA_WIDTH       => SRAM_DATA_WIDTH,

            C_REG_CE                => C_IP_REG_PRESENT, 
            C_REG_BASE              => REG_BASE, 
            C_IP_REG_NUM            => C_IP_REG_NUM,
            C_REG_DATA_WIDTH        => REG_DATA_WIDTH,

            C_WRFIFO_CE             => C_WRFIFO_PRESENT,
            C_WRFIFO_BASE           => WRFIFO_BASE,
            C_WRFIFO_ADDR_WIDTH     => WRFIFO_ADDR_WIDTH,
            C_WRFIFO_DATA_WIDTH     => WRFIFO_DATA_WIDTH,
            C_WRFIFO_REG_BASE       => WRFIFO_REG_BASE,
            C_WRFIFO_REG_NUM        => 2,
            C_WRFIFO_REG_DATA_WIDTH => WRFIFO_REG_DATA_WIDTH,

  
            C_RDFIFO_CE             => C_RDFIFO_PRESENT,
            C_RDFIFO_BASE           => RDFIFO_BASE,
            C_RDFIFO_ADDR_WIDTH     => RDFIFO_ADDR_WIDTH,
            C_RDFIFO_DATA_WIDTH     => RDFIFO_DATA_WIDTH,
            C_RDFIFO_REG_BASE       => RDFIFO_REG_BASE,
            C_RDFIFO_REG_NUM        => 2,
            C_RDFIFO_REG_DATA_WIDTH => RDFIFO_REG_DATA_WIDTH,

            C_DMA_CE                => C_DMA_PRESENT,
            C_DMA_BASE              => DMA_BASE,
            C_DMA_SRAM_ADDR_WIDTH   => DMA_SRAM_ADDR_WIDTH,
            C_DMA_SRAM_DATA_WIDTH   => DMA_SRAM_DATA_WIDTH,

            C_INTERRUPT_CE          => C_INTERRUPT_PRESENT,
            C_INTERRUPT_REG_BASE    => INTERRUPT_REG_BASE,
            C_INTERRUPT_REG_NUM     => INTERRUPT_REG_NUM, 
            C_INTERRUPT_REG_DATA_WIDTH=> INTERRUPT_REG_DATA_WIDTH,

 
            C_IP_RESET_CE           => C_RESET_PRESENT,
            C_IP_RESET_REG_BASE     => RESET_REG_BASE,
            C_IP_RESET_REG_NUM      => 1,
            C_IP_RESET_REG_DATA_WIDTH=> IP_RESET_REG_DATA_WIDTH
            )
    port map (
        Reset               => Bus_Reset_i,

        Bus2IP_RangeSel     => Bus2IP_RangeSel_sa,
        Bus2IP_Addr_sa      => Bus2IP_Addr_i,
        Bus2IP_BE_sa        => Bus2IP_BE_i,

        Bus2IP_RNW_sa       => Bus2IP_RNW_sa,
        Bus2IP_Clk          => Bus2IP_Clk_i,
        Bus2IP_Burst_sa     => Bus2IP_Burst_sa, 

        IP2Bus_WrAck_sa     => IP2Bus_WrAck_sa, 
        IP2Bus_RdAck_sa     => IP2Bus_RdAck_sa, 


        Asyn_SRAM_WrCE      => Asyn_SRAM_WrCE, 
        Asyn_SRAM_RdCE      => Asyn_SRAM_RdCE, 
--        Bus2IP_SRAM_WrCE    : out std_logic;
--        Bus2IP_SRAM_RdCE    : out std_logic;
        Bus2IP_SRAM_CE      => Bus2IP_SRAM_CE, 

        Bus2IP_Reg_WrCE     => Bus2IP_Reg_WrCE, 
        Bus2IP_Reg_RdCE     => Bus2IP_Reg_RdCE, 

        Asyn_WrFIFO_WrCE    => open,
        Asyn_WrFIFO_RdCE    => open,
        WrFIFO_WrCE         => WrFIFO_WrCE, 
        WrFIFO_RdCE         => WrFIFO_RdCE, 
        WrFIFO_Reg_WrCE     => WrFIFO_Reg_WrCE, 
        WrFIFO_Reg_RdCE     => WrFIFO_Reg_RdCE, 

        Asyn_RdFIFO_WrCE    => open,
        Asyn_RdFIFO_RdCE    => open,
        RdFIFO_WrCE         => RdFIFO_WrCE, 
        RdFIFO_RdCE         => RdFIFO_RdCE, 
        RdFIFO_Reg_WrCE     => RdFIFO_Reg_WrCE, 
        RdFIFO_Reg_RdCE     => RdFIFO_Reg_RdCE, 

     --   Asyn_DMA_SRAM_WrCE  : out std_logic;
     --   Asyn_DMA_SRAM_RdCE  : out std_logic;
        DMA_WrCE            => DMA_WrCE, 
        DMA_RdCE            => DMA_RdCE, 

        Interrupt_WrCE      => Interrupt_WrCE, 
        Interrupt_RdCE      => Interrupt_RdCE, 

        --IP_Reset_WrCE      : out std_logic_vector (0 to C_IP_RESET_REG_NUM-1);
        --IP_Reset_RdCE      : out std_logic_vector (0 to C_IP_RESET_REG_NUM-1)
        IP_Reset_RdCE       => IP_Reset_RdCE, 
        IP_Reset_WrCE       => IP_Reset_WrCE 
        );
  
  
  I_IP2BUS_SRMUX: ip2bus_srmux_blk
    port map (
              DMA_SG_Error => DMA_SG_Error,
              DMA_SG_RdAck => DMA_SG_RdAck,
              DMA_SG_Retry => DMA_SG_Retry,
              DMA_SG_ToutSup => DMA_SG_ToutSup,
              DMA_SG_WrAck => DMA_SG_WrAck,
              Intr2Bus_Error => Intr2Bus_Error,
              Intr2Bus_RdAck => Intr2Bus_RdAck,
              Intr2Bus_Retry => Intr2Bus_Retry,
              Intr2Bus_ToutSup => Intr2Bus_ToutSup,
              Intr2Bus_WrAck => Intr2Bus_WrAck,
              IP2Bus_Error => IP2Bus_Error,
              IP2Bus_Error_sa => IP2Bus_Error_sa,
              IP2Bus_RdAck => IP2Bus_RdAck,
              IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,
              IP2Bus_Retry => IP2Bus_Retry,
              IP2Bus_Retry_sa => IP2Bus_Retry_sa,
              IP2Bus_ToutSup => IP2Bus_ToutSup,
              IP2Bus_ToutSup_sa => IP2Bus_ToutSup_sa,
              IP2Bus_WrAck => IP2Bus_WrAck,
              IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
              RFIFO_Error => RFIFO_Error,
              RFIFO_RdAck => RFIFO_RdAck,
              RFIFO_Retry => RFIFO_Retry,
              RFIFO_ToutSup => RFIFO_ToutSup,
              RFIFO_WrAck => RFIFO_WrAck,
              Rst2Bus_Error => Rst2Bus_Error,
              Rst2Bus_RdAck => Rst2Bus_RdAck,
              Rst2Bus_Retry => Rst2Bus_Retry,
              Rst2Bus_ToutSup => Rst2Bus_ToutSup,
              Rst2Bus_WrAck => Rst2Bus_WrAck,
              WFIFO_Error => WFIFO_Error,
              WFIFO_RdAck => WFIFO_RdAck,
              WFIFO_Retry => WFIFO_Retry,
              WFIFO_ToutSup => WFIFO_ToutSup,
              WFIFO_WrAck => WFIFO_WrAck);
 
  
  I_BUS2IP_AMUX: bus2ip_amux
    generic map (C_IPIF_ABUS_WIDTH  => C_IPIF_ABUS_WIDTH,
                 C_IPIF_DBUS_WIDTH  => C_IPIF_DBUS_WIDTH)
    port map (
              Bus2IP_Reset_i    => Bus_Reset_i,
              Bus2IP_Clk_i      => Bus2IP_Clk_i,
              Mstr_sel_ma       => Mstr_sel_ma,
              Addr_Cntr_ClkEN_sa=> Addr_Cntr_ClkEN_sa,
              Addr_sel_sa       => Addr_sel_sa,
              Bus2IP_Addr_sa    => Bus2IP_Addr_sa,
              IP2IP_Addr        => IP2IP_Addr,
              DMA2IP_Addr       => DMA2IP_Addr,
              Bus2IP_Addr_i     => Bus2IP_Addr_i,
              Bus2IP_BE_sa      => Bus2IP_BE_sa, 
              IP2IP_BE          => CONST_ALL_IP_BYTES_ENABLED,
              DMA2IP_BE         => CONST_ALL_IP_BYTES_ENABLED,
              Bus2IP_BE_i       => Bus2IP_BE_i
             );
  
  
  I_IP2BUS_DMUX: ip2bus_dmux_blk
    generic map (C_OPB_DBUS_WIDTH)
    port map (
              DMA2Bus_Data => DMA2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
              Intr2Bus_DBus => Intr2Bus_DBus(0 to C_OPB_DBUS_WIDTH - 1),
              IP2Bus_Data => IP2Bus_Data(0 to C_IPIF_DBUS_WIDTH - 1),
              IP2Bus_Data_sa => IP2Bus_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
              Reset2Bus_Data => Reset2Bus_DBus(0 to C_OPB_DBUS_WIDTH - 1),
              RFIFO2Bus_Data => RdFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
              WFIFO2Bus_Data => WrFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1));
 
  
  I_SLAVE_ATTACHMENT: slave_attachment
    generic map (
        C_OPB_ABUS_WIDTH        => C_OPB_ABUS_WIDTH,
        C_OPB_DBUS_WIDTH        => C_OPB_DBUS_WIDTH,
        C_IPIF_ABUS_WIDTH       => C_IPIF_ABUS_WIDTH,
        C_IPIF_DBUS_WIDTH       => C_IPIF_DBUS_WIDTH,
        C_DEV_ADDR_DECODE_WIDTH => C_DEV_ADDR_DECODE_WIDTH,
        C_SL_ATT_ADDR_SEL_WIDTH => 2,
        C_SLAVE_ATT_BASE        => C_DEV_BASEADDR,
        C_SLN_BURST             => C_DEV_BURST_ENABLE,
        C_SLN_ONLY              => DEV_IS_SLAVE_ONLY,
        C_MA2SA_NUM_WIDTH       => 4,
        C_SLN_BUFFER_DEPTH      => SLN_BUFFER_DEPTH)
    port map (
              Reset => Bus_Reset_i,
              OPB_Clk => Bus2IP_Clk_i,
              OPB_Select => OPB_select,
              OPB_RNW => OPB_RNW,
              OPB_SeqAddr => OPB_SeqAddr,
              OPB_BE => OPB_BE(0 to C_OPB_DBUS_WIDTH/8 - 1),
              OPB_ABus => OPB_ABus(0 to C_OPB_ABUS_WIDTH - 1),
              OPB_DBus => OPB_DBus(0 to C_OPB_DBUS_WIDTH - 1),
              Sln_DBus_gtd => Sln_DBus(0 to C_OPB_DBUS_WIDTH - 1),
              Sln_XferAck => Sln_xferAck,
              Sln_ErrAck => Sln_errAck,
              Sln_ToutSup => Sln_toutSup,
              Sln_Retry => Sln_retry,
              Bus_MnGrant => Bus_MnGrant,
              MA2SA_Select => MA2SA_select,
              MA2SA_XferAck => MA2SA_XferAck,
              MA2SA_Rd => MA2SA_Rd,
              MA2SA_Num => MA2SA_num(0 to 3),
              SA2MA_RdRdy => SA2MA_RdRdy,
              SA2MA_WrAck => SA2MA_WrAck,
              Addr_Sel => Addr_sel_sa(0 to 1),
              Addr_Cntr_ClkEn => Addr_Cntr_ClkEN_sa,
              Bus2IP_Burst_sa => Bus2IP_Burst_sa,
              Bus2IP_RNW_sa => Bus2IP_RNW_sa,
              Bus2IP_BE_sa => Bus2IP_BE_sa(0 to C_IPIF_DBUS_WIDTH/8 - 1),
              Bus2IP_Addr_sa => Bus2IP_Addr_sa(0 to C_IPIF_ABUS_WIDTH - 1),
              Bus2IP_Data_sa => Bus2IP_Data_sa(0 to C_IPIF_DBUS_WIDTH - 1),
              Bus2IP_RangeSel => Bus2IP_RangeSel_sa,
              Bus2IP_WrReq_sa => Bus2IP_WrReq_sa,
              Bus2IP_RdReq_sa => Bus2IP_RdReq_sa,
              IP2Bus_Data_sa => IP2Bus_Data_sa(0 to C_IPIF_DBUS_WIDTH - 1),
              IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
              IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,
              IP2Bus_ErrAck_sa => IP2Bus_Error_sa,
              IP2Bus_ToutSup_sa => IP2Bus_ToutSup_sa,
              IP2Bus_Retry_sa => IP2Bus_Retry_sa);
 
  
-------------------------------------------------------------------------------  
  INCLUDE_RESET : if (C_RESET_PRESENT = true) generate
        
        I_RESET_CONTROL: reset_control
          generic map (C_DEV_MIR_ENABLE,
                       IPIF_TYPE,
                       C_DEV_BLK_ID,
                       IPIF_REVISION,
                       IPIF_MINOR_VERSION,
                       IPIF_MAJOR_VERSION,
                       C_OPB_DBUS_WIDTH)
          port map (
                    Bus2IP_Clk_i => Bus2IP_Clk_i,
                    Bus_DBus => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
                    IP_Reset_RdCE => IP_Reset_RdCE,
                    IP_Reset_WrCE => IP_Reset_WrCE,
                    Reset => Bus_Reset_i,
                    Reset2Bus_DBus    => Reset2Bus_DBus(0 to C_OPB_DBUS_WIDTH - 1),
                    Reset2Bus_Error   => Rst2Bus_Error,
                    Reset2Bus_RdAck   => Rst2Bus_RdAck,
                    Reset2Bus_Retry   => Rst2Bus_Retry,
                    Reset2Bus_ToutSup => Rst2Bus_ToutSup,
                    Reset2Bus_WrAck   => Rst2Bus_WrAck,
                    Reset2IP_Reset    => Bus2IP_Reset_i);
  
  end generate INCLUDE_RESET; 
   
                                
    
  REMOVE_RESET : if (C_RESET_PRESENT = false) generate
  
        Reset2Bus_DBus  <= (others => '0') ;
        Rst2Bus_Error   <=  '0';
        Rst2Bus_RdAck   <=  '0';
        Rst2Bus_Retry   <=  '0';
        Rst2Bus_ToutSup <=  '0';
        Rst2Bus_WrAck   <=  '0';
        Bus2IP_Reset_i  <=  Bus_Reset_i;
  
  
  end generate REMOVE_RESET; 
 
-------------------------------------------------------------------------------  
  
 INCLUDE_INTERRUPT : if (C_INTERRUPT_PRESENT = true) generate
  
  
  
    I_INTERRUPT_CONTROL: interrupt_control
      generic map (C_INTERRUPT_REG_NUM    => INTERRUPT_REG_NUM,
                   C_NUM_IPIF_IRPT_SRC    => 4,
                   C_NUM_IP_IRPTS         => C_IP_IRPT_NUM,
                   C_INCLUDE_DEV_PENCODER => C_INCLUDE_DEV_PENCODER and
                                             C_INCLUDE_DEV_ISC,
                   C_INCLUDE_DEV_ISC      => C_INCLUDE_DEV_ISC,
                   C_IPIF_DBUS_WIDTH      => C_IPIF_DBUS_WIDTH)
      port map (
                Bus2IP_Clk_i => Bus2IP_Clk_i,
                Bus2IP_Data_sa => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
                Bus2IP_RdReq_sa => Bus2IP_RdReq_sa,
                Bus2IP_Reset_i => Bus2IP_Reset_i,
                Bus2IP_WrReq_sa => Bus2IP_WrReq_sa,
                Interrupt_RdCE => Interrupt_RdCE(0 to INTERRUPT_REG_NUM - 1),
                Interrupt_WrCE => Interrupt_WrCE(0 to INTERRUPT_REG_NUM - 1),
                Intr2Bus_DBus => Intr2Bus_DBus(0 to C_OPB_DBUS_WIDTH - 1),
                Intr2Bus_DevIntr => Intr2Bus_DevIntr,
                Intr2Bus_Error => Intr2Bus_Error,
                Intr2Bus_RdAck => Intr2Bus_RdAck,
                Intr2Bus_Retry => Intr2Bus_Retry,
                Intr2Bus_ToutSup => Intr2Bus_ToutSup,
                Intr2Bus_WrAck => Intr2Bus_WrAck,
                IP2Bus_IntrEvent => IP2Bus_IntrEvent(0 to C_IP_IRPT_NUM - 1),
                IPIF_Lvl_Interrupts => IPIF_Lvl_Interrupts(0 to 3),
                IPIF_Reg_Interrupts => IPIF_Reg_Interrupts(0 to 1));
 

 end generate INCLUDE_INTERRUPT;  
 
  
  
 REMOVE_INTERRUPT : if (C_INTERRUPT_PRESENT = false) generate
  
      Intr2Bus_DBus     <=  (others => '0');
      Intr2Bus_DevIntr  <=  IP2Bus_IntrEvent(0);
      Intr2Bus_Error    <=  '0'; 
      Intr2Bus_RdAck    <=  '0'; 
      Intr2Bus_Retry    <=  '0'; 
      Intr2Bus_ToutSup  <=  '0';
      Intr2Bus_WrAck    <=  '0'; 
  
  
           
 end generate REMOVE_INTERRUPT; 
                                                                               
                                                                               
                                                                               
 ------------------------------------------------------------------------------ 
  
  INCLUDE_RDFIFO : if (C_RDFIFO_PRESENT = true) generate
  
  
    I_RDFIFO: rdfifo
      generic map (C_OPB_DBUS_WIDTH,
                   C_OPB_BE_NUM,
                   C_DEV_MIR_ENABLE,
                   C_DEV_BLK_ID,
                   C_VIRTEX_II)
      port map (
                Bus2IP_BE_sa => Bus2IP_BE_i(0 to C_OPB_BE_NUM - 1),
                Bus2IP_Burst_sa => Bus2IP_Burst_sa,
                Bus2IP_Clk_i => Bus2IP_Clk_i,
                Bus2IP_Data_sa => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
                Bus2IP_RdReq_sa => Bus2IP_RdReq_sa,
                Bus2IP_Reset_i => Bus2IP_Reset_i,
                Bus2IP_WrReq_sa => Bus2IP_WrReq_sa,
                IP2RFIFO_Data => IP2RFIFO_Data(0 to 31),
                IP2RFIFO_WrMark => IP2RFIFO_WrMark,
                IP2RFIFO_WrRelease => IP2RFIFO_WrRelease,
                IP2RFIFO_WrReq => IP2RFIFO_WrReq,
                IP2RFIFO_WrRestore => IP2RFIFO_WrRestore,
                RdFIFO2Bus_Data => RdFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
                RdFIFO2Intr_DeadLock => RdFIFO2Intr_DeadLock,
                RdFIFO_RdCE => RdFIFO_RdCE,
                RdFIFO_Reg_RdCE => RdFIFO_Reg_RdCE(0 to 1),
                RdFIFO_Reg_WrCE => RdFIFO_Reg_WrCE(0 to 1),
                RdFIFO_WrCE => RdFIFO_WrCE,
                RFIFO2DMA_AlmostEmpty => RFIFO2DMA_AlmostEmpty,
                RFIFO2DMA_Empty => RFIFO2DMA_Empty,
                RFIFO2DMA_Occupancy => RFIFO2DMA_Occupancy(0 to 9),
                RFIFO2IP_AlmostFull => RFIFO2IP_AlmostFull,
                RFIFO2IP_Full => RFIFO2IP_Full,
                RFIFO2IP_Vacancy => RFIFO2IP_Vacancy(0 to 9),
                RFIFO2IP_WrAck => RFIFO2IP_WrAck,
                RFIFO_Error => RFIFO_Error,
                RFIFO_RdAck => RFIFO_RdAck,
                RFIFO_Retry => RFIFO_Retry,
                RFIFO_ToutSup => RFIFO_ToutSup,
                RFIFO_WrAck => RFIFO_WrAck);

  end generate INCLUDE_RDFIFO; 

  
  
  
  REMOVE_RDFIFO : if (C_RDFIFO_PRESENT = false) generate
  
          RdFIFO2Bus_Data       <=  (others => '0');
          RdFIFO2Intr_DeadLock  <=  '0';
          RFIFO2DMA_AlmostEmpty <=  '0';
          RFIFO2DMA_Empty       <=  '0';
          RFIFO2DMA_Occupancy   <=  (others => '0');
          RFIFO2IP_AlmostFull   <=  '0';
          RFIFO2IP_Full         <=  '0';
          RFIFO2IP_Vacancy      <=  (others => '0');
          RFIFO2IP_WrAck        <=  '0';
          RFIFO_Error           <=  '0';
          RFIFO_RdAck           <=  '0';
          RFIFO_Retry           <=  '0';
          RFIFO_ToutSup         <=  '0';
          RFIFO_WrAck           <=  '0';
  
  
  end generate REMOVE_RDFIFO; 
  
                                                                
-------------------------------------------------------------------------------
 INCLUDE_WRFIFO : if (C_WRFIFO_PRESENT = true) generate
  
  
  
    I_WRFIFO: wrfifo
      generic map (C_OPB_DBUS_WIDTH,
                   C_OPB_BE_NUM,
                   C_DEV_MIR_ENABLE,
                   C_DEV_BLK_ID,
                   C_VIRTEX_II)
      port map (
                Bus2IP_BE_sa => Bus2IP_BE_i(0 to C_OPB_BE_NUM - 1),
                Bus2IP_Burst_sa => Bus2IP_Burst_sa,
                Bus2IP_Clk_i => Bus2IP_Clk_i,
                Bus2IP_Data_sa => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
                Bus2IP_RdReq_sa => Bus2IP_RdReq_sa,
                Bus2IP_Reset_i => Bus2IP_Reset_i,
                Bus2IP_WrReq_sa => Bus2IP_WrReq_sa,
                IP2WFIFO_RdMark => IP2WFIFO_RdMark,
                IP2WFIFO_RdRelease => IP2WFIFO_RdRelease,
                IP2WFIFO_RdReq => IP2WFIFO_RdReq,
                IP2WFIFO_RdRestore => IP2WFIFO_RdRestore,
                WFIFO2DMA_AlmostFull => WFIFO2DMA_AlmostFull,
                WFIFO2DMA_Full => WFIFO2DMA_Full,
                WFIFO2DMA_Vacancy => WFIFO2DMA_Vacancy(0 to 9),
                WFIFO2IP_AlmostEmpty => WFIFO2IP_AlmostEmpty,
                WFIFO2IP_Data => WFIFO2IP_Data(0 to 31),
                WFIFO2IP_Empty => WFIFO2IP_Empty,
                WFIFO2IP_Occupancy => WFIFO2IP_Occupancy(0 to 9),
                WFIFO2IP_RdAck => WFIFO2IP_RdAck,
                WFIFO_Error => WFIFO_Error,
                WFIFO_RdAck => WFIFO_RdAck,
                WFIFO_Retry => WFIFO_Retry,
                WFIFO_ToutSup => WFIFO_ToutSup,
                WFIFO_WrAck => WFIFO_WrAck,
                WrFIFO2Bus_Data => WrFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
                WrFIFO2Intr_DeadLock => WrFIFO2Intr_DeadLock,
                WrFIFO_RdCE => WrFIFO_RdCE,
                WrFIFO_Reg_RdCE => WrFIFO_Reg_RdCE(0 to 1),
                WrFIFO_Reg_WrCE => WrFIFO_Reg_WrCE(0 to 1),
                WrFIFO_WrCE => WrFIFO_WrCE);

 end generate INCLUDE_WRFIFO; 

 
 

 REMOVE_WRFIFO : if (C_WRFIFO_PRESENT = false) generate

                WFIFO2DMA_Full        <=  '0';
                WFIFO2DMA_Vacancy     <=  (others => '0');
                WFIFO2IP_AlmostEmpty  <=  '0';
                WFIFO2IP_Data         <=  (others => '0');
                WFIFO2IP_Empty        <=  '0';
                WFIFO2IP_Occupancy    <=  (others => '0');
                WFIFO2IP_RdAck        <=  '0';
                WFIFO_Error           <=  '0';
                WFIFO_RdAck           <=  '0';
                WFIFO_Retry           <=  '0';
                WFIFO_ToutSup         <=  '0';
                WFIFO_WrAck           <=  '0';
                WrFIFO2Bus_Data       <=  (others => '0');
                WrFIFO2Intr_DeadLock  <=  '0';
                                  
                                  
 end generate REMOVE_WRFIFO; 
 
  
 ------------------------------------------------------------------------------
  
 ------------------------------------------------------------------------------
 -- Include DMA in the IPIF
 ------------------------------------------------------------------------------
 INCLUDE_DMA : if (C_DMA_PRESENT = True) generate
    
  
  I_DMA_SG_BLK: dma_sg_blk
    generic map (C_DEV_BLK_ID,
                 C_DMA_CHAN_NUM,
                 C_DMA_CH1_TYPE,
                 C_DMA_CH2_TYPE,
                 DMA_USE_BURST,
                 DMA_REG_BASEADDR,
                 C_DMA_LENGTH_WIDTH,
                 C_DMA_INTR_COALESCE,
                 IP_REG_BASEADDR,
                 IP_RXL_FIFO_BASEADDR,
                 IP_TXL_FIFO_BASEADDR,
                 IP_TXS_FIFO_BASEADDR,
                 IP_RXS_FIFO_BASEADDR,
                 C_DMA_PACKET_WAIT_UNIT_NS,
                 C_OPB_ABUS_WIDTH,
                 C_OPB_DBUS_WIDTH,
                 C_OPB_CLK_PERIOD_PS,
                 C_OPB_BE_NUM,
                 C_IPIF_ABUS_WIDTH-2)
    port map (
              Bus2IP_Addr_i => Bus2IP_Addr_i(0 to C_IPIF_ABUS_WIDTH - 3),
              Bus2IP_BE_sa => Bus2IP_BE_i(0 to C_OPB_BE_NUM - 1),
              Bus2IP_Burst_sa => Bus2IP_Burst_sa,
              Bus2IP_Clk_i => Bus2IP_Clk_i,
              Bus2IP_Data_sa => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
              Bus2IP_DMA_Ack => Bus2IP_DMA_Ack,
              Bus2IP_Freeze_i => Bus2IP_Freeze_i,
              Bus2IP_MstError_i => Bus2IP_MstError_i,
              Bus2IP_MstLastAck_i => Bus2IP_MstLastAck_i,
              Bus2IP_MstRdAck_i => Bus2IP_MstRdAck_i,
              Bus2IP_MstRetry_i => Bus2IP_MstRetry_i,
              Bus2IP_MstTimeOut_i => Bus2IP_MstTimeOut_i,
              Bus2IP_MstWrAck_i => Bus2IP_MstWrAck_i,
              Bus2IP_RdReq_sa => Bus2IP_RdReq_sa,
              Bus2IP_Reset_i => Bus2IP_Reset_i,
              Bus2IP_WrReq_sa => Bus2IP_WrReq_sa,
              DMA2Bus_Addr => DMA2Bus_Addr(0 to C_OPB_ABUS_WIDTH - 1),
              DMA2Bus_Data => DMA2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
              DMA2Intr_Intr => DMA2Intr_Intr(0 to 1),
              DMA2IP_Addr => DMA2IP_Addr(0 to C_IPIF_ABUS_WIDTH - 3),
                -- See assignment to DMA2IP_Addr(30:31), below.
              DMA_MstBE => DMA_MstBE(0 to C_OPB_BE_NUM - 1),
              DMA_MstBurst => DMA_MstBurst,
              DMA_MstBusLock => DMA_MstBusLock,
              DMA_MstRdReq => DMA_MstRdReq,
              DMA_MstWrReq => DMA_MstWrReq,
              DMA_RdCE => DMA_RdCE,
              DMA_SG_Error => DMA_SG_Error,
              DMA_SG_RdAck => DMA_SG_RdAck,
              DMA_SG_Retry => DMA_SG_Retry,
              DMA_SG_ToutSup => DMA_SG_ToutSup,
              DMA_SG_WrAck => DMA_SG_WrAck,
              DMA_WrCE => DMA_WrCE,
              IP2Bus_DMA_Req => IP2Bus_DMA_Req,
              IP2DMA_RxLength_Empty => IP2DMA_RxLength_Empty,
              IP2DMA_RxStatus_Empty => IP2DMA_RxStatus_Empty,
              IP2DMA_TxLength_Full => IP2DMA_TxLength_Full,
              IP2DMA_TxStatus_Empty => IP2DMA_TxStatus_Empty,
              Mstr_sel_ma => Mstr_sel_ma,
              RFIFO2DMA_AlmostEmpty => RFIFO2DMA_AlmostEmpty,
              RFIFO2DMA_Empty => RFIFO2DMA_Empty,
              RFIFO2DMA_Occupancy => RFIFO2DMA_Occupancy(0 to 9),
              WFIFO2DMA_AlmostFull => WFIFO2DMA_AlmostFull,
              WFIFO2DMA_Full => WFIFO2DMA_Full,
              WFIFO2DMA_Vacancy => WFIFO2DMA_Vacancy(0 to 9));

              DMA2IP_Addr(C_IPIF_ABUS_WIDTH - 2 to C_IPIF_ABUS_WIDTH -1) <= (others => '0');
 
      end generate INCLUDE_DMA; 
                 
            
            
    ------------------------------------------------------------------------------
    -- Don't include DMA in the IPIF . Drive all outputs to zero.
    ------------------------------------------------------------------------------
   
    REMOVE_DMA : if (C_DMA_PRESENT = False) generate
   
           Bus2IP_DMA_Ack      <=  '0';    
           DMA2Bus_Addr        <=  (others => '0');    
           DMA2Bus_Data        <=  (others => '0');    
           DMA2Intr_Intr       <=  (others => '0');    
           DMA2IP_Addr         <=  (others => '0');    
           DMA_MstBE           <=  (others => '0');    
           DMA_MstBurst        <=  '0';    
           DMA_MstBusLock      <=  '0';    
           DMA_MstRdReq        <=  '0';    
           DMA_MstWrReq        <=  '0';    
           DMA_SG_Error        <=  '0';    
           DMA_SG_RdAck        <=  '0';    
           DMA_SG_Retry        <=  '0';    
           DMA_SG_ToutSup      <=  '0';    
           DMA_SG_WrAck        <=  '0';    
    
    
      end generate REMOVE_DMA; 
   
  
  
-------------------------------------------------------------------------------  
-- Misc logic assignments  
  
  Bus2IP_Addr       <= Bus2IP_Addr_i;
 
  Bus2IP_Data       <= Bus2IP_Data_sa(0 to C_IPIF_DBUS_WIDTH-1);
 
  Bus2IP_BE         <= Bus2IP_BE_i;
  Bus2IP_WrReq      <= Bus2IP_WrReq_sa;
  Bus2IP_RdReq      <= Bus2IP_RdReq_sa;
  Bus2IP_Burst      <= Bus2IP_Burst_sa;
 
  Bus2IP_MstWrAck   <= Bus2IP_MstWrAck_i and not(Mstr_sel_ma);
  Bus2IP_MstRdAck   <= Bus2IP_MstRdAck_i and not(Mstr_sel_ma);
  Bus2IP_MstRetry   <= Bus2IP_MstRetry_i;
  Bus2IP_MstError   <= Bus2IP_MstError_i;
  Bus2IP_MstTimeOut <= Bus2IP_MstTimeOut_i;
  Bus2IP_MstLastAck <= Bus2IP_MstLastAck_i;
 
  Bus2IP_Clk_i      <= OPBClk;
  Bus2IP_Clk        <= OPBClk;
 
  Bus_Reset_i       <= Reset;
 
  Bus2IP_Freeze_i   <= Freeze;
  Bus2IP_Freeze     <= Freeze;
 
  IP2INTC_Irpt      <= Intr2Bus_DevIntr;
 
  IPIF_Lvl_Interrupts(0) <= DMA2Intr_Intr(0);
  IPIF_Lvl_Interrupts(1) <= DMA2Intr_Intr(1);
  IPIF_Lvl_Interrupts(2) <= RdFIFO2Intr_DeadLock;
  IPIF_Lvl_Interrupts(3) <= WrFIFO2Intr_DeadLock;
 
  IPIF_Reg_Interrupts(0) <= IP2Bus_Error_sa;
  IPIF_Reg_Interrupts(1) <= const_zero;
 
  Bus2IP_Reset      <= Bus2IP_Reset_i;
 
  const_zero        <= LOGIC_LOW;
  
end implementation; -- (architecture)

