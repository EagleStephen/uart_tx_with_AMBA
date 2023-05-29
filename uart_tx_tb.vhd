-------------------------------------------------------------------------------
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_tb is
end uart_tx_tb;

architecture tb of uart_tx_tb is

    -- Signals
    signal Clk     : std_logic := '0';
    signal Rst     : std_logic := '0';
    signal StopClock : boolean := FALSE;
    
    -- AMBA
    signal Wdata   : std_logic_vector(7 downto 0) := (others => '0');
    signal Rdata   : std_logic_vector(7 downto 0);
    signal Adress  : std_logic_vector(7 downto 0) := (others => '0');
    signal RW      : std_logic := '0';
    signal Req     : std_logic := '0';
    signal Ack     : std_logic;
    
    -- Registers
    signal reg_ctrl : std_logic_vector(7 downto 0);                                    
    signal reg_data : std_logic_vector(7 downto 0) := (others => '0');   

    -- TX
    signal Tx      : std_logic;
    signal IRQ     : std_logic;

   

begin
    UUT: entity work.UART_TX(ARCH_TX)
    port map (
        Clk     => Clk,
        Rst     => Rst,
        Wdata   => Wdata,
        Rdata   => Rdata,
        Adress  => Adress,
        RW      => RW,
        Req     => Req,
        Ack     => Ack,
        Tx      => Tx,
        IRQ     => IRQ
    );

      ClockGen: process is
      begin
        while not StopClock loop
          Clk <= '0';
          wait for 10 ns;
          Clk <= '1';
          wait for 10 ns;
        end loop;
        wait;
      end process ClockGen;

  
      -----------------   Stimulus -----------------------
      Stim: process is
      begin
      ---------------- Initialisation --------------------
      
      Req <= '0';
      Rst <= '0';              -- Rst : active on low 
      Adress <= "00000000";
      Wdata <= "00000000";
      RW <= '0'; 
      

      wait for 20 ns;
      Rst <='1';                -- Rst : deactivated
      wait for 20 ns;
      
      --------------- Writing sequence -----------------

      wait until rising_edge (Clk); 
      Req <= '1';
      RW <= '1';     --  RW on high means writing mode 
      Adress <= "00000001";
      Wdata <= "11000011";
      

      wait until Ack <= '1';
      wait until rising_edge (Clk);
      Req <= '0'; 
      RW <= '0';
      Adress <= "00000001"; 
      
      
      wait for 20 ns;
      --------------- Reading sequence -------------------
      wait until rising_edge(Clk);
      Req <= '1';
      RW <= '0';
      Adress <= "00000001";

      wait until Ack <= '1';
      wait until rising_edge (Clk); 

      -------------- End of Transmission 1 ---------------
      wait until IRQ = '1';
      wait for 20 ns;


      --------------- Reset States --------------------
      wait until rising_edge (Clk);
      Req <= '0'; 
      RW <= '0';
      Adress <= "00000000";
      Wdata <= "00000000";
      RW <= '0'; 
      

      wait for 20 ns;
      Rst <='1';                -- Rst : deactivated
      wait for 20 ns;
      
      --------------- Writing sequence -----------------

      wait until rising_edge (Clk); 
      Req <= '1';
      RW <= '1';     --  RW on high means writing mode 
      Adress <= "00000001";
      Wdata <= "00011000";
      

      wait until Ack <= '1';
      wait until rising_edge (Clk);
      Req <= '0'; 
      RW <= '0';
      Adress <= "00000001"; 
      
      
      wait for 20 ns;
      --------------- Reading sequence -------------------
      wait until rising_edge(Clk);
      Req <= '1';
      RW <= '0';
      Adress <= "00000001";

      wait until Ack <= '1';
      wait until rising_edge (Clk); 

      --------------
      wait until IRQ = '1';
      wait for 20 ns;

      StopClock <= true;
      wait;
      end process;
-- 


end tb;
