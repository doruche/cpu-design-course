# 源码口试准备与复核记录

## 使用规则

本文是源码索引、提问清单和参考答案，不是逐字背诵稿。复习时应先合上答案，用自己的话
说明 owner、请求、完成事件、停顿/提交条件和失败路径，再打开参考答案与 live source
核对。自动测试只能证明其 oracle 覆盖的行为，不能替代设计理解。

AR1 负责冻结问题库、源码位置和待复习状态；用户随后要求补齐全部参考答案，以便针对性
复习。答案完成只表示材料可用，不表示用户已经理解或口试通过。无法解释的项目标为
`Re-read`；如果后续回读源码发现真实 RTL/协议缺陷，立即停止当时的检查点并回到产品
owner。

## Product 模块 owner map

```text
miniRV_SoC
├── U_clkgen: clk_wiz_0，100 MHz 输入 -> 50 MHz product clock
├── U_cpu: cpu_top
│   ├── U_core: cpu_core（single-cycle 或 five-stage pipeline truth）
│   ├── U_icache: ICache
│   ├── U_dcache: DCache
│   └── U_aximaster: cache-side request -> AXI4 master
├── U_interconnect: memory AXI / local MMIO 路由与错误响应
├── U_peripherals
│   ├── U_uart: UART register/FIFO/8N1
│   └── U_seven_segment: 八位十六进制扫描显示
└── U_bram: Vivado Block Memory Generator AXI4 IP
```

该 map 只表示模块 ownership，不是外部 owner 的数据通路图，也不替代报告图。

## 关键事件链

1. **取指**：pipeline `cpu_core` 发一个 outstanding fetch；ICache hit 直接返回，miss 以
   16-byte aligned read refill；返回可进入 IF/ID 或一项 skid buffer。
2. **普通 load**：EX/MEM 持有地址与 load op；MEM 只发一次请求，等待 DCache response；
   miss 经 AXI 四 beat refill，结果扩展后进入 MEM/WB。
3. **MMIO load/store**：`0xFFFF_xxxx` 在 DCache 中 uncached；AXI master 发 single beat；
   interconnect 路由到 peripherals 并返回 OKAY 或 DECERR。
4. **taken control transfer**：pipeline 静态 predict-not-taken；EX 得到 taken 后 redirect PC，
   清空 younger IF/ID，并丢弃已经发出但属于错误路径的 fetch response。
5. **mul/div**：EX 只 launch 一次，`busy` 期间 hold；busy 下降后 capture result，再允许该
   指令离开 EX，防止 level-sensitive `start` 重启运算单元。
6. **UART output**：CPU store 到 UART TX FIFO 寄存器；DCache uncached write 经 AXI/MMIO；
   UART FSM 依次发送 start、8 data bits、stop。
7. **CoreMark timing**：软件用 timer high-low-high 取得一致 64-bit snapshot；start/stop
   差值按 50 MHz 转为时间，UART 输出 CRC 和分数。

## Pipeline 与 CPU

### P1：五级状态在哪里

追问：五级分别由哪些寄存器边界表示？为什么 IF 另外需要 outstanding 状态和 skid
buffer？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:32-70,85-169`。

参考回答：五级不是五组寄存器，而是 IF/ID、ID/EX、EX/MEM、MEM/WB 四道边界加上边界
两侧的组合逻辑。`*_valid` 表示该级是否真有指令，bubble 只是 `valid=0`。IF 还必须维护
`fetch_pending/fetch_pc`，因为取指响应延迟无上界，CPU 需要明确拥有唯一 outstanding
request。响应回来时 IF/ID 可能被后级停顿占住，所以再用一项 skid buffer 暂存返回的
`pc/inst`；发请求条件保证 IF/ID 与 skid 不会同时已满。这样既不会丢迟到响应，也允许
前一响应返回与下一请求同拍交接，避免吞吐退化为两拍一条。

易错点：skid buffer 不是第二个 outstanding fetch；总线侧仍只有一个 outstanding，它只
保存已经返回但暂时放不进 IF/ID 的指令。

### P2：停顿优先级

追问：`mem_stall`、`md_stall`、`load_use_stall` 同时出现时，哪些 stage 更新？为什么较后级
停顿必须冻结较前级？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:72-83,390-404,465-474`。

参考回答：优先级由“越靠后越高”实现。`mem_stall=1` 时 EX/MEM 必须保留正在等待的访存，
因此 EX/MEM、ID/EX、IF/ID 都冻结，只有已有 MEM/WB 可以正常提交。只有 `md_stall=1` 时，
ID/EX 和 IF/ID 保持 M 指令及更年轻指令，EX/MEM 写入 bubble，让更老指令继续离开。只有
`load_use_stall=1` 时，load 从 EX 前进到 MEM，ID/EX 插入 bubble，消费者留在 IF/ID。
后级停顿必须冻结前级，否则年轻指令会越过尚未完成的老指令，或覆盖仍拥有 response 的
stage state。

易错点：load-use 不是把整个 pipeline 冻住；它必须允许 load 自己向 MEM 前进，才能在
随后产生可前递的数据。

### P3：数据前递与 load-use

追问：EX/MEM 与 MEM/WB 同时匹配时选谁？为什么 load 的直接消费者仍要停一拍？同一拍
WB 写回如何让 ID 看到新值？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:234-249,289-304`。

参考回答：EX 的选择顺序是 EX/MEM 优先、MEM/WB 次之、最后才用 ID/EX 保存值，因为
EX/MEM 是同一寄存器最新的生产者；所有比较都排除 `rd=x0`。load 在 EX/MEM 中只有地址，
真正的 load data 要等 MEM response 并进入 MEM/WB 后才存在，所以紧随 load 的消费者要
在 ID 停一拍，再使用 MEM/WB→EX 前递。同一时钟沿上 WB 写 RF、ID/EX 也锁存读值；为避免
读写同址时依赖具体 RF read-during-write 行为，ID 还有显式 WB bypass，直接选择
`mem_wb_result`。

易错点：不能把 `ex_mem_alu_result` 当成 load value，它是访存地址或普通 ALU 结果。

### P4：控制冒险

追问：预测策略是什么？branch/jal/jalr 在哪里解析？一个错误路径 fetch 已经 outstanding
时如何处理它的迟到 response？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:99-145,357-378`。

参考回答：预测策略是静态 not-taken；每次成功发取指请求时 PC 先走 `pc+4`。branch、jal、
jalr 都在 EX 解析，taken 且 ID/EX 本拍允许更新时产生 `flush`，PC 改为 `npc`，IF/ID 与
skid 清空。若错误路径 fetch 尚未返回，`fetch_discard` 被置位；若恰好同拍返回，
`fetch_keep` 因 `flush` 为假而直接丢弃。redirect 期间不发新请求，必须等旧 outstanding
response 被消费/丢弃后，才从正确 PC 继续。

易错点：`flush` 受 `id_ex_update` 限定。branch 被更老的 MEM stall 挡住时不能反复 redirect
或提前越过老指令。

### P5：Trace 看到什么

追问：为什么 Trace 信号连接到 MEM/WB commit 和实际 data request，而不是简单连接 decode
控制？Trace PASS 能否单独证明 MMIO？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:479-499`；
`cdp-tests/csrc/dut.h`；官方 Trace 说明明确外设不在 Trace 范围内。

参考回答：寄存器 Trace 来自 `mem_wb_valid & mem_wb_rf_we`，表示一条指令真的走到提交点；
store Trace 直接取实际脉冲 `daccess_wen/addr/data`。decode control 可能因 stall 保持多拍、
因 flush 作废，若直接接 decode 会把“意图”重复或错误地报告成架构事件。Trace driver 每拍
只读取这两类 public event 与 golden trace 比对。

Trace PASS 只证明指定测试程序在该配置下的寄存器提交和 store 事件匹配；AXI-direct
Trace 可以再覆盖 Cache/AXI 主存路径，但标准 Trace 不访问五类 MMIO，某些 profile 还绕过
product interconnect。因此它不能单独证明 UART、timer、LED 等外设，必须看 integration、
CPU-driven system 或用户板测。

易错点：Trace 中出现 data store event 不等于证明 store 的外设副作用；Trace 比较的是 CPU
边界事件，MMIO interconnect/peripheral 是否正确仍需自己的 oracle。

### S1：单周期产品如何等待多周期操作

追问：single-cycle core 为什么需要 `mem_pending`、`mul_div_pending` 和 captured fields？迟到
response 为什么不能无条件提交？

源码核对：`projects/single_cycle/src/rtl/cpu_core.v:73-82,153-173,211-255`。

参考回答：这里的“single-cycle”是数据通路形态，不代表外部 memory 和 mul/div 必须一拍
完成。`mem_pending`、`mul_div_pending` 是 completion owner：发起时置位，只有 owner 存在
时 `daccess_rvalid/daccess_wresp` 或 `!busy` 才能组成 `mem_done/mul_div_done`。因为
`ifetch_valid` 只保持一拍，模块还要捕获目的寄存器、load op 和地址低两位，迟到响应才能
用原指令语义做扩展和写回。normal 指令由 `ifetch_valid` 当拍完成；load 只在 pending read
response 时写回，store response 只结束指令不写 RF。

易错点：不能用裸 `rvalid` 或裸 `!busy` 提交。没有 matching pending owner 的迟到信号可能
属于 reset 前或别的事务，必须忽略。

## Cache

### C1：几何结构

追问：I/D Cache 的容量、line size、index/tag/offset 分别来自哪些位？为什么是 direct
mapped 1 KiB、16-byte line？

源码核对：`projects/pipeline/src/rtl/ICache.v:5-8,43-55`；
`projects/pipeline/src/rtl/DCache.v:5-8,58-66`。

参考回答：每个 cache 有 64 行，每行 128 bit=16 B，所以容量是 64×16 B=1 KiB；每个 index
只有一个 tag/data entry，因此是 direct mapped。对字节地址，两者都是 tag=`addr[31:10]`、
index=`addr[9:4]`、line 内 word offset=`addr[3:2]`，`addr[1:0]` 留给子字节访问。ICache
内部先保存 `addr[31:2]`，所以源码写成等价的 `[29:8]/[7:2]/[1:0]`。16-byte line 正好是
4 个 32-bit AXI beat，与 `IC/DC_BLK_LEN=4` 一致。

易错点：这里的“为什么”是当前冻结的产品参数和总线契合，不是说 1 KiB/direct-mapped 是
唯一可能设计。

### C2：ICache miss

追问：一次 miss 从 lookup 到 refill response 经哪些状态？请求地址为何清零低四位？何时
写 tag/data/valid，何时把所需 word 返回 CPU？

源码核对：`projects/pipeline/src/rtl/ICache.v:71-99,101-164`。

参考回答：IDLE 接收请求并保存 word address，LOOKUP 比 valid/tag；hit 直接按 offset 选
32-bit word。miss 进入 REFILL_REQ，`cpu_ren=4'hf`，地址拼成
`{req_word_addr[29:2],4'h0}`，即把低 4 位清零到 line base；总线接受后进入
REFILL_WAIT。`dev_rvalid` 到达时，同一个时钟沿写 data/tag/valid，同时组合输出直接从
`dev_rdata` 选出原请求 word 给 CPU，因此不需要再做一次 lookup。之后根据是否已有下一项
`inst_rreq` 回 LOOKUP 或 IDLE。

易错点：tag/data 只在完整 refill response 时写，valid reset 为 0；不能在发出 miss 请求时
就提前置 valid。

### C3：DCache policy

追问：为什么称为 write-through、no-write-allocate？write hit 时怎样保持 cache line 与
写到总线的数据一致？

源码核对：`projects/pipeline/src/rtl/DCache.v:82-104,145-159,194-260`。

参考回答：所有 store 都发到下层总线，所以是 write-through。若 store 命中且不是 MMIO，
总线接受 write 的同一时刻用 `req_wen` 对 resident 32-bit word 做 byte-mask merge，保证后续
read hit 不会读到旧值；总线仍收到原地址、原 strobe 和原数据。若 write miss，则只写下层
memory，不 refill、不改 tag/valid，也不驱逐当前同 index 的旧 line，所以是
no-write-allocate。write completion 要经历 ready 先变 busy 再恢复，才向 CPU 发
`data_wresp`。

易错点：no-write-allocate 不等于“write 永远不更新 cache”；write hit 必须更新已有 line。

### C4：为什么 MMIO uncached

追问：怎样识别 MMIO？MMIO read 为什么保留原地址和 byte enable、只读一个 32-bit beat？
如果把它按普通 cache line refill 会有什么副作用风险？

源码核对：`projects/pipeline/src/rtl/DCache.v:54-56,162-191,233-251`；
`projects/pipeline/src/rtl/axi_master.v:127-140`。

参考回答：`req_addr[31:16]==16'hffff` 就是 uncached MMIO。普通 miss 发 line-aligned 地址、
`ren=4'hf` 并请求 4 beat；MMIO 则保持原 byte address 和原 `req_ren`，AXI master 据高 16 位
把 `ARLEN` 设为 0，只取返回的低 32 bit，且 response 不写 cache tag/data/valid。这样
`lb/lh/lw` 的 byte address 与 enable 能一直传到设备边界。

若按 cache line refill，会把一次设备读取扩大成相邻 4 个寄存器读取并缓存结果；读 RX
FIFO 可能被多次 pop，timer/status 会变成陈旧值，甚至触发未定义 offset。MMIO 必须按每次
软件访问产生一次可见 side effect，不能被 hit 吞掉或被 speculative refill 扩大。

易错点：uncached 不是绕过 AXI；它仍走同一 AXI master，只是保持原请求形态并禁止 cache
line refill/命中复用。

## AXI 与多周期访存

### A1：仲裁

追问：bridge idle 时 write、DCache read、ICache read 的优先级是什么？当前为何只允许一个
cache-side transaction？

源码核对：`projects/pipeline/src/rtl/axi_master.v:5-8,102-111`。

参考回答：bridge 只有在 read/write 两个状态机都 idle 时才接收新事务，固定优先级是
DCache write > DCache read > ICache read。对应 ready 也用同样条件生成，因此同拍竞争只会
有一个 requester 被接受。当前 bridge 的地址、来源、beat 计数和 128-bit 暂存寄存器都只
有一份；串行化使一次事务从接受到 response 都有唯一 owner，也避免 I/D read 与 write 在
单组 AXI master channel 上交错后无法归属 response。

易错点：这是 cache-side 的串行化策略，不是 AXI 协议规定的唯一实现；AXI 本身允许更高
并发，但本设计没有 transaction ID 队列。

### A2：读事务

追问：cache refill 与 MMIO read 的 `ARLEN` 分别是多少？四个 read beat 如何拼成 128 bit，
何时向原 requester 发 `dev_rvalid`？

源码核对：`projects/pipeline/src/rtl/axi_master.v:116-179,256-271`。

参考回答：普通 ICache/DCache refill 的 `ARLEN=BLK_LEN-1=3`，表示 4 个 32-bit beat；
uncached MMIO read 的 `ARLEN=0`，只有 1 beat。每次 R handshake 依据 `read_beat` 把数据依次
写入 `read_data[31:0]`、`[63:32]`、`[95:64]`、`[127:96]`，最后一个带 `RLAST` 的 beat
使状态从 READ_DATA 进入 READ_RESP。到 READ_RESP 才按捕获的 `read_source` 对唯一原
requester 拉高一拍 `dev_rvalid` 并给出完整 128-bit 数据；MMIO 只使用低 32 bit。

易错点：`ARLEN` 是 beats-minus-one，不是 byte 数；`dev_rvalid` 也不是每个 AXI beat 都拉高。

### A3：写地址和写数据为何分开记账

追问：AW 与 W 可以不同拍握手时，`write_addr_done`/`write_data_done` 如何避免重复 VALID，
何时进入 B response？

源码核对：`projects/pipeline/src/rtl/axi_master.v:181-230,243-254`。

参考回答：AXI 的 AWREADY 与 WREADY 可独立出现，所以进入 WRITE_SEND 前先捕获地址、数据和
strobe，并把 `write_addr_done/write_data_done` 清零。某一路握手后对应 done 置位，组合
逻辑随即撤销该路 VALID，另一条路继续保持到自己的握手，从而不会重复发送。状态转移同时
检查“历史 done 或本拍 handshake”，所以两路同拍或分拍完成都能立即进入 WRITE_RESP；
之后才拉高 BREADY，等 BVALID 完成整个 store。

易错点：不能等 AW 和 W 同拍 ready；也不能在只完成其中一路时就等待 B response。

### A4：memory 与 MMIO 路由

追问：哪段地址进入 MMIO？合法 MMIO 请求形态是什么？不支持的 burst/size/strobe 怎样
消费并返回错误，为什么不能产生 peripheral side effect？

源码核对：`projects/pipeline/src/rtl/soc_interconnect.v:3-6,106-150,152-270,302-355`。

参考回答：地址高 16 位为 `0xFFFF` 时走本地 MMIO，其余请求透传给 AXI BRAM memory 侧。
合法 MMIO read 必须是 single-beat、32-bit、INCR，即 `ARLEN=0/ARSIZE=2/ARBURST=01`；合法
write 还要求 single-beat WLAST，并且 strobe 与地址低两位构成合法的 byte/half/word lane。
合法形态到达外设后，未定义 page/offset 或权限错误由 peripheral error 转成 AXI DECERR。

不合法 read 不触发 `mmio_rd_en`，而是按请求的 ARLEN 返回相同数量的零数据 DECERR beats；
不合法 write 会接收 W beat，只有 `write_data_is_supported` 才产生 `mmio_wr_en`，最后返回
DECERR。完整消费请求可避免 master 永久等待；用形态检查门控 peripheral enable 可确保
被拒绝的 burst/size/strobe 不会写 LED、pop UART FIFO 等。

易错点：非法 MMIO 不是“不握手”；必须把协议事务收尾，只是不能产生设备副作用。

### A5：pipeline MEM completion

追问：CPU 如何保证一个 load/store 只 issue 一次？`mem_done` 为什么必须以 `mem_issued` 为
前提？response 到达时哪些 pipeline register 才能推进？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:406-474`。

参考回答：EX/MEM 中的有效 load/store 令 `mem_needs=1`。仅当 `mem_issued=0` 时，
`mem_issue` 才把 `daccess_ren/wen/addr/data` 脉冲一个周期并置 `mem_issued=1`；等待期间请求
脉冲归零、EX/MEM 被 `mem_stall` 保持，因此不会重复 issue。`mem_done` 还必须要求
`mem_issued=1`，否则无 owner 的迟到或无关 `rvalid/wresp` 会错误完成当前指令。

matching response 到达时 `mem_stall` 解除：MEM/WB 锁存 load 扩展值或原 ALU 结果，
EX/MEM 才可接收下一条，连带 ID/EX 和 IF/ID 恢复推进；同一时钟沿 `mem_issued` 清零，为
下一项访存重新建立 owner。

易错点：request 是单拍脉冲，持有的是 EX/MEM transaction state，不是持续拉高 request。

## 乘法与除法

### M1：level start 与一次 launch

追问：ALU 的 `start` 是 level 而不是 pulse 时，pipeline 为什么需要 `md_launched` 和
`md_captured`？invalid bubble 为什么也必须撤销旧的 M op？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:306-344`。

参考回答：ALU 用操作码直接形成 multiplier/divider 的 level `start`。M 指令刚到 EX 时，
`md_present` 只成立一次，启动单元并置 `md_launched`；随后即使 ID/EX 因 `md_stall` 保持，
送进 ALU 的 op 也临时改成 ADD，避免单元 busy 结束后看到仍为高的 start 又启动一次。busy
下降时 `md_capture` 保存结果、撤销 launched 并置 `md_captured`，下一拍 M 指令才离开 EX；
ID/EX 更新时清除 captured，交给下一条指令。

bubble 的 `valid=0` 并不会自动清掉旧 decode fields。若只用 `ex_is_md` 撤销 op，invalid
bubble 仍可能把旧 M opcode 留给 ALU，在后续 live operation 后重启单元；所以
`ex_holds_md_op` 故意只看 decode field，不看 valid。

易错点：`md_captured` 不是第二次计算，它把“busy 已下降”和“结果已归属当前 EX 指令”隔开。

### M2：算法与延迟

追问：multiplier 每拍做什么 Booth step？divider 每拍如何生成 quotient bit？`busy` 在何时
拉高和拉低？

源码核对：`projects/pipeline/src/rtl/multiplier.v:35-94`；
`projects/pipeline/src/rtl/divider.v:33-92`。

参考回答：multiplier 是 radix-2 Booth。初始化 `{0,y,0}`，每拍看低两位：01 加被乘数、10
加其二补数、00/11 不变，然后对整个 partial product 算术右移一位；加/减和移位组合在
同一 cycle，运行 WIDTH 次。`start` 在 IDLE 被采样后 busy 拉高，最后一步锁存结果并回到
IDLE，busy 拉低。

divider 是恢复除法的 magnitude datapath：每拍把 remainder 左移并带入 quotient 的最高
待处理位，与 divisor 比较；够减就减并生成 quotient bit 1，否则保留并生成 0，再把该 bit
移入 quotient 低位。它对 32-bit magnitude 运行 32 步（模块实例 WIDTH=33，内部
MAG_WIDTH=32），最后附回 quotient/remainder sign 并清 busy。

易错点：乘法参数 WIDTH=32 时是 32 次 Booth step；有符号除法实例的 WIDTH=33 是“符号位
+ 32-bit magnitude”，不是做 33 个 quotient bit。

### M3：signed/unsigned 与除零

追问：signed division 的符号怎样拆成 magnitude 和 sign？除数为零时 DIV/REM 的 ISA 结果
如何返回？

源码核对：`projects/pipeline/src/rtl/ALU.v:27-37,39-58,80-95,122-145`。

参考回答：signed DIV/REM 先把 `a/b` 各自取绝对值，再把原 dividend sign、
`dividend_sign XOR divisor_sign` 随 magnitude 送进 divider；divider 输出 sign-magnitude，
ALU 再按 sign 转回二补数。因此 quotient 向零截断，remainder 与 dividend 同号。DIVU/REMU
则在 33-bit 输入前补 0，完全按无符号 magnitude 处理。

launch 时 ALU 还捕获原 dividend 和 `b==0`。除数为零后虽然底层迭代仍会结束，最终选择器
按 RISC-V 语义覆盖结果：DIV/DIVU 返回 `0xFFFF_FFFF`，REM/REMU 返回原 dividend。

易错点：除零不能用事后 remainder 还原 dividend；原操作数必须在多周期运算开始时捕获。

## MMIO、UART 与五外设

### U1：地址表与权限

追问：switch、LED、digital LED、UART、timer 地址分别是什么？哪些只读、哪些可写？非法
offset 最终返回什么 AXI response？

源码核对：`projects/pipeline/src/rtl/defines.vh:68-75`；
`projects/pipeline/src/rtl/soc_peripherals.v:79-130`；
`projects/pipeline/src/rtl/soc_interconnect.v:143-150`。

参考回答：五个 page base 是 switch `0xFFFF_0000`、LED `0xFFFF_1000`、digital LED
`0xFFFF_2000`、UART `0xFFFF_3000`、timer `0xFFFF_4000`。switch 只读；LED 和数码管的
base port 可读写；timer 只读，`+0..+3` 是 low、`+8..+B` 是 high；UART 的四个 word
offset 另见 U3。对只读设备写、未定义 page/offset、UART 不允许的方向，peripheral 拉高
error，interconnect 把成功形态的访问完成为 AXI DECERR (`2'b11`)。

易错点：整个 `0xFFFF_xxxx` 都会先被路由为 MMIO，但被路由不代表 offset 合法；设备 decode
仍会拒绝未实现位置。

### U2：switch、LED、数码管

追问：异步 switch 为什么要两级同步？subword LED/数码管写如何合并 byte lane？八个 digit
如何扫描，EGO1 输出极性是什么？

源码核对：`projects/pipeline/src/rtl/miniRV_SoC.v:39-52`；
`projects/pipeline/src/rtl/soc_peripherals.v:42-75,132-140`；
`projects/pipeline/src/rtl/seven_segment.v:3-56`。

参考回答：板上 switch 对 50 MHz 时钟是异步输入，先经过带 `ASYNC_REG` 属性的 meta、sync
两级寄存器，再作为稳定 level 暴露给 MMIO，以降低亚稳态传播风险。LED/数码管 store 保留
AXI byte strobe，`merge_bytes` 只替换被选中的 8-bit lane，因此 `sb/sh/sw` 可更新对应部分
而不破坏其余 byte。

数码管寄存器保存 32-bit、每个十六进制 digit 占 4 bit。19-bit free-running counter 的
`[18:16]` 轮流选择 8 个 nibble，同时 one-hot 选择对应 digit；译码表产生七段加小数点的
8-bit pattern。当前 EGO1 合同中 digit enable 与 segment 都是 active high。

易错点：两级同步适合慢速稳定开关 level，不等于能无损捕获任意短异步 pulse。

### U3：UART 寄存器和 FIFO

追问：四个寄存器 offset 的读写语义是什么？RX data read 何时 pop？TX/RX FIFO full 时
如何处理同拍 pop/push？

源码核对：`projects/pipeline/src/rtl/uart_peripheral.v:73-116,118-148,266-302`。

参考回答：offset `+0x0` 是 RX data；非空时 read handshake 返回队首并 pop，写入报错。
`+0x4` 是 TX data；读取固定为 0，`strb[0]` 有效的写把低 8 bit push。`+0x8` 是只读
status：RX valid/full、TX empty/full 和 interrupt-enable。`+0xC` 是 control：bit0 清 TX、
bit1 清 RX、bit4 设置 interrupt-enable；读取返回 enable。未定义 offset 或不允许的写方向
返回 error。

TX/RX FIFO 都是 16 byte。full 边界若同拍存在 pop/read，write 条件仍允许 push；指针各自
前进，count 的 `{push,pop}=11` 分支保持不变，既不误报 overflow，也不丢掉腾出的槽位。
clear 的优先级高于普通 FIFO 操作。

易错点：读取空 RX data 返回 0 但不会 pop；“RX valid”是非空，不是串口线上正在收 bit。

### U4：8N1 收发

追问：50 MHz/115200 如何得到 clocks per bit？TX/RX 分别怎样经过 start、8 data、stop？
RX 为什么在 start bit 中点复核，异步输入在哪里同步？

源码核对：`projects/pipeline/src/rtl/uart_peripheral.v:27-50,150-264`。

参考回答：`CLKS_PER_BIT=(50_000_000+115_200/2)/115_200=434`，用整数四舍五入逼近
115200 baud。TX 空闲为高；从 FIFO 取 byte 后发送 1 个低 start bit、按 LSB-first 发送 8
个 data bit、再发送 1 个高 stop bit，每段各保持 434 clocks。

RX 引脚先过 `rx_meta/rx_sync` 两级同步。检测到低电平后先等约半 bit，在 start bit 中点再
确认仍为低，以排除短毛刺；随后每隔一个 bit period 在各 data bit 中心采样 8 次，最后在
stop 时刻仅当同步输入为高且 FIFO 有空间时入队。

易错点：8N1 的 “N” 表示无 parity；stop bit 异常时当前实现丢弃该 byte，没有独立 framing
error 寄存器。

### U5：timer 与 CoreMark

追问：timer 是否可写？低/高字分别在哪些 offset？为什么两次独立读取不是原子 snapshot，
CoreMark 如何避免低 32 位 rollover 拼出错误时间？

源码核对：`projects/pipeline/src/rtl/soc_peripherals.v:34,59-65,108-116`；
`programs/c_test/4_coremark/src/coremark/core_portme.c` 的 `get_time()`。

参考回答：timer 是 reset 清零、此后每个 50 MHz cycle 加一的 64-bit free-running counter，
不可写；低 32 位在 `0xFFFF_4000 + 0`，高 32 位在 `+8`。两次 MMIO read 是独立事务，期间
counter 继续前进，所以先读 low、后读 high 恰遇 low rollover 时可能拼成“新 high + 旧
low”的错误大值，它们不是硬件原子 snapshot。

CoreMark 的 `get_time()` 采用 high-low-high：先读 high，再读 low，再重读 high；两次 high
不同就重试。相同则证明 low read 没跨越会改变 high 的 rollover，可安全拼成 64 bit。

易错点：该算法保证跨 low-word rollover 的一致性，但读到的仍是读取窗口内的一个合理
时刻，不是三次 load 同拍完成。

## 证据与边界追问

### E1：Trace、system、board 分别证明什么

核对点：Trace 是 CPU commit/store 差分，AXI Trace 覆盖主存链路但不覆盖外设；system suite
可自动覆盖 MMIO 和 transcript；只有用户记录能证明真实 EGO1 现象。

来源核对：`projects/pipeline/src/rtl/cpu_core.v:479-499`；`cdp-tests/csrc/dut.h`；
`tests/coremark/coremark_system_tb.sv`；`docs/acceptance/acceptance-matrix.md`。

参考回答：Trace 把 RTL 的寄存器 commit/store event 与 golden trace 比对，适合证明 ISA
执行及相应配置的 CPU/Cache/AXI 主存路径；它不运行五外设，不能推出 UART/timer/LED 正确。
unit/integration/system test 用各自 oracle 覆盖外设寄存器、协议错误、CPU-driven MMIO、
CoreMark transcript 等仿真行为，但仍只证明 testbench model 下的结果。真实 EGO1 的时钟、
引脚、bitstream、串口输出和板上现象只能由用户编程与观察记录证明。

易错点：证据是分层且 claim-specific 的；下层 PASS 不能自动替代更靠近实物的证据。

### E2：为什么当前不迁移 Vendor IP

核对点：现场快照未把 Crossbar/GPIO/Protocol Converter/Uartlite 列为独立项；当前自有
interconnect/peripheral/UART 已有功能、实现和板级证据。教师若新增要求，必须停止并另开
产品变更，不在 AR1 夹带迁移。

来源核对：`docs/devlog/course-acceptance-readiness.md` 的“保留当前物理拓扑”和“停止条件”；
`docs/acceptance/acceptance-matrix.md`。

参考回答：当前验收快照只检查功能与理解，没有把 AXI Crossbar、AXI GPIO、Protocol
Converter 或 AXI Uartlite 指定为独立必检项；仓库现有自有 interconnect/peripheral/UART
已经有自动、Vivado 和用户板级证据。此时迁移不是等价换名，而会改变 topology、XPR/XCI、
时序资源、仿真模型和已有 evidence provenance，风险与当前材料目标不相称。若教师明确
新增特定 IP 要求，应停止验收材料任务，另开产品变更并重新跑相应门禁。

易错点：不迁移不是声称 Vendor IP 不好，而是当前合同没有授权且已有产品证据不能沿用。

### E3：功耗如何表述

核对点：0.189 W 是 Vivado routed vectorless estimate，confidence Low；不是板上实测功耗。

来源核对：`docs/acceptance/evidence-handoff.md`；`artifacts/acceptance/manifest.tsv`；
`artifacts/acceptance/screenshots/pipeline-post-impl-power.png`。

参考回答：应表述为：“Vivado 2023.2 对 routed pipeline CoreMark implementation 给出的
vectorless Total On-Chip Power estimate 为 0.189 W，其中 Dynamic 0.115 W、Device Static
0.074 W，confidence 为 Low。”vectorless 使用工具推断的 activity，不是示波器/功耗仪在
EGO1 电源轨上的测量，也不包含对整板输入功耗的实测声明，因此不能简称为“板上功耗
0.189 W”。

易错点：实现后 routed estimate 比综合前估算更有约束信息，但 confidence Low 仍必须保留。

## 针对性复习台账

下表是 AR1 冻结的问题清单。`Answer ready / review Pending` 表示参考答案已从 live source
整理，但尚未进行用户复习；它不阻塞 AR1，也绝不能解释为用户已经理解或通过。

| ID | 主题 | 状态 | 后续记录 |
| --- | --- | --- | --- |
| P1 | 五级状态与 IF buffer | Answer ready / review Pending | — |
| P2 | pipeline 停顿优先级 | Answer ready / review Pending | — |
| P3 | 前递与 load-use | Answer ready / review Pending | — |
| P4 | 控制冒险与迟到 fetch response | Answer ready / review Pending | — |
| P5 | Trace 事件与证明边界 | Answer ready / review Pending | — |
| S1 | single-cycle 多周期 completion owner | Answer ready / review Pending | — |
| C1 | I/D Cache 几何结构 | Answer ready / review Pending | — |
| C2 | ICache miss/refill | Answer ready / review Pending | — |
| C3 | DCache write-through/no-write-allocate | Answer ready / review Pending | — |
| C4 | uncached MMIO | Answer ready / review Pending | — |
| A1 | AXI master 仲裁 | Answer ready / review Pending | — |
| A2 | AXI read transaction/refill | Answer ready / review Pending | — |
| A3 | 独立 AW/W handshake | Answer ready / review Pending | — |
| A4 | memory/MMIO 路由与 DECERR | Answer ready / review Pending | — |
| A5 | pipeline MEM completion | Answer ready / review Pending | — |
| M1 | level start 与一次 launch | Answer ready / review Pending | — |
| M2 | multiplier/divider 算法与延迟 | Answer ready / review Pending | — |
| M3 | signed/unsigned 与除零 | Answer ready / review Pending | — |
| U1 | 五外设地址与权限 | Answer ready / review Pending | — |
| U2 | switch/LED/数码管 | Answer ready / review Pending | — |
| U3 | UART 寄存器与 FIFO | Answer ready / review Pending | — |
| U4 | UART 8N1 收发 | Answer ready / review Pending | — |
| U5 | timer 与 CoreMark snapshot | Answer ready / review Pending | — |
| E1 | Trace/system/board 证据边界 | Answer ready / review Pending | — |
| E2 | Vendor-IP 非迁移边界 | Answer ready / review Pending | — |
| E3 | Vivado vectorless power 表述 | Answer ready / review Pending | — |

## 随机复核记录

每轮由 reviewer 从 P/S、C、A、M、U/E 各抽至少一题，随机排列；用户在不照读本文的
情况下回答，再回到 live source 核对。`Pass` 只表示用户能够解释该题，不等同于新产品
验证。

| Round | 日期 | 随机题序 | 用户结果 | 回读项 | reviewer 结论 |
| --- | --- | --- | --- | --- | --- |
| 后续 R1 | Pending | Pending | Pending | Pending | Pending |

复习完成前，本文件必须保持“用户口头复核 Pending”。后续结果可逐题更新台账，再形成一轮
随机复核记录；AR1 的 Completed 只证明问题库与源码索引已就绪。
