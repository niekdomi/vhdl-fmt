-------------------------------------------------------------------------------
-- $Id: rdfifo.vhd,v 1.4 2004/11/23 00:59:54 jcanaris Exp $
-------------------------------------------------------------------------------
-- rdfifo.vhd - VHD design file
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        rdfifo.vhd
--
-- Description:     VHDL design file that is a wrapper around the IPIF rdfifo
--                  module. It is primarily used to include/remove the rdfifo
--                  from the IPIF per user parameterization.
--
-------------------------------------------------------------------------------
-- Structure:
--
--              rdfifo.vhd
--              rpfifo_top.vhd
--                     |
--                     |---> ipif_control_rd.vhd
--                     |---> rdpfifo_dp_cntl.vhd
--                     |
--                     |---> dp512x32_v3_2_rden_ve.edn (COREGEN created Dual Port)
--                     |  or (depending on generic)
--                     |---> dp512x32_v3_2_rden_vii.edn (COREGEN created Dual Port)
--
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
--
-- History:
--  DET      July 23, 2001      -- First version adapted from Visual HDL output
--
--
--  DET      Aug 20, 2001
--  LCW	Oct 12, 2004	 -- updated for NCSim
--
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
---------------------------------------------------------------------------------

library IEEE;
use IEEE.Std_Logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.rpfifo_top;



---------------------------------------------------------------------------------
entity rdfifo is
  generic (
           C_OPB_DBUS_WIDTH     : INTEGER := 32;
           C_B                  : INTEGER := 4;
           C_RFIFO_MIR_ENABLE   : Boolean := True;
           C_RFIFO_BLK_ID       : INTEGER := 255;
           C_VERTEX_II          : Boolean := false
           );
  port (
        Bus2IP_BE_sa            : in std_logic_vector(0 to C_B - 1 );
        Bus2IP_Burst_sa         : in std_logic;
        Bus2IP_Clk_i            : in std_logic;
        Bus2IP_Data_sa          : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        Bus2IP_RdReq_sa         : in std_logic;
        Bus2IP_Reset_i          : in std_logic;
        Bus2IP_WrReq_sa         : in std_logic;
        IP2RFIFO_Data           : in std_logic_vector(0 to 31 );
        IP2RFIFO_WrMark         : in std_logic;
        IP2RFIFO_WrRelease      : in std_logic;
        IP2RFIFO_WrReq          : in std_logic;
        IP2RFIFO_WrRestore      : in std_logic;
        RdFIFO2Bus_Data         : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        RdFIFO2Intr_DeadLock    : out std_logic;
        RdFIFO_RdCE             : in std_logic;
        RdFIFO_Reg_RdCE         : in std_logic_vector(0 to 1 );
        RdFIFO_Reg_WrCE         : in std_logic_vector(0 to 1 );
        RdFIFO_WrCE             : in std_logic;
        RFIFO2DMA_AlmostEmpty   : out std_logic;
        RFIFO2DMA_Empty         : out std_logic;
        RFIFO2DMA_Occupancy     : out std_logic_vector(0 to 9 );
        RFIFO2IP_AlmostFull     : out std_logic;
        RFIFO2IP_Full           : out std_logic;
        RFIFO2IP_Vacancy        : out std_logic_vector(0 to 9 );
        RFIFO2IP_WrAck          : out std_logic;
        RFIFO_Error             : out std_logic;
        RFIFO_RdAck             : out std_logic;
        RFIFO_Retry             : out std_logic;
        RFIFO_ToutSup           : out std_logic;
        RFIFO_WrAck             : out std_logic
        );


end rdfifo;


-------------------------------------------------------------------------------
architecture implementation of rdfifo is



    signal Bus2FIFO_RdCE1 : std_logic;
    signal Bus2FIFO_RdCE2 : std_logic;
    signal Bus2FIFO_WrCE1 : std_logic;
    signal Bus2FIFO_WrCE2 : std_logic;
    signal Bus_DBus       : std_logic_vector(28 to 31 );


begin  -- architecture implementation



         Bus2FIFO_RdCE1 <= RdFIFO_Reg_RdCE(0);
         Bus2FIFO_RdCE2 <= RdFIFO_Reg_RdCE(1);

         Bus2FIFO_WrCE1 <= RdFIFO_Reg_WrCE(0);
         Bus2FIFO_WrCE2 <= RdFIFO_Reg_WrCE(1);

         Bus_DBus(28) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-4);
         Bus_DBus(29) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-3);
         Bus_DBus(30) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-2);
         Bus_DBus(31) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-1);



         I_RdFIFO_INSTANCE : entity opb_ipif_v1_23_a.rpfifo_top
           generic map (C_RFIFO_MIR_ENABLE,
                        C_RFIFO_BLK_ID,
                        C_VERTEX_II)
           port map (
                     Bus_Reset             => Bus2IP_Reset_i,
                     Bus_Clk               => Bus2IP_Clk_i,
                     Bus_RdReq             => Bus2IP_RdReq_sa,
                     Bus_WrReq             => Bus2IP_WrReq_sa,
                     Bus2FIFO_RdCE1        => Bus2FIFO_RdCE1,
                     Bus2FIFO_RdCE2        => Bus2FIFO_RdCE2,
                     Bus2FIFO_RdCE3        => RdFIFO_RdCE,
                     Bus2FIFO_WrCE1        => Bus2FIFO_WrCE1,
                     Bus2FIFO_WrCE2        => Bus2FIFO_WrCE2,
                     Bus2FIFO_WrCE3        => RdFIFO_WrCE,
                     Bus_DBus              => Bus_DBus(28 to 31),
                     IP2RFIFO_WrReq        => IP2RFIFO_WrReq,
                     IP2RFIFO_WrMark       => IP2RFIFO_WrMark,
                     IP2RFIFO_WrRestore    => IP2RFIFO_WrRestore,
                     IP2RFIFO_WrRelease    => IP2RFIFO_WrRelease,
                     IP2RFIFO_Data         => IP2RFIFO_Data(0 to 31),
                     RFIFO2IP_WrAck        => RFIFO2IP_WrAck,
                     RFIFO2IP_AlmostFull   => RFIFO2IP_AlmostFull,
                     RFIFO2IP_Full         => RFIFO2IP_Full,
                     RFIFO2IP_Vacancy      => RFIFO2IP_Vacancy(0 to 9),
                     RFIFO2DMA_AlmostEmpty => RFIFO2DMA_AlmostEmpty,
                     RFIFO2DMA_Empty       => RFIFO2DMA_Empty,
                     RFIFO2DMA_Occupancy   => RFIFO2DMA_Occupancy(0 to 9),
                     FIFO2IRPT_DeadLock    => RdFIFO2Intr_DeadLock,
                     FIFO2Bus_DBus         => RdFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
                     FIFO2Bus_WrAck        => RFIFO_WrAck,
                     FIFO2Bus_RdAck        => RFIFO_RdAck,
                     FIFO2Bus_Error        => RFIFO_Error,
                     FIFO2Bus_Retry        => RFIFO_Retry,
                     FIFO2Bus_ToutSup      => RFIFO_ToutSup);






--     ---------------------------------------------------------------------------
--     -- If selected, include rdfifo in the design
--     ---------------------------------------------------------------------------
--      INCLUDE_RDFIFO : if (C_RDFIFO_PRESENT = True) generate
--
--         signal Bus2FIFO_RdCE1 : std_logic;
--         signal Bus2FIFO_RdCE2 : std_logic;
--         signal Bus2FIFO_WrCE1 : std_logic;
--         signal Bus2FIFO_WrCE2 : std_logic;
--         signal Bus_DBus       : std_logic_vector(28 to 31 );
--
--       begin
--
--          Bus2FIFO_RdCE1 <= RdFIFO_Reg_RdCE(0);
--          Bus2FIFO_RdCE2 <= RdFIFO_Reg_RdCE(1);
--
--          Bus2FIFO_WrCE1 <= RdFIFO_Reg_WrCE(0);
--          Bus2FIFO_WrCE2 <= RdFIFO_Reg_WrCE(1);
--
--          Bus_DBus(28) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-4);
--          Bus_DBus(29) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-3);
--          Bus_DBus(30) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-2);
--          Bus_DBus(31) <= Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-1);
--
--
--          RdFIFO_INSTANCE : rpfifo_top_v0_00_b
--            generic map (C_RFIFO_MIR_ENABLE,
--                         C_RFIFO_BLK_ID)
--            port map (
--                      Bus_Reset             => Bus2IP_Reset_i,
--                      Bus_Clk               => Bus2IP_Clk_i,
--                      Bus_RdReq             => Bus2IP_RdReq_sa,
--                      Bus_WrReq             => Bus2IP_WrReq_sa,
--                      Bus2FIFO_RdCE1        => Bus2FIFO_RdCE1,
--                      Bus2FIFO_RdCE2        => Bus2FIFO_RdCE2,
--                      Bus2FIFO_RdCE3        => RdFIFO_RdCE,
--                      Bus2FIFO_WrCE1        => Bus2FIFO_WrCE1,
--                      Bus2FIFO_WrCE2        => Bus2FIFO_WrCE2,
--                      Bus2FIFO_WrCE3        => RdFIFO_WrCE,
--                      Bus_DBus              => Bus_DBus(28 to 31),
--                      IP2RFIFO_WrReq        => IP2RFIFO_WrReq,
--                      IP2RFIFO_WrMark       => IP2RFIFO_WrMark,
--                      IP2RFIFO_WrRestore    => IP2RFIFO_WrRestore,
--                      IP2RFIFO_WrRelease    => IP2RFIFO_WrRelease,
--                      IP2RFIFO_Data         => IP2RFIFO_Data(0 to 31),
--                      RFIFO2IP_WrAck        => RFIFO2IP_WrAck,
--                      RFIFO2IP_AlmostFull   => RFIFO2IP_AlmostFull,
--                      RFIFO2IP_Full         => RFIFO2IP_Full,
--                      RFIFO2IP_Vacancy      => RFIFO2IP_Vacancy(0 to 9),
--                      RFIFO2DMA_AlmostEmpty => RFIFO2DMA_AlmostEmpty,
--                      RFIFO2DMA_Empty       => RFIFO2DMA_Empty,
--                      RFIFO2DMA_Occupancy   => RFIFO2DMA_Occupancy(0 to 9),
--                      FIFO2IRPT_DeadLock    => RdFIFO2Intr_DeadLock,
--                      FIFO2Bus_DBus         => RdFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
--                      FIFO2Bus_WrAck        => RFIFO_WrAck,
--                      FIFO2Bus_RdAck        => RFIFO_RdAck,
--                      FIFO2Bus_Error        => RFIFO_Error,
--                      FIFO2Bus_Retry        => RFIFO_Retry,
--                      FIFO2Bus_ToutSup      => RFIFO_ToutSup);
--
--       end generate; -- INCLUDE_RDFIFO
--
--
--
--
--
--       ---------------------------------------------------------------------------
--       -- Remove rdfifo from the design
--       ---------------------------------------------------------------------------
--        REMOVE_RDFIFO : if (C_RDFIFO_PRESENT = False) generate
--
--           RdFIFO2Bus_Data         <= (others => '0');
--           RdFIFO2Intr_DeadLock    <= '0';
--           RFIFO2DMA_AlmostEmpty   <= '0';
--           RFIFO2DMA_Empty         <= '0';
--           RFIFO2DMA_Occupancy     <= (others => '0');
--           RFIFO2IP_AlmostFull     <= '0';
--           RFIFO2IP_Full           <= '0';
--           RFIFO2IP_Vacancy        <= (others => '0');
--           RFIFO2IP_WrAck          <= '0';
--           RFIFO_Error             <= '0';
--           RFIFO_RdAck             <= '0';
--           RFIFO_Retry             <= '0';
--           RFIFO_ToutSup           <= '0';
--           RFIFO_WrAck             <= '0';
--
--
--       end generate; -- REMOVE_RDFIFO




end implementation;

