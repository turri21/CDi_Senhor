derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

set_false_path -from {*|flag_cross_domain*|flagtoggle_clk_a*} -to {*|flag_cross_domain*|synca_clk_b*}
set_false_path -from {*|signal_cross_domain*|signal_clk_a} -to {*|signal_cross_domain*|synca_clk_b[0]}
set_false_path -from {*|mpeg_video:video|mpeg_stream_fifo_write_adr_syncval*} -to {*|mpeg_video:video|mpeg_stream_fifo_write_adr_clk60*}
