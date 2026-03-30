-------------------------------------------------------------------------------
-- $Id: plb2opb_bridge_besr.vhd,v 1.1 2004/05/13 20:28:15 mlovejoy Exp $
-------------------------------------------------------------------------------
--  PLB to OPB Bridge Out, Bus Error Status Registers - Module
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
--  Filename:     plb2opb_bridge_besr.vhd
--  Version:      v1.01a
--  Description:
--    This module instantiates the bus error status and address registers
--    (BEAR/BESR). The BEAR/BESRs are accessed via a DCR Slave Interface
--
--  VHDL-Standard:   VHDL'93
--  Design Notes:
--    This module has 8 BEAR/BESR registers on DCR to flag errors on the
--    OPB bus resulting from this bridge's transactions:
--
--    DCR_BASE_ADDR + 0 : BESR_MERR_DETECT
--    [0:C_PLB_NUM_MASTERS-1]  = Error detected with corresponding master
--              Writing to this register field clears all the corresponding
--              master's BESR bits.
--
--    DCR_BASE_ADDR + 1 : BESR_MDRIVE_DETECT
--    [0:C_PLB_NUM_MASTERS-1] = The corresponding master has latched the
--              BEARs with its error information. BESR_MDRIVE_DETECT is one-hot.
--
--    DCR_BASE_ADDR + 2 : BESR_RNW_ERR
--    [0:C_PLB_NUM_MASTERS-1]  = Specifies if Error for corresponding master
--              is due to a Read (= 1) or Write (= 0) transaction
--
--    DCR_BASE_ADDR + 3 : BESR_ERR_TYPE
--    [0:C_PLB_NUM_MASTERS-1] = Specifies if Error for corresponding master
--              is due to a OPB Timeout (= 1) or ErrAck (= 0)
--
--    DCR_BASE_ADDR + 4 : BESR_LCK_ERR
--    [0:C_PLB_NUM_MASTERS-1] = Specifies if corresponding master's error
--              fields are locked (= 1) or unlocked (= 0). If unlocked, 
--              subsequent errors will overwrite error BESR fields
--
--    DCR_BASE_ADDR + 5 : BEAR_ADDR
--    [0:C_DCR_DWIDTH-1]  = OPB Address where error occurred
--
--    DCR_BASE_ADDR + 6 : BEAR_BYTE_EN
--    [0:C_OPB_DWIDTH/8-1] = OPB Byte Enable Value when error occurred
--
--    DCR_BASE_ADDR + 7 : BGO_CTRL_REG
--    [0]   = Interrupt Enable. Default value is enabled. If DCR interface is
--            parameterized away, interrupts will be enabled.
--    [1]   = BGO Reset. This provides a way for software to issue a reset to
--            the bridge.
--
-------------------------------------------------------------------------------
-- Structure:
--
--            -- plb2opb_bridge.vhd
--               -- plb2opb_bridge_plb_if.vhd
--                  -- plb2opb_bridge_srl16x30.vhd
--               -- plb2opb_bridge_xfer_if.vhd
--               -- plb2opb_bridge_rcv_data_if.vhd
--               -- plb2opb_bridge_opb_if.vhd
--               -- plb2opb_bridge_besr.vhd
--               -- plb2opb_bridge_interrupt.vhd
--
-------------------------------------------------------------------------------
-- Author:      
-- History:
--      KD          5/22/01     -- EA 2 Release
--      ALS         11/06/01    -- VHDL conversion
--      ALS         01/15/02
-- ^^^^^^
--      Modified the register definitions to match design spec. Added control
--      register containing interrupt enable and software reset bits. DCR 
--      signals are now registered off the DCR bus. BEARs are now reset.
-- ~~~~~~
--      ALS         04/17/02
-- ^^^^^^
--      Fixed SW reset so that none of the DCR interface signals are reset.
-- ~~~~~~
--      ALS     07/09/02            -- Version 1.00b
-- ^^^^^^
--  C_INCLUDE_BGI_TRANSABORT generic is no longer used.
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
-- 
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_MISC.all;
 
library unisim;
use unisim.vcomponents.all;

library proc_common_v1_00_b;
use proc_common_v1_00_b.proc_common_pkg.all;
use proc_common_v1_00_b.pselect;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity plb2opb_bridge_besr is
    generic( C_DCR_BASEADDR     : std_logic_vector;
             C_DCR_HIGHADDR     : std_logic_vector;
             C_DCR_AWIDTH       : integer := 10;
             C_DCR_DWIDTH       : integer := 32;
             C_PLB_NUM_MASTERS  : integer := 16;
             C_OPB_AWIDTH       : integer := 32;
             C_OPB_DWIDTH       : integer := 32
            );
  port (
        Clk             : in std_logic;
        Rst             : in std_logic;
        Err_ack_det     : in std_logic;
        Err_addr        : in std_logic_vector(0 to C_OPB_AWIDTH-1);
        Err_byte_enable : in std_logic_vector (0 to C_OPB_DWIDTH/8-1);
        Err_rd_wr_n     : in std_logic;
        Lock_err        : in std_logic;
        Master_id_decode : in std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
        Timeout_det     : in std_logic;
        DCR_ABus        : in std_logic_vector(0 to C_DCR_AWIDTH-1);
        DCR_DBus        : in std_logic_vector(0 to C_DCR_DWIDTH-1);
        DCR_Read        : in std_logic;
        DCR_Write       : in std_logic;
        BGO_dcrAck      : out std_logic;
        BGO_dcrDBus     : out std_logic_vector(0 to C_DCR_DWIDTH-1);
        Intr_en         : out std_logic;
        SW_rst          : out std_logic
        );
end plb2opb_bridge_besr;
 
-----------------------------------------------------------------------------
-- Architecture section
----------------------------------------------------------------------------- 
architecture plb2opb_bridge_besr of plb2opb_bridge_besr is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
constant DEV_ADDR_DECODE_WIDTH : integer := 
                            Addr_Bits(C_DCR_BASEADDR,C_DCR_HIGHADDR);

constant DCR_NUM_REGS   : integer := 8;
constant NUMREG_BITS    : integer := log2(DCR_NUM_REGS);

constant MERR_DETECT_OFFSET : std_logic_vector(0 to NUMREG_BITS-1) := "000";
constant MDRIVE_BEAR_OFFSET : std_logic_vector(0 to NUMREG_BITS-1) := "001";
constant RNW_ERR_OFFSET     : std_logic_vector(0 to NUMREG_BITS-1) := "010";
constant ERR_TYPE_OFFSET    : std_logic_vector(0 to NUMREG_BITS-1) := "011";
constant LCK_ERR_OFFSET     : std_logic_vector(0 to NUMREG_BITS-1) := "100";
constant ADDR_OFFSET        : std_logic_vector(0 to NUMREG_BITS-1) := "101";
constant BYTE_EN_OFFSET     : std_logic_vector(0 to NUMREG_BITS-1) := "110";
constant CTRL_OFFSET        : std_logic_vector(0 to NUMREG_BITS-1) := "111";

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- internal signal for output
signal BGO_dcrAck_i         : std_logic;
 
-- DCR Bus pipeline signals
signal dcr_dbus_d1      : std_logic_vector(0 to C_DCR_DWIDTH-1) := (others => '0');
signal dcr_abus_d1      : std_logic_vector(0 to C_DCR_AWIDTH-1) := (others => '0');
signal dcr_read_d1      : std_logic;
signal dcr_write_d1     : std_logic;

-- DCR address bus decode slice
signal dcr_abus_slice   : std_logic_vector(0 to NUMREG_BITS-1);

-- DCR registers and control/data input signals
signal bear_addr            : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal bear_byte_en         : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal clear_error          : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal besr_merr_detect     : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal besr_err_type        : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal besr_lck_err         : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal besr_mdrive_bear     : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal besr_rnw_err         : std_logic_vector(0 to C_DCR_DWIDTH-1 );
signal bgo_ctrl_reg         : std_logic_vector(0 to C_DCR_DWIDTH-1);

signal enable_besr_update   : std_logic_vector(0 to C_PLB_NUM_MASTERS-1 );
signal err_detect           : std_logic;
signal lock_err_status      : std_logic;
signal besr_mdrive_bear_ce  : std_logic;
signal not_locked_BEAR      : std_logic;
signal locked               : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);


-- DCR decode signal
signal dcr_address_valid    : std_logic;
signal dcr_addr_hit         : std_logic;

-- DCR read data
signal read_data            : std_logic_vector(0 to C_DCR_DWIDTH-1 );


-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

component pselect   
  generic (
    C_AB     : integer := 9;
    C_AW     : integer := 32;
    C_BAR    : std_logic_vector
    );
  port (
    A        : in   std_logic_vector(0 to C_AW-1);
    AValid   : in   std_logic;
    CS       : out  std_logic
    );
end component pselect;

-----------------------------------------------------------------------------
-- Begin architecture
-----------------------------------------------------------------------------
begin

-- assign outputs
BGO_dcrAck <= BGO_dcrAck_i;
Intr_en    <= bgo_ctrl_reg(0);
SW_rst     <= bgo_ctrl_reg(1);

-------------------------------------------------------------------------------
--  BESR Registers
-------------------------------------------------------------------------------
--  BESR register Definitions 
--      besr_merr_detect     - Which master generated an error
--      besr_rnw_err         - For each master, was error rd (1) or wr (0)
--      besr_err_type        - For each master, was error timeout(1) or errAck(0)
--      besr_mdrive_bear     - One-hot, which master is driving the BEAR values
--      besr_lck_err         - For each master. Are it's BESR flags
--                              locked (1) or unlocked (0). If unlocked above BESRs
--                              can be overwritten by the next error
--
--  Generate status bits for "error detect" fields of BESR
err_detect <= Err_ack_det or Timeout_det;

BESR_MERR_DETECT_GEN: for i in 0 to C_PLB_NUM_MASTERS-1 generate
    MERR_DETECT_PROCESS: process (Clk)
    begin
        if (Clk'event and Clk = '1' ) then
            if Rst = RESET_ACTIVE  then
                besr_merr_detect(i) <= '0';
            else
                besr_merr_detect(i) <= not(clear_error(i)) and
                 ((Master_id_decode(i) and err_detect) or besr_merr_detect(i));
            end if ;
        end if;
    end process MERR_DETECT_PROCESS;
end generate BESR_MERR_DETECT_GEN;

--  Generate status bits for "lock error" fields of BESR
lock_err_status <= ((Err_ack_det or Timeout_det)) and Lock_err after 1 ns;

BESR_LCK_ERR_GEN: for i in 0 to C_PLB_NUM_MASTERS-1 generate
    LCK_ERR_PROCESS: process (Clk)
    begin
        if (Clk'event and Clk = '1' ) then
            if Rst = RESET_ACTIVE  then
                besr_lck_err(i) <= '0';
            else
                besr_lck_err(i) <= not(clear_error(i)) and
                   ((Master_id_decode(i) and lock_err_status) or besr_lck_err(i));
            end if ;
        end if;
    end process LCK_ERR_PROCESS;
end generate BESR_LCK_ERR_GEN;

--  Generate status bits for "rd_wr_n" and "err_type" fields of BESR
RW_ERR_GENERATE: for i in 0 to C_PLB_NUM_MASTERS -1 generate
begin
    enable_besr_update(i) <= Master_id_decode(i) and err_detect
                            and not(besr_lck_err(i));

    BESR_RNW_ERR_FF_I: fdre
      port map (
                Q   => besr_rnw_err(i),         --[out]
                C   => Clk,                     --[in]
                CE  => enable_besr_update(i),   --[in]
                D   => Err_rd_wr_n,             --[in]
                R   => clear_error(i)           --[in]
                );

    BESR_ERR_TYPE_FF_I: fdre
      port map (
                Q   => besr_err_type(i),        --[out]
                C   => Clk,                     --[in]
                CE  => enable_besr_update(i),   --[in]
                D   => Timeout_det,             --[in]
                R   => clear_error(i)           --[in]
                );

end generate RW_ERR_GENERATE;

   
--  Generate status bits for "locked_addr" fields of BESR
ISLOCKED_PROCESS: process (besr_lck_err, besr_mdrive_bear)
begin
    for i in 0 to C_PLB_NUM_MASTERS-1 loop
        locked(i) <= besr_lck_err(i) and besr_mdrive_bear(i);
    end loop;
end process ISLOCKED_PROCESS;

not_locked_BEAR <= '1' when or_reduce(locked)='0'
                    else '0';
                    

besr_mdrive_bear_ce <= err_detect and not_locked_BEAR;        
MDRIVE_BEAR_GENERATE: for i in 0 to C_PLB_NUM_MASTERS-1 generate
    BESR_MDRIVE_BEAR_FF_I: fdre
      port map (
                Q   => besr_mdrive_bear(i), --[out]
                C   => Clk, --[in]
                CE  => besr_mdrive_bear_ce, --[in]
                D   => Master_id_decode(i), --[in]
                R   => clear_error(i)--[in]
                );
end generate MDRIVE_BEAR_GENERATE;              
    
-- if number of masters is less than dcr data width, zero the remaining bits of the registers
NUMMASTERS_LT_DCRDWIDTH: if C_PLB_NUM_MASTERS < C_DCR_DWIDTH generate
    besr_merr_detect(C_PLB_NUM_MASTERS to C_DCR_DWIDTH-1)   <= (others => '0');
    besr_lck_err(C_PLB_NUM_MASTERS to C_DCR_DWIDTH-1)       <= (others => '0');
    besr_rnw_err(C_PLB_NUM_MASTERS to C_DCR_DWIDTH-1)       <= (others => '0');
    besr_err_type(C_PLB_NUM_MASTERS to C_DCR_DWIDTH-1)      <= (others => '0');
    besr_mdrive_bear(C_PLB_NUM_MASTERS to C_DCR_DWIDTH-1)      <= (others => '0');
end generate  NUMMASTERS_LT_DCRDWIDTH;   

-------------------------------------------------------------------------------
--  BEAR Registers
-------------------------------------------------------------------------------
process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst = RESET_ACTIVE then
        bear_addr <= (others => '0');
        bear_byte_en <= (others => '0');
    elsif err_detect= '1'  and not_locked_BEAR= '1'  then
      bear_addr(0 to C_OPB_AWIDTH-1) <= Err_addr;
      bear_byte_en(0 to C_OPB_DWIDTH/8-1) <= Err_byte_enable;
    end if ;
  end if;
end process ;

-------------------------------------------------------------------------------
--  DCR Register Interface
-------------------------------------------------------------------------------
-- register DCR bus input signals
DCR_BUS_REGS: process (Clk)
begin
    if Clk'event and Clk = '1' then
       dcr_dbus_d1 <= DCR_DBus;
       dcr_abus_d1 <= DCR_ABus;
       dcr_read_d1 <= DCR_Read;
       dcr_write_d1 <= DCR_Write;
    end if;
end process DCR_BUS_REGS;

-- Determine if the address is valid
dcr_address_valid <= dcr_read_d1 or dcr_write_d1;

-------------------------------------------------------------------------------
--    DCR Address Decode
-------------------------------------------------------------------------------
ZERO_DEVADDR_BITS_GEN: if DEV_ADDR_DECODE_WIDTH = 0 generate
    dcr_addr_hit <= dcr_address_valid;
end generate ZERO_DEVADDR_BITS_GEN;

ONE_DEVADDR_BITS_GEN: if DEV_ADDR_DECODE_WIDTH = 1 generate
    dcr_addr_hit <= dcr_address_valid and 
                (dcr_abus_d1(0) xnor C_DCR_BASEADDR(0));
end generate ONE_DEVADDR_BITS_GEN;

MULTI_DEVADDR_BITS_GEN: if DEV_ADDR_DECODE_WIDTH > 1 generate
    -- Use PSELECT module to decode the base address
    DCR_BASEADDR_DECODE_I: pselect
        generic map
        (
          C_AB => DEV_ADDR_DECODE_WIDTH,
          C_AW => C_DCR_AWIDTH,
          C_BAR => C_DCR_BASEADDR
        )
        port map
        (
          A      => dcr_abus_d1,
          AValid => dcr_address_valid,
          CS     => dcr_addr_hit
        );
end generate MULTI_DEVADDR_BITS_GEN;

-------------------------------------------------------------------------------
-- DCR Ack
-------------------------------------------------------------------------------
DCRACK_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    BGO_dcrAck_i <= ((DCR_Read or DCR_Write)) and dcr_addr_hit;
  end if;
end process DCRACK_REG;

-------------------------------------------------------------------------------
-- DCR Read & Write 
-- clear_error register at address offset MERR_DETECT_OFFSET
-- bgo control register at address offset CTRL_OFFSET
-------------------------------------------------------------------------------
dcr_abus_slice <= dcr_abus_d1(C_DCR_AWIDTH-NUMREG_BITS to C_DCR_AWIDTH-1);

DCRWRITE_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if Rst = RESET_ACTIVE  then
      clear_error <= (others => '1');
      bgo_ctrl_reg(0) <= '1';   -- interrupts default to enabled state
      bgo_ctrl_reg(1 to C_DCR_DWIDTH-1) <= (others => '0');
    elsif dcr_write_d1='1' and dcr_addr_hit='1' and BGO_dcrAck_i = '0' then
        if dcr_abus_slice = MERR_DETECT_OFFSET then
                clear_error <= dcr_dbus_d1;
        elsif dcr_abus_slice = CTRL_OFFSET then    
                bgo_ctrl_reg <= dcr_dbus_d1;
        else
                clear_error <= (others => '0');
                bgo_ctrl_reg <= bgo_ctrl_reg;
        end if;
    else
        clear_error <= (others => '0');
    end if;
 end if;
end process DCRWRITE_REG;

DCRREAD_REG: process (Clk)
begin
  if (Clk'event and Clk = '1' ) then
    if dcr_read_d1='1' and dcr_addr_hit='1' and BGO_dcrAck_i='0' then
       if  dcr_abus_slice = MERR_DETECT_OFFSET then
               read_data <= besr_merr_detect;
       elsif dcr_abus_slice = MDRIVE_BEAR_OFFSET then
               read_data <= besr_mdrive_bear;
       elsif dcr_abus_slice = RNW_ERR_OFFSET then
               read_data <= besr_rnw_err; 
       elsif dcr_abus_slice = ERR_TYPE_OFFSET then
               read_data <= besr_err_type;
       elsif dcr_abus_slice = LCK_ERR_OFFSET then
               read_data <= besr_lck_err;
       elsif dcr_abus_slice = ADDR_OFFSET then
               read_data <= bear_addr ;
       elsif dcr_abus_slice = BYTE_EN_OFFSET then
               read_data <= bear_byte_en ;
       elsif dcr_abus_slice = CTRL_OFFSET then
               read_data <= bgo_ctrl_reg;
       else
               read_data <= (others => '0');
       end if;
   end if ;
  end if;
end process DCRREAD_REG;
            
BGO_dcrDBus <= read_data 
            when (dcr_addr_hit='1' and dcr_read_d1='1' and BGO_dcrAck_i='1') 
            else DCR_DBus;

end ;

