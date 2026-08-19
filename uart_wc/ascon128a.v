module top_dht11_ascon_uart(
    input  wire clk,
    input  wire rst,
    input  wire btnu,
    input  wire btnd,

    // ASIC IO split
    input  wire dht_in,
    output wire dht_out,
    output wire dht_oe,

    output wire tx,
    output wire [3:0] led
);

//////////////////////////////////////////////////
// BUTTON EDGE DETECTION
//////////////////////////////////////////////////
reg bu_d, bd_d;
always @(posedge clk or posedge rst) begin
    if(rst) begin 
        bu_d <= 0; 
        bd_d <= 0; 
    end
    else begin 
        bu_d <= btnu; 
        bd_d <= btnd; 
    end
end

wire enc_btn = btnu & ~bu_d;
wire dec_btn = btnd & ~bd_d;

//////////////////////////////////////////////////
// NONCE
//////////////////////////////////////////////////
reg [127:0] nonce_counter;
reg [127:0] nonce_used;

//////////////////////////////////////////////////
// PLAINTEXT STORAGE
//////////////////////////////////////////////////
reg [127:0] plaintext_reg;

wire [127:0] associated_data =
    128'h4261737973335F4173636F6E41454144;

reg enc_start, dec_start;

//////////////////////////////////////////////////
// ASCON SIGNALS
//////////////////////////////////////////////////
wire [127:0] cipher_w, tag_w;
wire enc_done;

wire [127:0] dec_text_w;
wire auth_ok_w;
wire dec_done;

reg [127:0] cipher_reg, tag_reg;
reg [127:0] dec_text_reg;
reg auth_ok;

//////////////////////////////////////////////////
// DHT SENSOR
//////////////////////////////////////////////////
wire [7:0] temp_raw, hum_raw;
wire valid;

dht11_timing_correct DHT(
    .clk(clk),
    .rst(rst),
    .dht_in(dht_in),
    .dht_out(dht_out),
    .dht_oe(dht_oe),
    .temperature(temp_raw),
    .humidity(hum_raw),
    .valid(valid)
);

reg [7:0] temp, hum;

always @(posedge clk or posedge rst) begin
    if(rst) begin 
        temp <= 0; 
        hum  <= 0; 
    end
    else if(valid) begin 
        temp <= temp_raw; 
        hum  <= hum_raw; 
    end
end

//////////////////////////////////////////////////
// PLAINTEXT
//////////////////////////////////////////////////
wire [7:0] t_tens = (temp/10) + 8'h30;
wire [7:0] t_ones = (temp%10) + 8'h30;
wire [7:0] h_tens = (hum/10)  + 8'h30;
wire [7:0] h_ones = (hum%10)  + 8'h30;

wire [127:0] plaintext = {
    "T","=",t_tens,t_ones,"C"," ",
    "H","=",h_tens,h_ones,"%",
    40'h0
};

//////////////////////////////////////////////////
// SYSTEM FSM
//////////////////////////////////////////////////
localparam S_IDLE=0,S_WAIT_ENC_DONE=1,S_READY_DEC=2,S_WAIT_DEC_DONE=3;
reg [1:0] sys_state;

always @(posedge clk or posedge rst) begin
if(rst) begin
    sys_state <= S_IDLE;
    nonce_counter <= 0;
    nonce_used <= 0;
    enc_start <= 0;
    dec_start <= 0;
end 
else begin

    enc_start <= 0;
    dec_start <= 0;

    case(sys_state)

    S_IDLE:
    if(enc_btn) begin
        nonce_counter <= nonce_counter + 16;
        nonce_used    <= nonce_counter + 16;
        plaintext_reg <= plaintext;
        enc_start     <= 1;
        sys_state     <= S_WAIT_ENC_DONE;
    end

    S_WAIT_ENC_DONE:
    if(enc_done) begin
        cipher_reg <= cipher_w;
        tag_reg    <= tag_w;
        sys_state  <= S_READY_DEC;
    end

    S_READY_DEC:
    if(dec_btn) begin
        dec_start <= 1;
        sys_state <= S_WAIT_DEC_DONE;
    end

    S_WAIT_DEC_DONE:
    if(dec_done) begin
        dec_text_reg <= dec_text_w;
        auth_ok      <= auth_ok_w;
        sys_state    <= S_IDLE;
    end

    endcase
end
end

//////////////////////////////////////////////////
// ASCON
//////////////////////////////////////////////////
ascon128a_aead ENC(
    .clk(clk), .rst(rst), .start(enc_start),
    .key(128'h000102030405060708090A0B0C0D0E0F),
    .nonce(nonce_used),
    .ad(associated_data),
    .plaintext(plaintext_reg),
    .ciphertext(cipher_w),
    .tag(tag_w),
    .done(enc_done)
);

ascon128a_aead_dec DEC(
    .clk(clk), .rst(rst), .start(dec_start),
    .key(128'h000102030405060708090A0B0C0D0E0F),
    .nonce(nonce_used),
    .ad(associated_data),
    .ciphertext(cipher_reg),
    .tag_in(tag_reg),
    .plaintext(dec_text_w),
    .auth_ok(auth_ok_w),
    .done(dec_done)
);

assign led = auth_ok ? 4'b1111 : 4'b0000;

//////////////////////////////////////////////////
// UART DRIVER (EDGE-TRIGGERED FIXED)
//////////////////////////////////////////////////
reg send;
reg [7:0] uart_data;
wire busy;

reg enc_done_d;

always @(posedge clk or posedge rst) begin
    if(rst)
        enc_done_d <= 0;
    else
        enc_done_d <= enc_done;
end

wire enc_done_pulse = enc_done & ~enc_done_d;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        send <= 0;
        uart_data <= 8'h00;
    end
    else begin
        if(enc_done_pulse) begin
            uart_data <= cipher_w[127:120];
            send <= 1;
        end
        else begin
            send <= 0;
        end
    end
end

//////////////////////////////////////////////////
// UART (CLOCK GATED)
//////////////////////////////////////////////////
uart_tx_icg UART(
    .clk(clk),
    .rst(rst),
 // .clk_en(send | busy),
    .send(send),
    .data(uart_data),
    .tx(tx),
    .busy(busy)
);

endmodule


//////////////////////////////////////////////////////////////
// DHT11 (ASIC FIXED IO)
//////////////////////////////////////////////////////////////
module dht11_timing_correct(
    input  wire clk,
    input  wire rst,
    input  wire dht_in,
    output reg  dht_out,
    output reg  dht_oe,
    output reg  [7:0] temperature,
    output reg  [7:0] humidity,
    output reg  valid
);

reg [6:0] div;
reg tick_1us;

always @(posedge clk or posedge rst) begin
    if(rst) begin div<=0; tick_1us<=0; end
    else begin
        if(div==99) begin div<=0; tick_1us<=1; end
        else begin div<=div+1; tick_1us<=0; end
    end
end

reg [3:0] state;
reg [31:0] cnt;
reg [5:0] bit_cnt;
reg [39:0] data;

localparam IDLE=0,START_LOW=1,START_HIGH=2,RESP_LOW=3,RESP_HIGH=4,READ_BITS=5,DONE=6;

always @(posedge clk or posedge rst) begin
if(rst) begin
    state<=IDLE; cnt<=0; bit_cnt<=0; data<=0;
    valid<=0; temperature<=0; humidity<=0;
    dht_oe<=1; dht_out<=1;
end
else if(tick_1us) begin

case(state)

IDLE: begin
    valid<=0;
    dht_oe<=1; dht_out<=1;
    cnt<=cnt+1;
    if(cnt>1000000) begin cnt<=0; dht_out<=0; state<=START_LOW; end
end

START_LOW: if(cnt<18000) cnt<=cnt+1;
else begin cnt<=0; dht_out<=1; state<=START_HIGH; end

START_HIGH: if(cnt<30) cnt<=cnt+1;
else begin cnt<=0; dht_oe<=0; state<=RESP_LOW; end

RESP_LOW: if(dht_in==0) state<=RESP_HIGH;

RESP_HIGH: if(dht_in==1) cnt<=cnt+1;
else if(cnt>70) begin cnt<=0; bit_cnt<=0; state<=READ_BITS; end

READ_BITS: begin
    if(dht_in==1) cnt<=cnt+1;
    else if(cnt>0) begin
        data <= {data[38:0], (cnt>40)};
        bit_cnt<=bit_cnt+1;
        cnt<=0;
        if(bit_cnt==39) state<=DONE;
    end
end

DONE: begin
    humidity<=data[39:32];
    temperature<=data[23:16];
    valid<=1;
    state<=IDLE;
end

endcase
end
end
endmodule


module ascon128a_aead(
    input wire clk,
    input wire rst,
    input wire start,

    input wire [127:0] key,
    input wire [127:0] nonce,
    input wire [127:0] ad,
    input wire [127:0] plaintext,

    output reg [127:0] ciphertext,
    output reg [127:0] tag,
    output reg done
);

localparam IV = 64'h00001000808C0001;

reg [63:0] S0,S1,S2,S3,S4;
reg [3:0] round;
reg [4:0] state;

wire [319:0] perm_in  = {S0,S1,S2,S3,S4};
wire [319:0] perm_out;

ascon_perm P(.s_in(perm_in), .round(round), .s_out(perm_out));

localparam IDLE=0,
           INIT_P12=1,
           KEY_MIX1=2,
           AD_ABSORB=3,
           AD_P6=4,
           DOMAIN=5,
           PT_ABSORB=6,
           PT_P6=7,
           FINAL_KEY1=8,
           FINAL_P12=9,
           FINAL_KEY2=10;

always @(posedge clk or posedge rst)
begin
if(rst) begin
    S0<=0; S1<=0; S2<=0; S3<=0; S4<=0;
    round<=0; state<=IDLE; done<=0;
end
else begin
    done<=0;

case(state)

IDLE:
if(start) begin
    S0 <= IV;
    S1 <= key[127:64];
    S2 <= key[63:0];
    S3 <= nonce[127:64];
    S4 <= nonce[63:0];
    round <= 0;
    state <= INIT_P12;
end

INIT_P12:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;
    if(round == 11) begin
        round <= 0;
        state <= KEY_MIX1;
    end
end

KEY_MIX1:
begin
    S3 <= S3 ^ key[127:64];
    S4 <= S4 ^ key[63:0];
    state <= AD_ABSORB;
end

AD_ABSORB:
begin
    S0 <= S0 ^ ad[127:64];
    S1 <= S1 ^ ad[63:0];
    state <= AD_P6;
end

AD_P6:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;
    if(round == 5) begin
        round <= 0;
        state <= DOMAIN;
    end
end

DOMAIN:
begin
    S4 <= S4 ^ 64'h1;
    state <= PT_ABSORB;
end

PT_ABSORB:
begin
    ciphertext[127:64] <= plaintext[127:64] ^ S0;
    ciphertext[63:0]   <= plaintext[63:0]   ^ S1;

    S0 <= plaintext[127:64] ^ S0;
    S1 <= plaintext[63:0]   ^ S1;

    state <= PT_P6;
end

PT_P6:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;
    if(round == 5) begin
        round <= 0;
        state <= FINAL_KEY1;
    end
end

// ? FIX STARTS HERE

FINAL_KEY1:
begin
    S2 <= S2 ^ key[127:64];
    S3 <= S3 ^ key[63:0];
    state <= FINAL_P12;
end

FINAL_P12:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;

    if(round == 11) begin
        round <= 0;
        state <= FINAL_KEY2;
    end
end

FINAL_KEY2:
begin
    S3 <= S3 ^ key[127:64];
    S4 <= S4 ^ key[63:0];

    tag <= {S3,S4};   // ? Correct
    done <= 1;
    state <= IDLE;
end

endcase
end
end

endmodule

module ascon_perm(
    input  [319:0] s_in,
    input  [3:0]   round,      // 0 to 11
    output [319:0] s_out
);

//////////////////////////////////////////////////
// Internal state
//////////////////////////////////////////////////
reg [63:0] x0,x1,x2,x3,x4;
reg [63:0] t0,t1,t2,t3,t4;

//////////////////////////////////////////////////
// ASIC-SAFE ROUND CONSTANT (NO initial block)
//////////////////////////////////////////////////
wire [7:0] RC;

assign RC =
    (round==0)  ? 8'hF0 :
    (round==1)  ? 8'hE1 :
    (round==2)  ? 8'hD2 :
    (round==3)  ? 8'hC3 :
    (round==4)  ? 8'hB4 :
    (round==5)  ? 8'hA5 :
    (round==6)  ? 8'h96 :
    (round==7)  ? 8'h87 :
    (round==8)  ? 8'h78 :
    (round==9)  ? 8'h69 :
    (round==10) ? 8'h5A :
                  8'h4B;

//////////////////////////////////////////////////
// Combinational permutation logic
//////////////////////////////////////////////////
always @(*) begin

    // Unpack
    x0 = s_in[319:256];
    x1 = s_in[255:192];
    x2 = s_in[191:128];
    x3 = s_in[127:64];
    x4 = s_in[63:0];

    //////////////////////////////////////////////////
    // Add round constant
    //////////////////////////////////////////////////
    x2 = x2 ^ {56'd0, RC};

    //////////////////////////////////////////////////
    // Substitution layer (S-box)
    //////////////////////////////////////////////////
    x0 = x0 ^ x4;
    x4 = x4 ^ x3;
    x2 = x2 ^ x1;

    t0 = ~x0 & x1;
    t1 = ~x1 & x2;
    t2 = ~x2 & x3;
    t3 = ~x3 & x4;
    t4 = ~x4 & x0;

    x0 = x0 ^ t1;
    x1 = x1 ^ t2;
    x2 = x2 ^ t3;
    x3 = x3 ^ t4;
    x4 = x4 ^ t0;

    x1 = x1 ^ x0;
    x0 = x0 ^ x4;
    x3 = x3 ^ x2;
    x2 = ~x2;

    //////////////////////////////////////////////////
    // Linear diffusion layer
    //////////////////////////////////////////////////
    x0 = x0 ^ (x0 >> 19) ^ (x0 >> 28);
    x1 = x1 ^ (x1 >> 61) ^ (x1 >> 39);
    x2 = x2 ^ (x2 >> 1)  ^ (x2 >> 6);
    x3 = x3 ^ (x3 >> 10) ^ (x3 >> 17);
    x4 = x4 ^ (x4 >> 7)  ^ (x4 >> 41);

end

//////////////////////////////////////////////////
// Pack output
//////////////////////////////////////////////////
assign s_out = {x0,x1,x2,x3,x4};

endmodule

module ascon128a_aead_dec(
    input wire clk,
    input wire rst,
    input wire start,

    input wire [127:0] key,
    input wire [127:0] nonce,
    input wire [127:0] ad,
    input wire [127:0] ciphertext,
    input wire [127:0] tag_in,

    output reg [127:0] plaintext,
    output reg auth_ok,
    output reg done
);

localparam IV = 64'h00001000808C0001;

reg [63:0] S0,S1,S2,S3,S4;
reg [3:0] round;
reg [4:0] state;

wire [319:0] perm_in  = {S0,S1,S2,S3,S4};
wire [319:0] perm_out;

ascon_perm P(.s_in(perm_in), .round(round), .s_out(perm_out));

localparam IDLE=0,
           INIT_P12=1,
           KEY_MIX1=2,
           AD_ABSORB=3,
           AD_P6=4,
           DOMAIN=5,
           PT_PROCESS=6,
           PT_P6=7,
           FINAL_KEY1=8,
           FINAL_P12=9,
           FINAL_KEY2=10;

always @(posedge clk or posedge rst)
begin
if(rst) begin
    S0<=0; S1<=0; S2<=0; S3<=0; S4<=0;
    round<=0; state<=IDLE;
    done<=0; auth_ok<=0;
end
else begin
    done<=0;

case(state)

IDLE:
if(start) begin
    S0 <= IV;
    S1 <= key[127:64];
    S2 <= key[63:0];
    S3 <= nonce[127:64];
    S4 <= nonce[63:0];
    round <= 0;
    state <= INIT_P12;
end

INIT_P12:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;
    if(round == 11) begin
        round <= 0;
        state <= KEY_MIX1;
    end
end

KEY_MIX1:
begin
    S3 <= S3 ^ key[127:64];
    S4 <= S4 ^ key[63:0];
    state <= AD_ABSORB;
end

AD_ABSORB:
begin
    S0 <= S0 ^ ad[127:64];
    S1 <= S1 ^ ad[63:0];
    state <= AD_P6;
end

AD_P6:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;
    if(round == 5) begin
        round <= 0;
        state <= DOMAIN;
    end
end

DOMAIN:
begin
    S4 <= S4 ^ 64'h1;
    state <= PT_PROCESS;
end

PT_PROCESS:
begin
    plaintext[127:64] <= ciphertext[127:64] ^ S0;
    plaintext[63:0]   <= ciphertext[63:0]   ^ S1;

    S0 <= ciphertext[127:64];
    S1 <= ciphertext[63:0];

    state <= PT_P6;
end

PT_P6:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;
    if(round == 5) begin
        round <= 0;
        state <= FINAL_KEY1;
    end
end

FINAL_KEY1:
begin
    S2 <= S2 ^ key[127:64];
    S3 <= S3 ^ key[63:0];
    state <= FINAL_P12;
end

FINAL_P12:
begin
    {S0,S1,S2,S3,S4} <= perm_out;
    round <= round + 1;

    if(round == 11) begin
        round <= 0;
        state <= FINAL_KEY2;
    end
end

FINAL_KEY2:
begin
    S3 <= S3 ^ key[127:64];
    S4 <= S4 ^ key[63:0];

    auth_ok <= ({S3,S4} == tag_in);  // ? Correct
    done <= 1;
    state <= IDLE;
end

endcase
end
end

endmodule



module uart_tx_icg
#(
parameter CLK_FREQ = 100_000_000,
parameter BAUD     = 9600
)
(
input  wire clk,
input  wire rst,
input  wire send,
input  wire [7:0] data,
output reg  tx,
output reg  busy
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

reg [31:0] clk_cnt = 0;
reg [3:0]  bit_index = 0;
reg [9:0]  shifter = 10'b1111111111;

//////////////////////////////////////////////////
// CLOCK GATING ENABLE
//////////////////////////////////////////////////

wire en;
assign en = send | busy;

//////////////////////////////////////////////////
// ICG CELL (REPLACE NAME WITH YOUR LIB CELL)
//////////////////////////////////////////////////

wire gclk;

//  Replace LAGCE_CELL with actual library cell name
LAGCEPOM2DP u_icg (
.CLK (clk),
.EN  (en),
.GCLK(gclk)
);

//////////////////////////////////////////////////
// UART LOGIC USING GATED CLOCK
//////////////////////////////////////////////////

always @(posedge gclk or posedge rst)
begin
if(rst) begin
tx        <= 1'b1;
busy      <= 0;
clk_cnt   <= 0;
bit_index <= 0;
shifter   <= 10'b1111111111;
end
else begin


    ////////////////// START //////////////////
    if(send && !busy) begin
        shifter   <= {1'b1, data, 1'b0};
        busy      <= 1;
        clk_cnt   <= 0;
        bit_index <= 0;
    end

    ////////////////// TRANSMIT //////////////////
    else if(busy) begin
        if(clk_cnt < CLKS_PER_BIT - 1)
            clk_cnt <= clk_cnt + 1;
        else begin
            clk_cnt <= 0;

            tx <= shifter[0];
            shifter <= shifter >> 1;
            bit_index <= bit_index + 1;

            if(bit_index == 9) begin
                busy <= 0;
                tx   <= 1'b1;
            end
        end
    end

end


end

endmodule

