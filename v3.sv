/*
===============================================================================
v3: General Matrix Multiplier
===============================================================================

PURPOSE:
------------
Given M multipliers, compute:
    a x b = c
    where a and b are NxN matrices, while maximizing multiplier usage.

ARCHITECTURE:
-----------------
Compute the MAXIMUM POSSIBLE AMOUNT of output element c[i][j] per active clock cycle.

Each output is a length N dot product:
c[i][j] = 
            a[i][0] * b[0][j] +
            a[i][1] * b[1][j] +
            .
            .
            .
            a[i][N] * b[N][j]

- LOCATION TRACKING:
    To keep track of indices, we use base_index, updated each clk cycle by + M; 
    Inside every clk cycle, a for loop does m++ until m=M
    while index = base_index + m = i*N^2 + j*N + k unfolds the precise location of inputs that the multiplier draws from.

Every product is added to running_sum after completion

- DOT PRODUCT STORAGE:
    When k = N-1, we have completed one dot product. runnning_sum gets stored to array sum[sum_count], then resets to 0.
    sum[] stores up to ceil(M/N) = (M+N-1)/N sums, the maximum amount of sums each cycle.

    sum_count is an index that tracks the location of sums in the sum[] array. There are two other arrays sum_i and sun_j that tracks the 
    i and j location of the sum_count, so c[sum_i[sum_count]][sum_j[sum_count]] = sum[sum_count]

- HOLDING REMANING PRODUCTS FOR NEXT RUN:
    By the end of the combinational loop, excess products in running_sum are passed down to partial_sum, an actual registers that will hold the value
    for usage in the next cycle. running_sum then draws from partial_sum in the next combinational loop to complete the dot product

The datapath contains:
    - M running multipliers,
    - combinational multiplication and addtion logic
    - registers that keeps track of: base_index, partial_sum, output matrix

The M multipliers are reused until completion of matrix multiplication.

When index = N^3 we have completed the last dot product. On the next clk edge base_index >= N^3 so done=1

CONTROL:
-------
reset:
clear all registers to prepare for a fresh calculation

start && !active:
fresh start multiplication beginning at c[0][0]

active:
continues the multiplication if active

*/


module matrix_multiplier #(
    parameter int WIDTH = 8,
    parameter int N = 8,
    parameter int M = 10
) (
    input logic clk,
    input logic reset,
    input logic start,

    input logic signed [WIDTH-1:0] a [0:N-1][0:N-1],
    input logic signed [WIDTH-1:0] b [0:N-1][0:N-1],

    output logic signed [(2*WIDTH + $clog2(N))-1:0] c [0:N-1][0:N-1],
    output logic done
);
// ============================================================================
// object length declaration
// ============================================================================
    localparam int PRODUCT_WIDTH = 2 * WIDTH;
    localparam int SUM_WIDTH = PRODUCT_WIDTH + $clog2(N);
    localparam int INDEX_WIDTH = $clog2(N*N*N + M);
    localparam int DIM_WIDTH = (N <= 1) ? 1 : $clog2(N);    // to account for N=1
    localparam int MAX_NUM_DOTPRODUCT = (M + N - 1) / N;    // M/N rounded up
    localparam int SUM_COUNT_WIDTH = $clog2(MAX_NUM_DOTPRODUCT + 1);
// ============================================================================
// combinatoinal signals, not remembered through cycles.
// ============================================================================
    logic [DIM_WIDTH-1:0] i;
    logic [DIM_WIDTH-1:0] j;
    logic [DIM_WIDTH-1:0] k;
    // index used to unfold i j k
    logic [INDEX_WIDTH-1:0] index;

    // product array used to add to running_sum
    logic signed [PRODUCT_WIDTH-1:0] product [0:M-1];
    // sum of products
    logic signed [SUM_WIDTH-1:0] running_sum;   

    // index tracker for storing into c
    logic [DIM_WIDTH-1:0] sum_i [0:MAX_NUM_DOTPRODUCT-1];
    logic [DIM_WIDTH-1:0] sum_j [0:MAX_NUM_DOTPRODUCT-1];

    // sum array and sum index
    logic signed [SUM_WIDTH-1:0] sum [0:MAX_NUM_DOTPRODUCT-1];
    logic [SUM_COUNT_WIDTH-1:0] sum_count;
// ============================================================================
// registers
// ============================================================================
    logic [INDEX_WIDTH-1:0] base_index;

    logic signed [SUM_WIDTH-1:0] partial_sum;   // for storing the partial sum of potentially leftover products

    logic active;
// ============================================================================
// combinational logic
// ============================================================================
    always_comb begin

        // set the combinational signals sum and product to 0 at the start
        i = '0;
        j = '0;
        k = '0;
        index = '0;

        running_sum = partial_sum;
        sum_count = '0;     // the number of and the position of the sums in this loop
        
        for (int m = 0; m < M; m++) begin
            product[m] = '0;
        end

        for (int s = 0; s < MAX_NUM_DOTPRODUCT; s++) begin
            sum[s]   = '0;
            sum_i[s] = '0;
            sum_j[s] = '0;
        end

        // begin multiplication and addition logic
        for (int m=0; m < M; m++) begin
            index = base_index + INDEX_WIDTH'(m);

            if (index < N*N*N) begin
                i = DIM_WIDTH'((index / (N**2)) % N);
                j = DIM_WIDTH'((index / N) % N);
                k = DIM_WIDTH'(index % N);

                product[m] = a[i][k] * b[k][j];

                running_sum = running_sum + 
                    {{(SUM_WIDTH-PRODUCT_WIDTH){product[m][PRODUCT_WIDTH-1]}}, product[m]}; 
                    // repeat the most significant bit to fil difference between sum and product width, and extend

                if (k==N-1) begin
                    sum[sum_count] = running_sum;
                    sum_i[sum_count] = i;      // note that sum_i and j gets reset every clock edge.
                    sum_j[sum_count] = j;
                    sum_count = sum_count + 1;
                    running_sum = 0;
                end
            end
        end
    end

// ============================================================================
// sequential logic
// ============================================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= '0;
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
                        c[sum_i[s]][sum_j[s]] <= sum[s];    // store into c, with the info from combinational signals
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


