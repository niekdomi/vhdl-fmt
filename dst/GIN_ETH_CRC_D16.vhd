---------------------------------------------------------------------------
--
--  GIN-Link	Ethernet CRC calculator
--
---------------------------------------------------------------------------
--
--  project     : GS_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 22.05.2008
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- calculate Ethernet 32-Bit CRC from 16-Bit Data
--		--> Eth needs complement byte-reverse CRC
---
--	ToDo:	
--		- asynchron TxData would reduce latency 16ns
--
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   22.05.2008-FB	erste Version
--	18.12.2008-le : - add svn keywords
--	20.12.2017-le : - add output with CRC for odd datasize
--------------------------------------------------------------------------------
--$Rev:: 4693                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-21 16:22:50 +0100 (Do., 21 Dez 2017)                         $
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
USE gin_link.PCK_CRC32_D8.all;

entity GIN_Eth_CRC_D16 is 
	port (
		i_Q62_5		: IN  std_logic;
		i_Data	 	: IN  std_logic_vector(15 downto 0);
		i_CrcClr	: in  std_logic;
		i_CrcRun	: in  std_logic;
		o_EthCRC	: out std_logic_vector(31 downto 0);
		o_EthOddCRC: out std_logic_vector(31 downto 0)
	);
end;

architecture impl of GIN_Eth_CRC_D16 is   
--------------------------------------------------------------------------------
   	signal	EthCRC		: std_logic_vector (31 downto 0) := x"00000000"; 
   	signal	nbrEthCRC	: std_logic_vector (31 downto 0) := x"00000000";
	signal	EthOddCRC	: std_logic_vector (31 downto 0) := x"00000000";
	signal	nbrEthOddCRC: std_logic_vector (31 downto 0) := x"00000000";

   	signal	CRCinp		: std_logic_vector (15 downto 0) := x"0000"; 
	signal 	CrcClr		: std_logic := '0';
	signal 	CrcRun	 	: std_logic := '0';

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';    

--------------------------------------------------------------------------------
begin
   	
--------------------------------------------------------------------------------
	o_EthCRC <= nbrEthCRC;
	o_EthOddCRC <= nbrEthOddCRC;

--------------------------------------------------------------------------------
--	Ethernet CRC calculator
--------------------------------------------------------------------------------

	-- byte-reverse data-input 
	process (i_Data) begin
		for i in 7 downto 0 loop
       		-- first TxBit = i_TxData(8) (nextCRC_inp = D15)
		    CRCinp(15 - i) 	<= i_Data( 8 + i);
		    CRCinp( 7 - i)	<= i_Data(i);
		end loop;				
	end process;	

	-- calc CRC32 from 16-bit data
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
        	if (i_CrcClr = H) then 
            	EthCRC <= x"FFFFFFFF";
        	elsif (i_CrcRun = H) then
        		-- nextCRC_inp first TxBit = D15 (= i_TxData(8))
        		EthCRC <= gin_link.PCK_CRC32_D16.nextCRC32_D16(CRCinp,EthCRC);
        	end if;
			EthOddCRC <= gin_link.PCK_CRC32_D8.nextCRC32_D8(CRCinp(15 downto 8),EthCRC);
		end if;
	end process;	

	-- complement byte-reverse CRC
	process (EthCRC) begin 
		for i in 7 downto 0 loop
       		-- first TxBit = i_TxData(24) (= EthCRC(31))
		    nbrEthCRC(24 + i) 	<= not EthCRC(31 - i);
		    nbrEthCRC(16 + i) 	<= not EthCRC(23 - i);
		    nbrEthCRC( 8 + i) 	<= not EthCRC(15 - i);
		    nbrEthCRC(     i) 	<= not EthCRC( 7 - i);
		end loop;				
	end process;
	process (EthOddCRC) begin
		for i in 7 downto 0 loop
			-- first TxBit = i_TxData(24) (= EthOddCRC(31))
			nbrEthOddCRC(24 + i) <= not EthOddCRC(31 - i);
			nbrEthOddCRC(16 + i) <= not EthOddCRC(23 - i);
			nbrEthOddCRC( 8 + i) <= not EthOddCRC(15 - i);
			nbrEthOddCRC(     i) <= not EthOddCRC( 7 - i);
		end loop;
	end process;
	  
--------------------------------------------------------------------------------
end;
--------------------------------------------------------------------------------
