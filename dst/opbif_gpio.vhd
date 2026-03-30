--------------------------------------------------------------------------------
--  opbif_gpio
--------------------------------------------------------------------------------
--
--  project     : ppc-card, imp2, sac2
--  programmer  : C. Leuthold, INDEL AG
--  date        : 18.12.2006
--  version     : 1.00
--  language    : VHDL
--  system      : ispLever 3.0
--
--  purpose
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	18.12.2004-le
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

-----------------------------------------------------------------------------
-- Entity section
-----------------------------------------------------------------------------
entity opbif_gpio is
	generic (
		C_NO_OF_GPIOS : integer := 32;
		C_DWIDTH : integer := 32;
		C_AWIDTH : integer := 32
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
		-- gpios
		i_gpio_I : in std_logic_vector(C_NO_OF_GPIOS-1 downto 0) := (others => L);
		o_gpio_O : out std_logic_vector(C_NO_OF_GPIOS-1 downto 0);
		o_gpio_T : out std_logic_vector(C_NO_OF_GPIOS-1 downto 0)
	);
end opbif_gpio;
--------------------------------------------------------------------------------
-- Architecture
--------------------------------------------------------------------------------
architecture implementation of opbif_gpio is
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	constant C_NO_OF_GPIOS_REG : integer := (C_NO_OF_GPIOS-1)/32;
	
	constant C_ADDR : integer := pkg_log2(4*C_NO_OF_GPIOS_REG);
	-- C_NO_OF_GPIOS_REG = 64
	-- 0x00		gpio(0..31) inputs
	-- 0x04		gpio(32..63) inputs
	-- 0x08		gpio(0..31) inputs
	-- 0x0c		gpio(32..63) inputs
	-- 0x10		gpio(0..31) outputs
	-- 0x14		gpio(32..63) outputs
	-- 0x18		gpio(0..31) direction, H input / L output
	-- 0x1c		gpio(32..63) direction, H input / L output
	-- .....
	constant DF_GPIO_OUT : std_logic_vector := "10";
	constant DF_GPIO_DIR : std_logic_vector := "11";
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
	signal gpio_T : std_logic_vector(C_NO_OF_GPIOS-1 downto 0) := (others => H);
	signal gpio_O : std_logic_vector(C_NO_OF_GPIOS-1 downto 0) := (others => L);
	
	
begin -- architecture ----------------------------------------------------------
	clk <= i_Clk;
	rst <= i_Rst;
	
	o_gpio_T <= gpio_T;
	o_gpio_O <= gpio_O;
	-- OPB FI PORT
	loc_addr <= i_addr;
	loc_rd_acc <= i_rd_acc;
	loc_wr_acc <= i_wr_acc;
	loc_byte_ebl <= i_byte_ebl;
	loc_wr_data <= i_wr_data;
	o_rd_data <= loc_rd_data;
	o_rd_acc_done <= loc_rd_acc_done;
	o_wr_acc_done <= loc_wr_acc_done; 
	
	loc_wr_acc_done <= H;
	---------------------------------------------------------------------------- 

	write : process (rst, clk)
	begin
		if rst=H then 
			gpio_T <= (others => H);
			gpio_O <= (others => L);
		elsif rising_edge(clk) then
			if loc_wr_acc=H then -- write
				if loc_addr(C_ADDR+1 downto C_ADDR)=DF_GPIO_OUT then 
					for j in 0 to C_NO_OF_GPIOS_REG
					loop
						if loc_addr(C_ADDR-1 downto 2)=j then
							if j=C_NO_OF_GPIOS_REG then
								for i in 0 to C_NO_OF_GPIOS-j*32-1
								loop
									if i<8 and loc_byte_ebl(0) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>7 and i<16 and loc_byte_ebl(1) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>15 and i<24 and loc_byte_ebl(2) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>23 and i<32 and loc_byte_ebl(3) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
								end loop;
							else
								for i in 0 to 31
								loop
									if i<8 and loc_byte_ebl(0) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>7 and i<16 and loc_byte_ebl(1) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>15 and i<24 and loc_byte_ebl(2) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>23 and i<32 and loc_byte_ebl(3) = H then
										gpio_O(32*j+31-i) <= loc_wr_data(i);
									end if;
								end loop;
							end if;
						end if;
					end loop;
				elsif loc_addr(C_ADDR+1 downto C_ADDR)=DF_GPIO_DIR then 
					for j in 0 to C_NO_OF_GPIOS_REG
					loop
						if loc_addr(C_ADDR-1 downto 2)=j then 
							if j=C_NO_OF_GPIOS_REG then
								for i in 0 to C_NO_OF_GPIOS-j*32-1
								loop
									if i<8 and loc_byte_ebl(0) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>7 and i<16 and loc_byte_ebl(1) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>15 and i<24 and loc_byte_ebl(2) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>23 and i<32 and loc_byte_ebl(3) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
								end loop;
							else
								for i in 0 to 31
								loop
									if i<8 and loc_byte_ebl(0) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>7 and i<16 and loc_byte_ebl(1) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>15 and i<24 and loc_byte_ebl(2) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
									if i>23 and i<32 and loc_byte_ebl(3) = H then
										gpio_T(32*j+31-i) <= loc_wr_data(i);
									end if;
								end loop;
							end if;
						end if;
					end loop;
				end if; -- end of addr decod 
			end if;
			if loc_rd_acc=H and loc_rd_acc_done=L then  -- read
				loc_rd_acc_done <= H;
			else
				loc_rd_acc_done <= L;
			end if;
		end if;
	end process;

	read : process(loc_rd_acc, loc_addr, i_gpio_I)
	begin
		-- default value: always = 0
		loc_rd_data <= (others => '0');
		if loc_rd_acc=H then    -- read
			if loc_addr(C_ADDR+1 downto C_ADDR)=DF_GPIO_OUT then
				for j in 0 to C_NO_OF_GPIOS_REG
				loop
					if loc_addr(C_ADDR-1 downto 2)=j then
						if j=C_NO_OF_GPIOS_REG then
							for i in 0 to C_NO_OF_GPIOS-j*32-1 loop
								loc_rd_data(i) <= gpio_O(32*j+31-i);
							end loop;
						else
							for i in 0 to 31 loop
								loc_rd_data(i) <= gpio_O(32*j+31-i);
							end loop;
						end if;
					end if;
				end loop;
			elsif loc_addr(C_ADDR+1 downto C_ADDR)=DF_GPIO_DIR then
				for j in 0 to C_NO_OF_GPIOS_REG
				loop
					if loc_addr(C_ADDR-1 downto 2)=j then
						if j=C_NO_OF_GPIOS_REG then
							for i in 0 to C_NO_OF_GPIOS-j*32-1 loop
								loc_rd_data(i) <= gpio_T(32*j+31-i);
							end loop;
						else
							for i in 0 to 31 loop
								loc_rd_data(i) <= gpio_T(32*j+31-i);
							end loop;
						end if;
					end if;
				end loop;
			else
				for j in 0 to C_NO_OF_GPIOS_REG
				loop
					if loc_addr(C_ADDR-1 downto 2)=j then
						if j=C_NO_OF_GPIOS_REG then
							for i in 0 to C_NO_OF_GPIOS-j*32-1 loop
								loc_rd_data(i) <= i_gpio_I(32*j+31-i);
							end loop;
						else
							for i in 0 to 31 loop
								loc_rd_data(i) <= i_gpio_I(32*j+31-i);
							end loop;
						end if;
					end if;
				end loop;
			end if;   -- end of addr decod
		end if;
	end process;
end implementation;