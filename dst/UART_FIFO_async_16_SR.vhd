--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------
--	Filename:	fifo_async16_sr.vhd
--
--			
--	Description:
--		an Asynchronous FIFO 
--              
--	Copyright (c) 2006 by George Huber 
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 								 
--
--	Revision	History:
--	Revision	Date      	Author   	Comment
--	--------	----------	---------	-----------
--	1.0     	12/17/06  	h lefevre	Initial revision
--	
--------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

ENTITY UART_FIFO_async_16_SR IS
	GENERIC (data_width: integer := 8); -- size of data bus
	PORT   (					
			clk_WR : IN  std_logic; -- write clock
			clk_RD : IN  std_logic; -- read clock
			rst    : IN  std_logic; -- resets counters
			srst   : IN  std_logic:= '0'; -- resets counters (sync with clk_WR)
			WR     : IN  std_logic; -- write control 
			RD     : IN  std_logic; -- read control
			D      : IN  std_logic_vector(data_width-1 DOWNTO 0);
			Q      : OUT std_logic_vector(data_width-1 DOWNTO 0);
			empty  : OUT std_logic; 
			full   : OUT std_logic);
END ENTITY UART_FIFO_async_16_SR;

ARCHITECTURE a OF UART_FIFO_async_16_SR IS

	type ram_mem_type is ARRAY (15 downto 0) 
	        of std_logic_vector (data_width-1 DOWNTO 0);
	SIGNAL ram_mem     : ram_mem_type; 
	SIGNAL iempty      : std_logic;
	SIGNAL ifull       : std_logic;
	SIGNAL add_WR_CE   : std_logic;
	SIGNAL add_WR      : std_logic_vector(4 DOWNTO 0); -- 4 bits are used to address MEM
	SIGNAL add_WR_GC   : std_logic_vector(4 DOWNTO 0); -- 5 bits are used to compare
	SIGNAL n_add_WR    : std_logic_vector(4 DOWNTO 0); --   for empty, full flags
	SIGNAL add_WR_RS   : std_logic_vector(4 DOWNTO 0); -- synced to read clk
	SIGNAL add_RD_CE   : std_logic;
	SIGNAL add_RD      : std_logic_vector(4 DOWNTO 0);
	SIGNAL add_RD_GC   : std_logic_vector(4 DOWNTO 0);
	SIGNAL add_RD_GCwc : std_logic_vector(4 DOWNTO 0);
	SIGNAL n_add_RD    : std_logic_vector(4 DOWNTO 0);
	SIGNAL add_RD_WS   : std_logic_vector(4 DOWNTO 0); -- synced to write clk
	SIGNAL srst_w      : std_logic;
	SIGNAL isrst_w     : std_logic;
	SIGNAL srst_r      : std_logic;
	SIGNAL isrst_r     : std_logic;

BEGIN

--------------------------------------------
------- memory -----------------------------
--------------------------------------------

PROCESS(clk_WR)
BEGIN			  
	IF (rising_edge(clk_WR)) THEN
		IF ((WR = '1') AND (ifull = '0')) THEN
			ram_mem(CONV_INTEGER(add_WR(3 downto 0))) <= D;
		END IF;
	END IF;		
END PROCESS;

Q <= ram_mem(CONV_INTEGER(add_RD(3 DOWNTO 0)));

-----------------------------------------
----- Write address counter -------------
-----------------------------------------

add_WR_CE <= '0' WHEN (ifull = '1') ELSE '0' WHEN (WR = '0') ELSE '1';

n_add_WR <= add_WR + x"1";
				 
PROCESS(clk_WR,rst)
BEGIN 
	IF (rst = '1') THEN
		add_WR <= (OTHERS => '0');
		add_RD_WS <= "11000"; 
		add_WR_GC <= (OTHERS => '0');
	ELSIF (rising_edge(clk_WR)) THEN
		add_RD_WS <= add_RD_GCwc;
		IF (srst_w = '1') THEN
			add_WR <= (OTHERS => '0');
			add_WR_GC <= (OTHERS => '0');
		ELSIF (add_WR_CE = '1') THEN
			add_WR <= n_add_WR;
			add_WR_GC(0) <= n_add_WR(0) XOR n_add_WR(1);
			add_WR_GC(1) <= n_add_WR(1) XOR n_add_WR(2);
			add_WR_GC(2) <= n_add_WR(2) XOR n_add_WR(3);
			add_WR_GC(3) <= n_add_WR(3) XOR n_add_WR(4);
			add_WR_GC(4) <= n_add_WR(4);
		ELSE
			add_WR <= add_WR;
			add_WR_GC <= add_WR_GC;
		END IF;
	END IF;
END PROCESS;
				 
	full <= ifull;

	ifull <= '0' WHEN (iempty = '1') ELSE -- just in case add_RD_WS is reset to "00000"
	         '0' WHEN (add_RD_WS /= add_WR_GC) ELSE ---- instend of "11000"
	         '1';
			 
-----------------------------------------
----- Read address counter --------------
-----------------------------------------


add_RD_CE <= '0' WHEN (iempty = '1') ELSE '0' WHEN (RD = '0') ELSE '1';
				 
n_add_RD <= add_RD + x"1";
				 
PROCESS(clk_RD,rst)
BEGIN 
	IF (rst = '1') THEN
		add_RD <= (OTHERS => '0');	
		add_WR_RS <= (OTHERS => '0');
		add_RD_GC <= (OTHERS => '0');
		add_RD_GCwc <= "11000";
	ELSIF (rising_edge(clk_RD)) THEN
		add_WR_RS <= add_WR_GC;
		IF (srst_r = '1') THEN
			add_RD <= (OTHERS => '0');
			add_RD_GC <= (OTHERS => '0');
			add_RD_GCwc <= "11000";
		ELSIF (add_RD_CE = '1') THEN
			add_RD <= n_add_RD;
			add_RD_GC(0) <= n_add_RD(0) XOR n_add_RD(1);
			add_RD_GC(1) <= n_add_RD(1) XOR n_add_RD(2);
			add_RD_GC(2) <= n_add_RD(2) XOR n_add_RD(3);
			add_RD_GC(3) <= n_add_RD(3) XOR n_add_RD(4);
			add_RD_GC(4) <= n_add_RD(4);
			add_RD_GCwc(0) <= n_add_RD(0) XOR n_add_RD(1);
			add_RD_GCwc(1) <= n_add_RD(1) XOR n_add_RD(2);
			add_RD_GCwc(2) <= n_add_RD(2) XOR n_add_RD(3);
			add_RD_GCwc(3) <= n_add_RD(3) XOR (NOT n_add_RD(4));
			add_RD_GCwc(4) <= (NOT n_add_RD(4));
		ELSE
			add_RD <= add_RD; 
			add_RD_GC <= add_RD_GC;
			add_RD_GCwc <= add_RD_GCwc;
		END IF;
	END IF;
END PROCESS;

empty <= iempty;
 
iempty <= '1' WHEN (add_WR_RS = add_RD_GC) ELSE '0';

----------------------------------
---	sync rest stuff --------------
--- srst is sync with clk_WR -----
--- srst_r is sync with clk_RD ---
----------------------------------

PROCESS(clk_WR,rst)
BEGIN 
	IF (rst = '1') THEN
		srst_w <= '0';	
		isrst_r <= '0';	
	ELSIF (rising_edge(clk_WR)) THEN
		isrst_r <= srst_r;
		IF (srst = '1') THEN
			srst_w <= '1';
		ELSIF (isrst_r = '1') THEN
			srst_w <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(clk_RD,rst)
BEGIN 
	IF (rst = '1') THEN
		srst_r <= '0';	
		isrst_w <= '0';	
	ELSIF (rising_edge(clk_RD)) THEN
		isrst_w <= srst_w;
		IF (isrst_w = '1') THEN
			srst_r <= '1';
		ELSE
			srst_r <= '0';
		END IF;
	END IF;
END PROCESS;

END ARCHITECTURE;
