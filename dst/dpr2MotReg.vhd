--------------------------------------------------------------------------------
--
--	dpr2MotReg
--
--------------------------------------------------------------------------------
--
--	project     : dpr to register sequenzer
--	programmer  : C.Leuthold, INDEL AG
--	date        : 11.06.2009
--	language    : VHDL
--	system      : PPC-CARD4
--
--	purpose
--		copy registers from and to blockram
--		for all 3ph motor controllers (gin generation sac3, sac3x3, max4)
--
-- SAC3			SAC3x3		MAX4
-- C_PWM = 1	C_PWM = 3	C_PWM = 4
-- C_SI = 1		C_SI = 3	C_SI = 1
-- C_ADC = 2	C_ADC = 6	C_ADC = 2
-- C_CM = 4		C_CM = 12	C_CM = 16
-- C_ENC = 2	C_ENC = 3	C_ENC = 4
-- C_DAC = 0	C_DAC = 0	C_DAC = 1
-- C_SPWM = 0	C_SPWM = 0	C_SPWM = 1
-- FF 553		FF 856		FF 1045
-- LUT 450		LUT 786		LUT 833
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--
--	11.06.2009-le : - change dpr2SAC3x3Reg to dpr2MotReg
--	06.08.2009-le : - dpr2mot: correct current measurement addr of CM1
--	22.07.2010-le : - support for gin-ax-42, add pwm register x and a special pwm 100 
--	27.09.2010-le : - correct data_index length
--	02.02.2012-le : - support up to 6 encoders
--	18.12.2012-le : - add 8puls registers
--------------------------------------------------------------------------------
--$Rev:: 2834                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-07-09 09:20:01 +0200 (Di., 09 Jul 2013)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library	ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;

entity dpr2MotReg is
	generic (
		C_PWM : integer range 1 to 4  := 1;
		C_SI  : integer range 1 to 4  := 1;
		C_ADC : integer range 1 to 6  := 2;
		C_CM  : integer range 1 to 16 := 4;
		C_ENC : integer range 1 to 8  := 2;
		C_DAC : integer range 0 to 1  := 0;
		C_SPWM : integer range 0 to 1  := 0;
		C_USE_ENC_TRIGGER : integer range 0 to 1  := 0;
		C_8PULS : integer range 0 to 1  := 0
	);
	port (
		--System
		i_Reset		: IN	std_logic;
		i_Clk		: IN	std_logic;
		-- Dualport	Ram	access
		o_dprEN		: OUT	std_logic;
		o_dprClk	: OUT	std_logic;
		o_dprRst	: OUT	std_logic;
		o_dprWEN	: OUT	std_logic_vector(3 downto 0);
		o_dprData	: out	STD_LOGIC_VECTOR(63 downto 0);
		i_dprData	: in	STD_LOGIC_VECTOR(63 downto 0);
		o_dprAddr	: OUT	std_logic_vector(9 downto 0);
		-- inputs
		-- adcs  0x3000
		i_ADCA0		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCA1		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCA2		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCA3		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCA4		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCA5		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB0		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB1		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB2		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB3		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB4		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB5		: in	std_logic_vector(15 downto 0) := (others => '0');
		-- current measurement 0x3100
		i_sdADC0	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC1	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC2	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC3	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC4	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC5	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC6	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC7	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC8	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC9	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC10	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC11	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC12	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC13	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC14	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_sdADC15	: in	std_logic_vector(15 downto 0) := (others => '0');
		-- encoders 0x3200
		i_Enc0		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc1		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc2		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc3		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc4		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc5		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc6		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc7		: in	std_logic_vector(15 downto 0) := (others => '0');
		-- misc/inputs 0x3300
		i_d_in		: in	std_logic_vector(31 downto 0) := (others => '0');
		i_16		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ExtStatus	: in	std_logic_vector(31 downto 0) := (others => '0');
		i_Status	: in	std_logic_vector(31 downto 0) := (others => '0');
		-- abs encoder /pulscnt 0x3500
		i_SI0		: in	std_logic_vector(63 downto 0) := (others => '0');
		i_SI1		: in	std_logic_vector(63 downto 0) := (others => '0');
		i_SI2		: in	std_logic_vector(63 downto 0) := (others => '0');
		i_SI3		: in	std_logic_vector(63 downto 0) := (others => '0');
		--
		i_PWMCnt	: in	std_logic_vector(15 downto 0) := (others => '0');
		-- outputs
		-- 0x2000
		o_PWM_U0	: out	std_logic_vector(15 downto 0);
		o_PWM_V0	: out	std_logic_vector(15 downto 0);
		o_PWM_W0	: out	std_logic_vector(15 downto 0);
		o_PWM_X0	: out	std_logic_vector(15 downto 0);
		o_PWM_100	: out	std_logic_vector(15 downto 0);
		o_PWM_U1	: out	std_logic_vector(15 downto 0);
		o_PWM_V1	: out	std_logic_vector(15 downto 0);
		o_PWM_W1	: out	std_logic_vector(15 downto 0);
		o_PWM_X1	: out	std_logic_vector(15 downto 0);
		o_PWM_U2	: out	std_logic_vector(15 downto 0);
		o_PWM_V2	: out	std_logic_vector(15 downto 0);
		o_PWM_W2	: out	std_logic_vector(15 downto 0);
		o_PWM_X2	: out	std_logic_vector(15 downto 0);
		o_PWM_U3	: out	std_logic_vector(15 downto 0);
		o_PWM_V3	: out	std_logic_vector(15 downto 0);
		o_PWM_W3	: out	std_logic_vector(15 downto 0);
		o_PWM_X3	: out	std_logic_vector(15 downto 0);
		-- 0x2100
		o_PWM_INT	: out	std_logic_vector(15 downto 0);
		o_Conv_St	: out	std_logic_vector(15 downto 0);
		o_PWM_100_ax42 : out	std_logic_vector(15 downto 0);-- same address as o_dead_time
		o_dead_time	: out	std_logic_vector(15 downto 0);
		o_cEnc_time	: out	std_logic_vector(15 downto 0);-- same address as o_index_val
		o_index_val	: out	std_logic_vector(15 downto 0);
		o_ResOff	: out	std_logic_vector(31 downto 0);
		o_RESflg	: out	std_logic_vector(31 downto 0);
		-- 0x2200
		o_PWM_0		: out	std_logic_vector(15 downto 0);
		o_PWM_1		: out	std_logic_vector(15 downto 0);
		o_PWM_break	: out	std_logic_vector(15 downto 0);
		o_PWM_100_01: out	std_logic_vector(15 downto 0);
		-- 0x2300
		o_DAC0		: out	std_logic_vector(15 downto 0);
		o_DAC1		: out	std_logic_vector(15 downto 0);
		o_DAC2		: out	std_logic_vector(15 downto 0);
		o_DAC3		: out	std_logic_vector(15 downto 0);
		o_DAC_PD	: out	std_logic_vector(15 downto 0);
		o_dac_config: out	std_logic_vector(31 downto 0);
		--0x2400
		o_sin_gain	: out	std_logic_vector(31 downto 0);
		o_sin_phase	: out	std_logic_vector(31 downto 0);
		o_Ext_Flg	: out	std_logic_vector(31 downto 0);
		o_Flags		: out	std_logic_vector(31 downto 0);
		-- 0x2500
		o_si_config0: out	std_logic_vector(31 downto 0);
		o_SI0		: out	std_logic_vector(31 downto 0);
		o_si_config1: out	std_logic_vector(31 downto 0);
		o_SI1		: out	std_logic_vector(31 downto 0);
		o_si_config2: out	std_logic_vector(31 downto 0);
		o_SI2		: out	std_logic_vector(31 downto 0);
		o_si_config3: out	std_logic_vector(31 downto 0);
		o_SI3		: out	std_logic_vector(31 downto 0);
		o_Si_Read	: out	std_logic_vector(C_SI-1 downto 0);
		-- 
		i_PWM_Run	: in	std_logic := '0';
		-- triggers
		i_cADC_0	: in	std_logic := '0';
		i_cADC_180	: in	std_logic := '0';
		i_cCM		: in	std_logic := '0';
		i_cCM180	: in	std_logic := '0';
		i_cIntCnt	: in	std_logic := '0';
		i_cEncZP0	: in	std_logic := '0';
		i_cEncZP1	: in	std_logic := '0';
		i_cEncZP2	: in	std_logic := '0';
		i_cEncZP3	: in	std_logic := '0';
		i_cEncZP4	: in	std_logic := '0';
		i_cEncZP5	: in	std_logic := '0';
		i_cEncZP6	: in	std_logic := '0';
		i_cEncZP7	: in	std_logic := '0';
		i_cEnc		: in	std_logic := '0';
		i_cPWM0		: in	std_logic := '0';
		i_cSI0		: in	std_logic := '0';
		i_cSI1		: in	std_logic := '0';
		i_cSI2		: in	std_logic := '0';
		i_cSI3		: in	std_logic := '0';
		i_dac_addr	: in	std_logic_vector(3 downto 0) := (others => '0');
		i_dac_reread: in	std_logic := '0';
		o_dac_read_done : out std_logic;
		
		o_ppwm_pls_n0 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t0 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t0 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt0 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n1 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t1 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t1 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt1 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n2 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t2 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t2 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt2 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n3 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t3 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t3 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt3 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n4 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t4 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t4 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt4 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n5 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t5 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t5 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt5 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n6 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t6 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t6 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt6 : in	std_logic_vector(31 downto 0) := (others => '0');
		
		o_ppwm_pls_n7 : out	std_logic_vector(31 downto 0);
		o_ppwm_frq_t7 : out	std_logic_vector(31 downto 0);
		o_ppwm_pls_t7 : out	std_logic_vector(31 downto 0);
		i_ppwm_p_cnt7 : in	std_logic_vector(31 downto 0) := (others => '0')
	);
end;

architecture behavior_dpr2MotReg of dpr2MotReg is
--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	: std_logic := '1';
	constant	L	: std_logic := '0';
	constant	Z	: std_logic := 'Z';
	-- outputs
	constant DF_rPWM0_ADDR	: std_logic_vector(9 downto 0) := "0000000000";--BASE+0x0000
	constant DF_rPWM1_ADDR	: std_logic_vector(9 downto 0) := "0000000001";--BASE+0x0008
	constant DF_rPWM2_ADDR	: std_logic_vector(9 downto 0) := "0000000010";--BASE+0x0010
	constant DF_rPWM3_ADDR	: std_logic_vector(9 downto 0) := "0000000011";--BASE+0x0018
	constant DF_rPWMC_ADDR	: std_logic_vector(9 downto 0) := "0000100000";--BASE+0x0100
	constant DF_rPWMRF_ADDR	: std_logic_vector(9 downto 0) := "0000100001";--BASE+0x0108
	constant DF_rSPWM_ADDR	: std_logic_vector(9 downto 0) := "0001000000";--BASE+0x0200
	constant DF_rDAC_ADDR	: std_logic_vector(9 downto 0) := "0001100000";--BASE+0x0300
	constant DF_rDOUT0_ADDR	: std_logic_vector(9 downto 0) := "0010000000";--BASE+0x0400
	constant DF_rDOUT1_ADDR	: std_logic_vector(9 downto 0) := "0010000001";--BASE+0x0408
	constant DF_rSI0_ADDR	: std_logic_vector(9 downto 0) := "0010100000";--BASE+0x0500
	constant DF_rSI1_ADDR	: std_logic_vector(9 downto 0) := "0010100001";--BASE+0x0508
	constant DF_rSI2_ADDR	: std_logic_vector(9 downto 0) := "0010100010";--BASE+0x0510
	constant DF_rSI3_ADDR	: std_logic_vector(9 downto 0) := "0010100011";--BASE+0x0518
	
	constant DF_rPLS_ADDR	: std_logic_vector(9 downto 0) := "0011000000";--BASE+0x0600
	-- indices
	constant DF_rPWM0_INDEX : integer := 0;
	constant DF_rPWM1_INDEX : integer := 1;
	constant DF_rPWM2_INDEX : integer := 2;
	constant DF_rPWM3_INDEX : integer := 3;
	constant DF_rPWMC_INDEX : integer := 4;
	constant DF_rPWMRF_INDEX : integer := 5;
	constant DF_rDOUT0_INDEX : integer := 6;
	constant DF_rDOUT1_INDEX : integer := 7;
	constant DF_rSI0_INDEX : integer := 8;
	constant DF_rSI1_INDEX : integer := 9;
	constant DF_rSI2_INDEX : integer := 10;
	constant DF_rSI3_INDEX : integer := 11;
	constant DF_rSPWM_INDEX : integer := 12;
	constant DF_rdac0_INDEX : integer := 13;
	constant DF_rdac1_INDEX : integer := 14; 
	constant DF_rPLS00_INDEX : integer := 15;
	constant DF_rPLS01_INDEX : integer := 16;
	constant DF_rPLS02_INDEX : integer := 17;
	constant DF_rPLS03_INDEX : integer := 18;
	constant DF_rPLS04_INDEX : integer := 19;
	constant DF_rPLS05_INDEX : integer := 20;
	constant DF_rPLS06_INDEX : integer := 21;
	constant DF_rPLS07_INDEX : integer := 22;
	constant DF_rPLS08_INDEX : integer := 23;
	constant DF_rPLS09_INDEX : integer := 24;
	constant DF_rPLS10_INDEX : integer := 25;
	constant DF_rPLS11_INDEX : integer := 26;
	constant DF_rPLS12_INDEX : integer := 27;
	constant DF_rPLS13_INDEX : integer := 28;
	constant DF_rPLS14_INDEX : integer := 29;
	constant DF_rPLS15_INDEX : integer := 30;
	
	
	-- inputs
	constant DF_ADC0_0_ADDR		: std_logic_vector(9 downto 0) := "1000000000";--BASE+0x1000
	constant DF_ADC1_0_ADDR		: std_logic_vector(9 downto 0) := "1000000001";--BASE+0x1008
	constant DF_ADC2_0_ADDR		: std_logic_vector(9 downto 0) := "1000000010";--BASE+0x1010
	--constant DF_ADC0_180_ADDR	: std_logic_vector(9 downto 0) := "1000000100";--BASE+0x1020
	--constant DF_ADC1_180_ADDR	: std_logic_vector(9 downto 0) := "1000000111";--BASE+0x1028
	--constant DF_ADC2_180_ADDR	: std_logic_vector(9 downto 0) := "1000000110";--BASE+0x1030
	constant DF_CM0_ADDR		: std_logic_vector(9 downto 0) := "1000100000";--BASE+0x1100
	constant DF_CM1_ADDR		: std_logic_vector(9 downto 0) := "1000100001";--BASE+0x1108
	constant DF_CM2_ADDR		: std_logic_vector(9 downto 0) := "1000100010";--BASE+0x1110
	constant DF_CM3_ADDR		: std_logic_vector(9 downto 0) := "1000100011";--BASE+0x1118
	--constant DF_CM0_180_ADDR	: std_logic_vector(9 downto 0) := "1000100100";--BASE+0x1120
	--constant DF_CM1_180_ADDR	: std_logic_vector(9 downto 0) := "1000100101";--BASE+0x1128
	--constant DF_CM2_180_ADDR	: std_logic_vector(9 downto 0) := "1000100110";--BASE+0x1130
	--constant DF_CM3_180_ADDR	: std_logic_vector(9 downto 0) := "1000100110";--BASE+0x1138
	constant DF_ENC_ADDR_0		: std_logic_vector(9 downto 0) := "1001000000";--BASE+0x1200
	constant DF_ENC_ADDR_1		: std_logic_vector(9 downto 0) := "1001000001";--BASE+0x1208
	constant DF_ENC_ADDR_2		: std_logic_vector(9 downto 0) := "1001000010";--BASE+0x1210
	constant DF_ENC_ADDR_3		: std_logic_vector(9 downto 0) := "1001000011";--BASE+0x1218
	constant DF_ENC_ADDR_4		: std_logic_vector(9 downto 0) := "1001000100";--BASE+0x1220
	constant DF_ENC_ADDR_5		: std_logic_vector(9 downto 0) := "1001000101";--BASE+0x1228
	constant DF_ENC_ADDR_6		: std_logic_vector(9 downto 0) := "1001000110";--BASE+0x1230
	constant DF_ENC_ADDR_7		: std_logic_vector(9 downto 0) := "1001000111";--BASE+0x1238
	constant DF_MISC0_ADDR		: std_logic_vector(9 downto 0) := "1001100000";--BASE+0x1300
	constant DF_MISC1_ADDR		: std_logic_vector(9 downto 0) := "1001100001";--BASE+0x1308
	constant DF_SI0_ADDR		: std_logic_vector(9 downto 0) := "1010100000";--BASE+0x1500
	constant DF_SI1_ADDR		: std_logic_vector(9 downto 0) := "1010100010";--BASE+0x1510
	constant DF_SI2_ADDR		: std_logic_vector(9 downto 0) := "1010100100";--BASE+0x1520
	constant DF_SI3_ADDR		: std_logic_vector(9 downto 0) := "1010100110";--BASE+0x1530
	
	constant DF_PLS_ADDR		: std_logic_vector(9 downto 0) := "1011000000";--BASE+0x1600
	
	-- indices
	constant DF_ADC0	: integer := 0;
	constant DF_ADC1	: integer := 1;
	constant DF_ADC2	: integer := 2;
	constant DF_CM0		: integer := 3;
	constant DF_CM1		: integer := 4;
	constant DF_CM2		: integer := 5;
	constant DF_CM3		: integer := 6;
	constant DF_E_ZP0	: integer := 7;
	constant DF_E_ZP1	: integer := 8;
	constant DF_E_ZP2	: integer := 9;
	constant DF_E_ZP3	: integer := 10;
	constant DF_E_ZP4	: integer := 11;
	constant DF_E_ZP5	: integer := 12;
	constant DF_E_ZP6	: integer := 13;
	constant DF_E_ZP7	: integer := 14;
	constant DF_MISC0	: integer := 15;
	constant DF_MISC1	: integer := 16;
	constant DF_SI0		: integer := 17;
	constant DF_SI1		: integer := 18;
	constant DF_SI2		: integer := 19;
	constant DF_SI3		: integer := 20;
	constant DF_PLS0	: integer := 21;
	constant DF_PLS1	: integer := 22;
	constant DF_PLS2	: integer := 23;
	constant DF_PLS3	: integer := 24;

	-- types -------------------------------------------------------------------
	type t_state is (rw_loop0, rw_loop1, rw_loop2, rw_loop3, rw_loop4, rw_loop5, rw_loop6, rw_loop7, rw_loop8, rw_loop9, rw_loop10, rw_loop11, rw_loop12, rw_loop12_5, rw_loop13, rw_loop14, write, reread_DAC, readdac0, readdac1, rPulsePwm0,rPulsePwm1,rPulsePwm2,rPulsePwm3,rPulsePwm4,rPulsePwm5,rPulsePwm6,rPulsePwm7,rPulsePwm8,rPulsePwm9,rPulsePwm10,rPulsePwm11,rPulsePwm12,rPulsePwm13,rPulsePwm14,rPulsePwm15,rPulsePwm16,rPulsePwm17);
	type tr_data	is array(0 to 30) of std_logic_vector(o_dprData'length-1 downto 0);
	type tw_data	is array(0 to 24) of std_logic_vector(o_dprData'length-1 downto 0);
	-- signal ------------------------------------------------------------------
	signal State		: t_state := write;
	signal addr			: std_logic_vector(9 downto 0) := DF_rPWM0_ADDR;
	signal data_index	: std_logic_vector(4 downto 0) := (others=>L);
	signal r_data		: tr_data := (others => (others => L));
	signal w_data		: tw_data := (others => (others => L));
	signal PWMCntAtInt	: std_logic_vector(15 downto 0);
	signal EncoderZP0	: std_logic_vector(31 downto 0);
	signal EncoderZP1	: std_logic_vector(31 downto 0);
	signal EncoderZP2	: std_logic_vector(31 downto 0);
	signal EncoderZP3	: std_logic_vector(31 downto 0);
	signal EncoderZP4	: std_logic_vector(31 downto 0);
	signal EncoderZP5	: std_logic_vector(31 downto 0);
	signal EncoderZP6	: std_logic_vector(31 downto 0);
	signal EncoderZP7	: std_logic_vector(31 downto 0);
	
	
	signal PWMCntAtInt_PWM0	: std_logic_vector(15 downto 0);
	signal EncoderZP0_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP1_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP2_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP3_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP4_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP5_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP6_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP7_PWM0	: std_logic_vector(31 downto 0);
	signal Enc0			: std_logic_vector(15 downto 0);
	signal Enc1			: std_logic_vector(15 downto 0);
	signal Enc2			: std_logic_vector(15 downto 0);
	signal Enc3			: std_logic_vector(15 downto 0);
	signal Enc4			: std_logic_vector(15 downto 0);
	signal Enc5			: std_logic_vector(15 downto 0);
	signal Enc6			: std_logic_vector(15 downto 0);
	signal Enc7			: std_logic_vector(15 downto 0);
	signal ADCx0		: std_logic_vector(63 downto 0);
	signal ADCx1		: std_logic_vector(63 downto 0);
	signal ADCx0_180	: std_logic_vector(63 downto 0);
	signal ADCx1_180	: std_logic_vector(63 downto 0);
	
	signal cADC0_0		: std_logic := L;
	signal cADC0_180	: std_logic := L;
	signal cADC1_0		: std_logic := L;
	signal cADC2_0		: std_logic := L;
	signal cCM0			: std_logic := L;
	signal cCM0_180		: std_logic := L;
	signal cCM1			: std_logic := L;
	signal cCM2			: std_logic := L;
	signal cCM3			: std_logic := L;
	
	signal cIntCnt		: std_logic := L;
	signal cEncoder0	: std_logic := L;
	signal cEncoder1	: std_logic := L;
	signal cEncoder2	: std_logic := L;
	signal cEncoder3	: std_logic := L;
	signal cEncoder4	: std_logic := L;
	signal cEncoder5	: std_logic := L;
	signal cEncoder6	: std_logic := L;
	signal cEncoder7	: std_logic := L;
	signal cPWM0		: std_logic := L;
	signal cSI0			: std_logic := L;
	signal cSI1			: std_logic := L;
	signal cSI2			: std_logic := L;
	signal cSI3			: std_logic := L;
	signal cPUlsePWM0	: std_logic := L;
	signal cPUlsePWM1	: std_logic := L;
	signal cPUlsePWM2	: std_logic := L;
	signal cPUlsePWM3	: std_logic := L;
	
	
	
	signal read_DAC		: std_logic := L;

	signal GND16		: std_logic_vector(15 downto 0)	:= (others => L);

--------------------------------------------------------------------------------
begin

	o_PWM_U0 <= r_data(DF_rPWM0_INDEX)(63 downto 48);			-- 0x0000
	o_PWM_V0 <= r_data(DF_rPWM0_INDEX)(47 downto 32);			-- 0x0002
	o_PWM_W0 <= r_data(DF_rPWM0_INDEX)(31 downto 16);			-- 0x0004
	o_PWM_X0 <= r_data(DF_rPWM0_INDEX)(15 downto 0);			-- 0x0006
	o_PWM_100<= r_data(DF_rPWM0_INDEX)(15 downto 0);			-- 0x0006
	
	o_PWM_U1 <= r_data(DF_rPWM1_INDEX)(63 downto 48);			-- 0x0008
	o_PWM_V1 <= r_data(DF_rPWM1_INDEX)(47 downto 32);			-- 0x000A
	o_PWM_W1 <= r_data(DF_rPWM1_INDEX)(31 downto 16);			-- 0x000C
	o_PWM_X1 <= r_data(DF_rPWM1_INDEX)(15 downto 0);			-- 0x000E
	
	o_PWM_U2 <= r_data(DF_rPWM2_INDEX)(63 downto 48);			-- 0x0010
	o_PWM_V2 <= r_data(DF_rPWM2_INDEX)(47 downto 32);			-- 0x0012
	o_PWM_W2 <= r_data(DF_rPWM2_INDEX)(31 downto 16);			-- 0x0014
	o_PWM_X2 <= r_data(DF_rPWM2_INDEX)(15 downto 0);			-- 0x0016
	
	o_PWM_U3 <= r_data(DF_rPWM3_INDEX)(63 downto 48);			-- 0x0018
	o_PWM_V3 <= r_data(DF_rPWM3_INDEX)(47 downto 32);			-- 0x001A
	o_PWM_W3 <= r_data(DF_rPWM3_INDEX)(31 downto 16);			-- 0x001C
	o_PWM_X3 <= r_data(DF_rPWM3_INDEX)(15 downto 0);			-- 0x001E

	o_PWM_INT	<= r_data(DF_rPWMC_INDEX)(63 downto 48);		-- 0x0100
	o_Conv_St	<= r_data(DF_rPWMC_INDEX)(47 downto 32);		-- 0x0102
	o_PWM_100_ax42	<= r_data(DF_rPWMC_INDEX)(31 downto 16);	-- 0x0104
	o_dead_time	<= r_data(DF_rPWMC_INDEX)(31 downto 16);		-- 0x0104
	o_index_val	<= r_data(DF_rPWMC_INDEX)(15 downto 0);			-- 0x0106
	o_cEnc_time	<= r_data(DF_rPWMC_INDEX)(15 downto 0);			-- 0x0106
	o_ResOff	<= r_data(DF_rPWMRF_INDEX)(63 downto 32);		-- 0x0108
	o_RESflg	<= r_data(DF_rPWMRF_INDEX)(31 downto 0);		-- 0x010C

	o_PWM_0			<= r_data(DF_rSPWM_INDEX)(63 downto 48);	-- 0x0200
	o_PWM_1			<= r_data(DF_rSPWM_INDEX)(47 downto 32);	-- 0x0202
	o_PWM_break		<= r_data(DF_rSPWM_INDEX)(31 downto 16);	-- 0x0204
	o_PWM_100_01	<= r_data(DF_rSPWM_INDEX)(15 downto 0);		-- 0x0206


	o_DAC_PD		<= r_data(DF_rDAC0_INDEX)(63 downto 48);	-- 0x0300
	o_DAC0			<= r_data(DF_rDAC0_INDEX)(47 downto 32);	-- 0x0302
	o_DAC1			<= r_data(DF_rDAC0_INDEX)(31 downto 16);	-- 0x0304
	o_DAC2			<= r_data(DF_rDAC0_INDEX)(15 downto 0);		-- 0x0306
	o_DAC3			<= r_data(DF_rDAC1_INDEX)(63 downto 48);	-- 0x0308
	--	 <= r_data(DF_rDAC1_INDEX)(47 downto 32);				-- 0x030A
	o_dac_config	<= r_data(DF_rDAC1_INDEX)(31 downto  0);	-- 0x030C
	
	o_sin_gain		<= r_data(DF_rDOUT0_INDEX)( 63 downto 32);	-- 0x0400
	o_sin_phase		<= r_data(DF_rDOUT0_INDEX)( 31 downto  0);	-- 0x0404
	o_Ext_Flg		<= r_data(DF_rDOUT1_INDEX)( 63 downto 32);	-- 0x0408
	o_Flags			<= r_data(DF_rDOUT1_INDEX)( 31 downto  0);	-- 0x040C
	
	o_si_config0	<= r_data(DF_rSI0_INDEX)( 63 downto 32);	-- 0x0500
	o_SI0			<= r_data(DF_rSI0_INDEX)( 31 downto  0);	-- 0x0504
	o_si_config1	<= r_data(DF_rSI1_INDEX)( 63 downto 32);	-- 0x0508
	o_SI1			<= r_data(DF_rSI1_INDEX)( 31 downto  0);	-- 0x050c
	o_si_config2	<= r_data(DF_rSI2_INDEX)( 63 downto 32);	-- 0x0510
	o_SI2			<= r_data(DF_rSI2_INDEX)( 31 downto  0);	-- 0x0514
	o_si_config3	<= r_data(DF_rSI3_INDEX)( 63 downto 32);	-- 0x0518
	o_SI3			<= r_data(DF_rSI3_INDEX)( 31 downto  0);	-- 0x051c

	o_ppwm_frq_t0	<= r_data(DF_rPLS00_INDEX)( 63 downto 32);	-- 0x0400
	o_ppwm_pls_t0	<= r_data(DF_rPLS00_INDEX)( 31 downto  0);	-- 0x0404
	o_ppwm_pls_n0	<= r_data(DF_rPLS01_INDEX)( 63 downto 32);	-- 0x0408
	
	o_ppwm_frq_t1	<= r_data(DF_rPLS02_INDEX)( 63 downto 32);	-- 0x0410
	o_ppwm_pls_t1	<= r_data(DF_rPLS02_INDEX)( 31 downto  0);	-- 0x0414
	o_ppwm_pls_n1	<= r_data(DF_rPLS03_INDEX)( 63 downto 32);	-- 0x0418
	
	o_ppwm_frq_t2	<= r_data(DF_rPLS04_INDEX)( 63 downto 32);	-- 0x0420
	o_ppwm_pls_t2	<= r_data(DF_rPLS04_INDEX)( 31 downto  0);	-- 0x0424
	o_ppwm_pls_n2	<= r_data(DF_rPLS05_INDEX)( 63 downto 32);	-- 0x0428
	
	o_ppwm_frq_t3	<= r_data(DF_rPLS06_INDEX)( 63 downto 32);	-- 0x0430
	o_ppwm_pls_t3	<= r_data(DF_rPLS06_INDEX)( 31 downto  0);	-- 0x0434
	o_ppwm_pls_n3	<= r_data(DF_rPLS07_INDEX)( 63 downto 32);	-- 0x0438
	
	o_ppwm_frq_t4	<= r_data(DF_rPLS08_INDEX)( 63 downto 32);	-- 0x0440
	o_ppwm_pls_t4	<= r_data(DF_rPLS08_INDEX)( 31 downto  0);	-- 0x0444
	o_ppwm_pls_n4	<= r_data(DF_rPLS09_INDEX)( 63 downto 32);	-- 0x0448
	
	o_ppwm_frq_t5	<= r_data(DF_rPLS10_INDEX)( 63 downto 32);	-- 0x0450
	o_ppwm_pls_t5	<= r_data(DF_rPLS10_INDEX)( 31 downto  0);	-- 0x0454
	o_ppwm_pls_n5	<= r_data(DF_rPLS11_INDEX)( 63 downto 32);	-- 0x0458
	
	o_ppwm_frq_t6	<= r_data(DF_rPLS12_INDEX)( 63 downto 32);	-- 0x0460
	o_ppwm_pls_t6	<= r_data(DF_rPLS12_INDEX)( 31 downto  0);	-- 0x0464
	o_ppwm_pls_n6	<= r_data(DF_rPLS13_INDEX)( 63 downto 32);	-- 0x0468
	
	o_ppwm_frq_t7	<= r_data(DF_rPLS14_INDEX)( 63 downto 32);	-- 0x0470
	o_ppwm_pls_t7	<= r_data(DF_rPLS14_INDEX)( 31 downto  0);	-- 0x0474
	o_ppwm_pls_n7	<= r_data(DF_rPLS15_INDEX)( 63 downto 32);	-- 0x0478
	
	--					0x0 & 0x2 & 0x4 & 0x6
	w_data(DF_ADC0) <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1;
	w_data(DF_ADC1) <= i_ADCA2 & i_ADCB2 & i_ADCA3 & i_ADCB3;
	w_data(DF_ADC2) <= i_ADCA4 & i_ADCB4 & i_ADCA5 & i_ADCB5;
	w_data(DF_CM0) <= i_sdADC0 & i_sdADC1 & i_sdADC2 & i_sdADC3;
	w_data(DF_CM1) <= i_sdADC4 & i_sdADC5 & i_sdADC6 & i_sdADC7;
	w_data(DF_CM2) <= i_sdADC8 & i_sdADC9 & i_sdADC10 & i_sdADC11;
	w_data(DF_CM3) <= i_sdADC12 & i_sdADC13 & i_sdADC14 & i_sdADC15;
	w_data(DF_E_ZP0) <= EncoderZP0_PWM0 & Enc0 & i_PWMCnt;
	w_data(DF_E_ZP1) <= EncoderZP1_PWM0 & Enc1 & GND16;
	w_data(DF_E_ZP2) <= EncoderZP2_PWM0 & Enc2 & GND16;
	w_data(DF_E_ZP3) <= EncoderZP3_PWM0 & Enc3 & GND16;
	w_data(DF_E_ZP4) <= EncoderZP4_PWM0 & Enc4 & GND16;
	w_data(DF_E_ZP5) <= EncoderZP5_PWM0 & Enc5 & GND16;
	w_data(DF_E_ZP6) <= EncoderZP6_PWM0 & Enc6 & GND16;
	w_data(DF_E_ZP7) <= EncoderZP7_PWM0 & Enc7 & GND16;
	w_data(DF_MISC0) <= i_d_in & i_ExtStatus;
	w_data(DF_MISC1) <= PWMCntAtInt_PWM0 & i_16 & i_Status;
	w_data(DF_SI0) <= i_SI0;
	w_data(DF_SI1) <= i_SI1;
	w_data(DF_SI2) <= i_SI2;
	w_data(DF_SI3) <= i_SI3;
	
	w_data(DF_PLS0) <= i_ppwm_p_cnt0 & i_ppwm_p_cnt1;
	w_data(DF_PLS1) <= i_ppwm_p_cnt2 & i_ppwm_p_cnt3;
	w_data(DF_PLS2) <= i_ppwm_p_cnt4 & i_ppwm_p_cnt5;
	w_data(DF_PLS3) <= i_ppwm_p_cnt6 & i_ppwm_p_cnt7;
	
	enc_trig : if C_USE_ENC_TRIGGER=1 generate
	begin
		enc : process (i_Clk) begin
			if rising_edge(i_Clk) then
				if i_cEnc=H then
					Enc0 <= i_Enc0;
					Enc1 <= i_Enc1;
					Enc2 <= i_Enc2;
					Enc3 <= i_Enc3;
					Enc4 <= i_Enc4;
					Enc5 <= i_Enc5;
					Enc6 <= i_Enc6;
					Enc7 <= i_Enc7;
				end if;
			end if;
		end process;
	end generate enc_trig;
	
	no_enc_trig : if C_USE_ENC_TRIGGER=0 generate
	begin
		Enc0 <= i_Enc0;
		Enc1 <= i_Enc1;
		Enc2 <= i_Enc2;
		Enc3 <= i_Enc3;
		Enc4 <= i_Enc4;
		Enc5 <= i_Enc5;
		Enc6 <= i_Enc6;
		Enc7 <= i_Enc7;
	end generate no_enc_trig;
	

	dpr : process (i_Clk) begin
		if rising_edge(i_Clk) then
			o_dprWEN <= (others => L);
			o_Si_Read <= (others => L);
			-- hold trigger inputs
			cCM0 <= i_cCM or i_cCM180 or cCM0; -- tigger
			cCM0_180 <= i_cCM180 or cCM0_180; -- 180° hold
			cIntCnt <= i_cIntCnt or cIntCnt;
			cADC0_0 <= i_cADC_0 or i_cADC_180 or cADC0_0; -- tigger
			cADC0_180 <= i_cADC_180 or cADC0_180; -- 180° hold
			cSI0 <= i_cSI0 or cSI0;
			cSI1 <= i_cSI1 or cSI1;
			cSI2 <= i_cSI2 or cSI2;
			cSI3 <= i_cSI3 or cSI3;
			read_DAC <= read_DAC or i_dac_reread;
			if (i_cIntCnt=L and cIntCnt=H) then
				PWMCntAtInt <= i_PWMCnt;
				cIntCnt <= L;
			end if;
			if i_cEncZP0=H then
				EncoderZP0 <= i_Enc0 & i_PWMCnt;
			end if;
			if i_cEncZP1=H then
				EncoderZP1 <= i_Enc1 & i_PWMCnt;
			end if;
			if i_cEncZP2=H then
				EncoderZP2 <= i_Enc2 & i_PWMCnt;
			end if;
			if i_cEncZP3=H then
				EncoderZP3 <= i_Enc3 & i_PWMCnt;
			end if;
			if i_cEncZP4=H then
				EncoderZP4 <= i_Enc4 & i_PWMCnt;
			end if;
			if i_cEncZP5=H then
				EncoderZP5 <= i_Enc5 & i_PWMCnt;
			end if;
			if i_cEncZP6=H then
				EncoderZP6 <= i_Enc6 & i_PWMCnt;
			end if;
			if i_cEncZP7=H then
				EncoderZP7 <= i_Enc7 & i_PWMCnt;
			end if;
			if i_cPWM0=H then
				PWMCntAtInt_PWM0 <= PWMCntAtInt;
				EncoderZP0_PWM0 <= EncoderZP0;
				EncoderZP1_PWM0 <= EncoderZP1;
				EncoderZP2_PWM0 <= EncoderZP2;
				EncoderZP3_PWM0 <= EncoderZP3;
				EncoderZP4_PWM0 <= EncoderZP4;
				EncoderZP5_PWM0 <= EncoderZP5;
				EncoderZP6_PWM0 <= EncoderZP6;
				EncoderZP7_PWM0 <= EncoderZP7;
				cPWM0 <= H;
			end if;
			o_dprEN <= L;
			addr <= DF_rPWM0_ADDR;
			--data_index <= (others=>L);
			case state is
				when rw_loop0 =>
					if (C_PWM > 1) then
						addr <= DF_rPWM1_ADDR;
					end if;
					state <= rw_loop1;
					o_dprEN <= H;
				when rw_loop1 =>
					if (C_PWM > 2) then
						addr <= DF_rPWM2_ADDR;
					end if;
					r_data(DF_rPWM0_INDEX) <= i_dprData;
					state <= rw_loop2;
					o_dprEN <= H;
				when rw_loop2 =>
					if (C_PWM > 3) then
						addr <= DF_rPWM3_ADDR;
					end if;
					if (C_PWM > 1) then
						r_data(DF_rPWM1_INDEX) <= i_dprData;
					end if;
					state <= rw_loop3;
					o_dprEN <= H;
				when rw_loop3 =>
					addr <= DF_rPWMC_ADDR;
					if (C_PWM > 2) then
						r_data(DF_rPWM2_INDEX) <= i_dprData;
					end if;
					state <= rw_loop4;
					o_dprEN <= H;
				when rw_loop4 =>
					addr <= DF_rPWMRF_ADDR;
					if (C_PWM > 3) then
						r_data(DF_rPWM3_INDEX) <= i_dprData;
					end if;
					state <= rw_loop5;
					o_dprEN <= H;
				when rw_loop5 =>
					addr <= DF_rDOUT0_ADDR;
					r_data(DF_rPWMC_INDEX) <= i_dprData;
					state <= rw_loop6;
					o_dprEN <= H;
				when rw_loop6 =>
					addr <= DF_rDOUT1_ADDR;
					r_data(DF_rPWMRF_INDEX) <= i_dprData;
					state <= rw_loop7;
					o_dprEN <= H;
				when rw_loop7 =>
					addr <= DF_rSI0_ADDR;
					r_data(DF_rDOUT0_INDEX) <= i_dprData;
					state <= rw_loop8;
					o_dprEN <= H;
				when rw_loop8 =>
					if (C_SI > 1) then
						addr <= DF_rSI1_ADDR;
					end if;
					r_data(DF_rDOUT1_INDEX) <= i_dprData;
					state <= rw_loop9;
					o_dprEN <= H;
				when rw_loop9 =>
					if (C_SI > 2) then
						addr <= DF_rSI2_ADDR;
					end if;
					r_data(DF_rSI0_INDEX) <= i_dprData;
					o_Si_Read(0) <= H;
					state <= rw_loop10;
					o_dprEN <= H;
				when rw_loop10 =>
					if (C_SI > 3) then
						addr <= DF_rSI3_ADDR;
					end if;
					if (C_SI > 1) then
						r_data(DF_rSI1_INDEX) <= i_dprData;
						o_Si_Read(1) <= H;
					end if;
					state <= rw_loop11;
					o_dprEN <= H;
				when rw_loop11 =>
					if (C_SPWM/=0) then
						addr <= DF_rSPWM_ADDR;
					end if;
					if (C_SI > 2) then
						r_data(DF_rSI2_INDEX) <= i_dprData;
						o_Si_Read(2) <= H;
					end if;
					state <= rw_loop12;
					o_dprEN <= H;
				when rw_loop12 =>
					if (C_DAC/=0) then
						addr <= DF_rDAC_ADDR(9 downto 5) & i_dac_addr & L;
					end if;
					if (C_SI > 3) then
						r_data(DF_rSI3_INDEX) <= i_dprData;
						o_Si_Read(3) <= H;
					end if;
					state <= rw_loop12_5;
					o_dprEN <= H;
				when rw_loop12_5 =>
					if (C_DAC/=0) then
						addr <= DF_rDAC_ADDR(9 downto 5) & i_dac_addr & H;
					end if;
					if (C_SPWM/=0) then
						r_data(DF_rSPWM_INDEX) <= i_dprData;
					end if;
					state <= rw_loop13;
					o_dprEN <= H;
				
				when rw_loop13 =>
					addr <= DF_MISC0_ADDR;
					data_index <= CONV_STD_LOGIC_VECTOR(DF_MISC0,data_index'length);
					o_dprWEN <= (others => H);
					if (C_DAC/=0) then
						r_data(DF_rDAC0_INDEX) <= i_dprData;
					end if;
					state <= rw_loop14;
					o_dprEN <= H;
				when rw_loop14 =>
					addr <= DF_MISC1_ADDR;
					data_index <= CONV_STD_LOGIC_VECTOR(DF_MISC1,data_index'length);
					o_dprWEN <= (others => H);
					if (C_DAC/=0) then
						r_data(DF_rDAC1_INDEX) <= i_dprData;
						o_dac_read_done <= H;
						read_DAC <= L;
					end if;
					if (C_8PULS=0) then
						state <= write;
					else
						state <= rPulsePwm0;
					end if;
					o_dprEN <= H;
				when reread_DAC =>
					addr <= DF_rDAC_ADDR(9 downto 5) & i_dac_addr & H;
					state <= readdac0;
					o_dprEN <= H;
				when readdac0 =>
					if (C_DAC/=0) then
						r_data(DF_rDAC0_INDEX) <= i_dprData;
					end if;
					state <= readdac1;
					o_dprEN <= H;
				when readdac1 =>
					if (C_DAC/=0) then
						r_data(DF_rDAC1_INDEX) <= i_dprData;
						o_dac_read_done <= H;
						read_DAC <= L;
					end if;
					state <= write;
					o_dprEN <= H;
				
					
				when rPulsePwm0 =>
					addr <= DF_rPLS_ADDR;
					state <= rPulsePwm1;
					o_dprEN <= H;
				when rPulsePwm1 =>
					addr <= DF_rPLS_ADDR+1;
					state <= rPulsePwm2;
					o_dprEN <= H;
				when rPulsePwm2 =>
					addr <= DF_rPLS_ADDR+2;
					r_data(DF_rPLS00_INDEX) <= i_dprData;
					state <= rPulsePwm3;
					o_dprEN <= H;
				when rPulsePwm3 =>
					addr <= DF_rPLS_ADDR+3;
					r_data(DF_rPLS00_INDEX+1) <= i_dprData;
					state <= rPulsePwm4;
					o_dprEN <= H;
				when rPulsePwm4 =>
					addr <= DF_rPLS_ADDR+4;
					r_data(DF_rPLS00_INDEX+2) <= i_dprData;
					state <= rPulsePwm5;
					o_dprEN <= H;
				when rPulsePwm5 =>
					addr <= DF_rPLS_ADDR+5;
					r_data(DF_rPLS00_INDEX+3) <= i_dprData;
					state <= rPulsePwm6;
					o_dprEN <= H;
				when rPulsePwm6 =>
					addr <= DF_rPLS_ADDR+6;
					r_data(DF_rPLS00_INDEX+4) <= i_dprData;
					state <= rPulsePwm7;
					o_dprEN <= H;
				when rPulsePwm7 =>
					addr <= DF_rPLS_ADDR+7;
					r_data(DF_rPLS00_INDEX+5) <= i_dprData;
					state <= rPulsePwm8;
					o_dprEN <= H;
				when rPulsePwm8 =>
					addr <= DF_rPLS_ADDR+8;
					r_data(DF_rPLS00_INDEX+6) <= i_dprData;
					state <= rPulsePwm9;
					o_dprEN <= H;
				when rPulsePwm9 =>
					addr <= DF_rPLS_ADDR+9;
					r_data(DF_rPLS00_INDEX+7) <= i_dprData;
					state <= rPulsePwm10;
					o_dprEN <= H;
				when rPulsePwm10 =>
					addr <= DF_rPLS_ADDR+10;
					r_data(DF_rPLS00_INDEX+8) <= i_dprData;
					state <= rPulsePwm11;
					o_dprEN <= H;
				when rPulsePwm11 =>
					addr <= DF_rPLS_ADDR+11;
					r_data(DF_rPLS00_INDEX+9) <= i_dprData;
					state <= rPulsePwm12;
					o_dprEN <= H;
				when rPulsePwm12 =>
					addr <= DF_rPLS_ADDR+12;
					r_data(DF_rPLS00_INDEX+10) <= i_dprData;
					state <= rPulsePwm13;
					o_dprEN <= H;	
				when rPulsePwm13 =>
					addr <= DF_rPLS_ADDR+13;
					r_data(DF_rPLS00_INDEX+11) <= i_dprData;
					state <= rPulsePwm14;
					o_dprEN <= H;
				when rPulsePwm14 =>
					addr <= DF_rPLS_ADDR+14;
					r_data(DF_rPLS00_INDEX+12) <= i_dprData;
					state <= rPulsePwm15;
					o_dprEN <= H;
				when rPulsePwm15 =>
					addr <= DF_rPLS_ADDR+15;
					r_data(DF_rPLS00_INDEX+13) <= i_dprData;
					state <= rPulsePwm16;
					o_dprEN <= H;
				when rPulsePwm16 =>
					--addr <= DF_rPLS_ADDR+12;
					r_data(DF_rPLS00_INDEX+14) <= i_dprData;
					state <= rPulsePwm17;
					o_dprEN <= H;
				when rPulsePwm17 =>
					--addr <= DF_rPLS_ADDR+13;
					r_data(DF_rPLS00_INDEX+15) <= i_dprData;
					state <= write;
					o_dprEN <= H;
				when write =>
					-- w_data(ADC) 0° and 180°
					if (cADC0_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC0,data_index'length);
						addr <= DF_ADC0_0_ADDR;
						addr(2) <= cADC0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cADC0_0 <= L;
						if (C_ADC > 2) then
							cADC1_0 <= H;
						else
							cADC0_180 <= L;
						end if;
					elsif (cADC1_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC1,data_index'length);
						addr <= DF_ADC1_0_ADDR;
						addr(2) <= cADC0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cADC1_0 <= L;
						if (C_ADC > 4) then
							cADC2_0 <= H;
						else
							cADC0_180 <= L;
						end if;
					elsif (cADC2_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC2,data_index'length);
						addr <= DF_ADC2_0_ADDR;
						addr(2) <= cADC0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cADC2_0 <= L;
						cADC0_180 <= L;
					-- w_data(CM) 0° and 180°
					elsif (cCM0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM0,data_index'length);
						addr <= DF_CM0_ADDR;
						addr(2) <= cCM0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cCM0 <= L;
						if (C_CM > 4) then
							cCM1 <= H;
						else
							cCM0_180 <= L;
						end if;
					elsif cCM1=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM1,data_index'length);
						addr <= DF_CM1_ADDR;
						addr(2) <= cCM0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cCM1 <= L;
						if (C_CM > 8) then
							cCM2 <= H;
						else
							cCM0_180 <= L;
						end if;
					elsif cCM2=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM2,data_index'length);
						addr <= DF_CM2_ADDR;
						addr(2) <= cCM0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cCM2 <= L;
						if (C_CM > 12) then
							cCM3 <= H;
						else
							cCM0_180 <= L;
						end if;
					elsif cCM3=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM3,data_index'length);
						addr <= DF_CM3_ADDR;
						addr(2) <= cCM0_180;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cCM3 <= L;
						cCM0_180 <= L;
					elsif cSI0=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI0,data_index'length);
						addr <= DF_SI0_ADDR;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cSI0 <= L;
					elsif cSI1=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI1,data_index'length);
						addr <= DF_SI1_ADDR;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cSI1 <= L;
					elsif cSI2=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI2,data_index'length);
						addr <= DF_SI2_ADDR;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cSI2 <= L;
					elsif cSI3=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI3,data_index'length);
						addr <= DF_SI3_ADDR;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cSI3 <= L;
					-- w_data(ENCODER_ZP)
					elsif cEncoder0=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP0,data_index'length);
						addr <= DF_ENC_ADDR_0;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder0 <= L;
						if (C_ENC > 1) then
							cEncoder1 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder1=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP1,data_index'length);
						addr <= DF_ENC_ADDR_1;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder1 <= L;
						if (C_ENC > 2) then
							cEncoder2 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder2=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP2,data_index'length);
						addr <= DF_ENC_ADDR_2;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder2 <= L;
						if (C_ENC > 3) then
							cEncoder3 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder3=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP3,data_index'length);
						addr <= DF_ENC_ADDR_3;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder3 <= L;
						if (C_ENC > 4) then
							cEncoder4 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder4=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP4,data_index'length);
						addr <= DF_ENC_ADDR_4;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder4 <= L;
						if (C_ENC > 5) then
							cEncoder5 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder5=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP5,data_index'length);
						addr <= DF_ENC_ADDR_5;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder5 <= L;
						if (C_ENC > 6) then
							cEncoder6 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder6=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP6,data_index'length);
						addr <= DF_ENC_ADDR_6;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder6 <= L;
						if (C_ENC > 7) then
							cEncoder7 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cEncoder7=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP7,data_index'length);
						addr <= DF_ENC_ADDR_7;
						o_dprEN <= H;
						o_dprWEN <= (others => H);
						cEncoder7 <= L;
						if (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					elsif cPUlsePWM0=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_PLS0,data_index'length);
						addr <= DF_PLS_ADDR;
						o_dprWEN <= (others => H);
						o_dprEN <= H;
						cPUlsePWM0 <= L;
						cPUlsePWM1 <= H;
					elsif cPUlsePWM1=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_PLS1,data_index'length);
						addr <= DF_PLS_ADDR+1;
						o_dprWEN <= (others => H);
						o_dprEN <= H;
						cPUlsePWM1 <= L;
						cPUlsePWM2 <= H;
					elsif cPUlsePWM2=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_PLS2,data_index'length);
						addr <= DF_PLS_ADDR+2;
						o_dprWEN <= (others => H);
						o_dprEN <= H;
						cPUlsePWM2 <= L;
						cPUlsePWM3 <= H;
					elsif cPUlsePWM3=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_PLS3,data_index'length);
						addr <= DF_PLS_ADDR+3;
						o_dprWEN <= (others => H);
						o_dprEN <= H;
						cPUlsePWM3 <= L;
					elsif cPWM0=H then
						addr <= DF_rPWM0_ADDR;
						state <= rw_loop0;
						o_dprEN <= H;
						cPWM0 <= L;
						if (C_ENC > 0) then
							cEncoder0 <= H;
						elsif (C_8PULS=1) then
							cPUlsePWM0 <= H;
						end if;
					else
						if (i_PWM_Run=L) then -- read permanent
							addr <= DF_rPWM0_ADDR;
							state <= rw_loop0;
							o_dprEN <= H;
						elsif (read_DAC=H and C_DAC/=0) then
							state <= reread_DAC;
							addr <= DF_rDAC_ADDR(9 downto 5) & i_dac_addr & L;
							o_dprEN <= H;
						end if;
					end if;
			end case;
			-- syncron reset
			if (i_Reset=H) then
				cADC0_0 <= L;
				cADC1_0 <= L;
				cADC2_0 <= L;
				cADC0_180 <= L;
				cCM0 <= L;
				cCM1 <= L;
				cCM2 <= L;
				cCM0_180 <= L;
				cIntCnt <= L;
				cEncoder0 <= L;
				cEncoder1 <= L;
				cEncoder2 <= L;
				cEncoder3 <= L;
				cEncoder4 <= L;
				cEncoder5 <= L;
				cEncoder6 <= L;
				cEncoder7 <= L;
				cPWM0 <= L;
				cSI0 <= L;
				cSI1 <= L;
				cSI2 <= L;
				cSI3 <= L;
				read_DAC <= L;
				state <= write;
			end if;
		end if;
	end process;

	mux : process (data_index,w_data)
	begin
		o_dprData<= w_data(conv_integer(data_index));
	end process;

	o_dprAddr <= addr;
	o_dprClk <= i_Clk;
	o_dprRst <= i_Reset;


end behavior_dpr2MotReg;