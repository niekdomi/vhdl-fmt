--------------------------------------------------------------------------------
--
--  esat_master.vhd
--
--------------------------------------------------------------------------------
--
--  project     : esat
--  programmer  : C. Leuthold, INDEL AG
--  date        : 27.11.2015
--  version     : 1.00
--  language    : VHDL
--  system      : 
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	
--------------------------------------------------------------------------------
--$Rev:: 3873                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2015-12-17 14:39:26 +0100 (Do., 17 Dez 2015)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

library Infolink;
use Infolink.ALL;

library indel_pkg;
use indel_pkg.indel_pkg.all;

entity esat_master is
	generic (
		C_OVERSAMPLING : integer :=3
	);
	port (  
		i_Clk : in std_logic;
		i_Rx : in std_logic;
		o_Tx : out std_logic;
		i_Addr : in std_logic_vector(15 downto 0);
		i_Data : in std_logic_vector(63 downto 0);
		o_Data : out std_logic_vector(63 downto 0);
		o_DataValid : out std_logic;
		i_Start : in std_logic;
		o_Ready : out std_logic;
		i_ForceACRCError : in std_logic := L;
		i_ForceDCRCError : in std_logic := L;
		i_ForceLinkError : in std_logic := L;
		o_err_cnt : out std_logic_vector(15 downto 0);
		o_tx_ok_cnt : out std_logic_vector(15 downto 0);
		o_rx_ok_cnt : out std_logic_vector(15 downto 0);
		o_Error : out std_logic_vector(3 downto 0)
	);
end;

architecture impl of esat_master is

	signal addresTx : std_logic_vector(15 downto 0) := (others => H);
	signal dataTx : std_logic_vector(63 downto 0) := (others => H);
	signal NewTx : std_logic := L;
	signal txcnt : std_logic_vector(pkg_log2(dataTx'length)-1 downto 0) := (others => L);
	signal txd : std_logic_vector(63 downto 0) := (others => L);
	type tMasTx is (sIdle,sStartbit,sSendAddress,sCrcA,sData0,sData1,sData2,sData3,sCrcD,sEnd,sPause);
	signal MasTx : tMasTx := sIdle;
	signal TXr : std_logic := L;		
	signal TXPause : std_logic := L;		
	signal TXErr : std_logic := L;			
	signal TXBitClk	: std_logic := L;
	signal TxSr : std_logic_vector(15 downto 0) := (others => L);
	signal CRCPoly : std_logic_vector(7 downto 0) := x"d5";--b"00101111";
	signal TXCrc : std_logic_vector(7 downto 0) := (others => H);
	
	constant RCMAX : integer := 127;
	constant SWait : integer := RCMAX;
	constant SError : integer := RCMAX-1;
	signal rxcnt : integer range 0 to RCMAX := 0;
	signal RXCrc : std_logic_vector(7 downto 0) := (others => H);
	signal RPaus_n1 : std_logic := H;
	signal RxSr : std_logic_vector(63 downto 0) := (others => L);
	signal Error : std_logic_vector(3 downto 0) := (others => L);
	constant LINK_ERR : std_logic_vector(3 downto 0) := "0001";
	--constant ACRC_ERR : std_logic_vector(3 downto 0) := "0010";
	constant DCRC_ERR : std_logic_vector(3 downto 0) := "0100";
	constant SBIT_ERR : std_logic_vector(3 downto 0) := "1000";
	signal RXr : std_logic := L;		
	signal RErr	: std_logic := L;		
	signal RPaus : std_logic := H;	
	signal RXBitClk	: std_logic := L;
	signal LiErr : std_logic := L;
	signal RXData : std_logic_vector(63 downto 0) := (others => L);
	signal RXOK : std_logic := L;
	
	signal ForceACRCError : std_logic := L;
	signal ForceDCRCError : std_logic := L;
	signal ForceLinkError : std_logic := L;
	signal DataError : std_logic := L;
	signal TXr_and_error : std_logic := L;
	
	signal err_cnt  : std_logic_vector(15 downto 0) := (others => L);
	signal rx_ok_cnt  : std_logic_vector(15 downto 0) := (others => L);
	signal tx_ok_cnt  : std_logic_vector(15 downto 0) := (others => L);
	
	signal tp : std_logic := L;
	
	signal WaitForRx : std_logic := L;
begin
	
	il_enc : entity InfoLink.InfoLink_Encoder 
	generic map( 
		C_CLK_DIV_22MHZ => C_OVERSAMPLING/2
	)
	port map (     
		i_Clk		=> i_Clk	,-- clock 
		i_Rst		=> L		,-- reset
		o_TX		=> o_Tx		,-- info-link output                  			
		i_TXd		=> TXr_and_error		,-- TX-data input decoded  
		i_Pause		=> TXPause	,-- H: don't send (TX=H)
		i_TXErr		=> TXErr	,-- H: generate modulations errors
		o_BitClk	=> TXBitClk	 -- __-_____-_____-			
	);
	
	-- master tx
	TXr <= TxSr(TxSr'high);
	TXr_and_error <= TXr xor DataError;
	
	o_Ready <= not i_Start and not NewTx;
	
	o_tx_ok_cnt <= tx_ok_cnt;
	
	master_tx : process (i_Clk) begin 
		if rising_edge(i_Clk) then
			if (i_Start=H and NewTx=L) then
				NewTx <= H;
				addresTx <= i_Addr;
				dataTx <= i_Data;
			end if;
			if (i_ForceLinkError=H) then
				ForceLinkError <= H; 
			end if;
			if (i_ForceACRCError=H) then
				ForceACRCError <= H; 
			end if;
			if (i_ForceDCRCError=H) then
				ForceDCRCError <= H; 
			end if;
			
			if (TXBitClk=H) then
				TXErr <= L;
				DataError <= L;
				--											x^	  76543210								
				--	crc_poly: x^8 + x^5 + x^3 + x^2 + x^1 + 1 -> "10010111"
				TXCrc <= crc_gen(TXr, TXCrc, CRCPoly);
				TxSr(TxSr'high downto 0) <=  TxSr(TxSr'high-1 downto 0) & L;
				txcnt <= txcnt-1;
				TXPause <= L;
				case MasTx is
				when sIdle =>
					TXPause <= H;
					if (NewTx=H) then
						MasTx <= sStartbit;
						TXPause <= L;
					end if;
					TXCrc <= (others => H);
					txcnt <= (others => L);
				when sStartbit =>
					MasTx <= sSendAddress;
					TxSr <= addresTx;
					txcnt <= conv_std_logic_vector(15,txcnt'length);
					TXCrc <= (others => H);
				when sSendAddress =>
					txcnt <= txcnt-1;
					--TXCrc <= crc_gen(TXr, TXCrc, CRCPoly);
					if txcnt=0 then
						MasTx <= sCrcA;
						TxSr <= crc_gen(TXr, TXCrc, CRCPoly) & x"00";
						txcnt <= conv_std_logic_vector(7,txcnt'length);
						TXErr <= ForceLinkError;
						ForceLinkError <= L;
					end if;
					if (ForceACRCError=H) then
						ForceACRCError <= L;
						DataError <= H;
					end if;
				when sCrcA =>
					TXCrc <= TXCrc;
					txcnt <= txcnt-1;
					if txcnt=0 then
						TXCrc <= (others => H);
						MasTx <= sData0;
						TxSr <= dataTx(63 downto 48);
						txcnt <= conv_std_logic_vector(15,txcnt'length);
					end if;
					if (ForceACRCError=H) then
						ForceACRCError <= L;
						DataError <= H;
					end if;
				when sData0 =>
					WaitForRx <= H;
					txcnt <= txcnt-1;
					if txcnt=0 then
						MasTx <= sData1;
						TxSr <= dataTx(47 downto 32);
						txcnt <= conv_std_logic_vector(15,txcnt'length);
					end if;
					if (ForceDCRCError=H) then
						ForceDCRCError <= L;
						DataError <= H;
					end if;
				when sData1 =>
					txcnt <= txcnt-1;
					if txcnt=0 then
						MasTx <= sData2;
						TxSr <= dataTx(31 downto 16);
						txcnt <= conv_std_logic_vector(15,txcnt'length);
					end if;
					if (ForceDCRCError=H) then
						ForceDCRCError <= L;
						DataError <= H;
					end if;
				when sData2 =>
					txcnt <= txcnt-1;
					if txcnt=0 then
						MasTx <= sData3;
						TxSr <= dataTx(15 downto 0);
						txcnt <= conv_std_logic_vector(15,txcnt'length);
					end if;
					if (ForceDCRCError=H) then
						ForceDCRCError <= L;
						DataError <= H;
					end if;
				when sData3 =>
					txcnt <= txcnt-1;
					if txcnt=0 then
						MasTx <= sCrcD;
						TxSr <= crc_gen(TXr, TXCrc, CRCPoly) & x"00";
						txcnt <= conv_std_logic_vector(7,txcnt'length);
					end if;
					if (ForceDCRCError=H) then
						ForceDCRCError <= L;
						DataError <= H;
					end if;					
				when sCrcD =>
					TXCrc <= TXCrc;
					txcnt <= txcnt-1;
					if txcnt=0 then
						MasTx <= sEnd;
						TXCrc <= (others => H);
					end if;
					if (ForceDCRCError=H) then
						ForceDCRCError <= L;
						DataError <= H;
					end if;
				when sEnd =>
					TXCrc <= (others => H);
					TXErr <= H;
					txcnt <= conv_std_logic_vector(7+8,txcnt'length);
					tx_ok_cnt <= tx_ok_cnt+1;
					MasTx <= sPause;
				when sPause => 
					TXPause <= H;
					if txcnt=0 then
						MasTx <= sIdle;
						NewTx <= L;
						WaitForRx <= L;
						--tx_ok_cnt <= tx_ok_cnt+1;
						o_Data <= RXData;
						o_DataValid <= RXOK;
						o_err_cnt <= err_cnt;
						o_rx_ok_cnt <= rx_ok_cnt;
						o_Error <= Error;
						
					end if;
				end case;
			end if;
		end if;
	end process master_tx;
	
	master_il_dec : entity InfoLink.InfoLink_Decoder 
	generic map ( 
		C_CLK_DIV_22MHZ => C_OVERSAMPLING/2,
		C_NO_FIBRE_DESKEW => 1,
		C_CONTINUOUS_BITCLK => 1
	)
	port map(     
		i_Clk		=> i_Clk	,-- clock 
		i_Rst		=> L		,-- reset
		i_RX		=> i_Rx		,-- info-link input
		o_RXd		=> RXr		,-- RX-data output decoded	
		o_RErr		=> RErr		,-- RX-Error  
		o_Paus		=> RPaus	,-- Pause      
		o_BitClk    => RXBitClk	,-- RXCnt(x);    
		o_LiErr		=> LiErr	,-- dignosis link-error
		i_clrLiErr	=> L							
	);
	
	master_rx : process (i_Clk) begin
		if rising_edge(i_Clk) then
			RPaus_n1 <= RPaus;
			if  (WaitForRx=L) then
				rxcnt <= SWait;
				Error <= (others => L);
				RXOK <= L;
			elsif ((RPaus=L and RPaus_n1=H)) then
				rxcnt <= 0;
				RxSr <= (others => L);
			elsif (RXBitClk=H) then
				tp <= L;
				if (rxcnt<SError) then
					rxcnt <= rxcnt+1;
				end if;
				RXCrc <= crc_gen(RXr, RXCrc, CRCPoly);
				RxSr <= RxSr(RxSr'high-1 downto 0) & RXr;
				case rxcnt is
				when 0 =>
						RXCrc <= (others => H);
						if (RXr/=L) then
							Error <= Error or SBIT_ERR;
							rxcnt <= SError;
						end if;
				when 1 =>
						RXCrc <= (others => H);
						if (RXr/=L) then
							Error <= Error or SBIT_ERR;
							rxcnt <= SError;
						end if;
				when 66 =>
						RxData <= RxSr(63 downto 0);
				when 66+7 =>
					if (crc_gen(RXr, RXCrc, CRCPoly)=x"00") then
						
					else
						Error <= Error or DCRC_ERR; 
						rxcnt <= SError;
					end if;
				when 66+7+3 =>
					tp <= H;
					if (RErr=H) then
						RXOK <= H;
						rx_ok_cnt <= rx_ok_cnt+1;
						rxcnt <= SWait;
					else
						Error <= Error or LINK_ERR;
						rxcnt <= SError;
					end if;
				when SError =>
					err_cnt <= err_cnt+1;
					rxcnt <= SWait;
				when SWait =>
				when others =>
				end case;
				if (RErr=H and rxcnt<66+7) then                             
					Error <= Error or LINK_ERR;
					rxcnt <= SError;
				end if;
			end if;
		end if;
	end process master_rx;


end architecture impl;
