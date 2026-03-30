--------------------------------------------------------------------------------
--
--	COP-VC8
--
--------------------------------------------------------------------------------
--
--	project		: COP-VC8
--	programmer	: C. Leuthold, INDEL AG
--	date		: 11.05.2020
--	version		: 1.00
--	language	: VHDL
--	system		: Project Navigator
--
--	purpose
--		- COP-VC8
--
---------------------------------------------------------------------------



--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	11.05.2020-le	create
--	12.11.2020-le: Rev01:
--					- invert the current measurement
--					- reduce the size of R, kP, IcmdRed, IcmdMAx
--					- adjustments in vlave_crtl
--	29.03.2021-le: Rev02
--					- valve_ctrl: add reset 
--------------------------------------------------------------------------------
--$Rev:: 5884                   $
--$Author:: Leuthold                 $
--$Date:: 2021-04-12 21:06:47 +0200 (Mo., 12 Apr 2021)         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;


library sigma_delta;
use sigma_delta.sigma_delta_synchron;

library BRAM;
use BRAM.all;

library PWM;
use PWM.all;

library C64_Slave;
use C64_Slave.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library Unisim;
use Unisim.vcomponents.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity COP_VC8 is
	generic (
		C_REVISION		: in	std_logic_vector(7 downto 0) := x"02"
	);
	port (
		-- address switch
		 i_AddrSw		: in	std_logic_vector(3 downto 0);

		-- C64-Bus
		 i_C64_CLK		: in	std_logic;
		ni_C64_CLK		: in	std_logic;
		 i_C64_SEL		: in	std_logic;
		 i_C64_Bend		: in	std_logic;
		 b_C64_DatBus	: inout	std_logic_vector(15 downto 0);
		no_C64_Ack		: inout	std_logic;
		 i_C64_Reset	: in	std_logic;

		-- SPI
		no_SPI_CS		: inout	std_logic;
		 o_SPI_CLK		: inout	std_logic;
		 o_SPI_D		: inout	std_logic;
		 i_SPI_Q		: in	std_logic := L;

		-- JTAG
		 o_JTAG_TMS		: inout	std_logic;
		 o_JTAG_TDI		: inout	std_logic;
		 o_JTAG_TCK		: inout	std_logic;
		 i_JTAG_TDO		: in	std_logic;

		no_EEP_Wen		: inout	std_logic;
		no_OkLED		: out	std_logic;
		ni_HWRev		: in	std_logic_vector( 3 downto 0);

		-- axis pwm outputs
		 o_pwm_p		: out	std_logic_vector(7 downto 0);
		 o_pwm_n		: out	std_logic_vector(7 downto 0);
		 o_pwm_en		: out	std_logic_vector(7 downto 0);
		ni_pwm_Fault	: in	std_logic_vector(3 downto 0);
		ni_pwm_OTW		: in	std_logic_vector(3 downto 0);
		 o_pwm_M2		: out	std_logic_vector(3 downto 0);

		-- sigma delta adc
		 o_sd_sClk		: inout	  std_logic_vector(4 downto 0);
		 i_sd_sData		: in	std_logic_vector(8 downto 0);

		 ni_Ucc_Cmp		: in	std_logic
	);
end COP_VC8;

architecture impl of COP_VC8 is
--------------------------------------------------------------------------------
--	C64 Card-Type						 COP-VC8 = x"24"
	constant g_App_Rev		: std_logic_vector := x"24" & C_REVISION;	-- typ,vers

	constant DF_SDREG_LNG : integer := 10;
--------------------------------------------------------------------------------
	-- read
	constant cfg_PWM_pulsecnt0		: std_logic_vector := x"00";
	constant cfg_PWM_pulsecnt1		: std_logic_vector := x"01";
	constant cfg_PWM_pulsecnt2		: std_logic_vector := x"02";
	constant cfg_PWM_pulsecnt3		: std_logic_vector := x"03";
	constant cfg_PWM_pulsecnt4		: std_logic_vector := x"04";
	constant cfg_PWM_pulsecnt5		: std_logic_vector := x"05";
	constant cfg_PWM_pulsecnt6		: std_logic_vector := x"06";
	constant cfg_PWM_pulsecnt7		: std_logic_vector := x"07";
	constant cfg_PWM_Endlesscnt0	: std_logic_vector := x"08";
	constant cfg_PWM_Endlesscnt1	: std_logic_vector := x"09";
	constant cfg_PWM_Endlesscnt2	: std_logic_vector := x"0a";
	constant cfg_PWM_Endlesscnt3	: std_logic_vector := x"0b";
	constant cfg_PWM_Endlesscnt4	: std_logic_vector := x"0c";
	constant cfg_PWM_Endlesscnt5	: std_logic_vector := x"0d";
	constant cfg_PWM_Endlesscnt6	: std_logic_vector := x"0e";
	constant cfg_PWM_Endlesscnt7	: std_logic_vector := x"0f";
	constant cfg_VCStatus			: std_logic_vector := x"30";
	constant cfg_Ucc_A				: std_logic_vector := x"31";
	constant cfg_i0					: std_logic_vector := x"32";
	constant cfg_i1					: std_logic_vector := x"33";
	constant cfg_i2					: std_logic_vector := x"34";
	constant cfg_i3					: std_logic_vector := x"35";
	constant cfg_i4					: std_logic_vector := x"36";
	constant cfg_i5					: std_logic_vector := x"37";
	constant cfg_i6					: std_logic_vector := x"38";
	constant cfg_i7					: std_logic_vector := x"39";

	-- write
	constant cfg_PWM0_n			: std_logic_vector := x"00";
	constant cfg_PWM1_n			: std_logic_vector := x"01";
	constant cfg_PWM2_n			: std_logic_vector := x"02";
	constant cfg_PWM3_n			: std_logic_vector := x"03";
	constant cfg_PWM4_n			: std_logic_vector := x"04";
	constant cfg_PWM5_n			: std_logic_vector := x"05";
	constant cfg_PWM6_n			: std_logic_vector := x"06";
	constant cfg_PWM7_n			: std_logic_vector := x"07";
	constant cfg_PWM0_freq_tH	: std_logic_vector := x"10";
	constant cfg_PWM0_freq_tL	: std_logic_vector := x"11";
	constant cfg_PWM1_freq_tH	: std_logic_vector := x"12";
	constant cfg_PWM1_freq_tL	: std_logic_vector := x"13";
	constant cfg_PWM2_freq_tH	: std_logic_vector := x"14";
	constant cfg_PWM2_freq_tL	: std_logic_vector := x"15";
	constant cfg_PWM3_freq_tH	: std_logic_vector := x"16";
	constant cfg_PWM3_freq_tL	: std_logic_vector := x"17";
	constant cfg_PWM4_freq_tH	: std_logic_vector := x"18";
	constant cfg_PWM4_freq_tL	: std_logic_vector := x"19";
	constant cfg_PWM5_freq_tH	: std_logic_vector := x"1a";
	constant cfg_PWM5_freq_tL	: std_logic_vector := x"1b";
	constant cfg_PWM6_freq_tH	: std_logic_vector := x"1c";
	constant cfg_PWM6_freq_tL	: std_logic_vector := x"1d";
	constant cfg_PWM7_freq_tH	: std_logic_vector := x"1e";
	constant cfg_PWM7_freq_tL	: std_logic_vector := x"1f";
	constant cfg_PWM0_pulse_tH	: std_logic_vector := x"20";
	constant cfg_PWM0_pulse_tL	: std_logic_vector := x"21";
	constant cfg_PWM1_pulse_tH	: std_logic_vector := x"22";
	constant cfg_PWM1_pulse_tL	: std_logic_vector := x"23";
	constant cfg_PWM2_pulse_tH	: std_logic_vector := x"24";
	constant cfg_PWM2_pulse_tL	: std_logic_vector := x"25";
	constant cfg_PWM3_pulse_tH	: std_logic_vector := x"26";
	constant cfg_PWM3_pulse_tL	: std_logic_vector := x"27";
	constant cfg_PWM4_pulse_tH	: std_logic_vector := x"28";
	constant cfg_PWM4_pulse_tL	: std_logic_vector := x"29";
	constant cfg_PWM5_pulse_tH	: std_logic_vector := x"2a";
	constant cfg_PWM5_pulse_tL	: std_logic_vector := x"2b";
	constant cfg_PWM6_pulse_tH	: std_logic_vector := x"2c";
	constant cfg_PWM6_pulse_tL	: std_logic_vector := x"2d";
	constant cfg_PWM7_pulse_tH	: std_logic_vector := x"2e";
	constant cfg_PWM7_pulse_tL	: std_logic_vector := x"2f";
	constant cfg_VCFlags		: std_logic_vector := x"30";
	-- config
	constant cfg_IMAX0			: std_logic_vector := x"b0";
	constant cfg_IRED0			: std_logic_vector := x"b1";
	constant cfg_TIMa0			: std_logic_vector := x"b2";
	constant cfg_R_xx0			: std_logic_vector := x"b3";
	constant cfg_kP_x0			: std_logic_vector := x"b4";
	constant cfg_IMAX1			: std_logic_vector := x"b8";
	constant cfg_IRED1			: std_logic_vector := x"b9";
	constant cfg_TIMa1			: std_logic_vector := x"ba";
	constant cfg_R_xx1			: std_logic_vector := x"bb";
	constant cfg_kP_x1			: std_logic_vector := x"bc";
	constant cfg_IMAX2			: std_logic_vector := x"c0";
	constant cfg_IRED2			: std_logic_vector := x"c1";
	constant cfg_TIMa2			: std_logic_vector := x"c2";
	constant cfg_R_xx2			: std_logic_vector := x"c3";
	constant cfg_kP_x2			: std_logic_vector := x"c4";
	constant cfg_IMAX3			: std_logic_vector := x"c8";
	constant cfg_IRED3			: std_logic_vector := x"c9";
	constant cfg_TIMa3			: std_logic_vector := x"ca";
	constant cfg_R_xx3			: std_logic_vector := x"cb";
	constant cfg_kP_x3			: std_logic_vector := x"cc";
	constant cfg_IMAX4			: std_logic_vector := x"d0";
	constant cfg_IRED4			: std_logic_vector := x"d1";
	constant cfg_TIMa4			: std_logic_vector := x"d2";
	constant cfg_R_xx4			: std_logic_vector := x"d3";
	constant cfg_kP_x4			: std_logic_vector := x"d4";
	constant cfg_IMAX5			: std_logic_vector := x"d8";
	constant cfg_IRED5			: std_logic_vector := x"d9";
	constant cfg_TIMa5			: std_logic_vector := x"da";
	constant cfg_R_xx5			: std_logic_vector := x"db";
	constant cfg_kP_x5			: std_logic_vector := x"dc";
	constant cfg_IMAX6			: std_logic_vector := x"e0";
	constant cfg_IRED6			: std_logic_vector := x"e1";
	constant cfg_TIMa6			: std_logic_vector := x"e2";
	constant cfg_R_xx6			: std_logic_vector := x"e3";
	constant cfg_kP_x6			: std_logic_vector := x"e4";
	constant cfg_IMAX7			: std_logic_vector := x"e8";
	constant cfg_IRED7			: std_logic_vector := x"e9";
	constant cfg_TIMa7			: std_logic_vector := x"ea";
	constant cfg_R_xx7			: std_logic_vector := x"eb";
	constant cfg_kP_x7			: std_logic_vector := x"ec";
	constant cfg_GainA			: std_logic_vector := x"ee";
	constant cfg_LogCtrl		: std_logic_vector := x"ef";

	signal cop_rst		  : std_logic :=L;
	signal Card_Rd_Status	: std_logic_vector(11 downto 0);
	signal Card_Wr_Status	: std_logic_vector(15 downto 0);
	signal HWRev			: std_logic_vector( 3 downto 0);
	signal CFG_en			: std_logic;
	----------------------------------------------------------------------------
	-- C64-Slave Rd/Wr
	----------------------------------------------------------------------------
	signal Q25				: std_logic						:= L;
	signal Slv_WrData32	: std_logic_vector(31 downto 0)	:= X"0000_0000";
	alias	Slv_WrData32_B1	: std_logic_vector(15 downto 0) is Slv_WrData32(31 downto 16);
	alias	Slv_WrData		: std_logic_vector(15 downto 0)	is Slv_WrData32(15 downto 0);

--	-- for consistent 64-Bit RdData
--	signal Slv_RdData_64	: std_logic_vector(63 downto 0)	:= (others => L);
--	alias	Slv_RdData_L2	: std_logic_vector(15 downto 0) is Slv_RdData_64(47 downto 32);
--	alias	Slv_RdData_L1	: std_logic_vector(15 downto 0) is Slv_RdData_64(31 downto 16);
--	alias	Slv_RdData_L0	: std_logic_vector(15 downto 0) is Slv_RdData_64(15 downto	0);
--
--	-- for consistent 32-Bit RdData
--	alias	Slv_RdData_32	: std_logic_vector(31 downto 0) is Slv_RdData_64(63 downto 32);
--	alias	Slv_RdData		: std_logic_vector(15 downto 0) is Slv_RdData_64(63 downto 48);
--	signal Last_RdData_L2	: std_logic_vector(15 downto 0)	:= (others => L);
--	signal Last_RdData_L1	: std_logic_vector(15 downto 0)	:= (others => L);
--	signal Last_RdData_L0	: std_logic_vector(15 downto 0)	:= (others => L);

	signal	Slv_RdData		: std_logic_vector(15 downto 0);

	signal Slv_Addr			: std_logic_vector( 7 downto 0)	:= X"00";
	signal Slv_WrEn			: std_logic						:= L;
	signal Slv_RdEn			: std_logic						:= L;


	signal Q100				: std_logic						:= L;
	signal nQ100			: std_logic						:= L;
	signal Q80				: std_logic						:= L;
	signal nQ80				: std_logic						:= L;
	signal Q100_LOCKED		: std_logic						:= L;
	signal Q100_Lcnt		: unsigned( 7 downto 0) := (others => L);
	signal PLL_RST			: std_logic						:= H;
	signal PLL_RST_Cnt		: unsigned( 7 downto 0)	:= (others => L);

	-- sigma delta u and i measurement -----------------------------------------
	constant DF_NUM_SD_DEVICES : integer := 8;
	constant DF_NUM_SD_INST : integer := 2;
	type t_DF_SD is array (0 to DF_NUM_SD_DEVICES/2-1) of integer;

	signal sd_sData : std_logic_vector(DF_NUM_SD_DEVICES-1 downto 0);
	signal sd_overrange : std_logic_vector(DF_NUM_SD_DEVICES-1 downto 0);
	signal sd_analog_data_X : std_logic_vector(DF_NUM_SD_DEVICES*DF_SDREG_LNG-1 downto 0);

	signal sClk_1 : std_logic := L;
	signal sClk_2 : std_logic := L;
	signal sClk_3 : std_logic := L;

	signal sd_sClk_ddr		: std_logic_vector(4 downto 0);
	signal sd_clk_cnt		: unsigned(2 downto 0);
	signal sd_sClk1		: std_logic	:= L;
	signal sd_sClk2		: std_logic	:= L;
	signal sd_dataready	: std_logic	:= L;
	signal clr_sd_en	: std_logic	:= L;
	signal sd_clr		: std_logic	:= H;
	signal sd_we		: std_logic_vector(DF_NUM_SD_INST-1 downto 0);

	constant C_PULSE_PWM : integer := 8;
	signal fPWM : std_logic_vector(C_PULSE_PWM-1 downto 0) := (others => L);
	signal fPWM100 : std_logic_vector(C_PULSE_PWM-1 downto 0) := (others => L);
	signal PWM_Enable 		: std_logic_vector(C_PULSE_PWM-1 downto 0) := (others => H);				--PWM enable
	signal PWM_reg_Pulse_n		: tSLV_Nx16(C_PULSE_PWM-1 downto 0) := (others => (others => L));		--anzahl Pulse reg
	signal PWM_reg_freq_t		: tSLV_Nx32(C_PULSE_PWM-1 downto 0) := (others => (others => L));		--PWM frequenz reg
	signal PWM_reg_Pulse_t		: tSLV_Nx32(C_PULSE_PWM-1 downto 0) := (others => (others => L));

	signal PWM_Pulse_n		: tSLV_Nx16(C_PULSE_PWM-1 downto 0) := (others => (others => L));			--anzahl Pulse
	signal PWM_freq_t		: tSLV_Nx32(C_PULSE_PWM-1 downto 0) := (others => (others => L));			--PWM frequenz
	signal PWM_Pulse_t		: tSLV_Nx32(C_PULSE_PWM-1 downto 0) := (others => (others => L));			--PWM Pulsdauer
	signal PWM_PulseCnt		: tSLV_Nx16(C_PULSE_PWM-1 downto 0) := (others => (others => L));			--PWM Counter output
	signal PWM_EndlessCnt	: tSLV_Nx16(C_PULSE_PWM-1 downto 0) := (others => (others => L));			--PWM Counter output

	signal Prescaler1us	: unsigned(7 downto 0) := (others => L);
	signal c1us			: std_logic := L;

	signal pwm_n : std_logic_vector(C_PULSE_PWM-1 downto 0);
	signal pwm_p : std_logic_vector(C_PULSE_PWM-1 downto 0);
	signal pwm_disable : std_logic_vector(C_PULSE_PWM-1 downto 0);

	----------------------------------------------------------------------------
	--	Config-RAM
	----------------------------------------------------------------------------
	signal CfgRam_Base : std_logic_vector(15 downto 0) := (others => L);

	-- C64-Slave side
	signal CfgRam_WEN_A : std_logic_vector( 1 downto 0) := (others => L);
	signal CfgRam_Addr_A : unsigned(CfgRam_Base'high downto 0) := (others => L);
	signal CfgRam_WrAd_A : unsigned(CfgRam_Base'high downto 0) := (others => L);
	signal CfgRam_RdData_A : std_logic_vector(15 downto 0) := (others => L);
	signal CfgRam_WrData_A : std_logic_vector(15 downto 0) := (others => L);

	signal IcmdMax	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal IcmdRed	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal TIMax	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	type tIact	is array(natural RANGE <>)					of std_logic_vector(DF_SDREG_LNG-1 downto 0);
	signal Iact		: tIact(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal Igain	: std_logic_vector(11 downto 0) := (others => L);
	type	tSLV_Nx11	is array(natural RANGE <>)					of std_logic_vector(10 downto 0); 
	signal R		: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal kP		: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal Ucc		: std_logic_vector(15 downto 0) := (others => L);
	signal Ucc100		: std_logic_vector(15 downto 0) := (others => L);
	signal log_en	: std_logic_vector(C_PULSE_PWM-1 downto 0) := (others => L);
	signal logIact	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal logIerr	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal logIcmd	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal logpwm	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal logton	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal ton	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal logstat	: tSLV_Nx16(C_PULSE_PWM-1 downto 0) := (others => (others => L));

	signal VCFlags	: std_logic_vector(15 downto 0) := (others => L);
	constant DF_E0 : integer := 0;
	constant DF_E1 : integer := 1;
	constant DF_E2 : integer := 2;
	constant DF_E3 : integer := 3;
	constant DF_E4 : integer := 4;
	constant DF_E5 : integer := 5;
	constant DF_E6 : integer := 6;
	constant DF_E7 : integer := 7;
	constant DF_CLR_ERR : integer := 8;
	--constant DF_FILT2 : integer := 9;
	--constant DF_DISEN : integer := 11;
	--constant DF_SDSYNC : integer := 12;
	--constant DF_NO2RED : integer := 13;
	--constant DF_NO2MAX : integer := 14;
	--constant DF_FILT : integer := 15;
	signal VCStatus_n1	: std_logic_vector(15 downto 0) := (others => L);
	signal VCStatus	: std_logic_vector(15 downto 0) := (others => L);
	signal disEN : std_logic;
	signal LogCtrl : std_logic_vector(15 downto 0) := (others => L);
	constant DF_CI0 : integer := 0;
	constant DF_CI1 : integer := 1;
	constant DF_CI2 : integer := 2;
	constant DF_LOG_nSINGLE : integer := 4;

	signal sd_sUcc : std_logic_vector(0 downto 0);

	signal Error01 : std_logic := L;
	signal Error23 : std_logic := L;
	signal Error45 : std_logic := L;
	signal Error67 : std_logic := L;
	signal Ucc_Cmp : std_logic := L;
	signal Error : std_logic := L;
	signal ErrorHold : std_logic := L;
	
	signal new_val : std_logic := L;

begin

--------------------------------------------------------------------------------
--	Test-Points
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	In / Out
--------------------------------------------------------------------------------
	disEN <= H;--VCFlags(DF_DISEN)
	-- bridge enables
	o_pwm_en(0) <= L when (disEN=H and pwm_disable(0)=H and Error01=L) or VCFlags(DF_E0)=H else H;
	o_pwm_en(1) <= L when (disEN=H and pwm_disable(1)=H and Error01=L) or VCFlags(DF_E1)=H else H;
	o_pwm_en(2) <= L when (disEN=H and pwm_disable(2)=H and Error23=L) or VCFlags(DF_E2)=H else H;
	o_pwm_en(3) <= L when (disEN=H and pwm_disable(3)=H and Error23=L) or VCFlags(DF_E3)=H else H;
	o_pwm_en(4) <= L when (disEN=H and pwm_disable(4)=H and Error45=L) or VCFlags(DF_E4)=H else H;
	o_pwm_en(5) <= L when (disEN=H and pwm_disable(5)=H and Error45=L) or VCFlags(DF_E5)=H else H;
	o_pwm_en(6) <= L when (disEN=H and pwm_disable(6)=H and Error67=L) or VCFlags(DF_E6)=H else H;
	o_pwm_en(7) <= L when (disEN=H and pwm_disable(7)=H and Error67=L) or VCFlags(DF_E7)=H else H;

	o_pwm_n <= pwm_n;
	o_pwm_p <= pwm_p;

	o_pwm_M2 <= (others => L);

	-- Clock outputpins
	o_sd_sClk <= sd_sClk_ddr(4 downto 0);

	sd_sData <= not i_sd_sData(7 downto 0);
	sd_sUcc(0) <= i_sd_sData(8);

	Error01 <= VCStatus(0);
	Error23 <= VCStatus(2);
	Error45 <= VCStatus(4);
	Error67 <= VCStatus(6);
	Ucc_Cmp <= VCStatus(8);

	Error <= Error01 or Error23 or Error45 or Error67 or not(Ucc_Cmp) or ErrorHold;



	process(Q25) begin
		if rising_edge(Q25) then
			-- first stage
			VCStatus_n1(0) <= not ni_pwm_Fault(0);
			VCStatus_n1(1) <= not ni_pwm_OTW(0);
			VCStatus_n1(2) <= not ni_pwm_Fault(1);
			VCStatus_n1(3) <= not ni_pwm_OTW(1);
			VCStatus_n1(4) <= not ni_pwm_Fault(2);
			VCStatus_n1(5) <= not ni_pwm_OTW(2);
			VCStatus_n1(6) <= not ni_pwm_Fault(3);
			VCStatus_n1(7) <= not ni_pwm_OTW(3);
			VCStatus_n1(8) <= not ni_Ucc_Cmp;
			-- second stage
			VCStatus <= VCStatus_n1;
			VCStatus(15)<= Error;

			if (unsigned(fPWM)/=0) then -- set/store errors
				ErrorHold <= (Error or ErrorHold) and not(VCFlags(DF_CLR_ERR));
			else --hold errors
				ErrorHold <= (ErrorHold) and not(VCFlags(DF_CLR_ERR));
			end if;
			
			PWM_Enable(0) <= not(Error);
			PWM_Enable(1) <= not(Error);
			PWM_Enable(2) <= not(Error);
			PWM_Enable(3) <= not(Error);
			PWM_Enable(4) <= not(Error);
			PWM_Enable(5) <= not(Error);
			PWM_Enable(6) <= not(Error);
			PWM_Enable(7) <= not(Error);
			
		end if;
	end process;

--------------------------------------------------------------------------------
--
--	Card Status Rd/Wr
--
--------------------------------------------------------------------------------
	-- live-bits and read-back bits
	-- Card_Wr_Status(15): EEprom
	-- Card_Wr_Status(14): slave internal
	-- Card_Wr_Status(13..12): okLed state
	-- Card_Wr_Status will be cleared after i_C64_Reset
	Card_Rd_Status <= Card_Wr_Status(11 downto 8) & std_logic_vector(Q100_Lcnt);

	HWRev <= not ni_HWRev;

	cop_clk : entity clockgenerator
	port map (
		 i_C64_CLK =>  i_C64_CLK,
		ni_C64_CLK => ni_C64_CLK,
		 o_clk => Q25
	);

--------------------------------------------------------------------------------
--	C64-Slave	Read/Write
--------------------------------------------------------------------------------
--	-- for consistent 32-Bit Data
--	process(Q25) begin
--		if rising_edge(Q25) then
--			-- for consistent 64-Bit Data
--			Last_RdData_L2 <= Slv_RdData_L2;
--			-- for consistent 64-Bit Data
--			if (Slv_Addr(1 downto 0) = "00") then
--				Last_RdData_L1 <= Slv_RdData_L1;
--				Last_RdData_L0 <= Slv_RdData_L0;
--			end if;
--		end if;
--	end process;

--------------------------------------------------------------------------------
--	Read
--------------------------------------------------------------------------------
	process(Slv_Addr,Slv_RdEn,PWM_PulseCnt,PWM_EndlessCnt,IcmdMax,IcmdRed,TIMax,R,kP,Igain,Ucc,VCStatus,Iact,CfgRam_Base,CfgRam_RdData_A,LogCtrl,ton
		) begin

--		Slv_RdData_32	<= x"CCCC_CCCC";
		Slv_RdData	<= x"CCCC";

		if (Slv_RdEn = H) then
			--------------------------------------------------------------------
			case Slv_Addr is

			when cfg_PWM_pulsecnt0 => Slv_RdData <= PWM_PulseCnt(0);
			when cfg_PWM_pulsecnt1 => Slv_RdData <= PWM_PulseCnt(1);
			when cfg_PWM_pulsecnt2 => Slv_RdData <= PWM_PulseCnt(2);
			when cfg_PWM_pulsecnt3 => Slv_RdData <= PWM_PulseCnt(3);
			when cfg_PWM_pulsecnt4 => Slv_RdData <= PWM_PulseCnt(4);
			when cfg_PWM_pulsecnt5 => Slv_RdData <= PWM_PulseCnt(5);
			when cfg_PWM_pulsecnt6 => Slv_RdData <= PWM_PulseCnt(6);
			when cfg_PWM_pulsecnt7 => Slv_RdData <= PWM_PulseCnt(7);
			when cfg_PWM_Endlesscnt0 => Slv_RdData <= PWM_EndlessCnt(0);
			when cfg_PWM_Endlesscnt1 => Slv_RdData <= PWM_EndlessCnt(1);
			when cfg_PWM_Endlesscnt2 => Slv_RdData <= PWM_EndlessCnt(2);
			when cfg_PWM_Endlesscnt3 => Slv_RdData <= PWM_EndlessCnt(3);
			when cfg_PWM_Endlesscnt4 => Slv_RdData <= PWM_EndlessCnt(4);
			when cfg_PWM_Endlesscnt5 => Slv_RdData <= PWM_EndlessCnt(5);
			when cfg_PWM_Endlesscnt6 => Slv_RdData <= PWM_EndlessCnt(6);
			when cfg_PWM_Endlesscnt7 => Slv_RdData <= PWM_EndlessCnt(7);
			when cfg_VCStatus	=> Slv_RdData <= VCStatus;
			when cfg_Ucc_A => Slv_RdData <= Ucc;
			when cfg_i0	=> Slv_RdData <= "0000" & ton(0);
			when cfg_i1	=> Slv_RdData <= "0000" & ton(1);
			when cfg_i2	=> Slv_RdData <= "0000" & ton(2);
			when cfg_i3	=> Slv_RdData <= "0000" & ton(3);
			when cfg_i4	=> Slv_RdData <= "0000" & ton(4);
			when cfg_i5	=> Slv_RdData <= "0000" & ton(5);
			when cfg_i6	=> Slv_RdData <= "0000" & ton(6);
			when cfg_i7	=> Slv_RdData <= "0000" & ton(7);
			-- read cfg
			when cfg_IMAX0 => Slv_RdData <= IcmdMax(0) & "0000";
			when cfg_IRED0 => Slv_RdData <= IcmdRed(0) & "0000";
			when cfg_TIMa0 => Slv_RdData <= "0000" & TIMax  (0);
			when cfg_R_xx0 => Slv_RdData <= R	   (0) & "0000";
			when cfg_kP_x0 => Slv_RdData <= kP	   (0) & "0000";
			when cfg_IMAX1 => Slv_RdData <= IcmdMax(1) & "0000";
			when cfg_IRED1 => Slv_RdData <= IcmdRed(1) & "0000";
			when cfg_TIMa1 => Slv_RdData <= "0000" & TIMax  (1);
			when cfg_R_xx1 => Slv_RdData <= R	   (1) & "0000";
			when cfg_kP_x1 => Slv_RdData <= kP	   (1) & "0000";
			when cfg_IMAX2 => Slv_RdData <= IcmdMax(2) & "0000";
			when cfg_IRED2 => Slv_RdData <= IcmdRed(2) & "0000";
			when cfg_TIMa2 => Slv_RdData <= "0000" & TIMax  (2);
			when cfg_R_xx2 => Slv_RdData <= R	   (2) & "0000";
			when cfg_kP_x2 => Slv_RdData <= kP	   (2) & "0000";
			when cfg_IMAX3 => Slv_RdData <= IcmdMax(3) & "0000";
			when cfg_IRED3 => Slv_RdData <= IcmdRed(3) & "0000";
			when cfg_TIMa3 => Slv_RdData <= "0000" & TIMax  (3);
			when cfg_R_xx3 => Slv_RdData <= R	   (3) & "0000";
			when cfg_kP_x3 => Slv_RdData <= kP	   (3) & "0000";
			when cfg_IMAX4 => Slv_RdData <= IcmdMax(4) & "0000";
			when cfg_IRED4 => Slv_RdData <= IcmdRed(4) & "0000";
			when cfg_TIMa4 => Slv_RdData <= "0000" & TIMax  (4);
			when cfg_R_xx4 => Slv_RdData <= R	   (4) & "0000";
			when cfg_kP_x4 => Slv_RdData <= kP	   (4) & "0000";
			when cfg_IMAX5 => Slv_RdData <= IcmdMax(5) & "0000";
			when cfg_IRED5 => Slv_RdData <= IcmdRed(5) & "0000";
			when cfg_TIMa5 => Slv_RdData <= "0000" & TIMax  (5);
			when cfg_R_xx5 => Slv_RdData <= R	   (5) & "0000";
			when cfg_kP_x5 => Slv_RdData <= kP	   (5) & "0000";
			when cfg_IMAX6 => Slv_RdData <= IcmdMax(6) & "0000";
			when cfg_IRED6 => Slv_RdData <= IcmdRed(6) & "0000";
			when cfg_TIMa6 => Slv_RdData <= "0000" & TIMax  (6);
			when cfg_R_xx6 => Slv_RdData <= R	   (6) & "0000";
			when cfg_kP_x6 => Slv_RdData <= kP	   (6) & "0000";
			when cfg_IMAX7 => Slv_RdData <= IcmdMax(7) & "0000";
			when cfg_IRED7 => Slv_RdData <= IcmdRed(7) & "0000";
			when cfg_TIMa7 => Slv_RdData <= "0000" & TIMax  (7);
			when cfg_R_xx7 => Slv_RdData <= R	   (7) & "0000";
			when cfg_kP_x7 => Slv_RdData <= kP	   (7) & "0000";
			when cfg_GainA => Slv_RdData <= Igain & "0000";
			when cfg_LogCtrl => Slv_RdData <= LogCtrl;
			----------------------------------------------------------------
			-- Read ConfigRam
			----------------------------------------------------------------
			when x"F8"	=> Slv_RdData <= CfgRam_Base;
			when x"F9"	=> Slv_RdData <= CfgRam_RdData_A;

			--------------------------------------------------------------------
			when others => null;
			end case;
			--------------------------------------------------------------------
		end if;
	end process;

--------------------------------------------------------------------------------
--	Write
--------------------------------------------------------------------------------
	process(Q25) begin
		if rising_edge(Q25) then
			cop_rst <= i_C64_Reset;
			new_val <= L;
			
			if (cop_rst = H) then
				PWM_Pulse_t	<= (others => (others => L));
				PWM_Pulse_n	<= (others => (others => L));
				PWM_freq_t	<= (others => (others => L));
			elsif (new_val=H) then
				PWM_freq_t <= PWM_reg_freq_t;
				PWM_Pulse_n <= PWM_reg_Pulse_n;
				PWM_Pulse_t <= PWM_reg_Pulse_t;
			end if;
			

			-- global Reset
			if (cop_rst = H) then
				PWM_reg_Pulse_t	<= (others => (others => L));
				PWM_reg_Pulse_n	<= (others => (others => L));
				PWM_reg_freq_t	<= (others => (others => L));
			elsif (Slv_WrEn = H) then
				if (Slv_Addr(0) = L) then
					-- for consistent 32-Bit data
					Slv_WrData32_B1 <= Slv_WrData;
				end if;
				----------------------------------------------------------------
				case Slv_Addr is
				--PWM
				--first write the value to the register
				when cfg_PWM0_n => PWM_reg_Pulse_n(0) <= Slv_WrData;
				when cfg_PWM1_n => PWM_reg_Pulse_n(1) <= Slv_WrData;
				when cfg_PWM2_n => PWM_reg_Pulse_n(2) <= Slv_WrData;
				when cfg_PWM3_n => PWM_reg_Pulse_n(3) <= Slv_WrData;
				when cfg_PWM4_n => PWM_reg_Pulse_n(4) <= Slv_WrData;
				when cfg_PWM5_n => PWM_reg_Pulse_n(5) <= Slv_WrData;
				when cfg_PWM6_n => PWM_reg_Pulse_n(6) <= Slv_WrData;
				when cfg_PWM7_n => PWM_reg_Pulse_n(7) <= Slv_WrData;

				when cfg_PWM0_freq_tL => PWM_reg_freq_t(0) <= Slv_WrData32;
				when cfg_PWM1_freq_tL => PWM_reg_freq_t(1) <= Slv_WrData32;
				when cfg_PWM2_freq_tL => PWM_reg_freq_t(2) <= Slv_WrData32;
				when cfg_PWM3_freq_tL => PWM_reg_freq_t(3) <= Slv_WrData32;
				when cfg_PWM4_freq_tL => PWM_reg_freq_t(4) <= Slv_WrData32;
				when cfg_PWM5_freq_tL => PWM_reg_freq_t(5) <= Slv_WrData32;
				when cfg_PWM6_freq_tL => PWM_reg_freq_t(6) <= Slv_WrData32;
				when cfg_PWM7_freq_tL => PWM_reg_freq_t(7) <= Slv_WrData32;

				--write data to the pwms
				when cfg_PWM0_pulse_tL => PWM_reg_Pulse_t(0) <= Slv_WrData32;
				when cfg_PWM1_pulse_tL => PWM_reg_Pulse_t(1) <= Slv_WrData32;
				when cfg_PWM2_pulse_tL => PWM_reg_Pulse_t(2) <= Slv_WrData32;
				when cfg_PWM3_pulse_tL => PWM_reg_Pulse_t(3) <= Slv_WrData32;
				when cfg_PWM4_pulse_tL => PWM_reg_Pulse_t(4) <= Slv_WrData32;
				when cfg_PWM5_pulse_tL => PWM_reg_Pulse_t(5) <= Slv_WrData32;
				when cfg_PWM6_pulse_tL => PWM_reg_Pulse_t(6) <= Slv_WrData32;
				when cfg_PWM7_pulse_tL => PWM_reg_Pulse_t(7) <= Slv_WrData32; new_val <= H;

				when cfg_VCFlags => VCFlags <= Slv_WrData;
				--when cfg_Ucc_A => wUcc <= Slv_WrData;
				----------------------------------------------------------------
				when others => null;
				end case;
				----------------------------------------------------------------
				--Config Data
				if (CFG_en=H) then
					case Slv_Addr is

					when cfg_IMAX0 => IcmdMax(0) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED0 => IcmdRed(0) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa0 => TIMax	 (0) <= Slv_WrData(11 downto 0);
					when cfg_R_xx0 => R		 (0) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x0 => kP	 (0) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX1 => IcmdMax(1) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED1 => IcmdRed(1) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa1 => TIMax	 (1) <= Slv_WrData(11 downto 0);
					when cfg_R_xx1 => R		 (1) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x1 => kP	 (1) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX2 => IcmdMax(2) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED2 => IcmdRed(2) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa2 => TIMax	 (2) <= Slv_WrData(11 downto 0);
					when cfg_R_xx2 => R		 (2) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x2 => kP	 (2) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX3 => IcmdMax(3) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED3 => IcmdRed(3) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa3 => TIMax	 (3) <= Slv_WrData(11 downto 0);
					when cfg_R_xx3 => R		 (3) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x3 => kP	 (3) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX4 => IcmdMax(4) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED4 => IcmdRed(4) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa4 => TIMax	 (4) <= Slv_WrData(11 downto 0);
					when cfg_R_xx4 => R		 (4) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x4 => kP	 (4) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX5 => IcmdMax(5) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED5 => IcmdRed(5) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa5 => TIMax	 (5) <= Slv_WrData(11 downto 0);
					when cfg_R_xx5 => R		 (5) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x5 => kP	 (5) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX6 => IcmdMax(6) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED6 => IcmdRed(6) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa6 => TIMax	 (6) <= Slv_WrData(11 downto 0);
					when cfg_R_xx6 => R		 (6) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x6 => kP	 (6) <= L & Slv_WrData(14 downto 4);
					when cfg_IMAX7 => IcmdMax(7) <= L & Slv_WrData(14 downto 4);
					when cfg_IRED7 => IcmdRed(7) <= "000" & Slv_WrData(12 downto 4);
					when cfg_TIMa7 => TIMax	 (7) <= Slv_WrData(11 downto 0);
					when cfg_R_xx7 => R		 (7) <= L & Slv_WrData(14 downto 4);
					when cfg_kP_x7 => kP	 (7) <= L & Slv_WrData(14 downto 4);
					when cfg_GainA => Igain		 <= Slv_WrData(15 downto 4);
					when cfg_LogCtrl => LogCtrl <= Slv_WrData;

					when others => null;
					end case;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
-- synchron part of Config-BRAM Read/Write
--------------------------------------------------------------------------------
	process(Q25) begin
		if rising_edge(Q25) then
			if (cop_rst = H) then
				CfgRam_WrAd_A <= (others => L);
				CfgRam_WrData_A <= (others => L);
				CfgRam_WEN_A <= (others => H);
			else
				CfgRam_WrAd_A <= unsigned(CfgRam_Base);
				CfgRam_WrData_A <= (others => L);
				CfgRam_WEN_A <= (others => L);

				--------------------------------------------------------------------
				-- synchron part of CFG_BRAM read
				--------------------------------------------------------------------
				if (Slv_RdEn = H) then
					if (Slv_Addr = x"F9") then
						CfgRam_WrAd_A <= CfgRam_WrAd_A + 1;
					end if;
				end if;

				--------------------------------------------------------------------
				-- CFG_BRAM write
				--------------------------------------------------------------------
				if (Slv_WrEn = H) then
					----------------------------------------------------------------
					case Slv_Addr is
					----------------------------------------------------------------
					-- Write ConfigRam
					----------------------------------------------------------------
					when x"F8" =>
						-- save Start-16Bit-Addr
						CfgRam_Base <= Slv_WrData(CfgRam_Base'high downto 0);
						CfgRam_WrAd_A <= unsigned(Slv_WrData(CfgRam_Base'high downto 0));
					when x"F9" =>
						CfgRam_WEN_A <= "11";
						CfgRam_WrData_A <= Slv_WrData;

						if (CfgRam_WEN_A = "00") then
							CfgRam_WrAd_A <= unsigned(CfgRam_Base);
						else
							CfgRam_WrAd_A <= CfgRam_WrAd_A + 1;
						end if;
					----------------------------------------------------------------
					when others => null;
					end case;
					----------------------------------------------------------------
				end if;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
-- asynchron part of CfgAddr
--------------------------------------------------------------------------------
	process(Slv_RdEn,CfgRam_WrAd_A) begin
		-- zeige schon mal auf den ersten
		CfgRam_ADDR_A <= CfgRam_WrAd_A;

		if (Slv_RdEn = H) then
			-- zeige immer um eins voraus
			CfgRam_ADDR_A <= CfgRam_WrAd_A + 1;
		end if;
	end process;
--------------------------------------------------------------------------------
--	C64 BusSlave instance
--------------------------------------------------------------------------------
	inst_C64_Slaver: entity C64_Slave.C64_SlaveSeq
	generic map (
		g_App_Rev => g_App_Rev,
		-- support Config-BRAM on Port F8=Addr, F9=Data
		g_CfgRAM_F8_F9 => 1
	)
		PORT MAP (
		-- address switch
		 i_AddrSw		=> i_AddrSw,
		 i_HWRev		=> HWRev			,

		-- C64 Bus
		 i_C64_Reset	=> cop_rst			,
		 i_clk25		=> Q25				,
		 i_C64_SEL		=> i_C64_SEL		,
		 i_C64_Bend		=> i_C64_Bend		,
		 b_C64_DatBus	=> b_C64_DatBus		,
		no_C64_Ack		=> no_C64_Ack		,

		-- JTAG pins
		 o_JTAG_TCK		=> o_JTAG_TCK		,
		 o_JTAG_TMS		=> o_JTAG_TMS		,
		 o_JTAG_TDI		=> o_JTAG_TDI		,
		 i_JTAG_TDO		=> i_JTAG_TDO		,

		-- SPI Pins
		 o_SPI_CLK		=>	o_SPI_CLK		,
		no_SPI_CS		=> no_SPI_CS		,
		 o_SPI_D		=>	o_SPI_D			,
		 i_SPI_Q		=>	i_SPI_Q			,

		-- local application Rd/Wr
		 o_Addr			=> Slv_Addr			,
		 i_RdData		=> Slv_RdData		,
		 o_WrData		=> Slv_WrData		,
		 o_WrEn			=> Slv_WrEn			,
		 o_RdEn			=> Slv_RdEn			,
		-- status
		 i_Card_Status	=> Card_Rd_Status	,
		 o_Card_Status	=> Card_Wr_Status	,
		-- GinFrams_Flags
		 o_GF_Flags		=> open				,
		no_EEP_Wen		=> no_EEP_Wen		,
		no_OkLED		=> no_OkLED			,

		 o_CFG_en		=> CFG_en
	);

--------------------------------------------------------------------------------
--	PLL instance
--------------------------------------------------------------------------------
--	PLL PowerON-Reset
	process(Q25) begin
		if rising_edge(Q25) then
			if (PLL_RST_Cnt < 100) then
				PLL_RST_Cnt <= PLL_RST_Cnt + 1;
			else
				PLL_RST <= L;
			end if;
		end if;
	end process;

inst_PLL: entity C64_Slave.PLL_i25_o100
	port map (
		 i_Reset		=> PLL_RST			,
		 i_Q25			=> Q25				,
		 o_Q100			=> Q100				,
		 o_Q25			=> open				,
		 o_Q80			=> Q80				,
		 o_LOCKED		=> Q100_LOCKED
	);

	process (Q100_LOCKED)
	begin
		if falling_edge(Q100_LOCKED) then
			Q100_Lcnt <= Q100_Lcnt + 1;
		end if;
	end process;

	--1 MHz clock for PWM's and 1us
	process(Q25)
	constant DF_US : natural := 25;
	begin
		if rising_edge(Q25) then
			clr_sd_en <= L;
			if (Prescaler1us = DF_US-1) then
				c1us <= H;
				Prescaler1us <= (others => L);
			elsif (Prescaler1us = DF_US-8) then
				clr_sd_en <= H;
				Prescaler1us <= Prescaler1us + 1;
			else
				c1us <= L;
				Prescaler1us <= Prescaler1us + 1;
			end if;
		end if;
	end process;

	process(Q100) begin
		if rising_edge(Q100) then
			fPWM100 <= fPWM;
		end if;
	end process;

	pulse_pwm: if (C_PULSE_PWM/=0) generate
	constant C_FLAG_EXT_1MHZPRESCALE	: integer := 1;
	constant C_TIME_BITS_PULS			: integer := 20;
	signal c1us100 : std_logic := L;
	signal c1us_1 : std_logic := L;
	type	tF1	is array(natural RANGE <>)					of std_logic_vector(DF_SDREG_LNG+4 downto 0);
	signal IF1 : tF1(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal IactF100 : tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));

	function filter(val,filreg : signed) return signed is
	variable dif : signed(filreg'length-1 downto 0);
	variable SHIFT : natural := filreg'length-val'length;
	variable filler : signed(SHIFT-1 downto 0) := (others => L);
	begin
		dif := (val&filler)-filreg;
		return filreg + shift_right(dif, SHIFT);
	end function filter;

	signal off  : std_logic_vector(11 downto 0) := x"00a";
	signal IcmdMax100	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal IcmdRed100	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal TIMax100	: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal Igain100	: std_logic_vector(11 downto 0) := (others => L);
	signal R100		: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal kP100		: tSLV_Nx12(C_PULSE_PWM-1 downto 0) := (others => (others => L));
	signal VCFlags100  : std_logic_vector(15 downto 0) := (others => L);

	begin
		process(Q100) begin
			if rising_edge(Q100) then
				IcmdMax100  <= IcmdMax;
				IcmdRed100 <= IcmdRed;
				TIMax100 <= TIMax;
				R100 <= R;
				kP100 <= kP;
				Igain100 <= Igain;
				VCFlags100 <= VCFlags;
			end if;
		end process;

		pwm_inst : for i in 0 to C_PULSE_PWM-1 generate
		begin
			inst_Pulsator : entity PWM.Pulsator
			generic map(
				C_EXT_1MHZPRESCAL => C_FLAG_EXT_1MHZPRESCALE,
				C_TIME_BITS => C_TIME_BITS_PULS
			)
			port map(
				i_CLK  => Q25,
				i_PS1MHz => c1us,
				i_enable  => PWM_Enable(i),
				i_Freq_t  => PWM_freq_t(i)(19 downto 0),
				i_Pulse_t  => PWM_Pulse_t(i)(19 downto 0),
				i_Pulse_n  => PWM_Pulse_n(i),
				o_Pulse	 => fPWM(i),
				o_EndlessCnt => PWM_EndlessCnt(i),
				o_PulseCnt	=> PWM_PulseCnt(i)
			);

			process(Q100) begin
				if rising_edge(Q100) then
					if (sd_we(1)=H) then
						IF1(i) <= std_logic_vector(filter(signed(Iact(i)), signed(IF1(i))));
					end if;

					--if VCFlags100(DF_FILT)=H then
						IactF100(i) <= IF1(i)(DF_SDREG_LNG+4 downto 3);
					--else
					--	IactF100(i) <= Iact(i)&"00";
					--end if;
					c1us_1 <= c1us;
					if (c1us=L and c1us_1=H) then
						c1us100 <= H;
					else
						c1us100 <= L;
					end if;
				end if;
			end process;

			Iact(i) <= sd_analog_data_X(DF_SDREG_LNG-1+DF_SDREG_LNG*i downto DF_SDREG_LNG*i);

			inst_Ctrl: entity work.valve_ctrl
			generic map (
				C_REG_LENGTH		=> 12,
				C_ENpPWM			=> 10,
				C_TICKSpEN			=> 100,--
				C_DT 				=> 20,-- in Ticks
				C_FIXUCC			=> 24,-- 0 calculate from i_Ucc: >0 use this value
				C_PWMHALF			=> 1,
				C_DOT 				=> 4, -- U, R, kP, Gain
				C_DOT_U				=> 6, -- max 32V
				C_DOT_I				=> 8 -- Ired, Imax, Iact
			)
			port map (
				i_Clk => Q100,
				i_reset => sd_clr,
				i_loop_en	=> c1us100	,
				i_pulse_en	=> fPWM100(i)	,
				i_Flags(0)	=> H,--VCFlags100(DF_NO2RED)	,
				i_Flags(1)	=> L,--VCFlags100(DF_NO2MAX)	,
				i_IcmdMax	=> IcmdMax100(i),
				i_IcmdRed	=> IcmdRed100(i),
				i_TIMax		=> TIMax100(i),
				-- ctrl	
				i_Iact		=> IactF100(i),
				i_Igain		=> Igain100,
				i_R			=> R100(i),
				i_kP		=> kP100(i),
				i_off		=> off,
				--i_Ucc		=> wUcc		,
				o_p			=> pwm_p(i)	,
				o_n			=> pwm_n(i)	,
				o_disable	=> pwm_disable(i),
				o_log_en	=> log_en(i)	,
				o_Iact		=> logIact(i),
				o_Ierr		=> logIerr(i),
				o_Icmd		=> logIcmd(i),
				o_pwm		=> logpwm (i),
				o_Status	=> logstat(i),
				o_Ton		=> logton(i)
			);

		end generate pwm_inst;
	end generate pulse_pwm;

	-- sigma delta measurement ------------------------------------------------
	process (Q100) begin
		if rising_edge(Q100) then
			sClk_1 <= sd_sClk1;
			sClk_2 <= sClk_1;
			sClk_3 <= sClk_2;

			if (cop_rst = H or Q100_LOCKED=L) then
				sd_clr <= H;
			elsif (clr_sd_en=H) then
				sd_clr <= L;
			end if;
		end if;
	end process;

	sd_dataready <= H when sClk_3=L and sClk_2=H else L;

	-- sClk < 20MHz, sd_clk_cnt shuld count at least to DF_NUM_SD_DEVICES/2
	-- 4 devices, busclock 99 or 110MHz and sd_clk_cnt>20MHz
	-- 99MHz/6 => 16.5MHz / 110MHz/6 => 18.3MHz / 100Mhz/6 => 16.6666MHz / 100Mhz/5 => 20MHz (need ddr ff)
	-- 80MHz/5 => 16MHz
	sd_clk_gen : process (Q80)
	begin
		if rising_edge(Q80) then
			sd_clk_cnt <= sd_clk_cnt + 1;
			-- /5 with ddr ff
			if (sd_clk_cnt=0) then
				sd_sClk1 <= H;
				sd_sClk2 <= H;
			elsif (sd_clk_cnt=2) then
				sd_sClk1 <= L;
				sd_sClk2 <= H;
			elsif (sd_clk_cnt=3) then
				sd_sClk1 <= L;
				sd_sClk2 <= L;
			elsif (sd_clk_cnt=4) then
				sd_clk_cnt <= (others => L);
			end if;
		end if;
	end process sd_clk_gen;

	nQ80 <= not Q80;

	ddrff:for i in 0 to 4 generate
		begin
			sd5050_clk : ODDR2
			generic map(
				--DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE"
				DDR_ALIGNMENT => "NONE",
				INIT => '0',		-- Initial value for Q port ('1' or '0')
				SRTYPE => "SYNC")	-- Reset Type ("ASYNC" or "SYNC")
			port map (
				Q  => sd_sClk_ddr(i),		-- DDR output
				C0 => Q80,			-- clock input
				C1 => nQ80,		-- clock input
				CE => H,			-- clock enable input
				D0 => sd_sClk1,		-- data input (positive edge)
				D1 => sd_sClk2,		-- data input (negative edge)
				R  => L,			-- reset input
				S  => L				-- set input
			);
	end generate ddrff;

	sd_inst8_0: for i in 0 to DF_NUM_SD_INST-1 generate
	begin
		i_sd_inst08_c : entity sigma_delta.sigma_delta_synchron
		generic map (
			C_OVERRANGE => 25,
			C_CLK_DIV => 8,
			C_REG_LNG => DF_SDREG_LNG,
			C_NUM_SD_DEVICES => DF_NUM_SD_DEVICES/DF_NUM_SD_INST
		)
		port map (
			i_Clk => Q100,
			i_dataready => sd_dataready,
			--sigma_delta Pins
			i_sData => sd_sData(i*DF_NUM_SD_DEVICES/DF_NUM_SD_INST+DF_NUM_SD_DEVICES/DF_NUM_SD_INST-1 downto i*DF_NUM_SD_DEVICES/DF_NUM_SD_INST),
			-- interface
			o_DataLA => sd_analog_data_X(i*DF_NUM_SD_DEVICES/DF_NUM_SD_INST*DF_SDREG_LNG+DF_NUM_SD_DEVICES/DF_NUM_SD_INST*DF_SDREG_LNG-1 downto i*DF_NUM_SD_DEVICES/DF_NUM_SD_INST*DF_SDREG_LNG),
			o_WE => sd_we(i),
			i_clear => sd_clr
		);
	end generate sd_inst8_0;

	i_sd_inst64 : entity sigma_delta.sigma_delta_synchron
	generic map (
		C_OVERRANGE => 25,
		C_CLK_DIV => 64,
		C_REG_LNG => 16,
		C_NUM_SD_DEVICES => 1
	)
	port map (
		i_Clk => Q100,
		i_dataready => sd_dataready,
		--sigma_delta Pins
		i_sData => sd_sUcc,
		-- interface
		o_DataLA => Ucc100
	);

	process (Q25) begin
		if rising_edge(Q25) then
			Ucc <= Ucc100;
			ton <= logton;
		end if;
	end process;

logger : if 1=1 generate
			constant C_LOGRAM_NO_OF_KBYTE : integer := 32;
			signal clg_BRAM_WEN : std_logic_vector(1 downto 0);
			signal clg_BRAM_Addr : unsigned(15 downto 0) := (others => H);
			signal clg_BRAM_s2r : std_logic_vector(15 downto 0);
			signal clg_BRAM_r2s : std_logic_vector(15 downto 0);
			constant DF_LOG_CHANNELS : integer := 4;
			signal ch : integer range 0 to DF_LOG_CHANNELS := DF_LOG_CHANNELS;
			signal trig : std_logic:=L;
			signal log_run : std_logic :=L;
			signal i : integer range 0 to 7 := 0;
			signal cnti : unsigned(7 downto 0) := (others => L);
			signal LogCtrl100 : std_logic_vector(15 downto 0) := (others => L);

			constant BRAM_Init		: tSLV_Nx16(0 to 512*C_LOGRAM_NO_OF_KBYTE-1) := (	-- GinSlave and COP_Master
				0 => x"0001",
				1 => x"0203",
				2 => x"0405",
				3 => x"0607",
				4 => x"0809",
				5 => x"0a0b",
				6 => x"0c0d",
				7 => x"0e0f",
				--4094 => x"AAAA",
				--4095 => x"5555",
				others	=> (others => L)
				);
		begin
			inst_Ram_t0 : entity BRAM.BRAM_NkByte_A16_B16
			generic map (
				C_NO_OF_KBYTE => C_LOGRAM_NO_OF_KBYTE,
				BRAM_Init => BRAM_Init
			)
			port map (
				-- A-side read/write
				i_BRAM_Clk_A	=> Q100,
				i_BRAM_WEN_A	=> clg_BRAM_WEN,
				i_BRAM_Addr_A	=> std_logic_vector(clg_BRAM_Addr(pkg_log2(512*C_LOGRAM_NO_OF_KBYTE)-1 downto 0)),
				o_BRAM_Din_A	=> clg_BRAM_r2s,
				i_BRAM_Dout_A	=> clg_BRAM_s2r,
				i_BRAM_Clk_B => Q25,
				i_BRAM_WEN_B => CfgRam_WEN_A,
				i_BRAM_Addr_B => std_logic_vector(CfgRam_Addr_A(pkg_log2(512*C_LOGRAM_NO_OF_KBYTE)-1 downto 0)),
				i_BRAM_Dout_B => CfgRam_WrData_A,
				o_BRAM_Din_B =>	 CfgRam_RdData_A
			);

			clg_crtl : process (Q100)
			--constant i : integer range 0 to 7 := 2;
			variable  logch	: tSLV_Nx16(DF_LOG_CHANNELS-1 downto 0) := (others => (others => L));
			begin
				if rising_edge(Q100) then
					if (sd_we(1)=H) then
						cnti <= cnti+1;
					end if;
					LogCtrl100 <= LogCtrl;
					i <= to_integer(unsigned(LogCtrl100(2 downto 0)));
					logch(0) := "0000" & logpwm(i);
					logch(1) := logIact(i) & "0000";
					logch(2) := logIerr(i) & "0000";
					logch(3) := logIcmd(i)(11 downto 4) & logstat(i)(7 downto 0);
					trig <= fPWM100(i);
					clg_BRAM_WEN  <= (others => L);
					if trig=L and fPWM100(i)=H and log_run=L then
						log_run <= H;
						clg_BRAM_Addr <= to_unsigned(DF_LOG_CHANNELS-1,clg_BRAM_Addr'length);
						ch <= DF_LOG_CHANNELS;
					end if;
					if log_run=H then
						if (clg_BRAM_Addr<((512*C_LOGRAM_NO_OF_KBYTE)-1)) then
							if (log_en(i)=H) then
								ch <= 0;
							end if;
							if ch<DF_LOG_CHANNELS then
								ch <= ch+1;
								clg_BRAM_Addr <= clg_BRAM_Addr+1;
								clg_BRAM_WEN  <= (others => H);
								clg_BRAM_s2r <= logch(ch);
							end if;
						else
							log_run <= LogCtrl100(DF_LOG_nSINGLE);
						end if;
					else
						if (log_en(i)=H) then
							clg_BRAM_Addr <= (others => H);
							ch <= 0;
						end if;
						if ch>=0 and ch<DF_LOG_CHANNELS then
							ch <= ch+1;
							clg_BRAM_Addr <= clg_BRAM_Addr+1;
							clg_BRAM_WEN  <= (others => H);
							clg_BRAM_s2r <= logch(ch);
						end if;
					end if;
				end if;
			end process clg_crtl;
		end generate logger;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
