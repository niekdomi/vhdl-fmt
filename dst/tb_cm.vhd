--------------------------------------------------------------------------------
--$Rev:: 5416                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-11-22 13:53:46 +0100 (Fr., 22 Nov 2019)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.numeric_std.ALL;
use IEEE.math_real.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity tb is
end tb;

architecture arc_tb of tb is

constant H          : std_logic := '1';
constant L          : std_logic := '0';
constant Z          : std_logic := 'Z';

signal clk : std_logic := L;
signal rst : std_logic := H;
signal i_start_conv : std_logic := L;

constant C_BIT_RES : integer := 16;
constant C_REG_LNG : integer := 16;
constant C_NUM_SD_DEVICES : integer := 1;
constant DF_NS : integer := 50; -- periodtime for ext_clk

signal i_sData       : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
signal i_sData2       : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
signal i_sData2_x       : std_logic_vector(2-1 downto 0) := (others => L);
signal o_Data        : tSLV_Nx16(C_NUM_SD_DEVICES-1 downto 0) := (others => (others => L));
signal o_DataLA      : std_logic_vector(C_NUM_SD_DEVICES*C_REG_LNG-1 downto 0) := (others => L);
signal o_overrange   : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
type t_datala is array (C_NUM_SD_DEVICES-1 downto 0) of std_logic_vector(C_BIT_RES-1 downto 0);
signal o_DataLA_sim : t_datala;

signal o_Data_2      : std_logic_vector(C_REG_LNG-1 downto 0) := (others => L);        
signal o_DataLA_2    : std_logic_vector(C_REG_LNG-1 downto 0) := (others => L);  

signal o_DataLA_4    : std_logic_vector(C_REG_LNG-1 downto 0) := (others => L);

signal o_DataLA_4_x    : std_logic_vector(2*C_REG_LNG-1 downto 0) := (others => L);        
signal o_overrange_2 : std_logic := L;             


signal filterDataLA_4    : std_logic_vector(C_REG_LNG-1 downto 0) := (others => L); 

signal input : real := 0.0;

signal ext_clk : std_logic := L;
signal sd_clk_cnt : unsigned(2 downto 0) := (others => L); 
signal i_half_dezi : std_logic := L;
signal i_clear : std_logic := L;
signal i_clear2 : std_logic := L;

signal calc : std_logic := H;

signal slowFlg : std_logic := L;
signal sd_trig_clr : std_logic := L;


begin
	
	clocki : process
	begin
		clk <= L;
		wait for 5 ns;
		clk <= H;
		wait for 5 ns;
		rst <= L;
	end process clocki;
	
	sd_clk_gen : process (clk)
	begin
		if rising_edge(clk) then 
			sd_clk_cnt <= sd_clk_cnt + 1;
			i_start_conv <= L;
			--if sd_clk_cnt=(C_NUM_SD_DEVICES-1)/2 then
		--	if sd_clk_cnt=2 then
		--		ext_clk <= not ext_clk;
		--		sd_clk_cnt <= (others => L);
		--		if (ext_clk=L) then
		--			i_start_conv <= H;
		--		end if;
		--	end if;
			if (sd_clk_cnt=0) then
				ext_clk <= H;
			elsif (sd_clk_cnt=1) then
				i_start_conv <= H;
			elsif (sd_clk_cnt=2) then
				ext_clk <= L;
			elsif (sd_clk_cnt=3) then
				ext_clk <= L;
			elsif (sd_clk_cnt=4) then
				sd_clk_cnt <= (others => L);
			end if;
			i_clear2 <= i_clear;
			if i_clear=H and i_clear2=L then
				sd_trig_clr <=H;
			else
				sd_trig_clr <= L;
			end if;
		end if;
	end process sd_clk_gen;
	
	sd_adc : process
	variable int : real := 0.0;
	variable dif : real := 1.0;
	variable cmp : real := 0.0;
	
	variable int2_0 : real := 0.0;
	variable int2_1 : real := 0.0;
	variable dif2 : real := 1.0;
	variable cmp2 : real := 0.0;
	
	variable rad : real := 0.0;
	variable down : std_logic := L;
	variable nanosec : integer := 0;
	constant DF_PTIME : integer := 31250;
	begin
		for i in 0 to 20000 loop
			wait until ext_clk'event and ext_clk = H;
			wait for 40 ns; -- Data access time after MCLK rising edge
			nanosec := nanosec + DF_NS;
			--sigma delta
			dif := input - cmp;
			int := (int + dif)*1.0;
			if int>0.0 then
				cmp := 1.0;
				i_sData <= (others => H);
			else
				cmp := -1.0;
				i_sData <= (others => L);
			end if;
			
			dif2 := input - cmp2;
			int2_0 := (int2_0 + dif2)*1.0;
			int2_1 := (int2_1 + (int2_0-cmp2))*1.0;
			if int2_1>0.0 then
				cmp2 := 1.0;
				i_sData2 <= (others => H);
			else
				cmp2 := -1.0;
				i_sData2 <= (others => L);
			end if;
			
			if (nanosec rem DF_PTIME)<DF_NS then
				i_clear <= H;
			else
				i_clear <= L;
			end if;
			if nanosec < DF_PTIME then
				input <= -0.8;
			elsif nanosec < 2*DF_PTIME then
				input <= 0.0;
			elsif nanosec < 3*DF_PTIME then
				input <= 0.8;
			elsif nanosec < 3*DF_PTIME+DF_NS*2 then
				input <= -0.8;
			elsif nanosec < 3*DF_PTIME+DF_NS*4 then
				input <= 0.0;
				
				
				
			elsif nanosec < 20*DF_PTIME then
				-- sinus
				rad := rad + 0.0005;
				input <= SIN(rad*2.0) * 0.9;
			elsif nanosec < 20*DF_PTIME+DF_NS*4 then
				input <= 0.9;
				down := H;
			else
				-- dreieck
				if input>0.9 then
					down := H;
				elsif input<-0.9 then
					down := L;
				end if;
				if down=L then
					input <= input + 0.9/real(DF_PTIME/DF_NS)*4.0;
				else
					input <= input - 0.9/real(DF_PTIME/DF_NS)*4.0;
				end if;
			end if;
			
			if nanosec < 11*DF_PTIME then
				slowFlg <= L;
			elsif nanosec < 25*DF_PTIME then
				slowFlg <= H;
			else
				slowFlg <= L;
			end if;
			
		end loop;
		wait;
	end process sd_adc;
	
	new_current_measurement : entity work.current_meas
	generic map (
		C_NUM_SD_DEVICES	=> 1,
		C_NUM_SD_INST		=> 1
	)
	port map (
		i_clk				=> clk,
		i_slowFlg(0)		=> slowFlg,

		i_sd_trig_clr		=> sd_trig_clr,
		-- sigma_delta ------------------------------------------------------------
		i_sd_dataready		=> i_start_conv,
		i_sd_sData			=> i_sData,
		-- current data out --------------------------------------------------------
		o_sd_analog_data	=> o_Data
	);
	

	
end arc_tb;