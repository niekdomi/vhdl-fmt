-------------------------------------------------------------------------------
--  $Id: watchdog_timer.vhd,v 1.1 2004/05/13 20:36:05 mlovejoy Exp $
-------------------------------------------------------------------------------
-- watchdog_timer.vhd - entity/architecture pair
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
-- Filename:        watchdog_timer.vhd
-- Description:     v1.01aThis file contains the watchdog timer for the PLB. It will
--                  generate addrAck if the slave has not responded within 16
--                  clocks after PAValid or SAValid asserts. It will also 
--                  appropriately assert the data acks to complete transfers
--                  along with the master error signal.
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
-- Author:      BLT
-- History:
--      ALS     02/20/02        -- created from plb_arbiter_v1_01_a
--      ALS     04/16/02        -- Version v1.01a
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

-- PROC_COMMON library contains down_counter component
library proc_common_v1_00_b;
use proc_common_v1_00_b.all; 
-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--      No generics used
--
-- Definition of Ports:
--      -- Clock and Reset
--      input  Clk                      
--      input  ArbReset   
--
--      -- Priority Encoder Results
--      input  ArbAddrValidReg          
--
--      -- PLB Transfer signals
--      input  PLB_size                 
--      input  PLB_AValid               
--      input  PLB_RNW                  
--      input  PLB_rdBurst              
--      input  PLB_wrBurst              
--      input  PLB_abort                
--
--      -- Slave transfer responses
--      input  Sl_addrAck               
--      input  Sl_rearbitrate           
--      input  Sl_wait                  
--
--      -- Watchdog timer transfer responses
--      output WdtAddrAck               
--      output WdtRdBTerm               
--      output WdtWrBTerm               
--      output WdtRdComp                
--      output WdtWrComp                
--      output WdtRdDAck                
--      output WdtWrDAck                
--      output PLB_rdWdAddrWDT  
--
--      -- Watchdog timer status signals 
--      output WdtCountIsZero           
--      output WdtTimeOutReg            
--      output WdtTimeOutAct            
--      output WdtTimeOutBusy           
-------------------------------------------------------------------------------
 
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity watchdog_timer is
  port (
        Clk                 : in std_logic;
        ArbReset            : in std_logic;
        ArbAddrValidReg     : in std_logic;
        PLB_size            : in std_logic_vector (0 to 3);
        PLB_AValid          : in std_logic;
        PLB_RNW             : in std_logic;
        PLB_rdBurst         : in std_logic;
        PLB_wrBurst         : in std_logic;
        PLB_abort           : in std_logic;
        Sl_addrAck          : in std_logic;
        Sl_rearbitrate      : in std_logic;
        Sl_wait             : in std_logic;
        WdtAddrAck          : out std_logic;
        WdtRdBTerm          : out std_logic;
        WdtWrBTerm          : out std_logic;
        WdtRdComp           : out std_logic;
        WdtWrComp           : out std_logic;
        WdtRdDAck           : out std_logic;
        WdtWrDAck           : out std_logic;
        PLB_rdWdAddrWDT     : out std_logic_vector (0 to 3);
        WdtCountIsZero      : out std_logic;
        WdtTimeOutReg       : out std_logic;
        WdtTimeOutAct       : out std_logic;
        WdtTimeOutBusy      : out std_logic
        );
end watchdog_timer;
 
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of watchdog_timer is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- define internal versions of output signals

signal wdtAddrAck_i         : std_logic;
signal wdtRdBTerm_i         : std_logic;
signal wdtWrBTerm_i         : std_logic;
signal wdtRdComp_i          : std_logic;
signal wdtWrComp_i          : std_logic;
signal wdtRdDAck_i          : std_logic;
signal wdtWrDAck_i          : std_logic;
signal wdtCountIsZero_i     : std_logic;
signal wdtTimeOutReg_i      : std_logic;
signal wdtTimeOutIn         : std_logic;
signal wdtTimeOutBusy_i     : std_logic;
 
 
signal wdtDAckIn            : std_logic;
signal wdtCompIn            : std_logic;
signal wdtDAckReg           : std_logic;
signal wdtCompReg           : std_logic;

-- TimeOut Counter Signals
signal wdtTimeOutCntrReset  : std_logic;
signal wdtTimeOutCountIn    : std_logic_vector(0 to 3 );
signal wdtTimeOutCount      : std_logic_vector(0 to 3 );
signal wdtTimeOutCntrEnable : std_logic;
signal wdtTimeOutCntrLoad   : std_logic;
signal wdtTimeOutCntrDin    : std_logic_vector(0 to 3 );

signal rdwdAddr             : std_logic_vector(0 to 3 );
signal wdtSingleAccIn       : std_logic;
signal wdtLine4AccIn        : std_logic;
signal wdtLine8AccIn        : std_logic;
signal wdtLine16AccIn       : std_logic;
signal wdtBurstAccIn        : std_logic;
signal wdtSingleAccReg      : std_logic;
signal wdtLine4AccReg       : std_logic;
signal wdtLine8AccReg       : std_logic;
signal wdtLine16AccReg      : std_logic;
signal wdtBurstAccReg       : std_logic;
signal wdtLine              : std_logic;

-- Data Ack Counter Signals
signal wdtDAckCntrEnable    : std_logic;   
signal wdtDAckCntrEnd       : std_logic;
signal wdtDAckNewCount      : std_logic_vector(0 to 3 );
signal wdtDAckCount         : std_logic_vector(0 to 3 );
signal wdtDAckCountReg      : std_logic_vector(0 to 3 );

signal PLB_RNWReg           : std_logic;
signal PLB_RNWRegReg        : std_logic;
signal wdtTimeOutG1         : std_logic;
signal wdtTransferSizeG1    : std_logic;
signal wdtControlStatesG1   : std_logic;

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- Down counter used to count cycles from PAValid to slave response

component down_counter 
  generic ( C_CNT_WIDTH : INTEGER := 4 );
  port (
        Din     : in std_logic_vector(0 to C_CNT_WIDTH - 1);
        Load    : in std_logic;
        Cnt_en  : in std_logic;  
        Cnt_out : out std_logic_vector(0 to C_CNT_WIDTH - 1 );
        Clk     : in std_logic;
        Rst     : in std_logic
        );
 
end component down_counter;


-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
  
begin
 
  WdtWrBTerm        <= wdtWrBTerm_i;
  WdtWrDAck         <= wdtWrDAck_i;
  WdtTimeOutReg     <= wdtTimeOutReg_i;
  WdtRdBTerm        <= wdtRdBTerm_i;
  WdtRdDAck         <= wdtRdDAck_i;
  WdtCountIsZero    <= wdtCountIsZero_i;
  WdtAddrAck        <= wdtAddrAck_i;
  WdtWrComp         <= wdtWrComp_i;
  WdtRdComp         <= wdtRdComp_i;
  WdtTimeOutBusy    <= wdtTimeOutBusy_i;
 
-------------------------------------------------------------------------------
--    Transfer Time Out Counter
--
--    This 4-bit down-counter is used to determine when a timeout has occured on
--    the PLB bus.  A timeout on the PLB bus is defined as the slaves not asserting
--    Sl_addrAck or Sl_wait within 16 cycles of the assertion of the PLB_AValid
--    signal by the PLB arbiter.
-------------------------------------------------------------------------------

wdtTimeOutCntrLoad <= (PLB_AValid and PLB_abort) 
                        or Sl_addrAck 
                        or Sl_rearbitrate 
                        or ArbReset;
wdtTimeOutCntrReset  <= '0';

wdtTimeOutCntrEnable <= not(Sl_wait) and PLB_AValid;
wdtTimeOutCntrDin   <= (others => '1');

WDT_TIMEOUT_CNTR_I: down_counter 
   generic map  (   C_CNT_WIDTH => 4 )
   port map (
                    Din     => wdtTimeOutCntrDin,
                    Load    => wdtTimeOutCntrLoad,
                    Cnt_en  => wdtTimeOutCntrEnable,         
                    Cnt_out => wdtTimeOutCount,
                    Clk     => Clk,
                    Rst     => wdtTimeOutCntrReset
            );
  

-------------------------------------------------------------------------------
--    wdtAddrAck generation
-------------------------------------------------------------------------------

wdtCountIsZero_i <= not(wdtTimeOutCount(0)) 
                    and not(wdtTimeOutCount(1))
                    and not(wdtTimeOutCount(2)) 
                    and not(wdtTimeOutCount(3));
                    
wdtAddrAck_i     <= wdtCountIsZero_i 
                    and not(Sl_rearbitrate) 
                    and not(Sl_wait);
                    
-------------------------------------------------------------------------------
--    wdtTimeOutReg generation
-------------------------------------------------------------------------------
--  The wdtTimeOutReg state is entered anytime ~Sl_addrAck and a valid count 
--  of 0 is detected.
--  This state is exited automatically after 1 clock cycle.
wdtTimeOutIn <= arbAddrValidReg and not(PLB_abort) and not(Sl_addrAck) 
                and wdtAddrAck_i;

TIMEOUTREG_PROCESS: process (Clk)
begin
    if Clk'event and Clk = '1' then
        if ArbReset = '1' then
            wdtTimeOutReg_i <= '0';
        elsif wdtCountIsZero_i = '1' then
            wdtTimeOutReg_i <= wdtTimeOutIn;                       
        else
            wdtTimeOutReg_i <= '0';
        end if;
    end if;
end process TIMEOUTREG_PROCESS;

-------------------------------------------------------------------------------
--    Transfer Size Decode
-------------------------------------------------------------------------------

wdtSingleAccIn  <= '1' when PLB_size = "0000"   --    Single Access Size Decode
                    else '0';
wdtLine4AccIn   <= '1' when PLB_size = "0001"   --    Line Access Size Decode
                    else '0';
wdtLine8AccIn   <= '1' when PLB_size = "0010"
                    else '0';
wdtLine16AccIn  <= '1' when PLB_size = "0011"
                    else '0';
                    
--    Burst Access Size Decode
wdtBurstAccIn   <= PLB_size(0);

XFER_SIZE_PROCESS: process (Clk)
begin
    if Clk'event and Clk = '1' then
        if ArbReset = '1' then
            wdtSingleAccReg <= '0';
            wdtLine4AccReg  <= '0';
            wdtLine8AccReg  <= '0';
            wdtLine16AccReg <= '0';
            wdtBurstAccReg  <= '0';
            PLB_RNWReg      <= '0';
        elsif wdtCountIsZero_i = '1' then
            wdtSingleAccReg <= wdtSingleAccIn;
            wdtLine4AccReg  <= wdtLine4AccIn;
            wdtLine8AccReg  <= wdtLine8AccIn;
            wdtLine16AccReg <= wdtLine16AccIn;
            wdtBurstAccReg  <= wdtBurstAccIn;
            PLB_RNWReg      <= PLB_RNW;
        end if;
    end if;
end process XFER_SIZE_PROCESS;
            

                    
-------------------------------------------------------------------------------
--    wdtRdBTerm generation
-------------------------------------------------------------------------------
                    
wdtRdBTerm_i <= wdtTimeOutReg_i 
                and PLB_RNWReg 
                and PLB_rdBurst
                and wdtBurstAccReg;
                
-------------------------------------------------------------------------------
--    wdtWrBTerm generation
-------------------------------------------------------------------------------

wdtWrBTerm_i <= wdtTimeOutReg_i 
                and not(PLB_RNWReg) 
                and PLB_wrBurst 
                and wdtBurstAccReg;
                
                
-------------------------------------------------------------------------------
--    Data Acknowledge Counter
--
--    In the event of a PLB bus timeout for a line access, this 4-bit down-counter is used
--    to determine the number of DAcks required to properly terminate the bus cycle.
--
--    For any master device size, the counter is loaded for either 4, 8, or 16 count
--    depending on the requested line size.
-------------------------------------------------------------------------------

wdtLine <= wdtLine4AccIn or wdtLine8AccIn or wdtLine16AccIn;
wdtDAckNewCount(0) <= wdtLine16AccIn;
wdtDAckNewCount(1) <= wdtLine8AccIn or wdtLine16AccIn;
wdtDAckNewCount(2) <= wdtLine;
wdtDAckNewCount(3) <= wdtLine;


wdtDAckCntrEnable  <= wdtDAckReg or wdtCompReg or wdtTimeOutReg_i;

WDT_DACK_CNTR_I: down_counter 
   generic map  (   C_CNT_WIDTH => 4 )
   port map (
                    Din     => wdtDAckNewCount,
                    --Din     => wdtDAckCount,
                    Load    => wdtTimeOutIn,
                    --Load    => wdtTimeOutReg_i,
                    Cnt_en  => wdtDAckCntrEnable,         
                    Cnt_out => wdtDAckCountReg,
                    Clk     => Clk,
                    Rst     => ArbReset
            );


 wdtDAckCntrEnd <= '1' when wdtDAckCountReg = "0000"
                    else '0';

wdtDAckCount <= wdtDAckCountReg;
                
-------------------------------------------------------------------------------
--    Generate read word address for PLB timeouts that requested a line transfer
--    Use the line dack counter and invert the bits for the address.  Always start
--    at line address 0
-------------------------------------------------------------------------------
rdwdAddr(0) <= not(wdtDAckCount(0)) and wdtLine16AccReg;
rdwdAddr(1) <= not(wdtDAckCount(1)) and ((wdtLine8AccReg or wdtLine16AccReg));
rdwdAddr(2) <= not(wdtDAckCount(2));
rdwdAddr(3) <= not(wdtDAckCount(3));

PLB_rdWdAddrWDT <= rdwdAddr when (wdtTimeOutBusy_i = '1' and PLB_RNWReg = '1')
                    else (others => '0');
                    
-------------------------------------------------------------------------------
--    PLB Watchdog Timer Control States generation
-------------------------------------------------------------------------------

wdtDAckIn   <=  (((wdtTimeOutReg_i and not(wdtBurstAccReg)) 
                or (wdtDAckReg and wdtLine4AccReg and not(wdtDAckCntrEnd)) 
                or (wdtDAckReg and wdtLine8AccReg and not(wdtDAckCntrEnd)) 
                or (wdtDAckReg and wdtLine16AccReg and not(wdtDAckCntrEnd)))) 
                and not(arbReset);
                

wdtCompIn   <=  (wdtTimeOutReg_i and wdtSingleAccReg) 
                or (wdtTimeOutReg_i and wdtBurstAccReg 
                    and not(((PLB_rdBurst and PLB_RNWReg) 
                            or (PLB_wrBurst and not(PLB_RNWReg))))) 
                or wdtRdBTerm_i
                or wdtWrBTerm_i 
                or (wdtDAckReg and not(wdtDAckIn) and not(wdtCompReg));

              
CTRL_STATES_PROCESS: process (Clk)
begin
    if Clk'event and Clk = '1' then
        if ArbReset = '1' then
            wdtDAckReg      <= '0';
            wdtCompReg      <= '0';
            PLB_RNWRegReg   <= '0';
        elsif wdtTimeOutReg_i = '1' or wdtDAckReg = '1' 
              or wdtCompReg = '1' then
            wdtDAckReg      <= wdtDAckIn;
            wdtCompReg      <= wdtCompIn;
            PLB_RNWRegReg   <= PLB_RNWReg;
        end if;
    end if;
end process CTRL_STATES_PROCESS;
              
-------------------------------------------------------------------------------
--    wdtRdComp, wdtWrComp Generation
-------------------------------------------------------------------------------
wdtRdComp_i <= wdtCompReg and PLB_RNWRegReg;
wdtWrComp_i <= wdtCompReg and not(PLB_RNWRegReg);

-------------------------------------------------------------------------------
--    wdtRdDAck, wdtWrDAck Generation
-------------------------------------------------------------------------------
wdtRdDAck_i <= ((wdtDAckReg or wdtCompReg)) and PLB_RNWRegReg;
wdtWrDAck_i <= ((wdtDAckReg or wdtCompReg)) and not(PLB_RNWRegReg);

-------------------------------------------------------------------------------
--  Generate a couple of signals that define the timeout window for use in arb_top
-------------------------------------------------------------------------------
WdtTimeOutAct <= wdtTimeOutReg_i or wdtRdDAck_i or
                 wdtWrDAck_i or wdtRdComp_i or wdtWrComp_i or
                 wdtAddrAck_i;
WdtTimeOutBusy_i <= wdtTimeOutReg_i or wdtRdDAck_i or
                wdtWrDAck_i or wdtRdComp_i or wdtWrComp_i;

end ;

