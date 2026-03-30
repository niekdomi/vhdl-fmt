---------------------------------------------------------------------------
--
--  GIN-Frame Sequencer
--
---------------------------------------------------------------------------
--
--  project		: GIN_LINK
--  programmer  : F:Baschung, INDEL AG
--  date		: 21.05.2004
--  version		: 1.00
--  language	: VHDL
--  system		: Project Navigator
--
--  purpose
--		- Decode GIN-Frames
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00   21.05.2004-FB   erste Version
--  Rev. 1.03   10.11.2010-FB   new Cmd_TT= 3:  slave cfg_reg block access
--  18.05.2011-le : - avoid synthesis warnings:
--						remove gsf_fixlen and GSF_IRQ
--						correct sensitivity list
--	06.09.2016-le	- support ginlink diagnostic
--	09.02.2017-le	- add i_8k3p_Enable to enable/disable 3port and 8k feature (rev>=0x210).
--	24.02.2017-le	- try to improve timing
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	13.02.2018-le	- read slave addr when page>=8
--					- do not cont gsf counter and do not store safetyword when page>=8
--	10.02.2021-vz	- sensitivity list completed to prevent warnings
--
--------------------------------------------------------------------------------
--$Rev:: 5783                   $
--$Author:: Zuellig                  $
--$Date:: 2021-02-10 07:52:00 +0100 (Mi., 10 Feb 2021)        $
--------------------------------------------------------------------------------


---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY gin_link;
--USE gin_link.ALL;
USE gin_link.PCK_CRC32_D16.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity GS_RxSeq is
	generic (
		-- normal Slaves have   0x0400 Tx,Rx0,Rx1 BufferSize   0x400,0x800,0xC00
		-- C96_passive_Slave	0x0200 Tx,Rx0,Rx1 BufferSize   0xA00,0xC00,0xE00
		Is_C96Slave		: integer := 0;
		-- (TwoPort: first port for PPC, second for C64-Master)
		g_8k_MEM	: integer range 0 to 1 := 0;		-- default is one Port only
		g_Tunnel	: integer range 0 to 1 := 0
	);
	port (
		i_Q62_5			: in  std_logic;
		i_RxCharIsK		: in  std_logic_vector( 1 downto 0);
		i_RxData		: in  std_logic_vector(15 downto 0);
		i_EthCRC		: in  std_logic_vector(31 downto 0);
		i_EthRun		: in  std_logic;							-- EthFrame is running
		i_GinRun		: in  std_logic;							-- GinFrame is running
		i_sUdpCsum		: in  std_logic;
		i_EthError		: in  std_logic;
		i_CrcRun		: in  std_logic;
		i_CrcClr		: in  std_logic;
		o_GinError		: out std_logic;

		i_MEM_RdData	: in  std_logic_vector(31 downto 0);
		o_MEM_WrData	: out std_logic_vector(31 downto 0);
		o_MEM_Adr		: out std_logic_vector(15 downto 0);
		o_MEM_WR		: out std_logic;
		o_WrBufTgl		: out std_logic_vector( 7 downto 0);

		o_TxCharIsK		: out std_logic_vector( 1 downto 0);
		o_TxData		: out std_logic_vector(15 downto 0);

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
		i_error_ethfw	: in  std_logic;
		i_error_ethbw	: in  std_logic;
		i_EthError_bw	: in  std_logic;
		i_linkdown_fw	: in  std_logic;
		i_linkdown_bw	: in  std_logic;
		i_xChangerErr	: in  std_logic;
		o_fw_error		: out std_logic;
		o_bw_error		: out std_logic;
		i_8k3p_Enable	: in  std_logic := conv_std_logic_vector(g_8k_MEM,1)(0);

		i_Mac2Tun_D		: in  std_logic_vector(15 downto 0);
		i_Mac2Tun_Req	: in std_logic;
		o_Mac2Tun_En	: out std_logic;
		o_Mac2Tun_Req_ack: out std_logic;
		o_Tun2Mac_D		: out std_logic_vector(15 downto 0);
		o_Tun2Mac_Dv	: out std_logic;
		o_dbg			: out std_logic_vector(7 downto 0)
	);
end;

architecture impl of GS_RxSeq is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

	type sGS_RxSeq is (
		sIdle,sWaitGinStart,
		sEth_HdCRC_H,sEth_HdCRC_L,
		sGF_StartOfFrame,sGF_HdBlink,sGF_HdLen,sGF_Sfty_H,sGF_Sfty_L,sGF_HdCRC_L,sGF_HdCRC_H,
		sGSF_StartOfFrame,sGSF_Cmd,sGSF_Adr_H,sGSF_Adr_L,sGSF_Len,sGSF_Int,sGSF_Sfty_H,sGSF_Sfty_L,sGSF_HdCRC_L,sGSF_HdCRC_H,
		sGSF_StartOfMemData,sGSF_StartOfCfgData,
		sWaitMemDat,sMemDat_H,sMemDat_L,
		sWaitCnt,
		sGSF_Sla,sGSF_DatCRC_L,sGSF_DatCRC_H,
		sErrEnd,sErrEnd1,sErrEnd2,sErrWaitEnd,
		sTx_CRC_H,sTx_CRC_L,sTx_CRC_Err,
		sTxH_Rd,sTxH_Rx_Or,sTxH_Rx_Inc,sTxH_Rx_And,
		sTxL_Rd,sTxL_Rx_Or,sTxL_Rx_Inc,sTxL_Rx_And,
		sOkEnd,sOkEnd1,sOkEnd2,sOkEnd3,sOkWaitEnd
	);

	signal GS_RxSeq: sGS_RxSeq := sIdle;						-- main sequencer
	signal GS_TxSeq: sGS_RxSeq := sIdle;						-- t-1 old state

	signal GF_Flags_uc	: std_logic_vector(15 downto 0) := x"0000";		-- GinFrame header flags (unchecked)
	signal GF_Flags		: std_logic_vector(15 downto 0) := x"0000";		-- GinFrame header flags
--  signal GSF_IRQ		: std_logic_vector(15 downto 0) := x"0000";		-- SubFrame header Irqs

	signal NrOfGSF		: std_logic_vector(15 downto 0) := x"0000";		-- Nr of GinSubFrames

	signal GSF_Cmd		: std_logic_vector(15 downto 0) := x"0000";		-- command
	signal GSF_Adr		: std_logic_vector(31 downto 0) := x"00000000"; -- slave/address/CfgReg
	signal GSF_Len		: std_logic_vector(11 downto 0) := x"000";		-- GinSubFram lenght
--  signal GSF_FixLen   : std_logic_vector( 2 downto 0) :=  "000";		-- Fix-Len access

	signal MEM_Adr		: std_logic_vector(15 downto 0) := x"0000";		-- act dp-ram adr
	signal MEM_Adr_1	: std_logic_vector(15 downto 0) := x"0000";		-- t-1 old dp-ram adr
	signal MEM_WrData   : std_logic_vector(31 downto 0) := x"00000000"; -- data to dp-ram
	signal MEM_RdData   : std_logic_vector(31 downto 0) := x"00000000"; -- data from dp-ram
	signal MEM_RdData_P1: std_logic_vector(31 downto 0) := x"00000000"; -- data from dp-ram
	signal MEM_WrData_NULL : std_logic_vector (31 downto 0) :=  x"00000000";
	signal MEM_WrData_RXDATA : std_logic_vector (31 downto 0) :=  x"00000000";
	signal MEM_WrData_PERR : std_logic_vector (31 downto 0) :=  x"00000000";
	signal MEM_WR		: std_logic := L;								-- write

	signal WrBufTgl		: std_logic_vector( 7 downto 0) :=  "00000000"; -- wr-buffer toggle
	signal sw_RxBuf		: std_logic_vector( 7 downto 0)	:= (others => '0');
	signal TxBuf_Base	: std_logic_vector( 3 downto 0)	:= (others => '0');

	signal RxData_1		: std_logic_vector(15 downto 0) := x"0000";		-- t-1 old RxData
	signal RxCharIsK_1  : std_logic_vector( 1 downto 0) :=  "00";
	signal TxCharIsK	: std_logic_vector( 1 downto 0) :=  "00";
	signal TxData		: std_logic_vector(15 downto 0) := x"0000";		-- what we want to send
	signal AdrOfs		: std_logic_vector(31 downto 0) := x"00000000"; -- offset till my data
	signal MemAdrOfs	: std_logic_vector(31 downto 0) := x"00000000"; -- offset till my data
	signal FixOfs		: std_logic_vector(15 downto 0) := x"0000";		-- offset till my FixData
	signal MemLen		: std_logic_vector(11 downto 0) := x"000";		-- mem-len(act page)

	type sGSF_CmdSwitch is (sGSF_CmdDecNone,sGSF_CmdDecWdat,sGSF_CmdDecDat_H,sGSF_CmdDecDat_L,sGSF_CmdDecWend,sGSF_CmdDecEnd);
	signal CmdSwitch	: sGSF_CmdSwitch := sGSF_CmdDecNone;					-- command decoder result
	signal SlaveAttached: std_logic := L;								-- this slave was attached
	signal SubFrmOk		: std_logic := L;								-- SubFrame was ok
	signal RxCRC_Equ_L  : std_logic := L;								-- CheckSumm is ok
	signal RxCRC_Equ_H  : std_logic := L;								-- CheckSumm is ok
	signal RxCRC_OFF	: std_logic := L;								-- CheckSumm is x"CCCC"

	--  32-Bit to 16-Bit latches
	signal WrDatBuf31_16: std_logic_vector(15 downto 0) := x"0000";		-- latched wr-data
	signal RdDatBuf15_0 : std_logic_vector(15 downto 0) := x"0000";		-- latched rd-data

	signal dQ62_5		: std_logic := '0';								-- write
	signal PgIRQs		: std_logic_vector( 7 downto 0) := x"00";		-- IRQ to PPC
	signal PgWdogs		: std_logic_vector( 7 downto 0) := x"00";		-- IRQ to PPC
	signal WdogBit		: std_logic := '0';								-- WdogBit latch till CRC-OK
	signal PgTlgSyn		: std_logic_vector( 7 downto 0) := x"00";		-- TglSyn to latch PWM-value
	signal SynCopMas	: std_logic := '0';								-- synch CopMaster to 64kHz safety cnt
	signal SynCopMas_ok	: std_logic := '0';								-- synch CopMaster pulse

--------------------------------------------------------------------------------
--  Configuration
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  DP-Ram Memory		0X2000-Bytes = 8kByte total
--------------------------------------------------------------------------------
--  Der DP_Mem Bereich wird in 4 Blöcke aufgeteilt:
--		dw-adr						byteadr
--		000-07F CGF					0000
--		080-087 CmpAdr				0200
--		100
--		200		RD					0800			A10 = L, A9 = H
--		300
--		400		WR-0				1000			A10 = H, A9 = WrTgl
--		500
--		600		WR-1				1800
--		700
--
--  Die Pages 1..7 müssen also alle in einem Adr-Bereich von 000..1FF liegen
--  Bei RD			+200			+0800 Tx
--  Bei WR & Tgl0   +400			+1000 Rx
--  Bei WR & Tgl1   +400 + 200		+1800 Rx-buffer2
--
--  A9  = +200 wird auch für RD und WR-Tgl benötigt
--  A10 = +400 wird mit Page-1..7 Write = 1
-------------------------------------------------------------------------- Byte
	constant CfgMy_SlaveNr  : std_logic_vector(15 downto 0) := x"0060"; -- 0180
	constant CfgMy_SlvFlags	: std_logic_vector(15 downto 0) := x"0063"; -- 018C
	constant CfgGF_Flags	: std_logic_vector(15 downto 0) := x"0064"; -- 0190
	constant CfgGF_Safety   : std_logic_vector(15 downto 0) := x"0065"; -- 0194
	constant CfgGF_Err		: std_logic_vector(15 downto 0) := x"0066"; -- 0198
	constant CfgGF_Cnt		: std_logic_vector(15 downto 0) := x"0067"; -- 019C

	constant CfgGSF_AdrCmp  : std_logic_vector(15 downto 0) := x"0080"; -- 0200
--  higher-word = lenght : lower-word = BaseAdr
	constant CfgGSF_MemDef  : std_logic_vector(15 downto 0) := x"0081"; -- 0204
	constant CfgGSF_Safety  : std_logic_vector(15 downto 0) := x"0085"; -- 0214
	constant CfgGSF_Cnt		: std_logic_vector(15 downto 0) := x"0087"; -- 021C

--------------------------------------------------------------------------------
--  Gin-Command
--------------------------------------------------------------------------------
	constant cmd_Rd		:  std_logic_vector := "001";
	constant cmd_Rx_Or  :  std_logic_vector := "010";
	constant cmd_Rx_Inc :  std_logic_vector := "011";
	constant cmd_Rx_And :  std_logic_vector := "100";

	constant cmd_Wr		:  std_logic_vector := "001";
	constant cmd_Clear  :  std_logic_vector := "010";
--  constant cmd_Inc_Wr :  std_logic_vector := "011";


	ALIAS  GSF_Cmd_IrqEn:   std_logic is GSF_Cmd(15);
	ALIAS  GSF_Cmd_TT   :   std_logic_vector(2 downto 0) is GSF_Cmd(14 downto 12);
	ALIAS  GSF_Cmd_Wr   :   std_logic_vector(2 downto 0) is GSF_Cmd(10 downto  8);
	ALIAS  GSF_Cmd_Rd   :   std_logic_vector(2 downto 0) is GSF_Cmd( 6 downto  4);
	ALIAS  GSF_Cmd_Pg   :   std_logic_vector(2 downto 0) is GSF_Cmd( 2 downto  0);
	ALIAS  GSF_Cmd_Pg8  :   std_logic					 is GSF_Cmd(3);

	ALIAS  GSF_SlaveNr  :   std_logic_vector(15 downto 0) is GSF_Adr(31 downto 16);
	ALIAS  GSF_Adr_H	:   std_logic_vector(15 downto 0) is GSF_Adr(31 downto 16);
	ALIAS  GSF_Adr_L	:   std_logic_vector(15 downto 0) is GSF_Adr(15 downto  0);

--------------------------------------------------------------------------------
--  Components
--------------------------------------------------------------------------------
	signal  EthCRC_1	: std_logic_vector (31 downto 0) := x"00000000";
	signal  TxCRC32		: std_logic_vector (31 downto 0) := x"00000000";
	signal  LxCRC32		: std_logic_vector (31 downto 0) := x"00000000";
	signal  nbrTxCRC32  : std_logic_vector (31 downto 0) := x"00000000";
	signal  nbrLxCRC32  : std_logic_vector (31 downto 0) := x"00000000";

	signal  TxCrcClr	: std_logic := '0';
	signal  TxCrcRun	: std_logic := '0';
	
	signal error_gfrx : std_logic := L;
	signal error_ethfw : std_logic := L;
	signal error_ethbw : std_logic := L;
	signal linkdown_fw : std_logic := L;
	signal linkdown_bw : std_logic := L;
	signal ext_error_pending : std_logic := L;
	signal xChangerErr : std_logic := L;
	
	signal fw_error : std_logic := L;
	signal bw_error : std_logic := L;
	signal change_diag_mode : std_logic := L;
	signal SlvFlags : std_logic_vector (31 downto 0) := (others => L);
	
	signal ExtPage		: std_logic := L;
	signal ExtDv		: std_logic := L;
	signal ExtFirst		: std_logic := L;
	signal ExtFirst_1	: std_logic := L;
	signal ExtFull		: std_logic := L;
	
	signal Tun2Mac_Dv	: std_logic := L;
	signal Mac2Tun_En	: std_logic := L;
	
	signal SlaveNr		: std_logic_vector (15 downto 0) := (others => L);
--------------------------------------------------------------------------------
begin -- of architecture GS_RxSeq
--------------------------------------------------------------------------------

--  outputs --------------------------------------------------------------------

	o_MEM_WrData	<= MEM_WrData;
	  MEM_RdData	<= i_MEM_RdData after 10 ps;
	o_MEM_WR	<= MEM_WR ;
	o_WrBufTgl  <= WrBufTgl;

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			o_TxCharIsK <= TxCharIsK;
			o_TxData	<= TxData ;
		end if;
	end process;

	o_GF_Flags  <= GF_Flags ;
	o_SlvFlags	<= SlvFlags;

	-- unused MEM_Adr(15.. will be eliminated!
	o_MEM_Adr <= MEM_Adr;

pas: if (Is_C96Slave = 1) generate begin
	sw_RxBuf(0) <= H when ((i_8k3p_Enable=L)) and (Is_C96Slave = 1) else L;
	sw_RxBuf(1) <= H when ((i_8k3p_Enable=H)) else L;
end generate pas;
	
mas: if (Is_C96Slave = 0) generate begin
	sw_RxBuf(0) <= L;
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			sw_RxBuf(1) <= i_8k3p_Enable;
		end if;
	end process;
end generate mas;

tt: if (g_Tunnel/=0) generate begin 
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			Tun2Mac_Dv <= L;
			if (ExtPage=H and ExtFull=L and GSF_Cmd_Pg="000" and GSF_Cmd_Wr="001") then
				Tun2Mac_Dv <= H;
			end if;
		end if;
	end process;

	Mac2Tun_En <= H when (ExtPage=H and ExtFull=L and GSF_Cmd_Pg="000" and GSF_Cmd_Rd="001") else L;
	
	o_Mac2Tun_En <= Mac2Tun_En;
	o_Tun2Mac_D <= i_RxData;
	o_Tun2Mac_Dv <= Tun2Mac_Dv;
end generate tt;

nt: if (g_Tunnel=0) generate begin 
	o_Mac2Tun_En <= L;
	o_Tun2Mac_D <= (others => L);
	o_Tun2Mac_Dv <= L;
end generate nt;

	
	o_dbg(0) <= Tun2Mac_Dv;				-- b_C96_a5
	o_dbg(1) <= Mac2Tun_En;             -- b_C96_a6
	o_dbg(2) <= ExtPage;                -- b_C96_a7
	o_dbg(3) <= ExtFull;                -- b_C96_a8
	o_dbg(4) <= ExtDv;                  -- b_C96_a9
	o_dbg(5) <= ExtFirst;               -- b_C96_a10
	o_dbg(6) <= GSF_Cmd_Pg8;                      -- b_C96_a11
	o_dbg(7) <= L;                      -- b_C96_a12
	

--******************************************************************************
--
--  if Slave attached and CRC ok
--		set Page IRQ
--		kick page WathDog
--		toggle Memory WriteBuffer
--
--******************************************************************************
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			PgIRQs   <= x"00";
			PgTlgSyn <= x"00";
			
			if (g_Tunnel=0 or GSF_Cmd_Pg8=L) then
			
				if (SubFrmOk = H) then				-- was the whole frame ok
					-- set IRQ if slave attached and IRQenabled
					PgIRQs(CONV_INTEGER(GSF_Cmd_Pg)) <= GSF_Cmd_IrqEn;

					-- set Page WatchDog Bit = Safety bit-0
					PgWdogs(CONV_INTEGER(GSF_Cmd_Pg)) <= WdogBit;

					if (GSF_Cmd_Wr /= 0) then
						--- Daten OK, umschalten auf neuen Buffer --------------
						WrBufTgl( CONV_INTEGER(GSF_Cmd_Pg) ) <= not WrBufTgl( CONV_INTEGER(GSF_Cmd_Pg) );
					end if;
				end if;

				-- one short pulse only a start of PgData access
				if (GS_RxSeq = sMemDat_H) and (SlaveAttached = L) then
					PgTlgSyn(CONV_INTEGER(GSF_Cmd_Pg)) <= H;
				end if;
				
			end if;

		end if;
	end process;

	o_PgIRQs	<= PgIRQs;
	o_PgWdogs   <= PgWdogs;
	-- Pg-0-synch is not possible, so I take this bit for 64kHz-saftey-cnt synch
	o_PgTlgSyn  <= PgTlgSyn(7 downto 1) & SynCopMas_ok;

--******************************************************************************
--
--		GIN-Frame Sequencer
--
--******************************************************************************
--  32 subtract		uses	16 slices
--  32 comperator   uses	 9 slices
--  16 comperator   uses	 5 slices
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
--			bwCrcErr <= bwCrcErr or i_bwEthCrcError ;

			-- t-1 SeqState, used by TxData
			GS_TxSeq <= GS_RxSeq;

			SubFrmOk		<= L;
			o_GinError		<= L;
			SlaveAttached   <= L;
			SynCopMas_ok	<= L;
			ExtPage <= L;
			ExtDv <= L;
			ExtFirst <= ExtFirst_1;
			ExtFirst_1 <= L;
			ExtFull <= L;
			o_Mac2Tun_Req_ack <= L;

			-- check if we got an Etnernet Framing Error
			if  ((i_EthError = H)
			and  (GS_RxSeq /= sIdle)				-- a not gin-fram
			and  (GS_RxSeq /= sErrEnd)				-- already counting error
			and  (GS_RxSeq /= sErrEnd1)				-- already counting error
			and  (GS_RxSeq /= sErrEnd2)				-- already counting error
			and  (GS_RxSeq /= sErrWaitEnd)) then	-- error already counted
				-- count also all Ethernet-Errors
				GS_RxSeq <= sErrEnd;

			else
				case GS_RxSeq is

				----------------------------------------------------------------
				--  Gin Header
				----------------------------------------------------------------
				when sIdle =>   --- wait for GF-Start of Header ----------------
					SynCopMas <= L;
					if  (i_GinRun = H) then
						GS_RxSeq <= sEth_HdCRC_L;
					elsif  (i_EthRun = L) then
						-- enough time to handel errors...
						if (ext_error_pending=H or change_diag_mode=H) then
							GS_RxSeq <= sErrEnd;
						end if;
					end if;
					
				--------------------------------------------------------------------
				--  EthHeader Csum
				--------------------------------------------------------------------
				when sEth_HdCRC_L =>
					GS_RxSeq <= sGF_StartOfFrame;

				--------------------------------------------------------------------
				--  Start of GinHeader
				--------------------------------------------------------------------
				when sGF_StartOfFrame =>
					GS_RxSeq <= sGF_HdBlink;

				--------------------------------------------------------------------
				--  GinHeader Blink
				--------------------------------------------------------------------
				when sGF_HdBlink =>
					GF_Flags_uc <= i_RxData;
					GS_RxSeq <= sGF_HdLen;

				--------------------------------------------------------------------
				--  GinHeader NrOfGinFrames
				--------------------------------------------------------------------
				when sGF_HdLen =>
					NrOfGSF <= i_RxData;
					GS_RxSeq <= sGF_Sfty_H;

				--------------------------------------------------------------------
				--  GinHeader Safety
				--------------------------------------------------------------------
				when sGF_Sfty_H =>
					GS_RxSeq <= sGF_Sfty_L;
				when sGF_Sfty_L =>
					GS_RxSeq <= sGF_HdCRC_H;
					-- CopMaster Synch (3-Port RAM syncher)	64kHz_cnt = 3F
					if ((MEM_RdData(5 downto 0) /= b"00_0000")
					and (  i_RxData(5 downto 0)  = b"00_0000")) then
						SynCopMas <= H;
					end if;
				--------------------------------------------------------------------
				--  GinHeader Csum
				--------------------------------------------------------------------
				when sGF_HdCRC_H =>
					if ((RxCRC_Equ_H = H) or (RxCRC_OFF = H)) then
						GS_TxSeq <= sTx_CRC_H;
						GS_RxSeq <= sGF_HdCRC_L;
					else
						GS_TxSeq <= sTx_CRC_Err;
						GS_RxSeq <= sErrEnd;
						error_gfrx <= H;
					end if;

				when sGF_HdCRC_L =>
					if ((RxCRC_Equ_L = H) or (RxCRC_OFF = H)) then
						GS_TxSeq <= sTx_CRC_L;
						GS_RxSeq <= sGSF_StartOfFrame;
						-- CRC-OK, synch Cop_Master (3-Port RAM syncher)
						SynCopMas_ok <= SynCopMas;
						GF_Flags <= GF_Flags_uc;
						
						if (GF_Flags_uc(9)/=GF_Flags(9)) then
							change_diag_mode <= H;
						end if;
					else
						GS_TxSeq <= sTx_CRC_Err;
						GS_RxSeq <= sErrEnd;
						error_gfrx <= H;
					end if;

				--------------------------------------------------------------------
				--  GinSubFrame Header
				--------------------------------------------------------------------
				when sGSF_StartOfFrame =>
					GS_RxSeq <= sGSF_Cmd;

				when sGSF_Cmd =>	--- save Cmd -----------------------------------
					GSF_Cmd <= i_RxData;
					GS_RxSeq <= sGSF_Adr_H;

				when sGSF_Adr_H =>  --- save Adr -----------------------------------
					GSF_Adr_H <= i_RxData;
					GS_RxSeq <= sGSF_Adr_L;

				when sGSF_Adr_L =>  --- save Adr -----------------------------------
--ToDo optimize		-- calc Offset in frame till my memory-adr
					-- für TT=000
					MemAdrOfs <= MEM_RdData - (RxData_1 & i_RxData);
					-- für TT=010   fe MySlnr 0123 - 0120 = 3
					FixOfs	  <= MEM_RdData(15 downto 0) - i_RxData;
					GSF_Adr_L <= i_RxData;
					GS_RxSeq <= sGSF_Len;
					if (GSF_Cmd_TT = "001") or (GSF_Cmd_TT = "010") or (GSF_Cmd_TT = "011") or (GSF_Cmd_Pg8 = H) then
						SlaveNr <= MEM_RdData(15 downto 0);
					end if;

				when sGSF_Len =>	--- save Len -----------------------------------
					if (GSF_Cmd_TT = "010") then
						-- Slave-Register Mode with fix_len
						MemLen  <= x"00" & i_RxData(15 downto 12);
					else
						-- read MemLen(bytes) from CfgGSF_MemDef higher word
						-- convert it to 16-Bit words
						MemLen  <= MEM_RdData(28 downto 17);
					end if;

					GSF_Len <= i_RxData(11 downto 0);
--					GSF_FixLen <= i_RxData(14 downto 12);
					GS_RxSeq <= sGSF_Int;

				when sGSF_Int =>	--- save Int -----------------------------------

--					GSF_IRQ <= i_RxData;

					case GSF_Cmd_TT is
					when "000" =>   -- memory-adr mode
						AdrOfs <= MemAdrOfs;

					when "001"		-- broadcast
						|"011"=>	-- slave cfg_reg block access
						AdrOfs <= x"00000000";

					when "010" =>   -- slave-adr mode
						-- 32Bit/Slave == 4Byte
						AdrOfs <= "00000000000000" & FixOfs & "00";

					when others => null; -------------------------------------------
					end case;

					GS_RxSeq <= sGSF_Sfty_H;

				--------------------------------------------------------------------
				--  GinSubHeader Safety
				--------------------------------------------------------------------
				when sGSF_Sfty_H =>
					GS_RxSeq <= sGSF_Sfty_L;
				when sGSF_Sfty_L =>
					WdogBit <= i_RxData(0);
					GS_RxSeq <= sGSF_HdCRC_H;

				--------------------------------------------------------------------
				--  GinSubFrame Header Csum
				--------------------------------------------------------------------
				when sGSF_HdCRC_H =>
					if ((RxCRC_Equ_H = H) or (RxCRC_OFF = H)) then
						GS_TxSeq <= sTx_CRC_H;
						GS_RxSeq <= sGSF_HdCRC_L;
					else
						GS_TxSeq <= sTx_CRC_Err;
						GS_RxSeq <= sErrEnd;
						error_gfrx <= H;
					end if;

				when sGSF_HdCRC_L =>
					 if ((RxCRC_Equ_L = H) or (RxCRC_OFF = H)) then
						GS_TxSeq <= sTx_CRC_L;
						ExtPage <= GSF_Cmd_Pg8;
						-- check if Page-8..F
						if (GSF_Cmd_Pg8 = H) then
							ExtFirst_1 <= H;
							GS_RxSeq <= sWaitCnt;
						-- check if memory-access
						else
							if (GSF_Cmd_TT = "000") then
								GS_RxSeq <= sGSF_StartOfMemData;
							else
								--s config-register access
								GS_RxSeq <= sGSF_StartOfCfgData;
							end if;
						end if;
					else
						GS_TxSeq <= sTx_CRC_Err;
						GS_RxSeq <= sErrEnd;
						error_gfrx <= H;
					end if;

				--------------------------------------------------------------------
				--  GinSubFrame Data
				--------------------------------------------------------------------
				when sGSF_StartOfMemData
					|sGSF_StartOfCfgData =>
					MemLen  <= MemLen  - 1; -- -1, so we can test to 000
					GSF_Len <= GSF_Len - 2; -- -2, so we can test to 000
					AdrOfs  <= AdrOfs  - 2; -- -2, so we can test to 000
					case CmdSwitch is
					when sGSF_CmdDecWdat	=> GS_RxSeq <= sWaitMemDat;
					when sGSF_CmdDecDat_H   => GS_RxSeq <= sMemDat_H;
					when sGSF_CmdDecWend	=> GS_RxSeq <= sWaitCnt;
					when sGSF_CmdDecEnd		=> GS_RxSeq <= sGSF_Sla;
					when others => null;
					end case;

				when sWaitMemDat =>--- Wait for Data ---------------------------
					GSF_Len <= GSF_Len - 2; -- dec data-lenght
					AdrOfs  <= AdrOfs  - 2; -- dec adress-offset

					case CmdSwitch is
					when sGSF_CmdDecWdat	=> GS_RxSeq <= sWaitMemDat;
					when sGSF_CmdDecDat_H   => GS_RxSeq <= sMemDat_H;
					when sGSF_CmdDecEnd		=> GS_RxSeq <= sGSF_Sla;
					when others => null;
					end case;

				when sMemDat_H =>   --- Mem Data 31..16 ------------------------
					SlaveAttached <= H;						-- yes, that's mine
					MemLen  <= MemLen  - 1;
					GSF_Len <= GSF_Len - 2; -- dec data-lenght

					case CmdSwitch is
					when sGSF_CmdDecDat_L   => GS_RxSeq <= sMemDat_L;
					when sGSF_CmdDecWend	=> GS_RxSeq <= sWaitCnt;
					when sGSF_CmdDecEnd		=> GS_RxSeq <= sGSF_Sla;
					when others => null;
					end case;

					case GSF_Cmd_Rd is
					when cmd_Rd				=> GS_TxSeq <= sTxH_Rd;
					when cmd_Rx_Or			=> GS_TxSeq <= sTxH_Rx_Or;
					when cmd_Rx_Inc			=> GS_TxSeq <= sTxH_Rx_Inc;
					when cmd_Rx_And			=> GS_TxSeq <= sTxH_Rx_And;
					when others => null;
					end case;

				when sMemDat_L =>   --- Mem Data 15..0 -------------------------
					SlaveAttached <= H;						-- yes, that's mine
					MemLen  <= MemLen  - 1;
					GSF_Len <= GSF_Len - 2; -- dec data-lenght

					case CmdSwitch is
					when sGSF_CmdDecDat_H   => GS_RxSeq <= sMemDat_H;
					when sGSF_CmdDecWend	=> GS_RxSeq <= sWaitCnt;
					when sGSF_CmdDecEnd		=> GS_RxSeq <= sGSF_Sla;
					when others => null;
					end case;

					case GSF_Cmd_Rd is
					when cmd_Rd				=> GS_TxSeq <= sTxL_Rd;
					when cmd_Rx_Or			=> GS_TxSeq <= sTxL_Rx_Or;
					when cmd_Rx_Inc			=> GS_TxSeq <= sTxL_Rx_Inc;
					when cmd_Rx_And			=> GS_TxSeq <= sTxL_Rx_And;
					when others => null;
					end case;

				----------------------------------------------------------------
				--  Gin Slave Counter
				----------------------------------------------------------------
				when sWaitCnt =>
					SlaveAttached <= SlaveAttached;			-- hold it
					if (g_Tunnel/=0) then
						ExtPage <= GSF_Cmd_Pg8;
						if (GSF_Cmd_Pg8 = H) then
							SlaveAttached <= Tun2Mac_Dv or ExtDv;
							if (GSF_Cmd_Rd="001") then
								ExtDv <= ExtDv;
								ExtFull <= ExtFull;
								if ExtFirst=H then
									 -- DAAD for first come first serve or SlaveNr|0x8000 to select a Slave
									if (i_RxData=x"DAAD" or i_RxData=(H & SlaveNr(14 downto 0))) then
										ExtDv <= i_Mac2Tun_Req;
									else
										ExtFull <= H;
									end if;
								end if;
							end if;
						end if;
					end if;
					GSF_Len <= GSF_Len - 2;   -- dec data-lenght
					case CmdSwitch is
					when sGSF_CmdDecEnd		=> GS_RxSeq <= sGSF_Sla;
					when others => null;
					end case;

				--------------------------------------------------------------------
				--  GinSubFrame Slave Atached
				--------------------------------------------------------------------
				when sGSF_Sla =>
					SlaveAttached <= SlaveAttached;			-- hold it
					if (g_Tunnel/=0) then
						o_Mac2Tun_Req_ack <= ExtDv;
					end if;
					if (SlaveAttached = H) then				-- yes, I got data
						GS_TxSeq <= sTxL_Rx_Inc;			-- inc SlaveAttached
					end if;
					GS_RxSeq <= sGSF_DatCRC_H;

				--------------------------------------------------------------------
				--  GinSubFrame Data-CRC
				--------------------------------------------------------------------
				when sGSF_DatCRC_H =>
					SlaveAttached <= SlaveAttached;			-- hold it
					if ((RxCRC_Equ_H = H) or (RxCRC_OFF = H)) then
						GS_TxSeq <= sTx_CRC_H;
						GS_RxSeq <= sGSF_DatCRC_L;
					else
						GS_TxSeq <= sTx_CRC_Err;
						GS_RxSeq <= sErrEnd;
						error_gfrx <= H;
					end if;

				when sGSF_DatCRC_L =>
					NrOfGSF <= NrOfGSF - 1;					--ToDo ?-Bits

					if ((RxCRC_Equ_L = H) or (RxCRC_OFF = H)) then
						GS_TxSeq <= sTx_CRC_L;
						--- this Frame is OK -----------------------------------
						SubFrmOk <= SlaveAttached;			-- Attached and OK

						--- Check if we have more GIN-Frames -------------------
						if (NrOfGSF > 1) then
							 GS_RxSeq <= sGSF_StartOfFrame;
						else
							if  (i_GinRun = H) then
								GS_RxSeq <= sOkWaitEnd;
							else
								GS_TxSeq <= sTx_CRC_H;
								GS_RxSeq <= sOkEnd;
							end if;
						end if;
					else
						GS_TxSeq <= sTx_CRC_Err;
						GS_RxSeq <= sErrEnd;
						error_gfrx <= H;
					end if;

				----------------------------------------------------------------
				--  Ok-End, wait to end of GinFrame
				----------------------------------------------------------------
				when sOkWaitEnd =>
					if  (i_GinRun = L) then
						GS_TxSeq <= sTx_CRC_H;
						GS_RxSeq <= sOkEnd;
					end if;

				----------------------------------------------------------------
				--  Ok-End, count GinFrames
				----------------------------------------------------------------
				when sOkEnd =>  --- count GF -----------------------------------
					GS_TxSeq <= sTx_CRC_L;
					GS_RxSeq <= sOkEnd1;
				when sOkEnd1 => --- count GF -----------------------------------
					GS_RxSeq <= sOkEnd2;
				when sOkEnd2 => --- count GSF ----------------------------------
					GS_RxSeq <= sOkEnd3;
				when sOkEnd3 => --- count GSF ----------------------------------
					SlvFlags <= MEM_RdData;
					GS_RxSeq <= sIdle;

				----------------------------------------------------------------
				--  Error End, Add ErrorCounter + 1
				----------------------------------------------------------------
				-- Für ein Inc einer DPRam-Zelle +1 braucht es zwei States
				--  1   Adr anlegen
				--  2   WrData = RdData + 1 ; WR

				when sErrEnd =>		--- Error, Inc Error-Counter ---------------
					o_GinError <= H;
					GS_RxSeq <= sErrEnd1;
				when sErrEnd1 =>	--- write Error-Counter --------------------
					GS_RxSeq <= sErrEnd2;
				when sErrEnd2 =>	--- write Error-Counter --------------------
					GS_RxSeq <= sErrWaitEnd;
					error_gfrx <= L;
					change_diag_mode <= L;
				when sErrWaitEnd => --- Wait to EndOFGinFrame ------------------
					if  (i_GinRun = L) then
						GS_RxSeq <= sIdle;
					end if;

--				  ----------------------------------------------------------------
--				when sbwCrcErr =>		--- Error, Inc Error-Counter -----------
--					-- wait until bwCRCerr past, so we don't cnt it twice
--					if (i_bwEthCrcError = L) then
--						if (bwCrcErr = H) then
--							GS_RxSeq <= sErrEnd1;
--							bwCrcErr <= L;
--						else
--							GS_RxSeq <= sIdle;
--						end if;
--					end if;

				when others => null; -------------------------------------------
				end case;
			end if;
		end if;
	end process;

--******************************************************************************
--
--		Memory Access
--
--******************************************************************************
--  Vorsicht: zwischen MemAdr und RdData sind zweit States!
--------------------------------------------------------------------------------
--  synchron part of DP-Ram read
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			MEM_Adr_1 <= MEM_Adr;

			--- save Wr-Data high
			WrDatBuf31_16 <= i_RxData;

			case GS_RxSeq is
			when sMemDat_L =>   --- Reg Data 15..0 -----------------------------
				--- Latch Read Data from Ram
				RdDatBuf15_0 <= MEM_RdData(15 downto 0);
				--- next adr
				MEM_Adr_1 <= MEM_Adr_1 + 1;

			when others => null; -------------------------------------------
			end case;
		end if;
	end process;

	MEM_RdData_P1 <= MEM_RdData + 1;
	MEM_WrData_NULL <= x"00000000";
	MEM_WrData_RXDATA <= WrDatBuf31_16 & i_RxData;
	
	ext_error_pending <= error_ethfw or error_ethbw or linkdown_fw or linkdown_bw or xChangerErr;
	
	o_fw_error <= fw_error;
	o_bw_error <= bw_error;
	
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			if (change_diag_mode=H) then
				MEM_WrData_PERR <= GF_Flags(9) & MEM_WrData_NULL(30 downto 0);
			elsif (GF_Flags(9)=L) then
				fw_error <= L;
				bw_error <= L;
				error_ethfw <= L;
				error_ethbw <= L;
				linkdown_fw <= L;
				linkdown_bw <= L;
				xChangerErr <= L;
				MEM_WrData_PERR <= MEM_RdData_P1;
			else
				if (i_error_ethfw=H or i_EthError=H) then
					error_ethfw <= H;
				elsif (GS_RxSeq = sErrEnd2) then
					error_ethfw <= L;
				end if;
				if (i_error_ethbw=H or i_EthError_bw=H) then
					error_ethbw <= H;
				elsif (GS_RxSeq = sErrEnd2) then
					error_ethbw <= L;
				end if;
				if (i_linkdown_fw=H) then
					linkdown_fw <= H;
				elsif (GS_RxSeq = sErrEnd2) then
					linkdown_fw <= L;
				end if;
				if (i_linkdown_bw=H) then
					linkdown_bw <= H;
				elsif (GS_RxSeq = sErrEnd2) then
					linkdown_bw <= L;
				end if;
				if (i_xChangerErr=H) then
					xChangerErr <= H;
				elsif (GS_RxSeq = sErrEnd2) then
					xChangerErr <= L;
				end if;
				
				MEM_WrData_PERR <= H & L & bw_error & fw_error & MEM_RdData(27 downto 0);
			
				if (error_gfrx=H or error_ethfw=H) then
					fw_error <= H;
					MEM_WrData_PERR( 3 downto  0) <= MEM_RdData( 3 downto  0) + 1;
				end if;
				if (error_ethbw = H) then
					bw_error <= H;
					MEM_WrData_PERR(7 downto 4) <= MEM_RdData(7 downto 4) + 1;
				end if;
				if (linkdown_fw = H) then
					fw_error <= H;
					MEM_WrData_PERR(11 downto 8) <= MEM_RdData(11 downto 8) + 1;
				end if;
				if (linkdown_bw = H) then
					bw_error <= H;
					MEM_WrData_PERR(15 downto 12) <= MEM_RdData(15 downto 12) + 1;
				end if;
				if (xChangerErr = H) then
					MEM_WrData_PERR(19 downto 16) <= MEM_RdData(19 downto 16) + 1;
				end if;
				
			end if;
		end if;
	end process;
	
--------------------------------------------------------------------------------
--  asynchron part of DP-Ram read
--------------------------------------------------------------------------------
	process (GS_RxSeq,i_RxData,WrBufTgl,sw_RxBuf,
			MEM_Adr_1,MEM_RdData,MEM_RdData_P1,WrDatBuf31_16,
			GSF_Cmd,GSF_Cmd_Wr,GSF_Cmd_Pg,GSF_Cmd_TT,
			GSF_Adr,SlaveAttached,MEM_WrData_NULL,MEM_WrData_RXDATA
		) begin

		MEM_WR <= L;
		MEM_WrData <= MEM_WrData_NULL;
		MEM_Adr <= MEM_Adr_1;
		sw_RxBuf(4) <=  WrBufTgl(CONV_INTEGER(GSF_Cmd_Pg));

		case GS_RxSeq is

		------------------------------------------------------------------------
		--  Blink-Flags
		------------------------------------------------------------------------
		-- also save StrofOfFrame, can maybe used to synch something
		when sGF_HdBlink => --- save GF-Flags ----------------------------------
			MEM_Adr <= CfgGF_Flags;
			MEM_WrData <= MEM_WrData_RXDATA;
			MEM_WR <= H;

		------------------------------------------------------------------------
		--  Safety Word
		------------------------------------------------------------------------
        when sGF_Sfty_H =>--- save Safety Word ---------------------------------
            MEM_Adr <= CfgGF_Safety;
            
        when sGF_Sfty_L =>--- save Safety Word ---------------------------------
            MEM_Adr <= CfgGF_Safety;
			MEM_WrData <= MEM_WrData_RXDATA;
			MEM_WR <= H;

		------------------------------------------------------------------------
		--  Read Page Compare Address
		------------------------------------------------------------------------
		when sGSF_Adr_H =>  --- save Adr ---------------------------------------
			-- broadcast or SlaveAdrMode
			if (GSF_Cmd_TT = "001") or (GSF_Cmd_TT = "010") or (GSF_Cmd_TT = "011") or (GSF_Cmd_Pg8 = H) then
				-- point to CfgReg Slave-Adr
				MEM_Adr <= CfgMy_SlaveNr;
			else
				-- point to CfgGSF_AdrCmp(GSF_Cmd_Pg) to read the ComperatorAdr
				MEM_Adr <= CfgGSF_AdrCmp(15 downto 6) & GSF_Cmd_Pg & CfgGSF_AdrCmp(2 downto 0);
			end if;

		when sGSF_Adr_L =>  --- save Adr -----------------------------------
			-- point to CfgGSF_MemDef(GSF_Cmd_Pg) to  MemLen
			MEM_Adr <= CfgGSF_MemDef(15 downto 6) & GSF_Cmd_Pg & CfgGSF_MemDef(2 downto 0);

		when sGSF_Sfty_L =>
			--coppas??MEM_Adr <= CfgGSF_Safety(15 downto 7) & GSF_Cmd_Pg8 & GSF_Cmd_Pg & CfgGSF_Safety(2 downto 0);
			MEM_Adr <= CfgGSF_Safety(15 downto 6) & GSF_Cmd_Pg & CfgGSF_Safety(2 downto 0);
			MEM_WrData <= MEM_WrData_RXDATA;
			MEM_WR <= not GSF_Cmd_Pg8;

		when sGSF_HdCRC_L =>
			-- again point to CfgGSF_MemDef(GSF_Cmd_Pg) to read the BaseAdr
			MEM_Adr <= CfgGSF_MemDef(15 downto 6) & GSF_Cmd_Pg & CfgGSF_MemDef(2 downto 0);

		------------------------------------------------------------------------
		-- Start of Data
		------------------------------------------------------------------------
		when sGSF_StartOfMemData => --- Start of Memory Data --------------------------
			MEM_Adr <= "00" & MEM_RdData(15 downto 2);

		when sGSF_StartOfCfgData => --- Start of ConfigReg Data --------------------------
			-- GSF_Adr = Byte-Adr, daher einfach /4
			-- 32-bit access only supported
			MEM_Adr <= "00" & GSF_Adr(31 downto 18);
		------------------------------------------------------------------------
		--  Read and Write Data (normal Slave)
		------------------------------------------------------------------------
		-- for reading Config:  A9=L,A8=L
		-- for writing Config:  A9=L,A8=L
		-- for reading Data:	A9=L,A8=H					while sMemDat_H
		-- for writing Data:	A9=H,A8=WrDatBufToggle		while sMemDat_L
		------------------------------------------------------------------------
		when sMemDat_H =>   --- Reg Data 31..16 ------------------------
			-- in this state, we read Tx_Data from DPR to send them
			if (GSF_Cmd_Pg /= 0) then
				-- we have to switch from RxBUF0/1 back to TxBUF
				----------------------------------------------------------------
				case sw_RxBuf(3 downto 0) is	-- g_GS_Type: normal,COP,3Port
				----------------------------------------------------------------
				when x"0" => MEM_Adr(10 downto 7)	<=  MEM_Adr_1(10) & "01" & MEM_Adr_1(7) ; 	-- 0400..07FF
				when x"1" => MEM_Adr(10 downto 7)	<=  MEM_Adr_1(10) & "101"; 					-- 0A00..0BFF
				when x"2" => MEM_Adr(10 downto 7)	<= "01" & MEM_Adr_1(8) & MEM_Adr_1(7) ;		-- 0800..0FFF
				----------------------------------------------------------------
				when others => null;
				end case;
				----------------------------------------------------------------
			end if;

		when sMemDat_L =>   --- Reg Data 15..0 -----------------------------
			-- in this state, we write the received data to Rx_Datat in DPR
			if (GSF_Cmd_Pg /= 0) then
				-- we have to switch from TxBUF to RxBUF0/1
				----------------------------------------------------------------
				case sw_RxBuf(7 downto 0) is	-- g_GS_Type: normal,COP,3Port
				---- WrTgl = 0 -------------------------------------------------
				when x"0_0" => MEM_Adr(10 downto 7)	<=  MEM_Adr_1(10) & "10" & MEM_Adr_1(7) ; 	-- 0800..0BFF
				when x"0_1" => MEM_Adr(10 downto 7)	<=  MEM_Adr_1(10) & "110"; 	-- 0C00..0DFF
				when x"0_2" => MEM_Adr(10 downto 7)	<= "10" & MEM_Adr_1(8) & MEM_Adr_1(7)  ;	-- 1000..17FF
				---- WrTgl = 1 -------------------------------------------------
				when x"1_0" => MEM_Adr(10 downto 7)	<=  MEM_Adr_1(10) & "11" & MEM_Adr_1(7) ; 	-- 0C00..0FFF
				when x"1_1" => MEM_Adr(10 downto 7)	<=  MEM_Adr_1(10) & "111"; 	-- 0E00..0FFF
				when x"1_2" => MEM_Adr(10 downto 7)	<= "11" & MEM_Adr_1(8) & MEM_Adr_1(7)  ;	-- 1800..1FFF
				----------------------------------------------------------------
				when others => null;
				end case;
				----------------------------------------------------------------
			end if;

			case GSF_Cmd_Wr is
			when cmd_Wr =>
				MEM_WrData <= MEM_WrData_RXDATA;
				MEM_WR <= H;

			when cmd_Clear =>
				MEM_WrData <= MEM_WrData_NULL;
				MEM_WR <= H;

			when others => null;
			end case;

		--------------------------------------------------------------------
		--  count received GinSubFrames
		--------------------------------------------------------------------
		when sGSF_Sla =>	--- count GinSubFrames -----------------------------
			--coppas??MEM_Adr <= CfgGSF_Cnt(15 downto 7) & GSF_Cmd_Pg8 & GSF_Cmd_Pg & CfgGSF_Cnt(2 downto 0);
			MEM_Adr <= CfgGSF_Cnt(15 downto 6) & GSF_Cmd_Pg & CfgGSF_Cnt(2 downto 0);

		when sGSF_DatCRC_L =>   --- count GinSubFrames -----------------------------
			MEM_WR <= SlaveAttached and not GSF_Cmd_Pg8;		-- count only if attached
			MEM_WrData <= MEM_RdData_P1;

		--------------------------------------------------------------------
		--  OK-End , count received OK-GinFrames
		--------------------------------------------------------------------
		when sOkEnd =>  --- Ok End, count GinFrames ----------------------------
			MEM_Adr <= CfgGF_Cnt;

		when sOkEnd1 => --- count GinFrames ------------------------------------
			MEM_WR <= H;
			MEM_WrData <= MEM_RdData_P1;
			
		when sOkEnd2 =>
			MEM_Adr <= CfgMy_SlvFlags;

		------------------------------------------------------------------------
		--  Error-End , count received Error-GinFrames
		------------------------------------------------------------------------
		when sErrEnd =>		--- Error, Inc Error-Counter ---------------
			MEM_Adr <= CfgGF_Err;

--		when sbwCrcErr =>   --- bwCrcError, Inc beError-Counter ---------------
--			MEM_Adr <= CfgBwError;

		when sErrEnd2 =>	--- write Error-Counter --------------------
			MEM_WR <= H;
			MEM_WrData <= MEM_WrData_PERR;

		------------------------------------------------------------------------
		when others => null;
		end case;
	end process;

--******************************************************************************
--
--  Command decoder
--
--******************************************************************************
--  Es gibt drei Zugriffs-Arten
--  1.  Broadcast
--		zB Rd_Or CfgReg-Error über alle Slaves
--
--  2.  32-Bit per Slave
--		zB Rd CfgReg Error von allen Slaves einzeln hintereinander
--
--  3.  Memory-Bereich
--		zB Rd Alle Istwerte
--------------------------------------------------------------------------------

	process (GSF_Cmd,GSF_Cmd_TT,AdrOfs,GSF_Len,FixOfs,MemLen,GS_RxSeq) begin

		CmdSwitch <= sGSF_CmdDecNone;

		case GS_RxSeq is
--		when sGSF_HdCRC_L =>	--- check SubFrame Header ChkSum ---------------

		when sGSF_StartOfMemData
			|sGSF_StartOfCfgData =>
			if (GSF_Len = 0) then
				CmdSwitch <= sGSF_CmdDecEnd;				-- GinFrame End , no more data
			else
				case GSF_Cmd_TT is
				when "000"		-- memory-adr mode
				   | "010" =>   -- Slave-adr mode

					if (AdrOfs = x"00000000") then
						CmdSwitch <= sGSF_CmdDecDat_H;				-- memory-data 31..16
					else
						CmdSwitch <= sGSF_CmdDecWdat;				-- wait for memory-data
					end if;

				when "001" =>   -- broadcast
						CmdSwitch <= sGSF_CmdDecDat_H;				-- memory-data 31..16

				when "011" =>   -- slave config-reg block access
					--  FixOfs = MySlNr - RecSlNr = 0000 if it's for me
					if (FixOfs = x"0000") then
						CmdSwitch <= sGSF_CmdDecDat_H;				-- memory-data 31..16
					else
						CmdSwitch <= sGSF_CmdDecWend;				-- it's not for me ...
					end if;
				when others => null; -------------------------------------------
				end case;
			end if;

		when sWaitMemDat =>--- Wait for Data ---------------------------
			if (GSF_Len = 0) then
				CmdSwitch <= sGSF_CmdDecEnd;				-- GinFrame End , no more data
			else
				if (AdrOfs = x"00000000") then
					CmdSwitch <= sGSF_CmdDecDat_H;				-- memory-data 31..16
				else
					CmdSwitch <= sGSF_CmdDecWdat;				-- wait again for memory-data
				end if;
			end if;

		when sMemDat_H =>   --- Mem Data 31..16 ------------------------
			if (GSF_Len = 0) then
				CmdSwitch <= sGSF_CmdDecEnd;				-- GinFrame End , no more data
			else
				if (MemLen /= 0) then
					CmdSwitch <=sGSF_CmdDecDat_L;				-- memory-data 15..0
				else
					CmdSwitch <= sGSF_CmdDecWend;				-- MemArea end , wait frame-end
				end if;
			end if;

		when sMemDat_L =>   --- Mem Data 15..0 -------------------------
			if (GSF_Len = 0) then
				CmdSwitch <= sGSF_CmdDecEnd;				-- GinFrame End , no more data
			else
				if (MemLen /= 0) then
					CmdSwitch <= sGSF_CmdDecDat_H;				-- memory-data 31..16
				else
					CmdSwitch <= sGSF_CmdDecWend;				-- MemArea end , wait frame-end
				end if;
			end if;

		when sWaitCnt =>	--- wait till SlaveCnt ---------------------
			if (GSF_Len = 0) then
				CmdSwitch <= sGSF_CmdDecEnd;				-- GinFrame End , no more data
			end if;

		when others => null; -------------------------------------------
		end case;

	end process;

--******************************************************************************
--
--		Tx-Data
--
--******************************************************************************
--  Damit wir mögl wenig Durchlaufzeit haben, müssen die Rd-DPram und TxCsum
--  direkt auf TxData verknüpft werden.
--  TxData wird vom TxMGT dann sowieso wieder Q62.5 synchron übernommen.
--
--  Duchgeschlaufte RxDaten werden daher um 1 verzögert, RxData_1
--  Um wenig Verknüpfungen zu haben, wird hier auch UDP-Csum disable gemacht
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then

			-- TxCRC ist immer 1 State hinten nach, also...
			RxCharIsK_1 <= i_RxCharIsK;
			EthCRC_1	<= i_EthCRC;

			if (i_sUdpCsum = H) then		-- if UDP-Csum then
				RxData_1 <= x"0000";		--	  send 0000
			elsif ((g_Tunnel/=0) and (ExtDv = H) and (ExtPage = H)) then
				RxData_1 <= i_Mac2Tun_D;
			elsif ((g_Tunnel/=0) and ExtFirst=H and i_Mac2Tun_Req=H) then
				RxData_1 <= L & SlaveNr(14 downto 0);--slave/port nr
			else
				RxData_1 <= i_RxData;
			end if;

			nbrLxCRC32  <= nbrTxCRC32;		-- latch it for second tx-word
			TxCrcRun <= i_CrcRun;			-- tx one clk later then rx
		end if;
	end process;

--  Asynchron part of TxData
	process (i_EthRun,GS_TxSeq,nbrTxCRC32,nbrLxCRC32,MEM_RdData,RxData_1,RdDatBuf15_0,RxCharIsK_1) begin

		if (i_EthRun = L) then
--			TxCharIsK   <= "10";
--			TxData		<= x"BC50";
			TxCharIsK   <= "11";
			TxData		<= x"0000";
		else

		TxData		<= RxData_1;
		TxCharIsK   <= RxCharIsK_1;

		case GS_TxSeq is

		when sTx_CRC_H =>  --- Rx-CRC was ok, send TxCRC ----------------------
			TxData <= nbrTxCRC32(31 downto 16);

		when sTx_CRC_L =>  --- Rx-CRC was ok, send TxCRC ----------------------
			TxData <= nbrLxCRC32(15 downto 0);

		when sTx_CRC_Err =>  --- Rx-CRC was ok, send TxCRC ----------------------
			TxData <= x"EEEE";				-- send wrong CRC

		when sTxH_Rd => --- Data 31..16 ------------------------------------
			TxData <= MEM_RdData(31 downto 16);

		when sTxH_Rx_Or =>  --- Data 31..16 ------------------------------------
			TxData <= RxData_1 or MEM_RdData(31 downto 16);

		when sTxH_Rx_And => --- Data 31..16 ------------------------------------
			TxData <= RxData_1 and MEM_RdData(31 downto 16);

		when sTxL_Rd => --- Data 31..16 ------------------------------------
			TxData <= RdDatBuf15_0;

		when sTxL_Rx_Or =>  --- Data 31..16 ------------------------------------
			TxData <= RxData_1 or RdDatBuf15_0;

		when sTxL_Rx_Inc => --- Data 31..16 ------------------------------------
			TxData <= RxData_1 + 1;

		when sTxL_Rx_And => --- Data 31..16 ------------------------------------
			TxData <= RxData_1 and RdDatBuf15_0;

		when others => null; -------------------------------------------
		end case;

		end if;
	end process;

--******************************************************************************
--
--		GIN-Frame CRC
--
--******************************************************************************
--------------------------------------------------------------------------------
--  CheckSumm Comperator
--------------------------------------------------------------------------------
	process (i_RxData,i_EthCRC,EthCRC_1) begin

		if (i_RxData = i_EthCRC(31 downto 16)) then
			RxCRC_Equ_H <= H;
		else
			RxCRC_Equ_H <= L;
		end if;

		if (i_RxData = EthCRC_1(15 downto 0)) then
			RxCRC_Equ_L <= H;
		else
			RxCRC_Equ_L <= L;
		end if;

		if (i_RxData = x"CCCC") then
			RxCRC_OFF <= H;
		else
			RxCRC_OFF <= L;
		end if;

	end process;

--------------------------------------------------------------------------------
--  CRC-generator
--------------------------------------------------------------------------------
	uRxSeq_TxCRC: entity gin_link.GIN_Eth_CRC_D16
	PORT MAP(
		i_Q62_5		=> i_Q62_5	  ,
		i_Data		=> TxData	  ,
		i_CrcClr	=> i_CrcClr   ,
		i_CrcRun	=> TxCrcRun   ,
		o_EthCRC	=> nbrTxCRC32
	);


--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
