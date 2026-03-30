---------------------------------------------------------------------------
--
--  C64 Master-Wrapper
--
---------------------------------------------------------------------------
--
--  project     : Gin passive Slave
--  programmer  : F:Baschung, INDEL AG
--  date        : 04.10.2010
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- wraps all ...
--
---------------------------------------------------------------------------
-- ToDo
--
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
--	04.10.2010-fb	first version
--	18.05.2011-le : - add svn keywords
--	28.07.2011-le : - split sda to input and output
--	28.12.2012-FB	zurück auf Stand 2060, neue Version separat in C64Mas_8k_Wrapper
--	23.07.2012-le : - add generic for 32 bit ram
--	31.07.2012-fb : - added addr to read ICU-IRQ-Timer
--	04.10.2013-le : - adjust ICU BRAM switch
--	15.01.2014-le	- add outputs o_C64_CLK_fe and o_C64_CLK_re to support 50/50 clk with ddr output ffs
--	16.05.2014-le	- 8k/3portram: adjustments ans support for cop-mas2
--	29.06.2015-le	- add ports and generics for crc check
--	26.05.2016-le	- add a second irq with own mask and timer for fast irq
--	25.06.2019-le:	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--	12.06.2020-vz	- add handshake signal to/from C64_EEPROMER to share i2c bus with another i2c master
--					  used in cv_sodimm_max4x10 
--------------------------------------------------------------------------------
--$Rev:: 5552                                                                  $
--$Author:: Zuellig                                                            $
--$Date:: 2020-06-15 13:15:49 +0200 (Mo., 15 Jun 2020)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

LIBRARY gin_link;
USE gin_link.ALL;

LIBRARY BRAM;
USE BRAM.ALL;

LIBRARY C64_Master;
USE C64_Master.ALL;


--------------------------------------------------------------------------------
entity C64Mas_Wrap is
	generic (
		g_fpga_type     : in	natural range 0 to 7 := 0; -- 0 = Xilinx, 1 = Altera
		-- passive GinLink Slave ? (or DPR to PowerPC)
		g_GinPasSlv	    : in 	natural range 0 to 1 := 0;
		g64_n32BitRam	: in	integer range 0 to 1 := 1;
--not implemented (ram)		g_OUTREG_A		: in integer range 0 to 1 := 0;
		g_Extern_Q25	: in	natural range 0 to 1 := 0;
		-- GinLink Auto-Soft-Synch
		g_GL_ASoSy		: in	natural range 0 to 1 := 1;
		-- show GinLink-TlgTime
		g_GL_TlgTime	: in	natural range 0 to 1 := 1;
		g_CRCChecker	: in integer range 0 to 1 := 0;
		g_MEM_RdD_REG : in integer range 0 to 1 := 0
	);
	port (
		i_Q125			: in 	std_logic;
		i_Q25		 	: in 	std_logic := L;
		i_TlgIrq		: in 	std_logic_vector( 7 downto 0) := x"00";
		o_IRQs			: out 	std_logic_vector( 1 downto 0);
		i_GinLink_Wdog  : in	std_logic := L;

		i_BRAM_Clk 		: in 	std_logic;
		i_BRAM_EN 		: in 	std_logic;
		i_BRAM_WEN 		: in 	std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);

		i_BRAM_Addr 	: in 	std_logic_vector(15 downto 0);
		i_BRAM_Dout 	: in 	std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_BRAM_Din 		: out	std_logic_vector(31 + g64_n32BitRam*32 downto 0);

		o_C64_CLK_EN	: out	std_logic;
		-- C64-Bus
		o_C64_Reset		: out	std_logic;
		o_C64_CLK		: out	std_logic;
		o_C64_CLK_fe	: out	std_logic; -- clock output for ddr falling edge
		o_C64_CLK_re	: out	std_logic; -- clock output for ddr rising edge
		o_C64_SEL		: out	std_logic;
		o_C64_RES		: out	std_logic;
		o_C64_Dat_HOE	: out	std_logic;
		o_C64_Dat_LOE	: out	std_logic;
		o_C64_Ack_OE	: out	std_logic;
		o_C64_Bend		: out	std_logic;
		o_C64_WrDat		: out	std_logic_vector(15 downto 0);
		i_C64_RdDat		: in 	std_logic_vector(15 downto 0);
		i_C64_Ack_Ext	: in 	std_logic;
		i_C64_Ack_Int	: in 	std_logic;

		o_C64_I2C_SCL	: out	std_logic;
		o_C64_I2C_SDA	: out	std_logic;
		i_C64_I2C_SDA	: in	std_logic;

		o_C96_I2C_SCL	: out	std_logic;
		o_C96_I2C_SDA	: out	std_logic;
		i_C96_I2C_SDA	: in	std_logic;
		i_eep_i2c_acpt	: in	std_logic := H;
		o_eep_i2c_req	: out	std_logic
	);

end C64Mas_Wrap;

--------------------------------------------------------------------------------
architecture impl of C64Mas_Wrap is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	--                                              Typ=C96     Rev
	constant g_C96_Rev	: std_logic_vector(31 downto 0) := x"0100" & x"0100";

--------------------------------------------------------------------------------
	signal ByteAdr		: std_logic_vector(15 downto 0);	-- dummy
	signal Rx_BRAM_EN	: std_logic;

	signal MEM_RdDat_B : std_logic_vector(31 downto 0);

--------------------------------------------------------------------------------
	signal RxPPCRdData	: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	signal MEM_RdData 	: std_logic_vector(31 downto 0);
	signal MEM_WrData 	: std_logic_vector(31 downto 0);
	signal MEM_ByteAddr	: std_logic_vector(15 downto 0);
	signal MEM_WR		: std_logic_vector( 3 downto 0);
	signal MEM_EN		: std_logic;
--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	signal ICU_RdData		: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	signal ICU_IRQs_Inp		: std_logic_vector(31 downto 0) := (others => '0');
	signal ICU_EN			: std_logic;

	signal PgIRQs			: std_logic_vector( 7 downto 0);
	signal Overrun			: std_logic;

--------------------------------------------------------------------------------
	constant BRAM_Init : tSLV_Nx32(0 to 1023) := (
		448/4 => g_C96_Rev,  	-- 0x1C0    GAL_Revision
		768/4 => x"90000C35",  	-- 0x300	start 8kHz 40ns Timer, dis OverRun
		796/4 => x"11090080",  	-- 0x31C    read C96-EEP
		others => (others => '0')
	);

	type t_out_select is (rxram,icu);
	signal out_select_p			: t_out_select := rxram;
	signal out_select_r			: t_out_select := rxram;
	signal out_select			: t_out_select := rxram;
--------------------------------------------------------------------------------

begin

--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	ICU_IRQs_Inp <= b"0000_0000_0000_0000_0000_000" & Overrun & PgIRQs;

	uWrap_ICU: entity gin_link.Gin_ICU
	generic map (
		--g_OUTREG_A => g_OUTREG_A,
		g64_n32BitRam => g64_n32BitRam,
		C_SECOND_ICU => 1
	)
	port MAP(
		i_ICU_Clk	=>	i_BRAM_Clk  	,	-- liegt im BRAM AdrRaum
		i_ICU_EN	=>	ICU_EN			,
		i_WR 		=>	i_BRAM_WEN		,
		i_addr		=>	ByteAdr(2)		,	-- for 32Bit Read
		i_addr_tim	=> 	ByteAdr(3)		,	-- read IRQ-Timer
		i_addr_2nd	=> 	ByteAdr(4)		,
		i_Din		=>	i_BRAM_Dout		,
		o_Dout		=>	ICU_RdData  	,
		i_IRQs		=>  ICU_IRQs_Inp	,
		o_IRQs		=>  o_IRQs
	);

--------------------------------------------------------------------------------
--	Dualport Adr
--------------------------------------------------------------------------------
--	side A	PowerPC
--	side B	GinPSlave-Sequencer
--------------------------------------------------------------------------------
	----------------------------------------------------------------------------
	--	PPC-Side
	----------------------------------------------------------------------------
	-- PPC-Side C64Mas / ICU Block Multiplexer ---------------------------------
	process (ByteAdr,i_BRAM_EN,RxPPCRdData,ICU_RdData,i_BRAM_Addr,out_select) begin
		if g64_n32BitRam=1 then
			ByteAdr <= "0" & i_BRAM_Addr(11 downto 0) & "000";
		else
			ByteAdr <= "0" & i_BRAM_Addr(12 downto 0) & "00";
		end if;

		Rx_BRAM_EN	<= L;
		ICU_EN		<= L;

		if (ByteAdr < x"4000") then		-- ..0x4000	Rx
			Rx_BRAM_EN <= i_BRAM_EN;
			--o_BRAM_Din <= RxPPCRdData;
		else
			ICU_EN		<= i_BRAM_EN;			-- 			select IRQcontroller
			--o_BRAM_Din	<= ICU_RdData;			-- 			rd IRQ controller
		end if;

		case out_select is
		when icu => o_BRAM_Din <= ICU_RdData;
		when rxram => o_BRAM_Din <= RxPPCRdData;
		end case;

	end process;

--	outreg_en: if g_OUTREG_A=1 generate
--		out_select <= out_select_p;
--	end generate outreg_en;

--	outreg_dis: if g_OUTREG_A=0 generate
		out_select <= out_select_r;
--	end generate outreg_dis;

	process (i_BRAM_Clk) begin
		if rising_edge(i_BRAM_Clk) then
			if Rx_BRAM_EN=H then
				out_select_r <= rxram;
			elsif ICU_EN=H then
				out_select_r <= icu;
			end if;
			out_select_p <= out_select_r;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Dualport Ram
--------------------------------------------------------------------------------
	dpr64:if (g64_n32BitRam = 1) generate begin
		uWarp_BRAM: entity BRAM.BRAM_4kByte_A64_B32
		generic map (
			BRAM_Init		=> BRAM_Init
		)
		PORT MAP(
			i_BRAM_Clk_A  => i_BRAM_Clk  			,
			i_BRAM_EN_A   => Rx_BRAM_EN				,
			i_BRAM_WEN_A  => i_BRAM_WEN  			,
			i_BRAM_Addr_A => i_BRAM_Addr(8 downto 0),
			i_BRAM_Dout_A => i_BRAM_Dout 			,
			o_BRAM_Din_A  => RxPPCRdData  			,

			i_BRAM_Clk_B  => i_Q125  	 			,
			i_BRAM_EN_B   => MEM_EN  				,
			i_BRAM_WEN_B  => MEM_WR		 			,
			i_BRAM_Addr_B => MEM_ByteAddr(11 downto 2),
			i_BRAM_Dout_B => MEM_WrData				,
			o_BRAM_Din_B  => MEM_RdDat_B
		);
	end generate dpr64;

	dpr32:if (g64_n32BitRam = 0) generate begin
		uWarp_BRAM: entity BRAM.BRAM_4kByte_A32_B32
		generic map (
			BRAM_Init		=> BRAM_Init
		)
		PORT MAP(
			i_BRAM_Clk_A  => i_BRAM_Clk  			,
			i_BRAM_EN_A   => Rx_BRAM_EN				,
			i_BRAM_WEN_A  => i_BRAM_WEN  			,
			i_BRAM_Addr_A => i_BRAM_Addr(9 downto 0),
			i_BRAM_Dout_A => i_BRAM_Dout 			,
			o_BRAM_Din_A  => RxPPCRdData  			,

			i_BRAM_Clk_B  => i_Q125  	 			,
			i_BRAM_EN_B   => MEM_EN  				,
			i_BRAM_WEN_B  => MEM_WR		 			,
			i_BRAM_Addr_B => MEM_ByteAddr(11 downto 2),
			i_BRAM_Dout_B => MEM_WrData				,
			o_BRAM_Din_B  => MEM_RdDat_B
		);
	end generate dpr32;
	-- for timing simulate only
	MEM_RdData <= MEM_RdDat_B after 105 ps; -- delay for sim

--------------------------------------------------------------------------------
--	C64_Master Sequencer
--------------------------------------------------------------------------------
	uWrap_C64MasSeq: entity C64_Master.C64_MasSeq
	generic map (
		g_Extern_Q25 	=> g_Extern_Q25			,
		-- GinLink Auto-Soft-Synch
		g_GL_ASoSy		=> g_GL_ASoSy			,
		-- show GinLink-TlgTime
		g_GL_TlgTime	=> g_GL_TlgTime,
		g_CRCChecker	=> g_CRCChecker,
		g_MEM_RdD_REG	=> g_MEM_RdD_REG
	)
	PORT MAP(
		i_Q125 			=> i_Q125				,
		i_Q25 			=> i_Q25				,
		i_TlgIrq		=> i_TlgIrq				,
		o_PgIRQs		=> PgIRQs				,
		i_GinLink_Wdog	=> i_GinLink_Wdog		,

		i_MEM_RdData	=> MEM_RdData			,
		o_MEM_WrData	=> MEM_WrData			,
		o_MEM_ByteAddr	=> MEM_ByteAddr			,
		o_MEM_WR		=> MEM_WR				,
		o_MEM_EN		=> MEM_EN				,
		-- synchronous clocking for internal slaves
		o_C64_CLK_EN	=> o_C64_CLK_EN,
		-- C64-Bus
		o_C64_Reset		=> o_C64_Reset 			,
		o_C64_CLK		=> o_C64_CLK 			,
		o_C64_CLK_fe	=> o_C64_CLK_fe			,
		o_C64_CLK_re	=> o_C64_CLK_re			,
		o_C64_SEL		=> o_C64_SEL    		,
		o_C64_RES		=> o_C64_RES			,
		o_C64_Dat_HOE	=> o_C64_Dat_HOE 		,
		o_C64_Dat_LOE	=> o_C64_Dat_LOE 		,
		o_C64_Ack_OE	=> o_C64_Ack_OE 		,
		o_C64_Bend		=> o_C64_Bend   		,
		o_C64_WrDat		=> o_C64_WrDat			,
		i_C64_RdDat		=> i_C64_RdDat			,
		i_C64_Ack_Ext	=> i_C64_Ack_Ext		,
		i_C64_Ack_Int	=> i_C64_Ack_Int		,

		o_C64_I2C_SCL	=> o_C64_I2C_SCL		,
		o_C64_I2C_SDA	=> o_C64_I2C_SDA		,
		i_C64_I2C_SDA	=> i_C64_I2C_SDA		,
		o_C96_I2C_SCL	=> o_C96_I2C_SCL		,
		o_C96_I2C_SDA	=> o_C96_I2C_SDA		,
		i_C96_I2C_SDA	=> i_C96_I2C_SDA		,
		i_eep_i2c_acpt	=> i_eep_i2c_acpt		,	
        o_eep_i2c_req	=> o_eep_i2c_req		,
		o_Overrun		=> Overrun
	);

--------------------------------------------------------------------------------
end;
