# Top-level signals
add wave sim:/v1_tb/clk
add wave sim:/v1_tb/reset
add wave sim:/v1_tb/start

add wave sim:/v1_tb/a
add wave sim:/v1_tb/b

# DUT outputs
add wave sim:/v1_tb/dut/result
add wave sim:/v1_tb/dut/done

# Internal datapath
add wave sim:/v1_tb/dut/product0
add wave sim:/v1_tb/dut/product1
add wave sim:/v1_tb/dut/product2
add wave sim:/v1_tb/dut/product3

add wave sim:/v1_tb/dut/sum0
add wave sim:/v1_tb/dut/sum1

add wave sim:/v1_tb/dut/final_sum