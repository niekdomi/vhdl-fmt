-------------------------------------------------------------------------------
-- opb_uart.vhd
-------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

entity OPB_uart is
  generic (
    C_OPB_AWIDTH : integer                   := 32;
    C_OPB_DWIDTH : integer                   := 32;
    C_BASEADDR   : std_logic_vector(0 to 31) := X"8000_0000";
    C_HIGHADDR   : std_logic_vector          := X"8000_00FF";
    C_DATA_BITS  : integer range 7 to 8      := 8;
    C_CLK_FREQ   : integer                   := 99_000_000;
    C_BAUDRATE   : integer                   := 115_200;
    C_USE_PARITY : integer                   := 0;
    C_ODD_PARITY : integer                   := 1;
    C_485_SUPPORT: integer range 0 to 1 	 := 1
    );
  port (
    -- Global signals
    OPB_Clk : in std_logic;
    OPB_Rst : in std_logic;

    -- OPB signals
    OPB_ABus    : in std_logic_vector(0 to 31);
    OPB_BE      : in std_logic_vector(0 to 3);
    OPB_RNW     : in std_logic;
    OPB_select  : in std_logic;
    OPB_seqAddr : in std_logic;
    OPB_DBus    : in std_logic_vector(0 to 31);

    UART_DBus    : out std_logic_vector(0 to 31);
    UART_errAck  : out std_logic;
    UART_retry   : out std_logic;
    UART_toutSup : out std_logic;
    UART_xferAck : out std_logic;

    -- UART signals
    RX          : in  std_logic;
    TX          : out std_logic;
    Interrupt   : out std_logic;
    o_txInterrupt : out std_logic;
    o_rxInterrupt : out std_logic; 
    o_485_RnW	: out std_logic;
    ni_sioRTS   : in  std_logic;
    no_sioCTS   : out std_logic;
    o_TP1	: out std_logic;
    o_TP2	: out std_logic;
    o_TP3	: out std_logic;
    o_TP4	: out std_logic
    );

end entity OPB_uart;

library Common_v1_00_a;
use Common_v1_00_a.pselect;

library unisim;
use unisim.all;

architecture IMP of OPB_uart is

  component pselect is
    generic (
      C_AB  : integer;
      C_AW  : integer;
      C_BAR : std_logic_vector);
    port (
      A      : in  std_logic_vector(0 to C_AW-1);
      AValid : in  std_logic;
      ps     : out std_logic);
  end component pselect;

  component OPB_uart_Core is
    generic (   
      C_485_SUPPORT: integer range 0 to 1;
      C_DATA_BITS  : integer range 7 to 8;
      C_CLK_FREQ   : integer;
      C_BAUDRATE   : integer;
      C_USE_PARITY : integer;
      C_ODD_PARITY : integer);
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
      o_TP4	: out std_logic);
  end component OPB_uart_Core;

  function Addr_Bits (x, y : std_logic_vector(0 to C_OPB_AWIDTH-1)) return integer is
    variable addr_nor : std_logic_vector(0 to C_OPB_AWIDTH-1);
  begin
    addr_nor := x xor y;
    for i in 0 to C_OPB_AWIDTH-1 loop
      if addr_nor(i) = '1' then return i;
      end if;
    end loop;
    return(C_OPB_AWIDTH);
  end function Addr_Bits;

  constant C_AB : integer := Addr_Bits(C_HIGHADDR, C_BASEADDR);

  signal uart_CS : std_logic;
  signal RTS     : std_logic;
  signal CTS     : std_logic;    
begin  -- architecture IMP
  
  process (OPB_Clk)
  begin 
    if rising_edge(OPB_Clk) then 
        RTS   <= not(ni_sioRTS);
    end if;
  end process;
  no_sioCTS <= not(CTS);

  -----------------------------------------------------------------------------
  -- Handling the OPB bus interface
  -----------------------------------------------------------------------------

  -- Do the OPB address decoding
  pselect_I : pselect
    generic map (
      C_AB  => C_AB,                    -- [integer]
      C_AW  => C_OPB_AWIDTH,            -- [integer]
      C_BAR => C_BASEADDR)              -- [std_logic_vector]
    port map (
      A      => OPB_ABus,               -- [in  std_logic_vector(0 to C_AW-1)]
      AValid => OPB_select,             -- [in  std_logic]
      ps     => uart_CS);               -- [out std_logic]


  --UART_DBus(0 to C_OPB_DWIDTH-9) <= (others => '0');
  UART_errAck                    <= '0';
  UART_retry                     <= '0';
  UART_toutSup                   <= '0';

  -----------------------------------------------------------------------------
  -- Instanciating the UART core
  -----------------------------------------------------------------------------
  OPB_uart_Core_I : OPB_uart_Core
    generic map (   
      C_485_SUPPORT => C_485_SUPPORT,   -- [integer range 0 to 1 := 0]
      C_DATA_BITS  => C_DATA_BITS,      -- [integer range 7 to 8]
      C_CLK_FREQ   => C_CLK_FREQ,       -- [integer]
      C_BAUDRATE   => C_BAUDRATE,       -- [integer]
      C_USE_PARITY => C_USE_PARITY,     -- [integer]
      C_ODD_PARITY => C_ODD_PARITY)     -- [integer]
    port map (
      Clk         => OPB_Clk,           -- [in  std_logic]
      Reset       => OPB_Rst,           -- [in  std_logic]
      UART_CS     => uart_CS,           -- [in  std_logic]
      OPB_ABus    => OPB_ABus(C_OPB_AWIDTH-5 to C_OPB_AWIDTH-3),  -- [in  std_logic_vector(0 to 2)]
      OPB_RNW     => OPB_RNW,           -- [in  std_logic]
      OPB_DBus    => OPB_DBus(0 to C_OPB_DWIDTH-1),  -- [in  std_logic_vector(0 to 31)]
      SIn_xferAck => UART_xferAck,      -- [out std_logic]
      SIn_DBus    => UART_DBus(0 to C_OPB_DWIDTH-1),  -- [out std_logic_vector(0 to 31)]
      RX          => RX,                -- [in  std_logic]
      TX          => TX,                -- [out std_logic]
      Interrupt   => Interrupt,         -- [out std_logic]
      o_txInterrupt => o_txInterrupt,   -- [out std_logic]
      o_rxInterrupt => o_rxInterrupt,   -- [out std_logic] 
      o_485_RnW	  => o_485_RnW,			-- [out std_logic]
      i_sioRTS    => RTS,               -- in  std_logic;
      o_sioCTS    => CTS,                -- out std_logic
      o_TP1		  => o_TP1,				-- out std_logic;
   	  o_TP2		  => o_TP2,				 --out std_logic;
      o_TP3		  => o_TP3,				 --out std_logic;
      o_TP4		  => o_TP4				 --out std_logic
      );

end architecture IMP;



