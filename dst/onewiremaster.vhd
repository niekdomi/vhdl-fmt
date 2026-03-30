----------------------------------------------------------------------------
--                                                                        --
--  OneWireMaster                                                         --
--   A synthesizable 1-wire master peripheral                             --
--   Copyright 1999-2012 Maxim Integrated Products                        --
--                                                                        --
----------------------------------------------------------------------------
--                                                                        --
--  Purpose:  Provides timing and control of Dallas 1-wire bus            --
--            through a memory-mapped peripheral                          --
--  File:     onewiremaster.vhd                                           --
--  Date:     September 26, 2012                                           --
--  Version:  v2.41                                                       --
--  Authors:  Eric Hereford,                                              --
--            Dallas Semiconductor Corporation                            --
--                                                                        --
--  Note:     This source code is available for use without license.      --
--            Dallas Semiconductor is not responsible for the             --
--            functionality or utility of this product.                   --
--                                                                        --
--  REV:      Initial port based on v2.200 Verilog - EAH                  --
--                                                                        --
--            v1.2 - Jan 28, 2007                                         --
--            Changd value of bit_ts_end_od from 9 to 10 - EAH            --
--            v2.4 Added risetime delay for tPDH pulse   - SWM            --
--            v2.41 Changed recovery time to be 6us      - SWM            --
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity onewiremaster is
    port(
      BIT_CTL                  : in std_logic;
      clk_1us                  : in std_logic;
      clr_activate_intr        : in std_logic;
      DQ_IN                    : in std_logic;
      EN_FOW                   : in std_logic;
      EOWL                     : in std_logic;
      EOWSH                    : in std_logic;
      epd                      : in std_logic;
      erbf                     : in std_logic;
      ersf                     : in std_logic;
      etbe                     : in std_logic;
      etmt                     : in std_logic;
      FOW                      : in std_logic;
      ias                      : in std_logic;
      LLM                      : in std_logic;
      MR                       : in std_logic;
      OD                       : in std_logic;
      owr                      : in std_logic;
      pd                       : in std_logic;
      PPM                      : in std_logic;
      rbf_reset                : in std_logic;
      sr_a                     : in std_logic;
      STP_SPLY                 : in std_logic;
      STPEN                    : in std_logic;
      tbe                      : in std_logic;
      xmit_buffer              : in std_logic_vector (7 downto 0);
      clear_interrupts         : out std_logic;
      DQ_CONTROL               : out std_logic;
      FSM_CLK                  : out std_logic;
      INTR                     : out std_logic;
      OneWireIO_eq_Load        : out std_logic;
      OW_LOW                   : out std_logic;
      OW_SHORT                 : out std_logic;
      pdr                      : out std_logic;
      rbf                      : out std_logic;
      rcvr_buffer              : out std_logic_vector (7 downto 0);
      reset_owr                : out std_logic;
      rsrf                     : out std_logic;
      STPZ                     : out std_logic;
      temt                     : out std_logic);
end entity onewiremaster;



architecture rtl_onewiremaster of onewiremaster is

   --
   -- Define the states
   --
   constant Idle       : std_logic_vector(2 DOWNTO 0) := b"000"; -- Idle
   constant CheckOWR   : std_logic_vector(2 DOWNTO 0) := b"001"; -- Check for shorted OW
   constant Reset_Low  : std_logic_vector(2 DOWNTO 0) := b"010"; -- Start reset
   constant PD_Wait    : std_logic_vector(2 DOWNTO 0) := b"011"; -- release line for 1T
   constant PD_Sample  : std_logic_vector(2 DOWNTO 0) := b"100"; -- sample line after slowest 1T over
   constant Reset_High : std_logic_vector(2 DOWNTO 0) := b"101"; -- recover OW line leve
   constant PD_Force   : std_logic_vector(2 DOWNTO 0) := b"110"; -- mask the presence pulse
   constant PD_Release : std_logic_vector(2 DOWNTO 0) := b"111"; -- recover OW line level

   constant IdleS      : std_logic_vector(4 DOWNTO 0) := b"0_0000"; -- Idle stat
   constant Load       : std_logic_vector(4 DOWNTO 0) := b"0_0001"; -- Load byte
   constant CheckOW    : std_logic_vector(4 DOWNTO 0) := b"0_0010"; -- Check for shorted line
   constant DQLOW      : std_logic_vector(4 DOWNTO 0) := b"0_0011"; -- Start of timeslot
   constant WriteZero  : std_logic_vector(4 DOWNTO 0) := b"0_0100"; -- Write a zero to the 1-wire
   constant WriteOne   : std_logic_vector(4 DOWNTO 0) := b"0_0101"; -- Wrte a one to the 1-wire
   constant ReadBit    : std_logic_vector(4 DOWNTO 0) := b"0_0110"; -- Search Rom Accelerator read bit
   constant FirstPassSR: std_logic_vector(4 DOWNTO 0) := b"0_0111"; -- Used by SRA
   constant WriteBitSR : std_logic_vector(4 DOWNTO 0) := b"0_1000"; -- Decide what bit value to write in SRA
   constant WriteBit   : std_logic_vector(4 DOWNTO 0) := b"0_1001"; -- Writes the chosen bit in SRA
   constant WaitTS     : std_logic_vector(4 DOWNTO 0) := b"0_1010"; -- Wait for end of time slot
   constant IndexInc   : std_logic_vector(4 DOWNTO 0) := b"0_1011"; -- Increments bit index
   constant UpdateBuff : std_logic_vector(4 DOWNTO 0) := b"0_1100"; -- Updates states of rbf
   constant ODWriteZero: std_logic_vector(4 DOWNTO 0) := b"0_1101"; -- Write a zero @ OD speed to OW
   constant ODWriteOne : std_logic_vector(4 DOWNTO 0) := b"0_1110"; -- Write a one @ OD speed to OW
   constant ClrLowDone : std_logic_vector(4 DOWNTO 0) := b"0_1111"; -- disable stupz before pulldown
   

   -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   -- micro-second count for bit transitions and sample
   -- Standard Speed
   constant bit_ts_writeone_high      : std_logic_vector(6 DOWNTO 0) := b"000_0110"; -- release-1  @6 us
   constant bit_ts_writeone_high_ll   : std_logic_vector(6 DOWNTO 0) := b"000_1000"; -- rel-1-LLM  @8 us
   constant bit_ts_sample             : std_logic_vector(6 DOWNTO 0) := b"000_1111"; -- sample     @15 us
   constant bit_ts_sample_ll          : std_logic_vector(6 DOWNTO 0) := b"001_1000"; -- sample/llm @24 us
   constant bit_ts_writezero_high     : std_logic_vector(6 DOWNTO 0) := b"011_1100"; -- release-0  @60 us
   constant bit_ts_end                : std_logic_vector(6 DOWNTO 0) := b"100_0110"; -- end        @70 us
   constant bit_ts_end_ll             : std_logic_vector(6 DOWNTO 0) := b"101_0000"; -- end        @80 us
   -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   -- Overdrive speed
   -- note that due to the state machine architecture, the
   -- writeone_high_od and sample_od must be 1 and 2 us.
   -- writezero_high_od and end_od are adjustable, so long
   -- as writezero_high_od does not exceed a particular
   -- 1-Wire device max low time.
   constant bit_ts_writeone_high_od   : std_logic_vector(6 DOWNTO 0) := b"000_0001"; -- release-1 @1 us
   constant bit_ts_sample_od          : std_logic_vector(6 DOWNTO 0) := b"000_0010"; -- sample    @2 us
   constant bit_ts_writezero_high_od  : std_logic_vector(6 DOWNTO 0) := b"000_1000"; -- release-0 @8 us
   constant bit_ts_end_od             : std_logic_vector(6 DOWNTO 0) := b"000_1100"; -- end       @12 us -- Changed to have 6us recovery time
   -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   -- micro-second count for reset transitions
   -- Standard Speed
   constant reset_ts_release          : std_logic_vector(10 DOWNTO 0) := b"010_0101_1000"; -- release @600 us
   constant reset_ts_pdhcnt           : std_logic_vector(10 DOWNTO 0) := b"000_0000_1001"; -- pdhcnt  @9 us
   constant reset_ts_no_stpz          : std_logic_vector(10 DOWNTO 0) := b"010_0110_0010"; -- stpz=1  @610 us
   constant reset_ts_ppm              : std_logic_vector(10 DOWNTO 0) := b"010_0110_1100"; -- pp-mask @620 us
   constant reset_ts_sample           : std_logic_vector(10 DOWNTO 0) := b"010_1001_1110"; -- sample  @670 us
   constant reset_ts_llsample         : std_logic_vector(10 DOWNTO 0) := b"010_1010_1101"; -- sample  @685 us
   constant reset_ts_ppm_end          : std_logic_vector(10 DOWNTO 0) := b"010_1011_0010"; -- ppm-end @690 us
   constant reset_ts_stpz             : std_logic_vector(10 DOWNTO 0) := b"011_1011_0110"; -- stpz    @950 us
   constant reset_ts_recover          : std_logic_vector(10 DOWNTO 0) := b"011_1100_0000"; -- recover @960 us
   constant reset_ts_end              : std_logic_vector(10 DOWNTO 0) := b"100_0011_1000"; -- end     @1080 us
   -- Overdrive Speed
   constant reset_ts_release_od       : std_logic_vector(10 DOWNTO 0) := b"000_0100_0110"; -- release @70 us
   constant reset_ts_pdhcnt_od        : std_logic_vector(10 DOWNTO 0) := b"000_0000_0001"; -- pdhcnt  @1 us
   constant reset_ts_no_stpz_od       : std_logic_vector(10 DOWNTO 0) := b"000_0100_1011"; -- stpz=1  @75 us
   constant reset_ts_sample_od        : std_logic_vector(10 DOWNTO 0) := b"000_0100_1111"; -- sample  @79 us
   constant reset_ts_stpz_od          : std_logic_vector(10 DOWNTO 0) := b"000_0110_1001"; -- stpz    @105 us
   constant reset_ts_recover_od       : std_logic_vector(10 DOWNTO 0) := b"000_0111_0011"; -- recover @115 us
   constant reset_ts_end_od           : std_logic_vector(10 DOWNTO 0) := b"000_1000_0000"; -- end     @128 us
   
   constant s0                        : std_logic_vector(3 DOWNTO 0) := b"0000";
   constant s1                        : std_logic_vector(3 DOWNTO 0) := b"0001";
   constant s2                        : std_logic_vector(3 DOWNTO 0) := b"0010";
   constant s3                        : std_logic_vector(3 DOWNTO 0) := b"0011";
   constant s4                        : std_logic_vector(3 DOWNTO 0) := b"0100";
   constant s5                        : std_logic_vector(3 DOWNTO 0) := b"0101";
   constant s6                        : std_logic_vector(3 DOWNTO 0) := b"0110";
   constant s7                        : std_logic_vector(3 DOWNTO 0) := b"0111";
   
   -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   
   -- Internal Signals
   signal temt_ext                  : std_logic; -- temt extended flag
   signal set_rbf                   : std_logic; -- set signal for rbf
   signal activate_intr             : std_logic;
   signal dly_clr_activate_intr     : std_logic;
   signal SET_RSHRT                 : std_logic; -- set ow_short prior to ow reset
   signal SET_IOSHRT                : std_logic;     -- set ow_short prior to tx a bit
   signal xmit_shiftreg             : std_logic_vector(7 downto 0);  -- transmit shift register
   signal rcvr_shiftreg             : std_logic_vector(7 downto 0);  -- receive shift register
   signal last_rcvr_bit             : std_logic; -- active on index = 7 to begin shift to rbe
   signal byte_done                 : std_logic;
   signal byte_done_flag            : std_logic; -- signal to stretch byte_done
   signal bdext1                    : std_logic; -- signal to stretch byte_done
   signal First                     : std_logic; -- for Search ROM accelerator
   signal BitRead1                  : std_logic;
   signal BitRead2                  : std_logic;
   signal BitWrite                  : std_logic;
   signal OneWireReset              : std_logic_vector(2 downto 0);
   signal OneWireIO                 : std_logic_vector(4 downto 0);
   signal count                     : std_logic_vector(10 downto 0);
   signal index                     : std_logic_vector(3 downto 0);
   signal TimeSlotCnt               : std_logic_vector(6 downto 0);
   signal PD_READ                   : std_logic;
   signal LOW_DONE                  : std_logic;
   signal DQ_CONTROL_F              : std_logic;
   signal DQ_IN_HIGH                : std_logic;
   signal OD_DQH                    : std_logic;
	signal rbf_set                   : std_logic;
	signal rsrf_reset                : std_logic;
   signal ROW                       : std_logic;
   signal SPLY                      : std_logic;
   signal acint_reset               : std_logic;
   signal activate_intr_concat_ias  : std_logic_vector(1 downto 0);
   signal BitRead1_concat_BitRead2  : std_logic_vector(1 downto 0);

  -- VHDL does not allow Outputs to be used within the architecture,
  -- therefore internal signals were created to maintain consistency
  -- with Verilog code version  
  signal FSM_CLK_int                : std_logic;
  signal DQ_CONTROL_int             : std_logic;
  signal rsrf_int                   : std_logic;
  signal rbf_int                    : std_logic;
  signal OW_SHORT_int               : std_logic;
  signal OW_LOW_int                 : std_logic;
  signal temt_int                   : std_logic;

    begin

     FSM_CLK <= FSM_CLK_int;
     DQ_CONTROL <= DQ_CONTROL_int;
     rsrf <= rsrf_int;
     rbf <= rbf_int;
     OW_SHORT <= OW_SHORT_int;
     OW_LOW <= OW_LOW_int;
     temt <= temt_int;
     activate_intr_concat_ias <= (activate_intr & ias);
     BitRead1_concat_BitRead2 <= (BitRead1 & BitRead2);
     
     -- Continuous assignments
     FSM_CLK_int <= clk_1us;
     DQ_CONTROL_int <= '1' when (MR = '1') else DQ_CONTROL_F;
     OneWireIO_eq_Load <= '1' when (OneWireIO = Load) else '0';
     SPLY <= '1' when ((STP_SPLY='1' and (OneWireReset=Idle)) and (OneWireIO=IdleS)) else '0';
     STPZ <= '0' when ((STPEN and DQ_CONTROL_int and 
                      ((DQ_IN_HIGH and STP_SPLY and (PD_READ or LOW_DONE or SPLY)) or 
                       (DQ_IN_HIGH and (not STP_SPLY) and (PD_READ or LOW_DONE))))='1') else '1';
     acint_reset <= '1' when (MR='1' or clr_activate_intr='1') else '0';
     temt_ext <= '1' when ((temt_int and byte_done_flag)='1') else '0';
     
     --
     --  1 wire control
     --
     process(FSM_CLK_int)
       begin
         if (FSM_CLK_int='1' and FSM_CLK_int'event) then
            if(EN_FOW='1' and FOW='1') then
              DQ_CONTROL_F <= '0';
            elsif(OneWireReset = Reset_Low) then
              DQ_CONTROL_F <= '0';
            elsif(OneWireReset = PD_Wait) then
              DQ_CONTROL_F <= '1';
            elsif(OneWireReset = PD_Force) then
              DQ_CONTROL_F <= '0';
            elsif(OneWireIO = DQLOW) then
              DQ_CONTROL_F <= '0';
            elsif(OneWireIO = WriteZero) then
              DQ_CONTROL_F <= '0';
            elsif(OneWireIO = ODWriteZero) then
              DQ_CONTROL_F <= '0';
            elsif(OneWireIO = WriteBit) then
              DQ_CONTROL_F <= '0';  
            else
              DQ_CONTROL_F <= '1';
            end if;    
         end if;
     end process;
       

     --
     -- Strong Pullup control section - GAG
     -- not pulling line low, not checking for pres detect, and
     -- OW has recovered from read
     -- SPLY is only for enabling STP when a slave requires high current
     --   and STP_SPLY is enabled
     --
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           DQ_IN_HIGH <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if((DQ_IN='1' or DQ_IN='H') and ((not DQ_IN_HIGH)='1')) then -- EAH
             DQ_IN_HIGH <= '1';    
           elsif((DQ_IN='1' or DQ_IN='H') and (DQ_IN_HIGH='1')) then -- EAH
             DQ_IN_HIGH <= DQ_IN_HIGH;
           else
             DQ_IN_HIGH <= '0';
           end if;
         end if;    
     end process;

     --
     -- Update receive buffer and the rsrf_int and rbf_int int flags
     --
     process(MR, rbf_reset, rbf_set)
       begin
         if (MR='1') then
           rbf_int <= '0';      
         elsif (rbf_reset='1') then
           rbf_int <= '0';    
         elsif (rbf_set='1' and rbf_set'event) then
           rbf_int <= '1';    
         end if;
     end process;
     
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           rsrf_int <= '0';    
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if((last_rcvr_bit or BIT_CTL)='1') then
             if(OneWireIO = IndexInc) then
               rsrf_int <= '1';
             elsif (rsrf_reset = '1') then
               rsrf_int <= '0';
             end if;    
           elsif(rsrf_reset='1' or (OneWireIO=DQLOW)) then
             rsrf_int <= '0';    
           end if;
         end if;
     end process;

     process(FSM_CLK_int, MR)
       begin
         if (MR='1') then
           rcvr_buffer <= x"00";
           rbf_set <= '0';    
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if((rsrf_int and (not rbf_int))='1') then
             rcvr_buffer <= rcvr_shiftreg;
             rbf_set <= '1';
             rsrf_reset <= '1';
           else
             rbf_set <= '0';
             if(((not rsrf_int))='1') then
               rsrf_reset <= '0';
             end if;
           end if;        
         end if;
     end process;
     
     --
     -- Update OW shorted interrupt
     --
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           OW_SHORT_int <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if((SET_RSHRT or SET_IOSHRT) = '1') then
             OW_SHORT_int <= '1';
           elsif(clr_activate_intr = '1') then
             OW_SHORT_int <= '0';
           else
             OW_SHORT_int <= OW_SHORT_int;
           end if;    
         end if;    
     end process;

     --
     -- Update OW bus low interrupt
     --
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           OW_LOW_int <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if((DQ_IN='0') and (OneWireReset=Idle) and (OneWireIO=IdleS)) then
             OW_LOW_int <= '1';    
           elsif(clr_activate_intr='1') then
             OW_LOW_int <= '0';   
           else
             OW_LOW_int <= OW_LOW_int;
           end if;
         end if;    
     end process;

       
     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --/
     -- The following section handles the interrupt itself
     --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --/

     --
     -- Create clear interrupts
     --
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           clear_interrupts <= '0';      
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           clear_interrupts <= clr_activate_intr;    
         end if;           
     end process;
     
     --
     -- Check for active interrupt
     --
     process(acint_reset, FSM_CLK_int)
       begin
         if (acint_reset='1') then
           activate_intr <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if((pd and epd)='1') then
             activate_intr <= '1';
           elsif ((tbe and etbe and (not temt_int))='1') then
             activate_intr <= '1';  
           elsif ((temt_ext and etmt)='1') then
             activate_intr <= '1';  
           elsif ((rbf_int and erbf)='1') then
             activate_intr <= '1';  
           elsif ((rsrf_int and ersf)='1') then
             activate_intr <= '1';  
           elsif ((OW_LOW_int and EOWL)='1') then
             activate_intr <= '1';  
           elsif ((OW_SHORT_int and EOWSH)='1') then
             activate_intr <= '1';  
           end if;
         end if;    
     end process;

     --
     -- Create INTR signal by checking for active interrupt and active
     -- state of INTR
     --
     INTR <= '1' when (activate_intr='1' and ias='1') else
             '0' when (activate_intr='0' and ias='1') else
             '0' when (activate_intr='1' and ias='0') else '1'; -- EAH - DOES NOT MATCH CURRENT VERILOG VERSION!!!

     ----------------------------------------------------------------------------
     --
     --  OneWireReset
     --
     --  this state machine performs the 1-wire reset and presence detect
     --  - Added OD for overdrive speed presence detect
     --  - Added PD_LOW bit for strong pullup control
     --
     --  Idle       : OW high - waiting to issue a PD
     --  CheckOWR   : OW high - checks for shorted OW line
     --  Reset_Low  : OW low - held down for GT8 OW osc periods
     --  PD_Wait    : OW high - released and waits for 1T
     --  PD_Sample  : OW high - checks to see if a slave is out there pulling
     --                         OW low for 4T
     --  Reset_High : OW high - slave, if any, release OW and host lets it recover
     ----------------------------------------------------------------------------
     process(FSM_CLK_int, MR)
       begin
         if (MR='1') then
           pdr <= '1';        -- Added default state to conform to spec - SDS
           OneWireReset <= Idle;
           count <= b"000_0000_0000";
           PD_READ <= '0';       -- Added PD_READ - GAG
           reset_owr <= '0';
           SET_RSHRT <= '0';
			  ROW <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           if(( not owr)='1') then
             count <= b"000_0000_0000";
             ROW <= '0';
             reset_owr <= '0';
             OneWireReset <= Idle;    
           else
             case (OneWireReset) is
               when Idle =>
                 if(ROW='1') then
                   reset_owr <= '1';
                 else
                   count <= b"000_0000_0000";
                   SET_RSHRT <= '0';
                   reset_owr <= '0';
                   OneWireReset <= CheckOWR;
                 end if;
                 
               when CheckOWR =>
                 OneWireReset <= Reset_Low;
                 if(DQ_IN='0') then
                   SET_RSHRT <= '1';
                 end if; 
               
               when Reset_Low =>
                 count <= count + b"000_0000_0001";
                 PD_READ <= '0';    
                 if(OD='1') then
                   if(count = reset_ts_release_od) then
                     OneWireReset <= PD_Wait;
                     PD_READ <= '1';
                   end if;    
                 elsif(count = reset_ts_release) then
                   OneWireReset <= PD_Wait;
                   PD_READ <= '1';                   
                 end if;  
 
               --  This PD_Wait state adjusts for the needed risetime of tPDH --SWM             
	       when PD_Wait =>
	         SET_RSHRT <= '0';
		 count <= count + b"000_0000_0001";
		 if(OD='1') then -- Overdrive mode
		   if((DQ_IN='0') and (DQ_CONTROL_F='1') and (count > reset_ts_release_od + reset_ts_pdhcnt_od)) then
		     OneWireReset <= PD_Sample;
		   elsif(count=reset_ts_no_stpz_od) then
		     PD_READ <= '0';
		   elsif(count=reset_ts_sample_od) then
		     OneWireReset <= PD_Sample;
		   end if;
		 else -- Standard mode
		   if((DQ_IN='0') and (DQ_CONTROL_F='1') and (count > reset_ts_release + reset_ts_pdhcnt)) then
		     OneWireReset <= PD_Sample;
		   elsif(count=reset_ts_no_stpz) then
		     PD_READ <= '0';
		   elsif((count=reset_ts_ppm) and (PPM='1')) then
		     OneWireReset <= PD_Force;  
		   elsif((count=reset_ts_llsample) and ((not LLM)='1')) then
		     OneWireReset <= PD_Sample;
		   elsif((count=reset_ts_sample) and (LLM='1')) then
		     OneWireReset <= PD_Sample;
		   end if;
		 end if;
	       
	       -- This PD_Wait State contained no time for the risetime of tPDH  --SWM
               -- when PD_Wait =>
               --  SET_RSHRT <= '0';
               -- count <= count + b"000_0000_0001";
               --  if((DQ_IN='0') and (DQ_CONTROL_F='1')) then
               --    OneWireReset <= PD_Sample;
               --  elsif (OD='1') then
               --    if(count=reset_ts_no_stpz_od) then
               --      PD_READ <= '0';
               --    elsif(count=reset_ts_sample_od) then
               --      OneWireReset <= PD_Sample;    
               --    end if;
               --  elsif(count=reset_ts_no_stpz) then
               --    PD_READ <= '0';
               --  elsif((count=reset_ts_ppm) and PPM='1') then
               --    OneWireReset <= PD_Force;
               --  elsif((count=reset_ts_llsample) and ((not LLM)='1')) then 
               --    OneWireReset <= PD_Sample;
               --  elsif((count=reset_ts_sample) and (LLM='1')) then
               --    OneWireReset <= PD_Sample;   
               --  end if;
               --
	       
               when PD_Sample =>
                 PD_READ <= '0';
                 count <= count + b"000_0000_0001";
                 if(DQ_IN='1' or DQ_IN='H') then
                   pdr <= '1';    
                 else
                   pdr <= '0';    
                 end if;
                 OneWireReset <= Reset_High;
               
               when Reset_High =>
                 count <= count + b"000_0000_0001";
                 if(OD='1') then
                   if(count=reset_ts_stpz_od) then
                     if(DQ_IN='1' or DQ_IN='H') then
                       PD_READ <= '1';    
                     end if;
                   elsif(count=reset_ts_recover_od) then
                     PD_READ <= '0';
                   elsif(count=reset_ts_end_od) then
                     PD_READ <= '0';
                     OneWireReset <= Idle;
                     ROW <= '1';
                   end if;    
                 else
                   if(count=reset_ts_stpz) then
                     if((DQ_IN='1' or DQ_IN='H')) then
                       PD_READ <= '1';
                     end if;    
                   elsif(count=reset_ts_recover) then
                     PD_READ <= '0';    
                   elsif(count=reset_ts_end) then
                     PD_READ <= '0';
                     OneWireReset <= Idle;
                     ROW <= '1';    
                   end if;
                 end if;
               
               when PD_Force =>
                 count <= count + b"000_0000_0001";
                 if(count=reset_ts_ppm_end) then
                   OneWireReset <= PD_Release;    
                 end if;
               
               when PD_Release =>
                 count <= count + b"000_0000_0001";
                 pdr <= '0';
                 if(count=reset_ts_stpz) then
                   if((DQ_IN='1' or DQ_IN='H')) then
                     PD_READ <= '1';
                   end if;    
                 elsif(count=reset_ts_recover) then
                   PD_READ <= '0';    
                 elsif(count=reset_ts_end) then
                   PD_READ <= '0';
                   OneWireReset <= Idle;
                   ROW <= '1';    
                 end if;
               
               when others =>
                 OneWireReset <= Idle;   
             end case;
           end if;
         end if;    
     end process;


     ----------------------------------------------------------------------------
     --
     --  OneWireIO
     --
     --  this state machine performs the 1-wire writing and reading
     --  - Added ODWriteZero and ODWriteOne for overdrive timing
     --
     --  IdleS       : Waiting for transmit byte to be loaded
     --  ClrLowDone  : Disables strong pullup before pulldown turns on
     --  Load        : Loads byte to shift reg
     --  CheckOW     : Checks for OW short
     --  DQLOW       : Starts time slot with OW = 0
     --  ODWriteZero : Completes write of 0 bit / read bit in OD speed
     --  ODWriteOne  : Completes write of 1 bit / read bit in OD speed
     --  WriteZero   : Completes write of 0 bit / read bit in standard speed
     --  WriteOne    : Completes write of 1 bit / read bit in standard speed
     --  ReadBit     : AutoSearchRom : Reads the first bit value
     --  FirstPassSR : AutoSearchRom : Decides to do another read or the write
     --  WriteBitSR  : AutoSearchRom : Determines the bit to write
     --  WriteBit    : AutoSearchRom : Writes the bit
     --  WatiTS      : Allows OW to recover for the remainder of the time slot
     --  IndexInc    : Increment the index to send out next bit (in byte)
     --  UpdateBuff  : Allows other signals to update following finished byte/bit
     ----------------------------------------------------------------------------

     -- The following 2 registers are to stretch the temt_int signal to catch the
     -- temt_int interrupt source - SDS

     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           bdext1 <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           bdext1 <= byte_done;
         end if;    
     end process;
     
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           byte_done_flag <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           byte_done_flag <= bdext1;
         end if;    
     end process;

     
     -- The index variable has been decoded explicitly in this state machine
     -- so that the code would compile on the Cypress warp compiler - SDS
     process(MR, FSM_CLK_int)
       begin
         if (MR='1') then
           index <= b"0000";
           TimeSlotCnt <= b"000_0000";
           temt_int <= '1';
           last_rcvr_bit <= '0';
           rcvr_shiftreg <= b"0000_0000";
           OneWireIO <= IdleS;
           BitRead1 <= '0';
           BitRead2 <= '0';
           BitWrite <= '0';
           First <= '0';
           byte_done <= '0';
           xmit_shiftreg <= b"0000_0000";
           LOW_DONE <= '0';
           SET_IOSHRT <= '0';
         elsif (FSM_CLK_int='1' and FSM_CLK_int'event) then
           case (OneWireIO) is
               
             -- IdleS state clears variables and waits for something to be
             -- deposited in the transmit buffer. When something is there,
             -- the next state is Load.
             when IdleS =>
               byte_done <= '0';
               index <= b"0000";
               last_rcvr_bit <= '0';
               First <= '0';
               TimeSlotCnt <= b"000_0000";
               LOW_DONE <= '0';
               SET_IOSHRT <= '0';
               temt_int <= '1';
               if((not tbe)='1') then
                 if(STPEN='1') then
                   OneWireIO <= ClrLowDone;
                 else
                   OneWireIO <= Load;
                 end if;    
               else
                 OneWireIO <= IdleS;    
               end if;
             
             -- New state added to be sure the strong pullup will be disabled
             -- before the OW pulldown turns on
             when ClrLowDone =>
               LOW_DONE <= '0';
               if(LOW_DONE='0') then
                 OneWireIO <= Load;    
               end if;
                 
             -- Load transfers the transmit buffer to the transmit shift register,
             -- then clears the transmit shift register empty interrupt. The next
             -- state is then DQLOW.
             when Load =>
               xmit_shiftreg <= xmit_buffer;
               rcvr_shiftreg <= b"0000_0000";
               temt_int <= '0';
               LOW_DONE <= '0';
               OneWireIO <= CheckOW;
                 
             -- Checks OW value before sending out every bit to see if line
             -- was forced low by some other means at an incorrect time
             when CheckOw =>
               OneWireIO <= DQLOW;
               if(DQ_IN='0') then
                 SET_IOSHRT <= '1';
               end if;    

             -- DQLOW pulls the DQ line low for 1us, beginning a timeslot.
             -- If sr_a is 0, it is a normal write/read operation. If sr_a
             -- is a 1, then you must go into Search ROM accelerator mode.
             -- If OD is 1, the part is in overdrive and must perform
             -- ODWrites instead of normal Writes while OD is 0.
             when DQLOW =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               LOW_DONE <= '0';
               if(OD='1') then
                 if((not sr_a)='1') then
                   case (index) is
                     when s0 =>
                            if(( not xmit_shiftreg(0))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s1 =>
                            if((not xmit_shiftreg(1))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s2 =>
                            if((not xmit_shiftreg(2))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s3 =>
                            if((not xmit_shiftreg(3))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s4 =>
                            if((not xmit_shiftreg(4))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s5 =>
                            if((not xmit_shiftreg(5))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s6 =>
                            if((not xmit_shiftreg(6))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when s7 =>
                            if((not xmit_shiftreg(7))='1') then
                               OneWireIO <= ODWriteZero;
                            else
                               OneWireIO <= ODWriteOne;
                            end if;
                     when others => null;
                   end case;
                 else      -- Search Rom Accelerator mode
                   OneWireIO <= Readbit;    
                 end if;
               elsif(((TimeSlotCnt=bit_ts_writeone_high)and((not LLM)='1')) or
                      ((TimeSlotCnt=bit_ts_writeone_high_ll)and(LLM='1'))) then
                 if((not sr_a)='1') then
                   case (index) is
                     when s0 =>
                           if((not xmit_shiftreg(0))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s1 =>
                           if(( not xmit_shiftreg(1))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s2 =>
                           if((not xmit_shiftreg(2))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s3 =>
                           if((not xmit_shiftreg(3))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s4 =>
                           if((not xmit_shiftreg(4))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s5 =>
                           if((not xmit_shiftreg(5))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s6 =>
                           if((not xmit_shiftreg(6))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when s7 =>
                           if((not xmit_shiftreg(7))='1') then
                              OneWireIO <= WriteZero;
                           else
                              OneWireIO <= WriteOne;
                           end if;
                     when others => null;
                   end case;
                 else
                   OneWireIO <= ReadBit;
                 end if;
               end if;
                 
             -- WriteZero and WriteOne are identical, except for what they do to
             -- DQ (assigned in concurrent assignments). They both read DQ after
             -- 15us, then move on to wait for the end of the timeslot, unless
             -- running in Long Line mode which extends the sample time out to 22
             when WriteZero =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               if(((TimeSlotCnt=bit_ts_sample) and ((not sr_a)='1') and ((not LLM)='1')) or
                  ((TimeSlotCnt=bit_ts_sample_ll) and ((not sr_a)='1') and (LLM='1'))) then 
                 case (index) is
                   when s0 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(0) <= '1';
                      else
                        rcvr_shiftreg(0) <= '0';
                      end if;
                   when s1 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(1) <= '1';
                      else
                        rcvr_shiftreg(1) <= '0';
                      end if;
                   when s2 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(2) <= '1';
                      else
                        rcvr_shiftreg(2) <= '0';
                      end if;
                   when s3 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(3) <= '1';
                      else
                        rcvr_shiftreg(3) <= '0';
                      end if;
                   when s4 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(4) <= '1';
                      else
                        rcvr_shiftreg(4) <= '0';
                      end if;
                   when s5 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(5) <= '1';
                      else
                        rcvr_shiftreg(5) <= '0';
                      end if;
                   when s6 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(6) <= '1';
                      else
                        rcvr_shiftreg(6) <= '0';
                      end if;
                   when s7 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(7) <= '1';
                      else
                        rcvr_shiftreg(7) <= '0';
                      end if;
                      
                   when others =>
                      null; 
                 end case;
               end if;
               if(TimeSlotCnt=bit_ts_writezero_high) then
                 OneWireIO <= WaitTS;    
               end if;
               if((DQ_IN='1' or DQ_IN='H')) then
                 LOW_DONE <= '1';    
               end if;
            
             when WriteOne =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               if(((TimeSlotCnt=bit_ts_sample) and ((not sr_a)='1') and ((not LLM)='1')) or
                  ((TimeSlotCnt=bit_ts_sample_ll) and ((not sr_a)='1') and (LLM='1'))) then 
                 case (index) is
                   when s0 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(0) <= '1';
                      else
                        rcvr_shiftreg(0) <= '0';
                      end if;
                   when s1 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(1) <= '1';
                      else
                        rcvr_shiftreg(1) <= '0';
                      end if;
                   when s2 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(2) <= '1';
                      else
                        rcvr_shiftreg(2) <= '0';
                      end if;
                   when s3 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(3) <= '1';
                      else
                        rcvr_shiftreg(3) <= '0';
                      end if;
                   when s4 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(4) <= '1';
                      else
                        rcvr_shiftreg(4) <= '0';
                      end if;
                   when s5 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(5) <= '1';
                      else
                        rcvr_shiftreg(5) <= '0';
                      end if;
                   when s6 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(6) <= '1';
                      else
                        rcvr_shiftreg(6) <= '0';
                      end if;
                   when s7 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(7) <= '1';
                      else
                        rcvr_shiftreg(7) <= '0';
                      end if;
                      
                   when others =>
                      null; 
                 end case;
               end if;
               if(TimeSlotCnt=bit_ts_writezero_high) then
                 OneWireIO <= WaitTS;    
               end if;
               if((DQ_IN='1' or DQ_IN='H')) then
                 LOW_DONE <= '1';    
               end if;
             
                
             -- ADDED ODWRITE states here GAG
             -- ODWriteZero and ODWriteOne are identical, except for what they
             -- do to DQ (assigned in concurrent assignments). They both read
             -- DQ after 3us, then move on to wait for the end of the timeslot.
             when ODWriteZero =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               if((TimeSlotCnt=bit_ts_sample_od) and ((not sr_a)='1')) then 
                 case (index) is
                   when s0 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(0) <= '1';
                      else
                        rcvr_shiftreg(0) <= '0';
                      end if;
                   when s1 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(1) <= '1';
                      else
                        rcvr_shiftreg(1) <= '0';
                      end if;
                   when s2 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(2) <= '1';
                      else
                        rcvr_shiftreg(2) <= '0';
                      end if;
                   when s3 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(3) <= '1';
                      else
                        rcvr_shiftreg(3) <= '0';
                      end if;
                   when s4 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(4) <= '1';
                      else
                        rcvr_shiftreg(4) <= '0';
                      end if;
                   when s5 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(5) <= '1';
                      else
                        rcvr_shiftreg(5) <= '0';
                      end if;
                   when s6 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(6) <= '1';
                      else
                        rcvr_shiftreg(6) <= '0';
                      end if;
                   when s7 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(7) <= '1';
                      else
                        rcvr_shiftreg(7) <= '0';
                      end if;
                      
                   when others =>
                      null; 
                 end case;
               end if;
               if(TimeSlotCnt=bit_ts_writezero_high_od) then
                 OneWireIO <= WaitTS;    
               end if;
               if((DQ_IN='1' or DQ_IN='H')) then
                 LOW_DONE <= '1';    
               end if;
                
             when ODWriteOne =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               if((TimeSlotCnt=bit_ts_sample_od) and ((not sr_a)='1')) then 
                 case (index) is
                   when s0 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(0) <= '1';
                      else
                        rcvr_shiftreg(0) <= '0';
                      end if;
                   when s1 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(1) <= '1';
                      else
                        rcvr_shiftreg(1) <= '0';
                      end if;
                   when s2 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(2) <= '1';
                      else
                        rcvr_shiftreg(2) <= '0';
                      end if;
                   when s3 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(3) <= '1';
                      else
                        rcvr_shiftreg(3) <= '0';
                      end if;
                   when s4 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(4) <= '1';
                      else
                        rcvr_shiftreg(4) <= '0';
                      end if;
                   when s5 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(5) <= '1';
                      else
                        rcvr_shiftreg(5) <= '0';
                      end if;
                   when s6 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(6) <= '1';
                      else
                        rcvr_shiftreg(6) <= '0';
                      end if;
                   when s7 =>
                      if(DQ_IN='1' or DQ_IN='H') then
                        rcvr_shiftreg(7) <= '1';
                      else
                        rcvr_shiftreg(7) <= '0';
                      end if;
                      
                   when others =>
                      null; 
                 end case;
               end if;
               if(TimeSlotCnt=bit_ts_writezero_high_od) then
                 OneWireIO <= WaitTS;    
               end if;
               if((DQ_IN='1' or DQ_IN='H')) then
                 LOW_DONE <= '1';    
               end if;
                 
             -- ReadBit used by the SRA to do the required bit reads
             when ReadBit =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               if((DQ_IN='1' or DQ_IN='H')) then
                 LOW_DONE <= '1';    
               end if;
               if(OD='1') then
                 if(TimeSlotCnt = bit_ts_sample_od) then
                   if((not First) = '1') then
                     if(DQ_IN='1' or DQ_IN='H') then
                       BitRead1 <= '1';
                     else
                       BitRead1 <= '0';
                     end if;
                   else
                     if(DQ_IN='1' or DQ_IN='H') then
                       BitRead2 <= '1';
                     else
                       BitRead2 <= '0';
                     end if;
                   end if;  
                 end if;
                 if(TimeSlotCnt = bit_ts_writezero_high_od) then
                   OneWireIO <= FirstPassSR;
                 end if;    
               else
                 if(((TimeSlotCnt = bit_ts_sample)and((not LLM)='1')) or ((TimeSlotCnt = bit_ts_sample_ll)and(LLM='1'))) then
                   if((not First)='1') then
                     if(DQ_IN='1' or DQ_IN='H') then
                       BitRead1 <= '1';
                     else
                       BitRead1 <= '0';
                     end if;
                   else
                     if(DQ_IN='1' or DQ_IN='H') then
                       BitRead2 <= '1';
                     else
                       BitRead2 <= '0';
                     end if;
                   end if;
                 end if;
                 if(TimeSlotCnt = bit_ts_writezero_high) then
                   OneWireIO <= FirstPassSR;    
                 end if;
               end if;
             
             -- FirstPassSR decides whether to do another read or to do the
             -- bit write.
             when FirstPassSR =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               LOW_DONE <= '0';
               if(OD='1') then
                 if(TimeSlotCnt = bit_ts_end_od) then
                   TimeSlotCnt <= b"000_0000";
                   if((not First)='1') then
                     First <= '1';
                     OneWireIO <= DQLOW;
                   else
                     OneWireIO <= WriteBitSR;
                   end if;    
                 end if;
               else
                 if(((TimeSlotCnt=bit_ts_end)and((not LLM)='1')) or ((TimeSlotCnt=bit_ts_end_ll)and(LLM='1'))) then
                   TimeSlotCnt <= b"000_0000";
                   if((not First)='1') then
                     First <= '1';
                     OneWireIO <= DQLOW;    
                   else
                     OneWireIO <= WriteBitSR;    
                   end if;
                 end if;
               end if;     
                 
             -- WriteBitSR will now determine the bit necessary to write
             -- for the Search ROM to proceed.
             when WriteBitSR =>
               case (BitRead1_concat_BitRead2) is
                 when (b"00") =>
                    case (index) is
                      when s0 =>
                         BitWrite <= xmit_shiftreg(1);
                         rcvr_shiftreg(0) <= '1';
                      when s1 =>
                         BitWrite <= xmit_shiftreg(2);
                         rcvr_shiftreg(1) <= '1';
                      when s2 =>
                         BitWrite <= xmit_shiftreg(3);
                         rcvr_shiftreg(2) <= '1';
                      when s3 =>
                         BitWrite <= xmit_shiftreg(4);
                         rcvr_shiftreg(3) <= '1';
                      when s4 =>
                         BitWrite <= xmit_shiftreg(5);
                         rcvr_shiftreg(4) <= '1';
                      when s5 =>
                         BitWrite <= xmit_shiftreg(6);
                         rcvr_shiftreg(5) <= '1';
                      when s6 =>
                         BitWrite <= xmit_shiftreg(7);
                         rcvr_shiftreg(6) <= '1';
                      when s7 =>
                         BitWrite <= xmit_shiftreg(0);
                         rcvr_shiftreg(7) <= '1';
                      when others =>
                         null;
                    end case;
                 when (b"01") =>
                    BitWrite <= '0';
                    case (index) is
                      when s0 =>
                         rcvr_shiftreg(0) <= '0';
                      when s1 =>
                         rcvr_shiftreg(1) <= '0';
                      when s2 =>
                         rcvr_shiftreg(2) <= '0';
                      when s3 =>
                         rcvr_shiftreg(3) <= '0';
                      when s4 =>
                         rcvr_shiftreg(4) <= '0';
                      when s5 =>
                         rcvr_shiftreg(5) <= '0';
                      when s6 =>
                         rcvr_shiftreg(6) <= '0';
                      when s7 =>
                         rcvr_shiftreg(7) <= '0';
                      when others =>
                         null;
                    end case;
                 when (b"10") =>
                    BitWrite <= '1';
                    case (index) is
                      when s0 =>
                         rcvr_shiftreg(0) <= '0';
                      when s1 =>
                         rcvr_shiftreg(1) <= '0';
                      when s2 =>
                         rcvr_shiftreg(2) <= '0';
                      when s3 =>
                         rcvr_shiftreg(3) <= '0';
                      when s4 =>
                         rcvr_shiftreg(4) <= '0';
                      when s5 =>
                         rcvr_shiftreg(5) <= '0';
                      when s6 =>
                         rcvr_shiftreg(6) <= '0';
                      when s7 =>
                         rcvr_shiftreg(7) <= '0';
                      when others =>
                         null;
                    end case;
                 when (b"11") =>
                    BitWrite <= '1';
                    case (index) is
                      when s0 =>
                         rcvr_shiftreg(0) <= '1';
                         rcvr_shiftreg(1) <= '1';
                      when s1 =>
                         rcvr_shiftreg(1) <= '1';
                         rcvr_shiftreg(2) <= '1';
                      when s2 =>
                         rcvr_shiftreg(2) <= '1';
                         rcvr_shiftreg(3) <= '1';
                      when s3 =>
                         rcvr_shiftreg(3) <= '1';
                         rcvr_shiftreg(4) <= '1';
                      when s4 =>
                         rcvr_shiftreg(4) <= '1';
                         rcvr_shiftreg(5) <= '1';
                      when s5 =>
                         rcvr_shiftreg(5) <= '1';
                         rcvr_shiftreg(6) <= '1';
                      when s6 =>
                         rcvr_shiftreg(6) <= '1';
                         rcvr_shiftreg(7) <= '1';
                      when s7 =>
                         rcvr_shiftreg(7) <= '1';
                         rcvr_shiftreg(0) <= '1';
                      when others =>
                         null;
                    end case;
                 when others =>
                   null;
               end case; -- case (BitRead1_concat_BitRead2)
               OneWireIO <= WriteBit;
             
                 
             -- WriteBit actually writes the chosen bit to the One Wire bus.
             when WriteBit =>
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               case (index) is
                 when s0 =>
                   rcvr_shiftreg(1) <= BitWrite;
                 when s1 =>
                   rcvr_shiftreg(2) <= BitWrite;
                 when s2 =>
                   rcvr_shiftreg(3) <= BitWrite;
                 when s3 =>
                   rcvr_shiftreg(4) <= BitWrite;
                 when s4 =>
                   rcvr_shiftreg(5) <= BitWrite;
                 when s5 =>
                   rcvr_shiftreg(6) <= BitWrite;
                 when s6 =>
                   rcvr_shiftreg(7) <= BitWrite;
                 when s7 =>
                   rcvr_shiftreg(0) <= BitWrite;
                 when others =>
                   null;  
               end case;
               if((not BitWrite)='1') then
                 if(OD='1') then
                   OneWireIO <= ODWriteZero;
                 else
                   OneWireIO <= WriteZero;
                 end if;    
               else
                 if((OD='1') and (TimeSlotCnt = bit_ts_writeone_high_od)) then
                   OneWireIO <= ODWriteOne;    
                 elsif(((not LLM)='1') and (TimeSlotCnt = bit_ts_writeone_high)) then
                   OneWireIO <= WriteOne;      
                 elsif((LLM='1') and (TimeSlotCnt = bit_ts_writeone_high_ll)) then
                   OneWireIO <= WriteOne;    
                 end if;
               end if;

             -- WaitTS waits until the timeslot is completed, 80us. When done with
             -- that timeslot, the index will be incremented.
             when WaitTS =>
               SET_IOSHRT <= '0';
               TimeSlotCnt <= TimeSlotCnt + b"000_0001";
               if(OD='1') then
                 if(TimeSlotCnt = bit_ts_end_od) then
                   OneWireIO <= IndexInc;    
                 end if;
               else
                 if(((TimeSlotCnt = bit_ts_end) and ((not LLM)='1')) or ((TimeSlotCnt=bit_ts_end_ll) and (LLM='1'))) then
                   OneWireIO <= IndexInc;    
                 end if;
	       end if;
	       	 
               if(DQ_IN='1' OR DQ_IN='H') then
                 LOW_DONE <= '1';
               end if;

             -- IndexInc incs the index by 1 if normal write, by 2 if in SRA
             when IndexInc =>
               if((not sr_a)='1') then
                 index <= index + b"0001";    
               else
                 index <= index + b"0010";
                 First <= '0';
               end if;
               
               if((BIT_CTL='1') or ((index=b"0111") and ((not sr_a)='1')) or ((index=b"0110") and (sr_a='1'))) then
                 byte_done <= '1';
                 OneWireIO <= UpdateBuff;    
               else
                 if((index = b"0110") and ((not sr_a)='1')) then
                   last_rcvr_bit <= '1';
                 else
                   if((index = b"0100") and (sr_a = '1')) then
                     last_rcvr_bit <= '1';    
                   end if;
                 end if;
                 OneWireIO <= CheckOW;         -- Changed from DQLOW to
                 TimeSlotCnt <= b"000_0000";   -- remove pulse on LOW_DONE  
               end if;
               LOW_DONE <= '1';          -- Changed from 0 to 1
                 
             when UpdateBuff =>
               OneWireIO <= IdleS;
               LOW_DONE <= '0';
                 
             when others =>
               OneWireIO <= IdleS;
               LOW_DONE <= '0';
           end case;
         end if;
     end process;   
       
end architecture rtl_onewiremaster;
