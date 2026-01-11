entity benchmark_entity is
    generic (
        WIDTH : integer := 32
    );
    port (
        clk      : in  bit;
        rst      : in  bit;
        en       : in  bit; -- Added for conditional checks
        data_in  : in  bit;
        data_out : out bit
    );
end benchmark_entity;

architecture Behavioral of benchmark_entity is
    signal sig1 : bit;
    signal sig2 : bit;
    signal sig3 : bit;
    signal clk_gen : bit;
begin
    clk_gen <= '0', -- test
               '1' after 10 ns, -- test
               '0' after 20 ns, 
               '1' after 30 ns; -- test

    process
    begin
        if clk = '1' then
            if rst = '1' then
                sig1 <= '0' after 1 ns;
                sig2 <= '0' after 1 ns;
                sig3 <= '0' after 1 ns;
            else
                sig1 <= data_in after 2 ns, -- test
                        not data_in after 4 ns; -- test

                sig2 <= sig1;
                
                -- Simple delay
                sig3 <= sig2 after 5 ns;
            end if;
        end if;
    end process;
end Behavioral;
