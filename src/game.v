`default_nettype none

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // ==========================================
  // 1. VGA & Direct Input Setup 
  // ==========================================
  wire hsync, vsync, video_active;
  wire [1:0] R, G, B;
  wire [9:0] pix_x, pix_y;

  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Direct button inputs from ui_in:
  // ui_in[0] = Move UP
  // ui_in[1] = Move DOWN
  // ui_in[2] = Start / Restart after Game Over
  wire inp_up    = ui_in[0];
  wire inp_down  = ui_in[1];
  wire inp_start = ui_in[2];

  wire _unused_ok = &{ena, ui_in[7:3], uio_in};

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // ==========================================
  // 2. Game Parameters & Registers
  // ==========================================
  localparam PLAYER_X         = 10'd64;
  localparam PLAYER_SIZE      = 10'd24;
  localparam PLAYER_SPEED     = 10'd4;

  localparam ENEMY_SIZE       = 10'd24;
  localparam ENEMY_INIT_SPEED = 10'd5;
  localparam ENEMY_MAX_SPEED  = 10'd15;

  localparam NEW_GAME  = 2'b00;
  localparam PLAY      = 2'b01;
  localparam GAME_OVER = 2'b10;

  reg [1:0] state = NEW_GAME;
  reg [9:0] player_y;
  reg [9:0] enemy_x, enemy_y;

  reg [9:0] enemy_speed;
  reg [3:0] hit_count;
  reg [7:0] score;

  wire hit = (enemy_x < PLAYER_X + PLAYER_SIZE) &&
             (enemy_x + ENEMY_SIZE > PLAYER_X) &&
             (enemy_y < player_y + PLAYER_SIZE) &&
             (enemy_y + ENEMY_SIZE > player_y);

  // ==========================================
  // 3. Game Logic (1 Frame per Update)
  // ==========================================
  always @(posedge vsync) begin
    if (!rst_n) begin
      state <= NEW_GAME;
    end else begin
      case (state)
        NEW_GAME: begin
          player_y    <= 10'd228;
          enemy_x     <= 10'd640;
          enemy_y     <= 10'd200;
          enemy_speed <= ENEMY_INIT_SPEED;
          hit_count   <= 4'd0;
          score       <= 8'd0;
          state       <= PLAY;
        end

        PLAY: begin
          // Player Up/Down movement
          if (inp_down && !inp_up) begin
            if (player_y + PLAYER_SIZE + PLAYER_SPEED >= 10'd479)
              player_y <= 10'd480 - PLAYER_SIZE;
            else
              player_y <= player_y + PLAYER_SPEED;
          end else if (inp_up && !inp_down) begin
            if (player_y < PLAYER_SPEED)
              player_y <= 10'd0;
            else
              player_y <= player_y - PLAYER_SPEED;
          end

          // Catch = +1 score & speed up every 10 catches
          if (hit) begin
            score   <= score + 8'd1;
            enemy_x <= 10'd640;

            if (enemy_y + 10'd113 >= 10'd480 - ENEMY_SIZE)
              enemy_y <= (enemy_y + 10'd113) - (10'd480 - ENEMY_SIZE);
            else
              enemy_y <= enemy_y + 10'd113;

            if (hit_count == 4'd9) begin
              hit_count <= 4'd0;
              if (enemy_speed < ENEMY_MAX_SPEED)
                enemy_speed <= enemy_speed + 10'd1;
            end else begin
              hit_count <= hit_count + 4'd1;
            end

          // Miss = GAME_OVER
          end else if (enemy_x < enemy_speed) begin
            state <= GAME_OVER;

          // Keep moving left
          end else begin
            enemy_x <= enemy_x - enemy_speed;
          end
        end

        GAME_OVER: begin
          if (inp_start)
            state <= NEW_GAME;
        end

        default: state <= NEW_GAME;
      endcase
    end
  end

  // ==========================================
  // 4. Drawing & Colors
  // ==========================================
  wire draw_player = (pix_x >= PLAYER_X) && (pix_x < PLAYER_X + PLAYER_SIZE) &&
                     (pix_y >= player_y) && (pix_y < player_y + PLAYER_SIZE);

  wire draw_enemy  = (pix_x >= enemy_x)  && (pix_x < enemy_x + ENEMY_SIZE) &&
                     (pix_y >= enemy_y)  && (pix_y < enemy_y + ENEMY_SIZE);

  reg [5:0] color;

  always @(*) begin
    if (state == GAME_OVER) begin
      color = 6'b110000;       // GAME OVER: Red
    end else if (draw_player) begin
      color = 6'b001111;       // Player: Cyan
    end else if (draw_enemy) begin
      color = 6'b110000;       // Enemy: Red
    end else begin
      color = 6'b000000;       // Background: Black
    end
  end

  assign R = video_active ? color[5:4] : 2'b00;
  assign G = video_active ? color[3:2] : 2'b00;
  assign B = video_active ? color[1:0] : 2'b00;

endmodule
