--------------------------------------------------------------------------
-- $Id: ppc405_virtex4.vhd,v 1.3 2005/11/30 00:42:44 jeffs Exp $
--------------------------------------------------------------------------------- ppc405_virtex4.vhd - entity/architecture
-------------------------------------------------------------------------------
-- ** Copyright(C) 2004 by Xilinx, Inc. All rights reserved.
-- **
-- ** This text contains proprietary, confidential information of
-- ** Xilinx, Inc. , is distributed by under license from Xilinx, Inc.,
-- ** and may be used, copied and/or disclosed only pursuant to the
-- ** terms of a valid license agreement with Xilinx, Inc.
-- **
-- ** Unmodified source code is guaranteed to place and route,
-- ** function and run at speed according to the datasheet
-- ** specification. Source code is provided "as-is", with no
-- ** obligation on the part of Xilinx to provide support.
-- **
-- ** Xilinx Hotline support of source code IP shall only include
-- ** standard level Xilinx Hotline support, and will only address
-- ** issues and questions related to the standard released Netlist
-- ** version of the core (and thus indirectly, the original core source
-- **
-- ** The Xilinx Support Hotline does not have access to source
-- ** code and therefore cannot answer specific questions related
-- ** to source HDL. The Xilinx Support Hotline will only be able
-- ** to confirm the problem in the Netlist version of the core.
-- **
-- ** This copyright and support notice must be retained as part
-- ** of this text at all times.
------------------------------------------------------------------------------
-- Filename:       ppc405_virtex4.vhd
-- Version:        v1.00a
-- Description:    PowerPC405 wrapper for EDK (only for Virtex4)
-------------------------------------------------------------------------------
-- Structure:
-------------------------------------------------------------------------------
-- Author:      lg
-- History:
--      lg      05/25/04        - First version       
-------------------------------------------------------------------------------
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

entity ppc405_virtex4 is
  generic (
    -- for DCR address overlap checking
    C_IDCR_BASEADDR              : std_logic_vector(0 to 9)  := "0100000000";
    C_IDCR_HIGHADDR              : std_logic_vector(0 to 9)  := "0100001111";
    C_DISABLE_OPERAND_FORWARDING : integer                   := 1;
    C_MMU_ENABLE                 : integer                   := 1;
    C_DETERMINISTIC_MULT         : integer                   := 0;
    C_PLBSYNCBYPASS              : integer                   := 1;
    C_APU_CONTROL                : std_logic_vector(0 to 15) := X"DE00";
    C_APU_UDI_1                  : std_logic_vector(0 to 23) := X"A18981";  -- FSL get
    C_APU_UDI_2                  : std_logic_vector(0 to 23) := X"A38981";  -- FSL cget
    C_APU_UDI_3                  : std_logic_vector(0 to 23) := X"A589C1";  -- FSL nget
    C_APU_UDI_4                  : std_logic_vector(0 to 23) := X"A789C1";  -- FSL ncget
    C_APU_UDI_5                  : std_logic_vector(0 to 23) := X"A98C01";  -- FSL put
    C_APU_UDI_6                  : std_logic_vector(0 to 23) := X"AB8C01";  -- FSL cput
    C_APU_UDI_7                  : std_logic_vector(0 to 23) := X"AD8C41";  -- FSL nput
    C_APU_UDI_8                  : std_logic_vector(0 to 23) := X"AF8C41";  -- FSL ncput
    C_PVR_HIGH                   : std_logic_vector(0 to 3) := "0000";
    C_PVR_LOW                    : std_logic_vector(0 to 3) := "0000"
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
    CPMDCRCLK              : in  std_logic;
    CPMFCMCLK              : in  std_logic;

    -- Reset Interface
    C405RSTCHIPRESETREQ : out std_logic;
    C405RSTCORERESETREQ : out std_logic;
    C405RSTSYSRESETREQ  : out std_logic;
    RSTC405RESETCHIP    : in  std_logic;
    RSTC405RESETCORE    : in  std_logic;
    RSTC405RESETSYS     : in  std_logic;

    -- APU Interface
    APUFCMDECODED            : out std_logic;
    APUFCMDECUDI             : out std_logic_vector(0 to 2);
    APUFCMDECUDIVALID        : out std_logic;
    APUFCMENDIAN             : out std_logic;
    APUFCMFLUSH              : out std_logic;
    APUFCMINSTRUCTION        : out std_logic_vector(0 to 31);
    APUFCMINSTRVALID         : out std_logic;
    APUFCMLOADBYTEEN         : out std_logic_vector(0 to 3);
    APUFCMLOADDATA           : out std_logic_vector(0 to 31);
    APUFCMLOADDVALID         : out std_logic;
    APUFCMOPERANDVALID       : out std_logic;
    APUFCMRADATA             : out std_logic_vector(0 to 31);
    APUFCMRBDATA             : out std_logic_vector(0 to 31);
    APUFCMWRITEBACKOK        : out std_logic;
    APUFCMXERCA              : out std_logic;
    FCMAPUCR                 : in  std_logic_vector(0 to 3);
    FCMAPUDCDCREN            : in  std_logic;
    FCMAPUDCDFORCEALIGN      : in  std_logic;
    FCMAPUDCDFORCEBESTEERING : in  std_logic;
    FCMAPUDCDFPUOP           : in  std_logic;
    FCMAPUDCDGPRWRITE        : in  std_logic;
    FCMAPUDCDLDSTBYTE        : in  std_logic;
    FCMAPUDCDLDSTDW          : in  std_logic;
    FCMAPUDCDLDSTHW          : in  std_logic;
    FCMAPUDCDLDSTQW          : in  std_logic;
    FCMAPUDCDLDSTWD          : in  std_logic;
    FCMAPUDCDLOAD            : in  std_logic;
    FCMAPUDCDPRIVOP          : in  std_logic;
    FCMAPUDCDRAEN            : in  std_logic;
    FCMAPUDCDRBEN            : in  std_logic;
    FCMAPUDCDSTORE           : in  std_logic;
    FCMAPUDCDTRAPBE          : in  std_logic;
    FCMAPUDCDTRAPLE          : in  std_logic;
    FCMAPUDCDUPDATE          : in  std_logic;
    FCMAPUDCDXERCAEN         : in  std_logic;
    FCMAPUDCDXEROVEN         : in  std_logic;
    FCMAPUDECODEBUSY         : in  std_logic;
    FCMAPUDONE               : in  std_logic;
    FCMAPUEXCEPTION          : in  std_logic;
    FCMAPUEXEBLOCKINGMCO     : in  std_logic;
    FCMAPUEXECRFIELD         : in  std_logic_vector(0 to 2);
    FCMAPUEXENONBLOCKINGMCO  : in  std_logic;
    FCMAPUINSTRACK           : in  std_logic;
    FCMAPULOADWAIT           : in  std_logic;
    FCMAPURESULT             : in  std_logic_vector(0 to 31);
    FCMAPURESULTVALID        : in  std_logic;
    FCMAPUSLEEPNOTREADY      : in  std_logic;
    FCMAPUXERCA              : in  std_logic;
    FCMAPUXEROV              : in  std_logic;

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
    DSOCMRDADDRVALID   : out std_logic;
    DSOCMWRADDRVALID   : out std_logic;
    DSOCMRWCOMPLETE    : in  std_logic;

    -- Instruction Side XpressRAM Interface
    BRAMISOCMCLK         : in  std_logic;
    BRAMISOCMRDDBUS      : in  std_logic_vector(0 to 63);
    BRAMISOCMDCRRDDBUS   : in  std_logic_vector(0 to 31);
    ISARCVALUE           : in  std_logic_vector(0 to 7);
    ISCNTLVALUE          : in  std_logic_vector(0 to 7);
    ISOCMBRAMEN          : out std_logic;
    ISOCMBRAMEVENWRITEEN : out std_logic;
    ISOCMBRAMODDWRITEEN  : out std_logic;
    ISOCMBRAMRDABUS      : out std_logic_vector(8 to 28);
    ISOCMBRAMWRABUS      : out std_logic_vector(8 to 28);
    ISOCMBRAMWRDBUS      : out std_logic_vector(0 to 31);
    ISOCMDCRBRAMEVENEN   : out std_logic;
    ISOCMDCRBRAMODDEN    : out std_logic;
    ISOCMDCRBRAMRDSELECT : out std_logic;

    -- EMAC Interface
    DCREMACABUS                : out std_logic_vector(8 to 9);
    DCREMACCLK                 : out std_ulogic;
    DCREMACDBUS                : out std_logic_vector(0 to 31);
    DCREMACENABLER             : out std_ulogic;
    DCREMACREAD                : out std_ulogic;
    DCREMACWRITE               : out std_ulogic;
    EMACDCRACK                 : in  std_ulogic;
    EMACDCRDBUS                : in  std_logic_vector(0 to 31);

    -- Device Control Register (DCR) Interface
    -- Maintains name standard from V2P.
    EXTDCRABUS                 : out std_logic_vector(0 to 9);
    EXTDCRDBUSOUT              : out std_logic_vector(0 to 31);
    EXTDCRREAD                 : out std_ulogic;
    EXTDCRWRITE                : out std_ulogic;
    EXTDCRACK                  : in  std_ulogic;
    EXTDCRDBUSIN               : in  std_logic_vector(0 to 31);

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
    C405DBGMSRWE             : out std_logic;
    C405DBGSTOPACK           : out std_logic;
    C405DBGWBCOMPLETE        : out std_logic;
    C405DBGWBFULL            : out std_logic;
    C405DBGWBIAR             : out std_logic_vector(0 to 29);
    DBGC405DEBUGHALT         : in  std_logic;
    DBGC405EXTBUSHOLDACK     : in  std_logic;
    DBGC405UNCONDDEBUGEVENT  : in  std_logic;
    C405DBGLOADDATAONAPUDBUS : out std_logic;

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
end ppc405_virtex4;

architecture structure of ppc405_virtex4 is

  component PPC405_ADV
    port (
      APUFCMDECODED              : out std_ulogic;
      APUFCMDECUDI               : out std_logic_vector(0 to 2);
      APUFCMDECUDIVALID          : out std_ulogic;
      APUFCMENDIAN               : out std_ulogic;
      APUFCMFLUSH                : out std_ulogic;
      APUFCMINSTRUCTION          : out std_logic_vector(0 to 31);
      APUFCMINSTRVALID           : out std_ulogic;
      APUFCMLOADBYTEEN           : out std_logic_vector(0 to 3);
      APUFCMLOADDATA             : out std_logic_vector(0 to 31);
      APUFCMLOADDVALID           : out std_ulogic;
      APUFCMOPERANDVALID         : out std_ulogic;
      APUFCMRADATA               : out std_logic_vector(0 to 31);
      APUFCMRBDATA               : out std_logic_vector(0 to 31);
      APUFCMWRITEBACKOK          : out std_ulogic;
      APUFCMXERCA                : out std_ulogic;
      C405CPMCORESLEEPREQ        : out std_ulogic;
      C405CPMMSRCE               : out std_ulogic;
      C405CPMMSREE               : out std_ulogic;
      C405CPMTIMERIRQ            : out std_ulogic;
      C405CPMTIMERRESETREQ       : out std_ulogic;
      C405DBGLOADDATAONAPUDBUS   : out std_ulogic;
      C405DBGMSRWE               : out std_ulogic;
      C405DBGSTOPACK             : out std_ulogic;
      C405DBGWBCOMPLETE          : out std_ulogic;
      C405DBGWBFULL              : out std_ulogic;
      C405DBGWBIAR               : out std_logic_vector(0 to 29);
      C405JTGCAPTUREDR           : out std_ulogic;
      C405JTGEXTEST              : out std_ulogic;
      C405JTGPGMOUT              : out std_ulogic;
      C405JTGSHIFTDR             : out std_ulogic;
      C405JTGTDO                 : out std_ulogic;
      C405JTGTDOEN               : out std_ulogic;
      C405JTGUPDATEDR            : out std_ulogic;
      C405PLBDCUABORT            : out std_ulogic;
      C405PLBDCUABUS             : out std_logic_vector(0 to 31);
      C405PLBDCUBE               : out std_logic_vector(0 to 7);
      C405PLBDCUCACHEABLE        : out std_ulogic;
      C405PLBDCUGUARDED          : out std_ulogic;
      C405PLBDCUPRIORITY         : out std_logic_vector(0 to 1);
      C405PLBDCUREQUEST          : out std_ulogic;
      C405PLBDCURNW              : out std_ulogic;
      C405PLBDCUSIZE2            : out std_ulogic;
      C405PLBDCUU0ATTR           : out std_ulogic;
      C405PLBDCUWRDBUS           : out std_logic_vector(0 to 63);
      C405PLBDCUWRITETHRU        : out std_ulogic;
      C405PLBICUABORT            : out std_ulogic;
      C405PLBICUABUS             : out std_logic_vector(0 to 29);
      C405PLBICUCACHEABLE        : out std_ulogic;
      C405PLBICUPRIORITY         : out std_logic_vector(0 to 1);
      C405PLBICUREQUEST          : out std_ulogic;
      C405PLBICUSIZE             : out std_logic_vector(2 to 3);
      C405PLBICUU0ATTR           : out std_ulogic;
      C405RSTCHIPRESETREQ        : out std_ulogic;
      C405RSTCORERESETREQ        : out std_ulogic;
      C405RSTSYSRESETREQ         : out std_ulogic;
      C405TRCCYCLE               : out std_ulogic;
      C405TRCEVENEXECUTIONSTATUS : out std_logic_vector(0 to 1);
      C405TRCODDEXECUTIONSTATUS  : out std_logic_vector(0 to 1);
      C405TRCTRACESTATUS         : out std_logic_vector(0 to 3);
      C405TRCTRIGGEREVENTOUT     : out std_ulogic;
      C405TRCTRIGGEREVENTTYPE    : out std_logic_vector(0 to 10);
      C405XXXMACHINECHECK        : out std_ulogic;
      DCREMACABUS                : out std_logic_vector(8 to 9);
      DCREMACCLK                 : out std_ulogic;
      DCREMACDBUS                : out std_logic_vector(0 to 31);
      DCREMACENABLER             : out std_ulogic;
      DCREMACREAD                : out std_ulogic;
      DCREMACWRITE               : out std_ulogic;
      DSOCMBRAMABUS              : out std_logic_vector(8 to 29);
      DSOCMBRAMBYTEWRITE         : out std_logic_vector(0 to 3);
      DSOCMBRAMEN                : out std_ulogic;
      DSOCMBRAMWRDBUS            : out std_logic_vector(0 to 31);
      DSOCMBUSY                  : out std_ulogic;
      DSOCMRDADDRVALID           : out std_ulogic;
      DSOCMWRADDRVALID           : out std_ulogic;
      EXTDCRABUS                 : out std_logic_vector(0 to 9);
      EXTDCRDBUSOUT              : out std_logic_vector(0 to 31);
      EXTDCRREAD                 : out std_ulogic;
      EXTDCRWRITE                : out std_ulogic;
      ISOCMBRAMEN                : out std_ulogic;
      ISOCMBRAMEVENWRITEEN       : out std_ulogic;
      ISOCMBRAMODDWRITEEN        : out std_ulogic;
      ISOCMBRAMRDABUS            : out std_logic_vector(8 to 28);
      ISOCMBRAMWRABUS            : out std_logic_vector(8 to 28);
      ISOCMBRAMWRDBUS            : out std_logic_vector(0 to 31);
      ISOCMDCRBRAMEVENEN         : out std_ulogic;
      ISOCMDCRBRAMODDEN          : out std_ulogic;
      ISOCMDCRBRAMRDSELECT       : out std_ulogic;
      BRAMDSOCMCLK               : in  std_ulogic;
      BRAMDSOCMRDDBUS            : in  std_logic_vector(0 to 31);
      BRAMISOCMCLK               : in  std_ulogic;
      BRAMISOCMDCRRDDBUS         : in  std_logic_vector(0 to 31);
      BRAMISOCMRDDBUS            : in  std_logic_vector(0 to 63);
      CPMC405CLOCK               : in  std_ulogic;
      CPMC405CORECLKINACTIVE     : in  std_ulogic;
      CPMC405CPUCLKEN            : in  std_ulogic;
      CPMC405JTAGCLKEN           : in  std_ulogic;
      CPMC405SYNCBYPASS          : in  std_ulogic;
      CPMC405TIMERCLKEN          : in  std_ulogic;
      CPMC405TIMERTICK           : in  std_ulogic;
      CPMDCRCLK                  : in  std_ulogic;
      CPMFCMCLK                  : in  std_ulogic;
      DBGC405DEBUGHALT           : in  std_ulogic;
      DBGC405EXTBUSHOLDACK       : in  std_ulogic;
      DBGC405UNCONDDEBUGEVENT    : in  std_ulogic;
      DSARCVALUE                 : in  std_logic_vector(0 to 7);
      DSCNTLVALUE                : in  std_logic_vector(0 to 7);
      DSOCMRWCOMPLETE            : in  std_ulogic;
      EICC405CRITINPUTIRQ        : in  std_ulogic;
      EICC405EXTINPUTIRQ         : in  std_ulogic;
      EMACDCRACK                 : in  std_ulogic;
      EMACDCRDBUS                : in  std_logic_vector(0 to 31);
      EXTDCRACK                  : in  std_ulogic;
      EXTDCRDBUSIN               : in  std_logic_vector(0 to 31);
      FCMAPUCR                   : in  std_logic_vector(0 to 3);
      FCMAPUDCDCREN              : in  std_ulogic;
      FCMAPUDCDFORCEALIGN        : in  std_ulogic;
      FCMAPUDCDFORCEBESTEERING   : in  std_ulogic;
      FCMAPUDCDFPUOP             : in  std_ulogic;
      FCMAPUDCDGPRWRITE          : in  std_ulogic;
      FCMAPUDCDLDSTBYTE          : in  std_ulogic;
      FCMAPUDCDLDSTDW            : in  std_ulogic;
      FCMAPUDCDLDSTHW            : in  std_ulogic;
      FCMAPUDCDLDSTQW            : in  std_ulogic;
      FCMAPUDCDLDSTWD            : in  std_ulogic;
      FCMAPUDCDLOAD              : in  std_ulogic;
      FCMAPUDCDPRIVOP            : in  std_ulogic;
      FCMAPUDCDRAEN              : in  std_ulogic;
      FCMAPUDCDRBEN              : in  std_ulogic;
      FCMAPUDCDSTORE             : in  std_ulogic;
      FCMAPUDCDTRAPBE            : in  std_ulogic;
      FCMAPUDCDTRAPLE            : in  std_ulogic;
      FCMAPUDCDUPDATE            : in  std_ulogic;
      FCMAPUDCDXERCAEN           : in  std_ulogic;
      FCMAPUDCDXEROVEN           : in  std_ulogic;
      FCMAPUDECODEBUSY           : in  std_ulogic;
      FCMAPUDONE                 : in  std_ulogic;
      FCMAPUEXCEPTION            : in  std_ulogic;
      FCMAPUEXEBLOCKINGMCO       : in  std_ulogic;
      FCMAPUEXECRFIELD           : in  std_logic_vector(0 to 2);
      FCMAPUEXENONBLOCKINGMCO    : in  std_ulogic;
      FCMAPUINSTRACK             : in  std_ulogic;
      FCMAPULOADWAIT             : in  std_ulogic;
      FCMAPURESULT               : in  std_logic_vector(0 to 31);
      FCMAPURESULTVALID          : in  std_ulogic;
      FCMAPUSLEEPNOTREADY        : in  std_ulogic;
      FCMAPUXERCA                : in  std_ulogic;
      FCMAPUXEROV                : in  std_ulogic;
      ISARCVALUE                 : in  std_logic_vector(0 to 7);
      ISCNTLVALUE                : in  std_logic_vector(0 to 7);
      JTGC405BNDSCANTDO          : in  std_ulogic;
      JTGC405TCK                 : in  std_ulogic;
      JTGC405TDI                 : in  std_ulogic;
      JTGC405TMS                 : in  std_ulogic;
      JTGC405TRSTNEG             : in  std_ulogic;
      MCBCPUCLKEN                : in  std_ulogic;
      MCBJTAGEN                  : in  std_ulogic;
      MCBTIMEREN                 : in  std_ulogic;
      MCPPCRST                   : in  std_ulogic;
      PLBC405DCUADDRACK          : in  std_ulogic;
      PLBC405DCUBUSY             : in  std_ulogic;
      PLBC405DCUERR              : in  std_ulogic;
      PLBC405DCURDDACK           : in  std_ulogic;
      PLBC405DCURDDBUS           : in  std_logic_vector(0 to 63);
      PLBC405DCURDWDADDR         : in  std_logic_vector(1 to 3);
      PLBC405DCUSSIZE1           : in  std_ulogic;
      PLBC405DCUWRDACK           : in  std_ulogic;
      PLBC405ICUADDRACK          : in  std_ulogic;
      PLBC405ICUBUSY             : in  std_ulogic;
      PLBC405ICUERR              : in  std_ulogic;
      PLBC405ICURDDACK           : in  std_ulogic;
      PLBC405ICURDDBUS           : in  std_logic_vector(0 to 63);
      PLBC405ICURDWDADDR         : in  std_logic_vector(1 to 3);
      PLBC405ICUSSIZE1           : in  std_ulogic;
      PLBCLK                     : in  std_ulogic;
      RSTC405RESETCHIP           : in  std_ulogic;
      RSTC405RESETCORE           : in  std_ulogic;
      RSTC405RESETSYS            : in  std_ulogic;
      TIEAPUCONTROL              : in  std_logic_vector(0 to 15);
      TIEAPUUDI1                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI2                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI3                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI4                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI5                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI6                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI7                 : in  std_logic_vector(0 to 23);
      TIEAPUUDI8                 : in  std_logic_vector(0 to 23);
      TIEC405DETERMINISTICMULT   : in  std_ulogic;
      TIEC405DISOPERANDFWD       : in  std_ulogic;
      TIEC405MMUEN               : in  std_ulogic;
      TIEDCRADDR                 : in  std_logic_vector(0 to 5);
      TIEPVRBIT10                : in  std_ulogic;
      TIEPVRBIT11                : in  std_ulogic;
      TIEPVRBIT28                : in  std_ulogic;
      TIEPVRBIT29                : in  std_ulogic;
      TIEPVRBIT30                : in  std_ulogic;
      TIEPVRBIT31                : in  std_ulogic;
      TIEPVRBIT8                 : in  std_ulogic;
      TIEPVRBIT9                 : in  std_ulogic;
      TRCC405TRACEDISABLE        : in  std_ulogic;
      TRCC405TRIGGEREVENTIN      : in  std_ulogic);
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
  signal PLBSYNCBYPASS              : std_logic;

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
  PLBSYNCBYPASS              <= '0' when C_PLBSYNCBYPASS = 0              else '1';

--------------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Instantiate PPC405 Processor Block Module
----------------------------------------------------------------------------
  PPC405_ADV_i : PPC405_ADV
    port map (
      APUFCMDECODED              => APUFCMDECODED,
      APUFCMDECUDI               => APUFCMDECUDI,
      APUFCMDECUDIVALID          => APUFCMDECUDIVALID,
      APUFCMENDIAN               => APUFCMENDIAN,
      APUFCMFLUSH                => APUFCMFLUSH,
      APUFCMINSTRUCTION          => APUFCMINSTRUCTION,
      APUFCMINSTRVALID           => APUFCMINSTRVALID,
      APUFCMLOADBYTEEN           => APUFCMLOADBYTEEN,
      APUFCMLOADDATA             => APUFCMLOADDATA,
      APUFCMLOADDVALID           => APUFCMLOADDVALID,
      APUFCMOPERANDVALID         => APUFCMOPERANDVALID,
      APUFCMRADATA               => APUFCMRADATA,
      APUFCMRBDATA               => APUFCMRBDATA,
      APUFCMWRITEBACKOK          => APUFCMWRITEBACKOK,
      APUFCMXERCA                => APUFCMXERCA,
      C405CPMCORESLEEPREQ        => C405CPMCORESLEEPREQ,
      C405CPMMSRCE               => C405CPMMSRCE,
      C405CPMMSREE               => C405CPMMSREE,
      C405CPMTIMERIRQ            => C405CPMTIMERIRQ,
      C405CPMTIMERRESETREQ       => C405CPMTIMERRESETREQ,
      C405DBGLOADDATAONAPUDBUS   => C405DBGLOADDATAONAPUDBUS,
      C405DBGMSRWE               => C405DBGMSRWE,
      C405DBGSTOPACK             => C405DBGSTOPACK,
      C405DBGWBCOMPLETE          => C405DBGWBCOMPLETE,
      C405DBGWBFULL              => C405DBGWBFULL,
      C405DBGWBIAR               => C405DBGWBIAR,
      C405JTGCAPTUREDR           => C405JTGCAPTUREDR,
      C405JTGEXTEST              => C405JTGEXTEST,
      C405JTGPGMOUT              => C405JTGPGMOUT,
      C405JTGSHIFTDR             => C405JTGSHIFTDR,
      C405JTGTDO                 => C405JTGTDO,
      C405JTGTDOEN               => C405JTGTDOEN,
      C405JTGUPDATEDR            => C405JTGUPDATEDR,
      C405PLBDCUABORT            => C405PLBDCUABORT,
      C405PLBDCUABUS             => C405PLBDCUABUS,
      C405PLBDCUBE               => C405PLBDCUBE,
      C405PLBDCUCACHEABLE        => C405PLBDCUCACHEABLE,
      C405PLBDCUGUARDED          => C405PLBDCUGUARDED,
      C405PLBDCUPRIORITY         => C405PLBDCUPRIORITY,
      C405PLBDCUREQUEST          => C405PLBDCUREQUEST,
      C405PLBDCURNW              => C405PLBDCURNW,
      C405PLBDCUSIZE2            => DCU_PLB_SIZE2,
      C405PLBDCUU0ATTR           => C405PLBDCUU0ATTR,
      C405PLBDCUWRDBUS           => C405PLBDCUWRDBUS,
      C405PLBDCUWRITETHRU        => C405PLBDCUWRITETHRU,
      C405PLBICUABORT            => C405PLBICUABORT,
      C405PLBICUABUS             => ICU_PLB_ABus,
      C405PLBICUCACHEABLE        => C405PLBICUCACHEABLE,
      C405PLBICUPRIORITY         => C405PLBICUPRIORITY,
      C405PLBICUREQUEST          => C405PLBICUREQUEST,
      C405PLBICUSIZE             => ICU_PLB_SIZE,
      C405PLBICUU0ATTR           => C405PLBICUU0ATTR,
      C405RSTCHIPRESETREQ        => C405RSTCHIPRESETREQ,
      C405RSTCORERESETREQ        => C405RSTCORERESETREQ,
      C405RSTSYSRESETREQ         => C405RSTSYSRESETREQ,
      C405TRCCYCLE               => C405TRCCYCLE,
      C405TRCEVENEXECUTIONSTATUS => C405TRCEVENEXECUTIONSTATUS,
      C405TRCODDEXECUTIONSTATUS  => C405TRCODDEXECUTIONSTATUS,
      C405TRCTRACESTATUS         => C405TRCTRACESTATUS,
      C405TRCTRIGGEREVENTOUT     => C405TRCTRIGGEREVENTOUT,
      C405TRCTRIGGEREVENTTYPE    => C405TRCTRIGGEREVENTTYPE,
      C405XXXMACHINECHECK        => C405XXXMACHINECHECK,
      DCREMACABUS                => DCREMACABUS,
      DCREMACCLK                 => DCREMACCLK,
      DCREMACDBUS                => DCREMACDBUS,
      DCREMACREAD                => DCREMACREAD,
      DCREMACWRITE               => DCREMACWRITE,
      DCREMACENABLER             => DCREMACENABLER,
      DSOCMBRAMABUS              => DSOCMBRAMABUS,
      DSOCMBRAMBYTEWRITE         => DSOCMBRAMBYTEWRITE,
      DSOCMBRAMEN                => DSOCMBRAMEN,
      DSOCMBRAMWRDBUS            => DSOCMBRAMWRDBUS,
      DSOCMBUSY                  => DSOCMBUSY,
      DSOCMRDADDRVALID           => DSOCMRDADDRVALID,
      DSOCMWRADDRVALID           => DSOCMWRADDRVALID,
      EXTDCRABUS                 => EXTDCRABUS,
      EXTDCRDBUSOUT              => EXTDCRDBUSOUT,
      EXTDCRREAD                 => EXTDCRREAD,
      EXTDCRWRITE                => EXTDCRWRITE,
      ISOCMBRAMEN                => ISOCMBRAMEN,
      ISOCMBRAMEVENWRITEEN       => ISOCMBRAMEVENWRITEEN,
      ISOCMBRAMODDWRITEEN        => ISOCMBRAMODDWRITEEN,
      ISOCMBRAMRDABUS            => ISOCMBRAMRDABUS,
      ISOCMBRAMWRABUS            => ISOCMBRAMWRABUS,
      ISOCMBRAMWRDBUS            => ISOCMBRAMWRDBUS,
      ISOCMDCRBRAMEVENEN         => ISOCMDCRBRAMEVENEN,
      ISOCMDCRBRAMODDEN          => ISOCMDCRBRAMODDEN,
      ISOCMDCRBRAMRDSELECT       => ISOCMDCRBRAMRDSELECT,
      BRAMDSOCMCLK               => BRAMDSOCMCLK,
      BRAMDSOCMRDDBUS            => BRAMDSOCMRDDBUS,
      BRAMISOCMCLK               => BRAMISOCMCLK,
      BRAMISOCMDCRRDDBUS         => BRAMISOCMDCRRDDBUS,
      BRAMISOCMRDDBUS            => BRAMISOCMRDDBUS,
      CPMC405CLOCK               => CPMC405CLOCK,
      CPMC405CORECLKINACTIVE     => CPMC405CORECLKINACTIVE,
      CPMC405CPUCLKEN            => CPMC405CPUCLKEN,
      CPMC405JTAGCLKEN           => CPMC405JTAGCLKEN,
      CPMC405SYNCBYPASS          => PLBSYNCBYPASS,
      CPMC405TIMERCLKEN          => CPMC405TIMERCLKEN,
      CPMC405TIMERTICK           => CPMC405TIMERTICK,
      CPMDCRCLK                  => CPMDCRCLK,
      CPMFCMCLK                  => CPMFCMCLK,
      DBGC405DEBUGHALT           => DBGC405DEBUGHALT,
      DBGC405EXTBUSHOLDACK       => DBGC405EXTBUSHOLDACK,
      DBGC405UNCONDDEBUGEVENT    => DBGC405UNCONDDEBUGEVENT,
      DSARCVALUE                 => DSARCVALUE,
      DSCNTLVALUE                => DSCNTLVALUE,
      DSOCMRWCOMPLETE            => DSOCMRWCOMPLETE,
      EICC405CRITINPUTIRQ        => EICC405CRITINPUTIRQ,
      EICC405EXTINPUTIRQ         => EICC405EXTINPUTIRQ,
      EMACDCRACK                 => EMACDCRACK,
      EMACDCRDBUS                => EMACDCRDBUS,
      EXTDCRACK                  => EXTDCRACK,
      EXTDCRDBUSIN               => EXTDCRDBUSIN,
      FCMAPUCR                   => FCMAPUCR,
      FCMAPUDCDCREN              => FCMAPUDCDCREN,
      FCMAPUDCDFORCEALIGN        => FCMAPUDCDFORCEALIGN,
      FCMAPUDCDFORCEBESTEERING   => FCMAPUDCDFORCEBESTEERING,
      FCMAPUDCDFPUOP             => FCMAPUDCDFPUOP,
      FCMAPUDCDGPRWRITE          => FCMAPUDCDGPRWRITE,
      FCMAPUDCDLDSTBYTE          => FCMAPUDCDLDSTBYTE,
      FCMAPUDCDLDSTDW            => FCMAPUDCDLDSTDW,
      FCMAPUDCDLDSTHW            => FCMAPUDCDLDSTHW,
      FCMAPUDCDLDSTQW            => FCMAPUDCDLDSTQW,
      FCMAPUDCDLDSTWD            => FCMAPUDCDLDSTWD,
      FCMAPUDCDLOAD              => FCMAPUDCDLOAD,
      FCMAPUDCDPRIVOP            => FCMAPUDCDPRIVOP,
      FCMAPUDCDRAEN              => FCMAPUDCDRAEN,
      FCMAPUDCDRBEN              => FCMAPUDCDRBEN,
      FCMAPUDCDSTORE             => FCMAPUDCDSTORE,
      FCMAPUDCDTRAPBE            => FCMAPUDCDTRAPBE,
      FCMAPUDCDTRAPLE            => FCMAPUDCDTRAPLE,
      FCMAPUDCDUPDATE            => FCMAPUDCDUPDATE,
      FCMAPUDCDXERCAEN           => FCMAPUDCDXERCAEN,
      FCMAPUDCDXEROVEN           => FCMAPUDCDXEROVEN,
      FCMAPUDECODEBUSY           => FCMAPUDECODEBUSY,
      FCMAPUDONE                 => FCMAPUDONE,
      FCMAPUEXCEPTION            => FCMAPUEXCEPTION,
      FCMAPUEXEBLOCKINGMCO       => FCMAPUEXEBLOCKINGMCO,
      FCMAPUEXECRFIELD           => FCMAPUEXECRFIELD,
      FCMAPUEXENONBLOCKINGMCO    => FCMAPUEXENONBLOCKINGMCO,
      FCMAPUINSTRACK             => FCMAPUINSTRACK,
      FCMAPULOADWAIT             => FCMAPULOADWAIT,
      FCMAPURESULT               => FCMAPURESULT,
      FCMAPURESULTVALID          => FCMAPURESULTVALID,
      FCMAPUSLEEPNOTREADY        => FCMAPUSLEEPNOTREADY,
      FCMAPUXERCA                => FCMAPUXERCA,
      FCMAPUXEROV                => FCMAPUXEROV,
      ISARCVALUE                 => ISARCVALUE,
      ISCNTLVALUE                => ISCNTLVALUE,
      JTGC405BNDSCANTDO          => JTGC405BNDSCANTDO,
      JTGC405TCK                 => JTGC405TCK,
      JTGC405TDI                 => JTGC405TDI,
      JTGC405TMS                 => JTGC405TMS,
      JTGC405TRSTNEG             => JTGC405TRSTNEG,
      MCBCPUCLKEN                => MCBCPUCLKEN,
      MCBJTAGEN                  => MCBJTAGEN,
      MCBTIMEREN                 => MCBTIMEREN,
      MCPPCRST                   => MCPPCRST,
      PLBC405DCUADDRACK          => PLBC405DCUADDRACK,
      PLBC405DCUBUSY             => PLBC405DCUBUSY,
      PLBC405DCUERR              => PLBC405DCUERR,
      PLBC405DCURDDACK           => PLBC405DCURDDACK,
      PLBC405DCURDDBUS           => PLBC405DCURDDBUS,
      PLBC405DCURDWDADDR         => DCU_PLB_MRdDBus,
      PLBC405DCUSSIZE1           => DCU_PLB_MSSize,
      PLBC405DCUWRDACK           => PLBC405DCUWRDACK,
      PLBC405ICUADDRACK          => PLBC405ICUADDRACK,
      PLBC405ICUBUSY             => PLBC405ICUBUSY,
      PLBC405ICUERR              => PLBC405ICUERR,
      PLBC405ICURDDACK           => PLBC405ICURDDACK,
      PLBC405ICURDDBUS           => PLBC405ICURDDBUS,
      PLBC405ICURDWDADDR         => ICU_PLB_MRdDBus,
      PLBC405ICUSSIZE1           => ICU_PLB_MSSize,
      PLBCLK                     => PLBCLK,
      RSTC405RESETCHIP           => RSTC405RESETCHIP,
      RSTC405RESETCORE           => RSTC405RESETCORE,
      RSTC405RESETSYS            => RSTC405RESETSYS,
      TIEAPUCONTROL              => C_APU_CONTROL,
      TIEAPUUDI1                 => C_APU_UDI_1,
      TIEAPUUDI2                 => C_APU_UDI_2,
      TIEAPUUDI3                 => C_APU_UDI_3,
      TIEAPUUDI4                 => C_APU_UDI_4,
      TIEAPUUDI5                 => C_APU_UDI_5,
      TIEAPUUDI6                 => C_APU_UDI_6,
      TIEAPUUDI7                 => C_APU_UDI_7,
      TIEAPUUDI8                 => C_APU_UDI_8,
      TIEC405DETERMINISTICMULT   => DETERMINISTIC_MULT,
      TIEC405DISOPERANDFWD       => DISABLE_OPERAND_FORWARDING,
      TIEC405MMUEN               => MMU_ENABLE,
      TIEPVRBIT8                 => C_PVR_HIGH(0),
      TIEPVRBIT9                 => C_PVR_HIGH(1),
      TIEPVRBIT10                => C_PVR_HIGH(2),
      TIEPVRBIT11                => C_PVR_HIGH(3),
      TIEPVRBIT28                => C_PVR_LOW(0),
      TIEPVRBIT29                => C_PVR_LOW(1),
      TIEPVRBIT30                => C_PVR_LOW(2),
      TIEPVRBIT31                => C_PVR_LOW(3),
      TIEDCRADDR                 => C_IDCR_BASEADDR(0 to 5),
      TRCC405TRACEDISABLE        => TRCC405TRACEDISABLE,
      TRCC405TRIGGEREVENTIN      => TRCC405TRIGGEREVENTIN);
end structure;
