-------------------------------------------------------------------------------
-- $Id: plb_sesr_sear.vhd,v 1.2 2004/04/12 15:42:20 dougt Exp $
-------------------------------------------------------------------------------
-- PLB SEAR and SESR Register entity and architecture
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
-- Filename:        plb_sesr_sear.vhd
-- Version:         v1_00_a
-- Description:     This block implements the PLB Slave Error Status Register 
--                  (SEAR)  and Slave Error Address Register (SEAR). This 
--                  module will be optioned in or out by a Generic.
--
-------------------------------------------------------------------------------
-- Structure: 
--
--              plb_sesr_sear.vhd
-------------------------------------------------------------------------------
-- Author:      DET
-- History:
--  det     - Mar-5-2002 Initial version
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;


-------------------------------------------------------------------------------
entity plb_sesr_sear is
    generic (
        C_PLB_MID_WIDTH     : Integer := 4; 
        C_PLB_AWIDTH        : integer := 32;
        C_PLB_DWIDTH        : Integer := 32;
        C_SESR_SEAR_DWIDTH  : Integer := 32;
        C_NUM_CE            : Integer := 2
        );
    port(        
        --System Input signals
        Bus_Reset           : in  std_logic;
        Bus_Clk             : in  std_logic;
        
        -- General Input signals
        Bus2IP_RdReq        : In  std_logic;
        Bus2IP_WrReq        : In  std_logic;
        SESR_RdCE           : In  std_logic_vector(0 to C_NUM_CE-1);
        SESR_WrCE           : In  std_logic_vector(0 to C_NUM_CE-1);
        Bus2IP_DBus         : In  std_logic_vector(0 to C_PLB_DWIDTH-1);
        Bus2IP_Addr         : in  std_logic_vector(0 to C_PLB_AWIDTH-1);
        Bus2IP_RNW          : in  std_logic;
        Bus2IP_BE           : in  std_logic_vector(0 to C_PLB_DWIDTH/8-1);
        SA2SESR_MID         : in  std_logic_vector(0 to C_PLB_MID_WIDTH-1);
        SA2SESR_size        : in  std_logic_vector(0 to 3);
        SA2SESR_type        : in  std_logic_vector(0 to 2);
        SA2SESR_Sl_SSize    : in  std_logic_vector(0 to 1);
        
        -- Capture trigger signals
        MUX2SA_ErrAck       : in  std_logic;
        SA2INT_DAck_Timeout : in  std_logic;
        
        -- Outputs
        SESR2Bus_RdAck      : out std_logic; 
        SESR2Bus_WrACK      : out std_logic; 
        SESR2Bus_Error      : out std_logic; 
        SESR2Bus_ToutSup    : out std_logic; 
        SESR2Bus_Retry      : out std_logic; 
        SESR2Bus_Data       : out std_logic_vector(0 to C_SESR_SEAR_DWIDTH-1)
        );
end plb_sesr_sear;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

architecture implementation of plb_sesr_sear is



-------------------------------------------------------------------------------                       
-- Type Declarations
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
   Constant NEED_EXTENDED_SEAR : boolean := (C_PLB_AWIDTH > 32);
   Constant LOCK_KEY : std_logic_vector(0 to 3) := "1010";
   Constant MATCH_BE : integer := 0;
   
   Constant REG_WIDTH : integer := 32;
   
   
   
-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
 
 
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
  
  Signal sig_sesr_reg           : std_logic_vector(0 to REG_WIDTH-1);
  Signal sig_sear_reg           : std_logic_vector(0 to REG_WIDTH-1);
  Signal sear_sesr_rd_data      : std_logic_vector(0 to C_SESR_SEAR_DWIDTH-1);


-------------------------------------------------------------------------------
-- begin the architecture logic
-------------------------------------------------------------------------------
begin




   -- Misc Output assignments        
   SESR2Bus_Retry   <= '0';
   SESR2Bus_ToutSup <= '0';
   SESR2Bus_Error   <= '0';


-------------------------------------------------------------------------------
NORMAL_ADDR_BUS : If (NEED_EXTENDED_SEAR = false) generate
 
      signal SESR2Bus_RdAck_i  : std_logic;
      signal SESR2Bus_WrACK_i  : std_logic;
      Signal triggered         : boolean;

   begin
    
    
    
   CAPTURE_STATUS : process (bus_clk)
      BEGIN
          
         If (bus_clk'EVENT and bus_clk = '1') Then
       
            -- Default the Write Acknowledge to inactive
            SESR2Bus_WrACK_i <= '0';
            
            If (bus_reset = '1') Then
               
               triggered        <= false;
               sig_sesr_reg     <= (others => '0');
               sig_sear_reg     <= (others => '0');
            
            Elsif (SESR_WrCE(0)        = '1' and
                   Bus2IP_BE(MATCH_BE) = '1' and
                   Bus2IP_DBus(4 to 7) = LOCK_KEY) Then
            
               triggered        <= false;
               sig_sesr_reg     <= (others => '0');
               sig_sear_reg     <= (others => '0');
               SESR2Bus_WrACK_i <= Bus2IP_WrReq;
            
            Elsif (triggered = false and
                  (MUX2SA_ErrAck = '1' or
                   SA2INT_DAck_Timeout = '1') ) Then
            
               -- Set the triggered indication
               triggered             <= true;

               -- Populate the SEAR Register
               sig_sear_reg     <= (others => '0'); --default state
               for p in 0 to C_PLB_AWIDTH-1 loop
                   sig_sear_reg(p)  <= Bus2IP_Addr(p);
               End loop; 
               
               -- Populate the SESR Register
               sig_sesr_reg          <= (others => '0'); --default state
               sig_sesr_reg(0)       <= MUX2SA_ErrAck;
               sig_sesr_reg(1)       <= Bus2IP_RNW;
               sig_sesr_reg(2)       <= SA2INT_DAck_Timeout;
               sig_sesr_reg(3 to 4)  <= SA2SESR_Sl_SSize;
               sig_sesr_reg(5 to 7)  <= SA2SESR_type;
               sig_sesr_reg(8 to 11) <= SA2SESR_size;
               
               for i in 0 to C_PLB_MID_WIDTH-1 loop
                   sig_sesr_reg(12+i+(4-C_PLB_MID_WIDTH)) <= SA2SESR_MID(i);
               End loop; 
               
               for j in 0 to (C_PLB_DWIDTH/8)-1 loop
                   sig_sesr_reg(16+j) <= Bus2IP_BE(j);
               End loop; 

            else
            
               null; -- hold state
               
            End if;
         
         else
            null;
         End if;

     END PROCESS; -- CAPTURE_STATUS


 
   SESR2Bus_WrACK <= SESR2Bus_WrACK_i;


   
   ------------------------------------------------------------
   -- If Generate
   --
   -- Label: READ_BUS_32
   --
   -- If Generate Description:
   --   This IFGEN implements the read-back structure for a
   -- 32-bit PLB Data Bus.
   --
   --
   ------------------------------------------------------------
   READ_BUS_32 : if (C_SESR_SEAR_DWIDTH = 32) generate
   
      -- Local Constants
      -- Local variables
      -- local signals
      -- local components
   
      begin
   
        READ_CONTROL : process (SESR_RdCE, 
                                --Bus2IP_RdReq,
                                sig_sesr_reg, 
                                sig_sear_reg)
         Begin
         
             If (SESR_RdCE(0) = '1') Then
         
               sear_sesr_rd_data <= sig_sesr_reg;
               --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
               
             Elsif (SESR_RdCE(1) = '1') Then
             
               sear_sesr_rd_data <= sig_sear_reg;
               --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
                 
             else  
               
               sear_sesr_rd_data <= (others => '0');
               --SESR2Bus_RdAck_i  <= '0';
               
             End if;
             
                     
          
         End process; -- READ_CONTROL

        
        
    -- Generate the Read Acknowledge on a valid read
     GEN_RDACK : process (bus_clk)
        Begin
           If (bus_clk'EVENT and bus_clk = '1') Then
               if (Bus_Reset = '1') Then
                   SESR2Bus_RdAck_i <= '0';
               Else
                   SESR2Bus_RdAck_i <= (SESR_RdCE(0) and Bus2IP_RdReq) or
                                       (SESR_RdCE(1) and Bus2IP_RdReq);
               End if;
               
           else
              null;
           End if;
        End process; -- GEN_RDACK

        
        -- now connect to output data bus
        SESR2Bus_Data <= sear_sesr_rd_data; -- 32 bit bus
        SESR2Bus_RdAck <= SESR2Bus_RdAck_i;
      
      end generate READ_BUS_32;

     
     
     
   ------------------------------------------------------------
   -- If Generate
   --
   -- Label: READ_BUS_64
   --
   -- If Generate Description:
   --   This IFGEN implements the read-back structure for a
   -- 64-bit PLB Data Bus.
   --
   ------------------------------------------------------------
   READ_BUS_64 : if (C_SESR_SEAR_DWIDTH = 64) generate

      -- Local Constants
      -- Local variables
      -- local signals
      -- local components

      begin
        
        READ_CONTROL : process (SESR_RdCE, 
                                --Bus2IP_RdReq,
                                sig_sesr_reg, 
                                sig_sear_reg)
         Begin
         
             If (SESR_RdCE(0) = '1') Then
         
               sear_sesr_rd_data <= sig_sesr_reg & sig_sear_reg;
               --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
               
             --Elsif (SESR_RdCE(1) = '1') Then
             --
             --  sear_sesr_rd_data <= sig_sear_reg;
             --  --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
                 
             else  
               
               sear_sesr_rd_data <= (others => '0');
               --SESR2Bus_RdAck_i  <= '0';
               
             End if;
             
                     
          
         End process; -- READ_CONTROL

    -- Generate the Read Acknowledge on a valid read
    GEN_RDACK : process (bus_clk)
       Begin
          If (bus_clk'EVENT and bus_clk = '1') Then
              if (Bus_Reset = '1') Then
                  SESR2Bus_RdAck_i <= '0';
              Else
                  SESR2Bus_RdAck_i <= (SESR_RdCE(0) and Bus2IP_RdReq);
              End if;
              
          else
             null;
          End if;
       End process; -- GEN_RDACK


        -- now connect to output data bus
        SESR2Bus_Data <= sear_sesr_rd_data; -- 64 bit bus
        SESR2Bus_RdAck <= SESR2Bus_RdAck_i;
               
      end generate READ_BUS_64;


End generate NORMAL_ADDR_BUS;


       
       
       
EXTENDED_ADDR_BUS : If (NEED_EXTENDED_SEAR = true) generate
   
      signal SESR2Bus_RdAck_i       : std_logic;
      signal SESR2Bus_WrACK_i       : std_logic;
      Signal sig_sear_reg_extended  : std_logic_vector(0 to 31);
      Signal triggered              : boolean;
      
   begin 

   CAPTURE_STATUS : process (bus_clk)
      BEGIN
          
         If (bus_clk'EVENT and bus_clk = '1') Then
       
            -- Default the Write Acknowledge to inactive
            SESR2Bus_WrACK_i <= '0';
         
            If (bus_reset = '1') Then
               
               triggered             <= false;
               sig_sesr_reg          <= (others => '0');
               sig_sear_reg          <= (others => '0');
               sig_sear_reg_extended <= (others => '0');
            
            Elsif (SESR_WrCE(0) = '1' and
                   Bus2IP_DBus(0 to 3) = LOCK_KEY) Then
            
               triggered             <= false;
               sig_sesr_reg          <= (others => '0');
               sig_sear_reg          <= (others => '0');
               sig_sear_reg_extended <= (others => '0');
               SESR2Bus_WrACK_i      <= Bus2IP_WrReq;
            
            Elsif (triggered = false and
                  (MUX2SA_ErrAck = '1' or
                   SA2INT_DAck_Timeout = '1') ) Then
            
               -- Set the Triggered flag
               triggered             <= true;
               
               -- Populate the SEAR Register
               sig_sear_reg          <= Bus2IP_Addr(0 to 31);
               
               -- default extended reg to all to zeros
                           sig_sear_reg_extended <= (others => '0'); 
                           -- now assign extra addr bits 
                           for j in 32 to C_PLB_AWIDTH-1 loop        
                  sig_sear_reg_extended(j-32) <= Bus2IP_Addr(j);    
               End loop; 
                              
               -- Populate the SESR Register
               sig_sesr_reg          <= (others => '0'); --default state
               sig_sesr_reg(0)       <= MUX2SA_ErrAck;
               sig_sesr_reg(1)       <= Bus2IP_RNW;
               sig_sesr_reg(2)       <= SA2INT_DAck_Timeout;
               sig_sesr_reg(3 to 4)  <= SA2SESR_Sl_SSize;
               sig_sesr_reg(5 to 7)  <= SA2SESR_type;
               sig_sesr_reg(8 to 11) <= SA2SESR_size;
               
               for i in 0 to C_PLB_MID_WIDTH-1 loop
                   sig_sesr_reg(12+i+(4-C_PLB_MID_WIDTH)) <= SA2SESR_MID(i);
               End loop; 
               
               for j in 0 to (C_PLB_DWIDTH/8)-1 loop
                   sig_sesr_reg(16+j) <= Bus2IP_BE(j);
               End loop; 
            
            else
            
               null; -- hold state
               
            End if;
         
         else
            null;
         End if;

     END PROCESS; -- CAPTURE_STATUS

 
   SESR2Bus_WrACK <= SESR2Bus_WrACK_i;


   
   ------------------------------------------------------------
   -- If Generate
   --
   -- Label: READ_BUS_32_EXTND
   --
   -- If Generate Description:
   --   This IFGEN implements the read-back structure for a
   -- 32-bit PLB Data Bus and an extended SEAR.
   --
   --
   ------------------------------------------------------------
   READ_BUS_32_EXTND : if (C_SESR_SEAR_DWIDTH = 32) generate
   
      -- Local Constants
      -- Local variables
      -- local signals
      -- local components
   
      begin
   
        READ_CONTROL_EXTND : process (SESR_RdCE, 
                                      --Bus2IP_RdReq,
                                      sig_sesr_reg, 
                                      sig_sear_reg)
         Begin
         
           If (SESR_RdCE(0) = '1') Then
       
             sear_sesr_rd_data <= sig_sesr_reg;
             --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
             
           Elsif (SESR_RdCE(1) = '1') Then
       
             sear_sesr_rd_data <= sig_sear_reg;
             --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
               
           Elsif (SESR_RdCE(2) = '1') Then
       
             sear_sesr_rd_data <= sig_sear_reg_extended;
             --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
               
           else  
             
             sear_sesr_rd_data <= (others => '0');
             --SESR2Bus_RdAck_i  <= '0';
             
           End if;
                     
          
         End process; -- READ_CONTROL

    
      -- Generate the Read Acknowledge on a valid read
      GEN_RDACK : process (bus_clk)
         Begin
            If (bus_clk'EVENT and bus_clk = '1') Then
                if (Bus_Reset = '1') Then
                    SESR2Bus_RdAck_i <= '0';
                Else
                    SESR2Bus_RdAck_i <= (SESR_RdCE(0) and Bus2IP_RdReq) or
                                        (SESR_RdCE(1) and Bus2IP_RdReq) or
                                        (SESR_RdCE(2) and Bus2IP_RdReq);
                End if;
                
            else
               null;
            End if;
         End process; -- GEN_RDACK
 
 
        -- now connect to output data bus
        SESR2Bus_Data  <= sear_sesr_rd_data; -- 32 bit bus
        SESR2Bus_RdAck <= SESR2Bus_RdAck_i;
      
      end generate READ_BUS_32_EXTND;

     
     
     
   ------------------------------------------------------------
   -- If Generate
   --
   -- Label: READ_BUS_64_EXTND
   --
   -- If Generate Description:
   --   This IFGEN implements the read-back structure for a
   -- 64-bit PLB Data Bus and an extended SEAR.
   --
   ------------------------------------------------------------
   READ_BUS_64_EXTND : if (C_SESR_SEAR_DWIDTH = 64) generate

      -- Local Constants
         Constant ZEROS_32 : std_logic_vector(0 to 31) := (others => '0');
         
      -- Local variables
      -- local signals
      -- local components

      begin
        
        READ_CONTROL_EXTND : process (SESR_RdCE, 
                                      --Bus2IP_RdReq,
                                      sig_sesr_reg, 
                                      sig_sear_reg)
         Begin
         
           If (SESR_RdCE(0) = '1') Then
       
             sear_sesr_rd_data <= sig_sesr_reg & sig_sear_reg;
             --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
             
           Elsif (SESR_RdCE(1) = '1') Then
       
             sear_sesr_rd_data <= sig_sear_reg_extended & ZEROS_32;
             --SESR2Bus_RdAck_i  <= Bus2IP_RdReq;
               
           else  
             
             sear_sesr_rd_data <= (others => '0');
             --SESR2Bus_RdAck_i  <= '0';
             
           End if;
                     
          
         End process; -- READ_CONTROL

      -- Generate the Read Acknowledge on a valid read
      GEN_RDACK : process (bus_clk)
         Begin
            If (bus_clk'EVENT and bus_clk = '1') Then
                if (Bus_Reset = '1') Then
                    SESR2Bus_RdAck_i <= '0';
                Else
                    SESR2Bus_RdAck_i <= (SESR_RdCE(0) and Bus2IP_RdReq) or
                                        (SESR_RdCE(1) and Bus2IP_RdReq);
                End if;
                
            else
               null;
            End if;
         End process; -- GEN_RDACK
 
 
        -- now connect to output data bus
        SESR2Bus_Data <= sear_sesr_rd_data; -- 64 bit bus
        SESR2Bus_RdAck <= SESR2Bus_RdAck_i;
               
      end generate READ_BUS_64_EXTND;
 

End generate EXTENDED_ADDR_BUS;

       
       
 
end implementation;
