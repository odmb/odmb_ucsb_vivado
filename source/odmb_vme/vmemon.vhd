-- VMEMON: Sends out FLFCTRL with monitoring values

library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;

entity VMEMON is
  generic (
    NFEB : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 in the final design
    );    
  port (

    SLOWCLK : in std_logic;
    CLK40   : in std_logic;
    RST     : in std_logic;

    DEVICE  : in std_logic;
    STROBE  : in std_logic;
    COMMAND : in std_logic_vector(9 downto 0);
    WRITER  : in std_logic;

    INDATA  : in  std_logic_vector(15 downto 0);
    OUTDATA : out std_logic_vector(15 downto 0);

    DTACK : out std_logic;

    DCFEB_DONE  : in std_logic_vector(NFEB downto 1);
    QPLL_LOCKED : in std_logic;

    OPT_RESET_PULSE : out std_logic;
    L1A_RESET_PULSE : out std_logic;
    FW_RESET        : out std_logic;
    REPROG_B        : out std_logic;
    TEST_INJ        : out std_logic;
    TEST_PLS        : out std_logic;
    TEST_PED        : out std_logic;
    TEST_LCT        : out std_logic;
    TEST_BC0        : out std_logic;
    OTMB_LCT_RQST   : out std_logic;
    OTMB_EXT_TRIG   : out std_logic;

    MASK_L1A      : out std_logic_vector(NFEB downto 0);
    MASK_PLS      : out std_logic;
    MAX_WORDS_DCFEB : out std_logic_vector(15 downto 0);
    TP_SEL        : out std_logic_vector(15 downto 0);
    ODMB_CTRL     : out std_logic_vector(15 downto 0);
    ODMB_DATA_SEL : out std_logic_vector(7 downto 0);
    ODMB_DATA     : in  std_logic_vector(15 downto 0);
    TXDIFFCTRL    : out std_logic_vector(3 downto 0);  -- Controls the TX voltage swing
    LOOPBACK      : out std_logic_vector(2 downto 0)  -- For internal loopback tests

    );
end VMEMON;


architecture VMEMON_Arch of VMEMON is

  signal dd_dtack, d_dtack, q_dtack : std_logic;
  signal cmddev : std_logic_vector (15 downto 0);

  signal busy        : std_logic;
  signal r_odmb_data : std_logic;

  signal odmb_ctrl_inner : std_logic_vector(15 downto 0) := (others => '0');

  signal out_tp_sel, tp_sel_inner : std_logic_vector(15 downto 0) := (others => '0');
  signal w_tp_sel                 : std_logic                     := '0';
  signal r_tp_sel                 : std_logic                     := '0';

  signal out_max_words_dcfeb, max_words_dcfeb_inner : std_logic_vector(15 downto 0) := (others => '0');
  signal w_max_words_dcfeb                 : std_logic                     := '0';
  signal r_max_words_dcfeb                 : std_logic                     := '0';

  signal odmb_rst               : std_logic_vector(15 downto 0) := (others => '0');
  signal resync_rst, reprog_rst : std_logic                     := '0';
  signal opt_reset_pulse_rst    : std_logic                     := '0';
  signal reprog                 : std_logic                     := '0';
  signal reset_rst              : std_logic                     := '0';

  signal out_loopback   : std_logic_vector(15 downto 0) := (others => '0');
  signal loopback_inner : std_logic_vector(2 downto 0);
  signal w_loopback     : std_logic                     := '0';
  signal r_loopback     : std_logic                     := '0';

  signal out_txdiffctrl   : std_logic_vector(15 downto 0) := (others => '0');
  signal txdiffctrl_inner : std_logic_vector(3 downto 0);
  signal w_txdiffctrl     : std_logic                     := '0';
  signal r_txdiffctrl     : std_logic                     := '0';

  signal out_dcfeb_done : std_logic_vector(15 downto 0) := (others => '0');
  signal r_dcfeb_done   : std_logic                     := '0';

  signal out_qpll_locked : std_logic_vector(15 downto 0) := (others => '0');
  signal r_qpll_locked   : std_logic                     := '0';

  signal raw_odmb_ctrl_inner, odmb_ctrl_en : std_logic_vector(15 downto 0) := (others => '0');

  signal out_odmb_cal           : std_logic_vector(15 downto 0) := (others => '0');
  signal w_odmb_cal, r_odmb_cal : std_logic                     := '0';

  signal w_odmb_rst : std_logic := '0';

  signal out_mux_data_path                : std_logic_vector(15 downto 0) := (others => '0');
  signal w_mux_data_path, r_mux_data_path : std_logic                     := '0';

  signal out_mux_lvmb           : std_logic_vector(15 downto 0) := (others => '0');
  signal w_mux_lvmb, r_mux_lvmb : std_logic                     := '0';

  signal out_mux_trigger              : std_logic_vector(15 downto 0) := (others => '0');
  signal w_mux_trigger, r_mux_trigger : std_logic                     := '0';

  signal out_mask_l1a           : std_logic_vector(15 downto 0)   := (others => '0');
  signal mask_l1a_inner         : std_logic_vector(NFEB downto 0) := (others => '0');
  signal w_mask_l1a, r_mask_l1a : std_logic                       := '0';

  signal out_mask_pls           : std_logic_vector(15 downto 0)   := (others => '0');
  signal mask_pls_inner         : std_logic := '0';
  signal w_mask_pls, r_mask_pls : std_logic                       := '0';

  signal out_odmb_ped           : std_logic_vector(15 downto 0) := (others => '0');
  signal w_odmb_ped, r_odmb_ped : std_logic                     := '0';

  signal out_cal_ped                          : std_logic_vector(15 downto 0) := (others => '0');
  signal w_cal_ped, r_cal_ped, test_ped_inner : std_logic                     := '0';

  signal w_dcfeb_pulse : std_logic                    := '0';
  signal dcfeb_pulse   : std_logic_vector(5 downto 0) := (others => '0');


  signal w_dcfeb_reprog : std_logic := '0';
  signal w_dcfeb_resync : std_logic := '0';
  signal w_opt_rst      : std_logic := '0';

begin

-- CMDDEV: Variable that looks like the VME commands we input
  cmddev <= "000" & DEVICE & COMMAND & "00";

  w_odmb_cal <= '1' when (CMDDEV = x"1000" and WRITER = '0') else '0';
  r_odmb_cal <= '1' when (CMDDEV = x"1000" and WRITER = '1') else '0';

  w_odmb_rst     <= '1' when (CMDDEV = x"1004" and WRITER = '0' and STROBE = '1') else '0';
  w_opt_rst      <= '1' when (CMDDEV = x"1008" and WRITER = '0' and STROBE = '1') else '0';
  w_dcfeb_reprog <= '1' when (CMDDEV = x"1010" and WRITER = '0' and STROBE = '1') else '0';
  w_dcfeb_resync <= '1' when (CMDDEV = x"1014" and WRITER = '0' and STROBE = '1') else '0';

  w_tp_sel <= '1' when (CMDDEV = x"1020" and WRITER = '0') else '0';
  r_tp_sel <= '1' when (CMDDEV = x"1020" and WRITER = '1') else '0';
  w_max_words_dcfeb <= '1' when (CMDDEV = x"1024" and WRITER = '0') else '0';
  r_max_words_dcfeb <= '1' when (CMDDEV = x"1024" and WRITER = '1') else '0';

  w_loopback    <= '1' when (CMDDEV = x"1100" and WRITER = '0') else '0';
  r_loopback    <= '1' when (CMDDEV = x"1100" and WRITER = '1') else '0';
  w_txdiffctrl  <= '1' when (CMDDEV = x"1110" and WRITER = '0') else '0';
  r_txdiffctrl  <= '1' when (CMDDEV = x"1110" and WRITER = '1') else '0';
  r_dcfeb_done  <= '1' when (CMDDEV = x"1120" and WRITER = '1') else '0';
  r_qpll_locked <= '1' when (CMDDEV = x"1124" and WRITER = '1') else '0';

  w_dcfeb_pulse <= '1' when (CMDDEV = x"1200" and WRITER = '0') else '0';

  w_mux_data_path <= '1' when (CMDDEV = x"1300" and WRITER = '0') else '0';
  r_mux_data_path <= '1' when (CMDDEV = x"1300" and WRITER = '1') else '0';
  w_mux_trigger   <= '1' when (CMDDEV = x"1304" and WRITER = '0') else '0';
  r_mux_trigger   <= '1' when (CMDDEV = x"1304" and WRITER = '1') else '0';
  w_mux_lvmb      <= '1' when (CMDDEV = x"1308" and WRITER = '0') else '0';
  r_mux_lvmb      <= '1' when (CMDDEV = x"1308" and WRITER = '1') else '0';

  w_odmb_ped <= '1' when (CMDDEV = x"1400" and WRITER = '0') else '0';
  r_odmb_ped <= '1' when (CMDDEV = x"1400" and WRITER = '1') else '0';
  w_cal_ped  <= '1' when (CMDDEV = x"1404" and WRITER = '0') else '0';
  r_cal_ped  <= '1' when (CMDDEV = x"1404" and WRITER = '1') else '0';
  w_mask_l1a <= '1' when (CMDDEV = x"1408" and WRITER = '0') else '0';
  r_mask_l1a <= '1' when (CMDDEV = x"1408" and WRITER = '1') else '0';
  w_mask_pls <= '1' when (CMDDEV = x"140C" and WRITER = '0') else '0';
  r_mask_pls <= '1' when (CMDDEV = x"140C" and WRITER = '1') else '0';

  r_odmb_data               <= '1' when (CMDDEV(12) = '1' and CMDDEV(3 downto 0) = x"C") else '0';
  odmb_data_sel(7 downto 0) <= COMMAND(9 downto 2);

-- Resets
  PLS_FWRESET  : PULSE2FAST port map(FW_RESET, clk40, RST, w_odmb_rst);
  PLS_OPTRESET : PULSE2FAST port map(OPT_RESET_PULSE, clk40, RST, w_opt_rst);
  PLS_L1ARESET : PULSE2FAST port map(L1A_RESET_PULSE, clk40, RST, w_dcfeb_resync);
  PLS_REPROG   : NPULSE2SAME port map(reprog, slowclk, RST, 2, w_dcfeb_reprog);
  REPROG_B <= not reprog;

  odmb_rst <= (8 => reset_rst, others => RST);

  raw_odmb_ctrl_inner(5 downto 0)   <= INDATA(5 downto 0);
  raw_odmb_ctrl_inner(6)            <= INDATA(0);
  raw_odmb_ctrl_inner(7)            <= INDATA(0);
  raw_odmb_ctrl_inner(8)            <= INDATA(0);
  raw_odmb_ctrl_inner(9)            <= INDATA(0);
  raw_odmb_ctrl_inner(10)           <= INDATA(0);
  raw_odmb_ctrl_inner(12 downto 11) <= INDATA(1 downto 0);
  raw_odmb_ctrl_inner(14 downto 13) <= INDATA(1 downto 0);
  raw_odmb_ctrl_inner(15)           <= '0';
  odmb_ctrl_en(5 downto 0)          <= (others => w_odmb_cal);
  odmb_ctrl_en(6)                   <= '0';
  odmb_ctrl_en(7)                   <= w_mux_data_path;
  odmb_ctrl_en(8)                   <= w_odmb_rst;
  odmb_ctrl_en(9)                   <= w_mux_trigger;
  odmb_ctrl_en(10)                  <= w_mux_lvmb;
  odmb_ctrl_en(12 downto 11)        <= (others => w_mask_l1a);
  odmb_ctrl_en(14 downto 13)        <= (others => w_odmb_ped);
  odmb_ctrl_en(15)                  <= '0';

  FD_CALPED : FDCE port map(test_ped_inner, STROBE, w_cal_ped, RST, INDATA(0));
  test_ped <= test_ped_inner;

  GEN_ODMB_CTRL : for K in 0 to 15 generate
  begin
    ODMB_CTRL_K : FDCE port map (odmb_ctrl_inner(K), STROBE, odmb_ctrl_en(k),
                                 odmb_rst(K), raw_odmb_ctrl_inner(K));
  end generate GEN_ODMB_CTRL;
  ODMB_CTRL <= odmb_ctrl_inner;

-- DCFEB pulses  
  GEN_dcfeb_pulse : for K in 0 to 5 generate
  begin
    dcfeb_pulse(K) <= w_dcfeb_pulse and STROBE and INDATA(K);
  end generate GEN_dcfeb_pulse;
  PULSE_INJ : NPULSE2SAME port map(test_inj, slowclk, rst, 2, dcfeb_pulse(0));
  PULSE_PLS : NPULSE2SAME port map(test_pls, slowclk, rst, 2, dcfeb_pulse(1));
  PULSE_L1A : PULSE2FAST port map(test_lct, clk40, rst, dcfeb_pulse(2));
  PULSE_LCT : PULSE2FAST port map(otmb_lct_rqst, clk40, rst, dcfeb_pulse(3));
  PULSE_EXT : PULSE2FAST port map(otmb_ext_trig, clk40, rst, dcfeb_pulse(4));
  PULSE_BC0 : PULSE2FAST port map(test_bc0, clk40, rst, dcfeb_pulse(5));

-- Write MASK_PLS
  FD_W_MASK_PLS : FDCE port map(MASK_PLS_INNER, STROBE, W_MASK_PLS, RST, INDATA(0));
  MASK_PLS <= MASK_PLS_INNER;

-- Read MASK_PLS
  OUT_MASK_PLS(15 downto 0) <= x"000" & "000" & MASK_PLS_INNER when R_MASK_PLS = '1'
                               else (others => 'Z');

-- Write MASK_L1A
  GEN_MASK_L1A : for I in NFEB downto 0 generate
  begin
    FD_W_MASK_L1A : FDCE port map(MASK_L1A_INNER(I), STROBE, W_MASK_L1A, RST, INDATA(I));
  end generate GEN_MASK_L1A;
  MASK_L1A <= MASK_L1A_INNER;

-- Read MASK_L1A
  OUT_MASK_L1A(15 downto 0) <= x"00" & MASK_L1A_INNER when R_MASK_L1A = '1'
                               else (others => 'Z');

-- Write TP_SEL
  GEN_TP_SEL : for I in 15 downto 0 generate
  begin
    FD_W_TP_SEL : FDCE port map(TP_SEL_INNER(I), STROBE, W_TP_SEL, RST, INDATA(I));
  end generate GEN_TP_SEL;
  TP_SEL <= TP_SEL_INNER;

-- Read TP_SEL
  OUT_TP_SEL(15 downto 0) <= TP_SEL_INNER when R_TP_SEL = '1'
                             else (others => 'Z');

-- Write MAX_WORDS_DCFEB. At reset it goes to 2^10 = 1024
  GEN_MAX_WORDS_DCFEB : for I in 9 downto 0 generate
  begin
    FD_W_MAX_WORDS_DCFEB0 : FDCE port map(MAX_WORDS_DCFEB_INNER(I), STROBE, W_MAX_WORDS_DCFEB, RST, INDATA(I));
  end generate GEN_MAX_WORDS_DCFEB;
  
  GEN_MAX_WORDS_DCFEB11 : for I in 15 downto 11 generate
  begin
    FD_W_MAX_WORDS_DCFEB11 : FDCE port map(MAX_WORDS_DCFEB_INNER(I), STROBE, W_MAX_WORDS_DCFEB, RST, INDATA(I));
  end generate GEN_MAX_WORDS_DCFEB11;
  
  FD_W_MAX_WORDS_DCFEB10 : FDPE port map(Q => MAX_WORDS_DCFEB_INNER(10), C => STROBE, CE => W_MAX_WORDS_DCFEB,
                                         PRE => RST, D => INDATA(10));
  MAX_WORDS_DCFEB <= MAX_WORDS_DCFEB_INNER;

-- Read MAX_WORDS_DCFEB
  OUT_MAX_WORDS_DCFEB(15 downto 0) <= MAX_WORDS_DCFEB_INNER when R_MAX_WORDS_DCFEB = '1'
                             else (others => 'Z');

-- Write LOOPBACK
  GEN_LOOPBACK : for I in 2 downto 0 generate
  begin
    FD_W_LOOPBACK : FDCE port map(loopback_inner(I), STROBE, w_loopback,
                                  RST, INDATA(I));
  end generate GEN_LOOPBACK;
  LOOPBACK <= loopback_inner;

-- Read LOOPBACK
  out_loopback <= x"000" & '0' & loopback_inner when r_loopback = '1'
                  else (others => 'Z');

-- Write TXDIFFCTRL
  --GEN_TXDIFFCTRL : for I in 3 downto 0 generate
  --begin
  --  FD_W_TXDIFFCTRL : FDCE port map(txdiffctrl_inner(I), STROBE, w_txdiffctrl,
  --                                  RST, INDATA(I));
  --end generate GEN_TXDIFFCTRL;
  txdiffctrl_inner <= x"8";
  TXDIFFCTRL <= txdiffctrl_inner;

-- Reads
  out_odmb_cal      <= "00" & x"00" & odmb_ctrl_inner(5 downto 0);
  out_mux_data_path <= "000" & x"000" & odmb_ctrl_inner(7);
  out_mux_trigger   <= "000" & x"000" & odmb_ctrl_inner(9);
  out_mux_lvmb      <= "000" & x"000" & odmb_ctrl_inner(10);
  out_odmb_ped      <= "00" & x"000" & odmb_ctrl_inner(14 downto 13);
  out_cal_ped       <= "000" & x"000" & test_ped_inner;
  out_txdiffctrl    <= x"000" & txdiffctrl_inner;
  out_dcfeb_done    <= x"00" & '0' & dcfeb_done;
  out_qpll_locked   <= x"000" & "000" & qpll_locked;

  OUTDATA <= out_odmb_cal when (r_odmb_cal = '1') else
             out_mux_data_path when (r_mux_data_path = '1') else
             out_mux_trigger   when (r_mux_trigger = '1') else
             out_mux_lvmb      when (r_mux_lvmb = '1') else
             out_mask_pls      when (r_mask_pls = '1') else
             out_mask_l1a      when (r_mask_l1a = '1') else
             out_odmb_ped      when (r_odmb_ped = '1') else
             out_cal_ped       when (r_cal_ped = '1') else
             out_tp_sel        when (r_tp_sel = '1') else
             out_max_words_dcfeb        when (r_max_words_dcfeb = '1') else
             out_loopback      when (r_loopback = '1') else
             out_txdiffctrl    when (r_txdiffctrl = '1') else
             out_dcfeb_done    when (r_dcfeb_done = '1') else
             out_qpll_locked   when (r_qpll_locked = '1') else
             odmb_data         when (r_odmb_data = '1') else
             (others => 'L');

  -- DTACK
  dd_dtack <= STROBE and DEVICE;
  FD_D_DTACK : FDC port map(d_dtack, dd_dtack, q_dtack, '1');
  FD_Q_DTACK : FD port map(q_dtack, SLOWCLK, d_dtack);
  DTACK    <= q_dtack;
  
end VMEMON_Arch;
