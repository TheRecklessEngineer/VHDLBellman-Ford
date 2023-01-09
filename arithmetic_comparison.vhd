-- Arithmetic and Comparison unit performs arithmetic on the starting node value and link value
-- Followed by comparison with the terminating node value in order to determine whether
-- an update to the node RAM is requried
-- If an update is requried, a control signal is generated along with data output to be written
-- to the node RAM 
-- The unit implements infinite value check on the head node of the link and also performs inverted 
-- and sequential link error checking

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity arith_comp_confl is
    generic(link_size, node_size, n_addr_size : integer);
    port(
        clk : in std_logic;
        reset : in std_logic;
        latest_nodes : in std_logic_vector(5 downto 0);
        node_di1 : in std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
        node_di2 : in std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
        nodecount_di1 : in std_logic_vector(((n_addr_size+node_size)-1) downto 0); --x
        nodecount_di2 : in std_logic_vector(((n_addr_size+node_size)-1) downto 0); --x
        link_value : in std_logic_vector(link_size-1 downto 0);
        iteration_in: in std_logic_vector(4 downto 0); --xx
        cycle_iteration_in : in std_logic;
        read_address: in std_logic_vector(n_addr_size-1 downto 0); --xx
        req_node_write : out std_logic;
        si_confliction : out std_logic_vector(1 downto 0);
        update_combined_nl : out std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
        skip_link : out std_logic;
        seq_confliction_errors : out std_logic_vector(5 downto 0);
        inv_confliction_errors : out std_logic_vector(5 downto 0);
        infinite_n_errors : out std_logic_vector(5 downto 0);
        node_updates : out std_logic_vector(5 downto 0);
        arith_node_do1 : out std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
        arith_node_do2 : out std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
        arith_link_value : out std_logic_vector(link_size-1 downto 0);
        new_nodes : out std_logic_vector(1 downto 0);
        max_iteration : out std_logic_vector(4 downto 0); --
        disable_lread : out std_logic
    );
end entity arith_comp_confl;

architecture behavioural of arith_comp_confl is
    
    --Registers for the error count
    signal seq_error_count : unsigned(5 downto 0);
    signal inv_error_count : unsigned(5 downto 0);
    signal writes_count : unsigned(5 downto 0);
    signal infinite_node_count : unsigned(5 downto 0);

    --Registers for the previous node1, node2 and link value read relative to the current the node and link reader
    --These values will be used to determine the value of the trailing node and whether a confliction occurs
    signal prev_node_do1 : std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
    signal prev_node_do2 : std_logic_vector(((n_addr_size+node_size)-1) downto 0); --
    signal prev_link_value : std_logic_vector(link_size-1 downto 0);
    
    --Register for hte maximum iteration required by the address and iteration calculator
    signal max_iteration_r : unsigned(4 downto 0);
    signal read_addr_r : std_logic_vector(n_addr_size-1 downto 0);
    
    --Check whether the signed bit of the resultant and 2nd node are either positive or negative
    function np_resultant_check(np_resultant : unsigned(node_size-n_addr_size downto 0);
                                node_data2 : std_logic_vector(((n_addr_size+node_size)-1) downto 0)
             ) return boolean is
    begin
        if(np_resultant(node_size-n_addr_size) = '0' AND node_data2(node_size-n_addr_size) = '0') then
              --Cna be refactored into another function but is not neccesary since the number of lines is minimal
              if(np_resultant(node_size-n_addr_size downto 0) < unsigned(node_data2(node_size-n_addr_size downto 0))) then
                    return true;
                    else
                       return false;
              end if;
            elsif(np_resultant(node_size-n_addr_size) = '0' AND node_data2(node_size-n_addr_size) = '1') then
              return false;
            elsif(np_resultant(node_size-n_addr_size) = '1' AND node_data2(node_size-n_addr_size) = '0') then
              return true;
            elsif(np_resultant(node_size-n_addr_size) = '1' AND node_data2(node_size-n_addr_size) = '1') then
              if(np_resultant(node_size-n_addr_size downto 0) < unsigned(node_data2(node_size-n_addr_size downto 0))) then
                    return true;
                    else
                       return false;
              end if;
            else
                return false;            
        end if;
    end function;
    
        --Function performs the arithemtic function and returns the result
    function calc_nl_result (node_data : std_logic_vector(node_size+n_addr_size-1 downto 0); link_data : std_logic_vector(link_size-1 downto 0))
     return std_logic_vector is
    begin
        --Calculates the value of the first node + the link address
        return std_logic_vector((unsigned((node_data(node_size-n_addr_size downto 0))) + unsigned((link_data(link_size-1-(2*n_addr_size) downto 0)))));
    end function;
    
    --Function performs the arithemtic function and returns true if an update is required
    function nl_bool(node_data1 : std_logic_vector(((n_addr_size+node_size)-1) downto 0); 
                    node_data2 : std_logic_vector(((n_addr_size+node_size)-1) downto 0);
                    link_value : std_logic_vector(link_size-1 downto 0)
    ) return boolean is
        variable np_resultant : unsigned(node_size-n_addr_size downto 0);
        variable pp_resultant : unsigned(node_size-n_addr_size-1 downto 0);

    begin
        --Variables for same and different signed integers of the first node and link
        np_resultant := unsigned(calc_nl_result(node_data1, link_value));
--        (unsigned((node_data1(node_size-n_addr_size downto 0))) + unsigned((link_value(link_size-1-(2*node_size) downto 0))));

        --If node1 and lnik are both positive, MSB is not needed for arithmetic
        --If MSB is used for arithmetic calculation, two positive integers may produce a negative integer
        pp_resultant := (unsigned((node_data1(node_size-n_addr_size-1 downto 0))) + unsigned((link_value(link_size-2-(2*n_addr_size) downto 0))));
        
        --Check whether the 1st node and link are positive integers
        if(((node_data1(node_size-n_addr_size)) = '0') AND (link_value(link_size-1-(2*n_addr_size))='0')) then
                
                --Check the 2nd node whether positive
                if((node_data2(node_size-n_addr_size)) = '0') then
                        
                        --Check whether the 1st node+link value is less than the 2nd node value
                        if(pp_resultant(node_size-n_addr_size-1 downto 0) < unsigned(node_data2(node_size-n_addr_size-1 downto 0))) then
                                return true;
                            else
                                return false;
                        end if;
                    
                    --Check if 2nd node is negative
                    --The product of two positive integers from node 1 and link is always greater than a negative
                    --number, therefore a write is not required and return false
                    elsif((node_data2(node_size-n_addr_size)) = '1') then
                        return false;
                    else
                        return false;
                end if;
                
            --Check whether the 1st node is positive and link is negative
            elsif(((node_data1(node_size-n_addr_size)) = '0') AND (link_value(link_size-1-(2*n_addr_size))='1')) then
                --N1+link < N2 check
                if(np_resultant_check(np_resultant, node_data2)) then
                        return true;
                    else
                        return false;
                end if;
                
            --Check whether the 1st node is negative and link is positive
            elsif(((node_data1(node_size-n_addr_size)) = '1') AND (link_value(link_size-1-(2*n_addr_size))='0')) then
               -- N1+link < N2 check
                if(np_resultant_check(np_resultant, node_data2)) then
                        return true;
                    else
                        return false;
                end if;
                
            --Check whether the 1st node is negative and link is negative
            elsif(((node_data1(node_size-n_addr_size)) = '1') AND (link_value(link_size-1-(2*n_addr_size))='1')) then
                --Check the 2nd node whether positive
                if((node_data2(node_size-n_addr_size)) = '0') then
                    return true;
                    --Check 2nd node is negative
                    elsif((node_data2(node_size-n_addr_size)) = '1') then
                        --Check whether the 1st node+link value is less than the 2nd node value without the signed bits
                        if(pp_resultant(node_size-n_addr_size-1 downto 0) < unsigned(node_data2(node_size-n_addr_size-1 downto 0))) then
                                return true;
                            else
                                return false;
                        end if;
                    else
                        return false;
                end if;
                
            else  
                return false;       
        end if;
    end function;

    begin
    
    --Shows the current nodes and link values in the arithmetic circuit
    arith_node_do1 <= prev_node_do1;
    arith_node_do2 <= prev_node_do2;
    arith_link_value <= prev_link_value;
    
    process(clk, reset, latest_nodes) begin
        if(reset='0') then
            si_confliction <= (others=>'0');
            req_node_write <= '0';
            update_combined_nl <= (others=>'0');
            seq_confliction_errors <= (others=>'0');
            inv_confliction_errors <= (others=>'0');
            infinite_n_errors <= (others=>'0');
            node_updates <= (others=>'0');
            skip_link <= '0';
            max_iteration <= (others=>'0');
            seq_error_count <= (others=>'0');
            inv_error_count <= (others=>'0');
            infinite_node_count <= (others=>'0');
            writes_count <= (others=>'0');
            prev_node_do1 <= (others=>'0');
            prev_node_do2 <= (others=>'0');
            prev_link_value <= (others=>'0');
            max_iteration_r <= (others=>'0');
            new_nodes <= (others=>'0');
            disable_lread <= '0';
        else
            --Performs error detection for sequential and inversion errors of links
            --The reason for concurrent design is because of the delayed signals entering into the circuit
            --Here upon the rising edge from the previous circuit, latest_nodes signal is delayed into the current circuit
            --Therefore the initial output data is incorrect must be re-rendered, this is shown by latest_nodes in the sensitivity list 
            if(rising_edge(clk)) then
                    prev_node_do1 <= node_di1;
                    prev_node_do2 <= node_di2;
                    prev_link_value <= link_value;
                    read_addr_r <= read_address;
                elsif(falling_edge(clk)) then
                                
                                --Determines whether an early stoppage of the algorithm occurs during the negative cycle              
                                --iteration by setting the value of disable_lread
                                if(not(read_address = "000") AND cycle_iteration_in='1') then    
                                            report "read_address>000, cycle_iteration=1";
                                            --Determine whether a write operation is required for the trailing node
                                            if(nl_bool(prev_node_do1, prev_node_do2, prev_link_value)) then
                                                      report "read_address>000 cycle_iter=1, n1+L<n2, disable_lread=1";
                                                      disable_lread <= '1';
                                                  else
                                                      report "read_address>000 cycle_iter=1, n1+L>=n2, disable_lread=0";
                                            end if;
                                        elsif(read_address = "000" AND cycle_iteration_in='1') then
                                            report "Last link enters arithmetic before cycle_iteration, read_address=000 cycle_iter=1, disable_lread=0";
                                            disable_lread <= '0';
                                        else
                                end if;               
                                                               
                                --Performs counting of the nodes of a node reader link and increments the max iteration
                                if(nodecount_di1(node_size-1) = '0' AND nodecount_di2(node_size-1) = '0') then
                                        report "N1=0, N2=0";
                                        new_nodes <= "00";
                                        max_iteration <= std_logic_vector(max_iteration_r);
                                    elsif(nodecount_di1(node_size-1) = '1' AND nodecount_di2(node_size-1) = '0') then
                                        report "N1=1, N2=0";
                                        new_nodes <= "10";
                                        max_iteration_r <= max_iteration_r+1;
                                        max_iteration <= std_logic_vector(max_iteration_r+1);
                                    elsif(nodecount_di1(node_size-1) = '0' AND nodecount_di2(node_size-1) = '1') then
                                        report "N1=0, N2=1";
                                        new_nodes <= "01";
                                        max_iteration_r <= max_iteration_r+1;
                                        max_iteration <= std_logic_vector(max_iteration_r+1);
                                    elsif(nodecount_di1(node_size-1) = '1' AND nodecount_di2(node_size-1) = '1') then
                                        report "N1=1, N2=1";
                                        new_nodes <= "11";
                                        max_iteration_r <= max_iteration_r+2;
                                        max_iteration <= std_logic_vector(max_iteration_r+2);
                                    else
                                end if;                      
                    
                            --In reality self looping links should not occur in the weighted graph, since we cannot produce a smaller value for any node
                            --by computing the positive valued self looping link
                            --If the self looping link is neagtive, then a stable value cannoot be reached
                            --The link can be computed an infinite number of times to reduce the current node value
                            --A self looping link can be found under the conditions where both the head and trailing nodes are equivalent
                            
                            --Calculate the resultant value of the 1st node + link value and output
                            update_combined_nl <= prev_node_do2(node_size+n_addr_size-1 downto node_size) & '0' & '0' & calc_nl_result(prev_node_do1, prev_link_value);
                            
                            --Check whether the 1st node and 2nd node are equivalent 
                            --This occurs just after the global asynchronous reset and any empty links
                            --For example, 3 bits for the link address, only 7 links are used and the last is empty
                            if(not (prev_node_do1(node_size+n_addr_size-1 downto node_size) = prev_node_do2(node_size+n_addr_size-1 downto node_size))) then

                                    --Check for infinity value of the head and trailing to determine whether a write operation 
                                    --is required for the trailing node
                                    case prev_node_do1(node_size-2) is
                                        when '0' =>
                                              --Comparison operation required and link is not skipped
                                              skip_link <= '0';
                                              --Infinity check for node 2 in order to determine whether arithmetic comparison required
                                                case prev_node_do2(node_size-2) is
                                                    when '0' =>
                                                        --Determine whether a write operation is required for the trailing node
                                                        if(nl_bool(prev_node_do1, prev_node_do2, prev_link_value)) then
                                                                report "N1INF=0, N2INF=0, SKIP=0, WN=1";
                                                                req_node_write <= '1';
                                                                writes_count <= writes_count+1;
                                                                node_updates <= std_logic_vector(writes_count+1);
                                                            else
                                                                report "N1INF=0, N2INF=0, SKIP=0, WN=0";
                                                                req_node_write <= '0';
                                                        end if;      
                                                    when '1' =>
                                                        report "N1INF=0, N2INF=1, SKIP=0, WN=1";
                                                        --Write operation required without comparison when 2nd node is infinite
                                                        --Increment the count for infinity for 2nd node
                                                        req_node_write <= '1';
                                                        writes_count <= writes_count+1;
                                                        node_updates <= std_logic_vector(writes_count+1);
                                                        infinite_node_count <= infinite_node_count+1;
                                                        infinite_n_errors <= std_logic_vector(infinite_node_count+1);
                                                    when others =>
                                              end case;
                                            when '1' =>
                                            --Comparison not required since 1st node is infinite and link is skipped
                                            --No increment for infinity node, since we do not write the 1st node back into memory
                                            --Otherwise a duplicate error count occurs
                                            report "N1INF=1, N2INF=X, SKIP=1, WN=0";
                                            skip_link <= '1';
                                            req_node_write <= '0';
                                            when others =>
                                    end case;
                                
                                    --Determines whether a confliction occurs between the node reader link and the arithmetic link 
                                    --Link and node reader values
                                    if(prev_node_do2(node_size+n_addr_size-1 downto node_size) = latest_nodes((2*n_addr_size)-1 downto n_addr_size)) then
                                            report "Sequential error triggered, SI=10";
                                            si_confliction <= "10";
                                            
                                            --Condition required for counting confliction error until the last link entering the arithmetic circuit
                                            if(iteration_in="00001") then
                                                seq_error_count<=seq_error_count+1;
                                                seq_confliction_errors <= std_logic_vector(seq_error_count+1);
                                                elsif((iteration_in="00010" AND read_address="111") OR (iteration_in="00010" AND read_address="000")) then
                                                        seq_error_count<=seq_error_count+1;
                                                        seq_confliction_errors <= std_logic_vector(seq_error_count+1);
                                                else
                                            end if;
                                        elsif(prev_node_do2(node_size+n_addr_size-1 downto node_size) = latest_nodes(n_addr_size-1 downto 0)) then
                                            report "Inversion error triggered, SI=01";
                                            si_confliction <= "01";
                                            
                                            --Condition required for counting confliction error until the last link entering the arithmetic circuit
                                            if(iteration_in="00001") then
                                                inv_error_count<=inv_error_count+1;
                                                inv_confliction_errors <= std_logic_vector(inv_error_count+1);
                                                elsif((iteration_in="00010" AND read_address="111") OR (iteration_in="00010" AND read_address="000")) then
                                                        inv_error_count<=inv_error_count+1;
                                                        inv_confliction_errors <= std_logic_vector(inv_error_count+1);
                                                else
                                            end if;      
                                        else
                                            report "No confliction error detected, , SI=00";
                                            si_confliction <= "00";
                                            
                                    end if;
                                else
                            end if;
                end if;               
            end if; 
    end process;
end architecture behavioural;





