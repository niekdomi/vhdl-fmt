--------------------------------------------------------------------------
-- $Id: jtagppc_cntlr.vhd,v 1.4 2004/09/08 00:56:43 larsg Exp $ jtagppc_cntlr.vhd,v 1.3 2004/06/02 00:47:47 larsg Exp $
--------------------------------------------------------------------------
-- jtagppc_cntlr.vhd - entity/architecture
--------------------------------------------------------------------------
-- ** Copyright(C) 2004 by Xilinx, Inc. All rights reserved.
-- **
-- ** This text contains proprietary, confidential information of
-- ** Xilinx, Inc. , is distributed by under license from Xilinx, Inc.,
-- ** and may be used, copied and/or disclosed only pursuant to the
-- ** terms of a valid license agreement with Xilinx, Inc.
-- **
-- ** Unmodified source code is guaranteed to place and route,
-- ** function and run at speed according to the datasheet
-- ** specification. Source code is provided "as-is", with no
-- ** obligation on the part of Xilinx to provide support.
-- **
-- ** Xilinx Hotline support of source code IP shall only include
-- ** standard level Xilinx Hotline support, and will only address
-- ** issues and questions related to the standard released Netlist
-- ** version of the core (and thus indirectly, the original core source
-- **
-- ** The Xilinx Support Hotline does not have access to source
-- ** code and therefore cannot answer specific questions related
-- ** to source HDL. The Xilinx Support Hotline will only be able
-- ** to confirm the problem in the Netlist version of the core.
-- **
-- ** This copyright and support notice must be retained as part
-- ** of this text at all times.
-- -------------------------------------------------------------------------
-- Filename: jtagppc_cntlr.vhd
-- Version: v2.00a
-- Description:
--   Instantiating this module in conjunction with 
--   PowerPC BDM can result the powerpc BDM port to be 
--   shared with the jtag pins of FPGA configuration port
-- -----------------------------------------------------------------------
-- @BEGIN_CHANGELOG EDK_Gmm
-- Initial release of v2.00a
-- Simplified connectivity for mutli-PowerPC designs. Full JTAG interface
-- connects to core, and internal connectivity determined based on targeted
-- part
-- @END_CHANGELOG
--
--------------------------------------------------------------------------
-- Structure: 
---------------------------------------------------------------------
-- Author: L Ganrot
-- History:
--      LG     7/12/2004 - First Version
--------------------------------------------------------------------------
-- Naming Conventions:
-- active low signals: "*_n"
-- clock signals: "clk", "div#_clk", "#x_clk"
-- reset signals: "rst", "rst_n"
-- generics: "C_*"
-- user defined types: "*_TYPE"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- combinational signals: "*_cmb"
-- pipelined or register delay signals: "*_d#"
-- counter signals: "*cnt*"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- ports: - Names begin with Uppercase
-- processes: "*_PROCESS"
-- component instantiations: "<ENTITY_><#|FUNC>_I
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity jtagppc_cntlr is
  generic (
    C_DEVICE          :     string);
  port (
    TRSTNEG           : in  std_logic;
    -- Halt control PPC 0
    HALTNEG0          : in  std_logic;
    DBGC405DEBUGHALT0 : out std_logic;
    -- Halt control PPC 1
    HALTNEG1          : in  std_logic;
    DBGC405DEBUGHALT1 : out std_logic;
    -- JTAG Port 0
    C405JTGTDO0       : in  std_logic;
    C405JTGTDOEN0     : in  std_logic;
    JTGC405TCK0       : out std_logic;
    JTGC405TDI0       : out std_logic;
    JTGC405TMS0       : out std_logic;
    JTGC405TRSTNEG0   : out std_logic;
    -- JTAG Port 1
    C405JTGTDO1       : in  std_logic;
    C405JTGTDOEN1     : in  std_logic;
    JTGC405TCK1       : out std_logic;
    JTGC405TDI1       : out std_logic;
    JTGC405TMS1       : out std_logic;
    JTGC405TRSTNEG1   : out std_logic
    );
end jtagppc_cntlr;

--------------------------------------------------------------------------------
-- Architecture Implementation
--------------------------------------------------------------------------------
architecture structure of jtagppc_cntlr is

  function LowerCase_Char(char : character) return character is
  begin
    -- If char is not an upper case letter then return char
    if char < 'A' or char > 'Z' then
      return char;
    end if;
    -- Otherwise map char to its corresponding lower case character and
    -- return that
    case char is
      when 'A'    => return 'a'; when 'B' => return 'b'; when 'C' => return 'c'; when 'D' => return 'd';
      when 'E'    => return 'e'; when 'F' => return 'f'; when 'G' => return 'g'; when 'H' => return 'h';
      when 'I'    => return 'i'; when 'J' => return 'j'; when 'K' => return 'k'; when 'L' => return 'l';
      when 'M'    => return 'm'; when 'N' => return 'n'; when 'O' => return 'o'; when 'P' => return 'p';
      when 'Q'    => return 'q'; when 'R' => return 'r'; when 'S' => return 's'; when 'T' => return 't';
      when 'U'    => return 'u'; when 'V' => return 'v'; when 'W' => return 'w'; when 'X' => return 'x';
      when 'Y'    => return 'y'; when 'Z' => return 'z';
      when others => return char;
    end case;
  end LowerCase_Char;

  function LowerCase_String (s : string) return string is
    variable res : string(s'range);
  begin  -- function LoweerCase_String
    for I in s'range loop
      res(I) := LowerCase_Char(s(I));
    end loop;  -- I
    return res;
  end function LowerCase_String;
  
  -- purpose: look up how many ppc's are in the targeted device
  function ppc_cnt (
    constant DEVICE : string)
    return natural is
    variable lowercase_device : string(DEVICE'range);
  begin  -- ppc_cnt
    lowercase_device := LowerCase_String(DEVICE);
    if (lowercase_device = "2vp4") or (lowercase_device = "2vp7") or (lowercase_device = "2vpx20") or (lowercase_device = "4vfx12") or (lowercase_device = "4vfx20") then
      return 1;
    else
      return 2;
    end if;
  end ppc_cnt;
  
  signal C405JTGTDOEN_All : std_logic;
  signal JTGC405TCK       : std_logic;
  signal JTGC405TMS       : std_logic;
  constant device_ppc_cnt : natural := ppc_cnt(C_DEVICE);

begin
  -----------------------------------------------------------------------------
  -- Connect to Internal JTAG Debug Controller  -- 
  -----------------------------------------------------------------------------

  DBGC405DEBUGHALT0 <= not HALTNEG0;
  DBGC405DEBUGHALT1 <= not HALTNEG1;

  JTGC405TRSTNEG0 <= TRSTNEG;
  JTGC405TRSTNEG1 <= TRSTNEG;
  
  C405JTGTDOEN_All <= C405JTGTDOEN0 or C405JTGTDOEN1;

  -----------------------------------------------------------------------------
  -- Chains single PPC to jtagppc primitive. Only to be used in devices with a
  -- single PPC (2VP4, 2VP7, 2VPX20, 4VFX12, 4VXFX20)
  -----------------------------------------------------------------------------
  single_ppc_connectivity: if device_ppc_cnt = 1 generate
    JTAGPPC_i : JTAGPPC port map (
      TCK      => JTGC405TCK0,            -- O
      TDIPPC   => JTGC405TDI0,            -- O
      TMS      => JTGC405TMS0,            -- O
      TDOPPC   => C405JTGTDO0,            -- I
      TDOTSPPC => C405JTGTDOEN0           -- I
      );
  end generate single_ppc_connectivity;


  -----------------------------------------------------------------------------
  -- Chains both PPC devices as required in 2 PPC parts
  -- requires same clock and TMS to be used for both PPCs (Should be case)
  -----------------------------------------------------------------------------
  dual_ppc_connectivity: if device_ppc_cnt = 2 generate
    JTGC405TDI1 <= C405JTGTDO0;
    JTGC405TMS0 <= JTGC405TMS;
    JTGC405TMS1 <= JTGC405TMS;
    JTGC405TCK0 <= JTGC405TCK;
    JTGC405TCK1 <= JTGC405TCK;

    JTAGPPC_i : JTAGPPC port map (
      TCK      => JTGC405TCK,            -- O
      TDIPPC   => JTGC405TDI0,            -- O
      TMS      => JTGC405TMS,            -- O
      TDOPPC   => C405JTGTDO1,            -- I
      TDOTSPPC => C405JTGTDOEN_All        -- I
      );    
  end generate dual_ppc_connectivity;

end structure;

