
`timescale 1ns/1ps

module v3_tb;

    localparam int WIDTH = 8;
    localparam int N = 4;
    localparam int M = 5;
    localparam int SUM_WIDTH = 2*WIDTH + $clog2(N);

    logic clk;
    logic reset;
    logic start;

    logic signed [WIDTH-1:0] a [0:N-1][0:N-1];
    logic signed [WIDTH-1:0] b [0:N-1][0:N-1];

    logic signed [SUM_WIDTH-1:0] c [0:N-1][0:N-1];
    logic done;

    matrix_multiplier #(
        .WIDTH(WIDTH),
        .N(N),
        .M(M)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .a(a),
        .b(b),
        .c(c),
        .done(done)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        start = 0;

        // A = identity matrix
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (i == j)
                    a[i][j] = 1;
                else
                    a[i][j] = 0;
            end
        end

        // B = easy-to-recognize values
        b[0][0] = 1;  b[0][1] = 2;  b[0][2] = 3;  b[0][3] = 4;
        b[1][0] = 5;  b[1][1] = 6;  b[1][2] = 7;  b[1][3] = 8;
        b[2][0] = 9;  b[2][1] = 10; b[2][2] = 11; b[2][3] = 12;
        b[3][0] = 13; b[3][1] = 14; b[3][2] = 15; b[3][3] = 16;

        repeat (2) @(posedge clk);
        reset = 0;

        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        wait(done);

        $display("Result matrix:");

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                $write("%0d ", c[i][j]);
            end
            $display("");
        end

        #10;
        $stop;
    end

endmodule