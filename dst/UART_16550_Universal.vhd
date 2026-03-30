-- MODULE UART 16550
-- VHDL Architecture Indel_lib.UART_16550.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --

-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
-- 28.02.2008                                                                 --
-- This is an adapted OpenCores.org UART16550. Why was it adapted and not used--
-- as it is?- The "standard" version needs the whole "gh_vhdl" library which  --
-- has to be instantiated in every design the UART is used.                   --
-- -------------------------------------------------------------------------- --
--                                                                            --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --


--------------------------------------------------------------------------------
--$Rev:: 776                                                                   $
--$Author:: leuthold_wg                                                        $
--$Date:: 2008-11-24 14:44:59 +0100 (Mo., 24 Nov 2008)                         $
--------------------------------------------------------------------------------

-----------------------------------------------------------------------------
--	Filename:	UART_16550_Universal.vhd
--
--	Description:
--		designed to be a 16550 compatible UART 
--
--	Copyright (c) 2006, 2007 by H LeFevre 
--		A VHDL 16550 UART core
--		an OpenCores.org Project
--		free to use, but see documentation for conditions 
--
--	Revision 	History:
--	Revision 	Date       	Author    	Comment
--	-------- 	---------- 	---------	-----------
--	1.0      	02/25/06  	H LeFevre	Initial revision 
--	1.1     	03/18/06  	H LeFevre	mod to clear THREmpty interrupt 
--	        	          	         	    with IIR read 
--	1.2     	04/08/06  	H LeFevre	add time out interrupt
--	1.3     	04/19/06  	H LeFevre	fix read fifo signal, so fifo 
--	        	          	         	   will not lose data when baud rate 
--	        	          	         	   generator is read
--	2.0     	12/13/06  	H LeFevre	Fixed THRE interrupt, as recommended
--	       		          	         	   by Walter Hogan 12/12/06 
--	2.1     	12/23/06  	H LeFevre	replace fifo's
--	2.2    		01/20/07  	H LeFevre	replace read fifo 
--	2.3     	02/22/07  	B Chini  	Modified TOI Function To Work as Specified in 16550D manual
--	2.4    		07/12/07  	H LeFevre	fix 6, 7 bits transfers (LCR bits 1,0 were swapped
--       		          	         	   as pointed out by Matthias Klemm
--	2.5     	08/03/07  	H LeFevre	Mod TOI to fix issues missed in 2.3 (enabled with receiveIRQ, 
--       		          	         	   time reset with receive word- as Specified in 16550D manual)
--	2.6     	08/04/07  	H LeFevre	load TOI when receive IRQ disabled
--	2.7     	10/12/07  	H LeFevre	fix LSR Interrupt, as suggested by Matthias Klemm
--	   	    	          	         	+  mod to THRE Interrupt now, will be generated
--	   	    	          	         	   when enabled while trans FIFO is empty
--	   	    	          	         	   (opencore bug report)
--	2.7     	10/13/07  	H LeFevre	mod LSR Interrupt so that it will retrigger with
--	   	    	          	         	   back to back errors
--
-----------------------------------------------------------------------------
LIBRARY ieee ;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.INFO_SAM3_Package_Take2.all;

ENTITY UART_16550 IS
	PORT(
		GCLK    : IN std_logic;
		BRCLK   : IN std_logic;
		CLR_n   : IN std_logic;
		CS      : IN std_logic;
		WR      : IN std_logic;
		BE      : IN std_logic_vector(Return_Upper_F_I_PKG(Router_BE_Width_C_S_PKG) DOWNTO 0);
		WR_Data : IN std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
		
		sRX     : IN std_logic;
		CTSn    : IN std_logic := '1';
		DSRn    : IN std_logic := '1';
		RIn     : IN std_logic := '1';
		DCDn    : IN std_logic := '1';
		
		sTX     : OUT std_logic;
		DTRn    : OUT std_logic;
		RTSn    : OUT std_logic;
		OUT1n   : OUT std_logic;
		OUT2n   : OUT std_logic;
		TXRDYn  : OUT std_logic;
		RXRDYn  : OUT std_logic;
		
		IRQ     : OUT std_logic;
		BCLK    : OUT std_logic;
	   RD_Data : OUT std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0)
		);
END ENTITY UART_16550;


ARCHITECTURE Universal OF UART_16550 IS

COMPONENT UART_Edge_Det IS
	PORT(	
		clk : IN  std_logic;
		rst : IN  std_logic;
		D   : IN  std_logic;
		re  : OUT std_logic; -- rising edge (need sync source at D)
		fe  : OUT std_logic; -- falling edge (need sync source at D)
		sre : OUT std_logic; -- sync'd rising edge
		sfe : OUT std_logic  -- sync'd falling edge
		);
END COMPONENT UART_Edge_Det;


COMPONENT UART_TX_8_Bit IS	
	PORT(
		clk       : IN  std_logic; --  clock
		rst       : IN  std_logic;
		xBRC      : IN  std_logic; -- x clock enable
		D_RYn     : IN  std_logic; -- data ready 
		D         : IN  std_logic_vector(7 DOWNTO 0);
		num_bits  : IN  integer:= 8; -- number of bits in transfer
		Break_CB  : IN  std_logic;
		stopB     : IN  std_logic;
		Parity_EN : IN  std_logic;
		Parity_EV : IN  std_logic;
		sTX       : OUT std_logic;
		BUSYn     : OUT std_logic;
		read      : OUT std_logic -- data read
		);
END COMPONENT UART_TX_8_Bit;


COMPONENT UART_RX_8_Bit IS	
	PORT(
		clk       : IN  std_logic; -- clock
		rst       : IN  std_logic;
		BRCx16    : IN  std_logic; -- 16x clock enable
		sRX       : IN  std_logic; 
		num_bits  : IN  integer;
		Parity_EN : IN  std_logic;
		Parity_EV : IN  std_logic;
		Parity_ER : OUT std_logic;
		Frame_ER  : OUT std_logic;
		Break_ITR : OUT std_logic;
		D_RDY     : OUT std_logic;
		D         : OUT std_logic_vector(7 DOWNTO 0)
		);
END COMPONENT;


COMPONENT UART_FIFO_async_16_SR IS
	GENERIC (data_width: integer :=8 ); -- size of data bus
	PORT (					
		clk_WR : IN  std_logic; -- write clock
		clk_RD : IN  std_logic; -- read clock
		rst    : IN  std_logic; -- resets counters
		srst   : IN  std_logic; -- resets counters
		WR     : IN  std_logic; -- write control 
		RD     : IN  std_logic; -- read control
		D      : IN  std_logic_vector(data_width-1 DOWNTO 0);
		Q      : OUT std_logic_vector(data_width-1 DOWNTO 0);
		empty  : OUT std_logic; 
		full   : OUT std_logic
		);
END COMPONENT UART_FIFO_async_16_SR;


COMPONENT UART_Baud_Rate_GEN IS
	PORT(
		clk     : IN  std_logic;
		rst     : IN  std_logic;
		BR_clk  : IN  std_logic;
		WR      : IN  std_logic;
		BE      : IN  std_logic_vector(1 DOWNTO 0); -- byte enable
		D       : IN  std_logic_vector(15 DOWNTO 0);
		RD      : OUT std_logic_vector(15 DOWNTO 0);
		rCE     : OUT std_logic;
		rCLK    : OUT std_logic
		);
END COMPONENT UART_Baud_Rate_GEN;


COMPONENT UART_FIFO_async_16_RCSR_WF IS
	GENERIC (data_width: integer :=8 ); -- size of data bus
	PORT (					
		clk_WR  : IN  std_logic; -- write clock
		clk_RD  : IN  std_logic; -- read clock
		rst     : IN  std_logic; -- resets counters
		rc_srst : in  std_logic:= '0'; -- resets counters (sync with clk_RD!!!)
		WR      : IN  std_logic; -- write control 
		RD      : IN  std_logic; -- read control
		D       : IN  std_logic_vector(data_width-1 DOWNTO 0);
		q       : OUT std_logic_vector(data_width-1 DOWNTO 0);
		empty   : OUT std_logic; -- sync with clk_RD!!!
		q_full  : OUT std_logic; -- sync with clk_RD!!!
		h_full  : OUT std_logic; -- sync with clk_RD!!!
		a_full  : OUT std_logic; -- sync with clk_RD!!!
		full    : OUT std_logic
		);
END COMPONENT UART_FIFO_async_16_RCSR_WF;


COMPONENT  UART_Edge_Det_XCD IS -- added 2 aug 2007
	PORT(
		iclk : IN  std_logic;  -- clock for input data signal
		oclk : IN  std_logic;  -- clock for output data pulse
		rst  : IN  std_logic;
		D    : IN  std_logic;
		re   : OUT std_logic; -- rising edge 
		fe   : OUT std_logic  -- falling edge 
		);
END COMPONENT UART_Edge_Det_XCD;

	SIGNAL IER    : std_logic_vector(3 DOWNTO 0); -- Interrupt Enable Register
	SIGNAL IIR    : std_logic_vector(7 DOWNTO 0); -- Interrupt ID Register
	SIGNAL iIIR   : std_logic_vector(3 DOWNTO 0); -- 12/23/06
	SIGNAL FCR    : std_logic_vector(7 DOWNTO 0); -- FIFO Control register
	SIGNAL LCR    : std_logic_vector(7 DOWNTO 0); -- Line Control Register
	SIGNAL MCR    : std_logic_vector(4 DOWNTO 0); -- Modem Control Register
	SIGNAL LSR    : std_logic_vector(7 DOWNTO 0); -- Line Status Register
	SIGNAL MSR    : std_logic_vector(7 DOWNTO 0); -- Modem Status Register
	SIGNAL SCR    : std_logic_vector(7 DOWNTO 0); -- Line Control Register
	SIGNAL RDD    : std_logic_vector(15 DOWNTO 0); -- Divisor Latch 
	SIGNAL iMSR   : std_logic_vector(7 DOWNTO 4); -- Modem Status Register
	SIGNAL RD_IIR : std_logic;
	
	SIGNAL iRD    : std_logic_vector(7 DOWNTO 0);
	SIGNAL CSn    : std_logic;
	SIGNAL WR_B   : std_logic_vector(7 DOWNTO 0);
	SIGNAL WR_F   : std_logic;
	SIGNAL WR_IER : std_logic;
	SIGNAL WR_D   : std_logic;
	SIGNAL WR_DML : std_logic_vector(1 DOWNTO 0);
	SIGNAL D16    : std_logic_vector(15 DOWNTO 0);
	SIGNAL BRC16x : std_logic; -- baud rate clock 
	
	SIGNAL ITR0   : std_logic;
	SIGNAL isITR1 : std_logic;
	SIGNAL sITR1  : std_logic;
	SIGNAL cITR1  : std_logic;
	SIGNAL cITR1a : std_logic;
	SIGNAL ITR1   : std_logic;
	SIGNAL ITR2   : std_logic;
	SIGNAL ITR3   : std_logic;
	
	SIGNAL DCTS     : std_logic;
	SIGNAL CTSn_RE  : std_logic;
	SIGNAL CTSn_FE  : std_logic;
	SIGNAL iDCTS    : std_logic;
	SIGNAL iLOOP    : std_logic;
	
	SIGNAL DDSR     : std_logic;
	SIGNAL DSRn_RE  : std_logic;
	SIGNAL DSRn_FE  : std_logic;
	SIGNAL iDDSR    : std_logic;

	SIGNAL TERI     : std_logic;
	SIGNAL RIn_RE   : std_logic;
		
	SIGNAL DDCD     : std_logic;
	SIGNAL DCDn_RE  : std_logic;
	SIGNAL DCDn_FE  : std_logic;
	SIGNAL iDDCD    : std_logic;

	SIGNAL RD_MSR   : std_logic;
	SIGNAL MSR_CLR  : std_logic;

	SIGNAL RD_LSR   : std_logic;
	SIGNAL LSR_CLR  : std_logic;
	
	SIGNAL num_bits  : integer:= 0;
	SIGNAL stopB     : std_logic;
	SIGNAL Parity_EN : std_logic;
	SIGNAL Parity_EV : std_logic;
	SIGNAL Break_CB  : std_logic;
	
	SIGNAL TF_RD    : std_logic;
	SIGNAL TF_CLR   : std_logic;
	SIGNAL TF_CLRS  : std_logic;
	SIGNAL TF_DO    : std_logic_vector(7 DOWNTO 0);
	SIGNAL TF_empty	: std_logic;
	SIGNAL TF_full  : std_logic;

	SIGNAL RF_WR     : std_logic;
	SIGNAL RF_RD     : std_logic;
	SIGNAL RF_RD_brs : std_logic; -- added 3 aug 2007
	SIGNAL RF_CLR    : std_logic;
	SIGNAL RF_CLRS   : std_logic;
	SIGNAL RF_DI     : std_logic_vector(10 DOWNTO 0); -- Read FIFO data input
	SIGNAL RF_DO     : std_logic_vector(10 DOWNTO 0); -- Read FIFO data output
	SIGNAL RF_empty  : std_logic;
	SIGNAL RF_full   : std_logic;
	SIGNAL RD_RDY    : std_logic;
	
	SIGNAL iParity_ER : std_logic; -- added 13 oct 2007
	SIGNAL iFRAME_ER  : std_logic; -- added 13 oct 2007
	SIGNAL iBreak_ITR : std_logic; -- added 13 oct 2007
	SIGNAL Parity_ER  : std_logic;
	SIGNAL FRAME_ER   : std_logic;
	SIGNAL Break_ITR  : std_logic;
	SIGNAL TSR_EMPTY  : std_logic;
	SIGNAL OVR_ER     : std_logic;
	SIGNAL isTX       : std_logic;
	SIGNAL isRX       : std_logic;
	
	SIGNAL q_full   : std_logic;
	SIGNAL h_full   : std_logic;
	SIGNAL a_full   : std_logic;
	
	SIGNAL RF_ER   : std_logic;
	SIGNAL TX_RDY  : std_logic;
	SIGNAL TX_RDYS : std_logic;
	SIGNAL TX_RDYC : std_logic;
	SIGNAL RX_RDY  : std_logic;
	SIGNAL RX_RDYS : std_logic;
	SIGNAL RX_RDYC : std_logic;

	SIGNAL TOI      : std_logic; -- time out interrupt 
	SIGNAL TOI_enc  : std_logic; -- time out interrupt counter inable
	SIGNAL iTOI_enc : std_logic;
	SIGNAL TOI_set  : std_logic;
	SIGNAL iTOI_set : std_logic; -- added 3 aug 2007
	SIGNAL TOI_clr  : std_logic;
	SIGNAL TOI_c_ld : std_logic;
	SIGNAL TOI_c_d  : std_logic_vector(11 DOWNTO 0);
	SIGNAL iTC      : std_logic;
	SIGNAL iQ       : std_logic_vector(9 DOWNTO 0);
	SIGNAL rst      : std_logic;
	
BEGIN

   -- Concurrent reset inversion
   rst <= NOT(CLR_n);
   
----------------------------------------------
---- resd   ----------------------------------
----------------------------------------------
RD_Data(7 DOWNTO 0) <= RF_DO(7 DOWNTO 0) WHEN (LCR(7) = '0') ELSE RDD(7 DOWNTO 0);-- 0
RD_Data(15 DOWNTO 8) <= (X"0" & IER) WHEN (LCR(7) = '0') ELSE RDD(15 DOWNTO 8);-- 1
RD_Data(23 DOWNTO 16) <= IIR;-- 2
RD_Data(31 DOWNTO 24) <= LCR;-- 3
RD_Data(39 DOWNTO 32) <= ("000" & MCR);-- 4
RD_Data(47 DOWNTO 40) <= LSR;-- 5
RD_Data(55 DOWNTO 48) <= MSR;-- 6
RD_Data(63 DOWNTO 56) <= SCR;-- 7
----------------------------------------------

----
----
u1: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		TX_RDY <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((TX_RDYS = '1') AND (TX_RDYC = '1')) THEN
			TX_RDY <= NOT TX_RDY;
		ELSIF (TX_RDYS = '1') THEN
			TX_RDY <= '1';
		ELSIF (TX_RDYC = '1') THEN
			TX_RDY <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
	TXRDYn <= (NOT TX_RDY);
		
	TX_RDYS <= '1' WHEN ((FCR(3) = '0') AND (TF_empty = '1') AND (TSR_EMPTY = '1')) ELSE
	           '1' WHEN ((FCR(3) = '1') AND (TF_empty = '1')) ELSE
	           '0';
	
	TX_RDYC <= '1' WHEN ((FCR(3) = '0') AND (TF_empty = '0')) ELSE
	           '1' WHEN ((FCR(3) = '1') AND (TF_full = '1')) ELSE
	           '0';
	
----
----
u2: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		RX_RDY <= '0';
	elsif (RISING_EDGE(gclk)) THEN 
		IF ((RX_RDYS = '1') AND (RX_RDYC = '1')) THEN
			RX_RDY <= NOT RX_RDY;
		ELSIF (RX_RDYS = '1') THEN
			RX_RDY <= '1';
		ELSIF (RX_RDYC = '1') THEN
			RX_RDY <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
		
	RXRDYn <= (NOT RX_RDY);
		
	RX_RDYS <= '1' WHEN ((FCR(3) = '0') AND (RF_empty = '0')) ELSE	-- mod 01/20/07
	           '1' WHEN ((FCR(3) = '1') AND (FCR(7 DOWNTO 6) = "11") AND (a_full = '1')) ELSE
	           '1' WHEN ((FCR(3) = '1') AND (FCR(7 DOWNTO 6) = "10") AND (h_full = '1')) ELSE
	           '1' WHEN ((FCR(3) = '1') AND (FCR(7 DOWNTO 6) = "01") AND (q_full = '1')) ELSE
	           '1' WHEN ((FCR(3) = '1') AND (FCR(7 DOWNTO 6) = "00") AND (RF_empty = '0')) ELSE
	           '0';
		
		
	RX_RDYC <= '1' WHEN (RF_empty = '1') ELSE '0';
		
		
----------------------------------------------
---- Modem Status Register Bits --------------
----------------------------------------------

U3 : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => CTSn,
		sre => CTSn_RE,
		sfe => CTSn_FE);
		
	iDCTS <= CTSn_RE OR CTSn_FE;
	
----
----
u4: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		DCTS <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((iDCTS = '1') AND (MSR_CLR = '1')) THEN
			DCTS <= NOT DCTS;
		ELSIF (iDCTS = '1') THEN
			DCTS <= '1';
		ELSIF (MSR_CLR = '1') THEN
			DCTS <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
	MSR(0) <= DCTS;

U5 : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => DSRn,
		sre => DSRn_RE,
		sfe => DSRn_FE);
		
	iDDSR <= DSRn_RE or DSRn_FE;

		
----
----
u6: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		DDSR <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((iDDSR = '1') AND (MSR_CLR = '1')) THEN
			DDSR <= NOT DDSR;
		ELSIF (iDDSR = '1') THEN
			DDSR <= '1';
		ELSIF (MSR_CLR = '1') THEN
			DDSR <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
	MSR(1) <= DDSR;

U7 : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => RIn,
		sre => RIn_RE);
		
	
----
----
u8: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		TERI <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((RIn_RE = '1') AND (MSR_CLR = '1')) THEN
			TERI <= NOT TERI;
		ELSIF (RIn_RE = '1') THEN
			TERI <= '1';
		ELSIF (MSR_CLR = '1') THEN
			TERI <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
	MSR(2) <= TERI;
	
U9 : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => DCDn,
		sre => DCDn_RE,
		sfe => DCDn_FE);
		
	iDDCD <= DCDn_RE OR DCDn_FE;
		
----
----
u10: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		DDCD <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((iDDCD = '1') AND (MSR_CLR = '1')) THEN
			DDCD <= NOT DDCD;
		ELSIF (iDDCD = '1') THEN
			DDCD <= '1';
		ELSIF (MSR_CLR = '1') THEN
			DDCD <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
MSR(3) <= DDCD;
	
iMSR(4) <= (NOT CTSn) WHEN (iLOOP = '0') ELSE MCR(1);
	
iMSR(5) <= (NOT DSRn) WHEN (iLOOP = '0') ELSE MCR(0);
	
iMSR(6) <= (NOT RIn) WHEN (iLOOP = '0') ELSE MCR(2);
	
iMSR(7) <= (NOT DCDn) WHEN (iLOOP = '0') ELSE MCR(3);
  
RD_MSR <= '0' WHEN ((CS = '0') OR (WR = '1')) ELSE '0' WHEN (BE(6) = '0') ELSE '1';


ITR0 <= '0' when (IER(3) = '0') ELSE '1' WHEN (MSR(3 DOWNTO 0) > x"0") ELSE '0';
			  
U11 : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => RD_MSR,
		sfe => MSR_CLR);
	
----
----
u12: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		 MSR(7 DOWNTO 4) <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		MSR(7 DOWNTO 4) <= iMSR;
	END IF;
END process;
----
----
		
---------------------------------------------------
-------- LSR --------------------------------------
---------------------------------------------------

LSR(0) <= (NOT RF_empty);
		
----
----
u13: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		LSR(1) <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((OVR_ER = '1') AND (LSR_CLR = '1')) THEN
			LSR(1) <= NOT LSR(1);
		ELSIF (OVR_ER = '1') THEN
			LSR(1) <= '1';
		ELSIF (LSR_CLR = '1') THEN
			LSR(1) <= '0';
		END IF;
	END IF;
END PROCESS;
----
----

	OVR_ER <= '1' WHEN ((RF_full = '1') AND (RF_WR = '1')) ELSE
	          '0';
			
----
----
u14: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		LSR(2) <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((PARITY_ER = '1') AND (LSR_CLR = '1')) THEN
			LSR(2) <= NOT LSR(2);
		ELSIF (PARITY_ER = '1') THEN
			LSR(2) <= '1';
		ELSIF (LSR_CLR = '1') THEN
			LSR(2) <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
----
----
u15: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		LSR(3) <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((FRAME_ER = '1') AND (LSR_CLR = '1')) THEN
			LSR(3) <= NOT LSR(3);
		ELSIF (FRAME_ER = '1') THEN
			LSR(3) <= '1';
		ELSIF (LSR_CLR = '1') THEN
			LSR(3) <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
	
----
----
u16: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		LSR(4) <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((Break_ITR = '1') AND (LSR_CLR = '1')) THEN
			LSR(4) <= NOT LSR(4);
		ELSIF (Break_ITR = '1') THEN
			LSR(4) <= '1';
		ELSIF (LSR_CLR = '1') THEN
			LSR(4) <= '0';
		END IF;
	END IF;
END PROCESS;
----
----

LSR(5) <= TF_EMPTY;
LSR(6) <= TF_EMPTY AND TSR_EMPTY;
	
----
----
u17: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		LSR(7) <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((RF_ER = '1') AND (LSR_CLR = '1')) THEN
			LSR(7) <= NOT LSR(7);
		ELSIF (RF_ER = '1') THEN
			LSR(7) <= '1';
		ELSIF (LSR_CLR = '1') THEN
			LSR(7) <= '0';
		END IF;
	END IF;
END PROCESS;
----
----

RF_ER <= '1' WHEN (RF_DI(10 DOWNTO 8) > "000") ELSE '0';
	
RD_LSR <= '0' WHEN ((CS = '0') or (WR = '1')) ELSE '0' WHEN (BE(5) = '0') ELSE '1';
	
U18 : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => RD_LSR,
		sfe => LSR_CLR);
		
----------------------------------------------
------  registers -------
----------------------------------------------

CSn <= (NOT CS);
	
----
----
-- Concurrent Address Decode, to be replaced
--WR_B <= x"00" WHEN (CSn = '1') ELSE
--        x"00" WHEN (WR = '0') ELSE
--        x"80" WHEN (ADD = o"7") ELSE
--        x"40" WHEN (ADD = o"6") ELSE
--        x"20" WHEN (ADD = o"5") ELSE
--        x"10" WHEN (ADD = o"4") ELSE
--        x"08" WHEN (ADD = o"3") ELSE
--        x"04" WHEN (ADD = o"2") ELSE
--        x"02" WHEN (ADD = o"1") ELSE
--        x"01";-- WHEN (A= o"0")
        
WR_B <= X"00" WHEN ((CSn = '1') OR (WR = '0')) ELSE BE;
----
----

WR_F <= (WR_B(0) AND NOT(LCR(7)));
WR_IER <= (WR_B(1) AND NOT(LCR(7)));
WR_D <= (LCR(7) AND (WR_B(0) OR WR_B(1)));
WR_DML <= ((WR_B(1) AND LCR(7)) & (WR_B(0) AND LCR(7)));
				
----
----
u20: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		IER <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		IF (WR_IER = '1') THEN -- BE(1)
			IER <= WR_Data(11 DOWNTO 8);-- D(3 DOWNTO 0);
		END IF;
	END IF;
END PROCESS;
----
----
				
----
----
u21: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		FCR <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		IF (WR_B(2) = '1') THEN -- BE(2)
			FCR <= WR_Data(23 DOWNTO 16);-- D;
		END IF;
	END IF;
END PROCESS;
----
----
			
----
----
u22: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		RF_CLR <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((RF_CLRS = '1') AND (RF_EMPTY = '1')) THEN
			RF_CLR <= NOT RF_CLR;
		ELSIF (RF_CLRS = '1') THEN
			RF_CLR <= '1';
		ELSIF (RF_EMPTY = '1') THEN
			RF_CLR <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
		
--RF_CLRS <= D(1) AND WR_B(2); -- BE(2)
RF_CLRS <= WR_Data(17) AND WR_B(2); -- BE(2)
			
----
----
u23: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		TF_CLR <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((TF_CLRS = '1') AND (TF_EMPTY = '1')) THEN
			TF_CLR <= NOT TF_CLR;
		ELSIF (TF_CLRS = '1') THEN
			TF_CLR <= '1';
		ELSIF (TF_EMPTY = '1') THEN
			TF_CLR <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
		
--TF_CLRS <= D(2) AND WR_B(2); -- BE(2)
TF_CLRS <= WR_Data(18) AND WR_B(2); -- BE(2)
		
		
----
----
u24: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		LCR <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		IF (WR_B(3) = '1') THEN -- BE(3)
			LCR <= WR_Data(31 DOWNTO 24);
		END IF;
	END IF;
END PROCESS;
----
----	
	
	num_bits <= 5 WHEN ((LCR(0) = '0') AND (LCR(1) = '0')) ELSE
	            6 WHEN ((LCR(0) = '1') AND (LCR(1) = '0')) ELSE	 -- 07/12/07
	            7 WHEN ((LCR(0) = '0') AND (LCR(1) = '1')) ELSE	 -- 07/12/07
	            8;				   

stopB <= LCR(2);
	
Parity_EN <= LCR(3);
Parity_EV <= LCR(3) AND LCR(4) AND (NOT LCR(5)); 
Break_CB <= LCR(6);
				
----
----
u25: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		MCR <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		IF (WR_B(4) = '1') THEN -- BE(4)
			MCR <= WR_Data(36 DOWNTO 32);
		END IF;
	END IF;
END PROCESS;
----
----	

	DTRn <= (NOT MCR(0)) OR iLOOP;
	RTSn <= (NOT MCR(1)) OR iLOOP;
	OUT1n <= (NOT MCR(2)) OR iLOOP;
	OUT2n <= (NOT MCR(3)) OR iLOOP;
  	iLOOP <= MCR(4);   
	  
		
----
----
u26: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		SCR <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		IF (WR_B(7) = '1') THEN -- BE(7)
			SCR <= WR_Data(63 DOWNTO 56);
		END IF;
	END IF;
END PROCESS;
----
----	

----------------------------------------------------------
		
	--D16 <= D & D;
    D16 <= WR_Data(15 DOWNTO 0);

		
u27 : UART_Baud_Rate_GEN
	PORT MAP(
		clk => GCLK,  
		BR_clk => BRCLK, 
		rst  => rst, 
		WR => WR_D,
		BE => WR_DML,
		D => D16,
		RD => RDD,
		rCE => BRC16x,
		rCLK => BCLK
		);		
	
--------------------------------------------------
---- trans FIFO   12/23/06 -----------------------
--------------------------------------------------

U28 : UART_FIFO_async_16_SR
	Generic Map(data_width => 8)
	PORT MAP (
		clk_WR => GCLK,
		clk_RD => BRCLK,
		rst => rst,
		srst => TF_CLR,
		WR => WR_F, -- BE(0)
		RD => TF_RD,
		D => WR_Data(7 DOWNTO 0),
		Q => TF_DO,
		empty => TF_empty,
		full => TF_full);

----------------------------------------------------------------
----------- added 03/18/06 -------------------------------------
-----------  mod 10/12/07 --------------------------------------

U28a : UART_Edge_Det  
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => isITR1,
		sre => sITR1);
		
isITR1 <= TF_empty AND IER(1);
	
---------- end mod 10/12/07 -----------------
	
	RD_IIR <= '0' WHEN (BE(2) = '0') ELSE
	          '0' WHEN (WR = '1') ELSE
	          '0' WHEN (CS = '0') ELSE
	          '0' WHEN (IIR(3 DOWNTO 1) /= "001") ELSE -- walter hogan 12/12/2006
	          '1';

U28b : UART_Edge_Det  
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => RD_IIR,
		sfe => cITR1a);
		
cITR1 <= cITR1a OR (NOT TF_empty);
			
----
----
u28c: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		ITR1 <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((sITR1 = '1') AND (cITR1 = '1')) THEN
			ITR1 <= NOT ITR1;
		ELSIF (sITR1 = '1') THEN
			ITR1 <= '1';
		ELSIF (cITR1 = '1') THEN
			ITR1 <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
		
----------- added 03/18/06 ------------------------------------------
---------------------------------------------------------------------

U29 : UART_TX_8_Bit 
	PORT MAP (
		clk => BRCLK,
		rst => rst,
		xBRC => BRC16x,
		D_RYn => TF_empty,
		D => TF_DO,
		num_bits => num_bits,
		Break_CB => Break_CB,
		StopB => stopB,
		Parity_EN => Parity_EN,
		Parity_EV => Parity_EV,
		sTX => isTX,
		BUSYn => TSR_EMPTY,
		read => TF_RD);

sTX <= isTX;
		
--------------------------------------------------
---- Receive FIFO ----------------------------------
--------------------------------------------------

U30 : UART_Edge_Det 
	PORT MAP (
		clk => BRCLK,
		rst => rst,
		d => RD_RDY,
		re => RF_WR);
		
	RF_RD <= '0' WHEN (LCR(7) = '1') ELSE -- added 04/19/06
	         '1' WHEN ((BE(0) = '1') AND (CS = '1') AND (WR = '0')) ELSE
	         '0';
		
U31 : UART_FIFO_async_16_RCSR_WF -- 01/20/07
	Generic Map(data_width => 11)
	PORT MAP (
		clk_WR => BRCLK,
		clk_RD => GCLK,
		rst => rst,
		rc_srst => RF_CLR,
		WR => RF_WR,
		RD => RF_RD,
		D => RF_DI,
		Q => RF_DO,
		empty => RF_empty,
		q_full => q_full,
		h_full => h_full,
		a_full => a_full,
		full => RF_full);

------------ 10/12/07 --------------------------------------
----- as suggested  Matthias Klemm -------------------------
----- mod 10/13/07 -----------------------------------------

iParity_ER <= RF_DO(8) AND (NOT RF_RD);

U32a : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => iParity_ER,
		sre => Parity_ER);
		
	iFRAME_ER <= RF_DO(9) AND (NOT RF_RD);
		
U32b : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => iFRAME_ER,
		sre => FRAME_ER);
		
	iBreak_ITR <= RF_DO(10) AND (NOT RF_RD);
		
U32c : UART_Edge_Det 
	PORT MAP (
		clk => GCLK,
		rst => rst,
		d => iBreak_ITR,
		sre => Break_ITR);
	
	ITR3 <= '0' WHEN (IER(2) = '0') ELSE
	        '1' WHEN (LSR(1) = '1') ELSE
	        '1' WHEN (LSR(4 DOWNTO 2) > "000") ELSE
	        '0';

-----------------------------------------------------------------------

			
isRX <= sRX WHEN (iLOOP = '0') ELSE isTX;


	ITR2 <= '0' WHEN (IER(0) = '0') ELSE  -- mod 01/20/07
	        '1' WHEN ((FCR(7 DOWNTO 6) = "11") AND (a_full = '1')) ELSE
	        '1' WHEN ((FCR(7 DOWNTO 6) = "10") AND (h_full = '1')) ELSE
	        '1' WHEN ((FCR(7 DOWNTO 6) = "01") AND (q_full = '1')) ELSE
	        '1' WHEN ((FCR(7 DOWNTO 6) = "00") AND(RF_empty = '0')) ELSE
	        '0';
 
U33 : UART_RX_8_Bit 
	PORT MAP (
		clk => BRCLK,
		rst => rst,
		BRCx16 => BRC16x,
		sRX => isRX,
		num_bits => num_bits,
		Parity_EN => Parity_EN,
		Parity_EV => Parity_EV,
		Parity_ER => RF_DI(8),
		FRAME_ER => RF_DI(9),
		Break_ITR => RF_DI(10),
		D_RDY => RD_RDY,
		D => RF_DI(7 DOWNTO 0)
		);

----------------------------------------------------------------
---------- added 04/08/06 time out interrupt -------------------
---------- once there a received data word is recieved, --------
---------- the counter will be running until -------------------
---------- FIFO is empty, counter reset on FIFO read or write --
------- mod 3 aug 2007

	TOI_clr <= RF_empty OR RF_RD OR (NOT IER(0)); 
		
----
----
u34: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		TOI <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((TOI_set = '1') AND (TOI_clr = '1')) THEN
			TOI <= NOT TOI;
		ELSIF (TOI_set = '1') THEN
			TOI <= '1';
		ELSIF (TOI_clr = '1') THEN
			TOI <= '0';
		END IF;
	END IF;
END PROCESS;
----
----
		
----
----
u35: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		iTOI_enc <= '0';
	ELSIF (rising_edge(GCLK)) THEN 
		IF ((LSR(0) = '1') AND (RF_empty = '1')) THEN
			iTOI_enc <= NOT iTOI_enc;
		ELSIF (LSR(0) = '1') THEN -- enable time out counter with received data
			iTOI_enc <= '1';
		ELSIF (RF_empty = '1') THEN
			iTOI_enc <= '0';-- once FIFO is empty, stop counter
		END IF;
	END IF;
END PROCESS;
----
----
		
U35a : UART_Edge_Det_XCD 
	PORT MAP (
		iclk => GCLK,
		oclk => BRCLK,
		rst => rst,
		d => RF_RD,
		re => RF_RD_brs,
		fe => OPEN);
		
PROCESS(BRCLK,rst)
BEGIN
	IF (rst = '1') THEN
		TOI_enc <= '0';
	ELSIF (rising_edge(BRCLK)) THEN
		TOI_enc <= iTOI_enc;
	END IF;
END PROCESS;

	TOI_c_ld <= '1' WHEN (IER(0) = '0') ELSE -- added 4 aug 2007
	            '1' WHEN (TOI_enc = '0') ELSE
	            '1' WHEN (RF_RD_brs = '1') ELSE
	            '1' WHEN (RF_WR = '1') ELSE 
	            '0';

----
----
u36_1: PROCESS(BRCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		iTC <= '0';
	ELSIF (rising_edge(BRCLK)) THEN
		IF (TOI_c_ld = '1') THEN
			IF (TOI_c_d(9 DOWNTO 0) = x"0") THEN
				iTC <= '1';
			ELSE
				iTC <= '0';
			END IF;
		ELSIF (BRC16x = '0') THEN  -- LOAD = '0'
				IF (iQ = x"0") THEN
					iTC <= '1';
				ELSE
					iTC <= '0';
				END IF;
		ELSE -- (CE = '1')	
			IF (iQ = x"1") THEN
				iTC <= '1';
			ELSE
				iTC <= '0';
			END IF;
		END IF;			
	END IF;
END PROCESS;

-- Concurrent
iTOI_set <= (iTC AND BRC16x);

u36_2: PROCESS(BRCLK,rst)
BEGIN
	IF (rst = '1') THEN 
		iQ <= (OTHERS => '0');
	ELSIF (rising_edge(BRCLK)) THEN
		IF (TOI_c_ld = '1') THEN 
			iQ <= TOI_c_d(9 DOWNTO 0);
		ELSIF (BRC16x = '1') THEN
			iQ <= (iQ - "01");
		END IF;			
	END IF;
END PROCESS;
----
----

U36a : UART_Edge_Det_XCD 
	PORT MAP (
		iclk => BRCLK,
		oclk => GCLK,
		rst => rst,
		d => iTOI_set,
		re => TOI_set,
		fe => OPEN);

		
	TOI_c_d <= x"1C0" WHEN (num_bits = 5) ELSE
	           x"200" WHEN (num_bits = 6) ELSE
	           x"240" WHEN (num_bits = 7) ELSE
	           x"280";-- WHEN (num_bits = 8)

--------------------------------------------------------------
--------------------------------------------------------------

IRQ <= '1' WHEN ((ITR3 OR ITR2 OR TOI OR ITR1 OR ITR0) = '1') ELSE '0';
		   
iIIR(0) <= '0' WHEN ((ITR3 OR ITR2 OR TOI OR ITR1 OR ITR0) = '1') ELSE '1';
			  
	iIIR(3 DOWNTO 1) <= "011" WHEN (ITR3 = '1') ELSE
	                    "010" WHEN (ITR2 = '1') ELSE
	                    "110" WHEN (TOI  = '1') ELSE	-- added 04/08/06	
	                    "001" WHEN (ITR1 = '1') ELSE
	                    "000";
			  
IIR(7 DOWNTO 4) <= x"C"; -- FIFO's always enabled

		
----
----
u37: PROCESS(GCLK,rst)
BEGIN
	IF (rst = '1') THEN
		IIR(3 DOWNTO 0) <= (OTHERS =>'0');
	ELSIF (rising_edge (GCLK)) THEN
		IF (CSn = '1') THEN
			IIR(3 DOWNTO 0) <= iIIR;
		END IF;
	END IF;
END PROCESS;
----
----

--------------------------------------------------------------

END Universal;
