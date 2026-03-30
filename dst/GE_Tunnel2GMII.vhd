---------------------------------------------------------------------------
--
--  GE_Tunnel2GMII
--
---------------------------------------------------------------------------
--
--  project     : GINLINK
--  programmer  : C.Leuthold, INDEL AG
--  date        : 03.10.2016
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--	- GMII and Fifo for tunneling data from/to ginlink
--
---------------------------------------------------------------------------
--	03.10.2016-le	start
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	13.02.2018-le	- for connecting to gin_eth add a rx busy output and support
--					  1 RX Buffer (0 is to do...)
--------------------------------------------------------------------------------
--$Rev:: 4869                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-25 17:22:07 +0200 (Mi., 25 Apr 2018)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

LIBRARY gin_link;
USE gin_link.ALL;
LIBRARY gin_eth;
USE gin_eth.ALL;
LIBRARY bram;
USE bram.ALL;

--------------------------------------------------------------------------------
entity GE_Tunnel2GMII is
	generic (
		C_NO_OF_TXBUFFER : integer range 0 to 1 := 1; -- for connecting to gin_eth, no buffers are necessary
		C_NO_OF_RXBUFFER : integer range 1 to 16 := 8
	);
	port (
		i_Q125			: in std_logic;
		i_Q62_5			: in std_logic;
		i_GMII_RX_Data_Valid_EN	: in std_logic := '1';
		i_GMII_TX_CLK_EN		: in std_logic := '1';

		o_GMII_TxDat	: out std_logic_vector(7 downto 0);
		o_GMII_TxDv		: out std_logic;
		o_GMII_TxErr	: out std_logic;

		i_GMII_RxDat	: in std_logic_vector(7 downto 0);
		i_GMII_RxDv		: in std_logic;
		i_GMII_RxErr	: in std_logic;

		o_Mac2Tun_D		: out std_logic_vector(15 downto 0);
		o_Mac2Tun_Req	: out std_logic;
		i_Mac2Tun_Req_ack: in std_logic := L;
		i_Mac2Tun_En	: in std_logic := L;
		i_Tun2Mac_D		: in std_logic_vector(15 downto 0);
		i_Tun2Mac_Dv	: in std_logic;

		o_RX_busy	: out std_logic;
		o_GMII_RX_fifoshift : out std_logic;
		o_dbg			: out std_logic_vector(15 downto 0);
		o_TxLng			: out std_logic_vector(11 downto 0);
		o_TxD			: out std_logic_vector(15 downto 0)
	);
end GE_Tunnel2GMII;

--------------------------------------------------------------------------------
architecture impl of GE_Tunnel2GMII is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	Tx
--------------------------------------------------------------------------------
	signal TxCharIsK		: std_logic_vector( 1 downto 0);
	signal TxData			: std_logic_vector(15 downto 0);

	type sGE_16_8_TxSeq is (
		sIdle,sHB,sLB
	);
	signal GE_16_8_TxSeq	: sGE_16_8_TxSeq := sIdle;

	signal GMII_TxDat		: std_logic_vector(7 downto 0) := x"00";
	signal GMII_TxDv		: std_logic := L;
	signal GMII_TxDat_1		: std_logic_vector(7 downto 0) := x"00";

--------------------------------------------------------------------------------
--	Rx
--------------------------------------------------------------------------------
	signal GMII_RxDat		: std_logic_vector( 7 downto 0) := x"00";
	signal GMII_RxDv		: std_logic := '0';
	signal GMII_RxErr		: std_logic := '0';
	signal GMII_RxDat_1		: std_logic_vector( 7 downto 0) := x"00";
	signal GMII_RxDv_1		: std_logic := '0';

	type sGE_16_8_RxSeq is (
		sIdle,sWaitStart,sHB,sLB,sOdd
	);
	signal GE_16_8_RxSeq	: sGE_16_8_RxSeq := sIdle;

	signal RxD16v			: std_logic_vector (15 downto 0) := x"0000";
	signal RxChv			: std_logic_vector (1 downto 0) := "00";

	signal RxData			: std_logic_vector (15 downto 0) := x"0000";
	signal RxCharIsK		: std_logic_vector (1 downto 0) := "00";

--------------------------------------------------------------------------------
	signal RX_DV                           : std_logic:= '0';
	signal CLK62_5_EN_Lengthened_d         : std_logic;
	signal Data_Valid_62_5_EN_stored       : std_logic;
	signal Data_Valid_62_5_EN_stored_INT   : std_logic;
	signal Data_Status_62_5_Level          : std_logic;
	signal Data_Valid_125_EN               : std_logic;
	signal Data_Valid_62_5_EN              : std_logic;

	signal TX_CLK125_EN                    : std_logic;
	signal TX_CLK62_5_d                    : std_logic;
	signal TX_CLK62_5_EN                   : std_logic;
	signal TX_CLK62_5_EN_Level             : std_logic;
	signal TX_CLK62_5_EN_stored            : std_logic;
	signal TX_CLK62_5_EN_stored_INT        : std_logic;

--------------------------------------------------------------------------------
	type tGE_EthRxSeq is (
		sIdle,sWend,
		sOkEnd1,sOkEnd2
	);

	signal GE_EthRxSeq		: tGE_EthRxSeq := sIdle;
	signal RxCnt			: std_logic_vector(11 downto 0) := (others => L);
	signal Mac2Tun_En		: std_logic := L;

	signal GMII_RX_WEN		: std_logic := L;
	signal GMII_RX_Addr		: std_logic_vector(15 downto 0) := (others => L);
	signal GMII_RX_Data		: std_logic_vector(15 downto 0) := (others => L);
	signal GMII_RX_fifoinc	: std_logic := L;
	signal GMII_RX_full		: std_logic := L;
	signal GMII2Tun_Addr	: std_logic_vector(15 downto 0) := (others => L);
	signal GMII_RX_fifodec	: std_logic := L;
	signal GMII_RX_fifoshift : std_logic := L;

	type tGE_EthTxSeq is (
		sIdle,sStart,sEthHd1,sEthHd2,sEthHd3,
		sWend,sOddEnd,sOddEnd2,sEnd,
		sifG1,sifG2,sifG3,sifG4,sifG5
	);

	signal GE_EthTxSeq		: tGE_EthTxSeq := sIdle;
	signal TxCnt			: std_logic_vector(11 downto 0) := (others => L);
	signal Tun2Mac_Dv		: std_logic := L;

	signal TunnelDv_2		: std_logic := L;

	signal Tun2GMII_WEN		: std_logic := L;
	signal Tun2GMII_Addr	: std_logic_vector(15 downto 0) := (others => L);
	signal Tun2GMII_Data	: std_logic_vector(15 downto 0) := (others => L);
	signal GMII_TX_Addr		: std_logic_vector(15 downto 0) := (others => L);
	signal GMII_TX_Data		: std_logic_vector(15 downto 0) := (others => L);
	signal GMII_TX_Req		: std_logic := L;
	signal GMII_TX_fifodec	: std_logic := L;

	signal Mac2Tun_Req		: std_logic := L;

	type tTun2GMIISeq is (
		sIdle,sData,sLast
	);
	signal Tun2GMIISeq		: tTun2GMIISeq := sIdle;

	signal TunnelLng : std_logic_vector(11 downto 0) := (others => L);
	constant DF_NO_OF_KBYTE : integer := 2;
	constant BRAM_Init : tSLV_Nx16(0 to 512*DF_NO_OF_KBYTE-1) := (others => (others => L));

	constant DF_NO_OF_KBYTE_RX : integer := 2*C_NO_OF_RXBUFFER;
	constant BRAM_InitRX : tSLV_Nx16(0 to 512*DF_NO_OF_KBYTE_RX-1) := (others => (others => L));
	
	signal RX_WEN_A : std_logic_vector(1 downto 0);
	signal TX_WEN_A : std_logic_vector(1 downto 0);
	
	function pkg_log2_spez(value : natural) return integer is
	begin
		if value=1 then
			return 1;
		else
			return pkg_log2(value);
		end if;
	end pkg_log2_spez;
	
	signal GMII_RX_fifobuff_a : std_logic_vector(pkg_log2_spez(C_NO_OF_RXBUFFER)-1 downto 0) := (others => L);
	signal GMII_RX_fifobuff_b : std_logic_vector(pkg_log2_spez(C_NO_OF_RXBUFFER)-1 downto 0) := (others => L);
	signal GMII_RX_fifo_full : std_logic := L;
	signal GMII_RXFifo_addr : std_logic_vector(9+pkg_log2(C_NO_OF_RXBUFFER) downto 0) := (others => L);
	signal GMII2TunFifo_Addr : std_logic_vector(9+pkg_log2(C_NO_OF_RXBUFFER) downto 0) := (others => L);
	
begin

--------------------------------------------------------------------------------
	GMII_RxDv <= i_GMII_RxDv;
	GMII_RxErr <= i_GMII_RxErr;
	GMII_RxDat <= i_GMII_RxDat;

	o_GMII_TxDat <= GMII_TxDat;
	o_GMII_TxDv <= GMII_TxDv;
	o_GMII_TxErr <= L;

	Create_RX_CLK125_EN: process(i_Q125)
	begin
		if rising_edge(i_Q125) then
			RX_DV <= i_GMII_RxDv;
			---- INSERT RX_Data_Valid --
			Data_Valid_125_EN <= i_GMII_RX_Data_Valid_EN;
			Data_Valid_62_5_EN_stored_INT <= Data_Valid_62_5_EN_stored;
			if (((i_GMII_RxDv = '1') AND (RX_DV = '0')) AND (i_GMII_RX_Data_Valid_EN = '0')) then
				Data_Valid_62_5_EN_stored <= '0';
				Data_Status_62_5_Level <= '0';
			elsif (i_GMII_RX_Data_Valid_EN = '1') then
				Data_Valid_62_5_EN_stored <= (NOT(Data_Status_62_5_Level) OR Data_Valid_125_EN);
				Data_Status_62_5_Level <= NOT(Data_Status_62_5_Level);
			else
				Data_Valid_62_5_EN_stored <= '0';
			end if;
		end if;
	end process Create_RX_CLK125_EN;

	-- Concurrent 0: Generate lengthened enable signal.
	CLK62_5_EN_Lengthened_d <= (Data_Valid_62_5_EN_stored OR Data_Valid_62_5_EN_stored_INT);

	Create_RX_CLK62_5_EN: process(i_Q62_5)
	begin
		if rising_edge(i_Q62_5) then
			Data_Valid_62_5_EN <= CLK62_5_EN_Lengthened_d;
		end if;
	end process Create_RX_CLK62_5_EN;

	Create_TX_CLK125_EN: process(i_Q125)
	begin
		if rising_edge(i_Q125) then
			TX_CLK125_EN <= i_GMII_TX_CLK_EN;
			TX_CLK62_5_EN_stored_INT <= TX_CLK62_5_EN_stored;
			if (i_GMII_TX_CLK_EN = '1') then
				TX_CLK62_5_EN_stored <= (TX_CLK125_EN OR NOT(TX_CLK62_5_EN_Level));
				TX_CLK62_5_EN_Level <= NOT(TX_CLK62_5_EN_Level);
			else
				TX_CLK62_5_EN_stored <= '0';
			end if;
		end if;
	end process Create_TX_CLK125_EN;

	TX_CLK62_5_d <= (TX_CLK62_5_EN_stored OR TX_CLK62_5_EN_stored_INT);

	Create_TX_CLK62_5_EN: process(i_Q62_5)
	begin
		if rising_edge(i_Q62_5) then
			TX_CLK62_5_EN <= TX_CLK62_5_d;
		end if;
	end process Create_TX_CLK62_5_EN;

--------------------------------------------------------------------------------
--	convert 8-Bit GMII_ to 16-Bit MGT Data
--------------------------------------------------------------------------------
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			if (Data_Valid_125_EN = '1') then
				GMII_RxDv_1 <= GMII_RxDv;
				GMII_RxDat_1 <= GMII_RxDat;
				RxD16v <= x"0000";
				RxChv <= "11";
				case (GE_16_8_RxSeq) is
					when sIdle =>	---	Idle, wait to PktStart -------------------------
						if (GMII_RxDv_1 = L) and (GMII_RxDat = x"55") and (GMII_RxDv = H) then
							GE_16_8_RxSeq <= sWaitStart;
						end if;
					when sWaitStart => ---	We are waiting for the 0xD5 character: the 0x55's are no longer interesting for us --------------------------------------
						if (GMII_RxDat = x"D5") then
							RxD16v <= GMII_RxDat_1 & GMII_RxDat;
							RxChv <= not (GMII_RxDv_1 & GMII_RxDv);
							if (GMII_RxDv = H) then
								GE_16_8_RxSeq <= sHB;
							else
								if (GMII_RxDv_1 = H) then
									GE_16_8_RxSeq <= sOdd;
								else
									GE_16_8_RxSeq <= sIdle;
								end if;
							end if;
						else
							RxD16v <= GMII_RxDat_1 & GMII_RxDat;
							RxChv <= not (GMII_RxDv_1 & GMII_RxDv);
							GE_16_8_RxSeq <= sWaitStart;
						end if;
					when sHB =>	---	send HighByte --------------------------------------
						RxD16v <= RxD16v;
						RxChv <= RxChv;
						GE_16_8_RxSeq <= sLB;
					when sLB =>	---	send LowByte --------------------------------------
						RxD16v <= GMII_RxDat_1 & GMII_RxDat;
						RxChv <= not (GMII_RxDv_1 & GMII_RxDv);
						if (GMII_RxDv = H) then
							GE_16_8_RxSeq <= sHB;
						else
							if (GMII_RxDv_1 = H) then
								GE_16_8_RxSeq <= sOdd;
							else
								GE_16_8_RxSeq <= sIdle;
							end if;
						end if;
					when sOdd =>	---	send oddByte --------------------------------------
						RxD16v <= RxD16v;
						RxChv <= RxChv;
						GE_16_8_RxSeq <= sIdle;
				end case;
			end if;
		end if;
	end process;

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			RxData <= RxD16v;
			RxCharIsK <= RxChv;
		end if;
	end process;

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			GMII_RX_fifoinc <= L;
			GMII_RX_WEN <= L;
			GMII_RX_fifoshift <= L;
			if (Data_Valid_62_5_EN=H) then
				case (GE_EthRxSeq) is
				when sIdle =>	--- wait for 5555 55D5 EthPreamble
					RxCnt <= x"000";
					GMII_RX_Addr <= (others => L);
					if (RxData = x"55D5" and RxCharIsK = "00") then
						GE_EthRxSeq <= sWend;
						if (GMII_RX_fifo_full=H) then
							-- discard the oldest entry
							GMII_RX_fifoshift <= H;
						end if;
					end if;
				when sWend =>	--- Wait until UDP-End
					GMII_RX_WEN <= H;
					GMII_RX_Addr <= GMII_RX_Addr+1;
					GMII_RX_Data <= RxData;
					if (RxCharIsK = "00") then
						RxCnt <= RxCnt + 2;
					else
						-- check if normal EthEnd
						if (RxCharIsK(1) = H) then
							GE_EthRxSeq <= sOkEnd1;
						else
							RxCnt <= RxCnt + 1;
							GE_EthRxSeq <= sOkEnd1;
						end if;
					end if;
				when sOkEnd1 =>
					GMII_RX_WEN <= H;
					GMII_RX_Addr <= GMII_RX_Addr+1;
					GMII_RX_Data <= RxData;
					GE_EthRxSeq <= sOkEnd2;
				when sOkEnd2 =>
					GE_EthRxSeq <= sIdle;
					GMII_RX_WEN <= H;
					GMII_RX_Addr <= (others => L);
					GMII_RX_Data <= "0000" & RxCnt;
					o_dbg(15 downto 8) <= RxCnt(7 downto 0);
					GMII_RX_fifoinc <= H;
				end case;
			end if;
		end if;
	end process;
	
	bufg2: if (C_NO_OF_RXBUFFER>1) generate
		signal GMII_RX_fifobuff_a_next : std_logic_vector(pkg_log2_spez(C_NO_OF_RXBUFFER)-1 downto 0) := (others => L);
	begin
	
		o_RX_busy <= GMII_RX_fifo_full;
		o_GMII_RX_fifoshift <= GMII_RX_fifoshift;
	
		Mac2Tun_Req <= L when (GMII_RX_fifobuff_a=GMII_RX_fifobuff_b) and (GMII_RX_fifo_full=L) else H;
		GMII_RXFifo_addr <= GMII_RX_fifobuff_a(GMII_RX_fifobuff_a'high downto 0)&GMII_RX_Addr(9 downto 0);
		
		GMII_RX_fifobuff_a_next <= GMII_RX_fifobuff_a+1; 
		
		process (i_Q62_5) begin
			if rising_edge(i_Q62_5) then
				if (GMII_RX_fifoinc=H) then
					GMII_RX_fifobuff_a <= GMII_RX_fifobuff_a_next;
				end if;
				if (GMII_RX_fifodec=H) or (GMII_RX_fifo_full=H and GMII_RX_fifoinc=H) then
					GMII_RX_fifobuff_b <= GMII_RX_fifobuff_b+1;
				end if;
				
				if (GMII_RX_fifobuff_a_next=GMII_RX_fifobuff_b and GMII_RX_fifodec=L and GMII_RX_fifoinc=H) then
					GMII_RX_fifo_full <= H;
				elsif GMII_RX_fifodec=H and GMII_RX_fifoinc=L then
					GMII_RX_fifo_full <= L;
				end if;
				
				Mac2Tun_En <= i_Mac2Tun_En;
				if (Mac2Tun_En=H) then
					GMII2TunFifo_Addr <= GMII2TunFifo_Addr+1;
				else
					GMII2TunFifo_Addr <= GMII_RX_fifobuff_b(GMII_RX_fifobuff_b'high downto 0) & "0000000000";
				end if;
			end if;
		end process;
	end generate bufg2;
	
	bufg1: if (C_NO_OF_RXBUFFER=1) generate
	
		o_GMII_RX_fifoshift <= GMII_RX_fifoshift;
	
		Mac2Tun_Req <= L when (GMII_RX_fifo_full=L) else H;
		GMII_RXFifo_addr <= GMII_RX_Addr(9 downto 0);
		
		--GMII_RX_fifobuff_a_next <= GMII_RX_fifobuff_a+1; 
		
		process (i_Q62_5) begin
			if rising_edge(i_Q62_5) then
				if (GMII_RX_fifoinc=H) then
					GMII_RX_fifo_full <= H;
				end if;
				if (GMII_RX_fifodec=H) then
					GMII_RX_fifo_full <= L;
					o_RX_busy <= L;
				end if;
				if (GE_EthRxSeq/=sIdle) then
					o_RX_busy <= H;
				end if;
				
				Mac2Tun_En <= i_Mac2Tun_En;
				if (Mac2Tun_En=H) then
					GMII2TunFifo_Addr <= GMII2TunFifo_Addr+1;
				else
					GMII2TunFifo_Addr <= "0000000000";
				end if;
			end if;
		end process;
	end generate bufg1;

	GMII_RX_fifodec <= i_Mac2Tun_Req_ack or GMII_RX_fifoshift;

	RX_WEN_A <= GMII_RX_WEN&GMII_RX_WEN;

	GMII2Tunfifo_bram: entity bram.BRAM_NkByte_A16_B16
	generic map (
		C_NO_OF_KBYTE => DF_NO_OF_KBYTE_RX,
		BRAM_Init => BRAM_InitRX
	)
	port map (
		i_BRAM_Clk_A	=> i_Q62_5,
		i_BRAM_WEN_A	=> RX_WEN_A,
		i_BRAM_Addr_A	=> GMII_RXFifo_addr(9+pkg_log2(C_NO_OF_RXBUFFER) downto 0),
		i_BRAM_Dout_A	=> GMII_RX_Data,
		i_BRAM_Clk_B	=> i_Q62_5,
		i_BRAM_Addr_B	=> GMII2TunFifo_Addr(9+pkg_log2(C_NO_OF_RXBUFFER) downto 0),
		o_BRAM_Din_B	=> o_Mac2Tun_D,
		i_BRAM_EN_B		=> H
	);

	o_Mac2Tun_Req <= Mac2Tun_Req;
	o_dbg(4) <= Mac2Tun_Req;
	o_dbg(5) <= Mac2Tun_En;
	o_dbg(6) <= GMII_RxDv;
	o_dbg(7) <= GMII_RxDat(0);

	--------------------------------------------------------------------------------
	--	convert 16-Bit MGT to 8-Bit GMII_ Tx Data
	--------------------------------------------------------------------------------
	--	GE_16_8_Tx Sequencer
	--------------------------------------------------------------------------------
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			if (TX_CLK125_EN = '1') then
				GMII_TxDat <= x"00";
				GMII_TxDv <= L;
				GMII_TxDat_1 <= TxDATA(7 downto 0);
				case (GE_16_8_TxSeq) is
				when sIdle =>	---	Idle, wait to PktStart -------------------------
					if (((TxDATA(15 downto 0) = x"5555") and (TxCharIsk = "00") and C_NO_OF_TXBUFFER/=0) or
						((TxDATA(15 downto 0) = x"55D5") and (TxCharIsk = "00") and C_NO_OF_TXBUFFER=0)) then
						GMII_TxDat <= TxDATA(15 downto 8);
						GMII_TxDv <= H;
						GE_16_8_TxSeq <= sLB;
					end if;
				when sHB =>	---	send HighByte --------------------------------------
					if (TxCharIsk = "00") then
						GMII_TxDat <= TxDATA(15 downto 8);
						GE_16_8_TxSeq <= sLB;
						GMII_TxDv <= H;
					elsif (TxCharIsk = "01") then
						GMII_TxDat <= TxDATA(15 downto 8);
						GE_16_8_TxSeq <= sIdle;
						GMII_TxDv <= H;
					else
						GE_16_8_TxSeq <= sIdle;
						GMII_TxDv <= L;
					end if;
				when sLB =>	---	send LowByte ---------------------------------------
					GMII_TxDat <= GMII_TxDat_1;
					GMII_TxDv <= H;
					GE_16_8_TxSeq <= sHB;
				end case;
			end if;
		end if;
	end process;

tx_buffers : if C_NO_OF_TXBUFFER/=0 generate
begin
	-- 16-Bit MGT Tx Data from buffer
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			GMII_TX_fifodec <= L;
			if (TX_CLK62_5_EN=H) then
				TxData <= x"0000";
				TxCharIsK <= "11";
				GMII_TX_Addr <= (others => L);
				case (GE_EthTxSeq) is
				when sIdle =>	---	Idle, wait to PktStart -------------------------
					if (GMII_TX_Req = H) then
						GE_EthTxSeq <= sStart;
					end if;
				when sStart =>
					TxData <= x"5555";
					TxCharIsK <= "00";
					GE_EthTxSeq <= sEthHd1;
				when sEthHd1 =>	--- EthPreamble ------------------------------------
					TxData <= x"5555";
					TxCharIsK <= "00";
					GE_EthTxSeq <= sEthHd2;
				when sEthHd2 =>	--- EthPreamble ------------------------------------
					TxData <= x"5555";
					TxCharIsK <= "00";
					GE_EthTxSeq <= sEthHd3;
					TxCnt <= GMII_TX_Data(11 downto 0);
					o_TxLng <= GMII_TX_Data(11 downto 0);
					GMII_TX_Addr <= GMII_TX_Addr+1;
				when sEthHd3 =>	--- EthPreamble ------------------------------------
					TxData <= x"55D5";
					TxCharIsK <= "00";
					GE_EthTxSeq <= sWend;
					GMII_TX_Addr <= GMII_TX_Addr+1;
				when sWend =>		--- send til EthPkt-End ------------------------
					o_TxD <= GMII_TX_Data;
					TxData <= GMII_TX_Data;
					TxCharIsK <= "00";
					GMII_TX_Addr <= GMII_TX_Addr+1;
					if (TxCnt >= 4) then
						GE_EthTxSeq <= sWend;
					else
						if (TxCnt = 3) then
							GE_EthTxSeq <= sOddEnd;
						else
							GE_EthTxSeq <= sEnd;
						end if;
					end if;
					TxCnt <= TxCnt - 2;
				when sOddEnd =>		--- Odd-Byte End ---------------------------
					TxData <= GMII_TX_Data( 15 downto 8) & x"FD";
					TxCharIsK <= "01";
					GE_EthTxSeq <= sOddEnd2;
				when sOddEnd2 =>		--- Extended-Byte End ----------------------
					TxData <= x"F7F7";
					TxCharIsK <= "11";
					GE_EthTxSeq <= sEnd;

				when sEnd =>
					TxData <= x"0000";
					TxCharIsK <= "11";
					-- InterFramGab = 96ns = 12*8ns = 6x16Bit
					--	1	2	3	4	5	6
					--	e6	e7	e8	e9	ifg	idle
					GE_EthTxSeq <= sifG1;
					GMII_TX_fifodec <= H;
				when sifG1 =>
					GE_EthTxSeq <= sifG2;
				when sifG2 =>
					GE_EthTxSeq <= sifG3;
				when sifG3 =>
					GE_EthTxSeq <= sifG4;
				when sifG4 =>
					GE_EthTxSeq <= sifG5;
				when sifG5 =>
					GE_EthTxSeq <= sIdle;
				end case;
			end if;
		end if;
	end process;

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			Tun2GMII_Data <= i_Tun2Mac_D;
			Tun2Mac_Dv <= i_Tun2Mac_Dv;
			TunnelDv_2 <= Tun2Mac_Dv;
			Tun2GMII_WEN <= L;

			if (GMII_TX_fifodec=H) then
				GMII_TX_Req <= L;
			end if;

			case (Tun2GMIISeq) is
			when sIdle =>
				Tun2GMII_Addr <= (others => L);
				if (Tun2Mac_Dv=H and TunnelDv_2=L and GMII_TX_Req=L) then
					Tun2GMII_WEN <= H;
					TunnelLng <= i_Tun2Mac_D(TunnelLng'high downto 0);
					Tun2GMIISeq <= sData;
					GMII_TX_Req <= H;
				end if;
			when sData =>
				Tun2GMII_WEN <= H;
				Tun2GMII_Addr <= Tun2GMII_Addr+1;
				TunnelLng <= TunnelLng-2;
				if (TunnelLng=2 or (TunnelLng=1)) then
					Tun2GMIISeq <= sLast;
				end if;
				if (i_Tun2Mac_Dv=L) then
					Tun2GMIISeq <= sIdle;
				end if;
			when sLast =>
				Tun2GMII_WEN <= H;
				Tun2GMII_Addr <= Tun2GMII_Addr+1;
				Tun2GMIISeq <= sIdle;
			end case;
		end if;
	end process;

	o_dbg(0) <= Tun2Mac_Dv;
	o_dbg(1) <= Tun2GMII_Data(0);
	o_dbg(2) <= GMII_TxDv;
	o_dbg(3) <= GMII_TxDat(0);

	TX_WEN_A <= Tun2GMII_WEN&Tun2GMII_WEN;

	Tun2GMIIfifo_bram: entity bram.BRAM_NkByte_A16_B16
	generic map (
		C_NO_OF_KBYTE => DF_NO_OF_KBYTE,
		BRAM_Init => BRAM_Init
	)
	port map (
		i_BRAM_Clk_A	=> i_Q62_5,
		i_BRAM_WEN_A	=> TX_WEN_A,
		i_BRAM_Addr_A	=> Tun2GMII_Addr(9 downto 0),
		i_BRAM_Dout_A	=> Tun2GMII_Data,
		i_BRAM_Clk_B	=> i_Q62_5,
		i_BRAM_Addr_B	=> GMII_TX_Addr(9 downto 0),
		o_BRAM_Din_B	=> GMII_TX_Data,
		i_BRAM_EN_B		=> TX_CLK62_5_EN
	);
end generate tx_buffers;

no_tx_buffer : if C_NO_OF_TXBUFFER=0 generate
begin
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			TxData <= x"0000";
			TxCharIsK <= "11";

			Tun2Mac_Dv <= i_Tun2Mac_Dv;
			TunnelDv_2 <= Tun2Mac_Dv;

			case (Tun2GMIISeq) is
			when sIdle =>
				if (Tun2Mac_Dv=H and TunnelDv_2=L) then
					TunnelLng <= i_Tun2Mac_D(TunnelLng'high downto 0);
					TxData <= x"55D5";
					TxCharIsK <= "00";
					Tun2GMIISeq <= sData;
				end if;
			when sData =>
				o_TxD <= i_Tun2Mac_D;
				TxData <= i_Tun2Mac_D;
				TxCharIsK <= "00";

				if (TunnelLng=4 or TunnelLng=3) then
					Tun2GMIISeq <= sLast;
				end if;
				TunnelLng <= TunnelLng-2;
				if (i_Tun2Mac_Dv=L) then
					Tun2GMIISeq <= sIdle;
				end if;
			when sLast =>
				o_TxD <= i_Tun2Mac_D;
				TxData <= i_Tun2Mac_D;
				if (TunnelLng=1) then
					TxCharIsK <= "01";
				else
					TxCharIsK <= "00";
				end if;
				Tun2GMIISeq <= sIdle;
			end case;
		end if;
	end process;
end generate no_tx_buffer;


--------------------------------------------------------------------------------
end;
