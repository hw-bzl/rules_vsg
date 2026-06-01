library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package math_pkg is

  constant c_data_width : integer := 8;

  function add_unsigned (
    a : unsigned(c_data_width - 1 downto 0);
    b : unsigned(c_data_width - 1 downto 0)
  ) return unsigned;

end package math_pkg;

package body math_pkg is

  function add_unsigned (
    a : unsigned(c_data_width - 1 downto 0);
    b : unsigned(c_data_width - 1 downto 0)
  ) return unsigned is
  begin

    return a + b;

  end function add_unsigned;

end package body math_pkg;
