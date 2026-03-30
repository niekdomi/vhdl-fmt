--------------------------------------------------------------------------------
--
--  INFO-LINK (for SAC)
--
--------------------------------------------------------------------------------
--
--  project     : VirtexIIpro Tests
--  programmer  : C. Leuthold, INDEL AG
--  date        : 10.09.2003
--  version     : 1.00
--  language    : VHDL 
--  system      : ISE 5.2e
--
--  purpose
--    
--
--------------------------------------------------------------------------------
--	17.05.2004-le : - adjustment for pasiv imp  
--	16.07.2004-le : - i_impbusGoNRst as synch reset for inst. serial_imp_bus Rev1.1
--	11.05.2007-le : - add svn keywords
--	11.05.2010-le : - C_PASIV_IMP=1: add crc error to restore/update sequence
--					- add o_wait_at_end: H when telg lng = 31 (wait mode)
--------------------------------------------------------------------------------
--$Rev:: 1431                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2010-05-20 09:08:05 +0200 (Do., 20 Mai 2010)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
----- includes -----------------------------------------------------------------
--------------------------------------------------------------------------------	
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ieee.std_logic_arith.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dpr2IMPsBus is  
	generic (  
	    C_PASIV_IMP		: integer := 0;   
		C_DPR_AWIDTH	: integer := 8;
		C_CYCLECNT_ON 	: integer := 0;
		C_DATA_ONLY	    : integer := 1;
        C_RX_OFFSET     : integer := 0;--x"50";   --2/3*512-256   
        --C_RX_OFFSET     : STD_LOGIC_VECTOR := x"50";   --2/3*512-256  
        -- frequenz(i_Clk)/C_CLK_DIV = 11 MHZ          
		C_CLK_DIV		: integer := 8;  			-- 88/11=8  
    	-- (1+C_OUT_DELAY)*periode(i_Clk)   
    	C_OUT_DELAY 	: integer := 2;				-- Output after 3*11ns
    	C_IN_PRE_SAMPLE : integer := 3      		-- 3 Clk before In_Clk 
	);
	port (     
		-- std-ports
		i_Clk		: in 	std_logic;
		i_Rst		: in 	std_logic;				-- high-activ  
		-- dprPORT 
		o_dprEN		: out 	STD_LOGIC;
		o_dprClk	: out 	STD_LOGIC; 
		o_dprRst	: out 	STD_LOGIC;  
		o_dprData	: out 	STD_LOGIC_VECTOR(31 downto 0);
		i_dprData	: in 	STD_LOGIC_VECTOR(31 downto 0);
	    o_dprAddr	: out 	STD_LOGIC_VECTOR(C_DPR_AWIDTH-1 downto 0);
		o_dprWEN	: out 	STD_LOGIC_VECTOR(3 downto 0); 
		-- PPC interups
		o_sBusInt 	: out	std_logic;	
		o_TXrestartInt 	: out	std_logic;
		o_RXendInt	: out	std_logic;
		-- sBus   
		ni_SIB_in 	: in	std_logic;
		no_SIB_out	: out	std_logic;
		no_SIB_Clk	: out	std_logic;
		no_SIB_Sel	: out	std_logic; 
		-- ctrl
		i_impbusGoNRst : in	std_logic;
		o_wait_at_end : out std_logic
	);
end dpr2IMPsBus;

architecture Behavioral of dpr2IMPsBus is   
-- component declarations ------------------------------------------------------    
	component SERIAL_IMP_BUS    
    port ( 
        i_Clk       : in    std_logic;                  -- clock input
        i_Reset     : in    std_logic;                  -- reset input L-active    
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
        i_sib_Clk 	: in 	std_logic;                  -- sBusClk 5,5 MHz 1:1
        i_Out_Clk   : in 	std_logic;                  -- sBus Output Clk
        i_In_Clk    : in 	std_logic;                  -- sBus Input Sample Clk
        i_In_preClk : in 	std_logic                   -- sBus Input filter Clk
    );
	end component;    
-- constants -------------------------------------------------------------------
    constant H          : std_logic := '1';
    constant L          : std_logic := '0';
    constant Z          : std_logic := 'Z';  
    --constant  NULLS		: std_logic_vector(C_DPR_AWIDTH-1 downto 8) := 0    
    constant RX_OFFSET	: std_logic_vector(C_DPR_AWIDTH-2 downto 0) := CONV_STD_LOGIC_VECTOR(C_RX_OFFSET,C_DPR_AWIDTH-1);
-- types -----------------------------------------------------------------------
    type t_state is (idle, write, read, preread, restore1, restore2);	
-- signals ---------------------------------------------------------------------
    signal Reset    	: std_logic;					-- inverse of ni_Reset 
    signal Clk    		: std_logic;    
    -- imp-serial-Bus
    signal sib_Data_in  : std_logic;                            
    signal sib_Data_out : std_logic;                        
    signal sib_Select 	: std_logic;                        
    signal sib_Clock  	: std_logic; 
    -- clock div  
    signal srCnt		: std_logic_vector(C_CLK_DIV-1 downto 0);  
    signal sib_Clk		: std_logic;  
    signal Out_Clk      : std_logic;
    signal In_Clk       : std_logic;
    signal In_preClk	: std_logic;         
    -- ctrl signals
    signal Start	    : std_logic;
    signal tx_done      : std_logic;
    signal rx_done      : std_logic;   
    
    signal state		: t_state; 
    signal TX_Reg		: std_logic_vector(31 downto 0);
    signal RX_Reg		: std_logic_vector(31 downto 0); 
    
    signal sBusInt		: std_logic;
    signal TXrestartInt : std_logic;
    signal RXendInt		: std_logic;
    
    signal RX_Addr      : std_logic_vector(C_DPR_AWIDTH-2 downto 0); 
    signal TX_Addr      : std_logic_vector(C_DPR_AWIDTH-1 downto 0); 

    signal CycleCnt		: std_logic_vector(31 downto 0);    

    signal rx_addr_rst  : std_logic;         
    signal zero_job		: std_logic;
    signal rx_ack       : std_logic;  
    signal toggle		: std_logic_vector(1 downto 0);
    signal serial_imp_bus_sync_rst : std_logic;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin									-- of architecture behavior_IMP_SBUS_TOP   
	Reset		<= i_Rst;	
    Clk			<= i_Clk;      

    sib_Data_in <= not(ni_SIB_in);  
    no_SIB_out	<= not(sib_Data_out); 
    no_SIB_Clk	<= not(sib_Clock);    
    no_SIB_Sel	<= not(sib_Select);  
      
    o_sBusInt		<= sBusInt 		; 
    o_TXrestartInt  <= TXrestartInt	;
    o_RXendInt  	<= RXendInt		;
    ----------------------------------------------------------------------------
	-- generate sib_Clk, Out_Clk, In_Clk and In_preClk   
	-- example: 88 MHz           
    -- C_CLK_DIV		= 8;       
    -- C_OUT_DELAY 		= 2;        
    -- C_IN_PRE_SAMPLE 	= 3; 
	--
	-- sib_clk   ________--------________--------________--------________-------
	-- Out_Clk   __________-_______________-_______________-_______________-____
	-- In_Clk    _______-_______________-_______________-_______________-_______
	-- In_preClk ____-_______________-_______________-_______________-__________
	-- Clk       012345670123456701234567012345670123456701234567012345670123456
	----------------------------------------------------------------------------      
    Out_Clk 	<= srCnt(C_OUT_DELAY) 				 and     sib_Clk; 
    In_Clk    	<= srCnt(C_CLK_DIV-1                )and not sib_Clk;
    In_preClk 	<= srCnt(C_CLK_DIV-1-C_IN_PRE_SAMPLE)and not sib_Clk;
    sBusClk : process(Reset, Clk)
    begin   
    	if (Reset = '1') then
        -- asynch reset statements     
    		srCnt <= (others => L); 
    		sib_Clk 	<= L;       
    	elsif rising_edge(Clk) then
        -- clocked statements
        	if srCnt=0 then
        		srCnt(0) <= H;
        	else   
        		srCnt <= srCnt(srCnt'length-2 downto 0)&srCnt(srCnt'length-1);
        	end if;	 
        	if srCnt(C_CLK_DIV-1)=H then
        		if sib_Clk=L then
        			sib_Clk <= H; 
        		else
        			sib_Clk <= L;
        		end if; 
        	end if;
        end if; 
    end process sBusClk; 
    
    -- dual port ram -----------------------------------------------------------
    o_dprRst	<= Reset;             
    o_dprClk	<= i_Clk; 
	dpr : process(i_Clk)
	begin
		if rising_edge(i_Clk) then   
			o_dprWEN 	<= (others => '0');
            o_dprEN 	<= L; 
            sBusInt		<= L; 
            TXrestartInt<= L;
            RXendInt    <= L;
            rx_ack      <= L;
            if i_impbusGoNRst=L or i_Rst=H then 
            	serial_imp_bus_sync_rst <= H;
            	state 		<= idle;   
				start  		<= L;
            	zero_job	<= H; 
            	rx_addr_rst <= L; 
            	TX_Reg      <= (others => '0');
            	if C_DATA_ONLY=1 then  
            	    RX_Addr     <= RX_OFFSET;
            	else
            	    RX_Addr     <= (others => '0');
            	end if;
            	TX_Addr     <= (others => '0');
            	if C_CYCLECNT_ON=1 then
            		CycleCnt	<= (others => '0'); 
            	end if; 
            	toggle			<= (others => '0');  
            	o_dprData 		<= (others => '0');
            	o_wait_at_end <= L;
            else 
            	serial_imp_bus_sync_rst <= L;
				case state is
				  when idle =>                           
					if rx_done=H then 						-- write to dpr
            	        rx_ack <= H;
						if C_DATA_ONLY=1 then    
							if RX_Reg(31)=L then            -- only data    
								o_dprAddr 	<= '1' & RX_Addr;  
								o_dprData 	<= RX_Reg; 
            	        		o_dprEN 	<= H;   
            	        		if C_PASIV_IMP=1 and (RX_Reg(27)=H or RX_Reg(26)=H or RX_Reg(25)=H) then
            	        			-- if framing, parity or crc error, then update only status RX_Reg(31 downto 24) 
            	        			-- C_PASIV_IMP: no byteenables -> read, modified, write 
            	        			-- IMP2: software do it
            	        			state 	<= restore1;                      
            	        		else
            	        			o_dprWEN 	<= "1111";
									state 		<= write; 
								end if;
							elsif rx_addr_rst=H then 
								state 		<= write; 
							end if;
						else                       			-- data and addr
							o_dprAddr 	<= '1' & RX_Addr; 
							o_dprData 	<= RX_Reg; 
							o_dprWEN 	<= "1111";
            	        	o_dprEN 	<= H;
							state 		<= write;
						end if;               
						sBusInt		<= RX_Reg(30);
					elsif tx_done=H then					-- read from dpr  
            	        if start=L then 
            	            if C_DATA_ONLY=1 then
				  	            o_dprAddr 	<= TX_Addr; 
            	            else
            	                o_dprAddr 	<= '0' & TX_Addr(C_DPR_AWIDTH-2 downto 0);
            	            end if;
            	            o_dprEN 	<= H; 
						    state 		<= preread;
					    end if;	
            	    else  
				  		start  	<= L;
					end if;	    
				when restore1 =>    
					state 	<= restore2; 
				when restore2 =>   	   
					o_dprData 	<= RX_Reg(31 downto 24) & i_dprData(23 downto 0); 
					o_dprWEN 	<= "1111";
            	    o_dprEN 	<= H;
					state 		<= write;			
            	when preread => 
            	    state <= read;
				when read =>  
					state 		<= idle;
					o_wait_at_end <= L;
            	    if (i_dprData(28 downto 24)=0) and C_PASIV_IMP=0 then 
            	        toggle(0) <= i_dprData(0);
            	        toggle(1) <= toggle(0);   
            	        if (toggle(0)/=toggle(1) or toggle(0)/=i_dprData(0)) then
            	        	TX_Addr     <= (others => '0');  
            	        	TXrestartInt<= not(zero_job); 	-- only if first job not zero
            	        	zero_job	<= H;
            	        	rx_addr_rst <= H;
            	        else
            	        	-- wait and read again
            	        end if;  
            	    elsif (i_dprData(28 downto 24)="11111")
            	      or (C_DATA_ONLY=1 and TX_Addr>=(H&RX_OFFSET)) then
            	    	-- wait and read again  
            	    	o_wait_at_end <= H;
            	    else       
            	    	zero_job	<= L;
            	        TX_Addr 	<= TX_Addr + 1;
            	        start  		<= H;  
            	        TX_Reg 		<= i_dprData; 
            	    end if;
				when write => 
					state <= idle;
            	    rx_addr_rst <= L;
            	    if rx_addr_rst=H then
            	        if C_DATA_ONLY=1 then  
            	            RX_Addr     <= RX_OFFSET;
            	        else
            	            RX_Addr     <= (others => '0');
            	        end if;
            	        RXendInt	<= H;  
            	        if C_CYCLECNT_ON=1 then
            	        	CycleCnt	<= CycleCnt + 1;
            	        	o_dprAddr 	<= (others => '1');  
							o_dprData 	<= CycleCnt; 
							o_dprWEN 	<= "1111";
            	        	o_dprEN 	<= H;
            	       	end if;
            	    else
            	        RX_Addr <= RX_Addr + 1;
            	    end if;
				end case;
			end if;  
		end if;	                   
	end process;     
    
	seial_imp_bus : SERIAL_IMP_BUS          
    port map( 
        i_Clk       => Clk        	,--in   std_logic;            
        i_Reset     => serial_imp_bus_sync_rst     	,--in   std_logic;                
        i_TX_Reg	=> TX_Reg	 	,--in	std_logic_vector(31 downto 0);
        o_RX_Reg	=> RX_Reg	 	,--out	std_logic_vector(31 downto 0);
        i_sib_Data  => sib_Data_in  ,--in	std_logic;
        o_sib_Data  => sib_Data_out ,--out	std_logic;
        o_sib_Select=> sib_Select 	,--out	std_logic;
        o_sib_Clock => sib_Clock  	,--out	std_logic; 
        i_Start		=> Start		,--in 	std_logic;
        o_tx_done	=> tx_done		,--out	std_logic;
        o_rx_done	=> rx_done		,--out	std_logic;
        i_rx_ack	=> rx_ack       ,--in 	std_logic;
        o_int		=> open         ,--out 	std_logic;                        
        i_sib_Clk 	=> sib_Clk		,--in 	std_logic;
        i_Out_Clk   => Out_Clk		,--in 	std_logic;
        i_In_Clk    => In_Clk 		,--in 	std_logic;
        i_In_preClk => In_preClk 	 --in 	std_logic 
    );
	
end Behavioral;