--------------------------------------------------------------------------------
--
--  esat_slave.vhd
--
--------------------------------------------------------------------------------
--
--  project     : esat
--  programmer  : C. Leuthold, INDEL AG
--  date        : 12.10.2015
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

entity esat_slave is
	generic (
		C_OVERSAMPLING : integer :=3	 	-- 66MHz
	);
	port (  
		i_Clk : in std_logic;
		i_Rx : in std_logic;
		o_Tx : out std_logic;
		o_Oe : out std_logic;
		i_ModAddr : in std_logic_vector(3 downto 0);
		o_err_cnt : out std_logic_vector(7 downto 0);
		o_ok_cnt : out std_logic_vector(7 downto 0);
		o_Error : out std_logic_vector(3 downto 0)
	);
end;

architecture impl of esat_slave is
	
	signal RXr : std_logic := L;		
	signal RErr	: std_logic := L;		
	signal RPaus : std_logic := L;	
	signal RXBitClk	: std_logic := L;
	signal LiErr : std_logic := L;

	signal RPaus_n1 : std_logic := L;
	signal CRCPoly : std_logic_vector(7 downto 0) := x"d5";--b"00101111";
	signal RXCrc : std_logic_vector(7 downto 0) := (others => H);
	signal TXCrc : std_logic_vector(7 downto 0) := (others => H);
	signal Sr : std_logic_vector(66 downto 0) := (others => L);
	signal addresRx : std_logic_vector(15 downto 0) := (others => L);
	signal RxData : std_logic_vector(63 downto 0) := (others => L);
	signal RxData16 : std_logic_vector(15 downto 0) := (others => L);
	signal TxData : std_logic_vector(63 downto 0) := x"0123456789abcdef";
	signal ModAddr : std_logic_vector(3 downto 0) := "0000";
	
	constant RCMAX : integer := 127;
	constant SWait : integer := RCMAX;
	constant SError : integer := RCMAX-1;
	signal rxcnt : integer range 0 to RCMAX := 0;
	
	signal Error : std_logic_vector(3 downto 0) := (others => L);
	constant LINK_ERR : std_logic_vector(3 downto 0) := "0001";
	constant ACRC_ERR : std_logic_vector(3 downto 0) := "0010";
	constant DCRC_ERR : std_logic_vector(3 downto 0) := "0100";
	
	signal acrc_err_cnt : std_logic_vector(15 downto 0) := (others => L);
	signal dcrc_err_cnt : std_logic_vector(15 downto 0) := (others => L);
	signal link_err_cnt : std_logic_vector(15 downto 0) := (others => L);
	
	
	signal TXr : std_logic := L;		
	signal TxPause : std_logic := L;	
	signal TXErr : std_logic := L;	
	signal TXBitClk : std_logic := L;
	
	signal RXOK : std_logic := L;
	signal bc1 : std_logic := L;
	signal bc2 : std_logic := L;
	
	signal Oe : std_logic := L;
	
	--                                                  fedcba9876543210
	signal TestCRCPoly : std_logic_vector(15 downto 0):= b"0001000000100001"; -- CRC-16-CCITT x^16+x^12+x^5+1
	
	signal tp : std_logic := L;
	signal dbg_rx_crc  : std_logic_vector(7 downto 0) := (others => H);
	
	signal err_cnt  : std_logic_vector(7 downto 0) := (others => L);
	signal ok_cnt  : std_logic_vector(7 downto 0) := (others => L);
	
	constant p : integer:=4;
	
begin
	
	o_Oe <= Oe;
	
	o_err_cnt <= err_cnt;
	o_ok_cnt <= ok_cnt;
	o_Error <= Error;
	
	slave_il_dec : entity InfoLink.InfoLink_Decoder 
	generic map ( 
		C_CLK_DIV_22MHZ => C_OVERSAMPLING/2,
		C_NO_FIBRE_DESKEW =>1,
		C_CONTINUOUS_BITCLK =>1
	)
	port map(     
		i_Clk		=> i_Clk	,-- clock 
		i_Rst		=> L		,-- reset
		i_RX		=> i_RX		,-- info-link input
		o_RXd		=> RXr		,-- RX-data output decoded	
		o_RErr		=> RErr		,-- RX-Error  
		o_Paus		=> RPaus	,-- Pause      
		o_BitClk    => RXBitClk	,-- RXCnt(x);    
		o_LiErr		=> LiErr	,-- dignosis link-error
		i_clrLiErr	=> L		,
		o_bc1		=> bc1,
		o_bc2		=> bc2
	);
	
	-- slave rx
	slave_rx : process (i_Clk) begin 
		if rising_edge(i_Clk) then
			RPaus_n1 <= RPaus;
			RXOK <= L;
			if (RPaus=L and RPaus_n1=H) then
				rxcnt <= 0;
				Sr <= (others => H);
				Error <= (others => L);
				Oe <= L;
				TxPause <= H;
				ModAddr <= i_ModAddr;
			elsif (RXBitClk=H) then
				if (rxcnt<SError) then
					rxcnt <= rxcnt+1;
				end if;
				RXCrc <= crc_gen(RXr, RXCrc, CRCPoly);
				TXCrc <= crc_gen(TXr, TXCrc, CRCPoly);
				Sr <= Sr(Sr'high-1 downto 0) & RXr;
				TXErr <= L;
				tp <= L;
				case rxcnt is
					when 1 =>
						RXCrc <= (others => H);
					when 18 =>
						addresRx <= Sr(15 downto 0);
					when 25 =>
						RXCrc <= (others => H);
						if (crc_gen(RXr, RXCrc, CRCPoly)=x"00") then
							if (addresRx(11 downto 8)=ModAddr) then
								Oe <= H;
								--TxPause <= L;
							else
								rxcnt <= SWait;
							end if;
						else
							Error <= Error or ACRC_ERR;
							acrc_err_cnt <= acrc_err_cnt+1;
							err_cnt <= err_cnt+1;
							rxcnt <= SError;
						end if;
					when 26+16 =>
						RxData16 <= Sr(15 downto 0);
					when 26+32 =>
						RxData16 <= Sr(15 downto 0);
					when 26+48 =>
						RxData16 <= Sr(15 downto 0);	
					when 26+64 =>
						RxData16 <= Sr(15 downto 0);
						RxData <= Sr(63 downto 0);
					when 25+64+8 =>
						if (crc_gen(RXr, RXCrc, CRCPoly)=x"00") then
						
						else
							Error <= Error or DCRC_ERR;
							dcrc_err_cnt <= dcrc_err_cnt+1;
							err_cnt <= err_cnt+1;
						end if;
					when 25+64+8+2 =>
						if (RErr=H) then
							if Error=0 then
								RXOK <= H;
								ok_cnt <= ok_cnt+1;
							end if;
						else
							Error <= Error or LINK_ERR;
							link_err_cnt <= link_err_cnt+1;
							err_cnt <= err_cnt+1;
						end if;
					when SError =>
					
					when SWait =>
						
					when others =>
				end case;
				--tx stats
				case rxcnt is
					--when 24 => 
					--	Sr(Sr'high downto 1) <= "00" & addresRx & TxData(63-16 downto 0);--crc_gen(addresRx, x"FFFF", TestCRCPoly) & crc_gen(addresRx, x"FFFF", TestCRCPoly) &crc_gen(addresRx, x"FFFF", TestCRCPoly);--TxData(63-16 downto 0);
					--when 26 =>
					--	TXCrc <= (others => H);
					when p+25 =>
						TxPause <= L;
					when p+24 => 
						Sr(Sr'high downto Sr'high-1) <= "00";
						Sr(Sr'high downto 1) <= (others => L);
					when p+26 =>
						TXCrc <= (others => H);
						if (addresRx(15)=L) then
							Sr(Sr'high downto Sr'high-15) <= addresRx;
						else
							Sr(Sr'high downto Sr'high-15) <= ok_cnt & err_cnt;
						end if;
						tp <= H;
					when p+26+16 =>
						if (addresRx(15)=L) then
							Sr(Sr'high downto Sr'high-15) <= crc_gen(addresRx, x"FFFF", TestCRCPoly);
						else
							Sr(Sr'high downto Sr'high-15) <= acrc_err_cnt;
						end if;
						tp <= H;
					when p+26+32 =>
						if (addresRx(15)=L) then
							Sr(Sr'high downto Sr'high-15) <= crc_gen(addresRx, x"0000", TestCRCPoly);
						else
							Sr(Sr'high downto Sr'high-15) <= dcrc_err_cnt;
						end if;
						tp <= H;
					when p+26+48 =>
						if (addresRx(15)=L) then
							Sr(Sr'high downto Sr'high-15) <= crc_gen(addresRx, x"1234", TestCRCPoly);
						else
							Sr(Sr'high downto Sr'high-15) <= link_err_cnt;
						end if;
						tp <= H;
					when p+26+64 =>
						Sr(Sr'high downto Sr'high-15) <= crc_gen(TXr, TXCrc, CRCPoly) & x"00";
						dbg_rx_crc <= crc_gen(TXr, TXCrc, CRCPoly);
						tp <= H;
					when p+25+64+8+1 =>
						TXErr <= H;
					when p+25+64+8+2 =>
						TxPause <= H;
						if Error=0 then
							rxcnt <= SWait;
						else
							rxcnt <= SError;
						end if;
					when others =>
				end case;
				
				if (RErr=H and rxcnt<(25+64+8)) then                             
					Error <= Error or LINK_ERR;
					link_err_cnt <= link_err_cnt+1;
					err_cnt <= err_cnt+1;
					rxcnt <= SError;
				end if;

			end if;
			
		end if;
	end process slave_rx;
	
	TXr <= Sr(Sr'high);
	
	slave_il_enc : entity InfoLink.InfoLink_Encoder 
	generic map( 
		C_CLK_DIV_22MHZ => C_OVERSAMPLING/2,
		C_EXTERNAL_BITCLK => 1
	)
	port map (     
		i_Clk		=> i_Clk	,-- clock 
		i_Rst		=> L		,-- reset
		o_TX		=> o_TX	,-- info-link output                  			
		i_TXd		=> TXr		,-- TX-data input decoded  
		i_Pause		=> TxPause	,-- H: don't send (TX=H)
		i_TXErr		=> TXErr	,-- H: generate modulations errors
		--i_bc		=> RXBitClk ,
		i_bc1		=> bc1,
		i_bc2		=> bc2,
		o_BitClk	=> TXBitClk	 -- __-_____-_____-			
	);
	


end architecture impl;
