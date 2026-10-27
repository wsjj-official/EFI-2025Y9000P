# EFI 细节

本文对应 `Legion-Y9000P-IAX10H-EFI-v1.0`，记录目录、ACPI、Kext、`config.plist` 各段、Quirks 和启动参数。配置以 2026-10-27 在 83F5 实机启动的版本为准。

---

## 1. 版本与文件

| 项目 | 值 |
| --- | --- |
| EFI 版本 | v1.0 |
| 导出日期 | 2026-10-27 |
| OpenCore | 自定义构建，版本字符串为 `REL-XXX-YYYY-MM-DD`（2025-09 构建，非原版 Acidanthera 版本号） |
| `OpenCore.efi` | 612 KB |
| `BOOTx64.efi` | 24 KB |
| `config.plist` | XML，约 44 KB |
| `Resources` | 103 个文件，OpenCanopy 图标/字体/语音 |
| 架构 | x86_64 |
| 目标系统 | macOS 15 Sequoia（实测 15.8 / 24H23） |

> 这个 EFI 的 OpenCore 来自 NullMoth 相关工具链，`OpenCore.efi` 内的版本宏被替换成 `REL-XXX-YYYY-MM-DD`，因此不能用 `strings` 读出官方版本号。升级 OpenCore 时不要直接替换单个 `OpenCore.efi`，要按 OpenCorePkg 的升级流程同时更新 `BOOTx64.efi`、`Drivers` 和 `config.plist` 结构。

---

## 2. 目录结构

```text
EFI/
├── BOOT/
│   └── BOOTx64.efi
└── OC/
    ├── ACPI/
    │   ├── DSDT.aml
    │   ├── SSDT-EC.aml
    │   ├── SSDT-GPI0.aml
    │   ├── SSDT-HPET.aml
    │   ├── SSDT-PLUG-ALT.aml
    │   ├── SSDT-PS2K-HID.aml
    │   ├── SSDT-RTCAWAC.aml
    │   ├── SSDT-SBUS-MCHC.aml
    │   ├── SSDT-USBX.aml
    │   └── SSDT-XOSI.aml
    ├── Drivers/
    │   ├── HfsPlus.efi
    │   ├── OpenCanopy.efi
    │   ├── OpenRuntime.efi
    │   └── ResetNvramEntry.efi
    ├── Kexts/
    │   ├── AirportItlwm-Sequoia-BE200.kext
    │   ├── AMFIPass.kext
    │   ├── AppleALC.kext
    │   ├── AppleIGC.kext
    │   ├── AppleMCEReporterDisabler.kext
    │   ├── AW88399Driver.kext
    │   ├── BlueToolFixup.kext
    │   ├── BrightnessKeys.kext
    │   ├── CpuTopologyRebuild.kext
    │   ├── CpuTscSync.kext
    │   ├── ECM-Override.kext
    │   ├── HoRNDIS.kext
    │   ├── IntelBluetoothFirmware.kext
    │   ├── IntelBTPatcher.kext
    │   ├── Lilu.kext
    │   ├── NVMeFix.kext
    │   ├── RestrictEvents.kext
    │   ├── SMCBatteryManager.kext
    │   ├── SMCProcessor.kext
    │   ├── SMCSuperIO.kext
    │   ├── USBToolBox.kext
    │   ├── UTBMap.kext
    │   ├── VirtualSMC.kext
    │   ├── VoodooI2C.kext
    │   ├── VoodooI2CHID.kext
    │   ├── VoodooPS2Controller.kext
    │   ├── WhateverGreen.kext
    │   └── YogaSMC.kext
    ├── Logs/                    # 空目录，OpenCore 运行时写入
    ├── Resources/
    │   ├── Audio/
    │   ├── Font/
    │   ├── Image/
    │   └── Label/
    ├── Tools/
    │   └── NullMothSafe.efi
    ├── config.plist
    └── OpenCore.efi
```

---

## 3. ACPI

### 3.1 加载的表

`ACPI > Add` 顺序如下，全部启用：

| 顺序 | 文件 | 作用 |
| --- | --- | --- |
| 1 | `DSDT.aml` | 本机整机 DSDT 补丁表（约 671 KB） |
| 2 | `SSDT-HPET.aml` | HPET 中断资源修复 |
| 3 | `SSDT-EC.aml` | 伪造 EC，配合 AppleACPIEC |
| 4 | `SSDT-USBX.aml` | USB 供电属性（USBX） |
| 5 | `SSDT-PLUG-ALT.aml` | CPU 电源管理 / plugin-type |
| 6 | `SSDT-RTCAWAC.aml` | RTC / AWAC 修复 |
| 7 | `SSDT-XOSI.aml` | `_OSI` → `XOSI` 的配套表 |
| 8 | `SSDT-SBUS-MCHC.aml` | SMBus / MCHC 设备 |
| 9 | `SSDT-GPI0.aml` | 触摸板 GPIO 中断 |
| 10 | `SSDT-PS2K-HID.aml` | PS2 键盘 `_HID` 修复的配套表 |

### 3.2 ACPI 删除

| 表 | 动作 | 原因 |
| --- | --- | --- |
| `DMAR` | `All = true` 删除 | Core Ultra 平台保留 VT-d DMAR 时，内核交接阶段可能卡住 |

### 3.3 ACPI 补丁

| 注释 | 查找 → 替换 | 作用 |
| --- | --- | --- |
| GPI0 _STA to XSTA Rename | `_STA` → `XSTA` | 让 SSDT-GPI0 接管触摸板 GPIO |
| Remove conditional ACPI scope declaration | `A0 00 00 00 92 93 50 43 48 41 00` → `A3...` | 去掉条件 ACPI scope，避免设备不枚举 |
| _OSI to XOSI rename - requires SSDT-XOSI.aml | `_OSI` → `XOSI` | 配合 SSDT-XOSI 模拟 Windows |
| HPET _STA to XSTA Rename | `_STA` → `XSTA` | HPET 由 SSDT-HPET 接管 |
| HPET _CRS to XCRS Rename | `_CRS` → `XCRS` | HPET 资源由 SSDT-HPET 提供 |
| IPIC IRQ 2 Patch | `22 04 00 79 00` → `22 00 00 79 00` | 修 IPIC 中断 |
| RTC IRQ 8 Patch | `22 00 01 79 00` → `22 00 00 79 00` | 修 RTC 中断 |
| TIMR IRQ 0 Patch | `22 01 00 79 00` → `22 00 00 79 00` | 修 TIMR 中断 |
| PS2K _HID to XHID Rename (with SSDT-PS2K-HID) | `PS2K ... _HID` → `XHID` | 让 VoodooPS2 接管键盘 |

> `DSDT.aml` 是整机补丁表，同型号 83F5 可复用；升级 BIOS 后建议重新提取并比对，不要盲目覆盖。

---

## 4. Kext

### 4.1 列表与版本

| Kext | Bundle ID | 版本 | 作用 |
| --- | --- | --- | --- |
| Lilu | `as.vit9696.Lilu` | 1.7.3 | 内核补丁加载器 |
| VirtualSMC | `as.vit9696.VirtualSMC` | 1.3.9 | SMC 模拟 |
| SMCBatteryManager | `ru.usrsse2.SMCBatteryManager` | 1.3.9 | 电池 |
| SMCProcessor | `as.vit9696.SMCProcessor` | 1.3.9 | CPU 传感器 |
| SMCSuperIO | `ru.joedm.SMCSuperIO` | 1.3.9 | 风扇/IO 传感器 |
| AppleALC | `as.vit9696.AppleALC` | 1.9.8（共享 DAC 分支） | ALC287 布局 + 共享 DAC02 |
| AW88399Driver | `org.codex.AW88399Driver` | 0.2 | 双 AW88399 功放 |
| VoodooI2C | `com.alexandred.VoodooI2C` | 2.9.1（dual-resource 补丁） | I2C 控制器 / 设备 nub |
| VoodooI2CServices | `com.alexandred.VoodooI2CServices` | 1 | VoodooI2C 服务 |
| VoodooGPIO | `org.coolstar.VoodooGPIO` | 1.1 | GPIO |
| VoodooInput | `me.kishorprins.VoodooInput` | 1.1.7 | 触摸板输入抽象 |
| VoodooI2CHID | `com.alexandred.VoodooI2CHID` | 1 | I2C HID 触摸板 |
| VoodooPS2Controller | `as.acidanthera.voodoo.driver.PS2Controller` | 2.3.8 | PS2 键盘/鼠标 |
| AirportItlwm | `com.zxystd.AirportItlwm` | 2.4.0（Sequoia BE200） | BE200 Wi-Fi |
| IntelBluetoothFirmware | `com.zxystd.IntelBluetoothFirmware` | 2.5.0 | Intel 蓝牙固件 |
| IntelBTPatcher | `com.zxystd.IntelBTPatcher` | 2.5.0 | 蓝牙补丁 |
| BlueToolFixup | `as.acidanthera.BlueToolFixup` | 2.7.3 | 蓝牙协议修复 |
| WhateverGreen | `as.vit9696.WhateverGreen` | 1.7.2 | 显卡补丁/背光 |
| AppleIGC | `com.sxx.AppleIGC` | 1.9d2 | Intel 有线网卡 |
| AppleMCEReporterDisabler | `org.xlnc.disabler.MCEReporter` | 1.2 | 禁用 MCE reporter |
| NVMeFix | `org.acidanthera.NVMeFix` | 1.1.4 | NVMe 电源/兼容 |
| RestrictEvents | `as.vit9696.RestrictEvents` | 1.1.7 | 屏蔽不必要的事件/OTA 限制 |
| BrightnessKeys | `as.acidanthera.BrightnessKeys` | 1.0.4 | 亮度快捷键 |
| CpuTscSync | `org.lvs1974.driver.CpuTscSync` | 1.1.3 | TSC 同步 |
| YogaSMC | `org.zhen.YogaSMC` | 1.5.3 | Legion 电源/风扇/功能键 |
| USBToolBox | `com.dhinakg.USBToolBox.kext` | 1.2.0 | USB 映射工具 |
| UTBMap | `com.dhinakg.USBToolBox.map` | 1.1 | 本机 USB 端口映射 |
| AMFIPass | `com.dhinakg.AMFIPass` | 1.4.1 | AMFI 放行 |
| HoRNDIS | `com.joshuawise.kexts.HoRNDIS` | 9.2 | USB 网络共享 |
| ECM-Override | `com.dortania.ECM-Override` | 9.9.9 | USB CDC ECM |
| CpuTopologyRebuild | `org.b00t0x.CpuTopologyRebuild` | 2.0.2 | 大小核拓扑（默认禁用） |

### 4.2 `Kernel > Add` 顺序

顺序与 `config.plist` 一致；依赖在前：

```text
 1 Lilu
 2 AMFIPass
 3 VirtualSMC
 4 AppleALC
 5 AppleIGC
 6 AppleMCEReporterDisabler
 7 BlueToolFixup
 8 BrightnessKeys
 9 CpuTopologyRebuild            (Enabled = false)
10 IntelBTPatcher
11 IntelBluetoothFirmware
12 NVMeFix
13 RestrictEvents
14 CpuTscSync
15 SMCBatteryManager
16 SMCProcessor
17 SMCSuperIO
18 USBToolBox
19 UTBMap
20 VoodooI2CServices
21 VoodooGPIO
22 AirportItlwm-Sequoia-BE200
23 VoodooI2C
24 VoodooInput
25 VoodooI2CHID
26 VoodooPS2Controller
27 VoodooPS2 VoodooInput         (Enabled = false)
28 VoodooPS2Keyboard
29 VoodooPS2Mouse                (Enabled = false)
30 VoodooPS2Trackpad             (Enabled = false)
31 WhateverGreen
32 YogaSMC
33 HoRNDIS
34 ECM-Override
35 AW88399Driver
```

说明：

- `AW88399Driver` 放在最后，但依赖的 `VoodooI2CServices` / `VoodooGPIO` / `VoodooI2C` 都在前面；OpenCore 在启动匹配阶段统一解析，位置不影响匹配。
- `CpuTopologyRebuild` 默认禁用；如果需要在 24 核 CPU 上调整大小核拓扑，可自行启用并测试。
- 只保留一个 `VoodooInput`：`VoodooPS2Controller` 内的那份禁用，使用 `VoodooI2C` 插件里的 1.1.7。
- `MinKernel` / `MaxKernel` 只对以下项设了限制：
  - `AMFIPass`：`MinKernel 20.0.0`
  - `BlueToolFixup`：`MinKernel 21.0.0`
  - `NVMeFix`：`MinKernel 18.0.0`
  - `AirportItlwm`：`MinKernel 24.2.0`，`MaxKernel 24.99.99`，`Arch x86_64`
  - `HoRNDIS`：`MinKernel 20.0.0`
  - `ECM-Override`：`MinKernel 23.0.0`，`Arch x86_64`
  - `AW88399Driver`：`MinKernel 24.0.0`，`MaxKernel 24.99.99`

### 4.3 `Kernel > Block`

| Identifier | Strategy | 原因 |
| --- | --- | --- |
| `com.apple.driver.AppleEthernetRL` | Exclude | 避免与 AppleIGC/板载网卡驱动冲突 |

### 4.4 `Kernel > Emulate`

| 键 | 值 | 说明 |
| --- | --- | --- |
| `Cpuid1Data` | `55 06 0A 00 ...`（CPUID `0x000A0655`） | Arrow Lake CPUID 伪装，配合 `ProvideCurrentCpuInfo` |
| `Cpuid1Mask` | `FF FF FF FF 00...` | 只覆盖前 4 字节 |
| `DummyPowerManagement` | `false` | 使用 XCPM |
| `MinKernel` / `MaxKernel` | 空 | 全版本 |

---

## 5. `config.plist` 各段

### 5.1 `ACPI`

见第 3 节。`Add` 10 张表，`Delete` 1 条（DMAR），`Patch` 9 条。

### 5.2 `Booter`

`MmioWhitelist` 1 条：

| Address | Comment | Enabled |
| --- | --- | --- |
| `0xFF000000` | Preserve runtime MMIO 0xFF000000 | true |

启用的 Quirks：

| Quirk | 值 | 说明 |
| --- | --- | --- |
| `AllowRelocationBlock` | true | 允许重定位 block |
| `AvoidRuntimeDefrag` | true | 避免 runtime defrag |
| `DevirtualiseMmio` | true | MMIO 虚拟化处理 |
| `EnableSafeModeSlide` | true | 安全模式 slide |
| `FixupAppleEfiImages` | true | 修复 Apple EFI 镜像 |
| `ProtectUefiServices` | true | 保护 UEFI 服务 |
| `ProvideCustomSlide` | true | 自定义 slide |
| `RebuildAppleMemoryMap` | true | 重建内存映射 |
| `SetupVirtualMap` | true | 建立虚拟映射 |
| `SyncRuntimePermissions` | true | 同步 runtime 权限 |
| `ResizeAppleGpuBars` | 0 | 关闭 Apple GPU BAR 调整 |

其余多为默认关闭，例如 `DisableVariableWrite`、`DiscardHibernateMap`、`EnableWriteUnprotector`、`ProtectMemoryRegions`、`ProtectSecureBoot`、`SignalAppleOS`。

### 5.3 `DeviceProperties`

| 路径 | 属性 | 值 | 作用 |
| --- | --- | --- | --- |
| `PciRoot(0x0)/Pci(0x2,0x0)` | `disable-gpu` | `true` | 禁用 Arrow Lake 核显（macOS 无驱动） |
| `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)` | `acpi-wake-type` | `1` | 独显唤醒类型 |
| `PciRoot(0x2)/Pci(0x1f,0x3)` | `layout-id` | `0D 00 00 00` | AppleALC layout 13 |
| `PciRoot(0x2)/Pci(0x1f,0x3)` | `alc-layout-id` | `0D 00 00 00` | 共享 DAC 守卫读取的 layout 13 |
| `PciRoot(0x80)/Pci(0x1f,0x3)` | `layout-id` | `0D 00 00 00` | 兼容旧路径的同值 |
| `PciRoot(0x80)/Pci(0x1f,0x3)` | `alc-layout-id` | `0D 00 00 00` | 兼容旧路径的同值 |

> 两个 HDEF 路径是刻意保留的：本机 ACPI 的 HDEF 在 `_SB.PC02` 下，正确路径是 `PciRoot(0x2)`；旧配置使用 `PciRoot(0x80)` 也能生效。两条都写 4 字节 `0D 00 00 00`，避免不同 OpenCore 解析差异导致 layout 丢失。

### 5.4 `Kernel`

- `Add`：35 项，见 4.2
- `Block`：1 项，见 4.3
- `Emulate`：见 4.4
- `Patch`：0
- `Force`：0
- `Quirks`：

| Quirk | 值 | 说明 |
| --- | --- | --- |
| `AppleXcpmCfgLock` | true | 绕过 CFG Lock |
| `AppleXcpmForceBoost` | true | 强制 XCPM 睿频 |
| `CustomSMBIOSGuid` | true | 配合 `UpdateSMBIOSMode=Custom` |
| `DisableIoMapper` | true | 关闭 IOMMU 映射 |
| `DisableLinkeditJettison` | true | 保留 linkedit，Lilu 需要 |
| `PanicNoKextDump` | true | panic 时不 dump kext |
| `PowerTimeoutKernelPanic` | true | 电源超时不 panic |
| `ProvideCurrentCpuInfo` | true | 提供当前 CPU 信息 |
| `XhciPortLimit` | true | 解除 15 端口限制 |
| `SetApfsTrimTimeout` | -1 | 默认 TRIM 行为 |

### 5.5 `Misc`

#### Boot

| 键 | 值 |
| --- | --- |
| `PickerMode` | `External`（OpenCanopy） |
| `PickerAttributes` | `17`（0x11） |
| `PickerVariant` | `Auto` |
| `ShowPicker` | true |
| `Timeout` | 5 |
| `HideAuxiliary` | false |
| `LauncherOption` | `Disabled` |
| `PollAppleHotKeys` | false |
| `TakeoffDelay` | 0 |
| `HibernateMode` | `None` |
| `HibernateSkipsPicker` | false |

#### Security

| 键 | 值 |
| --- | --- |
| `ScanPolicy` | 0（允许所有文件系统/设备） |
| `SecureBootModel` | `Disabled` |
| `Vault` | `Optional` |
| `DmgLoading` | `Signed` |
| `BlacklistAppleUpdate` | true |
| `AllowSetDefault` | true |
| `ExposeSensitiveData` | 7 |
| `ApECID` | 0 |
| `EnablePassword` | false |

#### Debug

| 键 | 值 |
| --- | --- |
| `Target` | 3（控制台 + 文件日志） |
| `AppleDebug` | true |
| `ApplePanic` | true |
| `DisableWatchDog` | true |
| `DisplayDelay` | 0 |
| `DisplayLevel` | `0x80000002` |
| `LogModules` | `*` |
| `SysReport` | false |

#### Tools

| 名称 | Path | Arguments | 作用 |
| --- | --- | --- | --- |
| `1401: Remove NVIDIA driver` | `NullMothSafe.efi` | 空 | 下次启动移除 NVIDIA 驱动 |
| `1401: Start once without NVIDIA driver` | `NullMothSafe.efi` | `once` | 本次启动不加载 NVIDIA 驱动 |

### 5.6 `NVRAM`

`Add` 中的主要变量：

| GUID | 键 | 值 |
| --- | --- | --- |
| `7C436110-AB2A-4BBB-A880-FE41995C9F82` | `boot-args` | 见第 7 节 |
| 同上 | `csr-active-config` | `43 0A 00 00`（0x0A43） |
| 同上 | `SystemAudioVolume` | `46` |
| 同上 | `prev-lang:kbd` | 空 |
| 同上 | `run-efi-updater` | `No` |
| 同上 | `bluetoothExternalDongleFailed` | `00` |
| 同上 | `bluetoothInternalControllerInfo` | 全零 |
| `4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102` | `revcpu` | `1` |
| 同上 | `revcpuname` | `Intel(R) Core(TM) Ultra 9 275HX` |
| 同上 | `revpatch` | `sbvmm,cpuname` |
| 同上 | `rtc-blacklist` | 空 |
| `4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14` | `DefaultBackgroundColor` | `00 00 00 00` |

`csr-active-config = 0x0A43` 表示部分关闭 SIP，允许未签名 kext / 文件系统访问；这是 NullMoth 和注入 kext 所需。不要随意改成 `0x00`。

### 5.7 `PlatformInfo`

| 键 | 值 |
| --- | --- |
| `Automatic` | true |
| `UpdateSMBIOS` | true |
| `UpdateSMBIOSMode` | `Custom` |
| `UpdateNVRAM` | true |
| `UpdateDataHub` | true |
| `UseRawUuidEncoding` | false |
| `SystemProductName` | `MacBookPro16,2` |
| `ProcessorType` | `3841`（0xF01） |
| `SpoofVendor` | true |
| `AdviseFeatures` | false |
| `MaxBIOSVersion` | false |
| `SystemMemoryStatus` | `Auto` |
| `SystemSerialNumber` | **已清空，需自行生成** |
| `MLB` | **已清空，需自行生成** |
| `SystemUUID` | **已清空，需自行生成** |
| `ROM` | **6 字节零，需替换为网卡 MAC** |

### 5.8 `UEFI`

#### Drivers

| 文件 | Enabled | LoadEarly |
| --- | --- | --- |
| `HfsPlus.efi` | true | false |
| `OpenRuntime.efi` | true | false |
| `ResetNvramEntry.efi` | true | false |
| `OpenCanopy.efi` | true | false |

#### APFS

| 键 | 值 |
| --- | --- |
| `EnableJumpstart` | true |
| `GlobalConnect` | false |
| `HideVerbose` | true |
| `JumpstartHotPlug` | false |
| `MinDate` | -1 |
| `MinVersion` | -1 |

#### Audio

| 键 | 值 |
| --- | --- |
| `AudioSupport` | false |
| `AudioDevice` | `PciRoot(0x0)/Pci(0x1b,0x0)` |
| `AudioOutMask` | 1 |
| `AudioCodec` | 0 |
| `PlayChime` | `Auto` |
| `DisconnectHda` | false |
| `MaximumGain` | -15 |
| `MinimumAssistGain` | -30 |
| `MinimumAudibleGain` | -55 |

> OpenCore 启动提示音是关闭的；系统内的声音由 AppleHDA + AppleALC + AW88399 负责。

#### Output / Input

| 段 | 键 | 值 |
| --- | --- | --- |
| Output | `Resolution` | `Max` |
| Output | `TextRenderer` | `BuiltinGraphics` |
| Output | `ProvideConsoleGop` | true |
| Output | `DirectGopRendering` | false |
| Output | `UIScale` | 0（自动） |
| Input | `KeySupport` | true |
| Input | `KeySupportMode` | `Auto` |
| Input | `TimerResolution` | 50000 |
| Input | `KeyForgetThreshold` | 5 |

#### ProtocolOverrides

| 键 | 值 |
| --- | --- |
| `AppleDebugLog` | true |
| `FirmwareVolume` | true |
| 其余 | false |

#### Quirks

| Quirk | 值 |
| --- | --- |
| `ReleaseUsbOwnership` | true |
| `RequestBootVarRouting` | true |
| `ResizeGpuBars` | -1 |
| `TscSyncTimeout` | 0 |
| `ExitBootServicesDelay` | 0 |
| `EnableVmx` | false |
| `DisableSecurityPolicy` | false |
| `IgnoreInvalidFlexRatio` | false |
| 其余 | false |

---

## 6. 启动参数逐项

```text
-v keepsyms=1 -vi2c-force-polling nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
alcid=13 alcverbs=1 nvrmacpibl=1
```

| 参数 | 作用 | 能否去掉 |
| --- | --- | --- |
| `-v` | verbose 启动 | 可以，稳定后去掉 |
| `keepsyms=1` | panic 保留符号 | 建议保留 |
| `-vi2c-force-polling` | VoodooI2C 强制轮询 | 触摸板/SPKR 正常后可试去掉，不建议 |
| `nvfb=1` | NullMoth NVIDIA framebuffer | 不装 NVIDIA 驱动时无影响 |
| `nvaccel=1` | NullMoth 加速 | 同上 |
| `nvfbheads=4` | NVIDIA 显示头数量 | 同上 |
| `-nvkmsnosmooth` | NullMoth 关闭 KMS 平滑 | 同上 |
| `nvrmacpibl=1` | 让 NVKMS 自己注册内屏背光（亮度滑块 + 亮度键恢复） | 只有装了 NullMoth 驱动才生效；**若加完卡在 GPU 启动阶段**，删掉它 |
| `amfi_get_out_of_my_way=0x1` | AMFI 放行 | 注入未签名 kext 需要 |
| `amfi=0x80` | AMFI 兼容位 | 同上 |
| `ipc_control_port_options=0` | IPC 端口选项 | 建议保留 |
| `alcid=13` | AppleALC layout 13 | **声卡需要** |
| `alcverbs=1` | 共享 DAC verb hook | **声卡需要，不能去掉** |

---

## 7. 与声卡相关的关键值汇总

| 项 | 值 |
| --- | --- |
| Codec | Realtek ALC287，`10ec:0287` |
| PCI SSID | `17aa:3d6c` |
| Codec SSID（Linux 资料） | `17aa:3906` |
| HDA controller | Intel `8086:7f50` |
| HDEF 路径 | `PciRoot(0x2)/Pci(0x1f,0x3)`（兼容 `0x80`） |
| layout | `13`（`alcid=13`） |
| `layout-id` / `alc-layout-id` | `0D 00 00 00` |
| AppleALC | 1.9.8 共享 DAC 分支，需 `alcverbs=1` |
| 主低音 pin | `0x17`（23） |
| 高音 pin | `0x14`（20） |
| 共享 DAC | `0x02` |
| 功放 | 2 × AW88399，I2C `0x34` / `0x35` |
| AW ACPI | `\_SB.PC02.I2C2.SPKR`，HID `AWDZ8399` |
| AW 固件 | 152416 字节，SHA-256 `1e927c9bca76d868181c0f81df2bccef3cf19c7d0910219f229360c87babd42c`，内置于 kext |
| AW 通道映射 | `0x34 → channel 1`，`0x35 → channel 0` |

---

## 8. 文件校验

发布包根目录提供 `SHA256SUMS.txt`。校验方式：

```sh
shasum -a 256 -c SHA256SUMS.txt
```

> `SHA256SUMS.txt` 本身不包含自己的哈希；下载压缩包后请另外核对发布页给出的 zip SHA-256。
