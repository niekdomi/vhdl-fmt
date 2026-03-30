-------------------------------------------------------------------------------
-- $Id: burst_support.vhd,v 1.3 2004/11/23 01:11:50 jcanaris Exp $
-------------------------------------------------------------------------------
-- burst_support.vhd
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
-- Filename:        burst_support.vhd
--
-- Description:     
--  This VHDL design implements burst support features that are used for fixed
-- length bursts and cacheline transfers. Some indeterminate burst support  
-- logic is provided.                
--                  
--                  
--                  
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--              burst_support.vhd
--
-------------------------------------------------------------------------------
-- Author:          DET
-- Revision:        $Revision: 1.3 $
-- Date:            $5/15/2002$
--
-- History:
--     DET     6/12/2003     Initial
-- ~~~~~~
--     - This design was adapted from the determinate timer module.
-- ^^^^^^
--
--     DET     3/25/2004     plb ipif to  V1_00_f
-- ~~~~~~
--     - Removed reference to ipif_common_library
--     - Updated proc_common library reference to v2_00_a
-- ^^^^^^
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
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
Use IEEE.std_logic_arith.all;
Use IEEE.std_logic_unsigned.all;

Library proc_common_v2_00_a;
Use proc_common_v2_00_a.all;
Use proc_common_v2_00_a.proc_common_pkg.all;
Use proc_common_v2_00_a.ipif_pkg.all;

-- Xilinx Primitive Library
library unisim;
use unisim.vcomponents.all;


-------------------------------------------------------------------------------

entity burst_support is
  generic (
    -- Generics
    C_MAX_DBEAT_CNT          : Integer := 16
    );
  port (
    -- Input ports
    Bus_reset           : In std_logic;
    Bus_clk             : In std_logic;
    RNW                 : In std_logic;
    Req_Init            : In std_logic;
    Req_Active          : In std_logic;
    Indet_Burst         : In std_logic; -- '1' = Indeterminate burst operation
    Num_Data_Beats      : In integer range 0 to C_MAX_DBEAT_CNT;
    Target_AddrAck      : In std_logic;
    Target_DataAck      : In std_logic;
    WrBuf_wen           : In std_logic;
    
    -- Output signals
    Control_Ack         : Out std_logic;
    Control_AlmostDone  : Out std_logic;
    Control_Done        : Out std_logic;
    Response_Ack        : Out std_logic;
    Response_AlmostDone : Out std_logic;
    Response_Done       : Out std_logic
    );

end entity burst_support;


architecture implementation of burst_support is

  -- functions
    -- none
 
  
  -- Constants
  --Constant COUNTER_SIZE     : integer := 5;
  constant DBEAT_CNTR_SIZE  : integer := log2(C_MAX_DBEAT_CNT)+1;
  Constant LOGIC_LOW        : std_logic := '0';
  Constant LOGIC_HIGH       : std_logic := '1';
  Constant ZERO             : integer := 0;
  Constant ONE              : integer := 1;
  
  
  Constant COUNT_ZERO     : std_logic_vector(0 to DBEAT_CNTR_SIZE-1)
                            := CONV_STD_LOGIC_VECTOR(ZERO, DBEAT_CNTR_SIZE);
                          
  Constant CYCLE_CNT_ZERO : std_logic_vector(0 to DBEAT_CNTR_SIZE-1)
                            := CONV_STD_LOGIC_VECTOR(ZERO, DBEAT_CNTR_SIZE);
                          
  Constant CYCLE_CNT_ONE  : std_logic_vector(0 to DBEAT_CNTR_SIZE-1)
                            := CONV_STD_LOGIC_VECTOR(ONE, DBEAT_CNTR_SIZE);
                          
                    
  -- Types
  
  
   
  -- Signals
  
   -- Control Counter
   Signal cntl_dbeat_count      : std_logic_vector(0 to DBEAT_CNTR_SIZE-1);
   Signal cntl_db_load_value    : std_logic_vector(0 to DBEAT_CNTR_SIZE-1);
   Signal cntl_db_cnten         : std_logic;
   Signal Control_Done_i        : std_logic;
   Signal Control_AlmostDone_i  : std_logic;
   Signal cntl_done_reg         : std_logic;
   Signal cntl_cntup            : std_logic;
   
   -- Response Counter
   Signal resp_dbeat_count      : std_logic_vector(0 to DBEAT_CNTR_SIZE-1);
   Signal resp_db_load_value    : std_logic_vector(0 to DBEAT_CNTR_SIZE-1);
   Signal resp_db_cnten         : std_logic;
   Signal Response_Done_i       : std_logic;
   Signal Response_AlmostDone_i : std_logic;
   Signal resp_done_reg         : std_logic;
   
   -- General Signals
   Signal rnw_s_h               : std_logic;
   
                                              
  
  -- Component Declarations
   
   -- Xilinx Prim    component FDRE is
   -- Xilinx Prim      port (
   -- Xilinx Prim        Q  : out std_logic;
   -- Xilinx Prim        C  : in  std_logic;
   -- Xilinx Prim        CE : in  std_logic;
   -- Xilinx Prim        D  : in  std_logic;
   -- Xilinx Prim        R  : in  std_logic
   -- Xilinx Prim      );
   -- Xilinx Prim    end component FDRE;



-------------------------------------------------------------------------------
begin --(architecture implementation)

  -- Misc assignments
     Control_Done        <= Control_Done_i;
     Control_AlmostDone  <= Control_AlmostDone_i;
     Response_Done       <= Response_Done_i;
     Response_AlmostDone <= Response_AlmostDone_i;
 
   
     Control_Ack <= Target_AddrAck and 
                    not(cntl_done_reg);

     Response_Ack <= Target_DataAck and 
                     not(resp_done_reg);

   
 
  -- Instantate sample and hold register for the PLB RNW 
   
  I_RNW_S_H_REG : FDRE
    port map(
      Q  =>  rnw_s_h,  
      C  =>  Bus_clk,                
      CE =>  Req_Init,       
      D  =>  RNW,  
      R  =>  Bus_Reset                 
    );


   
        
   ----------------------------------------------------------------------------
   -- Response Data Beat Counter Logic
   ----------------------------------------------------------------------------
          
   resp_db_load_value <=  CONV_STD_LOGIC_VECTOR(Num_Data_Beats, DBEAT_CNTR_SIZE);
   
   
   
   resp_db_cnten <= Target_DataAck and 
                    not(Response_Done_i);
                    
                    
   
    
   RESPONSE_DBEAT_CNTR_I :  entity proc_common_v2_00_a.pf_counter_top
      generic map(
        C_COUNT_WIDTH => DBEAT_CNTR_SIZE
        )  
      port map(
        Clk           =>  Bus_clk,              -- : in  std_logic;
        Rst           =>  Bus_reset,            -- : in  std_logic;  
        Load_Enable   =>  Req_Init,             -- : in  std_logic;
        Load_value    =>  resp_db_load_value,   -- : in  std_logic_vector(0 to C_COUNT_WIDTH-1);
        Count_Down    =>  resp_db_cnten,        -- : in  std_logic;
        Count_Up      =>  LOGIC_LOW,            -- : in  std_logic;
        Count_Out     =>  resp_dbeat_count      -- : out std_logic_vector(0 to C_COUNT_WIDTH-1)
        );
   
   
   Response_Done_i <= '1'
      When  (resp_dbeat_count = CYCLE_CNT_ZERO and
             Indet_Burst = '0')
      Else '0';
   
   Response_AlmostDone_i <= '1'
      When  (resp_dbeat_count = CYCLE_CNT_ONE and
             Indet_Burst = '0')
      Else '0';
   
  
  
   
   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: REG_RESP_DONE_STATUS
   --
   -- Process Description:
   -- This process registers the response cycle done signal
   --
   -------------------------------------------------------------
   REG_RESP_DONE_STATUS : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           if (bus_reset = '1' or 
               Req_Init = '1' or
               Indet_Burst = '1') then

             resp_done_reg <= '0';
            
           else

             resp_done_reg <=  Response_Done_i and 
                               Target_DataAck;                 
             
           end if;        
        else
          null;
        end if;
      end process REG_RESP_DONE_STATUS; 
   









   
   ----------------------------------------------------------------------------
   -- Control Data Beat Counter Logic
   ----------------------------------------------------------------------------
  
   
   cntl_db_load_value <=  CONV_STD_LOGIC_VECTOR(Num_Data_Beats, DBEAT_CNTR_SIZE);
   
   
   cntl_db_cnten    <= Target_AddrAck and 
                       not(Control_Done_i);
                       
   cntl_cntup       <= WrBuf_wen
                       when (Indet_Burst = '1' and
                             rnw_s_h     = '0')
                       Else LOGIC_LOW;
   
   
   CONTROL_DBEAT_CNTR_I :  entity proc_common_v2_00_a.pf_counter_top
      generic map(
        C_COUNT_WIDTH => DBEAT_CNTR_SIZE
        )  
      port map(
        Clk           =>  Bus_clk,              -- : in  std_logic;
        Rst           =>  Bus_reset,            -- : in  std_logic;  
        Load_Enable   =>  Req_Init,             -- : in  std_logic;
        Load_value    =>  cntl_db_load_value,   -- : in  std_logic_vector(0 to C_COUNT_WIDTH-1);
        Count_Down    =>  cntl_db_cnten,        -- : in  std_logic;
        --Count_Up      =>  LOGIC_LOW,          -- : in  std_logic;
        Count_Up      =>  cntl_cntup,           -- : in  std_logic;
        Count_Out     =>  cntl_dbeat_count      -- : out std_logic_vector(0 to C_COUNT_WIDTH-1)
        );
   
   
   Control_Done_i <= '1'
      When  (cntl_dbeat_count = CYCLE_CNT_ZERO and
             Indet_Burst = '0') or
            (cntl_dbeat_count = CYCLE_CNT_ZERO and
             Indet_Burst = '1' and
             rnw_s_h     = '0')
      Else '0';
   
   Control_AlmostDone_i <= '1'
      When  (cntl_dbeat_count = CYCLE_CNT_ONE and
             Indet_Burst = '0') or
            (cntl_dbeat_count = CYCLE_CNT_ONE and
             Indet_Burst = '1' and
             rnw_s_h     = '0')
      Else '0';
   
   
   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: REG_CNTL_DONE_STATUS
   --
   -- Process Description:
   -- This process registers the control cycle done signal
   --
   -------------------------------------------------------------
   REG_CNTL_DONE_STATUS : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           
           if (bus_reset   = '1'  or 
               Req_Init    = '1'  or
               Indet_Burst = '1') then

             cntl_done_reg <= '0';
             
           else
              
              cntl_done_reg <= Control_Done_i and 
                               Target_AddrAck;
           
           end if;        
        else
          null;
        end if;
      end process REG_CNTL_DONE_STATUS; 
   





end implementation;
