-------------------------------------------------------------------------------
-- $Id: addr_decode.vhd,v 1.4 2004/11/23 00:59:53 jcanaris Exp $
-------------------------------------------------------------------------------
-- Address Decode entity and architecture
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        addr_decode.vhd
--
-- Description:     This vhdl file is the module that decodes addresses as
--                  required to complete the slave attachment operation for
--                  transacitons with IP modules and internal IPIF modules.
--                  Word boundary aligned addresses are required as inputs
--                  to this module.
--
-------------------------------------------------------------------------------
-- Structure:
--              addr_decode.vhd
--                  -- regdecode.vhd
--                  -- sramdecode.vhd
-------------------------------------------------------------------------------
-- Author:      Mike Lovejoy
-- History:
--  Mike Lovejoy      03/28/01      -- First version
--
--  ALS                 09/25/01
-- ^^^^^^
--      Merged decode.vhd and addr_decode.vhd files. Incorporated new generics
--      and renamed generics as needed.
-- ~~~~~~
-- LCW		Oct 12, 2004	-- updated for NCSim
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
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.SRAMdecode;
use opb_ipif_v1_23_a.Regdecode;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--      -- Bus Interfaces
--          C_IPIF_ABUS_WIDTH       -- Width of IPIF Address bus
--          C_IPIF_DBUS_WIDTH       -- Width of IPIF Data bus
--
--      -- SRAM
--          C_SRAM_CE               -- True = include, False = not included
--          C_SRAM_BASE              -- SRAM base address
--          C_SRAM_ADDR_WIDTH       -- SRAM address width
--          C_SRAM_DATA_WIDTH       -- SRAM data width
--
--      -- Registers
--          C_REG_CE                -- True = include, False = not included
--          C_REG_BASE               -- Base address for registers
--          C_IP_REG_NUM            -- Number of IP registers
--          C_REG_DATA_WIDTH        -- Register data width
--
--      -- Write FIFO
--          C_WRFIFO_CE             -- True = include, False = not included
--          C_WRFIFO_BASE            -- Write FIFO base address
--          C_WRFIFO_ADDR_WIDTH     -- Number of address bits for address range
--          C_WRFIFO_DATA_WIDTH     -- Write FIFO data width
--          C_WRFIFO_REG_BASE        -- Write FIFO registers base address
--          C_WRFIFO_REG_NUM        -- Number of Write FIFO registers
--          C_WRFIFO_REG_DATA_WIDTH -- Write FIFO registers data width
--
--      -- Read FIFO
--          C_RDFIFO_CE             -- True = include, False = not included
--          C_RDFIFO_BASE            -- Read FIFO base address
--          C_RDFIFO_ADDR_WIDTH     -- Number of address bits for address range
--          C_RDFIFO_DATA_WIDTH     -- Read FIFO data width
--          C_RDFIFO_REG_BASE        -- Read FIFO registers base address
--          C_RDFIFO_REG_NUM        -- Number of Read FIFO registers
--          C_RDFIFO_REG_DATA_WIDTH -- Read FIFO registers data width
--
--      -- DMA
--          C_DMA_CE                -- True = include, False = not included
--          C_DMA_BASE               -- DMA base address
--          C_DMA_SRAM_ADDR_WIDTH   -- number of DMA address bits required
--          C_DMA_SRAM_DATA_WIDTH   -- width of DMA data bus
--
--      -- Interrupt registers
--          C_INTERRUPT_CE          -- True = include, False = not included
--          C_INTERRUPT_REG_BASE     -- base address for interrupt registers
--          C_INTERRUPT_REG_NUM     -- number of interrupt registers
--          C_INTERRUPT_REG_DATA_WIDTH -- data width of interrupt registers
--
--      -- Reset register
--          C_IP_RESET_CE           -- True = include, False = not included
--          C_IP_RESET_REG_BASE      -- Reset register base address
--          C_IP_RESET_REG_NUM      -- Number of IP reset registers
--          C_IP_RESET_REG_DATA_WIDTH-- data width of IP reset registers
--
-- Definition of Ports:
--
--       in Reset                   -- reset
--
--       in Bus2IP_RangeSel         -- address is in this module's address space
--       in Bus2IP_Addr_sa          -- address bus
--       in Bus2IP_BE_sa            -- byte enables
--
--       in Bus2IP_RNW_sa           -- read not write
--       in Bus2IP_Clk              -- clock
--       in Bus2IP_Burst_sa         -- burst
--
--       in IP2Bus_WrAck_sa         -- write acknowledge from IP
--       in IP2Bus_RdAck_sa         -- read acknowledge from IP
--
--
--       out Asyn_SRAM_WrCE         -- asynchronous SRAM write enable
--       out Asyn_SRAM_RdCE         -- asynchronous SRAM read enable
--       out Bus2IP_SRAM_WrCE       -- synchronous SRAM write enable
--       out Bus2IP_SRAM_RdCE       -- synchronous SRAM read enable
--       out Bus2IP_SRAM_CE         -- synchronous SRAM enable
--
--       out Bus2IP_Reg_WrCE        -- register write enables
--       out Bus2IP_Reg_RdCE        -- register read enables
--
--       out Asyn_WrFIFO_WrCE       -- asynchronous write fifo write enable
--       out Asyn_WrFIFO_RdCE       -- asynchronous write fifo read enable
--       out WrFIFO_WrCE            -- synchronous write fifo write enable
--       out WrFIFO_RdCE            -- synchronous write fifo read enable
--       out WrFIFO_Reg_WrCE        -- write fifo registers write enable
--       out WrFIFO_Reg_RdCE        -- write fifo registers read enable
--
--       out Asyn_RdFIFO_WrCE       -- asynchronous read fifo write enable
--       out Asyn_RdFIFO_RdCE       -- asynchronous read fifo read enable
--       out RdFIFO_WrCE            -- synchronous read fifo write enable
--       out RdFIFO_RdCE            -- synchronous read fifo read enable
--       out RdFIFO_Reg_WrCE        -- read fifo registers write enable
--       out RdFIFO_Reg_RdCE        -- read fifo registers read enable
--
--       out DMA_WrCE               -- DMA write enable
--       out DMA_RdCE               -- DMA read enable
--
--       out Interrupt_WrCE         -- interrupt register write enable
--       out Interrupt_RdCE         -- interrupt register read enable
--
--       out IP_Reset_RdCE          -- reset register read enable
--       out IP_Reset_WrCE          -- reset register write enable
-------------------------------------------------------------------------------
entity addr_decode is

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

        --IP_Reset_WrCE       : out std_logic_vector (0 to C_IP_RESET_REG_NUM-1);
        --IP_Reset_RdCE       : out std_logic_vector (0 to C_IP_RESET_REG_NUM-1)
        IP_Reset_RdCE       : out std_logic;
        IP_Reset_WrCE       : out std_logic
        );
end addr_decode;

architecture implementation of addr_decode is
--This implementation has a maximum base address register (BASE) width of 32.
-------------------------------------------------------------------------------
-- Signal Declaration
-------------------------------------------------------------------------------
signal ip_reset_wrce_vect   : std_logic_vector (0 to C_IP_RESET_REG_NUM-1);
signal ip_reset_rdce_vect   : std_logic_vector (0 to C_IP_RESET_REG_NUM-1);
signal asyn_dma_sram_wrce   : std_logic;
signal asyn_dma_sram_rdce   : std_logic;
signal bus2ip_sram_wrce     : std_logic;
signal bus2ip_sram_rdce     : std_logic;

-------------------------------------------------------------------------------
-- Component Declaration
-------------------------------------------------------------------------------
-- SRAM decode module

--Register decode module

begin
-- Combinational assignments
Bus2IP_SRAM_CE <= bus2ip_sram_rdce or bus2ip_sram_wrce;

IP_Reset_WrCE <= ip_reset_wrce_vect(0);
IP_Reset_RdCE <= ip_reset_rdce_vect(0);

-------------------------------------------------------------------------------
-- SRAM Decode Logic
-------------------------------------------------------------------------------
SRAM_decode_NOT_generate: if(not(C_SRAM_CE)) generate --Set outputs to zero
  begin
     Asyn_SRAM_WrCE <= '0';
     Asyn_SRAM_RdCE <= '0';
     bus2ip_sram_wrce <= '0';
     bus2ip_sram_rdce <= '0';
end generate SRAM_decode_NOT_generate;

SRAM_decode_generate: if(C_SRAM_CE) generate    --Include SRAM decode when true
   I_UUT: entity opb_ipif_v1_23_a.SRAMdecode
    generic map(

            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,
            C_SRAM_BASE => C_SRAM_BASE,      --includes lsb for byte addressing
            C_SRAM_ADDR_WIDTH => C_SRAM_ADDR_WIDTH,
            C_SRAM_DATA_WIDTH => C_SRAM_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,
        Bus2IP_Burst_sa => Bus2IP_Burst_sa,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Asyn_SRAM_WrCE => Asyn_SRAM_WrCE,
        Asyn_SRAM_RdCE => Asyn_SRAM_RdCE,
        Bus2IP_SRAM_WrCE => bus2ip_sram_wrce,
        Bus2IP_SRAM_RdCE => bus2ip_sram_rdce
        );
end generate SRAM_decode_generate;

-------------------------------------------------------------------------------
-- Register Decode Logic
-------------------------------------------------------------------------------
Reg_decode_NOT_generate: if(not(C_REG_CE)) generate
  begin
        Bus2IP_Reg_WrCE <= (others => '0');
        Bus2IP_Reg_RdCE <= (others => '0');
end generate Reg_decode_NOT_generate;

Reg_decode_generate: if(C_REG_CE) generate   --Include Register decode when true
   I_UUT: entity opb_ipif_v1_23_a.Regdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_REG_BASE => C_REG_BASE,
            C_IP_REG_NUM => C_IP_REG_NUM,
            C_REG_DATA_WIDTH => C_REG_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Bus2IP_Reg_WrCE => Bus2IP_Reg_WrCE,
        Bus2IP_Reg_RdCE => Bus2IP_Reg_RdCE
        );
end generate Reg_decode_generate;

-------------------------------------------------------------------------------
-- Write FIFO Decode Logic
-------------------------------------------------------------------------------
WrFIFO_decode_NOT_generate: if(not(C_WRFIFO_CE)) generate  --Set outputs to zero
  begin
     Asyn_WrFIFO_WrCE <= '0';
     Asyn_WrFIFO_RdCE <= '0';
     WrFIFO_WrCE <= '0';
     WrFIFO_RdCE <= '0';
     WrFIFO_Reg_WrCE <= (others => '0');
     WrFIFO_Reg_RdCE <= (others => '0');
end generate WrFIFO_decode_NOT_generate;

WrFIFO_decode_generate: if(C_WRFIFO_CE) generate  --Include Write FIFO deocode when true
                                            --Includes both SRAM and Register decodes
   I_UUT0: entity opb_ipif_v1_23_a.SRAMdecode
    generic map(

            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_SRAM_BASE => C_WRFIFO_BASE,
 --           C_SRAM_MAXAR => C_WRFIFO_MAXAR,
            C_SRAM_ADDR_WIDTH => C_WRFIFO_ADDR_WIDTH,
            C_SRAM_DATA_WIDTH => C_WRFIFO_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,
        Bus2IP_Burst_sa => Bus2IP_Burst_sa,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Asyn_SRAM_WrCE => Asyn_WrFIFO_WrCE,
        Asyn_SRAM_RdCE => Asyn_WrFIFO_RdCE,
        Bus2IP_SRAM_WrCE => WrFIFO_WrCE,
        Bus2IP_SRAM_RdCE => WrFIFO_RdCE
        );

   I_UUT1: entity opb_ipif_v1_23_a.Regdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_REG_BASE => C_WRFIFO_REG_BASE,
            C_IP_REG_NUM => C_WRFIFO_REG_NUM,
            C_REG_DATA_WIDTH => C_WRFIFO_REG_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Bus2IP_Reg_WrCE => WrFIFO_Reg_WrCE,
        Bus2IP_Reg_RdCE => WrFIFO_Reg_RdCE
        );
end generate WRFIFO_decode_generate;

-------------------------------------------------------------------------------
-- Read FIFO Decode Logic
-------------------------------------------------------------------------------
RdFIFO_decode_NOT_generate: if(not(C_RDFIFO_CE)) generate
--Set outputs to zero
  begin
     Asyn_RdFIFO_WrCE <= '0';
     Asyn_RdFIFO_RdCE <= '0';
     RdFIFO_WrCE <= '0';
     RdFIFO_RdCE <= '0';
     RdFIFO_Reg_WrCE <= (others => '0');
     RdFIFO_Reg_RdCE <= (others => '0');
end generate RdFIFO_decode_NOT_generate;

RdFIFO_decode_generate: if(C_RDFIFO_CE) generate
--Include Read FIFO decode when true
--Includes both SRAM and Register decodes
   I_UUT0: entity opb_ipif_v1_23_a.SRAMdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_SRAM_BASE => C_RDFIFO_BASE,
--            C_SRAM_MAXAR => C_RDFIFO_MAXAR,
            C_SRAM_ADDR_WIDTH => C_RDFIFO_ADDR_WIDTH,
            C_SRAM_DATA_WIDTH => C_RDFIFO_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,
        Bus2IP_Burst_sa => Bus2IP_Burst_sa,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Asyn_SRAM_WrCE => Asyn_RdFIFO_WrCE,
        Asyn_SRAM_RdCE => Asyn_RdFIFO_RdCE,
        Bus2IP_SRAM_WrCE => RdFIFO_WrCE,
        Bus2IP_SRAM_RdCE => RdFIFO_RdCE
        );

   I_UUT1: entity opb_ipif_v1_23_a.Regdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_REG_BASE => C_RDFIFO_REG_BASE,
            C_IP_REG_NUM => C_RDFIFO_REG_NUM,
            C_REG_DATA_WIDTH => C_RDFIFO_REG_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Bus2IP_Reg_WrCE => RdFIFO_Reg_WrCE,
        Bus2IP_Reg_RdCE => RdFIFO_Reg_RdCE
        );
end generate RDFIFO_decode_generate;

-------------------------------------------------------------------------------
-- DMA Decode Logic
-------------------------------------------------------------------------------
DMA_decode_NOT_generate: if(not(C_DMA_CE)) generate --Set outputs to zero
  begin
     asyn_dma_sram_wrce <= '0';
     asyn_dma_sram_rdce <= '0';
     DMA_WrCE <= '0';
     DMA_RdCE <= '0';
end generate DMA_decode_NOT_generate;

DMA_decode_generate: if(C_DMA_CE) generate  --Include SRAM decode
   I_UUT0: entity opb_ipif_v1_23_a.SRAMdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_SRAM_BASE => C_DMA_BASE,
--            C_SRAM_MAXAR => C_DMA_MAXAR,
            C_SRAM_ADDR_WIDTH => C_DMA_SRAM_ADDR_WIDTH,
            C_SRAM_DATA_WIDTH => C_DMA_SRAM_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,
        Bus2IP_Burst_sa => Bus2IP_Burst_sa,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Asyn_SRAM_WrCE => asyn_dma_sram_wrce,
        Asyn_SRAM_RdCE => asyn_dma_sram_rdce,
        Bus2IP_SRAM_WrCE => DMA_WrCE,
        Bus2IP_SRAM_RdCE => DMA_RdCE
        );
end generate DMA_decode_generate;

-------------------------------------------------------------------------------
-- Interrupt Decode Logic
-------------------------------------------------------------------------------
Interrupt_decode_NOT_generate: if(not(C_INTERRUPT_CE)) generate --Set outputs to zero
  begin
        Interrupt_WrCE <= (others => '0');
        Interrupt_RdCE <= (others => '0');
end generate Interrupt_decode_NOT_generate;

Interrupt_decode_generate: if(C_INTERRUPT_CE) generate   --Include Interrupt Reg decode when true
   I_UUT: entity opb_ipif_v1_23_a.Regdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_REG_BASE => C_INTERRUPT_REG_BASE,
            C_IP_REG_NUM => C_INTERRUPT_REG_NUM,
            C_REG_DATA_WIDTH => C_INTERRUPT_REG_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Bus2IP_Reg_WrCE => Interrupt_WrCE,
        Bus2IP_Reg_RdCE => Interrupt_RdCE
        );
end generate Interrupt_decode_generate;

-------------------------------------------------------------------------------
-- IP Reset Decode Logic
-------------------------------------------------------------------------------
IP_Reset_decode_NOT_generate: if(not(C_IP_RESET_CE)) generate --Set outputs to zero
  begin
        ip_reset_wrce_vect <= (others => '0');
        ip_reset_rdce_vect <= (others => '0');
end generate IP_Reset_decode_NOT_generate;

IP_Reset_decode_generate: if(C_IP_RESET_CE) generate   --Include Interrupt Reg decode when true
   I_UUT: entity opb_ipif_v1_23_a.Regdecode
    generic map(
            C_IPIF_ABUS_WIDTH => C_IPIF_ABUS_WIDTH,
            C_IPIF_DBUS_WIDTH => C_IPIF_DBUS_WIDTH,

            C_REG_BASE => C_IP_RESET_REG_BASE,
            C_IP_REG_NUM => C_IP_RESET_REG_NUM,
            C_REG_DATA_WIDTH => C_IP_RESET_REG_DATA_WIDTH
            )

    port map (
        Reset => Reset,

        Bus2IP_RangeSel => Bus2IP_RangeSel,
        Bus2IP_Addr_sa => Bus2IP_Addr_sa,
        Bus2IP_BE_sa => Bus2IP_BE_sa,

        Bus2IP_RNW_sa => Bus2IP_RNW_sa,
        Bus2IP_Clk => Bus2IP_Clk,

        IP2Bus_WrAck_sa => IP2Bus_WrAck_sa,
        IP2Bus_RdAck_sa => IP2Bus_RdAck_sa,

        Bus2IP_Reg_WrCE => ip_reset_wrce_vect,
        Bus2IP_Reg_RdCE => ip_reset_rdce_vect
        );
end generate IP_Reset_decode_generate;

end implementation;
