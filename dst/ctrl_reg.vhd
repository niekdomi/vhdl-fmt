library ieee;
use ieee.std_logic_1164.all;

entity ctrl_reg is
    generic(
        C_RESET_VAL: std_logic_vector
    );
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        chan_sel  : in  std_logic;
        reg_sel   : in  std_logic;
        wr_ce     : in  std_logic;
        d         : in  std_logic_vector;
        q         : out std_logic_vector
    );
end ctrl_reg;

architecture sim of ctrl_reg is
begin
    CTRL_REG_PROCESS: process (clk)
    begin
        if clk'event and clk='1' then
            if (rst = '1') then
                q <= C_RESET_VAL; 
            elsif (chan_sel and reg_sel and wr_ce) = '1' then
                q <= d;
            end if;
        end if;
    end process;
end;
