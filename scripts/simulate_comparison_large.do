vlog matrix_multiplier_n.sv
vlog matrix_multiplier_m.sv
vlog multiplier_comparison_tb.sv

vsim -gN=50 -gM=99 work.multiplier_comparison_tb

run -all
