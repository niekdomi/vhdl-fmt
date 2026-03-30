----------------------------------------------------------------------------
--																		  --
--  OneWireMaster														  --
--   A synthesizable 1-wire master peripheral							  --
--   Copyright 1999-2007 Dallas Semiconductor Corporation				  --
--																		  --
----------------------------------------------------------------------------
--																		  --
--  Purpose:  Provides timing and control of Dallas 1-wire bus			  --
--			  through a memory-mapped peripheral						  --
--  File:	  owm.vhd													  --
--  Date:	  January 17, 2007											  --
--  Version:  v1.100													  --
--  Authors:  Eric Hereford,											  --
--			  Dallas Semiconductor Corporation							  --
--																		  --
--  Note:	  This source code is available for use without license.	  --
--			  Dallas Semiconductor is not responsible for the			  --
--			  functionality or utility of this product.					  --
--																		  --
--  REV:	  Initial port based on v2.100 Verilog - EAH				  --
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

ENTITY ds1wm IS
   PORT (
	  ADDRESS				  : IN std_logic_vector(2 DOWNTO 0);   
	  ADS_bar				  : IN std_logic;   
	  CLK					  : IN std_logic;
	  EN_bar				  : IN std_logic;
	  MR					  : IN std_logic;   
	  RD_bar				  : IN std_logic;   
	  WR_bar				  : IN std_logic;   
	  INTR					  : OUT std_logic;   
	  STPZ					  : OUT std_logic;  
-- original --------------------------------------------------------------------	   
--	  DATA					  : INOUT std_logic_vector(7 DOWNTO 0);   
--	  DQ					  : INOUT std_logic);
-- Baschi ----------------------------------------------------------------------	   
	  i_DATA				  : IN std_logic_vector(7 DOWNTO 0);   
	  i_DQ					  : IN std_logic;
	  o_DATA				  : OUT std_logic_vector(7 DOWNTO 0);   
	  o_DQ_CONTROL			  : OUT std_logic;
	  i_clk_1us               : IN std_logic);
--------------------------------------------------------------------------------
END ENTITY ds1wm;

ARCHITECTURE rtl_ds1wm OF ds1wm IS

  COMPONENT one_wire_io
	PORT (
	  CLK						 :  IN std_logic;
	  DDIR						 :  IN std_logic;
	  DOUT						 :  IN std_logic_vector(7 DOWNTO 0);
	  DQ_CONTROL				 :  IN std_logic;
	  MR						 :  IN std_logic;
	  DIN						 :  OUT std_logic_vector(7 DOWNTO 0);
	  DQ_IN						 :  OUT std_logic;
	  DATA						 :  INOUT std_logic_vector(7 DOWNTO 0);
	  DQ						 :  INOUT std_logic
	  );   
  END COMPONENT;
  
  COMPONENT clk_prescaler
 	PORT (
 	  CLK		  : in std_logic;
 	  CLK_EN	  : in std_logic;
 	  div_1		  : in std_logic;
 	  div_2		  : in std_logic;
 	  div_3		  : in std_logic;
 	  MR		  : in std_logic;
 	  pre_0		  : in std_logic;
 	  pre_1		  : in std_logic;
 	  clk_1us	  : out std_logic
 	  );
  END COMPONENT;
  
  COMPONENT one_wire_interface
	PORT (
	  ADDRESS					  : IN std_logic_vector(2 downto 0);
	  ADS_bar					  : IN std_logic;
	  clear_interrupts			  : IN std_logic;
	  DIN						  : IN std_logic_vector(7 downto 0);
	  DQ_IN						  : IN std_logic;
	  EN_bar					  : IN std_logic;
	  FSM_CLK					  : IN std_logic;
	  MR						  : IN std_logic;
	  OneWireIO_eq_Load			  : IN std_logic;
	  pdr						  : IN std_logic;
	  OW_LOW					  : IN std_logic;
	  OW_SHORT					  : IN std_logic;
	  rbf						  : IN std_logic;
	  rcvr_buffer				  : IN std_logic_vector(7 downto 0);
	  RD_bar					  : IN std_logic;
	  reset_owr					  : IN std_logic;
	  rsrf						  : IN std_logic;
	  temt						  : IN std_logic;
	  WR_bar					  : IN std_logic;
	  BIT_CTL					  : OUT std_logic;
	  CLK_EN					  : OUT std_logic;
	  clr_activate_intr			  : OUT std_logic;
	  DDIR						  : OUT std_logic;
	  div_1						  : OUT std_logic;
	  div_2						  : OUT std_logic;
	  div_3						  : OUT std_logic;
	  DOUT						  : OUT std_logic_vector(7 downto 0);
	  EN_FOW					  : OUT std_logic;
	  EOWL						  : OUT std_logic;
	  EOWSH						  : OUT std_logic;
	  epd						  : OUT std_logic;
	  erbf						  : OUT std_logic;
	  ersf						  : OUT std_logic;
	  etbe						  : OUT std_logic;
	  etmt						  : OUT std_logic;
	  FOW						  : OUT std_logic;
	  ias						  : OUT std_logic;
	  LLM						  : OUT std_logic;
	  OD						  : OUT std_logic;
	  owr						  : OUT std_logic;
	  pd						  : OUT std_logic;
	  PPM						  : OUT std_logic;
	  pre_0						  : OUT std_logic;
	  pre_1						  : OUT std_logic;
	  rbf_reset					  : OUT std_logic;
	  sr_a						  : OUT std_logic;
	  STP_SPLY					  : OUT std_logic;
	  STPEN						  : OUT std_logic;
	  tbe						  : OUT std_logic;
	  xmit_buffer				  : OUT std_logic_vector(7 downto 0)
	  );
  END COMPONENT;

  COMPONENT onewiremaster
	PORT (
	  BIT_CTL				   : in std_logic;
	  clk_1us				   : in std_logic;
	  clr_activate_intr		   : in std_logic;
	  DQ_IN					   : in std_logic;
	  EN_FOW				   : in std_logic;
	  EOWL					   : in std_logic;
	  EOWSH					   : in std_logic;
	  epd					   : in std_logic;
	  erbf					   : in std_logic;
	  ersf					   : in std_logic;
	  etbe					   : in std_logic;
	  etmt					   : in std_logic;
	  FOW					   : in std_logic;
	  ias					   : in std_logic;
	  LLM					   : in std_logic;
	  MR					   : in std_logic;
	  OD					   : in std_logic;
	  owr					   : in std_logic;
	  pd					   : in std_logic;
	  PPM					   : in std_logic;
	  rbf_reset				   : in std_logic;
	  sr_a					   : in std_logic;
	  STP_SPLY				   : in std_logic;
	  STPEN					   : in std_logic;
	  tbe					   : in std_logic;
	  xmit_buffer			   : in std_logic_vector (7 downto 0);
	  clear_interrupts		   : out std_logic;
	  DQ_CONTROL			   : out std_logic;
	  FSM_CLK				   : out std_logic;
	  INTR					   : out std_logic;
	  OneWireIO_eq_Load		   : out std_logic;
	  OW_LOW				   : out std_logic;
	  OW_SHORT				   : out std_logic;
	  pdr					   : out std_logic;
	  rbf					   : out std_logic;
	  rcvr_buffer			   : out std_logic_vector (7 downto 0);
	  reset_owr				   : out std_logic;
	  rsrf					   : out std_logic;
	  STPZ					   : out std_logic;
	  temt					   : out std_logic
	  );
  END COMPONENT;
	
  
  signal DDIR				 : std_logic;
  signal DOUT				 : std_logic_vector(7 downto 0);
  signal DQ_CONTROL			 : std_logic;
  signal DIN				 : std_logic_vector(7 downto 0);
  signal DQ_IN				 : std_logic;
  signal CLK_EN				 : std_logic;
  signal div_1				 : std_logic;
  signal div_2				 : std_logic;
  signal div_3				 : std_logic;
  signal pre_0				 : std_logic;
  signal pre_1				 : std_logic;
  signal clk_1us			 : std_logic;
  signal clear_interrupts	 : std_logic;
  signal fsm_clk			 : std_logic;
  signal onewireio_eq_load   : std_logic;
  signal pdr				 : std_logic;
  signal ow_low				 : std_logic;
  signal ow_short			 : std_logic;
  signal rbf				 : std_logic;
  signal rcvr_buffer		 : std_logic_vector(7 downto 0);
  signal reset_owr			 : std_logic;
  signal rsrf				 : std_logic;
  signal temt				 : std_logic;
  signal bit_ctl			 : std_logic;
  signal clr_activate_intr   : std_logic;
  signal en_fow				 : std_logic;
  signal eowl				 : std_logic;
  signal eowsh				 : std_logic;
  signal epd				 : std_logic;
  signal erbf				 : std_logic;
  signal ersf				 : std_logic;
  signal etbe				 : std_logic;
  signal etmt				 : std_logic;
  signal fow				 : std_logic;
  signal ias				 : std_logic;
  signal llm				 : std_logic;
  signal od					 : std_logic;
  signal owr				 : std_logic;
  signal pd					 : std_logic;
  signal ppm				 : std_logic;
  signal rbf_reset			 : std_logic;
  signal sr_a				 : std_logic;
  signal stp_sply			 : std_logic;
  signal stpen				 : std_logic;
  signal tbe				 : std_logic;
  signal xmit_buffer		 : std_logic_vector(7 downto 0);

  
  BEGIN
	  
-- original --------------------------------------------------------------------	   
--  xone_wire_io : one_wire_io
--	  PORT MAP (
--		CLK			=> CLK,
--		DDIR		=> DDIR,
--		DOUT		=> DOUT,
--		DQ_CONTROL  => DQ_CONTROL,
--		MR			=> MR,
--		DIN			=> DIN,
--		DQ_IN		=> DQ_IN,
--		DATA		=> DATA,
--		DQ			=> DQ
--		);
-- Baschi ----------------------------------------------------------------------	   
 	o_DATA 		 <= DOUT;
	DIN			 <= i_DATA;		   
	o_DQ_CONTROL <= DQ_CONTROL;		-- DQ <= 'Z' when DQ_CONTROL='1' else '0';
	
	process(MR, CLK)
	  begin
		if (MR='1') then
		  DQ_IN <= '1';	   
		elsif falling_edge(CLK) then
		  DQ_IN <= i_DQ;	
		end if;	   
	end process;
--------------------------------------------------------------------------------		
		
-- original --------------------------------------------------------------------	   
--  xclk_prescaler : clk_prescaler
--	PORT MAP (
--	  CLK		  => CLK,
--	  CLK_EN	  => CLK_EN,
--	  div_1		  => div_1,
--	  div_2		  => div_2,
--	  div_3		  => div_3,
--	  MR		  => MR,
--	  pre_0		  => pre_0,
--	  pre_1		  => pre_1,
--	  clk_1us	  => clk_1us
--	  );
-- Baschi ----------------------------------------------------------------------	   
	clk_1us <= i_clk_1us;
--------------------------------------------------------------------------------
	  
  xone_wire_interface : one_wire_interface
	PORT MAP (
	  ADDRESS			  => ADDRESS,
	  ADS_bar			  => ADS_bar,
	  clear_interrupts	  => clear_interrupts,
	  DIN				  => DIN,
	  DQ_IN				  => DQ_IN,
	  EN_bar			  => EN_bar,
	  FSM_CLK			  => FSM_CLK,
	  MR				  => MR,
	  OneWireIO_eq_Load   => OneWireIO_eq_Load,
	  pdr				  => pdr,
	  OW_LOW			  => OW_LOW,
	  OW_SHORT			  => OW_SHORT,
	  rbf				  => rbf,
	  rcvr_buffer		  => rcvr_buffer,
	  RD_bar			  => RD_bar,
	  reset_owr			  => reset_owr,
	  rsrf				  => rsrf,
	  temt				  => temt,
	  WR_bar			  => WR_bar,
	  BIT_CTL			  => BIT_CTL,
	  CLK_EN			  => CLK_EN,
	  clr_activate_intr   => clr_activate_intr,
	  DDIR				  => DDIR,
	  div_1				  => div_1,
	  div_2				  => div_2,
	  div_3				  => div_3,
	  DOUT				  => DOUT,
	  EN_FOW			  => EN_FOW,
	  EOWL				  => EOWL,
	  EOWSH				  => EOWSH,
	  epd				  => epd,
	  erbf				  => erbf,
	  ersf				  => ersf,
	  etbe				  => etbe,
	  etmt				  => etmt,
	  FOW				  => FOW,
	  ias				  => ias,
	  LLM				  => LLM,
	  OD				  => OD,
	  owr				  => owr,
	  pd				  => pd,
	  PPM				  => PPM,
	  pre_0				  => pre_0,
	  pre_1				  => pre_1,
	  rbf_reset			  => rbf_reset,
	  sr_a				  => sr_a,
	  STP_SPLY			  => STP_SPLY,
	  STPEN				  => STPEN,
	  tbe				  => tbe,
	  xmit_buffer		  => xmit_buffer
	  );
	  
  xonewiremaster : onewiremaster
	PORT MAP (
	  BIT_CTL			  => BIT_CTL,
	  clk_1us			  => clk_1us,
	  clr_activate_intr   => clr_activate_intr,
	  DQ_IN				  => DQ_IN,
	  EN_FOW			  => EN_FOW,
	  EOWL				  => EOWL,
	  EOWSH				  => EOWSH,
	  epd				  => epd,
	  erbf				  => erbf,
	  ersf				  => ersf,
	  etbe				  => etbe,
	  etmt				  => etmt,
	  FOW				  => FOW,
	  ias				  => ias,
	  LLM				  => LLM,
	  MR				  => MR,
	  OD				  => OD,
	  owr				  => owr,
	  pd				  => pd,
	  PPM				  => PPM,
	  rbf_reset			  => rbf_reset,
	  sr_a				  => sr_a,
	  STP_SPLY			  => STP_SPLY,
	  STPEN				  => STPEN,
	  tbe				  => tbe,
	  xmit_buffer		  => xmit_buffer,
	  clear_interrupts	  => clear_interrupts,
	  DQ_CONTROL		  => DQ_CONTROL,
	  FSM_CLK			  => FSM_CLK,
	  INTR				  => INTR,
	  OneWireIO_eq_Load   => OneWireIO_eq_Load,
	  OW_LOW			  => OW_LOW,
	  OW_SHORT			  => OW_SHORT,
	  pdr				  => pdr,
	  rbf				  => rbf,
	  rcvr_buffer		  => rcvr_buffer,
	  reset_owr			  => reset_owr,
	  rsrf				  => rsrf,
	  STPZ				  => STPZ,
	  temt				  => temt
	  );
	  

END ARCHITECTURE rtl_ds1wm;

