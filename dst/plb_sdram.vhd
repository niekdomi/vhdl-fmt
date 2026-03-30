-------------------------------------------------------------------------------
-- $Id: plb_sdram.vhd,v 1.5 2004/08/02 21:26:43 gburch Exp $
-------------------------------------------------------------------------------
-- plb_sdram.vhd - entity/architecture pair
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
-- Filename:        plb_sdram.vhd
-- Version:         v1.00d
-- Description:     Top level file for PLB SDRAM controller
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--                  -- plb_sdram.vhd                  
--                      -- sdram_controller.vhd
--                          -- data_statemachine.vhd
--                          -- command_statemachine.vhd
--                          -- init_statemachine.vhd
--                          -- counters.vhd
--                          -- io_registers.vhd
--                          -- ipic_if.vhd
--                          -- clock_gen.vhd
--                      -- plb_ipif.vhd
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- @BEGIN_CHANGELOG EDK_Gmm_SP1
--
--  Added this change log.
--
--  Fixed problem with ip2bus_data not being driven with 0's when core was not
--  selected.
--
-- @END_CHANGELOG
-------------------------------------------------------------------------------
-- Author:          DAB
-- History:
--   DAB           07/01/02    First Version
-- ^^^^^^
--      First version of PLB sdram controller
-- ~~~~~~
--  ALS            07/31/02
-- ^^^^^^
--      Added support for bursts and cachelines
-- ~~~~~~
-- ALS              09/05/02
-- ^^^^^^
--      Changed IPIF arrays to work around XST array bugs. DUMMY entry in array
--      is now first so that the first element in the array is the max value
--      of the array. This means that DUMMY will occupy a 1 byte address space
--      which is the very upper byte of the SDRAM address range. This can
--      be fixed when XST is fixed.
-- ~~~~~~
-- ALS              10/08/02
-- ^^^^^^
--      Removed top-level ports & generic associated with including the DCM in
--      the core. Removed the following:
--          C_INCLUDE_SDRAMCLK_DCM
--          Clk       
--          DCM_locked
--          DCM_Rst 
-- ~~~~~~
--  ALS             03/31/03    
-- ^^^^^^
--  Added generic to allow use of either positive edge or negative edge output
--  registers and another generic to allow setting of the simulation initialization
--  time. Added output SDRAM_INIT_DONE to indicate that the initialization period
--  has completed. Sl_MErr is no longer asserted during transaction requests
--  during initialization. The data phase is held and not acknowledged until
--  initialization is complete.
-- ~~~~~~
--  ALS             04/15/03
-- ^^^^^^
--  Removed XST workaround that required a DUMMY entry to be first in the array.
--  This should allow the last byte of the SDRAM space to be accessed correctly.
-- ~~~~~~
--  ALS             10/06/03
-- ^^^^^^
-- Added plb_ipif_v1_00_e which no longer has the determinate timer and removes
-- the read restriction across row boundaries. Also includes the support for
-- indeterminate bursts and removes latency.
-- ~~~~~~
--  GAB             01/13/04
-- ^^^^^^
-- Added new PSFUtil attributes
-- Removed unused signals due to core optimizations.
-- ~~~~~~
--  GAB             07/13/04
-- ^^^^^^
--  - Modified data_statemachine.vhd to fix issue with ip2bus_data not being set
--  to 0 when core was not selected.  This fix was for CR190932 and CR190933.
--  - Added Change Log
--  - Updated mpd attributes
--  - Removed or_gate call from data_statemachine.vhd
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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;
use proc_common_v1_00_b.family.all;

library sdram_v1_00_d;
use sdram_v1_00_d.all;

library plb_ipif_v1_00_e;
use plb_ipif_v1_00_e.all;

library ipif_common_v1_00_b;
use ipif_common_v1_00_b.ipif_pkg.all;
use ipif_common_v1_00_b.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_INCLUDE_BURST_CACHELN_SUPPORT -- support PLB bursts and cacheline xfers
--      C_USE_POSEDGE_OUTREGS       -- use positive edge output registers if 1
--                                  -- use negative edge output registers if 0
--      C_INCLUDE_HIGHSPEED_PIPE    -- use pipeline on write cycle to increase op freq
--                                  -- set to 0 if C_USE_POSEDGE_OUTREGS=1
--      C_SDRAM_TMRD                -- Load Mode Register command cycle time             
--      C_SDRAM_TWR                 -- write recovery time                               
--      C_SDRAM_TCCD                -- read/write command to read/write command
--      C_SDRAM_TRAS                -- delay after ACTIVE command before                 
--                                  -- PRECHARGE command                                 
--      C_SDRAM_TRC                 -- delay after ACTIVE command before                 
--                                  -- another ACTIVE or AUTOREFRESH command             
--      C_SDRAM_TRFC                -- delay after AUTOREFRESH before another command    
--      C_SDRAM_TRCD                -- delay after ACTIVE before READ/WRITE              
--      C_SDRAM_TRRD                -- delay after ACTIVE row a before ACTIVE            
--                                  -- row b                                             
--      C_SDRAM_TRP                 -- delay after PRECHARGE command                     
--      C_SDRAM_TREF                -- refresh to refresh command interval               
--      C_SDRAM_REFRESH_NUMROWS     -- number of SDRAM rows         
--      C_SDRAM_CAS_LAT             -- CAS latency                                       
--      C_SDRAM_DWIDTH              -- total data width of all SDRAM devices               
--      C_SDRAM_AWIDTH              -- SDRAM row address width                             
--      C_SDRAM_COL_AWIDTH          -- SDRAM column address width                          
--      C_SDRAM_BANK_AWIDTH         -- SDRAM bank address width 
--      C_SDRAM_TREFI               -- auto-calculated average periodic refresh command interval
--      C_SIM_INIT_TIME_PS          -- SDRAM initialization time to be used in simulation
--      C_PLB_MID_WIDTH             -- log2(C_PLB_NUM_MASTERS) - auto-calculated
--      C_PLB_CLK_PERIOD_PS         -- clock frequency
--      C_FAMILY                    -- target FPGA family
--      C_BASEADDR                  -- SDRAM memory base address                                                                                 
--      C_HIGHADDR                  -- SDRAM memory high address
--      C_PLB_NUM_MASTERS           -- number of PLB masters
--      C_PLB_DWIDTH                -- IPIC data width                                   
--      C_PLB_AWIDTH                -- IPIC address width

-------------------------------------------------------------------------------
-- Definition of Ports:
--  -- PLB interface
--      PLB_ABus                -- PLB address bus
--      PLB_PAValid             -- PLB primary address valid indicator
--      PLB_SAValid             -- PLB secondary address valid indicator
--      PLB_rdPrim              -- PLB secondary to primary read request indicator
--      PLB_wrPrim              -- PLB secondary to primary write request indicator
--      PLB_masterID            -- PLB current master indicator
--      PLB_abort               -- PLB abort bus request indicator
--      PLB_busLock             -- PLB bus lock
--      PLB_RNW                 -- PLB read not write
--      PLB_BE                  -- PLB byte enables
--      PLB_MSize               -- PLB master data bus size
--      PLB_size                -- PLB transfer size
--      PLB_type                -- PLB transfer type
--      PLB_compress            -- PLB compressed data transfer indicator
--      PLB_guarded             -- PLB guarded transfer indicator
--      PLB_ordered             -- PLB synchronize transfer indicator
--      PLB_lockErr             -- PLB lock error indicator
--      PLB_wrDBus              -- PLB write data bus
--      PLB_wrBurst             -- PLB burst write transfer indicator
--      PLB_rdBurst             -- PLB burst read transfer indicator
--      PLB_pendReq             -- PLB pending request
--      PLB_pendPri             -- PLB pending request priority
--      PLB_reqPri              -- PLB request priority
--      Sl_addrAck              -- Slave address acknowledge
--      Sl_SSize                -- Slave data bus sizer
--      Sl_wait                 -- Slave wait indicator
--      Sl_rearbitrate          -- Slave rearbitrate bus indicator
--      Sl_wrDAck               -- Slave write data acknowledge
--      Sl_wrComp               -- Slave write transfer complete indicator
--      Sl_wrBTerm              -- Slave terminate write burst transfer
--      Sl_rdDBus               -- Slave read bus
--      Sl_rdWdAddr             -- Slave read word address
--      Sl_rdDAck               -- Slave read data acknowledge
--      Sl_rdComp               -- Slave read transfer complete indicator
--      Sl_rdBTerm              -- Slave terminate read burst transfer
--      Sl_MBusy                -- Slave busy indicator
--      Sl_MErr                 -- Slave error indicator
--
--  SDRAM interface signals
--      SDRAM_Clk               -- SDRAM clock             
--      SDRAM_CKE               -- SDRAM clock enable
--      SDRAM_CSn               -- SDRAM chip select
--      SDRAM_RASn              -- SDRAM row address strobe
--      SDRAM_CASn              -- SDRAM column address strobe
--      SDRAM_WEn               -- SDRAM write enable
--      SDRAM_DQM               -- SDRAM data mask
--      SDRAM_BankAddr          -- SDRAM bank address
--      SDRAM_Addr              -- SDRAM address
--      SDRAM_DQ_o              -- SDRAM DQ output
--      SDRAM_DQ_i              -- SDRAM DQ input
--      SDRAM_DQ_t              -- SDRAM DQ output enable
--
--    -- Timer or interrrupt signals
--      SDRAM_Init_done         -- SDRAM power-up/reset initialization is
--                              -- complete
--  Clocks and reset
--      PLB_Clk                 -- PLB clock
--      SDRAM_Clk_in            -- SDRAM clock feedback or PLB clock
--      PLB_Rst                 -- PLB Reset
-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity plb_sdram is
    generic (
        -- sdram generics
        C_INCLUDE_BURST_CACHELN_SUPPORT : integer  := 0;
        C_USE_POSEDGE_OUTREGS           : integer  := 0;
        C_INCLUDE_HIGHSPEED_PIPE        : integer  := 1;
        C_SDRAM_TMRD                    : integer  := 2;
        C_SDRAM_TWR                     : integer  := 15000;
        C_SDRAM_TCCD                    : integer  := 1;
        C_SDRAM_TRAS                    : integer  := 40000;
        C_SDRAM_TRC                     : integer  := 65000;
        C_SDRAM_TRFC                    : integer  := 75000;
        C_SDRAM_TRCD                    : integer  := 20000;
        C_SDRAM_TRRD                    : integer  := 15000;
        C_SDRAM_TRP                     : integer  := 20000;
        C_SDRAM_TREF                    : integer  := 64;
        C_SDRAM_REFRESH_NUMROWS         : integer  := 8192;
        C_SDRAM_CAS_LAT                 : integer  := 2;
        C_SDRAM_DWIDTH                  : integer  := 32;
        C_SDRAM_AWIDTH                  : integer  := 13;
        C_SDRAM_COL_AWIDTH              : integer  := 9;
        C_SDRAM_BANK_AWIDTH             : integer  := 2;

        -- simulation only generic (set to 100us)
        C_SIM_INIT_TIME_PS              : integer  := 100000000;
        
        -- auto-calculated generic
        C_SDRAM_TREFI                   : integer  := 7810000;
        C_PLB_MID_WIDTH                 : integer  := 2;
        
        -- ipif generics
        C_PLB_CLK_PERIOD_PS             : integer          := 10000  ;
        C_FAMILY                        : string           := "virtex2p";
        C_BASEADDR                      : std_logic_vector := X"FFFF_FFFF";
        C_HIGHADDR                      : std_logic_vector := X"0000_0000";
        -- sec. mem map addrsses (mapped to 0 to f_ffff)
		C_ADDR_B    					: std_logic_vector := X"FFB0_0000"; 
		C_ADDR_H    					: std_logic_vector := X"FFBF_FFFF"; 
        C_PLB_NUM_MASTERS               : integer          := 4;
        C_PLB_AWIDTH                    : integer          := 32;       
        C_PLB_DWIDTH                    : integer          := 64
        
     );  

  port
      (
        -- Clocks and reset
        PLB_Clk             : in  std_logic;
        SDRAM_Clk_in        : in  std_logic;
        PLB_Rst             : in  std_logic;

        -- PLB Slave signals
        PLB_ABus            : in  std_logic_vector(0 to C_PLB_AWIDTH-1);                            
        PLB_PAValid         : in  std_logic;                            
        PLB_SAValid         : in  std_logic;                            
        PLB_rdPrim          : in  std_logic;                            
        PLB_wrPrim          : in  std_logic;                            
        PLB_masterID        : in  std_logic_vector(0 to C_PLB_MID_WIDTH-1);                            
        PLB_abort           : in  std_logic;                            
        PLB_busLock         : in  std_logic;                            
        PLB_RNW             : in  std_logic;                            
        PLB_BE              : in  std_logic_vector(0 to (C_PLB_DWIDTH/8)-1);                            
        PLB_MSize           : in  std_logic_vector(0 to 1);                            
        PLB_size            : in  std_logic_vector(0 to 3);                            
        PLB_type            : in  std_logic_vector(0 to 2);                            
        PLB_compress        : in  std_logic;                            
        PLB_guarded         : in  std_logic;                            
        PLB_ordered         : in  std_logic;                            
        PLB_lockErr         : in  std_logic;                            
        PLB_wrDBus          : in  std_logic_vector(0 to C_PLB_DWIDTH-1);                            
        PLB_wrBurst         : in  std_logic;                            
        PLB_rdBurst         : in  std_logic;                            
        PLB_pendReq         : in  std_logic;
        PLB_pendPri         : in  std_logic_vector(0 to 1);        
        PLB_reqPri          : in  std_logic_vector(0 to 1);                            
        Sl_addrAck          : out std_logic;                            
        Sl_SSize            : out std_logic_vector(0 to 1);                            
        Sl_wait             : out std_logic;                            
        Sl_rearbitrate      : out std_logic;                            
        Sl_wrDAck           : out std_logic;                            
        Sl_wrComp           : out std_logic;                            
        Sl_wrBTerm          : out std_logic;                            
        Sl_rdDBus           : out std_logic_vector(0 to C_PLB_DWIDTH-1);                            
        Sl_rdWdAddr         : out std_logic_vector(0 to 3);                            
        Sl_rdDAck           : out std_logic;                            
        Sl_rdComp           : out std_logic;                            
        Sl_rdBTerm          : out std_logic;                            
        Sl_MBusy            : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);                            
        Sl_MErr             : out std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
      
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
        SDRAM_Init_done     : out std_logic

                                        
      );                                

    --fan-out attributes for XST
    attribute MAX_FANOUT                    : string;
    attribute MAX_FANOUT   of PLB_Clk       : signal is "10000";
    attribute MAX_FANOUT   of PLB_Rst       : signal is "10000";

    -- PSFUtil MPD attributes
    attribute IP_GROUP                      : string;
    attribute IP_GROUP of plb_sdram         : entity is "LOGICORE";
  
    attribute MIN_SIZE   : string;
    attribute MIN_SIZE of C_BASEADDR        : constant is "0x08";

    attribute SIGIS      : string;
    attribute SIGIS of PLB_Clk              : signal is "Clk";
    attribute SIGIS of PLB_Rst              : signal is "Rst";

    attribute XRANGE                        : string;
    attribute XRANGE of C_SDRAM_DWIDTH                      : constant is "(8,16,32,64)";
    attribute XRANGE of C_SDRAM_CAS_LAT                     : constant is "(2,3)";
    attribute XRANGE of C_INCLUDE_BURST_CACHELN_SUPPORT     : constant is "(0,1)";
    attribute XRANGE of C_USE_POSEDGE_OUTREGS               : constant is "(0,1)";
    attribute XRANGE of C_INCLUDE_HIGHSPEED_PIPE            : constant is "(0,1)";


    attribute ADDR_TYPE                         : string;
    attribute ADDR_TYPE of C_BASEADDR           : constant is "MEMORY";
    attribute ADDR_TYPE of C_HIGHADDR           : constant is "MEMORY";

    attribute ASSIGNMENT                        : string;
    attribute ASSIGNMENT of C_BASEADDR          : constant is "REQUIRE";
    attribute ASSIGNMENT of C_PLB_AWIDTH        : constant is "CONSTANT";
    attribute ASSIGNMENT of C_PLB_DWIDTH        : constant is "CONSTANT";


end plb_sdram;
-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture implementation of plb_sdram is

function bool2int(x: boolean) return integer is
begin
    if x then 
        return 1;
    else
        return 0;
    end if;
end function bool2int;

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- set the bus to be used - 
constant OPB_BUS        : integer := 0;
constant PLB_BUS        : integer := 1;

-- set the SDRAM burst size
constant SDRAM_BRST_SIZE     : integer  := C_PLB_DWIDTH/C_SDRAM_DWIDTH;

-- addresses are now expected to be 64-bits wide - create constants to 
-- zero the most significant address bits
constant ZERO_ADDR_PAD       : std_logic_vector(0 to 64-C_PLB_AWIDTH-1) := (others => '0');
constant SDRAM               : integer := 120;
constant SDRAM_SEC_MAP       : integer := 121;								--le
-- sec. mem map addrsses (mapped to 0 to f_ffff)
--constant C_ADDR_B    : std_logic_vector := X"FFB0_0000"; 
--constant C_ADDR_H    : std_logic_vector := X"FFBF_FFFF"; 

constant ARD_ID_ARRAY : INTEGER_ARRAY_TYPE :=
        (
         0 => SDRAM,   -- SDRAM 
         1 => SDRAM_SEC_MAP													--le
         );

constant ARD_ADDR_RANGE_ARRAY  : SLV64_ARRAY_TYPE :=
         (
          ZERO_ADDR_PAD & C_BASEADDR, -- SDRAM base addr
          ZERO_ADDR_PAD & C_HIGHADDR, -- SDRAM high addr
          ZERO_ADDR_PAD & C_ADDR_B,   										--le
          ZERO_ADDR_PAD & C_ADDR_H                                          --le
         );

constant ARD_DWIDTH_ARRAY     : INTEGER_ARRAY_TYPE :=
        (
         0 => C_PLB_DWIDTH,   --  SDRAM data width
         1 => C_PLB_DWIDTH													--le
        );

constant ARD_NUM_CE_ARRAY   : INTEGER_ARRAY_TYPE :=
        (
         0 => 1,    -- SDRAM CE number
         1 => 1																--le
        );

-- don't include MIR
constant DEV_MIR_ENABLE      : boolean   := false;
constant DEV_BLK_ID          : integer := 1;

-- set IPIF timeout counter to 64
constant DEV_DPHASE_TIMEOUT     : integer   := 64;

-- set IPIF burst page size 
constant DEV_BURST_ENABLE       : boolean := true;
constant DEV_FAST_DATA_XFER     : boolean := C_INCLUDE_BURST_CACHELN_SUPPORT /= 0; 
constant ADDR_OFFSET            : integer := log2(C_SDRAM_DWIDTH/8);
constant DEV_BURST_PAGE_SIZE    : integer := 
                    2**(C_SDRAM_AWIDTH+C_SDRAM_BANK_AWIDTH+C_SDRAM_COL_AWIDTH+ADDR_OFFSET); 
constant DEV_MAX_BURST_SIZE     : integer := DEV_BURST_PAGE_SIZE;

-- no interrupts
constant IP_INTR_MODE_ARRAY     : INTEGER_ARRAY_TYPE := (0,0);
constant IP_NUM_INTR            : integer := IP_INTR_MODE_ARRAY'length;
constant ZERO_INTREVENT         : std_logic_vector(0 to IP_NUM_INTR-1) := (others => '0');
constant INCLUDE_DEV_ISC        : BOOLEAN := false;
constant INCLUDE_DEV_PENCODER   : BOOLEAN := false;

-- no master, slave only
constant IP_MASTER_PRESENT      : BOOLEAN := false;

-- no FIFOs, just use default generics

-- zero constants for unused IPIF inputs
constant ZERO_ADDR      : std_logic_vector(0 to C_PLB_AWIDTH-1)   := (others => '0');
constant ZERO_DATA      : std_logic_vector(0 to C_PLB_DWIDTH-1)   := (others => '0');
constant ZERO_BE        : std_logic_vector(0 to C_PLB_DWIDTH/8-1) := (others => '0');

-- zero read fifo data input
constant RDFIFO_DWIDTH  : integer := C_PLB_DWIDTH;
constant ZERO_RFIFO_DATA: std_logic_vector(0 to RDFIFO_DWIDTH-1) := (others => '0');                                                      
-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------

-- IPIC Used Signals
signal ip2bus_addrack           : std_logic;
signal ip2bus_rdack             : std_logic;
signal ip2bus_wrack             : std_logic;
signal ip2bus_toutsup           : std_logic;
signal ip2bus_retry             : std_logic;
signal ip2bus_busy              : std_logic;
signal ip2bus_errack            : std_logic;
signal ip2bus_data              : std_logic_vector(0 to C_PLB_DWIDTH - 1);
signal bus2ip_addr              : std_logic_vector(0 to C_PLB_AWIDTH - 1);
signal bus2ip_data              : std_logic_vector(0 to C_PLB_DWIDTH - 1);
signal bus2ip_rnw               : std_logic;
signal bus2ip_rdreq             : std_logic;
signal bus2ip_wrreq             : std_logic;
signal bus2ip_cs                : std_logic_vector(0 to ((ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
signal bus2ip_ce                : std_logic_vector(0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);
signal bus2ip_rdce              : std_logic_vector(0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);
signal bus2ip_wrce              : std_logic_vector(0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);
signal bus2ip_be                : std_logic_vector(0 to (C_PLB_DWIDTH / 8) - 1);
signal bus2ip_burst             : std_logic;
signal bus2ip_clk               : std_logic;
signal bus2ip_reset             : std_logic; 

signal myBus2ip_cs				: std_logic;                              	--le
signal myBus2ip_addr        	: std_logic_vector(0 to C_PLB_AWIDTH - 1);

begin                                                                         




myBus2ip_cs <= Bus2ip_cs(0) or Bus2ip_cs(1); -- SDRAM addr or SDRAM 2.Map addr 
myBus2ip_addr <=  Bus2ip_addr and (C_ADDR_H-C_ADDR_B) when Bus2ip_cs(1)='1' else Bus2ip_addr;
-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
I_PLB_IPIF: entity plb_ipif_v1_00_e.plb_ipif
  generic map (
        C_ARD_ID_ARRAY          => ARD_ID_ARRAY,
        C_ARD_ADDR_RANGE_ARRAY  => ARD_ADDR_RANGE_ARRAY,
        C_ARD_DWIDTH_ARRAY      => ARD_DWIDTH_ARRAY,                
        C_ARD_NUM_CE_ARRAY      => ARD_NUM_CE_ARRAY,
        C_DEV_BLK_ID            => DEV_BLK_ID,  
        C_DEV_MIR_ENABLE        => DEV_MIR_ENABLE,                      
        C_DEV_BURST_ENABLE      => DEV_BURST_ENABLE,
        C_DEV_FAST_DATA_XFER    => DEV_FAST_DATA_XFER,
        C_DEV_BURST_PAGE_SIZE   => DEV_BURST_PAGE_SIZE,
        C_DEV_MAX_BURST_SIZE    => DEV_MAX_BURST_SIZE,
        C_DEV_DPHASE_TIMEOUT    => DEV_DPHASE_TIMEOUT,
        C_INCLUDE_DEV_ISC       => INCLUDE_DEV_ISC,
        C_INCLUDE_DEV_PENCODER  => INCLUDE_DEV_PENCODER,
        C_IP_INTR_MODE_ARRAY    => IP_INTR_MODE_ARRAY,
        C_IP_MASTER_PRESENT     => IP_MASTER_PRESENT,
        C_PLB_MID_WIDTH         => C_PLB_MID_WIDTH,
        C_PLB_NUM_MASTERS       => C_PLB_NUM_MASTERS,
        C_PLB_AWIDTH            => C_PLB_AWIDTH,  
        C_PLB_DWIDTH            => C_PLB_DWIDTH,  
        C_PLB_CLK_PERIOD_PS     => C_PLB_CLK_PERIOD_PS,  
        C_IPIF_DWIDTH           => C_PLB_DWIDTH,
        C_IPIF_AWIDTH           => C_PLB_AWIDTH,
        C_FAMILY                => C_FAMILY
        )
  port map (  
    -- System signals ---------------------------------------------------------    
        PLB_clk                 => PLB_Clk,                                 
        Reset                   => PLB_Rst,                                
        Freeze                  => '0',                                
        IP2INTC_Irpt            => open,                
    -- Bus Slave signals ------------------------------------------------------       
        PLB_ABus                => PLB_ABus      ,                          
        PLB_PAValid             => PLB_PAValid   ,
        PLB_SAValid             => PLB_SAValid   ,
        PLB_rdPrim              => PLB_rdPrim    ,
        PLB_wrPrim              => PLB_wrPrim    ,
        PLB_masterID            => PLB_masterID  ,                             
        PLB_abort               => PLB_abort     ,
        PLB_busLock             => PLB_busLock   ,
        PLB_RNW                 => PLB_RNW       ,
        PLB_BE                  => PLB_BE        ,                             
        PLB_MSize               => PLB_MSize     ,             
        PLB_size                => PLB_size      ,             
        PLB_type                => PLB_type      ,             
        PLB_compress            => PLB_compress  ,
        PLB_guarded             => PLB_guarded   ,
        PLB_ordered             => PLB_ordered   ,
        PLB_lockErr             => PLB_lockErr   ,
        PLB_wrDBus              => PLB_wrDBus    ,                          
        PLB_wrBurst             => PLB_wrBurst   ,
        PLB_rdBurst             => PLB_rdBurst   ,
        PLB_pendReq             => PLB_pendReq   ,
        PLB_pendPri             => PLB_pendPri   ,
        PLB_reqPri              => PLB_reqPri    ,             
        Sl_addrAck              => Sl_addrAck    ,
        Sl_SSize                => Sl_SSize      ,             
        Sl_wait                 => Sl_wait       ,
        Sl_rearbitrate          => Sl_rearbitrate,
        Sl_wrDAck               => Sl_wrDAck     ,
        Sl_wrComp               => Sl_wrComp     ,
        Sl_wrBTerm              => Sl_wrBTerm    ,
        Sl_rdDBus               => Sl_rdDBus     ,                          
        Sl_rdWdAddr             => Sl_rdWdAddr   ,             
        Sl_rdDAck               => Sl_rdDAck     ,
        Sl_rdComp               => Sl_rdComp     ,
        Sl_rdBTerm              => Sl_rdBTerm    ,
        Sl_MBusy                => Sl_MBusy      ,                               
        Sl_MErr                 => Sl_MErr       ,               
    -- Bus Master Signals -----------------------------------------------------        
        PLB_MAddrAck            => '0',                                
        PLB_MSSize              => "00",                                
        PLB_MRearbitrate        => '0',                                         
        PLB_MBusy               => '0',                                         
        PLB_MErr                => '0',                                         
        PLB_MWrDAck             => '0',                                         
        PLB_MRdDBus             => ZERO_DATA,                                
        PLB_MRdWdAddr           => "0000",
        PLB_MRdDAck             => '0',                                         
        PLB_MRdBTerm            => '0',         
        PLB_MWrBTerm            => '0',         
        M_request               => open,                                
        M_priority              => open,                                
        M_buslock               => open,                                        
        M_RNW                   => open,                                        
        M_BE                    => open,                                                                       
        M_MSize                 => open,                                                       
        M_size                  => open,                                                       
        M_type                  => open,                                                       
        M_compress              => open,                                        
        M_guarded               => open,                                        
        M_ordered               => open,                                        
        M_lockErr               => open,                                        
        M_abort                 => open,                                                                      
        M_ABus                  => open,                                                                    
        M_wrDBus                => open,                                                                    
        M_wrBurst               => open,                                           
        M_rdBurst               => open,                         
    -- IP Interconnect (IPIC) port signals -----------------------------------------        
        --System Signals
        IP2Bus_Clk              => '0',        
        Bus2IP_Clk              => open,        
        Bus2IP_Reset            => open,        
        Bus2IP_Freeze           => open,       
        -- IP Slave signals
        IP2Bus_IntrEvent        => ZERO_INTREVENT,        
        IP2Bus_Data             => ip2bus_data,                                
        IP2Bus_WrAck            => ip2bus_wrack,                                
        IP2Bus_RdAck            => ip2bus_rdack,        
        IP2Bus_Retry            => ip2bus_retry,
        IP2Bus_Error            => ip2bus_errack,
        IP2Bus_ToutSup          => ip2bus_toutsup,        
        IP2Bus_PostedWrInh      => '0',
        IP2Bus_Busy             => ip2bus_busy,
        IP2Bus_AddrAck          => ip2bus_addrack,
        IP2Bus_BTerm            => '0',
        Bus2IP_Addr             => bus2ip_addr,                               
        Bus2IP_Data             => bus2ip_data,                                
        Bus2IP_RNW              => bus2ip_rnw,             
        Bus2IP_BE               => bus2ip_be,        
        Bus2IP_Burst            => bus2ip_burst, 
        Bus2IP_IBurst           => open,
        Bus2IP_WrReq            => bus2ip_wrreq,        
        Bus2IP_RdReq            => bus2ip_rdreq, 
        Bus2IP_RNW_Early        => open,
        Bus2IP_PselHit          => open,
        Bus2IP_CS               => bus2ip_cs,        
        Bus2IP_CE               => open,                                                                 
        Bus2IP_RdCE             => open,                                                                 
        Bus2IP_WrCE             => open,                                                          
        -- IP to DMA Support Signals (Length and Status FIFO I/O)
        IP2DMA_RxLength_Empty   => '0',        
        IP2DMA_RxStatus_Empty   => '0',        
        IP2DMA_TxLength_Full    => '0',        
        IP2DMA_TxStatus_Empty   => '0',                                
        -- IP Master Signals
        IP2Bus_Addr             => ZERO_ADDR,        
        IP2Bus_MstBE            => ZERO_BE,        
        IP2IP_Addr              => ZERO_ADDR,        
        IP2Bus_MstWrReq         => '0',
        IP2Bus_MstRdReq         => '0',        
        IP2Bus_MstBurst         => '0',        
        IP2Bus_MstBusLock       => '0',        
        Bus2IP_MstWrAck         => open,        
        Bus2IP_MstRdAck         => open,        
        Bus2IP_MstRetry         => open,        
        Bus2IP_MstError         => open,        
        Bus2IP_MstTimeOut       => open,        
        Bus2IP_MstLastAck       => open,                
        -- RdPFIFO Signals
        IP2RFIFO_WrReq          => '0',        
        IP2RFIFO_Data           => ZERO_RFIFO_DATA,
        IP2RFIFO_WrMark         => '0',        
        IP2RFIFO_WrRelease      => '0',        
        IP2RFIFO_WrRestore      => '0',        
        RFIFO2IP_WrAck          => open,                
        RFIFO2IP_AlmostFull     => open,                
        RFIFO2IP_Full           => open,        
        RFIFO2IP_Vacancy        => open,
        -- WrPFIFO signals
        IP2WFIFO_RdReq          => '0',        
        IP2WFIFO_RdMark         => '0',
        IP2WFIFO_RdRelease      => '0',        
        IP2WFIFO_RdRestore      => '0',
        WFIFO2IP_Data           => open,                                
        WFIFO2IP_RdAck          => open,                
        WFIFO2IP_AlmostEmpty    => open,                
        WFIFO2IP_Empty          => open,                
        WFIFO2IP_Occupancy      => open,                
        -- IP DMA signals
        IP2Bus_DMA_Req          => '0',        
        Bus2IP_DMA_Ack          => open                
        ); 


-----------------------------------------------------------------------------
-- Instantiate the SDRAM Controller
-----------------------------------------------------------------------------
SDRAM_CTRL_I: entity sdram_v1_00_d.sdram_controller 
    generic map (
        C_INCLUDE_BURST_SUPPORT   =>  C_INCLUDE_BURST_CACHELN_SUPPORT,
        C_USE_POSEDGE_OUTREGS     =>  C_USE_POSEDGE_OUTREGS,
        C_INCLUDE_HIGHSPEED_PIPE  =>  C_INCLUDE_HIGHSPEED_PIPE,
        C_FAMILY                  =>  C_FAMILY              ,
        C_SDRAM_TMRD              =>  C_SDRAM_TMRD          ,
        C_SDRAM_TWR               =>  C_SDRAM_TWR           ,
        C_SDRAM_TCCD              =>  C_SDRAM_TCCD          ,
        C_SDRAM_TRAS              =>  C_SDRAM_TRAS          ,
        C_SDRAM_TRC               =>  C_SDRAM_TRC           ,
        C_SDRAM_TRFC              =>  C_SDRAM_TRFC          ,
        C_SDRAM_TRCD              =>  C_SDRAM_TRCD          ,
        C_SDRAM_TRRD              =>  C_SDRAM_TRRD          ,
        C_SDRAM_TREF              =>  C_SDRAM_TREF          ,
        C_SDRAM_TREFI             =>  C_SDRAM_TREFI         ,
        C_SDRAM_TRP               =>  C_SDRAM_TRP           ,
        C_SDRAM_CAS_LAT           =>  C_SDRAM_CAS_LAT       ,
        C_SDRAM_DWIDTH            =>  C_SDRAM_DWIDTH        ,
        C_SDRAM_AWIDTH            =>  C_SDRAM_AWIDTH        ,
        C_SDRAM_COL_AWIDTH        =>  C_SDRAM_COL_AWIDTH    ,
        C_SDRAM_BANK_AWIDTH       =>  C_SDRAM_BANK_AWIDTH   ,
        C_SDRAM_BRST_LEN          =>  SDRAM_BRST_SIZE       ,
        C_IPIF_DWIDTH             =>  C_PLB_DWIDTH        ,
        C_IPIF_AWIDTH             =>  C_PLB_AWIDTH        ,
        C_CLK_PERIOD              =>  C_PLB_CLK_PERIOD_PS ,          
        C_OPB_BUS                 =>  OPB_BUS             ,
        C_PLB_BUS                 =>  PLB_BUS             ,
        C_SIM_INIT_TIME_PS        =>  C_SIM_INIT_TIME_PS  
        )  
  port map (
--le        Bus2IP_Addr         =>  bus2ip_addr   ,                                            
        Bus2IP_Addr         =>  myBus2ip_addr   ,							--le    
        Bus2IP_BE           =>  bus2ip_be     ,                                            
        Bus2IP_Data         =>  bus2ip_data   ,                                            
        Bus2IP_RNW          =>  bus2ip_rnw    ,                                            
        Bus2IP_RdReq        =>  bus2ip_rdreq  ,                                            
        Bus2IP_WrReq        =>  bus2ip_wrreq  ,                                            
        Bus2IP_Burst        =>  bus2ip_burst  , 
--le    	Bus2IP_CS           =>  bus2ip_cs(0)  ,
		Bus2IP_CS           =>  myBus2ip_cs  ,  							--le                                          
        IP2Bus_Data         =>  ip2bus_data   ,                                            
        IP2Bus_AddrAck      =>  ip2bus_addrack,
        IP2Bus_RdAck        =>  ip2bus_rdack  ,                                            
        IP2Bus_WrAck        =>  ip2bus_wrack  ,                                            
        IP2Bus_ErrAck       =>  ip2bus_errack ,                                            
        IP2Bus_Retry        =>  ip2bus_retry  ,                                            
        IP2Bus_ToutSup      =>  ip2bus_toutsup, 
        IP2Bus_Busy         =>  ip2bus_busy   ,
        SDRAM_Clk           =>  SDRAM_Clk     ,                                            
        SDRAM_CKE           =>  SDRAM_CKE     ,                                            
        SDRAM_CSn           =>  SDRAM_CSn     ,                                            
        SDRAM_RASn          =>  SDRAM_RASn    ,                                            
        SDRAM_CASn          =>  SDRAM_CASn    ,                                            
        SDRAM_WEn           =>  SDRAM_WEn     ,                                            
        SDRAM_DQM           =>  SDRAM_DQM     ,                                            
        SDRAM_BankAddr      =>  SDRAM_BankAddr,                                            
        SDRAM_Addr          =>  SDRAM_Addr    ,                                            
        SDRAM_DQ_o          =>  SDRAM_DQ_o    ,                                            
        SDRAM_DQ_i          =>  SDRAM_DQ_i    ,                                            
        SDRAM_DQ_t          =>  SDRAM_DQ_t    , 
        SDRAM_Init_done     =>  SDRAM_Init_done,
        SDRAM_Clk_in        =>  SDRAM_Clk_in  ,                                            
        Sys_Clk             =>  PLB_Clk       ,                                            
        Rst                 =>  PLB_Rst                                                         
    );

end implementation;