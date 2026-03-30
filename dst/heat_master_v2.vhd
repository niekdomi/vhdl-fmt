--------------------------------------------------------------------------------
-- heat_master_v2.vhd
--------------------------------------------------------------------------------
--
--	project	 	: INFO-HEAT
--	programmer	: C. Leuthold, INDEL AG
--	date		: 13.03.2008
--	version	 	: 0.00
--	language	: VHDL 
--	system		: ise / v2p
--
--	purpose
--				heat_master
--				preambles:
--				il	: infolink
--				ils : infolink slave
--				ilm : infolink master
--				ib	: impbus
--				sio : sio
--				sd	: sdram
--				p	: peripheriebus
--				plb	: plb
--				lan : lan
--				dpr : dualport ram
--				reg : register
--				mc	: memory controller
--				adc : analog digital converter
--				sr  : shift register
--				log : logic
--				dr  : dualport ram register
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 1.00
--		13.03.2008-le:	- create
-- 1.01nr
--		29.04.2008-le: 	- change safety communication
--		12.08.2008-qfu:	- removed SSI_Mode(3) from Error_Control
--						- added disabling of the digital outputs under bus error conditions again.
--						- added the additional port of the new Esart macro.
-- 1.02 03.06.2009-le:	- create rev 1.02 with eq. safety fpga to have a clearly
--						  difference to some delivered unreleased rev 1.01.
--						  functional is no difference between 1.01 and 1.02.
-- 1.03 02.07.2009-le:	- clear dpr when Fatal_Zone_Error to detect bus errors
--						- remove busdata direct to out 0..11
--
--		05.08.2009-le:	- rename to heat_master_v2.vhd
--------------------------------------------------------------------------------
--$Rev:: 1155                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-08-05 10:16:33 +0200 (Mi., 05 Aug 2009)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library dcm_clk_module;
use dcm_clk_module.ALL;

library opbif_extmem;
use opbif_extmem.ALL;

library opbif_register;
use opbif_register.ALL;

library dpr1aNb;
use dpr1aNb.ALL;

library dpr2infoMS;
use dpr2infoMS.all;

library ADS8361_if;
use ADS8361_if.ADS8361_if;

library shift_register;
use shift_register.shift_register;

library dpr2HEATReg;
use dpr2HEATReg.dpr2HEATReg;

library ppc_module;
use ppc_module.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

use heat_master.heat_master_pkg.all;

library esart;
use esart.ALL;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity heat_master is
  generic (
	C_SDRAM_WIDTH : integer := 32;
	C_REVISION : std_logic_vector := x"103";
	C_FELDBUS : integer range 0 to 1 := DF_HEAT_PKG_INFOLINK;
	C_DEV_BUILD : integer range 0 to 15 := 0 -- 0 for releases
  );
  port (
	i_sys_clk : in std_logic;
	-- sio ---------------------------------------------------------------------
	ni_sioRX : in std_logic;
	no_sioTX : out std_logic;
	-- sdram -------------------------------------------------------------------
	o_sdADR : out std_logic_vector(11 downto 0);
	o_sdBAdr : out std_logic_vector(1 downto 0);
	b_sdDAT : inout std_logic_vector(31 downto 0);
	o_sdDQM : out std_logic_vector(3 downto 0);
	no_sdCAS : out std_logic;
	no_sdCS : out std_logic;
	no_sdRAS : out std_logic;
	no_sdWE : out std_logic;
	o_sdCKE : out std_logic;
	o_sdCLK : out std_logic;
	-- periphery bus -----------------------------------------------------------
	o_pADR : out std_logic_vector(20 downto 0);
	b_pDAT : inout std_logic_vector(15 downto 0);
	o_pRnW : out std_logic;
	no_pOE : out std_logic;
	no_Flash_CEn : out std_logic;
	-- info link ---------------------------------------------------------------
	o_ilTX : out std_logic;
	ni_ilRX : in std_logic;
	-- i2c bus -----------------------------------------------------------------
	o_SCL : out std_logic;
	b_SDA : inout std_logic;
	-- adc ---------------------------------------------------------------------
	no_ADC_cs : out std_logic;
	o_ADC_clk : out std_logic;
	o_ADC_convst : out std_logic;
	o_ADC_addr0 : out std_logic;
	i_ADC_din_a : in std_logic;
	i_ADC_din_b : in std_logic;
	-- serial adc mux ----------------------------------------------------------
	o_asrClk : out std_logic;
	o_asrLoad : out std_logic;
	o_asrData : out std_logic;
	i_asrData : in std_logic;
	i_asrData_fb : in std_logic;
	-- serial ios --------------------------------------------------------------
	o_dsrClk : out std_logic;
	o_dsrLoad : out std_logic;
	o_dsrData : out std_logic;
	i_dsrData : in std_logic;
	-- sihtregister output enable ----------------------------------------------
	no_sr_out_en : out std_logic;
	-- serial com safty --------------------------------------------------------
	o_ssrClk : out std_logic;
	o_ssrLoad : out std_logic;
	o_ssrData : out std_logic;
	i_ssrData : in std_logic;
--	-- safty reserve -----------------------------------------------------------
--	o_srGClk : out std_logic;
--	b_srData : inout std_logic_vector(3 downto 0);
--	-- 40 MHz quarz ------------------------------------------------------------
	i_ESART_CLK : in std_logic := L;
	-- jtag port ---------------------------------------------------------------
	b_jtgTCK : inout std_logic;
	b_jtgTMS : inout std_logic;
	b_jtgTDO : inout std_logic;
	b_jtgTDI : inout std_logic
  );
end heat_master;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of heat_master is
	----------------------------------------------------------------------------
	-- constants 
	----------------------------------------------------------------------------
	constant DF_REG_LENGTH : integer := 16;
	constant DF_SR_IOS : integer := 4*8;
	
	constant DF_INC_CNT_LNG : integer := 14;

	constant DF_OPB_IF_REG    : integer := 0;
	constant C_BASEADDR_OPB_IF_1 : std_logic_vector := X"8000_0800";
	constant C_HIGHADDR_OPB_IF_1 : std_logic_vector := X"8000_08ff";
	
	constant DF_OPB_IF_EXTMEM : integer := 1;
	constant C_BASEADDR_OPB_IF_2 : std_logic_vector := X"E000_0000";
	constant C_HIGHADDR_OPB_IF_2 : std_logic_vector := X"EFFF_FFFF";
	
	constant DF_NUM_OPB_IF : integer := 2;
	
	constant C_NUM_UARTS : integer := 1;
	
	constant C_ISOCM : integer := 32; -- kilobyte
	constant C_NUM_OF_BOOT_BRAMS : integer := C_ISOCM/2;
	
	constant DF_FLAGS : std_logic_vector := "0000" or DF_FLG_ISOCM_32 or DF_FLG_CIRQ;
	
	constant DF_REVISION : std_logic_vector(31 downto 0) := pkg_rev_reg(DF_PKG_TARGET_HEAT, C_DEV_BUILD, DF_FLAGS, C_SDRAM_WIDTH, C_FELDBUS, C_REVISION);
	constant DF_SVN_REV : std_logic_vector(31 downto 0) := get_dec_from_string("$Rev: 1155 $", 31);
	----------------------------------------------------------------------------
	-- type declarations
	----------------------------------------------------------------------------
	
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	
	signal net_gnd : std_logic := L;
	signal net_vcc : std_logic := H;
	signal GND32 : std_logic_vector(31 downto 0) := (others => L);
	
	-- resets
	signal periph_rst : std_logic;
	signal periph_rst66 : std_logic := H;
	-- uart
	signal sio_rxInt : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_txInt : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nRX : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nTX : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nRTS : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nCTS : std_logic_vector(C_NUM_UARTS-1 downto 0);
	
	-- sdram bidis
	signal sdDAT_O : std_logic_vector(b_sdDAT'range);
	signal sdDAT_T : std_logic_vector(b_sdDAT'range) := (others => H);
	signal sdDQM : std_logic_vector(o_sdDQM'range) := (others => L);
	-- register and interrupt controller
	signal reg_MasterSlave : std_logic;
	signal reg_ilCmpEn : std_logic;
	signal reg_CIRQ0en : std_logic;
	signal reg_CIRQ1en : std_logic;
	signal reg_Master_Ctrl : std_logic_vector(7 downto 0);
	signal reg_Diag_ON : std_logic;
	signal reg_Diag_invers : std_logic;
	signal reg_CardTyp : std_logic_vector(2 downto 0);
	signal reg_Interrups : std_logic_vector(DF_INC_CNT_LNG-1 downto 0) := (others => L);
	signal reg_ppc_ext_irq : std_logic;
	signal reg_ppc_crit_irq : std_logic := L;
	signal reg_MemConfig : std_logic_vector(31 downto 0) := (others => L);
	signal reg_nOkLed : std_logic;
	signal reg_nErrorLed : std_logic;
	signal reg_AddrS : std_logic_vector(7 downto 0);
	signal reg_AddrSin : std_logic_vector(7 downto 0) := (others => L);
	signal reg_ExtMem_OFF : std_logic;
	-- reg bidis
	signal reg_i2cSDA_I : std_logic;
	signal reg_i2cSDA_O : std_logic;
	signal reg_i2cSDA_T : std_logic;
	signal reg_jtgTCK_I : std_logic;
	signal reg_jtgTCK_O : std_logic;
	signal reg_jtgTCK_T : std_logic;
	signal reg_jtgTMS_I : std_logic;
	signal reg_jtgTMS_O : std_logic;
	signal reg_jtgTMS_T : std_logic;
	signal reg_jtgTDO_I : std_logic;
	signal reg_jtgTDO_O : std_logic;
	signal reg_jtgTDO_T : std_logic;
	signal reg_jtgTDI_I : std_logic;
	signal reg_jtgTDI_O : std_logic;
	signal reg_jtgTDI_T : std_logic;
	-- memory controller
	-- memory controller bidis
	signal mc_data_O : std_logic_vector(b_pDAT'range);
	signal mc_data_T : std_logic_vector(b_pDAT'range);
	-- dcm clocks
	signal dcmLocked : std_logic;
	signal ocm_clk : std_logic;
	signal ppc_clk : std_logic;
	signal plb_clk : std_logic;
	signal opb_clk : std_logic;
	signal QuarzClk : std_logic;
	-- infolink
	signal il_nPowerLed : std_logic;
	signal il_nLinkLed : std_logic;
	signal il_wdog : std_logic;
	signal ils_int0 : std_logic;
	signal ils_int1 : std_logic;
	signal ils_int4 : std_logic;
	signal ils_AddrS_IMP2com : std_logic_vector(7 downto 0);
	signal ilm_int : std_logic;
	signal ilm_JobIRQ : std_logic;
	signal ilm_CIRQ : std_logic;
	signal ilm_Error : std_logic;
	signal ilm_Ovrun : std_logic;
	signal ilm_Or1ms : std_logic;
	signal ils_blinki : std_logic;
	signal ils66_int0 : std_logic;
	signal ils66_int1 : std_logic;
	signal ils66_int4 : std_logic;
	signal ilm66_int : std_logic;
	signal ilm66_JobIRQ : std_logic;
	signal ilm66_CIRQ : std_logic;
	signal ilm66_Error : std_logic;
	signal ilm66_Ovrun : std_logic;
	signal ilm66_Or1ms : std_logic;
	signal il66_nLinkLed : std_logic;
	signal ils66_blinki : std_logic;
	signal il66_nPowerLed : std_logic;
	signal il66_wdog : std_logic := L;
	signal il66_WDOG_TIME : std_logic_vector(1 downto 0) := "10";
	-- plb bram interface
	signal plb2bram_Rst : std_logic_vector(0 to 0) := (others => L);
	signal plb2bram_Clk : std_logic_vector(0 to 0) := (others => L);
	signal plb2bram_EN : std_logic_vector(0 to 0) := (others => L);
	signal plb2bram_WEN : std_logic_vector(0 to 7) := (others => L);
	signal plb2bram_Addr : std_logic_vector(0 to 31) := (others => L);
	signal plb2bram_Data : std_logic_vector(0 to 63) := (others => L);
	signal bram2plb_Data : std_logic_vector(0 to 63) := (others => L);
	-- infolink dpr
	signal il2dpr_Addr : std_logic_vector(10 downto 0);
	signal il2dpr_Clk : std_logic;
	signal dpr2il_Data : std_logic_vector(31 downto 0);
	signal il2dpr_Data : std_logic_vector(31 downto 0);
	signal il2dpr_EN : std_logic;
	signal il2dpr_Rst : std_logic;
	signal il2dpr_WEN : std_logic_vector(3 downto 0);
	-- register dpr
	signal reg2dpr_Addr : std_logic_vector(8 downto 0);
	signal reg2dpr_Clk : std_logic;
	signal reg2dpr_Data : std_logic_vector(127 downto 0);
	signal dpr2reg_Data : std_logic_vector(127 downto 0);
	signal reg2dpr_EN : std_logic;
	signal reg2dpr_Rst : std_logic;
	signal reg2dpr_WEN : std_logic_vector(3 downto 0);
	-- adcs
	signal adc_convst : std_logic;							-- pin
	signal adc_dout_a : std_logic_vector(16-1 downto 0);
	signal adc_dout_b : std_logic_vector(16-1 downto 0);
	signal adc_d_ready : std_logic;
	-- adc mux
	signal adc_mux_ka : std_logic := L;
	signal adc_mux_kb : std_logic := L;
	signal adc_mux_kc : std_logic := L;
	signal adc_mux_kd : std_logic := L;
	signal adc_mux_nkd : std_logic := L;
	signal adc_gain_a0 : std_logic := L;
	signal adc_gain_a1 : std_logic := L;
	signal adc_mux_kf : std_logic := L;
	signal adc_mux_ke : std_logic := L;
	signal adc_mux_kx : std_logic := L;
	signal adc_mux_kz : std_logic := L;
	signal adc_mux_ky : std_logic := L;
	-- shift_register
	signal sr_outputs : std_logic_vector(DF_SR_IOS-1 downto 0) := (others => L);
	signal sr_inputs : std_logic_vector(DF_SR_IOS-1 downto 0);
	signal sr_addrsw : std_logic_vector(3 downto 0);
	signal sr_GL_Sdat : std_logic;
	signal sr_MAX2nMAX4 : std_logic;
	signal sr_n_ext_board_mtd : std_logic;
	signal sr_digital_inputs : std_logic_vector(31 downto 0);
	signal sr_out_en : std_logic := L;
	signal srLoad : std_logic;
	signal sr_start : std_logic;
	signal srLoadREdge : std_logic;
	signal srLoadold : std_logic := H;
	
	-- adc sr
	signal asrLoadFEdge : std_logic := L;
	signal asrLoadREdge : std_logic := L;
	signal asrLoad : std_logic := L;
	signal asrLoadold : std_logic := L;
	signal asr_outputs  : std_logic_vector(15 downto 0);
	signal asr_out_en : std_logic := L;
	signal asr_inputs  : std_logic_vector(15 downto 0);
	-- io sr
	signal dsr_out_en : std_logic := L;
	signal sr_digital_inputs_fb : std_logic;
	
	-- dpr register
	signal dr_flags : std_logic_vector(31 downto 0);
	signal dr_digital_outputs : std_logic_vector(31 downto 0);
	signal dr_TimerMax : std_logic_vector(31 downto 0);
	signal dr_TimerCmp0 : std_logic_vector(31 downto 0);
	signal dr_TimerCmp1 : std_logic_vector(31 downto 0);
	signal dr_TimerCmp2 : std_logic_vector(31 downto 0);
	
	-- logic
	-- flags bit no.
	constant FL_OUT_EN : integer := 31;
	constant FL_ADC_EN : integer := 30;
	constant FL_ADC_CONT : integer := 29;
	constant FL_DSR_CONT : integer := 28;
	constant FL_STATUS_WR_CONT : integer := 27;
	constant FL_ESARD_OUT_CTRL : integer := 26;
	constant FL_ASR_FB : integer := 0;
	constant FL_DSR_FB : integer := 1;
	
	-- status bit no.
	constant ST_IL_WD  : integer := 0;
	constant ST_OUTS_WD : integer := 1;
	constant ST_SAFETY_WD : integer := 2;
	constant ST_BOARD : integer := 12;
	constant ST_ASR_FB : integer := 13;
	constant ST_DSR_FB : integer := 14;
	constant ST_EXT_BOARD : integer := 15;
	
	signal log_status : std_logic_vector(31 downto 0);
	signal log_conv_0_n_1 : std_logic := L;
	signal log_cADCx0 : std_logic := L;
	signal log_cADCx1 : std_logic := L;
	signal log_EnDataO :  std_logic;
	signal log_adc_next_ch : std_logic;
	signal log_adc_start_conv : std_logic := L;
	signal log_data_ready_old : std_logic;
	signal log_digital_sr_fb : std_logic;
	signal log_analog_sr_fb : std_logic;
	
	-- unused interrupts
	signal ib_BusInt : std_logic := L;
	signal ib_RXendInt : std_logic := L;
	signal nLan_Int : std_logic := L;
	signal sio2_rxInt : std_logic := L;
	signal sio2_txInt : std_logic := L;
	-- adc
	type t_adc_state is (idle,start_next_ch,gnd_ref,wait_gr_done,wait_Xus,change_ch);
	signal adc_state : t_adc_state := idle;
	signal gnd_ref_cnt : std_logic_vector(4 downto 0);
	signal dr_adc_job : std_logic_vector(15 downto 0);	-- info-fad style
	signal saved_adc_job : std_logic_vector(15 downto 0);
	signal asr_start : std_logic := L;
	signal adc_1us_cnt : std_logic_vector(6 downto 0) := (others => L);
	signal adc_1us : std_logic := L;
	signal adc_new_ch : std_logic := L;
	signal fe_adc_convst : std_logic;
	signal adc_convst_n1 : std_logic := L;
	signal adc_din_a : std_logic_vector(0 downto 0);
	signal adc_din_b : std_logic_vector(0 downto 0);
	
	signal Test_v32 : std_logic_vector(31 downto 0);
	signal Test2_v32 : std_logic_vector(31 downto 0) := (others => L);
	
	constant ADDR_WIDTH : integer := 11; --log2(BRAM size in byte)
	constant DF_ADDR_HIGH : integer := 32-3;--ppcaddr width (64bit word)
--																							segment & r!w & address
	constant DF_OUT_WD_ADDR : std_logic_vector(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH+2) := "01" & "0" & x"400";
	constant DF_SAFETY_WD_ADDR : std_logic_vector(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH+2) := "01" & "0" & x"800";
	
	signal ppc_dpr_wr_outputs : std_logic;
	signal ppc_dpr_wr_safety : std_logic;
	signal ppc_2_5ms_wdog_cnt : std_logic_vector(18 downto 0);
	
	signal ppc_wdog_outputs : std_logic;
	signal ppc_wdog_safety : std_logic;
	-- opb interfaces: 1. reg, 2. extmem
	signal opbif_rd_acc_done : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_rd_data : std_logic_vector(DF_NUM_OPB_IF*32-1 downto 0);
	signal opbif_wr_acc_done : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_addr : std_logic_vector(DF_NUM_OPB_IF*32-1 downto 0);
	signal opbif_byte_ebl : std_logic_vector(DF_NUM_OPB_IF*32/8-1 downto 0);
	signal opbif_rd_acc : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_wr_acc : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_wr_data : std_logic_vector(DF_NUM_OPB_IF*32-1 downto 0);
	
	-- timer -------------------------------------------------------------------
	signal tm_TimerMax : std_logic_vector(16 downto 0);
	signal tm_TimerCmp0 : std_logic_vector(16 downto 0);
	signal tm_TimerCmp1 : std_logic_vector(16 downto 0);
	signal tm_TimerCmp2 : std_logic_vector(16 downto 0);
	signal tm_cnt : std_logic_vector(16 downto 0) := (others => L);
	signal tm_cmp0 : std_logic := L;
	signal tm_cmp1 : std_logic := L;
	signal tm_cmp2 : std_logic := L;
	signal tm_enable : std_logic;
	signal tm_CmpEn0 : std_logic;
	signal tm_CmpEn1 : std_logic;
	signal tm_CmpEn2 : std_logic;
	signal tm_timer : std_logic_vector(31 downto 0) := (others => L);
	signal tm0 : std_logic;
	signal cTim0 : std_logic;
	signal TimIrq : std_logic_vector(7 downto 0) := (others => L);
	
	signal cSr : std_logic;
	
	signal sc_cSafety : std_logic := L;
	signal sc_rAddr : std_logic_vector(3 downto 0) := (others => L);
	signal sc_wAddr : std_logic_vector(3 downto 0) := (others => L);
	signal sc_DataOut : std_logic_vector(127 downto 0);
	signal sc_DataIn : std_logic_vector(127 downto 0) := (others => L);
	
	signal ESART_ERROR_LED  : std_logic;
	
begin -- architecture ----------------------------------------------------------
	sio_nRX(0) <= ni_sioRX;
	no_sioTX <= sio_nTX(0);
	
	o_sdDQM <= sdDQM;
	
	-- unused interrupts
	ib_BusInt <= L;
	ib_RXendInt <= L;
	nLan_Int <= L;
	sio2_rxInt <= L;
	sio2_txInt <= L;
	-- interrupts
	reg_Interrups( 0) <= ils_int0;
	reg_Interrups( 1) <= ils_int1;
	reg_Interrups( 2) <= ils_int4;
	reg_Interrups( 3) <= L;
	reg_Interrups( 4) <= sio_txInt(0);
	reg_Interrups( 5) <= sio_rxInt(0);
	reg_Interrups( 6) <= nLan_Int;
	reg_Interrups( 7) <= ib_BusInt;
	reg_Interrups( 8) <= ib_RXendInt;
	reg_Interrups( 9) <= L;
	reg_Interrups(10) <= ilm_int;
	reg_Interrups(11) <= TimIrq(TimIrq'high);
	reg_Interrups(12) <= sio2_txInt;
	reg_Interrups(13) <= sio2_rxInt;
	
	reg_AddrSin <= "0000" & sr_addrsw;
	
	Test2_v32(15  downto 0) <= asr_inputs;
	Test_v32 <= tm_Timer;
	-- clocks ------------------------------------------------------------------
	clk_mod : entity dcm_clk_module.dcm_clk_module
	generic map (
		C_MHZ => 66,
		C_DDR_SUPORT => 0,
		C_NO_INPUT_BUFG => 0
		) 
	port map (
		i_Quarz => i_sys_clk,
		o_dcmLocked => dcmLocked,
		o_Quarz => QuarzClk,
		o_Quarz_div2 => open,
		o_opb_clk => opb_clk,
		o_plb_clk => plb_clk,
		o_2xplb_clk => open,
		o_ocm_clk => ocm_clk,
		o_ppc_clk => ppc_clk
	);
	
	-- ppc-inst: uart, plb-sdram, bootram, plb-bram and 2 opb-interface --------
	ppc_inst : entity ppc_module.ppc_module
	generic map (
		C_PLB_CHIPSCOPE => 0,
		C_INDEL_PLB_BRAM => 0,
		C_INDEL_PLB2OPB => 0,
		C_SDRAM_WIDTH => C_SDRAM_WIDTH,
		C_NUM_PLBBRAM_IF => 1,
		C_BASEADDR_PLBBRAM_IF_1 => X"7000_0000",
		C_HIGHADDR_PLBBRAM_IF_1 => X"70FF_FFFF",
		C_NUM_OPB_IF => DF_NUM_OPB_IF,
		C_BASEADDR_OPB_IF_1 => C_BASEADDR_OPB_IF_1,
		C_HIGHADDR_OPB_IF_1 => C_HIGHADDR_OPB_IF_1,
		C_BASEADDR_OPB_IF_2 => C_BASEADDR_OPB_IF_2,
		C_HIGHADDR_OPB_IF_2 => C_HIGHADDR_OPB_IF_2,
		C_NUM_UARTS => C_NUM_UARTS,
		C_BUS_CLK_FREQ => 99_000_000,
		C_OPB_BOOT_RAM => 1,
		C_ISOCM_BOOT_RAM => 1,
		C_NUM_OF_BOOT_BRAMS => C_NUM_OF_BOOT_BRAMS
	)
	port map (
		-- reset in
		ni_reset => net_vcc,
		-- reset out
		o_periph_rst => periph_rst,
		-- clocks and dcm
		i_dcmLocked => dcmLocked,
		i_ocm_clk => ocm_clk,
		i_ppc_clk => ppc_clk,
		i_plb_clk => plb_clk,
		i_opb_clk => opb_clk,
		-- uart
		ni_sioRX => sio_nRX,
		no_sioTX => sio_nTX,
		ni_sioRTS => sio_nRTS,
		no_sioCTS => sio_nCTS,
		o_sio_txInt => sio_txInt,
		o_sio_rxInt => sio_rxInt,
		-- sdram
		o_sdADR => o_sdADR,
		o_sdBAdr => o_sdBAdr,
		o_sdDQM => sdDQM(C_SDRAM_WIDTH/8-1 downto 0),
		no_sdCAS => no_sdCAS,
		no_sdCS => no_sdCS,
		no_sdRAS => no_sdRAS,
		no_sdWE => no_sdWE,
		o_sdCKE => o_sdCKE,
		o_sdCLK => o_sdCLK,
		b_sdDAT_I => b_sdDAT(C_SDRAM_WIDTH-1 downto 0),
		b_sdDAT_O => sdDAT_O(C_SDRAM_WIDTH-1 downto 0),
		b_sdDAT_T => sdDAT_T(C_SDRAM_WIDTH-1 downto 0),
		-- opb interface
		o_opbif_addr => opbif_addr,
		o_opbif_rd_acc => opbif_rd_acc,
		o_opbif_wr_acc => opbif_wr_acc,
		o_opbif_byte_ebl => opbif_byte_ebl,
		o_opbif_wr_data => opbif_wr_data,
		i_opbif_rd_data => opbif_rd_data,
		i_opbif_rd_acc_done => opbif_rd_acc_done,
		i_opbif_wr_acc_done => opbif_wr_acc_done,
		-- plbbram interface
		o_plbbram_Rst => plb2bram_Rst,
		o_plbbram_Clk => plb2bram_Clk,
		o_plbbram_EN => plb2bram_EN,
		o_plbbram_WEN => plb2bram_WEN,
		o_plbbram_Addr => plb2bram_Addr,
		i_plbbram_Data => bram2plb_Data,
		o_plbbram_Data => plb2bram_Data,
		-- interrupt
		i_ppc_ext_irq => reg_ppc_ext_irq,
		i_ppc_crit_irq => reg_ppc_crit_irq
	);
	-- first opb-interface 0x80000800: register and irq-ctrl -------------------
	
	opbif_register_max2 : entity opbif_register.opbif_register
	generic map (
		-- LEDs
		C_INIT_LEDREG => x"0000_0000",
		-- INFOLINK
		C_INIT_INFOREG => x"0000_1800",
		-- Memory read and write access times for all memory banks
		C_INIT_MEMREG => x"000B_0000",
		-- HW Revision
		C_REVISION => DF_REVISION,
		C_NUM_INTR_INPUTS => DF_INC_CNT_LNG,
		C_KIND_OF_INTR => "11111111111111111111101111001111",
		C_POS_N_NEG => "11111111111111111111110000111111",
		-- Target typ: DF_TARGET_IMP2=0, DF_TARGET_SAC2=1, DF_TARGET_MAX2=2, ...
		C_TARGET => DF_PKG_TARGET_MAX4,
		-- CARD_TYP: default imp2 typ
		-- wie imp2
		C_CARD_TYP => DF_PKG_CARD_TYP_IMP2,
		C_SYNC_IL => 1,
		C_DWIDTH => 32,
		C_AWIDTH => 32,
		C_SVN_NO => DF_SVN_REV
	)
	port map (
		i_Clk => opb_clk,
		i_Rst => periph_rst,
		-- opbif
		i_addr => opbif_addr(DF_OPB_IF_REG*32+31 downto DF_OPB_IF_REG*32),
		i_rd_acc => opbif_rd_acc(DF_OPB_IF_REG),
		i_wr_acc => opbif_wr_acc(DF_OPB_IF_REG),
		i_byte_ebl => opbif_byte_ebl(DF_OPB_IF_REG*4+3 downto DF_OPB_IF_REG*4),
		i_wr_data => opbif_wr_data(DF_OPB_IF_REG*32+31 downto DF_OPB_IF_REG*32),
		o_rd_data => opbif_rd_data(DF_OPB_IF_REG*32+31 downto DF_OPB_IF_REG*32),
		o_rd_acc_done => opbif_rd_acc_done(DF_OPB_IF_REG),
		o_wr_acc_done => opbif_wr_acc_done(DF_OPB_IF_REG),
		-- register and irq-ctrl signals
		o_MemConfig => reg_MemConfig,
		no_OKLed => reg_nOkLed,
		no_ErrorLed => reg_nErrorLed,
		ni_PowerLed => il_nPowerLed,
		ni_LinkLed => il_nLinkLed,
		ni_LanLnkLed => net_gnd,
		ni_LanRXLed => net_gnd,
		o_LanLnkLed => open,
		no_LanRXLed => open,
		i_il_Clk => QuarzClk,
		o_CIRQ0en => reg_CIRQ0en,
		o_CIRQ1en => reg_CIRQ1en,
		o_IMPCmpEn => reg_ilCmpEn,
		i_blinki => ils_blinki,
		i_AddrS => reg_AddrSin,
		o_AddrS => reg_AddrS,
		o_CardTyp => reg_CardTyp,
		o_MasterSlave => reg_MasterSlave,
		o_Master_Ctrl => reg_Master_Ctrl,
		o_Diag_ON => reg_Diag_ON,
		o_Diag_invers => reg_Diag_invers,
		i_JobIRQ => ilm_JobIRQ,
		i_CIRQ => ilm_CIRQ,
		i_Error => ilm_Error,
		i_Ovrun => ilm_Ovrun,
		i_Or1ms => ilm_Or1ms,
		i_BatCmp => net_gnd,
		o_impbusGoNRst => open,
		o_chip_reset => open,
		o_ExtMem_OFF => reg_ExtMem_OFF,
		i_Intr => reg_Interrups,
		o_Irq => reg_ppc_ext_irq,
		o_CritIrq => reg_ppc_crit_irq,
		i_Free1 => Test_v32,
		i_Free2 => Test2_v32,
		o_i2cSCL => o_SCL,
		b_i2cSDA_I => b_SDA,
		b_i2cSDA_O => reg_i2cSDA_O,
		b_i2cSDA_T => reg_i2cSDA_T,
		b_jtgTCK_I => b_jtgTCK,
		b_jtgTCK_O => reg_jtgTCK_O,
		b_jtgTCK_T => reg_jtgTCK_T,
		b_jtgTMS_I => b_jtgTMS,
		b_jtgTMS_O => reg_jtgTMS_O,
		b_jtgTMS_T => reg_jtgTMS_T,
		b_jtgTDO_I => b_jtgTDO,
		b_jtgTDO_O => reg_jtgTDO_O,
		b_jtgTDO_T => reg_jtgTDO_T,
		b_jtgTDI_I => b_jtgTDI,
		b_jtgTDI_O => reg_jtgTDI_O,
		b_jtgTDI_T => reg_jtgTDI_T
	);
	-- second opb-interface 0xE0000000: flash and shared-pins ------------------
	--0xE0000000..0xEFFFFFFF: flash
	
	opbif_extmem_max2 : entity opbif_extmem.opbif_extmem
	generic map (
		-- Target typ
		C_TARGET => DF_PKG_TARGET_MAX4,		-- DF_TARGET_IMP2=0, DF_TARGET_SAC2=1, DF_TARGET_MAX2=2, ...
		--Generics set for IPIF
		C_DWIDTH => 32,
		C_AWIDTH => 32
		)
	port map (
		-- System Port Declarations -------------------------------------------
		i_Clk => opb_clk,
		i_Rst => periph_rst,
		-- opbif
		i_addr => opbif_addr(DF_OPB_IF_EXTMEM*32+31 downto DF_OPB_IF_EXTMEM*32),
		i_rd_acc => opbif_rd_acc(DF_OPB_IF_EXTMEM),
		i_wr_acc => opbif_wr_acc(DF_OPB_IF_EXTMEM),
		i_byte_ebl => opbif_byte_ebl(DF_OPB_IF_EXTMEM*4+3 downto DF_OPB_IF_EXTMEM*4),
		i_wr_data => opbif_wr_data(DF_OPB_IF_EXTMEM*32+31 downto DF_OPB_IF_EXTMEM*32),
		o_rd_data => opbif_rd_data(DF_OPB_IF_EXTMEM*32+31 downto DF_OPB_IF_EXTMEM*32),
		o_rd_acc_done => opbif_rd_acc_done(DF_OPB_IF_EXTMEM),
		o_wr_acc_done => opbif_wr_acc_done(DF_OPB_IF_EXTMEM),
		-- ctrl singnals 
--		i_MemCnt_OFF => reg_ExtMem_OFF,
		i_ConfReg => reg_MemConfig,
		-- Memory signals -----------------------------------------------------
		o_Mem_A => o_pADR,
		b_Mem_DQ_I => b_pDAT,
		b_Mem_DQ_O => mc_data_O,
		b_Mem_DQ_T => mc_data_T,
		no_Flash_CEn => no_Flash_CEn,
		no_Mem_OEN => no_pOE,
		no_Mem_WEN => o_pRnW
	);
	-- dpr: side a plb, side b infolink and register ---------------------------
	fieldbus_dpr : entity dpr1aNb.dpr1anb
	generic map (
		C_MEMSIZE => 8192,
		C_PORT_DWIDTH => 64,
		C_PORT_AWIDTH => 32,
		C_NUM_WE => 8,
		C_FAMILY => "virtex2p",
		C_NUM_OF_BLOCKS => 2,
		C_PORT_B0_DWIDTH => 32,
		C_PORT_B0_AWIDTH => 11,
		C_B0_BRAM_IF_SUPPORT => 0,
		C_PORT_B1_DWIDTH => 128,
		C_PORT_B1_AWIDTH => 9,
		C_B1_BRAM_IF_SUPPORT => 0
	)
	port map (
		-- plb bram port
		i_Rst_A => plb2bram_Rst(0),
		i_Clk_A => plb2bram_Clk(0),
		i_EN_A => plb2bram_EN(0),
		i_WEN_A => plb2bram_WEN(0 to 7),
		i_Addr_A => plb2bram_Addr(0 to 31),
		o_Data_A => bram2plb_Data(0 to 63),
		i_Data_A => plb2bram_Data(0 to 63),
		-- infolink bram port
		i_Rst_B0 => il2dpr_Rst,
		i_Clk_B0 => il2dpr_Clk,
		i_EN_B0 => il2dpr_EN,
		i_WEN_B0 => il2dpr_WEN,
		i_Addr_B0 => il2dpr_Addr,
		o_Data_B0 => dpr2il_Data,
		i_Data_B0 => il2dpr_Data,
		-- register bram port
		i_Rst_B1 => reg2dpr_Rst,
		i_Clk_B1 => reg2dpr_Clk,
		i_EN_B1 => reg2dpr_EN,
		i_WEN_B1 => reg2dpr_WEN,
		i_Addr_B1 => reg2dpr_Addr,
		o_Data_B1 => dpr2reg_Data,
--		o_Parity_AB1 => PPCTouched,
		i_Data_B1 => reg2dpr_Data
	);
	
	ppcwatchdogs : process(opb_clk)
	begin
		if rising_edge(opb_clk) then
			if (periph_rst=H) then
				ppc_dpr_wr_outputs <= L;
				ppc_dpr_wr_safety <= L;
				ppc_2_5ms_wdog_cnt <= (others => L);
				ppc_wdog_outputs <= H;
			else
				ppc_2_5ms_wdog_cnt <= ppc_2_5ms_wdog_cnt + 1;
				-- watchdogs
				if (ppc_2_5ms_wdog_cnt(18)=H) then -- 2.65 ms
					ppc_wdog_outputs <= not ppc_dpr_wr_outputs;
					ppc_dpr_wr_outputs <= L;
					ppc_wdog_safety <= not ppc_dpr_wr_safety;
					ppc_dpr_wr_safety <= L;
					ppc_2_5ms_wdog_cnt <= (others => L);
				end if;
				-- write comparators
				if (plb2bram_EN(0)=H and plb2bram_Addr(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH)=DF_OUT_WD_ADDR(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH) and plb2bram_WEN(0 to 7)/=0) then -- write one or more bytes from 0x70002400 to 0x70002403
					ppc_dpr_wr_outputs <= H;
				end if;
				-- write comparators
				if (plb2bram_EN(0)=H and plb2bram_Addr(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH-5)=DF_SAFETY_WD_ADDR(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH-5) and plb2bram_WEN(0 to 7)/=0) then -- write one or more bytes from 0x70002800 to 0x700028fc
					ppc_dpr_wr_safety <= H;
				end if;
				
			end if;
		end if;
	end process ppcwatchdogs;
	
	-- field bus ---------------------------------------------------------------
	inst_info_link : IF (C_FELDBUS = DF_HEAT_PKG_INFOLINK) GENERATE
	
		clk_dom_change : process (opb_clk)-- synch inputs with two ff-stages
		begin
			if rising_edge(opb_clk) then
				ils_int0 <= ils66_int0;
				ils_int1 <= ils66_int1;
				ils_int4 <= ils66_int4;
				ilm_int <= ilm66_int;
				ilm_JobIRQ <= ilm66_JobIRQ;
				ilm_CIRQ <= ilm66_CIRQ;
				ilm_Error <= ilm66_Error;
				ilm_Ovrun <= ilm66_Ovrun;
				ilm_Or1ms <= ilm66_Or1ms;
				il_nLinkLed <= il66_nLinkLed;
				il_nPowerLed <= il66_nPowerLed;
				ils_blinki <= ils66_blinki;
				il_wdog <= il66_wdog;
			end if;
		end process clk_dom_change;
		
		ils_AddrS_IMP2com <= "0100" & reg_AddrS(3 downto 0);
		
		-- for i_clk = 66MHz:
		--i_WDOG_TIME = 00 => 0.993ms
		--i_WDOG_TIME = 01 => 2.979ms
		--i_WDOG_TIME = 10 => 4.965ms
		--i_WDOG_TIME = 11 => 6.951ms
		il66_WDOG_TIME <= "10";
		
		clk_dom_change_99to66 : process (QuarzClk)
		begin
			if rising_edge(QuarzClk) then
				periph_rst66 <= periph_rst;
			end if;
		end process clk_dom_change_99to66;
		
		info_link : entity dpr2infoMS.dpr2infoMS
		generic map (
			C_CLK_DIV_22MHZ => 3,			--66MHz
			C_ChipScope_Implemented => 0,
			C_SpezJob_Implemented => 0,		-- old-fashion compatible
			C_SAC_SUP => 0,
			C_32BITJOBS => 1,
			C_CONF_INCO => 0,	-- configurable and addresswitch-fix imp2 job
			C_TYPE_IRQ4 => 0
			)
		port map (
			-- std-ports
			i_Clk => QuarzClk,
			i_Rst => periph_rst66,			-- high-activ
			-- dprPORT
			o_dprRst => il2dpr_Rst,
			o_dprClk => il2dpr_Clk,
			o_dprEN => il2dpr_EN,
			o_dprWEN => il2dpr_WEN,
			o_dprAddr => il2dpr_Addr,
			i_dprData => dpr2il_Data,
			o_dprData => il2dpr_Data,
			-- selector L: slave; H: master
			i_MasterSlave => reg_MasterSlave,
			-- LEDs
			no_LinkLED => il66_nLinkLed,	-- low-activ (L=light)
			no_PowerLED => il66_nPowerLed,	-- low-activ (L=light)
			-- INFO-LINK
			ni_RX => ni_ilRX,				-- info-link in
			o_TX => o_ilTX,					-- info-link out
			i_WDOG_TIME => il66_WDOG_TIME,
			o_wdog => il66_wdog,
			-- slave ports --------------------------------------------------------
			-- PPC interrups
			o_Int0 => ils66_int0,			-- high-activ
			o_Int1 => ils66_int1,			-- high-activ
			o_Int4 => ils66_int4,			-- high-activ
			o_Int4_Typ => open,
			i_CIRQ0 => reg_CIRQ0en,			-- high-activ
			i_CIRQ1 => reg_CIRQ1en,			-- high-activ
			o_blinki => ils66_blinki,
			i_IMPCmpEn => reg_ilCmpEn,
			i_CardTyp => reg_CardTyp,
			i_AddrSwitch => ils_AddrS_IMP2com,
			-- master ports -------------------------------------------------------
			-- PPC interrup
			o_ILM_IRQ => ilm66_int,			-- IRQ
			-- inputs for ilm seq
			i_Master_Ctrl => reg_Master_Ctrl,
			i_Diag_ON => reg_Diag_ON,
			i_Diag_invers => reg_Diag_invers,
			-- outputs
			o_JobIRQ => ilm66_JobIRQ,
			o_CIRQ => ilm66_CIRQ,
			o_Error => ilm66_Error,
			o_Ovrun => ilm66_Ovrun,
			o_Or1ms => ilm66_Or1ms
		);
	end generate inst_info_link;
	
	-- analog inputs -----------------------------------------------------------
	no_ADC_cs <= not dr_flags(FL_ADC_EN);
	o_ADC_convst <= adc_convst;
	adc_din_a(0) <= i_ADC_din_a;
	adc_din_b(0) <= i_ADC_din_b;
	
	adcs : entity ADS8361_if.ADS8361_if
	generic map (
		C_CLK_PERMANENT => 0,
		C_NUM_ADC => 1
	)
	port map (
		i_Clk => opb_clk,
		--ADS8361 Pins
		o_ADCclk => o_ADC_clk,
		no_CS => open,						-- pin kommt von max2logic
		o_Convst => adc_convst,
		o_Read => open,
		o_Addr0 => o_ADC_addr0,
		i_sDataA => adc_din_a,
		i_sDataB => adc_din_b,
		-- interface	 
		o_DataA => adc_dout_a,				-- zu max2register
		o_DataB => adc_dout_b,				-- zu max2register
		o_Channel => open,
		o_data_ready => adc_d_ready,		-- zu max2logic
		i_next_Channel => log_adc_next_ch,	-- von max2logic
		i_start_conv => log_adc_start_conv		-- von max2logic
	);
	-- shiftregisters ----------------------------------------------------------
	
	-- outputs -------------------------------------
	-- first byte
	asr_outputs(0) <= L;
	asr_outputs(1) <= adc_mux_ka;
	asr_outputs(2) <= adc_mux_kf;
	asr_outputs(3) <= adc_mux_kc;
	asr_outputs(4) <= adc_mux_kb;
	asr_outputs(5) <= adc_mux_kd;
	asr_outputs(6) <= adc_mux_nkd;
	asr_outputs(7) <= L;
	--  second byte
	asr_outputs(8) <= log_analog_sr_fb;
	asr_outputs(9) <= L;
	asr_outputs(10) <= adc_mux_ke;
	asr_outputs(11) <= adc_mux_kx;
	asr_outputs(12) <= adc_mux_kz;
	asr_outputs(13) <= adc_mux_ky;
	asr_outputs(14) <= adc_gain_a0;
	asr_outputs(15) <= adc_gain_a1;
	
	asr : entity shift_register.shift_register
	generic map (
		C_NR_OF_IOS	=> 16,
		C_CLK_DIV	=> 5
	)
	port map (
		i_Clk => opb_clk,
		i_Reset => periph_rst,
		i_Start => asr_start,
		o_serClk => o_asrClk,
		o_serLoad => asrLoad,
		o_serData => o_asrData,
		i_serData => i_asrData,
		i_outputs => asr_outputs,
		o_inputs => asr_inputs
	);
	
	o_asrLoad <= asrLoad;
	
	-- outputs -------------------------------------
	-- first byte
	sr_outputs(0) <= dr_digital_outputs(0) when ppc_wdog_outputs=L else L;
	sr_outputs(1) <= dr_digital_outputs(4) when ppc_wdog_outputs=L else L;
	sr_outputs(2) <= dr_digital_outputs(1) when ppc_wdog_outputs=L else L;
	sr_outputs(3) <= dr_digital_outputs(5) when ppc_wdog_outputs=L else L;
	sr_outputs(4) <= dr_digital_outputs(2) when ppc_wdog_outputs=L else L;
	sr_outputs(5) <= dr_digital_outputs(6) when ppc_wdog_outputs=L else L;
	sr_outputs(6) <= dr_digital_outputs(3) when ppc_wdog_outputs=L else L;
	sr_outputs(7) <= dr_digital_outputs(7) when ppc_wdog_outputs=L else L;
	--  second byte
	sr_outputs(8) <= dr_digital_outputs(8) when ppc_wdog_outputs=L else L;
	sr_outputs(9) <= dr_digital_outputs(12) when ppc_wdog_outputs=L else L;
	sr_outputs(10) <= dr_digital_outputs(9) when ppc_wdog_outputs=L else L;
	sr_outputs(11) <= dr_digital_outputs(13) when ppc_wdog_outputs=L else L;
	sr_outputs(12) <= dr_digital_outputs(10) when ppc_wdog_outputs=L else L;
	sr_outputs(13) <= dr_digital_outputs(14) when ppc_wdog_outputs=L else L;
	sr_outputs(14) <= dr_digital_outputs(11) when ppc_wdog_outputs=L else L;
	sr_outputs(15) <= dr_digital_outputs(15) when ppc_wdog_outputs=L else L;
	--  3. byte
	sr_outputs(16) <= log_digital_sr_fb;
	sr_outputs(17) <= dr_digital_outputs(16) when ppc_wdog_outputs=L else L;
	sr_outputs(18) <= L;
	sr_outputs(19) <= dr_digital_outputs(17) when ppc_wdog_outputs=L else L;
	sr_outputs(20) <= L;
	sr_outputs(21) <= dr_digital_outputs(18) when ppc_wdog_outputs=L else L;
	sr_outputs(22) <= L;
	sr_outputs(23) <= dr_digital_outputs(19) when ppc_wdog_outputs=L else L;
	-- 4. byte
	sr_outputs(24) <= il_nPowerLed;
	sr_outputs(25) <= reg_nOkLed;
	sr_outputs(26) <= reg_nErrorLed;
	sr_outputs(27) <= ESART_ERROR_LED when (C_FELDBUS = DF_HEAT_PKG_ESART) else il_nLinkLed;
	sr_outputs(28) <= L;
	sr_outputs(29) <= L;
	sr_outputs(30) <= L;
	sr_outputs(31) <= sio_nCTS(0);
	-- inputs --------------------------------------
	-- 4. byte
	sr_n_ext_board_mtd <= sr_inputs(DF_SR_IOS-32);
	sio_nRTS(0) <= sr_inputs(DF_SR_IOS-31);
	sr_MAX2nMAX4 <= sr_inputs(DF_SR_IOS-29);
	sr_addrsw(2) <= sr_inputs(DF_SR_IOS-28);
	sr_addrsw(1) <= sr_inputs(DF_SR_IOS-27);
	sr_addrsw(0) <= sr_inputs(DF_SR_IOS-26);
	sr_addrsw(3) <= sr_inputs(DF_SR_IOS-25);
	-- third and second byte
	sr_digital_inputs(15 downto 0) <= not sr_inputs(DF_SR_IOS-9 downto DF_SR_IOS-24);
	-- first byte
	sr_digital_inputs(16) <= not sr_inputs(DF_SR_IOS-8);
	sr_digital_inputs(17) <= not sr_inputs(DF_SR_IOS-7);
	sr_digital_inputs(18) <= not sr_inputs(DF_SR_IOS-6);
	sr_digital_inputs(19) <= not sr_inputs(DF_SR_IOS-5);
	sr_digital_inputs_fb <= sr_inputs(DF_SR_IOS-1);
	
	no_sr_out_en <= not(sr_out_en and log_EnDataO);
	
	srLoadREdge <= srLoad and not srLoadold;
	sr_power_on : process(opb_clk)
	begin
		if rising_edge(opb_clk) then
			srLoadold <= srLoad;
			if (periph_rst=H) then
				asr_out_en <= L;
				dsr_out_en <= L;
				sr_out_en <= L;
			else
				if srLoadREdge=H then
					dsr_out_en <= H;
				elsif asrLoadREdge=H then
					asr_out_en <= H;
				else
					sr_out_en <= dsr_out_en and asr_out_en;
				end if;
			end if;
		end if;
	end process sr_power_on;
	
	-- shiftreg.: singel at timer=0 or run continuous when timer is off
	sr_start <= H when (tm_Cmp2=H or tm_CmpEn2=L or tm_enable=L or dr_flags(FL_DSR_CONT)=H) else L;
	
	dsr : entity shift_register.shift_register
	generic map (
		C_NR_OF_IOS	=> DF_SR_IOS,
		C_CLK_DIV	=> 5
	)
	port map (
		i_Clk => opb_clk,
		i_Reset => periph_rst,
		i_Start => sr_start,
		o_serClk => o_dsrClk,
		o_serLoad => srLoad,
		o_serData => o_dsrData,
		i_serData => i_dsrData,
		i_outputs => sr_outputs,
		o_inputs => sr_inputs,
		o_done => cSr
	);
	
	o_dsrLoad <= srLoad;
	
	-- register dpr ------------------------------------------------------------
	dpr_register : entity dpr2HEATReg.dpr2HEATReg
	port map (
		--System
		i_Clk => opb_clk,
		i_Reset => periph_rst,
		-- Dualport Ram access
		o_dprEN => reg2dpr_EN,
		o_dprClk => reg2dpr_Clk,
		o_dprRst => reg2dpr_Rst,
		o_dprWEN => reg2dpr_WEN,
		o_dprData => reg2dpr_Data,
		i_dprData => dpr2reg_Data,
		o_dprAddr => reg2dpr_Addr,
		-- inputs
		-- adcs
		i_ADCA0 => adc_dout_a(15 downto 0),
		i_ADCB0 => adc_dout_b(15 downto 0),
		-- misc
		i_Timer => tm_timer,
		i_Status => log_status,
		i_digital_inputs => sr_digital_inputs,
		-- outputs
		o_TimerMax =>  dr_TimerMax,
		o_TimerCmp0 => dr_TimerCmp0,
		o_TimerCmp1 => dr_TimerCmp1,
		o_TimerCmp2 => dr_TimerCmp2,
		o_digital_outputs => dr_digital_outputs,
		o_ADC_job => dr_adc_job,
		o_Flags => dr_flags,
		-- safety
		i_srAddr => sc_rAddr,
		i_swAddr => sc_wAddr,
		o_sData => sc_DataOut,
		i_sData => sc_DataIn,
		o_swDone => open,--sc_wDone,
		o_srDone => open,--sc_rDone,
		-- triggers
		i_cADC_0 => log_cADCx0,
		i_cADC_1 => log_cADCx1,
		i_cIntCnt => ils_int4,
		i_cTim0 => cTim0,
		i_cInputs => cSr,
		i_cSafety => sc_cSafety
	);
	-- logic, misc -------------------------------------------------------------
	-- status flags
	log_status(ST_ASR_FB) <= i_asrData_fb;
	log_status(ST_DSR_FB) <= sr_digital_inputs_fb;
	
	log_status(ST_OUTS_WD) <= ppc_wdog_outputs;
	log_status(ST_SAFETY_WD) <= ppc_wdog_safety;
	log_status(ST_EXT_BOARD) <= not sr_n_ext_board_mtd;
	log_status(ST_IL_WD) <= il_wdog;
	log_status(ST_BOARD) <= sr_MAX2nMAX4;
	
	log_EnDataO <= dr_flags(FL_OUT_EN);
	log_analog_sr_fb <= dr_flags(FL_ASR_FB);
	log_digital_sr_fb <= dr_flags(FL_DSR_FB);
	
	triggers : process (opb_clk)
	begin
		if rising_edge(opb_clk) then
			if (periph_rst=H) then
				log_cADCx0 <= L;
				log_cADCx1 <= L;
				log_adc_start_conv <= L;
			else
			-- clocked statements
				log_cADCx0 <= L;
				log_cADCx1 <= L;
				log_data_ready_old <= adc_d_ready;
				log_adc_start_conv <= L;
				if (tm_Cmp0=H) then
					log_conv_0_n_1 <= H;
					log_adc_next_ch <= H;
					log_adc_start_conv <= H;
					log_cADCx1 <= H;
				end if;
				if (tm_Cmp1=H) then
					log_conv_0_n_1 <= L;
					log_adc_next_ch <= L;
					log_adc_start_conv <= H;
				end if;
				if adc_d_ready=H and log_data_ready_old=L then
					if log_adc_next_ch=H then
						log_cADCx0 <= H;
					end if;
				end if;
			end if;
		end if;
	end process triggers;
	
	-- ADC-Mux -----------------------------------------------------------------
	fe_adc_convst <= H when adc_convst=L and adc_convst_n1=H else L; --falling edge of adc_convst
	
	asrLoadFEdge <= not asrLoad and asrLoadold;
	asrLoadREdge <= asrLoad and not asrLoadold;
	adc_mux : process(opb_clk)
	begin
		if rising_edge(opb_clk) then
			if (periph_rst=H) then
				adc_state <= idle;
				asr_start <= H;
				adc_new_ch <= L;
			else
				asrLoadold <= asrLoad;
				adc_1us_cnt <= (others => L);
				asr_start <= L;
				adc_convst_n1 <= adc_convst;
				case adc_state is
				when idle =>
					if (log_conv_0_n_1=H and fe_adc_convst=H) then
						if ((dr_flags(FL_ADC_CONT)=H)
						  or (dr_adc_job(3 downto 0) /= saved_adc_job(3 downto 0))				-- new ch
						  or (dr_adc_job(9 downto 8) /= saved_adc_job(9 downto 8))				-- new gain
						  or (dr_adc_job(15 downto 11) /= saved_adc_job(15 downto 11))) then	-- new ref
							--adc_new_ch <= H;
							adc_state <= start_next_ch;
						end if;
						saved_adc_job <= dr_adc_job;
					end if;
					--if (adc_new_ch=H) then
					--	adc_new_ch <= L;
					--	-- next state
					--	adc_state <= start_next_ch;
					--end if;
				when start_next_ch =>
					-- data to shift (start next ch)
					-- all disable, GND-ref. and gain 1
					adc_mux_ka <= H;
					adc_mux_kb <= H;
					adc_mux_kc <= H;
					adc_mux_kd <= L;
					adc_mux_nkd <= L;
					adc_gain_a0 <= L;
					adc_gain_a1 <= L;
					adc_mux_kf <= L;
					adc_mux_kx <= H;
					adc_mux_ky <= H;
					adc_mux_kz <= H;
					adc_mux_ke <= L;
					-- next state
					adc_state <= gnd_ref;
					-- start shiftregister IOs for digital In/Out
					asr_start <= H;
				when gnd_ref =>
					-- continue shiftregister
					asr_start <= H;
					-- data to shift
					-- enable, GND-ref. and gain 1
					adc_mux_ke <= H;
					if (asrLoadFEdge=H) then -- wait until done
						-- next state
						adc_state <= wait_gr_done;
					end if;
				when wait_gr_done =>
					if (asrLoadFEdge=H) then -- wait until done
						-- next state
						adc_state <= wait_Xus;
						-- set gnd ref time
						gnd_ref_cnt <= saved_adc_job(7 downto 4) & L;
					end if;
				when wait_Xus =>
					if (adc_1us_cnt=99-1) then
						gnd_ref_cnt <= gnd_ref_cnt - 1;
						adc_1us_cnt <= (others => L);
					else
						adc_1us_cnt <= adc_1us_cnt + 1;
					end if;
					-- data to shift
					-- all disable, new ch and new gain
					adc_mux_ka <= not saved_adc_job(0);
					adc_mux_kb <= not saved_adc_job(1);
					adc_mux_kc <= not saved_adc_job(2);
					adc_gain_a0 <= saved_adc_job(8);
					adc_gain_a1 <= saved_adc_job(9);
					adc_mux_kf <= saved_adc_job(11);
					adc_mux_kx <= saved_adc_job(12);
					adc_mux_ky <= saved_adc_job(13);
					adc_mux_kz <= saved_adc_job(14);
					adc_mux_ke <= L;
					if gnd_ref_cnt = 0 then
						-- start shiftregister
						asr_start <= H;
						-- next state
						adc_state <= change_ch;
					end if;
				when change_ch =>
					-- continue shiftregister
					asr_start <= H;
					-- data to shift
					-- enable channel
					adc_mux_kd <= saved_adc_job(3) and not saved_adc_job(15);
					adc_mux_nkd <= not saved_adc_job(3) and not saved_adc_job(15);
					adc_mux_kf <= saved_adc_job(11);
					adc_mux_ke <= saved_adc_job(15);
					if (asrLoadFEdge=H) then
						-- next state
						adc_state <= idle;
					end if;
				end case;
			end if;
		end if;
	end process adc_mux;
	
	-- timer -------------------------------------------------------------------
	tm_TimerMax <= dr_TimerMax(tm_TimerMax'high downto 0);
	tm_TimerCmp0 <= dr_TimerCmp0(tm_TimerCmp0'high downto 0);
	tm_TimerCmp1 <= dr_TimerCmp1(tm_TimerCmp1'high downto 0);
	tm_TimerCmp2 <= dr_TimerCmp2(tm_TimerCmp2'high downto 0);
	tm_enable <= dr_TimerMax(31);
	tm_CmpEn0 <= dr_TimerCmp0(31);
	tm_CmpEn1 <= dr_TimerCmp1(31);
	tm_CmpEn2 <= dr_TimerCmp2(31);
	
	tm_timer(tm_cnt'high downto 0) <= tm_cnt;
	
	cTim0 <= tm0 or dr_flags(FL_STATUS_WR_CONT);
	
	timer : process(opb_clk)
	begin
		if rising_edge(opb_clk) then
			if (periph_rst=H) then
				tm0 <= H;
				tm_cnt <= (others => L);-- reset
			elsif (tm_cnt<tm_TimerMax and tm_enable=H) then
				tm_cnt <= tm_cnt + 1;	-- increment until tm_TimerMax
				tm0 <= L;
			else
				tm0 <= H;
				tm_cnt <= (others => L);-- reset
			end if;
			TimIrq <= TimIrq(TimIrq'high-1 downto 0) & (tm0 and tm_enable);
		end if;
	end process timer;
	
	comparators : process(opb_clk)
	begin
		if rising_edge(opb_clk) then
			if (tm_cnt=tm_TimerCmp0 and tm_CmpEn0=H) then
				tm_Cmp0 <= H;
			else
				tm_Cmp0 <= L;
			end if;
			if (tm_cnt=tm_TimerCmp1 and tm_CmpEn1=H) then
				tm_Cmp1 <= H;
			else
				tm_Cmp1 <= L;
			end if;
			if (tm_cnt=tm_TimerCmp2 and tm_CmpEn2=H) then
				tm_Cmp2 <= H;
			else
				tm_Cmp2 <= L;
			end if;
		end if;
	end process comparators;
	
	-- safety com --------------------------------------------------------------
	
	log_status(31) <= i_ssrData;
	
	safety_communication : block
		type t_sc_state is (s_idle, s_start, s_shift, s_save, s_next);
		signal sc_state : t_sc_state := s_idle;
		signal sc_set : std_logic := L;
		signal sIn : std_logic := L;
		signal sc_clkcnt : std_logic_vector(1 downto 0) := (others => L);
		signal sc_sr : std_logic_vector(42 downto 0) := (others => L);
		signal sc_srcnt : std_logic_vector(5 downto 0) := (others => L);
		signal sc_start : std_logic := L;
		signal CRCrx : std_logic_vector(DF_HEAT_PKG_CRC_POLY'range) := DF_HEAT_PKG_CRC_INIT;
		signal CRCtx : std_logic_vector(DF_HEAT_PKG_CRC_POLY'range) := DF_HEAT_PKG_CRC_INIT;
	begin
	
		safety_com : process(opb_clk)
		begin
			if rising_edge(opb_clk) then
				sc_set <= L;
				sc_cSafety <= L;
				if (periph_rst=H) then
					sc_state <= s_idle;
					o_ssrClk <= L;
					o_ssrLoad <= L;
					o_ssrData <= L;
					sc_clkcnt <= (others => L);
					sc_start <= L;
					sc_rAddr <= (others => L);
					sc_wAddr <= (others => L);
				else
					-- clock
					-- cnt	012301230123
					-- clk	_--__--__--_
					-- set	_-___-___-__
					if (sc_clkcnt=3) then
						sc_clkcnt <= (others => L);
					else
						sc_clkcnt <= sc_clkcnt + 1;
					end if;
					if (sc_clkcnt=0) then
						o_ssrClk <= H;
						sc_set <= H;
						sIn <= i_ssrData;
					elsif (sc_clkcnt=2) then
						o_ssrClk <= L;
					end if;
					-- sr
					sc_start <= (sc_start or tm_Cmp2) and not ppc_wdog_safety;
					case sc_state is
					when s_idle =>
						CRCtx <= DF_HEAT_PKG_CRC_INIT;
						if (sc_start=H) then
							sc_start <= L;
							if (sc_DataOut(127)=H) then
								sc_state <= s_start;
							end if;
						end if;
					when s_start =>
						sc_state <= s_shift;
						CRCtx <= DF_HEAT_PKG_CRC_INIT;
						sc_sr(42 downto 0) <= sc_DataOut(40 downto 32) & sc_DataOut(31 downto 0) & sc_DataOut(126) & sc_DataOut(125);
						sc_srcnt <= (others => L);
						--sc_saved_dpr_addr <= sc_DataOut(40 downto 32);
						--sc_saved_addr <= sc_rAddr;
					when s_shift =>
						if (sc_set=H) then
							sc_srcnt <= sc_srcnt + 1;
							-- output
							if (sc_srcnt>43) then -- shift crc out
								o_ssrData <= CRCtx(CRCtx'high);
							else
								o_ssrData <= sc_sr(sc_sr'high);
							end if;
							-- tx crc
							if (sc_srcnt>43) then -- shift crc out
								CRCtx <= CRCtx(CRCtx'high-1 downto 0) & L;
							else -- bulid
								CRCtx <= crc_gen(sc_sr(sc_sr'high), CRCtx, DF_HEAT_PKG_CRC_POLY);
							end if;
							-- shiftregister
							sc_sr <= sc_sr(sc_sr'high-1 downto 0) & sIn;
							-- rx crc
							if (sc_srcnt=4) then
								CRCrx <= DF_HEAT_PKG_CRC_INIT;
							else
								CRCrx <= crc_gen(sIn, CRCrx, DF_HEAT_PKG_CRC_POLY);
							end if;
							-- load/state
							if (sc_srcnt=53) then
								sc_state <= s_save;
								o_ssrLoad <= L;
							else
								o_ssrLoad <= H;
							end if;
							-- store input data and request next data
							if (sc_srcnt=12) then
								sc_DataIn(63 downto 56) <= sc_sr(7 downto 0);
								sc_DataIn(40 downto 32) <= sc_DataOut(40 downto 32);
								sc_wAddr <= sc_rAddr;
								sc_rAddr <= sc_rAddr+1;
							end if;
						end if;
					when s_save =>
						sc_DataIn(31 downto 0) <= sc_sr(40 downto 9);
						sc_DataIn(55 downto 48) <= sc_sr(8 downto 1); --save crc
						sc_DataIn(95 downto 64) <= tm_timer;
						if (CRCrx=0) then
							sc_DataIn(127) <= L;
						else
							sc_DataIn(127) <= H;
						end if;
						sc_cSafety <= H;
						sc_state <= s_next;
					when s_next =>
						if (sc_DataOut(127)=H and sc_rAddr/=0) then
							sc_state <= s_start;
						else
							sc_rAddr <= (others => L);
							sc_state <= s_idle;
						end if;
					end case;
				end if;
			end if;
		end process safety_com;
	end block safety_communication;
	
	-- bidis -------------------------------------------------------------------
	sd_data_iobuf : for i in b_sdDAT'range generate
	begin
		b_sdDAT(i) <= Z when sdDAT_T(i)=H else sdDAT_O(i);
	end generate sd_data_iobuf;
	
	p_data_iobuf : for i in b_pDAT'range generate
	begin
		b_pDAT(i) <= Z when mc_data_T(i)=H else mc_data_O(i);
	end generate p_data_iobuf;
	
	b_SDA <= Z when reg_i2cSDA_T=H else reg_i2cSDA_O;
	
	b_jtgTCK <= Z when reg_jtgTCK_T=H else reg_jtgTCK_O;
	b_jtgTMS <= Z when reg_jtgTMS_T=H else reg_jtgTMS_O;
	b_jtgTDO <= Z when reg_jtgTDO_T=H else reg_jtgTDO_O;
	b_jtgTDI <= Z when reg_jtgTDI_T=H else reg_jtgTDI_O;
	
	-- Esart -------------------------------------------------------------------
	Instantiate_Esart: IF (C_FELDBUS = DF_HEAT_PKG_ESART) GENERATE
		SIGNAL CLK40_Int           : std_logic;
		SIGNAL CLK40_RST           : std_logic;
		SIGNAL Esart_RST_n         : std_logic;
		SIGNAL Esart_RST_SYNC_n    : std_logic;
		SIGNAL Esart_RST_SYNC      : std_logic; 
		SIGNAL Esart_RXD_Int       : std_logic;
		SIGNAL Esart_RXD           : std_logic;
		SIGNAL Esart_Data_A_In     : std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_Data_A_Out    : std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_Data_B_In     : std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_Data_B_Out    : std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_Data_C_In     : std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_Data_C_Out    : std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_Port_Update   : std_logic_vector(2 DOWNTO 0);
		SIGNAL Esart_TDP_WREN      : std_logic_vector(3 DOWNTO 0);
		SIGNAL Esart_TDP_A         : std_logic_vector(10 DOWNTO 0);
		SIGNAL Esart_TDP_D         : std_logic_vector(31 DOWNTO 0);
		SIGNAL TDP_Esart_D         : std_logic_vector(31 DOWNTO 0);
		SIGNAL Esart_Sample_Counter: std_logic_vector(15 DOWNTO 0);
		SIGNAL Esart_IRQ           : std_logic;
		SIGNAL Esart_Slope_Int     : std_logic;
		SIGNAL Esart_Select_Temp   : std_logic;
		SIGNAL SSI_Mode            : std_logic_vector(7 DOWNTO 0);
		SIGNAL Fatal_Zone_Error    : std_logic;
		SIGNAL Current_MEAS_Start  : std_logic;
		SIGNAL Current_MEAS_Counter: std_logic_vector(20 DOWNTO 0);
		--SIGNAL E2_INT0             : std_logic;
		--SIGNAL E2_INT1             : std_logic; 
		--SIGNAL E2_Data0            : std_logic_vector(15 DOWNTO 0);
		--SIGNAL E2_Data1            : std_logic_vector(15 DOWNTO 0);		
		
		-- Debug, Cross boarder
		SIGNAL ESART_ERROR_LED_Int0 : std_logic;
		SIGNAL ESART_ERROR_LED_Int1 : std_logic;
		
		type t_dpr_synch_state is (idle, read, write, save, wait_end, wait_ack_err);
		signal dpr_synch_state : t_dpr_synch_state := idle;
		signal Esart_start : std_logic_vector(1 downto 0);
		
		signal Txd : std_logic;
		
		signal Esart_Data_A_Out0_lastUpdat : std_logic := '0';


	BEGIN
		Esart_Sync: entity esart.Reset_Synchronization
			PORT MAP (
				SCLK               => CLK40_Int,
				ACLR_n             => Esart_RST_n, --Do not touch!
				CLR_n              => Esart_RST_SYNC_n,
				CLR                => Esart_RST_SYNC
			);
		
		Esart_Slave: ENTITY esart.e2_ultralight
			GENERIC MAP (
				FirmID_User    => x"07", 
				PrintID        => x"0005",
				SlaveAdr       => "0011",
				RegisterInputs => FALSE
			)
			PORT MAP (
				INA            => Esart_Data_A_In,
				INB            => Esart_Data_B_In,
				INC            => Esart_Data_C_In,
				OutputEnable   => '1',
				Rxd            => Esart_RXD,
				clk40          => CLK40_Int,
				reset_n        => Esart_RST_SYNC_n,
				ErrorLED       => ESART_ERROR_LED_Int0, ----------------------------------------------
				FreezeInputs   => OPEN,-- You can freeze a toggeling inout signal with the help of this port.
				OutA           => Esart_Data_A_Out,
				OutB           => Esart_Data_B_Out,
				OutC           => Esart_Data_C_Out,
				Syn            => OPEN,
				Sync           => OPEN,-- Synchronization signal to the Esart
				Txd            => Txd,--E2_INT0,
				UpdatePort     => Esart_Port_Update-- Update(2 DOWNTO 0) the port is written to.
			);	
	
			
			
			
		
		-- dual por ram --------------------------------------------------------
		-- esard write to 0x70000040 and read 0x70000000..3c
		-- dual port ram runs on both sides with opb_clk.
		-- only Esart_start is synched and delayed, Esart_TDP_D is unchanged for
		-- one esard chycle.
		
		--99er domain
		il2dpr_Rst <= L;
		il2dpr_Clk <= opb_clk;
		il2dpr_EN <= H;
		dpr_synch : process(opb_clk)
		begin
			if rising_edge(opb_clk) then
				il2dpr_WEN <= (others => L);
				Esart_start <= Esart_start(0) & Esart_Select_Temp;
				if (periph_rst=H) then
					il2dpr_Addr <= (others => L);
					il2dpr_Data <= (others => L);
					SSI_Mode <= (others => L);
					Esart_Data_A_In <= (others => L);
					dpr_synch_state <= idle;
				else
					case dpr_synch_state is
					when idle =>
						if (Esart_start(1)=H) then
							dpr_synch_state <= read;
						end if;
						if (Fatal_Zone_Error=H) then
							il2dpr_WEN <= (others => H);
							il2dpr_Addr <= "00000010000"; -- Esart command address
							il2dpr_Data <= (others => L);
							il2dpr_Data(30) <= H;
							dpr_synch_state <= wait_ack_err;
						end if;
					when read =>
						il2dpr_Addr <= "0000000"&Esart_TDP_D(4 DOWNTO 1);
						dpr_synch_state <= write;
					when write =>
						il2dpr_WEN <= (others => H);
						il2dpr_Addr <= "00000010000"; -- Esart command address
						il2dpr_Data <= Esart_TDP_D;
						dpr_synch_state <= save;
					when save =>
						SSI_Mode <= dpr2il_Data(15 DOWNTO 8);
						--Esart_Data_A_In <= dpr2il_Data(15 DOWNTO 0);
						Esart_Data_A_In <= (dpr2il_Data(12)&dpr2il_Data(15 DOWNTO 13) & dpr2il_Data(11 DOWNTO 0));-- Debug QFU, 12.08.2008
						dpr_synch_state <= wait_end;
					when wait_end =>
						if (Esart_start(1)=L) then
							dpr_synch_state <= idle;
						end if;
					when wait_ack_err =>
						if (Fatal_Zone_Error=L) then
							dpr_synch_state <= idle;
						end if;
					end case;
				end if;
			end if;
		end process dpr_synch;
		
		CLK40_Int <= i_ESART_CLK;  
		
		
		
		
		
		
		---------------------------
		-- Debug QFU Sync. Esart2
		---------------------------
		E2_Sync: PROCESS(CLK40_Int)
		BEGIN
		   IF (CLK40_Int'EVENT AND CLK40_Int = '1') THEN
		     Esart_RXD_Int   <= NOT(ni_ilRX);
		     Esart_RXD <= Esart_RXD_Int;
		   END IF;
		END PROCESS E2_Sync;
		
		---------------------------
		---------------------------
		
		
		-- We have to save the Esart command in the TDP RAM and to read the ADC temperature values and the current.
		Esart_Feeder: PROCESS(CLK40_Int)
		BEGIN
			IF (CLK40_Int'EVENT AND CLK40_Int = '1') THEN
				IF (Esart_RST_SYNC_n = '0') THEN
					Esart_TDP_D <= (OTHERS =>'0');
					Esart_Sample_Counter <= (OTHERS => '0');
					Esart_Select_Temp <= '0';
				ELSIF ((Esart_Port_Update(0) = '1') AND (Esart_Select_Temp = '0')) THEN
					Esart_TDP_D <= (Current_MEAS_Start & "0000000"&Esart_Sample_Counter(11 DOWNTO 4)& Esart_Data_A_Out); -- oberste 4 bit frei machen für mode.
					IF (Esart_Sample_Counter = "0000111111111111") THEN
						Esart_Sample_Counter <= (OTHERS => '0');
					ELSE
						Esart_Sample_Counter <= (Esart_Sample_Counter + 1);
					END IF;
					Esart_Select_Temp <= '1';
				ELSIF ((Esart_Port_Update(0) = '0') AND (Esart_Select_Temp = '1')) THEN
					Esart_Select_Temp <= '0';
				ELSE
					Esart_Select_Temp <= '0';
				END IF;
			END IF;
		END PROCESS Esart_Feeder;
		
		-- Concurrent 1
		Current_MEAS_Start <= ((Esart_Data_A_Out(1) AND Esart_Data_A_Out(2)) AND (Esart_Data_A_Out(3) AND Esart_Data_A_Out(4)));
		
		------------------------------------------------------
		------------------------------------------------------
		-- Overtemperature disable
		Error_Control: PROCESS(CLK40_Int)
		BEGIN
			IF (CLK40_Int'EVENT AND CLK40_Int = '1') THEN
				IF (Esart_RST_SYNC_n = '0') THEN
					Fatal_Zone_Error <= '1';
					Esart_Data_A_Out0_lastUpdat <= '0';
				--ELSIF ((SSI_Mode(4) = '1') OR (SSI_Mode(3) = '1') OR (ESART_ERROR_LED_Int0 = '1')) THEN
				--ELSIF ((SSI_Mode(4) = '1') OR (ESART_ERROR_LED_Int0 = '1')) THEN -- Debug QFU, 13.08.2008, Thermocouple Break Disable deactivated.
				ELSIF (ESART_ERROR_LED_Int0 = '1') THEN -- le nur noch busserror, kein overtemp vom ppc
					Fatal_Zone_Error <= '1';
				ELSIF (Esart_Port_Update(0) = '1') THEN
					Esart_Data_A_Out0_lastUpdat <= Esart_Data_A_Out(0);
					IF (Esart_Data_A_Out(0) = '0') THEN
						Fatal_Zone_Error <= '0';
					END IF;
				ELSIF (Esart_Port_Update(0) = '0') THEN
					IF (Esart_Data_A_Out(0) = '0' and Esart_Data_A_Out0_lastUpdat='1') THEN  -- powerup mode
						Fatal_Zone_Error <= '1';
					END IF;
				END IF;
			END IF;
		END PROCESS Error_Control;
		------------------------------------------------------
		------------------------------------------------------
		
		------------------------------------------------------
		-- Achtung, wichtig *: gemaess den Tests am 02.04.2008 reicht die Verknüpfung mit der Error_LED nicht aus. (Esart_Data_A_Out(0) = '0') muss zusätzlich angeschaut werden.
		-- Was geschieht bei Slaves, die kein EN-Bit haben?- 
		------------------------------------------------------
		------------------------------------------------------
		
		-- Concurrent 1
		Esart_RST_n <= NOT(periph_rst); -- periph_rst is synchroneous to 66MHz. So it's like a asynchroneous CLK for CLK40.
		--Debug QFU: Esart_RXD   <= NOT(ni_ilRX); -- We have one Schmitt Trigger on the INFO-TORX194 print.
		o_ilTX <= not TXd;
	    --o_ilTX <= TXd;              s
		
		Esart_Data_B_In <= NOT(Esart_Data_B_Out);
		Esart_Data_C_In <= NOT(Esart_Data_C_Out);
		CLK40_RST <= '0';
		----------------
		-- Cross domains
		----------------
		--Esart Receive LED, DOUT
		Esart_REC_SYNC: PROCESS(opb_clk)
		BEGIN
			IF (opb_clk'EVENT AND opb_clk = '1') THEN
				IF (periph_rst = '1') THEN
					ESART_ERROR_LED <= '1';
					ESART_ERROR_LED_Int1 <= '1';
				ELSE
					ESART_ERROR_LED <= ESART_ERROR_LED_Int1;
					ESART_ERROR_LED_Int1 <= ESART_ERROR_LED_Int0;
				END IF;
			END IF;
		END PROCESS Esart_REC_SYNC;
		--------------------
		-- Cross domains END
		--------------------
	
	
	END GENERATE Instantiate_Esart;
	
end architecture STRUCTURE;

