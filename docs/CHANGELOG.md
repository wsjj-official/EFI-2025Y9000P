# 变更记录

## v1.0 — 2026-10-27

首个正式整理版，基于本机 2026-10-27 可启动、外放正常的 EFI 导出。

### 声卡

- 启用 `AW88399Driver.kext` 0.2：
  - 支持 I2C `0x34` / `0x35` 两颗 AW88399；
  - 内置 `aw88399_acf.bin`（152416 字节，SHA-256 `1e927c9bca76d868181c0f81df2bccef3cf19c7d0910219f229360c87babd42c`）；
  - 按 `IOAudioEngineState` 启停功放；
  - 发布 `AW88399Ready` / `AW88399AmplifierRunning` 等诊断属性。
- 启用 dual-resource 补丁版 `VoodooI2C.kext` 2.9.1：
  - SPKR 的 `0x34` / `0x35` 两个 I2C 资源分别发布 nub；
  - 保留 `7F4C–7F4F` 控制器匹配。
- 启用共享 DAC 分支 `AppleALC.kext` 1.9.8：
  - pin17（低音）与 pin14（高音）共用 DAC02；
  - 通过 `alcverbs=1` 镜像音量/静音；
  - 修复“声音很小、音调偏高、播放断续”。
- 修正 HDEF `layout-id` / `alc-layout-id`：
  - 由错误的 8 字节 ASCII `"0d000000"` 改为 4 字节 `0D 00 00 00`；
  - 保留 `PciRoot(0x2)` 与 `PciRoot(0x80)` 两个兼容路径。
- boot-args 增加 `alcverbs=1`。

### 其他

- Wi-Fi 使用 `AirportItlwm-Sequoia-BE200.kext` 2.4.0，`IOPCIMatch` 含 `0x272b8086`。
- 蓝牙：IntelBluetoothFirmware 2.5.0 + IntelBTPatcher 2.5.0 + BlueToolFixup 2.7.3。
- 触摸板：VoodooI2C 2.9.1 + VoodooI2CHID 1 + VoodooInput 1.1.7。
- 移除已禁用的 `NullMothLogo.efi` 及其配置项。
- 保留 `NullMothSafe.efi` 两个 NVIDIA 恢复入口。

### 发布整理

- 清空原机 SMBIOS 三码：
  - `SystemSerialNumber`、`MLB`、`SystemUUID` 为空；
  - `ROM` 为 6 字节零；
  - 使用前必须用 GenSMBIOS 生成自己的三码。
- 删除 `_preAudioBackup`、旧 `config.plist.bak-*`、`Logs` 内容。
- 新增 README、EFI 细节、声卡原理、安装、排错、第三方组件说明。
- 新增 `tools/check-audio.sh`。

### 实测结果

| 项目 | 结果 |
| --- | --- |
| macOS | 15.8（24H23，Darwin 24.6.0） |
| AppleALC | 1.9.8 |
| VoodooI2C | 2.9.1 |
| AW88399Driver | 0.2 |
| SPKR nub | 2 个（0x34 / 0x35） |
| `AW88399Ready` | Yes |
| 播放时 `AW88399AmplifierRunning` | Yes |
| `ALC287SharedDACPrimaryPin` | 23（pin17） |
| `ALC287SharedDACSecondaryPin` | 20（pin14） |
| `ALC287SharedDACLastError` | 0 |

### 已知问题

- NVIDIA 驱动不在本包内；当前系统显示 `No Kext Loaded`。
- 3.5 mm 耳机口、HDMI/DP 音频、睡眠/唤醒、长时间播放未在本版验证。
- `DSDT.aml` 为整机补丁表，升级 BIOS 后建议重新核对。

---

## 仓库发布 v1.0 — 2026-10-27

仓库从「三份变体 + Wi-Fi 修复文件包」重构为单一 EFI 发布。

### 删除

- 旧的三份 EFI 目录：`带NVIDIA驱动修改项EFI`、`不带NVDIA驱动修改项EFI`、`EFI-1401移除OCLP支持带NV驱动修改项`；
- 旧方案依赖的 `Wi-Fi修复-所需文件/`（OCLP-Mod 3.1.9 安装包、`Ventura.zip`、诊断脚本等）。

### 新增

- 单一 `EFI/`（直接放 ESP 根目录）、`docs/`、`tools/check-audio.sh`、`THIRD-PARTY.md`、`SHA256SUMS.txt`；
- README 重写：合并旧版硬件/BIOS/NVIDIA/注意事项等内容与本版 Wi-Fi、声卡修复说明。

### 声明

- **Wi-Fi（Intel BE200）已修复**：`AirportItlwm-Sequoia-BE200 2.4.0` 原生注入，不再需要 `IOSkywalkFamily` / `IO80211FamilyLegacy`，也不需要在系统侧安装 OCLP-Mod 或打 `Post-Install Root Patch`。
- **声卡（ALC287 + 双 AW88399）已修复**：外放高音/低音同时工作，音量与静音正常。
- **彻底移除对 OCLP 的依赖**：本包不含任何 OCLP/OCLP-Mod 组件，`csr-active-config` 只需 `0x0A43`。

---

## 2026-10-27 — 内屏亮度恢复

- `boot-args` 增加 **`nvrmacpibl=1`**：由 NullMoth 的 NVKMS 自己注册内屏背光，**亮度滑块与键盘亮度键恢复可用**。
  （参考同平台 Legion 5 15IAX10 + NullMoth 的验证结论：本机内屏走独显、固件 DSDT 里只有一个空的 `_BCM` 桩，SSDT-PNLF 方案不适用。）
- **前提**：必须已安装 NullMoth 驱动；未装驱动时该参数不生效，滑块仍为灰色。
- **回退**：NullMoth 只在此参数存在时才读 GPU 的 ACPI `_DSM` / `_DOD`（默认关闭，避免少数机器在 GPU 启动阶段挂住）。若加入后开机卡在 GPU 启动阶段，删掉该参数即可。
- 同步更新：README（功能状态 / 启动参数 / NVIDIA 说明 / 更新记录）、`docs/EFI-DETAILS.md`、`docs/TROUBLESHOOTING.md`（新增 5.3 内屏亮度）。

---

## 2026-10-27 晚 — Wi-Fi 驱动升级：修复 Wi-Fi 6 连接不稳，加入 6 GHz 支持

### 驱动

- 换入新的 **`AirportItlwm-Sequoia-BE200.kext`（2.4.0 `_FIX3_20261027`，x86_64）**，替换旧构建。
- **驱动来源**：<https://github.com/Ersiter/AirportItlwm-BE200> —— BE200 专用分支，目前为**内测阶段**，尚未合并进 `OpenIntelWireless/itlwm` 主仓库，也没有对应正式 release（所以上游主仓库看不到这版）。README 与 `THIRD-PARTY.md` 已补上该仓库链接。
- 修复内容（来自驱动发布说明）：
  - **初始四次握手末包的发送与装钥时序** —— 之前表现为连上就掉、认证反复、DHCP 拿不到地址；
  - **离网时旧状态请求仍在执行** —— 切网/断网后的残留状态会让下一次关联失败。
- 保留 **6 GHz 被动扫描与结果上报**（`AirportItlwm-WCLScan6GHzMap`、`WCLChannels6GHz`、`HWScan6GHzCount`）。

### 启动参数

- 新增 **`itlwm_he=1`**：打开 HE / 802.11ax（Wi-Fi 6），也是 6 GHz（Wi-Fi 6E）能力集的入口。去掉会退回 11ac。
- 驱动只认 `itlwm_he` / `itlwm_cc` / `itlwm_tsleep` 三个参数；区域可用 `itlwm_cc=XX` 指定。

### 已知限制（上游）

- 6 GHz 目前**只做被动扫描与上报，实际关联未验证**；
- 纯 **WPA3-SAE 未实现**（WPA2-Personal / Enterprise 可连）；
- **Wi-Fi 7（EHT）未测试**；没有隔空投送 / AWDL。

### 同步更新

- `EFI/OC/config.plist`：kext 换新 + `boot-args` 追加 `itlwm_he=1` + kext 注释标注 `_FIX3_20261027`；
- README（Wi-Fi 章节 / 功能状态 / 启动参数 / 已知限制 / 更新记录）、`docs/EFI-DETAILS.md`（kext 表 + 参数表）、`docs/TROUBLESHOOTING.md`（新增 3.2.1 Wi-Fi 6 与 6 GHz）。

---

## 2026-10-31 晚 — Wi-Fi 升到 `_FIX26_20261031`（15 / 26 两份同步）

- 两份 EFI 的 Wi-Fi kext 都换到 **2.4.0 `_FIX26_20261031`**：`EFI-Sequoia/` 用 `AirportItlwm-Sequoia-BE200`，`EFI-Tahoe/` 用 `AirportItlwm-Tahoe-BE200`。
- 主要修复：**端口授权**（此前 WPA2/WPA3 关联与认证都过，但链路不建立、DHCP 拿不到地址）；RX 设备状态校验拒绝全 1 读数；直通模式只解析固件实际写入的数据；关联态扫描离/回主信道时长成对下发；接受 Cisco/Apple **Fast Lane**；高带宽信道块非法时自动 160→80→40→20 降带宽。
- 继承：BA 会话/重排计时器、MPDU 载荷边界、密钥槽重置、国家码以固件答复为准、6 GHz 开机后主动通知重读、6 GHz 后台扫描只扫 PSC、连接前结清扫描、密钥安装排队、离开 WPA3/PMF 发保护性解除关联帧、默认关闭省电、WPA3-Personal（SAE/H2E）。
- 仍为公测：Wi-Fi 7（EHT/MLO）；**macOS 15 不支持 Wi-Fi 7**。
- 同步更新 README（Wi-Fi 段 / 状态表 / 更新记录）、`README-macOS26-Tahoe.md`、`docs/EFI-DETAILS.md`、`THIRD-PARTY.md`。

---

## 2026-10-31 晚 — macOS 26 蓝牙换 FixA2DP，修 AirPods「连上没声」

- `EFI-Tahoe/EFI/OC/Kexts/BlueToolFixup.kext`：`BE200 stored-key 实验版（39,808 B，`-btlfxbe200key`）` → **FixA2DP 2.7.3（42,464 B，`-btlfxa2dpcheck`）**。
  原理：Apple 的 `bluetoothd` 在 AirPods 这类 Fast-Connect 设备重连时会先做 `HCI_Read_Clock`，Intel 控制器返回不了这个时钟，于是 A2DP 不发布音频；补丁把这道门控改成成功路径。
- `EFI-Tahoe` 的 `boot-args`：**去掉 `-btlfxbe200key`、加 `-btlfxa2dpcheck`**；`-ibtcompatbeta` 保留；`-btlfxbeta` 在 26.x 不需要。
- `IntelBluetoothFirmware-2.5.1` / `IntelBTPatcher-BE200-25x` 保持不动（与修复包 `SHA256.txt` 一致）。
- 代价：丢掉 BE200 stored-key 那条实验补丁；两条分支目前没有合并版，只能二选一。回滚备份在仓库外 `EFI/_backup-bluetooth/BlueToolFixup-BE200-Darwin25-20261016.kext`。
- 同步更新 README（26 启动参数块 + §3.4 蓝牙）、`README-macOS26-Tahoe.md`（kext 表 / 启动参数 / 变更记录）、`docs/EFI-DETAILS.md`、`docs/TROUBLESHOOTING.md`。

---

## 2026-10-29 — Wi-Fi `_FIX18_20261029` + 蓝牙 A2DP 修复

### Wi-Fi（BE200）

- 换入 **`AirportItlwm-Sequoia-BE200.kext` 2.4.0 `_FIX18_20261029`**（内测分支 <https://github.com/Ersiter/AirportItlwm-BE200>）。
- 相对 Fix3 / 社区 Fix11 的变化：
  - **6 GHz**：扫描按频段与信道正确映射，自动候选纳入 6 GHz；修正「加入 11ax 网络后 6 GHz 信道从可用列表消失」；
  - **断连**：发送队列排空失败不再引发整卡重启；固件异常时不再重复触发恢复；
  - **扫描期误判**：修正扫描过程中把正常状态误判为整卡故障并重启（那几秒网卡对外不可用，关联请求全部失败）——这是 Wi-Fi 6 不稳的主要来源；
  - **连接状态**：正确上报成功 / 失败 / 取消；
  - **监管域**：国家码变更的恢复与重复通知处理；
  - **SAE**：重复 Commit/Confirm 与重试处理，失败不在驱动内降级到 PSK；补上 **H2E（Hash to Element）**，AP 要求 H2E 时自动切换并重发 Commit。
- boot-args 保持 `itlwm_he=1`（HE / 802.11ax 与 6 GHz 能力入口）。
- **WPA3（SAE）实测仍不可用**（驱动侧虽已实现 SAE/H2E）：连接热点请用 **WPA2-Personal（AES）**；WPA3/WPA2 混合模式也可能协商到 WPA3 而失败，建议把热点加密固定为 WPA2 或单独开一个 WPA2 SSID。
- 6 GHz 实际关联仍待现场验证；Wi-Fi 7/EHT 未测试。

### 蓝牙（A2DP）

- 换入 **`BlueToolFixup.kext` 2.7.3 FixA2DP**（<https://github.com/hexxyan/BlueToolFixup-FixA2DP>，基于 acidanthera/BrcmPatchRAM）。
- 修「Intel 蓝牙 + AirPods Pro 2（8B39 等）：能连上、能切降噪、音量正常，但放音频没声音；音频会话一断就彻底没声」——macOS 蓝牙栈在第三方控制器上的 A2DP 会话恢复缺陷。
- boot-args 增加 **`-btlfxa2dpcheck`**（补丁靠该参数启用；没有它补丁不生效，也不影响其它蓝牙功能）。
- `Kernel>Add` 里 `BlueToolFixup` 的 `MinKernel` 由 21.0.0 调整为 **19.0.0**（与补丁包建议一致），`IntelBluetoothFirmware` / `IntelBTPatcher` 不动。

### 同步更新

- `EFI/OC/config.plist`：两个 kext 换新 + boot-args 增加 `-btlfxa2dpcheck` + 条目注释更新；
- README（功能状态 / Wi-Fi 章节 / 新增 3.4 蓝牙 A2DP / 启动参数 / 已知限制 / 更新记录）；
- `docs/EFI-DETAILS.md`（kext 表、Kernel/Add 说明、参数表）、`docs/TROUBLESHOOTING.md`（3.2 与 3.2.1 更新、新增 3.3.1 A2DP）、`THIRD-PARTY.md`。

---

## 2026-10-29 — 文档补记：WPA3 不可用，推荐 WPA2

> 已被 2026-10-30 的 `_FIX22_20261030` 取代：**WPA3-Personal 现已实测可用**（见下一条）。

- 按实测结论更正文档：**WPA3（WPA3-Personal / SAE）目前仍不可用**，连接 Wi-Fi 热点请使用 **WPA2-Personal（AES）**（WPA2-Enterprise/PEAP 也可）。
- WPA3/WPA2 混合模式可能协商到 WPA3 而失败；建议把热点加密固定为 WPA2，或单独开一个 WPA2 的 SSID。
- 同步更新：README（Wi-Fi 状态行、§3.1「连接建议」、§9 已知限制、§12 更新记录）、`docs/TROUBLESHOOTING.md`（3.2 与 3.2.1）、`docs/EFI-DETAILS.md`。

---

## 2026-10-30 — Wi-Fi `_FIX22_20261030`：WPA3-Personal（SAE）实测可用

### 驱动

- 换入 **`AirportItlwm-Sequoia-BE200.kext` 2.4.0 `_FIX22_20261030`**（内测分支 <https://github.com/Ersiter/AirportItlwm-BE200>）。
- **WPA3-Personal（SAE）默认走 H2E-only**，本机实测可连上；修正 AP RSNXE 的保存与四次握手校验（不再要求 AP 能力字节等于本机写死值）；CI 增加 SAE 主机测试。传统 **HnP** 隔离为默认不编译的实验兼容路径。
- **MLO / 6 GHz**：修正 MLO 关联请求长度、附属链路响应偏移与共享 AID；修正 PHY 频段比较漏掉 6 GHz。
- **EHT**：按协议检查 80/160/320 MHz 打孔位图，降宽后重新校验，避免向固件提交非法组合。
- 6 GHz 信道按固件与实际监管域许可，不建议伪造地区。

### 连接建议

- **WPA3-Personal（SAE）可用**，前提是 AP 支持 H2E；只支持 HnP 的老 WPA3 路由器连不上。
- **WPA2-Personal（AES）与 WPA2-Enterprise（PEAP）仍然完全可用**，可作为对照或保守选择。

### 仍待验证

- 6 GHz 实际关联、Wi-Fi 7 / EHT / MLO 未实测。

### 同步更新

- `EFI/OC/config.plist`：Wi-Fi kext 换新，条目注释标注 `_FIX22_20261030`。
- README（Wi-Fi 状态行、§3.1 驱动变化与「连接建议」、§9 已知限制、§12 更新记录）；`docs/TROUBLESHOOTING.md`（3.2 / 3.2.1 改为 WPA3 可用 + H2E 前提与对照方法）；`docs/EFI-DETAILS.md`、`THIRD-PARTY.md`。

---

## 2026-10-31 — 拆成 macOS 15 / 26 两份 EFI；Wi-Fi 升到 `_FIX24_20261030`

### 结构

- 仓库改为 `EFI-Sequoia/EFI/`（macOS 15.2+）与 `EFI-Tahoe/EFI/`（macOS 26.4+）两份并列，各自是 `BOOT/` + `OC/` 直接展开的形态（外层 `EFI` 目录可直接拷到 ESP 根目录，不用改名）；
- 两份的 ACPI（10 张表）、Booter、DeviceProperties、PlatformInfo、USB 端口图**完全一致**，差异只在 Wi-Fi / 蓝牙 / AppleHDA 这几组 kext 与 `boot-args`。

### macOS 26（新增）

- 实测**可以进桌面**；**未装 NullMoth 驱动时约 1–3 FPS**（固件/旧帧缓冲在推像素），装完驱动恢复正常；
- 换入 Tahoe 专用件：`AirportItlwm-Tahoe-BE200`、`IntelBluetoothFirmware-2.5.1`、`IntelBTPatcher-BE200-25x`、`SimpleHDA`、`NMHDA`、`AW88399Driver`(25.x)；
- `Kernel>Block` 增加 `com.apple.iokit.IONDRVSupport`（NullMoth 要求，防固件 framebuffer 抢 display 0）；
- `boot-args` 增加 `gfxrst=4`（装了 WhateverGreen 必需）、`-ibtcompatbeta`、`-btlfxbe200key`。

### Wi-Fi（两份都换）

- `AirportItlwm` 升到 **2.4.0 `_FIX24_20261030`**：国家码/监管域优先级（启动参数 → 固件 → 定位）与授权状态分离、监管请求被拒不再锁死后续更新、复位后硬件接管与定时器生命周期、RNR 邻居报告 → 6 GHz 定向探测、多链路信道/带宽统一校验、关闭 Wi-Fi 后 RX 中断队列；
- **明确：macOS 15 不支持 Wi-Fi 7（EHT/802.11be）**，驱动只到 802.11ax（Wi-Fi 6/6E）；26 上 EHT/MLO 仍为公测、未实测。

### 其它

- 两份 EFI 的 `Misc > Debug` 默认关闭（`Target=0`、`DisplayLevel=0`、`AppleDebug/ApplePanic=false`）；排错时改回 `67 / 2147483650 / true / true`；
- 新增 `README-macOS26-Tahoe.md`（26 包的改动清单、取舍、装驱动顺序、排错），并同步 README / `docs/EFI-DETAILS.md` / `docs/INSTALL.md` / `docs/TROUBLESHOOTING.md` / `THIRD-PARTY.md`；
- 清理 `config.plist.before-*` 备份文件，不随仓库发布。

---

## 2026-11-02 — 记录 BIOS 83WW 回归（触控板 + 雷电 USB3.2）

- 实测 BIOS 升到 **83WW** 后：内建 I2C 触控板消失（`ioreg` 无 `TPD0`）、雷电口只剩 USB 2.0、开机刷 `\_SB.UBTC._INI` / `AE_NOT_FOUND` 并拖延数十秒。
- 根因：83WW 固件把 `Device (PC02)` 包在 `If (PCHA)` 中，macOS 侧 `PCHA` 读 0 → `\_SB.PC02` 整段不加载 → `\_SB.PC02.I2C1.TPD0` 不存在；雷电 SS 通道同样未拉起。
- 三种 EFI 侧修法（拆 `If (PCHA)` / 离线预打补丁 DSDT / 在 `\_SB.PC02.I2C1` 下自建 `TPD1`）全部卡在 `\_SB.UBTC._INI` 的 `AE_NOT_FOUND` 连锁，确认无解。
- **回退 78WW 后触控板与雷电口 USB 3.2 均恢复**；实测 `UTBMap` 的 `TXHC` 用 3 口或 5 口都能正常识别 USB 3.2，仓库保持原版 3 口。
- 文档：README 第 6 节改为「BIOS 必须停留在 78WW」对照表 + 警告；`docs/INSTALL.md` Thunderbolt 行；`docs/TROUBLESHOOTING.md` 新增 1.0 节；`docs/EFI-DETAILS.md` DSDT 说明。

---

## 2026-11-01 — Wi-Fi 升到 `_FIX29_20261101`（15 / 26 两份同步）

- 两份 EFI 的 Wi-Fi kext 都换到 **2.4.0 `_FIX29_20261101`**：`EFI-Sequoia/` 用 `AirportItlwm-Sequoia-BE200`，`EFI-Tahoe/` 用 `AirportItlwm-Tahoe-BE200`。
- **6 GHz SSID**：从 Multiple BSSID 元素的 profile 中解析各 BSS 的名字并逐条发布，BSSID 优先取 RNR 声明的地址；此前 6 GHz 网络始终没有名字。
- SSID 解析分六种状态记录（正常/隐藏/全零/超长/无元素/截断）；每条 profile 使用自己的 IE、RSN 与能力字段。
- **6 GHz 关联**在 RSNE 里强制置 MFPC/MFPR（802.11ax 要求）。
- 扫描：完成通知按批次归属判定；接收计数前移；FCS 与 IE 长度一次性计算；新增 CI 主机测试。
- 继承 Fix26–Fix28：端口授权、换网一次切换、6 GHz 监管重读、WPA3/PMF 装钥失败上报、Fast Lane、保护性解除关联帧、默认关省电。
- 同步更新 README（Wi-Fi 段/状态表/更新记录）、`docs/EFI-DETAILS.md`、`THIRD-PARTY.md`、`README-macOS26-Tahoe.md`。

---

## 2026-11-06 — 记录 NullMoth 2.7.2 与声卡的冲突

- 升级 NVIDIA 驱动到 **2.7.2** 后，安装器会往 `/Library/Extensions` 放入 **`NMXAudio.kext`**，顶掉 `SimpleHDA` 提供的 HDA 路径。
- 症状：**音量开到最大爆音**；**`AW88399Driver` 不生效、外放声音明显变小**。
- 处理（终端执行后重启）：`sudo rm -rf /Library/Extensions/NMXAudio.kext && sudo kmutil install --update-all`。
- 该操作只影响音频 kext，NVIDIA 的 `NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC` 不受影响。
- 同步更新 README（第 3.2 声卡 + 第 10 NVIDIA + 更新记录）、`docs/TROUBLESHOOTING.md`（新增 2.4）、`docs/INSTALL.md`、`docs/AUDIO-AW88399.md`。
- 补充：不删 kext 的替代做法——`NMXAudio`/`NMHDA` 是 Lilu 插件（`com.nullmoth.NMHDA`），源码定义 `bootargOff = "-nmhdaoff"`，在 `boot-args` 加该参数或在 `Kernel>Block` 里屏蔽即可（代价：NVIDIA HDMI/DP 音频同时关闭）。来源：<https://github.com/nullmoth/nvidia-macos-driver>（`kexts/NMHDA/nmhda.cpp`）。

---

## 2026-11-06 — `EFI-Tahoe` 默认加 `-nmhdaoff`，保留 SimpleHDA / AW88399 外放

- NullMoth 2.7.2 在 macOS 26 上会安装 `NMXAudio.kext`（FreeBSD `snd_hda` 的 XNU 移植），顶掉 `SimpleHDA` 的 HDA 路径，导致最大音量爆音、`AW88399Driver` 不生效（外放很小）。
- ~~`EFI-Tahoe/` 的 `boot-args` 末尾追加 `-nmhdaoff`~~ **（已撤销，见 2026-11-06 更正）**：该参数只关 `NMHDA`，对 `NMXAudio.kext` 无效。
- 影响：**ALC287 + 双 AW88399（layout 13 共享 DAC）外放/耳机正常**；**NVIDIA HDMI/DP 音频不可用**；显卡、亮度、Wi-Fi、蓝牙不受影响。
- `EFI-Sequoia/` 不加该参数（macOS 15 自带 AppleHDA，加了只会丢 HDMI 音频）。
- 同步：README 第 3.2 / 第 7 / 更新记录、`README-macOS26-Tahoe.md`、`docs/EFI-DETAILS.md`、`docs/TROUBLESHOOTING.md`。

---

## 2026-11-06（更正） — `-nmhdaoff` 对 `NMXAudio.kext` 无效，已从 EFI 移除

- 实测：`EFI-Tahoe` 加了 `-nmhdaoff` 后重启，声音依旧不正常；只有执行 `sudo rm -rf /Library/Extensions/NMXAudio.kext && sudo kmutil install --update-all` 并重启才恢复。
- 原因：`-nmhdaoff` 是 `NMHDA`（Lilu 插件，补 NVIDIA HDA 设备 ID）的开关；`NMXAudio.kext` 是 FreeBSD `snd_hda` 在 XNU 上的移植，不是 Lilu 插件，不解析 Lilu 启动参数。
- 已把 `-nmhdaoff` 从 `EFI-Tahoe/` 的 `boot-args` 移除；`NMHDA.kext` 保持启用（NVIDIA HDMI/DP 音频可用）。
- 26 上恢复外放的可靠做法：删除 `NMXAudio.kext` 并重建内核缓存；EFI 侧若要尝试，只能用 `Kernel>Block` 按其 bundle id 屏蔽（需实测）。
- 文档同步：README 第 3.2/第 7/更新记录、`README-macOS26-Tahoe.md`、`docs/EFI-DETAILS.md`、`docs/TROUBLESHOOTING.md`。

---

## 2026-11-09 — 拆出 83WW 专用 EFI（`EFI-Tahoe-83WW/`）

- 实测确认 **BIOS 版本决定 `PC02` 子树内容**：78WW 的 `If (PCHA)` 块里还包着 `UBTC`/`UCM`/`UCH`/`UBST`/`DGPB`/`DGPS`，拆开后 `_INI` 找不到 `UBSC`（Region）等依赖 → `AE_NOT_FOUND` 连锁 → **开不了机**（78WW + 83WW 配方，2026-11-09 实测）。
- **方案来源**：BIOS 83WW 的修复方案（两条 PC02 补丁、`APIC-CPU24` 替换、`TXHC` 5 口映射）由 [**Ersiter**](https://github.com/Ersiter) 提供，本仓库在其基础上整理（去掉核显部分、保留蓝牙 A2DP 等）。
- 新增目录 `EFI-Tahoe-83WW/EFI`（macOS 26 + 83WW）：**无 `DSDT.aml`**、`ACPI>Delete` 856 字节 APIC、加 `APIC-CPU24.aml`、两条 PC02 补丁（`a04e2f92…` / `a08e7716…`）、`TXHC` 5 口、boot-args 追加 `TSC_sync_margin=0`。
- 该变体以一份**已在 83WW 实测可用**的同机型 EFI 为参考，但**去掉了核显部分**（`XeGfxIntelFB`、`SSDT-DGPU-HYB`、`-nmintelfboff` 等），保留本仓库的蓝牙 A2DP、`Kernel>Block`、`NullMothSafe` 工具、`MacBookPro16,2`。
- **2026-11-09 在 83WW 上实测通过**：正常进桌面，内建触控板与雷电口 USB 3.2 均正常（验证用的 EFI 与仓库 `EFI-Tahoe-83WW/EFI` 逐字节一致，仅 `config.plist` 多一条 DSDT 禁用的占位条目）。
- `EFI-Tahoe/`（78WW）与 `EFI-Sequoia/`（78WW）保持不变。
- 新增 `docs/BIOS-VERSIONS.md`（对照、原理、历史尝试、切换与回滚）；同步 README（顶部/§4/§5/§6/更新记录/文档索引）、`docs/INSTALL.md`、`docs/EFI-DETAILS.md`（7.1 节）、`docs/TROUBLESHOOTING.md`（1.0 节）、`README-macOS26-Tahoe.md`。
