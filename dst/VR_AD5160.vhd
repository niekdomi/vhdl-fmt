--------------------------------------------------------------------------------
--
--  VR_AD5160 	(Delvotec USG SubModule)
--
--------------------------------------------------------------------------------
--
--  project     : VR_AD5160
--  programmer  : , INDEL AG
--  date        : 24.05.2018
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose:
--  	- communication with AD5160 over SPI
--		- module has not a MISO signal
--		- max frequency for AD5160  = 25 MHz
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	24.05.2018-VZ	- erste Version
--	31.05.2018-VZ	- Bit Counter korrigiert
--------------------------------------------------------------------------------
--$Rev:: 3835                                                                  $
--$Author:: fbaschung                                                          $
--$Date:: 2015-11-06 07:59:36 +0100 (Fr., 06 Nov 2015)                         $
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

--------------------------------------------------------------------------------
entity VR_AD5160 is
	generic (
		 g_clkDiv		: in	integer range 4 to 250 	:= 8; 	-- f_SPI = i_Clk/g_clkDiv
		 g_data_length	: in	integer					:= 8	-- 	
	);
	port (
		 i_Clk			: in	std_logic;
		 o_wait			: out 	std_logic;
		-- SPI pins
		 o_SPI_CLK		: out	std_logic;
		 o_SPI_CONV		: out	std_logic;
		 o_SPI_Dout		: out	std_logic;

		-- a short start puls	_-_
		 i_POT_WR_SP	: in	std_logic;

		 i_POT_WrData	: in	std_logic_vector(g_data_length-1 downto 0)
		 
		 --o_done			: out	std_logic
    );
end VR_AD5160;

--------------------------------------------------------------------------------
architecture impl of VR_AD5160 is
--------------------------------------------------------------------------------
	
	type sPOTSeq is (sIdle,sPreCLK,sOUT,sPostCLK);	
	signal POTSeq: sPOTSeq := sIdle;	    -- DAC-sequencer

	----------------------------------------------------------------------------
	--	Data-Ports
	----------------------------------------------------------------------------
	signal	Tx_Start		: std_logic 					:= '0';
	signal	SPI_ClkEn 		: std_logic 					:= '0';
	signal	SPI_ClkCnt 		: std_logic_vector(pkg_log2(g_clkDiv)-1 downto 0)	:= (others => '0');

	-- signals for whole 34 bit spi cycle
	signal	Tx_ClkEn 		: std_logic 					:= '0';
	signal	Tx_RUN 			: std_logic 					:= '0';
	signal	Tx_BitCnt 		: integer						:= 7;
	signal	Tx_Data			: std_logic_vector( 7 downto 0)	:= (others => '0');
	
	----------------------------------------------------------------------------
	--	SPI Pins
	----------------------------------------------------------------------------
	signal	SPI_CLK 		: std_logic 					:= '0';
	signal	SPI_CONV		: std_logic						:= H;
	signal	SPI_Dout 		: std_logic 					:= '0';

--------------------------------------------------------------------------------

begin

--------------------------------------------------------------------------------
--	Test-Points
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	In / Out
--------------------------------------------------------------------------------
	o_wait		<= Tx_RUN;

	o_SPI_CLK	<= SPI_Clk;
	o_SPI_CONV	<= SPI_CONV;
	o_SPI_Dout	<= SPI_Dout;

--------------------------------------------------------------------------------
--	SPI		Clock
--------------------------------------------------------------------------------
	process(i_Clk) begin
		if rising_edge(i_Clk) then
			Tx_ClkEn <= L;
			SPI_ClkCnt <= SPI_ClkCnt +1;

			if (SPI_ClkCnt = (g_clkDiv-1)) then
				SPI_ClkCnt <= (others => L);
			end if;
			if(SPI_ClkCnt = (g_clkDiv-1)) then
				Tx_ClkEn <= H;	-- clk_en pulse for further logic
			end if;

			if (SPI_ClkCnt = ((g_clkDiv/2)-1)) then
				SPI_Clk <= SPI_ClkEn; -- divided SPI clock
			end if;
			if (SPI_ClkCnt = (g_clkDiv-1)) then
				SPI_Clk <= L;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
-- SPI
--				  1	  2	  3	  4	  5	  6	  7	  8	  9	  10
-- SCLK	:	______--__--__--__--__--__--__--__--__--__--___________
-- CS	:	------__________________________________---------------
-- SDI	:	XXXXXXXX77776666555544443333222211110000XXXXXXXXXXXXXXXX
--													RDAC Register Load
-- VOUT	:											 analog mV
--

--------------------------------------------------------------------------------
--	Latch Start-Puls
--------------------------------------------------------------------------------
	process(i_Clk) begin
		if rising_edge(i_Clk) then
			if (i_POT_WR_SP = H) then
				Tx_Start <= H;
			elsif (Tx_RUN = H) then
				Tx_Start <= L;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	SPI   Sequencer
--------------------------------------------------------------------------------
	process(i_Clk) begin
		if rising_edge(i_Clk) then
			-- desc. use slow spi clk
			if (Tx_ClkEn = H) then
				SPI_CONV <= H;
				case POTSeq is
				-- desc. Wait for operation
				when sIdle =>
					if(Tx_Start = H) then
						Tx_RUN <= H;
						POTSeq <= sPreCLK;
						Tx_Data <= i_POT_WrData;
						Tx_BitCnt <= Tx_Data'high;
						SPI_ClkEn <= H;
					end if;
				-- desc. one clock pulse extra
				when sPreCLK =>
					SPI_CONV <= L;
					POTSeq <= sOUT;
					-- buffer MSB out 
					SPI_Dout <= Tx_Data(Tx_Data'high);
				-- desc. buffer bits e.g 6 downto 0
				when sOUT =>
					if(Tx_BitCnt > 0) then
						SPI_CONV <= L;
						Tx_BitCnt <= Tx_BitCnt - 1;
						SPI_Dout <= Tx_Data(Tx_BitCnt-1);
					else 
						Tx_BitCnt <= Tx_Data'high;
						POTSeq <= sPostCLK;
						SPI_Dout <= L;
					end if;
				--desc. one clock pulse extra 
				when sPostCLK =>
					POTSeq <= sIdle;
					Tx_RUN <= L;
					SPI_ClkEn <= L;
				when others => NULL;
				end case;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
