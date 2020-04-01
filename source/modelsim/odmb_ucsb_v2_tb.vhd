-- ODMB_UCSB_V2_TB: Test bench for the simulation of the ODMB firmware (ODMB_UCSB_V2)

library work;
library ieee;
library std;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library unimacro;
library unisim;
use unimacro.vcomponents.all;
use unisim.vcomponents.all;

entity ODMB_UCSB_V2_TB is
  generic (
    NFEB : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 in the final design
    );  
  port
    (error : out std_logic);

end ODMB_UCSB_V2_TB;


architecture ODMB_UCSB_V2_TB_arch of ODMB_UCSB_V2_TB is

-- Beginning of the Test Bench Section

  component file_handler is
    port (
      clk             : in  std_logic;
      start           : out std_logic;
      vme_cmd_reg     : out std_logic_vector(31 downto 0);
      vme_dat_reg_in  : out std_logic_vector(31 downto 0);
      vme_dat_reg_out : in  std_logic_vector(31 downto 0);
      vme_cmd_rd      : in  std_logic;
      vme_dat_wr      : in  std_logic
      );

  end component;

  component file_handler_event is
    port (
      clk      : in  std_logic;
      en       : in  std_logic;
      l1a      : out std_logic;
      alct_dav : out std_logic;
      otmb_dav : out std_logic;
      lct      : out std_logic_vector(7 downto 0)
      );

  end component;

  component file_handler_ccb is
    port (
      clk        : in  std_logic;
      en         : in  std_logic;
      ccb_cmd_s  : out std_logic;
      ccb_cmd    : out std_logic_vector(5 downto 0);
      ccb_data_s : out std_logic;
      ccb_data   : out std_logic_vector(7 downto 0);
      ccb_cal    : out std_logic_vector(2 downto 0)
      );

  end component;

  component test_controller is

    port(

      clk       : in std_logic;
      rstn      : in std_logic;
      sw_reset  : in std_logic;
      tc_enable : in std_logic;

-- From/To SLV_MGT Module

      start     : in  std_logic;
      start_res : out std_logic;
      stop      : in  std_logic;
      stop_res  : out std_logic;
      mode      : in  std_logic;
      cmd_n     : in  std_logic_vector(9 downto 0);
      busy      : out std_logic;

      vme_cmd_reg     : in  std_logic_vector(31 downto 0);
      vme_dat_reg_in  : in  std_logic_vector(31 downto 0);
      vme_dat_reg_out : out std_logic_vector(31 downto 0);

-- To/From VME Master FSM

      vme_cmd    : out std_logic;
      vme_cmd_rd : in  std_logic;

      vme_addr    : out std_logic_vector(23 downto 1);
      vme_wr      : out std_logic;
      vme_wr_data : out std_logic_vector(15 downto 0);
      vme_rd      : out std_logic;
      vme_rd_data : in  std_logic_vector(15 downto 0);

-- From/To VME_CMD Memory and VME_DAT Memory

      vme_mem_addr     : out std_logic_vector(9 downto 0);
      vme_mem_rden     : out std_logic;
      vme_cmd_mem_out  : in  std_logic_vector(31 downto 0);
      vme_dat_mem_out  : in  std_logic_vector(31 downto 0);
      vme_dat_mem_wren : out std_logic;
      vme_dat_mem_in   : out std_logic_vector(31 downto 0)

      );

  end component;

  component vme_master is
    
    port (
      clk      : in std_logic;
      rstn     : in std_logic;
      sw_reset : in std_logic;

      vme_cmd    : in  std_logic;
      vme_cmd_rd : out std_logic;

      vme_addr    : in  std_logic_vector(23 downto 1);
      vme_wr      : in  std_logic;
      vme_wr_data : in  std_logic_vector(15 downto 0);
      vme_rd      : in  std_logic;
      vme_rd_data : out std_logic_vector(15 downto 0);

      ga   : out std_logic_vector(5 downto 0);
      addr : out std_logic_vector(23 downto 1);
      am   : out std_logic_vector(5 downto 0);

      as      : out std_logic;
      ds0     : out std_logic;
      ds1     : out std_logic;
      lword   : out std_logic;
      write_b : out std_logic;
      iack    : out std_logic;
      berr    : out std_logic;
      sysfail : out std_logic;
      dtack   : in  std_logic;

      data_in  : in  std_logic_vector(15 downto 0);
      data_out : out std_logic_vector(15 downto 0);
      oe_b     : out std_logic

      );

  end component;

  component pon_reg is
    port (
      pon_en   : in  std_logic;
      pon_load : in  std_logic;
      pon_in   : in  std_logic_vector(7 downto 0);
      pon_out  : out std_logic_vector(7 downto 0)
      );

  end component;

  component prom is
    port(

      clk : in std_logic;
      rst : in std_logic;

      we_b : in std_logic;
      cs_b : in std_logic;
      oe_b : in std_logic;
      le_b : in std_logic;

      addr : in    std_logic_vector(22 downto 0);
      data : inout std_logic_vector(15 downto 0)
      );

  end component;



-- End of the Test Bench Section

  component odmb_ucsb_v2 is
    generic (
      IS_SIMULATION : integer range 0 to 1 := 1;  -- Set to 1 by test bench in simulation 
      NFEB          : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 in the final design
      );  
    port
      (
        tc_run_out : out std_logic;     -- OK           NEW!


-- BPI Prom signals To/From bpi_interface

        prom_a        : inout std_logic_vector(22 downto 0);
        prom_a_21_rs0 : out   std_logic;  -- not connected in v.2
        prom_a_22_rs1 : out   std_logic;  -- not connected in v.2
        prom_d        : inout std_logic_vector(15 downto 0);
        prom_cs_b     : out   std_logic;
        prom_oe_b     : out   std_logic;
        prom_we_b     : out   std_logic;
        prom_le_b     : out   std_logic;

-- From/To VME connector To/From MBV

        vme_data        : inout std_logic_vector(15 downto 0);
        vme_addr        : in    std_logic_vector(23 downto 1);
        vme_am          : in    std_logic_vector(5 downto 0);
        vme_gap         : in    std_logic;
        vme_ga          : in    std_logic_vector(4 downto 0);
        --vme_bg0         : in    std_logic;
        --vme_bg1         : in    std_logic;
        --vme_bg2         : in    std_logic;
        --vme_bg3         : in    std_logic;
        vme_as_b        : in    std_logic;
        vme_ds_b        : in    std_logic_vector(1 downto 0);
        --vme_sysreset_b  : in    std_logic;
        vme_sysfail_b   : in    std_logic;
        vme_sysfail_out : out   std_logic;
        vme_berr_b      : in    std_logic;
        vme_berr_out    : out   std_logic;
        vme_iack_b      : in    std_logic;
        vme_lword_b     : in    std_logic;
        vme_write_b     : in    std_logic;
        --vme_clk         : in    std_logic;
        vme_dtack_v6_b  : inout std_logic;
        vme_tovme       : out   std_logic;  -- not (tovme)
        vme_doe_b       : out   std_logic;

-- From/To PPIB (connectors J3 and J4)

        dcfeb_tck       : out std_logic_vector(NFEB downto 1);
        dcfeb_tms       : inout std_logic;
        dcfeb_tdi       : inout std_logic;
        dcfeb_tdo       : in  std_logic_vector(NFEB downto 1);
        dcfeb_bc0       : out std_logic;
        dcfeb_resync    : out std_logic;
        odmb_hardrst_b  : out std_logic;  -- Generater REPROG_B
        dcfeb_reprgen_b : out std_logic;
        dcfeb_injpls    : out std_logic;
        dcfeb_extpls    : out std_logic;
        dcfeb_l1a       : out std_logic;
        dcfeb_l1a_match : out std_logic_vector(NFEB downto 1);
        dcfeb_done      : in  std_logic_vector(NFEB downto 1);

-- From/To ODMB_UCSB_V2 JTAG port (through IC34)

        v6_tck      : out std_logic;
        v6_tms      : out std_logic;
        v6_tdi      : out std_logic;
        v6_jtag_sel : out std_logic;

        --odmb_tms : in std_logic;
        --odmb_tdi : in std_logic;
        odmb_tdo : in std_logic;

-- From/To J6 (J3) connector to ODMB_CTRL

        ccb_cmd      : in  std_logic_vector(5 downto 0);
        ccb_cmd_s    : in  std_logic;
        ccb_data     : in  std_logic_vector(7 downto 0);
        ccb_data_s   : in  std_logic;
        ccb_cal      : in  std_logic_vector(2 downto 0);
        ccb_crsv     : in  std_logic_vector(4 downto 0);
        ccb_drsv     : in  std_logic_vector(1 downto 0);
        ccb_rsvo     : in  std_logic_vector(4 downto 0);
        ccb_rsvi     : out std_logic_vector(2 downto 0);
        ccb_bx0_b      : in  std_logic;
        ccb_bxrst_b    : in  std_logic;
        ccb_l1arst_b   : in  std_logic;
        ccb_l1acc_b    : in  std_logic;
        ccb_l1rls    : out std_logic;
        ccb_clken    : in  std_logic;
        ccb_evcntres_b : in  std_logic;

        --ccb_hardrst : in std_logic;
        ccb_softrst_b : in std_logic;

-- From J6/J7 (J3/J4) to FIFOs

        otmb      : in std_logic_vector(17 downto 0);
        alct      : in std_logic_vector(17 downto 0);
        rawlct    : in std_logic_vector(NFEB downto 0);
        --otmbffclk : in std_logic;

-- From/To J3/J4 t/fromo ODMB_CTRL

        otmbdav   : in  std_logic;      --  lctdav1
        alctdav   : in  std_logic;      --  lctdav2
--    rsvtd : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);     
        rsvtd_in  : in  std_logic_vector(2 downto 0);
        rsvtd_out : out std_logic_vector(2 downto 0);
        lctrqst   : out std_logic_vector(2 downto 1);

-- From/To QPLL (From/To DAQMBV)

        qpll_autorestart : out std_logic;
        qpll_reset       : out std_logic;
        --qpll_f0sel       : in  std_logic_vector(3 downto 0);
        qpll_locked      : in  std_logic;
        qpll_error       : in  std_logic;
        qpll_clk40MHz_p  : in  std_logic;
        qpll_clk40MHz_n  : in  std_logic;
        --qpll_clk80MHz_p  : in  std_logic;
        --qpll_clk80MHz_n  : in  std_logic;
        qpll_clk160MHz_p : in  std_logic;
        qpll_clk160MHz_n : in  std_logic;

-- From/To LVMB (From/To DAQMBV and DAQMBC)

        lvmb_pon   : out std_logic_vector(7 downto 0);
        pon_load   : out std_logic;
        pon_en_b   : out std_logic;
        r_lvmb_pon : in  std_logic_vector(7 downto 0);
        lvmb_csb   : out std_logic_vector(6 downto 0);
        lvmb_sclk  : out std_logic;
        lvmb_sdin  : out std_logic;
        lvmb_sdout : in  std_logic;

-- To LEDs

        ledg : out std_logic_vector(6 downto 1);
        ledr : out std_logic_vector(6 downto 1);

-- From Push Buttons

        pb : in std_logic_vector(1 downto 0);

-- From/To Test Connector for Single-Ended signals

        d : out std_logic_vector(63 downto 0);

-- From/To Test Points

        test_point : out std_logic_vector(49 downto 12);

-- From/To RX 

        orx_p     : in  std_logic_vector(12 downto 1);
        orx_n     : in  std_logic_vector(12 downto 1);
        orx_rx_en : out std_logic;
        orx_en_sd : out std_logic;
        orx_sd    : in  std_logic;
        orx_sq_en : out std_logic;

-- From/To OT1 (GigaBit Link)

        gl0_tx_p  : out std_logic;
        gl0_tx_n  : out std_logic;
        gl0_rx_p  : in  std_logic;
        gl0_rx_n  : in  std_logic;
        gl0_clk_p : in  std_logic;
        gl0_clk_n : in  std_logic;

-- From/To OT2 (GigaBit Link)

        gl1_tx_p  : out std_logic;
        gl1_tx_n  : out std_logic;
        gl1_rx_p  : in  std_logic;
        gl1_rx_n  : in  std_logic;
        gl1_clk_p : in  std_logic;
        gl1_clk_n : in  std_logic;

-- From IC31 

        done_in : in std_logic;

-- Adam Aug 15 To SYSMON QQQ
        --sm_agnd       : in std_logic;
        p1v0_sm_p     : in std_logic;
        p1v0_sm_n     : in std_logic;
        p2v5_sm_p     : in std_logic;
        p2v5_sm_n     : in std_logic;
        lv_p3v3_sm_p  : in std_logic;
        lv_p3v3_sm_n  : in std_logic;
        p5v_sm_p      : in std_logic;
        p5v_sm_n      : in std_logic;
        p5v_lvmb_sm_p : in std_logic;
        p5v_lvmb_sm_n : in std_logic;
        p3v3_pp_sm_p  : in std_logic;
        p3v3_pp_sm_n  : in std_logic;
        therm1_p      : in std_logic;
        therm1_n      : in std_logic;
        therm2_p      : in std_logic;
        therm2_n      : in std_logic;

    otmb_tx_tb : in std_logic_vector(48 downto 0)
        );
  end component;

  component PRBS_GEN is
    port (
      DOUT : out std_logic;

      CLK    : in std_logic;
      RST    : in std_logic;
      ENABLE : in std_logic
      );
  end component;

  component PULSE_EDGE is
    port (
      DOUT   : out std_logic;
      PULSE1 : out std_logic;
      CLK    : in  std_logic;
      RST    : in  std_logic;
      NPULSE : in  integer;
      DIN    : in  std_logic
      );
  end component;

-- clock and reset signals

  signal go, goevent, goccb : std_logic := '0';
  signal goccbcal0 : std_logic := '0';

  signal ccb_cal_tb : std_logic_vector(2 downto 0);
  
  signal clk  : std_logic := '0';
  signal rst  : std_logic := '0';
  signal rstn : std_logic := '1';

  signal SLOWCLK      : std_logic := '0';
  signal SLOWCLK2     : std_logic := '0';
  signal MIDCLK       : std_logic := '0';
  signal FASTCLK      : std_logic := '0';
  signal SUPERFASTCLK : std_logic := '0';

-- signals from file_handler_event

  signal l1a      : std_logic;
  signal l1a_b    : std_logic := '1';
  signal alct_dav : std_logic;
  signal otmb_dav : std_logic;
  signal lct      : std_logic_vector(NFEB downto 0);

-- signals to/from test_controller (from/to slv_mgt module)

  signal start           : std_logic;
  signal start_res       : std_logic;
  signal stop            : std_logic;
  signal stop_res        : std_logic;
  signal vme_cmd_reg     : std_logic_vector(31 downto 0);
  signal vme_dat_reg_in  : std_logic_vector(31 downto 0);
  signal vme_dat_reg_out : std_logic_vector(31 downto 0);
  signal mode            : std_logic                    := '1';  -- read commands from file
  signal cmd_n           : std_logic_vector(9 downto 0) := "0000000000";
  signal busy            : std_logic;

-- signals to/from test_controller (from/to cmd and dat memories)

  signal vme_mem_addr     : std_logic_vector(9 downto 0);
  signal vme_mem_rden     : std_logic;
  signal vme_cmd_mem_out  : std_logic_vector(31 downto 0);
  signal vme_dat_mem_out  : std_logic_vector(31 downto 0);
  signal vme_dat_mem_wren : std_logic;
  signal vme_dat_mem_in   : std_logic_vector(31 downto 0);

-- signals between test_controller and vme_master_fsm and command_module

  signal vme_cmd     : std_logic;
  signal vme_cmd_rd  : std_logic;
  signal vme_addr    : std_logic_vector(23 downto 1);
  signal vme_wr      : std_logic;
  signal vme_wr_data : std_logic_vector(15 downto 0);
  signal vme_rd      : std_logic;
  signal vme_rd_data : std_logic_vector(15 downto 0);
  signal vme_data    : std_logic_vector(15 downto 0);

-- signals between vme_master_fsm and command_module

  signal berr        : std_logic;
  signal berr_out    : std_logic;
  signal as          : std_logic;
-- signal ds0 : std_logic;
-- signal ds1 : std_logic;
  signal ds          : std_logic_vector(1 downto 0);
  signal lword       : std_logic;
  signal write_b     : std_logic;
  signal iack        : std_logic;
  signal sysfail     : std_logic;
  signal sysfail_out : std_logic;
  signal am          : std_logic_vector(5 downto 0);
  signal ga          : std_logic_vector(5 downto 0);
  signal adr         : std_logic_vector(23 downto 1);
  signal oe_b        : std_logic;

-- signals between vme_master_fsm and cfebjtag and lvdbmon modules

  signal dtack   : std_logic;
  signal indata  : std_logic_vector(15 downto 0);
  signal outdata : std_logic_vector(15 downto 0);

  signal tovme, doe_b : std_logic;

  signal ccbinj : std_logic := '0';
  signal ccbpls : std_logic := '0';


-- Signals From/To ODMB_V6

-- From/To PPIB (connectors J3 and J4)

  signal dcfeb_tck       : std_logic_vector(NFEB downto 1);
  signal dcfeb_tms       : std_logic;
  signal dcfeb_tdi       : std_logic;
  signal dcfeb_tdo       : std_logic_vector(NFEB downto 1) := "0000000";  -- in
  signal dcfeb_bc0       : std_logic                       := '0';
  signal dcfeb_resync    : std_logic                       := '0';
  signal odmb_hardrst_b  : std_logic                       := '0';
  signal dcfeb_reprgen_b : std_logic                       := '0';
  signal dcfeb_injpls    : std_logic                       := '0';
  signal dcfeb_extpls    : std_logic                       := '0';
  signal dcfeb_l1a       : std_logic                       := '0';
  signal dcfeb_l1a_match : std_logic_vector(NFEB downto 1);
  signal dcfeb_done      : std_logic_vector(NFEB downto 1) := "0001000";  -- in

-- From/To ODMB_UCSB_V2 JTAG port (through IC34)

  signal v6_tck      : std_logic;
  signal v6_tms      : std_logic;
  signal v6_tdi      : std_logic;
  signal v6_jtag_sel : std_logic;

  signal odmb_tms : std_logic := '0';
  signal odmb_tdi : std_logic := '0';
  signal odmb_tdo : std_logic := '0';

-- From/To J6 (J3) connector to ODMB_CTRL (All signals active low)

  signal ccb_cmd      : std_logic_vector(5 downto 0) := "000000";         -- in
  signal ccb_cmd_s    : std_logic                    := '1';              -- in
  signal ccb_data     : std_logic_vector(7 downto 0) := "00000000";       -- in
  signal ccb_data_s   : std_logic                    := '1';              -- in
  signal ccb_cal      : std_logic_vector(2 downto 0) := (others => '1');  -- in
  signal ccb_crsv     : std_logic_vector(4 downto 0) := "00000";          -- in
  signal ccb_drsv     : std_logic_vector(1 downto 0) := "00";             -- in
  signal ccb_rsvo     : std_logic_vector(4 downto 0) := "00000";          -- in
  signal ccb_rsvi     : std_logic_vector(2 downto 0);  -- out
  signal ccb_bx0_b      : std_logic                    := '1';  -- in
  signal ccb_l1acc_b    : std_logic                    := '1';              -- in
  signal ccb_l1rls    : std_logic;      -- out
  signal ccb_clken    : std_logic                    := '1';              -- in
  --signal ccb_hardrst  : std_logic                    := '1';              -- in
  signal ccb_softrst_b  : std_logic                    := '1';              -- in
  signal ccb_evcntres_b : std_logic                    := '1';
  signal ccb_bxrst_b    : std_logic                    := '1';              -- in
  signal ccb_l1arst_b   : std_logic                    := '1';              -- in


-- From J6/J7 (J3/J4) to FIFOs

  signal otmb      : std_logic_vector(17 downto 0) := (others => '1');  -- in
  signal alct      : std_logic_vector(17 downto 0) := (others => '1');  -- in
  --signal otmbffclk : std_logic                     := '0';  -- in

-- From/To J3/J4 t/fromo ODMB_CTRL

  signal otmbdav   : std_logic                    := '0';      -- in
  signal alctdav   : std_logic                    := '0';      -- in
  signal rsvtd_in  : std_logic_vector(2 downto 0) := "000";  -- in
  signal rsvtd_out : std_logic_vector(2 downto 0);             -- out
  signal lctrqst   : std_logic_vector(2 downto 1);             -- out

-- From/To QPLL (From/To DAQMBV)

  signal qpll_autorestart : std_logic;  -- out
  signal qpll_reset       : std_logic;  -- out
  --signal qpll_f0sel       : std_logic_vector(3 downto 0) := (others => '0');  -- out
  signal qpll_locked      : std_logic                    := '1';  -- in
  signal qpll_error       : std_logic                    := '1';  -- in
  signal qpll_clk40MHz_p  : std_logic                    := '0';  -- in
  signal qpll_clk40MHz_n  : std_logic                    := '1';  -- in
  --signal qpll_clk80MHz_p  : std_logic                    := '0';  -- in
  --signal qpll_clk80MHz_n  : std_logic                    := '1';  -- in
  signal qpll_clk160MHz_p : std_logic                    := '0';  -- in
  signal qpll_clk160MHz_n : std_logic                    := '1';  -- in

-- From/To LVMB (From/To DAQMBV and DAQMBC)

  signal lvmb_pon   : std_logic_vector(7 downto 0);                -- out
  signal pon_load   : std_logic;                                   -- out
  signal pon_en_b   : std_logic;                                   -- out
  signal r_lvmb_pon : std_logic_vector(7 downto 0) := "10101010";  -- in
  signal lvmb_csb   : std_logic_vector(6 downto 0);                -- out
  signal lvmb_sclk  : std_logic;                                   -- out
  signal lvmb_sdin  : std_logic;                                   -- out
  signal lvmb_sdout : std_logic                    := '0';         -- in

-- To LEDs

  signal ledg : std_logic_vector(6 downto 1);
  signal ledr : std_logic_vector(6 downto 1);

-- From Push Buttons

  signal pb : std_logic_vector(1 downto 0) := "11";  -- in. Set to 1, as they'd be unpressed

-- From/To Test Connector for Single-Ended signals

  signal d : std_logic_vector(63 downto 0);

-- From/To Test Points

  signal test_point : std_logic_vector(49 downto 12);

-- From/To RX 

  signal orx_p     : std_logic_vector(12 downto 1) := "000000000000";  -- in
  signal orx_n     : std_logic_vector(12 downto 1) := "111111111111";  -- in
  signal orx_rx_en : std_logic;                                        -- out
  signal orx_en_sd : std_logic;                                        -- out
  signal orx_sd    : std_logic                     := '0';             -- in
  signal orx_sq_en : std_logic;                                        -- out

-- From/To OT1 (GigaBit Link)

  signal gl0_tx_p  : std_logic;         -- out
  signal gl0_tx_n  : std_logic;         -- out
  signal gl0_rx_p  : std_logic := '0';  -- in
  signal gl0_rx_n  : std_logic := '0';  -- in
  signal gl0_clk_p : std_logic := '1';  -- in
  signal gl0_clk_n : std_logic := '0';  -- in

-- From/To OT2 (GigaBit Link)

  signal gl1_tx_p  : std_logic;         -- out
  signal gl1_tx_n  : std_logic;         -- out
  signal gl1_rx_p  : std_logic := '0';  -- in
  signal gl1_rx_n  : std_logic := '0';  -- in
  signal gl1_clk_p : std_logic := '1';  -- in
  signal gl1_clk_n : std_logic := '0';  -- in

  -- Adam Aug 15 To SYSMON
  signal p1v0_sm_p     : std_logic := '0';
  signal p1v0_sm_n     : std_logic := '0';
  signal p2v5_sm_p     : std_logic := '0';
  signal p2v5_sm_n     : std_logic := '0';
  signal lv_p3v3_sm_p  : std_logic := '0';
  signal lv_p3v3_sm_n  : std_logic := '0';
  signal p5v_sm_p      : std_logic := '0';
  signal p5v_sm_n      : std_logic := '0';
  signal p5v_lvmb_sm_p : std_logic := '0';
  signal p5v_lvmb_sm_n : std_logic := '0';
  signal p3v3_pp_sm_p  : std_logic := '0';
  signal p3v3_pp_sm_n  : std_logic := '0';
  signal therm1_p      : std_logic := '0';
  signal therm1_n      : std_logic := '0';
  signal therm2_p      : std_logic := '0';
  signal therm2_n      : std_logic := '0';

-- From/To PROM

  signal prom_addr : std_logic_vector(22 downto 0);
  signal prom_data : std_logic_vector(15 downto 0);
  signal prom_cs_b : std_logic;
  signal prom_oe_b : std_logic;
  signal prom_we_b : std_logic;
  signal prom_le_b : std_logic;

-- Others 

  signal done_in : std_logic := '0';    -- in

  signal LOGIC0 : std_logic := '0';
  signal LOGIC1 : std_logic := '1';

  signal otmb_prbs_tx, otmb_prbs_tx_en, pulse_otmb_prbs_tx_en : std_logic;
  signal otmb_tx                                              : std_logic_vector(48 downto 0);

begin

  go    <= '1' after 15 us;
  --goevent <= '1' after 300 us;
  goccb <= '1' after 29 us;
  goccbcal0 <= '1', '0' after 45 us, '1' after 45.025 us;

  ccb_cal_tb <= goccbcal0 & "11";
  
  qpll_clk40MHz_p  <= not qpll_clk40MHz_p  after 12.5 ns;
  qpll_clk40MHz_n  <= not qpll_clk40MHz_n  after 12.5 ns;
  --qpll_clk80MHz_p  <= not qpll_clk80MHz_p  after 6.25 ns;
  --qpll_clk80MHz_n  <= not qpll_clk80MHz_n  after 6.25 ns;
  qpll_clk160MHz_p <= not qpll_clk160MHz_p after 3.125 ns;
  qpll_clk160MHz_n <= not qpll_clk160MHz_n after 3.125 ns;
  gl1_clk_p        <= not gl1_clk_p        after 4 ns;
  gl1_clk_n        <= not gl1_clk_n        after 4 ns;
  gl0_clk_p        <= not gl0_clk_p        after 6.25 ns;
  gl0_clk_n        <= not gl0_clk_n        after 6.25 ns;
  clk              <= not clk              after 12.5 ns;

  --orx_p(1) <= gl0_tx_p;  -- Test of the DDU TX
  --orx_n(1) <= gl0_tx_n;  -- Test of the DDU TX

  orx_p(1) <= gl1_tx_p;                 -- Test of the PC TX
  orx_n(1) <= gl1_tx_n;                 -- Test of the PC TX

  orx_p(2) <= gl0_tx_p;                 -- Test of the DCFEB RX
  orx_n(2) <= gl0_tx_n;                 -- Test of the DCFEB RX
  orx_p(3) <= gl1_tx_p;                 -- Test of the DCFEB RX
  orx_n(3) <= gl1_tx_n;                 -- Test of the DCFEB RX
  orx_p(4) <= gl1_tx_p;                 -- Test of the DCFEB RX
  orx_n(4) <= gl1_tx_n;                 -- Test of the DCFEB RX
  orx_p(5) <= gl1_tx_p;                 -- Test of the DCFEB RX
  orx_n(5) <= gl1_tx_n;                 -- Test of the DCFEB RX
  orx_p(6) <= gl1_tx_p;                 -- Test of the DCFEB RX
  orx_n(6) <= gl1_tx_n;                 -- Test of the DCFEB RX
  orx_p(7) <= gl1_tx_p;                 -- Test of the DCFEB RX
  orx_n(7) <= gl1_tx_n;                 -- Test of the DCFEB RX

  rst <= '0', '1' after 200 ns, '0' after 3000 ns;
  dcfeb_done(1) <= '0', '1' after 13500 ns;
  dcfeb_done(2) <= '0', '1' after 30500 ns;
  
  rstn <= not rst;

  stop <= '0';

  dtack <= 'H';

-- Beginning of the Test Bench Section

-- End of the Test Bench Section

  odmb_ucsb_v2_TOP : odmb_ucsb_v2
    generic map(
      IS_SIMULATION => 1,
      NFEB          => 7)
    port map(

      tc_run_out => goevent,

-- BPI Prom signals To/From bpi_interface

      prom_a        => prom_addr,
      prom_a_21_rs0 => open,            -- not connected in v.2
      prom_a_22_rs1 => open,            -- not connected in v.2
      prom_d        => prom_data,
      prom_cs_b     => prom_cs_b,
      prom_oe_b     => prom_oe_b,
      prom_we_b     => prom_we_b,
      prom_le_b     => prom_le_b,

-- From/To VME connector To/From MBV

      vme_data        => vme_data(15 downto 0),  -- inout
      vme_addr        => adr(23 downto 1),       -- in
      vme_am          => am(5 downto 0),         -- in
      vme_gap         => ga(5),         -- in
      vme_ga          => ga(4 downto 0),         -- in
      --vme_bg0         => LOGIC0,        -- in
      --vme_bg1         => LOGIC0,        -- in
      --vme_bg2         => LOGIC0,        -- in
      --vme_bg3         => LOGIC0,        -- in
      vme_as_b        => as,  -- in                                               
      vme_ds_b        => ds,            -- in
      --vme_sysreset_b  => LOGIC1,        -- in ???
      vme_sysfail_b   => sysfail,
      vme_sysfail_out => sysfail_out,   -- out
      vme_berr_b      => berr,          -- in
      vme_berr_out    => berr_out,      -- out
      vme_iack_b      => iack,          -- in
      vme_lword_b     => lword,         -- in
      vme_write_b     => write_b,       -- in
      --vme_clk         => LOGIC0,        -- in ???
      vme_dtack_v6_b  => dtack,         -- inout
      vme_tovme       => tovme,         -- out
      vme_doe_b       => doe_b,         -- out

-- From/To PPIB (connectors J3 and J4)

      dcfeb_tck       => dcfeb_tck,
      dcfeb_tms       => dcfeb_tms,
      dcfeb_tdi       => dcfeb_tdi,
      dcfeb_tdo       => dcfeb_tdo,
      dcfeb_bc0       => dcfeb_bc0,
      dcfeb_resync    => dcfeb_resync,
      odmb_hardrst_b  => odmb_hardrst_b,  -- Generater REPROG_B
      dcfeb_reprgen_b => dcfeb_reprgen_b,
      dcfeb_injpls    => dcfeb_injpls,
      dcfeb_extpls    => dcfeb_extpls,
      dcfeb_l1a       => dcfeb_l1a,
      dcfeb_l1a_match => dcfeb_l1a_match,
      dcfeb_done      => dcfeb_done,

-- From/To ODMB_UCSB_V2 JTAG port (through IC34)

      v6_tck      => v6_tck,
      v6_tms      => v6_tms,
      v6_tdi      => v6_tdi,
      v6_jtag_sel => v6_jtag_sel,

      --odmb_tms => odmb_tms,
      --odmb_tdi => odmb_tdi,
      odmb_tdo => odmb_tdo,

-- From/To J6 (J3) connector to ODMB_CTRL

      ccb_cmd     => ccb_cmd,           -- in - from file_handler_ccb
      ccb_cmd_s   => ccb_cmd_s,         -- in - from file_handler_ccb
      ccb_data    => ccb_data,          -- in - from file_handler_ccb
      ccb_data_s  => ccb_data_s,        -- in - from file_handler_ccb
      ccb_cal     => ccb_cal_tb,           -- in - from file_handler_ccb
      ccb_crsv    => ccb_crsv,          -- in
      ccb_drsv    => ccb_drsv,          -- in
      ccb_rsvo    => ccb_rsvo,          -- in
      ccb_rsvi    => ccb_rsvi,          -- in
      ccb_bx0_b     => ccb_bx0_b,           -- in
      ccb_bxrst_b   => ccb_bxrst_b,         -- in
      ccb_l1arst_b  => ccb_l1arst_b,        -- in
--              ccb_l1acc => ccb_l1acc, -- in
      ccb_l1acc_b   => l1a_b,             -- from file_handler_event
      ccb_l1rls   => ccb_l1rls,         -- out
      ccb_clken   => ccb_clken,         -- in
      --ccb_hardrst => ccb_hardrst,       -- in           
      ccb_softrst_b => ccb_softrst_b,       -- in

-- From J6/J7 (J3/J4) to FIFOs

      otmb      => otmb,                -- in
      alct      => alct,                -- in
      rawlct    => lct,                 -- from file_handler_event
      --otmbffclk => otmbffclk,           -- in

-- From/To J3/J4 t/fromo ODMB_CTRL

      otmbdav   => otmb_dav,            -- from file_handler_event
      alctdav   => alct_dav,            -- from file_handler_event
--              rsvtd : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);                     
      rsvtd_in  => rsvtd_in,            -- in
      rsvtd_out => rsvtd_out,           -- out
      lctrqst   => lctrqst,             -- out


-- From/To QPLL (From/To DAQMBV)

      qpll_autorestart => qpll_autorestart,  -- out
      qpll_reset       => qpll_reset,        -- out
      --qpll_f0sel       => qpll_f0sel,        -- out
      qpll_locked      => qpll_locked,       -- in
      qpll_error       => qpll_error,        -- in

      qpll_clk40MHz_p  => qpll_clk40MHz_p,   -- in 
      qpll_clk40MHz_n  => qpll_clk40MHz_n,   -- in 
      --qpll_clk80MHz_p  => qpll_clk80MHz_p,   -- in 
      --qpll_clk80MHz_n  => qpll_clk80MHz_n,   -- in 
      qpll_clk160MHz_p => qpll_clk160MHz_p,  -- NEW!
      qpll_clk160MHz_n => qpll_clk160MHz_n,  -- NEW!

-- From/To LVMB (From/To DAQMBV and DAQMBC)

      lvmb_pon   => lvmb_pon,           -- out
      pon_load   => pon_load,           -- out
      pon_en_b   => pon_en_b,           -- out
      r_lvmb_pon => r_lvmb_pon,         -- in
      lvmb_csb   => lvmb_csb,           -- out
      lvmb_sclk  => lvmb_sclk,          -- out
      lvmb_sdin  => lvmb_sdin,          -- out
      lvmb_sdout => lvmb_sdout,         -- out

-- To LEDs

      ledg => ledg,                     -- out
      ledr => ledr,                     -- out

-- From Push Buttons

      pb => pb,                         -- in

-- From/To Test Connector for Single-Ended signals

      d => d,                           -- out              

-- From/To Test Points

      test_point => test_point,

-- From/To RX 

      orx_p     => orx_p,               -- in
      orx_n     => orx_n,               -- in
      orx_rx_en => orx_rx_en,
      orx_en_sd => orx_en_sd,
      orx_sd    => orx_sd,
      orx_sq_en => orx_sq_en,

-- From/To OT1 (GigaBit Link)

      gl0_tx_p  => gl0_tx_p,            -- out
      gl0_tx_n  => gl0_tx_n,            -- out
      gl0_rx_p  => gl0_tx_p,            -- in
      gl0_rx_n  => gl0_tx_n,            -- in
      --gl0_rx_p  => gl0_rx_p,            -- in
      --gl0_rx_n  => gl0_rx_n,            -- in
      gl0_clk_p => gl0_clk_p,           -- in
      gl0_clk_n => gl0_clk_n,           -- in

-- From/To OT2 (GigaBit Link)

      gl1_tx_p  => gl1_tx_p,            -- out
      gl1_tx_n  => gl1_tx_n,            -- out
      gl1_rx_p  => gl1_tx_p,            -- in : Loop test in simulation
      gl1_rx_n  => gl1_tx_n,            -- in : Loop test in simulation
      gl1_clk_p => gl1_clk_p,
      gl1_clk_n => gl1_clk_n,


      done_in      => done_in,
      ccb_evcntres_b => ccb_evcntres_b,

      -- Adam Aug 15 To SYSMON
      p1v0_sm_p     => p1v0_sm_p,
      p1v0_sm_n     => p1v0_sm_n,
      p2v5_sm_p     => p2v5_sm_p,
      p2v5_sm_n     => p2v5_sm_n,
      lv_p3v3_sm_p  => lv_p3v3_sm_p,
      lv_p3v3_sm_n  => lv_p3v3_sm_n,
      p5v_sm_p      => p5v_sm_p,
      p5v_sm_n      => p5v_sm_n,
      p5v_lvmb_sm_p => p5v_lvmb_sm_p,
      p5v_lvmb_sm_n => p5v_lvmb_sm_n,
      p3v3_pp_sm_p  => p3v3_pp_sm_p,
      p3v3_pp_sm_n  => p3v3_pp_sm_n,
      therm1_p      => therm1_p,
      therm1_n      => therm1_n,
      therm2_p      => therm2_p,
      therm2_n      => therm2_n,

      otmb_tx_tb => otmb_tx
      );

  PMAP_file_handler_event : file_handler_event

    port map(

      clk      => clk,
      en       => goevent,
      l1a      => l1a,
      alct_dav => alct_dav,
      otmb_dav => otmb_dav,
      lct      => lct
      );

  PMAP_file_handler_ccb : file_handler_ccb

    port map(

      clk        => clk,
      en         => goccb,
      ccb_cmd_s  => ccb_cmd_s,
      ccb_cmd    => ccb_cmd,
      ccb_data_s => ccb_data_s,
      ccb_data   => ccb_data,
      ccb_cal    => ccb_cal
      );

  l1a_b <= not l1a;

  PMAP_file_handler : file_handler

    port map(

      clk             => clk,
      start           => start,
      vme_cmd_reg     => vme_cmd_reg,
      vme_dat_reg_in  => vme_dat_reg_in,
      vme_dat_reg_out => vme_dat_mem_in,
      vme_cmd_rd      => vme_mem_rden,
      vme_dat_wr      => vme_dat_mem_wren
      );

  vme_cmd_mem_out <= vme_cmd_reg;
  vme_dat_mem_out <= vme_dat_reg_in;

  PMAP_test_controller : test_controller

    port map(

      clk       => clk,
      rstn      => rstn,
      sw_reset  => rst,
      tc_enable => go,

      -- From/To SLV_MGT Module

      start     => start,
      start_res => start_res,
      stop      => stop,
      stop_res  => stop_res,
      mode      => mode,
      cmd_n     => cmd_n,
      busy      => busy,

      vme_cmd_reg     => vme_cmd_reg,
      vme_dat_reg_in  => vme_dat_reg_in,
      vme_dat_reg_out => vme_dat_reg_out,

-- To/From VME Master

      vme_cmd    => vme_cmd,
      vme_cmd_rd => vme_cmd_rd,

      vme_addr    => vme_addr,
      vme_wr      => vme_wr,
      vme_wr_data => vme_wr_data,
      vme_rd      => vme_rd,
      vme_rd_data => vme_rd_data,

-- From/To VME_CMD Memory and VME_DAT Memory

      vme_mem_addr     => vme_mem_addr,
      vme_mem_rden     => vme_mem_rden,
      vme_cmd_mem_out  => vme_cmd_mem_out,
      vme_dat_mem_out  => vme_dat_mem_out,
      vme_dat_mem_wren => vme_dat_mem_wren,
      vme_dat_mem_in   => vme_dat_mem_in

      );

  PMAP_prom : prom
    port map (

      clk => clk,
      rst => rst,

      we_b => prom_we_b,
      cs_b => prom_cs_b,
      oe_b => prom_oe_b,
      le_b => prom_le_b,

      addr => prom_addr,
      data => prom_data);


  PMAP_VME_Master : vme_master
    port map (

      clk      => clk,
      rstn     => rstn,
      sw_reset => rst,

      vme_cmd     => vme_cmd,
      vme_cmd_rd  => vme_cmd_rd,
      vme_wr      => vme_cmd,
      vme_addr    => vme_addr,
      vme_wr_data => vme_wr_data,
      vme_rd      => vme_rd,
      vme_rd_data => vme_rd_data,

      ga   => ga,
      addr => adr,
      am   => am,

      as      => as,
      ds0     => ds(0),
      ds1     => ds(1),
      lword   => lword,
      write_b => write_b,
      iack    => iack,
      berr    => berr,
      sysfail => sysfail,
      dtack   => dtack,

      oe_b     => oe_b,
      data_in  => outdata,
      data_out => indata

      );

  vme_d00_buf : IOBUF port map (O => outdata(0), IO => vme_data(0), I => indata(0), T => oe_b);
  vme_d01_buf : IOBUF port map (O => outdata(1), IO => vme_data(1), I => indata(1), T => oe_b);
  vme_d02_buf : IOBUF port map (O => outdata(2), IO => vme_data(2), I => indata(2), T => oe_b);
  vme_d03_buf : IOBUF port map (O => outdata(3), IO => vme_data(3), I => indata(3), T => oe_b);
  vme_d04_buf : IOBUF port map (O => outdata(4), IO => vme_data(4), I => indata(4), T => oe_b);
  vme_d05_buf : IOBUF port map (O => outdata(5), IO => vme_data(5), I => indata(5), T => oe_b);
  vme_d06_buf : IOBUF port map (O => outdata(6), IO => vme_data(6), I => indata(6), T => oe_b);
  vme_d07_buf : IOBUF port map (O => outdata(7), IO => vme_data(7), I => indata(7), T => oe_b);
  vme_d08_buf : IOBUF port map (O => outdata(8), IO => vme_data(8), I => indata(8), T => oe_b);
  vme_d09_buf : IOBUF port map (O => outdata(9), IO => vme_data(9), I => indata(9), T => oe_b);
  vme_d10_buf : IOBUF port map (O => outdata(10), IO => vme_data(10), I => indata(10), T => oe_b);
  vme_d11_buf : IOBUF port map (O => outdata(11), IO => vme_data(11), I => indata(11), T => oe_b);
  vme_d12_buf : IOBUF port map (O => outdata(12), IO => vme_data(12), I => indata(12), T => oe_b);
  vme_d13_buf : IOBUF port map (O => outdata(13), IO => vme_data(13), I => indata(13), T => oe_b);
  vme_d14_buf : IOBUF port map (O => outdata(14), IO => vme_data(14), I => indata(14), T => oe_b);
  vme_d15_buf : IOBUF port map (O => outdata(15), IO => vme_data(15), I => indata(15), T => oe_b);

  PMAP_pon_reg : pon_reg
    port map (
      pon_en   => pon_en_b,
      pon_load => pon_load,
      pon_in   => lvmb_pon,
      pon_out  => r_lvmb_pon);

  error <= '0';

-- PRBS tests
  otmb_prbs_tx_en <= '0', '1' after 30000 ns;
  PE_OTMB_PRBS_TX_EN : PULSE_EDGE port map(pulse_otmb_prbs_tx_en, open, clk, rst, 1024, otmb_prbs_tx_en);

  PRBS_GEN_PM : PRBS_GEN port map(otmb_prbs_tx, clk, rst, pulse_otmb_prbs_tx_en);
  otmb_tx <= (48 => pulse_otmb_prbs_tx_en, others => otmb_prbs_tx);

end ODMB_UCSB_V2_TB_arch;
