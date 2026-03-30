-------------------------------------------------------------------------------
-- $Id: ip2bus_dmux.vhd,v 1.3 2001/10/15 22:48:57 ostlerf Exp $
-------------------------------------------------------------------------------
-- ip2bus_dmux.vhd - vhdl design file for the entity and architecture
--                            of the Mauna Loa IPIF IP to IPIF Bus Read Data
--                            multiplexer (actually just a big OR gate) with
--                            some parameterization added.
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        ip2bus_dmux.vhd
--
-- Description:     This vhdl design file is for the entity and architecture  
--                  of the Mauna Loa IPIF IP to IPIF Bus Read Data Output 
--                  multiplexer (actually just a big OR gate). Added some 
--                  parameters       
--
-------------------------------------------------------------------------------
-- Structure:   
--              
--
--              ip2bus_dmux.vhd
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
-- History:
--  DET        Apr-25-01      -- v0.00a version
--
--  DET        June 6, 01     -- v0.00b added some parameterization
--
--  DET        July 19, 01    -- v0.00c Added IPIF Reset MIR data bus input
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


-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
entity ip2bus_dmux is
    Generic (C_DBUS_WIDTH       : Integer := 32
         );
    port (
    
       -- Read Data Bus inputs from the IP
         IP2Bus_Data        : in    std_logic_vector(0 to C_DBUS_WIDTH-1);
         
       -- Read Data Bus inputs from the Write FIFO
         WFIFO2Bus_Data     : in    std_logic_vector(0 to C_DBUS_WIDTH-1);
         
       -- Read Data Bus inputs from the Read FIFO
         RFIFO2Bus_Data     : in    std_logic_vector(0 to C_DBUS_WIDTH-1);
         
       -- Read Data Bus inputs from the DMA/SG engine
         DMA2Bus_Data       : in    std_logic_vector(0 to C_DBUS_WIDTH-1);
         
       -- Read Data from the IPIF Interrupt processinng block
         IRPT2Bus_Data      : In    std_logic_vector(0 to C_DBUS_WIDTH-1);
         
       -- Read Data from the IPIF Reset MIR function
         Reset2Bus_Data     : In    std_logic_vector(0 to C_DBUS_WIDTH-1);
         
         
       -- Read Data Bus outputs to the Slave Attachment
         IP2Bus_Data_sa     : out   std_logic_vector(0 to C_DBUS_WIDTH-1)
         
        
         );
end ip2bus_dmux;



architecture implementation of ip2bus_dmux is


    
-- COMPONENTS

--TYPES
    
  -- no types
  
             
-- CONSTANTS
   
  

--INTERNAL SIGNALS
  -- none      
      
      
--------------------------------------------------------------------------------------------------------------
-------------------------------------- start of logic -------------------------------------------------
  
begin
  
  
 -- The following code is for a simple 'OR' function of the input signals 
 -- to generate a single output. This method works in place of a multiplexer
 -- since by definition inactive signals (and unused) are driven to a logic '0'.
 
 -- Combinational logic
    
OR_THE_DATA :  process (IP2Bus_Data, WFIFO2Bus_Data, RFIFO2Bus_Data, DMA2Bus_Data,
                        IRPT2Bus_Data, Reset2Bus_Data)
  Begin                                                                          
                      
    
     for i in 0 to C_DBUS_WIDTH-1 loop
    
         IP2Bus_Data_sa(i) <=  IP2Bus_Data(i)    or
                               WFIFO2Bus_Data(i) or
                               RFIFO2Bus_Data(i) or
                               DMA2Bus_Data(i)   or
                               IRPT2Bus_Data(i)  or
                               Reset2Bus_Data(i);
       
     End loop;
          
  End process; --OR_THE_DATA
                                         
      
end implementation;
  




