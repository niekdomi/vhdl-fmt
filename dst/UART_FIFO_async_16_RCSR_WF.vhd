--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------


---------------------------------------------------------------------
--	Filename:	fifo_async16_rcsr_wf.vhd
--
--
--	Description:
--		a simple Asynchronous FIFO - uses FASM style Memory
--		16 word depth with UART level read flags
--		has "Style #2" gray code address compare
--              
--	Copyright (c) 2007 by Howard LeFevre 
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 								 
--
--	Revision	History:
--	Revision	Date      	Author   	Comment
--	--------	----------	---------	-----------
--	1.0     	01/20/07  	h lefevre	Initial revision
--	
--------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

ENTITY UART_FIFO_async_16_RCSR_WF IS
	GENERIC (data_width: integer := 8); -- size of data bus
	PORT (					
		clk_WR  : IN std_logic; -- write clock
		clk_RD  : IN std_logic; -- read clock
		rst     : IN std_logic; -- resets counters
		rc_srst : IN std_logic:='0'; -- resets counters (sync with clk_RD!!!)
		WR      : IN std_logic; -- write control 
		RD      : IN std_logic; -- read control
		D       : IN std_logic_vector (data_width-1 DOWNTO 0);
		Q       : OUT std_logic_vector (data_width-1 DOWNTO 0);
		empty   : OUT std_logic; -- sync with clk_RD!!!
		q_full  : OUT std_logic; -- sync with clk_RD!!!
		h_full  : OUT std_logic; -- sync with clk_RD!!!
		a_full  : OUT std_logic; -- sync with clk_RD!!!
		full    : OUT std_logic);
END ENTITY UART_FIFO_async_16_RCSR_WF;

ARCHITECTURE a OF UART_FIFO_async_16_RCSR_WF IS


	type ram_mem_type is array (15 downto 0) 
	        OF std_logic_vector (data_width-1 DOWNTO 0);
	SIGNAL ram_mem : ram_mem_type; 
	SIGNAL iempty        : std_logic;
	SIGNAL diempty       : std_logic;
	SIGNAL ifull         : std_logic;
	SIGNAL add_WR_CE     : std_logic;
	SIGNAL add_WR        : std_logic_vector(4 DOWNTO 0); -- add_width -1 bits are used to address MEM
	SIGNAL add_WR_GC     : std_logic_vector(4 DOWNTO 0); -- add_width bits are used to compare
	SIGNAL iadd_WR_GC    : std_logic_vector(4 DOWNTO 0);
	SIGNAL n_add_WR      : std_logic_vector(4 DOWNTO 0); --   for empty, full flags
	SIGNAL add_WR_RS     : std_logic_vector(4 DOWNTO 0); -- synced to read clk
	SIGNAL add_RD_CE     : std_logic;
	SIGNAL add_RD        : std_logic_vector(4 DOWNTO 0);
	SIGNAL add_RD_GC     : std_logic_vector(4 DOWNTO 0);
	SIGNAL iadd_RD_GC    : std_logic_vector(4 DOWNTO 0);
	SIGNAL add_RD_GCwc   : std_logic_vector(4 DOWNTO 0);
	SIGNAL iadd_RD_GCwc  : std_logic_vector(4 DOWNTO 0);
	SIGNAL iiadd_RD_GCwc : std_logic_vector(4 DOWNTO 0);
	SIGNAL n_add_RD      : std_logic_vector(4 DOWNTO 0);
	SIGNAL add_RD_WS     : std_logic_vector(4 DOWNTO 0); -- synced to write clk
	SIGNAL srst_w        : std_logic;
	SIGNAL isrst_w       : std_logic;
	SIGNAL srst_r        : std_logic;
	SIGNAL isrst_r       : std_logic;
	SIGNAL c_add_RD      : std_logic_vector(4 DOWNTO 0);
	SIGNAL c_add_WR      : std_logic_vector(4 DOWNTO 0);
	SIGNAL c_add         : std_logic_vector(4 DOWNTO 0);

BEGIN

--------------------------------------------
------- memory -----------------------------
--------------------------------------------


PROCESS(clk_WR)
BEGIN			  
	IF (rising_edge(clk_WR)) THEN
		IF ((WR = '1') AND (ifull = '0')) THEN
			ram_mem(CONV_INTEGER(add_WR(3 DOWNTO 0))) <= D;
		END IF;
	END IF;		
END PROCESS;

Q <= ram_mem(CONV_INTEGER(add_RD(3 DOWNTO 0)));

-----------------------------------------
----- Write address counter -------------
-----------------------------------------

add_WR_CE <= '0' WHEN (ifull = '1') ELSE '0' WHEN (WR = '0') ELSE '1';

n_add_WR <= add_WR + "01";


----
----
u1: PROCESS(n_add_WR) IS
BEGIN
	FOR j IN 0 TO 3 LOOP
		iadd_WR_GC(j) <= n_add_WR(j) XOR n_add_WR(j+1);
	END LOOP;
	iadd_WR_GC(4) <= n_add_WR(4);
END PROCESS;
----
----
	
PROCESS(clk_WR,rst)
BEGIN 
	IF (rst = '1') THEN
		add_WR <= (OTHERS => '0');
		add_RD_WS(4 DOWNTO 3) <= "11"; 
		add_RD_WS(2 DOWNTO 0) <= (OTHERS => '0');
		add_WR_GC <= (OTHERS => '0');
	ELSIF (rising_edge(clk_WR)) THEN
		add_RD_WS <= add_RD_GCwc;
		IF (srst_w = '1') THEN
			add_WR <= (OTHERS => '0');
			add_WR_GC <= (OTHERS => '0');
		ELSIF (add_WR_CE = '1') THEN
			add_WR <= n_add_WR;
			add_WR_GC <= iadd_WR_GC;
		ELSE
			add_WR <= add_WR;
			add_WR_GC <= add_WR_GC;
		END IF;
	END IF;
END PROCESS;
				 
full <= ifull;

ifull <= '0' WHEN (iempty = '1') ELSE -- just in case add_RD_WS is reset to all zero's
	         '0' WHEN (add_RD_WS /= add_WR_GC) ELSE ---- instend of "11 zero's" 
	         '1';

		
-----------------------------------------
----- Read address counter --------------
-----------------------------------------


add_RD_CE <= '0' WHEN (iempty = '1') ELSE '0' WHEN (RD = '0') ELSE '1';
				 
n_add_RD <= add_RD + "01";

----
----
u2: PROCESS(n_add_RD) IS
BEGIN
	FOR j IN 0 TO 3 LOOP
		iadd_RD_GC(j) <= n_add_RD(j) XOR n_add_RD(j+1);
	END LOOP;
	iadd_RD_GC(4) <= n_add_RD(4);
END PROCESS;
----
----

iiadd_RD_GCwc <= (NOT n_add_RD(4)) & n_add_RD(3 DOWNTO 0);
		
----
----
u3: PROCESS(iiadd_RD_GCwc) IS
BEGIN
	FOR j in 0 TO 3 LOOP
		iadd_RD_GCwc(j) <= iiadd_RD_GCwc(j) XOR iiadd_RD_GCwc(j+1);
	END LOOP;
	iadd_RD_GCwc(4) <= iiadd_RD_GCwc(4);
END PROCESS;
----
----
		
PROCESS(clk_RD,rst)
BEGIN 
	IF (rst = '1') THEN
		add_RD <= (OTHERS => '0');	
		add_WR_RS <= (OTHERS => '0');
		add_RD_GC <= (OTHERS => '0');
		add_RD_GCwc(4 DOWNTO 3) <= "11";
		add_RD_GCwc(2 DOWNTO 0) <= (OTHERS => '0');
		diempty <= '1';
	ELSIF (rising_edge(clk_RD)) THEN
		add_WR_RS <= add_WR_GC;
		diempty <= iempty;
		IF (srst_r = '1') THEN
			add_RD <= (OTHERS => '0');
			add_RD_GC <= (OTHERS => '0');
			add_RD_GCwc(4 DOWNTO 3) <= "11";
			add_RD_GCwc(2 DOWNTO 0) <= (OTHERS => '0');
		ELSIF (add_RD_CE = '1') THEN
			add_RD <= n_add_RD;
			add_RD_GC <= iadd_RD_GC;
			add_RD_GCwc <= iadd_RD_GCwc;
		ELSE
			add_RD <= add_RD; 
			add_RD_GC <= add_RD_GC;
			add_RD_GCwc <= add_RD_GCwc;
		END IF;
	END IF;
END PROCESS;

empty <= diempty;
 
iempty <= '1' WHEN (add_WR_RS = add_RD_GC) ELSE '0';
	
----
----
u4: PROCESS(add_RD_GC,c_add_RD) IS
BEGIN
	FOR j in 0 TO 3 LOOP
		c_add_RD(j) <= add_RD_GC(j) xor c_add_RD(j+1);
	END LOOP;
	c_add_RD(4) <= add_RD_GC(4);
END PROCESS;
----
----

----
----
u5: PROCESS(add_WR_RS,c_add_WR) IS
BEGIN
	FOR j in 0 TO 3 LOOP
		c_add_WR(j) <= add_WR_RS(j) XOR c_add_WR(j+1);
	END LOOP;
	c_add_WR(4) <= add_WR_RS(4);
END PROCESS;
----
----
		
c_add <= (c_add_WR - c_add_RD);
	
q_full <= '0' WHEN (iempty = '1') ELSE '0' WHEN (c_add(4 DOWNTO 2) = "000") ELSE '1';
	
h_full <= '0' WHEN (iempty = '1') ELSE '0' WHEN (c_add(4 DOWNTO 3) = "00") ELSE '1'; 
	
a_full <= '0' WHEN (iempty = '1') ELSE '0' WHEN (c_add(4 DOWNTO 1) < "0111") ELSE '1'; 
			  
----------------------------------
--- sync rest stuff --------------
--- rc_srst is sync with clk_RD --
--- srst_w is sync with clk_WR ---
----------------------------------

PROCESS(clk_WR,rst)
BEGIN 
	IF (rst = '1') THEN
		srst_w <= '0';	
		isrst_r <= '0';	
	ELSIF (rising_edge(clk_WR)) THEN
		srst_w <= isrst_w;
		IF (srst_w = '1') THEN
			isrst_r <= '1';
		ELSIF (srst_w = '0') THEN
			isrst_r <= '0';
		END IF;
	END IF;
END PROCESS;

PROCESS(clk_RD,rst)
BEGIN 
	IF (rst = '1') THEN
		srst_r <= '0';	
		isrst_w <= '0';
	ELSIF (rising_edge(clk_RD)) THEN
		srst_r <= rc_srst;
		IF (rc_srst = '1') THEN
			isrst_w <= '1';
		ELSIF (isrst_r = '1') THEN
			isrst_w <= '0';
		END IF;
	END IF;
END PROCESS;

END ARCHITECTURE;
