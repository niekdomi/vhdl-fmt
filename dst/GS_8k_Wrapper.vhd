---------------------------------------------------------------------------
--
--  GinSlave 8kByte WrapperWrapper
--
---------------------------------------------------------------------------
--
--  project		: GS_LINK
--  programmer  : F:Baschung, INDEL AG
--  date		: 21.05.2004
--  version		: 1.00
--  language	: VHDL
--  system		: Project Navigator
--
--  purpose
--		- wraps all GinSubModules to the main GinModule
--		- wraps a second BRAM-Port to connect a COP_Master
--
---------------------------------------------------------------------------
--	Revisions
---------------------------------------------------------------------------
--	19.12.2012-FB	von 4kByte Wrapper abgeleitet
--	16.05.2014-le	- 8k/3portram: adjustments ans support for cop-mas2
--	06.09.2016-le	- support ginlink diagnostic
--	09.02.2017-le	- add i_8k3p_Enable to enable/disable 3port and 8k feature (rev>=0x210).
--	24.02.2017-le	- disable 2.port write when i_8k3p_Enable=L
--					- remove addresscomperator for improving timing. cpu can now write to eeprom and cop config
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	25.04.2018-le	- add ram int for GinOpt 0x1c4 = 0x00000001 when g_Tunnel=1
--------------------------------------------------------------------------------
--$Rev:: 4868                   $
--$Author:: Leuthold                     $
--$Date:: 2018-04-25 17:12:30 +0200 (Mi., 25 Apr 2018)        $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY gin_link;
USE gin_link.ALL;
LIBRARY gin_slave;
USE gin_slave.ALL;

LIBRARY BRAM;
USE BRAM.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

--------------------------------------------------------------------------------
entity GS_8k_Wrap is
	generic (
		-- 1=64Bit / 0=32Bit DP-RAM
		g64_n32BitRam 	: integer range 0 to 1 := 1;		-- default is 64Bit RAM
		-- generate first BRAM and a 64Bit Port to connect the PowerPC
		g_FirstPort		: integer range 0 to 1 := 1;		-- default is FP-64
--not implemented (ram)		g_OUTREG_A		: in integer range 0 to 1 := 0;
		-- generate second BRAM and a 32Bit Port to connect direclty the C64-Master
		g_SecondPort		: integer range 0 to 1 := 0;		-- default is no SP
		-- COP-Master Rev in BRAM
		g_CopMasRev			: std_logic_vector(15 downto 0) := (others => L);
		g_Tunnel	    : in  natural range 0 to 1 := 0
	);
	port (
		i_Q62_5				: in  std_logic;
		i_Q125				: in  std_logic;

		i_xChanger			: in  std_logic;

		-- GinFrame flag word (Blink-Bit)
		o_GF_Flags			: out std_logic_vector(15 downto 0);
		-- Page-Data access start (short puls)
		o_PgTlgSyn			: out std_logic_vector( 7 downto 0);
		-- Page-Data received and CRC-ok (short pulse)
		o_PgIRQs			: out std_logic_vector( 7 downto 0);
		-- Page-Safety word Bit-0 used as watchdog toggle-bit
		o_PgWdogs			: out std_logic_vector( 7 downto 0);
		-- flags for the slave
		o_SlvFlags			: out std_logic_vector(31 downto 0);

		o_IRQ				: out std_logic;

		o_fwGMII_TxDat		: out std_logic_vector(7 downto 0);
		o_fwGMII_TxDv		: out std_logic;
		o_fwGMII_TxErr		: out std_logic;
		i_fwGMII_RxDat		: in  std_logic_vector(7 downto 0);
		i_fwGMII_RxDv		: in  std_logic;
		i_fwGMII_RxErr		: in  std_logic;

		o_bwGMII_TxDat		: out std_logic_vector(7 downto 0);
		o_bwGMII_TxDv		: out std_logic;
		o_bwGMII_TxErr		: out std_logic;
		i_bwGMII_RxDat		: in  std_logic_vector(7 downto 0);
		i_bwGMII_RxDv		: in  std_logic;
		i_bwGMII_RxErr		: in  std_logic;
		o_fw_error			: out std_logic;
		o_bw_error			: out std_logic;

		o_EthRun 			: out std_logic;
		o_GinRun 			: out std_logic;

		o_fwGinRun 			: out std_logic;
		o_bwGinRun 			: out std_logic;
		-- first port for PPC  	(32 or 64Bit)
		i_FP_Clk 			: in  std_logic;
		i_FP_EN 			: in  std_logic;
		i_FP_Addr			: in  std_logic_vector(15 downto 0);
		i_FP_WEN 			: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_FP_WrData			: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_FP_RdData 		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		-- second-port to C64-master, always 32Bit
		i_SP_Clk	    	: in  std_logic						:= '0';
		i_SP_EN		    	: in  std_logic						:= '0';
		i_SP_Addr 	    	: in  std_logic_vector(15 downto 0) := (others => '0');
		i_SP_WEN 	    	: in  std_logic_vector( 3 downto 0)	:= (others => '0');
		i_SP_WrData 		: in  std_logic_vector(31 downto 0)	:= (others => '0');
		o_SP_RdData 		: out std_logic_vector(31 downto 0)	:= (others => '0');
		
		i_Mac2Tun_D		: in  std_logic_vector(15 downto 0) := (others => L);
		i_Mac2Tun_Req	: in std_logic := L;
		o_Mac2Tun_En	: out std_logic;
		o_Mac2Tun_Req_ack: out std_logic;
		o_Tun2Mac_D		: out std_logic_vector(15 downto 0);
		o_Tun2Mac_Dv	: out std_logic;
		
		i_linkState0		: in  std_logic;
		i_linkState1		: in  std_logic;
		
		i_8k3p_Enable		: in  std_logic
	);

end GS_8k_Wrap;

--------------------------------------------------------------------------------
architecture impl of GS_8k_Wrap is
--------------------------------------------------------------------------------
	-- !!!! raminit is not in all FPGAs suportet !!!!
	function BRAM_init (C96Slave , SecondPort : integer) return tSLV_Nx32 is
		variable init : tSLV_Nx32(0 to 2047);
		constant DF_GIN_OPT : tSLV_Nx32(0 to 1) := (x"00000000",x"00000001");
	begin
		if (g_FirstPort = 1) and (g_SecondPort = 0) then
			init := (	--	GinSlave only
				448/4 => x"8000_0210"				,	-- 0x1C0	Typ 8K, GS only ; GAL_Revision
				452/4 => DF_GIN_OPT(g_Tunnel)		,	-- 0x1c4	GinOpt
				-- no COP_Master init at all
				others 	=> (others => '0')
				);
		elsif (g_FirstPort = 0) and (g_SecondPort = 1) then
			init := (	-- COP_Master only
				448/4 => x"8100_0210"				,	-- 0x1C0	Typ 8K, COP only ; GAL_Revision
				452/4 => DF_GIN_OPT(g_Tunnel)		,	-- 0x1c4	GinOpt
				768/4 => x"9000_0C35"				,	-- 0x300	start 8kHz 40ns Timer, dis OverRun
				776/4 => x"0000" & g_CopMasRev		,	-- 0x308	Passive Master revision
				792/4 => x"0000_0000"				,	-- 0x318	128Bytes to Addr 000
				796/4 => x"1109_0080"				,	-- 0x31C	read C96-EEP to 0000
				others 	=> (others => '0')
				);
		elsif (g_FirstPort = 1) and (g_SecondPort = 1) then
			init := (	-- GinSlave and COP_Master
--				128/4 => x"12345678"				,	-- 0x080	Test-Pattern
--				132/4 => x"9ABCDEF0"				,	-- 0x084
				448/4 => x"0000_0210"				,	-- 0x1C0	Typ 8K, GS & COP ; GAL_Revision !!! leading 0x8200 set by sw!!!
				452/4 => DF_GIN_OPT(g_Tunnel)		,	-- 0x1c4	GinOpt
				768/4 => x"0000_0000"				,	-- 0x300	do not start C64_MasSeq
				776/4 => x"0000" & g_CopMasRev		,	-- 0x308	Passive Master revision
				-- EEPROM-Read will be done by PPC
				others 	=> (others => '0')
				);
		end if;

		return init;
	end function;
	
	function get_raminit_file(input : integer) return string is
	begin
		if ((g_FirstPort = 1) and (g_SecondPort = 1) and (g64_n32BitRam=0) and (g_Tunnel=0)) then
			return "..\gin_slave\GS32_8k.mif";
		elsif ((g_FirstPort = 1) and (g_SecondPort = 1) and (g64_n32BitRam=0) and (g_Tunnel=1)) then
			return "..\gin_slave\GS32_8k_Tun.mif";
		else
			assert 1<0
			report "mif file not yet created" severity error;
			return "0000";
		end if;
	end get_raminit_file;
	
	constant INIFile : string := get_raminit_file(0);
	
--------------------------------------------------------------------------------
--	My MAC Adress
--------------------------------------------------------------------------------
	constant MyMac : std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_00";

--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------
	signal FP_Addr32_A			: std_logic_vector(10 downto 0) := (others => '0');
	signal FP_Addr64_A			: std_logic_vector( 9 downto 0) := (others => '0');
	signal PPC_RAM_EN_B			: std_logic                 	:= '1';
	signal PPC_RAM_Addr_B		: std_logic_vector(10 downto 0) := (others => '0');
	signal PPC_RAM_Dout_B		: std_logic_vector(31 downto 0) := (others => '0');

	signal SP_Addr_A	    	: std_logic_vector(10 downto 0)	:= (others => '0');
	signal C64MAS_RAM_EN_B		: std_logic						:= '1';
	signal C64MAS_RAM_Addr_B	: std_logic_vector(10 downto 0)	:= (others => '0');
	signal C64MAS_RAM_Dout_B	: std_logic_vector(31 downto 0)	:= (others => '0');

--------------------------------------------------------------------------------
	signal EthCRC				: std_logic_vector(31 downto 0);
	signal CrcRun 				: std_logic;
	signal CrcClr 				: std_logic;
	signal EthError				: std_logic;
	signal EthRun 				: std_logic;
	signal sUdpCsum				: std_logic;

	signal fwGinRun				: std_logic;
	signal bwGinRun				: std_logic;

--------------------------------------------------------------------------------
--	GinSlave
	signal GSRx_PPC_RdData   	: std_logic_vector(31 downto 0) := (others => '0'); -- PPC Side
	signal GSRx_C64MAS_RdData   : std_logic_vector(31 downto 0) := (others => '0'); -- COP-Master
	signal GSRx_MEM_RdData  	: std_logic_vector(31 downto 0);
	signal GSRx_MEM_WrData  	: std_logic_vector(31 downto 0);
	signal GSRx_MEM_Adr			: std_logic_vector(15 downto 0) := (others => '0');
	signal GSRx_MEM_ByteAdr		: std_logic_vector(15 downto 0) := (others => '0');
	signal GSRx_MEM_WR			: std_logic;
	signal GSRx_MEM_WRx4		: std_logic_vector( 3 downto 0);

	signal WrBufTgl				: std_logic_vector( 7 downto 0);	-- wr-buffer toggle
	signal WrBufTgl_ppc_dom 	: std_logic_vector( 7 downto 0);	-- wr-buffer toggle on ppc clk domain
	Signal PgIRQs				: std_logic_vector( 7 downto 0);
	Signal PgWdogs				: std_logic_vector( 7 downto 0);
	Signal PgTlgSyn				: std_logic_vector( 7 downto 0);
	Signal GF_Flags				: std_logic_vector(15 downto 0);
	signal GinError				: std_logic;
--------------------------------------------------------------------------------
 	signal fwRxCharIsk 			: std_logic_vector( 1 downto 0);
	signal fwRxData				: std_logic_vector(15 downto 0);
	signal fwTxCharIsk 			: std_logic_vector( 1 downto 0);
	signal fwTxData				: std_logic_vector(15 downto 0);

	signal fwxchTxCharIsk 		: std_logic_vector( 1 downto 0);
	signal fwxchTxData 			: std_logic_vector(15 downto 0);

--------------------------------------------------------------------------------
	signal bwRxCharIsk 			: std_logic_vector( 1 downto 0);
	signal bwRxData				: std_logic_vector(15 downto 0);
	signal bwRxCRCERR 			: std_logic;
	signal bwTxCharIsk 			: std_logic_vector( 1 downto 0);
	signal bwTxData				: std_logic_vector(15 downto 0);

--------------------------------------------------------------------------------
	signal err 		        	: std_logic;
	signal sw_RxBuf				: std_logic_vector(15 downto 0)	:= (others => '0');
	signal sp_sw_RxBuf			: std_logic_vector(15 downto 0)	:= (others => '0');
--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	Signal ICU_RdData		: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	Signal ICU_IRQs_Inp		: std_logic_vector(31 downto 0) := (others => '0');
	Signal ICU_EN			: std_logic;

	signal ByteAdr		: std_logic_vector(15 downto 0);
	signal FP_EN		: std_logic;
	signal FP_RdData	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);

	type t_out_select is (rxram,icu);
	signal out_select_p			: t_out_select := rxram;
	signal out_select_r			: t_out_select := rxram;
	signal out_select			: t_out_select := rxram;
--------------------------------------------------------------------------------
	
	signal error_ethfw : std_logic := L;
	signal error_ethbw : std_logic := L;
	signal linkdown_fw : std_logic := L;
	signal linkdown_bw : std_logic := L;
	signal xChangerErr : std_logic := L;
	signal EthError_bw : std_logic := L;
	
	signal linkState0_1 : std_logic := L;
	signal linkState1_1 : std_logic := L;
	signal xChanger_1 : std_logic := L;
	
	signal EthCnt_fw : std_logic_vector(11 downto 0);
	signal EthCnt_bw : std_logic_vector(11 downto 0);

	signal int8k3p_Enable_62_5 : std_logic := L;

--------------------------------------------------------------------------------
begin

--------------------------------------------------------------------------------
--	convert 8-Bit GMII to 16-Bit MGT Data
--------------------------------------------------------------------------------
	uWrap_fwGMII_MGT: entity gin_link.GL_GMII_MGT
	PORT MAP(
		i_Q125			=> i_Q125		 	,
		i_Q62_5			=> i_Q62_5			,
		i_GMII_RxDat	=> i_fwGMII_RxDat	,
		i_GMII_RxDv		=> i_fwGMII_RxDv	,
		i_GMII_RxErr	=> i_fwGMII_RxErr	,
		o_MGT_RxData	=> fwRxData			,
		o_MGT_RxCharIsk	=> fwRxCharIsk
	);

	uWrap_bwGMII_MGT: entity gin_link.GL_GMII_MGT
	PORT MAP(
		i_Q125			=> i_Q125		 	,
		i_Q62_5			=> i_Q62_5			,
		i_GMII_RxDat	=> i_bwGMII_RxDat	,
		i_GMII_RxDv		=> i_bwGMII_RxDv	,
		i_GMII_RxErr	=> i_bwGMII_RxErr	,
		o_MGT_RxData	=> bwRxData			,
		o_MGT_RxCharIsk	=> bwRxCharIsk
	);

--------------------------------------------------------------------------------
--	convert 16-Bit MGT  to 8-Bit GMII Data
--------------------------------------------------------------------------------
	uWrap_fwMGT_GMII: entity gin_link.GL_MGT_GMII
	PORT MAP(
--		i_Q62_5			=> i_Q62_5			,
		i_MGT_TxCharIsk	=> fwTxCharIsk		,
		i_MGT_TxData	=> fwTxData			,
		i_Q125			=> i_Q125			,
		o_GMII_TxDat	=> o_fwGMII_TxDat	,
		o_GMII_TxDv		=> o_fwGMII_TxDv	,
		o_GMII_TxErr	=> o_fwGMII_TxErr
	);

	uWrap_bwMGT_GMII: entity gin_link.GL_MGT_GMII
	PORT MAP(
--		i_Q62_5			=> i_Q62_5			,
		i_MGT_TxCharIsk	=> bwTxCharIsk		,
		i_MGT_TxData	=> bwTxData			,
		i_Q125			=> i_Q125			,
		o_GMII_TxDat	=> o_bwGMII_TxDat	,
		o_GMII_TxDv		=> o_bwGMII_TxDv	,
		o_GMII_TxErr	=> o_bwGMII_TxErr
	);

--------------------------------------------------------------------------------
--	synch irqs and flags with PPC-Clock
--------------------------------------------------------------------------------
--	process (i_ppc_dom_clk) begin
--		if rising_edge(i_ppc_dom_clk) then
--			o_IRQs		<= PgIRQs;
--			o_GF_Flags	<= GF_Flags;
--			o_Wdogs		<= PgWdogs;
--		end if;
--	end process;

--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------


	ICU_IRQs_Inp <= x"000000" & PgIRQs;

	uWrap_ICU: entity gin_link.Gin_ICU
	generic map (
--		g_OUTREG_A => g_OUTREG_A,
		g64_n32BitRam => g64_n32BitRam
	)
	port MAP(
		i_ICU_Clk	=> i_FP_Clk	,	-- liegt im BRAM AdrRaum
		i_ICU_EN	=> ICU_EN		,
		i_WR 		=> i_FP_WEN	,
		i_addr		=> ByteAdr(2)	,	-- for 32Bit Read
		i_addr_tim	=> ByteAdr(3)	,	-- read IRQ-Timer
		i_Din		=> i_FP_WrData	,
		o_Dout		=> ICU_RdData	,
		i_IRQs		=> ICU_IRQs_Inp	,
		o_IRQ		=> o_IRQ
	);

--------------------------------------------------------------------------------
--	Dualport Block-Ram
--------------------------------------------------------------------------------
--	side A	PowerPC
--	side B	GinLink

-- 8k Slaves have
-- 		COP_CFG		0300..07FF
-- 		Tx-BUF		0800..0FFF
-- 		Rx_BUF0		1000..17FF
-- 		Rx_BUF1		1800..1FFF
--------------------------------------------------------------------------------

	process (i_FP_Clk)
	begin
		if rising_edge(i_FP_Clk) then
			WrBufTgl_ppc_dom <= WrBufTgl;
		end if;
	end process;

	process (ByteAdr,i_FP_Addr,i_FP_EN,FP_RdData,ICU_RdData,out_select) begin
		if g64_n32BitRam=1 then
			ByteAdr <= i_FP_Addr(12 downto 0) & "000";
		else
			ByteAdr <= i_FP_Addr(13 downto 0) & "00";
		end if;

		FP_EN	<= L;
		ICU_EN		<= L;

		if (ByteAdr < x"C000") then
			FP_EN <= i_FP_EN;
		--	o_FP_RdData <= FP_RdData;
		else
			ICU_EN		<= i_FP_EN;
		--	o_FP_RdData	<= ICU_RdData;
		end if;

		case out_select is
		when icu => o_FP_RdData <= ICU_RdData;
		when rxram => o_FP_RdData <= FP_RdData;
		end case;

	end process;

--	outreg_en: if g_OUTREG_A=1 generate
--		out_select <= out_select_p;
--	end generate outreg_en;

--	outreg_dis: if g_OUTREG_A=0 generate
		out_select <= out_select_r;
--	end generate outreg_dis;

	process (i_FP_Clk) begin
		if rising_edge(i_FP_Clk) then
			if FP_EN=H then
				out_select_r <= rxram;
			elsif ICU_EN=H then
				out_select_r <= icu;
			end if;
			out_select_p <= out_select_r;
		end if;
	end process;

--------------------------------------------------------------------------------
--	64-Bit PPC Anbindung
--------------------------------------------------------------------------------
--	wird verwendet für:
--		Gin-Slaves mit PPC-Card	(Gin-SAC,MAX,AX,IMP)
-- 	Dieses BRAM verbindet immer nur den GinSlave zum lokalen PPC
-- 	Die ganzen COP_Master-Bereiche bleiben also leer
-- 	Ich kann aber mit lesen, was der GinLink für den COP-Master aufsetzt
--------------------------------------------------------------------------------
--	0000..007F		System-EEPROM
-- 	0080..017F					                COP_Module EEPROM,SPI,JTG
-- 	0180..1FFF		GinLink stuff
--	0200..02FF		GinLink PgAddrComp
-- 	0300..031F					                COP_MAster Command
-- 	0320..07FF					                COP_MasterTab
-- 	0800..0FFF		GinLink TxBuf		        COP_Master Rx
--	4000..4007		ICU
-- 	8000..87FF		GinLink RxBuf-0		        COP_Master Tx
-- (8800..8FFF)		GinLink RxBuf-1
--------------------------------------------------------------------------------
--	64BitAdr		A1	0010		A5	0100		A9	1000
--					A2	0020		A6	0200		A10	2000
--					A3	0040		A7	0400		A11	4000
--	A0	0008		A4	0080		A8	0800        A12 8000
--------------------------------------------------------------------------------
FirstPort64 : if (g_FirstPort = 1) generate
begin

	BR32 : if (g64_n32BitRam = 0) generate
	begin
	--	Write-Buffer toggle
		process (i_FP_Addr,WrBufTgl_ppc_dom,i_8k3p_Enable) begin
			FP_Addr32_A(10 downto 0)	<= i_FP_Addr(10 downto 0);
	
			if (i_8k3p_Enable=H) then
			-- read from RX_BUF 1000..87FF
			if (i_FP_Addr(13 downto 10) /= x"0") then
				FP_Addr32_A(10) <= H;
				-- get 1000..17FF	if GS uses RX-BUF1
				-- get 1800..1FFF	if GS uses RX-BUF0
				FP_Addr32_A(9) <= not	WrBufTgl_ppc_dom(CONV_INTEGER(i_FP_Addr(12 downto 10)));
			end if;
			else
				FP_Addr32_A(10) <= L;
				if (i_FP_Addr(9)=H) then	-- Write-Buffer access
					FP_Addr32_A(8) <= not WrBufTgl_ppc_dom(CONV_INTEGER(i_FP_Addr(12 downto 10)));
				end if;
			end if;
		end process;
	
	
		uWarp_BRAM : entity BRAM.BRAM_8kByte_A32_B32
		generic map (
			BRAM_Init		=> BRAM_init(g_FirstPort , g_SecondPort),
			g_INIT_FILE		=> INIFile
		)
		PORT MAP(
			i_BRAM_Clk_A  	=> i_FP_Clk					,
			i_BRAM_EN_A		=> FP_EN					,
			i_BRAM_WEN_A  	=> i_FP_WEN					,
			i_BRAM_Addr_A 	=> FP_Addr32_A				,
			i_BRAM_Dout_A	=> i_FP_WrData				,
			o_BRAM_Din_A	=> FP_RdData				,
	
			i_BRAM_Clk_B	=> i_Q62_5					,
			i_BRAM_EN_B		=> H						,
			i_BRAM_WEN_B	=> GSRx_MEM_WRx4			,
			i_BRAM_Addr_B	=> GSRx_MEM_Adr(10 downto 0),
			i_BRAM_Dout_B	=> GSRx_MEM_WrData			,
			o_BRAM_Din_B 	=> GSRx_PPC_RdData
		);
	end generate BR32;

--	64-Bit DP_RAM
--------------------------------------------------------------------------------
--	wird verwendet für:
--		Gin-Slaves mit PPC-Card	(Gin-SAC,MAX,AX,IMP)
--------------------------------------------------------------------------------
	BR64 : if (g64_n32BitRam = 1) generate
	begin
	--	Write-Buffer toggle
		process (i_FP_Addr,WrBufTgl_ppc_dom,i_8k3p_Enable) begin
			FP_Addr64_A(9 downto 0)	<= i_FP_Addr(9 downto 0);
	
			if (i_8k3p_Enable=H) then
			-- read from RX_BUF 1000..87FF
			if (i_FP_Addr(12 downto 9) /= x"0") then
				FP_Addr64_A(9) <= H;
				-- get 1000..17FF	if GS uses RX-BUF1
				-- get 1800..1FFF	if GS uses RX-BUF0
				FP_Addr64_A(8) <= not	WrBufTgl_ppc_dom(CONV_INTEGER(i_FP_Addr(11 downto 9)));
			end if;
			else
				FP_Addr32_A(9) <= L;
				if (i_FP_Addr(8)=H) then	-- Write-Buffer access
					FP_Addr32_A(7) <= not WrBufTgl_ppc_dom(CONV_INTEGER(i_FP_Addr(11 downto 9)));
				end if;
			end if;
		end process;
	
	
		uWarp_BRAM : entity BRAM.BRAM_8kByte_A64_B32
		generic map (
			BRAM_Init		=> BRAM_init(g_FirstPort , g_SecondPort),
			g_INIT_FILE		=> INIFile
		)
		PORT MAP(
			i_BRAM_Clk_A  	=> i_FP_Clk					,
			i_BRAM_EN_A		=> FP_EN					,
			i_BRAM_WEN_A  	=> i_FP_WEN					,
			i_BRAM_Addr_A 	=> FP_Addr64_A				,
			i_BRAM_WrData_A => i_FP_WrData				,
			o_BRAM_RdData_A => FP_RdData				,
	
			i_BRAM_Clk_B	=> i_Q62_5					,
			i_BRAM_EN_B		=> H						,
			i_BRAM_WEN_B	=> GSRx_MEM_WRx4			,
			i_BRAM_Addr_B	=> GSRx_MEM_Adr(10 downto 0),
			i_BRAM_WrData_B	=> GSRx_MEM_WrData			,
			o_BRAM_RdData_B => GSRx_PPC_RdData
		);
	end generate BR64;
end generate;

--------------------------------------------------------------------------------
--	32-Bit C64-Master  Anbindung
--	second port for C64-Master
--------------------------------------------------------------------------------
--  32BitAdr        A2  0010        A6  0100        A10 1000        A14 not used
--                  A3  0020        A7  0200        A11 2000        A15 not used
--  A0  0004        A4  0040        A8  0400        A12 4000
--  A1  0008        A5  0080        A9  0800        A13 8000
--------------------------------------------------------------------------------
-- C96_passive_Slave    0x0200 Tx,Rx0,Rx1 BufferSize   0xA00,0xC00,0xE00
--------------------------------------------------------------------------------
SecondPort32 : if (g_SecondPort = 1) generate
signal we_sp_gin : std_logic_vector( 3 downto 0);
signal we_sp_cop : std_logic_vector( 3 downto 0);
begin
--	Write-Buffer toggle
	process (i_SP_Addr,WrBufTgl_ppc_dom,sp_sw_RxBuf)
	begin
		SP_Addr_A(10 downto 0) <= i_SP_Addr(10 downto 0);

		-- read from RX_BUF 1000..87FF
		if (i_SP_Addr(13 downto 10) /= x"0") then
			SP_Addr_A(10) <= H;
			-- get 1000..17FF	if GS uses RX-BUF1
			-- get 1800..1FFF	if GS uses RX-BUF0
			SP_Addr_A(9) <= not	WrBufTgl_ppc_dom(CONV_INTEGER(i_SP_Addr(12 downto 10)));
		end if;
	end process;

	process(int8k3p_Enable_62_5,GSRx_MEM_WRx4)
	begin
		if  (int8k3p_Enable_62_5 = L) then
			we_sp_gin			<= (others => L);
		else
			we_sp_gin			<= GSRx_MEM_WRx4;
		end if;
	end process;
	
	process(i_8k3p_Enable,i_SP_WEN)
	begin
		if  (i_8k3p_Enable = L) then
			we_sp_cop			<= (others => L);
		else
			we_sp_cop			<= i_SP_WEN;
		end if;
	end process;

uWarp_RAM2 : entity BRAM.BRAM_8kByte_A32_B32
	generic map (
		BRAM_Init		=> BRAM_init(g_FirstPort , g_SecondPort),
		g_INIT_FILE		=> INIFile
	)
	PORT MAP(
		-- C64-master side
		i_BRAM_Clk_A	=> i_SP_Clk		 			,
		i_BRAM_EN_A		=> i_SP_EN		 			,
		i_BRAM_WEN_A	=> we_sp_cop	 			,
		i_BRAM_Addr_A	=> SP_Addr_A				,
		i_BRAM_Dout_A	=> i_SP_WrData	 			,
		o_BRAM_Din_A	=> o_SP_RdData				,
		-- GinSlave side
		i_BRAM_Clk_B	=> i_Q62_5					,
		i_BRAM_EN_B		=> H						,
		i_BRAM_WEN_B	=> we_sp_gin				,
		i_BRAM_Addr_B	=> GSRx_MEM_Adr(10 downto 0),
		i_BRAM_Dout_B	=> GSRx_MEM_WrData			,
		o_BRAM_Din_B	=> GSRx_C64MAS_RdData
	);

end generate;

--------------------------------------------------------------------------------
--	GinLink Read
--------------------------------------------------------------------------------
--	Im Bereich 	0080..0180	COP-EEPROM
--  und			0300..07FF	COP-Config
--  wird IMMER nur von der C64-Master-Seite gelesen.
-- 	Der PPC kann in diesem Bereich also nichts dem GinLink übergeben
-- 24.02.17-le: wegen timing: die processorseite wird immer geored
--------------------------------------------------------------------------------
--  32BitAdr        A2  0010        A6  0100        A10 1000
--                  A3  0020        A7  0200        A11 2000
--  A0  0004        A4  0040        A8  0400        A12 4000
--  A1  0008        A5  0080        A9  0800        A13 8000
--------------------------------------------------------------------------------
	-- nur zur besseren Lesbarkeit
	GSRx_MEM_ByteAdr <= GSRx_MEM_Adr(13 downto 0) & "00";

	process (GSRx_MEM_ByteAdr,GSRx_PPC_RdData,GSRx_C64MAS_RdData,int8k3p_Enable_62_5)
	begin
		if (int8k3p_Enable_62_5=L) then
			GSRx_MEM_RdData <= GSRx_PPC_RdData;
		--els
	--	if  (int8k3p_Enable_62_5=H)
	--	and (((GSRx_MEM_ByteAdr >= x"0080") and (GSRx_MEM_ByteAdr <  x"0180"))
	--	or	((GSRx_MEM_ByteAdr >= x"0300") and (GSRx_MEM_ByteAdr <  x"0800"))) then
	--		-- read from C64Master
	--		GSRx_MEM_RdData <= GSRx_C64MAS_RdData;
		else
		  -- read from GinSlave
			GSRx_MEM_RdData <= GSRx_C64MAS_RdData or GSRx_PPC_RdData;
		end if;
	end process;

--------------------------------------------------------------------------------
--	GinFrame Sequencer
--------------------------------------------------------------------------------
	uWrap_RxSeq: entity gin_slave.GS_RxSeq
	generic map (
		-- use MEM_Layout for 8k_BRAM
		g_8k_MEM			=> 1,
		g_Tunnel			=> g_Tunnel
	)
	PORT MAP(
		i_Q62_5				=> i_Q62_5			,
		i_EthRun 			=> EthRun			,
		i_GinRun 			=> fwGinRun			,
		i_RxCharIsk			=> fwRxCharIsk		,
		i_RxData 			=> fwRxData			,
		i_sUdpCsum			=> sUdpCsum			,
		i_EthCRC			=> EthCRC			,
		i_CrcRun 			=> CrcRun			,
		i_CrcClr 			=> CrcClr			,
		i_EthError			=> EthError			,
		o_GinError			=> GinError			,
		o_TxCharIsk			=> fwTxCharIsk		,
		o_TxData			=> fwTxData			,
		i_MEM_RdData		=> GSRx_MEM_RdData	,
		o_MEM_WrData		=> GSRx_MEM_WrData	,
		o_MEM_Adr			=> GSRx_MEM_Adr		,
		o_MEM_WR			=> GSRx_MEM_WR		,
		o_WrBufTgl			=> WrBufTgl			,
		o_PgIRQs			=> PgIRQs			,
		o_PgWdogs			=> o_PgWdogs		,
		o_GF_Flags			=> o_GF_Flags		,
		o_SlvFlags			=> o_SlvFlags		,
		o_PgTlgSyn			=> o_PgTlgSyn		,
		i_error_ethfw		=> error_ethfw		,
		i_error_ethbw		=> error_ethbw		,
		i_EthError_bw		=> EthError_bw		,
		i_linkdown_fw		=> linkdown_fw		,
		i_linkdown_bw		=> linkdown_bw		,
		i_xChangerErr		=> xChangerErr		,
		o_fw_error			=> o_fw_error		,
		o_bw_error			=> o_bw_error		,
		i_8k3p_Enable		=> int8k3p_Enable_62_5,
		o_Tun2Mac_D		=> o_Tun2Mac_D	,
		o_Tun2Mac_Dv	=> o_Tun2Mac_Dv	,
		i_Mac2Tun_D		=> i_Mac2Tun_D	,
		o_Mac2Tun_En	=> o_Mac2Tun_En,
		i_Mac2Tun_Req	=> i_Mac2Tun_Req,
		o_Mac2Tun_Req_ack => o_Mac2Tun_Req_ack
	);
	GSRx_MEM_WRx4 <= GSRx_MEM_WR & GSRx_MEM_WR & GSRx_MEM_WR & GSRx_MEM_WR;
	o_PgIRQs <= PgIRQs;

--------------------------------------------------------------------------------
--	forward Ethernet, IP, UDP Sequencer
--------------------------------------------------------------------------------
	o_EthRun	<= EthRun;
	o_GinRun	<= fwGinRun;
	o_fwGinRun	<= fwGinRun;

	uWrap_fwEthSeq: entity gin_link.GIN_RxEthSeq
	GENERIC MAP (
		i_MyMac		=> MyMac		,
		i_fw		=> H				-- test forward frame
	)
	PORT MAP(
		i_Q62_5		=> i_Q62_5		,
		i_RxCharIsk => fwRxCharIsk	,
		i_RxData 	=> fwRxData		,
		o_EthCRC 	=> EthCRC		,
		o_CrcRun 	=> CrcRun		,
		o_CrcClr 	=> CrcClr		,
		o_CrcError	=> error_ethfw	,
		o_EthError	=> EthError		,
		o_EthRun 	=> EthRun		,
		o_GinRun	=> fwGinRun		,
		o_sUdpCsum	=> sUdpCsum		,
		o_EthCnt	=> EthCnt_fw
	);


--------------------------------------------------------------------------------
--	backward Ethernet, IP, UDP Sequencer
--------------------------------------------------------------------------------
	o_bwGinRun	<= bwGinRun;

	uWrap_bwEthSeq: entity gin_link.GIN_RxEthSeq
	GENERIC MAP (
		i_MyMac		=> MyMac		,
		i_fw		=> L				-- test backward frame
	)
	PORT MAP(
		i_Q62_5		=> i_Q62_5		,
		i_RxCharIsk => bwRxCharIsk	,
		i_RxData 	=> bwRxData		,
		o_EthCRC 	=> open			,
		o_CrcRun 	=> open			,
		o_CrcClr 	=> open			,
		o_CrcError	=> error_ethbw	,
		o_EthError	=> EthError_bw	,
		o_EthRun 	=> open			,
		o_GinRun 	=> bwGinRun		,
		o_sUdpCsum	=> open			,
		o_EthCnt	=> EthCnt_bw
	);

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			linkState0_1 <= i_linkState0;
			linkState1_1 <= i_linkState1;
			xChanger_1 <= i_xChanger;
			
			int8k3p_Enable_62_5 <= i_8k3p_Enable;
			
			if (i_linkState0=L and linkState0_1=H) then
				linkdown_fw <= H;
			else
				linkdown_fw <= L;
			end if;
			
			if (i_linkState1=L and linkState1_1=H) then
				linkdown_bw <= H;
			else
				linkdown_bw <= L;
			end if;
			
			if (i_xChanger/=xChanger_1) then
				xChangerErr <= H;
			else
				xChangerErr <= L;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	Backward channel
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			if (i_xChanger = H) then
				bwTxData	<= fwxchTxData;
				bwTxCharIsk <= fwxchTxCharIsk;
			else
				bwTxData	<= bwRxData;
				bwTxCharIsk <= bwRxCharIsk;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	xchange	MAC, IP and UDP		src <-> dest
--------------------------------------------------------------------------------
	uWrap_Xch:	entity gin_slave.GS_Xchanger
	GENERIC MAP (
		i_MyMac		 => MyMac
	)
	PORT MAP(
		i_Q62_5		 => i_Q62_5			,
		i_RxCharIsk  => fwTxCharIsk		,
		i_RxData	 => fwTxData		,
		o_TxData	 => fwxchTxData		,
		o_TxCharIsk  => fwxchTxCharIsk
	);

--------------------------------------------------------------------------------
end;
