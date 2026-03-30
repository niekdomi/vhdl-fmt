-------------------------------------------------------------------------------
-- $Id: ipif_regonly_slave.vhd,v 1.2 2003/03/31 19:15:36 anitas Exp $
-------------------------------------------------------------------------------
-- ipif_regonly_slave.vhd - entity/architecture pair 
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
-- Filename:        ipif_regonly_slave.vhd
-- Version:         v1.02d 
-- Description:     This file provides the OPB Slave interface to the arbiter
--                  registers. Note that if the parameter, C_PROC_INTRFCE is
--                  false, this logic is not instantiated.
-- 
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--
--              opb_arbiter.vhd
--                --opb_arbiter_core.vhd
--                  -- ipif_regonly_slave.vhd
--                  -- priority_register_logic.vhd
--                      -- priority_reg.vhd
--                      -- onehot2encoded.vhd
--                          -- or_bits.vhd
--                  -- control_register.vhd
--                  -- arb2bus_data_mux.vhd
--                      -- mux_onehot.vhd
--                      -- or_bits.vhd
--                  -- watchdog_timer.vhd
--                  -- arbitration_logic.vhd
--                      -- or_bits.vhd
--                  -- park_lock_logic.vhd
--                      -- or_bits.vhd
--                      -- or_gate.vhd
--                          -- or_muxcy.vhd
-------------------------------------------------------------------------------
-- Author:      ALS
-- History:
--  ALS         08/28/01        -- Version 1.01a creation to include IPIF v1.22a
--
--  ALS         08/30/01
-- ^^^^^^
--  Updated IPIF component instantiation to change VERTEXII to VIRTEXII.
-- ~~~~~~
--
--  ALS         10/04/01        -- Version 1.02a creation to include IPIF v1.23a
--
--  ALS         10/08/01
-- ^^^^^^
--  Updated IPIF library to opb_ipif_v1_23_a
-- ~~~~~~
--
--  ALS         10/12/01
-- ^^^^^^
--  The width of the IPIF address bus is now set to 9 by the constant 
--  IPIF_ABUS_WIDTH which is defined in opb_arb_pkg.
-- ~~~~~~
--  
--  ALS         10/16/01
-- ^^^^^^
--  Updated component instantiation of IPIF.
-- ~~~~~~
--  ALS         11/27/01
-- ^^^^^^
--  Version 1.02b created to fix registered grant problem.
-- ~~~~~~
--  ALS         01/26/02
-- ^^^^^^
--  Created version 1.02c to fix problem with registered grants, and buslock when
--  the buslock master is holding request high and performing conversion cycles.
-- ~~~~~~
--  ALS         01/09/03
-- ^^^^^^
--  Created version 1.02d to register OPB_timeout to improve timing
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

-- opb_arb_pkg defines RESET_ACTIVE and IPIF_ABUS_WIDTH
library opb_arbiter_v1_02_d;
use opb_arbiter_v1_02_d.opb_arb_pkg.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.all;

library ieee;
use ieee.STD_LOGIC_ARITH.all;


-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_OPB_ABUS_WIDTH        -- width of OPB address bus
--      C_OPB_DBUS_WIDTH        -- width of OPB data bus
--      C_BASEADDR              -- OPB Arbiter base address
--      C_NUM_MASTERS           -- number of OPB masters
--      C_NUM_MID_BITS          -- number of bits to encode master id
--      C_DEV_BLK_ID            -- device block id
--      C_DEV_MIR_ENABLE        -- IPIF mirror capability enable
--      C_DEV_ADDR_DECODE_WIDTH -- width of device address
--
-- Definition of Ports:
--         
--      Bus2IP_Data             -- OPB data to processor bus
--      Bus2IP_Reg_RdCE         -- read register clock enables
--      Bus2IP_Reg_WrCE         -- write register clock enables
--      Bus2IP_Clk              -- clock
--      Bus2IP_Reset            -- reset
--      IP2Bus_Data             -- IP data to processor bus
--      IP2Bus_RdAck            -- IP read acknowledge
--      IP2Bus_WrAck            -- IP write acknowledge
--      OPB_ABus                -- OPB address bus
--      OPB_BE                  -- OPB byte enables
--      OPB_Clk                 -- OPB clock
--      OPB_DBus                -- OPB data bus
--      OPB_RNW                 -- Read not Write
--      OPB_Select              -- Master has control of bus
--      OPB_seqAddr             -- Sequential Address
--      Rst                     -- Reset
--      Sln_DBus                -- Slave data bus
--      Sln_ErrAck              -- Slave error acknowledge
--      Sln_Retry               -- Slave retry
--      Sln_ToutSup             -- Slave timeout suppress
--      Sln_XferAck             -- Slave transfer acknowledge
--
-------------------------------------------------------------------------------


-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity ipif_regonly_slave is
    generic (
             C_OPB_ABUS_WIDTH           : integer := 32;
             C_OPB_DBUS_WIDTH           : integer := 32;
             C_BASEADDR                 : std_logic_vector;
             C_NUM_MASTERS              : integer := 4;
             C_NUM_MID_BITS             : integer := 2;
             C_DEV_BLK_ID               : integer :=0;
             C_DEV_MIR_ENABLE           : boolean := false;
             C_DEV_ADDR_DECODE_WIDTH    : integer := 4
             );
    port (
          Bus2IP_Data       : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
          Bus2IP_Reg_RdCE   : out std_logic_vector(0 to C_NUM_MASTERS );
          Bus2IP_Reg_WrCE   : out std_logic_vector(0 to C_NUM_MASTERS );
          Bus2IP_Clk        : out std_logic;
          Bus2IP_Reset      : out std_logic;
          IP2Bus_Data       : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
          IP2Bus_RdAck      : in std_logic;
          IP2Bus_WrAck      : in std_logic;
          OPB_ABus          : in std_logic_vector(0 to C_OPB_ABUS_WIDTH - 1 );
          OPB_BE            : in std_logic_vector(0 to C_OPB_DBUS_WIDTH / 8 - 1 );
          OPB_Clk           : in std_logic;
          OPB_DBus          : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
          OPB_RNW           : in std_logic;
          OPB_Select        : in std_logic;
          OPB_seqAddr       : in std_logic;
          Rst               : in std_logic;
          Sln_DBus          : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
          Sln_ErrAck        : out std_logic;
          Sln_Retry         : out std_logic;
          Sln_ToutSup       : out std_logic;
          Sln_XferAck       : out std_logic
          ); 
end ipif_regonly_slave;
 
-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------
architecture implementation of ipif_regonly_slave is

-------------------------------------------------------------------------------
--  Constant Declarations
-------------------------------------------------------------------------------
constant REG_OFFSET_INT  : integer := 256;
constant REG_OFFSET      : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1) 
                         := conv_std_logic_vector(REG_OFFSET_INT, C_OPB_ABUS_WIDTH);

-------------------------------------------------------------------------------
--  Signal Declarations
-------------------------------------------------------------------------------
signal zero_addr        : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1) := (others => '0');
signal zero_be          : std_logic_vector(0 to C_OPB_ABUS_WIDTH/8-1) := (others => '0');
signal zero_rdfifo_data : std_logic_vector(0 to 31) := (others => '0');
signal zero_intrevent   : std_logic_vector(0 to 0) := (others => '0');
signal zero_ip2ip_addr  : std_logic_vector(0 to IPIF_ABUS_WIDTH-1):= (others => '0');

-------------------------------------------------------------------------------
--  Component Declarations
-------------------------------------------------------------------------------


component ipif is
  generic (
           C_DEV_BLK_ID : INTEGER := 1;  
                    --  Platform Builder Assiged Device ID number (unique
                    --  for each device)
                    
           C_DEV_MIR_ENABLE : BOOLEAN := false;  
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
                    -- 'True' specifies inclusion of the IPIF S/W Reset function
                    
           C_INTERRUPT_PRESENT : BOOLEAN := false;  
                    -- 'True' specifies inclusion of the IPIF Interrupt 
                    -- Support function
                    
         --  C_INCLUDE_DEV_ISC : BOOLEAN := true;
                    -- 'true' specifies that the full device interrupt
                    -- source controller structure will be included;
                    -- 'false' specifies that only the global interrupt
                    -- enable is present in the device interrupt source
                    -- controller and that the only source of interrupts
                    -- in the device is the IP interrupt source controller

           C_INCLUDE_DEV_PENCODER : BOOLEAN := true;  
                    -- 'True' will include the Device IID in the IPIF Interrupt
                    -- function
                    
           C_IP_MASTER_PRESENT : BOOLEAN := false;  
                    -- 'True' specifies that the IP has Bus Master capability
                    
           C_IP_REG_PRESENT : BOOLEAN := false;  
                    -- 'True' specifies that the IP has register(s) needing 
                    -- address decoding
                    
           C_IP_REG_BASEADDR_OFFSET : std_logic_vector := X"00000044";  
                    -- The address offset of the start of the IP registers from
                    -- Device BAR (in bytes)
                    
           C_IP_REG_NUM : INTEGER := 1;  
                    -- Number of required IP register chip enables.
                    
           C_IP_IRPT_NUM : INTEGER := 22;  
                    -- Number of required IP Interrupts to IPIF Interrupt function
                    
           C_IP_SRAM_PRESENT : BOOLEAN := false;  
                    -- 'True' specifies that the IP requires SRAM type 
                    -- chip enables
                    
           C_IP_SRAM_BASEADDR_OFFSET : std_logic_vector := X"00001000";
                    --  The address offset from Device BAR (in bytes) of the 
                    --  start of the SRAM decode
                    
           C_IP_SRAM_SIZE : INTEGER := 256;  
                    --  The required size of decoded SRAM space (in bytes)
                    
           C_WRFIFO_PRESENT : BOOLEAN := false;  
                    --  'True' specifies that a WrFIFO is required
                    
           C_WRFIFO_BASEADDR_OFFSET : std_logic_vector := X"00002100"; 
                    --  The address offset from Device BAR (in bytes)
                    
           C_WRFIFO_REG_BASEADDR_OFFSET : std_logic_vector := X"00002000"; 
                    --  The address offset from Device BAR (in bytes)
                    
           C_RDFIFO_PRESENT : BOOLEAN := false;  
                    --  'True' specifies that a RdFIFO is required
                    
           C_RDFIFO_BASEADDR_OFFSET : std_logic_vector := X"00002200";  
                    --  The address offset from Device BAR (in bytes)
                    
           C_RDFIFO_REG_BASEADDR_OFFSET : std_logic_vector := X"00002010"; 
                    --  The address offset from Device BAR (in bytes)
                    
           C_DMA_PRESENT : BOOLEAN := false;  
                    --  'True' specifies that a DMA function is required
                    
           C_DMA_REG_BASEADDR_OFFSET : std_logic_vector := X"00002300";  
                    --  The address offset from Device BAR (in bytes)
                    
           C_DMA_CHAN_NUM : INTEGER := 2;  
                    --  The number of desired DMA/SG channels (1 or 2)
                    
           C_DMA_CH1_TYPE : INTEGER := 2; 
                    --  0 = Simple DMA, 1 = SG, 2 = Tx, 3 = Rx
                    
           C_DMA_CH2_TYPE : INTEGER := 3;  
                    --  0 = Simple DMA, 1 = SG, 2 = Tx, 3 = Rx
                    
           C_DMA_ALLOW_BURST : BOOLEAN := false;  
                    -- 'True' allows DMA to initiate burst transfers, 'False'
                    -- inhibits DMA initiated bursts
                    
           C_DMA_LENGTH_WIDTH : INTEGER := 11;  
                    --  Maximum number of bits to use for DMA/SG 'Length" 
                    --  parameters
                    
           C_DMA_INTR_COALESCE : BOOLEAN := false;  
                    --  'True' specifies that the DMA/SG interrupt coalescing
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
                    
           C_IPIF_DBUS_WIDTH : INTEGER := 32;  
                    --  Set this equal to C_OPB_DBUS_WIDTH
                    
           C_VIRTEX_II : Boolean := false
                    -- Select the target architecture type
                    -- true = Virtex II, False = Virtex E
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
 
 
end component ipif;

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin
 

IPIF_BLK_I: IPIF 
  -- only set generics whose values need to change from defaults
  generic map (
           C_DEV_BLK_ID             => C_DEV_BLK_ID,
           C_DEV_MIR_ENABLE         => C_DEV_MIR_ENABLE, 
           C_DEV_ADDR_DECODE_WIDTH  => C_DEV_ADDR_DECODE_WIDTH,
           C_DEV_BASEADDR           => C_BASEADDR,  
           C_DEV_BURST_ENABLE       => false,           -- No Burst 
           C_RESET_PRESENT          => false,           -- No software reset
           C_INTERRUPT_PRESENT      => false,           -- No interrupts
           C_IP_IRPT_NUM            => 1,               -- No interrupts: set to 1 to avoid 0 to -1 stdlogicvec
           C_IP_MASTER_PRESENT      => false,           -- No bus master capability
           C_IP_REG_PRESENT         => true,            -- Registers preset
           C_IP_REG_BASEADDR_OFFSET => REG_OFFSET,      -- Offset from device bar for first register
           C_IP_REG_NUM             => C_NUM_MASTERS+1, -- Number of required IP register chip enables.
           C_IP_SRAM_PRESENT        => false,           -- No SRAM
           C_WRFIFO_PRESENT         => false,           -- No WrFIFO
           C_RDFIFO_PRESENT         => false,           -- No RdFIFO
           C_DMA_PRESENT            => false,           -- No DMA 
           C_OPB_ABUS_WIDTH         => C_OPB_ABUS_WIDTH,--  width of OPB Address Bus (in bits)
           C_OPB_DBUS_WIDTH         => C_OPB_DBUS_WIDTH,--  Width of the OPB Data Bus (in bits)
           C_OPB_BE_NUM             => C_OPB_DBUS_WIDTH/8,--  Number of OPB Bus byte enables used
           C_IPIF_ABUS_WIDTH        => IPIF_ABUS_WIDTH  -- set this constant in opb_arb_pkg
            )
  port map (
        OPB_ABus                    => OPB_ABus,
        OPB_DBus                    => OPB_DBus,
        Sln_DBus                    => Sln_DBus,
        Mn_ABus                     => open,
        IP2Bus_Addr                 => zero_addr,
        Bus2IP_Addr                 => open,
        Bus2IP_Data                 => Bus2IP_Data,
        Bus2IP_Reg_RdCE             => Bus2IP_Reg_RdCE,
        Bus2IP_Reg_WrCE             => Bus2IP_Reg_WrCE,
        Bus2IP_SRAM_CE              => open,
        IP2Bus_Data                 => IP2Bus_Data,
        IP2Bus_WrAck                => IP2Bus_WrAck,
        IP2Bus_RdAck                => IP2Bus_RdAck,
        IP2Bus_Retry                => '0',
        IP2Bus_Error                => '0',
        IP2Bus_ToutSup              => '0',
        IP2DMA_RxLength_Empty       => '0',
        IP2DMA_RxStatus_Empty       => '0',
        IP2DMA_TxLength_Full        => '0', 
        IP2DMA_TxStatus_Empty       => '0',
        IP2IP_Addr                  => zero_ip2ip_addr,
        IP2RFIFO_Data               => zero_rdfifo_data,
        IP2RFIFO_WrMark             => '0',
        IP2RFIFO_WrRelease          => '0',
        IP2RFIFO_WrReq              => '0',
        IP2RFIFO_WrRestore          => '0',
        IP2WFIFO_RdMark             => '0',
        IP2WFIFO_RdRelease          => '0',
        IP2WFIFO_RdReq              => '0',
        IP2WFIFO_RdRestore          => '0',
        IP2Bus_MstBE                => zero_be,
        IP2Bus_MstWrReq             => '0',
        IP2Bus_MstRdReq             => '0',
        IP2Bus_MstBurst             => '0',
        IP2Bus_MstBusLock           => '0',
        Bus2IP_MstWrAck             => open,
        Bus2IP_MstRdAck             => open,
        Bus2IP_MstRetry             => open,
        Bus2IP_MstError             => open,
        Bus2IP_MstTimeOut           => open,
        Bus2IP_MstLastAck           => open,
        Bus2IP_BE                   => open,
        Bus2IP_WrReq                => open,
        Bus2IP_RdReq                => open,
        Bus2IP_Burst                => open,
        Mn_request                  => open,
        Mn_busLock                  => open,
        Mn_select                   => open,
        Mn_RNW                      => open,
        Mn_BE                       => open,
        Mn_seqAddr                  => open,
        OPB_MnGrant                 => '0',
        OPB_xferAck                 => '0',
        OPB_errAck                  => '0',
        OPB_retry                   => '0',
        OPB_timeout                 => '0',
        Freeze                      => '0',
        RFIFO2IP_AlmostFull         => open,
        RFIFO2IP_Full               => open,
        RFIFO2IP_Vacancy            => open,
        RFIFO2IP_WrAck              => open,
        OPB_select                  => OPB_select,
        OPB_RNW                     => OPB_RNW,
        OPB_seqAddr                 => OPB_seqAddr,
        OPB_BE                      => OPB_BE,
        Sln_xferAck                 => Sln_XferAck,
        Sln_errAck                  => Sln_errAck,
        Sln_toutSup                 => Sln_toutSup,
        Sln_retry                   => Sln_retry,
        WFIFO2IP_AlmostEmpty        => open,
        WFIFO2IP_Data               => open,
        WFIFO2IP_Empty              => open,
        WFIFO2IP_Occupancy          => open,
        WFIFO2IP_RdAck              => open,
        Bus2IP_Clk                  => Bus2IP_Clk,
        Bus2IP_DMA_Ack              => open,
        Bus2IP_Freeze               => open,
        Bus2IP_Reset                => Bus2IP_Reset,
        IP2Bus_Clk                  => '0',
        IP2Bus_DMA_Req              => '0',
        IP2Bus_IntrEvent            => zero_intrevent,
        IP2INTC_Irpt                => open,
        OPBClk                      => OPB_Clk,
        Reset                       => Rst
        ); 

end implementation;

