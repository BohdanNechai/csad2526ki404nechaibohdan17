library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Мій I2C Master (передавач, Tx)
-- Завдання: відправити один байт (адресу або дані).
entity i2c_master_tx is
    generic (
        -- Вхідний такт з ПЛІС (напр., 50 МГц)
        SYS_CLK_FREQ : integer := 50_000_000; 
        -- Такт I2C, який я генерую (напр., 100 кГц)
        I2C_CLK_FREQ : integer := 100_000 
    );
    port (
        -- === Входи ===
        clk         : in  std_logic; -- Системний такт
        reset_n     : in  std_logic; -- Скидання (активний '0')
        start_tx    : in  std_logic; -- "start" - кнопка, щоб почати передачу
        byte_to_tx  : in  std_logic_vector(7 downto 0); -- Байт, який треба відправити
        
        -- === Виходи ===
        tx_busy     : out std_logic; -- '1' поки зайнятий
        ack_error   : out std_logic; -- '1' якщо Slave не відповів (помилка NACK)
        
        -- === Лінії шини I2C ===
        scl         : inout std_logic; -- SCL
        sda         : inout std_logic  -- SDA (двонаправлена)
    );
end entity i2c_master_tx;

architecture rtl of i2c_master_tx is

    -- 1. Дільник частоти
    -- Розрахунок коефіцієнту ділення
    constant CLK_DIV_RATIO : integer := SYS_CLK_FREQ / (2 * I2C_CLK_FREQ);
    -- Лічильник для ділення
    signal clk_div_cnt : integer range 0 to CLK_DIV_RATIO;
    -- Мій згенерований такт 100 кГц (i2c_clk)
    signal i2c_clk     : std_logic := '0'; 

    -- 2. Стани автомату (FSM)
    type t_state is (
        ST_IDLE,
        ST_START,
        ST_TX_BYTE,
        ST_WAIT_ACK,
        ST_STOP
    );
    signal state       : t_state := ST_IDLE;

    -- 3. Робочі сигнали і регістри
    signal bit_counter : integer range 0 to 7; -- Лічильник біт (від 7 до 0)
    signal tx_buffer   : std_logic_vector(7 downto 0); -- Буфер, куди копіюється byte_to_tx
    signal sda_i       : std_logic; -- Сюди читаю SDA (для перевірки ACK)
    signal sda_o_en    : std_logic := '0'; -- '1' = я тягну SDA до '0'
    signal scl_o_en    : std_logic := '0'; -- '1' = я тягну SCL до '0'
    
    -- Внутрішні сигнали для виходів
    signal s_tx_busy   : std_logic := '0';
    signal s_ack_error : std_logic := '0';

begin

    -- ================================================================
    -- Блок 1. Генератор такту i2c_clk (100 кГц)
    -- ================================================================
    -- Робить з 50 МГц меандр 100 кГц (ділить на CLK_DIV_RATIO)
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            clk_div_cnt <= 0;
            i2c_clk     <= '0';
        elsif rising_edge(clk) then
            if clk_div_cnt >= CLK_DIV_RATIO - 1 then
                clk_div_cnt <= 0;
                i2c_clk     <= not i2c_clk;
            else
                clk_div_cnt <= clk_div_cnt + 1;
            end if;
        end if;
    end process;

    -- ================================================================
    -- Блок 2. FSM (Сам автомат)
    -- ================================================================
    -- Цей процес працює по ПОЗИТИВНОМУ фронту i2c_clk (коли SCL=high)
    process (i2c_clk, reset_n)
    begin
        if reset_n = '0' then
            state       <= ST_IDLE;
            s_tx_busy   <= '0';
            s_ack_error <= '0';
            bit_counter <= 7;
            scl_o_en    <= '0';
            sda_o_en    <= '0';
        elsif rising_edge(i2c_clk) then
            
            -- Логіка переходів FSM
            case state is
                
                -- ST_IDLE: Чекаю на 'start_tx'
                when ST_IDLE =>
                    s_tx_busy <= '0';
                    s_ack_error <= '0';
                    scl_o_en  <= '0'; -- SCL/SDA відпущені (Z)
                    sda_o_en  <= '0'; 
                    
                    if start_tx = '1' then
                        state       <= ST_START;
                        tx_buffer   <= byte_to_tx; -- Копіюю вхідний байт в буфер
                        bit_counter <= 7;           -- Скидаю лічильник
                        s_tx_busy   <= '1';
                    end if;

                -- ST_START: Генерую START
                -- (Тягну SDA до '0', SCL ще '1' - це і є START)
                when ST_START =>
                    scl_o_en <= '1'; -- Готуюсь тягнути SCL до '0'
                    sda_o_en <= '1'; -- Вже тягну SDA до '0'
                    state    <= ST_TX_BYTE;

                -- ST_TX_BYTE: Відправляю 8 біт
                when ST_TX_BYTE =>
                    scl_o_en <= '1'; -- SCL/SDA під моїм контролем
                    sda_o_en <= '1'; 
                    
                    -- (Дані виставляються в Блоці 3 по negedge)
                    
                    if bit_counter = 0 then
                        state <= ST_WAIT_ACK; -- 8 біт відправив, час чекати ACK
                    else
                        bit_counter <= bit_counter - 1; -- Рахую біти
                        state       <= ST_TX_BYTE;     -- Залишаюсь тут
                    end if;

                -- ST_WAIT_ACK: Чекаю на 9-й біт (ACK)
                when ST_WAIT_ACK =>
                    scl_o_en <= '1'; -- Продовжую генерувати 9-й такт SCL
                    sda_o_en <= '0'; -- ВІДПУСКАЮ SDA (Z), щоб Slave міг її притягнути
                    
                    -- (Читаю ACK в Блоці 3 по negedge)
                    
                    if sda_i = '1' then -- Перевіряю, чи був ACK. '1' = NACK (помилка)
                        s_ack_error <= '1'; 
                    end if;
                    state <= ST_STOP;

                -- ST_STOP: Генерую STOP
                when ST_STOP =>
                    scl_o_en <= '0'; -- Відпускаю SCL ('Z' = high)
                    sda_o_en <= '1'; -- Тримаю SDA ('0')
                    -- (На наступному ris_edge SDA відпуститься - це і є STOP)
                    state <= ST_IDLE;
                    
            end case;
        end if;
    end process;

    -- ================================================================
    -- Блок 3. Логіка даних
    -- ================================================================
    -- Цей процес працює по НЕГАТИВНОМУ фронту i2c_clk (коли SCL=low)
    -- (Правило I2C: міняти дані, коли SCL=low)
    process (i2c_clk, reset_n)
    begin
        if reset_n = '0' then
            sda_o_en <= '0';
        elsif falling_edge(i2c_clk) then
            
            -- Читаю лінію SDA (для перевірки ACK в Блоці 2)
            sda_i <= sda; 
            
            if state = ST_TX_BYTE then
                -- Готую наступний біт (зсуваю буфер вліво)
                tx_buffer <= tx_buffer(6 downto 0) & '0'; 
            end if;
            
            if state = ST_STOP then
                -- Відпускаю SDA (Блок 2 згенерує STOP на ris_edge)
                sda_o_en <= '0';
            end if;
        end if;
    end process;
    
    -- ================================================================
    -- Блок 4. Фізичне керування лініями (Open-Drain)
    -- ================================================================
    -- 'Z' = відпущено (high, підтягнуто резистором), '0' = притягнуто (low)
    
    -- Керую SCL: тягну до '0', коли scl_o_en='1' і i2c_clk='0'
    scl <= '0' when scl_o_en = '1' and i2c_clk = '0' else 'Z';
    
    -- Керую SDA: тягну до '0', якщо...
    sda <= '0' when sda_o_en = '1' and (state = ST_START or state = ST_TX_BYTE) and tx_buffer(7) = '0' else -- ...треба відправити '0'
           '0' when sda_o_en = '1' and (state = ST_STOP) else -- ...готую STOP
           'Z'; -- ...в усіх інших випадках відпускаю (Z)

    -- Призначення виходів
    tx_busy   <= s_tx_busy;
    ack_error <= s_ack_error;

end architecture rtl;