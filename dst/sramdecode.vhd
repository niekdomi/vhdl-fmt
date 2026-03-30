-------------------------------------------------------------------------------
-- $Id: sramdecode.vhd,v 1.4 2001/10/15 22:48:58 ostlerf Exp $
-------------------------------------------------------------------------------
-- SRAM Decode entity and architecture
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        sramdecode.vhd
--
-- Description:     This vhdl file is the module that is instantiated in the
--                  decode module as required to complete the slave attachment
--                  operation for SRAM interface. Multiple modules can be 
--                  instantiated for multiple SRAM interfaces.
--
-------------------------------------------------------------------------------
-- Structure:   
--              sramdecode.vhd
--
-------------------------------------------------------------------------------
-- Author:      Mike Lovejoy
-- History:
--  Mike Lovejoy      03/28/01      -- First version
--
--  ALS                 09/21/01    
-- ^^^^^^
--      Simplified code by requiring size of external SRAM to be a power of 2.
--      Changed generic specifying the max address to generic specifying the 
--      number of SRAM address bits. Implemented decode using PSELECT module 
--      and implemented check of valid byte enables using VALID_BE module.
-- ~~~~~~~
--
--  ALS                 09/25/01
-- ^^^^^^
--      Made the following code cleanups:
--          C_SRAM_BAR is now C_SRAM_BASE to indicate base address and is now
--          sized to be the size of the IPIF address bus.
--          C_SL_ATT_ADDR_WIDTH is now C_IPIF_ABUS_WIDTH.
--          C_OPB_ABUS_WIDTH is no longer needed.
--          C_OPB_DBUS_WIDTH is now C_IPIF_DBUS_WIDTH.
-- ~~~~~~
--
--  ALS                 09/28/01
-- ^^^^^^
--      Added reference to proc_common library.
-- ~~~~~~
--
--  ALS                 10/11/01
-- ^^^^^^
--      Modified code so that PSELECT is used if more than one bit in 
--      base address is to be decoded. If only zero or one bit in the 
--      base address needs to be decoded, just describe the logic.
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
library ieee;
use ieee.std_logic_1164.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.ipif_pkg.all;

-- PROC_COMMON library contains the pselect and valid_be components
library proc_common_v1_00_a;
use proc_common_v1_00_a.all;
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
entity sramdecode is

    generic (
            C_IPIF_ABUS_WIDTH       : integer;      --IPIF address bus width
            C_IPIF_DBUS_WIDTH       : integer;      --IPIF data bus width

            C_SRAM_BASE              : std_logic_vector;  --Word boundary aligned
            C_SRAM_ADDR_WIDTH       : integer;          -- Number of address bits for SRAM
            C_SRAM_DATA_WIDTH       : integer            --Number of bits in bus
            );

    port    (
        Reset           : in std_logic;

        Bus2IP_RangeSel : in std_logic;
        Bus2IP_Addr_sa  : in std_logic_vector (0 to C_IPIF_ABUS_WIDTH-1);
        Bus2IP_BE_sa    : in std_logic_vector (0 to C_IPIF_DBUS_WIDTH/8-1);

        Bus2IP_RNW_sa   : in std_logic;
        Bus2IP_Clk      : in std_logic;
        Bus2IP_Burst_sa : in std_logic;

        IP2Bus_WrAck_sa : in std_logic;
        IP2Bus_RdAck_sa : in std_logic;

        Asyn_SRAM_WrCE  : out std_logic;
        Asyn_SRAM_RdCE  : out std_logic;
        Bus2IP_SRAM_WrCE  : out std_logic;
        Bus2IP_SRAM_RdCE  : out std_logic
        );


end sramdecode;

architecture implementation of sramdecode is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
--Calculates a reduced vector with BAR information
-- no longer needed since BAR is sliced correctly at top level
--constant SRAM_BAR : STD_LOGIC_VECTOR (0 to C_IPIF_ABUS_WIDTH+1)
--:= C_SRAM_BASE(C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH-2 to C_OPB_ABUS_WIDTH-1);

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
--signal Burst_mode            : std_logic;
signal Asyn_SRAM_RdCE_int    : std_logic;
signal Asyn_SRAM_WrCE_int    : std_logic;
--signal Bus2IP_SRAM_RdCE_int  : std_logic;
--signal Bus2IP_SRAM_WrCE_int  : std_logic;
signal ce_valid              : std_logic;
signal be_valid              : std_logic;
--signal Clear_CE              : std_logic;
--signal Asynch_Clear_CE       : std_logic;
--signal Sln_XferAck_simulated : std_logic;

--signal SRAM_MAXAR_BE : std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8-1);  --Internal signal
                   --to provide correct CE-signal assertion with byte enable decode
                   --when maximum address is decoded, but valid address space does
                   --not span full word
-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- PSELECT is used to compare the address to the BAR
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

-- VALID_BE is used to determine if the byte enables are valid for the OPB data
-- width and SRAM data width
component valid_be is
  generic (
    C_HOST_DW           : integer range 8 to 256 := 32;
    C_TARGET_DW         : integer range 8 to 32  := 32
    );   
  port (
    OPB_BE_Reg     : in  std_logic_vector(0 to C_HOST_DW/8-1);
    Valid          : out std_logic
    );
end component valid_be;

-------------------------------------------------------------------------------
begin

--Combinatorial assignments
--Bus2IP_SRAM_RdCE <= Bus2IP_SRAM_RdCE_int;
--Bus2IP_SRAM_WrCE <= Bus2IP_SRAM_WrCE_int;
--Asyn_SRAM_RdCE <= Asyn_SRAM_RdCE_int;
--Asyn_SRAM_WrCE <= Asyn_SRAM_WrCE_int;

Asyn_SRAM_RdCE <= ce_valid when be_valid = '1' and 
                  Bus2IP_RNW_sa = '1' and 
                  (Bus2IP_Burst_sa = '1' or IP2Bus_RdAck_sa = '0')
                  else '0';
Asyn_SRAM_WrCE <= ce_valid when be_valid = '1' and 
                  Bus2IP_RNW_sa = '0' and 
                  (Bus2IP_Burst_sa = '1' or IP2Bus_WrAck_sa = '0')
                  else '0';
                  
-------------------------------------------------------------------------------
-- check number of bits to verify in base address. If zero, ce_valid simply
-- equals Bus2IP_RangeSel. If one, ce_valid equals Bus2IP_RangeSel and the
-- xnor of the address bit with the base address bit. Otherwise,
-- instantiate the pselect module to decode the register base address.
-------------------------------------------------------------------------------
SRAM_ZEROADDRBIT_GEN: if C_IPIF_ABUS_WIDTH-C_SRAM_ADDR_WIDTH = 0 generate
    ce_valid <= Bus2IP_RangeSel;
end generate SRAM_ZEROADDRBIT_GEN;

SRAM_ONEADDRBIT_GEN: if C_IPIF_ABUS_WIDTH-C_SRAM_ADDR_WIDTH = 1 generate
    ce_valid <= Bus2IP_RangeSel and 
                (Bus2IP_Addr_sa(0) xnor C_SRAM_BASE(0));
end generate SRAM_ONEADDRBIT_GEN;

SRAM_MULTIADDRBIT_GEN: if C_IPIF_ABUS_WIDTH-C_SRAM_ADDR_WIDTH > 1 generate 
    SRAM_PSELECT_I: pselect
        generic map (C_AB   => C_IPIF_ABUS_WIDTH-C_SRAM_ADDR_WIDTH,
                     C_AW   => C_IPIF_ABUS_WIDTH,
                     C_BAR  => C_SRAM_BASE)
        port map (A         => Bus2IP_Addr_sa,
                  AValid    => Bus2IP_RangeSel,
                  CS        => ce_valid);
 end generate SRAM_MULTIADDRBIT_GEN;

-- Instantiate the valid_be module to determine if the BEs are valid for the
-- OPB data bus and the SRAM data bus
SRAM_BE_I: valid_be
  generic map(  C_HOST_DW       => C_IPIF_DBUS_WIDTH,
                C_TARGET_DW     => C_SRAM_DATA_WIDTH
              )   
  port map (    OPB_BE_Reg      => Bus2IP_BE_sa,
                Valid           => be_valid
            );

-------------------------------------------------------------------------------
-- Read and Write CE Register process
-- The read/write CEs are reset when the respective ACK is returned
-------------------------------------------------------------------------------
REGCE_PROCESS: process(Bus2IP_Clk)
begin
    if Bus2IP_Clk'event and Bus2IP_Clk='1' then
        -- Read CEs
        if (Bus2IP_Burst_sa = '0' and IP2Bus_RdAck_sa = '1') or Reset = RESET_ACTIVE or Bus2IP_RNW_sa = '0' then
            Bus2IP_SRAM_RdCE <= '0';
        elsif be_valid = '1' then
            Bus2IP_SRAM_RdCE <= ce_valid;
        end if;
        
        -- Write CEs
        if (Bus2IP_Burst_sa = '0' and IP2Bus_WrAck_sa = '1') or Reset = RESET_ACTIVE or Bus2IP_RNW_sa = '1' then
            Bus2IP_SRAM_WrCE <= '0';
        elsif be_valid = '1' then
            Bus2IP_SRAM_WrCE <= ce_valid;
        end if;
    end if;
end process;
end implementation;
