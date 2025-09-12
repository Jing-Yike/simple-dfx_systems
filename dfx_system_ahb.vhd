----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/26/2025 12:03:40 AM
-- Design Name: 
-- Module Name: dfx_system - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.misc.all;
use gaisler.axi.all;
library UNISIM;
use UNISIM.VComponents.all;

entity dfx_system_ahb is
generic (
    hsindex                         : integer := 0;
    hmindex                         : integer := 0;
    memtech                         : integer := 0;
    wordsize                        : integer := AHBDW;
    haddr                           : integer := 0;
    hmask                           : integer := 16#f00#;
    ahbendian                       : integer := AHBENDIAN
    );
  Port ( 
  
--system
    clk                             : in    std_logic;
    rstn                            : in    std_logic;
    
--HW triggers
    vsm_vs_shift_hw_triggers        : in    std_logic_vector(1 downto 0);
    vsm_vs_count_hw_triggers        : in    std_logic_vector(1 downto 0);
       
--Master ports to AHB
    ahbmo                           : out   ahb_mst_out_type;
    ahbmi                           : in    ahb_mst_in_type;
    
--Slave ports to AHB
    ahbso                           : out   ahb_slv_out_type;
    ahbsi                           : in    ahb_slv_in_type;
    
--led
    count_out                       : out   std_logic_vector(3 downto 0);
    shift_out                       : out   std_logic_vector(3 downto 0)   
  );
end dfx_system_ahb;

architecture rtl of dfx_system_ahb is

-- AHB2AXI4 Bridge Signals
    signal aximi                        : axi_somi_type;
    signal aximo                        : axi4_mosi_type;
    signal ahbsi_bridge                 : ahb_slv_in_type;
    signal ahbso_bridge                 : ahb_slv_out_type;
    
-- AXI2AHB Bridge Signals
    signal axisi                        : axi4_mosi_type;
    signal axiso                        : axi_somi_type;
    signal ahbmi_bridge                 : ahb_mst_in_type;
    signal ahbmo_bridge                 : ahb_mst_out_type;

    signal s_axi_awlock                 : std_logic_vector (0 downto 0);
    signal s_axi_arlock                 : std_logic_vector (0 downto 0);
    signal s_axi_arregion_UNCONNECTED   : STD_LOGIC_VECTOR ( 3 downto 0 );
    signal s_axi_awregion_UNCONNECTED   : STD_LOGIC_VECTOR ( 3 downto 0 );

-- AXI4 signals between Protocol Converter and dfx system
    signal converter_to_dfx_awaddr      : std_logic_vector(31 downto 0);
    signal converter_to_dfx_awvalid     : std_logic;
    signal converter_to_dfx_awready     : std_logic;
    signal converter_to_dfx_wdata       : std_logic_vector(31 downto 0);
    signal converter_to_dfx_wvalid      : std_logic;
    signal converter_to_dfx_wready      : std_logic;
    signal converter_to_dfx_bresp       : std_logic_vector(1 downto 0);
    signal converter_to_dfx_bvalid      : std_logic;
    signal converter_to_dfx_bready      : std_logic;
    signal converter_to_dfx_araddr      : std_logic_vector(31 downto 0);
    signal converter_to_dfx_arvalid     : std_logic;
    signal converter_to_dfx_arready     : std_logic;
    signal converter_to_dfx_rdata       : std_logic_vector(31 downto 0);
    signal converter_to_dfx_rresp       : std_logic_vector(1 downto 0);
    signal converter_to_dfx_rvalid      : std_logic;
    signal converter_to_dfx_rready      : std_logic;

--DFXC signals
    signal vsm_vs_shift_rm_shutdown_ack :   std_logic       := '1';
    signal vsm_vs_count_rm_shutdown_ack :   std_logic       := '1';
    
--ICAP signals
    signal icap_csib                : std_logic;
    signal icap_o                   : std_logic_vector(31 downto 0);
    signal icap_i                   : std_logic_vector(31 downto 0);
    signal icap_rdwrb               : std_logic;
    signal icap_avail               : std_logic;
    signal icap_prdone              : std_logic;
    signal icap_prerror             : std_logic;

--dfx decoupler signals
    signal vsm_vs_shift_rm_decouple : std_logic;
    signal vsm_vs_count_rm_decouple : std_logic;
    signal shift_out_int            : std_logic_vector(3 downto 0);
    signal count_out_int            : std_logic_vector(3 downto 0);
    
--RM reset signals
    signal vsm_vs_shift_rm_reset    : std_logic;
    signal vsm_vs_count_rm_reset    : std_logic;
    
    signal count_value              : std_logic_vector(34 downto 0);
    
    COMPONENT axi_protocol_converter
      PORT (
        aclk                        : IN STD_LOGIC;
        aresetn                     : IN STD_LOGIC;
        s_axi_awid                  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awaddr                : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axi_awlen                 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize                : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst               : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awlock                : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        s_axi_awcache               : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awprot                : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awregion              : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awqos                 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awvalid               : IN STD_LOGIC;
        s_axi_awready               : OUT STD_LOGIC;
        s_axi_wdata                 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axi_wstrb                 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_wlast                 : IN STD_LOGIC;
        s_axi_wvalid                : IN STD_LOGIC;
        s_axi_wready                : OUT STD_LOGIC;
        s_axi_bid                   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_bresp                 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid                : OUT STD_LOGIC;
        s_axi_bready                : IN STD_LOGIC;
        s_axi_arid                  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_araddr                : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axi_arlen                 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize                : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst               : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arlock                : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        s_axi_arcache               : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arprot                : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arregion              : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arqos                 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arvalid               : IN STD_LOGIC;
        s_axi_arready               : OUT STD_LOGIC;
        s_axi_rid                   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_rdata                 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axi_rresp                 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast                 : OUT STD_LOGIC;
        s_axi_rvalid                : OUT STD_LOGIC;
        s_axi_rready                : IN STD_LOGIC;
        m_axi_awaddr                : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_awprot                : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awvalid               : OUT STD_LOGIC;
        m_axi_awready               : IN STD_LOGIC;
        m_axi_wdata                 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_wstrb                 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_wvalid                : OUT STD_LOGIC;
        m_axi_wready                : IN STD_LOGIC;
        m_axi_bresp                 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid                : IN STD_LOGIC;
        m_axi_bready                : OUT STD_LOGIC;
        m_axi_araddr                : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_arprot                : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arvalid               : OUT STD_LOGIC;
        m_axi_arready               : IN STD_LOGIC;
        m_axi_rdata                 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_rresp                 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rvalid                : IN STD_LOGIC;
        m_axi_rready                : OUT STD_LOGIC
      );
    END COMPONENT;
    
    component dfx_controller
        port (
            clk                                 : in    std_logic;
            reset                               : in    std_logic;
            vsm_vs_shift_hw_triggers            : in    std_logic_vector(1 downto 0);
            vsm_vs_shift_rm_shutdown_ack        : in    std_logic;
            vsm_vs_shift_rm_shutdown_req        : out   std_logic;
            vsm_vs_shift_m_axis_status_tdata    : out   std_logic_vector(31 downto 0);
            vsm_vs_shift_m_axis_status_tvalid   : out   std_logic;
            vsm_vs_shift_rm_decouple            : out   std_logic;
            vsm_vs_shift_rm_reset               : out   std_logic;
            vsm_vs_shift_event_error            : out   std_logic;
            vsm_vs_shift_sw_shutdown_req        : out   std_logic;
            vsm_vs_shift_sw_startup_req         : out   std_logic;
            vsm_vs_count_hw_triggers            : in    std_logic_vector(1 downto 0);
            vsm_vs_count_rm_shutdown_ack        : in    std_logic;
            vsm_vs_count_rm_shutdown_req        : out   std_logic;
            vsm_vs_count_m_axis_status_tdata    : out   std_logic_vector(31 downto 0);
            vsm_vs_count_m_axis_status_tvalid   : out   std_logic;
            vsm_vs_count_rm_decouple            : out   std_logic;
            vsm_vs_count_rm_reset               : out   std_logic;
            vsm_vs_count_event_error            : out   std_logic;
            vsm_vs_count_sw_shutdown_req        : out   std_logic;
            vsm_vs_count_sw_startup_req         : out   std_logic;
            s_axi_reg_awaddr                    : in    std_logic_vector(31 downto 0);
            s_axi_reg_awvalid                   : in    std_logic;
            s_axi_reg_awready                   : out   std_logic;
            s_axi_reg_wdata                     : in    std_logic_vector(31 downto 0);
            s_axi_reg_wvalid                    : in    std_logic;
            s_axi_reg_wready                    : out   std_logic;
            s_axi_reg_bresp                     : out   std_logic_vector(1 downto 0);
            s_axi_reg_bvalid                    : out   std_logic;
            s_axi_reg_bready                    : in    std_logic;
            s_axi_reg_araddr                    : in    std_logic_vector(31 downto 0);
            s_axi_reg_arvalid                   : in    std_logic;
            s_axi_reg_arready                   : out   std_logic;
            s_axi_reg_rdata                     : out   std_logic_vector(31 downto 0);
            s_axi_reg_rresp                     : out   std_logic_vector(1 downto 0);
            s_axi_reg_rvalid                    : out   std_logic;
            s_axi_reg_rready                    : in    std_logic;
            m_axi_mem_araddr                    : out   std_logic_vector(31 downto 0);
            m_axi_mem_arburst                   : out   std_logic_vector(1 downto 0);
            m_axi_mem_arcache                   : out   std_logic_vector(3 downto 0);
            m_axi_mem_arlen                     : out   std_logic_vector(7 downto 0);
            m_axi_mem_arprot                    : out   std_logic_vector(2 downto 0);
            m_axi_mem_arready                   : in    std_logic;
            m_axi_mem_arsize                    : out   std_logic_vector(2 downto 0);
            m_axi_mem_aruser                    : out   std_logic_vector(3 downto 0);
            m_axi_mem_arvalid                   : out   std_logic;
            m_axi_mem_rdata                     : in    std_logic_vector(31 downto 0);
            m_axi_mem_rlast                     : in    std_logic;
            m_axi_mem_rready                    : out   std_logic;
            m_axi_mem_rresp                     : in    std_logic_vector(1 downto 0);
            m_axi_mem_rvalid                    : in    std_logic;
            icap_csib                           : out   std_logic;
            icap_o                              : in    std_logic_vector(31 downto 0);
            icap_i                              : out   std_logic_vector(31 downto 0);
            icap_rdwrb                          : out   std_logic;
            icap_avail                          : in    std_logic;
            icap_prdone                         : in    std_logic;
            icap_prerror                        : in    std_logic;
            icap_clk                            : in    std_logic;
            icap_reset                          : in    std_logic            
        );
    end component;
    
    component dfx_decoupler
        port (
            rp_intf_0_DATA  : in    std_logic_vector(3 downto 0);
            s_intf_0_DATA   : out   std_logic_vector(3 downto 0);
            decouple        : in    std_logic;
            decouple_status : out   std_logic
        );
    end component;
    
    component count
        port (
            rst             : in    std_logic;
            clk             : in    std_logic;
            count_out       : out   std_logic_vector(3 downto 0)
        );
    end component;
    
    component shift
        port (
            en              : in    std_logic;
            clk             : in    std_logic;
            addr            : in    std_logic_vector(11 downto 0);
            data_out        : out   std_logic_vector(3 downto 0)
        );
    end component;
        
begin

-- Assign AHB ports to record
    ahbsi_bridge.hsel   <= ahbsi.hsel;
    ahbsi_bridge.haddr  <= ahbsi.haddr;
    ahbsi_bridge.hwrite <= ahbsi.hwrite;
    ahbsi_bridge.htrans <= ahbsi.htrans;
    ahbsi_bridge.hsize  <= ahbsi.hsize;
    ahbsi_bridge.hburst <= ahbsi.hburst;
    ahbsi_bridge.hprot  <= ahbsi.hprot;
    ahbsi_bridge.hready <= ahbsi.hready;
    ahbsi_bridge.hwdata <= ahbsi.hwdata;
    
    
    ahbso.hconfig <= ahbso_bridge.hconfig;
    ahbso.hirq    <= (others => '0');
    ahbso.hindex  <= hsindex;
    ahbso.hsplit  <= (others => '0');
    ahbso.hready  <= ahbso_bridge.hready;
    ahbso.hresp   <= ahbso_bridge.hresp;
    ahbso.hrdata  <= ahbso_bridge.hrdata;
    
    ahbmi_bridge.hgrant <= ahbmi.hgrant;
    ahbmi_bridge.hready <= ahbmi.hready;
    ahbmi_bridge.hresp  <= ahbmi.hresp;
    ahbmi_bridge.hrdata <= ahbmi.hrdata;
    
    ahbmo.htrans    <= ahbmo_bridge.htrans;
    ahbmo.haddr     <= ahbmo_bridge.haddr;
    ahbmo.hwrite    <= ahbmo_bridge.hwrite;
    ahbmo.hsize     <= ahbmo_bridge.hsize;
    ahbmo.hburst    <= ahbmo_bridge.hburst;
    ahbmo.hprot     <= ahbmo_bridge.hprot;
    ahbmo.hwdata    <= ahbmo_bridge.hwdata;
    ahbmo.hirq      <= (others => '0');
    ahbmo.hconfig   <= ahbmo_bridge.hconfig;
    ahbmo.hindex    <= hmindex;
  
  
    bridge_ahb2axi : ahb2axi4b
        generic map (
            hindex          => hsindex,
            aximid          => 0,
            wbuffer_num     => 32,
            rprefetch_num   => 32,
            ahb_endianness  => ahbendian,
            endianness_mode => 0,
            narrow_acc_mode => 0,
            vendor          => VENDOR_GAISLER,
            device          => GAISLER_AHB2AXI,
            bar0            => ahb2ahb_membar(haddr, '1', '1', hmask)
        )
        port map (
            rstn            => rstn,
            clk             => clk,
            ahbsi           => ahbsi_bridge,
            ahbso           => ahbso_bridge,
            aximi           => aximi,
            aximo           => aximo
        );
    
    s_axi_awlock(0)  <= aximo.aw.lock;
    s_axi_arlock(0)  <= aximo.ar.lock;
    
    
    bridge_axi2ahb : axi2ahb
        generic map (
            memtech                         => memtech,
            hindex                          => hmindex,
            dbuffer                         => 32,
            wordsize                        => wordsize,
            axi_endian                      => ahbendian,
            sub_bus_width_address_inversion => 0,
            mask                            => 16#000#,
            vendorid                        => VENDOR_GAISLER,
            deviceid                        => GAISLER_AXI2AHB,
            memory_ft                       => 0
        )
        port map (
            clk             => clk,
            resetn          => rstn,
            ahbmi           => ahbmi_bridge,
            ahbmo           => ahbmo_bridge,
            axisi           => axisi,
            axiso           => axiso
        );
    
    ----------------------------------------------------------------------------------------
    --Virtual Sockets
    ----------------------------------------------------------------------------------------
    --Virtual Socket 0: shift
    inst_shift : shift
        port map (
            en          =>  vsm_vs_shift_rm_reset,
            clk         =>  clk,
            addr        =>  count_value(34 downto 23),
            data_out    =>  shift_out_int
        );
    
    --Vrtual Socket 1: count
    inst_count : count
        port map (
            rst         =>  vsm_vs_count_rm_reset,
            clk         =>  clk,
            count_out   =>  count_out_int
        );
    
    --add DFX Decoupler IP
    dfx_decoupler_shift : dfx_decoupler
        port map (
            rp_intf_0_DATA  =>  shift_out_int,
            s_intf_0_DATA   =>  shift_out,
            decouple        =>  vsm_vs_shift_rm_decouple,
            decouple_status =>  open
        );
        
    dfx_decoupler_count : dfx_decoupler
        port map (
            rp_intf_0_DATA  =>  count_out_int,
            s_intf_0_DATA   =>  count_out,
            decouple        =>  vsm_vs_count_rm_decouple,
            decouple_status =>  open
        );
    
    ---------------------------------------------------------------------------------------
    --DFX Controller
    ---------------------------------------------------------------------------------------
    i_dfx_controller : dfx_controller
        port map (
            clk             =>  clk,
            reset           =>  rstn,
            icap_clk        =>  clk,
            icap_reset      =>  rstn,
            
            --Signals for vs_shift
            vsm_vs_shift_hw_triggers            =>  vsm_vs_shift_hw_triggers,
            vsm_vs_shift_rm_shutdown_ack        =>  vsm_vs_shift_rm_shutdown_ack,
            vsm_vs_shift_rm_shutdown_req        =>  open,
            vsm_vs_shift_m_axis_status_tdata    =>  open,
            vsm_vs_shift_m_axis_status_tvalid   =>  open,
            vsm_vs_shift_rm_decouple            =>  vsm_vs_shift_rm_decouple,
            vsm_vs_shift_rm_reset               =>  vsm_vs_shift_rm_reset,
            vsm_vs_shift_event_error            =>  open,
            vsm_vs_shift_sw_shutdown_req        =>  open,
            vsm_vs_shift_sw_startup_req         =>  open,
            
            --Signals for vs_count
            vsm_vs_count_hw_triggers            =>  vsm_vs_count_hw_triggers,
            vsm_vs_count_rm_shutdown_ack        =>  vsm_vs_count_rm_shutdown_ack,
            vsm_vs_count_rm_shutdown_req        =>  open,
            vsm_vs_count_m_axis_status_tdata    =>  open,
            vsm_vs_count_m_axis_status_tvalid   =>  open,
            vsm_vs_count_rm_decouple            =>  vsm_vs_count_rm_decouple,
            vsm_vs_count_rm_reset               =>  vsm_vs_count_rm_reset,
            vsm_vs_count_event_error            =>  open,
            vsm_vs_count_sw_shutdown_req        =>  open,
            vsm_vs_count_sw_startup_req         =>  open,
            
            --ICAP signals
            icap_csib                           =>  icap_csib,
            icap_o                              =>  icap_o,
            icap_i                              =>  icap_i,
            icap_rdwrb                          =>  icap_rdwrb,
            icap_avail                          =>  icap_avail,
            icap_prdone                         =>  icap_prdone,
            icap_prerror                        =>  icap_prerror,
            
            --Signals for AXI slave
            s_axi_reg_awaddr                => converter_to_dfx_awaddr,
            s_axi_reg_awvalid               => converter_to_dfx_awvalid,
            s_axi_reg_awready               => converter_to_dfx_awready,
            s_axi_reg_wdata                 => converter_to_dfx_wdata,
            s_axi_reg_wvalid                => converter_to_dfx_wvalid,
            s_axi_reg_wready                => converter_to_dfx_wready,
            s_axi_reg_bresp                 => converter_to_dfx_bresp,
            s_axi_reg_bvalid                => converter_to_dfx_bvalid,
            s_axi_reg_bready                => converter_to_dfx_bready,
            s_axi_reg_araddr                => converter_to_dfx_araddr,
            s_axi_reg_arvalid               => converter_to_dfx_arvalid,
            s_axi_reg_arready               => converter_to_dfx_arready,
            s_axi_reg_rdata                 => converter_to_dfx_rdata,
            s_axi_reg_rresp                 => converter_to_dfx_rresp,
            s_axi_reg_rvalid                => converter_to_dfx_rvalid,
            s_axi_reg_rready                => converter_to_dfx_rready,
            
            --Signals for AXI master
            m_axi_mem_araddr                    =>  axisi.ar.addr,
            m_axi_mem_arburst                   =>  axisi.ar.burst,
            m_axi_mem_arcache                   =>  axisi.ar.cache,
            m_axi_mem_arlen                     =>  axisi.ar.len,
            m_axi_mem_arprot                    =>  axisi.ar.prot,
            m_axi_mem_arready                   =>  axiso.ar.ready,
            m_axi_mem_arsize                    =>  axisi.ar.size,
            m_axi_mem_aruser                    =>  open,
            m_axi_mem_arvalid                   =>  axisi.ar.valid,
            m_axi_mem_rdata                     =>  axiso.r.data,
            m_axi_mem_rlast                     =>  axiso.r.last,
            m_axi_mem_rready                    =>  axisi.r.ready,
            m_axi_mem_rresp                     =>  axiso.r.resp,
            m_axi_mem_rvalid                    =>  axiso.r.valid
        );
        
    -- axi_protocol_converter
    axi_protocol_converter_inst : axi_protocol_converter
        port map (
            aclk           => clk,
            aresetn        => rstn,
            m_axi_awaddr   => converter_to_dfx_awaddr,      
            m_axi_awprot   => open,
            m_axi_awvalid  => converter_to_dfx_awvalid,     
            m_axi_awready  => converter_to_dfx_awready,     
            m_axi_wdata    => converter_to_dfx_wdata,       
            m_axi_wstrb    => open,      
            m_axi_wvalid   => converter_to_dfx_wvalid,      
            m_axi_wready   => converter_to_dfx_wready,      
            m_axi_bresp    => converter_to_dfx_bresp,       
            m_axi_bvalid   => converter_to_dfx_bvalid,    
            m_axi_bready   => converter_to_dfx_bready,      
            m_axi_araddr   => converter_to_dfx_araddr,   
            m_axi_arprot    => open,
            m_axi_arvalid  => converter_to_dfx_arvalid,     
            m_axi_arready  => converter_to_dfx_arready,    
            m_axi_rdata    => converter_to_dfx_rdata,     
            m_axi_rresp    => converter_to_dfx_rresp,    
            m_axi_rvalid   => converter_to_dfx_rvalid,      
            m_axi_rready   => converter_to_dfx_rready,
            
            s_axi_arid     => aximo.ar.id,
            s_axi_araddr   => aximo.ar.addr,
            s_axi_arburst  => aximo.ar.burst,
            s_axi_arcache  => aximo.ar.cache,
            s_axi_arlen    => aximo.ar.len,
            s_axi_arlock   => s_axi_arlock,
            s_axi_arprot   => aximo.ar.prot,
            s_axi_arregion => s_axi_arregion_UNCONNECTED,
            s_axi_arqos    => aximo.ar.qos,
            s_axi_arready  => aximi.ar.ready,
            s_axi_arsize   => aximo.ar.size,
            s_axi_arvalid  => aximo.ar.valid,
            s_axi_awid     => aximo.aw.id,
            s_axi_awaddr   => aximo.aw.addr,
            s_axi_awburst  => aximo.aw.burst,
            s_axi_awcache  => aximo.aw.cache,
            s_axi_awlen    => aximo.aw.len,
            s_axi_awlock   => s_axi_awlock,
            s_axi_awprot   => aximo.aw.prot,
            s_axi_awregion => s_axi_awregion_UNCONNECTED,
            s_axi_awqos    => aximo.aw.qos,
            s_axi_awready  => aximi.aw.ready,
            s_axi_awsize   => aximo.aw.size,
            s_axi_awvalid  => aximo.aw.valid,
            s_axi_bid      => aximi.b.id,
            s_axi_bready   => aximo.b.ready,
            s_axi_bresp    => aximi.b.resp,
            s_axi_bvalid   => aximi.b.valid,
            s_axi_rid      => aximi.r.id,
            s_axi_rdata    => aximi.r.data,
            s_axi_rlast    => aximi.r.last,
            s_axi_rready   => aximo.r.ready,
            s_axi_rresp    => aximi.r.resp,
            s_axi_rvalid   => aximi.r.valid,
            s_axi_wdata    => aximo.w.data,
            s_axi_wlast    => aximo.w.last,
            s_axi_wready   => aximi.w.ready,
            s_axi_wstrb    => aximo.w.strb,
            s_axi_wvalid   => aximo.w.valid
    );
        
    ICAPE3_inst : ICAPE3
       port map (
          AVAIL => icap_avail,     -- 1-bit output: Availability status of ICAP.
          O => icap_o,             -- 32-bit output: Configuration data output bus.
          PRDONE => icap_prdone,   -- 1-bit output: Indicates completion of Partial Reconfiguration.
          PRERROR => icap_prerror, -- 1-bit output: Indicates error during Partial Reconfiguration.
          CLK => clk,         -- 1-bit input: Clock input.
          CSIB => icap_csib,       -- 1-bit input: Active-Low ICAP enable.
          I => icap_i,             -- 32-bit input: Configuration data input bus.
          RDWRB => icap_rdwrb      -- 1-bit input: Read/Write Select input.
       );

    p_count : process (clk)
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                count_value <= (others => '0');
            else
                count_value <= std_logic_vector(unsigned(count_value) + 1);
            end if;
        end if;
    end process;

end rtl;
