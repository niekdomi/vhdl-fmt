entity benchmark_entity is
    generic (
        WIDTH : integer := 32
    );
    port (
        clk      : in  bit;
        rst      : in  bit;
        data_in  : in  bit;
        data_out : out bit
    );
end benchmark_entity;

architecture Behavioral of benchmark_entity is
    signal sig1 : bit;
    signal sig2 : bit;
    signal sig3 : bit;
begin
    process
    begin
        if clk = '1' then
            if rst = '1' then
                sig1 <= '0';
                sig2 <= '0';
                sig3 <= '0';
                data_out <= '0';
            else
                sig1 <= data_in;
                sig2 <= sig1;
                sig3 <= sig2;
                data_out <= sig3;
            end if;
        end if;
    end process;
end Behavioral;
