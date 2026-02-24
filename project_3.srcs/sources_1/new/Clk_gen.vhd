library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity clock_generator is
    Port (
        clk         : in  STD_LOGIC; -- 125 MHz
        reset       : in  STD_LOGIC;
        N           : in  STD_LOGIC_VECTOR(17 downto 0);
        clk_out     : out STD_LOGIC
         
    );
end clock_generator;

architecture Behavioral of clock_generator is


    
     signal counter         : STD_LOGIC_VECTOR(17 downto 0):=(others => '0');
     signal clock           : STD_LOGIC:='0';
  

begin

     process(clk)
        begin
            if rising_edge(clk) then
                if counter = N then
                    clock <= not clock;
                    counter <= (others=> '0') ;
                else 
                    counter <= counter + '1';
                end if;
            end if;    
     end process;

clk_out <= clock;

end Behavioral;
