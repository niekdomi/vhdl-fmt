--------------------------------------------------------------------------------
--
--  	DAC Gain/Offset Abgleich
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
-- 		- rechnet FIX32-Bit Werte in DAC units
--		- Korrigiert die DAC-Werte mit *Gain + Offset
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--  22.01.2013-FB	in separates File ausgelagert
--------------------------------------------------------------------------------
--$Rev:: 2081																   $
--$Author:: leuthold														   $
--$Date:: 2011-08-03 15:53:32 +0100 (Mi, 03 Aug 2011)						   $
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
entity DAC_GainOfs is
	generic (
		-- number of DAC-channels
		NrOfCh	 			: in integer 						:= 8
	);
	port (
		i_Q25				: in  std_logic;
		i_DAC_GO_Start		: in  std_logic;

		i_DAC_MODE			: in  tSLV_Nx4(0 to NrOfCh-1);

		-- 32Bit DAC_RAM with FIX32 input DAC-values
		o_DacRam_Addr_B		: out std_logic_vector(11 downto 0)	:= (others => '0');
		i_DacRam_RdData_B	: in  std_logic_vector(31 downto 0);

		-- 16Bit Config_RAM with EEPROM-Data
		o_CfgRam_Addr_B		: out std_logic_vector(11 downto 0)	:= (others => '0');
		i_CfgRam_RdData_B	: in  std_logic_vector(15 downto 0)	:= (others => '0');

		-- Ausgabe in linearem Array
		o_DAC_Value			: out tSLV_Nx16(0 to NrOfCh-1)		:= (others =>(others => '0'));
		o_DAC_SOC			: out std_logic
	);

end DAC_GainOfs;
--------------------------------------------------------------------------------
architecture impl of DAC_GainOfs is
--------------------------------------------------------------------------------
	constant H				: std_logic := '1';
	constant L				: std_logic := '0';
--------------------------------------------------------------------------------
	type	tINT_8x4		  is array(0 to 7) of integer range 0 to 15;
	signal	iDacMode		: tINT_8x4;

--------------------------------------------------------------------------------
--	Der DAC-Wert wird im fix32-Format im mV oder mA übertragen
-- 	zB		9500mV	=	0x251C_0000
--  oder	19.5mA	=	0x0013_8000
--
--  EEP-Bereich
--	+-10V		32768 = 12V			32768/12000 = 2.730667	= 1.365333 * 2
--	0..5V		65536 = 6V			65536/ 6000 = 10.922667	= 1.365333 * 8
-- 	0..20mA		65536 = 24mA		65536/   24	= 2730.66666= 1.333333 * 2048
--------------------------------------------------------------------------------
	-- norm Zahl s1.kkkk_kkkk_kkkk_kkkk
	constant nz				: real := 65536.0;

	type sDacDSP_State is (
		sIdle,s1,s2,s3,s4
	);
	signal	DacDSP_State	: sDacDSP_State := sIdle;

	signal	DAC_Signum		: std_logic						:= '0';
	signal	DAC_Bipolar		: std_logic						:= '0';

	--  DSP-1	(DAC * Gain) + Offset
	signal	A1				: signed(31 downto 0);
	signal	B1				: signed(11 downto 0);
	signal	G1				: signed(17 downto 0);
	signal	C1				: signed(31 downto 0);
	signal	Z1				: signed(49 downto 0);
	-- calc DAC-Gain 1 + EEP_Gain
	signal	A2				: signed(17 downto 0);
	signal	B2				: signed(15 downto 0);
	signal	Z2				: signed(17 downto 0);

	-- DAC channel 0..7
	signal	iDAC_CH			: integer range 0 to NrOfCh-1;

	----------------------------------------------------------------------------
	-- CfgRam DAC side
	----------------------------------------------------------------------------
	-- DSP side
	signal	DacRam_Addr_B	: std_logic_vector(11 downto 0) := (others => '0');

	-- byte addr (ist besser zu lesen)
	signal	EEPROM_DAC_AD8	: integer range 0 to 255;
	-- 16Bit addr hilfsnode
	signal	EEPROM_DAC_AD16	: integer range 0 to 127;
----------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
--  In / Out
--------------------------------------------------------------------------------
	o_DacRam_Addr_B <= DacRam_Addr_B;

	-- 16Bit CfgRam addr
	o_CfgRam_ADDR_B <= conv_std_logic_vector(EEPROM_DAC_AD16,12);

cint:	for i in 0 to NrOfCh-1 generate
		-- convert std_logic_vector to more usable integer
		iDacMode(i) <= CONV_INTEGER(i_DAC_MODE(i));
	end generate;

--------------------------------------------------------------------------------
--  DAC correction
--------------------------------------------------------------------------------
--	siehe auch MathCad-File		COP_ADA32.xmcd
--------------------------------------------------------------------------------
	----------------------------------------------------------------------------
	--  DSP-1   asynchron part		mux inp data to DSP
	----------------------------------------------------------------------------
	-- DSP function
	Z1 <= (A1 + B1) * G1 + C1	after 8 ns;

	-- Gain = 1 + EEP-Gain
	A2 <= "01" & x"0000";
	B2 <= signed(i_CfgRam_RdData_B);
	Z2 <= (A2 + B2)			after 8 ns;

	----------------------------------------------------------------------------
	--  DSP-1 synchron part
	----------------------------------------------------------------------------
	process (i_Q25) begin
	   if rising_edge(i_Q25) then
			o_DAC_SOC 	<= L;

			-- default values
			A1 <= (others => L);
			B1 <= (others => L);
			C1 <= (others => L);
			G1 <= CONV_SIGNED(INTEGER(1),18);

			-- DacMode 0..7 sind unipolar
			if (iDacMode(iDAC_CH) < 8) then
				DAC_Bipolar <= L;
			else
				DAC_Bipolar <= H;
			end if;

			--------------------------------------------------------------------
			case (DacDSP_State) is
			--------------------------------------------------------------------
			when sIdle =>
				-- zeige auf ADC-0
				iDAC_CH <= 0;
				DacRam_Addr_B <= (others => '0');

				if (i_DAC_GO_Start = H) then
					DacDSP_State <= s1;
				end if;

			--------------------------------------------------------------------
			when s1 =>	--
				A1 <= signed(i_DacRam_RdData_B);
				DAC_Signum <= i_DacRam_RdData_B(31);

				-- zeige schon auf nächsten Kanal im DacRam
				DacRam_Addr_B(2 downto 0) <= DacRam_Addr_B(2 downto 0) + 1;
				----------------------------------------------------------------
				case (iDacMode(iDAC_CH)) is
				----------------------------------------------------------------
				-- könnte auch ins CgfRam verlegt werden, falls es mehr werden
				when 1 =>		G1 <= CONV_SIGNED(INTEGER(1.600000*nz),18);	--  0..20mA
				when 2 =>		G1 <= CONV_SIGNED(INTEGER(1.333333*nz),18);	--  0..24mA
				when 4|6|8|10 =>G1 <= CONV_SIGNED(INTEGER(1.638400*nz),18);	--  0..5V	, 0..10V  , +-5V  , +-10V
				when 5|7|9|11 =>G1 <= CONV_SIGNED(INTEGER(1.365333*nz),18);	--  0..6V	, 0..12V  , +-6V  , +-12V
				----------------------------------------------------------------
				when others => null;
				end case;
				DacDSP_State <= s2;

			--------------------------------------------------------------------
			when s2 =>	-- jetzt liegt Gain an BRAM-Data-
				-- Resultat in Z1	s1xxxx.kkkk_kkkk
				A1(31 downto 22) <= Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49);
				----------------------------------------------------------------
				case (iDacMode(iDAC_CH)) is
				----------------------------------------------------------------
				-- lade A1 mit Wert*16 1sxxxxk um Komma-Stellen zum Runden zu erhalten
				when 1|2 =>		A1(21 downto 0) <= Z1(49-11 downto 28-11);		-- * 2048	2^11	0..20mA	, 0..24mA
				when 4|5 =>		A1(21 downto 0) <= Z1(49-3  downto 28-3);		-- * 8		2^3		0..5V	, 0..6V
				when 6|7|8|9 =>	A1(21 downto 0) <= Z1(49-2  downto 28-2);		-- * 4		2^2		0..10V	, 0..12V  , +-5V  , +-6V
				when 10|11 =>	A1(21 downto 0) <= Z1(49-1  downto 28-1);		-- * 2		2^1		+-10V	, +-12V
				----------------------------------------------------------------
				when others =>	A1 <= (others => '0');
				end case;
				----------------------------------------------------------------

				G1 <= Z2;	-- s1.xxxx
				DacDSP_State <= s3;

			--------------------------------------------------------------------
			when s3 =>	-- nur jetzt liegt Offset an BRAM-Data
				-- Resultat in Z1 ist *16	s1xxxxk_kkkk
				-- Lade A1 mit Wert*16, damit Auf/Abrunden möglich
				A1(31 downto 22) <= Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49)&Z1(49);
				A1(21 downto  0) <= Z1(37 downto 16);		-- *16

				-- offset aus RAM lesen	(high-byte or low-byte)
				----------------------------------------------------------------
				case iDAC_CH is
				----------------------------------------------------------------
				when 0|2|4|6 =>	B1(11 downto 4) <= signed(i_CfgRam_RdData_B(15 downto 8));	-- *16
				when others  => B1(11 downto 4) <= signed(i_CfgRam_RdData_B( 7 downto 0));	-- *16
				end case;

				----------------------------------------------------------------
				-- Auf- / Abrunden	(siehe auch MathCad-File HEX_DSP_Round.xmcd)
				----------------------------------------------------------------
				-- Auf-/Abrunden
			--	if (DAC_Bipolar = H) then
			--		-- bipolar,		+- runden
			--		if (DAC_Signum = L) then
			--			C1 <= CONV_SIGNED(INTEGER(+0.5*16),32);		-- *16
			--		else
			--			C1 <= CONV_SIGNED(INTEGER(-0.5*16),32);		-- *16
			--		end if;
			--	else
					-- unipolar,	+ runden
					C1 <= CONV_SIGNED(INTEGER(+0.5*16),32);			-- *16
			--	end if;
				DacDSP_State <= s4;

			--------------------------------------------------------------------
			when s4 =>
				-- Resultat in Z1 ist *16 s1xxxx.k
				if (DAC_Bipolar = H) then
					-- bipolar begrenzen	8000..7FFF
					if 		(std_logic_vector(Z1(21 downto 19)) = "001") then
						o_DAC_Value(iDAC_CH) <= x"7FFF";
					elsif	(std_logic_vector(Z1(21 downto 19)) = "110") then
						o_DAC_Value(iDAC_CH) <= x"8000";
					else
						o_DAC_Value(iDAC_CH) <= std_logic_vector(Z1(19 downto 4)); 	-- /16
					end if;
				else
					-- unipolar begrenzen 	0000..FFFF
					if 		(std_logic_vector(Z1(21 downto 20)) = "01") then
						o_DAC_Value(iDAC_CH) <= x"FFFF";
					elsif	(std_logic_vector(Z1(21 downto 20)) = "11") then
						o_DAC_Value(iDAC_CH) <= x"0000";
					else
						o_DAC_Value(iDAC_CH) <= std_logic_vector(Z1(19 downto 4)); 	-- /16
					end if;
				end if;

				if (iDAC_CH < NrOfCh-1) then
					-- calc next ch
					-- zeige auf nächstes Gain
					iDAC_CH <= iDAC_CH + 1;
					DacDSP_State <= s1;
				else
					DacDSP_State <= sIdle;
					-- start of DAC-convert
					o_DAC_SOC <= H;
				end if;

			--------------------------------------------------------------------
			when others => null;
			end case;
			--------------------------------------------------------------------
		end if;
	end process;


--------------------------------------------------------------------------------
--  DAC EEP_ConfigRam access	point to Offset/Gain in CfgRam	(== EEPROM Struktur)
--------------------------------------------------------------------------------
--	DacMode:		0	disabled			8	+- 5V
--					1	0..20mA             9	+- 6V
--					2	0..24mA             10	+- 10V
--					3	4..20mA             11	+- 12V
--					4	0..5V               12	disabled
--					5	0..6V               13	disabled
--					6	0..10V              14	disabled
--					7	0..12V              15	disabled
--
	process (DacDSP_State,iDAC_CH,iDacMode) begin
--			--------------------------------------------------------------------
--			when sIdle 	=>							-- jetzt liegt Gain an BRAM-Data
--			when s1 	=> 							-- jetzt liegt Gain an BRAM-Data
--			when s2		=> EEP_to_DacOfs <= H;		-- jetzt liegt Gain an BRAM-Data
--			when s3		=>							-- jetzt liegt Ofs  an BRAM-Data
--			when s4		=>							-- jetzt liegt Gain an BRAM-Data
--			--------------------------------------------------------------------
			if (DacDSP_State = s2) then		-- bei s3 liegt Ofs an BRAM-Data
				------------------------------------------------------------
				case (iDacMode(iDAC_CH)) is				-- Offset
				------------------------------------------------------------
				when 2	=>		EEPROM_DAC_AD8 <= 116 + iDAC_CH;		-- 0..24mA
				when 5	=>		EEPROM_DAC_AD8 <=  92 + iDAC_CH;		-- 0..6V
				when 11	=>		EEPROM_DAC_AD8 <=  68 + iDAC_CH;		-- +- 12V
				------------------------------------------------------------
				when others =>	EEPROM_DAC_AD8 <=  68 + iDAC_CH;		-- +- 12V
				end case;
				------------------------------------------------------------
			else
				------------------------------------------------------------
				case (iDacMode(iDAC_CH)) is				-- Gain
				------------------------------------------------------------
				when 2	=>		EEPROM_DAC_AD8 <= 124 + (iDAC_CH*2);	-- 0..24mA
				when 5	=>		EEPROM_DAC_AD8 <= 100 + (iDAC_CH*2);	-- 0..6V
				when 11	=>		EEPROM_DAC_AD8 <=  76 + (iDAC_CH*2);	-- +- 12V
				------------------------------------------------------------
				when others =>	EEPROM_DAC_AD8 <=  76 + (iDAC_CH*2);	-- +- 12V
				end case;
				------------------------------------------------------------
			end if;
	end process;

	-- EEPROM-Byte Adr to CFG_BRAM-Word Adr		( /2 )
	EEPROM_DAC_AD16 <= EEPROM_DAC_AD8/2;


--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
