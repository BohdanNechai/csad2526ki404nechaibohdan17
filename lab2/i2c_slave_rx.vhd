library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Модуль приймача I2C (Slave-Rx).
-- Завдання: прийняти один байт по шині і відправити ACK.
entity i2c_slave_rx is
    port (
        -- === Входи ===
        clk     : in  std_logic; -- Системний такт (напр. 50МГц)
        reset_n : in  std_logic; -- Скидання (активний '0')
        
        -- === Шина I2C ===
        scl : in  std_logic; -- SCL (тільки слухаємо)
        sda : inout std_logic; -- SDA (читаємо дані + відправляємо ACK)
        
        -- === Виходи ===
        byte_received : out std_logic_vector(7 downto 0); -- Сюди пишемо прийнятий байт
        rx_done       : out std_logic -- Прапорець "готово", імпульс на 1 такт
    );
end entity i2c_slave_rx;

architecture rtl of i2c_slave_rx is

    -- Стани для FSM (автомату)
    type t_state is (
        ST_IDLE,      -- Чекаємо на START
        ST_RX_BYTE,   -- Приймаємо 8 біт
        ST_SEND_ACK,  -- Відправляємо ACK ('0')
        ST_WAIT_STOP  -- Чекаємо на STOP
    );
    signal state : t_state := ST_IDLE;
    
    -- Регістри для синхронізації SCL/SDA (!!дуже важливо!!)
    -- бо SCL/SDA асинхронні до нашого 'clk'
    signal scl_sync1, scl_sync2 : std_logic;
    signal sda_sync1, sda_sync2 : std_logic;

    -- Сигнали-детектори (ловлять події на шині)
    signal scl_rising_edge  : std_logic; -- Знайшли позитивний фронт SCL
    signal scl_falling_edge : std_logic; -- Знайшли негативний фронт SCL
    signal start_condition  : std_logic; -- Знайшли умову START
    signal stop_condition   : std_logic; -- Знайшли умову STOP

    -- Внутрішні сигнали
    signal bit_counter : integer range 0 to 7;          -- Лічильник біт (від 7 до 0)
    signal rx_buffer   : std_logic_vector(7 downto 0); -- Тут збираємо прийнятий байт
    signal sda_o_en    : std_logic := '0';          -- '1' = я керую SDA (для ACK)
    signal s_rx_done   : std_logic;                   -- Внутрішній сигнал для rx_done

begin

    -- ================================================================
    -- Блок 1: Синхронізація та Детектори
    -- ================================================================

    -- Спочатку переганяємо асинхронні SCL/SDA у наш тактовий домен 'clk'
    -- (простий 2-флоповий синхронізатор)
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            scl_sync1 <= '0'; 
            scl_sync2 <= '0';
            sda_sync1 <= '0'; 
            sda_sync2 <= '0';
        elsif rising_edge(clk) then
            scl_sync1 <= scl; 
            scl_sync2 <= scl_sync1;
            sda_sync1 <= sda; 
            sda_sync2 <= sda_sync1;
        end if;
    end process;
    
    -- Тепер на основі синхронізованих сигналів робимо детектори
    -- (вони дадуть імпульс на 1 такт 'clk', коли зловлять подію)
    
    -- Ловимо фронти SCL
    scl_rising_edge  <= '1' when scl_sync1 = '0' and scl_sync2 = '1' else '0';
    scl_falling_edge <= '1' when scl_sync1 = '1' and scl_sync2 = '0' else '0';
    
    -- Ловимо умови START/STOP (вони відбуваються, коли SCL = '1')
    start_condition  <= '1' when scl_sync2 = '1' and sda_sync1 = '1' and sda_sync2 = '0' else '0'; -- SDA 1->0, поки SCL=1
    stop_condition   <= '1' when scl_sync2 = '1' and sda_sync1 = '0' and sda_sync2 = '1' else '0'; -- SDA 0->1, поки SCL=1


    -- ================================================================
    -- Блок 2: FSM (Скінченний автомат)
    -- ================================================================
    
    -- Основний процес, працює від нашого системного 'clk'
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            state       <= ST_IDLE;
            bit_counter <= 7;
            sda_o_en    <= '0';
            s_rx_done   <= '0';
            rx_buffer   <= (others => '0');
        elsif rising_edge(clk) then
            
            s_rx_done <= '0'; -- Скидаємо прапорець "готово" (він імпульсний)
            
            -- START та STOP мають найвищий пріоритет.
            -- Вони можуть перервати будь-який стан у будь-який час.
            if start_condition = '1' then
                state       <= ST_RX_BYTE;
                bit_counter <= 7; -- Готуємось приймати 8 біт (з 7-го до 0-го)
                sda_o_en    <= '0';
            elsif stop_condition = '1' then
                state       <= ST_IDLE;
                sda_o_en    <= '0';
            else
                -- Якщо не було START/STOP, працює звичайна логіка станів
                case state is
                    
                    -- Стан: Чекаємо на START
                    when ST_IDLE =>
                        -- Детектор 'start_condition' вище зробить всю роботу
                        null; 
                        
                    -- Стан: Приймаємо 8 біт
                    when ST_RX_BYTE =>
                        if scl_rising_edge = '1' then -- Читаємо біт по позитивному фронту SCL
                            rx_buffer(bit_counter) <= sda_sync2; -- Записуємо біт з SDA в буфер
                            
                            if bit_counter = 0 then
                                state <= ST_SEND_ACK; -- Прийняли 8-й біт (0-й), йдемо відправляти ACK
                            else
                                bit_counter <= bit_counter - 1; -- Рахуємо далі
                            end if;
                        end if;
                        
                    -- Стан: Відправляємо ACK
                    when ST_SEND_ACK =>
                        sda_o_en <= '1'; -- Вмикаємо свій вихід (тягнемо SDA до '0')
                        
                        if scl_rising_edge = '1' then -- Чекаємо 9-й такт SCL
                            state       <= ST_WAIT_STOP; -- ACK відправлено
                            s_rx_done   <= '1';         -- Виставляємо прапорець "Готово" на 1 такт
                            sda_o_en    <= '0';         -- Відпускаємо SDA
                        end if;

                    -- Стан: Чекаємо на STOP
                    when ST_WAIT_STOP =>
                        -- Детектор 'stop_condition' вище зробить всю роботу
                        null;
                        
                    when others =>
                        state <= ST_IDLE;
                        
                end case;
            end if;
        end if;
    end process;
    
    -- ================================================================
    -- Блок 3: Логіка виходів
    -- ================================================================
    
    -- Керування SDA: '0' для ACK, інакше 'Z' (високий імпеданс, слухаємо)
    sda <= '0' when sda_o_en = '1' else 'Z';

    -- Виставляємо прийнятий байт та прапорець "готово" на вихідні порти
    byte_received <= rx_buffer;
    rx_done       <= s_rx_done;

end architecture rtl;