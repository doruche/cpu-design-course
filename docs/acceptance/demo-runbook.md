# Pipeline CoreMark 现场演示 Runbook

## 演示目标

现场只演示当前最高完成度：EGO1 上的 pipeline SoC 运行 CoreMark。此 runbook 不生成新
候选，不替代用户操作，也不把既有 PC-U 记录自动延伸到下一次现场运行。

## 冻结输入

```text
candidate:  pipeline/coremark
bitstream:  /mnt/z/cpu-design-vivado/candidates/pipeline/coremark/miniRV_SoC.bit
source:     14a05572ebb585f20a3c83341fb2abe6fb834b0d
bit SHA256: 36c3f95eaf4faa6b9bd609e783423057af4bee110343f3bce71a2362ec97c6ab
COE SHA256: aaf7c184d27c4c2afeacae8c22f807b75fa1ea584295d16bac344bf37671bae3
clock:      50 MHz
serial:     115200 baud, 8 data bits, no parity, 1 stop bit, no flow control
```

现场使用前先执行只读检查：

```bash
sha256sum \
  /mnt/z/cpu-design-vivado/candidates/pipeline/coremark/miniRV_SoC.bit
python3 scripts/check_vivado_result.py \
  /mnt/z/cpu-design-vivado/candidates/pipeline/coremark/stage5_evidence.json
```

第一条必须得到冻结 bitstream hash；第二条必须 PASS。任一结果不同，不烧录、不换用
“最新”文件，保存输出并停止。

## 现场前检查

- EGO1、JTAG/供电线和 UART 线可用，串口设备名已确认；
- Vivado Hardware Manager 能看到目标器件；
- 串口程序未被其他进程占用，换行显示不会吞掉原始输出；
- terminal 已固定为 115200/8N1、无硬件和软件流控；
- bitstream 仍位于冻结绝对路径且 hash 相符；
- 预留至少 20 秒运行窗口，并准备保存从首个 banner 到 `FINISH` 的完整 transcript。

## 演示步骤

1. 在候选目录核对 bitstream SHA-256，不通过则停止。
2. 在 Hardware Manager 中选择 EGO1 目标器件，只烧录上面的 `miniRV_SoC.bit`。
3. 打开正确 UART 端口，确认 115200/8N1、无流控；不要向 CoreMark 发送输入。
4. 按下板级低有效 reset，保持到系统明确进入 reset，再释放。
5. 从首个 `CoreMark 1.0` 开始保存原始串口输出。候选含 100 ms 初始化等待。
6. 等待完整 benchmark。已关闭候选约 14.08 秒完成；不得在十秒前用不完整输出判 PASS。
7. 一直记录到 `FINISH`，随后核对下面的内容、失败关键词和性能值。
8. 记录本次日期、bitstream hash、串口设置、total ticks、CRC、分数和实际 PASS/FAIL。

## 期望 transcript

必须同时出现：

```text
CoreMark 1.0
2K performance run parameters for coremark.
Total ticks      : 703945188
Total time (secs): 14
Iterations/Sec   : 50
Iterations       : 700
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x65c5
Correct operation validated
CoreMark 1.0 : 49.7197
CoreMark/MHz : 0.9943
FINISH
```

串口中的浮点格式可能包含额外尾随零；判定值仍必须对应 49.7197 和 0.9943。精确计时由
703,945,188 个 50 MHz tick 得到 `14.07890376 s`。固定算法判据是 seed/list/matrix/state
四项；`crcfinal` 是本次 700 iterations 的累计值，不能当作迭代无关 oracle。

## 失败判据

出现以下任一情况，本次演示为 FAIL 或无效，不靠重启、换 candidate 或改口径掩盖：

- bitstream、COE、manifest、selection 或 source 不能与冻结 evidence 对应；
- 无输出、乱码、输出中途停止或没有 `FINISH`；
- 出现 `ERROR`、`ERROR!`、`Errors detected` 或 `Incorrect operation`；
- 任一固定 CRC 不符，或缺少 `Correct operation validated`；
- 有效运行不足十秒，iterations 不是 700，或 ticks/性能与冻结候选矛盾；
- reset 后没有从首个 banner 重新开始；
- Vivado 编程失败、串口设置不确定或 transcript 没有保存完整。

发生失败时保留原始 transcript、Hardware Manager 消息、实际 bitstream hash、串口设置和
复现步骤。先区分设备/连接/操作问题与产品问题；若指向 RTL、时序或协议缺陷，停止 AR1
并回到拥有该行为的产品任务，不在验收文档中修产品。

## 现场口头说明边界

- 可说明：这是 pipeline SoC、50 MHz、Cache enabled，通过 UART 输出，timer 计时；
- 可引用：本次实际 transcript、冻结 provenance 和已审计 timing；
- 不可声称：LLAMA2、DDR、未采用的 AXI Vendor IP、板上实测功耗；
- Vivado power 仅是 routed vectorless estimate，confidence 为 Low；
- 若教师要求检查额外 IP 拓扑或其他硬件形态，停止并更新任务边界。

## 本次演示记录槽位

| 字段 | 用户填写 |
| --- | --- |
| 日期 / 地点 | Pending |
| 实际 bitstream SHA-256 | Pending |
| 串口设备与设置 | Pending |
| reset 后首个 banner | Pending |
| ticks / iterations | Pending |
| 四项固定 CRC | Pending |
| CoreMark / CoreMark/MHz | Pending |
| `FINISH` 与错误关键词 | Pending |
| 用户结论 | Pending |

此槽位只记录下一次用户实际演示；AR1 文档准备不能预填为 PASS。
