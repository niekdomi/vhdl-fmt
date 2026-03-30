--------------------------------------------------------------------------------
--  sinGen
--------------------------------------------------------------------------------
--
--  project     : PWsinGenM
--  programmer  : C. LEuthold, INDEL AG
--  date        : 08.09.2004
--  version     : 1.00
--  language    : VHDL
--  system      :
--
--  purpose     : sinGen-component
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00d   :   21.10.2004-le  : - disc.
--	11.05.2007-le	add svn keywords
--	15.05.2007-le	change address-calculation
--	22.05.2007-le	add C_NUM_SINGEN for multiple sinGens (sac3x3):
--						out o_SinGenPWM as vector (C_NUM_SINGEN-1 downto 0),
--						data as i_dprData(C_NUM_SINGEN*C_SIN_CNT_LENGTH-1 downto 0)
--						in ram
--	01.06.2007-le	syntax corrected, add pakage indel_pkg
--	29.04.2009-le	new single ram multi sinusgenerator with gain and phaseshift
--	24.07.2009-le	add 16bit signed value out for C_NEW_SINGEN
--	29.09.2009-le	new singen are 180° to old singen: compare of unsigned and signed!
--	30.09.2009-le	correct read pipe
--	28.11.2013-le	add a clockenabel
--------------------------------------------------------------------------------
--$Rev:: 3115                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-11-28 12:00:48 +0100 (Do., 28 Nov 2013)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity SinGen is
	generic (
		C_SIN_CNT_LENGTH	: integer := 8;
		C_FAKT_LENGTH		: integer := 3;
		C_NUM_SINGEN		: integer := 3;
		C_ADDR_LENGTH		: integer := 9;
		C_NEW_SINGEN		: integer := 0
	);
	port (
		i_Clk		: in    std_logic;
		i_clken		: in	std_logic := '1';-- clocken input
		i_Reset		: in    std_logic;
		-- Dualport Ram access
		o_dprEN		: OUT	std_logic;
		o_dprClk	: OUT	std_logic;
		o_dprRst	: OUT	std_logic;
		o_dprWEN	: OUT	std_logic_vector(3 downto 0);
		o_dprData	: out	STD_LOGIC_VECTOR(31 downto 0);
		i_dprData	: in	STD_LOGIC_VECTOR(31 downto 0);
		o_dprAddr	: OUT	std_logic_vector(C_ADDR_LENGTH-1 downto 0);	-- DP-RAM Adr
		--
		i_PWMcntMax	: in	std_logic_vector(C_SIN_CNT_LENGTH-1 downto 0);
		i_Faktor	: in	std_logic_vector(C_FAKT_LENGTH-1 downto 0);
		i_sync		: in	std_logic;
		i_gain		: in	std_logic_vector(C_NUM_SINGEN*C_SIN_CNT_LENGTH-1 downto 0) := (others => L);
		i_phase		: in	std_logic_vector(C_NUM_SINGEN*C_SIN_CNT_LENGTH-1 downto 0) := (others => L);
		o_SinGenPWM	: out	std_logic_vector(C_NUM_SINGEN-1 downto 0);
		o_SinVal	: out	std_logic_vector(C_NUM_SINGEN*16-1 downto 0) -- value out 16bit signed
	);
end SinGen;

architecture Behavioral of SinGen is
-- component declarations ------------------------------------------------------

-- constants -------------------------------------------------------------------

-- types -----------------------------------------------------------------------

-- signals ---------------------------------------------------------------------
	signal clk			: std_logic;
	signal sgPWMcnt		: unsigned(C_SIN_CNT_LENGTH-1 downto 0) := (others => L);
	

-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin -- of architecture PWM
	clk <= i_Clk;
	o_dprClk <= clk;
	o_dprRst <= L;
	o_dprWEN <= (others => L);
	o_dprEN <= i_clken;
	
	old_singen : if C_NEW_SINGEN=0 generate
		signal dprAddr : unsigned(C_ADDR_LENGTH-1 downto 0):=(others => L);
		type tPWM_val is array (C_NUM_SINGEN-1 downto 0) of unsigned(C_SIN_CNT_LENGTH-1 downto 0);
		signal PWM_val : tPWM_val := (others => (others => L));
	begin
		
		o_SinVal <= (others => L);
		gen: for i in 0 to C_NUM_SINGEN-1 generate
			PWM_val(i) <= unsigned(i_dprData(i*C_SIN_CNT_LENGTH+C_SIN_CNT_LENGTH-1 downto i*C_SIN_CNT_LENGTH));
		end generate gen;
		o_dprAddr <= std_logic_vector(dprAddr);
	
		process (clk)
		begin
			if rising_edge(clk) then
				if i_clken=H then
					if sgPWMcnt>=unsigned(i_PWMcntMax) then
						sgPWMcnt <= (others => L);
						dprAddr <= dprAddr + unsigned(i_Faktor);
					else
						sgPWMcnt <= sgPWMcnt + 1;
					end if;
					for i in 0 to C_NUM_SINGEN-1 loop
						if sgPWMcnt>=PWM_val(i) then
							o_SinGenPWM(i) <= H;
						else
							o_SinGenPWM(i) <= L;
						end if;
					end loop;
					if i_sync=H then
						sgPWMcnt <= (others => L);
						dprAddr <= (others => L);
					end if;
				end if;
			end if;
		end process;
	end generate old_singen;
	
	new_singen : if C_NEW_SINGEN=1 generate
		type tPWM_val is array (C_NUM_SINGEN-1 downto 0) of signed(C_SIN_CNT_LENGTH-1 downto 0);
		signal PWM_val		: tPWM_val := (others => (others => L));
		type t_addr_arr is array (C_NUM_SINGEN-1 downto 0) of unsigned(C_ADDR_LENGTH-1 downto 0);
		signal dprAddr : t_addr_arr :=(others => (others => L));
		signal ind : natural range 0 to C_NUM_SINGEN := 0;
		signal ind_1 : natural range 0 to C_NUM_SINGEN := 0;
		signal ind_2 : natural range 0 to C_NUM_SINGEN := 0;
		signal ind_3 : natural range 0 to C_NUM_SINGEN := 0;
		signal i_cnt : unsigned(pkg_log2(C_NUM_SINGEN) downto 0) := (others => L);
		signal i_cnt_1 : unsigned(pkg_log2(C_NUM_SINGEN) downto 0) := (others => L);
		signal i_cnt_2 : unsigned(pkg_log2(C_NUM_SINGEN) downto 0) := (others => L);
		signal i_cnt_3 : unsigned(pkg_log2(C_NUM_SINGEN) downto 0) := (others => L);
		signal new_val : std_logic := L;
		signal mul : signed(16 downto 0);
		type tSinVal is array (C_NUM_SINGEN-1 downto 0) of signed(15 downto 0);
		signal SinVal : tSinVal;
		signal l_PWM_val : signed(C_SIN_CNT_LENGTH downto 0);
		signal faktor : unsigned(C_ADDR_LENGTH-1 downto 0) := (others => L);
		type tGain is array (C_NUM_SINGEN-1 downto 0) of signed(C_SIN_CNT_LENGTH downto 0);
		signal gain : tGain;
		signal phase : t_addr_arr :=(others => (others => L));
		signal acalc : unsigned(C_ADDR_LENGTH-1 downto 0);
		signal p_0 : std_logic := L;
		signal p_1 : std_logic := L;
		signal p_2 : std_logic := L;
	begin
		ind <= conv_integer(i_cnt);
		ind_1 <= conv_integer(i_cnt_1);
		ind_2 <= conv_integer(i_cnt_2);
		ind_3 <= conv_integer(i_cnt_3);
		o_dprAddr <= std_logic_vector(acalc);
		-- index
		process (clk)
		begin
			if rising_edge(clk) then
				if i_clken=H then
					i_cnt_1 <= i_cnt;
					i_cnt_2 <= i_cnt_1;
					i_cnt_3 <= i_cnt_2;
					p_1 <= p_0;
					p_2 <= p_1;
					if i_sync=H then
						for i in 0 to C_NUM_SINGEN-1 loop
							dprAddr(i) <= phase(i);
						end loop;
						i_cnt <= (others => L);
						p_0 <= L;
					else
						p_0 <= L;
						if (new_val=H) then
							i_cnt <= (others => L);
						elsif (i_cnt<C_NUM_SINGEN) then
							i_cnt <= i_cnt + 1;
							acalc <= dprAddr(ind) + faktor;
							p_0 <= H;
						end if;
						if (p_0=H) then
							dprAddr(ind_1) <= acalc;
	--						mul <= signed(i_dprData(C_SIN_CNT_LENGTH-1 downto 0))*gain(ind_1);
						end if;
						if (p_1=H) then
							mul <= signed(i_dprData(C_SIN_CNT_LENGTH-1 downto 0))*gain(ind_2);
						end if;
						if (p_2=H) then
							PWM_val(ind_3) <= l_PWM_val(C_SIN_CNT_LENGTH downto 1);
							SinVal(ind_3) <= mul(16 downto 1);
						end if;
					end if;
				end if;
			end if;
		end process;
		
		faktor(C_FAKT_LENGTH-1 downto 0) <= unsigned(i_Faktor);
		
		l_PWM_val <= (mul(16 downto 8) + signed(i_PWMcntMax) + 1);
		
		gen: for i in 0 to C_NUM_SINGEN-1 generate
			gain(C_NUM_SINGEN-1-i) <= signed(L & i_gain(i*C_SIN_CNT_LENGTH+C_SIN_CNT_LENGTH-1 downto i*C_SIN_CNT_LENGTH));
			phase(C_NUM_SINGEN-1-i)(C_SIN_CNT_LENGTH-1 downto 0) <= unsigned(i_phase(i*C_SIN_CNT_LENGTH+C_SIN_CNT_LENGTH-1 downto i*C_SIN_CNT_LENGTH));
			o_SinVal(i*16+16-1 downto i*16) <= std_logic_vector(SinVal(i));
		end generate gen;
		
		process (clk)
		begin
			if rising_edge(clk) then
				if i_clken=H then
					-- pwm cnt with syncher
					new_val <= L;
					if i_sync=H then
						sgPWMcnt <= (others => L);
					else
						if sgPWMcnt=unsigned(i_PWMcntMax) then
							sgPWMcnt <= (others => L);
							new_val <= H;
						else
							sgPWMcnt <= sgPWMcnt + 1;
						end if;
					end if;
					-- pwm generator
					for i in 0 to C_NUM_SINGEN-1 loop
						if sgPWMcnt>=unsigned(PWM_val(i)) then
							o_SinGenPWM(i) <= H;
						else
							o_SinGenPWM(i) <= L;
						end if;
					end loop;
				end if;
			end if;
		end process;
	end generate new_singen;

end Behavioral;
