-------------------------------------------------------------------------------
-- $Id: plb_ipif_reset.vhd,v 1.2 2004/04/12 15:42:20 dougt Exp $
-------------------------------------------------------------------------------
--plb_ipif_reset.vhd   v1.01a
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
-- Filename:        plb_ipif_reset.vhd
--
-- Description:     This VHDL design file is for the Point Design of the Mauna
--                  Loa Ethernet IPIF Reset support block.
--
-------------------------------------------------------------------------------
-- Structure:   
--
--              plb_ipif_reset.vhd
--                  
--
-------------------------------------------------------------------------------
-- Author:      Doug Thorpe
--
-- History:
--     DET     Aug 16, 2001 -- V1.01a (initial release)
--
--     DET     Feb-24-2002  
-- ~~~~~~
--              - Changed asynchronous reset to synchronous resets in clocked
--                processes.
-- ^^^^^^
--
--     DET     4/8/2003     PLB IPIF v1.00.d
-- ~~~~~~
--     - Modified logic for optimized operation on 64 bit PLB bus
--          - Added Bus_BE input signals
--          - Qualified Reset trigger logic for 32 or 64 bit operation
--          - Instantiated Reset generator Flip-flops
-- ^^^^^^
--
--
--     DET     4/12/2004     IPIF to V1_00_f
-- ~~~~~~
--     - Updated unisim library reference to unisim.vcomponents.all
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
---------------------------------------------------------------------
-- Library definitions

library ieee;
use ieee.std_logic_1164.all;


library ieee;
use ieee.std_logic_arith.all; -- need 'conv_std_logic_vector' conversion function


library unisim;
use unisim.vcomponents.all;

----------------------------------------------------------------------

entity plb_ipif_reset is
  Generic (
           C_IPIF_MIR_ENABLE    : Boolean  := false; -- Allows inclusion of the IPIF MIR
           C_IPIF_TYPE          : Integer  := 8;    -- used if MIR is enabled
           C_IPIF_BLK_ID        : Integer  := 90;   -- used if MIR is enabled
           C_IPIF_REVISION      : Integer  := 3;    -- used if MIR is enabled
           C_IPIF_MINOR_VERSION : Integer  := 1;    -- used if MIR is enabled
           C_IPIF_MAJOR_VERSION : Integer  := 1;    -- used if MIR is enabled
           C_DBUS_WIDTH         : Integer  := 64;   -- Data bus width (in bits)
           C_RESET_WIDTH        : Integer  := 4     -- Width of triggered reset in Bus Clocks
          ); 
  port (
  
  -- Inputs From the IPIF Bus 
    Reset                : In  std_logic;  -- Master Reset from the IPIF reset block
    Bus2IP_Clk_i         : In  std_logic;  -- Master timing clock from the IPIF
    Bus2IP_WrReq         : In  std_logic;  
    Bus2IP_RdReq         : In  std_logic;  
    IP_Reset_WrCE        : In  std_logic;
    IP_Reset_RdCE        : In  std_logic;
    Bus_DBus             : In  std_logic_vector(0 to C_DBUS_WIDTH-1);
    Bus_BE               : In  std_logic_vector(0 to (C_DBUS_WIDTH/8)-1);
    
  -- Final Device Reset Output
    Reset2IP_Reset       : Out std_logic; -- Device interrupt output to the Master Interrupt Controller
    
    
  -- Status Reply Outputs to the Bus 
    Reset2Bus_DBus       : Out std_logic_vector(0 to C_DBUS_WIDTH-1);
    Reset2Bus_WrAck      : Out std_logic;
    Reset2Bus_RdAck      : Out std_logic;
    Reset2Bus_Error      : Out std_logic;
    Reset2Bus_Retry      : Out std_logic;
    Reset2Bus_ToutSup    : Out std_logic
    
    );
  end plb_ipif_reset ;
  
  

-------------------------------------------------------------------------------

architecture implementation of plb_ipif_reset is

 -- FUNCTIONS   
    
    -------------------------------------------------------------------
    -- Function
    --
    -- Function Name: POPULATE_MIR
    --
    -- Function Description:
    --
    --
    -------------------------------------------------------------------
    function POPULATE_MIR (major_ver : integer;
                           minor_ver : integer;
                           rev       : integer;
                           blk_id    : integer;
                           type_id   : integer)
        return std_logic_vector is
    
      Variable mir_value : std_logic_vector(0 to 63);
    
    begin
      
      ---------------------------------------------------------------------- 
      -- assemble the MIR fields from the Applicable Generics
      ----------------------------------------------------------------------
         mir_value(0 to 3)     := CONV_STD_LOGIC_VECTOR(C_IPIF_MAJOR_VERSION, 4);
         mir_value(4 to 10)    := CONV_STD_LOGIC_VECTOR(C_IPIF_MINOR_VERSION, 7);
         mir_value(11 to 15)   := CONV_STD_LOGIC_VECTOR(C_IPIF_REVISION, 5);
         mir_value(16 to 23)   := CONV_STD_LOGIC_VECTOR(C_IPIF_BLK_ID, 8); -- conversion to std_logic_vector required
         mir_value(24 to 31)   := CONV_STD_LOGIC_VECTOR(C_IPIF_TYPE, 8);
     
         mir_value(32 to 63)   := (others => '0');
         
     return(mir_value);    
    
    end function POPULATE_MIR;
    
 
 
    

-- COMPONENTS

  -- Xilinx Prim    component FDRSE
  -- Xilinx Prim      port(
  -- Xilinx Prim        Q   : out std_logic;
  -- Xilinx Prim        C   : in  std_logic;
  -- Xilinx Prim        CE  : in  std_logic;
  -- Xilinx Prim        D   : in  std_logic;    
  -- Xilinx Prim        R   : in  std_logic;
  -- Xilinx Prim        S   : in  std_logic
  -- Xilinx Prim        );
  -- Xilinx Prim    end component;
 

--TYPES
    

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

      Signal  sm_reset       : std_logic;
      Signal  error_reply    : std_logic;
  
      Signal  MIR_RdAck      : std_logic;
      Signal  Reset_WrAck    : std_logic;
      Signal  Reset_Error    : std_logic;
      Signal  reset_trig     : std_logic;
      Signal  wrack          : std_logic;
      signal  wrack_ff_chain : std_logic;
      Signal  flop_q_chain   : std_logic_vector(0 to C_RESET_WIDTH);

--------------------------------------------------------------------------------------------------------------
-------------------------------------- start architecture logic -------------------------------------------------
  
begin

           
  -- Misc assignments         
    Reset2Bus_WrAck     <= Reset_WrAck;
    Reset2Bus_RdAck     <= MIR_RdAck;
    Reset2Bus_Error     <= Reset_Error;
    Reset2Bus_Retry     <= '0';
    Reset2Bus_ToutSup   <= sm_reset; -- Suppress a data phase timeout when
                                     -- a commanded reset is active.
           
           
    --Reset_WrAck         <=  wrack and IP_Reset_WrCE;
    Reset_WrAck         <=  (error_reply or wrack) and IP_Reset_WrCE;
    Reset_Error         <=  error_reply and IP_Reset_WrCE;
    Reset2IP_Reset      <=  Reset or sm_reset;
 
           
           
 ------------------------------------------------------------
 -- If Generate
 --
 -- Label: BUS_IS_32
 --
 -- If Generate Description:
 --    This IFGEN implements the reset activation detection logic
 -- when the interface bus data width is 32 bits.
 --
 ------------------------------------------------------------
 BUS_IS_32 : if (C_DBUS_WIDTH <= 32) generate
 
    -- Local Constants
     Constant BE_MATCH : integer := C_DBUS_WIDTH/8-1; -- Required BE index to be active during Reset activation
    -- Local variables
    -- local signals
    -- local components
 
    begin
           
      -----------------------------------------------------------------------
      -- Start the S/W reset state machine as a result of an IPIF Bus write to
      -- the Reset port and the data on the DBus inputs matching the Reset 
      -- match value. If the value on the data bus input does not match the 
      -- designated reset key, an error acknowledge is generated.
      -----------------------------------------------------------------------     
      DETECT_SW_RESET : process (Bus2IP_Clk_i)
        Begin
              
           if (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then

              If (Reset = '1') Then
               
                 error_reply       <= '0';
                 reset_trig        <= '0';
                 
              elsif (IP_Reset_WrCE = '1' and 
                     Bus_BE(BE_MATCH) = '1' and
                     Bus_DBus(C_DBUS_WIDTH-4 to 
                              C_DBUS_WIDTH-1) = RESET_MATCH) Then
                 
                 error_reply       <= '0';
                 reset_trig        <= Bus2IP_WrReq;
              
              elsif (IP_Reset_WrCE = '1') then 
                 
                 error_reply       <= '1';
                 reset_trig        <= '0';
              
              else
                 
                 error_reply       <= '0';
                 reset_trig        <= '0';
              
              End if;
           
           Else 
              null;
           End if;
        End process; -- DETECT_SW_RESET
   
    end generate BUS_IS_32;





 ------------------------------------------------------------
 -- If Generate
 --
 -- Label: BUS_IS_64
 --
 -- If Generate Description:
 --    This IFGEN implements the reset activation detection logic
 -- when the interface bus data width is 64 bits.
 --
 ------------------------------------------------------------
 BUS_IS_64 : if (C_DBUS_WIDTH = 64) generate
 
    -- Local Constants
     Constant BE_MATCH : integer := 3; -- Required BE index to be active during Reset activation
    -- Local variables
    -- local signals
    -- local components
 
    begin
      
      -----------------------------------------------------------------------
      -- Start the S/W reset state machine as a result of an IPIF Bus write to
      -- the Reset port and the data on the DBus inputs matching the Reset 
      -- match value. If the value on the data bus input does not match the 
      -- designated reset key, an error acknowledge is generated.
      -----------------------------------------------------------------------     
      DETECT_SW_RESET : process (Bus2IP_Clk_i)
        Begin
              
           if (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then

              If (Reset = '1') Then
               
                 error_reply       <= '0';
                 reset_trig        <= '0';
               
              elsif (IP_Reset_WrCE = '1' and 
                     Bus_BE(BE_MATCH) = '1' and
                     Bus_DBus(28 to 
                              31) = RESET_MATCH) Then
                 
                 error_reply       <= '0';
                 reset_trig        <= Bus2IP_WrReq;
              
              elsif (IP_Reset_WrCE = '1') then 
                 
                 error_reply       <= '1';
                 reset_trig        <= '0';
              
              else
                 
                 error_reply       <= '0';
                 reset_trig        <= '0';
              
              End if;
           
           Else 
              null;
           End if;
        End process; -- DETECT_SW_RESET
        
    end generate BUS_IS_64;


    ------------------------------------------------------------
    -- For Generate
    --
    -- Label: RESET_FLOPS
    --
    -- For Generate Description:
    --  This FORGEN implements the register chain used to create 
    -- the parameterizable reset pulse width.
    --
    --
    ------------------------------------------------------------
    RESET_FLOPS : for index in 0 to C_RESET_WIDTH-1 generate
       -- local variables
       -- local constants
       -- local signals
       -- local component declarations
    
    begin
     
     flop_q_chain(0) <= '0';
     
     RST_FLOPS : FDRSE
       port map(
         Q   =>  flop_q_chain(index+1), -- :    out std_logic;
         C   =>  Bus2IP_Clk_i,          -- :    in  std_logic;
         CE  =>  '1',                   -- :    in  std_logic;
         D   =>  flop_q_chain(index),   -- :    in  std_logic;    
         R   =>  Reset,                 -- :    in  std_logic;
         S   =>  reset_trig             -- :    in  std_logic
         );
    
    end generate RESET_FLOPS;

    
   -- Use the last flop output for the commanded reset pulse 
    sm_reset        <=  flop_q_chain(C_RESET_WIDTH);

    wrack_ff_chain  <= flop_q_chain(C_RESET_WIDTH) and 
                        not(flop_q_chain(C_RESET_WIDTH-1));
   

  -- Register the Write Acknowledge for the Reset write
  -- This is generated at the end of the reset pulse. This
  -- keeps the Slave busy until the commanded reset completes.
    FF_WRACK : FDRSE
      port map(
        Q   =>  wrack,            -- :  out std_logic;
        C   =>  Bus2IP_Clk_i,     -- :  in  std_logic;
        CE  =>  '1',              -- :  in  std_logic;
        D   =>  wrack_ff_chain,   -- :  in  std_logic;    
        R   =>  Reset,            -- :  in  std_logic;
        S   =>  '0'               -- :  in  std_logic
        );

   
--------------------------------------------------------------------------------------
-- MIR function stuff
-------------------------------------------------------------------------------------- 
 
DELETE_MIR : if (C_IPIF_MIR_ENABLE = False) generate
    
    
    Reset2Bus_DBus <= (others => '0');  -- always zeroes
    
  -- Status Reply Outputs always low 
    MIR_RdAck      <= '0';              -- no RdAck

end generate DELETE_MIR; 
 
 
                           
                           
INCLUDE_MIR : if (C_IPIF_MIR_ENABLE = True) generate

    -- Constant MIR_STATUS : std_logic_vector(0 to 63) := 
    --          POPULATE_MIR(C_IPIF_MAJOR_VERSION,
    --                       C_IPIF_MINOR_VERSION,
    --                       C_IPIF_REVISION,
    --                       C_IPIF_BLK_ID,
    --                       C_IPIF_TYPE);
    
    Constant ZEROS_32 : std_logic_vector(0 to 31) := (others => '0');
    
    Constant MIR_STATUS : std_logic_vector(0 to 63) :=
  
              CONV_STD_LOGIC_VECTOR(C_IPIF_MAJOR_VERSION, 4) &
              CONV_STD_LOGIC_VECTOR(C_IPIF_MINOR_VERSION, 7) &
              CONV_STD_LOGIC_VECTOR(C_IPIF_REVISION, 5)      &
              CONV_STD_LOGIC_VECTOR(C_IPIF_BLK_ID, 8)        &
              CONV_STD_LOGIC_VECTOR(C_IPIF_TYPE, 8)          &
              ZEROS_32;          
  
  
  
    --signal  mir_value         : std_logic_vector(0 to 64);
    signal  Reg_IP_Reset_RdCE : std_logic;

   begin -- generate   

   
   
      REG_RDCE : process (Bus2IP_Clk_i)
        Begin
          if (Bus2IP_Clk_i'EVENT and Bus2IP_Clk_i = '1') Then
             If (Reset = '1') Then
                Reg_IP_Reset_RdCE <= '0';            
             Else 
                Reg_IP_Reset_RdCE <= IP_Reset_RdCE;
             End if;
          Else
             null;
          End if;
        End process; -- REG_RDCE
   
   
   
   OUTPUT_MIR : process (IP_Reset_RdCE, Reg_IP_Reset_RdCE)
      Begin
       
        
        If (IP_Reset_RdCE = '1') Then
           
           --Reset2Bus_DBus <= (others => '0');

          -- Populate the MIR onto the Read data bus
           for i in 0 to C_DBUS_WIDTH-1 loop       --PLB
              Reset2Bus_DBus(i) <= MIR_STATUS(i);  --PLB
           End loop; 
           
          -- Status Reply is RdCE delayed 1 clock 
           MIR_RdAck      <= Reg_IP_Reset_RdCE;  -- RdAck
                 
        else 
          
           Reset2Bus_DBus <= (others => '0');  -- always zeroes
           
         -- Status Reply Outputs always low 
           MIR_RdAck      <= '0';              -- no RdAck
    
        End if;
      End process; -- OUTPUT_MIR
   
   
    

end generate INCLUDE_MIR; 
 

 
      
    
end implementation;


 






