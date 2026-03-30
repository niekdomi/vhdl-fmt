--------------------------------------------------------------------------------
--
--	dpr2HEATReg
--
--------------------------------------------------------------------------------
--
--	project		: INFO-HEAT
--	programmer	: C.Leuthold, INDEL	AG
--	date		: 16.09.2004
--	version		: 1.00a
--	language	: VHDL
--	system		: ISE / EDK
--
--	purpose
--		copy registers from and to blockram
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--
--	17.03.2008-le: - adjustments for info-heat (from dpr2MAX4Reg)
--	28.04.2008-le: - change i_sAddr to a read and a write addres
--------------------------------------------------------------------------------
--$Rev:: 460                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2008-07-04 13:45:41 +0200 (Fr., 04 Jul 2008)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library	ieee;
use	IEEE.std_logic_1164.ALL;
use	IEEE.std_logic_unsigned.ALL;
use	IEEE.std_logic_arith.ALL;

entity dpr2HEATReg is
	port (
		--System
		i_Reset : in std_logic;
		i_Clk : in std_logic;
		-- Dualport	Ram	access
		o_dprEN : out std_logic;
		o_dprClk : out std_logic;
		o_dprRst : out std_logic;
		o_dprWEN : out std_logic_vector(3 downto 0);
		o_dprData : out std_logic_vector(127 downto 0);
		i_dprData : in std_logic_vector(127 downto 0);
		o_dprAddr : out std_logic_vector(8 downto 0);
		-- inputs
		-- adcs
		i_ADCA0 : in std_logic_vector(15 downto 0) := (others => '0');
		i_ADCB0 : in std_logic_vector(15 downto 0) := (others => '0');
		-- misc
		i_Timer : in std_logic_vector(31 downto 0) := (others => '0');
		i_Status : in std_logic_vector(31 downto 0) := (others => '0');
		i_digital_inputs : in std_logic_vector(31 downto 0) := (others => '0');
		--
		i_srAddr : in	std_logic_vector(3 downto 0) := (others => '0');
		i_swAddr : in	std_logic_vector(3 downto 0) := (others => '0');
		o_sData : out std_logic_vector(127 downto 0);
		i_sData : in std_logic_vector(127 downto 0) := (others => '0');
		o_srDone : out std_logic;
		o_swDone : out std_logic;
		-- outputs
		o_TimerMax : out std_logic_vector(31 downto 0);
		o_TimerCmp0 : out std_logic_vector(31 downto 0);
		o_TimerCmp1 : out std_logic_vector(31 downto 0);
		o_TimerCmp2 : out std_logic_vector(31 downto 0);
		o_digital_outputs : out std_logic_vector(31 downto 0);
		o_ADC_job : out std_logic_vector(15 downto 0);
		o_Flags : out std_logic_vector(31 downto 0);
		-- triggers
		i_cADC_0 : in std_logic := '0';
		i_cADC_1 : in std_logic := '0';
		i_cIntCnt : in std_logic := '0';
		i_cTim0 : in std_logic := '0';
		i_cInputs : in std_logic := '0';
		i_cSafety : in std_logic := '0'
	);
end;


architecture behavior_dpr2HEATReg of dpr2HEATReg is
--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	: std_logic := '1';
	constant	L	: std_logic := '0';
	constant	Z	: std_logic := 'Z';
	-- outputs
	constant DF_rTIMER_ADDR	: std_logic_vector(8 downto 0) := "000000000";--BASE+0x0000
	constant DF_rDOUT_ADDR	: std_logic_vector(8 downto 0) := "001000000";--BASE+0x0400
	constant DF_rSAVE_ADDR	: std_logic_vector(8 downto 0) := "010000000";--BASE+0x0800
	
	constant DF_rTIMER_INDEX : integer := 0;
	constant DF_rDOUT_INDEX : integer := 1;
	constant DF_rSAVE_INDEX : integer := 2;
	-- inputs
	constant DF_ADC_0_ADDR	: std_logic_vector(8 downto 0) := "100000000";--BASE+0x1000
	constant DF_ADC_1_ADDR	: std_logic_vector(8 downto 0) := "100000010";--BASE+0x1020
	constant DF_MISC_ADDR	: std_logic_vector(8 downto 0) := "100110000";--BASE+0x1300
	constant DF_MISC_ADDR2	: std_logic_vector(8 downto 0) := "100110001";--BASE+0x1310
	constant DF_wSAVE_ADDR	: std_logic_vector(8 downto 0) := "110000000";--BASE+0x1800
	-- indices
	constant DF_ADC		: integer := 0;
	constant DF_MISC	: integer := 1;
	constant DF_SAVE	: integer := 2;
	

	-- types -------------------------------------------------------------------
	type t_state is (read_restart, rw_loop0, rw_loop1, rw_loop2, write);
	type tr_data is array(0 to 2) of std_logic_vector(o_dprData'length-1 downto 0);
	type tw_data is array(0 to 2) of std_logic_vector(o_dprData'length-1 downto 0);
	-- signal ------------------------------------------------------------------
	signal State : t_state := read_restart;
	signal addr : std_logic_vector(8 downto 0) := DF_rTIMER_ADDR;
	signal data_index : std_logic_vector(1 downto 0) := (others=>L);
	signal r_data : tr_data;
	signal w_data : tw_data;
	signal TimerAtInt : std_logic_vector(31 downto 0);
	
	signal cADC_0 : std_logic := L;
	signal cADC_1 : std_logic := L;
	signal cTim0 : std_logic := L;
	signal cInputs : std_logic := L;
	signal cSafety : std_logic := L;
	signal cIntCnt : std_logic := L;

	signal GND16 : std_logic_vector(15 downto 0)	:= (others => L);

--------------------------------------------------------------------------------
begin

	o_TimerMax <= r_data(DF_rTIMER_INDEX)(127 downto 96);-- 0x0000
	o_TimerCmp0 <= r_data(DF_rTIMER_INDEX)(95 downto 64);-- 0x0004
	o_TimerCmp1 <= r_data(DF_rTIMER_INDEX)(63 downto 32);-- 0x0008
	o_TimerCmp2 <= r_data(DF_rTIMER_INDEX)(31 downto 0);-- 0x000C
	
	o_digital_outputs <= r_data(DF_rDOUT_INDEX)(127 downto 96);-- 0x0400
	-- <= r_data(DF_rDOUT_INDEX)(95 downto 80);			-- 0x0404
	-- <= r_data(DF_rDOUT_INDEX)(79 downto 64);			-- 0x0406
	o_ADC_job <= r_data(DF_rDOUT_INDEX)(63 downto 48);	-- 0x0408
	--	 <= r_data(DF_rDOUT_INDEX)(47 downto 32);		-- 0x040A
	o_Flags <= r_data(DF_rDOUT_INDEX)(31 downto 0); 	-- 0x040C
	
	o_sData <= r_data(DF_rSAVE_INDEX);

	--					0x0 & 0x2 & 0x4 & 0x6 & 0x8 & 0xA & 0xC & 0xE
	w_data(DF_ADC) <= i_ADCA0 & i_ADCB0 & GND16 & GND16 & GND16 & GND16 & i_Timer;
	w_data(DF_MISC) <= i_digital_inputs & i_Timer & TimerAtInt & i_Status;
	w_data(DF_SAVE) <= i_sData;

	dpr : process (i_Clk) begin
		if rising_edge(i_Clk) then
			o_dprWEN <= (others => L);
			o_swDone <= L;
			o_srDone <= L;
			-- hold trigger inputs
			cADC_0 <= i_cADC_0 or cADC_0;
			cADC_1 <= i_cADC_1 or cADC_1;
			cTim0 <= i_cTim0 or cTim0;
			cSafety <= i_cSafety or cSafety;
			cInputs <= i_cInputs or cInputs;
			if (i_cIntCnt=H) then
				TimerAtInt <= i_Timer;
				cIntCnt <= H;
			end if;
			case state is
				when read_restart =>
					addr <= DF_rTIMER_ADDR;
					state <= rw_loop0;
				when rw_loop0 =>
					addr <= DF_rDOUT_ADDR;
					state <= rw_loop1;
				when rw_loop1 =>
					r_data(DF_rTIMER_INDEX) <= i_dprData;
					addr <= DF_rSAVE_ADDR(8 downto 4) & i_srAddr;
					state <= rw_loop2;
				when rw_loop2 =>
					r_data(DF_rDOUT_INDEX) <= i_dprData;
					if (cInputs=H) then -- spezi write: cInputs can be permanent H!
						data_index <= CONV_STD_LOGIC_VECTOR(DF_MISC,data_index'length);
						addr <= DF_MISC_ADDR;
						o_dprWEN <= (others => H);
						cInputs <= L;
						TimerAtInt(31) <= not cIntCnt;
						cIntCnt <= L;
					end if;
					state <= write;
				when write =>
					r_data(DF_rSAVE_INDEX) <= i_dprData;
					o_srDone <= H;
					-- w_data(ADC) 0 and 1
					if (cADC_0=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC,data_index'length);
						addr <= DF_ADC_0_ADDR;
						o_dprWEN <= (others => H);
						cADC_0 <= L;
						state <= read_restart;
					elsif (cADC_1=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_ADC,data_index'length);
						addr <= DF_ADC_1_ADDR;
						o_dprWEN <= (others => H);
						cADC_1 <= L;
						state <= read_restart;
					elsif (cSafety=H) then
						data_index <= CONV_STD_LOGIC_VECTOR(DF_SAVE,data_index'length);
						addr <= DF_wSAVE_ADDR(8 downto 4) & i_swAddr;
						o_dprWEN <= (others => H);
						cSafety <= L;
						o_swDone <= H;
						state <= read_restart;
					else
						-- read permanent
						addr <= DF_rTIMER_ADDR;
						state <= rw_loop0;
					end if;
			end case;
			-- syncron reset
			if (i_Reset=H) then
				cADC_0 <= L;
				cADC_1 <= L;
				cTim0 <= L;
				cInputs <= L;
				cSafety <= L;
				State <= read_restart;
				cIntCnt <= L;
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
	o_dprRst <= L;


end behavior_dpr2HEATReg;







