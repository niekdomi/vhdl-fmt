--------------------------------------------------------------------------------
-- plb_slave.vhd 
-- Number of Slices:                      77  out of   3008     2%  
-- Number of Slice Flip Flops:           134  out of   6016     2%  
-- Number of 4 input LUTs:               123  out of   6016     2%  
-- Number of bonded IOBs:                217  out of    140   155% (*) 
-- Number of BRAMs:                        8  out of     28    28%  
-- Number of GCLKs:                        1  out of     16     6%
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

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity plb_slave is
generic (
	C_NUM_MASTERS : integer := 2;
	C_BASEADDR : std_logic_vector := X"7000_0000";
	C_HIGHADDR : std_logic_vector := X"7fff_ffff";
	C_INCLUDE_BURST_CACHELN_SUPPORT : integer := 1; -- means ppc 8 line transfer only!!!
	C_USER_AWIDTH : integer := 11;
	C_PLB_DWIDTH : integer range 64 to 64 := 64;
	C_PLB_AWIDTH : integer range 32 to 32 := 32;
	C_PLB_CLK_PERIOD_PS : integer := 40000;
	C_PLB_MID_WIDTH : integer := 1;
	C_PIPLINED_TRANSFER_EN : integer := 1;
	C_CHIPSCOPE_EN : integer := 0
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
	-- user port
	o_bus2user_data : out std_logic_vector(C_PLB_DWIDTH-1 downto 0);
	i_user2bus_data : in std_logic_vector(C_PLB_DWIDTH-1 downto 0);
	o_user_addr : out std_logic_vector(C_USER_AWIDTH-1 downto 0);
	o_user_be : out std_logic_vector(C_PLB_DWIDTH/8-1 downto 0);
	o_user_wr_req : out std_logic;
	i_user_wr_ready : in std_logic;
	o_user_rd_req : out std_logic;
	i_user_rd_done : in std_logic;
	o_user_burst : out std_logic
);
end plb_slave;

architecture multi_stm of plb_slave is
	-------------------------------------------------------------------
	--
	--  IBA/PLB core component declaration
	--
	--    Number of PLB masters: 1
	--    Number of PLB slaves:  1
	--
	-------------------------------------------------------------------
	component iba_plb
	  port
	  (
		control           : inout std_logic_vector(35 downto 0);
		trig_in           : in    std_logic_vector(55 downto 0);
		plb_clk           : in    std_logic;
		plb_rst           : in    std_logic;
		plb_abort         : in    std_logic;
		plb_be            : in    std_logic_vector(0 to 7);
		plb_buslock       : in    std_logic;
		plb_masterid      : in    std_logic_vector(0 to 3);
		plb_msize         : in    std_logic_vector(0 to 1);
		plb_pavalid       : in    std_logic;
		plb_savalid       : in    std_logic;
		plb_rdprim        : in    std_logic;
		plb_rnw           : in    std_logic;
		plb_size          : in    std_logic_vector(0 to 3);
		plb_wrprim        : in    std_logic;
		plb_abus          : in    std_logic_vector(0 to 31);
		plb_wrdbus        : in    std_logic_vector(0 to 63);
		sl_rddbus         : in    std_logic_vector(0 to 63);
		---- INDIVIDUAL MASTER SIGNALS
		plb_maddrack      : in    std_logic_vector(0 to (1*1)-1);
		plb_mbusy         : in    std_logic_vector(0 to (1*1)-1);
		plb_merr          : in    std_logic_vector(0 to (1*1)-1);
		plb_mrddack       : in    std_logic_vector(0 to (1*1)-1);
		plb_mrdwdaddr     : in    std_logic_vector(0 to (4*1)-1);
		plb_mrearbitrate  : in    std_logic_vector(0 to (1*1)-1);
		plb_mssize        : in    std_logic_vector(0 to (2*1)-1);
		plb_mwrdack       : in    std_logic_vector(0 to (1*1)-1);
		m_abort           : in    std_logic_vector(0 to (1*1)-1);
		m_be              : in    std_logic_vector(0 to (8*1)-1);
		m_buslock         : in    std_logic_vector(0 to (1*1)-1);
		m_msize           : in    std_logic_vector(0 to (2*1)-1);
		m_priority        : in    std_logic_vector(0 to (2*1)-1);
		m_request         : in    std_logic_vector(0 to (1*1)-1);
		m_rnw             : in    std_logic_vector(0 to (1*1)-1);
		m_size            : in    std_logic_vector(0 to (4*1)-1);
		---- INDIVIDUAL SLAVE SIGNALS
		sl_addrack        : in    std_logic_vector(0 to (1*1)-1);
		sl_rddack         : in    std_logic_vector(0 to (1*1)-1);
		sl_rdwdaddr       : in    std_logic_vector(0 to (4*1)-1);
		sl_rearbitrate    : in    std_logic_vector(0 to (1*1)-1);
		sl_ssize          : in    std_logic_vector(0 to (2*1)-1);
		sl_wait           : in    std_logic_vector(0 to (1*1)-1);
		sl_wrcomp         : in    std_logic_vector(0 to (1*1)-1);
		sl_wrdack         : in    std_logic_vector(0 to (1*1)-1)
	  );
	end component;
	component icon
	  port
	  (
		control0 : out std_logic_vector(35 downto 0)
	  );
	end component;
	-- signals for cs 
	signal control0 : std_logic_vector(35 downto 0);
	signal cs_userinputs : std_logic_vector(55 downto 0) := (others => '0');
	signal cs_plb_maddrack      : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_plb_mbusy         : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_plb_merr          : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_plb_mrddack       : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_plb_mrdwdaddr     : std_logic_vector(0 to (4*1)-1) := (others => '0');
	signal cs_plb_mrearbitrate  : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_plb_mssize        : std_logic_vector(0 to (2*1)-1) := (others => '0');
	signal cs_plb_mwrdack       : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_m_plb_abort       : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_m_plb_be          : std_logic_vector(0 to (8*1)-1) := (others => '0');
	signal cs_m_plb_buslock     : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_m_plb_msize       : std_logic_vector(0 to (2*1)-1) := (others => '0');
	signal cs_m_plb_priority    : std_logic_vector(0 to (2*1)-1) := (others => '0');
	signal cs_m_plb_request     : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_m_plb_rnw         : std_logic_vector(0 to (1*1)-1) := (others => '0');
	signal cs_m_plb_size        : std_logic_vector(0 to (4*1)-1) := (others => '0');
	signal addrack_v : std_logic_vector(0 to (1*1)-1);
	signal rddack_v : std_logic_vector(0 to (1*1)-1);
	signal swait_v : std_logic_vector(0 to (1*1)-1);
	signal wrcomp_v : std_logic_vector(0 to (1*1)-1);
	signal wrdack_v : std_logic_vector(0 to (1*1)-1);
	signal rearbitrate_v : std_logic_vector(0 to (1*1)-1);

	-- types
	--type t_state is (AVALID, SDREADY, PREREAD, READ, WRITE);
	--subtype t_state is std_logic_vector(4 downto 0);
	--constant AVALID		: std_logic_vector(4 downto 0) := "00001";
	--constant SDREADY	: std_logic_vector(4 downto 0) := "00010";
	--constant PREREAD	: std_logic_vector(4 downto 0) := "00100";
	--constant READ		: std_logic_vector(4 downto 0) := "01000";
	--constant WRITE		: std_logic_vector(4 downto 0) := "10000";
	
	--subtype t_a_state is std_logic_vector(0 downto 0);
	--constant AVALID		: std_logic_vector(0 downto 0) := "0";
	--constant SDREADY	: std_logic_vector(0 downto 0) := "1";
	
	subtype t_d_state is std_logic_vector(4 downto 0);
	constant IDLE		: std_logic_vector(4 downto 0) := "00001";
	constant SDREADY	: std_logic_vector(4 downto 0) := "00010";
	constant PREREAD	: std_logic_vector(4 downto 0) := "00100";
	constant READ		: std_logic_vector(4 downto 0) := "01000";
	constant WRITE		: std_logic_vector(4 downto 0) := "10000";
	
	
	-- constants
	--constant H : std_logic := '1';
	--constant L : std_logic := '0';
	-- mask with relevant address bits for addrescompare
	constant DF_ADDR_MASK : std_logic_vector(0 to C_PLB_AWIDTH-1) := not (C_HIGHADDR - C_BASEADDR);
	-- plb_size
	constant SINGLE : std_logic_vector(0 to 3) := "0000";
	constant LINE8  : std_logic_vector(0 to 3) := "0010";
	-- static signals
	signal GND : std_logic := L;
	signal VCC : std_logic := H;
	signal GND64 : std_logic_vector(0 to C_PLB_DWIDTH-1) := (others =>L);
	signal GND1 : std_logic_vector(0 to 0) := (others =>L);
	-- signals
	signal d_state : t_d_state := IDLE;
	signal addr_valid : std_logic;
	signal addrAck : std_logic := L;
	signal rdDAck : std_logic := L;
	signal wrDAck : std_logic := L;
	signal rdComp : std_logic := L;
	signal wrComp : std_logic := L;
	signal RNW : std_logic;
	signal primary : std_logic := H;
	signal data_out : std_logic_vector(0 to C_PLB_DWIDTH-1);
	signal MBusy : std_logic_vector(0 to C_NUM_MASTERS-1) := (others =>L);
	signal MErr : std_logic_vector(0 to C_NUM_MASTERS-1) := (others =>L);
	signal ABus : std_logic_vector(0 to C_PLB_AWIDTH-1) := (others =>L);
	signal rdPrim : std_logic;
	signal wrPrim : std_logic;
	signal PAValid : std_logic;
	signal SAValid : std_logic;
	signal burst : std_logic := L;
	signal plb_rd_burst_addr : std_logic_vector(0 to 1);
	signal user_burst_addr : std_logic_vector(0 to 1);
	signal BE : std_logic_vector(0 to C_PLB_DWIDTH/8-1);
	signal burst_cnt : std_logic_vector(1 downto 0);
	signal reg_ABus : std_logic_vector(0 to C_PLB_AWIDTH-1) := (others =>L);
	signal rearbitrate : std_logic;
	signal rdBTerm : std_logic;
	signal wrBTerm : std_logic;
	signal SSize : std_logic_vector(0 to 1);
	signal swait : std_logic;
	signal rdWdAddr : std_logic_vector(0 to 3);
	
	signal user_addr : std_logic_vector(31 downto 0);
	
	signal rd_req : std_logic;
	signal wr_req : std_logic;
	signal reg_user_rd_done : std_logic;
--	attribute FSM_ENCODING : string;
--	attribute FSM_ENCODING of d_state: signal is "USER";
begin
	-- oututs
	sl_addrAck <= addrAck;
	sl_MBusy <= MBusy;
	sl_MErr <= MErr;
	sl_rdBTerm <= rdBTerm;
	sl_rdComp <= rdComp;
	sl_rdDAck <= rdDAck;
	sl_rdDBus <= crossbits(i_user2bus_data) when rdDAck=H else GND64;
	sl_rdWdAddr <= rdWdAddr;
	sl_rearbitrate <= rearbitrate;
	sl_SSize <= SSize;
	sl_wait <= swait;
	sl_wrBTerm <= wrBTerm;
	sl_wrComp <= wrComp;
	sl_wrDAck <= wrDAck;
	
	--??für was-3?? o_user_addr <= crossbits(ABus(C_PLB_AWIDTH-C_USER_AWIDTH-3 to 26) & user_burst_addr);
	user_addr <= crossbits(ABus(0 to 26) & user_burst_addr & "000");
	o_user_addr <= user_addr(C_USER_AWIDTH-1 downto 0);
--	o_bus2user_data <= crossbits(plb_wrDBus);
	o_user_be <= crossbits(BE);
	o_user_wr_req <= wrDAck;
	o_user_rd_req <= rd_req;
	o_user_burst <= burst;
	--process(plb_clk)
	--begin
	--	if (rising_edge(plb_clk)) then
	--		if (wrDAck=H) then
				o_bus2user_data <= crossbits(plb_wrDBus);
	--		end if;
	--	end if;
	--end process;

	
	rdWdAddr <= L & plb_rd_burst_addr & L;
	rearbitrate <= L;
	rdBTerm <= L;
	wrBTerm <= L;
	
	plb32 : if C_PLB_DWIDTH=32 generate SSize <= "00"; end generate plb32;
	plb64 : if C_PLB_DWIDTH=64 generate SSize <= "01"; end generate plb64;
	plb128 : if C_PLB_DWIDTH=128 generate SSize <= "10"; end generate plb128;
	
	addr_valid <= H when (reg_ABus and DF_ADDR_MASK) = (C_BASEADDR and DF_ADDR_MASK) else L;
	
	state_machine : process(plb_clk, plb_rst)
	begin
		if (plb_rst = H) then
			d_state <= IDLE;
			addrAck <= L;
			rdDAck <= L;
			wrDAck <= L;
			rdComp <= L;
			wrComp <= L;
			swait <= L;
			plb_rd_burst_addr <= (others => L);
			burst <= L;
			ABus  <= (others => L);
			burst_cnt <= (others => L);
			user_burst_addr <= (others => L);
		elsif (rising_edge(plb_clk)) then
			-- default values
			addrAck <= L;
			rdDAck <= L;
			wrDAck <= L;
			rdComp <= L;
			wrComp <= L;
			rd_req <= rd_req and not i_user_rd_done;--L;
			swait <= L;
			-- registers
			reg_ABus <= plb_ABus;
			if (addr_valid=H and plb_abort=L and (plb_size=SINGLE or (plb_size=LINE8 and C_INCLUDE_BURST_CACHELN_SUPPORT=1))) then
				if (plb_PAValid=H) then
					if (addrAck=L) then
						swait <= H;
					end if;
					if (d_state=IDLE) then
						addrAck <= H;
						RNW <= plb_RNW;
						-- save signals
						ABus <= plb_ABus;
						if (plb_size(2)=H) then
							burst <= H;
							BE <= (others => H);
						else
							burst <= L;
							BE <= plb_BE;
						end if;
						user_burst_addr <= plb_ABus(27 to 28);
						-- start data transfer
						if (plb_RNW=H) then
							d_state <= PREREAD;
							rd_req <= H;
						else
							d_state <= WRITE;
						end if;
					end if;
				elsif (C_PIPLINED_TRANSFER_EN=1 and plb_SAValid=H) then
					swait <= H;
					if (d_state=IDLE) then
						addrAck <= H;
						if (plb_RNW=H) then
							rd_req <= H;
						end if;
						RNW <= plb_RNW;
						-- save signals
						ABus <= plb_ABus;
						if (plb_size(2)=H) then
							burst <= H;
							BE <= (others => H);
						else
							burst <= L;
							BE <= plb_BE;
						end if;
						user_burst_addr <= plb_ABus(27 to 28);
						-- wait until databus ready
						d_state <= SDREADY;
					end if;
				end if;
			end if;
			-- data state machine
			burst_cnt <= (others => L);
			plb_rd_burst_addr <= (others => L);
			reg_user_rd_done <= L;
			case (d_state) is
				when IDLE =>
				when SDREADY => -- unused if C_PIPLINED_TRANSFER_EN/=1
					reg_user_rd_done <= i_user_rd_done;
					if (RNW=H and (plb_rdPrim=H or (addrAck=H and plb_PAValid=H))) then
						-- start data transfer
						d_state <= READ;
						rdComp <= not burst;
					elsif (RNW=L and (plb_wrPrim=H or (addrAck=H and plb_PAValid=H))) then
						-- start data transfer
						d_state <= WRITE;
					end if;
				when PREREAD =>
					reg_user_rd_done <= i_user_rd_done;
					d_state <= READ;
					rdComp <= not burst;
				when READ =>
					if (i_user_rd_done=H or reg_user_rd_done=H) then
						rdDAck <= H;
						if (burst=L or C_INCLUDE_BURST_CACHELN_SUPPORT=0) then
							-- single transfer
							d_state <= IDLE;
							plb_rd_burst_addr <= ABus(27 to 28);
						else
							-- 4*64er burst 
							rd_req <= H;
							user_burst_addr <= user_burst_addr + 1;
							burst_cnt <= burst_cnt + 1;
							plb_rd_burst_addr <= ABus(27 to 28) + burst_cnt;
							if (burst_cnt=2) then
								rdComp <= H;
							elsif (burst_cnt=3) then
								rd_req <= L;
								user_burst_addr <= user_burst_addr;
								d_state <= IDLE;
							end if;
						end if;
					end if;
				when WRITE =>
					if (i_user_wr_ready=H) then
						wrDAck <= H;
						if (burst=L or C_INCLUDE_BURST_CACHELN_SUPPORT=0) then
							-- single transfer
							wrComp <= H;
							d_state <= IDLE;
						else
							-- 4*64er burst
							burst_cnt <= burst_cnt + 1;
						end if;
					end if;
					if (wrDAck=H and burst=H) then
						user_burst_addr <= user_burst_addr + 1;
						if (burst_cnt=3) then
							wrComp <= H;
							d_state <= IDLE;
						end if;
					end if;
				when others =>
					null;
			end case;
			-- MBusy ------------------------------
			if (addrAck=H) then
				for i in 0 to C_NUM_MASTERS-1 loop
					if (i=plb_masterID) then
						MBusy(i) <= H;
					else
						MBusy(i) <= L;
					end if;
				end loop;
			elsif (wrComp=H or rdComp=H) then
				MBusy <= (others => L);
			end if;
		end if;
	end process state_machine;
	
	CHIPSCOPE : if (C_CHIPSCOPE_EN=1) generate
	begin
		addrack_v(0) <= addrack;
		rddack_v(0) <= rddack;
		swait_v(0) <= swait;
		wrcomp_v(0) <= wrcomp;
		wrdack_v(0) <= wrdack;
		rearbitrate_v(0) <= rearbitrate;
		
		cs_userinputs(10 downto 0) <= crossbits(ABus(18 to 26) & user_burst_addr);
		cs_userinputs(18 downto 11) <= crossbits(BE);
		cs_userinputs(20 downto 19) <= burst_cnt;
		cs_userinputs(21) <= burst;
		cs_userinputs(26 downto 22) <= d_state;
		cs_userinputs(27) <= rdComp;
		cs_userinputs(28) <= rd_req;
		cs_userinputs(30 downto 29) <= MBusy;
		cs_userinputs(38 downto 31) <= (others => L);
		
		i_iba_plb : iba_plb
		port map
		(
			control           => control0,
			trig_in           => cs_userinputs,
			plb_clk           => plb_clk,
			plb_rst           => plb_rst,
			plb_abort         => plb_abort,
			plb_be            => plb_be,
			plb_buslock       => plb_buslock,
			plb_masterid      => plb_masterid,
			plb_msize         => plb_msize,
			plb_pavalid       => plb_pavalid,
			plb_savalid       => plb_savalid,
			plb_rdprim        => plb_rdprim,
			plb_rnw           => plb_rnw,
			plb_size          => plb_size,
			plb_wrprim        => plb_wrprim,
			plb_abus          => plb_abus,
			plb_wrdbus        => GND64,
			sl_rddbus         => GND64,
			-- INDIVIDUAL MASTER SIGNALS (unused)
			plb_maddrack      => cs_plb_maddrack,
			plb_mbusy         => cs_plb_mbusy,
			plb_merr          => cs_plb_merr,
			plb_mrddack       => cs_plb_mrddack,
			plb_mrdwdaddr     => cs_plb_mrdwdaddr,
			plb_mrearbitrate  => cs_plb_mrearbitrate,
			plb_mssize        => cs_plb_mssize,
			plb_mwrdack       => cs_plb_mwrdack,
			m_abort           => cs_m_plb_abort,
			m_be              => cs_m_plb_be,
			m_buslock         => cs_m_plb_buslock,
			m_msize           => cs_m_plb_msize,
			m_priority        => cs_m_plb_priority,
			m_request         => cs_m_plb_request,
			m_rnw             => cs_m_plb_rnw,
			m_size            => cs_m_plb_size,
			-- INDIVIDUAL SLAVE SIGNALS
			sl_addrack        => addrack_v,
			sl_rddack         => rddack_v,
			sl_rdwdaddr       => rdwdaddr,
			sl_rearbitrate    => rearbitrate_v,
			sl_ssize          => ssize,
			sl_wait           => swait_v,
			sl_wrcomp         => wrcomp_v,
			sl_wrdack         => wrdack_v
		);
		i_icon : icon
		port map
		(
			control0    => control0
		);
	end generate CHIPSCOPE;
end architecture multi_stm;