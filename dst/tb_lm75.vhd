--------------------------------------------------------------------------------
--$Rev:: 3415                                                                  $
--$Author:: Nueesch                                                            $
--$Date:: 2014-07-25 11:41:35 +0200 (Fr., 25 Jul 2014)                         $
--------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity tb is
end tb;

architecture arc_tb of tb is
	
	
	
	signal opb_clk : std_logic := L;

	signal b_tmpSCL : std_logic := 'H';
	signal b_tmpSDA : std_logic := 'H';
	
	----------------------------------------------------------------------------
	
	type states is(waiting, start, read, read1, read2, write1, write2, sendAKK, checkAKK); -- states
	signal state, next_state : states := waiting;	-- states for next state and state after next 
	
	-- varible to check if address is right
	signal Address		: std_logic_vector(7 downto 0) := (others => L); 
	-- variable to count bits and recognize if full byte is received or sent	
	signal clk_cnt 		: std_logic_vector(2 downto 0) := (others => L);
	-- DataIn buffer
	signal DataIn       : std_logic_vector(7 downto 0) := (others => L);
	-- Register Pointer
	signal Pointer      : std_logic_vector(1 downto 0) := (others => L);
	-- Register Data (8bit or 2x 8bit)
	signal Temp0        : std_logic_vector(7 downto 0) := "10000000";
	signal Temp1	    : std_logic_vector(7 downto 0) := "01000001"; 	-- (65°C)
	signal Config       : std_logic_vector(7 downto 0) := (others => L);
	signal Thyst0       : std_logic_vector(7 downto 0) := (others => L);
	signal Thyst1       : std_logic_vector(7 downto 0) := "01001011";	-- initial value of LM75 (75°C)
	signal Tos0         : std_logic_vector(7 downto 0) := (others => L);
	signal Tos1         : std_logic_vector(7 downto 0) := "01010000";	-- initial value of LM75 (80°C)
	--indicator to wait a clock	
	signal waitclk		: std_logic := L;
	--internal SDA signal
	signal tmpSDA : std_logic := 'H';
	--simulation signal to check signal bevor bus
	signal tmpSDAlog : std_logic := 'H';
	
	signal o_SCL : std_logic := L;
	signal o_SDA : std_logic := L;
	        
	----------------------------------------------------------------------------
	
		
begin

	process
	begin
		opb_clk <= L;
		wait for 20 ns;
		opb_clk <= H;
		wait for 20 ns;
	end process;
	
	----------------------------------------------------------------------------
    b_tmpSCL<='H'; --|__\ 'pullup' of data lines
    b_tmpSDA<='H'; --|  /
    b_tmpSDA<= L when tmpSDAlog=L else Z; -- don't send heavy high
    b_tmpSDA<= L when o_SDA=L else Z;
    b_tmpSCL<= L when o_SCL=L else Z;
	
	process(b_tmpSCL, b_tmpSDA)
	begin
		
		if(falling_edge(b_tmpSCL)) then --synchronisation on the falling edge of written signals
			tmpSDAlog<=tmpSDA;
		end if;
		       
		if(rising_edge(b_tmpSCL)) then
			case state is
				when waiting =>  null;
				
				when start   => 
						-- starting with bit 7 (counter = 0) set 8 times a lower bit.
						Address(Address'length-1 - conv_integer(clk_cnt)) <= b_tmpSDA;
						if(clk_cnt = "111") then -- after 8 times check address:
							if (Address(7 downto 1) = "1001000") then -- if address is LM75s address
								if (b_tmpSDA = 'H') then -- check if master wants to read
									state <= write1; -- set state after akk to write temp			
								else -- else, if master wants to write
									state <= sendAKK; -- set state after akk to read some byte
									next_state <= read; -- first byte i have to read is always
														-- the pointer address
								end if;               		
								tmpSDA <= L;                               	
							else -- else, if address was wrong:
								state <= sendAKK; -- don't send akk
								tmpSDA <= 'H';
								next_state <= waiting; -- go to wait
							end if;
						end if;
						-- count bits (after 8 bits no need to zero value in cause of an 3 bit value)	
						clk_cnt <= clk_cnt + 1;
							
				when read    =>
						-- starting with bit 7 (counter = 0) set 8 times a lower bit. 
						DataIn(DataIn'length-1 - conv_integer(clk_cnt)) <= b_tmpSDA;
						if(clk_cnt = "111") then -- after 8 times pointer is read
							 Pointer <= DataIn(1) & b_tmpSDA; -- safe pointer
							 state <= sendAKK; -- send akk 
							 tmpSDA <= L; -- to be on clock i have to send every signal
							 			  -- one whole clock earlier, it later gets synchronised with
							 			  -- the following negative edge
							 next_state <= read1; -- after akk master either aborts or sends data to
							                      -- write into pointers address so i I'm ready to read next byte
						end if;
						-- count bits (after 8 bits no need to zero value in cause of an 3 bit value)
						clk_cnt <= clk_cnt + 1;
						
				when read1 	 =>
						-- starting with bit 7 (counter = 0) set 8 times a lower bit.  
						DataIn(DataIn'length-1 - conv_integer(clk_cnt)) <= b_tmpSDA;
						if(clk_cnt = "111") then 
							 if (Pointer = "01") then -- check the saved pointer value to decide where to save data
							 	Config <= DataIn(7 downto 1) & b_tmpSDA; -- save data
							 	next_state <= waiting; -- Config register is only 8bit long, so after 1 read go to wait
							 	state <= sendAKK; -- send Akk
							 	tmpSDA <= L; -- to be on clock i have to send every signal
								 			 -- one whole clock earlier, it later gets synchronised with
								 			 -- the following negative edge
							 elsif (Pointer = "10") then
							 	Thyst1 <= DataIn(7 downto 1) & b_tmpSDA;
							 	next_state <= read2; -- Thyst register is 16bit long, so i have to read a second byte
							 	state <= sendAKK;
							 	tmpSDA <= L;
							 elsif (Pointer = "11") then
							 	Tos1 <= DataIn(7 downto 1) & b_tmpSDA;
							 	next_state <= read2; -- Tos register is 16bit long, so i have to read a second byte
							 	state <= sendAKK;
							 	tmpSDA <= L;
							 end if;
						end if;
						-- count bits (after 8 bits no need to zero value in cause of an 3 bit value)
						clk_cnt <= clk_cnt + 1;
						
				when read2	 =>
						-- starting with bit 7 (counter = 0) set 8 times a lower bit. 
						DataIn(DataIn'length-1 - conv_integer(clk_cnt)) <= b_tmpSDA;
						if(clk_cnt = "111") then -- check the saved pointer value to decide where to save data
							 if (Pointer = "10") then
							 	Thyst0 <= DataIn(7 downto 1) & b_tmpSDA; -- Thyst register is written
							 	next_state <= waiting; -- so I can go to wait
							 	state <= sendAKK;
							 	tmpSDA <= L; -- to be on clock i have to send every signal
								 			 -- one whole clock earlier, it later gets synchronised with
								 			 -- the following negative edge
							 elsif (Pointer = "11") then
							 	Tos0 <= DataIn(7 downto 1) & b_tmpSDA; -- Tos register is written
							 	next_state <= waiting;
							 	state <= sendAKK;
							 	tmpSDA <= L;
							 end if;
						end if;
						-- count bits (after 8 bits no need to zero value in cause of an 3 bit value)
						clk_cnt <= clk_cnt + 1;
								
				when write1  =>
						-- if master wants to read I first have to check which register I have to send
						-- and send the msb of the (most significant) data byte first
						-- (every sending assignement is one clock earlier sent to get synchronised later on to the
						-- following negative edge)
						if (Pointer = "00") then
						 	tmpSDA <= Temp1(DataIn'length-1 - conv_integer(clk_cnt));
						elsif (Pointer = "01") then
						 	tmpSDA <= Config(DataIn'length-1 - conv_integer(clk_cnt));
						elsif (Pointer = "10") then
						 	tmpSDA <= Thyst1(DataIn'length-1 - conv_integer(clk_cnt));
						elsif (Pointer = "11") then
						 	tmpSDA <= Tos1(DataIn'length-1 - conv_integer(clk_cnt));
						end if;
						if(clk_cnt = "111") then -- if data byte is sent I have to decide if I have to send the
												-- second byte of the register or if register only has one byte
							 if (Pointer = "00") then
						 		next_state <= write2;
							 elsif (Pointer = "01") then
						 		next_state <= waiting;
							 elsif (Pointer = "10") then
						 		next_state <= write2;
							 elsif (Pointer = "11") then
						 		next_state <= write2;
							 end if;
							 state <= checkAKK;
							 waitclk <= H; --because I was writing and now want to read masters akk i have to wait
							 			   -- one clock more...
						end if;
						clk_cnt <= clk_cnt + 1;
						
				when write2	 => 
						-- if master wants to read I first have to check which register I have to send
						-- and send the msb of the (most significant) data byte first
						-- (every sending assignement is one clock earlier sent to get synchronised later on to the
						-- following negative edge)
						-- In this case first byte is allready set but it doesn't change my assignement, because
						-- the counter was set to one 
						 if (Pointer = "00") then
						 	tmpSDA <= Temp0(DataIn'length-1 - conv_integer(clk_cnt));
						 elsif (Pointer = "10") then
						 	tmpSDA <= Thyst0(DataIn'length-1 - conv_integer(clk_cnt));
						 elsif (Pointer = "11") then       
						 	tmpSDA <= Tos0(DataIn'length-1 - conv_integer(clk_cnt));
						 end if;
						if(clk_cnt = "111") then -- if all bits are sent
						 	state <= checkAKK;   -- check the akk of the master and
						 	waitclk <= H;       -- go to end
					 		next_state <= waiting;
						end if;
						clk_cnt <= clk_cnt + 1;
						
				when sendAKK =>
						state <= next_state;
						tmpSDA <= 'H';
						
				when checkAKK=>
						if (waitclk = H) then
							waitclk <= L;  -- wait one clock
							tmpSDA <= 'H'; -- give Data line free
						elsif (b_tmpSDA = L) then -- if master wants a byte more(from the 2 byte register)...
							state <= next_state;
							-- Now: I was reading the akk of the master and want to write my second byte, so
							-- I allready have to set first bit on this clock edge, that the signal can get
							-- synchronised with the following negative edge
							if (Pointer = "00") then
								tmpSDA <= Temp0(DataIn'length-1);
							elsif (Pointer = "10") then
							 	tmpSDA <= Thyst0(DataIn'length-1);
							elsif (Pointer = "11") then       
							 	tmpSDA <= Tos0(DataIn'length-1);
							end if;
							clk_cnt <= "001"; --set counter one up to indicate one bit allready set
						else
							state <= waiting; --esle if master sent nack go to waiting state
						end if;
				
			end case;
		end if;
		
		-- check start condition of I2C bus. And start without any further checks
		if falling_edge(b_tmpSDA) and b_tmpSCL='H' then
			state<=start; -- go to start
			-- I'm not shure if followed two assignments really needed, but i think it's saver 
			tmpSDA <= 'H';-- release Data line
			clk_cnt <= (others => L); -- zero byte-bit counter
			waitclk <= L;
		end if;
		
		-- check stop condition of I2C bus. And reset without any further checks
		if rising_edge(b_tmpSDA) and b_tmpSCL='H' then
			state<=waiting; -- go to waiting state
			tmpSDA <= 'H';-- release Data line
			clk_cnt <= (others => L); -- zero byte-bit counter
			waitclk <= L;
		end if;
				
	end process;
    ----------------------------------------------------------------------------
    
    
	test : entity work.ReadOnlyTempLM75
	port map (
		i_clk =>  opb_clk,
		i_enable => H,
		-- i2c bus -----------------------------------------------------------------
		-- b_SCL => b_tmpSCL,
		-- b_SDA => open, --b_tmpSDA,
		o_SCL =>  o_SCL ,
		o_SDA =>  o_SDA ,
                      
		i_SCL  =>  b_tmpSCL  ,
		i_SDA  =>  b_tmpSDA  ,
		
		-- Data Out ----------------------------------------------------------------
		o_Temp => open
		
	);
	
end arc_tb;