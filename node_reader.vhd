-- Dual port node RAM holds the ndoe values for the Bellman Ford graph
-- RAM contains true node values

    --The maximum positive value of the link is 32, however after addition the values
    --can be considerably larger
    --The weighted grpah instance does not contain negative values, although our logic should
    --be able to handle both unsigned and signed integers
    --There is no particular algorithm for calculating the largest value of a node in
    --the weighted graph without execution of the algorithm itself
    --Although we can choose a reaosnable estimation by considering the number of digits of
    --the largest number and increasing by 1. In this case if 32 is the largest, we should be 
    --able to represent atleast 100. 
    --In order to handle both unsigned and signed integer, we require an additional signed bit
    --with the signed bit, we also decrease the range of positive numbers
    --For example, using 7 bits, we can represent positive numbers from 0-127, if 7 includes
    --then signed bit, our range decreases to -64-63
    --Initially we needed to represent atleast 100, therefore we use 8 bits to cover both
    --signed and unsigned reange of integers
    --The final range of representable numbers are from -128-127 which is sufficient for our
    --weighted graph
    
    --Measurements for the maximum ndoe value
    --A measurement which gaurantees enough bits are used is to consider multiplying the 
    --number of links by the maximum link value
    --The maximum value is acheived when all links are sequential, however this is unlikely
    --and therefore all node values are certain to be less than this value
    
    --Initial infinity conditions
    --In additon to representing the largest possible node value, we must also represent the
    --appearance of infinity for the initial conditions
    --We accomplish this by using an extra bit to indicate infinity, in total 9 bits are used

    -- Node reader will also perform node address extraction from the received links
    --for both reading and writing of the node RAM
    --Read the node values and then output node values along with link value for the arithmetic stage

library ieee;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity node_reader is
generic(link_size, node_size, n_addr_size, num_nodes : integer);
port (
        clk : in std_logic;
        reset: in std_logic:='1'; --active low reset asynchronous
        rn_request : in std_logic;
        wn_request : in std_logic;
        manual_readn : in std_logic_vector((n_addr_size-1) downto 0);
        si_confliction : in std_logic_vector(1 downto 0);
        link_data_in : in std_logic_vector(link_size-1 downto 0); --x
        wr_data_in : in std_logic_vector((n_addr_size+node_size)-1 downto 0); --x
        new_nodes : in std_logic_vector(1 downto 0); --
        max_iteration : in std_logic_vector(4 downto 0);
        node_do1 : out std_logic_vector(((n_addr_size+node_size)-1) downto 0); --x
        node_do2 : out std_logic_vector(((n_addr_size+node_size)-1) downto 0); --x
        latest_nodes : out std_logic_vector(((n_addr_size*2)-1) downto 0);
        manual_node_do : out std_logic_vector((node_size-1) downto 0);
        latest_node_do1 : out std_logic_vector((node_size-1) downto 0); ---x
        latest_node_do2 : out std_logic_vector((node_size-1) downto 0); ---x
        nodecount_do1 : out std_logic_vector(((n_addr_size+node_size)-1) downto 0); --x
        nodecount_do2 : out std_logic_vector(((n_addr_size+node_size)-1) downto 0) --x
    );
end node_reader;

architecture beh of node_reader is

    --Initialize the 5 node values in the RAM
    type ram_type is array (0 to (num_nodes-1)) of std_logic_vector((node_size-1) downto 0);
    signal RAM : ram_type:= ("1000000000", others => "1100000000");

begin
    
    --Transfers nodes into arithmetic on receiving new link data for calculation of new nodes
    process (reset, link_data_in) begin
        if(reset='0') then
            nodecount_do1 <= (others=>'0');
            nodecount_do2 <= (others=>'0');
            latest_nodes <= (others=>'0');
        else
            nodecount_do1 <= link_data_in((link_size-1) downto (link_size-n_addr_size)) & RAM(to_integer(unsigned(link_data_in((link_size-1) downto (link_size-n_addr_size)))));
            nodecount_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))));
            latest_nodes <= link_data_in(link_size-1 downto link_size-n_addr_size) & link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)));
            
            --For testing purposes
            manual_node_do <= RAM(to_integer(unsigned(manual_readn(n_addr_size-1 downto 0))));
            latest_node_do1 <= RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))));
            latest_node_do2 <= RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))));
        end if;
    end process;

    --Max iteration in sensitivity list is just used to re-run the process at the falling edge just after global reset
    -- rn_request, wn_request, si_confliction,
    process (reset, rn_request, wn_request, si_confliction, wr_data_in, max_iteration) begin
        if(reset='0') then
            node_do1 <= (others=>'0');
            node_do2 <= (others=>'0');
        else
            if(rn_request = '1' AND wn_request='1') then
            report "Reading and writing node operation";
                    --Write the 2nd node of the arithmetic link into node RAM
                    RAM(to_integer(unsigned(wr_data_in((n_addr_size+node_size)-1 downto node_size)))) <= wr_data_in((node_size-1) downto 0);
                    case si_confliction is
                                when "00" =>
                                    --When no confliction error is present, determine whether either 1st or 2nd node has been read previously
                                    case new_nodes is
                                        when "00" =>
                                            report "RW=11, SI=00, NN=00";
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0);   
                                        when "01" =>
                                            report "RW=11, SI=00, NN=01";
                                            RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)))))) <= '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0); 
                                        when "10" =>
                                            report "RW=11, SI=00, NN=10";
                                            RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size)))) <= '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0);
                                        when "11" =>
                                            report "RW=11, SI=00, NN=11";
                                            RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size)))) <= '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)))))) <= '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0);
                                        when others =>
                                    end case;      
                                when "10" =>
                                    --Since 2nd node from arithmetic has already been written to memory, replace the 1st node of the node reader link
                                    --with updated value for 2nd node from arithmetic
                                    node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & wr_data_in((node_size-1) downto 0);
                                    
                                    --When a sequential error is present, determine whether the 2nd node has been read previously and therefore
                                    --replace the node to reflect previously read status
                                    case new_nodes is
                                        when "00" =>
                                            report "RW=11, SI=10, NN=00";
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0); 
                                        when "01" =>
                                            report "RW=11, SI=10, NN=01";
                                            RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)))))) <= '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0); 
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0); 
                                        when others =>
                                    end case;    
                                when "01" =>              
                                    --Replace 2nd node of node reader link with updated data from arithmetic
                                    node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & wr_data_in((node_size-1) downto 0);
                                    --When an inversion error is present, determine whether the 1st node has been read previously
                                    case new_nodes is
                                        when "00" =>
                                            report "RW=11, SI=01, NN=00";
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0); 
                                        when "10" =>
                                            report "RW=11, SI=01, NN=10";
                                            RAM(to_integer(unsigned(link_data_in(link_size-1  downto link_size-n_addr_size )))) <= '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0); 
                                        when others =>
                                    end case;    
                                when others =>
                                --A case of both inversion and sequential erros should not occur
                       end case;
               elsif(rn_request = '1' AND wn_request='0') then
               report "Reading node operation, no writing";
               case si_confliction is
                                when "00" =>
                                    --When nonconfliction error is present, determine whether either 1st or 2nd node has been read previously
                                    case new_nodes is
                                        when "00" =>
                                            report "RW=10, SI=00, NN=00";
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0);
                                        when "01" =>
                                            report "RW=10, SI=00, NN=01";
                                            RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)))))) <= '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0); 
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0); 
                                        when "10" =>
                                            report "RW=10, SI=00, NN=10";
                                            RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size)))) <= '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0);
                                        when "11" =>
                                            report "RW=10, SI=00, NN=11";
                                            RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size)))) <= '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)))))) <= '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0);
                                        when others =>
                                    end case;    
                                when "10" =>
                                    --When a sequential error is present, determine whether the 2nd node has been read previously
                                    case new_nodes is
                                        when "00" =>
                                            report "RW=10, SI=10, NN=00";
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0);   
                                        when "01" =>
                                            report "RW=10, SI=10, NN=01";
                                            RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2)))))) <= '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & '0' & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(8 downto 0); 
                                        when others =>
                                    end case;    
                                when "01" =>
                                    --When an inversion error is present, determine whether the 1st node has been read previously
                                    case new_nodes is
                                        when "00" =>
                                            report "RW=10, SI=01, NN=00";
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(9 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) & RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0);   
                                        when "10" =>
                                            report "RW=10, SI=01, NN=10";
                                            RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size)))) <= '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do1 <= link_data_in(link_size-1 downto link_size-n_addr_size) & '0' & RAM(to_integer(unsigned(link_data_in(link_size-1 downto link_size-n_addr_size))))(8 downto 0);
                                            node_do2 <= link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))) &  RAM(to_integer(unsigned(link_data_in((link_size-n_addr_size-1) downto (link_size-(n_addr_size*2))))))(9 downto 0); 
                                        when others =>
                                    end case;    
                                when others =>
                                --A case of both inversion and sequential erros should not occur
                       end case;
               --Algorithm execution stop condition, can be used for streaming links and node into RAM before the circuit begins execution
               else
               report "No reading or writing node operations OR Writing node operation, no reading";
            end if;
        end if;
    end process;
end beh;



