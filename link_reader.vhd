-- Dual port instruction RAM holds the instructions for the Bellman Ford Algorithm
-- RAM contains, starting and termination node addresses and link value
-- The RAM instantiated can be used for both reading and writing simultaneously
-- The instruction RAM is used only for reading, although when streaming data
-- writing to the instruction RAM is required

-- Link reader is implemented as a pure processing unit and the controller has been
--decoupled, for ease of design and testing

--Testing history
--completed single unit test, no faults

library ieee;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
use ieee.math_real.all;

entity link_reader is
generic(link_size, addr_size : integer);
port (
    clk: in std_logic;
    reset: in std_logic:='1'; --active asynchronous low reset
    l_read_request : in std_logic;
    l_write_request : in std_logic;
    rd_addr : in std_logic_vector((addr_size-1) downto 0);
    wr_addr : in std_logic_vector((addr_size-1) downto 0);
    wr_di : in std_logic_vector((link_size-1) downto 0); --
    rd_do : out std_logic_vector((link_size-1) downto 0);--
    wr_do : out std_logic_vector((link_size-1) downto 0);--
    empty_link : out std_logic;
    n_read_request : out std_logic
    );
end link_reader;

architecture beh of link_reader is

    --(0,1), (1,3), (0,3), (3,2), (2,0), (2,4), (4,3), (3,1)
    --Links stored in lnik RAM can either be hardcoded or streamed from an external circuit
    type ram_type is array (0 to ((2**addr_size)-1)) of std_logic_vector ((link_size-1) downto 0);
    signal RAM : ram_type:= (
    "00000100000100",
    "01000100000001",
    "00001000000010",
    "00101100000110",
    "01001100000001",
    "00110000000010",
    "01110000000010",
    "01101000000001"
    );
    
    --Value of the link used for comparison and identification of an empty link
    signal zero_link_value : std_logic_vector(link_size-1 downto 0);
    signal BASE_ADDRESS : std_logic_vector(addr_size-1 downto 0);
    
    --All positive edges graph with empty link
--    "00000100000100",
--  "01000100000001",
--  "00001000000010",
--  "00101100000110",
--  "01001100000001",
--  "00110000000010",
--  "01110000000010",
--  "00000000000000"
    
    --Original weighted graph with negative weightings
    --"00000100010111", --(0,1)
    --"00101100001101", --(1,3) 
    --"00001100000101", --(0,3) 
    --"01101011111101", --negative (3,2) 
    --"01000011111101", --negative (2,0)
    --"01010000100000", --(2,4)
    --"10001100010100", --(4,3)
    --"01100100001110"); --(3,1)
    
begin
    process (reset, rd_addr, wr_addr, l_read_request, l_write_request) begin
        if(reset='0') then
            rd_do <= (others=>'0');
            wr_do <= (others=>'0');
            zero_link_value <= (others=>'0');
            n_read_request <= '0';
            empty_link <= '0';
            BASE_ADDRESS <= (others=>'0');
        else
            --By default, request to read nodes from Node RAM
            n_read_request <= '1';
            --Check whether the read address is the reset condition "000"
            --Check whether the link value associated with read address is empty e.g all '0's
            if(l_read_request='1' AND l_write_request='0') then
                    if(rd_addr > "000") then
                        if(RAM(to_integer(unsigned(rd_addr))) = zero_link_value) then
                             report "LRW=10, Read address>000, empty_link=1";
                             --BASE_ADDRESS must be available immediately since si confliction is calculated at the
                             --falling edge in the arithmetic circuit
                             --Otherwise SI confliction will be with an empty link
                             rd_do <= RAM(to_integer(unsigned(BASE_ADDRESS)));
                             empty_link <= '1';
                           elsif(not (RAM(to_integer(unsigned(rd_addr))) = zero_link_value)) then
                             report "LRW=10, Read address>000, empty_link=0";
                             empty_link <= '0';
                             rd_do <= RAM(to_integer(unsigned(rd_addr)));
                           else
                        end if;
                        elsif(rd_addr = "000") then
                            report "LRW=10, Read address=000, empty_link=0";
                            rd_do <= RAM(to_integer(unsigned(rd_addr)));
                            empty_link <= '0';
                        else
                    end if; 
                elsif(l_read_request='0' AND l_write_request='1') then
                    --Link writing currently not implemented, requires writing interface circuit
                    --Below code may need changing in order to detect error conditions dependent on
                    --writing itnerface circuit
                    RAM(to_integer(unsigned(wr_addr))) <= wr_di;
                    wr_do <= RAM(to_integer(unsigned(wr_addr)));
                elsif(l_read_request='1' AND l_write_request='1') then
                    if(rd_addr > "000") then
                        if(RAM(to_integer(unsigned(rd_addr))) = zero_link_value) then
                             report "LRW=10, Read address>000, empty_link=1";
                             empty_link <= '1';
                           elsif(not (RAM(to_integer(unsigned(rd_addr))) = zero_link_value)) then
                             report "LRW=10, Read address>000, empty_link=0";
                             empty_link <= '0';
                             rd_do <= RAM(to_integer(unsigned(rd_addr)));
                             else
                        end if;
                        elsif(rd_addr = "000") then
                            report "LRW=10, Read address=000, empty_link=0";
                            rd_do <= RAM(to_integer(unsigned(rd_addr)));
                            empty_link <= '0';
                        else
                    end if; 
                    RAM(to_integer(unsigned(wr_addr))) <= wr_di;
                    wr_do <= RAM(to_integer(unsigned(wr_addr)));
                elsif(l_read_request='0' AND l_write_request='0') then
                else
                
            end if;
        end if;
    end process;
end beh;


