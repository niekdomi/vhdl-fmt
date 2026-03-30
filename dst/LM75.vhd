-------------------------------------------------------------------------------
-- LM75.vhd
-------------------------------------------------------------------------------
--
--	project     : LM75
--	programmer  : S. Nüesch, INDEL AG
--	date        : 25.07.2014
--	version     : 1.00
--	language    : VHDL 
--	system      : ise / Spartan6
--
--	purpose	
--		LM75 interface designed to simply read the temperature without
--		any settings.
--
--	history
--		originally from Heat_Safety project (Leuthold), then exported in own
--		file LM75.vhd for COP-PTC (Bärtschi) and ReadOnlyTempLM75.vhd for
--		GIN-TTL (Ochsenbein). The ReadOnlyTempLM75 version doesn't set the 
--		pointer register before a read (trusts on default state), doesn't use
--		directly bidirectinal inputs, has no reset input but has some
--		additional control inputs and status outputs.
--		
--		This file now is based on the ReadOnlyTempLM75 version with some changes 
--		and is finally included in the indel library.
--
--	note that in an error case the i2c reset (state r1 .. r3) will be executed
--	afterwards. This has to be kept in mind if interface is used for several
--	sensors (with muxing).
--	-> maybe increment error counter not until i2c reset (state r1 .. r3) is finished?
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	1.00	18.02.2013-no	- first steps
--	2.00	25.07.2014-stn	- cleaned up, added non-generic address input and
--							migrated to LM75.vhd
--			07.08.2014-stn	- minimal C_READ_CYCLE reduced and comments added
-- 30.08.2016 -le	- add i2c reset request
--					- I2C: delay ack in combination with stop
--------------------------------------------------------------------------------
--$Rev:: 4024                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-08-30 14:51:12 +0200 (Di., 30 Aug 2016)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library i2c;
use i2c.all;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity LM75 is
generic (
-- Constants
	C_LM75_SLAVE_ADDR	: std_logic_vector(2 downto 0) := "000";	-- LM75 address
	C_READ_CYCLE		: integer range 100 to 5000 := 200;			-- Read Cycle time (continuous polling of single LM75 shouldn't be faster than 200 ms!)
	C_CLOCK				: integer := 25000;
	C_FIXED_ADDR		: integer range 0 to 1 := 1					-- 1: C_LM75_SLAVE_ADDR, 0: i_LM75_slave_addr
);
port (
	i_clk				: in std_logic;
	i_enable			: in std_logic;
	--o_pin_request		: out std_logic;
	i_reset_bus			: in std_logic;
	
	i_LM75_slave_addr	: in std_logic_vector(2 downto 0) := "000";	-- LM75 address
	
	-- i2c bus -----------------------------------------------------------------
	o_SCL				: out std_logic;
	o_SDA				: out std_logic;
	i_SCL				: in std_logic;
	i_SDA				: in std_logic;
	
	-- Data Out ----------------------------------------------------------------
	o_Temp				: out std_logic_vector(15 downto 0);		-- 9 Bit used for temperatur (12 integer , 4 decimal places)!
	
	o_err_counter		: out std_logic_vector(7 downto 0) := (others => L); 
	o_new_counter		: out std_logic_vector(7 downto 0) := (others => L)
		
);
end LM75;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of LM75 is

	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	--                                              LM75 I2C type & address
	--constant DF_LM75_SLAVE_ADDR : std_logic_vector := "1001" & C_LM75_SLAVE_ADDR;
	
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal ms_ce		: std_logic := L;	
	signal start_ce		: std_logic := L;

	signal ms_cnt		: std_logic_vector(pkg_log2(C_CLOCK)-1 downto 0) := (others => L);
	signal start_cnt	: std_logic_vector(pkg_log2(C_READ_CYCLE)-1 downto 0) := (others => L); -- based on 1 ms ce
	
	signal i2c_clk_cnt		: unsigned(7 downto 0) := CONV_UNSIGNED(C_CLOCK/(5*400)-1, 8); -- 25MHz/(5*100kHz)-1 
	   
	signal i2c_read			: std_logic := L;
	signal i2c_write		: std_logic := L;
	signal i2c_start		: std_logic := L;
	signal i2c_stop			: std_logic := L;
	signal i2c_ack_in		: std_logic := L;
	signal i2c_cmd_ack		: std_logic := L;
	signal i2c_din			: std_logic_vector(7 downto 0) := (others => L);
	signal i2c_dout			: std_logic_vector(7 downto 0) := (others => L);
	signal i2c_ack_out		: std_logic := L;
	signal i2c_ack_out_ack	: std_logic := L;
	
	type t_i2c_state is (idle,r1,r2,r3,i1,i2,i3,i4); -- r: error/reset , i: regular sequence
	signal i2c_state : t_i2c_state := i1;
	
	signal saveMSByte : std_logic := L;
	signal saveLSByte : std_logic := L;
	
	signal i2c_err : std_logic := L;
	
	signal i2c_dout_save	    : std_logic_vector(7 downto 0) := (others => L);
	
	signal err_counter : std_logic_vector(7 downto 0) := (others => L);
	signal new_counter : std_logic_vector(7 downto 0) := (others => L); 
	
	signal lm75_slave_addr : std_logic_vector(6 downto 0) := "1001000";

-- architecture ----------------------------------------------------------------				
begin

-- fixed or dynamic addressing of LM75 slaves ------------------------------
--						LM75 I2C type & address									LM75 I2C type & address
lm75_slave_addr <= ("1001" & C_LM75_SLAVE_ADDR) when (C_FIXED_ADDR = 1) else ("1001" & i_lm75_slave_addr);

-- prescalers / clock enables ----------------------------------------------	
	clock_teiler : process(i_clk)
		begin
			if (rising_edge(i_clk)) then
				ms_ce <= L;
				start_ce <= L;
				-- ms clock generator
				if (ms_cnt=(C_CLOCK-1)) then
					ms_cnt <= (others => L);
					ms_ce <= H;
				else
					ms_cnt <= ms_cnt + 1;
				end if;
				-- read cycle clock generator
				if (ms_ce=H) then
					if ((start_cnt=C_READ_CYCLE - 1) and (i_enable = H)) then
						start_cnt <= (others => L);
						start_ce <= H;
					else
						start_cnt <= start_cnt + 1;
					end if;
				end if;
			end if;
		end process clock_teiler;
		
-- i2c master instance -----------------------------------------------------
	i2cmaster : entity i2c.simple_i2c 
	generic map(
		g_TrstBuf => 0
	)
	port map (
		clk => i_clk,
		ena => H,
		clk_cnt => i2c_clk_cnt,
		nReset => H,
		read => i2c_read,
		write => i2c_write,
		start => i2c_start,
		stop => i2c_stop,
		ack_in => i2c_ack_in,
		cmd_ack => i2c_cmd_ack,
		Din => i2c_din,
		Dout => i2c_dout,
		ack_out => i2c_ack_out,
		ack_out_ack => i2c_ack_out_ack,
		o_SCL=> o_SCL,
		o_SDA=> o_SDA,
		i_SCL => i_SCL,
		i_SDA => i_SDA
	); 
	
	o_err_counter <= err_counter;
	o_new_counter <= new_counter;
	
-- i2c command sequenzer ---------------------------------------------------
-- all 200 millisecond (C_READ_CYCLE): (lm75 uses 100 ms for convert and restart conversion 
-- at read cmd.: if we read faster then 100 ms the value never change!!!)
-- write 0x00 to lm75 pointerregister (set pointer to temperature register)
-- read temperature register (pointer register not used anymore)
	i2c_lm75 : process(i_clk)
	begin
		if rising_edge(i_clk) then
			saveMSByte <= L;
			saveLSByte <= L;
			
			-- store the MSB until finished
			if(saveMSByte = H) then
				i2c_dout_save <= i2c_dout;
			end if;
			
			--if (i2c_err= H) then
			--	-- if error occured reset error and try to reset I2C-bus
			--	i2c_err <= L;
			--	i2c_state <= r1;
			--	-- count error_counter one up to indicate it
			--	err_counter <= err_counter + 1;
			--end if;
			
			-- with the end of the LSByte the value can be put together
			if(saveLSByte = H) then
				if (i2c_err= L) then
					-- shift temperatur to get 12 integer and 4 decimal places
					o_Temp(15) <= i2c_dout_save(7);	-- sign bit
					o_Temp(14) <= i2c_dout_save(7); 
					o_Temp(13) <= i2c_dout_save(7);
					o_Temp(12) <= i2c_dout_save(7);
					o_Temp(11) <= i2c_dout_save(7);
					o_Temp(10 downto 4) <= i2c_dout_save(6 downto 0); -- 7 higher bits
					o_Temp(3)  <= i2c_dout(7); -- LSB
					o_Temp(2 downto 0) <= "000"; -- undefined
					
					-- if new value arrived count new_counter one up
					new_counter <= new_counter + 1;
				else
					-- if error occured reset error and try to reset I2C-bus
					i2c_err <= L;
					--i2c_state <= r1;
					-- count error_counter one up to indicate it
					err_counter <= err_counter + 1;
				end if;
			end if;
			
			
			-- main function / sequencer
			case i2c_state is
				when idle => 
					if (start_ce=H) then
						if i_reset_bus=H then
							i2c_state <= r1;
						else
							i2c_state <= i1;
						end if;
					end if;
				when r1 =>    -- error state
					--if (start_ce=H) then
						i2c_state <= r2;
						i2c_start <= H;
						i2c_read <= H;
						i2c_write <= L;
						i2c_ack_in <= L;
						i2c_stop <= L;
					--end if;
				when r2 =>    -- second error state
					if (i2c_cmd_ack = H) then
						i2c_state <= r3;
						i2c_start <= L;
						i2c_read <= H;
						i2c_write <= L;
						i2c_ack_in <= H;
						i2c_stop <= H;
					end if;
				when r3 =>	-- end I2C conversation 
					if (i2c_cmd_ack = H) then
						i2c_state <= i1;
						i2c_start <= L;
						i2c_read <= L;
						i2c_write <= L;
						i2c_ack_in <= L;
						i2c_stop <= L;
					end if;
				when i1 =>	-- send start condition, send slave address + read later
					--if (start_ce=H) then -- wait until start counter gets high
						i2c_state <= i2;
						i2c_start <= H;
						i2c_read <= L;
						i2c_write <= H;
						i2c_ack_in <= L;
						i2c_stop <= L;
						i2c_din <= lm75_slave_addr & H; -- write to slave (R/W = '0')
					--end if;
				when i2 =>  -- wait until I2C commands sent and set I2C state to read
					if (i2c_cmd_ack = H) then 
						i2c_state <= i3;
						i2c_start <= L;
						i2c_read <= H; -- prepare to read MSB (high-byte)
						i2c_write <= L;
						i2c_ack_in <= L;
						i2c_stop <= L;
					end if;
				when i3 =>	-- read MSB
					if (i2c_ack_out_ack = H) then	-- check ack bit (of i1 - after addressing)
						if (i2c_ack_out /= L) then
							i2c_err <= H; -- no acknowledge received from last command, expected ACK 
						end if;
					end if;
					if (i2c_cmd_ack = H) then -- wait until I2C commands sent and set I2C state to read
						saveMSByte <= H;  -- for saving I have to wait one clock more so I use this bit for timing it
						i2c_state <= i4;
						i2c_start <= L;
						i2c_read <= H; -- prepare to read LSB (low-byte)
						i2c_write <= L;
						i2c_ack_in <= H; -- set ack high after receiving second byte
						i2c_stop <= H;
					end if;
				when i4 =>	-- read LSB, wait until end of I2C conversation
					if (i2c_cmd_ack = H) then
						saveLSByte <= H;  -- for saving I have to wait one clock more so I use this bit for timing it
						i2c_state <= idle;
						i2c_start <= L;
						i2c_read <= L;
						i2c_write <= L;
						i2c_ack_in <= L;
						i2c_stop <= L;
					end if;
			end case;
		end if;
	end process i2c_lm75;			
		
	end architecture STRUCTURE;