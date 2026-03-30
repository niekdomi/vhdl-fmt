--------------------------------------------------------------------------------
--
--  dpr2SAC3x3Reg
--
--------------------------------------------------------------------------------
--
--  project     : INFO-SAC3x3
--  programmer  : C.Leuthold, INDEL AG
--  date        : 29.05.2007
--  version     : 1.00
--  language    : VHDL
--  system      : ISE / EDK
--
--	purpose
--		copy registers from and to blockram
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--
--	29.05.2007-le: - start
--	29.04.2009-le: - corrections for si register
--					 add breakpwm, sinus geni gain and phase
--	07.05.2009-le: - add o_Si_Read (H pulse when si config reg is read)
--	02.06.2009-le: - add Extended Status
--------------------------------------------------------------------------------
--$Rev:: 1033                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-06-02 17:15:49 +0200 (Di., 02 Jun 2009)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library	ieee;
use	IEEE.std_logic_1164.ALL;
use	IEEE.std_logic_unsigned.ALL;
use	IEEE.std_logic_arith.ALL;

entity dpr2SAC3x3Reg is
	port (
		--System
		i_Reset		: IN	std_logic;						-- Reset
		i_Clk		: IN	std_logic;						-- 99MHz
		-- Dualport	Ram	access
		o_dprEN		: OUT	std_logic;
		o_dprClk	: OUT	std_logic;
		o_dprRst	: OUT	std_logic;
		o_dprWEN	: OUT	std_logic_vector(3 downto 0);
		o_dprData	: out	STD_LOGIC_VECTOR(127 downto 0);
		i_dprData	: in	STD_LOGIC_VECTOR(127 downto 0);
		o_dprAddr	: OUT	std_logic_vector(8 downto 0);
		-- inputs
		-- adcs
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
		-- current measurement
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
		-- encoders
		i_Enc0		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc1		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc2		: in	std_logic_vector(15 downto 0) := (others => '0');
		-- misc
		i_PWMCnt	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Status	: in	std_logic_vector(31 downto 0) := (others => '0');
		i_ExtStatus	: in	std_logic_vector(31 downto 0);
		i_SI0		: in	std_logic_vector(63 downto 0) := (others => '0');
		i_SI1		: in	std_logic_vector(63 downto 0) := (others => '0');
		i_SI2		: in	std_logic_vector(63 downto 0) := (others => '0');
		-- outputs
		-- pwm
		o_PWM_U0	: out	std_logic_vector(15 downto 0);
		o_PWM_V0	: out	std_logic_vector(15 downto 0);
		o_PWM_W0	: out	std_logic_vector(15 downto 0);
		o_PWM_U1	: out	std_logic_vector(15 downto 0);
		o_PWM_V1	: out	std_logic_vector(15 downto 0);
		o_PWM_W1	: out	std_logic_vector(15 downto 0);
		o_PWM_U2	: out	std_logic_vector(15 downto 0);
		o_PWM_V2	: out	std_logic_vector(15 downto 0);
		o_PWM_W2	: out	std_logic_vector(15 downto 0);
		-- pwm 100%
		o_PWM_100	: out	std_logic_vector(15 downto 0);
		-- pwm irq
		o_PWM_INT	: out	std_logic_vector(15 downto 0);
		-- convert stars
		o_Conv_St	: out	std_logic_vector(15 downto 0);
		
		o_dead_time	: out	std_logic_vector(15 downto 0);
		o_index_val	: out	std_logic_vector(15 downto 0);
		o_sin_gain	: out	std_logic_vector(31 downto 0);
		o_sin_phase	: out	std_logic_vector(31 downto 0);
		o_RESflg	: out	std_logic_vector(31 downto 0);
		o_Ext_Flg	: out	std_logic_vector(31 downto 0);
		o_Flags		: out	std_logic_vector(31 downto 0);
		o_si_config0: out	std_logic_vector(31 downto 0);
		o_SI0		: out	std_logic_vector(31 downto 0);
		o_si_config1: out	std_logic_vector(31 downto 0);
		o_SI1		: out	std_logic_vector(31 downto 0);
		o_si_config2: out	std_logic_vector(31 downto 0);
		o_SI2		: out	std_logic_vector(31 downto 0);
		o_Si_Read	: out	std_logic_vector(2 downto 0);
		-- 
		i_PWM_Run	: in	std_logic := '0';
		-- triggers
		i_cADC_0	: in	std_logic := '0';
		i_cADC_180	: in	std_logic := '0';
		i_cCM		: in	std_logic := '0';
		i_cCM180	: in	std_logic := '0';
		i_cIntCnt	: in	std_logic := '0';
		i_cEncZP0	 : in	std_logic := '0';
		i_cEncZP1	 : in	std_logic := '0';
		i_cEncZP2	 : in	std_logic := '0';
		i_cPWM0		: in	std_logic := '0';
		i_cSI0		: in	std_logic := '0';
		i_cSI1		: in	std_logic := '0';
		i_cSI2		: in	std_logic := '0'
	);
end;


architecture behavior_dpr2SAC3x3Reg of dpr2SAC3x3Reg is
--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	: std_logic := '1';
	constant	L	: std_logic := '0';
	constant	Z	: std_logic := 'Z';
	-- outputs
	constant DF_rPWM0_ADDR	: std_logic_vector(8 downto 0) := "000000000";--BASE+0x0000
	constant DF_rPWM1_ADDR	: std_logic_vector(8 downto 0) := "000000001";--BASE+0x0010
	constant DF_rPWMC_ADDR	: std_logic_vector(8 downto 0) := "000010000";--BASE+0x0100
--	constant DF_rSPWM_ADDR	: std_logic_vector(8 downto 0) := "000100000";--BASE+0x0200
--	constant DF_rDAC_ADDR	: std_logic_vector(8 downto 0) := "000110000";--BASE+0x0300
	constant DF_rDOUT_ADDR	: std_logic_vector(8 downto 0) := "001000000";--BASE+0x0400
	constant DF_rSI0_ADDR	: std_logic_vector(8 downto 0) := "001010000";--BASE+0x0500
	constant DF_rSI1_ADDR	: std_logic_vector(8 downto 0) := "001010001";--BASE+0x0510
	-- indices
	constant DF_rPWM0_INDEX : integer := 0;
	constant DF_rPWM1_INDEX : integer := 1;
	constant DF_rPWMC_INDEX : integer := 2;
--	constant DF_rSPWM_INDEX : integer := 3;
	constant DF_rDOUT_INDEX : integer := 4;
--	constant DF_rDAC_INDEX : integer := 5;
	constant DF_rSI0_INDEX : integer := 3;
	constant DF_rSI1_INDEX : integer := 5;
	-- inputs
	constant DF_ADC0_0_ADDR	: std_logic_vector(8 downto 0) := "100000000";--BASE+0x1000
	constant DF_ADC1_0_ADDR	: std_logic_vector(8 downto 0) := "100000001";--BASE+0x1010
	constant DF_ADC0_180_ADDR: std_logic_vector(8 downto 0) := "100000010";--BASE+0x1020
	constant DF_ADC1_180_ADDR: std_logic_vector(8 downto 0) := "100000011";--BASE+0x1030
	constant DF_CM0_ADDR	: std_logic_vector(8 downto 0) := "100010000";--BASE+0x1100
	constant DF_CM1_ADDR	: std_logic_vector(8 downto 0) := "100010001";--BASE+0x1110
	constant DF_CM0_180_ADDR: std_logic_vector(8 downto 0) := "100010010";--BASE+0x1120
	constant DF_CM1_180_ADDR: std_logic_vector(8 downto 0) := "100010011";--BASE+0x1130
	constant DF_ENC_ADDR_01	: std_logic_vector(8 downto 0) := "100100000";--BASE+0x1200
	constant DF_ENC_ADDR_23	: std_logic_vector(8 downto 0) := "100100001";--BASE+0x1210
	constant DF_MISC_ADDR	: std_logic_vector(8 downto 0) := "100110000";--BASE+0x1300
	constant DF_SI0_ADDR	: std_logic_vector(8 downto 0) := "101010000";--BASE+0x1500
	constant DF_SI1_ADDR	: std_logic_vector(8 downto 0) := "101010001";--BASE+0x1510
	constant DF_SI2_ADDR	: std_logic_vector(8 downto 0) := "101010010";--BASE+0x1520
	-- indices
	constant DF_ADC0		: integer := 0;
	constant DF_ADC1		: integer := 1;
	constant DF_CM0			: integer := 2;
	constant DF_CM1			: integer := 3;
	constant DF_E_ZP01		: integer := 4;
	constant DF_E_ZP23		: integer := 5;
	constant DF_MISC		: integer := 6;
	constant DF_SI0			: integer := 7;
	constant DF_SI1			: integer := 8;
	constant DF_SI2			: integer := 9;
	-- types -------------------------------------------------------------------
	type t_state is (read_restart, rw_loop0, rw_loop1, rw_loop2, rw_loop3, rw_loop4, rw_loop5, rw_loop6, write);
	type tr_data	is array(0 to 5) of std_logic_vector(o_dprData'length-1 downto 0);
	type tw_data	is array(0 to 9) of std_logic_vector(o_dprData'length-1 downto 0);
	-- signal ------------------------------------------------------------------
	signal State		: t_state := read_restart;
	signal addr			: std_logic_vector(8 downto 0) := DF_rPWM0_ADDR;
	signal data_index	: std_logic_vector(3 downto 0) := (others=>L);
	signal r_data		: tr_data;
	signal w_data		: tw_data;
	signal PWMCntAtInt	: std_logic_vector(15 downto 0);
	signal EncoderZP0	: std_logic_vector(31 downto 0);
	signal EncoderZP1	: std_logic_vector(31 downto 0);
	signal EncoderZP2	: std_logic_vector(31 downto 0);
	signal PWMCntAtInt_PWM0	: std_logic_vector(15 downto 0);
	signal EncoderZP0_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP1_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP2_PWM0	: std_logic_vector(31 downto 0);
	signal ADCx0		: std_logic_vector(63 downto 0);
	signal ADCx1		: std_logic_vector(63 downto 0);
	signal ADCx0_180		: std_logic_vector(63 downto 0);
	signal ADCx1_180		: std_logic_vector(63 downto 0);
	
	signal cADC0_0		: std_logic := L;
	signal cADC0_180		: std_logic := L;
	signal cADC1_0		: std_logic := L;
	signal cADC1_180		: std_logic := L;
	signal cCM0			: std_logic := L;
	signal cCM0_180		: std_logic := L;
	signal cCM1			: std_logic := L;
	signal cCM1_180		: std_logic := L;
	signal cIntCnt		: std_logic := L;
	signal cEncoder		: std_logic := L;
	signal cPWM0		: std_logic := L;
	signal cSI0			: std_logic := L;
	signal cSI1			: std_logic := L;
	signal cSI2			: std_logic := L;
	
	

	signal GND16		: std_logic_vector(15 downto 0)	:= (others => L);

--------------------------------------------------------------------------------
begin

	o_PWM_U0 <= r_data(DF_rPWM0_INDEX)(127 downto 112);			-- 0x0000
	o_PWM_V0 <= r_data(DF_rPWM0_INDEX)(111 downto 96);			-- 0x0002
	o_PWM_W0 <= r_data(DF_rPWM0_INDEX)(95 downto 80);			-- 0x0004
	o_PWM_100 <= r_data(DF_rPWM0_INDEX)(79 downto 64);			-- 0x0006
	o_PWM_U1 <= r_data(DF_rPWM0_INDEX)(63 downto 48);			-- 0x0008
	o_PWM_V1 <= r_data(DF_rPWM0_INDEX)(47 downto 32);			-- 0x000A
	o_PWM_W1 <= r_data(DF_rPWM0_INDEX)(31 downto 16);			-- 0x000C
	-- <= r_data(DF_rPWM0_INDEX)(15 downto 0);					-- 0x000E
	
	o_PWM_U2 <= r_data(DF_rPWM1_INDEX)(127 downto 112);			-- 0x0010
	o_PWM_V2 <= r_data(DF_rPWM1_INDEX)(111 downto 96);			-- 0x0012
	o_PWM_W2 <= r_data(DF_rPWM1_INDEX)(95 downto 80);			-- 0x0014
	--       <= r_data(DF_rPWM1_INDEX)(79 downto 64);			-- 0x0016
	--       <= r_data(DF_rPWM1_INDEX)(63 downto 48);			-- 0x0018
	--       <= r_data(DF_rPWM1_INDEX)(47 downto 32);			-- 0x001A
	--       <= r_data(DF_rPWM1_INDEX)(31 downto 16);			-- 0x001C
	--       <= r_data(DF_rPWM1_INDEX)(15 downto 0);			-- 0x001E

	o_PWM_INT <= r_data(DF_rPWMC_INDEX)(127 downto 112);		-- 0x0100
	o_Conv_St <= r_data(DF_rPWMC_INDEX)(111 downto 96);			-- 0x0102
	o_dead_time <= r_data(DF_rPWMC_INDEX)(95 downto 80);		-- 0x0104
	o_index_val <= r_data(DF_rPWMC_INDEX)(79 downto 64);		-- 0x0106
	--		 <= r_data(DF_rPWMC_INDEX)(63 downto 48);			-- 0x0108
	--		 <= r_data(DF_rPWMC_INDEX)(47 downto 32);			-- 0x010A
	o_RESflg <= r_data(DF_rPWMC_INDEX)(31 downto 0);			-- 0x010C

	--		 <= r_data(DF_rSPWM_INDEX)(127 downto 112);			-- 0x0200
	--		 <= r_data(DF_rSPWM_INDEX)(111 downto 96);			-- 0x0202
	--		 <= r_data(DF_rSPWM_INDEX)(95 downto 80);			-- 0x0204
	--		 <= r_data(DF_rSPWM_INDEX)(79 downto 64);			-- 0x0206
	--		 <= r_data(DF_rSPWM_INDEX)(63 downto 32);			-- 0x0208
	--		 <= r_data(DF_rSPWM_INDEX)(31 downto 0);			-- 0x020C

	--		 <= r_data(DF_rDAC_INDEX)(127 downto 112);			-- 0x0300
	--		 <= r_data(DF_rDAC_INDEX)(111 downto 96);			-- 0x0302
	--		 <= r_data(DF_rDAC_INDEX)(95 downto 80);			-- 0x0304
	--		 <= r_data(DF_rDAC_INDEX)(79 downto 64);			-- 0x0306
	--		 <= r_data(DF_rDAC_INDEX)(63 downto 48);			-- 0x0308
	--		 <= r_data(DF_rDAC_INDEX)(47 downto 32);			-- 0x030A
	--		 <= r_data(DF_rDAC_INDEX)(31 downto  0);			-- 0x030C
	
	o_sin_gain		 <= r_data(DF_rDOUT_INDEX)(127 downto 96);	-- 0x0400
	o_sin_phase		 <= r_data(DF_rDOUT_INDEX)( 95 downto 64);	-- 0x0404
	o_Ext_Flg <= r_data(DF_rDOUT_INDEX)( 63 downto 32);			-- 0x0408
	o_Flags <= r_data(DF_rDOUT_INDEX)(31 downto 0); 			-- 0x040C
	
	o_si_config0 <= r_data(DF_rSI0_INDEX)(127 downto 96);		-- 0x0500
	o_SI0		 <= r_data(DF_rSI0_INDEX)( 95 downto 64);		-- 0x0504
	o_si_config1 <= r_data(DF_rSI0_INDEX)( 63 downto 32);		-- 0x0508
	o_SI1		 <= r_data(DF_rSI0_INDEX)( 31 downto  0);		-- 0x050c
	o_si_config2 <= r_data(DF_rSI1_INDEX)(127 downto 96);		-- 0x0510
	o_SI2		 <= r_data(DF_rSI1_INDEX)( 95 downto 64);		-- 0x0514

	--					0x0 & 0x2 & 0x4 & 0x6 & 0x8 & 0xA & 0xC & 0xE
	w_data(DF_ADC0) <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1 & i_ADCA2 & i_ADCB2 & i_ADCA3 & i_ADCB3;
	w_data(DF_ADC1) <= i_ADCA4 & i_ADCB4 & i_ADCA5 & i_ADCB5 & GND16 & GND16 & GND16 & GND16;
	
	w_data(DF_CM0) <= i_sdADC0 & i_sdADC1 & i_sdADC2 & i_sdADC3 & i_sdADC4 & i_sdADC5 & i_sdADC6 & i_sdADC7;
	w_data(DF_CM1) <= i_sdADC8 & i_sdADC9 & GND16 & GND16 & GND16 & GND16 & GND16 & GND16;
	
	w_data(DF_E_ZP01) <= EncoderZP0_PWM0 & i_Enc0 & GND16 & EncoderZP1_PWM0 & i_Enc1 & GND16;
	w_data(DF_E_ZP23) <= EncoderZP2_PWM0 & i_Enc2 & GND16 & GND16 & GND16 & GND16 & GND16;
	w_data(DF_MISC) <= GND16 & GND16 & i_ExtStatus & PWMCntAtInt_PWM0 & GND16 & i_Status;
	
	w_data(DF_SI0) <= i_SI0 & GND16 & GND16 & GND16 & GND16;
	w_data(DF_SI1) <= i_SI1 & GND16 & GND16 & GND16 & GND16;
	w_data(DF_SI2) <= i_SI2 & GND16 & GND16 & GND16 & GND16;

	dpr : process (i_Clk) begin
		if rising_edge(i_Clk) then
			o_dprWEN <= (others => L);
			o_Si_Read <= (others => L);
			-- hold trigger inputs
			cCM0 <= i_cCM or cCM0;
			cCM0_180 <= i_cCM180 or cCM0_180;
			cIntCnt <= i_cIntCnt or cIntCnt;
			cADC0_0 <= i_cADC_0 or cADC0_0;
			cADC0_180 <= i_cADC_180 or cADC0_180;
			cSI0 <= i_cSI0 or cSI0;
			cSI1 <= i_cSI1 or cSI1;
			cSI2 <= i_cSI2 or cSI2;
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
			if i_cPWM0=H then
				PWMCntAtInt_PWM0 <= PWMCntAtInt;
				EncoderZP0_PWM0 <= EncoderZP0;
				EncoderZP1_PWM0 <= EncoderZP1;
				EncoderZP2_PWM0 <= EncoderZP2;
				cPWM0 <= H;
			end if;
			case state is
				when read_restart =>
					addr <= DF_rPWM0_ADDR;
					state <= rw_loop0;
				when rw_loop0 =>
					addr <= DF_rPWM1_ADDR;
					state <= rw_loop1;
				when rw_loop1 =>
					addr <= DF_rPWMC_ADDR;
					r_data(DF_rPWM0_INDEX) <= i_dprData;
					state <= rw_loop2;
				when rw_loop2 =>
					addr <= DF_rDOUT_ADDR;
					r_data(DF_rPWM1_INDEX) <= i_dprData;
					state <= rw_loop3;
				when rw_loop3 =>
					addr <= DF_rSI0_ADDR;
					r_data(DF_rPWMC_INDEX) <= i_dprData;
					state <= rw_loop4;
				when rw_loop4 =>
					addr <= DF_rSI1_ADDR;
					r_data(DF_rDOUT_INDEX) <= i_dprData;
					state <= rw_loop5;
				when rw_loop5 =>
					addr <= DF_MISC_ADDR;
					data_index <= CONV_STD_LOGIC_VECTOR(DF_MISC,data_index'length);
					o_dprWEN <= (others => H);
					r_data(DF_rSI0_INDEX) <= i_dprData;
					o_Si_Read(0) <= H;
					o_Si_Read(1) <= H;
					state <= rw_loop6;
				when rw_loop6 =>
					addr <= DF_rPWM0_ADDR;
					r_data(DF_rSI1_INDEX) <= i_dprData;
					o_Si_Read(2) <= H;
					state <= write;
				when write =>
					-- w_data(ADC) 0° and 180°
					if (cADC0_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC0,data_index'length);
						addr <= DF_ADC0_0_ADDR;
						o_dprWEN <= (others => H);
						cADC0_0 <= L;
						cADC1_0 <= H;
					elsif (cADC1_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC1,data_index'length);
						addr <= DF_ADC1_0_ADDR;
						o_dprWEN <= (others => H);
						cADC1_0 <= L;
					elsif (cADC0_180=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC0,data_index'length);
						addr <= DF_ADC0_180_ADDR;
						o_dprWEN <= (others => H);
						cADC0_180 <= L;
						cADC1_180 <= H;
					elsif (cADC1_180=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC1,data_index'length);
						addr <= DF_ADC1_180_ADDR;
						o_dprWEN <= (others => H);
						cADC1_180 <= L;
					-- w_data(CM) 0°
					elsif cCM0=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM0,data_index'length);
						addr <= DF_CM0_ADDR;
						o_dprWEN <= (others => H);
						cCM0 <= L;
						cCM1 <= H;
					elsif cCM1=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM1,data_index'length);
						addr <= DF_CM1_ADDR;
						o_dprWEN <= (others => H);
						cCM1 <= L;
					-- w_data(CM) 180°
					elsif cCM0_180=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM0,data_index'length);
						addr <= DF_CM0_180_ADDR;
						o_dprWEN <= (others => H);
						cCM0_180 <= L;
						cCM1_180 <= H;
					elsif cCM1_180=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM1,data_index'length);
						addr <= DF_CM1_180_ADDR;
						o_dprWEN <= (others => H);
						cCM1_180 <= L;
					elsif cSI0=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI0,data_index'length);
						addr <= DF_SI0_ADDR;
						o_dprWEN <= (others => H);
						cSI0 <= L;
					elsif cSI1=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI1,data_index'length);
						addr <= DF_SI1_ADDR;
						o_dprWEN <= (others => H);
						cSI1 <= L;
					elsif cSI2=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SI2,data_index'length);
						addr <= DF_SI2_ADDR;
						o_dprWEN <= (others => H);
						cSI2 <= L;
					-- w_data(ENCODER_ZP)
					elsif cPWM0=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP01,data_index'length);
						addr <= DF_ENC_ADDR_01;
						o_dprWEN <= (others => H);
						cPWM0 <= L;
						cEncoder <= H;
					-- w_data(ENCODER)
					elsif cEncoder=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP23,data_index'length);
						addr <= DF_ENC_ADDR_23;
						o_dprWEN <= (others => H);
						cEncoder <= L;
						state <= read_restart;
					else
						if (i_PWM_Run=L) then -- read permanent
							state <= read_restart;
						end if;
					end if;
			end case;
			-- syncron reset
			if (i_Reset=H) then
				cADC0_0 <= L;
				cADC1_0 <= L;
				cADC0_180 <= L;
				cADC1_180 <= L;
				cCM0 <= L;
				cCM1 <= L;
				cCM0_180 <= L;
				cCM1_180 <= L;
				cIntCnt <= L;
				cEncoder <= L;
				cPWM0 <= L;
				cSI0 <= L;
				cSI1 <= L;
				cSI2 <= L;
				State <= read_restart;
			end if;
		end if;
	end process;

	mux : process (data_index,w_data)
	begin
		o_dprData<= w_data(conv_integer(data_index));
	end process;

	o_dprEN <= H;
	o_dprAddr <= addr;
	o_dprClk <= i_Clk;
	o_dprRst <= i_Reset;


end behavior_dpr2SAC3x3Reg;