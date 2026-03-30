--------------------------------------------------------------------------------
--
--  LM75
--
--------------------------------------------------------------------------------
--
--  project     : LM75
--  programmer  : S.Bärtschi, INDEL AG
--  date        : 11.07.2011
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- C64-PTC, LM75 
--
--------------------------------------------------------------------------------
--
--	Fehlt noch:
--  
--------------------------------------------------------------------------------
--	Beschreibung:
--  Liest den LM75 aus. Basierend auf dem Code des Heat_Safety
--    
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	02.11.2011-sbä: created
--------------------------------------------------------------------------------
--$Rev:: 3414                                                                  $
--$Author:: Nueesch                                                            $
--$Date:: 2014-07-25 11:32:15 +0200 (Fr., 25 Jul 2014)                         $
--------------------------------------------------------------------------------
                         
--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     


library i2c;
use i2c.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;


entity LM75 is
    generic (
	    C_LM75_SLAVE_ADDR   : std_logic_vector(6 downto 0) := "1001000";
	    C_CLOCK             : integer := 25000;
	    C_REFRESHER         : integer := 200
    );
	port (         
		i_clk           : in  std_logic;
		i_reset         : in  std_logic;
		b_tmpSCL        : inout std_logic;
	    b_tmpSDA        : inout  std_logic;
	    o_temp          : out std_logic_vector(15 downto 0)
    );
end LM75;                                         
  
  
architecture impl of LM75 is     
	type t_i2c_state is (r1,r2,i1,i2,i3,i4,i5,i6);
	signal i2c_state        : t_i2c_state := i1;
	signal i2c_clk_cnt      : unsigned(7 downto 0) := conv_unsigned(C_CLOCK / (400)-1, 8);  --"10000011"; 
	signal i2c_din          : std_logic_vector(7 downto 0);
	signal i2c_dout         : std_logic_vector(7 downto 0);
	signal i2c_read         : std_logic := L;
	signal i2c_write        : std_logic := L;
	signal i2c_start        : std_logic := L;
	signal i2c_stop         : std_logic := L;
	signal i2c_ack_in       : std_logic := L;
	signal i2c_cmd_ack      : std_logic;
	signal i2c_ack_out      : std_logic;
	signal i2c_err          : std_logic := L;
	signal i2c_err_str      : std_logic := L;
	signal i2c_store_MSB    : std_logic := L;
	signal i2c_store_LSB    : std_logic := L;
	signal i2c_dout_save    : std_logic_vector(7 downto 0);
	signal i2c_go           : std_logic := H;
	signal i2c_ack_out_ack  : std_logic;
	signal i2c_errcnt       : unsigned(1 downto 0) := (others => L);
	signal i2c_lm75_error   : std_logic := H;
	
	signal tempLM           : std_logic_vector(15 downto 0);
	
	signal reset            : std_logic := L;
	signal prescale_cnt     : unsigned(15 downto 0) := (others => L);
	signal ms_en            : std_logic := L;
	signal ms_cnt           : unsigned(7 downto 0) := x"00";

  
--------------------------------------------------------------------------------	
begin

    o_temp <= tempLM;

    -- TBase1ms : Lets create a repeating clockpulse every 1ms
    TBase1ms : process(i_Clk)
	begin
        if rising_edge(i_clk) then
            if(prescale_cnt = C_CLOCK ) then
                ms_en <= H;
                prescale_cnt <= (others => L);
            else
                ms_en <= L;
                prescale_cnt <= prescale_cnt + 1;
            end if;
        end if;
    end process TBase1ms;
                               
                               
	-- i2c master instance -----------------------------------------------------
	i2cmaster : entity i2c.simple_i2c
	port map (
		clk => i_Clk,
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
		SCL => b_tmpSCL,
		SDA => b_tmpSDA
	);
	
	
	-- i2c command sequenzer ---------------------------------------------------
	-- all 200 millisecond: (lm75 use 100 ms for convert and restart conversion 
	-- at read cmd.: if we read faster then 100 ms the value never change!!!)
	-- write 0x00 to lm75 pointerregister (set pointer to temperature register)
	-- read temperature register
	--
	-- The tempLM value is updated only if no error occured.
	-- If it fails 3 times in a row to read the LM75, then the errorflag will be set.
	-- The flag indicates that the value is not valid or old.
	
	
	i2c_lm75 : process(i_Clk)
	begin
		if rising_edge(i_Clk) then
			i2c_store_MSB <= L;
			i2c_store_LSB <= L;
			i2c_go <= L;
			if (reset=H) then
				ms_cnt <= (others => L);
				tempLM <= (others => L);
				i2c_lm75_error <= H;
				i2c_errcnt <= (others => L);
				i2c_err_str <= i2c_err;
				i2c_state <= r1;
				i2c_start <= L;
				i2c_read <= L;
				i2c_write <= L;
				i2c_ack_in <= L;
				i2c_stop <= L;
			else
			    -- Store the MSB until finished
				if (i2c_store_MSB=H) then
					i2c_dout_save <= i2c_dout;
				end if;
				
				-- With the end of the LSByte the value can be put togheter
				if (i2c_store_LSB=H) then
					
					if (i2c_err=L) then
						tempLM(15) <= i2c_dout_save(7);
						tempLM(14) <= i2c_dout_save(7);
						tempLM(13) <= i2c_dout_save(7);
						tempLM(12) <= i2c_dout_save(7);
						tempLM(11) <= i2c_dout_save(7);
						tempLM(10) <= i2c_dout_save(6);
						tempLM(9) <= i2c_dout_save(5);
						tempLM(8) <= i2c_dout_save(4);
						tempLM(7) <= i2c_dout_save(3);
						tempLM(6) <= i2c_dout_save(2);
						tempLM(5) <= i2c_dout_save(1);
						tempLM(4) <= i2c_dout_save(0);
						tempLM(3) <= i2c_dout(7);
						tempLM(2 downto 0) <= "000";
						i2c_errcnt <= (others => L);
						i2c_lm75_error <= L;
					else				
						if (i2c_errcnt<3) then
							i2c_errcnt <= i2c_errcnt+1;
						else
							i2c_lm75_error <= H;
						end if;
					end if;
				end if;
				
				-- Count the 1ms timepulses and when the magical limit is reached
				-- the "go" is given.
				if (ms_en=H) then
					if (ms_cnt = conv_unsigned(C_REFRESHER-1,8)) then
						ms_cnt <= (others => L);
						i2c_go <= H;
					else
						ms_cnt <= ms_cnt + 1;
					end if;
				end if;
				
				case i2c_state is
					-- hang here until the "go" arrives
					when r1 =>
						if (i2c_go=H) then
							i2c_state <= r2;
							i2c_start <= L;
							i2c_read <= H;
							i2c_write <= L;
							i2c_ack_in <= L;
							i2c_stop <= L;
						end if;
					when r2 =>
						if (i2c_cmd_ack = H) then
							i2c_state <= i2;
							i2c_start <= L;
							i2c_read <= H;
							i2c_write <= L;
							i2c_ack_in <= L;
							i2c_stop <= H;
						end if;
					when i1 =>	-- send start condition, send slave address + write
						if (i2c_go=H) then
							i2c_state <= i2;
							i2c_start <= H;
							i2c_read <= L;
							i2c_write <= H;
							i2c_ack_in <= L;
							i2c_stop <= L;
							i2c_din <= ( C_LM75_SLAVE_ADDR ) & L; -- write to slave (R/W = '0')
						end if;
						i2c_err <= H;
					when i2 =>	-- set POINTER REGISTER 0  and stop
						if (i2c_cmd_ack = H) then
							i2c_state <= i3;
							i2c_start <= L;
							i2c_read <= L;
							i2c_write <= H;
							i2c_ack_in <= L;
							i2c_stop <= H;
							i2c_din <= x"00";
							i2c_err <= L;
						end if;
					when i3 =>	-- send (repeated) start condition, send slave address + read
						-- check aknowledge bit of i1 
						if (i2c_ack_out_ack = H) then
							if (i2c_ack_out = H) then
								i2c_err <= H; -- no acknowledge received from last command, expected ACK
							--else
							--	i2c_err <= L; --clear
							end if;
						end if;
						if (i2c_cmd_ack = H) then
							i2c_state <= i4;
							i2c_start <= H;
							i2c_read <= L;
							i2c_write <= H;
							i2c_ack_in <= L;
							i2c_stop <= L;
							i2c_din <= ( C_LM75_SLAVE_ADDR ) & H; -- write to slave (R/W = '1')
						end if;
					when i4 =>	--- read MSB (hi-byte), send acknowledge
						-- check aknowledge bit of i2
						if (i2c_ack_out_ack = H) then
							if (i2c_ack_out = H) then
								i2c_err <= H; -- no acknowledge received from last command, expected ACK
							end if;
						end if;
						if (i2c_cmd_ack = H) then
							i2c_state <= i5;
							i2c_start <= L;
							i2c_read <= H;
							i2c_write <= L;
							i2c_ack_in <= L;
							i2c_stop <= L;
						end if;
					when i5 =>	-- read LSB (lo-byte), send acknowledge, sent stop
						-- check aknowledge bit of i3
						if (i2c_ack_out_ack = H) then
							if (i2c_ack_out = H) then
								i2c_err <= H; -- no acknowledge received from last command, expected ACK
							end if;
						end if;
						if (i2c_cmd_ack = H) then
							i2c_store_MSB <= H;
							i2c_state <= i6;
							i2c_start <= L;
							i2c_read <= H;
							i2c_write <= L;
							i2c_ack_in <= H;
							i2c_stop <= H;
						end if;
					when i6 =>	-- wait until done
						if (i2c_cmd_ack = H) then
							i2c_err_str <= i2c_err;
							i2c_store_LSB <= H;
							i2c_state <= i1;
							i2c_start <= L;
							i2c_read <= L;
							i2c_write <= L;
							i2c_ack_in <= L;
							i2c_stop <= L;
						end if;
				end case;
			end if;
		end if;
	end process i2c_lm75;

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------

