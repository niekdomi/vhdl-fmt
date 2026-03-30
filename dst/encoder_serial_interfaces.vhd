--------------------------------------------------------------------------------
--	endat, ssi, hyperface, BISS, GPIO
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	(absolute) encoder serial interface
--------------------------------------------------------------------------------
--
--	project     :
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 21.03.2018
--	version     : 1.00
--	language    : VHDL
--
--	purpose
--		BISS interface
--		read pos only with errorbit, warnigbit and crc: DDDDDDDDDDEWCCCCCC
--		CRC: length, init and poli is configurable. default is 6,0,0x43
--		control communication: not implementet	
--		
--		C_CLK_PRE_DIV switchable colck pre divider: 
--			defined with C_CLK_PRE_DIV and switchable with
--			i_fast_clk. this should allow a new design to run with
--			e.g. 100 MHz replacing a old with running with 25
--			(C_CLK_PRE_DIV=4). new sw can switch to 100 but for older
--			it will always running with 25...
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	21.03.2018-le  : - start
--------------------------------------------------------------------------------
--$Rev:: 4845                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-13 10:19:38 +0200 (Fr., 13 Apr 2018)                         $
--------------------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;
library endat;
use endat.all;

entity encoder_serial_interfaces is
	generic (
		C_CLK_CNT_LNG : integer := 9;
		C_CLK_PRE_DIV : integer range 1 to 8 := 1;
		C_RES2ENC : integer range 0 to 1 := 0
	);
	port (
		i_Clk		: in	std_logic;				-- clock input
		-- config
		i_Config	: in	std_logic_vector(31 downto 0);
		-- data
		i_Data		: in	std_logic_vector(31 downto 0);
		o_Data		: out	std_logic_vector(63 downto 0);
		--Pin controll
		o_sClk		: out	std_logic;
		o_sData		: out	std_logic;
		o_sRef		: out	std_logic;
		o_sClkRnW	: out	std_logic;
		o_sDataRnW	: out	std_logic;
		o_sRefRnW	: out	std_logic;
		i_sClk		: in	std_logic;
		i_sData		: in	std_logic;
		i_sRef		: in	std_logic;
		-- GPIO mode
		i_gpioClk		: in	std_logic := L;
		i_gpioData		: in	std_logic := L;
		i_gpioRef		: in	std_logic := L;
		i_gpioClkRnW	: in	std_logic := L;
		i_gpioDataRnW	: in	std_logic := L;
		i_gpioRefRnW	: in	std_logic := L;
		-- aux
		o_endat_addinfo0 : out	std_logic_vector(31 downto 0);
		o_endat_addinfo1 : out	std_logic_vector(31 downto 0);
		-- cop synch (synch to cop bus clk)
		i_cop_r_data	: in	std_logic;
		-- triggers, sinuspwm...
		i_periodicalStart : in	std_logic;
		o_periodicPosTrig : out	std_logic;
		i_SinPWM	 	: in	std_logic := L;
		i_r2i_a			: in std_logic := L;
		i_r2i_b			: in std_logic := L;
		i_r2i_z			: in std_logic := L

	);
end;

architecture behavior_endat of encoder_serial_interfaces is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal ssi_hip_data_trig: std_logic := L;
	signal endat_pos_trig : std_logic := L;
	signal biss_pos_trig : std_logic := L;
	signal endat_addinfo0_trig : std_logic := L;
	signal endat_addinfo1_trig : std_logic := L;
	
	signal ssi_hip_rxdata : std_logic_vector(63 downto 0) := (others => L);
	signal endat_rxdata	: std_logic_vector(63 downto 0) := (others => L);
	signal biss_rxdata : std_logic_vector(63 downto 0) := (others => L);

	signal addi_cnt0 : std_logic_vector(3 downto 0) := (others => L);
	signal addi_cnt1 : std_logic_vector(3 downto 0) := (others => L);
	
	signal abs_Select : std_logic_vector( 1 downto 0) := DF_SEL_SSI;
	signal ssi_hip_enable : std_logic := L;
	signal endat_enable : std_logic := L;
	signal biss_enable : std_logic := L;
	signal abs_start : std_logic := L;
	signal abs_mode : std_logic_vector( 5 downto 0) := (others => L);
	signal ssi_hip_sClk : std_logic := L;
	signal ssi_hip_sData_out : std_logic := L;
	signal ssi_hip_RnW : std_logic := L;
	signal endat_sClk : std_logic := L;
	signal endat_sData_out : std_logic := L;
	signal endat_RnW : std_logic := L;
	signal biss_sClk : std_logic := L;

	signal endat_data_trig : std_logic := L;
	signal biss_data_trig : std_logic := L;
	
	signal end_start		: std_logic	:= L;
	signal si_written		: std_logic	:= L;
	signal si_written_cop	: std_logic	:= L;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture esi

	o_periodicPosTrig <= endat_pos_trig or biss_pos_trig;

	endat_start : process(i_Clk)
	begin
		if rising_edge(i_Clk) then
			if (ssi_hip_data_trig=H) then
				o_Data <= ssi_hip_rxdata;
			elsif (endat_data_trig=H) then
				o_Data <= endat_rxdata;
			elsif (biss_data_trig=H) then
				o_Data <= biss_rxdata;
			elsif (i_Data(30)=H and (endat_addinfo0_trig=H or endat_addinfo1_trig=H)) then
				-- write addinfo to pos
				o_Data <= endat_rxdata;
			end if;
			if (endat_addinfo0_trig=H) then
				addi_cnt0 <= addi_cnt0+1;
				o_endat_addinfo0 <= endat_rxdata(63 downto 60) & addi_cnt0 & endat_rxdata(23 downto 0);
			end if;
			if (endat_addinfo1_trig=H) then
				addi_cnt1 <= addi_cnt1+1;
				o_endat_addinfo1 <= endat_rxdata(63 downto 60) & addi_cnt1 & endat_rxdata(23 downto 0);
			end if;
			-- i_Data(31) have to toggle
			si_written_cop <= i_Data(31);
			if (si_written_cop/=i_Data(31)) then -- write to si config register
				si_written <= H;
			end if;
			if (i_cop_r_data=H and si_written=H) then
				end_start <= H;
				si_written <= L;
			else
				end_start <= L;
			end if;
		end if;
	end process endat_start;
	
	biss_enc : entity endat.biss
	generic map (
		C_CLK_CNT_LNG => C_CLK_CNT_LNG,
		C_CLK_PRE_DIV => C_CLK_PRE_DIV
	)
	port map (
		i_Clk => i_Clk,
		-- config
		i_clk_div => i_Config(24 downto 16),
		i_data_lng => i_Config(pkg_log2(64)-1 downto 0),
		i_fast_clk => i_Config(27),
		--endat Pin controll
		o_sClk => biss_sClk,
		i_sData => i_sData,
		-- interface
		o_Data => biss_rxdata,
		i_mode => abs_mode,
		i_Data => i_Data(23 downto 0),
		o_data_ready => biss_data_trig,
		o_pos_ready => biss_pos_trig,
		i_Enable => biss_enable,
		i_start => abs_start
	);

	endat22_enc	: entity endat.endat22
	generic map (
		C_CLK_CNT_LNG => C_CLK_CNT_LNG,
		-- old sw expect 25MHz (SAC4) on i_Clk, the new can disable the pre devider with i_fast_clk=H
		C_CLK_PRE_DIV => C_CLK_PRE_DIV
	)
	port map (
		i_Clk => i_Clk,
		-- config
		i_clk_div => i_Config(24 downto 16),
		i_data_lng => i_Config(pkg_log2(64)-1 downto 0),
		i_fast_clk => i_Config(27),
		--endat Pin controll
		o_sClk => endat_sClk,
		i_sData => i_sData,
		o_sData => endat_sData_out,
		o_RnW => endat_RnW,
		-- interface
		o_Data => endat_rxdata,
		i_mode => abs_mode,
		i_Data => i_Data(23 downto 0),
		o_data_ready => endat_data_trig,
		o_pos_ready => endat_pos_trig,
		o_addinfo_ready(0) => endat_addinfo0_trig,
		o_addinfo_ready(1) => endat_addinfo1_trig,
		i_Enable => endat_enable,
		i_start => abs_start
	);
	
	hiper_ssi_enc	: entity endat.endat
	generic map (
		C_SR_LNG => 64,
		C_CLK_CNT_LNG => C_CLK_CNT_LNG,
		C_DATA_CNT_LNG => pkg_log2(64),
		C_HIPERFACE_SUPPORT => 1,
		C_CLK_PRE_DIV => C_CLK_PRE_DIV
	)
	port map (
		i_Clk => i_Clk,
		-- config
		i_clk_div => i_Config(24 downto 16),
		i_data_lng => i_Config(pkg_log2(64)-1 downto 0),
		i_fast_clk => i_Config(27),
		--endat Pin controll
		o_sClk => ssi_hip_sClk,
		i_sData => i_sData,
		o_sData => ssi_hip_sData_out,
		o_RnW => ssi_hip_RnW,
		-- interface
		o_Data => ssi_hip_rxdata,
		i_mode => abs_mode(2 downto 0),
		i_Data => i_Data(23 downto 0),
		o_data_ready => ssi_hip_data_trig,
		i_Enable => ssi_hip_enable,
		i_Select => abs_Select,
		i_start => abs_start
	);

	-- encoder serial interface ------------------------------------------------
	-- support:
	--		SSI: synchron serial interface clock out and data in
	--		RS485 or (soft) hiperface: 2. uart: bidirectoinal data
	--		RS422: 2. uart: clock as data out and data in
	--		EnDat: synchron serial interface clock out and bidirectoinal data
	--		hiperface: read pos. only (need no uart)
	--		biss (c): read pos. only 
	serial_interface_mux: process(i_periodicalStart,i_Config,i_Data,end_start,
								ssi_hip_sClk,ssi_hip_RnW,ssi_hip_sData_out,
								endat_sClk,endat_RnW,endat_sdata_out,
								biss_sclk,
								i_r2i_a,i_r2i_b,i_r2i_z)
	begin
		-- defaults
		-- pins (defaults = GPIOs)
		o_sDataRnW <= i_gpioDataRnW;
		o_sData <= i_gpioData;
		o_sClkRnW <= i_gpioClkRnW;
		o_sClk<= i_gpioClk;
		o_sRefRnW <= i_gpioRefRnW;
		o_sRef <= i_gpioRef;
		-- enables, triggers
		abs_Select <= DF_SEL_SSI;
		ssi_hip_enable <= L;
		endat_enable <= L;
		biss_enable <= L;
		abs_start <= L;
		abs_mode <= i_Data(29 downto 24);
		if ((i_Config(15 downto 12)=DF_ESI_SSI) or
			(i_Config(15 downto 12)=DF_ESI_SSI_CONT)) then
			o_sClkRnW <= H; -- output
			o_sDataRnW <= L; -- input
			ssi_hip_enable <= H;
			o_sClk<= ssi_hip_sClk;
			abs_Select <= DF_SEL_SSI;
			if (i_Config(15 downto 12)=DF_ESI_SSI_CONT) then --DF_ESI_SSI_CONT
				abs_start <= i_periodicalStart;
			else
				abs_start <= end_start;
			end if;
		elsif (i_Config(15 downto 12)=DF_ESI_HIPER) then
			-- clk = default...
			o_sDataRnW <= not(ssi_hip_RnW); -- bidi
			o_sData <= ssi_hip_sData_out;
			ssi_hip_enable <= H;
			abs_Select <= DF_SEL_HIP;
			abs_start <= end_start;
		elsif (i_Config(15 downto 12)=DF_ESI_RS485) then
		elsif (i_Config(15 downto 12)=DF_ESI_RS485_INV) then
		elsif (i_Config(15 downto 12)=DF_ESI_RS422) then
		elsif (i_Config(15 downto 12)=DF_ESI_RS422_INV) then
		elsif  ((i_Config(15 downto 12)=DF_ESI_ENDAT) or
				(i_Config(15 downto 12)=DF_ESI_ENDAT_CONT)) then
			o_sClkRnW <= H; -- output
			o_sDataRnW <= not(endat_RnW); -- bidi
			
			endat_enable <= H;
			o_sClk<= endat_sClk;
			o_sData <= endat_sData_out;
			if ((i_Config(15 downto 12)=DF_ESI_ENDAT_CONT)) then -- DF_ESI_ENDAT_CONT
				abs_start <= i_periodicalStart;
			else
				abs_start <= end_start;
			end if;
		elsif ((i_Config(15 downto 12)=DF_ESI_BISS) or
				(i_Config(15 downto 12)=DF_ESI_BISS_CONT)) then
			o_sClkRnW <= H; -- output
			o_sDataRnW <= L; -- input
			biss_enable <= H;
			o_sClk<= biss_sClk;
			if (i_Config(15 downto 12)=DF_ESI_BISS_CONT) then
				abs_start <= i_periodicalStart;
			else
				abs_start <= end_start;
			end if;
		elsif (i_Config(15 downto 12)=DF_ESI_INC) then
			o_sClkRnW <= L; -- input
			o_sDataRnW <= L; -- input
			o_sRefRnW <= L; -- input 
		elsif (i_Config(15 downto 12)=DF_ESI_RES) then
			o_sClk <= i_SinPWM;
			o_sClkRnW <= H; -- output
		elsif (i_Config(15 downto 12)=DF_ESI_RES2ENC and C_RES2ENC=1) then
			o_sClkRnW <= H; -- output
			o_sDataRnW <= H; -- output
			o_sRefRnW <= H; -- output
			o_sClk<= i_r2i_a;
			o_sData <= i_r2i_b;
			o_sRef <= i_r2i_z;
		end if;
	end process serial_interface_mux;
	
end behavior_endat;
--------------------------------------------------------------------------------

