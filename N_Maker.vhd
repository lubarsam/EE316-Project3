library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity N_maker is
    Port (
        clk     : in  STD_LOGIC; -- 125 MHz
        reset   : in  STD_LOGIC;
        ADC_in  : in  STD_LOGIC_VECTOR(7 downto 0);  -- 0 to 255
        
        -- Outputs
        N_out   : out STD_LOGIC_VECTOR(17 downto 0); -- 41666 to 125000
        clk_out : out STD_LOGIC                      -- NEW: The actual generated clock!
    );
end N_maker;

architecture Behavioral of N_maker is

    
 --   signal ADC_temp   : unsigned(7 downto 0) := (others => '0');

    signal counter   : unsigned(17 downto 0) := (others => '0'); 
    signal N_value   : unsigned(17 downto 0) := (others => '0');
    signal clk_track : std_logic := '0'; -- NEW: Signal to hold the current clock state

    -- Constants
    constant OFFSET  : integer := 41666;
    constant SLOPE   : integer := 327; 

begin

    ------------------------------------------------------------------
    -- Compute N_out (Hardware Optimized with Clamp)
    ------------------------------------------------------------------
    process(ADC_in)
        variable temp : integer;
    begin
        -- Map the value
        temp := OFFSET + (SLOPE * to_integer(unsigned(ADC_in)));
        
        -- Clamp to prevent overshoot
        if temp > 125000 then
            temp := 125000;
        end if;
        
        N_value <= to_unsigned(temp, 18);
    end process;

    ------------------------------------------------------------------
    -- Clock divider using N_value
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter <= (others => '0');
                clk_track <= '0';
            elsif counter >= N_value then 
                counter <= (others => '0');
                clk_track <= not clk_track; -- NEW: Toggle the clock!
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- Output Assignments
    N_out <= std_logic_vector(N_value);
    clk_out <= clk_track; -- NEW: Drive the physical pin

end Behavioral;