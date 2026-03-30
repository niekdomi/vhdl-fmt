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
--  	- Dieser Wrapper wird benötigt, wenn der C64-MAS in einem
--        Vitrex-4 mit PPC läuft (enthält das dazu notwendige BRAM)
--      - Auch bei der 3-PORT Version wird dieses BRAM zum PPC benötigt
--        und das Second-Port macht die Verbindung zum GinSlave-SP-BRAM
--
--      - Im Spartan-6 Pasive-Master wird direkt ans GinSlave-BRAM
--        angekoppelt und daher brauchts diesen Wrapper dann nicht.
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
--	19.06.2012-FB	TwoPort: first port for PPC, second connected with Gin-Slave BRAM
--	25.11.2012-FB	new g_NO_SPI,g_NO_JTAG,g_NO_EEPROM to reduce LUTs for ActMaster
--	16.05.2014-le	- 8k/3portram: adjustments ans support for cop-mas2 
--	29.06.2015-le	- add ports and generics for crc check
--	26.05.2016-le	- add a second irq with own mask and timer for fast irq
--	09.02.2017-le	- add new command for jumping to a subtabel
--	09.02.2017-le	- remove job logger
--	09.02.2017-le	- add i_8k3p_Enable to enable/disable 3port and 8k feature (rev>=0x210).
--	16.11.2017-le	- cop-master: never Rev >210 on GinMaster. this leads to a sw error
--	25.06.2019-vz	- add generic to patch eeprom address
--	25.06.2019-le:	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--	12.06.2020-vz	- add handshake signal to/from C64_EEPROMER to share i2c bus with another i2c master
--					  used in cv_sodimm_max4x10 
--------------------------------------------------------------------------------
--$Rev:: 2580                                                                  $
--$Author:: Administrator                                                      $
--$Date:: 2012-12-12 13:01:41 +0100 (Mi, 12 Dez 2012)                          $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	3-Port RAM: 	FP = First Port ; SP = Second Port
--------------------------------------------------------------------------------
--
--
-- ------------------------in GS_WRAP   |  in C64_MAS_WRAP----------------------
--
--          72000000 +------+ 72000000      74000000 +------+
-- GL_wr >-->+------>|      |                        |      |<------+<--< C64_wr
--           :       | BRAM |<==64===> PPC  <===64==>| BRAM |       :
--           :   +--<|      |       FP      FP       |      |>--+   :
--           :  SW   +------+                        +------+   SW  :
--           :   :                                              :   :
--             +--+                                            +--+
-- GL_rd <-----|OR|                                            |OR|-----> C64_rd
--             +--+                                            +--+
--           :   :                                              :   :
--           :   :   +------+                                   :   :
--           :   +--<|      |>------->------>-------------------+   :
--           :       | BRAM |       SP      SP                      :
--           +------>|      |<-------<------<-----------------------+
--                   +------+
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
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
entity C64Mas_8k_Wrap is
	generic (
		-- second port directly connected with GinLink
		g_SecondPort	: in	natural range 0 to 1 := 0;
		g_GIN_MASTERnSLAVE : in	natural range 0 to 1 := 0;
		g64_n32BitRam	: in	integer range 0 to 1 := 1;
--not implemented (ram)		g_OUTREG_A		: in integer range 0 to 1 := 0;
		g_Extern_Q25	: in	natural range 0 to 1 := 0;

		g_NO_SPI		: in 	natural range 0 to 1 := 0;
		g_NO_JTAG		: in 	natural range 0 to 1 := 0;
		g_NO_EEPROM		: in 	natural range 0 to 1 := 0;
		-- patch to change eeprom address 
		g_patch_ee_addr	: in	integer range 0 to 1 := 0;
		g_patch_addr_f	: in	std_logic_vector(3 downto 0) := x"0"; -- from
		g_patch_addr_t	: in	std_logic_vector(3 downto 0) := x"0"; -- to
		g_CRCChecker	: in integer range 0 to 1 := 0;
		g_SELECTnOR_MEM : in integer range 0 to 1 := 0;
		g_MEM_RdD_REG : in integer range 0 to 1 := 0
	);
	port (
		i_Q125			: in 	std_logic;
		i_Q25		 	: in 	std_logic := L;
		--i_Q125en		: in 	std_logic := H;
		i_TlgIrq		: in 	std_logic_vector( 7 downto 0) := x"00";
		o_IRQs			: out 	std_logic_vector( 1 downto 0);
		i_GinLink_Wdog  : in	std_logic := L;

		-- first port, PPC_74000000 to C64_MAS
		i_FP_Clk 		: in 	std_logic;
		i_FP_EN 		: in 	std_logic;
		i_FP_WEN 		: in 	std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_FP_Addr 		: in 	std_logic_vector(15 downto 0);
		i_FP_WrData 	: in 	std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_FP_RdData		: out	std_logic_vector(31 + g64_n32BitRam*32 downto 0);

		-- second port, GinLink to C64_MAS
		i_SP_RdData	    : in 	std_logic_vector(31 downto 0)	:= (others => '0');
		o_SP_WrData	    : out	std_logic_vector(31 downto 0);
		o_SP_Addr		: out	std_logic_vector(15 downto 0);
		o_SP_WR		    : out	std_logic_vector( 3 downto 0);
		o_SP_EN		    : out	std_logic;

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
		o_eep_i2c_req	: out	std_logic;
		
		i_8k3p_Enable	: in  std_logic
	);

end C64Mas_8k_Wrap;
--------------------------------------------------------------------------------
architecture impl of C64Mas_8k_Wrap is
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------$
	signal ByteAdr		: std_logic_vector(15 downto 0);	-- dummy
	signal FP_EN			: std_logic;
	signal FP_Addr_A		: std_logic_vector(10 downto 0);
	signal FP_RdData		: std_logic_vector(i_FP_WrData'range);
--------------------------------------------------------------------------------
	signal MEM_RdDat_B 		: std_logic_vector(31 downto 0);
	signal MEM_RdData 		: std_logic_vector(31 downto 0);
	signal MEM_WrData 		: std_logic_vector(31 downto 0);
	signal MEM_ByteAddr		: std_logic_vector(15 downto 0);
	signal MEM_32Addr		: std_logic_vector(10 downto 0);
	signal MEM_WR			: std_logic_vector( 3 downto 0);
	signal MEM_EN			: std_logic;
--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
	signal ICU_RdData		: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	signal ICU_IRQs_Inp		: std_logic_vector(31 downto 0) := (others => '0');
	signal ICU_EN			: std_logic;

	signal PgIRQs			: std_logic_vector( 7 downto 0);
	signal Overrun			: std_logic;

--------------------------------------------------------------------------------
	-- !!!! raminit is not in all FPGAs suportet !!!!
	-- !!! never >210 on GinMaster !!!
	function get_init_str(input : integer) return string is
	begin
		case input is
		when 0 =>
			return "..\C64_Master\COP_8k.mif";
		when 1 =>
			return "..\C64_Master\COP_8k_GM.mif";
		when others =>
			assert 1<0
			report "unsupported input" severity error;
			return "0000";
		end case;
	end get_init_str;
	
	constant INIFile : string := get_init_str(g_GIN_MASTERnSLAVE);
	
	constant GAL_Revision : tSLV_Nx32(0 to 1) := (x"0000_0210",x"0000_0202");
	constant FP_Init : tSLV_Nx32(0 to 2047) := (
--		448/4 => x"8200_0200",  	-- 0x1C0	Typ 8K, GS & COP ; GAL_Revision
		16#1C0# /4 => GAL_Revision(g_GIN_MASTERnSLAVE),  	-- 0x1C0	Typ 8K, GS & COP ; GAL_Revision !!! leading 0x8200 set by sw!!!
		-- EEPROM-Read will be done by PPC
	 	others => (others => '0')
	 );

--dbg jlog	type t_out_select is (rxram,icu,logram);
	type t_out_select is (rxram,icu);
	signal out_select_p			: t_out_select := rxram;
	signal out_select_r			: t_out_select := rxram;
	signal out_select			: t_out_select := rxram;
	
--dbg jlog	signal log_addr : std_logic_vector(9 downto 0);
--dbg jlog	signal logout : std_logic_vector(31 downto 0);
--dbg jlog	signal log_den : std_logic_vector(3 downto 0);
--dbg jlog	
--dbg jlog	signal log_EN			: std_logic;
--dbg jlog	signal log_RdData		: std_logic_vector(i_FP_WrData'range);
--------------------------------------------------------------------------------

begin

--------------------------------------------------------------------------------
--	second port (will by connected to GinSlave BRAM)
--------------------------------------------------------------------------------
	o_SP_WrData		<= MEM_WrData;
	o_SP_Addr		<= "00" & MEM_ByteAddr(15 downto 2);	--32Bit Addr
	o_SP_WR			<= MEM_WR;

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
		i_ICU_Clk	=>	i_FP_Clk  	,	-- liegt im BRAM AdrRaum
		i_ICU_EN	=>	ICU_EN			,
		i_WR 		=>	i_FP_WEN		,
		i_addr		=>	ByteAdr(2)		,	-- for 32Bit Read
		i_addr_tim	=> 	ByteAdr(3)		,	-- read IRQ-Timer
		i_addr_2nd	=> 	ByteAdr(4)		,
		i_Din		=>	i_FP_WrData	,
		o_Dout		=>	ICU_RdData  	,
		i_IRQs		=>  ICU_IRQs_Inp	,
		o_IRQs		=>  o_IRQs
	);

--------------------------------------------------------------------------------
--	PPC-Dualport-Ram		FP_8kByte_A64_B32
-- 	Dieses BRAM verbindet immer nur den COP_Master zum lokalen PPC
-- 	Die ganzen GinLink-Bereiche bleiben also leer
--------------------------------------------------------------------------------
--	0000..007F		                          		System-EEPROM
-- 	0080..017F		COP_Module EEPROM,SPI,JTG
-- 	0180..1FFF		                          		GinLink stuff
--	0200..02FF		                          		GinLink PgAddrComp
-- 	0300..031F		COP_MAster Command
-- 	0320..07FF		COP_MasterTab
-- 	0800..0FFF		COP_Master Rx             		GinLink TxBuf
--	4000..4007		                          		ICU
-- 	8000..87FF		COP_Master Tx             		GinLink RxBuf-0
-- (8800..8FFF)		                          		GinLink RxBuf-1
--------------------------------------------------------------------------------
--	64BitAdr		A1	0010		A5	0100		A9	1000
--					A2	0020		A6	0200		A10	2000
--					A3	0040		A7	0400		A11	4000
--	A0	0008		A4	0080		A8	0800        A12 8000
--------------------------------------------------------------------------------
	-- select RxArea with 8000
	--FP_Addr_A <= i_FP_Addr(12) & i_FP_Addr(8 downto 0);	-- 64Bit Addr
--------------------------------------------------------------------------------
	----------------------------------------------------------------------------
	--	PPC-Side
	----------------------------------------------------------------------------
	-- PPC-Side C64Mas / ICU Block Multiplexer ---------------------------------
	process (ByteAdr,i_FP_Addr,i_FP_EN,FP_RdData,ICU_RdData,out_select) begin
		if g64_n32BitRam=1 then
			ByteAdr <= "0" & i_FP_Addr(11 downto 0) & "000";
			FP_Addr_A <= "0" & i_FP_Addr(12) & i_FP_Addr(8 downto 0);
		else
			ByteAdr <= "0" & i_FP_Addr(12 downto 0) & "00";
			FP_Addr_A <= i_FP_Addr(13) & i_FP_Addr(9 downto 0);
		end if;

		FP_EN	<= L;
		ICU_EN		<= L;
--dbg jlog		log_en <= L;

		if (ByteAdr(15 downto 12) = x"4") then
			ICU_EN			<= i_FP_EN;		-- select IRQcontroller
			--o_FP_RdData	<= ICU_RdData;		-- rd IRQ controller
--dbg jlog		elsif (ByteAdr(15 downto 12) = x"3") then
--dbg jlog			log_en <= i_FP_EN;
		else
			FP_EN		<= i_FP_EN;
			--o_FP_RdData 	<= FP_RdData;
		end if;

		case out_select is
		when icu => o_FP_RdData <= ICU_RdData;
		when rxram => o_FP_RdData <= FP_RdData;
--dbg jlog		when logram => o_FP_RdData <= log_RdData;
		end case;

	end process;

--	outreg_en: if g_OUTREG_A=1 generate
--		out_select <= out_select_p;
--	end generate outreg_en;

--	outreg_dis: if g_OUTREG_A=0 generate
		out_select <= out_select_r;
--	end generate outreg_dis;

	process (i_FP_Clk) begin
		if rising_edge(i_FP_Clk) then
			if FP_EN=H then
				out_select_r <= rxram;
			elsif ICU_EN=H then
				out_select_r <= icu;
--dbg jlog			elsif log_EN=H then
--dbg jlog				out_select_r <= logram;
			end if;
			out_select_p <= out_select_r;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Dualport Ram
--------------------------------------------------------------------------------
	MEM_32Addr <= MEM_ByteAddr(15) & MEM_ByteAddr(11 downto 2);
	dpr64:if (g64_n32BitRam = 1) generate begin
		uWarp_C64BRAM: entity BRAM.BRAM_8kByte_A64_B32
		generic map (
			BRAM_Init		=> FP_Init
		)
		PORT MAP(
			i_BRAM_Clk_A  	=> i_FP_Clk  			,
			i_BRAM_EN_A   	=> FP_EN				,
			i_BRAM_WEN_A  	=> i_FP_WEN  			,
			i_BRAM_Addr_A 	=> FP_Addr_A(9 downto 0),
			i_BRAM_WrData_A => i_FP_WrData 			,
			o_BRAM_RdData_A => FP_RdData  			,
	
			i_BRAM_Clk_B  	=> i_Q125  	 			,
			i_BRAM_EN_B   	=> MEM_EN	  			,
			i_BRAM_WEN_B  	=> MEM_WR		 		,
			i_BRAM_Addr_B 	=> MEM_32Addr			,
			i_BRAM_WrData_B => MEM_WrData			,
			o_BRAM_RdData_B => MEM_RdDat_B
		);
	end generate dpr64;

	dpr32:if (g64_n32BitRam = 0) generate begin
		uWarp_C64BRAM: entity BRAM.BRAM_8kByte_A32_B32
		generic map (
			BRAM_Init		=> FP_Init,
			g_INIT_FILE		=> INIFile
		)
		PORT MAP(
			i_BRAM_Clk_A  	=> i_FP_Clk  			,
			i_BRAM_EN_A   	=> FP_EN				,
			i_BRAM_WEN_A  	=> i_FP_WEN  			,
			i_BRAM_Addr_A 	=> FP_Addr_A(10 downto 0),
			i_BRAM_Dout_A => i_FP_WrData 			,
			o_BRAM_Din_A => FP_RdData  				,
	
			i_BRAM_Clk_B  	=> i_Q125  	 			,
			i_BRAM_EN_B   	=> MEM_EN	  			,
			i_BRAM_WEN_B  	=> MEM_WR		 		,
			i_BRAM_Addr_B 	=> MEM_32Addr			,
			i_BRAM_Dout_B => MEM_WrData				,
			o_BRAM_Din_B  => MEM_RdDat_B
		);
--dbg jlog		
--dbg jlog		uWarp_logBRAM: entity BRAM.BRAM_4kByte_A32_B32
--dbg jlog		PORT MAP(
--dbg jlog			i_BRAM_Clk_A  	=> i_FP_Clk  			,
--dbg jlog			i_BRAM_EN_A   	=> log_EN				,
--dbg jlog			i_BRAM_WEN_A  	=> i_FP_WEN  			,
--dbg jlog			i_BRAM_Addr_A 	=> FP_Addr_A(9 downto 0),
--dbg jlog			i_BRAM_Dout_A => i_FP_WrData 			,
--dbg jlog			o_BRAM_Din_A => log_RdData  			,
--dbg jlog	
--dbg jlog			i_BRAM_Clk_B  	=> i_Q125  	 			,
--dbg jlog			i_BRAM_EN_B   	=> H	  			,
--dbg jlog			i_BRAM_WEN_B  	=> log_den		 		,
--dbg jlog			i_BRAM_Addr_B 	=> log_addr			,
--dbg jlog			i_BRAM_Dout_B => logout				,
--dbg jlog			o_BRAM_Din_B  => open
--dbg jlog		);
--dbg jlog		log_den(1) <= log_den(0);
--dbg jlog		log_den(2) <= log_den(0);
--dbg jlog		log_den(3) <= log_den(0);
	end generate dpr32;
	-- for timing simulate only
	MEM_RdData <= MEM_RdDat_B after 105 ps; -- delay for sim

--------------------------------------------------------------------------------
--	C64_Master Sequencer
--------------------------------------------------------------------------------
	uWrap_C64MasSeq: entity C64_Master.C64_MasSeq
	generic map (
		g_Extern_Q25 	=> g_Extern_Q25        	,
		-- first and second-port data-OR
		g_TwoPort_OR	=> g_SecondPort			,
		g_NO_SPI		=> g_NO_SPI		        ,
		g_NO_JTAG		=> g_NO_JTAG		    ,
		g_NO_EEPROM		=> g_NO_EEPROM			,
		g_patch_ee_addr	=> g_patch_ee_addr		,
		g_patch_addr_f	=> g_patch_addr_f		,	
		g_patch_addr_t	=> g_patch_addr_t		,	
		g_CRCChecker	=> g_CRCChecker			,
		g_SELECTnOR_MEM => g_SELECTnOR_MEM,
		g_MEM_RdD_REG	=> g_MEM_RdD_REG
	)
	PORT MAP(
		i_Q125 			=> i_Q125				,
		i_Q25 			=> i_Q25				,
		i_TlgIrq		=> i_TlgIrq				,
		o_PgIRQs		=> PgIRQs				,
		i_GinLink_Wdog	=> i_GinLink_Wdog		,

		-- first port
		i_MEM_RdData	=> MEM_RdData			,
		o_MEM_WrData	=> MEM_WrData			,
		o_MEM_ByteAddr	=> MEM_ByteAddr			,
		o_MEM_WR		=> MEM_WR				,
		o_MEM_EN		=> MEM_EN				,
		-- second port
		o_SP_EN			=> o_SP_EN				,
		i_SP_RdData		=> i_SP_RdData			,
		-- synchronous clocking for internal slaves
		o_C64_CLK_EN	=> o_C64_CLK_EN,
		-- C64-Bus
		o_C64_Reset		=> o_C64_Reset 			,
		o_C64_CLK		=> o_C64_CLK 			,
		o_C64_CLK_fe	=> o_C64_CLK_fe			,
		o_C64_CLK_re	=> o_C64_CLK_re			,
		o_C64_SEL		=> o_C64_SEL    		,
		o_C64_RES		=> o_C64_RES    		,
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
		o_Overrun		=> Overrun				,
		i_8k3p_Enable	=> i_8k3p_Enable--dbg jlog,
--dbg jlog		o_log_addr => log_addr, 
--dbg jlog		o_logout => logout,
--dbg jlog		o_log_en => log_den(0)
	);

--------------------------------------------------------------------------------
end;
