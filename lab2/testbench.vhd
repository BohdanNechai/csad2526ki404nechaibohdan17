library ieee;
use ieee.std_logic_1164.all;

entity testbench is
end entity;

architecture sim of testbench is
    signal clk  : std_logic := '0';
    signal rstn : std_logic := '0';
    signal start : std_logic := '0';
    signal data  : std_logic_vector(7 downto 0) := "10101010";

	 signal scl : std_logic := 'Z';
	 signal sda : std_logic := 'Z';

    signal busy     : std_logic;
    signal rx_byte  : std_logic_vector(7 downto 0);
    signal rx_done  : std_logic;

begin
pullup_scl: process(scl) begin
    if scl = 'Z' then
        scl <= '1';
    end if;
end process;

pullup_sda: process(sda) begin
    if sda = 'Z' then
        sda <= '1';
    end if;
end process;

    -- Генеруємо такт 50 МГц / 20ns
    clk <= not clk after 10 ns;

    -- === MASTER ===
    uut_master: entity work.i2c_master_tx
        port map(
            clk        => clk,
            reset_n    => rstn,
            start_tx   => start,
            byte_to_tx => data,
            tx_busy    => busy,
            ack_error  => open,
            scl        => scl,
            sda        => sda
        );

    -- === SLAVE ===
    uut_slave : entity work.i2c_slave_rx
        port map(
            clk     => clk,
            reset_n => rstn,
            scl     => scl,
            sda     => sda,
            byte_received => rx_byte,
            rx_done       => rx_done
        );

    -- Стимули
  stimulus_proc : process
begin
    -- Reset
    rstn <= '0';
    wait for 200 ns;
    rstn <= '1';
    
    -- Чекаємо стабілізації i2c_clk (дуже важливо!)
    wait for 50 us;

    -- Запускаємо передачу байта
    start <= '1';
    wait until busy = '1';  -- майстер ПІДХОПИВ команду
    start <= '0';

    -- Чекаємо завершення передачі
    wait until busy = '0';

    -- Все, можна завершувати або передавати ще байт
    wait;
end process;


end architecture;
