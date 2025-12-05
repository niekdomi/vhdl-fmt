library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_entity is
    port (
        clk : in std_logic;
        data : out std_logic
    );
end entity test_entity;

architecture rtl of test_entity is
    signal counter : integer := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;
end architecture rtl;
