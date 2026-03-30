--------------------------------------------------------------------------------
--
--  Altera GIN_BRAM_8kByte_A64_B32.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 21.08.2008
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--	07.06.2011-le - take clk enables from sam3 ethercat to support 10/100 speeds
--				  - add generic for registered outputs (gin-pcie local bus)
--------------------------------------------------------------------------------
--$Rev:: 3142                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-12-13 11:03:09 +0100 (Fr., 13 Dez 2013)                         $
--------------------------------------------------------------------------------
--
-- Xilinx has a write-enable per byte, but no general WE
-- we use the ram xilinx-like
--
-- Altera has one WE and byte-enables
-- so we extract a WE form the i_BRAM_WEN_ 
-- 
--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY GIN_BRAM_8kByte_A64_B32 is 

	generic (
		g_Eth_Type	 	: in   bit_vector(31 downto 0) := x"00000000"; -- x"4574685F";		-- Eth_	
		g_Eth_Rev  		: in   bit_vector(31 downto 0) := x"00000000"; -- x"5478" & X"0101" -- Tx
                                                                     
		g_GL_Rev 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00000101";  -- 
                                                                     
		g_GS_MEM_0 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00040000";	-- 0 32-Bit CfgReg
		g_GS_MEM_1 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00040800";	-- 1 
		g_GS_MEM_2 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00000000";	-- 2 
		g_GS_MEM_3 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00000000";	-- 3 
		g_GS_MEM_4 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00000000";	-- 4 
		g_GS_MEM_5 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00000000";	-- 5 
		g_GS_MEM_6 		: in   bit_vector(31 downto 0) := x"00000000"; -- X"00000000";	-- 6 
		g_GS_MEM_7 		: in   bit_vector(31 downto 0) := x"00000000";  -- X"00000000";	-- 7 
		g_OUTREG_A		: in integer range 0 to 1 := 0
   );
	port (
		i_BRAM_Clk_A  	: IN  std_logic                     := '0';                
		i_BRAM_EN_A   	: IN  std_logic                   	:= '0';                
		i_BRAM_WEN_A  	: IN  std_logic_vector( 7 downto 0)	:= "00000000";         
		i_BRAM_Addr_A 	: IN  std_logic_vector( 9 downto 0)	:= "0000000000";        
		i_BRAM_Dout_A 	: IN  std_logic_vector(63 downto 0)	:= x"0000000000000000";
		o_BRAM_Din_A  	: OUT std_logic_vector(63 downto 0) := x"0000000000000000";	 
	                  	
		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '0';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector(10 downto 0) := "00000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
	
END;

ARCHITECTURE impl OF GIN_BRAM_8kByte_A64_B32 IS

    signal wren_a		: std_logic;
    signal wren_B		: std_logic;
	signal address_b	: STD_LOGIC_VECTOR (10 DOWNTO 0);


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
--		ram_block_type		: STRING;
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
		byteena_a	: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		byteena_b	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		address_a	: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		address_b	: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
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
    
    process (i_BRAM_WEN_B,i_BRAM_EN_B) begin
    	if ((i_BRAM_WEN_B > x"0") and (i_BRAM_EN_B = '1')) then
    		wren_b <= '1';	
    	else
    		wren_b <= '0';	
    	end if;    
    end process;
    
	-- altera seems to think otherwise (like INTEL) then Xilinx (PowerPC)
    address_b <= (i_BRAM_Addr_B(10 downto 1) & not i_BRAM_Addr_B(0)); 
        
	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b 				=> "CLOCK1",
		byteena_reg_b 				=> "CLOCK1",
		byte_size 					=> 8,
		clock_enable_input_a 		=> "BYPASS",
		clock_enable_input_b 		=> "BYPASS",
		clock_enable_output_a 		=> "BYPASS",
		clock_enable_output_b 		=> "BYPASS",
		indata_reg_b 				=> "CLOCK1",
		intended_device_family 		=> "Arria GX",
		lpm_type 					=> "altsyncram",
		INIT_FILE 					=> "GinMaster.mif",
		numwords_a 					=> 1024,
		numwords_b 					=> 2048,
		operation_mode 				=> "BIDIR_DUAL_PORT",
		outdata_aclr_a 				=> "NONE",
		outdata_aclr_b 				=> "NONE",
		outdata_reg_a				=> C_OUTREG(g_OUTREG_A),
		outdata_reg_b				=> "UNREGISTERED",
		power_up_uninitialized 		=> "FALSE",
--		ram_block_type => "M4K",
		widthad_a 					=> 10,
		widthad_b 					=> 11,
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
		wren_b		=> wren_b		,
		byteena_b	=> i_BRAM_WEN_B	,
		address_b	=> address_b	,
		data_b		=> i_BRAM_Dout_B,
		q_b			=> o_BRAM_Din_B
	);

END impl;