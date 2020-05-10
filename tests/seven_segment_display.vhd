library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity seven_segment_display is
port( clk, reset : in std_logic;
         segment : out std_logic_vector(6 downto 0)); -- A,B,C,D,E,F,G represent numbers 0-9
end seven_segment_display;

architecture behavioral of seven_segment_display is
type my_state is (s0,s1,s2,s3,s4,s5,s6,s7,s8,s9);
signal n_s : my_state;
signal clk_div : std_logic;
begin

process(clk_div, reset) -- reset here for asynchronous reset
begin
if reset='1' then 
	segment <= "1111110";
	n_s <= s0;
end if;
if clk_div='1' and clk_div'event then
    case n_s is
        when s0  => segment <= "1111110"; n_s <= s1;
        when s1  => segment <= "0110000"; n_s <= s2;
        when s2  => segment <= "1101101"; n_s <= s3;
        when s3  => segment <= "1111001"; n_s <= s4;
        when s4  => segment <= "0110011"; n_s <= s5;
        when s5  => segment <= "1011011"; n_s <= s6;
        when s6  => segment <= "1011111"; n_s <= s7;
        when s7  => segment <= "1110000"; n_s <= s8;
        when s8  => segment <= "1111111"; n_s <= s9;
        when s9  => segment <= "1111011"; n_s <= s0;
    end case;
end if;
end process;

process(clk) -- clock division
variable count : integer;
begin
if clk = '1' and clk'event then
    if count = 50_000_000 then -- 50 MHz
        clk_div <= not clk_div;
        count := 0;
    else
        count := count + 1;
    end if;
end if;
end process;

end behavioral;