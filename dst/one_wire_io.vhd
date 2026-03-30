----------------------------------------------------------------------------
--                                                                        --
--  OneWireMaster                                                         --
--   A synthesizable 1-wire master peripheral                             --
--   Copyright 1999-2007 Dallas Semiconductor Corporation                 --
--                                                                        --
----------------------------------------------------------------------------
--                                                                        --
--  Purpose:  Provides timing and control of Dallas 1-wire bus            --
--            through a memory-mapped peripheral                          --
--  File:     one_wire_io.vhd                                             -- 
--  Date:     January 17, 2007                                            --
--  Version:  v1.100                                                      --
--  Authors:  Eric Hereford,                                              --
--            Dallas Semiconductor Corporation                            --
--                                                                        --
--  Note:     This source code is available for use without license.      --
--            Dallas Semiconductor is not responsible for the             --
--            functionality or utility of this product.                   --
--                                                                        --
--  REV:      Initial port based on v2.100 Verilog - EAH                  --
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity one_wire_io is
  port(
    CLK                        :  IN std_logic;
    DDIR                       :  IN std_logic;
    DOUT                       :  IN std_logic_vector(7 DOWNTO 0);
    DQ_CONTROL                 :  IN std_logic;
    MR                         :  IN std_logic;
    DIN                        :  OUT std_logic_vector(7 DOWNTO 0);
    DQ_IN                      :  OUT std_logic;
    DATA                       :  INOUT std_logic_vector(7 DOWNTO 0);
    DQ                         :  INOUT std_logic);
end one_wire_io;

architecture rtl_one_wire_io of one_wire_io is
    
  begin
  
    DATA <= DOUT when DDIR='1' else "ZZZZZZZZ";
    DIN <= DATA;
    DQ <= 'Z' when DQ_CONTROL='1' else '0';
    
    process(MR, CLK)
      begin
        if (MR='1') then
          DQ_IN <= '1';    
        elsif falling_edge(CLK) then
          DQ_IN <= DQ;    
        end if;    
    end process;
      
end architecture rtl_one_wire_io;
    