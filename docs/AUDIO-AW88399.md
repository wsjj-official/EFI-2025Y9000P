# ALC287 + 双 AW88399 声卡说明

本文记录这台 Legion Y9000P IAX10H（83F5）在 macOS 15 下把外放修好的完整链路，包括硬件拓扑、Linux 对照、三个 macOS 组件、配置值和验证方法。

---

## 1. 硬件拓扑

```text
┌─────────────────────────────────────────────┐
│ Intel HDA controller                        │
│ 8086:7F50（HDEF）                            │
└──────────────────┬──────────────────────────┘
                   │ HDA
┌──────────────────▼──────────────────────────┐
│ Realtek ALC287（10ec:0287）                  │
│ PCI SSID 17aa:3d6c                          │
│                                             │
│  pin 0x17（woofer / 低音）──┐                │
│  pin 0x14（tweeter / 高音）─┤ 都接 DAC02     │
└──────────────────┬──────────┴───────────────┘
                   │ I2C（ALC287 旁边的 side codec）
        ┌──────────▼──────────┐
        │ AW88399 #0  0x34    │  channel 1
        │ AW88399 #1  0x35    │  channel 0
        └──────────┬──────────┘
                   │
             两个低音单元
```

关键点：

- ALC287 负责 HDA 编解码，两个扬声器 pin 都走 **DAC02**。
- 两颗 AW88399 不是标准 HDA codec，而是挂在 ALC287 旁边的 **I2C side codec / smart amp**，负责驱动两个低音单元。
- Linux 用 `snd_hda_scodec_aw88399` + `snd_soc_aw88399` 驱动；macOS 没有对应驱动，需要自己补一条链路。

### 1.1 本机 ID

| 项目 | 值 |
| --- | --- |
| 机型 | Legion Y9000P IAX10H |
| 板号 | 83F5 |
| Codec | Realtek ALC287（`10ec:0287`） |
| PCI SSID | `17aa:3d6c` |
| Codec SSID（Linux 资料） | `17aa:3906` |
| HDA controller | Intel `8086:7f50` |
| 功放 | 2 × Awinic AW88399 |
| 功放 chip ID | `0x2183` |
| ACPI HID | `AWDZ8399` |
| ACPI 路径 | `\_SB.PC02.I2C2.SPKR` |
| I2C 地址 | `0x34` / `0x35` |
| I2C 控制器 | `8086:7F4C`（I2C0）、`8086:7F4E`（I2C2） |
| ACF 固件 | `aw88399_acf.bin`，152416 字节 |
| 固件 SHA-256 | `1e927c9bca76d868181c0f81df2bccef3cf19c7d0910219f229360c87babd42c` |

---

## 2. Linux 下的根因（对照）

Linux 教程里总结的四个问题，在 macOS 上对应关系如下：

| Linux 问题 | Linux 修复 | macOS 对应 |
| --- | --- | --- |
| 只有 ASoC 驱动，没有 HDA side-codec 驱动 | `snd_hda_scodec_aw88399` + `aw88399_hda_i2c` | `AW88399Driver.kext` 通过 VoodooI2C 直接访问两颗功放 |
| ACPI 只枚举一个功放实例 | `serial-multi-instantiate` 双实例 | VoodooI2C dual-resource 补丁，把 SPKR 的 0x34/0x35 都发布成 nub |
| ALC287 缺少 Legion fixup | pin17 从 DAC06 改到 DAC02，关闭 pin1d | AppleALC 共享 DAC 分支：pin17 + pin14 都走 DAC02 |
| 缺少 ACF 固件 | 安装 `aw88399_acf.bin` | 固件内置于 `AW88399Driver.kext`，不需要额外放 `/lib/firmware` |

Linux 的完整方案还包含 per-SSID 声道交换、BSTS quirk、protection/calibration 等；macOS 侧由 AW88399Driver 的 Linux 派生核心保留。

---

## 3. macOS 的三个组件

### 3.1 `AW88399Driver.kext` 0.2

- 匹配 `IOProviderClass = VoodooI2CDeviceNub`、`IONameMatch = SPKR`。
- 读取 nub 的 `i2cAddress`，只接受 `0x34` / `0x35`，其他地址直接拒绝。
- 初始化 AW88399：读 chip ID、加载 ACF、配置 DSP/保护/校准。
- 通道映射：
  - `0x34` → `channel 1`
  - `0x35` → `channel 0`
- 查找祖先带 `IOHDACodecVendorID = 0x10ec0287` 的 `AppleHDAEngineOutput`。
- 每 20 ms 轮询 `IOAudioEngineState`：
  - 开始播放 → `aw88399_start(..., AW88399_SYNC_START)`，功放上电
  - 停止播放 → `aw88399_stop()`，功放下电
- 发布诊断属性：
  - `AW88399Ready`
  - `AW88399I2CAddress`
  - `AW88399PlaybackActive`
  - `AW88399AmplifierRunning`
  - `AW88399LastError`
  - `AW88399AudioEngineName` / `RegistryID` / `State`
- ACF 固件直接嵌在 kext 二进制里（偏移 30752，152416 字节），`Info.plist` 不再需要 `AW88399FirmwareData`；因此不需要像上游公开包那样再跑 `import_firmware.py`。

### 3.2 `VoodooI2C.kext` 2.9.1（dual-resource 补丁）

原版 VoodooI2C 的 ACPI 资源解析器只保留 **一个** I2C Serial Bus 资源：

```cpp
if (found_i2c)
    return;
```

而本机 `SPKR` 的 `_CRS` 里有两个：

```text
I2cSerialBus (0x34)
I2cSerialBus (0x35)
```

补丁做了三件事：

1. `VoodooI2CACPIResourcesParser` 保留最多 8 个 I2C 资源，记录 `i2c_count`，溢出则拒绝。
2. `VoodooI2CControllerDriver::publishNubs()` 对每个资源发布一个 `VoodooI2CDeviceNub`，并设置 `i2cResourceIndex`。
3. `VoodooI2CDeviceNub::getDeviceResources()` 按 index 选择对应地址，发布 `i2cAddress` 和 `i2cResourceCount`。

另外保留了本板需要的控制器匹配：

```text
0x7f4c8086&0xFFFCFFFF
```

修补后 IORegistry 里 `SPKR` 下会出现两个 nub：

```text
SPKR  i2cAddress = 52 (0x34)
SPKR  i2cAddress = 53 (0x35)
```

### 3.3 `AppleALC.kext` 1.9.8（共享 DAC 分支）

原版/普通 layout 的问题：

- pin17（低音）和 pin14（高音）都接到 DAC02。
- 如果 AppleHDA 把它们声明成两条独立软件路径，PathSet 会把通道数累加，DAC02 被编程成 4 通道（format `0x33`、stream tag 1 + channel offset 2），而 HAL 仍然只给立体声，导致：
  - 音量很小 / 声音薄
  - 音调偏高
  - 播放断续

共享 DAC 分支的做法：

- 只声明一条完整立体声路径：**pin17 → DAC02**，带 Amp 音量/静音。
- 通过 `executeVerb` hook 把 pin17 的输出控制、Amp、power 写入镜像到 pin14。
- 启用 pin14 时：
  - 读取 pin14 的实际 connection list
  - 找到 DAC02 selector
  - 复制 pin17 当前的左右 Amp 状态
  - 设置 EAPD
  - 不额外分配 stream
- 需要 `alcverbs=1`。
- 守卫条件：ALC287（`10ec0287`）、HDEF、Intel `7f50`、`alc-layout-id = 13`。
- 诊断属性：
  - `ALC287SharedDACPrimaryPin = 23`（0x17）
  - `ALC287SharedDACSecondaryPin = 20`（0x14）
  - `ALC287SharedDACSecondarySelector`
  - `ALC287SharedDACLastError`
  - `ALC287SharedDACOutputEnabled`

> 这就是为什么只加 `AW88399Driver` 不够：功放要有信号，AppleHDA 的 pin17/DAC02 路径必须先正确；而共享 DAC 分支负责让高音和低音一起工作且音量正常。

---

## 4. 配置值

### 4.1 HDEF

```text
PciRoot(0x2)/Pci(0x1f,0x3)
  layout-id     = 0D 00 00 00
  alc-layout-id = 0D 00 00 00

PciRoot(0x80)/Pci(0x1f,0x3)
  layout-id     = 0D 00 00 00
  alc-layout-id = 0D 00 00 00
```

必须是 **4 字节 little-endian**，不能写成 ASCII 字符串 `"0d000000"`（8 字节）。旧配置就是这里写错，导致 layout 13 守卫失效。

> 运行时 `ioreg` 可能显示 `layout-id = 07`（AppleALC 的内部 native layout）而 `alc-layout-id = 0d`；这是正常的。请求值以 `alc-layout-id` 为准，不要因为 `layout-id` 变成 7 就改配置。

### 4.2 boot-args

```text
alcid=13 alcverbs=1
```

- `alcid=13`：AppleALC 选择 layout 13。
- `alcverbs=1`：启用共享 DAC 的 verb hook；去掉后 pin14 不会跟随 pin17 的音量/静音。

### 4.3 其他

- `-vi2c-force-polling`：VoodooI2C 强制轮询，保证 SPKR 双资源稳定枚举。
- `AMFIPass` + `amfi=0x80`：允许注入未签名 kext。
- `csr-active-config = 0x0A43`：部分关闭 SIP。

---

## 5. 验证

### 5.1 一键脚本

```sh
bash tools/check-audio.sh
```

### 5.2 手动命令

```sh
# 1. 驱动是否加载
kmutil showloaded | grep -Ei 'AppleALC|VoodooI2C|AW88399'

# 2. SPKR 双 nub
ioreg -l -w0 -r -c VoodooI2CDeviceNub | \
  grep -E '"name" = <"SPKR|"i2cAddress"|"i2cResourceCount"'

# 3. 功放状态
ioreg -l -w0 -r -c AW88399Driver | \
  grep -E 'AW88399(Ready|I2CAddress|PlaybackActive|AmplifierRunning|LastError|AudioEngine)'

# 4. 共享 DAC
ioreg -l -w0 | grep ALC287SharedDAC
```

### 5.3 期望结果

加载的 kext：

```text
as.vit9696.AppleALC (1.9.8)
com.alexandred.VoodooI2C (2.9.1)
org.codex.AW88399Driver (0.2)
```

两个 nub：

```text
"i2cAddress" = 52
"i2cAddress" = 53
"i2cResourceCount" = 2
```

功放：

```text
"AW88399Ready" = Yes
"AW88399I2CAddress" = 52
"AW88399I2CAddress" = 53
"AW88399LastError" = 0
```

播放时：

```text
"AW88399PlaybackActive" = Yes
"AW88399AmplifierRunning" = Yes
```

共享 DAC：

```text
"ALC287SharedDACPrimaryPin" = 23
"ALC287SharedDACSecondaryPin" = 20
"ALC287SharedDACLastError" = 0
```

### 5.4 试听

```sh
afplay /System/Library/Sounds/Glass.aiff
```

正常状态：

- 左右声道都有声音；
- 低音炮有明显低频；
- 系统音量滑块能同时改变高音和低音；
- 静音后两个单元都静音。

---

## 6. 常见问题

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| 只有一个 `SPKR` nub | VoodooI2C 补丁未加载 / 被原版覆盖 | 确认 `VoodooI2C.kext` 二进制含 `i2cResourceCount`；确认 `Kexts` 里没有被替换成原版 |
| 两个 nub 但 AW 不加载 | AW kext 顺序/依赖问题 | 确认 `VoodooI2CServices`、`VoodooGPIO`、`VoodooI2C` 在 AW 之前；`kmutil showloaded` 查 `org.codex.AW88399Driver` |
| `AW88399Ready = No`，`LastError != 0` | I2C 地址不对 / 固件 / chip ID | 看 `log show` 里的 `AW88399:` 日志；确认地址 0x34/0x35；确认 ACF 内置 |
| 功放 Ready 但播放不启动 | 没找到 `AppleHDAEngineOutput` / 引擎祖先没有 `10ec0287` | `ioreg` 查 `AW88399AudioEngineName`；确认 AppleALC 已加载 |
| 有高音没低音 | pin17 未启用 / 共享 DAC 未生效 | 查 `ALC287SharedDACPrimaryPin`、`OutputEnabled`；确认 `alcverbs=1` 和 layout 13 |
| 声音很小、音调偏高 | DAC02 被分配成 4 通道 | 确认 AppleALC 是共享 DAC 分支 1.9.8；确认 `layout-id` 是 4 字节 13 而不是 ASCII |
| 左右低音反了 | 0x34/0x35 通道映射 | 本版固定 `0x34→ch1`、`0x35→ch0`；如换板需改 `AW88399Driver.cpp` |
| 升级系统后失效 | AppleHDA/AppleALC ABI 变化 | 用对应 SDK 重编 AppleALC/AW88399Driver；保留原 EFI 回退 |
| 睡眠后无声 | 功放未重新上电 | 本版未验证睡眠；可先禁用睡眠或反馈日志 |

---

## 7. 与 Linux 方案的差异

| 项目 | Linux | macOS |
| --- | --- | --- |
| 功放驱动位置 | 内核 `sound/hda/codecs/side-codecs` | 用户态 IOKit kext（VoodooI2C provider） |
| 固件加载 | `/lib/firmware/aw88399_acf.bin` | 内置于 `AW88399Driver.kext` |
| 路由 | ALC287 fixup + HDA side-codec | AppleALC 共享 DAC 分支 + `alcverbs=1` |
| 双实例枚举 | `serial-multi-instantiate` | VoodooI2C dual-resource 补丁 |
| 启停时机 | ALSA PREPARE/CLEANUP | 20 ms 轮询 `IOAudioEngineState` |
| 声道交换 | per-SSID quirk | `AW88399Driver` 固定 0x34→1 / 0x35→0 |

macOS 侧不是 Linux 驱动的直接移植：HDA PCM 传输仍由 AppleHDA 负责，AW88399Driver 只负责功放的 I2C 配置、DSP/保护初始化和按播放状态启停。

---

## 8. 参考

- Linux 修复记录（作者博客）：<https://www.wsjj.top/archives/176>
- 上游 Linux 项目：<https://github.com/nadimkobeissi/16iax10h-linux-sound-saga>
- macOS 声卡项目：<https://github.com/Ersiter/Legion-ALC287-AW88399-macOS>
- Awinic ACF 固件说明：上游 `docs/FIRMWARE.md`
- VoodooI2C：<https://github.com/VoodooI2C/VoodooI2C>
- AppleALC：<https://github.com/acidanthera/AppleALC>
