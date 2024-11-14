verilator --top-module emu  \
     --trace --trace-fst --trace-structs --cc --assert --exe --timing --build   \
    --build-jobs 8 sim_top.cpp -I../rtl  \
    ../rtl/*.sv ../CDi.sv ../rtl/*.v  \
    tg68kdotc_verilog_wrapper.v ur6805.v \
    /usr/lib/x86_64-linux-gnu/libpng.so && ./obj_dir/Vemu $*

# -DDISABLE_MAIN_CPU -DDISABLE_SLAVE_UC

# Makes it slower?
# --threads 5