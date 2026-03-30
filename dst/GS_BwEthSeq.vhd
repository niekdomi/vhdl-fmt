---------------------------------------------------------------------------
--
--  GIN-Link	Ethernet backward sequencer
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
--  	- filter non-eth ctrl-sequences
--		- check CRC-error
--
---------------------------------------------------------------------------
                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- synopsys translate_off
--Library UNISIM;
--use UNISIM.Vcomponents.all;
-- synopsys translate_on

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   21.05.2004-FB	erste Version
---------------------------------------------------------------------------

entity GS_BwEthSeq is 
	port (
		i_Q62_5		: IN  std_logic;
		i_RxCharIsK : IN  std_logic_vector( 1 downto 0);
		i_RxData 	: IN  std_logic_vector(15 downto 0);
		i_RxCrcErr	: IN  std_logic;
		o_TxCharIsK : out std_logic_vector( 1 downto 0);
		o_TxData 	: out std_logic_vector(15 downto 0);
		o_EthBwError: OUT std_logic;				-- EthFraming Error 
		o_EthBwRun	: OUT std_logic
    );
end;    

architecture impl of GS_BwEthSeq is   
--------------------------------------------------------------------------------
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
    type sGS_BwEthSeq is (
    	sIdle,
    	sWend,sEthCRC1,sEthCRC2,sEthEnd,sErrEnd
    );

	signal GS_BwEthSeq	: sGS_BwEthSeq := sIdle;		
	signal EthBwError	: std_logic := L;
	signal EthBwRun		: std_logic := L;

--------------------------------------------------------------------------------	
begin -- of architecture GIN_EthBWSeq    
--------------------------------------------------------------------------------

--	outputs --------------------------------------------------------------------
    o_EthBwRun 	<= EthBwRun;
   	o_EthBwError<= EthBwError;
   	
--------------------------------------------------------------------------------
--	GS_EthBw Sequencer
--------------------------------------------------------------------------------
	process (i_Q62_5) begin
    	if rising_edge(i_Q62_5) then 
    	
			EthBwError 	<= L;
	   		o_TxCharIsK <= "10";
	   		o_TxData	<= x"BC50";
            
    		case (GS_BwEthSeq) is 
    		
			when sIdle =>	---	Idle, wait to PktStart ---------------------
            	EthBwRun 	<= L;

	    		if ((i_RxData = x"FB55") 
	    		and (i_RxCharIsK = "10")) then
	    			EthBwRun <= H; 
		            o_TxData 	<= i_RxData;
		            o_TxCharIsK <= i_RxCharIsK;
	    			GS_BwEthSeq <= sWend; 
	    		end if;	
	    					   
	    					    				                	
			when sWend =>	--- Wait til UDP-End ---------------------------
	            o_TxData 	<= i_RxData;
	            o_TxCharIsK <= i_RxCharIsK;
				if (i_RxCharIsK /= "00") then
		    		if ((i_RxData = x"FDF7") 
		    		and (i_RxCharIsK = "11")) then 
		    			GS_BwEthSeq <= sEthEnd; 
		    		else   
				   		o_TxCharIsK <= "10";
	   					o_TxData	<= x"BC50";
		    			GS_BwEthSeq <= sErrEnd; 
		    		end if;
		    	end if;		
   				
			when sEthEnd =>		--- Ethernet End ---------------------------
            	EthBwRun <= L;
    			GS_BwEthSeq <= sIdle; 
									
			when sErrEnd =>	--- error detected -----------------------------
				EthBwError <= H;
            	EthBwRun <= L;
   				GS_BwEthSeq <= sIdle;
			
				when others => null;
			end case;

		end if;	
    end process;
    	
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
