# 故障排查

本文按“启动 → 声卡 → Wi-Fi/蓝牙 → 触摸板 → NVIDIA → 睡眠”的顺序列出常见问题和检查命令。

---

## 1. 启动问题

### 1.1 卡在 `OC: Prelinked status`

- 确认 `EFI/OC/Drivers/OpenRuntime.efi` 存在且启用；
- 确认 `config.plist` 的 `Booter > Quirks` 没有被清空；
- 确认没有把原版 `OpenCore.efi` 和本包的 `config.plist` 混用。

### 1.2 卡在 Apple Logo / 进度条

先用 `-v` 看最后一行。常见：

| 最后一行 | 可能原因 | 处理 |
| --- | --- | --- |
| `AMFI: ...` | AMFI 未放行 | 确认 `amfi=0x80`、`amfi_get_out_of_my_way=0x1`、AMFIPass 已加载 |
| `Lilu ... failed` | Lilu 版本/顺序问题 | 确认 Lilu 在 AppleALC/WhateverGreen 之前 |
| `AppleHDA ...` | AppleALC 与系统不匹配 | 用备份 EFI 启动，换回原 AppleALC |
| `VoodooI2C ...` | I2C 资源/补丁冲突 | 确认 dual-resource 补丁版，不要混原版 |
| `Still waiting for root device` | USB/存储 | 换 USB 口，检查 UTBMap/USBToolBox |
| `DMAR` / VT-d 相关 | VT-d 表冲突 | 本 EFI 已删除 DMAR；BIOS 里可尝试关闭 VT-d |

### 1.3 无限重启

- 进 OpenCore，先 `Reset NVRAM`；
- 关闭 BIOS Secure Boot；
- 用备份 EFI 启动，逐个替换 kext 排查；
- 如果是刚更新 macOS 后出现，先用原 EFI 启动，等 AppleALC/AW88399 重编后再升级。

### 1.4 OpenCore 日志

`Misc > Debug > Target = 3` 时，日志写到：

```text
EFI/OC/Logs/OpenCore-YYYY-MM-DD-HHMMSS.txt
```

把该文件与 `-v` 最后几行一起提供，最容易定位。

---

> **进得去系统、但只有 1–3 FPS（macOS 26 实测）**：这不是 EFI 的问题，是**还没装 NVIDIA 驱动**。
> 内屏接在独显上，没有 NullMoth 驱动时只有固件/旧帧缓冲在推像素，鼠标要拖很久才动、窗口画不出来。
> 装完驱动（`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC` + `NVMTLDriver`）后恢复正常帧率。
> 详见 [README-macOS26-Tahoe.md](../README-macOS26-Tahoe.md) 第 5 节。

## 2. 声卡

### 2.1 一键检查

```sh
bash tools/check-audio.sh
```

### 2.2 驱动没加载

```sh
kmutil showloaded | grep -Ei 'AppleALC|VoodooI2C|AW88399'
```

期望：

```text
as.vit9696.AppleALC (1.9.8)
com.alexandred.VoodooI2C (2.9.1)
org.codex.AW88399Driver (0.2)
```

如果没有 AW：

- 确认 `EFI/OC/Kexts/AW88399Driver.kext` 存在；
- 确认 `config.plist > Kernel > Add` 里 `AW88399Driver.kext` 的 `Enabled=true`，`MinKernel=24.0.0`、`MaxKernel=24.99.99`；
- 确认 `VoodooI2CServices`、`VoodooGPIO`、`VoodooI2C` 在它之前；
- 看 `log show --last 10m | grep -i AW88399`。

### 2.3 只有一个 SPKR nub

```sh
ioreg -l -w0 -r -c VoodooI2CDeviceNub | \
  grep -E '"name" = <"SPKR|"i2cAddress"|"i2cResourceCount"'
```

如果只有 `52` 或只有 `53`：

- `VoodooI2C.kext` 不是 dual-resource 补丁版；
- 或补丁版被原版覆盖；
- 检查二进制：

```sh
strings -a EFI/OC/Kexts/VoodooI2C.kext/Contents/MacOS/VoodooI2C | \
  grep -E 'i2cResourceCount|Too many I2C'
```

应能看到这两串。

### 2.4 `AW88399Ready = No`

```sh
ioreg -l -w0 -r -c AW88399Driver | grep AW88399
log show --last 10m --style compact | grep -i 'AW88399:'
```

常见日志：

| 日志 | 原因 | 处理 |
| --- | --- | --- |
| `refusing unexpected I2C address` | nub 地址不是 0x34/0x35 | 检查 VoodooI2C 资源解析 |
| `chip initialization failed` | I2C 不通 / chip ID 不对 | 检查 `-vi2c-force-polling`、BIOS I2C、硬件 |
| `ACF/DSP initialization failed` | 固件/ACF 数据问题 | 确认使用的是内置 ACF 的 0.2 构建 |
| `synchronous ACF/DSP initialization failed` | 命令门/固件加载失败 | 看完整日志，必要时重编驱动 |

### 2.5 功放 Ready，但播放不启动

```sh
ioreg -l -w0 -r -c AW88399Driver | grep -E 'AudioEngine|Amplifier'
```

期望：

```text
"AW88399AudioEngineName" = "AppleHDAEngineOutput"
"AW88399AmplifierRunning" = Yes   # 播放时
```

如果 `AudioEngineName` 为空：

- AppleHDA 没有创建输出引擎；
- 检查 AppleALC 是否加载、layout 13 是否生效；
- `ioreg -l -w0 -r -n HDEF | grep -E 'layout-id|alc-layout-id'`，应为 `0d000000`（`alc-layout-id`）。

### 2.6 有高音没低音

```sh
ioreg -l -w0 | grep ALC287SharedDAC
```

应看到：

```text
"ALC287SharedDACPrimaryPin" = 23
"ALC287SharedDACSecondaryPin" = 20
"ALC287SharedDACLastError" = 0
```

如果 `LastError != 0`：

- 确认 `alcverbs=1` 在 boot-args；
- 确认 `alc-layout-id=13` 是 4 字节，不是 ASCII；
- 确认 AppleALC 是 1.9.8 共享 DAC 分支。

### 2.7 声音很小 / 音调偏高

这是共享 DAC 未生效的典型表现：

- `layout-id` 被写成 8 字节 ASCII；
- `alcid` 与 `alc-layout-id` 不一致；
- 用了原版 AppleALC 而不是共享 DAC 分支；
- `alcverbs=1` 丢失。

检查：

```sh
nvram boot-args
ioreg -l -w0 -r -n HDEF | grep -E 'layout-id|alc-layout-id'
kmutil showloaded | grep AppleALC
```

### 2.8 升级系统后失效

AppleHDA/IOAudioFamily 变化会导致 AppleALC 共享 DAC 分支和 AW88399Driver 需要重编。处理：

1. 用备份 EFI 启动；
2. 用对应 SDK 重编 AppleALC 分支和 AW88399Driver；
3. 重新验证 `AW88399Ready` / `ALC287SharedDAC`；
4. 再升级。

---

## 3. Wi-Fi（BE200）

### 3.1 没有 Wi-Fi

```sh
system_profiler SPAirPortDataType | head -40
kmutil showloaded | grep -i itlwm
```

确认：

- `AirportItlwm-Sequoia-BE200.kext` 已加载；
- `Info.plist` 的 `IOPCIMatch` 含 `0x272b8086`；
- `MinKernel=24.2.0`、`MaxKernel=24.99.99`；
- 没有同时使用 `itlwm.kext + HeliPort`（那是另一种驱动方式，不能和 AirportItlwm 混用）。

### 3.2 Wi-Fi 能显示但无法连接

- 检查 `ROM` 是否是有效 MAC（iServices 和网络接口相关）；
- 删除旧的网络配置文件，重新加入；
- 确认路由器 5 GHz/信道兼容；
- 看 `log show --last 5m | grep -i itlwm`。
- **连不上 / 认证失败**：先确认加密方式与驱动版本（WPA3 需要本包 `_FIX22_20261030` 及以上，且 AP 支持 H2E，见 3.2.1）；仍不行就退回 WPA2-Personal/AES 对比。
- **连上后掉线 / 反复认证 / DHCP 拿不到地址**：确认用的是本包的 `AirportItlwm 2.4.0 _FIX18_20261029`（修了四次握手末包发送与装钥时序、离网残留状态、**扫描期间误判整卡故障并重启**、发送队列排空失败触发整卡重启），并确认 boot-args 里有 `itlwm_he=1`。

### 3.2.1 Wi-Fi 6（HE）与 6 GHz

- 驱动只认三个参数：`itlwm_he`、`itlwm_cc`、`itlwm_tsleep`。
- **Wi-Fi 6 / 6 GHz 需要 `itlwm_he=1`**：它打开 802.11ax 能力；6 GHz（Wi-Fi 6E）的 HE 能力集也挂在这条路径上。没有这个参数时只会走 11ac（2.4/5 GHz）。
- Fix18 已修好 **6 GHz 的扫描/信道映射**（按频段与信道正确映射、自动候选纳入 6 GHz、修正加入 11ax 网络后 6 GHz 信道从可用列表消失）；**实际 6 GHz 关联仍待现场验证**。想指定国家/区域可以用 `itlwm_cc=XX`（驱动按 regulatory 决定 6 GHz 是否可用）。
- **加密方式（2026-10-30 更新）：WPA3-Personal（SAE）已实测可用**，要求：
  - 驱动为 `_FIX22_20261030` 或更新；**WPA3 默认走 H2E-only，AP 必须支持 H2E**（只支持传统 HnP 的老路由器连不上，HnP 是默认不编译的实验路径）；
  - 典型现象：认证阶段失败 / 一直在“正在连接”。先确认路由器 WPA3 模式是 H2E（有的固件写作 WPA3-Only/H2E，或提供 WPA3/WPA2 混合）；
  - 拿不准时用 **WPA2-Personal（AES）** 做对照：WPA2 能连、WPA3 不能连 → 多半是 AP 不支持 H2E；两者都连不上 → 按 3.1/3.2 查驱动与扫描。
  - **WPA2-Personal（AES）与 WPA2-Enterprise（PEAP）仍然完全可用**。
- 别为了多出 6 GHz 信道去伪造监管域（`itlwm_cc`），信道会按固件与真实监管域裁剪。
- **Wi-Fi 7（EHT）未测试**。
- 验证：

  ```sh
  spairport info 2>/dev/null | grep -i -E 'PHY|Channel|NSS'
  system_profiler SPAirPortDataType | grep -i -A3 'Current Network'
  # 6 GHz 上报的扫描结果（需要路由器开 6 GHz）
  ioreg -l | grep -i 'WCLScan6GHzMap\|Channels6GHz'
  ```

### 3.3 蓝牙

- 确认 `IntelBluetoothFirmware`、`IntelBTPatcher`、`BlueToolFixup` 顺序；
- `BlueToolFixup` 用 FixA2DP 补丁版时 `MinKernel 19.0.0`（本包已改成 19.0.0）；
- 如果蓝牙开关灰色，先 `Reset NVRAM`。

#### 3.3.1 蓝牙耳机能连上、放歌没声（A2DP）

症状：AirPods 等设备能连、能切降噪、音量正常，但**播放没有声音**；或者**音频会话一断（暂停/切 App）就彻底没声**。

处理：

1. 确认 `EFI/OC/Kexts/BlueToolFixup.kext` 是**FixA2DP 补丁版**（`2.7.3`，来源 <https://github.com/hexxyan/BlueToolFixup-FixA2DP>）；
2. 确认 boot-args 带 **`-btlfxa2dpcheck`**（没这个参数补丁不启用）：

   ```sh
   sysctl -n kern.bootargs | grep -- -btlfxa2dpcheck
   kextstat | grep -i bluetoolfixup
   ```

3. 重启后连耳机，做几次「暂停 / 继续 / 切走再切回」，每次都应该有声。
4. `IntelBluetoothFirmware` / `IntelBTPatcher` **保持原版**，不要为了这个补丁一起换版本。
5. 回退：换回原版 `BlueToolFixup` 2.7.3（acidanthera/BrcmPatchRAM），并从 boot-args 删掉 `-btlfxa2dpcheck`。

**macOS 26 补充（2026-10-31）**：`EFI-Tahoe/` 原来用的是「BE200 stored-key 实验版」`BlueToolFixup`（39,808 B，配 `-btlfxbe200key`），这份**没有** A2DP 补丁；现在已换成 FixA2DP 版并把参数改成 `-btlfxa2dpcheck`。

- 两个补丁（A2DP 快连门控 / BE200 stored-key）是两条分支，目前**没有合并版**，只能二选一；
- 如果换成 FixA2DP 后 26 上蓝牙打不开 / 连不上，说明这台机器需要 BE200 stored-key 那条：换回旧 `BlueToolFixup.kext` 并把参数改回 `-btlfxbe200key`（备份在仓库外 `EFI/_backup-bluetooth/BlueToolFixup-BE200-Darwin25-20261016.kext`）；
- `IntelBluetoothFirmware-2.5.1` / `IntelBTPatcher-BE200-25x` 不要跟着换。

> 不要为了切设备反复长按充电盒按钮重置耳机——那会清掉 Mac 和手机上的所有配对。

---

## 4. 触摸板

- `VoodooI2C` 必须在 `VoodooI2CHID` 之前；
- `VoodooI2CServices`、`VoodooGPIO` 在 `VoodooI2C` 之前；
- 只保留一个 `VoodooInput`（本包使用 VoodooI2C 插件内的 1.1.7，VoodooPS2 内的禁用）；
- `-vi2c-force-polling` 保留；
- `SSDT-GPI0.aml` 必须启用，ACPI 里 GPI0 `_STA` 已改名；
- 如果改了声卡后触摸板失效，确认没有把 VoodooI2C 换回原版（原版只保留一个 I2C 资源，可能影响 SPKR 但不应该影响触摸板；若影响，检查 kext 顺序）。

---

## 5. NVIDIA 独显

当前系统：

```text
NVIDIA (0x10de) Device ID: 0x2f58
Kernel Extension Info: No Kext Loaded
```

说明 NVIDIA 驱动未加载，这是本包的预期状态（本包不含 NVIDIA 驱动）。

### 5.1 安装/恢复

按 NullMoth 2.6.2 的说明安装。OpenCore 里已保留：

- `NullMothSafe.efi` 两个入口：
  - `1401: Remove NVIDIA driver`：下次启动移除驱动
  - `1401: Start once without NVIDIA driver`：本次启动不加载
- `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth`
- `amfi_get_out_of_my_way=0x1 amfi=0x80`

### 5.2 黑屏 / 花屏

- 用 `NullMothSafe` 的“本次不加载”入口启动；
- 确认 `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)` 的 `acpi-wake-type=1` 仍在；
- 检查 `ResizeAppleGpuBars=-1` 与 BIOS ReBAR 设置；
- 不要在没有核显输出备份的情况下反复尝试。

### 5.3 内屏亮度滑块是灰的

本机内屏接在独显上，固件 DSDT 里只有一个空的 `_BCM` 桩，没有可用的背光方法，所以 SSDT-PNLF / WhateverGreen 那一套在这里不适用。

修法就一个 boot-arg：

```text
nvrmacpibl=1
```

加上之后 NullMoth 的 NVKMS 会自己注册内屏背光，**亮度滑块和亮度键都会恢复**。注意两点：

- **必须装了 NullMoth 驱动才有效**；没装驱动时这个参数不生效，滑块依旧是灰的；
- NullMoth 只在这个参数存在时才去读 GPU 的 ACPI `_DSM` / `_DOD`（默认关闭，因为少数机器会在 GPU 启动阶段挂住）。**如果加了它之后开机卡在 GPU 启动阶段，把这个参数删掉**。

验证：

```sh
nvram boot-args | grep -o 'nvrmacpibl=1'
# 系统设置 → 显示器：亮度滑块可拖动；键盘亮度键有效
```

---

## 6. 睡眠 / 唤醒

本版未验证睡眠。需要测试时：

```sh
sudo pmset -a sleep 1
```

唤醒后检查：

- 声音是否恢复；
- `AW88399Ready` 是否仍为 Yes；
- `ALC287SharedDACLastError` 是否为 0。

如果唤醒后无声，先临时禁用睡眠：

```sh
sudo pmset -a sleep 0
```

并记录 `log show --last 10m | grep -Ei 'AW88399|ALC287|AppleHDA'`。

---

## 7. 怎么收集可分享的日志

### 7.1 声卡报告

```sh
bash tools/check-audio.sh > ~/Desktop/audio-report.txt
```

### 7.2 内核日志

```sh
log show --last 10m --style compact > ~/Desktop/kernel-10m.txt
```

### 7.3 OpenCore 日志

从 EFI 分区复制：

```text
EFI/OC/Logs/OpenCore-*.txt
```

### 7.4 注意隐私

`ioreg -l`、`system_profiler`、`log show` 可能包含：

- 机器序列号；
- MLB / UUID；
- MAC 地址；
- Apple ID 相关路径。

分享前删除/替换这些字段。发布包的三码为空，但日志不会自动脱敏。

---

## 8. 恢复

发布包不包含你的原机备份。出现无法启动时：

1. 用原 EFI、U 盘或 macOS Recovery 启动；
2. 挂载 EFI；
3. 覆盖 `EFI/OC`；
4. 保留 `EFI/Microsoft`。

Recovery 终端：

```sh
diskutil list
diskutil mount disk1s1
cp -R "/Volumes/BACKUP/EFI/OC" "/Volumes/NO NAME/EFI/OC"
```

如果连 OpenCore 都进不去，优先检查 BIOS 启动项和 EFI 分区是否还在。
