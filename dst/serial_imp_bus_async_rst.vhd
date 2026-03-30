--------------------------------------------------------------------------------
--  title
--------------------------------------------------------------------------------
--
--  project     : serial IMP-Bus
--  programmer  : Christof Leuthold, INDEL AG
--  date        : 08.01.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : 
--
--  purpose
--    
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00   :   08.01.2004-le  : - first steps 
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes 
--------------------------------------------------------------------------------                 
library ieee;
use IEEE.std_logic_1164.ALL;                
use IEEE.std_logic_unsigned.ALL;   
--------------------------------------------------------------------------------
-- defines 
--------------------------------------------------------------------------------
entity SERIAL_IMP_BUS is         
    port ( 
        i_Clk       : in    std_logic;      -- clock input
        i_Reset    : in    std_logic;      -- reset input H-active    
        -- ctrl-Register
        i_TX_Reg	: in	std_logic_vector(31 downto 0);
        o_RX_Reg	: out	std_logic_vector(31 downto 0);
        -- serial IMP-Bus
        i_sib_Data  : in	std_logic;
        o_sib_Data  : out	std_logic;
        o_sib_Select: out	std_logic;
        o_sib_Clock : out	std_logic;
        -- data ctrl 
        i_Start		: in 	std_logic;
        o_tx_done	: out	std_logic;
        o_rx_done	: out	std_logic;    
        i_rx_ack	: in 	std_logic;
        o_int		: out 	std_logic;     
        -- clocks  
        i_sib_Clk 	: in 	std_logic;
        i_Out_Clk   : in 	std_logic;
        i_In_Clk    : in 	std_logic;
        i_In_preClk : in 	std_logic
        
    );
end;                                                    -- of entity SERIAL_IMP_BUS 

architecture behavior_SERIAL_IMP_BUS of SERIAL_IMP_BUS is   
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
    constant H          : std_logic := '1';
    constant L          : std_logic := '0';
    constant Z          : std_logic := 'Z';     
    
    constant DEF_DATA_LENGTH : integer := 24;           
-- types -----------------------------------------------------------------------
	type t_TX_state is (TX_Start_bit,TX_AdressOrData,TX_Data_bits,TX_Parity_bit,TX_Stop_bit);   
	type t_RX_state is (RX_Start_bit,RX_Data_bits,RX_Parity_bit,RX_Stop_bit);
-- signals ---------------------------------------------------------------------
    signal Reset    	: std_logic;					-- inverse of ni_Reset 
    signal Clk    		: std_logic;    
    -- clocks  
    signal Out_Clk      : std_logic;
    signal In_Clk       : std_logic;
    signal In_preClk	: std_logic;   
    -- shift register
    signal DataSR		: std_logic_vector(DEF_DATA_LENGTH-1 downto 0);
    -- tx register signals   
    signal AddrNData	: std_logic;  
    signal Interrupt	: std_logic;
    signal data_length  : std_logic_vector(4 downto 0);   
    -- tx sequenzer signals         
    signal TX_state 		: t_TX_state; 
    signal sib_out		: std_logic;  
    signal sib_select	: std_logic;
    signal tx_Parity    : std_logic;  
    signal start		: std_logic;
    signal tx_done		: std_logic;   
    -- rx sequenzer signals    
    signal RX_state 	: t_RX_state; 
    signal sib_in		: std_logic;     
    signal shift     	: std_logic;
    signal rx_Parity    : std_logic;   
    signal SinRef 	    : std_logic; 
    signal sIn_test         : std_logic; 
    signal FErr         : std_logic;  
    signal RX_done		: std_logic;        
    signal rx_shift		: std_logic;
    
    signal TX_Reg       : std_logic_vector(31 downto 0);    
    
    signal RX_AT		: std_logic;    
    signal RX_Int		: std_logic;
    signal RX_Ferr		: std_logic;
    signal RX_Perr		: std_logic;
    signal RX_Data		: std_logic_vector(DEF_DATA_LENGTH-1 downto 0);     
    
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin								-- of architecture behavior_SERIAL_IMP_BUS    
	-- inverse and readable Outputs --------------------------------------------
    Reset 			<= (i_Reset);    
    Clk	    		<= i_Clk;  
    
    o_sib_Select	<= sib_select;
    o_sib_Clock 	<= i_sib_Clk;  
    o_sib_Data		<= sib_out;
	sib_in			<= i_sib_Data;        
    
    o_RX_Reg(31) 	<= RX_AT;
    o_RX_Reg(30) 	<= RX_Int;
    o_RX_Reg(29)	<= L;    
    o_RX_Reg(28)	<= L; 
    o_RX_Reg(27) 	<= RX_Ferr;    
    o_RX_Reg(26)    <= RX_Perr;
    o_RX_Reg(25)	<= L; 
    o_RX_Reg(24)	<= L; 
    o_RX_Reg(23 downto 0)  <= RX_Data;   
    
    Out_Clk   		<= i_Out_Clk;
    In_Clk    		<= i_In_Clk;
    In_preClk 		<= i_In_preClk;   
    
    TX_Reg 			<= i_TX_Reg;       
    
    start			<= i_Start;	
    o_tx_done       <= tx_done; 
    o_rx_done       <= rx_done; 
     
    ----------------------------------------------------------------------------
    -- master-state-machine
    -- start	____________-_-----------_-----------_-
    -- tx_done	-------------___________-___________-__
    -- txStates SSSSSSSSSSSSSADDDDDDDDPESADDDDDDDDPESAD 
    -- rxStates SSSSSSSSSSSSSSSSDDDDDDDDPESSDDDDDDDDPES              
    -- shift	_______________----------__----------__
    ---------------------------------------------------------------------------- 
          
    Statemachine : process (Reset,Clk) 
    begin                                                       
        if (Reset = '1') then
        -- asynch reset statements
        	TX_state 	<= TX_Start_bit; 	--master-state-machin
        	RX_state 	<= RX_Start_bit; 	--slave-states        
        	shift    	<= L; 
            tx_done 	<= H;   
            rx_shift 	<= L;
        elsif rising_edge(Clk) then  
        	if Out_Clk=H then  
    			-- master-state-machine
				case TX_state is
    			when TX_Start_bit => 
					if start=H then 	 
    			   		TX_state 	<= TX_AdressOrData; 
    			   		tx_done 	<= L; 
    			   	else
    			   		tx_done 	<= H; 
    			   	end if;  
    			   	if RX_state=RX_Parity_bit then  
    			   		RX_state 	<= RX_Stop_bit;  
    			   	else   
    			   		RX_state 	<= RX_Start_bit; 
    			   	end if;
				when TX_AdressOrData =>  
					TX_state 	<= TX_Data_bits; 
					RX_state 	<= RX_Start_bit;   
				when TX_Data_bits => 	 
					shift    <= H;  
					if shift=H then 
						rx_shift <= H;
						RX_state<= RX_Data_bits; 
					end if;
					if data_length<2 then
    			    	TX_state<= TX_Parity_bit; 
    			    end if;
   				when TX_Parity_bit => 
					TX_state 	<= TX_Stop_bit;	
				when TX_Stop_bit =>	 
					TX_state 	<= TX_Start_bit; 
					RX_state	<= RX_Parity_bit; 
    			    tx_done 	<= H;  
					rx_shift 	<= L;
    			    shift    	<= L;
				end case;   
    		end if; 
        end if;
    end process;
    ----------------------------------------------------------------------------
	-- serial data transmitter
	--             Sta AT  D1  D0  P   Sto Sta AT  
	-- Out_Clk   _-___-___-___-___-___-___-___-___-       
	-- sib_sel   xx____----------------________----
	-- sib_out   xx____----____--------____________ 
	-- tx_Parity xx----________-------------------- 
	-- TFr       ------_---------------------------                                       
	----------------------------------------------------------------------------      
    sib_tx: process (Reset,Clk) 
    begin                                                       
        if (Reset = '1') then
        -- asynch reset statements
        	sib_select 	<= L; 
        	sib_out 	<= L; 
        	tx_Parity  	<= L;       
        elsif rising_edge(Clk) then
        -- clocked statements     
        	if Out_Clk=H then          
        		case TX_state is
        		when TX_Start_bit =>   
        			tx_Parity  	<= H;   -- reset perity
        			sib_select 	<= L;	-- bus on idle 
        			sib_out 	<= L;  
        		when TX_AdressOrData =>  
        			sib_select 	<= H;   -- start bus cycle
        			sib_out 	<= AddrNData; 
        			tx_Parity 	<= tx_Parity xor AddrNData; 
        		when TX_Data_bits => 
        			sib_select 	<= H; 
        			sib_out 	<= DataSR(DEF_DATA_LENGTH-1); 
        			tx_Parity 	<= tx_Parity xor DataSR(DEF_DATA_LENGTH-1);
        		when TX_Parity_bit =>    
        			sib_select 	<= H;  
        			sib_out 	<= tx_Parity;   
        		when TX_Stop_bit =>  
        			sib_select 	<= L;	-- stop bus cycle
        			sib_out 	<= L;  
        		end case;
        	else
        		tx_Parity <= tx_Parity;  
        		sib_select 	<= sib_select;
        		sib_out 	<= sib_out 	 ;
            end if; 
        end if;
    end process sib_tx;
    ----------------------------------------------------------------------------
	-- serial data resiver 
	-- In_Clk    -___________-___________-___________-___________-___________-__
	-- In_preClk _________-___________-___________-___________-___________-_____
	-- sIn_test  -_________---_________---_________---_________---_________---__
	--            startbit=0
	-- sib_in    -____________------------____________----------_-_________-----
	-- SinRef    ----------____________------------____________------------_____
	-- FErr		 xxxxxxxxxxxxx___________________________________---------------
	-- Parity	 xxxxxxxxxxxxx------------________________________--------------
	----------------------------------------------------------------------------
    sib_rx: process (Reset,Clk) 
    begin                                                       
        if (Reset = '1') then
        -- asynch reset statements
        	rx_Parity <= L;              
        	FErr 	<= L;
        	SinRef 	<= L;      
        	sIn_test 	<= L; 
        	RX_AT   <= L;
        	RX_Int  <= L;
        	RX_Ferr <= L;
        	RX_Perr <= L;
        	RX_Data <= (others => L);    
        	RX_done	<= L;     
        	o_int	<= L;
        elsif rising_edge(Clk) then
        -- clocked statements 
        	if sIn_test=H then    
        		-- FrameError: no previous errors and a stabel input
        		if (FErr=L) and (sib_in=SinRef) then 
        			FErr <= L;
        	    else
        	    	FErr <= H;
        	    end if;
        	end if; 
        	if i_rx_ack = H then
        		RX_done		<= L; 
        	end if;
        	if In_Clk=H then       
        		sIn_test 	<= L;      
        		o_int 		<= L;
        		case RX_state is   
        			when RX_Start_bit =>   
        				rx_Parity <= H;   
        				FErr <= sib_in; -- is 0 
        			when RX_Data_bits => 
        				rx_Parity <= rx_Parity xor sib_in;	-- build parity 
        			when RX_Parity_bit => 
        				rx_Parity <= rx_Parity xor sib_in;  -- compare parity 
        				-- store shared registers
        				RX_AT	<= AddrNData;
        				RX_Int  <= Interrupt; 
        				RX_Data <= DataSR(DEF_DATA_LENGTH-1 downto 0);
        			when RX_Stop_bit =>  
        				-- store rx registers     
        				-- Ferr <= previous errors, last sample and stopbit = 0
        				RX_Ferr <= (FErr and (sib_in xor SinRef)) or sib_in;
        				-- Perr <= Parityerror  
        				RX_Perr <= rx_Parity;  
        				RX_done <= H;  			-- ready for read 
        				o_int	<= RX_Int;
        		end case;
        	end if;      
        	if In_preClk=H then
        		SinRef 	<= sib_in; 
        		sIn_test	<= H;  
        	end if;
        end if;     
    end process sib_rx; 
    ----------------------------------------------------------------------------
	-- data load and shiftregister
	----------------------------------------------------------------------------  	
	process(Reset, Clk)
	begin 
        if (Reset = '1') then
        -- asynch reset statements 
        	DataSR 		<= (others => L);  
        	AddrNData	<= 	L;		 
    		Interrupt	<= 	L;  
    		data_length <= (others => L);  
        elsif rising_edge(Clk) then
        -- clocked statements             
        	if Out_Clk=H then 
        		if TX_state=TX_Data_bits then   
        			data_length <= data_length - 1;      
        		end if;  
        		if start=H and tx_done=H then  	-- new data to send  
        			AddrNData	<= TX_Reg(31);		 
    				Interrupt	<= TX_Reg(30);
        		    DataSR		<= TX_Reg(DEF_DATA_LENGTH-1 downto 0);
        		    data_length <= TX_Reg(28 downto 24);  
        		end if;				
        	end if;
        	if In_Clk=H then                 
        		-- shiftregister                  
        		if shift=H then   
        			DataSR <= DataSR(DEF_DATA_LENGTH-2 downto 0) &  (sib_in and rx_shift);
        		end if;	
        	end if;    
        end if;
	end process; 
end behavior_SERIAL_IMP_BUS;                              -- END of architecture      
-------------------------------------------------------------------------------- 
