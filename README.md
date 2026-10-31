# Lenovo Legion Y9000P IAX10H（83F5）— OpenCore EFI（macOS 15 + macOS 26）

面向 **Lenovo Legion Y9000P IAX10H / 板号 83F5 / Intel Core Ultra 9 275HX / RTX 5070 Ti Laptop** 的 OpenCore EFI。

**仓库现在是两份 EFI，按系统版本选一份用：**

| 目录 | 目标系统 | 状态 |
| --- | --- | --- |
| [`EFI-Sequoia/`](EFI-Sequoia) | **macOS 15 Sequoia**（15.2+） | 主力、长期验证：外放（ALC287 + 双 AW88399）、BE200 Wi-Fi、蓝牙 A2DP、亮度全部可用 |
| [`EFI-Tahoe/`](EFI-Tahoe) | **macOS 26 Tahoe**（26.4+） | 新增、实测**能进桌面**。**装 NVIDIA 驱动之前会非常卡（约 1–3 FPS）**，装完驱动才正常 |

> 两份都是「`BOOT/` + `OC/` 直接展开」的形态，把选中那份的**内容**拷到 ESP 根目录即可（保留 `EFI\Microsoft`，否则 Windows 引导会丢）。
> **不要两份混拷**：Wi-Fi / 蓝牙 kext 是分系统版本的（15 用 `AirportItlwm-Sequoia-BE200`，26 用 `AirportItlwm-Tahoe-BE200`）。

**这一版做成了这几件事：**

1. **Wi-Fi 打通** —— Intel BE200（`8086:272b`），`AirportItlwm` **2.4.0 `_FIX24_20261030`** 直接注入，**不需要 OCLP / 根补丁 / IOSkywalk 回移植**；WPA3-Personal（SAE/H2E）实测可用；
2. **外放修好** —— Realtek ALC287 + 两颗 Awinic AW88399 智能功放（高音 + 低音同时工作，音量/静音正常）；
3. **蓝牙 A2DP 修复** —— AirPods 等设备「能连上、放歌没声 / 断一下就没声」已修（`BlueToolFixup` FixA2DP + `-btlfxa2dpcheck`）；
4. **内屏亮度** —— `nvrmacpibl=1`，由 NullMoth NVKMS 注册背光（需装 NVIDIA 驱动）；
5. **macOS 26 EFI** —— 新增，实测可进系统；**未装 NVIDIA 驱动时仅 1–3 FPS**，详见 [README-macOS26-Tahoe.md](README-macOS26-Tahoe.md)。

> 发布包已经清空原机 SMBIOS：`SystemSerialNumber` / `MLB` / `SystemUUID` 为空、`ROM` 为 6 字节零。
> **使用前必须用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成自己的三码**，否则 iCloud、iMessage、App Store 会不可用（不影响开机与声卡）。

---

## 0. 和旧版（仓库最早那三份 EFI 变体）的区别

仓库最早是三个变体目录：`带NVIDIA驱动修改项EFI`、`不带NVDIA驱动修改项EFI`、`EFI-1401移除OCLP支持带NV驱动修改项`，
后来合并成一份 EFI；**2026-10-31 起又拆成「15 / 26 各一份」**（驱动 ABI 不同，不能共用）。

| 项目 | 旧版（2026-10-14 / 10-16） | 本版 v1.0（2026-10-27） |
| --- | --- | --- |
| Wi-Fi（BE200） | `AirportItlwm 2.3.0`（Ventura 二进制）+ `IOSkywalkFamily` + `IO80211FamilyLegacy`，屏蔽系统 `IOSkywalkFamily`，**系统侧还要装 OCLP-Mod 3.1.9 打根补丁** | `AirportItlwm-Sequoia-BE200 2.4.0` 原生注入，**不需要 OCLP、不需要根补丁、不需要 IOSkywalk 那一套** |
| 声卡外放 | `AppleALC` layout 13，能出声但**音量很小**（缺功放驱动） | 增加 `AW88399Driver.kext 0.2`（两颗功放 `0x34`/`0x35` + ACF 固件）+ `AppleALC 1.9.8` 共享 DAC 分支 + `VoodooI2C` dual-resource 补丁，**高音/低音都正常** |
| SIP | `0xFF0F0000` | `0x0A43`（只为放行第三方 kext，保持最小放宽） |
| `Kernel>Block` | 还要屏蔽 `IOSkywalkFamily` | 只剩 `AppleEthernetRL` 一条（让 AppleIGC 接管 I225/I226） |
| 仓库结构 | 三份变体 + `Wi-Fi修复-所需文件/`（含 767 MB 的 OCLP-Mod 安装包） | `EFI-Sequoia/` + `EFI-Tahoe/` 两份 EFI + 文档 + 检查脚本，OCLP 相关文件全部移除 |
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
| Wi-Fi（BE200） | ✅ 已验证（**WPA3 已可用**） | `AirportItlwm-Sequoia-BE200 2.4.0 _FIX24_20261030`，**无需 OCLP 根补丁**；HE/Wi-Fi 6 由 `itlwm_he=1` 开启；**WPA3-Personal（SAE/H2E）实测可连**，WPA2 也照常可用；**Wi-Fi 7（EHT/802.11be）在 macOS 15 上不支持** |
| 蓝牙 | ✅ 驱动已加载 + A2DP 修复 | IntelBluetoothFirmware 2.5.0 + IntelBTPatcher 2.5.0 + **BlueToolFixup 2.7.3 FixA2DP**（配 `-btlfxa2dpcheck`） |
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
| **macOS 26 Tahoe（`EFI-Tahoe/`）** | ✅ 可进桌面（需 NVIDIA 驱动才有正常帧率） | 实测能进系统；**未装 NullMoth 驱动时约 1–3 FPS**，装驱动后正常；详见 [README-macOS26-Tahoe.md](README-macOS26-Tahoe.md) |
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

**本版驱动（2026-10-30 更新，`_FIX24_20261030`）**：`AirportItlwm-Sequoia-BE200.kext` 换成 **2.4.0 `_FIX24_20261030`** 构建。

- **国家码 / 监管域**：按「启动参数 → 固件 → 定位」的优先级上报；监管请求是否获准、实际可用信道表分别取自固件响应，不再互相污染；修正「监管请求被拒后仍锁死后续更新」以及复位后硬件接管、定时器与停机的生命周期问题；
- **6 GHz**：补齐 **RNR 邻居报告 → 6 GHz 定向探测**链路（通过真实探测响应拿到 SSID），刷新更名缓存并保留隐藏 SSID 行为；
- **多链路**：监管表变更后统一校验主/次链路的信道、HE/EHT 与带宽限制，清理失效连接与迟到的多链路任务；
- **RX 中断**：修正关闭 Wi-Fi 后仍允许排队 RX 中断分派的问题，保留启动 ALIVE 与 RF-kill 通知；
- 继承前面的修复：WPA3-Personal（SAE，默认 **H2E-only**）、AP RSNXE 与四次握手校验、扫描期误判整卡故障、发送队列排空失败触发整卡重启、连接状态上报、MLO/6 GHz 映射、EHT 打孔位图校验。

> **Wi-Fi 7 说明（重要）**：BE200 是 Wi-Fi 7 硬件，但驱动目前只做到 **802.11a/b/g/n/ac + HE(802.11ax) = Wi-Fi 6/6E**。
> **macOS 15 上不支持 Wi-Fi 7（EHT/802.11be）**；macOS 26 上 EHT/MLO 仍属公测、尚未实测。
> 也就是说：15 和 26 都请按 Wi-Fi 6 / 6E 使用，不要期待 11be 的速率。

**开启 HE / Wi-Fi 6 / 6 GHz**：需要 boot-args 增加 `itlwm_he=1`（驱动只认 `itlwm_he`、`itlwm_cc`、`itlwm_tsleep` 三个参数；`itlwm_he=1` 打开 802.11ax 能力，6 GHz 的 HE 能力集也挂在这条路径上）。本版已加进 `config.plist`。

**开启 HE / Wi-Fi 6 / 6 GHz**：需要 boot-args 增加 `itlwm_he=1`（驱动只认 `itlwm_he`、`itlwm_cc`、`itlwm_tsleep` 三个参数；`itlwm_he=1` 打开 802.11ax 能力，6 GHz 的 HE 能力集也挂在这条路径上）。本版已加进 `config.plist`。

**驱动来源**：[**Ersiter/AirportItlwm-BE200**](https://github.com/Ersiter/AirportItlwm-BE200) —— BE200 的专用分支，目前仍在**内测阶段**，还没有合并进 `OpenIntelWireless/itlwm` 主仓库，也没有对应的正式 release，所以上游仓库看起来"没更新"是正常的。本包的 `_FIX24_20261030` 构建就出自这个分支（`AirportItlwm-Sequoia` / `AirportItlwm-Tahoe` 两个 target，分别对应 15.2+ 和 26.x）。想跟进最新修复或自己编译，直接看那个仓库。

> **连接建议（2026-10-30 更新）：WPA3-Personal（SAE）已实测可用**，可以直接用 H2E 的 WPA3 热点。
>
> - WPA3 默认走 **H2E-only**，所以 **AP 必须支持 H2E**；只支持传统 HnP 的老 WPA3 路由器连不上（HnP 是默认不编译的实验路径）；
> - 连不上 WPA3 时先看路由器有没有「WPA3 / H2E」选项，或先把加密切回 **WPA2-Personal（AES）** 验证网卡本身正常；
> - **WPA2-Personal（AES）与 WPA2-Enterprise（PEAP）仍然完全可用**，想稳一点可以用 WPA2；
> - 不建议伪造监管域来强行开 6 GHz 信道。

其余限制：**6 GHz 关联仍待现场验证**；**Wi-Fi 7/EHT/MLO 未测试**；没有隔空投送/AWDL；扫描偶尔不稳，扫不到列表时用「加入其他网络…」手填 SSID + 密码。

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

### 3.4 蓝牙：A2DP 无声修复（2026-10-29）

**症状**：Intel 蓝牙 + AirPods Pro 2（固件 8B39 及相近版本）能连上、能切降噪、音量也正常，但**放音频没有声音**，或者**音频会话一断就彻底没声**。

**原因**：macOS 蓝牙栈在第三方（Intel）控制器上的 **A2DP 会话恢复缺陷**，不是耳机或手机的问题。

**做法**：换入社区补丁版 `BlueToolFixup.kext`（**2.7.3 FixA2DP**，来自 [hexxyan/BlueToolFixup-FixA2DP](https://github.com/hexxyan/BlueToolFixup-FixA2DP)），并在 boot-args 增加 **`-btlfxa2dpcheck`**（补丁靠这个参数才启用；没有它补丁不生效，也不影响原有蓝牙功能）。

| 项目 | 值 |
| --- | --- |
| Bundle ID | `as.acidanthera.BlueToolFixup`（不变） |
| 版本 | `2.7.3`（FixA2DP 补丁构建） |
| `Kernel>Add` | 仍是原来那一条（`MinKernel 19.0.0`，`Arch Any`），只换了 kext 本体 |
| 依赖 | `IntelBluetoothFirmware` / `IntelBTPatcher` **不动** |

验证：

```sh
sysctl -n kern.bootargs | grep -- -btlfxa2dpcheck      # 必须能看到
kextstat | grep -i bluetoolfixup                        # 应加载
```

然后连 AirPods 听歌，特意做几次「暂停 / 继续 / 切走再切回」，确认每次都有声。

> 注意：**不要**为了切设备反复长按 AirPods 盒背重置（会清掉所有配对）。回退：换回原版 `BlueToolFixup` 2.7.3（acidanthera/BrcmPatchRAM）并从 boot-args 删掉 `-btlfxa2dpcheck`。

---

## 4. 目录结构

```text
├── EFI-Sequoia/                  ← macOS 15 用；把里面的内容（BOOT/ + OC/）拷到 ESP 根目录
│   ├── BOOT/BOOTx64.efi
│   └── OC/
│       ├── ACPI/                 ← DSDT + 9 个 SSDT（与 26 共用同一套）
│       ├── Drivers/              ← HfsPlus / OpenRuntime / ResetNvramEntry / OpenCanopy
│       ├── Kexts/                ← 28 个 kext bundle（含 AirportItlwm-Sequoia-BE200、AW88399Driver）
│       ├── Resources/            ← OpenCanopy 图标/字体/语音
│       ├── Tools/                ← NullMothSafe.efi
│       ├── Logs/                 ← OpenCore 日志落盘目录（默认关闭，排错时再开）
│       ├── config.plist          ← 当前配置（三码已清空，需自行填写）
│       └── OpenCore.efi
├── EFI-Tahoe/                    ← macOS 26 用；同样把里面的内容拷到 ESP 根目录
│   ├── BOOT/BOOTx64.efi
│   └── OC/                       ← Tahoe 专用 kext（NMHDA / SimpleHDA / AW88399 25.x / AirportItlwm-Tahoe-BE200 / IntelBT 25x）
├── README-macOS26-Tahoe.md       ← macOS 26 EFI 的详细说明（改动清单、取舍、排错）
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
2. 按系统选一份 EFI，把**里面的内容**（`BOOT/` + `OC/`）复制到 FAT32 的 EFI 分区根目录（**保留** `EFI/Microsoft`，否则 Windows 引导会丢）：
   - macOS 15 → `EFI-Sequoia/`
   - macOS 26 → `EFI-Tahoe/`（先用 [README-macOS26-Tahoe.md](README-macOS26-Tahoe.md) 过一遍它的取舍与装驱动顺序）
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

**macOS 15（`EFI-Sequoia/`）**

```text
-v keepsyms=1 -vi2c-force-polling nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 alcid=13 alcverbs=1 nvrmacpibl=1 itlwm_he=1 -btlfxa2dpcheck
```

**macOS 26（`EFI-Tahoe/`）** —— 多出来的 4 个是 Tahoe / 蓝牙 / WhateverGreen 的硬要求：

```text
-v keepsyms=1 -vi2c-force-polling -ibtcompatbeta -btlfxbe200key gfxrst=4
nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
alcid=13 alcverbs=1 nvrmacpibl=1 itlwm_he=1
```

| 只在 26 上需要的参数 | 为什么 |
| --- | --- |
| `gfxrst=4` | 装了 WhateverGreen 就必须加，否则 WEG 的开机画面拷贝会读到已释放内存 → panic |
| `-ibtcompatbeta` | macOS 26 上用 Intel 蓝牙必须加（Dortania 明确写的） |
| `-btlfxbe200key` | 配合 26 那套 BE200 蓝牙 kext |

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
| `-btlfxa2dpcheck` | 启用 **BlueToolFixup FixA2DP** 的 A2DP 会话恢复补丁（蓝牙耳机放歌没声/断一下就没声）；删掉则退回原版行为 |

---

## 8. 为什么开机可能黑屏 ~98 秒

内屏由独显输出。NullMoth 驱动把内屏接起来的过程没有任何东西往控制台打印，画面就停在最后几行（`VoodooI2C…` / `Notification consumer published…` 之类）。

**没装 NVIDIA 驱动时的实际表现（2026-10-31 在 macOS 26 上实测）**：系统**能进桌面**，但画面只有 **约 1–3 FPS** —— 鼠标要拖很久才动，窗口几乎画不出来。原因是此时只有固件/旧帧缓冲在推像素，没有 GPU 加速。装上 NullMoth 驱动后恢复正常帧率。

所以在 26 上"能进系统但卡成幻灯片"不是 EFI 配错了，而是**还没装显卡驱动**；在 15 上同理（只是 15 那套软件渲染略好一点）。

---

## 9. 已知限制

- 只针对 **83F5 + ALC287 + 双 AW88399 + BE200**；其他 Legion 型号、其他 codec、其他功放拓扑不要直接套用。
- **Wi-Fi 的限制**：**WPA3-Personal（SAE）已实测可用，但要求 AP 支持 H2E**（驱动默认 H2E-only；只支持 HnP 的 AP 连不上，可退回 WPA2）。**macOS 15 不支持 Wi-Fi 7（EHT/802.11be）；26 上 EHT/MLO 仍为公测、未实测**。6 GHz 关联仍待现场验证；没有隔空投送 / AWDL。Wi-Fi 6 的 HE 能力依赖 boot-args 的 `itlwm_he=1`，去掉会退回 11ac。
- **蓝牙 A2DP**：补丁版 `BlueToolFixup` 依赖 `-btlfxa2dpcheck` 才生效；`IntelBluetoothFirmware` / `IntelBTPatcher` 保持原版，不要一起换版本。
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
- **2026-10-29 — Wi-Fi `_FIX18_20261029` + 蓝牙 A2DP 修复**：
  - Wi-Fi 换入 **2.4.0 `_FIX18_20261029`**：6 GHz 扫描/信道映射与自动候选、断连时不再整卡重启、扫描期误判修复、连接状态上报、监管域处理、SAE 重复帧 + H2E（当时 WPA3 实测仍不可用；**已由 2026-10-30 的 Fix22 修复**，见下条）；
  - 蓝牙换入 **`BlueToolFixup 2.7.3 FixA2DP`**（hexxyan 补丁版），boot-args 增加 **`-btlfxa2dpcheck`**，修 AirPods 等设备「能连上、放歌没声 / 断一下就没声」；
  - `Kernel>Add` 里 BlueToolFixup 的 `MinKernel` 调整为 `19.0.0`（与补丁包建议一致），条目本身不变。
- **2026-10-30 — Wi-Fi `_FIX22_20261030`：WPA3-Personal（SAE）实测可用**：
  - 换入 **2.4.0 `_FIX22_20261030`**：WPA3 默认 **H2E-only** 并可连上；修正 **AP RSNXE 保存与四次握手校验**（不再要求 AP 能力字节等于本机写死值）；SAE 主机测试；
  - MLO 关联请求长度 / 附属链路响应偏移 / 共享 AID 修正；PHY 频段比较补上 6 GHz；EHT 按协议校验 80/160/320 MHz 打孔位图；
  - 6 GHz 信道按固件与真实监管域裁剪（不建议伪造地区）；
  - **WPA2-Personal / WPA2-Enterprise 仍然可用**；只支持 HnP 的老 WPA3 路由器仍连不上（HnP 为默认不编译的实验路径）。

---

- **2026-10-31 — 拆成 15 / 26 两份 EFI，Wi-Fi 升到 `_FIX24_20261030`**：
  - 仓库结构改为 `EFI-Sequoia/`（macOS 15）+ `EFI-Tahoe/`（macOS 26）；两份的 ACPI / Booter / DeviceProperties / USB 图 / SMBIOS 完全一致，只有 **Wi-Fi、蓝牙、声卡（AppleHDA）这几组 kext 和 boot-args 按系统版本不同**；
  - **macOS 26 实测可以进桌面**：未装 NVIDIA 驱动时约 **1–3 FPS**（软件帧缓冲），装完 NullMoth 驱动正常；详见 [README-macOS26-Tahoe.md](README-macOS26-Tahoe.md)；
  - Wi-Fi 两套都换到 **2.4.0 `_FIX24_20261030`**（`AirportItlwm-Sequoia-BE200` / `AirportItlwm-Tahoe-BE200`）：国家码/监管域优先级与授权状态、RNR→6 GHz 定向探测、多链路信道与带宽校验、关闭 Wi-Fi 后的 RX 中断队列；
  - **明确：macOS 15 不支持 Wi-Fi 7（EHT/802.11be）**，驱动只到 802.11ax；26 上 EHT/MLO 仍为公测、未实测；
  - 两份 EFI 的 `Misc > Debug` 默认关闭（`Target=0`）；要抓 `OC\Logs` 日志时把 `Target=67`、`DisplayLevel=2147483650`、`AppleDebug/ApplePanic=true` 打开。

---

## 13. 文档索引

- [EFI 细节](docs/EFI-DETAILS.md)：ACPI、Kext、config 各段、Quirks、启动参数
- [声卡原理](docs/AUDIO-AW88399.md)：ALC287 + AW88399 拓扑、Linux 对照、验证与排错
- [**macOS 26（Tahoe）EFI 说明**](README-macOS26-Tahoe.md)：两份 EFI 的取舍、改动清单、装驱动顺序、排错
- [安装步骤](docs/INSTALL.md)：BIOS、三码、复制 EFI、首次启动
- [故障排查](docs/TROUBLESHOOTING.md)：启动、声卡、Wi-Fi、触摸板、NVIDIA
- [变更记录](docs/CHANGELOG.md)
- [第三方组件](THIRD-PARTY.md)

---

## 14. 致谢

- [Acidanthera](https://github.com/acidanthera)：OpenCore、Lilu、VirtualSMC、WhateverGreen、AppleALC、VoodooInput
- [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C)：I2C 触摸板与设备 nub
- [Ersiter/Legion-ALC287-AW88399-macOS](https://github.com/Ersiter/Legion-ALC287-AW88399-macOS)：ALC287 共享 DAC 分支、AW88399Driver、双 I2C 资源补丁
- [**Ersiter/AirportItlwm-BE200**](https://github.com/Ersiter/AirportItlwm-BE200)：BE200 原生 Wi-Fi 驱动（**内测分支**；本包 `2.4.0 _FIX24_20261030` 构建来源，尚未合并进上游主仓库）
- [OpenIntelWireless/itlwm](https://github.com/OpenIntelWireless/itlwm)：itlwm / AirportItlwm 上游项目
- NullMoth 2.6.2：NVIDIA 驱动与工具链（本包不含驱动）
- Linux 侧参考：[16iax10h-linux-sound-saga](https://github.com/nadimkobeissi/16iax10h-linux-sound-saga)、[作者博客](https://www.wsjj.top/archives/176)

---

## 15. 免责声明

EFI 与 ACPI 表会直接参与固件启动。请先备份原 EFI，并确认自己能通过 U 盘 / Windows / macOS Recovery 恢复。因使用本包造成的系统损坏、数据丢失或保修问题，作者不承担责任。
