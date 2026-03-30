--------------------------------------------------------------------------------
--
--  dpr2SACReg
--
--------------------------------------------------------------------------------
--
--  project     : INFO-SAC2
--  programmer  : C.Leuthold, INDEL AG
--  date        : 16.09.2004
--  version     : 1.00a
--  language    : VHDL
--  system      : ISE / EDK
--
--  purpose
--	copy sac registers from and to blockram
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--
--  Rev. 1.00a  ;   16.09.2004-le : - origin
--  Rev. 1.00b  ;   04.01.2005-le : - startup problems seq. hang-up
--  Rev. 1.00c  ;   04.01.2005-le : - add i_cSCI_ZP and save SCI_cnt on i_cSCI_ZP and on i_cEncoderZP
--					02.09.2005-le : - change IncCnt and SinCos to 12 bit
--									- add i_IncZPcnt, i_SinCosZPcnt and i_SinCosRef
--					15.09.2005-le : - add PWMcntAtIncZP
--					19.10.2006-le : - add default values at some inputs
--	01.12.2006-le : remove o_outputs (same as o_RESflg) 
--	20.12.2006-le : change register for endat/ssi rx-data (i_EndatSSI) and
--					move it to addr 0x70002018/1C
--	14.05.2007-le	add svn keywords
--	21.07.2009-le: - add o_Si_Read (H pulse when si config reg is read)
--------------------------------------------------------------------------------
--$Rev:: 1138                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-07-21 14:54:10 +0200 (Di., 21 Jul 2009)                         $
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
----- includes -----------------------------------------------------------------
--------------------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
----- defines ------------------------------------------------------------------
--------------------------------------------------------------------------------

entity dpr2SACReg is
	--generic (
	--	C_IMPL_SD2_REG : integer := 0
	--);
	port (
		--System
		i_Reset     : IN    std_logic;                      -- Reset
		i_Clk       : IN    std_logic;                      -- 66MHz
		-- Dualport Ram access
		o_dprEN     : OUT   std_logic;
		o_dprClk    : OUT   std_logic;
		o_dprRst    : OUT   std_logic;
		o_dprWEN    : OUT   std_logic_vector(3 downto 0);
		o_dprData   : out   STD_LOGIC_VECTOR(31 downto 0);
		i_dprData   : in    STD_LOGIC_VECTOR(31 downto 0);
		o_dprAddr   : OUT   std_logic_vector(10 downto 0);  -- DP-RAM Adr
		-- SAC Register
		i_ADCA0     : in    std_logic_vector(15 downto 0) := (others => L);
		i_ADCA1     : in    std_logic_vector(15 downto 0) := (others => L);
		i_ADCB0     : in    std_logic_vector(15 downto 0) := (others => L);
		i_ADCB1     : in    std_logic_vector(15 downto 0) := (others => L);
		i_SD0       : in    std_logic_vector(15 downto 0) := (others => L);
		i_SD1       : in    std_logic_vector(15 downto 0) := (others => L);
		i_SD2       : in    std_logic_vector(15 downto 0) := (others => L);
		i_SD3       : in    std_logic_vector(15 downto 0) := (others => L);
		i_EndatSSI  : in    std_logic_vector(63 downto 0) := (others => L);
		i_Status    : in    std_logic_vector(31 downto 0);
		i_SSI       : in    std_logic_vector(31 downto 0) := (others => L);
		i_PWMCnt    : in    std_logic_vector(15 downto 0);
		i_IncEnc    : in    std_logic_vector(11 downto 0);
		i_SinCos    : in    std_logic_vector(11 downto 0);
		i_IncZPcnt  : in    std_logic_vector(3 downto 0);
		i_SinCosZPcnt : in    std_logic_vector(3 downto 0);
		i_SinCosRef : in    std_logic;

		o_PWM_U     : out   std_logic_vector(15 downto 0);
		o_PWM_V     : out   std_logic_vector(15 downto 0);
		o_PWM_W     : out   std_logic_vector(15 downto 0);
		o_PWM_100   : out   std_logic_vector(15 downto 0);
		o_PWM_INT   : out   std_logic_vector(15 downto 0);
		o_Conv_St   : out   std_logic_vector(15 downto 0);
		o_Conv_St2  : out   std_logic_vector(15 downto 0);
		o_dead_time : out   std_logic_vector(15 downto 0);
		o_index_val : out   std_logic_vector(15 downto 0);
		o_SIN_phase : out   std_logic_vector(15 downto 0);
		o_RESflg    : out   std_logic_vector(31 downto 0);
		o_Flags     : out   std_logic_vector(31 downto 0);
		o_si_config : out   std_logic_vector(31 downto 0);
		o_Endat     : out    std_logic_vector(31 downto 0);
		o_Si_Read   : out    std_logic_vector(0 downto 0);
		-- adc inversOrder
		i_invertOrder0: in  std_logic;
		i_invertOrder1: in  std_logic;
		--
		i_conv_0_n_180: in  std_logic;
		-- triggers
		i_cADCx0    : in    std_logic;
		i_cADCx1    : in    std_logic;
		i_cSSI      : in    std_logic;
		i_cSD       : in    std_logic;
		i_cSD180    : in    std_logic;
		i_cIntCnt   : in    std_logic;
		i_cEncoderZP: in    std_logic;
		i_cSCI_ZP   : in    std_logic;
		i_cEncoder  : in    std_logic;
		i_cSaveCounters : in    std_logic;
		i_cEndatSSI : in    std_logic
		);
end;


architecture behavior_dpr2SACReg of dpr2SACReg is
--------------------------------------------------------------------------------
--  Constants
--------------------------------------------------------------------------------
	constant DF_rD0_ADDR    : std_logic_vector(5 downto 0) := "000000";
	constant DF_rD1_ADDR    : std_logic_vector(5 downto 0) := "000001";
	constant DF_rD2_ADDR    : std_logic_vector(5 downto 0) := "000010";
	constant DF_rD3_ADDR    : std_logic_vector(5 downto 0) := "000011";
	constant DF_rD4_ADDR    : std_logic_vector(5 downto 0) := "000100";
	constant DF_rD5_ADDR    : std_logic_vector(5 downto 0) := "001000";-- RESflg (o_Outputs, o_RESflg)
	constant DF_rD6_ADDR    : std_logic_vector(5 downto 0) := "001011";-- FLG    (o_Flags)
	constant DF_rD7_ADDR    : std_logic_vector(5 downto 0) := "000101";
	constant DF_rD8_ADDR    : std_logic_vector(5 downto 0) := "000110";
	constant DF_ADCxx_ADDR  : std_logic_vector(5 downto 0) := "100000";--0x80
	constant DF_SD_ADDR     : std_logic_vector(5 downto 0) := "110000";--0xC0
	constant DF_END_ADDR_H  : std_logic_vector(5 downto 0) := "000110";--0x18
	constant DF_END_ADDR_L  : std_logic_vector(5 downto 0) := "000111";--0x1C
	constant DF_SD180_ADDR  : std_logic_vector(5 downto 0) := "111000";--0xE0
	constant DF_SCI_ZP      : std_logic_vector(5 downto 0) := "111011";--0xEC
	constant DF_ENC_ADDR    : std_logic_vector(5 downto 0) := "111100";--0xF0
	constant DF_ENC_ADDR_ZP : std_logic_vector(5 downto 0) := "111101";--0xF4
	constant DF_SSI_ADDR    : std_logic_vector(5 downto 0) := "111110";--0xF8
	constant DF_INT_CNT     : std_logic_vector(5 downto 0) := "111111";--0xFC
	constant DF_STAT_ADDR   : std_logic_vector(5 downto 0) := "001010";--0x28 Status (i_Status)

	-- types -------------------------------------------------------------------
	--type t_state is (idle, write_adc, write_one);
	type t_state is (read_restart, rw_loop, write, write_SD, write_SD180, write_adc, write_PWMcntAtIncZP, write_ENCcntAtIncZP, write_Endat);
	type tr_data    is array(0 to 8) of std_logic_vector(31 downto 0);
	type tw_data    is array(0 to 13) of std_logic_vector(31 downto 0);
	-- signal ------------------------------------------------------------------
	signal State        : t_state := read_restart;
	signal addr         : std_logic_vector(5 downto 0) := DF_rD0_ADDR;
	signal data_index   : std_logic_vector(3 downto 0) := (others=>L);
	signal r_data       : tr_data;
	signal w_data       : tw_data;

	signal cADCx0       : std_logic := L;
	signal cADCx1       : std_logic := L;
	signal cSD          : std_logic := L;
	signal cSD180       : std_logic := L;
	signal cSSI         : std_logic := L;
	signal cIntCnt      : std_logic := L;
	signal cEncoderZP   : std_logic := L;
	signal cSCI_ZP      : std_logic := L;
	signal cEncoder     : std_logic := L;
	signal cSaveCounters: std_logic := L;
	signal cEndatSSI       : std_logic := L;
	signal IntCnt       : std_logic_vector(15 downto 0) := (others => L);
	signal PWMcntAtIncZP: std_logic_vector(15 downto 0) := (others => L);
	signal atSinCosZP   : std_logic_vector(31 downto 0) := (others => L);
	signal atPeriodical : std_logic_vector(31 downto 0) := (others => L);
	signal atIncZP      : std_logic_vector(31 downto 0) := (others => L);
	signal SD0          : std_logic_vector(15 downto 0) := (others => L);
	signal SD1          : std_logic_vector(15 downto 0) := (others => L);
	signal SD2          : std_logic_vector(15 downto 0) := (others => L);
	signal SD3          : std_logic_vector(15 downto 0) := (others => L);
	signal atPWM0_0     : std_logic_vector(31 downto 0) := (others => L);
	signal atPWM0_1     : std_logic_vector(31 downto 0) := (others => L);
	signal atPWM0_2     : std_logic_vector(31 downto 0) := (others => L);


--------------------------------------------------------------------------------
begin
	o_PWM_U <= r_data(0)(31 downto 16);
	o_PWM_V <= r_data(0)(15 downto 0);
	o_PWM_W <= r_data(1)(31 downto 16);
	o_PWM_100 <= r_data(1)(15 downto 0);
	o_PWM_INT <= r_data(2)(31 downto 16);
	o_Conv_St <= r_data(2)(15 downto 0);
	o_dead_time <= r_data(3)(31 downto 16);
	o_index_val <= r_data(3)(15 downto 0);
	o_SIN_phase <= r_data(4)(31 downto 16);
	o_Conv_St2 <= r_data(4)(15 downto 0);
	o_RESflg <= r_data(5)(31 downto 0);
	o_Flags <= r_data(6)(31 downto 0);
	o_si_config <= r_data(7)(31 downto 0);
	o_Endat <= r_data(8)(31 downto 0);

	w_data(0) <= i_ADCA0 & i_ADCB0;
	w_data(1) <= i_ADCA1 & i_ADCB1;
	w_data(2) <= x"00000000";
	w_data(3) <= atPWM0_0;--atSinCosZP;
	w_data(4) <= atPeriodical;
	w_data(5) <= atPWM0_1;--atIncZP;
	w_data(6) <= i_SSI;
	w_data(7) <= atPWM0_2;--IntCnt & PWMcntAtIncZP;
	w_data(8) <= SD0 & SD1;
	w_data(9) <= SD2 & SD3;
	w_data(10) <= i_EndatSSI(63 downto 32);
	w_data(11) <= i_EndatSSI(31 downto 0);
	--w_data(12) <= SD22;
	--w_data(13) <= SD23;

	o_dprEN <= H;
	dpr : process (i_Clk) begin
		if rising_edge(i_Clk) then
			o_Si_Read <= "0";
			o_dprWEN <= (others => L);
			-- hold trigger inputs
			cADCx0 <= i_cADCx0 or cADCx0;
			cADCx1 <= i_cADCx1 or cADCx1;
			cSD <= i_cSD or cSD;
			cSSI <= i_cSSI or cSSI;
			cIntCnt <= i_cIntCnt or cIntCnt;
			cEncoder <= i_cEncoder or cEncoder;
			cSD180 <= i_cSD180 or cSD180;
			cEndatSSI <= i_cEndatSSI or cEndatSSI;
			if (i_cSaveCounters=H) then -- exact at pwmCnt=0
				atPWM0_0 <= atSinCosZP;
				atPWM0_1 <= atIncZP;
				atPWM0_2 <= IntCnt & PWMcntAtIncZP;
				cSaveCounters <= H;
			end if;
			if (i_cIntCnt=L and cIntCnt=H) then   -- from 66mhz dom.
				IntCnt <= i_PWMCnt;
				cIntCnt <= L;
			end if;
			if (i_cEncoderZP=H) then
				atIncZP <= i_IncEnc & i_IncZPcnt & i_SinCos & i_IncZPcnt; -- @INC ZP
				PWMcntAtIncZP <= i_PWMCnt;
			end if;
			if (i_cSCI_ZP=H) then
				atSinCosZP <= i_IncEnc & i_SinCosZPcnt & i_SinCos & i_SinCosZPcnt; -- @Ref ZP
			end if;
			if (i_cEncoder=H) then
				atPeriodical <= i_IncEnc & i_IncZPcnt & i_SinCosRef & i_SinCosZPcnt(2 downto 0) & i_SinCos; -- old
			end if;
			if (i_cSD=H or i_cSD180=H) then
				SD0 <= i_SD0;
				SD1 <= i_SD1;
				SD2 <= i_SD2;
				SD3 <= i_SD3;
			end if;
			case state is
				when read_restart =>
					addr <= DF_rD0_ADDR;
					state <= rw_loop;
				when rw_loop =>
					if addr=DF_rD0_ADDR then
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
						addr <= DF_rD5_ADDR;
						r_data(3) <= i_dprData;
					elsif addr=DF_rD5_ADDR then
						addr <= DF_rD6_ADDR;
						r_data(4) <= i_dprData;
					elsif addr=DF_rD6_ADDR then
						addr <= DF_rD7_ADDR;
						r_data(5) <= i_dprData;
					elsif addr=DF_rD7_ADDR then
						addr <= DF_rD8_ADDR;
						r_data(6) <= i_dprData;
					elsif addr=DF_rD8_ADDR then
						addr <= DF_STAT_ADDR;
						o_dprWEN <= (others => H);
						r_data(7) <= i_dprData;
						o_Si_Read <= "1";
					elsif addr=DF_STAT_ADDR then
						addr <= DF_rD0_ADDR;
						r_data(8) <= i_dprData;
						state <= write;
					else
						-- r/w periodical interrupted!
						state <= read_restart;
					end if;
				when write =>
					if i_cADCx0=H or cADCx0=H then  -- write to dpr
						data_index <= L & DF_ADCxx_ADDR(2 downto 0);
						addr <= DF_ADCxx_ADDR;
						addr(2) <= i_invertOrder0;
						addr(3) <= not(i_conv_0_n_180);
						o_dprWEN <= (others => H);
						state <= write_adc;
					elsif i_cADCx1=H or cADCx1=H then   -- write to dpr
						data_index <= L & DF_ADCxx_ADDR(2 downto 0);
						addr <= DF_ADCxx_ADDR;
						addr(2) <= not(i_invertOrder0);
						addr(3) <= not(i_conv_0_n_180);
						o_dprWEN <= (others => H);
						state <= write_adc;
					elsif cSD=H then     -- write to dpr
						data_index <= "1000";
						addr <= DF_SD_ADDR;
						o_dprWEN <= (others => H);
						state <= write_SD;
					elsif cSD180=H then   -- write to dpr
						data_index <= "1000";
						addr <= DF_SD180_ADDR;
						o_dprWEN <= (others => H);
						state <= write_SD180;
					elsif cEndatSSI=H then     -- write to dpr
						data_index <= "1010";
						addr <= DF_END_ADDR_H;
						o_dprWEN <= (others => H);
						state <= write_Endat;
					elsif cEncoder=H then   -- write to dpr
						addr <= DF_ENC_ADDR;
						data_index <= L & DF_ENC_ADDR(2 downto 0);
						o_dprWEN <= (others => H);
						cEncoder <= L;
						state <= read_restart;
					elsif i_cSSI=H or cSSI=H then   -- write to dpr
						addr <= DF_SSI_ADDR;
						data_index <= L & DF_SSI_ADDR(2 downto 0);
						o_dprWEN <= (others => H);
						cSSI <= L;
						state <= read_restart;
					elsif cSaveCounters=H then
						addr <= DF_ENC_ADDR_ZP;
						data_index <= L & DF_ENC_ADDR_ZP(2 downto 0);
						o_dprWEN <= (others => H);
						cSaveCounters <= L;
						state <= write_ENCcntAtIncZP; -- write enc(pwm)
					else
						state <= rw_loop;
					end if;
				when write_ENCcntAtIncZP =>
					addr <= DF_SCI_ZP;
					data_index <= L & DF_SCI_ZP(2 downto 0);
					o_dprWEN <= (others => H);
					state <= write_PWMcntAtIncZP;
				when write_PWMcntAtIncZP =>
					addr <= DF_INT_CNT;
					data_index <= L & DF_INT_CNT(2 downto 0);
					o_dprWEN <= "1111";
					state <= read_restart;
				when write_Endat =>
					data_index <= data_index + 1;
					o_dprWEN <= (others => H);
					addr(1 downto 0) <= addr(1 downto 0) + 1;
					state <= read_restart;
					cEndatSSI <= L;
				when write_SD =>
					data_index <= data_index + 1;
					o_dprWEN <= (others => H);
					addr(1 downto 0) <= addr(1 downto 0) + 1;
					state <= read_restart;
					cSD <= L;
				when write_SD180 =>
					data_index <= data_index + 1;
					o_dprWEN <= (others => H);
					addr(1 downto 0) <= addr(1 downto 0) + 1;
					state <= read_restart;
					cSD180 <= L;
				when write_adc =>
					data_index <= data_index + 1;
					o_dprWEN <= (others => H);
					addr(1 downto 0) <= addr(1 downto 0) + 1;
					if cADCx0=H then -- adc0
						addr(2) <= i_invertOrder1;
					else             -- adc1
						addr(2) <= not i_invertOrder1;
					end if;
					addr(3) <= not(i_conv_0_n_180);
					state <= read_restart;
					cADCx1 <= L;
					cADCx0 <= L;
			end case;
			-- syncron reset
			if i_Reset=H then
				cADCx0 <= L;
				cADCx1 <= L;
				cSD <= L;
				cSSI <= L;
				cIntCnt <= L;
				cEncoderZP <= L;
				cSCI_ZP <= L;
				cEncoder <= L;
				cSD180 <= L;
				cSaveCounters <= L;
				State <= read_restart;
			end if;
		end if;
	end process;

	mux : process (data_index,w_data)
	begin
		if addr=DF_STAT_ADDR then
			o_dprData<= i_Status;
		else
			o_dprData<= w_data(conv_integer(data_index));
		end if;
	end process;

	o_dprAddr(addr'high downto 0) <= addr;
	o_dprAddr(o_dprAddr'high downto 1+addr'high) <= (others => L);
	o_dprClk <= i_Clk;
	o_dprRst <= i_Reset;

end behavior_dpr2SACReg;
