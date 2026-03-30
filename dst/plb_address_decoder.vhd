-------------------------------------------------------------------------------
-- $Id: plb_address_decoder.vhd,v 1.3 2006/08/21 23:25:26 dougt Exp $
-------------------------------------------------------------------------------
-- plb_address_decoder - entity/architecture pair
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
-- Filename:        plb_address_decoder.vhd
-- Version:         v1.00a
-- Description:     Address decoder utilizing unconstrained arrays for Base
--                  Address specification, target data bus size, and ce number.
--
-------------------------------------------------------------------------------
--
--                  -- plb_address_decoder.vhd
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
-- History:
--  DET        02-12-2002      -- First version
--
--
--  DET         03-12-02
-- ~~~~~~
--     - Removed registering of decode_hit signal in order
--       to remove one address phase clock cycle from an
--       PLB Bus cycle to this slave.
-- ^^^^^^
--
--  DET         03-26-02
-- ~~~~~~
--     - Changed the input generic C_ARD_ADDR_RANGE_ARRAY to 
--       SLV64_ARRAY_TYPE (from SLV32_ARRAY_TYPE)
-- ^^^^^^
--
--     DET     11/19/2002     plb ipif Rev C update
-- ~~~~~~
--     - Changed the ipif_common library reference to ipif_common_v1_00_b.
-- ^^^^^^
--
--     DET     3/18/2003     Fmax improvement
-- ~~~~~~
--     - Created special PLB version for Fmax and LUT optimization 
--        - Added register stage for Pselect outputs
--        - Generate CS, CE, RdCE, WrCE, and CS_Size from registered Pselects
--        - CS_Size_early removed (not used anymore) 
--        - Utilized instantiated registering
-- ^^^^^^
--
--     DET     6/20/2003     PCI requirements
-- ~~~~~~
--     - Added raw pselect outputs for PCI 'busy' determination.
-- ^^^^^^
--
--     DET     3/25/2004     ipif to v1_00_f
-- ~~~~~~
--     - Updated proc_common library reference to v2_00_a
--     - Removed ipif_common library reference
-- ^^^^^^
--
--
--     DET     4/12/2004     IPIF to V1_00_f
-- ~~~~~~
--     - Updated unisim library reference to unisim.vcomponents.all.
--     - Commented out Xilinx primitive component declarations
-- ^^^^^^
--
--     DET     8/18/2006     v1_00_f for Im sp2
-- ~~~~~~
--     - Fix for CR418863 and CR415395. Removed component instantiations and
--       replaced with direct entity instantiations.
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
--      combinatorial signals:                  "*_cmb" 
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;     
--use ieee.std_logic_unsigned.CONV_INTEGER;  --Used in byte count compare 2 MA2SA_Num
--use ieee.std_logic_arith.conv_std_logic_vector;

library proc_common_v2_00_a;
use proc_common_v2_00_a.proc_common_pkg.all;
use proc_common_v2_00_a.pselect;
use proc_common_v2_00_a.or_gate;
use proc_common_v2_00_a.ipif_pkg.all;


library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Port declarations
-------------------------------------------------------------------------------

entity plb_address_decoder is
  generic (
    C_BUS_AWIDTH      : Integer := 32;
                                                                                          
    C_ARD_ADDR_RANGE_ARRAY  : SLV64_ARRAY_TYPE :=                              
            (                                                            
             X"0000_0000_1000_0000", --  IP user0 base address       
             X"0000_0000_1000_01FF", --  IP user0 high address       
             X"0000_0000_1000_0200", --  IP user1 base address       
             X"0000_0000_1000_02FF", --  IP user1 high address       
             X"0000_0000_1000_2000", --  IP user2 base address
             X"0000_0000_1000_20FF", --  IP user2 high address
             X"0000_0000_1000_2100", --  IPIF Interrupt base address       
             X"0000_0000_1000_21ff", --  IPIF Interrupt high address       
             X"0000_0000_1000_2200", --  IPIF Reset base address           
             X"0000_0000_1000_22FF", --  IPIF Reset high address           
             X"0000_0000_1000_2300", --  IPIF WrFIFO Registers base address
             X"0000_0000_1000_23FF", --  IPIF WrFIFO Registers high address
             X"0000_0000_7000_0000", --  IPIF WrFIFO Data base address     
             X"0000_0000_7000_00FF", --  IPIF WrFIFO Data high address     
             X"0000_0000_8000_0000", --  IPIF RdFIFO Registers base address
             X"0000_0000_8FFF_FFFF", --  IPIF RdFIFO Registers high address                                                   
             X"0000_0000_9000_0000", --  IPIF RdFIFO Data base address                                                        
             X"0000_0000_9FFF_FFFF"  --  IPIF RdFIFO Data high address                                                        
            );                                                                    
                                                                                  
    C_ARD_DWIDTH_ARRAY  : INTEGER_ARRAY_TYPE :=                                      
            (                                                                     
             64  ,    -- User0 data width                          
             64  ,    -- User1 data width                                 
             64  ,    -- User2 data width                                 
             32  ,    -- IPIF Interrupt data width                                   
             32  ,    -- IPIF Reset data width                                       
             32  ,    -- IPIF WrFIFO Registers data width 
             64  ,    -- IPIF WrFIFO Data data width     
             32  ,    -- IPIF RdFIFO Registers data width
             64       -- IPIF RdFIFO Data width          
            );
                      
    C_ARD_NUM_CE_ARRAY   : INTEGER_ARRAY_TYPE :=
            (
             8,     -- User0 CE Number
             1,     -- User1 CE Number
             1,     -- User2 CE Number
             16,    -- IPIF Interrupt CE Number
             1,     -- IPIF Reset CE Number
             2,     -- IPIF WrFIFO Registers CE Number
             1,     -- IPIF WrFIFO Data data CE Number
             2,     -- IPIF RdFIFO Registers CE Number
             1      -- IPIF RdFIFO Data CE Number
            )
   
    );   
  port (
    Bus_clk           : in  std_logic;
    Bus_rst           : in  std_logic;

    -- PLB Interface signals
    Address_In        : in  std_logic_vector(0 to C_BUS_AWIDTH-1);
    Address_Valid     : In  std_logic;
    Bus_RNW           : In  std_logic;
    
    -- Registering control signals
    cs_sample_hold_n  : In  std_logic;
    cs_sample_hold_clr: In  std_logic;
    CS_CE_ld_enable   : In  std_logic;
    Clear_CS_CE_Reg   : In  std_logic;
    RW_CE_ld_enable   : In  std_logic;
    Clear_RW_CE_Reg   : In  std_logic;
    Clear_addr_match  : In  std_logic;
    
    -- Decode output signals
    PSelect_Hit       : Out std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1); -- Raw PSelect outputs
    Addr_Match_early  : Out std_logic; -- unregistered 
    Addr_Match        : Out std_logic; -- registered
    CS_Out            : Out std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
    CS_Out_Early      : Out std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
    CS_Size           : Out std_logic_vector(0 to 2);
    -- CS_Size_early     : Out std_logic_vector(0 to 2);
    CE_Out            : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);
    RdCE_Out          : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1);
    WrCE_Out          : out std_logic_vector(0 to calc_num_ce(C_ARD_NUM_CE_ARRAY)-1)
    );
end entity plb_address_decoder;

-------------------------------------------------------------------------------
-- Architecture section
-------------------------------------------------------------------------------

architecture IMP of plb_address_decoder is


-- local type declarations ----------------------------------------------------
type decode_bit_array_type is Array(natural range 0 to (
                                     (C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1) of integer;

type size_array_type is Array(natural range 0 to (
                                     (C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1) of 
                                     std_logic_vector(0 to 2);
   
type short_addr_array_type is Array(natural range 0 to 
                                     C_ARD_ADDR_RANGE_ARRAY'LENGTH-1) of 
                                     std_logic_vector(0 to 31);
   
-- functions ------------------------------------------------------------------
   
 ------------------------------------------------------------------------------
 -- This function converts a 64 bit address range array to a 32 bit address
 -- range array.
 ------------------------------------------------------------------------------
 function slv64_2_slv32 (slv64_addr_array : SLV64_ARRAY_TYPE) 
                        return short_addr_array_type is

    Variable temp_addr   : std_logic_vector(0 to 63);
    Variable slv32_array : short_addr_array_type;
    
 begin
 
    for array_index in 0 to slv64_addr_array'length-1 loop
       
       temp_addr := slv64_addr_array(array_index);
       slv32_array(array_index) := temp_addr(32 to 63);
               
    End loop; 
    
    return(slv32_array);
    
 end function slv64_2_slv32;
 
 
 ------------------------------------------------------------------------------ 
 function Addr_Bits (x,y : std_logic_vector(0 to C_BUS_AWIDTH-1)) 
 return integer is
   variable addr_nor : std_logic_vector(0 to C_BUS_AWIDTH-1);
 begin
   addr_nor := x xor y;
   for i in 0 to C_BUS_AWIDTH-1 loop
     if addr_nor(i)='1' then return i;
     end if;
   end loop;
   return(C_BUS_AWIDTH);
 end function Addr_Bits;

 
 
 
 
 ------------------------------------------------------------------------------
 function Get_Addr_Bits (baseaddrs : short_addr_array_type) 
 return decode_bit_array_type is
 
    Variable num_bits : decode_bit_array_type;
    
  begin
     
    for i in 0 to ((baseaddrs'length)/2)-1 loop
   
       num_bits(i) :=  Addr_Bits (baseaddrs(i*2), 
                                  baseaddrs(i*2+1)
                                 );
       
    end loop;
     
   return(num_bits);
   
 end function Get_Addr_Bits;
 
 
 
 ------------------------------------------------------------------------------
 function encode_size (size : integer) return std_logic_vector is
 
    Variable enc_size : Std_logic_vector(0 to 2);
    
 begin
     
     Case size Is
        When 8 => 
           enc_size := "001";
        When 16 => 
           enc_size := "010";
        When 32 => 
           enc_size := "011";
        When 64 => 
           enc_size := "100";
        When 128 => 
           enc_size := "101";
        When others   => 
           enc_size := "000";
     End case;
     
     return(enc_size);    
     
 end function encode_size;
 
 
 ------------------------------------------------------------------------------
 -------------------------------------------------------------------
 -- Function
 --
 -- Function Name: NEEDED_ADDR_BITS
 --
 -- Function Description:
 --  This function calculates the number of address bits required 
 -- to support the CE generation logic. This is determined by 
 -- multiplying the number of CEs for an address space by the 
 -- data width of the address space (in bytes). Each address
 -- space entry is processed and the biggest of the spaces is 
 -- used to set the number of address bits required to be latched
 -- and used for CE decoding. A minimum value of 1 is returned by
 -- this function.
 --
 -------------------------------------------------------------------
 function needed_addr_bits (ce_array   : INTEGER_ARRAY_TYPE;
                            size_array : INTEGER_ARRAY_TYPE) 
                            return integer is

    Constant NUM_CE_ENTRIES : integer := CE_ARRAY'length;
   
    Variable biggest : Integer := 2; -- forces a minimum return value
                                     -- of 1 (log2(2) = 1).
    
    Variable req_ce_addr_size : Integer := 0;
    Variable num_addr_bits : Integer := 0;
    
 begin

    for i in 0 to NUM_CE_ENTRIES-1 loop
    
                                         
       req_ce_addr_size := ce_array(i) * (size_array(i)/8);                                  
                                         
                                         
       If (req_ce_addr_size > biggest) Then
     
          biggest := req_ce_addr_size;
          
       End if;
             
    end loop;
    
    num_addr_bits := log2(biggest);
    
    return(num_addr_bits);
    
 end function NEEDED_ADDR_BITS;








-- Components------------------------------------------------------------------
  
  



-- constants

Constant ARD32_ADDR_RANGE_ARRAY : short_addr_array_type := 
                                  slv64_2_slv32(C_ARD_ADDR_RANGE_ARRAY);




constant NUM_BASE_ADDRS  : integer := (C_ARD_ADDR_RANGE_ARRAY'length)/2;

Constant DECODE_BITS     : decode_bit_array_type := Get_Addr_Bits(ARD32_ADDR_RANGE_ARRAY);

Constant NUM_SIZES       : integer := C_ARD_DWIDTH_ARRAY'length;

Constant NUM_CE_SIGNALS  : integer := calc_num_ce(C_ARD_NUM_CE_ARRAY);

Constant NUM_S_H_ADDR_BITS : integer := needed_addr_bits(C_ARD_NUM_CE_ARRAY,
                                                         C_ARD_DWIDTH_ARRAY);



-- Signals
 signal pselect_hit_i   : std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
 signal CS_Out_i        : std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
 signal CS_Out_S_H      : std_logic_vector(0 to ((C_ARD_ADDR_RANGE_ARRAY'LENGTH)/2)-1);
 signal CE_Expnd_i      : std_logic_vector(0 to NUM_CE_SIGNALS-1);  
 signal CE_Out_i        : std_logic_vector(0 to NUM_CE_SIGNALS-1);  
 signal RDCE_Out_i      : std_logic_vector(0 to NUM_CE_SIGNALS-1);  
 signal WRCE_Out_i      : std_logic_vector(0 to NUM_CE_SIGNALS-1);  
 signal CS_Size_i       : std_logic_vector(0 to 2); 
 signal CS_Size_i_reg   : std_logic_vector(0 to 2); 
 signal CS_Size_array   : size_array_type;
 Signal size_or_bus     : std_logic_vector(0 to (3*NUM_SIZES)-1);
 Signal decode_hit      : std_logic_vector(0 to 0);
 Signal decode_hit_reg  : std_logic;

 Signal cs_s_h_clr      : std_logic;
 Signal cs_ce_clr       : std_logic;
 Signal rdce_clr        : std_logic;
 Signal wrce_clr        : std_logic;
 Signal addr_match_clr  : std_logic;
 Signal RNW_S_H         : std_logic;
 Signal Addr_Out_S_H    : std_logic_vector(0 to NUM_S_H_ADDR_BITS-1);


------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------

begin -- architecture IMP
  
   
  -- Register clears
  
  cs_s_h_clr <= Bus_rst or cs_sample_hold_clr;
  
  cs_ce_clr  <= Bus_rst or Clear_CS_CE_Reg;
  
  rdce_clr   <= Bus_rst or Clear_RW_CE_Reg or not(RNW_S_H);
  
  wrce_clr   <= Bus_rst or Clear_RW_CE_Reg or RNW_S_H;
   
  addr_match_clr <= Bus_rst or Clear_addr_match; 
  
  ------------------------------------------------------------
  -- For Generate
  --
  -- Label: GEN_S_H_ADDR_REG
  --
  -- For Generate Description:
  --        This ForGen implements the Sample and Hold 
  -- register for the input PLB address. Only those LS address 
  -- bits needed for CE generation are registered. 
  --
  ------------------------------------------------------------
  GEN_S_H_ADDR_REG : for addr_bit_index in 0 to NUM_S_H_ADDR_BITS-1 generate

    Constant START_ADDR_INDEX : integer := C_BUS_AWIDTH - 
                                           NUM_S_H_ADDR_BITS;
  
  begin
    
      I_ADDR_S_H_REG : FDRE
        port map(
          Q  =>  Addr_Out_S_H(addr_bit_index),  
          C  =>  Bus_clk,                
          CE =>  cs_sample_hold_n,       
          D  =>  Address_In(START_ADDR_INDEX+addr_bit_index),  
          R  =>  cs_s_h_clr                 
        );
    
  end generate GEN_S_H_ADDR_REG;
  
  
  -- Instantate sample and hold register for the PLB RNW 
   
  I_RNW_S_H_REG : FDRE
    port map(
      Q  =>  RNW_S_H,  
      C  =>  Bus_clk,                
      CE =>  cs_sample_hold_n,       
      D  =>  Bus_RNW,  
      R  =>  cs_s_h_clr                 
    );


      
      
  -----------------------------------------------------------------------------
  -- Universal Address Decode Block
  -----------------------------------------------------------------------------
  
  MEM_DECODE_GEN: for bar_index in 0 to NUM_BASE_ADDRS-1 generate
    
      
  begin  
      
      -- Instantiate the basic Base Address Decoders
      MEM_SELECT_I: entity proc_common_v2_00_a.pselect
        generic map (
          C_AB     => DECODE_BITS(bar_index),
          C_AW     => C_BUS_AWIDTH,
          C_BAR    => ARD32_ADDR_RANGE_ARRAY(bar_index*2)
            )
        port map (
          A        => Address_In,       -- [in]
          AValid   => Address_Valid,     -- [in]
          CS       => pselect_hit_i(bar_index)  -- [out]
                );        
 
       
       
       -- Instantate sample and hold registers for the Chip Selects
       
      I_CS_S_H_REG : FDRE
        port map(
          Q  =>  CS_Out_S_H(bar_index),  
          C  =>  Bus_clk,                
          CE =>  cs_sample_hold_n,       
          D  =>  pselect_hit_i(bar_index),  
          R  =>  cs_s_h_clr                 
        );
    
       
       -- Instantate backend registers for the Chip Selects
       
      I_BKEND_CS_REG : FDRE
        port map(
          Q  =>  CS_Out_i(bar_index),  
          C  =>  Bus_clk,              
          CE =>  CS_CE_ld_enable,      
          D  =>  CS_Out_S_H(bar_index),
          R  =>  cs_ce_clr 
        );
    
       
       -- Generate the size outputs
       Assign_size : process (CS_Out_S_H(bar_index))
           Begin
             
             If (CS_Out_S_H(bar_index) = '1') Then
                CS_Size_array(bar_index) <=  encode_size(C_ARD_DWIDTH_ARRAY(bar_index));
             else
                CS_Size_array(bar_index) <= (others => '0');
             End if;
               
           End process; -- assign_size
       
       
       
       
       -- Now expand the individual chip enables for each base address
       DECODE_REGBITS: for ce_index in 0 to C_ARD_NUM_CE_ARRAY(bar_index)-1 generate
          
          Constant NEXT_CE_INDEX_START   : integer := calc_start_ce_index(C_ARD_NUM_CE_ARRAY,bar_index);
          
          --constant CE_DECODE_ADDR_SIZE   : Integer range 0 to 15 := log2(C_ARD_NUM_CE_ARRAY(bar_index));   
          constant CE_DECODE_ADDR_SIZE   : Integer range 0 to NUM_S_H_ADDR_BITS := log2(C_ARD_NUM_CE_ARRAY(bar_index));   
          
       begin
          
          ---------------------------------------------------------------------
          -- There is only one CE required so just use the output of the 
          -- Sample and hold CS register as the CE.
          ---------------------------------------------------------------------
          CE_IS_CS : if (CE_DECODE_ADDR_SIZE = 0) generate
              
            Constant ARRAY_INDEX           : integer := ce_index;
            Constant BASEADDR_INDEX        : integer := bar_index;
          
          begin
              
              CE_Expnd_i(NEXT_CE_INDEX_START+ARRAY_INDEX) <= CS_Out_S_H(BASEADDR_INDEX);
          
          
          end generate CE_IS_CS;  

                    
          
          ---------------------------------------------------------------------
          -- Multiple CEs are required so expand and decode as needed by the 
          -- specified number of CEs and address bits.
          ---------------------------------------------------------------------
          CE_EXPAND : if (CE_DECODE_ADDR_SIZE > 0) generate
            
            
            Constant ARRAY_INDEX           : integer := ce_index;
            Constant BASEADDR_INDEX        : integer := bar_index;
            
            
            --constant CE_DECODE_SKIP_BITS   : Integer range 0 to 8  := log2(C_ARD_DWIDTH_ARRAY(BASEADDR_INDEX)/8); 
            constant CE_DECODE_SKIP_BITS   : Integer range 0 to NUM_S_H_ADDR_BITS  := log2(C_ARD_DWIDTH_ARRAY(BASEADDR_INDEX)/8); 
            
            --constant CE_ADDR_WIDTH         : Integer range 0 to 31 := CE_DECODE_ADDR_SIZE + CE_DECODE_SKIP_BITS;   
            constant CE_ADDR_WIDTH         : Integer range 0 to NUM_S_H_ADDR_BITS := CE_DECODE_ADDR_SIZE + CE_DECODE_SKIP_BITS;   
              
            -- constant ADDR_START_INDEX      : integer range 0 to 31 := C_BUS_AWIDTH-CE_ADDR_WIDTH;
            -- constant ADDR_END_INDEX        : integer range 0 to 31 := C_BUS_AWIDTH-CE_DECODE_SKIP_BITS-1;
            constant ADDR_START_INDEX      : integer range 0 to NUM_S_H_ADDR_BITS := NUM_S_H_ADDR_BITS-CE_ADDR_WIDTH;
            constant ADDR_END_INDEX        : integer range 0 to NUM_S_H_ADDR_BITS := NUM_S_H_ADDR_BITS-CE_DECODE_SKIP_BITS-1;
          
          
            Signal   compare_address  : std_logic_vector(0 to CE_DECODE_ADDR_SIZE-1);
             
          begin   
             
             INDIVIDUAL_CE_GEN : process (Addr_Out_S_H,
                                          --Address_In, 
                                          CS_Out_S_H(BASEADDR_INDEX), 
                                          compare_address)
                Begin
                   
                  --compare_address <= Address_In(ADDR_START_INDEX to ADDR_END_INDEX);
                  compare_address <= Addr_Out_S_H(ADDR_START_INDEX to ADDR_END_INDEX);
                  
                  if compare_address = ARRAY_INDEX then
                      CE_Expnd_i(NEXT_CE_INDEX_START+ARRAY_INDEX) <= CS_Out_S_H(BASEADDR_INDEX);
                  else
                      CE_Expnd_i(NEXT_CE_INDEX_START+ARRAY_INDEX) <= '0';
                  
                  end if;
                                  
                    
                End process INDIVIDUAL_CE_GEN;  
          
          end generate CE_EXPAND;  

          
          
                          
       end generate DECODE_REGBITS;
  
  
  end generate MEM_DECODE_GEN;    



   OR_CS_Size : process (CS_Size_array)
      Begin

        for i in 0 to NUM_SIZES-1 loop
    
           size_or_bus(3*i to 3*i+2) <= CS_Size_array(i);
          
        End loop; 
        
      End process; -- OR_CS_SIZE


   I_OR_SIZES :  entity proc_common_v2_00_a.or_gate 
     generic map(
       C_OR_WIDTH   => NUM_SIZES,
       C_BUS_WIDTH  => 3,
       C_USE_LUT_OR => TRUE
       )
     port map(
       A => size_or_bus,
       Y => CS_Size_i
       );

 

   I_OR_CS :  entity proc_common_v2_00_a.or_gate 
     generic map(
       C_OR_WIDTH   => NUM_BASE_ADDRS,
       C_BUS_WIDTH  => 1,
       C_USE_LUT_OR => TRUE
       )
     port map(
       A => pselect_hit_i,
       Y => decode_hit
       );

                       
                       
    ------------------------------------------------------------
    -- For Generate
    --
    -- Label: GEN_BKEND_CE_REGISTERS
    --
    -- For Generate Description:
    --      This ForGen implements the backend registering for
    --  the CE, RdCE, and WrCE output buses.
    --
    --
    --
    ------------------------------------------------------------
    GEN_BKEND_CE_REGISTERS : for ce_index in 0 to NUM_CE_SIGNALS-1 generate
       -- local variables
       -- local constants
       -- local signals
       -- local component declarations
    
    begin
    
      
       -- Instantate Backend CE register
       
      I_BKEND_CE_REG : FDRE
        port map(
          Q  =>  CE_Out_i(ce_index),            
          C  =>  Bus_clk,                       
          CE =>  CS_CE_ld_enable,               
          D  =>  CE_Expnd_i(ce_index),          
          R  =>  cs_ce_clr     
        );
      

       -- Instantate Backend RdCE register
       
      I_BKEND_RDCE_REG : FDRE
        port map(
          Q  =>  RdCE_Out_i(ce_index),          
          C  =>  Bus_clk,                       
          CE =>  RW_CE_ld_enable,               
          D  =>  CE_Expnd_i(ce_index),          
          R  =>  rdce_clr
        );
      
      
       -- Instantate Backend WrCE register
       
      I_BKEND_WRCE_REG : FDRE
        port map(
          Q  =>  WrCE_Out_i(ce_index),          
          C  =>  Bus_clk,                       
          CE =>  RW_CE_ld_enable,               
          D  =>  CE_Expnd_i(ce_index),          
          R  =>  wrce_clr
        );
      
            
    end generate GEN_BKEND_CE_REGISTERS;
                       
                       
                       
                       
                       
    -- Instantate Address Match register
    
   I_ADDR_MATCH_REG : FDRE
     port map(
       Q  =>  decode_hit_reg,          
       C  =>  Bus_clk,                       
       CE =>  '1',               
       D  =>  decode_hit(0),          
       R  =>  addr_match_clr
     );
                    
                       
    -- Instantate CS Size registers
    
   I_CS_SIZE_REG0 : FDRE
     port map(
       Q  =>  CS_Size_i_reg(0),          
       C  =>  Bus_clk,                       
       CE =>  CS_CE_ld_enable,               
       D  =>  CS_Size_i(0),          
       R  =>  cs_ce_clr
     );
                       
   I_CS_SIZE_REG1 : FDRE
     port map(
       Q  =>  CS_Size_i_reg(1),          
       C  =>  Bus_clk,                       
       CE =>  CS_CE_ld_enable,               
       D  =>  CS_Size_i(1),          
       R  =>  cs_ce_clr
     );
                       
   I_CS_SIZE_REG2 : FDRE
     port map(
       Q  =>  CS_Size_i_reg(2),          
       C  =>  Bus_clk,                       
       CE =>  CS_CE_ld_enable,               
       D  =>  CS_Size_i(2),          
       R  =>  cs_ce_clr
     );
                       

                     
  -- Assign registered output signals
                                   
  Addr_Match   <= decode_hit_reg ;
  CS_Out       <= CS_Out_i   ;
  CS_Size      <= CS_Size_i_reg  ;
  CE_Out       <= CE_Out_i   ;
  RdCE_Out     <= RdCE_Out_i ;
  WrCE_Out     <= WrCE_Out_i ;



-- Assign early timing output for Address Match.
-- This is unregistered so it occurs 1 clock early
-- but may induce large Fmax timing paths

Addr_Match_early   <= decode_hit(0) ;  
CS_Out_Early       <= CS_Out_S_H;
PSelect_Hit        <= pselect_hit_i;
                       
                       
                       
-------------------------------------------------------------------------------
-- end of decoder block
-------------------------------------------------------------------------------

          
end architecture IMP;

