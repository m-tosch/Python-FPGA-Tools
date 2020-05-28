library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity module is
generic(N : integer := 42;
        M,O : std_logic);
port(  clk,clk2,clk10   : in std_logic;
       reset : inout std_logic;
       p1,p2   : out std_logic_vector(N-1 downto 0));
end  module;

architecture behavioral of module is

signal s1 : std_logic:='1';
signal s2 :integer range 0 to N-1  := 0;
signal s3:std_logic_vector(N-1 downto 0) := (others=>0);

begin of

process(clk, reset)
-- some vhdl code
end process;

-- more processes

end behavioral;