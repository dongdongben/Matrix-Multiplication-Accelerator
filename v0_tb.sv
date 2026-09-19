`timescale 1ns/1ps

module v0_tb;

    localparam int WIDTH = 8;
    localparam int ACC_WIDTH = (2 * WIDTH) + 2;

    logic clk;
    logic reset;
    logic start;

    logic signed [WIDTH-1:0] a [0:3];
    logic signed [WIDTH-1:0] b [0:3];

    logic signed [ACC_WIDTH-1:0] result;
    logic busy;
    logic done;


    // Replace dot_product_engine with your actual module name if different.
    dot_product_engine #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .a(a),
        .b(b),
        .result(result),
        .busy(busy),
        .done(done)
    );


    // Clock generation: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // Test sequence
    initial begin
        reset = 1'b1;
        start = 1'b0;

        a[0] = 1;
        a[1] = 2;
        a[2] = 3;
        a[3] = 4;

        b[0] = 5;
        b[1] = 6;
        b[2] = 7;
        b[3] = 8;

        repeat (2) @(posedge clk);
        reset = 1'b0;

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        wait (done == 1'b1);

        if (result == 70)
            $display("PASS: result = %0d", result);
        else
            $display("FAIL: expected 70, got %0d", result);

        #10;
        $finish;
    end

endmodule