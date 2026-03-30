--------------------------------------------------------------------------------
--
--	opbif_extmem
--
--------------------------------------------------------------------------------
--
--	project		: ppc-card, imp2, sac2
--	programmer	: C. Leuthold, INDEL AG
--	date		: 16.09.2004
--	version		: 1.00
--	language	: VHDL
--	system		: ISE / EDK
--
--	purpose
--		extern memory and periphery-bus controller for ppc-card targets like
--		imp2, sac2 and future developments
--
-------------------------------------------------------------------------------- 

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	2.00a	16.09.2004 -le:	imp2 and sac2 compatible version
--							new generic
--								C_TARGET: IMP2=0, SAC2=1, ...
--								C_WR_FIFO_SIZE : (0..16) implement a write fifo
--									with C_WR_FIFO_SIZE size
--							new port-signals
--								sac2 spez. IOs
--							replaced component
--								opb_generic_if_fifo, opb_generic_if with fifo
--			21.09.2004 -le:	test...
--			23.11.2004 -le: add sac2 spez ios for hw-rev A
--			28.01.2005 -le: IMP2: BEN only with cs1: bootsys works also on a
--									SAC-print
--			13.09.2005 -le: clean up, remove sync of busy, add target MAX2, same
--							func. like sac2
--			29.11.2005 -le: change def. values of i_WEn and i_OEn to '1' 
--			14.03.2006 -le: add LAN support on DF_TARGET_DEVELOP
--			15.05.2006 -le: use INDEL_pkg for DF_PKG_TARGET_ and add support for
--							target IT-MAS2
--			21.11.2006 -le: add support for target INFO-MAX4
--	11.05.2007-le:	- add svn keywords
--	03.07.2007-le:	- add DF_PKG_TARGET_LAN and DF_PKG_TARGET_NO_LAN and change
--						DF_TARGET_DEVELOP to 256 to avoid a change for each new
--						target.
--	16.07.2010-le:	- support DF_PKG_TARGET_FLASH_MRAM: c/mram, flash but no lan
--	21.07.2010-le:	- correct FLASH_MRAM outputs
--	27.04.2011-le:	- add C_END_AFTER_BUSY_IMM to end after busy immediately
--						default is stop count waitstatis until busy is avtive
--------------------------------------------------------------------------------
--$Rev:: 1916                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-04-27 19:54:59 +0200 (Mi., 27 Apr 2011)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
----- includes -----------------------------------------------------------------
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

--
-- library unsigned is used for overloading of "=" which allows integer to
-- be compared to std_logic_vector
use ieee.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

-------------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity opbif_extmem is
-- Generics to be set by user
	generic (
		-- Target typ
		C_TARGET : integer := 0;		-- new: DF_PKG_TARGET_LAN(0), DF_PKG_TARGET_NO_LAN(1), DF_PKG_TARGET_FLASH_MRAM(100)/ old: DF_PKG_TARGET_IMP2=0, DF_PKG_TARGET_SAC2=1, DF_PKG_TARGET_MAX2=2, DF_PKG_TARGET_IT_MAS2=3, DF_PKG_TARGET_MAX4=4
		--Generics set for IPIF
		C_DWIDTH : integer := 32;
		C_AWIDTH : integer := 32;
		C_END_AFTER_BUSY_IMM : integer := 0 -- /=0: end after busy immediately, 0: stop count waitstatis until busy is avtive
	);
	port (
		-- System Port Declarations ********************************************
		i_Clk			: in std_logic;
		i_Rst			: in std_logic;
		-- OPB IF Port Declarations ********************************************
		i_addr			: in std_logic_vector(C_AWIDTH-1 downto 0);
		i_rd_acc		: in std_logic;
		i_wr_acc		: in std_logic;
		i_byte_ebl		: in std_logic_vector(C_DWIDTH/8-1 downto 0);
		i_wr_data		: in std_logic_vector(C_DWIDTH-1 downto 0);
		o_rd_data		: out std_logic_vector(C_DWIDTH-1 downto 0);
		o_rd_acc_done	: out std_logic;
		o_wr_acc_done	: out std_logic;
		-- ctrl singnals
		i_MemCnt_OFF	: in std_logic := '0';
		i_ConfReg		: in std_logic_vector(31 downto 0) := x"000B_FFFF";
		-- Memory signals
		o_Mem_A			: out std_logic_vector(20 downto 0);
		b_Mem_DQ_I		: in std_logic_vector(15 downto 0);
		b_Mem_DQ_O		: out std_logic_vector(15 downto 0);
		b_Mem_DQ_T		: out std_logic_vector(15 downto 0);
		no_Flash_CEn	: out std_logic;
		no_Mem_CEn1		: out std_logic;
		no_Mem_CEn2		: out std_logic;
		no_Mem_OEN		: out std_logic;
		no_Mem_WEN		: out std_logic;
		no_Mem_BEN		: out std_logic_vector(1 downto 0);
		ni_Mem_Busy		: in std_logic := '1';
		-- imp2 spez. outputs
		no_Lan_IWR0		: out std_logic;
		no_Lan_IWR1		: out std_logic;
		-- shared IOs
		i_BEn			: in std_logic_vector(1 downto 0) := (others => '0');
		i_A_Bus			: in std_logic_vector(20 downto 0) := (others => '0');
		i_OEn			: in std_logic := '1';
		i_WEn			: in std_logic := '1';
		i_D_Bus_OE		: in std_logic := '0';
		i_D_Bus			: in std_logic_vector(15 downto 0) := (others => '0');
		o_D_Bus			: out std_logic_vector(15 downto 0);
		-- test points
		tp1				: out std_logic;
		tp2				: out std_logic;
		tp3				: out std_logic;
		tp4				: out std_logic
	);
end opbif_extmem;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture implementation of opbif_extmem is
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	constant C_WRITE_REG		: integer := 1;		-- 0: no reg for write..

	constant DF_TARGET_DEVELOP	: integer := 256;		-- always the last!
	-- components --------------------------------------------------------------

	----------------------------------------------------------------------------
	-- Signal and Type Declarations
	----------------------------------------------------------------------------
	-- types -------------------------------------------------------------------
	-- signals -----------------------------------------------------------------

	----------------------------------------------------------------------------
	-- Signal and Type Declarations
	----------------------------------------------------------------------------
	-- types -------------------------------------------------------------------
	type t_states is (idle, read, write);
	-- signals -----------------------------------------------------------------
	signal rst				: std_logic;
	signal clk				: std_logic;
	signal data				: std_logic_vector(C_DWIDTH-1 downto 0);
	signal Reg				: std_logic_vector(C_DWIDTH-1 downto 0);
	signal ConfReg			: std_logic_vector(7 downto 0);
	signal waitstate		: std_logic_vector(3 downto 0);
	signal waitrepeat		: std_logic_vector(2 downto 0);
	signal CEn				: std_logic;
	signal WEn				: std_logic;
	signal myOE				: std_logic:=L;
	signal Flash			: std_logic:=L;
	signal Cs1				: std_logic:=L;
	signal Cs2				: std_logic:=L;
	signal state			: t_states;
	signal loc_addr			: std_logic_vector(C_AWIDTH-1 downto 0);
	signal loc_rd_acc		: std_logic;
	signal loc_wr_acc		: std_logic;
	signal loc_byte_ebl		: std_logic_vector(C_DWIDTH/8-1 downto 0);
	signal loc_wr_data		: std_logic_vector(C_DWIDTH-1 downto 0);
	signal loc_rd_data		: std_logic_vector(C_DWIDTH-1 downto 0);
	signal loc_rd_acc_done	: std_logic;
	signal loc_wr_acc_done	: std_logic;
	signal a1				: std_logic;
	signal done				: std_logic;
	signal BEn0				: std_logic;
	signal BEn1				: std_logic;
	signal B32				: std_logic;
	signal acc_runs			: std_logic;
	signal loc_Busy			: std_logic;
	signal Busy				: std_logic;
	signal outData			: std_logic_vector(15 downto 0);
	signal inData			: std_logic_vector(15 downto 0);
	signal XConf			: std_logic_vector(1 downto 0); -- bit1 -> cross databus (lan on imp2) bit0 -> cross byteEn (cram on imp2)
	signal BusyEn			: std_logic;
begin -- architecture
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

	tp1 <= not(CEn and (Flash or Cs1 or Cs2));
	tp2 <= a1;
	tp3 <= not(WEn);--not(CEn and loc_wr_acc and Cs2 and not(loc_addr(5))); --o_Lan_IWR0;
	tp4 <= not(CEn and loc_rd_acc); --not(CEn and loc_wr_acc and Cs2 and     loc_addr(5));  --o_Lan_IWR1;

	imp_2: if (C_TARGET=DF_PKG_TARGET_IMP2
			or C_TARGET=DF_PKG_TARGET_IT_MAS2
			or C_TARGET=DF_PKG_TARGET_LAN) generate
		-- imp2 output functionality
		no_Mem_BEN(0) <= not(BEn0 and Cs1);
		no_Mem_BEN(1) <= not(BEn1 and Cs1);
		o_Mem_A(20 downto 1) <= loc_addr(21 downto 2);
		o_Mem_A(0) <= a1 or loc_addr(1);
		no_Flash_CEn <= not(CEn and Flash);
		no_Mem_CEn1 <= not(CEn and Cs1);
		no_Mem_CEn2 <= not(CEn and Cs2);
		no_Mem_OEN <= not(CEn and loc_rd_acc);
		no_Mem_WEN <= not(WEn);
		no_Lan_IWR0 <= not(CEn and loc_wr_acc and Cs2 and not(loc_addr(5)));
		no_Lan_IWR1 <= not(CEn and loc_wr_acc and Cs2 and loc_addr(5));
		myOE <= CEn and loc_wr_acc;
		Busy <= not(ni_Mem_Busy) and BusyEn;
	end generate imp_2;
	sac_2: if (C_TARGET=DF_PKG_TARGET_SAC2
			or C_TARGET=DF_PKG_TARGET_MAX2
			or C_TARGET=DF_PKG_TARGET_MAX4
			or C_TARGET=DF_PKG_TARGET_NO_LAN) generate
		-- sac2 output functionality
		no_Flash_CEn <= not(CEn and Flash) when i_MemCnt_OFF=L else H;
		no_Mem_CEn1 <= H;-- unused
		no_Mem_CEn2 <= H;-- unused
		no_Lan_IWR0 <= H;-- unused
		no_Lan_IWR1 <= H;-- unused
		myOE <= CEn and loc_wr_acc when i_MemCnt_OFF=L else L; -- h: outputs / l: inputs
		Busy <= L;-- no Busy input
		-- shared ios
		-- inputs on databus
		o_D_Bus <= b_Mem_DQ_i;
		-- outputs on addrbus
		no_Mem_BEN(0) <= i_BEn(0);
		no_Mem_BEN(1) <= i_BEn(1);
		no_Mem_OEN <= not(CEn and loc_rd_acc) when i_MemCnt_OFF=L else i_OEn;
		no_Mem_WEN <= not(WEn) when i_MemCnt_OFF=L else i_WEn;
		o_Mem_A(20 downto 1) <= loc_addr(21 downto 2) when i_MemCnt_OFF=L else i_A_Bus(20 downto 1);
		o_Mem_A(0) <= a1 or loc_addr(1) when i_MemCnt_OFF=L else i_A_Bus(0);
	end generate SAC_2;
	DEVELOP: if C_TARGET>=DF_TARGET_DEVELOP generate
		no_Mem_BEN(0) <= not(BEn0) when i_MemCnt_OFF=L else i_BEn(0);
		no_Mem_BEN(1) <= not(BEn1) when i_MemCnt_OFF=L else i_BEn(1);
		o_Mem_A(20 downto 1) <= loc_addr(21 downto 2) when i_MemCnt_OFF=L else i_A_Bus(20 downto 1);
		o_Mem_A(0) <= a1 or loc_addr(1) when i_MemCnt_OFF=L else i_A_Bus(0);
		no_Flash_CEn <= not(CEn and Flash) when i_MemCnt_OFF=L else H;
		no_Mem_CEn1 <= not(CEn and Cs1) when i_MemCnt_OFF=L else H;
		no_Mem_CEn2 <= not(CEn and Cs2) when i_MemCnt_OFF=L else H;
		no_Mem_OEN <= not(CEn and loc_rd_acc) when i_MemCnt_OFF=L else i_OEn;
		no_Mem_WEN <= not(WEn) when i_MemCnt_OFF=L else i_WEn;
		myOE <= CEn and loc_wr_acc when i_MemCnt_OFF=L else i_D_Bus_OE; -- h: outputs / l: inputs
		o_D_Bus <= b_Mem_DQ_i;
		no_Lan_IWR0 <= not(CEn and loc_wr_acc and Cs2 and not(loc_addr(5)));
		no_Lan_IWR1 <= not(CEn and loc_wr_acc and Cs2 and loc_addr(5));
		Busy <= not(ni_Mem_Busy) and BusyEn;
	end generate DEVELOP;
	FLASH_MRAM : if C_TARGET=DF_PKG_TARGET_FLASH_MRAM generate
		no_Mem_BEN(0) <= not(BEn0 and Cs1);
		no_Mem_BEN(1) <= not(BEn1 and Cs1);
		o_Mem_A(20 downto 1) <= loc_addr(21 downto 2);
		o_Mem_A(0) <= a1 or loc_addr(1);
		no_Flash_CEn <= not(CEn and Flash);
		no_Mem_CEn1 <= not(CEn and Cs1);
		no_Mem_CEn2 <= H;
		no_Mem_OEN <= not(CEn and loc_rd_acc);
		no_Mem_WEN <= not(WEn);
		no_Lan_IWR0 <= H;
		no_Lan_IWR1 <= H;
		myOE <= CEn and loc_wr_acc;
		Busy <= L;
	end generate FLASH_MRAM;

	B32 <= loc_byte_ebl(1) and loc_byte_ebl(2);

	TristateOutput : process(myOE, rst)
	begin
		if rst=H then
			b_Mem_DQ_T <= (others => H);				-- Z
		elsif myOE=H then
			b_Mem_DQ_T <= (others => L);				-- output
		else
			b_Mem_DQ_T <= (others => H);				-- input/Z
		end if;
	end process;

	DATABUS_X : process(outData,b_Mem_DQ_i,Cs2)

	begin
		if XConf(1)=H then
			-- databus crossing (a.e. for LAN91C96 on imp2)
			for i in 0 to 15 loop
				b_Mem_DQ_O(i) <= outData(15-i);
				inData(i) <= b_Mem_DQ_i(15-i);
			end loop;
		else
			b_Mem_DQ_O <= outData;
			inData <= b_Mem_DQ_i;
		end if;
	end process;

	ByteEnable : process(a1,loc_byte_ebl)
	begin
		if a1=H then
			if XConf(0)=L then
				BEn0 <= loc_byte_ebl(0);
				BEn1 <= loc_byte_ebl(1);
			else
				-- byteEnable crossing (a.e. for CRam on imp2)
				BEn0 <= loc_byte_ebl(1);
				BEn1 <= loc_byte_ebl(0);
			end if;
		else
			if XConf(0)=L then
				BEn0 <= loc_byte_ebl(2);
				BEn1 <= loc_byte_ebl(3);
			else
				-- byteEnable crossing (a.e. for CRam on imp2)
				BEn0 <= loc_byte_ebl(3);
				BEn1 <= loc_byte_ebl(2);
			end if;
		end if;
	end process;

	memctrl : process (clk)
	begin
		if rising_edge(clk) then
			if (((Flash=H) or (Cs1=H) or (Cs2=H)) and done=L) then
				if acc_runs=L then
					a1 <= loc_addr(1);
				end if;
				CEn	 <= H;
				WEn <= loc_wr_acc;
				if (waitstate>=ConfReg(3 downto 0) and Busy=L) then
					if ConfReg(7)=H and WEn=H then
						WEn <= L;
					else
						CEn <= L;
						WEn <= L;
						if a1=H then		-- read databus
							data(15 downto 0) <= inData;
						else
							data(31 downto 16) <= inData;
						end if;
						if B32=H and a1=L then
							-- repeat for 32 bit
							if waitrepeat >= ConfReg(6 downto 4) then
								waitstate <= (others => '0');
								a1 <= H;
							else
								waitrepeat <= waitrepeat + 1;
							end if;
						else
							done <= H;
							acc_runs <= L;
						end if;
					end if;
				else
					done <= L;
					acc_runs <= H;
					if Busy = L then
						waitstate <= waitstate + 1;
					elsif (C_END_AFTER_BUSY_IMM/=0) then
						waitstate <= ConfReg(3 downto 0);
					end if;
				end if;
			else
				WEn <= L;
				CEn <= L;
				done <= L;
				a1 <= L;
				waitrepeat <= (others => '0');
				waitstate <= (others => '0');
				acc_runs <= L;
			end if;
		end if;
	end process;

	bussize : process(a1,Reg,i_MemCnt_OFF,i_D_Bus)
	begin
		if C_TARGET>=DF_TARGET_DEVELOP and i_MemCnt_OFF=H then
			outData <= i_D_Bus;
		else
			if a1=H then
				outData <= Reg(15 downto 0);
			else
				outData <= Reg(31 downto 16);
			end if;
		end if;
	end process;

	addr_decode : process (loc_addr, rst, loc_rd_acc, loc_wr_acc)
	begin
		if rst=H then
			Flash <= L;
			Cs1 <= L;
			Cs2 <= L;
			ConfReg <= (others => '0');
			XConf <= "00";
			BusyEn <= L;
		else
			Flash <= L;
			Cs1 <= L;
			Cs2 <= L;
			ConfReg <= (others => '0');
			XConf <= "00";
			BusyEn <= L;
			if ((loc_rd_acc=H or loc_wr_acc=H )) then
				if C_TARGET=DF_PKG_TARGET_IMP2 or C_TARGET=DF_PKG_TARGET_IT_MAS2 or C_TARGET=DF_PKG_TARGET_LAN then
					-- imp2 with Cs2, Cs1 and flash
					--			Cs1: CRam
					--			Cs2: Lan
					if loc_addr(27 downto 26)="00" then
						Cs1 <= H;
						ConfReg <= i_ConfReg(7 downto 0);
						XConf <= "01";
						BusyEn <= i_ConfReg(30);
					elsif loc_addr(27 downto 26)="01" then
						Cs2 <= H;
						ConfReg <= i_ConfReg(15 downto 8);
						XConf <= "10";
						BusyEn <= H;
					else
						Flash <= H;
						ConfReg <= i_ConfReg(23 downto 16);
						XConf <= "00";
						BusyEn <= L;
					end if;
				elsif C_TARGET=DF_PKG_TARGET_SAC2 or C_TARGET=DF_PKG_TARGET_MAX2 or C_TARGET=DF_PKG_TARGET_MAX4 or C_TARGET=DF_PKG_TARGET_NO_LAN then
					-- sac2, max2 with flash
					Flash <= H;
					ConfReg <= i_ConfReg(23 downto 16);
				elsif C_TARGET=DF_PKG_TARGET_FLASH_MRAM then
					-- c96-ppc-card, gin-imp with flash
					if loc_addr(27)=L then
						Cs1 <= H;
						ConfReg <= i_ConfReg(7 downto 0);
						XConf <= i_ConfReg(25 downto 24);-- on imp2 ="01"
						BusyEn <=L;
					else
						Flash <= H;
						ConfReg <= i_ConfReg(23 downto 16);
						XConf <= i_ConfReg(29 downto 28);-- on ppc-card ="00"
						BusyEn <= L;
					end if;
				else -- develop mode: full configuration (inkl. crossing) over i_ConfReg
					if loc_addr(27 downto 26)="00" then
						Cs1 <= H;
						ConfReg <= i_ConfReg(7 downto 0);
						XConf <= i_ConfReg(25 downto 24);-- on imp2 ="01"
						BusyEn <= i_ConfReg(30);
					elsif loc_addr(27 downto 26)="01" then
						Cs2 <= H;
						ConfReg <= i_ConfReg(15 downto 8);
						XConf <= i_ConfReg(27 downto 26);-- on imp2 ="10"
						BusyEn <= i_ConfReg(31);		-- on imp2 = H
					else
						Flash <= H;
						ConfReg <= i_ConfReg(23 downto 16);
						XConf <= i_ConfReg(29 downto 28);-- on ppc-card ="00"
						BusyEn <= L;
					end if;
				end if;
			end if;
		end if;
	end process;
	-- opbif -------------------------------------------------------------------
	loc_rd_acc_done <= done;
	loc_wr_acc_done <= done;

	write_reg1: if C_WRITE_REG=1 generate
	opbif_write : process (clk)
	begin
		if rising_edge(clk) then
			if loc_wr_acc=H then 	-- write
				for i in 0 to C_DWIDTH/8-1 loop
					if loc_byte_ebl(i) = H then
						Reg(i*8+7 downto i*8) <= loc_wr_data(i*8+7 downto i*8);
					end if;
				end loop;
			else
				Reg <= (others => '0');
			end if;
		end if;
	end process;
	end generate write_reg1;

	write_no_reg1: if C_WRITE_REG=0 generate
	opbif_write : process (loc_byte_ebl,loc_wr_data)
	begin
		for i in 0 to C_DWIDTH/8-1 loop
			if loc_byte_ebl(i) = H then
				Reg(i*8+7 downto i*8) <= loc_wr_data(i*8+7 downto i*8);
			end if;
		end loop;
	end process;
	end generate write_no_reg1;

	opbif_read : process(loc_rd_acc, data)
	begin
		if loc_rd_acc=H then 	-- read
			loc_rd_data <= data;
		else
			loc_rd_data <= (others => '0');
		end if;
	end process;
end implementation;