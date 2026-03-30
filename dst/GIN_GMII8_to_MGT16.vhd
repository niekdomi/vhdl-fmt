---------------------------------------------------------------------------
--
--  GIN GMII-8 to MGT-16 Data converter
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
--  	- convert 8-Bit GMII to 16-Bit MGT Data
--
---------------------------------------------------------------------------
--	18.12.2008-le : - add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 823                                                                   $
--$Author:: leuthold                                                           $
--$Date:: 2008-12-18 15:37:50 +0100 (Do., 18 Dez 2008)                         $
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
entity GL_GMII_MGT is
	port (
		i_Q125				: in  std_logic;
		i_GMII_RxDat		: in  std_logic_vector( 7 downto 0);		
		i_GMII_RxDv			: in  std_logic;	
		i_GMII_RxErr		: in  std_logic;

		i_Q62_5				: in  std_logic;
		o_MGT_RxCharIsK		: out std_logic_vector( 1 downto 0);	                    	
		o_MGT_RxData		: out std_logic_vector(15 downto 0)
	);

end GL_GMII_MGT;

--------------------------------------------------------------------------------
architecture impl of GL_GMII_MGT is
--------------------------------------------------------------------------------	
    constant H 	: std_logic := '1';
    constant L 	: std_logic := '0';

--------------------------------------------------------------------------------
    type sGL_8_16_Seq is (
    	sIdle,sHB,sLB
    );
	signal GL_8_16_Seq		: sGL_8_16_Seq := sIdle;		
	signal GMII_RxDat_1		: std_logic_vector( 7 downto 0) := x"00";
	signal GMII_RxDv_1		: std_logic := '0';
	signal RxD16v			: std_logic_vector(15 downto 0) := x"0000";
	signal RxChv			: std_logic_vector( 1 downto 0) := "00";

--------------------------------------------------------------------------------
begin

--------------------------------------------------------------------------------
--	convert 8-Bit GMII_ to 16-Bit MGT Data
--------------------------------------------------------------------------------
	process (i_Q125) begin 
    	if rising_edge(i_Q125) then
    	    GMII_RxDv_1 	<= i_GMII_RxDv;
    	    GMII_RxDat_1	<= i_GMII_RxDat;  

			RxD16v 	<= x"0000";
			RxChv 	<= "11";
            
	   		case (GL_8_16_Seq) is 
    		
			when sIdle =>	---	Idle, wait to PktStart -------------------------
				if (GMII_RxDv_1 = L) and (i_GMII_RxDv = H) then
                	GL_8_16_Seq <= sLB;
				end if;
				 
			when sHB =>	---	send HighByte -------------------------------------- 
			    RxD16v 	<= RxD16v;
			    RxChv 	<= RxChv;  
			    
               	GL_8_16_Seq <= sLB;

			when sLB =>	---	send HighByte -------------------------------------- 
				RxD16v 	<= GMII_RxDat_1  & i_GMII_RxDat;
				RxChv 	<= not (GMII_RxDv_1 & i_GMII_RxDv);
                                         
                if (i_GMII_RxDv = H) then
	               	GL_8_16_Seq <= sHB;
                else
	               	GL_8_16_Seq <= sIdle;
                end if;
                                
			when others => null;
			end case;
		end if;	
    end process;       

--------------------------------------------------------------------------------
--	synch to 62.5MHz Clock
--------------------------------------------------------------------------------
	process (i_Q62_5) begin 
    	if rising_edge(i_Q62_5) then
        	o_MGT_RxData	<= RxD16v;
            o_MGT_RxCharIsK	<= RxChv;
		end if;	
    end process;       

		                			                
--------------------------------------------------------------------------------
end;
