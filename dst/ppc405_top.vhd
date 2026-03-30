-------------------------------------------------------------------------------
--$Id: ppc405_top.vhd,v 1.6 2004/09/08 01:04:07 larsg Exp $
------------------------------------------------------------------------------
-- PPC405 wrapper - Top Level Module
-------------------------------------------------------------------------------
--
--               THESE DESIGNS ARE PROVIDED "AS IS" WITH NO WARRANTY
--               WHATSOEVER AND XILINX SPECIFICALLY DISCLAIMS ANY
--               IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
--               A PARTICULAR PURPOSE, OR AGAINST INFRINGEMENT.
--
--               THESE DESIGNS ARE XILINX CONFIDENTIAL MATERIAL
--               PROVIDED UNDER NDA.
--
--               Copyright (c) 1995-2002 Xilinx, Inc.  All rights reserved.
--               All rights reserved
--
------------------------------------------------------------------------------
-- Filename:       ppc405_top.vhd
-- Version:        v1.00a
-- Description:
--   This module is the top level file for the PLB Slave to OPB Master
--
-- Design Notes:
-------------------------------------------------------------------------------
-- Structure:
-------------------------------------------------------------------------------
-- Author:
-- History:
-------------------------------------------------------------------------------
-- @BEGIN_CHANGELOG EDK_Gmm
-- Added high address parameters for OCM DCR address ranges
-- to aid addressgen tool. No functional change.
-- @END_CHANGELOG
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics/parameters:                    "C_*"
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

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------

entity ppc405_top is
  generic (
    C_ISOCM_DCR_BASEADDR         : std_logic_vector(0 to 9) := "0000010000";
    C_ISOCM_DCR_HIGHADDR         : std_logic_vector(0 to 9) := "0000010011";
    C_DSOCM_DCR_BASEADDR         : std_logic_vector(0 to 9) := "0000100000";
    C_DSOCM_DCR_HIGHADDR         : std_logic_vector(0 to 9) := "0000100011";
    C_DISABLE_OPERAND_FORWARDING : integer                  := 1;
    C_MMU_ENABLE                 : integer                  := 1;
    C_DETERMINISTIC_MULT         : integer                  := 0;
    C_DCR_RESYNC                 : integer                  := 0
    );

  port (
    -- Clock and Power Management Interface / CPU Control Interface
    C405CPMCORESLEEPREQ    : out std_logic;
    C405CPMMSRCE           : out std_logic;
    C405CPMMSREE           : out std_logic;
    C405CPMTIMERIRQ        : out std_logic;
    C405CPMTIMERRESETREQ   : out std_logic;
    C405XXXMACHINECHECK    : out std_logic;
    CPMC405CLOCK           : in  std_logic;
    CPMC405CORECLKINACTIVE : in  std_logic;
    CPMC405CPUCLKEN        : in  std_logic;
    CPMC405JTAGCLKEN       : in  std_logic;
    CPMC405TIMERCLKEN      : in  std_logic;
    CPMC405TIMERTICK       : in  std_logic;
    MCBCPUCLKEN            : in  std_logic;
    MCBTIMEREN             : in  std_logic;
    MCPPCRST               : in  std_logic;
    PLBCLK                 : in  std_logic;
    DCRCLK                 : in  std_logic;  -- clock for pipelining DCR interface
    
    -- Reset Interface
    C405RSTCHIPRESETREQ : out std_logic;
    C405RSTCORERESETREQ : out std_logic;
    C405RSTSYSRESETREQ  : out std_logic;
    RSTC405RESETCHIP    : in  std_logic;
    RSTC405RESETCORE    : in  std_logic;
    RSTC405RESETSYS     : in  std_logic;

    -- Instruction Cache Unit PLB Interface
    C405PLBICUABUS        : out std_logic_vector(0 to 31);  -- [0:29]
    C405PLBICUBE          : out std_logic_vector(0 to 7);   -- M_BE
    C405PLBICURNW         : out std_logic;                  -- M_RNW
    C405PLBICUABORT       : out std_logic;
    C405PLBICUBUSLOCK     : out std_logic;                  -- M_busLock
    C405PLBICUU0ATTR      : out std_logic;
    C405PLBICUGUARDED     : out std_logic;                  -- M_guarded
    C405PLBICULOCKERR     : out std_logic;                  -- M_lockErr
    C405PLBICUMSIZE       : out std_logic_vector(0 to 1);   -- M_MSize
    C405PLBICUORDERED     : out std_logic;                  -- M_ordered
    C405PLBICUPRIORITY    : out std_logic_vector(0 to 1);
    C405PLBICURDBURST     : out std_logic;                  -- M_rdBurst
    C405PLBICUREQUEST     : out std_logic;
    C405PLBICUSIZE        : out std_logic_vector(0 to 3);   -- C405PLBICUSIZE
    C405PLBICUTYPE        : out std_logic_vector(0 to 2);   -- M_type
    C405PLBICUWRBURST     : out std_logic;                  -- M_wrBurst
    C405PLBICUWRDBUS      : out std_logic_vector(0 to 63);  -- M_wrDBus
    C405PLBICUCACHEABLE   : out std_logic;
    PLBC405ICUADDRACK     : in  std_logic;
    PLBC405ICUBUSY        : in  std_logic;
    PLBC405ICUERR         : in  std_logic;
    PLBC405ICURDBTERM     : in  std_logic;                  -- PLB_MRdBTerm
    PLBC405ICURDDACK      : in  std_logic;
    PLBC405ICURDDBUS      : in  std_logic_vector(0 to 63);
    PLBC405ICURDWDADDR    : in  std_logic_vector(0 to 3);   -- [1:3]
    PLBC405ICUREARBITRATE : in  std_logic;                  -- PLB_MRearbitrate
    PLBC405ICUWRBTERM     : in  std_logic;                  -- PLB_MWrBTerm
    PLBC405ICUWRDACK      : in  std_logic;                  -- PLB_MWrDAck
    PLBC405ICUSSIZE       : in  std_logic_vector(0 to 1);   -- PLB_MSSize
    PLBC405ICUSERR        : in  std_logic;                  -- PLB_SMErr
    PLBC405ICUSBUSYS      : in  std_logic;                  -- PLB_SMBusy

    -- Data Cache Unit PLB Interface
    C405PLBDCUABUS        : out std_logic_vector(0 to 31);
    C405PLBDCUBE          : out std_logic_vector(0 to 7);
    C405PLBDCURNW         : out std_logic;
    C405PLBDCUABORT       : out std_logic;
    C405PLBDCUBUSLOCK     : out std_logic;                 -- M_busLock
    C405PLBDCUU0ATTR      : out std_logic;
    C405PLBDCUGUARDED     : out std_logic;
    C405PLBDCULOCKERR     : out std_logic;                 -- M_lockErr
    C405PLBDCUMSIZE       : out std_logic_vector(0 to 1);  -- M_MSize
    C405PLBDCUORDERED     : out std_logic;                 -- M_ordered
    C405PLBDCUPRIORITY    : out std_logic_vector(0 to 1);
    C405PLBDCURDBURST     : out std_logic;                 -- M_rdBurst
    C405PLBDCUREQUEST     : out std_logic;
    C405PLBDCUSIZE        : out std_logic_vector(0 to 3);  -- C405PLBDCUSIZE2
    C405PLBDCUTYPE        : out std_logic_vector(0 to 2);  -- M_type
    C405PLBDCUWRBURST     : out std_logic;                 -- M_wrBurst
    C405PLBDCUWRDBUS      : out std_logic_vector(0 to 63);
    C405PLBDCUCACHEABLE   : out std_logic;
    C405PLBDCUWRITETHRU   : out std_logic;
    PLBC405DCUADDRACK     : in  std_logic;
    PLBC405DCUBUSY        : in  std_logic;
    PLBC405DCUERR         : in  std_logic;
    PLBC405DCURDBTERM     : in  std_logic;                 -- PLB_MRdBTerm
    PLBC405DCURDDACK      : in  std_logic;
    PLBC405DCURDDBUS      : in  std_logic_vector(0 to 63);
    PLBC405DCURDWDADDR    : in  std_logic_vector(0 to 3);  -- [1:3]
    PLBC405DCUREARBITRATE : in  std_logic;                 -- PLB_MRearbitrate
    PLBC405DCUWRBTERM     : in  std_logic;                 -- PLB_MWrBTerm
    PLBC405DCUWRDACK      : in  std_logic;
    PLBC405DCUSSIZE       : in  std_logic_vector(0 to 1);  -- PLB_MSSize
    PLBC405DCUSERR        : in  std_logic;                 -- PLB_SMErr
    PLBC405DCUSBUSYS      : in  std_logic;                 -- PLB_SMBusy

    -- Data Side XpressRAM Interface
    BRAMDSOCMCLK       : in  std_logic;
    BRAMDSOCMRDDBUS    : in  std_logic_vector(0 to 31);
    DSARCVALUE         : in  std_logic_vector(0 to 7);
    DSCNTLVALUE        : in  std_logic_vector(0 to 7);
    DSOCMBRAMABUS      : out std_logic_vector(8 to 29);
    DSOCMBRAMBYTEWRITE : out std_logic_vector(0 to 3);
    DSOCMBRAMEN        : out std_logic;
    DSOCMBRAMWRDBUS    : out std_logic_vector(0 to 31);
    DSOCMBUSY          : out std_logic;

    -- Instruction Side XpressRAM Interface
    BRAMISOCMCLK         : in  std_logic;
    BRAMISOCMRDDBUS      : in  std_logic_vector(0 to 63);
    ISARCVALUE           : in  std_logic_vector(0 to 7);
    ISCNTLVALUE          : in  std_logic_vector(0 to 7);
    ISOCMBRAMEN          : out std_logic;
    ISOCMBRAMEVENWRITEEN : out std_logic;
    ISOCMBRAMODDWRITEEN  : out std_logic;
    ISOCMBRAMRDABUS      : out std_logic_vector(8 to 28);
    ISOCMBRAMWRABUS      : out std_logic_vector(8 to 28);
    ISOCMBRAMWRDBUS      : out std_logic_vector(0 to 31);

    -- Device Control Register (DCR) Interface
    C405DCRABUS    : out std_logic_vector(0 to 9);
    C405DCRDBUSOUT : out std_logic_vector(0 to 31);
    C405DCRREAD    : out std_logic;
    C405DCRWRITE   : out std_logic;
    DCRC405ACK     : in  std_logic;
    DCRC405DBUSIN  : in  std_logic_vector(0 to 31);

    -- Interrupt Controller Interface
    EICC405CRITINPUTIRQ : in std_logic;
    EICC405EXTINPUTIRQ  : in std_logic;

    -- JTAG Interface
    C405JTGCAPTUREDR  : out std_logic;
    C405JTGEXTEST     : out std_logic;
    C405JTGPGMOUT     : out std_logic;
    C405JTGSHIFTDR    : out std_logic;
    C405JTGTDO        : out std_logic;
    C405JTGTDOEN      : out std_logic;
    C405JTGUPDATEDR   : out std_logic;
    MCBJTAGEN         : in  std_logic;
    JTGC405BNDSCANTDO : in  std_logic;
    JTGC405TCK        : in  std_logic;
    JTGC405TDI        : in  std_logic;
    JTGC405TMS        : in  std_logic;
    JTGC405TRSTNEG    : in  std_logic;

    -- Debug Interface
    C405DBGMSRWE            : out std_logic;
    C405DBGSTOPACK          : out std_logic;
    C405DBGWBCOMPLETE       : out std_logic;
    C405DBGWBFULL           : out std_logic;
    C405DBGWBIAR            : out std_logic_vector(0 to 29);
    DBGC405DEBUGHALT        : in  std_logic;
    DBGC405EXTBUSHOLDACK    : in  std_logic;
    DBGC405UNCONDDEBUGEVENT : in  std_logic;

    -- Trace Interface
    C405TRCCYCLE               : out std_logic;
    C405TRCEVENEXECUTIONSTATUS : out std_logic_vector(0 to 1);
    C405TRCODDEXECUTIONSTATUS  : out std_logic_vector(0 to 1);
    C405TRCTRACESTATUS         : out std_logic_vector(0 to 3);
    C405TRCTRIGGEREVENTOUT     : out std_logic;
    C405TRCTRIGGEREVENTTYPE    : out std_logic_vector(0 to 10);
    TRCC405TRACEDISABLE        : in  std_logic;
    TRCC405TRIGGEREVENTIN      : in  std_logic
    );
end ppc405_top;

architecture structure of ppc405_top is

  component PPC405
    port (
      -- Clock and Power Management Interface / CPU Control Interface
      C405CPMCORESLEEPREQ      : out std_logic;
      C405CPMMSRCE             : out std_logic;
      C405CPMMSREE             : out std_logic;
      C405CPMTIMERIRQ          : out std_logic;
      C405CPMTIMERRESETREQ     : out std_logic;
      C405XXXMACHINECHECK      : out std_logic;
      CPMC405CLOCK             : in  std_logic;
      CPMC405CORECLKINACTIVE   : in  std_logic;
      CPMC405CPUCLKEN          : in  std_logic;
      CPMC405JTAGCLKEN         : in  std_logic;
      CPMC405TIMERCLKEN        : in  std_logic;
      CPMC405TIMERTICK         : in  std_logic;
      MCBCPUCLKEN              : in  std_logic;
      MCBTIMEREN               : in  std_logic;
      MCPPCRST                 : in  std_logic;
      PLBCLK                   : in  std_logic;
      TIEC405DETERMINISTICMULT : in  std_logic;
      TIEC405DISOPERANDFWD     : in  std_logic;
      TIEC405MMUEN             : in  std_logic;

      -- Reset Interface
      C405RSTCHIPRESETREQ : out std_logic;
      C405RSTCORERESETREQ : out std_logic;
      C405RSTSYSRESETREQ  : out std_logic;
      RSTC405RESETCHIP    : in  std_logic;
      RSTC405RESETCORE    : in  std_logic;
      RSTC405RESETSYS     : in  std_logic;

      -- Data Cache Unit PLB Interface
      C405PLBDCUABORT     : out std_logic;
      C405PLBDCUABUS      : out std_logic_vector(0 to 31);
      C405PLBDCUBE        : out std_logic_vector(0 to 7);
      C405PLBDCUCACHEABLE : out std_logic;
      C405PLBDCUGUARDED   : out std_logic;
      C405PLBDCUPRIORITY  : out std_logic_vector(0 to 1);
      C405PLBDCUREQUEST   : out std_logic;
      C405PLBDCURNW       : out std_logic;
      C405PLBDCUSIZE2     : out std_logic;
      C405PLBDCUU0ATTR    : out std_logic;
      C405PLBDCUWRDBUS    : out std_logic_vector(0 to 63);
      C405PLBDCUWRITETHRU : out std_logic;
      PLBC405DCUADDRACK   : in  std_logic;
      PLBC405DCUBUSY      : in  std_logic;
      PLBC405DCUERR       : in  std_logic;
      PLBC405DCURDDACK    : in  std_logic;
      PLBC405DCURDDBUS    : in  std_logic_vector(0 to 63);
      PLBC405DCURDWDADDR  : in  std_logic_vector(1 to 3);
      PLBC405DCUSSIZE1    : in  std_logic;
      PLBC405DCUWRDACK    : in  std_logic;

      -- Instruction Cache Unit PLB Interface
      C405PLBICUABORT     : out std_logic;
      C405PLBICUABUS      : out std_logic_vector(0 to 29);
      C405PLBICUCACHEABLE : out std_logic;
      C405PLBICUPRIORITY  : out std_logic_vector(0 to 1);
      C405PLBICUREQUEST   : out std_logic;
      C405PLBICUSIZE      : out std_logic_vector(2 to 3);
      C405PLBICUU0ATTR    : out std_logic;
      PLBC405ICUADDRACK   : in  std_logic;
      PLBC405ICUBUSY      : in  std_logic;
      PLBC405ICUERR       : in  std_logic;
      PLBC405ICURDDACK    : in  std_logic;
      PLBC405ICURDDBUS    : in  std_logic_vector(0 to 63);
      PLBC405ICURDWDADDR  : in  std_logic_vector(1 to 3);
      PLBC405ICUSSIZE1    : in  std_logic;

      -- Data Side XpressRAM Interface
      BRAMDSOCMCLK       : in  std_logic;
      BRAMDSOCMRDDBUS    : in  std_logic_vector(0 to 31);
      DSARCVALUE         : in  std_logic_vector(0 to 7);
      DSCNTLVALUE        : in  std_logic_vector(0 to 7);
      DSOCMBRAMABUS      : out std_logic_vector(8 to 29);
      DSOCMBRAMBYTEWRITE : out std_logic_vector(0 to 3);
      DSOCMBRAMEN        : out std_logic;
      DSOCMBRAMWRDBUS    : out std_logic_vector(0 to 31);
      DSOCMBUSY          : out std_logic;
      TIEDSOCMDCRADDR    : in  std_logic_vector(0 to 7);

      -- Instruction Side XpressRAM Interface
      BRAMISOCMCLK         : in  std_logic;
      BRAMISOCMRDDBUS      : in  std_logic_vector(0 to 63);
      ISARCVALUE           : in  std_logic_vector(0 to 7);
      ISCNTLVALUE          : in  std_logic_vector(0 to 7);
      ISOCMBRAMEN          : out std_logic;
      ISOCMBRAMEVENWRITEEN : out std_logic;
      ISOCMBRAMODDWRITEEN  : out std_logic;
      ISOCMBRAMRDABUS      : out std_logic_vector(8 to 28);
      ISOCMBRAMWRABUS      : out std_logic_vector(8 to 28);
      ISOCMBRAMWRDBUS      : out std_logic_vector(0 to 31);
      TIEISOCMDCRADDR      : in  std_logic_vector(0 to 7);

      -- Device Control Register (DCR) Interface
      C405DCRABUS    : out std_logic_vector(0 to 9);
      C405DCRDBUSOUT : out std_logic_vector(0 to 31);
      C405DCRREAD    : out std_logic;
      C405DCRWRITE   : out std_logic;
      DCRC405ACK     : in  std_logic;
      DCRC405DBUSIN  : in  std_logic_vector(0 to 31);

      -- Interrupt Controller Interface
      EICC405CRITINPUTIRQ : in std_logic;
      EICC405EXTINPUTIRQ  : in std_logic;

      -- JTAG Interface
      C405JTGCAPTUREDR  : out std_logic;
      C405JTGEXTEST     : out std_logic;
      C405JTGPGMOUT     : out std_logic;
      C405JTGSHIFTDR    : out std_logic;
      C405JTGTDO        : out std_logic;
      C405JTGTDOEN      : out std_logic;
      C405JTGUPDATEDR   : out std_logic;
      MCBJTAGEN         : in  std_logic;
      JTGC405BNDSCANTDO : in  std_logic;
      JTGC405TCK        : in  std_logic;
      JTGC405TDI        : in  std_logic;
      JTGC405TMS        : in  std_logic;
      JTGC405TRSTNEG    : in  std_logic;

      -- Debug Interface
      C405DBGMSRWE            : out std_logic;
      C405DBGSTOPACK          : out std_logic;
      C405DBGWBCOMPLETE       : out std_logic;
      C405DBGWBFULL           : out std_logic;
      C405DBGWBIAR            : out std_logic_vector(0 to 29);
      DBGC405DEBUGHALT        : in  std_logic;
      DBGC405EXTBUSHOLDACK    : in  std_logic;
      DBGC405UNCONDDEBUGEVENT : in  std_logic;

      -- Trace Interface
      C405TRCCYCLE               : out std_logic;
      C405TRCEVENEXECUTIONSTATUS : out std_logic_vector(0 to 1);
      C405TRCODDEXECUTIONSTATUS  : out std_logic_vector(0 to 1);
      C405TRCTRACESTATUS         : out std_logic_vector(0 to 3);
      C405TRCTRIGGEREVENTOUT     : out std_logic;
      C405TRCTRIGGEREVENTTYPE    : out std_logic_vector(0 to 10);
      TRCC405TRACEDISABLE        : in  std_logic;
      TRCC405TRIGGEREVENTIN      : in  std_logic
      );
  end component;

----------------------------------------------------------------------------
-- Signal Declarations
----------------------------------------------------------------------------
  signal ICU_PLB_ABus    : std_logic_vector(0 to 29);
  signal ICU_PLB_SIZE    : std_logic_vector(2 to 3);
  signal ICU_PLB_MRdDBus : std_logic_vector(1 to 3);
  signal ICU_PLB_MSSize  : std_logic;

  signal DCU_PLB_SIZE2   : std_logic;
  signal DCU_PLB_MRdDBus : std_logic_vector(1 to 3);
  signal DCU_PLB_MSSize  : std_logic;

  signal net_gnd0  : std_logic;
  signal net_gnd3  : std_logic_vector(0 to 2);
  signal net_gnd64 : std_logic_vector(0 to 63);

  signal net_vcc0 : std_logic;
  signal net_vcc8 : std_logic_vector(0 to 7);

  signal DETERMINISTIC_MULT         : std_logic;
  signal DISABLE_OPERAND_FORWARDING : std_logic;
  signal MMU_ENABLE                 : std_logic;

  -- Resynchronisation signals for DCR interface
  signal DCRC405ACK_D     : std_logic;                  -- delayed 1 DCRCLK
  signal C405DCRWRITE_E   : std_logic;                  -- early 1 DCRCLK
  signal C405DCRREAD_E    : std_logic;                  -- early 1 DCRCLK
  signal DCRC405DBUSIN_D    : std_logic_vector(0 to 31);  -- delayed 1 DCRCLK
  signal C405DCRABUS_E    : std_logic_vector(0 to 9);  -- early 1 DCRCLK
  signal C405DCRDBUSOUT_E : std_logic_vector(0 to 31);  -- early 1 DCRCLK

begin

--------------------------------------------------------------------------------
-- Power assignments
  net_gnd0          <= '0';
  net_gnd3          <= "000";
  net_gnd64         <= "0000000000000000000000000000000000000000000000000000000000000000";
  net_vcc0          <= '1';
  net_vcc8          <= "11111111";
--------------------------------------------------------------------------------
-- Top-level port ICU assignments
  C405PLBICUABUS    <= ICU_PLB_ABus & "00";
  C405PLBICUBE      <= net_vcc8;
  C405PLBICURNW     <= net_vcc0;
  C405PLBICUBUSLOCK <= net_gnd0;
  C405PLBICUGUARDED <= net_gnd0;
  C405PLBICULOCKERR <= net_gnd0;
  C405PLBICUMSIZE   <= "01";
  C405PLBICUORDERED <= net_gnd0;
  C405PLBICURDBURST <= net_gnd0;
  C405PLBICUSIZE    <= "00" & ICU_PLB_SIZE;
  C405PLBICUTYPE    <= net_gnd3;
  C405PLBICUWRBURST <= net_gnd0;
  C405PLBICUWRDBUS  <= net_gnd64;

  ICU_PLB_MRdDBus <= PLBC405ICURDWDADDR(1 to 3);
  ICU_PLB_MSSize  <= PLBC405ICUSSIZE(1);

-- Top-level port DCU assignments
  C405PLBDCUBUSLOCK <= net_gnd0;
  C405PLBDCULOCKERR <= net_vcc0;
  C405PLBDCUMSIZE   <= "01";
  C405PLBDCUORDERED <= net_gnd0;
  C405PLBDCURDBURST <= net_gnd0;
  C405PLBDCUSIZE    <= "00" & DCU_PLB_SIZE2 & '0';
  C405PLBDCUTYPE    <= net_gnd3;
  C405PLBDCUWRBURST <= net_gnd0;

  DCU_PLB_MRdDBus <= PLBC405DCURDWDADDR(1 to 3);
  DCU_PLB_MSSize  <= PLBC405DCUSSIZE(1);

  DETERMINISTIC_MULT         <= '0' when C_DETERMINISTIC_MULT = 0         else '1';
  DISABLE_OPERAND_FORWARDING <= '0' when C_DISABLE_OPERAND_FORWARDING = 0 else '1';
  MMU_ENABLE                 <= '0' when C_MMU_ENABLE = 0                 else '1';

--------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- DCR pipeline registers for DCR interface timing. 
-------------------------------------------------------------------------------

  Full_DCR_Resync   : if (C_DCR_RESYNC = 2) generate begin
    FD_I_ACK       : FD port map (Q => DCRC405ACK_D, C => DCRCLK, D => DCRC405ACK);
    FD_I_READ      : FD port map (Q => C405DCRREAD, C => DCRCLK, D => C405DCRREAD_E);
    FD_I_WRITE     : FD port map (Q => C405DCRWRITE, C => DCRCLK, D => C405DCRWRITE_E);

    DCRDBUS_Resync  : for i in 0 to 31 generate begin
      FD_I_DBUSOUT : FD port map (Q => C405DCRDBUSOUT(i), C => DCRCLK, D => C405DCRDBUSOUT_E(i));
      FD_I_DBUSIN  : FD port map (Q => DCRC405DBUSIN_D(i), C => DCRCLK, D => DCRC405DBUSIN(i));
    end generate DCRDBUS_Resync;

    DCRABUS_Resync   : for i in 0 to 9 generate begin
      FD_I_ABUS    : FD port map (Q => C405DCRABUS(i), C => DCRCLK, D => C405DCRABUS_E(i));
    end generate DCRABUS_Resync;
  end generate Full_DCR_Resync;

  Ctrl_DCR_Resync : if (C_DCR_RESYNC = 1) generate begin
    FD_I_ACK     : FD port map (Q => DCRC405ACK_D, C => DCRCLK, D => DCRC405ACK);
    FD_I_READ    : FD port map (Q => C405DCRREAD, C => DCRCLK, D => C405DCRREAD_E);
    FD_I_WRITE   : FD port map (Q => C405DCRWRITE, C => DCRCLK, D => C405DCRWRITE_E);

    C405DCRABUS     <= C405DCRABUS_E;     -- not resynchronized
    C405DCRDBUSOUT  <= C405DCRDBUSOUT_E;  -- not resynchronized
    DCRC405DBUSIN_D <= DCRC405DBUSIN;       -- not resynchronized
  end generate Ctrl_DCR_Resync;

  No_DCR_Resync : if (C_DCR_RESYNC = 0) generate begin
    C405DCRREAD     <= C405DCRREAD_E;     -- not resynchronized
    C405DCRWRITE    <= C405DCRWRITE_E;    -- not resynchronized
    DCRC405ACK_D    <= DCRC405ACK;        -- not resynchronized
    C405DCRABUS     <= C405DCRABUS_E;     -- not resynchronized
    C405DCRDBUSOUT  <= C405DCRDBUSOUT_E;  -- not resynchronized
    DCRC405DBUSIN_D <= DCRC405DBUSIN;       -- not resynchronized
  end generate No_DCR_Resync;

----------------------------------------------------------------------------
-- Instantiate PPC405 Processor Block Module
----------------------------------------------------------------------------
  PPC405_i : PPC405 port map (
    -- Clock and Power Management Interface / CPU Control Interface
    C405CPMCORESLEEPREQ        => C405CPMCORESLEEPREQ,           -- O
    C405CPMMSRCE               => C405CPMMSRCE,                  -- O 
    C405CPMMSREE               => C405CPMMSREE,                  -- O 
    C405CPMTIMERIRQ            => C405CPMTIMERIRQ,               -- O 
    C405CPMTIMERRESETREQ       => C405CPMTIMERRESETREQ,          -- O 
    C405XXXMACHINECHECK        => C405XXXMACHINECHECK,           -- O
    CPMC405CLOCK               => CPMC405CLOCK,                  -- I 
    CPMC405CORECLKINACTIVE     => CPMC405CORECLKINACTIVE,        -- I 
    CPMC405CPUCLKEN            => CPMC405CPUCLKEN,               -- I 
    CPMC405JTAGCLKEN           => CPMC405JTAGCLKEN,              -- I 
    CPMC405TIMERCLKEN          => CPMC405TIMERCLKEN,             -- I 
    CPMC405TIMERTICK           => CPMC405TIMERTICK,              -- I
    MCBCPUCLKEN                => MCBCPUCLKEN,                   -- I 
    MCBTIMEREN                 => MCBTIMEREN,                    -- I 
    MCPPCRST                   => MCPPCRST,                      -- I 
    PLBCLK                     => PLBCLK,                        -- I 
    TIEC405DETERMINISTICMULT   => DETERMINISTIC_MULT,            -- I
    TIEC405DISOPERANDFWD       => DISABLE_OPERAND_FORWARDING,    -- I
    TIEC405MMUEN               => MMU_ENABLE,                    -- I 
    -- Reset Interface
    C405RSTCHIPRESETREQ        => C405RSTCHIPRESETREQ,           -- O
    C405RSTCORERESETREQ        => C405RSTCORERESETREQ,           -- O
    C405RSTSYSRESETREQ         => C405RSTSYSRESETREQ,            -- O
    RSTC405RESETCHIP           => RSTC405RESETCHIP,              -- I
    RSTC405RESETCORE           => RSTC405RESETCORE,              -- I
    RSTC405RESETSYS            => RSTC405RESETSYS,               -- I
    -- Data Cache Unit PLB Interface
    C405PLBDCUABORT            => C405PLBDCUABORT,               -- O
    C405PLBDCUABUS             => C405PLBDCUABUS,                -- O [0:31]
    C405PLBDCUBE               => C405PLBDCUBE,                  -- O [0:7]
    C405PLBDCUCACHEABLE        => C405PLBDCUCACHEABLE,           -- O
    C405PLBDCUGUARDED          => C405PLBDCUGUARDED,             -- O
    C405PLBDCUPRIORITY         => C405PLBDCUPRIORITY,            -- O [0:1]
    C405PLBDCUREQUEST          => C405PLBDCUREQUEST,             -- O
    C405PLBDCURNW              => C405PLBDCURNW,                 -- O
    C405PLBDCUSIZE2            => DCU_PLB_SIZE2,                 -- O
    C405PLBDCUU0ATTR           => C405PLBDCUU0ATTR,              -- O
    C405PLBDCUWRDBUS           => C405PLBDCUWRDBUS,              -- O [0:63]
    C405PLBDCUWRITETHRU        => C405PLBDCUWRITETHRU,           -- O
    PLBC405DCUADDRACK          => PLBC405DCUADDRACK,             -- I
    PLBC405DCUBUSY             => PLBC405DCUBUSY,                -- I
    PLBC405DCUERR              => PLBC405DCUERR,                 -- I
    PLBC405DCURDDACK           => PLBC405DCURDDACK,              -- I
    PLBC405DCURDDBUS           => PLBC405DCURDDBUS,              -- I [0:63]
    PLBC405DCURDWDADDR         => DCU_PLB_MRdDBus,               -- I [1:3]
    PLBC405DCUSSIZE1           => DCU_PLB_MSSize,                -- I
    PLBC405DCUWRDACK           => PLBC405DCUWRDACK,              -- I
    -- Instruction Cache Unit PLB Interface
    C405PLBICUABORT            => C405PLBICUABORT,               -- O 
    C405PLBICUABUS             => ICU_PLB_ABus,                  -- O [0:29]
    C405PLBICUCACHEABLE        => C405PLBICUCACHEABLE,           -- O
    C405PLBICUPRIORITY         => C405PLBICUPRIORITY,            -- O [0:1]
    C405PLBICUREQUEST          => C405PLBICUREQUEST,             -- O
    C405PLBICUSIZE             => ICU_PLB_SIZE,                  -- O [2:3]
    C405PLBICUU0ATTR           => C405PLBICUU0ATTR,              -- O 
    PLBC405ICUADDRACK          => PLBC405ICUADDRACK,             -- I 
    PLBC405ICUBUSY             => PLBC405ICUBUSY,                -- I 
    PLBC405ICUERR              => PLBC405ICUERR,                 -- I 
    PLBC405ICURDDACK           => PLBC405ICURDDACK,              -- I 
    PLBC405ICURDDBUS           => PLBC405ICURDDBUS,              -- I [0:63]
    PLBC405ICURDWDADDR         => ICU_PLB_MRdDBus,               -- I [1:3]
    PLBC405ICUSSIZE1           => ICU_PLB_MSSize,                -- I 
    -- Data Side XpressRAM Interface
    BRAMDSOCMCLK               => BRAMDSOCMCLK,                  -- I
    BRAMDSOCMRDDBUS            => BRAMDSOCMRDDBUS,               -- I [0:31]
    DSARCVALUE                 => DSARCVALUE,                    -- I [0:7]
    DSCNTLVALUE                => DSCNTLVALUE,                   -- I [0:7]
    DSOCMBRAMABUS              => DSOCMBRAMABUS,                 -- O [8:29]
    DSOCMBRAMBYTEWRITE         => DSOCMBRAMBYTEWRITE,            -- O [0:3]
    DSOCMBRAMEN                => DSOCMBRAMEN,                   -- O
    DSOCMBRAMWRDBUS            => DSOCMBRAMWRDBUS,               -- O [0:31]
    DSOCMBUSY                  => DSOCMBUSY,                     -- O
    TIEDSOCMDCRADDR            => C_DSOCM_DCR_BASEADDR(0 to 7),  -- I [0:7]
    -- Instruction Side XpressRAM Interface
    BRAMISOCMCLK               => BRAMISOCMCLK,                  -- I
    BRAMISOCMRDDBUS            => BRAMISOCMRDDBUS,               -- I [0:63]
    ISARCVALUE                 => ISARCVALUE,                    -- I [0:7]
    ISCNTLVALUE                => ISCNTLVALUE,                   -- I [0:7]
    ISOCMBRAMEN                => ISOCMBRAMEN,                   -- O
    ISOCMBRAMEVENWRITEEN       => ISOCMBRAMEVENWRITEEN,          -- O
    ISOCMBRAMODDWRITEEN        => ISOCMBRAMODDWRITEEN,           -- O
    ISOCMBRAMRDABUS            => ISOCMBRAMRDABUS,               -- O [0:28]
    ISOCMBRAMWRABUS            => ISOCMBRAMWRABUS,               -- O [8:28]
    ISOCMBRAMWRDBUS            => ISOCMBRAMWRDBUS,               -- O [0:31]
    TIEISOCMDCRADDR            => C_ISOCM_DCR_BASEADDR(0 to 7),  -- I [0:7]
    -- Device Control Register (DCR) Interface
    C405DCRABUS                => C405DCRABUS_E,                 -- O [0:9]
    C405DCRDBUSOUT             => C405DCRDBUSOUT_E,              -- O [0:31]
    C405DCRREAD                => C405DCRREAD_E,                 -- O
    C405DCRWRITE               => C405DCRWRITE_E,                -- O
    DCRC405ACK                 => DCRC405ACK_D,                  -- I
    DCRC405DBUSIN              => DCRC405DBUSIN_D,               -- I [0:31]
    -- Interrupt Controller Interface
    EICC405CRITINPUTIRQ        => EICC405CRITINPUTIRQ,           -- I
    EICC405EXTINPUTIRQ         => EICC405EXTINPUTIRQ,            -- I
    -- JTAG Interface
    C405JTGCAPTUREDR           => C405JTGCAPTUREDR,              -- O
    C405JTGEXTEST              => C405JTGEXTEST,                 -- O
    C405JTGPGMOUT              => C405JTGPGMOUT,                 -- O
    C405JTGSHIFTDR             => C405JTGSHIFTDR,                -- O
    C405JTGTDO                 => C405JTGTDO,                    -- O
    C405JTGTDOEN               => C405JTGTDOEN,                  -- O
    C405JTGUPDATEDR            => C405JTGUPDATEDR,               -- O
    MCBJTAGEN                  => MCBJTAGEN,                     -- I 
    JTGC405BNDSCANTDO          => JTGC405BNDSCANTDO,             -- I
    JTGC405TCK                 => JTGC405TCK,                    -- I
    JTGC405TDI                 => JTGC405TDI,                    -- I
    JTGC405TMS                 => JTGC405TMS,                    -- I
    JTGC405TRSTNEG             => JTGC405TRSTNEG,                -- I
    -- Debug Interface
    C405DBGMSRWE               => C405DBGMSRWE,                  -- O 
    C405DBGSTOPACK             => C405DBGSTOPACK,                -- O 
    C405DBGWBCOMPLETE          => C405DBGWBCOMPLETE,             -- O
    C405DBGWBFULL              => C405DBGWBFULL,                 -- O
    C405DBGWBIAR               => C405DBGWBIAR,                  -- O [0:29]
    DBGC405DEBUGHALT           => DBGC405DEBUGHALT,              -- I
    DBGC405EXTBUSHOLDACK       => DBGC405EXTBUSHOLDACK,          -- I
    DBGC405UNCONDDEBUGEVENT    => DBGC405UNCONDDEBUGEVENT,       -- I
    -- Trace Interface
    C405TRCCYCLE               => C405TRCCYCLE,                  -- O
    C405TRCEVENEXECUTIONSTATUS => C405TRCEVENEXECUTIONSTATUS,    -- O [0:1]
    C405TRCODDEXECUTIONSTATUS  => C405TRCODDEXECUTIONSTATUS,     -- O [0:1]
    C405TRCTRACESTATUS         => C405TRCTRACESTATUS,            -- O [0:3]
    C405TRCTRIGGEREVENTOUT     => C405TRCTRIGGEREVENTOUT,        -- O
    C405TRCTRIGGEREVENTTYPE    => C405TRCTRIGGEREVENTTYPE,       -- O [0:10]
    TRCC405TRACEDISABLE        => TRCC405TRACEDISABLE,           -- I
    TRCC405TRIGGEREVENTIN      => TRCC405TRIGGEREVENTIN          -- I
    );

end structure;
