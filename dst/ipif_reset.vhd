-------------------------------------------------------------------------------
-- $Id: ipif_reset.vhd,v 1.3 2001/10/15 22:48:57 ostlerf Exp $
-------------------------------------------------------------------------------
--ipif_reset.vhd   v1.01a
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        ipif_reset.vhd
--
-- Description:     This VHDL design file is for the Point Design of the Mauna
--                  Loa Ethernet IPIF Reset support block.
--
-------------------------------------------------------------------------------
-- Structure:   
--
--              ipif_reset.vhd
--                  
--
-------------------------------------------------------------------------------
-- Author:      Doug Thorpe
--
-- History:
--  Doug Thorpe  Aug 16, 2001 -- V1.01a (initial release)
--
--
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
---------------------------------------------------------------------
-- Library definitions

library ieee;
use ieee.std_logic_1164.all;


library ieee;
use ieee.std_logic_arith.all; -- need 'conv_std_logic_vector' conversion function

----------------------------------------------------------------------

entity ipif_reset is
  Generic (
           --C_RESET_PRESENT      : Boolean  := True; -- specifies if interrupt function is used
           C_DBUS_WIDTH         : Integer  := 32;   -- Data bus width (in bits)
           C_IPIF_MIR_ENABLE    : Boolean  := False;-- Allows inclusion of the IPIF MIR
           C_IPIF_TYPE          : Integer  := 1;    -- used if MIR is enabled
           C_IPIF_BLK_ID        : Integer  := 1;    -- used if MIR is enabled
           C_IPIF_REVISION      : Integer  := 1;    -- used if MIR is enabled
           C_IPIF_MINOR_VERSION : Integer  := 0;    -- used if MIR is enabled
           C_IPIF_MAJOR_VERSION : Integer  := 0     -- used if MIR is enabled
          ); 
  port (
  
  -- Inputs From the IPIF Bus 
    Reset               : In  std_logic;  -- Master Reset from the IPIF reset block
    Bus2IP_Clk_i        : In  std_logic;  -- Master timing clock from the IPIF
    IP_Reset_WrCE       : In  std_logic;
    IP_Reset_RdCE       : In  std_logic;
    Bus_DBus            : In  std_logic_vector(0 to C_DBUS_WIDTH-1);
    
  -- Final Device Reset Output
    Reset2IP_Reset      : Out std_logic; -- Device interrupt output to the Master Interrupt Controller
    
    
  -- Status Reply Outputs to the Bus 
    Reset2Bus_DBus       : Out std_logic_vector(0 to C_DBUS_WIDTH-1);
    Reset2Bus_WrAck      : Out std_logic;
    Reset2Bus_RdAck      : Out std_logic;
    Reset2Bus_Error      : Out std_logic;
    Reset2Bus_Retry      : Out std_logic;
    Reset2Bus_ToutSup    : Out std_logic
    
    );
  end ipif_reset ;
  
  

-------------------------------------------------------------------------------

architecture implementation of ipif_reset is

--TYPES
    
    type sw_reset_state_types  is (idle, wait_for_bus, reset_1, reset_2);  
  

-- CONSTANTS

    -- Module Software Reset screen value for write data
     Constant RESET_MATCH : std_logic_vector(0 to 3) := "1010"; -- This requires a Hex 'A' to be written
                                                                -- to ativate the S/W reset port
 
    -- general use constants 
     Constant LOGIC_LOW      : std_logic := '0';
     Constant LOGIC_HIGH     : std_logic := '1';
     
     
     
    -- Generic to constant mapping
     --Constant IPIF_BUS_WIDTH     : Integer range 0 to 31 := C_DBUS_WIDTH - 1;
     
  
  

--INTERNAL SIGNALS

      Signal  sw_reset_state : sw_reset_state_types;
      Signal  strt_sm_reset  : std_logic;
      Signal  sm_reset       : std_logic;
      Signal  sm_wrack       : std_logic;
      Signal  error_reply    : std_logic;
  
      Signal  MIR_RdAck      : std_logic;
      Signal  Reset_WrAck    : std_logic;
      Signal  Reset_Error    : std_logic;

--------------------------------------------------------------------------------------------------------------
-------------------------------------- start architecture logic -------------------------------------------------
  
begin

           
  -- Misc assignments         
    Reset2Bus_WrAck     <= Reset_WrAck;
    Reset2Bus_RdAck     <= MIR_RdAck;
    Reset2Bus_Error     <= Reset_Error;
    Reset2Bus_Retry     <= '0';
    Reset2Bus_ToutSup   <= '0';
           
           
    Reset_WrAck         <=  (sm_wrack  or error_reply) and IP_Reset_WrCE;
    Reset_Error         <=  error_reply and IP_Reset_WrCE;
    Reset2IP_Reset      <=  Reset or sm_reset;
 
           
           
           
           
 -----------------------------------------------------------------------
 -- Start the S/W reset state machine as a result of an IPIF Bus write to
 -- the Reset port and the data on the DBus inputs matching the Reset 
 -- match value. If the value on the data bus input does not match the 
 -- designated reset key, an error acknowledge is generated.
 -----------------------------------------------------------------------     
 DETECT_SW_RESET : process (Reset, Bus2IP_Clk_i)
   Begin
      If (Reset = '1') Then
         strt_sm_reset     <= '0';
         error_reply       <= '0';
      Elsif (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
         If (IP_Reset_WrCE = '1' and Bus_DBus(C_DBUS_WIDTH-4 to C_DBUS_WIDTH-1) = RESET_MATCH) Then
            strt_sm_reset     <= '1';
            error_reply       <= '0';
         elsif (IP_Reset_WrCE = '1') then 
            strt_sm_reset     <= '0';
            error_reply       <= '1';
         else
            strt_sm_reset     <= '0';
            error_reply       <= '0';
         End if;
      Else 
         null;
      End if;
   End process; -- DETECT_SW_RESET
   
  
   
   
 -----------------------------------------------------------------------
 -- The S/W reset state machine causes a 2 clock wide reset pulse that 
 -- occurs after the initiating bus cycle completes.
 -----------------------------------------------------------------------     
 RESET_STATE_MACHINE : process (Reset, Bus2IP_Clk_i)
  Begin
      If (Reset = '1') Then
         sw_reset_state  <= idle;
         sm_reset        <= '0';
         sm_wrack        <= '0';
         
      Elsif (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
 
         sm_reset    <= '0'; -- default value
         sm_wrack    <= '0'; -- default value
          
         Case sw_reset_state Is
 
           When idle => 
              If (strt_sm_reset = '1') Then
                 sw_reset_state <= wait_for_bus;
                 sm_wrack       <= '1';       -- issue the write ack to the ipif bus
              else
                 sw_reset_state   <= idle;
              End if;
              
           When wait_for_bus => 
              
              If (IP_Reset_WrCE = '1') Then   -- wait until bus cycle completes
                 sw_reset_state <= wait_for_bus;
                 sm_wrack       <= '1';       -- issue the write ack to the ipif bus
              else
                 sw_reset_state  <= reset_1;
                 sm_reset        <= '1';
              End if;
              
           When reset_1 =>
              sw_reset_state  <= reset_2;
              sm_reset        <= '1';
               
           When reset_2 => 
              sw_reset_state  <= idle; 
               
           When others   => 
              sw_reset_state   <= idle;
         End case;
          
      Else 
         null;
      End if;
     
  End process; -- RESET_STATE_MACHINE
          
 
 
 
           

--------------------------------------------------------------------------------------
-- MIR function stuff
-------------------------------------------------------------------------------------- 
 
DELETE_MIR : if (C_IPIF_MIR_ENABLE = False) generate
    
    
    Reset2Bus_DBus <= (others => '0');  -- always zeroes
    
  -- Status Reply Outputs always low 
    MIR_RdAck      <= '0';              -- no RdAck

end generate DELETE_MIR; 
 
 
                           
                           
INCLUDE_MIR : if (C_IPIF_MIR_ENABLE = True) generate
  
    signal  mir_value         : std_logic_vector(0 to 31);
    signal  Reg_IP_Reset_RdCE : std_logic;

   begin -- generate   

   ---------------------------------------------------------------------- 
   -- assemble the MIR fields from the Applicable Generics
   ----------------------------------------------------------------------
      mir_value(0 to 3)       <= CONV_STD_LOGIC_VECTOR(C_IPIF_MAJOR_VERSION, 4);
      mir_value(4 to 10)      <= CONV_STD_LOGIC_VECTOR(C_IPIF_MINOR_VERSION, 7);
      mir_value(11 to 15)     <= CONV_STD_LOGIC_VECTOR(C_IPIF_REVISION, 5);
      mir_value(16 to 23)     <= CONV_STD_LOGIC_VECTOR(C_IPIF_BLK_ID, 8); -- conversion to std_logic_vector required
      mir_value(24 to 31)     <= CONV_STD_LOGIC_VECTOR(C_IPIF_TYPE, 8);
      
   
   
   REG_RDCE : process (Reset, Bus2IP_Clk_i)
     Begin
       If (Reset = '1') Then
          Reg_IP_Reset_RdCE <= '0';
       Elsif (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
          Reg_IP_Reset_RdCE <= IP_Reset_RdCE;
       Else
          null;
       End if;
     End process; -- REG_RDCE
   
   
   
   OUTPUT_MIR : process (IP_Reset_RdCE, Reg_IP_Reset_RdCE, mir_value)
      Begin
        
        If (IP_Reset_RdCE = '1') Then

           for i in 0 to  C_DBUS_WIDTH-1 loop
              Reset2Bus_DBus(i) <= mir_value(i);
           End loop; --forloop_n2
           
           -- Status Reply is RdCE delayed 1 clock 
           MIR_RdAck      <= Reg_IP_Reset_RdCE;  -- no RdAck
                 
        else 
          
           Reset2Bus_DBus <= (others => '0');  -- always zeroes
           
         -- Status Reply Outputs always low 
           MIR_RdAck      <= '0';              -- no RdAck
    
        End if;
      End process; -- OUTPUT_MIR
   
   
    

end generate INCLUDE_MIR; 
 



                        
                        
-- --------------------------------------------------------------------------------------
-- -- Reset function stuff
-- -------------------------------------------------------------------------------------- 
--  
-- DELETE_RESET : if (C_RESET_PRESENT = False) generate
--   
--   -- Final Device Reset Output
--     Reset2IP_Reset   <= Reset; -- Just pass the Reset signal through
--                                   -- to the output
--     
--   -- Status Reply Outputs always low 
--     Reset_WrAck      <= '0';
--     Reset_Error      <=  '0';  -- tie to zero                                
-- 
-- end generate DELETE_RESET; 
--  
 
 
 
-- INCLUDE_RESET : if (C_RESET_PRESENT = True) generate
--  
-- --TYPES
--     
--     type sw_reset_state_types  is (idle, wait_for_bus, reset_1, reset_2);  
--   
-- -- CONSTANTS
-- 
--   
--     -- Module Software Reset screen value for write data
--      Constant RESET_MATCH : std_logic_vector(0 to 3) := "1010"; -- This requires a Hex 'A' to be written
--                                                                 -- to ativate the S/W reset port
--  
--     -- general use constants 
--      Constant LOGIC_LOW      : std_logic := '0';
--      Constant LOGIC_HIGH     : std_logic := '1';
--      
--      
--      
--     -- Generic to constant mapping
--      --Constant IPIF_BUS_WIDTH     : Integer range 0 to 31 := C_DBUS_WIDTH - 1;
--      
--   
--   
-- 
-- --INTERNAL SIGNALS
-- 
--       Signal  sw_reset_state : sw_reset_state_types;
--       Signal  strt_sm_reset  : std_logic;
--       Signal  sm_reset       : std_logic;
--       Signal  sm_wrack       : std_logic;
--       Signal  error_reply    : std_logic;
-- 
--              
--              
--   
-- begin  -- generate
-- 
-- -- Misc I/O and Signal assignments 
-- 
--  Reset_WrAck    <=  (sm_wrack  or error_reply) and IP_Reset_WrCE;
--  Reset_Error    <=  error_reply and IP_Reset_WrCE;
--  
-- 
--  Reset2IP_Reset <=  Reset or sm_reset;
-- 
--  
--   
-- -----------------------------------------------------------------------
-- -- Start the S/W reset state machine as a result of an IPIF Bus write to
-- -- the Reset port and the data on the DBus inputs matching the Reset 
-- -- match value. If the value on the data bus input does not match the 
-- -- designated reset key, an error acknowledge is generated.
-- -----------------------------------------------------------------------     
-- DETECT_SW_RESET : process (Reset, Bus2IP_Clk_i)
--   Begin
--      If (Reset = '1') Then
--         strt_sm_reset     <= '0';
--         error_reply       <= '0';
--      Elsif (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
--         If (IP_Reset_WrCE = '1' and Bus_DBus(C_DBUS_WIDTH-4 to C_DBUS_WIDTH-1) = RESET_MATCH) Then
--            strt_sm_reset     <= '1';
--            error_reply       <= '0';
--         elsif (IP_Reset_WrCE = '1') then 
--            strt_sm_reset     <= '0';
--            error_reply       <= '1';
--         else
--            strt_sm_reset     <= '0';
--            error_reply       <= '0';
--         End if;
--      Else 
--         null;
--      End if;
--   End process; -- DETECT_SW_RESET
--   
--  
--   
--   
-- -----------------------------------------------------------------------
-- -- The S/W reset state machine causes a 2 clock wide reset pulse that 
-- -- occurs after the initiating bus cycle completes.
-- -----------------------------------------------------------------------     
-- RESET_STATE_MACHINE : process (Reset, Bus2IP_Clk_i)
--  Begin
--      If (Reset = '1') Then
--         sw_reset_state  <= idle;
--         sm_reset        <= '0';
--         sm_wrack        <= '0';
--         
--      Elsif (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
-- 
--         sm_reset    <= '0'; -- default value
--         sm_wrack    <= '0'; -- default value
--          
--         Case sw_reset_state Is
-- 
--           When idle => 
--              If (strt_sm_reset = '1') Then
--                 sw_reset_state <= wait_for_bus;
--                 sm_wrack       <= '1';       -- issue the write ack to the ipif bus
--              else
--                 sw_reset_state   <= idle;
--              End if;
--              
--           When wait_for_bus => 
--              
--              If (IP_Reset_WrCE = '1') Then   -- wait until bus cycle completes
--                 sw_reset_state <= wait_for_bus;
--                 sm_wrack       <= '1';       -- issue the write ack to the ipif bus
--              else
--                 sw_reset_state  <= reset_1;
--                 sm_reset        <= '1';
--              End if;
--              
--           When reset_1 =>
--              sw_reset_state  <= reset_2;
--              sm_reset        <= '1';
--               
--           When reset_2 => 
--              sw_reset_state  <= idle; 
--               
--           When others   => 
--              sw_reset_state   <= idle;
--         End case;
--          
--      Else 
--         null;
--      End if;
--     
--  End process; -- RESET_STATE_MACHINE
--  
-- 
-- 
-- end generate INCLUDE_RESET; 
 
 
      
    
end implementation;


 






