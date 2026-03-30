-------------------------------------------------------------------------------
-- $Id: data_statemachine.vhd,v 1.3 2005/02/03 22:51:10 gburch Exp $
-------------------------------------------------------------------------------
-- data_statemachine.vhd - entity/architecture pair
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
-- Filename:        data_statemachine.vhd
-- Version:         v1.00e
-- Description:     This state machine controls the power-up sequence of commands
--                  to the SDRAM.
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
--  Modified for SDRAM
-- ~~~~~~
--
--   ALS            07/24/02    Version C
-- ^^^^^^
--  Include pipe stage in write cycle to increase clock frequency and clean up code
-- ~~~~~~
--  ALS             07/29/02
-- ^^^^^^
--  Separated write data and read data states to more easily support write data
--  pipelining and bursts
-- ~~~~~~
--  ALS             10/06/03    Version D
-- ^^^^^^
--  Removed XON generics, used UNISIM.VCOMPONENTS, removed latency and added support
--  for new PLB IPIF.
-- ~~~~~~
--  GAB             11/26/03
-- ^^^^^^
--  Added Read counter to handle situations where the read command is interrupted.
--  Interruptions can occur if a refresh is issued in the middle of a burst, or
--  if the read burst crosses an address boundry, i.e. crosses to the next row or bank.
--
--  Modified data statemachine to handle pauses in the read cycles.  Brought in 
--  Read_pause as part of this modification.
--  
--  Modified ce logic to allow for signaling the command state machine to issue the next
--  read command prior to reading all of the data.  This allows for back to back reads
--  improving read latency.  Brought in C_SDRAM_CAS_LAT and C_USE_POSEDGE_OUTREGS as
--  part of this modification.
--
--  Removed cas latency timer.  This timer was no longer needed with the ce modifications
--  made above.
--
--  Modified RDAck reset logic to provide correct RDAck's during PLB bursting.
-- ~~~~~~
--  GAB             07/13/04
-- ^^^^^^
-- Added back in the read_data_rst signal so 0's will be driven onto the ip2bus_data
-- bus when the controller is not selected.  This bug was introduced during 
-- optimizations of the core.  This fix is for CR190932 and CR190933.
--
-- Removed inclusion of or_gate which is not being used to fix tool issue
-- ~~~~~~
-- GAB              10/29/04    Version E
-- ^^^^^^
--  Moved write_data_rst from REG_RST process to statemachine to prevent write_ce
--  piping stage from being filled up causing an ack to be generated when it
--  shouldn't have.
--
--  Shifted sdram_burst_end and wrack logic to accomidate registering of 
--  pend_read and pend_write in command_statemachine..
--
--  Register IPIC Write data for 8-bit and 16-bit SDRAM cases, to break
--  slow path in the 8-bit configuration.  This mod required shifting of 
--  WrAck to allow correct timing of data changes.
--
--  Moved Twr_load and Twr_cnt_en from the data statemachine to the command
--  statemachine to fix issue with Twr time being 1 clock too long
--
--  Updated to use proc_common_v2_00_a library
-- ~~~~~~
-- GAB              01/31/05
-- ^^^^^^
--  Removed setting of data done signal in the wait_twr state.  Data done
--  does not need to get set for write cycles.  This was causing the
--  data statemachine to get out of sync with the command statemachine.
-- ~~~~~~
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
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library proc_common_v2_00_a;
use proc_common_v2_00_a.proc_common_pkg.all;
use proc_common_v2_00_a.mux_onehot;
use proc_common_v2_00_a.counter;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_SDRAM_DWIDTH                  -- width of SDRAM address bus
--      C_SDRAM_BRST_LEN                -- length of SDRAM burst (IPIF_DWIDTH/SDRAM_DWIDTH)
--      C_IPIF_DWIDTH                   -- width of IPIF data bus
--      C_SDRAM_CAS_LAT                 -- CAS latency
--      C_USE_POSEDGE_OUTREGS           -- use positive edge output registers if 1
--      C_INCLUDE_HIGHSPEED_PIPE        -- high frequency design (adds pipeline registers)
--      C_INCLUDE_BURSTS                -- support bus burst transactions
--
-- Definition of Ports:
--  -- inputs
--      IPIC_wrdata         -- data to be written
--      IPIC_be             -- bus byte enables
--      SDRAM_ReadData      -- data read from SDRAM
--      Pend_write          -- enable writing of data
--      Pend_read           -- enable reading of data
--      Bus2IP_RNW          -- bus read not write
--      Bus2IP_Burst        -- burst
--      Bus2IP_CS           -- indicates SDRAM controller has been selected
--      Twr_end             -- Twr end
--
--  -- outputs
--      WrAck               -- write acknowledge
--      RdAck               -- read acknowledge
--      Read_data_en        -- enable read data io register
--      Read_data           -- data read
--      Write_data_en       -- enable write data io register
--      Write_data          -- data to be written
--      Write_data_mask     -- data mask to be written
--      Data_done           -- data statemachine is complete
--      SDRAM_brst_end      -- SDRAM burst done
--      Read_pause          -- read transfer is interrupted
--      Tcaslat_cnt_en      -- enable CAS latency counter
--      Tcaslat_load        -- load CAS latency counter
--      Rst_pend_rd         -- reset pending read
--      Rst_pend_wr         -- reset pending write
--
--    -- Clocks and reset
--      Clk                 
--      Rst               
---------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------

entity data_statemachine is
  generic ( C_SDRAM_DWIDTH              : integer;
            C_SDRAM_BRST_LEN            : integer;
            C_IPIF_DWIDTH               : integer;
            C_SDRAM_CAS_LAT             : integer;
            C_USE_POSEDGE_OUTREGS       : integer;
            C_INCLUDE_HIGHSPEED_PIPE    : integer;
            C_INCLUDE_BURSTS            : integer
  );
  port (
    -- inputs
    IPIC_wrdata         : in  std_logic_vector(0 to C_IPIF_DWIDTH-1);
    IPIC_be             : in  std_logic_vector(0 to C_IPIF_DWIDTH/8-1);
    SDRAM_ReadData      : in  std_logic_vector(0 to C_SDRAM_DWIDTH-1);
    Pend_write          : in  std_logic;
    Pend_read           : in  std_logic;
    Bus2IP_RNW          : in  std_logic;
    Bus2IP_Burst        : in  std_logic;
    Bus2IP_CS           : in  std_logic;
    Twr_end             : in  std_logic;
    Rst_data_done       : in  std_logic;

    -- outputs
    WrAck               : out std_logic;
    RdAck               : out std_logic;
    Read_data           : out std_logic_vector(0 to C_IPIF_DWIDTH-1);
    Write_data_en       : out std_logic;
    Write_data          : out std_logic_vector(0 to C_SDRAM_DWIDTH-1);
    Write_data_mask     : out std_logic_vector(0 to C_SDRAM_DWIDTH/8-1);
    Data_done           : out std_logic;
    SDRAM_brst_end      : out std_logic;
    Read_pause          : in  std_logic;
    Rst_pend_rd         : out std_logic;
    Rst_pend_wr         : out std_logic;

    -- Clocks and reset
    Clk                 : in  std_logic;
    Rst                 : in  std_logic
    );
end entity data_statemachine;


-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture imp of data_statemachine is
-----------------------------------------------------------------------------
-- Constant declarations
-----------------------------------------------------------------------------
constant PRECHARGE_X        : integer := (C_SDRAM_CAS_LAT - 1);

constant TTL_CAS_LAT        : integer := (C_SDRAM_CAS_LAT
                                        + C_USE_POSEDGE_OUTREGS
                                        + C_INCLUDE_HIGHSPEED_PIPE);

constant TTL_READ_CYCLE     : integer := C_SDRAM_BRST_LEN + TTL_CAS_LAT;

constant NEXT_READ_CMND     : integer := max2(0,(TTL_READ_CYCLE - PRECHARGE_X - 3));

constant READ_CNTR_WIDTH    : integer := 4;  

constant READ_CNTR_ZEROS    : std_logic_vector(0 to READ_CNTR_WIDTH-1) 
                                := (others => '0');
                                
constant READ_CNTR_ONE      : std_logic_vector(0 to READ_CNTR_WIDTH-1) 
                                := conv_std_logic_vector(1, READ_CNTR_WIDTH);

-----------------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------------
type DATA_STATE_TYPE is (IDLE, WAIT_CASLAT, READ, WRITE, WAIT_TWR, WAIT_RDACK, DONE);
signal datasm_ns        : DATA_STATE_TYPE;
signal datasm_cs        : DATA_STATE_TYPE;

signal write_data_en_cmb: std_logic;
signal read_data_en_cmb : std_logic;
signal read_data_en     : std_logic;
signal read_data_rst    : std_logic;
signal write_data_rst   : std_logic;
signal write_data_cmb   : std_logic_vector(0 to C_SDRAM_DWIDTH-1);
signal write_data_mask_cmb : std_logic_vector(0 to C_SDRAM_DWIDTH/8-1);
signal ce_cmb           : std_logic;
signal ce_last          : std_logic;
signal ce               : std_logic_vector(0 to TTL_READ_CYCLE-1);
signal write_ce         : std_logic_vector(0 to C_SDRAM_BRST_LEN-1);
signal read_ce          : std_logic_vector(0 to TTL_READ_CYCLE-1);
signal data_done_cmb    : std_logic;
signal last_word        : std_logic;
signal read_data_pipe   : std_logic_vector(0 to C_IPIF_DWIDTH-1);
signal ipic_be_n        : std_logic_vector(0 to C_IPIF_DWIDTH/8-1);

signal RdAck_i          : std_logic;
signal rdack_rst_i      : std_logic;
signal RdAck_rst        : std_logic;
signal read_cntr_ce     : std_logic;
signal read_cntr_rst    : std_logic;
signal read_cnt         : std_logic_vector(0 to READ_CNTR_WIDTH-1);

signal end_cas_lat          : std_logic;
signal reg_SDRAM_brst_end   : std_logic;


-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------

begin  -- architecture imp

Rst_pend_rd <= RESET_ACTIVE;
Rst_pend_wr <= RESET_ACTIVE;


RdAck       <= RdAck_i;

-- reset RdAck when the read transaction has been interrupted and the last
-- read ack has been received and during all states of the read side of the
-- data state machine except RD_DATA
-- For burst support Read_pause is functional
BURST_ACKRST_GEN : if C_INCLUDE_BURSTS = 1 generate
    RdAck_rst <= '1' 
                    when ((read_cnt = READ_CNTR_ONE and RdAck_i = '1' and Read_pause='1')
                           or rdack_rst_i = '1')
                    else '0';
end generate BURST_ACKRST_GEN;
-- For NO burst support Read_pause is tied to 0
NOBURST_ACKRST_GEN : if C_INCLUDE_BURSTS = 0 generate
    RdAck_rst <= rdack_rst_i;
end generate NOBURST_ACKRST_GEN;

--------------------------------------------------------------------------------
-- Data State Machine
-- DATASM_CMB:     combinational process for determining next state
-- DATASM_REG:     state machine registers
--------------------------------------------------------------------------------
    -- Combinational process
DATASM_CMB: process (Pend_write, Pend_read, Twr_end,end_cas_lat, read_data_en,
                    datasm_cs, last_word, Bus2IP_Burst,  Rdack_i, Read_pause, read_cnt ,Bus2IP_CS)
begin
-- Set default values
write_data_en_cmb <= '0';
read_data_en_cmb <= '0';
data_done_cmb <= '0';
datasm_ns <= datasm_cs;
rdack_rst_i <= '0';
write_data_rst  <= '0';


case datasm_cs is
-------------------------- IDLE --------------------------
    when IDLE =>
        rdack_rst_i <= '1';
        -- idle state
        -- wait in this state for pending read or write 

        if Pend_write = '1'  then
            datasm_ns <= WRITE;
            write_data_en_cmb <= '1';
        end if;
        if Pend_read = '1' then
            datasm_ns <= WAIT_CASLAT;
            read_data_en_cmb <= '1';
            write_data_rst  <= '1';
        end if;
        
-------------------------- WAIT_CASLAT --------------------------
    when WAIT_CASLAT => 
        -- Assert read data enable
        read_data_en_cmb <= '1';

        -- Reset read acknowledge register
        rdack_rst_i <= '1';

        -- Hold write paths in reset
        write_data_rst  <= '1';
        -- wait in this state for cas latency 
        if end_cas_lat = '1' then
            datasm_ns <= READ;
        end if;
        
-------------------------- READ --------------------------
    when READ =>
        -- read data in this state
        -- stay in this state while pend_read is asserted
        -- when pend_read negates 
        -- check to see if the SDRAM burst cycle is complete
        read_data_en_cmb <= '1';
        
        -- Hold write paths in reset
        write_data_rst  <= '1';
        --------------- BURST Support --------------------
        if C_INCLUDE_BURSTS = 1 then
        
            -- Burst finished
            if(Bus2IP_CS = '0')then
                datasm_ns <= DONE;
                data_done_cmb <= '1';
                rdack_rst_i <= '1';
            -- SDRAM is done with burst
            elsif Bus2IP_Burst = '0' and Read_pause = '0' then
                if Rdack_i = '1' then
                    -- Read ack generated therefore go to DONE
                    datasm_ns <= DONE;
                    data_done_cmb <= '1';
                    rdack_rst_i <= '1';
                else
                    -- Wait for read data ack
                    datasm_ns <= WAIT_RDACK;
                end if;
            elsif read_cnt = READ_CNTR_ZEROS then
                -- read transaction has been interrupted and
                -- all read acks have been received
                datasm_ns <= DONE;
                data_done_cmb <= '1';
                rdack_rst_i <= '1';
            end if;

        --------------- NO BURST Support --------------------
        else
            if Rdack_i = '1' then
                -- Read ack generated therefore go to DONE
                datasm_ns <= DONE;
                data_done_cmb <= '1';
                rdack_rst_i <= '1';
            else
                -- Wait for read data ack
                datasm_ns <= WAIT_RDACK;
            end if;
        end if; -- if C_INCLUDE_BURSTS
        
-------------------------- WRITE --------------------------
    when WRITE =>
        -- write data in this state
        -- stay in this state while pend_write is asserted
        -- when pend_write negates 
        -- check to see if the SDRAM burst cycle is complete
        write_data_en_cmb   <= '1';
        rdack_rst_i         <= '1';
        if Pend_write = '0' then
            -- no more write commands 
            if last_word = '1' then
                -- SDRAM is done with burst, enable TWR counter
                -- and wait for it to expire
                datasm_ns       <= WAIT_TWR;
            end if;
        end if;

-------------------------- WAIT_TWR --------------------------
    when WAIT_TWR =>
        -- wait for write recovery timer to expire, then
        -- go to done
        rdack_rst_i <= '1';
        if Pend_write = '1' then
            datasm_ns <= WRITE;
            write_data_en_cmb <= '1';
        elsif Twr_end = '1' then
--            data_done_cmb <= '1';
            datasm_ns <= DONE;
        end if;
        
-------------------------- WAIT_RDACK --------------------------
    when WAIT_RDACK => 
        read_data_en_cmb <= '1';
        -- Hold write paths in reset
        write_data_rst  <= '1';
        -- wait in this state for read data ack to assert
--        if Rdack_i = '1' then
        if Rdack_i = '1' or Bus2IP_CS = '0' then
            -- SDRAM is done with burst, go to DONE
            datasm_ns <= DONE;
            data_done_cmb <= '1';
            rdack_rst_i <= '1';
        end if;

-------------------------- DONE --------------------------
    when DONE =>
        -- Data_done is asserted in this state
        -- if pend_op asserts, go to XFER_DATA, otherwise
        -- go back to IDLE
        rdack_rst_i <= '1';
        if Pend_write = '1' then
            datasm_ns <= WRITE;
            write_data_en_cmb <= '1';
        elsif Pend_read = '1' then
            datasm_ns <= WAIT_CASLAT;
            read_data_en_cmb <= '1';
            write_data_rst  <= '1';
        else
            datasm_ns <= IDLE;
            read_data_en_cmb <= read_data_en;
            write_data_rst  <= '1';
        end if;
        
-------------------------- DEFAULT --------------------------
    when others => 
        datasm_ns <= IDLE;
end case;
end process DATASM_CMB;
    
DATASM_REG: process (Clk)
begin

    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE) then
            datasm_cs       <= IDLE;
            read_data_en    <= '0';
        else
            datasm_cs       <= datasm_ns;
            read_data_en    <= read_data_en_cmb;
        end if;
    end if;
end process DATASM_REG;    

--------------------------------------------------------------------------------
-- Latch Data Done Signal
--------------------------------------------------------------------------------
REG_DONE : process(Clk)
begin
    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE or Rst_data_done = '1') then
            Data_done <= '0';
        elsif(data_done_cmb = '1')then
            Data_done <= '1';
        end if;
   end if;
end process REG_DONE;      

REG_RST : process(Clk)
begin
    if (Clk'event and Clk = '1') then
        if (Rst = RESET_ACTIVE)then
            read_data_rst   <= '1';
--            write_data_rst  <= '1';
        elsif(Bus2IP_CS = '0' or Bus2IP_RNW = '0') then            
            read_data_rst   <= '1';
--            write_data_rst  <= '0';
--        elsif(Bus2IP_CS = '0' or Bus2IP_RNW = '1') then                    
--            read_data_rst   <= '0';
--            write_data_rst  <= '1';
        else
            read_data_rst   <= '0';
--            write_data_rst  <= '0';
        end if;
   end if;
end process REG_RST;      


--------------------------------------------------------------------------------
-- Data enables
-- This code allows for the SDRAM to be of a narrower width than the bus
-- by ping-ponging data registers
--------------------------------------------------------------------------------
-- Create ce's for data pipe            
           
last_word <= ce(C_SDRAM_BRST_LEN-1);

end_cas_lat <= ce(TTL_CAS_LAT - 1);
ce_cmb      <= pend_read or pend_write;

GEN_END_SAME_WIDTH : if C_SDRAM_BRST_LEN = 1 generate

SDRAM_brst_end  <= ce_cmb;

end generate;

GEN_END_NOTSAME_WIDTH : if C_SDRAM_BRST_LEN > 1 generate

SDRAM_brst_end  <=  ce(C_SDRAM_BRST_LEN - 2) when write_data_en_cmb = '1'
         else       ce(NEXT_READ_CMND) when (read_data_en = '1' or read_data_en_cmb = '1')
         else       '0';

end generate;


DATAEN_GEN: for i in 0 to TTL_READ_CYCLE-1 generate

    ZEROGEN: if i = 0 generate
        ZERO_DATAEN: FDR
            port map (
                Q => ce(i),  --[out]
                C => Clk,    --[in]
                D => ce_cmb, --[in]
                R => Rst     --[in]
            );
    end generate ZEROGEN;
    
    OTHERSGEN: if i /= 0 generate
        OTHER_DATAEN: FDR
            port map (
                Q => ce(i),     --[out]
                C => Clk,       --[in]
                D => ce(i-1),   --[in]
                R => Rst        --[in]
            );
    end generate OTHERSGEN;
end generate DATAEN_GEN;

--------------------------------------------------------------------------------
-- Read Data Path
-- This code allows for the SDRAM to be of a narrower width than the bus
-- by ping-ponging data registers
--------------------------------------------------------------------------------

read_ce <= ce;

RDDATA_REG_GEN: for i in TTL_CAS_LAT to TTL_READ_CYCLE - 1 generate
    RDDATA_BIT_REG_GEN: for j in 0 to C_SDRAM_DWIDTH-1 generate
        RDDATA_BIT: FDRE
            port map (
                Q   => read_data_pipe((i-TTL_CAS_LAT)*C_SDRAM_DWIDTH+j), --[out]
                C   => Clk,                     --[in]
                CE  => read_ce(i),              --[in]
                D   => SDRAM_ReadData(j),       --[in]
                R   => read_data_rst            --[in]
            );
    end generate RDDATA_BIT_REG_GEN;
end generate RDDATA_REG_GEN;

read_data <= read_data_pipe;

-- ACK is one clock after last read_ce
RDACK_REG: FDR
            port map (
                Q => RdAck_i,                   --[out]
                C => Clk,                       --[in]
                D => read_ce(TTL_READ_CYCLE-1), --[in]
                R => RdAck_rst
            );

--------------------------------------------------------------------------------
-- Write Data Path
-- This code allows for the SDRAM to be of a narrower width than the bus
-- by ping-ponging data registers
--------------------------------------------------------------------------------
-- Write CE's need to assert immediately
-- create write_ce bus
write_ce(0) <= pend_write;

WRBRST_GTONE_GEN: if C_SDRAM_BRST_LEN > 1 generate
    write_ce(1 to C_SDRAM_BRST_LEN-1) <= ce(0 to C_SDRAM_BRST_LEN-2);
end generate WRBRST_GTONE_GEN;


-- SDRAM Device width does not equal the bus width
-- Register write data and be's to break slow path from IPIF to MUX
GEN_REG_NOTEQUAL_WIDTH : if C_SDRAM_BRST_LEN > 1 generate
signal ipic_wrdata_d1       : std_logic_vector(0 to C_IPIF_DWIDTH - 1);
signal ipic_be_n_d1         : std_logic_vector(0 to C_IPIF_DWIDTH/8 -1);
begin
    IPIC_be_n <= not(IPIC_be);

    WRDATA_REG_PROCESS: process (Clk)
    begin
        if Clk'event and Clk = '1' then
            if(Rst = RESET_ACTIVE)then
                ipic_wrdata_d1  <= (others => '0');
                ipic_be_n_d1    <= (others => '0'); 
            else
                ipic_wrdata_d1 <= IPIC_wrdata;
                ipic_be_n_d1   <= IPIC_be_n; 
            end if;
        end if;
    end process WRDATA_REG_PROCESS;

    WRITE_DATA_MUX: entity proc_common_v2_00_a.mux_onehot 
       generic map ( C_DW => C_SDRAM_DWIDTH,
                     C_NB => C_SDRAM_BRST_LEN )
       port map (
          D => IPIC_wrdata_d1,
          S => write_ce,
          Y => write_data_cmb
          );

    WRITE_DATAMASK_MUX: entity proc_common_v2_00_a.mux_onehot 
       generic map ( C_DW => C_SDRAM_DWIDTH/8,
                     C_NB => C_SDRAM_BRST_LEN )
       port map (
          D => ipic_be_n_d1,
          S => write_ce,
          Y => write_data_mask_cmb
          );
end generate GEN_REG_NOTEQUAL_WIDTH;

-- SDRAM Device width equals the bus width
GEN_REG_EQUAL_WIDTH : if C_SDRAM_BRST_LEN = 1 generate
begin
    IPIC_be_n <= not(IPIC_be);


    WRITE_DATA_MUX: entity proc_common_v2_00_a.mux_onehot 
       generic map ( C_DW => C_SDRAM_DWIDTH,
                     C_NB => C_SDRAM_BRST_LEN )
       port map (
          D => IPIC_wrdata,
          S => write_ce,
          Y => write_data_cmb
          );

    WRITE_DATAMASK_MUX: entity proc_common_v2_00_a.mux_onehot 
       generic map ( C_DW => C_SDRAM_DWIDTH/8,
                     C_NB => C_SDRAM_BRST_LEN )
       port map (
          D => IPIC_be_n,
          S => write_ce,
          Y => write_data_mask_cmb
          );
end generate GEN_REG_EQUAL_WIDTH;


-- WrAck is coincident with last ce if burst is > 1
--WRACK_BRST_GTONE_GEN: if C_SDRAM_BRST_LEN > 1 generate
--    WRACK_REG: FDR
--                port map (
--                    Q => WrAck, --[out]
--                    C => Clk, --[in]
--                    D => write_ce(C_SDRAM_BRST_LEN-2), --[in]
--                    R => write_data_rst --[in]
--               );
--end generate WRACK_BRST_GTONE_GEN;

WRACK_BRST_GTONE_GEN: if C_SDRAM_BRST_LEN > 2 generate
    WRACK_REG: FDR
                port map (
                    Q => WrAck, --[out]
                    C => Clk, --[in]
                    D => write_ce(C_SDRAM_BRST_LEN-3), --[in]
                    R => write_data_rst --[in]
               );
end generate WRACK_BRST_GTONE_GEN;

-- if burst length is 1, WRACK is write_ce(0)
--WRACK_BRST_EQONE_GEN: if C_SDRAM_BRST_LEN = 1 generate
WRACK_BRST_EQONE_GEN: if C_SDRAM_BRST_LEN <= 2 generate

    WrAck <= write_ce(0) and not(write_data_rst);

end generate WRACK_BRST_EQONE_GEN;

-------------------------------------------------------------------------------
-- Pipeline registers to improve timing
-------------------------------------------------------------------------------
WRITE_REGS_GEN: if C_INCLUDE_HIGHSPEED_PIPE = 1 generate
    WRITE_REGS_PROCESS: process (Clk)
    begin
        if Clk'event and Clk = '1' then
            if Rst = RESET_ACTIVE then
                Write_data      <= (others => '0');
                Write_data_mask <= (others => '0');
                Write_data_en   <= '0'; 
            else
                Write_data      <= write_data_cmb;
                Write_data_mask <= write_data_mask_cmb;
                Write_data_en   <= write_data_en_cmb;
            end if;
        end if;
    end process WRITE_REGS_PROCESS;
end generate WRITE_REGS_GEN;   

WRITE_CMB_GEN: if C_INCLUDE_HIGHSPEED_PIPE = 0 generate
    Write_data      <= write_data_cmb;
    Write_data_en   <= write_data_en_cmb;
    Write_data_mask <= write_data_mask_cmb;
end generate WRITE_CMB_GEN;

-------------------------------------------------------------------------------
-- Read counter
-- Counts up when there is a pending read command, counts
-- down everytime a read acknowledge is received
-- Reset whenever read data is finished
-------------------------------------------------------------------------------
BURST_RDCNT_GEN : if C_INCLUDE_BURSTS = 1 generate
    read_cntr_ce <= Pend_read xor RdAck_i;
    read_cntr_rst <= data_done_cmb or Rst;
    READCNTR_I:  entity proc_common_v2_00_a.Counter(imp)
        generic map (C_NUM_BITS => READ_CNTR_WIDTH)
        port map
            (
                Clk           => Clk,
                Rst           => read_cntr_rst,  
                Load_In       => READ_CNTR_ZEROS,
                Count_Enable  => read_cntr_ce,
                Count_Load    => '0',
                Count_Down    => RdAck_i,
                Count_Out     => read_cnt,
                Carry_Out     => open
            );
end generate BURST_RDCNT_GEN;

end imp;

