--------------------------------------------------------------------------------
--
--	Average Filter 32Bit
--
--------------------------------------------------------------------------------
--
--  project	 : Average Filter 32Bit
--  programmer  : F:Baschung, INDEL AG
--  date		: 08.10.2012
--  version	 : 1.00
--  language	: VHDL
--  system	  : Project Navigator
--
--  purpose
--  	- Average Filter 32Bit
--
--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
LIBRARY ieee;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

LIBRARY BRAM;
USE BRAM.ALL;

--------------------------------------------------------------------------------
entity Average_8x32 is
	port (
		i_CLK				: in	std_logic;
		-- FLT_INP ready
		i_FLT_START			: in	std_logic;
		--	Input value 	(valid for one clk with FLT_START=H)
		i_FLT_INP_t1		: in	signed(31 downto 0);
		i_FLT_INP			: in	signed(31 downto 0);
		-- ADC channel 0..7 (valid for one clk with FLT_START=H)
		i_FLT_CH			: in	integer range 0 to 7;

		-- Filter type (per channel)
		i_FLT_TYPE			: in	tSLV_Nx4(0 to 7) 	:= (others => (others => '0'));

		-- filter result ram (0..7 used only, 32Bit)
		o_FltRam_WEN		: out	std_logic_vector( 3 downto 0) := (others => '0');
		o_FltRam_Addr		: out	std_logic_vector(11 downto 0) := (others => '0');
		o_FltRam_WrData		: out	std_logic_vector(31 downto 0) := (others => '0');

		-- filtered Output value
		o_FLT_OUT		   : out	tSIG_Nx32(0 to 7) 	:= (others => (others => '0'));
		o_FLT_DONE			: out	std_logic	-- a short puls only
	);
end;

architecture impl of Average_8x32 is
--------------------------------------------------------------------------------
	type	tSIG_Nx24	is array(natural RANGE <>)	of signed(23 downto 0);
	type	tSIG_Nx18	is array(natural RANGE <>)	of signed(17 downto 0);
	type	tSIG_Nx33	is array(natural RANGE <>)	of signed(32 downto 0);
	type	tSIG_Nx48	is array(natural RANGE <>)	of signed(47 downto 0);
--------------------------------------------------------------------------------
	signal	L_CH	  	: integer range 0 to 7			:= 0;

	signal	FLT_OUT		: tSIG_Nx32(0 to 7)				:= (others => (others => '0'));

	signal	AVG_START	: std_logic						:= '0';
	signal	SMPL_DIV	: std_logic_vector(3 downto 0)	:= (others => '0');

	signal	FLT_Type	: tslv_Nx4(0 to 7)				:= (others => (others => '1'));

--------------------------------------------------------------------------------
	signal	FLT_SUM		: tSIG_Nx48(0 to 7)				:= (others => (others => '0'));
	signal	New_SUM  	: signed(47 downto 0) 			:= (others => '0');
	signal	New_Val  	: signed(31 downto 0) 			:= (others => '0');
	signal	Oldest_Val  : signed(31 downto 0) 			:= (others => '0');

--------------------------------------------------------------------------------
--	DSP-0	for AVG
	signal	dA0			: signed(31 downto 0) 			:= (others => L);
	signal	dB0			: signed(31 downto 0) 			:= (others => L);
	signal	dG0			: signed(17 downto 0) 			:= (others => L);
	signal	dZ0			: signed(49 downto 0) 			:= (others => L);

	-- norm Zahl 1s.kkkk_kkkk_kkkk_kkkk
	constant nz			: real :=  65536.0;
	signal	FLT_SCL		: tSIG_Nx18(0 to 7)		   	:= (others => (others => '0'));
	signal	FLT_N		: tslv_Nx12(0 to 7)				:= (others => (others => '0'));
	signal	BRAM_WrPos	: tslv_Nx12(0 to 7)				:= (others => (others => '0'));

--------------------------------------------------------------------------------
--	BRAM
-- 	constant BRAM_Init 		: tSLV_Nx32(0 to 511) := (others => (others => '0'));

	-- Histroy Wr-Side
	signal	BRAM_WR_EN  : tslv_Nx4 (0 to 7)				:= (others => (others => '0'));
	signal	BRAM_WR_ADDR: std_logic_vector(11 downto 0)	:= (others => '0');
	signal	BRAM_WR_DATA: std_logic_vector(31 downto 0)	:= (others => '0');

	-- Histroy Rd-Side
	signal	BRAM_RD_DATA: tslv_Nx32(0 to 7)				:= (others => (others => '0'));
	signal	BRAM_RD_ADDR: tslv_Nx12(0 to 7)				:= (others => (others => '0'));

--------------------------------------------------------------------------------
begin


--------------------------------------------------------------------------------
	o_FLT_OUT <= FLT_OUT;

--------------------------------------------------------------------------------
--	32kHz , 16kHz , 8kHz , 4kHz
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) then
			if ((i_FLT_START = H) and (i_FLT_CH = 7)) then
				SMPL_DIV <= SMPL_DIV +1;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Filter Type Output MUX
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) then
		o_FltRam_Addr <= b"0000_0000_0" & conv_std_logic_vector(L_CH,3);
		o_FltRam_WEN <= (others => L);

		if (AVG_START = H) then
			o_FltRam_WEN <= (others => H);
			------------------------------------------------------------------------
			case (FLT_TYPE(L_CH)) is
			------------------------------------------------------------------------
			when x"0" =>	-- no filter
				o_FltRam_WrData	<= std_logic_vector(i_FLT_INP);				-- 1:1
			------------------------------------------------------------------------
			when x"1" =>	-- AVG16 	1kHz	1ms
				o_FltRam_WrData	<= std_logic_vector(New_SUM(35 downto 4));	-- /16
			------------------------------------------------------------------------
			when x"2" =>	-- AVG80 	200Hz	5ms
				o_FltRam_WrData	<= std_logic_vector(New_SUM(38 downto 7));	-- /128 == *1.6/320
			------------------------------------------------------------------------
			when x"3" =>	-- AVG160 	100Hz	10ms
				o_FltRam_WrData	<=std_logic_vector(New_SUM(39 downto 8));	-- 100Hz = 1.6*160/256
			------------------------------------------------------------------------
			when x"4" =>	-- AVG267	60Hz	16.6688 ms
				o_FltRam_WrData	<= std_logic_vector(New_SUM(40 downto 9));	-- 60Hz	= 1.91*267/512
			------------------------------------------------------------------------
			when x"5" =>	-- AVG320	50Hz	20ms
				o_FltRam_WrData	<=std_logic_vector( New_SUM(40 downto 9));	-- 50Hz	= 1.6*320/512
			------------------------------------------------------------------------
			when others => 	-- not implemented
				o_FltRam_WrData	<= std_logic_vector(New_SUM(40 downto 9));
			end case;
			------------------------------------------------------------------------
		end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Inp Skalierung, damit	*scal/512 = 1
--------------------------------------------------------------------------------
selFilt_CFG: for i in 0 to 7 generate
	process (i_CLK) begin
		if rising_edge(i_CLK) then
			--------------------------------------------------------------------
			case (FLT_TYPE(i)) is
			--------------------------------------------------------------------
			when x"0" =>	-- no filter
				FLT_N(i)	<= x"001";				  -- 1kHz = 32/512
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.000000*nz),18);
			--------------------------------------------------------------------
			when x"1" =>	-- AVG16 	1kHz	1ms
				FLT_N(i)	<= x"010";				  -- 1kHz = 32/512
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.000000*nz),18);
			--------------------------------------------------------------------
			when x"2" =>	-- AVG80 	200Hz	5ms
				FLT_N(i)	<= x"050";				  -- 200Hz = 1.6/128
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.600000*nz),18);
			--------------------------------------------------------------------
			when x"3" =>	-- AVG160 	100Hz	10ms
				FLT_N(i)	<= x"0A0";				  -- 100Hz = 1.6*160/256
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.600000*nz),18);
			--------------------------------------------------------------------
			when x"4" =>	-- AVG267	60Hz	16.6688 ms
				FLT_N(i) 	<= x"10B";					-- 60Hz	= 1.91*267/512
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.917603*nz),18);
			--------------------------------------------------------------------
			when x"5" =>	-- AVG320	50Hz	20ms
				FLT_N(i) 	<= x"140";					-- 50Hz	= 1.6*320/512
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.600000*nz),18);
			--------------------------------------------------------------------
			when others =>  -- not implemented
				FLT_N(i)	<= x"200";				  --
				FLT_SCL(i) 	<= CONV_SIGNED(INTEGER( 1.000000*nz),18);
			end case;
			--------------------------------------------------------------------
		end if;
	end process;
end generate;

--------------------------------------------------------------------------------
-- 	DSP functions	(32x24Bits belegt 4 DSP48A1s)
--------------------------------------------------------------------------------
--	 56	  32	32	 18 	Bits
	dZ0 <= (dA0 + dB0) * dG0 after 16 ns;

--------------------------------------------------------------------------------
--	VorFilter	32kHz to 16kHz
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) then
			AVG_START <= L;

			if (i_FLT_START = H) then
				if (SMPL_DIV(0) = L) then
					-- wird schon im top-file gespeichert
				else
					-- prepare DSP input data
					dA0 <=  i_FLT_INP;   		-- neuer Wert
					dB0	<=  i_FLT_INP_t1;		-- letzter t-1 Wert
					dG0 <=  FLT_SCL(i_FLT_CH);	-- *scal/512 = 1
					-- latch channel
					L_CH	<= i_FLT_CH;
					-- next clk = BRAM_AVG
					AVG_START <= H;
				end if;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Filter Calc		SUM = SUM + new_val - oldest_val
--------------------------------------------------------------------------------
	New_Val <= dZ0(48 downto 17);
	New_SUM <= FLT_SUM(L_CH) + New_Val - Oldest_Val;

	process (i_CLK) begin
		if rising_edge(i_CLK) then

			o_FLT_DONE <= L;
			BRAM_WR_EN <= (others => (others => '0'));
		   	BRAM_WR_DATA <= (others => '0');

			-- HOLD (nicht löschen, ISE Fehler ??)
			BRAM_WrPos <= BRAM_WrPos;
			BRAM_RD_ADDR <= BRAM_RD_ADDR;
			FLT_SUM <= FLT_SUM;

			if (AVG_START = H) then
		 		-- check if FLT_TYPE has changed
		  		if (FLT_TYPE(L_CH) /= i_FLT_TYPE(L_CH)) then
					FLT_TYPE(L_CH) <= i_FLT_TYPE(L_CH);

					-- we've to clear SUM and the whole BRAM
					FLT_SUM(L_CH) 		<= (others => '0');
					-- write 0000
					BRAM_WR_EN(L_CH)  	<= "1111";
				   	BRAM_WR_DATA  		<= (others => '0');
					BRAM_WR_ADDR		<= (others => '0');
					BRAM_RD_ADDR(L_CH)	<= (others => '0');
					BRAM_WrPos(L_CH) 	<= (others => '0');

				else
					-- write to BRAM
					BRAM_WR_EN(L_CH) <= "1111";
					BRAM_WR_ADDR <= BRAM_RD_ADDR(L_CH) + BRAM_WrPos(L_CH);

					-- calc next bram-write-pos
					if (FLT_N(L_CH) = BRAM_WrPos(L_CH)) then
						-- calc next sum	(buffer full, +new -old
						FLT_SUM(L_CH) <= New_SUM;

					   	BRAM_WR_DATA <= std_logic_vector(New_Val); -- an Alle

						BRAM_RD_ADDR(L_CH) 	<= BRAM_RD_ADDR(L_CH) + 1;
					else
						-- (clear buffer)
						FLT_SUM(L_CH) <= (others => '0');
					   	BRAM_WR_DATA <= (others => '0');
						BRAM_WrPos(L_CH) <= BRAM_WrPos(L_CH) + 1;

					end if;
				end if;
				o_FLT_DONE <= H;
			end if;


		end if;
	end process;

   	-- BRAM-READ MUX
	Oldest_Val	<= signed(BRAM_RD_DATA(L_CH));

--------------------------------------------------------------------------------
--	Y = (Y*511 + X)/512		== (Y*1.996*256 + x)/512
--------------------------------------------------------------------------------
--		!!	ist nicht wirklich brauchbar  !!
--------------------------------------------------------------------------------
--	--	DSP-1	for 		Y = (Y*511 + X) /512
--		signal	dA1			: signed(31 downto 0) 			:= (others => L);
--	--	signal	dB1			: signed(31 downto 0) 			:= (others => L);
--		signal	dG1			: signed(17 downto 0) 			:= (others => L);
--		signal	dC1			: signed(31 downto 0) 			:= (others => L);
--	--	signal	dZ1			: signed(49 downto 0) 			:= (others => L);
--		signal	dZ1			: signed(49 downto 0) 			:= (others => L);
--
--		signal	FLT_XY		: tSIG_Nx32(0 to 7)				:= (others => (others => '0'));
--------------------------------------------------------------------------------
--	--		1.xxxx * 1.xxxx = xxxx.kk-- * 256 = xxxxkk.-- + yyyyyy.--
--
--
--   	dZ1 <= dA1 * dG1 + (dC1&x"00")  after 16 ns;
--
--   	process (i_CLK) begin
--		if rising_edge(i_CLK) then
--			if (i_FLT_START = H) then
--				if (SMPL_DIV(0) = L) then
--				else
--					dA1 <= FLT_XY(i_FLT_CH);
--					dG1 <= CONV_SIGNED(INTEGER( 1.996094*nz),18);	-- 511/256
--					dC1 <= FLT_INP_32kHz;
--				end if;
--			end if;
--		end if;
--	end process;
--
--	process (i_CLK) begin
--		if rising_edge(i_CLK) then
--			if (AVG_START = H) then
--			 	FLT_XY(L_CH) <= dZ1(48 downto 17);		-- old*511/256*256 /512
--			end if;
--		end if;
--	end process;
--
--------------------------------------------------------------------------------
--	BRAM instance
--------------------------------------------------------------------------------
FiltBRAMs: for i in 0 to 7 generate
	inst_BRam: entity BRAM.BRAM_2kByte_A32_B32
		port map (
		-- History WRITE side
		i_BRAM_Clk_A 	=>	i_CLK						,
		i_BRAM_WEN_A  	=>  BRAM_WR_EN(i)				,
		i_BRAM_Addr_A   =>  BRAM_WR_ADDR(8 downto 0)	,
		i_BRAM_Dout_A   =>  BRAM_WR_DATA				,

		-- History READ side  	(WR for Reset)
		i_BRAM_Clk_B	=> 	i_CLK	   				,
		i_BRAM_Addr_B   => 	BRAM_RD_ADDR(i)(8 downto 0)	,
		o_BRAM_Din_B	=>  BRAM_RD_DATA(i)
	);
end generate;
--------------------------------------------------------------------------------
END;
