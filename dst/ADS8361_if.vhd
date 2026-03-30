--------------------------------------------------------------------------------
--	ADS8361 interface
--------------------------------------------------------------------------------
--
--	project		: INFO-SAC2
--	programmer	: Christof Leuthold, INDEL AG
--	date		: 09.09.2004
--	version		: 1.00
--	language	: VHDL
--	system		: ispLever 3.0
--
--	purpose
--		read seriel adc ADS8361 (burr-brown/ti) (INFO-SAC2)
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	Rev. 1.00a	:	09.09.2004-le : - disc.
--	Rev. 1.00b	:	30.11.2004-le :	adjustments for hw-rev A.
--									new generic C_NUM_ADC (default = 3)
--									number of adcs as parameter
--	Rev. 1.00c	:	16.11.2005-le : avoid hangers in statemachine

--	07.09.2006-le:	add generic C_CLK_DIV
--	11.05.2007-le	add svn keywords
--	24.05.2007-le: - add generic C_EXT_CLK for external clock generator.
--						need inputs i_ADCset and i_ADCget 
--	26.07.2011-fb: - ein CLK mehr am Schluss
--	02.02.2011-le: - correct this additional clk for continuous mode (e. g. f max)
--------------------------------------------------------------------------------
--$Rev:: 2222                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2012-02-02 11:10:37 +0100 (Do., 02 Feb 2012)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity ADS8361_if is
	generic (
		C_CLK_PERMANENT : integer := 0;
		C_NUM_ADC		: integer := 3;
		C_CLK_DIV		: integer := 5;
		C_EXT_CLK		: integer := 0
	);
	port (
		i_Clk			: in	std_logic;				-- clock input
		i_Reset			: in	std_logic;				-- reset input H-active
		--ADS8361 Pins
		o_ADCclk		: out	std_logic := '0';
		no_CS			: out	std_logic := '1';
		o_Convst		: out	std_logic := '0';
		o_Read			: out	std_logic := '0';
		o_Addr0			: out	std_logic := '0';
		i_sDataA		: in	std_logic_vector(C_NUM_ADC-1 downto 0);
		i_sDataB		: in	std_logic_vector(C_NUM_ADC-1 downto 0);
		-- interface
		o_DataA			: out	std_logic_vector(16*C_NUM_ADC-1 downto 0);
		o_DataB			: out	std_logic_vector(16*C_NUM_ADC-1 downto 0);
		o_Channel		: out	std_logic_vector(C_NUM_ADC-1 downto 0);
		o_data_ready	: out	std_logic;
		i_next_Channel	: in	std_logic;
		i_start_conv	: in	std_logic;
		-- eauxiliary inputs for C_EXT_CLK=1
		i_ADCset		: in	std_logic := '0';
		i_ADCget		: in	std_logic := '0'
	);
end;													-- of entity ADS8361_if

architecture behavior_ADS8361_if of ADS8361_if is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
	constant H			: std_logic := '1';
	constant L			: std_logic := '0';
	constant Z			: std_logic := 'Z';

	constant CLK_DIV	: integer	:= C_CLK_DIV;			-- CLK_DIV=freq(i_clk)/freq_max(ADCclk)/2=99/10/2
-- types -----------------------------------------------------------------------
	type t_states is (idle,start_conv,set_next_ch,read_ch,clear,read_data,wait_end,wait_end2);
	type t_data	is array (0 to C_NUM_ADC-1) of std_logic_vector(15 downto 0);
-- signals ---------------------------------------------------------------------
	signal ADCclk		: std_logic					:= L;
	signal clk_cnt		: std_logic_vector( 2 downto 0)	:= (others => L);
	signal ADCset		: std_logic					:= L;
	signal ADCget		: std_logic					:= L;
	signal state		: t_states						:= idle;
	signal CS			: std_logic						:= L;
	signal Channel		: std_logic					:= L;
	signal DataA		: t_data	;
	signal DataB		: t_data	;
	signal data_cnt		: std_logic_vector( 3 downto 0)	:= (others => L);
	signal start_clk	: std_logic						:=L;
	signal start_clk_old: std_logic						:=L;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture ADS8361_if

	no_CS <= not(CS);
	o_ADCclk <= ADCclk;
	data_outputs : for i in 0 to C_NUM_ADC-1 generate
		o_DataA(15+i*16 downto 0+i*16) <= DataA(i);
		o_DataB(15+i*16 downto 0+i*16) <= DataB(i);
	end generate data_outputs;

-- processes -------------------------------------------------------------------
int_clk_gen : if C_EXT_CLK = 0 generate
	adc_clk : process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
		elsif rising_edge(i_Clk) then
		-- clocked statements
			clk_cnt <= clk_cnt + 1;
			ADCset <= L;
			ADCget <= L;
			start_clk_old <= start_clk;
			if	C_CLK_PERMANENT = 0 and start_clk = L then
				-- stop clk
				ADCset <= L;
				ADCget <= L;
				clk_cnt <= (others => L);
			elsif C_CLK_PERMANENT = 0 and start_clk = H and start_clk_old = L then
				-- restart clk..
				clk_cnt <= (others => L);
				ADCset <= H;
				ADCclk <= H;
			elsif clk_cnt = CLK_DIV-1 then
				clk_cnt <= (others => L);
				ADCclk <= not(ADCclk);
				if ADCclk = L then
					ADCset <= H;
				end if;
			end if;
			if clk_cnt = CLK_DIV-2 and ADCclk = L then
				ADCget <= H;
			end if;
		end if;
	end process;
end generate int_clk_gen;

ext_clk_gen : if C_EXT_CLK = 1 generate
	ADCset <= i_ADCset;
	ADCget <= i_ADCget;
end generate ext_clk_gen;
	----------------------------------------------------------------------------
	-- clk		C01234567890123456789012345678901234567890
	-- convst	_--__________________--__________________-
	-- rd		_--__________________--__________________-
	-- a0		______________________-___________________
	-- nCs		-_________________________________________
	-- dataX	ZZCHDDDDDDDDDDDDDDDD00CHDDDDDDDDDDDDDDDD00

	process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
		elsif rising_edge(i_Clk) then
		-- clocked statements
			case state is
				when idle =>
					if i_start_conv = H then --start convert
						state <= start_conv;
						Channel <= i_next_Channel;
						o_data_ready <= L;
						if C_CLK_PERMANENT = 0 then
							start_clk <= H;
						end if;
					elsif ADCset=H then
						CS <= L;
						start_clk <= L;
					end if;
				when start_conv =>
					if ADCset=H then
						CS <= H;
						o_Read <= H;
						o_Convst <= H;
						state <= set_next_ch;
					end if;
				when set_next_ch =>
					if ADCset=H then
						o_Addr0 <= Channel;
						state <= read_ch;
					end if;
				when read_ch =>
					if ADCget=H then
						o_Channel <= i_sDataA;
						state <= clear;
					end if;
				when clear =>
					data_cnt <= (others => L);
					if ADCset=H then
						o_Read <= L;
						o_Convst <= L;
						o_Addr0 <= L;
					end if;
					if ADCget=H then
						state <= read_data;
					end if;
				when read_data =>
					if ADCget=H then
						for i in 0 to C_NUM_ADC-1 loop
							DataA(i) <= DataA(i)(14 downto 0) & i_sDataA(i);
							DataB(i) <= DataB(i)(14 downto 0) & i_sDataB(i);
						end loop;
						data_cnt <= data_cnt + 1;
						if data_cnt = 15 then
							state <= wait_end;
							o_data_ready <= H;
						end if;
					end if;
				when wait_end =>
					if ADCset=H then
						state <= wait_end2;
					end if;
				when wait_end2 =>
					if i_start_conv = H and  C_CLK_PERMANENT /= 0 then --start convert
						state <= start_conv;
						Channel <= i_next_Channel;
						o_data_ready <= L;
					elsif ADCset=H then
						state <= idle;
					end if;
			end case;
		end if;
	end process;										-- END of process NAME
end behavior_ADS8361_if;								-- END of architecture ADS8361_if
--------------------------------------------------------------------------------

