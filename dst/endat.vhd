--------------------------------------------------------------------------------
--	endat, ssi and hyperface interface
--------------------------------------------------------------------------------
--
--	project     : 
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 27.03.2006
--	version     : 1.00
--	language    : VHDL
--	system      : ise81
--
--	purpose
--		endat 2.1 interface
--		ssi interface
--		hiperface (only read pos. at braodcast address 0xFF with odd parity, 
--			baudrate is i_clk_div=(i_clk frequenc)/2/baudrate/16
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	27.03.2006-le  : - start
--	03.11.2006-le  : - add ssi interface
--	11.05.2007-le  : - add svn keywords
--	12.05.2009-le  : - add hiperface support
--	08.09.2009-le  : - add crc support for Endat and some error dedection
--	02.09.2011-le  : - remove clk spike in ssimode and C_HIPERFACE_SUPPORT=1
--	23.09.2011-le  : - set busy at start
--	07.07.2017-le  : - remove clk spike in Endat mode
--	28.0-.2018-le  : - add a switchable colck pre divider. 
--						defined with C_CLK_PRE_DIV and switchable with
--						i_fast_clk. this should allow a new design to run with
--						e.g. 100 MHz replacing a old with running with 25
--						(C_CLK_PRE_DIV=4). new sw can switch to 100 but for older
--						it will always running with25...
--------------------------------------------------------------------------------
-- 	!!! for newer impl. use endat22.vhd and this only for hiperface and ssi  !!!
--------------------------------------------------------------------------------
--$Rev:: 4812                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-09 17:02:53 +0200 (Mo., 09 Apr 2018)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;
--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity endat is
	generic (
		C_SR_LNG : integer := 64;
		C_CLK_CNT_LNG : integer := 9;
		C_DATA_CNT_LNG : integer := 6;
		C_HIPERFACE_SUPPORT : integer range 0 to 1 := 1;
		C_CRC_ERROR_SUP : integer range 0 to 1 := 0;
		C_CLK_PRE_DIV : integer range 1 to 8 := 1
	);
	port (
		i_Clk		: in	std_logic;				-- clock input
		-- config
		i_clk_div	: in	std_logic_vector(C_CLK_CNT_LNG-1 downto 0);
		i_data_lng: in	std_logic_vector(C_DATA_CNT_LNG-1 downto 0);
		i_fast_clk	: in	std_logic := L;
		--endat Pin controll
		o_sClk		: out	std_logic;
		i_sData		: in	std_logic;
		o_sData		: out	std_logic;
		o_RnW		: out	std_logic;
		-- interface
		o_Data		: out	std_logic_vector(C_SR_LNG-1 downto 0);
		i_mode		: in	std_logic_vector(2 downto 0);
		i_Data		: in	std_logic_vector(23 downto 0);
		o_data_ready: out	std_logic;
		i_Select	: in	std_logic_vector(1 downto 0) := "00";
		i_SSInEndat : in	std_logic := '0';
		i_Enable	: in	std_logic;
		i_start		: in	std_logic
	);
end;

architecture behavior_endat of endat is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
	constant DF_ADDR  : std_logic_vector(7 downto 0) := x"ff";
	constant DF_CMD   : std_logic_vector(7 downto 0) := x"42";
	constant DF_CHECK : std_logic_vector(7 downto 0) := DF_ADDR xor DF_CMD;
	
	function v_parity(inputs : std_logic_vector) return std_logic is
	variable p : std_logic := L;
	begin
		for i in inputs'Range loop
			p := p xor inputs(i);
		end loop ;
		return p;
	end;
	
	function xv(inputs : std_logic_vector) return std_logic_vector is
	variable p : std_logic_vector(inputs'Range);
	variable j : integer := 0;
	begin
		for i in inputs'low to inputs'high loop
			p(inputs'high-j) := inputs(i);
			J := j + 1;
		end loop ;
		return p;
	end;

-- types -----------------------------------------------------------------------
	type t_states is (idle,wait0,mode_out,data_out,wait1,wait2,startbit,data_in,crc,load_d_hip,data_out_hip,rx_start_hip,rx_start2_hip,rx_hip,rx_par_hip,rx_stop_hip);
-- signals ---------------------------------------------------------------------
	signal sClk			: std_logic := L;
	signal clk_cnt		: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => L);
	signal Dclk			: std_logic := L;
	signal Rclk			: std_logic := L;
	signal start_clk	: std_logic := L;
	signal state		: t_states := idle;
	signal d_sample		: std_logic := L;
	signal d_sample1	: std_logic := L;
	signal data_cnt		: std_logic_vector(C_DATA_CNT_LNG-1 downto 0) := (others => L);
	signal pos			: std_logic := L;
	signal sr			: std_logic_vector(C_SR_LNG-1 downto 0) := (others => L);
	signal GND_V		: std_logic_vector(C_SR_LNG-1 downto 0) := (others => L);
	signal crc_build	: std_logic_vector(4 downto 0);
	signal crc_input	: std_logic;

	signal baudi : std_logic_vector(3 downto 0) := (others => L);
	signal parity			: std_logic := L;
	signal bcnt : std_logic_vector(2 downto 0) := (others => L);
	signal checksum : std_logic_vector(7 downto 0) := (others => L);
	signal clk_prediv	: std_logic_vector(2 downto 0) := CONV_STD_LOGIC_VECTOR(C_CLK_PRE_DIV-1, 3);
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture ssi

	o_sClk <= (sClk or not start_clk);
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
	-- Rclk			x______-_______-_______-_______-_______-____________
	-- o_sClk		---____----____----____----____----____----____--------
	----------------------------------------------------------------------------
	end_clk_div : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
		-- clocked statements
			Dclk <= L;
			Rclk <= L;
			clk_prediv <= CONV_STD_LOGIC_VECTOR(C_CLK_PRE_DIV-1, clk_prediv'length);
			if i_clk_div=0 then
				sClk <= L;
			else
				if (start_clk=H) then
					if (i_fast_clk=H or clk_prediv=0) then
						clk_cnt <= clk_cnt - 1;
					else
						clk_prediv <= clk_prediv-1;
					end if;
					if (clk_cnt=0 and (i_fast_clk=H or clk_prediv=0)) then
						sClk <= not sClk;
						Rclk <= not sClk;
						clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0);
					elsif (clk_cnt=1 and sClk=H and (i_fast_clk=H or clk_prediv=0)) then
						Dclk <= H;
					elsif (clk_cnt=1 and sClk=L and (i_fast_clk=H or clk_prediv=0)) then
						Rclk <= H;
					end if;
				else
					sClk <= L;
					clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0);
				end if;
			end if;
		end if;
	end process end_clk_div;
	----------------------------------------------------------------------------
	-- i_start		____-_______________________________________________________
	-- start_clk	_____-------------------------------------------------------
	
	-- Dclk			________-___-___-___-___-___-___-___-___-_..-___-___-___-__
	-- o_sClk		-----__--__--__--__--__--__--__--__--__--_..-__--__--__--__
	-- b_data		ZZZZZZZZZZZZZ<M2><M1><M0><!2><!1><!0><23>....<00>ZZZZZZZZ  
	-- Rclk			_______-___-___-___-___-___-___-___-___-_..-___-___-___-__
	
	o_Data <= sr;
	
	crc_input <= d_sample xor crc_build(4);
	process (i_Clk)
	begin
		if rising_edge(i_Clk) then
		-- clocked statements
			o_data_ready <= L;
			if (i_Enable=H) then
				case state is
					when idle =>
						o_RnW <= H;
						if (i_start=H) then --start
							start_clk <= H;
							-- set busy
							sr(sr'high) <= H;
							o_data_ready <= H;
							if (C_HIPERFACE_SUPPORT = 1) then
								if (i_Select=DF_SEL_SSI) then
									state <= startbit;
									data_cnt <= i_data_lng;
								elsif (i_Select=DF_SEL_HIP) then
									state <= load_d_hip;
								else
									state <= wait0;
								end if;
							else
								if (i_SSInEndat=H) then
									state <= startbit;
									data_cnt <= i_data_lng;
								else
									state <= wait0;
								end if;
							end if;
						else
							start_clk <= L;
						end if;
					when load_d_hip =>
						if (Dclk=H) then
							data_cnt <= CONV_STD_LOGIC_VECTOR(35, data_cnt'length);
							sr <= H & H & L & xv(DF_ADDR) & v_parity(DF_ADDR) & H & L & xv(DF_CMD) & v_parity(DF_CMD) & H & L & xv(DF_CHECK) & v_parity(DF_CHECK) & H & H & GND_V(sr'high-36 downto 0);
							state <= data_out_hip;
							o_data_ready <= H;
							checksum <= (others => L);
							bcnt <= (others => L);
						end if;
					when data_out_hip =>
						-- send data
						if (Dclk=H) then
							baudi <= baudi+1;
							if (baudi=0) then
								o_RnW <= L;
								o_sData <= sr(sr'high);
								sr(sr'high downto 1) <= sr(sr'high-1 downto 0);
								data_cnt <= data_cnt - 1;
								if (data_cnt=0) then
									state <= rx_start_hip;
								end if;
							end if;
						end if;
					when rx_start_hip =>
						-- startbit dedection
						o_RnW <= H;
						if (Dclk=H) then
							data_cnt <= CONV_STD_LOGIC_VECTOR(7, data_cnt'length);
							parity <= L;
							baudi <= "1001";
							if (d_sample = L) then
								state <= rx_start2_hip;
							end if;
						end if;
					when rx_start2_hip =>
						-- startbit center
						if (Dclk=H) then
							baudi <= baudi+1;
							if (baudi=0) then
								state <= rx_hip;
							end if;
						end if;
					when rx_hip =>
						-- sample bits
						if (Dclk=H) then
							baudi <= baudi+1;
							if (baudi=0) then
								if (bcnt=6) then
									if (d_sample/=checksum(7)) then
										state <= idle;
										sr(sr'high) <= L;
										sr(sr'high-1) <= H; --checksum error
										o_data_ready <= H;
									end if;
									checksum(7 downto 1) <= checksum(6 downto 0);
								else
									sr(0) <= d_sample;
									sr(sr'high downto 1) <= sr(sr'high-1 downto 0);
								end if;
								parity <= parity xor d_sample;
								data_cnt <= data_cnt - 1;
								if (data_cnt=0) then
									state <= rx_par_hip;
								end if;
							end if;
						end if;
					when rx_par_hip =>
						-- check parity
						if (Dclk=H) then
							baudi <= baudi+1;
							if (baudi=0) then
								if (parity=d_sample) then
									state <= rx_stop_hip;
								else
									state <= idle;
									sr(sr'high) <= L;
									sr(sr'high-2) <= H; -- parity error
									o_data_ready <= H;
								end if;
							end if;
						end if;
					when rx_stop_hip =>
						-- check stopbit
						if (Dclk=H) then
							baudi <= baudi+1;
							if (baudi=0) then
								checksum <= sr(7 downto 0) xor checksum;
								if (d_sample=H) then
									state <= rx_start_hip;
									bcnt <= bcnt+1;
									if (bcnt=6) then
										state <= idle;
										o_data_ready <= H;
									else
										sr(7 downto 0) <= xv(sr(7 downto 0));
									end if;
								else
									state <= idle;
									sr(sr'high) <= L;
									sr(sr'high-3) <= H; -- stopbit error
									o_data_ready <= H;
								end if;
							end if;
						end if;
					when wait0 =>
						o_RnW <= H;
						if (Dclk=H) then
							state <= mode_out;
						end if;
						-- load
						data_cnt <= CONV_STD_LOGIC_VECTOR(5, data_cnt'length);
						sr <= i_mode & not i_mode & i_Data & GND_V(sr'high-2*i_mode'length-i_Data'length downto 0);
						if (i_mode="000") then
							pos <= H;
						else
							pos <= L;
						end if;
					when mode_out =>
						-- send mode
						if (Dclk=H) then
							o_RnW <= L;
							o_sData <= sr(sr'high);
							sr(sr'high downto 1) <= sr(sr'high-1 downto 0);
							data_cnt <= data_cnt - 1;
							if (data_cnt=0) then
								if (pos=H) then
									state <= wait1;
									data_cnt <= i_data_lng;
								else
									state <= data_out;
									data_cnt <= CONV_STD_LOGIC_VECTOR(23, data_cnt'length);
								end if;
							end if;
						end if;
					when data_out =>
						-- send data
						if (Dclk=H) then
							o_RnW <= L;
							o_sData <= sr(sr'high);
							sr(sr'high downto 1) <= sr(sr'high-1 downto 0);
							data_cnt <= data_cnt - 1;
							if (data_cnt=0) then
								state <= wait1;
								data_cnt <= CONV_STD_LOGIC_VECTOR(23, data_cnt'length);
							end if;
						end if;
					when wait1 =>
						if (Dclk=H) then
							o_RnW <= H;
							sr <= (others => L);
							state <= wait2;
						end if;
					when wait2 =>
						if (Dclk=H) then
							o_RnW <= H;
							state <= startbit;
						end if;
					when startbit =>
						if (Dclk=H) then
							o_RnW <= H;
							if (d_sample=H) then
								state <= data_in;
							end if;
							sr <= (others => L);
							sr(sr'high) <= H;
							o_data_ready <= H;
							crc_build <= (others => H);
						end if;
					when data_in =>
						-- receive data
						if (Dclk=H) then
							o_RnW <= H;
							sr(0) <= d_sample;
							sr(sr'high downto 1) <= sr(sr'high-1 downto 0);
							data_cnt <= data_cnt - 1;
							if (data_cnt=0) then
								if (C_HIPERFACE_SUPPORT = 1) then
									if (i_Select=DF_SEL_SSI) then
										o_data_ready <= H;
										state <= idle;
										start_clk <= L;
									else
										state <= crc;
									end if;
								else
									if (i_SSInEndat=H) then
										o_data_ready <= H;
										state <= idle;
										start_clk <= L;
									else
										state <= crc;
									end if;
								end if;
								data_cnt <= CONV_STD_LOGIC_VECTOR(4, data_cnt'length);
							end if;
							crc_build(0) <= crc_input;
							crc_build(1) <= crc_build(0) xor crc_input;
							crc_build(2) <= crc_build(1);
							crc_build(3) <= crc_build(2) xor crc_input;
							crc_build(4) <= crc_build(3);
						end if;
					when crc =>
						-- receive crc
						if (Dclk=H) then
							o_RnW <= H;
							data_cnt <= data_cnt - 1;
							if (C_CRC_ERROR_SUP=1) then
								crc_build(4 downto 1) <= crc_build(3 downto 0);
								if (crc_build(4)/=d_sample) then  -- crc is inverted!
									if (data_cnt=0) then
										o_data_ready <= H;
										state <= idle;
										start_clk <= L;
									end if;
								else
									sr(sr'high-1) <= H; -- crc error
									o_data_ready <= H;
									state <= idle;
									start_clk <= L;
								end if;
							else
								sr(0) <= d_sample;
								sr(sr'high downto 1) <= sr(sr'high-1 downto 0);
								if (data_cnt=0) then
									o_data_ready <= H;
									state <= idle;
									start_clk <= L;
								end if;
							end if;
						end if;
				end case;
			else -- disable
				o_RnW <= H;
				state <= idle;
				start_clk <= L;
			end if;
			if (Rclk=H) then
				d_sample1 <= i_sData;
				d_sample <= d_sample1;
			end if;
		end if;
	end process;
end behavior_endat;
--------------------------------------------------------------------------------

