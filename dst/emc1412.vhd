--------------------------------------------------------------------------------
--! @file emc1412.vhd
--------------------------------------------------------------------------------
--
--	project		: EMC1412 Temperature Sensor
--	programmer	: V. Zuellig, INDEL AG
--	date		: 01.09.2020
--	language	: VHDL
--	system		: all
--
--  purpose		:
--			
--	Read Temperature from EMC1412
--
--	Temperature stored in register 0x00 and 0x29, refresh 200ms
--
--	This FSM reads only the temperature from the internal diode.
--	The default configuration (extended temperature range) is used for now.
--
--
-- TODO:
--		- external diode
--		- configuration
--
--
--------------------------------------------------------------------------------
--! revision information
--------------------------------------------------------------------------------
--!	15.09.2020	vz: 	create project
--
--
--
--------------------------------------------------------------------------------
--$Rev:: 5368                                                                  $
--$Author:: Zuellig                                                            $
--$Date:: 2019-10-08 10:43:09 +0200 (Di., 08 Okt 2019)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--! includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.Numeric_std.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library EMC1412;
use EMC1412.all;

--------------------------------------------------------------------------------
--! Entity section
--------------------------------------------------------------------------------
entity emc1412 is
	generic(
		C_REFRESH_TIME	: integer := 200;						--! refresh time in ms
		C_BUS_CLK_FREQ	: integer := 125000000;					--! input clock in Hz
		C_I2C_CLK_FREQ	: integer := 400000						--! i2c clock in Hz
	);
	port (
		i_sys_clk		: in	std_logic;						--! main clock 125MHz
		i_periph_rst	: in 	std_logic := L;					--! reset

		i_enable		: in 	std_logic_vector(7 downto 0);	--! start
		o_device_status	: out	std_logic_vector(7 downto 0);	--! ack error
		-- adc
		o_brd_temp		: out 	std_logic_vector(15 downto 0);	--! board temperature

		-- to hardware
		i_i2c_scl		: in	std_logic;						--! i2c clock input
		o_i2c_scl_en	: out	std_logic;						--! tri-state out enable
		i_i2c_sda		: in	std_logic;						--! i2c data input
		o_i2c_sda_en	: out	std_logic						--! tri-state out enable		
	);
end emc1412;

architecture Behavioral of emc1412 is

	--! @details i2c addresses
	constant C_I2C_ADDR		: std_logic_vector(6 downto 0) := "1001100";	--! EMC1412
	constant C_I2C_WnR		: std_logic := L;
	constant C_CFG_REG		: std_logic_vector(7 downto 0) := X"03";
	
	signal config_reg		: std_logic_vector(7 downto 0) := X"04"; 
	 alias MASK_ALL			: std_logic is config_reg(7);
	 alias RUN_STOP			: std_logic is config_reg(5);
	 alias ALERT_COMP		: std_logic is config_reg(5);
	 alias RECD				: std_logic is config_reg(4);
	 alias TEMP_RANGE		: std_logic is config_reg(2);
	 alias DAVG_DIS			: std_logic is config_reg(1);
	 
	
	type t_i2c_state is (	sIdle,				--! wait for action
							sCFG,				--! config device
							sReadTemp,			--! read temperature high byte
							sReadTempF,			--! read temperature low byte aka "fractional"
							store				--! store adc data to output register
						);
	signal i2c_state 		: t_i2c_state := sIdle;

	
	--! counter ???
	type t_byte_state is (	sPTR,				--! set pointer to register (1. byte)
							sRd,				--! write or restart for read (2. byte)
							sDa					--! read (3. byte)
						);
	signal byte_state 		: t_byte_state := sPTR;

	
	--! i2c ctrl signals
	signal i2c_nrst			: std_logic;
	signal i2c_enable		: std_logic;
	signal i2c_addr			: std_logic_vector(6 downto 0);
	signal i2c_rw			: std_logic;
	signal i2c_busy			: std_logic;
	signal i2c_busy_old		: std_logic;
	signal i2c_ack_error	: std_logic;
	signal i2c_data_ld		: std_logic;
	signal i2c_data_ld_old	: std_logic;
	
	signal i2c_data_wr		: std_logic_vector(7 downto 0) := (others => L);
	signal i2c_data_rd		: std_logic_vector(7 downto 0) := (others => L);
	
	signal cycle_cnt		: integer range 0 to 150000:= 0;
	signal data_ptr			: integer range 0 to 1 := 0;
	
	signal adc_reg			: tSLV_Nx16(3 downto 0);
	signal device_status	: std_logic_vector(7 downto 0) := (others => L);

begin
	--! reset assignement
	i2c_nrst <= not i_periph_rst;
	--! i2c device status for cop-bus
	o_device_status <= device_status;
	
	--! i2c_master.vhd
	inst_i2c_master: entity work.i2c_master
	generic map (
		input_clk	=> C_BUS_CLK_FREQ	,
		bus_clk  	=> C_I2C_CLK_FREQ	
	)
	port map (
		clk			=> i_sys_clk		,
		reset_n		=> i2c_nrst			,
		ena			=> i2c_enable		,
		data_ld		=> i2c_data_ld		,
		addr		=> i2c_addr			,
		rw			=> i2c_rw			,
		data_wr		=> i2c_data_wr		,
		busy		=> i2c_busy			,
		data_rd		=> i2c_data_rd		,
		ack_error	=> i2c_ack_error	,
		sda_en		=> o_i2c_sda_en		,
		sda			=> i_i2c_sda		,
		scl_en      => o_i2c_scl_en		,
		scl			=> i_i2c_scl
	);
	
	--! i2c_mux -----------------------------------------------------------------
	i2c_mux : process(i_sys_clk)
	begin
		if rising_edge(i_sys_clk) then
			--! clear all flipflops
			if (i_periph_rst = H) then
				i2c_state <= sIdle;
				cycle_cnt <= 0;
				data_ptr <= 0;
				adc_reg <= (others => (others => L));
				device_status <= (others => L);
			else
				-- latch handshake signals
				i2c_data_ld_old <= i2c_data_ld;
				i2c_busy_old <= i2c_busy;
				device_status(0) <= i2c_ack_error;
				cycle_cnt <= cycle_cnt + 1;
				
				case i2c_state is
				--! sIdle state
				when sIdle =>
					--! refresh time is over
					if(i_enable(0) = H)then -- timer = 0
--						C64_I2C_ACPT <= L;
						--! next state
						i2c_state <= sCFG;
					end if;
					--! reset timer -> no overflow
					cycle_cnt <= 0;
				--! write configuration to device	
				when sCFG =>
					case byte_state is
					when sPTR =>
						i2c_enable <= H;
						i2c_addr <= C_I2C_ADDR;
						i2c_rw <= C_I2C_WnR;
						--! Pointer to config register
						i2c_data_wr <= C_CFG_REG;
						if(i2c_data_ld = L and i2c_data_ld_old = H)then
							byte_state <= sRd;
						end if;
					when sRd =>
						i2c_enable <= H;
						i2c_data_wr <= config_reg;
						if(i2c_busy = L)then
							i2c_enable <= L;
							byte_state <= sDa;
						end if;
					when sDa =>
						if(i2c_busy = L and i2c_busy_old = H)then
							byte_state <= sPTR;
							--! set pointer to register 0x00 for temperature high byte
							i2c_data_wr <= X"00";
							i2c_state <= sReadTemp;
							cycle_cnt <= 0;
							data_ptr <= 0;
						end if;
					end case;
				--! read temperature				
				when sReadTemp =>
					case byte_state is
					--! let's go 
					when sPTR =>
						i2c_enable <= H;
						i2c_addr <= C_I2C_ADDR;
						i2c_rw <= C_I2C_WnR;
						if(i2c_data_ld = L and i2c_data_ld_old = H)then
							byte_state <= sRd;
						end if;
					when sRd =>
						--! stop sequence
						i2c_enable <= L;
						if(i2c_busy = L and i2c_busy_old = H)then
							--! start sequence
							i2c_enable <= H;
							i2c_addr <= C_I2C_ADDR;
							i2c_rw <= not C_I2C_WnR;	-- read
							byte_state <= sDa;
						end if;
					when sDa =>
						--! we only wants to read one byte
						if(i2c_data_ld = L and i2c_data_ld_old = H)then
							i2c_enable <= L;
						end if;
						--! store date and go on
						if(i2c_busy = L and i2c_busy_old = H)then
							adc_reg(data_ptr)(7 downto 0) <= i2c_data_rd;
							byte_state <= sPTR;
							cycle_cnt <= 0;
							i2c_state <= sReadTempF;
							--! we are done 
							if(data_ptr = 1)then
								data_ptr <= 0;
								cycle_cnt <= 0;
								i2c_state <= store;
							end if;
							
						end if;					
					end case;
				when sReadTempF =>
					if(cycle_cnt = 62500-1)then	-- 
						i2c_data_wr <= X"29";	-- low byte = fractional
						data_ptr <= 1;
						i2c_state <= sReadTemp;
					end if;
				when store => 
					o_brd_temp <= "00000" & adc_reg(0)(7 downto 0) & adc_reg(1)(7 downto 5);
					--! wait some times
					if(cycle_cnt = 62500-1)then
						cycle_cnt <= 0;
						data_ptr <= 0;
						i2c_data_wr <= X"00";	-- high byte
						i2c_state <= sReadTemp;
					end if;
				end case;
			end if;
		end if;
	end process i2c_mux;
		
end Behavioral;