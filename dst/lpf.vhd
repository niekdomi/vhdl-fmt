-------------------------------------------------------------------------------
-- $Id: lpf.vhd,v 1.4 2003/08/29 19:44:46 conover Exp $
-------------------------------------------------------------------------------
-- lpf - entity/architecture pair
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
-- Filename:        lpf.vhd
--
-- Description:     
--                  This file contains a parameterizable low pass filter
--                  and double registers for meta-stability.  Also the active
--                  high or low for the reset inputs are generated here.
--
-------------------------------------------------------------------------------
-- Structure:   
--
--              lpf.vhd
--
-------------------------------------------------------------------------------
-- Author:      Kurt Conover
-- History:
--  Kurt Conover      11/08/01      -- First Release
--
--  KC                02/25/2002    -- Added Dcm_locked as an input
--                                  -- Added Power on reset srl_time_out
--
--  KC                08/26/2003    -- Added attribute statements for power on 
--                                     reset SRL
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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
library Unisim; 
use Unisim.all; 
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_EXT_RST_WIDTH       -- External Reset Low Pass Filter setting
--          C_AUX_RST_WIDTH       -- Auxiliary Reset Low Pass Filter setting   
--          C_EXT_RESET_HIGH      -- External Reset Active High or Active Low
--          C_AUX_RESET_HIGH      -= Auxiliary Reset Active High or Active Low
--
-- Definition of Ports:
--          Slowest_sync_clk       -- Clock 
--          External_System_Reset  -- External Reset Input
--          Auxiliary_System_Reset -- Auxiliary Reset Input
--          Dcm_locked             -- DCM Locked, hold system in reset until 1
--          Lpf_reset              -- Low Pass Filtered Output
--
-------------------------------------------------------------------------------
entity lpf is
   generic(
           C_EXT_RST_WIDTH    : Integer;
           C_AUX_RST_WIDTH    : Integer;
           C_EXT_RESET_HIGH   : std_logic;
           C_AUX_RESET_HIGH   : std_logic 
          );
      
   port(
        Dcm_locked               : in  std_logic;
        External_System_Reset    : in  std_logic; 
        Auxiliary_System_Reset   : in  std_logic;                         
        Slowest_Sync_Clk         : in  std_logic; 
        Lpf_reset                : out std_logic                          
       );
      
end lpf;

architecture imp of lpf is

component SRL16 is 
-- synthesis translate_off 
  generic ( 
        INIT : bit_vector ); 
-- synthesis translate_on 
  port (D    : in  std_logic; 
        CLK  : in  std_logic; 
        A0   : in  std_logic; 
        A1   : in  std_logic; 
        A2   : in  std_logic; 
        A3   : in  std_logic; 
        Q    : out std_logic); 
end component SRL16; 


constant CLEAR : std_logic := '0';

signal exr_d1        : std_logic := '0'; -- delayed External_System_Reset
signal exr_lpf       : std_logic_vector(0 to C_EXT_RST_WIDTH - 1)
                             := (others => '0'); -- LPF DFF
                             
signal asr_d1        : std_logic := '0'; -- delayed Auxiliary_System_Reset
signal asr_lpf       : std_logic_vector(0 to C_AUX_RST_WIDTH - 1)
                             := (others => '0'); -- LPF DFF
                             
signal exr_and       : std_logic := '0'; -- varible input width "and" gate
signal exr_nand      : std_logic := '0'; -- vaiable input width "and" gate
                     
signal asr_and       : std_logic := '0'; -- varible input width "and" gate
signal asr_nand      : std_logic := '0'; -- vaiable input width "and" gate
                     
signal lpf_int       : std_logic := '0'; -- internal Lpf_reset
signal lpf_exr       : std_logic := '0';
signal lpf_asr       : std_logic := '0';
                     
signal srl_time_out  : std_logic;

attribute INIT             : string;
attribute INIT of POR_SRL_I: label is "FFFF";


begin

   Lpf_reset <= lpf_int;
   
-------------------------------------------------------------------------------
-- Power On Reset Generation
-------------------------------------------------------------------------------
--  This generates a reset for the first 16 clocks after a power up
-------------------------------------------------------------------------------
  POR_SRL_I: SRL16 
-- synthesis translate_off 
    generic map ( 
      INIT => X"FFFF") 
-- synthesis translate_on 
    port map ( 
      D   => '0', 
      CLK => Slowest_sync_clk, 
      A0  => '1', 
      A1  => '1', 
      A2  => '1', 
      A3  => '1', 
      Q   => srl_time_out); 
   
-------------------------------------------------------------------------------
-- LPF_OUTPUT_PROCESS
-------------------------------------------------------------------------------
--  This generates the reset pulse and the count enable to core reset counter
--
LPF_OUTPUT_PROCESS: process (Slowest_sync_clk)
   begin
      if (Slowest_sync_clk'event and Slowest_sync_clk = '1') then
         lpf_int <= lpf_exr or lpf_asr or srl_time_out or not Dcm_locked;
      end if;
   end process;

EXR_OUTPUT_PROCESS: process (Slowest_sync_clk)
   begin
      if (Slowest_sync_clk'event and Slowest_sync_clk = '1') then
         if exr_and = '1' then
            lpf_exr <= '1';
         elsif (exr_and = '0' and exr_nand = '1') then
            lpf_exr <= '0';
         end if;
      end if;
   end process;

ASR_OUTPUT_PROCESS: process (Slowest_sync_clk)
   begin
      if (Slowest_sync_clk'event and Slowest_sync_clk = '1') then
         if asr_and = '1' then
            lpf_asr <= '1';
         elsif (asr_and = '0' and asr_nand = '1') then
            lpf_asr <= '0';
         end if;
      end if;
   end process;
-------------------------------------------------------------------------------
-- This If-generate selects an active high input for External System Reset 
-------------------------------------------------------------------------------
ACTIVE_HIGH_EXT: if (C_EXT_RESET_HIGH /= '0') generate  
   ACT_HI_EXT:process(Slowest_Sync_Clk)
   begin
      if (Slowest_Sync_Clk'event and Slowest_Sync_Clk = '1') then
         exr_d1     <= External_System_Reset;
         exr_lpf(0) <= exr_d1;
      end if;
   end process;
end generate ACTIVE_HIGH_EXT;
-------------------------------------------------------------------------------
-- This If-generate selects an active low input for External System Reset 
-------------------------------------------------------------------------------
ACTIVE_LOW_EXT: if  (C_EXT_RESET_HIGH = '0') generate  
   ACT_LO_EXT: process(Slowest_Sync_Clk)
   begin
      if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
         exr_d1     <= not External_System_Reset;
         exr_lpf(0) <= exr_d1;
      end if;
   end process;
end generate ACTIVE_LOW_EXT;

-------------------------------------------------------------------------------
-- This If-generate selects an active high input for Auxiliary System Reset 
-------------------------------------------------------------------------------
ACTIVE_HIGH_AUX: if (C_AUX_RESET_HIGH /= '0') generate  
   ACT_HI_AUX: process(Slowest_Sync_Clk)
   begin
      if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
         asr_d1     <= Auxiliary_System_Reset;
         asr_lpf(0) <= asr_d1;
      end if;
   end process;
end generate ACTIVE_HIGH_AUX;
-------------------------------------------------------------------------------
-- This If-generate selects an active low input for Auxiliary System Reset 
-------------------------------------------------------------------------------
ACTIVE_LOW_AUX: if (C_AUX_RESET_HIGH = '0') generate  
   ACT_LO_AUX: process(Slowest_Sync_Clk)
   begin
      if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
         asr_d1     <= not Auxiliary_System_Reset;
         asr_lpf(0) <= asr_d1;
      end if;
   end process;
end generate ACTIVE_LOW_AUX;

-------------------------------------------------------------------------------
-- This For-generate creates the low pass filter D-Flip Flops
-------------------------------------------------------------------------------
      EXT_LPF: for i in 1 to C_EXT_RST_WIDTH - 1 generate
         EXT_LPF_DFF : process (Slowest_Sync_Clk)
         begin
            if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
               exr_lpf(i) <= exr_lpf(i-1);
            end if;
         end process;
      end generate EXT_LPF;
------------------------------------------------------------------------------------------
-- Implement the 'AND' function on the for the LPF
------------------------------------------------------------------------------------------
  EXT_LPF_AND : process (exr_lpf)
    Variable loop_and  : std_logic;
    Variable loop_nand : std_logic;
    Begin
       loop_and  := '1';
       loop_nand := '1';
       for j in 0 to C_EXT_RST_WIDTH - 1 loop
          loop_and  := loop_and and      exr_lpf(j);
          loop_nand := loop_nand and not exr_lpf(j);
       End loop;
      
       exr_and  <= loop_and;
       exr_nand <= loop_nand;

    end process; 

-------------------------------------------------------------------------------
-- This For-generate creates the low pass filter D-Flip Flops
-------------------------------------------------------------------------------
      AUX_LPF: for k in 1 to C_AUX_RST_WIDTH - 1 generate
         AUX_LPF_DFF : process (Slowest_Sync_Clk)
         begin
            if (Slowest_Sync_Clk'event) and Slowest_Sync_Clk = '1' then
               asr_lpf(k) <= asr_lpf(k-1);
            end if;
         end process;
      end generate AUX_LPF;
------------------------------------------------------------------------------------------
-- Implement the 'AND' function on the for the LPF
------------------------------------------------------------------------------------------
  AUX_LPF_AND : process (asr_lpf)
    Variable aux_loop_and  : std_logic;
    Variable aux_loop_nand : std_logic;
    Begin
       aux_loop_and  := '1';
       aux_loop_nand := '1';
       for m in 0 to C_AUX_RST_WIDTH - 1 loop
          aux_loop_and  := aux_loop_and and      asr_lpf(m);
          aux_loop_nand := aux_loop_nand and not asr_lpf(m);
       End loop;
      
       asr_and  <= aux_loop_and;
       asr_nand <= aux_loop_nand;

    end process; 

end imp;
  

