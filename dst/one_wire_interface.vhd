----------------------------------------------------------------------------
--                                                                        --
--  OneWireMaster                                                         --
--   A synthesizable 1-wire master peripheral                             --
--   Copyright 1999-2007 Dallas Semiconductor Corporation                 --
--                                                                        --
----------------------------------------------------------------------------
--                                                                        --
--  Purpose:  Provides timing and control of Dallas 1-wire bus            --
--            through a memory-mapped peripheral                          --
--  File:     one_wire_interface.vhd                                      -- 
--  Date:     January 17, 2007                                            --
--  Version:  v1.100                                                      --
--  Authors:  Eric Hereford,                                              --
--            Dallas Semiconductor Corporation                            --
--                                                                        --
--  Note:     This source code is available for use without license.      --
--            Dallas Semiconductor is not responsible for the             --
--            functionality or utility of this product.                   --
--                                                                        --
--  REV:      Initial port based on v2.100 Verilog - EAH                  --
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity one_wire_interface is
  port(
    ADDRESS                     : IN std_logic_vector(2 downto 0);
    ADS_bar                     : IN std_logic;
    clear_interrupts            : IN std_logic;
    DIN                         : IN std_logic_vector(7 downto 0);
    DQ_IN                       : IN std_logic;
    EN_bar                      : IN std_logic;
    FSM_CLK                     : IN std_logic;
    MR                          : IN std_logic;
    OneWireIO_eq_Load           : IN std_logic;
    pdr                         : IN std_logic;
    OW_LOW                      : IN std_logic;
    OW_SHORT                    : IN std_logic;
    rbf                         : IN std_logic;
    rcvr_buffer                 : IN std_logic_vector(7 downto 0);
    RD_bar                      : IN std_logic;
    reset_owr                   : IN std_logic;
    rsrf                        : IN std_logic;
    temt                        : IN std_logic;
    WR_bar                      : IN std_logic;
    BIT_CTL                     : OUT std_logic;
    CLK_EN                      : OUT std_logic;
    clr_activate_intr           : OUT std_logic;
    DDIR                        : OUT std_logic;
    div_1                       : OUT std_logic;
    div_2                       : OUT std_logic;
    div_3                       : OUT std_logic;
    DOUT                        : OUT std_logic_vector(7 downto 0);
    EN_FOW                      : OUT std_logic;
    EOWL                        : OUT std_logic;
    EOWSH                       : OUT std_logic;
    epd                         : OUT std_logic;
    erbf                        : OUT std_logic;
    ersf                        : OUT std_logic;
    etbe                        : OUT std_logic;
    etmt                        : OUT std_logic;
    FOW                         : OUT std_logic;
    ias                         : OUT std_logic;
    LLM                         : OUT std_logic;
    OD                          : OUT std_logic;
    owr                         : OUT std_logic;
    pd                          : OUT std_logic;
    PPM                         : OUT std_logic;
    pre_0                       : OUT std_logic;
    pre_1                       : OUT std_logic;
    rbf_reset                   : OUT std_logic;
    sr_a                        : OUT std_logic;
    STP_SPLY                    : OUT std_logic;
    STPEN                       : OUT std_logic;
    tbe                         : OUT std_logic;
    xmit_buffer                 : OUT std_logic_vector(7 downto 0));
end one_wire_interface;

architecture rtl_one_wire_interface of one_wire_interface is
    
  signal read_op                : std_logic;
  signal read_op_n              : std_logic;
  signal write_op               : std_logic;
  signal write_op_n             : std_logic;
  signal sel_addr               : std_logic_vector(2 downto 0);
  signal set_activate_intr      : std_logic;
  signal xmit_buffer_full       : std_logic;
  signal CLR_OWR                : std_logic;
  signal acint_reset            : std_logic;
  
  -- VHDL does not allow Outputs to be used within the architecture,
  -- therefore internal signals were created to maintain consistency
  -- with Verilog code version  
  signal FOW_int                : std_logic;
  signal sr_a_int               : std_logic;
  signal owr_int                : std_logic;
  signal tbe_int                : std_logic;
  signal pd_int                 : std_logic;
  signal EOWL_int               : std_logic;
  signal EOWSH_int              : std_logic;
  signal ersf_int               : std_logic;
  signal erbf_int               : std_logic;
  signal etmt_int               : std_logic;
  signal etbe_int               : std_logic;
  signal ias_int                : std_logic;
  signal epd_int                : std_logic;
  signal CLK_EN_int             : std_logic;
  signal div_3_int              : std_logic;
  signal div_2_int              : std_logic;
  signal div_1_int              : std_logic;
  signal pre_1_int              : std_logic;
  signal pre_0_int              : std_logic;
  signal OD_int                 : std_logic;
  signal BIT_CTL_int            : std_logic;
  signal STP_SPLY_int           : std_logic;
  signal STPEN_int              : std_logic;
  signal EN_FOW_int             : std_logic;
  signal PPM_int                : std_logic;
  signal LLM_int                : std_logic;
  signal rbf_reset_int          : std_logic;
  signal clr_activate_intr_int  : std_logic;
  
  -- These signals are just defined to assist with debugging.
  -- They should be commented out when not debugging.
  --signal COMMAND_REG            : std_logic_vector(7 downto 0); -- @ Addr = 0x00
  --signal INTERRUPT_REG          : std_logic_vector(7 downto 0); -- @ Addr = 0x02
  --signal INTERRUPT_EN_REG       : std_logic_vector(7 downto 0); -- @ Addr = 0x03
  --signal CLOCK_DIVISOR_REG      : std_logic_vector(7 downto 0); -- @ Addr = 0x04
  --signal CONTROL_REG            : std_logic_vector(7 downto 0); -- @ Addr = 0x05
  -- End of debugging section.

-- Baschi ----------------------------------------------------------------------
  signal DQ_INre	          : std_logic;	-- DQ synched to Q25 _+-
--------------------------------------------------------------------------------

  begin
      
    -- These signals are just defined to assist with debugging.
    -- They should be commented out when not debugging.
    --COMMAND_REG <= (b"0000" & DQ_IN & FOW_int & sr_a_int & owr_int);
    --INTERRUPT_REG <= (OW_LOW & OW_SHORT & rsrf & rbf & temt & tbe_int & pdr & pd_int);
    --INTERRUPT_EN_REG <= (EOWL_int & EOWSH_int & ersf_int & erbf_int & etmt_int & etbe_int & ias_int & epd_int);
    --CLOCK_DIVISOR_REG <= (CLK_EN_int & b"00" & div_3_int & div_2_int & div_1_int & pre_1_int & pre_0_int);
    --CONTROL_REG <= (b"0" & OD_int & BIT_CTL_int & STP_SPLY_int & STPEN_int & EN_FOW_int & PPM_int & LLM_int);
    -- End of debugging section.
      
    FOW <= FOW_int;
    sr_a <= sr_a_int;
    owr <= owr_int;
    tbe <= tbe_int;
    pd <= pd_int;
    EOWL <= EOWL_int;
    EOWSH <= EOWSH_int;
    ersf <= ersf_int;
    erbf <= erbf_int;
    etmt <= etmt_int;
    etbe <= etbe_int;
    ias <= ias_int;
    epd <= epd_int;
    CLK_EN <= CLK_EN_int;
    div_3 <= div_3_int;
    div_2 <= div_2_int;
    div_1 <= div_1_int;
    pre_1 <= pre_1_int;
    pre_0 <= pre_0_int;
    OD <= OD_int;
    BIT_CTL <= BIT_CTL_int;
    STP_SPLY <= STP_SPLY_int;
    STPEN <= STPEN_int;
    EN_FOW <= EN_FOW_int;
    PPM <= PPM_int;
    LLM <= LLM_int;
    rbf_reset <= rbf_reset_int;
    clr_activate_intr <= clr_activate_intr_int;
    
    --------------------------------------------------------------------------
    --  read/write process
    --------------------------------------------------------------------------
    
    -- Continuous assignments  
    read_op <= (not EN_bar) and (not MR) and (not RD_bar) and WR_bar;
    read_op_n <= (not read_op);
    write_op <= (not EN_bar) and (not MR) and RD_bar and (not WR_bar);
    write_op_n <= (not write_op);
    DDIR <= read_op;
    CLR_OWR <= MR or reset_owr;
    acint_reset <= MR or clear_interrupts;
    rbf_reset_int <= '1' when (read_op = '1' and (sel_addr = b"001")) else '0';
    
    process(MR, WR_bar)
      begin
        if (MR='1') then
          EOWL_int <= '0';
          EOWSH_int <= '0';
          ersf_int <= '0';
          erbf_int <= '0';
          etmt_int <= '0';
          etbe_int <= '0';
          ias_int <= '0';
          epd_int <= '0';
          xmit_buffer <= x"00";
        elsif (WR_bar='1' and WR_bar'event) then
          if(((not EN_bar) and RD_bar) = '1') then
            case(sel_addr) is
              when b"001" =>
                xmit_buffer <= DIN;
              
              when b"011" =>
                EOWL_int <= DIN(7);
                EOWSH_int <= DIN(6);
                ersf_int <= DIN(5);
                erbf_int <= DIN(4);
                etmt_int <= DIN(3);
                etbe_int <= DIN(2);
                ias_int <= DIN(1);
                epd_int <= DIN(0);
                  
              when others => null;
            end case;
          end if;   
        end if;          
    end process;

    
    --
    -- Modified DOUT to always drive the current register value out
    -- based on the address value
    --
-- original --------------------------------------------------------------------	   
--    DOUT <= 
--      (b"0000" & DQ_IN & FOW_int & sr_a_int & owr_int) when (sel_addr = b"000") else
--      (rcvr_buffer) when (sel_addr = b"001") else
--      (OW_LOW & OW_SHORT & rsrf & rbf & temt & tbe_int & pdr & pd_int) when (sel_addr = b"010") else
--      (EOWL_int & EOWSH_int & ersf_int & erbf_int & etmt_int & etbe_int & ias_int & epd_int) when (sel_addr = b"011") else
--      (CLK_EN_int & b"00" & div_3_int & div_2_int & div_1_int & pre_1_int & pre_0_int) when (sel_addr = b"100") else
--      (b"0" & OD_int & BIT_CTL_int & STP_SPLY_int & STPEN_int & EN_FOW_int & PPM_int & LLM_int) when (sel_addr = b"101") else x"00";
-- Baschi ----------------------------------------------------------------------	   
	process (FSM_CLK)
      begin 
      	-- synch DQ to rising edge to get no timig problems (Q25-+_ to Q125_+-)
		if rising_edge(FSM_CLK) then
        	DQ_INre <= DQ_IN;
        end if;
    end process;

    DOUT <= 
      (b"0000" & DQ_INre & FOW_int & sr_a_int & owr_int) when (sel_addr = b"000") else
      (rcvr_buffer) when (sel_addr = b"001") else
      (OW_LOW & OW_SHORT & rsrf & rbf & temt & tbe_int & pdr & pd_int) when (sel_addr = b"010") else
      (EOWL_int & EOWSH_int & ersf_int & erbf_int & etmt_int & etbe_int & ias_int & epd_int) when (sel_addr = b"011") else
      (CLK_EN_int & b"00" & div_3_int & div_2_int & div_1_int & pre_1_int & pre_0_int) when (sel_addr = b"100") else
      (b"0" & OD_int & BIT_CTL_int & STP_SPLY_int & STPEN_int & EN_FOW_int & PPM_int & LLM_int) when (sel_addr = b"101") else x"00";            
--------------------------------------------------------------------------------


    --
    -- Clock divisor register
    --
    -- synopsys async_set_reset MR
    process(MR, WR_bar)
      begin
        if (MR='1') then
          pre_0_int <= '0';
          pre_1_int <= '0';
          div_1_int <= '0';
          div_2_int <= '0';
          div_3_int <= '0';
          CLK_EN_int <= '0';
        elsif (WR_bar='1' and WR_bar'event) then
          if(((not EN_bar) and RD_bar) = '1') then
            if(sel_addr = b"100") then
              pre_0_int <= DIN(0);
              pre_1_int <= DIN(1);
              div_1_int <= DIN(2);
              div_2_int <= DIN(3);
              div_3_int <= DIN(4);
              CLK_EN_int <= DIN(7);
            end if;
          end if;    
        end if;
    end process;
    
    --
    -- Command reg writes are handled in the next two sections
    -- Bit 0 needs to be separate for the added clearing mechanism
    --
    process(CLR_OWR, WR_bar)
      begin
        if (CLR_OWR='1') then
          owr_int <= '0';    
        elsif (WR_bar='1' and WR_bar'event) then
          if(((not EN_bar) and RD_bar) = '1') then
            if(sel_addr = b"000") then
              owr_int <= DIN(0);
            end if;
          end if;    
        end if;
    end process;
    --
    -- Bits 1-7's write routine
    --
    process(MR, WR_bar)
      begin
        if (MR='1') then
          FOW_int <= '0';
          sr_a_int <= '0';    
        elsif (WR_bar='1' and WR_bar'event) then
          if(((not EN_bar) and RD_bar) = '1') then
            if(sel_addr = b"000") then
              sr_a_int <= DIN(1);
              FOW_int <= DIN(2);
            end if;
          end if;
        end if;
    end process;
    
    --
    -- The Control reg writes are handled here
    --
    process(MR, WR_bar)
      begin
        if (MR='1') then
          OD_int <= '0';
          BIT_CTL_int <= '0';
          STP_SPLY_int <= '0';
          STPEN_int <= '0';
          EN_FOW_int <= '0';
          PPM_int <= '0';
          LLM_int <= '0';
        elsif (WR_bar='1' and WR_bar'event) then
          if( EN_bar='0' and RD_bar ='1') then
            if(sel_addr = b"101") then
              OD_int <= DIN(6);
              BIT_CTL_int <= DIN(5);
              STP_SPLY_int <= DIN(4);
              STPEN_int <= DIN(3);
              EN_FOW_int <= DIN(2);
              PPM_int <= DIN(1);
              LLM_int <= DIN(0);
            end if;
          end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    --  Transparent address latch
    ----------------------------------------------------------------------------
    process(ADS_bar,ADDRESS,EN_bar)
      begin
        if(((not ADS_bar) and (not EN_bar))='1') then
          sel_addr <= ADDRESS;
        end if;    
    end process;

    ----------------------------------------------------------------------------
    -- Interrupt flag register clearing (What is not handled in onewiremaster.v)
    ----------------------------------------------------------------------------
    process(acint_reset, RD_bar)
      begin
        if (acint_reset='1') then
          clr_activate_intr_int <= '0';    
        elsif (RD_bar='1' and RD_bar'event) then
          if(((not EN_bar) and WR_bar)='1') then
            if(sel_addr = b"010") then
              clr_activate_intr_int <= '1';
            end if;    
          end if;
        end if;    
    end process;

    
    process(MR, FSM_CLK)
      begin
        if (MR='1') then
          pd_int <= '0';    
        elsif (FSM_CLK='1' and FSM_CLK'event) then
          if(reset_owr = '1') then
            pd_int <= '1';    
          elsif (clr_activate_intr_int = '1') then
            pd_int <= '0';        
          else
            pd_int <= pd_int;        
          end if;
        end if;
    end process;
    
    --
    -- The following two blocks handle tbe_int
    -- The lower is the psuedo asynch portion which is synched up
    --  in the upper section.
    --
    process(FSM_CLK, MR)
      begin
        if (MR='1') then
          tbe_int <= '1';    
        elsif (FSM_CLK='1' and FSM_CLK'event) then
          tbe_int <= (not xmit_buffer_full);    
        end if;          
    end process;
    
    process(MR, WR_bar, OneWireIO_eq_Load)
      begin
        if (MR='1') then
          xmit_buffer_full <= '0';
        elsif (OneWireIO_eq_Load ='1') then
          xmit_buffer_full <= '0';
        elsif (WR_bar='1' and WR_bar'event) then
          if(((not EN_bar) and RD_bar)='1') then
            if(sel_addr = b"001") then
              xmit_buffer_full <= '1';
            end if;    
          end if;
        end if;    
    end process;
      
end architecture rtl_one_wire_interface;

    
