--------------------------------------------------------------------------------
--
--  FIFO_1kByte_i8_o16.vhd
--
--------------------------------------------------------------------------------
--
--  project     : FIFO
--  programmer  : F. Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
--$Rev:: 1973                                                                  $
--$Author:: fb                                                           	   $
--$Date:: 2011-06-16 08:57:47 +0200 (Do, 16 Jun 2011)                          $
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

LIBRARY BRAM;
USE BRAM.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--	Die Daten am FIFO-Ausgang liegen immer schon nach einem Clock an.
entity FIFO_1kByte_i8_o16 is
	port (
		i_Reset		: IN  std_logic 					:= L;

		i_CLKin		: IN  std_logic 					:= L;
		i_ENin		: IN  std_logic 					:= L;
		i_DATAin	: IN  std_logic_vector( 7 downto 0) := (others => L);

		i_CLKout	: IN  std_logic 					:= L;
		i_ENout		: IN  std_logic_vector( 1 downto 0) := (others => L);
		o_DATAout	: OUT std_logic_vector(15 downto 0) := (others => L);

		o_Level		: OUT std_logic_vector( 9 downto 0) := (others => L)
	);
end FIFO_1kByte_i8_o16;

architecture impl OF FIFO_1kByte_i8_o16 is
--------------------------------------------------------------------------------

	signal 	ADDRin		: std_logic_vector( 9 downto 0) := (others => L);
	signal 	ADDRin_t1	: std_logic_vector( 9 downto 0) := (others => L);

	signal  ADDRout		: std_logic_vector( 9 downto 0) := (others => L);
	-- 0.5k LowByte
	signal  ALBout		: std_logic_vector( 8 downto 0) := (others => L);
	-- 0.5k HighByte
	signal 	AHBout		: std_logic_vector( 8 downto 0) := (others => L);

	signal 	Level		: std_logic_vector( 9 downto 0) := (others => L);
	signal 	Level_1		: std_logic_vector( 9 downto 0) := (others => L);
	signal 	switch		: std_logic_vector( 2 downto 0) := (others => L);

--------------------------------------------------------------------------------
	signal	BH_Clk_A	: std_logic						 := L;
	signal	BH_WEN_A	: std_logic						:= L;
	signal	BH_Addr_A	: std_logic_vector( 9 downto 0) := (others => L);
	signal	BH_Din_A	: std_logic_vector( 7 downto 0) := (others => L);

	signal	BH_Clk_B	: std_logic 					:= L;
	signal	BH_Addr_B	: std_logic_vector( 9 downto 0) := (others => L);
	signal	BH_Dout_B 	: std_logic_vector( 7 downto 0) := (others => L);

--------------------------------------------------------------------------------
	signal	BL_Clk_A	: std_logic						 := L;
	signal	BL_WEN_A	: std_logic						:= L;
	signal	BL_Addr_A	: std_logic_vector( 9 downto 0) := (others => L);
	signal	BL_Din_A	: std_logic_vector( 7 downto 0) := (others => L);

	signal	BL_Clk_B	: std_logic 					:= L;
	signal	BL_Addr_B	: std_logic_vector( 9 downto 0) := (others => L);
	signal	BL_Dout_B	: std_logic_vector( 7 downto 0) := (others => L);

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	o_Level 	<= Level_1;

--------------------------------------------------------------------------------
--	write a byte into Fifo
--------------------------------------------------------------------------------
--		HB		LB
--	  00		01
--	  02		03
--------------------------------------------------------------------------------

	BH_Clk_A  	<= i_CLKin;
	BH_Din_A  	<= i_DATAin;
	BH_Addr_A   <= '0' & ADDRin(9 downto 1);

	BL_Clk_A  	<= i_CLKin;
	BL_Din_A  	<= i_DATAin;
	BL_Addr_A   <= '0' & ADDRin(9 downto 1);

	process(i_Enin,ADDRin) begin
		BH_WEN_A <= L;
		BL_WEN_A <= L;

		if (i_Enin = H) then
			if (ADDRin(0) = L) then
				-- write first byte to HB
				BH_WEN_A <= H;
			else
				-- write second byte to LB
				BL_WEN_A <= H;
			end if;
		end if;
	end process;


	process (i_CLKin) begin
		if rising_edge(i_CLKin) then

			ADDRin_t1 <= ADDRin;

			if (i_Reset = H) then
				ADDRin 		<= (others => L);
				ADDRin_t1 	<= (others => L);
			else
				if (i_Enin = H) then
					ADDRin <= ADDRin + 1;
				end if;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	read a byte or word from FIFO	(2 x 0.5kByte)
--------------------------------------------------------------------------------
	BH_Clk_B  	<= i_CLKout;
	BH_Addr_B   <= '0' & AHBout;

	BL_Clk_B  	<= i_CLKout;
	BL_Addr_B   <= '0' & ALBout;

	----------------------------------------------------------------------------
	--	Read Data aligned/unaligned mux
	----------------------------------------------------------------------------
   	switch <= ADDRout(0) & i_ENout;
	process (switch,BH_Dout_B,BL_Dout_B) begin
		------------------------------------------------------------------------
		case (switch) is

		when "001" =>	o_DATAout <= x"00"		& BH_Dout_B;
		when "010" =>	o_DATAout <= BH_Dout_B	& x"00";
		when "011" =>	o_DATAout <= BH_Dout_B	& BL_Dout_B;

		when "101" =>	o_DATAout <= x"00"		& BL_Dout_B;
		when "110" =>	o_DATAout <= BL_Dout_B	& x"00";
		when "111" =>	o_DATAout <= BL_Dout_B	& BH_Dout_B;
		------------------------------------------------------------------------
		when others => o_DATAout <= x"00_00";
		end case;
		------------------------------------------------------------------------
	end process;


	----------------------------------------------------------------------------
	--	asynchron part FIFO Rd-Adr
	----------------------------------------------------------------------------
	--	Ich zeige voraus immer schon auf die nächsten Daten,
	--	damit dass sie schon nach 1clk gelesen werden können
	----------------------------------------------------------------------------
	process (switch,ADDRout) begin

		------------------------------------------------------------------------
		case (switch) is
		when "000" =>	AHBout <= ADDRout(9 downto 1);
		when "001" =>	AHBout <= ADDRout(9 downto 1) + 1;
		when "010" =>	AHBout <= ADDRout(9 downto 1) + 1;
		when "011" =>	AHBout <= ADDRout(9 downto 1) + 1;

		when "100" =>	AHBout <= ADDRout(9 downto 1) + 1;
		when "101" =>	AHBout <= ADDRout(9 downto 1) + 1;
		when "110" =>	AHBout <= ADDRout(9 downto 1) + 1;
		when "111" =>	AHBout <= ADDRout(9 downto 1) + 2; 	-- sehr weit vorausschauend
		------------------------------------------------------------------------
		when others => 	null;
		end case;
		------------------------------------------------------------------------

		------------------------------------------------------------------------
		case (switch) is
		when "000" =>	ALBout <= ADDRout(9 downto 1);
		when "001" =>	ALBout <= ADDRout(9 downto 1);
		when "010" =>	ALBout <= ADDRout(9 downto 1);
		when "011" =>	ALBout <= ADDRout(9 downto 1) + 1;

		when "100" =>	ALBout <= ADDRout(9 downto 1);
		when "101" =>	ALBout <= ADDRout(9 downto 1) + 1;
		when "110" =>	ALBout <= ADDRout(9 downto 1) + 1;
		when "111" =>	ALBout <= ADDRout(9 downto 1) + 1;
		------------------------------------------------------------------------
		when others => 	null;
		end case;
		------------------------------------------------------------------------

	end process;

	----------------------------------------------------------------------------
	--	synchron part of FIFO Rd-Adr
	----------------------------------------------------------------------------
	process (i_CLKin) begin
		if rising_edge(i_CLKin) then
			if (i_Reset = H) then
				ADDRout <= (others => L);
			else
				----------------------------------------------------------------
				case (switch) is

				when "001" =>	ADDRout <= ADDRout + 1;
				when "010" =>	ADDRout <= ADDRout + 1;
				when "011" =>	ADDRout <= ADDRout + 2;

				when "101" =>	ADDRout <= ADDRout + 1;
				when "110" =>	ADDRout <= ADDRout + 1;
				when "111" =>	ADDRout <= ADDRout + 2;
				----------------------------------------------------------------
				when others => null;
				end case;
				----------------------------------------------------------------
			end if;
		end if;
	end process;


--------------------------------------------------------------------------------
--	FIFO Level
--------------------------------------------------------------------------------
	process (ADDRin_t1,ADDRout) begin
		Level_1 <= (ADDRin_t1 - ADDRout) after 3 ns;
	end process;

--------------------------------------------------------------------------------
-- 	Two 8-but RAM , write 8-Bit interleaved, read 16-Bit parallel
--------------------------------------------------------------------------------
-- kleinere als 1kByte RAM gibt es im Spartan-6 nicht, daher
-- 2x1KByte, aber mit A9 fix = 0
inst_BRAM_H: entity BRAM.BRAM_1kByte_A8_B8
	port map (
		i_BRAM_Clk_A  	=>  BH_Clk_A 	,
		i_BRAM_WEN_A  	=>  BH_WEN_A	,
		i_BRAM_Addr_A 	=>  BH_Addr_A  	,
		i_BRAM_Dout_A  	=>  BH_Din_A   	,

		i_BRAM_Clk_B  	=>  BH_Clk_B   	,
		i_BRAM_Addr_B 	=>  BH_Addr_B  	,
		o_BRAM_Din_B  	=>  BH_Dout_B
	);

inst_BRAM_L: entity BRAM.BRAM_1kByte_A8_B8
	port map (
		i_BRAM_Clk_A  	=>  BL_Clk_A 	,
		i_BRAM_WEN_A  	=>  BL_WEN_A	,
		i_BRAM_Addr_A 	=>  BL_Addr_A  	,
		i_BRAM_Dout_A  	=>  BL_Din_A   	,

		i_BRAM_Clk_B  	=>  BL_Clk_B   	,
		i_BRAM_Addr_B 	=>  BL_Addr_B  	,
		o_BRAM_Din_B  	=>  BL_Dout_B
	);

--------------------------------------------------------------------------------
end architecture impl;
--------------------------------------------------------------------------------
