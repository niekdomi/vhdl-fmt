---------------------------------------------------------------------------
--
--  MII Sequencer for the BCM5482 dual Phy
--
---------------------------------------------------------------------------
--
--  project     : Ethernet Phy MII 
--  programmer  : F:Baschung, INDEL AG
--  date        : 10.07.2006
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose              
--		- MII Interface for both Phy 0 and 1
--  	- Read Eth Status 
--		- Write LED1/2 On/Off
--		- send MII commands form PPC 
--
---------------------------------------------------------------------------
                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
--	09.10.2008-FB	erste Version
--	16.12.2008-le	- GE_MIISeq: add generic C_ADDR_4_1 for phyaddr4..1
--						ppc-card4-eth-HW0: 0000 , ppc-card4-eth-HWA: 0001
--	18.12.2008-le	- GE_MIISeq: cange generic C_ADDR_4_1 default to 0001
--	18.12.2008-le : - add svn keywords
--	18.05.2011-le : - avoid synthesis warnings:
--						use own if statment for clk_en
--	07.06.2011-le : - replace speedselect input with a generic interface
--	01.02.2013-le : - add generic C_PHY to support others then BCM5482
--					- add BCM54610
--	26.11.2013-le : - add BCM54210 and disable EEE support to avoid very long 
--						linkdelays if two Phys connected together with EEE 
--						support.
--	20.10.2015-qfu: - Extended the functionality to support the "high address range"
--						 of the parts BCM54616 and BCM54210 when more than two PHY's are
--						 used AD=24, AD=25(additional generic "C_ADDR_H_EN").
--	15.12.2015-le : - expand CFG_PHY_BCM5482 to 0..20 with dummies
--	10.02.2016-le : - (20.11.2015-qfu:) extended to disable EEE for the higher address range to.
--	06.09.2016-le : - add o_linkStateN: filtered linkstatus from o_PhyN_LineStat(2)
--------------------------------------------------------------------------------
--$Rev:: 4031                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-09-06 15:04:59 +0200 (Di., 06 Sep 2016)                         $
--------------------------------------------------------------------------------

entity GE_MIISeq is
	generic (
		C_ADDR_4_1     : std_logic_vector(4 downto 1) := "0001";
		C_ADDR_H_EN    : natural  := 0; --0=no add. PHY, 1=+1 PHY, 2=+2 PHY's, max. total=4 PHY's.
		C_PHY          : string := "BCM5482"
	);
	port (
		i_Q62_5			: IN  std_logic;

		o_MII_Clk		: OUT std_logic := '0';
		o_MII_Dout		: OUT std_logic := '0';
		o_MII_T			: OUT std_logic := '0';
		o_MII_Dinp		: IN  std_logic;
		
		i_Phy0_LED1		: IN  std_logic := '0';	-- green
		i_Phy0_LED2		: IN  std_logic := '0';	-- yellow

		i_Phy1_LED1		: IN  std_logic := '0';	-- green
		i_Phy1_LED2		: IN  std_logic := '0'; -- yellow
		
		i_Phy2_LED1		: IN  std_logic := '0';	-- green
		i_Phy2_LED2		: IN  std_logic := '0'; -- yellow
		
		i_Phy3_LED1		: IN  std_logic := '0';	-- green
		i_Phy3_LED2		: IN  std_logic := '0'; -- yellow
		
		o_Phy0_LineStat	: OUT std_logic_vector(15 downto 0) := x"0000";
		o_Phy1_LineStat	: OUT std_logic_vector(15 downto 0) := x"0000";
		o_Phy2_LineStat	: OUT std_logic_vector(15 downto 0) := x"0000";
		o_Phy3_LineStat	: OUT std_logic_vector(15 downto 0) := x"0000";
		
		o_Phy0_LEDStat : OUT std_logic_vector(15 downto 0) := x"0000";
		o_Phy1_LEDStat : OUT std_logic_vector(15 downto 0) := x"0000";
		o_Phy2_LEDStat : OUT std_logic_vector(15 downto 0) := x"0000";
		o_Phy3_LEDStat : OUT std_logic_vector(15 downto 0) := x"0000";
		
		o_linkState0 : out std_logic := L;
		o_linkState1 : out std_logic := L;
		o_linkState2 : out std_logic := L;
		o_linkState3 : out std_logic := L;
		
		i_PhyX : in std_logic_vector(31 downto 0) := x"00000000";
		o_PhyX : OUT std_logic_vector(15 downto 0) := x"0000";
		o_XDone : out std_logic
		
    );
end;    

architecture impl of GE_MIISeq is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
	signal	Prescaler	: std_logic_vector( 5 downto 0) := "000000";
	signal	Q12MHz		: std_logic := '0';

--------------------------------------------------------------------------------
    type tGE_MII_Seq is (
    	sIdle,
    	sRdLineStat_0,sWaitLineStat_0,
    	sRdLineStat_1,sWaitLineStat_1,
		sRdLineStat_2,sWaitLineStat_2,
		sRdLineStat_3,sWaitLineStat_3,
    	sWrLED1_0,sWaitLED1_0,
    	sWrLED2_0,sWaitLED2_0,
    	sWrLED1_1,sWaitLED1_1,
    	sWrLED2_1,sWaitLED2_1,
		sWrLED1_2,sWaitLED1_2,
    	sWrLED2_2,sWaitLED2_2,
		sWrLED1_3,sWaitLED1_3,
    	sWrLED2_3,sWaitLED2_3,
    	sWrLEDStat_0,sWaitWrLEDStat_0,
    	sWrLEDStat_1,sWaitWrLEDStat_1,
		sWrLEDStat_2,sWaitWrLEDStat_2,
		sWrLEDStat_3,sWaitWrLEDStat_3,
    	sRdLEDStat_0,sWaitRdLEDStat_0,
    	sRdLEDStat_1,sWaitRdLEDStat_1,
		sRdLEDStat_2,sWaitRdLEDStat_2,
		sRdLEDStat_3,sWaitRdLEDStat_3,
		sDisEEE0,sDisEEE1,sDisEEE2,sDisEEE3,
		sDis_H_EEE0,sDis_H_EEE1,sDis_H_EEE2,sDis_H_EEE3,
    	sWrX,sWaitWrX,
    	sRdX,sWaitRdX
    );
    
    type tGE_MII_SerSeq is (
    	sIdle,sPRE,sStOpAdReg,sRead,sWrite
    );

	signal	GE_MII_Seq	: tGE_MII_Seq 	:= sIdle;
	signal	GE_MII_SerSeq		: tGE_MII_SerSeq 		:= sIdle;

	signal	MII_Cnt		: std_logic_vector( 4 downto 0) := "00000";
	
	signal	MII_Data	: std_logic_vector(31 downto 0) := x"00000000";
	signal	MII_ClkEn	: std_logic := L;
	signal	MII_Run		: std_logic := L;
	signal	MII_Rd		: std_logic := L;
	
--------------------------------------------------------------------------------
--	Configuration
--------------------------------------------------------------------------------

	constant Phy0_RdLineStat  : integer := 0;
	constant Phy1_RdLineStat  : integer := 1;
	constant Phy0_WrLED1_OFF  : integer := 2;
	constant Phy0_WrLED1_ON   : integer := 3;
	constant Phy1_WrLED1_OFF  : integer := 4;
	constant Phy1_WrLED1_ON   : integer := 5;
	constant Phy0_WrLED2_OFF  : integer := 6;
	constant Phy0_WrLED2_ON   : integer := 7;
	constant Phy1_WrLED2_OFF  : integer := 8;
	constant Phy1_WrLED2_ON   : integer := 9;
	constant Phy0_WrLEDStatus : integer := 10;
	constant Phy1_WrLEDStatus : integer := 11;
	constant Phy0_RdLEDStatus : integer := 12;
	constant Phy1_RdLEDStatus : integer := 13;
	
	constant Phy2_RdLineStat  : integer := 14;
	constant Phy2_WrLED1_OFF  : integer := 15;
	constant Phy2_WrLED1_ON   : integer := 16;
	constant Phy2_WrLED2_OFF  : integer := 17;
	constant Phy2_WrLED2_ON   : integer := 18;
	constant Phy2_WrLEDStatus : integer := 19;
	constant Phy2_RdLEDStatus : integer := 20;
	
	constant Phy3_RdLineStat  : integer := 21;
	constant Phy3_WrLED1_OFF  : integer := 22;
	constant Phy3_WrLED1_ON   : integer := 23;
	constant Phy3_WrLED2_OFF  : integer := 24;
	constant Phy3_WrLED2_ON   : integer := 25;
	constant Phy3_WrLEDStatus : integer := 26;
	constant Phy3_RdLEDStatus : integer := 27;
	
	
	constant C_ADDR_4_1_H     : std_logic_vector(4 downto 1):= (C_ADDR_4_1 OR "1100"); -- We need to check further PHY's...
	
	constant CFG_PHY_BCM5482 : tSLV_Nx32(0 to 27) := (
		--  STOP 			  AAAAARRRRRZZddddDDDDddddDDDD 
		"0110" & C_ADDR_4_1 & "000001000000000000000000",--Phy0_RdLineStat 
		"0110" & C_ADDR_4_1 & "100001000000000000000000",--Phy1_RdLineStat 
		"0101" & C_ADDR_4_1 & "011100101011010000011110",--Phy0_WrLED1_OFF 
		"0101" & C_ADDR_4_1 & "011100101011010000011111",--Phy0_WrLED1_ON  
		"0101" & C_ADDR_4_1 & "111100101011010000011110",--Phy1_WrLED1_OFF 
		"0101" & C_ADDR_4_1 & "111100101011010000011111",--Phy1_WrLED1_ON  
		"0101" & C_ADDR_4_1 & "011100101011100011100011",--Phy0_WrLED2_OFF 
		"0101" & C_ADDR_4_1 & "011100101011100011110011",--Phy0_WrLED2_ON  
		"0101" & C_ADDR_4_1 & "111100101011100011100011",--Phy1_WrLED2_OFF 
		"0101" & C_ADDR_4_1 & "111100101011100011110011",--Phy1_WrLED2_ON  
		                       -- reg 0x1c shadow 001000 --
		"0101" & C_ADDR_4_1 & "011100100010000000000000",--Phy0_WrLEDStatus  
		"0101" & C_ADDR_4_1 & "111100100010000000000000",--Phy1_WrLEDStatus  
		"0110" & C_ADDR_4_1 & "011100000010000000000000",--Phy0_RdLEDStatus  
		"0110" & C_ADDR_4_1 & "111100000010000000000000", --Phy1_RdLEDStatus
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000",
		x"00000000"
	);
	

	
		constant CFG_PHY_BCM54610_210 : tSLV_Nx32(0 to 27) := (
		--  STOP 		   AAAAARRRRRZZddddDDDDddddDDDD 
		"0110" & C_ADDR_4_1 & "000001000000000000000000",--Phy0_RdLineStat 
		"0110" & C_ADDR_4_1 & "100001000000000000000000",--Phy1_RdLineStat
		-- reg 0x1c shadow 01100
		"0101" & C_ADDR_4_1 & "011100101011010011101110",--Phy0_WrLED1_OFF 
		x"00000000",--Phy0_WrLED1_ON  
		"0101" & C_ADDR_4_1 & "111100101011010011101110",--Phy1_WrLED1_OFF 
		x"00000000",--Phy1_WrLED1_ON  
		x"00000000",--Phy0_WrLED2_OFF 
		x"00000000",--Phy0_WrLED2_ON  
		x"00000000",--Phy1_WrLED2_OFF 
		x"00000000",--Phy1_WrLED2_ON  
		-- reg 0x1c shadow 001000
		"0101" & C_ADDR_4_1 & "011100100010000000000000",--Phy0_WrLEDStatus  
		"0101" & C_ADDR_4_1 & "111100100010000000000000",--Phy1_WrLEDStatus  
		"0110" & C_ADDR_4_1 & "011100000010000000000000",--Phy0_RdLEDStatus  
		"0110" & C_ADDR_4_1 & "111100000010000000000000", --Phy1_RdLEDStatus
		
		"0110" & C_ADDR_4_1_H & "000001000000000000000000",--Phy2_RdLineStat
		"0101" & C_ADDR_4_1_H & "011100101011010011101110",--Phy2_WrLED1_OFF
		x"00000000",--Phy2_WrLED1_ON
		x"00000000",--Phy2_WrLED2_OFF 
		x"00000000",--Phy2_WrLED2_ON
		"0101" & C_ADDR_4_1_H & "011100100010000000000000",--Phy2_WrLEDStatus
		"0110" & C_ADDR_4_1_H & "011100000010000000000000",--Phy2_RdLEDStatus
		
		"0110" & C_ADDR_4_1_H & "100001000000000000000000",--Phy3_RdLineStat
		"0101" & C_ADDR_4_1_H & "111100101011010011101110",--Phy3_WrLED1_OFF
		x"00000000",--Phy3_WrLED1_ON
		x"00000000",--Phy3_WrLED2_OFF 
		x"00000000",--Phy3_WrLED2_ON
		"0101" & C_ADDR_4_1_H & "111100100010000000000000",--Phy3_WrLEDStatus
		"0110" & C_ADDR_4_1_H & "111100000010000000000000" --Phy3_RdLEDStatus
	);

	
	function get_PHY_reg(phy : string; reg : integer) return std_logic_vector is
	begin
		-- string compare do not work with case statement!
		if (phy="BCM5482") then
			return std_logic_vector(CFG_PHY_BCM5482(reg));
		elsif (phy="BCM54210") then
			return std_logic_vector(CFG_PHY_BCM54610_210(reg));
		elsif (phy="BCM54610") then
			assert 1<0
			report "phy BCM54610 wird eigentlich nirgens eingesetzt und durch BCM54210 ersetzt! falls doch kÃ¶nnen diese zeilen gelÃ¶scht werden." severity FAILURE;
			return std_logic_vector(CFG_PHY_BCM54610_210(reg));
		else
			assert 1<0
			report "unsupported phy" severity FAILURE;
		end if;
		return x"00000000";
	end function get_PHY_reg;
	

	constant CfgPhy0_RdLineStat : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_RdLineStat );
	constant CfgPhy1_RdLineStat : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_RdLineStat );
	constant CfgPhy0_WrLED1_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_WrLED1_OFF );
	constant CfgPhy0_WrLED1_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_WrLED1_ON  );
	constant CfgPhy1_WrLED1_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_WrLED1_OFF );
	constant CfgPhy1_WrLED1_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_WrLED1_ON  );
	constant CfgPhy0_WrLED2_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_WrLED2_OFF );
	constant CfgPhy0_WrLED2_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_WrLED2_ON  );
	constant CfgPhy1_WrLED2_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_WrLED2_OFF );
	constant CfgPhy1_WrLED2_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_WrLED2_ON  );
	constant CfgPhy0_WrLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_WrLEDStatus);
	constant CfgPhy1_WrLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_WrLEDStatus);
	constant CfgPhy0_RdLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy0_RdLEDStatus);
	constant CfgPhy1_RdLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy1_RdLEDStatus);
	
	-----
	-----
	constant CfgPhy2_RdLineStat : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_RdLineStat );
	constant CfgPhy2_WrLED1_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_WrLED1_OFF );
	constant CfgPhy2_WrLED1_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_WrLED1_ON  );
	constant CfgPhy2_WrLED2_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_WrLED2_OFF );
	constant CfgPhy2_WrLED2_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_WrLED2_ON  );
	constant CfgPhy2_WrLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_WrLEDStatus);
	constant CfgPhy2_RdLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy2_RdLEDStatus);
	
	constant CfgPhy3_RdLineStat : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_RdLineStat );
	constant CfgPhy3_WrLED1_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_WrLED1_OFF );
	constant CfgPhy3_WrLED1_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_WrLED1_ON  );
	constant CfgPhy3_WrLED2_OFF : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_WrLED2_OFF );
	constant CfgPhy3_WrLED2_ON  : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_WrLED2_ON  );
	constant CfgPhy3_WrLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_WrLEDStatus);
	constant CfgPhy3_RdLEDStatus : std_logic_vector(31 downto 0) 	:= get_PHY_reg(C_PHY, Phy3_RdLEDStatus);
	-----
	-----
	
	
	                                                                  --fedc           ba98   765432 10 fedcba9876543210
	constant CfgPhy0_WrDisableEEE0 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1 & b"001101_10_0000000000000111";
	constant CfgPhy0_WrDisableEEE1 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1 & b"001110_10_0000000000111100";
	constant CfgPhy0_WrDisableEEE2 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1 & b"001101_10_0100000000000111";
	constant CfgPhy0_WrDisableEEE3 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1 & b"001110_10_0000000000000000";
	
	-- We have to disable the EEE modi for the high PHY address range, too.
	constant CfgPhy2_WrDisableEEE0 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1_H & b"001101_10_0000000000000111";
	constant CfgPhy2_WrDisableEEE1 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1_H & b"001110_10_0000000000111100";
	constant CfgPhy2_WrDisableEEE2 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1_H & b"001101_10_0100000000000111";
	constant CfgPhy2_WrDisableEEE3 : std_logic_vector(31 downto 0) 	:= "0101" & C_ADDR_4_1_H & b"001110_10_0000000000000000";
	
	signal phyaddr : std_logic := L;
	signal phyaddr_high : std_logic := L;
	
	signal Phy0_LineStat	: std_logic_vector(15 downto 0) := (others => L);
	signal Phy1_LineStat	: std_logic_vector(15 downto 0) := (others => L);
	signal Phy2_LineStat	: std_logic_vector(15 downto 0) := (others => L);
	signal Phy3_LineStat	: std_logic_vector(15 downto 0) := (others => L);
	
	signal linkState0_fi : std_logic_vector(2 downto 0) := (others => L);
	signal linkState1_fi : std_logic_vector(2 downto 0) := (others => L);
	signal linkState2_fi : std_logic_vector(2 downto 0) := (others => L);
	signal linkState3_fi : std_logic_vector(2 downto 0) := (others => L);
	
	signal GE_MIIdone : std_logic := L; 
	
--------------------------------------------------------------------------------	
begin -- of architecture GE_MIISeq    
--------------------------------------------------------------------------------

	o_Phy0_LineStat <= Phy0_LineStat;
	o_Phy1_LineStat <= Phy1_LineStat;
	o_Phy2_LineStat <= Phy2_LineStat;
	o_Phy3_LineStat <= Phy3_LineStat;
	
	
	
	linkState_fiter : process(i_Q62_5)
	begin
		if rising_edge(i_Q62_5) then
			if (GE_MIIdone=H) then
				linkState0_fi <= linkState0_fi(linkState0_fi'high-1 downto 0) & Phy0_LineStat(2);
				linkState1_fi <= linkState1_fi(linkState1_fi'high-1 downto 0) & Phy1_LineStat(2);
				linkState2_fi <= linkState2_fi(linkState1_fi'high-1 downto 0) & Phy2_LineStat(2);
				linkState3_fi <= linkState3_fi(linkState1_fi'high-1 downto 0) & Phy3_LineStat(2);
				if (linkState0_fi=0) then
					o_linkState0 <= L;
				elsif (linkState0_fi=((2**linkState0_fi'length)-1)) then
					o_linkState0 <= H;
				end if;
				if (linkState1_fi=0) then
					o_linkState1 <= L;
				elsif (linkState1_fi=((2**linkState1_fi'length)-1)) then
					o_linkState1 <= H;
				end if;
				if (linkState2_fi=0) then
					o_linkState2 <= L;
				elsif (linkState2_fi=((2**linkState2_fi'length)-1)) then
					o_linkState2 <= H;
				end if;
				if (linkState3_fi=0) then
					o_linkState3 <= L;
				elsif (linkState3_fi=((2**linkState3_fi'length)-1)) then
					o_linkState3 <= H;
				end if;
			end if;
		end if;
	end process linkState_fiter;

--------------------------------------------------------------------------------
--	62.5MHz = 16ns
--	
--			       0 1 2 3 4 0
--	Q62_5	_-_-_-_-_-_-_-_-_-_-_-_
--	Q12		_______--________--____
--	MDC		_------____------____--
--			  48   32
--	12.5MHz = 80ns
--	MDC high/low min 30ns
--
--------------------------------------------------------------------------------
--	62.5MHz / 5 = 12.5MHz
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
    	
    	    if (Prescaler >= 4) then
				Prescaler <= "000000";
    	    else
				Prescaler <= Prescaler + 1;
    	    end if; 

		end if;	
    end process;

--------------------------------------------------------------------------------
--	12.5MHz puls
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
    	
    	    if (Prescaler = 3) then
				Q12MHz <= H;
    	    else
				Q12MHz <= L;
    	    end if; 

		end if;	
    end process;

--------------------------------------------------------------------------------
--	MII_Clock
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 

			if (Prescaler = 1)
			or (Prescaler = 2) 
			or (Prescaler = 3) then
				o_MII_Clk <= MII_ClkEn;
			else
				o_MII_Clk <= L;
			end if;	
			    	    
		end if;	
    end process;

--------------------------------------------------------------------------------
--	GE_MII_SerSequencer
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then
			GE_MIIdone <= L;
			o_XDone <= L;
    		if (Q12MHz=H) then 
    	    	
    	    	MII_Cnt 	<= MII_Cnt -1;
				o_MII_Dout	<= L;
				o_MII_T		<= L;
            	--------------------------------------------------------------------
				--
            	--------------------------------------------------------------------
	   			case (GE_MII_Seq) is 
				when sIdle =>	---	Idle, ------------------------------------------
					GE_MIIdone <= H;
					if (C_PHY="BCM54210") then
						if ((C_ADDR_H_EN /= 0) and (phyaddr_high = '1')) then
							MII_Data <= CfgPhy2_WrDisableEEE0;
							GE_MII_Seq <= sDis_H_EEE0;
						else
							MII_Data <= CfgPhy0_WrDisableEEE0;
							GE_MII_Seq <= sDisEEE0;
						end if;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
					else
						GE_MII_Seq <= sRdLineStat_0;
					end if;
					
				when sDisEEE0 =>
					if (MII_Run = L) then
						MII_Data <= CfgPhy0_WrDisableEEE1;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
						GE_MII_Seq <= sDisEEE1; 
					end if;
				when sDisEEE1 =>
					if (MII_Run = L) then
						MII_Data <= CfgPhy0_WrDisableEEE2;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
						GE_MII_Seq <= sDisEEE2; 
					end if;
				when sDisEEE2 =>
					if (MII_Run = L) then
						MII_Data <= CfgPhy0_WrDisableEEE3;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
						GE_MII_Seq <= sDisEEE3; 
					end if;
				when sDisEEE3 =>
					if (MII_Run = L) then
						phyaddr <= not(phyaddr);
						if (phyaddr = '1') then
							phyaddr_high <= not(phyaddr_high);
						end if;
						GE_MII_Seq <= sRdLineStat_0;
					end if;
					-----------
					-----------
				when sDis_H_EEE0 =>
					if (MII_Run = L) then
						MII_Data <= CfgPhy2_WrDisableEEE1;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
						GE_MII_Seq <= sDis_H_EEE1; 
					end if;
				when sDis_H_EEE1 =>
					if (MII_Run = L) then
						MII_Data <= CfgPhy2_WrDisableEEE2;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
						GE_MII_Seq <= sDis_H_EEE2; 
					end if;
				when sDis_H_EEE2 =>
					if (MII_Run = L) then
						MII_Data <= CfgPhy2_WrDisableEEE3;
						MII_Data(23) <= phyaddr;
						MII_Rd <= L;
						MII_Run <= H;
						GE_MII_Seq <= sDis_H_EEE3; 
					end if;
				when sDis_H_EEE3 =>
					if (MII_Run = L) then
						phyaddr <= not(phyaddr);
						if (phyaddr = '1') then
							phyaddr_high <= not(phyaddr_high);
						end if;
						GE_MII_Seq <= sRdLineStat_0;
					end if;
					-----------
					-----------
				when sRdLineStat_0 =>	---	read line status -----------------------
					MII_Data <= CfgPhy0_RdLineStat;
					MII_Rd <= H;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLineStat_0;
            	
				when sWaitLineStat_0 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						Phy0_LineStat <= MII_Data(15 downto 0);     
	        	        GE_MII_Seq <= sRdLineStat_1;
					end if;
            	
				when sRdLineStat_1 =>	---	read line status -----------------------
					MII_Data <= CfgPhy1_RdLineStat;
					MII_Rd <= H;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLineStat_1;
            	
				when sWaitLineStat_1 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						Phy1_LineStat <= MII_Data(15 downto 0);
						if ((C_ADDR_H_EN = 1) OR (C_ADDR_H_EN = 2)) then
							GE_MII_Seq <= sRdLineStat_2;
						else
							GE_MII_Seq <= sWrLED1_0;
						end if;
					end if;
            	
				-----
			   -----
				when sRdLineStat_2 =>	---	read line status -----------------------
					MII_Data <= CfgPhy2_RdLineStat;
					MII_Rd <= H;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLineStat_2;
            	
				when sWaitLineStat_2 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						Phy2_LineStat <= MII_Data(15 downto 0);     
						if (C_ADDR_H_EN = 2) then
	        	        GE_MII_Seq <= sRdLineStat_3;
						ELSE
						  GE_MII_Seq <= sWrLED1_0;
						end if;
					end if;
					
				when sRdLineStat_3 =>	---	read line status -----------------------
					MII_Data <= CfgPhy3_RdLineStat;
					MII_Rd <= H;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLineStat_3;
            	
				when sWaitLineStat_3 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						Phy3_LineStat <= MII_Data(15 downto 0);     
	        	        GE_MII_Seq <= sWrLED1_0;
					end if;
	        -----
           ----		
            	
				when sWrLED1_0 =>	---	write LED1 ---------------------------------
					if (C_PHY="BCM54610" or C_PHY="BCM54210") then
						MII_Data <= CfgPhy0_WrLED1_OFF;
						MII_Data(0) <= i_Phy0_LED1;
						MII_Data(4) <= i_Phy0_LED2;
						GE_MII_Seq <= sWaitLED2_0;
					else
						if (i_Phy0_LED1 = H) then
							MII_Data <= CfgPhy0_WrLED1_ON;
	        			else
							MII_Data <= CfgPhy0_WrLED1_OFF;
	        			end if;
	        			GE_MII_Seq <= sWaitLED1_0;
	        		end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	      
            	    
				when sWaitLED1_0 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then    
	        	        GE_MII_Seq <= sWrLED2_0;
					end if;
            	    
				when sWrLED2_0 =>	---	write LED1 ---------------------------------
					if (i_Phy0_LED2 = H) then
						MII_Data <= CfgPhy0_WrLED2_ON;
        			else
						MII_Data <= CfgPhy0_WrLED2_OFF;
        			end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLED2_0;  
            	    
				when sWaitLED2_0 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then    
	        	        GE_MII_Seq <= sWrLED1_1;
					end if;
            	    
            	
				when sWrLED1_1 =>	---	write LED1 ---------------------------------
					if (C_PHY="BCM54610" or C_PHY="BCM54210") then
						MII_Data <= CfgPhy1_WrLED1_OFF;
						MII_Data(0) <= i_Phy1_LED1;
						MII_Data(4) <= i_Phy1_LED2;
						GE_MII_Seq <= sWaitLED2_1;
					else
						if (i_Phy1_LED1 = H) then
							MII_Data <= CfgPhy1_WrLED1_ON;
	        			else
							MII_Data <= CfgPhy1_WrLED1_OFF;
	        			end if;
	        			GE_MII_Seq <= sWaitLED1_1; 
	        		end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	     
            	    
				when sWaitLED1_1 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then    
	        	        GE_MII_Seq <= sWrLED2_1;
					end if;
            	    
				when sWrLED2_1 =>	---	write LED1 ---------------------------------
					if (i_Phy1_LED2 = H) then
						MII_Data <= CfgPhy1_WrLED2_ON;
        			else
						MII_Data <= CfgPhy1_WrLED2_OFF;
        			end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLED2_1;  
            	    
				when sWaitLED2_1 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then
						if ((C_ADDR_H_EN = 1) OR (C_ADDR_H_EN = 2)) then
	        	        GE_MII_Seq <= sWrLED1_2;
						ELSE
						  GE_MII_Seq <= sWrLEDStat_0;
						end if;
					end if;

				when sWrLED1_2 =>	---	write LED1 ---------------------------------
					if (C_PHY="BCM54610" or C_PHY="BCM54210") then
						MII_Data <= CfgPhy2_WrLED1_OFF;
						MII_Data(0) <= i_Phy2_LED1;
						MII_Data(4) <= i_Phy2_LED2;
						GE_MII_Seq <= sWaitLED2_2;
					else
						if (i_Phy2_LED1 = H) then
							MII_Data <= CfgPhy2_WrLED1_ON;
	        			else
							MII_Data <= CfgPhy2_WrLED1_OFF;
	        			end if;
	        			GE_MII_Seq <= sWaitLED1_2; 
	        		end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	     
            	    
				when sWaitLED1_2 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then    
	        	        GE_MII_Seq <= sWrLED2_2;
					end if;
            	    
				when sWrLED2_2 =>	---	write LED1 ---------------------------------
					if (i_Phy2_LED2 = H) then
						MII_Data <= CfgPhy2_WrLED2_ON;
        			else
						MII_Data <= CfgPhy2_WrLED2_OFF;
        			end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLED2_2;  
            	    
				when sWaitLED2_2 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then
						if (C_ADDR_H_EN = 2) then				
							GE_MII_Seq <= sWrLED1_3;
						ELSE
							GE_MII_Seq <= sWrLEDStat_0;
						end if;
					end if;
					
				when sWrLED1_3 =>	---	write LED1 ---------------------------------
					if (C_PHY="BCM54610" or C_PHY="BCM54210") then
						MII_Data <= CfgPhy3_WrLED1_OFF;
						MII_Data(0) <= i_Phy3_LED1;
						MII_Data(4) <= i_Phy3_LED2;
						GE_MII_Seq <= sWaitLED2_3;
					else
						if (i_Phy3_LED1 = H) then
							MII_Data <= CfgPhy3_WrLED1_ON;
	        			else
							MII_Data <= CfgPhy3_WrLED1_OFF;
	        			end if;
	        			GE_MII_Seq <= sWaitLED1_3; 
	        		end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	     
            	    
				when sWaitLED1_3 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then    
	        	        GE_MII_Seq <= sWrLED2_3;
					end if;
            	    
				when sWrLED2_3 =>	---	write LED1 ---------------------------------
					if (i_Phy3_LED2 = H) then
						MII_Data <= CfgPhy3_WrLED2_ON;
        			else
						MII_Data <= CfgPhy3_WrLED2_OFF;
        			end if;
					MII_Rd <= L;
					MII_Run <= H;			
            	    GE_MII_Seq <= sWaitLED2_3;  
            	    
				when sWaitLED2_3 =>	---	wait till write-end ------------------------
					if (MII_Run = L) then
	        	        GE_MII_Seq <= sWrLEDStat_0;
					end if;	
				
				when sWrLEDStat_0 =>	---	read led status -----------------------
					MII_Data <= CfgPhy0_WrLEDStatus;
					MII_Rd <= L;
					MII_Run <= H;
					GE_MII_Seq <= sWaitWrLEDStat_0;
				when sWaitWrLEDStat_0 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						GE_MII_Seq <= sWrLEDStat_1;
					end if;
				when sWrLEDStat_1 =>	---	read led status -----------------------
					MII_Data <= CfgPhy1_WrLEDStatus;
					MII_Rd <= L;
					MII_Run <= H;
					GE_MII_Seq <= sWaitWrLEDStat_1;
				when sWaitWrLEDStat_1 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						if ((C_ADDR_H_EN = 1) OR (C_ADDR_H_EN = 2)) then
						  GE_MII_Seq <= sWrLEDStat_2;
						ELSE
						  GE_MII_Seq <= sRdLEDStat_0;
						end if;
					end if;
					
				when sWrLEDStat_2 =>	---	read led status -----------------------
					MII_Data <= CfgPhy2_WrLEDStatus;
					MII_Rd <= L;
					MII_Run <= H;
					GE_MII_Seq <= sWaitWrLEDStat_2;
				when sWaitWrLEDStat_2 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						if (C_ADDR_H_EN = 2) then
							GE_MII_Seq <= sWrLEDStat_3;
						ELSE
							GE_MII_Seq <= sRdLEDStat_0;
						end if;
						
					end if;
					
				when sWrLEDStat_3 =>	---	read led status -----------------------
					MII_Data <= CfgPhy3_WrLEDStatus;
					MII_Rd <= L;
					MII_Run <= H;
					GE_MII_Seq <= sWaitWrLEDStat_3;
				when sWaitWrLEDStat_3 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then
						-- save LineStatus
						GE_MII_Seq <= sRdLEDStat_0;
					end if;	
					
				when sRdLEDStat_0 =>	---	read led status -----------------------
					MII_Data <= CfgPhy0_RdLEDStatus;
					MII_Rd <= H;
					MII_Run <= H;
					GE_MII_Seq <= sWaitRdLEDStat_0;
				when sWaitRdLEDStat_0 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						o_Phy0_LEDStat <= MII_Data(15 downto 0);
						if ((C_ADDR_H_EN = 1) OR (C_ADDR_H_EN = 2)) then
						  GE_MII_Seq <= sRdLEDStat_2;
						ELSE
						  GE_MII_Seq <= sRdLEDStat_1;
						end if;
					end if;
					
				when sRdLEDStat_2 =>	---	read led status -----------------------
					MII_Data <= CfgPhy2_RdLEDStatus;
					MII_Rd <= H;
					MII_Run <= H;
					GE_MII_Seq <= sWaitRdLEDStat_2;
				when sWaitRdLEDStat_2 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						o_Phy2_LEDStat <= MII_Data(15 downto 0);
						if (C_ADDR_H_EN = 2) then
							GE_MII_Seq <= sRdLEDStat_3;
						else
							GE_MII_Seq <= sRdLEDStat_1;
						end if;
					end if;
					
				when sRdLEDStat_3 =>	---	read led status -----------------------
					MII_Data <= CfgPhy3_RdLEDStatus;
					MII_Rd <= H;
					MII_Run <= H;
					GE_MII_Seq <= sWaitRdLEDStat_3;
				when sWaitRdLEDStat_3 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						o_Phy3_LEDStat <= MII_Data(15 downto 0);
						GE_MII_Seq <= sRdLEDStat_1;
					end if;

					
				when sRdLEDStat_1 =>	---	read led status -----------------------
					MII_Data <= CfgPhy1_RdLEDStatus;
					MII_Rd <= H;
					MII_Run <= H;
					GE_MII_Seq <= sWaitRdLEDStat_1;
				when sWaitRdLEDStat_1 =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						-- save LineStatus
						o_Phy1_LEDStat <= MII_Data(15 downto 0);
						
						if (i_PhyX(31 downto 28) = "0101") then --write and read
							GE_MII_Seq <= sWrX;
						elsif (i_PhyX(31 downto 28) = "0110") then  -- read only
							GE_MII_Seq <= sRdX;
						else
							GE_MII_Seq <= sidle;
						end if;
					end if;
					
				when sWrX =>	---	read led status -----------------------
					MII_Data <= "0101" & i_PhyX(27 downto 18) & "10" & i_PhyX(15 downto 0);
					MII_Rd <= L;
					MII_Run <= H;
					GE_MII_Seq <= sWaitWrX;
				when sWaitWrX =>	---	wait till write-end ---------------------
					if (MII_Run = L) then    
						GE_MII_Seq <= sRdX;
					end if;
				when sRdX =>	---	read line status -----------------------
					MII_Data <= "0110" & i_PhyX(27 downto 18) & "00" & x"0000";
					MII_Rd <= H;
					MII_Run <= H;
					GE_MII_Seq <= sWaitRdX;
				when sWaitRdX =>	---	wait till read-end ---------------------
					if (MII_Run = L) then    
						o_PhyX <= MII_Data(15 downto 0);
						o_XDone <= H;
						GE_MII_Seq <= sidle;
					end if;

			when others => null;
				end case;
            	
            	--------------------------------------------------------------------
				-- 	MII serial sequencer
            	--------------------------------------------------------------------
	   			case (GE_MII_SerSeq) is 
				when sIdle =>	---	Idle, wait to PktStart -------------------------
					MII_ClkEn <= L;
					MII_Cnt <= "11111";
					if (MII_Run = H) then
						MII_ClkEn <= H;
					    GE_MII_SerSeq <= sPRE;
					end if;
	    						   
				when sPRE =>	---	preamble ---------------------------------------
					o_MII_Dout <= H;
					if (MII_Cnt > 0) then
					else
						MII_Cnt <= "01101";
					    GE_MII_SerSeq <= sStOpAdReg;
					end if;
	    						   
				when sStOpAdReg =>	---	St Op Ad Reg -------------------------------
            	    -- serial shift IO
					o_MII_Dout <= MII_Data(31);
					MII_Data(31 downto 1) <= MII_Data(30 downto 0);
					MII_Data(0) <= o_MII_Dinp;
					
					if (MII_Cnt > 0) then
					else
						MII_Cnt <= "10001";
						if (MII_Rd = H) then
						    GE_MII_SerSeq <= sRead;
						else
						    GE_MII_SerSeq <= sWrite;
						end if;    
					end if;
            	
				when sRead =>	---	TA and Read ------------------------------------
            	    -- serial shift IO
					o_MII_Dout <= MII_Data(31);
					MII_Data(31 downto 1) <= MII_Data(30 downto 0);
					MII_Data(0) <= o_MII_Dinp;
					
					o_MII_T 	 <= H;	-- z while Read
					
					if (MII_Cnt > 0) then
					else
						MII_Run <= L;
					    GE_MII_SerSeq <= sIdle;
					end if;
            	
				when sWrite =>	---	TA and Wrte ------------------------------------
            	    -- serial shift IO
					o_MII_Dout <= MII_Data(31);
					MII_Data(31 downto 1) <= MII_Data(30 downto 0);
					MII_Data(0) <= L;
					
					if (MII_Cnt > 0) then
					else    
						MII_Run <= L;
					    GE_MII_SerSeq <= sIdle;
					end if;
					
				end case;
			end if;
		end if;	
    end process;



--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
