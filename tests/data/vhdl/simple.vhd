-- Top-level entity for testing the AST builder
entity ExampleEntity is
  generic (
    WIDTH      : integer := 8;
    ENABLE_LOG : boolean := true
  );

  port (
    enable : in  std_logic := '1';
    width  : in  integer := 8 + 4;
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    data_i : in  std_logic_vector(WIDTH-1 downto 0);
    data_o : out std_logic_vector(WIDTH-1 downto 0)
  );
end ExampleEntity;
