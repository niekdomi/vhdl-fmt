--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------



-----------------------------------------------------------------------------
--	Filename:	edge_det.vhd
--
--	Description:
--		an edge detector - 
--		   finds the rising edge and falling edge
--
--	Copyright (c) 2005 by George Huber 
--		an OpenCores.org Project
--		free to use, but see documentation for conditions  
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	----------	--------	-----------
--	1.0      	09/10/05  	G Huber 	Initial revision
--	2.0     	09/17/05  	h lefevre	name change to avoid conflict
--	        	          	         	  with other libraries
--	2.1      	05/21/06  	S A Dodd 	fix typo's
--
-----------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY UART_Edge_Det IS
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		D   : IN std_logic;
		re  : OUT std_logic; -- rising edge (need sync source at D)
		fe  : OUT std_logic; -- falling edge (need sync source at D)
		sre : OUT std_logic; -- sync'd rising edge
		sfe : OUT std_logic  -- sync'd falling edge
		);
END ENTITY UART_Edge_Det;


ARCHITECTURE a OF UART_Edge_Det IS

	SIGNAL Q0, Q1 : std_logic;

BEGIN

	re <= D AND (NOT Q0);
	fe <= (NOT D) AND Q0;
	sre <= Q0 AND (NOT Q1);
	sfe <= (NOT Q0) AND Q1;
	
PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		Q0 <= '0';
		Q1 <= '0';
	ELSIF (rising_edge(clk)) THEN
		Q0 <= D;
		Q1 <= Q0;
	END IF;
END PROCESS;

END a;
