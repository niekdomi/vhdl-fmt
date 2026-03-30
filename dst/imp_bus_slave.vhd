--------------------------------------------------------------------------------
--	imp_bus_slave.vhd
--------------------------------------------------------------------------------
--
--	project		: IMP-BUS Slave
--	programmer	: C. Leuthold, INDEL AG
--	date		: 10.09.2007
--	language	: VHDL
--
--	purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- Rev.: x.00
--	10.09.2007-le : - disc.
--	11.01.2008-le : add to repo
--	05.02.2008-le : change imp crc to a good 6 bit poly for 8-25 bit (find all 1, 2, 3 and 5 bit errors)
--	30.06.2008-SBä: some improvements on error detection
-- Rev.: x.01
--	13.11.2008-le : first module on a IMP-MASp (IMP-8PIN 0) is offlin
--					  IMP-MASp has no continous select start-sequence (bus start
--					  after trigger: __________-----__------__-----...---______)
--					- add a start from SWAIT with LLH select sequence 
-- Rev.: x.02
--	09.03.2009-SBä: Implemented the wdog function for all outputs      
--
-- Rev.: x.03 
--	18.11.2009-SBä: All Telegramms with the lenght of 9 bits and CRC enabled
--					have problems that the startsequence "1001" is followed by 2 L Bits
--					and the CRC. Depending on the CRC (starting with H) a further illegal 1001 
--					Sequence exists that retriggers the module. The module does never answer. 
--
-- 					Solution: 
--					Enhanced startsequence detector by also checking for Ssin 
--					"x00x" while "1001" on select.
--					                                       
--					!!!! A digital Input Module (Type "00") with 1! additional Data Bit inside its 
--					Adresstelegram (Lenght = 9) is impossible now!!!!!! 
--					
--					New Startsequence:
--						      Start|LL|CRC startin with H
--					Sel:		-__-__-XXXX
--					Sin:		x__x11
--								 LL
--                        
--					The above workaround works only at the adresstelegramm. 
--					For 9Bit Datatelegramms even the enhanced startsequence detection 
--					can decode a second startsequence.
--					To solve this the "1001" on the select line is changed to "1000"
--					after detection, so a just following second startsequence is not possible.
--
--					Without monipulation:	1001001		 => two startsequences  
--					With manipulation:		100 1/0 001	 => 
--												 |__ after the first startsequence the bit is changed from 1 to 0
--
--					During jTag transfers the outputs are now disabled by the wdog! Before the outputs stayed constant
--
--					All actual cards with older Revisions do not make a difference or have a problem.
--
-- Rev.: x.04
--	17.12.2009-SBä:	- Added the wdog Pin to be able to use it as a Layout testpoint.
--					- Added the o_add_a_data_ok signal to use the additional adress data
--					  before the end of the telegram

--
-- Rev.: x.05
-- 09.02.2010-SBä   It seems that some old imp-mas can also have 10001 or even 100001 sequence instead
-- 					of the normal 1001 sequence between the Adress and Data Telegramm. The old cards accept this.
--
-- 					This effect was detected at an imp-mas1 with an old Ramtest software.
-- 					By deactivating the ramtest task, the effect gat away. A newly created project run without glitches.
-- 					Up today no complaints from customers are known and no other tested software has shown the same effect.
--
-- 					Due to the simply change the change was done anyway.
-- 					This revision runs also on the troublemaker imp-mas1. 
--					A pause is allowed now between adress and data telegramm. 

--
-- Rev.: x.06
-- 29.11.2010-SBae
-- Inverted the o_wdog. The output was inverted since its introducion in the x.04 version.
-- This has no consequences because the wdog signal was never used to drive logic.
-- The pin is used only as a testpoint in all existing modules.
-- (imp-8pot, imp-6plr, imp-16pot, imp-inc) or completly unused (imp-8pin, imp-16pin, imp-fadc)
--
-- old: o_wdog=H => normal operation     o_wdog=L => wdog occured
-- new: o_wdog=L => normal operation     o_wdog=H => wdog occured
--
-- The new imp-dac and imp-smc uses the x.06 version from the beginning. 
-- There is no need to upgrade any existing module.
-- ONLY EFFECT: The testpin is invertet too on all modules....
-- but this should not be a big problem.

-- 07.06.2011-le
-- rename Return_Upper_F_I_PKG to Return_Upper
-- only a funktion renaming, DF_REVISION is still x.06

-- Rev.: x.07
-- 19.10.2017-le
-- add output o_AddrOk 

--------------------------------------------------------------------------------
--	!!!!! update DF_REVISION !!!!!
--------------------------------------------------------------------------------
--$Rev:: 4598                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-10-23 09:39:12 +0200 (Mo., 23 Okt 2017)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library imp_wdog;
use imp_wdog.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity imp_bus_slave is
	generic (
		C_CARDTYPE : std_logic_vector;
		C_ADDR_DATA_LENGTH : natural range 0 to 5 := 0;
		C_DATA_LENGTH : natural range 2 to 24 := 8;
		C_JTAG_SUPPORT : natural range 0 to 1 := 1;
		C_REVISION : std_logic_vector(7 downto 0) := x"00";
		C_WDOG_SUPPORT : natural range 0 to 1 := 1
	);
	port (
		-------- Address Switch ------------------------------------------------
		ni_AddrJmp : in std_logic := H;
		i_AddrSw : in std_logic_vector(3 downto 0) := (others => L);
		-------- Local field bus -----------------------------------------------
		i_Clk : in std_logic;					-- clock
		i_Sel : in std_logic;					-- select
		i_Sin : in std_logic;					-- serial data input
		o_Sout : out std_logic;					-- serial data output
		o_OE : out std_logic;					-- serial data output Enable
		-- paralell data
		o_add_a_data : out std_logic_vector(Return_Upper(C_ADDR_DATA_LENGTH) downto 0);
		o_add_a_data_ok : out std_logic;
		i_Data : in std_logic_vector(C_DATA_LENGTH-1 downto 0) := (others => H);
		o_Data : out std_logic_vector(C_DATA_LENGTH-1 downto 0);
		o_TrOk : out std_logic;
		o_AddrOk : out std_logic;
		-- I2C from impbus
		o_fb_scl : out std_logic;
		o_fb_sda : out std_logic;
		i_fb_sda : in std_logic := L;
		-- reset
		i_reset : in std_logic := L;
		-- jatg-port
		o_jtagOe : out std_logic;
		o_jtagTCK : out std_logic;
		o_jtagTDI : out std_logic;
		o_jtagTMS : out std_logic;
		i_jtagTDO : in std_logic := L;
		-- dbg
		o_error : out std_logic;
		o_wdog 	: out std_logic;
		o_JtagTrOk : out std_logic
	);
end imp_bus_slave;
--------------------------------------------------------------------------------
architecture imp_bus_slave_dinamic_sm of imp_bus_slave is
-- constants -------------------------------------------------------------------
	constant GNDV : std_logic_vector(3 downto 0) := (others => L);
	constant DF_ADDR_LENGTH : integer := C_CARDTYPE'length +1 + 5 + C_ADDR_DATA_LENGTH;
	
	constant C_MAX_DATA_LNG : integer range 0 to 24 := max(C_DATA_LENGTH, DF_ADDR_LENGTH);
	
	constant DF_REVISION : std_logic_vector(15 downto 0) := C_REVISION & X"07";
	
	constant C_JTAG_EN : integer := 7;
	constant C_JTAG_CNT : integer := C_JTAG_EN + 4;
	
-- types -----------------------------------------------------------------------
	type t_rx_states is (SWAIT, SACMP, SACRCEN, SADATA, SADDRP, SAEND, SDWAIT, SDCRCEN, SDDATA, SDATAP, SDEND);
	type t_tx_states is (STXIDLE, STXDATA, STXP, STXCRC3, STXCRC2, STXCRC1, STXCRC0, STXCRC0_1, SCRCSTOP, SCRCEND);
	type t_jtag_states is (jtag_idle, jtag_enable, jtag_go, jtag_single, jtag_burst);
-- signals ---------------------------------------------------------------------
	
	signal Clk : std_logic;
	signal Sel : std_logic := L;
	signal Sin : std_logic := L;
	signal Sout : std_logic := L;
	signal Sout_en : std_logic := L;
	
	-- states: use save implementation!
	signal rx_state : t_rx_states := SWAIT;
	signal tx_state : t_tx_states := STXIDLE;
	signal jtag_state : t_jtag_states := jtag_idle;
	
	-- count down from data length:
	--	minimum length log2 of C_MAX_DATA_LNG or 16 when jtag is supported
	signal dcnt : std_logic_vector(pkg_log2(max(C_MAX_DATA_LNG,16*C_JTAG_SUPPORT))-1 downto 0) := (others => L);
	
	signal RxP : std_logic := L;
	signal TxP : std_logic := L;
	signal EEPen : std_logic := L;
	signal SR : std_logic_vector(max(C_MAX_DATA_LNG,8*C_JTAG_SUPPORT)-1 downto 0) := (others => L);
	signal DataIn : std_logic_vector(C_DATA_LENGTH-1 downto 0) := (others => L);
	signal DataOut : std_logic_vector(C_DATA_LENGTH-1 downto 0) := (others => L);
	signal TrOk : std_logic := L;
	signal add_a_data_ok : std_logic := L;
	signal add_a_data : std_logic_vector(Return_Upper(C_ADDR_DATA_LENGTH) downto 0) := (others => L);
	signal EEPClk : std_logic := L;
	signal EEPdataOut : std_logic := H;
	signal EEPdataIn : std_logic;
	signal compare : std_logic_vector(C_CARDTYPE'length + 5 downto 0); --cardtype, eeprom and addrswitch
	
	signal errorSel : std_logic := L;
	signal errorSin : std_logic := L;
	signal errorSel1 : std_logic := L;
	signal errorSin1 : std_logic := L;
	signal error : std_logic := L;
	
	signal CRCrx : std_logic_vector(DF_PKG_IMP_CRC_POLY'range) := (others => L);
	signal CRCtx : std_logic_vector(DF_PKG_IMP_CRC_POLY'range) := (others => L);
	signal SelCRC : std_logic_vector(DF_PKG_IMP_CRC_POLY'range);
	signal SelSR : std_logic_vector(6 downto 0) := (others => L);
	signal SinSR : std_logic_vector(1 downto 0) := (others => L); 
	signal CRCen : std_logic := L;
	
	signal RX_CRC_ok : std_logic;
	signal protocoll_Check : std_logic;
	signal start : std_logic;
	
	signal jtag_acc : std_logic := L;
	signal jtag_dataacc : std_logic := L;
	
	signal jtag_cnt : std_logic_vector(3 downto 0) := (others => L);
	signal jtagTCK : std_logic := H;
	signal burst_clk : std_logic := L;
	
	signal jtagOe : std_logic := L;
	signal jtagTMS : std_logic := H;
	signal jtagTDI : std_logic := L;
	signal jtagTCKout : std_logic := L;
	
	signal data_out_E : std_logic := H;
	signal wdog_trigger : std_logic := L;
	
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin								-- of architecture imp_bus_slave_dinamic_sm
-- processes -------------------------------------------------------------------
	
	Clk <= i_Clk;
	o_Sout <= Sout;
	o_OE <= Sout_en;
	o_TrOk <= H when (TrOk=H and jtag_acc=L) else L;
	o_add_a_data_ok <= add_a_data_ok;
	o_error <= error;
	o_wdog <= not data_out_E;
	
	
	o_fb_scl <= EEPClk;
	o_fb_sda <= EEPdataOut;
	EEPdataIn <= i_fb_sda;
	
	compare <= C_CARDTYPE & L & not ni_AddrJmp & i_AddrSw;
	
	DataIn <= i_Data;
	o_Data <= DataOut when data_out_E=H else (others => L);
	
	o_add_a_data <= add_a_data; 
	
	o_jtagOe <= jtagOe;
	o_jtagTMS <= jtagTMS;
	o_jtagTDI <= jtagTDI;
	o_jtagTCK <= jtagTCKout;
	o_JtagTrOk <= H when (TrOk=H and jtag_dataacc=H) else L;
	
	-- error detection
	-- sin and sel are clocked in on falling edge and finaly used on rising edge...
	-- ... but only if during the "clk low time" the i_sin and i_sel are stable!
	-- otherwise the Error signal is set.
	process (Clk)
	begin
		if falling_edge(Clk) then
			Sin <= i_Sin;
			Sel <= i_Sel;
		end if;
	end process;
	
	
	process (i_Sin,rx_state)
	begin
		if rx_state <= SWAIT then
			errorSin1 <= L;
		elsif falling_edge(i_sin) then 
			if (clk = L) then
				errorSin1 <= H;
			end if;
		end if;
	end process;
	
	process (i_Sin,rx_state)
	begin
		if rx_state <= SWAIT then
			errorSin <= L;
		elsif rising_edge(i_sin) then
			if (clk = L) then
				errorSin <= H;
			end if;
		end if;
	end process;
	
	process (i_Sel,rx_state)
	begin
		if rx_state <= SWAIT then
			errorSel1 <= L;
		elsif falling_edge(i_sel) then 
			if (clk = L) then
				errorSel1 <= H;
			end if;
		end if;
	end process;
	
	process (i_Sel,rx_state)
	begin
		if rx_state <= SWAIT then
			errorSel <= L;
		elsif rising_edge(i_sel) then
			if (clk = L) then
				errorSel <= H;
			end if;
		end if;
	end process;
	
	--create a synchron error signal
	process (Clk)
	begin
		if rising_edge(Clk) then
			error <= errorSin1 or errorSin or errorSel1 or errorSel;
		end if;
	end process;
	
	falling_edge_clk : process (Clk)
	begin
		if falling_edge(Clk) then
			-- parity
			if (rx_state=SDWAIT) then -- reset parity
				TxP <= L;
			else -- build parity
				TxP <= ((Sout and not Txp) or (not Sout and Txp));
			end if;
			-- crc
			if (rx_state=SDWAIT) then -- reset crc
				CRCtx <= DF_PKG_IMP_CRC_INIT;
			elsif (tx_state=STXCRC3) then -- shift crc out
				CRCtx <= CRCtx(CRCtx'high-1 downto 0) & L;
			else -- build crc
				CRCtx <= crc_gen(Sout, CRCtx, DF_PKG_IMP_CRC_POLY);
			end if;
		end if;
	end process falling_edge_clk;
	
	-- select input do not include 1001 (starting sequence of a new frame!)
	SelCRC(SelCRC'high-0) <= SelSR(6);
	SelCRC(SelCRC'high-1) <= SelSR(4);
	SelCRC(SelCRC'high-2) <= SelSR(3);
	SelCRC(SelCRC'high-3) <= SelSR(1);
	SelCRC(SelCRC'high-4) <= SelSR(0);
	SelCRC(SelCRC'high-5) <= Sin;
	
	RX_CRC_ok <= H when (SelCRC=CRCRx and CRCen=H) or (CRCen=L and Sin/=RxP) else L;
	protocoll_Check <= H when ((Sel=H and CRCen=L) or ((Sel=L or dcnt<7) and CRCen=H)) and start=L else L;
	
	start <= H when SelSR(2 downto 0)="100" 
				and SinSR(1 downto 0)="00"
				and Sel=H else L;
	
	rising_edge_clk : process (Clk)
	begin
		if rising_edge(Clk) then
			SelSR <= SelSR(SelSR'high-1 downto 0) & Sel;
			SinSR <= SinSR(SinSR'high-1 downto 0) & Sin;
			-- parity
			if (start=H or rx_state=SWAIT) then
				CRCrx <= crc_gen(Sin, DF_PKG_IMP_CRC_INIT, DF_PKG_IMP_CRC_POLY);
				RxP <= Sin;
			else
				CRCrx <= crc_gen(Sin, CRCrx, DF_PKG_IMP_CRC_POLY);
				RxP <= ((Sin and not RxP) or (not Sin and RxP));
			end if;
			-- defaults
			TrOk <= L;
			o_AddrOk <= L;
			add_a_data_ok <= L;
			wdog_trigger <= L;
			rx_state <= SWAIT;
			dcnt <= dcnt - 1;
			case rx_state is
				-- waiting for start of address telegram -----------------------
				when SWAIT =>
					if (SelSR(1 downto 0)="00"
						and SinSR(1 downto 0)="00"
						and Sel=H and Sin=H) then
						
						rx_state <= SACRCEN;
						EEPen <= L;    
						
						if (C_JTAG_SUPPORT=1) then
							jtag_acc <= L;
							jtag_dataacc <= L;
						end if;
					end if;
				-- receive cardtype, eeprom, addressswitch ---------------------
				-- select protocoll
				when SACRCEN =>
					dcnt <= CONV_STD_LOGIC_VECTOR(compare'length - 2, dcnt'length);
					if (Sel=L) then
						CRCen <= H;
					else
						CRCen <= L;
					end if;
					if (compare(compare'high)=Sin) then
						rx_state <= SACMP;
					end if;
				when SACMP =>
					if (protocoll_Check=H) then
						if (dcnt=5) then-- eeprom
							EEPen <= Sin and not CRCen;
							if (C_JTAG_SUPPORT=1) then
								jtag_acc <= Sin and CRCen;
							end if;
							rx_state <= SACMP;
						elsif (compare(CONV_INTEGER(dcnt))=Sin) then
							if (dcnt=0) then
								dcnt <= CONV_STD_LOGIC_VECTOR(C_ADDR_DATA_LENGTH-1,dcnt'length);
								if (C_ADDR_DATA_LENGTH>0 and EEPen=L and jtag_acc=L) then
									rx_state <= SADATA;
								else
									rx_state <= SADDRP;
								end if;
							else
								rx_state <= SACMP;
							end if;
						end if;
					end if;
				-- addr data ---------------------------------------------------
				when SADATA =>
					if (protocoll_Check=H) then
						SR <= SR(SR'high-1 downto 0) & Sin;
						if (dcnt=0) then
							rx_state <= SADDRP;
						else
							rx_state <= SADATA;
						end if;
					end if;
				-- address parity and stopbit ----------------------------------
				when SADDRP =>
					if (Sel=H) then
						if (RX_CRC_ok=H or CRCen=L) then
							rx_state <= SAEND;
							o_AddrOk <= H;
						end if;
					end if;
				-- address frame end -------------------------------------------
				when SAEND =>
					if (Sel=L and Sin=L) then
						if (C_ADDR_DATA_LENGTH>0) then
							add_a_data(C_ADDR_DATA_LENGTH-1 downto 0) <= SR(C_ADDR_DATA_LENGTH-1 downto 0);
							add_a_data_ok <= H;
						end if;
						rx_state <= SDWAIT;
					end if;
				-- data frame start --------------------------------------------
				when SDWAIT =>
					if (Sel=L) then
						rx_state <= SDWAIT;
					elsif (SelSR(1 downto 0)="00"			-- Wait until the Startsign arrives
							and SinSR(1 downto 0)="00"
							and Sel=H and Sin=L) then  
					 
						-- This little dirty trick is necessary for Data Telegramms with the lenght 9.
						-- Actually only IMP-DCM is affected.
						-- The SelSR register is "manipulated" from 1001 to 1000 to avoid a second
						-- 1001 Startsequence which occurs when after the following 2 L the CRC begins with a H! 
						-- Result: Bad Situation : 1001001, =:-/ 
						-- Fixed Situation: 1000001 	 
						if (C_DATA_LENGTH = 9) then
							SelSR <= SelSR(SelSR'high-1 downto 0) & L;
						end if;	
					
					
						rx_state <= SDCRCEN;
						if (EEPen=H) then
							SR(SR'high) <= EEPdataIn;
							SR(SR'high-1) <= EEPClk;
							dcnt <= CONV_STD_LOGIC_VECTOR(1, dcnt'length);
						elsif (jtag_acc=H) then
							dcnt <= CONV_STD_LOGIC_VECTOR(15, dcnt'length);
						else
							SR(SR'high downto SR'high-DataIn'high) <= DataIn;
							dcnt <= CONV_STD_LOGIC_VECTOR(C_DATA_LENGTH-1, dcnt'length);
						end if;
					end if;
				-- receive data ------------------------------------------------
				when SDCRCEN =>
					if (Sel=L) then
						CRCen <= H;
						if (C_JTAG_SUPPORT=1) then
							jtag_dataacc <= jtag_acc;
						end if;
					else
						CRCen <= L;
						if (C_JTAG_SUPPORT=1) then
							jtag_acc <= L;
							jtag_dataacc <= L;
						end if;
					end if;
					rx_state <= SDDATA;
					SR <= SR(SR'high-1 downto 0) & Sin;
				when SDDATA =>
					if (protocoll_Check=H) then
						SR <= SR(SR'high-1 downto 0) & Sin;
						if (dcnt=0) then
							rx_state <= SDATAP;
						else
							rx_state <= SDDATA;
						end if;
					end if;
				-- data parity -------------------------------------------------
				when SDATAP =>
					if (Sel=H) then
						if (RX_CRC_ok=H or CRCen=L) then
							rx_state <= SDEND;
						end if;
					end if;
				-- data frame end ----------------------------------------------
				when SDEND =>
					if (Sel=L and Sin=L) then
						
						if (jtag_dataacc=H and C_JTAG_SUPPORT=1) then
							TrOk <= H;
						elsif (EEPen=H) then
							EEPClk <= SR(0);
							EEPdataOut <= SR(1);
							wdog_trigger <= H;			-- Behave the same as the old ones
						else
							DataOut <= SR(DataOut'range);
							TrOk <= H;
							wdog_trigger <= H;
						end if;
					end if;
					rx_state <= SWAIT;
				when others =>
					rx_state <= SWAIT;
			end case;
			-- sender
			case tx_state is
				when STXIDLE =>
					if (rx_state=SDWAIT 
						and SelSR(1 downto 0)="00"
						and SinSR(1 downto 0)="00"
						and Sel=H and Sin=L) then
						
						--start=H and Sin=L) then
						tx_state <= STXDATA;
						Sout <= L; -- startbit
						Sout_en <= H;
					else
						Sout <= H; 
						Sout_en <= L;
						tx_state <= STXIDLE;
					end if;
				when STXDATA =>
					Sout_en <= H;
					if (jtag_dataacc=H and C_JTAG_SUPPORT=1) then
						if (jtag_State=jtag_idle) then
							Sout <= DF_REVISION(CONV_INTEGER(dcnt(3 downto 0)));
						else
							Sout <= i_jtagTDO;
						end if;
					else
						Sout <= SR(SR'high);
					end if;
					if (dcnt=0) then
						tx_state <= STXP;
					else
						tx_state <= STXDATA;
					end if;
				when STXP =>
					Sout_en <= H;
					if (CRCen=H) then
						Sout <= CRCtx(CRCtx'high);
						tx_state <= STXCRC3;
					else
						Sout <= not TxP;
						tx_state <= SCRCSTOP;
					end if;
				when STXCRC3 =>
					Sout <= CRCtx(CRCtx'high);
					Sout_en <= H;
					tx_state <= STXCRC2;
				when STXCRC2 =>
					Sout <= CRCtx(CRCtx'high);
					Sout_en <= H;
					tx_state <= STXCRC1;
				when STXCRC1 =>
					Sout <= CRCtx(CRCtx'high);
					Sout_en <= H;
					tx_state <= STXCRC0;
				when STXCRC0 =>
					Sout <= CRCtx(CRCtx'high);
					Sout_en <= H;
					tx_state <= STXCRC0_1;
				when STXCRC0_1 =>
					Sout <= CRCtx(CRCtx'high);
					Sout_en <= H;
					tx_state <= SCRCSTOP;
				when SCRCSTOP =>
					Sout <= L;
					Sout_en <= H;
					tx_state <= SCRCEND;
				when SCRCEND =>
					Sout <= H;
					Sout_en <= H;
					tx_state <= STXIDLE;
				when others =>
					Sout <= H; 
					Sout_en <= L;
					tx_state <= STXIDLE;
			end case;
			-- resets
			if (start=H and Sin=H) then		-- New Starting Adresstelegramm
				rx_state <= SACRCEN;
				EEPen <= L;
				if (C_JTAG_SUPPORT=1) then
					jtag_acc <= L;
					jtag_dataacc <= L;
				end if;
			end if;
			if (error=H) then
				rx_state <= SWAIT;
				if tx_state /= STXIDLE then
					tx_state <= SCRCEND;	-- this will force an activ high output on the bus before the high 'Z' state
				else	
					tx_state <= STXIDLE;
				end if;
				jtag_dataacc <= L;
			end if;
		end if;
	end process rising_edge_clk;
	
	in_system_prog : if (C_JTAG_SUPPORT=1) generate
	begin
		jtag_seq: process(Clk)
		begin
			if rising_edge(Clk) then
				if (TrOk=H and jtag_dataacc=H) then
					jtag_cnt <= jtag_cnt + 1;
				end if;
				if (jtag_dataacc=H) then
					case (jtag_State) is
						when jtag_idle =>
							jtag_cnt <= (others => H);
							if (dcnt=C_JTAG_EN and SR(7 downto 0)=x"A5") then
								jtag_State <= jtag_enable;
							end if;
						when jtag_enable =>
							if (dcnt=C_JTAG_CNT) then
								if (SR(3 downto 0)=jtag_cnt) then
									if (jtag_cnt="1111") then
										jtag_State <= jtag_go;
									end if;
								end if;
							end if;
						when jtag_go =>
							if (dcnt=C_JTAG_CNT-1) then
								if (SR(0)=H) then		-- TDI/TDO burst mode
									jtag_State <= jtag_burst;
								else					-- single mode
									jtag_State <= jtag_single;
								end if;
							end if;
						when jtag_burst =>
							if (dcnt=C_JTAG_CNT-1-9) then
								jtag_State <= jtag_go;
							else
								jtagTDI <= Sin;
								jtagTCK <= H;
							end if;
						when jtag_single =>
							if (dcnt=C_JTAG_CNT-1-1) then
								jtagTDI <= Sin;
							elsif (dcnt=C_JTAG_CNT-1-2) then
								jtagTMS <= Sin;
							elsif (dcnt=C_JTAG_CNT-1-3) then
								jtagTCK <= Sin;
							elsif (dcnt=C_JTAG_CNT-1-8) then
								jtag_State <= jtag_go;
								jtagTCK <= Sin;
							end if;
					end case;
					if (dcnt=C_JTAG_CNT) then
						if (SR(3 downto 0)/=jtag_cnt) then
							jtag_State <= jtag_idle;
						end if;
					end if;
				end if;
				if ((jtag_State=jtag_burst or jtag_State=jtag_single or jtag_State=jtag_go)) then
					jtagOe <= H;
				else
					jtagOe <= L;
				end if;
				if (error=H) then
					jtag_State <= jtag_idle;
					jtagOe <= L;
				end if;
			end if;
		end process jtag_seq;
		
		process(Clk)
		begin
			if falling_edge(Clk) then
				if (dcnt=C_JTAG_CNT-1-9) then
					burst_clk <= L;
				elsif (jtag_State=jtag_burst) then
					burst_clk <= H;
				end if;
			end if;
		end process;
		
		jtagTCKout <= not Clk when (burst_clk=H) else jtagTCK;
	end generate in_system_prog;
	
	
	
	
	wdog_sup : if (C_WDOG_SUPPORT=1) generate
		wdog_inst : entity imp_wdog.imp_wdog(arch_imp_wdog) 
		generic map (
			C_COUNTERLENGTH => 14,
			C_INTERNAL_CLOCK => 1
		)
		port map (
			i_Clk => clk,				-- Internal Clock is used
			i_Reset => wdog_trigger,	-- wdogEvent input
			o_DataE  => data_out_E		-- Enable for the Data Outputs
		);
	end generate wdog_sup;
	
	
	
end imp_bus_slave_dinamic_sm;