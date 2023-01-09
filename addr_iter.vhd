library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Address and iteration calculation circuit
--5 btis are used to represent the max iteration and a maximum graph
--of 33 nodes is possible, because the max iteration is totoal_nodes - 1
--Address is held in this unit and is reset upon ana ctive low reset

--Testing history
--completed single unit test, no faults


entity addr_iter is
    generic(addr_size : integer);
    Port (
        clk: in std_logic;
        reset: in std_logic:='1'; --Active low reset
        enable: in std_logic:='1'; --By default enabled
        mpa_nwrite: in std_logic;
        empty_link : in std_logic;
        disable_lread : in std_logic;
        previous_address: in std_logic_vector((addr_size-1) downto 0);
        arith_max_iteration: in std_logic_vector(4 downto 0); --x
        iteration_in: in std_logic_vector(4 downto 0);
        cycle_iteration_out: out std_logic;
        bm_completed: out std_logic;
        read_address: out std_logic_vector((addr_size-1) downto 0);
        current_address: out std_logic_vector((addr_size-1) downto 0);
        iteration_out: out std_logic_vector(4 downto 0);
        iter_nwrite_count_out: out std_logic_vector(4 downto 0);
        request_read: out std_logic
        );
end entity;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                

architecture Behavioral of addr_iter is
    --Address reg will be used to store the intermediate claculation of addresses
    signal address_reg : unsigned((addr_size-1) downto 0):=(others=>'0');
    signal iteration_reg : unsigned(4 downto 0):=(others=>'0');
    signal end_of_addr : std_logic:='0';
    signal wcount_reset_addr : unsigned(addr_size-1 downto 0):=(others=>'0');
    
    --Alternatively, this value can be set to the maximum number of links
    --Found by (number of nodes-1)x(number ofnodes) e.g 4N graph will have a maximum of 3x4 links
    signal iter_nwrite_count : unsigned(4 downto 0);
    
    --Performs calculation of the next address and iteration
    procedure addr_iter_calc(
    signal end_of_addr: inout std_logic;
    signal p_addr : in std_logic_vector((addr_size-1) downto 0); 
    signal addr_reg: inout unsigned((addr_size-1) downto 0);
    signal iter_reg : inout unsigned(4 downto 0); 
    signal curr_addr: out std_logic_vector((addr_size-1) downto 0); 
    signal curr_iter: out std_logic_vector(4 downto 0); 
    signal r_addr : out std_logic_vector((addr_size-1) downto 0)) is
        begin
        --Incrementation address and iteration
        if(unsigned(p_addr)+2 = "000") then
            report "Current address add 2 = 000, increment addr_reg, current_addr and iteration_reg";
            addr_reg <= addr_reg+1;
            curr_addr <= std_logic_vector(addr_reg+1);
            r_addr <= std_logic_vector(addr_reg+1);
            iter_reg <= iter_reg+1;
            curr_iter <= std_logic_vector(iter_reg+1);
            end_of_addr <= '1';
            else
                --Address less than or greater than prev_address+2=000 in different iterations
                report "Current address add 2 != 000, increment addr_reg and current_addr";
                addr_reg <= addr_reg+1;
                r_addr <= std_logic_vector(addr_reg+1);
                curr_addr<= std_logic_vector(addr_reg+1);
                end_of_addr <= '0';
        end if;                  
    end procedure addr_iter_calc;
    
    --Performs checking of the total node count for a single iteration and thereafter stops the 
    --circuit calculation if the graph stabilizes
    procedure iter_count_check(
        signal iter_nwrite_count : inout unsigned(4 downto 0);
        signal iter_nwrite_count_out : out std_logic_vector(4 downto 0);
        signal bm_completed : out std_logic;
        --Addr_iter_calc procedure signals
        signal end_of_addr : inout std_logic;
        signal previous_address : in std_logic_vector((addr_size-1) downto 0);
        signal address_reg : inout unsigned((addr_size-1) downto 0);
        signal iteration_reg : inout unsigned(4 downto 0); 
        signal current_address : out std_logic_vector((addr_size-1) downto 0); 
        signal iteration_out : out std_logic_vector(4 downto 0);
        signal read_address : out std_logic_vector((addr_size-1) downto 0)
    ) is
    begin
        if(iter_nwrite_count > 0) then
               report "n_write_count>0";
               addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
               iteration_out, read_address);
               iter_nwrite_count <= (others=>'0');
               iter_nwrite_count_out <= (others=>'0');             
           elsif(iter_nwrite_count = 0 AND mpa_nwrite='0') then
               report "n_write_count>0, mpa_nwrite=0, graph stabilized, bm_completed=1";
               iter_nwrite_count <= (others=>'0');
               iter_nwrite_count_out <= (others=>'0');   
               read_address <= std_logic_vector(address_reg);
               bm_completed <= '1';
           elsif(iter_nwrite_count = 0 AND mpa_nwrite='1') then
               report "n_write_count>0, mpa_nwrite=1";
               addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
               iteration_out, read_address);
               iter_nwrite_count <= (others=>'0');
               iter_nwrite_count_out <= (others=>'0');    
           else
        end if;
    end procedure;
    
begin

    addr_iter_instance: process(clk, reset) is begin
        if(reset='0') then
            report "Address and Iteration unit reset, initalizing setup conditions";
            --Registers
            address_reg <= (others=>'0');
            iteration_reg <= "00001";
            end_of_addr <= '0';
            --Output signals
            read_address <= (others=>'0');
            current_address <= (others=>'0');
            iteration_out <= "00001";
            cycle_iteration_out <= '0';
            bm_completed <= '0';
            request_read <= '1'; --Request for link value reasding at reset initialization to avoid a clock cycle delay at link reader
            --Node write counts
            iter_nwrite_count <= (others=>'0');
            iter_nwrite_count_out <= (others=>'0');
            --Calculate the base address reset for write node count
            wcount_reset_addr <= wcount_reset_addr+1;
         else
            if(rising_edge(clk)) then
                
                    --Detection of graph stabilisation in order to improve the efficiency of the algorithm
                    --For example, 5N graph requires 5 iterations to completion, but if the graph node values do not change
                    --past the 2nd iteration, the graph has stabilised its node values
                    --Returning the graph at this stage removes the final graph output delay at the 5th iteration
                    
                    --Check whether a stop read signal generated from the arithmetic circuit is active
                    --As a result of the 2nd node of the arithmetic needing replacement
                    --Check whether the current iteration is <> or = max iteration calculate from arithmetic circuit
                    if(enable='1' AND disable_lread='0') then
                            if(iteration_in < arith_max_iteration) then
                                    --Identify read and iterationn conditions for end of iteration of the algorithm
                                    --Since iteration is incremented early we check for iteration+1 and previous_address+1=001 such that
                                    --These are the conditions for the final address(e.g 111) of the previous iteration entering into
                                    --The arithmetic unit for computation 
                                    --For example, this occurs at wcount_reset_address=001 for a 3bit link address
                                    if(iteration_in="00001") then
                                            report "Iteration 1, 000 =< read_address =< 111";
                                            addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                             iteration_out, read_address);
                                       elsif(iteration_in="00010" AND (unsigned(previous_address)+1)="000") then
                                            --Link just before last enters into arithmetic of iteration one
                                            report "Iteration 2, read address 000";
                                            addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                              iteration_out, read_address); 
                                       elsif(iteration_in="00010" AND (unsigned(previous_address)+1)=wcount_reset_addr) then
                                            --Last link enters into arithmetic of iteration one
                                            report "Iteration 2, read address 001";
                                            addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                              iteration_out, read_address);
                                            iter_nwrite_count <= (others=>'0');
                                            iter_nwrite_count_out <= (others=>'0');
                                       elsif(iteration_in>"00010" AND (unsigned(previous_address)+1)="000") then
                                            report "Iteration > 2, read address 000";
                                            iter_count_check(
                                            iter_nwrite_count, iter_nwrite_count_out, bm_completed,
                                            end_of_addr, previous_address, address_reg, iteration_reg,
                                            current_address, iteration_out, read_address
                                            );  
                                       elsif(iteration_in>"00010" AND (unsigned(previous_address)+1)=wcount_reset_addr) then
                                           --Last link entering into arithmetic for iterations >= 2
                                           --Stabilisation of the graph can be checked for on or after 2nd iteration up until
                                           --cycle iteration but not including cycle iteration
                                           --Check for total node write count at the last link entering into arithmetic
                                           iter_count_check(
                                            iter_nwrite_count, iter_nwrite_count_out, bm_completed,
                                            end_of_addr, previous_address, address_reg, iteration_reg,
                                            current_address, iteration_out, read_address
                                            ); 
                                       else
                                           --All iteration either 2 or greater and do not match the reset conditions
                                           --e.g addresses 000 and 001
                                           if(iteration_in="00010") then
                                                    report "Iteration 2, 001 < read_address =< 111";
                                                    if(mpa_nwrite='1') then
                                                          iter_nwrite_count <= iter_nwrite_count+1;
                                                          iter_nwrite_count_out <= std_logic_vector(iter_nwrite_count+1);
                                                          addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                                             iteration_out, read_address); 
                                                       elsif(mpa_nwrite='0') then
                                                          addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                                             iteration_out, read_address); 
                                                       else
                                                    end if;
                                                else
                                                    --Iterations > 2
                                                    --Links of iteration > 2 entering into arithmetic
                                                    report "Iteration > 2, 001 < read_address =< 111";
                                                    if(mpa_nwrite='1') then
                                                        iter_nwrite_count <= iter_nwrite_count+1;
                                                        iter_nwrite_count_out <= std_logic_vector(iter_nwrite_count+1);
                                                        addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                                           iteration_out, read_address); 
                                                       elsif(mpa_nwrite='0') then
                                                          addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                                            iteration_out, read_address); 
                                                       else
                                                    end if;
                                           end if;
                                    end if;
                               elsif(iteration_in = arith_max_iteration) then
                                   if((unsigned(previous_address)+1)="000") then
                                           --Iteration just before cycle iteration
                                           report "Cycle Iteration-1, read address 000";
                                           iter_count_check(
                                            iter_nwrite_count, iter_nwrite_count_out, bm_completed,
                                            end_of_addr, previous_address, address_reg, iteration_reg,
                                            current_address, iteration_out, read_address
                                            ); 
                                        elsif((unsigned(previous_address)+1)=wcount_reset_addr) then
                                           --Iteration just before cycle iteration
                                           report "Cycle Iteration-1, read address 001";
                                           iter_count_check(
                                            iter_nwrite_count, iter_nwrite_count_out, bm_completed,
                                            end_of_addr, previous_address, address_reg, iteration_reg,
                                            current_address, iteration_out, read_address
                                            ); 
                                        else
                                           cycle_iteration_out <= '1';
                                           addr_iter_calc(end_of_addr, previous_address, address_reg, iteration_reg, current_address, 
                                               iteration_out, read_address);
                                   end if;
                               elsif(iteration_in > arith_max_iteration) then
                                   report "Iteration > Max iteration";
                                   if((unsigned(previous_address)+1)="000") then
                                           --Cycle iteration just before > max iteration
                                           report "Cycle Iteration, read address 000";
                                           iter_count_check(
                                            iter_nwrite_count, iter_nwrite_count_out, bm_completed,
                                            end_of_addr, previous_address, address_reg, iteration_reg,
                                            current_address, iteration_out, read_address
                                            ); 
                                        elsif((unsigned(previous_address)+1)=wcount_reset_addr) then
                                           --Cycle iteration just before > max iteration
                                           report "Cycle Iteration, read address 001";
                                           iter_count_check(
                                            iter_nwrite_count, iter_nwrite_count_out, bm_completed,
                                            end_of_addr, previous_address, address_reg, iteration_reg,
                                            current_address, iteration_out, read_address
                                            ); 
                                        else
                                            report "Bellman ford completed initeration>max_iteration, stopping calculation of iteration and addresses";
                                            read_address <= std_logic_vector(address_reg);
                                            bm_completed <= '1';
                                   end if;
                               else
                            end if;  
                        elsif(enable='1' AND disable_lread='1') then
                            report "Bellman ford completed in negeative cycle iteration, stopping calculation of iteration and addresses";
                            read_address <= std_logic_vector(address_reg);
                            bm_completed <= '1';
                        else
                            --If enable='0', perform no actions
                    end if;
                elsif(falling_edge(clk)) then                
                --On the falling edge check whether an empty link is received by the link reader
                --Perform reset of address reg and address output
                --Increment the iteration register
                                        
                    if(enable='1' AND empty_link='0') then
                        --If link received by the link reader is not empty, do not reset address registers
                        --Address read by the address and iteration calculator is the correct address
                        elsif(enable='1' AND empty_link='1') then
                        --Determine whether previous address incremented the iteration, therefore an incrementation
                        --As a result of the empty link is not required
                            if(end_of_addr='1') then
                                    address_reg <= (others=>'0');
                                    read_address <= (others=>'0');
                                    current_address <= (others=>'0');
                                elsif(end_of_addr='0') then
                                    report "end_of_addr=0, empty_link=1, reset read address and increment iteration";
                                    iteration_reg <= iteration_reg+1;
                                    iteration_out <= std_logic_vector(iteration_reg+1);
                                    address_reg <= (others=>'0');
                                    read_address <= (others=>'0');
                                    current_address <= (others=>'0');
                                else
                            end if;
                        else
                            --enable=0
                    end if; 
                                               
            end if;
        end if;
    end process;
end Behavioral;
