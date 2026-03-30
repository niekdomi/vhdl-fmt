--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------

-----------------------------------------------------------------------------
--	Filename:	baud_rate_gen.vhd
--
--	Description:
--		a 16 bit baud rate generator
--
--	Copyright (c) 2005 by George Huber 
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	---------- 	---------	-----------
--	1.0      	01/28/06  	H LeFevre	Initial revision
--	2.0      	02/04/06  	H LeFevre	reload counter with register load
--	2.1      	04/10/06  	H LeFevre	Fix error in rCLK
--
-----------------------------------------------------------------------------
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.std_logic_arith.all ;
USE ieee.std_logic_unsigned.all ;

ENTITY UART_Baud_Rate_GEN IS
	PORT(
		clk     : IN std_logic;	
		BR_clk  : IN std_logic;
		rst     : IN std_logic;
		WR      : IN std_logic;
		BE      : IN std_logic_vector(1 DOWNTO 0); -- byte enable
		D       : IN std_logic_vector(15 DOWNTO 0);
		RD      : OUT std_logic_vector(15 DOWNTO 0);
		rCE     : OUT std_logic;
		rCLK    : OUT std_logic
		);
END ENTITY;

ARCHITECTURE a OF UART_Baud_Rate_GEN IS
	SIGNAL UB_LD   : std_logic;
	SIGNAL LB_LD   : std_logic;
	SIGNAL rate    : std_logic_vector(15 DOWNTO 0);
	SIGNAL C_LD    : std_logic;
	SIGNAL C_CE    : std_logic;
	SIGNAL irLD    : std_logic;	-- added 02/04/06
	SIGNAL rLD     : std_logic; -- added 02/04/06
	SIGNAL count   : std_logic_vector(15 DOWNTO 0);
	
BEGIN
 
rCE <= '1' WHEN (count = x"01") ELSE '0';
		
u0: PROCESS(BR_clk,rst)
BEGIN
	IF (rst = '1') THEN
		rCLK <= '0';
		rLD <= '0';
	ELSIF (rising_edge(BR_CLK)) THEN 
		rLD <= irLD;
		IF (count > ('0' & (rate(15 DOWNTO 1)))) THEN -- fixed 04/10/06
			rCLK <= '1';
		ELSE
			rCLK <= '0';
		END IF;
	END IF;
END PROCESS u0;

	RD <= rate;
	
----------------------------------------------
----------------------------------------------	

UB_LD <= '0' WHEN (WR = '0') ELSE '0' WHEN (BE(1) = '0') ELSE '1';


u1: PROCESS (clk,rst)
BEGIN
	IF (rst = '1') THEN
		rate(15 DOWNTO 8) <= (OTHERS =>'0');
	ELSIF (rising_edge (clk)) THEN
		IF (UB_LD = '1') THEN
			rate(15 DOWNTO 8) <= d(15 DOWNTO 8);
		END IF;
	END IF;
END PROCESS;


LB_LD <= '0' when (WR = '0') ELSE '0' when (BE(0) = '0') ELSE '1';

u2: PROCESS (clk,rst)
BEGIN
	IF (rst = '1') THEN
		rate(7 DOWNTO 0) <= (OTHERS =>'0');
	ELSIF (rising_edge (clk)) THEN
		IF (LB_LD = '1') THEN
			rate(7 DOWNTO 0) <= d(7 DOWNTO 0);
		END IF;
	END IF;
END PROCESS;

------------------------------------------------------------
------------ baud rate counter -----------------------------
------------------------------------------------------------

u3: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN
		irLD <= '0';
	ELSIF (rising_edge(CLK)) THEN 
		IF ((UB_LD OR LB_LD) = '1') THEN
			irLD <= '1';
		ELSIF (rLD = '1') THEN
			irLD <= '0';
		END IF;
	END IF;
END PROCESS u3;

C_LD <= '1' WHEN (count = x"01") ELSE '1' WHEN (rLD = '1') ELSE '0';
	
C_CE <= '1' WHEN (rate > x"01") ELSE '0';


u4: PROCESS(BR_clk,rst)
BEGIN
	IF (rst = '1') THEN 
		count <= (OTHERS => '0');
	ELSIF (rising_edge(BR_clk)) THEN
		IF (C_LD = '1') THEN 
			count <= rate;
		ELSIF (C_CE = '1') THEN
			count <= (count - "01");
		END IF;			
	END IF;
END PROCESS u4;

END a;

