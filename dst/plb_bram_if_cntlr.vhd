-------------------------------------------------------------------------------
-- $Id: plb_bram_if_cntlr.vhd,v 1.6 2003/05/19 22:27:15 anitas Exp $
-------------------------------------------------------------------------------
-- plb_bram.vhd - entity/architecture pair
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
-- Filename:        plb_bram.vhd
-- Version:         v1.00a
-- Description:     This is the top-level design file for the PLB BRAM
--                  Controller. It supports 1-16 masters and control for BRAM
--                  modules.
-------------------------------------------------------------------------------
-- Structure:
--
--              plb_bram_if_cntlr.vhd
--                 -- bram_if.vhd
--
--
-------------------------------------------------------------------------------
-- Author:      DAB
-- History:
--  DAB      06-13-2002      -- First version
--  ALS      04-25-2003      
-- ^^^^^^
-- Updated IPIF and added support for burst/cache line transactions
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
use ieee.std_logic_arith.conv_std_logic_vector;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;
use IEEE.std_logic_misc.all;

library Unisim;
use Unisim.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;
use proc_common_v1_00_b.family.all;
use proc_common_v1_00_b.all;

library ipif_common_v1_00_b;
use ipif_common_v1_00_b.ipif_pkg.all;
use ipif_common_v1_00_b.all;

library plb_ipif_v1_00_d;
use plb_ipif_v1_00_d.all;

library bram_if_cntlr_v1_00_a;
use bram_if_cntlr_v1_00_a.all;

--
-- library unsigned is used for overloading of "=" which allows integer to
-- be compared to std_logic_vector
use ieee.std_logic_unsigned.all;
--
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS          -- number of PLB masters
--      C_BASEADDR             -- BRAM memory base address                                                                                 
--      C_HIGHADDR             -- BRAM memory high address
--      C_INCLUDE_BURST_CACHELN_SUPPORT -- include support for PLB burst/cachelines
--      C_PLB_DWIDTH           -- PLB data width                                   
--      C_PLB_AWIDTH           -- PLB address width
--      C_PLB_CLK_PERIOD_PS    -- clock frequency in pico-seconds
--      C_PLB_MID_WIDTH        -- log2(C_PLB_NUM_MASTERS) - auto-calculated
--
-- Definition of Ports:
--  -- PLB Signals
--      PLB_Clk                -- PLB clock
--      PLB_Rst                -- PLB Reset
--      PLB_abort              -- PLB abort bus request indicator
--      PLB_ABus               -- PLB address bus
--      PLB_BE                 -- PLB byte enables
--      PLB_busLock            -- PLB bus lock
--      PLB_compress           -- PLB compressed data transfer indicator
--      PLB_guarded            -- PLB guarded transfer indicator
--      PLB_lockErr            -- PLB lock error indicator
--      PLB_masterID           -- PLB current master indicator
--      PLB_MSize              -- PLB master data bus size
--      PLB_ordered            -- PLB synchronize transfer indicator
--      PLB_PAValid            -- PLB primary address valid indicator
--      PLB_RNW                -- PLB read not write
--      PLB_size               -- PLB transfer size
--      PLB_type               -- PLB transfer type
--      Sl_addrAck             -- Slave address acknowledge
--      Sl_MBusy               -- Slave busy indicator
--      Sl_MErr                -- Slave error indicator
--      Sl_SSize               -- Slave data bus sizer
--      Sl_rearbitrate         -- Slave rearbitrate bus indicator
--      Sl_wait                -- Slave wait indicator
--      PLB_rdPrim             -- PLB secondary to primary read request indicator
--      PLB_SAValid            -- PLB secondary address valid indicator
--      PLB_wrPrim             -- PLB secondary to primary write request indicator
--      PLB_wrBurst            -- PLB burst write transfer indicator
--      PLB_wrDBus             -- PLB write data bus
--      Sl_wrBTerm             -- Slave terminate write burst transfer
--      Sl_wrComp              -- Slave write transfer complete indicator
--      Sl_wrDAck              -- Slave write data acknowledge
--      PLB_rdBurst            -- PLB burst read transfer indicator
--      Sl_rdBTerm             -- Slave terminate read burst transfer
--      Sl_rdComp              -- Slave read transfer complete indicator
--      Sl_rdDAck              -- Slave read data acknowledge
--      Sl_rdDBus              -- Slave read bus
--      Sl_rdWdAddr            -- Slave read word address
--      PLB_pendReq            -- PLB pending request
--      PLB_pendPri            -- PLB pending request priority
--      PLB_reqPri             -- PLB request priority
--
--  BRAM interface signals
--      BRAM_Rst               -- BRAM reset             
--      BRAM_CLK               -- BRAM clock
--      BRAM_EN                -- BRAM chip enable
--      BRAM_WEN               -- BRAM write enable
--      BRAM_Addr              -- BRAM address 
--      BRAM_Dout              -- BRAM write data
--      BRAM_Din               -- BRAM read data
-------------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity plb_bram_if_cntlr is
   -- Generics to be set by user
  generic (
    C_NUM_MASTERS                     : integer := 8;
    C_BASEADDR                        : std_logic_vector := X"FFFF_FFFF";
    C_HIGHADDR                        : std_logic_vector := X"0000_0000";

    --Generics set for IPIF
    C_INCLUDE_BURST_CACHELN_SUPPORT   : integer          := 0;
    C_PLB_DWIDTH                      : integer          := 64;
    C_PLB_AWIDTH                      : integer          := 32;
    C_PLB_CLK_PERIOD_PS               : integer          := 40000;
    C_PLB_MID_WIDTH                   : integer          := 3
        );

  port
      (
       -- System Port Declarations ********************************************

       PLB_Clk      :   in std_logic;
       PLB_Rst      :   in std_logic;

       -- PLB Port Declarations ***********************************************

       PLB_abort       : in std_logic;
       PLB_ABus        : in std_logic_vector(0 to C_PLB_AWIDTH-1);
       PLB_BE          : in std_logic_vector(0 to (C_PLB_DWIDTH/8)-1);
       PLB_busLock     : in std_logic;
       PLB_compress    : in std_logic;
       PLB_guarded     : in std_logic;
       PLB_lockErr     : in std_logic;
       PLB_masterID    : in  std_logic_vector(0 to C_PLB_MID_WIDTH-1);
       PLB_MSize       : in std_logic_vector(0 to 1);
       PLB_ordered     : in std_logic;
       PLB_PAValid     : in std_logic;
       PLB_RNW         : in std_logic;
       PLB_size        : in std_logic_vector(0 to 3);
       PLB_type        : in std_logic_vector(0 to 2);
       Sl_addrAck      : out std_logic;
       Sl_MBusy        : out std_logic_vector(0 to C_NUM_MASTERS-1);
       Sl_MErr         : out std_logic_vector(0 to C_NUM_MASTERS-1);
       Sl_rearbitrate  : out std_logic;
       Sl_SSize        : out std_logic_vector(0 to 1);
       Sl_wait         : out std_logic;
       PLB_rdPrim      : in std_logic;
       PLB_SAValid     : in std_logic;
       PLB_wrPrim      : in std_logic;
       PLB_wrBurst     : in std_logic;
       PLB_wrDBus      : in std_logic_vector(0 to C_PLB_DWIDTH-1);
       Sl_wrBTerm      : out std_logic;
       Sl_wrComp       : out std_logic;
       Sl_wrDAck       : out std_logic;
       PLB_rdBurst     : in std_logic;
       Sl_rdBTerm      : out std_logic;
       Sl_rdComp       : out std_logic;
       Sl_rdDAck       : out std_logic;
       Sl_rdDBus       : out std_logic_vector(0 to C_PLB_DWIDTH-1);
       Sl_rdWdAddr     : out std_logic_vector(0 to 3) ;
       PLB_pendReq     : in  std_logic;
       PLB_pendPri     : in  std_logic_vector(0 to 1);
       PLB_reqPri      : in  std_logic_vector(0 to 1);


       -- User BRAM Ports 

       BRAM_Rst        : out std_logic;
       BRAM_Clk        : out std_logic;
       BRAM_EN         : out std_logic;
       BRAM_WEN        : out std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
       BRAM_Addr       : out std_logic_vector(0 to C_PLB_AWIDTH-1);
       BRAM_Din        : in std_logic_vector(0 to C_PLB_DWIDTH-1);
       BRAM_Dout       : out std_logic_vector(0 to C_PLB_DWIDTH-1)

      );

      --fan-out attributes for XST
      attribute MAX_FANOUT                  : string;
      attribute MAX_FANOUT   of PLB_Clk     : signal is "10000";
      attribute MAX_FANOUT   of PLB_Rst     : signal is "10000";

      -- PSFUtil MPD attributes
      attribute MIN_SIZE    : string;
      attribute MIN_SIZE of C_BASEADDR : constant is "0x4000";

      attribute SIGIS       : string;
      attribute SIGIS of PLB_CLK : signal is "CLK";
      attribute SIGIS of PLB_Rst : signal is "RST";
      
      attribute SPECIAL     : string;
      attribute SPECIAL of plb_bram_if_cntlr:entity is "BRAM_CNTLR";
      
      attribute ADDR_SLICE  : integer;
      attribute ADDR_SLICE of plb_bram_if_cntlr:entity is 28;
      
      attribute NUM_WRITE_ENABLES : integer;
      attribute NUM_WRITE_ENABLES of plb_bram_if_cntlr:entity is 8;
      
      attribute AWIDTH      : integer;
      attribute AWIDTH of plb_bram_if_cntlr:entity is 32;
      
      attribute DWIDTH      : integer;
      attribute DWIDTH of plb_bram_if_cntlr:entity is 64;
      
end plb_bram_if_cntlr;
-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture implementation of plb_bram_if_cntlr is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
constant ZERO_ADDR_PAD       : std_logic_vector(0 to 64-C_PLB_AWIDTH-1) := (others => '0');
constant BRAM                : integer := 120;
constant DUMMY               : integer := 121;


    constant ARD_ID_ARRAY : INTEGER_ARRAY_TYPE :=
            (
             0 => BRAM, -- BRAM
             1 => DUMMY -- dummy
             );

    constant ARD_ADDR_RANGE_ARRAY  : SLV64_ARRAY_TYPE :=
            (
             ZERO_ADDR_PAD & C_BASEADDR     , -- BRAM Base Address
             ZERO_ADDR_PAD & C_HIGHADDR     , -- BRAM High Address
             ZERO_ADDR_PAD & (C_BASEADDR xor x"0800_0000")    , -- dummy
             ZERO_ADDR_PAD & (C_HIGHADDR xor x"0800_0000")      -- dummy
            );

    constant ARD_DWIDTH_ARRAY     : INTEGER_ARRAY_TYPE :=
               (
                0 => C_PLB_DWIDTH,   --  BRAM data width
                1 => C_PLB_DWIDTH    --  dummy
               );

    constant ARD_NUM_CE_ARRAY   : INTEGER_ARRAY_TYPE :=
               (
                0 => 1,     -- BRAM CE number
                1 => 1      -- dummy
               );

    constant ARD_DTIME_READ_ARRAY   : INTEGER_ARRAY_TYPE :=
              -- Mode, Latency, Wait States
               (
                1, 1, 0,    -- bram
                1, 1, 0     -- dummy
                );

    constant ARD_DTIME_WRITE_ARRAY   : INTEGER_ARRAY_TYPE :=
         -- Mode, Latency, Wait States
         (
          0,0,0, -- BRAM write cycles         
          0,0,0  -- dummy                  
         );
                
    -- MIR is not used
    constant DEV_BLK_ID : INTEGER := 0;
    constant DEV_MIR_ENABLE      : boolean   := false;
    
   -- If Burst is enabled, then this parameter will allow the selection 
   -- of a fast data transfer mode (1 clk per databeat but FPGA resource
   -- intensive) or a slower multi-clock per databeat transfer mode
   -- (but saves FPGA resources).
    constant DEV_FAST_DATA_XFER  : boolean  := true;

    constant DEV_MAX_BURST_SIZE     : integer   := 64;
    constant DEV_BURST_PAGE_SIZE    : integer   := 1024;        

    constant DEV_DPHASE_TIMEOUT     : integer   := 64;

    -- no interrupts
    constant INCLUDE_DEV_ISC        : boolean   := false;
    constant INCLUDE_DEV_PENCODER   : boolean   := false;
    constant IP_INTR_MODE_ARRAY     : integer_array_type := (0,0);

    -- slave only
    constant IP_MASTER_PRESENT      : boolean   := false;

    -- no FIFOs
    constant WRFIFO_DEPTH               : integer range 4 to 16384 := 512;
    constant WRFIFO_INCLUDE_PACKET_MODE : boolean := false;
    constant WRFIFO_INCLUDE_VACANCY     : boolean := false;
    constant RDFIFO_DEPTH               : integer range 4 to 16384 := 512;
    constant RDFIFO_INCLUDE_PACKET_MODE : boolean := false;
    constant RDFIFO_INCLUDE_VACANCY     : boolean := false;


    -- PLB settings
    constant PLB_NUM_MASTERS    : integer := C_NUM_MASTERS;
    constant PLB_DWIDTH         : integer := C_PLB_DWIDTH;
    constant PLB_AWIDTH         : integer := C_PLB_AWIDTH;
    constant PLB_CLK_PERIOD_PS  : integer := C_PLB_CLK_PERIOD_PS;
    constant IPIF_AWIDTH        : integer := C_PLB_AWIDTH;
    constant IPIF_DWIDTH        : integer := C_PLB_DWIDTH;


    -- other constants calculated from arrays
    constant WRFIFO_DWIDTH      : integer := find_id_dwidth(ARD_ID_ARRAY,
                                                       ARD_DWIDTH_ARRAY,
                                                       IPIF_WRFIFO_DATA,
                                                       32);

    constant RDFIFO_DWIDTH      : integer := find_id_dwidth(ARD_ID_ARRAY,
                                                      ARD_DWIDTH_ARRAY,
                                                      IPIF_RDFIFO_DATA,
                                                      32);

    constant CS_BUS_WIDTH        :  integer := ARD_ADDR_RANGE_ARRAY'LENGTH/2;
    constant CE_BUS_WIDTH        :  integer := calc_num_ce(ARD_NUM_CE_ARRAY);
    constant RDFIFO_DEPTH_Log2X  :  integer := log2(RDFIFO_DEPTH);
    constant WRFIFO_DEPTH_Log2X  :  integer := log2(WRFIFO_DEPTH);
    constant IP_NUM_INTR         :  integer := IP_INTR_MODE_ARRAY'length;



-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------

-- IPIC Used Signals

  signal IP2Bus_rdAck             : std_logic;
  signal IP2Bus_wrAck             : std_logic;
  signal IP2Bus_toutSup           : std_logic;
  signal IP2Bus_retry             : std_logic;
  signal IP2Bus_errAck            : std_logic;
  signal IP2Bus_Data              : std_logic_vector(0 to IPIF_DWIDTH - 1);
  signal Bus2IP_Addr              : std_logic_vector(0 to IPIF_AWIDTH - 1);
  signal Bus2IP_Data              : std_logic_vector(0 to IPIF_DWIDTH - 1);
  signal Bus2IP_RNW               : std_logic;
  signal Bus2IP_RdReq             : std_logic;
  signal Bus2IP_WrReq             : std_logic;
  signal Bus2IP_AValid            : std_logic;
  signal Bus2IP_CS                : std_logic_vector(0 to ((ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
  signal Bus2IP_CE                : std_logic_vector(0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);
  signal Bus2IP_RdCE              : std_logic_vector(0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);
  signal Bus2IP_WrCE              : std_logic_vector(0 to calc_num_ce(ARD_NUM_CE_ARRAY)-1);
  signal Bus2IP_BE                : std_logic_vector(0 to (IPIF_DWIDTH / 8) - 1);
  signal Bus2IP_Burst             : std_logic;

-- IPIF Signals

  signal Freeze                  : std_logic := '0';
  signal PLB_MAddrAck            : std_logic := '0';
  signal PLB_MSSize              : std_logic_vector(0 to 1);
  signal PLB_MRearbitrate        : std_logic := '0';
  signal PLB_MBusy               : std_logic := '0';
  signal PLB_MErr                : std_logic := '0';
  signal PLB_MWrDAck             : std_logic := '0';
  signal PLB_MRdDBus             : std_logic_vector(0 to
                                          (PLB_DWIDTH-1));
  signal PLB_MRdWdAddr           : std_logic_vector(0 to 3);
  signal PLB_MRdDAck             : std_logic := '0';
  signal PLB_MRdBTerm            : std_logic := '0';
  signal PLB_MWrBTerm            : std_logic := '0';
  signal M_request               : std_logic;
  signal M_priority              : std_logic_vector(0 to 1);
  signal M_buslock               : std_logic;
  signal M_RNW                   : std_logic;
  signal M_BE                    : std_logic_vector(0 to
                                            (PLB_DWIDTH/8)-1);
  signal M_MSize                 : std_logic_vector(0 to 1);
  signal M_size                  : std_logic_vector(0 to 3);
  signal M_type                  : std_logic_vector(0 to 2);
  signal M_compress              : std_logic;
  signal M_guarded               : std_logic;
  signal M_ordered               : std_logic;
  signal M_lockErr               : std_logic;
  signal M_abort                 : std_logic;
  signal M_ABus                  : std_logic_vector(0 to PLB_AWIDTH-1);
  signal M_wrDBus                : std_logic_vector(0 to PLB_DWIDTH-1);
  signal M_wrBurst               : std_logic;
  signal M_rdBurst               : std_logic;

           -- IP Interconnect (IPIC) port signals -----------------------------------------
               --System Signals
  signal IP2Bus_Clk              : std_logic := '0';
  signal Bus2IP_Clk              : std_logic;
  signal Bus2IP_Reset            : std_logic;
  signal Bus2IP_Freeze           : std_logic;

               -- IP Slave signals
  signal IP2Bus_IntrEvent        : std_logic_vector(0 to IP_INTR_MODE_ARRAY'length-1);
  signal IP2Bus_Error            : std_logic := '0';
         -- IP to DMA Support Signals (Length and Status FIFO I/O)
  signal IP2DMA_RxLength_Empty   : std_logic := '0';
  signal IP2DMA_RxStatus_Empty   : std_logic := '0';
  signal IP2DMA_TxLength_Full    : std_logic := '0';
  signal IP2DMA_TxStatus_Empty   : std_logic := '0';

          -- IP Master Signals
  signal  IP2Bus_Addr             : std_logic_vector(0 to IPIF_AWIDTH - 1 ) := (others => '0');
  signal  IP2Bus_MstBE            : std_logic_vector(0 to (IPIF_DWIDTH/8) - 1 ) := (others  => '0');
  signal  IP2IP_Addr              : std_logic_vector(0 to IPIF_AWIDTH - 1 ) := (others  => '0');
  signal  IP2Bus_MstWrReq         : std_logic := '0';
  signal  IP2Bus_MstRdReq         : std_logic := '0';
  signal  IP2Bus_MstBurst         : std_logic := '0';
  signal  IP2Bus_MstBusLock       : std_logic := '0';
  signal  Bus2IP_MstWrAck         : std_logic;
  signal  Bus2IP_MstRdAck         : std_logic;
  signal  Bus2IP_MstRetry         : std_logic;
  signal  Bus2IP_MstError         : std_logic;
  signal  Bus2IP_MstTimeOut       : std_logic;
  signal  Bus2IP_MstLastAck       : std_logic;


         -- RdPFIFO Signals
  signal IP2RFIFO_WrReq          : std_logic := '0';
  signal IP2RFIFO_Data           : std_logic_vector(0 to RDFIFO_DWIDTH-1 );
  signal IP2RFIFO_WrMark         : std_logic := '0';
  signal IP2RFIFO_WrRelease      : std_logic := '0';
  signal IP2RFIFO_WrRestore      : std_logic := '0';
  signal RFIFO2IP_WrAck          : std_logic;
  signal RFIFO2IP_AlmostFull     : std_logic;
  signal RFIFO2IP_Full           : std_logic;
  signal RFIFO2IP_Vacancy        : std_logic_vector(0 to log2(RDFIFO_DEPTH));

          -- WrPFIFO signals
  signal IP2WFIFO_RdReq          : std_logic := '0';
  signal IP2WFIFO_RdMark         : std_logic := '0';
  signal IP2WFIFO_RdRelease      : std_logic := '0';
  signal IP2WFIFO_RdRestore      : std_logic := '0';
  signal WFIFO2IP_Data           : std_logic_vector(0 to WRFIFO_DWIDTH-1 );
  signal WFIFO2IP_RdAck          : std_logic;
  signal WFIFO2IP_AlmostEmpty    : std_logic;
  signal WFIFO2IP_Empty          : std_logic;
  signal WFIFO2IP_Occupancy      : std_logic_vector(0 to log2(WRFIFO_DEPTH));
               -- IP DMA signals
  signal IP2Bus_DMA_Req          : std_logic := '0';
  signal Bus2IP_DMA_Ack          : std_logic;
  
  signal myBus2ip_cs				: std_logic;                              	--le
signal myBus2ip_addr        	: std_logic_vector(0 to C_PLB_AWIDTH - 1);

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
component plb_ipif
  generic (
        
        C_ARD_ID_ARRAY :  INTEGER_ARRAY_TYPE :=
                --see ipif_pkg.vhd for reserved ID definitions
                (
                 IPIF_INTR,         -- ipif interrupt (pre-defined keyword)
                 USER_00,           -- user ID (pre-defined keyword)
                 USER_01,           -- user ID (pre-defined keyword) 
                 USER_02,           -- user ID (pre-defined keyword) 
                 IPIF_RST,          -- ipif reset (pre-defined keyword)
                 IPIF_WRFIFO_REG,   -- ipif wrfifo registers (pre-defined keyword)
                 IPIF_WRFIFO_DATA,  -- ipif wrfifo data (pre-defined keyword)
                 IPIF_RDFIFO_REG,   -- ipif rdfifo registers (pre-defined keyword)
                 IPIF_RDFIFO_DATA,  -- ipif rdfifo data (pre-defined keyword)
                 IPIF_SESR_SEAR     -- IPIF SESR/SEAR Registers
                );
                
        C_ARD_ADDR_RANGE_ARRAY  : SLV64_ARRAY_TYPE :=
               -- Base address and high address pairs.
                (
                 X"0000_0000_1000_0000", -- IPIF Interrupt base address
                 X"0000_0000_1000_01FF", -- IPIF Interrupt high address
                 X"0000_0000_7000_0000", -- IP user0 base address  
                 X"0000_0000_7000_00FF", -- IP user0 high address  
                 X"0000_0000_8000_0000", -- IP user1 base address
                 X"0000_0000_8FFF_FFFF", -- IP user1 high address
                 X"0000_0000_9000_0000", -- IP user2 base address
                 X"0000_0000_9FFF_FFFF", -- IP user2 high address
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
                 X"0000_0000_1000_2400", -- IPIF SESR/SEAR Register base address 
                 X"0000_0000_1000_241F"  -- IPIF SESR/SEAR Register high address      
                );
                
        C_ARD_DWIDTH_ARRAY     : INTEGER_ARRAY_TYPE :=
              -- This array specifies the data bus width of the memory address
              -- range specified for the cooresponding baseaddr pair.
                (
                 32,    -- IPIF Interrupt data width
                 32,    -- User0 data width
                 64,    -- User1 data width
                 8,     -- User2 data width
                 32,    -- IPIF Reset data width
                 32,    -- IPIF WrFIFO Registers data width
                 16,    -- IPIF WrFIFO Data data width
                 32,    -- IPIF RdFIFO Registers data width
                 8,     -- IPIF RdFIFO Data width
                 32     -- IPIF SESR/SEAR Register data width
                );
                
        C_ARD_NUM_CE_ARRAY   : INTEGER_ARRAY_TYPE :=
              -- This array spcifies the number of Chip Enables (CE) that is 
              -- required by the cooresponding baseaddr pair.
                (
                 16,    -- IPIF Interrupt CE Number
                 8,     -- User0 CE Number
                 1,     -- User1 CE Number
                 1,     -- User2 CE Number
                 1,     -- IPIF Reset CE Number
                 2,     -- IPIF WrFIFO Registers CE Number
                 1,     -- IPIF WrFIFO Data data CE Number
                 2,     -- IPIF RdFIFO Registers CE Number
                 1,     -- IPIF RdFIFO Data CE Number
                 2      -- IPIF SESR/SEAR Register CE Number
                );
  
        C_ARD_DTIME_READ_ARRAY   : INTEGER_ARRAY_TYPE :=
                -- Mode, Latency, Wait States
                (
                 0,0,0, -- IPIF Interrupt Determinate Read Params        
                 0,0,0, -- User0 Determinate Read Params                  
                 0,0,0, -- User1 Determinate Read Params                  
                 0,0,0, -- User2 Determinate Read Params                  
                 0,0,0, -- IPIF Reset Determinate Read Params             
                 0,0,0, -- IPIF WrFIFO Registers Determinate Read Params  
                 0,0,0, -- IPIF WrFIFO Data data Determinate Read Params  
                 0,0,0, -- IPIF RdFIFO Registers Determinate Read Params  
                 0,0,0, -- IPIF RdFIFO Data Determinate Read Params       
                 0,0,0  -- IPIF SESR/SEAR Register Determinate Read Params
                );
        
        C_ARD_DTIME_WRITE_ARRAY   : INTEGER_ARRAY_TYPE :=
                -- Mode, Latency, Wait States
                (
                 0,0,0, -- IPIF Interrupt Determinate Write Params         
                 0,0,0, -- User0 Determinate Write Params                  
                 0,0,0, -- User1 Determinate Write Params                  
                 0,0,0, -- User2 Determinate Write Params                  
                 0,0,0, -- IPIF Reset Determinate Write Params             
                 0,0,0, -- IPIF WrFIFO Registers Determinate Write Params  
                 0,0,0, -- IPIF WrFIFO Data data Determinate Write Params  
                 0,0,0, -- IPIF RdFIFO Registers Determinate Write Params  
                 0,0,0, -- IPIF RdFIFO Data Determinate Write Params       
                 0,0,0  -- IPIF SESR/SEAR Register Determinate Write Params
                );
        
           C_DEV_BLK_ID : INTEGER := 1;  
              --  Platform Builder Assiged Device ID number (unique
              --  for each device)
                    
           C_DEV_MIR_ENABLE : BOOLEAN := true;  
              --  Used to Enable/Disable Module ID functions
                    
           C_DEV_BURST_ENABLE : BOOLEAN := true;  
              -- Burst Enable for IPIF Interface
                    
           C_DEV_FAST_DATA_XFER : Boolean := false;
               -- If Burst is enabled, then this parameter will allow the selection 
               -- of a fast data transfer mode (1 clk per databeat but FPGA resource
               -- intensive) or a slower multi-clock per databeat transfer mode
               -- (but saves FPGA resources).
           
           C_DEV_MAX_BURST_SIZE : INTEGER := 64;  
               -- Maximum burst size to be supported (in bytes)
               
           C_DEV_BURST_PAGE_SIZE : Integer := 1024;
               -- Maximum supported burst address page size (bytes).
               -- Crossing a page boundry during a single burst  
               -- transaction will result in address wrapping.
                    
           C_DEV_DPHASE_TIMEOUT : Integer := 64;
               -- The number of bus clocks to use as a timeout of 
               -- data acknowledges within the device. If this parameter
               -- is set to 0, the WDT function is removed.
                    
           C_INCLUDE_DEV_ISC : BOOLEAN := true;
               -- 'true' specifies that the full device interrupt
               -- source controller structure will be included;
               -- 'false' specifies that only the global interrupt
               -- enable is present in the device interrupt source
               -- controller and that the only source of interrupts
               -- in the device is the IP interrupt source controller

           C_INCLUDE_DEV_PENCODER : BOOLEAN := true;  
               -- 'true' will include the Device IID in the IPIF Interrupt
               -- function
                    
           C_IP_INTR_MODE_ARRAY   : INTEGER_ARRAY_TYPE :=
               -- If an IPIF interrupt module is specified, this array 
               -- specifies the type of interrupt capture mode for each
               -- interrupt input from the IP design. Note: The number
               -- of entries in the array denotes how many IP interrupts
               -- are needed.
                (
                 INTR_PASS_THRU,        -- pass through (non-inverting)
                 INTR_PASS_THRU_INV,    -- pass through (inverting)
                 INTR_REG_EVENT,        -- registered level (non-inverting)
                 INTR_REG_EVENT_INV,    -- registered level (inverting)
                 INTR_POS_EDGE_DETECT,  -- positive edge detect
                 INTR_NEG_EDGE_DETECT,  -- negative edge detect
                 INTR_NEG_EDGE_DETECT,  -- negative edge detect
                 INTR_POS_EDGE_DETECT   -- positive edge detect
                );
           
           C_IP_MASTER_PRESENT : BOOLEAN := false;  
                -- 'true' specifies that the IP has Bus Master capability
                    
           C_WRFIFO_DEPTH    : Integer range 4 to 16384 := 512;     
                -- If a WRFIFO is specified, then this is
                -- the number of storage locations for the 
                -- WRFIFO. Should be a power of 2.
                
           C_WRFIFO_INCLUDE_PACKET_MODE : Boolean := false;
                -- If a WRFIFO is specified, then this is
                -- the selection of inclusion of packet mode features            
                -- on the IP interface
           
           C_WRFIFO_INCLUDE_VACANCY     : Boolean := true;
                -- If a WRFIFO is specified, then this is
                -- the selection of inclusion of vacancy calculation
                -- on the 'Write' interface of FIFO.                           
           
           C_RDFIFO_DEPTH    : Integer range 4 to 16384 := 512;     
                -- If a RDFIFO is specified, then this is
                -- the number of storage locations for the 
                -- RDFIFO. Should be a power of 2.
                
           C_RDFIFO_INCLUDE_PACKET_MODE : Boolean := false;
                -- If a RDFIFO is specified, then this is
                -- the selection of inclusion of packet mode features            
                -- on the IP interface
           
           C_RDFIFO_INCLUDE_VACANCY     : Boolean := true;
                -- If a RDFIFO is specified, then this is
                -- the selection of inclusion of vacancy calculation
                -- on the 'Write' interface of FIFO.                           
           
           C_PLB_MID_WIDTH : Integer := 3;
                -- The width of the Master ID bus 
                -- This is set to log2(C_PLB_NUM_MASTERS)
           
           C_PLB_NUM_MASTERS : Integer := 8;
                -- The number of Master Devices connected to the PLB bus
                -- Research this to find out default value
           
           C_PLB_AWIDTH : INTEGER := 32;  
                --  width of OPB Address Bus (in bits)
                    
           C_PLB_DWIDTH : INTEGER := 64;  
                --  Width of the OPB Data Bus (in bits)
                    
           C_PLB_CLK_PERIOD_PS : INTEGER := 10000;  
               --  The period of the OPB Bus clock in ps (10000 = 10ns)
                    
           C_IPIF_DWIDTH : INTEGER := 64;  
               --  Set this equal to largest data bus width needed by IPIF
               --  and IP elements.
                    
           C_IPIF_AWIDTH : INTEGER := 32;  
               --  Set this equal to C_PLB_AWIDTH
                    
           C_FAMILY : String := virtex2
               -- Select the target architecture type
               -- see the family.vhd package in the proc_common
               -- library
           );
  port (
  
    -- System signals ---------------------------------------------------------
    
        PLB_clk                 : in std_logic; 
                                
        Reset                   : in std_logic;
                                
        Freeze                  : in std_logic;
                                
        IP2INTC_Irpt            : out std_logic;
        
        
    -- Bus Slave signals ------------------------------------------------------   
    
        PLB_ABus                : in  std_logic_vector(0 to 
                                                       C_PLB_AWIDTH-1);
                                
        PLB_PAValid             : in  std_logic;
                                
        PLB_SAValid             : in  std_logic;
                                
        PLB_rdPrim              : in  std_logic;
                                
        PLB_wrPrim              : in  std_logic;
                                
        PLB_masterID            : in  std_logic_vector(0 to C_PLB_MID_WIDTH-1);
                                
        PLB_abort               : in  std_logic;
                                
        PLB_busLock             : in  std_logic;
                                
        PLB_RNW                 : in  std_logic;
                                
        PLB_BE                  : in  std_logic_vector(0 to 
                                                     (C_PLB_DWIDTH/8) - 1);
                                
        PLB_MSize               : in  std_logic_vector(0 to 1);
                                
        PLB_size                : in  std_logic_vector(0 to 3);
                                
        PLB_type                : in  std_logic_vector(0 to 2);
                                
        PLB_compress            : in  std_logic;
                                
        PLB_guarded             : in  std_logic;
                                
        PLB_ordered             : in  std_logic;
                                
        PLB_lockErr             : in  std_logic;
                                
        PLB_wrDBus              : in  std_logic_vector(0 to 
                                                       C_PLB_DWIDTH-1);
                                
        PLB_wrBurst             : in  std_logic;
                                
        PLB_rdBurst             : in  std_logic;
                                
        PLB_pendReq             : in  std_logic;
        
        PLB_pendPri             : in  std_logic_vector(0 to 1);
        
        PLB_reqPri              : in  std_logic_vector(0 to 1);
                                
        Sl_addrAck              : out std_logic;
                                
        Sl_SSize                : out std_logic_vector(0 to 1);
                                
        Sl_wait                 : out std_logic;
                                
        Sl_rearbitrate          : out std_logic;
                                
        Sl_wrDAck               : out std_logic;
                                
        Sl_wrComp               : out std_logic;
                                
        Sl_wrBTerm              : out std_logic;
                                
        Sl_rdDBus               : out std_logic_vector(0 to 
                                                       C_PLB_DWIDTH-1);
                                
        Sl_rdWdAddr             : out std_logic_vector(0 to 3);
                                
        Sl_rdDAck               : out std_logic;
                                
        Sl_rdComp               : out std_logic;
                                
        Sl_rdBTerm              : out std_logic;
                                
        Sl_MBusy                : out std_logic_vector(0 to 
                                                       C_PLB_NUM_MASTERS-1);
                                
        Sl_MErr                 : out std_logic_vector(0 to 
                                                       C_PLB_NUM_MASTERS-1);
        
        
    -- Bus Master Signals -----------------------------------------------------
        
        PLB_MAddrAck            : in  std_logic;
                                
        PLB_MSSize              : in  std_logic_vector(0 to 1);
                                
        PLB_MRearbitrate        : in  std_logic;
                                
        PLB_MBusy               : in  std_logic;
                                
        PLB_MErr                : in  std_logic;
                                
        PLB_MWrDAck             : in  std_logic;
                                
        PLB_MRdDBus             : in  std_logic_vector(0 to 
                                                      (C_PLB_DWIDTH-1));
                                
        PLB_MRdWdAddr           : in  std_logic_vector(0 to 3);
                                
        PLB_MRdDAck             : in  std_logic;
                                
        PLB_MRdBTerm            : in  std_logic;
                                
        PLB_MWrBTerm            : in  std_logic;
                                
        M_request               : out std_logic;
                                
        M_priority              : out std_logic_vector(0 to 1);
                                
        M_buslock               : out std_logic;
                                
        M_RNW                   : out std_logic;
                                
        M_BE                    : out std_logic_vector(0 to 
                                                      (C_PLB_DWIDTH/8)-1);
                                
        M_MSize                 : out std_logic_vector(0 to 1);
                                
        M_size                  : out std_logic_vector(0 to 3);
                                
        M_type                  : out std_logic_vector(0 to 2);
                                
        M_compress              : out std_logic;
                                
        M_guarded               : out std_logic;
                                
        M_ordered               : out std_logic;
                                
        M_lockErr               : out std_logic;
                                
        M_abort                 : out std_logic;
                                                              
        M_ABus                  : out std_logic_vector(0 to C_PLB_AWIDTH-1);
                                
        M_wrDBus                : out std_logic_vector(0 to C_PLB_DWIDTH-1);
                                
        M_wrBurst               : out std_logic;
                                
        M_rdBurst               : out std_logic;
        
        
        
    -- IP Interconnect (IPIC) port signals -----------------------------------------
        
        
        --System Signals
        IP2Bus_Clk              : in std_logic;
        
        Bus2IP_Clk              : out std_logic;
        
        Bus2IP_Reset            : out std_logic;
        
        Bus2IP_Freeze           : out std_logic;
        
        
        -- IP Slave signals
        IP2Bus_IntrEvent        : in std_logic_vector(0 to C_IP_INTR_MODE_ARRAY'length - 1 );
        
        IP2Bus_Data             : in std_logic_vector(0 to C_IPIF_DWIDTH - 1 );
                                
        IP2Bus_WrAck            : in std_logic;
                                
        IP2Bus_RdAck            : in std_logic;
        
        IP2Bus_Retry            : in std_logic;
        
        IP2Bus_Error            : in std_logic;
        
        IP2Bus_ToutSup          : in std_logic;
        
        IP2Bus_PostedWrInh      : In std_logic;
        
        Bus2IP_Addr             : out std_logic_vector(0 to C_IPIF_AWIDTH - 1 );
                                
        Bus2IP_Data             : out std_logic_vector(0 to C_IPIF_DWIDTH - 1 );
                                
        Bus2IP_RNW              : out std_logic;                                   -- new signal
        
        Bus2IP_BE               : out std_logic_vector(0 to (C_IPIF_DWIDTH/8) - 1 );
        
        Bus2IP_Burst            : out std_logic;
        
        Bus2IP_WrReq            : out std_logic;
        
        Bus2IP_RdReq            : out std_logic;
        
        Bus2IP_CS               : Out std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
        
        Bus2IP_CE               : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);  
        
        Bus2IP_RdCE             : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);  
        
        Bus2IP_WrCE             : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);   
      
        
        -- IP to DMA Support Signals (Length and Status FIFO I/O)
        IP2DMA_RxLength_Empty   : in std_logic;
        
        IP2DMA_RxStatus_Empty   : in std_logic;
        
        IP2DMA_TxLength_Full    : in std_logic;
        
        IP2DMA_TxStatus_Empty   : in std_logic;
        
        
        
        
        -- IP Master Signals
        IP2Bus_Addr             : in std_logic_vector(0 to C_IPIF_AWIDTH - 1 );
        
        IP2Bus_MstBE            : in std_logic_vector(0 to (C_IPIF_DWIDTH/8) - 1 );
        
        IP2IP_Addr              : in std_logic_vector(0 to C_IPIF_AWIDTH - 1 );
        
        IP2Bus_MstWrReq         : in std_logic;
        
        IP2Bus_MstRdReq         : in std_logic;
        
        IP2Bus_MstBurst         : in std_logic;
        
        IP2Bus_MstBusLock       : in std_logic;
        
        Bus2IP_MstWrAck         : out std_logic;
        
        Bus2IP_MstRdAck         : out std_logic;
        
        Bus2IP_MstRetry         : out std_logic;
        
        Bus2IP_MstError         : out std_logic;
        
        Bus2IP_MstTimeOut       : out std_logic;
        
        Bus2IP_MstLastAck       : out std_logic;
        
        
        -- RdPFIFO Signals
        IP2RFIFO_WrReq          : in std_logic;
        
        IP2RFIFO_Data           : in std_logic_vector(0 to find_id_dwidth(C_ARD_ID_ARRAY,
                                                                          C_ARD_DWIDTH_ARRAY,
                                                                          IPIF_RDFIFO_DATA,
                                                                          32)-1);
        
        IP2RFIFO_WrMark         : in std_logic;
        
        IP2RFIFO_WrRelease      : in std_logic;
        
        IP2RFIFO_WrRestore      : in std_logic;
        
        RFIFO2IP_WrAck          : out std_logic;
        
        RFIFO2IP_AlmostFull     : out std_logic;
        
        RFIFO2IP_Full           : out std_logic;
        
        RFIFO2IP_Vacancy        : out std_logic_vector(0 to log2(C_RDFIFO_DEPTH));
        
        
        
        -- WrPFIFO signals
        IP2WFIFO_RdReq          : in std_logic;
        
        IP2WFIFO_RdMark         : in std_logic;
        
        IP2WFIFO_RdRelease      : in std_logic;
        
        IP2WFIFO_RdRestore      : in std_logic;
        
        WFIFO2IP_Data           : out std_logic_vector(0 to find_id_dwidth(C_ARD_ID_ARRAY,
                                                                           C_ARD_DWIDTH_ARRAY,
                                                                           IPIF_WRFIFO_DATA,
                                                                           32)-1 );
        
        WFIFO2IP_RdAck          : out std_logic;
        
        WFIFO2IP_AlmostEmpty    : out std_logic;
        
        WFIFO2IP_Empty          : out std_logic;
        
        WFIFO2IP_Occupancy      : out std_logic_vector(0 to log2(C_WRFIFO_DEPTH) );
        
        
        -- IP DMA signals
        IP2Bus_DMA_Req          : in std_logic;
        
        Bus2IP_DMA_Ack          : out std_logic
        
        );
end component;

component bram_if
  generic (
    C_IPIF_AWIDTH : Integer := 32;
        -- The width if the IPIF address bus

    C_IPIF_DWIDTH : Integer := 32
        -- The width of the IPIF data bus

    );
  port (
    -- input ports
    bus_reset       : in std_logic;
    bus_clk         : in std_logic;
    Bus2IP_BE       : in std_logic_vector(0 to (C_IPIF_DWIDTH/8)-1);
    Bus2IP_Addr     : in std_logic_vector(0 to C_IPIF_AWIDTH-1);
    Bus2IP_Data     : in std_logic_vector(0 to C_IPIF_DWIDTH-1);
    Bus2IP_BRAM_CS  : in std_logic;
    Bus2IP_RNW      : in std_logic;
    Bus2IP_WrReq    : in std_logic;
    Bus2IP_RdReq    : in std_logic;

    -- Output ports
    IP2Bus_Data     : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
    IP2Bus_RdAck    : out std_logic;
    IP2Bus_WrAck    : out std_logic;
    IP2Bus_Retry    : out std_logic;
    IP2Bus_Error    : out std_logic;
    IP2Bus_ToutSup  : out std_logic;

    --BRAM Ports
    BRAM_Rst        : out  std_logic;
    BRAM_CLK        : out  std_logic;
    BRAM_EN         : out  std_logic;
    BRAM_WEN        : out std_logic_vector(0 to C_IPIF_DWIDTH/8 -1);
    BRAM_Addr       : out  std_logic_vector(0 to C_IPIF_AWIDTH-1);
    BRAM_Dout       : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
    BRAM_Din        : in  std_logic_vector(0 to C_IPIF_DWIDTH-1)

    );
  end component;

begin -- architecture IMP
myBus2ip_cs <= Bus2ip_cs(0) or Bus2ip_cs(1); -- SDRAM addr or SDRAM 2.Map addr 
myBus2ip_addr <=  Bus2ip_addr and not x"0800_0000";

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
I_PLB_IPIF: plb_ipif
  generic map(
      -- Generics to be set for ipif
      C_ARD_ID_ARRAY                =>   ARD_ID_ARRAY       ,
      C_ARD_ADDR_RANGE_ARRAY        =>   ARD_ADDR_RANGE_ARRAY ,
      C_ARD_DWIDTH_ARRAY            =>   ARD_DWIDTH_ARRAY     ,
      C_ARD_NUM_CE_ARRAY            =>   ARD_NUM_CE_ARRAY     ,
      C_ARD_DTIME_READ_ARRAY        =>   ARD_DTIME_READ_ARRAY ,
      C_ARD_DTIME_WRITE_ARRAY       =>   ARD_DTIME_WRITE_ARRAY,
      C_DEV_BLK_ID                  =>   DEV_BLK_ID           ,
      C_DEV_MIR_ENABLE              =>   DEV_MIR_ENABLE       ,
      C_DEV_BURST_ENABLE            =>   true,
      C_DEV_FAST_DATA_XFER          =>   C_INCLUDE_BURST_CACHELN_SUPPORT /= 0   ,
      C_DEV_MAX_BURST_SIZE          =>   DEV_MAX_BURST_SIZE   ,
      C_DEV_BURST_PAGE_SIZE         =>   DEV_BURST_PAGE_SIZE  ,
      C_DEV_DPHASE_TIMEOUT          =>   DEV_DPHASE_TIMEOUT   ,
      C_INCLUDE_DEV_ISC             =>   INCLUDE_DEV_ISC      ,
      C_INCLUDE_DEV_PENCODER        =>   INCLUDE_DEV_PENCODER ,
      C_IP_INTR_MODE_ARRAY          =>   IP_INTR_MODE_ARRAY   ,
      C_IP_MASTER_PRESENT           =>   IP_MASTER_PRESENT    ,
      C_WRFIFO_DEPTH                =>   WRFIFO_DEPTH         ,
      C_WRFIFO_INCLUDE_PACKET_MODE  =>   WRFIFO_INCLUDE_PACKET_MODE,
      C_WRFIFO_INCLUDE_VACANCY      =>   WRFIFO_INCLUDE_VACANCY,
      C_RDFIFO_DEPTH                =>   RDFIFO_DEPTH         ,
      C_RDFIFO_INCLUDE_PACKET_MODE  =>   RDFIFO_INCLUDE_PACKET_MODE,
      C_RDFIFO_INCLUDE_VACANCY      =>   RDFIFO_INCLUDE_VACANCY,
      C_PLB_MID_WIDTH               =>   C_PLB_MID_WIDTH,
      C_PLB_NUM_MASTERS             =>   PLB_NUM_MASTERS      ,
      C_PLB_AWIDTH                  =>   PLB_AWIDTH           ,
      C_PLB_DWIDTH                  =>   PLB_DWIDTH           ,
      C_PLB_CLK_PERIOD_PS           =>   PLB_CLK_PERIOD_PS    ,
      C_IPIF_DWIDTH                 =>   PLB_DWIDTH           ,
      C_IPIF_AWIDTH                 =>   PLB_AWIDTH           
      )
    port map (

    -- System signals ---------------------------------------------------------

        PLB_Clk           =>  PLB_clk,
        Reset             =>  PLB_Rst,
        Freeze            =>  Freeze,
        IP2INTC_Irpt      =>  open,


    -- Bus Slave signals ------------------------------------------------------

        PLB_ABus          =>  PLB_ABus      ,
        PLB_PAValid       =>  PLB_PAValid   ,
        PLB_SAValid       =>  PLB_SAValid   ,
        PLB_rdPrim        =>  PLB_rdPrim    ,
        PLB_wrPrim        =>  PLB_wrPrim    ,
        PLB_masterID      =>  PLB_masterID  ,
        PLB_abort         =>  PLB_abort     ,
        PLB_busLock       =>  PLB_busLock   ,
        PLB_RNW           =>  PLB_RNW       ,
        PLB_BE            =>  PLB_BE        ,
        PLB_MSize         =>  PLB_MSize     ,
        PLB_size          =>  PLB_size      ,
        PLB_type          =>  PLB_type      ,
        PLB_compress      =>  PLB_compress  ,
        PLB_guarded       =>  PLB_guarded   ,
        PLB_ordered       =>  PLB_ordered   ,
        PLB_lockErr       =>  PLB_lockErr   ,
        PLB_wrDBus        =>  PLB_wrDBus    ,
        PLB_wrBurst       =>  PLB_wrBurst   ,
        PLB_rdBurst       =>  PLB_rdBurst   ,
        PLB_pendReq       =>  PLB_pendReq   ,
        PLB_pendPri       =>  PLB_pendPri   ,
        PLB_reqPri        =>  PLB_reqPri    ,
        Sl_addrAck        =>  Sl_addrAck    ,
        Sl_SSize          =>  Sl_SSize      ,
        Sl_wait           =>  Sl_wait       ,
        Sl_rearbitrate    =>  Sl_rearbitrate,
        Sl_wrDAck         =>  Sl_wrDAck     ,
        Sl_wrComp         =>  Sl_wrComp     ,
        Sl_wrBTerm        =>  Sl_wrBTerm    ,
        Sl_rdDBus         =>  Sl_rdDBus     ,
        Sl_rdWdAddr       =>  Sl_rdWdAddr   ,
        Sl_rdDAck         =>  Sl_rdDAck     ,
        Sl_rdComp         =>  Sl_rdComp     ,
        Sl_rdBTerm        =>  Sl_rdBTerm    ,
        Sl_MBusy          =>  Sl_MBusy      ,
        Sl_MErr           =>  Sl_MErr       ,


    -- Bus Master Signals -----------------------------------------------------

        PLB_MAddrAck      =>  PLB_MAddrAck    ,
        PLB_MSSize        =>  PLB_MSSize    ,
        PLB_MRearbitrate  =>  PLB_MRearbitrate,
        PLB_MBusy         =>  PLB_MBusy       ,
        PLB_MErr          =>  PLB_MErr        ,
        PLB_MWrDAck       =>  PLB_MWrDAck     ,
        PLB_MRdDBus       =>  PLB_MRdDBus     ,
        PLB_MRdWdAddr     =>  PLB_MRdWdAddr   ,
        PLB_MRdDAck       =>  PLB_MRdDAck     ,
        PLB_MRdBTerm      =>  PLB_MRdBTerm    ,
        PLB_MWrBTerm      =>  PLB_MWrBTerm    ,
        M_request         =>  M_request       ,
        M_priority        =>  M_priority      ,
        M_buslock         =>  M_buslock       ,
        M_RNW             =>  M_RNW           ,
        M_BE              =>  M_BE            ,
        M_MSize           =>  M_MSize         ,
        M_size            =>  M_size          ,
        M_type            =>  M_type          ,
        M_compress        =>  M_compress      ,
        M_guarded         =>  M_guarded       ,
        M_ordered         =>  M_ordered       ,
        M_lockErr         =>  M_lockErr       ,
        M_abort           =>  M_abort         ,
        M_ABus            =>  M_ABus          ,
        M_wrDBus          =>  M_wrDBus        ,
        M_wrBurst         =>  M_wrBurst       ,
        M_rdBurst         =>  M_rdBurst       ,

    -- IP Interconnect (IPIC) port signals -----------------------------------------


        --System Signals
        IP2Bus_Clk       =>  IP2Bus_Clk       ,
        Bus2IP_Clk       =>  Bus2IP_Clk       ,
        Bus2IP_Reset     =>  Bus2IP_Reset     ,
        Bus2IP_Freeze    =>  Bus2IP_Freeze    ,

        -- IP Slave signals
        IP2Bus_IntrEvent   =>  IP2Bus_IntrEvent,
        IP2Bus_Data        =>  IP2Bus_Data,
        IP2Bus_WrAck       =>  IP2Bus_WrAck   ,
        IP2Bus_RdAck       =>  IP2Bus_RdAck   ,
        IP2Bus_Retry       =>  IP2Bus_Retry   ,
        IP2Bus_Error       =>  IP2Bus_errAck   ,
        IP2Bus_ToutSup     =>  IP2Bus_ToutSup ,
        IP2Bus_PostedWrInh =>  '0',
        Bus2IP_Addr        =>  Bus2ip_addr    ,
        Bus2IP_Data        =>  Bus2IP_Data,
        Bus2IP_RNW         =>  Bus2IP_RNW     ,
        Bus2IP_BE          =>  Bus2IP_BE      ,
        Bus2IP_Burst       =>  Bus2IP_Burst   ,
        Bus2IP_WrReq       =>  Bus2IP_WrReq   ,
        Bus2IP_RdReq       =>  Bus2IP_RdReq   ,
        Bus2IP_CS          =>  Bus2ip_cs   ,
        Bus2IP_CE          =>  Bus2IP_CE   ,
        Bus2IP_RdCE        =>  Bus2IP_RdCE,
        Bus2IP_WrCE        =>  Bus2IP_WrCE,

        -- IP to DMA Support Signals (Length and Status FIFO I/O)
        IP2DMA_RxLength_Empty   =>  IP2DMA_RxLength_Empty,
        IP2DMA_RxStatus_Empty   =>  IP2DMA_RxStatus_Empty,
        IP2DMA_TxLength_Full    =>  IP2DMA_TxLength_Full ,
        IP2DMA_TxStatus_Empty   =>  IP2DMA_TxStatus_Empty,

        -- IP Master Signals
        IP2Bus_Addr             =>  IP2Bus_Addr       ,
        IP2Bus_MstBE            =>  IP2Bus_MstBE      ,
        IP2IP_Addr              =>  IP2IP_Addr        ,
        IP2Bus_MstWrReq         =>  IP2Bus_MstWrReq   ,
        IP2Bus_MstRdReq         =>  IP2Bus_MstRdReq   ,
        IP2Bus_MstBurst         =>  IP2Bus_MstBurst   ,
        IP2Bus_MstBusLock       =>  IP2Bus_MstBusLock ,
        Bus2IP_MstWrAck         =>  Bus2IP_MstWrAck   ,
        Bus2IP_MstRdAck         =>  Bus2IP_MstRdAck   ,
        Bus2IP_MstRetry         =>  Bus2IP_MstRetry   ,
        Bus2IP_MstError         =>  Bus2IP_MstError   ,
        Bus2IP_MstTimeOut       =>  Bus2IP_MstTimeOut ,
        Bus2IP_MstLastAck       =>  Bus2IP_MstLastAck ,

        -- RdPFIFO Signals
        IP2RFIFO_WrReq         =>  IP2RFIFO_WrReq,
        IP2RFIFO_Data          =>  IP2RFIFO_Data,
        IP2RFIFO_WrMark        =>  IP2RFIFO_WrMark    ,
        IP2RFIFO_WrRelease     =>  IP2RFIFO_WrRelease ,
        IP2RFIFO_WrRestore     =>  IP2RFIFO_WrRestore ,
        RFIFO2IP_WrAck         =>  RFIFO2IP_WrAck ,
        RFIFO2IP_AlmostFull    =>  RFIFO2IP_AlmostFull,
        RFIFO2IP_Full          =>  RFIFO2IP_Full,
        RFIFO2IP_Vacancy       =>  RFIFO2IP_Vacancy,

        -- WrPFIFO signals
        IP2WFIFO_RdReq         =>  IP2WFIFO_RdReq       ,
        IP2WFIFO_RdMark        =>  IP2WFIFO_RdMark      ,
        IP2WFIFO_RdRelease     =>  IP2WFIFO_RdRelease   ,
        IP2WFIFO_RdRestore     =>  IP2WFIFO_RdRestore   ,
        WFIFO2IP_Data          =>  WFIFO2IP_Data        ,
        WFIFO2IP_RdAck         =>  WFIFO2IP_RdAck       ,
        WFIFO2IP_AlmostEmpty   =>  WFIFO2IP_AlmostEmpty ,
        WFIFO2IP_Empty         =>  WFIFO2IP_Empty       ,
        WFIFO2IP_Occupancy     =>  WFIFO2IP_Occupancy   ,

        -- IP DMA signals
        IP2Bus_DMA_Req         =>  IP2Bus_DMA_Req  ,
        Bus2IP_DMA_Ack         =>  Bus2IP_DMA_Ack
      );

-------------------------------------------------------------------------------
-- Generate BRAM controller with 2nd port brought out all the way to the top
-------------------------------------------------------------------------------
I_BRAM_CONTROLLER: bram_if
  generic map(
       C_IPIF_DWIDTH       =>   C_PLB_DWIDTH,
       C_IPIF_AWIDTH       =>   C_PLB_AWIDTH
       )

    port map (

       bus_reset          =>  PLB_Rst,
       bus_clk            =>  PLB_Clk,
       Bus2IP_Addr        =>  myBus2ip_addr,
       Bus2IP_BE          =>  Bus2IP_BE,
       Bus2IP_Data        =>  Bus2IP_Data,
       Bus2IP_RNW         =>  Bus2IP_RNW,
       Bus2IP_WrReq       =>  Bus2IP_WrReq,
       Bus2IP_RdReq       =>  Bus2IP_RdReq,
       Bus2IP_BRAM_CS     =>  myBus2ip_cs,

       IP2Bus_Data        => IP2Bus_Data(0 to C_PLB_DWIDTH-1),
       IP2Bus_Error       => IP2Bus_errAck,
       IP2Bus_retry       => IP2Bus_retry,
       IP2Bus_toutSup     => IP2Bus_toutSup,
       IP2Bus_RdAck       => IP2Bus_RdAck,
       IP2Bus_WrAck       => IP2Bus_WrAck,

       BRAM_Rst        =>   BRAM_Rst,
       BRAM_Clk        =>   BRAM_Clk,
       BRAM_EN         =>   BRAM_EN,
       BRAM_WEN        =>   BRAM_WEN,
       BRAM_Addr       =>   BRAM_Addr,
       BRAM_Din        =>   BRAM_Din,
       BRAM_Dout       =>   BRAM_Dout

       );
end implementation;
