    module dot_product_parallel #(
        parameter int WIDTH = 8
    ) (
        input logic clk,
        input logic reset,
        input logic start,

        input logic signed [WIDTH-1:0] a [3:0],  // bit width and how many there are
        input logic signed [WIDTH-1:0] b [3:0],

        output logic signed [(2*WIDTH)+1:0] result,
        output logic done
    );
        localparam int PRODUCT_WIDTH = 2 * WIDTH;
        localparam int SUM_WIDTH = PRODUCT_WIDTH + 1;
        localparam int ACC_WIDTH = PRODUCT_WIDTH + 2;

        logic signed [PRODUCT_WIDTH-1:0] product0, product1, product2, product3;

        logic signed [SUM_WIDTH-1:0] sum0, sum1;           // 17 bits because they come from 16 + 16 bit

        logic signed [ACC_WIDTH-1:0] final_sum;          // 18 bits comes from 17 + 17 

        always_comb begin
            product0 = a[0] * b[0];
            product1 = a[1] * b[1];
            product2 = a[2] * b[2];
            product3 = a[3] * b[3];

            // Extend each 16-bit product to 17 bits before addition.


            sum0 =
                {product0[PRODUCT_WIDTH-1], product0}   // extending the product's most significant bit
            + {product1[PRODUCT_WIDTH-1], product1};

            sum1 =
                {product2[PRODUCT_WIDTH-1], product2}
            + {product3[PRODUCT_WIDTH-1], product3};

            final_sum =
                {sum0[SUM_WIDTH-1], sum0}
            + {sum1[SUM_WIDTH-1], sum1};
        end

        always_ff @(posedge clk or posedge reset) begin
            if (reset) begin
                result <= '0;
                done <= 1'b0;
            end
            else begin
                done <= 1'b0;
                if (start) begin
                    result <= final_sum;
                    done <= 1'b1;
                end
            end
        end
    endmodule


