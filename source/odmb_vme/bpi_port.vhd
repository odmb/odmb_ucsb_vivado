-- BPI_PORT: Controls via VME the BPI engine that writes FW and registers to the PROM

library ieee;
library work;
library unisim;
library hdlmacro;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;
use hdlmacro.hdlmacro.all;

entity BPI_PORT is
  port (
    CSP_BPI_PORT_LA_CTRL : inout std_logic_vector(35 downto 0);

    SLOWCLK : in std_logic;
    CLK     : in std_logic;             -- 40 MHz
    RST     : in std_logic;

    DEVICE  : in std_logic;
    STROBE  : in std_logic;
    COMMAND : in std_logic_vector(9 downto 0);
    WRITE_B : in std_logic;

    INDATA  : in  std_logic_vector(15 downto 0);
    OUTDATA : out std_logic_vector(15 downto 0);

    DTACK : out std_logic;

    -- BPI controls
    BPI_RST           : out std_logic;
    BPI_CMD_FIFO_DATA : out std_logic_vector(15 downto 0);
    BPI_WE            : out std_logic;
    BPI_RE            : out std_logic;
    BPI_DSBL          : out std_logic;
    BPI_ENBL          : out std_logic;
    BPI_CFG_DL        : out std_logic;
    BPI_CFG_UL        : out std_logic;
    BPI_CONST_DL      : out std_logic;
    BPI_CONST_UL      : out std_logic;

    BPI_RBK_FIFO_DATA  : in  std_logic_vector(15 downto 0);
    BPI_RBK_WRD_CNT    : in  std_logic_vector(10 downto 0);
    BPI_STATUS         : in  std_logic_vector(15 downto 0);
    BPI_TIMER          : in  std_logic_vector(31 downto 0);
    BPI_CFG_UL_PULSE   : out std_logic;
    BPI_CFG_DL_PULSE   : out std_logic;
    BPI_CFG_BUSY       : in  std_logic;
    BPI_CONST_UL_PULSE : out std_logic;
    BPI_CONST_DL_PULSE : out std_logic;
    BPI_CONST_BUSY     : in  std_logic;
    BPI_DONE           : in  std_logic

    );
end BPI_PORT;


architecture BPI_PORT_Arch of BPI_PORT is

  component csp_bpi_port_la is
    port (
      CLK     : in    std_logic := 'X';
      DATA    : in    std_logic_vector (127 downto 0);
      TRIG0   : in    std_logic_vector (7 downto 0);
      CONTROL : inout std_logic_vector (35 downto 0)
      );
  end component;

  signal cmddev : std_logic_vector (15 downto 0);

  signal bpi_port_csp_data : std_logic_vector(127 downto 0);
  signal bpi_port_csp_trig : std_logic_vector(7 downto 0);

  signal dd_dtack, d_dtack, q_dtack, dtack_inner : std_logic;
  signal send_bpi_rst, bpi_rst_inner             : std_logic;
  signal send_bpi_dsbl                           : std_logic;
  signal r_rbk_fifo_nw                           : std_logic;
  signal r_bpi_status                            : std_logic;
  signal r_bpi_timer_l                           : std_logic;
  signal r_bpi_timer_h                           : std_logic;

  signal bpi_enbl_inner, bpi_dsbl_inner           : std_logic;
  signal send_bpi_enbl                            : std_logic;
  signal rst_send_bpi_enbl                        : std_logic;
  signal w_cmd_fifo, r_rbk_fifo, start_w_cmd_fifo : std_logic;
  signal dd_r_rbk_fifo, d_r_rbk_fifo              : std_logic;
  signal q_r_rbk_fifo, q_r_rbk_fifo_b             : std_logic;

  signal start_rst, start_cfg_ul, start_const_ul : std_logic;

  signal send_bpi_cfg_ul                 : std_logic;
  signal d_cfg_ul_init, q_cfg_ul_init    : std_logic;
  signal rst_cfg_ul_init, dd_cfg_ul_init : std_logic;
  signal bpi_cfg_ul_pulse_inner          : std_logic;
  signal bpi_cfg_busy_b                  : std_logic;
  signal bpi_cfg_ul_inner                : std_logic;
  signal rst_cfg_ul_pulse                : std_logic := '0';
  signal rst_const_ul_init_b             : std_logic;
  signal rst_cfg_done_pulse   : std_logic := '0';
  signal rst_cfg_done_pulse_b : std_logic := '1';

  signal send_bpi_cfg_dl, bpi_cfg_dl_inner     : std_logic;
  signal rst_cfg_ul_dl, bpi_cfg_dl_pulse_inner : std_logic;

  signal send_bpi_const_ul                   : std_logic;
  signal d_const_ul_init, q_const_ul_init    : std_logic;
  signal rst_const_ul_init, dd_const_ul_init : std_logic;
  signal bpi_const_ul_pulse_inner            : std_logic;
  signal bpi_const_busy_b                    : std_logic;
  signal bpi_const_ul_inner                  : std_logic;
  signal rst_const_ul_pulse                  : std_logic := '0';
  signal rst_const_done_pulse   : std_logic := '0';
  signal rst_const_done_pulse_b : std_logic := '1';

  signal send_bpi_const_dl, bpi_const_dl_inner     : std_logic;
  signal rst_const_ul_dl, bpi_const_dl_pulse_inner : std_logic;

  signal rst_b            : std_logic := '1';

begin  --Architecture

-- Decode instruction
  cmddev <= "000" & DEVICE & COMMAND & "00";

  SEND_BPI_CFG_DL <= '1' when (CMDDEV = x"1000" and WRITE_B = '0' and STROBE = '1' 
                               and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';
  SEND_BPI_CFG_UL <= '1' when (CMDDEV = x"1004" and WRITE_B = '0' and STROBE = '1' 
                               and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';

  SEND_BPI_CONST_DL <= '1' when (CMDDEV = x"1010" and WRITE_B = '0' and STROBE = '1' 
                                 and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';
  SEND_BPI_CONST_UL <= '1' when (CMDDEV = x"1014" and WRITE_B = '0' and STROBE = '1' 
                                 and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';

  SEND_BPI_RST <= '1' when (CMDDEV = x"1020" and WRITE_B = '0'
                            and STROBE = '1' and BPI_CFG_BUSY = '0') else '0';

  SEND_BPI_DSBL <= '1' when (CMDDEV = x"1024" and WRITE_B = '0'
                             and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';
  SEND_BPI_ENBL <= '1' when (CMDDEV = x"1028" and WRITE_B = '0'
                             and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';

  W_CMD_FIFO <= '1' when (CMDDEV = x"102C" and WRITE_B = '0'
                          and BPI_CFG_BUSY = '0' and BPI_CONST_BUSY = '0') else '0';
  R_RBK_FIFO    <= '1' when (CMDDEV = x"1030" and WRITE_B = '1') else '0';
  R_RBK_FIFO_NW <= '1' when (CMDDEV = x"1034" and WRITE_B = '1') else '0';
  R_BPI_STATUS  <= '1' when (CMDDEV = x"1038" and WRITE_B = '1') else '0';
  R_BPI_TIMER_L <= '1' when (CMDDEV = x"103C" and WRITE_B = '1') else '0';
  R_BPI_TIMER_H <= '1' when (CMDDEV = x"1040" and WRITE_B = '1') else '0';

-- CFG REGISTERS
  -- Start Upload and Download CFG registers
  start_cfg_ul <= SEND_BPI_CFG_UL or rst_cfg_ul_pulse;
  PULSE_CFG_UL : PULSE2FAST port map(BPI_CFG_UL_INNER, CLK, RST, start_cfg_ul);
  PULSE_CFG_DL : PULSE2FAST port map(BPI_CFG_DL_INNER, CLK, RST, SEND_BPI_CFG_DL);
  BPI_CFG_UL   <= BPI_CFG_UL_INNER;
  BPI_CFG_DL   <= BPI_CFG_DL_INNER;

  -- Setting MUXes for Upload and Download CFG registers
  bpi_cfg_busy_b <= not BPI_CFG_BUSY;
  FDCP_CFG_UL : FDCP port map (bpi_cfg_ul_pulse_inner, bpi_cfg_busy_b, RST, '0', start_cfg_ul);
  FDCP_CFG_DL : FDCP port map (bpi_cfg_dl_pulse_inner, bpi_cfg_busy_b, RST, '0', SEND_BPI_CFG_DL);

  BPI_CFG_UL_PULSE <= bpi_cfg_ul_pulse_inner;
  BPI_CFG_DL_PULSE <= bpi_cfg_dl_pulse_inner;

  -- Upload config from PROM on RST
  rst_const_ul_init_b  <= not rst_const_ul_init;
  RST_CFGDONE_PE : NPULSE2FAST port map (rst_cfg_done_pulse, clk, '0', 20, rst_const_ul_init_b);
  rst_cfg_done_pulse_b <= not rst_cfg_done_pulse;
  RST_UL_CFG_PE  : NPULSE2FAST port map (rst_cfg_ul_pulse, clk, '0', 5, rst_cfg_done_pulse_b);

  -- Reset BPI (mainly rbk_fifo) after initial Upload
  FD_DD_CFG_UL_INIT : FD port map(DD_CFG_UL_INIT, CLK, rst_cfg_ul_pulse);
  FD_D_CFG_UL_INIT  : FDC port map(D_CFG_UL_INIT, DD_CFG_UL_INIT, RST_CFG_UL_INIT, '1');
  FD_CFG_UL_INIT    : FD port map(Q_CFG_UL_INIT, SLOWCLK, D_CFG_UL_INIT);
  --rst_cfg_ul_init <= bpi_cfg_busy_b and Q_CFG_UL_INIT;
  PULSE_RSTCFGULINIT : PULSE2FAST port map(rst_cfg_ul_init, CLK, '0', bpi_cfg_busy_b);


-- CONST REGISTERS
  -- Start Upload and Download CONST registers
  start_const_ul <= SEND_BPI_CONST_UL or rst_const_ul_pulse;
  PULSE_CONST_UL : PULSE2FAST port map(BPI_CONST_UL_INNER, CLK, '0', start_const_ul);
  PULSE_CONST_DL : PULSE2FAST port map(BPI_CONST_DL_INNER, CLK, RST, SEND_BPI_CONST_DL);
  BPI_CONST_UL   <= BPI_CONST_UL_INNER;
  BPI_CONST_DL   <= BPI_CONST_DL_INNER;

  -- Setting MUXes for Upload and Download CONST registers
  bpi_const_busy_b <= not BPI_CONST_BUSY;
  FDCP_CONST_UL : FDCP port map (bpi_const_ul_pulse_inner, bpi_const_busy_b, RST, '0', start_const_ul);
  FDCP_CONST_DL : FDCP port map (bpi_const_dl_pulse_inner, bpi_const_busy_b, RST, '0', SEND_BPI_CONST_DL);

  BPI_CONST_UL_PULSE <= bpi_const_ul_pulse_inner;
  BPI_CONST_DL_PULSE <= bpi_const_dl_pulse_inner;

  -- Upload config from PROM on RST
  rst_b            <= not RST;
  RST_DONE_PE     : NPULSE2SAME port map (rst_const_done_pulse, clk, '0', 20, rst_b);
  rst_const_done_pulse_b <= not rst_const_done_pulse;
  RST_UL_CONST_PE : NPULSE2SAME port map (rst_const_ul_pulse, clk, '0', 5, rst_const_done_pulse_b);

  -- Reset BPI (mainly rbk_fifo) after initial Upload
  FD_DD_CONST_UL_INIT : FD port map(DD_CONST_UL_INIT, CLK, rst_const_ul_pulse);
  FD_D_CONST_UL_INIT  : FDC port map(D_CONST_UL_INIT, DD_CONST_UL_INIT, RST_CONST_UL_INIT, '1');
  FD_CONST_UL_INIT    : FD port map(Q_CONST_UL_INIT, SLOWCLK, D_CONST_UL_INIT);
  --rst_const_ul_init <= bpi_const_busy_b and Q_CONST_UL_INIT;
  PULSE_RSTCONSTULINIT : PULSE2FAST port map(rst_const_ul_init, CLK, '0', bpi_const_busy_b);

  -- Read enables for Readback FIFO
  dd_r_rbk_fifo  <= '1' when (r_rbk_fifo = '1' and STROBE = '1') else '0';
  FD_D_R_RBK_FIFO : FDC port map(d_r_rbk_fifo, dd_r_rbk_fifo, q_r_rbk_fifo, '1');
  FD_Q_R_RBK_FIFO : FD port map(q_r_rbk_fifo, SLOWCLK, d_r_rbk_fifo);
  q_r_rbk_fifo_b <= not q_r_rbk_fifo;
  PULSE_BPI_RE    : PULSE2SAME port map(BPI_RE, CLK, RST, q_r_rbk_fifo_b);

  start_rst        <= SEND_BPI_RST or rst_cfg_ul_init or rst_const_ul_init;
  PULSE_BPI_RST : NPULSE2FAST port map(BPI_RST_INNER, CLK, '0', 5, start_rst);
  start_w_cmd_fifo <= '1' when (w_cmd_fifo = '1' and STROBE = '1') else '0';
  PULSE_BPI_WE  : PULSE2FAST port map(BPI_WE, CLK, RST, start_w_cmd_fifo);

  PULSE_BPI_ENBL : PULSE2FAST port map(BPI_ENBL_INNER, CLK, RST, SEND_BPI_ENBL);
  PULSE_BPI_DSBL : PULSE2FAST port map(BPI_DSBL_INNER, CLK, RST, SEND_BPI_DSBL);

  BPI_RST  <= BPI_RST_INNER;
  BPI_ENBL <= BPI_ENBL_INNER;
  BPI_DSBL <= BPI_DSBL_INNER;

  OUTDATA <= BPI_RBK_FIFO_DATA when (R_RBK_FIFO = '1') else
             "00000" & BPI_RBK_WRD_CNT when (R_RBK_FIFO_NW = '1') else
             BPI_STATUS                when (R_BPI_STATUS = '1')  else
             BPI_TIMER(15 downto 0)    when (R_BPI_TIMER_L = '1') else
             BPI_TIMER(31 downto 16)   when (R_BPI_TIMER_H = '1') else
             (others => 'Z');

-- Generate CMD_FIFO INPUT DATA
  FDCE_GEN : for i in 0 to 15 generate
  begin
    FDCE_CMD_FIFO_DATA : FDCE port map (BPI_CMD_FIFO_DATA(i), STROBE, W_CMD_FIFO, RST, INDATA(i));
  end generate FDCE_GEN;

-- Chip ScopePro
  --csp_bpi_port_la_pm : csp_bpi_port_la
  --  port map (
  --    CONTROL => CSP_BPI_PORT_LA_CTRL,
  --    CLK     => CLK,
  --    DATA    => bpi_port_csp_data,
  --    TRIG0   => bpi_port_csp_trig
  --    );

  --bpi_port_csp_trig <= "00" & STROBE & BPI_ENBL_INNER & BPI_DSBL_INNER & BPI_RST_INNER
  --                     & SEND_BPI_CFG_UL & SEND_BPI_CFG_DL;
  --bpi_port_csp_data <= "0" & x"000000000000" &
  --                     std_logic_vector(cmddev) &                   --[78:66]
  --                     x"0000" &        --[65:50]
  --                     BPI_RBK_FIFO_DATA &                          --[49:34]
  --                     BPI_RBK_WRD_CNT &                            --[33:23]
  --                     BPI_CFG_BUSY & BPI_DONE & bpi_cfg_busy_b & STROBE & WRITE_B & RST &  --[22:17]
  --                     "00" &           --[16:15]
  --                     "00" &           --[14:13]
  --                     bpi_cfg_dl_pulse_inner & SEND_BPI_CFG_DL & BPI_CFG_DL_INNER &  --[12:10]
  --                     bpi_cfg_ul_pulse_inner & SEND_BPI_CFG_UL & BPI_CFG_UL_INNER &  --[9:7]
  --                     "000" &          -- [6:4]
  --                     DD_DTACK & D_DTACK & Q_DTACK & DTACK_INNER;  --[3:0]

  -- DTACK
  dd_dtack <= STROBE and DEVICE;
  FD_D_DTACK : FDC port map(d_dtack, dd_dtack, q_dtack, '1');
  FD_Q_DTACK : FD port map(q_dtack, SLOWCLK, d_dtack);
  dtack_inner    <= q_dtack;
  DTACK    <= q_dtack;
  
end BPI_PORT_Arch;
