--------------------------------------------------------------------------------
--
--  esat_tb.vhd
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

entity esat_tb is
end;

architecture impl of esat_tb is
	
	constant DF_CLK_FREQ : integer := 100000000;
	constant DF_CLK_PERIOD : time := 1000.0 ms / DF_CLK_FREQ;
	constant DF_OVERSAMPLING : integer := 8;
	
	signal i_Clk : std_logic := H;
	signal o_MaTX : std_logic;
	signal i_MaRX : std_logic := L;
	signal o_Ready : std_logic;
	
	constant addres : tSLV_Nx16(0 to 9) := (x"1034", x"8001", x"5155", x"a0aa", x"f0ff", x"0000", x"0003", x"8088",(others => H), (others => L)); 
	constant data : tSLV_Nx64(0 to 9) := (x"0123456789abcdef", x"8000000000000001", x"5555555555555555", x"aaaaaaaaaaaaaaaa", x"0000000000000000", x"FFFFFFFFFFFFFFFF", x"0123456789abcdef", x"0123456789abcdef",(others => H), (others => L));
	
	signal addresTx : std_logic_vector(15 downto 0) := (others => H);
	signal dataTx : std_logic_vector(63 downto 0) := (others => H);
	signal NewTx : std_logic := L;
		
	constant NO_OF_MOD : integer := 2;
	
	signal i_ForceACRCError : std_logic := L;
	signal i_ForceDCRCError : std_logic := L;	
	signal i_ForceLinkError : std_logic := L;
	
begin
	-- Stimulus process
	stim_proc: process
	begin
		
		wait for DF_CLK_PERIOD*50;
		wait until rising_edge(i_Clk);-- and TXBitClk=H;
		
		addresTx <= addres(0);
		dataTx <= data(0);
		NewTx <= H;
		wait until rising_edge(i_Clk);-- and TXBitClk=H;
		NewTx <= L;
		
		for i in 1 to 9 loop
			wait until o_Ready=H;
			addresTx <= addres(i);
			dataTx <= data(i);
			NewTx <= H;
		--	if (i=3) then
		--		i_ForceACRCError <= H;
		--	end if;
		--	if (i=4) then
		--		i_ForceDCRCError <= H;
		--	end if;
		--	if (i=5) then
		--		i_ForceLinkError <= H;
		--	end if;
			wait until rising_edge(i_Clk);-- and TXBitClk=H;
			NewTx <= L;
			i_ForceACRCError <= L;
			i_ForceDCRCError <= L;	
			i_ForceLinkError <= L;
			wait until rising_edge(i_Clk);
			--wait for (addresTx'length+8+64+8+9)*DF_CLK_PERIOD*DF_OVERSAMPLING;
		end loop;
		wait;
	end process;
	
	clock_process :process
	begin
		i_Clk <= '1';
		wait for DF_CLK_PERIOD/2;
		i_Clk <= '0';
		wait for DF_CLK_PERIOD/2;
	end process;
	
	esat_master: entity work.esat_master
	generic map (
		C_OVERSAMPLING => DF_OVERSAMPLING
	)
	port map (  
		i_Clk => i_Clk,
		i_Rx => i_MaRX,
		o_Tx => o_MaTX,
		i_Addr => addresTx,
		i_Data => dataTx,
		i_Start => NewTx,
		o_Ready => o_Ready,
		i_ForceACRCError => i_ForceACRCError,
		i_ForceDCRCError => i_ForceDCRCError,
		i_ForceLinkError => i_ForceLinkError
	);
	
	slaves: for i in 0 to NO_OF_MOD-1 generate
		constant DF_CLK_PERIOD_MOD : time := (1000.0 ms / DF_CLK_FREQ);
		signal ModAddr : tSLV_Nx4(0 to NO_OF_MOD-1);
		signal Tx: std_logic_vector(NO_OF_MOD-1 downto 0) := (others => L);
		signal Oe: std_logic_vector(NO_OF_MOD-1 downto 0) := (others => L);
		signal i_Clk_Mod : std_logic_vector(NO_OF_MOD-1 downto 0) := (others => H);
	begin
		clock_process_Mod :process
		begin
			i_Clk_Mod(i) <= '1';
			wait for DF_CLK_PERIOD_MOD/2;
			i_Clk_Mod(i) <= '0';
			wait for DF_CLK_PERIOD_MOD/2;
		end process;
		
		esat_slave: entity work.esat_slave
		generic map (
			C_OVERSAMPLING => DF_OVERSAMPLING
		)
		port map (  
			i_Clk => i_Clk_Mod(i),
			i_Rx => o_MaTx,
			o_Tx => Tx(i),
			o_Oe => Oe(i),
			i_ModAddr => ModAddr(i)
		);
		
		ModAddr(i) <= conv_std_logic_vector(i,4);
		
		i_MaRX <= Z when Oe(i)=L else Tx(i);
	
	end generate slaves;
	
	i_MaRX <= 'H';



end architecture impl;
