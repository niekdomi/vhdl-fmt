-------------------------------------------------------------------------------
-- $Id: pf_dly1_mux.vhd,v 1.2 2004/04/12 16:32:31 dougt Exp $
-------------------------------------------------------------------------------
-- pf_dly1_mux.vhd - entity/architecture pair
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
-- Filename:        pf_dly1_mux.vhd
--
-- Description:     Implements a multiplexer and register combo that allows 
--                  selection of a registered or non-registered version of
--                  the input signal for output.
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--                  pf_dly1_mux.vhd
--
-------------------------------------------------------------------------------
-- Author:          B.L. Tise
-- Revision:        $Revision: 1.2 $
-- Date:            $Date: 2004/04/12 16:32:31 $
--
-- History:
--   D. Thorpe      2001-08-30    First Version
--                  - adapted from B Tise MicroBlaze counters
--
--   DET            2001-09-11   
--                  - Added the Rst input signal and connected it to the FDRE
--                    reset input.
--
--
--   DET            2002-02-24
--                  - Changed to call out proc_common_v1_00_b library.
--                  - Removed unused MUXCY_L and XORCY components.
--
--     DET     3/25/2004     ipif to v1_00_f
-- ~~~~~~
--                  - Changed to call out proc_common_v2_00_a library.
-- ^^^^^^
--
--
--     DET     4/12/2004     IPIF to V1_00_f
-- ~~~~~~
--     - Updated unisim library reference to unisim.vcomponents.all.
--     - Commented out Xilinx primitive component declarations
-- ^^^^^^
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
-----------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

library proc_common_v2_00_a;
Use proc_common_v2_00_a.inferred_lut4;
                

-- Xilinx Primitive Library
library unisim;
use unisim.vcomponents.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity pf_dly1_mux is
  Generic (C_MUX_WIDTH : Integer := 12
       );
  port (
    Clk           : in  std_logic;
    Rst           : In  std_logic;
    dly_sel1      : in  std_logic;
    dly_sel2      : in  std_logic;
    Inputs        : in  std_logic_vector(0 to C_MUX_WIDTH-1);
    Y_out         : out std_logic_vector(0 to C_MUX_WIDTH-1)
    );

end pf_dly1_mux;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture implementation of pf_dly1_mux is
  
  
  component inferred_lut4 is 
   generic (INIT : bit_vector(15 downto 0)); 
   port ( 
     O  : out std_logic; 
     I0 : in std_logic; 
     I1 : in std_logic; 
     I2 : in std_logic; 
     I3 : in std_logic 
     );
  end component inferred_lut4;
  
 
   
  -- Xilinx Prim    component FDRE is
  -- Xilinx Prim      port (
  -- Xilinx Prim        Q  : out std_logic;
  -- Xilinx Prim        C  : in  std_logic;
  -- Xilinx Prim        CE : in  std_logic;
  -- Xilinx Prim        D  : in  std_logic;
  -- Xilinx Prim        R  : in  std_logic
  -- Xilinx Prim      );
  -- Xilinx Prim    end component FDRE;
  
  signal    lut_out  : std_logic_vector(0 to C_MUX_WIDTH-1);
  signal    reg_out  : std_logic_vector(0 to C_MUX_WIDTH-1);
  signal    count_Result_Reg : std_logic;

  attribute INIT       : string;
  
begin  -- VHDL_RTL

        
        
   MAKE_DLY_MUX : for i in 0 to C_MUX_WIDTH-1 generate
     
     
     
        --- xst wrk around  I_SEL_LUT : LUT4
        --- xst wrk around    generic map(
        --- xst wrk around    -- synthesis translate_off
        --- xst wrk around      Xon  => false,
        --- xst wrk around    -- synthesis translate_on    
        --- xst wrk around      INIT => X"FE10"
        --- xst wrk around      )
        --- xst wrk around    port map (
        --- xst wrk around      O  => lut_out(i),               
        --- xst wrk around      I0 => dly_sel1,      
        --- xst wrk around      I1 => dly_sel2,      
        --- xst wrk around      I2 => Inputs(i),    
        --- xst wrk around      I3 => reg_out(i)
        --- xst wrk around     );          
        
        
        
        
        I_SEL_LUT : inferred_lut4
          generic map(
            INIT => X"FE10"
            )
          port map (
            O  => lut_out(i),               
            I0 => dly_sel1,      
            I1 => dly_sel2,      
            I2 => Inputs(i),    
            I3 => reg_out(i)
           );          
        
        
        
        FDRE_I: FDRE
          port map (
            Q  =>  reg_out(i),          
            C  =>  Clk,          
            CE =>  '1',          
            D  =>  Inputs(i),          
            R  =>  Rst          
          );      
       
   End generate MAKE_DLY_MUX; 
           
        
   Y_out <= lut_out;
        
                             
                             
end implementation;


