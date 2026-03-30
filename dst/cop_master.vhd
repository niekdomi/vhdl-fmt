--------------------------------------------------------------------------------
--	cop_master.vhd
--------------------------------------------------------------------------------
--
--	project     : cop_master
--	programmer  : C. Leuthold, INDEL AG
--	date        : 29.08.2013
--	language    : VHDL
--
--	purpose
--
--------------------------------------------------------------------------------
-- revision information
--	29.08.2013-le	- first steps
--	15.01.2014-le	- add ddr output ffs for 50/50 clk
--	28.04.2014-le	- add JTAG pins
--	16.05.2014-le	- 8k/3portram: adjustments ans support for cop-mas2
--	29.06.2015-le	- add ports and generics for crc check
--	26.05.2016-le	- add a second irq with own mask and timer for fast irq
--	27.06.2016-le	- hold C64_WrDat for a clk, intern C64_Dat_HOE is faster then extern oe!
--	04.07.2016-le	- correct order of C64_WrDat mux
--	05.12.2016-le	- add JTAG and SPI on C64Mas_8k_Wrap
--	22.12.2016-le	- need generic C_GIN_MASTERnSLAVE together with C_ENABLE_3PORT_MASTER=1
--					  disabel g_SecondPort on gin-masters.
--	16.11.2017-le	- cop-master: never Rev >210 on GinMaster. this leads to a sw error
--	25.06.2019-le	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--	10.06.2020-vz	- all i2c tristate buffers removed, these should always be created on top-level
--	12.06.2020-vz	- add handshake signal to/from C64_EEPROMER to share i2c bus with another i2c master
--					  used in cv_sodimm_max4x10
--	23.06.2020-le	- adjustments for the cop-mas2 NadAp Project (DF_TESTMODE=1)
--	02.07.2020-le	- adjustments for the cop-mas2 NadAp Project (DF_TESTMODE=1)
--	13.08.2020-le	- adjustments for the cop-mas2 NadAp Project (DF_TESTMODE=1)
--------------------------------------------------------------------------------
--$Rev:: 1965                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2020-08-13 17:11:48 +0200 (Do., 13 Aug 2020)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library C64_Master;
use C64_Master.All;

library C64_Slave;
use C64_Slave.All;

--------------------------------------------------------------------------------
-- Entity section
--------------------------------------------------------------------------------
entity cop_master is
	generic (
		C_REVISION		: std_logic_vector(11 downto 0) := x"000";
		C_DEV_BUILD		: integer := 1;-- 0 for releases
		DF_TESTMODE		: in integer range 0 to 1 := 0;
		C_EMG_SYS		: in integer range 0 to 1 := 0;
		g64_n32BitRam	: in integer range 0 to 1 := 1;
		g_Extern_Q25	: in	natural range 0 to 1 := 0;
		-- patch to change eeprom address 
		g_patch_ee_addr	: in	integer range 0 to 1 := 0;
		g_patch_addr_f	: in	std_logic_vector(3 downto 0) := x"0"; -- from
		g_patch_addr_t	: in	std_logic_vector(3 downto 0) := x"0"; -- to
		C_ENABLE_3PORT_MASTER : in	natural range 0 to 1 := 0;
		C_GIN_MASTERnSLAVE : in	natural range 0 to 1 := 0;
		g_CRCChecker	: in integer range 0 to 1 := 0;
		g_MEM_RdD_REG : in integer range 0 to 1 := 0
	);
	port (
		i_Q125			: in	std_logic;
		i_Q25			: in	std_logic := L;
		i_TlgIrq		: in	std_logic_vector( 7 downto 0) := x"00";
		i_GinLink_Wdog  : in	std_logic := L;
		o_IRQs			: out	std_logic_vector(1 downto 0);
		
		i_BRAM_Clk		: in	std_logic;
		i_BRAM_EN		: in	std_logic;
		i_BRAM_WEN		: in	std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		
		i_BRAM_Addr		: in	std_logic_vector(15 downto 0);
		i_BRAM_Dp2r		: in	std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_BRAM_Dr2p		: out	std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		
		o_SP_EN			: out	std_logic;
		o_SP_WEN		: out	std_logic_vector( 3 downto 0);
		o_SP_Addr		: out	std_logic_vector(15 downto 0);
		o_SP_Dc2g		: out	std_logic_vector(31 downto 0);
		i_SP_Dg2c		: in	std_logic_vector(31 downto 0) := (others => L);
		
		o_C64_Reset		: out	std_logic;
		o_C64_CLK		: out	std_logic;
		no_C64_CLK		: out	std_logic;
		o_C64_SEL		: out	std_logic;
		o_C64_Bend		: out	std_logic;
		b_C64_Data		: inout	std_logic_vector(15 downto 0) := (others => L);
		nb_C64_Ack		: inout	std_logic := H;
		o_C64_res		: out	std_logic;
		
		o_C64_I2C_SCL	: out	std_logic;
		i_C64_I2C_SDA	: in	std_logic := H;
		o_C64_I2C_SDA	: out	std_logic;
		
		o_C96_I2C_SCL	: out	std_logic;
		i_C96_I2C_SDA	: in	std_logic := H;
		o_C96_I2C_SDA	: out	std_logic;
		
		i_eep_i2c_acpt	: in	std_logic := H;
		o_eep_i2c_req	: out	std_logic;
		
		i_TestModeOE	: in std_logic := L;
		
		no_OkLED		: out	std_logic;
		i_HWRev			: in	std_logic_vector(3 downto 0);
		i_AddrSw		: in	std_logic_vector(3 downto 0);
		
		 o_SPI_CLK		: out	std_logic;
		no_SPI_CS		: out	std_logic;
		 o_SPI_D		: out	std_logic;
		 i_SPI_Q		: in 	std_logic := '0';
		 
		b_jtagTCK		: inout	std_logic := L;
		b_jtagTMS		: inout	std_logic := L;
		b_jtagTDI		: inout	std_logic := L;
		b_jtagTDO		: inout	std_logic := L;
		
		i_SlvInt_Ack_OE		: in std_logic := L;
		i_SlvInt_Slv2Mas	: in std_logic_vector(15 downto 0) := (others => L);
		i_SlvInt_Dat_HOE	: in std_logic := L;
		i_SlvInt_Dat_LOE	: in std_logic := L;
		o_SlvInt_Mas2Slv	: out std_logic_vector(15 downto 0);
		o_SlvInt_Reset		: out std_logic;
		o_SlvInt_CLK		: out std_logic;
		o_SlvInt_ClkEn		: out std_logic;
		o_SlvInt_SEL		: out std_logic;
		o_SlvInt_Bend		: out std_logic;
		
		i_8k3p_Enable		: in std_logic
	);
end entity cop_master;

architecture rtl of cop_master is
	--signal net_gnd : std_logic := L;
	signal net_vcc : std_logic := H;

	signal C64_CLK_EN		: std_logic;
	signal C64_Reset		: std_logic;
	signal C64_CLK			: std_logic;
	signal C64_CLK_fe		: std_logic;
	signal C64_CLK_re		: std_logic;
	signal C64_nCLK			: std_logic;
	signal C64_SEL			: std_logic;
	signal C64_Bend			: std_logic;
	signal C64_res			: std_logic;
	signal C64_Ack_Ext		: std_logic;
	signal C64_Ack_Int		: std_logic;
	signal C64_Ack_OE		: std_logic;
	signal C64_WrDat		: std_logic_vector(15 downto 0);
	signal C64_RdDat		: std_logic_vector(15 downto 0);
	signal C64_Dat_HOE		: std_logic;
	signal C64_Dat_LOE		: std_logic;
	
	signal IntSlvAck		: std_logic;
	signal IntSlvAck_n1		: std_logic;
	----------------------------------------------------------------------------
	-- local Cop Slave #9
	----------------------------------------------------------------------------
	constant DF_TYP : tSLV_Nx8(0 to 1) := (x"F1", x"EE");-- typ(std, emg)
	constant g_SlaveApp_Rev	: std_logic_vector(15 downto 0) := DF_TYP(C_EMG_SYS) & ( C_REVISION(7 downto 0) + DF_TESTMODE*128+ DF_TESTMODE*32);	-- typ,vers
----------------------------------------------------------------------------  

	signal Slv_GF_Flags		: std_logic_vector(15 downto 0) := (others => '0');
	signal Card_Rd_Status	: std_logic_vector(11 downto 0);
	signal Card_Wr_Status	: std_logic_vector(15 downto 0);

	-- slave Rd/Wr
	--signal Slv_Q25			: std_logic;
	signal Slv_Addr			: std_logic_vector( 7 downto 0);
	signal Slv_RdData		: std_logic_vector(15 downto 0);
	signal Slv_WrData		: std_logic_vector(15 downto 0);
	signal Slv_WrEn			: std_logic;
	signal Slv_RdEn			: std_logic;

	----------------------------------------------------------------------------
	-- Slave #9 bus-signals
	----------------------------------------------------------------------------
	signal Slv9_C64_Ack_OE	: std_logic;
	signal Slv9_C64_WrDat	: std_logic_vector(15 downto 0);
	signal Slv9_C64_Dat_HOE	: std_logic;
	signal Slv9_C64_Dat_LOE	: std_logic;
	
	signal clk_reset		: std_logic := L;
	
	signal Slv9_Testmode	: std_logic_vector(15 downto 0);
	constant cfg_TestMode	: std_logic_vector := x"F0";
	
	function invers_int_bool(input : integer) return integer is
	begin
		if input=0 then
			return 1;
		elsif input=1 then
			return 0;
		else
			assert 1<0
			report "unsupported input" severity error;
			return -1;
		end if;
	end invers_int_bool;
	
begin
	----------------------------------------------------------------------------
	-- cop_master
	----------------------------------------------------------------------------
	g_2port_mas : if (C_ENABLE_3PORT_MASTER = 0) generate
		uWrap_C64MasSeq: entity C64_Master.C64Mas_Wrap
		generic map (
			g64_n32BitRam	=> g64_n32BitRam,
			g_Extern_Q25 => g_Extern_Q25,
			g_CRCChecker => g_CRCChecker,
			g_MEM_RdD_REG => g_MEM_RdD_REG
		)
		port map (
			i_Q125 			=> i_Q125		,
			i_Q25 			=> i_Q25		,
			i_TlgIrq		=> i_TlgIrq		,	-- clk_dom 62.5 to 125
			i_GinLink_Wdog	=> i_GinLink_Wdog,
			o_IRQs			=> o_IRQs		,
		
			i_BRAM_Clk		=> i_BRAM_Clk	,
			i_BRAM_EN		=> i_BRAM_EN	,
			i_BRAM_WEN		=> i_BRAM_WEN	,
			i_BRAM_Addr		=> i_BRAM_Addr	,
			i_BRAM_Dout		=> i_BRAM_Dp2r	,
			o_BRAM_Din		=> o_BRAM_Dr2p	,
			
			o_C64_CLK_EN	=> C64_CLK_EN,
			-- C64-Bus
			o_C64_Reset		=> C64_Reset	,
			o_C64_CLK		=> C64_CLK		,
			o_C64_CLK_fe	=> C64_CLK_fe	,
			o_C64_CLK_re	=> C64_CLK_re	,
			o_C64_SEL		=> C64_SEL		,
			o_C64_RES		=> C64_RES	,
			o_C64_Dat_HOE	=> C64_Dat_HOE	,
			o_C64_Dat_LOE	=> C64_Dat_LOE	,
			o_C64_Ack_OE	=> C64_Ack_OE	,
			o_C64_Bend		=> C64_Bend		,
			o_C64_WrDat		=> C64_WrDat	,
			i_C64_RdDat		=> C64_RdDat	,
			i_C64_Ack_Ext	=> C64_Ack_Ext	,
			i_C64_Ack_Int	=> C64_Ack_Int	,
			o_C64_I2C_SCL	=> o_C64_I2C_SCL,
			o_C64_I2C_SDA	=> o_C64_I2C_SDA,
			i_C64_I2C_SDA	=> i_C64_I2C_SDA,
			o_C96_I2C_SCL	=> o_C96_I2C_SCL,
			o_C96_I2C_SDA	=> o_C96_I2C_SDA,
			i_C96_I2C_SDA	=> i_C96_I2C_SDA,
			i_eep_i2c_acpt	=> i_eep_i2c_acpt,
			o_eep_i2c_req	=> o_eep_i2c_req
		);
		
		o_SP_EN <= L;
		o_SP_WEN <= (others => '0');
		o_SP_Addr <= (others => '0');
		o_SP_Dc2g <= (others => '0');
		
	end generate g_2port_mas;
	
	g_3port_mas : if (C_ENABLE_3PORT_MASTER = 1) generate
		uWrap_C64MasSeq: entity C64_Master.C64Mas_8k_Wrap
		generic map (
			g64_n32BitRam	=> g64_n32BitRam,
			g_Extern_Q25 => g_Extern_Q25,
			g_SecondPort	=> invers_int_bool(C_GIN_MASTERnSLAVE),	-- generate second port for gin salve
			g_GIN_MASTERnSLAVE => C_GIN_MASTERnSLAVE,
			g_patch_ee_addr	=> g_patch_ee_addr		,
			g_patch_addr_f	=> g_patch_addr_f		,	
			g_patch_addr_t	=> g_patch_addr_t		,	
			g_CRCChecker => g_CRCChecker			,
			g_SELECTnOR_MEM => 1,
			g_MEM_RdD_REG => g_MEM_RdD_REG
		)
		port map (
			i_Q125			=> i_Q125		,
			i_Q25			=> i_Q25		,
			i_TlgIrq		=> i_TlgIrq		,	-- clk_dom 62.5 to 125
			i_GinLink_Wdog	=> i_GinLink_Wdog,
			o_IRQs			=> o_IRQs		,
			
			i_FP_Clk		=> i_BRAM_Clk	,
			i_FP_EN			=> i_BRAM_EN	,
			i_FP_WEN		=> i_BRAM_WEN	,
			i_FP_Addr		=> i_BRAM_Addr	,
			i_FP_WrData		=> i_BRAM_Dp2r	,
			o_FP_RdData		=> o_BRAM_Dr2p	,
			-- second port, connected with Gin-Slave BRAM
			o_SP_EN		    => o_SP_EN		,
			o_SP_WR		    => o_SP_WEN		,
			o_SP_Addr  		=> o_SP_Addr	,
			o_SP_WrData	    => o_SP_Dc2g	,
			i_SP_RdData	    => i_SP_Dg2c	,
			
			o_C64_CLK_EN	=> C64_CLK_EN,
			-- C64-Bus
			o_C64_Reset		=> C64_Reset	,
			o_C64_CLK		=> C64_CLK		,
			o_C64_CLK_fe	=> C64_CLK_fe	,
			o_C64_CLK_re	=> C64_CLK_re	,
			o_C64_SEL		=> C64_SEL		,
			o_C64_RES		=> C64_RES	,
			o_C64_Dat_HOE	=> C64_Dat_HOE	,
			o_C64_Dat_LOE	=> C64_Dat_LOE	,
			o_C64_Ack_OE	=> C64_Ack_OE	,
			o_C64_Bend		=> C64_Bend		,
			o_C64_WrDat		=> C64_WrDat	,
			i_C64_RdDat		=> C64_RdDat	,
			i_C64_Ack_Ext	=> C64_Ack_Ext	,
			i_C64_Ack_Int	=> C64_Ack_Int	,
			o_C64_I2C_SCL	=> o_C64_I2C_SCL,
			o_C64_I2C_SDA	=> o_C64_I2C_SDA,
			i_C64_I2C_SDA	=> i_C64_I2C_SDA,
			o_C96_I2C_SCL	=> o_C96_I2C_SCL,
			o_C96_I2C_SDA	=> o_C96_I2C_SDA,
			i_C96_I2C_SDA	=> i_C96_I2C_SDA,
			i_eep_i2c_acpt	=> i_eep_i2c_acpt,
			o_eep_i2c_req	=> o_eep_i2c_req,
			i_8k3p_Enable	=> i_8k3p_Enable
		);
	end generate g_3port_mas;
		
	----------------------------------------------------------------------------
	--	extern C64-Bus Clock outputs
	----------------------------------------------------------------------------
	--	C64_CLK aus dem C64_Master ist identisch mit dem clock-net i_Q25
	--	Das kann so aber nicht direkt auf ein Pin gefÃ¼hrt werden,
	--	daher mÃ¼ssen zwei ODDR2-FF instanziert werden 
	----------------------------------------------------------------------------
	C64_nCLK <= not C64_CLK;
	sym_ddr_clk: if (g_Extern_Q25 = 0) generate
		COMPONENT RGMII_OUT_CTRL IS
		PORT   (
			aclr                         : IN   std_logic;
			datain_h                     : IN   std_logic;
			datain_l                     : IN   std_logic;
			outclock                     : IN   std_logic;
			dataout                      : OUT  std_logic 
		);
		END COMPONENT RGMII_OUT_CTRL;
		signal C64_nCLK_fe : std_logic;
		signal C64_nCLK_re : std_logic;
	begin
		C64_nCLK_fe <= not C64_CLK_fe;
		C64_nCLK_re <= not C64_CLK_re;
		
		pos_clk: RGMII_OUT_CTRL
		PORT MAP (
			aclr                          => clk_reset,
			datain_h                      => C64_CLK_re,--Router_In(0).Data(8), -- Positive edge TXEN
			datain_l                      => C64_CLK_fe,--Router_In(0).Data(9), -- Negative edge TXEN/TXERR
			outclock                      => i_Q125,--PHY_REG_CLK1_Int,
			dataout                       => o_C64_CLK
		);
		neg_clk: RGMII_OUT_CTRL
		PORT MAP (
			aclr                          => clk_reset,
			datain_h                      => C64_nCLK_re,--Router_In(0).Data(8), -- Positive edge TXEN
			datain_l                      => C64_nCLK_fe,--Router_In(0).Data(9), -- Negative edge TXEN/TXERR
			outclock                      => i_Q125,--PHY_REG_CLK1_Int,
			dataout                       => no_C64_CLK
		);
	end generate sym_ddr_clk;
	
	sym_ext_clk: if (g_Extern_Q25 = 1) generate
		o_C64_CLK <= C64_CLK;
		no_C64_CLK <= C64_nCLK;
	end generate sym_ext_clk;
	----------------------------------------------------------------------------
	-- extern C64-Bus outputs
	----------------------------------------------------------------------------

	process(i_Q125) begin
		-- hold C64_WrDat for a clk, intern C64_Dat_HOE is faster then extern oe!
		if rising_edge(i_Q125) then
			IntSlvAck_n1 <= IntSlvAck;
		end if;
	end process;
	
	no_testmode : if DF_TESTMODE=0 generate
		signal outdata : std_logic_vector(15 downto 0);
	begin 
		o_C64_Reset <= C64_Reset;
		o_C64_SEL	<= C64_SEL;
		o_C64_Bend	<= C64_Bend;
		-- not yet used
		o_C64_res	<= C64_res;
		
		nb_C64_Ack <= H when C64_Ack_OE=H else 'Z';
		
		-- intern C64_Dat_HOE is faster then extern oe.
		-- be careful, when you change this sequence.
		process (IntSlvAck_n1,C64_Dat_HOE,C64_Dat_LOE,C64_WrDat) 
		begin
			if (C64_Dat_HOE=H or C64_Dat_LOE=H or IntSlvAck_n1=L) then
				outdata <= C64_WrDat;
			else
				outdata <= (others => L);
			end if;
			if (C64_Dat_HOE=H or IntSlvAck_n1=H) then
				b_C64_Data(15 downto 8) <= outdata(15 downto 8);
			else
				b_C64_Data(15 downto 8) <= (others => Z);
			end if;
			
			if (C64_Dat_LOE=H or IntSlvAck_n1=H) then
				b_C64_Data( 7 downto 0) <= outdata( 7 downto 0);
			else
				b_C64_Data( 7 downto 0) <= (others => Z);
			end if;
		end process;
		clk_reset <= L;
	end generate no_testmode;

	testmode : if DF_TESTMODE=1 generate
		signal outdata : std_logic_vector(15 downto 0);
	begin 
		o_C64_Reset <= L when (i_TestModeOE=L or Slv9_Testmode(0)=H) else C64_Reset;
		o_C64_SEL	<= L when (i_TestModeOE=L or Slv9_Testmode(0)=H) else C64_SEL;
		o_C64_Bend	<= L when (i_TestModeOE=L or Slv9_Testmode(0)=H) else C64_Bend;
		-- not yet used
		o_C64_res	<= L when (i_TestModeOE=L or Slv9_Testmode(0)=H) else C64_res;
		
		nb_C64_Ack <= L when (i_TestModeOE=L or Slv9_Testmode(0)=H) else H when C64_Ack_OE=H else 'Z';
		
		-- intern C64_Dat_HOE is faster then extern oe.
		-- be careful, when you change this sequence.
		process (IntSlvAck_n1,C64_Dat_HOE,C64_Dat_LOE,C64_WrDat) 
		begin
			if (C64_Dat_HOE=H or C64_Dat_LOE=H or IntSlvAck_n1=L) then
				outdata <= C64_WrDat;
			else
				outdata <= (others => L);
			end if;
			if (i_TestModeOE=L or Slv9_Testmode(0)=H) then
				b_C64_Data <= (others => L);
			else
				if (C64_Dat_HOE=H or IntSlvAck_n1=H) then
					b_C64_Data(15 downto 8) <= outdata(15 downto 8);
				else
					b_C64_Data(15 downto 8) <= (others => Z);
				end if;
				
				if (C64_Dat_LOE=H or IntSlvAck_n1=H) then
					b_C64_Data( 7 downto 0) <= outdata( 7 downto 0);
				else
					b_C64_Data( 7 downto 0) <= (others => Z);
				end if;
			end if;
		end process;
		clk_reset <= H when (i_TestModeOE=L or Slv9_Testmode(0)=H) else L;
	end generate testmode;

	----------------------------------------------------------------------------
	-- switch extern/intern C64 access
	----------------------------------------------------------------------------
	process (Slv9_C64_Ack_OE,nb_C64_Ack,i_SlvInt_Ack_OE) begin
		-- local C64_Slave access?
		if (Slv9_C64_Ack_OE = H)
		or (i_SlvInt_Ack_OE = H) then
			IntSlvAck <= H;
		else
			IntSlvAck <= L;
		end if;	
	end process;

	C64_Ack_Ext <= not nb_C64_Ack;
	C64_Ack_Int <= IntSlvAck;

	process (Slv9_C64_Dat_HOE,Slv9_C64_Dat_LOE,Slv9_C64_WrDat,b_C64_Data,
			 i_SlvInt_Dat_HOE,i_SlvInt_Dat_LOE,i_SlvInt_Slv2Mas) begin
		-- local C64_Slave access?
		if (Slv9_C64_Dat_HOE = H) then
			C64_RdDat(15 downto 8) <= Slv9_C64_WrDat(15 downto 8);
		elsif (i_SlvInt_Dat_HOE = H) then
			C64_RdDat(15 downto 8) <= i_SlvInt_Slv2Mas(15 downto 8);
		else
			C64_RdDat(15 downto 8) <= b_C64_Data(15 downto 8);
		end if;

		-- local C64_Slave access?
		if (Slv9_C64_Dat_LOE = H) then
			C64_RdDat(7 downto 0) <= Slv9_C64_WrDat(7 downto 0);
		elsif (i_SlvInt_Dat_LOE = H) then
			C64_RdDat(7 downto 0) <= i_SlvInt_Slv2Mas(7 downto 0);
		else
			C64_RdDat(7 downto 0) <= b_C64_Data(7 downto 0);
		end if;
	end process;
	
	o_SlvInt_Mas2Slv <= C64_WrDat;
	o_SlvInt_Reset	<= C64_Reset;
	o_SlvInt_CLK	<= C64_CLK;
	o_SlvInt_SEL	<= C64_SEL;
	o_SlvInt_Bend	<= C64_Bend;
	o_SlvInt_ClkEn	<= C64_CLK_EN;
	
	----------------------------------------------------------------------------
	--
	-- Card Status Rd/Wr
	--
	----------------------------------------------------------------------------
	-- live-bits and read-back bits
	-- Card_Wr_Status(15): EEprom
	-- Card_Wr_Status(14): slave internal
	-- Card_Wr_Status(13..12): okLed state
	-- Card_Wr_Status will be cleared after i_C64_Reset	
no_testmode1 : if DF_TESTMODE=0 generate
	Card_Rd_Status <= x"00" & i_AddrSw(3 downto 0);
end generate no_testmode1;
testmode1 : if DF_TESTMODE=1 generate
	Card_Rd_Status <= "00" & not i_TestModeOE & Slv9_Testmode(0) & "0000" & i_AddrSw(3 downto 0);
	Slv9_Testmode(0) <= Card_Wr_Status(8);
end generate testmode1;
	
	----------------------------------------------------------------------------
	-- C64 BusSlave instance
	----------------------------------------------------------------------------
	--Slv_Q25 <= C64_CLK;
	
	uC64_SlaveSeq: entity C64_Slave.C64_SlaveSeq
	generic map (
		g_App_Rev		=> g_SlaveApp_Rev	,
		g_TrstBuf		=> 0				,
--		g_P_CLK_only	=> 1				,
		g_IntNExt		=> 1				,
		g_m_sync_clk	=> 1
	)
	port map (
		-- internal Slave fix in Module_9 !!!
		 i_AddrSw		=> x"9"				,

		-- synchronous clocking for internal slaves
		i_CLK125		=> i_Q125,
		i_C64_CLK_EN	=> C64_CLK_EN,

		-- C64-Bus
		 i_C64_Reset	=> C64_Reset		,
		 i_CLK25		=> L				,
		 i_C64_SEL		=> C64_SEL          ,
		 i_C64_Bend		=> C64_Bend         ,
		
		i_C64_DatBus	=> C64_WrDat	    ,
		o_C64_DatBus	=> Slv9_C64_WrDat   ,
		o_C64_Dat_HOE	=> Slv9_C64_Dat_HOE ,
		o_C64_Dat_LOE	=> Slv9_C64_Dat_LOE ,
		o_C64_Ack_OE	=> Slv9_C64_Ack_OE  ,
		
		-- JTAG Pins
		 o_JTAG_TCK		=> b_jtagTCK		,
		 o_JTAG_TMS		=> b_jtagTMS		,
		 o_JTAG_TDI		=> b_jtagTDI		,
		 i_JTAG_TDO		=> b_jtagTDO		,
		
		-- SPI Pins
		 o_SPI_CLK		=>  o_SPI_CLK		,
		no_SPI_CS		=> no_SPI_CS		,
		 o_SPI_D		=>  o_SPI_D			,
		 i_SPI_Q		=>  i_SPI_Q			,
		 
		-- local application Rd/Wr 
		 o_Addr			=> Slv_Addr			,
		 i_RdData		=> Slv_RdData		,
		 o_WrData		=> Slv_WrData		,
		 o_WrEn			=> Slv_WrEn			,
		 o_RdEn			=> Slv_RdEn			,
		 -- status
		 i_Card_Status	=> Card_Rd_Status	,
		 o_Card_Status	=> Card_Wr_Status	,
		-- GinFrams_Flags		
		 o_GF_Flags		=> Slv_GF_Flags		,
--		no_EEP_Wen		=> no_EEP_Wen		,
		no_OkLED		=> no_OkLED			,
		 i_HWRev		=> i_HWRev
	);
end architecture rtl;
