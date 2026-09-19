/*
===============================================================================
V2: 3x3 Matrix Multiplier
===============================================================================

PURPOSE
-------
Compute:

    C = A x B

for two signed 3x3 matrices.

ARCHITECTURE
------------
Computes ONE output element C[row][col] per active clock cycle.

Each output is a length-3 dot product:

    C[i][j] =
        A[i][0] * B[0][j] +
        A[i][1] * B[1][j] +
        A[i][2] * B[2][j]

The datapath contains:
    - 3 parallel multipliers
    - combinational addition logic
    - row_index / col_index registers
    - output matrix C registers

The 3 multipliers are reused for all 9 output elements.

CONTROL
-------
start && !active:
    Begin a new matrix multiplication at C[0][0].

active:
    Current combinational dot product is written into C[row_index][col_index].
    Then advance to the next output position.

Traversal order:

    C00 -> C01 -> C02
     -> C10 -> C11 -> C12
     -> C20 -> C21 -> C22

After C22 is written:
    done   = 1
    active = 0

TIMING
------
Start cycle initializes the indices.

Then:
    1 output element / clock
    9 output elements total

Therefore the matrix computation requires 9 active compute/write cycles
(after accepting start).

IMPORTANT INVARIANT
-------------------
row_index and col_index always identify the output C element currently
being produced by the combinational datapath.

DATAFLOW
--------

 A[row][0] ----x---- B[0][col] --- product0 --\
 A[row][1] ----x---- B[1][col] --- product1 ----+--> sum0 --> C[row][col]
 A[row][2] ----x---- B[2][col] --- product2 --/

===============================================================================
*/

module multiplier_3x3 #(
    parameter int WIDTH = 8
) (
    input logic clk,
    input logic reset,
    input logic start,

    // 3x3 matrices, count from 0 to 2 like an array, unlike bit
    input logic signed [WIDTH-1:0] a [0:2][0:2],
    input logic signed [WIDTH-1:0] b [0:2][0:2],

    // result is still 3x3, but increase bit width for each slot 
    output logic signed [(2*WIDTH)+1:0] c [0:2][0:2],
    output logic done
);

// ============================================================================
// Datapath widths
// ============================================================================
    localparam int PRODUCT_WIDTH = 2 * WIDTH;
    localparam int SUM_WIDTH = PRODUCT_WIDTH + 2;

// ============================================================================
// Control state
// ============================================================================
    logic [1:0] row_index;      // up to three, two bits sufficient
    logic [1:0] col_index;

// ============================================================================
// Combinational datapath
// ============================================================================
    logic signed [PRODUCT_WIDTH-1:0] product0, product1, product2; // for 3x3 dot product
    logic signed [SUM_WIDTH-1:0] sum0;

    logic active;

    always_comb begin
        product0 = a[row_index][0] * b[0][col_index];
        product1 = a[row_index][1] * b[1][col_index];
        product2 = a[row_index][2] * b[2][col_index];

        sum0 = 
            {{2{product0[PRODUCT_WIDTH-1]}}, product0} 
        + {{2{product1[PRODUCT_WIDTH-1]}}, product1} 
        + {{2{product2[PRODUCT_WIDTH-1]}}, product2};
    end


// ============================================================================
// Sequential control and writeback
// ============================================================================
//
// Responsibilities:
//   1. Accept start
//   2. Write the current dot product into C
//   3. Advance row/column indices
//   4. Detect completion
//

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            //sum0 <= '0;           Mistake: sum0 is combinational, can't assign anything here in sequential, would cause two different logic pieces driving sum0
            row_index <= '0;
            col_index <= '0;
            done <= 1'b0;
            active <= 1'b0;
        end
        else begin
            if (start && !active) begin     // if fresh start
                row_index <= '0;
                col_index <= '0;
                done <= 1'b0;
                active <= 1'b1;
            end
            else if (active) begin
                c[row_index][col_index] <= sum0;

                if (row_index == 2 && col_index== 2) begin
                    done <= 1'b1;
                    active <= 1'b0;
                end
                else if (col_index==2) begin
                    row_index <= row_index + 1;
                    col_index <= 0;
                end
                else begin
                    col_index <= col_index + 1;
                end

            end
        end
    end
endmodule

