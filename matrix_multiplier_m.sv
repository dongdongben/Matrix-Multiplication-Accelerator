/*
===============================================================================
M-multiplier matrix multiplier
===============================================================================

This is the generalized V3 architecture under an experiment-specific module
name. It treats matrix multiplication as N^3 flattened product jobs and
processes M jobs per active cycle.

For the comparison experiment, choose:

    N < M < 2*N

Because an M-job group can cross a dot-product boundary, partial_sum stores the
unfinished next dot product between cycles. Up to two complete output elements
can be produced by one cycle in this M range.

Latency after start is accepted:

    ceil(N^3 / M) active cycles
*/

module matrix_multiplier_m #(
    parameter int WIDTH = 8,
    parameter int N = 4,
    parameter int M = 5
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
    localparam int INDEX_WIDTH = $clog2(N*N*N + M);
    localparam int DIM_WIDTH = (N <= 1) ? 1 : $clog2(N);
    localparam int MAX_NUM_DOTPRODUCT = (M + N - 1) / N;
    localparam int SUM_COUNT_WIDTH = $clog2(MAX_NUM_DOTPRODUCT + 1);

    logic [DIM_WIDTH-1:0] i;
    logic [DIM_WIDTH-1:0] j;
    logic [DIM_WIDTH-1:0] k;
    logic [INDEX_WIDTH-1:0] index;

    logic signed [PRODUCT_WIDTH-1:0] product [0:M-1];
    logic signed [SUM_WIDTH-1:0] running_sum;

    logic [DIM_WIDTH-1:0] sum_i [0:MAX_NUM_DOTPRODUCT-1];
    logic [DIM_WIDTH-1:0] sum_j [0:MAX_NUM_DOTPRODUCT-1];
    logic signed [SUM_WIDTH-1:0] sum [0:MAX_NUM_DOTPRODUCT-1];
    logic [SUM_COUNT_WIDTH-1:0] sum_count;

    logic [INDEX_WIDTH-1:0] base_index;
    logic signed [SUM_WIDTH-1:0] partial_sum;
    logic active;

    always_comb begin
        i = '0;
        j = '0;
        k = '0;
        index = '0;

        running_sum = partial_sum;
        sum_count = '0;

        for (int m = 0; m < M; m++) begin
            product[m] = '0;
        end

        for (int s = 0; s < MAX_NUM_DOTPRODUCT; s++) begin
            sum[s] = '0;
            sum_i[s] = '0;
            sum_j[s] = '0;
        end

        for (int m = 0; m < M; m++) begin
            index = base_index + INDEX_WIDTH'(m);

            if (index < N*N*N) begin
                i = DIM_WIDTH'((index / (N**2)) % N);
                j = DIM_WIDTH'((index / N) % N);
                k = DIM_WIDTH'(index % N);

                product[m] = a[i][k] * b[k][j];
                running_sum = running_sum +
                    {{(SUM_WIDTH-PRODUCT_WIDTH){product[m][PRODUCT_WIDTH-1]}},
                        product[m]};

                if (k == N-1) begin
                    sum[sum_count] = running_sum;
                    sum_i[sum_count] = i;
                    sum_j[sum_count] = j;
                    sum_count = sum_count + 1'b1;
                    running_sum = '0;
                end
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 1'b0;
            base_index <= '0;
            active <= 1'b0;
            partial_sum <= '0;
        end
        else begin
            if (start && !active) begin
                base_index <= '0;
                active <= 1'b1;
                done <= 1'b0;
                partial_sum <= '0;
            end
            else if (active) begin
                // Keep the hardware loop statically bounded so synthesis can
                // prove every sum-array access is in range.
                for (int s = 0; s < MAX_NUM_DOTPRODUCT; s++) begin
                    if (s < sum_count) begin
                        c[sum_i[s]][sum_j[s]] <= sum[s];
                    end
                end

                if (base_index + M >= N*N*N) begin
                    done <= 1'b1;
                    active <= 1'b0;
                end
                else begin
                    partial_sum <= running_sum;
                    base_index <= base_index + INDEX_WIDTH'(M);
                end
            end
        end
    end
endmodule
