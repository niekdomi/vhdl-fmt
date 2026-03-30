--------------------------------------------------------------------------------
-- gin-max4x4.vhd
--------------------------------------------------------------------------------
--
--	project		: CV-SODIMM
--	programmer	: C. Leuthold, INDEL AG
--	date		: 07.10.2008
--	language	: VHDL
--	system		: cv-sodimm
--
--  purpose
--				
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	19.03.2019-vz:	create project
--	22.11.2019-le:	move it to library and use it on cop-ax/ax2
--					!!! gatemode from sac includet but not testet
--	18.02.2021-le:	- use DataReady single pulse for parallel data out
--------------------------------------------------------------------------------
--$Rev:: 5818                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2021-02-18 10:46:54 +0100 (Do., 18 Feb 2021)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.std_logic_arith.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library sigma_delta;
use sigma_delta.sigma_delta_synchron;

library division;
use division.division;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity current_meas is
	generic (
		C_NUM_SD_DEVICES	: integer := 8;
		C_NUM_SD_INST		: integer := 8;
		C_GATEMODE			: integer range 0 to 1 := 0
	);
	port (
		i_clk 				: in	std_logic;
		i_slowFlg			: in	std_logic_vector(C_NUM_SD_DEVICES-1 downto 0);
		i_sd_trig_clr		: in	std_logic;
		i_switchpoint		: in	std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
		-- sigma_delta ------------------------------------------------------------
		i_sd_dataready		: in	std_logic;
		i_sd_sData			: in	std_logic_vector(C_NUM_SD_DEVICES-1 downto 0);	
		-- current data out --------------------------------------------------------
		o_sd_analog_data	: out 	tSLV_Nx16(C_NUM_SD_DEVICES-1 downto 0);
		o_sd_overrange		: out	std_logic_vector(C_NUM_SD_DEVICES-1 downto 0)
	);
end current_meas;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of current_meas is
	constant DF_INTLNG : integer := 27;
	constant DF_REG_LENGTH		: integer := 16;
	type t_ares_lv is array (natural RANGE <>) of std_logic_vector(DF_INTLNG-1 downto 0);
	signal ares_s : t_ares_lv(C_NUM_SD_DEVICES-1 downto 0) := (others => (others => L));
	signal acnt_l : t_ares_lv(C_NUM_SD_DEVICES-1 downto 0) := (others => (others => L));
	type t_acnt is array (0 to C_NUM_SD_DEVICES-1) of std_logic_vector(10 downto 0);
	signal acnt : t_acnt := (others => (others => L));
	signal sd_analog_data_X : tSLV_Nx16(0 to C_NUM_SD_DEVICES-1);
	signal sd_analog_data_X13 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_analog_data_X1 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_analog_data_X3 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_analog_data_X1_0 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_analog_data_X1_1 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_analog_data_X3_0 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	signal sd_analog_data_X3_1 : std_logic_vector(C_NUM_SD_DEVICES*DF_REG_LENGTH-1 downto 0);
	type t_ares_s is array (0 to C_NUM_SD_DEVICES-1) of signed(DF_INTLNG-1 downto 0);
	signal aint : t_ares_s := (others => (others => L));
	signal we : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
	signal we_n1 : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
	signal we1 : std_logic := L;
	signal we3 : std_logic := L;
	type t_GateCnt is array (0 to C_NUM_SD_DEVICES-1) of std_logic_vector(3 downto 0);
	signal GateCnt : t_GateCnt := (others => (others => L));
	signal gate : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
	signal we_v1_0 : std_logic_vector(C_NUM_SD_INST-1 downto 0);
	signal we_v1_1 : std_logic_vector(C_NUM_SD_INST-1 downto 0);
	signal we_v3_0 : std_logic_vector(C_NUM_SD_INST-1 downto 0);
	signal we_v3_1 : std_logic_vector(C_NUM_SD_INST-1 downto 0);
	signal tlg : std_logic := L;
	signal sd_trig_clr_0 : std_logic := L;
	signal sd_trig_clr_1 : std_logic := L;
	signal clr_cnt : std_logic_vector(7 downto 0) := (others => L);
	signal div_done : std_logic_vector(C_NUM_SD_DEVICES-1 downto 0) := (others => L);
begin -- architecture ----------------------------------------------------------
	sd_inst32_0: for i in 0 to C_NUM_SD_INST-1 generate
	begin
		i_sd_inst32 : entity sigma_delta.sigma_delta_synchron
		generic map (
			C_OVERRANGE => 25,
			C_CLK_DIV => 32,
			C_REG_LNG => DF_REG_LENGTH,
			C_NUM_SD_DEVICES => C_NUM_SD_DEVICES/C_NUM_SD_INST
		)
		port map (
			i_Clk => i_clk,
			i_dataready => i_sd_dataready,
			--sigma_delta Pins
			i_sData => i_sd_sData(i*C_NUM_SD_DEVICES/C_NUM_SD_INST+C_NUM_SD_DEVICES/C_NUM_SD_INST-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST),
			-- interface
			o_DataLA => sd_analog_data_X1_0(i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH+C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH),
			o_overrange => o_sd_overrange(i*C_NUM_SD_DEVICES/C_NUM_SD_INST+C_NUM_SD_DEVICES/C_NUM_SD_INST-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST),
			o_DataReady => we_v1_0(i),
			i_clear => sd_trig_clr_0
		);
	end generate sd_inst32_0;

	sd_inst32_1: for i in 0 to C_NUM_SD_INST-1 generate
	begin
		i_sd_inst32 : entity sigma_delta.sigma_delta_synchron
		generic map (
			C_OVERRANGE => 25,
			C_CLK_DIV => 32,
			C_REG_LNG => DF_REG_LENGTH,
			C_NUM_SD_DEVICES => C_NUM_SD_DEVICES/C_NUM_SD_INST
		)
		port map (
			i_Clk => i_clk,
			i_dataready => i_sd_dataready,
			--sigma_delta Pins
			i_sData => i_sd_sData(i*C_NUM_SD_DEVICES/C_NUM_SD_INST+C_NUM_SD_DEVICES/C_NUM_SD_INST-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST),
			-- interface
			o_DataLA => sd_analog_data_X1_1(i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH+C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH),
			o_DataReady => we_v1_1(i),
			i_clear => sd_trig_clr_1
		);
	end generate sd_inst32_1;

	sd_inst8_0: for i in 0 to C_NUM_SD_INST-1 generate
	begin
		i_sd_inst08_c : entity sigma_delta.sigma_delta_synchron
		generic map (
			C_OVERRANGE => 25,
			C_CLK_DIV => 8,
			C_REG_LNG => DF_REG_LENGTH,
			C_NUM_SD_DEVICES => C_NUM_SD_DEVICES/C_NUM_SD_INST
		)
		port map (
			i_Clk => i_clk,
			i_dataready => i_sd_dataready,
			--sigma_delta Pins
			i_sData => i_sd_sData(i*C_NUM_SD_DEVICES/C_NUM_SD_INST+C_NUM_SD_DEVICES/C_NUM_SD_INST-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST),
			-- interface
			o_DataLA => sd_analog_data_X3_0(i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH+C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH),
			o_DataReady => we_v3_0(i),
			i_clear => sd_trig_clr_0
		);
	end generate sd_inst8_0;

	sd_inst8_1: for i in 0 to C_NUM_SD_INST-1 generate
	begin
		i_sd_inst08_c : entity sigma_delta.sigma_delta_synchron
		generic map (
			C_OVERRANGE => 25,
			C_CLK_DIV => 8,
			C_REG_LNG => DF_REG_LENGTH,
			C_NUM_SD_DEVICES => C_NUM_SD_DEVICES/C_NUM_SD_INST
		)
		port map (
			i_Clk => i_clk,
			i_dataready => i_sd_dataready,
			--sigma_delta Pins
			i_sData => i_sd_sData(i*C_NUM_SD_DEVICES/C_NUM_SD_INST+C_NUM_SD_DEVICES/C_NUM_SD_INST-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST),
			-- interface
			o_DataLA => sd_analog_data_X3_1(i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH+C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH-1 downto i*C_NUM_SD_DEVICES/C_NUM_SD_INST*DF_REG_LENGTH),
			o_DataReady => we_v3_1(i),
			i_clear => sd_trig_clr_1
		);
	end generate sd_inst8_1;

	sd_analog_data_X1 <= sd_analog_data_X1_0 when tlg=L else sd_analog_data_X1_1;
	we1 <= we_v1_0(0) when tlg=L else we_v1_1(0);

	sd_analog_data_X3 <= sd_analog_data_X3_0 when tlg=L else sd_analog_data_X3_1;
	we3 <= we_v3_0(0) when tlg=L else we_v3_1(0);

	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if clr_cnt=0 then
				sd_trig_clr_0 <= L;
				sd_trig_clr_1 <= L;
			else
				clr_cnt <= clr_cnt-1;
			end if;
			if i_sd_trig_clr=H then
				tlg <= not tlg;
				sd_trig_clr_0 <= not tlg;
				sd_trig_clr_1 <= tlg;
				clr_cnt <= x"00";
			end if;
		end if;
	end process;

	divis:for i in 0 to C_NUM_SD_DEVICES-1 generate
	begin

		i_division : entity division.division
		generic map (
			SIZE => DF_INTLNG,
			C_SIGNED => 1
		)
		port map (
			clk		=> i_clk,
			Start	=> i_sd_trig_clr,
			num		=> std_logic_vector(aint(i)),
			den		=> acnt_l(i),
			res		=> ares_s(i),
			o_Done	=> div_done(i)
		);
		acnt_l(i)(acnt(i)'high downto 0) <= acnt(i);
		sd_analog_data_X(i) <= sxt(ares_s(i),16);

		process (GateCnt,i_slowFlg)
		begin
			if (C_GATEMODE=1) then
				if GateCnt(i)<9 and GateCnt(i)/=0 and  i_slowFlg(i)=L then
					gate(i) <= H;
				elsif GateCnt(i)<6 and GateCnt(i)/=0 and  i_slowFlg(i)=H then
					gate(i) <= H;
				else 
					gate(i) <= L;
				end if;
			else 
				gate(i) <= L;
			end if;
		end process;

		we(i) <= we3 when i_slowFlg(i)=L else we1;
		
		process(i_slowFlg,sd_analog_data_X1,sd_analog_data_X3) begin
			if i_slowFlg(i)=L then
				sd_analog_data_X13(15+16*i downto 16*i) <= sd_analog_data_X3(15+16*i downto 16*i);
			else
				sd_analog_data_X13(15+16*i downto 16*i) <= sd_analog_data_X1(15+16*i downto 16*i);
			end if;
		end process;
		
		integrator	: process (i_clk)
		begin
			if rising_edge(i_clk) then
				if (i_switchpoint(i)=H and C_GATEMODE=1) then
					if i_slowFlg(i)=L then
						GateCnt(i) <= conv_std_logic_vector(10,GateCnt(i)'length);
					else
						GateCnt(i) <= conv_std_logic_vector(5,GateCnt(i)'length);
					end if;
				end if;
				if i_sd_trig_clr=H then
					acnt(i) <= (others => L);
					aint(i) <= (others => L);
				elsif (we(i)=H) then
					if (GateCnt(i)/=0) then
						GateCnt(i) <= GateCnt(i)-1;
					end if;
					if (gate(i)=H and C_GATEMODE=1) then
						-- do not add
					else
						acnt(i) <= acnt(i) + 1;
						aint(i) <= aint(i) + signed(sxt(sd_analog_data_X13(15+16*i downto 16*i),aint(i)'length));
					end if;
				end if;

				if div_done(i)=H then
					o_sd_analog_data(i) <= sd_analog_data_X(i);
				end if;
			end if;
		end process integrator;
	end generate divis;

--------------------------------------------------------------------------------
end architecture STRUCTURE;
