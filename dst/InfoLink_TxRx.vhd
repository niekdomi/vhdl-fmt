--******************************************************************************
--
--  INFO-Link Tx/Rx	Sequencer
--
--******************************************************************************
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;   

----------------------------------------------------------------------------
-- revision information
------------------------------------------------------------------------------
--	Rev. 1.00	;   03.06.2003-FB :		from SAM-2 , as TxRx Module
--------------------------------------------------------------------------------
--	Rev. 1.10	;   19.09.2003-FB :		checked and OK with SAM-2 and PCI-2
--
--	full Q66 synchron design	
--  all FlipFlops with global-reset
--
--------------------------------------------------------------------------------
--	Rev. 1.11	;   19.03.2004-le :		change TNr reset from run to ReSt 
--										(same as RNr reset)      
--					05.05.2004-le :     change some async-resets to synch resets
--------------------------------------------------------------------------------
--	Rev. 2.00	;	17.11.2004-le :		change designe to a rx and tx stage-
--										machine. remove encoder and decoder to
--										modules.	
--------------------------------------------------------------------------------
--	Rev. 2.10	;	17.02.2005-le :		rename i_Reg_Sta internal to 
--										RxCirqEnFlag <= i_Reg_Sta(4);
--										RestartFlag <= i_Reg_Sta(5);
--										RunFlag <= i_Reg_Sta(6);
--										OverRunFlag <= i_Reg_Sta(7);	
--										---
--										error on pci2: first loop get overrun ->
--										Reset(), and reset stop link before last
--										tel. arrives
--										-> change rx-stage-machine
-------------------------------------------------------------------------------- 
--	26.07.2006-le:						add some dbg outputs
--										add M5first as Restart synch Stage
--										 for info-pci2 rev. 1.6
-------------------------------------------------------------------------------- 
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
-- 	30.06.2008-le : merge pci2 and \libraries\indel\infoMaster
--------------------------------------------------------------------------------
-- 	30.06.2008-le : (info-pci2 Rev. 1.7)
--	new sender TOTX195A make infolink errors at the end of protocol (45ns short 
--	puls modulation error) in conjunction with nois.
--	errorcounter incremet, but errrors are not visible in diagnostics! 
--	change protocol:
--	1. add a stopbit ('0') after parity to avoid short puls modulation error.
--		- after '0', only long modulation error will be generated.
--		- slaves generate TrOk at parity ok and send a additional '0' too. they 
--		  ignore error modulation for protocol checking 
--	2. remove errordedection at the end of protocol 
--------------------------------------------------------------------------------
--	17.01.2012-FB	NewPause 
--	Neues InfoLink Timing für Hassia (Diagnose auch bei mehr als 30 Slaves)
--	Mit der letzten Änderung (+1 NullStopBit) wurde die Pause zu kurz und die
--	Diagnose funktionierte nicht mehr zuverlässig. Daher wird speziell für
--	Hassia ein neues Timing eingeführt:
--
--	- NopJobs mit Adr 7FBx und FFBx mit einstellbarer ExtraPause 
--		Data(15)   => NewPause	(1 = einschalten, 0 = ausschalten)
--		Data(7..0) = Anzahl ExtraPausen Bits 
--
--	Wenn NewPause = H then --> 
--	- alle 16Bit Jobs statt  5 neu 6 Pause-bit (neu 44Bits = 4.0909 us)
--	- alle 32Bit Jobs statt 11 neu 6 Pause-bit (neu 62Bits = 5.6363 us) 
--
--	Vorsicht:
--	---------
--	Wenn NewPause erst mal eingeschaltet ist, bleibt es eingeschaltet,
--	auch wenn ein anderes System geladen wird! Nur noch PowerOff hilft?
--------------------------------------------------------------------------------
--	22.04.2014-le 	correct short error pulse (from NewPause)
--					shift pause back to tx_state 56
--------------------------------------------------------------------------------
--$Rev:: 3350                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2014-04-28 10:34:56 +0200 (Mo., 28 Apr 2014)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
----- defines ------------------------------------------------------------------
--------------------------------------------------------------------------------
entity InfoLink_TxRx is					 
	port (
		i_Q66		: 	In		std_logic;						-- 66MHz									  						
		i_Reset		: 	In		std_logic;						-- nReset
					  			
		i_Tx_Dat	:	In		std_logic_vector(15 downto 0);	-- D15.0 Inp Reg
		o_Rx_Dat	:	Out		std_logic_vector(15 downto 0);	-- D15.0 Out Reg

		o_LEDrec	: 	Out		std_logic;							
		i_WDOGin	: 	In		std_logic;						
		o_WDOGout	: 	Out		std_logic;						

		o_CIRQ		: 	Out		std_logic;						
		o_Or1ms		: 	Out		std_logic;
		
--------------------------------------------------------------------------------
--	Transmitter
--	Receiver
--------------------------------------------------------------------------------
		i_RX		: 	In		std_logic;						-- Rec Input
		o_TX		: 	Out		std_logic;						-- Trans-Output

------- Sequenzer ctrl ---------------------------------------------------------
		o_RUN		:	Out		std_logic;						-- Sequenzer running
		o_ReSt		:	Out		std_logic;						-- Sequenzer ReStart
		i_Reg_Sta	:	In		std_logic_vector( 7 downto 0);
		i_Reg_IOP	:	In		std_logic_vector( 7 downto 0);
		i_Tgo_en	:	In		std_logic;						-- short nResetPuls
		i_Trst		:	In		std_logic;						-- short nResetPuls
		
		o_Error		:	Out		std_logic;						-- Transfer Error
		o_Ovrun		:	Out		std_logic;						-- Over-Run 1,2

------- Transmit Data Request --------------------------------------------------
		o_Treq		:	Out		std_logic_vector(1 downto 0);
		i_Tack		:	In		std_logic;

------- Receiver Data Request --------------------------------------------------
		o_Rreq		:	Out		std_logic_vector(1 downto 0);
		i_Rack		:	In		std_logic;
		
		dbg_o_RErr  :	out		std_logic;
		dbg_o_RXr   :	out		std_logic;
        dbg_o_RNr   :	out		std_logic;
        dbg_o_ReStart : out 	std_logic;
        dbg_o_M5old :	out		std_logic;
		
		dbg_o_pause: out 	std_logic;
		dbg_o_TXErr :	out		std_logic
		
--------------------------------------------------------------------------------
		);   

end;
	  
architecture behavior  of InfoLink_TxRx is

--------------------------------------------------------------------------------
-- components
--------------------------------------------------------------------------------
	component InfoLink_Encoder 
	generic ( 
		C_CLK_DIV_22MHZ : integer :=3	 	-- 66MHz
	);
	port (     
		-- std-ports
		i_Clk		: in 	std_logic;		-- clock 
		i_Rst		: in 	std_logic;		-- reset
		-- info-link-ports 
		-- LINK
		o_TX		: out 	std_logic;		-- info-link output 
		-- encoder                    			
		i_TXd		: in 	std_logic;		-- TX-data input decoded  
		i_Pause		: in 	std_logic;      -- H: don't send (TX=H)
		i_TXErr		: in	std_logic;		-- H: generate modulations errors
		o_BitClk	: out 	std_logic		-- __-_____-_____-			
	);
	end component;
	
	component InfoLink_Decoder 
	generic ( 
		C_CLK_DIV_22MHZ : integer :=3	 	--66MHz
	);
	port (     
		-- std-ports
		i_Clk	: in std_logic;             -- clock 
		i_Rst	: in std_logic;             -- reset
		-- info-link-ports 
		-- LINK
		i_RX		: in std_logic;			-- info-link input
		-- codec
		o_RXd		: out std_logic;		-- RX-data output decoded	
		o_RErr		: out std_logic;		-- RX-Error  
		o_Paus		: out std_logic; 		-- Pause      
		o_BitClk    : out std_logic;		-- RXCnt(x);    
		o_LiErr		: out std_logic;        -- dignosis link-error
		i_clrLiErr	: in  std_logic
	);
	end component;
--------------------------------------------------------------------------------
--	Constants
--------------------------------------------------------------------------------
	constant	H	:	std_logic := '1';
	constant	L	:	std_logic := '0';
	constant	Tadr:	std_logic_vector := "01";
	constant	Tdal:	std_logic_vector := "10";
	constant	Tdah:	std_logic_vector := "11";
	constant	Radr:	std_logic_vector := "01";
	constant	Rdal:	std_logic_vector := "10";
	constant	Rdah:	std_logic_vector := "11";
          
--------------------------------------------------------------------------------
	
	signal nLEDrec	: std_logic := L;
	signal M5first    : std_logic := L;
	signal M5old    : std_logic := L;
	signal M5older  : std_logic := L;
	signal ReStart	: std_logic := L; 
	signal Or1ms 	: std_logic := L;
	signal Ovrun 	: std_logic := L;
	signal Run   	: std_logic := L;  
	signal WDOGout	: std_logic := L;
	signal Dout_Cdis: std_logic := L;	
	
	signal Tx_Dat	: std_logic_vector(i_Tx_Dat'range) 	:= (others => L);
	signal TSr		: std_logic_vector(i_Tx_Dat'range) 	:= (others => L); 
	signal tx_state	: integer range 0 to 127 := 0;
	signal TXr		: std_logic := L;
	signal pause	: std_logic := L;
	signal TXErr	: std_logic := L;
	signal TXBitClk	: std_logic := L;
	
	signal TXp		: std_logic := L;
	signal TNr		: std_logic := L;
	signal T32Bit	: std_logic := L; 	                                                                    
	signal TCard	: std_logic := L;  
	
	signal Tgo		: std_logic := L; 
	signal V		: std_logic_vector(3 downto 0)		:= (others => L);
	signal T1us		: std_logic := L;  
	
	signal RSr		: std_logic_vector(o_Rx_Dat'high+1 downto 0):= (others => L); 
	signal rx_state	: integer range 0 to 63 := 0;
	signal RXr		: std_logic := L;
	signal nRX		: std_logic := L;
	signal RPaus	: std_logic := L;
	signal RErr		: std_logic := L;
	signal RXBitClk	: std_logic := L;
	
	signal RXp		: std_logic := L;
	signal RNr		: std_logic := L;
	signal R32Bit	: std_logic := L; 	                                                                    
	signal RCard	: std_logic := L; 
	signal LiErr	: std_logic := L; 
	signal clrLiErr	: std_logic := L;
	signal TrOk		: std_logic := L;
	signal error	: std_logic := L;
	signal RxCIRQ	: std_logic := L;  
	
	signal Rreq	: std_logic_vector(1 downto 0)			:= (others => L);
	signal Treq	: std_logic_vector(1 downto 0)			:= (others => L);
	
	signal RestartHold : std_logic := L;
	
	-- i_Reg_Sta bits
	signal RxCirqEnFlag	: std_logic := L;
	signal RestartFlag	: std_logic := L;
	signal RunFlag		: std_logic := L;
	signal OverRunFlag	: std_logic := L;

--------------------------------------------------------------------------------
--	17.01.2012-FB	NewPause for Hassia-Timing
--	- alle 16Bit Jobs statt  5 neu 6 Pause-bit (neu 44Bits = 4.0909 us)
--	- alle 32Bit Jobs statt 11 neu 6 Pause-bit (neu 62Bits = 5.6363 us) 
--	- NopJops mit Adr 7FBx und FFBx mit einstellbarer ExtraPause 
--		Data(15)   => NewPause	(1 = einschalten, 0 = ausschalten)
--		Data(7..0) = Anzahl ExtraPausen Bits	 
	signal NewPause		: std_logic := L; 		-- 1=Ein / 0=Aus
	signal chkExtraPause: std_logic := L;		-- Flag bis Daten kommen
	signal ExtraPause	: std_logic_vector(7 downto 0)			:= (others => L);
--------------------------------------------------------------------------------
	                                                           
BEGIN
	o_LEDrec    <= not nLEDrec; 
	o_Rreq		<= Rreq; 
	o_Treq		<= Treq;
	--o_ReSt   	<= ReStart;
	o_Or1ms     <= Or1ms;  
	o_Ovrun     <= Ovrun;  
	o_Run       <= Run;    
	o_WDOGout   <= WDOGout;
	o_Error		<= error;

	RxCirqEnFlag <= i_Reg_Sta(4);
	RestartFlag <= i_Reg_Sta(5);
	RunFlag <= i_Reg_Sta(6);
	OverRunFlag <= i_Reg_Sta(7);
   
	
	dbg_o_RErr  <= RErr;
	dbg_o_RXr   <= RXr; 
	dbg_o_RNr   <= RNr;     	
	dbg_o_ReStart <= ReStart;
	dbg_o_M5old <= M5old;

	dbg_o_pause <= pause;
	dbg_o_TXErr <= TXErr;
--------------------------------------------------------------------------------
--	InfoLink Error	
--------------------------------------------------------------------------------
	process (i_Reset,i_Q66)	
	begin
		if (i_Reset = H) then
			nLEDrec <= H;
		elsif rising_edge(i_Q66) then
			nLEDrec <= ( i_WDOGin											-- löscht bei Wdog
					   or (not LiErr and i_Reg_IOP(4) and not i_Reg_IOP(5))	-- blinkt normal  
					   or (	   LiErr and i_Reg_IOP(4) and	 i_Reg_IOP(5)));-- blinkt invers  
		end if;			
	end process;

--------------------------------------------------------------------------------			
--		i_Reset Sequenzer
--------------------------------------------------------------------------------			
-- Bei Status wechsel von 00->20 gibt es einen kurzen ni_Reset-Puls an Sequenzer
-- (da pM5 asyn, könnte ReSt auch schief gehen !? 961214-FB)
-- CLK war früher CTTL, NS-Synchron; pM5-Write wird auch mit i_Q66/Q33 gemacht
-- Sicherheitshalber M5older eingeführt!

	process(i_Reset,i_Q66)
	begin
		if (i_Reset = H) then
			M5first	<= L;
			M5old  	<= L;
			M5older <= L;
		elsif rising_edge(i_Q66) then
			M5first	<= RestartFlag;
			M5old	<= M5first;									-- pM5 old
			M5older <= M5old;									-- pM5 older
		end if;
	end process;	
	ReStart <= (M5old and not M5older);					-- ReStart PULS Rec/Tra
--------------------------------------------------------------------------------			
--		Transmitter RUN CTRL
--------------------------------------------------------------------------------			
-- Findet kein Or1ms-dis innerhalb der ms statt, wird der naechste
-- Transfer gesperrt! (WDog-AUS auf allen Karten)

	process(i_Reset,i_Q66)
	begin
		if (i_Reset = H) then
			Or1ms <= L;
			Ovrun <= L;
			Run   <= L;
		elsif rising_edge(i_Q66) then
			Or1ms <= (i_Trst and OverRunFlag)				-- first Trans
					 or (Or1ms and OverRunFlag);			-- hold

			Ovrun  <= (i_Trst and Or1ms and RunFlag)		-- 2 Trans -> RunEnd
					  or (Ovrun and RunFlag);				-- hold
																				
			Run   <= (not Ovrun and RunFlag and not error)	-- Run if no Error
					 or (Run and not i_Trst and RunFlag);	-- Run till 1ms-End

		end if;
	end process;	

--------------------------------------------------------------------------------
--		Transmitter
--------------------------------------------------------------------------------
--				   1		 2		   3		 4		   5		 6
--	   00012345678901234567890123456789012345678901234567890123456789
-- Start_-___
-- go   __-------------------------------------------------------___
-- end  ________________________________________________________-
--
--		  SiiiN0TTEaaaaAAAAcIssDDDDddddDDDDddddPe
--16-Bit  SiiiN0TTEaaaaAAAAcIss--------------->DDDDddddDDDDddddPe
--32-Bit  SiiiN1TTEaaaaAAAAcIssDDDDddddDDDDddddDDDDddddDDDDddddPe
-- 
	il_enc : InfoLink_Encoder 
	generic map( 
		C_CLK_DIV_22MHZ => 3	 			-- 66MHz
	)
	port map (     
		i_Clk		=> i_Q66	,-- clock 
		i_Rst		=> i_Reset	,-- reset
		o_TX		=> o_TX		,-- info-link output                  			
		i_TXd		=> TXr		,-- TX-data input decoded  
		i_Pause		=> pause	,-- H: don't send (TX=H)
		i_TXErr		=> TXErr	,-- H: generate modulations errors
		o_BitClk	=> TXBitClk	 -- __-_____-_____-			
	);  
	
	
	--pause <= H when tx_state=0 or tx_state>56 else L;
	
    TXErr <= H when tx_state=56 else L;
	get_TX_DATA : process(i_Reset,i_Q66)
	begin
    	if (i_Reset = H) then
    		Treq <= "00"; 
			TNr	 <= L;   
			Treq <= Tadr;
			tx_state <= 0;
			NewPause 		<= L;
			chkExtraPause 	<= L;
			ExtraPause 		<= x"00";			
		elsif rising_edge(i_Q66) then 
			if (TXBitClk=H) then
				-- when nothing else  
				TXp <= TXp xor TXr; 
				TXr <=	TSr(TSr'high); 
				TSr <= (TSr(TSr'high-1 downto 0) & "0");-- shift and fill with 0
				tx_state<= tx_state + 1;
				case tx_state is 
					when 0 =>                   -- idle
					    pause <= H;
						TXr		<= L;		    
						--if (T1us=H and i_Tgo_en=H and Ovrun=L) then -- start
--						if (T1us=H and Run=H) then -- start sync@T1us
						if (Run=H) then
						    pause <= L;			-- start modulated Tx
							tx_state <= tx_state + 1;
						else
							tx_state <= 0;	
						end if;
					when 1 =>                   -- StartBit
						TXr		<= L;    
					when 2 =>                   -- TestLinkError Bit
						TXr		<= i_Reg_IOP(4); 
					when 3 =>                   -- TestLinkBlink Bit
						TXr		<= i_Reg_IOP(5);
					when 4 =>                   -- Tel-Nr.
						TXr		<= TNr;  
						TNr 	<= not TNr;		-- toggle  
						-- dpr request
						if (Tx_Dat(15)=H) then 	-- 32bit high word   
							Treq <= Tdah;
						else                    -- 16bit low word
							Treq <= Tdal;
						end if;      
						-- load shiftregister
						TSr 	<= Tx_Dat;		-- save tx addr to sr 
						-- store some flags
						T32Bit	<= Tx_Dat(15);  -- save 16/32bit transpher 
						TCard	<= Tx_Dat(3);   -- save odd/even P. (cardok) 
						if (Tx_Dat(15 downto 4) = x"7FB") 
						or (Tx_Dat(15 downto 4) = x"FFB") then 
							chkExtraPause <= H;
						else
							chkExtraPause <= L;
						end if;
						
					when 5 => 
						TXp 	<= L;           -- reset 						
					when 18 =>
						if (T32Bit=L) then		-- skip if 16-Bit Job
							tx_state <= (tx_state + 17);
						else 
							tx_state <= (tx_state + 1);
						end if;
					when 20 =>                  -- load req. tx data   
						-- dpr request
						if (T32Bit=H) then		-- 32bit low word 
							Treq <= Tdal;
						end if; 
						-- load shiftregister
						TSr <= Tx_Dat;          -- save tx data to sr
					when 36 =>                	-- load req. tx addr 
					  	-- dpr request
					  	Treq <= Tadr;  
					  	-- load shiftregister
					  	TSr <= Tx_Dat;          -- save tx data to sr   
						if (chkExtraPause = H) then
							NewPause   <= Tx_Dat(15);
							ExtraPause <= Tx_Dat(7 downto 0);						
						else	
							ExtraPause <= x"00";						
						end if;
					when 53 =>                  -- Partity
						if (TCard=H) then			
			            	TXr	<=  TXp xor TXr;         -- Partity
			            else
			            	TXr	<= not ( TXp xor TXr);   -- Partity Invers
			            end if;
			        when 54 =>	-- ER1 
			        when 55 =>	-- NullStopBit 
			        when 56 =>	-- Pause 1
						pause <= H;  
			        when 57 => 	-- Pause 2 
			        when 58 => 	-- Pause 3 
			        	-- if NewPause: do the programmable ExtraPause 
			        	if  (NewPause = H) 
			        	and (ExtraPause > 0) then
			        		ExtraPause <= ExtraPause - 1;
			        	    tx_state <= tx_state; 
			        	end if;
			        	
			        when 59 => 	-- Pause 4
			        	-- if NewPause: do one PausBit more
			        	if  (NewPause = L) 
			        	and (T32Bit=L) then 
				        	tx_state <= 0;	-- Idle = Pause-5          
				        end if;	

			        when 60 => 	-- Pause 5 
			        	-- if NewPause: do 32Bit Jobs with 6 PausBits only
			        	if (NewPause = H) then 
				        	tx_state <= 0;	-- Idle = Pause-6          
				        end if;	
			        when 61 => 	-- Pause 6
			        when 62 => 	-- Pause 7
			        when 63 => 	-- Pause 8
			        when 64 => 	-- Pause 9
			        when 65 => 	-- Pause 10
			        	--if (NewPause = L) and (T32Bit=H) then 
				        	tx_state<= 0;	-- Idle = Pause-11          
    					--end if;

			        when 96 => 	
			        	

					when others =>
				end case; 
			end if;
			if (ReStart=H) then					-- restart
				Treq <= "00"; 
				TNr	 <= L;   
				Treq <= Tadr;
				tx_state<= 0;
			elsif (i_Tack=H) then				-- done
				Tx_Dat <= i_Tx_Dat;				-- save data
				Treq <= "00";                   -- clear request
			--elsif (Run=H and i_Tgo_en=L) then-- Start-Request (ni_Reset)
			--	Treq <= Tadr;
			end if;	  
		end if;
	end process;  
--------------------------------------------------------------------------------
--		1us Timer
--------------------------------------------------------------------------------
--	wird seit NewPause nicht mehr benötigt...
--	process(i_Reset,i_Q66)
--	begin
--		if (i_Reset = H) then
--			V <= (others => L);
--		elsif rising_edge(i_Q66) then 
--			if (TXBitClk=H) then							  	-- == Q11
--				if (V < 10) then
--					V <= V + 1;								-- 0..10 <= 11/11=1us
--				else
--					V <=(others => L);
--				end if;	
--			end if;
--		end if;
--	end process;	
--
--	T1us <= V(3) and V(1);
--
--------------------------------------------------------------------------------
--
--		Receiver 
--
--------------------------------------------------------------------------------
--		Rec DP-RAM Request's
--------------------------------------------------------------------------------
	il_dec : InfoLink_Decoder 
	generic map ( 
		C_CLK_DIV_22MHZ => 3	 	--66MHz
	)
	port map(     
		i_Clk		=> i_Q66	,-- clock 
		i_Rst		=> i_Reset	,-- reset
		i_RX		=> nRX		,-- info-link input
		o_RXd		=> RXr		,-- RX-data output decoded	
		o_RErr		=> RErr		,-- RX-Error  
		o_Paus		=> RPaus	,-- Pause      
		o_BitClk    => RXBitClk	,-- RXCnt(x);    
		o_LiErr		=> LiErr	,-- dignosis link-error
		i_clrLiErr	=> clrLiErr							
	);
    clrLiErr 	<= not i_Reg_IOP(4);
    nRX		<= not i_RX;
	process(i_Reset,i_Q66)
	begin
		if (i_Reset = H) then
			RestartHold <= H;
			Error 	<= L; 
			RNr		<= L; 
			Rreq 	<= "00";  
			rx_state<= 0;
			TrOK <= L;
			o_ReSt <= L; 
			R32Bit <= L;
			RCard <= L;
			RxCIRQ <= L;
			RNr <= L;
		elsif rising_edge(i_Q66) then
			TrOK <= L;
			o_ReSt <= L; 
			if (RXBitClk=H) then 
				if (RErr=H) then                             
					Error <= H;                              
				end if;                                      
				RXp <= RXp xor RXr;
				RSr(0) <= RXr;										-- Data Inp
				RSr(RSr'high downto 1) <= RSr(RSr'high-1 downto 0);	-- Shift 
				rx_state <= (rx_state+1);	-- state cnt.
				case rx_state is 
					when 4 =>
						if (RXr/=RNr) then
							Error <= H;
						end if;
						RXp <= L; -- reset
					when 5 =>
						R32Bit	<= RXr;
					when 17 =>
						RCard	<= RXr;
					when 18 =>
						RxCIRQ	<= RXr;	
					when 20 =>
						if R32Bit=L then
							rx_state <= (rx_state+17);	-- 16-Bit, Skip
						else
							rx_state <= (rx_state+1);	-- 32-Bit, go one..
						end if;		
					when 21 =>
						if (Error=L) then
							Rreq <= Radr;	
						end if;				
					when 37 =>
						if (Error=L) then
							if (R32Bit=L) then
								Rreq <= Radr; 
							else
								if (RCard=H) then
									Rreq <= Rdah;
								end if;
							end if;
						end if;
					when 53 =>
						if (RCard=H) then
							if (RXr=RXp) then
								TrOK	<= H;
								RNr		<= not RNr; 
								if (Error=L) then 
									Rreq <= Rdal;
								end if;
							else
								Error	<= H;
							end if;
						else
							if (RXr/=RXp) then
								TrOK	<= H;
								RNr		<= not RNr;
							else
								Error	<= H;
							end if;
						end if;  
					when 54 =>
						rx_state <= 54;
						Error <= Error;                   
					when others =>
				end case; 	
			end if;
			-- dpr acknowledgement  
			if (i_Rack=H) then							-- done
				Rreq 	<= "00";  
			end if;
			-- state reset
			if (RPaus=H) then
				rx_state<= 0;
			end if;  
			--  
			-------------------------------------------------------------------
			-- error on pci2: first loop get overrun -> Reset(), and reset stop
			-- link before last tel. arrives
			-------------------------------------------------------------------
			--	if (ReStart=H) then							-- ReStart PULS Rec/Tra 
			--		Error 	<= L; 
			--		RNr		<= L; 
			--		Rreq 	<= "00";  
			--		rx_state<= 0;
			--	elsif (Error=L and RunFlag=L) then		-- hold till RUN 
			--		Error 	<= L; 
			--		rx_state<= 0;
			--	end if; 
			if (ReStart=H) then							-- ReStart PULS Rec/Tra 
				RestartHold <= H;
			elsif (RestartHold = H and RunFlag=H) then		-- 
				o_ReSt <= H; 
				RestartHold <= L;
				Error 	<= L; 
				RNr		<= L; 
				Rreq 	<= "00";  
				rx_state<= 0;
			elsif (RestartHold = H and RunFlag=L) then 
				Error 	<= L;	-- hold till RUN	
			end if;
		end if;
	end process;	
									
--------------------------------------------------------------------------------
--		Card-IRQ
--------------------------------------------------------------------------------
	process(i_Reset,i_Q66)
	begin
		if (i_Reset = H) then 
			o_CIRQ <= L;	  
		elsif rising_edge(i_Q66) then  
			if (RxCirqEnFlag=H) then
				if (RxCIRQ=H and TrOK=H) then 
					o_CIRQ <= H;
				end if;
		   	else
		   		o_CIRQ <= L;
		   	end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--		WatchDog
--------------------------------------------------------------------------------
	process(i_Reset,i_Q66)
	begin
		if (i_Reset = H) then 
			WDOGout <= L;	  
		elsif rising_edge(i_Q66) then
			--if (rx_state>=16) then
			--	WDOGout <= H; 			-- Daten kommen
			--elsif (RErr=H)	then
			--	WDOGout <= WDOGout; 
		   	--else
		   	--	WDOGout <= L;
		   	--end if;
		   	if (TrOK=H)	then
				--WDOGout <= WDOGout;
				WDOGout <= H; 			-- Daten kommen 
		   	else
		   		WDOGout <= L;
		   	end if;
		end if;
	end process;
    o_WDOGout <= WDOGout;
	
--------------------------------------------------------------------------------
--		Rec-Data to DP-Ram
--------------------------------------------------------------------------------
	process(i_Reset,i_Q66) begin
		if i_Reset = H then
			o_Rx_Dat <= (others => L);
			Dout_Cdis <= L;	
		elsif rising_edge(i_Q66) then
			if not (Rreq = "00") then   					-- _+- Rc4
				Dout_Cdis <= H;
				if (Dout_Cdis=L) then                       -- _+- Rc5
					o_Rx_Dat <= RSr(RSr'high downto RSr'high-o_Rx_Dat'high);						-- Latch Data	
				end if;
			else
				Dout_Cdis <= L;	
			end if;		
		end if;
	end process;	
--------------------------------------------------------------------------------

end;

