--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------

-----------------------------------------------------------------------------
--	Filename:	edge_det_XCD.vhd
--
--	Description:
--		an edge detector, for crossing clock domains - 
--		   finds the rising edge and falling edge for a pulse crossing clock domains
--
--	Copyright (c) 2006, 2008 by George Huber 
--		an OpenCores.org Project
--		free to use, but see documentation for conditions  
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	----------	--------	-----------
--	1.0        	09/16/06  	S A Dodd 	Initial revision
--	2.0     	04/12/08  	hlefevre	mod to double register between clocks
--	        	          	        	   output time remains the same
--
-----------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY UART_Edge_Det_XCD IS
	PORT(
		iclk : IN std_logic;  -- clock for input data signal
		oclk : IN std_logic;  -- clock for output data pulse
		rst  : IN std_logic;
		D    : IN std_logic;
		re   : OUT std_logic; -- rising edge 
		fe   : OUT std_logic  -- falling edge 
		);
END ENTITY UART_Edge_Det_XCD;


ARCHITECTURE a OF UART_Edge_Det_XCD IS

	SIGNAL iQ  : std_logic;
	SIGNAL jkR, jkF : std_logic;
	SIGNAL irQ0, rQ0, rQ1 : std_logic;
	SIGNAL ifQ0, fQ0, fQ1 : std_logic;

BEGIN

PROCESS(iclk,rst)
BEGIN
	IF (rst = '1') THEN 
		iQ <= '0';
		jkR <= '0';
		jkF <= '0';
	ELSIF (rising_edge(iclk)) THEN
		iQ <= D;
		IF ((D = '1') AND (iQ = '0')) THEN
			jkR <= '1';
		ELSIF (rQ1 = '1') THEN
			jkR <= '0';
		ELSE
			jkR <= jkR;
		END IF;
		IF ((D = '0') AND (iQ = '1')) THEN
			jkF <= '1';
		ELSIF (fQ1 = '1') THEN
			jkF <= '0';
		ELSE
			jkF <= jkF;
		END IF;
	END IF;
END PROCESS;

re <= (NOT rQ1) AND rQ0;
fe <= (NOT fQ1) AND fQ0;

PROCESS(oclk,rst)
BEGIN
	IF (rst = '1') THEN 
		irQ0 <= '0';
		rQ0 <= '0'; 
		rQ1 <= '0';
		---------------
		ifQ0 <= '0';
		fQ0 <= '0';
		fQ1 <= '0';
	ELSIF (rising_edge(oclk)) THEN
		irQ0 <= jkR;
		rQ0 <= irQ0;
		rQ1 <= rQ0;
		---------------
		ifQ0 <= jkF;
		fQ0 <= ifQ0;
		fQ1 <= fQ0;
	END IF;
END PROCESS;


END a;
