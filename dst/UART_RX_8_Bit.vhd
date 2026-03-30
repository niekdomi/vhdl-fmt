--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------

-----------------------------------------------------------------------------
--	Filename:	uart_Rx_8bit.vhd
--
--	Description:
--		an 8 bit UART Rx Module
--
--	Copyright (c) 2006 by H LeFevre 
--		A VHDL 16550 UART core
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	---------- 	---------	-----------
--	1.0      	02/18/06  	H LeFevre  	Initial revision
--	1.1      	02/25/06  	H LeFevre  	mod to SM, goes to idle faster
--	        	          	         	   if no break error  
--	2.0     	06/18/07  	P.Azkarate  Define "range" in R_WCOUNT and R_brdCOUNT signals
-----------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY UART_RX_8_Bit IS 
   PORT (
		clk       : IN std_logic; -- clock
		rst       : IN std_logic;
		BRCx16    : IN std_logic; -- 16x clock enable
		sRX       : IN std_logic; 
		num_bits  : IN integer;
		Parity_EN : IN std_logic;
		Parity_EV : IN std_logic;
		Parity_ER : OUT std_logic;
		Frame_ER  : OUT std_logic;
		Break_ITR : OUT std_logic;
		D_RDY     : OUT std_logic;
		D         : OUT std_logic_vector(7 DOWNTO 0)
		);
END ENTITY UART_RX_8_Bit;
	
ARCHITECTURE a OF UART_RX_8_Bit IS


	type R_StateType is (idle,R_start_bit,shift_data,R_parity,
	                     R_stop_bit,break_err);
	SIGNAL R_state, R_nstate : R_StateType; 

	SIGNAL parity      : std_logic;
	SIGNAL parity_Grst : std_logic;
	SIGNAL RWC_LD      : std_logic;
	SIGNAL R_WCOUNT : integer RANGE 0 TO 15;
	SIGNAL s_DATA_LD : std_logic;
	SIGNAL chk_par : std_logic;
	SIGNAL chk_frm : std_logic;
	SIGNAL clr_brk : std_logic;
	SIGNAL clr_D : std_logic;
	SIGNAL s_chk_par : std_logic;
	SIGNAL s_chk_frm : std_logic;
	SIGNAL R_shift_reg : std_logic_vector(7 DOWNTO 0);
	SIGNAL iRX : std_logic;
	SIGNAL BRC : std_logic;
	SIGNAL dCLK_LD : std_logic;
	SIGNAL R_brdCOUNT : integer RANGE 0 TO 15;
	SIGNAL iParity_ER : std_logic;
	SIGNAL iFrame_ER : std_logic;
	SIGNAL iBreak_ITR : std_logic;
	SIGNAL iD_RDY : std_logic;
	
BEGIN

----------------------------------------------
---- outputs----------------------------------
----------------------------------------------
PROCESS(CLK,rst)
BEGIN
	IF (rst = '1') THEN	
		Parity_ER <= '0';
		Frame_ER <= '0';
		Break_ITR <= '0';
		D_RDY <= '0';
	ELSIF (rising_edge(CLK)) THEN
		IF (BRCx16 = '1') THEN
			D_RDY <= iD_RDY;
			IF (iD_RDY = '1') THEN
				Parity_ER <= iParity_ER;
				Frame_ER <= iFrame_ER;
				Break_ITR <= iBreak_ITR;
			END IF;
		END IF;
	END IF;
END PROCESS;

	D <= R_shift_reg WHEN (num_bits = 8) ELSE
	    ('0' & R_shift_reg(7 DOWNTO 1)) WHEN (num_bits = 7) ELSE
	    ("00" & R_shift_reg(7 DOWNTO 2)) WHEN (num_bits = 6) ELSE
	    ("000" & R_shift_reg(7 DOWNTO 3)); -- WHEN (bits_word = 5) ELSE


----------------------------------------------

dCLK_LD <= '1' WHEN (R_state = idle) ELSE '0';
			   
BRC <= '0' WHEN (BRCx16 = '0') ELSE '1' WHEN (R_brdCOUNT = 0) ELSE '0';
	
----
----
u1: PROCESS(clk,rst) -- baud rate divider
BEGIN 
	IF (rst = '1') THEN
		R_brdCOUNT <= 0;
	ELSIF (rising_edge(clk))  THEN 
		IF (dCLK_LD = '1') THEN
			R_brdCOUNT <= 14;  
		ELSIF (BRCx16 = '1') THEN
			IF (R_brdCOUNT = 0) THEN
				R_brdCOUNT <= 15;
			ELSE 
				R_brdCOUNT <= R_brdCOUNT - 1;
			END IF;
		END IF;
	END IF;
END PROCESS;
----
----
		
----------------------------------------------------------

----
----
u2: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		R_shift_reg <= (OTHERS => '0');
	ELSIF (rising_edge(clk)) THEN 
		IF (clr_D = '1') THEN
			R_shift_reg <= (OTHERS => '0');
		ELSIF (s_DATA_LD = '1') THEN
			R_shift_reg(7) <= sRX;
			R_shift_reg(6 DOWNTO 0) <= R_shift_reg(7 DOWNTO 1);
		END IF;
	END IF;
END PROCESS;
----
----

-----------------------------------------------------------

	chk_par <= s_chk_par AND (((parity XOR iRX) AND Parity_EV) 
	                 OR (((not parity) XOR iRX) AND (NOT Parity_EV)));

----
----
u2c: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		iParity_ER <= '0';
	ELSIF (rising_edge(clk)) THEN 
		IF ((chk_par = '1') AND (dCLK_LD = '1')) THEN
			iParity_ER <= NOT iParity_ER;
		ELSIF (chk_par = '1') THEN
			iParity_ER <= '1';
		ELSIF (dCLK_LD = '1') THEN
			iParity_ER <= '0';
		END IF;
	END IF;
END PROCESS;
----
----

chk_frm <= s_chk_frm AND (NOT iRX);
		
----
----
u2d: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		iFrame_ER <= '0';
	ELSIF (rising_edge(clk)) THEN 
		IF ((chk_frm = '1') AND (dCLK_LD = '1')) THEN
			iFrame_ER <= NOT iFrame_ER;
		ELSIF (chk_frm = '1') THEN
			iFrame_ER <= '1';
		ELSIF (dCLK_LD = '1') THEN
			iFrame_ER <= '0';
		END IF;
	END IF;
END PROCESS;
----
----

----
----
u2e: PROCESS(clk,rst)
BEGIN
	IF (rst = '1') THEN 
		iBreak_ITR <= '0';
	ELSIF (rising_edge(clk)) THEN 
		if ((clr_d = '1') AND (clr_brk = '1')) THEN
			iBreak_ITR <= not iBreak_ITR;
		ELSIF (clr_d = '1') THEN
			iBreak_ITR <= '1';
		ELSIF (clr_brk = '1') THEN
			iBreak_ITR <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
		
--------------------------------------------------------------
--------------------------------------------------------------


PROCESS(R_state,BRCx16,BRC,iRX,R_WCOUNT,Parity_EN,R_brdCOUNT,iBreak_ITR)
BEGIN
	CASE R_state IS
		WHEN idle => -- idle  
			iD_RDY <= '0'; s_DATA_LD <= '0'; RWC_LD <= '1'; 
			s_chk_par <= '0'; s_chk_frm <= '0'; clr_brk <= '0';
			clr_D <= '0';
			IF (iRX = '0') THEN	
				R_nstate <= R_start_bit;
			ELSE 
				R_nstate <= idle;
			END IF;
		WHEN R_start_bit => -- 
			iD_RDY <= '0'; s_DATA_LD <= '0'; RWC_LD <= '1'; 
			s_chk_par <= '0'; s_chk_frm <= '0'; clr_brk <= '0';
			IF (BRC = '1') THEN
				clr_D <= '1';
				R_nstate <= shift_data;
			ELSIF ((R_brdCOUNT = 8) AND (iRX = '1')) THEN -- false start bit detection
				clr_D <= '0';
				R_nstate <= idle;
			ELSE
				clr_D <= '0';
				R_nstate <= R_start_bit;
			END IF;
		WHEN shift_data => -- send data bit	
			iD_RDY <= '0'; RWC_LD <= '0';
			s_chk_par <= '0'; s_chk_frm <= '0';
			clr_D <= '0';
			IF (BRCx16 = '0') THEN
				s_DATA_LD <= '0'; clr_brk <= '0';
				R_nstate <= shift_data;	
			ELSIF (R_brdCOUNT = 8) THEN
				s_DATA_LD <= '1'; clr_brk <= iRX; 
				R_nstate <= shift_data;	
			ELSIF ((R_WCOUNT = 1) AND (R_brdCOUNT = 0) AND (Parity_EN = '1')) THEN
				s_DATA_LD <= '0'; clr_brk <= '0';
				R_nstate <= R_parity;	
			ELSIF ((R_WCOUNT = 1) AND (R_brdCOUNT = 0)) THEN
				s_DATA_LD <= '0'; clr_brk <= '0';
				R_nstate <= R_stop_bit;
			ELSE
				s_DATA_LD <= '0'; clr_brk <= '0'; 
				R_nstate <= shift_data;
			END IF;
		WHEN R_parity => -- check parity bit
			iD_RDY <= '0'; s_DATA_LD <= '0'; 
			RWC_LD <= '0'; s_chk_frm <= '0';
			clr_D <= '0';
			IF (BRCx16 = '0') THEN
				s_chk_par <= '0';  clr_brk <= '0';
				R_nstate <= R_parity;
			ELSIF (R_brdCOUNT = 8) THEN
				s_chk_par <= '1'; clr_brk <= iRX; 
				R_nstate <= R_parity;
			ELSIF (BRC = '1') THEN
				s_chk_par <= '0'; clr_brk <= '0';
				R_nstate <= R_stop_bit;
			ELSE 
				s_chk_par <= '0'; clr_brk <= '0';
				R_nstate <= R_parity;
			END IF;	 
		WHEN R_stop_bit => -- check stop bit
			s_DATA_LD <= '0'; RWC_LD <= '0'; 
			s_chk_par <= '0'; clr_brk <= iRX;
			clr_D <= '0';
			IF ((BRC = '1') AND (iBreak_ITR = '1')) THEN
				iD_RDY <= '1'; s_chk_frm <= '0';
				R_nstate <= break_err; 
			ELSIF (BRC = '1') THEN
				iD_RDY <= '1'; s_chk_frm <= '0';
				R_nstate <=	idle;
			ELSIF (R_brdCOUNT = 8) THEN
				iD_RDY <= '0'; s_chk_frm <= '1';
				R_nstate <= R_stop_bit;	
			ELSIF ((R_brdCOUNT = 7) AND (iBreak_ITR = '0')) THEN -- added 02/20/06
				iD_RDY <= '1'; s_chk_frm <= '0';
				R_nstate <=	idle;
			ELSE 
				iD_RDY <= '0'; s_chk_frm <= '0';
				R_nstate <= R_stop_bit;
			END IF;	
		WHEN break_err => 
			iD_RDY <= '0'; s_DATA_LD <= '0'; RWC_LD <= '0'; 
			s_chk_par <= '0'; s_chk_frm <= '0'; clr_brk <= '0';
			clr_D <= '0';
			IF (iRX = '1') THEN
				R_nstate <= idle;
			ELSE
				R_nstate <= break_err;
			END IF;
		WHEN OTHERS => 
			iD_RDY <= '0'; s_DATA_LD <= '0'; RWC_LD <= '0'; 
			s_chk_par <= '0'; s_chk_frm <= '0'; clr_brk <= '0';
			clr_D <= '0';
			R_nstate <= idle;
	END CASE;
END PROCESS;

--
-- registers for SM
PROCESS(CLK,rst)
BEGIN
	IF (rst = '1') THEN	
		iRX <= '1';
		R_state <= idle;
	ELSIF (rising_edge(CLK)) THEN
		IF (BRCx16 = '1') THEN
			iRX <= sRX;
			R_state <= R_nstate;
		ELSE 
			iRX <= iRX;
			R_state <= R_state;
		END IF;
	END IF;
END PROCESS;


----
----
u3: PROCESS(clk,rst)-- word counter
BEGIN 
	IF (rst = '1') THEN
		R_WCOUNT <= 0;
	ELSIF (rising_edge(clk))  THEN 
		IF (RWC_LD = '1') THEN
			R_WCOUNT <= num_bits;  
		ELSIF (BRC = '1') THEN
			IF (R_WCOUNT = 0) THEN
				R_WCOUNT <= 8;
			ELSE 
				R_WCOUNT <= R_WCOUNT - 1;
			END IF;
		END IF;
	END IF;
END PROCESS u3;
----
----

--------------------------------------------------------
--------------------------------------------------------
			   
parity_Grst <= '1' WHEN (R_state = R_start_bit) ELSE '0';
	

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
			parity <= (parity XOR R_shift_reg(7));
		END IF;
	END IF;
END PROCESS;
----
----
		
END a;

