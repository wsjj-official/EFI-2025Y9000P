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
