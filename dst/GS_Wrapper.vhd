---------------------------------------------------------------------------
--
--  GIN-Wrapper
--
---------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- wraps all GinSubModules to the main GinModule
--
---------------------------------------------------------------------------
--	Revisions
---------------------------------------------------------------------------
--	26.01.2011-FB	Generic gIs_C96Slave hinzu gefügt
--	18.05.2011-le : - support for 32bit ram (g64_n32BitRam=1)
--					- add revision for passive master (g_C96Rev)
--					- change to bram library
--	28.12.2012-FB	alter version 1947 wieder hergestellt, ganz ohne TreePort Mist
--	07.01.2013-le	- change MEM_Adr to 16 bit
--	04.10.2013-le	adjust ICU BRAM switch
--	16.10.2013-le	temporary remove icu (do not work with gin-ax4 (ppc))
--	05.11.2013-le	add icu to 0xC000. 0x4000 is used by gins
--	28.11.2013-le	remove ICU when gIs_C96Slave=1 to saving logic and get better timing
--	06.09.2016-le	support ginlink diagnostic
--	13.04.2017-le	support for cop-pas lex
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	25.04.2018-le	- add ram init for GinOpt 0x1c4 = 0x00000001 when g_Tunnel=1
--	25.06.2019-le	- add ram init for cop-pas (on cop-mas2..)
--	10.02.2021-vz	- sensitivity list completed to prevent warnings
--
--------------------------------------------------------------------------------
--$Rev:: 5783                                                                  $
--$Author:: Zuellig                                                            $
--$Date:: 2021-02-10 07:52:00 +0100 (Mi., 10 Feb 2021)                         $
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

--------------------------------------------------------------------------------
entity GS_Wrap is
	generic (
		-- 1=64Bit / 0=32Bit DP-RAM
		g64_n32BitRam 	: integer range 0 to 1 := 1;		-- default is 64Bit RAM
--not implemented (ram)		g_OUTREG_A		: in integer range 0 to 1 := 0;
		-- normal Slaves have   0x0400 Tx,Rx0,Rx1 BufferSize   0x400,0x800,0xC00
		-- C96_passive_Slave	0x0200 Tx,Rx0,Rx1 BufferSize   0xA00,0xC00,0xE00
		gIs_C96Slave 	: integer range 0 to 1 := 0;		-- default is normal GinSlave
		g_C96Rev		: std_logic_vector(15 downto 0) := (others => L);
		g_LEX			: integer range 0 to 1 := 0;
		g_COPIMP		: integer range 0 to 1 := 0;
		g_Tunnel	    : in  natural range 0 to 1 := 0
	);
	port (
		i_Q62_5			: in  std_logic;
		i_Q125			: in  std_logic;

		i_xChanger		: in  std_logic;

		-- GinFrame flag word (Blink-Bit)
		o_GF_Flags		: out std_logic_vector(15 downto 0);
		-- Page-Data access start (short puls)
		o_PgTlgSyn		: out std_logic_vector( 7 downto 0);
		-- Page-Data received and CRC-ok (short pulse)
		o_PgIRQs		: out std_logic_vector( 7 downto 0);
		-- Page-Safety word Bit-0 used as watchdog toggle-bit
		o_PgWdogs		: out std_logic_vector( 7 downto 0);
		-- flags for the slave
		o_SlvFlags		: out std_logic_vector(31 downto 0);

		o_IRQ			: out std_logic;

		o_fwGMII_TxDat	: out std_logic_vector(7 downto 0);
		o_fwGMII_TxDv	: out std_logic;
		o_fwGMII_TxErr	: out std_logic;
		i_fwGMII_RxDat	: in  std_logic_vector(7 downto 0);
		i_fwGMII_RxDv	: in  std_logic;
		i_fwGMII_RxErr	: in  std_logic;

		o_bwGMII_TxDat	: out std_logic_vector(7 downto 0);
		o_bwGMII_TxDv	: out std_logic;
		o_bwGMII_TxErr	: out std_logic;
		i_bwGMII_RxDat	: in  std_logic_vector(7 downto 0);
		i_bwGMII_RxDv	: in  std_logic;
		i_bwGMII_RxErr	: in  std_logic;
		o_fw_error		: out std_logic;
		o_bw_error		: out std_logic;
		o_GinError		: out std_logic;
		
		o_EthRun 		: out std_logic;
		o_GinRun 		: out std_logic;

		o_fwGinRun 		: out std_logic;
		o_bwGinRun 		: out std_logic;
		
		i_Mac2Tun_D		: in  std_logic_vector(15 downto 0) := (others => L);
		i_Mac2Tun_Req	: in std_logic := L;
		o_Mac2Tun_En	: out std_logic;
		o_Mac2Tun_Req_ack: out std_logic;
		o_Tun2Mac_D		: out std_logic_vector(15 downto 0);
		o_Tun2Mac_Dv	: out std_logic;
		o_dbg			: out std_logic_vector(7 downto 0);

		i_BRAM_Clk 		: in  std_logic;
		i_BRAM_EN 		: in  std_logic;
		i_BRAM_Addr 	: in  std_logic_vector(15 downto 0);
		i_BRAM_WEN 		: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_BRAM_Dout 	: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_BRAM_Din		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		
		i_linkState0	: in  std_logic;
		i_linkState1	: in  std_logic
	);

end GS_Wrap;

--------------------------------------------------------------------------------
architecture impl of GS_Wrap is
--------------------------------------------------------------------------------

	constant DF_GS_REV : std_logic_vector(15 downto 0) := x"0104";
	-- Typ
	-- default:	0x0000
	-- C96:		0x0100
	-- LEX:		0x0300
	-- IMP:		0x0400
	function get_gs_typ return std_logic_vector is
	begin
		if ((gIs_C96Slave = 0) and (g_LEX = 0) and (g_COPIMP=0)) then
			return x"0000";
		elsif ((gIs_C96Slave = 1) and (g_LEX = 0) and (g_COPIMP=0)) then
			return x"0100";
		elsif ((gIs_C96Slave = 1) and (g_LEX = 1) and (g_COPIMP=0)) then
			return x"0300";
		elsif ((gIs_C96Slave = 1) and (g_LEX = 0) and (g_COPIMP=1)) then
			return x"0400";
		else
			assert 1<0
			report "unsupported gs_type" severity error;
			return x"EEEE";
		end if;
	end get_gs_typ;

	constant DF_GS_TYPREV : std_logic_vector(31 downto 0) := get_gs_typ & DF_GS_REV;

--------------------------------------------------------------------------------
--	My MAC Adress
--------------------------------------------------------------------------------
	constant MyMac : std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_00";

--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------
	constant DF_C96_TIM : tSLV_Nx32(0 to 1) := (x"00000000",x"90000C35");
	constant DF_C96_REV : tSLV_Nx32(0 to 1) := (x"00000000",x"0000" & g_C96Rev);
	constant DF_C96_EEP : tSLV_Nx32(0 to 1) := (x"00000000",x"11090080");
	constant DF_GIN_OPT : tSLV_Nx32(0 to 1) := (x"00000000",x"00000001");
	-- !!!! raminit is not in all FPGAs suportet !!!!
	constant BRAM_Init : tSLV_Nx32(0 to 1023) := (
		448/4 => DF_GS_TYPREV,				-- 0x1C0	GAL_Revision
		452/4 => DF_GIN_OPT(g_Tunnel),		-- 0x1c4	GinOpt
		768/4 => DF_C96_TIM(gIs_C96Slave),	-- 0x300	start 8kHz 40ns Timer, dis OverRun
		776/4 => DF_C96_REV(gIs_C96Slave),	-- 0x308	Passive Master revision
		792/4 => x"00000000",				-- 0x318	128Bytes to Addr 000
		796/4 => DF_C96_EEP(gIs_C96Slave),	-- 0x31C	read C96-EEP
		others => (others => '0')
	);
	
	function get_raminit_file(input : integer) return string is
	begin
		if ((gIs_C96Slave = 0) and (g_LEX = 0) and (g64_n32BitRam=0) and (g_Tunnel=0) and (g_COPIMP=0)) then
			return "..\gin_slave\GS32.mif";
		elsif ((gIs_C96Slave = 0) and (g_LEX = 0) and (g64_n32BitRam=0) and (g_Tunnel=1) and (g_COPIMP=0)) then
			return "..\gin_slave\GS32_Tun.mif";
		elsif ((gIs_C96Slave = 1) and (g_LEX = 0) and (g64_n32BitRam=0) and (g_Tunnel=0) and (g_COPIMP=0)) then
			return "..\gin_slave\CP32.mif";
		else
			assert 1<0
			report "mif file not yet created" severity error;
			return "0000";
		end if;
	end get_raminit_file;
	
	constant INIFile : string := get_raminit_file(0);

	signal BRAM_Adr32_A  : std_logic_vector( 9 downto 0);
	signal BRAM_Adr64_A  : std_logic_vector( 8 downto 0);

	signal BRAM_EN_B   : std_logic;
	signal BRAM_WEN_B  : std_logic_vector( 3 downto 0);
	signal BRAM_Addr_B : std_logic_vector(10 downto 0);
	signal BRAM_Dout_B : std_logic_vector(31 downto 0);

--------------------------------------------------------------------------------
	signal EthCRC			: std_logic_vector(31 downto 0);
	signal CrcRun 			: std_logic;
	signal CrcClr 			: std_logic;
	signal EthError 		: std_logic;
	signal EthRun 			: std_logic;
	signal sUdpCsum 		: std_logic;

	signal fwGinRun 		: std_logic;
	signal bwGinRun 		: std_logic;

--------------------------------------------------------------------------------
    signal MEM_RdData 		: std_logic_vector(31 downto 0);
    signal MEM_WrData 		: std_logic_vector(31 downto 0);
    signal MEM_Adr	   		: std_logic_vector(15 downto 0);
    signal MEM_WR			: std_logic;
    signal WrBufTgl			: std_logic_vector( 7 downto 0);		-- wr-buffer toggle
    signal WrBufTgl_ppc_dom	: std_logic_vector( 7 downto 0);		-- wr-buffer toggle on ppc clk domain
    Signal PgIRQs	    	: std_logic_vector( 7 downto 0);
    Signal PgWdogs	    	: std_logic_vector( 7 downto 0);
    Signal PgTlgSyn	    	: std_logic_vector( 7 downto 0);
    Signal GF_Flags         : std_logic_vector(15 downto 0);
    signal GinError			: std_logic;
--------------------------------------------------------------------------------
 	signal fwRxCharIsk 		: std_logic_vector( 1 downto 0);
	signal fwRxData 		: std_logic_vector(15 downto 0);
	signal fwRxCharIsk_1	: std_logic_vector( 1 downto 0);
	signal fwRxData_1 		: std_logic_vector(15 downto 0);
	signal fwTxCharIsk 		: std_logic_vector( 1 downto 0);
	signal fwTxData 		: std_logic_vector(15 downto 0);

	signal fwxchTxCharIsk 	: std_logic_vector( 1 downto 0);
	signal fwxchTxData 		: std_logic_vector(15 downto 0);

--------------------------------------------------------------------------------
	signal bwRxCharIsk 		: std_logic_vector( 1 downto 0);
	signal bwRxData 		: std_logic_vector(15 downto 0);
	signal bwTxCharIsk 		: std_logic_vector( 1 downto 0);
	signal bwTxData 		: std_logic_vector(15 downto 0);

--------------------------------------------------------------------------------
	signal err 		: std_logic;

--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	Signal ICU_RdData		: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	Signal ICU_IRQs_Inp		: std_logic_vector(31 downto 0) := (others => '0');
	Signal ICU_EN			: std_logic;

	signal ByteAdr		: std_logic_vector(15 downto 0);
	signal Rx_BRAM_EN	: std_logic;
	signal RxPPCRdData	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);

	type t_out_select is (rxram,icu);
	signal out_select_p			: t_out_select := rxram;
	signal out_select_r			: t_out_select := rxram;
	signal out_select			: t_out_select := rxram;
	
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
	
--------------------------------------------------------------------------------
begin

--------------------------------------------------------------------------------
--	convert 8-Bit GMII to 16-Bit MGT Data
--------------------------------------------------------------------------------
	uWrap_fwGMII_MGT: entity gin_link.GL_GMII_MGT
	PORT MAP(
		i_Q125			=> i_Q125		 	,
		i_Q62_5			=> i_Q62_5			,
		i_GMII_RxDat	=> i_fwGMII_RxDat   ,
		i_GMII_RxDv		=> i_fwGMII_RxDv	,
		i_GMII_RxErr	=> i_fwGMII_RxErr   ,
		o_MGT_RxData 	=> fwRxData_1       ,
		o_MGT_RxCharIsk	=> fwRxCharIsk_1
	);

	uWrap_bwGMII_MGT: entity gin_link.GL_GMII_MGT
	PORT MAP(
		i_Q125			=> i_Q125		 	,
		i_Q62_5			=> i_Q62_5			,
		i_GMII_RxDat	=> i_bwGMII_RxDat   ,
		i_GMII_RxDv		=> i_bwGMII_RxDv	,
		i_GMII_RxErr	=> i_bwGMII_RxErr   ,
		o_MGT_RxData 	=> bwRxData         ,
		o_MGT_RxCharIsk	=> bwRxCharIsk
	);

--------------------------------------------------------------------------------
--	convert 16-Bit MGT  to 8-Bit GMII Data
--------------------------------------------------------------------------------
	uWrap_fwMGT_GMII: entity gin_link.GL_MGT_GMII
	PORT MAP(
--		i_Q62_5			=> i_Q62_5			,
        i_MGT_TxCharIsk	=> fwTxCharIsk	    ,
        i_MGT_TxData	=> fwTxData	        ,
        i_Q125			=> i_Q125			,
        o_GMII_TxDat	=> o_fwGMII_TxDat	,
        o_GMII_TxDv		=> o_fwGMII_TxDv	,
        o_GMII_TxErr	=> o_fwGMII_TxErr
    );

	uWrap_bwMGT_GMII: entity gin_link.GL_MGT_GMII
	PORT MAP(
--		i_Q62_5			=> i_Q62_5			,
        i_MGT_TxCharIsk	=> bwTxCharIsk	    ,
        i_MGT_TxData	=> bwTxData	        ,
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

withicu: if gIs_C96Slave=0 generate
begin
	ICU_IRQs_Inp <= x"000000" & PgIRQs;

	uWrap_ICU: entity gin_link.Gin_ICU
	generic map (
--		g_OUTREG_A => g_OUTREG_A,
		g64_n32BitRam => g64_n32BitRam
	)
	port MAP(
		i_ICU_Clk	=> i_BRAM_Clk	,	-- liegt im BRAM AdrRaum
		i_ICU_EN	=> ICU_EN		,
		i_WR 		=> i_BRAM_WEN	,
		i_addr		=> ByteAdr(2)	,	-- for 32Bit Read
		i_addr_tim	=> ByteAdr(3)	,	-- read IRQ-Timer
		i_Din		=> i_BRAM_Dout	,
		o_Dout		=> ICU_RdData	,
		i_IRQs		=> ICU_IRQs_Inp	,
		o_IRQ		=> o_IRQ
	);
end generate;

noicu: if gIs_C96Slave=1 generate
begin
	o_IRQ <= L;
end generate;
--------------------------------------------------------------------------------
--	Dualport Block-Ram
--------------------------------------------------------------------------------
--	side A	PowerPC
--	side B	GinLink

-- normal Slaves have   0x0400 Tx,Rx0,Rx1 BufferSize   0x400,0x800,0xC00
-- C96_Slaves	 have	0x0200 Tx,Rx0,Rx1 BufferSize   0xA00,0xC00,0xE00
--------------------------------------------------------------------------------

	process (i_BRAM_Clk)
	begin
		if rising_edge(i_BRAM_Clk) then
			WrBufTgl_ppc_dom <= WrBufTgl;
		end if;
	end process;

	process (ByteAdr,i_BRAM_EN,RxPPCRdData,ICU_RdData,i_bram_addr,out_select) begin
		if g64_n32BitRam=1 then
			ByteAdr <= i_BRAM_Addr(12 downto 0) & "000";
		else
			ByteAdr <= i_BRAM_Addr(13 downto 0) & "00";
		end if;

		Rx_BRAM_EN	<= L;
		ICU_EN		<= L;

		if (gIs_C96Slave=1 or ByteAdr < x"C000") then
			Rx_BRAM_EN <= i_BRAM_EN;
		--	o_BRAM_Din <= RxPPCRdData;
		else
			ICU_EN		<= i_BRAM_EN;
		--	o_BRAM_Din	<= ICU_RdData;
		end if;

		case out_select is
		when icu => o_BRAM_Din	<= ICU_RdData;
		when rxram =>o_BRAM_Din <= RxPPCRdData;
		end case;

	end process;

--	outreg_en: if g_OUTREG_A=1 generate
--		out_select <= out_select_p;
--	end generate outreg_en;

--	outreg_dis: if g_OUTREG_A=0 generate
		out_select <= out_select_r;
--	end generate outreg_dis;

	process (i_BRAM_Clk) begin
		if rising_edge(i_BRAM_Clk) then
			if Rx_BRAM_EN=H then
				out_select_r <= rxram;
			elsif ICU_EN=H then
				out_select_r <= icu;
			end if;
			out_select_p <= out_select_r;
		end if;
	end process;

--------------------------------------------------------------------------------
--	32-Bit DP_RAM
--------------------------------------------------------------------------------
--	wird verwendet für:
--		C96-Passive-Slave
--------------------------------------------------------------------------------
BR32 : if (g64_n32BitRam = 0) generate
begin
--	Write-Buffer toggle
	process (i_BRAM_Addr,WrBufTgl_ppc_dom) begin
		BRAM_Adr32_A <= i_BRAM_Addr(9 downto 0);
		if (gIs_C96Slave = 0) then
			if (i_BRAM_Addr(9) = H) then				-- Write-Buffer access
				BRAM_Adr32_A(8) <= not WrBufTgl_ppc_dom(CONV_INTEGER(i_BRAM_Addr(12 downto 10)));
			else
				BRAM_Adr32_A(8) <= i_BRAM_Addr(8);
			end if;
		else
			if (i_BRAM_Addr(9 downto 8) = "11") then				-- Write-Buffer access
				BRAM_Adr32_A(7) <= not WrBufTgl_ppc_dom(CONV_INTEGER(i_BRAM_Addr(12 downto 10)));
			else
				BRAM_Adr32_A(7) <= i_BRAM_Addr(7);
			end if;
		end if;
	end process;

	BRAM_EN_B <= '1';
	BRAM_WEN_B <= MEM_WR&MEM_WR&MEM_WR&MEM_WR;

	uWarp_BRAM : entity BRAM.BRAM_4kByte_A32_B32
	generic map (
		BRAM_Init		=> BRAM_Init,
		g_INIT_FILE		=> INIFile
	)
	PORT MAP(
		i_BRAM_Clk_A	=> i_BRAM_Clk	,
		i_BRAM_EN_A		=> Rx_BRAM_EN	,
		i_BRAM_WEN_A	=> i_BRAM_WEN	,
		i_BRAM_Addr_A	=> BRAM_Adr32_A	,
		i_BRAM_Dout_A	=> i_BRAM_Dout	,
		o_BRAM_Din_A	=> RxPPCRdData	,

		i_BRAM_Clk_B	=> i_Q62_5	,
		i_BRAM_EN_B		=> BRAM_EN_B	,
		i_BRAM_WEN_B	=> BRAM_WEN_B	,
		i_BRAM_Addr_B	=> MEM_Adr( 9 downto 0)		,
		i_BRAM_Dout_B	=> MEM_WrData	,
		o_BRAM_Din_B	=> MEM_RdData
	);

end generate BR32;

--------------------------------------------------------------------------------
--	64-Bit DP_RAM
--------------------------------------------------------------------------------
--	wird verwendet für:
--		Gin-Slaves mit PPC-Card	(Gin-SAC,MAX,AX,IMP)
--------------------------------------------------------------------------------
BR64 : if (g64_n32BitRam = 1) generate
begin
--	Write-Buffer toggle
	process (i_BRAM_Addr,WrBufTgl_ppc_dom) begin
		BRAM_Adr64_A <= i_BRAM_Addr(8 downto 0);

		if (gIs_C96Slave = 0) then
			if (i_BRAM_Addr(8) = H) then				-- Write-Buffer access
				BRAM_Adr64_A(7) <= not WrBufTgl_ppc_dom(CONV_INTEGER(i_BRAM_Addr(11 downto 9)));
	    	else
				BRAM_Adr64_A(7) <= i_BRAM_Addr(7);
	    	end if;
	    else
			if (i_BRAM_Addr(8 downto 7) = "11") then				-- Write-Buffer access
				BRAM_Adr64_A(6) <= not WrBufTgl_ppc_dom(CONV_INTEGER(i_BRAM_Addr(11 downto 9)));
	    	else
				BRAM_Adr64_A(6) <= i_BRAM_Addr(6);
	    	end if;
	    end if;
   	end process;

    BRAM_EN_B     <= '1';
    BRAM_WEN_B    <= MEM_WR&MEM_WR&MEM_WR&MEM_WR;

	uWarp_BRAM : entity BRAM.BRAM_4kByte_A64_B32
	generic map (
		BRAM_Init		=> BRAM_Init,
		g_INIT_FILE		=> INIFile
	)
	PORT MAP(
		i_BRAM_Clk_A  	=> i_BRAM_Clk  	,
		i_BRAM_EN_A   	=> Rx_BRAM_EN	,
		i_BRAM_WEN_A  	=> i_BRAM_WEN  	,
		i_BRAM_Addr_A 	=> BRAM_Adr64_A ,
		i_BRAM_Dout_A 	=> i_BRAM_Dout 	,
		o_BRAM_Din_A  	=> RxPPCRdData  	,

		i_BRAM_Clk_B  	=> i_Q62_5  	,
		i_BRAM_EN_B   	=> BRAM_EN_B   	,
		i_BRAM_WEN_B  	=> BRAM_WEN_B  	,
		i_BRAM_Addr_B 	=> MEM_Adr( 9 downto 0) 	 	,
		i_BRAM_Dout_B 	=> MEM_WrData  	,
		o_BRAM_Din_B  	=> MEM_RdData
	);

end generate BR64;

--------------------------------------------------------------------------------
--	GinFrame Sequencer
--------------------------------------------------------------------------------
	uWrap_RxSeq: entity gin_slave.GS_RxSeq
	generic map (
		-- normal Slaves have   0x0400 Tx,Rx0,Rx1 BufferSize   0x400,0x800,0xC00
		-- C96_passive_Slave	0x0200 Tx,Rx0,Rx1 BufferSize   0xA00,0xC00,0xE00
		Is_C96Slave 	=> gIs_C96Slave,
		g_Tunnel		=> g_Tunnel
	)
	PORT MAP(
		i_Q62_5 		=> i_Q62_5		,
		i_EthRun 		=> EthRun		,
		i_GinRun 		=> fwGinRun		,
		i_RxCharIsk 	=> fwRxCharIsk	,
		i_RxData 		=> fwRxData		,
		i_sUdpCsum		=> sUdpCsum		,
		i_EthCRC		=> EthCRC		,
		i_CrcRun 		=> CrcRun		,
		i_CrcClr 		=> CrcClr		,
		i_EthError		=> EthError		,
		o_GinError		=> GinError		,
		o_TxCharIsk		=> fwTxCharIsk	,
		o_TxData 		=> fwTxData		,
		i_MEM_RdData	=> MEM_RdData	,
		o_MEM_WrData	=> MEM_WrData	,
		o_MEM_Adr		=> MEM_Adr		,
		o_MEM_WR		=> MEM_WR		,
		o_WrBufTgl		=> WrBufTgl		,
        o_PgIRQs		=> PgIRQs		,
        o_PgWdogs		=> o_PgWdogs	,
        o_GF_Flags		=> o_GF_Flags	,
		o_SlvFlags		=> o_SlvFlags	,
		o_PgTlgSyn		=> o_PgTlgSyn	,
		i_error_ethfw	=> error_ethfw	,
		i_error_ethbw	=> error_ethbw	,
		i_EthError_bw	=> EthError_bw	,
		i_linkdown_fw	=> linkdown_fw	,
		i_linkdown_bw	=> linkdown_bw	,
		i_xChangerErr	=> xChangerErr	,
		o_fw_error		=> o_fw_error	,
		o_bw_error		=> o_bw_error	,
		o_Tun2Mac_D		=> o_Tun2Mac_D	,
		o_Tun2Mac_Dv	=> o_Tun2Mac_Dv	,
		i_Mac2Tun_D		=> i_Mac2Tun_D	,
		o_Mac2Tun_En	=> o_Mac2Tun_En,
		i_Mac2Tun_Req	=> i_Mac2Tun_Req,
		o_Mac2Tun_Req_ack => o_Mac2Tun_Req_ack,
		o_dbg			=> o_dbg
	);
	o_GinError <= GinError;
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
		i_Q62_5 	=> i_Q62_5		,
		i_RxCharIsk => fwRxCharIsk	,
		i_RxData 	=> fwRxData		,
		o_EthCRC 	=> EthCRC		,
		o_CrcRun 	=> CrcRun		,
		o_CrcClr 	=> CrcClr		,
		o_CrcError	=> error_ethfw	,
		o_EthError	=> EthError		,
		o_EthRun 	=> EthRun		,
		o_GinRun 	=> fwGinRun		,
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
		i_Q62_5 	=> i_Q62_5		,
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
	
no_prex : if (g_LEX = 0) generate
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
		i_RxCharIsk  => fwTxCharIsk 	,
		i_RxData 	 => fwTxData    	,
		o_TxData 	 => fwxchTxData   	,
		o_TxCharIsk  => fwxchTxCharIsk
	);
	
	fwRxData <= fwRxData_1;
	fwRxCharIsk <= fwRxCharIsk_1;
end generate no_prex;
	
prex : if (g_LEX = 1) generate
	
	bwTxData	<= bwRxData;
	bwTxCharIsk <= bwRxCharIsk;
	
	uWrap_preXch:	entity gin_slave.GS_Xchanger
	GENERIC MAP (
		i_MyMac		 => MyMac,
		g_preX => 1
	)
	PORT MAP(
		i_Q62_5		=> i_Q62_5			,
		i_RxCharIsk	=> fwRxCharIsk_1	,
		i_RxData	=> fwRxData_1		,
		o_TxData	=> fwRxData			,
		o_TxCharIsk	=> fwRxCharIsk
	);
end generate prex;

--------------------------------------------------------------------------------
end;
