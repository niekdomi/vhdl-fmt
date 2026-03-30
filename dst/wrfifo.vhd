-------------------------------------------------------------------------------
-- $Id: wrfifo.vhd,v 1.4 2004/11/23 00:59:54 jcanaris Exp $
-------------------------------------------------------------------------------
-- wrfifo.vhd   Version v1.01a
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        wrfifo.vhd
--
-- Description:     VHDL design file that is a wrapper around the IPIF wrfifo
--                  module. It is primarily used to include/remove the wrfifo
--                  from the IPIF per user parameterization.
--
-------------------------------------------------------------------------------
-- Structure:
--
--              wrfifo.vhd
--                  wpfifo_top.vhd
--                         |
--                         |---> ipif_control_wr.vhd
--                         |---> wpfifo_dp_cntl.vhd
--                         |---> dp512x32_v3_2_rden_vii.edn (COREGEN created Dual Port)
--                         |
--                         |  or (depending on the C_VERTEX_II parameter setting)
--                         |
--                         |---> dp512x32_v3_2_rden_ve.edn (COREGEN created Dual Port)
--
-------------------------------------------------------------------------------
-- Author:      D. Thorpe
--
-- History:
--  DET      July 23, 2001      -- First version adapted from Visual HDL output
--
--
--  DET     Aug 20, 2001        -- v1.01a
--          - Platform Generator compliancy modifications
--
--  LCW	Oct 12, 2004	 -- updated for NCSim
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
use opb_ipif_v1_23_a.wrpfifo_top;

---------------------------------------------------------------------------------

entity wrfifo is
  generic (
           C_OPB_DBUS_WIDTH   : INTEGER := 32;
           C_B                : INTEGER := 4;
           C_WFIFO_MIR_ENABLE : Boolean := True;
           C_WFIFO_BLK_ID     : INTEGER := 254;
           C_VERTEX_II        : Boolean := true
           );
  port (
        Bus2IP_BE_sa         : in std_logic_vector(0 to C_B - 1 );
        Bus2IP_Burst_sa      : in std_logic;
        Bus2IP_Clk_i         : in std_logic;
        Bus2IP_Data_sa       : in std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        Bus2IP_RdReq_sa      : in std_logic;
        Bus2IP_Reset_i       : in std_logic;
        Bus2IP_WrReq_sa      : in std_logic;
        IP2WFIFO_RdMark      : in std_logic;
        IP2WFIFO_RdRelease   : in std_logic;
        IP2WFIFO_RdReq       : in std_logic;
        IP2WFIFO_RdRestore   : in std_logic;
        WFIFO2DMA_AlmostFull : out std_logic;
        WFIFO2DMA_Full       : out std_logic;
        WFIFO2DMA_Vacancy    : out std_logic_vector(0 to 9 );
        WFIFO2IP_AlmostEmpty : out std_logic;
        WFIFO2IP_Data        : out std_logic_vector(0 to 31 );
        WFIFO2IP_Empty       : out std_logic;
        WFIFO2IP_Occupancy   : out std_logic_vector(0 to 9 );
        WFIFO2IP_RdAck       : out std_logic;
        WFIFO_Error          : out std_logic;
        WFIFO_RdAck          : out std_logic;
        WFIFO_Retry          : out std_logic;
        WFIFO_ToutSup        : out std_logic;
        WFIFO_WrAck          : out std_logic;
        WrFIFO2Bus_Data      : out std_logic_vector(0 to C_OPB_DBUS_WIDTH - 1 );
        WrFIFO2Intr_DeadLock : out std_logic;
        WrFIFO_RdCE          : in std_logic;
        WrFIFO_Reg_RdCE      : in std_logic_vector(0 to 1 );
        WrFIFO_Reg_WrCE      : in std_logic_vector(0 to 1 );
        WrFIFO_WrCE          : in std_logic
        );


end wrfifo;


----------------------------------------------------------------------------------

architecture implementation of wrfifo is


        signal Bus2FIFO_RdCE1 : std_logic;
        signal Bus2FIFO_RdCE2 : std_logic;
        signal Bus2FIFO_WrCE1 : std_logic;
        signal Bus2FIFO_WrCE2 : std_logic;




 begin -- architecture wrfifo



      -- Adapt vector chip enables to unique enables
      Bus2FIFO_RdCE1 <= WrFIFO_Reg_RdCE(0);
      Bus2FIFO_RdCE2 <= WrFIFO_Reg_RdCE(1);

      Bus2FIFO_WrCE1 <= WrFIFO_Reg_WrCE(0);
      Bus2FIFO_WrCE2 <= WrFIFO_Reg_WrCE(1);


     I_WRFIFO_INSTANCE : entity opb_ipif_v1_23_a.wrpfifo_top
       generic map (C_WFIFO_MIR_ENABLE,
                    C_WFIFO_BLK_ID,
                    C_VERTEX_II)
       port map (
                 Bus_Reset            => Bus2IP_Reset_i,
                 Bus_Clk              => Bus2IP_Clk_i,
                 Bus_RdReq            => Bus2IP_RdReq_sa,
                 Bus_WrReq            => Bus2IP_WrReq_sa,
                 Bus2FIFO_RdCE1       => Bus2FIFO_RdCE1,
                 Bus2FIFO_RdCE2       => Bus2FIFO_RdCE2,
                 Bus2FIFO_RdCE3       => WrFIFO_RdCE,
                 Bus2FIFO_WrCE1       => Bus2FIFO_WrCE1,
                 Bus2FIFO_WrCE2       => Bus2FIFO_WrCE2,
                 Bus2FIFO_WrCE3       => WrFIFO_WrCE,
                 Bus_DBus             => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
                 IP2WFIFO_RdReq       => IP2WFIFO_RdReq,
                 IP2WFIFO_RdMark      => IP2WFIFO_RdMark,
                 IP2WFIFO_RdRestore   => IP2WFIFO_RdRestore,
                 IP2WFIFO_RdRelease   => IP2WFIFO_RdRelease,
                 WFIFO2IP_Data        => WFIFO2IP_Data(0 to 31),
                 WFIFO2IP_RdAck       => WFIFO2IP_RdAck,
                 WFIFO2IP_AlmostEmpty => WFIFO2IP_AlmostEmpty,
                 WFIFO2IP_Empty       => WFIFO2IP_Empty,
                 WFIFO2IP_Occupancy   => WFIFO2IP_Occupancy(0 to 9),
                 WFIFO2DMA_AlmostFull => WFIFO2DMA_AlmostFull,
                 WFIFO2DMA_Full       => WFIFO2DMA_Full,
                 WFIFO2DMA_Vacancy    => WFIFO2DMA_Vacancy(0 to 9),
                 FIFO2IRPT_DeadLock   => WrFIFO2Intr_DeadLock,
                 FIFO2Bus_DBus        => WrFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
                 FIFO2Bus_WrAck       => WFIFO_WrAck,
                 FIFO2Bus_RdAck       => WFIFO_RdAck,
                 FIFO2Bus_Error       => WFIFO_Error,
                 FIFO2Bus_Retry       => WFIFO_Retry,
                 FIFO2Bus_ToutSup     => WFIFO_ToutSup);










 --     ---------------------------------------------------------------------------
 --     -- If selected, include wrfifo in the design
 --     ---------------------------------------------------------------------------
 --      INCLUDE_WRFIFO : if (C_WRFIFO_PRESENT = True) generate
 --
 --         signal Bus2FIFO_RdCE1 : std_logic;
 --         signal Bus2FIFO_RdCE2 : std_logic;
 --         signal Bus2FIFO_WrCE1 : std_logic;
 --         signal Bus2FIFO_WrCE2 : std_logic;
 --
 --       begin
 --
 --         -- Adapt vector chip enables to unique enables
 --         Bus2FIFO_RdCE1 <= WrFIFO_Reg_RdCE(0);
 --         Bus2FIFO_RdCE2 <= WrFIFO_Reg_RdCE(1);
 --
 --         Bus2FIFO_WrCE1 <= WrFIFO_Reg_WrCE(0);
 --         Bus2FIFO_WrCE2 <= WrFIFO_Reg_WrCE(1);
 --
 --
 --
 --         WrFIFO_INSTANCE : wpfifo_top_v0_00_c
 --           generic map (C_WFIFO_MIR_ENABLE,
 --                        C_WFIFO_BLK_ID)
 --           port map (
 --                     Bus_Reset            => Bus2IP_Reset_i,
 --                     Bus_Clk              => Bus2IP_Clk_i,
 --                     Bus_RdReq            => Bus2IP_RdReq_sa,
 --                     Bus_WrReq            => Bus2IP_WrReq_sa,
 --                     Bus2FIFO_RdCE1       => Bus2FIFO_RdCE1,
 --                     Bus2FIFO_RdCE2       => Bus2FIFO_RdCE2,
 --                     Bus2FIFO_RdCE3       => WrFIFO_RdCE,
 --                     Bus2FIFO_WrCE1       => Bus2FIFO_WrCE1,
 --                     Bus2FIFO_WrCE2       => Bus2FIFO_WrCE2,
 --                     Bus2FIFO_WrCE3       => WrFIFO_WrCE,
 --                     Bus_DBus             => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH - 1),
 --                     IP2WFIFO_RdReq       => IP2WFIFO_RdReq,
 --                     IP2WFIFO_RdMark      => IP2WFIFO_RdMark,
 --                     IP2WFIFO_RdRestore   => IP2WFIFO_RdRestore,
 --                     IP2WFIFO_RdRelease   => IP2WFIFO_RdRelease,
 --                     WFIFO2IP_Data        => WFIFO2IP_Data(0 to 31),
 --                     WFIFO2IP_RdAck       => WFIFO2IP_RdAck,
 --                     WFIFO2IP_AlmostEmpty => WFIFO2IP_AlmostEmpty,
 --                     WFIFO2IP_Empty       => WFIFO2IP_Empty,
 --                     WFIFO2IP_Occupancy   => WFIFO2IP_Occupancy(0 to 9),
 --                     WFIFO2DMA_AlmostFull => WFIFO2DMA_AlmostFull,
 --                     WFIFO2DMA_Full       => WFIFO2DMA_Full,
 --                     WFIFO2DMA_Vacancy    => WFIFO2DMA_Vacancy(0 to 9),
 --                     FIFO2IRPT_DeadLock   => WrFIFO2Intr_DeadLock,
 --                     FIFO2Bus_DBus        => WrFIFO2Bus_Data(0 to C_OPB_DBUS_WIDTH - 1),
 --                     FIFO2Bus_WrAck       => WFIFO_WrAck,
 --                     FIFO2Bus_RdAck       => WFIFO_RdAck,
 --                     FIFO2Bus_Error       => WFIFO_Error,
 --                     FIFO2Bus_Retry       => WFIFO_Retry,
 --                     FIFO2Bus_ToutSup     => WFIFO_ToutSup);
 --
 --
 --     end generate; -- INCLUDE_WRFIFO
 --
 --
 --
 --
 --
 --
 --     ---------------------------------------------------------------------------
 --     -- Remove wrfifo from the design
 --     ---------------------------------------------------------------------------
 --      REMOVE_WRFIFO : if (C_WRFIFO_PRESENT = False) generate
 --
 --             WFIFO2DMA_AlmostFull <= '0';
 --             WFIFO2DMA_Full       <= '0';
 --             WFIFO2DMA_Vacancy    <= (others => '0');
 --             WFIFO2IP_AlmostEmpty <= '0';
 --             WFIFO2IP_Data        <= (others => '0');
 --             WFIFO2IP_Empty       <= '0';
 --             WFIFO2IP_Occupancy   <= (others => '0');
 --             WFIFO2IP_RdAck       <= '0';
 --             WFIFO_Error          <= '0';
 --             WFIFO_RdAck          <= '0';
 --             WFIFO_Retry          <= '0';
 --             WFIFO_ToutSup        <= '0';
 --             WFIFO_WrAck          <= '0';
 --             WrFIFO2Bus_Data      <= (others => '0');
 --             WrFIFO2Intr_DeadLock <= '0';
 --
 --     end generate; -- REMOVE_WRFIFO




end implementation;

