---------------------------------------------------------------------------
--
--  GIN Master Wrapper
--
---------------------------------------------------------------------------
--
--  project		: GIN_LINK
--  programmer  : F:Baschung, INDEL AG
--  date		: 23.08.2004
--  version		: 1.00
--  language	: VHDL
--  system		: Project Navigator
--
--  purpose
--		- wraps all GinMasSubModules to the main Gin Master Module
--
--------------------------------------------------------------------------------
-- revision information
--	10.08.2011-le - add generic for registered outputs (gin-pcie local bus)
--				  -	add generic for 32 bit ram
--	12.12.2011-le - add i_GinRing to enable Ginlink in Ring mode
--	25.06.2012-qfu - add "ixChanger" to allow a running GinLink without a slave.
-- 26.06.2012-qfu - renamed the "ixChanger" signal and changed the funct.:
--		explicit activation needed by software. Generic for loop delay time.
--	24.09.2012-le - change input for Autoclose: PhyLinkDown forward and backward
--					- for stingmode only i_fPhyLinkDown is used.
--					- ringmode use i_fPhyLinkDown and i_bPhyLinkDown
--	04.10.2013-le - adjust ICU BRAM switch
--	23.01.2014-le - added addr to read ICU-IRQ-Timer
--				  - add a output to sync cop master
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--------------------------------------------------------------------------------
--$Rev:: 4697                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-22 13:46:20 +0100 (Fr., 22 Dez 2017)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


LIBRARY gin_link;
USE gin_link.ALL;
LIBRARY gin_master;
USE gin_master.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

--------------------------------------------------------------------------------
entity GM_Wrap is
	generic (
		g_OUTREG_A		: in integer range 0 to 1 := 0;
		g64_n32BitRam	: in integer range 0 to 1 := 1;
		gLoop_Delay		: in integer range 0 to 15:= 1;
		g_Tunnel		: in natural range 0 to 1 := 0;
		g_TX_DATA_Z1	: in natural range 0 to 1 := 0
	);
	port (
		i_Q125 			: in  std_logic;
		i_Q62_5			: in  std_logic;

		i_ppc_dom_clk	: in  std_logic;	--le
		o_IRQ				: out std_logic;

		o_fwGMII_TxDat	: out std_logic_vector(7 downto 0);
		o_fwGMII_TxDv	: out std_logic;
		o_fwGMII_TxErr	: out std_logic;
		i_bwGMII_RxDat	: in  std_logic_vector(7 downto 0);
		i_bwGMII_RxDv	: in  std_logic;
		i_bwGMII_RxErr	: in  std_logic;
		i_AutoCloseEN  : in  std_logic := '0';
		i_fPhyLinkDown  : in  std_logic := '0';
		i_bPhyLinkDown  : in  std_logic := '0';
		o_EthRun 		: out std_logic := '0';
		o_GinRun 		: out std_logic := '0';
		i_GinRing		: in  std_logic := '0';
		
		o_TxSlot_0		: out std_logic;  
		o_SynCopMas		: out std_logic;
		
		o_Mac2Tun_En : out std_logic;
		i_Mac2Tun_Req : in std_logic := '0';
		i_ExtTxData : in  std_logic_vector(15 downto 0) := (others => '0');
		o_ExtRxDv		: out std_logic;
		o_ExtRxData		: out std_logic_vector(15 downto 0);
		
		o_dbgExtData : out std_logic;

		i_BRAM_Clk 		: in  std_logic;
		i_BRAM_EN 		: in  std_logic;
		i_BRAM_Addr 	: in  std_logic_vector(15 downto 0);
		i_BRAM_WEN 		: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_BRAM_Dout 	: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_BRAM_Din 		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0)
	);

end GM_Wrap;

--------------------------------------------------------------------------------
architecture impl of GM_Wrap is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	My MAC Adress
--------------------------------------------------------------------------------
	constant MyMac : std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_00";


	constant g_GL_Rev : bit_vector(31 downto 0) := x"00000103";
--------------------------------------------------------------------------------
	constant H	: std_logic := '1';
	constant L	: std_logic := '0';

	signal PPC_RdData	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	signal PPC_WrData	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	-- 64Bit PLB_Adr --> ByteAdr
	signal ByteAdr 		: std_logic_vector(15 downto 0);

--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	signal EthCRC			: std_logic_vector(31 downto 0);
	signal EthError			: std_logic;
	signal bwEthRun			: std_logic;
	signal bwGinRun			: std_logic;
	signal sUdpCsum			: std_logic;

--------------------------------------------------------------------------------
--	Tx Sequencer
--------------------------------------------------------------------------------
	signal TxMEM_RdData		: std_logic_vector(31 downto 0);
	signal TxMEM_WrData		: std_logic_vector(31 downto 0);
	signal TxMEM_Adr		: std_logic_vector(10 downto 0);
	Signal TxMEM_WR			: std_logic;
	Signal TxSlot_0			: std_logic;
	Signal TxIRQs			: std_logic_vector(11 downto 0);

--------------------------------------------------------------------------------
--	Rx Sequencer
--------------------------------------------------------------------------------
	signal WrBufTgl		: std_logic_vector( 2 downto 0);

	signal RxMEM_RdData		: std_logic_vector(31 downto 0);
	signal RxMEM_WrData		: std_logic_vector(31 downto 0);
	signal RxMEM_Adr		: std_logic_vector(10 downto 0);
	Signal RxMEM_WR			: std_logic;
	signal RxIRQs			: std_logic_vector(15 downto 0);

	Signal GinError			: std_logic;

--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	Signal ICU_RdData		: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	Signal ICU_IRQs_Inp		: std_logic_vector(31 downto 0);
	Signal ICU_EN			: std_logic;

--------------------------------------------------------------------------------
--	TX	DP-Ram
--------------------------------------------------------------------------------
	signal TxBRAM_EN_A 		: std_logic;
	signal oTxBRAM_Din	 	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);

	signal TxBRAM_EN_B 		: std_logic;
	signal TxBRAM_WEN_B		: std_logic_vector( 3 downto 0) := "0000";
	signal TxBRAM_Addr_B 	: std_logic_vector(10 downto 0);
	signal TxBRAM_WrDat_B	: std_logic_vector(31 downto 0);
	signal TxBRAM_RdDat_B 	: std_logic_vector(31 downto 0);

--------------------------------------------------------------------------------
--	RX	DP-Ram
--------------------------------------------------------------------------------
	signal RxBRAM_EN_A 		: std_logic;
	signal oRxBRAM_Din	 	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	signal RxBRAM_EN_B 		: std_logic;
	signal RxBRAM_WEN_B		: std_logic_vector( 3 downto 0);

--------------------------------------------------------------------------------
--	16Bit RxTx Data
--------------------------------------------------------------------------------
	signal bwRxData			: std_logic_vector(15 downto 0) := x"0000";
	signal bwRxCharIsK		: std_logic_vector( 1 downto 0) := "00";
	signal fwTxCharisk 		: std_logic_vector( 1 downto 0);
	signal fwTxData			: std_logic_vector(15 downto 0);
	-- internal signals to "close" the GinLink
	signal bwRxData_Int		: std_logic_vector(15 downto 0) := x"0000";
	signal bwRxCharIsK_Int	: std_logic_vector( 1 downto 0) := "00";
	signal fwTxCharisk_Int 	: std_logic_vector( 1 downto 0);
	signal fwTxData_Int		: std_logic_vector(15 downto 0);
	signal GinRing_Int		: std_logic:= '0';
	signal Delayed_CharIsK	: std_logic_vector(1 downto 0);
	signal Delayed_Data		: std_logic_vector(15 downto 0);
	type   CharIsK_array		is array (natural range <>) of std_logic_vector(1 downto 0);
	type   Data_array			is array (natural range <>) of std_logic_vector(15 downto 0);
	signal Loop_CharIsK		: CharIsK_array(gLoop_Delay downto 0);
	signal Loop_Data			: Data_array(gLoop_Delay downto 0);

	type t_out_select is (txram,rxram,icu);
	signal out_select_p			: t_out_select := rxram;
	signal out_select_r			: t_out_select := rxram;
	signal out_select			: t_out_select := rxram;
	
--------------------------------------------------------------------------------
begin
	o_TxSlot_0 <= TxSlot_0;
--------------------------------------------------------------------------------
--	convert 8-Bit GMII <==> 16-Bit MGT Data
--------------------------------------------------------------------------------
	uWrap_fwGMII_MGT: entity gin_link.GL_GMII_MGT
	PORT MAP(
		i_Q125			=> i_Q125		 	,
		i_Q62_5			=> i_Q62_5			,
		i_GMII_RxDat	=> i_bwGMII_RxDat	,
		i_GMII_RxDv		=> i_bwGMII_RxDv	,
		i_GMII_RxErr	=> i_bwGMII_RxErr	,
		o_MGT_RxData 	=> bwRxData         ,
		o_MGT_RxCharIsk	=> bwRxCharIsK
	);

	uWrap_fwMGT_GMII: entity gin_link.GL_MGT_GMII
	PORT MAP(
--        i_Q62_5			=> i_Q62_5		,
		i_MGT_TxCharIsk	=> fwTxCharIsk		,
		i_MGT_TxData	=> fwTxData			,
		i_Q125			=> i_Q125			,
		o_GMII_TxDat	=> o_fwGMII_TxDat	,
		o_GMII_TxDv		=> o_fwGMII_TxDv	,
		o_GMII_TxErr	=> o_fwGMII_TxErr
	);

--------------------------------------------------------------------------------
--	Da kein Mensch das Din/Dout nachvollziehen kann, hier eine umbenennung:
	o_BRAM_Din	<= PPC_RdData;
	PPC_WrData  <= i_BRAM_Dout;

--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	ICU_IRQs_Inp <= RxIRQs & x"0" & TxIRQs;

	uWrap_ICU: entity gin_link.Gin_ICU
	generic map (
		g_OUTREG_A => g_OUTREG_A,
		g64_n32BitRam => g64_n32BitRam
	)
	port map (
		i_ICU_Clk	=> i_BRAM_Clk		,	-- liegt im BRAM AdrRaum
		i_ICU_EN	=> ICU_EN			,
		i_WR 		=> i_BRAM_WEN		,
		i_Din		=> PPC_WrData		,
		o_Dout		=> ICU_RdData		,
		i_addr		=> i_BRAM_Addr(0)	,
		i_addr_tim	=> i_BRAM_Addr(1)	,	-- read IRQ-Timer
		i_IRQs		=> ICU_IRQs_Inp		,
		o_IRQ		=> o_IRQ
	);

--------------------------------------------------------------------------------
--	Tx Dualport Block-Ram
--------------------------------------------------------------------------------
--	side A	PowerPC
--	side B	GinLink
--------------------------------------------------------------------------------

	----------------------------------------------------------------------------
	--	PPC-Side
	----------------------------------------------------------------------------
	-- PPC-Side Tx/Rx/ICU Block Multiplexer ------------------------------------
	process (ByteAdr,i_BRAM_EN,oTxBRAM_Din,oRxBRAM_Din,ICU_RdData,i_BRAM_Addr,out_select) begin

		if g64_n32BitRam=1 then
			ByteAdr <= "0" & i_BRAM_Addr(11 downto 0) & "000";
		else
			ByteAdr <= "0" & i_BRAM_Addr(12 downto 0) & "00";
		end if;

		TxBRAM_EN_A <= L;
		RxBRAM_EN_A <= L;
		ICU_EN 		<= L;

		if (ByteAdr < x"0400") then         -- ..0x0400	Config
			TxBRAM_EN_A <= i_BRAM_EN;			-- 			write to Tx
			RxBRAM_EN_A <= i_BRAM_EN;			-- 			write also to Rx
--			PPC_RdData	<= oTxBRAM_Din;			-- 			read Tx only

		elsif (ByteAdr < x"2000") then      -- ..0x2000	Tx
			TxBRAM_EN_A <= i_BRAM_EN;			-- 			write Tx only
--			PPC_RdData	<= oTxBRAM_Din;			-- 			read Tx

		elsif (ByteAdr < x"4000") then		-- ..0x4000	Rx
			RxBRAM_EN_A <= i_BRAM_EN;			-- 			write Rx only
--			PPC_RdData	<= oRxBRAM_Din;			-- 			rd Rx

		else
			ICU_EN		<= i_BRAM_EN;			-- 			select IRQcontroller
--			PPC_RdData	<= ICU_RdData;			-- 			rd IRQ controller
		end if;

		case out_select is
		when txram => PPC_RdData <= oTxBRAM_Din;
		when rxram => PPC_RdData <= oRxBRAM_Din;
		when icu => PPC_RdData <= ICU_RdData;
		end case;

	end process;

	outreg_en: if g_OUTREG_A=1 generate
		out_select <= out_select_p;
	end generate outreg_en;

	outreg_dis: if g_OUTREG_A=0 generate
		out_select <= out_select_r;
	end generate outreg_dis;

	process (i_BRAM_Clk) begin
		if rising_edge(i_BRAM_Clk) then
			if TxBRAM_EN_A=H then
				out_select_r <= txram;
			elsif RxBRAM_EN_A=H then
				out_select_r <= rxram;
			elsif ICU_EN=H then
				out_select_r <= icu;
			end if;
			out_select_p <= out_select_r;
		end if;
	end process;


--------------------------------------------------------------------------------
--	Gin Tx Sequencer
--------------------------------------------------------------------------------
	uWrap_TxSeq: entity gin_master.gm_txseq
	generic map (
		g_Tunnel => g_Tunnel,
		g_TX_DATA_Z1 => g_TX_DATA_Z1
	)
	port MAP(
		i_Q125			=> i_Q125		,
		i_Q62_5			=> i_Q62_5		,
		i_MEM_RdData	=> TxMEM_RdData	,
		o_MEM_WrData	=> TxMEM_WrData	,
		o_MEM_Adr		=> TxMEM_Adr	,
		o_MEM_WR		=> TxMEM_WR		,
		o_TxSlot_0		=> TxSlot_0		,
		o_TxIRQs		=> TxIRQs		,
		o_SynCopMas		=> o_SynCopMas	,
		o_TxCharIsK		=> fwTxCharIsK	,
		o_TxData		=> fwTxData		,
		o_Mac2Tun_En	=> o_Mac2Tun_En,
		i_Mac2Tun_Req	=> i_Mac2Tun_Req,
		i_ExtTxData		=> i_ExtTxData,
		o_dbgExtData => o_dbgExtData
	);

--------------------------------------------------------------------------------
-- Select the RX data: Real RX data or loop the TX data by exchanging src, & des.
--------------------------------------------------------------------------------
--There is no Slave connected...link status = '0', i_PhyLinkDown = '1' to be comp.

Create_Loop_Delay_signals: if (gLoop_Delay /= 0) generate
begin
	Generate_Loop_Delay: for m in 0 to (gLoop_Delay -1) generate
	begin
		assignDelay: process(i_Q62_5)
		begin
			if (i_Q62_5'event and i_Q62_5 = '1') THEN
				Loop_CharIsK(m + 1) <= Loop_CharIsK(m);
				Loop_Data(m + 1) <= Loop_Data(m);
			end if;
		end process assignDelay;
	end generate Generate_Loop_Delay;

	Delayed_CharIsK <= Loop_CharIsK(gLoop_Delay);
	Delayed_Data <= Loop_Data(gLoop_Delay);
end generate Create_Loop_Delay_signals;

No_Loop_Delay: if (gLoop_Delay = 0) generate
begin
	Delayed_CharIsK <= Loop_CharIsK(0);
	Delayed_Data <= Loop_Data(0);
end generate No_Loop_Delay;

Loop_CharIsK(0) <= fwTxCharIsK;
Loop_Data(0) <= fwTxData;

uWrap_Mode: process(i_Q62_5)
begin
	if (i_Q62_5'event and i_Q62_5 = '1') then
		if (i_AutoCloseEN = '1' and ((i_GinRing = '0' and i_fPhyLinkDown = '1') or (i_GinRing = '1' and i_fPhyLinkDown = '1' and i_bPhyLinkDown = '1'))) then
			bwRxCharIsK_Int <= Delayed_CharIsK;
			bwRxData_Int <= Delayed_Data;
			GinRing_Int <= '1';
		else
			bwRxCharIsK_Int <= bwRxCharIsK;
			bwRxData_Int <= bwRxData;
			GinRing_Int <= i_GinRing;
		end if;
	end if;
end process uWrap_Mode;

--------------------------------------------------------------------------------
--	Main Ethernet, IP, UDP Sequencer
--------------------------------------------------------------------------------
	o_EthRun	<= EthError or GinError;
	o_GinRun	<= bwGinRun;

	uWrap_RxEthSeq: entity gin_link.GIN_RxEthSeq
	GENERIC MAP (
		i_MyMac		 	=> MyMac
	)
	PORT MAP(
		i_Q62_5			=> i_Q62_5			,
		i_RxCharIsK 	=> bwRxCharIsK_Int	,
		i_RxData 		=> bwRxData_Int 	,
		i_fwNbw			=> GinRing_Int		,
		o_EthCRC		=> EthCRC			,
		o_EthError 		=> EthError			,
		o_EthRun 		=> bwEthRun			,
		o_GinRun		=> bwGinRun			,
		o_sUdpCsum		=> sUdpCsum
	);

--------------------------------------------------------------------------------
--	Gin Rx Sequencer
--------------------------------------------------------------------------------
	uWrap_RxSeq: entity gin_master.gm_rxseq
	generic map (
		g_Tunnel => g_Tunnel
	)
	port MAP(
		i_Q125			=> i_Q125			,
		i_Q62_5			=> i_Q62_5			,
		i_MEM_RdData	=> RxMEM_RdData		,
		i_EthCRC		=> EthCRC			,
		o_MEM_WrData	=> RxMEM_WrData		,
		o_MEM_Adr		=> RxMEM_Adr		,
		o_MEM_WR		=> RxMEM_WR			,
		o_RxIRQs		=> RxIRQs			,
		o_GinError		=> GinError			,
		i_TxSlot_0		=> TxSlot_0			,
		i_EthRun		=> bwEthRun			,
		i_GinRun		=> bwGinRun			,
		i_sUdpCsum		=> sUdpCsum			,
		i_EthError		=> EthError			,
		i_RxCharIsK		=> bwRxCharIsK_Int	,
		i_RxData		=> bwRxData_Int		,
		o_ExtDv			=> o_ExtRxDv		,
		o_ExtData		=> o_ExtRxData
	);

--------------------------------------------------------------------------------
--	Dualport-RAMs
--------------------------------------------------------------------------------
	-- Rx-Dualport Ram , 2kx32 = 8kByte ----------------------------------------
	RxBRAM_WEN_B <= RxMEM_WR&RxMEM_WR&RxMEM_WR&RxMEM_WR;
	RxBRAM_EN_B  <= '1';

	-- Tx-Dualport Ram , 2kx32 = 8kByte ----------------------------------------
	TxBRAM_Addr_B  <= TxMEM_Adr after 105 ps;
	TxBRAM_WEN_B   <= TxMEM_WR&TxMEM_WR&TxMEM_WR&TxMEM_WR after 105 ps;
	TxBRAM_WrDat_B <= TxMEM_WrData after 105 ps;
	TxMEM_RdData   <= TxBRAM_RdDat_B after 105 ps;

	TxBRAM_EN_B  <= '1';

	dpr64:if (g64_n32BitRam = 1) generate begin

		uWarp_TxBRAM: entity gin_link.Gin_BRAM_8kByte_A64_B32
		generic map (
			g_GL_Rev => g_GL_Rev,
			g_OUTREG_A => g_OUTREG_A
		)
		port MAP(
			i_BRAM_Clk_A  	=> i_BRAM_Clk  				,
			i_BRAM_EN_A		=> TxBRAM_EN_A				,
			i_BRAM_WEN_A  	=> i_BRAM_WEN  				,
			i_BRAM_Addr_A 	=> i_BRAM_Addr(9 downto 0)	,
			i_BRAM_Dout_A 	=> PPC_WrData 				,
			o_BRAM_Din_A	=> oTxBRAM_Din				,

			i_BRAM_Clk_B  	=> i_Q125					,
			i_BRAM_EN_B		=> TxBRAM_EN_B				,
			i_BRAM_WEN_B	=> TxBRAM_WEN_B				,
			i_BRAM_Addr_B 	=> TxBRAM_Addr_B 			,
			i_BRAM_Dout_B 	=> TxBRAM_WrDat_B 			,
			o_BRAM_Din_B  	=> TxBRAM_RdDat_B
		);

		uWarp_RxBRAM: entity gin_link.Gin_BRAM_8kByte_A64_B32
		generic map (
			g_OUTREG_A => g_OUTREG_A
		)
		port MAP(
			i_BRAM_Clk_A  	=> i_BRAM_Clk  				,
			i_BRAM_EN_A		=> RxBRAM_EN_A				,
			i_BRAM_WEN_A  	=> i_BRAM_WEN  				,
			i_BRAM_Addr_A 	=> i_BRAM_Addr(9 downto 0)	,
			i_BRAM_Dout_A 	=> PPC_WrData 				,
			o_BRAM_Din_A  	=> oRxBRAM_Din 				,

			i_BRAM_Clk_B  	=> i_Q62_5					,
			i_BRAM_EN_B		=> RxBRAM_EN_B				,
			i_BRAM_WEN_B	=> RxBRAM_WEN_B				,
			i_BRAM_Addr_B 	=> RxMEM_Adr				,
			i_BRAM_Dout_B	=> RxMEM_WrData				,
			o_BRAM_Din_B	=> RxMEM_RdData
		);
	end generate dpr64;

	dpr32:if (g64_n32BitRam = 0) generate begin

		uWarp_TxBRAM: entity gin_link.Gin_BRAM_8kByte_A32_B32
		generic map (
			g_GL_Rev => g_GL_Rev,
			g_OUTREG_A => g_OUTREG_A
		)
		port MAP(
			i_BRAM_Clk_A  	=> i_BRAM_Clk  				,
			i_BRAM_EN_A		=> TxBRAM_EN_A				,
			i_BRAM_WEN_A  	=> i_BRAM_WEN  				,
			i_BRAM_Addr_A 	=> i_BRAM_Addr(10 downto 0)	,
			i_BRAM_Dout_A 	=> PPC_WrData 				,
			o_BRAM_Din_A	=> oTxBRAM_Din				,

			i_BRAM_Clk_B  	=> i_Q125					,
			i_BRAM_EN_B		=> TxBRAM_EN_B				,
			i_BRAM_WEN_B	=> TxBRAM_WEN_B				,
			i_BRAM_Addr_B 	=> TxBRAM_Addr_B 			,
			i_BRAM_Dout_B 	=> TxBRAM_WrDat_B 			,
			o_BRAM_Din_B  	=> TxBRAM_RdDat_B
		);

		uWarp_RxBRAM: entity gin_link.Gin_BRAM_8kByte_A32_B32
		generic map (
			g_OUTREG_A => g_OUTREG_A
		)
		port MAP(
			i_BRAM_Clk_A  	=> i_BRAM_Clk  				,
			i_BRAM_EN_A		=> RxBRAM_EN_A				,
			i_BRAM_WEN_A  	=> i_BRAM_WEN  				,
			i_BRAM_Addr_A 	=> i_BRAM_Addr(10 downto 0)	,
			i_BRAM_Dout_A 	=> PPC_WrData 				,
			o_BRAM_Din_A  	=> oRxBRAM_Din 				,

			i_BRAM_Clk_B  	=> i_Q62_5					,
			i_BRAM_EN_B		=> RxBRAM_EN_B				,
			i_BRAM_WEN_B	=> RxBRAM_WEN_B				,
			i_BRAM_Addr_B 	=> RxMEM_Adr				,
			i_BRAM_Dout_B	=> RxMEM_WrData				,
			o_BRAM_Din_B	=> RxMEM_RdData
		);
	end generate dpr32;

--------------------------------------------------------------------------------
end impl;
