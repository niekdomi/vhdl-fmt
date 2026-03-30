-------------------------------------------------------------------------------
-- $Id: counters.vhd,v 1.3 2005/02/03 22:51:10 gburch Exp $
-------------------------------------------------------------------------------
-- counters.vhd - entity/architecture pair
-------------------------------------------------------------------------------
--
--  ***************************************************************************
--  **  Copyright(C) 2004 by Xilinx, Inc. All rights reserved.               **
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
-- Filename:        counters.vhd
-- Version:         v1.00e
-- Description:     This file contains all of the counters for the SDRAM design.
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--                  sdram_controller.vhd
--                      -- data_statemachine.vhd
--                      -- command_statemachine.vhd
--                      -- init_statemachine.vhd
--                      -- counters.vhd
--                      -- io_registers.vhd
--                      -- ipic_if.vhd
--                      -- clock_gen.vhd
-------------------------------------------------------------------------------
-- Author:          ALS
-- History:
--   ALS           06/11/02    First Version
--   ALS           06/15/02
-- ^^^^^^
--  Modifications for SDRAM - no longer need burst, command, and wtr counters.
--  SDRAM_brst_end is now an input from the data state machine.
-- ~~~~~~
--   ALS           06/19/02
-- ^^^^^^
--  GPCnt_en is now just the inverse of GP_load. Made changes to not instantiate
--  counters when count is zero.
-- ~~~~~~
--  ALS             06/20/02
-- ^^^^^^
--  Fixed gp counter so that the end signal stays asserted until the next load.
-- ~~~~~~
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--  ALS             10/06/03    Version D            
-- ^^^^^^
-- Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
-- for new PLB IPIF.
-- ~~~~~~
--  GAB             10/29/04    Version E
-- ^^^^^^
--  Updated to use proc_common_v2_00_a library
--
--  Added additional generate for determining Twr_end to accomidate changes
--  made in Twr_load and Twr_cnt_en to fix an issue where the Twr time was
--  1 clock too long.  This required adding a new generic, C_ADJWRCNT.
-- ~~~~~~
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
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library proc_common_v2_00_a;
use proc_common_v2_00_a.proc_common_pkg.all;
use proc_common_v2_00_a.ld_arith_reg;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_GPCNT_WIDTH           -- width of general purpose counter
--      C_RCCNT_WIDTH           -- width of Trc counter
--      C_RRDCNT_WIDTH          -- width of Trrd counter
--      C_RASCNT_WIDTH          -- width of Tras counter
--      C_REFICNT_WIDTH         -- width of Trefi counter
--      C_WRCNT_WIDTH           -- width of Twr counter
--      C_BRSTCNT_WIDTH         -- width of burst counter
--      C_RCCNT                 -- Trc count value in clock cycles 
--      C_RRDCNT                -- Trrd count value in clock cycles
--      C_RASCNT                -- Tras count value in clock cycles
--      C_REFICNT               -- Trefi count value in clock cycles
--      C_100US_CNT             -- 200us count value in clock cycles
--      C_WRCNT                 -- Twr count value in clock cycles
--
-- Definition of Ports:
--  -- inputs
--      GPcnt_load              -- load general purpose counter 
--      GPcnt_data              -- general purpose counter load value
--      Trc_load                -- load Trc counter
--      Trrd_load               -- load Trrd counter
--      Tras_load               -- load Tras counter
--      Trefi_load              -- load Trefi counter
--      Init_done               -- initialization is done
--      Tcaslat_load            -- load CAS latency counter
--      Tcaslat_cnt_en          -- CAS latency count enable
--      SDRAM_brst_end          -- SDRAM burst is complete
--      Twr_load                -- load Twr counter
--      Twr_cnten               -- Twr count enable
--      Twr_rst                 -- reset Twr counter
-- -- outputs
--      GPcnt_end               -- general purpose count complete     
--      Trc_end                 -- Trc count complete
--      Trrd_end                -- Trrd count complete
--      Tras_end                -- Tras count complete
--      Trefi_pwrup_end         -- Trefi-powerup count complete
--      Twr_end                 -- Twr count complete
--
--    -- Clocks and reset
--      Clk                 
--      Rst               
---------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity counters is
  generic ( 
  
            C_RFCCNT_WIDTH      : integer;
            C_RCDCNT_WIDTH      : integer;
            C_MRDCNT_WIDTH      : integer;
            C_RPCNT_WIDTH       : integer;
            C_BRSTLENCNT_WIDTH  : integer;  
            C_RCCNT_WIDTH       : integer;
            C_RRDCNT_WIDTH      : integer;
            C_RASCNT_WIDTH      : integer;
            C_REFICNT_WIDTH     : integer;
            C_WRCNT_WIDTH       : integer;
            C_RFCCNT            : std_logic_vector;
            C_RCDCNT            : std_logic_vector;
            C_MRDCNT            : std_logic_vector;
            C_RPCNT             : std_logic_vector;
            C_BRSTLENCNT        : std_logic_vector;
            C_RCCNT             : std_logic_vector;
            C_RRDCNT            : std_logic_vector;
            C_RASCNT            : std_logic_vector;
            C_REFICNT           : std_logic_vector;
            C_100US_CNT         : std_logic_vector;
            C_WRCNT             : std_logic_vector;
            C_ADJWRCNT          : std_logic_vector

            );
  port (
        Trc_load                : in  std_logic;
        Trrd_load               : in  std_logic;
        Tras_load               : in  std_logic;
        Trefi_load              : in  std_logic;
        Trfc_load               : in  std_logic;
        Trcd_load               : in  std_logic;
        Tmrd_load               : in  std_logic;
        Trp_load                : in  std_logic;
        Tbrstlen_load           : in  std_logic;
        Init_done               : in  std_logic;
        SDRAM_brst_end          : in  std_logic;
        Twr_load                : in  std_logic;
        Twr_cnt_en              : in  std_logic;
        Twr_rst                 : in  std_logic;
        Trc_end                 : out std_logic;
        Trrd_end                : out std_logic;
        Tras_end                : out std_logic;
        Trefi_pwrup_end         : out std_logic;       
        Twr_end                 : out std_logic;
        Trfc_end                : out std_logic;
        Trcd_end                : out std_logic;
        Tmrd_end                : out std_logic;
        Trp_end                 : out std_logic;
        Tbrstlen_end            : out std_logic;
        
        -- Clocks and reset
        Clk                     : in  std_logic;
        Rst                     : in  std_logic
    );
end entity counters;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of counters is
-----------------------------------------------------------------------------
-- Function declarations
-----------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Function end_cnt will set the end count value to zero if the count value
-- is zero, otherwise the end count value is set to the count value -1
-------------------------------------------------------------------------------
function end_cnt (cnt_vec, zero_vec : std_logic_vector) return std_logic_vector is
variable end_vec : std_logic_vector(0 to cnt_vec'length -1);
begin
    if cnt_vec = zero_vec then
        end_vec := zero_vec;
    else
        end_vec := cnt_vec - 1;
    end if;
    
    return end_vec;
end function end_cnt;

-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
-- reset values
constant RFCCNT_RST     : std_logic_vector(0 to C_RFCCNT_WIDTH-1)  := (others => '0');
constant RCDCNT_RST     : std_logic_vector(0 to C_RCDCNT_WIDTH-1)  := (others => '0');
constant MRDCNT_RST     : std_logic_vector(0 to C_MRDCNT_WIDTH-1)  := (others => '0');
constant RPCNT_RST      : std_logic_vector(0 to C_RPCNT_WIDTH-1)   := (others => '0');
constant BRSTLENCNT_RST : std_logic_vector(0 to C_BRSTLENCNT_WIDTH-1):= (others => '0');
constant RCCNT_RST      : std_logic_vector(0 to C_RCCNT_WIDTH-1)  := (others => '0');
constant RRDCNT_RST     : std_logic_vector(0 to C_RRDCNT_WIDTH-1) := (others => '0');
constant RASCNT_RST     : std_logic_vector(0 to C_RASCNT_WIDTH-1) := (others => '0');
constant REFICNT_RST    : std_logic_vector(0 to C_REFICNT_WIDTH-1):= (others => '0');
constant WRCNT_RST      : std_logic_vector(0 to C_WRCNT_WIDTH-1)  := (others => '0');

-- zero values
constant ZERO_RFCCNT    : std_logic_vector(0 to C_RFCCNT_WIDTH-1)  := (others => '0');
constant ZERO_RCDCNT    : std_logic_vector(0 to C_RCDCNT_WIDTH-1)  := (others => '0');
constant ZERO_MRDCNT    : std_logic_vector(0 to C_MRDCNT_WIDTH-1)  := (others => '0');
constant ZERO_RPCNT     : std_logic_vector(0 to C_RPCNT_WIDTH-1)   := (others => '0');
constant ZERO_BRSTLENCNT: std_logic_vector(0 to C_BRSTLENCNT_WIDTH-1):= (others => '0');
constant ZERO_RCCNT     : std_logic_vector(0 to C_RCCNT_WIDTH-1)  := (others => '0');
constant ZERO_RRDCNT    : std_logic_vector(0 to C_RRDCNT_WIDTH-1) := (others => '0');
constant ZERO_RASCNT    : std_logic_vector(0 to C_RASCNT_WIDTH-1) := (others => '0');
constant ZERO_REFICNT   : std_logic_vector(0 to C_REFICNT_WIDTH-1):= (others => '0');
constant ZERO_WRCNT     : std_logic_vector(0 to C_WRCNT_WIDTH-1)  := (others => '0');


-- terminal values
constant RFCCNT_END     : std_logic_vector(0 to C_RFCCNT_WIDTH-1)  
                            := end_cnt(C_RFCCNT, ZERO_RFCCNT);
constant RCDCNT_END     : std_logic_vector(0 to C_RCDCNT_WIDTH-1)  
                            := end_cnt(C_RCDCNT, ZERO_RCDCNT);
constant MRDCNT_END     : std_logic_vector(0 to C_MRDCNT_WIDTH-1)  
                            := end_cnt(C_MRDCNT,ZERO_MRDCNT);
constant RPCNT_END      : std_logic_vector(0 to C_RPCNT_WIDTH-1)   
                            := end_cnt(C_RPCNT,ZERO_RPCNT);
constant BRSTLENCNT_END : std_logic_vector(0 to C_BRSTLENCNT_WIDTH-1)  
                            := end_cnt(C_BRSTLENCNT,ZERO_BRSTLENCNT);

-- since state machine will always go from PRECHARGE to IDLE before going to ACTIVE,
-- make the end signal for Trc a clock early
-- check this - if C_RCCNT<2, then use ZERO here
constant RCCNT_END      : std_logic_vector(0 to C_RCCNT_WIDTH-1) 
                            := end_cnt(C_RCCNT-1,ZERO_RCCNT);

constant RRDCNT_END     : std_logic_vector(0 to C_RRDCNT_WIDTH-1) 
                            := end_cnt(C_RRDCNT,ZERO_RRDCNT);

constant RASCNT_END     : std_logic_vector(0 to C_RASCNT_WIDTH-1) 
                            := end_cnt(C_RASCNT,ZERO_RASCNT) ;

constant REFICNT_END    : std_logic_vector(0 to C_REFICNT_WIDTH-1):= 
                        conv_std_logic_vector(1,C_REFICNT_WIDTH);
constant WRCNT_END      : std_logic_vector(0 to C_WRCNT_WIDTH-1)  := 
                        conv_std_logic_vector(1,C_WRCNT_WIDTH);

-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
signal rrd_cnt          : std_logic_vector(0 to C_RRDCNT_WIDTH-1);
signal ras_cnt          : std_logic_vector(0 to C_RASCNT_WIDTH-1);
signal refi_pwrup_cnt   : std_logic_vector(0 to C_REFICNT_WIDTH-1);
signal refi_pwrup_cnten : std_logic;
signal wr_cnt           : std_logic_vector(0 to C_WRCNT_WIDTH-1);

signal twr_cnten        : std_logic;
signal twr_rst_i        : std_logic;

signal trrd_cnt_en      : std_logic;
signal tras_cnt_en      : std_logic;

signal gpcnt_load_delay : std_logic;
signal gpcnt_en_delay   : std_logic;
 
-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  
-------------------------------------------------------------------------------
-- Instantiate the counters
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- RFC delay counter
-------------------------------------------------------------------------------
RFCCNT_GEN: if C_RFCCNT /= ZERO_RFCCNT generate
signal rfc_cnt          : std_logic_vector(0 to C_RFCCNT_WIDTH-1);
begin
    RFCCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_RFCCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Trfc_load,
                     Load_In        => RFCCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => rfc_cnt,   
                     Carry_Out      => open
                 );

    RFCCNT_END_PROCESS: process(Clk)
    begin
        if Clk'event and Clk = '1' then
            if Rst = RESET_ACTIVE then
                Trfc_end <= '0';         
            elsif Trfc_load = '1' then
                Trfc_end <= '0';
            elsif rfc_cnt =  RFCCNT_END then
                Trfc_end <= '1';
            end if;
        end if;
    end process RFCCNT_END_PROCESS;
end generate RFCCNT_GEN;

ZERO_RFCCNT_GEN: if C_RFCCNT = ZERO_RFCCNT generate
    Trfc_end    <= '1';    -- tie counter end signal high
end generate ZERO_RFCCNT_GEN;  

-------------------------------------------------------------------------------
-- RCD delay counter
-------------------------------------------------------------------------------
RCDCNT_GEN: if C_RCDCNT /= ZERO_RCDCNT generate
signal rcd_cnt          : std_logic_vector(0 to C_RCDCNT_WIDTH-1);
begin
    RCDCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_RCDCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Trcd_load,
                     Load_In        => RCDCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => rcd_cnt,   
                     Carry_Out      => open
                 );
                 
    RCDCNT_END_PROCESS: process (Clk)
    begin
        if Clk'event and Clk='1' then
            if Rst = RESET_ACTIVE then
                Trcd_end <= '0';
            elsif Trcd_load = '1' then
                Trcd_end <= '0';
            elsif rcd_cnt =  RCDCNT_END then
                Trcd_end <= '1';
            end if;
        end if;
    end process RCDCNT_END_PROCESS;     
end generate RCDCNT_GEN;

ZERO_RCDCNT_GEN: if C_RCDCNT = ZERO_RCDCNT generate
    Trcd_end    <= '1';   -- tie counter end signal high      
end generate ZERO_RCDCNT_GEN;

-------------------------------------------------------------------------------
-- MRD delay counter
-------------------------------------------------------------------------------
MRDCNT_GEN: if C_MRDCNT /= ZERO_MRDCNT generate
signal mrd_cnt          : std_logic_vector(0 to C_MRDCNT_WIDTH-1);
begin
    MRDCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_MRDCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Tmrd_load,
                     Load_In        => MRDCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => mrd_cnt,   
                     Carry_Out      => open
                 );

    MRDCNT_END_PROCESS: process (Clk)
    begin
        if Clk'event and Clk='1' then
            if Rst = RESET_ACTIVE then
                Tmrd_end <= '0';         
            elsif Tmrd_load = '1' then
                Tmrd_end <= '0';
            elsif mrd_cnt =  MRDCNT_END then
                Tmrd_end <= '1';
            end if;
        end if;
    end process MRDCNT_END_PROCESS;
end generate MRDCNT_GEN;

ZERO_MRDCNT_GEN: if C_MRDCNT = ZERO_MRDCNT generate
    Tmrd_end    <= '1';
end generate ZERO_MRDCNT_GEN;

-------------------------------------------------------------------------------
-- RP delay counter
-------------------------------------------------------------------------------
RPCNT_GEN: if C_RPCNT /= ZERO_RPCNT generate
signal rp_cnt           : std_logic_vector(0 to C_RPCNT_WIDTH-1) ;
begin
    RPCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_RPCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Trp_load,
                     Load_In        => RPCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => rp_cnt,   
                     Carry_Out      => open
                 );

    RPCNT_END_PROCESS: process (Clk)
    begin
        if Clk'event and Clk='1' then
            if Rst = RESET_ACTIVE then
                Trp_end <= '0';         
            elsif Trp_load = '1' then
                Trp_end <= '0';
            elsif rp_cnt =  RPCNT_END then
                Trp_end <= '1';
            end if;
        end if;
    end process RPCNT_END_PROCESS;
end generate RPCNT_GEN;

ZERO_RPCNT_GEN: if C_RPCNT = ZERO_RPCNT generate
    Trp_end     <= '1';
end generate ZERO_RPCNT_GEN;

-------------------------------------------------------------------------------
-- BRSTLEN delay counter
-------------------------------------------------------------------------------
BRSTLENCNT_GEN: if C_BRSTLENCNT /= ZERO_BRSTLENCNT generate
signal brstlen_cnt      : std_logic_vector(0 to C_BRSTLENCNT_WIDTH-1);
begin
    BRSTLENCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_BRSTLENCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Tbrstlen_load,
                     Load_In        => BRSTLENCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => brstlen_cnt,   
                     Carry_Out      => open
                 );
                 
    BRSTLEN_CNT_END_PROCESS: process (Clk)
    begin
        if Clk'event and Clk='1' then
            if Rst = RESET_ACTIVE then
                Tbrstlen_end        <= '0';         
            elsif Tbrstlen_load = '1' then
                Tbrstlen_end <= '0';
            elsif brstlen_cnt =  BRSTLENCNT_END then
                Tbrstlen_end <= '1';
            end if;
        end if;
    end process BRSTLEN_CNT_END_PROCESS;
end generate BRSTLENCNT_GEN;

ZERO_BRSTLENCNT_GEN: if C_BRSTLENCNT = ZERO_BRSTLENCNT generate
    Tbrstlen_end    <= '1';
end generate ZERO_BRSTLENCNT_GEN;

-------------------------------------------------------------------------------
-- RC delay counter
-------------------------------------------------------------------------------
RCCNT_GEN: if C_RCCNT /= ZERO_RCCNT generate
signal rc_cnt           : std_logic_vector(0 to C_RCCNT_WIDTH-1);
begin

    RCCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_RCCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Trc_load,
                     Load_In        => RCCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => rc_cnt,   
                     Carry_Out      => open
                 );

    RCCNT_END_PROCESS : process(Clk)
        begin
            if(Clk'EVENT and Clk = '1')then
                -- The Trc_end, Trrd_end, and Tras_end signals must
                -- stay asserted until the counters are reloaded.
                if Rst = RESET_ACTIVE or Trc_load = '1' then
                    Trc_end <= '0';
                elsif rc_cnt =  RCCNT_END then
                    Trc_end <= '1';
                end if;
            end if;
        end process RCCNT_END_PROCESS;

end generate RCCNT_GEN;

ZERO_RCCNT_GEN: if C_RCCNT = ZERO_RCCNT generate
    Trc_end <= '1';
end generate ZERO_RCCNT_GEN;


-------------------------------------------------------------------------------
-- RRD delay counter
-------------------------------------------------------------------------------
RRDCNT_GEN: if C_RRDCNT /= ZERO_RRDCNT generate
signal rrd_cnt      : std_logic_vector(0 to C_RRDCNT_WIDTH-1);
begin
    RRDCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_RRDCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Trrd_load,
                     Load_In        => RRDCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => rrd_cnt,   
                     Carry_Out      => open
                 );


    RRDCNT_END_PROCESS : process(Clk)
        begin
            if(Clk'EVENT and Clk = '1')then
                if Rst = RESET_ACTIVE or Trrd_load = '1' then
                    Trrd_end <= '0';
                elsif rrd_cnt =  RRDCNT_END then
                    Trrd_end <= '1';
                end if;
            end if;
        end process RRDCNT_END_PROCESS;

end generate RRDCNT_GEN;


ZERO_RRDCNT_GEN: if C_RRDCNT = ZERO_RRDCNT generate
    Trrd_end    <= '1';
end generate ZERO_RRDCNT_GEN;            
       

-------------------------------------------------------------------------------
-- RAS delay counter
-------------------------------------------------------------------------------
RASCNT_GEN: if C_RASCNT /= ZERO_RASCNT generate
signal ras_cnt          : std_logic_vector(0 to C_RASCNT_WIDTH - 1);
begin
    RASCNT_I: entity proc_common_v2_00_a.counter
        generic map (
                     C_NUM_BITS    => C_RASCNT_WIDTH
                    )
        port map (   Clk            => Clk,
                     Rst            => Tras_load,
                     Load_In        => RASCNT_RST, 
                     Count_Enable   => '1',
                     Count_Load     => '0',
                     Count_Down     => '0',  
                     Count_Out      => ras_cnt,   
                     Carry_Out      => open
                 );

    RASCNT_END_PROCESS : process(Clk)
        begin
            if(Clk'EVENT and Clk = '1')then
                if Rst = RESET_ACTIVE or Tras_load = '1' then
                    Tras_end <= '0';
                elsif ras_cnt =  RASCNT_END then
                    Tras_end <= '1';
                end if;
            end if;
        end process RASCNT_END_PROCESS;

end generate RASCNT_GEN;

ZERO_RASCNT_GEN: if C_RASCNT = ZERO_RASCNT generate
    Tras_end    <= '1';
end generate ZERO_RASCNT_GEN;            
       
-------------------------------------------------------------------------------
-- REFI delay counter
-------------------------------------------------------------------------------
-- Always need this counter to count powerup delays, etc.
-- Refresh and powerup delay counter
refi_pwrup_cnten <= not(Trefi_load);

REFI_PWRUP_CNT_I: entity proc_common_v2_00_a.ld_arith_reg
    generic map (C_ADD_SUB_NOT  => false,
                 C_REG_WIDTH    => C_REFICNT_WIDTH,
                 C_RESET_VALUE  => C_100US_CNT,
                 C_LD_WIDTH     => C_REFICNT_WIDTH,
                 C_LD_OFFSET    => 0,
                 C_AD_WIDTH     => 1,
                 C_AD_OFFSET    => 0
                )
    port map (   CK             => Clk,
                 RST            => Rst,
                 Q              => refi_pwrup_cnt,   
                 LD             => C_REFICNT, 
                 AD             => "1",  
                 LOAD           => Trefi_load,
                 OP             => refi_pwrup_cnten
             );

-------------------------------------------------------------------------------
-- WR delay counter
-------------------------------------------------------------------------------
-- counter is only needed if C_WRCNT > 0
--WRCNT_GEN: if C_WRCNT > 0 generate
WRCNT_GEN: if C_WRCNT > 1 generate
   -- can't load this counter with SDRAM_brst_end because that's the brst end
   -- for a single transaction - use Twr_load from the data sm because its the
   -- end of a bus burst
    twr_cnten <= Twr_cnt_en and not(Twr_load);
    twr_rst_i <= Twr_rst after 1 ns;
    WRCNT_I: entity proc_common_v2_00_a.ld_arith_reg
        generic map (C_ADD_SUB_NOT  => false,
                     C_REG_WIDTH    => C_WRCNT_WIDTH,
                     C_RESET_VALUE  => WRCNT_RST,
                     C_LD_WIDTH     => C_WRCNT_WIDTH,
                     C_LD_OFFSET    => 0,
                     C_AD_WIDTH     => 1,
                     C_AD_OFFSET    => 0
                    )
        port map (   CK             => Clk,
                     RST            => twr_rst_i,
                     Q              => wr_cnt,   
--                     LD             => C_WRCNT, 
                     LD             => C_ADJWRCNT, 
                     AD             => "1",  
                     LOAD           => Twr_load,
                     OP             => twr_cnten
                 );

    WRCNT_END_PROCESS: process(Clk)
    begin
        if Clk'event and Clk = '1' then
            if Rst = RESET_ACTIVE then
                Twr_end <= '0';
            elsif Twr_rst = '1' then
                Twr_end <= '0';
            elsif wr_cnt = WRCNT_END then
                Twr_end <= '1';
            end if;
        end if;
    end process WRCNT_END_PROCESS;
end generate WRCNT_GEN;

ONEWRCNT_GEN: if C_WRCNT = 1 generate
    wr_cnt <= (others => '0');
    WRCNT_END_PROCESS: process(Clk)
    begin
        if Clk'event and Clk = '1' then
            if Rst = RESET_ACTIVE then
                Twr_end <= '0';
            elsif Twr_load = '1' then
                Twr_end <= '1';
            elsif Twr_rst = '1' then
                Twr_end <= '0';
            end if;
        end if;
    end process WRCNT_END_PROCESS;
end generate ONEWRCNT_GEN;


NOWRCNT_GEN: if C_WRCNT = 0 generate
    wr_cnt <= (others => '0');
    Twr_end <= '1';
end generate NOWRCNT_GEN;

-------------------------------------------------------------------------------
-- Generate the counter end signals
-- Generate signal when counter is at '1' so that the end signal can be
-- registered
-------------------------------------------------------------------------------
CNTR_END_PROCESS: process (Clk)
begin
    if Clk'event and Clk='1' then
        if Rst = RESET_ACTIVE then
            Trefi_pwrup_end     <= '0';  
        else
            -- the refresh timer interval end signal must
            -- stay asserted until the refresh can be serviced
            -- reset it once the load signal occurs again
            if Trefi_load = '1' then
                Trefi_pwrup_end <= '0';
            elsif  refi_pwrup_cnt =  REFICNT_END then
                Trefi_pwrup_end <= '1';
            elsif Init_done = '0' then
                Trefi_pwrup_end <= '0';
            end if;
        end if;
    end if;
end process CNTR_END_PROCESS;    
            

end imp;