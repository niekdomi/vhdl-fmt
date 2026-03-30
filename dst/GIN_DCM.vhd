--------------------------------------------------------------------------------
--
--  GIN-DCM
--
--------------------------------------------------------------------------------
--
--  project     : GIN_LINK
--  programmer  : F.Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- generates Clocks and reset for Gin-MGT
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 	Rev. 1.00   21.05.2004-FB	erste Version
--	18.12.2008-le : - add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 823                                                                   $
--$Author:: leuthold                                                           $
--$Date:: 2008-12-18 15:37:50 +0100 (Do., 18 Dez 2008)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;
-- synopsys translate_off
Library UNISIM;
use UNISIM.Vcomponents.all;
-- synopsys translate_on


entity GIN_DCM is 

	port (
		i_Reset  : in std_logic;
		i_Q125 	 : in std_logic;
   		o_Q62_5  : OUT std_logic;
   		o_dQ62_5 : OUT std_logic;
		o_MGTclk : out std_logic;
		o_MGTrst : out std_logic
	); 
	
end GIN_DCM;

architecture imp of GIN_DCM is
--------------------------------------------------------------------------------
	signal CLKFB : std_logic;
	signal CLK0 : std_logic;
	signal CLK90 : std_logic;
	signal CLKDV : std_logic;
	signal GND : std_logic;
	signal Q62_5 : std_logic;
	signal dQ62_5 : std_logic;
	signal gQ62_5 : std_logic;
	signal LOCKED : std_logic;

	signal Rst_FF0 : std_logic := '0';
	signal Rst_FF1 : std_logic := '0';
	signal Q25cnt : std_logic_vector(2 downto 0) := "000";        

	signal MGTclk : std_logic := '0';

-- 	Period Jitter (unit interval) = 0.02 UI
-- 	Period Jitter (Peak-to-Peak) = 0.79 ns

--------------------------------------------------------------------------------
-- 	components
--------------------------------------------------------------------------------
   component DCM
		generic( 
			CLKDV_DIVIDE : real := 2.0;
			CLKFX_DIVIDE : integer := 1;
			CLKFX_MULTIPLY : integer := 4;
			CLKIN_DIVIDE_BY_2 : boolean := false;
			CLKIN_PERIOD : real := 0.0;						   
			CLKOUT_PHASE_SHIFT : string := "NONE";
			CLK_FEEDBACK : string := "1X";
			DESKEW_ADJUST : string := "SYSTEM_SYNCHRONOUS";	   
			DFS_FREQUENCY_MODE : string := "LOW";
			DLL_FREQUENCY_MODE : string := "LOW";
			DSS_MODE : string := "NONE";						   
			DUTY_CYCLE_CORRECTION : boolean := true;
			FACTORY_JF : bit_vector := X"C080";				   
--			MAXPERCLKIN : time := 1000000 ps;				   
--			MAXPERPSCLK : time := 100000000 ps;				   
			PHASE_SHIFT : integer := 0;
--			SIM_CLKIN_CYCLE_JITTER : time := 300 ps;			   
--			SIM_CLKIN_PERIOD_JITTER : time := 1000 ps;		   
			STARTUP_WAIT : boolean := false					   
		);
		port (
			CLKIN : in std_logic;
			CLKFB : in std_logic;
			RST : in std_logic;
			PSEN : in std_logic;
			PSINCDEC : in std_logic;
			PSCLK : in std_logic;
			DSSEN : in std_logic;
			CLK0 : out std_logic;
			CLK90 : out std_logic;
--			CLK180 : out std_logic;
--			CLK270 : out std_logic;
			CLKDV : out std_logic;
--			CLK2X : out std_logic;
--			CLK2X180 : out std_logic;
--			CLKFX : out std_logic;
--			CLKFX180 : out std_logic;
--			STATUS : out std_logic_vector (7 downto 0);
			LOCKED : out std_logic
--			PSDONE : out std_logic
	   	); 
   end component;
      
   component BUFG
		port (
	   		I : in std_logic;
	   		O : out std_logic
		);
   end component;

--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	:	std_logic := '1';
	constant	L	:	std_logic := '0';
	constant	Z	:	std_logic := 'Z';

begin

-------------------------------------------------------------------------------
--	Clock-Buffers
-------------------------------------------------------------------------------
	o_Q62_5 	<= Q62_5;
	o_dQ62_5 	<= dQ62_5;

	uDCM_Q62_5Buf : BUFG
		port map (
			I => CLKDV,
			O => Q62_5
		);

-------------------------------------------------------------------------------
--	dQ62_5 used for asynchronous logical-gates
-------------------------------------------------------------------------------
	process(CLK90) begin
		if rising_edge(CLK90) then	
			dQ62_5 <= CLKDV;
		end if;	
	end process;

-------------------------------------------------------------------------------
-- just for DCM-feedback
	uDCM_QfbBuf : BUFG
		port map (
			I => CLK0,
			O => CLKFB
		);
	
-------------------------------------------------------------------------------
--	MGT Q62_5 
-------------------------------------------------------------------------------
	process(i_Q125) begin
		if rising_edge(i_Q125) then	
			MGTclk <= not MGTclk;
		end if;	
	end process;
	
	o_MGTclk <= MGTclk;  
--	uMGTclkBuf : BUFG
--		port map (
--			I => MGTclk,
--			O => o_MGTclk
--		);
	
-------------------------------------------------------------------------------
--	MGT benötigt einen 2 Takte langen Reset
-------------------------------------------------------------------------------
	process (i_Reset,Q62_5) begin
		if (i_Reset = H) then 
			Rst_FF0 <= L;
			Rst_FF1 <= L;
			o_MGTrst <= H;
		elsif rising_edge(Q62_5) then
			if (LOCKED = L) then
				Rst_FF0 <= L;
				Rst_FF1 <= L;
			else
				if (Rst_FF0 = L) then
					Rst_FF0 <= H;
				else
					if (Rst_FF1 = L) then
						Rst_FF1 <= H;
					end if;
				end if;
			end if;
			-- End Reset after 2 Q62_5 periodes
			if (Rst_FF1 = H) then
				o_MGTrst <= L;
			else
				o_MGTrst <= H;
			end if;
		end if; 
	end process;

-------------------------------------------------------------------------------
--	DCM
-------------------------------------------------------------------------------
	GND <= '0';
   uDCM_DCM : DCM 
		Generic map (
			CLK_FEEDBACK => "1X",
			CLKDV_DIVIDE => 2.0,
			CLKFX_DIVIDE => 4,
			CLKFX_MULTIPLY => 2,
			CLKIN_DIVIDE_BY_2 => FALSE,
			CLKIN_PERIOD => 8.0,
			CLKOUT_PHASE_SHIFT => "NONE",
			DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS",
			DFS_FREQUENCY_MODE => "LOW",
			DLL_FREQUENCY_MODE => "LOW",
			DUTY_CYCLE_CORRECTION => TRUE,
			PHASE_SHIFT => 0,
			STARTUP_WAIT => FALSE
		) port map (
			CLKIN 	=> i_Q125,
			CLKFB 	=> CLKFB,
			RST 	=> i_Reset,
			PSEN 	=> GND,
			PSINCDEC=> GND,
			PSCLK 	=> GND,
			DSSEN 	=> GND,
			CLK0 	=> CLK0,
			CLK90 	=> CLK90,
			CLKDV 	=> CLKDV,
			LOCKED 	=> LOCKED
		);
-------------------------------------------------------------------------------

end;

