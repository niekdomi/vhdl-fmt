--------------------------------------------------------------------------------
--	ppc_module_v2.vhd
--------------------------------------------------------------------------------
--
--	project     : ppc module
--	programmer  : C. Leuthold, INDEL AG
--	date        : 04.01.2006
--	version     : 1.00
--	language    : VHDL 
--	system      : ise / v2p
--
--------------------------------------------------------------------------------
--	29.05.2006-le	- add debug input ni_ppc_halt: 
--					  not connected or H, ppc start after init / L, ppc wait after init
--	30.05.2006-le	- correct name i_reset to ni_reset (L-active)
--					- set ppc generic C_DISABLE_OPERAND_FORWARDING to 0
--					- remove extmem_ and reg_ pins and add config opbifs 0..4
--	12.06.2006-le	- plb_sdram: add C_SDRAM_DRIVER_STRENGTH
--	14.06.2006-le	- change sdram vector ios from to to downto
--	11.09.2006-le	- add i_ppc_crit_irq
--					- ! correct plb2opb: C_NUM_ADDR_RNG to 3
--						8000_0000-8000_08FF / 0xE000_0000-0xEFFF_FFFF / 0xFFC0_0000-0xFFFF_FFFF
--	13.10.2006-le	- ! correct gnd and vcc vectorlength at inst opb
--	25.10.2006-le	- add ISOCM bus: new generics C_ISOCM_BOOT_RAM := 0, and C_NUM_OF_BOOT_BRAMS := 4
--						change lib boot_ram_sys_elaborate_v1_00_a to boot_ram_sys_isocm
--	27.10.2006-le	- ! C_SDRAM_DRIVER_STRENGTH on plb_sdram was 1
--						sdram K4s281633H support this function, but it do not 
--						work with 99MHz -> C_SDRAM_DRIVER_STRENGTH=0!!! 
--	23.01.2007-le	- ! plb2opb: C_RNG0_HIGHADDR form 8000_08FF to 8fff_ffff
--	11.05.2007-le	add svn keywords
--	01.06.2007-le	opb : entity opb_v20_v1_10_b.opb_v20: correct net_vcc/gnd64
--						range  (x to 0) to (0 to x)
--	04.01.2007-le	- ! ocm : remove bram reset for better timing (99MHz to 148.5MHz)
--	12.02.2008-le	- plb_bram: add sec. map (addr + 0x8000000) (but no cl support)
--	08.09.2008-le	- rename to ppc_module_v2.vhd (virtex2 support)
--	24.11.2008-le	- isocm error: bramcontent change from isocm side even 
--						though WEn is connected to gnd.
--					- add isocm-bram wen from fix gnd to dcmLocked to use the 
--						inverted bram wen use isocm en to save power.
--	27.01.2009-le	- remove inverted bram wen
--------------------------------------------------------------------------------
--$Rev:: 853                                                                   $
--$Author:: leuthold                                                           $
--$Date:: 2009-01-28 08:36:26 +0100 (Mi., 28 Jan 2009)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library boot_ram_sys_isocm;
use boot_ram_sys_isocm.all;

library jtagppc_cntlr_v2_00_a;
use jtagppc_cntlr_v2_00_a.all;

library opb_bram_if_cntlr_v1_00_a;
use opb_bram_if_cntlr_v1_00_a.all;

library opb_v20_v1_10_b;
use opb_v20_v1_10_b.all;

library plb_bram_if_cntlr_v1_00_a;
use plb_bram_if_cntlr_v1_00_a.all;

library plb_sdram_v1_00_e;
use plb_sdram_v1_00_e.all;

library plb_v34_v1_02_a;
use plb_v34_v1_02_a.all;

library plb_v34_v1_02_a_cs;
use plb_v34_v1_02_a_cs.all;

library plb2opb_bridge_v1_01_a;
use plb2opb_bridge_v1_01_a.all;

library ppc405_v2_00_c;
use ppc405_v2_00_c.all;

library proc_sys_reset_v1_00_a;
use proc_sys_reset_v1_00_a.all;

library opb_if;
use opb_if.all;

library opb_uart;
use opb_uart.all;

library plb_bram;
use plb_bram.all;

library plb2opb;
use plb2opb.all;

entity ppc_module is
	generic (
		C_PLB_CHIPSCOPE : integer range 0 to 1 := 0;
		C_INDEL_PLB_BRAM : integer range 0 to 1 := 0;
		C_INDEL_PLB2OPB : integer range 0 to 1 := 0;
		C_SDRAM_WIDTH : integer := 32;
		C_NUM_PLBBRAM_IF : integer range 0 to 4:= 1;
		C_BASEADDR_PLBBRAM_IF_1 : std_logic_vector := X"7000_0000";
		C_BASEADDR_PLBBRAM_IF_2 : std_logic_vector := X"7100_0000";
		C_BASEADDR_PLBBRAM_IF_3 : std_logic_vector := X"7200_0000";
		C_BASEADDR_PLBBRAM_IF_4 : std_logic_vector := X"7300_0000";
		C_HIGHADDR_PLBBRAM_IF_1 : std_logic_vector := X"70FF_FFFF";
		C_HIGHADDR_PLBBRAM_IF_2 : std_logic_vector := X"71FF_FFFF";
		C_HIGHADDR_PLBBRAM_IF_3 : std_logic_vector := X"72FF_FFFF";
		C_HIGHADDR_PLBBRAM_IF_4 : std_logic_vector := X"73FF_FFFF";
		C_NUM_OPB_IF : integer range 0 to 4:= 2;
		C_BASEADDR_OPB_IF_1 : std_logic_vector := X"8000_0800";
		C_BASEADDR_OPB_IF_2 : std_logic_vector := X"E000_0000";
		C_BASEADDR_OPB_IF_3 : std_logic_vector := X"A000_0000";
		C_BASEADDR_OPB_IF_4 : std_logic_vector := X"B000_0000";
		C_HIGHADDR_OPB_IF_1 : std_logic_vector := X"8000_08FF";
		C_HIGHADDR_OPB_IF_2 : std_logic_vector := X"EFFF_FFFF";
		C_HIGHADDR_OPB_IF_3 : std_logic_vector := X"AFFF_FFFF";
		C_HIGHADDR_OPB_IF_4 : std_logic_vector := X"BFFF_FFFF";
		C_NUM_UARTS : integer range 0 to 4 := 1;
		C_BUS_CLK_FREQ :integer := 99_000_000;
		C_OPB_BOOT_RAM : integer := 1;
		C_ISOCM_BOOT_RAM : integer := 0;
		C_NUM_OF_BOOT_BRAMS : integer := 4;
		C_ISOCMCLJRATIO : positive range 1 to 8 := 2
	);
	port (
		-- clocks and reset
		i_dcmLocked : in std_logic;
		i_ocm_clk : in std_logic;
		i_ppc_clk : in std_logic;
		i_plb_clk : in std_logic;
		i_opb_clk : in std_logic;
		o_periph_rst : out std_logic;
		ni_reset : in std_logic := H;
		-- ppc interrupt
		i_ppc_ext_irq : in std_logic := L;
		i_ppc_crit_irq : in std_logic := L;
		-- debug
		ni_ppc_halt : in std_logic := H;
		o_isocm_addr : out std_logic_vector(8 to 28);
		o_isocm_en : out std_logic;
		-- sdram
		no_sdCAS : out std_logic;
		no_sdCS : out std_logic;
		no_sdRAS : out std_logic;
		no_sdWE : out std_logic;
		o_sdCKE : out std_logic;
		o_sdCLK : out std_logic;
		o_sdADR : out std_logic_vector(11 downto 0);
		o_sdBAdr : out std_logic_vector(1 downto 0);
		o_sdDQM : out std_logic_vector(C_SDRAM_WIDTH/8-1 downto 0);
		b_sdDAT_I : in std_logic_vector(C_SDRAM_WIDTH-1 downto 0);
		b_sdDAT_O : out std_logic_vector(C_SDRAM_WIDTH-1 downto 0);
		b_sdDAT_T : out std_logic_vector(C_SDRAM_WIDTH-1 downto 0);
		-- sio
		ni_sioRX : in std_logic_vector(C_NUM_UARTS-1 downto 0);
		no_sioTX : out std_logic_vector(C_NUM_UARTS-1 downto 0);
		ni_sioRTS : in std_logic_vector(C_NUM_UARTS-1 downto 0);
		no_sioCTS : out std_logic_vector(C_NUM_UARTS-1 downto 0);
		o_sio_txInt : out std_logic_vector(C_NUM_UARTS-1 downto 0);
		o_sio_rxInt : out std_logic_vector(C_NUM_UARTS-1 downto 0);
		o_485_RnW : out std_logic_vector(C_NUM_UARTS-1 downto 0);
		-- plb bram intrerfaces
		o_plbbram_Rst : out std_logic_vector(0 to C_NUM_PLBBRAM_IF-1);
		o_plbbram_Clk : out std_logic_vector(0 to C_NUM_PLBBRAM_IF-1);
		o_plbbram_EN : out std_logic_vector(0 to C_NUM_PLBBRAM_IF-1);
		o_plbbram_WEN : out std_logic_vector(0 to 8*C_NUM_PLBBRAM_IF-1);
		o_plbbram_Addr : out std_logic_vector(0 to 32*C_NUM_PLBBRAM_IF-1);
		i_plbbram_Data : in std_logic_vector(0 to 64*C_NUM_PLBBRAM_IF-1) := (others => L);
		o_plbbram_Data : out std_logic_vector(0 to 64*C_NUM_PLBBRAM_IF-1);
		-- opb interfaces
		o_opbif_addr :       out std_logic_vector(32*C_NUM_OPB_IF-1 downto 0);
		o_opbif_rd_acc :     out std_logic_vector(C_NUM_OPB_IF-1 downto 0);
		o_opbif_wr_acc :     out std_logic_vector(C_NUM_OPB_IF-1 downto 0);
		o_opbif_byte_ebl :   out std_logic_vector(4*C_NUM_OPB_IF-1 downto 0);
		o_opbif_wr_data :    out std_logic_vector(32*C_NUM_OPB_IF-1 downto 0);
		i_opbif_rd_data :     in std_logic_vector(32*C_NUM_OPB_IF-1 downto 0);
		i_opbif_rd_acc_done : in std_logic_vector(C_NUM_OPB_IF-1 downto 0);
		i_opbif_wr_acc_done : in std_logic_vector(C_NUM_OPB_IF-1 downto 0)
	);
end ppc_module;

architecture STRUCTURE of ppc_module is
	type t_std_l_v_array is array(0 to 3) of std_logic_vector(0 to 31);
	constant C_FAMILY : string := "virtex2p";
	constant C_BASEADDR_PLBBRAM_IF : t_std_l_v_array := (C_BASEADDR_PLBBRAM_IF_1, C_BASEADDR_PLBBRAM_IF_2, C_BASEADDR_PLBBRAM_IF_3, C_BASEADDR_PLBBRAM_IF_4);
	constant C_HIGHADDR_PLBBRAM_IF : t_std_l_v_array := (C_HIGHADDR_PLBBRAM_IF_1, C_HIGHADDR_PLBBRAM_IF_2, C_HIGHADDR_PLBBRAM_IF_3, C_HIGHADDR_PLBBRAM_IF_4);
	constant C_BASEADDR_OPB_IF : t_std_l_v_array := (C_BASEADDR_OPB_IF_1, C_BASEADDR_OPB_IF_2, C_BASEADDR_OPB_IF_3, C_BASEADDR_OPB_IF_4);
	constant C_HIGHADDR_OPB_IF : t_std_l_v_array := (C_HIGHADDR_OPB_IF_1, C_HIGHADDR_OPB_IF_2, C_HIGHADDR_OPB_IF_3, C_HIGHADDR_OPB_IF_4);
	constant C_BASEADDR_UART : t_std_l_v_array := (X"8000_0000", X"8000_0100", X"8000_0200", X"8000_0300");
	constant C_HIGHADDR_UART : t_std_l_v_array := (X"8000_00FF", X"8000_01FF", X"8000_02FF", X"8000_03FF");
	constant C_PLB_CLK_PERIOD_PS : integer := 1_000_000_000/(C_BUS_CLK_FREQ/1000)-1;
	constant C_PLB_NUM_MASTERS : integer := 2;
	constant C_PLB_NUM_SLAVES : integer := 2+C_NUM_PLBBRAM_IF;
	constant C_PLB_DWIDTH : integer := 64;
	constant C_PLB_AWIDTH : integer := 32;
	constant C_PLB_MID_WIDTH : integer := pkg_log2(C_PLB_NUM_MASTERS);
	constant C_OPB_AWIDTH : integer := 32;
	constant C_OPB_DWIDTH : integer := 32;
	constant C_OPB_NUM_MASTERS : integer := 1;
	constant C_OPB_NUM_SLAVES : integer := C_OPB_BOOT_RAM+C_NUM_OPB_IF+C_NUM_UARTS;
	constant C_OPB_CLK_PERIOD_PS : integer := C_PLB_CLK_PERIOD_PS;
	constant DF_ISOCMCLJRATIO : std_logic_vector(0 to 3) := conv_std_logic_vector(2**C_ISOCMCLJRATIO-1, 4);
	-- Internal signals

	signal Boot_RW_BRAM_Addr : std_logic_vector(0 to 31);
	signal Boot_RW_BRAM_Clk : std_logic;
	signal Boot_RW_BRAM_Din : std_logic_vector(0 to 31);
	signal Boot_RW_BRAM_Dout : std_logic_vector(0 to 31);
	signal Boot_RW_BRAM_EN : std_logic;
	signal Boot_RW_BRAM_WEN : std_logic_vector(0 to 3);
	signal C405JTGTDO : std_logic;
	signal C405JTGTDOEN : std_logic;
	signal C405RSTCHIPRESETREQ : std_logic;
	signal C405RSTCORERESETREQ : std_logic;
	signal C405RSTSYSRESETREQ : std_logic;
	signal DBGC405DEBUGHALT : std_logic;
	signal Irq : std_logic;
	signal Crit_Irq : std_logic;
	signal JTGC405TCK : std_logic;
	signal JTGC405TDI : std_logic;
	signal JTGC405TMS : std_logic;
	signal JTGC405TRSTNEG : std_logic;
	signal RSTC405RESETCHIP : std_logic;
	signal RSTC405RESETCORE : std_logic;
	signal RSTC405RESETSYS : std_logic;
	signal dcmLocked : std_logic;
	signal extmem_addr : std_logic_vector(31 downto 0);
	signal extmem_byte_ebl : std_logic_vector(3 downto 0);
	signal extmem_rd_acc : std_logic;
	signal extmem_rd_acc_done : std_logic;
	signal extmem_rd_data : std_logic_vector(31 downto 0);
	signal extmem_wr_acc : std_logic;
	signal extmem_wr_acc_done : std_logic;
	signal extmem_wr_data : std_logic_vector(31 downto 0);
	signal net_gnd0 : std_logic;
	signal net_gnd64 : std_logic_vector(0 to 63);
	signal net_vcc0 : std_logic;
	signal net_vcc64 : std_logic_vector(0 to 63);
	signal opb_M_ABus : std_logic_vector(0 to C_OPB_AWIDTH*C_OPB_NUM_MASTERS-1);
	signal opb_M_BE : std_logic_vector(0 to (C_OPB_DWIDTH+7)/8*C_OPB_NUM_MASTERS-1);
	signal opb_M_DBus : std_logic_vector(0 to C_OPB_DWIDTH*C_OPB_NUM_MASTERS-1);
	signal opb_M_RNW : std_logic_vector(0 to C_OPB_NUM_MASTERS-1);
	signal opb_M_busLock : std_logic_vector(0 to C_OPB_NUM_MASTERS-1);
	signal opb_M_request : std_logic_vector(0 to C_OPB_NUM_MASTERS-1);
	signal opb_M_select : std_logic_vector(0 to C_OPB_NUM_MASTERS-1);
	signal opb_M_seqAddr : std_logic_vector(0 to C_OPB_NUM_MASTERS-1);
	signal opb_OPB_ABus : std_logic_vector(0 to C_OPB_AWIDTH-1);
	signal opb_OPB_BE : std_logic_vector(0 to (C_OPB_DWIDTH+7)/8-1);
	signal opb_OPB_DBus : std_logic_vector(0 to C_OPB_DWIDTH-1);
	signal opb_OPB_MGrant : std_logic_vector(0 to C_OPB_NUM_MASTERS-1);
	signal opb_OPB_RNW : std_logic;
	signal opb_OPB_Rst : std_logic;
	signal opb_OPB_errAck : std_logic;
	signal opb_OPB_retry : std_logic;
	signal opb_OPB_select : std_logic;
	signal opb_OPB_seqAddr : std_logic;
	signal opb_OPB_timeout : std_logic;
	signal opb_OPB_xferAck : std_logic;
	signal opb_Sl_DBus : std_logic_vector(0 to 32*C_OPB_NUM_SLAVES-1);
	signal opb_Sl_errAck : std_logic_vector(0 to C_OPB_NUM_SLAVES-1);
	signal opb_Sl_retry : std_logic_vector(0 to C_OPB_NUM_SLAVES-1);
	signal opb_Sl_toutSup : std_logic_vector(0 to C_OPB_NUM_SLAVES-1);
	signal opb_Sl_xferAck : std_logic_vector(0 to C_OPB_NUM_SLAVES-1);
	signal opb_clk : std_logic;
	signal peripheral_reset : std_logic_vector(0 to 0);
	signal plbDPR_BRAM_Addr : std_logic_vector(0 to 31);
	signal plbDPR_BRAM_Clk : std_logic;
	signal plbDPR_BRAM_Din : std_logic_vector(0 to 63);
	signal plbDPR_BRAM_Dout : std_logic_vector(0 to 63);
	signal plbDPR_BRAM_EN : std_logic;
	signal plbDPR_BRAM_Rst : std_logic;
	signal plbDPR_BRAM_WEN : std_logic_vector(0 to 7);
	signal plb_M_ABus : std_logic_vector(0 to C_PLB_AWIDTH*C_PLB_NUM_MASTERS-1);
	signal plb_M_BE : std_logic_vector(0 to C_PLB_DWIDTH/8*C_PLB_NUM_MASTERS-1);
	signal plb_M_MSize : std_logic_vector(0 to 2*C_PLB_NUM_MASTERS-1);
	signal plb_M_RNW : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_abort : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_busLock : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_compress : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_guarded : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_lockErr : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_ordered : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_priority : std_logic_vector(0 to 2*C_PLB_NUM_MASTERS-1);
	signal plb_M_rdBurst : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_request : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_size : std_logic_vector(0 to 4*C_PLB_NUM_MASTERS-1);
	signal plb_M_type : std_logic_vector(0 to 3*C_PLB_NUM_MASTERS-1);
	signal plb_M_wrBurst : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_M_wrDBus : std_logic_vector(0 to C_PLB_DWIDTH*C_PLB_NUM_MASTERS-1);
	signal plb_PLB2OPB_rearb : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_PLB_ABus : std_logic_vector(0 to 31);
	signal plb_PLB_BE : std_logic_vector(0 to 7);
	signal plb_PLB_MAddrAck : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MBusy : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MErr : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MRdBTerm : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MRdDAck : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MRdDBus : std_logic_vector(0 to C_PLB_DWIDTH*C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MRdWdAddr : std_logic_vector(0 to 4*C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MRearbitrate : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MSSize : std_logic_vector(0 to 2*C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MSize : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MWrBTerm : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_MWrDAck : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_PAValid : std_logic;
	signal plb_PLB_RNW : std_logic;
	signal plb_PLB_Rst : std_logic;
	signal plb_PLB_SAValid : std_logic;
	signal plb_PLB_SMBusy : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_SMErr : std_logic_vector(0 to C_PLB_NUM_MASTERS-1);
	signal plb_PLB_abort : std_logic;
	signal plb_PLB_busLock : std_logic;
	signal plb_PLB_compress : std_logic;
	signal plb_PLB_guarded : std_logic;
	signal plb_PLB_lockErr : std_logic;
	signal plb_PLB_masterID : std_logic_vector(0 to C_PLB_MID_WIDTH-1);
	signal plb_PLB_ordered : std_logic;
	signal plb_PLB_pendPri : std_logic_vector(0 to 1);
	signal plb_PLB_pendReq : std_logic;
	signal plb_PLB_rdBurst : std_logic;
	signal plb_PLB_rdPrim : std_logic;
	signal plb_PLB_reqPri : std_logic_vector(0 to 1);
	signal plb_PLB_size : std_logic_vector(0 to 3);
	signal plb_PLB_type : std_logic_vector(0 to 2);
	signal plb_PLB_wrBurst : std_logic;
	signal plb_PLB_wrDBus : std_logic_vector(0 to 63);
	signal plb_PLB_wrPrim : std_logic;
	signal plb_Sl_MBusy : std_logic_vector(0 to C_PLB_NUM_SLAVES*C_PLB_NUM_MASTERS-1);
	signal plb_Sl_MErr : std_logic_vector(0 to C_PLB_NUM_SLAVES*C_PLB_NUM_MASTERS-1);
	signal plb_Sl_SSize : std_logic_vector(0 to C_PLB_NUM_SLAVES*C_PLB_NUM_MASTERS-1);
	signal plb_Sl_addrAck : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_rdBTerm : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_rdComp : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_rdDAck : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_rdDBus : std_logic_vector(0 to 64*C_PLB_NUM_SLAVES-1);
	signal plb_Sl_rdWdAddr : std_logic_vector(0 to 4*C_PLB_NUM_SLAVES-1);
	signal plb_Sl_rearbitrate : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_wait : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_wrBTerm : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_wrComp : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_Sl_wrDAck : std_logic_vector(0 to C_PLB_NUM_SLAVES-1);
	signal plb_clk : std_logic;
	signal ppc_clk : std_logic;
	signal ocm_clk : std_logic;
	signal reg_addr : std_logic_vector(31 downto 0);
	signal reg_byte_ebl : std_logic_vector(3 downto 0);
	signal reg_rd_acc : std_logic;
	signal reg_rd_acc_done : std_logic;
	signal reg_rd_data : std_logic_vector(31 downto 0);
	signal reg_wr_acc : std_logic;
	signal reg_wr_acc_done : std_logic;
	signal reg_wr_data : std_logic_vector(31 downto 0);
	signal sio_rxInt : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sio_txInt : std_logic_vector(C_NUM_UARTS-1 downto 0);
	signal sys_bus_reset : std_logic_vector(0 to 0);
	signal system_nReset : std_logic;
	signal sdADR : std_logic_vector(0 to 11);
	signal sdBAdr : std_logic_vector(0 to 1);
	signal sdDQM : std_logic_vector(0 to C_SDRAM_WIDTH/8-1);
	signal sdDAT_I : std_logic_vector(0 to C_SDRAM_WIDTH-1);
	signal sdDAT_O : std_logic_vector(0 to C_SDRAM_WIDTH-1);
	signal sdDAT_T : std_logic_vector(0 to C_SDRAM_WIDTH-1);
	signal keep_isocm_en : std_logic := L;
	signal keep_isocm_addr : std_logic_vector(0 to 31) := (others => L);
	signal isocm_data : std_logic_vector(0 to 63) := (others => L);
	signal ISARCVALUE : std_logic_vector(0 to 7) := x"ff"; -- 0xff00_0000 .. 0xffff_ffff
	signal ISCNTLVALUE : std_logic_vector(0 to 7) := "0000" & DF_ISOCMCLJRATIO; -- 0: enable, 5..7 clk ratio "011" -> 2:1
	
	attribute KEEP : string;
	attribute KEEP of dcmLocked : signal is "TRUE";
	attribute KEEP of keep_isocm_addr : signal is "TRUE";
	attribute KEEP of keep_isocm_en : signal is "TRUE";
begin

	-- Internal assignments

	dcmLocked <= i_dcmLocked;
	ppc_clk <= i_ppc_clk;
	plb_clk <= i_plb_clk;
	opb_clk <= i_opb_clk;
	ocm_clk <= i_ocm_clk;
	o_periph_rst <= peripheral_reset(0);
	system_nReset <= ni_reset;
	Irq <= i_ppc_ext_irq;
	Crit_Irq <= i_ppc_crit_irq;
	o_sio_txInt <= sio_txInt;
	o_sio_rxInt <= sio_rxInt;
	plb_PLB2OPB_rearb(1 to C_PLB_NUM_SLAVES-1)  <= (others => L);
	net_gnd0 <= L;
	net_gnd64(0 to 63) <= B"0000000000000000000000000000000000000000000000000000000000000000";
	net_vcc0 <= H;
	net_vcc64(0 to 63) <= B"1111111111111111111111111111111111111111111111111111111111111111";
	
	ppc405_sys : entity ppc405_v2_00_c.ppc405_top
	generic map (
		C_ISOCM_DCR_BASEADDR => B"0000010000",	-- ISINIT:0x10, ISFILL 0x11, ISARC 0x12, ISCNTL 0x13
		C_ISOCM_DCR_HIGHADDR => B"0000010011",	-- unused
		C_DSOCM_DCR_BASEADDR => B"0000100000",	-- 0x20..0x23
		C_DSOCM_DCR_HIGHADDR => B"0000100011",	-- unused
		C_DISABLE_OPERAND_FORWARDING => 0,
		C_DETERMINISTIC_MULT => 0,
		C_MMU_ENABLE => 1,
		C_DCR_RESYNC => 0
	)
	port map (
		C405CPMCORESLEEPREQ => open,
		C405CPMMSRCE => open,
		C405CPMMSREE => open,
		C405CPMTIMERIRQ => open,
		C405CPMTIMERRESETREQ => open,
		C405XXXMACHINECHECK => open,
		CPMC405CLOCK => ppc_clk,
		CPMC405CORECLKINACTIVE => net_gnd0,
		CPMC405CPUCLKEN => net_vcc0,
		CPMC405JTAGCLKEN => net_vcc0,
		CPMC405TIMERCLKEN => net_vcc0,
		CPMC405TIMERTICK => net_vcc0,
		MCBCPUCLKEN => net_vcc0,
		MCBTIMEREN => net_vcc0,
		MCPPCRST => net_vcc0,
		PLBCLK => plb_clk,
		DCRCLK => net_gnd0,
		C405RSTCHIPRESETREQ => C405RSTCHIPRESETREQ,
		C405RSTCORERESETREQ => C405RSTCORERESETREQ,
		C405RSTSYSRESETREQ => C405RSTSYSRESETREQ,
		RSTC405RESETCHIP => RSTC405RESETCHIP,
		RSTC405RESETCORE => RSTC405RESETCORE,
		RSTC405RESETSYS => RSTC405RESETSYS,
		C405PLBICUABUS => plb_M_ABus(32 to 63),
		C405PLBICUBE => plb_M_BE(8 to 15),
		C405PLBICURNW => plb_M_RNW(1),
		C405PLBICUABORT => plb_M_abort(1),
		C405PLBICUBUSLOCK => plb_M_busLock(1),
		C405PLBICUU0ATTR => plb_M_compress(1),
		C405PLBICUGUARDED => plb_M_guarded(1),
		C405PLBICULOCKERR => plb_M_lockErr(1),
		C405PLBICUMSIZE => plb_M_MSize(2 to 3),
		C405PLBICUORDERED => plb_M_ordered(1),
		C405PLBICUPRIORITY => plb_M_priority(2 to 3),
		C405PLBICURDBURST => plb_M_rdBurst(1),
		C405PLBICUREQUEST => plb_M_request(1),
		C405PLBICUSIZE => plb_M_size(4 to 7),
		C405PLBICUTYPE => plb_M_type(3 to 5),
		C405PLBICUWRBURST => plb_M_wrBurst(1),
		C405PLBICUWRDBUS => plb_M_wrDBus(64 to 127),
		C405PLBICUCACHEABLE => open,
		PLBC405ICUADDRACK => plb_PLB_MAddrAck(1),
		PLBC405ICUBUSY => plb_PLB_MBusy(1),
		PLBC405ICUERR => plb_PLB_MErr(1),
		PLBC405ICURDBTERM => plb_PLB_MRdBTerm(1),
		PLBC405ICURDDACK => plb_PLB_MRdDAck(1),
		PLBC405ICURDDBUS => plb_PLB_MRdDBus(64 to 127),
		PLBC405ICURDWDADDR => plb_PLB_MRdWdAddr(4 to 7),
		PLBC405ICUREARBITRATE => plb_PLB_MRearbitrate(1),
		PLBC405ICUWRBTERM => plb_PLB_MWrBTerm(1),
		PLBC405ICUWRDACK => plb_PLB_MWrDAck(1),
		PLBC405ICUSSIZE => plb_PLB_MSSize(2 to 3),
		PLBC405ICUSERR => plb_PLB_SMErr(1),
		PLBC405ICUSBUSYS => plb_PLB_SMBusy(1),
		C405PLBDCUABUS => plb_M_ABus(0 to 31),
		C405PLBDCUBE => plb_M_BE(0 to 7),
		C405PLBDCURNW => plb_M_RNW(0),
		C405PLBDCUABORT => plb_M_abort(0),
		C405PLBDCUBUSLOCK => plb_M_busLock(0),
		C405PLBDCUU0ATTR => plb_M_compress(0),
		C405PLBDCUGUARDED => plb_M_guarded(0),
		C405PLBDCULOCKERR => plb_M_lockErr(0),
		C405PLBDCUMSIZE => plb_M_MSize(0 to 1),
		C405PLBDCUORDERED => plb_M_ordered(0),
		C405PLBDCUPRIORITY => plb_M_priority(0 to 1),
		C405PLBDCURDBURST => plb_M_rdBurst(0),
		C405PLBDCUREQUEST => plb_M_request(0),
		C405PLBDCUSIZE => plb_M_size(0 to 3),
		C405PLBDCUTYPE => plb_M_type(0 to 2),
		C405PLBDCUWRBURST => plb_M_wrBurst(0),
		C405PLBDCUWRDBUS => plb_M_wrDBus(0 to 63),
		C405PLBDCUCACHEABLE => open,
		C405PLBDCUWRITETHRU => open,
		PLBC405DCUADDRACK => plb_PLB_MAddrAck(0),
		PLBC405DCUBUSY => plb_PLB_MBusy(0),
		PLBC405DCUERR => plb_PLB_MErr(0),
		PLBC405DCURDBTERM => plb_PLB_MRdBTerm(0),
		PLBC405DCURDDACK => plb_PLB_MRdDAck(0),
		PLBC405DCURDDBUS => plb_PLB_MRdDBus(0 to 63),
		PLBC405DCURDWDADDR => plb_PLB_MRdWdAddr(0 to 3),
		PLBC405DCUREARBITRATE => plb_PLB_MRearbitrate(0),
		PLBC405DCUWRBTERM => plb_PLB_MWrBTerm(0),
		PLBC405DCUWRDACK => plb_PLB_MWrDAck(0),
		PLBC405DCUSSIZE => plb_PLB_MSSize(0 to 1),
		PLBC405DCUSERR => plb_PLB_SMErr(0),
		PLBC405DCUSBUSYS => plb_PLB_SMBusy(0),
		BRAMDSOCMCLK => plb_clk,
		BRAMDSOCMRDDBUS => net_gnd64(0 to 31),
		DSARCVALUE => net_gnd64(0 to 7),
		DSCNTLVALUE => net_gnd64(0 to 7),
		DSOCMBRAMABUS => open,
		DSOCMBRAMBYTEWRITE => open,
		DSOCMBRAMEN => open,
		DSOCMBRAMWRDBUS => open,
		DSOCMBUSY => open,
		BRAMISOCMCLK => ocm_clk,
		BRAMISOCMRDDBUS => isocm_data,
		ISARCVALUE => ISARCVALUE,
		ISCNTLVALUE => ISCNTLVALUE,
		ISOCMBRAMEN => keep_isocm_en,
		ISOCMBRAMEVENWRITEEN => open,
		ISOCMBRAMODDWRITEEN => open,
		ISOCMBRAMRDABUS => keep_isocm_addr(8 to 28),
		ISOCMBRAMWRABUS => open,
		ISOCMBRAMWRDBUS => open,
		C405DCRABUS => open,
		C405DCRDBUSOUT => open,
		C405DCRREAD => open,
		C405DCRWRITE => open,
		DCRC405ACK => net_gnd0,
		DCRC405DBUSIN => net_gnd64(0 to 31),
		EICC405CRITINPUTIRQ => Crit_Irq,
		EICC405EXTINPUTIRQ => Irq,
		C405JTGCAPTUREDR => open,
		C405JTGEXTEST => open,
		C405JTGPGMOUT => open,
		C405JTGSHIFTDR => open,
		C405JTGTDO => C405JTGTDO,
		C405JTGTDOEN => C405JTGTDOEN,
		C405JTGUPDATEDR => open,
		MCBJTAGEN => net_vcc0,
		JTGC405BNDSCANTDO => net_gnd0,
		JTGC405TCK => JTGC405TCK,
		JTGC405TDI => JTGC405TDI,
		JTGC405TMS => JTGC405TMS,
		JTGC405TRSTNEG => JTGC405TRSTNEG,
		C405DBGMSRWE => open,
		C405DBGSTOPACK => open,
		C405DBGWBCOMPLETE => open,
		C405DBGWBFULL => open,
		C405DBGWBIAR => open,
		DBGC405DEBUGHALT => DBGC405DEBUGHALT,
		DBGC405EXTBUSHOLDACK => net_gnd0,
		DBGC405UNCONDDEBUGEVENT => net_gnd0,
		C405TRCCYCLE => open,
		C405TRCEVENEXECUTIONSTATUS => open,
		C405TRCODDEXECUTIONSTATUS => open,
		C405TRCTRACESTATUS => open,
		C405TRCTRIGGEREVENTOUT => open,
		C405TRCTRIGGEREVENTTYPE => open,
		TRCC405TRACEDISABLE => net_gnd0,
		TRCC405TRIGGEREVENTIN => net_gnd0
	);
	
YES_C_PLB_CHIPSCOPE : if (C_PLB_CHIPSCOPE=1) generate
begin
	plb : entity plb_v34_v1_02_a_cs.plb_v34
	generic map (
		C_PLB_NUM_MASTERS => C_PLB_NUM_MASTERS,
		C_PLB_NUM_SLAVES => C_PLB_NUM_SLAVES,
		C_PLB_MID_WIDTH => C_PLB_MID_WIDTH,
		C_PLB_AWIDTH => C_PLB_AWIDTH,
		C_PLB_DWIDTH => C_PLB_DWIDTH,
		C_DCR_INTFCE => 0,
		C_BASEADDR => B"1111111111",
		C_HIGHADDR => B"0000000000",
		C_DCR_AWIDTH => 10,
		C_DCR_DWIDTH => 32,
		C_EXT_RESET_HIGH => 1,
		C_IRQ_ACTIVE => H,
		C_NUM_OPBCLK_PLB2OPB_REARB => 5
	)
	port map (
		PLB_Clk => plb_clk,
		SYS_Rst => sys_bus_reset(0),
		PLB_Rst => plb_PLB_Rst,
		PLB_dcrAck => open,
		PLB_dcrDBus => open,
		DCR_ABus => net_gnd64(0 to 9),
		DCR_DBus => net_gnd64(0 to 31),
		DCR_Read => net_gnd0,
		DCR_Write => net_gnd0,
		M_ABus => plb_M_ABus,
		M_BE => plb_M_BE,
		M_RNW => plb_M_RNW,
		M_abort => plb_M_abort,
		M_busLock => plb_M_busLock,
		M_compress => plb_M_compress,
		M_guarded => plb_M_guarded,
		M_lockErr => plb_M_lockErr,
		M_MSize => plb_M_MSize,
		M_ordered => plb_M_ordered,
		M_priority => plb_M_priority,
		M_rdBurst => plb_M_rdBurst,
		M_request => plb_M_request,
		M_size => plb_M_size,
		M_type => plb_M_type,
		M_wrBurst => plb_M_wrBurst,
		M_wrDBus => plb_M_wrDBus,
		Sl_addrAck => plb_Sl_addrAck,
		Sl_MErr => plb_Sl_MErr,
		Sl_MBusy => plb_Sl_MBusy,
		Sl_rdBTerm => plb_Sl_rdBTerm,
		Sl_rdComp => plb_Sl_rdComp,
		Sl_rdDAck => plb_Sl_rdDAck,
		Sl_rdDBus => plb_Sl_rdDBus,
		Sl_rdWdAddr => plb_Sl_rdWdAddr,
		Sl_rearbitrate => plb_Sl_rearbitrate,
		Sl_SSize => plb_Sl_SSize,
		Sl_wait => plb_Sl_wait,
		Sl_wrBTerm => plb_Sl_wrBTerm,
		Sl_wrComp => plb_Sl_wrComp,
		Sl_wrDAck => plb_Sl_wrDAck,
		PLB_ABus => plb_PLB_ABus,
		PLB_BE => plb_PLB_BE,
		PLB_MAddrAck => plb_PLB_MAddrAck,
		PLB_MBusy => plb_PLB_MBusy,
		PLB_MErr => plb_PLB_MErr,
		PLB_MRdBTerm => plb_PLB_MRdBTerm,
		PLB_MRdDAck => plb_PLB_MRdDAck,
		PLB_MRdDBus => plb_PLB_MRdDBus,
		PLB_MRdWdAddr => plb_PLB_MRdWdAddr,
		PLB_MRearbitrate => plb_PLB_MRearbitrate,
		PLB_MWrBTerm => plb_PLB_MWrBTerm,
		PLB_MWrDAck => plb_PLB_MWrDAck,
		PLB_MSSize => plb_PLB_MSSize,
		PLB_PAValid => plb_PLB_PAValid,
		PLB_RNW => plb_PLB_RNW,
		PLB_SAValid => plb_PLB_SAValid,
		PLB_abort => plb_PLB_abort,
		PLB_busLock => plb_PLB_busLock,
		PLB_compress => plb_PLB_compress,
		PLB_guarded => plb_PLB_guarded,
		PLB_lockErr => plb_PLB_lockErr,
		PLB_masterID => plb_PLB_masterID(0 to 0),
		PLB_MSize => plb_PLB_MSize,
		PLB_ordered => plb_PLB_ordered,
		PLB_pendPri => plb_PLB_pendPri,
		PLB_pendReq => plb_PLB_pendReq,
		PLB_rdBurst => plb_PLB_rdBurst,
		PLB_rdPrim => plb_PLB_rdPrim,
		PLB_reqPri => plb_PLB_reqPri,
		PLB_size => plb_PLB_size,
		PLB_type => plb_PLB_type,
		PLB_wrBurst => plb_PLB_wrBurst,
		PLB_wrDBus => plb_PLB_wrDBus,
		PLB_wrPrim => plb_PLB_wrPrim,
		PLB_SaddrAck => open,
		PLB_SMErr => plb_PLB_SMErr,
		PLB_SMBusy => plb_PLB_SMBusy,
		PLB_SrdBTerm => open,
		PLB_SrdComp => open,
		PLB_SrdDAck => open,
		PLB_SrdDBus => open,
		PLB_SrdWdAddr => open,
		PLB_Srearbitrate => open,
		PLB_Sssize => open,
		PLB_Swait => open,
		PLB_SwrBTerm => open,
		PLB_SwrComp => open,
		PLB_SwrDAck => open,
		PLB2OPB_rearb => plb_PLB2OPB_rearb,
		ArbAddrVldReg => open,
		Bus_Error_Det => open,
		i_input => Crit_Irq
	);
end generate YES_C_PLB_CHIPSCOPE;

NO_C_PLB_CHIPSCOPE : if (C_PLB_CHIPSCOPE=0) generate
begin
	plb : entity plb_v34_v1_02_a.plb_v34
	generic map (
		C_PLB_NUM_MASTERS => C_PLB_NUM_MASTERS,
		C_PLB_NUM_SLAVES => C_PLB_NUM_SLAVES,
		C_PLB_MID_WIDTH => C_PLB_MID_WIDTH,
		C_PLB_AWIDTH => C_PLB_AWIDTH,
		C_PLB_DWIDTH => C_PLB_DWIDTH,
		C_DCR_INTFCE => 0,
		C_BASEADDR => B"1111111111",
		C_HIGHADDR => B"0000000000",
		C_DCR_AWIDTH => 10,
		C_DCR_DWIDTH => 32,
		C_EXT_RESET_HIGH => 1,
		C_IRQ_ACTIVE => H,
		C_NUM_OPBCLK_PLB2OPB_REARB => 5
	)
	port map (
		PLB_Clk => plb_clk,
		SYS_Rst => sys_bus_reset(0),
		PLB_Rst => plb_PLB_Rst,
		PLB_dcrAck => open,
		PLB_dcrDBus => open,
		DCR_ABus => net_gnd64(0 to 9),
		DCR_DBus => net_gnd64(0 to 31),
		DCR_Read => net_gnd0,
		DCR_Write => net_gnd0,
		M_ABus => plb_M_ABus,
		M_BE => plb_M_BE,
		M_RNW => plb_M_RNW,
		M_abort => plb_M_abort,
		M_busLock => plb_M_busLock,
		M_compress => plb_M_compress,
		M_guarded => plb_M_guarded,
		M_lockErr => plb_M_lockErr,
		M_MSize => plb_M_MSize,
		M_ordered => plb_M_ordered,
		M_priority => plb_M_priority,
		M_rdBurst => plb_M_rdBurst,
		M_request => plb_M_request,
		M_size => plb_M_size,
		M_type => plb_M_type,
		M_wrBurst => plb_M_wrBurst,
		M_wrDBus => plb_M_wrDBus,
		Sl_addrAck => plb_Sl_addrAck,
		Sl_MErr => plb_Sl_MErr,
		Sl_MBusy => plb_Sl_MBusy,
		Sl_rdBTerm => plb_Sl_rdBTerm,
		Sl_rdComp => plb_Sl_rdComp,
		Sl_rdDAck => plb_Sl_rdDAck,
		Sl_rdDBus => plb_Sl_rdDBus,
		Sl_rdWdAddr => plb_Sl_rdWdAddr,
		Sl_rearbitrate => plb_Sl_rearbitrate,
		Sl_SSize => plb_Sl_SSize,
		Sl_wait => plb_Sl_wait,
		Sl_wrBTerm => plb_Sl_wrBTerm,
		Sl_wrComp => plb_Sl_wrComp,
		Sl_wrDAck => plb_Sl_wrDAck,
		PLB_ABus => plb_PLB_ABus,
		PLB_BE => plb_PLB_BE,
		PLB_MAddrAck => plb_PLB_MAddrAck,
		PLB_MBusy => plb_PLB_MBusy,
		PLB_MErr => plb_PLB_MErr,
		PLB_MRdBTerm => plb_PLB_MRdBTerm,
		PLB_MRdDAck => plb_PLB_MRdDAck,
		PLB_MRdDBus => plb_PLB_MRdDBus,
		PLB_MRdWdAddr => plb_PLB_MRdWdAddr,
		PLB_MRearbitrate => plb_PLB_MRearbitrate,
		PLB_MWrBTerm => plb_PLB_MWrBTerm,
		PLB_MWrDAck => plb_PLB_MWrDAck,
		PLB_MSSize => plb_PLB_MSSize,
		PLB_PAValid => plb_PLB_PAValid,
		PLB_RNW => plb_PLB_RNW,
		PLB_SAValid => plb_PLB_SAValid,
		PLB_abort => plb_PLB_abort,
		PLB_busLock => plb_PLB_busLock,
		PLB_compress => plb_PLB_compress,
		PLB_guarded => plb_PLB_guarded,
		PLB_lockErr => plb_PLB_lockErr,
		PLB_masterID => plb_PLB_masterID(0 to 0),
		PLB_MSize => plb_PLB_MSize,
		PLB_ordered => plb_PLB_ordered,
		PLB_pendPri => plb_PLB_pendPri,
		PLB_pendReq => plb_PLB_pendReq,
		PLB_rdBurst => plb_PLB_rdBurst,
		PLB_rdPrim => plb_PLB_rdPrim,
		PLB_reqPri => plb_PLB_reqPri,
		PLB_size => plb_PLB_size,
		PLB_type => plb_PLB_type,
		PLB_wrBurst => plb_PLB_wrBurst,
		PLB_wrDBus => plb_PLB_wrDBus,
		PLB_wrPrim => plb_PLB_wrPrim,
		PLB_SaddrAck => open,
		PLB_SMErr => plb_PLB_SMErr,
		PLB_SMBusy => plb_PLB_SMBusy,
		PLB_SrdBTerm => open,
		PLB_SrdComp => open,
		PLB_SrdDAck => open,
		PLB_SrdDBus => open,
		PLB_SrdWdAddr => open,
		PLB_Srearbitrate => open,
		PLB_Sssize => open,
		PLB_Swait => open,
		PLB_SwrBTerm => open,
		PLB_SwrComp => open,
		PLB_SwrDAck => open,
		PLB2OPB_rearb => plb_PLB2OPB_rearb,
		ArbAddrVldReg => open,
		Bus_Error_Det => open
	);
end generate NO_C_PLB_CHIPSCOPE;

	opb : entity opb_v20_v1_10_b.opb_v20
	generic map (
		C_BASEADDR => X"FFFFFFFF",
		C_HIGHADDR => X"00000000",
		C_OPB_AWIDTH => C_OPB_AWIDTH,
		C_OPB_DWIDTH => C_OPB_DWIDTH,
		C_NUM_MASTERS => C_OPB_NUM_MASTERS,
		C_NUM_SLAVES => C_OPB_NUM_SLAVES,
		C_USE_LUT_OR => 1,
		C_EXT_RESET_HIGH => 1,
		C_DYNAM_PRIORITY => 0,
		C_PARK => 0,
		C_PROC_INTRFCE => 0,
		C_REG_GRANTS => 1,
		C_DEV_BLK_ID => 0,
		C_DEV_MIR_ENABLE => 0
	)
	port map (
		OPB_Clk => opb_clk,
		OPB_Rst => opb_OPB_Rst,
		SYS_Rst => sys_bus_reset(0),
		Debug_SYS_Rst => net_gnd0,
		WDT_Rst => net_gnd0,
		M_ABus => opb_M_ABus,
		M_BE => opb_M_BE,
		M_beXfer => net_gnd64(0 to C_OPB_NUM_MASTERS-1),
		M_busLock => opb_M_busLock,
		M_DBus => opb_M_DBus,
		M_DBusEn => net_gnd64(0 to C_OPB_NUM_MASTERS-1),
		M_DBusEn32_63 => net_vcc64(0 to C_OPB_NUM_MASTERS-1),
		M_dwXfer => net_gnd64(0 to C_OPB_NUM_MASTERS-1),
		M_fwXfer => net_gnd64(0 to C_OPB_NUM_MASTERS-1),
		M_hwXfer => net_gnd64(0 to C_OPB_NUM_MASTERS-1),
		M_request => opb_M_request,
		M_RNW => opb_M_RNW,
		M_select => opb_M_select,
		M_seqAddr => opb_M_seqAddr,
		Sl_beAck => net_gnd64(0 to C_OPB_NUM_SLAVES-1),
		Sl_DBus => opb_Sl_DBus,
		Sl_DBusEn => net_vcc64(0 to C_OPB_NUM_SLAVES-1),
		Sl_DBusEn32_63 => net_vcc64(0 to C_OPB_NUM_SLAVES-1),
		Sl_errAck => opb_Sl_errAck,
		Sl_dwAck => net_gnd64(0 to C_OPB_NUM_SLAVES-1),
		Sl_fwAck => net_gnd64(0 to C_OPB_NUM_SLAVES-1),
		Sl_hwAck => net_gnd64(0 to C_OPB_NUM_SLAVES-1),
		Sl_retry => opb_Sl_retry,
		Sl_toutSup => opb_Sl_toutSup,
		Sl_xferAck => opb_Sl_xferAck,
		OPB_MRequest => open,
		OPB_ABus => opb_OPB_ABus,
		OPB_BE => opb_OPB_BE,
		OPB_beXfer => open,
		OPB_beAck => open,
		OPB_busLock => open,
		OPB_rdDBus => open,
		OPB_wrDBus => open,
		OPB_DBus => opb_OPB_DBus,
		OPB_errAck => opb_OPB_errAck,
		OPB_dwAck => open,
		OPB_dwXfer => open,
		OPB_fwAck => open,
		OPB_fwXfer => open,
		OPB_hwAck => open,
		OPB_hwXfer => open,
		OPB_MGrant => opb_OPB_MGrant,
		OPB_pendReq => open,
		OPB_retry => opb_OPB_retry,
		OPB_RNW => opb_OPB_RNW,
		OPB_select => opb_OPB_select,
		OPB_seqAddr => opb_OPB_seqAddr,
		OPB_timeout => opb_OPB_timeout,
		OPB_toutSup => open,
		OPB_xferAck => opb_OPB_xferAck
	);
	
	indel_plb2opb : if C_INDEL_PLB2OPB=1 generate
	begin
		plb2opb : entity plb2opb.plb2opb
		generic map (
			C_BASEADDR => X"8000_0000",
			C_HIGHADDR => X"ffff_ffff",
			C_PIPLINED_TRANSFER_EN => 1,
			C_CHIPSCOPE_EN => 0,
			C_INCLUDE_BURST_CACHELN_SUPPORT => 1, -- means ppc 8 line transfer only!!!
			C_PLB_DWIDTH => C_PLB_DWIDTH,
			C_PLB_AWIDTH => C_PLB_AWIDTH,
			C_NUM_MASTERS => C_PLB_NUM_MASTERS,
			C_PLB_CLK_PERIOD_PS => C_PLB_CLK_PERIOD_PS,
			C_PLB_MID_WIDTH => C_PLB_MID_WIDTH,
			C_OPB_AWIDTH => C_OPB_AWIDTH,
			C_OPB_DWIDTH => C_OPB_DWIDTH
		)
		port map (
			PLB_Clk => plb_clk,
			PLB_Rst => plb_PLB_Rst,
			sl_addrAck => plb_Sl_addrAck(0),
			sl_MErr => plb_Sl_MErr(0 to 1),
			sl_MBusy => plb_Sl_MBusy(0 to 1),
			sl_rdBTerm => plb_Sl_rdBTerm(0),
			sl_rdComp => plb_Sl_rdComp(0),
			sl_rdDAck => plb_Sl_rdDAck(0),
			sl_rdDBus => plb_Sl_rdDBus(0 to 63),
			sl_rdWdAddr => plb_Sl_rdWdAddr(0 to 3),
			sl_rearbitrate => plb_Sl_rearbitrate(0),
			sl_SSize => plb_Sl_SSize(0 to 1),
			sl_wait => plb_Sl_wait(0),
			sl_wrBTerm => plb_Sl_wrBTerm(0),
			sl_wrComp => plb_Sl_wrComp(0),
			sl_wrDAck => plb_Sl_wrDAck(0),
			plb_abort => plb_PLB_abort,
			plb_ABus => plb_PLB_ABus,
			plb_BE => plb_PLB_BE,
			plb_busLock => plb_PLB_busLock,
			plb_compress => plb_PLB_compress,
			plb_guarded => plb_PLB_guarded,
			plb_lockErr => plb_PLB_lockErr,
			plb_masterID => plb_PLB_masterID(0 to 0),
			plb_MSize => plb_PLB_MSize,
			plb_ordered => plb_PLB_ordered,
			plb_PAValid => plb_PLB_PAValid,
			plb_pendreq => plb_PLB_pendReq,
			plb_pendpri => plb_PLB_pendPri,
			plb_rdBurst => plb_PLB_rdBurst,
			plb_rdPrim => plb_PLB_rdPrim,
			plb_reqpri => plb_PLB_reqPri,
			plb_RNW => plb_PLB_RNW,
			plb_SAValid => plb_PLB_SAValid,
			plb_size => plb_PLB_size,
			plb_type => plb_PLB_type,
			plb_wrBurst => plb_PLB_wrBurst,
			plb_wrDBus => plb_PLB_wrDBus,
			plb_wrPrim => plb_PLB_wrPrim,
	--		PLB2OPB_rearb => plb_PLB2OPB_rearb(0),
			M_ABus => opb_M_ABus,
			M_BE => opb_M_BE,
			M_busLock => opb_M_busLock(0),
			M_DBus => opb_M_DBus,
			M_request => opb_M_request(0),
			M_RNW => opb_M_RNW(0),
			M_select => opb_M_select(0),
			M_seqAddr => opb_M_seqAddr(0),
			OPB_DBus => opb_OPB_DBus,
			OPB_errAck => opb_OPB_errAck,
			OPB_MnGrant => opb_OPB_MGrant(0),
			OPB_retry => opb_OPB_retry,
			OPB_timeout => opb_OPB_timeout,
			OPB_xferAck => opb_OPB_xferAck
		);
	end generate indel_plb2opb;
	
	xilinx_plb2opb : if C_INDEL_PLB2OPB=0 generate
	begin
		plb2opb : entity plb2opb_bridge_v1_01_a.plb2opb_bridge
		generic map (
			C_NO_PLB_BURST => 1, 
			C_DCR_INTFCE => 0,
			C_FAMILY => C_FAMILY,
			C_NUM_ADDR_RNG => 3,
			C_RNG0_BASEADDR => X"8000_0000",
			C_RNG0_HIGHADDR => X"8fff_ffff",
			C_RNG1_BASEADDR => X"E000_0000",
			C_RNG1_HIGHADDR => X"EFFF_FFFF",
			C_RNG2_BASEADDR => X"FFFF_0000",
			C_RNG2_HIGHADDR => X"FFFF_FFFF",
			C_RNG3_BASEADDR => X"FFFFFFFF",
			C_RNG3_HIGHADDR => X"00000000",
			C_PLB_AWIDTH => C_PLB_AWIDTH,
			C_PLB_DWIDTH => C_PLB_DWIDTH,
			C_PLB_NUM_MASTERS => C_PLB_NUM_MASTERS,
			C_PLB_MID_WIDTH => C_PLB_MID_WIDTH,
			C_OPB_AWIDTH => C_OPB_AWIDTH,
			C_OPB_DWIDTH => C_OPB_DWIDTH,
			C_DCR_BASEADDR => B"1111111111",
			C_DCR_HIGHADDR => B"0000000000",
			C_DCR_AWIDTH => 10,
			C_DCR_DWIDTH => 32,
			C_IRQ_ACTIVE => H,
			C_BGI_TRANSABORT_CNT => 31,
			C_CLK_ASYNC => 1,
			C_HIGH_SPEED => 1,
			C_INCLUDE_BGI_TRANSABORT => 1
		)
		port map (
			PLB_Clk => plb_clk,
			OPB_Clk => opb_clk,
			PLB_Rst => plb_PLB_Rst,
			OPB_Rst => opb_OPB_Rst,
			Bus_Error_Det => open,
			BGI_Trans_Abort => open,
			BGO_dcrAck => open,
			BGO_dcrDBus => open,
			DCR_ABus => net_gnd64(0 to 9),
			DCR_DBus => net_gnd64(0 to 31),
			DCR_Read => net_gnd0,
			DCR_Write => net_gnd0,
			BGO_addrAck => plb_Sl_addrAck(0),
			BGO_MErr => plb_Sl_MErr(0 to 1),
			BGO_MBusy => plb_Sl_MBusy(0 to 1),
			BGO_rdBTerm => plb_Sl_rdBTerm(0),
			BGO_rdComp => plb_Sl_rdComp(0),
			BGO_rdDAck => plb_Sl_rdDAck(0),
			BGO_rdDBus => plb_Sl_rdDBus(0 to 63),
			BGO_rdWdAddr => plb_Sl_rdWdAddr(0 to 3),
			BGO_rearbitrate => plb_Sl_rearbitrate(0),
			BGO_SSize => plb_Sl_SSize(0 to 1),
			BGO_wait => plb_Sl_wait(0),
			BGO_wrBTerm => plb_Sl_wrBTerm(0),
			BGO_wrComp => plb_Sl_wrComp(0),
			BGO_wrDAck => plb_Sl_wrDAck(0),
			PLB_abort => plb_PLB_abort,
			PLB_ABus => plb_PLB_ABus,
			PLB_BE => plb_PLB_BE,
			PLB_busLock => plb_PLB_busLock,
			PLB_compress => plb_PLB_compress,
			PLB_guarded => plb_PLB_guarded,
			PLB_lockErr => plb_PLB_lockErr,
			PLB_masterID => plb_PLB_masterID(0 to 0),
			PLB_MSize => plb_PLB_MSize,
			PLB_ordered => plb_PLB_ordered,
			PLB_PAValid => plb_PLB_PAValid,
			PLB_rdBurst => plb_PLB_rdBurst,
			PLB_rdPrim => plb_PLB_rdPrim,
			PLB_RNW => plb_PLB_RNW,
			PLB_SAValid => plb_PLB_SAValid,
			PLB_size => plb_PLB_size,
			PLB_type => plb_PLB_type,
			PLB_wrBurst => plb_PLB_wrBurst,
			PLB_wrDBus => plb_PLB_wrDBus,
			PLB_wrPrim => plb_PLB_wrPrim,
			PLB2OPB_rearb => plb_PLB2OPB_rearb(0),
			BGO_ABus => opb_M_ABus,
			BGO_BE => opb_M_BE,
			BGO_busLock => opb_M_busLock(0),
			BGO_DBus => opb_M_DBus,
			BGO_request => opb_M_request(0),
			BGO_RNW => opb_M_RNW(0),
			BGO_select => opb_M_select(0),
			BGO_seqAddr => opb_M_seqAddr(0),
			OPB_DBus => opb_OPB_DBus,
			OPB_errAck => opb_OPB_errAck,
			OPB_MnGrant => opb_OPB_MGrant(0),
			OPB_retry => opb_OPB_retry,
			OPB_timeout => opb_OPB_timeout,
			OPB_xferAck => opb_OPB_xferAck
		);
	end generate xilinx_plb2opb;

	jtagppc_0 : entity jtagppc_cntlr_v2_00_a.jtagppc_cntlr
	generic map (
		C_DEVICE => "2vp4"
	)
	port map (
		TRSTNEG => net_vcc0,
		HALTNEG0 => ni_ppc_halt,
		DBGC405DEBUGHALT0 => DBGC405DEBUGHALT,
		HALTNEG1 => net_vcc0,
		DBGC405DEBUGHALT1 => open,
		C405JTGTDO0 => C405JTGTDO,
		C405JTGTDOEN0 => C405JTGTDOEN,
		JTGC405TCK0 => JTGC405TCK,
		JTGC405TDI0 => JTGC405TDI,
		JTGC405TMS0 => JTGC405TMS,
		JTGC405TRSTNEG0 => JTGC405TRSTNEG,
		C405JTGTDO1 => net_gnd0,
		C405JTGTDOEN1 => net_gnd0,
		JTGC405TCK1 => open,
		JTGC405TDI1 => open,
		JTGC405TMS1 => open,
		JTGC405TRSTNEG1 => open
	);

	reset_block_sys : entity proc_sys_reset_v1_00_a.proc_sys_reset
	generic map (
		C_EXT_RST_WIDTH => 4,
		C_AUX_RST_WIDTH => 1,
		C_EXT_RESET_HIGH => L,
		C_AUX_RESET_HIGH => H,
		C_NUM_BUS_RST => 1,
		C_NUM_PERP_RST => 1
	)
	port map (
		Slowest_sync_clk => opb_clk,
		Ext_Reset_In => system_nReset,
		Aux_Reset_In => net_gnd0,
		Core_Reset_Req => C405RSTCORERESETREQ,
		Chip_Reset_Req => C405RSTCHIPRESETREQ,
		System_Reset_Req => C405RSTSYSRESETREQ,
		Dcm_locked => dcmLocked,
		Rstc405resetcore => RSTC405RESETCORE,
		Rstc405resetchip => RSTC405RESETCHIP,
		Rstc405resetsys => RSTC405RESETSYS,
		Bus_Struct_Reset => sys_bus_reset(0 to 0),
		Peripheral_Reset => peripheral_reset(0 to 0)
	);
	
	-- inputs
	sdDAT_I <= crossbits(b_sdDAT_I);
	-- outputs
	b_sdDAT_O <= crossbits(sdDAT_O);
	b_sdDAT_T <= crossbits(sdDAT_T);
	o_sdDQM <= crossbits(sdDQM);
	o_sdBAdr <= crossbits(sdBAdr);
	o_sdADR <= crossbits(sdADR);
	
	
	plb_sdram_sys : entity plb_sdram_v1_00_e.plb_sdram
	generic map (
		C_INCLUDE_BURST_CACHELN_SUPPORT => 1,
		C_USE_POSEDGE_OUTREGS => 0,
		C_INCLUDE_HIGHSPEED_PIPE => 1,
		C_SDRAM_TMRD => 2,
		C_SDRAM_TWR => 15000,
		C_SDRAM_TCCD => 1,
		C_SDRAM_TRAS => 45000,
		C_SDRAM_TRC => 65000,
		C_SDRAM_TRFC => 75000,
		C_SDRAM_TRCD => 20000,
		C_SDRAM_TRRD => 15000,
		C_SDRAM_TRP => 20000,
		C_SDRAM_TREF => 64,
		C_SDRAM_REFRESH_NUMROWS => 4096,
		C_SDRAM_CAS_LAT => 2,
		C_SDRAM_DWIDTH => C_SDRAM_WIDTH,
		C_SDRAM_AWIDTH => 12,
		C_SDRAM_COL_AWIDTH => 9,
		C_SDRAM_BANK_AWIDTH => 2,
		C_SIM_INIT_TIME_PS => 100000000,
		C_SDRAM_DRIVER_STRENGTH => 0,
		C_SDRAM_TREFI => 15625000,
		C_FAMILY => "virtex2p",
		C_BASEADDR => X"0000_0000",
		C_HIGHADDR => X"01FF_FFFF",
		C_ADDR_B => X"FFB0_0000",
		C_ADDR_H => X"FFBF_FFFF",
		C_PLB_MID_WIDTH => C_PLB_MID_WIDTH,
		C_PLB_CLK_PERIOD_PS => C_PLB_CLK_PERIOD_PS,
		C_PLB_NUM_MASTERS => C_PLB_NUM_MASTERS,
		C_PLB_AWIDTH => C_PLB_AWIDTH,
		C_PLB_DWIDTH => C_PLB_DWIDTH
	)
	port map (
		PLB_Clk => plb_clk,
		SDRAM_Clk_in => plb_clk,
		PLB_Rst => plb_PLB_Rst,
		PLB_ABus => plb_PLB_ABus,
		PLB_PAValid => plb_PLB_PAValid,
		PLB_SAValid => plb_PLB_SAValid,
		PLB_rdPrim => plb_PLB_rdPrim,
		PLB_wrPrim => plb_PLB_wrPrim,
		PLB_masterID => plb_PLB_masterID(0 to 0),
		PLB_abort => plb_PLB_abort,
		PLB_busLock => plb_PLB_busLock,
		PLB_RNW => plb_PLB_RNW,
		PLB_BE => plb_PLB_BE,
		PLB_MSize => plb_PLB_MSize,
		PLB_size => plb_PLB_size,
		PLB_type => plb_PLB_type,
		PLB_compress => plb_PLB_compress,
		PLB_guarded => plb_PLB_guarded,
		PLB_ordered => plb_PLB_ordered,
		PLB_lockErr => plb_PLB_lockErr,
		PLB_wrDBus => plb_PLB_wrDBus,
		PLB_wrBurst => plb_PLB_wrBurst,
		PLB_rdBurst => plb_PLB_rdBurst,
		PLB_pendReq => plb_PLB_pendReq,
		PLB_pendPri => plb_PLB_pendPri,
		PLB_reqPri => plb_PLB_reqPri,
		Sl_addrAck => plb_Sl_addrAck(1),
		Sl_SSize => plb_Sl_SSize(2 to 3),
		Sl_wait => plb_Sl_wait(1),
		Sl_rearbitrate => plb_Sl_rearbitrate(1),
		Sl_wrDAck => plb_Sl_wrDAck(1),
		Sl_wrComp => plb_Sl_wrComp(1),
		Sl_wrBTerm => plb_Sl_wrBTerm(1),
		Sl_rdDBus => plb_Sl_rdDBus(64 to 127),
		Sl_rdWdAddr => plb_Sl_rdWdAddr(4 to 7),
		Sl_rdDAck => plb_Sl_rdDAck(1),
		Sl_rdComp => plb_Sl_rdComp(1),
		Sl_rdBTerm => plb_Sl_rdBTerm(1),
		Sl_MBusy => plb_Sl_MBusy(2 to 3),
		Sl_MErr => plb_Sl_MErr(2 to 3),
		SDRAM_Clk => o_sdCLK,
		SDRAM_CKE => o_sdCKE,
		SDRAM_CSn => no_sdCS,
		SDRAM_RASn => no_sdRAS,
		SDRAM_CASn => no_sdCAS,
		SDRAM_WEn => no_sdWE,
		SDRAM_DQM => sdDQM,
		SDRAM_BankAddr => sdBAdr,
		SDRAM_Addr => sdADR,
		SDRAM_Init_done => open,
		SDRAM_DQ_I => sdDAT_I,
		SDRAM_DQ_O => sdDAT_O,
		SDRAM_DQ_T => sdDAT_T
	);
	
	indel_plb_bram : if C_INDEL_PLB_BRAM=1 generate
	begin
		i_plbbram_if : for i in 0 to C_NUM_PLBBRAM_IF-1 generate
		begin
			inst_i_plb_bram : entity plb_bram.plb_bram
			generic map (
				C_BASEADDR => C_BASEADDR_PLBBRAM_IF(i),
				C_HIGHADDR => C_HIGHADDR_PLBBRAM_IF(i),
				C_PIPLINED_TRANSFER_EN => 1,
				C_CHIPSCOPE_EN => 0,
				C_BRAM_AWIDTH => 32,
				C_INCLUDE_BURST_CACHELN_SUPPORT => 1, -- means ppc 8 line transfer only!!!
				C_PLB_DWIDTH => C_PLB_DWIDTH,
				C_PLB_AWIDTH => C_PLB_AWIDTH,
				C_NUM_MASTERS => C_PLB_NUM_MASTERS,
				C_PLB_CLK_PERIOD_PS => C_PLB_CLK_PERIOD_PS,
				C_PLB_MID_WIDTH => C_PLB_MID_WIDTH
			)
			port map (
				plb_clk => plb_clk,
				plb_rst => plb_PLB_Rst,
				plb_abort => plb_PLB_abort,
				plb_abus => plb_PLB_ABus,
				plb_be => plb_PLB_BE,
				plb_buslock => plb_PLB_busLock,
				plb_compress => plb_PLB_compress,
				plb_guarded => plb_PLB_guarded,
				plb_lockerr => plb_PLB_lockErr,
				plb_masterid => plb_PLB_masterID(0 to C_PLB_MID_WIDTH-1),
				plb_msize => plb_PLB_MSize,
				plb_ordered => plb_PLB_ordered,
				plb_pavalid => plb_PLB_PAValid,
				plb_rnw => plb_PLB_RNW,
				plb_size => plb_PLB_size,
				plb_type => plb_PLB_type,
				sl_addrack => plb_Sl_addrAck(2+i),
				sl_mbusy => plb_Sl_MBusy(4+i*2 to 5+i*2),
				sl_merr => plb_Sl_MErr(4+i*2 to 5+i*2),
				sl_rearbitrate => plb_Sl_rearbitrate(2+i),
				sl_ssize => plb_Sl_SSize(4+i*2 to 5+i*2),
				sl_wait => plb_Sl_wait(2+i),
				plb_rdprim => plb_PLB_rdPrim,
				plb_savalid => plb_PLB_SAValid,
				plb_wrprim => plb_PLB_wrPrim,
				plb_wrburst => plb_PLB_wrBurst,
				plb_wrdbus => plb_PLB_wrDBus,
				sl_wrbterm => plb_Sl_wrBTerm(2+i),
				sl_wrcomp => plb_Sl_wrComp(2+i),
				sl_wrdack => plb_Sl_wrDAck(2+i),
				plb_rdburst => plb_PLB_rdBurst,
				sl_rdbterm => plb_Sl_rdBTerm(2+i),
				sl_rdcomp => plb_Sl_rdComp(2+i),
				sl_rddack => plb_Sl_rdDAck(2+i),
				sl_rddbus => plb_Sl_rdDBus(128+i*64 to 191+i*64),
				sl_rdwdaddr => plb_Sl_rdWdAddr(8+i*4 to 11+i*4),
				plb_pendreq => plb_PLB_pendReq,
				plb_pendpri => plb_PLB_pendPri,
				plb_reqpri => plb_PLB_reqPri,
				bram_rst => o_plbbram_Rst(i),
				bram_clk => o_plbbram_Clk(i),
				bram_en => o_plbbram_EN(i),
				bram_wen => o_plbbram_WEN(8*i to 8*i+7),
				bram_addr => o_plbbram_Addr(32*i to 32*i+31),
				bram_din => i_plbbram_Data(64*i to 64*i+63),
				bram_dout => o_plbbram_Data(64*i to 64*i+63)
			);
		end generate i_plbbram_if;
	end generate indel_plb_bram;
	
	xilinx_plb_bram : if C_INDEL_PLB_BRAM=0 generate
	begin
		x_plbbram_if : for i in 0 to C_NUM_PLBBRAM_IF-1 generate
		begin
			inst_x_plb_bram : entity plb_bram_if_cntlr_v1_00_a.plb_bram_if_cntlr
			generic map (
				C_BASEADDR => C_BASEADDR_PLBBRAM_IF(i),--X"7000_0000",
				C_HIGHADDR => C_HIGHADDR_PLBBRAM_IF(i),--X"7000_FFFF",
				C_INCLUDE_BURST_CACHELN_SUPPORT => 0,
				C_PLB_DWIDTH => C_PLB_DWIDTH,
				C_PLB_AWIDTH => C_PLB_AWIDTH,
				C_NUM_MASTERS => C_PLB_NUM_MASTERS,
				C_PLB_CLK_PERIOD_PS => C_PLB_CLK_PERIOD_PS,
				C_PLB_MID_WIDTH => C_PLB_MID_WIDTH
			)
			port map (
				plb_clk => plb_clk,
				plb_rst => plb_PLB_Rst,
				plb_abort => plb_PLB_abort,
				plb_abus => plb_PLB_ABus,
				plb_be => plb_PLB_BE,
				plb_buslock => plb_PLB_busLock,
				plb_compress => plb_PLB_compress,
				plb_guarded => plb_PLB_guarded,
				plb_lockerr => plb_PLB_lockErr,
				plb_masterid => plb_PLB_masterID(0 to C_PLB_MID_WIDTH-1),
				plb_msize => plb_PLB_MSize,
				plb_ordered => plb_PLB_ordered,
				plb_pavalid => plb_PLB_PAValid,
				plb_rnw => plb_PLB_RNW,
				plb_size => plb_PLB_size,
				plb_type => plb_PLB_type,
				sl_addrack => plb_Sl_addrAck(2+i),
				sl_mbusy => plb_Sl_MBusy(4+i*2 to 5+i*2),
				sl_merr => plb_Sl_MErr(4+i*2 to 5+i*2),
				sl_rearbitrate => plb_Sl_rearbitrate(2+i),
				sl_ssize => plb_Sl_SSize(4+i*2 to 5+i*2),
				sl_wait => plb_Sl_wait(2+i),
				plb_rdprim => plb_PLB_rdPrim,
				plb_savalid => plb_PLB_SAValid,
				plb_wrprim => plb_PLB_wrPrim,
				plb_wrburst => plb_PLB_wrBurst,
				plb_wrdbus => plb_PLB_wrDBus,
				sl_wrbterm => plb_Sl_wrBTerm(2+i),
				sl_wrcomp => plb_Sl_wrComp(2+i),
				sl_wrdack => plb_Sl_wrDAck(2+i),
				plb_rdburst => plb_PLB_rdBurst,
				sl_rdbterm => plb_Sl_rdBTerm(2+i),
				sl_rdcomp => plb_Sl_rdComp(2+i),
				sl_rddack => plb_Sl_rdDAck(2+i),
				sl_rddbus => plb_Sl_rdDBus(128+i*64 to 191+i*64),
				sl_rdwdaddr => plb_Sl_rdWdAddr(8+i*4 to 11+i*4),
				plb_pendreq => plb_PLB_pendReq,
				plb_pendpri => plb_PLB_pendPri,
				plb_reqpri => plb_PLB_reqPri,
				bram_rst => o_plbbram_Rst(i),
				bram_clk => o_plbbram_Clk(i),
				bram_en => o_plbbram_EN(i),
				bram_wen => o_plbbram_WEN(8*i to 8*i+7),
				bram_addr => o_plbbram_Addr(32*i to 32*i+31),
				bram_din => i_plbbram_Data(64*i to 64*i+63),
				bram_dout => o_plbbram_Data(64*i to 64*i+63)
			);
		end generate x_plbbram_if;
	end generate xilinx_plb_bram;
	
	opb_boot_ram : if C_OPB_BOOT_RAM=1 generate
		-- opb slave 0 -------------------------------------------------------------
		opb_bram_if_cntlr_boot_sys : entity opb_bram_if_cntlr_v1_00_a.opb_bram_if_cntlr
		generic map (
			C_BASEADDR => X"FFFF8000",
			C_HIGHADDR => X"FFFFFFFF",
			C_INCLUDE_BURST_SUPPORT => 1,
			C_OPB_DWIDTH => C_OPB_DWIDTH,
			C_OPB_AWIDTH => C_OPB_AWIDTH,
			C_OPB_CLK_PERIOD_PS => C_OPB_CLK_PERIOD_PS
		)
		port map (
			opb_clk => opb_clk,
			opb_rst => opb_OPB_Rst,
			opb_abus => opb_OPB_ABus,
			opb_dbus => opb_OPB_DBus,
			sln_dbus => opb_Sl_DBus(0 to 31),
			opb_select => opb_OPB_select,
			opb_rnw => opb_OPB_RNW,
			opb_seqaddr => opb_OPB_seqAddr,
			opb_be => opb_OPB_BE,
			sln_xferack => opb_Sl_xferAck(0),
			sln_errack => opb_Sl_errAck(0),
			sln_toutsup => opb_Sl_toutSup(0),
			sln_retry => opb_Sl_retry(0),
			bram_rst => open,
			bram_clk => Boot_RW_BRAM_Clk,
			bram_en => Boot_RW_BRAM_EN,
			bram_wen => Boot_RW_BRAM_WEN,
			bram_addr => Boot_RW_BRAM_Addr,
			bram_din => Boot_RW_BRAM_Din,
			bram_dout => Boot_RW_BRAM_Dout
		);
	end generate opb_boot_ram;
	
	o_isocm_addr <= keep_isocm_addr(8 to 28);
	o_isocm_en <= keep_isocm_en;
	
	boot_ram_opb_no_isocm : if (C_OPB_BOOT_RAM=1 and C_ISOCM_BOOT_RAM=0) generate
		keep_isocm_addr <= (others => L);
		isocm_data <= (others => L);
		ISCNTLVALUE <= "0000" & DF_ISOCMCLJRATIO;-- 0: enable, 5..7 clk ratio "011" -> 2:1
		boot_ram_sys : entity boot_ram_sys_isocm.boot_ram_sys_isocm
		generic map (
			C_NUM_OF_BRAMS => C_NUM_OF_BOOT_BRAMS
		)
		port map (
			BRAM_Rst_A => net_gnd0,
			BRAM_Clk_A => Boot_RW_BRAM_Clk,
			BRAM_EN_A => Boot_RW_BRAM_EN,
			BRAM_WEN_A => Boot_RW_BRAM_WEN,
			BRAM_Addr_A => Boot_RW_BRAM_Addr,
			BRAM_Din_A => Boot_RW_BRAM_Din,
			BRAM_Dout_A => Boot_RW_BRAM_Dout,
			BRAM_Rst_B => net_gnd0,
			BRAM_Clk_B => net_gnd0,
			BRAM_EN_B => net_gnd0,
			BRAM_WEN_B => net_gnd64(0 to C_NUM_OF_BOOT_BRAMS-1),
			BRAM_Addr_B => net_gnd64(0 to 31),
			BRAM_Din_B => open,
			BRAM_Dout_B => net_gnd64(0 to 63)
		);
	end generate boot_ram_opb_no_isocm;
	
	boot_ram_isocm_no_opb : if (C_OPB_BOOT_RAM=0 and C_ISOCM_BOOT_RAM=1) generate
		signal isocm_BRAM_WEN : std_logic_vector(0 to C_NUM_OF_BOOT_BRAMS-1) := (others => L);
	begin
		ISARCVALUE <= x"ff"; -- 0xff00_0000 .. 0xffff_ffff
		-- enabled at startup
		ISCNTLVALUE <= "1000" & DF_ISOCMCLJRATIO;-- 0: enable, 5..7 clk ratio "011" -> 2:1
		
		--gen_isocm_BRAM_WEN : for i in 0 to C_NUM_OF_BOOT_BRAMS-1 generate
		--	isocm_BRAM_WEN(i) <= not dcmLocked;
		--end generate gen_isocm_BRAM_WEN;
		
		boot_ram_sys : entity boot_ram_sys_isocm.boot_ram_sys_isocm
		generic map (
			C_NUM_OF_BRAMS => C_NUM_OF_BOOT_BRAMS
		)
		port map (
			BRAM_Rst_A => net_gnd0,
			BRAM_Clk_A => net_gnd0,
			BRAM_EN_A => net_gnd0,
			BRAM_WEN_A => net_gnd64(0 to 3),
			BRAM_Addr_A => net_gnd64(0 to 31),
			BRAM_Din_A => open,
			BRAM_Dout_A => net_gnd64(0 to 31),
			BRAM_Rst_B => net_gnd0,
			BRAM_Clk_B => ocm_clk,
			BRAM_EN_B => keep_isocm_en,
			BRAM_WEN_B => isocm_BRAM_WEN,
			BRAM_Addr_B => keep_isocm_addr,
			BRAM_Din_B => isocm_data,
			BRAM_Dout_B => net_gnd64(0 to 63)
		);
	end generate boot_ram_isocm_no_opb;
	
	boot_ram_opb_and_isocm : if (C_OPB_BOOT_RAM=1 and C_ISOCM_BOOT_RAM=1) generate
		signal isocm_BRAM_WEN : std_logic_vector(0 to C_NUM_OF_BOOT_BRAMS-1) := (others => L);
	begin
		ISARCVALUE <= x"ff"; -- 0xff00_0000 .. 0xffff_ffff
		-- enable over sw
		ISCNTLVALUE <= "0000" & DF_ISOCMCLJRATIO;-- 0: enable, 5..7 clk ratio "011" -> 2:1
		--gen_isocm_BRAM_WEN : for i in 0 to C_NUM_OF_BOOT_BRAMS-1 generate
		--	isocm_BRAM_WEN(i) <= not dcmLocked;
		--end generate gen_isocm_BRAM_WEN;
		boot_ram_sys : entity boot_ram_sys_isocm.boot_ram_sys_isocm
		generic map (
			C_NUM_OF_BRAMS => C_NUM_OF_BOOT_BRAMS
		)
		port map (
			BRAM_Rst_A => net_gnd0,
			BRAM_Clk_A => Boot_RW_BRAM_Clk,
			BRAM_EN_A => Boot_RW_BRAM_EN,
			BRAM_WEN_A => Boot_RW_BRAM_WEN,
			BRAM_Addr_A => Boot_RW_BRAM_Addr,
			BRAM_Din_A => Boot_RW_BRAM_Din,
			BRAM_Dout_A => Boot_RW_BRAM_Dout,
			BRAM_Rst_B => net_gnd0,
			BRAM_Clk_B => ocm_clk,
			BRAM_EN_B => keep_isocm_en,
			BRAM_WEN_B => isocm_BRAM_WEN,
			BRAM_Addr_B => keep_isocm_addr,
			BRAM_Din_B => isocm_data,
			BRAM_Dout_B => net_gnd64(0 to 63)
		);
	end generate boot_ram_opb_and_isocm;
	-- opb interfaces ----------------------------------------------------------
	opbifs : for i in 0 to C_NUM_OPB_IF-1 generate
	begin
		opb_if : entity opb_if.opb_if
		generic map (
			C_BASEADDR => C_BASEADDR_OPB_IF(i),
			C_HIGHADDR => C_HIGHADDR_OPB_IF(i),
			C_WR_FIFO_SIZE => 0,
			C_OPB_DWIDTH => C_OPB_DWIDTH,
			C_OPB_AWIDTH => C_OPB_AWIDTH
		)
		port map (
			OPB_Clk => opb_clk,
			OPB_Rst => opb_OPB_Rst,
			OPB_ABus => opb_OPB_ABus,
			OPB_DBus => opb_OPB_DBus,
			OPB_select => opb_OPB_select,
			OPB_RNW => opb_OPB_RNW,
			OPB_seqAddr => opb_OPB_seqAddr,
			OPB_BE => opb_OPB_BE,
			Sln_DBus => opb_Sl_DBus((C_OPB_BOOT_RAM+i)*32 to (C_OPB_BOOT_RAM+i)*32+31),
			Sln_xferAck => opb_Sl_xferAck((C_OPB_BOOT_RAM+i)),
			Sln_errAck => opb_Sl_errAck((C_OPB_BOOT_RAM+i)),
			Sln_toutSup => opb_Sl_toutSup((C_OPB_BOOT_RAM+i)),
			Sln_retry => opb_Sl_retry((C_OPB_BOOT_RAM+i)),
			-- user interface
			addr => o_opbif_addr(i*32+31 downto i*32),
			rd_acc => o_opbif_rd_acc(i),
			wr_acc => o_opbif_wr_acc(i),
			byte_ebl => o_opbif_byte_ebl(i*4+3 downto i*4),
			wr_data => o_opbif_wr_data(i*32+31 downto i*32),
			rd_data => i_opbif_rd_data(i*32+31 downto i*32),
			rd_acc_done => i_opbif_rd_acc_done(i),
			wr_acc_done => i_opbif_wr_acc_done(i)
		);
	end generate opbifs;
	-- opb slave uarts ---------------------------------------------------------
	uarts : for i in 0 to C_NUM_UARTS-1 generate
	begin
		opb_uart_sys : entity opb_uart.opb_uart
		generic map (
			C_BASEADDR => C_BASEADDR_UART(i),
			C_HIGHADDR => C_HIGHADDR_UART(i),
			C_OPB_DWIDTH => C_OPB_DWIDTH,
			C_OPB_AWIDTH => C_OPB_AWIDTH,
			C_DATA_BITS => 8,
			C_CLK_FREQ => C_BUS_CLK_FREQ,
			C_BAUDRATE => 115200,
			C_USE_PARITY => 0,
			C_ODD_PARITY => 0,
			C_485_SUPPORT => 1
		)
		port map (
			OPB_Clk => opb_clk,
			OPB_Rst => opb_OPB_Rst,
			Interrupt => open,
			OPB_ABus => opb_OPB_ABus,
			OPB_BE => opb_OPB_BE,
			OPB_RNW => opb_OPB_RNW,
			OPB_select => opb_OPB_select,
			OPB_seqAddr => opb_OPB_seqAddr,
			OPB_DBus => opb_OPB_DBus,
			UART_DBus => opb_Sl_DBus((C_OPB_BOOT_RAM+C_NUM_OPB_IF+i)*32 to (C_OPB_BOOT_RAM+C_NUM_OPB_IF+i)*32+31),
			UART_errAck => opb_Sl_errAck(C_OPB_BOOT_RAM+C_NUM_OPB_IF+i),
			UART_retry => opb_Sl_retry(C_OPB_BOOT_RAM+C_NUM_OPB_IF+i),
			UART_toutSup => opb_Sl_toutSup(C_OPB_BOOT_RAM+C_NUM_OPB_IF+i),
			UART_xferAck => opb_Sl_xferAck(C_OPB_BOOT_RAM+C_NUM_OPB_IF+i),
			-- uart signals
			RX => ni_sioRX(i),
			TX => no_sioTX(i),
			o_txInterrupt => sio_txInt(i),
			o_rxInterrupt => sio_rxInt(i),
			o_485_RnW => o_485_RnW(i),
			ni_sioRTS => ni_sioRTS(i),
			no_sioCTS => no_sioCTS(i),
			o_TP1 => open,
			o_TP2 => open,
			o_TP3 => open,
			o_TP4 => open
		);
	end generate uarts;
end architecture STRUCTURE;

