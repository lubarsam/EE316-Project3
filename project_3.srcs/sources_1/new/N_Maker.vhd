library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity N_Maker is
    Port (
        clk     : in  STD_LOGIC; -- 125 MHz
        reset   : in  STD_LOGIC;
        ADC_in  : in  STD_LOGIC_VECTOR(7 downto 0);  -- 0 to 255
        N_out   : out STD_LOGIC_VECTOR(17 downto 0)  -- 41666 to 125000
    );
end N_Maker;

architecture Behavioral of N_Maker is

    -- CHANGED: counter is now unsigned so we can do math on it
    signal counter   : unsigned(17 downto 0); 
    signal N_value   : unsigned(17 downto 0);

    -- Cleaned up constants
    constant OFFSET  : integer := 41666;
    constant SLOPE   : integer := 327; -- 83334 / 255 is approx 327

begin

    ------------------------------------------------------------------
    -- Compute N_out (Hardware Optimized)
    ------------------------------------------------------------------
    process(ADC_in)
        variable temp : integer;
    begin
        -- CHANGED: Removed hardware division. 
        -- Replaced with integer multiplication mapping.
        temp := OFFSET + (SLOPE * to_integer(unsigned(ADC_in)));
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

            -- This comparison now works perfectly because both are unsigned
            elsif counter >= N_value then 
                counter <= (others => '0');

            -- This addition now works perfectly
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- Cast back to std_logic_vector for the output port
    N_out <= std_logic_vector(N_value);

end Behavioral;