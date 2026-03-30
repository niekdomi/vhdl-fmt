--------------------------------------------------------------------------------
--
--	dpr2MAX4Reg
--
--------------------------------------------------------------------------------
--
--	project		: INFO-MAX4
--	programmer	: C.Leuthold, INDEL	AG
--	date		: 16.09.2004
--	version		: 1.00a
--	language	: VHDL
--	system		: ISE /	EDK
--
--	purpose
--		copy registers from and to blockram
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--
--	22.04.2005-le: - adjustments for max4 (from dpr2SACReg	1.00b)
--	14.05.2007-le: - add svn keywords
--	03.11.2008-le: - add pulse pwm register
--	06.11.2008-le: - change to one pulse pwm and change register to 32 bit
--------------------------------------------------------------------------------
--$Rev:: 734                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-12 16:55:39 +0100 (Mi., 12 Nov 2008)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library	ieee;
use	IEEE.std_logic_1164.ALL;
use	IEEE.std_logic_unsigned.ALL;
use	IEEE.std_logic_arith.ALL;

entity dpr2MAX4Reg is
	port (
		--System
		i_Reset		: IN	std_logic;						-- Reset
		i_Clk		: IN	std_logic;						-- 66MHz
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
		i_ADCB0		: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB1		: in	std_logic_vector(15 downto 0) := (others => '0');
		-- current measurement
		i_cmPWM100_U0 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_U0 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_V0 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_V0 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_U1 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_U1 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_V1 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_V1 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_U2 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_U2 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_V2 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_V2 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_U3 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_U3 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWM100_V3 : in	std_logic_vector(15 downto 0) := (others => '0');
		i_cmPWMHigh_V3 : in	std_logic_vector(15 downto 0) := (others => '0');
		-- encoders
		i_Enc0	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc1	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc2	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Enc3	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_pulsator_pulsecnt : in std_logic_vector(31 downto 0) := (others => '0');
		-- misc
		i_PWMCnt	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Status	: in	std_logic_vector(31 downto 0) := (others => '0');
		i_digital_inputs: in	std_logic_vector(15 downto 0) := (others => '0');
		i_ext_board_in : in	std_logic_vector(15 downto 0) := (others => '0');
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
		o_PWM_U3	: out	std_logic_vector(15 downto 0);
		o_PWM_V3	: out	std_logic_vector(15 downto 0);
		o_PWM_W3	: out	std_logic_vector(15 downto 0);
		o_PWM_break	: out	std_logic_vector(15 downto 0);
		-- pwm 100%
		o_PWM_100	: out	std_logic_vector(15 downto 0);
		-- pwm irq
		o_PWM_INT	: out	std_logic_vector(15 downto 0);
		-- convert stars
		o_Conv_St	: out	std_logic_vector(15 downto 0);
		o_Conv_St2	: out	std_logic_vector(15 downto 0);

		o_PWM_0		: out	std_logic_vector(15 downto 0);
		o_PWM_1		: out	std_logic_vector(15 downto 0);
		o_PWM_100_01: out	std_logic_vector(15 downto 0);
		
		o_pulsator_freq_t : out	std_logic_vector(31 downto 0);
		o_pulsator_pulse_t : out	std_logic_vector(31 downto 0);
		o_pulsator_pulse_n : out	std_logic_vector(31 downto 0);

		o_RESflg	: out	std_logic_vector(31 downto 0);
		o_Flags		: out	std_logic_vector(31 downto 0);

		o_digital_outputs: out	std_logic_vector(15 downto 0);
		o_ext_board_out : out	std_logic_vector(7 downto 0);
		o_ADC_job	: out	std_logic_vector(15 downto 0);
		o_DAC0		: out	std_logic_vector(15 downto 0);
		o_DAC1		: out	std_logic_vector(15 downto 0);
		o_DAC2		: out	std_logic_vector(15 downto 0);
		o_DAC3		: out	std_logic_vector(15 downto 0);
		o_DAC_PD	: out	std_logic_vector(15 downto 0);
		o_dac_config: out	std_logic_vector(31 downto 0);
		
		i_PWM_Run	: in	std_logic := '0';
		-- triggers
		i_cADC_0	: in	std_logic := '0';
		i_cADC_180	: in	std_logic := '0';
		i_cCM		: in	std_logic := '0';
		i_cCM180	: in	std_logic := '0';
		i_cIntCnt	: in	std_logic := '0';
		i_cEncoderZP0 : in	std_logic := '0';
		i_cEncoderZP1 : in	std_logic := '0';
		i_cEncoderZP2 : in	std_logic := '0';
		i_cEncoderZP3 : in	std_logic := '0';
		i_cPWM0		: in	std_logic := '0';
		i_dac_addr	: in	std_logic_vector(3 downto 0) := (others => '0');
		i_dac_reread: in	std_logic := '0';
		o_dac_read_done : out std_logic
	);
end;


architecture behavior_dpr2MAX4Reg of dpr2MAX4Reg is
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
	constant DF_rSPWM_ADDR	: std_logic_vector(8 downto 0) := "000100000";--BASE+0x0200
	constant DF_rDAC_ADDR	: std_logic_vector(8 downto 0) := "000110000";--BASE+0x0300
	constant DF_rDOUT_ADDR	: std_logic_vector(8 downto 0) := "001000000";--BASE+0x0400
	constant DF_rPU_ADDR 	: std_logic_vector(8 downto 0) := "001010000";--BASE+0x0500
	
	constant DF_rPWM0_INDEX : integer := 0;
	constant DF_rPWM1_INDEX : integer := 1;
	constant DF_rPWMC_INDEX : integer := 2;
	constant DF_rSPWM_INDEX : integer := 3;
	constant DF_rDOUT_INDEX : integer := 4;
	constant DF_rDAC_INDEX : integer := 5;
	constant DF_rPU_INDEX : integer := 6;
	-- inputs
	constant DF_ADC_0_ADDR	: std_logic_vector(8 downto 0) := "100000000";--BASE+0x1000
	constant DF_ADC_180_ADDR: std_logic_vector(8 downto 0) := "100000010";--BASE+0x1020
	constant DF_CM_ADDR		: std_logic_vector(8 downto 0) := "100010000";--BASE+0x1100
	constant DF_CM2_ADDR	: std_logic_vector(8 downto 0) := "100010001";--BASE+0x1110
	constant DF_CM180_ADDR	: std_logic_vector(8 downto 0) := "100010010";--BASE+0x1120
	constant DF_CM2180_ADDR	: std_logic_vector(8 downto 0) := "100010011";--BASE+0x1130
	constant DF_ENC_ADDR_01	: std_logic_vector(8 downto 0) := "100100000";--BASE+0x1200
	constant DF_ENC_ADDR_23	: std_logic_vector(8 downto 0) := "100100001";--BASE+0x1210
	constant DF_MISC_ADDR	: std_logic_vector(8 downto 0) := "100110000";--BASE+0x1300
	constant DF_PULSE_ADDR	: std_logic_vector(8 downto 0) := "101010000";--BASE+0x1500
	-- indices
	constant DF_ADC			: integer := 0;
	constant DF_CM			: integer := 1;
	constant DF_CM2			: integer := 2;
	constant DF_E_ZP01		: integer := 3;
	constant DF_E_ZP23		: integer := 4;
	constant DF_MISC		: integer := 5;
	constant DF_ADC_180		: integer := 6;
	constant DF_PULSE		: integer := 7;

	-- types -------------------------------------------------------------------
	type t_state is (read_restart, rw_loop0, rw_loop1, rw_loop2, rw_loop3, rw_loop4, rw_loop5, rw_loop6, rw_loop7, write, reread_DAC);
	type tr_data	is array(0 to 6) of std_logic_vector(o_dprData'length-1 downto 0);
	type tw_data	is array(0 to 7) of std_logic_vector(o_dprData'length-1 downto 0);
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
	signal EncoderZP3	: std_logic_vector(31 downto 0);
	signal PWMCntAtInt_PWM0	: std_logic_vector(15 downto 0);
	signal EncoderZP0_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP1_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP2_PWM0	: std_logic_vector(31 downto 0);
	signal EncoderZP3_PWM0	: std_logic_vector(31 downto 0);
	signal ADCx0		: std_logic_vector(63 downto 0);
	signal ADCx1		: std_logic_vector(63 downto 0);
	signal ADCx0_180		: std_logic_vector(63 downto 0);
	signal ADCx1_180		: std_logic_vector(63 downto 0);
	
	signal cADC_0		: std_logic := L;
	signal cADC_180		: std_logic := L;
	signal cCM			: std_logic := L;
	signal cCM180		: std_logic := L;
	signal cCM2			: std_logic := L;
	signal cCM2180		: std_logic := L;
	signal cIntCnt		: std_logic := L;
	signal cEncoder		: std_logic := L;
	signal cPWM0		: std_logic := L;
	signal read_DAC		: std_logic := L;
	signal cPulse		: std_logic := L;

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
	o_PWM_U3 <= r_data(DF_rPWM1_INDEX)(63 downto 48);			-- 0x0018
	o_PWM_V3 <= r_data(DF_rPWM1_INDEX)(47 downto 32);			-- 0x001A
	o_PWM_W3 <= r_data(DF_rPWM1_INDEX)(31 downto 16);			-- 0x001C
	--       <= r_data(DF_rPWM1_INDEX)(15 downto 0);			-- 0x001E

	o_PWM_INT <= r_data(DF_rPWMC_INDEX)(127 downto 112);		-- 0x0100
	o_Conv_St <= r_data(DF_rPWMC_INDEX)(111 downto 96);			-- 0x0102
	--		 <= r_data(DF_rPWMC_INDEX)(95 downto 80);			-- 0x0104
	--		 <= r_data(DF_rPWMC_INDEX)(79 downto 64);			-- 0x0106
	--		 <= r_data(DF_rPWMC_INDEX)(63 downto 48);			-- 0x0108
	o_Conv_St2 <= r_data(DF_rPWMC_INDEX)(47 downto 32);			-- 0x010A
	o_RESflg <= r_data(DF_rPWMC_INDEX)(31 downto 0);			-- 0x010C

	o_PWM_0 <= r_data(DF_rSPWM_INDEX)(127 downto 112);			-- 0x0200
	o_PWM_1 <= r_data(DF_rSPWM_INDEX)(111 downto 96);			-- 0x0202
	o_PWM_break <= r_data(DF_rSPWM_INDEX)(95 downto 80);		-- 0x0204
	o_PWM_100_01 <= r_data(DF_rSPWM_INDEX)(79 downto 64);		-- 0x0206
	--		 <= r_data(DF_rSPWM_INDEX)(63 downto 32);			-- 0x0208
	--		 <= r_data(DF_rSPWM_INDEX)(31 downto 0);			-- 0x020C

	o_DAC_PD <= r_data(DF_rDAC_INDEX)(127 downto 112);			-- 0x0300
	o_DAC0 <= r_data(DF_rDAC_INDEX)(111 downto 96);				-- 0x0302
	o_DAC1 <= r_data(DF_rDAC_INDEX)(95 downto 80);				-- 0x0304
	o_DAC2 <= r_data(DF_rDAC_INDEX)(79 downto 64);				-- 0x0306
	o_DAC3 <= r_data(DF_rDAC_INDEX)(63 downto 48);				-- 0x0308
	--	 <= r_data(DF_rDAC_INDEX)(47 downto 32);				-- 0x030A
	o_dac_config <= r_data(DF_rDAC_INDEX)(31 downto  0);		-- 0x030C
	
	
	o_digital_outputs <= r_data(DF_rDOUT_INDEX)(127 downto 112);-- 0x0400
	--	 <= r_data(DF_rDOUT_INDEX)(111 downto 96);				-- 0x0402
	--	8bit <= r_data(DF_rDOUT_INDEX)(95 downto 88);			-- 0x0403
	o_ext_board_out <= r_data(DF_rDOUT_INDEX)(87 downto 80);	-- 0x0404
	--	 <= r_data(DF_rDOUT_INDEX)(79 downto 64);				-- 0x0406
	o_ADC_job <= r_data(DF_rDOUT_INDEX)(63 downto 48);			-- 0x0408
	--	 <= r_data(DF_rDOUT_INDEX)(47 downto 32);				-- 0x040A
	o_Flags <= r_data(DF_rDOUT_INDEX)(31 downto 0); 			-- 0x040C
	
	o_pulsator_freq_t <= r_data(DF_rPU_INDEX)(127 downto 96);	-- 0x0500
	o_pulsator_pulse_t <= r_data(DF_rPU_INDEX)(95 downto 64);	-- 0x0504
	o_pulsator_pulse_n <= r_data(DF_rPU_INDEX)(63 downto 32);	-- 0x0508
	--			 <= r_data(DF_rPU_INDEX)(47 downto 32);			-- 0x050A
	--			 <= r_data(DF_rPU_INDEX)(31 downto 16);			-- 0x050C
	--			<= r_data(DF_rPU_INDEX)(15 downto 0);			-- 0x050E

	--					0x0 & 0x2 & 0x4 & 0x6 & 0x8 & 0xA & 0xC & 0xE
	w_data(DF_ADC) <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1 & GND16 & GND16 & GND16 & GND16;
	w_data(DF_ADC_180) <= GND16 & GND16 & GND16 & GND16 & i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1;
	w_data(DF_CM) <= i_cmPWM100_U0 & i_cmPWMHigh_U0 & i_cmPWM100_V0 & i_cmPWMHigh_V0 & i_cmPWM100_U1 & i_cmPWMHigh_U1 & i_cmPWM100_V1 & i_cmPWMHigh_V1;
	w_data(DF_CM2) <= i_cmPWM100_U2 & i_cmPWMHigh_U2 & i_cmPWM100_V2 & i_cmPWMHigh_V2 & i_cmPWM100_U3 & i_cmPWMHigh_U3 & i_cmPWM100_V3 & i_cmPWMHigh_V3;
	w_data(DF_E_ZP01) <= EncoderZP0_PWM0 & i_Enc0 & GND16 & EncoderZP1_PWM0 & i_Enc1 & GND16;
	w_data(DF_E_ZP23) <= EncoderZP2_PWM0 & i_Enc2 & GND16 & EncoderZP3_PWM0 & i_Enc3 & GND16;
	w_data(DF_PULSE) <= i_pulsator_pulsecnt & GND16 & GND16 & GND16 & GND16 & GND16 & GND16;
	
	w_data(DF_MISC) <= i_digital_inputs & GND16 & i_ext_board_in & GND16 & PWMCntAtInt_PWM0 & GND16 & i_Status;

	dpr : process (i_Clk) begin
		if rising_edge(i_Clk) then
			o_dprWEN <= (others => L);
			o_dac_read_done <= L;
			-- hold trigger inputs
			cCM <= i_cCM or cCM;
			cCM180 <= i_cCM180 or cCM180;
			cIntCnt <= i_cIntCnt or cIntCnt;
			cADC_0 <= i_cADC_0 or cADC_0;
			cADC_180 <= i_cADC_180 or cADC_180;
			read_DAC <= read_DAC or i_dac_reread;
			if (i_cIntCnt=L and cIntCnt=H) then
				PWMCntAtInt <= i_PWMCnt;
				cIntCnt <= L;
			end if;
			if i_cEncoderZP0=H then
				EncoderZP0 <= i_Enc0 & i_PWMCnt;
			end if;
			if i_cEncoderZP1=H then
				EncoderZP1 <= i_Enc1 & i_PWMCnt;
			end if;
			if i_cEncoderZP2=H then
				EncoderZP2 <= i_Enc2 & i_PWMCnt;
			end if;
			if i_cEncoderZP3=H then
				EncoderZP3 <= i_Enc3 & i_PWMCnt;
			end if;
			if i_cPWM0=H then
				PWMCntAtInt_PWM0 <= PWMCntAtInt;
				EncoderZP0_PWM0 <= EncoderZP0;
				EncoderZP1_PWM0 <= EncoderZP1;
				EncoderZP2_PWM0 <= EncoderZP2;
				EncoderZP3_PWM0 <= EncoderZP3;
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
					addr <= DF_rSPWM_ADDR;
					r_data(DF_rPWM1_INDEX) <= i_dprData;
					state <= rw_loop3;
				when rw_loop3 =>
					addr <= DF_rPU_ADDR;
					r_data(DF_rPWMC_INDEX) <= i_dprData;
					state <= rw_loop4;
				when rw_loop4 =>
					addr <= DF_rDOUT_ADDR;
					r_data(DF_rSPWM_INDEX) <= i_dprData;
					state <= rw_loop5;
				when rw_loop5 =>
					addr <= DF_rDAC_ADDR(8 downto 4) & i_dac_addr;
					r_data(DF_rPU_INDEX) <= i_dprData;
					state <= rw_loop6;
				when rw_loop6 =>
					addr <= DF_MISC_ADDR;
					data_index <= CONV_STD_LOGIC_VECTOR(DF_MISC,data_index'length);
					o_dprWEN <= (others => H);
					r_data(DF_rDOUT_INDEX) <= i_dprData;
					state <= rw_loop7;
				when rw_loop7 =>
					addr <= DF_rPWM0_ADDR;
					r_data(DF_rDAC_INDEX) <= i_dprData;
					o_dac_read_done <= H;
					read_DAC <= L;
					state <= write;
				when reread_DAC =>
					state <= rw_loop7;
				when write =>
					-- w_data(ADC) 0° and 180°
					if (cADC_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC,data_index'length);
						addr <= DF_ADC_0_ADDR;
						o_dprWEN <= (others => H);
						cADC_0 <= L;
					elsif (cADC_180=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC_180,data_index'length);
						addr <= DF_ADC_180_ADDR;
						o_dprWEN <= (others => H);
						cADC_180 <= L;
					-- w_data(CM) 0°
					elsif cCM=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM,data_index'length);
						addr <= DF_CM_ADDR;
						o_dprWEN <= (others => H);
						cCM <= L;
						cCM2 <= H;
					elsif cCM2=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM2,data_index'length);
						addr <= DF_CM2_ADDR;
						o_dprWEN <= (others => H);
						cCM2 <= L;
					-- w_data(CM) 180°
					elsif cCM180=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM,data_index'length);
						addr <= DF_CM180_ADDR;
						o_dprWEN <= (others => H);
						cCM180 <= L;
						cCM2180 <= H;
					elsif cCM2180=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM2,data_index'length);
						addr <= DF_CM2180_ADDR;
						o_dprWEN <= (others => H);
						cCM2180 <= L;
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
						cPulse <= H;
					elsif cPulse=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_PULSE,data_index'length);
						addr <= DF_PULSE_ADDR;
						o_dprWEN <= (others => H);
						cPulse <= L;
						state <= read_restart;
					else
						if (i_PWM_Run=L) then -- read permanent
							state <= read_restart;
						elsif (read_DAC=H) then
							state <= reread_DAC;
							addr <= DF_rDAC_ADDR(8 downto 4) & i_dac_addr;
						end if;
					end if;
			end case;
			-- syncron reset
			if (i_Reset=H) then
				cADC_0 <= L;
				cADC_180 <= L;
				cCM <= L;
				cCM2 <= L;
				cIntCnt <= L;
				cEncoder <= L;
				cCM180 <= L;
				cCM2180 <= L;
				cPWM0 <= L;
				read_DAC <= L;
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


end behavior_dpr2MAX4Reg;







