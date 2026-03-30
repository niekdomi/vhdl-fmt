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
--	29.06.2015-le : - use a synchronous clock for ctrl<->monito communication
--						address is not longer a part of the protocol, writeaddr 
--						is fix 0 and readaddr is 0x200. write to 0x200 is still
--						supported to read the written data(e.g. for testing).
--						 
--------------------------------------------------------------------------------
--$Rev:: 3707                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2015-01-08 16:38:32 +0100 (Do, 08 Jan 2015)                          $
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

entity safty_spi_scs is
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
end safty_spi_scs;

architecture impl of safty_spi_scs is
--------------------------------------------------------------------------------
	
	constant WR_ADDR_OR	: std_logic_vector(15 downto 0) := x"0000";
	constant RD_ADDR_OR	: std_logic_vector(15 downto 0) := x"0100";


	signal data_in	: std_logic_vector(16 downto 0);
	signal data_out	: std_logic_vector(15 downto 0);
	
	signal cnt		: std_logic_vector(3 downto 0) := (others => L);
	signal addr_ready : std_logic := L;
	signal wr_en : std_logic := L;
	signal addr_cmp : std_logic := L;
	
	signal bram_rdata	: std_logic_vector(15 downto 0);
	signal bram_wdata	: std_logic_vector(15 downto 0);
	
	signal bram_addr	: std_logic_vector(15 downto 0);
	signal bram_addr_wr	: std_logic_vector(15 downto 0) := x"1234";
	
	signal bram_wen	: std_logic_vector(1 downto 0) := (others => 'U');
	signal bram_addr_rd	: std_logic_vector(15 downto 0);
	
----------------------------------------------------------------------------------

begin
	spi_sequ: process(i_spi_clk) begin

		if rising_edge(i_spi_clk) then
			if ni_spi_cs=H then
				cnt <= (others => L);
				addr_ready <= L;
				addr_cmp <= L;
				wr_en <= L;
				bram_addr_rd <= (others => L);
				bram_addr_wr <= (others => L);
			elsif i_spi_clkEn=H then
				data_in <= data_in(data_in'high-1 downto 0) & i_spi_d;
				data_out <= data_out(data_out'high-1 downto 0) & L;
				cnt <= cnt+1;
				
				if cnt=7 then
					data_out <= bram_rdata;
					if addr_ready=L then
						if ((i_type="0" and (data_in(6 downto 3) = i_type&i_addr))
							   or (i_type="1" and (data_in(6) = i_type(0)))) then
							addr_cmp <= H;
						else
							addr_cmp <= L;
						end if;
					end if;
					bram_addr_rd <= bram_addr_rd+1;
				end if;
				
				if cnt=(6) then
					if addr_ready=L then
						 -- same address for read and write (bram_addr_wr=RD_ADDR_OR)
						bram_addr_wr(8) <= i_spi_d;
					end if;
				end if;
				
				if cnt=15 then
					cnt <= (others => L);
					if addr_ready=L then
						addr_ready <= H;
						if (addr_cmp=H) then
							wr_en <= i_spi_d;
						end if;
					else
						bram_addr_wr <= bram_addr_wr+1;
					end if;
					
				end if;
			end if;
		end if;
	end process;
	
	process(cnt,addr_ready,wr_en,data_in,i_spi_d,bram_addr_wr,bram_addr_rd,addr_cmp) begin
		bram_wdata <= data_in(data_in'high-2 downto 0) & i_spi_d;
		bram_wen <= (others => L);

		if cnt=15 and addr_ready=H and wr_en=H and addr_cmp=H then
			bram_addr <= (bram_addr_wr) or WR_ADDR_OR;
			bram_wen <= (others => H);
		else
			bram_addr <= (bram_addr_rd) or RD_ADDR_OR;
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
