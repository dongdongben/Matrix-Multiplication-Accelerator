/*
===============================================================================
N-multiplier matrix multiplier
===============================================================================

This architecture owns exactly N multipliers. During each active clock cycle,
all N products for one output element are formed and added. The completed dot
product is then written to C[row_index][col_index].

Latency after start is accepted:

    N * N active cycles

There is no partial dot product carried between cycles. The cost is an
N-product combinational datapath and N physical multipliers.
*/

module matrix_multiplier_n #(
    parameter int WIDTH = 8,
    parameter int N = 4
) (
    input logic clk,
    input logic reset,
    input logic start,

    input logic signed [WIDTH-1:0] a [0:N-1][0:N-1],
    input logic signed [WIDTH-1:0] b [0:N-1][0:N-1],

    output logic signed [(2*WIDTH + $clog2(N))-1:0] c [0:N-1][0:N-1],
    output logic done
);
    localparam int PRODUCT_WIDTH = 2 * WIDTH;
    localparam int SUM_WIDTH = PRODUCT_WIDTH + $clog2(N);
    localparam int DIM_WIDTH = (N <= 1) ? 1 : $clog2(N);

    logic [DIM_WIDTH-1:0] row_index;
    logic [DIM_WIDTH-1:0] col_index;
    logic active;

    logic signed [PRODUCT_WIDTH-1:0] product [0:N-1];
    logic signed [SUM_WIDTH-1:0] dot_product;

    always_comb begin
        dot_product = '0;

        for (int k = 0; k < N; k++) begin
            product[k] = a[row_index][k] * b[k][col_index];
            dot_product = dot_product +
                {{(SUM_WIDTH-PRODUCT_WIDTH){product[k][PRODUCT_WIDTH-1]}},
                    product[k]};
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            row_index <= '0;
            col_index <= '0;
            done <= 1'b0;
            active <= 1'b0;
        end
        else begin
            if (start && !active) begin
                row_index <= '0;
                col_index <= '0;
                done <= 1'b0;
                active <= 1'b1;
            end
            else if (active) begin
                c[row_index][col_index] <= dot_product;

                if ((row_index == N-1) && (col_index == N-1)) begin
                    done <= 1'b1;
                    active <= 1'b0;
                end
                else if (col_index == N-1) begin
                    row_index <= row_index + 1'b1;
                    col_index <= '0;
                end
                else begin
                    col_index <= col_index + 1'b1;
                end
            end
        end
    end
endmodule
