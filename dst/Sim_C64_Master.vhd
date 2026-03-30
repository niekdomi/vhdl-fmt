--------------------------------------------------------------------------------
--
--  Testbench for C64_BusMaster
--
--------------------------------------------------------------------------------
--
--  project     : GIN_LINK
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

LIBRARY C64_Master;
USE C64_Master.ALL;
LIBRARY C64_Slave;
USE C64_Slave.ALL;


--------------------------------------------------------------------------------
ENTITY Sim_C64_Master IS
END Sim_C64_Master;

ARCHITECTURE tst OF Sim_C64_Master IS 

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	
	signal BRAM_Clk 		: std_logic;
	signal BRAM_EN 			: std_logic;
	signal BRAM_WEN 		: std_logic_vector( 7 downto 0);
	signal BRAM_Addr 		: std_logic_vector(15 downto 0);
	signal BRAM_Dout 		: std_logic_vector(63 downto 0);          

	signal t 				: std_logic_vector(31 downto 0) := x"00000000";          


	signal b_C64_DatBus		: std_logic_vector(15 downto 0) := x"0000";		
	signal nb_C64_Ack		: std_logic := '0';		

	signal Mas_HT			: std_logic := '0';
	signal Mas_LT			: std_logic := '0';

--------------------------------------------------------------------------------
	signal Mas_C64_CLK		: std_logic := '0';
	signal Mas_C64_SEL		: std_logic := '0';	
	signal Mas_C64_Dat_HOE	: std_logic := '0';	
	signal Mas_C64_Dat_LOE	: std_logic := '0';	
	signal Mas_C64_Ack_OE	: std_logic := '0';	
	signal Mas_C64_Bend		: std_logic := '0';	
	signal Mas_C64_WrDat	: std_logic_vector(15 downto 0) := x"0000";		
	signal Mas_C64_Ack		: std_logic := '0';	
--------------------------------------------------------------------------------
    signal Q125 			: std_logic := '0';
    signal TlgIrq 			: std_logic_vector( 7 downto 0)	:= x"00";
	
--------------------------------------------------------------------------------
	signal Slv_AddrSw		: std_logic_vector( 3 downto 0) := x"0";

	signal Slv_Inp			: std_logic_vector(15 downto 0) := x"0000";
    signal Slv_Out			: std_logic_vector(15 downto 0) := x"0000";
    signal Slv_B0_24V		: std_logic := '0';
    signal Slv_B1_24V		: std_logic := '0';

    signal Slv_C64_CLK		: std_logic := '0';
    signal Slv_C64_nCLK		: std_logic := '0';
    signal Slv_C64_SEL		: std_logic := '0';
    signal Slv_C64_Bend		: std_logic := '0';
    signal Slv_C64_Reset	: std_logic := '1';
    signal Slv_C64_WrDat	: std_logic_vector(15 downto 0) := x"0000";
    signal Slv_C64_OE		: std_logic := '0';
    signal Slv_C64_Ack		: std_logic := '0';


	signal	JTAG_TCK        : std_logic := '0';
    signal	JTAG_TMS		: std_logic := '0';
    signal	JTAG_TDI		: std_logic := '0';
    signal	JTAG_TDO		: std_logic := '0';
    signal	JTAG_TDOdl		: std_logic := '0';

	signal	ENC_A		: std_logic_vector(5 downto 0) := (others => '0');
	signal	ENC_B		: std_logic_vector(5 downto 0) := (others => '0');
	signal	ENC_N		: std_logic_vector(5 downto 0) := (others => '0');
	
	signal adc_rd       : std_logic := '0';
	signal adc_soc       : std_logic := '0';
	signal adc_fdat       : std_logic := '0';
	signal adc       : std_logic_vector(15 downto 0) := (others => '0');
	signal adc_busy         : std_logic;

--------------------------------------------------------------------------------
	signal MEM_Adr 	: std_logic_vector(15 downto 0) := X"01FE";
	type tMEM is array(0 to 511) of  std_logic_vector(31 downto 0);
   	signal MEM : tMEM := (       


--------------------------------------------------------------------------------
--	Diese Daten wurden von Hand gemacht ;-)
--------------------------------------------------------------------------------
--	Das Ram-Layout ist dem GinSlave DP-RAM angepasst.
--
--	Die C64-CommmandTab benötigt neben dem freien 300'er Bereich noch einen
--	Teil vom TxBuffer.
--	Da dieser aber kaum je gefüllt ist, wird mal abgenommen, dass der Bereich
--		600-6FF 
--	als Nutzdaten-TxBuffer ausreicht.
--------------------------------------------------------------------------------
--	Gin EEPROM
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",	-- 0000  
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  
  x"80014011",x"87654321",x"89abcdef",x"fedcba98",x"00000000",x"00000000",x"00000000",x"00000000", 	-- 080
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",

  x"80014011",x"0080fff1",x"00c01000",x"18000140",x"c010ffff",x"0006ffff",x"0080ffff",x"0034ffff",
  x"0001ffff",x"a000ffff",x"0d00ffff",x"006cffff",x"00606680",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",

--	Gin Status
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",	-- 0180
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",

--	Gin Page AdrComp  
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",	-- 0200
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
    
--	C64 Command-Tab
  x"80300C35",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",	-- 0300  

--  ATTTCMAA    ..NN.AAA
  x"80007419",x"00010600",	-- write Mod 4, Adresse 19, from 0x600  
  x"800074E0",x"00010602",  -- ADC_Status	
  x"800074E1",x"00010604",	-- PGA_Status
  x"80007003",x"00010606",  
   
  x"80007440",x"00010620",	-- U0	
  x"80007441",x"00010622",	-- U1
  x"80007442",x"00010624",	-- IMAX0 
  x"80007443",x"00010626",  -- IMIN0
   
  x"80007444",x"00010628",	-- UMAX0	
  x"80007445",x"0001062A",	-- UMAX1
  x"800072E2",x"0001062C",	
  x"80007220",x"0020062E",  
                              
  x"80007300",x"00010660",	-- write to Mod-3	
  x"80007301",x"00010662",	
  x"80007302",x"00010664",	
  x"80007303",x"00010666",  
                              
                              
  x"83003000",x"00010A00",	-- read to Mod-0	
  x"80003001",x"00010A02",	
  x"80003002",x"00010A04",	
  x"80003003",x"00010A06",  
   
  x"80003100",x"00080A20",	-- read to Mod-1	
  x"800031FC",x"00010A40",	
  x"800031E0",x"00040A50",	
  x"800031F8",x"00010A60",  
   
  x"80003400",x"00020B00",	-- read to Mod-2	
  x"800032FC",x"00010A00",	
  x"800032FE",x"00010A00",	
  x"80003220",x"00100B40",  

--	TxBuffer (auch noch als CmdTab benutzt)  
  x"48200002",x"80000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",	-- 0400           
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",          
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",	-- 0500
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",

	-- (Tx Nutzdaten)  
  x"000A1234",x"00789ABC",x"00000000",x"00000000",x"00000000",x"00000000",x"C0CCD0DD",x"E2EEF0FF",	-- 0600
  x"40006000",x"3FFF3FFF",x"3FFF3FFF",x"77778888",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"800E0001",x"00000000",x"00000000",x"00000000",
  x"00081234",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
           
  x"11110880",x"10181000",x"20180200",x"00000000",x"40000000",x"00000000",x"00000000",x"00000000",	-- 0700
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",
  x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000",x"00000000"
  
  );

--------------------------------------------------------------------------------
	constant CLK125_PERIOD : time := 8 ns;			 
	constant CLK80_PERIOD : time := 12.5 ns;			 
	constant H : std_logic := '1';
	constant L : std_logic := '0';

	constant E_PERIOD : time := 250 ns;			 

--------------------------------------------------------------------------------
BEGIN
--------------------------------------------------------------------------------
	
--------------------------------------------------------------------------------
-- extern 125MHz Clock
--------------------------------------------------------------------------------
	process begin
		Q125 	<= H;
		wait for (clk125_period/2);
		Q125 	<= L;
		wait for (clk125_period/2);
	end process;

--------------------------------------------------------------------------------
--	Encoder-0
--------------------------------------------------------------------------------
	process begin 
        wait for E_PERIOD;
	    ENC_A(0) <= H;
	    ENC_B(0) <= L;
        wait for E_PERIOD;
	    ENC_A(0) <= H;
	    ENC_B(0) <= H;
        wait for E_PERIOD;
	    ENC_A(0) <= L;
	    ENC_B(0) <= H;
        wait for E_PERIOD;
	    ENC_A(0) <= L;
	    ENC_B(0) <= L;
	end process;	
	
	process begin 
        wait for 493 us;
		ENC_N(0) <= H;
        wait for E_PERIOD;
	    ENC_N(0) <= L;
	end process;	
	
--------------------------------------------------------------------------------
--	Encoder-1
--------------------------------------------------------------------------------
	process begin 
        wait for E_PERIOD;
	    ENC_A(1) <= L;
	    ENC_B(1) <= H;
        wait for E_PERIOD;
	    ENC_A(1) <= H;
	    ENC_B(1) <= H;
        wait for E_PERIOD;
	    ENC_A(1) <= H;
	    ENC_B(1) <= L;
        wait for E_PERIOD;
	    ENC_A(1) <= L;
	    ENC_B(1) <= L;
	end process;	
	
	process begin 
        wait for 533 us;
		ENC_N(1) <= H;
        wait for E_PERIOD;
	    ENC_N(1) <= L;
	end process;	
	
	    ENC_A(2) <= L;
	    ENC_B(2) <= H;
	    ENC_N(2) <= L;

	    ENC_A(3) <= L;
	    ENC_B(3) <= H;
	    ENC_N(3) <= L;

--------------------------------------------------------------------------------
--	Encoder-4
--------------------------------------------------------------------------------
	    ENC_A(4) <= L;
	    ENC_B(4) <= H;
	
	process begin 
        wait for 666 us;
		ENC_N(4) <= H;
        wait for E_PERIOD;
	    ENC_N(4) <= L;
	end process;	

	    ENC_A(5) <= L;
	    ENC_B(5) <= H;
	    ENC_N(5) <= L;

--------------------------------------------------------------------------------
--	8kHz Tlg IRQ
--------------------------------------------------------------------------------
	process begin 
		-- 8kHz - clk125_period
        wait for 124992 ns;
		TlgIRQ <= x"08";		
        wait for clk125_period;
		TlgIRQ <= x"00";
		-- 8kHz - clk125_period
        wait for 124992 ns;
		TlgIRQ <= x"08";		
        wait for clk125_period;
		TlgIRQ <= x"00";

		-- 8kHz - clk125_period
        wait for 124992 ns;
        wait for clk125_period;

		loop             
			-- 8kHz - clk125_period
	        wait for 124992 ns;
			TlgIRQ <= x"08";		
	        wait for clk125_period;
			TlgIRQ <= x"00";
		end loop;	
	end process;	

--------------------------------------------------------------------------------
--	Reset
--------------------------------------------------------------------------------
	process begin 
        wait for 1 ns;
		Slv_C64_Reset <= L;  
		wait for 1 us;
		Slv_C64_Reset <= H;  
        wait for clk125_period;
		Slv_C64_Reset <= L;
		wait;  
	end process;	

--------------------------------------------------------------------------------
--	Memory
--------------------------------------------------------------------------------
	BRAM_Clk <= Q125;
	 
	process (BRAM_Clk,MEM_Adr) begin
		if rising_edge(BRAM_Clk) then
			t <= t + 8;
			if (not (MEM_Adr = x"FFFE")) then
				-- init DP-RAM (64-Bit Data)                  
				BRAM_EN 	<= H;
				BRAM_WEN 	<= "11111111"; 
				BRAM_Dout 	<= MEM(CONV_INTEGER(MEM_Adr)) & MEM(CONV_INTEGER(MEM_Adr+1)); 
				BRAM_Addr 	<= '0' & MEM_Adr(15 downto 1);
				MEM_Adr 	<= MEM_Adr - 2;
			else
				if (t = x"070000") then	
					BRAM_EN 	<= H;
					BRAM_WEN 	<=  "00001111";
					BRAM_Addr 	<= x"00CA"; 
					BRAM_Dout 	<= x"00000000AAAAAAAA";	
			    end if;
			end if; 

		end if;
	end process;
   
-------------------------------------------------------------------------------- 
--	Master <-> Slave interconnection
-------------------------------------------------------------------------------- 
	nb_C64_Ack <= H when Mas_C64_Ack_OE=H else 'Z';

	-- Data from Master to Bus
	MAS_HT <= Mas_C64_Dat_HOE after 1 ns;
	process(MAS_HT,Mas_C64_WrDat) begin
		if (MAS_HT = H) then
			b_C64_DatBus(15 downto 8) <= Mas_C64_WrDat(15 downto 8)	after 500 ps;
		else
			b_C64_DatBus(15 downto 8) <= "ZZZZZZZZ"	after 500 ps;
		end if;
	end process;	

	MAS_LT <= Mas_C64_Dat_LOE after 1 ns;
	process(MAS_LT,Mas_C64_WrDat) begin
		if (MAS_LT = H) then
			b_C64_DatBus( 7 downto 0) <= Mas_C64_WrDat( 7 downto 0)	after 500 ps;
		else
			b_C64_DatBus( 7 downto 0) <= "ZZZZZZZZ"	after 500 ps;
		end if;
	end process;	

    -- delay signals from master to slave        
	Mas_C64_Ack	    <= not Slv_C64_Ack			after 500 ps;

    -- delay signals from slave to master        
	Slv_C64_CLK		<= Mas_C64_CLK			after 500 ps;	
	Slv_C64_nCLK	<= not Mas_C64_CLK		after 500 ps;	
	Slv_C64_SEL	    <= Mas_C64_SEL			after 500 ps;
	Slv_C64_Bend	<= Mas_C64_Bend			after 500 ps;

	Slv_Inp <= Slv_Out;   
	
	process (JTAG_TCK) begin
		if falling_edge(JTAG_TCK) then
			JTAG_TDO <= JTAG_TDI;
		end if;
	end process;		          
	
	JTAG_TDOdl <= transport JTAG_TDI after  95 ns;
	
	
	
	process  begin
		wait until rising_edge(adc_soc);
		    adc_busy <= '1';
		wait for 1 us;
		    adc_busy <= '0';
		    adc <= x"5555";     
  		    adc_fdat <= '0';
		wait until rising_edge(adc_rd);
		    adc <= x"1000";     -- Current
		    adc_fdat <= '1';
		wait until rising_edge(adc_rd);
		    adc <= x"1100";     -- Current
		    adc_fdat <= '0';
		wait until rising_edge(adc_rd);
		    adc <= x"7300";
		wait until rising_edge(adc_rd);
		    adc <= x"7400";
		wait until rising_edge(adc_rd);
		    adc <= x"7500";
		wait until rising_edge(adc_rd);
		    adc <= x"7600";
		wait until rising_edge(adc_rd);
		    adc <= x"7700";
		wait until rising_edge(adc_rd);
		    adc <= x"7800";
	end process;		          
	
	
	
	
	process (adc_rd) begin
		if rising_edge(adc_rd) then
			JTAG_TDO <= JTAG_TDI;
		end if;
	end process;		          
	
	
	
	
	
	
	
--------------------------------------------------------------------------------
--	C64 BusMaster instance
--------------------------------------------------------------------------------
	uSIM_C64Mas: entity C64_Master.C64Mas_Wrap  
    generic map (
        g_fpga_type     => 0, -- 0 = Xilinx, 1 = Altera
        -- passive GinLink Slave ? (or DPR to PowerPC)
        g_GinPasSlv	    => 0
    )
	PORT MAP(
		i_Q125 			=> Q125 			,
		i_TlgIrq		=> TlgIrq			,
		            	                	
		i_BRAM_Clk 		=> BRAM_Clk	 		,
		i_BRAM_EN		=> BRAM_EN			,
		i_BRAM_WEN 		=> BRAM_WEN 		,
		i_BRAM_Addr 	=> BRAM_Addr 		,
		i_BRAM_Dout 	=> BRAM_Dout 		,
                                        	
        -- C64-Bus                      	
		o_C64_CLK		=> Mas_C64_CLK  	,
		o_C64_SEL		=> Mas_C64_SEL  	,
		o_C64_Dat_HOE	=> Mas_C64_Dat_HOE  ,
		o_C64_Dat_LOE	=> Mas_C64_Dat_LOE  ,
		o_C64_Ack_OE	=> Mas_C64_Ack_OE  	,
		o_C64_Bend		=> Mas_C64_Bend 	,
		o_C64_WrDat		=> Mas_C64_WrDat	,
		i_C64_RdDat		=> b_C64_DatBus		,		
		i_C64_Ack		=> Mas_C64_Ack		,
		
		i_c64_i2c_sda => H,
		i_c96_i2c_sda => H
	);                      

--------------------------------------------------------------------------------
--	C64 PTC instance
--------------------------------------------------------------------------------
	uSIM_C64_PTC: entity C64_Slave.C64_PTC
	PORT MAP (
		i_AddrSw		=> x"4"				,
      ni_hwRev   => x"F" ,
		i_C64_CLK		=> Slv_C64_CLK		,
		ni_C64_CLK		=> Slv_C64_nCLK		,
		i_C64_SEL		=> Slv_C64_SEL		,
		b_C64_DatBus	=> b_C64_DatBus		, 
		no_C64_Ack		=> nb_C64_Ack		,
		i_C64_Bend		=> Slv_C64_Bend		,
		i_C64_Reset		=> Slv_C64_Reset	,
		                                	
		o_JTAG_TCK		=> JTAG_TCK     	,
		o_JTAG_TMS		=> JTAG_TMS     	,
		o_JTAG_TDI		=> JTAG_TDI     	,
		i_JTAG_TDO		=> JTAG_TDOdl       ,
		
		no_ADC_RD       => adc_rd             ,
		 o_ADC_SOC      => adc_soc            ,
		 o_ADC_OS       => open             ,
		no_ADC_StBy     => open             ,
		 o_ADC_Range    => open             ,
		 o_ADC_Reset    => open             ,
		 
		 i_ADC_Busy     => adc_busy         ,
		 i_ADC_Fdat     => adc_fdat         ,
		 i_ADC_Dat      => adc              ,
		
		
		o_IMUX_EN       => open             ,
		o_IMUX          => open             ,
		o_VMUX_EN       => open             ,
		o_VMUX          => open             ,
		
		o_PGA_GAIN      => open             ,
		
		o_OUT           => open             ,
		i_INP           => "LH"             ,
		
	    o_PWM_A         => open             ,
		o_PWM_B		    => open             ,
		o_PWM_C		    => open             ,
		o_PWM_D		    => open             ,
	   no_Reset_AB		=> open             ,
	   no_Reset_CD	    => open             ,
	   ni_Fault         => 'H'              ,
	   ni_OTW           => 'H'              ,
		o_PWM_Mode		=> open             
	);                      

--------------------------------------------------------------------------------
--	C64 BusSlave instance
--------------------------------------------------------------------------------
	uSIM_C64_IO: entity C64_Slave.C64_IO
	PORT MAP (
		i_AddrSw		=> x"0"				,
		ni_Inp			=> Slv_Inp			,
		ni_B0_24V		=> Slv_B0_24V		,
		ni_B1_24V		=> Slv_B1_24V		,
		o_Out			=> Slv_Out			,
		ni_hwrev => "000",                          	
		i_C64_CLK		=> Slv_C64_CLK		,
		ni_C64_CLK		=> Slv_C64_nCLK		,
		i_C64_SEL		=> Slv_C64_SEL		,
		b_C64_DatBus	=> b_C64_DatBus		, 
		no_C64_Ack		=> nb_C64_Ack		,
		i_C64_Bend		=> Slv_C64_Bend		,
		i_C64_Reset		=> Slv_C64_Reset	,
		                                	
		o_JTAG_TCK		=> JTAG_TCK     	,
		o_JTAG_TMS		=> JTAG_TMS     	,
		o_JTAG_TDI		=> JTAG_TDI     	,
		i_JTAG_TDO		=> JTAG_TDOdl             
	);                      

--------------------------------------------------------------------------------
END;
