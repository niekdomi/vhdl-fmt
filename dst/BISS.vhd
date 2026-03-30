--------------------------------------------------------------------------------
--	BISS interface
--------------------------------------------------------------------------------
--
--	project     :
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 21.03.2018
--	version     : 1.00
--	language    : VHDL
--
--	purpose
--		BISS interface
--		read pos only with errorbit, warnigbit and crc: DDDDDDDDDDEWCCCCCC
--		CRC: length, init and poli is configurable. default is 6,0,0x43
--		control communication: not implementet	
--		
--		C_CLK_PRE_DIV switchable colck pre divider: 
--			defined with C_CLK_PRE_DIV and switchable with
--			i_fast_clk. this should allow a new design to run with
--			e.g. 100 MHz replacing a old with running with 25
--			(C_CLK_PRE_DIV=4). new sw can switch to 100 but for older
--			it will always running with 25...
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	21.03.2018-le  : - start
--------------------------------------------------------------------------------
--$Rev:: 5555                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2020-06-23 09:15:54 +0200 (Di., 23 Jun 2020)                         $
--------------------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity biss is
	generic (
		C_CLK_CNT_LNG : integer := 9;
		C_CLK_PRE_DIV : integer range 1 to 8 := 1
	);
	port (
		i_Clk		: in	std_logic;				-- clock input
		-- config
		i_clk_div	: in	std_logic_vector(C_CLK_CNT_LNG-1 downto 0);
		i_data_lng	: in	std_logic_vector(5 downto 0);
		i_fast_clk	: in	std_logic := L;
		--endat Pin controll
		o_sClk		: out	std_logic;
		i_sData		: in	std_logic;
		o_sData		: out	std_logic;
		o_RnW		: out	std_logic;
		-- interface
		o_Data		: out	std_logic_vector(63 downto 0);
		i_mode		: in	std_logic_vector(5 downto 0);
		i_Data		: in	std_logic_vector(23 downto 0);
		o_data_ready: out	std_logic;
		o_pos_ready : out	std_logic;
		i_Enable	: in	std_logic;
		i_start		: in	std_logic;
		o_Rclk		: out	std_logic;
		o_Rclk2		: out	std_logic;
		o_SampleD	: out	std_logic;
		o_crc_err	: out	std_logic
	);
end;

architecture behavior_endat of biss is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
	type t_states is (idle,wait12,wait2,startbit,data_in,err_in,wrn_in,crc,last);
-- signals ---------------------------------------------------------------------
	signal sClk			: std_logic := L;
	signal clk_cnt		: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => L);
	signal dly_cnt		: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => L);
	signal delay		: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => L);
	signal delay_dec	: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => L);
	signal Dclk			: std_logic := L;
	signal start_clk	: std_logic := L;
	signal state		: t_states := idle;
	signal d_sample		: std_logic := L;
	signal calc_delay	: std_logic := L;
	signal data_cnt		: std_logic_vector(5 downto 0) := (others => L);
	signal tx_data_cnt	: std_logic_vector(5 downto 0) := (others => L);
	signal mode			: std_logic_vector(3 downto 0) := "0000";
	signal tx_data		: std_logic_vector(29 downto 0) := (others => L);
	signal clk_dly		: std_logic_vector(1 downto 0) := (others => L);
	signal start_rx		: std_logic := L;
	signal start_rx2	: std_logic := L;
	signal clk_L		: std_logic := L;
	-- rx
	signal d_sample1	: std_logic := L;
	signal d_sample2	: std_logic := L;
	signal rx_data_cnt	: std_logic_vector(5 downto 0) := (others => L);
	signal endpos_p		: std_logic_vector(5 downto 0) := (others => L);
	signal crc_input	: std_logic;
	signal crc_order	: std_logic_vector(2 downto 0) := "101"; -- 0..7
	signal crc_poly		: std_logic_vector(7 downto 0) := "00000011";
	signal crc_build	: std_logic_vector(7 downto 0) := (others => L);
	signal crc_init		: std_logic_vector(7 downto 0) := (others => L);
	
	signal rx_data		: std_logic_vector(48 downto 0) := (others => L);
	type t_rx_states is (idle,poll_stb,data_in,err_in,wrn_in,crc);
	signal rx_state		: t_rx_states := idle;
	signal busy			: std_logic;
	signal crc_err		: std_logic;
	signal rx_clk_cnt	: std_logic_vector(C_CLK_CNT_LNG downto 0) := (others => L);
	signal set_busy		: std_logic := L;
	signal clk_prediv	: std_logic_vector(2 downto 0) := CONV_STD_LOGIC_VECTOR(C_CLK_PRE_DIV-1, 3);
	signal err_bit		: std_logic :=L;
	signal wrn_bit		: std_logic :=L;
	signal err_wrn_crc_dis : std_logic :=L;
	signal readcnt		: std_logic_vector(7 downto 0) := (others => L);

-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture ssi
	o_SampleD <= d_sample;
	o_crc_err <= crc_err;

	process (sClk,start_clk,clk_L)
	begin
		if (start_clk=H) then
			if (clk_L=L) then
				o_sClk <= sClk;
			else
				o_sClk <= L;
			end if;
		else
			o_sClk <= H;
		end if;
	end process;
-- processes -------------------------------------------------------------------
	----------------------------------------------------------------------------
	-- ssi_clk
	----------------------------------------------------------------------------
	-- i_clk_div	= 3
	-- i_clk		012345678901234567890123456789012345678901234567890
	-- start_clk	___--------------------------------------------________
	-- clk_cnt		x33321032103210321032103210321032103210321032103333
	-- sClk			x______----____----____----____----____----____________
	-- Dclk			x_________-_______-_______-_______-_______-____________
	-- o_sClk		---____----____----____----____----____----____--------
	----------------------------------------------------------------------------
	end_clk_div : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
		-- clocked statements
			Dclk <= L;
			clk_prediv <= CONV_STD_LOGIC_VECTOR(C_CLK_PRE_DIV-1, clk_prediv'length);
			if i_clk_div(C_CLK_CNT_LNG-1 downto 1)=0 then
				sClk <= L;
				clk_L <= L;
			else
				if (calc_delay=H) then
					if (d_sample=H) then
						dly_cnt <= dly_cnt +1;
					end if;
				end if;
				if (start_clk=H) then
					if (i_fast_clk=H or clk_prediv=0) then
						clk_cnt <= clk_cnt - 1;
					else
						clk_prediv <= clk_prediv-1;
					end if;
					if (clk_cnt=1 and sClk=H and (i_fast_clk=H or clk_prediv=0)) then
						Dclk <= H;
					end if;
					if (clk_cnt=0 and (i_fast_clk=H or clk_prediv=0)) then
						sClk <= not sClk;
						if (clk_dly=0 and sClk=L) then
							clk_L <= L;
						elsif (clk_dly/=0 and sClk=L) then
							clk_L <= H;
						end if;
						clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0);
						if (sClk=L) then
							dly_cnt <= (others => L);
						end if;
					end if;
				else
					sClk <= L;
					clk_L <= L;
					clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0);
				end if;
			end if;
		end if;
	end process end_clk_div;
	----------------------------------------------------------------------------
	
	o_RnW <= H;
	o_sData <= L;
	
	tx : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
		-- clocked statements
		
			set_busy <= L;
			start_rx <= L;
			start_rx2 <= start_rx;
			if (clk_dly/=0 and Dclk=H and delay_dec=0) then
				clk_dly <= clk_dly-1;
			end if;
			if (delay_dec/=0) then
				delay_dec <= delay_dec-1;
			end if;
			if (i_Enable=H) then
				case state is
					when idle =>
						calc_delay <= L;
						mode <= i_mode(3 downto 0);
						if (i_start=H and d_sample=H) then --start
							start_clk <= H;
							state <= wait12;
							set_busy <= H;
							data_cnt <= i_data_lng;
							tx_data_cnt <= i_data_lng;
						else
							start_clk <= L;
						end if;
					when wait12 =>
						if mode="1001" then
							calc_delay <= H;
						elsif mode="1010" then
							crc_init <= i_Data(crc_init'high  downto 0);
						elsif mode="1011" then	
							crc_poly <= i_Data(crc_poly'high  downto 0);
						elsif mode="1100" then
							crc_order <= i_Data(crc_order'high  downto 0);
							err_wrn_crc_dis <= i_Data(8);
						else
							delay <= i_Data(delay'high  downto 0);
						end if;
						if (Dclk=H) then
							state <= wait2;
							delay_dec <= delay;
						end if;
					when wait2 =>
						if (delay_dec=0) then
							start_rx <= H;
						end if;
						if (Dclk=H) then
							calc_delay <= L;
							if (delay_dec=0) then
								state <= startbit;
							else
								tx_data_cnt <= tx_data_cnt - 1;
							end if;
						end if;
					when startbit =>
						if (Dclk=H) then
							if (d_sample=H) then
								state <= data_in;
							end if;
						end if;
					when data_in =>
						-- receive data
						if (Dclk=H) then
							tx_data_cnt <= tx_data_cnt - 1;
							if (tx_data_cnt=0) then
								tx_data_cnt <= (others => L);
								tx_data_cnt(crc_order'length-1 downto 0) <= crc_order;
								if (err_wrn_crc_dis=L) then
									state <= err_in;
								else
									state <= last;
								end if;
							end if;
						end if;
					when err_in =>
						-- receive data
						if (Dclk=H) then
							state <= wrn_in;
						end if;
					when wrn_in =>
						-- receive data
						if (Dclk=H) then
							state <= crc;
						end if;
					when crc =>	
						-- receive crc
						if (Dclk=H) then
							tx_data_cnt <= tx_data_cnt - 1;
							if (tx_data_cnt=0) then
								state <= last;
							end if;
						end if;
					when last =>
						if (Dclk=H) then
							state <= idle;
							start_clk <= L;
						end if;
				end case;
			else -- disable
				state <= idle;
				start_clk <= L;
			end if;
		end if;
	end process tx;


	-- rx ---------------------------------------------------------------------
	d_sample <= d_sample2;
	o_Data <= busy & crc_err & err_bit &  wrn_bit & "0000" & readcnt & rx_data(47 downto 0);
	
	crc_input <= d_sample xor crc_build(CONV_INTEGER(crc_order));
	
	rx : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
			d_sample1 <= i_sData;
			d_sample2 <= d_sample1;
			if (i_fast_clk=H or clk_prediv=0) then
				rx_clk_cnt <= rx_clk_cnt - 1;
			end if;
			busy <= H;
			o_data_ready <= set_busy;
			o_pos_ready <= L;
			o_Rclk <= L;
			o_Rclk2 <= L;
			if (i_Enable=L) then
				readcnt <= (others => L);
				rx_state <= idle;
			elsif (start_rx=H and start_rx2=L) then
				o_Rclk <= H;
				rx_clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0) & L;
				rx_state <= poll_stb;
				rx_data_cnt <= data_cnt;
			elsif (rx_clk_cnt=0 and (i_fast_clk=H or clk_prediv=0)) then
				rx_clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0) & H;
				case rx_state is
					when idle =>
					when poll_stb =>
						o_Rclk <= H;
						rx_data <= (others => L);
						if d_sample=H then
							rx_state <= data_in;
							err_bit <= L;
							wrn_bit <= L;
						end if;
						--if (calc_delay=H) then
						if mode(2 downto 0)="001" then
							rx_data(rx_data'high downto rx_data'high-3) <= mode;
							rx_data(dly_cnt'high downto 0) <= dly_cnt;
							rx_state <= idle;
							o_data_ready <= H;
							busy <= L;
						elsif mode(2 downto 0)="010" then
							rx_data(rx_data'high downto rx_data'high-3) <= mode;
							rx_data(crc_init'high downto 0) <= crc_init;
							rx_state <= idle;
							o_data_ready <= H;
							busy <= L;
						elsif mode(2 downto 0)="011" then
							rx_data(rx_data'high downto rx_data'high-3) <= mode;
							rx_data(crc_poly'high downto 0) <= crc_poly;
							rx_state <= idle;
							o_data_ready <= H;
							busy <= L;
						elsif mode(2 downto 0)="100" then
							rx_data(rx_data'high downto rx_data'high-3) <= mode;
							rx_data(crc_order'high downto 0) <= crc_order;
							rx_data(8) <= err_wrn_crc_dis;
							rx_state <= idle;
							o_data_ready <= H;
							busy <= L;
						end if;
						crc_build <= crc_init;
						crc_err <= L;

					when data_in =>
						o_Rclk <= H;
						o_Rclk2 <= H;
						rx_data_cnt <= rx_data_cnt-1;
						rx_data(CONV_INTEGER(rx_data_cnt)) <= d_sample;
						
						if (rx_data_cnt=0) then
							if (err_wrn_crc_dis=L) then
								rx_state <= err_in;
							else
								busy <= L;
								rx_state <= idle;
								o_data_ready <= H;
								if (mode=0) then
									o_pos_ready <= H;
								end if;
							end if;
							rx_data_cnt <= (others => L);
							rx_data_cnt(crc_order'length-1 downto 0) <= crc_order;
						end if;
						
						crc_build(0) <= crc_input;
						for i in 1 to 7 loop
							if (crc_poly(i)=H) then
								crc_build(i) <= crc_build(i-1) xor crc_input;
							else
								crc_build(i) <= crc_build(i-1);
							end if;
						end loop;
						
					when err_in =>
						o_Rclk <= H;
						o_Rclk2 <= H;
						err_bit <= not d_sample;

						rx_state <= wrn_in;

						crc_build(0) <= crc_input;
						for i in 1 to 7 loop
							if (crc_poly(i)=H) then
								crc_build(i) <= crc_build(i-1) xor crc_input;
							else
								crc_build(i) <= crc_build(i-1);
							end if;
						end loop;
					
					when wrn_in =>
						o_Rclk <= H;
						o_Rclk2 <= H;
						wrn_bit <= not d_sample;

						rx_state <= crc;

						crc_build(0) <= crc_input;
						for i in 1 to 7 loop
							if (crc_poly(i)=H) then
								crc_build(i) <= crc_build(i-1) xor crc_input;
							else
								crc_build(i) <= crc_build(i-1);
							end if;
						end loop;					
						
					when crc =>
						o_Rclk <= H;
						o_Rclk2 <= H;
						-- receive and compare crc
						rx_data_cnt <= rx_data_cnt - 1;
						if (crc_build(CONV_INTEGER(rx_data_cnt))=d_sample) then -- crc is inverted!
							crc_err <= H; -- crc error
						end if;

						if (rx_data_cnt=0) then
							busy <= L;
							rx_state <= idle;
							o_data_ready <= H;
							if (mode=0) then
								readcnt <= readcnt+1;
								o_pos_ready <= H;
							end if;
						end if;

				end case;
			end if;
		end if;
	end process rx;
end behavior_endat;
--------------------------------------------------------------------------------

