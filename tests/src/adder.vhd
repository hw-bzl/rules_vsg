library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.math_pkg.all;

entity adder is
  port (
    i_a   : in    unsigned(c_data_width - 1 downto 0);
    i_b   : in    unsigned(c_data_width - 1 downto 0);
    o_sum : out   unsigned(c_data_width - 1 downto 0)
  );
end entity adder;

architecture rtl of adder is

begin

  o_sum <= add_unsigned(i_a, i_b);

end architecture rtl;
