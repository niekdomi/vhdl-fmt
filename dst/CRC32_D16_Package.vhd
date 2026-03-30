-----------------------------------------------------------------------
-- Module:  CRC32_D16_Universal.vhd                              
-- Date:  Mon Feb 27 16:48:36 2006                                                      
--                                                                     
-- Copyright (C) 1999-2003 Easics NV.                 
-- This source file may be used and distributed without restriction    
-- provided that this copyright statement is not removed from the file 
-- and that any derivative work contains the original copyright notice
-- and the associated disclaimer.
--
-- THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
-- WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
--
-- Purpose: VHDL package containing a synthesizable CRC function
--   * polynomial: (0 1 2 4 5 7 8 10 11 12 16 22 23 26 32)
--   * data width: 16
--                                                                     
-- Info: tools@easics.be
--       http://www.easics.com                                  
-----------------------------------------------------------------------
--	18.12.2008-le : - add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 823                                                                   $
--$Author:: leuthold                                                           $
--$Date:: 2008-12-18 15:37:50 +0100 (Do., 18 Dez 2008)                         $
--------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

package PCK_CRC32_D16 is

  -- polynomial: (0 1 2 4 5 7 8 10 11 12 16 22 23 26 32)
  -- data width: 16
  -- convention: the first serial data bit is D(15)
  function nextCRC32_D16
    ( Data:  std_logic_vector(15 downto 0);
      CRC:   std_logic_vector(31 downto 0) )
    return std_logic_vector;

end PCK_CRC32_D16;

library IEEE;
use IEEE.std_logic_1164.all;

package body PCK_CRC32_D16 is

  -- polynomial: (0 1 2 4 5 7 8 10 11 12 16 22 23 26 32)
  -- data width: 16
  -- convention: the first serial data bit is D(15)
  function nextCRC32_D16  
    ( Data:  std_logic_vector(15 downto 0);
      CRC:   std_logic_vector(31 downto 0) )
    return std_logic_vector is

    variable D: std_logic_vector(15 downto 0);
    variable C: std_logic_vector(31 downto 0);
    variable NewCRC: std_logic_vector(31 downto 0);

  begin

    D := Data;
    C := CRC;

    NewCRC(0) := D(12) xor D(10) xor D(9) xor D(6) xor D(0) xor C(16) xor 
                 C(22) xor C(25) xor C(26) xor C(28);
    NewCRC(1) := D(13) xor D(12) xor D(11) xor D(9) xor D(7) xor D(6) xor 
                 D(1) xor D(0) xor C(16) xor C(17) xor C(22) xor C(23) xor 
                 C(25) xor C(27) xor C(28) xor C(29);
    NewCRC(2) := D(14) xor D(13) xor D(9) xor D(8) xor D(7) xor D(6) xor 
                 D(2) xor D(1) xor D(0) xor C(16) xor C(17) xor C(18) xor 
                 C(22) xor C(23) xor C(24) xor C(25) xor C(29) xor C(30);
    NewCRC(3) := D(15) xor D(14) xor D(10) xor D(9) xor D(8) xor D(7) xor 
                 D(3) xor D(2) xor D(1) xor C(17) xor C(18) xor C(19) xor 
                 C(23) xor C(24) xor C(25) xor C(26) xor C(30) xor C(31);
    NewCRC(4) := D(15) xor D(12) xor D(11) xor D(8) xor D(6) xor D(4) xor 
                 D(3) xor D(2) xor D(0) xor C(16) xor C(18) xor C(19) xor 
                 C(20) xor C(22) xor C(24) xor C(27) xor C(28) xor C(31);
    NewCRC(5) := D(13) xor D(10) xor D(7) xor D(6) xor D(5) xor D(4) xor 
                 D(3) xor D(1) xor D(0) xor C(16) xor C(17) xor C(19) xor 
                 C(20) xor C(21) xor C(22) xor C(23) xor C(26) xor C(29);
    NewCRC(6) := D(14) xor D(11) xor D(8) xor D(7) xor D(6) xor D(5) xor 
                 D(4) xor D(2) xor D(1) xor C(17) xor C(18) xor C(20) xor 
                 C(21) xor C(22) xor C(23) xor C(24) xor C(27) xor C(30);
    NewCRC(7) := D(15) xor D(10) xor D(8) xor D(7) xor D(5) xor D(3) xor 
                 D(2) xor D(0) xor C(16) xor C(18) xor C(19) xor C(21) xor 
                 C(23) xor C(24) xor C(26) xor C(31);
    NewCRC(8) := D(12) xor D(11) xor D(10) xor D(8) xor D(4) xor D(3) xor 
                 D(1) xor D(0) xor C(16) xor C(17) xor C(19) xor C(20) xor 
                 C(24) xor C(26) xor C(27) xor C(28);
    NewCRC(9) := D(13) xor D(12) xor D(11) xor D(9) xor D(5) xor D(4) xor 
                 D(2) xor D(1) xor C(17) xor C(18) xor C(20) xor C(21) xor 
                 C(25) xor C(27) xor C(28) xor C(29);
    NewCRC(10) := D(14) xor D(13) xor D(9) xor D(5) xor D(3) xor D(2) xor 
                  D(0) xor C(16) xor C(18) xor C(19) xor C(21) xor C(25) xor 
                  C(29) xor C(30);
    NewCRC(11) := D(15) xor D(14) xor D(12) xor D(9) xor D(4) xor D(3) xor 
                  D(1) xor D(0) xor C(16) xor C(17) xor C(19) xor C(20) xor 
                  C(25) xor C(28) xor C(30) xor C(31);
    NewCRC(12) := D(15) xor D(13) xor D(12) xor D(9) xor D(6) xor D(5) xor 
                  D(4) xor D(2) xor D(1) xor D(0) xor C(16) xor C(17) xor 
                  C(18) xor C(20) xor C(21) xor C(22) xor C(25) xor C(28) xor 
                  C(29) xor C(31);
    NewCRC(13) := D(14) xor D(13) xor D(10) xor D(7) xor D(6) xor D(5) xor 
                  D(3) xor D(2) xor D(1) xor C(17) xor C(18) xor C(19) xor 
                  C(21) xor C(22) xor C(23) xor C(26) xor C(29) xor C(30);
    NewCRC(14) := D(15) xor D(14) xor D(11) xor D(8) xor D(7) xor D(6) xor 
                  D(4) xor D(3) xor D(2) xor C(18) xor C(19) xor C(20) xor 
                  C(22) xor C(23) xor C(24) xor C(27) xor C(30) xor C(31);
    NewCRC(15) := D(15) xor D(12) xor D(9) xor D(8) xor D(7) xor D(5) xor 
                  D(4) xor D(3) xor C(19) xor C(20) xor C(21) xor C(23) xor 
                  C(24) xor C(25) xor C(28) xor C(31);
    NewCRC(16) := D(13) xor D(12) xor D(8) xor D(5) xor D(4) xor D(0) xor 
                  C(0) xor C(16) xor C(20) xor C(21) xor C(24) xor C(28) xor 
                  C(29);
    NewCRC(17) := D(14) xor D(13) xor D(9) xor D(6) xor D(5) xor D(1) xor 
                  C(1) xor C(17) xor C(21) xor C(22) xor C(25) xor C(29) xor 
                  C(30);
    NewCRC(18) := D(15) xor D(14) xor D(10) xor D(7) xor D(6) xor D(2) xor 
                  C(2) xor C(18) xor C(22) xor C(23) xor C(26) xor C(30) xor 
                  C(31);
    NewCRC(19) := D(15) xor D(11) xor D(8) xor D(7) xor D(3) xor C(3) xor 
                  C(19) xor C(23) xor C(24) xor C(27) xor C(31);
    NewCRC(20) := D(12) xor D(9) xor D(8) xor D(4) xor C(4) xor C(20) xor 
                  C(24) xor C(25) xor C(28);
    NewCRC(21) := D(13) xor D(10) xor D(9) xor D(5) xor C(5) xor C(21) xor 
                  C(25) xor C(26) xor C(29);
    NewCRC(22) := D(14) xor D(12) xor D(11) xor D(9) xor D(0) xor C(6) xor 
                  C(16) xor C(25) xor C(27) xor C(28) xor C(30);
    NewCRC(23) := D(15) xor D(13) xor D(9) xor D(6) xor D(1) xor D(0) xor 
                  C(7) xor C(16) xor C(17) xor C(22) xor C(25) xor C(29) xor 
                  C(31);
    NewCRC(24) := D(14) xor D(10) xor D(7) xor D(2) xor D(1) xor C(8) xor 
                  C(17) xor C(18) xor C(23) xor C(26) xor C(30);
    NewCRC(25) := D(15) xor D(11) xor D(8) xor D(3) xor D(2) xor C(9) xor 
                  C(18) xor C(19) xor C(24) xor C(27) xor C(31);
    NewCRC(26) := D(10) xor D(6) xor D(4) xor D(3) xor D(0) xor C(10) xor 
                  C(16) xor C(19) xor C(20) xor C(22) xor C(26);
    NewCRC(27) := D(11) xor D(7) xor D(5) xor D(4) xor D(1) xor C(11) xor 
                  C(17) xor C(20) xor C(21) xor C(23) xor C(27);
    NewCRC(28) := D(12) xor D(8) xor D(6) xor D(5) xor D(2) xor C(12) xor 
                  C(18) xor C(21) xor C(22) xor C(24) xor C(28);
    NewCRC(29) := D(13) xor D(9) xor D(7) xor D(6) xor D(3) xor C(13) xor 
                  C(19) xor C(22) xor C(23) xor C(25) xor C(29);
    NewCRC(30) := D(14) xor D(10) xor D(8) xor D(7) xor D(4) xor C(14) xor 
                  C(20) xor C(23) xor C(24) xor C(26) xor C(30);
    NewCRC(31) := D(15) xor D(11) xor D(9) xor D(8) xor D(5) xor C(15) xor 
                  C(21) xor C(24) xor C(25) xor C(27) xor C(31);

    return NewCRC;

  end nextCRC32_D16;

end PCK_CRC32_D16;

