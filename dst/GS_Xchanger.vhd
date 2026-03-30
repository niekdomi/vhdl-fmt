---------------------------------------------------------------------------
--
--  GIN-Link	Xchanger
--
---------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 21.05.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- exchanges MAC- IP and UDP-Port Src/Dest
--		--> we'll get a 6x16ns = 96ns latency 
--
--	ToDo:	
--		- asynchron TxData would reduce latency 16ns
--
---------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	21.05.2004-FB	erste Version
--	18.05.2011-le :	add revision struct
--	13.04.2017-le	support for cop-pas lex
--------------------------------------------------------------------------------
--$Rev:: 4455                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-06-08 16:33:22 +0200 (Do., 08 Jun 2017)                         $
--------------------------------------------------------------------------------

                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY gin_link;
USE gin_link.PCK_CRC32_D16.all;

entity GS_Xchanger is 
	generic (
		i_MyMac 	: IN   std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_00";
		g_preX 	: integer range 0 to 1 := 0				
	);
	port (
		i_Q62_5		: IN   std_logic;
		i_RxCharIsK : IN   std_logic_vector( 1 downto 0);
		i_RxData 	: IN   std_logic_vector(15 downto 0);
		o_TxData 	: OUT  std_logic_vector(15 downto 0);
		o_TxCharIsK : OUT  std_logic_vector( 1 downto 0)
    );
end;    

architecture impl of GS_Xchanger is   
--------------------------------------------------------------------------------
--	My MAC Adress
--------------------------------------------------------------------------------
--	constant MyMac : std_logic_vector(47 downto 0) := x"00_04_3d_FB_FB_00";		

--------------------------------------------------------------------------------
    type sXchanger is (
    	sIdle,sChkMacDest,sXchUdpPort,
    	sXchwCRC,sXchwEthCRC,
    	sXchCRC,sXchEthCRC
    );

	signal GS_XchSeq	: sXchanger := sIdle;		
	signal EthCnt		: std_logic_vector(7 downto 0) := x"00" ;		
    

	type tHistDat is array(0 to 5) of  std_logic_vector(15 downto 0);	
    signal HistDat : tHistDat:= (x"0000",x"0000",x"0000",x"0000",x"0000",x"0000");  

	type  tHistIsk is array(0 to 5) of  std_logic_vector(1 downto 0);	
    signal HistIsk : tHistIsk := ("00","00","00","00","00","00"); 

	signal TxData		: std_logic_vector(15 downto 0);		
	signal TxCharIsK 	: std_logic_vector( 1 downto 0);

--	CRC ------------------------------------------------------------------------
   	signal	TxCRC32		: std_logic_vector (31 downto 0) := x"00000000"; 
   	signal	nbrTxCRC32	: std_logic_vector (31 downto 0) := x"00000000"; 

   	signal	CRCinp		: std_logic_vector (15 downto 0) := x"0000"; 
	signal 	CrcClr		: std_logic := '0';
	signal 	CrcRun	 	: std_logic := '0';

--	offsets/values in GIN-Frame ------------------------------------------------	
    constant MAC_Src_1_OFS 		: integer :=  7;
    constant MAC_Src_2_OFS 		: integer :=  8;
    constant MAC_Src_3_OFS 		: integer :=  9;
    constant ETHER_TYPE_OFS 	: integer := 10;
    constant IP_DEST_2_OFS 		: integer := 20;
    constant UDP_DEST_PORT_OFS 	: integer := 22;
    constant GF_Start_OFS 		: integer := 30;

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	o_TxCharIsK <= TxCharIsK;
    o_TxData	<= TxData;

--------------------------------------------------------------------------------
--	GS_XchSequencer              
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
    	    HistDat(0) <= i_RxData;
    	    HistDat(1) <= HistDat(0);
    	    HistDat(2) <= HistDat(1);
    	    HistDat(3) <= HistDat(2);
    	    HistDat(4) <= HistDat(3);   
    	    HistDat(5) <= HistDat(4);   
--    	    HistDat(6) <= HistDat(5);   
--    	    TxData 	   <= HistDat(5);

    	    HistIsk(0) <= i_RxCharIsK;
    	    HistIsk(1) <= HistIsk(0);
    	    HistIsk(2) <= HistIsk(1);
    	    HistIsk(3) <= HistIsk(2);
    	    HistIsk(4) <= HistIsk(3);
    	    HistIsk(5) <= HistIsk(4);
--    	    HistIsk(6) <= HistIsk(5);
--    	    TxCharIsK  <= HistIsk(5);
    	     
			EthCnt <= x"00";    		

--    		if  (not (GS_XchSeq = sIdle))
--    		and (not (TxCharIsK = "00")) then
--	    		-- reset seq if something wrong
--				GS_XchSeq <= sIdle;
--    		else
    			EthCnt <= EthCnt + 1;
    		    
	    		case (GS_XchSeq) is 
	    		
				when sIdle =>	---	Idle, wait to PktStart ---------------------
		    		if ((i_RxData = x"5555") 
		    		and (i_RxCharIsK = "00")) then 
		    			GS_XchSeq <= sChkMacDest;
		    		else	
						EthCnt <= x"00";
						CrcClr <= H;    		
						CrcRun <= L;    		
		    		end if;	
		    			
				when sChkMacDest =>	---	xchange MAC src <-> dest --------------- 
					CrcClr <= L;    		
					-- test the GinFrame identification only: 00_04_3d_FB_FB_xx
					if (EthCnt = MAC_Src_3_OFS) then
						if (g_preX=1 or ((i_MyMac(15 downto  8) = HistDat(2)(15 downto 8)) 
						and (i_MyMac(31 downto 16) = HistDat(3)) 
						and (i_MyMac(47 downto 32) = HistDat(4)))) then

							-- X-change MAC Src <-> Dest
							HistDat(0) <= HistDat(2);	
							HistDat(1) <= HistDat(3);							
							HistDat(2) <= HistDat(4);	
                    
							HistDat(3) <= i_RxData; 							
							HistDat(4) <= HistDat(0);	
							HistDat(5) <= HistDat(1);	

		    				GS_XchSeq <= sXchUdpPort;
			    			CrcRun <= H;
						else
		    				-- it's not a GinFrame, so let it as it is...
		    				GS_XchSeq <= sIdle;
						end if;	
					end if;

				when sXchUdpPort =>	--- xchange IP and UDP-Port src <-> dest ---
	                if (EthCnt = UDP_DEST_PORT_OFS) then
						-- X-change IP&UDP_Port Src <-> Dest
						HistDat(0) <= HistDat(0);	
						HistDat(1) <= i_RxData;	
                
						HistDat(2) <= HistDat(3);	
						HistDat(3) <= HistDat(4);	
													
						HistDat(4) <= HistDat(1);	
						HistDat(5) <= HistDat(2);		
							
		    			GS_XchSeq <= sXchwCRC;
		    		end if;	
    				
				when sXchwCRC =>	--- wait to GinFrame start CRC -------------
	                if (EthCnt = GF_Start_OFS) then
		    			GS_XchSeq <= sXchCRC;
					end if;
					
				when sXchCRC =>	--- GinFrame start CRC -------------------------
						HistDat(5)	<= nbrTxCRC32(15 downto  0);
		    			GS_XchSeq <= sXchwEthCRC;

				when sXchwEthCRC =>	--- wait to EthFrame CRC -------------------
					if (HistIsk(2) = "11") then 
	    				GS_XchSeq <= sXchEthCRC;
					end if;
					
				when sXchEthCRC =>	--- EthFrame CRC ---------------------------
					HistDat(5)	<= nbrTxCRC32(15 downto  0);
    				GS_XchSeq <= sIdle;

				when others => null;
				end case;
--			end if;	
		end if;	
    end process;
    	
--------------------------------------------------------------------------------
--	asynchron part of TxData
--------------------------------------------------------------------------------
    TxCharIsK  <= HistIsk(5);

	process (GS_XchSeq,HistDat,nbrTxCRC32) begin
		
		TxData <= HistDat(5);
  		case (GS_XchSeq) is 
		when sXchCRC
		   | sXchEthCRC =>
			TxData <= nbrTxCRC32(31 downto 16);

		when others => null;
		end case;
		
    end process;
	    
--------------------------------------------------------------------------------
--	CRC-generator
--------------------------------------------------------------------------------
	uxCh_TxCRC: entity gin_link.GIN_Eth_CRC_D16 
	PORT MAP(
		i_Q62_5		=> i_Q62_5    	,
	    i_Data	    => TxData     	,
	    i_CrcClr    => CrcClr   	,
	    i_CrcRun    => CrcRun   	,
	    o_EthCRC    => nbrTxCRC32
	);

--------------------------------------------------------------------------------
end;
--------------------------------------------------------------------------------
