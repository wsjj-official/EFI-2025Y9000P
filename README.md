# Lenovo Y9000P 2025 (U9-275HX) — OpenCore EFI 存档

适用机型：**联想 Y9000P 2025 / Core Ultra 9 275HX / RTX5070Ti** ，BIOS版本 **78WW** **本EFI由DeepSeek -V4修复生成**

系统环境（验证时）：macOS Sequoia **15.7.8 (24G824)**，OpenCore **1.0.8 RELEASE**（官方版，
四个引导文件与官方包逐字节一致）
本目录整理时间：2026-10-14
本目录最后更新：**2026-10-16 —— BE200 无线网卡已打通**（两份变体都同步了，见 6.1 节与下面的「更新记录」）

> 这份 EFI 是**为上述这一台机器**做的：里面带了这台机器的身份信息（SMBIOS 三码）、
> 一份属于这台机器固件的 DSDT、以及按这块板子物理 USB 口做的端口图。
> 拷到别的机器前请先读第 7 节。

---

## 0. 目录结构

```
EFI-Y9000P-2025-U9-275HX-78WW\
├─ README.md                  ← 本文件
├─ EFI\                       ← 实际引导用的 EFI 树（拷到 ESP 根目录）
│   ├─ BOOT\BOOTx64.efi
│   └─ OC\
│       ├─ config.plist       ← 当前生效配置（SHA256 见第 8 节）
│       ├─ OpenCore.efi / OpenRuntime.efi / Drivers\ / Tools\
│       ├─ ACPI\              ← 1 份 DSDT + 14 个 SSDT 文件（配置里实际加载 1 DSDT + 11 SSDT）
│       ├─ Kexts\             ← 29 个顶层 kext + 7 个插件包（config 里共 36 条，启用 32 条）
│       └─ Resources\         ← OpenCanopy 主题资源
```

> **2026-10-16 新增内容**
>
> - `Wi-Fi修复-所需文件\`：OCLP-Mod 3.1.9 的两个安装包（`OCLP-Mod.pkg` + `AutoPkg-Assets.pkg`）、
>   驱动原件 `Ventura.zip`、4 个诊断脚本（`BE200-诊断` / `BE200-手动连WiFi` / `亮度诊断` / `USB诊断`）
>   与上机说明 `读我-先看这个.txt`
> - 每个变体下的 `_alt\config.plist.before-wififix-20261016`：本次改动前的 config 备份
> - 每个变体下的 `EFI\OC\Logs\`：OpenCore 启动日志落盘目录（`Misc>Debug>Target = 67` 已打开）

### 更新记录

**2026-10-16 —— BE200 无线网卡打通，两份变体已同步**

- `Kernel>Add` +3（`IOSkywalkFamily` / `IO80211FamilyLegacy` / `AirportItlwm`）、
  `Kernel>Block` +1（屏蔽系统自带的 `IOSkywalkFamily`）、`csr-active-config` → `0xFF0F0000`、
  `Misc>Debug>Target` → `67`；
  `不带NVDIA驱动修改项EFI` 里 `SSDT-Disable_Network_RP08.aml` 由 `true` 改为 `false`
  （原来把 BE200 藏起来了，开着 Wi-Fi 永远不可能工作）。
- 系统侧再跑一次 **OCLP-Mod 3.1.9** 的 `Post-Install Root Patch`（列表里会出现「网络：Intel无线网卡」），
  安装包与完整步骤见 `Wi-Fi修复-所需文件\`。详见 6.1 节与 8.1 节。
- 实测（2026-10-15 夜日志）：三个 kext 均加载、`en5` 报 `fw: 90.38c93dbc.0`、信道表完整
  （2.4G 1–13 / 5G 36–177）、`/System/Library/CoreServices/oclp-mod.plist` 里有 `Intel无线网卡` 补丁记录。
- 新增 4 个诊断脚本：`BE200-诊断` / `BE200-手动连WiFi` / `亮度诊断` / `USB诊断`。

- 

**2026-10-16 —— 两个"待查"项的阶段性结论**

- **内屏亮度（暂缓）**：内屏由独显输出（2560x1600@240Hz，NullMoth `NVRM/NVAccel/NVRMFB`），
  而本机固件 DSDT 里**完全没有 `_BCM`/`_BQC` 背光方法**，`GFX0`（核显）下没有显示子设备，
  全局 `BRTN` 方法指向不存在的 `DD1F/DD2F`。常规"SSDT-PNLF + WhateverGreen"那套不适用，
  亮度只能从独显驱动栈或 EC 走；继续查用 `亮度诊断.command`。
- **USB 左侧口读不出 U 盘（已解决，见下面的"深夜更新"）**：macOS 下只有两个 xHCI —— `\_SB.PC02.XHCI`
  （被 SSDT 改名 `XHC2`，PCH 主控；USB2 = 端口 1–14，USB3(SS) = 17–26）与
  `\_SB.PC00.TXHC`（USB4/雷电4 控制器，只有 3 个端口）。macOS 每个控制器只有 **15 个端口**额度，
  17–26 的 SuperSpeed 端口够不着 —— 这正解释了"雷电口认 U 盘、左侧口不认"。
  取证脚本 `USB诊断.command`；开关是 `Kernel>Quirks>XhciPortLimit`（**现已打开**）。

### 2026-10-16 深夜 —— 两项都有结果了（重要更新）

**1. USB：`Kernel>Quirks>XhciPortLimit = true` 在本机 Sequoia 上确实生效**

- 实测：打开这个开关后重启，**左侧 USB-A / 左侧 Type-C / 雷电4 全部能正确识别 USB 3.0 设备**
  （用户实测结论）。之前左侧 USB-A 连 U 盘都认不到、Type-C 只能跑 480 Mbps 的问题随之消失。
- 这把之前的判断修正了一部分：原来写"17–26 号 SuperSpeed 端口超出 macOS 15 端口上限、
  没有绕过的办法"，实际上 OpenCore 的这个补丁在本机 **是有效的**（`XhciPortLimit` 会给
  `AppleUSBXHCI` / `AppleUSBXHCIPCI` / `IOUSBHostFamily` 打补丁、移除 15 端口上限）。
  仍然保持 **`UTBMap.kext` 不动**（26 + 26 + 3 个端口的映射现在反而都派上用场了）。
- 已把 `XhciPortLimit = true` 固化进三份 config，改动前的备份是
  `*.before-xhciportlimit-20261016`（哈希见 8.1 表）。

**2. Wi-Fi：这一版启动里 扫描 + 关联 + DHCP + 上网全通了**

证据（2026-10-16 00:20–00:25 的采集）：

- `system_profiler` 里出现 `Local Wi-Fi Networks:` 段（能看到 5GHz / ch36 的邻网）→ **扫描有结果**
- `wdutil info`：`SSID`/`BSSID` 有值、`RSSI -33 dBm`、`Tx Rate 58 Mbps`、`PHY Mode 11n`、
  `NSS 2`、`Security WPA2 Personal`、`Channel 2g1/20`
- 拿到地址：`IPv4 10.185.13.247`（路由器 `10.185.13.63`）、IPv6 全局地址若干、`Apple: Reachable`
- 同时段抓的 Wireless Diagnostics 包里 `diagnostics-connectivity.txt` 显示 **00:21:30 时还没通**
  （ping DNS 失败），说明这次是"先扫描、再连上"的正常过程；前几次开机扫不到，与 EFI 无关
  （同样的 config 在这几次都一样），属于上游所说的**扫描不稳定**。
- 遇到扫不到时的处置：重启、或在 Wi-Fi 菜单里关一下再开；要留证据就跑 `扫描监视.command`。

---

## 1. 硬件与系统概况

| 项目 | 值 |
|---|---|
| 机型 | Lenovo Y9000P 2025（Legion 级别，ACPI OEM ID `LENOVO CB-01`） |
| CPU | Intel Core Ultra 9 275HX（Arrow Lake-HX） |
| 内屏 | 2560x1600（由独显输出，见第 4 节） |
| 独显 | NVIDIA（PCI `10de:2f58`），由 NullMoth 驱动套件驱动 |
| 核显 | Intel `8086:7d67`，**未驱动**（没有 framebuffer/加速） |
| 有线网卡 | Intel Ethernet Controller **I226-V**（`8086:125c` 等），驱动 `AppleIGC`，`en0` built-in |
| 无线网卡 | Intel **BE200**（`8086:272b`，ACPI `\_SB.PC02.RP08`）—— **已驱动**（2026-10-16）：`AirportItlwm`(Ventura/BE200 版) + `IOSkywalkFamily` + `IO80211FamilyLegacy` + OCLP-Mod 根补丁，扫不到网络时用「其他网络…」手填 SSID，见 6.1 节 |
| 声卡 | Intel HDA 控制器 `8086:7f50`（ACPI `\_SB.PC02.HDAS`）+ Realtek ALC287 codec |
| 触摸板 | Goodix **GXTP5100**（I2C，挂在 `\_SB.PC02.I2C1`） |
| 键盘 | 真 PS/2（`PNP0303`） |
| 蓝牙 | Intel 网卡自带（走蓝牙串口 dext），状态见第 3 节 |
| 摄像头 | 「Integrated Camera」（USB UVC），能被系统识别 |
| 存储 | 两个 NVMe 控制器（`IONVMeController` ×2） |

---

## 2. BIOS 设置（必须这样设）

| 项目 | 值 | 原因 |
|---|---|---|
| **Secure Boot** | **关闭 (Disabled)** | 配置里 `Misc>Security>SecureBootModel = Disabled`、`Vault = Optional`；开着安全启动会拦 OpenCore 的引导链 |
| **VT-d (Intel VT for Directed I/O)** | **关闭** | 配置里 `ACPI>Delete` 丢掉了 DMAR 表（注释原话：*Core Ultra hangs at the kernel hand-off with it*），并且 `Kernel>Quirks>DisableIoMapper = true`；BIOS 里开着 VT-d 与这两项冲突，可能导致内核交接处卡死 |
| CPU 虚拟化 (VT-x) | 可保持开启 | 与上面两项无关 |
| 启动模式 | UEFI（不要 Legacy/CSM） | OpenCore 只走 UEFI |
| 硬盘模式 | AHCI / 纯 NVMe（不要 Intel RST / RAID） | macOS 不认 RST |
| Above 4G Decoding / Resizable BAR | **保持默认，不要动** | 配置里 `Booter>Quirks>ResizeAppleGpuBars = -1`、`UEFI>Quirks>ResizeGpuBars = -1`，即"交还固件原值"。厂商安装器脚本特意保留现状（原话：*A fixed 8 GB resize hung reported firmware before the picker*） |
| 显卡模式 (MUX / Hybrid / Discrete) | 按需要选，但注意代价 | 内屏交给独显 = 有独显输出但开机多 ~98 秒（第 4 节）；切混合/集显 = 开机快，但独显不推内屏 |

BIOS 版本 78WW 是本机实测可用的版本；换别的 BIOS 版本请重新验证（原因见第 5 节的 DSDT 说明）。

---

## 3. 驱动清单：哪些能用、哪些不能用

### 3.1 已驱动 / 工作（有 ioreg 或日志证据）

| 设备 | 驱动（kext / 组件） | 证据 |
|---|---|---|
| PS/2 键盘 | `VoodooPS2Controller 2.3.8` → `VoodooPS2Keyboard` | ioreg `ApplePS2Keyboard` 挂在 `ApplePS2KeyboardDevice` 下 |
| I2C 触摸板 (GXTP5100) | `VoodooI2C 2.9.1` + `VoodooI2CHID 1.0`（含 `VoodooGPIO 1.1`、`VoodooI2CServices 1.0`、`VoodooInput 1.1.7`）+ `SSDT-...-TPD0-ARL` | ioreg `VoodooI2CHIDDevice`、`TPD0`（`IOName = GXTP5100`）已匹配 |
| 内屏显示（2560x1600） | **NullMoth** 的 `NVRMFB` / `NVRM` / `NVAccel` / `NVRMAGDC`（**不在 EFI 里**，见第 8 节） | ioreg `NVRMFBClaim`/`NVAccel` 已挂；日志 `NVRM-fb: fb0 ... 2560x1600` |
| 电池 / EC / 传感器 | `VirtualSMC 1.3.9` + `SMCBatteryManager 1.3.9` + `SMCSuperIO 1.3.9` + `SMCProcessor 1.3.9` + `SMCLightSensor 1.3.9` + `SSDT-EC` / `SSDT-SBUS-MCHC` | 日志 `AppleSmartBatteryManager` 定时轮询、ioreg 有 `SMCSuperIO` |
| 热键 / 平台动作键 | `YogaSMC 1.5.3` + `BrightnessKeys 1.0.4` | 日志 `Received kext load notification: org.zhen.YogaSMC` |
| USB | `USBToolBox 1.2.0` + `UTBMap 1.1`（XHCI 26 口 / XHC2 26 口 / TXHC 3 口） | ioreg 里 USB 摄像头等设备正常枚举 |
| NVMe | `NVMeFix 1.1.4`（`SetApfsTrimTimeout = -1`，trim 交系统默认） | ioreg 两个 `IONVMeController` 已匹配 |
| 有线网卡 (I226-V) | `AppleIGC 1.9` | ioreg `Model = "Intel(R) Ethernet Controller I226-V (IGC)"`、`en0`（`IOBuiltin = Yes`） |
| 摄像头 | 系统原生 UVC | ioreg `Integrated Camera@14b00000` + `UVCAssistant` 进程 |
| 安卓 USB 网络共享 | `HoRNDIS 9.2` | 已加载（无线没驱动时的上网备选） |
| 内存 / 平台伪装 | `RestrictEvents 1.1.7`、`AMFIPass 1.4.1`、`AppleMCEReporterDisabler 1.2`、`CpuTscSync 1.1.3` | 已加载 |
| 声卡（内置扬声器 + 内置麦克风） | `AppleALC 1.9.9` 驱动原版 `AppleHDA`，layout 13 | 2026-10-14 实测：扬声器出声、内置麦克风可用（注入见 5.6 / 6.2 节） |

### 3.2 没有驱动 / 有问题

| 设备 | 状态 | 说明 |
|---|---|---|
| **无线网卡（BE200）** | **已修复（2026-10-16）** | EFI 里注入了 `AirportItlwm` + `IOSkywalkFamily` + `IO80211FamilyLegacy`，系统侧再跑一次 OCLP-Mod 根补丁即可。见第 6.1 节。遗留：只有 11ac（2.4/5GHz），没有 6GHz/隔空投送，扫描偶有不稳 |
| **扬声器音量偏小** | **缺 AW88399 功放驱动**（不在 EFI 内） | 左右声道各一颗 Awinic 智能功放（ACPI `\_SB.PC02.I2C2.SPKR`，`_HID = AWDZ8399`，I2C2 上 `0x34`/`0x35`），没有驱动就停在上电默认的低增益状态。macOS 无此驱动；Linux 需板级驱动 + ACF 固件。见第 6.2 节与 |
| 核显（`8086:7d67`） | 未驱动 | 没注入 `ig-platform-id`，`IONDRVFramebuffer` 实例 0；内屏走独显 |
| 独显（NVIDIA） | 只有 NullMoth 这套（framebuffer + Metal 翻译层），**不是原生加速** | 开机那 ~98 秒就是它的代价，见第 4 节 |
| 睡眠 / 唤醒 | **未测试** | 需要实测（合盖、手动睡眠、唤醒、唤醒后触摸板/键盘/网卡是否恢复） |
| HDMI / DP 外接输出 | **未测试** | 与独显的模式设定有关，建议实测 |

---

## 4. 开机时间为什么长（约 98 秒屏幕没有输出，问题出现在已经打了1401的NVIDIA驱动那份EFI）

### 4.1 结论

屏幕上「卡住不动」的那段时间，是**独显驱动把内屏接起来**的过程：这个阶段没有任何东西往控制台
打印，所以画面一直停在最后几行（也就是 `VoodooI2C...` / `Notification consumer published...` /
`VoodooI2CPCIController::pci8086,7f4d` 那几行）。

---

## 5. 这份 EFI 打了哪些补丁 / 做了哪些改动

### 5.1 ACPI 层

**`ACPI>Add`：13 条，其中 12 条启用（1 份自带 DSDT + 11 个 SSDT）**

`ACPI\` 目录里一共 15 个 `.aml`：1 份 DSDT + 14 个 SSDT。下面表格里的 12 个 SSDT 就是
"启用 / 被关 / 未登记"的全貌 —— 注意有 **2 个 SSDT 文件没有登记在 config 里**
（`USB-RHUB`、`NoRp21-Samsung`），它们不会生效，只作为资料保留。

| 文件 | 作用 |
|---|---|
| `DSDT.aml` | **自带本机固件 DSDT 的转储**（`LENOVO CB-01`，671,581 字节），用来覆盖固件那份；里面**已经预打了重命名**（出现 `XSTA`×2、`XOSI`×11、`XCRS`×1、`XHID`×1） |
| `SSDT-Y9000P_AXI10-HPET.aml` | HPET 修补（配合下面两条 HPET 改名），让系统用得上 HPET 定时器 |
| `SSDT-Y9000P_AXI10-EC.aml` | 补一个虚拟 EC（`SsdtEC`），AppleSMC 需要 |
| `SSDT-Y9000P_AXI10-USBX.aml` | USB 供电/电源属性（`UsbPowerProperties`） |
| `SSDT-Y9000P_AXI10-PLUG-ALT.aml` | CPU 电源管理（`CpuPlugA`，SSDT-PLUG 的替代写法，供 XCPM 使用） |
| `SSDT-Y9000P_AXI10-RTCAWAC.aml` | RTC/AWAC 相关修补 |
| `SSDT-Y9000P_AXI10-USB-Reset.aml` | USB 控制器复位（配合 USBToolBox 端口图） |
| `SSDT-Y9000P_AXI10-XOSI.aml` | 提供 `XOSI` 方法（配合 `_OSI`→`XOSI` 改名，向固件伪装系统版本） |
| `SSDT-Y9000P_AXI10-SBUS-MCHC.aml` | 补 SMBus/MCHC 设备（传感器与 SMC 相关） |
| `SSDT-Y9000P_AXI10-GPI0.aml` | 把 `\_SB.GPI0` 的 `_STA` 改名并强制可用（I2C 触摸板的中断需要 GPI0） |
| `SSDT-Y9000P_AXI10-TPD0-ARL.aml` | 定义 I2C 触摸板设备：把 Goodix **GXTP5100** 挂到 `\_SB.PC02.I2C1`（`TPD0`/`TPD1`、`_CID = PNP0C50`、`_SUB = GOOD0001`） |
| `SSDT-Y9000P_AXI10-PS2K-HID.aml` | 把 `\_SB.PC00.LPCB.PS2K` 的 `_HID` 改名（`PNP0303`），让 VoodooPS2Keyboard 能按预期匹配 |
| `SSDT-Disable_Network_RP08.aml` | 屏蔽 `\_SB.PC02.RP08`（无线网卡所在根端口）。**当前 `Enabled = false`（不加载）** |
| `SSDT-Y9000P_AXI10-NoRp21-Samsung.aml` | 针对"Samsung NVMe 在 RP21"的机型的处理。**文件在但不在这份加载表里**（你的机器没用到） |
| `SSDT-Y9000P_AXI10-USB-RHUB.aml` | USB 根集线器（RHUB）相关处理。**文件在但也不在这份加载表里**（当前 `USB-Reset.aml` 承担了这部分） |

**`ACPI>Delete`（1 条）**

- `Drop VT-d DMAR` —— 丢掉 DMAR 表（注释原话：Core Ultra 在它存在时内核交接处会卡住）

**`ACPI>Patch`（9 条，作用范围是 OpenCore 加载的所有 ACPI 表）**

| 注释 | Find（十六进制） |
|---|---|
| `_OSI to XOSI rename - requires SSDT-XOSI.aml` | `5F4F5349` |
| `GPI0 _STA to XSTA Rename` | `505314145F535441` |
| `HPET _STA to XSTA Rename` | `0014115F535441` |
| `HPET _CRS to XCRS Rename` | `255F435253` |
| `PS2K _HID to XHID Rename (with SSDT-PS2K-HID)` | `82440E5053324B144A0A5F48494408A048059193` |
| `Remove conditional ACPI scope declaration` | `A000000092935043484100` |
| `IPIC IRQ 2 Patch` | `2204007900` |
| `RTC IRQ 8 Patch` | `2200017900` |
| `TIMR IRQ 0 Patch` | `2201007900` |

### 5.2 Kernel 层（kext 与内核补丁）

**`Kernel>Add`（36 条，启用 32 条；下面列的是可见的 kext 与版本，标 ★ 的是被关掉的 4 条）**

> 2026-10-16 新增的三条（插在列表最前面，`MinKernel = 23.0.0` 的两条只在 Sonoma 及更新系统加载）：
> `IOSkywalkFamily.kext`（OCLP-Mod payload 1.2.0）、`IO80211FamilyLegacy.kext`（1.0.0）、
> `AirportItlwm.kext`（zxystd itlwm issue #955 的 Ventura/BE200 二进制，`IOPCIPrimaryMatch` 含
> `0x272b8086`，二进制 SHA256 `b4555bd8…f810b7`）。前两个 kext 与 OCLP-Mod 3.1.9 自带 payload
> **逐字节一致**。

```
Lilu 1.7.3                 VirtualSMC 1.3.9             WhateverGreen 1.7.2
AppleALC 1.9.9             AppleIGC 1.9                 AppleMCEReporterDisabler 1.2
AMFIPass 1.4.1             RestrictEvents 1.1.7         NVMeFix 1.1.4
CpuTscSync 1.1.3           BrightnessKeys 1.0.4         SMCBatteryManager 1.3.9
SMCLightSensor 1.3.9       SMCProcessor 1.3.9           SMCSuperIO 1.3.9
USBToolBox 1.2.0           UTBMap 1.1                   IntelBluetoothFirmware 2.5.0
IntelBTPatcher 2.5.0       BlueToolFixup 2.7.3          YogaSMC 1.5.3
HoRNDIS 9.2                VoodooI2C 2.9.1 (+ VoodooI2CServices / VoodooGPIO / VoodooInput 1.1.7)
VoodooI2CHID 1.0           VoodooPS2Controller 2.3.8 (+ VoodooPS2Keyboard 2.3.8)
★ CpuTopologyRebuild 2.0.2      ★ VoodooPS2Controller 里的 VoodooInput 1.1.7
★ VoodooPS2Mouse 2.3.8           ★ VoodooPS2Trackpad 2.3.8
```

★ 的四个说明：`CpuTopologyRebuild` 关（不需要重建拓扑）；PS2 的 `VoodooInput` 插件关（I2C 那边已有一份，
重复加载会冲突）；`VoodooPS2Mouse` / `VoodooPS2Trackpad` 关 —— **这是这份 EFI 相比原始版唯一的功能改动**：
这台机器的 PS/2 aux（鼠标）通道后面没有设备（触摸板是 I2C 的 GXTP5100），这两个插件只会不停超时，
每超时一次向屏幕打一行 `Timed out on input stream 1.`。

**`Kernel>Block`**：`com.apple.iokit.IONDRVSupport`（`Strategy = Exclude`），**当前 `Enabled = false`**。
2026-10-16 另加一条：`com.apple.iokit.IOSkywalkFamily`（`Strategy = Exclude`、`MinKernel = 23.0.0`、**启用**），
用来屏蔽系统自带的 `IOSkywalkFamily`，改用 EFI 注入的 1.2.0（`IO80211FamilyLegacy` 依赖它）。
（注意：`不带NVDIA驱动修改项EFI` 那份原来的 `Block` 是空数组，本次只加了这一条。）
厂商安装器的规则：内屏由独显推画面时可以打开它，防止固件 framebuffer 抢走 display index 0；
内屏走 Intel 核显 + 固件 framebuffer 时打开会黑屏。现在这个位置属于"安全的一侧"。

**`Kernel>Patch`**：2 条 `1401 fallback | ... | Remove non-monotonic time panic`（内核时间戳非单调导致的
panic 兜底），**两条都是 `Enabled = false`**（只作为备用）。

**`Kernel>Emulate`**：`Cpuid1Data = 55 06 0A 00 ...` / `Cpuid1Mask = FF FF FF FF ...`，把 CPU 的
CPUID 特征位伪装成 macOS 认得的型号（配合 `ProvideCurrentCpuInfo`，这是 Arrow Lake 能起来的关键之一）。

**`Kernel>Quirks`（与默认不同的项）**：`AppleXcpmCfgLock = true`（CPU 电源管理寄存器锁定绕过）、
`AppleXcpmForceBoost = true`、`CustomSMBIOSGuid = true`、**`DisableIoMapper = true`（配合 BIOS 关 VT-d）**、
`DisableLinkeditJettison = true`、`PanicNoKextDump = true`、`PowerTimeoutKernelPanic = true`、
`ProvideCurrentCpuInfo = true`、`SetApfsTrimTimeout = -1`。

### 5.3 Booter 层（引导期内存/固件修补）

- **`Booter>Quirks`**：`AvoidRuntimeDefrag`、`DevirtualiseMmio`、
  `AllowRelocationBlock`、`EnableSafeModeSlide`、`FixupAppleEfiImages`、`ProtectUefiServices`、
  `ProvideCustomSlide`（`ProvideMaxSlide = 0`）、`RebuildAppleMemoryMap`、`SetupVirtualMap = true`、
  `SyncRuntimePermissions = true`、**`ResizeAppleGpuBars = -1`**（交还固件原值，配合 NullMoth 驱动）；
  `EnableWriteUnprotector = false`。
- **`Booter>MmioWhitelist`（1 条）**：`Preserve runtime MMIO 0xFF000000`（保留 0xFF000000 这段运行时
  MMIO，配合 `DevirtualiseMmio`）。这是**按这块板子的内存映射做的**，换机器要重新确认。
- **`Booter>Patch`（1 条）**：`macOS to hacOS`（把 `macOS` 字符串替换成 `hacOS`，**`Enabled = false`**）。

### 5.4 UEFI 层

- **`UEFI>Drivers`**：`HfsPlus.efi`、`OpenRuntime.efi`、`ResetNvramEntry.efi`、
  `NullMothLogo.efi`（纯装饰的开机 logo）、`OpenCanopy.efi`（图形启动菜单）
- **`UEFI>Quirks`**：`ReleaseUsbOwnership = true`、`RequestBootVarRouting = true`、
  **`ResizeGpuBars = -1`**（与 `ResizeAppleGpuBars` 配套）
- **`UEFI>ProtocolOverrides`**：`AppleDebugLog = true`（每次开机往 Apple debug log 写一份 OC 日志，
  排查用，日常可以关）、`FirmwareVolume = true`
- **`Misc>Tools`（2 项）**：`NullMothSafe.efi` —— 厂商给的两个启动菜单工具：
  「下次开机卸掉 NVIDIA 驱动」和「这一次不带 NVIDIA 驱动启动」（`Arguments: once`）。
  **这两个不要删**，是驱动出问题时的退路

### 5.5 NVRAM 层

**`boot-args`（当前值，逐项解释）**

```
-v debug=0x100 keepsyms=1 -vi2c-force-polling nvfb=1 nvaccel=1 nvfbheads=4
-nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 alcid=13
```

（`不带NVDIA驱动修改项EFI` 那份的 boot-args 与上面相同，只是开头没有 `-v`。）

| 参数 | 含义 |
|---|---|
| `-v debug=0x100 keepsyms=1` | 详细模式 + 关看门狗 + panic 保留符号（排错用，就是屏幕上那串启动日志） |
| `-vi2c-force-polling` | VoodooI2C 强制轮询（中断不通时的兜底模式） |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | NullMoth NVIDIA 驱动的四项：帧缓冲 / 加速 / 4 个显示头 / 关闭 KMS 平滑 |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | 放宽 AMFI（配合 `AMFIPass.kext`，让第三方/未签名 kext 能加载） |
| `ipc_control_port_options=0` | 解决部分机器的 IPC 端口问题 |
| `alcid=13` | AppleALC 用 layout 13（声卡，2026-10-14 起生效，见第 6.2 节） |

注意：`NVRAM>Delete` 列表里**包含 `boot-args`**，也就是每次开机都由 config 重写这串参数；
如果你在 macOS 里用 `nvram boot-args=...` 改，重启就没了，要么改 config，要么把它从 `Delete` 里去掉。

**其它 NVRAM 项**：`csr-active-config = 0xFF0F0000`（2026-10-16 由 `0x0A43` 改来；这是 OCLP-Mod
打根补丁要求的"SIP 基本全开解锁"档，含 `CSR_ALLOW_UNAUTHENTICATED_ROOT` 等 12 位）、`run-efi-updater = No`、
`revcpu = 1` / `revcpuname = "Intel(R) Core(TM) Ultra 9 275HX"` / `revpatch = sbvmm,cpuname`
（配合 RestrictEvents，用于显示正确的 CPU 名称、屏蔽机型升级提示）、
`bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`（蓝牙状态变量，会被 Delete 清掉后重写）。

### 5.6 DeviceProperties 层（设备属性注入）

| 路径 | 属性 | 状态 |
|---|---|---|
| `PciRoot(0x80)/Pci(0x1f,0x3)` | `layout-id = <0D000000>`、`alc-layout-id = <0D000000>`（都是 Data，= 13） | **生效**：2026-10-14 起扬声器与内置麦克风实测可用 |
| `PciRoot(0x0)/Pci(0x2,0x0)` | （空，无属性） | 占位 |
| `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)` | `acpi-wake-type = 1` | 生效（唤醒类型） |

> 以前这里写的是 `#PciRoot(0x80)/Pci(0x1f,0x3)`（空格 `#`）——OpenCore 把 `#` 开头的键当注释丢弃，
> 所以那条注入等于没写，真正生效的只有 `alcid=11`。2026-10-14 已改成上面的真实注入。

### 5.7 SMBIOS / PlatformInfo（机型伪装）

| 项 | 值 |
|---|---|
| `SystemProductName` | `MacBookPro16,2` |
| `SystemSerialNumber` | `C02D900LML7H` |
| `MLB` | `C020356004NP8PGA8` |
| `SystemUUID` | `36F2E4C0-494C-4B9D-A0A3-AFF2C7134544` |
| `ROM` | `132E6FCCAF08`（按网卡 MAC 生成的 6 字节） |
| `ProcessorType` | 3841，`SpoofVendor = true`，`UpdateSMBIOSMode = Custom` |

> **这三码一 UUID 一 ROM 是这一台机器的身份**。换机器/外传前必须用 GenSMBIOS 重新生成，
> 并把 `ROM` 换成目标机自己的网卡 MAC（第 7 节第 1 条）。

### 5.8 Misc 层

| 区块 | 值 |
|---|---|
| `Security` | `SecureBootModel = Disabled`、`Vault = Optional`、`ScanPolicy = 0`、`DmgLoading = Signed`、`BlacklistAppleUpdate = true`、`ExposeSensitiveData = 7`、`EnablePassword = false` |
| `Boot` | `Timeout = 5`、`ShowPicker = true`、`PickerMode = External`、`PickerAttributes = 17`、`HideAuxiliary = false`、`LauncherOption = Disabled` |
| `Debug` | `AppleDebug = true`、`ApplePanic = true`、`DisableWatchDog = true`、`DisplayLevel = 2147483650`、`LogModules = *`、**`Target = 67`**（2026-10-16 由 `3` 改来：3 + 0x40，多了"写日志文件"，每次启动会在 `EFI\OC\Logs\` 生成 `opencore-*.txt`；不想留日志就改回 3） |

---

## 6. 自查到的问题：怎么继续查

### 6.1 无线网卡（Intel BE200）—— 已修复（2026-10-16）

**现在的状态**：能用。2026-10-15 夜里实测（有日志）：

- `kextstat`：`com.apple.iokit.IOSkywalkFamily 1.0`、`com.apple.iokit.IO80211FamilyLegacy 1200.12.2b1`、
  `com.zxystd.AirportItlwm 2.3.0` 三个都已加载
- `system_profiler SPAirPortDataType`：`en5` = `Card Type: Wi-Fi (0x8086, 0xF4)`、
  `Firmware Version: itlwm: 2.3.0 fw: 90.38c93dbc.0`、`Country Code: CN`、
  信道表完整（2.4G 1–13、5G 36–177）
- `/System/Library/CoreServices/oclp-mod.plist` 里已写入 `Intel无线网卡` 补丁集：
  `wifip2pd`（覆盖）、`IO80211.framework` + `WiFiPeerToPeer.framework`（合并），来源 `13.7.2-24`

**为什么以前不行**：官方 OCLP 对 BE200 支持不完整，而 Sequoia 里已经没有
`IO80211FamilyLegacy.kext`（只剩新的 `IO80211Family` + `IOSkywalkFamily`），
而能带 BE200 的 `AirportItlwm` 是 **Ventura 版**、必须挂在老的 `IO80211FamilyLegacy` 上。

**修好它需要两半，缺一不可**：

1. **EFI 侧（已同步进这两份 EFI）**：
   - `Kernel>Add` 最前面加三条：`IOSkywalkFamily.kext`(1.2.0) / `IO80211FamilyLegacy.kext`(1.0.0) /
     `AirportItlwm.kext`（zxystd itlwm issue #955 的 Ventura/BE200 二进制）
   - `Kernel>Block` 加 `com.apple.iokit.IOSkywalkFamily`（`Exclude`、`MinKernel 23.0.0`、启用）
   - `csr-active-config` 改成 `0xFF0F0000`；`Misc>Debug>Target` 改成 `67`
   - ACPI 里的 `SSDT-Disable_Network_RP08.aml` **必须保持 `Enabled = false`**（它就是用来把
     `\_SB.PC02.RP08` 上的 BE200 藏起来的）
2. **系统侧**：装 **OCLP-Mod 3.1.9**（不是官方 OCLP！）+ `AutoPkg-Assets.pkg`，
   打开后跑 `Post-Install Root Patch`，列表里会出现 **「网络：Intel无线网卡」**，打完重启。
   改 Windows 前的准备和安装步骤见 `Wi-Fi修复-所需文件\读我-先看这个.txt`。

**为什么 OCLP-Mod 认得 BE200**：它的 `pci_data.py` 把 `0x272B` 写进了 Intel 无线支持表
（注释 "Intel Wi-Fi 7(802.11be) AX1775*/AX1790*/BE20*/BE401/BE1750*"），
这条从 **2.4.7（2024-12）** 就存在，所以 3.1.9 天然支持；根补丁资产在安装包里自带，
**全程不需要联网、也不需要 KDK**（`ModernWireless.requires_kernel_debug_kit() = False`）。

**已知限制（上游就是这样）**：只有 11ac（2.4/5GHz），**没有 6GHz**、没有隔空投送/AWDL；
扫描有时不稳，扫不到网络列表时用「其他网络…(Join Other Network)」手填 SSID + 密码。

> ⚠️ 两份变体的一个差异（本次已修）：`不带NVDIA驱动修改项EFI` 里的
> `SSDT-Disable_Network_RP08.aml` 原本是 **`Enabled = true`**（把 BE200 藏起来用的），
> 开着的话 Wi-Fi 永远不可能工作。2026-10-16 已改成 `false`。

**相关文件**：`SSDT-Disable_Network_RP08.aml`（两份变体各自的名字带/不带 `Y9000P_AXI10-` 前缀）
是屏蔽 `\_SB.PC02.RP08`（无线网卡所在根端口）用的，**当前两份都是 `Enabled = false`**。
要用 BE200 就必须保持关闭；只有"这块口上暂时不装任何卡"时才考虑打开，少一次无用枚举。

### 6.2 声卡（已修复：layout 13）

**现状**：内置扬声器出声、内置麦克风可用，走 layout 13（`alcid=13` + `layout-id`/`alc-layout-id`
都注入 13）。下面几条是当时的排查记录，保留备查。

- 声卡从 ioreg 看是"认到了"的：`HDEF@1F,3` → `IOHDACodecDevice@1F,3,0`（registered/matched/active）
  → `AppleHDACodecGeneric` → `AppleHDAStream`；控制器在 ACPI 路径 `\_SB.PC02.HDAS`
  （PCI `pcidebug = 128:31:3`，即 bus 0x80）。
- **codec 型号的依据是 Windows，不是那份 macOS ioreg**（2026-10-14 更正）：Windows 设备库里这块
  codec 枚举为 `INTELAUDIO\FUNC_01&VEN_10EC&DEV_0287&SUBSYS_17AA3906`（"Realtek(R) Audio"），
  `0x10EC0287` → ALC287。macOS 侧那份 ioreg 里的 `HDAConfigDefault` 是 **AppleALC 自带的支持表**
  （663 条，`Codec=`/`CodecID=` 描述的是配置数据的来源机型），**不能用来判断总线上的 codec 是谁**；
  macOS 侧真正读 codec 身份的地方是 codec 节点上的 `IOHDACodecVendorID` / `IOHDACodecRevisionID`。
- **当时**生效的注入只有 `boot-args` 里的 `alcid=11`；`DeviceProperties` 里那条
  `#PciRoot(0x80)/Pci(0x1f,0x3) → layout-id 13` 是注释状态（等于关闭）——这就是"没声音"的原因，
  2026-10-14 改成真实注入 + `alcid=13` 之后，扬声器与内置麦克风同时通了。
- **遗留：外放音量偏小 = 缺功放驱动，不是硬件限制、也不在 EFI 里。** 本机实测（注册表 + DSDT，
  2026-10-14）：左右声道各一颗 Awinic 智能功放，ACPI 节点 `\_SB.PC02.I2C2.SPKR`，
  `_HID = AWDZ8399`（AW88399 系列），`_CRS` 指向 I2C2 上的 `0x35` 与 `0x34`；
  Windows 侧由 `AwinicChip`（`AwinicSmartKAmps.sys`）驱动并加载厂商配置 `AWDZ8399.bin`。
  没有驱动去写它的音量/使能寄存器，功放就停在上电默认状态 → 有声音但很小，Linux 同理
  （主线有 `snd_soc_aw88399`，但需要板级驱动 + ACF 固件才上电）。细节、
  证据摘录与 Linux 侧查证命令见 `E:\macos\AW88399-功放-证据与后续-2026-10-14.md`。
  要在 macOS 上解决，等于自己写一个 I2C 功放驱动。

**当时的排查步骤**（保留备查，每次只改一个值）：

1. 改 `boot-args` 的 `alcid=`。AppleALC 1.9.9 里 ALC287 **只有 3 个 layout：`11` / `13` / `21`**
   （11 通用、13 是 Legion 5 Pro R9000P、21 是 Yoga Slim 7；Hackintool 与 RapidEFI 的数据库也是这三个），
   所以别去试 66/98。每次重启后用 `ioreg -l | grep -i -E 'layout-id|IOHDACodecVendorID'` 看变化。
2. `DeviceProperties` 里那条恢复成真实注入（去掉 `#`）即可 —— **路径 `PciRoot(0x80)/Pci(0x1f,0x3)`
   是对的**（ioreg `pcidebug = 128:31:3`，bus 0x80），值要写成 Data（`<0D000000>`），
   也可以同时给 `alc-layout-id`。
3. 判断方向：如果**外放没声但耳机有声**，那是内置功放（smart amp）那一段，需要专门处理；
   如果**耳机也没声**，先确认 `IOHDACodecVendorID` 读出来确实是 `0x10EC0287`。
4. 三个现成 layout 都不行的话，下一步是提一份 codec dump（Linux 启动盘 `/proc/asound/card0/codec#0`）
   来比对真实 Pin Configuration；细节见 `E:\macos\声卡-layout-id-修改说明-2026-10-14.md`。

---

## 7. 注意事项（换机器、外传前必读）

1. **SMBIOS 三码 / UUID / ROM 是这一台机器的身份**，第二台机器必须重新生成（GenSMBIOS），
   否则两台同码会撞 Apple 服务；`ROM` 也要换成目标机自己的网卡 MAC。
2. **`DSDT.aml` 是本机固件的转储（`LENOVO CB-01`，BIOS 78WW）**，SSDT 里写死了
   `\_SB.PC02.I2C1`（GXTP5100 触摸板）、`\_SB.PC00.LPCB.PS2K`（PNP0303）、`\_SB.GPI0` 这些路径，
   9 条 ACPI Patch 也是按这份 DSDT 的字节特征做的。**同型号同 BIOS 版本**才成立；
   不同 BIOS 版本或不同机型请重新做 ACPI（SSDTTime）与 USB 端口图（USBToolBox）。
3. **USB 端口图 `UTBMap.kext` 是按这块板子的物理口做的**（XHCI 26 口 / XHC2 26 口 / TXHC 3 口），
   换机器要重新映射。
4. **NVIDIA 驱动（NullMoth）不在这个 EFI 里**：它的 kext 装在系统的
   `/Library/Extensions`（`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC`）与 `/Library/GPUBundles`
   （`NVMTLDriver`），还有 `nvfb/nvaccel/...` 这组 boot-args，需要用厂商安装器在目标系统上再装一遍。
   也就是说：**只拷这份 EFI，目标机上不会有独显输出**，还会有第 4 节那段开机耗时。
5. 这份配置里含 `csr-active-config = 0x0A43`（SIP 部分关闭）和 `amfi` 放宽参数，
   属于降低系统安全性，请知悉；`Misc>Debug` 与 `AppleDebugLog` 是排错档，日常可以关掉。
6. 本文里的"未驱动/待确认"结论，都是基于 2026-10-13 那次开机的 `ioreg` 与内核日志；
   硬件或 BIOS 改动后请重新验证。

---

### 8. Wi-Fi 修复用到的文件（`Wi-Fi修复-所需文件\`）

| 文件 | 用途 |
|---|---|
| `OCLP-Mod.pkg` (767 MB) | OCLP-Mod **3.1.9**（laobamac 版），文件大小与 GitHub release 资产一致 |
| `AutoPkg-Assets.pkg` (767 MB) | 同版本离线补丁资产（`payloads.dmg` / `Universal-Binaries.dmg` 就在包里的 app 内） |
| `Ventura.zip` (2.4 MB) | BE200 驱动原件（zxystd issue #955 的 Ventura 包），备份用 |
| `读我-先看这个.txt` | 上机步骤（拷 EFI → 装 OCLP-Mod → 打根补丁 → 测 Wi-Fi） |
| `BE200-诊断.command` | 一键收集 Wi-Fi/kext/根补丁/EFI 日志 |
| `BE200-手动连WiFi.command` | 扫描不工作时手动指定 SSID 连接 |
| `亮度诊断.command` | 内屏亮度链路诊断（本机内屏走 NVIDIA，目前无亮度通道） |
| `USB诊断.command` | USB 端口诊断（左侧口读不出 U 盘那个问题的取证脚本） |

### 8.4 独显（NVIDIA）驱动从哪来

第 1、3 节说的 NullMoth 驱动**不在 EFI 里**：`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC` 装在
`/Library/Extensions`，`NVMTLDriver` 在 `/Library/GPUBundles`，要用厂商安装器在目标系统上
另装一遍。EFI 侧只提供 `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` 这组 boot-args，以及
`Misc>Tools` 里两个 `NullMothSafe.efi` 菜单项（"下次开机卸驱动" / "这次不带驱动启动"）。
