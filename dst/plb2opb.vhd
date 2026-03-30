--------------------------------------------------------------------------------
-- plb2opb.vhd
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library plb_slave;
use plb_slave.ALL;

library opb_master;
use opb_master.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity plb2opb is
generic (
	C_NUM_MASTERS : integer := 2;
	C_BASEADDR : std_logic_vector := X"7000_0000";
	C_HIGHADDR : std_logic_vector := X"7fff_ffff";
	C_INCLUDE_BURST_CACHELN_SUPPORT : integer := 1; -- means ppc 8 line transfer only!!!
	C_PIPLINED_TRANSFER_EN : integer := 1;
	C_CHIPSCOPE_EN : integer := 0;
	C_PLB_DWIDTH : integer range 64 to 64 := 64;
	C_PLB_AWIDTH : integer range 32 to 32 := 32;
	C_PLB_CLK_PERIOD_PS : integer := 10000;
	C_PLB_MID_WIDTH : integer := 1;
	C_OPB_DWIDTH : integer range 32 to 32 := 32;
	C_OPB_AWIDTH : integer range 32 to 32 := 32
);
port (
	plb_clk : in std_logic;
	plb_rst : in std_logic;
	-- to bus/master
	sl_addrAck : out std_logic;										-- Slave address acknowledge
	sl_MBusy : out std_logic_vector(0 to C_NUM_MASTERS-1);			-- Slave busy indicator
	sl_MErr : out std_logic_vector(0 to C_NUM_MASTERS-1);			-- Slave error indicator
	sl_rdBTerm : out std_logic;										-- Slave terminate read burst transfer
	sl_rdComp : out std_logic;										-- Slave read transfer complete indicator
	sl_rdDAck : out std_logic;										-- Slave read data acknowledge
	sl_rdDBus : out std_logic_vector(0 to C_PLB_DWIDTH-1);			-- Slave read data bus
	sl_rdWdAddr : out std_logic_vector(0 to 3);						-- Slave read word address
	sl_rearbitrate : out std_logic;									-- Slave re-arbitrate bus indicator
	sl_SSize : out std_logic_vector(0 to 1);						-- Slave data bus size
	sl_wait : out std_logic;										-- Slave wait indicator
	sl_wrBTerm : out std_logic;										-- Slave terminate write burst transfer
	sl_wrComp : out std_logic;										-- Slave write transfer complete indicator
	sl_wrDAck : out std_logic;										-- Slave write data acknowledge
	-- from bus/master
	plb_abort : in std_logic;										-- PLB abort request indicator
	plb_ABus : in std_logic_vector(0 to C_PLB_AWIDTH-1);			-- PLB address bus
	plb_BE : in std_logic_vector(0 to C_PLB_DWIDTH/8-1);			-- PLB byte enables
	plb_busLock : in std_logic;										-- PLB bus lock
	plb_compress : in std_logic;									-- PLB compressed data transfer indicator
	plb_guarded : in std_logic;										-- PLB guarded transfer indicator
	plb_lockErr : in std_logic;										-- PLB lock error indicator
	plb_masterID : in std_logic_vector(0 to C_PLB_MID_WIDTH-1);	-- PLB current master identifier
	plb_MSize : in std_logic_vector(0 to 1);						-- PLB master data bus size
	plb_ordered : in std_logic;										-- PLB synchronize transfer indicator
	plb_PAValid : in std_logic;										-- PLB primary address valid indicator
	plb_pendPri : in std_logic_vector(0 to 1);						-- PLB pending request priority
	plb_pendReq : in std_logic;										-- PLB pending bus request indicator
	plb_rdBurst : in std_logic;										-- PLB burst read transfer indicator
	plb_rdPrim : in std_logic;										-- PLB secondary to primary read request indicator
	plb_reqPri : in std_logic_vector(0 to 1);						-- PLB current request priority
	plb_RNW : in std_logic;											-- PLB read/not write
	plb_SAValid : in std_logic;										-- PLB secondary address valid indicator
	plb_size : in std_logic_vector(0 to 3);							-- PLB transfer size
	plb_type : in std_logic_vector(0 to 2);							-- PLB transfer type
	plb_wrBurst : in std_logic;										-- PLB burst write transfer indicator
	plb_wrDBus : in std_logic_vector(0 to C_PLB_DWIDTH-1);			-- PLB write data bus
	plb_wrPrim : in std_logic;										-- PLB secondary to primary write request indicator
	-- OPB Master
--	OPB_Clk                 : in std_logic;
--	Rst                     : in std_logic;
--	BGI_Trans_Abort         : out std_logic;
	OPB_DBus : in std_logic_vector(0 to C_OPB_DWIDTH-1);
	OPB_errAck : in std_logic;
	OPB_MnGrant : in std_logic;
	OPB_retry : in std_logic;
	OPB_timeout : in std_logic;
	OPB_xferAck : in std_logic;
	M_ABus : out std_logic_vector(0 to C_OPB_AWIDTH-1);
	M_BE : out std_logic_vector(0 to C_OPB_DWIDTH/8 -1);
	M_busLock : out std_logic;
	M_DBus : out std_logic_vector(0 to C_OPB_DWIDTH-1);
	M_request : out std_logic;
	M_RNW : out std_logic;
	M_select : out std_logic;
	M_seqAddr : out std_logic
);
end plb2opb;

architecture plb2opb_arc of plb2opb is

	-- types
	-- constants
	-- static signals
	-- signals
	-- user port
	signal opb2plb_data : std_logic_vector(C_PLB_DWIDTH-1 downto 0);
	signal plb2opb_data : std_logic_vector(C_PLB_DWIDTH-1 downto 0);
	signal plb2opb_addr : std_logic_vector(C_OPB_AWIDTH-1 downto 0);
	signal plb2opb_be : std_logic_vector(C_PLB_DWIDTH/8-1 downto 0);
	signal plb2opb_wr_req : std_logic;
	signal opb2plb_wr_ready : std_logic;
	signal plb2opb_rd_req : std_logic;
	signal opb2plb_rd_done : std_logic;
begin
	inst_opb_master : entity opb_master.opb_master
	generic map (
		C_USER_DWIDTH => C_PLB_DWIDTH,
		C_OPB_DWIDTH => C_OPB_DWIDTH,
		C_OPB_AWIDTH => C_OPB_AWIDTH
	)
	port map (
		-- user port
		o_bus2user_data => opb2plb_data,
		i_user2bus_data => plb2opb_data,
		i_user_addr => plb2opb_addr,
		i_user_be => plb2opb_be,
		i_user_wr_req => plb2opb_wr_req,
		o_user_wr_ready => opb2plb_wr_ready,
		i_user_rd_req => plb2opb_rd_req,
		o_user_rd_done => opb2plb_rd_done,
		-- OPB Master
		OPB_Clk => plb_clk,
		OPB_Rst => plb_Rst,
		OPB_DBus => OPB_DBus,
		OPB_errAck => OPB_errAck,
		OPB_MnGrant => OPB_MnGrant,
		OPB_retry => OPB_retry,
		OPB_timeout => OPB_timeout,
		OPB_xferAck => OPB_xferAck,
		M_ABus => M_ABus,
		M_BE => M_BE,
		M_busLock => M_busLock,
		M_DBus => M_DBus,
		M_request => M_request,
		M_RNW => M_RNW,
		M_select => M_select,
		M_seqAddr => M_seqAddr
	);
	inst_plb_slave : entity plb_slave.plb_slave
	generic map (
		C_BASEADDR => C_BASEADDR,
		C_HIGHADDR => C_HIGHADDR,
		C_PIPLINED_TRANSFER_EN => C_PIPLINED_TRANSFER_EN,
		C_CHIPSCOPE_EN => C_CHIPSCOPE_EN,
		C_INCLUDE_BURST_CACHELN_SUPPORT => C_INCLUDE_BURST_CACHELN_SUPPORT,
		C_USER_AWIDTH => C_OPB_AWIDTH,
		C_PLB_DWIDTH => C_PLB_DWIDTH,
		C_PLB_AWIDTH => C_PLB_AWIDTH,
		C_NUM_MASTERS => C_NUM_MASTERS,
		C_PLB_CLK_PERIOD_PS => C_PLB_CLK_PERIOD_PS,
		C_PLB_MID_WIDTH => C_PLB_MID_WIDTH
	)
	port map (
		plb_clk => plb_clk,
		plb_rst => plb_Rst,
		plb_abort => plb_abort,
		plb_abus => plb_ABus,
		plb_be => plb_BE,
		plb_buslock => plb_busLock,
		plb_compress => plb_compress,
		plb_guarded => plb_guarded,
		plb_lockerr => plb_lockErr,
		plb_masterid => plb_masterID,
		plb_msize => plb_MSize,
		plb_ordered => plb_ordered,
		plb_pavalid => plb_PAValid,
		plb_rnw => plb_RNW,
		plb_size => plb_size,
		plb_type => plb_type,
		sl_addrack => sl_addrAck,
		sl_mbusy => sl_MBusy,
		sl_merr => sl_MErr,
		sl_rearbitrate => sl_rearbitrate,
		sl_ssize => sl_SSize,
		sl_wait => sl_wait,
		plb_rdprim => plb_rdPrim,
		plb_savalid => plb_SAValid,
		plb_wrprim => plb_wrPrim,
		plb_wrburst => plb_wrBurst,
		plb_wrdbus => plb_wrDBus,
		sl_wrbterm => sl_wrBTerm,
		sl_wrcomp => sl_wrComp,
		sl_wrdack => sl_wrDAck,
		plb_rdburst => plb_rdBurst,
		sl_rdbterm => sl_rdBTerm,
		sl_rdcomp => sl_rdComp,
		sl_rddack => sl_rdDAck,
		sl_rddbus => sl_rdDBus,
		sl_rdwdaddr => sl_rdWdAddr,
		plb_pendreq => plb_pendReq,
		plb_pendpri => plb_pendPri,
		plb_reqpri => plb_reqPri,
		-- user port
		o_bus2user_data => plb2opb_data,
		i_user2bus_data => opb2plb_data,
		o_user_addr => plb2opb_addr,
		o_user_be => plb2opb_be,
		o_user_wr_req => plb2opb_wr_req,
		i_user_wr_ready => opb2plb_wr_ready,
		o_user_rd_req => plb2opb_rd_req,
		i_user_rd_done => opb2plb_rd_done
	);
end architecture plb2opb_arc;