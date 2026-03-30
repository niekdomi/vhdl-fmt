--------------------------------------------------------------------------------
--
--	dpr2infoMS	2.00a chipskope buffer 1024
--
--------------------------------------------------------------------------------
--
--	project		: ppc-card, imp2, sac2
--	programmer	: C. Leuthold, INDEL AG
--	date		: 22.03.2004
--	version		: 1.00
--	language	: VHDL
--	system		: ISE / EDK
--
--	purpose
--		info link master or (imp)slave
--
--------------------------------------------------------------------------------
--	1.00b	05.05.2004	-le:	dpr2IMPinfoMS runs on imp2_1_00..1_02
--
--------------------------------------------------------------------------------
--	2.00a	28.09.2004	-le:	imp2 and sac2 cmp..
--								new generic C_SAC_SUP
--								new input i_CardTyp(2..0):
--									repalce constant C_CARD_TYP. settable const.
--									or var. from extern ->
--									variable communication channel for imp, sac
--									or whatever
--								i_AddrSwitch expanded to 8 bit
--									same reason
--								new output o_blinki
--									for sync ok leds on sac2 with info-link
--								new sac spez in- and outputs
--									o_NewData one clk pulse
--									when IMPCmpEn and dpr_compare(31) and
--									dpr_compare(24) and C_SAC_SUP=1
--									i_Status0: set TXStat0 when dpr_compare(24)
--									i_Status1: set TXStat1 when dpr_compare(24)
--									o_Status0: get RXStat0 whit o_sac_NewData
--									o_Status1: get RXStat1 whit o_sac_NewData
--									o_4KPr_out1: addr(2) when dpr_compare(25)
--									whit o_sac_NewData
--									o_MainCH
--			07.10.2004	-le:	slave: diagnostic-bit was invert
--									wdog combinate with CardOk
--									linkLed only if comperator set or inco
--			20.10.2004	-le:	slave: INCO CardIrq:
--									Reg(8)	= InfoAddr(7) and not Reg(7)
--			03.11.2004	-le:	half link led on inco.
--------------------------------------------------------------------------------
--	2.00b	14.02.2005	-le:	infoMaster_v1_00_c
--			15.07.2005	-le:	fehler: --bug150705
--								  jobs typ"00" werden ab addrswitch(3)=H falsch
--								  behandelt hw und sw... -> addr 0x0f tut nicht,
--								  da die kommunikation überschrieben wird.
--			05.09.2005	-le:	new: generic C_32BITJOBS = 1 add 16 32 bit jobs
--			28.09.2005	-le:	new: generic C_CONF_INCO
--									0 -> fix communication jobs
--									1 -> configurable communication jobs
--									2 -> both
--			18.10.2005	-le:	remove: sac spez ios: o_NewData, i_Status0,
--									i_Status1, o_Status0, o_Status1,
--									o_4KPr_out1, o_MainCH
--			30.12.2005	-le:	add: slave output o_TrOK
--			13.01.2006	-le:	add C_TYPE_IRQ4: 0: 1 irq4 / 1: sep. o_Int4_Typ for each jop type
--
--	01.03.2006-le:	lib adjustments for repository
--	09.05.2006-le:	synch irq4 with trok
--	19.09.2006-le:	change watchdog, new input i_WDOG_TIME (default: "10" = 4.965ms)
--	11.05.2007-le	add svn keywords
--	03.06.2008-le:	change watchdog to a 22mhz. (default: "10" = 4.468ms)
--	10.06.2008-le:	change TPs for for info-link debugging
--	05.05.2009-le:	add C_HIGH_TYPE_SUP to support card types higher then 3
--						only on of both is possible, e. g. 0x2000 or 0x6000!
--	31.08.2009-le:	correct i_WDOG_TIME="11"
--	02.02.2012-le:	remove xilinx specific components
--------------------------------------------------------------------------------
--$Rev:: 2221                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2012-02-02 11:07:44 +0100 (Do., 02 Feb 2012)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
----- includes -----------------------------------------------------------------
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- slave components
library infoSlave;
use infoSlave.info_link_seq;
use infoSlave.info_link_codec;
-- master components
library infoMaster;
use infoMaster.InfoLink_DprSeq;
use infoMaster.InfoLink_TxRx;
use infoMaster.InfoLink_Decoder;
use infoMaster.InfoLink_Encoder;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity dpr2infoMS is
	generic (
		C_CLK_DIV_22MHZ			: integer := 3;		--66MHz
		C_ChipScope_Implemented	: integer := 0;
		C_SpezJob_Implemented	: integer := 0;		-- old-fashion compatible
		C_SAC_SUP				: integer := 1;
		C_32BITJOBS				: integer := 0;
		C_CONF_INCO				: integer := 0;
		C_TYPE_IRQ4				: integer := 1;		-- 0: 1 irq4 / 1: sep. irq4 for each jop type
		C_HIGH_TYPE_SUP			: integer := 0
	);
	port (
		-- std-ports
		i_Clk		: in	std_logic;
		i_Rst		: in	std_logic := '0';				-- high-activ
		-- dprPORT
		o_dprEN		: out	STD_LOGIC;
		o_dprClk	: out	STD_LOGIC;
		o_dprRst	: out	STD_LOGIC;
		o_dprData	: out	STD_LOGIC_VECTOR(31 downto 0);
		i_dprData	: in	STD_LOGIC_VECTOR(31 downto 0);
		o_dprAddr	: out	STD_LOGIC_VECTOR(10 downto 0);
		o_dprWEN	: out	STD_LOGIC_VECTOR(3 downto 0);
		-- selector L: slave; H: master
		i_MasterSlave: in	std_logic := '0';
		-- LEDs
		no_LinkLED	: out	std_logic;				-- low-activ (L=light)
		no_PowerLED : out	std_logic;				-- low-activ (L=light)
		-- INFO-LINK
		ni_RX		: In	std_logic;				-- info-link in
		o_TX		: Out	std_logic;				-- info-link out
		--
		i_WDOG_TIME : in	std_logic_vector(1 downto 0) := "10"; -- wdog after => 4.965ms
		o_wdog		: out	std_logic;
		--
		o_TrOK		: out	std_logic;
		-- testport
		o_TP1		: out	std_logic;
		o_TP2		: out	std_logic;
		o_TP3		: out	std_logic;
		o_TP4		: out	std_logic;
		-- slave ports ---------------------------------------------------------
		-- PPC interrups
		o_Int0		: out	std_logic;				-- high-activ
		o_Int1		: out	std_logic;				-- high-activ
		o_Int4		: out	std_logic;
		o_Int4_Typ	: out	std_logic_vector (C_TYPE_IRQ4*4 downto 0);-- high-activ
		i_CIRQ0		: in	std_logic := '0';			-- high-activ
		i_CIRQ1		: in	std_logic := '0';			-- high-activ
		o_blinki	: out	std_logic;
		i_IMPCmpEn	: in	std_logic;
		i_CardTyp	: In	std_logic_vector(2 downto 0);
		i_AddrSwitch: in	std_logic_vector(7 downto 0);
		-- sac spez...
--		i_Status0	: in	std_logic := '0';
--		i_Status1	: in	std_logic := '0';
--		o_Status0	: out	std_logic;
--		o_Status1	: out	std_logic;
--		o_4KPr_out1	: out	std_logic;
--		o_MainCH	: out	std_logic;
--		o_NewData	: out	std_logic;
		-- master ports --------------------------------------------------------
		-- PPC interrup
		o_ILM_IRQ	: OUT	std_logic;						-- IRQ
		-- inputs for ilm seq
		i_Master_Ctrl: IN	std_logic_vector(7 downto 0) := (others => '0');
		i_Diag_ON	: in	std_logic := '0';
		i_Diag_invers: in	std_logic := '0';
		-- outputs
		o_JobIRQ	: out	std_logic;
		o_CIRQ		: out	std_logic;
		o_Error		: out	std_logic;
		o_Ovrun		: out	std_logic;
		o_Or1ms		: out	std_logic;
		i_dbg_in	: in	std_logic_vector(15 downto 0) := (others => '0');
		i_Spy0		: in	std_logic := '0';
		i_Spy1		: in	std_logic := '0';
		i_Spy2		: in	std_logic := '0';
		i_Spy3		: in	std_logic := '0';
		i_Spy4		: in	std_logic := '0';
		i_Spy5		: in	std_logic := '0';
		i_Spy6		: in	std_logic := '0';
		i_Spy7		: in	std_logic := '0'
	);
end dpr2infoMS;

architecture Behavioral of dpr2infoMS is
-- components --------------------------------------------------------------
	component info_link_seq
	generic (
		C_CLK_DIV_22MHZ : integer :=4	--88MHz
	);
	port (
		-- std-inputs
		i_clk		: in	std_logic;
		i_Rst		: in	std_logic;	-- high-activ
		-- INFO-LINK
		o_Irq		: out	std_logic;
		o_blinki	: out	std_logic;
		o_diagnosis	: out	std_logic;
		o_32bit		: out	std_logic;
		o_Typ2		: out	std_logic;
		o_Typ1		: out	std_logic;
		o_Typ0		: out	std_logic;
		o_Addr7		: out	std_logic;
		o_Addr6		: out	std_logic;
		o_Addr5		: out	std_logic;
		o_Addr4		: out	std_logic;
		o_Addr3		: out	std_logic;
		o_Addr2		: out	std_logic;
		o_Addr1		: out	std_logic;
		o_Addr0		: out	std_logic;
		o_MCok		: out	std_logic;
		o_CIrqEn	: out	std_logic;
		o_Status1	: out	std_logic;	-- infoLink status-bit
		o_Status0	: out	std_logic;	-- infoLink status-bit
		o_Data		: out	STD_LOGIC;

		o_cIrq		: out	std_logic;
		o_cDiagnosis: out	std_logic;
		o_c32bit	: out	std_logic;
		o_cTyp2		: out	std_logic;
		o_cTyp1		: out	std_logic;
		o_cTyp0		: out	std_logic;
		o_cAddr7	: out	std_logic;
		o_cAddr6	: out	std_logic;
		o_cAddr5	: out	std_logic;
		o_cAddr4	: out	std_logic;
		o_cAddr3	: out	std_logic;
		o_cAddr2	: out	std_logic;
		o_cAddr1	: out	std_logic;
		o_cAddr0	: out	std_logic;
		o_cMCok		: out	std_logic;
		o_cCIrqEn	: out	std_logic;
		o_cStatus1	: out	std_logic;	-- infoLink status-bit
		o_cStatus0	: out	std_logic;	-- infoLink status-bit
		o_cData32	: out	STD_LOGIC;
		o_cS35		: out	STD_LOGIC;
		o_cData16	: out	std_logic;
		o_cS37		: out	std_logic;
		o_cData		: out	std_logic;
		o_cWrite_D	: out	std_logic;
		o_cReadH	: out	std_logic;
		o_cS52		: out	std_logic;
		o_cDataEnd	: out	std_logic;

		i_diagnosis	: in	std_logic;
		i_CardOk	: in	std_logic;
		i_CardIrq	: in	std_logic;
		i_CIrqUnasked: in	std_logic;
		i_Status1	: in	std_logic;	-- infoLink status-bit
		i_Status0	: in	std_logic;	-- infoLink status-bit
		i_Data		: in	STD_LOGIC;

		i_Err		: in	std_logic;
		-- Eeprom --------------------------------------------------------------
		i_EEPROMen	: in	std_logic;
		o_EEen		: Out	std_logic;	-- EEPROM Chipselect
		o_EEclk		: Out	std_logic;	-- EEPROM Clock
		o_EEd		: Out	std_logic;	-- EEPROM Data Out
		i_EEd		: In	std_logic;	-- EEPROM Data In
		--
		o_LinkLED	: out	std_logic;	-- high-activ (H=light)
		o_PowerLED	: out	std_logic;	-- high-activ (H=light)
		i_AddrSwitch: In	std_logic_vector(7 downto 0);
		i_32not16	: in	std_logic;
		i_CardTyp	: In	std_logic_vector(2 downto 0);
		i_CmpEn		: in	std_logic_vector(11 downto 0);
		-- info_link_codec-port ------------------------------------------------
		-- LINK
		i_RX		: in	std_logic;	-- info-link input
		o_TX		: out	std_logic;	-- info-link output
		o_RErr		: out	std_logic;
		o_LiErr		: out	std_logic;
		o_BitClk	: out	std_logic;
		o_rxd		: out	std_logic;
		o_TrOK		: out	std_logic;
		o_RQq		: out	std_logic;
		o_RXq		: out	std_logic
	);
	END COMPONENT;
	----------------------------------------------------------------------------
	--	Dualport Ram Sequenzer
	----------------------------------------------------------------------------
	COMPONENT InfoLink_DprSeq
	generic (
		C_SpezJob_Implemented : boolean := false
	);
	port (
		i_Q66		: In	std_logic;
		i_Reset		: In	std_logic;
	---	Dualport Ram -----------------------------------------------------------
		o_dprAdr	: Out	std_logic_vector(10 downto 0);	-- DP-RAM Adr
		i_dprDat	: In	std_logic_vector(15 downto 0);	-- D15.0 Inp Reg
		o_dpr_R16_req : out	std_logic;
		o_dpr_WHB_req : out	std_logic;
		o_dpr_W16_req : out	std_logic;
		i_dpr_done	: in	std_logic;
	--- Sequenzer ctrl ---------------------------------------------------------
		i_RUN		: In	std_logic;					-- Sequenzer running
		i_ReSt		: In	std_logic;					-- Sequenzer ReStart
		i_Reg_Sta	: In	std_logic_vector( 7 downto 0);
		o_Tgo_en	: Out	std_logic;					-- short Puls
		o_Trst		: Out	std_logic;					-- short Puls
	--- Transmit Data Request --------------------------------------------------
		i_Treq		: In	std_logic_vector(1 downto 0);
		o_Tack		: Out	std_logic;
	--- Receiver Shift Register ------------------------------------------------
		i_Rreq		: In	std_logic_vector(1 downto 0);
		o_Rack		: Out	std_logic;
		i_saveIRQ	: in	std_logic;
		o_JobIRQ	: Out	std_logic					-- Tx Card-IRQ
	----------------------------------------------------------------------------
		);
	END COMPONENT;
	----------------------------------------------------------------------------
	--	TxRx Sequencer
	----------------------------------------------------------------------------
	COMPONENT InfoLink_TxRx
	PORT(
		i_Q66		: IN	std_logic;
		i_Reset		: IN	std_logic;
		i_Tx_Dat	: IN	std_logic_vector(15 downto 0);
		i_WDOGin	: IN	std_logic;
		i_RX		: IN	std_logic;
		i_Reg_Sta	: IN	std_logic_vector(7 downto 0);
		i_Reg_IOP	: IN	std_logic_vector(7 downto 0);
		i_Tgo_en	: IN	std_logic;
		i_Trst		: IN	std_logic;
		i_Tack		: IN	std_logic;
		i_Rack		: IN	std_logic;
		o_Rx_Dat	: OUT	std_logic_vector(15 downto 0);
		o_LEDrec	: OUT	std_logic;
		o_WDOGout	: OUT	std_logic;
		o_CIRQ		: OUT	std_logic;
		o_Or1ms		: OUT	std_logic;
		o_TX		: OUT	std_logic;
		o_RUN		: OUT	std_logic;
		o_ReSt		: OUT	std_logic;
		o_Error		: OUT	std_logic;
		o_Ovrun		: OUT	std_logic;
		o_Treq		: OUT	std_logic_vector(1 downto 0);
		o_Rreq		: OUT	std_logic_vector(1 downto 0);
		dbg_o_RErr	: out	std_logic;
		dbg_o_RXr	: out	std_logic;
		dbg_o_RNr	: out	std_logic
		);
	END COMPONENT;

	-- constants ---------------------------------------------------------------
	constant H		: std_logic := '1';
	constant L		: std_logic := '0';
	constant Z		: std_logic := 'Z';

	constant C_SpezJob_Implemented_bool : boolean := (C_SpezJob_Implemented=1);
	-- types -------------------------------------------------------------------
	type t_state_s is (idle_s, write_s, preread_s, read_s, read32_s);
	type t_state_m is (idle_m, write_m, preread_m, read_m);
	-- signals -----------------------------------------------------------------
	-- def. values for info_link_seq
	signal CardTyp		: std_logic_vector(2 downto 0);
	signal CmpEn		: std_logic_vector(11 downto 0);
	signal Low			: std_logic;
	signal High			: std_logic;
	-- std. signals for info_link_seq
	signal RX			: std_logic;
	signal TX			: std_logic;
	signal LinkLED		: std_logic;
	signal AddrSwitch	: std_logic_vector(7 downto 0);
	-- signals for info-link
	signal ni_RX1		: std_logic;
	signal ni_RX2		: std_logic;
	signal TrOk			: std_logic;
	signal TXData		: std_logic;
	signal RXData		: std_logic;
	signal RXd			: std_logic;
	signal BitClk		: std_logic;
	signal WDog			: std_logic;
	signal WDcnt		: std_logic_vector(17 downto 0);
	signal cnt22		: std_logic_vector(pkg_log2(C_CLK_DIV_22MHZ-1) downto 0) := (others => '0');
	signal cSave32addr	: std_logic;
	signal MCok			: std_logic;
	signal cMCok		: std_logic;
	signal TXStatus1	: std_logic;
	signal TXStatus0	: std_logic;
	signal RXStatus1	: std_logic;
	signal RXStatus0	: std_logic;
	signal n_LinkLED	: std_logic;
	signal Ien			: std_logic;
	signal CardIrq		: std_logic;
	signal CIrqUnasked	: std_logic;
	signal B32			: std_logic;
	signal state_s		: t_state_s;
	signal Reg			: std_logic_vector(34 downto 0);
	signal CIRQ0		: std_logic;
	signal CIRQ1		: std_logic;
	signal cAddr0		: std_logic;
	signal CardOk		: std_logic;
	signal INT4			: std_logic;
	signal INT4_Typ		: std_logic_vector(4 downto 0);
	signal INT4_reg		: std_logic;
	signal INT4_Typ_reg	: std_logic_vector(4 downto 0);
	signal INT1			: std_logic;
	signal INT0			: std_logic;
	signal do_write		: std_logic;
	signal shift		: std_logic;
	signal cDataEnd		: std_logic;
	signal cDiagnosis	: std_logic;
	signal dprAddr		: std_logic_vector(10 downto 0);
	signal InfoCom		: std_logic;
	signal IMPCmpEn		: std_logic;

	signal l_WDOGin		: std_logic;
	signal l_WDOGout	: std_logic;
	signal l_LEDrec		: std_logic;
	signal l_Or1ms		: std_logic;
	signal l_RUN		: std_logic;
	signal l_ReSt		: std_logic;
	signal l_Tgo_en		: std_logic;
	signal l_Trst		: std_logic;
	signal l_Error		: std_logic;
	signal l_Ovrun		: std_logic;
	signal l_TX			: std_logic;

	signal l_Treq		: std_logic_vector(1 downto 0);
	signal l_Rreq		: std_logic_vector(1 downto 0);
	signal l_Tack		: std_logic;
	signal l_Rack		: std_logic;

	signal l_Reg_IOP	: std_logic_vector(7 downto 0);
	signal l_ILM_IRQ	: std_logic;
	signal state_m		: t_state_m;

	signal l_JobIRQ		: std_logic;
	signal l_CIRQ		: std_logic;
	signal l_dprAdr		: std_logic_vector(10 downto 0);
	signal l_dprWEN		: std_logic_vector(3 downto 0);
	signal l_dprWEN_LB	: std_logic;
	signal l_dprWEN_HB	: std_logic;

	signal o_dprD_m		: std_logic_vector(31 downto 0);
	signal o_dprD_s		: std_logic_vector(31 downto 0);
	signal dpr_R16_req	: std_logic;
	signal dpr_WHB_req	: std_logic;
	signal dpr_W16_req	: std_logic;
	signal dpr_done		: std_logic;
	signal dprWEN		: std_logic_vector(3 downto 0);
	signal dprEN		: std_logic;
	signal i_RX			: std_logic;
	signal l_Rx_Dat		: std_logic_vector(15 downto 0);	-- D15.0 Out Reg
	signal dprDinp		: std_logic_vector(15 downto 0);
--	signal save_status	: std_logic := L;
--	signal out4kpr		: std_logic := L;
	signal l_LinkLED	: std_logic := L;
	signal com_LinkLED	: std_logic := L;

	signal RErr			: std_logic := L;
	signal RXr			: std_logic := L;
	signal RNr			: std_logic := L;
	signal MasterSlave	: std_logic;
	signal saved_32Addr	: std_logic_vector(15 downto 0);
	signal Addr7		: std_logic := L;
	signal InfoComConf	: std_logic := L;
	signal sRErr : std_logic := L;
	signal sRQq : std_logic := L;
	signal sRXq : std_logic := L;
	signal sLiErr : std_logic := L;
	-------------------------------------------------------------------
	--
	--	ILA core component declaration
	--
	-------------------------------------------------------------------
	component ila
	port (
		control	: in	std_logic_vector(35 downto 0);
		clk		: in	std_logic;
		trig0	: in	std_logic_vector(51 downto 0);
		trig1	: in	std_logic_vector(34 downto 0);
		trig2	: in	std_logic_vector(39 downto 0)
	);
	end component;
	-------------------------------------------------------------------
	--
	--	ICON core component declaration
	--
	-------------------------------------------------------------------
	component icon
	port (
		control0	: inout std_logic_vector(35 downto 0)
	);
	end component;

	-------------------------------------------------------------------
	--
	--	ILA core signal declarations
	--
	-------------------------------------------------------------------
	signal control	: std_logic_vector(35 downto 0);
	signal clk		: std_logic;
	signal trig0	: std_logic_vector(51 downto 0);	-- dpr_seq
	signal trig1	: std_logic_vector(34 downto 0);	-- tx_rx
	signal trig2	: std_logic_vector(39 downto 0);	-- top
begin
	-- rx synchronisation ------------------------------------------------------
	rx_sync : process(i_Clk)
	begin
		if rising_edge(i_Clk) then 
			ni_RX1 <= ni_RX; 
		    ni_RX2 <= ni_RX1;
		end if;
	end process rx_sync;
	
	-- mster and slave ---------------------------------------------------------
	MasterSlave <= i_MasterSlave;
	o_TX <= TX when MasterSlave=L else l_TX;
	no_LinkLED <= n_LinkLED when MasterSlave=L else not(l_LEDrec);
	no_PowerLED <= not(IMPCmpEn) when MasterSlave=L else L;
	o_wdog <= WDog;
	-- dpr
	o_dprRst <= i_Rst;
	o_dprClk <= i_Clk;
	o_dprWEN <= dprWEN;
	o_dprEN <= dprEN;
	o_dprAddr <= dprAddr when MasterSlave=L else L & l_dprAdr(10 downto 1);
	o_dprData <= o_dprD_s when MasterSlave=L else o_dprD_m;
	
	o_TP1 <= sRErr when MasterSlave=L else l_Error;
	o_TP2 <= sRQq when MasterSlave=L else RErr;
	o_TP3 <= sRXq when MasterSlave=L else RXr;
	o_TP4 <= sLiErr when MasterSlave=L else RNr;

	-- slave -------------------------------------------------------------------
	CardTyp <= i_CardTyp;
	CmpEn(11 downto 0) <= "000000000000";		-- compare : nothing
	Low <= L;
	High <= H;
	RX <= ni_RX2 and not(MasterSlave);
	n_LinkLED <= not(l_LinkLED or com_LinkLED) or WDog;
	AddrSwitch <= i_AddrSwitch;
	o_Int0 <= INT0;
	o_Int1 <= INT1;
	o_Int4 <= INT4;
	o_Int4_Typ <= INT4_Typ;

	CIRQ0 <= (i_CIRQ0);
	CIRQ1 <= (i_CIRQ1);
	IMPCmpEn <= i_IMPCmpEn;
	o_TrOK <= TrOK;

	-- master ------------------------------------------------------------------
	
	o_JobIRQ <= l_JobIRQ;
	o_CIRQ <= l_CIRQ;
	o_Error <= l_Error;
	o_Ovrun <= l_Ovrun;
	o_Or1ms <= l_Or1ms;
	l_Reg_IOP(4) <= i_Diag_ON;		-- err_led
	l_Reg_IOP(5) <= i_Diag_invers;	-- ok_led
	-- write
	o_dprD_m(31 downto 16) <= x"0000" when dpr_WHB_req=H else l_Rx_Dat;
	o_dprD_m(15 downto 0) <= x"0000" when dpr_WHB_req=H else l_Rx_Dat;
	--read
	dprDinp <= i_dprData(15 downto 0) when l_dprAdr(0)=H else i_dprData(31 downto 16);
	-- invers inputs
	i_RX <= not(ni_RX2) and MasterSlave;
	l_ILM_IRQ <= (l_Or1ms or l_CIRQ or l_JobIRQ);
	o_ILM_IRQ <= l_ILM_IRQ;

	dpr : process(i_Clk, i_Rst)
	begin
		if (i_Rst = H) then
			dprEN <= L;
			state_s <= idle_s;
			state_m <= idle_m;
			INT0 <= L;
			INT1 <= L;
			INT4 <= L;
			INT4_Typ <= (others => L);
			CardOk <= L;
			CardIrq <= H;
			CIrqUnasked <= L;
			do_write <= L;
			shift <= H;
			InfoCom <= L;
--			o_NewData <= L;
--			save_status <= L;
			-- for simulink
			dprAddr <= (others => L);
		elsif rising_edge(i_Clk) then
			dprWEN <= (others => L);
			o_dprD_s <= (others => L);
			dprEN <= L;
			dpr_done <= L;
			INT0 <= L;
			INT1 <= L;
			INT4 <= L;
			INT4_Typ <= (others => L);
--			o_NewData <= L;
			if (MasterSlave=L) then -- slave -----------------------------------
				if (BitClk=H) then
					-- shiftregister
					Reg(Reg'left downto 1)<= Reg(Reg'left-1 downto 0);
					Reg(0) <= RXd;
					TXData <= Reg(Reg'left);
				end if;
				case state_s is
				  when idle_s =>
					if (TrOK=H and do_write=H) then		-- write to dpr
						-- 32Bit:
						-- Reg(31..0)	= D(31..0)
						-- Reg(32)		= RXStatus0
						-- Reg(33)		= RXStatus1
						-- 16Bit:
						-- Reg(31..0)	= T(3..0),A(7..0),S(3..0),D(15..0)
						if (InfoCom=H) then
							INT0 <= Addr7 and not(MCOk) and RXStatus0;-- Reg(32);
							INT1 <= Addr7 and not(MCOk) and RXStatus1;-- Reg(33);
						end if;
						INT4 <= INT4_reg;
						INT4_Typ <=INT4_Typ_reg;
						dprAddr(10) <= H;		-- r/!w
						o_dprD_s <= Reg(32 downto 1);
						dprWEN <= "1111";
						dprEN <= H;
						state_s <= write_s;
					end if;
					if (cAddr0=H) then
						-- Reg(10..8)	= TYP(2..0)
						-- Reg(7..0)	= InfoAddr(7..0)
						CIrqUnasked <= L;	--reset le 30.4.04
						CardIrq <= H; --reset le 30.4.04
						CardOk <= L;
						InfoCom <= L;
						InfoComConf <= L;
						INT4_reg <= L;
						INT4_Typ_reg <= (others => L);
						Addr7 <= Reg(7);
						if (B32=L) then			-- 16 bit jobs
							if ((Reg(10)=L or C_HIGH_TYPE_SUP/=0) and IMPCmpEn=H) then
								-- 16 bit jobs typ 1..3 read from dpr for compare
								if (Reg(9 downto 8)="00") then
									-- 0er jobs
									if (Reg(7)=AddrSwitch(3)) then
										-- only 128 compares
										dprAddr <= "0000" & Reg(6 downto 0);
										dprEN <= H;
										state_s <= preread_s;
									end if;
								else
									dprAddr <= L & Reg(9 downto 0);
									dprEN <= H;
									state_s <= preread_s;
								end if;
							end if;
						else					-- 32 bit jobs
							if (C_CONF_INCO/=1 and Reg(10 downto 8)=CardTyp and Reg(6 downto 0)=AddrSwitch(6 downto 0)) then	-- 1. priority: fix com.
								-- fix 32 bit communication jop
								CardOk <= H;	-- cMCok is to late!
								InfoCom <= H;
							elsif (C_CONF_INCO/=0 and Reg(10)=L and IMPCmpEn=H) then											-- 2. priority: configurable com.
								-- configurable 32 bit communication jop
								InfoComConf <= H;
								if (Reg(9 downto 8)="00") then
									-- 0er jobs
									if (Reg(7)=H) then -- only AddrSw(7)=H com-jobs
										-- only 128 compares
										dprAddr <= "0000" & Reg(6 downto 0);
										dprEN <= H;
										state_s <= preread_s;
									end if;
								else
									dprAddr <= L & Reg(9 downto 0);
									dprEN <= H;
									state_s <= preread_s;
								end if;
							elsif (C_32BITJOBS=1 and IMPCmpEn=H) then
								-- 32 bit jobs addr (addr-sw*16..(addr-sw+1)*16-1) read from dpr for compare
								dprAddr <= "000100" & Reg(3 downto 0) & L;
								dprEN <= H;
								state_s <= preread_s;
								-- save type and address(is later overwritten by tx data)
								saved_32Addr(15 downto 4) <= Reg(11 downto 0);
							end if;
						end if;
					end if;
					if (cMCok=H) then					-- read from dpr for imp com.
						-- Reg(11..9)	= TYP(2..0)
						-- Reg(8..1)	= InfoAddr(7..0)
						if (InfoCom=H) then
							dprAddr <= (others => '1');
							dprAddr(0) <= MCok;
							dprAddr(1) <= Addr7;
							dprAddr(8) <= L;
							dprAddr(9) <= L;
							dprAddr(10) <= L;	-- r/!w
							dprEN <= H;
							state_s <= preread_s;
						end if;
					end if;
					if (C_32BITJOBS=1 and cSave32addr=H) then	-- save 32bit-jop addr
						-- save cardok, cardirq, status1 and status0
						saved_32Addr(3 downto 0) <= Reg(3 downto 0);
					end if;
				when preread_s =>
					state_s <= read_s;
					if (C_32BITJOBS=1 and B32=H and InfoCom=L and (InfoComConf=L or C_CONF_INCO=0)) then
						dprAddr(0) <= H;
						dprEN <= H;
					end if;
				when read_s =>
					state_s <= idle_s;
					if (InfoCom=H) then	-- info communication
						com_LinkLED <= LinkLED;
						-- Reg(8)	= InfoAddr(7)
						if (Addr7=L) then
							CardIrq <= CIRQ0;
						else
							CardIrq <= CIRQ1;
						end if;
						TXStatus0 <= L;
						Reg(32 downto 1) <= i_dprData;
						do_write <= H;
					else				-- dpr compare
						if (C_32BITJOBS=1 and B32=H and (InfoComConf=L or C_CONF_INCO=0)) then -- 32 bit jobs
							--if Reg(10 downto 8)=i_dprData(30 downto 28) and (i_dprData(31)=H) then
							if Reg(10 downto 4)=i_dprData(30 downto 24) and (i_dprData(31)=H) then
								l_LinkLED<= LinkLED;
								do_write <= H;
								CIrqUnasked <= i_dprData(16);		-- card int.
								INT4_reg <= i_dprData(17);				-- int4
								if (C_TYPE_IRQ4=1) then
									INT4_Typ_reg(4) <= i_dprData(17);
								end if;
								CardOk <= not(i_dprData(19));		-- spy bit
								--save_status <= i_dprData(26);
								-- status bits
								TXStatus0 <= i_dprData(20);		-- status0
								TXStatus1 <= i_dprData(21);		-- status1
								-- diagnostic (only status1 supported)
								-- 10 Status1 the most
								if (i_dprData(23)=H and i_dprData(22)=L) then--sta1
									TXStatus1 <= LinkLED;		-- diagnostic
								end if;
								state_s <= read32_s;
							end if;
						else
							if (InfoComConf=L or C_CONF_INCO=0) then
								if ((i_dprData(31)=H and C_HIGH_TYPE_SUP=0) or (i_dprData(31)=H and C_HIGH_TYPE_SUP/=0 and Reg(10)=i_dprData(24))) then
									l_LinkLED<= LinkLED;
									do_write <= H;
									CIrqUnasked <= i_dprData(16);		-- card int.
									INT4_reg <= i_dprData(17);				-- int4
									if (C_TYPE_IRQ4=1) then
										if (Reg(9 downto 8) = 0) then
											INT4_Typ_reg(0) <= i_dprData(17);
										elsif (Reg(9 downto 8) = 1) then
											INT4_Typ_reg(1) <= i_dprData(17);
										elsif (Reg(9 downto 8) = 2) then
											INT4_Typ_reg(2) <= i_dprData(17);
										elsif (Reg(9 downto 8) = 3) then
											INT4_Typ_reg(3) <= i_dprData(17);
										end if;
									end if;
									CardOk <= not(i_dprData(19));		-- spy bit
									-- status bits
									TXStatus0 <= i_dprData(20);	-- status0
									TXStatus1 <= i_dprData(21);	-- status1
									-- diagnostic
									-- 10 Status1	the most
									-- 11 bit 3		SAC
									-- 01 bit 0		4KP
									-- 00 no		the rest
									if (i_dprData(23)=H and i_dprData(22)=H) then--bit3
										Reg(31 downto 20) <= i_dprData(15 downto 4);
										Reg(19) <= LinkLED;			-- diagnostic
										Reg(18 downto 16) <= i_dprData(2 downto 0);
									elsif (i_dprData(23)=L and i_dprData(22)=H) then--bit0
										Reg(31 downto 17) <= i_dprData(15 downto 1);
										Reg(16) <= LinkLED;			-- diagnostic
									elsif (i_dprData(23)=H and i_dprData(22)=L) then--sta1
										TXStatus1 <= LinkLED;		-- diagnostic
										Reg(31 downto 16) <= i_dprData(15 downto 0);
									else
										Reg(31 downto 16) <= i_dprData(15 downto 0);
									end if;
									-- 4kpr out1 support
									if (i_dprData(25)=H and C_SAC_SUP=1) then	-- sac!
										if (dprAddr(2)=H) then
											INT4_reg <= L;			-- suppress int4
											INT4_Typ_reg <= (others => L);
											dprAddr(2) <= L;	-- change bit and repeat..
											dprEN <= H;
											state_s <= preread_s;
										end if;
									end if;
								end if;
							else
								if (i_dprData(31)=H) then
									Addr7 <= i_dprData(28);
									InfoCom <= i_dprData(29);
									CardOk <= i_dprData(29);
								elsif (C_32BITJOBS=1) then
									-- 32 bit jobs addr (addr-sw*16..(addr-sw+1)*16-1) read from dpr for compare
									dprAddr <= "000100" & Reg(3 downto 0) & L;
									dprEN <= H;
									state_s <= preread_s;
									-- save type and address(is later overwritten by tx data)
									saved_32Addr(15 downto 4) <= Reg(11 downto 0);
								end if;
							end if;
						end if;
					end if;
				when read32_s =>
					Reg(31 downto 0) <= i_dprData(31 downto 0);
					state_s <= idle_s;
				when write_s =>
					do_write <= L;
					CardOk <= L;
					InfoCom <= L;
					state_s <= idle_s;
					if (C_32BITJOBS=1 and B32=H and InfoCom=L) then
						dprAddr(0) <= L;
						o_dprD_s(31 downto 16) <= saved_32Addr;
						dprWEN <= "1111";
						dprEN <= H;
						state_s <= idle_s;
					end if;
				end case;
			else --Master ------------------------------------------------------
				case state_m is
				  when idle_m =>
					if (dpr_W16_req=H or dpr_WHB_req=H) then	-- write to dpr
						if (l_dprAdr(0)=H) then
							dprWEN(0) <= dpr_W16_req;
							dprWEN(1) <= H;
						else
							dprWEN(2) <= dpr_W16_req;
							dprWEN(3) <= H;
						end if;
						dprEN <= H;
						dpr_done <= H;
						state_m <= write_m;
					elsif (dpr_R16_req=H) then				-- read from dpr
						dprEN <= H;
						state_m <= preread_m;
					end if;
				when preread_m =>
					state_m <= read_m;
					dpr_done <= H;
				when read_m =>
					state_m <= idle_m;
				when write_m =>
					state_m <= idle_m;
				end case;
			end if;
		end if;
	end process;

	-- WatchDog ----------------------------------------------------------------
	--i_WDOG_TIME = 00 => 1117.090909   WDcnt = 0x6000
	--i_WDOG_TIME = 01 => 2234.181818   WDcnt = 0xc000
	--i_WDOG_TIME = 10 => 4468.363636   WDcnt = 0x18000
	--i_WDOG_TIME = 11 => 8936.727273   WDcnt = 0x30000
	lassie : process (i_Clk, i_Rst) begin
		if (i_Rst = H) then								-- reset values
			WDcnt <= (others => '0');
			WDog <= L;
		elsif rising_edge(i_Clk) then
			if (i_WDOG_TIME="00" and WDcnt(14 downto 13)="11") then
				WDog <= H;
			elsif (i_WDOG_TIME="01" and WDcnt(15 downto 14)="11") then
				WDog <= H;
			elsif (i_WDOG_TIME="10" and WDcnt(16 downto 15)="11") then
				WDog <= H;
			elsif (i_WDOG_TIME="11" and WDcnt(17 downto 16)="11") then
				WDog <= H;
			else
				WDog <= L;
			end if;
			if ((TrOk=H and CardOk=H and MasterSlave=L)	-- reset WDcnt slave
			 or (l_WDOGout=H and MasterSlave=H)) then	-- reset WDcnt master
				WDcnt <= (others => '0');
			elsif (WDog = L) then							-- count until Wdog
				if cnt22=C_CLK_DIV_22MHZ-1 then
					WDcnt <= WDcnt+1;
					cnt22 <= (others => '0');
				else
					cnt22 <= cnt22 + 1;
				end if;
			end if;
		end if;
	end process;
	l_WDOGin <= WDog;
	----------------------------------------------------------------------------
	-- components mapping ------------------------------------------------------
	ilseq1: info_link_seq
	generic map(
		C_CLK_DIV_22MHZ => C_CLK_DIV_22MHZ
	)
	PORT MAP(
		-- std-ports
		i_Clk		=> i_Clk,
		i_Rst		=> i_Rst,		-- high-activ
		-- outputs
		o_Irq		=> open,		-- IRQ-bit
		o_diagnosis	=> open,		-- diagnosis-bit
		o_blinki	=> o_blinki,	-- blink bit
		o_32bit		=> B32,
		o_Typ2		=> open,
		o_Typ1		=> open,
		o_Typ0		=> open,
		o_Addr7		=> open,
		o_Addr6		=> open,
		o_Addr5		=> open,
		o_Addr4		=> open,
		o_Addr3		=> open,
		o_Addr2		=> open,
		o_Addr1		=> open,
		o_Addr0		=> open,
		o_MCok		=> MCOk,
		o_CIrqEn	=> open,
		o_Status1	=> RXStatus1,	-- status-bit
		o_Status0	=> RXStatus0,	-- status-bit
		o_Data		=> RXData,
		-- clocks
		o_BitClk	=> BitClk,		-- master-clk
		o_cDiagnosis=> cDiagnosis,
		o_cAddr0	=> cAddr0,
		o_cMCok		=> cMCok,
		o_cReadH	=> open,
		o_cData16	=> open,--cSave32addr,
		o_cS35		=> open,
		o_cS37		=> open,
		o_cS52		=> open,
		o_cStatus1	=> open,
		o_cStatus0	=> cSave32addr,--open,
		o_cData		=> open,
		o_cDataEnd	=> cDataEnd,

		i_diagnosis	=> High,		-- if H => diagnosticable
		i_CardOk	=> CardOk,		-- if H => CardOk = H
		i_CardIrq	=> CardIrq,		-- if H => CIRQ = rx
		i_CIrqUnasked => CIrqUnasked,-- if H => CIRQ = H
		i_Status1	=> TXStatus1,	-- status-bit or diagnostic
		i_Status0	=> TXStatus0,	-- status bit
		i_Data		=> TXData,		-- TX-Data
		i_Err		=> Low,			-- if H => reset BitCnt
		-- Eeprom ----------------
		i_EEPROMen	=> Low,			-- no EEPROM
		o_EEen		=> open,		-- EEPROM Chipselect
		o_EEclk		=> open,		-- EEPROM Clock
		o_EEd		=> open,		-- EEPROM Data Out
		i_EEd		=> Low,			-- EEPROM Data In
		-- LEDs
		o_LinkLED	=> LinkLED,		-- high-activ (H=light)
		o_PowerLED	=> open,		-- high-activ (H=light)
		-- CardTyp def.
		i_32not16	=> B32,			-- protocol length L
		i_CardTyp	=> CardTyp,		-- card typ nr.:	TTT
		i_AddrSwitch=> AddrSwitch,	-- addresbits		AAAAAAAA
		i_CmpEn		=> CmpEn,		-- H => compare, L not compare
									--					TTTTAAAAAAAA
		-- link
		i_RX		=> RX,
		o_TX		=> TX,
		o_RErr		=> sRErr,
		o_RQq		=> sRQq,
		o_RXq		=> sRXq,
		o_LiErr		=> sLiErr,


		o_RXd		=> RXd,
		o_TrOK		=> TrOK
	);
	--o_TP2 <= cDiagnosis;
	----------------------------------------------------------------------------
	--	Module	TxRx Sequencer
	----------------------------------------------------------------------------
	TxRx: InfoLink_TxRx PORT MAP (
		i_Q66		=> i_Clk,
		i_Reset		=> i_Rst,
		i_Tx_Dat	=> dprDinp,
		i_WDOGin	=> l_WDOGin,
		i_RX		=> i_RX,
		i_Reg_Sta	=> i_Master_Ctrl,
		i_Reg_IOP	=> l_Reg_IOP,
		i_Tgo_en	=> l_Tgo_en,
		i_Trst		=> l_Trst,
		i_Tack		=> l_Tack,
		i_Rack		=> l_Rack,
		o_Rx_Dat	=> l_Rx_Dat,
		o_LEDrec	=> l_LEDrec,
		o_WDOGout	=> l_WDOGout,
		o_CIRQ		=> l_CIRQ,
		o_Or1ms		=> l_Or1ms,
		o_TX		=> l_TX,
		o_Error		=> l_Error,
		o_Ovrun		=> l_Ovrun,
		o_RUN		=> l_RUN,
		o_ReSt		=> l_ReSt,
		o_Treq		=> l_Treq,
		o_Rreq		=> l_Rreq,
		dbg_o_RErr	=> RErr,
		dbg_o_RXr	=> RXr,
		dbg_o_RNr	=> RNr
	);
	----------------------------------------------------------------------------
	--	Module	Dualport Ram Sequencer
	----------------------------------------------------------------------------
	DprSeq: InfoLink_DprSeq
	Generic Map (
		C_SpezJob_Implemented => C_SpezJob_Implemented_bool
	)
	PORT MAP (
		i_Q66		=> i_Clk,
		i_Reset		=> i_Rst,
	---	Dualport Ram -----------------------------------------------------------
		o_dprAdr	=> l_dprAdr,
		i_dprDat	=> dprDinp,
		o_dpr_R16_req => dpr_R16_req,
		o_dpr_WHB_req => dpr_WHB_req,
		o_dpr_W16_req => dpr_W16_req,
		i_dpr_done	=> dpr_done,
	--- Sequenzer ctrl ---------------------------------------------------------
		i_RUN		=> l_RUN,
		i_ReSt		=> l_ReSt,
		i_Reg_Sta	=> i_Master_Ctrl,
		o_Tgo_en	=> l_Tgo_en,
		o_Trst		=> l_Trst,
	--- Transmit Data Request --------------------------------------------------
		i_Treq		=> l_Treq,
		o_Tack		=> l_Tack,
	--- Receiver Shift Register ------------------------------------------------
		i_Rreq		=> l_Rreq,
		o_Rack		=> l_Rack,
		i_saveIRQ	=> l_Rx_Dat(2),
		o_JobIRQ	=> l_JobIRQ
	);
-- chipscope includes ----------------------------------------------------------
cs_imp0: if (C_ChipScope_Implemented=1) generate
begin
	trig0(10 downto 0) <= l_dprAdr;
	trig0(26 downto 11) <= dprDinp;
	trig0(27) <= dpr_R16_req;
	trig0(28) <= dpr_WHB_req;
	trig0(29) <= dpr_W16_req;
	trig0(30) <= dpr_done;
	trig0(31) <= l_RUN;
	trig0(32) <= l_ReSt;
	trig0(40 downto 33) <= i_Master_Ctrl;
	trig0(41) <= l_Tgo_en;
	trig0(42) <= l_Trst;
	trig0(44 downto 43) <= l_Treq;
	trig0(45) <= l_Tack;
	trig0(47 downto 46) <= l_Rreq;
	trig0(48) <= l_Rack;
	trig0(49) <= l_JobIRQ;
	trig0(50) <= l_Rx_Dat(2);	-- i_saveIRQ
	trig0(51) <= L;
end generate cs_imp0;
cs_imp1: if (C_ChipScope_Implemented=1) generate
begin
	trig1(0) <= l_TX;
	trig1(1) <= i_RX;
	trig1(9 downto 2) <= l_Reg_IOP;
	trig1(25 downto 10) <= l_Rx_Dat;
	trig1(26) <= l_LEDrec;
	trig1(27) <= l_WDOGout;
	trig1(28) <= l_WDOGin;
	trig1(29) <= l_CIRQ;
	trig1(30) <= l_Or1ms ;
	trig1(31) <= l_Error ;
	trig1(32) <= l_Ovrun;
	trig1(34 downto 33) <= "00";
end generate cs_imp1;
cs_imp2: if (C_ChipScope_Implemented=1) generate
begin
	trig2(10 downto 0) <= dprAddr when MasterSlave=L else i_dbg_in(10 downto 0);
	trig2(14 downto 11) <= dprWEN;
	trig2(15) <= dprEN;
	trig2(16) <= i_Rst;
	trig2(17) <= l_ILM_IRQ;
	trig2(18) <= TX when MasterSlave=L else l_TX;
	trig2(19) <= ni_RX2;
	trig2(20) <= MasterSlave;
	trig2(21) <= INT0;
	trig2(22) <= INT1;
	trig2(23) <= INT4;
	trig2(24) <= (i_CIRQ0);
	trig2(25) <= (i_CIRQ1);
	trig2(26) <= i_IMPCmpEn;
	trig2(27) <= RErr;--i_Spy0;
	trig2(28) <= RXr;--i_Spy1;
	trig2(29) <= RNr;--i_Spy2;
	trig2(30) <= i_Spy3;
	trig2(31) <= i_Spy4;
	trig2(32) <= i_Spy5;
	trig2(33) <= i_Spy6;
	trig2(34) <= i_Spy7;
	trig2(39 downto 35) <= i_dbg_in(15 downto 11);
end generate cs_imp2;
------------------------
cs_imp_inst: if (C_ChipScope_Implemented=1) generate
begin
	----------------------------------------------------------------------------
	--
	--	ILA core instance
	--
	----------------------------------------------------------------------------
	i_ila : ila
	port map
	(
		control	=> control,
		clk		=> i_Clk,
		trig0	=> trig0,
		trig1	=> trig1,
		trig2	=> trig2
	);
	----------------------------------------------------------------------------
	--
	--	ICON core instance
	--
	----------------------------------------------------------------------------
	i_icon : icon
	port map
	(
		control0	=> control
	);
end generate cs_imp_inst;
--------------------------------------------------------------------------------
end Behavioral;
