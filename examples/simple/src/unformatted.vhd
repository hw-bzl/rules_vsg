library ieee;
use ieee.std_logic_1164.all;

entity counter is
port(
clk:in std_logic;
q:out std_logic_vector(7 downto 0)
);
end entity;

architecture rtl of counter is
signal r:std_logic_vector(7 downto 0):=(others=>'0');
begin
process(clk) is begin
if rising_edge(clk) then r<=std_logic_vector(unsigned(r)+1); end if;
end process;
q<=r;
end architecture;
