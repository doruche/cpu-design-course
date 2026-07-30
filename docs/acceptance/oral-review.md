# 源码口试准备与复核记录

## 使用规则

本文是源码索引和提问清单，不是背诵答案。用户应先用自己的话说明 owner、请求、完成
事件、停顿/提交条件和失败路径，再打开列出的 live source 核对。自动测试只能证明其
oracle 覆盖的行为，不能替代设计理解。

AR1 负责冻结问题库、源码位置和待复习状态。用户于 2026-07-30 决定把实际口头复核留到
后续针对性复习，不作为 AR1 工程关闭门禁；它继续是总体验收和 AR-U 的用户-owned 要求。
无法解释的项目标为 `Re-read`；如果后续回读源码发现真实 RTL/协议缺陷，立即停止当时的
检查点并回到产品 owner。

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

### P2：停顿优先级

追问：`mem_stall`、`md_stall`、`load_use_stall` 同时出现时，哪些 stage 更新？为什么较后级
停顿必须冻结较前级？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:72-83,390-404,465-474`。

### P3：数据前递与 load-use

追问：EX/MEM 与 MEM/WB 同时匹配时选谁？为什么 load 的直接消费者仍要停一拍？同一拍
WB 写回如何让 ID 看到新值？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:234-249,289-304`。

### P4：控制冒险

追问：预测策略是什么？branch/jal/jalr 在哪里解析？一个错误路径 fetch 已经 outstanding
时如何处理它的迟到 response？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:99-145,357-378`。

### P5：Trace 看到什么

追问：为什么 Trace 信号连接到 MEM/WB commit 和实际 data request，而不是简单连接 decode
控制？Trace PASS 能否单独证明 MMIO？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:479-499`；
`cdp-tests/csrc/dut.h`；官方 Trace 说明明确外设不在 Trace 范围内。

### S1：单周期产品如何等待多周期操作

追问：single-cycle core 为什么需要 `mem_pending`、`mul_div_pending` 和 captured fields？迟到
response 为什么不能无条件提交？

源码核对：`projects/single_cycle/src/rtl/cpu_core.v:73-82,153-173,211-255`。

## Cache

### C1：几何结构

追问：I/D Cache 的容量、line size、index/tag/offset 分别来自哪些位？为什么是 direct
mapped 1 KiB、16-byte line？

源码核对：`projects/pipeline/src/rtl/ICache.v:5-8,43-55`；
`projects/pipeline/src/rtl/DCache.v:5-8,58-66`。

### C2：ICache miss

追问：一次 miss 从 lookup 到 refill response 经哪些状态？请求地址为何清零低四位？何时
写 tag/data/valid，何时把所需 word 返回 CPU？

源码核对：`projects/pipeline/src/rtl/ICache.v:71-99,101-164`。

### C3：DCache policy

追问：为什么称为 write-through、no-write-allocate？write hit 时怎样保持 cache line 与
写到总线的数据一致？

源码核对：`projects/pipeline/src/rtl/DCache.v:82-104,145-159,194-260`。

### C4：为什么 MMIO uncached

追问：怎样识别 MMIO？MMIO read 为什么保留原地址和 byte enable、只读一个 32-bit beat？
如果把它按普通 cache line refill 会有什么副作用风险？

源码核对：`projects/pipeline/src/rtl/DCache.v:54-56,162-191,233-251`；
`projects/pipeline/src/rtl/axi_master.v:127-140`。

## AXI 与多周期访存

### A1：仲裁

追问：bridge idle 时 write、DCache read、ICache read 的优先级是什么？当前为何只允许一个
cache-side transaction？

源码核对：`projects/pipeline/src/rtl/axi_master.v:5-8,102-111`。

### A2：读事务

追问：cache refill 与 MMIO read 的 `ARLEN` 分别是多少？四个 read beat 如何拼成 128 bit，
何时向原 requester 发 `dev_rvalid`？

源码核对：`projects/pipeline/src/rtl/axi_master.v:116-179,256-271`。

### A3：写地址和写数据为何分开记账

追问：AW 与 W 可以不同拍握手时，`write_addr_done`/`write_data_done` 如何避免重复 VALID，
何时进入 B response？

源码核对：`projects/pipeline/src/rtl/axi_master.v:181-230,243-254`。

### A4：memory 与 MMIO 路由

追问：哪段地址进入 MMIO？合法 MMIO 请求形态是什么？不支持的 burst/size/strobe 怎样
消费并返回错误，为什么不能产生 peripheral side effect？

源码核对：`projects/pipeline/src/rtl/soc_interconnect.v:3-6,106-150,152-270,302-355`。

### A5：pipeline MEM completion

追问：CPU 如何保证一个 load/store 只 issue 一次？`mem_done` 为什么必须以 `mem_issued` 为
前提？response 到达时哪些 pipeline register 才能推进？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:406-474`。

## 乘法与除法

### M1：level start 与一次 launch

追问：ALU 的 `start` 是 level 而不是 pulse 时，pipeline 为什么需要 `md_launched` 和
`md_captured`？invalid bubble 为什么也必须撤销旧的 M op？

源码核对：`projects/pipeline/src/rtl/cpu_core.v:306-344`。

### M2：算法与延迟

追问：multiplier 每拍做什么 Booth step？divider 每拍如何生成 quotient bit？`busy` 在何时
拉高和拉低？

源码核对：`projects/pipeline/src/rtl/multiplier.v:35-94`；
`projects/pipeline/src/rtl/divider.v:33-92`。

### M3：signed/unsigned 与除零

追问：signed division 的符号怎样拆成 magnitude 和 sign？除数为零时 DIV/REM 的 ISA 结果
如何返回？

源码核对：`projects/pipeline/src/rtl/ALU.v:27-37,39-58,80-95,122-145`。

## MMIO、UART 与五外设

### U1：地址表与权限

追问：switch、LED、digital LED、UART、timer 地址分别是什么？哪些只读、哪些可写？非法
offset 最终返回什么 AXI response？

源码核对：`projects/pipeline/src/rtl/defines.vh:68-75`；
`projects/pipeline/src/rtl/soc_peripherals.v:79-130`；`soc_interconnect.v:143-150`。

### U2：switch、LED、数码管

追问：异步 switch 为什么要两级同步？subword LED/数码管写如何合并 byte lane？八个 digit
如何扫描，EGO1 输出极性是什么？

源码核对：`projects/pipeline/src/rtl/miniRV_SoC.v:39-52`；
`soc_peripherals.v:42-75,132-140`；`seven_segment.v:3-56`。

### U3：UART 寄存器和 FIFO

追问：四个寄存器 offset 的读写语义是什么？RX data read 何时 pop？TX/RX FIFO full 时
如何处理同拍 pop/push？

源码核对：`projects/pipeline/src/rtl/uart_peripheral.v:73-116,118-148,266-302`。

### U4：8N1 收发

追问：50 MHz/115200 如何得到 clocks per bit？TX/RX 分别怎样经过 start、8 data、stop？
RX 为什么在 start bit 中点复核，异步输入在哪里同步？

源码核对：`projects/pipeline/src/rtl/uart_peripheral.v:27-50,150-264`。

### U5：timer 与 CoreMark

追问：timer 是否可写？低/高字分别在哪些 offset？为什么两次独立读取不是原子 snapshot，
CoreMark 如何避免低 32 位 rollover 拼出错误时间？

源码核对：`projects/pipeline/src/rtl/soc_peripherals.v:34,59-65,108-116`；
`programs/c_test/4_coremark/src/coremark/core_portme.c` 的 `get_time()`。

## 证据与边界追问

### E1：Trace、system、board 分别证明什么

核对点：Trace 是 CPU commit/store 差分，AXI Trace 覆盖主存链路但不覆盖外设；system suite
可自动覆盖 MMIO 和 transcript；只有用户记录能证明真实 EGO1 现象。

### E2：为什么当前不迁移 Vendor IP

核对点：现场快照未把 Crossbar/GPIO/Protocol Converter/Uartlite 列为独立项；当前自有
interconnect/peripheral/UART 已有功能、实现和板级证据。教师若新增要求，必须停止并另开
产品变更，不在 AR1 夹带迁移。

### E3：功耗如何表述

核对点：0.189 W 是 Vivado routed vectorless estimate，confidence Low；不是板上实测功耗。

## 针对性复习台账

下表是 AR1 冻结的问题清单。`Pending` 只表示尚未进行用户复习，不阻塞 AR1，也绝不能
解释为用户已经理解或通过。

| ID | 主题 | 状态 | 后续记录 |
| --- | --- | --- | --- |
| P1 | 五级状态与 IF buffer | Pending | — |
| P2 | pipeline 停顿优先级 | Pending | — |
| P3 | 前递与 load-use | Pending | — |
| P4 | 控制冒险与迟到 fetch response | Pending | — |
| P5 | Trace 事件与证明边界 | Pending | — |
| S1 | single-cycle 多周期 completion owner | Pending | — |
| C1 | I/D Cache 几何结构 | Pending | — |
| C2 | ICache miss/refill | Pending | — |
| C3 | DCache write-through/no-write-allocate | Pending | — |
| C4 | uncached MMIO | Pending | — |
| A1 | AXI master 仲裁 | Pending | — |
| A2 | AXI read transaction/refill | Pending | — |
| A3 | 独立 AW/W handshake | Pending | — |
| A4 | memory/MMIO 路由与 DECERR | Pending | — |
| A5 | pipeline MEM completion | Pending | — |
| M1 | level start 与一次 launch | Pending | — |
| M2 | multiplier/divider 算法与延迟 | Pending | — |
| M3 | signed/unsigned 与除零 | Pending | — |
| U1 | 五外设地址与权限 | Pending | — |
| U2 | switch/LED/数码管 | Pending | — |
| U3 | UART 寄存器与 FIFO | Pending | — |
| U4 | UART 8N1 收发 | Pending | — |
| U5 | timer 与 CoreMark snapshot | Pending | — |
| E1 | Trace/system/board 证据边界 | Pending | — |
| E2 | Vendor-IP 非迁移边界 | Pending | — |
| E3 | Vivado vectorless power 表述 | Pending | — |

## 随机复核记录

每轮由 reviewer 从 P/S、C、A、M、U/E 各抽至少一题，随机排列；用户在不照读本文的
情况下回答，再回到 live source 核对。`Pass` 只表示用户能够解释该题，不等同于新产品
验证。

| Round | 日期 | 随机题序 | 用户结果 | 回读项 | reviewer 结论 |
| --- | --- | --- | --- | --- | --- |
| 后续 R1 | Pending | Pending | Pending | Pending | Pending |

复习完成前，本文件必须保持“用户口头复核 Pending”。后续结果可逐题更新台账，再形成一轮
随机复核记录；AR1 的 Completed 只证明问题库与源码索引已就绪。
