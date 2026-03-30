---------------------------------------------------------------------------
--
--	SinCos Generator ->	DAC	-->-o--(Load)--o-> ADC -> DFT
--
---------------------------------------------------------------------------
--
--	project : SinCos_DFT
--	programmer : F:Baschung, INDEL	AG
--	date : 15.12.2010
--	version : 1.00
--	language : VHDL
--	system : Project Navigator
--
--	purpose
--		- SinCos Generator
--		- DFT
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--		DAC_3 set
--		start measuring at 0deg
--		ADC-offset measuring
--		ADC-Max/Min measuring
--
--
--------------------------------------------------------------------------------
--$Rev:: 2710                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-02-01 16:24:17 +0100 (Fr, 01 Feb 2013)                          $
--------------------------------------------------------------------------------
---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;

LIBRARY SinCos_Gen;
USE SinCos_Gen.ALL;

LIBRARY SinCos_DFT;
USE SinCos_DFT.dft_calc;

LIBRARY bram;
USE bram.ALL;

--------------------------------------------------------------------------------
entity SinCos_DFT is
	generic(
		C_LNG : integer := 32;
		DF_TESTMODE : integer := 0
	);
	port (
		i_CLK : in std_logic;
		i_Reset : in std_logic;

		o_DAC_SOC : out	std_logic;
		o_DAC_Ch : out	std_logic_vector( 1 downto 0);
		o_DAC_Data : out	std_logic_vector(15 downto 0);

		o_ADC_SOC : out	std_logic;
		i_adc_d_ready : in std_logic;
		i_ADC_Data_a : in std_logic_vector(15 downto 0);
		i_ADC_Data_b : in std_logic_vector(15 downto 0);

		i_Cfg_DAC0_Gain : in std_logic_vector(15 downto 0);
		i_Cfg_dTheta : in std_logic_vector(15 downto 0);
		i_Cfg_DAC0_Ofs : in std_logic_vector(15 downto 0);
		i_Cfg_NoS : in std_logic_vector(15 downto 0);
		i_Cfg_DAC_1 : in std_logic_vector(15 downto 0);
		i_Cfg_Phase : in std_logic_vector(15 downto 0);

		o_aSUM_RE : out std_logic_vector(C_LNG-1 downto 0);
		o_aSUM_IM : out std_logic_vector(C_LNG-1 downto 0);
		o_bSUM_RE : out std_logic_vector(C_LNG-1 downto 0);
		o_bSUM_IM : out std_logic_vector(C_LNG-1 downto 0);
		o_done : out std_logic;

		o_ram_addr : out std_logic_vector(1 downto 0);
		o_ram_data : out std_logic_vector(C_LNG-1 downto 0);
		o_ram_we : out std_logic;

		i_noReSync : in std_logic := '1';
		i_resetTheta : in std_logic := '0';

		i_logenable : in std_logic := '0';
		i_lrAddr : in std_logic_vector(15 downto 0) := (others => '0');
		o_lrData : out	std_logic_vector(31 downto 0);
		i_lrCLK : in std_logic := '0'
	);
end;

architecture impl of SinCos_DFT	is
--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';

--------------------------------------------------------------------------------
--	Vorgaben
--	2.5Vdc + 1.25Uss , 2kHz
--------------------------------------------------------------------------------
	-- 1 = +-10V	1/8	* 65536=
	signal Cfg_DAC0_Gain : signed(17 downto 0);
	-- 33575 ==	ca 0V	+	32768/4 = 2.5V	=
	signal Cfg_DAC0_Ofs : signed(15 downto 0);
	-- 2kHz	-> 2000	* 131072 / 1000000 = 262.144 *65536 = 17179869.184
	signal Cfg_dTheta : unsigned(15 downto 0) := (others => L);
	-- 2kHz, 500kS/sec -> 1000DFT_N = 20 periods
	signal Cfg_NoS : unsigned(15 downto 0) := (others => L);

	signal Cfg_DAC_1 : std_logic_vector(15 downto 0) :=(others => L);

--------------------------------------------------------------------------------
	signal result : signed(34 downto 0);
	signal NextDacCos : signed(15 downto 0) := (others => L);

--------------------------------------------------------------------------------
--	SinCos Generator
--------------------------------------------------------------------------------
	signal Start : std_logic := L;
	signal Theta : unsigned(16 downto 0) := (others => L);

	signal ThetaSin : unsigned(16 downto 0) := (others => L);

	signal Sin : signed(16 downto 0) := (others => L);
	signal Cos : signed(16 downto 0) := (others => L);

	signal iCos : std_logic_vector(18 downto 0) := (others => L);
--------------------------------------------------------------------------------
--	test Sequencer
--------------------------------------------------------------------------------
	signal state_cnt : unsigned(11 downto 0) := (others => L);

	signal aADC : signed(16 downto 0) := (others => L);
	signal bADC : signed(16 downto 0) := (others => L);

	signal aSUM_IM : signed(o_aSUM_RE'range) := (others => L);
	signal aSUM_RE : signed(o_aSUM_IM'range) := (others => L);
	signal bSUM_IM : signed(o_bSUM_RE'range) := (others => L);
	signal bSUM_RE : signed(o_bSUM_IM'range) := (others => L);

	signal DFT_N : unsigned(15 downto 0) := (others => L);

	--constant ADC_MAX : unsigned(state_cnt'range) := x"0c7"; --f9 für 125mhz (clk/adc samplerate )
	constant DAC_MAX : unsigned(state_cnt'range) := x"0c7";
	constant DAC_HALF : unsigned(state_cnt'range) := x"063";

	signal Cfg_Phase : unsigned(16 downto 0) := (others => L);

	signal lrEn : std_logic_vector(1 downto 0) := (others => L);
	signal lrAddr : unsigned(10 downto 0) := (others => L);
	signal logenable : std_logic := L;
	signal lrRun : std_logic := L;

	signal SinNCos : std_logic := L;


	signal c : signed(o_aSUM_RE'range) := (others => L);
	signal add_r : signed(o_aSUM_RE'range) := (others => L);
	signal add_rx : signed(o_aSUM_RE'range) := (others => L);
	signal a : signed(16 downto 0) := (others => L);
	signal b : signed(16 downto 0) := (others => L);

	signal adc_d_ready_r : std_logic := L;

	signal iindex : unsigned(1 downto 0) := (others => L);
	signal oindex : unsigned(1 downto 0) := (others => L);
	signal calcdone : std_logic := L;
	signal calcstart : std_logic := L;
--------------------------------------------------------------------------------

begin
--------------------------------------------------------------------------------
--	ADC	Sequencer
--------------------------------------------------------------------------------
--	Der	ADC	läuft mit 500kS/sec
--	Daher ist der ganze	Sequencer über den Q125/x"0F9" Zähler gesteuert
--------------------------------------------------------------------------------

	Cfg_DAC0_Gain <= signed(i_Cfg_DAC0_Gain & "00");
	Cfg_DAC0_Ofs <= signed(i_Cfg_DAC0_Ofs);
	Cfg_dTheta <= unsigned(i_Cfg_dTheta(15 downto 0));
	Cfg_NoS <= unsigned(L & i_Cfg_NoS(14 downto 0));

	dft_calc : entity work.dft_calc
	generic map (
		C_LNG => C_LNG,
		C_INDEXLNG => iindex'length
	)
	port map (
		i_CLK		=> i_CLK,
		i_Start		=> calcstart,
		i_index		=> iindex,
		i_a			=> a,
		i_b			=> b,
		i_c			=> c,
		o_index		=> oindex,
		o_res		=> add_rx,
		o_done		=> calcdone
	);


	tm: if DF_TESTMODE=1 generate
		signal cnt : unsigned(3 downto 0) := (others => L);
	begin

		add_r(C_LNG-1 downto 8) <= (others => L);
		add_r(7 downto 0) <= signed(std_logic_vector(cnt) & "00" & std_logic_vector(oindex));

		-- ram output
		o_ram_addr <= std_logic_vector(oindex);
		o_ram_data <= std_logic_vector(add_r);
		o_ram_we <= calcdone when DFT_N = Cfg_NoS else L;

		process (i_CLK) begin
			if rising_edge(i_CLK) then
				if (oindex=3 and calcdone=H and DFT_N = Cfg_NoS) then
					cnt <= cnt+1;
				end if;
			end if;
		end process;

	end generate tm;

	nm: if DF_TESTMODE=0 generate
	begin
		add_r <= add_rx;
		-- ram output
		o_ram_addr <= std_logic_vector(oindex);
		o_ram_data <= std_logic_vector(add_r);
		o_ram_we <= calcdone when DFT_N = Cfg_NoS else L;
	end generate nm;


	process (i_CLK) begin
		if rising_edge(i_CLK) then
			lrEn <= (others => L);
			o_done <= L;
			if (i_Reset = H ) then
				DFT_N <= (others => L);
				aSUM_RE <= (others => L);
				aSUM_IM <= (others => L);
				bSUM_RE <= (others => L);
				bSUM_IM <= (others => L);
				iindex <= "11";
			else
				adc_d_ready_r <= i_adc_d_ready;
				if (iindex=3) then
					calcstart <= L;
					if (i_adc_d_ready=H and adc_d_ready_r=L) then
						aADC <= signed(i_ADC_Data_a(15 downto 0)&L);
						bADC <= signed(i_ADC_Data_b(15 downto 0)&L);
						calcstart <= H;
						a <= signed(i_ADC_Data_a(15 downto 0)&L);
						b <= Cos;
						c <= aSUM_RE;
						iindex <= iindex + 1;
						if (lrRun=H) then
							lrEn <= "11";
							if (lrAddr=1023) then
								lrRun <= L;
							end if;
						end if;
					end if;
				elsif (iindex=0) then
					calcstart <= H;
					a <= a;
					b <= Sin;
					c <= aSUM_IM;
					iindex <= iindex + 1;
					if (lrRun=H) then
						lrAddr <= lrAddr+1;
					end if;
				elsif (iindex=1) then
					calcstart <= H;
					a <= bADC;
					b <= Cos;
					c <= bSUM_RE;
					iindex <= iindex + 1;
				elsif (iindex=2) then
					calcstart <= H;
					a <= a;
					b <= Sin;
					c <= bSUM_IM;
					iindex <= iindex + 1;
				end if;

				if (calcdone=H) then
					if (oindex=0) then
						aSUM_RE <= add_r;
					elsif (oindex=1) then
						aSUM_IM <= add_r;
					elsif (oindex=2) then
						bSUM_RE <= add_r;
					elsif (oindex=3) then
						if (DFT_N > Cfg_Nos) then
							if (ThetaSin=0) then
								DFT_N <= (others => L);
								aSUM_RE <= (others => L);
								aSUM_IM <= (others => L);
								bSUM_RE <= (others => L);
								bSUM_IM <= (others => L);
							end if;
						elsif (DFT_N = Cfg_NoS) then
							aSUM_RE <= (others => L);
							aSUM_IM <= (others => L);
							bSUM_RE <= (others => L);
							bSUM_IM <= (others => L);
							o_aSUM_RE <= std_logic_vector(aSUM_RE);
							o_aSUM_IM <= std_logic_vector(aSUM_IM);
							o_bSUM_RE <= std_logic_vector(bSUM_RE);
							o_bSUM_IM <= std_logic_vector(add_r);
							o_done <= H;
							logenable <= i_logenable;
							if (i_logenable=H and logenable=L) then
								lrRun <= H;
								lrAddr <= (others => H);
							end if;
							if (i_noReSync=L) then
								DFT_N <= DFT_N + 1;
							else
								DFT_N <= (others => L);
							end if;
						else
							DFT_N <= DFT_N + 1;
							bSUM_IM <= add_r;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	DAC/ADC Sequencer
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) then
			if (i_Reset = H ) then
				Start <= L;
				o_DAC_SOC <= L;
				Cfg_DAC_1 <= (others => L);
			else
				Start <= L;
				SinNCos <= L;
				o_DAC_SOC <= L;

				state_cnt <= state_cnt + 1;
				o_ADC_SOC <= L;

				case state_cnt is
				----------------------------------------------------------------
				--	Set DAC_0 (Cosinus)
				----------------------------------------------------------------
				when x"000" =>
					-- ADC StartOfConvert
					o_ADC_SOC <= H;
					if (Cfg_DAC_1 = i_Cfg_DAC_1) then
						o_DAC_Data <= std_logic_vector(NextDacCos);
						o_DAC_Ch <= "01";
						o_DAC_SOC <= H;
					else
						o_DAC_Data <= i_Cfg_DAC_1;
						o_DAC_Ch <= "00";
						o_DAC_SOC <= H;
					end if;
					Cfg_Phase <= unsigned(i_Cfg_Phase & L);
					Cfg_DAC_1 <= i_Cfg_DAC_1;
					ThetaSin <= ThetaSin + Cfg_dTheta;
				when DAC_HALF-10 =>
					Theta <= ThetaSin;
					Start <= H;
				when DAC_HALF-1 =>
					-- * Cfg_DAC0_Gain und runden
					result <= (Cfg_DAC0_Gain * Cos) + 65536;
				when DAC_HALF =>
					NextDacCos <= result(32 downto 17) + Cfg_DAC0_Ofs;
					Theta <= ThetaSin + Cfg_Phase;
					Start <= H;
					SinNCos <= H;
				when DAC_HALF+10 =>
					Sin <= Cos;
					Start <= H;
				when DAC_MAX =>
					state_cnt <= (others => L);
				when others => null;
				end case;

				if (i_resetTheta=H) then
					ThetaSin <= (others => L);
				end if;

			end if;
		end if;
	end process;

	Cos <= signed(iCos(18 downto 2));

--------------------------------------------------------------------------------
--	SinCos_Gen instance
--------------------------------------------------------------------------------
	SiCo_Gen : entity SinCos_Gen.SinCos_GenSeq
	port map (
		i_CLK				=> i_CLK,
		i_Start				=> Start,
		i_Theta				=> std_logic_vector(Theta),
		o_done				=> open,
		o_Cos				=> iCos,
		i_SinNCos			=> SinNCos
	);
--------------------------------------------------------------------------------
--	logger ram instance
--------------------------------------------------------------------------------
	lograma : entity bram.BRAM_4kByte_A16_B16
	port map(
		i_BRAM_Clk_A => i_CLK,
		i_BRAM_EN_A => H,
		i_BRAM_WEN_A => lrEn,
		i_BRAM_Addr_A => std_logic_vector(lrAddr),
		i_BRAM_Dout_A => std_logic_vector(aADC(16 downto 1)),
		i_BRAM_Clk_B => i_lrCLK,
		i_BRAM_EN_B => H,
		i_BRAM_WEN_B => "00",
		i_BRAM_Addr_B => i_lrAddr(10 downto 0),
		o_BRAM_Din_B => o_lrData(31 downto 16)
	);
	logramb : entity bram.BRAM_4kByte_A16_B16
	port map(
		i_BRAM_Clk_A => i_CLK,
		i_BRAM_EN_A => H,
		i_BRAM_WEN_A => lrEn,
		i_BRAM_Addr_A => std_logic_vector(lrAddr),
		i_BRAM_Dout_A => std_logic_vector(bADC(16 downto 1)),
		i_BRAM_Clk_B => i_lrCLK,
		i_BRAM_EN_B => H,
		i_BRAM_WEN_B => "00",
		i_BRAM_Addr_B => i_lrAddr(10 downto 0),
		o_BRAM_Din_B => o_lrData(15 downto 0)
	);


--------------------------------------------------------------------------------
END;
