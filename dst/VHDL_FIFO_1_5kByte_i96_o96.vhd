--------------------------------------------------------------------------------
--
--  FIFO_1_5kByte_x96.vhd
--
--------------------------------------------------------------------------------
--
--  project     : FIFO
--  programmer  : F. Baschung, INDEL AG
--  date        : 27.10.2017-FB
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
--$Rev:: 5164                   $
--$Author:: fbaschung                $
--$Date:: 2018-11-12 11:27:31 +0100 (Mo., 12 Nov 2018)        $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	25.10.2017-FB	+ synched LEVEL for both sides
-- 					+ unregisteres DATAout for faster access
-- 	25.01.2018-FB	synched LEVEL with SL2_100.Synch_D2 (no TimingErrors)  
-- 	24.01.2018-FB	LEVEL-synch neu (wie vorher, aber ohne TimingError) 
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

LIBRARY BRAM;
USE BRAM.ALL;  

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
entity FIFO_1_5kByte_i96_o96 is 
	port (
		i_Reset  	: IN  std_logic 					:= '0';

		i_CLKin  	: IN  std_logic;
		i_ENin   	: IN  std_logic 					:= '0';
		i_DATAin 	: IN  std_logic_vector(95 downto 0) := (others => '0');
		
		i_CLKout  	: IN  std_logic;
		i_ENout   	: IN  std_logic 					:= '0';
		-- unregistered DATAout
		o_DATAout  	: OUT std_logic_vector(95 downto 0) := (others => '0');
		-- registered DATAout
		o_REGout  	: OUT std_logic_vector(95 downto 0) := (others => '0');
        
        -- CLKin  snychron LEVEL
		o_LEVELin  	: OUT std_logic_vector( 6 downto 0) := (others => '0');
        -- CLKout snychron LEVEL
		o_LEVELout 	: OUT std_logic_vector( 6 downto 0) := (others => '0') 
	);
end FIFO_1_5kByte_i96_o96;

architecture impl OF FIFO_1_5kByte_i96_o96 is
--------------------------------------------------------------------------------
	signal 	ADDRin 		: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	ADDRout 	: std_logic_vector( 6 downto 0) := (others => '0');
	signal	ENout_t1  	: std_logic 					:= '0';
	signal	Enin_t1  	: std_logic 					:= '0';

	-- pre-synched
	signal 	sADDRin 	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	sADDRout 	: std_logic_vector( 6 downto 0) := (others => '0');
	-- synched
	signal 	sLEVELin	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	sLEVELout	: std_logic_vector( 6 downto 0) := (others => '0');

	-- xyz_syn is a TS_IGNOR constrained name
	signal 	xyz_syn_i	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	xyz_syn_o	: std_logic_vector( 6 downto 0) := (others => '0');

	signal 	syn_i0	 	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	syn_i1	 	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	syn_o0	 	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	syn_o1	 	: std_logic_vector( 6 downto 0) := (others => '0');

	-- xilinx
	attribute KEEP : string;
	attribute KEEP of xyz_syn_i  : signal is "TRUE";
	attribute KEEP of xyz_syn_o  : signal is "TRUE";

--------------------------------------------------------------------------------
	signal	BRAM_Clk_A  : std_logic                     := '0';                
	signal	BRAM_WEN_A  : std_logic_vector(11 downto 0)	:= (others => '0');         
	signal	BRAM_Addr_A : std_logic_vector( 6 downto 0) := (others => '0');
	signal	BRAM_Din_A  : std_logic_vector(95 downto 0) := (others => '0');   
	signal	BRAM_Dout_A : std_logic_vector(95 downto 0) := (others => '0');   

	signal	BRAM_Clk_B  : std_logic 					:= '0';
	signal	BRAM_Addr_B : std_logic_vector( 6 downto 0) := (others => '0');
	signal	BRAM_Din_B  : std_logic_vector(95 downto 0) := (others => '0');   
	signal	BRAM_Dout_B : std_logic_vector(95 downto 0) := (others => '0');   

	signal 	ADDRin_s 	: std_logic_vector( 6 downto 0) := (others => '0');
	signal 	ADDRout_s 	: std_logic_vector( 6 downto 0) := (others => '0');
--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	o_LEVELin  	<= sLEVELin;				-- FIFO-LEVEL synched to CLKin
	o_LEVELout 	<= sLEVELout;				-- FIFO-LEVEL synched to CLKout
	o_DATAout 	<= BRAM_Dout_B after 5 ns;	-- unregistered Data-Out
	 
--------------------------------------------------------------------------------
--	Write into FIFO
--------------------------------------------------------------------------------
	process (i_Reset,i_CLKin) begin     
		if (i_Reset = H) then
			BRAM_Din_A 	<= (others => '0');
			BRAM_WEN_A 	<= (others => '0');
		  	ADDRin 		<= (others => '0');
			Enin_t1 	<= '0';
			
		elsif rising_edge(i_CLKin) then 
			BRAM_Din_A <= (others => '0');
			BRAM_WEN_A <= (others => '0');
			
		   	if (i_Enin = H) then 
		   		-- schreibe in die aktuell anliegende Adr (zB 0 nach Reset)
				BRAM_Din_A <= i_DATAin;
				BRAM_WEN_A <=  (others => '1');
			end if;
			
			-- Addr-increment erst nach dem Schreiben
			Enin_t1 <= i_Enin;
		   	if (Enin_t1 = H) then
		   		-- zeigt auf die nÃ¤chste freie FIFO-Adr 
				ADDRin <= ADDRin + 1; 
			end if;				

		end if;
	end process;
	
--------------------------------------------------------------------------------
--	Read from FIFO	
--------------------------------------------------------------------------------
	process (i_Reset,i_CLKout) begin
		if (i_Reset = H) then
		  	ADDRout <= (others => '0');
		elsif rising_edge(i_CLKout) then
			if (i_ENout = H) and (sLEVELout > 0) then  
				ADDRout  <= ADDRout + 1; 
			end if;
		end if;
	end process;
	
	-- registered Data-Out
	process (i_CLKout) begin
		if rising_edge(i_CLKout) then
			-- needs two clock till new data
			ENout_t1 <= i_ENout; 

			if (ENout_t1 = H) then
				o_REGout <= BRAM_Dout_B;
			else
				o_REGout <= (others => '0');
			end if;

		end if;
	end process;

--------------------------------------------------------------------------------
--	FIFO-LEVEL
--------------------------------------------------------------------------------	
-- VORSICHT:	ADDR jeweils nur 2x zu synchen reicht nicht (knaxt)
--				=> if (syn_i0 = syn_i1) then... ist besser
-- (ev wÃ¼rde eine Stufe schon ausreichen, if (syn_i0 = xyz_syn_i) then...)
	xyz_syn_o <= ADDRout;	
	process (i_CLKin) begin
		if rising_edge(i_CLKin) then 
			syn_o0	<= xyz_syn_o;
			syn_o1	<= syn_o0;
			if (syn_o0 = syn_o1) then
	    		sLEVELin <= (ADDRin - syn_o1) after 3 ns;
		--	   	sADDRout <= syn_o1;
			end if; 
		-- damit muss der minFIFO-LEVEL hÃ¶her gewÃ¤hlt werden (zB 4)		
	    --	sLEVELin <= (ADDRin - sADDRout) after 3 ns;
		end if;
	end process;

	xyz_syn_i <= ADDRin;	
	process (i_CLKout) begin  
		if rising_edge(i_CLKout) then 
			syn_i0	<= xyz_syn_i;
			syn_i1	<= syn_i0;
			if (syn_i0 = syn_i1) then
    			sLEVELout <= (syn_i1 - ADDRout) after 3 ns;
		-- 		sADDRin <= syn_i1;
			end if; 			
		-- damit muss der minFIFO-LEVEL hÃ¶her gewÃ¤hlt werden (zB 4)		
    	--	sLEVELout <= (sADDRin - ADDRout) after 3 ns;
		end if;
	end process;
	   
--------------------------------------------------------------------------------
	BRAM_Clk_A 	<= i_CLKin;
	BRAM_Clk_B 	<= i_CLKout;
	BRAM_Addr_A <= ADDRin;
	BRAM_Addr_B <= ADDRout;

--------------------------------------------------------------------------------
--	BRAM
--------------------------------------------------------------------------------
inst_BRAM: entity BRAM.BRAM_1_5kByte_A96_B96  
	port map (
		i_BRAM_Clk_A  	=>  BRAM_Clk_A 		,
		i_BRAM_WEN_A  	=>  BRAM_WEN_A   	,
		i_BRAM_Addr_A 	=>  BRAM_Addr_A  	,
		o_BRAM_Din_A  	=>  BRAM_Dout_A  	,
		i_BRAM_Dout_A  	=>  BRAM_Din_A   	,
		                                 	
		i_BRAM_Clk_B  	=>  BRAM_Clk_B   	,
		i_BRAM_Addr_B 	=>  BRAM_Addr_B  	,
		o_BRAM_Din_B  	=>  BRAM_Dout_B  	,
		i_BRAM_Dout_B  	=>  BRAM_Din_B   
	);
	
--------------------------------------------------------------------------------
end architecture impl;
--------------------------------------------------------------------------------
