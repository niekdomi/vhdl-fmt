--------------------------------------------------------------------------------
--  OPB_uart_Core.vhd
--------------------------------------------------------------------------------
--
--  project     : ppc-module
--  programmer  : C. LEuthold, INDEL AG
--  date        : 17.11.2003
--  version     : 1.00
--  language    : VHDL 
--  system      : ISP/EDK 6.1
--
--  purpose
--    
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
-- 	Rev. 1.00	:	17.11.2003-le  : new component Baud_Rate       
--					13.01.2005-le  : add o_485_RnW 
--	11.05.2007-le	add svn keywords
--	09.01.2008-le	reset status at reset_RX_FIFO
--------------------------------------------------------------------------------
--$Rev:: 300                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2008-01-09 10:21:50 +0100 (Mi., 09 Jan 2008)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL; 

entity OPB_uart_Core is
  generic (    
  	C_485_SUPPORT: integer range 0 to 1 := 0;
    C_DATA_BITS  : integer range 7 to 8 := 8;
    C_CLK_FREQ   : integer              := 125_000_000;
    C_BAUDRATE   : integer              := 9600;
    C_USE_PARITY : integer              := 1;
    C_ODD_PARITY : integer              := 1
    );
  port (
    Clk   : in std_logic;
    Reset : in std_logic;

    UART_CS : in std_logic;

    -- OPB signals
    OPB_ABus : in std_logic_vector(0 to 2);
    OPB_RNW  : in std_logic;
    OPB_DBus : in std_logic_vector(0 to 31);

    SIn_xferAck : out std_logic;
    SIn_DBus    : out std_logic_vector(0 to 31);

    -- UART signals
    RX        : in  std_logic;
    TX        : out std_logic;
    Interrupt : out std_logic;
    o_txInterrupt : out std_logic;
    o_rxInterrupt : out std_logic;
    o_485_RnW	: out std_logic;
    i_sioRTS   : in  std_logic;
    o_sioCTS   : out std_logic;
    o_TP1	: out std_logic;
    o_TP2	: out std_logic;
    o_TP3	: out std_logic;
    o_TP4	: out std_logic
    );

end entity OPB_uart_Core;

library unisim;
use unisim.all;

architecture IMP of OPB_uart_Core is
  constant C_DATA_BITS_MAX : integer := 8;
  component Baud_Rate is
    port (
      Clk         : in  std_logic;
      EN_16x_Baud : out std_logic;
      i_ratio	  : in std_logic_vector(15 downto 0));	--ClkFreq/(16*baudrate)
  end component Baud_Rate;

  component OPB_uart_RX is
    --generic (
    --  C_DATA_BITS  : integer range 5 to 8;
    --  C_USE_PARITY : integer;
    --  C_ODD_PARITY : integer);
    port (
      Clk         : in std_logic;
      Reset       : in std_logic;
      EN_16x_Baud : in std_logic;

      RX               : in  std_logic;
      Read_RX_FIFO     : in  std_logic;
      Reset_RX_FIFO    : in  std_logic;
      RX_Data          : out std_logic_vector(0 to C_DATA_BITS_MAX-1);
      RX_Data_Present  : out std_logic;
      RX_BUFFER_FULL   : out std_logic;
      RX_Frame_Error   : out std_logic;
      RX_Overrun_Error : out std_logic;
      RX_Parity_Error  : out std_logic;
      i_data_bits	   : in  std_logic_vector(0 to 1); 
      i_use_parity 	   : in  std_logic;      
  	  i_odd_parity 	   : in  std_logic;
      i_Int_nr_of_Data : in  std_logic_vector(0 to 3); 
      o_RX_nr_of_Data  : out std_logic_vector(0 to 3); 
      o_rxInt          : out std_logic);
  end component OPB_uart_RX;

  component OPB_uart_TX is
    generic (  
    	C_485_SUPPORT: integer range 0 to 1 := 0
    --  C_DATA_BITS  : integer range 5 to 8;
    --  C_USE_PARITY : integer;
    --  C_ODD_PARITY : integer
    );
    port (
      Clk         : in std_logic;
      Reset       : in std_logic;
      EN_16x_Baud : in std_logic;

      TX              : out std_logic;
      Write_TX_FIFO   : in  std_logic;
      Reset_TX_FIFO   : in  std_logic;
      TX_Data         : in  std_logic_vector(0 to C_DATA_BITS_MAX-1);
      TX_Buffer_Full  : out std_logic;
      TX_Buffer_Empty : out std_logic;                   
      o_485_RnW		   : out std_logic;
      i_485_DELAY      : in  std_logic_vector(3 downto 0);
      i_data_bits	   : in  std_logic_vector(0 to 1); 
      o_TX_nr_of_Data  : out std_logic_vector(0 to 3);
      i_use_parity 	   : in  std_logic;      
  	  i_odd_parity 	   : in  std_logic);
  end component OPB_uart_TX;

  component FDRE is
    port (
      Q  : out std_logic;
      C  : in  std_logic;
      CE : in  std_logic;
      D  : in  std_logic;
      R  : in  std_logic);
  end component FDRE;

  component FDR is
    port (Q : out std_logic;
          C : in  std_logic;
          D : in  std_logic;
          R : in  std_logic);
  end component FDR;

  signal en_16x_Baud : std_logic;

  constant RX_FIFO_ADR    : std_logic_vector(0 to 2) := "000";
  constant TX_FIFO_ADR    : std_logic_vector(0 to 2) := "001";
  constant STATUS_REG_ADR : std_logic_vector(0 to 2) := "010";
  constant CTRL_REG_ADR   : std_logic_vector(0 to 2) := "011";   
  constant CONF_REG_ADR   : std_logic_vector(0 to 2) := "100";

  -- Read Only
  signal status_Reg : std_logic_vector(0 to 31);
  -- bit 31 rx_Data_Present
  -- bit 30 rx_Buffer_Full
  -- bit 29 tx_Buffer_Empty
  -- bit 28 tx_Buffer_Full
  -- bit 27 enable_interrupts
  -- bit 26 Overrun Error
  -- bit 25 Frame Error
  -- bit 24 Parity Error (If C_USE_PARITY is true, otherwise '0')
  -- bit 20..23 nr of data in rx fifo
  -- bit 16..19 nr of data in tx fifo

  -- Write Only
  -- Control Register
  -- bit 27   enable_interrupts
  -- bit 30   Reset_RX_FIFO
  -- bit 31   Reset_TX_FIFO

  -- Read-Write
  -- Config Register
  -- bit 31 RTS (read only)
  -- bit 30 CTS 
  -- bit 20..23 nr of data in rx fifo in order to release an interrupt 
  -- bit 19 odd parity
  -- bit 18 use pariti
  -- bit 16.. 17 data bits 5..8
  -- bit 0..15 ratio = BusClkFreq/(16*Baudrate)
  signal Config_Reg : std_logic_vector(0 to 31);  

  signal enable_interrupts : std_logic;
  signal read_RX_FIFO      : std_logic;
  signal reset_RX_FIFO     : std_logic;

  signal rx_Data          : std_logic_vector(0 to C_DATA_BITS_MAX-1);
  signal rx_Data_Present  : std_logic;
  signal rx_BUFFER_FULL   : std_logic;
  signal rx_Frame_Error   : std_logic;
  signal rx_Overrun_Error : std_logic;
  signal rx_Parity_Error  : std_logic;

  signal clr_Status_1 : std_logic;
  signal clr_Status : std_logic;

  signal write_TX_FIFO   : std_logic;
  signal reset_TX_FIFO   : std_logic;
  signal tx_BUFFER_FULL  : std_logic;
  signal tx_Buffer_Empty : std_logic;

  signal tx_Buffer_Empty_Pre : std_logic;

  signal xfer_Ack     : std_logic;
  signal sin_Dbus_i : std_logic_vector(0 to 31);

  signal ratio : std_logic_vector(15 downto 0) := 
  			CONV_STD_LOGIC_VECTOR(C_CLK_FREQ / (16 * C_BAUDRATE),16);

  signal uart_CS_1 : std_logic;         -- Active as long as UART_CS is active
  signal uart_CS_2 : std_logic;         -- Active only 1 clock cycle during an
  signal uart_CS_3 : std_logic;         -- Active only 1 clock cycle during an
                                        -- access

  signal opb_RNW_1 : std_logic;
  signal rxInt : std_logic;
  signal l_485_DELAY      : std_logic_vector(3 downto 0) := (others => '0');
  signal data_bits  : std_logic_vector(0 to 1); 
  signal use_parity : std_logic_vector(0 to 0);      
  signal odd_parity : std_logic_vector(0 to 0);
  signal Int_nr_of_Data : std_logic_vector(0 to 3);
  signal RX_nr_of_Data : std_logic_vector(0 to 3);
  signal TX_nr_of_Data : std_logic_vector(0 to 3);
  signal RTS : std_logic;
  signal CTS : std_logic;
begin  -- architecture IMP
  RTS       <= i_sioRTS;
  o_sioCTS  <= CTS;
  uart_CS_1_DFF : FDR
    port map (
      Q => uart_CS_1,                   -- [out std_logic]
      C => Clk,                         -- [in  std_logic]
      D => UART_CS,                     -- [in  std_logic]
      R => xfer_Ack);                   -- [in std_logic]

  uart_CS_2_DFF: process (Clk, Reset) is
  begin  -- process uart_CS_2_DFF
    if Reset = '1' then                 -- asynchronous reset (active high)
      uart_CS_2 <= '0';
      uart_CS_3 <= '0';
      opb_RNW_1 <= '0';
    elsif Clk'event and Clk = '1' then  -- rising clock edge
      uart_CS_2 <= uart_CS_1 and not uart_CS_2 and not uart_CS_3;
      uart_CS_3 <= uart_CS_2;
      opb_RNW_1 <= OPB_RNW;
    end if;
  end process uart_CS_2_DFF;
  
  -----------------------------------------------------------------------------
  -- Instanciating the BaudRate module
  -----------------------------------------------------------------------------
  Baud_Rate_I : Baud_Rate
    port map (
      Clk         => Clk,				-- [in  std_logic]
      EN_16x_Baud => en_16x_Baud,		-- [out std_logic]
      i_ratio => ratio);				-- [in std_logic_vector(15:0)]

  -----------------------------------------------------------------------------
  -- Status register handling
  -----------------------------------------------------------------------------
  status_Reg(31) <= rx_Data_Present;
  status_Reg(30) <= rx_BUFFER_FULL;
  status_Reg(29) <= tx_Buffer_Empty;
  status_Reg(28) <= tx_BUFFER_FULL;
  status_Reg(27) <= enable_interrupts;
  status_Reg(23) <= RX_nr_of_Data(0);
  status_Reg(22) <= RX_nr_of_Data(1); 
  status_Reg(21) <= RX_nr_of_Data(2);
  status_Reg(20) <= RX_nr_of_Data(3);
  status_Reg(19) <= TX_nr_of_Data(0);
  status_Reg(18) <= TX_nr_of_Data(1);
  status_Reg(17) <= TX_nr_of_Data(2);
  status_Reg(16) <= TX_nr_of_Data(3);    
  
  status_Reg(0)	<= '1' when RX_nr_of_Data=Int_nr_of_Data else '0';


          
  Config_Reg(31)        <= RTS;    
  Config_Reg(30)        <= CTS;
  gen_485_sup : if (C_485_SUPPORT = 1) generate 
	Config_Reg(27)  	<= l_485_DELAY(0);
	Config_Reg(26)      <= l_485_DELAY(1);
	Config_Reg(25)      <= l_485_DELAY(2);
	Config_Reg(24)      <= l_485_DELAY(3);
  end generate gen_485_sup; 
  Config_Reg(23)  		<= Int_nr_of_Data(0); 
  Config_Reg(22)  		<= Int_nr_of_Data(1); 
  Config_Reg(21)  		<= Int_nr_of_Data(2); 
  Config_Reg(20)  		<= Int_nr_of_Data(3); 
  
  
  Config_Reg(19)        <= odd_parity(0);
  Config_Reg(18)        <= use_parity(0);
  Config_Reg(16 to 17)  <= data_bits;
  Config_Reg(0 to 15)   <= ratio;
  
  o_TP1 <= status_Reg(24); -- Parity_Error
  o_TP2 <= status_Reg(25); -- Frame_Error
  o_TP3 <= status_Reg(26); -- OverRun_Error
  o_TP4 <= rx_Data_Present;

  clr_Status_1 <= uart_CS_3 and OPB_RNW_1 when (OPB_ABus = STATUS_REG_ADR)
                else '0';
  clr_Status <= reset_RX_FIFO or clr_Status_1;
  
  OverRun_Error_DFF : FDRE
    port map (
      Q  => status_Reg(26),              -- [out std_logic]
      C  => Clk,                        -- [in  std_logic]
      CE => rx_Overrun_Error,           -- [in  std_logic]
      D  => rx_Overrun_Error,           -- [in  std_logic]
      R  => clr_Status);                -- [in std_logic]

  Frame_Error_DFF : FDRE
    port map (
      Q  => status_Reg(25),              -- [out std_logic]
      C  => Clk,                        -- [in  std_logic]
      CE => rx_Frame_Error,             -- [in  std_logic]
      D  => rx_Frame_Error,             -- [in  std_logic]
      R  => clr_Status);                -- [in std_logic]

 -- Using_Parity : if (C_USE_PARITY = 1) generate
    Parity_Error_DFF : FDRE
      port map (
        Q  => status_Reg(24),            -- [out std_logic]
        C  => Clk,                      -- [in  std_logic]
        CE => rx_Parity_Error,          -- [in  std_logic]
        D  => rx_Parity_Error,          -- [in  std_logic]
        R  => clr_Status);              -- [in std_logic]
 -- end generate Using_Parity;

 -- No_Parity : if (C_USE_PARITY = 0) generate
 --   status_Reg(24) <= '0';
 -- end generate No_Parity;

  -----------------------------------------------------------------------------
  -- Control and config Register Handling 
  -----------------------------------------------------------------------------
  Ctrl_Reg_DFF : process (Clk, Reset) is
  begin  -- process Ctrl_Reg_DFF
    if Reset = '1' then                 -- asynchronous reset (active high)
      reset_TX_FIFO     <= '1';
      reset_RX_FIFO     <= '1';
      enable_interrupts <= '0';
      ratio             <= CONV_STD_LOGIC_VECTOR(C_CLK_FREQ / (16 * C_BAUDRATE),16);   
      if C_DATA_BITS=7 then
      	data_bits		<= "10";
      else 
        data_bits		<= "11"; 
      end if;
      --data_bits         <= CONV_STD_LOGIC_VECTOR(C_DATA_BITS,2);
      use_parity        <= CONV_STD_LOGIC_VECTOR(C_USE_PARITY,1);     
      odd_parity        <= CONV_STD_LOGIC_VECTOR(C_ODD_PARITY,1);
      Int_nr_of_Data    <= "0000";
      CTS               <= '0';
    elsif Clk'event and Clk = '1' then  -- rising clock edge
      reset_TX_FIFO <= '0';
      reset_RX_FIFO <= '0';
      if (uart_CS_2 = '1') and (OPB_RNW_1 = '0') then
       	if (OPB_ABus = CTRL_REG_ADR) then
	   		reset_RX_FIFO     <= OPB_DBus(30);
		    reset_TX_FIFO     <= OPB_DBus(31);
		    enable_interrupts <= OPB_DBus(27);
        elsif (OPB_ABus = CONF_REG_ADR) then
        	ratio   		  <= OPB_DBus(0 to 15); 
            data_bits         <= OPB_DBus(16 to 17); 
            use_parity(0)     <= OPB_DBus(18);     
            odd_parity(0)     <= OPB_DBus(19);
            Int_nr_of_Data(0) <= OPB_DBus(23); 
  			Int_nr_of_Data(1) <= OPB_DBus(22); 
  			Int_nr_of_Data(2) <= OPB_DBus(21); 
  			Int_nr_of_Data(3) <= OPB_DBus(20);
  			if (C_485_SUPPORT = 1) Then 
	  			l_485_DELAY(0)	  <= OPB_DBus(27);
	            l_485_DELAY(1)	  <= OPB_DBus(26);
	            l_485_DELAY(2)	  <= OPB_DBus(25);
	            l_485_DELAY(3)	  <= OPB_DBus(24);
	        end if;
            CTS               <= OPB_DBus(30);
        end if;             
      end if;
    end if;
  end process Ctrl_Reg_DFF;

  -----------------------------------------------------------------------------
  -- Interrupt handling
  -----------------------------------------------------------------------------

  -- Sampling the tx_Buffer_Empty signal in order to detect a rising edge
  TX_Buffer_Empty_FDRE : FDRE
    port map (
      Q  => tx_Buffer_Empty_Pre,        -- [out std_logic]
      C  => Clk,                        -- [in  std_logic]
      CE => '1',                        -- [in  std_logic]
      D  => tx_Buffer_Empty,            -- [in  std_logic]
      R  => write_TX_FIFO);             -- [in std_logic]

  Interrupt_DFF: process (Clk, Reset)
  begin  -- process Interrupt_DFF
    if Reset = '1' then                 -- asynchronous reset (active high)
      Interrupt <= '0';
    elsif Clk'event and Clk = '1' then  -- rising clock edge
      Interrupt <= enable_interrupts and (rxInt or 
                                          (tx_Buffer_Empty and not tx_Buffer_Empty_Pre));
      o_rxInterrupt <= enable_interrupts and rxInt;
      o_txInterrupt <= enable_interrupts and tx_Buffer_Empty;
    end if;
  end process Interrupt_DFF; 
  
  -----------------------------------------------------------------------------
  -- Handling the OPB bus interface
  -----------------------------------------------------------------------------
  
  Read_Mux : process (status_reg, OPB_ABus, rx_data) is
    begin  -- process Read_Mux
        sin_Dbus_i <= (others => '0');
        if (OPB_ABus = STATUS_REG_ADR) then
            sin_Dbus_i(status_reg'range) <= status_reg;
        elsif (OPB_ABus = CONF_REG_ADR) then 
            sin_Dbus_i(status_reg'range) <= config_reg;
        else  
        	sin_Dbus_i(0 to 15) <= status_reg(16 to 31);
            sin_Dbus_i(31-C_DATA_BITS_MAX+1 to 31) <= rx_data;
        end if;
  end process Read_Mux;

  OPB_rdDBus_DFF : for I in sin_DBus_i'range generate
    OPB_rdBus_FDRE : FDRE
      port map (
        Q  => SIn_DBus(I),              -- [out std_logic]
        C  => Clk,                      -- [in  std_logic]
        CE => uart_CS_2,                -- [in  std_logic]
        D  => sin_Dbus_i(I),            -- [in  std_logic]
        R  => xfer_Ack);                -- [in std_logic]
  end generate OPB_rdDBus_DFF;

  -- Generating read and write pulses to the FIFOs
  write_TX_FIFO <= uart_CS_2 and (not OPB_RNW_1) when (OPB_ABus = TX_FIFO_ADR) else '0';
  read_RX_FIFO <= uart_CS_2 and OPB_RNW_1 when (OPB_ABus = RX_FIFO_ADR) else '0';
  
  XFER_Control : process (Clk, Reset) is
  begin  -- process XFER_Control
    if Reset = '1' then                 -- asynchronous reset (active high)
      xfer_Ack    <= '0';
    elsif Clk'event and Clk = '1' then  -- rising clock edge
      xfer_Ack <= uart_CS_2;
    end if;
  end process XFER_Control;
  
  SIn_xferAck <= xfer_Ack;
  
  -----------------------------------------------------------------------------
  -- Instanciating the receive and transmit modules
  -----------------------------------------------------------------------------
  OPB_uart_RX_I : OPB_uart_RX
    port map (
      Clk              => Clk,          -- [in  std_logic]
      Reset            => Reset,        -- [in  std_logic]
      EN_16x_Baud      => en_16x_Baud,  -- [in  std_logic]
      RX               => RX,           -- [in  std_logic]
      Read_RX_FIFO     => read_RX_FIFO,      -- [in  std_logic]
      Reset_RX_FIFO    => reset_RX_FIFO,     -- [in  std_logic]
      RX_Data          => rx_Data,  -- [out std_logic_vector(0 to C_DATA_BITS-1)]
      RX_Data_Present  => rx_Data_Present,   -- [out std_logic]
      RX_BUFFER_FULL   => rx_BUFFER_FULL,    -- [out std_logic]
      RX_Frame_Error   => rx_Frame_Error,    -- [out std_logic]
      RX_Overrun_Error => rx_Overrun_Error,  -- [out std_logic]
      RX_Parity_Error  => rx_Parity_Error,   -- [out std_logic]
      i_data_bits	   => data_bits,         -- std_logic_vector(0 to 1); 
      i_use_parity 	   => use_parity(0),        -- std_logic;      
  	  i_odd_parity 	   => odd_parity(0),        -- std_logic;
      i_Int_nr_of_Data => Int_nr_of_Data,       -- std_logic_vector(0 to 3); 
      o_RX_nr_of_Data  => RX_nr_of_Data,         -- std_logic_vector(0 to 3);
      o_rxInt          => rxInt);            -- [out std_logic ]

  OPB_uart_TX_I : OPB_uart_TX  
  	generic map (
  		C_485_SUPPORT => C_485_SUPPORT  -- [integer range 0 to 1 := 0]
    )  		
    port map (
      Clk             => Clk,           -- [in  std_logic]
      Reset           => Reset,         -- [in  std_logic]
      EN_16x_Baud     => en_16x_Baud,   -- [in  std_logic]
      TX              => TX,            -- [out std_logic]
      Write_TX_FIFO   => write_TX_FIFO,                 -- [in  std_logic]
      Reset_TX_FIFO   => reset_TX_FIFO,                 -- [in  std_logic]
      TX_Data         => OPB_DBus(32-C_DATA_BITS_MAX to 31),  -- [in  std_logic_vector(0 to C_DATA_BITS-1)]
      TX_Buffer_Full  => tx_Buffer_Full,                -- [out std_logic]
      TX_Buffer_Empty => tx_Buffer_Empty,              -- [out std_logic]    
      o_485_RnW		  => o_485_RnW,			-- [out std_logic] 
      i_485_DELAY     => l_485_DELAY,		-- [in  std_logic_vector(3 downto 0)]
      i_data_bits	   => data_bits,         -- std_logic_vector(0 to 1); 
      o_TX_nr_of_Data  => TX_nr_of_Data,         -- std_logic_vector(0 to 3);
      i_use_parity 	   => use_parity(0),        -- std_logic;      
  	  i_odd_parity 	   => odd_parity(0));        -- std_logic;

end architecture IMP;



