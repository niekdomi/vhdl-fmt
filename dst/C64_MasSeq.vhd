---------------------------------------------------------------------------
--
--  C64 BusMaster Sequencer
--
---------------------------------------------------------------------------
--
--  project	 : C64_BusMaster
--  programmer  : F:Baschung, INDEL AG
--  date		: 23.06.2010
--  version	 : 1.00
--  language	: VHDL
--  system	  : Project Navigator
--
--  purpose
--  	- C64 BusMaster
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--
--	TimerMax before TabEnd error
--
--	ev 32Bit Transfers
--
--	any buss-error dedections
--	Master Ack-Inp error
--	Error-counters
--
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	23.06.2010-FB	erste Version
--	18.05.2011-le : - add svn keywords
--	28.07.2011-le : - split sda to input and output
--	13.02.2012-FB : - 64_Master wait-timer hänger beseitigt
--	25.11.2012-FB	new g_NO_SPI,g_NO_JTAG,g_NO_EEPROM to reduce LUTs for ActMaster
--	28.12.2012-FB	added new second-port for 8kByte ThreePort-RAM version
--	14.02.2012-FB	SynchPg nur noch 0..7 (bit 22 downto 20)
-- 					(SW toggelt WdogTgl falsch auf Bit23 statt Bit25) 
--	19.08.2013.FB	GinLink-TlgTime and AutoSoftSynch added
--	15.01.2014-le	- add outputs o_C64_CLK_fe and o_C64_CLK_re to support 50/50 clk with ddr output ffs
--	20.03.2014-stn	- added generics to patch i2c eeprom address
--					  (reference project gin-ttl_oct)
--	16.05.2014-le	- 8k/3portram: adjustments ans support for cop-mas2
--	03.07.2014-le	- CyCnt and WtErrCnt: do not increment ramdata to impruve timing
--	31.07.2014-qf	- sync can now take place based on TlgIrq, too when: the "sWTimer"
--					  state is active and "C64Clk_Seq = s3" -> faster sync.
--	18.08.2014-le	- add a ff to detect new cmd at Cfg_EEP_Job and reread cmd
--					  to prevent metastability
--	09.06.2015-le	- remove dbg output on (disabled) C64_WrDat in wsBusRdDat10.
--					  output enable seems to be very slow and the data go to outputs.
--	11.06.2015-le	- remove unsupported byte write and add cmd_C64_WR_BC for broadcast write.
--	29.06.2015-le	- add ports and generics for crc check
--	09.02.2017-le	- add new command for jumping to a subtabel
--	09.02.2017-le	- add i_8k3p_Enable to enable/disable 3port and 8k feature (rev>=0x210).
--	24.02.2017-le	- disable EJS_ACCESS_SW and GIN_OR_EN when i_8k3p_Enable=L
--	13.04.2017-le	- add clr_cnt to relax the timing a bit
--	25.06.2019-le:	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--	12.06.2020-vz	- add handshake signal to/from C64_EEPROMER to share i2c bus with another i2c master
--					  used in cv_sodimm_max4x10 
--------------------------------------------------------------------------------
--$Rev:: 5552                  $
--$Author:: Zuellig                     $
--$Date:: 2020-06-15 13:15:49 +0200 (Mo., 15 Jun 2020)       $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY C64_Master;
USE C64_Master.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity C64_MasSeq is
	generic (
		g_Extern_Q25	: in 	natural range 0 to 1 := 0;
		-- wird nur für 3-Port RAM benötigt
		g_TwoPort_OR	: in	natural range 0 to 1 := 0;
		-- GinLink Auto-Soft-Synch		(default 1, für weniger Recourcen 0)
		g_GL_ASoSy		: in 	natural range 0 to 1 := 1;
		-- show GinLink-TlgTime			(default 1, für weniger Recourcen 0) 
		g_GL_TlgTime	: in 	natural range 0 to 1 := 1;
        -- disable unused devices		(default 0, für weniger Recourcen 1)
		g_NO_SPI		: in 	natural range 0 to 1 := 0;
		g_NO_JTAG		: in 	natural range 0 to 1 := 0;
		g_NO_EEPROM		: in 	natural range 0 to 1 := 0;
		-- patch to change eeprom address 
		g_patch_ee_addr	: in	integer range 0 to 1 := 0;
		g_patch_addr_f	: in	std_logic_vector(3 downto 0) := x"0"; -- from
		g_patch_addr_t	: in	std_logic_vector(3 downto 0) := x"0"; -- to
		g_CRCChecker	: in integer range 0 to 1 := 0;
		g_HIDE_JUMP_CMD	: in integer range 0 to 1 := 1;
		g_SELECTnOR_MEM : in integer range 0 to 1 := 0;
		g_MEM_RdD_REG : in integer range 0 to 1 := 0
	);
	port (
		i_Q125			: in 	std_logic;
		i_Q25			: in 	std_logic := '0';
		i_TlgIrq		: in 	std_logic_vector( 7 downto 0) := x"00";
		o_PgIRQs		: out 	std_logic_vector( 7 downto 0) := x"00";
		-- pause GinLink Auto-Soft-Synch
		i_GinLink_Wdog	: in	std_logic := '0';

		-- Gin-Slave Ram
		i_MEM_RdData	: in 	std_logic_vector(31 downto 0);
		o_MEM_WrData	: out	std_logic_vector(31 downto 0);
		o_MEM_ByteAddr	: out	std_logic_vector(15 downto 0);
		o_MEM_WR		: out	std_logic_vector( 3 downto 0);
		o_MEM_EN		: out	std_logic;		-- select while EEP,SPI,JTG-Acces

		o_SP_EN			: out	std_logic;		-- select while EEP,SPI,JTG-Acces
		i_SP_RdData		: in 	std_logic_vector(31 downto 0) := (others => '0');

		-- C64-Bus
		o_C64_Reset		: out	std_logic := '1';
		o_C64_CLK		: out	std_logic;
		o_C64_CLK_fe	: out	std_logic; -- clock output for ddr falling edge
		o_C64_CLK_re	: out	std_logic; -- clock output for ddr rising edge
		o_C64_CLK_EN	: out 	std_logic;
		o_C64_SEL		: out	std_logic;
		o_C64_RES		: out	std_logic;
		o_C64_Bend		: out	std_logic;
		o_C64_Dat_HOE	: out	std_logic;
		o_C64_Dat_LOE	: out	std_logic;
		o_C64_Ack_OE	: out	std_logic;
		o_C64_WrDat		: out	std_logic_vector(15 downto 0);
		i_C64_RdDat		: in 	std_logic_vector(15 downto 0);
		i_C64_Ack_Ext	: in 	std_logic;
		i_C64_Ack_Int	: in 	std_logic;

		o_C64_I2C_SCL	: out	std_logic;
		o_C64_I2C_SDA	: out	std_logic;
		i_C64_I2C_SDA	: in	std_logic;

		o_C96_I2C_SCL	: out	std_logic;
		o_C96_I2C_SDA	: out	std_logic;
		i_C96_I2C_SDA	: in	std_logic;
		i_eep_i2c_acpt	: in	std_logic := H;
		o_eep_i2c_req	: out	std_logic;
		
		o_OverRun		: out	std_logic;
		i_8k3p_Enable	: in	std_logic := conv_std_logic_vector(g_TwoPort_OR,1)(0);
		-- dbg job logger
		o_log_addr : out std_logic_vector(9 downto 0);
		o_logout : out std_logic_vector(31 downto 0);
		o_log_en : out std_logic
	);
end;

architecture impl of C64_MasSeq is
--------------------------------------------------------------------------------
--	DP-Ram Memory	0X2000-Bytes = 8kByte total
--------------------------------------------------------------------------------
	constant Cfg_EEP080		: std_logic_vector(15 downto 0) := x"0080";

	-- 0x80000000 = INIT-DONE (EEPROM readed)
	constant Cfg_INTI_DONE	: std_logic_vector(15 downto 0) := x"0184";

	-- 0x80000C35 = timer active, 8kHz (+40ns)
	-- --> TelSyn(0) will do the 8kHz master-synch
	constant Cfg_TimMax		: std_logic_vector(15 downto 0) := x"0300";
	constant Cfg_ErrNACK	: std_logic_vector(15 downto 0) := x"0304";
	constant Cfg_WtErrCnt	: std_logic_vector(15 downto 0) := x"0308";
	constant Cfg_CyCnt		: std_logic_vector(15 downto 0) := x"030C";

	constant Cfg_GinTlgTim	: std_logic_vector(15 downto 0) := x"0310";
	constant Cfg_Test		: std_logic_vector(15 downto 0) := x"0314";

	constant Cfg_EEP_Desc	: std_logic_vector(15 downto 0) := x"0318";
	constant Cfg_EEP_Job	: std_logic_vector(15 downto 0) := x"031C";

	constant Cfg_JTG_Desc	: std_logic_vector(15 downto 0) := x"0318";
	constant Cfg_JTG_Job	: std_logic_vector(15 downto 0) := x"031C";

	constant Cfg_SPI_Desc	: std_logic_vector(15 downto 0) := x"0318";
	constant Cfg_SPI_Job	: std_logic_vector(15 downto 0) := x"031C";

	constant Cfg_CmdTab		: std_logic_vector(15 downto 0) := x"0320";
	constant Cfg_AdrTab		: std_logic_vector(15 downto 0) := x"0324";

--------------------------------------------------------------------------------
	-- EEPROMer/JTAGer commands
	constant cmd_EEP		: std_logic_vector(31 downto 0) := x"10000000";
	constant cmd_EEP_Rd		: std_logic_vector(31 downto 0) := x"11000000";
	constant cmd_EEP_Wr		: std_logic_vector(31 downto 0) := x"12000000";
	constant cmd_EEP_Busy	: std_logic_vector(31 downto 0) := x"90000000";

	constant cmd_JTG		: std_logic_vector(31 downto 0) := x"20000000";
	constant cmd_JTG_Start	: std_logic_vector(31 downto 0) := x"21000000";
	constant cmd_JTG_Busy	: std_logic_vector(31 downto 0) := x"A0000000";

	constant cmd_SPI		: std_logic_vector(31 downto 0) := x"30000000";
	constant cmd_SPI_Start	: std_logic_vector(31 downto 0) := x"31000000";
	constant cmd_SPI_Busy	: std_logic_vector(31 downto 0) := x"B0000000";

	constant cmd_Mask		: std_logic_vector(31 downto 0) := x"3F000000";
	constant cmd_TMask		: std_logic_vector(31 downto 0) := x"70000000";

--------------------------------------------------------------------------------
--	C64-Command
--------------------------------------------------------------------------------
	constant cmd_C64_nop	: std_logic_vector := "0000";
	constant cmd_C64_JTAG	: std_logic_vector := "0001";
	constant cmd_C64_SPI	: std_logic_vector := "0010";
	constant cmd_C64_RD		: std_logic_vector := "0011";
	constant cmd_C64_JUMP	: std_logic_vector := "0100";
	constant cmd_C64_WR_BC	: std_logic_vector := "0101";
	constant cmd_C64_6		: std_logic_vector := "0110";
	constant cmd_C64_WR		: std_logic_vector := "0111";
--------------------------------------------------------------------------------
	type sCM_MasSeq is (
		-- die EndZiffern deuten auf den C64_ClockState s0..s4 hin
		-- also immer schön synchron bleiben !!
		sIdle,sIdle1,sIdle2,sIdle3,sIdle4,
		sStart,sWstart,
		sReStart0,sReStart1,sReStart2,sReStart3,sReStart4,
		sEEP_Access,
		sJTG_Access,
		sSPI_Access,
		sCLR_ESJ_CMD1,sCLR_ESJ_CMD2,
		sWTimer,
		sBusAdr0,sBusAdr1,sBusAdr2,sBusAdr3,sBusAdr4,
		sBusRdDat10,sBusRdDat11,sBusRdDat12,sBusRdDat13,sBusRdDat14,
		sBusWrDat0,sBusWrDat1,sBusWrDat2,sBusWrDat3,sBusWrDat4,
		sJump0,sJump1,sJump2,sJump3,sJump4,
		sEnd0,sEnd1,sEnd2,sEnd3,
		sWtErr0,sWtErr1
	);
	signal	CM_Seq: sCM_MasSeq := sIdle;								-- main sequencer
--attribute fsm_encoding : string;
--attribute fsm_encoding of CM_Seq : signal is "one-hot";

	signal	CM_CmdPoi		: std_logic_vector(11 downto 0) := x"000";		-- points to command
	signal	CM_NextCmd		: std_logic_vector(31 downto 0) := x"00000000";	-- next command
	signal	CM_NOC			: std_logic_vector( 7 downto 0) := x"00";		-- nr of bus-cycles
	signal	CM_EEEE			: std_logic						:= '0';			-- disable overrun counter

	signal	PgRxBuf_Tgl		: std_logic_vector( 2 downto 0) :=  "000";		-- RxBuf 0/1 Tgl selector
	signal	MEM_Adr			: std_logic_vector(15 downto 0) := x"0000";		-- act dp-ram Byte-Adr
	signal	MEM_Adr_1		: std_logic_vector(15 downto 0) := x"0000";		-- t-1 Byte-Adr
	signal	MEM_DatPoi		: std_logic_vector(15 downto 0) := x"0000";		-- points to Data
	signal	MEM_WrData		: std_logic_vector(31 downto 0) := x"00000000";	-- data to dp-ram
	signal	MEM_RdData		: std_logic_vector(31 downto 0) := x"00000000";	-- data from dp-ram
	signal	MEM_WR			: std_logic_vector( 3 downto 0) :=  "0000";		-- write
	signal	EJS_RdData		: std_logic_vector(31 downto 0) := x"00000000";	-- RdData to EEP,JTG,SPI
	signal	MEM_En			: std_logic						:= '1';
	signal	SP_En			: std_logic						:= '0';

----------	---------------------------------------------------------------------
	signal	Timer			: std_logic_vector(15 downto 0) := x"0000";
	signal	TimerCmd		: std_logic_vector(15 downto 0) := x"0000";
	signal	TimerMax		: std_logic_vector(15 downto 0) := x"0000";
	signal	SeqReset 		: std_logic						:= '1';			-- reset-flag
	signal	OvrCnt			: std_logic_vector( 3 downto 0) := x"0";		-- overrun counter
	signal	TimOutCnt		: std_logic_vector(15 downto 0) := x"0000";		-- timout counter
	signal	DisOvrCnt		: std_logic						:= '0';			-- disable overrun counter

	signal	EnSynCopMas		: std_logic						:= '0';			-- enable SyncCopMast to 64kHz-safety-cnt
	signal	SynchPage		: std_logic_vector( 2 downto 0) := "000";		-- page to synch
	signal	WachDog			: std_logic						:= '0';			-- toggle for WatchDog
	signal	WachDog_1		: std_logic						:= '0';			-- t-1, toggle for WatchDog
	signal	TlgIrq			: std_logic						:= '0';			-- synch puls
	-- for active-master ith local PPC
	signal	PgIRQ_Nr		: integer range 0 to 7			:= 0;			-- Page IRQ-Nr
	signal	PgIRQs			: std_logic_vector( 7 downto 0) := x"00";		-- IRQ to PPC
	--
	signal	EJS_ACCESS_SW	: std_logic						:= '0';			-- EJS-access switch
	signal	GIN_OR_EN		: std_logic						:= '0';			-- GinOg enable switch

    signal	GL_SoftSynch	: std_logic						:= '0';			-- GinLink SoftSynch (do not reset Cycle-Timer)
    signal	GL_ASoSy		: std_logic						:= '0';			-- GinLink AutoSoftSynch
	signal	GinTlg_Time		: std_logic_vector(15 downto 0) := x"0000";     -- Gin-Tlg Time
	signal	GinTlg_Cnt		: std_logic_vector(15 downto 0) := x"0000";     -- Gin-Tlg Counter
	
	signal SpecialCmd		: std_logic						:= L;

--------------------------------------------------------------------------------
	constant s0 			: std_logic_vector( 3 downto 0) := x"0";
	constant s1 			: std_logic_vector( 3 downto 0) := x"1";
	constant s2 			: std_logic_vector( 3 downto 0) := x"2";
	constant s3 			: std_logic_vector( 3 downto 0) := x"3";
	constant s4 			: std_logic_vector( 3 downto 0) := x"4";
	signal	Q12_5			: std_logic							:= '0';
	signal	Q12_5_1			: std_logic						:= '0';

	signal	C64Clk_Seq		: std_logic_vector( 3 downto 0) := x"0";
	signal	C64_CLK			: std_logic						:= '0';
	signal	C64_CLK_fe		: std_logic						:= '0';
	signal	C64_CLK_re		: std_logic						:= '0';
	signal	C64_SEL			: std_logic						:= '0';
	signal	C64_Bend		: std_logic							:= '0';
	signal	C64_Dat_HOE		: std_logic						:= '0';
	signal	C64_Dat_LOE		: std_logic						:= '0';
	signal	C64_Ack_OE		: std_logic						:= '0';
	signal	C64_WrDat		: std_logic_vector(15 downto 0) := x"0000";

--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	EEPROM loader
--------------------------------------------------------------------------------
	signal EEP_En			: std_logic						:= '0';
	signal EEP_Done			: std_logic						:= '0';
	signal EEP_MEM_WrData	: std_logic_vector(31 downto 0) := (others => '0');
	signal EEP_MEM_Adr		: std_logic_vector(15 downto 0) := (others => '0');
	signal EEP_MEM_WR		: std_logic_vector( 3 downto 0) := (others => '0');

--------------------------------------------------------------------------------
--	JTAG loader
--------------------------------------------------------------------------------
	signal JTG_En			: std_logic							:= '0';
	signal JTG_Done			: std_logic						:= '0';

	signal JTG_MEM_WrData	: std_logic_vector(31 downto 0) := (others => '0');
	signal JTG_MEM_Adr		: std_logic_vector(15 downto 0) := (others => '0');
	signal JTG_MEM_WR		: std_logic_vector( 3 downto 0) := (others => '0');

	signal JTG_C64_SEL		: std_logic						:= '0';
	signal JTG_C64_Bend		: std_logic						:= '0';
	signal JTG_C64_Dat_HOE	: std_logic						:= '0';
	signal JTG_C64_Dat_LOE	: std_logic						:= '0';
	signal JTG_C64_Ack_OE	: std_logic						:= '0';
	signal JTG_C64_WrDat	: std_logic_vector(15 downto 0)	:= (others => '0');
--	signal JTG_C64_RdDat	: std_logic_vector(15 downto 0);
--	signal JTG_C64_Ack		: std_logic;

--------------------------------------------------------------------------------
--	SPI loader
--------------------------------------------------------------------------------
	signal SPI_En			: std_logic							:= '0';
	signal SPI_Done			: std_logic						:= '0';

	signal SPI_MEM_WrData	: std_logic_vector(31 downto 0) := (others => '0');
	signal SPI_MEM_Adr		: std_logic_vector(15 downto 0) := (others => '0');
	signal SPI_MEM_WR		: std_logic_vector( 3 downto 0) := (others => '0');

	signal SPI_C64_SEL		: std_logic						:= '0';
	signal SPI_C64_Bend		: std_logic						:= '0';
	signal SPI_C64_Dat_HOE	: std_logic						:= '0';
	signal SPI_C64_Dat_LOE	: std_logic						:= '0';
	signal SPI_C64_Ack_OE	: std_logic						:= '0';
	signal SPI_C64_WrDat	: std_logic_vector(15 downto 0)	:= (others => '0');
--	signal SPI_C64_RdDat	: std_logic_vector(15 downto 0);
--	signal SPI_C64_Ack		: std_logic;
	signal CyCnt	: std_logic_vector(31 downto 0) := (others => '0');
	signal WtErrCnt	: std_logic_vector( 7 downto 0) := (others => '0');
	
	signal send_crc			: std_logic := '0';
	signal clr_crc			: std_logic := '0';
	signal crc_val			: std_logic_vector(15 downto 0);
	signal C64_Ack			: std_logic;
	signal C64_CLK_EN		: std_logic;

	signal SubTable : std_logic := L;
	signal jump_return : std_logic := L;
	signal retPoi : std_logic_vector(11 downto 0) := (others => L);
	signal CM_Cmd : std_logic_vector(3 downto 0) := (others => L);
	signal SubStartTime : std_logic_vector(14 downto 0) := (others => L);
	
	signal log_addr : std_logic_vector(9 downto 0) := (others => L);
	
	signal clr_cnt : std_logic := L;
	
	signal MEM_RdData_r : std_logic_vector(31 downto 0) := (others => L);
	signal SP_RdData_r : std_logic_vector(31 downto 0) := (others => L);
	
--------------------------------------------------------------------------------
begin -- of architecture CM_Seq
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	outputs --------------------------------------------------------------------
MEM_RdD_REG: if (g_MEM_RdD_REG = 1)  generate begin
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			MEM_RdData_r <= i_MEM_RdData;
			SP_RdData_r <= i_SP_RdData;
		end if;
	end process;
end generate MEM_RdD_REG;

MEM_RdD_nREG: if (g_MEM_RdD_REG = 0)  generate begin
	MEM_RdData_r <= i_MEM_RdData;
	SP_RdData_r <= i_SP_RdData;
end generate MEM_RdD_nREG;

	process (GIN_OR_EN,MEM_RdData_r,SP_RdData_r) begin
		if (GIN_OR_EN = H) then
			MEM_RdData <= MEM_RdData_r or SP_RdData_r after 10 ps;
		else
			MEM_RdData <= MEM_RdData_r after 10 ps;
		end if;
	end process;
	
	C64_Ack <= i_C64_Ack_Int or i_C64_Ack_Ext;
	o_C64_CLK_EN <= C64_CLK_EN;
OR_MEM: if (g_SELECTnOR_MEM = 0)  generate begin
	o_MEM_ByteAddr	<= MEM_Adr		or SPI_MEM_Adr		or JTG_MEM_Adr		or EEP_MEM_Adr		;
	o_MEM_WrData 	<= MEM_WrData	or SPI_MEM_WrData	or JTG_MEM_WrData	or EEP_MEM_WrData	;
	o_MEM_WR		<= MEM_WR 		or SPI_MEM_WR 		or JTG_MEM_WR 		or EEP_MEM_WR 		;
end generate OR_MEM;
SELECT_MEM: if (g_SELECTnOR_MEM = 1) generate begin
	o_MEM_ByteAddr	<= MEM_Adr		;
	o_MEM_WrData 	<= MEM_WrData	;
	o_MEM_WR		<= MEM_WR 		;
end generate SELECT_MEM;
	o_MEM_EN		<= MEM_EN;
	o_SP_EN			<= SP_EN;


	o_C64_CLK 		<= C64_CLK		;
	o_C64_CLK_fe 	<= C64_CLK_fe	;
	o_C64_CLK_re 	<= C64_CLK_re	;
	o_C64_SEL	   <= C64_SEL		;
	o_C64_Bend		<= C64_Bend		;
	o_C64_Dat_HOE	<= C64_Dat_HOE	after 4 ns;
	o_C64_Dat_LOE	<= C64_Dat_LOE	after 4 ns;
	o_C64_Ack_OE  	<= C64_Ack_OE	;
	o_C64_WrDat		<= C64_WrDat	;

	-- IRQ-0 not useful
	o_PgIRQs 		<= PgIRQs(7 downto 1) & L;

--	o_C64_RES <= 'Z';
	o_C64_RES <= SeqReset;

--******************************************************************************
--	C64 Clock Generator
--******************************************************************************
--	Der C64-Clock muss stetig laufen,
--		daher NIE einen Reset oder adere Synchs auf diese Signal !
--------------------------------------------------------------------------------
inst_ExtQ25: if (g_Extern_Q25 = 1) generate begin
	-- i_Q25 is the master clock
	C64_CLK <= i_Q25;
	

	process (i_Q25) begin
		if rising_edge(i_Q25) then
			-- just toggle to find extern-Q25 rising edge
			Q12_5 <= not Q12_5;
		end if;
	end process;

--	 			 s0s1s2s3s4s0
--	C64_CLK		_------____----
--	Q125		_-_-_-_-_-_-_-_-_-_
--	Q25			_-----_____-----_____-
--	Q12.5		_----------__________-
--	Q12_5_1		___----------__________-
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			-- VORSICHT: darf nie zurück gesetzt werden!
			case C64Clk_Seq is
			when s0 =>
				C64Clk_Seq <= s1;
				C64_CLK_EN <= L;
			when s1 =>
				C64Clk_Seq <= s2;
				C64_CLK_EN <= L;
			when s2 =>
				C64Clk_Seq <= s3;
				C64_CLK_EN <= L;
			when s3 =>
				C64Clk_Seq <= s4;
				C64_CLK_EN <= H;
			when s4 =>
				C64Clk_Seq <= s0;
				C64_CLK_EN <= L;
			when others => null;
			end case;

			-- synch clk_state to extern Q25
			Q12_5_1 <= Q12_5;
			if (Q12_5_1 = L) and (Q12_5 = H) then
				C64Clk_Seq <= s1;
			end if;

		end if;
	end process;
end generate;

--******************************************************************************
--	C64 Clock Generator
--******************************************************************************
--	Der C64-Clock muss stetig laufen,
--		daher NIE einen Reset oder adere Synchs auf diese Signal !
--------------------------------------------------------------------------------
inst_IntQ25: if (g_Extern_Q25 = 0) generate begin
--	 			 s0s1s2s3s4s0
--	C64_CLK		_------____----
--	Q125		_-_-_-_-_-_-_-_-_-_
--	Q25			_-----_____-----_____-
	process (i_Q125) begin
		if rising_edge(i_Q125) then

			-- VORSICHT: darf nie zurück gesetzt werden!
			case C64Clk_Seq is
			when s0 =>
				C64Clk_Seq <= s1;
				C64_CLK <= H;
				C64_CLK_re <= H;
				C64_CLK_fe <= L;
				C64_CLK_EN <= L;
			when s1 =>
				C64Clk_Seq <= s2;
				C64_CLK <= H;
				C64_CLK_re <= L;
				C64_CLK_fe <= L;
				C64_CLK_EN <= L;
			when s2 =>
				C64Clk_Seq <= s3;
				C64_CLK <= L;
				C64_CLK_re <= L;
				C64_CLK_fe <= L;
				C64_CLK_EN <= L;
			when s3 =>
				C64Clk_Seq <= s4;
				C64_CLK <= L;
				C64_CLK_re <= H;
				C64_CLK_fe <= H;
				C64_CLK_EN <= H;
			when s4 =>
				C64Clk_Seq <= s0;
				C64_CLK <= H;
				C64_CLK_re <= H;
				C64_CLK_fe <= H;
				C64_CLK_EN <= L;
			when others => null;
			end case;
		end if;
	end process;
 end generate;


--******************************************************************************
--	Main Cycle-Timer
--******************************************************************************
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			if (C64Clk_Seq = s4) then
				SeqReset <= L;
			end if;
			
			o_Overrun <= L;

			--------------------------------------------------------------------
			--	select TlgPage for synch to
			--------------------------------------------------------------------
			--	kein Synch auf Page-0, Config-Register

			if ((EnSynCopMas = H and i_TlgIrq(0) = H)
			or	((SynchPage > 0) and (i_TlgIrq(CONV_INTEGER(SynchPage)) = H))) then
			    if (GL_SoftSynch = L) and (GL_ASoSy = L) then  
					TlgIrq <= H;
				end if;			
				-- do we havt to show GinLink TlgTime?                                
				if (g_GL_TlgTime = 1) then			
					GinTlg_Time <= Timer;
					GinTlg_Cnt  <= GinTlg_Cnt + 1;
				end if;
			elsif (SeqReset = H) then
				-- hold it till MainSeq reset
			 	TlgIrq <= L;
			end if;

			--------------------------------------------------------------------
			--	AutoSynch with GinLink  	
			--------------------------------------------------------------------
			Timermax <= TimerCmd;
			-- did we saved GL_TlgTime and do we have to do AutoSoftSynch? 
			if (g_GL_TlgTime = 1) and (g_GL_ASoSy = 1) then	
				-- AutoSoftSynch enabled an GinLink is running ?	
				if ((GL_ASoSy = H) and (i_GinLink_Wdog = L)) then
					-- faster /slower ?
					if (GinTlg_Time(15 downto 8) = x"00") then
						-- 0..7 is ok, else we need to be slower 
						if (GinTlg_Time(7 downto 3) /= "00000") then 
							-- slower
							Timermax <= TimerCmd + 1;	-- wird langsamer, GinTlg_Time wird kleiner
					    end if;
					else
						-- faster
						Timermax <= TimerCmd - 1;		-- wird schneller, GinTlg_Time wird grösser
					end if;
				end if;					
			end if;
			
			--------------------------------------------------------------------
			--	Main-Sequencer Tel-Synch & reset
			--	and Overrun Counter
			--------------------------------------------------------------------
			-- be always C64-Clock synchron !!
			-- SeqReset high at S3, so Seq resets at S4 -> S0
			if (C64Clk_Seq = s3) then
				-- timer-max reached?
				if (Timer >= TimerMax) then
					-- test overrun counter
					if (OvrCnt > 0) then
						-- still ok
						OvrCnt <= OvrCnt - 1;
						-- reset main-sequencer
	--					if  (CM_Seq /= sSPI_Access)
	--					and (CM_Seq /= sJTG_Access) then
						if (CM_Seq = sEnd3) then
							SeqReset <= H;
						end if;
					end if;
				end if;

				-- synch to GinLink telegram
				if (TlgIrq = H) then
					-- allow up to 3 GinLink miss
					OvrCnt <= x"3";
					-- reset main-sequencer
					if (CM_Seq = sEnd3) or ((C64Clk_Seq = s3) and (CM_Seq = sWTimer)) then
						SeqReset <= H;
					end if;
				end if;
			end if;

			--------------------------------------------------------------------
			--	C64 Main-Timer
			--------------------------------------------------------------------
			-- be always C64-Clock synchron !!
			if (C64Clk_Seq = s4) then
				if (SeqReset = H) then
					Timer <= x"0000";
				elsif (Timer < TimerMax) then
					Timer <= Timer+1;
				end if;
			end if;

			--------------------------------------------------------------------
			--	WatchDog reset with toggle of SynchPage(3)
			--	(used by Active-Master without GinLink-Slave-synch)
			--------------------------------------------------------------------
			if not(WachDog = WachDog_1) then
				-- allow up to 3 GinLink miss
				OvrCnt <= x"3";
			end if;

			--------------------------------------------------------------------
			-- disable overrun counter
			--------------------------------------------------------------------
			if (DisOvrCnt = H) then
				OvrCnt <= x"3";
			end if;

			--------------------------------------------------------------------
			-- Overrun as Status --> ActiveMaster ICU
			--------------------------------------------------------------------
			if ((OvrCnt = 0) and (CM_Seq = sEnd3)) then
				o_Overrun <= H;
			end if;

		end if;
	end process;

--------------------------------------------------------------------------------
--	Reset when TimeOut
--------------------------------------------------------------------------------
	process (i_Q125) begin
		if rising_edge(i_Q125) then

			-- 25MHz only
			if (C64Clk_Seq = s4) then
				-- C64-Bus access
				if (C64_SEL = H) then
					-- reset timout to 65535*40ns = 2.6ms
					TimOutCnt <= x"FFFF";
					-- end Reset
					o_C64_Reset <= L;
				else
					-- timeout?
					if (TimOutCnt > 0) then
						-- no, run timer
						TimOutCnt <= TimOutCnt - 1;
					else
						-- yes, Reset the C64-Mod outputs
						o_C64_Reset <= H;
					end if;
				end if;
			end if;

		end if;
	end process;
--******************************************************************************
--
--		GIN-Frame Sequencer
--
--******************************************************************************
	o_log_addr <= log_addr;
	process (i_Q125) begin
	  if rising_edge(i_Q125) then
		PgIRQs 	<= x"00";
		o_log_en <= L;
		clr_cnt <= L;
		-- TimerMax reached ?
		if (SeqReset = H) then
		  		-- yes, restart the sequencer
				CM_Seq <= sIdle;

				-- read disable overrun counter
				DisOvrCnt <= MEM_RdData(28);
				
		else
			--==================================================================
			--	Sequencer
			--==================================================================
			case CM_Seq is

			--------------------------------------------------------------------
			--	idle
			--------------------------------------------------------------------
			when sIdle =>	---
				CM_CmdPoi 		<= Cfg_TimMax(11 downto 0);
				C64_Dat_HOE 	<= H;
				C64_Dat_LOE 	<= H;
				C64_Ack_OE 		<= H;
				SubStartTime <= (others => L);
				SubTable <= L;
				jump_return <= L;
				if (C64Clk_Seq = s0) then
					CM_Seq <= sIdle1;
				end if;
				log_addr <= (others => L);

			when sIdle1 =>	---
				-- read disable overrun counter
				DisOvrCnt <= MEM_RdData(28);

				-- save WatchDog-toggle
				WachDog_1 <= WachDog;
				WachDog <= MEM_RdData(25);
				EnSynCopMas <= MEM_RdData(23);
				-- Tlg Synch-Page
				SynchPage <= MEM_RdData(22 downto 20);
				-- GinLink SoftSynch (do not reset CycleTimer)
				GL_SoftSynch <= MEM_RdData(19);
				-- GinLink AutoSoftSynch 
				GL_ASoSy <= MEM_RdData(18);
				-- save EJS-access switch
				EJS_ACCESS_SW <= MEM_RdData(27) and i_8k3p_Enable;
				-- save GinOr enable switch (get this from PPC only)
				GIN_OR_EN <= MEM_RdData_r(26) and i_8k3p_Enable;
				-- CycleTimer max
				TimerCmd <= MEM_RdData(15 downto 0);

				if (MEM_RdData(31) = H) and	(MEM_RdData(15 downto 0) > 0) then
					CM_Seq <= sIdle2;
				else
					CM_Seq <= sIdle;
					clr_cnt <= H;
				end if;

			when sIdle2 =>
				-- point ot first command
				CM_CmdPoi <= Cfg_CmdTab(11 downto 0);
				CM_Seq <= sIdle3;
				-- asynch part: point to JTAG_JOB

			when sIdle3 =>	---
				CM_Seq <= sIdle4;
				-- asynch part: point to EEP_JOB
				o_logout(15 downto 0) <= "0000" & CM_CmdPoi;

			when sIdle4 =>	---
				JTG_En <= L;
				SPI_En <= L;
				EEP_En <= L;
				if ((MEM_RdData and cmd_TMask) /= x"00000000") then
					SpecialCmd <= H;
				else
					SpecialCmd <= L;
				end if;
				if SpecialCmd=H then
					if (g_NO_JTAG=0) and ((MEM_RdData and cmd_TMask) = cmd_JTG) then
						-- give bus-ctrl to the JTAG loader
						JTG_En <= H;
						CM_Seq <= sJTG_Access;
					elsif (g_NO_SPI=0) and ((MEM_RdData and cmd_TMask) = cmd_SPI) then
						-- give bus-ctrl to the SPI loader
						SPI_En <= H;
						CM_Seq <= sSPI_Access;
					elsif (g_NO_EEPROM=0) and ((MEM_RdData and cmd_TMask) = cmd_EEP) then
						-- give bus-ctrl to the EEP loader
						EEP_En <= H;
						CM_Seq <= sEEP_Access;
					elsif ((MEM_RdData and cmd_TMask) /= x"00000000") then
						CM_Seq <= sCLR_ESJ_CMD1;
					else
						CM_Seq <= sWstart;
					end if;
				else
					CM_Seq <= sWstart;
				end if;
				-- asynch part: point to command tab

			--------------------------------------------------------------------
			--	EEPROMer
			--------------------------------------------------------------------
			when sCLR_ESJ_CMD1 =>	---
				-- clear job_cmd
				CM_Seq <= sCLR_ESJ_CMD2;
			when sCLR_ESJ_CMD2 =>	---
				-- write EEEE_EEEE to EEPROM-Addr 080
				CM_Seq <= sReStart0;

			when sEEP_Access =>	---

				if (EEP_Done = L) then
					EEP_En <= H;
				else
					EEP_En <= L;
					CM_Seq <= sReStart0;
				end if;

			when sSPI_Access =>	---
				-- C64 is controlled by SPI loader
		 		C64_SEL	 <= SPI_C64_SEL		;
		 		C64_Bend	<= SPI_C64_Bend	 ;
		 		C64_Dat_HOE <= SPI_C64_Dat_HOE  ;
		 		C64_Dat_LOE <= SPI_C64_Dat_LOE  ;
		 		C64_Ack_OE  <= SPI_C64_Ack_OE   ;
		 		C64_WrDat   <= SPI_C64_WrDat	;

				if (SPI_Done = L) then
					SPI_En <= H;
				else
					SPI_En <= L;
					CM_Seq <= sReStart0;
				end if;

			when sJTG_Access =>	---
				-- C64 is controlled by JTAG loader
		 		C64_SEL	 <= JTG_C64_SEL		;
		 		C64_Bend	<= JTG_C64_Bend	 ;
		 		C64_Dat_HOE <= JTG_C64_Dat_HOE  ;
		 		C64_Dat_LOE <= JTG_C64_Dat_LOE  ;
		 		C64_Ack_OE  <= JTG_C64_Ack_OE   ;
		 		C64_WrDat   <= JTG_C64_WrDat	;

				if (JTG_Done = L) then
					JTG_En <= H;
				else
					JTG_En <= L;
					CM_Seq <= sReStart0;
				end if;

			--==================================================================
			--
			--	ReStart and read TimerMax
			--
			--==================================================================
			when sReStart0 =>	---
				-- be always synchron
				if (C64Clk_Seq = s0) then
					CM_Seq <= sReStart1;
				end if;

			when sReStart1 =>	---
				CM_Seq <= sReStart2;

			when sReStart2 =>	---
				CM_Seq <= sReStart3;

			when sReStart3 =>	---
				-- point ot first command
				CM_CmdPoi <= Cfg_CmdTab(11 downto 0);
				CM_Seq <= sReStart4;

			when sReStart4 =>	---
				CM_Seq <= sWstart;
				o_logout(15 downto 0) <= "0000" & CM_CmdPoi;

			--==================================================================
			-- Start
			--==================================================================
			when sWstart =>	--- synch bus to C64_CLK ---------------------------
				-- command aktive?
				if (MEM_RdData(31) = H) then
					CM_Seq 	<= sStart;
				else
					CM_Seq 	<= sEnd0;
				end if;
				if (g_MEM_RdD_REG = 1) then
					-- save command
					CM_NextCmd <= MEM_RdData;
				end if;

			when sStart =>	--- synch bus to C64_CLK ---------------------------
				if (g_MEM_RdD_REG = 0) then
					-- save command
					CM_NextCmd <= MEM_RdData;
				end if;
				CM_Seq <= sWTimer;

			--------------------------------------------------------------------
			--	Timer
			--------------------------------------------------------------------
			when sWTimer =>	--- wait to timer ----------------------------------
				-- clear burst end (after last Rd/Wr)
				C64_Bend <= L;
				-- Bus active (after last Read)
				C64_Bend <= L;
				if (C64Clk_Seq = s1) then
					C64_Dat_HOE <= H;
					C64_Dat_LOE <= H;
					C64_Ack_OE <= H;
				end if;
				C64_WrDat <= x"0000";

				-- synch to C64 clock
				if (C64Clk_Seq = s4) then
					if  (Timer >= TimerMax) then
						-- wait-timer error
						CM_Seq <= sWtErr0;
					elsif (Timer(14 downto 0) >= (CM_NextCmd(30 downto 16)+SubStartTime)) then
						-- req time reeached
						CM_Seq <= sBusAdr0;
						-- point to next command and read it at t+2
						if (g_MEM_RdD_REG = 1) then
							CM_CmdPoi <= CM_CmdPoi + 4; 	-- + 4 Byte
						end if;
					end if;
				end if;

			--==================================================================
			--
			-- 		C64_Bus Address-Cycle
			--
			--==================================================================
			when sBusAdr0 =>	--- Adr-cycle ----------------------------------
				C64_Bend <= L;
				clr_CRC <= L;
				o_logout(31 downto 16) <= Timer;
				o_log_en <= H;
				if ((CM_NextCmd(15 downto 12)=cmd_C64_JUMP) and g_HIDE_JUMP_CMD=1) then
					C64_WrDat <= (others => L);
					C64_SEL <= L;
				else
					C64_SEL <= H;
					C64_WrDat <= CM_NextCmd(15 downto 0);
				end if;
				-- point to adr-tab and read it at t+2
				CM_CmdPoi <= CM_CmdPoi + 4; 	-- + 4 Byte
				CM_Seq 	<= sBusAdr1;

			when sBusAdr1 =>	--- Adr-cycle ----------------------------------
				log_addr <= log_addr+1;
				C64_Dat_HOE <= H;
				C64_Dat_LOE <= H;
				C64_Ack_OE <= H;
				-- point to next command and read it at t+2
				if (g_MEM_RdD_REG = 0) then
					CM_CmdPoi <= CM_CmdPoi + 4; 	-- + 4 Byte
				end if;
				CM_Seq 	<= sBusAdr2;

			when sBusAdr2 =>	--- Adr-cycle ----------------------------------
				-- save Byte-AdrPoi
				MEM_DatPoi <= MEM_RdData(15 downto 0);
				-- save IRQ_Nr for local-PPC IRQ
				PgIRQ_Nr <= CONV_INTEGER(MEM_RdData_r(14 downto 12));
				--save Page for RxBuf0/1 toggle-bit select
				if (g_TwoPort_OR = 0 or i_8k3p_Enable=L) then
					-- old 4k-version, FirstPort only
					PgRxBuf_Tgl <= MEM_RdData_r(14 downto 12);
				else
					-- new 8kByte ThreePort RAM version, get GinSlave_Pg
					PgRxBuf_Tgl <= SP_RdData_r(14 downto 12);
				end if;

				-- save No of burst-cycles
				CM_NOC 	<= MEM_RdData(23 downto 16);
				CM_EEEE <= MEM_RdData(24);
				CM_Seq 	<= sBusAdr3;

			when sBusAdr3 =>	--- Adr-cycle ----------------------------------
				-- save next command
				CM_NextCmd <= MEM_RdData;
				o_logout(15 downto 0) <= "0000" & CM_CmdPoi;
				CM_Cmd <= CM_NextCmd(15 downto 12);
				CM_Seq 	<= sBusAdr4;

			when sBusAdr4 =>	--- Adr-cycle ----------------------------------
				-- asynch part: MEM_adr zeigt jetzt auf Daten-Bereich
				if (CM_NOC = 0) then
					-- damit kein 256 wenn 0
					CM_NOC(0) <= H;
				end if;
				-- ab jetzt soll der Slave ACK bringen
				if (CM_Cmd=cmd_C64_JUMP) then
					C64_Ack_OE <= H;
				else
					C64_Ack_OE <= L;
				end if;

				----------------------------------------------------------------
				-- C64 command decoder
				----------------------------------------------------------------
				send_crc <= L;
				case CM_Cmd is
				when cmd_C64_WR_BC
				   | cmd_C64_WR	=>
					CM_Seq 	<= sBusWrDat0;
					if (C64_WrDat(7 downto 0)=x"FF" and g_CRCChecker=1) then
						send_crc <= H;
					end if;

				when cmd_C64_RD =>
					-- read, switch the data-bus to tristate
					C64_Dat_HOE <= L;
					C64_Dat_LOE <= L;
					CM_Seq 	<= sBusRdDat10;

				when cmd_C64_JUMP =>
					CM_Seq <= sJump0;

				when others =>
					-- don't know, so we are careful and do a read cycle
					C64_Dat_HOE <= L;
					C64_Dat_LOE <= L;
					CM_Seq 	<= sBusRdDat10;
				end case;
				
			--==================================================================
			--
			--		C64_Bus Read
			--
			--==================================================================
			when sBusRdDat10 =>	--- Data-cycle ---------------------------------
				C64_SEL <= L;
				-- last burst-cycle?
				if (CM_NOC = 1) then
					-- yes, set C64-BURST-END
					C64_Bend <= H;
				end if;
				CM_Seq 	<= sBusRdDat11;
				if (CM_NextCmd(31)=L and SubTable=H) then
					retPoi <= (others => L);
					CM_CmdPoi <= retPoi;
					jump_return <= H;
				end if;

			when sBusRdDat11 =>	--- Data-cycle ---------------------------------
				-- set PageIRQ (Timer-IRQs for active-Master)
				PgIRQs(PgIRQ_Nr) <= C64_Bend;
				CM_Seq 	<= sBusRdDat12;

			when sBusRdDat12 =>	--- Data-cycle ---------------------------------
				-- hold IRQS for Q125 -> Q110
				PgIRQs <= PgIRQs;
				CM_Seq 	<= sBusRdDat13;

			when sBusRdDat13 =>	--- Data-cycle ---------------------------------
				-- hold IRQS for Q125 -> Q110
				PgIRQs <= PgIRQs;
				CM_NOC <= CM_NOC-1;
				CM_Seq 	<= sBusRdDat14;
				if (jump_return = H) then
					SubTable <= L;
					SubStartTime <= (others => L);
					jump_return <= L;
					CM_NextCmd <= MEM_RdData;
					o_logout(15 downto 0) <= "0000" & CM_CmdPoi;
				end if;

			when sBusRdDat14 =>	--- Data-cycle ---------------------------------
				-- asynch part: store RdDat into MEM
				-- is this the last cycle ?
				if (C64_Bend = L) then
					-- no, burst again...
					CM_Seq 	<= sBusRdDat10;
					MEM_DatPoi <= MEM_DatPoi+2;
				else
					-- TabEnd reached?
					if (CM_NextCmd(31) = H) then
						-- no, next cmd with Timer ?
						if (CM_NextCmd(30 downto 16) > 0) then
							-- go and wait to Timer
							CM_Seq <= sWTimer;
						else
							-- do next burst-cycle
							CM_Seq <= sBusAdr0;
							-- point to next command and read it at t+2
							if (g_MEM_RdD_REG = 1) then
								CM_CmdPoi <= CM_CmdPoi + 4; 	-- + 4 Byte
							end if;
						end if;
					else
						-- TabEnd, go and wait to TimerMax
						CM_Seq <= sEnd0;
					end if;
				end if;

			--==================================================================
			--
			--		C64_Bus Write
			--
			--==================================================================
			when sBusWrDat0 =>	--- Data-cycle ---------------------------------
				C64_SEL <= L;
				-- high or low word
				if (MEM_DatPoi(1) = L) then
					C64_WrDat <= MEM_RdData(31 downto 16);
				else
					C64_WrDat <= MEM_RdData(15 downto  0);
				end if;
				if (send_crc=H and g_CRCChecker=1) then
					C64_WrDat <= crc_val;
					clr_CRC <= H;
				end if;

				-- last burst-cycle?
				if (CM_NOC = 1) then
					-- yes, set C64-BURST-END
					C64_Bend <= H;
				end if;
				CM_Seq 	<= sBusWrDat1;

				if (CM_NextCmd(31)=L and SubTable=H) then
					retPoi <= (others => L);
					CM_CmdPoi <= retPoi;
					jump_return <= H;
				end if;

			when sBusWrDat1 =>	--- Data-cycle ---------------------------------
				PgIRQs(PgIRQ_Nr) <= C64_Bend;
				-- inc Byte-AdrPoi 2-Byte
				MEM_DatPoi <= MEM_DatPoi+2;
				CM_Seq 	<= sBusWrDat2;

			when sBusWrDat2 =>	--- Data-cycle ---------------------------------
				-- hold IRQS for Q125 -> Q110
				PgIRQs <= PgIRQs;
				CM_Seq 	<= sBusWrDat3;

			when sBusWrDat3 =>	--- Data-cycle ---------------------------------
				-- hold IRQS for Q125 -> Q110
				PgIRQs <= PgIRQs;
				CM_NOC <= CM_NOC-1;
				CM_Seq 	<= sBusWrDat4;
				if (jump_return = H) then
					SubTable <= L;
					SubStartTime <= (others => L);
					jump_return <= L;
					CM_NextCmd <= MEM_RdData;
					o_logout(15 downto 0) <= "0000" & CM_CmdPoi;
				end if;

			when sBusWrDat4 =>	--- Data-cycle ---------------------------------
				-- is this the last cycle ?
				if (C64_Bend = L) then
					-- no, burst again...
					CM_Seq 	<= sBusWrDat0;
				else
					-- TabEnd reached?
					if (CM_NextCmd(31) = H) then
						-- no, next cmd with Timer ?
						if (CM_NextCmd(30 downto 16) > 0) then
							-- go and wait to Timer
							CM_Seq <= sWTimer;
						else
							-- do next burst-cycle
							CM_Seq <= sBusAdr0;
							-- point to next command and read it at t+2
							if (g_MEM_RdD_REG = 1) then
								CM_CmdPoi <= CM_CmdPoi + 4; 	-- + 4 Byte
							end if;
						end if;
					else
						-- TabEnd, go and wait to TimerMax
						CM_Seq <= sEnd0;
					end if;
				end if;

			--==================================================================
			--
			--		COP_Bus SubTable Command
			--
			--==================================================================	
			when sJump0 =>
				if (g_HIDE_JUMP_CMD=0) then
					C64_Bend <= H;
					C64_WrDat <= MEM_DatPoi(15 downto 0);
				end if;
				SubTable <= H;
				SubStartTime <= Timer(14 downto 0);
				C64_SEL <= L;
				CM_CmdPoi <= MEM_DatPoi(11 downto 0);
				CM_NextCmd <= MEM_RdData;
				retPoi <= CM_CmdPoi;
				CM_Seq <= sJump1;
				if (MEM_RdData(31)=L) then
					retPoi <= (others => L);
					CM_CmdPoi <= CM_CmdPoi;--CM_CmdPoi <= retPoi;
					jump_return <= H;
				end if;
			when sJump1 =>
				PgIRQs(PgIRQ_Nr) <= H;
				o_logout(15 downto 0) <= "0000" & CM_CmdPoi;
				CM_Seq <= sJump2;
			when sJump2 =>
				-- hold IRQS for Q125 -> Q110
				PgIRQs <= PgIRQs;
				CM_Seq <= sJump3;
			when sJump3 =>
				if (jump_return = H) then
					SubTable <= L;
					SubStartTime <= (others => L);
					jump_return <= L;
					CM_NextCmd <= MEM_RdData;
					o_logout(15 downto 0) <= "0000" & CM_CmdPoi;
				end if;
				CM_Seq <= sJump4;
			when sJump4 =>
				-- TabEnd reached?
				if (CM_NextCmd(31) = H) then
					-- no, next cmd with Timer ?
					if (CM_NextCmd(30 downto 16) > 0) then
						-- go and wait to Timer
						CM_Seq <= sWTimer;
					else
						-- do next bus-cycle
						CM_Seq <= sBusAdr0;
						-- point to next command and read it at t+2
						if (g_MEM_RdD_REG = 1) then
							CM_CmdPoi <= CM_CmdPoi + 4; 	-- + 4 Byte
						end if;
					end if;
				else
					-- TabEnd, go and wait to TimerMax
					CM_Seq <= sEnd0;
				end if;

			--==================================================================
			--
			-- 		TabEnd
			--
			--==================================================================
			when sEnd0 =>	--- TabEnd -----------------------------------------
				C64_Bend <= L;
				C64_WrDat <= x"0000";
				CM_Seq <= sEnd1;
				CyCnt <= CyCnt+1;

			when sEnd1 =>	--- Inc Cycle-Counter ------------------------------
				C64_Ack_OE <= H;
				C64_Dat_HOE <= H;
				C64_Dat_LOE <= H;
				CM_Seq <= sEnd2;

			when sEnd2 =>	--- TabEnd -----------------------------------------
				-- asyn part: point to Cfg_TimMax
				CM_Seq <= sEnd3;

			when sEnd3 =>	--- write SingleShot done --------------------------
				-- read disable overrun counter
				DisOvrCnt <= MEM_RdData(28);
				-- save WatchDog-toggle
				WachDog_1 <= WachDog;
				WachDog <= MEM_RdData(25);
				EnSynCopMas <= MEM_RdData(23);
				-- Tlg Synch-Page
				SynchPage <= MEM_RdData(22 downto 20);
				-- GinLink SoftSynch (do not reset CycleTimer)
				GL_SoftSynch <= MEM_RdData(19);
				-- GinLink AutoSoftSynch 
				GL_ASoSy <= MEM_RdData(18);
				-- save EJS-access switch
				EJS_ACCESS_SW <= MEM_RdData(27) and i_8k3p_Enable;
				-- save GinOr enable switch (get it from PPC only)
				GIN_OR_EN <= MEM_RdData_r(26) and i_8k3p_Enable;
				-- CycleTimer max
				TimerCmd <= MEM_RdData(15 downto 0);

			--==================================================================
			--	Wait to Timer Error
			--==================================================================
			when sWtErr0 =>	--- WtError ----------------------------------------
				CM_Seq <= sWtErr1;
				WtErrCnt <= WtErrCnt+1;

			when sWtErr1 =>	--- Inc WtErr Counter ------------------------------
				CM_Seq <= sEnd2;

			--------------------------------------------------------------------
			when others => null; -----------------------------------------------
			end case;
		end if; -- SeqReset
		
		if (clr_cnt=H) then
			WtErrCnt <= (others => L);
			CyCnt <= (others => L);
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
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			MEM_Adr_1 <= MEM_Adr;
		end if;
	end process;
--------------------------------------------------------------------------------
--	asynchron part of DP-Ram read
--------------------------------------------------------------------------------
MEM_RdD_REG_as: if (g_MEM_RdD_REG = 1) generate begin
	process (MEM_Adr_1,MEM_RdData_r,
			 CM_Seq,CM_CmdPoi,MEM_DatPoi,PgRxBuf_Tgl,
			 i_C64_RdDat,C64_Ack,CM_EEEE
		) begin

		MEM_Adr <= MEM_Adr_1;
		MEM_WR <= "0000";
		MEM_WrData <= x"00000000";

		case CM_Seq is

		------------------------------------------------------------------------
		-- 	idle
		------------------------------------------------------------------------
		when sIdle =>
			-- point to TimMax
			MEM_Adr <= Cfg_TimMax;
		
		when sIdle1 =>
			if (g_GL_TlgTime = 1) then			
				-- point to GinLink TlgTime
				MEM_Adr <= Cfg_GinTlgTim;
				MEM_WrData <= GinTlg_Cnt & GinTlg_Time;
				MEM_WR <= "1111"; 
			end if;	

		when sIdle2 =>
			-- point to EEP_Job
			MEM_Adr <= Cfg_EEP_Job;

		when sIdle3 =>
			MEM_Adr <= x"0" & Cfg_CmdTab(11 downto 0);
		
		when sIdle4 =>
			-- point to EEP_Job
			MEM_Adr <= Cfg_EEP_Job;
			
		when sReStart3 =>
			MEM_Adr <= x"0" & Cfg_CmdTab(11 downto 0);

		when sBusAdr0
		   | sBusAdr1 => 
			MEM_Adr <= x"0" & CM_CmdPoi;
			
		when sBusRdDat11
		   | sBusWrDat1
		   | sJump1 =>
			MEM_Adr <= x"0" & CM_CmdPoi;

		when sBusAdr3
		   | sBusWrDat3
		   | sBusRdDat13 =>
			MEM_Adr <= MEM_DatPoi(15) & PgRxBuf_Tgl & MEM_DatPoi(11 downto 0);

		when sBusAdr4
		   | sBusWrDat4
		   | sBusRdDat14 =>
			-- point to src/dest-mem Adr to get first wr-data
			-- MEM_Adr <= MEM_DatPoi(15) & PgRxBuf_Tgl & MEM_DatPoi(11 downto 0);
			
			if (CM_Seq=sBusRdDat14 or (send_crc=H  and g_CRCChecker=1)) then
				if (C64_Ack = H) then
					-- store the readed bus-data to dest-mem
					MEM_WrData <= i_C64_RdDat & i_C64_RdDat;
					if (MEM_DatPoi(1) = L) then
						MEM_WR <= "1100";
					else
						MEM_WR <= "0011";
					end if;
				else
					if (CM_EEEE = H) then
						-- store EEEE to dest-mem
						MEM_WrData <= x"EEEE_EEEE";
						if (MEM_DatPoi(1) = L) then
							MEM_WR <= "1100";
						else
							MEM_WR <= "0011";
						end if;
					end if;
				end if;
			end if;

		when sCLR_ESJ_CMD1 =>	---
			-- interface not implemented ?
			if (g_NO_JTAG=1) or (g_NO_SPI=1) or (g_NO_EEPROM=1) then
				-- clear EEP or SPI or JTG command
				MEM_Adr <= Cfg_EEP_Job;
				MEM_WrData  <= (others => '0');
				MEM_WR <= "1000";
			end if;

		when sCLR_ESJ_CMD2 =>	---
			-- interface not implemented ?
			if (g_NO_JTAG=1) or (g_NO_SPI=1) or (g_NO_EEPROM=1) then
				-- clear EEP or SPI or JTG command
				MEM_Adr <= Cfg_EEP080;
				MEM_WrData  <= x"EEEE_EEEE";
				MEM_WR <= "1111";
			end if;

		when sEEP_Access =>	---
			-- MEM is controlled by SPI loader
			if (g_SELECTnOR_MEM = 0) then
				MEM_Adr	 <= (others => '0');
				MEM_WrData  <= (others => '0');
				MEM_WR	  <= (others => '0');
			else
				MEM_Adr		<= EEP_MEM_Adr		;
				MEM_WrData	<= EEP_MEM_WrData	;
				MEM_WR 		<= EEP_MEM_WR 		;
			end if;

		when sSPI_Access =>	---
			-- MEM is controlled by SPI loader
			if (g_SELECTnOR_MEM = 0) then
				MEM_Adr	 <= (others => '0');
				MEM_WrData  <= (others => '0');
				MEM_WR	  <= (others => '0');
			else
				MEM_Adr		<= SPI_MEM_Adr		;
				MEM_WrData	<= SPI_MEM_WrData	;
				MEM_WR 		<= SPI_MEM_WR 		;
			end if;

		when sJTG_Access =>	---
			-- MEM is controlled by JTAG loader
			if (g_SELECTnOR_MEM = 0) then
				MEM_Adr	 <= (others => '0');
				MEM_WrData  <= (others => '0');
				MEM_WR	  <= (others => '0');
			else
				MEM_Adr		<= JTG_MEM_Adr		;
				MEM_WrData	<= JTG_MEM_WrData	;
				MEM_WR 		<= JTG_MEM_WR 		;
			end if;

		------------------------------------------------------------------------
		when sEnd0 =>
			-- point to Cycle Counter
			MEM_Adr <= Cfg_CyCnt;
			-- inc Cycle Counter
			MEM_WrData <= CyCnt;
			MEM_WR <= "1111";

		when sEnd1 =>
			-- point to TimerMax
			MEM_Adr <= Cfg_TimMax;

		when sEnd3 =>
			if (MEM_RdData_r(24) = H) then
				-- clear Aktive, set SingleShot done, clear DoSinge
				MEM_WrData <= (MEM_RdData_r and x"EEFFFFFF") or x"02000000";
				MEM_WR <= "1111";
			end if;

		------------------------------------------------------------------------
		when sWtErr0 =>
			-- point to Cycle Counter
			MEM_Adr <= Cfg_WtErrCnt;
			-- inc WtErr Counter 	only (7 downto 0) really used
			MEM_WrData <= x"000000" & WtErrCnt+1;
			MEM_WR <= "0001";
			
		when sWtErr1 =>
			-- point to TimerMax
			MEM_Adr <= Cfg_TimMax;
			

		------------------------------------------------------------------------
		when others => null;
		end case;
	end process;
end generate MEM_RdD_REG_as;

MEM_RdD_nREG_as: if (g_MEM_RdD_REG = 0) generate begin
	process (MEM_Adr_1,MEM_RdData,
			 CM_Seq,CM_CmdPoi,MEM_DatPoi,PgRxBuf_Tgl,
			 i_C64_RdDat,C64_Ack,CM_EEEE
		) begin

		MEM_Adr <= MEM_Adr_1;
		MEM_WR <= "0000";
		MEM_WrData <= x"00000000";

		case CM_Seq is

		------------------------------------------------------------------------
		-- 	idle
		------------------------------------------------------------------------
		when sIdle
		   | sIdle1 =>
			-- point to TimMax
			MEM_Adr <= Cfg_TimMax;

		when sIdle2 =>
			if (g_GL_TlgTime = 1) then			
				-- point to GinLink TlgTime
				MEM_Adr <= Cfg_GinTlgTim;
				MEM_WrData <= GinTlg_Cnt & GinTlg_Time;
				MEM_WR <= "1111"; 
			end if;	

		when sIdle3 =>
			-- point to EEP_Job
			MEM_Adr <= Cfg_EEP_Job;

		when sIdle4
		   | sReStart4
		   | sBusAdr1
		   | sBusAdr2
		   | sBusWrDat2
		   | sBusRdDat12
		   | sJump2 =>
			-- point to command tab
			MEM_Adr <= x"0" & CM_CmdPoi;

		when sBusAdr4
		   | sBusWrDat4
		   | sBusRdDat14 =>
			-- point to src/dest-mem Adr to get first wr-data
			MEM_Adr <= MEM_DatPoi(15) & PgRxBuf_Tgl & MEM_DatPoi(11 downto 0);
			
			if (CM_Seq=sBusRdDat14 or (send_crc=H  and g_CRCChecker=1)) then
				if (C64_Ack = H) then
					-- store the readed bus-data to dest-mem
					MEM_WrData <= i_C64_RdDat & i_C64_RdDat;
					if (MEM_DatPoi(1) = L) then
						MEM_WR <= "1100";
					else
						MEM_WR <= "0011";
					end if;
				else
					if (CM_EEEE = H) then
						-- store EEEE to dest-mem
						MEM_WrData <= x"EEEE_EEEE";
						if (MEM_DatPoi(1) = L) then
							MEM_WR <= "1100";
						else
							MEM_WR <= "0011";
						end if;
					end if;
				end if;
			end if;

		when sCLR_ESJ_CMD1 =>	---
			-- interface not implemented ?
			if (g_NO_JTAG=1) or (g_NO_SPI=1) or (g_NO_EEPROM=1) then
				-- clear EEP or SPI or JTG command
				MEM_Adr <= Cfg_EEP_Job;
				MEM_WrData  <= (others => '0');
				MEM_WR <= "1000";
			end if;

		when sCLR_ESJ_CMD2 =>	---
			-- interface not implemented ?
			if (g_NO_JTAG=1) or (g_NO_SPI=1) or (g_NO_EEPROM=1) then
				-- clear EEP or SPI or JTG command
				MEM_Adr <= Cfg_EEP080;
				MEM_WrData  <= x"EEEE_EEEE";
				MEM_WR <= "1111";
			end if;

		when sEEP_Access =>	---
			-- MEM is controlled by SPI loader
			if (g_SELECTnOR_MEM = 0) then
				MEM_Adr	 <= (others => '0');
				MEM_WrData  <= (others => '0');
				MEM_WR	  <= (others => '0');
			else
				MEM_Adr		<= EEP_MEM_Adr		;
				MEM_WrData	<= EEP_MEM_WrData	;
				MEM_WR 		<= EEP_MEM_WR 		;
			end if;

		when sSPI_Access =>	---
			-- MEM is controlled by SPI loader
			if (g_SELECTnOR_MEM = 0) then
				MEM_Adr	 <= (others => '0');
				MEM_WrData  <= (others => '0');
				MEM_WR	  <= (others => '0');
			else
				MEM_Adr		<= SPI_MEM_Adr		;
				MEM_WrData	<= SPI_MEM_WrData	;
				MEM_WR 		<= SPI_MEM_WR 		;
			end if;

		when sJTG_Access =>	---
			-- MEM is controlled by JTAG loader
			if (g_SELECTnOR_MEM = 0) then
				MEM_Adr	 <= (others => '0');
				MEM_WrData  <= (others => '0');
				MEM_WR	  <= (others => '0');
			else
				MEM_Adr		<= JTG_MEM_Adr		;
				MEM_WrData	<= JTG_MEM_WrData	;
				MEM_WR 		<= JTG_MEM_WR 		;
			end if;

		------------------------------------------------------------------------
		when sEnd0 =>
			-- point to Cycle Counter
			MEM_Adr <= Cfg_CyCnt;
			-- inc Cycle Counter
			MEM_WrData <= CyCnt;
			MEM_WR <= "1111";

		when sEnd1 =>

		when sEnd2 =>
			-- point to TimerMax
			MEM_Adr <= Cfg_TimMax;

		when sEnd3 =>
			if (MEM_RdData(24) = H) then
				-- clear Aktive, set SingleShot done, clear DoSinge
				MEM_WrData <= (MEM_RdData and x"EEFFFFFF") or x"02000000";
				MEM_WR <= "1111";
			end if;

		------------------------------------------------------------------------
		when sWtErr0 =>
			-- point to Cycle Counter
			MEM_Adr <= Cfg_WtErrCnt;
			
		when sWtErr1 =>
			-- inc WtErr Counter 	only (7 downto 0) really used
			MEM_WrData <= x"000000" & WtErrCnt;
			MEM_WR <= "0001";

		------------------------------------------------------------------------
		when others => null;
		end case;
	end process;

end generate MEM_RdD_nREG_as;
--------------------------------------------------------------------------------
--	C64_Master Read
--------------------------------------------------------------------------------
EJS_OnePort: if (g_TwoPort_OR = 0) generate
	EJS_RdData <= MEM_RdData_r after 105 ps; -- delay for sim
	MEM_EN <= H;
end generate;

--------------------------------------------------------------------------------
--	TwoPort	Version
--------------------------------------------------------------------------------
-- Wenn ich vom C64_Master aus gesehen 0300..031F lese, darf ich nur Gin Daten
-- sehen (werden von diesem manipuliert, zB EEPROM-JOB gelöscht)
-- Daher dürfen hier die Daten vom PPC in diesem Bereich nicht ge-or-ed werden.
EJS_TwoPort: if (g_TwoPort_OR = 1) generate
	process (EJS_ACCESS_SW, SP_RdData_r, MEM_RdData_r,
			SPI_MEM_WR, JTG_MEM_WR, EEP_MEM_WR)
	begin
		MEM_EN <= H;	SP_EN <= H;

		if (EJS_ACCESS_SW = L) then
				-- EJS access from PPC-side
				EJS_RdData <= MEM_RdData_r after 105 ps; -- delay for sim
				if (SPI_MEM_WR /= x"0")
				or (JTG_MEM_WR /= x"0")
				or (EEP_MEM_WR /= x"0") then
					SP_EN <= L;		-- do not write to GinLink side
				end if;
		else
				-- EJS access from GinLink-side
				EJS_RdData <= SP_RdData_r after 105 ps; -- delay for sim
				if (SPI_MEM_WR /= x"0")
				or (JTG_MEM_WR /= x"0")
				or (EEP_MEM_WR /= x"0") then
					MEM_EN <= L;	-- do not write to PPC-side
				end if;
		end if;
	end process;
end generate;

--------------------------------------------------------------------------------
--	I2C EEPROM loader
--------------------------------------------------------------------------------
genEEPROM:	if (g_NO_EEPROM = 0) generate
	uWrap_EEP: entity C64_Master.C64_EEPSeq
	GENERIC MAP(
		-- patch to change eeprom address 
		g_patch_ee_addr	=> g_patch_ee_addr		,	
		g_patch_addr_f	=> g_patch_addr_f		,
		g_patch_addr_t	=> g_patch_addr_t		,
		g_MEM_RdD_REG	=> g_MEM_RdD_REG
	)
	PORT MAP(
		i_Q125		 	=> i_Q125		 		,
		i_EEP_En	 	=> EEP_En				,
		o_EEP_Done	 	=> EEP_Done	 			,
		i_eep_i2c_acpt	=> i_eep_i2c_acpt		,
		o_eep_i2c_req	=> o_eep_i2c_req		,
		-- Gin-Slave Ram=> -- Gin-Slave Ram
		i_MEM_RdData	=> EJS_RdData 			,
		o_MEM_WrData	=> EEP_MEM_WrData		,
		o_MEM_ByteAddr	=> EEP_MEM_Adr			,
		o_MEM_WR		=> EEP_MEM_WR			,

		-- C64-Bus	  => -- C64-Bus
		i_C64Clk_Seq	=> C64Clk_Seq			,

		o_C64_I2C_SCL	=> o_C64_I2C_SCL		,
		o_C64_I2C_SDA	=> o_C64_I2C_SDA		,
		i_C64_I2C_SDA	=> i_C64_I2C_SDA		,
		o_C96_I2C_SCL	=> o_C96_I2C_SCL		,
		o_C96_I2C_SDA	=> o_C96_I2C_SDA		,
		i_C96_I2C_SDA	=> i_C96_I2C_SDA
	);
end generate;

--------------------------------------------------------------------------------
--	SPI loader
--------------------------------------------------------------------------------
genSPI:	if (g_NO_SPI = 0) generate
	uWrap_SPI: entity C64_Master.C64_SPISeq
	GENERIC MAP(
		g_MEM_RdD_REG	=> g_MEM_RdD_REG
	)
	PORT MAP(
		i_Q125		 	=> i_Q125		 		,
		i_SPI_En	 	=> SPI_En	 			,
		o_SPI_Done	 	=> SPI_Done	 			,

		-- Gin-Slave Ram => Gin-Slave Ram
		i_MEM_RdData	=> EJS_RdData 			,
		o_MEM_WrData	=> SPI_MEM_WrData		,
		o_MEM_ByteAddr	=> SPI_MEM_Adr			,
		o_MEM_WR		=> SPI_MEM_WR			,

		-- C64-Bus => C64-Bus
		i_C64Clk_Seq	=> C64Clk_Seq			,
		o_C64_SEL		=> SPI_C64_SEL			,
		o_C64_Bend		=> SPI_C64_Bend			,
		o_C64_Dat_HOE	=> SPI_C64_Dat_HOE		,
		o_C64_Dat_LOE	=> SPI_C64_Dat_LOE		,
		o_C64_Ack_OE	=> SPI_C64_Ack_OE		,
		o_C64_WrDat		=> SPI_C64_WrDat		,
		i_C64_RdDat		=> i_C64_RdDat			,
		i_C64_Ack		=> C64_Ack
	);
end generate;

--------------------------------------------------------------------------------
--	JTAG loader
--------------------------------------------------------------------------------
genJATG:	if (g_NO_JTAG = 0) generate
	uWrap_JTAG: entity C64_Master.C64_JTAGSeq
	GENERIC MAP(
		g_MEM_RdD_REG	=> g_MEM_RdD_REG
	)
	PORT MAP(
		i_Q125		 	=> i_Q125		 		,
		i_JTG_En	 	=> JTG_En	 			,
		o_JTG_Done	 	=> JTG_Done	 			,

		-- Gin-Slave Ram=> -- Gin-Slave Ram
		i_MEM_RdData	=> EJS_RdData 			,
		o_MEM_WrData	=> JTG_MEM_WrData		,
		o_MEM_ByteAddr	=> JTG_MEM_Adr			,
		o_MEM_WR		=> JTG_MEM_WR			,

		-- C64-Bus	  => -- C64-Bus
		i_C64Clk_Seq	=> C64Clk_Seq			,
		o_C64_SEL		=> JTG_C64_SEL			,
		o_C64_Bend		=> JTG_C64_Bend			,
		o_C64_Dat_HOE	=> JTG_C64_Dat_HOE		,
		o_C64_Dat_LOE	=> JTG_C64_Dat_LOE		,
		o_C64_Ack_OE	=> JTG_C64_Ack_OE		,
		o_C64_WrDat		=> JTG_C64_WrDat		,
		i_C64_RdDat		=> i_C64_RdDat			,
		i_C64_Ack		=> C64_Ack
	);
 end generate;
 
crc: if g_CRCChecker=1 generate
	signal last_crc_val : std_logic_vector(15 downto 0) := (others => H);
	--                                                  fedcba9876543210
	signal crc_poly : std_logic_vector(15 downto 0):= b"0001000000100001";--CRC-CCITT x16+x12+x5+1
	signal job : std_logic:=L;
	constant cmd_WR			:  std_logic_vector := "0111";
	constant cmd_WR_BC		:  std_logic_vector := b"0101_1111"; 
begin
	crc_val <= last_crc_val;
	process(i_Q125) 
	variable j : integer range 0 to 7 := 0;
	begin
		if rising_edge(i_Q125) then
			if (C64_CLK_EN=H) then
				if (C64_SEL=H) then
					-- all address
					job <= H;
					last_crc_val <= crc_gen(C64_WrDat,last_crc_val,crc_poly);
				else
					-- data of connected external modules
					if (C64_Bend=H )then
						job <= L;
					end if;
					if (job=H and i_C64_Ack_Ext=H) then
						if (C64_Dat_HOE=H or C64_Dat_LOE=H) then
							last_crc_val <= crc_gen(C64_WrDat,last_crc_val,crc_poly);
						else
							last_crc_val <= crc_gen(i_C64_RdDat,last_crc_val,crc_poly);
						end if;
					end if;
				end if;
				if (clr_CRC=H) then
					last_crc_val <= (others => H);
				end if;
			end if;
		end if;
	end process;
end generate crc;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
