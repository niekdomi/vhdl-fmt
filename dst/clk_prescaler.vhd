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
--  File:     clk_prescaler.vhd                                           --
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
use ieee.std_logic_unsigned.all;


entity clk_prescaler is
    port(
      CLK         : in std_logic;
      CLK_EN      : in std_logic;
      div_1       : in std_logic;
      div_2       : in std_logic;
      div_3       : in std_logic;
      MR          : in std_logic;
      pre_0       : in std_logic;
      pre_1       : in std_logic;
      clk_1us     : out std_logic);
end entity clk_prescaler;



architecture rtl_clk_prescaler of clk_prescaler is

   SIGNAL clk_prescaled            :  std_logic;   
   SIGNAL clk_div                  :  std_logic;
   SIGNAL end_div                  :  std_logic;
   SIGNAL clk_prescaled_reg        :  std_logic;
   SIGNAL div_cnt                  :  std_logic_vector(6 DOWNTO 0);   
   SIGNAL ClkPrescale              :  std_logic_vector(2 DOWNTO 0);
   SIGNAL rst_clk                  :  std_logic;
   SIGNAL en_clk                   :  std_logic;
   SIGNAL clk_1us_en               :  std_logic;
   SIGNAL concat_div               :  std_logic_vector(2 DOWNTO 0);   


   -- ClkPrescale state assignment
   CONSTANT  s0                    :  std_logic_vector(2 DOWNTO 0) := b"000"; 
   CONSTANT  s1                    :  std_logic_vector(2 DOWNTO 0) := b"001"; 
   CONSTANT  s2                    :  std_logic_vector(2 DOWNTO 0) := b"010"; 
   CONSTANT  s3                    :  std_logic_vector(2 DOWNTO 0) := b"011"; 
   CONSTANT  s4                    :  std_logic_vector(2 DOWNTO 0) := b"100"; 
   CONSTANT  s5                    :  std_logic_vector(2 DOWNTO 0) := b"101"; 
   CONSTANT  s6                    :  std_logic_vector(2 DOWNTO 0) := b"110";


   begin
       
       -- Continuous Assignment Statements
       clk_1us <= clk_1us_en and en_clk and CLK;
     concat_div <= div_3 & div_2 & div_1;
       rst_clk <= MR or (not CLK_EN);
       clk_prescaled <= en_clk and CLK;


       process (rst_clk, CLK)
           begin
               if (rst_clk='1') then
                  ClkPrescale <= s0;    
               elsif (CLK = '1' and CLK'event) then
                   case ClkPrescale is
                      when s0 => ClkPrescale <= s1;
                          
                      when s1 => ClkPrescale <= s2;

                      when s2 => if(pre_0='1' and pre_1='0') then
                                    ClkPrescale <= s0;
                                 else
                                    ClkPrescale <= s3;
                                 end if;

                      when s3 => ClkPrescale <= s4;

                      when s4 => if(pre_0='0' and pre_1='1') then
                                    ClkPrescale <= s0;
                                 else
                                    ClkPrescale <= s5;
                                 end if;

                      when s5 => ClkPrescale <= s6;

                      when s6 => ClkPrescale <= s0;
                          
                      when others => ClkPrescale <= s0;
                   end case;
               end if;
       end process;
       
       process(MR, CLK)
           begin
             if (MR='1') then
                clk_prescaled_reg <= '1';
             elsif (CLK='1' and CLK'event) then
                clk_prescaled_reg <= (not ClkPrescale(0)
                                  and (not ClkPrescale(1))
                                  and (not ClkPrescale(2))); 
             end if;
       end process;
       
       process(MR, CLK)
         begin
           if (MR='1') then
              en_clk <= '1';
           elsif (CLK='0' and CLK'event) then
              en_clk <= CLK_EN and (((not pre_0) and (not pre_1)) or 
              ((not ClkPrescale(2)) and (not ClkPrescale(1)) and (not ClkPrescale(0))));
           end if;
       end process;
       
  ----------------------------------------------------------------------------
  --  Clock Divider
  --  using clk_prescaled as its input, this divide-by-2 chain does the
  --  other clock division
  ----------------------------------------------------------------------------
       process(MR, CLK)
         begin
           if (MR='1') then
              div_cnt <= b"000_0000";
           elsif (CLK='1' and CLK'event) then
              if (en_clk='1') then
                div_cnt <= div_cnt + 1;
              end if;
           end if;    
       end process;
       
       process(MR, CLK)
         begin
          if (MR='1') then
             clk_1us_en <= '1';    
          elsif (CLK='0' and CLK'event) then
             case (concat_div) is
                when b"000" => clk_1us_en <= CLK_EN;
                when b"001" => clk_1us_en <= (not div_cnt(0));
                when b"010" => if (div_cnt(1 downto 0) = b"01") then
                                   clk_1us_en <= '1';
                               else
                                   clk_1us_en <= '0';
                               end if;
                when b"011" => if (div_cnt(2 downto 0) = b"011") then
                                   clk_1us_en <= '1';
                               else
                                   clk_1us_en <= '0';
                               end if;
                when b"100" => if (div_cnt(3 downto 0) = b"0111") then
                                   clk_1us_en <= '1';
                               else
                                   clk_1us_en <= '0';
                               end if;
                when b"101" => if (div_cnt(4 downto 0) = b"0_1111") then
                                   clk_1us_en <= '1';
                               else
                                   clk_1us_en <= '0';
                               end if;
                when b"110" => if (div_cnt(5 downto 0) = b"01_1111") then
                                   clk_1us_en <= '1';
                               else
                                   clk_1us_en <= '0';
                               end if;
                when b"111" => if (div_cnt(6 downto 0) = b"011_1111") then
                                   clk_1us_en <= '1';
                               else
                                   clk_1us_en <= '0';
                               end if;
                when others => clk_1us_en <= '0';
             end case;   
          end if;
       end process;
       
end architecture rtl_clk_prescaler;
