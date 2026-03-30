--------------------------------------------------------------------------------
--
--  Virtex-4	BRAM_4kByte_A32_B32.vhd
--
--------------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F:Baschung, INDEL AG
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
--	27.01.2010-FB	erste universelle version mit BRAM_Init Generic
--	25.04.2018-le	add dummy generic "g_INIT_FILE"
--------------------------------------------------------------------------------
--$Rev:: -1                                                                    $
--$Author::                                                                    $
--$Date::                                                                      $
--------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
ENTITY BRAM_4kByte_A32_B32 is 
	generic (
   		BRAM_Init		: tSLV_Nx32(0 to 1023) := (others => (others => '0'));
		g_INIT_FILE		: string := ""     
	);
	port (
		i_BRAM_Clk_A  	: IN  std_logic                     := '0';                
		i_BRAM_EN_A   	: IN  std_logic                   	:= '0';                
		i_BRAM_WEN_A  	: IN  std_logic_vector( 3 downto 0) := "0000";      
		i_BRAM_Addr_A 	: IN  std_logic_vector( 9 downto 0) := "0000000000";
		i_BRAM_Dout_A 	: IN  std_logic_vector(31 downto 0) := x"00000000"; 
		o_BRAM_Din_A  	: OUT std_logic_vector(31 downto 0) := x"00000000";   
	                  	
		i_BRAM_Clk_B  	: IN  std_logic 					:= '0';
		i_BRAM_EN_B   	: IN  std_logic 					:= '0';
		i_BRAM_WEN_B  	: IN  std_logic_vector( 3 downto 0) := "0000";
		i_BRAM_Addr_B 	: IN  std_logic_vector( 9 downto 0) := "0000000000";
		i_BRAM_Dout_B 	: IN  std_logic_vector(31 downto 0) := x"00000000";
		o_BRAM_Din_B  	: OUT std_logic_vector(31 downto 0) := x"00000000"
	);
	
END;

ARCHITECTURE impl OF BRAM_4kByte_A32_B32 IS

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- internal signals
--------------------------------------------------------------------------------
	function init (B , Z : integer) return bit_vector is
		-- B = Bank  	0,1
		-- Z = Zeile	0...63
		variable adr : integer;
		variable result : bit_vector(255 downto 0); 
	begin
		
		for i in 0 to 15 loop		
			adr := Z * 16 + i;
			result((i*16)+15 downto (i*16)) := to_bitvector(BRAM_Init(adr)((B*16)+15 downto (B*16))); 
		end loop;
			
		return result;
	end function init;
	
	type t_D is array (0 to 1) of std_logic_vector(31 downto 0);
	type t_W is array (0 to 1) of std_logic_vector(3 downto 0);
	
	signal Dout_A : t_D;
	signal Dout_B : t_D;
	signal Din_A : t_D;
	signal Din_B : t_D;
	signal WEN_A : t_W;
	signal WEN_B : t_W;
	
	signal net_gnd0 : std_logic;
	signal gnd_vec : std_logic_vector(3 downto 0);
	signal ADDR_A : std_logic_vector(14 downto 0);
	signal ADDR_B : std_logic_vector(14 downto 0);
	
BEGIN
	
--------------------------------------------------------------------------------
-- Power assignments
net_gnd0 <= '0';
gnd_vec	<= (others => '0');
--------------------------------------------------------------------------------
-- Lower-level assignments
--------------------------------------------------------------------------------
	-- das bleibt ein Rätsel...
	ADDR_A <= '0' & i_BRAM_Addr_A & "0000";		
	ADDR_B <= '0' & i_BRAM_Addr_B & "0000"; 
	
	ram2x : for i in 0 to 1 generate
	begin
		RAMB16_inst : RAMB16
		generic map (
			DOA_REG 			=> 0, 				-- Optional output registers on the A port (0 or 1)
			DOB_REG 			=> 0, 				-- Optional output registers on the B port (0 or 1)
			INIT_A 				=> X"000000000", 	--  Initial values on A output port
			INIT_B 				=> X"000000000", 	--  Initial values on B output port
			INVERT_CLK_DOA_REG 	=> FALSE, 			-- Invert clock on A port output registers (TRUE or FALSE)
			INVERT_CLK_DOB_REG 	=> FALSE, 			-- Invert clock on B port output registers (TRUE or FALSE)
			RAM_EXTENSION_A 	=> "NONE", 			-- "UPPER", "LOWER" or "NONE" when cascaded
			RAM_EXTENSION_B 	=> "NONE", 			-- "UPPER", "LOWER" or "NONE" when cascaded
			READ_WIDTH_A 		=> 18, 				-- Valid values are 1,2,4,9,18 or 36 
			READ_WIDTH_B 		=> 18, 				-- Valid values are 1,2,4,9,18 or 36 
			SIM_COLLISION_CHECK => "ALL", 			-- Collision check enable "ALL", "WARNING_ONLY", 
			                              			-- "GENERATE_X_ONLY" or "NONE" 
			SRVAL_A 			=> X"000000000", 	--  Port A output value upon SSR assertion
			SRVAL_B 			=> X"000000000", 	--  Port B output value upon SSR assertion
			WRITE_MODE_A 		=> "WRITE_FIRST", 	--  WRITE_FIRST, READ_FIRST or NO_CHANGE
			WRITE_MODE_B 		=> "WRITE_FIRST", 	--  WRITE_FIRST, READ_FIRST or NO_CHANGE
			WRITE_WIDTH_A 		=> 18, 				-- Valid values are 1,2,4,9,18 or 36
			WRITE_WIDTH_B 		=> 18, 				-- Valid values are 1,2,4,9,18 or 36 
			-- The following INIT_xx declarations specify the initial contents of the RAM
			INIT_00 => init( i ,  0  ),
			INIT_01 => init( i ,  1  ),
			INIT_02 => init( i ,  2  ),
			INIT_03 => init( i ,  3  ),
			INIT_04 => init( i ,  4  ),
			INIT_05 => init( i ,  5  ),
			INIT_06 => init( i ,  6  ),
			INIT_07 => init( i ,  7  ),
			INIT_08 => init( i ,  8  ),
			INIT_09 => init( i ,  9  ),
			INIT_0A => init( i , 10  ),
			INIT_0B => init( i , 11  ),
			INIT_0C => init( i , 12  ),
			INIT_0D => init( i , 13  ),
			INIT_0E => init( i , 14  ),
			INIT_0F => init( i , 15  ),
			INIT_10 => init( i , 16  ),
			INIT_11 => init( i , 17  ),
			INIT_12 => init( i , 18  ),
			INIT_13 => init( i , 19  ),
			INIT_14 => init( i , 20  ),
			INIT_15 => init( i , 21  ),
			INIT_16 => init( i , 22  ),
			INIT_17 => init( i , 23  ),
			INIT_18 => init( i , 24  ),
			INIT_19 => init( i , 25  ),
			INIT_1A => init( i , 26  ),
			INIT_1B => init( i , 27  ),
			INIT_1C => init( i , 28  ),
			INIT_1D => init( i , 29  ),
			INIT_1E => init( i , 30  ),
			INIT_1F => init( i , 31  ),
			INIT_20 => init( i , 32  ),
			INIT_21 => init( i , 33  ),
			INIT_22 => init( i , 34  ),
			INIT_23 => init( i , 35  ),
			INIT_24 => init( i , 36  ),
			INIT_25 => init( i , 37  ),
			INIT_26 => init( i , 38  ),
			INIT_27 => init( i , 39  ),
			INIT_28 => init( i , 40  ),
			INIT_29 => init( i , 41  ),
			INIT_2A => init( i , 42  ),
			INIT_2B => init( i , 43  ),
			INIT_2C => init( i , 44  ),
			INIT_2D => init( i , 45  ),
			INIT_2E => init( i , 46  ),
			INIT_2F => init( i , 47  ),
			INIT_30 => init( i , 48  ),
			INIT_31 => init( i , 49  ),
			INIT_32 => init( i , 50  ),
			INIT_33 => init( i , 51  ),
			INIT_34 => init( i , 52  ),
			INIT_35 => init( i , 53  ),
			INIT_36 => init( i , 54  ),
			INIT_37 => init( i , 55  ),
			INIT_38 => init( i , 56  ),
			INIT_39 => init( i , 57  ),
			INIT_3A => init( i , 58  ),
			INIT_3B => init( i , 59  ),
			INIT_3C => init( i , 60  ),
			INIT_3D => init( i , 61  ),
			INIT_3E => init( i , 62  ),
			INIT_3F => init( i , 63  ),
			-- The next set of INITP_xx are for the parity bits
			INITP_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000")
		port map (
			CASCADEOUTA	=> open, 			-- 1-bit cascade output
			CASCADEOUTB => open, 			-- 1-bit cascade output
			CASCADEINA	=> net_gnd0, 		-- 1-bit cascade A input
			CASCADEINB	=> net_gnd0, 		-- 1-bit cascade B input
			DOA			=> Din_A(i),    	-- 32-bit A port Data Output
			DOB 		=> Din_B(i),    	-- 32-bit B port Data Output
			DOPA 		=> open,    		-- 4-bit  A port Parity Output
			DOPB 		=> open,    		-- 4-bit  B port Parity Output
			CLKA 		=> i_BRAM_Clk_A,	-- Port A Clock
			CLKB 		=> i_BRAM_Clk_B,	-- Port B Clock
			ADDRA 		=> ADDR_A,  		-- 15-bit A port Address Input
			ADDRB 		=> ADDR_B,  		-- 15-bit B port Address Input
			DIA 		=> Dout_A(i),   	-- 32-bit A port Data Input
			DIB 		=> Dout_B(i),   	-- 32-bit B port Data Input
			DIPA 		=> gnd_vec,    		-- 4-bit  A port parity Input
			DIPB 		=> gnd_vec,    		-- 4-bit  B port parity Input
			ENA 		=> i_BRAM_EN_A, 	-- 1-bit  A port Enable Input
			ENB 		=> i_BRAM_EN_B, 	-- 1-bit  B port Enable Input
			REGCEA 		=> net_gnd0, 		-- 1-bit A port register enable input
			REGCEB 		=> net_gnd0, 		-- 1-bit B port register enable input
			SSRA 		=> net_gnd0,    	-- 1-bit  A port Synchronous Set/Reset Input
			SSRB 		=> net_gnd0,    	-- 1-bit  B port Synchronous Set/Reset Input
			WEA 		=> WEN_A(i),    	-- 4-bit  A port Write Enable Input
			WEB 		=> WEN_B(i)     	-- 4-bit  B port Write Enable Input
		);
		
		o_BRAM_Din_A(15+i*16 DOWNTO i*16) <= Din_A(i)(15 DOWNTO 0);
		o_BRAM_Din_B(15+i*16 DOWNTO i*16) <= Din_B(i)(15 DOWNTO 0);
		
		Dout_A(i) <= "0000000000000000" & i_BRAM_Dout_A(15+i*16 DOWNTO i*16);
		Dout_B(i) <= "0000000000000000" & i_BRAM_Dout_B(15+i*16 DOWNTO i*16);
		
		WEN_A(i) <= i_BRAM_WEN_A(1+i*2) & i_BRAM_WEN_A(i*2) & i_BRAM_WEN_A(1+i*2) & i_BRAM_WEN_A(i*2);
		WEN_B(i) <= i_BRAM_WEN_B(1+i*2) & i_BRAM_WEN_B(i*2) & i_BRAM_WEN_B(1+i*2) & i_BRAM_WEN_B(i*2);
		
	end generate ram2x;

END ARCHITECTURE impl;
