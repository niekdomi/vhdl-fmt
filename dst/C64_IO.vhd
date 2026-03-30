   ---------------------------------------------------------------------------
--
--  C64 IO
--
---------------------------------------------------------------------------
--
--  project     : C64_BusMaster
--  programmer  : F:Baschung, INDEL AG
--  date        : 23.06.2010
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- C64 IO
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
-------------------------------------------------------------------------------- 
-- Revison 0x05
--	23.06.2010-FB	- erste Version
--	27.10.2010-FB	- Nur noch IO- ohne test-Ram
--	16.03.2011-FB	- IOs auf 0x00 und CardStatus neu
--	28.06.2011-FB	- OkLED implementiert
--	28.06.2011-le	- add 1k readonly spi flash for xml cfg
--	09.01.2012-le	- change xml cfg
--	03.10.2012-sbä	- updated c64-slave madule
--	11.10.2012-sbä	- Released as Rev07
--					  Rev07: missing xml cfg!
--	21.11.2012-le	- Rev08: change path of spi ini-file to D:\KARTEN\COP\configs\COP\01_IO
--  25.10.2016-le	- Rev09: use clock synchronized COP_Reset
--------------------------------------------------------------------------------
--$Rev:: 4088                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-10-25 10:52:29 +0200 (Di., 25 Okt 2016)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

LIBRARY C64_Slave;
USE C64_Slave.ALL;

entity C64_IO is
	generic (
		Revision		: in  	std_logic_vector(7 downto 0) := x"09"
	);
	port (
		-- address switch
		 i_AddrSw		: in  std_logic_vector( 3 downto 0);

		-- C64-Bus
		 i_C64_CLK		: in  std_logic;
		ni_C64_CLK		: in  std_logic;
		 i_C64_SEL		: in  std_logic;
		 i_C64_Bend		: in  std_logic;
		 b_C64_DatBus	: inout  std_logic_vector(15 downto 0);
		no_C64_Ack		: inout std_logic;
		 i_C64_Reset	: in  std_logic;

		-- JTAG
		 o_JTAG_TMS		: inout std_logic;
		 o_JTAG_TDI		: inout std_logic;
		 o_JTAG_TCK		: inout std_logic;
		 i_JTAG_TDO		: in std_logic;

		no_EEP_Wen		: inout std_logic;
		no_OkLED		: out std_logic;
		ni_HWRev		: in  std_logic_vector( 2 downto 0);

		-- Application	16-IOs
		ni_Inp			: in  std_logic_vector(15 downto 0);
		ni_B0_24V		: in  std_logic;
		ni_B1_24V		: in  std_logic;
		 o_Out			: out std_logic_vector(15 downto 0)
	);
end C64_IO;

architecture impl of C64_IO is
--------------------------------------------------------------------------------
--	C64 Card-Type							  	 IO=01
	constant g_App_Rev		: std_logic_vector := x"01" & Revision;	-- typ,vers
--------------------------------------------------------------------------------
	constant cfg_IOs		: std_logic_vector := x"00";
	
	constant g_CRCChecker	: integer := 0;
--------------------------------------------------------------------------------
	constant H 				: std_logic	:= '1';
	constant L 				: std_logic	:= '0';
--------------------------------------------------------------------------------

	signal Card_Rd_Status	: std_logic_vector(11 downto 0);
	signal Card_Wr_Status	: std_logic_vector(15 downto 0);
	signal HWRev	 		: std_logic_vector( 3 downto 0);
	signal ModAddr			: std_logic_vector( 3 downto 0);
	----------------------------------------------------------------------------
	-- C64-Slave Rd/Wr
	----------------------------------------------------------------------------
	signal Q25			: std_logic						:= L;
	signal Slv_RdData	: std_logic_vector(15 downto 0)	:= X"0000";
	signal Slv_WrData	: std_logic_vector(15 downto 0)	:= X"0000";
	signal Slv_Addr		: std_logic_vector( 7 downto 0)	:= X"00";
	signal Slv_WrEn		: std_logic 					:= L;
	signal Slv_RdEn		: std_logic 					:= L;

--------------------------------------------------------------------------------
	signal SPI_CLK			: std_logic;
	signal nSPI_CS			: std_logic;
	signal SPI_D			: std_logic;
	signal SPI_Q			: std_logic;
--------------------------------------------------------------------------------
	signal Inputs 			: std_logic_vector(15 downto 0);
	signal cop_rst			: std_logic;
begin

--------------------------------------------------------------------------------
--	Test-Points
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	In / Out
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--
--	Card Status Rd/Wr
--
--------------------------------------------------------------------------------
	-- live-bits and read-back bits
	-- Card_Wr_Status(15): EEprom
	-- Card_Wr_Status(14): slave internal
	-- Card_Wr_Status(13..12): okLed state
	-- Card_Wr_Status will be cleared after i_C64_Reset
	Card_Rd_Status <= Card_Wr_Status(11 downto 2) & not ni_B1_24V & not ni_B0_24V;

	HWRev <= L & not ni_HWRev;
	
	cop_clk : entity C64_Slave.clockgenerator
	port map (
		 i_C64_CLK =>  i_C64_CLK,
		ni_C64_CLK => ni_C64_CLK,
		 o_clk => Q25
	);

--------------------------------------------------------------------------------
--	C64 BusSlave instance
--------------------------------------------------------------------------------
	inst_C64_Slaver: entity C64_Slave.C64_SlaveSeq
	generic map (
		g_App_Rev => g_App_Rev,
		g_SPI_TrstBuf => 0,
		g_half_spi_freq => 1,
		g_CRCChecker => g_CRCChecker
	)
		PORT MAP (
		-- address switch
		 i_AddrSw		=> i_AddrSw			,

		-- C64 Bus
		 i_C64_Reset	=> i_C64_Reset		,
		 i_CLK25		=> Q25				,
		 i_C64_SEL		=> i_C64_SEL		,
		 i_C64_Bend		=> i_C64_Bend		,
		 b_C64_DatBus	=> b_C64_DatBus		,
		no_C64_Ack		=> no_C64_Ack		,

		-- JTAG pins
		 o_JTAG_TCK		=> o_JTAG_TCK		,
		 o_JTAG_TMS		=> o_JTAG_TMS		,
		 o_JTAG_TDI		=> o_JTAG_TDI		,
		 i_JTAG_TDO		=> i_JTAG_TDO		,

		 -- SPI Pins
		 o_SPI_CLK		=> SPI_CLK			,
		no_SPI_CS		=> nSPI_CS			,
		 o_SPI_D		=> SPI_D			,
		 i_SPI_Q		=> SPI_Q			,

		-- local application Rd/Wr
		 o_Addr			=> Slv_Addr			,
		 i_RdData		=> Slv_RdData		,
		 o_WrData		=> Slv_WrData		,
		 o_WrEn			=> Slv_WrEn			,
		 o_RdEn			=> Slv_RdEn			,
		 -- status
		 i_Card_Status	=> Card_Rd_Status(11-4*g_CRCChecker downto 0)	,
		 o_Card_Status	=> Card_Wr_Status	,
		-- GinFrams_Flags
		 o_GF_Flags		=> open				,
		no_EEP_Wen		=> no_EEP_Wen		,
		no_OkLED		=> no_OkLED			,
		 i_HWRev		=> HWRev			,
		 o_cfg_en		=> open				,
		 o_COP_Reset	=> cop_rst
	);
--------------------------------------------------------------------------------
--	C64-Slave	Read/Write
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	Read	Inputs
--------------------------------------------------------------------------------
	process(Q25) begin
		if rising_edge(Q25) then
			-- pre-synch Inputs to Q25
			Inputs <= not ni_Inp;
		end if;
	end process;

	process(Slv_Addr,Slv_RdEn,Inputs) begin
		Slv_RdData	<= x"CCCC";
		if (Slv_RdEn = H) then
			--------------------------------------------------------------------
			case Slv_Addr is
			--------------------------------------------------------------------
			-- Read Inputs
			--------------------------------------------------------------------
			when cfg_IOs => Slv_RdData <= Inputs;
			--------------------------------------------------------------------
			when others => null;
			end case;
			--------------------------------------------------------------------
		end if;
	end process;

--------------------------------------------------------------------------------
--	Write	Outputs
--------------------------------------------------------------------------------
	process(Q25) begin
		if rising_edge(Q25) then
			-- global Reset
			if (cop_rst = H) then
				-- clear all outputs
				o_Out <= x"0000";
			elsif (Slv_WrEn=H) then
				----------------------------------------------------------------
				case Slv_Addr is
				----------------------------------------------------------------
				-- Write Outputs
				----------------------------------------------------------------
				when cfg_IOs => o_Out <= Slv_WrData;
				----------------------------------------------------------------
				when others => null;
				end case;
				----------------------------------------------------------------
			end if;
		end if;
	end process;

	max2_spi : entity work.spi
	PORT MAP (
		ncs	=>	nSPI_CS,
		sck	=>	SPI_CLK,
		si	=>	SPI_D,
		so	=>	SPI_Q
	);
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
