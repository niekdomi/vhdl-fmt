--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
-- 	30.06.2008-le : merge pci2 and \libraries\indel\infoMaster
--------------------------------------------------------------------------------
-- 	30.06.2008-le : 
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
--	17.12.2015-le : add C_EXTERNAL_BITCLK for extern generated bitclocks
--					(e.g. rx controlled slave)
--------------------------------------------------------------------------------
--$Rev:: 3870                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2015-12-17 14:29:04 +0100 (Do., 17 Dez 2015)                         $
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity InfoLink_Encoder is   
	generic ( 
		C_CLK_DIV_22MHZ : integer :=3;	 	-- 66MHz
		C_EXTERNAL_BITCLK : integer range 0 to 1 :=0
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
		o_BitClk	: out 	std_logic;		-- __-_____-_____-			
		i_bc1		: in	std_logic:='0';
		i_bc2		: in	std_logic:='0'
	);
end InfoLink_Encoder;

architecture behavioral_il_enc of InfoLink_Encoder is
	constant H 		: std_logic := '1';
	constant L 		: std_logic := '0';
	constant Z 		: std_logic := 'Z';   
	
    constant MID	: integer := C_CLK_DIV_22MHZ +1;
    constant LAST	: integer := C_CLK_DIV_22MHZ*2;    

	signal TXCnt    : std_logic_vector(LAST downto 1) := (others => L);
	signal TXold	: std_logic := L;         
	signal TX		: std_logic := L;   
	
	signal Pause	: std_logic := L;
	signal TXErr	: std_logic := L;
	signal TXd		: std_logic := L;
begin    
	-- readable output   
	o_TX		<= Tx;           
	
	o_BitClk	<= TXCnt(MID); 
--------------------------------------------------------------------------------
-- RXClkGen   
--------------------------------------------------------------------------------
-- 			  01234561234561234560     (LAST = 6)     
-- TXCnt	1 _-_____-_____-______                              
--			2 __-_____-_____-_____                              
--			3 ___-_____-_____-____                              
--	MID		4 ____-_____-_____-___   
--			5 _____-_____-_____-__   
--			6 ______-_____-_____-_                 
--------------------------------------------------------------------------------
	freeclk: if (C_EXTERNAL_BITCLK=0) generate begin
		TXd <= i_TXd;
		TXErr <= i_TXErr;
		Pause <= i_Pause;
		Rotate : process(i_Clk, i_Rst)
		begin    
			if i_Rst = H then
				TXCnt <= (others => L);
			elsif rising_edge(i_Clk) then
				if (TXCnt=0) then  			
					TXCnt(1) <= H;
				else 
					TXCnt(1) <= TXCnt(LAST);	-- close the loop
				end if;	
				TXCnt(LAST downto 2) <= TXCnt(LAST-1 downto 1); -- shift left
			end if;          
		end process; 
	end generate freeclk;
	
	syncclk: if (C_EXTERNAL_BITCLK=1) generate begin
		TXCnt(1) <= i_bc1;
		TXCnt(MID) <= i_bc2;
		TXd <= i_TXd;
		TXErr <= i_TXErr;
		Pause <= i_Pause;
	end generate syncclk;
--------------------------------------------------------------------------------
-- Serial Sdatput Data
--------------------------------------------------------------------------------
	encoder : process (i_Clk, i_Rst) begin 
		if (i_Rst = H) then									-- init values
			TXold <= L;                     
			TX	<= L;
		elsif rising_edge(i_Clk) then
			-- Delay Mark Modulation -------------------------------------------
			if TXCnt(1)=H then
				if (Pause=H) then
					TX <= H; 
				else
					if (TXErr=L) then  
						if (TXd=H) then  		-- X to H -> no change     				
							TX <= TX;
						else     
							if (TXold=H) then   -- H to L -> no change
								TX <= TX;
							else                -- L to L -> change
								TX <= not TX;
							end if;
						end if;
					else  						-- Error Generator 
						-- since Rev. 456, 30.06.2008, last tx is always '0'
						TX <= TX;
					end if;
				end if; 
			elsif TXCnt(MID)=H then 
				if (Pause=H) then
					TX <= H; 
				else	
					if (TXErr=L) then      
						if (TXd=H) then   	-- H -> change
							TX <= not TX;
						else                    -- L -> no change
							TX <= TX;
						end if; 
					else						-- Error Generator
						TX <= TX;				-- Hold falsches 0
					end if;
				end if;
				TXold <= TXd;				-- Old Data Inp  
			end if; 	  	 	
		end if; 
	end process;                 			-- encoder   

--------------------------------------------------------------------------------
end behavioral_il_enc;