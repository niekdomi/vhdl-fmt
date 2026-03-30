---------------------------------------------------------------------------
--
--  GE_TunnelMAC
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
--  - MAC for tunneling data from/to ginlink
--
---------------------------------------------------------------------------
--	03.10.2016-le	start
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--------------------------------------------------------------------------------
--$Rev:: 4693                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-21 16:22:50 +0100 (Do., 21 Dez 2017)                         $
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
entity GE_TunnelMAC is
	generic (
		g_OUTREG_A		: in integer range 0 to 1 := 0;
		g64_n32BitRam	: in integer range 0 to 1 := 1;
		g_NoBufferPair	: in positive range 1 to 4 := 1;
		g_RXIRQ_CLR_S	: in natural range 0 to 1 := 0 -- expand RxIrq_clr to 2 clks
	);
	port (
		i_ppc_dom_clk	: in std_logic;	--le
		o_IRQs			: out std_logic_vector( 7 downto 0);

		i_ENETnECAT		: in std_logic := H; -- switch between Ethernet and Ethercat when g_EtherCAT is enabled
		i_MulitBufEn	: in std_logic := L; -- enable more then two rx buffers
		i_Q62_5			: in std_logic;
		-- slave
		o_Mac2Tun_D		: out std_logic_vector(15 downto 0);
		o_Mac2Tun_Req	: out std_logic;
		i_Mac2Tun_En	: in std_logic := L;
		-- master/slave
		i_Tun2Mac_D		: in std_logic_vector(15 downto 0);
		i_Tun2Mac_Dv	: in std_logic;
		
		o_TxEthRun 		: out std_logic;
		o_RxEthRun 		: out std_logic;
		o_RxEthErr 		: out std_logic;

		i_BRAM_Clk 		: in std_logic;
		i_BRAM_EN 		: in std_logic;
		i_BRAM_Addr 	: in  std_logic_vector(15 downto 0);
		i_BRAM_WEN 		: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_BRAM_Dout 	: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_BRAM_Din 		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0)
	);

end GE_TunnelMAC;

--------------------------------------------------------------------------------
architecture impl of GE_TunnelMAC is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	constant g_EtherCAT : integer := 0;
--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------
	signal ByteADr		: std_logic_vector(15 downto 0);	-- dummy
	signal BRAM_Adr_A	: std_logic_vector(11 downto 0);
	signal BRAM_Adr_A_RX	: std_logic_vector(11 downto 0);
	signal Tx_BRAM_EN	: std_logic;
	signal Rx_BRAM_EN	: std_logic;
	signal BRAM_EN_B 	: std_logic;

--------------------------------------------------------------------------------
	signal RxPPCRdData	: std_logic_vector(i_BRAM_Dout'range);
	signal RxMEM_RdData : std_logic_vector(31 downto 0);
	signal RxMEM_WrData : std_logic_vector(31 downto 0);
	signal RxMEM_Adr	: std_logic_vector(11 downto 0);
	signal RxMEM_WR		: std_logic_vector( 3 downto 0);
	Signal RxIRQ	    : std_logic;
	signal RxIRQs		: std_logic_vector( 7 downto 0);
	signal RxIRQs_clr	: std_logic_vector( 7 downto 0) := (others => H);
	signal RxIRQs_clr_1	: std_logic_vector( 7 downto 0) := (others => H);
	signal RxIRQs_clr_2	: std_logic_vector( 7 downto 0) := (others => H);
	signal RxIRQs_store	: std_logic_vector( 7 downto 0) := (others => L);

	signal TxEthRun		: std_logic;
	signal RxEthRun		: std_logic;
--------------------------------------------------------------------------------
	signal TxPPCRdData	: std_logic_vector(i_BRAM_Dout'range);
	signal TxMEM_RdData : std_logic_vector(31 downto 0);
	signal TxMEM_WrData : std_logic_vector(31 downto 0);
	signal TxMEM_Adr	: std_logic_vector(10 downto 0);
	signal TxMEM_WR		: std_logic_vector( 3 downto 0);
	signal TxIRQs		: std_logic_vector( 7 downto 0);
--------------------------------------------------------------------------------
--	Tx
--------------------------------------------------------------------------------
	signal TxData 	: std_logic_vector(15 downto 0);
	signal TxData_1 : std_logic_vector(15 downto 0) := (others => L);
	signal TxCrcRun : std_logic := L;
	signal TxOdd : std_logic := L;
	signal TxCrcClr : std_logic := L;
	signal TxLCRC32	: std_logic_vector (31 downto 0) := x"00000000";
	signal TxLCRC32_1	: std_logic_vector (31 downto 0) := x"00000000";
	signal TxOddLCRC32	: std_logic_vector (31 downto 0) := x"00000000";
	
	type sGE_16_TxSeq is (
		sIdle,sData,
		sCRC01,sCRC23,
		sCRC0,sCRC12,sCRC3,
		sEnd
		);
	signal GE_16_TxSeq	: sGE_16_TxSeq := sIdle;

--------------------------------------------------------------------------------
--	Rx
--------------------------------------------------------------------------------
	signal RxLCRC32			: std_logic_vector (31 downto 0) := (others => L);
	signal RxLOddCRC32		: std_logic_vector (31 downto 0) := (others => L);

	signal RxCrcClr			: std_logic := L;
	signal RxCrcRun			: std_logic := L;
	signal RxCrcOk			: std_logic := L;
	signal odd_crc_ok		: std_logic := L;

	signal RxData			: std_logic_vector (15 downto 0) := (others => L);
	signal RxCharIsK		: std_logic_vector (1 downto 0) := (others => L);
	signal RxCrcErr			: std_logic := L;
	signal RxCrcErr_1		: std_logic := L;
	
	signal TunnelDv_1		: std_logic := L;
	signal TunnelDv_2		: std_logic := L;
	signal TunnelLng		: std_logic_vector (10 downto 0) := (others => L);

--------------------------------------------------------------------------------
	signal Data_Valid_62_5_EN	: std_logic;
	signal TX_CLK62_5_EN		: std_logic;
--------------------------------------------------------------------------------
--	PowerLink
--------------------------------------------------------------------------------
	signal PLTim_EN			: std_logic := L;
	signal PL_ICU_IRQ		: std_logic := L;
	signal PLTim_Dout		: std_logic_vector (o_BRAM_Din'range);
	signal I_PL_EthIRQs		: std_logic_vector (23 downto 0);
	signal IRQ_Mask			: std_logic_vector (23 downto 0);
	signal RxIRQMask		: std_logic_vector( 7 downto 0);
	signal TxIRQMask		: std_logic_vector( 7 downto 0);

--------------------------------------------------------------------------------
	constant Eth_Rev		: bit_vector (15 downto 0) := X"0101";
	constant Eth_Type		: bit_vector (31 downto 0) := x"4574685F";	-- Eth_
	constant ECAT_Type		: bit_vector (31 downto 0) := x"45434154";	-- ECAT

	type t_EType is array (0 to 1) of bit_vector (31 downto 0);
	constant EType : t_EType := (Eth_Type, Eth_Type);

	type t_out_select is (txram,rxram,icu);
	signal out_select_p			: t_out_select := rxram;
	signal out_select_r			: t_out_select := rxram;
	signal out_select			: t_out_select := rxram;
--------------------------------------------------------------------------------

begin

	TX_CLK62_5_EN <= H;
	Data_Valid_62_5_EN <= H;
	
--------------------------------------------------------------------------------
--	Tx
--------------------------------------------------------------------------------
	TxCrcClr <= not TxCrcRun;
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			TxDATA_1 <= TxData;
			case (GE_16_TxSeq) is
			when sIdle =>
				o_Mac2Tun_D <= x"0000";
				if (TxEthRun=H) then
					GE_16_TxSeq <= sData;
				end if;
			when sData =>
				o_Mac2Tun_D <= TxDATA_1;
				TxLCRC32_1 <= TxLCRC32;
				if (TxCrcRun=L) then
					GE_16_TxSeq <= sCRC01;
				elsif TxOdd=H then
					GE_16_TxSeq <= sCRC0;
				end if;
			when sCRC01 =>
				o_Mac2Tun_D <= TxLCRC32_1(31 downto 16);
				GE_16_TxSeq <= sCRC23;
			when sCRC23 =>
				o_Mac2Tun_D <= TxLCRC32_1(15 downto 0);
				GE_16_TxSeq <= sEnd;
			when sCRC0 =>
				o_Mac2Tun_D <= TxDATA_1(15 downto 8) & TxOddLCRC32(31 downto 24);
				TxLCRC32_1 <= TxOddLCRC32;
				GE_16_TxSeq <= sCRC12;
			when sCRC12 =>
				o_Mac2Tun_D <= TxLCRC32_1(23 downto 8);
				GE_16_TxSeq <= sCRC3;
			when sCRC3 =>
				o_Mac2Tun_D <= TxLCRC32_1(7 downto 0) & x"00";
				GE_16_TxSeq <= sEnd;
			when sEnd =>
				o_Mac2Tun_D <= x"0000";
				if (TxEthRun=L) then
					GE_16_TxSeq <= sIdle;
				end if;
			end case;
		end if;
	end process;
	
	uEthSeq_TxCRC: entity gin_link.GIN_Eth_CRC_D16 
	PORT MAP(
		i_Q62_5		=> i_Q62_5,
		i_Data		=> TxData,
		i_CrcClr	=> TxCrcClr,
		i_CrcRun	=> H,
		o_EthCRC	=> TxLCRC32,
		o_EthOddCRC	=> TxOddLCRC32
	);

--------------------------------------------------------------------------------
--	Rx
--------------------------------------------------------------------------------
	RxCrcErr <= RxCrcErr_1 when odd_crc_ok=L else not RxCrcOk;

	RX_flow: process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			RxCharIsK <= "11";
			RxCrcErr_1 <= not RxCrcOk;	
			RxCrcClr <= H;
			RxData <= i_Tun2Mac_D;
			TunnelDv_1 <= i_Tun2Mac_Dv;
			TunnelDv_2 <= TunnelDv_1;
			if (TunnelDv_1=H and TunnelDv_2=L) then
				if (i_Tun2Mac_D(15)=L) then
					TunnelLng <= i_Tun2Mac_D(TunnelLng'high downto 0);
					odd_crc_ok <= i_Tun2Mac_D(0);
					RxData <= x"55D5";
					RxCharIsK <= "00";
					--RxCrcClr <= H;
				end if;
			elsif (TunnelLng=1 and i_Tun2Mac_Dv=H) then -- odd
				RxCharIsK <= "01";
				TunnelLng <= TunnelLng-1;
				RxCrcClr <= L;
			elsif (TunnelLng/=0 and i_Tun2Mac_Dv=H) then
				TunnelLng <= TunnelLng-2;
				RxCharIsK <= "00";
				RxCrcClr <= L;
			end if;
		end if;
	end process RX_flow;
--------------------------------------------------------------------------------
--	Ethernet CRC calculator
--------------------------------------------------------------------------------
	RxCrcRun <= H;
	
	uEthSeq_RxCRC: entity gin_link.GIN_Eth_CRC_D16 
	PORT MAP(
		i_Q62_5		=> i_Q62_5,
		i_Data		=> RxData,
		i_CrcClr	=> RxCrcClr,
		i_CrcRun	=> RxCrcRun,
		o_EthCRC	=> RxLCRC32,
		o_EthOddCRC	=> RxLOddCRC32
	);

--------------------------------------------------------------------------------
-- 	Rx Check CRC
--------------------------------------------------------------------------------
-- wenn das ganze angekommene CRC auch noch durch den CRC-Generator durch ist,
-- wird das resultierende CRC immer eine Konsante:
--	RxLCRC32 = x"1CDF4421"	oder auch (das nocht Bit-verdrehte CRC)
--	RxCRC32 = x"C704DD7B"
	process (RxLCRC32,RxLOddCRC32,odd_crc_ok) begin
		--if (RxCRC32 = x"C704DD7B") then
		if (RxLCRC32 = x"1CDF4421" and odd_crc_ok=L) then
			RxCrcOk <= H;
		elsif (RxLOddCRC32 = x"1CDF4421" and odd_crc_ok=H) then
			RxCrcOk <= H;
		else
			RxCrcOk <= L;
		end if;
	end process;

--==============================================================================
--
--==============================================================================
--------------------------------------------------------------------------------
--	synch irq with PPC-Clock
--------------------------------------------------------------------------------
	process (i_ppc_dom_clk) begin
		if rising_edge(i_ppc_dom_clk) then
			RxIRQ <= (RxIRQs_store(1) or RxIRQs_store(0));
			o_IRQs <= RxIRQ & TxIRQs(7 downto 5) & PL_ICU_IRQ & "000" ;
		end if;
	end process;

	clr_enl : if (g_RXIRQ_CLR_S=1) generate
		process (i_ppc_dom_clk) begin
			if rising_edge(i_ppc_dom_clk) then
				RxIRQs_clr_1 <= RxIRQs_clr;
				RxIRQs_clr_2 <= RxIRQs_clr or RxIRQs_clr_1;
			end if;
		end process;
	end generate clr_enl;
	
	clr_std : if (g_RXIRQ_CLR_S=0) generate
		RxIRQs_clr_2 <= RxIRQs_clr;
	end generate clr_std;

	o_TxEthRun <= TxEthRun;
	o_RxEthRun <= RxEthRun;

	-- async clr for rx irqs (from ppc_dom_clk)
	clr : for i in 0 to g_NoBufferPair-1 generate
		process (ByteAdr,i_BRAM_WEN,i_BRAM_Dout,i_BRAM_EN) begin
			RxIRQs_clr(0+i*2) <= L;
			RxIRQs_clr(1+i*2) <= L;
			if (ByteAdr = (x"200"&conv_std_logic_vector(i*4,4)) and i_BRAM_EN=H) then --rx status
				if (i_BRAM_WEN(3+4*g64_n32BitRam)=H and i_BRAM_Dout(28+32*g64_n32BitRam)=L) then --clr rxirq(0)
					RxIRQs_clr(0+i*2) <= H;
				end if;
				if (i_BRAM_WEN(1+4*g64_n32BitRam)=H and i_BRAM_Dout(12+32*g64_n32BitRam)=L) then --clr rxirq(1)
					RxIRQs_clr(1+i*2) <= H;
				end if;
			end if;
		end process;
	end generate clr;

	-- hold of RXirqs wit asyncron clear
	hold_as_clr : for i in 0 to 2*g_NoBufferPair-1 generate
		process (i_Q62_5,RxIRQs_clr_2) begin
			if (RxIRQs_clr_2(i)=H) then
				RxIRQs_store(i) <= L;
			elsif rising_edge(i_Q62_5) then
				if (Data_Valid_62_5_EN=H) then
					if (i_MulitBufEn=L) then
						if (RxIRQs(i)=H) then
							RxIRQs_store(i) <= H;
						end if;
					else
						RxIRQs_store(i) <= L;
					end if;
				end if;
			end if;
		end process;
	end generate hold_as_clr;

--------------------------------------------------------------------------------
--	Dualport Adr
--------------------------------------------------------------------------------
--	side A	PowerPC
--	side B	EthernetSequencer
--------------------------------------------------------------------------------
	process (i_BRAM_Addr,i_BRAM_EN,TxPPCRdData,RxPPCRdData,ByteAdr,out_select,PLTim_Dout) begin

		if (g64_n32BitRam = 1) then
			ByteAdr <= i_BRAM_Addr(12 downto 0) & "000";
			BRAM_Adr_A <= i_BRAM_Addr(11 downto 0);
			BRAM_Adr_A_RX <= i_BRAM_Addr(11) & not i_BRAM_Addr(10) & i_BRAM_Addr(9 downto 0); -- used only for g_NoBufferPair>2
		else
			BRAM_Adr_A 	<= i_BRAM_Addr(11 downto 0);
			BRAM_Adr_A_RX 	<= not i_BRAM_Addr(11) & i_BRAM_Addr(10 downto 0); -- used only for g_NoBufferPair>2
			ByteAdr <= i_BRAM_Addr(13 downto 0) & "00";
		end if;
		Tx_BRAM_EN <= L;
		Rx_BRAM_EN <= L;
		PLTim_EN <= L;
		if (ByteAdr < x"2000") then-- ..0x2000	Config
			Tx_BRAM_EN <= i_BRAM_EN;
		elsif (ByteAdr < x"4000" and g_NoBufferPair=1) or (ByteAdr < x"C000" and g_NoBufferPair>1) then
			Rx_BRAM_EN <= i_BRAM_EN;
		else
			PLTim_EN <= i_BRAM_EN;
		end if;

		case out_select is
		when txram => o_BRAM_Din <= TxPPCRdData;
		when icu => o_BRAM_Din <= PLTim_Dout;
		when rxram => o_BRAM_Din <= RxPPCRdData;
		end case;

	end process;

	outreg_en: if g_OUTREG_A=1 generate
		out_select <= out_select_p;
	end generate outreg_en;

	outreg_dis: if g_OUTREG_A=0 generate
		out_select <= out_select_r;
	end generate outreg_dis;

	process (i_BRAM_Clk) begin
		if rising_edge(i_BRAM_Clk) then
			if Tx_BRAM_EN=H then
				out_select_r <= txram;
			elsif Rx_BRAM_EN=H then
				out_select_r <= rxram;
			elsif PLTim_EN=H then
				out_select_r <= icu;
			end if;
			out_select_p <= out_select_r;
		end if;
	end process;

	BRAM_EN_B <= Data_Valid_62_5_EN;

--------------------------------------------------------------------------------
--	Dualport Ram
--------------------------------------------------------------------------------
dpr64:if (g64_n32BitRam = 1) generate begin
	uWarp_TxEthRam: entity gin_link.Gin_BRAM_4kByte_A64_B32
	generic map (
		g_Eth_Type => EType(g_EtherCAT),			-- Eth or Ecat
		g_Eth_Rev => x"7478" & Eth_Rev,	-- tx
		g_OUTREG_A => g_OUTREG_A
	)
	PORT MAP(
		i_BRAM_Clk_A  => i_BRAM_Clk,
		i_BRAM_EN_A   => Tx_BRAM_EN,
		i_BRAM_WEN_A  => i_BRAM_WEN,
		i_BRAM_Addr_A => BRAM_Adr_A(8 downto 0),
		i_BRAM_Dout_A => i_BRAM_Dout,
		o_BRAM_Din_A  => TxPPCRdData,

		i_BRAM_Clk_B  => i_Q62_5,
		i_BRAM_EN_B   => TX_CLK62_5_EN,
		i_BRAM_WEN_B  => TxMEM_WR,
		i_BRAM_Addr_B => TxMEM_Adr(9 downto 0),
		i_BRAM_Dout_B => TxMEM_WrData,
		o_BRAM_Din_B  => TxMEM_RdData
	);
	
	dpr16k64: if (g_NoBufferPair>2) generate begin 
		uWarp_RxEthRam: entity bram.BRAM_16kByte_A64_B32
			generic map (
							--g_Eth_Type 	  =>  EType(g_EtherCAT),-- Eth or Ecat
							--g_Eth_Rev 	  => x"7278" & Eth_Rev,-- rx
							g_OUTREG_A => g_OUTREG_A
							)
			PORT MAP		(
							i_BRAM_Clk_A  => i_BRAM_Clk,
							i_BRAM_EN_A   => Rx_BRAM_EN,
							i_BRAM_WEN_A  => i_BRAM_WEN,
							i_BRAM_Addr_A => BRAM_Adr_A_RX(10 downto 0),
							i_BRAM_Dout_A => i_BRAM_Dout,
							o_BRAM_Din_A  => RxPPCRdData,

							i_BRAM_Clk_B  => i_Q62_5,
							i_BRAM_EN_B   => BRAM_EN_B,
							i_BRAM_WEN_B  => RxMEM_WR,
							i_BRAM_Addr_B => RxMEM_Adr(11 downto 0),
							i_BRAM_Dout_B => RxMEM_WrData,
							o_BRAM_Din_B  => RxMEM_RdData
							);
	end generate dpr16k64;
	
	dpr8k64: if (g_NoBufferPair=2) generate begin 
		uWarp_RxEthRam: entity gin_link.Gin_BRAM_8kByte_A64_B32
			generic map (
							g_Eth_Type 	  =>  EType(g_EtherCAT),-- Eth or Ecat
							g_Eth_Rev 	  => x"7278" & Eth_Rev,-- rx
							g_OUTREG_A => g_OUTREG_A
							)
			PORT MAP(
							i_BRAM_Clk_A  => i_BRAM_Clk,
							i_BRAM_EN_A   => Rx_BRAM_EN,
							i_BRAM_WEN_A  => i_BRAM_WEN,
							i_BRAM_Addr_A => BRAM_Adr_A_RX(9 downto 0),
							i_BRAM_Dout_A => i_BRAM_Dout,
							o_BRAM_Din_A  => RxPPCRdData,

							i_BRAM_Clk_B  => i_Q62_5,
							i_BRAM_EN_B   => BRAM_EN_B,
							i_BRAM_WEN_B  => RxMEM_WR,
							i_BRAM_Addr_B => RxMEM_Adr(10 downto 0),
							i_BRAM_Dout_B => RxMEM_WrData,
							o_BRAM_Din_B  => RxMEM_RdData
							);
	end generate dpr8k64;
	
	dpr4k64: if (g_NoBufferPair=1) generate begin 
		uWarp_RxEthRam: entity gin_link.Gin_BRAM_4kByte_A64_B32
			generic map (
							g_Eth_Type 	  =>  EType(g_EtherCAT),-- Eth or Ecat
							g_Eth_Rev 	  => x"7278" & Eth_Rev,-- rx
							g_OUTREG_A => g_OUTREG_A
							)
			PORT MAP		(
							i_BRAM_Clk_A  => i_BRAM_Clk,
							i_BRAM_EN_A   => Rx_BRAM_EN,
							i_BRAM_WEN_A  => i_BRAM_WEN,
							i_BRAM_Addr_A => BRAM_Adr_A_RX(8 downto 0),
							i_BRAM_Dout_A => i_BRAM_Dout,
							o_BRAM_Din_A  => RxPPCRdData,

							i_BRAM_Clk_B  => i_Q62_5,
							i_BRAM_EN_B   => BRAM_EN_B,
							i_BRAM_WEN_B  => RxMEM_WR,
							i_BRAM_Addr_B => RxMEM_Adr(9 downto 0),
							i_BRAM_Dout_B => RxMEM_WrData,
							o_BRAM_Din_B  => RxMEM_RdData
							);
	end generate dpr4k64;
end generate dpr64;
	
dpr32:if (g64_n32BitRam = 0) generate begin
	uWarp_TxEthRam: entity gin_link.Gin_BRAM_4kByte_A32_B32
	generic map (
		g_Eth_Type => EType(g_EtherCAT),			-- Eth or Ecat
		g_Eth_Rev => x"7478" & Eth_Rev,	-- tx
		g_OUTREG_A => g_OUTREG_A
	)
	PORT MAP(
		i_BRAM_Clk_A  => i_BRAM_Clk  	,
		i_BRAM_EN_A   => Tx_BRAM_EN		,
		i_BRAM_WEN_A  => i_BRAM_WEN  	,
		i_BRAM_Addr_A => BRAM_Adr_A(9 downto 0),
		i_BRAM_Dout_A => i_BRAM_Dout 	,
		o_BRAM_Din_A  => TxPPCRdData  	,

		i_BRAM_Clk_B  => i_Q62_5  	 	,
		i_BRAM_EN_B   => TX_CLK62_5_EN	,
		i_BRAM_WEN_B  => TxMEM_WR	 	,
		i_BRAM_Addr_B => TxMEM_Adr(9 downto 0),
		i_BRAM_Dout_B => TxMEM_WrData	,
		o_BRAM_Din_B  => TxMEM_RdData
	);
	dpr16k32: if (g_NoBufferPair>2) generate begin 
	uWarp_RxEthRam: entity bram.BRAM_16kByte_A32_B32
		generic map (
			--g_Eth_Type 	  =>  EType(g_EtherCAT),			-- Eth or Ecat
			--g_Eth_Rev 	  => x"7278" & Eth_Rev,	-- rx
			g_OUTREG_A => g_OUTREG_A
		)
		PORT MAP(
			i_BRAM_Clk_A  => i_BRAM_Clk  	,
			i_BRAM_EN_A   => Rx_BRAM_EN		,
			i_BRAM_WEN_A  => i_BRAM_WEN  	,
			i_BRAM_Addr_A => BRAM_Adr_A_RX(11 downto 0),
			i_BRAM_Dout_A => i_BRAM_Dout 	,
			o_BRAM_Din_A  => RxPPCRdData  	,

			i_BRAM_Clk_B  => i_Q62_5  	 	,
			i_BRAM_EN_B   => BRAM_EN_B		,
			i_BRAM_WEN_B  => RxMEM_WR	 	,
			i_BRAM_Addr_B => RxMEM_Adr(11 downto 0),
			i_BRAM_Dout_B => RxMEM_WrData	,
			o_BRAM_Din_B  => RxMEM_RdData
		);
	end generate dpr16k32;
	dpr8k32: if (g_NoBufferPair=2) generate begin 
	uWarp_RxEthRam: entity gin_link.Gin_BRAM_8kByte_A32_B32
		generic map (
			g_Eth_Type 	  =>  EType(g_EtherCAT),			-- Eth or Ecat
			g_Eth_Rev 	  => x"7278" & Eth_Rev,	-- rx
			g_OUTREG_A => g_OUTREG_A
		)
		PORT MAP(
			i_BRAM_Clk_A  => i_BRAM_Clk  	,
			i_BRAM_EN_A   => Rx_BRAM_EN		,
			i_BRAM_WEN_A  => i_BRAM_WEN  	,
			i_BRAM_Addr_A => BRAM_Adr_A_RX(10 downto 0),
			i_BRAM_Dout_A => i_BRAM_Dout 	,
			o_BRAM_Din_A  => RxPPCRdData  	,

			i_BRAM_Clk_B  => i_Q62_5  	 	,
			i_BRAM_EN_B   => BRAM_EN_B		,
			i_BRAM_WEN_B  => RxMEM_WR	 	,
			i_BRAM_Addr_B => RxMEM_Adr(10 downto 0),
			i_BRAM_Dout_B => RxMEM_WrData	,
			o_BRAM_Din_B  => RxMEM_RdData
		);
	end generate dpr8k32;
	dpr4k32: if (g_NoBufferPair=1) generate begin 
		uWarp_RxEthRam: entity gin_link.Gin_BRAM_4kByte_A32_B32
		generic map (
			g_Eth_Type 	  =>  EType(g_EtherCAT),			-- Eth or Ecat
			g_Eth_Rev 	  => x"7278" & Eth_Rev,	-- rx
			g_OUTREG_A => g_OUTREG_A
		)
		PORT MAP(
			i_BRAM_Clk_A  => i_BRAM_Clk  	,
			i_BRAM_EN_A   => Rx_BRAM_EN		,
			i_BRAM_WEN_A  => i_BRAM_WEN  	,
			i_BRAM_Addr_A => BRAM_Adr_A_RX(9 downto 0),
			i_BRAM_Dout_A => i_BRAM_Dout 	,
			o_BRAM_Din_A  => RxPPCRdData  	,

			i_BRAM_Clk_B  => i_Q62_5  	 	,
			i_BRAM_EN_B   => BRAM_EN_B		,
			i_BRAM_WEN_B  => RxMEM_WR	 	,
			i_BRAM_Addr_B => RxMEM_Adr(9 downto 0),
			i_BRAM_Dout_B => RxMEM_WrData	,
			o_BRAM_Din_B  => RxMEM_RdData
		);
	end generate dpr4k32;
end generate dpr32;


--------------------------------------------------------------------------------
--	Tx Ethernet Sequencer
--------------------------------------------------------------------------------
	uWrap_TxEthSeq: entity gin_Eth.GE_TxEthSeq
	generic map (
		g_Tunnel		=> 1
	)
	PORT MAP(
		i_Q62_5 		=> i_Q62_5		,
		i_Q62_5en		=> TX_CLK62_5_EN,

		o_TxData 		=> TxData		,
		o_EthRun 		=> TxEthRun		,
		o_CrcRun		=> TxCrcRun		,
		o_Odd			=> TxOdd		,
		
		i_Mac2Tun_En	=> i_Mac2Tun_En	,
		o_Mac2Tun_Req	=> o_Mac2Tun_Req,

		i_MEM_RdData	=> TxMEM_RdData ,
		o_MEM_WrData	=> TxMEM_WrData	,
		o_MEM_Adr		=> TxMEM_Adr	,
		o_MEM_WR		=> TxMEM_WR		,
		o_TxIRQs		=> TxIRQs
	);

--------------------------------------------------------------------------------
--	Rx Ethernet Sequencer
--------------------------------------------------------------------------------
	uWrap_RxEthSeq: entity gin_Eth.GE_RxEthSeq
	generic map (
		g_NoBufferPair	=> g_NoBufferPair
	)
	PORT MAP(
		i_Q62_5 		=> i_Q62_5		,
		i_Q62_5en		=> Data_Valid_62_5_EN,
		
		i_MulitBufEn	=> i_MulitBufEn	,

		i_RxCharIsk 	=> RxCharIsk	,
		i_RxData 		=> RxData		,
		i_RxCrcErr		=> RxCrcErr		,
		o_EthError		=> o_RxEthErr	,
		o_EthRun 		=> RxEthRun		,

		i_MEM_RdData	=> RxMEM_RdData	,
		o_MEM_WrData	=> RxMEM_WrData	,
		o_MEM_Adr		=> RxMEM_Adr	,
		o_MEM_WR		=> RxMEM_WR		,
		o_IRQ			=> RxIRQs(2*g_NoBufferPair-1 downto 0)
	);

--------------------------------------------------------------------------------
--	PowerLink Timer		always 32Bit only
--------------------------------------------------------------------------------
	I_PL_EthIRQs <= x"00" & TxIRQs & RxIRQs;
	IRQ_Mask <= x"00" & TxIRQMask & RxIRQMask;
	
	RxIRQMask(2*g_NoBufferPair-1 downto 0) <= (others => H);
	TxIRQMask <= (others => H);

	uWrap_PL_Timer: entity gin_Eth.PL_Timer
	generic map (
		g64_n32BitRam => g64_n32BitRam,
		g_OUTREG_A => g_OUTREG_A,
		g_SKIP_TIMER => 1
	)
	PORT MAP(
		i_CLK		=> i_BRAM_Clk			,
		i_EN		=> PLTim_EN				,
		i_WEN		=> i_BRAM_WEN			,
		i_Din		=> i_BRAM_Dout			,
		o_Dout		=> PLTim_Dout			,
		i_addr		=> ByteAdr(5 downto 2)	,
		i_EthIRQs	=> I_PL_EthIRQs			,
		i_IRQ_Mask	=> IRQ_Mask				,
		o_IRQ		=> PL_ICU_IRQ
	);
--------------------------------------------------------------------------------
end;
