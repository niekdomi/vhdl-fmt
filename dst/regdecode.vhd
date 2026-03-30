-------------------------------------------------------------------------------
-- $Id: regdecode.vhd,v 1.4 2001/10/15 22:48:58 ostlerf Exp $
-------------------------------------------------------------------------------
-- Register Decode entity and architecture
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        regdecode.vhd
--
-- Description:     This vhdl file is the module that is instantiated in the
--                  decode module as required to complete the slave attachment
--                  operation for the Register interface. Multiple modules can be 
--                  instantiated for multiple Register interfaces.
--
-------------------------------------------------------------------------------
-- Structure: 
--
--              regdecode.vhd
--
-------------------------------------------------------------------------------
-- Author:      Mike Lovejoy
-- History:
--  Mike Lovejoy      03/28/01      -- First version
--
--  ALS                 09/12/01
-- ^^^^^^
--  Modified address decode logic to use the PSELECT module to find matches
--  of the base address. Then used if/then/else structure to implement
--  individual CEs.
-- ~~~~~~
--
--  ALS                 09/13/01
-- ^^^^^^
--  Added condition for C_REG_NUM = 1
-- ~~~~~~
--
--  ALS                 09/25/01
-- ^^^^^^
--      Made the following code cleanups:
--          C_REG_BAR is now C_REG_BASE to indicate base address and is now
--          sized to be the size of the IPIF address bus.
--          C_SL_ATT_ADDR_WIDTH is now C_IPIF_ABUS_WIDTH.
--          C_OPB_ABUS_WIDTH is no longer needed.
--          C_OPB_DBUS_WIDTH is now C_IPIF_DBUS_WIDTH.
--          C_REG_NUM is now C_IP_REG_NUM.
-- ~~~~~~
-- 
--  ALS                 09/27/01
-- ^^^^^^
--      Made correction to handle full address bus
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
--use ieee.std_logic_unsigned."+";  --Used to add integer to std_logic_vector
use ieee.std_logic_unsigned.all;
-------------------------------------------------------------------------------

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.ipif_pkg.all;

-- PROC_COMMON library contains the pselect component
library proc_common_v1_00_a;
use proc_common_v1_00_a.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
entity regdecode is

    generic (
            C_IPIF_ABUS_WIDTH     : integer;      --Bus width from slave attachment
            C_IPIF_DBUS_WIDTH     : integer;      -- 8, 16, 32, 64 or 128 bits

            C_REG_BASE            : std_logic_vector;  --Word boundary aligned
            C_IP_REG_NUM          : integer;           --Number of Registers
            C_REG_DATA_WIDTH      : integer            --Number of Bytes in bus
            );

    port    (
        Reset           : in std_logic;

        Bus2IP_RangeSel : in std_logic;
        Bus2IP_Addr_sa  : in std_logic_vector (0 to C_IPIF_ABUS_WIDTH-1);
        Bus2IP_BE_sa    : in std_logic_vector (0 to C_IPIF_DBUS_WIDTH/8-1);

        Bus2IP_RNW_sa   : in std_logic;
        Bus2IP_Clk      : in std_logic;

        IP2Bus_WrAck_sa : in std_logic;
        IP2Bus_RdAck_sa : in std_logic;

        Bus2IP_Reg_WrCE : out std_logic_vector (0 to C_IP_REG_NUM-1);
        Bus2IP_Reg_RdCE : out std_logic_vector (0 to C_IP_REG_NUM-1)
        );


end regdecode;


architecture implementation of regdecode is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- the number of address bits required to address registers is log2 of the 
-- number of registers + 2 to account for 32-bit addressing of the registers
constant REGADDR_BITS : integer   := log2(C_IP_REG_NUM)+ 2;    

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

signal Bus2IP_Reg_RdCE_int      : std_logic_vector (0 to C_IP_REG_NUM-1);
signal Bus2IP_Reg_WrCE_int      : std_logic_vector (0 to C_IP_REG_NUM-1);
signal ce_int                   : std_logic_vector (0 to C_IP_REG_NUM-1);
--signal Asyn_Reg_RdCE_int      : std_logic_vector (0 to C_IP_REG_NUM-1);
--signal Asyn_Reg_WrCE_int      : std_logic_vector (0 to C_IP_REG_NUM-1);
signal ce_valid                 : std_logic;
--signal Sln_XferAck_simulated  : std_logic;

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------

begin
-------------------------------------------------------------------------------
-- check number of bits to verify in base address. If zero, ce_valid simply
-- equals Bus2IP_RangeSel. If one, ce_valid equals Bus2IP_RangeSel and the
-- xnor of the address bit with the base address bit. Otherwise,
-- instantiate the pselect module to decode the register base address.
-------------------------------------------------------------------------------
REG_ZEROADDRBIT_GEN: if C_IPIF_ABUS_WIDTH-REGADDR_BITS = 0 generate
    ce_valid <= Bus2IP_RangeSel;
end generate REG_ZEROADDRBIT_GEN;

REG_ONEADDRBIT_GEN: if C_IPIF_ABUS_WIDTH-REGADDR_BITS = 1 generate
    ce_valid <= Bus2IP_RangeSel and 
                (Bus2IP_Addr_sa(0) xnor C_REG_BASE(0));
end generate REG_ONEADDRBIT_GEN;

REG_MULTIADDRBIT_GEN: if C_IPIF_ABUS_WIDTH-REGADDR_BITS > 1 generate
    REGISTER_PSELECT_I: pselect
        generic map (C_AB   => C_IPIF_ABUS_WIDTH-REGADDR_BITS,
                     C_AW   => C_IPIF_ABUS_WIDTH,
                     C_BAR  => C_REG_BASE)
        port map (A         => Bus2IP_Addr_sa,
                  AValid    => Bus2IP_RangeSel,
                  CS        => ce_valid);
 end generate REG_MULTIADDRBIT_GEN;

-------------------------------------------------------------------------------
-- Decode the lower address bits required for the registers to an internal
-- ce bus. Ignore 2 LSBs since all registers are word addressed
-------------------------------------------------------------------------------
ONEREG_GEN: if (C_IP_REG_NUM = 1) generate
    ce_int(0) <= '1';
end generate ONEREG_GEN;

MULTREG_GEN: if (C_IP_REG_NUM > 1) generate
    DECODE_REGBITS: process(Bus2IP_Addr_sa)
    begin
        ce_int <= (others => '0');
        for j in 0 to C_IP_REG_NUM - 1 loop
            if Bus2IP_Addr_sa(C_IPIF_ABUS_WIDTH-REGADDR_BITS to C_IPIF_ABUS_WIDTH-3) = j then
                ce_int(j) <= '1';
            end if;
        end loop;
    end process DECODE_REGBITS;
end generate MULTREG_GEN;

-------------------------------------------------------------------------------
-- Read and Write CE Register process
-- The read/write CEs are reset when the respective ACK is returned
-------------------------------------------------------------------------------
REGCE_PROCESS: process(Bus2IP_Clk)
begin
    if Bus2IP_Clk'event and Bus2IP_Clk='1' then
        -- Read CEs
        if IP2Bus_RdAck_sa = '1' or Reset = RESET_ACTIVE or Bus2IP_RNW_sa = '0' then
            Bus2IP_Reg_RdCE <= (others => '0');
        elsif ce_valid = '1' then
            Bus2IP_Reg_RdCE <= ce_int;
        end if;
        
        -- Write CEs
        if IP2Bus_WrAck_sa = '1' or Reset = RESET_ACTIVE or Bus2IP_RNW_sa = '1' then
            Bus2IP_Reg_WrCE <= (others => '0');
        elsif ce_valid = '1' then
            Bus2IP_Reg_WrCE <= ce_int;
        end if;
    end if;
end process;

end implementation;
