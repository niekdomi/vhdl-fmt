--------------------------------------------------------------------------------
--
--  ADC AD7606
--
--------------------------------------------------------------------------------
--
--  project     : ADC AD7606
--  programmer  : M.Suter, INDEL AG
--  date        : 09.06.2011
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- ADC AD7606
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	09.06.2011-MS	- first Version, parallel and byte mode impl.
--					  serial mode not released yet
--	26.07.2011-le	- puwerup conditions as described in APPLICATION NOTE AN-1091
--	04.01.2012-le	- add o_last_stored
--	25.10.2012-rk	- serial mode implemented
-- 					- ADC_AUTOSYNC can be disabled
--	26.10.2012-fb	- generic store adc in revers order
--	18.01.2013-rk	- PowerOn Reset Sequence not depends on CLK_FREQ
--------------------------------------------------------------------------------
--$Rev:: 2646                                                                  $
--$Author:: Roli                                                               $
--$Date:: 2013-01-18 09:12:49 +0100 (Fr., 18 Jan 2013)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity ADC_AD7606 is
	generic (
		CLK_FREQ			: integer := 25;		--in MHz
		ADC_DATA_WITH		: integer := 16;		--data length of data bus
		ADC_MODE			: integer := 0;			--ADC Mode: 0: Parallel mode
													-- 			1: Byte mode
													-- 			2: Serial mode
		ADC_AUTOSYNC		: integer := 1;			-- sync. automatic between cyclic reads
		ADC_RD_WHILE_CONV	: integer := 0;			-- read ADC while conversion (serial mode)
		ADC_SCKDIV			: integer := 6;			-- divisor for ADC_SCLK
		ADC_ReversOrder		: integer := 0			-- store adc in revers order 7..0
	);
	port(
		i_Clk			: in 	std_logic;
		i_Reset			: in	std_logic;

		o_Tst			: out std_logic;
		o_ADC			: out	tSLV_Nx16(0 to 7);					--reg. with ADC data
		i_ADC_Status 	: in 	std_logic_vector(15 downto 0);		--status from bus
		i_ADC_Read		: in  	std_logic := '0';					--Read ADC signal from bus
		i_ADC_Start		: in  	std_logic := '0';					--Start ADC Conversion
		o_last_stored	: out	std_logic;
	    no_ADC_CS		: out	std_logic;
		no_ADC_RD		: out 	std_logic;
		o_ADC_SOC		: out 	std_logic;
		o_ADC_OS		: out 	std_logic_vector( 2 downto 0);
		o_ADC_StBy		: out 	std_logic;
		o_ADC_Reset		: out 	std_logic;
		o_ADC_Range		: out 	std_logic;
		i_ADC_Busy		: in  	std_logic;
		i_ADC_Fdat		: in  	std_logic;
		i_ADC_Dat		: in  	std_logic_vector(ADC_DATA_WITH-1 downto 0)
    );
end ADC_AD7606;

architecture impl of ADC_AD7606 is
	----------------------------------------------------------------------------
	--	constants for calculate the adc conv time (ns)
	----------------------------------------------------------------------------
	-- Conv Time = ADC_tConv + 8 * (2000/CLK_FREQ) + reserve
	-- ADC_tConv OS 0: 4.15us
	-- ADC_tConv OS 2: 9.1us
	-- ADC_tConv OS 4: 18.8us
	-- ADC_tConv OS 8: 39us
	-- ADC_tConv OS 16: 78us
	-- ADC_tConv OS 32: 158us
	-- ADC_tConv OS 64: 315us

	constant C_RESERVE			: integer := 400;
	constant C_Conv_Time_0		: integer := (4150 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;
	constant C_Conv_Time_2		: integer := (9100 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;
	constant C_Conv_Time_4		: integer := (18800 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;
	constant C_Conv_Time_8		: integer := (39000 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;
	constant C_Conv_Time_16		: integer := (78000 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;
	constant C_Conv_Time_32		: integer := (158000 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;
	constant C_Conv_Time_64		: integer := (315000 + 8 * (2000/CLK_FREQ) * (16/ADC_DATA_WITH) + C_RESERVE)/40;

	constant C_Wake_Shtdwn		: integer := (30000 * CLK_FREQ);	-- 30ms
	constant C_Rst_Pulse		: integer := CLK_FREQ / 2;			-- 500ns
	----------------------------------------------------------------------------
	--	ADC
	----------------------------------------------------------------------------

	signal	ADC_RD	 		: std_logic 							:= L;
	signal 	ADC_Sync_Time	: std_logic_vector(15 downto 0)			:= (others => '0');
	signal 	ADC_Timer		: std_logic_vector(15 downto 0)			:= (others => '0');
	signal 	ADC_MSBy 		: std_logic;
	signal	ADC_SOC			: std_logic 							:= L;
	signal 	ADC_Ch	 		: std_logic_vector( 3 downto 0)			:= x"8";
	signal 	ADC_RvsOdr_Ch	: std_logic_vector( 3 downto 0)			:= x"0";
	signal 	ADC_Read		: std_logic;
	signal 	ADC_CS			: std_logic;
	signal 	ADC_Status		: std_logic_vector(15 downto 0);

	-- Busy-syncher
	signal	ADC_Bsy_1		: std_logic 							:= L;
	signal	ADC_Bsy_2		: std_logic 							:= L;
	signal	ADC_EOC			: std_logic 							:= L;
	signal	ADC_CSTART		: std_logic 							:= L;

	signal 	ADC_OS			: std_logic_vector(2 downto 0) 			:= (others => '0');
	signal 	Conv_Time		: integer Range  0 to C_Conv_Time_64	:= 0;

	signal 	ADC				: tSLV_Nx16(0 to 7);

	signal poweronCnt		: std_logic_vector(21 downto 0)			:= (others => '0');

	-- Serial Mode
	signal clkCnt			: std_logic_vector( 3 downto 0);
	signal shift_cnt		: std_logic_vector( 3 downto 0);
	signal shiftR_clk		: std_logic 							:= L;
	signal storeValue		: std_logic 							:= L;
	signal ADC_SCLK			: std_logic 							:= '1';
    signal shReg_A			: std_logic_vector(15 downto 0);
    signal shReg_B			: std_logic_vector(15 downto 0);


	begin
	--------------------------------------------------------------------
	--	In/Out
	--------------------------------------------------------------------
	o_ADC 			<= ADC;
	ADC_Status 		<= i_ADC_Status;
	ADC_OS			<= ADC_Status(2 downto 0);
	o_ADC_OS		<= ADC_OS;
	no_ADC_RD		<= not 	ADC_RD;
	no_ADC_CS		<= not 	ADC_CS;
	o_ADC_OS		<= ADC_Status(2 downto 0);
	o_ADC_SOC		<= ADC_SOC;
	ADC_Read 		<= i_ADC_Read;

	o_Tst <= shiftR_clk;

	process(i_Clk) begin
		if rising_edge(i_Clk) then
			-- APPLICATION NOTE AN-1091
			---         |t1 |  t2 |
			-- nStBy XXX____---------
			-- Range XXX____
			-- Reset XXX__________-__
			-- t1 500ns
			-- t2 30ms
			poweronCnt <= poweronCnt + 1;
			if poweronCnt<C_Rst_Pulse then
				o_ADC_StBy <= H;
				o_ADC_Range <= L;
				o_ADC_Reset <= L;
			elsif poweronCnt=C_Rst_Pulse then
				o_ADC_StBy <= L;
			elsif poweronCnt=C_Wake_Shtdwn+C_Rst_Pulse then
				o_ADC_Reset <= H;
			elsif poweronCnt=C_Wake_Shtdwn+C_Rst_Pulse+C_Rst_Pulse then
				o_ADC_StBy <= ADC_Status(5);
				o_ADC_Range <= ADC_Status(3);
				o_ADC_Reset <= ADC_Status(4);
				poweronCnt <= poweronCnt;
			end if;
		end if;
	end process;
	-- end of convert:	Busy ---+__
    ADC_EOC <= ADC_Bsy_2 and (not ADC_Bsy_1);

	-- start of convert:	Busy __+---
	ADC_CSTART <= (not ADC_Bsy_2) and ADC_Bsy_1;

	--------------------------------------------------------------------
	--	ADC Serial Mode
	--  DB7 and DB8 adc_dat are used as DataIn
	--------------------------------------------------------------------
	Serial_Mode : if ADC_Mode = 2 generate
	begin

	ADC_RD <= not ADC_SCLK;

	process(i_Clk) begin
		if rising_edge(i_Clk) then
			-- synch Busy to Q25
			ADC_Bsy_1	<= i_ADC_Busy;
			ADC_Bsy_2	<= ADC_Bsy_1;

			o_last_stored <= L;

			--------------------------------------------------------------------
			--	start ADC RD sequence
			--------------------------------------------------------------------
			if (ADC_RD_WHILE_CONV = 1) then
				if (ADC_CSTART = '1') then
					ADC_CS <= '1';
					ADC_Ch <= x"0";
				end if;
            else
				if (ADC_EOC = '1') then
					ADC_CS <= '1';
					ADC_Ch <= x"0";
				end if;
			end if;
			--------------------------------------------------------------------
			--	ADC shift Clock
			--------------------------------------------------------------------
            if (ADC_CS = '0') then
            	clkCnt <= (others => '0');
                shiftR_clk <= '0';
                ADC_SCLK <= '1';
			else
				if (clkCnt < (ADC_SCKDIV-1)) then
					clkCnt <= clkCnt + 1;
	                shiftR_clk <= '0';
				else
	            	clkCnt <= (others => '0');
	                shiftR_clk <= '1';
				end if;
				if (clkCnt < (ADC_SCKDIV / 2)) then
	                ADC_SCLK <= '1';
	            else
	                ADC_SCLK <= '0';
	            end if;
            end if;

			--------------------------------------------------------------------
			--	ADC shift Registers
			--------------------------------------------------------------------
            if (shiftR_clk = '1') then
            	shReg_A <= shReg_A(14 downto 0) & i_ADC_Dat(7);
            	shReg_B <= shReg_B(14 downto 0) & i_ADC_Dat(8);
            end if;

			storeValue <= '0';
			if (shiftR_clk = '1') then
				if (shift_cnt < 15) then
					shift_cnt <= shift_cnt + 1;
				else
					shift_cnt <=  (others => '0');
					storeValue <= '1';
				end if;
			end if;

			--------------------------------------------------------------------
			--	Read ADC channels
			--------------------------------------------------------------------
			if (storeValue = '1') then
				--read value
				ADC(CONV_INTEGER(ADC_Ch))<= shReg_A;
				ADC(CONV_INTEGER(ADC_Ch+4))<= shReg_B;
				-- next channel
				ADC_Ch <= ADC_Ch + 1;

				if (ADC_Ch = 3) then
					o_last_stored <= H;
					ADC_CS <= '0';
				end if;
			end if;
		end if;
	end process;

	end generate Serial_Mode;

	--------------------------------------------------------------------
	--	ADC Byte Mode
	--  lower byte of adc_dat is used
	--------------------------------------------------------------------
	Byte_Mode : if ADC_Mode = 1 generate
	begin

	ADC_CS <= ADC_RD;

	process(i_Clk) begin
		if rising_edge(i_Clk) then
			-- synch Busy to Q25
			ADC_Bsy_1	<= i_ADC_Busy;
			ADC_Bsy_2	<= ADC_Bsy_1;
			ADC_RD   	<= L;

			o_last_stored <= L;

			--------------------------------------------------------------------
			--	start ADC RD sequence
			--------------------------------------------------------------------
			if (ADC_EOC = H) then
				ADC_RD <= H;
				ADC_Ch <= x"0";
				ADC_MSBy <= H;
			end if;

			--------------------------------------------------------------------
			--	Read all ADC channels
			--------------------------------------------------------------------
			if (ADC_RD = L) and (ADC_Ch < x"8") then
				if  ADC_MSBy = H then
					-- save ADC-Val MSByte of actual channel
					ADC(CONV_INTEGER(ADC_Ch))(15 downto 8) <= i_ADC_Dat;
					ADC_MSBy <= L;
				elsif ADC_MSBy = L then
					-- save ADC-Val LSByte of actual channel
					ADC(CONV_INTEGER(ADC_Ch))(7 downto 0) <= i_ADC_Dat;
					ADC_MSBy <= H;
					-- next channel
					ADC_Ch <= ADC_Ch + 1;

					if (ADC_Ch = 7) then
						o_last_stored <= H;
					end if;

				end if;

				-- do we need an other read?
				if (ADC_Ch < x"7")or (ADC_Ch = (x"7") and ADC_MSBy = H) then
					ADC_RD <= H;
				end if;
			end if;
		end if;
	end process;
	end generate Byte_Mode;


	--------------------------------------------------------------------
	--	ADC Parallel Mode (16 bit databus)
	--------------------------------------------------------------------
	Parallel_Mode : if ADC_Mode = 0 generate
	begin

	-- f.e. COP_ADA has invers order on siganl connector
	ADC_RvsOdr_Ch <= 7 - ADC_Ch;
	ADC_CS <= ADC_RD;

	process(i_Clk) begin
		if rising_edge(i_Clk) then
			-- synch Busy to Q25
			ADC_Bsy_1	<= i_ADC_Busy;
			ADC_Bsy_2	<= ADC_Bsy_1;
			ADC_RD   	<= L;
			o_last_stored <= L;

			--------------------------------------------------------------------
			--	start ADC RD sequence
			--------------------------------------------------------------------
			if (ADC_EOC = H) then
				ADC_RD <= H;
				ADC_Ch <= x"0";
			end if;

			--------------------------------------------------------------------
			--	Read all ADC channels
			--------------------------------------------------------------------
			if (ADC_RD = L) and (ADC_Ch < x"8") then
				--read value
				if (ADC_ReversOrder = 0) then
					ADC(CONV_INTEGER(ADC_Ch))<= i_ADC_Dat;
				else
					ADC(CONV_INTEGER(ADC_RvsOdr_Ch))<= i_ADC_Dat;
				end if;
				-- next channel
				ADC_Ch <= ADC_Ch + 1;
				-- do we need an other read?
				if (ADC_Ch < x"7") then
					ADC_RD <= H;
				end if;

				if (ADC_Ch = 7) then
					o_last_stored <= H;
				end if;
			end if;
		end if;
	end process;
	end generate Parallel_Mode;


	--------------------------------------------------------------------------------
	--	ADC	AutoSynch
	--------------------------------------------------------------------------------
	--	Ich messe die Zeit von C64_ADC-Read zu Read
	--	und setze sync time mit Zeit - conv_time 	(max conv time + reserve)
	--	somit beinhaltet das adc register, kurz vor absenden der daten aktuelle werte
	-- 	Ist die Samplingrate höher all die benötigte conv time, so wird nur bei jedem
	--	zweiten oder gar dritten buszyklus ein neuer wert zurück gesendet.
	-------------------------------------------------------------------------------
	AutoSyn: if ADC_AUTOSYNC = 1 generate
	begin

	process(i_Clk)
	begin
		if rising_edge(i_Clk) then
			if (i_Reset = H) then
				ADC_Timer <= x"0000";
			else
				-- reading ADC-0 ?
				if(ADC_Read = H) and (ADC_Timer > Conv_Time)then
					ADC_Sync_Time <= ADC_Timer - Conv_Time;
					ADC_Timer <= x"0000";
				else
					ADC_Timer <= ADC_Timer + 1;
				end if;

				ADC_SOC <= L;
				-- check if ADC StartOfConv time
				if (ADC_Timer = ADC_Sync_Time) then
					ADC_SOC <= H;
				end if;

				--Conv_Time from Tabel
				case ADC_OS is
					when "000" => Conv_Time <= C_Conv_Time_0;
					when "001" => Conv_Time <= C_Conv_Time_2;
					when "010" => Conv_Time <= C_Conv_Time_4;
					when "011" => Conv_Time <= C_Conv_Time_8;
					when "100" => Conv_Time <= C_Conv_Time_16;
					when "101" => Conv_Time <= C_Conv_Time_32;
					when "110" => Conv_Time <= C_Conv_Time_64;
					when others => Conv_Time <= C_Conv_Time_0;
				end case;
			end if;
		end if;
	end process;

	end generate AutoSyn;

--------------------------------------------------------------------------------
	ExtSyn: if not (ADC_AUTOSYNC = 1) generate
	-- Start of convert comes from external
	begin
		ADC_SOC <= i_ADC_Start;

	end generate ExtSyn;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
