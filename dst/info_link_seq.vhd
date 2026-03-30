--------------------------------------------------------------------------------
--
--  INFO-LINK Sequencer (slave)
--
--------------------------------------------------------------------------------
--
--  project     : library 
--  programmer  : C. Leuthold, INDEL AG
--  date        : 10.09.2003
--  version     : 02
--  language    : VHDL
--
--  purpose
--
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	18.09.2006-le:	add C_JTAG_SUPPORT for ISP over info-link (rev 01)
--	11.05.2007-le:	add svn keywords
--	25.09.2008-le:	add revision register tt.ss in isp mode (DF_MOD_REVISION=02)
--					tt: is revision of top modul C_REVISION(7..0)
--					ss: is revision of infoSlave DF_MOD_REVISION(7..0)
--------------------------------------------------------------------------------
--$Rev:: 1185                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2009-08-31 10:05:14 +0200 (Mo., 31 Aug 2009)                         $
--------------------------------------------------------------------------------

----- includes -----------------------------------------------------------------
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity info_link_seq is
	generic (
		C_CLK_DIV_22MHZ : integer :=4;	 --88MHz
		C_JTAG_SUPPORT : integer := 0;
		C_REVISION : std_logic_vector(7 downto 0) := x"00"
	);
	port (
		-- std-inputs
		i_clk		: in 	std_logic;
		i_Rst		: in 	std_logic := '0';				-- high-activ
		-- INFO-LINK
		o_Irq       : out	std_logic;
		o_blinki	: out	std_logic;
		o_diagnosis	: out	std_logic;
		o_32bit     : out	std_logic;
		o_Typ2      : out	std_logic;
		o_Typ1      : out	std_logic;
		o_Typ0      : out	std_logic;
		o_Addr7     : out	std_logic;
		o_Addr6     : out	std_logic;
		o_Addr5     : out	std_logic;
		o_Addr4     : out	std_logic;
		o_Addr3     : out	std_logic;
		o_Addr2     : out	std_logic;
		o_Addr1     : out	std_logic;
		o_Addr0     : out	std_logic;
		o_MCok      : out	std_logic;
		o_CIrqEn    : out	std_logic;
		o_Status1	: out 	std_logic;				-- infoLink status-bit
		o_Status0	: out 	std_logic;				-- infoLink status-bit
		o_Data		: out 	STD_LOGIC;

		o_cIrq		: out	std_logic;
		o_cDiagnosis: out	std_logic;
		o_c32bit	: out	std_logic;
		o_cTyp2     : out	std_logic;
		o_cTyp1     : out	std_logic;
		o_cTyp0     : out	std_logic;
		o_cAddr7    : out	std_logic;
		o_cAddr6    : out	std_logic;
		o_cAddr5    : out	std_logic;
		o_cAddr4    : out	std_logic;
		o_cAddr3    : out	std_logic;
		o_cAddr2    : out	std_logic;
		o_cAddr1    : out	std_logic;
		o_cAddr0    : out	std_logic;
		o_cMCok     : out	std_logic;
		o_cCIrqEn   : out	std_logic;
		o_cStatus1	: out 	std_logic;				-- infoLink status-bit
		o_cStatus0	: out 	std_logic;				-- infoLink status-bit
		o_cData32	: out 	STD_LOGIC;
		o_cJATG_start:out	std_logic;
		o_cS35		: out 	STD_LOGIC;
		o_cData16	: out	std_logic;
		o_cS37		: out 	std_logic;
		o_cData		: out	std_logic;
		o_cWrite_D	: out	std_logic;
		o_cReadH	: out	std_logic;
		o_cS52		: out	std_logic;
		o_cDataEnd	: out	std_logic;

		i_diagnosis : in	std_logic;
		i_CardOk    : in	std_logic;
		i_CardIrq   : in	std_logic;
		i_CIrqUnasked: in 	std_logic;
		i_Status1	: in 	std_logic;				-- infoLink status-bit
		i_Status0	: in 	std_logic;				-- infoLink status-bit
		i_Data		: in 	STD_LOGIC;

		i_Err		: in	std_logic;
		-- Eeprom --------------------------------------------------------------
		i_EEPROMen	: in 	std_logic;
		o_EEen      : Out 	std_logic;				-- EEPROM Chipselect
		o_EEclk     : Out 	std_logic;				-- EEPROM Clock
		o_EEd       : Out 	std_logic;				-- EEPROM Data Out
		i_EEd       : In    std_logic;				-- EEPROM Data In
		-- jatg-port
		o_jtagOe : out std_logic;
		o_jtagTCK : out std_logic;
		o_jtagTDI : out std_logic;
		o_jtagTMS : out std_logic;
		i_jtagTDO : in std_logic := '0';
		--
		o_LinkLED	: out	std_logic;          	-- high-activ (H=light)
		o_PowerLED	: out	std_logic;              -- high-activ (H=light)
		i_AddrSwitch: In	std_logic_vector(7 downto 0);
		i_32not16	: in	std_logic;
		i_CardTyp	: In	std_logic_vector(2 downto 0);
		i_CmpEn		: in    std_logic_vector(11 downto 0);
		-- info_link_codec-port ------------------------------------------------
		-- LINK
		i_RX		: in std_logic;				-- info-link input
		o_TX		: out std_logic;			-- info-link output
		--o_txd 		: out std_logic;
		o_rxd 		: out std_logic;
		o_RErr      : out std_logic;
		o_LiErr		: out std_logic;            -- dignosis link-error
		--i_rerr 		: in std_logic;
		--i_paus 		: in std_logic;
		o_BitClk 	: out std_logic;
		o_BitCnt 	: out std_logic_vector(5 downto 0);
		--i_TXp 		: in std_logic;
		--i_LiErr 	: in std_logic;
		o_TrOK 		: out std_logic;
		o_RQq		: out std_logic;
		o_RXq		: out std_logic
	);
end info_link_seq;

architecture behavioral_ils of info_link_seq is
	-- components --------------------------------------------------------------
	-- constants ---------------------------------------------------------------
	-- states
	constant C_IDLE		: integer :=  0;
	constant C_Irq		: integer :=  1;
	constant C_Diag		: integer :=  2;
	constant C_Blink	: integer :=  3;
	constant C_TNr		: integer :=  4;
	constant C_B32		: integer :=  5;
	constant C_TYP2		: integer :=  6;
	constant C_TYP1		: integer :=  7;
	constant C_TYP0		: integer :=  8;
	constant C_ADDR7	: integer :=  9;
	constant C_ADDR6	: integer := 10;
	constant C_ADDR5	: integer := 11;
	constant C_ADDR4	: integer := 12;
	constant C_ADDR3	: integer := 13;
	constant C_ADDR2	: integer := 14;
	constant C_ADDR1	: integer := 15;
	constant C_ADDR0	: integer := 16;
	constant C_CARDOK	: integer := 17;
	constant C_CIRQ 	: integer := 18;
	constant C_Status1	: integer := 19;
	constant C_Status0	: integer := 20;
	constant C_DATASTART: integer := 21;
	constant C_JTAG_PAT	: integer := 28+1;
	constant C_READH	: integer := 32;
	constant C_DATAEND16: integer := 36;
	constant C_JTAG_CNT : integer := 37+4;
	constant C_JTAG_EN : integer := 37+8;
	constant C_EEPROM	: integer := 37;
	constant C_S_EEP_CLK: integer := 40;
	constant C_C_EEP_CLK: integer := 48;
	constant C_DATAEND  : integer := 52;
	constant C_PARITY   : integer := 53;
	constant C_WRITE_D	: integer := 54;
	constant DEF_DATA16B: unsigned(5 downto 0)
						:= TO_UNSIGNED (C_DATAEND16+1, 6);
	
	function x(X : std_logic_vector) return std_logic_vector is
	variable ret_dt : std_logic_vector(X'range) := (others => L);
	begin
		for i in 0 to X'length-1 loop
			ret_dt(i) := X(X'high-i);
		end loop;
		return ret_dt;
	end x;
	constant DF_MOD_REVISION : std_logic_vector(7 downto 0) := x"02";
	-- revision: change bits to get a output highest bit first of DF_REVISION(BitCnt(3..0))
	-- in this case, BitCnt(3..0) starts with 5,6,7.. -> change from fedcba9876543210 to 56789abcdef01234
	constant DF_REVISION : unsigned(15 downto 0) := (unsigned(x(C_REVISION & DF_MOD_REVISION)) rol C_DATASTART);

	component info_link_codec
	generic (
		C_CLK_DIV_22MHZ : integer :=4	 --88MHz
	);
	port (
		-- std-ports
		i_Clk	: in std_logic;                 -- clock
		i_Rst	: in std_logic;                 -- reset
		-- info-link-ports
		-- LINK
		i_RX		: in std_logic;				-- info-link input
		o_TX		: out std_logic;			-- info-link output
		-- codec
		o_RXd		: out std_logic;			-- RX-data output decoded
		i_TXd		: in std_logic;				-- TX-data input decoded
		o_RErr		: out std_logic;			-- RX-Error
		o_Paus		: out std_logic; 			-- Pause
		o_BitClk    : out std_logic;			-- RXCnt(LAST);
		o_BitClk180 : out std_logic;			-- RXCnt(MID);
		i_BitCnt	: in std_logic_vector(5 downto 0); -- from sequenzer
		o_TXp		: out std_logic;           	-- TX parity
		o_LiErr		: out std_logic;            -- dignosis link-error
		o_TrOK		: out std_logic;            -- end of transfer, prity ok
		i_MCOK		: in std_logic;              -- bit CardOk was set from
												-- master -> odd parity
		o_RQq		: out std_logic;
		o_RXq		: out std_logic
	);
	end component;

	-- signals -----------------------------------------------------------------
	signal RXd		: std_logic;
	signal TXd		: std_logic;
	signal RErr		: std_logic;
	signal Sres		: std_logic;
	signal Paus		: std_logic;
	signal BitClk 	: std_logic;
	signal BitClk180: std_logic;
	signal BitCnt	: unsigned(5 downto 0);
	signal EEac		: std_logic;
	signal EEce		: std_logic;
	signal EEen		: std_logic;
	signal EEdo		: std_logic;
	signal TXp		: std_logic;
	signal LiErr	: std_logic;
	signal TrOK		: std_logic;
	signal MCOk		: std_logic;
	signal CmpErr	: std_logic;
	signal B32		: std_logic;
	signal dark		: std_logic;
	signal Rst		: std_logic;
	signal Clk		: std_logic;
	signal l_TX		: std_logic;
	signal l_RX 	: std_logic;
	
	signal jtag_acc : std_logic := L;
	signal jtag_cnt : unsigned(3 downto 0);
	signal jtag_reg : std_logic_vector(7 downto 0);
	type t_jtag_states is (jtag_idle, jtag_enable, jtag_go, jtag_single, jtag_burst);
	signal jtag_state : t_jtag_states := jtag_idle;

begin
	o_BitCnt <= std_logic_vector(BitCnt);
	o_BitClk <= BitClk;
	o_TrOk <= TrOk;
	o_rxd <= Rxd;
	Clk <= i_clk;
	Rst <= i_rst;
	o_Tx <= l_TX;
	l_RX <= i_Rx;
	o_PowerLED <= H;								-- we have power
	Sres <= (RErr or i_Err or CmpErr);
	o_RErr <= RErr;
	o_MCOk <= MCOk;
	o_EEen <= EEen;
	o_EEd <= EEdo;
	o_LinkLED <= not(Dark);						-- Löscht bei Diag&!Blink
	o_32bit <= b32;
	o_LiErr <= LiErr;
	-- StateCounter-------------------------------------------------------------
	--					1		   2		  3			 4		   5
	-- State 01234 5678 90123456 7890 1234567890123456 7890123456789012 34
	--															 54321 0
	-- RXr   0iiiT B011 aAAAAOKK axES DDDDDDDDDDDDDDDD DDDDDDDDDDDDDDDD PE
	--			n 3	   2		1 ny 3				1 1				 0
	--			r 2				   n 1				6 5
	--								 ---------------->
	--								   skip if 16Bit
	----------------------------------------------------------------------------
	StCnt : process(Rst, Clk)
	begin
		if (Rst=H) then											-- init values
			BitCnt <= "000000";
		elsif rising_edge(Clk) then
			if (Sres=H) then
				BitCnt <= "000000"; 					-- ERROR (synchReset)
			elsif BitClk = H then
				if (B32=L) and (BitCnt=C_Status0) then	-- StateCounter 16-Bit
					BitCnt <= DEF_DATA16B;				-- jump to start 16B
				else
					BitCnt <= (BitCnt+1); 						-- StateCounter
				end if;
			end if;
		end if;
	end process;
	-- info_link_sequenzer -----------------------------------------------------
	LINK_TX : process(Rst,  Clk)
	begin
		if (Rst = H) then										-- init values
			TXd <= L;
		elsif rising_edge(Clk) then
			if BitClk = H then
				if    RErr=H			then
					TXd <= L;                           		-- Error
				elsif i_CardOk = H then							-- for ext. cmp
					if BitCnt=C_CARDOK	then
						TXd <= H;								-- card ok
					elsif BitCnt=C_CIRQ 	then
						TXd <= (i_CardIrq and RXd) or i_CIrqUnasked;
					elsif BitCnt=C_STATUS1	then
						TXd <= i_Status1;						-- status 1
					elsif BitCnt=C_STATUS0	then
						TXd <= i_Status0;						-- status 0
					elsif BitCnt>=C_DATASTART and BitCnt<=C_DATAEND then
						if EEac=H and i_EEPROMen=H then 
							TXd <= i_EEd;-- EEPROM data
						elsif jtag_acc=H and C_JTAG_SUPPORT=1 then
							if (jtag_State=jtag_idle) then
								TXd <= DF_REVISION(TO_INTEGER(BitCnt(3 downto 0)));
							else
								TXd <= i_jtagTDO;
							end if;
						else
							TXd <= i_Data;						-- InfoLink data
						end if;
					elsif (BitCnt=C_PARITY) then				-- parity
						TXd <= TXp;
					elsif BitCnt>C_PARITY then
						TXd <= L;                            	-- breack
					else
						TXd <= RXd;							-- 0..16 => 1:1
					end if;
				else
					TXd <= RXd;								--  1:1
				end if;
			end if;
		end if;
	end process;
	-- RXd link ----------------------------------------------------------------
	LINK_RX: process(Rst,  Clk)
	begin
		if (Rst = H) then										-- init values
			o_diagnosis <= L;
			o_blinki <= L;
			o_Irq <= L;
			o_Typ2 <= L;
			o_Typ1 <= L;
			o_Typ0 <= L;
			o_Addr7 <= L;
			o_Addr6 <= L;
			o_Addr5 <= L;
			o_Addr4 <= L;
			o_Addr3 <= L;
			o_Addr2 <= L;
			o_Addr1 <= L;
			o_Addr0 <= L;
			MCok <= L;
			o_CIrqEn <= L;
			o_Status1 <= L;
			o_Status0 <= L;
			o_Data <= L;
			Dark <= L;
			CmpErr <= L;
			EEac <= L;
			o_cIrq <= L;
			o_cDiagnosis <= L;
			o_c32bit <= L;
			o_cTyp2 <= L;
			o_cTyp1 <= L;
			o_cTyp0 <= L;
			o_cAddr7 <= L;
			o_cAddr6 <= L;
			o_cAddr5 <= L;
			o_cAddr4 <= L;
			o_cAddr3 <= L;
			o_cAddr2 <= L;
			o_cAddr1 <= L;
			o_cAddr0 <= L;
			o_cMCok <= L;
			o_cCIrqEn <= L;
			o_cStatus1 <= L;
			o_cStatus0 <= L;
			o_cData32 <= L;
			o_cData16 <= L;
			o_cData <= L;
			o_cWrite_D <= L;
			o_cReadH <= L;
			o_cDataEnd <= L;
			o_cS35 <= L;
			o_cS37 <= L;
			o_cS52 <= L;
			B32 <= L;
			EEen <= L;
			EEce <= L;
			EEdo <= L;
			o_EEclk <= L;
			o_cJATG_start <= L;
		elsif rising_edge(Clk) then
			o_cIrq <= L;
			o_cDiagnosis <= L;
			o_c32bit <= L;
			o_cTyp2 <= L;
			o_cTyp1 <= L;
			o_cTyp0 <= L;
			o_cAddr7 <= L;
			o_cAddr6 <= L;
			o_cAddr5 <= L;
			o_cAddr4 <= L;
			o_cAddr3 <= L;
			o_cAddr2 <= L;
			o_cAddr1 <= L;
			o_cAddr0 <= L;
			o_cMCok <= L;
			o_cCIrqEn <= L;
			o_cStatus1 <= L;
			o_cStatus0 <= L;
			o_cData32 <= L;
			o_cData16 <= L;
			o_cData <= L;
			o_cWrite_D <= L;
			o_cReadH <= L;
			o_cDataEnd <= L;
			o_cS35 <= L;
			o_cS37 <= L;
			o_cS52 <= L;
			o_cJATG_start <= L;
			if Paus = H then
				CmpErr <= L;
			--	EEac <= L;
			elsif BitClk = H then
				if BitCnt=C_Irq			then					-- irq
					o_Irq  <= RXd;
					o_cIrq <= H;
				elsif BitCnt=C_Diag		then					-- diagnosis
					o_diagnosis <= RXd;
					o_cDiagnosis <= H;
					dark <= RXd;
				elsif BitCnt=C_Blink   	then
					o_blinki <= RXd;
					if i_diagnosis=H then
						Dark <= Dark and (not(LiErr) xor RXd);  -- let's blink
					else
						Dark <= L;
					end if;
				elsif BitCnt=C_B32	    then					-- 32bit
					b32	 <= RXd;
					o_c32bit <= H;
					if i_CmpEn(11) = H then
						if RXd/=i_32not16 then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_TYP2		then					-- typ
					o_Typ2  <= RXd;
					o_cTyp2 <= H;
					if i_CmpEn(10) = H then
						if RXd/=i_CardTyp(2) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_TYP1		then
					o_Typ1  <= RXd;
					o_cTyp1 <= H;
					if i_CmpEn(9) = H then
						if RXd/=i_CardTyp(1) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_TYP0		then
					o_Typ0  <= RXd;
					o_cTyp0 <= H;
					if i_CmpEn(8) = H then
						if RXd/=i_CardTyp(0) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR7	then					-- addr.
					o_Addr7 <= RXd;
					o_cAddr7 <= H;
					if i_CmpEn(7) = H then
						if RXd/=i_AddrSwitch(7) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR6	then
					o_Addr6 <= RXd;
					o_cAddr6 <= H;
					if i_CmpEn(6) = H then
						if RXd/=i_AddrSwitch(6) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR5	then
					o_Addr5 <= RXd;
					o_cAddr5 <= H;
					if i_CmpEn(5) = H then
						if RXd/=i_AddrSwitch(5) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR4	then
					o_Addr4 <= RXd;
					o_cAddr4 <= H;
					if i_CmpEn(4) = H then
						if RXd/=i_AddrSwitch(4) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR3	then
					o_Addr3 <= RXd;
					o_cAddr3 <= H;
					if i_CmpEn(3) = H then
						if RXd/=i_AddrSwitch(3) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR2	then
					o_Addr2 <= RXd;
					o_cAddr2 <= H;
					if i_CmpEn(2) = H then
						if RXd/=i_AddrSwitch(2) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR1	then
					o_Addr1 <= RXd;
					o_cAddr1 <= H;
					if i_CmpEn(1) = H then
						if RXd/=i_AddrSwitch(1) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_ADDR0	then
					o_Addr0 <= RXd;
					o_cAddr0 <= H;
					if i_CmpEn(0) = H then
						if RXd/=i_AddrSwitch(0) then CmpErr <= H; end if;
					end if;
				elsif BitCnt=C_CARDOK	then
					MCok  <= RXd;
					o_cMCok <= H;
					if i_EEPROMen=H and i_CardOk=H then
						EEac <= RXd;
					else
						EEac <= L;
					end if;
				elsif BitCnt=C_CIRQ 	then
					o_CIrqEn <= RXd;
					o_cCIrqEn <= H;
				elsif BitCnt=C_Status1	then
					o_Status1 <= RXd;
					o_cStatus1 <= H;
					if EEac=H then
						EEen <= RXd;					-- EEen
					end if;
				elsif BitCnt=C_Status0	then
					o_Status0 <= RXd;
					o_cStatus0 <= H;
					jtag_acc <= L;
					if EEac=H then
						EEce <= RXd;					-- EEce
						if (RXd=L and EEen=L and C_JTAG_SUPPORT=1 ) then
							jtag_acc <= H;
							EEac <= L;
						end if;
					end if;
				elsif BitCnt>=C_DATASTART and BitCnt<=C_DATAEND then
					o_Data  <= RXd;
					o_cData <= H;
					
					if BitCnt=C_JTAG_PAT and C_JTAG_SUPPORT=1 then
						o_cJATG_start <= H;
					end if;
					if BitCnt=C_DATAEND16-1 then
						o_cS35 <= H;
					end if;
					if BitCnt=C_DATAEND16 then
						o_cData16 <= H;
					end if;
					if BitCnt=C_DATAEND16+1 then
						if EEac=H then
							EEdo  <= RXd; 			-- EEdo
						end if;
						o_cS37 <= H;
					end if;
					if BitCnt=C_READH then
						o_cReadH <= H;
					end if;
					if BitCnt=C_DATASTART then
						o_cData32 <= H;
					end if;
					if BitCnt=C_DATAEND-1 then
						o_cS52 <= H;
					end if;
					if BitCnt=C_DATAEND then
						o_cDataEnd <= H;
					end if;
					if (BitCnt=C_S_EEP_CLK)and (EEce=H) and (EEac=H) then
						o_EEclk <= H;
					elsif (BitCnt=C_C_EEP_CLK)and (EEce=H) and (EEac=H) then
						o_EEclk <= L;
					end if;
				elsif BitCnt=C_WRITE_D then
					o_cWrite_D <= H;						-- and TrOk
				end if;
			end if;
		end if;
	end process;
	
	jtag_seq: process(Rst, Clk)
	begin
		if (Rst=H) then
			o_jtagOe <= L;
		elsif rising_edge(Clk) then
			if (TrOk=H and jtag_acc=H) then
				jtag_cnt <= jtag_cnt + 1;
			end if;
			if BitClk=H and C_JTAG_SUPPORT=1 then
				jtag_reg(7 downto 0) <= jtag_reg(6 downto 0) & RXd;
				if (jtag_acc=H) then
				  case (jtag_State) is
					when jtag_idle =>
						jtag_cnt <= (others => H);
						if (BitCnt=C_JTAG_EN and jtag_reg=x"A5") then
							jtag_State <= jtag_enable;
						end if;
					when jtag_enable =>
						if (BitCnt=C_JTAG_CNT) then
							if (unsigned(jtag_reg(3 downto 0))=jtag_cnt) then
								if (jtag_cnt="1111") then
									jtag_State <= jtag_go;
								end if;
							else
								jtag_State <= jtag_idle;
							end if;
						end if;
					when jtag_go =>
						if (BitCnt=C_JTAG_CNT) then
							if (unsigned(jtag_reg(3 downto 0))/=jtag_cnt) then
								jtag_State <= jtag_idle;
							end if;
						elsif (BitCnt=C_JTAG_CNT+1) then
							if (jtag_reg(0)=H) then -- TDI/TDO burst mode
								jtag_State <= jtag_burst;
							else					-- single mode
								jtag_State <= jtag_single;
							end if;
						end if;
					when jtag_burst =>
						if (BitCnt=C_JTAG_CNT+1+9) then
							jtag_State <= jtag_go;
							o_jtagTCK <= H;
						else
							o_jtagTDI <= RXd;
							o_jtagTCK <= L;
						end if;
					when jtag_single =>
						if (BitCnt=C_JTAG_CNT+1+1) then
							o_jtagTDI <= RXd;
						elsif (BitCnt=C_JTAG_CNT+1+2) then
							o_jtagTMS <= RXd;
						elsif (BitCnt=C_JTAG_CNT+1+3) then
							o_jtagTCK <= RXd;
						elsif (BitCnt=C_JTAG_CNT+1+8) then
							jtag_State <= jtag_go;
							o_jtagTCK <= RXd;
						end if;
				  end case;
				end if;
			end if;
			if (jtag_State=jtag_burst and BitClk180=H and C_JTAG_SUPPORT=1 ) then
				o_jtagTCK <= H;
			end if;
			if ((jtag_State=jtag_burst or jtag_State=jtag_single or jtag_State=jtag_go) and C_JTAG_SUPPORT=1 ) then
				o_jtagOe <= H;
			else
				o_jtagOe <= L;
			end if;
			
		end if;
	end process jtag_seq;
	
	ilcodec1: info_link_codec
	generic map(
		C_CLK_DIV_22MHZ => C_CLK_DIV_22MHZ
	)
	PORT MAP(
		i_Clk		=> Clk,
		i_Rst		=> Rst,
		i_RX		=> l_RX,
		o_TX		=> l_TX,
		o_RXd		=> RXd,
		i_TXd		=> txd,
		o_RErr		=> rerr,
		o_Paus		=> paus,
		o_BitClk	=> BitClk,
		o_BitClk180	=> BitClk180,
		i_BitCnt	=> std_logic_vector(BitCnt),
		o_TXp		=> TXp,
		o_LiErr		=> LiErr,
		o_TrOK		=> TrOK,
		i_MCOK		=> MCok,
		o_RQq		=> o_RQq,
		o_RXq		=> o_RXq
	);
end behavioral_ils;