# Lenovo Legion Y9000P IAX10H（83F5）— OpenCore EFI

面向 **Lenovo Legion Y9000P IAX10H / 板号 83F5 / Intel Core Ultra 9 275HX / RTX 5070 Ti Laptop** 的 macOS OpenCore EFI。

**v1.0（2026-10-27）这一版做成了三件事：**

1. **Wi-Fi 打通** —— Intel BE200（`8086:272b`），用 `AirportItlwm-Sequoia-BE200 2.4.0` 直接注入；
2. **外放修好** —— Realtek ALC287 + 两颗 Awinic AW88399 智能功放（高音 + 低音同时工作，音量/静音正常）；
3. **彻底移除对 OCLP 的依赖** —— 不再需要 OCLP / OCLP-Mod，不再需要 `Post-Install Root Patch`，也不再需要 `IOSkywalkFamily` + `IO80211FamilyLegacy` 那一套回移植补丁。

> 发布包已经清空原机 SMBIOS：`SystemSerialNumber` / `MLB` / `SystemUUID` 为空、`ROM` 为 6 字节零。
> **使用前必须用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成自己的三码**，否则 iCloud、iMessage、App Store 会不可用（不影响开机与声卡）。

---

## 0. 和旧版（仓库此前三份 EFI）的区别

仓库此前是三个变体目录：`带NVIDIA驱动修改项EFI`、`不带NVDIA驱动修改项EFI`、`EFI-1401移除OCLP支持带NV驱动修改项`。
v1.0 起合并为**单一 EFI**，`EFI/` 直接放到 ESP 根目录即可。

| 项目 | 旧版（2026-10-14 / 10-16） | 本版 v1.0（2026-10-27） |
| --- | --- | --- |
| Wi-Fi（BE200） | `AirportItlwm 2.3.0`（Ventura 二进制）+ `IOSkywalkFamily` + `IO80211FamilyLegacy`，屏蔽系统 `IOSkywalkFamily`，**系统侧还要装 OCLP-Mod 3.1.9 打根补丁** | `AirportItlwm-Sequoia-BE200 2.4.0` 原生注入，**不需要 OCLP、不需要根补丁、不需要 IOSkywalk 那一套** |
| 声卡外放 | `AppleALC` layout 13，能出声但**音量很小**（缺功放驱动） | 增加 `AW88399Driver.kext 0.2`（两颗功放 `0x34`/`0x35` + ACF 固件）+ `AppleALC 1.9.8` 共享 DAC 分支 + `VoodooI2C` dual-resource 补丁，**高音/低音都正常** |
| SIP | `0xFF0F0000` | `0x0A43`（只为放行第三方 kext，保持最小放宽） |
| `Kernel>Block` | 还要屏蔽 `IOSkywalkFamily` | 只剩 `AppleEthernetRL` 一条（让 AppleIGC 接管 I225/I226） |
| 仓库结构 | 三份变体 + `Wi-Fi修复-所需文件/`（含 767 MB 的 OCLP-Mod 安装包） | 单一 EFI + 文档 + 检查脚本，OCLP 相关文件全部移除 |
| SMBIOS | 含原机三码 | 清空占位，需自行生成 |

---

## 1. 验证环境

| 项目 | 值 |
| --- | --- |
| 机型 | Lenovo Legion Y9000P IAX10H（同平台 Legion Pro 7i 16IAX10H 可参考） |
| 板号 / DMI | 83F5（ACPI OEM `LENOVO`，OEM Table ID `CB-01`） |
| CPU | Intel Core Ultra 9 275HX（24 核） |
| 内存 | 64 GB |
| 独显 | NVIDIA GeForce RTX 5070 Ti Laptop（PCI `10de:2f58`） |
| 核显 | Intel Arrow Lake iGPU（`8086:7d67`，macOS 下禁用） |
| 无线 | Intel BE200（`8086:272b`） |
| 有线 | Intel I226-V（`8086:125c`） |
| 声卡 | Realtek ALC287（`10ec:0287`，PCI SSID `17aa:3d6c`，codec SSID `17aa:3906`），HDA 控制器在 PCI `80:1f.3` |
| 功放 | 2 × Awinic AW88399（I2C `0x34` / `0x35`，ACPI HID `AWDZ8399`，节点 `\_SB.PC02.I2C2.SPKR`） |
| 屏幕 | 2560 × 1600（内屏由独显输出） |
| 触摸板 | Goodix GXTP5100（I2C，`\_SB.PC02.I2C1`） |
| 系统（验证时） | macOS Sequoia **15.8（24H23，Darwin 24.6.0）** |
| OpenCore | 自定义构建（版本字符串 `REL-XXX-YYYY-MM-DD`） |
| Lilu | 1.7.3 |

---

## 2. 功能状态

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| OpenCore 启动 / macOS 15.8 | ✅ 已验证 | 本 EFI 即实机导出配置 |
| 内置扬声器（高音 + 低音） | ✅ 已验证 | 两颗 AW88399 均 `AW88399Ready = Yes`，播放时 `AmplifierRunning = Yes` |
| 系统音量 / 静音 | ✅ 正常 | AppleALC 共享 DAC 分支镜像 pin17 / pin14 |
| Wi-Fi（BE200） | ✅ 已验证 | `AirportItlwm-Sequoia-BE200 2.4.0 _FIX3_20261027`，**无需 OCLP 根补丁**；HE/Wi-Fi 6 由 `itlwm_he=1` 开启，6 GHz 被动扫描已上报 |
| 蓝牙 | ✅ 驱动已加载 | IntelBluetoothFirmware 2.5.0 + IntelBTPatcher 2.5.0 + BlueToolFixup 2.7.3 |
| 触摸板 / 键盘 | ✅ 已验证 | VoodooI2C 2.9.1 + VoodooI2CHID + GPI0 / VoodooPS2Controller 2.3.8 |
| 电池 / 传感器 | ✅ 驱动已加载 | VirtualSMC 1.3.9 + SMCBatteryManager / SMCProcessor / SMCSuperIO |
| 有线网卡（I226-V） | ✅ 已验证 | AppleIGC 1.9d2，`en0` built-in |
| USB | ✅ 已验证 | USBToolBox 1.2.0 + UTBMap 1.1，`XhciPortLimit = true` |
| NVMe | ✅ 已验证 | NVMeFix 1.1.4，`SetApfsTrimTimeout = -1` |
| 内置麦克风 | ✅ 设备存在 | 本版未单独做录音回放测试 |
| 摄像头 | ⚠️ 未验证 | 取决于 USB 映射 |
| 3.5 mm 耳机口 | ⚠️ 未验证 | 本版未做插孔切换测试 |
| HDMI / DP 音频 | ⚠️ 未验证 | 不属于本版声卡修复范围 |
| 睡眠 / 唤醒 | ⚠️ 未验证 | 未做长时间睡眠测试 |
| 内屏亮度调节 | ✅ 已恢复（需 NVIDIA 驱动） | 固件 DSDT 里只有空的 `_BCM` 桩，常规 SSDT-PNLF 不适用；加 **`nvrmacpibl=1`** 后由 NullMoth 的 NVKMS 自己注册内屏背光，滑块与亮度键都可用。**必须装了 NullMoth 驱动才生效**，没装驱动时滑块仍然是灰的 |
| NVIDIA 独显 | ⚠️ 不在本 EFI | 需单独安装 NullMoth 2.6.2，见第 10 节 |
| iServices | ⚠️ 需自行生成三码 | 发布包已清空 SMBIOS |

---

## 3. 本版修了什么

### 3.1 Wi-Fi（Intel BE200）：原生驱动，彻底去掉 OCLP

**以前为什么必须 OCLP**：Sequoia 里已经没有 `IO80211FamilyLegacy.kext`（只剩新的 `IO80211Family` + `IOSkywalkFamily`），而当时能给 BE200 用的 `AirportItlwm` 是 Ventura 时代的二进制，必须挂在老的 `IO80211FamilyLegacy` 上。旧方案因此需要：

- `Kernel>Add` 加 `IOSkywalkFamily` / `IO80211FamilyLegacy` / `AirportItlwm`（Ventura 版）；
- `Kernel>Block` 屏蔽系统自带 `IOSkywalkFamily`；
- `csr-active-config = 0xFF0F0000`；
- **系统侧再装 OCLP-Mod 3.1.9 打 `Post-Install Root Patch`**（替换 `wifip2pd`、合并 `IO80211.framework`）。

**现在的做法**：`AirportItlwm-Sequoia-BE200.kext` **2.4.0**（`com.zxystd.AirportItlwm`，`IOPCIMatch` 含 `0x272B8086`）直接注入，其余一概不需要：

| 项目 | 旧版 | 本版 |
| --- | --- | --- |
| `IOSkywalkFamily` / `IO80211FamilyLegacy` | 需要 | **不需要** |
| `Kernel>Block: IOSkywalkFamily` | 需要 | **没有** |
| OCLP-Mod / 根补丁 | 需要 | **不需要** |
| `csr-active-config` | `0xFF0F0000` | `0x0A43` |

验证：

```sh
kextstat | grep -i airportitlwm            # com.zxystd.AirportItlwm 2.4.0
system_profiler SPAirPortDataType | head -30
wdutil info                                 # SSID / BSSID / RSSI / 信道
```

**本版驱动（2026-10-27 更新）**：`AirportItlwm-Sequoia-BE200.kext` 换成 **2.4.0 `_FIX3_20261027`** 构建，针对 Wi-Fi 6 连接不稳的两处根因：

- 修复**四次握手末包的发送与装钥时序**（之前表现为连上后掉线、认证反复、DHCP 拿不到地址）；
- 修复**离网时旧状态请求仍在执行**（切网/断网后残留状态导致下一次关联异常）；
- 保留 **6 GHz 被动扫描与结果上报**（`AirportItlwm-WCLScan6GHzMap` / `WCLChannels6GHz`）。

**开启 HE / Wi-Fi 6 / 6 GHz**：需要 boot-args 增加 `itlwm_he=1`（驱动只认 `itlwm_he`、`itlwm_cc`、`itlwm_tsleep` 三个参数；`itlwm_he=1` 打开 802.11ax 能力，6 GHz 的 HE 能力集也挂在这条路径上）。本版已加进 `config.plist`。

已知限制（上游就是这样）：**6 GHz 目前只做到被动扫描与上报，实际 6 GHz 关联未验证**；纯 **WPA3-SAE 未实现**（WPA2-Personal/Enterprise 可连）；**Wi-Fi 7 未测试**；没有隔空投送/AWDL；扫描偶尔不稳，扫不到列表时用「加入其他网络…」手填 SSID + 密码。

### 3.2 声卡（ALC287 + 双 AW88399）

把 Linux 下同机型的 AW88399 修复流程搬到 macOS：

| 组件 | 版本 | 作用 |
| --- | --- | --- |
| `AW88399Driver.kext` | 0.2 | 通过 VoodooI2C 访问 `0x34` / `0x35` 两颗 AW88399，加载 `aw88399_acf.bin` 固件，按播放状态启停功放 |
| `VoodooI2C.kext` | 2.9.1（dual-resource 补丁） | SPKR 的两个 I2C 资源分别发布 nub；保留 `7F4C–7F4F` 控制器匹配 |
| `AppleALC.kext` | 1.9.8（共享 DAC 分支） | pin17（低音）与 pin14（高音）共用 DAC02，镜像音量/静音，避免 4 声道错配 |
| `config.plist` | — | `layout-id = 13`、`alc-layout-id = 13`、`alcid=13`、`alcverbs=1` |

**修掉的一个关键配置错误**：旧配置把 HDEF 的 `layout-id` 写成了 ASCII 字符串 `"0d000000"`（8 字节），而不是 4 字节小端 `0D 00 00 00`。这会让 AppleALC 的 layout 13 守卫失效、共享 DAC 补丁不生效。本版已改正，并同时保留 `PciRoot(0x2)` 与 `PciRoot(0x80)` 两条路径（本机 HDA 在 bus `0x80`，两条都注入避免解析差异）。

进系统后一键检查：

```sh
bash tools/check-audio.sh
```

期望看到：两个 `SPKR` nub（`i2cAddress = 52 (0x34)` / `53 (0x35)`）、`AW88399Ready = Yes`、`AW88399LastError = 0`、播放时 `AW88399AmplifierRunning = Yes`、`ALC287SharedDACPrimaryPin = 23`、`SecondaryPin = 20`、`LastError = 0`。
原理与排错见 [docs/AUDIO-AW88399.md](docs/AUDIO-AW88399.md)。

### 3.3 彻底移除 OCLP 依赖

- 本包**不含**任何 OCLP / OCLP-Mod 组件，也不需要 `Post-Install Root Patch`；
- `Kernel>Block` 里不再有 `IOSkywalkFamily`，`Kernel>Add` 里不再有 `IOSkywalkFamily` / `IO80211FamilyLegacy`；
- Wi-Fi 与蓝牙全部由 kext 完成，`csr-active-config = 0x0A43` 即可（旧方案要求 `0xFF0F0000`）；
- 旧仓库里的 `Wi-Fi修复-所需文件/`（含 767 MB 的 OCLP-Mod 安装包、`Ventura.zip` 等）已整体删除。

> OCLP 仍然只在一种场景下有用：给**非原生支持的显卡**做系统级补丁（例如本机的 NVIDIA 走的是 NullMoth 那一套，也不是 OCLP）。本 EFI 的 Wi-Fi / 声卡 / 蓝牙均与 OCLP 无关。

---

## 4. 目录结构

```text
├── EFI/                          ← 直接复制到 ESP 根目录（保留 Windows 的 EFI/Microsoft）
│   ├── BOOT/BOOTx64.efi
│   └── OC/
│       ├── ACPI/                 ← DSDT + 9 个 SSDT
│       ├── Drivers/              ← HfsPlus / OpenRuntime / ResetNvramEntry / OpenCanopy
│       ├── Kexts/               ← 28 个 kext bundle（Kernel>Add 35 项，4 项默认禁用）
│       ├── Resources/            ← OpenCanopy 图标/字体/语音
│       ├── Tools/                ← NullMothSafe.efi
│       ├── Logs/                 ← OpenCore 启动日志落盘目录
│       ├── config.plist          ← 当前配置（三码已清空，需自行填写）
│       └── OpenCore.efi
├── docs/
│   ├── AUDIO-AW88399.md          ← 声卡拓扑、Linux 对照、验证与排错
│   ├── CHANGELOG.md              ← 变更记录
│   ├── EFI-DETAILS.md            ← ACPI / Kext / config 各段 / Quirks
│   ├── INSTALL.md                ← BIOS、三码、复制 EFI、首次启动
│   └── TROUBLESHOOTING.md        ← 启动 / 声卡 / Wi-Fi / 触摸板 / NVIDIA
├── tools/
│   └── check-audio.sh            ← 一键检查声卡链路
├── README.md                     ← 本文件
├── SHA256SUMS.txt                ← 全包校验和
└── THIRD-PARTY.md                ← 第三方组件与许可
```

---

## 5. 快速安装

> 详细步骤见 [docs/INSTALL.md](docs/INSTALL.md)。

1. **备份**你现在能启动的 EFI 到另一块盘或 U 盘。
2. 把本包的 `EFI/` 复制到 FAT32 的 EFI 分区根目录（**保留** `EFI/Microsoft`，否则 Windows 引导会丢）。
3. 用 GenSMBIOS 生成 **`MacBookPro16,2`** 的三码：`SystemSerialNumber`、`MLB`、`SystemUUID`；
   `ROM` 填有线/无线网卡的 MAC（去掉分隔符，6 字节）。
4. 用 ProperTree / Xcode 填进 `config.plist` 的 `PlatformInfo > Generic`。
5. BIOS 按第 6 节设置。
6. 进 OpenCore 先执行一次 **`Reset NVRAM`**，再选 macOS。
7. 进系统后跑 `bash tools/check-audio.sh` 确认声卡链路。

---

## 6. BIOS 设置

| 项目 | 值 | 原因 |
| --- | --- | --- |
| **Secure Boot** | **关闭** | 配置里 `SecureBootModel = Disabled`、`Vault = Optional`，开着会拦引导链 |
| **VT-d** | **关闭** | `ACPI>Delete` 丢弃 `DMAR`（Core Ultra 在它存在时内核交接处会卡），且 `DisableIoMapper = true` |
| CPU 虚拟化（VT-x） | 可开启 | 与上面两项无关 |
| 启动模式 | UEFI（不要 Legacy/CSM） | OpenCore 只走 UEFI |
| 硬盘模式 | AHCI / 纯 NVMe（不要 Intel RST/RAID） | macOS 不认 RST |
| Above 4G Decoding / Resizable BAR | **保持默认** | 配置里 `ResizeAppleGpuBars = -1`、`ResizeGpuBars = -1`（交还固件原值）；固定 8 GB 重设会让固件在进选择界面前挂住 |
| 显卡模式（MUX / Hybrid / Discrete） | 按需 | 内屏交给独显 = 有画面但开机多 ~98 秒（第 8 节）；混合/集显模式内屏无输出 |

BIOS 版本 **78WW** 为本机实测可用版本；换 BIOS 版本请重新核对 ACPI（原因见第 11 节）。

---

## 7. 启动参数

```text
-v keepsyms=1 -vi2c-force-polling nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 alcid=13 alcverbs=1 nvrmacpibl=1 itlwm_he=1
```

| 参数 | 作用 |
| --- | --- |
| `-v` | 详细日志；稳定后可以去掉 |
| `keepsyms=1` | panic 时保留符号 |
| `-vi2c-force-polling` | VoodooI2C 强制轮询，触摸板 / SPKR 枚举更稳 |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | NullMoth NVIDIA 帧缓冲/加速相关；未装驱动时无影响 |
| `nvrmacpibl=1` | 让 NVKMS 自己注册内屏背光，**亮度滑块与亮度键恢复**；只在装了 NullMoth 驱动时生效。若加完卡在 GPU 启动阶段，删掉它 |
| `itlwm_he=1` | 给 BE200 打开 **HE / 802.11ax（Wi-Fi 6）**，同时是 6 GHz（Wi-Fi 6E）能力集的入口；**Wi-Fi 6 连接稳定性依赖它** |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | AMFI 放行，配合 AMFIPass 加载未签名 kext |
| `ipc_control_port_options=0` | 规避部分 IPC 限制 |
| `alcid=13` | AppleALC 使用 layout 13 |
| `alcverbs=1` | 启用 AppleALC 共享 DAC 的 verb hook（**声卡修复必需，别删**，否则 pin14 的音量/静音镜像不工作） |

---

## 8. 为什么开机可能黑屏 ~98 秒

内屏由独显输出。NullMoth 驱动把内屏接起来的过程没有任何东西往控制台打印，画面就停在最后几行（`VoodooI2C…` / `Notification consumer published…` 之类）。
**没装 NVIDIA 驱动时不会有这段黑屏**，但也不会有内屏画面——那时只能靠旧帧缓冲（黑屏+光标）。这是驱动装入前后的正常差异，与 EFI 无关。

---

## 9. 已知限制

- 只针对 **83F5 + ALC287 + 双 AW88399 + BE200**；其他 Legion 型号、其他 codec、其他功放拓扑不要直接套用。
- **Wi-Fi 的限制**：6 GHz 目前只做到被动扫描与上报，实际 6 GHz 关联未验证；纯 **WPA3-SAE 未实现**（WPA2-Personal / WPA2-Enterprise 可连）；**Wi-Fi 7 未测试**；没有隔空投送 / AWDL。Wi-Fi 6 的 HE 能力依赖 boot-args 的 `itlwm_he=1`，去掉会退回 11ac。
- 3.5 mm 耳机口、HDMI/DP 音频、睡眠/唤醒、摄像头、长时间播放未做本版验证。
- `AW88399Driver.kext` 与 `AppleALC.kext` 来自同型号 macOS 26 构建；Mach-O 没有版本下限，`LSMinimumSystemVersion = 26.0` 不影响在 15.8 上加载。若系统大版本更新后失效，需要按源码重编到对应 SDK。
- `DSDT.aml` 是整机补丁表，同型号可复用，但**不同 BIOS 版本可能有差异**；升级 BIOS 后建议重新提取核对。
- USB 上限：本机两个 xHCI（`XHC2` PCH 主控、`TXHC` USB4）端口数超过 macOS 每控制器 15 个的额度，配置里 `XhciPortLimit = true` 已打开，实测左侧 USB-A / Type-C / 雷电口均正常。

---

## 10. NVIDIA（NullMoth 2.6.2）

本 EFI **不包含** NVIDIA 内核驱动；只保留 NullMoth 相关 boot-args、`NullMothSafe.efi` 两个入口和 dGPU 的 `acpi-wake-type` 属性。

驱动本体 `NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC` 装在 `/Library/Extensions`，`NVMTLDriver` 在 `/Library/GPUBundles`，需要用 NullMoth 的安装器在目标系统上单独安装。

`NullMothSafe.efi` 两个入口：

- `1401: Start once without NVIDIA driver`：本次启动不加载 NVIDIA 驱动（重启自动恢复）；
- `1401: Remove NVIDIA driver`：下次启动移除 NVIDIA 驱动。

声卡 / Wi-Fi 修复与 NVIDIA 完全独立。

> **内屏亮度也归 NVIDIA 驱动管**：本机内屏接在独显上，固件 DSDT 里只有一个空的 `_BCM` 桩，SSDT-PNLF 那套在这里没有意义。装上 NullMoth 驱动后，boot-args 里的 **`nvrmacpibl=1`** 会让 NVKMS 自己注册内屏背光，亮度滑块和亮度键就都能用（摘掉这个参数则滑块变灰）。如果加了它之后开机卡在 GPU 启动阶段，把它删掉即可——NullMoth 只在带这个参数时才去读 GPU 的 `_DSM`/`_DOD`。

---

## 11. 换机器 / 外传前必读

1. **三码**：`SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 是每台机器的身份，第二台机器必须重新生成，否则两台同码会撞 Apple 服务。
2. **`DSDT.aml`** 是本机固件转储（`LENOVO CB-01`，DSDT 671,581 字节），SSDT 里写死了 `\_SB.PC02.I2C1`（GXTP5100 触摸板）、`\_SB.PC00.LPCB.PS2K`（PNP0303）、`\_SB.GPI0`、`\_SB.PC02.I2C2.SPKR`（功放）这些路径，9 条 ACPI Patch 也是按这份 DSDT 的字节特征做的；**同型号同 BIOS 版本**才成立。
3. **`UTBMap.kext`** 按这块板子的物理口映射（XHCI 24 口 / XHC2 24 口 / TXHC 3 口），换机器要重新映射（USBToolBox）。
4. **`csr-active-config = 0x0A43`** 与 `amfi` 放宽参数会降低系统安全性，请知悉；`Misc>Debug` / `AppleDebugLog` 是排错档，日常可以关掉。

---

## 12. 更新记录

- **2026-10-14** 初版：Y9000P 2025（U9-275HX）OpenCore EFI，三份变体（带/不带 NVIDIA 驱动修改项），声卡 layout 13 可用但外放音量偏小。
- **2026-10-16**：BE200 无线网卡打通（当时方案：`IOSkywalkFamily` + `IO80211FamilyLegacy` + `AirportItlwm` Ventura 二进制 + **OCLP-Mod 3.1.9 根补丁**）；同时确认 `XhciPortLimit = true` 解决左侧 USB 口识别问题。
- **2026-10-27 v1.0（本版）**：
  - **Wi-Fi 改为原生** `AirportItlwm-Sequoia-BE200 2.4.0`，**彻底移除 OCLP 依赖**（不再需要根补丁与 IOSkywalk 回移植）；
  - **外放修复**：`AW88399Driver 0.2` + 双 I2C 资源 `VoodooI2C` + `AppleALC 1.9.8` 共享 DAC，高音/低音同时工作；
  - **内屏亮度恢复**：boot-args 增加 `nvrmacpibl=1`，由 NullMoth 的 NVKMS 注册内屏背光（需装 NVIDIA 驱动），亮度滑块与亮度键可用；
  - 修正 HDEF `layout-id` 的 8 字节 ASCII 写法错误；
  - 仓库重构为**单一 EFI**，删除旧的三份变体与 OCLP 相关文件，补齐文档与 `tools/check-audio.sh`；
  - 清空 SMBIOS 三码，便于外传。
- **2026-10-27 晚 — Wi-Fi 驱动升级到 `_FIX3_20261027`**：
  - 换入新的 `AirportItlwm-Sequoia-BE200.kext`（2.4.0 `_FIX3_20261027`），**修复 Wi-Fi 6 连接不稳**：四次握手末包发送与装钥时序、离网时旧状态请求仍在执行；
  - boot-args 增加 **`itlwm_he=1`**，打开 HE / 802.11ax（Wi-Fi 6 / 6 GHz 能力集）；
  - 保留 6 GHz 被动扫描与结果上报（实际 6 GHz 关联尚未验证）。

---

## 13. 文档索引

- [EFI 细节](docs/EFI-DETAILS.md)：ACPI、Kext、config 各段、Quirks、启动参数
- [声卡原理](docs/AUDIO-AW88399.md)：ALC287 + AW88399 拓扑、Linux 对照、验证与排错
- [安装步骤](docs/INSTALL.md)：BIOS、三码、复制 EFI、首次启动
- [故障排查](docs/TROUBLESHOOTING.md)：启动、声卡、Wi-Fi、触摸板、NVIDIA
- [变更记录](docs/CHANGELOG.md)
- [第三方组件](THIRD-PARTY.md)

---

## 14. 致谢

- [Acidanthera](https://github.com/acidanthera)：OpenCore、Lilu、VirtualSMC、WhateverGreen、AppleALC、VoodooInput
- [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C)：I2C 触摸板与设备 nub
- [Ersiter/Legion-ALC287-AW88399-macOS](https://github.com/Ersiter/Legion-ALC287-AW88399-macOS)：ALC287 共享 DAC 分支、AW88399Driver、双 I2C 资源补丁
- [OpenIntelWireless/itlwm](https://github.com/OpenIntelWireless/itlwm)：AirportItlwm（BE200）
- NullMoth 2.6.2：NVIDIA 驱动与工具链（本包不含驱动）
- Linux 侧参考：[16iax10h-linux-sound-saga](https://github.com/nadimkobeissi/16iax10h-linux-sound-saga)、[作者博客](https://www.wsjj.top/archives/176)

---

## 15. 免责声明

EFI 与 ACPI 表会直接参与固件启动。请先备份原 EFI，并确认自己能通过 U 盘 / Windows / macOS Recovery 恢复。因使用本包造成的系统损坏、数据丢失或保修问题，作者不承担责任。
