--------------------------------------------------------------------------------
--	endat interface
--------------------------------------------------------------------------------
--
--	project     :
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 21.03.2018
--	version     : 1.00
--	language    : VHDL
--
--	purpose
--		endat 2.1 and 2.2 interface
--		
--		C_CLK_PRE_DIV switchable colck pre divider: 
--			defined with C_CLK_PRE_DIV and switchable with
--			i_fast_clk. this should allow a new design to run with
--			e.g. 100 MHz replacing a old with running with 25
--			(C_CLK_PRE_DIV=4). new sw can switch to 100 but for older
--			it will always running with25...
--
--		
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	21.03.2018-le  : - start
--------------------------------------------------------------------------------
--$Rev:: 4926                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-06-29 13:03:27 +0200 (Fr., 29 Jun 2018)                         $
--------------------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity endat22 is
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
		o_addinfo_ready : out	std_logic_vector(1 downto 0);
		i_Enable	: in	std_logic;
		i_start		: in	std_logic;
		o_Rclk		: out	std_logic;
		o_SampleD	: out	std_logic;
		o_crc_err	: out	std_logic
	);
end;

architecture behavior_endat of endat22 is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
	type t_states is (idle,wait0,mode_out,wait1,wait11,wait12,wait2,startbit,data_in,last,addinfo,send22,send22_1,send22_2,send22_3,send22_4,send22_5);--data_out,load_d_hip,data_out_hip,rx_start_hip,rx_start2_hip,rx_hip,rx_par_hip,rx_stop_hip);
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
	signal pos_mode		: std_logic_vector(1 downto 0) := "00";
	signal tx_data		: std_logic_vector(29 downto 0) := (others => L);

	signal add_info		: std_logic := L;
	signal no_add_info	: std_logic_vector(1 downto 0) := (others => L);

	signal clk_dly		: std_logic_vector(1 downto 0) := (others => L);
	signal start_rx		: std_logic := L;
	signal start_rx2	: std_logic := L;
	signal clk_L		: std_logic := L;

	-- rx
	signal d_sample1	: std_logic := L;
	signal d_sample2	: std_logic := L;
	signal rx_data_cnt	: std_logic_vector(5 downto 0) := (others => L);
	signal endpos_p		: std_logic_vector(5 downto 0) := (others => L);
	signal crc_build	: std_logic_vector(4 downto 0);
	signal crc_input	: std_logic;
	signal rx_no_add_info : std_logic_vector(1 downto 0) := (others => L);
	signal rx_data		: std_logic_vector(47 downto 0) := (others => L);
	type t_rx_states is (idle,poll_stb,error_in,data_in,crc,addinfo);
	signal rx_state		: t_rx_states := idle;
	signal busy			: std_logic;
	signal crc_err		: std_logic;
	signal rx_clk_cnt	: std_logic_vector(C_CLK_CNT_LNG downto 0) := (others => L);
	signal set_busy		: std_logic := L;
	signal clk_prediv	: std_logic_vector(2 downto 0) := CONV_STD_LOGIC_VECTOR(C_CLK_PRE_DIV-1, 3);
	signal err_bit		: std_logic :=L;
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
					if (d_sample=L) then
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
						o_RnW <= H;
						o_sData <= L;
						if (i_start=H) then --start
							start_clk <= H;
							state <= wait0;
							set_busy <= H;
							clk_dly <= "01";
							delay_dec <= delay;
							data_cnt <= i_data_lng;
						else
							start_clk <= L;
						end if;
					when wait0 =>
						if (Dclk=H and clk_dly=0) then
							o_RnW <= H;
							o_sData <= L;
							state <= mode_out;
						end if;
						-- load
						if i_mode(5 downto 4)="01" then
							no_add_info <= "01";
						elsif i_mode(5 downto 4)="10" then
							no_add_info <= "10";
						else
							no_add_info <= "00";
						end if;
						tx_data_cnt <= CONV_STD_LOGIC_VECTOR(5, tx_data_cnt'length);
						if (i_mode(3)=L) then -- old 2.1 sw set only 3 bits
							-- 000 pos 2.1
							-- 001 set mrs
							-- 011 write param
							-- 101 reset
							-- 100 read param
							-- 010 read testval
							-- 110 write testval
							-- 111 pos 2.2
							tx_data(5 downto 0) <= i_mode(2 downto 0) & not i_mode(2 downto 0);
							if (i_mode(2 downto 0)="000") then
								pos_mode <= "01"; --2.1
								if i_mode(5 downto 4)="11" then
									calc_delay <= H;
								end if;
								delay <= i_Data(delay'high  downto 0);
							elsif (i_mode(2 downto 0)="111") then
								pos_mode <= "10"; --2.2
								delay <= i_Data(delay'high  downto 0);
							else
								pos_mode <= "00";
								tx_data_cnt <= CONV_STD_LOGIC_VECTOR(5+24, tx_data_cnt'length);
								tx_data <= i_mode(2 downto 0) & not i_mode(2 downto 0) & i_Data;
							end if;
						else
							pos_mode <= "11"; --2.2
							tx_data(5 downto 0) <= i_mode(2 downto 0) & i_mode(2 downto 0);
						end if;
					when mode_out =>
						-- send mode
						if (Dclk=H) then
							o_RnW <= L;
							o_sData <= tx_data(CONV_INTEGER(tx_data_cnt));
							tx_data_cnt <= tx_data_cnt - 1;
							if (tx_data_cnt=0) then
								if (pos_mode/=0) then
									state <= wait1;
									tx_data_cnt <= i_data_lng+5;
								else
									state <= wait1;
									data_cnt <= CONV_STD_LOGIC_VECTOR(23, data_cnt'length);
									tx_data_cnt <= CONV_STD_LOGIC_VECTOR(23+5, tx_data_cnt'length);
								end if;
							end if;
						end if;
					when wait1 =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= wait11;
						end if;
					when wait11 =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= wait12;
						end if;
					when wait12 =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= wait2;
							delay_dec <= delay;
						end if;
					when wait2 =>
						if (delay_dec=0) then
							start_rx <= H;
						end if;
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							if (delay_dec=0) then
								state <= startbit;
							else
								tx_data_cnt <= tx_data_cnt - 1;
							end if;
						end if;
					when startbit =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							if (d_sample=H) then
								state <= data_in;
							end if;
						end if;
					when data_in =>
						-- receive data
						-- receive crc
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							tx_data_cnt <= tx_data_cnt - 1;
							if (tx_data_cnt=0) then
								if (((pos_mode="10") or (pos_mode="11")) and no_add_info/=0) then -- and crc_err=L) then
									state <= addinfo;
								else
									if (pos_mode="11") then
										state <= send22;
									else
										state <= last;
									end if;
								end if;
							end if;
						end if;
					when last =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= idle;
							start_clk <= L;
						end if;
					when addinfo =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							no_add_info <= no_add_info-1;
							tx_data_cnt <= CONV_STD_LOGIC_VECTOR(23+5, tx_data_cnt'length);
							state <= data_in;
						end if;
					when send22 =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= send22_1;
							clk_dly <= "01";
							delay_dec <= delay;
						end if;
					when send22_1 =>
						if (Dclk=H and clk_dly=0) then
							o_RnW <= H;
							o_sData <= L;
							tx_data <= "000001" & i_Data;
							tx_data_cnt <= CONV_STD_LOGIC_VECTOR(23+6, tx_data_cnt'length);
							state <= send22_2;
						end if;
					when send22_2 =>
						if (Dclk=H) then
							o_RnW <= L;
							o_sData <= tx_data(CONV_INTEGER(tx_data_cnt));
							state <= send22_3;
						end if;
					when send22_3 =>
						-- send data
						if (Dclk=H) then
							o_RnW <= L;
							o_sData <= tx_data(CONV_INTEGER(tx_data_cnt));
							tx_data_cnt <= tx_data_cnt - 1;
							if (tx_data_cnt=0) then
								state <= send22_4;
							end if;
						end if;
					when send22_4 =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= send22_5;
						end if;
					when send22_5 =>
						if (Dclk=H) then
							o_RnW <= H;
							o_sData <= L;
							state <= last;
						end if;
				end case;
			else -- disable
				o_RnW <= H;
				o_sData <= L;
				state <= idle;
				start_clk <= L;
			end if;
		end if;
	end process tx;


	-- rx ---------------------------------------------------------------------
	d_sample <= d_sample2;
	o_Data <= busy & crc_err & err_bit & "00000" & readcnt & rx_data;
	crc_input <= d_sample xor crc_build(4);

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
			o_addinfo_ready <= "00";--set_busy & set_busy;
			if (i_Enable=L) then
				readcnt <= (others => L);
				rx_state <= idle;
			elsif (start_rx=H and start_rx2=L) then
				o_Rclk <= H;
				rx_clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0) & L;
				rx_state <= poll_stb;
				rx_data_cnt <= data_cnt;
				rx_no_add_info <= no_add_info;
			elsif (rx_clk_cnt=0 and (i_fast_clk=H or clk_prediv=0)) then
				rx_clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0) & H;
				case rx_state is
					when idle =>
					when poll_stb =>
						o_Rclk <= H;
						rx_data <= (others => L);
						if d_sample=H then
							if (pos_mode/="00") then
								rx_state <= error_in;
								err_bit <= H;
							else
								rx_state <= data_in;
								err_bit <= L;
							end if;
							if (calc_delay=H) then
								rx_data(dly_cnt'high downto 0) <= dly_cnt;
								rx_state <= idle;
								o_data_ready <= H;
								busy <= L;
							end if;
						end if;
						crc_build <= (others => H);
						endpos_p <= (others => L);
						add_info <= L;
						crc_err <= L;
					when error_in =>
						o_Rclk <= H;
						rx_data_cnt <= rx_data_cnt-1;
						endpos_p <= endpos_p+1;
						if (endpos_p=0) then
							err_bit <= d_sample;
							if (pos_mode="01") then
								-- for compatibility with olter sw (shift register impl.)
								-- alarm, d0, d1 ... dn
								rx_data(CONV_INTEGER(rx_data_cnt)) <= d_sample;
								endpos_p <= (others => L);
								rx_state <= data_in;
							end if;
						else
							err_bit <= err_bit or not d_sample;
							endpos_p <= (others => L);
							rx_state <= data_in;
						end if;
						crc_build(0) <= crc_input;
						crc_build(1) <= crc_build(0) xor crc_input;
						crc_build(2) <= crc_build(1);
						crc_build(3) <= crc_build(2) xor crc_input;
						crc_build(4) <= crc_build(3);
					when data_in =>
						o_Rclk <= H;
						rx_data_cnt <= rx_data_cnt-1;
						endpos_p <= endpos_p+1;
						if (((pos_mode="10") or (pos_mode="11")) and add_info=L) then
							-- new impl.: dn, dn-1 ... d1, d0
							rx_data(CONV_INTEGER(endpos_p)) <= d_sample;
						else
							-- for compatibility with olter sw (shift register impl.)
							-- alarm, d0, d1 ... dn-1, dn
							rx_data(CONV_INTEGER(rx_data_cnt)) <= d_sample;
						end if;
						if (rx_data_cnt=0) then
							rx_state <= crc;
							rx_data_cnt <= CONV_STD_LOGIC_VECTOR(4, rx_data_cnt'length);
						end if;
						crc_build(0) <= crc_input;
						crc_build(1) <= crc_build(0) xor crc_input;
						crc_build(2) <= crc_build(1);
						crc_build(3) <= crc_build(2) xor crc_input;
						crc_build(4) <= crc_build(3);
					when crc =>
						o_Rclk <= H;
						-- receive and compare crc
						rx_data_cnt <= rx_data_cnt - 1;
						crc_build(4 downto 1) <= crc_build(3 downto 0);
						if (crc_build(4)=d_sample) then -- crc is inverted!
							crc_err <= H; -- crc error
						end if;
						if (rx_data_cnt=0) then
							busy <= L;
							if (add_info=L) then
								o_data_ready <= H;
								if (pos_mode/=0) then
									o_pos_ready <= H;
									readcnt <= readcnt+1;
								end if;
							else
								if rx_no_add_info/=0 then
									o_addinfo_ready(1) <= H;
								else
									o_addinfo_ready(0) <= H;
								end if;
							end if;
							if (((pos_mode="10") or (pos_mode="11")) and rx_no_add_info/=0 and crc_err=L) then
								rx_state <= addinfo;
							else
								rx_state <= idle;
							end if;
						end if;
					when addinfo =>
						o_Rclk <= H;
						add_info <= H;
						rx_no_add_info <= rx_no_add_info-1;
						rx_data <= (others => L);
						rx_data_cnt <= CONV_STD_LOGIC_VECTOR(23, rx_data_cnt'length);
						rx_state <= data_in;
						crc_build <= (others => H);
						endpos_p <= (others => L);
						crc_err <= L;
				end case;
			end if;
		end if;
	end process rx;
end behavior_endat;
--------------------------------------------------------------------------------

