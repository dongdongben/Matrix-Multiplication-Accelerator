`timescale 1ns/1ps

module multiplier_comparison_tb #(
    parameter int WIDTH = 8,
    parameter int N = 4,
    parameter int M = 5,
    parameter int RANDOM_TESTS = 20
);
    localparam int SUM_WIDTH = 2*WIDTH + $clog2(N);
    localparam int NUM_OUTPUTS = N*N;
    localparam int N_EXPECTED_CYCLES = N*N;
    localparam int M_EXPECTED_CYCLES = (N*N*N + M - 1) / M;
    localparam int TIMEOUT_CYCLES = N_EXPECTED_CYCLES + 10;

    logic clk;
    logic reset;
    logic start;

    logic signed [WIDTH-1:0] a [0:N-1][0:N-1];
    logic signed [WIDTH-1:0] b [0:N-1][0:N-1];

    logic signed [SUM_WIDTH-1:0] c_n [0:N-1][0:N-1];
    logic signed [SUM_WIDTH-1:0] c_m [0:N-1][0:N-1];
    logic signed [SUM_WIDTH-1:0] expected [0:N-1][0:N-1];
    logic done_n;
    logic done_m;

    integer total_cases;
    integer total_errors;
    integer total_n_cycles;
    integer total_m_cycles;
    integer random_seed;
    real cycle_speedup;
    real cycle_reduction_percent;
    real break_even_fmax_percent;

    matrix_multiplier_n #(
        .WIDTH(WIDTH),
        .N(N)
    ) dut_n (
        .clk(clk),
        .reset(reset),
        .start(start),
        .a(a),
        .b(b),
        .c(c_n),
        .done(done_n)
    );

    matrix_multiplier_m #(
        .WIDTH(WIDTH),
        .N(N),
        .M(M)
    ) dut_m (
        .clk(clk),
        .reset(reset),
        .start(start),
        .a(a),
        .b(b),
        .c(c_m),
        .done(done_m)
    );

    initial begin
        clk = 1'b0;
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

    task automatic reset_duts;
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
                    b[i][j] = ((i*N + j) % 127) + 1;
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
                    b[i][j] = ((i*N + j) % 127) + 1;
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

    function automatic integer signed_pattern_a;
        input integer row;
        input integer col;
        begin
            case ((row % 4)*4 + (col % 4))
                0:  signed_pattern_a = -3;
                1:  signed_pattern_a = -2;
                2:  signed_pattern_a = -1;
                3:  signed_pattern_a = 0;
                4:  signed_pattern_a = 1;
                5:  signed_pattern_a = 2;
                6:  signed_pattern_a = 3;
                7:  signed_pattern_a = -3;
                8:  signed_pattern_a = 2;
                9:  signed_pattern_a = -1;
                10: signed_pattern_a = 0;
                11: signed_pattern_a = 1;
                12: signed_pattern_a = -2;
                13: signed_pattern_a = 3;
                14: signed_pattern_a = -3;
                default: signed_pattern_a = 2;
            endcase
        end
    endfunction

    function automatic integer signed_pattern_b;
        input integer row;
        input integer col;
        begin
            case ((row % 4)*4 + (col % 4))
                0:  signed_pattern_b = 3;
                1:  signed_pattern_b = -1;
                2:  signed_pattern_b = 2;
                3:  signed_pattern_b = -2;
                4:  signed_pattern_b = -3;
                5:  signed_pattern_b = 2;
                6:  signed_pattern_b = 0;
                7:  signed_pattern_b = 1;
                8:  signed_pattern_b = 1;
                9:  signed_pattern_b = -2;
                10: signed_pattern_b = -1;
                11: signed_pattern_b = 3;
                12: signed_pattern_b = 0;
                13: signed_pattern_b = 1;
                14: signed_pattern_b = -3;
                default: signed_pattern_b = -1;
            endcase
        end
    endfunction

    task automatic load_signed_directed;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = signed_pattern_a(i, j);
                    b[i][j] = signed_pattern_b(i, j);
                end
            end
        end
    endtask

    function automatic integer limit_pattern_a;
        input integer row;
        input integer col;
        begin
            case ((row % 4)*4 + (col % 4))
                0:  limit_pattern_a = 127;
                1:  limit_pattern_a = -128;
                2:  limit_pattern_a = 3;
                3:  limit_pattern_a = -4;
                4:  limit_pattern_a = -1;
                5:  limit_pattern_a = 126;
                6:  limit_pattern_a = -127;
                7:  limit_pattern_a = 2;
                8:  limit_pattern_a = 64;
                9:  limit_pattern_a = -32;
                10: limit_pattern_a = 16;
                11: limit_pattern_a = -8;
                12: limit_pattern_a = -128;
                13: limit_pattern_a = 1;
                14: limit_pattern_a = 0;
                default: limit_pattern_a = 127;
            endcase
        end
    endfunction

    function automatic integer limit_pattern_b;
        input integer row;
        input integer col;
        begin
            case ((row % 4)*4 + (col % 4))
                0:  limit_pattern_b = -1;
                1:  limit_pattern_b = 2;
                2:  limit_pattern_b = -3;
                3:  limit_pattern_b = 4;
                4:  limit_pattern_b = 127;
                5:  limit_pattern_b = -128;
                6:  limit_pattern_b = 1;
                7:  limit_pattern_b = -2;
                8:  limit_pattern_b = -64;
                9:  limit_pattern_b = 32;
                10: limit_pattern_b = -16;
                11: limit_pattern_b = 8;
                12: limit_pattern_b = 7;
                13: limit_pattern_b = -6;
                14: limit_pattern_b = 5;
                default: limit_pattern_b = -4;
            endcase
        end
    endfunction

    task automatic load_near_width_limits;
        integer i;
        integer j;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    a[i][j] = limit_pattern_a(i, j);
                    b[i][j] = limit_pattern_b(i, j);
                end
            end
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

    task automatic start_and_measure;
        output integer n_cycles;
        output integer m_cycles;
        output integer n_timed_out;
        output integer m_timed_out;
        integer elapsed_cycles;
        begin
            n_cycles = 0;
            m_cycles = 0;
            n_timed_out = 0;
            m_timed_out = 0;
            elapsed_cycles = 0;

            @(negedge clk);
            start = 1'b1;

            // The following positive edge accepts start. It is not a compute
            // cycle, so elapsed_cycles begins on the next positive edge.
            @(posedge clk);
            #1;

            @(negedge clk);
            start = 1'b0;

            while (((n_cycles == 0) || (m_cycles == 0)) &&
                    (elapsed_cycles < TIMEOUT_CYCLES)) begin
                @(posedge clk);
                #1;
                elapsed_cycles = elapsed_cycles + 1;

                if (done_n && (n_cycles == 0)) begin
                    n_cycles = elapsed_cycles;
                end

                if (done_m && (m_cycles == 0)) begin
                    m_cycles = elapsed_cycles;
                end
            end

            if (n_cycles == 0) begin
                n_timed_out = 1;
            end

            if (m_cycles == 0) begin
                m_timed_out = 1;
            end
        end
    endtask

    task automatic check_outputs;
        input string test_name;
        input integer n_cycles;
        input integer m_cycles;
        input integer n_timed_out;
        input integer m_timed_out;
        output integer case_errors;
        integer i;
        integer j;
        begin
            case_errors = 0;

            if (n_timed_out) begin
                $display("ERROR: %s: N-multiplier DUT timed out", test_name);
                case_errors = case_errors + 1;
            end
            else if (n_cycles != N_EXPECTED_CYCLES) begin
                $display("ERROR: %s: N-multiplier cycle mismatch, expected %0d, got %0d",
                    test_name, N_EXPECTED_CYCLES, n_cycles);
                case_errors = case_errors + 1;
            end

            if (m_timed_out) begin
                $display("ERROR: %s: M-multiplier DUT timed out", test_name);
                case_errors = case_errors + 1;
            end
            else if (m_cycles != M_EXPECTED_CYCLES) begin
                $display("ERROR: %s: M-multiplier cycle mismatch, expected %0d, got %0d",
                    test_name, M_EXPECTED_CYCLES, m_cycles);
                case_errors = case_errors + 1;
            end

            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (c_n[i][j] !== expected[i][j]) begin
                        $display("ERROR: %s: N-multiplier C[%0d][%0d], expected %0d, got %0d",
                            test_name, i, j, expected[i][j], c_n[i][j]);
                        case_errors = case_errors + 1;
                    end

                    if (c_m[i][j] !== expected[i][j]) begin
                        $display("ERROR: %s: M-multiplier C[%0d][%0d], expected %0d, got %0d",
                            test_name, i, j, expected[i][j], c_m[i][j]);
                        case_errors = case_errors + 1;
                    end
                end
            end

            if (case_errors == 0) begin
                $display("PASS: %-28s | N=%0d: %0d cycles | M=%0d: %0d cycles",
                    test_name, N, n_cycles, M, m_cycles);
            end
            else begin
                $display("FAIL: %s had %0d issue(s)", test_name, case_errors);
            end
        end
    endtask

    task automatic run_case;
        input string test_name;
        integer n_cycles;
        integer m_cycles;
        integer n_timed_out;
        integer m_timed_out;
        integer case_errors;
        begin
            total_cases = total_cases + 1;
            calculate_expected();
            start_and_measure(n_cycles, m_cycles, n_timed_out, m_timed_out);
            check_outputs(test_name, n_cycles, m_cycles, n_timed_out,
                m_timed_out, case_errors);

            total_errors = total_errors + case_errors;
            total_n_cycles = total_n_cycles + n_cycles;
            total_m_cycles = total_m_cycles + m_cycles;
        end
    endtask

    initial begin
        total_cases = 0;
        total_errors = 0;
        total_n_cycles = 0;
        total_m_cycles = 0;
        random_seed = 32'h31415926;
        cycle_speedup = 0.0;
        cycle_reduction_percent = 0.0;
        break_even_fmax_percent = 0.0;

        if (!((M > N) && (M < 2*N))) begin
            $display("CONFIGURATION ERROR: comparison requires N < M < 2*N");
            $display("                     current N = %0d, M = %0d", N, M);
            $finish;
        end

        reset_duts();

        $display("============================================================");
        $display("N-multiplier versus M-multiplier comparison");
        $display("WIDTH = %0d, N = %0d, M = %0d", WIDTH, N, M);
        $display("Expected cycles: N architecture = %0d, M architecture = %0d",
            N_EXPECTED_CYCLES, M_EXPECTED_CYCLES);
        $display("============================================================");

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

        $display("============================================================");
        if (total_errors == 0) begin
            cycle_speedup = $itor(total_n_cycles) / $itor(total_m_cycles);
            cycle_reduction_percent =
                100.0 * $itor(N_EXPECTED_CYCLES-M_EXPECTED_CYCLES) /
                $itor(N_EXPECTED_CYCLES);
            break_even_fmax_percent =
                100.0 * $itor(M_EXPECTED_CYCLES) /
                $itor(N_EXPECTED_CYCLES);
            $display("OVERALL PASS: both architectures passed %0d cases", total_cases);
            $display("Total active cycles: N architecture = %0d", total_n_cycles);
            $display("Total active cycles: M architecture = %0d", total_m_cycles);
            $display("Ideal cycle-count speedup from M architecture = %0.3f x",
                cycle_speedup);
            $display("Per-operation cycle reduction = %0d of %0d cycles (%0.2f%%)",
                N_EXPECTED_CYCLES-M_EXPECTED_CYCLES,
                N_EXPECTED_CYCLES,
                cycle_reduction_percent);
            $display("Wall-clock break-even: M Fmax must exceed %0.2f%% of N Fmax",
                break_even_fmax_percent);
        end
        else begin
            $display("OVERALL FAIL: %0d issue(s) across %0d case(s)",
                total_errors, total_cases);
        end
        $display("============================================================");

        $finish;
    end
endmodule
