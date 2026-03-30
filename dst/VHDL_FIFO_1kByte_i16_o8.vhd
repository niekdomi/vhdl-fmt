--------------------------------------------------------------------------------
--
--  FIFO_1kByte_x32.vhd
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
--$Author:: fb                                                                 $
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
entity FIFO_1kByte_i16_o8 is
	port (
		i_Reset		: IN  std_logic 					:= '0';

		i_CLKin		: IN  std_logic;
		i_ENin		: IN  std_logic_vector( 1 downto 0) := (others => '0');
		i_DATAin	: IN  std_logic_vector(15 downto 0) := (others => '0');

		i_CLKout	: IN  std_logic;
		i_ENout		: IN  std_logic 					:= '0';
--		o_DATAout	: OUT std_logic_vector( 7 downto 0) := (others => '0');
		o_REGout	: OUT std_logic_vector( 7 downto 0) := (others => '0');

		o_Level		: OUT std_logic_vector( 9 downto 0) := (others => '0')
	);
end FIFO_1kByte_i16_o8;

architecture impl OF FIFO_1kByte_i16_o8 is
--------------------------------------------------------------------------------
	signal 	ADDRin 		: std_logic_vector( 9 downto 0) := (others => '0');
	signal 	ADDRin_t1	: std_logic_vector( 9 downto 0) := (others => '0');
	signal 	ADDRout 	: std_logic_vector( 9 downto 0) := (others => '0');

	signal 	Level	 	: std_logic_vector( 9 downto 0) := (others => '0');

	signal 	OneMore	 	: std_logic						:= '0';
	signal 	LastByte	: std_logic_vector( 7 downto 0) := (others => '0');

	signal 	switch		: std_logic_vector( 3 downto 0) := (others => '0');

--------------------------------------------------------------------------------
	signal	BRAM_Clk_A  : std_logic						:= '0';
	signal	BRAM_EN_A   : std_logic						:= '1';
	signal	BRAM_WEN_A  : std_logic_vector( 1 downto 0)	:= "00";
	signal	BRAM_Addr_A : std_logic_vector( 8 downto 0) := (others => '0');
	signal	BRAM_Din_A  : std_logic_vector(15 downto 0) := (others => '0');
	signal	BRAM_Dout_A : std_logic_vector(15 downto 0) := (others => '0');

	signal	BRAM_Clk_B  : std_logic 					:= '0';
	signal	BRAM_EN_B   : std_logic 					:= '1';
	signal	BRAM_WEN_B  : std_logic_vector( 1 downto 0) := "00";
	signal	BRAM_Addr_B : std_logic_vector( 8 downto 0) := (others => '0');
	signal	BRAM_Din_B  : std_logic_vector(15 downto 0) := (others => '0');
	signal	BRAM_Dout_B : std_logic_vector(15 downto 0) := (others => '0');

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	o_Level 	<= Level;
	BRAM_Clk_A 	<= i_CLKin  after 1 ns;
	BRAM_Clk_B 	<= i_CLKout;

--------------------------------------------------------------------------------
--	Ablauf Beispiele
--------------------------------------------------------------------------------
-- E10 		data	LB		FIFO
--	01		--00	--		00-- ---- ---- ---- ---- ----
--
--	11		1234	34		0012 ---- ---- ---- ---- ----
--	00		----	--		0012 34-- ---- ---- ---- ----
--
--	11		5678	78		0012 3456 ---- ---- ---- ----
--	11		9ABC	BC		0012 3456 789A ---- ---- ----
--	10		DE--	--		0012 3456 789A BCDE ---- ----
--	01		--F0	--		0012 3456 789A BCDE F0-- ----
--------------------------------------------------------------------------------
--	write a byte or word into Fifo
--------------------------------------------------------------------------------
--	Enin(0)	write low byte		(i_DATAin( 0 downto 0)
--	Enin(1)	write high bytes	(i_DATAin(15 downto 8)
--------------------------------------------------------------------------------
	switch <= OneMore & ADDRin(0) & i_Enin(1) & i_Enin(0);

	process (i_CLKin) begin

		if rising_edge(i_CLKin) then

			ADDRin_t1	<= ADDRin;
			BRAM_Din_A  <= (others => '0');
			BRAM_WEN_A  <= (others => '0');

			if (i_Reset = H) then
				ADDRin 	 <= (others => '0');
				LastByte <= (others => '0');
				OneMore  <= L;
			else

				----------------------------------------------------------------
				case (switch) is
				----------------------------------------------------------------
				when "0000" =>	-- nothing to to

				----------------------------------------------------------------
				when "0001" =>	-- wr one (low)byte to even FIFO-addr
					BRAM_Din_A(15 downto 8) <= i_DATAin( 7 downto 0);
					BRAM_WEN_A <= "10";
					ADDRin <= ADDRin + 1;

				----------------------------------------------------------------
				when "0010" =>	-- wr one (hi)byte to even FIFO-addr
					BRAM_Din_A(15 downto 8) <= i_DATAin(15 downto 8);
					BRAM_WEN_A <= "10";
					ADDRin <= ADDRin + 1;

				----------------------------------------------------------------
				when "0011" =>	-- wr two bytes to even FIFO-addr
					BRAM_Din_A <= i_DATAin;
					BRAM_WEN_A <= "11";
					ADDRin <= ADDRin + 2;

				----------------------------------------------------------------
				when "0100" =>	-- nothing to to

				----------------------------------------------------------------
				when "0101"	=>	-- wr one (low)byte to odd FIFO-addr
					BRAM_Din_A( 7 downto 0) <= i_DATAin(15 downto 8);
					BRAM_WEN_A <= "01";
					ADDRin <= ADDRin + 1;

				----------------------------------------------------------------
				when "0110" =>  -- wr one (hi)byte to odd FIFO-addr
					BRAM_Din_A( 7 downto 0) <= i_DATAin(15 downto 8);
					BRAM_WEN_A <= "01";
					ADDRin <= ADDRin + 1;

				----------------------------------------------------------------
				when "0111" => 	-- wr two bytes to odd FIFO-addr
					BRAM_Din_A( 7 downto 0) <= i_DATAin(15 downto 8);
					BRAM_WEN_A <= "01";
					ADDRin <= ADDRin + 1;
					-- we still have to do store one byte more into FIFO (later)
					OneMore <= '1';
					-- save this last byte
					LastByte <= i_DATAin( 7 downto 0);

				----------------------------------------------------------------
				-- still a LastByte to store
				----------------------------------------------------------------
				when "1000" =>	-- no external wr, store LastByte to even FIFO-a
					BRAM_Din_A(15 downto 8) <= LastByte;
					BRAM_WEN_A <= "10";
					ADDRin <= ADDRin + 1;
					OneMore <= '0';		-- done
					LastByte <= x"00";	-- just for fun

				----------------------------------------------------------------
				when "1001" =>	-- store Last(low)Byte to even FIFO-addr
								-- wr one bytes to next FIFO-addr
					BRAM_Din_A(15 downto 8) <= LastByte;
					BRAM_Din_A( 7 downto 0) <= i_DATAin( 7 downto 0);
					BRAM_WEN_A <= "11";
					ADDRin <= ADDRin + 2;
					OneMore <= '0';		-- done
					LastByte <= x"00";	-- just for fun

				----------------------------------------------------------------
				when "1010" =>	-- store Last(hi)Byte to even FIFO-addr
								-- wr one bytes to next FIFO-addr
					BRAM_Din_A(15 downto 8) <= LastByte;
					BRAM_Din_A( 7 downto 0) <= i_DATAin(15 downto 8);
					BRAM_WEN_A <= "11";
					ADDRin <= ADDRin + 2;
					OneMore <= '0';		-- done
					LastByte <= x"00";	-- just for fun

				----------------------------------------------------------------
				when "1011" => 	-- store LastByte to even FIFO-addr
				   				-- wr two bytes to next FIFO-addr
					BRAM_Din_A(15 downto 8) <= LastByte;
					BRAM_Din_A( 7 downto 0) <= i_DATAin(15 downto 8);
					BRAM_WEN_A <= "11";
					ADDRin <= ADDRin + 2;
					-- we still have to do store one byte more into FIFO (later)
					OneMore <= '1';
					-- save this last byte
					LastByte <= i_DATAin( 7 downto 0);

				----------------------------------------------------------------
				when "1100" =>	-- no external wr, store LastByte to odd FIFO-ad
					BRAM_Din_A( 7 downto 0) <= LastByte;
					BRAM_WEN_A <= "01";
					ADDRin <= ADDRin + 1;
					OneMore <= '0';		-- done
					LastByte <= x"00";	-- just for fun

				----------------------------------------------------------------
				when "1101" =>	-- store LastByte to odd FIFO-addr
								-- wr one (low)bytes to next FIFO-addr
					BRAM_Din_A( 7 downto 0) <= LastByte;
					BRAM_WEN_A <= "01";
					ADDRin <= ADDRin + 1;
					-- we still have to do store one byte more into FIFO (later)
					OneMore <= '1';
					-- save this last byte
					LastByte <= i_DATAin( 7 downto 0);

				----------------------------------------------------------------
				when "1110" =>	-- store LastByte to odd FIFO-addr
								-- wr one (hi)bytes to next FIFO-addr
					BRAM_Din_A( 7 downto 0) <= LastByte;
					BRAM_WEN_A <= "01";
					ADDRin <= ADDRin + 1;
					-- we still have to do store one byte more into FIFO (later)
					OneMore <= '1';
					-- save this last byte
					LastByte <= i_DATAin(15 downto 8);

				----------------------------------------------------------------
				when "1111" =>	-- not possible
					OneMore <= '0';		-- done
					LastByte <= x"00";	-- just for fun

				----------------------------------------------------------------
				when others => null;
				end case;
				----------------------------------------------------------------
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	read a byte from FIFO
--------------------------------------------------------------------------------
	BRAM_Addr_A <= ADDRin_t1( 9 downto 1);	-- muss ADDRin_t1 sein!!
	BRAM_Addr_B <= ADDRout( 9 downto 1);

	process (i_CLKout) begin
		if rising_edge(i_CLKout) then

			if (i_Reset = H) then
			  	ADDRout <= (others => '0');
			else
				if (i_ENout = '1') and (Level > 0) then
					if (ADDRout(0) = '0') then
						o_REGout <= BRAM_Dout_B(15 downto 8) after 5 ns;
					else
						o_REGout <= BRAM_Dout_B( 7 downto 0) after 5 ns;
					end if;
					ADDRout <= ADDRout + 1;
				end if;
			end if;

		end if;
	end process;


	process (ADDRin_t1,ADDRout) begin
		Level <= (ADDRin_t1 - ADDRout) after 3 ns;
	end process;

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
inst_BRAM: entity BRAM.BRAM_1kByte_A16_B16
	port map (
		i_BRAM_Clk_A  	=>  BRAM_Clk_A 		,
		i_BRAM_WEN_A  	=>  BRAM_WEN_A   	,
		i_BRAM_Addr_A 	=>  BRAM_Addr_A  	,
		o_BRAM_Din_A  	=>  BRAM_Dout_A  	,
		i_BRAM_Dout_A  	=>  BRAM_Din_A   	,

		i_BRAM_Clk_B  	=>  BRAM_Clk_B   	,
		i_BRAM_Addr_B 	=>  BRAM_Addr_B  	,
		o_BRAM_Din_B  	=>  BRAM_Dout_B  	,
		i_BRAM_Dout_B  	=>  BRAM_Din_B
	);

--------------------------------------------------------------------------------
end architecture impl;
--------------------------------------------------------------------------------
