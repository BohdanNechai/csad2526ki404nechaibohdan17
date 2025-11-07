library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master_tx is
    generic(
        SYS_CLK_FREQ : integer := 50_000_000;
        I2C_CLK_FREQ : integer := 100_000
    );
    port(
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        start_tx   : in  std_logic;
        byte_to_tx : in  std_logic_vector(7 downto 0);

        tx_busy    : out std_logic;
        ack_error  : out std_logic;

        scl        : inout std_logic;
        sda        : inout std_logic
    );
end entity;

architecture rtl of i2c_master_tx is

    constant DIV : integer := SYS_CLK_FREQ / (2 * I2C_CLK_FREQ);
    signal div_cnt : integer range 0 to DIV := 0;
    signal i2c_clk : std_logic := '0';

    type state_t is (ST_IDLE, ST_START, ST_TX_HIGH, ST_TX_LOW, ST_WAIT_ACK_HIGH, ST_WAIT_ACK_LOW, ST_STOP);
    signal state : state_t := ST_IDLE;

    signal shift_reg : std_logic_vector(7 downto 0);
    signal bit_pos   : integer range 7 downto 0;

    signal sda_out_en : std_logic := '0';
    signal scl_out_en : std_logic := '0'; 
    signal sda_in     : std_logic;

begin
    ----------------------------------------------------------------
    -- Генерація такту I2C
    ----------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            div_cnt <= 0;
            i2c_clk <= '0';
        elsif rising_edge(clk) then
            if div_cnt = DIV then
                div_cnt <= 0;
                i2c_clk <= not i2c_clk;
            else
                div_cnt <= div_cnt + 1;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- FSM
    ----------------------------------------------------------------
    process(i2c_clk, reset_n)
    begin
        if reset_n = '0' then
            state <= ST_IDLE;
            sda_out_en <= '0';
            scl_out_en <= '0';
            ack_error <= '0';
            bit_pos <= 7;

        elsif rising_edge(i2c_clk) then
            case state is

                when ST_IDLE =>
                    sda_out_en <= '0';
                    scl_out_en <= '0';
                    ack_error  <= '0';
                    if start_tx = '1' then
                        shift_reg <= byte_to_tx;
                        bit_pos <= 7;
                        state <= ST_START;
                    end if;

                when ST_START =>
                    sda_out_en <= '1'; -- SDA=0 при SCL=1
                    scl_out_en <= '0';
                    state <= ST_TX_LOW;

                when ST_TX_LOW =>
                    if shift_reg(bit_pos) = '0' then
						  sda_out_en <= '1';
						  else
							sda_out_en <= '0';
						  end if;
                    scl_out_en <= '1'; -- SCL=0
                    state <= ST_TX_HIGH;

                when ST_TX_HIGH =>
                    scl_out_en <= '0'; -- SCL=1
                    if bit_pos = 0 then
                        state <= ST_WAIT_ACK_LOW;
                    else
                        bit_pos <= bit_pos - 1;
                        state <= ST_TX_LOW;
                    end if;

                when ST_WAIT_ACK_LOW =>
                    sda_out_en <= '0'; -- слухаємо ACK
                    scl_out_en <= '1'; -- SCL=0
                    state <= ST_WAIT_ACK_HIGH;

                when ST_WAIT_ACK_HIGH =>
                    scl_out_en <= '0'; -- SCL=1
                    if sda_in = '1' then
                        ack_error <= '1';
                    end if;
                    state <= ST_STOP;

                when ST_STOP =>
                    sda_out_en <= '0'; -- SDA=1 при SCL=1 → STOP
                    scl_out_en <= '0';
                    state <= ST_IDLE;

            end case;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Open-Drain
    ----------------------------------------------------------------
    scl <= i2c_clk;
    sda <= '0' when sda_out_en = '1' else 'Z';
    sda_in <= sda;

    tx_busy <= '1' when state /= ST_IDLE else '0';

end architecture;
