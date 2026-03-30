-------------------------------------------------------------------------------
-- $Id: addr_reg_cntr_brst.vhd,v 1.1 2003/07/10 22:51:44 dougt Exp $
-------------------------------------------------------------------------------
-- addr_reg_cntr_brst.vhd - vhdl design file for the entity and architecture
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
-- Filename:        addr_reg_cntr_brst.vhd
--
-- Description:     This vhdl design file is for the entity and architecture  
--                  of the Mauna Loa IPIF Bus to IPIF Bus Address Bus Output 
--                  multiplexer.        
--
-------------------------------------------------------------------------------
-- Structure:   
--              
--
--              addr_reg_cntr_brst.vhd
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
-- History:
--
--      DET        Feb-5-02
-- ~~~~~~
--      First version
-- ^^^^^^
--
--      DET        Mar-4-02
-- ~~~~~~
--      - Corrected a problem with the cacheline address counting mechanism
-- ^^^^^^
--
--     DET     3/29/2002     v1_00_b
-- ~~~~~~
--     - Added burst mode support to the address reg/counter.
-- ^^^^^^
--
--
--
---------------------------------------------------------------------------------
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

library proc_common_v1_00_b;
Use proc_common_v1_00_b.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
entity addr_reg_cntr_brst is
  Generic (
           C_INCLUDE_BURST      : Boolean := true;
           C_BURST_PAGE_SIZE    : Integer := 1024; -- bytes
           C_PLB_AWIDTH         : Integer := 32;   -- bits
           C_IPIF_DWIDTH        : integer := 64;   -- bits
           C_PLB_DWIDTH         : Integer := 64    -- bits
          ); 
    port (
       -- Clock and Reset
         Bus_reset          : In  std_logic;
         Bus_clk            : In  std_logic;
       
       
       -- Inputs from Slave Attachment
         Addr_Load          : In  std_logic;
         Addr_Cnt_en        : In  std_logic;
         Addr_Cnt_Size      : In  Std_logic_vector(0 to 3);
         Address_In         : in  std_logic_vector(0 to C_PLB_AWIDTH-1);
         BE_in              : In  Std_logic_vector(0 to (C_PLB_DWIDTH/8)-1);
    
         
       -- BE Outputs
         BE_out             : Out Std_logic_vector(0 to (C_PLB_DWIDTH/8)-1);                                                                
                                                                       
       -- IPIF & IP address bus source (AMUX output)
         Address_Out        : out std_logic_vector(0 to C_PLB_AWIDTH-1)

         );
end addr_reg_cntr_brst;




architecture implementation of addr_reg_cntr_brst is


    
-- COMPONENTS

--TYPES
    
  -- no types
  
             
-- CONSTANTS
  
  
  

--INTERNAL SIGNALS
  Signal  Addr_Cnt_Size_reg : Std_logic_vector(0 to 3);
  Signal  Address_out_i     : std_logic_vector(0 to C_PLB_AWIDTH-1);
  Signal  BE_out_i          : std_logic_vector(0 to (C_PLB_DWIDTH/8)-1);

--------------------------------------------------------------------------------------------------------------
-------------------------------------- start of logic -------------------------------------------------
  
begin
  
    
    -- Output assignments
    Address_out   <=  Address_out_i;  
    BE_out        <=  BE_out_i;
  


------------------------------------------------------------
-- If Generate
--
-- Label: INCLUDE_BURST
--
-- If Generate Description:
-- This If-Generate creates the address counter/reg logic
-- required to support single beat ,cacheline, and burst
-- data transactions via the PLB bus.
--
--
------------------------------------------------------------
INCLUDE_BURST : if (C_INCLUDE_BURST = true) generate
  
     Constant BURST_CNT_CWIDTH  : integer := log2(C_BURST_PAGE_SIZE); 
     Constant BYTE_ADDRESS_SIZE : integer := log2(C_PLB_AWIDTH/8); -- future growth
     
     
     
     Signal  reg_addr          : std_logic_vector(0 to C_PLB_AWIDTH-BURST_CNT_CWIDTH-1);
     Signal  next_addr_cnt     : unsigned(0 to BURST_CNT_CWIDTH-1);
     Signal  addr_inc_value    : integer;
     Signal  reg_addr_plus_n   : unsigned(0 to BURST_CNT_CWIDTH-1);
     Signal  addr_plus_n       : unsigned(0 to BURST_CNT_CWIDTH-1);
     signal  addr_lsb_bus      : std_logic_vector(0 to 2);
     signal  decoded_be        : std_logic_vector(0 to (C_PLB_DWIDTH/8)-1);
     signal  cken0             : std_logic;
     signal  cken1             : std_logic;
     signal  cken2             : std_logic;
     signal  cken3             : std_logic;
     signal  cken4             : std_logic;

   begin

      -- Concatonate counter and registered versions of the output address
      Address_out_i <=  reg_addr & std_logic_vector(reg_addr_plus_n);


      
       -------------------------------------------------------------
       -- Combinational Process
       --
       -- Label: INCREMENT_THE_ADDR
       --
       -- Process Description:
       -- Combinationally increment the registered address value for 
       -- feedback into the address register
       --
       -------------------------------------------------------------
       INCREMENT_THE_ADDR : process (reg_addr_plus_n, 
                                     Addr_Cnt_Size_reg,
                                     addr_inc_value)
          Begin

             Case Addr_Cnt_Size_reg Is
               
               -- Single beat transfer
               When "0000" => 
                  addr_inc_value <= 0;
                  
               -- Cacheline transfer
               When "0001" | "0010" | "0011" =>
                  addr_inc_value <= C_IPIF_DWIDTH/8;
               
               -- Burst transfer bytes (8 bits)
               When "1000" =>
                  addr_inc_value <= 1;
               
               -- Burst transfer halfwords (16 bits)
               When "1001" =>
                  addr_inc_value <= 2;
               
               -- Burst transfer words (32 bits)
               When "1010" =>
                  addr_inc_value <= 4;
               
               -- Burst transfer double words (64 bits)
               When "1011" =>
                  addr_inc_value <= C_IPIF_DWIDTH/8;
               
               -- Burst transfer quad words (128 bits)
               When "1100" =>
                  addr_inc_value <= C_IPIF_DWIDTH/8;
               
               -- Burst transfer octal words (256 bits)
               When "1101" =>
                  addr_inc_value <= C_IPIF_DWIDTH/8;
               
               When others   => 
                  addr_inc_value <= 0;
             End case;
              
              
             addr_plus_n <= unsigned(reg_addr_plus_n) + addr_inc_value;
          
          End process INCREMENT_THE_ADDR; 

      
      
      -------------------------------------------------------------
      -- Combinational Process
      --
      -- Label: MUX_ADDR_CNT_SOURCE
      --
      -- Process Description:
      -- This process selects the source of the address loaded  
      -- into the counter portion of the address register.
      --
      -------------------------------------------------------------
      MUX_ADDR_CNT_SOURCE : process (Addr_Load, Address_In, addr_plus_n)
         begin
      
           if (Addr_Load = '1') then

             next_addr_cnt <=  unsigned(Address_In(C_PLB_AWIDTH-BURST_CNT_CWIDTH to
                                                   C_PLB_AWIDTH-1));
                               
           else

             next_addr_cnt <=  addr_plus_n;
             
           end if;
      
         end process MUX_ADDR_CNT_SOURCE; 
      

      -------------------------------------------------------------------------
      -- Synchronous Process
      -- 
      -- Process Label: REG_THE_ADDR
      --
      -- Process Description:
      -- This process registers the incremented address according to the type 
      -- of data phase transaction.
      -- 
      -------------------------------------------------------------------------
      REG_THE_ADDR : process (Bus_clk)
        Begin
           if (Bus_clk'EVENT and Bus_clk = '1') Then
               
               If (Bus_reset = '1') Then

                  reg_addr_plus_n <= (others => '0');
                  reg_addr        <= (others => '0');
                  
               elsif (Addr_Load = '1') Then  
                  reg_addr_plus_n <= next_addr_cnt;  
                  reg_addr        <= Address_In(0 to C_PLB_AWIDTH-BURST_CNT_CWIDTH-1);
               
               Else
            
                  If (Addr_Cnt_en = '1') Then

                     -- ls two cntr bits 
                     If (cken0 = '1') Then
                        reg_addr_plus_n(BURST_CNT_CWIDTH-1) <= addr_plus_n(BURST_CNT_CWIDTH-1);
                        reg_addr_plus_n(BURST_CNT_CWIDTH-2) <= addr_plus_n(BURST_CNT_CWIDTH-2);
                     else
                         null;
                     End if;
                     
                      
                     -- next two cntr bits
                     If (cken1 = '1') Then
                        reg_addr_plus_n(BURST_CNT_CWIDTH-3) <= addr_plus_n(BURST_CNT_CWIDTH-3);
                        reg_addr_plus_n(BURST_CNT_CWIDTH-4) <= addr_plus_n(BURST_CNT_CWIDTH-4);
                     else
                         null;
                     End if;
                      
                                     
                     -- next one cntr bit 
                     If (cken2 = '1') Then
                        reg_addr_plus_n(BURST_CNT_CWIDTH-5) <= addr_plus_n(BURST_CNT_CWIDTH-5);
                     else
                         null;
                     End if;
                      
                     -- last cacheln cntr bit
                     If (cken3 = '1') Then
                        reg_addr_plus_n(BURST_CNT_CWIDTH-6) <= addr_plus_n(BURST_CNT_CWIDTH-6);
                     else
                         null;
                     End if;
                      
                     -- remaining ms cntr bits
                     for cnt_bit_index in 0 to BURST_CNT_CWIDTH-7 loop
                        If (cken4 = '1') Then
                           reg_addr_plus_n(cnt_bit_index) <= addr_plus_n(cnt_bit_index);
                        else
                            null;
                        End if;
                     end loop;
                     
                  Else 

                      null;
                      
                  End if;
                 
               End if;
                      
           else
             null;
           End if;
             
        End process REG_THE_ADDR; 

       
       -------------------------------------------------------------------------
       -- Synchronous Process
       -- 
       -- Process Label: S_AND_H_SIZE
       --
       -- Process Description:
       -- This process samples and holds the transaction attribute (plb_size) and
       -- the initial BE value (for single beat data transfers).
       --  
       -------------------------------------------------------------------------
       S_AND_H_SIZE : process (Bus_clk)
         Begin
              
           if (Bus_clk'EVENT and Bus_clk = '1') Then
               If (Bus_reset = '1') Then

                  Addr_Cnt_Size_reg <= (others => '0');
               
               Elsif (Addr_Load = '1') Then

                  Addr_Cnt_Size_reg <= Addr_Cnt_Size;
                   
               else

                 null;
                   
               End if;
               
           else
             null;
           End if;
           
         End process S_AND_H_SIZE;
       
       
       
       -------------------------------------------------------------
       -- Combinational Process
       --
       -- Label: GEN_CLK_ENABLES
       --
       -- Process Description:
       -- This process generates the desired clock enable control 
       -- signals (for use by the register counter). The enables are 
       -- based upon the current data transaction mode (single, 
       -- cacheline, or burst).
       --
       -------------------------------------------------------------
       GEN_CLK_ENABLES : process (Addr_Cnt_Size_reg, Addr_Cnt_en)
         Begin
          
          -- Default conditions
          
            cken0 <= '0'; 
            cken1 <= '0'; 
            cken2 <= '0'; 
            cken3 <= '0'; 
            cken4 <= '0'; 
             
             
            Case Addr_Cnt_Size_reg Is
               When "0000" =>                 -- 1 to 4 byte transfer
                  cken0 <= Addr_Cnt_en;
                  
               When "0001" =>                 -- 4 word cache line
                  cken0  <= '1';
                  cken1  <= '1';
                  
               When "0010" =>                 -- 8 word cache line
                  cken0 <= '1';
                  cken1 <= '1';
                  cken2 <= '1';
                  
               When "0011" =>                 -- 16 word cache line
                  cken0 <= '1';
                  cken1 <= '1';
                  cken2 <= '1';
                  cken3 <= '1';
                  
               When "1000" | "1001" | "1010" |
                    "1011" | "1100" | "1101" => -- burst transfer
                  cken0 <= '1';
                  cken1 <= '1';
                  cken2 <= '1';
                  cken3 <= '1';
                  cken4 <= '1';

               When others   =>              -- undefined 

                  null; -- no enables

            End case;
         
         End process GEN_CLK_ENABLES; 

 
 
   -------------------------------------------------------------
   -- Combinational Process
   --
   -- Label: ADDR_2_BE
   --
   -- Process Description:
   -- This process generates the desired BE control signals (for
   -- use by the IPIF and IP) from the 3 lsb address bits and
   -- the current data transaction mode (single, cacheline, or
   -- burst).
   --
   -------------------------------------------------------------
   ADDR_2_BE : process (BE_in, Addr_Cnt_Size_reg, next_addr_cnt,
                        addr_lsb_bus)
      begin

         addr_lsb_bus <= next_addr_cnt(BURST_CNT_CWIDTH-3) &
                         next_addr_cnt(BURST_CNT_CWIDTH-2) &
                         next_addr_cnt(BURST_CNT_CWIDTH-1);
         
         
         Case Addr_Cnt_Size_reg Is
            
            When "0000" =>                 -- 1 to 4 byte transfer
               decoded_be  <= BE_in;
               
            When "0001" | "0010" | "0011"   =>  -- cacheline so set all BE's 

               decoded_be <= (others => '1');

            When "1000"  =>              -- byte burst 

               Case addr_lsb_bus Is
                 When "000" => 
                    decoded_be <= "10000000";
                 When "001" => 
                    decoded_be <= "01000000";
                 When "010" => 
                    decoded_be <= "00100000";
                 When "011" => 
                    decoded_be <= "00010000";
                 When "100" => 
                    decoded_be <= "00001000";
                 When "101" => 
                    decoded_be <= "00000100";
                 When "110" => 
                    decoded_be <= "00000010";
                 When "111" => 
                    decoded_be <= "00000001";
                 When others   => 
                    decoded_be <= "00000000";
               End case;

            When "1001"  =>              -- half word burst 

               Case addr_lsb_bus Is
                 When "000" => 
                    decoded_be <= "11000000";
                 When "010" => 
                    decoded_be <= "00110000";
                 When "100" => 
                    decoded_be <= "00001100";
                 When "110" => 
                    decoded_be <= "00000011";
                 When others   => 
                    decoded_be <= "00000000";
               End case;

            When "1010" =>              -- word burst 

               Case addr_lsb_bus Is
                 When "000" => 
                    decoded_be <= "11110000";
                 When "100" => 
                    decoded_be <= "00001111";
                 When others   => 
                    decoded_be <= "00000000";
               End case;

            When "1011" | "1100" | "1101" =>     -- double word burst 
               decoded_be <= "11111111";         -- Quad word burst
                                                 -- Octal word burst
            
            When others   =>              -- set all BE's 

               decoded_be <= (others => '0');

         End case;
    
      end process ADDR_2_BE; 

 
 
 
   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: GEN_BE_OUTPUTS
   --
   -- Process Description:
   -- This process registers the Byte Enable (BE) signals from
   -- the combinational ADDR_2_BE process.
   --
   -------------------------------------------------------------
   GEN_BE_OUTPUTS : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           
           if (bus_reset = '1') then
             
              BE_out_i <= (others => '0');
           
           Elsif (Addr_Load = '1' or 
                  Addr_Cnt_en = '1') Then -- load new value
              
              BE_out_i <= decoded_be;
              
           else

              null; -- hold the last value
              
           end if;        
           
        else
          null;
        end if;
      end process GEN_BE_OUTPUTS; 
      
                                        
   end generate INCLUDE_BURST;  



 
 
 
 
 
 
------------------------------------------------------------
-- If Generate
--
-- Label: OMIT_BURST
--
-- If Generate Description:
-- This If-Generate creates the address counter/reg logic
-- required only to support single beat and cacheline
-- data transactions via the PLB bus.
--
--
------------------------------------------------------------
OMIT_BURST : if (C_INCLUDE_BURST = false) generate
  
     Signal  reg_addr          : std_logic_vector(0 to C_PLB_AWIDTH-8);
     Signal  reg_addr_plus_n   : unsigned(0 to 6);
     Signal  addr_plus_n       : unsigned(0 to 6);
     signal  cken0             : std_logic;
     signal  cken1             : std_logic;
     signal  cken2             : std_logic;
     signal  cken3             : std_logic;
     signal  cken4             : std_logic;

   begin


      -- Concatonate counter and registered versions of the output address
      Address_out_i <=  reg_addr & std_logic_vector(reg_addr_plus_n);


      
       -------------------------------------------------------------
       -- Combinational Process
       --
       -- Label: INCREMENT_THE_ADDR
       --
       -- Process Description:
       -- Combinationally increment the registered address value for 
       -- feedback into the address register
       --
       -------------------------------------------------------------
       INCREMENT_THE_ADDR : process (reg_addr_plus_n)
          Begin
             
             addr_plus_n <= unsigned(reg_addr_plus_n) + C_IPIF_DWIDTH/8;
          
          End process; -- INCREMENT_THE_ADDR



      -------------------------------------------------------------------------
      -- Synchronous Process
      -- 
      -- Process Label: REG_THE_ADDR
      --
      -- Process Description:
      -- This process registers the incremented address according to the type 
      -- of data phase transaction.
      -- 
      -------------------------------------------------------------------------
      REG_THE_ADDR : process (Bus_clk)
        Begin
           if (Bus_clk'EVENT and Bus_clk = '1') Then
               
               If (Bus_reset = '1') Then

                  reg_addr_plus_n <= (others => '0');
                  reg_addr        <= (others => '0');
                  
               elsif (Addr_Load = '1') Then  
                  reg_addr_plus_n <= unsigned(Address_In(C_PLB_AWIDTH-7 to 
                                                         C_PLB_AWIDTH-1));  
                  reg_addr        <= Address_In(0 to C_PLB_AWIDTH-8);
               
               Else
            
                  If (Addr_Cnt_en = '1') Then

                     
                     -- cntr bits 5 & 6 
                     If (cken0 = '1') Then
                        reg_addr_plus_n(6) <= addr_plus_n(6);
                        reg_addr_plus_n(5) <= addr_plus_n(5);
                     else
                         null;
                     End if;
                      
                     -- cntr bits 4
                     If (cken1 = '1') Then
                        reg_addr_plus_n(4) <= addr_plus_n(4);
                        reg_addr_plus_n(3) <= addr_plus_n(3);
                     else
                         null;
                     End if;
                      
                     -- cntr bits 2
                     If (cken2 = '1') Then
                        reg_addr_plus_n(2) <= addr_plus_n(2);
                     else
                         null;
                     End if;
                      
                     -- cntr bits 1
                     If (cken3 = '1') Then
                        reg_addr_plus_n(1) <= addr_plus_n(1);
                     else
                         null;
                     End if;
                      
                     -- cntr bits 0
                     If (cken4 = '1') Then
                        reg_addr_plus_n(0) <= addr_plus_n(0);
                     else
                         null;
                     End if;
                     
                  Else 

                      null;
                      
                  End if;
                 
               End if;
                      
           else
             null;
           End if;
             
        End process REG_THE_ADDR;  

       
       -------------------------------------------------------------------------
       -- Synchronous Process
       -- 
       -- Process Label: S_AND_H_BE_SIZE
       --
       -- Process Description:
       -- This process samples and holds the transaction attribute (plb_size) and
       -- the initial BE value (for single beat data transferes).
       --  
       -------------------------------------------------------------------------
       S_AND_H_BE_SIZE : process (Bus_clk)
         Begin
              
           if (Bus_clk'EVENT and Bus_clk = '1') Then
               If (Bus_reset = '1') Then

                  Addr_Cnt_Size_reg <= (others => '0');
                  BE_out_i          <= (others => '0');
               
               Elsif (Addr_Load = '1') Then

                  Addr_Cnt_Size_reg <= Addr_Cnt_Size;
                  BE_out_i          <= BE_in; 
               
                  Case Addr_Cnt_Size Is
                     
                     When "0000" =>                 -- 1 to 4 byte transfer
                        BE_out_i  <= BE_in;
                        
                     When others   =>              -- cacheln so set all BE's 

                        BE_out_i <= (others => '1');

                  End case;
                   
               else

                 null;
                   
               End if;
               
           else
             null;
           End if;
           
         End process S_AND_H_BE_SIZE;
       
       
       
       ------------------------------------------------------------------------------
       -- Process
       --
       -- Generate clock enables for counter register
       --
       ------------------------------------------------------------------------------
       GEN_CLK_ENABLES : process (Addr_Cnt_Size_reg, Addr_Cnt_en)
         Begin
          
          -- Default conditions
          
            cken0 <= '0'; 
            cken1 <= '0'; 
            cken2 <= '0'; 
            cken3 <= '0'; 
            cken4 <= '0'; 
             
             
            Case Addr_Cnt_Size_reg Is
               When "0000" =>                 -- 1 to 4 byte transfer
                  cken0 <= Addr_Cnt_en;
                  
               When "0001" =>                 -- 4 word cache line
                  cken0  <= '1';
                  cken1  <= '1';
                  
               When "0010" =>                 -- 8 word cache line
                  cken0 <= '1';
                  cken1 <= '1';
                  cken2 <= '1';
                  
               When "0011" =>                 -- 16 word cache line
                  cken0 <= '1';
                  cken1 <= '1';
                  cken2 <= '1';
                  cken3 <= '1';
                  
               When "1000" | "1001" | "1010" |
                    "1011" | "1100" | "1101" => -- burst transfer (not
                  cken0 <= '1';                 -- really supported in
                  cken1 <= '1';                 -- this if-generate code)
                  cken2 <= '1';
                  cken3 <= '1';
                  cken4 <= '1';

               When others   =>              -- undefined 

                  null; -- no enables

            End case;
         
         End process GEN_CLK_ENABLES; 

   
   
   end generate OMIT_BURST;  


        
        
end implementation;
  




