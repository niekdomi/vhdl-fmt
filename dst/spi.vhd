 --------------------------------------------------------------------------------
--$Rev:: 2527                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2012-11-21 12:28:08 +0100 (Mi., 21 Nov 2012)                         $
--------------------------------------------------------------------------------
 LIBRARY lpm;
 USE lpm.all;

 LIBRARY maxii;
 USE maxii.all;


 LIBRARY ieee;
 USE ieee.std_logic_1164.all;

 ENTITY  spi_altufm_spi_9so IS 
	 PORT 
	 ( 
		 ncs	:	IN  STD_LOGIC;
		 osc	:	OUT  STD_LOGIC;
		 sck	:	IN  STD_LOGIC;
		 si	:	IN  STD_LOGIC;
		 so	:	OUT  STD_LOGIC
	 ); 
 END spi_altufm_spi_9so;

 ARCHITECTURE RTL OF spi_altufm_spi_9so IS

	 ATTRIBUTE synthesis_clearbox : natural;
	 ATTRIBUTE synthesis_clearbox OF RTL : ARCHITECTURE IS 2;
	 ATTRIBUTE ALTERA_ATTRIBUTE : string;
	 ATTRIBUTE ALTERA_ATTRIBUTE OF RTL : ARCHITECTURE IS "suppress_da_rule_internal=c101;suppress_da_rule_internal=c103;suppress_da_rule_internal=c104;suppress_da_rule_internal=c106;suppress_da_rule_internal=d101;suppress_da_rule_internal=r101;suppress_da_rule_internal=s102;suppress_da_rule_internal=s104";

	 SIGNAL	 addr_stdly_reg	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 dffe10	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 dffe12	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 	 SIGNAL	 dffe12_5	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 dffe13	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 	 SIGNAL	 dffe13_5	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 dffe2	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 dffe4	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 wire_dffe5a_d	:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	 SIGNAL	 dffe5a	:	STD_LOGIC_VECTOR(7 DOWNTO 0)
	 -- synopsys translate_off
	  := (OTHERS => '0')
	 -- synopsys translate_on
	 ;
	 SIGNAL	 wire_dffe5a_ena	:	STD_LOGIC_VECTOR(7 DOWNTO 0);
	 SIGNAL	 dffe6	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 wire_dffe7a_d	:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	 SIGNAL	 dffe7a	:	STD_LOGIC_VECTOR(7 DOWNTO 0)
	 -- synopsys translate_off
	  := (OTHERS => '0')
	 -- synopsys translate_on
	 ;
	 SIGNAL	 wire_dffe7a_ena	:	STD_LOGIC_VECTOR(7 DOWNTO 0);
	 SIGNAL	 dffe8	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL	 dffe9	:	STD_LOGIC
	 -- synopsys translate_off
	  := '0'
	 -- synopsys translate_on
	 ;
	 SIGNAL  wire_cntr11_clk_en	:	STD_LOGIC;
	 SIGNAL  wire_w_lg_w_lg_w_lg_ncs_wire2w80w81w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_cntr11_q	:	STD_LOGIC_VECTOR (4 DOWNTO 0);
	 SIGNAL  wire_cntr14_w_lg_w_q_range89w106w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_cntr14_clk_en	:	STD_LOGIC;
	 SIGNAL  wire_w_lg_w_lg_w_lg_ncs_wire2w103w104w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_cntr14_q	:	STD_LOGIC_VECTOR (3 DOWNTO 0);
	 SIGNAL  wire_cntr14_w_q_range89w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_cntr3_clk_en	:	STD_LOGIC;
	 SIGNAL  wire_w_lg_w_lg_w_lg_ncs_wire2w5w6w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_cntr3_clock	:	STD_LOGIC;
	 SIGNAL  wire_cntr3_q	:	STD_LOGIC_VECTOR (2 DOWNTO 0);
	 SIGNAL  wire_maxii_ufm_block1_bgpbusy	:	STD_LOGIC;
	 SIGNAL  wire_maxii_ufm_block1_busy	:	STD_LOGIC;
	 SIGNAL  wire_maxii_ufm_block1_drdout	:	STD_LOGIC;
	 SIGNAL  wire_maxii_ufm_block1_osc	:	STD_LOGIC;
	 SIGNAL	 wire_tri_buf15_out	:	STD_LOGIC;
	 SIGNAL	 wire_tri_buf15_oe	:	STD_LOGIC;
	 SIGNAL  wire_w_lg_w_lg_w_lg_w_lg_ncs_wire2w14w15w16w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_w_lg_w_lg_ncs_wire2w14w15w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_w_lg_ncs_wire2w14w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_addr_stdly113w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_addr_complete79w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_addr_complete_state107w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_ncs_wire2w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_op_complete3w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_op_complete_state13w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_sck_wire1w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_ufm_bgpbusy12w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_ufm_busy75w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  wire_w_lg_data_state114w	:	STD_LOGIC_VECTOR (0 DOWNTO 0);
	 SIGNAL  addr_complete :	STD_LOGIC;
	 SIGNAL  addr_complete_state :	STD_LOGIC;
	 SIGNAL  addr_state :	STD_LOGIC;
	 SIGNAL  addr_stdly :	STD_LOGIC;
	 SIGNAL  circuit_reset :	STD_LOGIC;
	 SIGNAL  data_complete :	STD_LOGIC;
	 SIGNAL  data_state :	STD_LOGIC;
	 SIGNAL  ncs_wire :	STD_LOGIC;
	 SIGNAL  op_complete :	STD_LOGIC;
	 SIGNAL  op_complete_state :	STD_LOGIC;
	 SIGNAL  op_state :	STD_LOGIC;
	 SIGNAL  oscena	:	STD_LOGIC;
	 SIGNAL  read_op :	STD_LOGIC;
	 SIGNAL  read_op_state :	STD_LOGIC;
	 SIGNAL  sck_wire :	STD_LOGIC;
	 SIGNAL  si_wire :	STD_LOGIC;
	 SIGNAL  so_wire :	STD_LOGIC;
	 SIGNAL  ufm_arclk :	STD_LOGIC;
	 SIGNAL  ufm_ardin :	STD_LOGIC;
	 SIGNAL  ufm_arshft :	STD_LOGIC;
	 SIGNAL  ufm_bgpbusy :	STD_LOGIC;
	 SIGNAL  ufm_busy :	STD_LOGIC;
	 SIGNAL  ufm_drclk :	STD_LOGIC;
	 SIGNAL  ufm_drdin :	STD_LOGIC;
	 SIGNAL  ufm_drdout :	STD_LOGIC;
	 SIGNAL  ufm_drshft :	STD_LOGIC;
	 SIGNAL  ufm_erase :	STD_LOGIC;
	 SIGNAL  ufm_osc :	STD_LOGIC;
	 SIGNAL  ufm_oscena :	STD_LOGIC;
	 SIGNAL  ufm_program :	STD_LOGIC;
	 
	 SIGNAL  x_y :	STD_LOGIC;
	 COMPONENT  lpm_counter
	 GENERIC 
	 (
		lpm_avalue	:	STRING := "0";
		lpm_direction	:	STRING := "DEFAULT";
		lpm_modulus	:	NATURAL := 0;
		lpm_port_updown	:	STRING := "PORT_CONNECTIVITY";
		lpm_pvalue	:	STRING := "0";
		lpm_svalue	:	STRING := "0";
		lpm_width	:	NATURAL;
		lpm_type	:	STRING := "lpm_counter"
	 );
	 PORT
	 ( 
		aclr	:	IN STD_LOGIC := '0';
		aload	:	IN STD_LOGIC := '0';
		aset	:	IN STD_LOGIC := '0';
		cin	:	IN STD_LOGIC := '1';
		clk_en	:	IN STD_LOGIC := '1';
		clock	:	IN STD_LOGIC;
		cnt_en	:	IN STD_LOGIC := '1';
		cout	:	OUT STD_LOGIC;
		data	:	IN STD_LOGIC_VECTOR(LPM_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
		eq	:	OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		q	:	OUT STD_LOGIC_VECTOR(LPM_WIDTH-1 DOWNTO 0);
		sclr	:	IN STD_LOGIC := '0';
		sload	:	IN STD_LOGIC := '0';
		sset	:	IN STD_LOGIC := '0';
		updown	:	IN STD_LOGIC := '1'
	 ); 
	 END COMPONENT;
	 COMPONENT  maxii_ufm
	 GENERIC 
	 (
		ADDRESS_WIDTH	:	NATURAL := 9;
		ERASE_TIME	:	NATURAL := 500000000;
		INIT_FILE	:	STRING := "UNUSED";
		mem1	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem10	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem11	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem12	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem13	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem14	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem15	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem16	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem2	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem3	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem4	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem5	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem6	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem7	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem8	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		mem9	:	STD_LOGIC_VECTOR(511 DOWNTO 0) := "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111";
		OSC_SIM_SETTING	:	NATURAL := 180000;
		PROGRAM_TIME	:	NATURAL := 1600000;
		lpm_type	:	STRING := "maxii_ufm"
	 );
	 PORT
	 ( 
		arclk	:	IN STD_LOGIC := '0';
		ardin	:	IN STD_LOGIC := '0';
		arshft	:	IN STD_LOGIC := '1';
		bgpbusy	:	OUT STD_LOGIC;
		busy	:	OUT STD_LOGIC;
		drclk	:	IN STD_LOGIC := '0';
		drdin	:	IN STD_LOGIC := '0';
		drdout	:	OUT STD_LOGIC;
		drshft	:	IN STD_LOGIC := '1';
		erase	:	IN STD_LOGIC := '0';
		osc	:	OUT STD_LOGIC;
		oscena	:	IN STD_LOGIC := '0';
		program	:	IN STD_LOGIC := '0'
	 ); 
	 END COMPONENT;
 BEGIN

	wire_w_lg_w_lg_w_lg_w_lg_ncs_wire2w14w15w16w(0) <= wire_w_lg_w_lg_w_lg_ncs_wire2w14w15w(0) AND wire_w_lg_ufm_bgpbusy12w(0);
	wire_w_lg_w_lg_w_lg_ncs_wire2w14w15w(0) <= wire_w_lg_w_lg_ncs_wire2w14w(0) AND wire_w_lg_op_complete_state13w(0);
	wire_w_lg_w_lg_ncs_wire2w14w(0) <= wire_w_lg_ncs_wire2w(0) AND op_state;
	--wire_w_lg_addr_stdly113w(0) <= addr_stdly AND addr_complete_state;
	wire_w_lg_addr_complete79w(0) <= NOT addr_complete;
	wire_w_lg_addr_complete_state107w(0) <= NOT addr_complete_state;
	wire_w_lg_ncs_wire2w(0) <= NOT ncs_wire;
	wire_w_lg_op_complete3w(0) <= NOT op_complete;
	wire_w_lg_op_complete_state13w(0) <= NOT op_complete_state;
	wire_w_lg_sck_wire1w(0) <= NOT sck_wire;
	wire_w_lg_ufm_bgpbusy12w(0) <= NOT ufm_bgpbusy;
	wire_w_lg_ufm_busy75w(0) <= NOT ufm_busy;
	--wire_w_lg_data_state114w(0) <= data_state OR wire_w_lg_addr_stdly113w(0);
	--addr_complete <= (((wire_cntr11_q(0) AND wire_cntr11_q(1)) AND wire_cntr11_q(2)) AND wire_cntr11_q(3));
	addr_complete <= '1' when wire_cntr11_q="10110" else '0';--((not wire_cntr11_q(0)) AND wire_cntr11_q(1) AND wire_cntr11_q(2) AND (not wire_cntr11_q(3)) AND wire_cntr11_q(4));
	addr_complete_state <= dffe12;--dffe12_5;
	addr_state <= dffe10;
	--addr_stdly <= addr_stdly_reg;
	circuit_reset <= ncs_wire;
	data_complete <= (((wire_cntr14_q(0) AND wire_cntr14_q(1)) AND wire_cntr14_q(2)) AND wire_cntr14_q(3));
	data_state <= dffe13_5;
	ncs_wire <= ncs;
	op_complete <= ((wire_cntr3_q(0) AND wire_cntr3_q(1)) AND wire_cntr3_q(2));
	op_complete_state <= dffe4;
	op_state <= dffe2;
	osc <= ufm_osc;
	oscena <= '1';
	read_op <= ((((((((NOT dffe5a(7)) AND (NOT dffe5a(6))) AND (NOT dffe5a(5))) AND (NOT dffe5a(4))) AND (NOT dffe5a(3))) AND (NOT dffe5a(2))) AND dffe5a(1)) AND dffe5a(0));
	read_op_state <= dffe9;
	sck_wire <= sck;
	si_wire <= si;
	so <= so_wire;
	so_wire <= wire_tri_buf15_out;
	ufm_arclk <= (((sck_wire AND addr_state) AND wire_w_lg_addr_complete_state107w(0)) OR wire_cntr14_w_lg_w_q_range89w106w(0));
	ufm_ardin <= (si_wire AND wire_w_lg_ufm_bgpbusy12w(0));
	ufm_arshft <= ((op_complete AND read_op) AND wire_w_lg_addr_complete_state107w(0));
	ufm_bgpbusy <= wire_maxii_ufm_block1_bgpbusy;
	ufm_busy <= wire_maxii_ufm_block1_busy;
	ufm_drclk <= (wire_w_lg_sck_wire1w(0) AND wire_w_lg_ufm_bgpbusy12w(0));
	ufm_drdin <= '0';
	ufm_drdout <= wire_maxii_ufm_block1_drdout;
	ufm_drshft <= (NOT (((x_Y) OR data_complete) AND read_op_state));
	ufm_erase <= '0';
	ufm_osc <= wire_maxii_ufm_block1_osc;
	ufm_oscena <= oscena;
	ufm_program <= '0';
	--PROCESS (sck_wire)
	--BEGIN
	--	IF (sck_wire = '0' AND sck_wire'event) THEN addr_stdly_reg <= addr_state;
	--	END IF;
	--END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe10 <= '0';
		ELSIF (sck_wire = '1' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe10 <= ((op_complete AND read_op) AND wire_w_lg_addr_complete79w(0));
			END IF;
			
			x_Y <= addr_state AND addr_complete;
			
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe12 <= '0';
			dffe12_5 <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe12 <= addr_complete;
			END IF;
			dffe12_5 <= dffe12;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe13 <= '0';
			dffe13_5 <= '0';
		ELSIF (sck_wire = '1' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe13 <= (addr_complete AND read_op);
			END IF;
			dffe13_5 <= dffe13;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe2 <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe2 <= wire_w_lg_op_complete3w(0);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe4 <= '0';
		ELSIF (sck_wire = '1' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe4 <= op_complete;
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(0) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(0) = '1') THEN dffe5a(0) <= wire_dffe5a_d(0);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(1) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(1) = '1') THEN dffe5a(1) <= wire_dffe5a_d(1);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(2) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(2) = '1') THEN dffe5a(2) <= wire_dffe5a_d(2);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(3) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(3) = '1') THEN dffe5a(3) <= wire_dffe5a_d(3);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(4) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(4) = '1') THEN dffe5a(4) <= wire_dffe5a_d(4);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(5) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(5) = '1') THEN dffe5a(5) <= wire_dffe5a_d(5);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(6) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(6) = '1') THEN dffe5a(6) <= wire_dffe5a_d(6);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe5a(7) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe5a_ena(7) = '1') THEN dffe5a(7) <= wire_dffe5a_d(7);
			END IF;
		END IF;
	END PROCESS;
	wire_dffe5a_d <= ( dffe5a(6 DOWNTO 0) & dffe6);
	loop0 : FOR i IN 0 TO 7 GENERATE
		wire_dffe5a_ena(i) <= wire_w_lg_w_lg_w_lg_w_lg_ncs_wire2w14w15w16w(0);
	END GENERATE loop0;
	PROCESS (sck_wire)
	BEGIN
		IF (sck_wire = '1' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe6 <= si;
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(0) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(0) = '1') THEN dffe7a(0) <= wire_dffe7a_d(0);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(1) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(1) = '1') THEN dffe7a(1) <= wire_dffe7a_d(1);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(2) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(2) = '1') THEN dffe7a(2) <= wire_dffe7a_d(2);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(3) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(3) = '1') THEN dffe7a(3) <= wire_dffe7a_d(3);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(4) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(4) = '1') THEN dffe7a(4) <= wire_dffe7a_d(4);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(5) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(5) = '1') THEN dffe7a(5) <= wire_dffe7a_d(5);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(6) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(6) = '1') THEN dffe7a(6) <= wire_dffe7a_d(6);
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire, circuit_reset)
	BEGIN
		IF (circuit_reset = '1') THEN dffe7a(7) <= '0';
		ELSIF (sck_wire = '0' AND sck_wire'event) THEN 
			IF (wire_dffe7a_ena(7) = '1') THEN dffe7a(7) <= wire_dffe7a_d(7);
			END IF;
		END IF;
	END PROCESS;
	wire_dffe7a_d <= ( dffe7a(6 DOWNTO 0) & dffe8);
	loop1 : FOR i IN 0 TO 7 GENERATE
		wire_dffe7a_ena(i) <= wire_w_lg_w_lg_w_lg_ncs_wire2w14w15w(0);
	END GENERATE loop1;
	PROCESS (sck_wire)
	BEGIN
		IF (sck_wire = '1' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe8 <= si;
			END IF;
		END IF;
	END PROCESS;
	PROCESS (sck_wire)
	BEGIN
		IF (sck_wire = '1' AND sck_wire'event) THEN 
			IF (ncs_wire = '0') THEN dffe9 <= (((op_complete_state AND read_op) AND wire_w_lg_ufm_busy75w(0)) AND wire_w_lg_ufm_bgpbusy12w(0));
			END IF;
		END IF;
	END PROCESS;
	wire_cntr11_clk_en <= wire_w_lg_w_lg_w_lg_ncs_wire2w80w81w(0);
	wire_w_lg_w_lg_w_lg_ncs_wire2w80w81w(0) <= (wire_w_lg_ncs_wire2w(0) AND wire_w_lg_addr_complete79w(0)) AND addr_state;
	cntr11 :  lpm_counter
	  GENERIC MAP (
		lpm_direction => "UP",
		lpm_port_updown => "PORT_UNUSED",
		lpm_width => wire_cntr11_q'length
	  )
	  PORT MAP ( 
		aclr => circuit_reset,
		clk_en => wire_cntr11_clk_en,
		clock => sck_wire,
		q => wire_cntr11_q
	  );
	wire_cntr14_w_lg_w_q_range89w106w(0) <= wire_cntr14_w_q_range89w(0) AND read_op_state;
	wire_cntr14_clk_en <= wire_w_lg_w_lg_w_lg_ncs_wire2w103w104w(0);
	wire_w_lg_w_lg_w_lg_ncs_wire2w103w104w(0) <= (wire_w_lg_ncs_wire2w(0) AND read_op) AND data_state;
	wire_cntr14_w_q_range89w(0) <= wire_cntr14_q(3);
	cntr14 :  lpm_counter
	  GENERIC MAP (
		lpm_direction => "UP",
		lpm_port_updown => "PORT_UNUSED",
		lpm_width => 4
	  )
	  PORT MAP ( 
		aclr => circuit_reset,
		clk_en => wire_cntr14_clk_en,
		clock => sck_wire,
		q => wire_cntr14_q
	  );
	wire_cntr3_clk_en <= wire_w_lg_w_lg_w_lg_ncs_wire2w5w6w(0);
	wire_w_lg_w_lg_w_lg_ncs_wire2w5w6w(0) <= (wire_w_lg_ncs_wire2w(0) AND wire_w_lg_op_complete3w(0)) AND op_state;
	wire_cntr3_clock <= wire_w_lg_sck_wire1w(0);
	cntr3 :  lpm_counter
	  GENERIC MAP (
		lpm_direction => "UP",
		lpm_port_updown => "PORT_UNUSED",
		lpm_width => 3
	  )
	  PORT MAP ( 
		aclr => circuit_reset,
		clk_en => wire_cntr3_clk_en,
		clock => wire_cntr3_clock,
		q => wire_cntr3_q
	  );
	maxii_ufm_block1 :  maxii_ufm
	  GENERIC MAP (
		ADDRESS_WIDTH => 9,
		ERASE_TIME => 500000000,
		INIT_FILE => "D:/KARTEN/COP/configs/COP/01_IO/IO_XML.HEX",
		OSC_SIM_SETTING => 180000,
		PROGRAM_TIME => 1600000
	  )
	  PORT MAP ( 
		arclk => ufm_arclk,
		ardin => ufm_ardin,
		arshft => ufm_arshft,
		bgpbusy => wire_maxii_ufm_block1_bgpbusy,
		busy => wire_maxii_ufm_block1_busy,
		drclk => ufm_drclk,
		drdin => ufm_drdin,
		drdout => wire_maxii_ufm_block1_drdout,
		drshft => ufm_drshft,
		erase => ufm_erase,
		osc => wire_maxii_ufm_block1_osc,
		oscena => ufm_oscena,
		program => ufm_program
	  );
	--wire_tri_buf15_out <= ufm_drdout;-- WHEN wire_tri_buf15_oe = '1' ELSE 'Z'; 
	--wire_tri_buf15_oe <= (((read_op AND read_op_state) AND wire_w_lg_data_state114w(0)) AND wire_w_lg_ncs_wire2w(0));
	PROCESS (sck_wire)
	BEGIN
		IF (sck_wire = '1' AND sck_wire'event) THEN 
			wire_tri_buf15_out <= ufm_drdout;
		END IF;
	END PROCESS;
	
	
	

 END RTL; --spi_altufm_spi_9so
--VALID FILE


LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY spi IS
	PORT
	(
		ncs		: IN STD_LOGIC ;
		sck		: IN STD_LOGIC ;
		si		: IN STD_LOGIC ;
		osc		: OUT STD_LOGIC ;
		so		: OUT STD_LOGIC 
	);
END spi;


ARCHITECTURE RTL OF spi IS

	ATTRIBUTE synthesis_clearbox: natural;
	ATTRIBUTE synthesis_clearbox OF RTL: ARCHITECTURE IS 2;
	ATTRIBUTE clearbox_macroname: string;
	ATTRIBUTE clearbox_macroname OF RTL: ARCHITECTURE IS "ALTUFM_SPI";
	ATTRIBUTE clearbox_defparam: string;
	ATTRIBUTE clearbox_defparam OF RTL: ARCHITECTURE IS "access_mode=READ_ONLY;byte_of_page_write=8;config_mode=EXTENDED;erase_time=500000000;intended_device_family=MAX II;lpm_file=D:/KARTEN/COP/configs/COP/01_IO/IO_XML.HEX;lpm_hint=UNUSED;lpm_type=altufm_spi;osc_frequency=180000;program_time=1600000;width_ufm_address=9;";
	SIGNAL sub_wire0	: STD_LOGIC ;
	SIGNAL sub_wire1	: STD_LOGIC ;



	COMPONENT spi_altufm_spi_9so
	PORT (
			ncs	: IN STD_LOGIC ;
			si	: IN STD_LOGIC ;
			so	: OUT STD_LOGIC ;
			osc	: OUT STD_LOGIC ;
			sck	: IN STD_LOGIC 
	);
	END COMPONENT;

BEGIN
	so    <= sub_wire0;
	osc    <= sub_wire1;

	spi_altufm_spi_9so_component : spi_altufm_spi_9so
	PORT MAP (
		ncs => ncs,
		si => si,
		sck => sck,
		so => sub_wire0,
		osc => sub_wire1
	);



END RTL;
