--------------------------------------------------------------------------------
--  DelayLine
--------------------------------------------------------------------------------
--
--  project     : DelayLine 
--  programmer  : C. Leuthold , INDEL AG
--  date        : 07.04.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : isp / edk
--
--  purpose  
--
--  long Delay-Line for one signal (delay: 1..16384 Clocks)
--  
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00   :   07.04.2004-le  : - disc. 
--
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 2675                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-01-24 14:07:28 +0100 (Do., 24 Jan 2013)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------                 
library ieee;
use IEEE.std_logic_1164.ALL;              
use ieee.std_logic_unsigned.all;
--------------------------------------------------------------------------------
-- defines 
--------------------------------------------------------------------------------
entity DelayLine is  
	generic (
		C_REG_LNG	: integer range 1 to 32 := 16
	);
    port ( 
        i_Clk       : in    std_logic;                  -- clock input
        i_Reset    	: in    std_logic;                  -- reset input H-active         
        i_delay		: in    std_logic_vector(C_REG_LNG-1 downto 0);  
        i_input		: in	std_logic;
        o_delayed_out: out	std_logic
    );
end;                                                    -- of entity template 

architecture behavior_DelayLine of DelayLine is   
-- component declarations ------------------------------------------------------
	----- Component RAMB16_S1_S1 -----
	component RAMB16_S1_S1
	  	port (DIA    : in STD_LOGIC_VECTOR (0 downto 0);
	  	      DIB    : in STD_LOGIC_VECTOR (0 downto 0);
	  	      ENA    : in STD_logic;
	  	      ENB    : in STD_logic;
	  	      WEA    : in STD_logic;
	  	      WEB    : in STD_logic;
	  	      SSRA   : in STD_logic;
	  	      SSRB   : in STD_logic;
	  	      CLKA   : in STD_logic;
	  	      CLKB   : in STD_logic;
	  	      ADDRA  : in STD_LOGIC_VECTOR (13 downto 0);
	  	      ADDRB  : in STD_LOGIC_VECTOR (13 downto 0);
	  	      DOA    : out STD_LOGIC_VECTOR (0 downto 0);
	  	      DOB    : out STD_LOGIC_VECTOR (0 downto 0)
	  	     ); 
	end component;


-- constants -------------------------------------------------------------------
    constant H          : std_logic := '1';
    constant L          : std_logic := '0';
    constant Z          : std_logic := 'Z';   
    constant C_ADDR_L	: integer := 14;
-- types -----------------------------------------------------------------------      
-- signals --------------------------------------------------------------------- 
	signal in_cnt       : std_logic_vector(C_ADDR_L-1 downto 0) := (others => L);
    signal out_cnt      : std_logic_vector(C_ADDR_L-1 downto 0) := (others => L); 
    signal delay        : std_logic_vector(C_ADDR_L-1 downto 0) := (others => L);
	signal VCC			: std_logic;
	signal GND			: std_logic;   
	signal GND_V        : std_logic_vector(C_ADDR_L-1 downto 0);    
	signal GND_V0		: std_logic_vector(0 downto 0);
	signal input		: std_logic_vector(0 downto 0);
    signal delayed_out	: std_logic_vector(0 downto 0);
    
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin                                                   -- of architecture NAME    
-- inverse and readable Outputs -----------------------------------------------
	VCC			<= H;
	GND			<= L;   
	GND_V		<= (others => L);   
	GND_V0		<= "0";   
	delay		<= i_delay(C_ADDR_L-1 downto 0) when C_ADDR_L<C_REG_LNG 
					else GND_V(C_ADDR_L-1 downto C_REG_LNG) & i_delay;
	process (i_input,delayed_out)
	begin  
		if i_input=H then
			input	<= "1";
		else
			input	<= "0";
		end if;      
		if delayed_out=1 then
          	o_delayed_out <= H;
		else
			o_delayed_out <= L;
		end if;                                                         
	end process;  
	
-- processes ------------------------------------------------------------------  
    count_around: process (i_Clk) 
    begin                                                       
        if rising_edge(i_Clk) then
        -- clocked statements  
        	if (i_Reset = '1') then
        	-- asynch reset statements
        	else 
        	   --out_cnt <= out_cnt + 1;
        	   --in_cnt  <= out_cnt + delay+2; 
        	   	in_cnt <= in_cnt + 1;        
        	   	out_cnt  <= in_cnt - delay;       
        	end if;
        end if;
    end process;	-- END of process count_around     
    ring_buf : RAMB16_S1_S1
	port map (
		DIA    => input  	,-- in STD_LOGIC_VECTOR (0 downto 0);
	    DIB    => GND_V0	,-- in STD_LOGIC_VECTOR (0 downto 0);
	    ENA    => VCC		,-- in STD_logic;
	    ENB    => VCC		,-- in STD_logic;
	    WEA    => VCC		,-- in STD_logic;
	    WEB    => GND		,-- in STD_logic;
	    SSRA   => i_Reset 	,-- in STD_logic;
	    SSRB   => i_Reset	,-- in STD_logic;
	    CLKA   => i_Clk 	,-- in STD_logic;
	    CLKB   => i_Clk 	,-- in STD_logic;
	    ADDRA  => in_cnt	,-- in STD_LOGIC_VECTOR (13 downto 0);
	    ADDRB  => out_cnt	,-- in STD_LOGIC_VECTOR (13 downto 0);
	    DOA    => open		,-- out STD_LOGIC_VECTOR (0 downto 0);
	    DOB    => delayed_out   -- out STD_LOGIC_VECTOR (0 downto 0)
	);  
end behavior_DelayLine;	-- END of architecture DelayLine      
--------------------------------------------------------------------------------

