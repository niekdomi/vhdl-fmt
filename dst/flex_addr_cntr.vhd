-------------------------------------------------------------------------------
-- $Id: flex_addr_cntr.vhd,v 1.3 2004/11/16 00:16:13 dougt Exp $
-------------------------------------------------------------------------------
-- flex_addr_cntr.vhd
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
-- Filename:        flex_addr_cntr.vhd
--
-- Description:     
--    This VHDL design file implements a flexible counter that is used to implement 
-- the address counting function needed for PLB Slave devices. It provides the
-- ability to increment addresses in the following manner:
--  - linear incrementing x1, x2, x4, x8, x16, x32, x64, x128 (burst support)             
--  - 4 word cacheline (x8 count)
--  - 8 word cacheline (x8 count)
--  - 16 word cacheline (x8 count)
--  - growth  32 word cacheln (x8, x16 count)                 
--                  
-- Special notes:
--
--  - Count enables must be held low during load operations
--  - Clock enables must be asserted during load operations                 
--  
--
--
-- This file also implements the BE generator function.
--
--
--                
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--              flex_addr_cntr.vhd
--
-------------------------------------------------------------------------------
-- Author:          DET
-- Revision:        $Revision: 1.3 $
-- Date:            $3/11/2003$
--
-- History:
--   DET   3/11/2003       Initial Version
--                      
--
--     DET     7/10/2003     Granite Rls PLB IPIF V1.00.e
-- ~~~~~~
--     - Removed XON generic from LUT4 component declaration and instances.
-- ^^^^^^
--
--
--     DET     4/12/2004     IPIF to V1_00_f
-- ~~~~~~
--     - Updated unisim library reference to unisim.vcomponents.all
--     - Commented out Xilinx primitive component declarations
-- ^^^^^^
--
--
--     DET     11/15/2004     EDK_Gmm_SP2
-- ~~~~~~
--     - Changed counter so that the 3 LSB's of the Addr_out port are cleared
--       during cacheline operations.
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


library unisim;
use unisim.vcomponents.all;


-------------------------------------------------------------------------------

entity flex_addr_cntr is
  Generic (
     C_AWIDTH : integer := 32
     );
    
  port (
    Clk            : in  std_logic;
    Rst            : in  std_logic;
    
   -- address generation 
    Load_Enable    : in  std_logic;
    Load_addr      : in  std_logic_vector(C_AWIDTH-1 downto 0);
    Cnt_by_1       : in  std_logic;
    Cnt_by_2       : in  std_logic;
    Cnt_by_4       : in  std_logic;
    Cnt_by_8       : in  std_logic;
    Cnt_by_16      : in  std_logic;
    Cnt_by_32      : in  std_logic;
    Cnt_by_64      : in  std_logic;
    Cnt_by_128     : in  std_logic;
    Clk_En_0       : in  std_logic;
    Clk_En_1       : in  std_logic;
    Clk_En_2       : in  std_logic;
    Clk_En_3       : in  std_logic;
    Clk_En_4       : in  std_logic;
    Clk_En_5       : in  std_logic;
    Clk_En_6       : in  std_logic;
    Clk_En_7       : in  std_logic;
    Addr_out       : out std_logic_vector(C_AWIDTH-1 downto 0);
    Carry_Out      : out std_logic;
    
   -- BE Generation 
    Single_beat    : In  std_logic;
    Cacheline      : In  std_logic;
    burst_bytes    : In  std_logic;
    burst_hwrds    : In  std_logic;
    burst_words    : In  std_logic;
    burst_dblwrds  : In  std_logic;
    BE_clk_en      : in  std_logic;
    BE_in          : In  std_logic_vector(0 to 7);
    BE_out         : Out std_logic_vector(0 to 7)
   );

end entity flex_addr_cntr;


architecture implementation of flex_addr_cntr is

  -- Constants
  -- Types
  -- Counter Signals
     Signal lut_out        : std_logic_vector(C_AWIDTH-1 downto 0);
     Signal addr_out_i     : std_logic_vector(C_AWIDTH-1 downto 0);
     Signal next_addr_i    : std_logic_vector(C_AWIDTH-1 downto 0);
     Signal Cout           : std_logic_vector(C_AWIDTH downto 0);
   
   -- BE Gen signals
     Signal x8x4           : std_logic;
     Signal decoded_be     : std_logic_vector(0 to 3);
     --Signal reset_be0_3    : std_logic;
     --Signal reset_be4_7    : std_logic;
     Signal be_next        : std_logic_vector(0 to 7);
     Signal set_all_be     : std_logic;
     
     Signal addr_lsb_clear : std_logic;
     
     
  -- Component Declarations
  
  -- Xilinx Prim    component LUT4 is
  -- Xilinx Prim      generic(
  -- Xilinx Prim        INIT : bit_vector := X"0000"
  -- Xilinx Prim        );
  -- Xilinx Prim      port (
  -- Xilinx Prim        O  : out std_logic;
  -- Xilinx Prim        I0 : in  std_logic;
  -- Xilinx Prim        I1 : in  std_logic;
  -- Xilinx Prim        I2 : in  std_logic;
  -- Xilinx Prim        I3 : in  std_logic);
  -- Xilinx Prim    end component LUT4;

  -- Xilinx Prim    component MUXCY is
  -- Xilinx Prim      port (
  -- Xilinx Prim        DI : in  std_logic;
  -- Xilinx Prim        CI : in  std_logic;
  -- Xilinx Prim        S  : in  std_logic;
  -- Xilinx Prim        O  : out std_logic);
  -- Xilinx Prim    end component MUXCY;

  -- Xilinx Prim    component XORCY is
  -- Xilinx Prim      port (
  -- Xilinx Prim        LI : in  std_logic;
  -- Xilinx Prim        CI : in  std_logic;
  -- Xilinx Prim        O  : out std_logic);
  -- Xilinx Prim    end component XORCY;
  
  -- Xilinx Prim    component FDRE is
  -- Xilinx Prim      port (
  -- Xilinx Prim        Q  : out std_logic;
  -- Xilinx Prim        C  : in  std_logic;
  -- Xilinx Prim        CE : in  std_logic;
  -- Xilinx Prim        D  : in  std_logic;
  -- Xilinx Prim        R  : in  std_logic
  -- Xilinx Prim      );
  -- Xilinx Prim    end component FDRE;

 
  -- Xilinx Prim    component FDRSE
  -- Xilinx Prim      port(
  -- Xilinx Prim        Q   :     out std_logic;
  -- Xilinx Prim        C   :     in  std_logic;
  -- Xilinx Prim        CE  :     in  std_logic;
  -- Xilinx Prim        D   :     in  std_logic;    
  -- Xilinx Prim        R   :     in  std_logic;
  -- Xilinx Prim        S   :     in  std_logic
  -- Xilinx Prim        );
  -- Xilinx Prim    end component;
 
 
 
  
  attribute INIT       : string;  -- used for LUTs
  

begin --(architecture implementation)



  -- Misc logic assignments
  
   Addr_out       <= addr_out_i;
 
   Carry_Out      <= Cout(C_AWIDTH);
 
   addr_lsb_clear <= Rst or Cacheline;



   ------------------------------------------------------------
   -- For Generate
   --
   -- Label: GEN_ADDR_MSB
   --
   -- For Generate Description:
   --   This For-Gen implements bits 7 and beyond for the the 
   -- address counter. The entire slice shares the same clock
   -- enable.
   --
   --
   --
   ------------------------------------------------------------
   GEN_ADDR_MSB : for addr_bit_index in 7 to C_AWIDTH-1 generate
      -- local variables
      -- local constants
      -- local signals
      -- local component declarations
   
   begin
   
   
      ------------------------------------------------------------------------------- 
      ---- Address Counter Bits 7 to max address bit  
     
     
      I_LUT_N : LUT4
        generic map(
          INIT => X"F202"
          )
        port map (
          O  => lut_out(addr_bit_index),        
          I0 => addr_out_i(addr_bit_index),     
          I1 => '0',     
          I2 => Load_Enable,       
          I3 => Load_addr(addr_bit_index)       
          );                       

      I_MUXCY_N : MUXCY
        port map (
          DI => '0',
          CI => Cout(addr_bit_index),
          S  => lut_out(addr_bit_index),
          O  => Cout(addr_bit_index+1)
          );

      I_XOR_N : XORCY
        port map (
          LI => lut_out(addr_bit_index),
          CI => Cout(addr_bit_index),
          O  => next_addr_i(addr_bit_index)
          );

      I_FDRE_N: FDRE
        port map (
          Q  => addr_out_i(addr_bit_index),  
          C  => Clk,            
          CE => Clk_En_7,       
          D  => next_addr_i(addr_bit_index), 
          R  => Rst             
          );      

   
   end generate GEN_ADDR_MSB;

 

------------------------------------------------------------------------------- 
---- Address Counter Bit 6  
 
 
  I_LUT6 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(6),        
      I0 => addr_out_i(6),     
      I1 => Cnt_by_128,     
      I2 => Load_Enable,       
      I3 => Load_addr(6)       
      );                       

  I_MUXCY6 : MUXCY
    port map (
      DI => Cnt_by_128,
      CI => Cout(6),
      S  => lut_out(6),
      O  => Cout(7)
      );

  I_XOR6 : XORCY
    port map (
      LI => lut_out(6),
      CI => Cout(6),
      O  => next_addr_i(6)
      );

  I_FDRE6 : FDRE
    port map (
      Q  => addr_out_i(6),  
      C  => Clk,            
      CE => Clk_En_6,       
      D  => next_addr_i(6), 
      R  => Rst             
      );      

  
 
 
------------------------------------------------------------------------------- 
---- Address Counter Bit 5  
 
 
  I_LUT5 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(5),        
      I0 => addr_out_i(5),     
      I1 => Cnt_by_64,     
      I2 => Load_Enable,       
      I3 => Load_addr(5)       
      );                       

  I_MUXCY5 : MUXCY
    port map (
      DI => Cnt_by_64,
      CI => Cout(5),
      S  => lut_out(5),
      O  => Cout(6)
      );

  I_XOR5 : XORCY
    port map (
      LI => lut_out(5),
      CI => Cout(5),
      O  => next_addr_i(5)
      );

  I_FDRE5: FDRE
    port map (
      Q  => addr_out_i(5),  
      C  => Clk,            
      CE => Clk_En_5,       
      D  => next_addr_i(5), 
      R  => Rst             
      );      

  
 
 
------------------------------------------------------------------------------- 
---- Address Counter Bit 4  
 
 
  I_LUT4 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(4),        
      I0 => addr_out_i(4),     
      I1 => Cnt_by_32,     
      I2 => Load_Enable,       
      I3 => Load_addr(4)       
      );                       

  I_MUXCY4 : MUXCY
    port map (
      DI => Cnt_by_32,
      CI => Cout(4),
      S  => lut_out(4),
      O  => Cout(5)
      );

  I_XOR4 : XORCY
    port map (
      LI => lut_out(4),
      CI => Cout(4),
      O  => next_addr_i(4)
      );

  I_FDRE4: FDRE
    port map (
      Q  => addr_out_i(4),  
      C  => Clk,            
      CE => Clk_En_4,       
      D  => next_addr_i(4), 
      R  => Rst             
      );      

  
 
 
------------------------------------------------------------------------------- 
---- Address Counter Bit 3  
 
 
  I_LUT3 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(3),        
      I0 => addr_out_i(3),     
      I1 => Cnt_by_16,     
      I2 => Load_Enable,       
      I3 => Load_addr(3)       
      );                       

  I_MUXCY3 : MUXCY
    port map (
      DI => Cnt_by_16,
      CI => Cout(3),
      S  => lut_out(3),
      O  => Cout(4)
      );

  I_XOR3 : XORCY
    port map (
      LI => lut_out(3),
      CI => Cout(3),
      O  => next_addr_i(3)
      );

  I_FDRE3: FDRE
    port map (
      Q  => addr_out_i(3),  
      C  => Clk,            
      CE => Clk_En_3,       
      D  => next_addr_i(3), 
      R  => Rst             
      );      

  
 
 
------------------------------------------------------------------------------- 
---- Address Counter Bit 2  
 
 
  I_LUT2 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(2),        
      I0 => addr_out_i(2),     
      I1 => Cnt_by_8,     
      I2 => Load_Enable,       
      I3 => Load_addr(2)       
      );                       

  I_MUXCY2 : MUXCY
    port map (
      DI => Cnt_by_8,
      CI => Cout(2),
      S  => lut_out(2),
      O  => Cout(3)
      );

  I_XOR2 : XORCY
    port map (
      LI => lut_out(2),
      CI => Cout(2),
      O  => next_addr_i(2)
      );

  I_FDRE2: FDRE
    port map (
      Q  => addr_out_i(2),  
      C  => Clk,            
      CE => Clk_En_2,       
      D  => next_addr_i(2), 
      R  => addr_lsb_clear             
      );      

  
 
 
------------------------------------------------------------------------------- 
---- Address Counter Bit 1  
 
 
  I_LUT1 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(1),        
      I0 => addr_out_i(1),     
      I1 => Cnt_by_4,     
      I2 => Load_Enable,       
      I3 => Load_addr(1)       
      );                       

  I_MUXCY1 : MUXCY
    port map (
      DI => Cnt_by_4,
      CI => Cout(1),
      S  => lut_out(1),
      O  => Cout(2)
      );

  I_XOR1 : XORCY
    port map (
      LI => lut_out(1),
      CI => Cout(1),
      O  => next_addr_i(1)
      );

  I_FDRE1: FDRE
    port map (
      Q  => addr_out_i(1),  
      C  => Clk,            
      CE => Clk_En_1,       
      D  => next_addr_i(1), 
      R  => addr_lsb_clear             
      );      

 
 
------------------------------------------------------------------------------- 
---- Address Counter Bit 0  
 
 
  I_LUT0 : LUT4
    generic map(
      INIT => X"F202"
      )
    port map (
      O  => lut_out(0),        
      I0 => addr_out_i(0),     
      I1 => Cnt_by_2,     
      I2 => Load_Enable,       
      I3 => Load_addr(0)       
      );                       

  I_MUXCY0 : MUXCY
    port map (
      DI => Cnt_by_2,
      CI => Cout(0),
      S  => lut_out(0),
      O  => Cout(1)
      );

  I_XOR0 : XORCY
    port map (
      LI => lut_out(0),
      CI => Cout(0),
      O  => next_addr_i(0)
      );

  I_FDRE0: FDRE
    port map (
      Q  => addr_out_i(0),  
      C  => Clk,            
      CE => Clk_En_0,       
      D  => next_addr_i(0), 
      R  => addr_lsb_clear             
      );      

 
 
 
------------------------------------------------------------------------------- 
---- Carry in selection for LS Bit  
 
 
  I_MUXCY : MUXCY
    port map (
      DI => Cnt_by_1,
      CI => '0',
      S  => Load_Enable,
      O  => Cout(0)
      );

 







------------------------------------------------------------------------------- 
------------------------------------------------------------------------------- 
---- BE Generator  (15 LUTs, 8 FDREs)

  
  --x8x4 <= Cnt_by_8 or Cnt_by_4;
  --x8x4 <= burst_dblwrds or burst_words or Cacheline;
  
  set_all_be <=  burst_dblwrds or Cacheline;
  


  I_BE_GEN_LUT0 : LUT4
    generic map(
      INIT => X"FF31"
      )
    port map (
      O  => decoded_be(0),     
      I0 => next_addr_i(0),     
      I1 => next_addr_i(1),
      I2 => burst_hwrds,     
      I3 => burst_words     
      );                       

  I_BE_GEN_LUT1 : LUT4
    generic map(
      INIT => X"FF32"
      )
    port map (
      O  => decoded_be(1),     
      I0 => next_addr_i(0),     
      I1 => next_addr_i(1),
      I2 => burst_hwrds,     
      I3 => burst_words     
      );                       

  I_BE_GEN_LUT2 : LUT4
    generic map(
      INIT => X"FFC4"
      )
    port map (
      O  => decoded_be(2),     
      I0 => next_addr_i(0),     
      I1 => next_addr_i(1),
      I2 => burst_hwrds,     
      I3 => burst_words     
      );                       

  I_BE_GEN_LUT4 : LUT4
    generic map(
      INIT => X"FFC8"
      )
    port map (
      O  => decoded_be(3),     
      I0 => next_addr_i(0),     
      I1 => next_addr_i(1),
      I2 => burst_hwrds,     
      I3 => burst_words     
      );                       

  
  
  

  
  
  ------------------------------------------------------------
  -- For Generate
  --
  -- Label: LDMUX_FDRSE_0to3
  --
  -- For Generate Description:
  --    Implements Load Mux and Output register for BE_out bits
  --    0 to 3.
  --
  --
  --
  ------------------------------------------------------------
  LDMUX_FDRSE_0to3 : for BE_index in 0 to 3 generate
  
  begin
      I_BE_LDMUX_0to3 : LUT4
        generic map(
          INIT => X"F022"
          )
        port map (
          O  => be_next(BE_index),     
          I0 => decoded_be(BE_index),               
          I1 => next_addr_i(2),                  
          I2 => BE_in(BE_index),     
          I3 => Single_beat     
          );                       
   
      I_FDRSE_BE0to3: FDRSE
        port map (
          Q  => BE_out(BE_index),  
          C  => Clk,            
          CE => BE_clk_en,       
          D  => be_next(BE_index), 
          R  => Rst,
          S  => set_all_be             
          );      
  
  end generate LDMUX_FDRSE_0to3;
  
  
  
  
  ------------------------------------------------------------
  -- For Generate
  --
  -- Label: LDMUX_FDRSE_4to7
  --
  -- For Generate Description:
  --    Implements Load Mux and Output register for BE_out bits
  --    4 to 7.
  --
  --
  --
  ------------------------------------------------------------
  LDMUX_FDRSE_4to7 : for BE_index in 4 to 7 generate
  
  begin
      I_BE_LDMUX_4to7 : LUT4
        generic map(
          INIT => X"F088"
          )
        port map (
          O  => be_next(BE_index),     
          I0 => decoded_be(BE_index-4),     
          I1 => next_addr_i(2),
          I2 => BE_in(BE_index),     
          I3 => Single_beat     
          );                       
   
      I_FDRSE_BE4to7: FDRSE
        port map (
          Q  => BE_out(BE_index),  
          C  => Clk,            
          CE => BE_clk_en,       
          D  => be_next(BE_index), 
          R  => Rst,
          S  => set_all_be             
          );      
  
  end generate LDMUX_FDRSE_4to7;
  
  

  
  
  
  
 --- End of BE Generation










end implementation;
