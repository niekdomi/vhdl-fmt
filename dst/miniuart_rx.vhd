--------------------------------------------------------------------------------
--  miniuart_rx.vhd
--------------------------------------------------------------------------------
--
--	project     : 
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 24.04.2008
--	version     : 
--	language    : VHDL
--
--	purpose
--		miniuart_rx
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	30.04.2008-le:	- start
--------------------------------------------------------------------------------
--$Rev:: 685                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-10-22 10:15:36 +0200 (Mi, 22 Okt 2008)                          $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity miniuart_rx is

	port (
		i_clk : in std_logic;
		i_reset : in std_logic;
		i_clk_en	: in	std_logic;
		--serial data
		i_RX		: in std_logic;
		-- interface
		i_cfg : in  std_logic_vector(1 downto 0) := (others => L);
		o_Data : out std_logic_vector(7 downto 0);
		o_DataStr : out std_logic;
		o_PErr : out std_logic;
		o_Ferr : out std_logic
	);
end;                                                -- of entity miniuart_rx

architecture behavior_miniuart_rx of miniuart_rx is
-- constants -------------------------------------------------------------------
	constant DF_PARITY : integer := 0;
	constant DF_ODD : integer := 1;
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal start  : std_logic := L;
	signal start_n1  : std_logic := L;
	signal parity  : std_logic := L;
	signal RxData : std_logic_vector(o_Data'high+3 downto 0) := (others => L);
	signal clk_div : unsigned(3 downto 0) := "1001";
	signal cnt : unsigned(3 downto 0) := "1011";
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin
		o_Data <= RxData(RxData'high-2 downto 1);
		
		start <= H when (cnt=11 or (cnt=10 and i_cfg(DF_PARITY)=L)) else L;
		o_DataStr <= start and not start_n1;
		--o_Ferr <= not RxData(RxData'high) or RxData(0) when i_cfg(DF_PARITY)=H else not RxData(RxData'high-1) or RxData(0);
		
		RX : process (i_clk)
		begin
			if rising_edge(i_clk) then
				start_n1 <= start;
				if (i_reset=H) then
					clk_div <= "1001";
					parity <= L;
					cnt <= "1011";
					--RxData <= (others => L);
				--elsif (i_clk_en=H) then
				else
					if (start=H) then
						clk_div <= "1001";
						--RxData <= (others => L);
						if (i_RX=L) then
							cnt <= "0000";
							parity <= L;
						end if;
					else
						if (i_clk_en=H) then
							clk_div <= clk_div + 1;
							if (clk_div=0) then
								--RxData(conv_integer(cnt)) <= i_RX;
								case cnt is
								when "0000" => RxData(0) <= i_RX;
								when "0001" => RxData(1) <= i_RX;
								when "0010" => RxData(2) <= i_RX;
								when "0011" => RxData(3) <= i_RX;
								when "0100" => RxData(4) <= i_RX;
								when "0101" => RxData(5) <= i_RX;
								when "0110" => RxData(6) <= i_RX;
								when "0111" => RxData(7) <= i_RX;
								when "1000" => RxData(8) <= i_RX;
								when "1001" => RxData(9) <= i_RX;
												if (i_cfg(DF_PARITY)=L) then
													o_Ferr <= not i_Rx or RxData(0);
													o_PErr <= L;
												end if;
								when "1010" => RxData(10) <= i_RX;
												o_PErr <= (parity xor i_cfg(DF_ODD)) and i_cfg(DF_PARITY);
												o_Ferr <= not i_Rx or RxData(0);
								when others => null;
								end case;
								parity <= parity xor i_Rx;
								cnt <= cnt + 1;
							end if;
						end if;
					end if;
				end if;
			end if;
		end process RX;
	
end behavior_miniuart_rx;
--------------------------------------------------------------------------------

