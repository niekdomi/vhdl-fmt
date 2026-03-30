---------------------------------------------------------------------------
--
--  C64 BusSlave Sequencer
--
---------------------------------------------------------------------------
--
--  project     : C64_BusMaster
--  programmer  : F:Baschung, INDEL AG
--  date        : 23.06.2010
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- C64 BusSlave 
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--  
--
--
--
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
-- revision information !!! update g_SlaveSeq_Rev prior to svn commits !!!
---------------------------------------------------------------------------
-- Rev.00	23.06.2010-FB	- erste Version
-- Rev.01	27.10.2010-FB	- Read-Rev in SlaveSeq
-- Rev.02	25.02.2011-FB	- SPI added
--			 2.03.2011-FB	- g_P_CLK_only added
-- Rev.03	16.03.2011-FB	- AddrSw in SlaveSeq_Rev
--			28.03.2011-FB	- new o_SPI_OE for g_TrstBuf=0
-- Rev.04	27.04.2011-QF	- generic g_m_sync_clk for synchronous
--							  operation with the master. You have to change
--							  both FSM's in the future (25MHz, 125MHz).
-- Rev.05	28.06.2011-FB	- cmd_WrBC = 5F eingeführt; BlinkBit
-- Rev.06	13.07.2011-le	- handle Status r/w, no_OkLED, no_EEP_Wen in slave 
--							  module
--							- add 4bit hwrev
--							- add g_half_spi_freq to halve the spi speed (MAXII)
--							- add g_IntNExt (ext modules: L&AddrSw(2..0))
-- Rev.07	19.07.2011-le	- add cfg enable
--							- add JTAG Oe and g_SPI_TrstBuf
-- Rev.08	02.09.2011-FB	- new CLK-Input i_CLK/ni_CLK to Q25
--			01.10.2012-le	- move clockfilter to external file clockgenerator
--
-- Rev.09	24.01.2013-le	- supports Config BRAM on Port F8=Addr, F9=Data (Burst RD/WR)
--							- new output o_Slv_BRAM_RdAddr for ram replacement of rd ports
-- Rev.0A	17.07.2013-fb	- broadcast writes enabled for all port
-- Rev.0B	29.06.2015-le	- add g_CRCChecker to enable crc check ofer cop-bus jobs
--			04.11.2015-le	- change g_SlaveSeq_Rev from 0xEB to 0x0B
-- Rev.0C	25.10.2016-le	- new output o_COP_Reset (clock synchronized i_C64_Reset)
-- Rev 0D	15.02.2018-le	- change all b_C64_DatBus in cop-ram and crc checker 
--							  to C64_RdDat
--------------------------------------------------------------------------------
--$Rev:: 4751                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-02-15 14:57:30 +0100 (Do., 15 Feb 2018)                         $
--------------------------------------------------------------------------------


entity C64_SlaveSeq is 
    generic (
		-- application version & revision
        g_App_Rev	    : in	std_logic_vector(15 downto 0) := X"0000";
        -- tristate-buffer = 1 -> use	b_C64_DatBus 
        -- tristate-buffer = 0 -> use	i,o,OE _C64_DatBus 
		g_TrstBuf		: in	integer range 0 to 1 := 1;
		-- w/wo TB for SPI-Pins
		g_SPI_TrstBuf	: in	integer range 0 to 1 := 1;
		-- w/wo TB for JTAG-Pins
		g_JTAG_TrstBuf	: in	integer range 0 to 1 := 1;
		-- clock the slave with the same global clock like the C64-Master
		g_m_sync_clk	: in integer range 0 to 1 := 0;
		
		-- supports Config BRAM on Port F8=Addr, F9=Data (Burst RD/WR)
		g_CfgRAM_F8_F9	: in integer range 0 to 1 := 0;
		
		g_half_spi_freq	: in integer range 0 to 1 := 0;
		g_IntNExt		: in integer range 0 to 1 := 0;
		g_CRCChecker	: in integer range 0 to 1 := 0
	);  
 	port (
		-- address switch and HW_rev pins: visible at cfg_Adr_SlvRev
		 i_AddrSw		: in	std_logic_vector( 3 downto 0);
		 i_HWRev		: in	std_logic_vector( 3 downto 0);
		-- C64-Bus
		 i_C64_Reset	: in	std_logic;
		 i_CLK25		: in	std_logic;
		 i_C64_SEL		: in	std_logic;		
		 i_C64_Bend		: in	std_logic;

		-- g_TrstBuf = 1:	C64-BusData with tristate-buffer
		 b_C64_DatBus	: inout	std_logic_vector(15 downto 0) := x"0000";
		no_C64_Ack		: inout std_logic := 'Z';

		-- g_TrstBuf = 0:	C64-BusData without tristate-buffer
		 i_C64_DatBus	: in 	std_logic_vector(15 downto 0) := x"0000";
		 o_C64_DatBus	: out	std_logic_vector(15 downto 0) := x"0000";
		 o_C64_Dat_HOE	: out	std_logic := '0'; 
		 o_C64_Dat_LOE	: out	std_logic := '0'; 
		 o_C64_Ack_OE	: out	std_logic := '0';  

		-- JTAG Pins
		 o_JTAG_TCK		: out	std_logic;
		 o_JTAG_TMS		: out	std_logic;
		 o_JTAG_TDI		: out	std_logic;
		 i_JTAG_TDO		: in 	std_logic := '0';
		-- g_JTAG_TrstBuf = 0:	JTAG_OE
		 o_JTAG_OE		: out	std_logic;
		-- SPI Pins  
		 o_SPI_CLK		: out	std_logic;
		no_SPI_CS		: out	std_logic;
		 o_SPI_D		: out	std_logic;
		 i_SPI_Q		: in 	std_logic := '0';
		-- g_SPI_TrstBuf = 0:	SPI_OE
		 o_SPI_OE		: out	std_logic;
      -- synchronous clocking for internal slaves
		 i_CLK125      :  in	std_logic := '0';
		 i_C64_CLK_EN  :  in	std_logic := '0';
       -- local application Rd/Wr 
		 o_Addr			: out	std_logic_vector( 7 downto 0);
		 i_RdData		: in 	std_logic_vector(15 downto 0)	:= x"0000";		
		 o_WrData		: out	std_logic_vector(15 downto 0);		
		 o_WrEn			: out	std_logic;
		 o_RdEn			: out	std_logic;
		-- Slaver BRAM addr
		 o_Slv_BRAM_RdAddr : out	std_logic_vector( 7 downto 0);
		
		 i_Card_Status	: in	std_logic_vector(11-4*g_CRCChecker downto 0)	:= (others => '0'); -- 12 or 8 bit
		 o_Card_Status	: out	std_logic_vector(15 downto 0);
		 o_GF_Flags		: out	std_logic_vector(15 downto 0);
		 
		no_EEP_Wen		: inout	std_logic;
		no_OkLED		: out	std_logic;
		o_cfg_en		: out	std_logic;
		o_crc_err		: out	std_logic;
		o_crc_job		: out	std_logic;
		o_COP_Reset		: out	std_logic
	);
end;                                         

architecture impl of C64_SlaveSeq is
   
--------------------------------------------------------------------------------
    constant g_SlaveSeq_Rev	:  std_logic_vector := x"0D";
--------------------------------------------------------------------------------  
	constant cfg_Card_Status: std_logic_vector	:= x"FC";
	constant cfg_Adr_AppRev	: std_logic_vector	:= x"FE";
	constant cfg_Adr_SlvRev	: std_logic_vector	:= x"FF";
--------------------------------------------------------------------------------
--	C64Bus while SEL=H:		|CCCC MMMM KKKK KKKK|
--------------------------------------------------------------------------------    
--	C64-Command
--------------------------------------------------------------------------------
    constant cmd_nop		:  std_logic_vector := "0000"; 
    constant cmd_JTAG		:  std_logic_vector := "0001"; 
    constant cmd_SPI		:  std_logic_vector := "0010"; 
    constant cmd_RD			:  std_logic_vector := "0011"; 
    constant cmd_WR_BC		:  std_logic_vector := b"0101_1111"; 
    constant cmd_WR			:  std_logic_vector := "0111";
    
--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';
--------------------------------------------------------------------------------	

    type sCS_SlvSeq is (
    	sIdle,
    	sRead,sWrite,sWrite_BC,sJTAG,sSPI
	);	
	signal CS_Seq: sCS_SlvSeq := sIdle;	    -- C64_Slave-sequencer
	
	signal	C64_WrDat		: std_logic_vector(15 downto 0) := x"0000";		
	signal	C64_RdDat		: std_logic_vector(15 downto 0) := x"0000";		
	signal 	C64_Dat_HOE 	: std_logic := L;
	signal 	C64_Dat_LOE 	: std_logic := L;
	signal 	C64_Ack_OE		: std_logic := L;

	signal	Ack_T 			: std_logic := L;
	signal	Dat_HT 			: std_logic := L;
	signal	Dat_LT 			: std_logic := L;

	signal	GF_Flags		: std_logic_vector(15 downto 0) := x"0000";
	
	signal 	Card_Rd_Status	: std_logic_vector(15 downto 0)	:= (others => '0');
	signal 	Card_Wr_Status	: std_logic_vector(15 downto 0)	:= (others => '0');
--------------------------------------------------------------------------------

	signal	Addr			: std_logic_vector( 7 downto 0) := x"00";		
	signal	RdData			: std_logic_vector(15 downto 0) := x"0000";		
	signal 	WrEn 			: std_logic := L;
	signal 	WrEn_BC			: std_logic := L;
	signal 	RdEn 			: std_logic := L;

--------------------------------------------------------------------------------
	signal 	JTAG_OE 		: std_logic := L;
	signal 	JTAG_TCK		: std_logic := L;
	signal 	JTAG_TMS		: std_logic := L;
	signal 	JTAG_TDI		: std_logic := L;

--------------------------------------------------------------------------------
	signal 	SPI_OE 			: std_logic := L;
	signal 	SPI_CLK			: std_logic := L;
	signal 	SPI_CS			: std_logic := L;
	signal 	SPI_D			: std_logic := L;
	
	signal	clk				: std_logic := L;
	signal	clk_en			: std_logic := L;
	
	signal CFG_en_cnt		: std_logic_vector(1 downto 0) := (others => L);
	signal blink_n1			: std_logic := L;
	signal CFG_en			: std_logic := L;
	signal set_CFG_en		: std_logic := L;
	
	signal NextPortNr		: std_logic_vector( 7 downto 0) := (others => '0');
	
	signal crc_err			: std_logic_vector(3 downto 0) := (others => '0');
	signal c64_reset : std_logic;

--------------------------------------------------------------------------------
begin -- of architecture CS_Seq    
--------------------------------------------------------------------------------
--	local application Rd/Wr outputs
--------------------------------------------------------------------------------
    o_Addr			<= Addr;
	o_WrEn			<= WrEn or WrEn_BC;
	o_RdEn			<= RdEn;	
    o_WrData		<= C64_RdDat;
    o_GF_Flags		<= GF_Flags;
	o_Card_Status	<= Card_Wr_Status;
	o_COP_Reset		<= c64_reset;
--------------------------------------------------------------------------------
--	JTAG outputs
--------------------------------------------------------------------------------
uJTAG_WTB:if (g_JTAG_TrstBuf = 1) generate
	begin
	o_JTAG_TCK	<= JTAG_TCK 	when JTAG_OE=H else	'Z';
	o_JTAG_TMS	<= JTAG_TMS 	when JTAG_OE=H else	'Z';
	o_JTAG_TDI	<= JTAG_TDI 	when JTAG_OE=H else	'Z';
	end generate;
uJTAG_WoTB:if (g_JTAG_TrstBuf = 0) generate
	begin    
	o_JTAG_TCK	<= JTAG_TCK;
	o_JTAG_TMS	<= JTAG_TMS;
	o_JTAG_TDI	<= JTAG_TDI;
	end generate;
	o_JTAG_OE	<= JTAG_OE;
--------------------------------------------------------------------------------
--	SPI outputs with tristate-buffer
--------------------------------------------------------------------------------
uSPI_WTB:if (g_SPI_TrstBuf = 1) generate
	begin    
	 o_SPI_CLK	<= SPI_CLK	 	when SPI_OE=H else	'Z';
	no_SPI_CS	<= not SPI_CS	when SPI_OE=H else	'Z';
	 o_SPI_D	<= SPI_D	 	when SPI_OE=H else	'Z';
	end generate;	
--------------------------------------------------------------------------------
--	SPI outputs without tristate-buffer
--------------------------------------------------------------------------------
uSPI_WoTB:if (g_SPI_TrstBuf = 0) generate
	begin    
	 o_SPI_CLK	<= SPI_CLK;
	no_SPI_CS	<= not SPI_CS;
	 o_SPI_D	<= SPI_D;
	end generate;
	 o_SPI_OE	<= SPI_OE;
--------------------------------------------------------------------------------
--	C64-Bus with tristate-buffer	
--------------------------------------------------------------------------------
uDB_WTB:if (g_TrstBuf = 1) generate
	begin    
		C64_RdDat <= b_C64_DatBus;
	
	    -- all delays for simulation only
		Dat_HT <= C64_Dat_HOE 	after 1 ns;
		Dat_LT <= C64_Dat_LOE 	after 1 ns;
		Ack_T  <= C64_Ack_OE 	after 1 ns;
		
		b_C64_DatBus(15 downto 8) <= C64_WrDat(15 downto 8) when Dat_HT=H else (others => 'Z');
		b_C64_DatBus( 7 downto 0) <= C64_WrDat( 7 downto 0) when Dat_LT=H else (others => 'Z');

		no_C64_Ack <= L when Ack_T=H else 'Z';
	end generate;

--------------------------------------------------------------------------------
--	C64-Bus without tristate-buffer	
--------------------------------------------------------------------------------
uDB_WoTB:if (g_TrstBuf = 0) generate
	begin    
		C64_RdDat	  <= i_C64_DatBus;
	end generate;

	o_C64_Dat_HOE <= C64_Dat_HOE;
	o_C64_Dat_LOE <= C64_Dat_LOE;
	o_C64_Ack_OE  <= C64_Ack_OE;
	o_C64_DatBus  <= C64_WrDat; 

--------------------------------------------------------------------------------    
--	int/ext clk, without CLK_EN
--------------------------------------------------------------------------------    
normal_clocked: if (g_m_sync_clk = 0) generate
	begin
		clk <= i_CLK25;
		clk_en <= H;
	end generate normal_clocked;

--------------------------------------------------------------------------------
--	internal 125MHz Clock with CLK_EN
--------------------------------------------------------------------------------
	master_sync_clocked: if (g_m_sync_clk = 1) generate
	begin
		clk <= i_CLK125;
		clk_en <= i_C64_CLK_EN;
	end generate master_sync_clocked;
	
--------------------------------------------------------------------------------
	-- enable EEPROM_Write
	no_EEP_Wen <= L when Card_Wr_Status(15)=H else 'Z';

--------------------------------------------------------------------------------
--	Ok-LED 		(GinFrame_Flags(8) = globales Bink-Bit) 
--------------------------------------------------------------------------------
	process(GF_Flags,Card_Rd_Status) begin
		--------------------------------------------------------------------
		case (Card_Rd_Status(14 downto 12)) is -- use Rd instead of Wr to indicate CFG_en on LED
		--------------------------------------------------------------------
		when "000" =>	no_OkLED <= not L;
		when "001" =>	no_OkLED <= not GF_Flags(8);
		when "010" =>	no_OkLED <=     GF_Flags(8);
		when "011" =>	no_OkLED <= not H;
		when "100" =>	no_OkLED <= not H;
		when "101" =>	no_OkLED <= not H;
		when "110" =>	no_OkLED <= not H;
		when "111" =>	no_OkLED <= not H;
		--------------------------------------------------------------------
		when others => null;
		end case;
		--------------------------------------------------------------------
	end process;
	
no_crc: if g_CRCChecker=0 generate	begin
	Card_Rd_Status <= (not no_EEP_Wen & CFG_en & Card_Wr_Status(13 downto 12)) & i_Card_Status;
end generate no_crc;
	
crc: if g_CRCChecker=1 generate
signal last_crc_val : std_logic_vector(15 downto 0):= (others => H);
--                                                  fedcba9876543210
signal crc_poly : std_logic_vector(15 downto 0):= b"0001000000100001"; -- CRC-16-CCITT x^16+x^12+x^5+1
--signal last_crc_val : std_logic_vector(31 downto 0):= (others => H);
----                                                  fedcba9876543210fedcba9876543210
--signal crc_poly : std_logic_vector(31 downto 0):= b"00000100110000010001110110110111";
signal job : std_logic := L;
signal crc_ch_cnt : std_logic_vector(3 downto 0) := (others => L);
signal init : std_logic := L;

begin
	Card_Rd_Status <= (not no_EEP_Wen & CFG_en & Card_Wr_Status(13 downto 12)) & crc_err & crc_ch_cnt & i_Card_Status(3 downto 0);
	process(clk) begin
		if rising_edge(clk) then
			if (clk_en=H) then
				
				o_crc_job <= L;
				if ((WrEn=H or WrEn_BC=H) and Addr=x"FF") then
					
					o_crc_err <= L;
					o_crc_job <= H;
					crc_ch_cnt <= crc_ch_cnt + 1;
					if (last_crc_val/=C64_RdDat and init=H) then
						crc_err <= crc_err+1;
						o_crc_err <= H;
					--elsif (Card_Wr_Status(11)=H) then
					--	crc_err <= (others => L);
					end if;
					
					
					if (C64_Reset = H) then
						init <= L;
					else
						init <= H;
					end if;
					--must_val <= last_crc_val;
					last_crc_val <= (others => H);
				--elsif ((i_C64_SEL=H) or (job=H and no_C64_Ack=L)) then
				--	last_crc_val <= crc_gen(b_C64_DatBus,last_crc_val,crc_poly);
				--end if;
				elsif (i_C64_SEL=H) then
					---- my address or broadcast write
					--if ((C64_RdDat(11 downto 8)=conv_std_logic_vector(g_IntNExt,1)&i_AddrSw(2 downto 0)) or (C64_RdDat(15 downto 8)=cmd_WR_BC)) then
					--	job <= H;
					--	last_crc_val <= crc_gen(C64_RdDat,last_crc_val,crc_poly);
					--else
					--	job <= L;
					--end if;
					
					-- all address
					job <= H;
					last_crc_val <= crc_gen(C64_RdDat,last_crc_val,crc_poly);
				else
					if (i_C64_Bend=H )then
						job <= L;
					end if;
					if (job=H  and no_C64_Ack=L) then
						if (C64_Dat_HOE=H or C64_Dat_LOE=H) then
							last_crc_val <= crc_gen(C64_WrDat,last_crc_val,crc_poly);
						else
							last_crc_val <= crc_gen(C64_RdDat,last_crc_val,crc_poly);
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
end generate crc;
	
	-- config enable
	o_CFG_en <= CFG_en;
	process(clk) begin
		if rising_edge(clk) then
			if (clk_en=H) then
				blink_n1 <= GF_Flags(8);
				-- global Reset
				if (C64_Reset = H) then 
					CFG_en <= L;
				elsif (set_CFG_en=H) then 
					CFG_en <= H;
					CFG_en_cnt <= (others => L);
				elsif (CFG_en_cnt=2) then
					CFG_en <= L;
				elsif (blink_n1/=GF_Flags(8) and CFG_en=H) then
					CFG_en_cnt <= CFG_en_cnt + 1;
				end if;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	Read Revisions 
--------------------------------------------------------------------------------
	process(Addr,i_RdData,i_AddrSw,i_HWRev,card_rd_status) begin  
	    	
		------------------------------------------------------------------------
		case Addr is
		------------------------------------------------------------------------
		--	Read Application Revision
		------------------------------------------------------------------------
		when cfg_Adr_AppRev =>
	    	RdData <= g_App_Rev;      

		------------------------------------------------------------------------
		--	Read C64-SlaveSequencer Revision
		------------------------------------------------------------------------
		when cfg_Adr_SlvRev =>
	    	RdData <= i_AddrSw & i_HWRev & g_SlaveSeq_Rev;
	    	 
		when cfg_Card_Status =>
			RdData <= Card_Rd_Status;
		
		------------------------------------------------------------------------
		--	Read Application-Aata
		------------------------------------------------------------------------
		when others => 
			RdData <= i_RdData;                              
		------------------------------------------------------------------------
		end case;
		------------------------------------------------------------------------  
		
	end process;	

--------------------------------------------------------------------------------
--	asynchron part of CS_Seq 
--------------------------------------------------------------------------------
	process(CS_Seq,RdData,i_JTAG_TDO,i_SPI_Q) begin

	    C64_WrDat	<= x"0000"; 

		------------------------------------------------------------------------
		case CS_Seq is  
		------------------------------------------------------------------------
		--	C64 Read          	D15..0 read
		------------------------------------------------------------------------
		when sRead =>	
		    C64_WrDat	<= RdData; 

		------------------------------------------------------------------------
		--	JTAG:	split Bus: 	D15..8 = Write		D7..0 = Read
		------------------------------------------------------------------------
		when sJTAG =>
			C64_WrDat(0) <= i_JTAG_TDO; 	

		------------------------------------------------------------------------
		--	SPI:	split Bus: 	D15..8 = Write		D7..0 = Read
		------------------------------------------------------------------------
		when sSPI =>
			C64_WrDat(0) <= i_SPI_Q;
			if (g_half_spi_freq=1) then
				C64_WrDat(1) <= H;
			end if;

		------------------------------------------------------------------------
		when others => null; 
		end case;
		------------------------------------------------------------------------

	end process;

--------------------------------------------------------------------------------
--	Slaver BRAM addr
--------------------------------------------------------------------------------
--	Da die BRAM zu lesen immer einen CLK verzögerung haben, muss von Slaver
-- 	eine vorausschauende BRAM-addr zur Verfpgung gestellt werden, die beim
--	ersten Port-Zurgriff bereits einen Tack vorher korrekt anliegt.
--	Diese Port-Adresse liegt zusammen mit dem Read&ModuleNr vor dem SVL_RdEn
-- 	auf dem C64-Bus.
--------------------------------------------------------------------------------
--	synchron BRAM addr counter
	process(clk) begin
		if rising_edge(clk) then
			if (clk_en=H) then
				if ((i_C64_SEL = H)         -- start of slave-sequence
						and (i_C64_Bend = L)) then
					-- first next port_nr
					NextPortNr <= C64_RdDat(7 downto 0) + 1;
				else
					-- next port_nr
					NextPortNr <= NextPortNr + 1;
				end if;
			end if;
		end if;
	end process;

--	asynchron very first BRAM addr
	process(i_C64_SEL, i_C64_Bend, C64_RdDat, NextPortNr) begin
		if ((i_C64_SEL = H)         -- start of slave-sequence
				and (i_C64_Bend = L)) then
			o_Slv_BRAM_RdAddr <= C64_RdDat(7 downto 0);
		else
			o_Slv_BRAM_RdAddr <= NextPortNr;
		end if;
	end process;

--******************************************************************************
--
--		GIN-Frame Sequencer
--
--******************************************************************************

--------------------------------------------------------------------------------
--	broadcast Write, status write
--------------------------------------------------------------------------------
	process(clk) begin
		if rising_edge(clk) then
			if (clk_en=H) then
				set_CFG_en <= L;
				c64_reset <= i_C64_Reset;
				-- global Reset 
				if (C64_Reset = H) then 
					GF_Flags <= (others => '0');
					Card_Wr_Status <= (others => '0');
				elsif (WrEn_BC = H) then 
					----------------------------------------------------------------
					case Addr is 
					
					----------------------------------------------------------------
					when x"FC"	=>	-- broadcast-port 0xFC = GinFrame_Flags
						GF_Flags <= C64_RdDat;
				
					----------------------------------------------------------------
					when others => null;
					end case;
					----------------------------------------------------------------
				elsif (WrEn = H) then 
					----------------------------------------------------------------
					case Addr is 
					
					----------------------------------------------------------------
					when cfg_Card_Status =>	-- card status
						Card_Wr_Status <= C64_RdDat;
						set_CFG_en <= C64_RdDat(14);
					----------------------------------------------------------------
					when others => null;
					end case;
				end if;
			end if;
		end if;
	end process;    
    
--------------------------------------------------------------------------------
--	Sequencer
--------------------------------------------------------------------------------
	process(clk) begin
		if rising_edge(clk) then
			if (clk_en=H) then
					
				C64_Ack_OE 	<= L;
				C64_Dat_HOE <= L;
				C64_Dat_LOE <= L;
				
				JTAG_OE 	<= L;
				JTAG_TCK	<= L;
				JTAG_TMS	<= L;
				JTAG_TDI	<= L;
				
				SPI_OE 		<= L;
				SPI_CLK		<= L;
				SPI_CS		<= L;
				SPI_D		<= L;
				
				WrEn 		<= L;
				RdEn 		<= L;
				WrEn_BC		<= L;
				Addr 		<= x"00";
            	
            	--------------------------------------------------------------------
				case CS_Seq is  
    			
            	--------------------------------------------------------------------
				--	wait to C64_SEL
				--------------------------------------------------------------------
				when sIdle =>	---
					-- wait till BusCycleStart
					if ((i_C64_SEL = H)         -- start of slave-sequence
					and (i_C64_Bend = L)) then	-- Bend=H maybe used later
						------------------------------------------------------------
						-- this Module addressed ?
						------------------------------------------------------------
						if (C64_RdDat(11 downto 8) = ( conv_std_logic_vector(g_IntNExt,1) &i_AddrSw(2 downto 0))) then
							-- yes, latch port addr
							Addr <= C64_RdDat(7 downto 0);
							--------------------------------------------------------
							case (C64_RdDat(15 downto 12)) is
							--------------------------------------------------------
							--	JTAG
							--------------------------------------------------------
							when cmd_JTAG =>
								-- set Bus-Acknowledge
								C64_Ack_OE <= H;
								JTAG_OE <= H;
								JTAG_TCK <= L; 
								JTAG_TMS <= L;
								JTAG_TDI <= L;
								CS_Seq <= sJTAG;
            	
							--------------------------------------------------------
							--	SPI
							--------------------------------------------------------
							when cmd_SPI =>
								-- set Bus-Acknowledge
								C64_Ack_OE <= H;
								SPI_OE 	<= H;
								SPI_CLK <= L; 
								SPI_CS 	<= L;
								SPI_D  	<= L;
								CS_Seq <= sSPI;
            	
							--------------------------------------------------------
							-- 	Read
							--------------------------------------------------------
							when cmd_RD =>
								-- set Bus-Acknowledge
								C64_Ack_OE <= H;
								C64_Dat_HOE <= H;
								C64_Dat_LOE <= H;
								RdEn <= H;
								CS_Seq <= sRead;
            	
							--------------------------------------------------------
							--	Write
							--------------------------------------------------------
							when cmd_WR =>
								-- set Bus-Acknowledge
								C64_Ack_OE <= H;
								WrEn <= H;
								CS_Seq <= sWrite;

							--------------------------------------------------------
							when others => null;
							end case;
							--------------------------------------------------------
						end if;
						-----------------------------------------------------------
						--	boardcast write ?  	Cmd=5 & Mod=F
						-----------------------------------------------------------
						if (C64_RdDat(15 downto 8) = cmd_WR_BC) then
							-- yes, latch BC_port addr
							Addr <= C64_RdDat(7 downto 0);
							-- set Bus-Acknowledge
							C64_Ack_OE <= H;
							WrEn_BC <= H;
							CS_Seq <= sWrite_BC;
						end if;
						-----------------------------------------------------------
					end if;
				
            	--------------------------------------------------------------------
				--	SPI
				--------------------------------------------------------------------
				when sSPI =>	---           
					if (i_C64_Bend = L) then
						-- hold Bus-Acknowledge
						C64_Ack_OE <= H;
						C64_Dat_HOE <= L;
						C64_Dat_LOE <= H;
            	
						SPI_OE 	<= H;
						SPI_CLK <= C64_RdDat(11); 
						SPI_CS  <= C64_RdDat(9); 
						SPI_D   <= C64_RdDat(8); 
					else
						CS_Seq <= sIdle; 
					end if;
            	
            	--------------------------------------------------------------------
				--	JEDEC
				--------------------------------------------------------------------
				when sJTAG =>	---           
					if (i_C64_Bend = L) then
						-- hold Bus-Acknowledge
						C64_Ack_OE <= H;
						C64_Dat_HOE <= L;
						C64_Dat_LOE <= H;
            	
						JTAG_OE <= H;
						JTAG_TCK <= C64_RdDat(11); 
						JTAG_TMS <= C64_RdDat(9); 
						JTAG_TDI <= C64_RdDat(8); 
					else
						CS_Seq <= sIdle; 
					end if;
            	
            	--------------------------------------------------------------------
				--	Read
				--------------------------------------------------------------------
				when sRead =>	---           
					if (i_C64_Bend = L) then
						-- hold Bus-Acknowledge
						C64_Ack_OE <= H;
						C64_Dat_HOE <= H;
						C64_Dat_LOE <= H;  

						if (g_CfgRAM_F8_F9 = 1) and (Addr = x"F9") then 
							-- hold CFG_BRAM port addr
							Addr <= x"F9";
						else
							-- point to next port
							Addr <= Addr + 1;
    					end if;

						-- hold read-en
						RdEn <= H;
						CS_Seq <= sRead; 
					else
						CS_Seq <= sIdle; 
					end if;
            	
            	--------------------------------------------------------------------
				--	Write
				--------------------------------------------------------------------
				when sWrite =>	---    
					if (i_C64_Bend = L) then
						-- hold Bus-Acknowledge
						C64_Ack_OE <= H;

                         
						if (g_CfgRAM_F8_F9 = 1) and (Addr = x"F9") then
							-- hold CFG_BRAM port addr
							Addr <= x"F9";
						else
							-- point to next port
							Addr <= Addr + 1;
    					end if;

						-- hold read-en
						WrEn <= H;
						CS_Seq <= sWrite; 
					else
						CS_Seq <= sIdle; 
					end if;
            	
            	--------------------------------------------------------------------
				--	broadcast Write
				--------------------------------------------------------------------
				when sWrite_BC =>	---    
					if (i_C64_Bend = L) then
						-- hold Bus-Acknowledge
						C64_Ack_OE <= H;
						-- point to next cannel
						Addr <= Addr + 1;
						-- hold write-BC-en
						WrEn_BC <= H;
						CS_Seq <= sWrite_BC; 
					else
						CS_Seq <= sIdle; 
					end if;
            	
				--------------------------------------------------------------------
				when others => null; -----------------------------------------------
				end case;
			end if;
		end if;
    end process;
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
