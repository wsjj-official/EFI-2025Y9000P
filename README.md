# Lenovo Y9000P 2025 (U9-275HX) — OpenCore EFI 存档

适用机型：**联想 Y9000P 2025 / Core Ultra 9 275HX / RTX5070Ti** ，BIOS版本 **78WW** **本EFI由DeepSeek -V4修复生成**

系统环境（验证时）：macOS Sequoia **15.7.8 (24G824)**，OpenCore **1.0.8 RELEASE**（官方版，
四个引导文件与官方包逐字节一致）
本目录整理时间：2026-10-14

> 这份 EFI 是**为上述这一台机器**做的：里面带了这台机器的身份信息（SMBIOS 三码）、
> 一份属于这台机器固件的 DSDT、以及按这块板子物理 USB 口做的端口图。
> 拷到别的机器前请先读第 9 节。

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
│       ├─ Kexts\             ← 26 个顶层 kext + 7 个插件包（config 里共 33 条，启用 29 条）
│       └─ Resources\         ← OpenCanopy 主题资源
```

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
| 无线网卡 | **没有驱动**（EFI 里无任何无线 kext，系统里也没有 `IO80211` 实例） |
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

### 3.2 没有驱动 / 有问题

| 设备 | 状态 | 说明 |
|---|---|---|
| **无线网卡** | **完全没驱动**（与你的实测一致） | EFI 里既无 `AirportItlwm` 也无 `itlwm`；系统里 `IO80211` 0 命中。见第 6.1 节 |
| **声卡（内置扬声器/耳机）** | **没声音**（与你的实测一致） | 控制器与 ALC287 codec 都认到了，但 layout-id 不匹配：见第 6.2 节 |
| 核显（`8086:7d67`） | 未驱动 | 没注入 `ig-platform-id`，`IONDRVFramebuffer` 实例 0；内屏走独显 |
| 独显（NVIDIA） | 只有 NullMoth 这套（framebuffer + Metal 翻译层），**不是原生加速** | 开机那 ~98 秒就是它的代价，见第 4 节 |
| 蓝牙 | **待你确认** | 栈起来了（ioreg `IOBluetoothHCIController` 已匹配，日志里 `IOUserBluetoothSerialDriver` dext 加载、bluetoothd 一直在扫 LE），但 `IntelBluetoothFirmware 2.5.0` 这个 personality 在 ioreg 里是 `!registered, !matched` |
| 雷电 / USB4                 | **未测试**                                                   | 未做验证                                                     |
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

**`Kernel>Add`（33 条，启用 29 条；下面列的是可见的 kext 与版本，标 ★ 的是被关掉的 4 条）**

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
-nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 alcid=11
```

| 参数 | 含义 |
|---|---|
| `-v debug=0x100 keepsyms=1` | 详细模式 + 关看门狗 + panic 保留符号（排错用，就是屏幕上那串启动日志） |
| `-vi2c-force-polling` | VoodooI2C 强制轮询（中断不通时的兜底模式） |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | NullMoth NVIDIA 驱动的四项：帧缓冲 / 加速 / 4 个显示头 / 关闭 KMS 平滑 |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | 放宽 AMFI（配合 `AMFIPass.kext`，让第三方/未签名 kext 能加载） |
| `ipc_control_port_options=0` | 解决部分机器的 IPC 端口问题 |
| `alcid=11` | AppleALC 用 layout-id = 11（声卡，见第 6.2 节） |

注意：`NVRAM>Delete` 列表里**包含 `boot-args`**，也就是每次开机都由 config 重写这串参数；
如果你在 macOS 里用 `nvram boot-args=...` 改，重启就没了，要么改 config，要么把它从 `Delete` 里去掉。

**其它 NVRAM 项**：`csr-active-config = 0x0A43`（SIP 放宽：未签名 kext、文件系统、NVRAM、
未批准 kext、未认证 root 五项放开，其余保持开启）、`run-efi-updater = No`、
`revcpu = 1` / `revcpuname = "Intel(R) Core(TM) Ultra 9 275HX"` / `revpatch = sbvmm,cpuname`
（配合 RestrictEvents，用于显示正确的 CPU 名称、屏蔽机型升级提示）、
`bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`（蓝牙状态变量，会被 Delete 清掉后重写）。

### 5.6 DeviceProperties 层（设备属性注入）

| 路径 | 属性 | 状态 |
|---|---|---|
| `#PciRoot(0x80)/Pci(0x1f,0x3)` | `layout-id = 13` | **被 `#` 注释掉 = 不生效**（OpenCore 把 `#` 开头的键当注释丢弃） |
| `PciRoot(0x0)/Pci(0x2,0x0)` | （空，无属性） | 占位 |
| `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)` | `acpi-wake-type = 1` | 生效（唤醒类型） |

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
> 并把 `ROM` 换成目标机自己的网卡 MAC（第 9 节）。

### 5.8 Misc 层

| 区块 | 值 |
|---|---|
| `Security` | `SecureBootModel = Disabled`、`Vault = Optional`、`ScanPolicy = 0`、`DmgLoading = Signed`、`BlacklistAppleUpdate = true`、`ExposeSensitiveData = 7`、`EnablePassword = false` |
| `Boot` | `Timeout = 5`、`ShowPicker = true`、`PickerMode = External`、`PickerAttributes = 17`、`HideAuxiliary = false`、`LauncherOption = Disabled` |
| `Debug` | `AppleDebug = true`、`ApplePanic = true`、`DisableWatchDog = true`、`DisplayLevel = 2147483650`、`LogModules = *`、`Target = 3`（都是排错档，日常可关） |

---

## 6. 自查到的问题：怎么继续查

### 6.1 无线网卡不能工作

**现状**：这份 EFI 里**没有任何无线驱动**（没有 `AirportItlwm`，也没有 `itlwm`），系统 ioreg 里
`IO80211` 0 命中。macOS 对绝大多数 Intel 无线网卡没有原生支持，而较新的 BE200/BE201 目前基本
没有可用的第三方驱动。

**三条路**：

1. **换一张 macOS 原生支持的卡**（最稳）：BCM94360NG / BCM94352Z 等 M.2 卡（注意天线与尺寸，
   以及是否需要 `AirportBrcmFixup`）。
2. **Intel 卡装 `AirportItlwm`**（要与 macOS 版本对号）或 `itlwm` + HeliPort（走以太网模拟）。
   只对部分世代有效；BE200 基本没戏，先查清你的卡具体型号再决定。
3. **不用无线**：有线网卡 `en0`（Intel I226-V）是好的；另外 `HoRNDIS.kext` 已经加载，
   安卓手机 USB 网络共享可以直接用（或 USB 网卡）。

**相关文件**：`SSDT-Y9000P_AXI10-Disable_Network_RP08.aml` 是屏蔽 `\_SB.PC02.RP08`（无线网卡所在
根端口）用的，当前 `Enabled = false`（不加载）。如果确认无线就在 RP08 上且暂时不用，
可以打开它减少一次无用的设备枚举；反过来说，**如果要在 RP08 上换新卡，必须保持关闭**。

### 6.2 声卡不能工作

**现状**：声卡不是"没认到"，而是 layout-id 不匹配。

- ioreg 里控制器 + codec 都挂上了：`HDEF@1F,3` → `IOHDACodecDevice@1F,3,0` → `AppleHDACodecGeneric`
  → `AppleHDAStream`，配置表里对应 `Codec = "Realtek ALC287"`；控制器在 ACPI 路径 `\_SB.PC02.HDAS`。
- 当前生效的注入只有 `boot-args` 里的 `alcid=11`；`DeviceProperties` 里那条
  `#PciRoot(0x80)/Pci(0x1f,0x3) → layout-id 13` 是注释状态（等于关闭）。

**怎么试**（每次只改一个值）：

1. 改 `boot-args` 的 `alcid=`，按 AppleALC 的 ALC287 支持表逐个试常见 layout（`11` / `21` / `66` / `98`），
   每次重启后用 `ioreg -l | grep -i -E 'codec|layout'` 看有没有变。
2. 或者把 `DeviceProperties` 里那条恢复成真实注入（去掉 `#`）。**注意路径别照抄 `PciRoot(0x80)`** ——
   ioreg 里 HDA 挂在 `\_SB.PC02/HDAS@1f0003` 下，路径要按实际总线号写；也可以改用
   `alc-layout-id` 属性。
3. 判断方向：如果**外放没声但耳机有声**，那是内置功放（smart amp）那一段，需要专门处理；
   如果**耳机也没声**，先确认所选 layout 的配置里是否包含 `CodecID = 0x10EC0287`（ALC287）。

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
