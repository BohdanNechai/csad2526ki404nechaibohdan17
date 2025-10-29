--! @file i2c_master_tx.vhd
--! @brief I2C Master Transmitter module
--!
--! This module implements the I2C Master functionality for transmitting data
--! (address and data bytes) to a slave device.
--! It generates the SCL clock and controls the SDA line for data output.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Для використання to_integer/to_unsigned, якщо потрібні

--! @brief Entity declaration for the I2C Master Transmitter.
--!
--! Defines the interface (ports) of the I2C Master Transmitter module.
entity i2c_master_tx is
    port (
        -- Global Ports
        i_clk        : in  std_logic;                                --! System clock input
        i_reset_n    : in  std_logic;                                --! Active-low asynchronous reset

        -- I2C Interface Ports
        o_scl        : out std_logic;                                --! SCL clock output to I2C bus
        o_sda        : out std_logic;                                --! SDA data output to I2C bus (Master drives)
        io_sda       : inout std_logic;                              --! Bi-directional SDA line (used in real world, simplified here for Tx-only)

        -- Control Inputs
        i_start_tx   : in  std_logic;                                --! Start transmission pulse (active high)
        i_slave_addr : in  std_logic_vector(6 downto 0);             --! 7-bit Slave address
        i_data_byte  : in  std_logic_vector(7 downto 0);             --! 8-bit Data byte to transmit

        -- Status Outputs
        o_busy       : out std_logic;                                --! Indicates if the I2C Master is busy
        o_ack_error  : out std_logic                                 --! Indicates if a NACK (error) was received
    );
end entity i2c_master_tx;

--! @brief Architecture definition for the I2C Master Transmitter.
--!
--! Contains the internal logic and state machine implementation.
architecture rtl of i2c_master_tx is

    -- State Machine Definition (States)
    type t_state is (
        ST_IDLE,         --! Waiting for a start command
        ST_START,        --! Generating the START condition
        ST_TX_BYTE,      --! Transmitting 8 bits (address or data)
        ST_WAIT_ACK,     --! Waiting for ACK/NACK from slave
        ST_STOP          --! Generating the STOP condition
    );
    signal current_state : t_state := ST_IDLE; --! Current state of the FSM
    signal next_state    : t_state;           --! Next state of the FSM

    -- Internal Signals for I2C bus control
    signal s_scl_int     : std_logic := '1'; --! Internal SCL signal before output buffer
    signal s_sda_int     : std_logic := '1'; --! Internal SDA signal before output buffer (Master drives)
    signal s_sda_oe_n    : std_logic := '1'; --! SDA Output Enable (active low) - controls when Master drives SDA

    -- Internal Counters and Registers
    signal s_bit_cnt     : natural range 0 to 8 := 0; --! Bit counter for 8-bit transmission
    signal s_byte_to_send: std_logic_vector(7 downto 0); --! The current byte being sent (address + R/W, or data)
    signal s_tx_data_reg : std_logic_vector(7 downto 0); --! Shift register for data transmission
    signal s_ack_received: std_logic := '0'; --! Flag to store the ACK/NACK bit from slave

    -- Internal FSM flags
    signal s_data_is_address : std_logic := '1'; --! '1' if sending address, '0' if sending data

    -- SCL clock generation (Example: for 100 kHz I2C from 50 MHz system clock)
    -- This needs a frequency divider
    -- For 100kHz SCL, we need 50MHz / (2 * 100kHz) = 250 cycles for half a period
    constant C_SCL_HALF_PERIOD_CNT : natural := 250; -- Example for 100kHz I2C from 50MHz CLK
    signal s_scl_clk_cnt   : natural range 0 to C_SCL_HALF_PERIOD_CNT - 1 := 0;
    signal s_scl_clk_toggle: std_logic := '0'; -- Toggles at half period to generate SCL

begin

    --! @brief I2C SCL Clock Generator Process
    --! Divides the system clock to generate the I2C SCL signal.
    process (i_clk, i_reset_n)
    begin
        if i_reset_n = '0' then
            s_scl_clk_cnt    <= 0;
            s_scl_clk_toggle <= '0';
        elsif rising_edge(i_clk) then
            if s_scl_clk_cnt = C_SCL_HALF_PERIOD_CNT - 1 then
                s_scl_clk_cnt    <= 0;
                s_scl_clk_toggle <= not s_scl_clk_toggle; -- Toggle SCL internal clock
            else
                s_scl_clk_cnt <= s_scl_clk_cnt + 1;
            end if;
        end if;
    end process;

    --! Assign SCL output based on internal SCL signal and clock toggle for I2C bit timing
    -- We need to control SCL explicitly by the FSM for START/STOP/ACK
    -- This is a placeholder for FSM to manage SCL directly
    -- For I2C, SCL is often controlled directly by state.
    o_scl <= s_scl_int;

    --! @brief SDA Bi-directional Buffer Control
    --! Controls when the Master drives SDA and when it listens.
    --! When s_sda_oe_n = '0', Master drives s_sda_int onto io_sda.
    --! When s_sda_oe_n = '1', Master tri-states io_sda (listens)
    io_sda <= s_sda_int when s_sda_oe_n = '0' else 'Z';


    --! @brief FSM State Register
    --! Updates the current state on the rising edge of the clock.
    process (i_clk, i_reset_n)
    begin
        if i_reset_n = '0' then
            current_state <= ST_IDLE;
        elsif rising_edge(i_clk) then
            current_state <= next_state;
        end if;
    end process;

    --! @brief FSM Next State and Output Logic
    --! Determines the next state and combinatorial outputs based on the current state.
    process (current_state, i_start_tx, s_bit_cnt, s_ack_received, s_data_is_address, i_slave_addr, i_data_byte)
    begin
        -- Default assignments (important for combinational logic)
        next_state <= current_state; -- Stay in current state by default
        o_busy     <= '0';
        o_ack_error<= '0';
        s_scl_int  <= '1';           -- Default SCL high (idle or during data stable)
        s_sda_int  <= '1';           -- Default SDA high (idle or tri-state)
        s_sda_oe_n <= '1';           -- Default SDA tri-state (listen)
        s_byte_to_send <= (others => '0'); -- Default

        case current_state is
            when ST_IDLE =>
                o_busy     <= '0';
                s_scl_int  <= '1';
                s_sda_int  <= '1';
                s_sda_oe_n <= '1'; -- Ensure SDA is released and high
                if i_start_tx = '1' then
                    next_state <= ST_START;
                    s_data_is_address <= '1'; -- First, send address
                else
                    next_state <= ST_IDLE;
                end if;

            when ST_START =>
                o_busy     <= '1';
                s_scl_int  <= '1';      -- SCL is high
                s_sda_int  <= '0';      -- SDA is pulled low
                s_sda_oe_n <= '0';      -- Master drives SDA
                s_bit_cnt  <= 7;        -- Start bit counter from MSB (7 down to 0)
                -- Prepare the first byte to send (Slave Address + Write bit)
                s_byte_to_send <= i_slave_addr & '0'; -- Assuming write operation for now
                s_tx_data_reg  <= i_slave_addr & '0';
                next_state <= ST_TX_BYTE;

            when ST_TX_BYTE =>
                o_busy     <= '1';
                s_sda_oe_n <= '0'; -- Master drives SDA
                s_scl_int  <= s_scl_clk_toggle; -- Use internal clock to generate SCL pulses
                s_sda_int  <= s_tx_data_reg(s_bit_cnt); -- Output current bit

                -- When SCL is low, prepare for next bit or state transition
                if s_scl_clk_toggle = '0' then
                    if s_bit_cnt = 0 then
                        next_state <= ST_WAIT_ACK; -- All 8 bits sent, go wait for ACK
                    else
                        s_bit_cnt <= s_bit_cnt - 1;
                    end if;
                end if;
                -- This state needs careful timing control to ensure SDA changes when SCL is low

            when ST_WAIT_ACK =>
                o_busy     <= '1';
                s_sda_oe_n <= '1';       -- Release SDA, let Slave drive
                s_scl_int  <= s_scl_clk_toggle; -- Generate 9th clock pulse

                if s_scl_clk_toggle = '1' then -- Read SDA when SCL is high
                    -- Read io_sda here, store in s_ack_received
                    -- The actual reading logic often happens in a clocked process for stability
                    -- For now, conceptual: s_ack_received <= io_sda;
                end if;

                -- Decision based on ACK/NACK
                if s_scl_clk_toggle = '0' then -- After 9th SCL cycle
                    if s_ack_received = '1' then -- NACK received
                        o_ack_error <= '1';
                        next_state  <= ST_STOP;
                    else -- ACK received
                        if s_data_is_address = '1' then
                            s_data_is_address <= '0'; -- Next, send data
                            s_bit_cnt <= 7;
                            s_tx_data_reg <= i_data_byte; -- Prepare data byte
                            next_state <= ST_TX_BYTE;
                        else -- We just sent data and got ACK
                            next_state <= ST_STOP;
                        end if;
                    end if;
                end if;

            when ST_STOP =>
                o_busy     <= '1';
                s_sda_oe_n <= '0';       -- Master drives SDA for STOP condition
                s_scl_int  <= '1';       -- SCL high
                s_sda_int  <= '1';       -- SDA goes high after SCL high (STOP condition)
                next_state <= ST_IDLE;   -- Always return to IDLE after STOP

            when others =>
                next_state <= ST_IDLE; -- Fallback for undefined states
        end case;
    end process;

end architecture rtl;