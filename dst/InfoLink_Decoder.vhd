--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
-- 	30.06.2008-le : merge pci2 and \libraries\indel\infoMaster
--------------------------------------------------------------------------------
--	17.12.2015-le : add C_NO_FIBRE_DESKEW to disable invert input and deskew of 
--						h pulse
--					add C_CONTINUOUS_BITCLK for a continuos output of o_BitClk
--------------------------------------------------------------------------------
--$Rev:: 3871                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2015-12-17 14:32:14 +0100 (Do., 17 Dez 2015)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity InfoLink_Decoder is   
	generic ( 
		C_CLK_DIV_22MHZ : integer :=4;	 --88MHz
		C_NO_FIBRE_DESKEW : integer range 0 to 1 :=0;	 -- 0-> invert input and deskew of h pulse
		C_CONTINUOUS_BITCLK : integer range 0 to 1 :=0
	);
	port (     
		-- std-ports
		i_Clk	: in std_logic;                 -- clock 
		i_Rst	: in std_logic;                 -- reset
		-- info-link-ports 
		-- LINK
		i_RX		: in std_logic;				-- info-link input
		-- codec
		o_RXd		: out std_logic;			-- RX-data output decoded	
		o_RErr		: out std_logic;			-- RX-Error  
		o_Paus		: out std_logic; 			-- Pause      
		o_BitClk    : out std_logic;			-- RXCnt(x);    
		o_LiErr		: out std_logic;            -- dignosis link-error
		i_clrLiErr	: in  std_logic;
		o_bc1		: out std_logic;
		o_bc2		: out std_logic
	);
end InfoLink_Decoder;

architecture behavioral_ildec of InfoLink_Decoder is
	constant H 		: std_logic := '1';
	constant L 		: std_logic := '0';
	constant Z 		: std_logic := 'Z';   
	
    constant MID	: integer := C_CLK_DIV_22MHZ +1;
    constant LAST	: integer := C_CLK_DIV_22MHZ*2;    
    constant C_PCNT	: std_logic_vector(4 downto 0) := CONV_STD_LOGIC_VECTOR((C_CLK_DIV_22MHZ*5),5);

	signal RXCnt    : std_logic_vector(LAST downto 1) := (others => L);             
	signal RQq  	: std_logic := L;
	signal RQold 	: std_logic := L;
	signal RXq  	: std_logic := L;
	signal RXa		: std_logic := L;
	signal RXb		: std_logic := L;
	signal RXr		: std_logic := L;
	signal Paus		: std_logic := H;
	signal RErr		: std_logic := L;
	signal PCnt		: std_logic_vector(4 downto 0) := (others => L); 
	-- funktioniert bis i_clk 132MHz, also C_CLK_DIV_22MHZ = 6
	-- bei 66Mhz würden 4 bit reichen    
	signal LiErr	: std_logic := L;

begin    
	-- readable output   
	o_RErr		<= RErr;                                     
	o_Paus		<= Paus;
	nocontclkout : if C_CONTINUOUS_BITCLK=0 generate
		o_BitClk	<= RXCnt(LAST-1);
	end generate nocontclkout;
	contclkout: if C_CONTINUOUS_BITCLK=1 generate
		o_BitClk	<= RXCnt(MID);
	end generate contclkout;
	o_LiErr		<= LiErr; 
	o_RXd		<= RXr;

	o_bc1 <= RXCnt(1);       
	o_bc2 <= RXCnt(MID);       

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
--------------------------------------------------------------------------------
	ClkGen : process(i_Clk, i_Rst)
	begin    
		if i_Rst = H then
			RXCnt <= (others => '0');
		elsif rising_edge(i_Clk) then 
			if (C_CONTINUOUS_BITCLK=0) then
				if (Paus=H) then                 		
					RXCnt(1) <= not(RXq);			-- start
				else
					RXCnt(1) <= RXCnt(LAST) and not RErr;		-- close the loop
				end if;
				RXCnt(LAST downto 2) <= RXCnt(LAST-1 downto 1);
			elsif (C_CONTINUOUS_BITCLK=1) then
				if (Paus=H and RXq=L) then
					RXCnt(LAST downto 2) <= (others => L);
					RXCnt(1) <= H;
				else
					RXCnt(LAST downto 1) <= RXCnt(LAST-1 downto 1) & RXCnt(LAST);
				end if;
			end if;
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
			RQq		<= L;
			RQold	<= L;
			RXq		<= L;
			RXa		<= L;
			RXb		<= L;
			RXr		<= L;
			Paus	<= H;
			RErr	<= L;
			PCnt	<= (others => '0');      
		elsif rising_edge(i_Clk) then             
			-- Optical-Data Syncher --------------------------------------------
			RQq 	<= i_RX;								-- Synch with i_Clk
			RQold 	<= RQq;
			if (C_NO_FIBRE_DESKEW=0) then -- add infolink fibre and receiver deskew
				RXq 	<= not(RQq and RQold);					-- Synch with i_Clk
			else
				RXq <= RQq;
			end if;
			-- decoder ---------------------------------------------------------
			-- RXa: 
			if 		(RXCnt(1)=H) then 	RXa <= RXq;			-- set on start
			end if;
			-- RXb:   
			if    	(Paus=H) then 		RXb <= H;			-- no StartError!
			elsif 	(RXCnt(MID)=H) then RXb <= RXq;			-- set on MID
			end if;
	    	-- RXr:
	        if	  	(Paus=H) then 		
	        	RXr	<= L;									-- no StartError!							
			elsif 	(RXCnt(MID)=H) then 
				RXr <= RXq xor RXa;	-- Decoded Data Inp  
			end if;                   
			-- Pausen Finder ---------------------------------------------------
			-- PCnt:
			--if (RXq=H) and (Paus=L) and (RErr=H) then PCnt <= (PCnt-1);	-- zählt 'Licht' 
			if (RXq=H) and (Paus=L) then PCnt <= (PCnt+1);	-- zählt 'Licht' 
			else PCnt <= (others => L);
	        end if; 
			-- Paus:				
			if (PCnt=C_PCNT) then Paus <= H;					-- set after 2,5 InfoClk  
			else Paus <= (Paus and RXq);                    -- hold
			end if; 
			-- Error-Erkennung -------------------------------------------------
	        -- RErr:
			RErr <= (RXCnt(MID) and not(RXr) and RXb and RXa and RXq)					-- ------------
				 or (RXCnt(MID) and not(RXr) and not(RXb) and not(RXa) and not(RXq))	-- ____________
				 or (RXCnt(MID) and  RXr and  RXb and not(RXa))					  		-- ___---___   
				 or (RXCnt(MID) and  RXr and not(RXb) and RXa)	  						-- ---___---   
				 or (RErr and not(Paus))												-- Hold till Pause 
				 or (RErr and Paus and RXq);											-- Hold till NewStart    
		end if;
	end process; 											-- decoder
	----------------------------------------------------------------------------
	--		Info-Link Blitz-Einschlag Erkennung				; 02.07.2000-FB
	----------------------------------------------------------------------------
	-- genaue Funktion siehe Indel Knowledge-Base
	process (i_Clk, i_Rst) begin 
		if i_Rst = H then
			LiErr <= L;  
		elsif rising_edge(i_Clk) then
			-- LiErr:	    
			if    (RErr=H)  and (RXCNT(LAST downto MID+1)=0) and (Paus=L) and (RXq=L) then 
				LiErr <= H;	--that is it
            elsif i_clrLiErr=H then 
            	LiErr <= L;
            end if;
		end if;	                        	
	end process;
--------------------------------------------------------------------------------
end behavioral_ildec;