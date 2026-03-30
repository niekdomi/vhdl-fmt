--------------------------------------------------------------------------------
--
--  GIN-MGT
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
--  	- GigaBit Rocket IO
--
--------------------------------------------------------------------------------
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
use IEEE.numeric_std.all;
-- synopsys translate_off
Library UNISIM;
use UNISIM.Vcomponents.all;
-- synopsys translate_on


entity GIN_MGT is
	generic (
		g_CRC_USE : boolean := FALSE
	);
    port ( 
    	i_MGTclk : in std_logic;
    	i_Q62_5 : in std_logic;

        LOOPBACK_IN : in std_logic_vector (1 downto 0) := "00";
        POWERDOWN_IN : in std_logic := '0';
        RXN_IN : in std_logic;
        RXP_IN : in std_logic;
        RXRESET_IN : in std_logic;
        TXCHARISK_IN : in std_logic_vector (1 downto 0);
        TXDATA_IN : in std_logic_vector (15 downto 0);
        TXFORCECRCERR_IN : in std_logic := '0';
        TXINHIBIT_IN : in std_logic := '0';
        TXRESET_IN : in std_logic;
        RXBUFSTATUS_OUT : out std_logic_vector (1 downto 0);
        RXCHARISCOMMA_OUT : out std_logic_vector (1 downto 0);
        RXCHARISK_OUT : out std_logic_vector (1 downto 0);
        RXCHECKINGCRC_OUT : out std_logic;
        RXCLKCORCNT_OUT : out std_logic_vector (2 downto 0);
        RXCOMMADET_OUT : out std_logic;
        RXCRCERR_OUT : out std_logic;
        RXDATA_OUT : out std_logic_vector (15 downto 0);
        RXDISPERR_OUT : out std_logic_vector (1 downto 0);
        RXLOSSOFSYNC_OUT : out std_logic_vector (1 downto 0);
        RXNOTINTABLE_OUT : out std_logic_vector (1 downto 0);
        RXREALIGN_OUT : out std_logic;
        RXRECCLK_OUT : out std_logic;
        RXRUNDISP_OUT : out std_logic_vector (1 downto 0);
        TXBUFERR_OUT : out std_logic;
        TXKERR_OUT : out std_logic_vector (1 downto 0);
        TXN_OUT : out std_logic;
        TXP_OUT : out std_logic;
        TXRUNDISP_OUT : out std_logic_vector (1 downto 0));
end GIN_MGT;

architecture impl of GIN_MGT is
--------------------------------------------------------------------------------
   signal H 					: std_logic;
   signal L 					: std_logic;
   signal GND 					: std_logic_vector (31 downto 0);
   signal RXCHARISCOMMA_float 	: std_logic_vector (1 downto 0);
   signal RXCHARISK_float 		: std_logic_vector (1 downto 0);
   signal RXDATA_float 			: std_logic_vector (15 downto 0);
   signal RXDISPERR_float 		: std_logic_vector (1 downto 0);
   signal RXNOTINTABLE_float 	: std_logic_vector (1 downto 0);
   signal RXRUNDISP_float 		: std_logic_vector (1 downto 0);
   signal TXKERR_float 			: std_logic_vector (1 downto 0);
   signal TXRUNDISP_float 		: std_logic_vector (1 downto 0);

-- not used
   signal CONFIGOUT_OUT 		: std_logic;


   signal RXDATA 				: std_logic_vector (15 downto 0);
   signal RXCHARISK 			: std_logic_vector (1 downto 0);


--------------------------------------------------------------------------------
-- 	components
--------------------------------------------------------------------------------
   	component GT_CUSTOM
    	generic( 
			ALIGN_COMMA_MSB : boolean := FALSE;
			CHAN_BOND_LIMIT : integer := 16;
			CHAN_BOND_MODE : string := "OFF";
			CHAN_BOND_OFFSET : integer := 8;
			CHAN_BOND_ONE_SHOT : boolean := FALSE;
			CHAN_BOND_SEQ_1_1 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_1_2 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_1_3 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_1_4 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_2_1 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_2_2 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_2_3 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_2_4 : bit_vector := "00000000000";
			CHAN_BOND_SEQ_2_USE : boolean := FALSE;
			CHAN_BOND_SEQ_LEN : integer := 1;
			CHAN_BOND_WAIT : integer := 8;
			CLK_COR_INSERT_IDLE_FLAG : boolean := FALSE;
			CLK_COR_KEEP_IDLE : boolean := FALSE;
			CLK_COR_REPEAT_WAIT : integer := 1;
			CLK_COR_SEQ_1_1 : bit_vector := "00000000000";
			CLK_COR_SEQ_1_2 : bit_vector := "00000000000";
			CLK_COR_SEQ_1_3 : bit_vector := "00000000000";
			CLK_COR_SEQ_1_4 : bit_vector := "00000000000";
			CLK_COR_SEQ_2_1 : bit_vector := "00000000000";
			CLK_COR_SEQ_2_2 : bit_vector := "00000000000";
			CLK_COR_SEQ_2_3 : bit_vector := "00000000000";
			CLK_COR_SEQ_2_4 : bit_vector := "00000000000";
			CLK_COR_SEQ_2_USE : boolean := FALSE;
			CLK_COR_SEQ_LEN : integer := 1;
			CLK_CORRECT_USE : boolean := TRUE;
			COMMA_10B_MASK : bit_vector := "1111111000";
			CRC_END_OF_PKT : string := "K29_7";
			CRC_FORMAT : string := "USER_MODE";
			CRC_START_OF_PKT : string := "K27_7";
			DEC_MCOMMA_DETECT : boolean := TRUE;
			DEC_PCOMMA_DETECT : boolean := TRUE;
			DEC_VALID_COMMA_ONLY : boolean := TRUE;
			MCOMMA_10B_VALUE : bit_vector := "1100000000";
			MCOMMA_DETECT : boolean := TRUE;
			PCOMMA_10B_VALUE : bit_vector := "0011111000";
			PCOMMA_DETECT : boolean := TRUE;
			REF_CLK_V_SEL : integer := 0;
			RX_BUFFER_USE : boolean := TRUE;
			RX_CRC_USE : boolean := FALSE;
			RX_DATA_WIDTH : integer := 2;
			RX_DECODE_USE : boolean := TRUE;
			RX_LOS_INVALID_INCR : integer := 1;
			RX_LOS_THRESHOLD : integer := 4;
			RX_LOSS_OF_SYNC_FSM : boolean := TRUE;
			SERDES_10B : boolean := FALSE;
			TERMINATION_IMP : integer := 50;
			TX_BUFFER_USE : boolean := TRUE;
			TX_CRC_FORCE_VALUE : bit_vector := "11010110";
			TX_CRC_USE : boolean := FALSE;
			TX_DATA_WIDTH : integer := 2;
			TX_DIFF_CTRL : integer := 500;
			TX_PREEMPHASIS : integer := 0
     	);
     	port (
			CHBONDI : in std_logic_vector (3 downto 0);
			CONFIGENABLE : in std_logic;
			CONFIGIN : in std_logic;
			ENMCOMMAALIGN : in std_logic;
			ENPCOMMAALIGN : in std_logic;
			ENCHANSYNC : in std_logic;
			LOOPBACK : in std_logic_vector (1 downto 0);
			POWERDOWN : in std_logic;
			REFCLK : in std_logic;
			REFCLK2 : in std_logic;
			REFCLKSEL : in std_logic;
			BREFCLK : in std_logic;
			BREFCLK2 : in std_logic;
			RXN : in std_logic;
			RXP : in std_logic;
			RXPOLARITY : in std_logic;
			RXRESET : in std_logic;
			RXUSRCLK : in std_logic;
			RXUSRCLK2 : in std_logic;
			TXBYPASS8B10B : in std_logic_vector (3 downto 0);
			TXCHARDISPMODE : in std_logic_vector (3 downto 0);
			TXCHARDISPVAL : in std_logic_vector (3 downto 0);
			TXCHARISK : in std_logic_vector (3 downto 0);
			TXDATA : in std_logic_vector (31 downto 0);
			TXFORCECRCERR : in std_logic;
			TXINHIBIT : in std_logic;
			TXPOLARITY : in std_logic;
			TXRESET : in std_logic;
			TXUSRCLK : in std_logic;
			TXUSRCLK2 : in std_logic;
			CHBONDDONE : out std_logic;
			CHBONDO : out std_logic_vector (3 downto 0);
			CONFIGOUT : out std_logic;
			RXBUFSTATUS : out std_logic_vector (1 downto 0);
			RXCHARISCOMMA : out std_logic_vector (3 downto 0);
			RXCHARISK : out std_logic_vector (3 downto 0);
			RXCHECKINGCRC : out std_logic;
			RXCLKCORCNT : out std_logic_vector (2 downto 0);
			RXCOMMADET : out std_logic;
			RXCRCERR : out std_logic;
			RXDATA : out std_logic_vector (31 downto 0);
			RXDISPERR : out std_logic_vector (3 downto 0);
			RXLOSSOFSYNC : out std_logic_vector (1 downto 0);
			RXNOTINTABLE : out std_logic_vector (3 downto 0);
			RXREALIGN : out std_logic;
			RXRECCLK : out std_logic;
			RXRUNDISP : out std_logic_vector (3 downto 0);
			TXBUFERR : out std_logic;
			TXKERR : out std_logic_vector (3 downto 0);
			TXN : out std_logic;
			TXP : out std_logic;
			TXRUNDISP : out std_logic_vector (3 downto 0)
       );
   	end component;
-------------------------------------------------------------------------------

begin
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--	start-code for simulation only 
-------------------------------------------------------------------------------
	process (RXDATA,RXCHARISK) begin 
		if (RXDATA(0) = 'X') then
			RXDATA_OUT    <= x"BC50";
		    RXCHARISK_OUT <= "10";
		else
			RXDATA_OUT    <= RXDATA;
		    RXCHARISK_OUT <= RXCHARISK;
		end if;    		    
    end process;

-------------------------------------------------------------------------------
	
	
	H 	<= '1';
	L 	<= '0';
	GND <= "00000000000000000000000000000000";
	
-------------------------------------------------------------------------------
--	MGT
-------------------------------------------------------------------------------
	uMGT : GT_CUSTOM
    	Generic map (
      		ALIGN_COMMA_MSB 			=> TRUE,
      		CHAN_BOND_LIMIT 			=> 16,
      		CHAN_BOND_MODE 				=> "OFF",
      		CHAN_BOND_OFFSET 			=> 8,
      		CHAN_BOND_ONE_SHOT 			=> FALSE,
      		CHAN_BOND_SEQ_1_1 			=> "00000000000",
      		CHAN_BOND_SEQ_1_2 			=> "00000000000",
      		CHAN_BOND_SEQ_1_3 			=> "00000000000",
      		CHAN_BOND_SEQ_1_4 			=> "00000000000",
      		CHAN_BOND_SEQ_2_1 			=> "00000000000",
      		CHAN_BOND_SEQ_2_2 			=> "00000000000",
      		CHAN_BOND_SEQ_2_3 			=> "00000000000",
      		CHAN_BOND_SEQ_2_4 			=> "00000000000",
      		CHAN_BOND_SEQ_2_USE 		=> FALSE,
      		CHAN_BOND_SEQ_LEN 			=> 1,
      		CHAN_BOND_WAIT 				=> 8,
      		CLK_CORRECT_USE 			=> TRUE,                -- insert/delete idle
      		CLK_COR_INSERT_IDLE_FLAG	=> TRUE,                -- RXRUNDISP = idle inserted
      		CLK_COR_KEEP_IDLE 			=> TRUE,             	-- keep at least 1 idle
      		CLK_COR_REPEAT_WAIT 		=> 0,                   -- was 1, 0=no limit
      		CLK_COR_SEQ_1_1 			=> "00110111100",       -- BC
      		CLK_COR_SEQ_1_2 			=> "00001010000",       --   50
      		CLK_COR_SEQ_1_3 			=> "00000000000",
      		CLK_COR_SEQ_1_4 			=> "00000000000",
      		CLK_COR_SEQ_2_1 			=> "00000000000",
      		CLK_COR_SEQ_2_2 			=> "00000000000",
      		CLK_COR_SEQ_2_3 			=> "00000000000",
      		CLK_COR_SEQ_2_4 			=> "00000000000",
      		CLK_COR_SEQ_2_USE 			=> FALSE,
      		CLK_COR_SEQ_LEN 			=> 2,                   -- two bytes, BC 50
      		COMMA_10B_MASK 				=> "1111111000",
      		CRC_END_OF_PKT 				=> "K29_7",             -- /T/ = FD
      		CRC_FORMAT 					=> "ETHERNET",
      		CRC_START_OF_PKT 			=> "K27_7",             -- /S/ = FB
      		DEC_MCOMMA_DETECT 			=> TRUE,
      		DEC_PCOMMA_DETECT 			=> TRUE,
      		DEC_VALID_COMMA_ONLY 		=> TRUE,
      		MCOMMA_10B_VALUE 			=> "1100000000",
      		MCOMMA_DETECT 				=> TRUE,
      		PCOMMA_10B_VALUE 			=> "0011111000",
      		PCOMMA_DETECT 				=> TRUE,
      		RX_BUFFER_USE 				=> TRUE,
     		RX_CRC_USE 					=> g_CRC_USE,
      		RX_DATA_WIDTH 				=> 2,
      		RX_DECODE_USE 				=> TRUE,
      		RX_LOSS_OF_SYNC_FSM 		=> TRUE,
      		RX_LOS_INVALID_INCR 		=> 1,
      		RX_LOS_THRESHOLD 			=> 4,
      		TERMINATION_IMP 			=> 50,   				-- 50,75 Ohm
      		SERDES_10B 					=> FALSE,				-- Q62_5 as RefClk
      		TX_BUFFER_USE 				=> TRUE,
      		TX_CRC_FORCE_VALUE 			=> "11010110",
      		TX_CRC_USE 					=> g_CRC_USE,
      		TX_DATA_WIDTH 				=> 2,
      		TX_DIFF_CTRL 				=> 700, 				-- 400,500,600,700,800mV
      		TX_PREEMPHASIS 				=> 1,                   -- 0=10 1=20 2=25 3=35%
      		REF_CLK_V_SEL 				=> 0)
     	port map (
			CHBONDI(3 downto 0) 		=> GND(3 downto 0),
			CONFIGENABLE 				=> L,
			CONFIGIN 					=> L,
			ENMCOMMAALIGN 				=> H,
			ENPCOMMAALIGN 				=> H,
			ENCHANSYNC 					=> L,
			LOOPBACK(1 downto 0) 		=> LOOPBACK_IN(1 downto 0),
			POWERDOWN 					=> POWERDOWN_IN,
			REFCLK 						=> i_MGTclk,
			REFCLK2 					=> L,
			REFCLKSEL 					=> L,
			BREFCLK 					=> L,
			BREFCLK2 					=> L,
			RXN 						=> RXN_IN,
			RXP 						=> RXP_IN,
			RXPOLARITY 					=> L,
			RXRESET 					=> RXRESET_IN,
			RXUSRCLK 					=> i_Q62_5,
			RXUSRCLK2 					=> i_Q62_5,
			TXBYPASS8B10B(3 downto 0) 	=> GND(3 downto 0),
			TXCHARDISPMODE(1 downto 0) 	=> GND(1 downto 0),
			TXCHARDISPMODE(3 downto 2) 	=> GND(1 downto 0),
			TXCHARDISPVAL(1 downto 0) 	=> GND(1 downto 0),
			TXCHARDISPVAL(3 downto 2) 	=> GND(1 downto 0),
			TXCHARISK(1 downto 0) 		=> TXCHARISK_IN(1 downto 0),
			TXCHARISK(3 downto 2) 		=> GND(1 downto 0),
			TXDATA(15 downto 0) 		=> TXDATA_IN(15 downto 0),
			TXDATA(31 downto 16) 		=> GND(15 downto 0),
			TXFORCECRCERR 				=> TXFORCECRCERR_IN,
			TXINHIBIT 					=> TXINHIBIT_IN,
			TXPOLARITY 					=> L,
			TXRESET 					=> TXRESET_IN,
			TXUSRCLK 					=> i_Q62_5,
			TXUSRCLK2 					=> i_Q62_5,
			CHBONDDONE 					=> open,
			CHBONDO 					=> open,
			CONFIGOUT 					=> CONFIGOUT_OUT,
			RXBUFSTATUS(1 downto 0) 	=> RXBUFSTATUS_OUT(1 downto 0),
			RXCHARISCOMMA(1 downto 0) 	=> RXCHARISCOMMA_OUT(1 downto 0),
			RXCHARISCOMMA(3 downto 2) 	=> RXCHARISCOMMA_float(1 downto 0),
			RXCHARISK(1 downto 0) 		=> RXCHARISK(1 downto 0),
			RXCHARISK(3 downto 2) 		=> RXCHARISK_float(1 downto 0),
			RXCHECKINGCRC 				=> RXCHECKINGCRC_OUT,
			RXCLKCORCNT(2 downto 0) 	=> RXCLKCORCNT_OUT(2 downto 0),
			RXCOMMADET 					=> RXCOMMADET_OUT,
			RXCRCERR 					=> RXCRCERR_OUT,
			RXDATA(15 downto 0) 		=> RXDATA(15 downto 0),
			RXDATA(31 downto 16) 		=> RXDATA_float(15 downto 0),
			RXDISPERR(1 downto 0) 		=> RXDISPERR_OUT(1 downto 0),
			RXDISPERR(3 downto 2) 		=> RXDISPERR_float(1 downto 0),
			RXLOSSOFSYNC(1 downto 0)	=> RXLOSSOFSYNC_OUT(1 downto 0),
			RXNOTINTABLE(1 downto 0)	=> RXNOTINTABLE_OUT(1 downto 0),
			RXNOTINTABLE(3 downto 2)	=> RXNOTINTABLE_float(1 downto 0),
			RXREALIGN 					=> RXREALIGN_OUT,
			RXRECCLK	 				=> RXRECCLK_OUT,
			RXRUNDISP(1 downto 0) 		=> RXRUNDISP_OUT(1 downto 0),
			RXRUNDISP(3 downto 2) 		=> RXRUNDISP_float(1 downto 0),
			TXBUFERR 					=> TXBUFERR_OUT,
			TXKERR(1 downto 0) 			=> TXKERR_OUT(1 downto 0),
			TXKERR(3 downto 2) 			=> TXKERR_float(1 downto 0),
			TXN 						=> TXN_OUT,
			TXP 						=> TXP_OUT,
			TXRUNDISP(1 downto 0) 		=> TXRUNDISP_OUT(1 downto 0),
			TXRUNDISP(3 downto 2) 		=> TXRUNDISP_float(1 downto 0)
		);

-------------------------------------------------------------------------------
end;

