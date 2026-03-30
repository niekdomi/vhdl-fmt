-------------------------------------------------------------------------------
--  $Id: priority_encoder.vhd,v 1.2 2004/11/23 01:15:02 jcanaris Exp $
-------------------------------------------------------------------------------
-- priority_encoder.vhd - entity/architecture pair
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
-- Filename:        priority_encoder.vhd
-- Version:         v1.01a
-- Description:     This file contains the carry-chain, parameterizable
--                  implementation of the priority encoder. The priority
--                  encoder selects the master with the highest priority bits.
--                  If there is more than one master with the highest priority
--                  bits, then the priority is fixed with Master 0 being the
--                  highest priority, then Master 1, Master 2, etc.
--
--                  Note that this code is parameterized for a number of masters
--                  which is divisible by 4. The number of masters passed into
--                  this file from PLB_PRIORITY_ENCODER.vhd has been padded to
--                  the nearest power of 2 and therefore meets this requirement.
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
-- Author:      ALS
-- History:
---     ALS     02/20/02        -- created from plb_arbiter_v1_01_a
--      ALS     04/16/02        -- Version v1.01a
--  LCW	Oct 15, 2004	  -- updated for NCSim
-------------------------------------------------------------------------------
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
library ieee;
use ieee.std_logic_1164.all;

-- The unisim library is required when instantiating Xilinx primitives.
library unisim;
use unisim.vcomponents.all;

library plb_v34_v1_02_a;
use plb_v34_v1_02_a.qual_request;




-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Definition of Generics:
--          C_NUM_MASTERS               -- number of PLB masters
--
-- Definition of Ports:
--
--      -- Master interface signals
--          input   M_request           -- array of masters requests
--          input   M_priority          -- array of masters priorities
--          input   M_abort             -- array of masters aborts
--
--      -- Arbiter interface signals
--          input   ArbDisMReqReg       -- indicates when masters requests are
--                                      -- disabled
--      -- Output
--          output  PrioencdrOutput     -- 1-hot register indicating who won
--                                      -- priority
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Section
-------------------------------------------------------------------------------
entity priority_encoder is
    generic (
            C_NUM_MASTERS       : integer   := 8
            );
    port    (
            M_request           : in    std_logic_vector(0 to C_NUM_MASTERS-1);
            M_priority          : in    std_logic_vector(0 to C_NUM_MASTERS*2-1);
            M_abort             : in    std_logic_vector(0 to C_NUM_MASTERS-1);
            ArbDisMReqReg       : in    std_logic_vector(0 to C_NUM_MASTERS-1);
            PrioencdrOutput     : out   std_logic_vector(0 to C_NUM_MASTERS-1)
            );
end priority_encoder;


-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture simulation of priority_encoder is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-- number of MUXCYs in a carry chain
constant NUM_MUX            : integer   := 7;

-- number of master quadrants
constant NUM_QUADS          : integer   := C_NUM_MASTERS/4;
-------------------------------------------------------------------------------
-- Signal and Type Declarations
-------------------------------------------------------------------------------
-- Decoded master levels
-- Single array arranged by M0_lvl0, M0_lvl1, M0_lvl2, M0_lvl3, M1_lvl0, M1_lvl1,
-- M1_lvl2, M1_lvl3, etc. where M#_lvl# are outputs from the QUAL_REQUEST blocks.
signal m_lvl                : std_logic_vector(0 to C_NUM_MASTERS*4-1);

-- Quadrant level signals
-- stores whether any master in each quadrant had a request of a certain level
-- there are 4 priority levels - these signals are active low
type QUAD_LVL_TYPE is array (0 to NUM_QUADS-1) of std_logic_vector(0 to 3);
signal q_lvl_n              : QUAD_LVL_TYPE;

-- Quadrant select signals
-- stores the MUXCY selects for the carry chains in the quadrant
-- there are NUM_MUX MUXCYs in each carry chain
type QUAD_SEL_TYPE is array (0 to NUM_QUADS -1) of std_logic_vector(0 to NUM_MUX-1);
signal q_sel                : QUAD_SEL_TYPE;

type TEMP_SEL_TYPE is array (0 to NUM_QUADS*NUM_MUX-1) of std_logic_vector(0 to NUM_QUADS-1);
signal temp_sel             : TEMP_SEL_TYPE;

-- Carry chain input signals
-- this data type is used for the DI, CI inputs to the MUXCYs
-- there are NUM_MUX MUXCYs in each chain and 4 masters in each quadrant
-- these signals only need to be stored for each quadrant
type MUXCY_DIN_TYPE is array (0 to 3) of std_logic_vector(0 to NUM_MUX-1);
type QUAD_MUXCY_TYPE is array (0 to NUM_QUADS-1) of MUXCY_DIN_TYPE;
signal lutout               : QUAD_MUXCY_TYPE;
signal cyout                : QUAD_MUXCY_TYPE;

-- Define signals for '1' and '0'
signal zero                 : std_logic := '0';
signal one                  : std_logic := '1';

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

-- QUAL_REQUEST decodes the master's priority bits into the lvl signal IF the
-- master's request and abort is negated and the request is not disabled

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin

-------------------------------------------------------------------------------
-- Component Instantiations
-------------------------------------------------------------------------------
-- Instantiate the qual_request components for the secondary read/write
-- signals and the masters
-------------------------------------------------------------------------------

MASTER_LVLS: for n in 0 to C_NUM_MASTERS-1 generate

        I_QUAL_MASTERS_REQUEST: entity plb_v34_v1_02_a.qual_request
            port map (
                    Request         => M_request(n),
                    ArbDisReqReg    => ArbDisMReqReg(n),
                    Abort           => M_abort(n),
                    Priority        => M_priority(2*n to (2*n)+1),
                    Lvl0            => m_lvl(n*4),
                    Lvl1            => m_lvl(n*4 + 1),
                    Lvl2            => m_lvl(n*4 + 2),
                    Lvl3            => m_lvl(n*4 + 3)
                    );
end generate MASTER_LVLS;

-------------------------------------------------------------------------------
-- Generate the logic to determine whether a master in a quadrant has a certain
-- priority level. If any master in a quadrant has a priority level 3, then the
-- lvl3_n signal (active low) is asserted. This is true for each priority level
-- in each quadrant
-------------------------------------------------------------------------------

QUAD_LVL_GEN: for i in 0 to NUM_QUADS -1 generate -- loop through quadrants

    LVLS_GEN: for n in 0 to 3 generate    -- loop through levels

        q_lvl_n(i)(n) <= not(m_lvl(i*16+n) or m_lvl(i*16+4+n) or
                             m_lvl(i*16+8+n) or m_lvl(i*16+12+n));
    end generate LVLS_GEN;
end generate QUAD_LVL_GEN;

-------------------------------------------------------------------------------
-- Generate the mux select signals for the quadrants
-------------------------------------------------------------------------------
QUAD_SEL_GEN: for i in 0 to NUM_QUADS -1 generate -- loop through quadrants

   MUXLOOP: for j in 0 to NUM_MUX-1 generate -- loop through muxes

        EVEN_SELS: if (j mod 2 = 0) generate  -- handle evens

                    EVEN_ZERO_SEL: if i = 0 generate
                                --q_sel(i)(j) <= q_sel(i)(j) and q_lvl_n(i)(j/2);
                                q_sel(i)(j) <= q_lvl_n(i)(j/2);
                    end generate EVEN_ZERO_SEL;

                    EVEN_NONZERO_SEL: if i /= 0 generate
                           E_MUXSEL: for k in 0 to (i-1) generate
                                ZERO_K: if k = 0 generate
                                    temp_sel(i*NUM_MUX+j)(k) <= q_lvl_n(k)(j/2);
                                end generate ZERO_K;
                                NZ_K: if k /= 0 generate
                                    temp_sel(i*NUM_MUX+j)(k) <= temp_sel(i*NUM_MUX+j)(k-1) and q_lvl_n(k)(j/2);
                                end generate NZ_K;
                           end generate E_MUXSEL;
                           q_sel(i)(j) <= temp_sel(i*NUM_MUX+j)(i-1);
                    end generate EVEN_NONZERO_SEL;

        end generate EVEN_SELS;

        ODD_SELS: if (j mod 2 /= 0) generate -- handle odds

                ODD_ZERO_SELS: if i = 0 generate

                    -- if there is only one quadrant, then there are not q_lvl_n signals for
                    -- the select lines of the odd muxes. In fact, these "odd" muxes are not
                    -- required, therefore, set the select lines to '1' to allow the previous
                    -- mux output to flow through and the muxes to be optimized away in
                    -- synthesis.

                    ONEQUAD_GEN: if NUM_QUADS = 1 generate
                        q_sel(i)(j) <= '1';
                    end generate ONEQUAD_GEN;

                    MULTQUAD_GEN: if NUM_QUADS > 1 generate
                        OZ_MUX_SELS: for k in i+1 to NUM_QUADS-1 generate
                            ONE_ZK: if k = i+1 generate
                                temp_sel(i*NUM_MUX+j)(k) <= q_lvl_n(k)((j+1)/2);
                            end generate ONE_ZK;
                            OTHER_ZK: if k > i+1 generate
                                temp_sel(i*NUM_MUX+j)(k) <= temp_sel(i*NUM_MUX+j)(k-1) and q_lvl_n(k)((j+1)/2);
                            end generate OTHER_ZK;
                        end generate OZ_MUX_SELS;
                        q_sel(i)(j) <= temp_sel(i*NUM_MUX+j)(NUM_QUADS-1);
                    end generate MULTQUAD_GEN;

                end generate ODD_ZERO_SELS;

                ODD_NONZERO_SELS:  if i /= 0 generate
                        O_MUXSEL: for k in i to NUM_QUADS -1 generate
                            ONE_NZK: if k = i generate
                                temp_sel(i*NUM_MUX+j)(k) <= q_lvl_n(k)((j+1)/2);
                            end generate ONE_NZK;
                            OTHER_NZK: if k > i generate
                                temp_sel(i*NUM_MUX+j)(k) <= temp_sel(i*NUM_MUX+j)(k-1) and q_lvl_n(k)((j+1)/2);
                            end generate OTHER_NZK;
                        end generate O_MUXSEL;
                        q_sel(i)(j) <= temp_sel(i*NUM_MUX+j)(NUM_QUADS-1);
                end generate ODD_NONZERO_SELS;

        end generate ODD_SELS;

    end generate MUXLOOP;
end generate QUAD_SEL_GEN;

-------------------------------------------------------------------------------
-- Generate the lut outputs
-------------------------------------------------------------------------------
LUTOUT_GEN: for i in 0 to NUM_QUADS-1 generate -- loop through quadrants

        MSTRLOOP: for j in 0 to 3 generate            -- loop through each master in quad

            MUXCY_LOOP: for n in 0 to 6 generate

                QUAD_ZERO:if i = 0 generate       -- quadrant 0 uses chain differently

                        EVEN_QUAD_ZERO: if n mod 2 = 0 generate -- even indexes

                            MASTER_ZERO: if j=0 generate     -- master 0 is highest priority
                                lutout(i)(j)(n) <= m_lvl(n/2);
                            end generate MASTER_ZERO;

                            MASTER_ONE: if j=1 generate     -- determine priority for master1
                                lutout(i)(j)(n) <= not(m_lvl(n/2)) and m_lvl(n/2+4);
                            end generate MASTER_ONE;

                            MASTER_TWO: if j=2 generate     -- determine priority for master2
                                lutout(i)(j)(n) <= not(m_lvl(n/2)) and not(m_lvl((n/2)+4))
                                                and m_lvl((n/2)+8);
                            end generate MASTER_TWO;

                            MASTER_THREE: if j=3 generate     -- determine priority for master3
                                lutout(i)(j)(n) <= not (m_lvl(n/2)) and not(m_lvl(n/2+4))
                                            and not(m_lvl(n/2+8)) and m_lvl(n/2+12);
                            end generate MASTER_THREE;
                        end generate EVEN_QUAD_ZERO;

                        ODD_QUAD_ZERO: if n mod 2 = 1 generate -- odd indexes
                            lutout(i)(j)(n) <= zero;
                        end generate ODD_QUAD_ZERO;

                end generate QUAD_ZERO;

                OTHER_QUADS: if i /= 0 generate      -- assign values for other quadrants

                        ZEROMUX_NZ_QUAD: if n=0 generate

                            ZERO_MASTER: if j=0 generate     -- master 0 of this quad is highest priority
                                lutout(i)(j)(n) <= m_lvl(i*16+(n/2));
                            end generate ZERO_MASTER;

                            ONE_MASTER: if j=1 generate     -- determine priority for master1 in this quad
                                lutout(i)(j)(n) <= not(m_lvl(i*16+(n/2))) and m_lvl(i*16+(n/2)+4);
                            end generate ONE_MASTER;

                            TWO_MASTER: if j=2 generate     -- determine priority for master2 in this quad
                                lutout(i)(j)(n) <= not(m_lvl(i*16+(n/2))) and not(m_lvl(i*16+(n/2)+4))
                                            and m_lvl(i*16+(n/2)+8);
                            end generate TWO_MASTER;

                            THREE_MASTER: if j=3 generate     -- determine priority for master3 in this quad
                                lutout(i)(j)(n) <= not (m_lvl(i*16+(n/2))) and not(m_lvl((n/2)+4))
                                            and not(m_lvl((n/2)+8)) and m_lvl(i*16+(n/2)+12);
                            end generate THREE_MASTER;
                        end generate ZEROMUX_NZ_QUAD;

                        ODDMUX_NZ_QUAD: if n mod 2 = 1 generate

                            ZERO_MASTER: if j=0 generate     -- master 0 of this quad is highest priority
                                lutout(i)(j)(n) <= m_lvl(i*16+(n+1)/2);
                            end generate ZERO_MASTER;

                            ONE_MASTER: if j=1 generate     -- determine priority for master1
                                lutout(i)(j)(n) <= not(m_lvl(i*16+((n+1)/2))) and m_lvl(i*16+((n+1)/2)+4);
                            end generate ONE_MASTER;

                            TWO_MASTER: if j=2 generate     -- determine priority for master2
                                lutout(i)(j)(n) <= not(m_lvl(i*16+((n+1)/2))) and not(m_lvl(i*16+((n+1)/2)+4))
                                            and m_lvl(i*16+((n+1)/2)+8);
                            end generate TWO_MASTER;

                            THREE_MASTER: if j=3 generate     -- determine priority for master3
                                lutout(i)(j)(n) <= not (m_lvl(i*16+((n+1)/2))) and not(m_lvl(i*16+((n+1)/2)+4))
                                            and not(m_lvl(i*16+((n+1)/2)+8)) and m_lvl(i*16+((n+1)/2)+12);
                            end generate THREE_MASTER;
                        end generate ODDMUX_NZ_QUAD;

                        EVEN_NONZERO_QUAD: if n/=0 and n mod 2 =0 generate
                            lutout(i)(j)(n) <= zero;
                        end generate EVEN_NONZERO_QUAD;

                end generate OTHER_QUADS;

            end generate MUXCY_LOOP;

        end generate MSTRLOOP;
end generate LUTOUT_GEN;

-------------------------------------------------------------------------------
-- Generate the carry chains
-------------------------------------------------------------------------------
MUXCY_GEN: for i in 0 to NUM_QUADS-1 generate -- loop through each quadrant

        QZ: if i = 0 generate           -- quadrant 0 is special

                QZ_MSTRS: for j in 0 to 3 generate    -- loop through each master in each quadrant

                    FIRSTMUX: MUXCY         -- first mux is special
                        port map (CI => zero,
                              DI => lutout(i)(j)(0),
                              S => q_sel(i)(0),
                              O => cyout(i)(j)(0)
                              );

                    OTHERMUXES: for n in 1 to NUM_MUX-1 generate

                        MUXES: MUXCY
                            port map (CI => cyout(i)(j)(n-1),
                                  DI => lutout(i)(j)(n),
                                  S => q_sel(i)(n),
                                  O => cyout(i)(j)(n)
                                  );
                    end generate OTHERMUXES;

                    prioencdrOutput(i*4+j) <= cyout(i)(j)(NUM_MUX-1);

            end generate QZ_MSTRS;

        end generate QZ;

        QNZ: if i /= 0 generate           -- quadrant 0 is special

            QNZ_MSTRS: for j in 0 to 3 generate    -- loop through each master in each quadrant

                    MUXFIRST: MUXCY         -- first mux is special
                        port map (CI => lutout(i)(j)(0),
                              DI => zero,
                              S => q_sel(i)(0),
                              O => cyout(i)(j)(0)
                              );

                    RESTMUXES: for n in 1 to NUM_MUX-1 generate

                        MUXES: MUXCY
                            port map (CI => cyout(i)(j)(n-1),
                                  DI => lutout(i)(j)(n),
                                  S => q_sel(i)(n),
                                  O  => cyout(i)(j)(n)
                                  );
                    end generate RESTMUXES;

                prioencdrOutput(i*4+j) <= cyout(i)(j)(NUM_MUX-1);

            end generate QNZ_MSTRS;

        end generate QNZ;

end generate MUXCY_GEN;

end simulation;
