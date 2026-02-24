library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_gen is
   generic(
      N  : integer := 8;    -- Resolution (8-bit)
      N2 : integer := 255   -- Max counter value (2^8 - 1)
   );
   port(
      clk       : in std_logic;
      reset     : in std_logic;
      freq_in    : in std_logic_vector(7 downto 0); 
      pwm_out   : out std_logic
   );
end pwm_gen;

architecture logic of pwm_gen is
    -- Internal signals
    signal counter     : integer range 0 to N2 := 0;
    signal duty_cycle  : unsigned(N-1 downto 0);
    signal pwm_reg     : std_logic;
begin

    -- 1. Ramp Counter Process
    -- Creates the "Sawtooth" waveform for comparison
    inst_counter: process(clk, reset)
    begin
        if reset = '1' then
            counter <= 0;
        elsif rising_edge(clk) then
            if counter < N2 then
                counter <= counter + 1;
            else 
                counter <= 0;
            end if;
        end if;
    end process;

    -- Convert input to unsigned for comparison
    duty_cycle <= unsigned(freq_in);
    
    -- 2. PWM Comparison Logic
    -- If the current counter is less than the ADC value, output is High
    inst_pwm_logic: process(clk, reset)
    begin
        if reset = '1' then
            pwm_reg <= '0';
        elsif rising_edge(clk) then
            -- Compare the counter to our ADC duty cycle
            if to_unsigned(counter, N) < duty_cycle then
                pwm_reg <= '1';
            else 
                pwm_reg <= '0';
            end if;
        end if;
    end process;

    pwm_out <= pwm_reg;
    
end logic;