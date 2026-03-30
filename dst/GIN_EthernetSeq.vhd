---------------------------------------------------------------------------
--
--  GIN-Link	Main Sequencer
--
---------------------------------------------------------------------------
--
--  project     : GIN_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- Decode every Ethernet-Frame and test if GIN-Link Frame 
--
---------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--	12.12.2011-le - add i_fwNbw for dynamic change Src/Dest test
--	06.09.2016-le	support ginlink diagnostic
--------------------------------------------------------------------------------
--$Rev:: 4032                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-09-06 15:13:58 +0200 (Di., 06 Sep 2016)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library gin_link;
use gin_link.ALL;

-- synopsys translate_off
--Library UNISIM;
--use UNISIM.Vcomponents.all;
-- synopsys translate_on

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   21.05.2004-FB	erste Version
---------------------------------------------------------------------------

entity GIN_RxEthSeq is 
	generic (
		i_MyMac 	: IN  std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_00";				
		i_fw		: IN  std_logic := '1'			-- check MAX,UDP src/dest
	);
	port (
		i_Q62_5		: IN  std_logic;
		i_RxCharIsK : IN  std_logic_vector( 1 downto 0);
		i_RxData 	: IN  std_logic_vector(15 downto 0);
		o_EthCRC	: OUT std_logic_vector(31 downto 0);
		i_fwNbw 	: IN  std_logic := i_fw;
		o_CrcRun	: OUT std_logic;
		o_CrcClr	: OUT std_logic;
		o_CrcError	: OUT std_logic;
		o_EthError	: OUT std_logic;				-- EthFraming Error 
		o_EthRun	: OUT std_logic;
		o_GinRun	: OUT std_logic;
		o_sUdpCsum	: OUT std_logic;
		o_EthCnt	: out std_logic_vector(11 downto 0)
    );
end;    

architecture impl of GIN_RxEthSeq is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
    type sGS_MainSeq is (
    	sIdle,
    	sDestChkMac1,sSrcChkMac1,sChkMac2,sChkMac3,
    	sChkIP,sChkUDP,
    	sfwChkUdpPortSrc,sfwChkUdpPortDest,sbwChkUdpPortSrc,sbwChkUdpPortDest,
    	sSavUdpCnt,sChkUdpCsum,sWend,sEthCRC1,sEthCRC2,sErrEnd
    );

	signal GS_MainSeq	: sGS_MainSeq := sIdle;		
	signal EthCnt		: std_logic_vector(11 downto 0) := x"000";		
	signal UdpCnt		: std_logic_vector(11 downto 0) := x"000";		
	signal EthError		: std_logic := L;
	signal EthRun		: std_logic := L;
	signal GinRun		: std_logic := L;
	signal sUdpCsum		: std_logic := L;

--------------------------------------------------------------------------------
--	Components
--------------------------------------------------------------------------------
	
	signal nbrRxCRC32	: std_logic_vector (31 downto 0) := x"00000000";
	signal nbrRxCRC32_1 : std_logic_vector (31 downto 0) := x"00000000";

	signal RxCRC_Equ_L : std_logic := L;
	signal RxCRC_Equ_H : std_logic := L;
	signal RxCRC_Equ_H_1 : std_logic := L;
	signal CrcError : std_logic := L;

   	signal	CRCinp		: std_logic_vector (15 downto 0) := x"0000"; 
	signal 	CrcClr		: std_logic := '0';
	signal 	CrcRun	 	: std_logic := '0';

--	offsets/values in GIN-Frame ------------------------------------------------	
    constant Eth_Start    		: integer := 3;
    constant MAC_Dest_OFS 		: integer := 4;
    constant MAC_Src_OFS 		: integer := 7;
    
    constant ETHER_TYPE_OFS 	: integer := 10;
    constant ETHER_TYPE_IP 		: std_logic_vector := x"0800";
    
    constant PROTOCOL_OFS 		: integer := 15;
    constant PROTOCOL_UDP 		: std_logic_vector := x"11";
    
    constant UDP_SRC_PORT_OFS 	: integer := 21;
    constant fwUDP_SRC_PORT 		: std_logic_vector := x"1964";
    constant bwUDP_SRC_PORT 		: std_logic_vector := x"1957";
    
    constant UDP_DEST_PORT_OFS 	: integer := 22;
    constant fwUDP_DEST_PORT 		: std_logic_vector := x"1957";
    constant bwUDP_DEST_PORT 		: std_logic_vector := x"1964";

--------------------------------------------------------------------------------	
begin -- of architecture GS_MainSeq    
--------------------------------------------------------------------------------

--	outputs --------------------------------------------------------------------
    o_EthRun 	<= EthRun;
    o_GinRun 	<= GinRun;
    o_sUdpCsum 	<= sUdpCsum; 
    o_EthCRC 	<= nbrRxCRC32; 
   	o_CrcRun    <= CrcRun;
   	o_CrcClr    <= CrcClr;   	
   	o_EthError  <= EthError;
	o_CrcError	<= CrcError;
	
	o_EthCnt <= EthCnt;
   	
--------------------------------------------------------------------------------
--	GS_MainSequencer
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
    	
   		    sUdpCsum <= L;
   		    UdpCnt <= x"000";
			EthCnt <= x"000";    		
			EthError <= L;
           	CrcClr <= L;

    		if  ( not((GS_MainSeq = sIdle) OR (GS_MainSeq = sErrEnd))
    		and ( not(i_RxCharIsK = "00"))) then
				GS_MainSeq <= sErrEnd;
    		else
    			EthCnt <= EthCnt + 1;
    		    
                if (EthCnt = Eth_Start) then 
	    			CrcRun <= H;
				end if;
	    		case (GS_MainSeq) is 

	    		
				when sIdle =>	---	Idle, wait to PktStart ---------------------
	            	GinRun <= L;
	            	EthRun <= L;
	            	CrcClr <= H;
	            	CrcRun <= L;
		    		if ((i_RxData = x"5555") 
		    		and (i_RxCharIsK = "00")) then
						if (i_fwNbw = H) then
			    			GS_MainSeq <= sDestChkMac1;
			    		else   
			    			GS_MainSeq <= sSrcChkMac1;
			    		end if;	
		    			EthRun <= H;
		    		else	
						EthCnt <= x"000";    		
		    			EthRun <= L;
		    		end if;	
		    					   
		    					    			
				when sDestChkMac1 =>	---	test if Mac = GinMac -------------------
	                if (EthCnt >= MAC_Dest_OFS) then
	                	-- 00_04 
			            if (i_RxData = i_MyMac(47 downto 32)) then
			    			GS_MainSeq <= sChkMac2;
			    		else   
			    			GS_MainSeq <= sIdle;
			    		end if;	 
			    	end if;	


				when sSrcChkMac1 =>	---	test if Mac = GinMac -------------------
	                if (EthCnt >= MAC_Src_OFS) then 
			            if (i_RxData = i_MyMac(47 downto 32)) then
			    			GS_MainSeq <= sChkMac2;
			    		else   
			    			GS_MainSeq <= sIdle;
			    		end if;	 
			    	end if;	


				when sChkMac2 =>	---	test if Mac = GinMac -------------------
					-- 3d_fb
		            if (i_RxData = i_MyMac(31 downto 16)) then
		    			GS_MainSeq <= sChkMac3;
		    		else   
		    			GS_MainSeq <= sIdle;
		    		end if;	 
		    		
				when sChkMac3 =>	---	test if Mac = GinMac -------------------
					-- fb_xx
		            if (i_RxData(15 downto 8) = i_MyMac(15 downto 8)) then
		    			GS_MainSeq <= sChkIP;
		    		else   
		    			GS_MainSeq <= sIdle;
		    		end if;	 
	    		
                        
                        
				when sChkIP =>	---	test if IP Frame ---------------------------
	                if (EthCnt >= ETHER_TYPE_OFS) then 
			            if (i_RxData = ETHER_TYPE_IP) then
			    			GS_MainSeq <= sChkUDP;
			    		else   
			    			GS_MainSeq <= sErrEnd;
			    		end if;	 
			    	end if;	
		    		
				when sChkUDP =>	--- test if UDP protocol -----------------------
	                if (EthCnt >= PROTOCOL_OFS) then
	                	if (i_RxData(7 downto 0) = PROTOCOL_UDP) then
							-- change Src/Dest test ?
							if (i_fwNbw = H) then
				    			GS_MainSeq <= sfwChkUdpPortSrc;
					    	else   
				    			GS_MainSeq <= sbwChkUdpPortSrc;
					    	end if;	
			    		else   
			    			GS_MainSeq <= sErrEnd;
			    		end if;	
			    	end if;	
	                	      	                	      	                	      
				when sfwChkUdpPortSrc =>	--- test if SrcPort = 1964 -------------
	                if (EthCnt >= UDP_SRC_PORT_OFS) then
		                if (i_RxData = fwUDP_SRC_PORT) then
			    			GS_MainSeq <= sfwChkUdpPortDest;
			    		else   
			    			GS_MainSeq <= sErrEnd;
				    	end if;	
		    		end if;	
	                	
				when sfwChkUdpPortDest =>	--- test if DestPort = 1957 ------------
	                if (i_RxData = fwUDP_DEST_PORT) then
		    			GS_MainSeq <= sSavUdpCnt;
		    		else   
		    			GS_MainSeq <= sErrEnd;
		    		end if;	
	                	
				when sbwChkUdpPortSrc =>	--- test if SrcPort = 1964 ------------
	                if (EthCnt >= UDP_SRC_PORT_OFS) then
		                if (i_RxData = bwUDP_SRC_PORT) then
			    			GS_MainSeq <= sbwChkUdpPortDest;
			    		else   
			    			GS_MainSeq <= sErrEnd;
			    		end if;	
		    		end if;	

				when sbwChkUdpPortDest =>	--- test if DestPort = 1957 -------------
	                if (i_RxData = bwUDP_DEST_PORT) then
		    			GS_MainSeq <= sSavUdpCnt;
		    		else   
		    			GS_MainSeq <= sErrEnd;
			    	end if;	
	                	
	                	  
				when sSavUdpCnt =>	--- save UDP-Length ------------------------
	                UdpCnt <= i_RxData(11 downto 0);
	                sUdpCsum <= H;
	    			GS_MainSeq <= sChkUdpCsum;
	                	
				when sChkUdpCsum =>	--- skip UDP-CSUM --------------------------
					-- we don't check the CSUM !
	                UdpCnt <= UdpCnt - 10;				-- -UDP-HeaderLenght - first  
	    			GinRun <= H;
	    			GS_MainSeq <= sWend;
	                	
				when sWend =>	--- Wait til UDP-End ---------------------------
	                UdpCnt <= UdpCnt - 2;
	                if (UdpCnt = 0) then
	                	GinRun <= L;
	    				GS_MainSeq <= sEthCRC1;
--	            		CrcRun <= L;
	    			end if;
    				
				when sEthCRC1 =>	--- Ethernet CRC1 ---------------------------
    				GS_MainSeq <= sEthCRC2;

				when sEthCRC2 =>	--- Ethernet CRC2 ---------------------------
-- in idle     		CrcRun <= L;
    				GS_MainSeq <= sidle;
    				
				when sErrEnd =>	--- error detected -----------------------------
					EthError <= H;
	            	GinRun <= L;
-- in idle         	EthRun <= L;
    				GS_MainSeq <= sIdle;
				
					when others => null;
				end case;
			end if;	
		end if;	
    end process;
	
	process (i_Q62_5) begin
		if rising_edge(i_Q62_5) then
			nbrRxCRC32_1 <= nbrRxCRC32;
			RxCRC_Equ_H_1 <= RxCRC_Equ_H;
			CrcError <= L;
			case (GS_MainSeq) is 
				when sEthCRC2 =>	--- Ethernet CRC2 ---------------------------
					if (RxCRC_Equ_L = L or  RxCRC_Equ_H_1 = L) then
						CrcError <= H;
					end if;
				when others => null;
			end case;
		end if;
	end process;
	
	process (i_RxData,nbrRxCRC32,nbrRxCRC32_1) begin
		if (i_RxData = nbrRxCRC32(31 downto 16)) then
			RxCRC_Equ_H <= H;
		else
			RxCRC_Equ_H <= L;
		end if;
		if (i_RxData = nbrRxCRC32_1(15 downto 0)) then
			RxCRC_Equ_L <= H;
		else
			RxCRC_Equ_L <= L;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Ethernet CRC calculator
--------------------------------------------------------------------------------
	uEthSeq_RxCRC: entity gin_link.GIN_Eth_CRC_D16 
	PORT MAP(
		i_Q62_5		=> i_Q62_5    ,
	    i_Data	    => i_RxData     ,
	    i_CrcClr    => CrcClr   ,
	    i_CrcRun    => CrcRun   ,
	    o_EthCRC    => nbrRxCRC32
	);
	  
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
