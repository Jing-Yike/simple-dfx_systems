----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/26/2025 04:04:33 PM
-- Design Name: 
-- Module Name: dfx_system_wrapper - rtl
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



entity dfx_system_wrapper is
generic(
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;   
    ahbendian               : integer := AHBENDIAN
);
  Port ( 
    -- System signals
    amba_rstn                   : in    std_logic;
    clk_amba                    : in    std_logic;
    
    -- AHB slave interface (replaces the AXI slave interface)   
    ahbso                       : out   ahb_slv_out_type;
    ahbsi                       : in    ahb_slv_in_type;
    
    -- AHB master interface
    ahbmi                       : in    ahb_mst_in_type;
    ahbmo                       : out   ahb_mst_out_type;
    
    -- Hardware triggers
    vsm_vs_shift_hw_triggers    : in    std_logic_vector(1 downto 0);
    vsm_vs_count_hw_triggers    : in    std_logic_vector(1 downto 0);
    
    -- LED outputs
    count_out                   : out   std_logic_vector(3 downto 0);
    shift_out                   : out   std_logic_vector(3 downto 0)
  );
end dfx_system_wrapper;

architecture rtl of dfx_system_wrapper is

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


component dfx_system is
    port(
        clk                             : in    std_logic;
        reset                           : in    std_logic;
        vsm_vs_shift_hw_triggers        : in    std_logic_vector(1 downto 0);
        vsm_vs_count_hw_triggers        : in    std_logic_vector(1 downto 0);
        s_axi_reg_awaddr                : in    std_logic_vector(31 downto 0);
        s_axi_reg_awvalid               : in    std_logic;
        s_axi_reg_awready               : out   std_logic;
        s_axi_reg_wdata                 : in    std_logic_vector(31 downto 0);
        s_axi_reg_wvalid                : in    std_logic;
        s_axi_reg_wready                : out   std_logic;
        s_axi_reg_bresp                 : out   std_logic_vector(1 downto 0);
        s_axi_reg_bvalid                : out   std_logic;
        s_axi_reg_bready                : in    std_logic;
        s_axi_reg_araddr                : in    std_logic_vector(31 downto 0);
        s_axi_reg_arvalid               : in    std_logic;
        s_axi_reg_arready               : out   std_logic;
        s_axi_reg_rdata                 : out   std_logic_vector(31 downto 0);
        s_axi_reg_rresp                 : out   std_logic_vector(1 downto 0);
        s_axi_reg_rvalid                : out   std_logic;
        s_axi_reg_rready                : in    std_logic;
        m_axi_mem_araddr                : out   std_logic_vector(31 downto 0);
        m_axi_mem_arburst               : out   std_logic_vector(1 downto 0);
        m_axi_mem_arcache               : out   std_logic_vector(3 downto 0);
        m_axi_mem_arlen                 : out   std_logic_vector(7 downto 0);
        m_axi_mem_arprot                : out   std_logic_vector(2 downto 0);
        m_axi_mem_arready               : in    std_logic;
        m_axi_mem_arsize                : out   std_logic_vector(2 downto 0);
        m_axi_mem_aruser                : out   std_logic_vector(3 downto 0);
        m_axi_mem_arvalid               : out   std_logic;
        m_axi_mem_rdata                 : in    std_logic_vector(31 downto 0);
        m_axi_mem_rlast                 : in    std_logic;
        m_axi_mem_rready                : out   std_logic;
        m_axi_mem_rresp                 : in    std_logic_vector(1 downto 0);
        m_axi_mem_rvalid                : in    std_logic;
        count_out                       : out   std_logic_vector(3 downto 0);
        shift_out                       : out   std_logic_vector(3 downto 0)
    );
end component;

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
      
    -- AXI4 signals between dfx system and AXI2AHB
      signal dfx_to_bridge_araddr         : std_logic_vector(31 downto 0);
      signal dfx_to_bridge_arburst        : std_logic_vector(1 downto 0);
      signal dfx_to_bridge_arcache        : std_logic_vector(3 downto 0);
      signal dfx_to_bridge_arlen          : std_logic_vector(7 downto 0);
      signal dfx_to_bridge_arprot         : std_logic_vector(2 downto 0);
      signal dfx_to_bridge_arready        : std_logic;
      signal dfx_to_bridge_arsize         : std_logic_vector(2 downto 0);
      signal dfx_to_bridge_aruser         : std_logic_vector(3 downto 0);
      signal dfx_to_bridge_arvalid        : std_logic;
      signal dfx_to_bridge_rdata          : std_logic_vector(31 downto 0);
      signal dfx_to_bridge_rlast          : std_logic;
      signal dfx_to_bridge_rready         : std_logic;
      signal dfx_to_bridge_rresp          : std_logic_vector(1 downto 0);
      signal dfx_to_bridge_rvalid         : std_logic;
      
      signal aximi                        : axi_somi_type;
      signal aximo                        : axi4_mosi_type;
      signal ahbsi_bridge                 : ahb_slv_in_type;
      signal ahbso_bridge                 : ahb_slv_out_type;
      signal s_axi_awlock                 : std_logic_vector (0 downto 0);
      signal s_axi_arlock                 : std_logic_vector (0 downto 0);
      
      signal axisi                        : axi4_mosi_type;
      signal axiso                        : axi_somi_type;
      
    -- UNCONNECTED signals --
      signal s_axi_arregion_UNCONNECTED   : STD_LOGIC_VECTOR ( 3 downto 0 );
      signal s_axi_awregion_UNCONNECTED   : STD_LOGIC_VECTOR ( 3 downto 0 );
      
begin

  ahbsi_bridge.hsel <= ahbsi.hsel;
  ahbsi_bridge.haddr <= ahbsi.haddr;
  ahbsi_bridge.hwrite <= ahbsi.hwrite;
  ahbsi_bridge.htrans <= ahbsi.htrans;
  ahbsi_bridge.hsize <= ahbsi.hsize;
  ahbsi_bridge.hburst <= ahbsi.hburst;
  ahbsi_bridge.hprot <= ahbsi.hprot;
  ahbsi_bridge.hready <= ahbsi.hready;
  ahbsi_bridge.hwdata <= ahbsi.hwdata;
  

  ahbso.hconfig <= ahbso_bridge.hconfig;
  ahbso.hirq    <= (others => '0');
  ahbso.hindex  <= hindex;
  ahbso.hsplit  <= (others => '0');
  ahbso.hready  <= ahbso_bridge.hready;
  ahbso.hresp   <= ahbso_bridge.hresp;
  ahbso.hrdata  <= ahbso_bridge.hrdata;

  bridge_ahb2axi : ahb2axi4b
    generic map (
      hindex => hindex,
      aximid => 0,
      wbuffer_num => 32,
      rprefetch_num => 32,
      ahb_endianness  => ahbendian,
      endianness_mode => 0,
      narrow_acc_mode => 0,
      vendor  => VENDOR_GAISLER,
      device  => GAISLER_AHB2AXI,
      bar0    => ahb2ahb_membar(haddr, '1', '1', hmask)
      )
    port map (
      rstn  => amba_rstn,
      clk   => clk_amba,
      ahbsi => ahbsi_bridge,
      ahbso => ahbso,
      aximi => aximi,
      aximo => aximo);
      
    s_axi_awlock(0)  <= aximo.aw.lock;
    s_axi_arlock(0)  <= aximo.ar.lock;
    
--  bridge_axi2ahb : axi2ahb
--    generic map (
      
--    );
      
  axi_protocol_converter_inst : axi_protocol_converter
    port map (
        aclk           => clk_amba,
        aresetn        => amba_rstn,
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
    
    dfx_system_inst : dfx_system
        port map (
            clk                             => clk_amba,
            reset                           => amba_rstn,
            vsm_vs_shift_hw_triggers        => vsm_vs_shift_hw_triggers,
            vsm_vs_count_hw_triggers        => vsm_vs_count_hw_triggers,
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
            --AXI2AHB
            count_out                       => count_out,
            shift_out                       => shift_out
        );

end rtl;
