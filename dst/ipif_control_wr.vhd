-------------------------------------------------------------------------------
-- $Id: ipif_control_wr.vhd,v 1.6 2006/02/14 19:36:52 dougt Exp $
-------------------------------------------------------------------------------
--ipif_control_wr.vhd
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
-- Filename:        ipif_control_wr.vhd
--
-- Description:     This VHDL design file is for the Point Design of the Mauna
--                  Loa Write Packet FIFO IPIF Local Bus Interface control 
--                  block.
--
-------------------------------------------------------------------------------
-- Structure:   
--              
--              
--
--              ipif_control_wr.vhd
--                  
--                  
--                  
--                  
--                  
--                  
--
-------------------------------------------------------------------------------
-- Author:      Doug Thorpe
--
-- History:
--  Doug Thorpe   April 5, 2001      -- V1.00a
--
--  DET  June 25, 2001   V1.00b
--                    - eliminated redundant logic warnings during synthesis
--
--
-- DET  July 20, 2001
--      - Changed the C_MIR_ENABLE type to Boolean from std_logic.
--
-- DET  Sept. 4, 2001
--      - Optimization changes and clean up
--
--
--
-- DET      Feb-11-2002
--          - Changed FIFO read/write data position to be on MS Bytes of bus
--
--
--     DET     12/20/2002     V200a
-- ~~~~~~
--     - Bus Width Matching modifications
-- ^^^^^^
--
--
--     DET     11/7/2003     v2.00.a
-- ~~~~~~
--     - Modified register interface to leverage 64 bit wide data port with
--       the IPIF.
-- ^^^^^^
--     GAB     2/10/2006     v2.00.a
-- ~~~~~~
--     - Fixed issue where a write to the RESET register caused an error
--      to be generated when the bus width configuration was set to 64.
--     - Fixed issue where a write to the STATUS register also reset the FIFO
--      when the bus width configuration was set to 64.
--     - Added changelog entry
-- ^^^^^^
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
-- Library definitions

library ieee;
use ieee.std_logic_1164.all;

library ieee;
use ieee.std_logic_arith.all;


-------------------------------------------------------------------------------

entity ipif_control_wr is
  Generic (
           C_MIR_ENABLE    : Boolean := true;            
                -- Enable for MIR synthesis (default for disable)
                
           C_BLOCK_ID      : integer range 0 to 255 := 255; 
                -- Platform Generator assigned ID number
                
           C_INTFC_TYPE    : integer range 0 to 31  := 1; 
                -- IPIF block protocol Type 
                
           C_VERSION_MAJOR : integer range 0 to 9   := 9; 
                -- Major versioning of top level design
                
           C_VERSION_MINOR : integer range 0 to 99  := 99; 
                -- Minor Version of top level design
                
           C_VERSION_REV   : integer range 0 to 25  := 0;  
                -- Revision letter of top level design
          
           C_FIFO_WIDTH         : Integer := 32;     
                -- Width of FIFO data in bits
           
           C_DP_ADDRESS_WIDTH   : Integer := 9;              
                    -- Indicates address width of RdFIFO memory
                    -- (= log2(fifo_depth)
                    
           C_SUPPORT_BURST      : Boolean := true;
                    -- Indicates write burst support for the IPIF bus
                    
           C_IPIF_DBUS_WIDTH : Integer := 32
                -- Width of the IPIF data bus in bits
          ); 
  port (
  
  -- Inputs From the IPIF Bus 
    Bus_rst             : In  std_logic;  -- Master Reset from the IPIF
    Bus_clk             : In  std_logic;  -- Master timing clock from the IPIF
    Bus_RdReq           : In  std_logic;
    Bus_WrReq           : In  std_logic;
    Bus_Burst           : In  std_logic;
    Bus_BE              : In  std_logic_vector(0 to (C_IPIF_DBUS_WIDTH/8)-1);
    Bus2FIFO_RdCE1      : In  std_logic;
    Bus2FIFO_RdCE2      : In  std_logic;
    Bus2FIFO_RdCE3      : In  std_logic;
    Bus2FIFO_WrCE1      : In  std_logic;
    Bus2FIFO_WrCE2      : In  std_logic;
    Bus2FIFO_WrCE3      : In  std_logic;
    Bus_DBus            : In  std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
    
  -- Inputs from the FIFO Interface Logic
    Fifo_WrAck          : In  std_logic;
    Vacancy             : In  std_logic_vector(0 to C_DP_ADDRESS_WIDTH);
    AlmostFull          : In  std_logic;
    Full                : In  std_logic;
    Deadlock            : In  std_logic;

  -- Outputs to the FIFO
    Fifo_wr_data        : Out std_logic_vector(0 to C_FIFO_WIDTH-1);
    Fifo_Reset          : Out std_logic;
    Fifo_WrReq          : Out std_logic;
    Fifo_burst_wr_xfer  : Out std_logic;
    
  -- Outputs to the IPIF Bus 
    FIFO2IRPT_DeadLock  : Out std_logic;
    FIFO2Bus_DBus       : Out std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
    FIFO2Bus_WrAck      : Out std_logic;
    FIFO2Bus_RdAck      : Out std_logic;
    FIFO2Bus_Error      : Out std_logic;
    FIFO2Bus_Retry      : Out std_logic;
    FIFO2Bus_ToutSup    : Out std_logic
    
    );
  end ipif_control_wr ;

-------------------------------------------------------------------------------

architecture implementation of ipif_control_wr is

    

 -- Functions
 
  
   -----------------------------------------------------------------------------
   -- Function set_fwidth
   --
   -- This function is used to set the value of FIFO width status 
   -- field based on the setting of the width parameter.
   -----------------------------------------------------------------------------
    function set_fwidth (fifo_width : integer) return integer is

       
       
       constant byte_lane_num : Integer := (fifo_width+7)/8;
       Variable enc_size      : Integer := 0;
       
    begin

       case byte_lane_num is
         when 0|1 =>
             enc_size := 1;
         when 2 =>
             enc_size := 2;
         when 3 | 4 =>
             enc_size := 3;
         when 5|6|7|8 =>
             enc_size := 4;
         When 9|10|11|12|13|14|15|16 =>
             enc_size := 5;
         when others =>
             enc_size := 6;
       end case;
              
       return(enc_size);
                     
    end function set_fwidth;

       
    
    -------------------------------------------------------------------
    -- Function
    --
    -- Function Name: limit_the_value
    --
    -- Function Description:
    -- Simple function that clips the input_val to the limit_val.
    --
    -------------------------------------------------------------------
    function limit_the_value (input_val   : integer;
                              limit_value : integer)
                              return integer is
    
        Variable result : Integer := 0;
    
    begin
    
      
      if (input_val > limit_value) then
      
         result := limit_value;
      
      else
      
         result := input_val;
      
      end if;
       
         return(result); 
          
    end function limit_the_value;
     
     


--TYPES
    
     Type byte_reg_type is array(0 to (C_IPIF_DBUS_WIDTH/8)-1) of std_logic_vector(0 to 7);
  
  
-- CONSTANTS
 
  
     Constant NATIVE_REG_WIDTH : integer := 32;
     Constant REG_DWIDTH       : integer := limit_the_value(C_IPIF_DBUS_WIDTH,
                                                            NATIVE_REG_WIDTH);
     
    
    
    -- Module Software Reset key value for write data
     Constant RESET_MATCH : std_logic_vector(0 to 3) := "1010"; 
                -- This requires a Hex 'A' to be written
                -- to activate the S/W reset port
  
 
    -- general use constants 
     Constant LOGIC_LOW          : std_logic := '0';
     Constant LOGIC_HIGH         : std_logic := '1';
  
  
    -- Bus Width Matching constant
     Constant ENC_FIFO_WIDTH : integer := set_fwidth(C_FIFO_WIDTH);
     
     Constant BE_TRIG_NUM : integer := ((C_FIFO_WIDTH+7)/8)-1;
  
  
  

--INTERNAL SIGNALS
 
     signal  bus_data_out        : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
     --signal  mir_value           : std_logic_vector(0 to 31);
     Signal  sw_reset_error      : std_logic;
     signal  reg_vacancy         : std_logic_vector(0 to C_DP_ADDRESS_WIDTH);
     Signal  reg_almostfull      : std_logic;                   
     Signal  reg_full            : std_logic;                   
     Signal  reg_deadlock        : std_logic;                   
     Signal  reg_rdce1           : std_logic;                   
     Signal  reg_rdce2           : std_logic;                   
     Signal  reg_rdce3           : std_logic;                   
     Signal  reg_wrce1           : std_logic;                   
     Signal  reg_wrce2           : std_logic;                   
     Signal  reg_wrce3           : std_logic;                   
     Signal  reg_wrreq           : std_logic;                   
     Signal  reg_rdreq           : std_logic;                   
     Signal  read_ack            : std_logic;
     Signal  reg_read_ack        : std_logic;
     Signal  write_ack           : std_logic;
     Signal  rd_access_error     : std_logic;
     Signal  wr_access_error     : std_logic;
     --Signal  burst_wr_xfer       : std_logic;
     Signal  read_req            : std_logic;
     Signal  reg_read_req        : std_logic;
     Signal  write_req           : std_logic;
     Signal  reg_write_req       : std_logic;
     Signal  fifo_errack_inhibit : std_logic;
     Signal  rd_vect             : std_logic_vector(0 to 3);
                                                   
     Signal  sig_rst_match       : std_logic;
--     Signal  sig_rst_vect        : std_logic_vector(0 to 1);  --GAB 2/10/06 
     Signal  sig_rst_vect        : std_logic_vector(0 to 2);
     Signal  sig_fifo_wr_data    : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
     
     Signal  write_data_reg      : byte_reg_type; -- array of bytes
     Signal  write_req_trig      : std_logic;
     Signal  write_req_trig_dly1 : std_logic;
    
     Signal  going_full_ccase    : std_logic; -- corner case going full
     

-------------------------------------------------------------------------------
--------------------- start architecture logic --------------------------------
  
begin
      
      
  -- General access detection (used to terminate reply signal to the Bus)
  
   read_req           <=  (Bus2FIFO_RdCE1 or Bus2FIFO_RdCE2 or Bus2FIFO_RdCE3);
   
   write_req          <=  (Bus2FIFO_WrCE1 or Bus2FIFO_WrCE2 or Bus2FIFO_WrCE3);
   
   
  
  -- I/O assignments
   FIFO2Bus_DBus      <=  bus_data_out;
      
   FIFO2Bus_ToutSup   <=  LOGIC_LOW;  
                -- This output signal not currently used so 
                -- drive it low.
                                      
   FIFO2Bus_Retry     <=  LOGIC_LOW;  
                -- This output signal not currently used so
                -- drive it low.
                                      
   FIFO2Bus_WrAck     <=  write_ack and 
                          write_req and 
                          not(going_full_ccase); 
                -- Connect the write acknowledge (drive only if a 
                -- request is present)
                
   FIFO2Bus_RdAck     <=  read_ack and read_req;  
                -- Connect the read acknowledge (drive only if
                -- a request is present)                                  
                                                       
    
   FIFO2Bus_Error     <=  (sw_reset_error or       
                           rd_access_error or     
                           wr_access_error) and 
                           (read_req or write_req);
                           
   FIFO2IRPT_DeadLock <=  Deadlock;
   
   -- Fifo_WrReq         <=  Bus2FIFO_WrCE3 and Bus_WrReq;  
   --              -- Write Request to FIFO read controller
                
   
   Fifo_WrReq         <=  write_req_trig;
   
   
   
   -- Fifo_burst_wr_xfer <=  burst_wr_xfer;   
   --              -- Burst detect signal to FIFO read controller
   
   Fifo_burst_wr_xfer <=  Bus_Burst;
   
   
   
                
   -- sig_fifo_wr_data   <=   Bus_DBus;
   
   
   
   
   
   
-------------------------------------------------------------------------------                                                    

   
-------------------------------------------------------------------------------
-- The FIFO data bus width is smaller than the IPIF data bus width so connect 
-- the smaller FIFO data to MSB position of data bus to IPIF interface and
-- set the remaining data bus bits to zeroes.
-------------------------------------------------------------------------------
BUS_BIGGER_THAN_FIFO : if (C_IPIF_DBUS_WIDTH > C_FIFO_WIDTH) generate

   CONNECT_DBUS : process (sig_fifo_wr_data)
     Begin

       
       -- for j in 0 to C_FIFO_WIDTH-1 loop
       --    
       --    fifo_wr_data(j)  <=  sig_fifo_wr_data(C_IPIF_DBUS_WIDTH-
       --                                                       C_FIFO_WIDTH+j);
       --    
       -- End loop;
    
       
        for j in 0 to C_FIFO_WIDTH-1 loop
           
           fifo_wr_data(j)  <=  sig_fifo_wr_data(j);
           
        End loop;
    
     End process; -- CONNECT_DBUS
   
    
end generate BUS_BIGGER_THAN_FIFO;

 

-------------------------------------------------------------------------------
-- The FIFO data bus width is equal to the IPIF data bus width so connect 
-- the FIFO data to IPIF data interface.
-------------------------------------------------------------------------------
BUS_EQUAL_TO_FIFO : if (C_IPIF_DBUS_WIDTH = C_FIFO_WIDTH) generate


    fifo_wr_data <=  sig_fifo_wr_data;


end generate BUS_EQUAL_TO_FIFO; 


 

-------------------------------------------------------------------------------
-- The FIFO data bus width is bigger than the IPIF data bus width !!BAD!!!
-- Connect the LSBits of the FIFO data to the IPIF data bus interface,  
-- Don't use (truncate) the MSBits of the FIFO data spilling over the IPIF 
-- data bus width.
-------------------------------------------------------------------------------
BUS_SMALLER_THAN_FIFO : if (C_IPIF_DBUS_WIDTH < C_FIFO_WIDTH) generate


   CONNECT_DBUS : process (sig_fifo_wr_data)
     Begin
       
       fifo_wr_data <= (others => '0'); --default bus state 

        for j in C_IPIF_DBUS_WIDTH-1 downto 0 loop
         
          fifo_wr_data(C_FIFO_WIDTH-C_IPIF_DBUS_WIDTH+j) 
                                                 <= sig_fifo_wr_data(j);
           
        End loop;
    
     End process; -- CONNECT_DBUS
   

end generate BUS_SMALLER_THAN_FIFO; 

   
   
 ------------------------------------------------------------------------------  
 -- Register the input chip enables     
 ------------------------------------------------------------------------------
 REGISTER_CHIP_ENABLES : process (Bus_rst, Bus_clk)
    Begin
      If (Bus_rst = '1') Then
         reg_rdce1     <= '0';
         reg_rdce2     <= '0';
         reg_rdce3     <= '0';
         reg_wrce1     <= '0';
         reg_wrce2     <= '0';
         reg_wrce3     <= '0';
         reg_rdreq     <= '0';
         reg_wrreq     <= '0';
         reg_read_req  <= '0';
         reg_write_req <= '0';
         
      Elsif (Bus_clk'EVENT and Bus_clk = '1') Then
         reg_rdce1     <= Bus2FIFO_RdCE1;
         reg_rdce2     <= Bus2FIFO_RdCE2;
         reg_rdce3     <= Bus2FIFO_RdCE3;
         reg_wrce1     <= Bus2FIFO_WrCE1;
         reg_wrce2     <= Bus2FIFO_WrCE2;
         reg_wrce3     <= Bus2FIFO_WrCE3;
         reg_rdreq     <= Bus_RdReq;
         reg_read_req  <= read_req;
         reg_wrreq     <= Bus_WrReq;
         reg_write_req <= write_req;
      Else 
         null;
      End if;
    End process; -- REGISTER_CHIP_ENABLES
  
    
 
 
 -------------------------------------------------------------
 -- Synchronous Process with Sync Reset
 --
 -- Label: INPUT_DATA_REG_IMP
 --
 -- Process Description:
 --  This process implements the input write register that is
 -- needed for the Bus Width Matching function.
 --
 -------------------------------------------------------------
 INPUT_DATA_REG_IMP : process (bus_clk)
    begin
      if (Bus_Clk'event and Bus_Clk = '1') then
         if (Bus_Rst = '1') then
          
           for i in 0 to (C_IPIF_DBUS_WIDTH/8)-1 loop

             write_data_reg(i)    <= (others => '0');
                          
           End loop; 
          
        elsif (Bus2FIFO_WrCE3 = '1' and Bus_WrReq = '1') Then
                   
           for i in 0 to (C_IPIF_DBUS_WIDTH/8)-1 loop
   
              If (Bus_BE(i) = '1') Then
   
                 write_data_reg(i) <= Bus_DBus((i*8) to (i*8)+7);
                 
              else

                 null; -- don't change state
                  
              End if;
                          
           End loop; 
        
        else
          Null;  -- don't change state
        End if;
      else
        null;
      end if;
    end process INPUT_DATA_REG_IMP; 



-------------------------------------------------------------
-- Combinational Process
--
-- Label: CONNECT_WR_DATA
--
-- Process Description:
--   This process connects the Write data register output to
-- the write data of the FIFO.
--
-------------------------------------------------------------
CONNECT_WR_DATA : process (write_data_reg)
   begin

     for i in 0 to (C_IPIF_DBUS_WIDTH/8)-1 loop

       sig_fifo_wr_data((i*8) to (i*8)+7) <= write_data_reg(i);
                    
     End loop; 

   end process CONNECT_WR_DATA; 

            


-------------------------------------------------------------
-- Synchronous Process with Sync Reset
--
-- Label: FIFO_WR_GEN
--
-- Process Description:
--  This process generates the write request to the FIFO write
-- controller based on the BE enabled from the Bus.
--
-------------------------------------------------------------
FIFO_WR_GEN : process (bus_clk)
   begin
     if (Bus_Clk'event and Bus_Clk = '1') then
        
        if (Bus_Rst = '1') then
          
           write_req_trig      <= '0';
           write_req_trig_dly1 <= '0';
          
        else
          
          write_req_trig       <= Bus_BE(BE_TRIG_NUM) and  -- the LS FIFO Byte Number
                                  Bus2FIFO_WrCE3 and       -- the FIFO Data Wr CE
                                  Bus_WrReq;               -- Bus Write Request
        
          write_req_trig_dly1  <= write_req_trig;     -- 1 clock delayed 
          
        end if;        
     else
       null;
     end if;
   end process FIFO_WR_GEN; 






-- -------------------------------------------------------------------------------
-- -- Detect a Burst Write Condition (used for reading the FIFO Data)
-- -------------------------------------------------------------------------------  
--  BURST_DETECT : process (Bus_rst, Bus_clk)
--     Begin
--        If (Bus_rst = '1') Then
--          burst_wr_xfer  <=  '0';
--        Elsif (Bus_clk'EVENT and Bus_clk = '1') Then
--          
--          If (reg_wrreq = '1' and Bus_WrReq = '1') Then
--             burst_wr_xfer  <=  '1';
--          Elsif (burst_wr_xfer = '1' and Bus_WrReq = '0') Then
--             burst_wr_xfer  <=  '0';
--          else
--             burst_wr_xfer  <=  '0';
--          End if;
--          
--        else
--           null;
--        End if;
--     End process; -- BURST_DETECT
  
           
 
 
 
            
------------------------------------------------------------------------------- 
-- Assemble and latch the FIFO status register fields
-------------------------------------------------------------------------------
GET_STATUS : process (Bus_rst, Bus_clk)
  Begin
    If (Bus_rst = '1') Then
      reg_vacancy     <= (others => '0');
      reg_deadlock    <= '0';
      reg_almostfull  <= '0';
      reg_full        <= '1';
    Elsif (Bus_clk'EVENT and Bus_clk = '1') Then
      If (reg_rdce2 = '1') Then  -- hold last value registered during read 
                                 -- operation.
         null;
      else                       -- register new status every clock
         reg_vacancy     <=  Vacancy    ; 
         reg_deadlock    <=  Deadlock   ;
         reg_almostfull  <=  AlmostFull ;
         reg_full        <=  Full       ;
      End if;
    else
      null; -- do nothing
    End if;
  
  End process; -- GET_STATUS
      
 
 
      
   
  -- sig_rst_match <= Bus_DBus(C_IPIF_DBUS_WIDTH-4) 
  --                  and not(Bus_DBus(C_IPIF_DBUS_WIDTH-3))
  --                  and Bus_DBus(C_IPIF_DBUS_WIDTH-2)  
  --                  and not(Bus_DBus(C_IPIF_DBUS_WIDTH-1));
  
  
  sig_rst_match <= Bus_DBus(REG_DWIDTH-4) 
                   and not(Bus_DBus(REG_DWIDTH-3))
                   and Bus_DBus(REG_DWIDTH-2)  
                   and not(Bus_DBus(REG_DWIDTH-1));
  
-- GAB 2/10/06 Qualified sig_rst_vect with BE's to prevent a 
-- fifo reset when a write occurs to the Status Register when
-- C_IPIF_DBUS_WIDTH = 64
--  sig_rst_vect  <= sig_rst_match & Bus2FIFO_WrCE1;
  sig_rst_vect  <= sig_rst_match & Bus2FIFO_WrCE1 & Bus_BE(3);
  
 ------------------------------------------------------------------------------
 -- Generate the S/W reset as a result of an IPIF Bus write to register
 -- port 1 and data on the DBus inputs matching the Reset match value.
 ------------------------------------------------------------------------------     
 GENERATE_SOFTWARE_RESET : process (Bus_rst, Bus_Clk)
   Begin
      If (Bus_rst = '1') Then
         FIFO_Reset     <= '1';
         sw_reset_error <= '0';
      Elsif (Bus_Clk'EVENT and Bus_Clk = '1') Then
      
          Case sig_rst_vect Is
--            When "11" =>   --GAB 2/10/06 (see comments above on sig_rst_vect)
            When "111" => 
               FIFO_Reset     <= '1'; 
               sw_reset_error <= '0'; 
--            When "01" =>   --GAB 2/10/06 (see comments above on sig_rst_vect)
            When "011" => 
               FIFO_Reset     <= '0'; 
               sw_reset_error <= '1'; 
            When others   => 
              FIFO_Reset     <= '0';
              sw_reset_error <= '0';
          End case;
      
      Else 
         null;
      End if;
   End process; -- GENERATE_SOFTWARE_RESET
 
  
 
  
  
-- Synthesis for MIR inclusion ------------------------------------------------


   Include_MIR :if (C_MIR_ENABLE = True) generate

      signal  mir_value   : std_logic_vector(0 to 31);
      -- Signal  mir_bus     : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
      -- Signal  status_bus  : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
     Signal  mir_bus     : std_logic_vector(0 to REG_DWIDTH-1);
     Signal  status_bus  : std_logic_vector(0 to REG_DWIDTH-1);


   begin

      ------------------------------------------------------------------------- 
      -- assemble the MIR fields from the Applicable Generics and Constants
      -- conversion to std_logic_vector required
      -------------------------------------------------------------------------
      mir_value(0 to 3)       <= CONV_STD_LOGIC_VECTOR(C_VERSION_MAJOR, 4);
      mir_value(4 to 10)      <= CONV_STD_LOGIC_VECTOR(C_VERSION_MINOR, 7);
      mir_value(11 to 15)     <= CONV_STD_LOGIC_VECTOR(C_VERSION_REV, 5);
      mir_value(16 to 23)     <= CONV_STD_LOGIC_VECTOR(C_BLOCK_ID, 8); 
      mir_value(24 to 31)     <= CONV_STD_LOGIC_VECTOR(C_INTFC_TYPE, 8);
      
         
         
      mir_bus <=  mir_value(0 to REG_DWIDTH-1);
         
         
      -- -------------------------------------------------------------------------
      -- -- If the IPIF read data bus width is less than or equal to the MIR value  
      -- -- size (32bits), then populate the LS MIR bits that will fit. Truncate 
      -- -- those that will not fit.
      -- -------------------------------------------------------------------------   
      -- BUS_LEQ_32 : if (C_IPIF_DBUS_WIDTH <= 32) generate
      -- 
      --      
      -- begin
      -- 
      --   BUILD_MIR_BUS : process (mir_value)
      --   
      --     Begin
      --   
      --        for j in 0 to (C_IPIF_DBUS_WIDTH-1) loop
      --         
      --           mir_bus(j) <=  mir_value((32-C_IPIF_DBUS_WIDTH)+j);
      --           
      --        End loop;
      --    
      --     End process; -- BUILD_MIR_BUS
      --   
      --   
      --   end generate BUS_LEQ_32; 
      --   
      --   
      --   
      -- -------------------------------------------------------------------------
      -- -- If the IPIF read data bus width is greater than the MIR value size 
      -- -- (32bits), then populate the MIR bits into the MSBits of the bus
      -- -- and zero the remaining LSBits
      -- -------------------------------------------------------------------------   
      -- BUS_GT_32 : if (C_IPIF_DBUS_WIDTH > 32) generate
      -- 
      --      
      -- begin
      -- 
      --    BUILD_MIR_BUS : process (mir_value)
      --      Begin
      -- 
      --         mir_bus <= (others => '0'); -- default bus values
      --             
      --         for j in 0 to 31 loop
      --          
      --            -- mir_bus((C_IPIF_DBUS_WIDTH-32)+j) <=  mir_value(j);
      --            mir_bus(j) <=  mir_value(j);
      --            
      --         End loop;
      --     
      --      End process; -- BUILD_MIR_BUS
      --    
      -- 
      -- end generate BUS_GT_32; 

   
  
--       ----------------------------------------------------------------------------
--       -- The IPIF DBUS is larger than 32 bits in width. Place the 32 bit status
--       -- word on the 32 MS Bits of the data bus.
--       -- Do not scale the vacancy value down.
--       -- Note status_bus bit 3 is not set, signaling a complete vacancy value.
--       ----------------------------------------------------------------------------
--       BUILD_STATUS_BIG : if (C_IPIF_DBUS_WIDTH >= 32) generate
--
--
--       begin
--
--          BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
--                                      reg_vacancy)
--            Begin
--
--               -- set default Status Register values
--               status_bus <= (others => '0');
--
--               -- set Encoded FIFO data width
--               status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
--
--               -- Set Vacancy is not scaled in this case.
--               status_bus(3)        <=  '0';
--
--
--               -- Echo remaining status
--               status_bus(2)        <=  reg_deadlock   ;
--               status_bus(1)        <=  reg_almostfull ;
--               status_bus(0)        <=  reg_full      ;
--
--
--               for j in 0 to C_DP_ADDRESS_WIDTH loop
--
--                  status_bus((32-(C_DP_ADDRESS_WIDTH+1))+j)
--                         <=  reg_vacancy(j);
--
--               End loop;
--
--            End process; -- BUILD_STATUS_BUS
--
--
--       end generate BUILD_STATUS_BIG;
--
--
--       ----------------------------------------------------------------------------
--       -- The IPIF DBUS is of sufficient width to contain the complete status
--       -- information so do not scale the vacancy value down.
--       -- Note status_bus bit 3 is not set, signaling a complete vacancy value.
--       ----------------------------------------------------------------------------
--       BUILD_STATUS_FIT : if (C_IPIF_DBUS_WIDTH >= C_DP_ADDRESS_WIDTH+7
--                              and C_IPIF_DBUS_WIDTH < 32) generate
--
--
--       begin
--
--          BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
--                                      reg_vacancy)
--            Begin
--
--               -- set default Status Register values
--               status_bus <= (others => '0');
--
--               -- set Encoded FIFO data width
--               status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
--
--               -- Set Vacancy is not scaled in this case.
--               status_bus(3)        <=  '0';
--
--
--               -- Echo remaining status
--               status_bus(2)        <=  reg_deadlock   ;
--               status_bus(1)        <=  reg_almostfull ;
--               status_bus(0)        <=  reg_full      ;
--
--
--               for j in C_DP_ADDRESS_WIDTH downto 0 loop
--
--                  status_bus((C_IPIF_DBUS_WIDTH-1)-(C_DP_ADDRESS_WIDTH-j))
--                         <=  reg_vacancy(j);
--
--               End loop;
--
--            End process; -- BUILD_STATUS_BUS
--
--
--       end generate BUILD_STATUS_FIT;
--
--
--
--       ----------------------------------------------------------------------------
--       -- The IPIF DBUS is too narrow to contain the complete status information so
--       -- scale the vacancy value down until it fits in the available space.
--       -- Note status_bus bit 3 is now set, signaling a scaled vacancy value.
--       ----------------------------------------------------------------------------
--       BUILD_STATUS_NO_FIT : if (C_IPIF_DBUS_WIDTH < C_DP_ADDRESS_WIDTH+7) generate
--
--          constant OCC_INDEX_END : Integer := (C_IPIF_DBUS_WIDTH-7)-1;
--
--       begin
--
--
--          BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
--                                      reg_vacancy)
--            Begin
--
--               -- set default Status Register values
--               status_bus <= (others => '0');
--
--               -- set Encoded FIFO data width
--               status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
--
--               -- Set Vacancy is scaled in this case.
--               status_bus(3)        <=  '1';
--
--
--               -- Echo remaining status
--               status_bus(2)        <=  reg_deadlock   ;
--               status_bus(1)        <=  reg_almostfull ;
--               status_bus(0)        <=  reg_full      ;
--
--
--               for j in 0 to OCC_INDEX_END loop
--
--                  status_bus((C_IPIF_DBUS_WIDTH-1)-OCC_INDEX_END+j)
--                         <=  reg_vacancy(j);
--
--               End loop;
--
--            End process; -- BUILD_STATUS_BUS
--
--
--       end generate BUILD_STATUS_NO_FIT;
--
      
   ----------------------------------------------------------------------------
   -- The IPIF DBUS is larger than 32 bits in width. Place the 32 bit status
   -- word on the 32 MSBits of the data bus. 
   -- Do not scale the vacancy value down.
   -- Note status_bus bit 3 is not set, signaling a complete vacancy value.
   ----------------------------------------------------------------------------
   BUILD_STATUS_32BIT : if (REG_DWIDTH = 32) generate
  
   
   begin
       
      BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
                                  reg_vacancy)
        Begin
   
           
           -- set default Status Register values
           status_bus <= (others => '0'); 
               
           -- set Encoded FIFO data width
           status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
           
           -- Set Vacancy as not scaled in this case
           status_bus(3)        <=  '0'; 
                    
           -- Echo remaining status
           status_bus(2)        <=  reg_deadlock   ; 
           status_bus(1)        <=  reg_almostfull ; 
           status_bus(0)        <=  reg_full       ;
           
                      
           for j in 0 to C_DP_ADDRESS_WIDTH loop
            
              status_bus((32-(C_DP_ADDRESS_WIDTH+1))+j) 
                     <=  reg_vacancy(j);
              
           End loop;
       
        End process; -- BUILD_STATUS_BUS

  
   end generate BUILD_STATUS_32BIT; 
  
  
   
   ----------------------------------------------------------------------------
   -- The IPIF DBUS is of sufficient width to contain the complete status 
   -- information so do not scale the Vacancy value down.
   -- Note status_bus bit 3 is not set, signaling a complete Vacancy value.
   ----------------------------------------------------------------------------
   BUILD_STATUS_FIT : if (REG_DWIDTH >= C_DP_ADDRESS_WIDTH+7
                          and REG_DWIDTH < 32) generate
  
   
   begin
       
      BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
                                  reg_vacancy)
        Begin
   
           -- set default Status Register values
           status_bus <= (others => '0'); 
               
           -- set Encoded FIFO data width
           status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
           
           -- Set Vacancy as not scaled in this case
           status_bus(3)        <=  '0'; 
           
           -- Echo remaining status
           status_bus(2)        <=  reg_deadlock   ; 
           status_bus(1)        <=  reg_almostfull; 
           status_bus(0)        <=  reg_full      ;
           
           
           for j in C_DP_ADDRESS_WIDTH downto 0 loop
            
              status_bus((REG_DWIDTH-1)-(C_DP_ADDRESS_WIDTH-j)) 
                     <=  reg_vacancy(j);
              
           End loop;
       
        End process; -- BUILD_STATUS_BUS

  
   end generate BUILD_STATUS_FIT; 
  
  
  
   ----------------------------------------------------------------------------
   -- The IPIF DBUS is too narrow to contain the complete status information so
   -- scale the Vacancy value down until it fits in the available space.
   -- Note status_bus bit 3 is now set, signaling a scaled Vacancy value.
   ----------------------------------------------------------------------------
   BUILD_STATUS_NO_FIT : if (REG_DWIDTH < C_DP_ADDRESS_WIDTH+7
                          and REG_DWIDTH < 32) generate
  
      constant VAC_INDEX_END : Integer := (REG_DWIDTH-7)-1;
      
   begin
      
      
      BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
                                  reg_vacancy)
        Begin
   
           -- set default Status Register values
           status_bus <= (others => '0'); 
               
           -- set Encoded FIFO data width
           status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
           
           -- Set Vacancy as scaled in this case
           status_bus(3)        <=  '1'; 
           
           -- Echo remaining status
           status_bus(2)        <=  reg_deadlock   ; 
           status_bus(1)        <=  reg_almostfull; 
           status_bus(0)        <=  reg_full      ;
           
           
           for j in 0 to VAC_INDEX_END loop
            
              status_bus((REG_DWIDTH-1)-VAC_INDEX_END+j) 
                     <=  reg_vacancy(j);
              
           End loop;
       
        End process; -- BUILD_STATUS_BUS

  
   end generate BUILD_STATUS_NO_FIT; 
  
  
      
      
        
    -- ----------------------------------------------------------------------------      
    -- -- Mux the three read data sources to the IPIF Local Bus output port during
    -- -- reads.
    -- ----------------------------------------------------------------------------      
    -- MUX_THE_OUTPUT_DATA : process (Bus2FIFO_RdCE3, Bus2FIFO_RdCE2, 
    --                                Bus2FIFO_RdCE1, mir_bus, status_bus,
    --                                rd_vect, reg_read_req)
    --   Begin
    --     
    --     rd_vect <=  reg_read_req   & Bus2FIFO_RdCE3 & 
    --                 Bus2FIFO_RdCE2 & Bus2FIFO_RdCE1;
    --     
    --     Case rd_vect Is
    -- 
    --       When "1001" =>  -- Read MIR port
    --       
    --           bus_data_out <=  mir_bus;
    -- 
    --       When "1010" =>  -- Read Status port
    --           
    --           bus_data_out <= status_bus;
    --            
    --       When others   =>  -- default to zeroes
    --          bus_data_out <=  (others => '0');
    --          
    --     End case;
    --     
    --   End process; -- MUX_THE_OUTPUT_DATA
        
 
    ------------------------------------------------------------
    -- If Generate
    --
    -- Label: READ_MUX_64BIT
    --
    -- If Generate Description:
    -- This IFGen builds the read mux when the Bus data width is
    -- 64 bits.
    --
    --
    ------------------------------------------------------------
    READ_MUX_64BIT : if (C_IPIF_DBUS_WIDTH = 64) generate
    
       -- Local Constants
       -- Local variables
       -- local signals
       -- local components
    
       begin
    
         ----------------------------------------------------------------------------      
         -- Mux the three read data sources to the IPIF Local Bus output port during
         -- reads.
         ----------------------------------------------------------------------------      
         MUX_THE_OUTPUT_DATA : process (Bus2FIFO_RdCE3, 
                                        --Bus2FIFO_RdCE2, 
                                        Bus2FIFO_RdCE1, 
                                        mir_bus, status_bus, 
                                        rd_vect, reg_read_req)
           Begin
             
             rd_vect <=  reg_read_req   & 
                         Bus2FIFO_RdCE3 &
                         '0' & 
                         --Bus2FIFO_RdCE2 &
                         Bus2FIFO_RdCE1;
             
             Case rd_vect Is

               When "1001" =>  -- Read MIR and status port
               
                   bus_data_out(0 to 31)  <= mir_bus;
                   bus_data_out(32 to 63) <= status_bus;
         
               When others   =>  -- default to zeroes
               
                   bus_data_out <=  (others => '0');
                  
             End case;
             
           End process; -- MUX_THE_OUTPUT_DATA
          
          
       end generate READ_MUX_64BIT;
     
     
     
    ------------------------------------------------------------
    -- If Generate
    --
    -- Label: READ_MUX_SMALL
    --
    -- If Generate Description:
    -- This IFGen builds the read mux when the Bus data width is
    -- 32 bits or less.
    --
    --
    ------------------------------------------------------------
    READ_MUX_SMALL : if (C_IPIF_DBUS_WIDTH <= 32) generate
    
       -- Local Constants
       -- Local variables
       -- local signals
       -- local components
    
       begin
    
         ----------------------------------------------------------------------------      
         -- Mux the three read data sources to the IPIF Local Bus output port during
         -- reads.
         ----------------------------------------------------------------------------      
         MUX_THE_OUTPUT_DATA : process (Bus2FIFO_RdCE3, 
                                        Bus2FIFO_RdCE2, 
                                        Bus2FIFO_RdCE1, 
                                        mir_bus, status_bus, 
                                        rd_vect, reg_read_req)
           Begin
             
             rd_vect <=  reg_read_req   & 
                         Bus2FIFO_RdCE3 & 
                         Bus2FIFO_RdCE2 &
                         Bus2FIFO_RdCE1;
             
             Case rd_vect Is

               When "1001" =>  -- Read MIR port
               
                   bus_data_out <= mir_bus;
                   
               When "1010" =>  -- Read status port
               
                   bus_data_out <= status_bus;
         
               When others   =>  -- default to zeroes
               
                   bus_data_out <=  (others => '0');
                  
             End case;
             
           End process; -- MUX_THE_OUTPUT_DATA
          
          
       end generate READ_MUX_SMALL;
     
  
 
      
      
      ----------------------------------------------------------------------------
      -- Generate the Read Error Acknowledge Reply to the Bus when
      -- an attempted read access by the IPIF Local Bus is invalid
      ----------------------------------------------------------------------------  
      GEN_RD_ERROR : process (Bus_rst, Bus_clk)
          Begin
            
             If (Bus_rst = '1') Then
               rd_access_error   <= '0';  
             Elsif (Bus_clk'EVENT and Bus_clk = '1') Then
                
                If (Bus2FIFO_RdCE3 = '1') Then  -- attempting a read of the FIFO  
                                                -- data through the data write 
                  rd_access_error <= '1';       -- port. This is always an error. 
                                                
                Else                                                                            
                  rd_access_error <= '0';                                                       
                End if;
                
             Else 
                null;
             End if;
             
       End process; -- GEN_RD_ERROR
      
 
   end generate Include_MIR;   
          
                        
                        
                        
-- Synthesis for MIR occlusion ------------------------------------------------
   Occlude_MIR : if (C_MIR_ENABLE = False) generate
   
        Signal  status_bus  : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1);
   
   begin
      
--       ----------------------------------------------------------------------------
--       -- The IPIF DBUS is larger than 32 bits in width. Place the 32 bit status
--       -- word on the 32 MS Bits of the data bus.
--       -- Do not scale the vacancy value down.
--       -- Note status_bus bit 3 is not set, signaling a complete vacancy value.
--       ----------------------------------------------------------------------------
--       BUILD_STATUS_BIG : if (C_IPIF_DBUS_WIDTH >= 32) generate
--
--
--       begin
--
--          BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
--                                      reg_vacancy)
--            Begin
--
--               -- set default Status Register values
--               status_bus <= (others => '0');
--
--               -- set Encoded FIFO data width
--               status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
--
--               -- Set Vacancy is not scaled in this case.
--               status_bus(3)        <=  '0';
--
--
--               -- Echo remaining status
--               status_bus(2)        <=  reg_deadlock   ;
--               status_bus(1)        <=  reg_almostfull ;
--               status_bus(0)        <=  reg_full      ;
--
--
--               for j in 0 to C_DP_ADDRESS_WIDTH loop
--
--                  status_bus((32-(C_DP_ADDRESS_WIDTH+1))+j)
--                         <=  reg_vacancy(j);
--
--               End loop;
--
--            End process; -- BUILD_STATUS_BUS
--
--
--       end generate BUILD_STATUS_BIG;
--
--
--       ----------------------------------------------------------------------------
--       -- The IPIF DBUS is of sufficient width to contain the complete status
--       -- information so do not scale the vacancy value down.
--       -- Note status_bus bit 3 is not set, signaling a complete vacancy value.
--       ----------------------------------------------------------------------------
--       BUILD_STATUS_FIT : if (C_IPIF_DBUS_WIDTH >= C_DP_ADDRESS_WIDTH+7
--                              and C_IPIF_DBUS_WIDTH < 32) generate
--
--
--       begin
--
--          BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
--                                      reg_vacancy)
--            Begin
--
--               -- set default Status Register values
--               status_bus <= (others => '0');
--
--               -- set Encoded FIFO data width
--               status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
--
--               -- Set Vacancy is not scaled in this case.
--               status_bus(3)        <=  '0';
--
--
--               -- Echo remaining status
--               status_bus(2)        <=  reg_deadlock   ;
--               status_bus(1)        <=  reg_almostfull ;
--               status_bus(0)        <=  reg_full      ;
--
--
--               for j in C_DP_ADDRESS_WIDTH downto 0 loop
--
--                  status_bus((C_IPIF_DBUS_WIDTH-1)-(C_DP_ADDRESS_WIDTH-j))
--                         <=  reg_vacancy(j);
--
--               End loop;
--
--            End process; -- BUILD_STATUS_BUS
--
--
--       end generate BUILD_STATUS_FIT;
--
--
--
--       ----------------------------------------------------------------------------
--       -- The IPIF DBUS is too narrow to contain the complete status information so
--       -- scale the vacancy value down until it fits in the available space.
--       -- Note status_bus bit 3 is now set, signaling a scaled vacancy value.
--       ----------------------------------------------------------------------------
--       BUILD_STATUS_NO_FIT : if (C_IPIF_DBUS_WIDTH < C_DP_ADDRESS_WIDTH+7) generate
--
--          constant OCC_INDEX_END : Integer := (C_IPIF_DBUS_WIDTH-7)-1;
--
--       begin
--
--
--          BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
--                                      reg_vacancy)
--            Begin
--
--               -- set default Status Register values
--               status_bus <= (others => '0');
--
--               -- set Encoded FIFO data width
--               status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
--
--               -- Set Vacancy is scaled in this case.
--               status_bus(3)        <=  '1';
--
--
--               -- Echo remaining status
--               status_bus(2)        <=  reg_deadlock   ;
--               status_bus(1)        <=  reg_almostfull ;
--               status_bus(0)        <=  reg_full      ;
--
--
--               for j in 0 to OCC_INDEX_END loop
--
--                  status_bus((C_IPIF_DBUS_WIDTH-1)-OCC_INDEX_END+j)
--                         <=  reg_vacancy(j);
--
--               End loop;
--
--            End process; -- BUILD_STATUS_BUS
--
--
--       end generate BUILD_STATUS_NO_FIT;
--



     
   ----------------------------------------------------------------------------
   -- The IPIF DBUS is larger than 32 bits in width. Place the 32 bit status
   -- word on the 32 MSBits of the data bus. 
   -- Do not scale the vacancy value down.
   -- Note status_bus bit 3 is not set, signaling a complete vacancy value.
   ----------------------------------------------------------------------------
   BUILD_STATUS_32BIT : if (REG_DWIDTH = 32) generate
  
   
   begin
       
      BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
                                  reg_vacancy)
        Begin
   
           
           -- set default Status Register values
           status_bus <= (others => '0'); 
               
           -- set Encoded FIFO data width
           status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
           
           -- Set Vacancy as not scaled in this case
           status_bus(3)        <=  '0'; 
                    
           -- Echo remaining status
           status_bus(2)        <=  reg_deadlock   ; 
           status_bus(1)        <=  reg_almostfull ; 
           status_bus(0)        <=  reg_full       ;
           
                      
           for j in 0 to C_DP_ADDRESS_WIDTH loop
            
              status_bus((32-(C_DP_ADDRESS_WIDTH+1))+j) 
                     <=  reg_vacancy(j);
              
           End loop;
       
        End process; -- BUILD_STATUS_BUS

  
   end generate BUILD_STATUS_32BIT; 
  
  
   
   ----------------------------------------------------------------------------
   -- The IPIF DBUS is of sufficient width to contain the complete status 
   -- information so do not scale the Vacancy value down.
   -- Note status_bus bit 3 is not set, signaling a complete Vacancy value.
   ----------------------------------------------------------------------------
   BUILD_STATUS_FIT : if (REG_DWIDTH >= C_DP_ADDRESS_WIDTH+7
                          and REG_DWIDTH < 32) generate
  
   
   begin
       
      BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
                                  reg_vacancy)
        Begin
   
           -- set default Status Register values
           status_bus <= (others => '0'); 
               
           -- set Encoded FIFO data width
           status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
           
           -- Set Vacancy as not scaled in this case
           status_bus(3)        <=  '0'; 
           
           -- Echo remaining status
           status_bus(2)        <=  reg_deadlock   ; 
           status_bus(1)        <=  reg_almostfull; 
           status_bus(0)        <=  reg_full      ;
           
           
           for j in C_DP_ADDRESS_WIDTH downto 0 loop
            
              status_bus((REG_DWIDTH-1)-(C_DP_ADDRESS_WIDTH-j)) 
                     <=  reg_vacancy(j);
              
           End loop;
       
        End process; -- BUILD_STATUS_BUS

  
   end generate BUILD_STATUS_FIT; 
  
  
  
   ----------------------------------------------------------------------------
   -- The IPIF DBUS is too narrow to contain the complete status information so
   -- scale the Vacancy value down until it fits in the available space.
   -- Note status_bus bit 3 is now set, signaling a scaled Vacancy value.
   ----------------------------------------------------------------------------
   BUILD_STATUS_NO_FIT : if (REG_DWIDTH < C_DP_ADDRESS_WIDTH+7
                          and REG_DWIDTH < 32) generate
  
      constant VAC_INDEX_END : Integer := (REG_DWIDTH-7)-1;
      
   begin
      
      
      BUILD_STATUS_BUS : process (reg_deadlock, reg_almostfull, reg_full,
                                  reg_vacancy)
        Begin
   
           -- set default Status Register values
           status_bus <= (others => '0'); 
               
           -- set Encoded FIFO data width
           status_bus(4 to 6)   <= CONV_STD_LOGIC_VECTOR(ENC_FIFO_WIDTH,3);
           
           -- Set Vacancy as scaled in this case
           status_bus(3)        <=  '1'; 
           
           -- Echo remaining status
           status_bus(2)        <=  reg_deadlock   ; 
           status_bus(1)        <=  reg_almostfull; 
           status_bus(0)        <=  reg_full      ;
           
           
           for j in 0 to VAC_INDEX_END loop
            
              status_bus((REG_DWIDTH-1)-VAC_INDEX_END+j) 
                     <=  reg_vacancy(j);
              
           End loop;
       
        End process; -- BUILD_STATUS_BUS

  
   end generate BUILD_STATUS_NO_FIT; 
  
  
      -- ----------------------------------------------------------------------------    
      -- -- Mux the two read data sources to the IPIF Local Bus output port during
      -- -- reads.
      -- ----------------------------------------------------------------------------      
      -- MUX_THE_OUTPUT_DATA : process (Bus2FIFO_RdCE3, Bus2FIFO_RdCE2, 
      --                                Bus2FIFO_RdCE1, status_bus, 
      --                                rd_vect, reg_read_req)
      --   Begin
      --     
      -- 
      --     rd_vect <=  reg_read_req   & Bus2FIFO_RdCE3 & 
      --                 Bus2FIFO_RdCE2 & Bus2FIFO_RdCE1;
      --     
      --     Case rd_vect Is
      -- 
      --       When "1010" =>
      --       
      --           bus_data_out <=  status_bus;
      --       
      --       When others   => 
      --          
      --          bus_data_out <=  (others => '0');
      --          
      --     End case;
      --     
      --   End process; -- MUX_THE_OUTPUT_DATA
                           
     
    ------------------------------------------------------------
    -- If Generate
    --
    -- Label: READ_MUX_64BIT
    --
    -- If Generate Description:
    -- This IFGen builds the read mux when the Bus data width is
    -- 64 bits.
    --
    --
    ------------------------------------------------------------
    READ_MUX_64BIT : if (C_IPIF_DBUS_WIDTH = 64) generate
    
       -- Local Constants
       -- Local variables
       -- local signals
       -- local components
    
       begin
    
    ----------------------------------------------------------------------------      
    -- Mux the three read data sources to the IPIF Local Bus output port during
    -- reads.
    ----------------------------------------------------------------------------      
    MUX_THE_OUTPUT_DATA : process (Bus2FIFO_RdCE3, 
                                   --Bus2FIFO_RdCE2, 
                                   Bus2FIFO_RdCE1, 
                                   --mir_bus, 
                                   status_bus, 
                                   rd_vect, reg_read_req)
      Begin
        
        rd_vect <=  reg_read_req   & 
                    Bus2FIFO_RdCE3 &
                    '0' & 
                    --Bus2FIFO_RdCE2 &
                    Bus2FIFO_RdCE1;
        
        Case rd_vect Is

          When "1001" =>  -- Read MIR and status port
          
              bus_data_out(0 to 31)  <= (others => '0');
              bus_data_out(32 to 63) <= status_bus;
    
          When others   =>  -- default to zeroes
          
              bus_data_out <=  (others => '0');
             
        End case;
        
      End process; -- MUX_THE_OUTPUT_DATA
     
     
  end generate READ_MUX_64BIT;
     
     
     
    ------------------------------------------------------------
    -- If Generate
    --
    -- Label: READ_MUX_SMALL
    --
    -- If Generate Description:
    -- This IFGen builds the read mux when the Bus data width is
    -- 32 bits or less.
    --
    --
    ------------------------------------------------------------
    READ_MUX_SMALL : if (C_IPIF_DBUS_WIDTH <= 32) generate
    
       -- Local Constants
       -- Local variables
       -- local signals
       -- local components
    
       begin
    
         ----------------------------------------------------------------------------      
         -- Mux the three read data sources to the IPIF Local Bus output port during
         -- reads.
         ----------------------------------------------------------------------------      
         MUX_THE_OUTPUT_DATA : process (Bus2FIFO_RdCE3, 
                                        Bus2FIFO_RdCE2, 
                                        Bus2FIFO_RdCE1, 
                                        --mir_bus, 
                                        status_bus, 
                                        rd_vect, reg_read_req)
           Begin
             
             rd_vect <=  reg_read_req   & 
                         Bus2FIFO_RdCE3 & 
                         Bus2FIFO_RdCE2 &
                         Bus2FIFO_RdCE1;
             
             Case rd_vect Is

               When "1010" =>  -- Read status port
               
                   bus_data_out <= status_bus;
         
               When others   =>  -- default to zeroes
               
                   bus_data_out <=  (others => '0');
                  
             End case;
             
           End process; -- MUX_THE_OUTPUT_DATA
          
          
       end generate READ_MUX_SMALL;
     
  
 
      ----------------------------------------------------------------------------
      -- Generate the Read Error Acknowledge Reply to the Bus when
      -- an attempted read access by the IPIF Local Bus is invalid
      ----------------------------------------------------------------------------  
      GEN_RD_ERROR : process (Bus_rst, Bus_clk)
        Begin
          
           If (Bus_rst = '1') Then
             rd_access_error    <= '0';  
           Elsif (Bus_clk'EVENT and Bus_clk = '1') Then
           
              if (Bus2FIFO_RdCE1 = '1') Then -- attempting to read the MIR but it
                                             -- is not included
                rd_access_error <= '1';
              Elsif (Bus2FIFO_RdCE3 = '1') Then -- attempting a read of the FIFO  
                rd_access_error <= '1';         -- data through the data write  
                                                -- port. This is always an error.
              Else                                                                            
                rd_access_error <= '0';                                                       
              End if;
           
           Else 
              null;
           End if;
                     
        End process; -- GEN_RD_ERROR
       
                           
                           
                           
   end generate Occlude_MIR;   
                        
 
 
          
-------------------------------------------------------------------------------
-- Generate the Read Acknowledge to the Bus
-------------------------------------------------------------------------------
GEN_READ_ACK : process (Bus_rst, Bus_clk)
  Begin
    If (Bus_rst = '1') Then
      reg_read_ack    <= '0';  
    Elsif (Bus_clk'EVENT and Bus_clk = '1') Then
        
        If (Bus2FIFO_RdCE1 = '1' ) Then
           reg_read_ack     <= '1';
           
        Elsif (Bus2FIFO_RdCE2 = '1' ) Then
           reg_read_ack     <= '1';
           
        else
           reg_read_ack     <= '0';
           
        End if;
        
    Else 
       null;
    End if;
  End process; -- GEN_READ_ACK
  
  
  read_ack       <= reg_read_ack or rd_access_error;
  
  
          
   
   
  -- write_ack      <=   reg_wrce1 or        -- used for reset port write
  --                     wr_access_error or  -- used for error ack on invalid 
  --                                         -- write ops
  --                     Fifo_WrAck ;        -- The FIFO accepted the write data
  
   
  
  write_ack        <= reg_wrce1       or  -- used for reset port write
                      wr_access_error or  -- used for error ack on invalid 
                                          -- write ops
                      (Bus2FIFO_WrCE3 and -- A valid data port enable
                      Bus_WrReq       and -- and write request
                      not(Full));         -- and the FIFO is not full

  going_full_ccase <= write_req_trig      and  -- FIFO not going full after  
                      write_req_trig_dly1 and  -- back to back writes
                      AlmostFull;
   
  
-------------------------------------------------------------------------------
-- This process detects the completion of at least one valid FIFO data write
-- cycle during a burst write. An error ack is generated only if a data
-- write is initiated at the same time as the FIFO is FUll.
-------------------------------------------------------------------------------
GEN_ERRACK_INHIB : process (Bus_rst, Bus_clk)
  Begin       
     If (Bus_rst = '1') Then
        fifo_errack_inhibit <= '0';
     Elsif (Bus_clk'EVENT and Bus_clk = '1' ) Then
        If (Bus2FIFO_WrCE3 = '1' and Fifo_WrAck = '1') Then
           fifo_errack_inhibit <= '1';
        Elsif (Bus2FIFO_WrCE3 = '0') Then
           fifo_errack_inhibit <= '0';
        else
           null;
        End if;
     else
          null;
     End if;
   End process; -- GEN_ERRACK_INHIB



  
-- GAB 2/10/06 Qualified ERROR Generation process with  DBUS Width
-- to prevent an error from being generated when the RESET register is written
-- to when C_IPIF_DBUS_WIDTH = 64
 
-------------------------------------------------------------------------------
-- Generate the Error Acknowledge Reply to the Bus when
-- an attempted access by the IPIF Local Bus is invalid
-------------------------------------------------------------------------------  
GEN_ERROR_FOR_64BIT : if C_IPIF_DBUS_WIDTH = 64 generate
    GEN_WR_ERROR : process (Bus_rst, Bus_clk)
      Begin
        If (Bus_rst = '1') Then
          wr_access_error   <= '0';  
        Elsif (Bus_clk'EVENT and Bus_clk = '1') Then

           if (Bus2FIFO_WrCE3 = '1' and 
               Full = '1' and 
               fifo_errack_inhibit = '0') Then -- Initiating a fifo write during a 
             wr_access_error <= '1';           -- full condition, this is an error.
           Elsif (Bus2FIFO_WrCE2 = '1'          -- Attempting to write to the status reg 
           and Bus_BE((C_IPIF_DBUS_WIDTH/8)-1)='1') Then  
             wr_access_error <= '1';
           Else
             wr_access_error <= '0';
           End if;

        Else 
           null;
        End if;
    end process GEN_WR_ERROR;
end generate GEN_ERROR_FOR_64BIT;

GEN_ERROR_FOR_32BIT : if C_IPIF_DBUS_WIDTH <= 32 generate
    GEN_WR_ERROR : process (Bus_rst, Bus_clk)
      Begin
        If (Bus_rst = '1') Then
          wr_access_error   <= '0';  
        Elsif (Bus_clk'EVENT and Bus_clk = '1') Then

           if (Bus2FIFO_WrCE3 = '1' and 
               Full = '1' and 
               fifo_errack_inhibit = '0') Then -- Initiating a fifo write during a 
             wr_access_error <= '1';           -- full condition, this is an error.
           Elsif (Bus2FIFO_WrCE2 = '1') Then  -- Attempting to write to the staus 
                                              -- register
             wr_access_error <= '1';
           Else
             wr_access_error <= '0';
           End if;

        Else 
           null;
        End if;
    end process GEN_WR_ERROR;
end generate GEN_ERROR_FOR_32BIT;


    
end implementation;


 





