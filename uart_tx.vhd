-- Copyright (c) VOXTRONAUTS
-- Use of this source code through a simulator and/or a compiler tool
-------------------------------------------------------------------------------
-- File : uart_tx_tb.vhd
-- Author : Stephen Neopane 
-- Created : 03 May 2023
-- Last update : 09 May 2023
-- Simulators : ModelSim SE 10.5c
-- Synthesizers: QModelSim SE 10.5c
-- Targets :
-- Dependency : None
----------------------------------------------------------------------
-- Description : Description of my package
----------------------------------------------------------------------
-- Version : 1
-- Date : 2023 3rd May 
-- Modifier : Stephen Neopane	
-- Modif. : 
-- Second Line of my modifications : 
---------------------------------------------------------------------
----------------------- Libraries in use -----------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

------------------------ UART TX ENTITY ------------------------------
ENTITY uart_tx IS
    PORT (

        Clk : IN STD_LOGIC;
        Rst : IN STD_LOGIC;
        -- AMBA Interface
        Wdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        Rdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        Adress : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        RW : IN STD_LOGIC;
        Req : IN STD_LOGIC;
        Ack : OUT STD_LOGIC;
        -- UART Tx Interface
        Tx : OUT STD_LOGIC;
        IRQ : OUT STD_LOGIC
    );
END uart_tx;

--------------------------- ARCHITECTURE -----------------------------
ARCHITECTURE ARCH_TX OF uart_tx IS

    ------------------------- Baudrate calculation ---------------------
    -- Baudrate calculation                                                 -- Formula for the clock cycle per bit calculation : ((1/b) / (1/f))
    CONSTANT DIVISOR : INTEGER := 434;                                      -- (1/b)/(1/50_000_000)  = 434.02      

    ------------- State machine for UART operation ------------------
    TYPE state IS (idle, start, data, parity, stop);

    ------------------------ Memory ------------------------------
    TYPE memory_type IS ARRAY (0 TO 1) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

    -------------------------- Signals  -----------------------------

    --                                                             
    -- Counter for baudrate generation                 
    SIGNAL counter : INTEGER RANGE 0 TO DIVISOR - 1 := 0; --  Initialised to 0 

    -- State
    SIGNAL current_state : state := idle;

    -- Bit counter
    SIGNAL bit_count : INTEGER RANGE 0 TO 7 := 0;

    -- Start Transmit
    SIGNAL start_transmit : STD_LOGIC;

    -- Register
    SIGNAL memo : memory_type;                                                -- 0x00 Storage for control register | 0x01 Storage for data register
    SIGNAL reg_ctrl : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');        -- reg_ctrl(0) <= 1 for start_bit | reg_ctrl(1) <= 1 for parity bit | reg_ctrl <= 00 for stop bit              
    SIGNAL reg_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');        -- storage for the 8 bit data that needs to be transmitted over the UART
    SIGNAL reg_data_buffer : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- Buffer for reg_data (temporary storage for data bits )

    ---------------------- ARCHITECTURE BEGIN ----------------------------           
BEGIN
    --------------------AMBA Process -AXI4 Lite --------------------------  
    AMBA : PROCESS (Clk, Rst, Req) IS
    BEGIN
        IF Rst = '0' THEN                                                    -- Reset active on low 
            Ack <= '0';
            Rdata <= (OTHERS => '0');
            memo(0) <= (OTHERS => '0'); 
            memo(1) <= (OTHERS => '0'); 
        ELSE
            IF rising_edge(Clk) THEN
                IF Req = '1' AND RW = '1' THEN                                -- When RW = 1 => Write Mode else Read Mode
                    memo(1) <= Wdata;                                         -- Write on 0x01  
                    Ack <= '1';                                               -- Acknowledgement 
                    memo(0) <= "00000001";                                    -- Trigger start_transmit through 0x00 
                ELSIF Req = '1' AND RW = '0' THEN                             
                    Rdata <= memo(1);                                         -- Read 0x01 
                    Ack <= '1';
                    --memo(0) <= "00000001";  
                ELSIF Req = '0' THEN                                          -- No request 
                    Ack <= '0';
                END IF;
            ELSE
                IF Req = '0' AND RW = '0' THEN                                -- Reset Acknowledge
                    Ack <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS AMBA;

    ----------------------------- Start Transmit -------------------------------
    start_transmit_process : PROCESS (Clk, Reg_ctrl, current_state)
    BEGIN
        IF Rst = '0' THEN
            start_transmit <= '0';
        ELSE
            IF rising_edge(Clk) THEN
                IF memo(0) = "00000001" AND current_state = IDLE THEN       -- Combinational logic to generate a simple pulse to trigger FSM
                    start_transmit <= '1';
                ELSIF memo(0) = "00000001" THEN                             -- Reset start_transmit 
                    start_transmit <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS start_transmit_process;

    ------------------------- TX signal states -----------------------------    
    Tx_state_machine : PROCESS (Clk, current_state, reg_ctrl, counter, memo, start_transmit,reg_data)
    BEGIN
        IF rising_edge(Clk) THEN
            IF Rst = '0' THEN                                               -- Initial values on reset
                IRQ <= '0';
                counter <= 0;
                current_state <= idle;
            ELSE
                CASE current_state IS
                    WHEN idle =>                                            -- Default State where tx = 1 unless start pulse 
                        --reg_data <= memo(1);                                -- Load data from memory
                        --reg_ctrl <= memo(0);                                -- Load controls from memory
                        IF start_transmit = '1' THEN                        -- Starting the Uart data trame                     
                            counter <= 0;                                   -- Setting the counter to 0
                            current_state <= start;                         -- Next state 
                        ELSE
                            current_state <= idle;
                        END IF;

                    WHEN start =>                                           -- Start state 
                        IF counter = DIVISOR - 1 THEN                       -- if counter = max value then we know we have been through 1 bit 
                            counter <= 0;                    
                            reg_ctrl(1) <= reg_data(7) XOR reg_data(6) XOR reg_data(5) XOR reg_data(4) XOR reg_data(3) XOR reg_data(2) XOR reg_data(1) XOR reg_data(0); -- Parity Bit 
                            current_state <= data;                          -- Start the data bit state
                        ELSE
                            counter <= counter + 1;                         -- Continue counting 
                            current_state <= start;
                            reg_data <= memo(1);                                -- Load data from memory
                            reg_ctrl <= memo(0); 
                            reg_data_buffer <= reg_data;
                        END IF;

                    WHEN data =>
                        IF counter = DIVISOR - 1 THEN                       -- Data state
                            counter <= 0;                                   
                            IF bit_count = 7 THEN                           -- Count from 0 to 7 
                                bit_count <= 0;
                                current_state <= parity;                    
                            ELSE
                                bit_count <= bit_count + 1;                 -- Increment the counter 
                                reg_data_buffer <= reg_data_buffer;
                                reg_data_buffer <= '0' & reg_data_buffer(7 DOWNTO 1);     -- Register values are shifted right by one position, Starting with LSB and preparing for the next bit transmission.
                                current_state <= data;
                            END IF;
                        ELSE
                            counter <= counter + 1;
                        END IF;

                    WHEN parity =>                                          -- Parity State 
                        IF counter = DIVISOR - 1 THEN                       
                            counter <= 0;
                            current_state <= stop;                          
                        ELSE
                            counter <= counter + 1;
                            current_state <= parity;
                        END IF;

                    WHEN stop =>
                        IF counter = DIVISOR - 1 THEN                       -- Stop state 
                            counter <= 0;
                            current_state <= idle;                          -- Return to the default State (IDLE)
                            reg_ctrl <= "00000000";                         -- Stop bit : when reg_ctrl is empty (filled with 0)
                            IRQ <= '1';                                     -- IRQ : Interrupt Pulse           
                            
                        ELSE
                            counter <= counter + 1;
                            current_state <= stop;
                            IRQ <= '0';                                     -- Reset IRQ 
                        END IF;
                END CASE;

            END IF;
        END IF;
    END PROCESS Tx_state_machine;

    ---------------------------- Tx signal generation --------------------------
    tx_signal_process : PROCESS (Clk)
    BEGIN
        IF Rst = '0' THEN
            tx <= '1';
        ELSIF rising_edge(Clk) THEN
            CASE current_state IS
                WHEN idle => tx <= '1';                                     -- Default State 
                WHEN start => tx <= '0';                                    -- Start bit as 0
                WHEN data => tx <= reg_data_buffer(0);                      -- Send each Bit position from 0 to 7
                WHEN parity => tx <= reg_ctrl(1);                           -- Tx getting the 
                WHEN stop => tx <= '1';                                     -- Returning to idle state after 0 as stop bit
            END CASE;
        END IF;
    END PROCESS tx_signal_process;
    -------------------------------------------------------------------------------
END ARCHITECTURE;
