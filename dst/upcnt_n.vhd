-------------------------------------------------------------------------------
-- $Id: upcnt_n.vhd,v 1.3 2003/05/16 16:26:39 conover Exp $
-------------------------------------------------------------------------------
-- upcnt_n - entity/architecture pair
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
-- Filename:        upcnt_n.vhd
--
-- Description:     
--                  This file contains a parameterizable N-bit up counter 
--
-------------------------------------------------------------------------------
-- Structure:   
--
--              upcnt_n.vhd
--
-------------------------------------------------------------------------------
-- Author:      Kurt Conover
-- History:
--  Kurt Conover      11/07/01      -- First Release
--
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
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_SIZE    -- Number of bits in counter
--                          
--
-- Definition of Ports:
--          Data       -- parallel data input
--          Cnt_en     -- count enable
--          Load       -- Load Data
--          Clr        -- reset
--          Clk        -- Clock
--          Qout       -- Count output
--
-------------------------------------------------------------------------------
entity upcnt_n is
   generic(
           C_SIZE : Integer
          );
      
	port(
	     Data    : in  STD_LOGIC_VECTOR (C_SIZE-1 downto 0); 
	     Cnt_en  : in  STD_LOGIC;                            
	     Load    : in  STD_LOGIC;                            
 	     Clr     : in  STD_LOGIC;                            
	     Clk     : in  STD_LOGIC;                            
	     Qout    : out STD_LOGIC_VECTOR (C_SIZE-1 downto 0)
	    );
		
end upcnt_n;

architecture imp of upcnt_n is

constant CLEAR : std_logic := '0';

signal q_int : UNSIGNED (C_SIZE-1 downto 0) := (others => '1');

begin
   process(Clk)
   begin
	       
      if (Clk'event) and Clk = '1' then
          -- Clear output register
         if (Clr = CLEAR) then
            q_int <= (others => '0');
	       -- Load in start value
         elsif (Load = '1') then
            q_int <= UNSIGNED(Data);
	       -- If count enable is high
         elsif Cnt_en = '1' then
		      q_int <= q_int + 1;
         end if;
      end if;
   end process;

   Qout <= STD_LOGIC_VECTOR(q_int);

end imp;
  

