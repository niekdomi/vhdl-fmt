library ieee;
use ieee.std_logic_1164.all;

entity test_component is
end entity test_component;

architecture rtl of test_component is
  -- Component declaration
  component my_adder
    generic (
      WIDTH : integer := 8
    );
    port (
      a_i    : in  std_logic_vector(WIDTH-1 downto 0);
      b_i    : in  std_logic_vector(WIDTH-1 downto 0);
      sum_o  : out std_logic_vector(WIDTH downto 0)
    );
  end component;

  component neorv32_cpu_cp_fpu_f2i
    generic (
      FPU_SUBNORMAL_SUPPORT : boolean := false
    );
    port (
      clk_i      : in  std_ulogic;
      rstn_i     : in  std_ulogic;
      start_i    : in  std_ulogic;
      abort_i    : in  std_ulogic;
      rmode_i    : in  std_ulogic_vector(2 downto 0);
      funct_i    : in  std_ulogic;
      sign_i     : in  std_ulogic;
      exponent_i : in  std_ulogic_vector(7 downto 0);
      mantissa_i : in  std_ulogic_vector(22 downto 0);
      class_i    : in  std_ulogic_vector(9 downto 0);
      result_o   : out std_ulogic_vector(31 downto 0);
      flags_o    : out std_ulogic_vector(4 downto 0);
      done_o     : out std_ulogic
    );
  end component;

  signal data_a : std_logic_vector(7 downto 0);
  signal data_b : std_logic_vector(7 downto 0);
  signal result : std_logic_vector(8 downto 0);

begin

end architecture rtl;
