--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------

-----------------------------------------------------------------------------
--	Filename:	uart_Tx_8bit.vhd
--
--	Description:
--		an 8 bit UART Tx Module
--
--	Copyright (c) 2006, 2007 by H LeFevre
--		A VHDL 16550 UART core
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	---------- 	---------	-----------
--	1.0      	02/18/06  	H LeFevre	Initial revision
--	1.1      	02/25/06  	H LeFevre	add BUSYn output
--	2.0     	06/18/07  	P.Azkarate  Define "range" in T_WCOUNT and x_dCOUNT signals
--	2.1     	07/12/07  	H LeFevre	fix a problem with 5 bit data and 1.5 stop bits
--       		          	         	   as pointed out by Matthias Klemm
--	2.2     	08/17/07  	H LeFevre	add stopB to sensitivity list line 164
--       		          	         	   as suggested by Guillaume Zin 
-----------------------------------------------------------------------------
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;

ENTITY UART_TX_8_Bit IS 
	PORT(
		clk       : IN std_logic; --  clock
		rst       : IN std_logic;
		xBRC      : IN std_logic; -- x clock enable
		D_RYn     : IN std_logic; -- data ready 
		D         : IN std_logic_vector(7 DOWNTO 0);
		num_bits  : IN integer:= 8; -- number of bits in transfer
		Break_CB  : IN std_logic;
		stopB     : IN std_logic;
		Parity_EN : IN std_logic;
		Parity_EV : IN std_logic;
		sTX       : OUT std_logic;
		BUSYn     : OUT std_logic;
		read      : OUT std_logic -- data read
		);
END ENTITY UART_TX_8_Bit;
	
ARCHITECTURE a OF UART_TX_8_Bit IS


	type T_StateType is (idle,s_start_bit,shift_data,s_parity,
	                     s_stop_bit,s_stop_bit2);
	SIGNAL T_state, T_nstate : T_StateType; 

	SIGNAL parity      : std_logic;
	SIGNAL parity_Grst : std_logic;
	SIGNAL TWC_LD      : std_logic;
	SIGNAL TWC_CE      : std_logic;
	SIGNAL T_WCOUNT : integer range 0 to 15;
	SIGNAL D_LD_v : integer range 1 to 15;
	SIGNAL D_LD : std_logic;
	SIGNAL Trans_sr_SE : std_logic;
	SIGNAL Trans_shift_reg : std_logic_vector(7 DOWNTO 0);
	SIGNAL iTX : std_logic;
	SIGNAL BRC : std_logic;
	SIGNAL dCLK_LD : std_logic;
	SIGNAL x_dCOUNT : integer range 0 to 15;
	
BEGIN

----------------------------------------------
---- outputs----------------------------------
----------------------------------------------

	BUSYn <= '1' WHEN (T_state = idle) ELSE
	         '0';

	read <= D_LD; -- read a data word

----------------------------------------------

	dCLK_LD <= '1' WHEN ((num_bits = 5) AND (stopB = '1') 
	               AND (T_state = s_stop_bit2) AND (x_dCOUNT = 7)) ELSE
	           '0' WHEN (D_RYn = '0') ELSE
	           '0' WHEN (T_state /= idle) ELSE
	           '1';

	D_LD_v <= 15 WHEN (T_state = s_stop_bit2) ELSE
	           1;
			   
	BRC <= '0' WHEN (xBRC = '0') ELSE
	       '1' WHEN (x_dCOUNT = 0) ELSE
	       '0';


----
----
u1: PROCESS (clk,rst) -- baud rate divider
BEGIN 
	IF (rst = '1') THEN
		x_dCOUNT <= 0;
	ELSIF (rising_edge(clk))  THEN 
		IF (dCLK_LD = '1') THEN
			x_dCOUNT <= D_LD_v;  
		ELSIF (xBRC = '1') THEN
			IF (x_dCOUNT = 0) THEN
				x_dCOUNT <= 15;
			ELSE 
				x_dCOUNT <= x_dCOUNT - 1;
			END IF;
		END IF;
	END IF;
END PROCESS;
----
----

----
----
u2: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		Trans_shift_reg <= (OTHERS => '0');
	ELSIF (rising_edge(clk)) THEN
		IF (D_LD = '1') THEN 
			Trans_shift_reg <= D;
		ELSIF (Trans_sr_SE = '1') THEN -- shift left
			Trans_shift_reg(7 DOWNTO 0) <=  '0' & Trans_shift_reg(7 DOWNTO 1);
		ELSE
			Trans_shift_reg <= Trans_shift_reg;
		END IF;
	END IF;
END PROCESS;
----
----
		
--------------------------------------------------------------
--------------------------------------------------------------
	
PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN
		sTX <= '1';
	ELSIF (rising_edge(clk)) THEN
		sTX <= iTX AND (NOT Break_CB);
	END IF;
END PROCESS ;

	iTX <= '0' WHEN (T_state = s_start_bit) ELSE -- send start bit
	        Trans_shift_reg(0) WHEN (T_state = shift_data) ELSE -- send data
	        parity WHEN ((Parity_EV = '1') AND (T_state = s_parity)) ELSE
	        (NOT parity) WHEN (T_state = s_parity) ELSE
	        '1'; -- idle, stop bit

PROCESS(T_state,D_RYn,BRC,T_WCOUNT,Parity_EN,num_bits,x_dCOUNT,stopB)
BEGIN
	CASE T_state IS
		WHEN idle => -- idle  
			TWC_CE <= '0';
			IF ((D_RYn = '0') AND (BRC = '1')) THEN
				D_LD <= '1'; Trans_sr_SE <= '0'; 
				TWC_LD <= '0'; 
				T_nstate <= s_start_bit;
			ELSE 
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= idle;
			END IF;
		WHEN s_start_bit => -- fifo is read, send start bit
			TWC_CE <= '0';
			IF (BRC = '1') THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '1';
				T_nstate <= shift_data;
			ELSE
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_start_bit;
			END IF;
		WHEN shift_data => -- send data bit
			IF (BRC = '0') THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; 
				TWC_LD <= '0'; TWC_CE <= '0';
				T_nstate <= shift_data;
			ELSIF ((T_WCOUNT = 1) AND (Parity_EN = '1')) THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; 
				TWC_LD <= '0'; TWC_CE <= '1';
				T_nstate <= s_parity;
			ELSIF (T_WCOUNT = 1) THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; 
				TWC_LD <= '0'; TWC_CE <= '1';
				T_nstate <= s_stop_bit;
			ELSE
				D_LD <= '0'; Trans_sr_SE <= '1'; 
				TWC_LD <= '0'; TWC_CE <= '1';
				T_nstate <= shift_data;
			END IF;
		WHEN s_parity => -- send parity bit
			TWC_CE <= '0';
			IF (BRC = '1') THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_stop_bit;
			ELSE 
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_parity;
			END IF;	 
		WHEN s_stop_bit => -- send stop bit
			TWC_CE <= '0';
			IF (BRC = '0') THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_stop_bit;
			ELSIF (stopB = '1') THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_stop_bit2;
			ELSIF (D_RYn = '0') THEN
				D_LD <= '1'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_start_bit;
			ELSE 
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= idle;
			END IF;
		WHEN s_stop_bit2 => -- send stop bit 
			TWC_CE <= '0';
			IF ((D_RYn = '0') AND (BRC = '1')) THEN
				D_LD <= '1'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_start_bit; 
			ELSIF (BRC = '1') THEN
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= idle;
			ELSIF ((num_bits = 5) AND (x_dCOUNT = 7) AND (D_RYn = '0')) THEN
				D_LD <= '1'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_start_bit;
			ELSIF ((num_bits = 5) AND (x_dCOUNT = 7)) THEN
				D_LD <= '1'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= idle;
			ELSE 
				D_LD <= '0'; Trans_sr_SE <= '0'; TWC_LD <= '0';
				T_nstate <= s_stop_bit2;
			END IF;
		WHEN OTHERS => 
			D_LD <= '0'; Trans_sr_SE <= '0'; 
			TWC_LD <= '0'; TWC_CE <= '0';
			T_nstate <= idle;
	END CASE;
END PROCESS;

--
-- registers for SM
PROCESS(CLK,rst)
BEGIN
	IF (rst = '1') THEN
		T_state <= idle;
	ELSIF (rising_edge(CLK)) THEN
		T_state <= T_nstate;
	END IF;
END PROCESS;

----
----
u3: PROCESS(clk,rst) -- word counter
BEGIN 
	IF (rst = '1') THEN
		T_WCOUNT <= 0;
	ELSIF (rising_edge(clk))  THEN 
		IF (TWC_LD = '1') THEN
			T_WCOUNT <= num_bits;  
		ELSIF (TWC_CE = '1') THEN
			IF (T_WCOUNT = 0) THEN
				T_WCOUNT <= 8;
			ELSE 
				T_WCOUNT <= T_WCOUNT - 1;
			END IF;
		END IF;
	END IF;
END PROCESS;
----
----

--------------------------------------------------------
--------------------------------------------------------

parity_Grst <= '1' WHEN (T_state = s_start_bit) ELSE '0';
	

----
----
u4: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		parity <= '0';
	ELSIF (rising_edge(clk)) THEN
		IF (parity_Grst = '1') THEN -- need to clear before start of data word
			parity <= '0';
		ELSIF (BRC = '1') THEN -- sample data bit for parity generation
			parity <= (parity XOR Trans_shift_reg(0));
		END IF;
	END IF;
END PROCESS;

----
----
		
END a;

