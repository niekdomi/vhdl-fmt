--------------------------------------------------------------------------------
--  sigma_delta_synchron.vhd
--------------------------------------------------------------------------------
--
--	project     : INFO-SAC2
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 24.05.2007
--	version     : 1.00
--	language    : VHDL
--
--	purpose
--		sigma_delta for 1..x syncron sd adcs (ad7401)
--		C_NUM_SD_DEVICES maximum = freq(i_dataready)/freq(i_clk)  (10 for 10 Mhz
--		sd-clk and 100mhz system clk)
--		C_CLK_DIV minimum is 4 if piplined subtractor is used 
--		examples of 3th order sinc filters:
--		------------------------------------------------------------------------
--		|	Decimation	|SNR	|ENOB	|Data Rate	|f-3dB	|Response	|gainDC
--		|	Ratio (M)	|(dB)	|(Bits)	|(kHz)		|(kHz)	|(us)		|(Bits)
--		|---------------|-------|-------|-----------|-------|-----------|-------
--		|	4			|24.99	|3.9	|2500.0		|655	|1.2		|6
--		|	8			|40.04	|6.4	|1250.0		|327.5	|2.4		|9
--		|	16			|55.09	|8.9	|625.0		|163.7	|4.8		|12
--		|	32			|70.14	|11.4	|312.5		|81.8	|9.6		|15
--		|	64			|85.19	|13.9	|156.2		|40.9	|19.2		|18
--		|	128			|100.24	|16.4	|78.1		|20.4	|38.4		|21
--		|	256			|115.30	|18.9	|39.1		|10.2	|76.7		|24
--		------------------------------------------------------------------------
--		references:
--		 - TI application SBAA094
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	24.05.2007-le:	- start
--	03.07.2007-le:	- rename some signals
--	18.10.2007-le:	- add ram interface
--					- remove generic C_BIT_RES
--					- solve overrun at positive maximum (goes to 0xFFFF)
--	22.10.2007-le:	- add C_ORDER
--	22.10.2008-le:	- wrong data at ch0 when num of devices is less and not 
--					  equal then busclock/sdclock:
--					  correct outregs, add calc_en as clk enable
--	30.04.2010-le:	- remove i_reset (unused)
--					- add i_clear to clear the dezimation counter (integrators 
--					  and differentiators uncleared)
--					- add i_half_dezi to change filter dezimation
--					  works not proper on sac (offset at switch)
--	18.02.2021-le:	- add DataReady single pulse for parallel data out
--					- clear: correct init of decimation counter 
--------------------------------------------------------------------------------
--$Rev:: 5817                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2021-02-18 10:38:35 +0100 (Do., 18 Feb 2021)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity sigma_delta_synchron is
	generic (
		C_ORDER : positive := 3;
		C_OVERRANGE	: natural := 25;
		C_CLK_DIV	: natural range 4 to 1024 := 32;
		C_REG_LNG	: natural := 16;
		C_NUM_SD_DEVICES : positive := 5;
		C_WE_SEQ : natural range 0 to 256 := 0;
		C_USE_SINGLE_SUB : natural range 0 to 1 := 0;
		C_NO_OUTREG : natural range 0 to 1 := 0
	);
	port (
		i_Clk       : in    std_logic;                  -- clock input
		i_dataready	: in	std_logic;
		i_clear		: in	std_logic := L;
		i_half_dezi	: in	std_logic := L;
		--sigma_delta Pins
		i_sData		: in	std_logic_vector(C_NUM_SD_DEVICES-1 downto 0);
		-- interface
			-- parallel data out in with single pulse DataReady. do not work with C_NO_OUTREG=1
		o_DataLA	: out	std_logic_vector(C_NUM_SD_DEVICES*C_REG_LNG-1 downto 0);
		o_DataReady	: out	std_logic := L;
			-- sequential data out with we over hole data output 
		o_RAMData : out std_logic_vector(C_REG_LNG-1 downto 0);
		o_RAMAddr : out std_logic_vector(pkg_log2(C_NUM_SD_DEVICES)-1 downto 0);
		o_WE : out std_logic;
		-- overrange
		o_overrange	: out	std_logic_vector(C_NUM_SD_DEVICES-1 downto 0)
	);
end;                                                    -- of entity sigma_delta_synchron

architecture behavior_sigma_delta_synchron of sigma_delta_synchron is
-- constants -------------------------------------------------------------------
	constant DF_BIT_RES : positive := pkg_log2(C_CLK_DIV)*C_ORDER+1;
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal i_cnt : std_logic_vector(pkg_log2(C_NUM_SD_DEVICES)-1 downto 0) := (others => L);
	signal i : natural range 0 to C_NUM_SD_DEVICES-1 := 0;
	signal calc_en : std_logic := L;
	signal clk_div : std_logic_vector(pkg_log2(C_CLK_DIV)-1 downto 0) := (others => L);
	
	signal sData : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
	signal oldData : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
	signal overrange : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
	type t_or_cnt is array (C_NUM_SD_DEVICES-1 downto 0) of std_logic_vector(pkg_log2(C_OVERRANGE)-1 downto 0);
	constant or_cnt_null : std_logic_vector(pkg_log2(C_OVERRANGE)-1 downto 0) := (others => L);
	signal or_cnt : t_or_cnt := (others => or_cnt_null);
	
	type t_filter_reg is array (C_NUM_SD_DEVICES-1 downto 0) of std_logic_vector(DF_BIT_RES-1 downto 0);
	constant filter_reg_null : std_logic_vector(DF_BIT_RES-1 downto 0) := (others => L);
	constant arr_reg_null : t_filter_reg := (others => filter_reg_null);
	type t_acc_arr_reg is array (C_ORDER-1 downto 0) of t_filter_reg;
	signal ACC : t_acc_arr_reg := (others => arr_reg_null);
	type t_diff_arr_reg is array (C_ORDER-1 downto 0) of t_filter_reg;
	signal DIFF : t_diff_arr_reg := (others => arr_reg_null);
	signal outreg : t_filter_reg := (others => filter_reg_null);
	signal HOLD : t_filter_reg := (others => filter_reg_null);
	signal sub : std_logic_vector(DF_BIT_RES-1 downto 0);
	signal we : std_logic := L;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin
	
	spez1 : if C_NUM_SD_DEVICES=1 generate
		i <= 0;
	end generate spez1;
	
	multidev : if C_NUM_SD_DEVICES>1 generate
		i <= conv_integer(i_cnt);
	end generate multidev;
	
	o_overrange <= overrange;
	
	o_RAMAddr <= i_cnt;
	
	C_REG_LNG_bigger : if C_REG_LNG>=DF_BIT_RES generate
		process (outreg,i)
		variable oi : natural;
		begin
			if (C_NO_OUTREG=1) then
				oi := 0;
			else
				oi := i;
			end if;
			-- ram out
			o_RAMData(C_REG_LNG-DF_BIT_RES downto 0) <= (others => L);
			if outreg(oi)(DF_BIT_RES-1)=L then
				o_RAMData(C_REG_LNG-1) <= not outreg(oi)(DF_BIT_RES-2);
				o_RAMData(C_REG_LNG-2 downto C_REG_LNG-DF_BIT_RES+1) <= outreg(oi)(DF_BIT_RES-3 downto 0);
			else
				o_RAMData(C_REG_LNG-1) <= L;
				o_RAMData(C_REG_LNG-2 downto C_REG_LNG-DF_BIT_RES+1) <= (others => H);
			end if;
			-- parallel out
			if (C_NO_OUTREG=0) then
				for z in 0 to C_NUM_SD_DEVICES-1 loop
					o_DataLA(C_REG_LNG*z+C_REG_LNG-DF_BIT_RES downto C_REG_LNG*z) <= (others => L);
					if outreg(z)(DF_BIT_RES-1)=L then
						o_DataLA(C_REG_LNG-1+C_REG_LNG*z) <= not outreg(z)(DF_BIT_RES-2);
						o_DataLA(C_REG_LNG*z+C_REG_LNG-2 downto C_REG_LNG*z+C_REG_LNG-DF_BIT_RES+1) <= outreg(z)(DF_BIT_RES-3 downto 0);
					else
						o_DataLA(C_REG_LNG-1+C_REG_LNG*z) <= L;
						o_DataLA(C_REG_LNG*z+C_REG_LNG-2 downto C_REG_LNG*z+C_REG_LNG-DF_BIT_RES+1) <= (others => H);
					end if;
				end loop;
			end if;
		end process;
	end generate C_REG_LNG_bigger;
		
	C_REG_LNG_smaler : if C_REG_LNG<DF_BIT_RES generate
		process (outreg,i)
		variable oi : natural;
		begin
			if (C_NO_OUTREG=1) then
				oi := 0;
			else
				oi := i;
			end if;
			-- ram out
			if outreg(oi)(DF_BIT_RES-1)=L then
				o_RAMData(C_REG_LNG-1) <= not outreg(oi)(DF_BIT_RES-2);
				o_RAMData(C_REG_LNG-2 downto 0) <= outreg(oi)(DF_BIT_RES-3 downto DF_BIT_RES-C_REG_LNG-1);
			else
				o_RAMData(C_REG_LNG-1) <= L;
				o_RAMData(C_REG_LNG-2 downto 0) <= (others => H);
			end if;
			-- parallel out
			if (C_NO_OUTREG=0) then
				for z in 0 to C_NUM_SD_DEVICES-1 loop
					if outreg(z)(DF_BIT_RES-1)=L then
						o_DataLA(C_REG_LNG*z+C_REG_LNG-1) <= not outreg(z)(DF_BIT_RES-2);
						o_DataLA(C_REG_LNG*z+C_REG_LNG-2 downto C_REG_LNG*z) <= outreg(z)(DF_BIT_RES-3 downto DF_BIT_RES-C_REG_LNG-1);
					else
						o_DataLA(C_REG_LNG*z+C_REG_LNG-1) <= L;
						o_DataLA(C_REG_LNG*z+C_REG_LNG-2 downto C_REG_LNG*z) <= (others => H);
					end if;
				end loop;
			end if;
		end process;
	end generate C_REG_LNG_smaler;
	
	no_outregs : if (C_NO_OUTREG=1) generate
		singel_sub : if (C_USE_SINGLE_SUB/=0) generate
			outreg(0) <= sub;
		end generate singel_sub;
		no_singel_sub : if (C_USE_SINGLE_SUB=0) generate
			outreg(0) <= HOLD(i) - DIFF(C_ORDER-1)(i);
		end generate no_singel_sub;
		o_WE <= calc_en when clk_div=C_ORDER else L;
		o_DataReady <= L;
	end generate no_outregs;
	
	outregs : if (C_NO_OUTREG=0) generate
		process (i_Clk)
		begin
		if rising_edge(i_Clk) then
			o_WE <= L;
			o_DataReady <= L;
			if clk_div=C_ORDER and calc_en=H then
				o_WE <= H;
				if (i=C_NUM_SD_DEVICES-1) then
					o_DataReady <= H;
				end if;
				if (C_USE_SINGLE_SUB/=0) then
					outreg(i) <= sub;
				else
					outreg(i) <= HOLD(i) - DIFF(C_ORDER-1)(i);
				end if;
			end if;
		end if;
		end process;
	end generate outregs;
	
	sequenzer : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
		-- clocked statements
			i_cnt <= (others => L);
			if i_clear=H then
				clk_div <= conv_std_logic_vector(C_ORDER,clk_div'length);
				calc_en <= L;
			elsif (i_dataready=H) then
				sData <= i_sData;
				calc_en <= H;
				if ((clk_div=C_CLK_DIV-1 and i_half_dezi=L) or (clk_div=C_CLK_DIV/2-1 and i_half_dezi=H)) then
					clk_div <= (others => L);
				else
					clk_div <= clk_div + 1;
				end if;
			else
				if (C_NUM_SD_DEVICES=1) then 
					calc_en <= L;
				else
					if (i_cnt/=C_NUM_SD_DEVICES-1 and calc_en=H) then
						i_cnt <= i_cnt + 1;
					else
						calc_en <= L;
					end if;
				end if;
			end if;
		end if;
	end process sequenzer;
	
	sincK_filter : process (i_Clk)
		-- procedure pDIFF(K) --------------------------------------------------
		--	generate with recursion and K=1 C_ORDER=3:
		--		if clk_div=1 then
		--			DIFF(0)(i) <= HOLD(i);
		--		elsif clk_div=2 then
		--			DIFF(1)(i) <= HOLD(i);
		--		elsif clk_div=3 then
		--			DIFF(2)(i) <= HOLD(i);
		--		end if;
		procedure pDIFF(K: in integer range 1 to C_ORDER) is
		begin
			if clk_div=K then
				DIFF(K-1)(i) <= HOLD(i);
			else
				if K<C_ORDER then
					pDIFF(K+1);
				end if;
			end if;
		end procedure pDIFF;
		-- procedure pHOLD(K) --------------------------------------------------
		--	generate with recursion and K=1 C_ORDER=3:
		--	if C_USE_SINGLE_SUB/0 "HOLD(i) - DIFF(X)(i)" is replaced with sub
		--		if clk_div=1 then
		--			HOLD(i) <= HOLD(i) - DIFF(0)(i);
		--		elsif clk_div=2 then
		--			HOLD(i) <= HOLD(i) - DIFF(1)(i);
		--		elsif clk_div=3 then
		--			HOLD(i) <= ACC(C_ORDER-1)(i);
		--		else
		--			HOLD(i) <= ACC(C_ORDER-1)(i);
		--		end if;
		procedure pHOLD(K: in integer range 1 to C_ORDER) is
		begin
			if clk_div=K then
				if (K=C_ORDER) then
					HOLD(i) <= ACC(C_ORDER-1)(i);
				else
					if (C_USE_SINGLE_SUB/=0) then
						HOLD(i) <= sub;
					else
						HOLD(i) <= HOLD(i) - DIFF(K-1)(i);
					end if;
				end if;
			else
				if K<C_ORDER then
					pHOLD(K+1);
				else
					HOLD(i) <= ACC(C_ORDER-1)(i);
				end if;
			end if;
		end procedure pHOLD;
	begin
		if rising_edge(i_Clk) then
		-- c--locked statements
			--if i_clear=H then
			--	ACC <= (others => arr_reg_null);
			--	HOLD <= (others => filter_reg_null);
			--	DIFF <= (others => arr_reg_null);
			--elsif calc_en=H then
			if calc_en=H then
				if sData(i) = H then
					if i_half_dezi=L then
						ACC(0)(i) <= ACC(0)(i) + 1;
					else
						ACC(0)(i) <= ACC(0)(i) + 2**C_ORDER;
					end if;
				end if;
				for order in 1 to C_ORDER-1 loop
					ACC(order)(i) <= ACC(order)(i) + ACC(order-1)(i);
				end loop;
--	Examples dezimation:	C_ORDER=3! -----------------------------------------
--				fast (v2p ~180 mhz), but piplined (-3)
--				if clk_div=C_CLK_DIV-1 then
--					ACC3_n(i) <= ACC3(i);
--					DIFF1_n(i) <= DIFF1(i);
--					DIFF2_n(i) <= DIFF2(i);
--					DIFF1(i) <= ACC3(i) - ACC3_n(i);
--					DIFF2(i) <= DIFF1(i) - DIFF1_n(i);
--					DIFF3(i) <= DIFF2(i) - DIFF2_n(i);
--				end if;
--				----------------------------------------------------------------
--				slow (v2p ~100 mhz), not piplined, use 3 subtractors
--				if clk_div=C_CLK_DIV-1 then
--					ACC3_n(i) <= ACC3(i);
--					DIFF1_n(i) <= ACC3(i) - ACC3_n(i);
--					DIFF2_n(i) <= ACC3(i) - ACC3_n(i) - DIFF1_n(i);
--					DIFF3(i) <= ACC3(i) - ACC3_n(i) - DIFF1_n(i) - DIFF2_n(i);
--				end if;
--				----------------------------------------------------------------
--				sequential (v2p ~140 mhz), piplined subtractor C_USE_SINGLE_SUB=0 need 2, C_USE_SINGLE_SUB=1 need 1
--				if clk_div=1 then
--					HOLD(i) <= HOLD(i) - DIFF(0)(i);
--					DIFF(0)(i) <= HOLD(i);
--				elsif clk_div=2 then
--					HOLD(i) <= HOLD(i) - DIFF(1)(i);
--					DIFF(1)(i) <= HOLD(i);
--				elsif clk_div=3 then
--					outreg(i) <= HOLD(i) - DIFF(2)(i);
--					DIFF(2)(i) <= HOLD(i);
--				else
--					HOLD(i) <= ACC(C_ORDER-1)(i);
--				end if;
--				----------------------------------------------------------------
-- implemented: sequential
				pDIFF(1);
				pHOLD(1);
			end if;
		end if;
	end process sincK_filter;
	
	single_sub : if C_USE_SINGLE_SUB/=0 generate
		subi : process (clk_div, i, DIFF, HOLD)
			-- procedure pHOLD(K) --------------------------------------------------
			--	generate with recursion and K=2 C_ORDER=3:
			--		if clk_div=2 then
			--			sub <= HOLD(i) - DIFF(1)(i);
			--		elsif clk_div=3 then
			--			sub <= HOLD(i) - DIFF(2)(i);
			--		else
			--			sub <= HOLD(i) - DIFF(0)(i);
			--		end if;
			procedure pSUB(K: in integer range 1 to C_ORDER) is
			begin
				if clk_div=K then
					sub <= HOLD(i) - DIFF(K-1)(i);
				else
					if K<C_ORDER then
						pSUB(K+1);
					else
						sub <= HOLD(i) - DIFF(0)(i);
					end if;
				end if;
			end procedure pSUB;
		begin
			pSUB(2);
		end process subi;
	end generate single_sub;
	
	or_detection : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
		-- clocked statements
			if calc_en=H then
				oldData(i) <= sData(i);
				if sData(i)=oldData(i) then
					if overrange(i)=L then
						or_cnt(i) <= or_cnt(i) + 1;
					end if;
				else
					or_cnt(i) <= (others => L);
				end if;
				if or_cnt(i)>=C_OVERRANGE then
					overrange(i) <= H;
				else
					overrange(i) <= L;
				end if;
			end if;
		end if;
	end process or_detection;

end behavior_sigma_delta_synchron;
--------------------------------------------------------------------------------

