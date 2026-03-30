--SINGLE_FILE_TAG
-------------------------------------------------------------------------------
-- $Id: proc_sys_reset.vhd,v 1.5 2004/11/23 01:18:19 jcanaris Exp $
-------------------------------------------------------------------------------
-- proc_sys_reset - entity/architecture pair
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
-- Filename:        proc_sys_reset.vhd
--
-- Description:     Parameterizeable top level processor reset module.
--
--
-------------------------------------------------------------------------------
-- Structure:   This section should show the hierarchical structure of the
--              designs. Separate lines with blank lines if necessary to improve
--              readability.
--
--              proc_sys_reset.vhd
--                  -- upcnt_n.vhd
--                      -- third_level_file1.vhd
--                          -- fourth_level_file.vhd
--                      -- third_level_file2.vhd
--                  -- second_level_file2.vhd
--                  -- second_level_file3.vhd
--
--              This section is optional for common/shared modules but should
--              contain a statement stating it is a common/shared module.
-------------------------------------------------------------------------------
-- Author:      kc
-- History:
--  kc           11/07/01      -- First version
--
--  kc           02/25/2002    -- Changed generic names C_EXT_RST_ACTIVE to
--                                C_EXT_RESET_HIGH and C_AUX_RST_ACTIVE to
--                                C_AUX_RESET_HIGH to match generics used in
--                                MicroBlaze.  Added the DCM Lock as an input
--                                to keep reset active until after the Lock
--                                is valid.
-- lcw          10/11/2004  -- Updated for NCSim
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
library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
library proc_sys_reset_v1_00_a;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_EXT_RST_WIDTH       -- External Reset Low Pass Filter setting
--          C_AUX_RST_WIDTH       -- Auxiliary Reset Low Pass Filter setting
--          C_EXT_RESET_HIGH      -- External Reset Active High or Active Low
--          C_AUX_RESET_HIGH      -= Auxiliary Reset Active High or Active Low
--          C_NUM_BUS_RST         -- Number of Bus Structures reset to generate
--          C_NUM_PERP_RST        -- Number of Peripheral resets to generate
--
--
-- Definition of Ports:
--          Slowest_sync_clk       -- Clock
--          Ext_Reset_In           -- External Reset Input
--          Aux_Reset_In           -- Auxiliary Reset Input
--          Core_Reset_Req         -- PPC Core reset request
--          Chip_Reset_Req         -- PPC Chip reset request
--          System_Reset_Req       -- PPC System reset request
--          Dcm_locked             -- DCM Locked, hold system in reset until 1
--          Rstc405resetcore       -- PPC core reset out
--          Rstc405resetchip       -- PPC chip reset out
--          Rstc405resetsys        -- PPC system reset out
--          Bus_Struct_Reset       -- Bus structure reset out
--          Peripheral_Reset       -- Peripheral reset out
--
-------------------------------------------------------------------------------
entity proc_sys_reset is
    generic (
              C_EXT_RST_WIDTH          : integer   := 4;
              C_AUX_RST_WIDTH          : integer   := 4;
              C_EXT_RESET_HIGH         : std_logic := '1'; -- High active input
              C_AUX_RESET_HIGH         : std_logic := '1'; -- High active input
              C_NUM_BUS_RST            : integer   := 1;
              C_NUM_PERP_RST           : integer   := 1
            );

    port (
          Slowest_sync_clk     : in  std_logic;
          Ext_Reset_In         : in  std_logic;
          Aux_Reset_In         : in  std_logic;
          Core_Reset_Req       : in  std_logic;
          Chip_Reset_Req       : in  std_logic;
          System_Reset_Req     : in  std_logic;
          Dcm_locked           : in  std_logic := '1';
          Rstc405resetcore     : out std_logic := '0';
          Rstc405resetchip     : out std_logic := '0';
          Rstc405resetsys      : out std_logic := '0';
          Bus_Struct_Reset     : out std_logic_vector(0 to C_NUM_BUS_RST - 1)
                                      := (others => '0');
          Peripheral_Reset     : out std_logic_vector(0 to C_NUM_PERP_RST - 1)
                                      := (others => '0')
         );

end entity proc_sys_reset;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture imp of proc_sys_reset is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------

constant ALL_ONES   : std_logic_vector(7 downto 0)  := "11111111";
constant DE         : std_logic_vector(7 downto 0)  := "11011110";
constant AD         : std_logic_vector(7 downto 0)  := "10101101";
constant BE         : std_logic_vector(7 downto 0)  := "10111110";
constant EF         : std_logic_vector(7 downto 0)  := "11101111";

-------------------------------------------------------------------------------
-- Signal and Type Declarations
signal Core_Reset_Req_d1   : std_logic := '0';  -- delayed Core_Reset_Req
signal Core_Reset_Req_d2   : std_logic := '0';  -- delayed Core_Reset_Req
signal Core_Reset_Req_d3   : std_logic := '0';  -- delayed Core_Reset_Req

signal core_cnt_en         : std_logic := '0'; -- Core_Reset_Req counter enable

signal core_req_edge       : std_logic := '1'; -- Rising edge of Core_Reset_Req

signal core_cnt     : std_logic_vector(3 downto 0); -- core counter output

signal lpf_reset    : std_logic; -- Low pass filtered ext or aux

signal Bsr_out      : std_logic;
signal Pr_out       : std_logic;
signal Core_out     : std_logic;
signal Chip_out     : std_logic;
signal Sys_out      : std_logic;
-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
--
begin
-------------------------------------------------------------------------------
-- This process defines the Rstc405reset outputs
-------------------------------------------------------------------------------
Rstc_output_PROCESS: process (Slowest_sync_clk)
   begin
      if (Slowest_sync_clk'event and Slowest_sync_clk = '1') then
         Rstc405resetcore  <= not (core_cnt(3) and core_cnt(2) and core_cnt(1)
                                   and core_cnt(0))
                                   or Core_out;


         Rstc405resetchip  <= Chip_out;

         Rstc405resetsys   <= Sys_out;

      end if;
   end process;

-------------------------------------------------------------------------------
-- This process delays signals so the the edge can be detected and used
--  Double register to sync up with slowest_sync_clk
-------------------------------------------------------------------------------
DELAY_PROCESS: process (Slowest_sync_clk)
begin
      if (Slowest_sync_clk'event and Slowest_sync_clk = '1') then
         core_reset_req_d1   <= Core_Reset_Req  ;
         core_reset_req_d2   <= core_reset_req_d1;
         core_reset_req_d3   <= core_reset_req_d2;
      end if;
   end process;

-------------------------------------------------------------------------------
-- This For-generate creates D-Flip Flops for the Bus_Struct_Reset output(s)
-------------------------------------------------------------------------------
      BSR_OUT_DFF: for i in 0 to C_NUM_BUS_RST - 1 generate
         BSR_DFF : process (Slowest_Sync_Clk)
         begin
            if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
               Bus_Struct_Reset(i) <= Bsr_out;
            end if;
         end process;
      end generate BSR_OUT_DFF;

-------------------------------------------------------------------------------
-- This For-generate creates D-Flip Flops for the Peripheral_Reset output(s)
-------------------------------------------------------------------------------
      PR_OUT_DFF: for i in 0 to C_NUM_PERP_RST - 1 generate
         PR_DFF : process (Slowest_Sync_Clk)
         begin
            if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
               Peripheral_Reset(i) <= Pr_out;
            end if;
         end process;
      end generate PR_OUT_DFF;


-------------------------------------------------------------------------------
-- This instantiates a counter to ensure the Core_Reset_Req will genereate a
-- Rstc045resetcore that is a mimimum of 15 clocks
-------------------------------------------------------------------------------
   CORE_RESET : entity proc_sys_reset_v1_00_a.UPCNT_N
   generic map (
                C_SIZE => 4
               )

     port map(
              Data     => "0000",
              Cnt_en   => core_cnt_en,
              Load     => '0',
              Clr      => core_req_edge,
              Clk      => Slowest_sync_clk,
              Qout     => core_cnt
             );

-------------------------------------------------------------------------------
-- CORE_RESET_PROCESS
-------------------------------------------------------------------------------
--  This generates the reset pulse and the count enable to core reset counter
--
CORE_RESET_PROCESS: process (Slowest_sync_clk)
   begin
      if (Slowest_sync_clk'event and Slowest_sync_clk = '1') then
         core_cnt_en <= not (core_cnt(3) and core_cnt(2) and core_cnt(1))
                        or not core_req_edge;
         core_req_edge <= not(core_Reset_Req_d2 and not core_reset_req_d3);
      end if;
   end process;

-------------------------------------------------------------------------------
-- This instantiates a low pass filter to filter both External and Auxiliary
-- Reset Inputs.
-------------------------------------------------------------------------------
   EXT_LPF : entity proc_sys_reset_v1_00_a.LPF
   generic map (
           C_EXT_RST_WIDTH    => C_EXT_RST_WIDTH   ,
           C_AUX_RST_WIDTH    => C_AUX_RST_WIDTH   ,
           C_EXT_RESET_HIGH   => C_EXT_RESET_HIGH  ,
           C_AUX_RESET_HIGH   => C_AUX_RESET_HIGH
              )
   port map(
            Dcm_locked               => Dcm_locked        ,
            External_System_Reset    => Ext_Reset_In      ,
            Auxiliary_System_Reset   => Aux_Reset_In      ,
            Slowest_Sync_Clk         => Slowest_Sync_Clk  ,
            Lpf_reset                => Lpf_reset
           );

-------------------------------------------------------------------------------
-- This instantiates the sequencer
--  This controls the time between resets becoming inactive
-------------------------------------------------------------------------------
   SEQ : entity proc_sys_reset_v1_00_a.SEQUENCE
   port map(
            Lpf_reset              => Lpf_reset         ,
            System_Reset_Req       => System_Reset_Req  ,
            Chip_Reset_Req         => Chip_Reset_Req    ,
            Slowest_Sync_Clk       => Slowest_Sync_Clk  ,
            Bsr_out                => Bsr_out           ,
            Pr_out                 => Pr_out            ,
            Core_out               => Core_out          ,
            Chip_out               => Chip_out          ,
            Sys_out                => Sys_out
           );

end imp;

--END_SINGLE_FILE_TAG
