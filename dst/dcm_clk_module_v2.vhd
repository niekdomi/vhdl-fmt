--------------------------------------------------------------------------------
--	dcm_clk_module
--------------------------------------------------------------------------------
--
--	project     : gin-card, ppc-card
--	programmer  : C. Leuthold, INDEL AG
--	date        : 26.01.2006
--	version     : 1.00
--	language    : VHDL
--
--	purpose
--		dcm clock module for gin and ppc card
--			input:	Quarz 66 or 125 MHz
--					ddr feedback
--			output: Quarz, Quarz*2, Quarz/2, opb-, plb-clk (99 or 100MHz, 0, 90,
--					180, 270°), 2*plb-clk, ocm-clk 1,5*plb and ppc-clk 3*plb
--					ddr 90° and 270° 
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	14.06.2006-le	+C_MHZ support for 62.5 MHz
--	11.05.2007-le	add svn keywords
--	07.01.2008-le	- add bufg for dcm.clk2x_out to avoid plb to ppc errors on temp. drift
--					- add SRL16 between dmc1.locked and dcm2.reset
--	09.01.2008-le	- change generic C_NO_INPUT_BUFG default to 0
--	08.09.2008-le	- rename file to dcm_clk_module_v2.vhd (virtex2p)
--------------------------------------------------------------------------------
--$Rev:: 545                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2008-09-08 11:34:01 +0200 (Mo., 08 Sep 2008)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
library UNISIM;
use UNISIM.VComponents.all;

entity dcm_clk_module is
	generic (
		C_MHZ : integer := 125;-- 125, 66, 625
		C_DDR_SUPORT : integer := 0;
		C_NO_INPUT_BUFG : integer := 0
	);
	Port (
		i_Quarz : in std_logic;
		o_dcmLocked : out std_logic;
		o_Quarz : out std_logic;
		o_Quarz2x : out std_logic;
		o_Quarz_div2 : out std_logic;
		o_opb_clk : out std_logic;
		o_plb_clk : out std_logic;
		o_ocm_clk : out std_logic;
		o_2xplb_clk : out std_logic;
		o_ppc_clk : out std_logic;
		i_ddr_fb_clk : in std_logic := '0';
		o_opb_clk_90 : out std_logic;
		o_opb_clk_180 : out std_logic;
		o_opb_clk_270 : out std_logic;
		o_ddr_fb_90 : out std_logic;
		o_ddr_fb_270 : out std_logic
	);
end dcm_clk_module;

architecture Behavioral of dcm_clk_module is
	COMPONENT dcm1
	PORT(
		RST_IN : IN std_logic;
		CLKIN_IN : IN std_logic;
		LOCKED_OUT : OUT std_logic;
		CLKDV_OUT : OUT std_logic;
		CLKFX_OUT : OUT std_logic;
		CLK2X_OUT : out std_logic;
		CLK0_OUT : OUT std_logic
		);
	END COMPONENT;
	COMPONENT dcm125
	PORT(
		RST_IN : IN std_logic;
		CLKIN_IN : IN std_logic;
		LOCKED_OUT : OUT std_logic;
		CLKDV_OUT : OUT std_logic;
		CLKFX_OUT : OUT std_logic;
		CLK0_OUT : OUT std_logic
		);
	END COMPONENT;
	COMPONENT dcm62_5
	PORT(
		RST_IN : IN std_logic;
		CLKIN_IN : IN std_logic;
		LOCKED_OUT : OUT std_logic;
		CLKDV_OUT : OUT std_logic;
		CLKFX_OUT : OUT std_logic;
		CLK2X_OUT : out std_logic;
		CLK0_OUT : OUT std_logic
		);
	END COMPONENT;
	COMPONENT dcm2
	PORT(
		CLKIN_IN : IN std_logic;
		RST_IN : IN std_logic;
		LOCKED_OUT : OUT std_logic;
		CLKDV_OUT : OUT std_logic;
		CLK2X_OUT : OUT std_logic;
		CLKFX_OUT : out std_logic;
		CLK0_OUT : OUT std_logic
		);
	END COMPONENT;
	COMPONENT dcm_ddr_int
	port (
		CLKIN_IN   : in    std_logic;
		RST_IN     : in    std_logic;
		CLK0_OUT   : out   std_logic;
		CLK90_OUT  : out   std_logic;
		CLK180_OUT : out   std_logic;
		CLK270_OUT : out   std_logic;
		LOCKED_OUT : out   std_logic
		);
	END COMPONENT;
	COMPONENT dcm_ddr_fb
	port (
		CLKIN_IN        : in    std_logic;
		RST_IN          : in    std_logic;
		CLK0_OUT        : out   std_logic;
		CLK90_OUT       : out   std_logic;
		CLK270_OUT      : out   std_logic;
		LOCKED_OUT      : out   std_logic
		);
	END COMPONENT;

	component INV
	 port (
	   I : in std_logic;
	   O : out std_logic
	   );
	end component;
	component FDS
		port (
			C : in std_logic;
			D : in std_logic;
			S : in std_logic;
			Q : out std_logic
		);
	end component;
	component FD
		port (
			C : in std_logic;
			D : in std_logic;
			Q : out std_logic
		);
	end component;
	signal dcm1_LOCKED_INV_IN   : std_logic;
	signal dcm2_LOCKED_INV_RST  : std_logic;
	signal dcm2_clk_in          : std_logic;
	signal gnd                  : std_logic;
	signal vcc                  : std_logic;
	signal clkin_div_1p5        : std_logic;
	signal clkin_mul4_div3		: std_logic;
	signal clkin_mul_2          : std_logic;
	signal clkin_mul_1          : std_logic;
	signal out1 : std_logic;
	signal out2 : std_logic;
	signal out3 : std_logic;
	signal out4 : std_logic;
	signal dcm1_Reset : std_logic;
	signal locked_2 : std_logic;
	signal locked_3 : std_logic;
	signal locked_4 : std_logic;
	signal dcm3_LOCKED_INV_RST : std_logic;
	signal Quarz_buf : std_logic;
	signal dcm1_CLK0_OUT : std_logic;
	signal dcm2_rst : std_logic;
begin
	gnd <= '0';
	vcc <= '1';
	-- clkin of dcm2 is 148.5 MHz
	o_opb_clk <= clkin_div_1p5;
	o_plb_clk <= clkin_div_1p5;
	o_ocm_clk <= clkin_mul_1;
	o_ppc_clk <= clkin_mul_2;
	o_2xplb_clk <= clkin_mul4_div3;
	o_Quarz <= dcm1_CLK0_OUT;

	input_buffer : if C_NO_INPUT_BUFG=0 generate
	begin
	CLK0_BUFG_INST : BUFG
	 port map (
	  I => i_Quarz,
	  O => Quarz_buf);
	end generate input_buffer;

	no_input_buffer : if C_NO_INPUT_BUFG=1 generate
	begin
	  Quarz_buf <= i_Quarz;
	end generate no_input_buffer;

	--------------------------------------------------------------------------------
	--	Reset for DCM-1
	--------------------------------------------------------------------------------
	--	DCM needs a reset-puls, but we could not take pin from sys_rst,
	--  because the dcm not locked also sets the sys_rst
	--	!! the clkfx does not work without a proper reset !!
	--------------------------------------------------------------------------------
	flop1: FDS port map (D => '0', C => Quarz_buf, Q => out1, S => '0');
	flop2: FD  port map (D => out1, C => Quarz_buf, Q => out2);
	flop3: FD  port map (D => out2, C => Quarz_buf, Q => out3);
	flop4: FD  port map (D => out3, C => Quarz_buf, Q => out4);
	---- dcmReset will be asserted for 3 clock cycles.
	dcm1_Reset <= out2 or out3 or out4;
	
	SRL16_inst : SRL16
-- The following generic declaration is only necessary if you wish to
-- change the initial contents of the SRL to anything other than all
-- zero's.
	generic map (
	INIT => X"FFFF")
	port map (
	Q => dcm2_rst, -- SRL data output
	A0 => vcc, -- Select[0] input
	A1 => vcc, -- Select[1] input
	A2 => vcc, -- Select[2] input
	A3 => vcc, -- Select[3] input
	CLK => dcm1_CLK0_OUT, -- Clock input
	D => dcm2_LOCKED_INV_RST -- SRL data input
	);
-- End of SRL16_inst instantiation

	INV_INST : INV port map (
	  I => dcm1_LOCKED_INV_IN,
	  O => dcm2_LOCKED_INV_RST
	);

	quarz_62_5MHZ : if C_MHZ=625 generate
	begin
		Inst_dcm1: dcm62_5 PORT MAP(
			RST_IN => dcm1_Reset,
			CLKIN_IN => Quarz_buf,
			LOCKED_OUT => dcm1_LOCKED_INV_IN,
			CLKDV_OUT => o_Quarz_div2,
			CLKFX_OUT => dcm2_clk_in,
			CLK2X_OUT => o_Quarz2x,
			CLK0_OUT => dcm1_CLK0_OUT
		);
	end generate quarz_62_5MHZ;

	quarz_66MHZ : if C_MHZ=66 generate
	begin
		Inst_dcm1: dcm1 PORT MAP(
			RST_IN => dcm1_Reset,
			CLKIN_IN => Quarz_buf,
			LOCKED_OUT => dcm1_LOCKED_INV_IN,
			CLKDV_OUT => o_Quarz_div2,
			CLKFX_OUT => dcm2_clk_in,
			CLK2X_OUT => o_Quarz2x,
			CLK0_OUT => dcm1_CLK0_OUT
		);
	end generate quarz_66MHZ;

	quarz_125MHZ : if C_MHZ=125 generate
	begin
		o_Quarz2x <= '0';
		Inst_dcm1: dcm125 PORT MAP(
			RST_IN => dcm1_Reset,
			CLKIN_IN => Quarz_buf,
			LOCKED_OUT => dcm1_LOCKED_INV_IN,
			CLKDV_OUT => o_Quarz_div2,
			CLKFX_OUT => dcm2_clk_in
		);
	end generate quarz_125MHZ;

	Inst_dcm2: dcm2 PORT MAP(
		CLKIN_IN => dcm2_clk_in,					  	--  148.5 or 150 MHZ
		RST_IN => dcm2_rst,
		LOCKED_OUT => locked_2,                     	--in CLKFX
		CLKDV_OUT => clkin_div_1p5,                    	--	 99      100
		CLKFX_OUT => clkin_mul4_div3,					--  198		 200
		CLK2X_OUT => clkin_mul_2,                      	--	297      300
		CLK0_OUT => clkin_mul_1                        	--	148.5    150
	);

	DDR : if C_DDR_SUPORT=1 generate
	begin
		INV_INST : INV port map (
		  I => locked_2,
		  O => dcm3_LOCKED_INV_RST
		);
		Inst_dcm_ddr_int: dcm_ddr_int
		port map (
			CLKIN_IN => clkin_div_1p5,
			RST_IN => dcm3_LOCKED_INV_RST,
			CLK90_OUT => o_opb_clk_90,
			CLK180_OUT => o_opb_clk_180,
			CLK270_OUT => o_opb_clk_270,
			LOCKED_OUT => locked_3
		);
		Inst_dcm_ddr_fb: dcm_ddr_fb
		port map (
			CLKIN_IN => i_ddr_fb_clk,
			RST_IN => dcm3_LOCKED_INV_RST,
			CLK90_OUT => o_ddr_fb_90,
			CLK270_OUT => o_ddr_fb_270,
			LOCKED_OUT => locked_4
		);
		o_dcmLocked <= locked_2 and locked_3 and locked_4;
	end generate DDR;

	NO_DDR : if C_DDR_SUPORT=0 generate
	begin
		o_dcmLocked <= locked_2;
		o_opb_clk_90 <= '0';
		o_opb_clk_180 <= '0';
		o_opb_clk_270 <= '0';
		o_ddr_fb_90 <= '0';
		o_ddr_fb_270 <= '0';
	end generate NO_DDR;

end Behavioral;