--------------------------------------------------------------------------------
--
--  safty spi
--
--------------------------------------------------------------------------------
--
--	project		: safty spi
--	programmer	: c. lEUTHOLD, INDEL AG
--	date		: 19.12.2011
--	language	: VHDL
--	system		: Project Navigator
--
--	purpose
--		- safty spi
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	26.09.2013-le : - start
--	27.08.2014-le : - change protocol to get a bigger address space for copram
--	10.12.2014-le : - remove bram_wxx laches
--					- move tristates to top
--	08.01.2015-le : - add clock enables
--------------------------------------------------------------------------------
--$Rev:: 4846                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-13 10:35:14 +0200 (Fr., 13 Apr 2018)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
package safty_spi_pkg is
	constant DF_STATUS_RAM_MUX : natural:=  13; 
end package safty_spi_pkg;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity safty_spi is
	generic (
		WR_ADDR_OR	: std_logic_vector(15 downto 0) := x"0100";
		RD_ADDR_OR	: std_logic_vector(15 downto 0) := x"0000";
		NO_ADDR_CMP : integer range 0 to 1 := 0
	);
	port (
		-- SPI
		 i_spi_clk	: in	std_logic;
		 i_spi_clkEn	: in	std_logic; 
		ni_spi_cs	: in	std_logic;
		 i_spi_d	: in	std_logic;
		 o_spi_d	: out	std_logic;
		 o_data_en	: out	std_logic;
		 i_type		: in	std_logic_vector(0 downto 0) := (others => '0');
		 i_Addr		: in	std_logic_vector(2 downto 0) := (others => '0');
		
		 o_BRAM_Clk	: out  std_logic;
		 o_BRAM_En	: out  std_logic;
		 o_BRAM_WEN	: out  std_logic_vector( 1 downto 0);
		 o_BRAM_Addr	: out  std_logic_vector(15 downto 0);
		 o_BRAM_D	: out  std_logic_vector(15 downto 0);
		 i_BRAM_D	: in   std_logic_vector(15 downto 0) := (others => '0')
	);
end safty_spi;

architecture impl of safty_spi is
--------------------------------------------------------------------------------
	signal data_out	: std_logic_vector(16 downto 0);
	signal cnt		: std_logic_vector(3 downto 0) := (others => L);
	signal addr_ready : std_logic := L;
	signal wr_en : std_logic := L;
	signal addr_cmp : std_logic := L;
	
	signal bram_rdata	: std_logic_vector(15 downto 0);
	signal bram_wdata	: std_logic_vector(15 downto 0);
	
	signal bram_addr	: std_logic_vector(15 downto 0);
	signal bram_addr_r	: std_logic_vector(15 downto 0) := x"1234";
	signal bram_wen	: std_logic_vector(1 downto 0) := (others => 'U');
	signal bram_addr_inc	: std_logic_vector(15 downto 0);
	
----------------------------------------------------------------------------------

begin
	spi_sequ: process(i_spi_clk,ni_spi_cs) begin
		if ni_spi_cs=H then
			cnt <= (others => L);
			addr_ready <= L;
			addr_cmp <= L;
			wr_en <= L;
		elsif rising_edge(i_spi_clk) then
			if i_spi_clkEn=H then
				data_out <= data_out(data_out'high-1 downto 0) & i_spi_d;
				cnt <= cnt+1;
				
				if cnt=14 then
					if addr_ready=L then
						bram_addr_r <= L & data_out(data_out'high-3 downto 0) & i_spi_d;
					end if;
				end if;
				if cnt=15 then
					cnt <= (others => L);
					if addr_ready=L then
						addr_ready <= H;
						-- type 0
						if (NO_ADDR_CMP=1)
						   or (i_type="0" and (bram_addr_r(14 downto 11) = i_type&i_addr))
						   or (i_type="1" and (bram_addr_r(14) = i_type(0))) then
							wr_en <= i_spi_d;
							addr_cmp <= H;
						else
							addr_cmp <= L;
						end if;
					else
						bram_addr_r <= bram_addr_inc;
					end if;
					data_out(16 downto 1) <= bram_rdata;
				end if;
			end if;
		end if;
	end process;
	
	bram_addr_inc <= bram_addr_r+1;
	
	process(cnt,addr_ready,wr_en,data_out,i_spi_d,bram_addr_r,bram_addr_inc,addr_cmp) begin
		bram_wdata <= data_out(data_out'high-2 downto 0) & i_spi_d;
		bram_wen <= (others => L);
		if cnt=14 and addr_ready=L then
			bram_addr <= ("00" & data_out(data_out'high-4 downto 0) & i_spi_d) or RD_ADDR_OR;
		elsif cnt=15 and addr_ready=H and wr_en=H and addr_cmp=H then
			bram_addr <= (bram_addr_r) or WR_ADDR_OR;
			bram_wen <= (others => H);
		else
			bram_addr <= (bram_addr_inc) or RD_ADDR_OR;
		end if;
	end process;
	
	o_spi_d <= data_out(data_out'high);-- after 1 ns when addr_cmp=H else Z after 1 ns;
	o_data_en <= addr_cmp;

	o_BRAM_Clk	<= i_spi_clk;
	o_BRAM_En	<= i_spi_clkEn;
	o_BRAM_WEN	<= bram_wen;
	o_BRAM_Addr	<= bram_addr;
	bram_rdata	<= i_BRAM_D;
	o_BRAM_D	<= bram_wdata;



--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
