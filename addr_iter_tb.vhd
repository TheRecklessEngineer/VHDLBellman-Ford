library IEEE;
library work;
use IEEE.STD_LOGIC_1164.ALL;

entity addr_iter_tb is
end addr_iter_tb;

architecture Behavioral of addr_iter_tb is
    
        --Clocking signals
        signal clk_tb : std_logic:='0';
        constant time_period : time:= 1 ns;
        
        --Generic values for generic variables in link RAM, Node RAM and operations on link within Arithmetic
        --Define the intiial data structure and the bellmand ford algorithm operation
        
        --Configuration parameters documentation--
        --n_addr_size may need adjusting for the node_reader module if the num_nodes are to increase or decrease
        --e.g if num_nodes increase to 10, link_size increase by 2 on the address of nodes, n_addr_size increases by 1
        --Since the bit range selection of the link is dependent on n_addr_size, an offset on n_addr_size may be required
        --e.g n_addr_size-1 where n_addr_size is the latest adjusted value
        --A new constant should be created and apply an offset to the new constant adjusted for increases/decrease of num_nodes
        --then passed into node_reader
        --n_addr_size can be passed in directly to the arithmetic module, after adjusting for increase/decrease in num_nodes
        --Only the integer values of the node including the signed bit should be changed in quantity e.g previosuly 5 bits including singed bit
        -- -> 6 bits
        --The control data on the node should not be changed in quantity ut can beb changed in value 
        --e.g changing 9th bit representative of whether a node is infinity or not
        constant link_size : integer:=14;--Changing this value requires changing link RAM data size
        constant node_size : integer:=10;--Changing this value requires changing node RAM data size
        constant num_nodes : integer:=5; --Changing this value requires changing node RAM, number of nodes, (others=>'0') may be required
        constant n_addr_size : integer:=3; --2^(addr_size) should be >= num_nodes
        constant l_addr_size : integer:=3; --2^(addr_size) should be >= num_links
        
        --Address and Iteration
        signal reset: std_logic:='1'; --Active low reset
        signal enable: std_logic:='1'; --By default enabled
        signal cycle_iteration_out: std_logic;
        signal disable_lread : std_logic;
        signal bm_completed: std_logic;
        signal iter_nwrite_count_out: std_logic_vector(4 downto 0);
        signal read_address: std_logic_vector(2 downto 0);
        signal address_connector: std_logic_vector(2 downto 0);
        signal iteration_connector: std_logic_vector(4 downto 0);
        
        --Link reader initialize write in data, used for streaming, currently not implemented
        signal di_initialize : std_logic_vector(13 downto 0):= "00000000000000";

        --Node reader connectors
        signal manual_readn : std_logic_vector(2 downto 0);
        signal manual_node_do : std_logic_vector(9 downto 0);
        signal nodeReader_nodeValueOnly1 : std_logic_vector(9 downto 0); ---x
        signal nodeReader_nodeValueOnly2 : std_logic_vector(9 downto 0); ---x
        signal wlink_d_connector : std_logic_vector(13 downto 0);
        signal rlink_d_connector : std_logic_vector(13 downto 0);
        signal nodeReader_nodecountDirect1 : std_logic_vector(12 downto 0);
        signal nodeReader_nodecountDirect2 : std_logic_vector(12 downto 0);
        signal nodeReader_nodeInterface1 : std_logic_vector(12 downto 0);
        signal nodeReader_nodeInterface2 :  std_logic_vector(12 downto 0);
        signal nodeReader_latestNodes : std_logic_vector(5 downto 0);
        
        --Arithmetic connectors
        signal arith_node_do1 : std_logic_vector(12 downto 0);
        signal arith_link_value : std_logic_vector(13 downto 0);
        signal arith_node_do2 : std_logic_vector(12 downto 0);
        signal nl_result_conn : std_logic_vector(12 downto 0);
        signal si_conf_connector : std_logic_vector(1 downto 0);
        signal read_req_connector : std_logic;
        signal write_req_connector : std_logic;
        signal sconf_err_connector : std_logic_vector(5 downto 0);
        signal iconf_err_connector : std_logic_vector(5 downto 0);
        signal nr_req_connector : std_logic;
        signal nw_req_connector : std_logic;
        signal node_wcount_connector : std_logic_vector(5 downto 0);
        signal inf_n_count_conn : std_logic_vector(5 downto 0);
        signal skip_link_conn : std_logic;
        signal max_iteration_arith: std_logic_vector(4 downto 0);
        signal new_nodes : std_logic_vector(1 downto 0);
        signal empty_link : std_logic;

begin

    addr_iter_instance : entity work.addr_iter 
    generic map(addr_size=>l_addr_size)
    port map (
        clk=>clk_tb, 
        reset=>reset, 
        enable=>enable, 
        previous_address=>address_connector,
        arith_max_iteration=>max_iteration_arith,
        iteration_in=>iteration_connector,
        cycle_iteration_out=>cycle_iteration_out, 
        bm_completed=>bm_completed, 
        read_address=>read_address, 
        current_address=>address_connector,
        iteration_out=>iteration_connector, 
        request_read=>read_req_connector,
        disable_lread=>disable_lread,
        empty_link=>empty_link,
        mpa_nwrite=>nw_req_connector,
        iter_nwrite_count_out=>iter_nwrite_count_out
    );
    
    --When initial streaming of data into link RAM is performed, clock of the link reader should be the divided clock from a base clock                      
    --Here we test the link reader in the abscence of the streaming interface circuit
    
    link_reader_instance : entity work.link_reader 
    generic map(link_size=>link_size, addr_size=>l_addr_size)
    port map(
        clk=>clk_tb, 
        reset=>reset, 
        l_read_request=>read_req_connector, 
        l_write_request=>write_req_connector,
        rd_addr=>read_address, 
        wr_addr=>read_address, 
        wr_di=>di_initialize, 
        rd_do=>rlink_d_connector, 
        wr_do=>wlink_d_connector,
        n_read_request=>nr_req_connector,
        empty_link=>empty_link
    );

    node_reader_instance : entity work.node_reader 
    generic map(link_size=>link_size, node_size=>node_size, n_addr_size=>n_addr_size, num_nodes=>num_nodes)
    port map(
        clk=>clk_tb, 
        reset=>reset, 
        rn_request=>nr_req_connector, 
        wn_request=>nw_req_connector,
        link_data_in=>rlink_d_connector, 
        wr_data_in=>nl_result_conn, 
        si_confliction=>si_conf_connector,
        node_do1=>nodeReader_nodeInterface1, 
        node_do2=>nodeReader_nodeInterface2, 
        nodecount_do1=>nodeReader_nodecountDirect1,
        nodecount_do2=>nodeReader_nodecountDirect2, 
        manual_readn=>manual_readn, 
        manual_node_do=>manual_node_do,
        latest_nodes=>nodeReader_latestNodes,
        latest_node_do1=>nodeReader_nodeValueOnly1,
        latest_node_do2=>nodeReader_nodeValueOnly2,
        max_iteration=>max_iteration_arith,
        new_nodes=>new_nodes
    );
    
    Arith_comp_instance : entity work.arith_comp_confl 
    generic map(link_size=>link_size, node_size=>node_size, n_addr_size=>n_addr_size)
    port map(
        clk=>clk_tb,
        reset=>reset,
        node_di1=>nodeReader_nodeInterface1,
        node_di2=>nodeReader_nodeInterface2,
        si_confliction=>si_conf_connector,
        link_value=>rlink_d_connector,
        req_node_write=>nw_req_connector,
        latest_nodes=>nodeReader_latestNodes,
        update_combined_nl=>nl_result_conn,
        seq_confliction_errors=>sconf_err_connector,
        inv_confliction_errors=>iconf_err_connector,
        iteration_in=>iteration_connector,
        cycle_iteration_in=>cycle_iteration_out,
        read_address=>read_address,
        infinite_n_errors=>inf_n_count_conn,
        node_updates=>node_wcount_connector,
        skip_link=>skip_link_conn,
        arith_node_do1=>arith_node_do1,
        arith_node_do2=>arith_node_do2,
        nodecount_di1=>nodeReader_nodecountDirect1,
        nodecount_di2=>nodeReader_nodecountDirect2, 
        arith_link_value=>arith_link_value,
        new_nodes=>new_nodes,
        max_iteration=>max_iteration_arith,
        disable_lread=>disable_lread
    );
    
    clocking_process : process begin
        wait for time_period;
        clk_tb <= not clk_tb;
    end process;
    
    stimulus_process : process begin
        wait for 5 ns;
        reset <= '0';
        wait for 0.2 ns;
        write_req_connector<='0';
        reset <= '1';
        enable <= '1';
        manual_readn <= "001"; --Signal used to test read any node 
        wait;
    end process;
end Behavioral;
