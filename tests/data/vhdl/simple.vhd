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
    -- [1] Concurrent Assignment with UNAFFECTED
    -- Tests: AST 'is_unaffected' flag
    data_out <= sig3 when en = '1' else unaffected;

    -- [2] Multi-value Driver (Clock Pattern)
    -- Tests: AST vector<Element> and hanging indent
    -- If line length is narrow, this will hang:
    -- clk_gen <= '0',
    --            '1' after 10 ns,
    --            '0' after 20 ns,
    --            '1' after 30 ns;
    clk_gen <= '0', '1' after 10 ns, '0' after 20 ns, '1' after 30 ns;

    process
    begin
        -- [3] Sequential Assignment with Delays
        -- Tests: SequentialStatement -> SignalAssign -> Waveform -> Element -> after
        if clk = '1' then
            if rst = '1' then
                sig1 <= '0' after 1 ns;
                sig2 <= '0' after 1 ns;
                sig3 <= '0' after 1 ns;
            else
                -- [4] Complex hanging indent scenario in sequential logic
                -- The formatter should align subsequent lines with 'data_in'
                sig1 <= data_in after 2 ns,
                        not data_in after 4 ns;

                sig2 <= sig1;
                
                -- Simple delay
                sig3 <= sig2 after 5 ns;
            end if;
        end if;
    end process;
end Behavioral;
