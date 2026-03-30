--------------------------------------------------------------------------------
--
--  BRAM_8kByte_A32_B32.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : C. Leuthold, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	05.02.2008-le	add svn keywords
--	13.02.2012-le	change to read first
--------------------------------------------------------------------------------
--$Rev:: 3142                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-12-13 11:03:09 +0100 (Fr, 13 Dez 2013)                          $
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY BRAM_16kByte_A32_B32 is

	generic (
		BRAM_Init		: tSLV_Nx32(0 to 4095) := (others => (others => '0'));
		g_OUTREG_A		: in integer range 0 to 1 := 0
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic 					:= '0';
		i_BRAM_EN_A   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_A  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_A 	: IN  std_logic_vector(11 downto 0) := "000000000000";
		i_BRAM_Dout_A 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_A  	: OUT std_logic_vector(31 downto 0) := x"00000000";

		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector(11 downto 0) := "000000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
END;

ARCHITECTURE impl OF BRAM_16kByte_A32_B32 IS

	signal wren_a		: std_logic;
	signal wren_B		: std_logic;

	COMPONENT altsyncram
	GENERIC (
		address_reg_b				: STRING;
		byteena_reg_b				: STRING;
		byte_size					: NATURAL;
		clock_enable_input_a		: STRING;
		clock_enable_input_b		: STRING;
		clock_enable_output_a		: STRING;
		clock_enable_output_b		: STRING;
		indata_reg_b				: STRING;
		intended_device_family		: STRING;
		lpm_type					: STRING;
		INIT_FILE					: STRING;
		numwords_a					: NATURAL;
		numwords_b					: NATURAL;
		operation_mode				: STRING;
		outdata_aclr_a				: STRING;
		outdata_aclr_b				: STRING;
		outdata_reg_a				: STRING;
		outdata_reg_b				: STRING;
		power_up_uninitialized		: STRING;
		read_during_write_mode_mixed_ports : STRING := "OLD_DATA";
		--ram_block_type		: STRING; -- 08.11.2010 QFU Debug: RAM is not initialized after switching to FPGA user mode
		widthad_a					: NATURAL;
		widthad_b					: NATURAL;
		width_a						: NATURAL;
		width_b						: NATURAL;
		width_byteena_a				: NATURAL;
		width_byteena_b				: NATURAL;
		wrcontrol_wraddress_reg_b	: STRING
	);
	PORT (
		wren_a		: IN STD_LOGIC ;
		clock0		: IN STD_LOGIC ;
		clocken0    : IN std_logic;
		wren_b		: IN STD_LOGIC ;
		clock1		: IN STD_LOGIC ;
		clocken1    : IN std_logic;
		byteena_a	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		byteena_b	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		address_a	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		address_b	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		q_a			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		q_b			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		data_a		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
	END COMPONENT;

	function C_OUTREG(i : integer range 0 to 1) return string is
	begin
		if (i=1) then
			return "CLOCK0";
		else
			return "UNREGISTERED";
		end if;
	end C_OUTREG;

BEGIN

	-- create write-enables
	process (i_BRAM_WEN_A,i_BRAM_EN_A) begin
		if ((i_BRAM_WEN_A > x"00") and (i_BRAM_EN_A = '1')) then
			wren_a <= '1';
		else
			wren_a <= '0';
		end if;
	end process;

	process (i_BRAM_WEN_B) begin
		if (i_BRAM_WEN_B > x"0") then
			wren_b <= '1';
		else
			wren_b <= '0';
		end if;
	end process;


	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b 				=> "CLOCK1",
		byteena_reg_b 				=> "CLOCK1",
		byte_size 					=> 8,
		clock_enable_input_a 		=> "NORMAL",
		clock_enable_input_b 		=> "NORMAL",
		clock_enable_output_a 		=> "BYPASS",
		clock_enable_output_b 		=> "BYPASS",
		indata_reg_b 				=> "CLOCK1",
		intended_device_family 		=> "Arria GX",
		lpm_type 					=> "altsyncram",
		INIT_FILE 					=> "COP_PAS.mif",
		numwords_a 					=> 4096,
		numwords_b 					=> 4096,
		operation_mode 				=> "BIDIR_DUAL_PORT",
		outdata_aclr_a 				=> "NONE",
		outdata_aclr_b 				=> "NONE",
		outdata_reg_a				=> C_OUTREG(g_OUTREG_A),
		outdata_reg_b				=> "UNREGISTERED",
		power_up_uninitialized 		=> "FALSE",
		--ram_block_type => "M4K", -- 08.11.2010 QFU Debug: RAM is not initialized after switching to FPGA user mode
		widthad_a 					=> 12,
		widthad_b 					=> 12,
		width_a 					=> 32,
		width_b 					=> 32,
		width_byteena_a 			=> 4,
		width_byteena_b 			=> 4,
		wrcontrol_wraddress_reg_b 	=> "CLOCK1"
	)
	PORT MAP (
		clock0		=> i_BRAM_Clk_A	,
		clocken0    => i_BRAM_EN_A,
		wren_a		=> wren_a		,
		byteena_a	=> i_BRAM_WEN_A	,
		data_a		=> i_BRAM_Dout_A,
		address_a	=> i_BRAM_Addr_A,
		q_a			=> o_BRAM_Din_A	,

		clock1		=> i_BRAM_Clk_B	,
		clocken1    => i_BRAM_EN_B,
		wren_b		=> wren_b		,
		byteena_b	=> i_BRAM_WEN_B	,
		address_b	=> i_BRAM_Addr_B,
		data_b		=> i_BRAM_Dout_B,
		q_b			=> o_BRAM_Din_B
	);


END ARCHITECTURE impl;
