--------------------------------------------------------------------------------
--  shift_register
--------------------------------------------------------------------------------
--
--	project		: info-sac2
--	programmer	: C. Leuthold, INDEL AG
--	date		: 13.09.2004
--	version		: 1.00
--	language	: VHDL
--	system	: ispLever 3.0
--
--	purpose
--		read and write to shiftregisters like 74HC165 (parallel in seriel out)
--		or 74HC595 seriel in with latched parallel out
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00a   :   13.09.2004-le  : - disc.
--  Rev. 1.00b   :   19.10.2005-le  : - add input i_start
--	11.05.2007-le	add svn keywords
--	24.05.2007-le:	 - add generic C_EXT_CLK for external clock generator.
--						add package INDEL_pkg to replace C_XX_CNT_LNG with
--						pkg_log2()
--	25.05.2007-le:	 - use global const. from INDEL_pkg
--	31.05.2007-le:	 - add outputs o_clkgate and o_done (used to controll 
--						external clock generator)
--	13.07.2007-le:	 - separate statemachine for ext. and int. clock and correct 
--						input at extern clock (missing first bit)
--	19.03.2008-le:	 - correct input at intern clock (missing first bit sended)
--	25.06.2009-le:	 - change input samplepoint to _- of o_serClk
--------------------------------------------------------------------------------
--$Rev:: 1069                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-06-25 11:50:52 +0200 (Do., 25 Jun 2009)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.numeric_std.ALL; 

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;
--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity shift_register is
	generic (
		C_NR_OF_IOS	: natural := 8;	-- nr maximum of used in- and/or outputs
		C_CLK_DIV	: natural := 10;-- ferq(o_serClk) = freq(i_Clk)/(C_CLK_DIV)
		C_EXT_CLK	: natural := 0	-- 0: intern clock generator / 1 extern clk gen
	);
	port (
		i_Clk		: in	std_logic;		-- clock input
		i_Reset		: in	std_logic;		-- reset input H-active
		i_Start		: in	std_logic := H;	-- unconnectet or static H -> continuous mode
		-- serial bus
		o_serClk	: out	std_logic;
		o_serLoad	: out	std_logic;
		o_serData	: out	std_logic;
		i_serData	: in	std_logic;
		-- port for outputs
		i_outputs	: in 	std_logic_vector(C_NR_OF_IOS-1 downto 0);
		-- port for inputs
		o_inputs	: out 	std_logic_vector(C_NR_OF_IOS-1 downto 0);
		o_done		: out	std_logic;
		-- eauxiliary inputs for C_EXT_CLK=1
		i_SampleIn	: in	std_logic := L;
		i_Shift	: in	std_logic := L;
		o_clkgate	: out	std_logic;
		o_sampledinput : out	std_logic
	);
end;								-- of entity shift_register

architecture behavior_shift_register of shift_register is
-- component declarations ------------------------------------------------------
-- types -----------------------------------------------------------------------
	type t_states is (idle, shift, set_outputs, set_outputs2);
-- signals ---------------------------------------------------------------------
	signal sr_state		: t_states := idle;
	signal serClk		: std_logic := L;
	signal clkCnt		: std_logic_vector(pkg_log2(C_CLK_DIV)-1 downto 0) := (others => L);
	signal bitCnt		: std_logic_vector(pkg_log2(C_NR_OF_IOS)-1 downto 0) := (others => L);
	signal shiftReg		: std_logic_vector(C_NR_OF_IOS-1  downto 0)	:= (others => L);
	signal serLoad		: std_logic := H;
	signal input		: std_logic;
	signal reStart		: std_logic;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin										-- of architecture shift_register
	
	o_serData <= shiftReg(shiftReg'high) after 1 ns;
	o_serLoad <= serLoad after 1 ns;
	o_sampledinput <= input;
	int_clk_gen : if C_EXT_CLK = 0 generate
		
		o_serClk <= serClk after 1 ns;
		-- clock gate unused
		o_clkgate <= H;
		
		shift_register : process (i_Reset, i_Clk)
		begin
			if (i_Reset = '1') then
			-- asynch reset statements
			elsif rising_edge(i_Clk) then
			-- clocked statements
				-- serClk	______-_-_-_-_-_-_-_-_______     -_-_-_-_-_-_-_-_-_-_-_-_-
				-- serLoad	_____----------------__--________------------___-------------
				-- o_serD	XXXXX0011223344556677XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
				-- i_serD	XXXXXX00112233445566777777777700112233445566770011223344556677 
				-- i_start	____-________________________ 
				o_done <= L;
				case sr_state is
				when idle =>
					-- set load
					serLoad <= L;
					serClk <= L;
					clkCnt <= (others => L);
					if (i_Start=H) then
						clkCnt(0) <= H; --clkCnt + 1
						-- load sr with new outputs
						shiftReg(i_outputs'high downto 0) <= i_outputs;
						-- reset bit counter
						bitCnt <= (others => L);
						---- set shift
						serLoad <= H;
						-- next state
						sr_state <= shift;
					end if;
				when shift =>
					clkCnt <= clkCnt + 1;
					if (clkCnt=C_CLK_DIV-1) then
						serClk <= L;
						clkCnt <= (others => L);
						bitCnt <= bitCnt + 1;
						if (bitCnt=C_NR_OF_IOS-1) then
							-- set new inputs
							o_inputs <= shiftReg(shiftReg'high-1 downto 0) & input;
							-- set load
							serLoad <= L;
							-- next state
							sr_state <= set_outputs;
							reStart <= i_Start;
						else
							-- set shift
							serLoad <= H;
							shiftReg <= shiftReg(shiftReg'high-1 downto 0) & input;
						end if;
					elsif (clkCnt=(C_CLK_DIV-1)/2) then
						serClk <= serLoad;
						input <= i_serData;
					end if;
				when set_outputs =>
					-- set load
					serLoad <= L;
					serClk <= L;
					clkCnt <= clkCnt + 1;
					if (clkCnt=C_CLK_DIV-1) then
						clkCnt <= (others => L);
						-- set load
						serLoad <= H;
						-- next state
						if (reStart=H) then
							clkCnt(0) <= H; --clkCnt + 1
							sr_state <= shift;
							-- load sr with new outputs
							shiftReg(i_outputs'high downto 0) <= i_outputs;
							-- reset bit counter
							bitCnt <= (others => L);
							o_done <= H;
							sr_state <= shift;
						else
							sr_state <= set_outputs2;
						end if;
						reStart <= L;
					end if;
				when set_outputs2 =>
					-- set load
					serLoad <= H;
					serClk <= L;
					clkCnt <= clkCnt + 1;
					if (clkCnt=C_CLK_DIV-1) then
						clkCnt <= (others => L);
						-- set load
						serLoad <= L;
						-- next state
						sr_state <= idle;
						o_done <= H;
					end if;
				end case;
			end if;
		end process shift_register;
		
	end generate int_clk_gen;
	
	ext_clk_gen : if C_EXT_CLK = 1 generate
		
		o_serClk <= L;
		
		shift_register_extclk : process (i_Reset, i_Clk)
		begin
			if (i_Reset = '1') then
			-- asynch reset statements
			elsif rising_edge(i_Clk) then
				o_done <= L;
			-- clocked statements
				case sr_state is
				when idle =>
					o_clkgate <= L;
					-- set load
					serLoad <= L;
					clkCnt <= (others => L);
					if (i_Start=H) then
						-- load sr with new outputs
						shiftReg(i_outputs'high downto 0) <= i_outputs;
						input <= i_serData;
						-- reset bit counter
						bitCnt <= (others => L);
						-- next state
						sr_state <= shift;
						o_clkgate <= H;
					end if;
				when shift => 
					o_clkgate <= H;
					-- set shift
					serLoad <= H;
					if (i_SampleIn=H) then
						input <= i_serData;
					end if;
					if (i_Shift=H) then
						bitCnt <= bitCnt + 1;
						if (bitCnt=C_NR_OF_IOS-1) then
							-- set new inputs
							o_inputs <= shiftReg(shiftReg'high-1 downto 0) & input;
							sr_state <= set_outputs;
						else
							shiftReg <= shiftReg(shiftReg'high-1 downto 0) & input;
						end if;
					end if;
				when set_outputs =>
					o_clkgate <= L;
					-- set load
					serLoad <= L;
					if (i_Shift=H) then
						-- set load
						serLoad <= H;
						-- next state
						sr_state <= set_outputs2;
					end if;
				when set_outputs2 =>
					o_clkgate <= L;
					-- set load
					serLoad <= H;
					if (i_Shift=H) then
						clkCnt <= (others => L);
						-- next state
						sr_state <= idle;
						o_done <= H;
					end if;
				end case;
			end if;
		end process shift_register_extclk;
		
	end generate ext_clk_gen;
	
end behavior_shift_register;
--------------------------------------------------------------------------------

