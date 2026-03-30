--------------------------------------------------------------------------------
--
--  endat_ssi_hip_biss_tb.vhd
--
--------------------------------------------------------------------------------
--
--  project     : endat_ssi_hip_biss
--  programmer  : C. Leuthold, INDEL AG
--  date        : 28.11.2017
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

--library indel_pkg;
--use indel_pkg.indel_pkg.all;

entity endat_ssi_hip_biss_tb is
end;

architecture impl of endat_ssi_hip_biss_tb is
	
	constant DF_CLK_FREQ : integer := 100000000;
	constant DF_CLK_PERIOD : time := 1000.0 ms / DF_CLK_FREQ;
	
	constant C_SR_LNG : integer := 64;
	constant C_CLK_CNT_LNG : integer := 9;
	constant C_DATA_CNT_LNG : integer := 6;
	
	constant DF_CLK_DIF : integer := 8;
	
	signal i_Clk		: std_logic := '0';
	-- config
	signal i_clk_div	: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => '0');
	signal i_data_lng	: std_logic_vector(C_DATA_CNT_LNG-1 downto 0) := (others => '0');
	--endat Pin controll
	signal o_sClk		: std_logic := '0';
	signal o_sClk2		: std_logic := '0';
	signal i_sData		: std_logic := '0';
	signal o_sData		: std_logic := '0';
	signal o_RnW		: std_logic := '0';
	-- interface
	signal o_Data		: std_logic_vector(C_SR_LNG-1 downto 0) := (others => '0');
	signal i_mode		: std_logic_vector(5 downto 0) := (others => '0');
	signal i_Data		: std_logic_vector(23 downto 0) := (others => '0');
	signal o_data_ready: std_logic := '0';
	signal i_SSInEndat : std_logic := '0';
	signal i_Enable	: std_logic := '0';
	signal i_start		: std_logic := '0';
	
	signal ssi_biss_load : std_logic := '1';
	signal enc_data : std_logic_vector(C_SR_LNG-1 downto 0) := (others => '0');
	signal datalng : integer := 48;
	signal enc_timeout : time := 5 us;
	

	constant DF_BISS_DOFF : integer :=4;
	signal biss_sr : std_logic_vector(C_SR_LNG+DF_BISS_DOFF downto 0) := (others => '0');
	signal biss_d : std_logic := '1';
	
	signal crc_order : integer range 1 to 8 := 6;
	signal crc_poly : std_logic_vector(7 downto 0) := "00000011";
	signal crc_build : std_logic_vector(7 downto 0) := "00000000";
	
	signal WE  : std_logic_vector(1 downto 0) := (others => '0');
	signal bisscrc : std_logic_vector(5 downto 0) := (others => '0');


	
	
begin
	
	ssi_biss_monflop_proc: process
	begin
		ssi_biss_load <= '1' after enc_timeout;
		wait until rising_edge(o_sClk);
		ssi_biss_load <= '0';
		wait for 1 ns; 		
	end process;

	-- biss encoder -----------------------------------------------------------
	-- input: enc_data, datalng
	-- output biss_d
	biss_sr_proc: process(o_sClk, enc_data)
	
	begin
		if ssi_biss_load='1' then
			biss_sr <= (others => '0');
			biss_sr(datalng+DF_BISS_DOFF+2+6 downto 0) <= '1' & '0' & '1' & '0'  & enc_data(datalng-1 downto 0) & not(WE) & bisscrc & '0';
		elsif rising_edge(o_sClk) then
			biss_sr(datalng+DF_BISS_DOFF+2+6 downto 0) <= biss_sr(datalng+DF_BISS_DOFF+2+6-1 downto 0) & biss_sr(datalng+DF_BISS_DOFF+2+6);
		end if;
	end process;
	biss_d <= (biss_sr(datalng+DF_BISS_DOFF+2+6) or ssi_biss_load);

	i_sData <= biss_d;

	stim_proc: process

	variable crc_input : std_logic;
	variable data_we : std_logic_vector(63 downto 0);
	begin
		wait until rising_edge(i_Clk);
		wait for DF_CLK_PERIOD*50;
		-- biss
		i_clk_div <= conv_std_logic_vector(DF_CLK_DIF-1,C_CLK_CNT_LNG);
		i_data_lng <= conv_std_logic_vector(datalng,C_DATA_CNT_LNG);
		i_mode <= (others => '0');
		i_Data <= (others => '0');
		i_Enable <= '1';
		enc_data(datalng-1 downto 0) <= x"fffffffffffc";
		wait for DF_CLK_PERIOD*100;
		loop
			WE <= "00"; 
			enc_data(datalng-1 downto 0) <= enc_data(datalng-1 downto 0)+1;
			crc_build <= "00000000";		
			wait until rising_edge(i_Clk);
			data_we(datalng+1 downto 0) := enc_data(datalng-1 downto 0)&not(WE);
			for j in datalng+1 downto 0 loop
				crc_input := data_we(j) xor crc_build(crc_order-1);
				crc_build(0) <= crc_input;
				for i in 1 to 7 loop
					if (crc_poly(i)='1') then
						crc_build(i) <= crc_build(i-1) xor crc_input;
					else
						crc_build(i) <= crc_build(i-1);
					end if;
				end loop;
				wait until rising_edge(i_Clk);
			end loop;
			bisscrc <= not(crc_build(crc_order-1 downto 0));
			wait until rising_edge(i_Clk);
			i_start <= '1';
			wait until rising_edge(i_Clk);
			i_start <= '0';
			wait until rising_edge(i_Clk);
			
			wait for 40.0 us;
			
--			-- error
--			WE <= "01"; 
--			enc_data(datalng-1 downto 0) <= enc_data(datalng-1 downto 0)+1;
--			crc_build <= "00000000";		
--			wait until rising_edge(i_Clk);
--			data_we(datalng+1 downto 0) := enc_data(datalng-1 downto 0)&not(WE);
--			for j in datalng+1 downto 0 loop
--				crc_input := data_we(j) xor crc_build(5);
--				crc_build(0) <= crc_input;
--				for i in 1 to 7 loop
--					if (crc_poly(i)='1') then
--						crc_build(i) <= crc_build(i-1) xor crc_input;
--					else
--						crc_build(i) <= crc_build(i-1);
--					end if;
--				end loop;
--				wait until rising_edge(i_Clk);
--			end loop;
--			bisscrc <= not(crc_build(5 downto 0));
--			wait until rising_edge(i_Clk);
--			i_start <= '1';
--			wait until rising_edge(i_Clk);
--			i_start <= '0';
--			wait until rising_edge(i_Clk);
--			
--			wait for 40.0 us;
--			
--			-- warning
--			WE <= "10"; 
--			enc_data(datalng-1 downto 0) <= enc_data(datalng-1 downto 0)+1;
--			crc_build <= "00000000";		
--			wait until rising_edge(i_Clk);
--			data_we(datalng+1 downto 0) := enc_data(datalng-1 downto 0)&not(WE);
--			for j in datalng+1 downto 0 loop
--				crc_input := data_we(j) xor crc_build(5);
--				crc_build(0) <= crc_input;
--				for i in 1 to 7 loop
--					if (crc_poly(i)='1') then
--						crc_build(i) <= crc_build(i-1) xor crc_input;
--					else
--						crc_build(i) <= crc_build(i-1);
--					end if;
--				end loop;
--				wait until rising_edge(i_Clk);
--			end loop;
--			bisscrc <= not(crc_build(5 downto 0));
--			wait until rising_edge(i_Clk);
--			i_start <= '1';
--			wait until rising_edge(i_Clk);
--			i_start <= '0';
--			wait until rising_edge(i_Clk);
--			
--			wait for 40.0 us;
--			
--			-- crc
--			WE <= "00"; 
--			enc_data(datalng-1 downto 0) <= enc_data(datalng-1 downto 0)+1;
--			crc_build <= "00000000";		
--			wait until rising_edge(i_Clk);
--			data_we(datalng+1 downto 0) := enc_data(datalng-1 downto 0)&not(WE);
--			for j in datalng+1 downto 0 loop
--				crc_input := data_we(j) xor crc_build(5);
--				crc_build(0) <= crc_input;
--				for i in 1 to 7 loop
--					if (crc_poly(i)='1') then
--						crc_build(i) <= crc_build(i-1) xor crc_input;
--					else
--						crc_build(i) <= crc_build(i-1);
--					end if;
--				end loop;
--				wait until rising_edge(i_Clk);
--			end loop;
--			bisscrc <= not(crc_build(5 downto 0))+1;
--			wait until rising_edge(i_Clk);
--			i_start <= '1';
--			wait until rising_edge(i_Clk);
--			i_start <= '0';
--			wait until rising_edge(i_Clk);
--			
--			wait for 40.0 us;
			
			
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
	
--	inst_BISS	: entity work.biss
--	port map (
--		i_Clk => i_Clk,
--		-- config
--		i_clk_div => i_clk_div,
--		i_data_lng => i_data_lng,
--		i_fast_clk => '1',
--		--Biss Pin controll
--		o_sClk => o_sClk, 
--		i_sData => i_sData,
--		o_sData => o_sData,
--		o_RnW => o_RnW,
--		-- interface
--		-- interface
--		o_Data => o_Data,
--		i_mode => i_mode,
--		i_Data => i_Data,
--		o_data_ready => o_data_ready,
--		i_Enable => i_Enable,
--	--	i_Select => i_Select,
--		i_start => i_start
--	);
-------------------------------------------------------------------------------
--  for "BISS-C inferometer qutools GmbH for Agathon" simulation:
--  comment inst_BISS : entity work.biss
--  and uncomment biss_clk_stim : process
-------------------------------------------------------------------------------
	biss_clk_stim : process
	constant DF_BISSCLK_FREQ : integer := 6000000;
	constant DF_BISSCLK_PERIOD : time := 1000.0 ms / DF_BISSCLK_FREQ;
	begin
		o_sClk <= '1';
		wait until rising_edge(i_Clk);
		if i_start='1' then
			for i in 0 to datalng+DF_BISS_DOFF+2+6 loop
				o_sClk <= '0';
				wait for DF_BISSCLK_PERIOD/2;
				o_sClk <= '1';
				wait for DF_BISSCLK_PERIOD/2;
			end loop;
		end if;
		
	end process;
	
end architecture impl;
