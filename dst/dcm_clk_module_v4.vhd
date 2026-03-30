--------------------------------------------------------------------------------
--	dcm_clk_module_v4
--------------------------------------------------------------------------------
--
--	project		: clock module virtex4
--	programmer	: C. Leuthold, INDEL AG
--	date		: 
--	version		: 0.00
--	language	: VHDL
--	system		: ise
--
--	purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	08.09.2008-le - rename entity
--					add svn keywords
--	12.09.2012-le - add 200ms reset for v4 dcm
--------------------------------------------------------------------------------
--$Rev:: 2389                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2012-09-12 13:56:28 +0200 (Mi., 12 Sep 2012)                         $
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library UNISIM;
use UNISIM.VComponents.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity dcm_clk_module is
	generic (
		C_CLK_FREQ : integer := 66_000_000;-- 66_000_000, 99_000_000, 110_000_000
		C_RST_TIME_MS : integer := 200
	);
	Port (
		i_Clk : in std_logic;
		i_reset : in std_logic := L;
		o_reset : out std_logic := L;
		o_dcmLocked : out std_logic;
		o_bus_clk : out std_logic;
		o_bus_clk_90 : out std_logic;
		o_bus_clk_180 : out std_logic;
		o_bus_clk_270 : out std_logic;
		o_ocm_clk : out std_logic;
		o_ppc_clk : out std_logic;
		o_il_clk : out std_logic;
		i_ddr_fb_clk : in std_logic := L;
		o_ddr_fb_90 : out std_logic;
		o_ddr_fb_270 : out std_logic;
		o_clkref200MHz : out std_logic
	);
end dcm_clk_module;

architecture BEHAVIOR_dcm_clk_module_v4 of dcm_clk_module is
begin
	osc99_110 : if C_CLK_FREQ>66_000_000 generate
	-- component declarations ------------------------------------------------------
	-- constants -------------------------------------------------------------------
		function calc_bus_freq(value : integer) return integer is
		begin
			if value=66_000_000 then
				return 99_000_000;
			elsif value=99_000_000 then
				return 99_000_000;
			elsif value=110_000_000 then
				return 110_000_000;
			end if;
			assert false
			report "dcm_clk_module_v4:" &
					" wrong value for generic C_CLK_FREQ"
			severity failure;
			return 0;
		end calc_bus_freq;
	
		constant C_BUS_FREQ : integer := calc_bus_freq(C_CLK_FREQ);
		constant C_BUS_CLK_PS : real := (1.0e+12)/(real(C_BUS_FREQ));
		constant C_BUS_CLK_NS : real := (1.0e+9)/(real(C_BUS_FREQ));
		constant C_OCM_CLK_NS : real := real(C_BUS_CLK_NS)/3.0*2.0;--C_BUS_CLK_NS/1.5;
	-- types -----------------------------------------------------------------------
	-- signals ---------------------------------------------------------------------
		signal bus_clk_buf : std_logic;
		signal dcm_Rst : std_logic_vector(15 downto 0) := (others => H);
		signal ppc_dcmLocked : std_logic;
		signal ocm_dcmLocked : std_logic;
		signal bus_clk : std_logic;
		signal bus_clk_90 : std_logic;
		signal ocm_clk : std_logic;
		signal bus_clk_90_ub : std_logic;
		signal bus_clk_ub : std_logic;
		signal ocm_clk_ub : std_logic;
		signal ppc_clk_ub : std_logic;
		signal ddr_clk_90 : std_logic;
		signal ddr_clk_90_ub : std_logic;
		signal ref_clk_ub : std_logic;
		
		constant DF_MS : integer := C_CLK_FREQ/1_000;
		constant DF_DCM_WAIT_NO_CLK : integer := C_RST_TIME_MS*DF_MS;
		signal res_cnt : std_logic_vector(pkg_log2(DF_DCM_WAIT_NO_CLK)-1 downto 0) := (others => L);
		
	-- Attribute declaration -------------------------------------------------------
	--------------------------------------------------------------------------------
	-- implementation
	--------------------------------------------------------------------------------
	begin							-- of architecture BEHAVIOR_dcm_clk_module_v4
	
		osc_is_bus_clk_gen : if C_CLK_FREQ/=66_000_000 generate
			-- input buffer
			IBUFG_clk_input : IBUFG
			port map (
				O => bus_clk_buf, -- Clock buffer output
				I => i_Clk -- Clock buffer input (connect directly to top-level port)
			);
			o_reset <= dcm_Rst(dcm_Rst'high-1);
			process(bus_clk_buf,i_reset)
			begin
				if (i_reset=H) then
					res_cnt <= (others => L);
					dcm_Rst <= (others => H);
				elsif rising_edge(bus_clk_buf) then
					if res_cnt=DF_DCM_WAIT_NO_CLK then
						dcm_Rst <= dcm_Rst(dcm_Rst'high-1 downto 0) & L;
					else
						res_cnt <= res_cnt + 1;
						dcm_Rst <= (others => H);
					end if;
				end if;
			end process;
			o_dcmLocked <= ppc_dcmLocked and ocm_dcmLocked;
		end generate osc_is_bus_clk_gen;
		
		DCM_BASE_inst_ocm : DCM_BASE
		generic map (
			CLKDV_DIVIDE => 1.5, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
			CLKFX_DIVIDE => 2, -- Can be any interger from 1 to 32
			CLKFX_MULTIPLY => 3, -- Can be any integer from 2 to 32
			CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
			CLKIN_PERIOD => C_BUS_CLK_NS, -- Specify period of input clock in ns from 1.25 to 1000.00
			CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
			CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
			DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
			DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
			DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
			DFS_FREQUENCY_MODE => "LOW", -- LOW or HIGH frequency mode for frequency synthesis
			DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
			DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
			FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
			PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
			STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
		port map (
			CLK0 => bus_clk_ub, -- 0 degree DCM CLK ouptput
			CLK180 => open, -- 180 degree DCM CLK output
			CLK270 => open, -- 270 degree DCM CLK output
			CLK2X => open, -- 2X DCM CLK output
			CLK2X180 => open, -- 2X, 180 degree DCM CLK out
			CLK90 => bus_clk_90_ub, -- 90 degree DCM CLK output
			CLKDV => open, -- Divided DCM CLK out (CLKDV_DIVIDE)
			CLKFX => ocm_clk_ub, -- DCM CLK synthesis out (M/D)
			CLKFX180 => open, -- 180 degree CLK synthesis out
			LOCKED => ocm_dcmLocked, -- DCM LOCK status output
			CLKFB => bus_clk, -- DCM clock feedback
			CLKIN => bus_clk_buf, -- Clock input (from IBUFG, BUFG or DCM)
			RST => dcm_Rst(dcm_Rst'high) -- DCM asynchronous reset input
		);
		
		BUFG_bus_clk : BUFG
		port map (
			O => bus_clk, -- Clock buffer output
			I => bus_clk_ub -- Clock buffer input
		);
		BUFG_bus_clk_90 : BUFG
		port map (
			O => bus_clk_90, -- Clock buffer output
			I => bus_clk_90_ub -- Clock buffer input
		);
		BUFG_ocm_clk : BUFG
		port map (
			O => ocm_clk, -- Clock buffer output
			I => ocm_clk_ub -- Clock buffer input
		);
		BUFG_ppc_clk : BUFG
		port map (
			O => o_ppc_clk, -- Clock buffer output
			I => ppc_clk_ub -- Clock buffer input
		);
		BUFG_ref_clk : BUFG
		port map (
			O => o_clkref200MHz, -- Clock buffer output
			I => ref_clk_ub -- Clock buffer input
		);
		o_bus_clk <= bus_clk;
		o_bus_clk_90 <= bus_clk_90;
		o_bus_clk_180 <= not bus_clk;
		o_bus_clk_270 <= not bus_clk_90;
		o_ocm_clk <= ocm_clk;
		
		CLK_99_MHZ : if C_CLK_FREQ<100_000_000 generate
			signal bus_clk_ub1 : std_logic;
			signal bus_clk_fb1 : std_logic;
			signal il_CLk_ub : std_logic;
		begin
			DCM_BASE_inst_ppc : DCM_BASE
			generic map (
				CLKDV_DIVIDE => 1.5, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
				CLKFX_DIVIDE => 1, -- Can be any interger from 1 to 32
				CLKFX_MULTIPLY => 3, -- Can be any integer from 2 to 32
				CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
				CLKIN_PERIOD => C_BUS_CLK_NS, -- Specify period of input clock in ns from 1.25 to 1000.00
				CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
				CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
				DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
				DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
				DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
				DFS_FREQUENCY_MODE => "HIGH", -- LOW or HIGH frequency mode for frequency synthesis
				DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
				DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
				FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
				PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
				STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
			port map (
				CLK0 => bus_clk_ub1, -- 0 degree DCM CLK ouptput
				CLK180 => open, -- 180 degree DCM CLK output
				CLK270 => open, -- 270 degree DCM CLK output
				CLK2X => ref_clk_ub, -- 2X DCM CLK output
				CLK2X180 => open, -- 2X, 180 degree DCM CLK out
				CLK90 => open, -- 90 degree DCM CLK output
				CLKDV => il_CLk_ub, -- Divided DCM CLK out (CLKDV_DIVIDE)
				CLKFX => ppc_clk_ub, -- DCM CLK synthesis out (M/D)
				CLKFX180 => open, -- 180 degree CLK synthesis out
				LOCKED => ppc_dcmLocked, -- DCM LOCK status output
				CLKFB => bus_clk_fb1, -- DCM clock feedback
				CLKIN => bus_clk_buf, -- Clock input (from IBUFG, BUFG or DCM)
				RST => dcm_Rst(dcm_Rst'high) -- DCM asynchronous reset input
			);
			BUFG_bus_clk1 : BUFG
			port map (
				O => bus_clk_fb1, -- Clock buffer output
				I => bus_clk_ub1 -- Clock buffer input
			);
			BUFG_il_CLk : BUFG
			port map (
				O => o_il_CLk, -- Clock buffer output
				I => il_CLk_ub -- Clock buffer input
			);
		end generate CLK_99_MHZ;
		
		CLK_110_MHZ : if C_CLK_FREQ>=100_000_000 generate
			signal ocm_clk_ub1 : std_logic;
			signal ocm_clk_fb1 : std_logic;
			signal ppc_dcm_Rst : std_logic_vector(15 downto 0) := (others => H);
			signal il_CLk_ub : std_logic;
		begin
			process(ocm_clk,dcm_Rst)
			begin
				if (dcm_Rst(dcm_Rst'high)=H) then
					ppc_dcm_Rst <= (others => H);
				elsif rising_edge(ocm_clk) then
					ppc_dcm_Rst <= ppc_dcm_Rst(ppc_dcm_Rst'high-1 downto 0) & not ocm_dcmLocked;
				end if;
			end process;
			DCM_BASE_inst_ppc : DCM_BASE
			generic map (
				CLKDV_DIVIDE => 2.5, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
				CLKFX_DIVIDE => 4, -- Can be any interger from 1 to 32
				CLKFX_MULTIPLY => 5, -- Can be any integer from 2 to 32
				CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
				CLKIN_PERIOD => C_OCM_CLK_NS, -- Specify period of input clock in ns from 1.25 to 1000.00
				CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
				CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
				DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
				DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
				DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
				DFS_FREQUENCY_MODE => "HIGH", -- LOW or HIGH frequency mode for frequency synthesis
				DLL_FREQUENCY_MODE => "HIGH", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
				DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
				FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
				PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
				STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
			port map (
				CLK0 => ocm_clk_ub1, -- 0 degree DCM CLK ouptput
				CLK180 => open, -- 180 degree DCM CLK output
				CLK270 => open, -- 270 degree DCM CLK output
				CLK2X => ppc_clk_ub, -- 2X DCM CLK output
				CLK2X180 => open, -- 2X, 180 degree DCM CLK out
				CLK90 => open, -- 90 degree DCM CLK output
				CLKDV => il_CLk_ub, -- Divided DCM CLK out (CLKDV_DIVIDE)
				CLKFX => ref_clk_ub, -- DCM CLK synthesis out (M/D)
				CLKFX180 => open, -- 180 degree CLK synthesis out
				LOCKED => ppc_dcmLocked, -- DCM LOCK status output
				CLKFB => ocm_clk_fb1, -- DCM clock feedback
				CLKIN => ocm_clk, -- Clock input (from IBUFG, BUFG or DCM)
				RST => ppc_dcm_Rst(ppc_dcm_Rst'high) -- DCM asynchronous reset input
			);
			BUFG_bus_clk1 : BUFG
			port map (
				O => ocm_clk_fb1, -- Clock buffer output
				I => ocm_clk_ub1 -- Clock buffer input
			);
			--BUFG_il_CLk : BUFG
			--port map (
			--	O => o_il_CLk, -- Clock buffer output
			--	I => il_CLk_ub -- Clock buffer input
			--);
			o_il_CLk <= bus_clk;
		end generate CLK_110_MHZ;
		
		-- ddr feedback support ----------------------------------------------------
		-- ddr feedback delay is not necessary with timing constrain in ppc-cahr4.ucf
		IBUFG_ddr_fb_clk : IBUFG
		port map (
			O => ddr_clk_90_ub, -- Clock buffer output
			I => i_ddr_fb_clk -- Clock buffer input (connect directly to top-level port)
		);
		BUFG_ddr_clk_90 : BUFG
		port map (
			O => ddr_clk_90, -- Clock buffer output
			I => ddr_clk_90_ub -- Clock buffer input
		);
		o_ddr_fb_90 <= ddr_clk_90;
		o_ddr_fb_270 <= not ddr_clk_90;
	
	end generate osc99_110;
	
	osc66 : if C_CLK_FREQ=66_000_000 generate
		signal clk_buf : std_logic;
		signal clk_buf_ub : std_logic;
		signal dcm_Rst : std_logic_vector(15 downto 0) := (others => H);
		signal dcm_RstBus : std_logic_vector(15 downto 0) := (others => H);
		signal ddr_ppc_dcmLocked : std_logic;
		signal ocm_dcmLocked : std_logic;
		signal bus_dcmLocked : std_logic; 
		signal bus_clk : std_logic;
		signal bus_clk_90 : std_logic;
		signal bus_clk_90_ub : std_logic;
		
		signal bus_clk_ub : std_logic;
		signal ocm_clk_ub : std_logic;
		signal ppc_clk_ub : std_logic;
		signal ref_clk_ub : std_logic;
		
		signal ddr_clk_90 : std_logic;
		signal ddr_clk_90_ub : std_logic;
		
		signal clk_buf_ub1 : std_logic;
		signal clk_buf_fb1 : std_logic;
		signal clk_buf_ub2 : std_logic;
		signal clk_buf_fb2 : std_logic;
		signal clk_buf_ub3 : std_logic;
		signal clk_buf_fb3 : std_logic;
		signal clk_buf_ub4 : std_logic;
		signal clk_buf_fb4 : std_logic;
		
		constant DF_MS : integer := C_CLK_FREQ/1_000;
		constant DF_DCM_WAIT_NO_CLK : integer := C_RST_TIME_MS*DF_MS;
		signal res_cnt : std_logic_vector(pkg_log2(DF_DCM_WAIT_NO_CLK)-1 downto 0) := (others => L);
	
	begin
		-- input buffer
		IBUFG_clk_input : IBUFG
		port map (
			O => clk_buf, -- Clock buffer output
			I => i_Clk -- Clock buffer input (connect directly to top-level port)
		);
		-- dcm resets
		o_reset <= dcm_Rst(dcm_Rst'high-1);
		process(clk_buf,i_reset)
		begin
			if (i_reset=H) then
					res_cnt <= (others => L);
					dcm_Rst <= (others => H);
			elsif rising_edge(clk_buf) then
				if res_cnt=DF_DCM_WAIT_NO_CLK then
					dcm_Rst <= dcm_Rst(dcm_Rst'high-1 downto 0) & L;
				else
					res_cnt <= res_cnt + 1;
					dcm_Rst <= (others => H);
				end if;
			end if;
		end process;
		
		process(bus_clk)
		begin
			if rising_edge(bus_clk) then
				dcm_RstBus <= dcm_RstBus(dcm_RstBus'high-1 downto 0) & not bus_dcmLocked;
			end if;
		end process;
		
		o_dcmLocked <= bus_dcmLocked and ocm_dcmLocked and ddr_ppc_dcmLocked;
		
		DCM_BASE_inst_bus : DCM_BASE
		generic map (
			CLKDV_DIVIDE => 2.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
			CLKFX_DIVIDE => 2, -- Can be any interger from 1 to 32
			CLKFX_MULTIPLY => 3, -- Can be any integer from 2 to 32
			CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
			CLKIN_PERIOD => 15.15, -- Specify period of input clock in ns from 1.25 to 1000.00
			CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
			CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
			DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
			DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
			DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
			DFS_FREQUENCY_MODE => "LOW", -- LOW or HIGH frequency mode for frequency synthesis
			DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
			DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
			FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
			PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
			STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
		port map (
			CLK0 => clk_buf_ub1, -- 0 degree DCM CLK ouptput
			CLK180 => open, -- 180 degree DCM CLK output
			CLK270 => open, -- 270 degree DCM CLK output
			CLK2X => open, -- 2X DCM CLK output
			CLK2X180 => open, -- 2X, 180 degree DCM CLK out
			CLK90 => open, -- 90 degree DCM CLK output
			CLKDV => open, -- Divided DCM CLK out (CLKDV_DIVIDE)
			CLKFX => bus_clk_ub, -- DCM CLK synthesis out (M/D)
			CLKFX180 => open, -- 180 degree CLK synthesis out
			LOCKED => bus_dcmLocked, -- DCM LOCK status output
			CLKFB => clk_buf_fb1, -- DCM clock feedback
			CLKIN => clk_buf, -- Clock input (from IBUFG, BUFG or DCM)
			RST => dcm_Rst(dcm_Rst'high) -- DCM asynchronous reset input
		);
		DCM_BASE_inst_ocm : DCM_BASE
		generic map (
			CLKDV_DIVIDE => 2.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
			CLKFX_DIVIDE => 2, -- Can be any interger from 1 to 32
			CLKFX_MULTIPLY => 3, -- Can be any integer from 2 to 32
			CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
			CLKIN_PERIOD => 10.00, -- Specify period of input clock in ns from 1.25 to 1000.00
			CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
			CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
			DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
			DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
			DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
			DFS_FREQUENCY_MODE => "LOW", -- LOW or HIGH frequency mode for frequency synthesis
			DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
			DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
			FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
			PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
			STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
		port map (
			CLK0 => clk_buf_ub2, -- 0 degree DCM CLK ouptput
			CLK180 => open, -- 180 degree DCM CLK output
			CLK270 => open, -- 270 degree DCM CLK output
			CLK2X => open, -- 2X DCM CLK output
			CLK2X180 => open, -- 2X, 180 degree DCM CLK out
			CLK90 => open, -- 90 degree DCM CLK output
			CLKDV => open, -- Divided DCM CLK out (CLKDV_DIVIDE)
			CLKFX => ocm_clk_ub, -- DCM CLK synthesis out (M/D)
			CLKFX180 => open, -- 180 degree CLK synthesis out
			LOCKED => ocm_dcmLocked, -- DCM LOCK status output
			CLKFB => clk_buf_fb2, -- DCM clock feedback
			CLKIN => bus_clk, -- Clock input (from IBUFG, BUFG or DCM)
			RST => dcm_RstBus(dcm_RstBus'high) -- DCM asynchronous reset input
		);
		DCM_BASE_inst_ddr_ppc : DCM_BASE
		generic map (
			CLKDV_DIVIDE => 2.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
			CLKFX_DIVIDE => 1, -- Can be any interger from 1 to 32
			CLKFX_MULTIPLY => 3, -- Can be any integer from 2 to 32
			CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
			CLKIN_PERIOD => 10.0, -- Specify period of input clock in ns from 1.25 to 1000.00
			CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
			CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE or 1X
			DCM_AUTOCALIBRATION => FALSE, -- DCM calibrartion circuitry TRUE/FALSE
			DCM_PERFORMANCE_MODE => "MAX_SPEED", -- Can be MAX_SPEED or MAX_RANGE
			DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
			DFS_FREQUENCY_MODE => "HIGH", -- LOW or HIGH frequency mode for frequency synthesis
			DLL_FREQUENCY_MODE => "LOW", -- LOW, HIGH, or HIGH_SER frequency mode for DLL
			DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
			FACTORY_JF => X"F0F0", -- FACTORY JF Values Suggested to be set to X"F0F0"
			PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
			STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
		port map (
			CLK0 => clk_buf_ub4, -- 0 degree DCM CLK ouptput
			CLK180 => open, -- 180 degree DCM CLK output
			CLK270 => open, -- 270 degree DCM CLK output
			CLK2X => ref_clk_ub, -- 2X DCM CLK output
			CLK2X180 => open, -- 2X, 180 degree DCM CLK out
			CLK90 => bus_clk_90_ub, -- 90 degree DCM CLK output
			CLKDV => open, -- Divided DCM CLK out (CLKDV_DIVIDE)
			CLKFX => ppc_clk_ub, -- DCM CLK synthesis out (M/D)
			CLKFX180 => open, -- 180 degree CLK synthesis out
			LOCKED => ddr_ppc_dcmLocked, -- DCM LOCK status output
			CLKFB => clk_buf_fb4, -- DCM clock feedback
			CLKIN => bus_clk, -- Clock input (from IBUFG, BUFG or DCM)
			RST => dcm_RstBus(dcm_RstBus'high) -- DCM asynchronous reset input
		);
		BUFG_fb1_clk : BUFG
		port map (
			O => clk_buf_fb1, -- Clock buffer output
			I => clk_buf_ub1 -- Clock buffer input
		);
		BUFG_fb2_clk : BUFG
		port map (
			O => clk_buf_fb2, -- Clock buffer output
			I => clk_buf_ub2 -- Clock buffer input
		);
		BUFG_fb3_clk : BUFG
		port map (
			O => clk_buf_fb3, -- Clock buffer output
			I => clk_buf_ub3 -- Clock buffer input
		);
		BUFG_fb4_clk : BUFG
		port map (
			O => clk_buf_fb4, -- Clock buffer output
			I => clk_buf_ub4 -- Clock buffer input
		);
		BUFG_bus_clk : BUFG
		port map (
			O => bus_clk, -- Clock buffer output
			I => bus_clk_ub -- Clock buffer input
		);
		BUFG_bus_clk_90 : BUFG
		port map (
			O => bus_clk_90, -- Clock buffer output
			I => bus_clk_90_ub -- Clock buffer input
		);
		BUFG_ocm_clk : BUFG
		port map (
			O => o_ocm_clk, -- Clock buffer output
			I => ocm_clk_ub -- Clock buffer input
		);
		BUFG_ppc_clk : BUFG
		port map (
			O => o_ppc_clk, -- Clock buffer output
			I => ppc_clk_ub -- Clock buffer input
		);
		BUFG_ref_clk : BUFG
		port map (
			O => o_clkref200MHz, -- Clock buffer output
			I => ref_clk_ub -- Clock buffer input
		);
		o_bus_clk <= bus_clk;
		o_bus_clk_90 <= bus_clk_90;
		o_bus_clk_180 <= not bus_clk;
		o_bus_clk_270 <= not bus_clk_90;
		o_il_CLk <= clk_buf_fb1;
		-- ddr feedback delay is not necessary with timing constrain in ppc-cahr4.ucf
		IBUFG_ddr_fb_clk : IBUFG
		port map (
			O => ddr_clk_90_ub, -- Clock buffer output
			I => i_ddr_fb_clk -- Clock buffer input (connect directly to top-level port)
		);
		BUFG_ddr_clk_90 : BUFG
		port map (
			O => ddr_clk_90, -- Clock buffer output
			I => ddr_clk_90_ub -- Clock buffer input
		);
		o_ddr_fb_90 <= ddr_clk_90;
		o_ddr_fb_270 <= not ddr_clk_90;
	
	end generate osc66;
	
end BEHAVIOR_dcm_clk_module_v4;
--------------------------------------------------------------------------------