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
--	26.09.2013-le : start
--	02.05.2014-le : - add status input and expand status to 32 bits	
--	05.06.2014-le : - to copram, do not or write address
--	27.08.2014-le : - change protocol to get a bigger address space for copram
--	23.09.2014-le : - size of copram is now configurable
--	17.11.2014-le : - remove dbg int of inst_Ram_t1 
--	10.12.2014-le : - change data enables, add o_msf_data_en
--	08.01.2015-le : - add clock enables
--	29.06.2015-le : - use a synchronous clock for ctrl<->monito communicatin (safty_spi_scs)
--	26.02.2016-le : - temporary remove the safty_spi_scs
--	20.04.2016-le : - undo remove the safty_spi_scs
--------------------------------------------------------------------------------
--$Rev:: 2777                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-03-15 09:11:47 +0100 (Fr, 15 Mrz 2013)                          $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;
library BRAM;
use BRAM.all;
library safty_spi;
use safty_spi.all;
use safty_spi.safty_spi_pkg.all;

entity safety_com_s is
generic (
	C_COPRAM_NO_OF_KBYTE	: integer range 1 to 32 := 8
);
port (
	-- COP-res SPI Pins
	 i_msf_spi_clk	: in	std_logic;
	ni_msf_spi_cs	: in	std_logic;
	 i_msf_spi_mosi	: in	std_logic;
	 o_msf_spi_miso	: out	std_logic;
	 o_msf_data_en	: out	std_logic;
	-- Safety SPI Pins
	 i_sf_spi_clk	: in	std_logic := L;
	ni_sf_spi_cs	: in	std_logic := L;
	 i_sf_spi_mosi	: in	std_logic := L;
	 o_sf_spi_miso	: out	std_logic;
	 o_sf_data_en	: out	std_logic;
	 
	 i_msf_ClkEn	: in	std_logic;
	 i_sf_ClkEn		: in	std_logic;
	 
	 i_AddrSw : in std_logic_vector(2 downto 0) := (others => L);
	o_sf_status : out std_logic_vector(31 downto 0);
	i_sf_status : in std_logic_vector(31 downto 0) := (others => L);
	i_cop_BRAM_Clk : in std_logic := L;
	i_cop_BRAM_WEN : in std_logic_vector(1 downto 0) := (others => L);
	i_cop_BRAM_Addr : in std_logic_vector(15 downto 0) := (others => L);
	o_cop_BRAM_r2c : out std_logic_vector(15 downto 0);
	i_cop_BRAM_c2r : in std_logic_vector(15 downto 0) := (others => L)
);
end safety_com_s;

architecture behavior of safety_com_s is 
	signal msf_BRAM_Clk : std_logic;
	signal msf_BRAM_WEN : std_logic_vector(1 downto 0);
	signal msf_BRAM_EN : std_logic;
	signal msf_BRAM_Addr : std_logic_vector(15 downto 0);
	signal msf_BRAM_s2r : std_logic_vector(15 downto 0);
	signal msf_BRAM_r2s : std_logic_vector(15 downto 0);
	signal ssf0_BRAM_Clk : std_logic;
	signal ssf0_BRAM_EN : std_logic;
	signal ssf0_BRAM_WEN : std_logic_vector(1 downto 0);
	signal ssf0_BRAM_Addr : std_logic_vector(15 downto 0);
	signal ssf0_BRAM_s2r : std_logic_vector(15 downto 0);
	signal ssf0_BRAM_r2s : std_logic_vector(15 downto 0);
	signal ssf1_BRAM_Clk : std_logic;
	signal ssf1_BRAM_EN : std_logic;
	signal ssf1_BRAM_WEN : std_logic_vector(1 downto 0);
	signal ssf1_BRAM_Addr : std_logic_vector(15 downto 0);
	signal ssf1_BRAM_s2r : std_logic_vector(15 downto 0);
	signal ssf1_BRAM_r2s : std_logic_vector(15 downto 0);
	signal ssf1_WEN : std_logic_vector(1 downto 0);
	signal ssf1_Stat_r2s : std_logic_vector(31 downto 0) := (others => L);
	signal ssf1_Stat_r2smux : std_logic_vector(15 downto 0) := (others => L);
	signal ssf1_BRAMStat_r2s : std_logic_vector(15 downto 0);
	signal ssf1_dataen : std_logic;
	signal ssf0_dataen : std_logic;
	
	signal sf_spi_miso0 : std_logic;
	signal ssf10_dataen : std_logic;
	signal sf_spi_miso1 : std_logic;
	signal ssf11_dataen : std_logic;
	
	constant BRAM_Init		: tSLV_Nx16(0 to 512*C_COPRAM_NO_OF_KBYTE-1) := (	-- GinSlave and COP_Master
				--0 => x"0001",
				--1 => x"0203",
				--2 => x"0405",
				--3 => x"0607",
				--4 => x"0809",
				--5 => x"0a0b",
				--6 => x"0c0d",
				--7 => x"0e0f",
				--4094 => x"AAAA",
				--4095 => x"5555",
				others 	=> (others => '0')
				);
	
	constant BRAM_Init_1k		: tSLV_Nx16(0 to 512*1-1) := (	-- GinSlave and COP_Master
				others 	=> (others => '0')
				);
	
begin

	-- from master, swap read and write aera


	msf : entity safty_spi.safty_spi_scs
	port map (
		-- SPI
		 i_spi_clk	=> i_msf_spi_clk,
		 i_spi_clkEn	=> i_msf_ClkEn,
		ni_spi_cs	=> ni_msf_spi_cs,
		 i_spi_d	=> i_msf_spi_mosi,
		 o_spi_d	=> o_msf_spi_miso,
		 o_data_en	=> ssf0_dataen,
		 i_Addr		=> i_AddrSw,
		 i_type		=> "0",
		 o_BRAM_Clk	=> msf_BRAM_Clk,
		 o_BRAM_EN	=> msf_BRAM_EN,
		 o_BRAM_WEN	=> msf_BRAM_WEN,
		 o_BRAM_Addr=> msf_BRAM_Addr,
		 o_BRAM_D	=> msf_BRAM_s2r,
		 i_BRAM_D	=> msf_BRAM_r2s
	);
	
	ssf_t0 : entity safty_spi.safty_spi
	port map (
		-- SPI
		 i_spi_clk	=> i_sf_spi_clk,
		 i_spi_clkEn	=> i_sf_ClkEn,
		ni_spi_cs	=> ni_sf_spi_cs,
		 i_spi_d	=> i_sf_spi_mosi,
		 o_spi_d	=> sf_spi_miso0,
		 o_data_en	=> ssf10_dataen,
		 i_Addr		=> "000",
		 i_type		=> "0",
		 o_BRAM_Clk	=> ssf0_BRAM_Clk,
		 o_BRAM_EN	=> ssf0_BRAM_EN,
		 o_BRAM_WEN	=> ssf0_BRAM_WEN,
		 o_BRAM_Addr=> ssf0_BRAM_Addr,
		 o_BRAM_D	=> ssf0_BRAM_s2r,
		 i_BRAM_D	=> ssf0_BRAM_r2s
	);
	
	-- to copram, do not or write address
	ssf_t1 : entity safty_spi.safty_spi
	generic map (
		WR_ADDR_OR	=> x"0000",
		RD_ADDR_OR	=> x"0000"
	)
	port map (
		-- SPI
		 i_spi_clk	=> i_sf_spi_clk,
		 i_spi_clkEn	=> i_sf_ClkEn,
		ni_spi_cs	=> ni_sf_spi_cs,
		 i_spi_d	=> i_sf_spi_mosi,
		 o_spi_d	=> sf_spi_miso1,
		 o_data_en	=> ssf11_dataen,
		 i_type		=> "1",
		 o_BRAM_Clk	=> ssf1_BRAM_Clk,
		 o_BRAM_EN	=> ssf1_BRAM_EN,
		 o_BRAM_WEN	=> ssf1_WEN,
		 o_BRAM_Addr=> ssf1_BRAM_Addr,
		 o_BRAM_D	=> ssf1_BRAM_s2r,
		 i_BRAM_D	=> ssf1_BRAMStat_r2s
	);
	
	inst_Ram_t0 : entity BRAM.BRAM_NkByte_A16_B16
	generic map (
		C_NO_OF_KBYTE => 1,
		BRAM_Init => BRAM_Init_1k
	)
	port map (
		-- A-side read/write
		i_BRAM_Clk_A	=> msf_BRAM_Clk,
		i_BRAM_EN_A		=> msf_BRAM_EN,
		i_BRAM_WEN_A	=> msf_BRAM_WEN,
		i_BRAM_Addr_A	=> msf_BRAM_Addr(8 downto 0),
		o_BRAM_Din_A	=> msf_BRAM_r2s,
		i_BRAM_Dout_A	=> msf_BRAM_s2r,
		i_BRAM_Clk_B	=> ssf0_BRAM_Clk,
		i_BRAM_EN_B		=> ssf0_BRAM_EN,
		i_BRAM_WEN_B	=> ssf0_BRAM_WEN,
		i_BRAM_Addr_B	=> ssf0_BRAM_Addr(8 downto 0),
		o_BRAM_Din_B	=> ssf0_BRAM_r2s,
		i_BRAM_Dout_B	=> ssf0_BRAM_s2r
	);
	
	ssf1_BRAM_WEN <= ssf1_WEN when ssf1_BRAM_Addr(DF_STATUS_RAM_MUX)=L else (others =>L);
	ssf1_BRAMStat_r2s <= ssf1_BRAM_r2s when ssf1_BRAM_Addr(DF_STATUS_RAM_MUX)=L else ssf1_Stat_r2smux;
	
	process(ssf1_BRAM_Clk)
	begin
		if rising_edge(ssf1_BRAM_Clk) then
			if (ssf1_BRAM_EN=H) then
				if (ssf1_BRAM_Addr(DF_STATUS_RAM_MUX)=H and ssf1_WEN/=0) then
					if (ssf1_BRAM_Addr(0)=L) then
						o_sf_status(31 downto 16) <= ssf1_BRAM_s2r;
					else
						o_sf_status(15 downto 0) <= ssf1_BRAM_s2r;
					end if;
				end if;
				-- save
				if (ssf11_dataen=L) then
					ssf1_Stat_r2s <= i_sf_status;
				end if;
				-- mux
				if (ssf1_BRAM_Addr(0)=L) then
					ssf1_Stat_r2smux <= ssf1_Stat_r2s(31 downto 16);
				else
					ssf1_Stat_r2smux <= ssf1_Stat_r2s(15 downto 0);
				end if;
			end if;
		end if;
	end process;
	
	o_msf_data_en <= ssf0_dataen;
	o_sf_data_en	<= ssf11_dataen or ssf10_dataen;
	
	process(sf_spi_miso0,ssf10_dataen,sf_spi_miso1,ssf11_dataen)
	begin
		if ssf10_dataen=H then
			o_sf_spi_miso <= sf_spi_miso0;
		elsif ssf11_dataen=H then
			o_sf_spi_miso <= sf_spi_miso1;
		else
			o_sf_spi_miso <= H;
		end if;
	end process;
	
	inst_Ram_t1 : entity BRAM.BRAM_NkByte_A16_B16
	generic map (
		C_NO_OF_KBYTE => C_COPRAM_NO_OF_KBYTE,
		BRAM_Init => BRAM_Init
	)
	port map (
		-- A-side read/write
		i_BRAM_Clk_A	=> i_cop_BRAM_Clk,
		i_BRAM_WEN_A	=> i_cop_BRAM_WEN,
		i_BRAM_Addr_A	=> i_cop_BRAM_Addr(pkg_log2(512*C_COPRAM_NO_OF_KBYTE)-1 downto 0),
		o_BRAM_Din_A	=> o_cop_BRAM_r2c,
		i_BRAM_Dout_A	=> i_cop_BRAM_c2r,
		i_BRAM_Clk_B	=> ssf1_BRAM_Clk,
		i_BRAM_EN_B		=> ssf1_BRAM_EN,
		i_BRAM_WEN_B	=> ssf1_BRAM_WEN,
		i_BRAM_Addr_B	=> ssf1_BRAM_Addr(pkg_log2(512*C_COPRAM_NO_OF_KBYTE)-1 downto 0),
		o_BRAM_Din_B	=> ssf1_BRAM_r2s,
		i_BRAM_Dout_B	=> ssf1_BRAM_s2r
	);

end;
