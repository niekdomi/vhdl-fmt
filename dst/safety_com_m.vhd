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
--	04.02.2014-le :	- add bram enable pin 
--	02.05.2014-le : - add status input and expand status to 32 bits
--	05.06.2014-le : - to copram, do not or write address
--	27.08.2014-le : - change protocol to get a bigger address space for copram
--	08.01.2015-le : - size of copram is now configurable
--	08.01.2015-le : - add clock enables
--	14.02.2018-le : - add dummy BRAM_Init for BRAM_NkByte_A16_B16
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

entity safety_com_m is
generic (
	C_COPRAM_NO_OF_KBYTE	: integer range 1 to 32 := 8
);
port (
	ni_mSPI_CS : in std_logic;
	i_mSPI_CLK : in std_logic;
	i_mSPI_D : in std_logic;
	o_mSPI_Q : out std_logic;
	i_mSPI_ClkEn : in	std_logic;
	no_sSPI_CS : out std_logic;
	o_sSPI_CLK : out std_logic;
	o_sSPI_D : out std_logic;
	i_sSPI_Q : in std_logic;
	o_sf_status : out std_logic_vector(31 downto 0);
	i_sf_status : in std_logic_vector(31 downto 0) := (others => L);
	i_cop_BRAM_Clk : in std_logic := L;
	i_cop_BRAM_en : in std_logic := H;
	i_cop_BRAM_WEN : in std_logic_vector(1 downto 0) := (others => L);
	i_cop_BRAM_Addr : in std_logic_vector(15 downto 0) := (others => L);
	o_cop_BRAM_r2c : out std_logic_vector(15 downto 0);
	i_cop_BRAM_c2r : in std_logic_vector(15 downto 0) := (others => L)
);
end safety_com_m;

architecture behavior of safety_com_m is 
	
	signal msf_BRAM_Clk : std_logic;
	signal msf_BRAM_EN : std_logic;
	signal msf_BRAM_WEN : std_logic_vector(1 downto 0);
	signal msf_BRAM_Addr : std_logic_vector(15 downto 0);
	signal msf_BRAM_s2r : std_logic_vector(15 downto 0);
	signal msf_BRAM_r2s : std_logic_vector(15 downto 0);
	signal msf_WEN : std_logic_vector(1 downto 0);
	
	signal msf_dataen : std_logic;
	signal mSPI_Q : std_logic;
	
	signal msf_Stat_r2s : std_logic_vector(31 downto 0) := (others => L);
	signal msf_Stat_r2smux : std_logic_vector(15 downto 0) := (others => L);
	signal msf_BRAMStat_r2s : std_logic_vector(15 downto 0);
	
	constant BRAM_Init : tSLV_Nx16(0 to 512*C_COPRAM_NO_OF_KBYTE-1) := (others => (others => L));
	
begin
	
	o_sSPI_clk <= i_mSPI_clk;
	no_sSPI_cs <= ni_mSPI_cs;
	o_sSPI_D <= i_mSPI_D;
	o_mSPI_Q <= mSPI_Q when msf_dataen=H else i_sSPI_Q;
	
	-- to copram, do not or write address
	msf : entity safty_spi.safty_spi
	generic map (
		WR_ADDR_OR	=> x"0000",
		RD_ADDR_OR	=> x"0000"
	)
	port map (
		-- SPI
		 i_spi_clk	=> i_mSPI_clk,
		 i_spi_clkEn	=> i_mSPI_ClkEn,
		ni_spi_cs	=> ni_mSPI_cs,
		 i_spi_d	=> i_mSPI_D,
		 o_spi_d	=> mSPI_Q,
		 o_data_en	=> msf_dataen,
		 i_Addr		=> "000",
		 i_type		=> "1",
		 o_BRAM_Clk	=> msf_BRAM_Clk,
		 o_BRAM_EN	=> msf_BRAM_EN,
		 o_BRAM_WEN	=> msf_WEN,
		 o_BRAM_Addr=> msf_BRAM_Addr,
		 o_BRAM_D	=> msf_BRAM_s2r,
		 i_BRAM_D	=> msf_BRAMStat_r2s
	);
	
	msf_BRAM_WEN <= msf_WEN when msf_BRAM_Addr(DF_STATUS_RAM_MUX)=L else (others =>L);
	msf_BRAMStat_r2s <= msf_BRAM_r2s when msf_BRAM_Addr(DF_STATUS_RAM_MUX)=L else msf_Stat_r2smux;

	process(msf_BRAM_Clk)
	begin
		if rising_edge(msf_BRAM_Clk) then
			if msf_BRAM_EN=H then
				if (msf_BRAM_Addr(DF_STATUS_RAM_MUX)=H and msf_WEN/=0) then
					if (msf_BRAM_Addr(0)=L) then
						o_sf_status(31 downto 16) <= msf_BRAM_s2r;
					else
						o_sf_status(15 downto 0) <= msf_BRAM_s2r;
					end if;
				end if;
				-- save
				if (msf_dataen=L) then
					msf_Stat_r2s <= i_sf_status;
				end if;
				-- mux
				if (msf_BRAM_Addr(0)=L) then
					msf_Stat_r2smux <= msf_Stat_r2s(31 downto 16);
				else
					msf_Stat_r2smux <= msf_Stat_r2s(15 downto 0);
				end if;
			end if;
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
		i_BRAM_EN_A		=> i_cop_BRAM_en,
		i_BRAM_WEN_A	=> i_cop_BRAM_WEN,
		i_BRAM_Addr_A	=> i_cop_BRAM_Addr(pkg_log2(512*C_COPRAM_NO_OF_KBYTE)-1 downto 0),
		o_BRAM_Din_A	=> o_cop_BRAM_r2c,
		i_BRAM_Dout_A	=> i_cop_BRAM_c2r,
		i_BRAM_Clk_B	=> msf_BRAM_Clk,
		i_BRAM_EN_B		=> msf_BRAM_EN,
		i_BRAM_WEN_B	=> msf_BRAM_WEN,
		i_BRAM_Addr_B	=> msf_BRAM_Addr(pkg_log2(512*C_COPRAM_NO_OF_KBYTE)-1 downto 0),
		o_BRAM_Din_B	=> msf_BRAM_r2s,
		i_BRAM_Dout_B	=> msf_BRAM_s2r
	);
	
end;


