library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pcf8591_controller is
    generic (
        CLK_FREQ        : integer := 50_000_000;  -- System clock frequency (Hz)
        I2C_FREQ        : integer := 100_000;     -- I2C clock frequency (Hz)
        DEVICE_ADDR     : std_logic_vector(6 downto 0) := "1001000" -- PCF8591 address (0x48)
    );
    port (
        -- System signals
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Control interface
        start           : in  std_logic;  -- Start transaction
        rw              : in  std_logic;  -- '1' = read ADC, '0' = write DAC
        adc_channel     : in  std_logic_vector(1 downto 0);  -- ADC channel select (0-3)
        dac_data        : in  std_logic_vector(7 downto 0);  -- Data to write to DAC
        adc_data        : out std_logic_vector(7 downto 0);  -- Data read from ADC
        busy            : out std_logic;
        done            : out std_logic;
        error           : out std_logic;
        
        -- I2C interface
        scl             : inout std_logic;
        sda             : inout std_logic
    );
end pcf8591_controller;

architecture behavioral of pcf8591_controller is

    -- I2C timing constants
    constant I2C_CLK_DIV : integer := CLK_FREQ / (4 * I2C_FREQ);
    
    -- Control byte bits for PCF8591
    -- Bit 7: Reserved (0)
    -- Bit 6: Analog output enable flag (1 = enable DAC)
    -- Bits 5-4: Analog input programming (00 = four single-ended inputs)
    -- Bit 3: Reserved (0)
    -- Bit 2: Auto-increment flag (0 = no auto-increment)
    -- Bits 1-0: Channel number
    
    -- State machine type
    type state_type is (
        IDLE,
        START_COND,
        SEND_ADDR,
        SEND_CONTROL,
        SEND_DAC_DATA,
        RESTART_COND,
        SEND_ADDR_READ,
        READ_DUMMY,      -- First read is dummy (previous conversion)
        READ_ADC_DATA,
        STOP_COND,
        COMPLETE
    );
    
    signal state        : state_type := IDLE;
    signal next_state   : state_type := IDLE;
    
    -- I2C signals
    signal scl_out      : std_logic := '1';
    signal sda_out      : std_logic := '1';
    signal scl_en       : std_logic := '0';
    signal sda_en       : std_logic := '0';
    
    -- Timing and control
    signal clk_count    : integer range 0 to I2C_CLK_DIV := 0;
    signal bit_count    : integer range 0 to 8 := 0;
    signal i2c_clk_en   : std_logic := '0';
    signal i2c_phase    : integer range 0 to 3 := 0;  -- Quarter clock phases
    
    -- Data registers
    signal shift_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal control_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_byte    : std_logic_vector(7 downto 0) := (others => '0');
    signal ack_bit      : std_logic := '0';
    signal data_valid   : std_logic := '0';
    
    -- Internal status
    signal busy_int     : std_logic := '0';
    signal done_int     : std_logic := '0';
    signal error_int    : std_logic := '0';

begin

    -- Tristate control for I2C
    scl <= '0' when (scl_en = '1' and scl_out = '0') else 'Z';
    sda <= '0' when (sda_en = '1' and sda_out = '0') else 'Z';
    
    -- Output assignments
    busy <= busy_int;
    done <= done_int;
    error <= error_int;
    
    -- I2C clock generator
    process(clk, rst)
    begin
        if rst = '1' then
            clk_count <= 0;
            i2c_clk_en <= '0';
            i2c_phase <= 0;
        elsif rising_edge(clk) then
            if state = IDLE then
                clk_count <= 0;
                i2c_clk_en <= '0';
                i2c_phase <= 0;
            else
                if clk_count = I2C_CLK_DIV - 1 then
                    clk_count <= 0;
                    i2c_clk_en <= '1';
                    if i2c_phase = 3 then
                        i2c_phase <= 0;
                    else
                        i2c_phase <= i2c_phase + 1;
                    end if;
                else
                    clk_count <= clk_count + 1;
                    i2c_clk_en <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Main state machine
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            busy_int <= '0';
            done_int <= '0';
            error_int <= '0';
            scl_out <= '1';
            sda_out <= '1';
            scl_en <= '0';
            sda_en <= '0';
            bit_count <= 0;
            shift_reg <= (others => '0');
            control_byte <= (others => '0');
            addr_byte <= (others => '0');
            adc_data <= (others => '0');
            data_valid <= '0';
            
        elsif rising_edge(clk) then
            done_int <= '0';  -- Pulse signal
            
            case state is
                when IDLE =>
                    busy_int <= '0';
                    error_int <= '0';
                    scl_out <= '1';
                    sda_out <= '1';
                    scl_en <= '0';
                    sda_en <= '0';
                    bit_count <= 0;
                    data_valid <= '0';
                    
                    if start = '1' then
                        busy_int <= '1';
                        -- Prepare address byte
                        addr_byte <= DEVICE_ADDR & '0';  -- Write address
                        -- Prepare control byte
                        -- Bit 6: DAC enable (always enabled)
                        -- Bits 1-0: channel select
                        control_byte <= "0" & "1" & "00" & "0" & "0" & adc_channel;
                        state <= START_COND;
                    end if;
                
                when START_COND =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_en <= '0';
                                sda_en <= '0';
                                scl_out <= '1';
                                sda_out <= '1';
                            when 1 =>
                                sda_en <= '1';
                                sda_out <= '0';  -- Start condition: SDA falls while SCL high
                            when 2 =>
                                scl_en <= '1';
                                scl_out <= '0';
                            when 3 =>
                                shift_reg <= addr_byte;
                                bit_count <= 0;
                                state <= SEND_ADDR;
                            when others => null;
                        end case;
                    end if;
                
                when SEND_ADDR =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_out <= shift_reg(7);  -- MSB first
                                sda_en <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                scl_out <= '1';
                            when 3 =>
                                scl_out <= '0';
                                if bit_count = 7 then
                                    bit_count <= 0;
                                    sda_en <= '0';  -- Release SDA for ACK
                                    next_state <= SEND_CONTROL;
                                else
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    bit_count <= bit_count + 1;
                                end if;
                            when others => null;
                        end case;
                        
                        -- Check for ACK
                        if bit_count = 0 and i2c_phase = 2 then
                            ack_bit <= sda;
                            if sda = '1' then  -- NACK received
                                error_int <= '1';
                            end if;
                        end if;
                        
                        if bit_count = 0 and i2c_phase = 3 then
                            if ack_bit = '0' then  -- ACK received
                                shift_reg <= control_byte;
                                state <= next_state;
                            else
                                state <= STOP_COND;
                            end if;
                        end if;
                    end if;
                
                when SEND_CONTROL =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_out <= shift_reg(7);
                                sda_en <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                scl_out <= '1';
                            when 3 =>
                                scl_out <= '0';
                                if bit_count = 7 then
                                    bit_count <= 0;
                                    sda_en <= '0';
                                    if rw = '0' then
                                        next_state <= SEND_DAC_DATA;
                                    else
                                        next_state <= RESTART_COND;
                                    end if;
                                else
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    bit_count <= bit_count + 1;
                                end if;
                            when others => null;
                        end case;
                        
                        if bit_count = 0 and i2c_phase = 2 then
                            ack_bit <= sda;
                        end if;
                        
                        if bit_count = 0 and i2c_phase = 3 then
                            if ack_bit = '0' then
                                shift_reg <= dac_data;
                                state <= next_state;
                            else
                                error_int <= '1';
                                state <= STOP_COND;
                            end if;
                        end if;
                    end if;
                
                when SEND_DAC_DATA =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_out <= shift_reg(7);
                                sda_en <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                scl_out <= '1';
                            when 3 =>
                                scl_out <= '0';
                                if bit_count = 7 then
                                    bit_count <= 0;
                                    sda_en <= '0';
                                else
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    bit_count <= bit_count + 1;
                                end if;
                            when others => null;
                        end case;
                        
                        if bit_count = 0 and i2c_phase = 2 then
                            ack_bit <= sda;
                        end if;
                        
                        if bit_count = 0 and i2c_phase = 3 then
                            state <= STOP_COND;
                        end if;
                    end if;
                
                when RESTART_COND =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_out <= '0';
                                sda_en <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                sda_en <= '0';
                                sda_out <= '1';
                            when 3 =>
                                sda_en <= '1';
                                sda_out <= '0';  -- Restart: SDA falls while SCL high
                                scl_out <= '0';
                                scl_en <= '1';
                                addr_byte <= DEVICE_ADDR & '1';  -- Read address
                                shift_reg <= DEVICE_ADDR & '1';
                                bit_count <= 0;
                                state <= SEND_ADDR_READ;
                            when others => null;
                        end case;
                    end if;
                
                when SEND_ADDR_READ =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_out <= shift_reg(7);
                                sda_en <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                scl_out <= '1';
                            when 3 =>
                                scl_out <= '0';
                                if bit_count = 7 then
                                    bit_count <= 0;
                                    sda_en <= '0';
                                else
                                    shift_reg <= shift_reg(6 downto 0) & '0';
                                    bit_count <= bit_count + 1;
                                end if;
                            when others => null;
                        end case;
                        
                        if bit_count = 0 and i2c_phase = 2 then
                            ack_bit <= sda;
                        end if;
                        
                        if bit_count = 0 and i2c_phase = 3 then
                            if ack_bit = '0' then
                                state <= READ_DUMMY;
                            else
                                error_int <= '1';
                                state <= STOP_COND;
                            end if;
                        end if;
                    end if;
                
                when READ_DUMMY =>
                    -- First read after control byte is dummy (previous conversion)
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_en <= '0';  -- Release SDA
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                shift_reg <= shift_reg(6 downto 0) & sda;  -- Read bit
                            when 3 =>
                                scl_out <= '0';
                                if bit_count = 7 then
                                    bit_count <= 0;
                                    sda_en <= '1';
                                    sda_out <= '0';  -- Send ACK
                                else
                                    bit_count <= bit_count + 1;
                                end if;
                            when others => null;
                        end case;
                        
                        if bit_count = 0 and i2c_phase = 3 then
                            state <= READ_ADC_DATA;
                        end if;
                    end if;
                
                when READ_ADC_DATA =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_en <= '0';  -- Release SDA
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                shift_reg <= shift_reg(6 downto 0) & sda;
                            when 3 =>
                                scl_out <= '0';
                                if bit_count = 7 then
                                    bit_count <= 0;
                                    sda_en <= '1';
                                    sda_out <= '1';  -- Send NACK (last byte)
                                    adc_data <= shift_reg(6 downto 0) & sda;
                                    data_valid <= '1';
                                else
                                    bit_count <= bit_count + 1;
                                end if;
                            when others => null;
                        end case;
                        
                        if bit_count = 0 and i2c_phase = 3 then
                            state <= STOP_COND;
                        end if;
                    end if;
                
                when STOP_COND =>
                    if i2c_clk_en = '1' then
                        case i2c_phase is
                            when 0 =>
                                scl_out <= '0';
                                sda_out <= '0';
                                sda_en <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_en <= '1';
                            when 2 =>
                                sda_out <= '1';  -- Stop condition: SDA rises while SCL high
                            when 3 =>
                                scl_en <= '0';
                                sda_en <= '0';
                                state <= COMPLETE;
                            when others => null;
                        end case;
                    end if;
                
                when COMPLETE =>
                    done_int <= '1';
                    busy_int <= '0';
                    state <= IDLE;
                
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

end behavioral;