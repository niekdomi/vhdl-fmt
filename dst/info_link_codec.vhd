--------------------------------------------------------------------------------
--
--  INFO-LINK CODEC
--
--------------------------------------------------------------------------------
--
--  project     : INFO-LINK
--  programmer  : C. Leuthold, INDEL AG
--  date        : 10.09.2003
--  version     : 1.00
--  language    : VHDL
--  system      : ISE 5.2e
--
--  purpose
--
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 04.09.2006-le:	add o_BitClk180 (RXCnt(MID)) 
-- 18.09.2006-le:	change TRok to a single pulse (one i_Clk)
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity info_link_codec is   
	generic ( 
		C_CLK_DIV_22MHZ : integer :=4	 --88MHz
	);
	port (     
		-- std-ports
		i_Clk	: in std_logic;                 -- clock 
		i_Rst	: in std_logic;                 -- reset
		-- info-link-ports 
		-- LINK
		i_RX		: in std_logic;				-- info-link input
		o_TX		: out std_logic;			-- info-link output 
		-- codec
		o_RXd		: out std_logic;			-- RX-data output decoded	
		i_TXd		: in std_logic;				-- TX-data input decoded  
		o_RErr		: out std_logic;			-- RX-Error  
		o_Paus		: out std_logic; 			-- Pause      
		o_BitClk    : out std_logic;			-- RXCnt(LAST);
		o_BitClk180 : out std_logic;			-- RXCnt(MID);
		i_BitCnt	: in std_logic_vector(5 downto 0); -- from sequenzer
		o_TXp		: out std_logic;           	-- TX parity        
		o_LiErr		: out std_logic;            -- dignosis link-error
		o_TrOK		: out std_logic;            -- end of transfer, prity ok
		i_MCOK		: in std_logic;              -- bit CardOk was set from 
												-- master -> odd parity 
		o_RQq		: out std_logic;										
		o_RXq		: out std_logic								
	);
end info_link_codec;

architecture behavioral_ilc of info_link_codec is
	constant H 		: std_logic := '1';
	constant L 		: std_logic := '0';
	constant Z 		: std_logic := 'Z';   
	
    constant MID	: integer := C_CLK_DIV_22MHZ +1;
    constant LAST	: integer := C_CLK_DIV_22MHZ*2;    
    constant C_PCNT	: std_logic_vector(4 downto 0) := CONV_STD_LOGIC_VECTOR((C_CLK_DIV_22MHZ*5),5);

	signal RXCnt    : std_logic_vector(LAST downto 1);
	signal Stop		: std_logic;              
	signal RQq  	: std_logic;
	signal RQold 	: std_logic;
	signal RXq  	: std_logic;
	signal RXa		: std_logic;
	signal RXb		: std_logic;
	signal RXr		: std_logic;
	signal RXp		: std_logic;
	signal Paus		: std_logic;
	signal RErr		: std_logic;
	signal PCnt		: std_logic_vector(4 downto 0); 
	-- funktioniert bis i_clk 132MHz, also C_CLK_DIV_22MHZ = 6
	-- bei 66Mhz würden 4 bit reichen   
	signal TXold	: std_logic;      
	signal TXp		: std_logic;       
	signal TX		: std_logic;  
	signal LiErr	: std_logic;
	signal TrOK		: std_logic;   
	signal TXStart	: std_logic;   
begin    
	-- readable output   
	o_TX		<= Tx;  
	o_RErr		<= RErr;                                     
	o_Paus		<= Paus;
	o_BitClk	<= RXCnt(LAST);
	o_BitClk180 <= RXCnt(MID);
	o_TXp		<= TXp;         
	o_LiErr		<= LiErr; 
	o_TrOK		<= TrOK;
	o_RXd		<= RXr; 
	
	o_RQq 		<= RQq;
	o_RXq		<= RXq;

--------------------------------------------------------------------------------
-- RXClkGen   
--------------------------------------------------------------------------------
-- 			  001234561234561234560     (LAST = 6)     
-- RXCnt	1 __-_____-_____-______                              
--			2 ___-_____-_____-_____                              
--			3 ____-_____-_____-____                              
--	MID		4 _____-_____-_____-___   
--			5 ______-_____-_____-__   
--			6 _______-_____-_____-_   
-- Paus      ---_________
-- RXq       --_xxxxxxxxx   new way.. one loop more after RErr until 0 
-- RErr		 ---__________---------   
-- Stop      ___________________--_                   
--------------------------------------------------------------------------------
	ClkGen : process(i_Clk, i_Rst)
	begin    
		if i_Rst = H then
			RXCnt <= (others => '0');
			Stop <= L; 
		elsif rising_edge(i_Clk) then                  		
			if (RErr=H and RXCnt(MID)=H) then    
				Stop <= H;                           	-- set
			elsif RXCnt(LAST)=H then 
				Stop <= L;                      		-- reset
			else 
				Stop <= Stop;							-- hold
			end if;	   
			RXCnt(1) <= (Paus and not(RXq))				-- start
					 or (RXCnt(LAST) and not(Stop));	-- close the loop
			RXCnt(LAST downto 2) <= RXCnt(LAST-1 downto 1); 				
		end if;          
	end process; 								--RXClkGen                                    
--------------------------------------------------------------------------------
-- input synch and decode
--------------------------------------------------------------------------------
--		1 0 1 1 0 0 1 0
-- i_RX	_----__---___---

--RQq	_----__---___--- 						i_RX synch
--RQold	__----__---___---
--RXq	___---___--____-    
-- Decodierung ------------------------------------------------------------
--RX	------_x__x_-x--x-__
--RXq   -------_x__x_-x--x-__
--RPaus --------_______________
--RStart________-_________
--RcMid ___________-_____-_____
--Rc1   ________-_____-_____
--
--		 0000000123456123456     
--------------------------------------------------------------------------------	   
	decoder : process(i_Clk, i_Rst)
	begin 
		if i_Rst = H then                                	-- init values
			RXp 	<= L;
			RQq		<= L;
			RQold	<= L;
			RXq		<= L;
			RXa		<= L;
			RXb		<= L;
			RXr		<= L;
			Paus	<= L;
			RErr	<= L;
			PCnt	<= (others => '0');      
		elsif rising_edge(i_Clk) then             
			-- Optical-Data Syncher --------------------------------------------
			RQq 	<= i_RX;								-- Synch with i_Clk
			RQold 	<= RQq;
			RXq 	<= not(RQq and RQold);					-- Synch with i_Clk 
			-- decoder ---------------------------------------------------------
			-- RXa: 
			if 		(RXCnt(1)=H) then 	RXa <= RXq;			-- set on start
			--else                 		RXa <= RXa;			-- hold  
			end if;
			-- RXb:   
			if    	(Paus=H) then 		RXb <= H;			-- no StartError!
			elsif 	(RXCnt(MID)=H) then RXb <= RXq;			-- set on MID
			--else 						RXb <= RXb;			-- hold
			end if;
	    	-- RXr:
	        if	  	(Paus=H) then 		
	        	RXr	<= L;									-- no StartError!							
			elsif 	(RXCnt(MID)=H) then 
				RXr <= RXq xor RXa;	-- Decoded Data Inp  
			end if;                   
			-- Pausen Finder ---------------------------------------------------
			-- PCnt:
			if (RXq=H) and (Paus=L) and (RErr=H) then PCnt <= (PCnt-1);	-- zählt 'Licht' 
			else PCnt <= C_PCNT;
	        end if; 
			-- Paus:				
			if (PCnt=0) then Paus <= H;					-- set after 2,5 InfoClk  
			else Paus <= (Paus and RXq);                    -- hold
			end if; 
			-- Error-Erkennung -------------------------------------------------
	        -- RErr:
			RErr <= (RXCnt(MID) and not(RXr) and RXb and RXa and RXq)					-- ------------
				 or (RXCnt(MID) and not(RXr) and not(RXb) and not(RXa) and not(RXq))	-- ____________
				 or (RXCnt(MID) and  RXr and  RXb and not(RXa))					  	-- ___---___   
				 or (RXCnt(MID) and  RXr and not(RXb) and RXa)	  					-- ---___---   
				 or (RErr and not(Paus))											-- Hold till Pause 
				 or (RErr and Paus and RXq);										-- Hold till NewStart  
			-- parity ----------------------------------------------------------    
			-- RXp:
			if RXCnt(LAST)=H then								-- set		 
				if (i_BitCnt>=5) then RXp <= RXr xor RXp;	-- Build Inp-Parity
				else RXp <= L;  
				end if;  
			else RXp <= RXp;								-- hold	
			end if;    
		end if;
	end process; 											-- decoder
--------------------------------------------------------------------------------
-- Serial Sdatput Data
--------------------------------------------------------------------------------
	coder : process (i_Clk, i_Rst) begin 
		if (i_Rst = H) then									-- init values
			TXold <= L;                     
			TXp <= L;
			TX	<= L;  
			TXStart <= L;
		elsif rising_edge(i_Clk) then
			if RXCnt(LAST)=H then									
				TXold <= i_TXd;								-- Old Data Inp   
			end if;
			-- Sdat-Parity -----------------------------------------------------
			-- TXp: 
			if (RXCNT(MID)=H) then
				if (i_BitCnt>5) then
					TXp <=  (i_TXd and not(TXp))			-- Build Sdat-Parity
				         or (not(i_TXd) and TXp);   
				else 
					TXp <= L;								-- clear on start 
				end if;
			end if;
			-- Delay Mark Modulation -------------------------------------------
			-- TX:
			-- new way.. without TXCnt 
			if (RXCnt(MID)=H  or Paus=H) then
				TXStart <= not(Paus); 	
			end if;       
			if (RXCnt=0 or TXStart=L) then
				TX <= H;  										-- Pause = LICHT !  
			elsif RXCnt(1)=H then
				if (RErr=L) then  
					TX <= (TX and i_TXd)						--1 vorne keine Pegeländ
					   or (TX and not(i_TXd) and TXold)	    	--0auf1 = keine Pegeländ
					   or (not(TX) and not(i_TXd) and not(TXold));--0auf0 = vorne Pegeländ   
				else  											-- Error Generator
				    TX <= (TX and not(TXold))					--1  Falsches 0 auf 0
					   or (not(TX) and TXold);					--2  Falsches 0 auf 1    
				end if; 
			elsif RXCnt(MID)=H then
				if (RErr=L) then 
					TX <= (TX and not(i_TXd))					--0	= keine Pegeländ
					   or (not(TX) and i_TXd); 					--1	= mitte Pegeländ
				else											-- Error Generator
					TX <= TX;                                   -- Hold falsches 0
				end if;
			else
				TX <= TX;
			end if; 	  	 	
		end if; 
	end process;                 							-- coder   
	----------------------------------------------------------------------------
	--		Info-Link Blitz-Einschlag Erkennung				; 02.07.2000-FB
	----------------------------------------------------------------------------
	-- genaue Funktion siehe Indel Knowledge-Base
	process (i_Clk, i_Rst) begin 
		if i_Rst = H then
			LiErr <= L;  
		elsif rising_edge(i_Clk) then
			-- LiErr:	    
			if    (RErr=H)  and (RXCNT(LAST downto MID+1)=0) and (Paus=L) and (RXq=L) then LiErr <= H;	--that is it
			elsif (LiErr=H) and (RXCNT(MID+1)=L)  then LiErr <= H;											-- hold till new-bit
			elsif (LiErr=H) and (i_BitCnt/=2)    then LiErr <= H;											-- hold till TestLinkErr
            elsif (LiErr=H) and (RXCNT(MID+1)=H) and (i_BitCnt=2) and (RXr=H) then LiErr <= H;					-- hold till clear
            else LiErr <= L;
            end if;
		end if;	                        	
	end process;
	----------------------------------------------------------------------------
	-- Transfer OK  => WatchDog reset 
	----------------------------------------------------------------------------
	process (i_Clk, i_Rst) begin 
		if i_Rst = H then
			TrOK <= L;  
		elsif rising_edge(i_Clk) then								
			-- TrOK:
			if 	  (i_BitCnt=53) and (RXr =RXp) and (i_MCOK=H) and (RXCNT(LAST)=H) then TrOK <= H;-- CardOK = 0     
			elsif (i_BitCnt=53) and (RXr/=RXp) and (i_MCOK=L) and (RXCNT(LAST)=H) then TrOK <= H;-- CardOK = 1     
--			elsif (TrOK=H) and RXCNT(MID)=L                              then TrOK <= H; 
			else	TrOk <= L;
			end if; 
		end if;	                        	
	end process;
--------------------------------------------------------------------------------
end behavioral_ilc;