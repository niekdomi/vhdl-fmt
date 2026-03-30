--------------------------------------------------------------------------------
--
--	ADC Offset/Gain Abgleich
--
--------------------------------------------------------------------------------
--
--  project		: C64_BusMaster
--  programmer  : F:Baschung, INDEL AG
--  date		: 23.06.2010
--  version		: 1.00
--  language	: VHDL
--  system		: Project Navigator
--
--  purpose
--		- ADC +Offset*Gain
-- 		- to FIX32
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--  22.01.2013-FB	in separates File
--------------------------------------------------------------------------------
--$Rev:: 2081																   $
--$Author:: leuthold														   $
--$Date:: 2011-08-03 15:53:32 +0100 (Mi, 03 Aug 2011)						   $
--------------------------------------------------------------------------------
--
--	Die ADC-Werte werden noch als tSLV_Nx16(0 to 7) übergeben,
-- 	da das so aus dem ADC-Module kommt.
-- 	Besser wäre vermutlich ein SimpleDualportRam
--
--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
entity ADC_OfsGain is
	port (
		i_Q25				: in  std_logic;

		-- from ADC-Module
		i_ADC_OG_Start		: in  std_logic;					-- ADC measuring done
		i_ADC				: tSLV_Nx16(0 to 7);				-- 16Bit ADC-Value
		i_PGA_AUTO		: in  std_logic_vector(15 downto 0);

		-- 32Bit ADC_RAM with FIX32 ADC ouput-values
		o_AdcRam_WEN_A		: out std_logic_vector( 3 downto 0);
		o_AdcRam_Addr_A		: out std_logic_vector(11 downto 0);
		o_AdcRam_WrData_A	: out std_logic_vector(31 downto 0);
		i_AdcRam_RdData_A	: in  std_logic_vector(31 downto 0);

		-- 16Bit Config_RAM with EEPROM-Data
		o_CfgRam_Addr_B		: out std_logic_vector(11 downto 0)	:= (others => '0');
		i_CfgRam_RdData_B	: in  std_logic_vector(15 downto 0)	:= (others => '0');

		-- to Average-Filter Module
		o_FLT_INP_t1		: out signed(31 downto 0);			-- last value t-1
		o_FLT_INP			: out signed(31 downto 0);			-- newest value
		o_FLT_CH			: out integer range 0 to 7;			-- act channel
		o_FLT_START			: out std_logic;

		o_ADC_OG_Done		: out std_logic						:= '0'
	);
end ADC_OfsGain;
--------------------------------------------------------------------------------
architecture impl of ADC_OfsGain is
--------------------------------------------------------------------------------
	constant H				: std_logic := '1';
	constant L				: std_logic := '0';
	-- norm Zahl s1.kkkk_kkkk_kkkk_kkkk
	constant nz				: real := 65536.0;

--------------------------------------------------------------------------------
	-- byte addr (ist besser zu lesen)
	signal	EEPROM_ADC_AD		: integer range 0 to 255;
	-- 16Bit addr hilfsnode
	signal	EEPROM_ADC_AD_2		: integer range 0 to 127;

--------------------------------------------------------------------------------
--  AdcDsp	(ADC + OFfset) * 1.Gain
	type sAdcDSP_State is (
		sIdle,s1,s2,s3,s4
	);
	signal	AdcDSP_State	: sAdcDSP_State := sIdle;
--	signal	i				: integer range 0 to 7;

	signal	A0				: signed(16 downto 0);
	signal	B0				: signed( 7 downto 0);
	signal	G0				: unsigned(16 downto 0);
	signal	Z0				: signed(34 downto 0);
	signal	one				: unsigned(16 downto 0)			:= "0" & x"0001";
	-- calc ADC-Gain 1/27000*27200 + EEP_Gain
	signal	A3				: signed(17 downto 0);
	signal	B3				: signed(15 downto 0);
	signal	Z3				: signed(17 downto 0);

	-- ADC channel 0..7
	signal	iADC_CH			: integer range 0 to 7;
	signal	nADC_CH			: integer range 0 to 7;

----------------------------------------------------------------------------------
--  AutoRange
	type	tusign_Nx16 is array(natural RANGE <>)  of unsigned(15 downto 0);
	signal	ToFix32			: tusign_Nx16(0 to 7)			:= (others => (others => '0'));
	signal	ActScal			: tSLV_Nx2(0 to 7)				:= (others => (others => '0'));

	-- ADC side
	signal	AdcRam_WEN_A	: std_logic_vector( 3 downto 0) := (others => '0');
	signal	AdcRam_Addr_A	: std_logic_vector(11 downto 0) := (others => '0');
	signal	AdcRam_WrData_A	: std_logic_vector(31 downto 0) := (others => '0');
----------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
--  In / Out
--------------------------------------------------------------------------------
	o_CfgRam_Addr_B <= conv_std_logic_vector(EEPROM_ADC_AD_2,12);

	o_AdcRam_WEN_A		<= AdcRam_WEN_A;
	o_AdcRam_Addr_A		<= AdcRam_Addr_A;
	o_AdcRam_WrData_A	<= AdcRam_WrData_A;

--------------------------------------------------------------------------------
--  Calc next Gain
--------------------------------------------------------------------------------
gX1_1000: for i in 0 to 7 generate

	process(i_PGA_AUTO,ActScal) begin
		ActScal(i) <= i_PGA_AUTO ((i*2)+1 downto (i*2));
		------------------------------------------------------------------------
		case ActScal(i) is
		------------------------------------------------------------------------
		when "00" => ToFix32(i) <= conv_unsigned(20000,16);
		when "01" => ToFix32(i) <= conv_unsigned( 2000,16);
		when "10" => ToFix32(i) <= conv_unsigned(  200,16);
		when "11" => ToFix32(i) <= conv_unsigned(   20,16);
		------------------------------------------------------------------------
		when others => null;
		end case;
	end process;

end generate;

--------------------------------------------------------------------------------
--  ADC correction
--------------------------------------------------------------------------------

	----------------------------------------------------------------------------
	--  AdcDSP   asynchron part		mux inp data to DSP
	----------------------------------------------------------------------------
	-- AdcDSP function
	Z0 <= (A0 - B0) * G0 after 8 ns;

	-- Gain = 1/27000*27200 + EEP-Gain
	-- Korrektur Spannungsteiler 1/27k * (27k+200Ohm) = 1.007407
	A3 <= CONV_SIGNED(INTEGER(1.007407*nz),18);
	B3 <= signed(i_CfgRam_RdData_B);
	Z3 <= (A3 + B3)			after 8 ns;

	----------------------------------------------------------------------------
	--  AdcDsp synchron part
	----------------------------------------------------------------------------
	process (i_Q25) begin
	   if rising_edge(i_Q25) then
			o_ADC_OG_Done <= L;
			o_FLT_START <= L;

			-- default values
			A0  <= (others => L);
			B0  <= (others => L);
			G0  <= one;

			AdcRam_WrData_A <= conv_std_logic_vector(Z0(31 downto 0),32);
			AdcRam_WEN_A <= (others => L);

			if (AdcRam_WEN_A(0) = H) then
				-- AutoInc nach jedem write
				AdcRam_Addr_A(2 downto 0) <= AdcRam_Addr_A(2 downto 0) +1;
			end if;

			--------------------------------------------------------------------
			case (AdcDSP_State) is
			--------------------------------------------------------------------
			when sIdle =>
				-- zeige auf ADC-0
				iADC_CH <= 0;
				nADC_CH <= 0;
				AdcRam_Addr_A <= (others => '0');
				if (i_ADC_OG_Start = H) then
					AdcDSP_State <= s1;
				end if;
			--------------------------------------------------------------------
			when s1 =>	-- jetzt liegt Offset an BRAM-Data
				-- offset aus RAM lesen	(high-byte or low-byte)
				----------------------------------------------------------------
				case nADC_CH is
				----------------------------------------------------------------
				when 0|2|4|6	=>	B0 <= signed(i_CfgRam_RdData_B(15 downto 8));
				when others 	=> 	B0 <= signed(i_CfgRam_RdData_B( 7 downto 0));
				end case;
				----------------------------------------------------------------
				-- zeige auf nächsten Offset	(wrap 0..7)
				nADC_CH <= conv_integer(conv_std_logic_vector(nADC_CH,3)+1);

				-- store ADC16 value
				AdcRam_WrData_A(31 downto 16) <= i_ADC(iADC_CH);
				AdcRam_Addr_A(4) <= L;	-- Port x00..07
				AdcRam_WEN_A <= "1100";
				AdcDSP_State <= s2;
			--------------------------------------------------------------------
			when s2 =>	-- nur jetzt liegt Gain an BRAM-Data
				A0 <= signed(i_ADC(iADC_CH)(15) & i_ADC(iADC_CH));  -- 17 Bit
				B0 <= B0;
				-- 1.xxxx  --> im BRAM sind nur die xxxx von Gain
--				G0 <= "1" & unsigned(CfgRam_RdData1_B);
				G0 <= unsigned(Z3(16 downto 0));	-- calced Gain 1.004707 * EEP_GAin
				-- benötige t-1 Wert in state-4
				AdcRam_Addr_A(4) <= H;				-- read from Port x10..1F
				AdcDSP_State <= s3;
			--------------------------------------------------------------------
			when s3 =>
				-- da *1.xxxx -> Resultat kann über 16Bit gehen
				A0 <= Z0(32 downto 16);				-- 17 Bit
				G0 <= "0" & ToFix32(iADC_CH);		-- scale to xxxx.xxxx
				AdcDSP_State <= s4;
			--------------------------------------------------------------------
			when s4 =>
				-- geht höchstens bis ca 10200mV
				-- push it into Filter
				o_FLT_INP_t1	<= signed(i_AdcRam_RdData_A);		-- letzter Wert, von t-1
				o_FLT_INP		<= Z0(31 downto 0);
				o_FLT_CH		<= iADC_CH;
				o_FLT_START		<= H;

				-- write new ADC32 val into AdcRam to Port x10..1F
				AdcRam_WEN_A <= (others => H);

				if (iADC_CH < 7) then
					-- calc next ch
					iADC_CH <= iADC_CH + 1;
					AdcDSP_State <= s1;
				else
					-- all Gain/Offset done
					o_ADC_OG_Done <= H;
					AdcDSP_State <= sidle;
				end if;
			--------------------------------------------------------------------
			when others => null;
			end case;
			--------------------------------------------------------------------
		end if;
	end process;

--------------------------------------------------------------------------------
--  ADC EEP_ConfigRam access	point to Offset/Gain in CfgRam	(== EEPROM Struktur)
--------------------------------------------------------------------------------
	process (AdcDSP_State,nADC_CH,ActScal) begin
--			--------------------------------------------------------------------
--			when sIdle =>					-- jetzt liegt Offset an BRAM-Data
--			when s1 => EEP_to_AdcGain <= H;	-- jetzt liegt Offset an BRAM-Data
--			when s2 =>						-- jetzt liegt Gain   an BRAM-Data
--			when s3 => 						-- jetzt liegt Offset an BRAM-Data
--			when s4 =>						-- jetzt liegt Offset an BRAM-Data
--			--------------------------------------------------------------------
			if (AdcDSP_State = s1) then		-- bei s2 liegt Gain an BRAM-Data
				------------------------------------------------------------
				case (ActScal(nADC_CH)) is		-- Gain
				------------------------------------------------------------
				when "00" =>	EEPROM_ADC_AD <= 148 + (nADC_CH*2);	-- +-10V
				when "01" =>	EEPROM_ADC_AD <= 196 + (nADC_CH*2);	-- +-1V
				when "10" =>	EEPROM_ADC_AD <= 220 + (nADC_CH*2);	-- +-0.1V
				when "11" =>	EEPROM_ADC_AD <= 240 + (nADC_CH*2);	-- +-0.01V
				------------------------------------------------------------
				when others =>	EEPROM_ADC_AD <= 148 + (nADC_CH*2);	-- +-10V
				end case;
				------------------------------------------------------------
			else
				-- VORSICHT: ist eigentlich zu spät, aber da /2 auch so gut
				------------------------------------------------------------
				case (ActScal(nADC_CH)) is		-- Offset
				------------------------------------------------------------
				when "00" =>	EEPROM_ADC_AD <= 140 + nADC_CH;		-- +-10V
				when "01" =>	EEPROM_ADC_AD <= 188 + nADC_CH;		-- +-1V
				when "10" =>	EEPROM_ADC_AD <= 212 + nADC_CH;		-- +-0.1V
				when "11" =>	EEPROM_ADC_AD <=  60 + nADC_CH;		-- +-0.01V
				------------------------------------------------------------
				when others =>	EEPROM_ADC_AD <= 140 + nADC_CH;		-- +-10V
				end case;
				------------------------------------------------------------
			end if;
	end process;


	-- EEPROM-Byte Adr to CFG_BRAM-Word Adr		( /2 )
	EEPROM_ADC_AD_2 <= EEPROM_ADC_AD/2;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
