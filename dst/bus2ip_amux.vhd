-------------------------------------------------------------------------------
-- $Id: bus2ip_amux.vhd,v 1.3 2001/10/15 22:48:56 ostlerf Exp $
-------------------------------------------------------------------------------
-- bus2ip_amux.vhd - vhdl design file for the entity and architecture
--                            of the Mauna Loa IPIF Bus to IPIF Bus Address
--                            multiplexer.
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        bus2ip_amux.vhd
--
-- Description:     This vhdl design file is for the entity and architecture  
--                  of the Mauna Loa IPIF Bus to IPIF Bus Address Bus Output 
--                  multiplexer.        
--
-------------------------------------------------------------------------------
-- Structure:   
--              
--
--              bus2ip_amux.vhd
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
-- History:
--  DET        May-9-01      -- First version
--
--
--  DET        May-22-01     -- Changed architecture to reflect addr counter and 
--                               non-registered address outputs.
--
--  FO         Oct-15-01     -- Added byte-enable channel.
--                           -- Subsumed ipif_interrupt.vhd into this file;
--                              there is no longer a wrapper.
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
--
-- Library definitions

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all; -- need the unsigned functions

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
entity bus2ip_amux is
  Generic (
           C_IPIF_ABUS_WIDTH    : Integer;
           C_IPIF_DBUS_WIDTH    : integer
          ); 
    port (
       -- Clock and Reset
         Bus2IP_Reset_i     : In  std_logic;
         Bus2IP_Clk_i       : In  std_logic;
       
       -- Select control from the Master Attachment
         Mstr_sel_ma        : In  std_logic;
       
       -- Slave Attachment I/O
         Addr_Cntr_ClkEN_sa  : In  std_logic;
         Addr_sel_sa        : In  std_logic_vector(0 to 1);
         Bus2IP_Addr_sa     : in  std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
    
       -- Address Bus inputs from the IP Master
         IP2IP_Addr         : in  std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
         
       -- Address Bus inputs from the DMA/SG engine
         DMA2IP_Addr        : in  std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
         
       -- IPIF & IP address bus source (AMUX output)
         Bus2IP_Addr_i      : out std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);

       -- Byte-enable channels
         Bus2IP_BE_sa       : in  std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1);
         IP2IP_BE           : in  std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1);
         DMA2IP_BE          : in  std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1);
         Bus2IP_BE_i        : out std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8 -1)

         );
end bus2ip_amux;




architecture implementation of bus2ip_amux is


    
-- COMPONENTS

--TYPES
    
  -- no types
  
             
-- CONSTANTS
  -- no constants
  

--INTERNAL SIGNALS
  Signal  selected_addr     : std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1);
  Signal  reg_addr_plus1    : unsigned(0 to C_IPIF_ABUS_WIDTH-1);
  Signal  addr_plus1        : unsigned(0 to C_IPIF_ABUS_WIDTH-1);
  Signal  selected_be       : std_logic_vector(0 to C_IPIF_DBUS_WIDTH/8-1);
  
 
--------------------------------------------------------------------------------------------------------------
-------------------------------------- start of logic -------------------------------------------------
  
begin
  
  
  
  Bus2IP_Addr_i <=  selected_addr; 
  Bus2IP_BE_i   <=  selected_be; 
  
  
  
 
-------------------------------------------------------------------------
-- This process switches the desired input address to the MUX output.
-------------------------------------------------------------------------
SELECT_THE_ADDRESSES :  process (Addr_sel_sa, Mstr_sel_ma, Bus2IP_Addr_sa, DMA2IP_Addr,
                                 IP2IP_Addr, reg_addr_plus1,
                                 DMA2IP_BE, IP2IP_BE, Bus2IP_BE_sa)
  Begin

    Case Addr_sel_sa Is

      When "00" =>              -- External Bus address Selected
         selected_addr <= Bus2IP_Addr_sa;
         selected_be   <= Bus2IP_BE_sa;
      
      When "01" =>              -- Local Master Address Selected
         If (Mstr_sel_ma = '1') Then
            selected_addr <= DMA2IP_Addr;
            selected_be   <= DMA2IP_BE;
         else
            selected_addr <= IP2IP_Addr;
            selected_be   <= IP2IP_BE;
         End if;
      
      When "10" =>              -- Address Register Output Plus 1 Selected
         selected_addr <= std_logic_vector(reg_addr_plus1);
         If (Mstr_sel_ma = '1') Then
            selected_be   <= DMA2IP_BE;
         else
            selected_be   <= IP2IP_BE;
         End if;
      
      When others   =>          -- Default to External Bus Selected
         selected_addr <= Bus2IP_Addr_sa;
         selected_be   <= Bus2IP_BE_sa;
      
      End case;
  
  End process; --SELECT_THE_ADDRESSES


-------------------------------------------------------------------------
-- Combinationally increment the registered address output for 
-- feedback into the select mux
-------------------------------------------------------------------------
 INCREMENT_THE_ADDR : process (selected_addr)
    Begin

       addr_plus1 <= unsigned(selected_addr) + 1;
       
       
    End process; -- INCREMENT_THE_ADDR
    
                                 
                                 
-------------------------------------------------------------------------
-- Combinationally increment the registered address output for 
-- feedback into the select mux
-------------------------------------------------------------------------
REG_THE_ADDR_PLUS_1 : process (Bus2IP_Reset_i, Bus2IP_Clk_i)
  Begin
     If (Bus2IP_Reset_i = '1') Then
        reg_addr_plus1 <= (others => '0');
        
     Elsif (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
        If (Addr_Cntr_ClkEN_sa = '1') Then
           reg_addr_plus1 <= addr_plus1;  -- register address+1 input
        Else
           null; -- Hold last address+1 registered
        End if;
     else
       null;
     End if;
       
  End process; -- REG_THE_ADDR_PLUS_1




      
end implementation;
  




