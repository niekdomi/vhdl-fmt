-------------------------------------------------------------------------------
-- $Id: dcr_regs.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
------------------------------------------------------------------------------- 
-- dcr_regs.vhd -- entity/architecture pair
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
-- Filename:        dcr_regs.vhd
-- Version:         v1.01a
-- Description:     This file contains the status and control registers for
--                  the PLB arbiter accessed through a DCR interface.
-- 
--    DCR_BASE_ADDR + 0 : PESR_MERR_DETECT
--    [0:C_PLB_NUM_MASTERS-1]  = Error detected with corresponding master
--              Writing to this register field clears all the corresponding
--              master's PESR bits.
--
--    DCR_BASE_ADDR + 1 : PESR_MDRIVE
--    [0:C_PLB_NUM_MASTERS-1] = The corresponding master has latched the
--              PEARs with its error information. PESR_MDRIVE is one-hot.
--
--    DCR_BASE_ADDR + 2 : PESR_RNW_ERR
--    [0:C_PLB_NUM_MASTERS-1]  = Specifies if Error for corresponding master
--              is due to a Read (= 1) or Write (= 0) transaction
--
--    DCR_BASE_ADDR + 3 : PESR_LCK_ERR
--    [0:C_PLB_NUM_MASTERS-1] = Specifies if corresponding master's error
--              fields are locked (= 1) or unlocked (= 0). If unlocked, 
--              subsequent errors will overwrite error PESR fields
--
--    DCR_BASE_ADDR + 4 : PEAR_ADDR
--    [0:C_DCR_DWIDTH-1]  = PLB Address where error occurred
--
--    DCR_BASE_ADDR + 5 : PEAR_BYTE_EN
--    [0:C_PLB_DWIDTH/8-1] = PLB Byte Enable Value when error occurred
--
--    DCR_BASE_ADDR + 6 : PEAR_SIZE_TYPE
--    [0:3] = PLB Size when error occurred
--    [4:6] = PLB Type when error occurred
--
--    DCR_BASE_ADDR + 7 : PACR (PLB Arbiter Control Register)
--    [0]   = Interrupt Enable. Default value is enabled. If DCR interface is
--            parameterized away, interrupts will be enabled.
--    [1]   = BGO Reset. This provides a way for software to issue a reset to
--            the bridge.
--    [2]   = Test Enable. When this bit is asserted, the DCR registers become
--             read/writeable.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--          plb_v34.vhd
--              --  plb_addrpath.vhd
--                  --  mux_onehot_imp.vhd
--
--              --  plb_rd_datapath.vhd
--
--              --  plb_wr_datapath.vhd
--                  --  mux_onehot_imp.vhd
--
--              --  plb_slave_ors.vhd
--
--              --  plb_arbiter_logic.vhd
--                  --  muxed_signals.vhd
--                      --  mux_onehot_imp.vhd
--                      --  or_bits.vhd
--
--                  --  arb_control_sm.vhd
--
--                  --  arb_registers.vhd
--                      --  bus_controlvhd
--
--                  --  plb_priority_encoder.vhd
--                      --  priority_encoder.vhd
--                          --  qual_request.vhd
--                      --  arb_addr_sel.vhd
--                      --  mux_onehot_imp.vhd
--                      --  pend_request.vhd
--                      --  pending_priority.vhd
--                          --  qual_priority.vhd
--
--                  --  gen_qual_req.vhd
--
--                  --  buslocksm.vhd
--
--                  --  watchdog_timer.vhd
--                      --  down_counter.vhd
--
--                  --  dcr_regs.vhd
-- 
--                  --  plb_interrupt.vhd
--
-------------------------------------------------------------------------------
-- Author:      Bert Tise
-- History:
--      ALS     02/20/02        -- created from plb_arbiter_v1_01_a
--      ALS     04/16-17/02        -- Version v1.01a
-- ^^^^^^
--  Added PLB_SIZE_TYPE PEAR register. Fixed SW reset bit so that it no longer
--  resets DCR_ACK. Also added TST_EN bit to the control register which allows
--  the PEAR registers to be written. 
-- ~~~~~~
---------------------------------------------------------------------------------
-- 
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
-- 
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

-- library unisim is required for Xilinx primitives
library unisim;
use unisim.vcomponents.all;

-- library PROC_COMMON contains the PSELECT module and the 
-- package with the RESET_ACTIVE constant and log2 and addr_bits functions
library proc_common_v1_00_b;
use proc_common_v1_00_b.pselect;
use proc_common_v1_00_b.proc_common_pkg.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      C_NUM_MASTERS               -- number of masters
--      C_PLB_AWIDTH                -- PLB address bus width
--      C_DCR_AWIDTH                -- DCR address bus width
--      C_DCR_DWIDTH                -- DCR data bus width
--      C_BASEADDR                  -- DCR base address of PLB 
--      C_HIGHADDR                  -- DCR high address of PLB
--
-- Definition of Ports:
--      input  Clk                  -- clock
--      input  ArbReset             -- reset
--      input  DCR_Write            -- DCR write command
--      input  DCR_Read             -- DCR read command
--      input  DCR_ABus             -- DCR address bus
--      input  DCR_DBus             -- DCR data bus
--      input  WdtCountIsZero       -- watchdog timeout
--      input  WdtAddrAck           -- watchdog timer address ack
--      input  ArbAddrSelReg        -- master currently controlling PLB
--      input  Sl_addrAck           -- slave address ack
--      input  PLB_RNW              -- read/write
--      input  PLB_ABus             -- PLB address bus
--      input  PLB_BE               -- PLB byte enables
--      input  PLB_size             -- PLB size
--      input  PLB_type             -- PLB type
--      input  M_lockErr            -- master indication to lock register on error
--
--      output PLB_dcrAck           -- DCR acknowledge from PLB
--      output PLB_dcrDBus          -- DCR data from PLB
--      output Intr_en              -- interrupt enable
--      output SW_Rst               -- software reset
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity dcr_regs is
  generic ( C_NUM_MASTERS     : integer   := 8;  
            C_PLB_AWIDTH      : integer   := 32;
            C_PLB_DWIDTH      : integer   := 64;
            C_DCR_AWIDTH      : integer   := 10;   
            C_DCR_DWIDTH      : integer   := 32;   
            C_BASEADDR        : std_logic_vector;
            C_HIGHADDR        : std_logic_vector
           );

  port (
        Clk             : in std_logic;
        ArbReset        : in std_logic;
        DCR_Write       : in std_logic;
        DCR_Read        : in std_logic;
        DCR_ABus        : in std_logic_vector (0 to C_DCR_AWIDTH-1);
        DCR_DBus        : in std_logic_vector (0 to C_DCR_DWIDTH-1);
        PLB_dcrAck      : out std_logic;
        PLB_dcrDBus     : out std_logic_vector (0 to C_DCR_DWIDTH-1);
        WdtCountIsZero  : in std_logic;
        WdtAddrAck      : in std_logic;
        ArbAddrSelReg   : in std_logic_vector (0 to C_NUM_MASTERS-1);
        Sl_addrAck      : in std_logic;
        PLB_RNW         : in std_logic;
        PLB_ABus        : in std_logic_vector (0 to C_PLB_AWIDTH-1);
        PLB_BE          : in std_logic_vector (0 to C_PLB_DWIDTH/8-1);
        PLB_size        : in std_logic_vector (0 to 3);
        PLB_type        : in std_logic_vector (0 to 2);
        M_lockErr       : in std_logic_vector (0 to C_NUM_MASTERS-1);
        Intr_en         : out std_logic;
        SW_Rst          : out std_logic
        );
end dcr_regs;
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture implementation of dcr_regs is

-------------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------------- 
constant DEV_ADDR_DECODE_WIDTH : integer := 
                            Addr_Bits(C_BASEADDR,C_HIGHADDR);

constant DCR_NUM_REGS   : integer := 8;
constant NUMREG_BITS   : integer := log2(DCR_NUM_REGS);

-- register offsets
constant MERR_DETECT_OFFSET : std_logic_vector(0 to NUMREG_BITS-1) := "000";
constant MDRIVE_PEAR_OFFSET : std_logic_vector(0 to NUMREG_BITS-1) := "001";
constant RNW_ERR_OFFSET     : std_logic_vector(0 to NUMREG_BITS-1) := "010";
constant LCK_ERR_OFFSET     : std_logic_vector(0 to NUMREG_BITS-1) := "011";
constant ADDR_OFFSET        : std_logic_vector(0 to NUMREG_BITS-1) := "100";
constant BYTE_EN_OFFSET     : std_logic_vector(0 to NUMREG_BITS-1) := "101";
constant SIZE_TYPE_OFFSET   : std_logic_vector(0 to NUMREG_BITS-1) := "110";
constant CTRL_OFFSET        : std_logic_vector(0 to NUMREG_BITS-1) := "111";

-- control register bit locations
constant INTR_EN_BIT        : integer := 0;
constant SW_RST_BIT         : integer := 1;
constant TST_EN_BIT         : integer := 2;
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- internal version of output signals 
signal plb_dcrack_i     : std_logic;

-- DCR Bus pipeline signals
signal dcr_dbus_d1      : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal dcr_abus_d1      : std_logic_vector(0 to C_DCR_AWIDTH-1) := (others => '0');
signal dcr_read_d1      : std_logic;
signal dcr_write_d1     : std_logic;

-- PLB Bus pipeline signals
signal wdtcountiszero_d1    : std_logic;
signal wdtaddrack_d1        : std_logic;
signal arbaddrselreg_d1     : std_logic_vector(0 to C_NUM_MASTERS-1) := (others => '0');
signal sl_addrack_d1        : std_logic;
signal plb_rnw_d1           : std_logic;
signal plb_abus_d1          : std_logic_vector(0 to C_PLB_AWIDTH-1);
signal plb_be_d1            : std_logic_vector(0 to C_PLB_DWIDTH/8 -1);
signal plb_size_d1          : std_logic_vector(0 to 3);
signal plb_type_d1          : std_logic_vector(0 to 2);
signal m_lockerr_d1         : std_logic_vector(0 to C_NUM_MASTERS-1);

-- DCR address decode signals
signal dcr_address_valid    : std_logic;
signal dcr_abus_slice       : std_logic_vector(0 to NUMREG_BITS-1);
signal dcr_plb_access       : std_logic;

-- DCR data signal
signal read_data         : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');

-- PEAR/PESR signals
signal arbTimeOut       : std_logic;

signal pear_addr            : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pear_byte_en         : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pear_size_type       : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal clear_error          : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pesr_merr_detect     : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pesr_lck_err         : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pesr_mdrive_pear     : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pesr_rnw_err         : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal pacr                 : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');

signal enable_pesr_update   : std_logic_vector(0 to C_NUM_MASTERS-1);
signal locked               : std_logic_vector(0 to C_NUM_MASTERS-1);
signal not_locked_PEAR      : std_logic;
signal pesr_mdrive_pear_ce  : std_logic;

-- Control signal
signal tst_en               : std_logic;
-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
component pselect
  generic
  (
    C_AB  : integer := 7;
    C_AW  : integer := 10;
    C_BAR : std_logic_vector := "0000000000"
  );
  port
  (
    A      : in  std_logic_vector(0 to C_AW - 1);
    AValid : in  std_logic;
    CS     : out std_logic
  );
end component pselect;

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
-- Assign output signals
PLB_dcrAck <= plb_dcrack_i;
Intr_en    <= pacr(INTR_EN_BIT);
SW_rst     <= pacr(SW_RST_BIT);

-- assign test enable signal
tst_en     <= pacr(TST_EN_BIT);
-------------------------------------------------------------------------------
--  PLB Interface
-------------------------------------------------------------------------------
-- register PLB bus input signals
PLB_BUS_REGS: process (Clk)
begin
    if Clk'event and Clk = '1' then
        if Arbreset = RESET_ACTIVE then
            wdtcountiszero_d1 <= '0';
            wdtaddrack_d1 <= '0';
            arbaddrselreg_d1 <= (others => '0');
            sl_addrack_d1 <= '0';
            plb_rnw_d1 <= '0';
            plb_abus_d1 <= (others => '0');
            plb_be_d1 <= (others => '0');
            plb_size_d1 <= (others => '0');
            plb_type_d1 <= (others => '0');
            m_lockerr_d1 <= (others => '0');
        else
           wdtcountiszero_d1 <= wdtCountIsZero;
           wdtaddrack_d1 <= wdtAddrAck;
           arbaddrselreg_d1 <= arbAddrSelReg;
           sl_addrack_d1 <= Sl_addrAck;
           plb_rnw_d1 <= PLB_RNW;
           plb_abus_d1 <= PLB_ABus;
           plb_be_d1 <= PLB_BE;
           plb_size_d1 <= PLB_size;
           plb_type_d1 <= PLB_type;
           m_lockerr_d1 <= M_lockErr;
        end if;
    end if;
end process PLB_BUS_REGS;

-------------------------------------------------------------------------------
--  PESR Registers
-------------------------------------------------------------------------------
--  PESR register Definitions 
--      pesr_merr_detect     - Which master generated an error
--      pesr_rnw_err         - For each master, was error rd (1) or wr (0)
--      pesr_mdrive_pear     - One-hot, which master is driving the PEAR values
--      pesr_lck_err         - For each master. Are it's PESR flags
--                              locked (1) or unlocked (0). If unlocked above PESRs
--                              can be overwritten by the next error
-------------------------------------------------------------------------------

arbTimeOut <= wdtaddrack_d1 and not(sl_addrack_d1);

PESR_MERR_DETECT_GEN: for i in 0 to C_NUM_MASTERS-1 generate
    MERR_DETECT_PROCESS: process (Clk)
    begin
        if (Clk'event and Clk = '1' ) then
            if ArbReset = RESET_ACTIVE  then
                pesr_merr_detect(i) <= '0';
            else
                pesr_merr_detect(i) <= not(clear_error(i)) and
                 ((arbaddrselreg_d1(i) and arbTimeOut) or pesr_merr_detect(i));
            end if ;
        end if;
    end process MERR_DETECT_PROCESS;
end generate PESR_MERR_DETECT_GEN;

PESR_LCK_ERR_GEN: for i in 0 to C_NUM_MASTERS-1 generate
    LCK_ERR_PROCESS: process (Clk)
    begin
        if (Clk'event and Clk = '1' ) then
            if ArbReset = RESET_ACTIVE  then
                pesr_lck_err(i) <= '0';
            else
                pesr_lck_err(i) <= not(clear_error(i)) and
                   ((arbaddrselreg_d1(i) and arbTimeOut and m_lockerr_d1(i)) or pesr_lck_err(i));
            end if ;
        end if;
    end process LCK_ERR_PROCESS;
end generate PESR_LCK_ERR_GEN;

--  Generate status bits for "rd_wr_n"  fields of PESR
RNW_ERR_GENERATE: for i in 0 to C_NUM_MASTERS -1 generate
begin
    enable_pesr_update(i) <= arbaddrselreg_d1(i) and arbTimeOut
                            and not(pesr_lck_err(i));

    PESR_RNW_ERR_FF_I: fdre
      port map (
                Q   => pesr_rnw_err(i),         --[out]
                C   => Clk,                     --[in]
                CE  => enable_pesr_update(i),   --[in]
                D   => plb_rnw_d1,              --[in]
                R   => clear_error(i)           --[in]
                );

end generate RNW_ERR_GENERATE;

ISLOCKED_PROCESS: process (pesr_lck_err, pesr_mdrive_pear)
begin
    for i in 0 to C_NUM_MASTERS-1 loop
        locked(i) <= pesr_lck_err(i) and pesr_mdrive_pear(i);
    end loop;
end process ISLOCKED_PROCESS;

not_locked_PEAR <= '1' when or_reduce(locked)='0'
                    else '0';
                    
pesr_mdrive_pear_ce <= arbTimeOut and not_locked_PEAR;  

MDRIVE_PEAR_GENERATE: for i in 0 to C_NUM_MASTERS-1 generate
    PESR_MDRIVE_PEAR_FF_I: fdre
      port map (
                Q   => pesr_mdrive_pear(i), --[out]
                C   => Clk, --[in]
                CE  => pesr_mdrive_pear_ce, --[in]
                D   => arbaddrselreg_d1(i), --[in]
                R   => clear_error(i)--[in]
                );
end generate MDRIVE_PEAR_GENERATE;              

-- if number of masters is less than dcr data width, zero the remaining bits of the registers
NUMMASTERS_LT_DCRDWIDTH: if C_NUM_MASTERS < C_DCR_DWIDTH generate
    pesr_merr_detect(C_NUM_MASTERS to C_DCR_DWIDTH-1)   <= (others => '0');
    pesr_lck_err(C_NUM_MASTERS to C_DCR_DWIDTH-1)       <= (others => '0');
    pesr_rnw_err(C_NUM_MASTERS to C_DCR_DWIDTH-1)       <= (others => '0');
    pesr_mdrive_pear(C_NUM_MASTERS to C_DCR_DWIDTH-1)    <= (others => '0');
end generate  NUMMASTERS_LT_DCRDWIDTH;   

-------------------------------------------------------------------------------
--  PEAR Registers
--  These registers are writable if the test enable bit has been set
-------------------------------------------------------------------------------
process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if ArbReset = RESET_ACTIVE then
        pear_addr <= (others => '0');
        pear_byte_en <= (others => '0');
        pear_size_type <= (others => '0');
    elsif tst_en = '1' and dcr_write_d1='1' and dcr_address_valid='1' and plb_dcrack_i = '0' then
        if dcr_abus_slice = ADDR_OFFSET then
            -- since C_PLB_AWIDTH = C_DCR_DWIDTH, don't need to slice 
            pear_addr <= dcr_dbus_d1;
        elsif dcr_abus_slice = BYTE_EN_OFFSET then
            pear_byte_en(0 to C_PLB_DWIDTH/8-1) <= dcr_dbus_d1(0 to C_PLB_DWIDTH/8-1);
        elsif dcr_abus_slice = SIZE_TYPE_OFFSET then
            pear_size_type(0 to 6) <= dcr_dbus_d1(0 to 6);
        end if;
    elsif arbTimeOut = '1'  and not_locked_PEAR= '1' and wdtcountiszero_d1 = '1' then
        -- since C_PLB_AWIDTH = C_DCR_DWIDTH, don't need to slice 
        pear_addr <= plb_abus_d1;
        pear_byte_en(0 to C_PLB_DWIDTH/8-1) <= plb_be_d1;
        pear_size_type(0 to 6) <= plb_size_d1 & plb_type_d1;
    else
        pear_addr <= pear_addr;
        pear_byte_en <= pear_byte_en;
        pear_size_type <= pear_size_type;
    end if ;
  end if;
end process ;
            
-------------------------------------------------------------------------------
--  DCR Register Interface
-------------------------------------------------------------------------------
-- register DCR bus input signals
-- Note: these registers are not reset because they need to hold their values
-- during a SW reset
DCR_BUS_REGS: process (Clk)
begin
    if Clk'event and Clk = '1' then
            dcr_dbus_d1 <= DCR_DBus;
            dcr_abus_d1 <= DCR_ABus;
            dcr_read_d1 <= DCR_Read;
            dcr_write_d1 <= DCR_Write;
    end if;
end process DCR_BUS_REGS;

-------------------------------------------------------------------------------
--    DCR Address Decode
-------------------------------------------------------------------------------
-- Determine if the address is valid
--dcr_address_valid <= DCR_Read or DCR_Write;
dcr_address_valid <= dcr_read_d1 or dcr_write_d1;

ZERO_DEVADDR_BITS_GEN: if DEV_ADDR_DECODE_WIDTH = 0 generate
    dcr_plb_access <= dcr_address_valid;
end generate ZERO_DEVADDR_BITS_GEN;

ONE_DEVADDR_BITS_GEN: if DEV_ADDR_DECODE_WIDTH = 1 generate
    dcr_plb_access <= dcr_address_valid and 
                (dcr_abus_d1(0) xnor C_BASEADDR(0));
end generate ONE_DEVADDR_BITS_GEN;

MULTI_DEVADDR_BITS_GEN: if DEV_ADDR_DECODE_WIDTH > 1 generate
    -- Use PSELECT module to decode the base address
    DCR_BASEADDR_DECODE_I: pselect
        generic map
        (
          C_AB => DEV_ADDR_DECODE_WIDTH,
          C_AW => C_DCR_AWIDTH,
          C_BAR => C_BASEADDR
        )
        port map
        (
          A      => dcr_abus_d1,
          AValid => dcr_address_valid,
          CS     => dcr_plb_access
        );
end generate MULTI_DEVADDR_BITS_GEN;


-------------------------------------------------------------------------------
-- DCR Read
-------------------------------------------------------------------------------
dcr_abus_slice <= dcr_abus_d1(C_DCR_AWIDTH-NUMREG_BITS to C_DCR_AWIDTH-1);

READDAT_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if dcr_plb_access='1' and dcr_read_d1 = '1' and plb_dcrack_i='0' then
       if  dcr_abus_slice = MERR_DETECT_OFFSET then
               read_data <= pesr_merr_detect;
       elsif dcr_abus_slice = MDRIVE_PEAR_OFFSET then
               read_data <= pesr_mdrive_pear;
       elsif dcr_abus_slice = RNW_ERR_OFFSET then
               read_data <= pesr_rnw_err; 
       elsif dcr_abus_slice = LCK_ERR_OFFSET then
               read_data <= pesr_lck_err;
       elsif dcr_abus_slice = ADDR_OFFSET then
               read_data <= pear_addr ;
       elsif dcr_abus_slice = BYTE_EN_OFFSET then
               read_data <= pear_byte_en ;
       elsif dcr_abus_slice = SIZE_TYPE_OFFSET then
               read_data <= pear_size_type ;
       elsif dcr_abus_slice = CTRL_OFFSET then
               read_data <= pacr;
       else
               read_data <= (others => '0');
       end if;
    end if;
  end if;
end process READDAT_REG;

PLB_dcrDBus <= read_data 
            when (dcr_plb_access='1' and dcr_read_d1='1' and plb_dcrack_i='1')
            else DCR_DBus;

-------------------------------------------------------------------------------
-- DCR Write PACR and MERR_DETECT (clear error)
-------------------------------------------------------------------------------
DCRWRITE_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if ArbReset = RESET_ACTIVE  then
      clear_error <= (others => '1');
      pacr(INTR_EN_BIT) <= '1';   -- interrupts default to enabled state
      pacr(SW_RST_BIT) <= '0';
      pacr(TST_EN_BIT) <= '0';
    elsif dcr_write_d1='1' and dcr_address_valid='1' and PLB_dcrAck_i = '0' then
        if dcr_abus_slice = MERR_DETECT_OFFSET then
                clear_error <= dcr_dbus_d1;
        elsif dcr_abus_slice = CTRL_OFFSET then    
                pacr(INTR_EN_BIT) <= dcr_dbus_d1(INTR_EN_BIT);
                pacr(SW_RST_BIT)  <= dcr_dbus_d1(SW_RST_BIT);
                pacr(TST_EN_BIT)  <= dcr_dbus_d1(TST_EN_BIT);
        else
                clear_error <= (others => '0');
                pacr <= pacr;
        end if;
    else
        clear_error <= (others => '0');
        pacr <= pacr;
    end if;
 end if;
end process DCRWRITE_REG;
            
-------------------------------------------------------------------------------
-- DCR Ack
-------------------------------------------------------------------------------
-- Don't reset this register because ACK still needs to assert when the SW reset
-- is asserted.
DCRACK_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
        plb_dcrack_i <= ((DCR_Read or DCR_Write)) and dcr_plb_access;
  end if;
end process DCRACK_REG;


end implementation;

