--------------------------------------------------------------------------------
--
--  Testbench for Resolver_To_Encoder
--
--------------------------------------------------------------------------------
--
--  project     : Resolver_To_Encoder
--  programmer  : F:Baschung, INDEL AG
--  date        : 06.10.2010
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- Testbench
--
--------------------------------------------------------------------------------
--
--
--                  
--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ieee.numeric_std.ALL;
use IEEE.math_real.ALL;

library STD;
use STD.textio.all;  

--------------------------------------------------------------------------------
ENTITY Sim_Resolver_To_Encoder IS
END Sim_Resolver_To_Encoder;

ARCHITECTURE tst OF Sim_Resolver_To_Encoder IS 

--------------------------------------------------------------------------------
	constant ClkFreq		: integer := 110000000;			-- 110MHz
	constant PwmFreq		: integer := 12000;	            -- 12kHz
	constant PWM			: integer := ClkFreq / PwmFreq;	-- 9166 = 0x23CE	
	
	constant CLK_PERIOD 	: time := 9.0909090909 ns;	 
	constant H : std_logic 	:= '1';
	constant L : std_logic 	:= '0';

--------------------------------------------------------------------------------
	signal Q100 			: std_logic;
	signal Q200 			: std_logic;
	signal Q400 			: std_logic;
                        	
--------------------------------------------------------------------------------
	signal	PWMcnt          : std_logic_vector(15 downto 0) := (others => L);			 
	signal	PWMcntMax       : std_logic_vector(15 downto 0) := (others => L);			 

	signal	NextPos			: std_logic_vector(15 downto 0) := (others => L);	
	signal	Divisor			: std_logic_vector(31 downto 0) := (others => L);	
                        	
	signal 	PWMsynch		: std_logic						:= L;
    

	signal MEM_Len 			: INTEGER := 0;
	signal MEM_Adr 			: INTEGER := 0;
	
	type tMEM is array(0 to 5000) of  std_logic_vector(15 downto 0);
   	signal MEM : tMEM;       
    
--------------------------------------------------------------------------------
	file textinput 			: text open read_mode is "ResolverData.dat";


BEGIN
--------------------------------------------------------------------------------
  readInput : process is
  variable l : line;
  variable i : integer := 0;
  variable r : real;
  variable c : character;
  begin

    while not endfile(textinput) loop
      readline(textinput,l); -- liest eine Zeile Text ein
      read(l,r); -- liest einen integer aus der Zeile   

		MEM(i) <=  STD_LOGIC_VECTOR(CONV_SIGNED(INTEGER(r * 16.0),16));
		i := i + 1;
        
      read(l,c); -- liste einen Char aus der Zeile (zB ',')
    end loop;         
    
    MEM_Len <= i;  
      
    wait;  -- dieser Process wartet nun für immer
  end process readInput;


	
--------------------------------------------------------------------------------
-- extern 125MHz Clock
--------------------------------------------------------------------------------
	process begin
		Q100 	<= H;
		wait for (CLK_PERIOD/2);
		Q100 	<= L;
		wait for (CLK_PERIOD/2);
	end process;

--------------------------------------------------------------------------------
--	PWM
--------------------------------------------------------------------------------
	PWMcntMax <= STD_LOGIC_VECTOR(CONV_SIGNED(PWM,16)); 	
	
	process (Q100) begin  
		if rising_edge(Q100) then
        	PWMSynch <= L;

			if (PWMcnt >= PWMcntMax) then	
	        	PWMcnt <= (others => L);
	        	PWMSynch <= H;
	        	
	        	NextPos <= MEM(MEM_Adr);
				if (MEM_Adr < MEM_Len) then
					MEM_Adr <= MEM_Adr + 1;        	     
				else
					MEM_Adr <= 0;        	     
        	    end if; 

	        else	
	        	PWMcnt <= PWMcnt +1;	                                                                  
	        end if;                                                                  
        end if;
	end process;

--------------------------------------------------------------------------------
-- 	Res_to_Enc instance
--------------------------------------------------------------------------------
	uResToEnc : entity work.Res_to_Enc
    generic map (
		g_ClkFreq		=> ClkFreq,
		g_PWMFreq		=> PwmFreq
    )
	port map (
		i_CLK			=> Q100	    ,
		i_PWMSynch		=> PWMSynch	,
		
		i_NextPos		=> NextPos  ,

		o_EncPos		=> open		,
		o_A           	=> open		,
		o_B           	=> open		,
		o_Z           	=> open		

    );

--------------------------------------------------------------------------------
END;
