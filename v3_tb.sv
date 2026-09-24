`timescale 1ns/1ps

module v3_tb;

    localparam int WIDTH = 8;
    localparam int N = 4;
    localparam int M = 5;
    localparam int SUM_WIDTH = 2*WIDTH + $clog2(N);
    localparam int NUM_OUTPUTS = N*N;

    // Counts active clock edges after start is accepted until done is asserted.
    localparam int EXPECTED_CYCLES = (N*N*N + M - 1) / M;
    localparam int TIMEOUT_CYCLES = EXPECTED_CYCLES + 10;
    localparam int RANDOM_TESTS = 20;

    logic clk;
    logic reset;
    logic start;

    logic signed [WIDTH-1:0] a [0:N-1][0:N-1];
    logic signed [WIDTH-1:0] b [0:N-1][0:N-1];

    logic signed [SUM_WIDTH-1:0] c [0:N-1][0:N-1];
    logic signed [SUM_WIDTH-1:0] expected [0:N-1][0:N-1];
    logic done;

    integer total_cases;
    integer total_errors;
    integer random_seed;

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

    task automatic clear_inputs;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = '0;
                    b[i][j] = '0;
                end
            end
        end
    endtask

    task automatic reset_dut;
        begin
            reset = 1'b1;
            start = 1'b0;
            clear_inputs();

            repeat (2) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            @(posedge clk);
        end
    endtask

    task automatic load_zero_a_pattern_b;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = 0;
                    b[i][j] = i*N + j + 1;
                end
            end
        end
    endtask

    task automatic load_identity_left;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = (i == j) ? 1 : 0;
                    b[i][j] = i*N + j + 1;
                end
            end
        end
    endtask

    task automatic load_identity_right;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = i - j;
                    b[i][j] = (i == j) ? 1 : 0;
                end
            end
        end
    endtask

    task automatic load_all_ones;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = 1;
                    b[i][j] = 1;
                end
            end
        end
    endtask

    task automatic load_signed_directed;
        begin
            a[0][0] = -3; a[0][1] = -2; a[0][2] = -1; a[0][3] = 0;
            a[1][0] = 1;  a[1][1] = 2;  a[1][2] = 3;  a[1][3] = -3;
            a[2][0] = 2;  a[2][1] = -1; a[2][2] = 0;  a[2][3] = 1;
            a[3][0] = -2; a[3][1] = 3;  a[3][2] = -3; a[3][3] = 2;

            b[0][0] = 3;  b[0][1] = -1; b[0][2] = 2;  b[0][3] = -2;
            b[1][0] = -3; b[1][1] = 2;  b[1][2] = 0;  b[1][3] = 1;
            b[2][0] = 1;  b[2][1] = -2; b[2][2] = -1; b[2][3] = 3;
            b[3][0] = 0;  b[3][1] = 1;  b[3][2] = -3; b[3][3] = -1;
        end
    endtask

    task automatic load_near_width_limits;
        begin
            a[0][0] = 127;  a[0][1] = -128; a[0][2] = 3;    a[0][3] = -4;
            a[1][0] = -1;   a[1][1] = 126;  a[1][2] = -127; a[1][3] = 2;
            a[2][0] = 64;   a[2][1] = -32;  a[2][2] = 16;   a[2][3] = -8;
            a[3][0] = -128; a[3][1] = 1;    a[3][2] = 0;    a[3][3] = 127;

            b[0][0] = -1;   b[0][1] = 2;    b[0][2] = -3;   b[0][3] = 4;
            b[1][0] = 127;  b[1][1] = -128; b[1][2] = 1;    b[1][3] = -2;
            b[2][0] = -64;  b[2][1] = 32;   b[2][2] = -16;  b[2][3] = 8;
            b[3][0] = 7;    b[3][1] = -6;   b[3][2] = 5;    b[3][3] = -4;
        end
    endtask

    function automatic integer random_range;
        input integer min_value;
        input integer max_value;
        integer raw;
        integer span;
        begin
            raw = $random(random_seed);
            span = max_value - min_value + 1;
            random_range = min_value + (raw < 0 ? -raw : raw) % span;
        end
    endfunction

    task automatic load_random_small;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = random_range(-8, 7);
                    b[i][j] = random_range(-8, 7);
                end
            end
        end
    endtask

    task automatic calculate_expected;
        integer i;
        integer j;
        integer k;
        integer acc;
        integer aval;
        integer bval;
        begin
            // Testbench math is not synthesized, so use clear integer arithmetic
            // for the independent golden model.
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    acc = 0;
                    for (k = 0; k < N; k = k + 1) begin
                        aval = a[i][k];
                        bval = b[k][j];
                        acc = acc + aval * bval;
                    end
                    expected[i][j] = acc;
                end
            end
        end
    endtask

    task automatic start_and_wait_done;
        output integer cycles;
        output integer timed_out;
        begin
            cycles = 0;
            timed_out = 0;

            @(negedge clk);
            start = 1'b1;

            @(posedge clk);
            #1;

            @(negedge clk);
            start = 1'b0;

            while (!done && cycles < TIMEOUT_CYCLES) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end

            if (!done) begin
                timed_out = 1;
            end
        end
    endtask

    task automatic check_outputs;
        input string test_name;
        input integer cycles;
        input integer timed_out;
        output integer case_errors;
        integer i;
        integer j;
        begin
            case_errors = 0;

            if (timed_out) begin
                $display("ERROR: %s timed out after %0d cycles waiting for done", test_name, cycles);
                case_errors = case_errors + 1;
            end
            else if (cycles != EXPECTED_CYCLES) begin
                $display("ERROR: %s cycle count mismatch", test_name);
                $display("       expected cycles = %0d", EXPECTED_CYCLES);
                $display("       actual cycles   = %0d", cycles);
                case_errors = case_errors + 1;
            end

            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (c[i][j] !== expected[i][j]) begin
                        $display("ERROR: %s", test_name);
                        $display("       C[%0d][%0d]", i, j);
                        $display("       expected = %0d", expected[i][j]);
                        $display("       actual   = %0d", c[i][j]);
                        case_errors = case_errors + 1;
                    end
                end
            end

            if (case_errors == 0) begin
                $display("PASS: %s all %0d outputs matched, cycles = %0d",
                    test_name, NUM_OUTPUTS, cycles);
            end
            else begin
                $display("FAIL: %s had %0d issue(s)", test_name, case_errors);
            end
        end
    endtask

    task automatic run_case;
        input string test_name;
        integer cycles;
        integer timed_out;
        integer case_errors;
        begin
            total_cases = total_cases + 1;
            calculate_expected();
            start_and_wait_done(cycles, timed_out);
            check_outputs(test_name, cycles, timed_out, case_errors);
            total_errors = total_errors + case_errors;
        end
    endtask

    initial begin
        total_cases = 0;
        total_errors = 0;
        random_seed = 32'h31415926;

        reset_dut();

        $display("Running v3 self-checking testbench");
        $display("WIDTH = %0d, N = %0d, M = %0d", WIDTH, N, M);
        $display("Expected active cycles per multiply = %0d", EXPECTED_CYCLES);

        load_zero_a_pattern_b();
        run_case("zero A, patterned B");

        load_identity_left();
        run_case("identity A, patterned B");

        load_identity_right();
        run_case("patterned A, identity B");

        load_all_ones();
        run_case("all ones");

        load_signed_directed();
        run_case("directed signed values");

        load_near_width_limits();
        run_case("near WIDTH limits");

        for (int t = 0; t < RANDOM_TESTS; t = t + 1) begin
            load_random_small();
            run_case($sformatf("random small values %0d", t));
        end

        if (total_errors == 0) begin
            $display("OVERALL PASS: %0d test case(s) passed", total_cases);
        end
        else begin
            $display("OVERALL FAIL: %0d issue(s) across %0d test case(s)",
                total_errors, total_cases);
        end

        $finish;
    end

endmodule
