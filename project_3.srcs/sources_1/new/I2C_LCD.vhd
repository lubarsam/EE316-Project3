library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity I2C_LCD_Controller is
    Port (
        iclk        : in  std_logic;
        reset_n     : in  std_logic;

        SourceSel   : in  std_logic_vector(1 downto 0); -- 00=LDR, 01=TEMP, 10=POT
        ClockActive : in  std_logic;

        LCD_SDA     : inout std_logic;
        LCD_SCL     : inout std_logic
    );
end I2C_LCD_Controller;

architecture Behavioral of I2C_LCD_Controller is

    -- I2C Master Component
    component i2c_master is
        generic(
            input_clk : integer := 125_000_000;
            bus_clk   : integer := 100_000
        );
        port(
            clk       : in  std_logic;
            reset_n   : in  std_logic;
            ena       : in  std_logic;
            addr      : in  std_logic_vector(6 downto 0);
            rw        : in  std_logic;
            data_wr   : in  std_logic_vector(7 downto 0);
            busy      : out std_logic;
            data_rd   : out std_logic_vector(7 downto 0);
            ack_error : out std_logic;
            sda       : inout std_logic;
            scl       : inout std_logic
        );
    end component;

    -- LCD line buffers (16 characters each)
    type line_t is array(1 to 16) of std_logic_vector(7 downto 0);
    signal line1, line2 : line_t;

    -- I2C control signals
    signal ena        : std_logic := '0';
    signal rw_sig     : std_logic := '0';
    signal busy       : std_logic;
    signal data_wr    : std_logic_vector(7 downto 0);
    signal ack_err    : std_logic;

    constant LCD_ADDR : std_logic_vector(6 downto 0) := "0100111"; -- PCF8574

    -- LCD FSM
    type state_type is (
        INIT_1, INIT_2, INIT_3, INIT_4,
        IDLE,
        SET_LINE1, SET_LINE2,
        WRITE_CHAR, NEXT_CHAR
    );

    signal state : state_type := INIT_1;
    signal char_index : integer range 1 to 16 := 1;

    -- Helper: Encode ASCII byte into PCF8574 format
    function LCD_Encode(
        ascii : std_logic_vector(7 downto 0);
        rs    : std_logic
    ) return std_logic_vector is
        variable outb : std_logic_vector(7 downto 0);
    begin
        outb(7 downto 4) := ascii(7 downto 4); -- upper nibble
        outb(3) := '1'; -- backlight
        outb(2) := '0'; -- EN low
        outb(1) := '0'; -- RW=0
        outb(0) := rs;  -- RS
        return outb;
    end function;

begin

    -- Instantiate I2C Master
    I2C_INST : i2c_master
        port map(
            clk       => iclk,
            reset_n   => reset_n,
            ena       => ena,
            addr      => LCD_ADDR,
            rw        => rw_sig,
            data_wr   => data_wr,
            busy      => busy,
            data_rd   => open,
            ack_error => ack_err,
            sda       => LCD_SDA,
            scl       => LCD_SCL
        );

    -- Build dynamic LCD messages
    process(iclk)
    begin
        if rising_edge(iclk) then

            -- Line 1: "SRC: LDR/TEMP/POT"
            line1(1) <= x"53"; -- S
            line1(2) <= x"52"; -- R
            line1(3) <= x"43"; -- C
            line1(4) <= x"3A"; -- :
            line1(5) <= x"20"; -- space

            case SourceSel is
                when "00" =>  -- LDR
                    line1(6) <= x"4C"; -- L
                    line1(7) <= x"44"; -- D
                    line1(8) <= x"52"; -- R
                    line1(9) <= x"20";
                    line1(10) <= x"20";
                    line1(11) <= x"20";
                    line1(12) <= x"20";
                    line1(13) <= x"20";
                    line1(14) <= x"20";
                    line1(15) <= x"20";
                    line1(16) <= x"20";

                when "01" =>  -- TEMP
                    line1(6) <= x"54"; -- T
                    line1(7) <= x"45"; -- E
                    line1(8) <= x"4D"; -- M
                    line1(9) <= x"50"; -- P
                    line1(10) <= x"20";
                    line1(11) <= x"20";
                    line1(12) <= x"20";
                    line1(13) <= x"20";
                    line1(14) <= x"20";
                    line1(15) <= x"20";
                    line1(16) <= x"20";

                when "10" =>  -- POT
                    line1(6) <= x"50"; -- P
                    line1(7) <= x"4F"; -- O
                    line1(8) <= x"54"; -- T
                    line1(9) <= x"20";
                    line1(10) <= x"20";
                    line1(11) <= x"20";
                    line1(12) <= x"20";
                    line1(13) <= x"20";
                    line1(14) <= x"20";
                    line1(15) <= x"20";
                    line1(16) <= x"20";

                when others =>
                    line1(6) <= x"3F"; -- ?
                    line1(7) <= x"3F"; -- ?
                    line1(8) <= x"20";
                    line1(9) <= x"20";
                    line1(10) <= x"20";
                    line1(11) <= x"20";
                    line1(12) <= x"20";
                    line1(13) <= x"20";
                    line1(14) <= x"20";
                    line1(15) <= x"20";
                    line1(16) <= x"20";
            end case;

            -- Line 2: "Clock Output: ON" or "Clock Output: OFF"
            line2(1)  <= x"43"; -- C
            line2(2)  <= x"6C"; -- l
            line2(3)  <= x"6F"; -- o
            line2(4)  <= x"63"; -- c
            line2(5)  <= x"6B"; -- k
            line2(6)  <= x"20";
            line2(7)  <= x"4F"; -- O
            line2(8)  <= x"75"; -- u
            line2(9)  <= x"74"; -- t
            line2(10) <= x"70"; -- p
            line2(11) <= x"75"; -- u
            line2(12) <= x"74"; -- t
            line2(13) <= x"3A"; -- :
            line2(14) <= x"20";

            if ClockActive = '1' then
                line2(15) <= x"4F"; -- O
                line2(16) <= x"4E"; -- N
            else
                line2(15) <= x"4F"; -- O
                line2(16) <= x"46"; -- F
            end if;

        end if;
    end process;

    -- LCD FSM (unchanged from previous version)
    process(iclk)
        variable c : std_logic_vector(7 downto 0);
    begin
        if rising_edge(iclk) then

            case state is

                when INIT_1 =>
                    if busy = '0' then
                        data_wr <= x"30"; ena <= '1'; rw_sig <= '0';
                        state <= INIT_2;
                    end if;

                when INIT_2 =>
                    ena <= '0';
                    if busy = '0' then
                        data_wr <= x"20"; ena <= '1';
                        state <= INIT_3;
                    end if;

                when INIT_3 =>
                    ena <= '0';
                    if busy = '0' then
                        data_wr <= x"28"; ena <= '1';
                        state <= INIT_4;
                    end if;

                when INIT_4 =>
                    ena <= '0';
                    if busy = '0' then
                        data_wr <= x"0C"; ena <= '1';
                        state <= IDLE;
                    end if;

                when IDLE =>
                    char_index <= 1;
                    state <= SET_LINE1;

                when SET_LINE1 =>
                    if busy = '0' then
                        data_wr <= x"80"; ena <= '1';
                        state <= WRITE_CHAR;
                    end if;

                when SET_LINE2 =>
                    if busy = '0' then
                        data_wr <= x"C0"; ena <= '1';
                        state <= WRITE_CHAR;
                    end if;

                when WRITE_CHAR =>
                    ena <= '0';
                    if busy = '0' then
                        if state = WRITE_CHAR and char_index <= 16 then
                            if state = SET_LINE1 or state = WRITE_CHAR then
                                c := line1(char_index);
                            else
                                c := line2(char_index);
                            end if;

                            data_wr <= LCD_Encode(c, '1');
                            ena <= '1';
                            state <= NEXT_CHAR;
                        end if;
                    end if;

                when NEXT_CHAR =>
                    ena <= '0';
                    if busy = '0' then
                        if char_index = 16 then
                            if state = SET_LINE1 then
                                char_index <= 1;
                                state <= SET_LINE2;
                            else
                                state <= IDLE;
                            end if;
                        else
                            char_index <= char_index + 1;
                            state <= WRITE_CHAR;
                        end if;
                    end if;

            end case;

        end if;
    end process;

end Behavioral;