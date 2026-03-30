--------------------------------------------------------------------------------
--
--  BRAM_4kByte_A64_B32.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : Q. Fueglistaller, INDEL AG
--  date        : 15.07.2004
--  version     : 1.00
--  language    : VHDL
--  system      : Quartus
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	05.02.2008-le	add svn keywords
--	13.02.2012-le	change to read first
--	25.04.2018-le	add generic "g_INIT_FILE" for altera ram initialization
--------------------------------------------------------------------------------
--$Rev:: 4867                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-25 16:57:30 +0200 (Mi., 25 Apr 2018)                         $
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

LIBRARY altera_mf;
USE altera_mf.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

ENTITY BRAM_4kByte_A64_B32 is 

	generic (
		BRAM_Init		: tSLV_Nx32(0 to 1023) := (others => (others => '0'));
		g_INIT_FILE		: string := "";
		g_OUTREG_A		: in integer range 0 to 1 := 0
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic                     := '0';                
		i_BRAM_EN_A   	: IN  std_logic                   	:= '1';                
		i_BRAM_WEN_A  	: IN  std_logic_vector( 7 downto 0)	:= "00000000";         
		i_BRAM_Addr_A 	: IN  std_logic_vector( 8 downto 0)	:= "000000000";        
		i_BRAM_Dout_A 	: IN  std_logic_vector(63 downto 0)	:= x"0000000000000000";
		o_BRAM_Din_A  	: OUT std_logic_vector(63 downto 0) := x"0000000000000000";	 
	                  	
		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '1';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector( 9 downto 0) := "0000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
	
END;

ARCHITECTURE impl OF BRAM_4kByte_A64_B32 IS

    signal wren_a		: std_logic;
    signal wren_B		: std_logic;
	signal address_b	: STD_LOGIC_VECTOR (9 DOWNTO 0);


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
--		INIT_FILE					: STRING;
		numwords_a					: NATURAL;
		numwords_b					: NATURAL;
		operation_mode				: STRING;
		outdata_aclr_a				: STRING;
		outdata_aclr_b				: STRING;
		outdata_reg_a				: STRING;
		outdata_reg_b				: STRING;
		power_up_uninitialized		: STRING;
		read_during_write_mode_mixed_ports : STRING := "OLD_DATA";
		ram_block_type		: STRING; -- 08.11.2010 QFU Debug: RAM is not initialized after switching to FPGA user mode
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
		wren_b		: IN STD_LOGIC ;
		clock1		: IN STD_LOGIC ;
		clocken1    : IN std_logic;
		byteena_a	: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		byteena_b	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		address_a	: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		address_b	: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		q_a			: OUT STD_LOGIC_VECTOR (63 DOWNTO 0);
		q_b			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		data_a		: IN STD_LOGIC_VECTOR (63 DOWNTO 0);
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

    
 	-- altera seems to think otherwise (like INTEL) then Xilinx (PowerPC)
    address_b <= (i_BRAM_Addr_B(9 downto 1) & not i_BRAM_Addr_B(0)); 
    
	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b 				=> "CLOCK1",
		byteena_reg_b 				=> "CLOCK1",
		byte_size 					=> 8,
		clock_enable_input_a 		=> "BYPASS",
		clock_enable_input_b 		=> "NORMAL",
		clock_enable_output_a 		=> "BYPASS",
		clock_enable_output_b 		=> "BYPASS",
		indata_reg_b 				=> "CLOCK1",
		intended_device_family 		=> "Arria GX",
		lpm_type 					=> "altsyncram",
		numwords_a 					=> 512,
		numwords_b 					=> 1024,
		operation_mode 				=> "BIDIR_DUAL_PORT",
		outdata_aclr_a 				=> "NONE",
		outdata_aclr_b 				=> "NONE",
		outdata_reg_a				=> C_OUTREG(g_OUTREG_A),
		outdata_reg_b				=> "UNREGISTERED",
		power_up_uninitialized 		=> "FALSE",
		ram_block_type => "M4K", -- 08.11.2010 QFU Debug: RAM is not initialized after switching to FPGA user mode
		widthad_a 					=> 9,
		widthad_b 					=> 10,
		width_a 					=> 64,
		width_b 					=> 32,
		width_byteena_a 			=> 8,
		width_byteena_b 			=> 4,
		wrcontrol_wraddress_reg_b 	=> "CLOCK1"
	)
	PORT MAP (
		clock0		=> i_BRAM_Clk_A	,
		wren_a		=> wren_a		,
		byteena_a	=> i_BRAM_WEN_A	,
		data_a		=> i_BRAM_Dout_A,
		address_a	=> i_BRAM_Addr_A,
		q_a			=> o_BRAM_Din_A	,

		clock1		=> i_BRAM_Clk_B	,
		clocken1    => i_BRAM_EN_B,
		wren_b		=> wren_b		,
		byteena_b	=> i_BRAM_WEN_B	,
		address_b	=> address_b	,
		data_b		=> i_BRAM_Dout_B,
		q_b			=> o_BRAM_Din_B
	);

END impl;