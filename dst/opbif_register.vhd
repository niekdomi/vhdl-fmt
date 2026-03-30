--------------------------------------------------------------------------------
--  opbif_register
--------------------------------------------------------------------------------
--
--  project     : ppc-card, imp2, sac2
--  programmer  : C. Leuthold, INDEL AG
--  date        : 18.02.2005
--  version     : 2.00a
--  language    : VHDL
--  system      : ispLever 3.0
--
--  purpose
--      like opb register for inos on ppc-card for imp2, sac2 and future
--      developments include interrupt ctrl
--      but opb interface is outsourced
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 13.09.2004-le
--     should be compatible to opb_IMPregister_v1_00_b
--     new generics:
--         C_TARGET  : integer := 0;   -- IMP2=0, SAC2=1,
--         C_CARD_TYP: std_logic_vector(2 downto 0) := "100";
--     new sinals:
--         i/o_AddrS: new lengrh is 8 (IMPreg 5)
--         i_blinki: blinki-bit from info-link
--         o_CardTyp : output C_CARD_TYP
--     new/changed register:
--         r: LED_ILS(31..23)=Addrs(7..0)  (new: 8 bit addr)
--         w: LED_ILS(31)=MasterSlave      (new: write only)
--         r: LED_ILS(19)=i_blinki
--         r: LED_ILS(22..22)= C_CARD_TYP
-- 12.11.2004-le
--     new register:
--         time measurement for pending irqs
--         PI_CNT(0..1) 2 16bit ticks counters for fildbus irqs
-- 26.08.2005-le
--     target-spez. cleanup., new target max2
-- 19.04.2006-le
--     remove revision(31 downto 28) <= CONV_STD_LOGIC_VECTOR(C_TARGET,4)
-- 27.10.2006-le
--     add critical irq at addr 0x80000840
--     add C_CONF_PI_COUNTER := 0
--     add I/Os i_Intr and o_Irq (same as Intr and Irq)
--	11.05.2007-le	add svn keywords
--	09.01.2008-le	register pi(i) to avoid timing warning
--	26.02.2008-le	add readable outputs o_flags at 0x..14 
--					add gpios
--	06.05.2008-le	add C_SVN_NO to show svn rev. no. at addr. 0xf8
--	06.10.2008-le	set default values for b_GPIO_I and i_BatCmp
--	28.04.2009-le	add input HW_Rev to change C_REVISION(15 dt 12) on runtime
--	12.10.2009-le	add C_INIT_EXTMEM_OFF
--	18.03.2010-le	add fan PWM
--	24.09.2012-le	add outputs GinRing and GinAUtoClose
--	25.09.2012-le	add C_GINFLG_EN to activate/deactivate implementation of GinRing and GinAUtoClose
--	07.12.2012-le	add flags for second uart
--------------------------------------------------------------------------------
--$Rev:: 2565                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2012-12-07 13:57:03 +0100 (Fr., 07 Dez 2012)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
-- rev. b include interrupt ctrl
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity opbif_register is
   -- Generics to be set by user
	generic (
		-- LEDs
		C_INIT_LEDREG : std_logic_vector := x"00000000";
		-- INFOLINK
		C_INIT_INFOREG : std_logic_vector := x"00000000";
		-- Memory read and write access times for all memory banks
		C_INIT_MEMREG : std_logic_vector := x"00000000";
		-- init of extmem on/off
		C_INIT_EXTMEM_OFF: std_logic := L;
		-- HW Revision
		C_REVISION : std_logic_vector := x"00000000";
		-- interrupt ctrl
		C_NUM_INTR_INPUTS : integer := 11;
		C_KIND_OF_INTR : std_logic_vector(31 downto 0) := "00000000000000000000000110001111";
		C_POS_N_NEG : std_logic_vector(31 downto 0) := "00000000000000000000011110111111";
		-- Target typ
		C_TARGET: integer := 0; -- DF_TARGET_IMP2=0, DF_TARGET_SAC2=1, MAX2=2
		-- CARD_TYP
		C_CARD_TYP : std_logic_vector(2 downto 0) := "100"; -- def imp2 typ
		C_SYNC_IL: integer := 1;
		C_CONF_PI_COUNTER : integer := 0;
		C_DWIDTH : integer := 32;
		C_AWIDTH : integer := 32;
		DF_FLAGS : integer range 0 to 1 := 0;
		C_NUM_OF_GPIO : integer range 0 to 8 := 0;
		C_GPIO_T_LEVEL : integer range 0 to 1 := 1; -- 1: H=input /0: L=input
		C_SVN_NO : std_logic_vector := x"00000000";
		C_GINFLG_EN : std_logic_vector(7 downto 0) := x"00";
		C_XFLG_EN : std_logic_vector(7 downto 0) := x"00"
	);
	port (
		-- System Port Declarations ********************************************
		i_Clk           : in std_logic;
		i_Rst           : in std_logic := L;
		-- OPB IF Port Declarations ********************************************
		i_addr          : in std_logic_vector(C_AWIDTH-1 downto 0);
		i_rd_acc        : in std_logic;
		i_wr_acc        : in std_logic;
		i_byte_ebl      : in std_logic_vector(C_DWIDTH/8-1 downto 0);
		i_wr_data       : in std_logic_vector(C_DWIDTH-1 downto 0);
		o_rd_data       : out std_logic_vector(C_DWIDTH-1 downto 0);
		o_rd_acc_done   : out std_logic;
		o_wr_acc_done   : out std_logic;
		-- Memory read and write access times for all memory banks
		o_MemConfig     : out std_logic_vector(31 downto 0);
		-- LEDs
		no_OKLed        : out   std_logic;
		no_ErrorLed     : out   std_logic;
		ni_PowerLed     : in    std_logic;
		ni_LinkLed      : in    std_logic;
		ni_LanLnkLed    : in    std_logic;
		ni_LanRXLed     : in    std_logic;
		o_LanLnkLed     : out   std_logic;
		no_LanRXLed     : out   std_logic;
		-- INFOLINK Slave
		i_il_Clk        : in    std_logic;
		o_CIRQ0en       : out   std_logic;
		o_CIRQ1en       : out   std_logic;
		o_IMPCmpEn      : out   std_logic;
		i_blinki        : in    std_logic;
		i_AddrS         : in    std_logic_vector(7 downto 0);
		o_AddrS         : out   std_logic_vector(7 downto 0);
		o_MasterSlave   : out   std_logic;
		o_CardTyp       : out   std_logic_vector(2 downto 0);
		-- INFOLINK Master
		o_Master_Ctrl   : out   std_logic_vector(7 downto 0);
		o_Diag_ON       : out   std_logic;
		o_Diag_invers   : out   std_logic;
		i_JobIRQ        : in    std_logic;
		i_CIRQ          : in    std_logic;
		i_Error         : in    std_logic;
		i_Ovrun         : in    std_logic;
		i_Or1ms         : in    std_logic;
		-- Battery monitoring
		i_BatCmp        : in    std_logic := L;
		-- I2C Bus
		o_i2cSCL        : out   std_logic;
		b_i2cSDA_O      : out   std_logic;
		b_i2cSDA_T      : out   std_logic;
		b_i2cSDA_I      : in    std_logic;
		-- IMPBus
		o_impbusGoNRst  : out   std_logic;
		-- ExtMem_OFF
		o_ExtMem_OFF    : out   std_logic;
		-- chip reset
		o_chip_reset    : out   std_logic;
		-- flg
		o_flags			: out   std_logic_vector(31 downto 0);
		b_GPIO_T        : out   std_logic_vector(C_NUM_OF_GPIO-1 downto 0);
		b_GPIO_O        : out   std_logic_vector(C_NUM_OF_GPIO-1 downto 0);
		b_GPIO_I        : in    std_logic_vector(C_NUM_OF_GPIO-1 downto 0) := (others => L);
		-- selfprogramming JTAG-Port
		b_jtgTCK_T      : out   std_logic;
		b_jtgTMS_T      : out   std_logic;
		b_jtgTDO_T      : out   std_logic;
		b_jtgTDI_T      : out   std_logic;
		b_jtgTCK_O      : out   std_logic;
		b_jtgTMS_O      : out   std_logic;
		b_jtgTDO_O      : out   std_logic;
		b_jtgTDI_O      : out   std_logic;
		b_jtgTCK_I      : in    std_logic;
		b_jtgTMS_I      : in    std_logic;
		b_jtgTDO_I      : in    std_logic;
		b_jtgTDI_I      : in    std_logic;
		i_Free1         : in    std_logic_vector(31 downto 0) := (others => L);
		i_Free2         : in    std_logic_vector(31 downto 0) := (others => L);
		Intr            : in    std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0) := (others => L); -- for compatibility only
		Irq             : out   std_logic;                                                         -- for compatibility only
		i_Intr          : in    std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0) := (others => L);
		o_Irq           : out   std_logic;
		o_CritIrq       : out   std_logic;
		i_HW_Rev        : in    std_logic_vector(3 downto 0) := C_REVISION(15 downto 12);
		i_Tacho         : in std_logic := L;
		no_Fan          : out std_logic;
		o_GinRing       : out std_logic;
		o_GinAutoClose  : out std_logic;
		o_X10_Uart       : out std_logic;
		o_X10_Uart_inv   : out std_logic;
		o_X10_Uart_route : out std_logic
	);
end opbif_register;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture implementation of opbif_register is
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';

	constant DF_LED_ILS_ADDR    : std_logic_vector :="000000";  --0x00
	constant DF_ILM_ADDR        : std_logic_vector :="000001";  --0x04
	constant DF_I2C_ADDR        : std_logic_vector :="000010";  --0x08
	constant DF_JTAG_ADDR       : std_logic_vector :="000011";  --0x0c
	constant DF_MEM_ADDR        : std_logic_vector :="000100";  --0x10
	constant DF_TARGET_ADDR     : std_logic_vector :="000101";  --0x14
	constant DF_FREE1_ADDR      : std_logic_vector :="000110";  --0x18
	constant DF_FREE2_ADDR      : std_logic_vector :="000111";  --0x1c
	constant DF_INT_ISR_ADDR    : std_logic_vector :="001000";  --0x20
	constant DF_INT_IER_ADDR    : std_logic_vector :="001001";  --0x24
	constant DF_INT_PIR_ADDR    : std_logic_vector :="001010";  --0x28
	constant DF_INT_MER_ADDR    : std_logic_vector :="001011";  --0x2c
	constant DF_INT_KIND_ADDR   : std_logic_vector :="001100";  --0x30
	constant DF_INT_P_N_ADDR    : std_logic_vector :="001101";  --0x34
	constant DF_PI_CNT0         : std_logic_vector :="001110";  --0x38
	constant DF_PI_CNT1         : std_logic_vector :="001111";  --0x3c
	constant DF_INT_CIR_ADDR    : std_logic_vector :="010000";  --0x40
	constant DF_SVN_ADDR        : std_logic_vector :="111110";  --0xf8

	constant DF_TARGET_IMP2     : integer :=0;
	constant DF_TARGET_SAC2     : integer :=1;
	constant DF_TARGET_MAX2     : integer :=2;
	
	constant DF_TARGET_SUP_ALL  : integer :=256; -->= 256 for deflopment -> target on system: 256 IMP-MAS2 257 INFO-SAC2...
	-- components --------------------------------------------------------------
	----------------------------------------------------------------------------
	-- Signal and Type Declarations
	----------------------------------------------------------------------------
	-- signals -----------------------------------------------------------------
	signal rst                  : std_logic;
	signal clk                  : std_logic;
	signal loc_addr             : std_logic_vector(C_AWIDTH-1 downto 0);
	signal loc_rd_acc           : std_logic;
	signal loc_wr_acc           : std_logic;
	signal loc_byte_ebl         : std_logic_vector(C_DWIDTH/8-1 downto 0);
	signal loc_wr_data          : std_logic_vector(C_DWIDTH-1 downto 0);
	signal loc_rd_data          : std_logic_vector(C_DWIDTH-1 downto 0);
	signal loc_rd_acc_done      : std_logic;
	signal loc_wr_acc_done      : std_logic;
	signal OKLed                : std_logic:=C_INIT_LEDREG(31);
	signal ErrorLed             : std_logic:=C_INIT_LEDREG(30);
	signal PowerLed             : std_logic:=L;
	signal LinkLed              : std_logic:=L;
	signal CIRQ0en              : std_logic:=C_INIT_INFOREG(31);
	signal CIRQ1en              : std_logic:=C_INIT_INFOREG(30);
	signal CmpEn                : std_logic:=C_INIT_INFOREG(29);
	signal Master_Ctrl          : std_logic_vector(7 downto 0):=C_INIT_INFOREG(23 downto 16);
	signal Diag_ON              : std_logic:=C_INIT_INFOREG(15);
	signal Diag_invers          : std_logic:=C_INIT_INFOREG(14);
	signal BatCmp               : std_logic:=L;
	signal i2cSDA_T             : std_logic:=H;
	signal i2cSCL               : std_logic:=H;
	signal i2cSDA               : std_logic:=L;
	signal jtgTCK_T             : std_logic:=H;
	signal jtgTMS_T             : std_logic:=H;
	signal jtgTDO_T             : std_logic:=H;
	signal jtgTDI_T             : std_logic:=H;
	signal jtgTCK               : std_logic:=L;
	signal jtgTMS               : std_logic:=L;
	signal jtgTDO               : std_logic:=L;
	signal jtgTDI               : std_logic:=L;
	signal LanLnkLed            : std_logic;
	signal LanRXLed             : std_logic;
	signal MasterSlave          : std_logic:=C_INIT_INFOREG(0);
	signal impbusGoNRst         : std_logic:=L;
	signal ExtMem_OFF           : std_logic:=C_INIT_EXTMEM_OFF;
	signal chip_reset           : std_logic:=L;
	signal flags                : std_logic_vector(C_DWIDTH-1 downto 0):= (others => L);
	signal MemReg               : std_logic_vector(C_DWIDTH-1 downto 0):=C_INIT_MEMREG;
	-- interrupt controller
	signal ISR                  : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal IER                  : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal IAR                  : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal PIR                  : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal CIR                  : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal MER                  : std_logic_vector(1 downto 0)                    := (others => L);
	signal IntrEdge             : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal IntrOld              : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal l_Intr               : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal SW_Intr              : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= (others => L);
	signal KIND_OF_INTR         : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= C_KIND_OF_INTR(31 downto 32-C_NUM_INTR_INPUTS);
	signal POS_N_NEG            : std_logic_vector(C_NUM_INTR_INPUTS - 1 downto 0):= C_POS_N_NEG   (31 downto 32-C_NUM_INTR_INPUTS);
	signal l_Irq                : std_logic:=L;
	signal l_CritIrq            : std_logic:=L;
	
	-- time measurement for pending irqs
	signal pi     : std_logic_vector(1 downto 0):= (others => L);
	signal pi_old : std_logic_vector(1 downto 0):= (others => L);
	type t_cnt_arr is array (1 downto 0) of std_logic_vector(15 downto 0);
	signal pi_cnt : t_cnt_arr;
	type t_PI_Select is array (1 downto 0) of std_logic_vector(4 downto 0);
	signal PI_Select : t_PI_Select;
	-- data sync 99 - 66 MHz
	signal sync_done            : std_logic:=L;
	signal sync_data            : std_logic:=L;
	
	signal GPIO_O : std_logic_vector(C_NUM_OF_GPIO-1 downto 0) := (others => L);
	signal GPIO_T : std_logic_vector(C_NUM_OF_GPIO-1 downto 0) := (others => H);
	
	signal Tacho : std_logic := L;
	signal nFan : std_logic := L;
	
	signal FanPwm : std_logic_vector(6 downto 0) := (others => L);
	signal FanPwmCnt: std_logic_vector(6 downto 0) := (others => L);
	signal precnt : std_logic_vector(4 downto 0) := (others => L);
	signal postcnt : std_logic_vector(15 downto 0) := (others => L);
	signal FanPwmOut : std_logic := L;
	signal FanPwmWr : std_logic := L;
	signal postcnten : std_logic := L;
	--C_GINFLG_EN
	signal GinRing : std_logic := L;
	signal GinAutoClose : std_logic := L;
	--C_XFLG_EN
	signal X10_Uart : std_logic;
	signal X10_Uart_inv : std_logic;
	signal X10_Uart_route : std_logic;
	
	-- functons ----------------------------------------------------------------
	FUNCTION vector_or ( inputs : std_logic_vector )
	RETURN std_logic IS
	CONSTANT floatvalue : std_logic := '0' ;
	BEGIN
	IF inputs'Length = 0 THEN
	   RETURN floatvalue ;
	ELSE
	   FOR i IN inputs'Range LOOP
		  IF inputs(i) = '1' THEN
			 RETURN '1' ;
		  END IF ;
	   END LOOP ;
	   RETURN '0' ;
	END IF ;
	END ;
	
	FUNCTION vector_or_with_mask ( inputs, mask : std_logic_vector )
	RETURN std_logic IS
	variable retvalue : std_logic := L ;
	BEGIN
		IF inputs'Length > 0 THEN
			FOR i IN inputs'Range LOOP
				IF inputs(i) = H and mask(i) = H THEN
					retvalue := H;
				END IF;
			END LOOP;
		END IF;
		RETURN retvalue ;
	END ;
begin -- architecture ----------------------------------------------------------
	clk <= i_Clk;
	rst <= i_Rst;
	-- OPB FI PORT
	loc_addr <= i_addr;
	loc_rd_acc <= i_rd_acc;
	loc_wr_acc <= i_wr_acc;
	loc_byte_ebl <= i_byte_ebl;
	loc_wr_data <= i_wr_data;
	o_rd_data <= loc_rd_data;
	o_rd_acc_done <= loc_rd_acc_done;
	o_wr_acc_done <= loc_wr_acc_done;
	-- Memory read and write access times for all memory banks
	o_MemConfig <= MemReg;
	-- LEDs
	PowerLed <= not(ni_PowerLed);
	--LinkLed <= not(ni_LinkLed);
	no_OKLed <= not(OKLed   );
	no_ErrorLed <= not(ErrorLed);
	o_LanLnkLed <= not(LanRXLed) and LanLnkLed;
	no_LanRXLed <= LanRXLed;
	----------------------------------------------------------------------------
	-- sync info-link register to a sec. clk
	--
	-- if C_SYNC_IL=1, the outputs for infolink master/slave are synched with a
	-- sec. clk
	----------------------------------------------------------------------------
	LinkLed <= not(ni_LinkLed);
	no_il_sync : if C_SYNC_IL=0 generate
		-- INFOLINK M&S
		o_MasterSlave <= MasterSlave;
		-- INFOLINK Slave
		o_CIRQ0en <= CIRQ0en;
		o_CIRQ1en <= CIRQ1en;
		o_IMPCmpEn <= CmpEn;
		o_CardTyp <= C_CARD_TYP;
		o_AddrS <= i_AddrS;
		-- INFOLINK Master
		o_Master_Ctrl <= Master_Ctrl;
		o_Diag_ON <= Diag_ON      ;
		o_Diag_invers <= Diag_invers  ;
	end generate no_il_sync;

	il_sync : if C_SYNC_IL=1 generate
		sync_il : process (i_il_Clk)
		begin
			if rising_edge(i_il_Clk) then
				o_AddrS <= i_AddrS;
				if sync_done=H then
					-- INFOLINK M&S
					o_MasterSlave <= MasterSlave;
					-- INFOLINK Slave
					o_CIRQ0en <= CIRQ0en;
					o_CIRQ1en <= CIRQ1en;
					o_IMPCmpEn <= CmpEn;
					-- INFOLINK Master
					o_Master_Ctrl <= Master_Ctrl;
					o_Diag_ON <= Diag_ON;
					o_Diag_invers <= Diag_invers;
					sync_done <= L;
				elsif sync_data=H then
					sync_done <= H;
				end if;
			end if;
		end process;
		o_CardTyp <= C_CARD_TYP;
	end generate il_sync;
	----------------------------------------------------------------------------
	-- I2C Bus
	o_i2cSCL <= i2cSCL;
	b_i2cSDA_T <= i2cSDA_T;
	b_i2cSDA_O <= i2cSDA_T;
	-- Fan
	no_Fan <= not FanPwmOut;
	
	o_GinRing <= GinRing;
	o_GinAutoClose <= GinAutoClose;
	
	o_X10_Uart <= X10_Uart;
	o_X10_Uart_inv <= X10_Uart_inv;
	o_X10_Uart_route <= X10_Uart_route;
	
	
	-- selfprogramming JTAG-Port
	b_jtgTCK_T <= jtgTCK_T;
	b_jtgTMS_T <= jtgTMS_T;
	b_jtgTDO_T <= jtgTDO_T;
	b_jtgTDI_T <= jtgTDI_T;
	b_jtgTCK_O <= jtgTCK;
	b_jtgTMS_O <= jtgTMS;
	b_jtgTDO_O <= jtgTDO;
	b_jtgTDI_O <= jtgTDI;
	-- IMPBus
	o_impbusGoNRst <= impbusGoNRst;
	-- ExtMem_OFF
	o_ExtMem_OFF <= ExtMem_OFF;

	o_chip_reset <= chip_reset;
	
	o_flags <= flags;
	b_GPIO_T <= GPIO_T;
	b_GPIO_O <= GPIO_O;
	----------------------------------------------------------------------------
	-- interrupt controller
	----------------------------------------------------------------------------

	PIR <= ISR and IER;
	l_Irq <= vector_or_with_mask(PIR,IER);
	l_CritIrq <= vector_or_with_mask(ISR,CIR);
	
	l_Intr <= i_Intr or Intr; -- !!!compatibility!!! one of both is zero 
	
	interrupt : process (clk)
	begin
		if rising_edge(clk) then
			if (rst=H) or (MER(0)=L) then
				o_Irq <= L;
				Irq <= L;
				o_CritIrq <= L;
			else
				o_Irq <= l_Irq;
				Irq <= l_Irq;-- compatibility
				o_CritIrq <= l_CritIrq;
			end if;
		end if;
	end process;

	interrupt_LorE : process (l_Intr, MER, KIND_OF_INTR, IntrEdge, SW_Intr, POS_N_NEG)
	begin
		ISR <= (others => '0');
		-- sw- or hw-ints
		if MER(1)=H then
		-- hw ints
			for i in l_Intr'range
			loop
				if KIND_OF_INTR(i)=H then
					-- edge
					ISR(i) <= IntrEdge(i);
				else
					-- level
					if POS_N_NEG(i)=H then
						-- pos
						ISR(i) <= l_Intr(i);
					else
						-- neg
						ISR(i) <= not(l_Intr(i));
					end if;
				end if;
			end loop;
		else
		-- sw ints
			ISR <= SW_Intr;
		end if;
	end process;

	interrupt_Ededect : process (clk)
	begin
		if rising_edge(clk) then
			for i in l_Intr'range
			loop
				if KIND_OF_INTR(i)=H then
					IntrOld(i) <= l_Intr(i);
					if IAR(i)=H then
						-- clear on H puls of IAR
						IntrEdge(i) <= L;
					end if;
					if POS_N_NEG(i)=H then
						-- pos edge
						if l_Intr(i)=H and IntrOld(i)=L then
							IntrEdge(i) <= H;
						end if;
					else
						-- neg edge
						if l_Intr(i)=L and IntrOld(i)=H then
							IntrEdge(i) <= H;
						end if;
					end if;
				end if;
			end loop;
		end if;
	end process;
	----------------------------------------------------------------------------
	-- time measurement for pending irqs
	--
	-- 2 16bit counters for fildbus irqs
	----------------------------------------------------------------------------
	old_style : if C_CONF_PI_COUNTER=0 generate
	begin
		process (clk)
		begin
			if rising_edge(clk) then
				pi(0) <= PIR(2) or PIR(10);     -- info link slave(irq4) or master
				pi(1) <= PIR(7) or PIR(8);      -- imp bus   RXendInt or sBusInt
			end if;
		end process;
	end generate old_style;
	conf_pi_cnt : if C_CONF_PI_COUNTER=1 generate
	begin
		process (clk)
		begin
			if rising_edge(clk) then
				pi(0) <= PIR(CONV_INTEGER(PI_Select(0)));
				pi(1) <= PIR(CONV_INTEGER(PI_Select(1)));
			end if;
		end process;
	end generate conf_pi_cnt;
	
	pending_cnt : process (clk)
	begin
		if rising_edge(clk) then
			for i in pi'range loop
				pi_old(i) <= pi(i);
				if (pi(i)=H and pi_old(i)=L) then
					pi_cnt(i) <= (others => L);
				elsif (pi(i)=H) then
					if pi_cnt(i)/=x"ffff" then
						pi_cnt(i) <= pi_cnt(i) + 1;
					end if;
				end if;
			end loop;
		end if;
	end process;
	----------------------------------------------------------------------------
	write : process (rst, clk)
	begin
		if rst=H then
			MemReg <= C_INIT_MEMREG;
			-- LEDs
			OKLed <= C_INIT_LEDREG(31);
			ErrorLed <= C_INIT_LEDREG(30);
			-- INFOLINK
			CIRQ0en <= C_INIT_INFOREG(31);
			CIRQ1en <= C_INIT_INFOREG(30);
			CmpEn <= C_INIT_INFOREG(29);
			Master_Ctrl <= C_INIT_INFOREG(23 downto 16);
			Diag_ON <= C_INIT_INFOREG(15);
			Diag_invers <= C_INIT_INFOREG(14);
			MasterSlave <= C_INIT_INFOREG(0);
			-- I2C BUS
			i2cSCL <= H;
			i2cSDA_T <= H;
			-- Fan
			nFan <= L;
			-- selfprogramming JTAG-Port
			jtgTCK_T <= H;
			jtgTMS_T <= H;
			jtgTDO_T <= H;
			jtgTDI_T <= H;
			-- IMPBus
			impbusGoNRst<= L;
			-- ExtMem_OFF
			ExtMem_OFF <= C_INIT_EXTMEM_OFF;
			chip_reset <= L;
			flags <= (others => '0');
			-- set as inputs
			if C_GPIO_T_LEVEL=1 then
				GPIO_T <= (others => '1');
			else
				GPIO_T <= (others => '0');
			end if;
			GPIO_O <= (others => '0');
			IER <= (others => '0');
			CIR <= (others => '0');
			IAR <= (others => '0');
			MER <= (others => '0');
			SW_Intr <= (others => '0');
			for i in 0 to C_NUM_INTR_INPUTS-1 loop
				KIND_OF_INTR(i)<= C_KIND_OF_INTR(C_KIND_OF_INTR'high-i);
			end loop;
			for i in 0 to C_NUM_INTR_INPUTS-1 loop
				POS_N_NEG(i)<= C_POS_N_NEG(C_POS_N_NEG'high-i);
			end loop;
			FanPwm <= conv_std_logic_vector(100,7);
			FanPwmWr <= L;
			GinRing <= L;
			GinAutoClose <= L;
			X10_Uart_inv <= L;
			X10_Uart_route <= L;
			X10_Uart <= L;
			if (C_XFLG_EN(0)=H) then
				X10_Uart <= H;
			end if;
			
			
		elsif rising_edge(clk) then
			if ((C_TARGET=DF_TARGET_IMP2) or (C_TARGET>=DF_TARGET_SUP_ALL)) then
				BatCmp <= i_BatCmp;
				LanLnkLed <= not(ni_LanLnkLed);
				LanRXLed <= not(ni_LanRXLed);
			end if;
			i2cSDA <= b_i2cSDA_I;
			loc_wr_acc_done <= H;
			IAR <= (others => '0'); -- only a short puls
			for i in IER'range
			loop
				if KIND_OF_INTR(i)=L and IAR(i)=H then
				-- disable level-IRQs with acknowledge
					IER(i) <= L;
					CIR(i) <= L;
				end if;
			end loop;
			if sync_done=H then
				sync_data <= L;
			end if;
			precnt <= precnt + 1;
			postcnten <= L;
			if (precnt=0) then
				FanPwmCnt <= FanPwmCnt + 1;
				if (FanPwmCnt=99) then
					FanPwmCnt <= (others => L);
					postcnten <= H;
				end if;
				if (FanPwmCnt>FanPwm) then
					FanPwmOut <= L;
				else
					FanPwmOut <= H;
				end if;
				if (FanPwmCnt=FanPwm or FanPwm>99) then
					tacho <= i_Tacho;
				end if;
			end if;
			if (postcnten=H) then
				postcnt <= postcnt + 1;
				if (postcnt=0) then
					if (FanPwmWr=L) then
						FanPwm <= conv_std_logic_vector(100,7);
					end if;
					FanPwmWr <= L;
				end if;
			end if;
			
			if loc_wr_acc=H then-- and loc_wr_acc_done=Lthen    -- write
				if loc_addr(7 downto 2)=DF_LED_ILS_ADDR then
					-- LEDs
					if loc_byte_ebl(0) = H and loc_wr_acc_done = H then
						OKLed <= loc_wr_data(0);
						ErrorLed <= loc_wr_data(1);
					end if;
					-- INFOLINK Slave
					if loc_byte_ebl(2) = H and loc_wr_acc_done = H then
						CIRQ0en <= loc_wr_data(16);
						CIRQ1en <= loc_wr_data(17);
						CmpEn <= loc_wr_data(18);
						sync_data <= H;
					end if;
					if loc_byte_ebl(3) = H and loc_wr_acc_done = H then
						MasterSlave <= loc_wr_data(31);
						sync_data <= H;
					end if;
				elsif loc_addr(7 downto 2)=DF_ILM_ADDR then
					-- INFOLINK Master
					if loc_byte_ebl(0) = H and loc_wr_acc_done = H then
						Master_Ctrl <= loc_wr_data(7 downto 0);
						sync_data <= H;
					end if;
					if loc_byte_ebl(1) = H and loc_wr_acc_done = H then
						Diag_ON <= loc_wr_data(8);
						Diag_invers <= loc_wr_data(9);
						sync_data <= H;
					end if;
				elsif loc_addr(7 downto 2)=DF_I2C_ADDR then
					-- I2C
					if loc_byte_ebl(0) = H and loc_wr_acc_done = H then
						i2cSCL <= loc_wr_data(0);
						i2cSDA_T <= loc_wr_data(1);
					end if;
					
					if loc_byte_ebl(1) = H and loc_wr_acc_done = H then
						dbg_int_out("C_XFLG_EN" , conv_integer(C_XFLG_EN));
						if (C_XFLG_EN(0)=H) then
							X10_Uart <= loc_wr_data(8);
						end if;
						if (C_XFLG_EN(1)=H) then
							X10_Uart_inv <= loc_wr_data(9);
						end if;
						if (C_XFLG_EN(2)=H) then
							X10_Uart_route <= loc_wr_data(10);
						end if;
					end if;
					
					
					if loc_byte_ebl(2) = H and loc_wr_acc_done = H then
						FanPwm <= loc_wr_data(22 downto 16);
						FanPwmWr <= H;
					end if;
					if loc_byte_ebl(3) = H and loc_wr_acc_done = H then
						dbg_int_out("C_GINFLG_EN" , conv_integer(C_GINFLG_EN));
						if (C_GINFLG_EN(DF_GINRING)=H) then
							GinRing <= loc_wr_data(24);
						end if;
						if (C_GINFLG_EN(DF_GINAUTOCLOSE)=H) then
							GinAutoClose <= loc_wr_data(25);
						end if;
					end if;
				elsif loc_addr(7 downto 2)=DF_JTAG_ADDR then
					-- selfprogramming JTAG-Port
					if loc_byte_ebl(0) = H and loc_wr_acc_done = H then
						jtgTCK <= loc_wr_data(0);
						jtgTMS <= loc_wr_data(1);
						jtgTDO <= loc_wr_data(2);
						jtgTDI <= loc_wr_data(3);
					end if;
					if loc_byte_ebl(2) = H and loc_wr_acc_done = H then
						jtgTCK_T <= loc_wr_data(16);
						jtgTMS_T <= loc_wr_data(17);
						jtgTDO_T <= loc_wr_data(18);
						jtgTDI_T <= loc_wr_data(19);
					end if;
					if (C_NUM_OF_GPIO/=0) then
						for i in 0 to C_NUM_OF_GPIO-1 loop
							if loc_byte_ebl(1) = H and loc_wr_acc_done = H then
								GPIO_O(i) <= loc_wr_data(8+i);
							end if;
							if loc_byte_ebl(3) = H and loc_wr_acc_done = H then
								GPIO_T(i) <= loc_wr_data(24+i);
							end if;
						end loop;
					end if;
				elsif loc_addr(7 downto 2)=DF_MEM_ADDR then
					-- Memory
					for i in 0 to C_DWIDTH/8-1 loop
						if loc_byte_ebl(i) = H and loc_wr_acc_done = H then
							MemReg(i*8+7 downto i*8) <= loc_wr_data(i*8+7 downto i*8);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_TARGET_ADDR then
					-- IMPBus
					if loc_byte_ebl(0) = H and loc_wr_acc_done = H then
						if ((C_TARGET=DF_TARGET_IMP2) or (C_TARGET>=DF_TARGET_SUP_ALL)) then
							impbusGoNRst <= loc_wr_data(0);
						end if;
					end if;
					-- ExtMem_OFF
					if loc_byte_ebl(1) = H and loc_wr_acc_done = H then
						if (C_TARGET=DF_TARGET_IMP2) then
							ExtMem_OFF <= L;
						else
							ExtMem_OFF <= loc_wr_data(8);
						end if;
						chip_reset <= loc_wr_data(9);
					end if;
					if (DF_FLAGS = 1) then
						for i in 0 to C_DWIDTH/8-1 loop
							if loc_byte_ebl(i) = H and loc_wr_acc_done = H then
								flags(i*8+7 downto i*8) <= loc_wr_data(i*8+7 downto i*8);
							end if;
						end loop;
					end if;
				elsif loc_addr(7 downto 2)=DF_INT_ISR_ADDR then
					-- SW_Intr
					for i in SW_Intr'range
					loop
						if i<8 and loc_byte_ebl(0) = H and loc_wr_acc_done = H then
							SW_Intr(i) <= loc_wr_data(i);
						end if;
						if i>7 and i<16 and loc_byte_ebl(1) = H and loc_wr_acc_done = H then
							SW_Intr(i) <= loc_wr_data(i);
						end if;
						if i>15 and i<24 and loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							SW_Intr(i) <= loc_wr_data(i);
						end if;
						if i>23 and i<32 and loc_byte_ebl(3) = H and loc_wr_acc_done = H then
							SW_Intr(i) <= loc_wr_data(i);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_INT_IER_ADDR then
					-- IER
					for i in IER'range
					loop
						if i<8 and loc_byte_ebl(0) = H and loc_wr_acc_done = H then
							IER(i) <= loc_wr_data(i);
						end if;
						if i>7 and i<16 and loc_byte_ebl(1) = H and loc_wr_acc_done = H then
							IER(i) <= loc_wr_data(i);
						end if;
						if i>15 and i<24 and loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							IER(i) <= loc_wr_data(i);
						end if;
						if i>23 and i<32 and loc_byte_ebl(3) = H and loc_wr_acc_done = H then
							IER(i) <= loc_wr_data(i);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_INT_PIR_ADDR then
					-- IAR
					for i in IAR'range
					loop
						if i<8 and loc_byte_ebl(0) = H and loc_wr_acc_done = H then
							IAR(i) <= loc_wr_data(i);
						end if;
						if i>7 and i<16 and loc_byte_ebl(1) = H and loc_wr_acc_done = H then
							IAR(i) <= loc_wr_data(i);
						end if;
						if i>15 and i<24 and loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							IAR(i) <= loc_wr_data(i);
						end if;
						if i>23 and i<32 and loc_byte_ebl(3) = H and loc_wr_acc_done = H then
							IAR(i) <= loc_wr_data(i);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_INT_MER_ADDR then
					-- MER
					if loc_byte_ebl(0) = H and loc_wr_acc_done = H then
						MER <= loc_wr_data(1 downto 0);
					end if;
				elsif loc_addr(7 downto 2)=DF_INT_KIND_ADDR then
					-- KIND_OF_INTR
					for i in KIND_OF_INTR'range
					loop
						if i<8 and loc_byte_ebl(0) = H and loc_wr_acc_done = H then
							KIND_OF_INTR(i) <= loc_wr_data(i);
						end if;
						if i>7 and i<16 and loc_byte_ebl(1) = H and loc_wr_acc_done = H then
							KIND_OF_INTR(i) <= loc_wr_data(i);
						end if;
						if i>15 and i<24 and loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							KIND_OF_INTR(i) <= loc_wr_data(i);
						end if;
						if i>23 and i<32 and loc_byte_ebl(3) = H and loc_wr_acc_done = H then
							KIND_OF_INTR(i) <= loc_wr_data(i);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_INT_P_N_ADDR then
					-- POS_N_NEG
					for i in POS_N_NEG'range
					loop
						if i<8 and loc_byte_ebl(0) = H and loc_wr_acc_done = H then
							POS_N_NEG(i) <= loc_wr_data(i);
						end if;
						if i>7 and i<16 and loc_byte_ebl(1) = H and loc_wr_acc_done = H then
							POS_N_NEG(i) <= loc_wr_data(i);
						end if;
						if i>15 and i<24 and loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							POS_N_NEG(i) <= loc_wr_data(i);
						end if;
						if i>23 and i<32 and loc_byte_ebl(3) = H and loc_wr_acc_done = H then
							POS_N_NEG(i) <= loc_wr_data(i);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_INT_CIR_ADDR then
					-- CIR H: critical irq / L non critical irq
					for i in CIR'range
					loop
						if i<8 and loc_byte_ebl(0) = H and loc_wr_acc_done = H then
							CIR(i) <= loc_wr_data(i);
						end if;
						if i>7 and i<16 and loc_byte_ebl(1) = H and loc_wr_acc_done = H then
							CIR(i) <= loc_wr_data(i);
						end if;
						if i>15 and i<24 and loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							CIR(i) <= loc_wr_data(i);
						end if;
						if i>23 and i<32 and loc_byte_ebl(3) = H and loc_wr_acc_done = H then
							CIR(i) <= loc_wr_data(i);
						end if;
					end loop;
				elsif loc_addr(7 downto 2)=DF_PI_CNT0 then 
					if C_CONF_PI_COUNTER=1 then
						-- PI(0)
						if loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							PI_Select(0) <= loc_wr_data(20 downto 16);
						end if;
					end if;
				elsif loc_addr(7 downto 2)=DF_PI_CNT1 then
					if C_CONF_PI_COUNTER=1 then
						-- PI(1)
						if loc_byte_ebl(2) = H and loc_wr_acc_done = H then
							PI_Select(1) <= loc_wr_data(20 downto 16);
						end if;
					end if;
				end if;  -- end of addr decod 
			end if;
			if loc_rd_acc=H and loc_rd_acc_done=L then  -- read
				loc_rd_acc_done <= H;
			else
				loc_rd_acc_done <= L;
			end if;
		end if;
	end process;

	read : process(loc_rd_acc,OKLed,ErrorLed,PowerLed,LinkLed,CIRQ0en,CIRQ1en,CmpEn,i_AddrS,MemReg,loc_addr,LanLnkLed, LanRXLed, BatCmp, i_blinki, MasterSlave, Master_Ctrl, Diag_ON, Diag_invers, i_JobIRQ, i_CIRQ, i_Error, i_Ovrun, i_Or1ms, i2cSCL, i2cSDA, b_jtgTCK_I, b_jtgTMS_I, b_jtgTDO_I, b_jtgTDI_I, jtgTCK_T, jtgTMS_T, jtgTDO_T, jtgTDI_T, impbusGoNRst, ExtMem_OFF,chip_reset, ISR, IER, PIR, MER, KIND_OF_INTR, POS_N_NEG, flags, GPIO_T, b_GPIO_I, nFan, Tacho)
	begin
		-- default value: always = 0
		loc_rd_data <= (others => '0');
		if loc_rd_acc=H then    -- read
			if loc_addr(7 downto 2)=DF_LED_ILS_ADDR then
				-- LEDs
				loc_rd_data(0) <= OKLed;
				loc_rd_data(1) <= ErrorLed;
				loc_rd_data(2) <= PowerLed;
				loc_rd_data(3) <= LinkLed;
				if ((C_TARGET=DF_TARGET_IMP2) or (C_TARGET>=DF_TARGET_SUP_ALL)) then
					loc_rd_data(4) <= LanLnkLed;
					loc_rd_data(5) <= LanRXLed;
					-- Battery monitoring
					loc_rd_data(8) <= BatCmp;
				end if;
				loc_rd_data(6) <= nFan;
				loc_rd_data(7) <= Tacho;
				-- INFOLINK Slave
				loc_rd_data(16) <= CIRQ0en;
				loc_rd_data(17) <= CIRQ1en;
				loc_rd_data(18) <= CmpEn;
				loc_rd_data(19) <= i_blinki; -- is reg in inst. infolinkMS
				loc_rd_data(22 downto 20)<= C_CARD_TYP;
				if C_TARGET=DF_TARGET_IMP2 then
					loc_rd_data(28 downto 24)<= i_AddrS(4 downto 0);
				else
					loc_rd_data(30 downto 24)<= i_AddrS(6 downto 0);
				end if;
				loc_rd_data(31) <= MasterSlave;
			elsif loc_addr(7 downto 2)=DF_ILM_ADDR then
				-- INFOLINK Master
				loc_rd_data(7 downto 0) <= Master_Ctrl;
				loc_rd_data(8) <= Diag_ON;
				loc_rd_data(9) <= Diag_invers;

				loc_rd_data(16) <= i_JobIRQ;
				loc_rd_data(20) <= i_CIRQ;
				loc_rd_data(21) <= i_Error;
				loc_rd_data(22) <= i_Ovrun;
				loc_rd_data(23) <= i_Or1ms;
			elsif loc_addr(7 downto 2)=DF_I2C_ADDR then
				-- I2C
				loc_rd_data(0) <= i2cSCL;
				loc_rd_data(1) <= i2cSDA;
				
				loc_rd_data(8) <= X10_Uart;
				loc_rd_data(9) <= X10_Uart_inv;
				loc_rd_data(10) <= X10_Uart_route;
				
				loc_rd_data(22 downto 16) <= FanPwm;
				
				loc_rd_data(24) <= GinRing;
				loc_rd_data(25) <= GinAutoClose;
			elsif loc_addr(7 downto 2)=DF_JTAG_ADDR then
				-- selfprogramming JTAG-Port
				loc_rd_data(0) <= b_jtgTCK_I;--jtgTCK;
				loc_rd_data(1) <= b_jtgTMS_I;--jtgTMS;
				loc_rd_data(2) <= b_jtgTDO_I;--jtgTDO;
				loc_rd_data(3) <= b_jtgTDI_I;--jtgTDI;
				loc_rd_data(16) <= jtgTCK_T;
				loc_rd_data(17) <= jtgTMS_T;
				loc_rd_data(18) <= jtgTDO_T;
				loc_rd_data(19) <= jtgTDI_T;
				if (C_NUM_OF_GPIO/=0) then
					for i in 0 to C_NUM_OF_GPIO-1 loop
						loc_rd_data(8+i) <=  b_GPIO_I(i);
						loc_rd_data(24+i) <= GPIO_T(i);
					end loop;
				end if;
			elsif loc_addr(7 downto 2)=DF_MEM_ADDR then
				-- Memory
				loc_rd_data <= MemReg;
			elsif loc_addr(7 downto 2)=DF_TARGET_ADDR then
				if (DF_FLAGS = 1) then
					loc_rd_data <= flags;
				end if;
				if ((C_TARGET=DF_TARGET_IMP2) or (C_TARGET>=DF_TARGET_SUP_ALL)) then
					-- IMPBus
					loc_rd_data(0) <= impbusGoNRst;
				end if;
				if (C_TARGET/=DF_TARGET_IMP2) then
					-- ExtMem OFF (not sup. on imp2)
					loc_rd_data(8) <= ExtMem_OFF;
				end if;
				-- addr switch (the hole byte:))
				if C_TARGET=DF_TARGET_IMP2 then
					loc_rd_data(28 downto 24)<= i_AddrS(4 downto 0);
				else
					loc_rd_data(31 downto 24)<= i_AddrS;
				end if;
			elsif loc_addr(7 downto 2)=DF_INT_ISR_ADDR then
				for i in ISR'range
				loop
					loc_rd_data(i) <= ISR(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_INT_IER_ADDR then
				for i in IER'range
				loop
					loc_rd_data(i) <= IER(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_INT_PIR_ADDR then
				for i in PIR'range
				loop
					loc_rd_data(i) <= PIR(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_INT_MER_ADDR then
				for i in MER'range
				loop
					loc_rd_data(i) <= MER(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_INT_KIND_ADDR then
				for i in KIND_OF_INTR'range
				loop
					loc_rd_data(i) <= KIND_OF_INTR(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_INT_P_N_ADDR then
				for i in POS_N_NEG'range
				loop
					loc_rd_data(i) <= POS_N_NEG(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_PI_CNT0 then
				loc_rd_data(15 downto 0) <= pi_cnt(0);
				if C_CONF_PI_COUNTER=1 then
					loc_rd_data(20 downto 16) <= PI_Select(0);
				end if;
			elsif loc_addr(7 downto 2)=DF_PI_CNT1 then
				loc_rd_data(15 downto 0) <= pi_cnt(1);
				if C_CONF_PI_COUNTER=1 then
					loc_rd_data(20 downto 16) <= PI_Select(1);
				end if;
			elsif loc_addr(7 downto 2)=DF_INT_CIR_ADDR then
				for i in CIR'range
				loop
					loc_rd_data(i) <= CIR(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_FREE1_ADDR then
				for i in i_Free1'range
				loop
					loc_rd_data(i) <= i_Free1(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_FREE2_ADDR then
				for i in i_Free2'range
				loop
					loc_rd_data(i) <= i_Free2(i);
				end loop;
			elsif loc_addr(7 downto 2)=DF_SVN_ADDR then
				loc_rd_data <= C_SVN_NO;
			else
				loc_rd_data <= C_REVISION(31 downto 16) & i_HW_Rev & C_REVISION(11 downto 0) ;
				--190406	loc_rd_data(31 downto 28) <= CONV_STD_LOGIC_VECTOR(C_TARGET,4);
			end if;   -- end of addr decod
		end if;
	end process;
end implementation;