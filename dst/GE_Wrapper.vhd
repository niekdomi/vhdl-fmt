---------------------------------------------------------------------------
--
--  GIN-Wrapper
--
---------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- wraps all GinSubModules to the main GinModule
--
---------------------------------------------------------------------------

-- ToDo
--
--	- Dis/En Rx
--	- static Rx IRQ
--	- static TxEmpty IRQ
--
--	05.02.2008-le	add svn keywords
--	08.02.2008-le	change to virtex4 blockram and change ppcside to 64 bit
--	20.09.2008-fb	correct rx for minimal interframe gap (IFG) (96 bit)
--	24.09.2008-le	add o_RxEthErr for triggering cs
--	17.03.2010-FB	EtherCAT Buffer-Toggle Timer implemented
--	10.09.2010-le	change rx irq to level triggerd, cleared when status=0
--	02.12.2010-qf	adapted the behaviour of the start of packet handling,
--						so that we can handle the byte stuffing bug described in the Marvell application note "MV-S700021-00".
--	07.06.2011-le	take clk enables from sam3 ethercat to support 10/100 speeds
--	10.08.2011-le	add generic for registered outputs (gin-pcie local bus)
--					add generic for 32 bit ram
--	12.08.2011-le	add signal to switch between Ethernet and Ethercat when
--						g_EtherCAT is enabled.
--	31.05.2012-fb	g_powerLink with PL-Timers and ICU added
--	11.09.2012-le	PL-Timers and ICU support for 64/32 bit devices
--	04.10.2013-le	adjust ICU BRAM switch
--	13.01.2014-le	add support for more then two rx buffers
--	14.07.2014-qf	corrections for multibuffer rx mode with 64bit word width.
--	08.02.2016-le	g_RXIRQ_CLR_S: expand RxIrq_clr to 2 clks
--	21.12.2017-le	reintegrate GinEthTunnel branch
--					- tunneling Ethernetframes from/to ginlink
--	13.02.2018-le	- add a tx busy input    
--	19.03.2019-le	GE_RxEthSeq: too long packages destroy the config area 0..0x40
--					add a new error for too long packages (>0x600) 
--					- remove EType string, it's now the counter of this error
--					- rev is now 0102
--	29.03.2019-le	GE_RxEthSeq: too long packages destroy the config area 0..0x40
--					add a new error for too long packages (max size of buffer 0x800-0x40) 
--					- rev is now 0103
--------------------------------------------------------------------------------
--$Rev:: 5269                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-03-29 15:35:59 +0100 (Fr., 29 MÃ¤r 2019)                        $
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
entity GE_Wrap is
	generic (
		g_fpga_type     : in natural range 0 to 7 := 0; -- 0 = Xilinx, 1 = Altera
		g_EtherCAT	    : in natural range 0 to 1 := 0;
		g_powerLink	    : in natural range 0 to 1 := 0;
		g_OUTREG_A		: in natural range 0 to 1 := 0;
		g64_n32BitRam	: in natural range 0 to 1 := 1;
		g_NoBufferPair	: in positive range 1 to 4 := 1;
		g_RXIRQ_CLR_S	: in natural range 0 to 1 := 0 -- expand RxIrq_clr to 2 clks
	);
	port (
		i_ppc_dom_clk	: in  std_logic;	--le
		o_IRQs			: out std_logic_vector( 7 downto 0);

		i_ENETnECAT		: in std_logic := '1'; -- switch between Ethernet and Ethercat when g_EtherCAT is enabled
		i_MulitBufEn	: in std_logic := '0'; -- enable more then two rx buffers
		i_Q125			: in  std_logic;
		i_Q62_5			: in  std_logic;
		i_GMII_RX_Data_Valid_EN	: in std_logic := '1';
		i_GMII_TX_CLK_EN		: in std_logic := '1';
		i_GMII_TX_Busy	: in std_logic := '0';
		o_GMII_TxDat	: out std_logic_vector(7 downto 0);
		o_GMII_TxDv		: out std_logic;
		o_GMII_TxErr	: out std_logic;

		i_GMII_RxDat	: in  std_logic_vector(7 downto 0);
		i_GMII_RxDv		: in  std_logic;
		i_GMII_RxErr	: in  std_logic;

		o_TxEthRun 		: OUT std_logic;
		o_RxEthRun 		: OUT std_logic;
		o_RxEthErr 		: OUT std_logic;

		i_BRAM_Clk 		: IN  std_logic;
		i_BRAM_EN 		: IN  std_logic;
		i_BRAM_Addr 	: in  std_logic_vector(15 downto 0);
		i_BRAM_WEN 		: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_BRAM_Dout 	: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_BRAM_Din 		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0)
	);

end GE_Wrap;

--------------------------------------------------------------------------------
architecture impl of GE_Wrap is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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

	signal RxMEM_WR_Mode: std_logic;

	signal EthCRC		: std_logic_vector(31 downto 0);
	signal TxEthRun		: std_logic;
	signal RxEthRun		: std_logic;

--------------------------------------------------------------------------------
	signal TxPPCRdData	: std_logic_vector(i_BRAM_Dout'range);
	signal TxMEM_RdData : std_logic_vector(31 downto 0);
	signal TxMEM_WrData : std_logic_vector(31 downto 0);
	signal TxMEM_Adr	: std_logic_vector(10 downto 0);
	signal TxMEM_WR		: std_logic_vector( 3 downto 0);
	signal TxIRQs		: std_logic_vector( 7 downto 0);
	signal TxIRQ	    : std_logic;

	signal dbgMEM_WR : std_logic_vector(3 downto 0);
	signal dbgMEM_Adr : std_logic_vector(10 downto 0);
	signal dbgMEM_WrData : std_logic_vector(31 downto 0);
	signal dbgMEM_RdData : std_logic_vector(31 downto 0);
--------------------------------------------------------------------------------
--	Tx
--------------------------------------------------------------------------------
	signal TxCharIsK 		: std_logic_vector( 1 downto 0);
	signal TxData 			: std_logic_vector(15 downto 0);

	type sGE_16_8_TxSeq is (
		sIdle,sHB,sLB,sOdd,
		sCRC0,sCRC1,sCRC2,sCRC3
	);
	signal GE_16_8_TxSeq	: sGE_16_8_TxSeq := sIdle;

	signal GMII_TxDat		: std_logic_vector(7 downto 0) := x"00";
	signal GMII_TxDv		: std_logic := L;
	signal GMII_TxErr		: std_logic := L;
	signal GMII_TxDat_1		: std_logic_vector(7 downto 0) := x"00";
	signal GMII_TxDv_1		: std_logic := L;

	signal TxCnt			: std_logic_vector (3 downto 0) := x"0";
	signal TxCRC32			: std_logic_vector (31 downto 0) := x"00000000";
	signal TxLCRC32			: std_logic_vector (31 downto 0) := x"00000000";
	signal TxCRCinp			: std_logic_vector (7 downto 0) := x"00";
	signal TxCrcClr			: std_logic := '0';
	signal TxCrcRun			: std_logic := '0';
	signal TxRunCrc			: std_logic := '0';
	signal TxOdd			: std_logic := '0';

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

	signal RxCnt			: std_logic_vector (3 downto 0) := x"0";
	signal RxCRC32			: std_logic_vector (31 downto 0) := x"00000000";
	signal RxLCRC32			: std_logic_vector (31 downto 0) := x"00000000";


	signal RxCRCinp		: std_logic_vector (7 downto 0) := x"00";
	signal RxCrcClr		: std_logic := '0';
	signal RxCrcRun		: std_logic := '0';
	signal RxCrcOk			: std_logic := '0';
	signal CRC_EN			: std_logic;

	signal Lh				: std_logic := '0';
	signal RxD16v			: std_logic_vector (15 downto 0) := x"0000";
	signal RxChv			: std_logic_vector (1 downto 0) := "00";
	signal RxErrv			: std_logic := '0';

	signal RxData			: std_logic_vector (15 downto 0) := x"0000";
	signal RxCharIsK		: std_logic_vector (1 downto 0) := "00";
	signal RxCrcErr			: std_logic := '0';

	signal x10				: std_logic := '0';
	signal x20				: std_logic := '0';
	signal x30				: std_logic := '0';
	signal x40				: std_logic := '0';

--------------------------------------------------------------------------------
	signal ECAT_Tim		: std_logic_vector (15 downto 0) := x"0000";
	signal ECAT_Toggle	: std_logic := '0';
	signal ECAT_Start_L	: std_logic := '1';
	signal ECAT_Start_H	: std_logic := '1';
	signal ECAT_Rst		: std_logic;

	signal RX_DV                           : std_logic:= '0';
	signal RX_DV_INT                       : std_logic:= '0';
	signal RX_DV_INT_INT                   : std_logic:= '0';
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
	constant Eth_Rev		: bit_vector (15 downto 0) := X"0103";
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

--------------------------------------------------------------------------------
	GMII_RxDv  		<= i_GMII_RxDv;
	GMII_RxErr		<= i_GMII_RxErr;
	GMII_RxDat 		<= i_GMII_RxDat;

	o_GMII_TxDat 	<= GMII_TxDat;
	o_GMII_TxDv  	<= GMII_TxDv;
	o_GMII_TxErr	<= GMII_TxErr;


	Create_RX_CLK125_EN: PROCESS(i_Q125)
	BEGIN
		IF (i_Q125'EVENT AND i_Q125 = '1') THEN
			RX_DV <= i_GMII_RxDv;
			RX_DV_INT <= RX_DV;
			RX_DV_INT_INT <= RX_DV_INT;
			---- INSERT RX_Data_Valid --
			Data_Valid_125_EN <= i_GMII_RX_Data_Valid_EN;
			Data_Valid_62_5_EN_stored_INT <= Data_Valid_62_5_EN_stored;
			IF (((i_GMII_RxDv = '1') AND (RX_DV = '0')) AND (i_GMII_RX_Data_Valid_EN = '0')) THEN
				Data_Valid_62_5_EN_stored <= '0';
				Data_Status_62_5_Level <= '0';
			ELSIF (i_GMII_RX_Data_Valid_EN = '1') THEN
				Data_Valid_62_5_EN_stored <= (NOT(Data_Status_62_5_Level) OR Data_Valid_125_EN);
				Data_Status_62_5_Level <= NOT(Data_Status_62_5_Level);
			ELSE
				Data_Valid_62_5_EN_stored <= '0';
			END IF;
		END IF;
	END PROCESS Create_RX_CLK125_EN;

	-- Concurrent 0: Generate lengthened enable signal.
	CLK62_5_EN_Lengthened_d <= (Data_Valid_62_5_EN_stored OR Data_Valid_62_5_EN_stored_INT);


	Create_RX_CLK62_5_EN: PROCESS(i_Q62_5)
	BEGIN
		IF (i_Q62_5'EVENT AND i_Q62_5 = '1') THEN
			Data_Valid_62_5_EN <= CLK62_5_EN_Lengthened_d;
		END IF;
	END PROCESS Create_RX_CLK62_5_EN;

	Create_TX_CLK125_EN: PROCESS(i_Q125)
	BEGIN
		IF (i_Q125'EVENT AND i_Q125 = '1') THEN
			TX_CLK125_EN <= i_GMII_TX_CLK_EN;
			TX_CLK62_5_EN_stored_INT <= TX_CLK62_5_EN_stored;
			IF (i_GMII_TX_CLK_EN = '1') THEN
				TX_CLK62_5_EN_stored <= (TX_CLK125_EN OR NOT(TX_CLK62_5_EN_Level));
				TX_CLK62_5_EN_Level <= NOT(TX_CLK62_5_EN_Level);
			ELSE
				TX_CLK62_5_EN_stored <= '0';
			END IF;
		END IF;
	END PROCESS Create_TX_CLK125_EN;

	TX_CLK62_5_d <= (TX_CLK62_5_EN_stored OR TX_CLK62_5_EN_stored_INT);

	Create_TX_CLK62_5_EN: PROCESS(i_Q62_5)
	BEGIN
		IF (i_Q62_5'EVENT AND i_Q62_5 = '1') THEN
			TX_CLK62_5_EN <= TX_CLK62_5_d;
		END IF;
	END PROCESS Create_TX_CLK62_5_EN;

--------------------------------------------------------------------------------
--gect:if (g_EtherCAT = 1) generate begin

		process (i_Q62_5) begin
			if rising_edge(i_Q62_5) then
				if (TX_CLK62_5_EN = H) then
					if (i_ENETnECAT=L and g_EtherCAT=1) then
						-- one short start-pulse only
						ECAT_Start_L <= L;
						ECAT_Start_H <= L;

						if ((ECAT_Tim = x"0000")
						or	(ECAT_Rst = H)) then
							-- 100MBit-EtherCAT läµ¦t mit Q62_4en nur mit 6.25MHz
							-- 6.25MHz gehen mit 8 und 4kHz nicht auf --> 2kHz
							--	000   781.25   1562.5   2343.75   3125
							--  000   30D       61A      928      C35
							--	-+_____+---------+________+--------+___
							-- max Jitter = +-80ns vom Ideal-Wert
							ECAT_Tim <= x"0C34";
						else
							ECAT_Tim <= ECAT_Tim-1;
						end if;

						if ((ECAT_Tim = x"000")
						or	(ECAT_Tim = x"61A")) then
							ECAT_Toggle  <= L;
							ECAT_Start_L <= H;
						end if;

						if ((ECAT_Tim = x"30D")
						or	(ECAT_Tim = x"928")) then
							ECAT_Toggle  <= H;
							ECAT_Start_H <= H;
						end if;
					end if;

				end if;
			end if;
		end process;
--	end generate;

--------------------------------------------------------------------------------
--	convert 16-Bit MGT to 8-Bit GMII_ Tx Data
--------------------------------------------------------------------------------
--	GE_16_8_Tx Sequencer
--------------------------------------------------------------------------------
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			IF (TX_CLK125_EN = '1') THEN -- Debug QFU
				GMII_TxDat_1 <= x"00";
				GMII_TxDv_1  <= L;
				GMII_TxDat <= GMII_TxDat_1;
				GMII_TxDv  <= GMII_TxDv_1;
				GMII_TxErr  <= L;

				TxCrcClr <= L;
				TxRunCrc <= TxCrcRun;

				case (GE_16_8_TxSeq) is

				when sIdle =>	---	Idle, wait to PktStart -------------------------
					if (TxDATA(15 downto 0) = x"5555") and (TxCharIsk = "00") then
						GMII_TxDat_1 <= TxDATA(15 downto 8);
						GMII_TxDv_1  <= H;
						TxCrcClr <= H;
						GE_16_8_TxSeq <= sLB;
					end if;

				when sHB =>	---	send HighByte --------------------------------------
					GMII_TxDat_1 <= TxDATA(15 downto 8);
					GMII_TxDv_1  <= H;

					-- dedect CRC_run end  --+__
					if (TxRunCrc = H) and (TxCrcRun = L) then
						if (TxOdd = H) then
							-- one Byte more
							TxRunCrc <= H;
							GE_16_8_TxSeq <= sOdd;
						else
							GE_16_8_TxSeq <= sCRC0;
						end if;
					else
						GE_16_8_TxSeq <= sLB;
					end if;

				when sLB =>	---	send LowByte ---------------------------------------
					GMII_TxDat_1 <= TxDATA(7 downto 0);
					GMII_TxDv_1  <= H;

					-- dedect CRC_run end  --+__
					if (TxRunCrc = H) and (TxCrcRun = L) then
						GE_16_8_TxSeq <= sCRC0;
					else
						GE_16_8_TxSeq <= sHB;
					end if;

				when sOdd =>	---	wait to send last odd Byte ---------------------
					GE_16_8_TxSeq <= sCRC0;

				when sCRC0 => --- send CRC -----------------------------------------
					GMII_TxDat <= TxLCRC32(31 downto 24);
					GMII_TxDv  <= H;
					GE_16_8_TxSeq <= sCRC1;
				when sCRC1 => --- send CRC -----------------------------------------
					GMII_TxDat <= TxLCRC32(23 downto 16);
					GMII_TxDv  <= H;
					GE_16_8_TxSeq <= sCRC2;
				when sCRC2 => --- send CRC -----------------------------------------
					GMII_TxDat <= TxLCRC32(15 downto  8);
					GMII_TxDv  <= H;
					GE_16_8_TxSeq <= sCRC3;
				when sCRC3 => --- send CRC -----------------------------------------
					GMII_TxDat <= TxLCRC32( 7 downto  0);
					GMII_TxDv  <= H;
					GE_16_8_TxSeq <= sIdle;

					when others => null;
				end case;

			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
--	Tx 8-Bit Inp to 32Bit CRC-Generator
--------------------------------------------------------------------------------
--	Eingangs-BitVerdreher
	process (GMII_TxDat_1) begin
		for i in 7 downto 0 loop
			-- first TxBit = TxData(8) (nextCRC_inp = D15)
			TxCRCinp( 7 - i)	<= GMII_TxDat_1(i);
		end loop;
	end process;

--	8-Bit to 32Bit CRC-Generator
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			IF (TX_CLK125_EN = '1') THEN -- Debug QFU
				if (TxCrcClr = H) then
					TxCRC32 <= x"FFFFFFFF";
				elsif (TxRunCrc = H) then
					-- nextCRC_inp first TxBit = D15 (= TxData(8))
					TxCRC32 <= gin_link.PCK_CRC32_D8.nextCRC32_D8(TxCRCinp,TxCRC32);
				end if;
			end if;
		end if;
	end process;

--	Ausgangs-BitVerdreher
	process (TxCRC32) begin
		for i in 7 downto 0 loop
			TxLCRC32(24 + i)	<= not TxCRC32(31 - i);
			TxLCRC32(16 + i)	<= not TxCRC32(23 - i);
			TxLCRC32(8 + i) 	<= not TxCRC32(15 - i);
			TxLCRC32(i) 		<= not TxCRC32( 7 - i);
		end loop;
	end process;


--------------------------------------------------------------------------------
--	convert 8-Bit GMII_ to 16-Bit MGT Data
--------------------------------------------------------------------------------
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			IF (Data_Valid_125_EN = '1') THEN -- Debug QFU
				GMII_RxDv_1 <= GMII_RxDv;
				GMII_RxDat_1 <= GMII_RxDat;
				RxErrv <= not RxCrcOk;
				RxD16v <= x"0000";
				RxChv <= "11";
				RxCrcClr <= L;

				case (GE_16_8_RxSeq) is

					when sIdle =>	---	Idle, wait to PktStart -------------------------
						if (GMII_RxDv_1 = L) and (GMII_RxDat = x"55") and (GMII_RxDv = H) then
							RxCrcClr <= H;
							GE_16_8_RxSeq <= sWaitStart;
						end if;
						CRC_EN <= '0';

					when sWaitStart => ---	We are waiting for the 0xD5 character: the 0x55's are no longer interesting for us --------------------------------------
						if (GMII_RxDat = x"D5") then
							RxD16v 	<= GMII_RxDat_1  & GMII_RxDat;
							RxChv 	<= not (GMII_RxDv_1 & GMII_RxDv);
							CRC_EN <= '1';
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
							RxD16v 	<= GMII_RxDat_1 & GMII_RxDat;
							RxChv 	<= not (GMII_RxDv_1 & GMII_RxDv);
							GE_16_8_RxSeq <= sWaitStart;
						end if;

					when sHB =>	---	send HighByte --------------------------------------
						RxD16v 	<= RxD16v;
						RxChv 	<= RxChv;
						GE_16_8_RxSeq <= sLB;

					when sLB =>	---	send LowByte --------------------------------------
						RxD16v 	<= GMII_RxDat_1  & GMII_RxDat;
						RxChv 	<= not (GMII_RxDv_1 & GMII_RxDv);
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
						RxD16v 	<= RxD16v;
						RxChv 	<= RxChv;
						GE_16_8_RxSeq <= sIdle;

					when others => null;
				end case;
			end if;
		end if;
	end process;

	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			RxData 		<= RxD16v;
			RxCharIsK 	<= RxChv;
			RxCrcErr	<= RxErrv;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Rx CRC-Clear und CRC-Run
--------------------------------------------------------------------------------

	process (GMII_RxDv,CRC_EN) begin
		RxCrcRun <= L;
		if (GMII_RxDv = H) and (CRC_EN = '1') then
			RxCrcRun <= H;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Rx 8-Bit Inp to 32Bit CRC-Generator
--------------------------------------------------------------------------------
--	Eingangs-BitVerdreher
	process (GMII_RxDat) begin
		for i in 7 downto 0 loop
			-- first TxBit = TxData(8) (nextCRC_inp = D15)
			RxCRCinp( 7 - i)	<= GMII_RxDat(i);
		end loop;
	end process;

--	8-Bit to 32Bit CRC-Generator
	process (i_Q125) begin
		if rising_edge(i_Q125) then
			IF (Data_Valid_125_EN = '1') THEN
				if (RxCrcClr = H) then
					RxCRC32 <= x"FFFFFFFF";
				elsif (RxCrcRun = H) then
					-- nextCRC_inp first TxBit = D15 (= TxData(8))
					RxCRC32 <= gin_link.PCK_CRC32_D8.nextCRC32_D8(RxCRCinp,RxCRC32);
				end if;
			end if;
		end if;
	end process;

--	Ausgangs-BitVerdreher
	process (RxCRC32) begin
		for i in 7 downto 0 loop
			RxLCRC32(24 + i)	<= not RxCRC32(31 - i);
			RxLCRC32(16 + i)	<= not RxCRC32(23 - i);
			RxLCRC32(8 + i) 	<= not RxCRC32(15 - i);
			RxLCRC32(i) 		<= not RxCRC32( 7 - i);
		end loop;
	end process;

--------------------------------------------------------------------------------
-- 	Rx Check CRC
--------------------------------------------------------------------------------
-- wenn das ganze angekommene CRC auch noch durch den CRC-Generator durch ist,
-- wird das resultierende CRC immer eine Konsante:
--	RxLCRC32 = x"1CDF4421"	oder auch (das nocht Bit-verdrehte CRC)
--	RxCRC32 = x"C704DD7B"
	process (RxCRC32) begin
		if (RxCRC32 = x"C704DD7B") then
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
			BRAM_Adr_A_RX <= i_BRAM_Addr(11) & not i_BRAM_Addr(10)  & i_BRAM_Addr(9 downto 0); -- used only for g_NoBufferPair>2
		else
			BRAM_Adr_A 	<= i_BRAM_Addr(11 downto 0);
			BRAM_Adr_A_RX 	<= not i_BRAM_Addr(11)  & i_BRAM_Addr(10 downto 0); -- used only for g_NoBufferPair>2
			ByteAdr <= i_BRAM_Addr(13 downto 0) & "00";
		end if;
		Tx_BRAM_EN <= L;
		Rx_BRAM_EN <= L;
		PLTim_EN <= L;
		if (ByteAdr < x"2000") then         -- ..0x2000	Config
			Tx_BRAM_EN <= i_BRAM_EN;
			--o_BRAM_Din <= TxPPCRdData;
		elsif (ByteAdr < x"4000" and g_NoBufferPair=1) or (ByteAdr < x"C000" and g_NoBufferPair>1) then
			Rx_BRAM_EN <= i_BRAM_EN;
			--o_BRAM_Din <= RxPPCRdData;
		else
			PLTim_EN <= i_BRAM_EN;
			--o_BRAM_Din <= PLTim_Dout;
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
		g_Eth_Type 	  => x"00000000",--EType(g_EtherCAT),			-- Eth or Ecat
		g_Eth_Rev 	  => x"7478" & Eth_Rev,	-- tx
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
							g_Eth_Type 	  => x"00000000",--EType(g_EtherCAT),-- Eth or Ecat
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
							g_Eth_Type 	  => x"00000000",--EType(g_EtherCAT),-- Eth or Ecat
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
		g_Eth_Type 	  => x"00000000",--EType(g_EtherCAT),			-- Eth or Ecat
		g_Eth_Rev 	  => x"7478" & Eth_Rev,	-- tx
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
			g_Eth_Type 	  => x"00000000",--EType(g_EtherCAT),			-- Eth or Ecat
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
			g_Eth_Type 	  => x"00000000",--EType(g_EtherCAT),			-- Eth or Ecat
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
		g_EtherCAT		=> g_EtherCAT
	)
	PORT MAP(
		i_Q62_5 		=> i_Q62_5		,
		i_Q62_5en		=> TX_CLK62_5_EN,
		i_ENETnECAT		=> i_ENETnECAT	,
		i_ECAT_Start_L  => ECAT_Start_L	,
		i_ECAT_Start_H  => ECAT_Start_H	,
		o_ECAT_Rst		=> ECAT_Rst		,
		i_TX_Busy		=> i_GMII_TX_Busy,

		o_TxCharIsk 	=> TxCharIsk	,
		o_TxData 		=> TxDATA		,
		o_EthRun 		=> TxEthRun		,
		o_CrcRun		=> TxCrcRun     ,
		o_Odd			=> TxOdd		,

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
		g_EtherCAT		=> g_EtherCAT,
		g_NoBufferPair	=> g_NoBufferPair
	)
	PORT MAP(
		i_Q62_5 		=> i_Q62_5		,
		i_Q62_5en		=> Data_Valid_62_5_EN,

		i_ENETnECAT		=> i_ENETnECAT	,
		i_ECAT_Toggle	=> ECAT_Toggle	,
		
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

uPL_Timer:if (g_PowerLink = 1) generate begin
	uWrap_PL_Timer: entity gin_Eth.PL_Timer
	generic map (
		g64_n32BitRam => g64_n32BitRam,
		g_OUTREG_A => g_OUTREG_A
	)
	PORT MAP(
		i_CLK			=> i_BRAM_Clk							,
		i_EN		    => PLTim_EN		                        ,
		i_WEN		    => i_BRAM_WEN							,
		i_Din		    => i_BRAM_Dout							,
		o_Dout		    => PLTim_Dout		                    ,
		i_addr		    => ByteAdr(5 downto 2)					,
		i_EthIRQs	    => I_PL_EthIRQs							,
		i_IRQ_Mask		=> IRQ_Mask								,
		o_IRQ		    => PL_ICU_IRQ
	);
end generate;

--------------------------------------------------------------------------------
end;
