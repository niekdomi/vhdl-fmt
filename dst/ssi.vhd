--------------------------------------------------------------------------------
--  ssi interface
--------------------------------------------------------------------------------
--
--  project     : INFO-SAC2
--  programmer  : Christof Leuthold, INDEL AG
--  date        : 12.10.2004
--  version     : 1.00
--  language    : VHDL
--  system      : ispLever 3.0
--
--  purpose
--  	 synchron serielles interface (ssi)
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00   :   12.10.2004-le  : - disc.
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.all;
--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity ssi is
	generic (
		C_SR_LNG : integer := 32;
		C_CLK_CNT_LNG : integer := 8;
		C_DATA_CNT_LNG : integer := 5;
		C_REG_LNG : integer := 16
	);
	port (
		i_Clk		: in	std_logic;				-- clock input
		i_Reset		: in	std_logic;				-- reset input H-active
		-- config
		i_clk_div	: in	std_logic_vector(C_REG_LNG-1 downto 0);
		i_data_length: in	std_logic_vector(C_REG_LNG-1 downto 0);
		--ssi Pins
		no_sClk		: out	std_logic;
		i_sData		: in	std_logic;
		-- interface
		o_Data		: out	std_logic_vector(C_SR_LNG-1 downto 0);
		o_data_ready: out	std_logic;
		i_Enable	: in	std_logic;
		i_start		: in	std_logic
	);
end;                                                    -- of entity ssi

architecture behavior_ssi of ssi is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
	constant H			: std_logic := '1';
	constant L			: std_logic := '0';
	constant Z			: std_logic := 'Z';


-- types -----------------------------------------------------------------------
	type t_states is (idle,start_conv,read_data);
-- signals ---------------------------------------------------------------------
	signal sClk			: std_logic := L;
	signal clk_cnt		: std_logic_vector(C_CLK_CNT_LNG-1 downto 0) := (others => L);
	signal read			: std_logic := L;
	signal start_clk	: std_logic := L;
	signal Data			: std_logic_vector(C_SR_LNG-1 downto 0) := (others => L);
	signal data_cnt		: std_logic_vector(C_DATA_CNT_LNG-1 downto 0) := (others => L);
	signal sData		: std_logic;
	signal state		: t_states := idle;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture ssi

	no_sClk <= not(sClk and start_clk);
	sData <= i_sData;
-- processes -------------------------------------------------------------------
	----------------------------------------------------------------------------
	-- ssi_clk
	----------------------------------------------------------------------------
	-- i_clk_div	= 3
	-- i_clk		012345678901234567890123456789012345678901234567890
	-- start_clk	___-------------------------------------------_____
	-- clk_cnt		x33321032103210321032103210321032103210321032103333
	-- sClk			x______----____----____----____----____----________
	-- read			x_________-_______-_______-_______-_______-________
	----------------------------------------------------------------------------
	ssi_clk : process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
			sClk <= L;
		elsif rising_edge(i_Clk) then
		-- clocked statements
			read <= L;
			if i_clk_div=0 then
				sClk <= L;
			else
				if start_clk = H then
					clk_cnt <= clk_cnt - 1;
					if clk_cnt = 0 then
						sClk <= not sClk;
						clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0);
					elsif clk_cnt = 1 then
						read <= sClk;
					end if;
				else
					sClk <= L;
					clk_cnt <= i_clk_div(C_CLK_CNT_LNG-1 downto 0);
				end if;
			end if;
		end if;
	end process ssi_clk;
	----------------------------------------------------------------------------
	-- no_sClk		------__--__--__--__--__--__-----------------------
	-- i_sData		--------____----____--------_________________------
	-- i_Clk		012345678901234567890123456789012345678901234567890
	-- i_data_length = 8
	-- read			_______-___-___-___-___-___-___-___________________
	-- i_start		___-_______________________________________________
	-- state		IIIISSSSRRRRRRRRRRRRRRRRRRRRRRRRWWWWWWWWWWWWWWIIIII
	-- start_clk	____----------------------------___________________
	-- data_cnt		000000000000111122223333444455555555555555555550000
	-- data
	o_Data <= Data;
	ssi_data : process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
		elsif rising_edge(i_Clk) then
		-- clocked statements
			o_data_ready<= L;
			if (i_Enable=H) then
				case state is
					when idle =>
						if (i_start=H) then --start
							state <= start_conv;
							start_clk <= H;
						end if;
					when start_conv =>	-- start bit
						if (read=H) then
							state <= read_data;
						end if;
						Data <= (others => L);
						data_cnt(C_DATA_CNT_LNG-1 downto 1) <= (others => L);
						data_cnt(0) <= H;
					when read_data =>
						if (read=H) then
							data_cnt<= data_cnt + 1;
							if (data_cnt = i_data_length(C_DATA_CNT_LNG-1 downto 0)) then
								state <= idle;
								o_data_ready <= H;
								start_clk <= L;
							end if;
							Data <= Data(C_SR_LNG-2 downto 0) & sData;
						end if;
				end case;
			else
				-- reset
				state <= idle;
				start_clk <= L;
			end if;
		end if;
	end process ssi_data;
end behavior_ssi;
--------------------------------------------------------------------------------

