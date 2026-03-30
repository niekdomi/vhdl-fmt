---------------------------------------------------------------------------
--
--  GIN MGT-16 to GMII-8 Data converter
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
--  	- convert 16-Bit MGT  to 8-Bit GMII Data
--
---------------------------------------------------------------------------
--	18.12.2008-le : - add svn keywords
--	18.05.2011-le : - avoid synthesis warnings:
--						remove unused i_Q62_5
--------------------------------------------------------------------------------
--$Rev:: 1945                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-05-18 16:50:45 +0200 (Mi., 18 Mai 2011)                         $
--------------------------------------------------------------------------------
                  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

--------------------------------------------------------------------------------
entity GL_MGT_GMII is
	port (
--		i_Q62_5				: in  std_logic;
		i_MGT_TxCharIsK		: in  std_logic_vector( 1 downto 0);	                    	
		i_MGT_TxData		: in  std_logic_vector(15 downto 0);			

		i_Q125				: in  std_logic;
		o_GMII_TxDat		: out  std_logic_vector( 7 downto 0);		
		o_GMII_TxDv			: out  std_logic;	
		o_GMII_TxErr		: out  std_logic
	);

end GL_MGT_GMII;

--------------------------------------------------------------------------------
architecture impl of GL_MGT_GMII is
--------------------------------------------------------------------------------	
    constant H 	: std_logic := '1';
    constant L 	: std_logic := '0';

--------------------------------------------------------------------------------
    type sGL_16_8_Seq is (
    	sIdle,sHB,sLB
    );
	signal GL_16_8_Seq		: sGL_16_8_Seq := sIdle;		
	signal GMII_TxDat		: std_logic_vector( 7 downto 0) := x"00";
	signal GMII_TxDv		: std_logic := '0';
	signal GMII_TxErr		: std_logic := '0';
	signal GMII_TxDat_1		: std_logic_vector( 7 downto 0) := x"00";
	signal GMII_TxDv_1		: std_logic := '0';

--------------------------------------------------------------------------------
begin

--------------------------------------------------------------------------------
	o_GMII_TxDat  <= GMII_TxDat;
    o_GMII_TxDv   <= GMII_TxDv ;
    o_GMII_TxErr  <= GMII_TxErr;

--------------------------------------------------------------------------------
--	convert 16-Bit MGT  to 8-Bit GMII Data
--------------------------------------------------------------------------------
	process (i_Q125) begin
    	if rising_edge(i_Q125) then 
    	
            GMII_TxDat <= x"00";
			GMII_TxDv  <= L;
            GMII_TxErr  <= L;
            
	   		case (GL_16_8_Seq) is 
    		
			when sIdle =>	---	Idle, wait to PktStart -------------------------
	    		if (i_MGT_TxDATA(15 downto 0) = x"5555") and (i_MGT_TxCharIsk = "00") then
	           		GMII_TxDat <= i_MGT_TxDATA(15 downto 8);
					GMII_TxDv  <= H;
					GL_16_8_Seq <= sLB;   
                end if;
                
			when sHB =>	---	send HighByte --------------------------------------
           		GMII_TxDat <= i_MGT_TxDATA(15 downto 8);
				GMII_TxDv  <= H;

				if (i_MGT_TxCharIsk = "00") then		
					GL_16_8_Seq <= sLB;   
				else                      
					GMII_TxDv  <= L;
					GL_16_8_Seq <= sIdle;   
				end if;	
				
			when sLB =>	---	send LowByte ---------------------------------------
				GMII_TxDat <= i_MGT_TxDATA(7 downto 0);
				GMII_TxDv  <= H;			

				if (i_MGT_TxCharIsk = "00") then		
					GL_16_8_Seq <= sHB;   
				else                      
					GMII_TxDv  <= L;
					GL_16_8_Seq <= sIdle;   
				end if;	

				when others => null;
			end case;

		end if;	
    end process;

		                			                
--------------------------------------------------------------------------------
end;
