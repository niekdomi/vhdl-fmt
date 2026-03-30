--------------------------------------------------------------------------------
-- GIN_SAC3_Top.vhd
--------------------------------------------------------------------------------
--
--	project		: GIN-SAC3
--	programmer	: C. Leuthold, INDEL AG
--	date		: 07.10.2008
--	language	: VHDL
--	system		: ppc-card4-eth
--
--  purpose
--				GIN_SAC3_Top
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
--				enc : encoder sincos or increment
--				dac : digital ananlog converter
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 3.00
--	16.10.2008-le : - change to 110 mhz oscillator
--					- correct waittimes and clock divs for 110 mhz
--	17.10.2008-le : - add sio_485_RnW to ppc_module
--					- rename no_EnDataO to no_srOutEn
--	22.10.2008-le : - correct sigma_delta.sigma_delta_synchron channel0 failure
--	03.11.2008-le : - merge with baschis changes.
--					- add eth and led flasher
--	03.11.2008-le : - dpr1aNb: add generic C_BX_BLOCK_ENABLED, to remove blocks0
--					  (infolink) when DF_INFOLINK=0
--	28.01.2009-le : - change ucf to ppc-card4-eth-HWA  
--	04.03.2009-fb : - !!- SAC3 hat Eth-Stecker vertauscht -!!
--	09.02.2009-le : - change i_ExtEn pin no. in ucf
--	19.02.2009-le : - release
--
-- 3.01
--	15.07.2009-le:	- add o_safRelFb, i_safRelFb pulluped
--	30.07.2009-le:	- change to dpr2motreg
--					- new resolver with gain and phaseshift
--					- add Break PWM
--					- add Fan PWM
--	03.08.2009-le:	- correct adc mesurement
--	04.08.2009-le : - add ac phase measurement
--	13.08.2009-le : - invert safety FB
--	08.09.2009-le : - correct write comparators for endat ssi hiperface start
--					- add crc support for Endat and some error dedection
--	28.09.2009-le : - change active output to sw out0
--	29.09.2009-le : - sinGen.vhd: new singen are 180° to old singen
--	05.10.2009-le : - release
--
--------------------------------------------------------------------------------
--$Rev:: 1221                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-10-05 16:16:38 +0200 (Mo, 05 Okt 2009)                          $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

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

library Motor_PWM;
use Motor_PWM.all;

library ADS8361_if;
use ADS8361_if.ADS8361_if;
use ADS8361_if.ADS7863_if;

library sigma_delta;
use sigma_delta.sigma_delta_synchron;

library increment_counter;
use increment_counter.all;

library shift_register;
use shift_register.shift_register;

library dpr2MotReg;
use dpr2MotReg.dpr2MotReg;

library endat;
use endat.endat;

library ppc_module;
use ppc_module.ALL;

library sincos;
use sincos.ALL;

library RGMII_if;
use RGMII_if.ALL;

library gin_eth;
use gin_eth.ALL;

library gin_slave;
use gin_slave.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity GIN_SAC3_Top is
generic (
	C_REVISION : std_logic_vector := x"301";
	C_DEV_BUILD : integer := 13 -- 0 for releases
);
port (
	i_sys_clk : in std_logic;
	-- ddr ram -----------------------------------------------------------------
	o_ddrClkp : out std_logic;
	o_ddrClkn : out std_logic;
	i_ddr_clk : in std_logic;
	o_ddrAddr : out std_logic_vector(12 downto 0);
	o_ddrBankAddr : out std_logic_vector(16/8-1 downto 0);
	no_ddrCas : out std_logic;
	o_ddrCe : out std_logic;
	no_ddrCs : out std_logic;
	no_ddrRas : out std_logic;
	no_ddrWe : out std_logic;
	o_ddrDm : out std_logic_vector(16/8-1 downto 0);
	b_ddrDqs : inout std_logic_vector(16/8-1 downto 0);
	b_ddrDq : inout std_logic_vector(16-1 downto 0);
	-- flash -------------------------------------------------------------------
	o_flashADR : out std_logic_vector(20 downto 0);
	b_flashDAT : inout std_logic_vector(15 downto 0);
	o_flashRnW : out std_logic;
	no_flashOE : out std_logic;
	no_flashCEn : out std_logic;
	no_flashReset : out std_logic;
	-- jtag port ---------------------------------------------------------------
	b_jtagTCK : inout std_logic;
	b_jtagTMS : inout std_logic;
	b_jtagTDO : inout std_logic;
	b_jtagTDI : inout std_logic;
	-- sio ---------------------------------------------------------------------
	ni_sioRX : in std_logic;
	no_sioTX : out std_logic;
	ni_sioRTS : in std_logic;
	no_sioCTS : out std_logic;
	-- Ethernet ----------------------------------------------------------------
	no_PHY_RESET : out std_logic;
	i_PHY_CLK125 : in std_logic;
	i_PHY_RXC0 : in std_logic;
	o_PHY_TXD0 : out std_logic_vector(3 downto 0);
	o_PHY_TXEN0 : out std_logic;
	i_PHY_RXD0 : in std_logic_vector(3 downto 0);
	i_PHY_RXDV0 : in std_logic;
	o_PHY_GTXCLK0 : out std_logic;
	i_PHY_RXC1 : in std_logic;
	o_PHY_TXD1 : out std_logic_vector(3 downto 0);
	o_PHY_TXEN1 : out std_logic;
	i_PHY_RXD1 : in std_logic_vector(3 downto 0);
	i_PHY_RXDV1 : in std_logic;
	o_PHY_GTXCLK1 : out std_logic;
	o_PHY_MDC : inout std_logic_vector(1 downto 0);
	b_PHY_MDIO : inout std_logic_vector(1 downto 0);
	-- info link ---------------------------------------------------------------
	o_ilTX : out std_logic;
	ni_ilRX : in std_logic;
	-- i2c bus -----------------------------------------------------------------
	o_SCL : out std_logic;
	b_SDA : inout std_logic;
	-- axis pwm outputs --------------------------------------------------------
	o_PWM_Ua : out std_logic;
	o_PWM_Ub : out std_logic;
	o_PWM_Va : out std_logic;
	o_PWM_Vb : out std_logic;
	o_PWM_Wa : out std_logic;
	o_PWM_Wb : out std_logic;
	-- break pwm ---------------------------------------------------------------
	o_PWM_brake : out std_logic;
	-- resolver sinus generator ------------------------------------------------
	o_SinPWM : out std_logic;
	no_SinPWM : out std_logic;
	-- serial ios --------------------------------------------------------------
	o_srClk : out std_logic;
	o_srLoad : out std_logic;
	o_srData : out std_logic;
	i_srData : in std_logic;
	-- fast inputs -------------------------------------------------------------
	ni_Phases : in std_logic;
	i_mot_temp : in std_logic;
	i_ExtEn : in std_logic;
	-- sinus cosinus interface -------------------------------------------------
	i_SCI_sin : in std_logic;
	i_SCI_cos : in std_logic;
	i_SCI_ref : in std_logic;
	-- incremental interface ---------------------------------------------------
	i_IncI_ref : in std_logic;
	i_IncI_a : in std_logic;
	i_IncI_b : in std_logic;
	-- SSI, EnDat, RS485, RS422, EnDat -----------------------------------------
	b_SI_clk : inout std_logic;
	b_SI_data : inout std_logic;
	o_SI_WnR_clk : out std_logic;
	o_SI_WnR_data : out std_logic;
	-- adc ---------------------------------------------------------------------
	o_ADC_cs : out std_logic;
	o_ADC_clk : out std_logic;
	o_ADC_convst : out std_logic;
	o_ADC_addr0 : out std_logic;
	i_ADC_din_a : in std_logic_vector(1 downto 0);
	i_ADC_din_b : in std_logic_vector(1 downto 0);
	-- sigma delta adc ---------------------------------------------------------
	o_sd_sClk : out std_logic;
	i_sd_sData : in std_logic_vector(3 downto 0);
	-- output enables ----------------------------------------------------------
	no_srOutEn : out std_logic;
	no_PWMEn : out std_logic;
	no_safRelFb : out std_logic;
	ni_safRelFb0 : in std_logic;
	ni_safRelFb1 : in std_logic;
	
	o_ad7356_cs : out std_logic;
	o_ad7356_clk : out std_logic;
	i_ad7356_ain : in std_logic;
	i_ad7356_bin : in std_logic;
	o_dbg : out std_logic;
	o_dbg2 : out std_logic
  );
end GIN_SAC3_Top;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of GIN_SAC3_Top is
	----------------------------------------------------------------------------
	-- constants 
	----------------------------------------------------------------------------
	--	no InfoLink
	--	with GinEthernet on Gin_bw_connector
	--	with GinSlave 
	--	AdrSwitch bit-3 used to ativate Ethernet
	--	AdrSw-3 = H ==> Gin_fw only, GinEthernet in bw_con
	----------------------------------------------------------------------------
	constant DF_NUM_OF_IRQS : integer := 17;

	constant C_NUM_PLBBRAM_IF : integer := 3;
	-- GinEthernet PLB-BRAM-Number
	constant DF_PLB_IF_Eth : integer := 1;
	-- GinSlave PLB-BRAM-Number
	constant DF_PLB_IF_GS : integer := 2;
	
	constant DF_OPB_IF_REG    : integer := 0;
	constant C_BASEADDR_OPB_IF_1 : std_logic_vector := X"8000_0800";
	constant C_HIGHADDR_OPB_IF_1 : std_logic_vector := X"8000_08ff";
	
	constant DF_OPB_IF_EXTMEM : integer := 1;
	constant C_BASEADDR_OPB_IF_2 : std_logic_vector := X"E000_0000";
	constant C_HIGHADDR_OPB_IF_2 : std_logic_vector := X"EFFF_FFFF";
	
	constant DF_NUM_OPB_IF : integer := 2;
	
	constant C_NUM_UARTS : integer := 2;
	
	constant C_ISOCM : integer := 32; -- kilobyte
	constant C_NUM_OF_BOOT_BRAMS : integer := C_ISOCM/2;
	
	constant DF_FLAGS : std_logic_vector := "0000" or DF_FLG_ISOCM_32 or DF_FLG_CIRQ;
	
	constant C_SDRAM_SIZE : integer := 32; -- megabyte

	constant DF_REVISION : std_logic_vector(31 downto 0) := pkg_rev_reg(DF_PKG_TARGET_SAC2, C_DEV_BUILD, DF_FLAGS, C_SDRAM_SIZE, 3, C_REVISION);
	constant DF_SVN_REV : std_logic_vector(31 downto 0) := get_dec_from_string(" $Rev:: 1221   $ ", 31);
	
	constant C_OSC_CLK_FREQ : integer := 110_000_000;-- oscillator freq. (66 or 110mhz)
	constant C_BUS_CLK_FREQ : integer := 110_000_000;-- bus freq (99 or 110mhz)
	-- info link
	constant DF_INFOLINK : integer := 0;
	constant C_SYNC_IL : integer := 0;-- 1 for 66/99mhz / 0 for 110mhz
	constant C_IL_CLK_DIV_22MHZ : integer := C_OSC_CLK_FREQ/22_000_000;-- 3 for 66/99mhz / 5 for 110mhz
	-- extern memory
	constant C_INIT_MEMREG : std_logic_vector(31 downto 0) := x"000e_0617";-- x"000B_0516";
	-- clock divisor for shiftregister(max 20 MHz), dac(max 20 MHz) and  adc(max 10MHz) (adc use intern clk_div*2)
	constant C_CLK_DIV : integer := C_BUS_CLK_FREQ/20_000_000 + 1; -- 99MHz : 5 / 110MHz : 6
	
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
	signal periph_rst : std_logic := H;
	signal periph_rst66 : std_logic := H;
	-- dcm clocks
	signal dcmLocked : std_logic;
	signal il_CLk : std_logic;
	signal ocm_clk : std_logic;
	signal ppc_clk : std_logic;
	signal bus_clk : std_logic;
	signal bus_clk_90 : std_logic;
	signal bus_clk_180 : std_logic;
	signal bus_clk_270 : std_logic;
	signal ddr_clk_90 : std_logic;
	signal ddr_clk_270 : std_logic;
	-- ddr ram bidis
	signal ddrDqs_i : std_logic_vector(1 downto 0);
	signal ddrDq_i : std_logic_vector(15 downto 0);
	signal ddrDqs_o : std_logic_vector(1 downto 0);
	signal ddrDq_o : std_logic_vector(15 downto 0);
	signal ddrDqs_t : std_logic_vector(1 downto 0);
	signal ddrDq_t : std_logic_vector(15 downto 0);
	-- memory controller bidis
	signal mc_data_O : std_logic_vector(b_flashDAT'range);
	signal mc_data_T : std_logic_vector(b_flashDAT'range);
	-- plb bram interface
	signal plb2bram_Rst : std_logic_vector(0 to C_NUM_PLBBRAM_IF-1) := (others => L);
	signal plb2bram_Clk : std_logic_vector(0 to C_NUM_PLBBRAM_IF-1) := (others => L);
	signal plb2bram_EN : std_logic_vector(0 to C_NUM_PLBBRAM_IF-1) := (others => L);
	signal plb2bram_WEN : std_logic_vector(0 to C_NUM_PLBBRAM_IF*8-1) := (others => L);
	signal plb2bram_Addr : std_logic_vector(0 to C_NUM_PLBBRAM_IF*32-1) := (others => L);
	signal plb2bram_Data : std_logic_vector(0 to C_NUM_PLBBRAM_IF*64-1) := (others => L);
	signal bram2plb_Data : std_logic_vector(0 to C_NUM_PLBBRAM_IF*64-1) := (others => L);
	-- opb interfaces: 1. reg, 2. extmem
	signal opbif_rd_acc_done : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_rd_data : std_logic_vector(DF_NUM_OPB_IF*32-1 downto 0);
	signal opbif_wr_acc_done : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_addr : std_logic_vector(DF_NUM_OPB_IF*32-1 downto 0);
	signal opbif_byte_ebl : std_logic_vector(DF_NUM_OPB_IF*32/8-1 downto 0);
	signal opbif_rd_acc : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_wr_acc : std_logic_vector(DF_NUM_OPB_IF-1 downto 0);
	signal opbif_wr_data : std_logic_vector(DF_NUM_OPB_IF*32-1 downto 0);
	-- uart
	constant DF_SYSTEM_UART : integer := 0;
	constant DF_ENCODER_UART : integer := 1;
	signal sio_rxInt : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_txInt : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nRX : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nTX : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nRTS : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_nCTS : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_485_RnW : std_logic_vector(C_NUM_UARTS-1 downto 0);
	-- register and interrupt controller
	signal reg_MasterSlave : std_logic;
	signal reg_ilCmpEn : std_logic;
	signal reg_CIRQ0en : std_logic;
	signal reg_CIRQ1en : std_logic;
	signal reg_Master_Ctrl : std_logic_vector(7 downto 0);
	signal reg_Diag_ON : std_logic;
	signal reg_Diag_invers : std_logic;
	signal reg_CardTyp : std_logic_vector(2 downto 0);
	signal reg_Interrups : std_logic_vector(DF_NUM_OF_IRQS-1 downto 0) := (others => L);
	signal reg_ppc_ext_irq : std_logic;
	signal reg_ppc_crit_irq : std_logic := L;
	signal reg_MemConfig : std_logic_vector(31 downto 0) := (others => L);
	signal reg_nOkLed : std_logic;
	signal reg_nErrorLed : std_logic;
	signal reg_AddrS : std_logic_vector(7 downto 0);
	signal reg_flags : std_logic_vector(31 downto 0);
	-- reg bidis
	signal i2cSDA_O : std_logic;
	signal i2cSDA_T : std_logic;
	signal jtagTCK_O : std_logic;
	signal jtagTCK_T : std_logic;
	signal jtagTMS_O : std_logic;
	signal jtagTMS_T : std_logic;
	signal jtagTDO_O : std_logic;
	signal jtagTDO_T : std_logic;
	signal jtagTDI_O : std_logic;
	signal jtagTDI_T : std_logic;
	-- infolink
	signal il_nPowerLed : std_logic;
	signal il_nLinkLed : std_logic;
	signal il_wdog : std_logic;
	signal ils_int0 : std_logic;
	signal ils_int1 : std_logic;
	signal ils_int4 : std_logic;
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
	-- infolink dpr
	signal il2dpr_Addr : std_logic_vector(10 downto 0) := (others => L);
	signal il2dpr_Clk : std_logic := L;
	signal dpr2il_Data : std_logic_vector(31 downto 0);
	signal il2dpr_Data : std_logic_vector(31 downto 0) := (others => L);
	signal il2dpr_EN : std_logic := L;
	signal il2dpr_Rst : std_logic := L;
	signal il2dpr_WEN : std_logic_vector(3 downto 0) := (others => L);
	-- register dpr
	signal reg2dpr_Addr : std_logic_vector(9 downto 0);
	signal reg2dpr_Clk : std_logic;
	signal reg2dpr_Data : std_logic_vector(63 downto 0);
	signal dpr2reg_Data : std_logic_vector(63 downto 0);
	signal reg2dpr_EN : std_logic;
	signal reg2dpr_Rst : std_logic;
	signal reg2dpr_WEN : std_logic_vector(3 downto 0);
	-- sintab dpr
	signal sin2dpr_Addr : std_logic_vector(10 downto 0) := (others => L);
	signal sin2dpr_Clk : std_logic;
	signal sin2dpr_Data : std_logic_vector(31 downto 0);
	signal dpr2sin_Data : std_logic_vector(31 downto 0);
	signal sin2dpr_EN : std_logic;
	signal sin2dpr_Rst : std_logic;
	signal sin2dpr_WEN : std_logic_vector(3 downto 0);
	-- ADC ---------------------------------------------------------------------
	signal adc_dout_a : std_logic_vector(2*16-1 downto 0);
	signal adc_dout_b : std_logic_vector(2*16-1 downto 0);
	signal adc_d_ready : std_logic;
	signal adc_next_ch : std_logic;
	signal acd_start_conv : std_logic;
	signal adc_ADCx0_trig  : std_logic := L;
	signal adc_ADCx1_trig  : std_logic := L;
	signal adc_d_ready_old : std_logic := L;
	-- 3ph sym. pwms -----------------------------------------------------------
	constant DF_NUM_3PH_PWM : integer := 1;
	constant DF_REG_LENGTH : integer := 16;
	signal pwm_int : std_logic;
	signal pwm_convSt : std_logic;
	signal pwm_convSt180 : std_logic;
	signal pwm_pwm0 : std_logic;
	signal pwm_cnt : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_100_time : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_int_time : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_convSt_time : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_dead_time : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_sin_index : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_sin_phase : std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal pwm_u_time : std_logic_vector(DF_NUM_3PH_PWM*DF_REG_LENGTH-1 downto 0);
	signal pwm_v_time : std_logic_vector(DF_NUM_3PH_PWM*DF_REG_LENGTH-1 downto 0);
	signal pwm_w_time : std_logic_vector(DF_NUM_3PH_PWM*DF_REG_LENGTH-1 downto 0);
	signal pwm_stop : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0) := (others => H);
	signal pwm_Ua : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0);
	signal pwm_Ub : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0);
	signal pwm_Va : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0);
	signal pwm_Vb : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0);
	signal pwm_Wa : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0);
	signal pwm_Wb : std_logic_vector(DF_NUM_3PH_PWM-1 downto 0);
	signal pwm_SinPWM : std_logic_vector(0 downto 0);
	signal pwm_nSinPWM : std_logic_vector(0 downto 0);
	signal pwm_PPC_WDog : std_logic;
	signal PPC_WDog : std_logic := H;
	signal pwm_run : std_logic;
	signal pwm_oversampling : std_logic_vector(2 downto 0);
	signal pwm_sinCycle : std_logic;
	-- encoders ----------------------------------------------------------------
	constant DF_ENC_SINCOS : integer := 0;
	constant DF_ENC_INC : integer := 1;
	signal enc_a : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	signal enc_b : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	signal enc_ref : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	signal enc_a_s : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	signal enc_b_s : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	signal enc_ref_s : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	type t_enc_cnt is array (DF_ENC_SINCOS to DF_ENC_INC) of std_logic_vector(11 downto 0);
	signal enc_cnt : t_enc_cnt;
	type t_enc_zpcnt is array (DF_ENC_SINCOS to DF_ENC_INC) of std_logic_vector(3 downto 0);
	signal enc_zpcnt : t_enc_zpcnt;
	signal enc_ZeroPulse : std_logic_vector(DF_ENC_INC downto DF_ENC_SINCOS);
	type t_enc_cnt2 is array (DF_ENC_SINCOS to DF_ENC_INC) of std_logic_vector(DF_REG_LENGTH-1 downto 0);
	signal enc_cnt2 : t_enc_cnt2;
	-- sigma delta u and i measurement -----------------------------------------
	constant DF_SD_U : integer := 1;--0;
	constant DF_SD_V : integer := 2;--1;
	constant DF_SD_W : integer := 3;--2;
	constant DF_SD_S : integer := 4;--3;
	constant DF_NUM_SD_DEVICES : integer := 4;
	signal sd_overrange : std_logic_vector(DF_NUM_SD_DEVICES-1 downto 0);
	signal sd_analog_data : std_logic_vector(DF_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_trig : std_logic;
	signal sd_180_trig : std_logic;
	signal sd_clk_cnt : std_logic_vector(2 downto 0) := (others => L);
	signal sd_sClk : std_logic := L;
	signal sd_dataready : std_logic := L;
	-- shift_register ----------------------------------------------------------
	signal sr_outputs : std_logic_vector(23 downto 0) := (others => L);
	signal sr_inputs : std_logic_vector(23 downto 0);
	signal sr_AddrSin : std_logic_vector(7 downto 0);
	signal sr_out_en : std_logic := L;
	signal srLoad : std_logic;
	signal sr_start : std_logic;
	signal srLoadREdge : std_logic;
	signal srLoadFEdge : std_logic;
	signal srLoadold : std_logic := H;
	-- register dpr ------------------------------------------------------------
	signal dr_RESflg : std_logic_vector(31 downto 0);
	signal dr_flags : std_logic_vector(31 downto 0);
	-- ssi ---------------------------------------------------------------------
	-- endat -------------------------------------------------------------------
	constant DF_NUM_OF_ESI : integer := 1;
	signal end_sData_out_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal end_start : std_logic_vector(DF_NUM_OF_ESI-1 downto 0) := (others => L);
	signal si_Read : std_logic_vector(2 downto 0) := (others => L);
	signal si_written : std_logic_vector(DF_NUM_OF_ESI-1 downto 0) := (others => L);
	
	constant ADDR_WIDTH : integer := 11; --log2(BRAM size in byte)
	constant DF_ADDR_HIGH : integer := 32-3;--ppcaddr width (64bit word)
	type t_a_cmp is array (0 to 2) of std_logic_vector(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH+2);
	constant DF_END_WD_ADDR : t_a_cmp := (	"010" & x"500",   --0x70002500
											"010" & x"508",   --0x70002508
											"010" & x"510");  --0x70002510
	signal si_selector : std_logic_vector(1 downto 0) := (others => L);
	type t_si_mux_conf is array (0 to DF_NUM_OF_ESI-1) of std_logic_vector(31 downto 0);
	type t_si_mux_txd  is array (0 to DF_NUM_OF_ESI-1) of std_logic_vector(31 downto 0);
	type t_si_mux_reg  is array (0 to DF_NUM_OF_ESI-1) of std_logic_vector(63 downto 0);
	type t_si_mux_mode is array (0 to DF_NUM_OF_ESI-1) of std_logic_vector(2 downto 0);
	type t_si_select is array (0 to DF_NUM_OF_ESI-1) of std_logic_vector(1 downto 0);
	signal dr_si_config_m : t_si_mux_conf;
	signal end_tx_data_m : t_si_mux_txd;
	signal endat_ssi_trig_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal endat_ssi_reg_m : t_si_mux_reg;
	constant DF_SEL_SSI : std_logic_vector(1 downto 0) := "01";
	constant DF_SEL_HIP : std_logic_vector(1 downto 0) := "10";
	constant DF_SEL_END : std_logic_vector(1 downto 0) := "00";
	signal esi_Select : t_si_select;
	signal end_enable_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal ssi_start_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal end_mode_m : t_si_mux_mode;
	signal end_sData_in_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal si_clk_out : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal si_clk_in : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal si_clk_WnR : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal si_data_out : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal si_data_in : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal si_data_WnR : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal end_RnW_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	signal end_sClk_m : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	
	signal sio_nRX_si : std_logic_vector(DF_NUM_OF_ESI-1 downto 0);
	
	-- logic, misc -------------------------------------------------------------
	-- flags bit no. 
	constant DF_ACTIVE_LED_OR  : integer := 0;
	constant DF_OUT1_LED_OR    : integer := 1;
	constant DF_EXTEN_LED_OR   : integer := 2;
	constant DF_REF_LED_OR     : integer := 3;
	constant DF_A_LED_OR       : integer := 4;
	constant DF_B_LED_OR       : integer := 5;
	constant DF_BRAKE_LED_OR   : integer := 6;

	constant DF_FLG_SFB_OUT    : integer := 16;
	constant DF_FLG_OUT0       : integer := 16 + 1;
	constant DF_FLG_OUT1       : integer := 16 + 2; --FLG2
	constant DF_FLG_CLR_ERR    : integer := 16 + 3; --FLG3
	constant DF_FLG_INT_EN     : integer := 16 + 5; --FLG5
	constant DF_FLG_ACT        : integer := 16 + 7; --FLG7
	constant DF_FLG_LED_UCC    : integer := 16 + 8;
	constant DF_FLG_LED_IMAX   : integer := 16 + 9;
	constant DF_FLG_LED_CTRL   : integer := 16 + 10;
	constant DF_FLG_LED_MOT    : integer := 16 + 11;
	constant DF_FLG_LED_RES    : integer := 16 + 12;
	constant DF_FLG_LED_PWM    : integer := 16 + 13;
	-- RESflg bit no.
	constant DF_RSFLG_PWM_OS0  : integer := 0;
	constant DF_RSFLG_PWM_OS1  : integer := 1;
	constant DF_RSFLG_PWM_OS2  : integer := 2;
	constant DF_RSFLG_POT_INC  : integer := 8;
	constant DF_RSFLG_POT_UP   : integer := 9;
	constant DF_RSFLG_POT_CS   : integer := 10;
	constant DF_RSFLG_PWM_EN   : integer := 15;
	constant DF_RSFLG_SR_EN    : integer := 14;
	constant DF_RSFLG_SIDIR_D_0  : integer := 16 + 0;
	constant DF_RSFLG_SIOUT_D_0  : integer := 16 + 1;
	constant DF_RSFLG_SIDIR_C_0  : integer := 16 + 2;
	constant DF_RSFLG_SIOUT_C_0  : integer := 16 + 3;
	constant DF_RSFLG_PERR     : integer := 16 + 12;
	constant DF_RSFLG_FAN      : integer := 16 + 13;
	constant DF_RSFLG_REL      : integer := 16 + 14;
	constant DF_RSFLG_BRE      : integer := 16 + 15;
	-- status bit no.
	constant DF_STAT_PPC       : integer := 0;
	constant DF_STAT_PHA       : integer := 11;
	
	constant DF_STAT_SAF_REL0  : integer := 12;
	constant DF_STAT_SAF_REL1  : integer := 13;
	
	constant DF_STAT_EXT_EN    : integer := 16 + 0;
	constant DF_STAT_ENC_NP    : integer := 16 + 1;
	constant DF_STAT_ENC_A     : integer := 16 + 2;
	constant DF_STAT_ENC_B     : integer := 16 + 3;
	constant DF_SINCYCLE       : integer := 16 + 4;
	constant DF_STAT_SI_C      : integer := 16 + 5;
	constant DF_STAT_SI_D      : integer := 16 + 6;
	constant DF_STAT_SC_REF    : integer := 16 + 7;
	constant DF_STAT_SC_A      : integer := 16 + 8;
	constant DF_STAT_SC_B      : integer := 16 + 9;
	constant DF_STAT_IRED      : integer := 16 + 10;
	constant DF_STAT_WDOG      : integer := 16 + 11;
	constant DF_STAT_MTEMP     : integer := 16 + 12;
	constant DF_STAT_AUS       : integer := 16 + 13;
	constant DF_STAT_KURZ      : integer := 16 + 14;
	constant DF_STAT_STP       : integer := 16 + 15;
	-- encoder serial interface
	constant DF_ESI_GPIO       : integer := 0;
	constant DF_ESI_SSI        : integer := 1;
	constant DF_ESI_RS485      : integer := 2;
	constant DF_ESI_RS422      : integer := 3;
	constant DF_ESI_ENDAT      : integer := 4;
	constant DF_ESI_HIPER      : integer := 5;
	
	signal log_status : std_logic_vector(31 downto 0) := (others => L);
	signal log_fan : std_logic;
	signal log_relais : std_logic;
	signal log_active : std_logic;
	signal log_brake : std_logic;
	signal log_stop : std_logic;
	signal log_shorty : std_logic;
	signal log_off : std_logic;
	signal log_ext_en : std_logic;
	signal log_ext_en_s : std_logic;
	signal log_pha : std_logic;
	signal log_pha_s : std_logic;
	signal log_mot_temp : std_logic;
	signal log_mot_temp_s : std_logic;
	
	signal TestV32_1 : std_logic_vector(31 downto 0) := (others => L);
	signal TestV32_2 : std_logic_vector(31 downto 0) := (others => L);
	
	signal clk125 : std_logic;
	signal clk125_90 : std_logic;
	signal clk62_5 : std_logic;
	signal ref_clk : std_logic;
	signal phy_dcm_Locked : std_logic;
	signal idel_rst : std_logic;

	signal Phy_reset : std_logic;

	signal reg_GPIO_T : std_logic_vector(3 downto 0);
	signal reg_GPIO_O : std_logic_vector(3 downto 0);
	signal reg_GPIO_I : std_logic_vector(3 downto 0);
	
--------------------------------------------------------------------------------
--	GMII
--------------------------------------------------------------------------------
	signal Gin_GMII_RxDat0	: std_logic_vector(7 downto 0);
	signal Gin_GMII_RxDv0	: std_logic;
	signal Gin_GMII_RxErr0	: std_logic;
	signal Gin_GMII_TxDat0	: std_logic_vector(7 downto 0);
	signal Gin_GMII_TxDv0	: std_logic;
	signal Gin_GMII_TxErr0	: std_logic;
	
	signal Gin_GMII_RxDat1	: std_logic_vector(7 downto 0);
	signal Gin_GMII_RxDv1	: std_logic;
	signal Gin_GMII_RxErr1	: std_logic;
	signal Gin_GMII_TxDat1	: std_logic_vector(7 downto 0);
	signal Gin_GMII_TxDv1	: std_logic;
	signal Gin_GMII_TxErr1	: std_logic;

--------------------------------------------------------------------------------
--	Ethernet
--------------------------------------------------------------------------------
	signal Eth_IRQs 		: std_logic_vector( 7 downto 0) := (others => L);
	signal Eth_BRAM_Clk 	: std_logic;
	signal Eth_BRAM_EN 		: std_logic;
	signal Eth_BRAM_WEN 	: std_logic_vector( 7 downto 0);
	signal Eth_BRAM_Addr 	: std_logic_vector(15 downto 0);
	signal Eth_BRAM_Dout 	: std_logic_vector(63 downto 0);
	signal Eth_BRAM_Din 	: std_logic_vector(63 downto 0);

	signal Eth_GMII_RxDat	: std_logic_vector( 7 downto 0);
	signal Eth_GMII_RxDv 	: std_logic;
	signal Eth_GMII_RxErr 	: std_logic;
	signal Eth_GMII_TxDat	: std_logic_vector( 7 downto 0);
	signal Eth_GMII_TxDv 	: std_logic;
	signal Eth_GMII_TxErr 	: std_logic;

	signal TxEthRun			: std_logic;

--------------------------------------------------------------------------------
--	GinLink Slave
--------------------------------------------------------------------------------
	signal Gin_BRAM_Clk		: std_logic;
	signal Gin_BRAM_EN		: std_logic;
	signal Gin_BRAM_WEN		: std_logic_vector( 7 downto 0);
	signal Gin_BRAM_Addr	: std_logic_vector(15 downto 0);
	signal Gin_BRAM_Dout	: std_logic_vector(63 downto 0);
	signal Gin_BRAM_Din		: std_logic_vector(63 downto 0);

	signal Gin_fwGMII_RxDat	: std_logic_vector(7 downto 0);
	signal Gin_fwGMII_RxDv	: std_logic;
	signal Gin_fwGMII_RxErr	: std_logic;
	signal Gin_fwGMII_TxDat	: std_logic_vector(7 downto 0);
	signal Gin_fwGMII_TxDv	: std_logic;
	signal Gin_fwGMII_TxErr	: std_logic;
	
	signal Gin_bwGMII_RxDat	: std_logic_vector(7 downto 0);
	signal Gin_bwGMII_RxDv	: std_logic;
	signal Gin_bwGMII_RxErr	: std_logic;
	signal Gin_bwGMII_TxDat	: std_logic_vector(7 downto 0);
	signal Gin_bwGMII_TxDv	: std_logic;
	signal Gin_bwGMII_TxErr	: std_logic;

	signal fwGinRun			: std_logic;
	signal bwGinRun			: std_logic;
	signal bwGinxChanger 	: std_logic;
	signal Sw_Gin_Eth 		: std_logic; 

	signal Gin_IRQs			: std_logic_vector( 7 downto 0);
	signal Gin_Wdogs		: std_logic_vector( 7 downto 0);
	signal Gin_TlgSyn		: std_logic_vector( 7 downto 0);
	signal GF_Flags			: std_logic_vector(15 downto 0);
	signal cIntCnt 			: std_logic;
	
--------------------------------------------------------------------------------
--	MII
--------------------------------------------------------------------------------
	signal	MII_Clk			: std_logic;
	signal	MII_Do			: std_logic;
	signal	MII_T			: std_logic;
	signal	MII_Di			: std_logic;		
	signal	Phy0_LEDgn		: std_logic;
	signal	Phy0_LEDyel		: std_logic;
	signal	Phy1_LEDgn		: std_logic;
	signal	Phy1_LEDyel		: std_logic;		
	signal	Phy0_LineStat	: std_logic_vector(15 downto 0);
	signal	Phy1_LineStat	: std_logic_vector(15 downto 0);
                         
--------------------------------------------------------------------------------
--	Wdog
--------------------------------------------------------------------------------
	signal	EthTx_LedDog	: std_logic;

    signal	WDog_Gin_3    	: std_logic;
	signal	bwGinFrm_LedDog	: std_logic;
	signal	fwGinFrm_LedDog	: std_logic;

--------------------------------------------------------------------------------
--	GE_LED Flasher
--------------------------------------------------------------------------------
	signal	Flash_1000		: std_logic;
	signal	Flash_0100		: std_logic;
	signal	Flash_0010		: std_logic;
	signal	Flash_0001		: std_logic;

	signal	Flash_1100		: std_logic;
	signal	Flash_0011		: std_logic;
	signal	Flash_1010		: std_logic;
	signal	Flash_0101		: std_logic;
	signal	Flash_1110		: std_logic;

--------------------------------------------------------------------------------
--	signals synch from 125MHz to 110MHz
--------------------------------------------------------------------------------
 	signal	Bus_Irq_Gin_7	: std_Logic;
 	signal	Bus_Irq_Gin_3	: std_Logic;
    signal	Bus_WDog_Gin_3	: std_logic;
 	signal	Bus_TlgSyn_3	: std_Logic;

	signal dr_pwm_sin_gain	: std_logic_vector(31 downto 0) := (others => L);
	signal dr_pwm_sin_phase	: std_logic_vector(31 downto 0) := (others => L);
	
	signal breakpwm : std_logic;
	signal break_prec : std_logic_vector(6 downto 0);
	signal dr_extflg : std_logic_vector(31 downto 0);
	signal breakpwm_cen : std_logic;
	
	signal fanpwm : std_logic;
	signal fan_prec : std_logic_vector(6 downto 0);
	
	constant DF_MAX_PER : std_logic_vector(9 downto 0) := (others => H);
	signal phase_cnt : std_logic_vector(9 downto 0) := (others => L);
	signal phase_val : std_logic_vector(31 downto 0) := (others => L);
	signal phase_per : std_logic_vector(9 downto 0) := (others => L);
	signal log_pha_n1 : std_logic := L;
	
	signal dpr_Ang0 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_Mag0 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_sin0 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_cos0 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_Ang1 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_Mag1 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_sin1 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_cos1 : std_logic_vector(15 downto 0) := (others => L);
	
	signal dpr_ErrAng : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_Posout : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_Speed : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_Speedsum : std_logic_vector(15+5 downto 0) := (others => L);
	signal sincos_cnt : std_logic_vector(7 downto 0) := (others => L);
	signal dpr_sincos_cnt : std_logic_vector(7 downto 0) := (others => L);
	signal dpr_Pos0 : std_logic_vector(31 downto 0) := (others => L);
	signal dpr_Pos1 : std_logic_vector(31 downto 0) := (others => L);
	signal dpr_Pos_Ang : std_logic_vector(31 downto 0) := (others => L);
	signal dpr_Pos_ad7356 : std_logic_vector(31 downto 0) := (others => L);
	signal angdifexp_sum : std_logic_vector(16+3 downto 0) := (others => L);
	signal AngdifFltOUT : std_logic_vector(31 downto 0) := (others => L);
	
	signal dpr_sinOffset : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_cosOffset : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_sinGain : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_sinPase : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_w2 : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_d2w : std_logic_vector(15 downto 0) := (others => L);
	signal dpr_atan : std_logic_vector(63 downto 0);
	signal dpr_tracking : std_logic_vector(63 downto 0);
	signal dpr_t1 : std_logic_vector(63 downto 0);
	signal sincos_trig : std_logic := L;
	signal sincos_trig_t1 : std_logic := L;
	signal sincos_trig0 : std_logic := L;
	signal sincos_trig1 : std_logic := L;
	signal sincos_trig2 : std_logic := L;
	signal sincos_trig3 : std_logic := L;
	signal sincos_trig4 : std_logic := L;
	signal sincos_trig5 : std_logic := L;
	signal sincos_trig6 : std_logic := L;
	signal sincos_trig7 : std_logic := L;
	signal sincos_trig8 : std_logic := L;
	signal dpr_off : std_logic_vector(31 downto 0);
	signal dpr_gain : std_logic_vector(31 downto 0);
	signal dpr_filt : std_logic_vector(31 downto 0);
	signal dpr_sincos_flg : std_logic_vector(31 downto 0);
	signal inc_cnt : std_logic_vector(11 downto 0);
	
	signal ad7356_da : std_logic_vector(11 downto 0) := (others => L);
	signal ad7356_db : std_logic_vector(11 downto 0) := (others => L);
	
--------------------------------------------------------------------------------

begin -- architecture ----------------------------------------------------------

	o_PWM_brake <= log_brake;
	
	no_flashReset <= not periph_rst;
	
	sio_nRX(DF_SYSTEM_UART) <= ni_sioRX;
	no_sioTX <= sio_nTX(DF_SYSTEM_UART);
	sio_nRTS(DF_SYSTEM_UART) <= ni_sioRTS;
	no_sioCTS <=  sio_nCTS(DF_SYSTEM_UART); 
	
	no_PWMEn <= not dr_RESflg(DF_RSFLG_PWM_EN) when periph_rst=L else H;
	
	TestV32_1(DF_REG_LENGTH-1 downto 0) <= pwm_cnt;
	
	-- interrupts --------------------------------------------------------------
	reg_Interrups( 0) <= ils_int0;
	reg_Interrups( 1) <= ils_int1;
	reg_Interrups( 2) <= ils_int4;
	reg_Interrups( 3) <= L;
	reg_Interrups( 4) <= sio_txInt(DF_SYSTEM_UART);
	reg_Interrups( 5) <= sio_rxInt(DF_SYSTEM_UART);
	reg_Interrups( 6) <= L;
	reg_Interrups( 7) <= L;
	reg_Interrups( 8) <= L;
	reg_Interrups( 9) <= L;
	reg_Interrups(10) <= ilm_int;
	reg_Interrups(11) <= pwm_int;
	reg_Interrups(12) <= sio_txInt(DF_ENCODER_UART);
	reg_Interrups(13) <= sio_rxInt(DF_ENCODER_UART);
	reg_Interrups(14) <= Eth_IRQs(7);
	reg_Interrups(15) <= Bus_Irq_Gin_7;	-- page-7	communication
	reg_Interrups(16) <= Bus_Irq_Gin_3;	-- page-3   fast axsis channels
	
	-- clocks ------------------------------------------------------------------
	clk_mod : entity dcm_clk_module.dcm_clk_module
	generic map (
		C_CLK_FREQ => C_OSC_CLK_FREQ
	)
	port map ( 
		i_Clk => i_sys_clk,
		o_dcmLocked => dcmLocked,
		o_bus_clk => bus_clk,
		o_bus_clk_90 => bus_clk_90,
		o_bus_clk_180 => bus_clk_180,
		o_bus_clk_270 => bus_clk_270,
		o_ocm_clk => ocm_clk,
		o_ppc_clk => ppc_clk,
		o_il_cLk => il_CLk,
		i_ddr_fb_clk => i_ddr_clk,
		o_ddr_fb_90 => ddr_clk_90,
		o_ddr_fb_270 => ddr_clk_270
	);
	
	-- ppc-inst: uart, plb-sdram, bootram, plb-bram and 2 opb-interface --------
	ppc_inst : entity ppc_module.ppc_module
	generic map (
		C_SDRAM_WIDTH => 16,
		C_NUM_PLBBRAM_IF => C_NUM_PLBBRAM_IF,
		C_BASEADDR_PLBBRAM_IF_2 => X"7100_0000",
		C_HIGHADDR_PLBBRAM_IF_2 => X"71FF_FFFF",
		C_BASEADDR_PLBBRAM_IF_3 => X"7200_0000",
		C_HIGHADDR_PLBBRAM_IF_3 => X"72FF_FFFF",
		C_NUM_OPB_IF => DF_NUM_OPB_IF,
		C_BASEADDR_OPB_IF_1 => C_BASEADDR_OPB_IF_1,
		C_HIGHADDR_OPB_IF_1 => C_HIGHADDR_OPB_IF_1,
		C_BASEADDR_OPB_IF_2 => C_BASEADDR_OPB_IF_2,
		C_HIGHADDR_OPB_IF_2 => C_HIGHADDR_OPB_IF_2,
		C_NUM_UARTS => C_NUM_UARTS,
		C_BUS_CLK_FREQ => C_BUS_CLK_FREQ,
		C_OPB_BOOT_RAM => 1,
		C_ISOCM_BOOT_RAM => 1,
		C_ISOCMCLJRATIO => 2,
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
		i_plb_clk => bus_clk,
		i_opb_clk => bus_clk,
		i_plb_clk180 => bus_clk_180,
		i_plb_clk90 => bus_clk_90,
		i_plb_clk270 => bus_clk_270,
		i_ddr_clk90 => ddr_clk_90,
		i_ddr_clk270 => ddr_clk_270,
		-- uart
		ni_sioRX => sio_nRX,
		no_sioTX => sio_nTX,
		ni_sioRTS => sio_nRTS,
		no_sioCTS => sio_nCTS,
		o_485_RnW => sio_485_RnW,
		o_sio_txInt => sio_txInt,
		o_sio_rxInt => sio_rxInt,
		-- ddr ram
		o_ddrClkp => o_ddrClkp,
		o_ddrClkn => o_ddrClkn,
		o_ddrAddr => o_ddrAddr,
		o_ddrBankAddr => o_ddrBankAddr,
		no_ddrCas => no_ddrCas,
		o_ddrCe => o_ddrCe,
		no_ddrCs => no_ddrCs,
		no_ddrRas => no_ddrRas,
		no_ddrWe => no_ddrWe,
		o_ddrDm => o_ddrDm,
		b_ddrDqs_i => ddrDqs_i,
		b_ddrDq_i => ddrDq_i,
		b_ddrDqs_o => ddrDqs_o,
		b_ddrDq_o => ddrDq_o,
		b_ddrDqs_t => ddrDqs_t,
		b_ddrDq_t => ddrDq_t,
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
	opbif_register_inst : entity opbif_register.opbif_register
	generic map (
		-- LEDs
		C_INIT_LEDREG => x"0000_0000",
		-- INFOLINK
		C_INIT_INFOREG => x"0000_1800",
		-- Memory read and write access times for all memory banks
		C_INIT_MEMREG => C_INIT_MEMREG,
		-- HW Revision
		C_REVISION => DF_REVISION,
		C_NUM_INTR_INPUTS => DF_NUM_OF_IRQS,
		C_KIND_OF_INTR => "00000000000000000000000110001111",
		C_POS_N_NEG => "00000000000000000000011110111111",
		-- Target typ: DF_TARGET_IMP2=0, DF_TARGET_SAC2=1, ...
		C_TARGET => DF_PKG_TARGET_SAC2,
		-- CARD_TYP: default imp2 typ
		C_CARD_TYP => DF_PKG_CARD_TYP_SAC2,
		C_SYNC_IL => C_SYNC_IL,
		C_CONF_PI_COUNTER => 1,
		C_DWIDTH => 32,
		C_AWIDTH => 32,
		DF_FLAGS => 1,
		C_NUM_OF_GPIO => 4,
		C_SVN_NO => DF_SVN_REV
	)
	port map (
		i_Clk => bus_clk,
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
		no_ErrorLed => reg_nErrorLED,
		ni_PowerLed => il_nPowerLed,
		ni_LinkLed => il_nLinkLed,
		ni_LanLnkLed => net_gnd,
		ni_LanRXLed => net_gnd,
		o_LanLnkLed => open,
		no_LanRXLed => open,
		i_il_Clk => il_Clk,
		o_CIRQ0en => reg_CIRQ0en,
		o_CIRQ1en => reg_CIRQ1en,
		o_IMPCmpEn => reg_ilCmpEn,
		i_blinki => ils_blinki,
		i_AddrS => sr_AddrSin,
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
		o_flags => reg_flags,
		i_Intr => reg_Interrups,
		o_Irq => reg_ppc_ext_irq,
		o_CritIrq => reg_ppc_crit_irq,
		i_Free1 => TestV32_1,
		i_Free2 => TestV32_2,
		o_i2cSCL => o_SCL,
		b_i2cSDA_I => b_SDA,
		b_i2cSDA_O => i2cSDA_O,
		b_i2cSDA_T => i2cSDA_T,
		b_jtgTCK_I => b_jtagTCK,
		b_jtgTCK_O => jtagTCK_O,
		b_jtgTCK_T => jtagTCK_T,
		b_jtgTMS_I => b_jtagTMS,
		b_jtgTMS_O => jtagTMS_O,
		b_jtgTMS_T => jtagTMS_T,
		b_jtgTDO_I => b_jtagTDO,
		b_jtgTDO_O => jtagTDO_O,
		b_jtgTDO_T => jtagTDO_T,
		b_jtgTDI_I => b_jtagTDI,
		b_jtgTDI_O => jtagTDI_O,
		b_jtgTDI_T => jtagTDI_T,
		b_GPIO_T => reg_GPIO_T,
		b_GPIO_O => reg_GPIO_O,
		b_GPIO_I => reg_GPIO_I
	);
	Phy_reset <= reg_flags(16);
	
	-- second opb-interface 0xE0000000: flash ----------------------------------
	--0xE0000000..0xEFFFFFFF: flash
	opbif_extmem_inst : entity opbif_extmem.opbif_extmem
	generic map (
		-- Target typ
		C_TARGET => DF_PKG_TARGET_NO_LAN,		-- DF_PKG_TARGET_LAN, DF_PKG_TARGET_NO_LAN, or >=256 for develop
		--Generics set for IPIF
		C_DWIDTH => 32,
		C_AWIDTH => 32
		)
	port map (
		-- System Port Declarations -------------------------------------------
		i_Clk => bus_clk,
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
		i_ConfReg => reg_MemConfig,
		-- Memory signals -----------------------------------------------------
		o_Mem_A => o_flashADR,
		b_Mem_DQ_I => b_flashDAT,
		b_Mem_DQ_O => mc_data_O,
		b_Mem_DQ_T => mc_data_T,
		no_Flash_CEn => no_flashCEn,
		no_Mem_OEN => no_flashOE,
		no_Mem_WEN => o_flashRnW
	);
	
	-- dpr: side a plb, side b infolink and register ---------------------------
	fieldbus_dpr : entity dpr1aNb.dpr1anb
	generic map (
		C_PORT_DWIDTH => 64,
		C_PORT_AWIDTH => 32,
		C_NUM_OF_BLOCKS => 3,
		C_PORT_B0_DWIDTH => 32,
		C_PORT_B0_AWIDTH => 11,
		C_B0_BLOCK_ENABLED => DF_INFOLINK,
		C_PORT_B1_DWIDTH => 64,
		C_PORT_B1_AWIDTH => 10,
		C_B1_HALF_SIZE => 4,
		C_PORT_B2_DWIDTH => 32,
		C_PORT_B2_AWIDTH => 11,
		C_B2_RAM_EN_MASK => "0001"
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
		i_Data_B1 => reg2dpr_Data,
		-- sinus gen. bram port
		i_Rst_B2 => sin2dpr_Rst,
		i_Clk_B2 => sin2dpr_Clk,
		i_EN_B2 => sin2dpr_EN,
		i_WEN_B2 => sin2dpr_WEN,
		i_Addr_B2 => sin2dpr_Addr,
		o_Data_B2 => dpr2sin_Data,
		i_Data_B2 => sin2dpr_Data
		
	);
	
	-- infolink field bus ------------------------------------------------------
	no_info_link : if (DF_INFOLINK=0) generate
	begin 
		o_ilTX <= pwm_convSt;--ni_ilRX and periph_rst;
		ils_int0 <= L;
		ils_int1 <= L;
		ils_int4 <= L;
		ilm_int <= L;
		ilm_JobIRQ <= L;
		ilm_CIRQ <= L;
		ilm_Error <= L;
		ilm_Ovrun <= L;
		ilm_Or1ms <= L;
		il_nLinkLed <= H;
		il_nPowerLed <= H;
		ils_blinki <= L;
		il_wdog <= L;
		periph_rst66 <= L;
	end generate no_info_link;
	
	info_link_inst : if (DF_INFOLINK=1) generate
	begin
		sync_to_il_clk : if C_SYNC_IL=1 generate
		begin
		clk_dom_change_66to99 : process (bus_clk)
		begin
			if rising_edge(bus_clk) then
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
		end process clk_dom_change_66to99;
			clk_dom_change_99to66 : process (il_CLk)
		begin
				if rising_edge(il_CLk) then
				periph_rst66 <= periph_rst;
			end if;
		end process clk_dom_change_99to66;
		end generate sync_to_il_clk;
	
		il_clk_is_sync : if C_SYNC_IL=0 generate
		begin
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
			periph_rst66 <= periph_rst;
		end generate il_clk_is_sync;
		
		-- for i_clk = 66MHz:
		--i_WDOG_TIME = 00 => 1117.090909
		--i_WDOG_TIME = 01 => 2234.181818
		--i_WDOG_TIME = 10 => 4468.363636
		--i_WDOG_TIME = 11 => 8936.727273
		il66_WDOG_TIME <= "10";
		
		info_link : entity dpr2infoMS.dpr2infoMS
		generic map (
			C_CLK_DIV_22MHZ => C_IL_CLK_DIV_22MHZ,
			C_ChipScope_Implemented => 0,
			C_SpezJob_Implemented => 0,		-- old-fashion compatible
			C_SAC_SUP => 1,
			C_32BITJOBS => 0,
			C_CONF_INCO => 0
			)
		port map (
			-- std-ports
			i_Clk => il_Clk,
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
			i_CIRQ0 => reg_CIRQ0en,			-- high-activ
			i_CIRQ1 => reg_CIRQ1en,			-- high-activ
			o_blinki => ils66_blinki,
			i_IMPCmpEn => reg_ilCmpEn,
			i_CardTyp => reg_CardTyp,
			i_AddrSwitch => reg_AddrS,
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
	end generate info_link_inst;
	
	-- analog inputs -----------------------------------------------------------
	o_ADC_cs <= periph_rst;

	
	si : if 1=1 generate
		constant C_ADCLNG  : integer := 16;
		constant C_ALGLNG  : integer := 12;
		constant C_FLTLNG  : integer := 16;
		constant C_ADDRLNG : integer := 2;
		
		signal adc_cnt : std_logic_vector(11 downto 0) := (others => L);
		signal Ang : std_logic_vector(C_ALGLNG-1 downto 0) := (others => L);
		signal AngOld : std_logic_vector(C_ALGLNG-1 downto 0) := (others => L);
		signal ErrAng : std_logic_vector(C_FLTLNG-1 downto 0) := (others => L);
		signal PosOld : std_logic_vector(C_FLTLNG-1 downto 0) := (others => L);
		signal PosOut : std_logic_vector(C_FLTLNG-1 downto 0) := (others => L);
		signal Mag : std_logic_vector(C_ALGLNG-1 downto 0) := (others => L);
		signal Speed : std_logic_vector(C_FLTLNG-1 downto 0) := (others => L);
		signal iaddr : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => L);
		signal oaddr : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
		signal oaddr1 : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
		signal oaddr2 : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
		signal oaddrsc : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
		signal fltaddr : std_logic_vector(C_ADDRLNG-1 downto 0) := (others => H);
		signal w2 : std_logic_vector(17 downto 0) := (others => L);
		signal d2w : std_logic_vector(17 downto 0) := (others => L);
		signal SpeedSum : std_logic_vector(C_FLTLNG-1 downto 0) := (others => L);
		signal save_pwm_convSt : std_logic := L;
		signal saved_sincos_trig : std_logic := L;
		signal old_enc : std_logic_vector(11 downto 0) := (others => L);
		type t_fltlng is array (0 to 16) of std_logic_vector(C_FLTLNG+3 downto 0);
		signal AngdifFlt : t_fltlng := (others => (others => L));
		signal adc_dout_a12 : std_logic_vector(2*12-1 downto 0);
		signal adc_dout_b12 : std_logic_vector(2*12-1 downto 0);
		signal ad7356_cs : std_logic := L;
		signal ad7356_clk : std_logic := L;
		signal ad7356_clkcnt : std_logic_vector(5 downto 0) := (others => L);
		signal ad7356_sra : std_logic_vector(11 downto 0) := (others => L);
		signal ad7356_srb : std_logic_vector(11 downto 0) := (others => L);
		
		signal Posflt : std_logic_vector(31 downto 0) := (others => L);
		
		signal osin : std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		signal ocos : std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		
		signal sin_in : std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		signal cos_in : std_logic_vector(C_ADCLNG-1 downto 0) := (others => L);
		
		signal ad7356_ain : std_logic;
		signal ad7356_bin : std_logic;
		
	begin
		o_ad7356_cs <= ad7356_cs;
		o_ad7356_clk <= ad7356_clk;
		
		o_dbg <= ad7356_sra(0);
		o_dbg2 <= iaddr(1);
		
		ad7356 : process(bus_clk)
		begin
			if rising_edge(bus_clk) then
				ad7356_ain <= i_ad7356_ain;
				ad7356_bin <= i_ad7356_bin;
				if (ad7356_clkcnt=29) then
					ad7356_clk <= H;
					ad7356_cs <= H;
					if (acd_start_conv=H) then
						ad7356_clkcnt <= (others => L);
					end if;
				elsif (ad7356_clkcnt=28) then
					ad7356_clk <= H;
					ad7356_cs <= H;
					ad7356_da <= ad7356_sra(ad7356_da'high-1 downto 0) & ad7356_ain;
					ad7356_db <= ad7356_srb(ad7356_db'high-1 downto 0) & ad7356_bin;
					--if (acd_start_conv=H) then
					--	ad7356_clkcnt <= (others => L);
					--else
						ad7356_clkcnt <= ad7356_clkcnt + 1;
					--end if;
				else
					ad7356_cs <= L;
					ad7356_clkcnt <= ad7356_clkcnt + 1;
					ad7356_clk <= not ad7356_clkcnt(0);
				end if;

				if (ad7356_clk=L) then
					ad7356_sra <= ad7356_sra(ad7356_da'high-1 downto 0) & ad7356_ain;
					ad7356_srb <= ad7356_srb(ad7356_db'high-1 downto 0) & ad7356_bin;
				end if;
			end if;
		end process ad7356;
	
		o_ADC_addr0 <= L;
		
		adcs : entity ADS8361_if.ADS7863_if
		generic map (
			C_NUM_ADC => 2,
			C_CLK_DIV => 2
		)
		port map (
			i_Clk => bus_clk,
			i_Reset => periph_rst,				-- high-activ
			--ADS8361 Pins
			o_ADCclk => o_ADC_clk,
			no_CS => open,						-- pin kommt von sac_logic
			o_Convst => o_ADC_convst,
			o_Read => open,
			--o_Addr0 => o_ADC_addr0,
			o_SDI => open,
			i_sDataA => i_ADC_din_a,
			i_sDataB => i_ADC_din_b,
			-- interface	 
			o_DataA => adc_dout_a12,				-- zu sac2register
			o_DataB => adc_dout_b12,				-- zu sac2register
			o_Channel => open,
			o_data_ready => adc_d_ready,		-- zu sac_logic
			--i_next_Channel => adc_next_ch,		-- von sac_logic
			i_start_conv => acd_start_conv		-- von sac_logic
		);
		
		adc_dout_a <= adc_dout_a12(23 downto 12) & "0000" & (ad7356_da+x"800") & "0000";
		adc_dout_b <= adc_dout_b12(23 downto 12) & "0000" & (ad7356_db+x"800") & "0000";
		sincosfilter : entity sincos.sincos
		generic map (
			C_ADCLNG    => C_ADCLNG,
			C_ALGLNG    => C_ALGLNG,
			C_FLTLNG    => C_FLTLNG,
			C_NO_SINCOS => 2,
			C_ADDRLNG => C_ADDRLNG
		)
		port map (
			i_clk => bus_clk,
			i_intclr => dpr_sincos_flg(31),
			i_sin => sin_in,
			i_cos => cos_in,
			i_sinOffset => dpr_sinOffset,
			i_cosOffset => dpr_cosOffset,
			i_sinGain =>   dpr_sinGain,
			i_sinPase =>   dpr_sinPase,
			--i_nw2 => w2,
			--i_nd2w => d2w,
			o_angle => Ang,
			o_magnitude => Mag,
			--o_Pos => posout,
			o_Pos => Posflt,
			--o_Speed => Speed,
			--o_ErrAng => ErrAng,
			o_sin => osin,
			o_cos => ocos,
			i_addr => iaddr,
			o_addr => oaddr,
			o_sc_addr => oaddrsc,
			o_flt_addr => fltaddr
		);
		
		w2 <= L & dpr_w2 & L ;
		d2w <= L & dpr_d2w & L;
		
		triggers : process (bus_clk)
		begin
			if rising_edge(bus_clk) then
			-- clocked statements
--				adc_ADCx0_trig <= L;
				adc_ADCx1_trig <= L;
				adc_d_ready_old <= adc_d_ready;
				acd_start_conv <= L;
				--if (pwm_convSt=H or pwm_convSt180=H) then
				--	adc_next_ch <= pwm_convSt;
				--	acd_start_conv <= H;
				--end if;
				adc_next_ch <= L;
				if pwm_run=L then
					adc_cnt <= (others => L);
				else
					adc_cnt <= adc_cnt + 1;
					--if (pwm_convSt=H) then
					if (pwm_pwm0=H) then
						--adc_next_ch <= pwm_convSt;
						acd_start_conv <= H;
						adc_cnt <= (others => L);
					elsif adc_cnt=dpr_sincos_flg(7 downto 0) and dpr_sincos_flg(29)=H then
						if dpr_sincos_flg(15 downto 8)>sincos_cnt then
							acd_start_conv <= H;
						end if;
						adc_cnt <= (others => L);
					end if;
				end if;
				
				if adc_d_ready=H and adc_d_ready_old=L then
					--adc_next_ch <= not adc_next_ch;
					--if adc_next_ch=H then
					-- adc_ADCx0_trig <= H;
					--else
					--	adc_ADCx1_trig <= H;
					--end if;
				end if;
			end if;
		end process;
		
		adc_ADCx0_trig <= sincos_trig;
		
		sincos_reg : process (bus_clk)
		variable sig : std_logic_vector(31 downto C_FLTLNG);
		variable speed32 : std_logic_vector(31 downto 0);
		variable angsig : std_logic_vector(31 downto C_FLTLNG);
		variable angdif : std_logic_vector(C_FLTLNG-1 downto 0);
		variable angdifexp : std_logic_vector(C_FLTLNG+3 downto 0);
		variable angdif32 : std_logic_vector(31 downto 0);
		variable AngdifFlt332 : std_logic_vector(31 downto 0);
		begin
			if rising_edge(bus_clk) then
				if (acd_start_conv=H) then
					inc_cnt <= inc_cnt + (enc_cnt(DF_ENC_SINCOS)-old_enc);
					old_enc <= enc_cnt(DF_ENC_SINCOS);
				end if;
				if adc_d_ready=H and adc_d_ready_old=L then
					iaddr <= (others => L);
					dpr_sinOffset <= dpr_off(31 downto 16);
					dpr_cosOffset <= dpr_off(15 downto 0);
					dpr_sinGain <= dpr_gain(31 downto 16);
					dpr_sinPase <= dpr_gain(15 downto 0);
					sin_in <= adc_dout_a(31 downto 16);
					cos_in <= adc_dout_b(31 downto 16);
					
				else
					if iaddr=0 then
						iaddr <= "01";
						dpr_sinOffset <= end_tx_data_m(0)(31 downto 16);
						dpr_cosOffset <= end_tx_data_m(0)(15 downto 0);
						dpr_sinGain <= dpr_filt(31 downto 16);
						dpr_sinPase <=  dpr_filt(15 downto 0);
						sin_in <= adc_dout_a(15 downto 0);
						cos_in <= adc_dout_b(15 downto 0);
					else
						iaddr <= (others => H);
					end if;
				end if;
				sincos_trig <= L;
				sincos_trig_t1 <= L;
				oaddr1 <= oaddr;
				oaddr2 <= oaddr1;
				
				if (fltaddr=0) then
					dpr_Ang0(15 downto C_ALGLNG) <= (others => Ang(C_ALGLNG-1));
					dpr_Ang0(C_ALGLNG-1 downto 0) <= Ang;
					dpr_Mag0(15 downto C_ALGLNG) <= (others => Mag(C_ALGLNG-1));
					dpr_Mag0(C_ALGLNG-1 downto 0) <= Mag;
				end if;
				if (oaddr=0) then
					dpr_Pos0 <= Posflt;
				end if;
				
				if (oaddrsc=0) then
					dpr_sin0 <= osin;
					dpr_cos0 <= ocos;
				end if;
				
				if (fltaddr=1) then
					dpr_Ang1(15 downto C_ALGLNG) <= (others => Ang(C_ALGLNG-1));
					dpr_Ang1(C_ALGLNG-1 downto 0) <= Ang;
					dpr_Mag1(15 downto C_ALGLNG) <= (others => Mag(C_ALGLNG-1));
					dpr_Mag1(C_ALGLNG-1 downto 0) <= Mag;
				end if;
				if (oaddr=1) then
					dpr_Pos1 <= Posflt;
				end if;
				
				if (oaddrsc=1) then
					dpr_sin1 <= osin;
					dpr_cos1 <= ocos;
				end if;
				
				
				if (oaddr=0) then
				--	
				--	if (Ang(C_ALGLNG-1 downto C_ALGLNG-2)="00") then -- 0..90°	inc_cnt xxx00
				--		if (inc_cnt(1 downto 0)="11") then
				--			inc_cnt <= inc_cnt+1;
				--		elsif (inc_cnt(1 downto 0)="01") then
				--			inc_cnt <= inc_cnt-1;
				--		end if;
				--	elsif (Ang(C_ALGLNG-1 downto C_ALGLNG-2)="01") then -- 90..180°	inc_cnt xxx01
				--		if (inc_cnt(1 downto 0)="00") then
				--			inc_cnt <= inc_cnt+1;
				--		elsif (inc_cnt(1 downto 0)="10") then
				--			inc_cnt <= inc_cnt-1;
				--		end if;
				--	elsif (Ang(C_ALGLNG-1 downto C_ALGLNG-2)="10") then -- -90..-180°	inc_cnt xxx10
				--		if (inc_cnt(1 downto 0)="01") then
				--			inc_cnt <= inc_cnt+1;
				--		elsif (inc_cnt(1 downto 0)="11") then
				--			inc_cnt <= inc_cnt-1;
				--		end if;
				--	else -- 0..-90°	inc_cnt xxx11
				--		if (inc_cnt(1 downto 0)="10") then
				--			inc_cnt <= inc_cnt+1;
				--		elsif (inc_cnt(1 downto 0)="00") then
				--			inc_cnt <= inc_cnt-1;
				--		end if;
				--	end if;
				--	
				--	dpr_Ang(15 downto C_ALGLNG) <= (others => Ang(C_ALGLNG-1));
				--	dpr_Ang(C_ALGLNG-1 downto 0) <= Ang;
				--	dpr_Mag(15 downto C_ALGLNG) <= (others => Mag(C_ALGLNG-1));
				--	dpr_Mag(C_ALGLNG-1 downto 0) <= Mag;
				--	
				--	angdif := signed(posout) - signed(posold);
				--	angsig := (others => angdif(C_FLTLNG-1));
				--	angdif32 := angsig & angdif;
				--	dpr_Pos <= signed(dpr_Pos) + signed(angdif32);
				--	posold <= posout;
				--	
				--	angdif := signed(Ang) - signed(AngOld);
				--	angsig := (others => angdif(C_FLTLNG-1));
				--	angdif32 := angsig & angdif;
				--	if (dpr_sincos_flg(16) = L) then
				--		dpr_Pos_Ang <= signed(dpr_Pos_Ang) + signed(angdif32);
				--	end if;
				--	
				--	angdifexp := angdif(C_FLTLNG-1) & angdif(C_FLTLNG-1) & angdif(C_FLTLNG-1) & angdif(C_FLTLNG-1) & angdif;
				--	AngdifFlt(0) <= angdifexp;
				--	for i in 0 to AngdifFlt'high-1 loop
				--		AngdifFlt(i+1) <= AngdifFlt(i);
				--	end loop;
				--	
				--	AngOld <= Ang;
				--	
				--	for i in 0 to 15 loop
				--		if (i<C_FLTLNG) then
				--			dpr_ErrAng(i) <= ErrAng(i);
				--			dpr_Posout(i) <= posout(i);
				--			dpr_Speed (i) <= Speed(i);
				--		else
				--			dpr_ErrAng(i) <= ErrAng(C_FLTLNG-1);
				--			dpr_Posout(i) <= posout(C_FLTLNG-1);
				--			dpr_Speed (i) <= Speed(C_FLTLNG-1);
				--		end if;
				--	end loop;
				--	
				--	sig := (others => Speed(C_FLTLNG-1));
				--	speed32 := sig & Speed;
					sincos_trig <= save_pwm_convSt;
				--	saved_sincos_trig <= save_pwm_convSt;
				--	if (saved_sincos_trig=H) then
				--		dpr_Speedsum <= speed32(dpr_Speedsum'range);
				--		dpr_sincos_cnt <= sincos_cnt;
				--		sincos_cnt <= (others => L);
				--		sincos_cnt(0) <= H;
				--	else
				--		dpr_Speedsum <= (signed(dpr_Speedsum) + signed(speed32(dpr_Speedsum'range)));
				--		sincos_cnt <= sincos_cnt + 1;
				--	end if;
					save_pwm_convSt <= L;
					
					sincos_trig0 <= save_pwm_convSt;
					sincos_trig1 <= sincos_trig0;
					sincos_trig2 <= sincos_trig1;
					sincos_trig3 <= sincos_trig2;
					sincos_trig4 <= sincos_trig3;
					sincos_trig5 <= sincos_trig4;
					sincos_trig6 <= sincos_trig5;
					sincos_trig7 <= sincos_trig6;
					sincos_trig8 <= sincos_trig7;
					
					if (dpr_sincos_flg(16) = L) then
						sincos_trig_t1 <= save_pwm_convSt;
					else
						--if (dpr_sincos_flg(18 downto 17) = "00") then
						--	sincos_trig_t1 <= sincos_trig1;
						--	if (dpr_sincos_flg(20 downto 19)="11") then
						--		sincos_trig_t1 <= sincos_trig5;
						--	end if;
						--elsif (dpr_sincos_flg(18 downto 17) = "01") then
						--	sincos_trig_t1 <= sincos_trig2;
						--	if (dpr_sincos_flg(20 downto 19)="11") then
						--		sincos_trig_t1 <= sincos_trig6;
						--	end if;
						--elsif (dpr_sincos_flg(18 downto 17) = "10") then
						--	sincos_trig_t1 <= sincos_trig3;
						--	if (dpr_sincos_flg(20 downto 19)="11") then
								sincos_trig_t1 <= sincos_trig7;
						--	end if;
						--else
						--	sincos_trig_t1 <= sincos_trig4;
						--	if (dpr_sincos_flg(20 downto 19)="11") then
						--		sincos_trig_t1 <= sincos_trig8;
						--	end if;
						--end if;
					end if;
					
					
				end if;
				--if (oaddr1=0) then
				--	AngdifFlt332(angdifexp'high downto 0) := signed(AngdifFlt(0)) + signed(angdifexp_sum);
				--	if (dpr_sincos_flg(20 downto 19)="00") then
				--		AngdifFlt332(angdifexp'high downto 0) := signed(AngdifFlt332(angdifexp'high downto 0))-signed(AngdifFlt(2));
				--	elsif (dpr_sincos_flg(20 downto 19)="01") then
				--		AngdifFlt332(angdifexp'high downto 0) := signed(AngdifFlt332(angdifexp'high downto 0))-signed(AngdifFlt(4));
				--	elsif (dpr_sincos_flg(20 downto 19)="10") then
				--		AngdifFlt332(angdifexp'high downto 0) := signed(AngdifFlt332(angdifexp'high downto 0))-signed(AngdifFlt(8));
				--	else
				--		AngdifFlt332(angdifexp'high downto 0) := signed(AngdifFlt332(angdifexp'high downto 0))-signed(AngdifFlt(16));
				--	end if;
				--	angdifexp_sum <= AngdifFlt332(angdifexp'high downto 0);
				--	AngdifFlt332(31 downto angdifexp'length) := (others => AngdifFlt332(angdifexp'high));
				--	AngdifFltOUT <= signed(AngdifFltOUT) + signed(AngdifFlt332);
				--end if;
				--if (oaddr2=0) then
				--	if (dpr_sincos_flg(16) = H) then
				--		if (dpr_sincos_flg(20 downto 19)="00") then
				--			dpr_Pos_Ang <= AngdifFltOUT(31) & AngdifFltOUT(31 downto 1);
				--		elsif (dpr_sincos_flg(20 downto 19)="01") then
				--			dpr_Pos_Ang <= AngdifFltOUT(31) & AngdifFltOUT(31) & AngdifFltOUT(31 downto 2);
				--		elsif (dpr_sincos_flg(20 downto 19)="10") then
				--			dpr_Pos_Ang <= AngdifFltOUT(31) & AngdifFltOUT(31) & AngdifFltOUT(31) & AngdifFltOUT(31 downto 3);
				--		else
				--			dpr_Pos_Ang <= AngdifFltOUT(31) & AngdifFltOUT(31) & AngdifFltOUT(31) & AngdifFltOUT(31) & AngdifFltOUT(31 downto 4);
				--		end if;
				--	end if;
				--	
				--	if (dpr_sincos_flg(16) = L) then
				--		sincos_trig_t1 <= sincos_trig0;
				--	else
				--		if (dpr_sincos_flg(18 downto 17) = "00") then
				--			sincos_trig_t1 <= sincos_trig1;
				--			if (dpr_sincos_flg(20 downto 19)="11") then
				--				sincos_trig_t1 <= sincos_trig5;
				--			end if;
				--		elsif (dpr_sincos_flg(18 downto 17) = "01") then
				--			sincos_trig_t1 <= sincos_trig2;
				--			if (dpr_sincos_flg(20 downto 19)="11") then
				--				sincos_trig_t1 <= sincos_trig6;
				--			end if;
				--		elsif (dpr_sincos_flg(18 downto 17) = "10") then
				--			sincos_trig_t1 <= sincos_trig3;
				--			if (dpr_sincos_flg(20 downto 19)="11") then
				--				sincos_trig_t1 <= sincos_trig7;
				--			end if;
				--		else
				--			sincos_trig_t1 <= sincos_trig4;
				--			if (dpr_sincos_flg(20 downto 19)="11") then
				--				sincos_trig_t1 <= sincos_trig8;
				--			end if;
				--		end if;
				--	end if;
				--	
				--end if;
				
				if (pwm_convSt=H) then
					save_pwm_convSt <= H;
				end if;
				-- pos reset
				if dpr_sincos_flg(30)=H then
--					dpr_Pos <= (others => L);
					dpr_Pos_Ang <= (others => L);
					AngdifFltOUT <= (others => L);
					angdifexp_sum <= (others => L);
					AngdifFlt(0) <= (others => L);
					inc_cnt <= (others => L);
					inc_cnt(1 downto 0) <= Ang(C_ALGLNG-1 downto C_ALGLNG-2);
				end if;
			end if;
		end process;
	end generate si;
	
	-- 3ph sym. pwms -----------------------------------------------------------
	
	o_PWM_Ua <= pwm_Ua(0);
	o_PWM_Ub <= pwm_Ub(0);
	o_PWM_Va <= pwm_Va(0);
	o_PWM_Vb <= pwm_Vb(0);
	o_PWM_Wa <= pwm_Wa(0);
	o_PWM_Wb <= pwm_Wb(0);
	-- invert resolver output!
	o_SinPWM <= pwm_nSinPWM(0);
	no_SinPWM <= pwm_SinPWM(0);
	pwm_stop(0) <= log_stop;
	
	pwm3ph : entity Motor_PWM.Motor_PWM
	generic map (
		C_REG_LENGTH => DF_REG_LENGTH,
		C_PWM_CNT_LENGTH => 14,
		C_DT_CNT_LENGTH => 8,	-- if 0 -> no deattime
		C_DT_MIN => 32,
		C_SIN_CNT_LENGTH => 8,	-- if 0 -> no sin_gen
		C_NUM_SINGEN => 1,
		C_ADDR_LENGTH => 9,
		C_NR_3PH_PWM => DF_NUM_3PH_PWM,
		C_BREAK_PWM => 0,
		C_MIN_PULSE => 0,
		C_NO_INPUT_REGISTER => 1,
		C_ENABLE_OVERSAMPLING => 1,
		C_NEW_SINGEN => 1
	)
	port map (
		i_Clk => bus_clk,
		i_Reset => periph_rst,
		-- Dualport Ram access
		o_dprEN => sin2dpr_EN,
		o_dprClk => sin2dpr_Clk,
		o_dprRst => sin2dpr_Rst,
		o_dprWEN => sin2dpr_WEN,
		o_dprData => sin2dpr_Data,
		i_dprData => dpr2sin_Data,
		o_dprAddr => sin2dpr_Addr(8 downto 0),
		-- interrupt
		o_INT => pwm_int,					-- int. rising-edge
		-- start of convert
		o_convSt => pwm_convSt,				-- pwmCnt=i_Conv_St and UP => o_convSt=H
		o_convSt180 => pwm_convSt180,		-- i_PWM_100-pwmCnt=i_Conv_St and DOWN => o_convSt180=H
		o_cPWM0 => pwm_pwm0,
		o_PWM_cnt => pwm_cnt,
		-- config inputs
		i_PWM_100 => pwm_100_time,-- maximum of PwmCnt
		i_PWM_INT => pwm_int_time,-- PwmCnt=i_PWM_INT activate IRQ
		i_dead_time => pwm_dead_time,-- dead time of bridge
		i_index_val => pwm_sin_index,-- ((SIN_TAB_LNG-1)*(2**C_SHIFT))/i_PWM_100
--1		i_SIN_phase => pwm_sin_phase,-- sin phase 0=0°/i_PWM_100=180°
		i_Conv_St => pwm_convSt_time,-- pwmCnt=i_Conv_St => o_convSt=H
		i_oversampling => pwm_oversampling,
		
		i_half_freq => dr_RESflg(DF_RSFLG_PWM_OS2+1),
		o_PwmDown => log_status(5),
		-- 3PH-PWM controll
		i_Stop => pwm_stop,-- extern IGBT-Disable
		i_PWM_U => pwm_u_time,
		i_PWM_V => pwm_v_time,
		i_PWM_W => pwm_w_time,
		-- IGBT outputs
		o_Ua => pwm_Ua,	-- U IGBT-output
		o_Ub => pwm_Ub,
		o_Va => pwm_Va,	-- V IGBT-output
		o_Vb => pwm_Vb,
		o_Wa => pwm_Wa,	-- W IGBT-output
		o_Wb => pwm_Wb,
		-- sinus geni
		o_SinPWM  => pwm_SinPWM,
		no_SinPWM => pwm_nSinPWM,
		o_SinCycle => pwm_sinCycle,
		i_gain => dr_pwm_sin_gain(31 downto 24),
		i_phase => dr_pwm_sin_phase(31 downto 24),
		o_PPC_Wdog => pwm_PPC_WDog,
		o_run => pwm_run
	);
	
	brake : entity pwm.break_pwm
		generic map (
			C_LNG => 7,
			C_100PERC => 100,
			C_MODE => 0
		)
		PORT MAP (
			i_Clk => bus_clk,
			i_Reset => periph_rst,
			i_clk_en => breakpwm_cen,
			o_PWM => breakpwm,
			i_value => break_prec
	);
	-- before sr_start
	breakpwm_cen <= pwm_convSt or pwm_convSt180;
	-- range 0..100
	break_prec <= dr_extflg(6 downto 0);
	
	log_brake <= (breakpwm or dr_RESflg(DF_RSFLG_BRE)) and not pwm_PPC_WDog;
	
	fan : entity pwm.break_pwm
		generic map (
			C_LNG => 7,
			C_100PERC => 100,
			C_MODE => 1
		)
		PORT MAP (
			i_Clk => bus_clk,
			i_Reset => periph_rst,
			i_clk_en => pwm_convSt,
			o_PWM => fanpwm,
			i_value => fan_prec
	);
	
	fan_prec <= dr_extflg(6+8 downto 8);
	
	log_fan <= (fanpwm or dr_RESflg(DF_RSFLG_FAN)) and not pwm_PPC_WDog;
	
	-- encoders ----------------------------------------------------------------
	enc_synch : process (bus_clk)
	begin
		if rising_edge(bus_clk) then
			-- 1. stage
			-- sinus cosinus interface
			enc_a_s(DF_ENC_SINCOS) <= i_SCI_cos;
			enc_b_s(DF_ENC_SINCOS) <= i_SCI_sin;
			enc_ref_s(DF_ENC_SINCOS) <= i_SCI_ref;
			-- incremental interface
			enc_a_s(DF_ENC_INC) <= i_IncI_a;
			enc_b_s(DF_ENC_INC) <= i_IncI_b;
			enc_ref_s(DF_ENC_INC) <= i_IncI_ref;
			-- 2. stage
			enc_a <= enc_a_s;
			enc_b <= enc_b_s;
			enc_ref <= enc_ref_s;
		end if;
	end process enc_synch;
	-- 2 increment counters 
	encoders : for i in DF_ENC_SINCOS to DF_ENC_INC generate
	begin
		enc : entity increment_counter.increment_counter
		generic map (
			C_CNT_LENGTH => 12,
			C_ZPCNT_LENGTH => 4,
			C_REG_LENGTH => DF_REG_LENGTH,
			C_INC_FILTER => 1,						-- 0: no filter / 1: filter
			C_SYNCHRONIZE => 0
		)
		port map (
			i_Clk => bus_clk,
			i_Reset => periph_rst,
			-- increment input signals
			i_IncA => enc_a(i),
			i_IncB => enc_b(i),
			i_ZeroPulse => enc_ref(i),
			-- increment output signals
			o_IncCnt => enc_cnt(i),
			o_ZPCnt => enc_zpcnt(i),
			o_IncReg => enc_cnt2(i),
			o_ZeroPulse => enc_ZeroPulse(i)
		);
	end generate encoders;
	
	-- sigma delta u and i measurement -----------------------------------------
	sd_trig <= pwm_convSt;
	sd_180_trig <= pwm_convSt180;
	
	o_sd_sClk <= sd_sClk;
	-- sClk < 20MHz, sd_clk_cnt shuld count at least to DF_NUM_SD_DEVICES/2
	-- 4 devices, busclock 99 or 110MHz and sd_clk_cnt>20MHz
	-- 99MHz/6 => 16.5MHz / 110MHz/6 => 18.3MHz
	sd_clk_gen : process (bus_clk)
	begin
		if rising_edge(bus_clk) then 
			sd_clk_cnt <= sd_clk_cnt + 1;
			sd_dataready <= L;
			if (sd_clk_cnt=2) then
				sd_sClk <= not sd_sClk;
				sd_clk_cnt <= (others => L);
				if (sd_sClk=L) then
					sd_dataready <= H;
				end if;
			end if;
		end if;
	end process sd_clk_gen;
	
	i_sd_inst : entity sigma_delta.sigma_delta_synchron
	generic map (
		C_OVERRANGE => 25,
		C_CLK_DIV => 32,
		C_REG_LNG => DF_REG_LENGTH,
		C_NUM_SD_DEVICES => DF_NUM_SD_DEVICES
	)
	port map (
		i_Clk => bus_clk,
		i_Reset => net_gnd,
		i_dataready => sd_dataready,
		--sigma_delta Pins
		i_sData => i_sd_sData,
		-- interface
		o_DataLA => sd_analog_data,
		o_overrange => sd_overrange
	);

	-- shift_register ----------------------------------------------------------
	sr_outputs( 0) <= il_nLinkLed;
	sr_outputs( 1) <= il_nPowerLed;
	sr_outputs( 2) <= not (log_active or dr_flags(DF_ACTIVE_LED_OR));--not (dr_flags(DF_FLG_OUT1) or dr_flags(DF_OUT1_LED_OR));
	sr_outputs( 3) <= not (dr_flags(DF_FLG_OUT1) or dr_flags(DF_OUT1_LED_OR));--not (log_active or dr_flags(DF_ACTIVE_LED_OR));
	sr_outputs( 4) <= not (log_ext_en or dr_flags(DF_EXTEN_LED_OR));
	sr_outputs( 5) <= not (enc_ref(DF_ENC_INC) or dr_flags(DF_REF_LED_OR));
	sr_outputs( 6) <= not (enc_a(DF_ENC_INC) or dr_flags(DF_A_LED_OR));
	sr_outputs( 7) <= not (enc_b(DF_ENC_INC) or dr_flags(DF_B_LED_OR));
	sr_outputs( 8) <= not (log_brake or dr_flags(DF_BRAKE_LED_OR));--not dr_flags(DF_FLG_LED_UCC);
	sr_outputs( 9) <= not dr_flags(DF_FLG_LED_IMAX);
	sr_outputs(10) <= not dr_flags(DF_FLG_LED_CTRL);
	sr_outputs(11) <= not dr_flags(DF_FLG_LED_MOT);
	sr_outputs(12) <= not dr_flags(DF_FLG_LED_RES);
	sr_outputs(13) <= not dr_flags(DF_FLG_LED_PWM);
	sr_outputs(14) <= reg_nOkLED;
	sr_outputs(15) <= reg_nErrorLED;
	sr_outputs(16) <= not dr_RESflg(DF_RSFLG_POT_CS);
	sr_outputs(17) <= dr_RESflg(DF_RSFLG_POT_UP);
	sr_outputs(18) <= dr_RESflg(DF_RSFLG_POT_INC);
	sr_outputs(19) <= not log_fan;
	sr_outputs(20) <= not log_relais;
	sr_outputs(21) <= not dr_flags(DF_FLG_OUT1);
	sr_outputs(22) <= not dr_flags(DF_FLG_OUT0);--log_active;
	sr_outputs(23) <= not dr_flags(DF_FLG_LED_UCC);--not (log_brake or dr_flags(DF_BRAKE_LED_OR));

	sr_AddrSin <= sr_inputs(23 downto 16);
	
	no_srOutEn <= not(sr_out_en and dr_RESflg(DF_RSFLG_SR_EN));
	o_srLoad <= srLoad;
	
	srLoadREdge <= srLoad and not srLoadold;
	srLoadFEdge <= not srLoad and srLoadold;
	
	sr_power_on : process(bus_clk)
	begin
		if rising_edge(bus_clk) then
			srLoadold <= srLoad;
			if srLoadREdge=H then
				sr_out_en <= H;
			else
				sr_out_en <= sr_out_en;
			end if;
		end if;
	end process sr_power_on;
	
	-- shiftreg. run continuous when pwm is off
	sr_start <= H when (pwm_run=L or pwm_convSt_time=0) else H;
	
	sr : entity shift_register.shift_register
	generic map (
		C_NR_OF_IOS	=> 24,
		C_CLK_DIV	=> C_CLK_DIV	-- max 20 mhz
	)
	port map (
		i_Clk => bus_clk,
		i_Reset => periph_rst,
		i_Start => sr_start,
		o_serClk => o_srClk,
		o_serLoad => srLoad,
		o_serData => o_srData,
		i_serData => i_srData,
		i_outputs => sr_outputs,
		o_inputs => sr_inputs
	);
	
	-- register dpr ------------------------------------------------------------
	
	dpr_t1 <= dpr_Pos0 & dpr_Pos1;
	dpr_tracking <= dpr_Ang0 & dpr_Mag0 & dpr_sin0 & dpr_cos0;
	dpr_atan <= dpr_Ang1 & dpr_Mag1 & dpr_sin1 & dpr_cos1;
	
	
	--dpr_sinOffset <= dpr_off(31 downto 16);
	--dpr_cosOffset <= dpr_off(15 downto 0);
	--dpr_sinGain <= dpr_gain(31 downto 16);
	--dpr_sinPase <= dpr_gain(15 downto 0);
	--dpr_w2 <= dpr_filt(31 downto 16);
	--dpr_d2w <= dpr_filt(15 downto 0);
	
	dpr_reg : entity dpr2MotReg.dpr2MotReg
	generic map (
		C_PWM => 1,
		C_SI  => 3,
		C_ADC => 2,
		C_CM  => 4,
		C_ENC => 2
	)
	port map (
		--System
		i_Clk => bus_clk,
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
		i_ADCA1 => adc_dout_a(31 downto 16),
		i_ADCB0 => adc_dout_b(15 downto 0),
		i_ADCB1 => adc_dout_b(31 downto 16),
		-- current m
		i_sdADC0 => sd_analog_data(15  downto  0),
		i_sdADC1 => sd_analog_data(31  downto 16),
		i_sdADC2 => sd_analog_data(47  downto 32),
		i_sdADC3 => sd_analog_data(63  downto 48),
		-- encoders 
		i_Enc0 => enc_cnt2(0),
		i_Enc1 => enc_cnt2(1),
		-- misc     
		i_Status => log_status,
		i_ExtStatus => GND32,
		i_PWMCnt => pwm_cnt,
		i_16 => open,
		i_d_in => phase_val,
		i_SI0 => dpr_t1,--endat_ssi_reg_m(0),
		i_SI1 => dpr_tracking,
		i_SI2 => dpr_atan,
		-- outputs  
		-- pwm      
		o_PWM_U0 =>  pwm_u_time,
		o_PWM_V0 =>  pwm_v_time,
		o_PWM_W0 =>  pwm_w_time,
		-- pwm 100%
		o_PWM_100 => pwm_100_time,
		-- pwm irq
		o_PWM_INT => pwm_int_time,
		-- convert stars
		o_Conv_St => pwm_convSt_time,
		--
		o_dead_time => pwm_dead_time,
		o_index_val => pwm_sin_index,
		
		o_sin_gain => dr_pwm_sin_gain,
		o_sin_phase => dr_pwm_sin_phase,
		--
		o_RESflg => dr_RESflg,
		o_Ext_Flg => dr_extflg,
		o_Flags => dr_flags,
		-- serial interface (ssi, endat...)
		o_si_config0 => dr_si_config_m(0),
		o_SI0 => end_tx_data_m(0),
		o_Si_Read => si_Read,
		o_si_config1 => dpr_off  ,
		o_SI1		 => dpr_gain ,
		o_si_config2 => dpr_filt ,
		o_SI2		 => dpr_sincos_flg ,
		--
		i_PWM_Run => pwm_run,
		-- triggers 
		i_cADC_0 =>   adc_ADCx0_trig,
		i_cADC_180 => adc_ADCx1_trig,
		i_cCM => sd_trig,
		i_cCM180 => sd_180_trig,
		i_cIntCnt => cIntCnt,
		i_cEncZP0 => enc_ZeroPulse(0),
		i_cEncZP1 => enc_ZeroPulse(1),
		i_cPWM0 => pwm_pwm0,
		i_cSI0 => sincos_trig_t1,--endat_ssi_trig_m(0),
		i_cSI1 => sincos_trig_t1,
		i_cSI2 => sincos_trig_t1
	);
	
	-- synch with GinLink Page-3 start data access pulse
	cIntCnt <= Bus_TlgSyn_3;-- axis jop 
	
	-- endat and ssi -----------------------------------------------------------
	endat_start : process(bus_clk)
	begin
		if rising_edge(bus_clk) then
			-- write comparators
			for i in 0 to DF_NUM_OF_ESI-1 loop
				if (plb2bram_EN(0)=H and plb2bram_Addr(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH-1)=DF_END_WD_ADDR(i)(DF_ADDR_HIGH-ADDR_WIDTH-1 to DF_ADDR_HIGH-1) and plb2bram_WEN(4 to 7)/=0) then -- write to 0x70002500 + 8*i + 4
					si_written(i) <= H;
				end if;
				
				if (si_Read(i)=H and si_written(i)=H) then
					end_start(i) <= H;
					si_written(i) <= L;
				else
					end_start(i) <= L;
				end if;
			end loop;
		end if;
	end process endat_start;
	
	endat_ssi_inst : for i in 0 to DF_NUM_OF_ESI-1 generate
	begin
		endat_ssi_enc : entity endat.endat
		generic map (
			C_SR_LNG => 64,
			C_CLK_CNT_LNG => 9,
			C_DATA_CNT_LNG => pkg_log2(64),
			C_HIPERFACE_SUPPORT => 1,
			C_CRC_ERROR_SUP => 1
		)
		port map (
			i_Clk => bus_clk,
			-- config
			i_clk_div => dr_si_config_m(i)(24 downto 16),
			i_data_lng => dr_si_config_m(i)(pkg_log2(64)-1 downto 0),
			--endat Pin controll
			o_sClk => end_sClk_m(i),
			i_sData => end_sData_in_m(i),
			o_sData => end_sData_out_m(i),
			o_RnW => end_RnW_m(i),
			-- interface
			o_Data => endat_ssi_reg_m(i),
			i_mode => end_mode_m(i),
			i_Data => end_tx_data_m(i)(23 downto 0),
			o_data_ready => endat_ssi_trig_m(i),
			i_Enable => end_enable_m(i),
			--i_SSInEndat => SSInEndat_m(i),
			i_Select => esi_Select(i),
			i_start => ssi_start_m(i)
		);
	
		-- encoder serial interface ------------------------------------------------
		-- support:
		--		SSI: synchron serial interface clock out and data in
		--		RS485 or (soft) hiperface: 2. uart: bidirectoinal data
		--		RS422: 2. uart: clock as data out and data in
		--		EnDat: synchron serial interface clock out and bidirectoinal data
		--		hiperface: read pos. only (need no uart)
		--		todo: BiSS heinz.erb@digana.ch für Muster-Drehgeber
		-- dr_si_config(15)=1 invert rx and tx at RS422 and RS485
		-- dr_si_config(14..12) 1:SSI,2:RS485,3:RS422,4:EnDat,5:hiperface
		serial_interface_mux : process(si_data_in,si_clk_in,sio_485_RnW,sio_nTX,si_selector,dr_RESflg,dr_si_config_m, pwm_convSt, end_start, end_RnW_m, end_sClk_m, end_sData_out_m, end_tx_data_m)
		begin
			-- defaults
			-- pins (defaults = GPIOs)
			si_data_WnR(i) <= dr_RESflg(DF_RSFLG_SIDIR_D_0 + i);
			si_data_out(i) <= dr_RESflg(DF_RSFLG_SIOUT_D_0 + i);
			si_clk_WnR(i) <= dr_RESflg(DF_RSFLG_SIDIR_C_0 + i);
			si_clk_out(i) <= dr_RESflg(DF_RSFLG_SIOUT_C_0 + i);
			-- endat / ssi
			esi_Select(i) <= DF_SEL_SSI;
			end_enable_m(i) <= L;
			ssi_start_m(i) <= L;
			end_mode_m(i) <= "000";
			end_sData_in_m(i) <= si_data_in(i);
			-- uart
			sio_nRX_si(i) <= L;
			if(dr_si_config_m(i)( 14 downto 12)=DF_ESI_SSI) then
				si_clk_WnR(i) <= H; -- output
				si_data_WnR(i) <= L; -- input
				end_enable_m(i) <= H;
				si_clk_out(i) <= end_sClk_m(i);
				esi_Select(i) <= DF_SEL_SSI;
				--SSInEndat_m(i) <= H;
				if (dr_si_config_m(i)(15)=H) then
					ssi_start_m(i) <= pwm_convSt;
				else
					ssi_start_m(i) <= end_start(i);
				end if;
			elsif (dr_si_config_m(i)(14 downto 12)=DF_ESI_HIPER) then
				-- clk = default...
				si_data_WnR(i) <= not(end_RnW_m(i)); -- bidi
				si_data_out(i) <= end_sData_out_m(i);
				end_enable_m(i) <= H;
				esi_Select(i) <= DF_SEL_HIP;
				ssi_start_m(i) <= end_start(i);
			elsif (dr_si_config_m(i)(14 downto 12)=DF_ESI_RS485) then
				si_data_WnR(i) <= not(sio_485_RnW(DF_ENCODER_UART)); -- bidi
				if (sio_485_RnW(DF_ENCODER_UART)=H) then
					-- receive
					sio_nRX_si(i) <= dr_si_config_m(i)(15) xor si_data_in(i);
				else
					-- transfer
					si_data_out(i) <= dr_si_config_m(i)(15) xor sio_nTX(DF_ENCODER_UART);
				end if;
			elsif (dr_si_config_m(i)(14 downto 12)=DF_ESI_RS422) then
				si_clk_WnR(i) <= H; -- output
				si_data_WnR(i) <= L; -- input
				-- receive
				sio_nRX_si(i) <= dr_si_config_m(i)(15) xor si_data_in(i);
				-- transfer
				si_clk_out(i) <= dr_si_config_m(i)(15) xor sio_nTX(DF_ENCODER_UART);
			elsif (dr_si_config_m(i)(14 downto 12)=DF_ESI_ENDAT) then
				si_clk_WnR(i) <= H; -- output
				si_data_WnR(i) <= not(end_RnW_m(i)); -- bidi
				end_mode_m(i) <= end_tx_data_m(i)(26 downto 24);
				end_enable_m(i) <= H;
				esi_Select(i) <= DF_SEL_END;
				--SSInEndat_m(i) <= L;
				si_clk_out(i) <= end_sClk_m(i);
				si_data_out(i) <= end_sData_out_m(i);
				if (dr_si_config_m(i)(15)=H) then
					ssi_start_m(i) <= pwm_convSt;
				else
					ssi_start_m(i) <= end_start(i);
				end if;
			end if;
		end process serial_interface_mux;
	
	end generate endat_ssi_inst;
	

	
	b_si_data <= si_data_out(0) when si_data_WnR(0)=H else Z;
	o_SI_WnR_data <= si_data_WnR(0);
	si_data_in(0) <= b_si_data;
	b_si_clk <= si_clk_out(0) when si_clk_WnR(0)=H else Z;
	o_SI_WnR_clk <= si_clk_WnR(0);
	si_clk_in(0) <= b_si_clk;
	
	sio_nRX(DF_ENCODER_UART) <= sio_nRX_si(0);
	
	-- logic, misc -------------------------------------------------------------
	pwm_oversampling(2 downto 0) <= dr_RESflg(DF_RSFLG_PWM_OS2 downto DF_RSFLG_PWM_OS0) when dr_RESflg(DF_RSFLG_PWM_OS2 downto DF_RSFLG_PWM_OS0)/="000" else "001";
	
	log_relais <= dr_RESflg(DF_RSFLG_REL) and not pwm_PPC_WDog;
	
	log_active <= not log_stop;
	log_stop <= PPC_WDog or not(dr_flags(DF_FLG_ACT)) or log_shorty or log_off;
	
	security : process (bus_clk)
	begin
		if rising_edge(bus_clk) then
			PPC_WDog <= pwm_PPC_WDog or (PPC_WDog and not(dr_flags(DF_FLG_CLR_ERR)));
			
			log_off <= (not(log_ext_en or dr_flags(DF_FLG_INT_EN)))
						or (log_off and not(dr_flags(DF_FLG_CLR_ERR)));
			log_shorty <= (log_shorty and not(dr_flags(DF_FLG_CLR_ERR)))
						or (sd_overrange(DF_SD_U))
						or (sd_overrange(DF_SD_V))
						or (sd_overrange(DF_SD_W));
			if (periph_rst=H) then
				PPC_WDog <= H;
				log_shorty <= H;
				log_off <= H;
			end if;
		end if;
	end process security;
	
	log_synch : process (bus_clk)
	begin
		if rising_edge(bus_clk) then
			-- 1. stage
			log_ext_en_s <= i_ExtEn;
			log_pha_s <= not ni_Phases;
			log_mot_temp_s <= i_mot_temp;
			-- 2. stage
			log_ext_en <= log_ext_en_s;
			log_pha <= log_pha_s;
			log_mot_temp <= log_mot_temp_s;
		end if;
	end process log_synch;
	
	log_status(DF_STAT_PPC   ) <= PPC_WDog;
	log_status(DF_STAT_PHA   ) <= log_pha;
	log_status(DF_STAT_SAF_REL0   ) <= not ni_safRelFb0;
	log_status(DF_STAT_SAF_REL1   ) <= not ni_safRelFb1;
	log_status(DF_STAT_EXT_EN) <= log_ext_en;
	log_status(DF_STAT_ENC_NP) <= enc_ref(DF_ENC_INC);
	log_status(DF_STAT_ENC_A ) <= enc_a(DF_ENC_INC);
	log_status(DF_STAT_ENC_B ) <= enc_b(DF_ENC_INC);
	log_status(DF_SINCYCLE   ) <= pwm_sinCycle;
	log_status(DF_STAT_SI_C ) <= b_SI_clk;
	log_status(DF_STAT_SI_D  ) <= b_SI_data;--hcs/acs Jumper  H;
	log_status(DF_STAT_SC_REF  ) <= enc_ref(DF_ENC_SINCOS);
	log_status(DF_STAT_SC_A  ) <= enc_a(DF_ENC_SINCOS);
	log_status(DF_STAT_SC_B  ) <= enc_b(DF_ENC_SINCOS);
	log_status(DF_STAT_IRED  ) <= L;
	log_status(DF_STAT_WDOG  ) <= Bus_WDog_Gin_3;
	log_status(DF_STAT_MTEMP ) <= log_mot_temp;
	log_status(DF_STAT_AUS   ) <= log_off;
	log_status(DF_STAT_KURZ  ) <= log_shorty;
	log_status(DF_STAT_STP   ) <= log_stop;
	
	no_safRelFb <= not dr_flags(DF_FLG_SFB_OUT);
	
	AC_phase : process (bus_clk)
	begin
		if rising_edge(bus_clk) then
			if (pwm_pwm0=H) then
				log_pha_n1 <= log_pha;
				if ((log_pha=L and log_pha_n1=H) or phase_per=DF_MAX_PER) then
					phase_per <= (others => L);
					phase_cnt <= (others => L);
					phase_val <= "000000" & phase_per & "000000" & phase_cnt;
				else
					phase_per <= phase_per + 1;
					if (log_pha=H) then
						phase_cnt <= phase_cnt + 1;
					end if;
				end if;
			end if;
		end if;
	end process AC_phase;
	
	-- bidis -------------------------------------------------------------------
	ddrDqs_i <= b_ddrDqs;
	ddrDq_i <= b_ddrDq;
	b_ddrDq_iobuf : for i in b_ddrDq'range generate
	begin
		b_ddrDq(i) <= Z when ddrDq_t(i)=H else ddrDq_o(i);
	end generate b_ddrDq_iobuf;

	b_ddrDqs_iobuf : for i in b_ddrDqs'range generate
	begin
		b_ddrDqs(i) <= Z when ddrDqs_t(i)=H else ddrDqs_o(i);
	end generate b_ddrDqs_iobuf;
	
	p_data_iobuf : for i in b_flashDAT'range generate
	begin
		b_flashDAT(i) <= Z when mc_data_T(i)=H else mc_data_O(i);
	end generate p_data_iobuf;
	
	b_SDA <= Z when i2cSDA_T=H else i2cSDA_O;
	
	b_jtagTCK <= Z when jtagTCK_T=H else jtagTCK_O;
	b_jtagTMS <= Z when jtagTMS_T=H else jtagTMS_O;
	b_jtagTDO <= Z when jtagTDO_T=H else jtagTDO_O;
	b_jtagTDI <= Z when jtagTDI_T=H else jtagTDI_O;
	
--------------------------------------------------------------------------------
--	125MHz	DCM
--------------------------------------------------------------------------------
	phy_clk : entity RGMII_if.RGMII_clk
	port map (
		-- phy
		i_PHY_CLK125	=> i_PHY_CLK125,
		-- clk outputs
		o_clkPHY		=> clk125,
		o_clkPHY_90	=> open,
		o_clkPHYdiv2	=> clk62_5,
		o_clkref200MHz	=> ref_clk,
		o_dcm_locked	=> phy_dcm_Locked
	);

--------------------------------------------------------------------------------
-- Instantiate IDELAYCTRL for the IDELAY in Fixed Tap Delay Mode
--------------------------------------------------------------------------------			
	dlyctrl_0 : IDELAYCTRL
	port map (
		RDY	=> open,
		REFCLK	=> ref_clk,
		RST	=> idel_rst
	);
	idel_rst	<= not phy_dcm_locked;

	no_PHY_RESET <= phy_dcm_Locked;
--------------------------------------------------------------------------------
--	Phy-0 		!!- SAC3 hat Eth-Stecker vertauscht -!!
--------------------------------------------------------------------------------
	phy_if0 : entity RGMII_if.RGMII_if
	generic map (
		C_ELASTIC_BUF_LAT => 5
	)
	port map (
		i_tx_clk		=> clk125,
		-- user interface
		o_data			=> Gin_GMII_RxDat1,
		o_data_valid	=> Gin_GMII_RxDv1,
		o_data_error	=> Gin_GMII_RxErr1,
		i_data			=> Gin_GMII_TxDat1,
		i_data_valid	=> Gin_GMII_TxDv1,
		i_data_error	=> Gin_GMII_TxErr1,
		-- rgmii ---------------------------------------------------------------
		i_PHY_RXC		=> i_PHY_RXC0,
		o_PHY_TXD		=> o_PHY_TXD0,
		o_PHY_TXEN		=> o_PHY_TXEN0,
		i_PHY_RXD		=> i_PHY_RXD0,
		i_PHY_RXDV		=> i_PHY_RXDV0,
		o_PHY_GTXCLK	=> o_PHY_GTXCLK0
	);
--------------------------------------------------------------------------------
--	Phy-1 		!!- SAC3 hat Eth-Stecker vertauscht -!!	
--------------------------------------------------------------------------------
	phy_if1 : entity RGMII_if.RGMII_if
	generic map (
		C_ELASTIC_BUF_LAT => 5
	)
	port map (
		i_tx_clk		=> clk125,
		-- user interface
		o_data			=> Gin_GMII_RxDat0,
		o_data_valid	=> Gin_GMII_RxDv0,
		o_data_error	=> Gin_GMII_RxErr0,
		i_data			=> Gin_GMII_TxDat0,
		i_data_valid	=> Gin_GMII_TxDv0,
		i_data_error	=> Gin_GMII_TxErr0,
		-- rgmii ---------------------------------------------------------------
		i_PHY_RXC		=> i_PHY_RXC1,
		o_PHY_TXD		=> o_phy_TXD1,
		o_PHY_TXEN		=> o_phy_TXEN1,
		i_PHY_RXD		=> i_PHY_RXD1,
		i_PHY_RXDV		=> i_PHY_RXDV1,
		o_PHY_GTXCLK	=> o_phy_GTXCLK1
	);


    Gin_fwGMII_RxDat	<= Gin_GMII_RxDat0;	
    Gin_fwGMII_RxDv     <= Gin_GMII_RxDv0; 
    Gin_fwGMII_RxErr    <= Gin_GMII_RxErr0;

    Gin_GMII_TxDat0		<= Gin_bwGMII_TxDat; 
    Gin_GMII_TxDv0		<= Gin_bwGMII_TxDv;  
    Gin_GMII_TxErr0		<= Gin_bwGMII_TxErr; 

--------------------------------------------------------------------------------
--*****	Baschi *****************************************************************    
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	GE_MII			!!- SAC3 hat Eth-Stecker vertauscht -!!
--------------------------------------------------------------------------------

	u_GE_MII: 	entity 	gin_link.GE_MIISeq 
	generic map (
		C_ADDR_4_1 => "0001"
	)
	port map ( 
		i_Q62_5				=> clk62_5			,		                   
	    o_MII_Clk	        => MII_Clk	       	,
	    o_MII_Dout	        => MII_Do	       	,
	    o_MII_T		        => MII_T		   	,
	    o_MII_Dinp		    => MII_Di	       	,
	           
	    i_Phy0_LED1			=> Phy1_LEDgn	   	,
	    i_Phy0_LED2			=> Phy1_LEDyel	   	,
	    o_Phy0_LineStat     => Phy1_LineStat   	,
              
	    i_Phy1_LED1			=> Phy0_LEDgn	   	,
	    i_Phy1_LED2			=> Phy0_LEDyel	   	,
	    o_Phy1_LineStat     => Phy0_LineStat   	
	);                      

	MII_Di <= b_PHY_MDIO(0) and b_PHY_MDIO(1);

	o_PHY_MDC(0) <= MII_Clk;
	o_PHY_MDC(1) <= MII_Clk;
	b_PHY_MDIO(0) <= Z when MII_T=H else MII_Do;
	b_PHY_MDIO(1) <= Z when MII_T=H else MII_Do;
    
	reg_GPIO_I(0) <= L;
	reg_GPIO_I(1) <= L;

	MII_Di <= b_PHY_MDIO(0) and b_PHY_MDIO(1);

	o_PHY_MDC(0) <= MII_Clk;
	o_PHY_MDC(1) <= MII_Clk;
	b_PHY_MDIO(0) <= Z when MII_T=H else MII_Do;
	b_PHY_MDIO(1) <= Z when MII_T=H else MII_Do;

--------------------------------------------------------------------------------
--	switch eth_connector 1 is either GinSlave_bw or Ethernet
--------------------------------------------------------------------------------
    -- if AdrSw x4 then with Ethernet
    Sw_Gin_Eth <= sr_AddrSin(2);
    
	process (Sw_Gin_Eth) begin
		if (Sw_Gin_Eth = L) then 
			-- GinSalve only
		    Gin_bwGMII_RxDat	<= Gin_GMII_RxDat1;	
		    Gin_bwGMII_RxDv     <= Gin_GMII_RxDv1; 
		    Gin_bwGMII_RxErr    <= Gin_GMII_RxErr1;

		    Eth_GMII_RxDat		<= x"00";	
		    Eth_GMII_RxDv     	<= L; 
		    Eth_GMII_RxErr    	<= L;

			Gin_GMII_TxDat1		<= Gin_fwGMII_TxDat;
		    Gin_GMII_TxDv1		<= Gin_fwGMII_TxDv;
		    Gin_GMII_TxErr1		<= Gin_fwGMII_TxErr;

			-- if Phy1_LineDown, then bwGinxChanger
			bwGinxChanger <= not Phy1_LineStat(2);

			if (Phy0_LineStat(2) = L) then
			    Phy0_LEDgn  <= 	 Flash_1100;
				Phy0_LEDyel <=	 Flash_0011;  
			    Phy1_LEDgn  <= 	 L;
				Phy1_LEDyel <=	 L;  
			else 
			    Phy0_LEDgn <= 	 H;
				if (fwGinFrm_LedDog = L) then
					Phy0_LEDyel <=	 L;  
				    Phy1_LEDgn  <= 	 L;
					Phy1_LEDyel <=	 L;  
				else					
					Phy0_LEDyel <=	 H;
					if (Phy1_LineStat(2) = L) then
					    Phy1_LEDgn  <= 	 L;
						Phy1_LEDyel <=	 L;  
					else      
					    Phy1_LEDgn  <= 	 H;
						if (bwGinFrm_LedDog = L) then
							Phy1_LEDyel <=	 L;  
				        else
							Phy1_LEDyel <=	 H;  
				        end if;
				    end if;
			    end if;
		    end if;

		else
			-- Gin and Eth ; bw_con == Ethernet
		    Gin_bwGMII_RxDat	<= x"00";	
		    Gin_bwGMII_RxDv     <= L; 
		    Gin_bwGMII_RxErr    <= L;

		    Eth_GMII_RxDat		<= Gin_GMII_RxDat1;	
		    Eth_GMII_RxDv     	<= Gin_GMII_RxDv1; 
		    Eth_GMII_RxErr    	<= Gin_GMII_RxErr1;

			Gin_GMII_TxDat1		<= Eth_GMII_TxDat;
		    Gin_GMII_TxDv1		<= Eth_GMII_TxDv;
		    Gin_GMII_TxErr1		<= Eth_GMII_TxErr;

			-- last Slave, bwGinxChanger
			bwGinxChanger <= H;

			if (Phy0_LineStat(2) = L) then
			    Phy0_LEDgn  <= 	 Flash_1100;
				Phy0_LEDyel <=	 Flash_0011;  
			else 
			    Phy0_LEDgn <= 	 H;
				if (fwGinFrm_LedDog = L) then
					Phy0_LEDyel <=	 L;  
				else					
					Phy0_LEDyel <=	 H;
			    end if;
		    end if;


		    if (Phy1_LineStat(2) = L) then
			    Phy1_LEDgn  <= 	 Flash_1010;
				Phy1_LEDyel <=	 Flash_0101;
			else	  
			    Phy1_LEDgn  <= 	 Flash_1110;
			    if (EthTx_LedDog = L) then
					Phy1_LEDyel <=	 L;
    			else
					Phy1_LEDyel <=	 Flash_1110;
    			end if;
    		end if;	
                                                                                                              
		end if;    
	end process;    
    
 
--------------------------------------------------------------------------------
--	Ethernet instance
--------------------------------------------------------------------------------
	Eth_BRAM_WEN  <= crossbits(plb2bram_WEN(DF_PLB_IF_Eth*8 to DF_PLB_IF_Eth*8+7));                                       
	Eth_BRAM_Addr <= crossbits(plb2bram_Addr(DF_PLB_IF_Eth*32+28-(Gin_BRAM_Addr'length-1) to DF_PLB_IF_Eth*32+28));       
	Eth_BRAM_Dout <= crossbits(plb2bram_Data(DF_PLB_IF_Eth*64 to DF_PLB_IF_Eth*64+63));                                   
	bram2plb_Data(DF_PLB_IF_Eth*64 to DF_PLB_IF_Eth*64+63) <= crossbits(Eth_BRAM_Din);
	Eth_BRAM_Clk <= plb2bram_Clk(DF_PLB_IF_Eth);
	Eth_BRAM_EN <= plb2bram_EN(DF_PLB_IF_Eth);

	uTop_Ethernet: entity gin_eth.ge_wrap
	port map (
		i_ppc_dom_clk		=> bus_clk	   		,
		o_IRQs				=> Eth_IRQs      	,
		i_Q125				=> clk125       	,
		i_Q62_5				=> clk62_5      	,
		o_GMII_TxDat		=> Eth_GMII_TxDat	,
		o_GMII_TxDv			=> Eth_GMII_TxDv	,
		o_GMII_TxErr		=> Eth_GMII_TxErr	,
		i_GMII_RxDat		=> Eth_GMII_RxDat	,
		i_GMII_RxDv			=> Eth_GMII_RxDv	,
		i_GMII_RxErr		=> Eth_GMII_RxErr	,
		o_TxEthRun 			=> TxEthRun       	,
		o_RxEthRun 			=> open         	,
		i_BRAM_Clk 			=> Eth_BRAM_Clk		,
		i_BRAM_EN 			=> Eth_BRAM_EN		,
		i_BRAM_WEN 			=> Eth_BRAM_WEN		,
		i_BRAM_Addr 		=> Eth_BRAM_Addr	,
		i_BRAM_Dout 		=> Eth_BRAM_Dout	,
		o_BRAM_Din 			=> Eth_BRAM_Din
	);

--------------------------------------------------------------------------------
--	GinSalve instance
--------------------------------------------------------------------------------
	Gin_BRAM_WEN  <= crossbits(plb2bram_WEN(DF_PLB_IF_GS*8 to DF_PLB_IF_GS*8+7));
	Gin_BRAM_Addr <= crossbits(plb2bram_Addr(DF_PLB_IF_GS*32+28-(Gin_BRAM_Addr'length-1) to DF_PLB_IF_GS*32+28));
	Gin_BRAM_Dout <= crossbits(plb2bram_Data(DF_PLB_IF_GS*64 to DF_PLB_IF_GS*64+63));
	bram2plb_Data(DF_PLB_IF_GS*64 to DF_PLB_IF_GS*64+63) <= crossbits(Gin_BRAM_Din);
	Gin_BRAM_Clk <= plb2bram_Clk(DF_PLB_IF_GS);
	Gin_BRAM_EN <= plb2bram_EN(DF_PLB_IF_GS);
	uTop_GSlave: entity gin_slave.gs_wrap
	port map (
		i_Q62_5			=> clk62_5,
		i_Q125			=> clk125,
		i_xChanger		=> bwGinxChanger,
		o_PgIRQs		=> Gin_IRQs,
		o_PgWdogs		=> Gin_Wdogs,
		o_PgTlgSyn		=> Gin_TlgSyn,
		o_GF_Flags		=> GF_Flags,
		o_fwGMII_TxDat	=> Gin_fwGMII_TxDat,
		o_fwGMII_TxDv	=> Gin_fwGMII_TxDv,
		o_fwGMII_TxErr	=> Gin_fwGMII_TxErr,
		i_fwGMII_RxDat	=> Gin_fwGMII_RxDat,
		i_fwGMII_RxDv	=> Gin_fwGMII_RxDv,
		i_fwGMII_RxErr	=> Gin_fwGMII_RxErr,
		o_bwGMII_TxDat	=> Gin_bwGMII_TxDat,
		o_bwGMII_TxDv	=> Gin_bwGMII_TxDv,
		o_bwGMII_TxErr	=> Gin_bwGMII_TxErr,
		i_bwGMII_RxDat	=> Gin_bwGMII_RxDat,
		i_bwGMII_RxDv	=> Gin_bwGMII_RxDv,
		i_bwGMII_RxErr	=> Gin_bwGMII_RxErr,
		o_fwGinRun		=> fwGinRun,
		o_bwGinRun		=> bwGinRun,
		i_BRAM_Clk		=> Gin_BRAM_Clk,
		i_BRAM_EN		=> Gin_BRAM_EN,
		i_BRAM_WEN		=> Gin_BRAM_WEN,
		i_BRAM_Addr		=> Gin_BRAM_Addr,
		i_BRAM_Dout		=> Gin_BRAM_Dout,
		o_BRAM_Din		=> Gin_BRAM_Din
	);
	
--------------------------------------------------------------------------------
--	synch signals from 62.5mHz to 110MHz
--------------------------------------------------------------------------------
	clk_dom_change : process(bus_clk) begin
		if rising_edge(bus_clk) then 
			Bus_Irq_Gin_7 	<= Gin_IRQs(7);
			Bus_Irq_Gin_3 	<= Gin_IRQs(3);
			Bus_TlgSyn_3 	<= Gin_TlgSyn(3);
			Bus_WDog_Gin_3 	<= not WDog_Gin_3;
		end if;
	end process;	

--------------------------------------------------------------------------------
--	GinLink WatchDogs	
--------------------------------------------------------------------------------	
	uWrap_GinIrqWdog: entity gin_link.Gin_WatchDog_1ms
	port map (
		i_Q62_5			=> clk62_5      ,
 		i_Probe			=> Gin_Wdogs(3)  , 	-- fast-channel access
		o_Wdog			=> WDog_Gin_3	
    );


	uWrap_bwGinLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5      ,
 		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
 		i_Probe			=> bwGinRun 	, 	-- bwGinFrames ?
		o_Wdog			=> bwGinFrm_LedDog	
    );

	uWrap_fwGinLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5      ,
 		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
 		i_Probe			=> fwGinRun 	, 	-- bwGinFrames ?
		o_Wdog			=> fwGinFrm_LedDog	
    );

	uWrap_EthLdog: entity gin_link.Gin_WatchDog_800ms
	port map (
		i_Q62_5			=> clk62_5      ,
 		i_SynchFlash	=> Flash_1000	,	-- synched with LEDs
 		i_Probe			=> TxEthRun 	, 	-- bwGinFrames ?
		o_Wdog			=> EthTx_LedDog	
    );

--------------------------------------------------------------------------------
--	main Led-Flasher
--------------------------------------------------------------------------------
	uGin_LED_Flasher : entity gin_link.Gin_LED_Flasher 
	port map (
		i_Q62_5			=> clk62_5      ,
 		i_SynchFlash	=> GF_Flags(8)	,	--GinFrame Flag 8 = BlinkBit
                         
		o_Flash_1000	=> Flash_1000  ,
		o_Flash_0100    => Flash_0100  ,
		o_Flash_0010    => Flash_0010  ,
		o_Flash_0001    => Flash_0001  
    );

	Flash_1100 <=	Flash_1000 or Flash_0100;
    Flash_0011 <=   not Flash_1100;
    Flash_1010 <=   Flash_1000 or Flash_0010;
    Flash_0101 <=   not Flash_1010;
    Flash_1110 <=   not Flash_0001;

--------------------------------------------------------------------------------
end architecture STRUCTURE;
