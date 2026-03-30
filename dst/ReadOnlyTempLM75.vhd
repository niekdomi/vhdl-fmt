-------------------------------------------------------------------------------
-- ReadOnlyTempLM75.vhd
-------------------------------------------------------------------------------
--
--	project     : LM75
--	programmer  : N.Ochsenbein, INDEL AG
--	date        : 18.02.2013
--	version     : 1.00
--	language    : VHDL 
--	system      : ise / Spartan6
--
--	purpose	
--		LM75 controller designed for GIN-TTL to simply read temperatur without
--		any settings.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	1.00	18.02.2013-no - first steps
--------------------------------------------------------------------------------
--$Rev:: 3414                                                                  $
--$Author:: Nueesch                                                            $
--$Date:: 2014-07-25 11:32:15 +0200 (Fr., 25 Jul 2014)                         $
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
entity ReadOnlyTempLM75 is
generic (
-- Constants
	C_READ_CYCLE : integer range 200 to 5000 := 200;   -- Read Cycle time
	C_LM75_SLAVE_ADDR : std_logic_vector(2 downto 0) := "000" --LM75 address
);
port (
	i_clk : in std_logic;
	i_enable : in std_logic;
	pin_request : out std_logic;
	
	-- i2c bus -----------------------------------------------------------------
	o_SCL : out std_logic;
	o_SDA : out std_logic;
	i_SCL : in std_logic;
	i_SDA : in std_logic;
	
	-- Data Out ----------------------------------------------------------------
	o_Temp : out std_logic_vector(15 downto 0);				-- 9 Bit used for temperatur (12 integer , 4 decimal places)!
	
	o_err_counter : out std_logic_vector(7 downto 0) := (others => L); 
	o_new_counter : out std_logic_vector(7 downto 0) := (others => L)
		
);
end ReadOnlyTempLM75;

--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture STRUCTURE of ReadOnlyTempLM75 is

	-- calculates Log2 of the value
	function log2(value : natural) return integer is
	begin
		if value=0 then
			return 1;
		end if;
		for i in 0 to 31 loop
			if ((2**i)>=value) then
				return i;
			end if;
		end loop;
		return -1;
	end log2;
	                                                                                                           
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	--                                              LM75 I2C type & address
	constant DF_LM75_SLAVE_ADDR : std_logic_vector := "1001" & C_LM75_SLAVE_ADDR;   
	
	----------------------------------------------------------------------------
	-- signal declarations
	----------------------------------------------------------------------------
	signal us_ce : std_logic := L;
	signal ms_ce : std_logic := L;	
	signal start_ce : std_logic := L;
	signal I2C_ce : std_logic := L;

	signal us_cnt : std_logic_vector(4 downto 0) := (others => L);	
	signal ms_cnt : std_logic_vector(9 downto 0) := (others => L);
	signal start_cnt : std_logic_vector(log2(C_READ_CYCLE)-1 downto 0) := (others => L); 
	signal I2C_cnt : std_logic_vector(9 downto 0) := (others => L);
	
	signal i2c_clk_cnt : unsigned(7 downto 0) := CONV_UNSIGNED(25000/(5*400)-1, 8); -- 25MHz/(5*100kHz)-1 
	  
	signal nReset			 : std_logic := L;  
	signal i2c_read          : std_logic := L;
	signal i2c_write         : std_logic := L;
	signal i2c_start         : std_logic := L;
	signal i2c_stop          : std_logic := L;
	signal i2c_ack_in        : std_logic := L;
	signal i2c_cmd_ack       : std_logic := L;
	signal i2c_din           : std_logic_vector(7 downto 0) := (others => L);
	signal i2c_dout          : std_logic_vector(7 downto 0) := (others => L);
	signal i2c_ack_out       : std_logic := L;
	signal i2c_ack_out_ack   : std_logic := L;
	signal b_tmpSCL          : std_logic := L;
	signal b_tmpSDA          : std_logic := L; 
	
	type t_i2c_state is (err,r2,r3,i1,i2,i3,i4);
	signal i2c_state : t_i2c_state := i1;
	
	signal saveMSByte : std_logic := L;
	signal saveLSByte : std_logic := L;
	
	signal i2c_err : std_logic := L;
	
	signal Temp1	    : std_logic_vector(7 downto 0) := (others => L);
	
	signal err_counter : std_logic_vector(7 downto 0) := (others => L);
	signal new_counter : std_logic_vector(7 downto 0) := (others => L); 
				
begin -- architecture ----------------------------------------------------------
	
	clock_teiler : process(i_clk)
		begin
			if (rising_edge(i_clk)) then
				us_ce <= L;
				I2C_ce <= L;
				ms_ce <= L;
				start_ce <= L;
				-- us clock generator
				if (us_cnt = 24) then
					us_cnt <= (others => L);
					us_ce <= H;
				else
					us_cnt <= us_cnt + 1;	
				end if;
                -- I2C clock generator
				if (us_ce=H) then
					if (I2C_cnt=62) then
					I2C_cnt <= (others => L);
						I2C_ce <= H;
					else
						I2C_cnt <= I2C_cnt + 1;
					end if;
				end if;
				-- ms clock generator
				if (us_ce=H) then
					if (ms_cnt=999) then
					ms_cnt <= (others => L);
						ms_ce <= H;
					else
						ms_cnt <= ms_cnt + 1;
					end if;
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
	-- all 200 millisecond: (lm75 use 100 ms for convert and restart conversion 
	-- at read cmd.: if we read faster then 100 ms the value never change!!!)
	-- write 0x00 to lm75 pointerregister (set pointer to temperature register)
	-- read temperature register
	i2c_lm75 : process(i_clk)
	begin
		if rising_edge(i_clk) then
			saveMSByte <= L;
			saveLSByte <= L;
			
			if(saveMSByte = H) then
				Temp1 <= i2c_dout;
			end if;
			if(saveLSByte = H) then
				if (i2c_err= L) then
					o_Temp(15) <= Temp1(7); -- shift tmperatur to get
					o_Temp(14) <= Temp1(7); -- 12 integer and 4 decimal places
					o_Temp(13) <= Temp1(7);
					o_Temp(12) <= Temp1(7);
					o_Temp(11) <= Temp1(7);
					o_Temp(10) <= Temp1(6);
					o_Temp(9)  <= Temp1(5);
					o_Temp(8)  <= Temp1(4);
					o_Temp(7)  <= Temp1(3);
					o_Temp(6)  <= Temp1(2);
					o_Temp(5)  <= Temp1(1);
					o_Temp(4)  <= Temp1(0);
					o_Temp(3)  <= i2c_dout(7);
					o_Temp(2 downto 0) <= "000";  
					
					-- if new vaule arrived count new_counter one up
					new_counter <= new_counter + 1;
				else
					-- if error occured reset error and try to reset I2C-bus
				   i2c_err <= L;
				   i2c_state <= err;
				   -- count error_counter one up to indicate it
				   err_counter <= err_counter + 1;
				end if;
			end if;
			
			--request I2C pins if reader enable is high
			if (i_enable = H)then
				pin_request <= H;
			end if;
			
			case i2c_state is
				when err =>    -- Error state
						i2c_state <= r2;
						i2c_start <= H;
						i2c_read <= H;
						i2c_write <= L;
						i2c_ack_in <= L;
						i2c_stop <= L;		
				when r2 =>    -- second Error state
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
				when i1 =>	-- send start condition, send slave address + Read
					if (i_enable = L) then
						pin_request <= L;
					end if;
					if (start_ce=H) then -- wait until start counter gets high
						i2c_state <= i2;
						i2c_start <= H;
						i2c_read <= L;
						i2c_write <= H;
						i2c_ack_in <= L;
						i2c_stop <= L;
						i2c_din <= DF_LM75_SLAVE_ADDR & H; -- Read from slave (R/W = '0')
					end if;
				when i2 =>  -- wait until I2C commands sent and set I2C state to read
					if (i2c_cmd_ack = H) then 
						i2c_state <= i3;
						i2c_start <= L;
						i2c_read <= H;
						i2c_write <= L;
						i2c_ack_in <= L;
						i2c_stop <= L;
					end if;
				when i3 =>	-- now check Akknwoledge bit of LM75 which he sent after addressing him
					if (i2c_ack_out_ack = H) then 
						if (i2c_ack_out /= L)then
							i2c_err <= H; -- no acknowledge received from last command, expected ACK 
						end if;                                                                    
					end if;
					if (i2c_cmd_ack = H) then -- wait until I2C commands sent and set I2C state to read
						saveMSByte <= H;  -- for saving I have to wait one clock more so I use this bit for timing it
						i2c_state <= i4;
						i2c_start <= L;
						i2c_read <= H;
						i2c_write <= L;
						i2c_ack_in <= H; -- set ack high after receiving second byte
						i2c_stop <= H;
					end if;
				when i4 =>	-- end I2C conversation
					if (i2c_cmd_ack = H) then
						saveLSByte <= H;  -- for saving I have to wait one clock more so I use this bit for timing it
						i2c_state <= i1;
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