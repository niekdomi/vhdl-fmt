---------------------------------------------------------------------------
--
--	Resolver to Encoder converter
--
---------------------------------------------------------------------------
--
--  project     : Resolver to Encoder converter
--  programmer  : F:Baschung, INDEL AG
--  date        : 22.03.2012
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- Resolver to Encoder converter 
--		- Input 16-Bit Resolver
--		- Output 13-Bit Encoder A,B,Z    	(8192 Inc/Turn)
--
---------------------------------------------------------------------------
-- includes  
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--	27.03.2012-fb: - first version of Resolver_to_Encoder
--	11.12.2012-fb: - Resolution 4096 hinzugefügt
--	09.08.2016-le: - calculate update frequency from i_PWMSynch
--				   - use division from lirary
--------------------------------------------------------------------------------
--$Rev:: 4013                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-08-09 12:36:01 +0200 (Di., 09 Aug 2016)                         $
--------------------------------------------------------------------------------	     
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

library division;
use division.all;


--------------------------------------------------------------------------------
--	Fehlt noch:
--
--	- ist noch fix auf eine PwmFreq eingestellt.
--	-- PwmMax könnte auch automatisch von _+- zu _+- gezählt werden
--  
--	- NextPos muss 16Bit von Resolver sein
-- 
--	- Nachbildung ist noch fix auf 13Bit = 0.8192 eingestellt
--	-- das einstellbar ?
--
---------------------------------------------------------------------------
entity Res_to_Enc is
    --generic (
	--	g_ClkFreq		: in	integer := 110000000;
	--	g_PWMFreq		: in	integer :=     12000
    --);                  
	port (              
		i_CLK			: in	std_logic;
		
		-- zB 12kHz synch pulse _-_
		i_PWMSynch		: in	std_logic;
		
		-- Input 16-Bit resolver-position
		i_NextPos		: in	std_logic_vector(15 downto 0);
		
		-- (not really used) already counted encoder-pos
		o_EncPos		: out	std_logic_vector(15 downto 0);
		
		-- encoder 
		o_A           	: out	std_logic;
		o_B           	: out	std_logic;
		o_Z           	: out	std_logic
    );
end;

architecture impl of Res_to_Enc is 
--------------------------------------------------------------------------------
	-- zB @12kHz  PWM = 9166 = 0x23CE		(int wird abgerundet)
	--constant PWM		: integer := g_ClkFreq / g_PwmFreq;	

	constant H 			: std_logic := '1';
	constant L 			: std_logic := '0';

--------------------------------------------------------------------------------
	signal	LastPos		: std_logic_vector(15 downto 0) := (others => L);
	signal	Delta		: std_logic_vector(15 downto 0) := (others => L);

	signal	PWMSynch	: std_logic			 			:= L;
	signal	backward	: std_logic			 			:= L;
	signal	EncCntEn	: std_logic			 			:= L;

	signal	Divisor		: std_logic_vector(31 downto 0) := (others => L);
	signal	DivCnt		: std_logic_vector(15 downto 0) := (others => L);
	signal	MaxCnt		: std_logic_vector(31 downto 0) := (others => L);
	alias	MaxCnt_H	: std_logic_vector(15 downto 0) is MaxCnt(31 downto 16);

	signal	EncCnt		: std_logic_vector(15 downto 0) := (others => L);

    -- Division
	signal	Div_ina 	: std_logic_vector(31 downto 0)	:= (others => L);
	signal	Div_inb		: std_logic_vector(31 downto 0)	:= (others => L);
	signal	Div_quot	: std_logic_vector(31 downto 0)	:= (others => L);
	signal	Div_Start   : std_logic 					:= L; 
	signal	Div_Done    : std_logic 					:= L;
	
	-- Last/Next signums
	signal	LLNN	    : std_logic_vector(3 downto 0)	:= (others => L);
	
	signal	PWM		: std_logic_vector(15 downto 0) := (others => L);

----------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	o_EncPos <= EncCnt; 
	
--------------------------------------------------------------------------------
--	get next input-data
--------------------------------------------------------------------------------
	LLNN <= EncCnt(15)&EncCnt(14) & i_NextPos(15)&i_NextPos(14);
    process (i_CLK) begin
		if rising_edge(i_CLK) then 
			-- do dedect _+- 
            PWMSynch <= i_PWMSynch; 
        	Div_Start <= L;       
            
			-- Zähler läuft
			DivCnt <= DivCnt + 1;   
			
			-- Puls Flanke erreicht?
			if (DivCnt >= MaxCnt_H) then
				MaxCnt <= MaxCnt + Divisor;
		    end if;
			
            --------------------------------------------------------------------
		    --	on rising_edge(PWMSynch)
            --------------------------------------------------------------------
        	if (PWMSynch = L) and (i_PWMSynch = H) then
				-- latch input data
            	LastPos <= i_NextPos; 
            	-- never reached    
            	MaxCnt  <= x"40000000"; 
				DivCnt  <= X"0001";
				-- (PWM-1), damit eher zu früh fertig und delta richtig berechnet wird
				PWM <= DivCnt-1;
	        	----------------------------------------------------------------
				case LLNN is   	-- Sonderfälle...
    	    	----------------------------------------------------------------
				when "0011" =>	-- Übergang von 0000 --> FFFF 
	        			backward <= H;
	        			Delta <= (EncCnt - i_NextPos);
	        	----------------------------------------------------------------
				when "1100" =>  -- Übergang von FFFF --> 0000
	        			Delta <= (i_NextPos - EncCnt);
	        			backward <= L;
	        	----------------------------------------------------------------
	        	when others =>	-- alles andere funktioniert richtig  
	        		if (i_NextPos >= LastPos) then
	        			Delta <= (i_NextPos - EncCnt);
	        			backward <= L;
	        		else
	        			backward <= H;
	        			Delta <= (EncCnt - i_NextPos);
	        		end if;
	        	----------------------------------------------------------------
	        	end case;
	        	----------------------------------------------------------------

        		-- Division starten
        		Div_Start <= H;       
            end if; 
            
            -- Resultat von Division fliegend übernehmen 
            --	Die Division benötig immer 32 Takte
            --	zB 12kHz-Regler:	110MHz/12kHz= 9166 / 32 = 286Inc/E
            --  das wird nie erreicht!!
			if (Div_Done = H) then
            	MaxCnt  <= Div_quot;
            	Divisor <= Div_quot;
			end if;

        end if; 
    end process;

--------------------------------------------------------------------------------
--	Encoder counter enable
--------------------------------------------------------------------------------
    process (i_CLK) begin
		if rising_edge(i_CLK) then 
			EncCntEn <= L;					
			-- nur Sicherheit, das könnte auch weg gelassen werden... 
--            if (not(EncCnt = LastPos)) then 
				if (DivCnt = MaxCnt_H) then
					EncCntEn <= H;					
	            end if;
--			end if;
        end if; 
    end process;

--------------------------------------------------------------------------------
--	Encoder counter
--------------------------------------------------------------------------------
    process (i_CLK) begin
		if rising_edge(i_CLK) then 
		
			if (EncCntEn = H) then					
				if (backward = L) then				
					EncCnt <= EncCnt + 1;
				else	
					EncCnt <= EncCnt - 1;
                end if;
            end if;   
            
        end if; 
    end process;

     
--------------------------------------------------------------------------------
--	Encoder A,B,Z signals
--------------------------------------------------------------------------------
    process (i_CLK) begin
		if rising_edge(i_CLK) then
			
			--------------------------------------------------------------------
--			if (EncCnt(15 downto 0) = 0) then 	-- 16Bit	0..65536
--			if (EncCnt(15 downto 3) = 0) then   -- 13Bit	0...8192
			if (EncCnt(15 downto 4) = 0) then   -- 13Bit	0...4096
				o_Z <= H;			
			else			
				o_Z <= L;			
			end if;
			
			--------------------------------------------------------------------
--			case EncCnt(1 downto 0) is	-- 16Bit	0..65536
--			case EncCnt(4 downto 3) is  -- 13Bit	0...8192
			case EncCnt(5 downto 4) is  -- 13Bit	0...4096
			--------------------------------------------------------------------
			when "00"	=>
				o_A <= L;
				o_B <= L;
			--------------------------------------------------------------------
			when "01"	=>
				o_A <= H;
				o_B <= L;
			--------------------------------------------------------------------
			when "10"	=>
				o_A <= H;
				o_B <= H;
			--------------------------------------------------------------------
			when "11"	=>
				o_A <= L;
				o_B <= H;
			--------------------------------------------------------------------
        	when others => null; 
        	end case;
			    
        end if; 
    end process;
			
--------------------------------------------------------------------------------
--	Division instance 
--------------------------------------------------------------------------------
	-- (PWM-1), damit eher zu früh fertig und delta richtig berechnet wird
	Div_ina(31 downto 16) <= PWM;--std_logic_vector(CONV_SIGNED((PWM-1),16));
	-- aaaa0000 / 0000bbbb => xxxx.xxxx
	Div_inb(15 downto  0) <= Delta;
		
inst_div: entity division.division  
	port map(
		Start	=> 	Div_Start				,
		clk		=> 	i_CLK  					,   	        					
		num		=>	Div_ina 			    ,
		den		=>  Div_inb 				,
		res		=>  Div_quot				,
		rm		=>  open                    ,
		o_Done	=> 	Div_Done
    ); 
    
				
--------------------------------------------------------------------------------
END;
