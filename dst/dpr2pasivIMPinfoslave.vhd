--------------------------------------------------------------------------------
--
--  INFO-LINK-Slave for pasiv IMP
--
--------------------------------------------------------------------------------
--
--  project	 : VirtexIIpro
--  programmer  : C. Leuthold, INDEL AG
--  date		: 11.05.2004
--  version	 : 1.00
--  language	: VHDL
--  system	  : ISE / EDK
--
--  purpose
--
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 1.00
--	01.03.2006-le : - lib adjustments to repository
--
-- 1.01
--	19.09.2006-le : - change jtag over infolink to infoSlave (new protocol!!!)
--	11.05.2007-le : - add svn keywords
--	26.02.2009-le : - clear all extrajobs after linkdown and set all pots to 0
--					  to avoid watchdog hanger at last module.
-- 2.02
--	04.05.2010-le : - remove some comment
--	18.05.2010-le : - implemet std. isp over infolink:
--					  rev. now  MASp.ilslave_module
--					- add config for 8/16 pinpot
--					- add module status register
--					- send a last dummy addr job. the last imp-module need it 
--					  to release the watchdog
--					- remove IOStatus of 16p jop
--------------------------------------------------------------------------------
--$Rev:: 1435                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2010-05-21 12:46:48 +0200 (Fr., 21 Mai 2010)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- slave components
library infoSlave;
use infoSlave.info_link_seq;

entity dpr2pasivIMPinfoslave is
	generic (
		C_CLK_DIV_22MHZ : integer :=3;				--66MHz
		C_REVISION		: std_logic_vector(7 downto 0) := x"02"	-- masp rev 2.xx
	);
	port (
		-- std-ports
		i_Clk		: in	std_logic;
		i_Rst		: in	std_logic;
		-- dprPORT
		o_dprEN		: out	std_logic;
		o_dprClk	: out	std_logic;
		o_dprRst	: out	std_logic;
		o_dprData	: out	std_logic_vector(31 downto 0);
		i_dprData	: in	std_logic_vector(31 downto 0);
		o_dprAddr	: out	std_logic_vector(7 downto 0);
		o_dprWEN	: out	std_logic_vector(3 downto 0);
		-- INFO-LINK
		i_RX		: In	std_logic;
		o_TX		: Out	std_logic;
		--
		no_LinkLED	: out	std_logic;
		no_PowerLED : out	std_logic;
		o_start_sBus: out	std_logic;
		i_AddrSwitch: in	std_logic_vector(7 downto 0);
		i_cycle_end : in	std_logic;
		-- JTAG-port
		o_JTAG_EN	: out	std_logic;
		o_TCK		: out	std_logic;
		o_TDI		: out	std_logic;
		o_TMS		: out	std_logic;
		i_TDO		: in	std_logic;
		-- eeprom
		o_eep_cs	: out	std_logic;
		o_eep_clk	: out	std_logic;
		o_eep_D		: out	std_logic;
		i_eep_D		: in	std_logic;
		-- testpoints
		TP1			: out	std_logic;
		TP2			: out	std_logic;
		TP3			: out	std_logic;
		TP4			: out	std_logic
	);
end dpr2pasivIMPinfoslave;

architecture Behavioral of dpr2pasivIMPinfoslave is
	-- constants ---------------------------------------------------------------
	constant H					: std_logic := '1';
	constant L					: std_logic := '0';
	constant Z					: std_logic := 'Z';
	constant DF_READ			: std_logic := '1';
	constant DF_WRITE			: std_logic := '0';
	constant ADDR_RESET			: std_logic_vector(5 downto 0) := "000000";
	constant T_DELAY			: time := 5 ns;

	constant CARD_TYP_UNI		: std_logic_vector := "000";	-- pasiv imp
	constant CARD_TYP_IO		: std_logic_vector := "010";	-- io's
	constant CARD_TYP_START		: std_logic_vector := "001";	-- sBus start
	-- types -------------------------------------------------------------------
	type t_state is (idle, write_last, preread, read, check_Addr, write_IO, write_Init); --read_IO
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
	signal AddrSwitch_1	: std_logic_vector(7 downto 0);
	signal AddrSwitch_plus8 : std_logic_vector(7 downto 0);
	-- signals for info-link
	signal TrOk			: std_logic;
	signal TXData		: std_logic;
	signal RXd			: std_logic;
	signal BitClk		: std_logic;
	signal WDcnt		: std_logic_vector(18 downto 0);
	signal WDog			: std_logic;
	signal cStatus1		: std_logic;
	signal RXStatus1	: std_logic;
	signal RXStatus0	: std_logic;
	signal n_LinkLED	: std_logic;
	signal B32			: std_logic;
	signal State		: t_state;
	signal Reg			: std_logic_vector(32 downto 0);
	signal cAddr0		: std_logic;
	signal CardOk		: std_logic;
	signal shift		: std_logic;
	signal cDataEnd		: std_logic;
	signal cDiagnosis	: std_logic;
	signal dprAddr		: std_logic_vector(o_dprAddr'range);
	signal fill_uni_jobs: std_logic;
	signal pAddr		: std_logic_vector(5 downto 0);
	signal RErr			: std_logic;
	signal LiErr		: std_logic;
	signal dprEN		: std_logic;
	signal Addr20		: std_logic_vector(2 downto 0);
	signal Addr20x		: std_logic_vector(2 downto 0);
	signal synch_job	: std_logic;
	signal n_first_cycle: std_logic;
	signal WDsave		: std_logic;
	signal data_out		: std_logic_vector(31 downto 0);
	signal data_in		: std_logic_vector(31 downto 0);
	signal dprWEN		: std_logic_vector(3 downto 0);
	signal clk			: std_logic;
	signal loc_i_eep_D	: std_logic;
	signal cS35			: std_logic;
	signal MCok			: std_logic;
	signal wd_clear		: std_logic := L;
	
	signal Inputs		: std_logic_vector(15 downto 0);
	
	signal cfg_flags	: std_logic_vector(15 downto 0) := (others => L);
	signal impIO16n8	: std_logic := L;
	signal impIO16n8_ini : std_logic := L;
	signal new_cfg : std_logic := L;
	signal cycle_end : std_logic;
	signal imp_status : std_logic_vector(31 downto 0) := (others => L);
	signal cardstatus : std_logic_vector(3 downto 0) := (others => L);
begin
	CardTyp <= CARD_TYP_UNI;
	CmpEn(11 downto 0) <= "000000000000";	-- compare : nothing
	Low <= L;
	High <= H;
	RX <= i_RX;
	o_TX <= TX;
	n_LinkLED <= not(LinkLED) or WDog;	--i_Wdog;
	no_LinkLED <= n_LinkLED;			-- link LED
	no_PowerLED <= L;					-- power LED
	AddrSwitch_plus8 <= AddrSwitch + 8;
	o_start_sBus <= (synch_job and TrOK) or wd_clear;
	clk <= i_Clk after 1 ps;

	TP1 <= CardOk;
	TP2 <= dprEN;
	TP3 <= new_cfg;
	TP4 <= impIO16n8;

	loc_i_eep_D <= i_eep_D;
	process(Addr20x,AddrSwitch)
	begin
		if Addr20x=AddrSwitch(2 downto 0) then
			Addr20 <= "000";
		elsif Addr20x=AddrSwitch(2 downto 0)+"001" then
			Addr20 <= "001";
		elsif Addr20x=AddrSwitch(2 downto 0)+"010" then
			Addr20 <= "010";
		elsif Addr20x=AddrSwitch(2 downto 0)+"011" then
			Addr20 <= "011";
		elsif Addr20x=AddrSwitch(2 downto 0)+"100" then
			Addr20 <= "100";
		elsif Addr20x=AddrSwitch(2 downto 0)+"101" then
			Addr20 <= "101";
		elsif Addr20x=AddrSwitch(2 downto 0)+"110" then
			Addr20 <= "110";
		else
			Addr20 <= "111";
		end if;
	end process;
	-- dpr
	o_dprRst <= i_Rst;
	o_dprClk <= i_Clk;
	o_dprAddr <= dprAddr;
	o_dprEN <= dprEN;
	o_dprData <= data_out;
	o_dprWEN <= dprWEN;
	data_in <= i_dprData;
	
	impIO16n8_ini <= cfg_flags(7 downto 0)(CONV_INTEGER(pAddr(5 downto 3)));
	
	dpr : process(clk, i_Rst)
	begin
		if i_Rst = H then
			dprAddr <= (others => '0');
			data_out <= (others => '0');
			dprWEN <= (others => '0');
			Reg <= (others => '0');
			pAddr <= ADDR_RESET;
			dprEN <= L;
			state <= idle;
			shift <= L;
			TXData <= L;
			CardOk <= L;
			synch_job <= L;
			fill_uni_jobs<= L;
			n_first_cycle<= L;
			WDsave <= L;
			wd_clear <= L;
			cfg_flags <=  (others => '0');
			new_cfg <= L;
		elsif rising_edge(clk) then
			AddrSwitch_1 <= i_AddrSwitch;
			dprWEN <= (others => '0');
			dprEN <= L;
			wd_clear <= L;
			if fill_uni_jobs=H then
				-- clear if link error untli fill dpr
				fill_uni_jobs <= not(LiErr);
			end if;
			if CardOk=H then
				-- clear if link error
				CardOk <= not(RErr);
			end if;
			if wdog = H then
				WDsave <= H;
			end if;
			cycle_end <= i_cycle_end;
			if (cycle_end=H and i_cycle_end=H) then
				n_first_cycle <= H;
			end if;
			case state is
			  when idle =>
				if B32=H then -- 32 bit telegram -------------------------------
					-- address compare -----------------------------------------
					if cAddr0=H then
						synch_job <= L;
						-- Reg(10..8)	= TYP(2..0)
						-- Reg(7..0)	= InfoAddr(7..0)
						if AddrSwitch(7 downto 0)=Reg(7 downto 0) and Reg(10 downto 8)=CARD_TYP_UNI then
							CardOk <= H;
						else
							CardOk <= L;
						end if;
					end if;
					-- write to dpr --------------------------------------------
					if TrOK=H and CardOk=H and MCok=L then
						if (fill_uni_jobs=H) then
							dprAddr(dprAddr'high) <= DF_WRITE;		-- !r/w
							dprAddr(6) <= H;			-- universal/!IO
							dprAddr(5 downto 1) <= pAddr(4 downto 0);	-- offset
							dprAddr(0) <= not(Reg(31));	-- !addr/data
							data_out <= Reg(31 downto 0);
							dprWEN <= "1111";
							dprEN <= H;
							pAddr <= pAddr + 1;
							CardOk <= L;
							if (RXStatus0=H) then -- last
								state <= write_last;
							end if;
						else
							--register access
							if (Reg(31)=H)then -- write enable 
								if (Reg(30 downto 28)=1) then -- addr 1
									cfg_flags <= Reg(15 downto 0);
									if (cfg_flags/=Reg(15 downto 0)) then
										new_cfg <= H;
									end if;
								elsif (Reg(30 downto 28)=2) then -- addr 2
								end if;
							end if;
						end if;
					end if;
					-- read from dpr -------------------------------------------
					if cStatus1=H and CardOk=H and MCok=L then
						if RXStatus1=H then			-- restart/first job
							fill_uni_jobs <= H;		-- enable fill dpr
							pAddr <= ADDR_RESET;	-- pAddr = 0
							dprAddr(dprAddr'high) <= DF_READ;	-- !r/w
							dprAddr(6) <= L;			--
							dprAddr(5) <= H;			-- universal/!IO
							dprAddr(4 downto 0) <= ADDR_RESET(4 downto 0);	-- offset
							dprEN <= H;
							state <= preread;
						elsif fill_uni_jobs=H then
							dprAddr(dprAddr'high) <= DF_READ;	-- !r/w
							dprAddr(6) <= L;			--
							dprAddr(5) <= H;			-- universal/!IO
							dprAddr(4 downto 0) <= pAddr(4 downto 0);		-- offset
							dprEN <= H;
							state <= preread;
						else
							--dprAddr <= Reg(24 downto 17);
							--dprEN <= H;
							--state <= preread;
							Reg(32 downto 1) <= imp_status;
							imp_status <= (others => L);
						end if;
					end if;
					--register access
					if cS35=H and CardOk=H and MCok=L then
						if (Reg(13 downto 11)=1) then -- addr 1
							Reg(32 downto 17) <= cfg_flags;
						elsif (Reg(30 downto 28)=2) then
						end if;
					end if;
				else -- 16 bit telegram ----------------------------------------
					-- address compare -----------------------------------------
					if cAddr0=H then
						synch_job <= L;
						-- Reg(10..8)	= TYP(2..0)
						-- Reg(7..0)	= InfoAddr(7..0)
						if Reg(10 downto 8)=CARD_TYP_IO and Reg(7 downto 0)>=AddrSwitch and Reg(7 downto 0)<(AddrSwitch_plus8) then
							-- set address to rx-data of IOs (offset is 4*addr(0..2))
							dprAddr(dprAddr'high) <= DF_READ;	-- !r/w
							dprAddr(dprAddr'high-1) <= L;		--
							dprAddr(dprAddr'high-2) <= L;		-- universal/!IO
							dprAddr(4 downto 2) <= Addr20;		-- offset
							dprAddr(1 downto 0) <= "00";
							dprEN <= H;
							impIO16n8 <= cfg_flags(7 downto 0)(CONV_INTEGER(addr20));
							state <= check_Addr;
						elsif Reg(10 downto 8)=CARD_TYP_START and Reg(7 downto 0)="11111111" then
							-- last infolink job 0x1FF8 start IMP Bus
							if WDsave=H then	-- link down => reset outputs and universal jobs
								state <= write_Init;
								pAddr <= (others => L);
								WDsave <= L;
							else
								synch_job <= H;
							end if;
						end if;
					end if;
					-- read from dpr -------------------------------------------
					if cStatus1=H and CardOk=H then				-- read from dpr
						for i in 0 to 3 loop
							if (impIO16n8=H and i<2) then
								imp_status(CONV_INTEGER(addr20 & "00") + i) <= cardstatus(i+2);-- both byte are ok
							else
								imp_status(CONV_INTEGER(addr20 & "00") + i) <= cardstatus(i);
							end if;
						end loop;
						Reg(32 downto 17) <= Inputs;
					end if;
					-- write to dpr --------------------------------------------
					if TrOK=H and CardOk=H and RXStatus1=L then
						if (impIO16n8=L) then -- 2*8pot
							-- set address to tx-data of the first Output (offset is 8*addr(0..2))
							dprAddr(dprAddr'high) <= DF_WRITE;	-- !r/w
							dprAddr(6) <= L;					-- universal/!IO
							dprAddr(5 downto 3) <= Addr20;		-- offset
							dprAddr(2 downto 0) <= "011";		-- lower 8 outputs
							data_out <= x"08" & Reg(7 downto 0) & x"0000";
							data_out(29) <= cfg_flags(8); --crc
							state <= write_IO;
						else -- 1*16pot
							-- set address to tx-data of the first Output (offset is 8*addr(0..2))
							dprAddr(dprAddr'high) <= DF_WRITE;	-- !r/w
							dprAddr(6) <= L;					-- universal/!IO
							dprAddr(5 downto 3) <= Addr20;		-- offset
							dprAddr(2 downto 0) <= "011";		-- lower 8 outputs
							data_out <= x"10" & Reg(15 downto 0) & x"00";
							data_out(29) <= H;
						end if;
						dprWEN <= "1111";
						dprEN <= H;
					end if;
				end if;
				if (i_cycle_end=H and new_cfg=H) then
					pAddr <= (others => L);
					state <= write_Init;
				end if;
			when write_IO =>
				-- set address to tx-data of the second Output (offset is 8*addr(0..2))
				dprAddr(dprAddr'high) <= DF_WRITE;	-- !r/w
				dprAddr(6) <= L;			-- universal/!IO
				dprAddr(5 downto 3) <= Addr20;		-- offset
				dprAddr(2 downto 0) <= "111";		-- higher 8 outputs
				data_out <= x"08" & Reg(15 downto 8) & x"0000";
				data_out(29) <= cfg_flags(8); --crc
				dprWEN <= "1111";
				dprEN <= H;
				state <= idle;
			when write_Init =>
				n_first_cycle <= L;
				dprAddr(6) <= L;
				dprAddr(5 downto 0) <= pAddr;
				dprEN <= H;
				pAddr <= pAddr + 1;
				dprAddr(dprAddr'high) <= DF_WRITE;
				--		2*8pin/8pot		16pin/16pot and dummy jobs for same timing
				--0x00	0x88000000		0xA8000000
				--0x01	0x08000000		0x30000000
				--0x02	0x88400000		0xA8400000
				--0x03	0x08000000		0x30000000
				--0x04	0x88010000		0x84F00000
				--0x05	0x08000000		0x04F00000
				--0x06	0x88410000		0x84F00000
				--0x07	0x08000000		0x04F00000
				dprWEN <= "1111";
				data_out(31 downto 0) <= (others => L);
				if (impIO16n8_ini=L) then -- 8pin/pot
					data_out(31) <= not pAddr(0); -- addr/data tel
					data_out(29) <= cfg_flags(8); --crc
					data_out(27) <= H; -- lng 8
					if (pAddr(1 downto 0) = "10") then -- pot
						data_out(22) <= H;
					end if;
					if (pAddr(0)=L) then -- addr tel
						data_out(19 downto 16) <= pAddr(5 downto 2); -- cardaddr
					end if;
				else -- 16pin/pot
					data_out(31) <= not pAddr(0); -- addr/data tel
					if (pAddr(2)=L) then -- 16pinpot
						data_out(29) <= H; --crc
						if (pAddr(1 downto 0) = "10") then -- pot
							data_out(22) <= H;
						end if;
						if (pAddr(0)=L) then -- addr tel
							data_out(27) <= H; -- lng 8
							data_out(19 downto 16) <= pAddr(5 downto 2); -- cardaddr (even only, to avoid conflicts with 8io modules)
						else -- data tel
							data_out(28) <= H; -- lng 16
						end if;
					else --dummy 
						data_out(26) <= H; -- lng 4
						data_out(23) <= H; -- send data
						data_out(22) <= H; -- send data
						data_out(21) <= H; -- send data
						data_out(20) <= H; -- send data
					end if;
				end if;
				if (pAddr="111111") then
					state <= idle;
					new_cfg <= L;
					
					if (new_cfg=L) then -- called from wdog
						-- do it
						wd_clear <= H; -- start bus
						state <= write_last; -- clear (first) universal jobs
						--pAddr <= (others => L); allready done by adr++
					end if;
				end if;
			when check_Addr =>
				-- read 2 input and 2 output imp-module rx-data
				-- it's my 16p-job if one or more of this 4 imp-module
				-- is online (no parity or frame error: data (27..26))
				if (data_in(25)=L and data_in(26)=L and data_in(27)=L) then
					CardOk <= n_first_cycle;
					cardstatus <= H & cardstatus(3 downto 1);
				else
					cardstatus <= L & cardstatus(3 downto 1);
				end if;
				if dprEN = H then
					dprEN <= H;
					dprAddr(1 downto 0) <= dprAddr(1 downto 0) + 1;
					if (impIO16n8=L) then -- 2*8pot
						if dprAddr(1 downto 0)="00" then
							-- 1.	like preread, data not valid
							CardOk <= L;
							cardstatus <= (others => L);
						elsif dprAddr(1 downto 0)="01" then -- rd 00
							-- 2.	check status and read data of first IMP-8PIN
							-- set lower 8 inputs
							Inputs(7 downto 0) <= data_in(7 downto 0);
						elsif dprAddr(1 downto 0)="11" then -- rd 10
							-- set higher 8 inputs
							Inputs(15 downto 8) <= data_in(7 downto 0);
							dprEN <= L;
						end if;
					else -- 1*16pot
						if dprAddr(1 downto 0)="00" then
							-- 1.	like preread, data not valid
							CardOk <= L;
							cardstatus <= (others => L);
						else--if dprAddr(1 downto 0)="01" then -- rd 00
							-- 2.	check status and read data of first IMP-8PIN
							-- set inputs
							Inputs <= data_in(15 downto 0);
							dprEN <= L;
						end if;
					end if;
				else
					state <= idle;
				end if;
			when preread =>
				state <= read;
			when read =>
				Reg(32 downto 1)<= data_in;
				state <= idle;
			when write_last =>
				-- send a last dummy addr job. the last imp-module need it to release the watchdog
				dprAddr(dprAddr'high) <= DF_WRITE;		-- !r/w
				dprAddr(6) <= H;						-- universal/!IO
				dprAddr(5 downto 1) <= pAddr(4 downto 0);-- offset
				dprAddr(0) <= L;						-- address job
				data_out <= x"82FFFFFF";
				dprWEN <= "1111";
				dprEN <= H;
				fill_uni_jobs <= L;						-- disable fill dpr
				if fill_uni_jobs=L then
					dprAddr(dprAddr'high) <= DF_WRITE;		-- !r/w
					dprAddr(6) <= H;						-- universal/!IO
					dprAddr(5 downto 1) <= pAddr(4 downto 0);-- offset
					dprAddr(0) <= H;						-- data job
					data_out <= (others => H);			-- 0x1fxxxxxx -> imp bus seq. wait on this addr
					dprWEN <= "1111";
					dprEN <= H;
					state <= idle;
				end if;
			end case;
			-- infolink sr
			if BitClk=H and shift=H then
				Reg(Reg'left downto 1)<= Reg(Reg'left-1 downto 0);
				Reg(0) <= RXd;
				TXData <= Reg(Reg'left);
			end if;
			if cDataEnd=H then
				shift <= L;
			end if;
			if cDiagnosis=H then
				AddrSwitch <= AddrSwitch_1;
				shift <= H;
			end if;
		end if;
	end process;
	-- WatchDog ----------------------------------------------------------------
	WDog <= WDcnt(18);								-- WDog after 3.97 ms
	lassie : process (i_Clk, i_Rst) begin
		if (i_Rst = H) then							-- reset values
			WDcnt <= (others => '0');
		elsif rising_edge(i_Clk) then
			if TrOk=H and CardOk=H then				-- reset WDcnt
				WDcnt <= (others => '0');
			elsif WDog = L then						-- count until Wdog
				WDcnt <= WDcnt+1;
			end if;
		end if;
	end process;
	----------------------------------------------------------------------------
	-- components mapping ------------------------------------------------------
	ilseq: entity infoSlave.info_link_seq
	generic map(
		C_CLK_DIV_22MHZ => C_CLK_DIV_22MHZ,
		C_JTAG_SUPPORT => 1,
		C_REVISION => C_REVISION
	)
	PORT MAP(
		-- std-ports
		i_Clk		=> i_Clk,
		i_Rst		=> i_Rst,		-- high-activ
		-- outputs
		o_Irq		=> open,		-- IRQ-bit
		o_diagnosis	=> open,		-- diagnosis-bit
		o_32bit		=> B32,
		o_Typ2		=> open,
		o_Typ1		=> open,
		o_Typ0		=> open,
		o_Addr7		=> open,
		o_Addr6		=> open,
		o_Addr5		=> open,
		o_Addr4		=> open,
		o_Addr3		=> open,
		o_Addr2		=> Addr20x(2),
		o_Addr1		=> Addr20x(1),
		o_Addr0		=> Addr20x(0),
		o_MCok		=> MCok,
		o_CIrqEn	=> open,
		o_Status1	=> RXStatus1,	-- status-bit
		o_Status0	=> RXStatus0,	-- status-bit
		o_Data		=> open,
		-- clocks
		o_BitClk	=> BitClk,		-- master-clk
		o_cDiagnosis=> cDiagnosis,
		o_cAddr0	=> cAddr0,
		o_cMCok		=> open,
		o_cReadH	=> open,
		o_cData16	=> open,
		o_cS35		=> cS35,
		o_cS37		=> open,
		o_cS52		=> open,
		o_cStatus1	=> cStatus1,
		o_cStatus0	=> open,
		o_cData		=> open,
		o_cDataEnd	=> cDataEnd,
		i_diagnosis => High,		-- if H => diagnosticable
		i_CardOk	=> CardOk,		-- if H => CardOk = H
		i_CardIrq	=> High,		-- if H => CIRQ = rx
		i_CIrqUnasked => Low,		-- if H => CIRQ = H
		i_Status1	=> LinkLED,		-- status-bit or diagnostic
		i_Status0	=> Low,			-- status bit
		i_Data		=> TXData,		-- TX-Data
		i_Err		=> Low,			-- if H => reset BitCnt
		-- Eeprom ----------------
		i_EEPROMen	=> High,		-- EEPROM
		o_EEen		=> o_eep_cs,	-- EEPROM Chipselect
		o_EEclk		=> o_eep_clk,	-- EEPROM Clock
		o_EEd		=> o_eep_D,		-- EEPROM Data Out
		i_EEd		=> loc_i_eep_D,	-- EEPROM Data In
		-- jatg-port
		o_jtagOe	=> o_JTAG_EN,
		o_jtagTCK	=> o_TCK,
		o_jtagTDI	=> o_TDI,
		o_jtagTMS	=> o_TMS,
		i_jtagTDO	=> i_TDO,
		-- LEDs
		o_LinkLED	=> LinkLED,		-- high-activ (H=light)
		o_PowerLED	=> open,		-- high-activ (H=light)
		-- CardTyp def.
		i_32not16	=> B32,			-- protocol length L
		i_CardTyp	=> CardTyp,		-- card typ nr.TTT
		i_AddrSwitch=> AddrSwitch,	-- addresbits AAAAAAAA
		i_CmpEn		=> CmpEn,		-- H => compare, L not compare
									-- TTTTAAAAAAAA
		-- link
		i_RX		=> RX,
		o_TX		=> TX,
		o_RXd		=> RXd,
		o_RErr		=> RErr,
		o_LiErr		=> LiErr,
		o_TrOK		=> TrOK
	);
end Behavioral;
