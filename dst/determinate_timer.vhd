-------------------------------------------------------------------------------
-- $Id: determinate_timer.vhd,v 1.2 2004/11/23 01:10:26 jcanaris Exp $
-------------------------------------------------------------------------------
-- determinate_timer.vhd
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        determinate_timer.vhd
--
-- Description:
--  This VHDL design implements a parameterizable timer function that
--  is used to generate control/response timing of IPIF transactions with
--  an IP target device.
--
--
--
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--              determinate_timer.vhd
--
-------------------------------------------------------------------------------
-- Author:          DET
-- Revision:        $Revision: 1.2 $
-- Date:            $5/15/2002$
--
-- History:
--     DET   5/15/2002       Initial Version
--
--     DET     7/19/2002     Initial
-- ~~~~~~
--     - Fixed a problem with the cycle count operation during
--       indetirminate timing operation.
-- ^^^^^^
--
--     DET     7/25/2002     DDR Burst Integ
-- ~~~~~~
--     - Corrected the methodology for identifying an active chip select bit
--  when multiple chip selects are asserted. This condition only occurs when
--  the ipif user requires a constant number of CS bits to their core but due
--  to parameterization, actually use less than that. The ARD Array Base
--  Address array is usually populated in the unused entries with the same
--  baseaddr/highaddr pair in order to conserve system memory space. This
--  generates multiple chip selects for those overlapped address spaces.
-- ^^^^^^
--
--
--     DET     11/19/2002     plb ipif Rev C update
-- ~~~~~~
--     - Changed the ipif_common library reference to ipif_common_v1_00_b.
-- ^^^^^^
--
--     DET     3/13/2003     Rev C Optimization
-- ~~~~~~
--     - Modified the Dtime parameter multiplexing path to improve Fmax
--       timing and LUT count.
-- ^^^^^^
--  LCW	Oct 19, 2004	  -- updated for NCSim
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
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
Use IEEE.std_logic_arith.all;
Use IEEE.std_logic_unsigned.all;

Library proc_common_v1_00_b;
Use proc_common_v1_00_b.all;
Use proc_common_v1_00_b.proc_common_pkg.all;

library ipif_common_v1_00_b;
Use ipif_common_v1_00_b.ipif_pkg.all;

library unisim;
use unisim.vcomponents.all;

library plb_ipif_v1_00_d;
use plb_ipif_v1_00_d.pf_counter_top;





-------------------------------------------------------------------------------

entity determinate_timer is
  generic (
    -- Generics
    C_NUM_CS                 : Integer := 9;
    C_MAX_CYCLE_CNT          : Integer := 16;
    C_ARD_DTIME_READ_ARRAY   : INTEGER_ARRAY_TYPE :=
        -- Type, Latency, Wait-States
        (
         0,0,0,  --CS 0 asserted
         1,1,0,  --CS 1 asserted
         1,1,1,  --CS 2 asserted
         2,1,1,  --CS 3 asserted
         1,2,4,  --CS 4 asserted
         1,1,3,  --CS 5 asserted
         2,1,0,  --CS 6 asserted
         1,0,0,  --CS 7 asserted
         1,1,1   --CS 8 asserted
        );

    C_ARD_DTIME_WRITE_ARRAY   : INTEGER_ARRAY_TYPE :=
        -- Type, Latency, Wait-States
        (
         0,0,0,  --CS 0 asserted
         0,0,0,  --CS 1 asserted
         0,0,0,  --CS 2 asserted
         0,0,0,  --CS 3 asserted
         0,0,0,  --CS 4 asserted
         0,0,0,  --CS 5 asserted
         0,0,0,  --CS 6 asserted
         0,0,0,  --CS 7 asserted
         0,0,0   --CS 8 asserted
        )
    );
  port (
    -- Input ports
    Bus_reset           : In std_logic;
    Bus_clk             : In std_logic;
    RNW                 : In std_logic;
    CS_Bus              : In std_logic_vector(0 to C_NUM_CS-1);
    Req_Init            : In std_logic;
    Req_Active          : In std_logic;
    Num_Data_Beats      : In integer range 0 to C_MAX_CYCLE_CNT;
    Target_ReqAck       : In std_logic;

    -- Output signals
    Control_Ack         : Out std_logic;
    Control_AlmostDone  : Out std_logic;
    Control_Done        : Out std_logic;
    Response_Ack        : Out std_logic;
    Response_AlmostDone : Out std_logic;
    Response_Done       : Out std_logic
    );

end entity determinate_timer;


architecture implementation of determinate_timer is

  -- functions
    -- none


  -- Constants
  Constant COUNTER_SIZE     : integer := 5;
  constant CYCLE_CNTR_SIZE  : integer := log2(C_MAX_CYCLE_CNT);
  Constant LOGIC_LOW        : std_logic := '0';
  Constant LOGIC_HIGH       : std_logic := '1';
  Constant ZERO             : integer := 0;
  Constant ONE              : integer := 1;


  Constant COUNT_ZERO     : std_logic_vector(0 to COUNTER_SIZE-1)
                            := CONV_STD_LOGIC_VECTOR(ZERO, COUNTER_SIZE);

  Constant CYCLE_CNT_ZERO : std_logic_vector(0 to CYCLE_CNTR_SIZE-1)
                            := CONV_STD_LOGIC_VECTOR(ZERO, CYCLE_CNTR_SIZE);

  Constant CYCLE_CNT_ONE  : std_logic_vector(0 to CYCLE_CNTR_SIZE-1)
                            := CONV_STD_LOGIC_VECTOR(ONE, CYCLE_CNTR_SIZE);

  Constant NUM_PARAMS_PER_BASEADDR : Integer := 3;

  -- Types



  -- Signals
   -- Control Counter
   Signal cntl_tc               : std_logic;
   Signal load_cntl_cntr        : std_logic;
   Signal cntl_cntr_load_value  : std_logic_vector(0 to COUNTER_SIZE-1);
   Signal cntl_count            : std_logic_vector(0 to COUNTER_SIZE-1);
   Signal cntl_ws_cnten         : std_logic;
   Signal cntl_cycle_count      : std_logic_vector(0 to CYCLE_CNTR_SIZE-1);
   Signal cntl_cc_load_value    : std_logic_vector(0 to CYCLE_CNTR_SIZE-1);
   Signal cntl_cc_cnten         : std_logic;
   Signal Control_Done_i        : std_logic;
   Signal Control_AlmostDone_i  : std_logic;

   -- Response Counter
   Signal resp_tc               : std_logic;
   Signal load_resp_cntr        : std_logic;
   Signal resp_cntr_load_value  : std_logic_vector(0 to COUNTER_SIZE-1);
   Signal resp_count            : std_logic_vector(0 to COUNTER_SIZE-1);
   Signal resp_ws_cnten         : std_logic;
   Signal resp_cycle_count      : std_logic_vector(0 to CYCLE_CNTR_SIZE-1);
   --Signal latency               : integer;
   Signal resp_cc_load_value    : std_logic_vector(0 to CYCLE_CNTR_SIZE-1);
   Signal resp_cc_cnten         : std_logic;
   Signal Response_Done_i       : std_logic;
   Signal Response_AlmostDone_i : std_logic;

   -- General Signals
   Signal dtime_mode_value      : integer;
   Signal latency_value         : integer;
   Signal wait_state_value      : integer;
   Signal active_cs_index       : integer range 0 to C_NUM_CS-1;
   -- Signal cs_active             : std_logic;
   Signal cs_active             : boolean;
   Signal trig_go               : std_logic;
   Signal dtime_enable          : std_logic;
   Signal cntl_done_reg         : std_logic;
   Signal resp_done_reg         : std_logic;
   Signal latency_done          : std_logic;

   Signal latency_eq_0          : std_logic;

   Signal rnw_s_h               : std_logic;


  -- Component Declarations

-------------------------------------------------------------------------------
begin --(architecture implementation)

  -- Misc assignments
     Control_Done        <= Control_Done_i;
     Control_AlmostDone  <= Control_AlmostDone_i;
     Response_Done       <= Response_Done_i;
     Response_AlmostDone <= Response_AlmostDone_i;


  -- Instantate sample and hold register for the PLB RNW

  I_RNW_S_H_REG : FDRE
    port map(
      Q  =>  rnw_s_h,
      C  =>  Bus_clk,
      CE =>  Req_Init,
      D  =>  RNW,
      R  =>  Bus_Reset
    );



  -------------------------------------------------------------
  -- Combinational Process
  --
  -- Label: GET_THE_ARD_VALUES
  --
  -- Process Description:
  -- This process extracts the timing parameters from the Generic
  -- C_ARD_DTIME_READ_ARRAY or C_ARD_DTIME_WRITE_ARRAY corresponding
  -- to the most significant active chip select bit in the CS_BUS.
  --
  -------------------------------------------------------------
  GET_THE_ARD_VALUES : process (CS_Bus,
                                --RNW,
                                rnw_s_h,
                                active_cs_index)

     --Variable cs_loop_or        : std_logic;

     Variable temp_active_index : Integer range 0 to C_NUM_CS-1 := 0;
     Variable cs_index          : Integer := 0;

     begin


       -- temp_active_index := 0;


         -- Default value
          dtime_mode_value <=  0;
          latency_value    <=  0;
          wait_state_value <=  0;
          latency_eq_0     <= '1';


       for cs_index in C_NUM_CS-1 downto 0 loop

          if (C_ARD_DTIME_READ_ARRAY(cs_index*
                                     NUM_PARAMS_PER_BASEADDR) /= 0) then

                if (CS_Bus(cs_index) = '1') then

                   --temp_active_index := cs_index;


                   --If (RNW = '1') Then    -- choose the read parameters
                   If (rnw_s_h = '1') Then    -- choose the read parameters

                      dtime_mode_value <= C_ARD_DTIME_READ_ARRAY(cs_index*
                                                         NUM_PARAMS_PER_BASEADDR);

                      if (C_ARD_DTIME_READ_ARRAY(cs_index*NUM_PARAMS_PER_BASEADDR+1) = 0) then

                         latency_eq_0   <= '1';
                         latency_value  <= 0;

                      else

                         latency_eq_0   <= '0';
                         latency_value  <= C_ARD_DTIME_READ_ARRAY(cs_index*
                                                            NUM_PARAMS_PER_BASEADDR+1)-1;

                      end if;


                      wait_state_value <= C_ARD_DTIME_READ_ARRAY(cs_index*
                                                         NUM_PARAMS_PER_BASEADDR+2);


                   else                 -- choose the write parameters

                      dtime_mode_value <= C_ARD_DTIME_WRITE_ARRAY(cs_index*
                                                         NUM_PARAMS_PER_BASEADDR);


                      if (C_ARD_DTIME_WRITE_ARRAY(cs_index*NUM_PARAMS_PER_BASEADDR+1) = 0) then

                         latency_eq_0   <= '1';
                         latency_value  <= 0;

                      else

                         latency_eq_0   <= '0';
                         latency_value  <= C_ARD_DTIME_WRITE_ARRAY(cs_index*
                                                         NUM_PARAMS_PER_BASEADDR+1)-1;

                      end if;



                      wait_state_value <= C_ARD_DTIME_WRITE_ARRAY(cs_index*
                                                         NUM_PARAMS_PER_BASEADDR+2);

                   End if;

                --    else
                --
                --       null; -- don't change value

                end if;


          End if;

       end loop;


       -- active_cs_index <=  temp_active_index;



       -- now pick out the appropriate array values for the detirminate
       -- timer parameters



          --    If (RNW = '1') Then    -- choose the read parameters
          --
          --       dtime_mode_value <= C_ARD_DTIME_READ_ARRAY(active_cs_index*
          --                                          NUM_PARAMS_PER_BASEADDR);
          --
          --       latency_value    <= C_ARD_DTIME_READ_ARRAY(active_cs_index*
          --                                          NUM_PARAMS_PER_BASEADDR+1);
          --
          --       wait_state_value <= C_ARD_DTIME_READ_ARRAY(active_cs_index*
          --                                          NUM_PARAMS_PER_BASEADDR+2);
          --
          --    else                 -- choose the write parameters
          --
          --       dtime_mode_value <= C_ARD_DTIME_WRITE_ARRAY(active_cs_index*
          --                                          NUM_PARAMS_PER_BASEADDR);
          --
          --       latency_value    <= C_ARD_DTIME_WRITE_ARRAY(active_cs_index*
          --                                          NUM_PARAMS_PER_BASEADDR+1);
          --
          --       wait_state_value <= C_ARD_DTIME_WRITE_ARRAY(active_cs_index*
          --                                          NUM_PARAMS_PER_BASEADDR+2);
          --
          --    End if;
          --



     end process GET_THE_ARD_VALUES;



   ----------------------------------------------------------------------------
   -- trigger Go Logic
   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: TRIG_GO_GEN
   --
   -- Process Description:
   -- This process generates a synchronous signal that is triggered
   -- to a high state when the first Target_ReqAck from the target
   -- is received.
   --
   -------------------------------------------------------------
   TRIG_GO_GEN : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then

           if (bus_reset = '1' or
               Req_Init = '1') then

             trig_go <= '0';

           elsif (Target_ReqAck = '1') then

             trig_go <= '1';

           else

             null;

           end if;
        else
          null;
        end if;
      end process TRIG_GO_GEN;


    dtime_enable <= trig_go and Req_Active
       When  dtime_mode_value = 2
       Else  Req_Active;


   ----------------------------------------------------------------------------
   -- Ack Mux Logic

    Control_Ack <= Target_ReqAck and
                   not(cntl_done_reg)
       When  dtime_mode_value = 0
       Else  cntl_tc and
             dtime_enable and
             not(cntl_done_reg);

    Response_Ack <= Target_ReqAck and
                    not(resp_done_reg)
       When  dtime_mode_value = 0
       Else  resp_tc and
             dtime_enable and
             not(resp_done_reg) and
             latency_done;




   ----------------------------------------------------------------------------
   -- Response Counter Logic

   load_resp_cntr   <= Req_Init or resp_tc;


   --    latency <=  0
   --      When latency_value = 0
   --      Else latency_value - 1;

   -- simple mux between wait-state and latency value loads
   --resp_cntr_load_value <= CONV_STD_LOGIC_VECTOR(latency, COUNTER_SIZE)
   resp_cntr_load_value <= CONV_STD_LOGIC_VECTOR(latency_value, COUNTER_SIZE)
     when (Req_Init = '1')
     else CONV_STD_LOGIC_VECTOR(wait_state_value, COUNTER_SIZE);

   resp_tc <= dtime_enable
     When resp_count = COUNT_ZERO
     Else '0';

   resp_ws_cnten <= dtime_enable and not(resp_done_reg);


   RESPONSE_CNTR_I :  entity plb_ipif_v1_00_d.pf_counter_top
      generic map(
        C_COUNT_WIDTH => COUNTER_SIZE
        )
      port map(
        Clk           =>  Bus_clk,               -- : in  std_logic;
        Rst           =>  Bus_reset,             -- : in  std_logic;
        Load_Enable   =>  load_resp_cntr,        -- : in  std_logic;
        Load_value    =>  resp_cntr_load_value,  -- : in  std_logic_vector(0 to C_COUNT_WIDTH-1);
        Count_Down    =>  resp_ws_cnten,         -- : in  std_logic;
        Count_Up      =>  LOGIC_LOW,             -- : in  std_logic;
        Count_Out     =>  resp_count             -- : out std_logic_vector(0 to C_COUNT_WIDTH-1)
        );


   --resp_cc_load_value <=  CONV_STD_LOGIC_VECTOR(Num_Data_Beats-1, CYCLE_CNTR_SIZE);
   resp_cc_load_value <=  CONV_STD_LOGIC_VECTOR(Num_Data_Beats, CYCLE_CNTR_SIZE);



   resp_cc_cnten <= Target_ReqAck and
                    not(Response_Done_i)
      When  dtime_mode_value = 0
      Else  resp_tc and
            dtime_enable and
            not(Response_Done_i) and
            latency_done;



   RESPONSE_CYCLE_CNTR_I :  entity plb_ipif_v1_00_d.pf_counter_top
      generic map(
        C_COUNT_WIDTH => CYCLE_CNTR_SIZE
        )
      port map(
        Clk           =>  Bus_clk,              -- : in  std_logic;
        Rst           =>  Bus_reset,            -- : in  std_logic;
        Load_Enable   =>  Req_Init,          -- : in  std_logic;
        Load_value    =>  resp_cc_load_value,   -- : in  std_logic_vector(0 to C_COUNT_WIDTH-1);
        Count_Down    =>  resp_cc_cnten,              -- : in  std_logic;
        Count_Up      =>  LOGIC_LOW,            -- : in  std_logic;
        Count_Out     =>  resp_cycle_count      -- : out std_logic_vector(0 to C_COUNT_WIDTH-1)
        );


   Response_Done_i <= latency_done
      When  (resp_cycle_count = CYCLE_CNT_ZERO and
             dtime_enable = '1')
      Else '0';

   Response_AlmostDone_i <= latency_done
      When  (resp_cycle_count = CYCLE_CNT_ONE and
             dtime_enable = '1')
      Else '0';


   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: REG_RESP_DONE_STATUS
   --
   -- Process Description:
   -- This process registers the response cycle done signal
   --
   -------------------------------------------------------------
   REG_RESP_DONE_STATUS : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           if (bus_reset = '1' or
               Req_Init = '1' or
               dtime_enable = '0') then

             resp_done_reg <= '0';

           Elsif (dtime_mode_value = 0) Then

              resp_done_reg <= Response_Done_i and Target_ReqAck;

           elsif (resp_tc = '1' and
                  dtime_enable = '1' and
                  latency_done = '1') then

              resp_done_reg <= Response_Done_i;

           else

             null;  -- don't change state

           end if;
        else
          null;
        end if;
      end process REG_RESP_DONE_STATUS;

   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: LATENCY_DONE_STATUS
   --
   -- Process Description:
   -- This process registers the the fact that the latency
   -- count has completed.
   --
   -------------------------------------------------------------
   LATENCY_DONE_STATUS : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           if (bus_reset = '1') then

             latency_done <= '0';


           Elsif (Req_Init = '1' and
                  --latency_value > 0) Then
                  latency_eq_0 = '0') Then

              latency_done <= '0';

           Elsif (Req_Init = '1' and
                  --latency_value = 0) Then
                  latency_eq_0 = '1') Then

              latency_done <= '1';

           -- Elsif (dtime_enable = '1' and
           --        latency_value = 1) Then
           --
           --    latency_done <= '1';

           elsif (resp_tc = '1' and
                  dtime_enable = '1') then

              latency_done <= '1';

           else

             null;  -- don't change state

           end if;
        else
          null;
        end if;
      end process LATENCY_DONE_STATUS;

   ----------------------------------------------------------------------------
   -- Control Counter Logic

   load_cntl_cntr   <= Req_Init or cntl_tc;


   cntl_cntr_load_value <= CONV_STD_LOGIC_VECTOR(wait_state_value, COUNTER_SIZE);



   cntl_tc <= '1'
     When cntl_count = COUNT_ZERO
     Else '0';


   cntl_ws_cnten <= dtime_enable and not(cntl_done_reg);

   CONTROL_CNTR_I :  entity plb_ipif_v1_00_d.pf_counter_top
      generic map(
        C_COUNT_WIDTH => COUNTER_SIZE
        )
      port map(
        Clk           =>  Bus_clk,              -- : in  std_logic;
        Rst           =>  Bus_reset,            -- : in  std_logic;
        Load_Enable   =>  load_cntl_cntr,       -- : in  std_logic;
        Load_value    =>  cntl_cntr_load_value, -- : in  std_logic_vector(0 to C_COUNT_WIDTH-1);
        Count_Down    =>  cntl_ws_cnten,        -- : in  std_logic;
        Count_Up      =>  LOGIC_LOW,            -- : in  std_logic;
        Count_Out     =>  cntl_count            -- : out std_logic_vector(0 to C_COUNT_WIDTH-1)
        );


   --cntl_cc_load_value <=  CONV_STD_LOGIC_VECTOR(Num_Data_Beats-1, CYCLE_CNTR_SIZE);
   cntl_cc_load_value <=  CONV_STD_LOGIC_VECTOR(Num_Data_Beats, CYCLE_CNTR_SIZE);


   cntl_cc_cnten    <= Target_ReqAck and
                       not(Control_Done_i)
       When  dtime_mode_value = 0
       Else  cntl_tc and
             dtime_enable and
             not(Control_Done_i);


   CONTROL_CYCLE_CNTR_I :  entity plb_ipif_v1_00_d.pf_counter_top
      generic map(
        C_COUNT_WIDTH => CYCLE_CNTR_SIZE
        )
      port map(
        Clk           =>  Bus_clk,              -- : in  std_logic;
        Rst           =>  Bus_reset,            -- : in  std_logic;
        Load_Enable   =>  Req_Init,             -- : in  std_logic;
        Load_value    =>  cntl_cc_load_value,   -- : in  std_logic_vector(0 to C_COUNT_WIDTH-1);
        Count_Down    =>  cntl_cc_cnten,        -- : in  std_logic;
        Count_Up      =>  LOGIC_LOW,            -- : in  std_logic;
        Count_Out     =>  cntl_cycle_count      -- : out std_logic_vector(0 to C_COUNT_WIDTH-1)
        );


   Control_Done_i <= '1'
      When  (cntl_cycle_count = CYCLE_CNT_ZERO and
             dtime_enable = '1')
      Else '0';

   Control_AlmostDone_i <= '1'
      When  (cntl_cycle_count = CYCLE_CNT_ONE and
             dtime_enable = '1')
      Else '0';

   -------------------------------------------------------------
   -- Synchronous Process
   --
   -- Label: REG_CNTL_DONE_STATUS
   --
   -- Process Description:
   -- This process registers the control cycle done signal
   --
   -------------------------------------------------------------
   REG_CNTL_DONE_STATUS : process (bus_clk)
      begin
        if (bus_clk'event and bus_clk = '1') then
           if (bus_reset = '1' or
               Req_Init = '1' or
               dtime_enable = '0') then

             cntl_done_reg <= '0';

           Elsif (dtime_mode_value = 0) Then

              cntl_done_reg <= Control_Done_i and Target_ReqAck;

           elsif (cntl_tc = '1' and
                  dtime_enable = '1') then

              cntl_done_reg <= Control_Done_i;

           else
             null;  -- don't change state
           end if;
        else
          null;
        end if;
      end process REG_CNTL_DONE_STATUS;


end implementation;
