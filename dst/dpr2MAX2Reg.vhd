--------------------------------------------------------------------------------
--
--	dpr2MAX2Reg
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
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--
--	Rev. 1.00a	;	22.04.2005-le :	- adjustments for max4 (from dpr2SACReg	1.00b)
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
----- includes -----------------------------------------------------------------
--------------------------------------------------------------------------------

library	ieee;
use	IEEE.std_logic_1164.ALL;
use	IEEE.std_logic_unsigned.ALL;
use	IEEE.std_logic_arith.ALL;

entity dpr2MAX2Reg is
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
		i_ADCA0		: in	std_logic_vector(15 downto 0);
		i_ADCA1		: in	std_logic_vector(15 downto 0);
		i_ADCB0		: in	std_logic_vector(15 downto 0);
		i_ADCB1		: in	std_logic_vector(15 downto 0);
		-- current measurement
		i_cmPWM100_U0 : in	std_logic_vector(15 downto 0);
		i_cmPWMHigh_U0 : in	std_logic_vector(15 downto 0);
		i_cmPWM100_V0 : in	std_logic_vector(15 downto 0);
		i_cmPWMHigh_V0 : in	std_logic_vector(15 downto 0);
		i_cmPWM100_U1 : in	std_logic_vector(15 downto 0);
		i_cmPWMHigh_U1 : in	std_logic_vector(15 downto 0);
		i_cmPWM100_V1 : in	std_logic_vector(15 downto 0);
		i_cmPWMHigh_V1 : in	std_logic_vector(15 downto 0);
		-- encoders
		i_Enc0	: in	std_logic_vector(15 downto 0);
		i_Enc1	: in	std_logic_vector(15 downto 0);
		i_Enc2	: in	std_logic_vector(15 downto 0);
		i_Enc3	: in	std_logic_vector(15 downto 0);
		-- misc
		i_PWMCnt	: in	std_logic_vector(15 downto 0);
		i_Status	: in	std_logic_vector(31 downto 0);
		i_digital_inputs: in	std_logic_vector(15 downto 0);
		i_ext_board_in : in	std_logic_vector(15 downto 0);
		-- outputs
		-- pwm
		o_PWM_U0	: out	std_logic_vector(15 downto 0);
		o_PWM_V0	: out	std_logic_vector(15 downto 0);
		o_PWM_W0	: out	std_logic_vector(15 downto 0);
		o_PWM_U1	: out	std_logic_vector(15 downto 0);
		o_PWM_V1	: out	std_logic_vector(15 downto 0);
		o_PWM_W1	: out	std_logic_vector(15 downto 0);
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

		i_conv_0_n_180: in	std_logic;
		-- triggers
		i_cADCx0	: in	std_logic;
		i_cADCx1	: in	std_logic;
		i_cCM		: in	std_logic;
		i_cCM180	: in	std_logic;
		i_cIntCnt	: in	std_logic;
		i_cEncoderZP0 : in	std_logic;
		i_cEncoderZP1 : in	std_logic;
		i_cEncoderZP2 : in	std_logic;
		i_cEncoderZP3 : in	std_logic;
		i_cPWM0		: in	std_logic
	);
end;


architecture behavior_dpr2MAX2Reg of dpr2MAX2Reg is
--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	: std_logic := '1';
	constant	L	: std_logic := '0';
	constant	Z	: std_logic := 'Z';
	-- outputs
	constant DF_rD0_ADDR	: std_logic_vector(8 downto 0) := "000000000";--BASE+0x0000
	constant DF_rD1_ADDR	: std_logic_vector(8 downto 0) := "000010000";--BASE+0x0100
	constant DF_rD2_ADDR	: std_logic_vector(8 downto 0) := "000100000";--BASE+0x0200
	constant DF_rD3_ADDR	: std_logic_vector(8 downto 0) := "000110000";--BASE+0x0300
	constant DF_rD4_ADDR	: std_logic_vector(8 downto 0) := "001000000";--BASE+0x0400
	-- inputs
	constant DF_ADC_0_ADDR	: std_logic_vector(8 downto 0) := "100000000";--BASE+0x1000
	constant DF_ADC_180_ADDR: std_logic_vector(8 downto 0) := "100000010";--BASE+0x1020
	constant DF_CM_ADDR		: std_logic_vector(8 downto 0) := "100010000";--BASE+0x1100
	constant DF_CM180_ADDR	: std_logic_vector(8 downto 0) := "100010010";--BASE+0x1120
	constant DF_ENC_ADDR_01	: std_logic_vector(8 downto 0) := "100100000";--BASE+0x1200
	constant DF_ENC_ADDR_23	: std_logic_vector(8 downto 0) := "100100001";--BASE+0x1210
	constant DF_MISC_ADDR	: std_logic_vector(8 downto 0) := "100110000";--BASE+0x1300
	-- indices
	constant DF_ADC			: integer := 0;
	constant DF_CM			: integer := 1;
	constant DF_E_ZP01		: integer := 2;
	constant DF_E_ZP23		: integer := 3;
	constant DF_MISC		: integer := 4;
	constant DF_ADC_180		: integer := 5;

	-- types -------------------------------------------------------------------
	--type t_state is (idle, write_adc,	write_one);
	type t_state is (read_restart, rw_loop, write);
	type tr_data	is array(0 to 4) of std_logic_vector(o_dprData'length-1 downto 0);
	type tw_data	is array(0 to 5) of std_logic_vector(o_dprData'length-1 downto 0);
	-- signal ------------------------------------------------------------------
	signal State		: t_state := read_restart;
	signal addr			: std_logic_vector(8 downto 0) := DF_rD0_ADDR;
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
	signal PWMCntAtADCx0_0	: std_logic_vector(15 downto 0);
	signal PWMCntAtADCx1_0	: std_logic_vector(15 downto 0);
	signal PWMCntAtADCx0_180	: std_logic_vector(15 downto 0);
	signal PWMCntAtADCx1_180	: std_logic_vector(15 downto 0);
	
	signal cADCx0		: std_logic := L;
	signal cADCx1		: std_logic := L;
	signal cADC_180		: std_logic := L;
	signal cCM			: std_logic := L;
	signal cCM180		: std_logic := L;
	signal cIntCnt		: std_logic := L;
	signal cEncoder		: std_logic := L;
	signal cPWM0		: std_logic := L;

	signal GND16		: std_logic_vector(15 downto 0)	:= (others => L);

--------------------------------------------------------------------------------
begin

	o_PWM_U0 <= r_data(0)(127 downto 112);			-- 0x0000
	o_PWM_V0 <= r_data(0)(111 downto 96);			-- 0x0002
	o_PWM_W0 <= r_data(0)(95 downto 80);			-- 0x0004
	o_PWM_100 <= r_data(0)(79 downto 64);			-- 0x0006
	o_PWM_U1 <= r_data(0)(63 downto 48);			-- 0x0008
	o_PWM_V1 <= r_data(0)(47 downto 32);			-- 0x000A
	o_PWM_W1 <= r_data(0)(31 downto 16);			-- 0x000C
	-- <= r_data(0)(15 downto 0);			-- 0x000E

	o_PWM_INT <= r_data(1)(127 downto 112);			-- 0x0100
	o_Conv_St <= r_data(1)(111 downto 96);			-- 0x0102
	-- <= r_data(1)(95 downto 80);			-- 0x0104
	-- <= r_data(1)(79 downto 64);			-- 0x0106
	-- <= r_data(1)(63 downto 48);			-- 0x0108
	o_Conv_St2 <= r_data(1)(47 downto 32);			-- 0x010A
	o_RESflg <= r_data(1)(31 downto 0);				-- 0x010C

	o_PWM_0 <= r_data(2)(127 downto 112);			-- 0x0200
	o_PWM_1 <= r_data(2)(111 downto 96);			-- 0x0202
	o_PWM_break <= r_data(2)(95 downto 80);			-- 0x0204
	o_PWM_100_01 <= r_data(2)(79 downto 64);		-- 0x0206
	-- <= r_data(2)(63 downto 32);				-- 0x0208
	-- <= r_data(2)(31 downto 0);				-- 0x020C

	o_DAC_PD <= r_data(3)(127 downto 112);			-- 0x0300
	o_DAC0 <= r_data(3)(111 downto 96);				-- 0x0302
	o_DAC1 <= r_data(3)(95 downto 80);				-- 0x0304
	o_DAC2 <= r_data(3)(79 downto 64);				-- 0x0306
	o_DAC3 <= r_data(3)(63 downto 48);				-- 0x0308
	-- <= r_data(3)(47 downto 32);				-- 0x030A
	-- <= r_data(3)(31 downto 16);				-- 0x030C
	-- <= r_data(3)(15 downto 0);				-- 0x030E
	
	o_digital_outputs <= r_data(4)(127 downto 112);	-- 0x0400
	-- <= r_data(3)(111 downto 96);				-- 0x0402
	--8bit <= r_data(4)(95 downto 88);			-- 0x0403
	o_ext_board_out <= r_data(4)(87 downto 80);		-- 0x0404
	-- <= r_data(4)(79 downto 64);				-- 0x0406
	o_ADC_job <= r_data(4)(63 downto 48);			-- 0x0408
	-- <= r_data(4)(47 downto 32);				-- 0x040A
	o_Flags <= r_data(4)(31 downto 0); 				-- 0x040C

	--					0x0 & 0x2 & 0x4 & 0x6 & 0x8 & 0xA & 0xC & 0xE
	w_data(DF_ADC) <= ADCx0 & ADCx1;
	w_data(DF_ADC_180) <= ADCx0_180 & ADCx1_180;
	w_data(DF_CM) <= i_cmPWM100_U0 & i_cmPWMHigh_U0 & i_cmPWM100_V0 & i_cmPWMHigh_V0 & i_cmPWM100_U1 & i_cmPWMHigh_U1 & i_cmPWM100_V1 & i_cmPWMHigh_V1;
	--w_data(DF_E_ZP01) <= EncoderZP0_PWM0 & i_Enc0 & GND16 & EncoderZP1_PWM0 & i_Enc1 & GND16;
	--w_data(DF_E_ZP23) <= EncoderZP2_PWM0 & i_Enc2 & GND16 & EncoderZP3_PWM0 & i_Enc3 & GND16;
	w_data(DF_E_ZP01) <= EncoderZP0_PWM0 & i_Enc0 & PWMCntAtADCx0_0 & EncoderZP1_PWM0 & i_Enc1 & PWMCntAtADCx0_180;
	w_data(DF_E_ZP23) <= EncoderZP2_PWM0 & i_Enc2 & PWMCntAtADCx1_0 & EncoderZP3_PWM0 & i_Enc3 & PWMCntAtADCx1_180;
	w_data(DF_MISC) <= i_digital_inputs & GND16 & i_ext_board_in & GND16 & PWMCntAtInt_PWM0 & GND16 & i_Status;

	dpr : process (i_Clk) begin
		if rising_edge(i_Clk) then
			o_dprWEN <= (others => L);
			-- hold	trigger inputs
			cCM <= i_cCM or cCM;
			cCM180 <= i_cCM180 or cCM180;
			cIntCnt <= i_cIntCnt or cIntCnt;
			if (i_cIntCnt=L and cIntCnt=H) then
				PWMCntAtInt <= i_PWMCnt;
				cIntCnt <= L;
			end if;
			if i_cADCx0=H then
				if (i_conv_0_n_180=H) then
					PWMCntAtADCx0_0 <= i_PWMCnt;
					ADCx0 <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1;
					cADCx0 <= H;
				else
					PWMCntAtADCx0_180 <= i_PWMCnt;
					ADCx0_180 <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1;
				end if;
			end if;
			if i_cADCx1=H then
				if (i_conv_0_n_180=H) then
					PWMCntAtADCx1_0 <= i_PWMCnt;
					ADCx1 <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1;
					cADCx1 <= H;
				else
					PWMCntAtADCx1_180 <= i_PWMCnt;
					ADCx1_180 <= i_ADCA0 & i_ADCB0 & i_ADCA1 & i_ADCB1;
				end if;
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
					addr <= DF_rD0_ADDR;
					state <= rw_loop;
				when rw_loop =>
					if addr=DF_rD0_ADDR	then
						addr <= DF_rD1_ADDR;
					elsif addr=DF_rD1_ADDR then
						addr <= DF_rD2_ADDR;
						r_data(0) <= i_dprData;
					elsif addr=DF_rD2_ADDR then
						addr <= DF_rD3_ADDR;
						r_data(1) <= i_dprData;
					elsif addr=DF_rD3_ADDR then
						addr <= DF_rD4_ADDR;
						r_data(2) <= i_dprData;
					elsif addr=DF_rD4_ADDR then
						addr <= DF_MISC_ADDR;
						data_index <= CONV_STD_LOGIC_VECTOR(DF_MISC,data_index'length);
						o_dprWEN <= (others => H);
						r_data(3) <= i_dprData;
					elsif addr=DF_MISC_ADDR then
						addr <= DF_rD0_ADDR;
						r_data(4) <= i_dprData;
						state <= write;
					else
						-- r/w periodical interrupted!
						state <= read_restart;
					end if;
				when write =>
					-- w_data(ADC) 0° and 180°
					if (cADCx0=H or cADCx1=H) then	-- write to dpr
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC,data_index'length);
						addr <= DF_ADC_0_ADDR;
						o_dprWEN <= (others => H);
						cADCx0 <= L;
						cADCx1 <= L;
						cADC_180 <= H;
						--state <= read_restart;
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
						state <= read_restart;
					-- w_data(CM) 180°
					elsif cCM180=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_CM,data_index'length);
						addr <= DF_CM180_ADDR;
						o_dprWEN <= (others => H);
						cCM180 <= L;
						state <= read_restart;
					-- w_data(ENCODER_ZP)
					elsif cPWM0=H then		-- write to	dpr
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP01,data_index'length);
						addr <= DF_ENC_ADDR_01;
						o_dprWEN <= (others => H);
						cPWM0 <= L;
						cEncoder <= H;
						--state <= read_restart;
					-- w_data(ENCODER)
					elsif cEncoder=H then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_E_ZP23,data_index'length);
						addr <= DF_ENC_ADDR_23;
						o_dprWEN <= (others => H);
						cEncoder <= L;
						state <= read_restart;
					else
						state <= rw_loop;
					end if;
			end case;
			-- syncron reset
			if i_Reset=H then
				cADCx0 <= L;
				cADCx1 <= L;
				cADC_180 <= L;
				cCM <= L;
				cIntCnt <= L;
				cEncoder <= L;
				cCM180 <= L;
				cPWM0 <= L;
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


end behavior_dpr2MAX2Reg;







