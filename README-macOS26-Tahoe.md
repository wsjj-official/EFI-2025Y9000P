# macOS 26（Tahoe）可开机 EFI — 说明与改动清单

适用机器：Lenovo Legion Y9000P IAX10H / 83F5 / Core Ultra 9 275HX / RTX 5070 Ti Laptop
对应仓库目录：**`EFI-Tahoe/EFI/`**（macOS 26 用）；对照的是同仓库的 `EFI-Sequoia/`（macOS 15，长期验证）
参考包：外部拿到的 `Tahoe-EFI-share`（别人做的 macOS 26 适配起点，作者自己标注 "not ready to boot"）

---

## 0. 一句话结论

**主用包 = 你那份能开机的 macOS 15 EFI 的硬件配置（ACPI / Booter / DeviceProperties / USB / SMBIOS 全部不动）
＋ 只把 macOS 26 真正需要的驱动和参数换进来。**

`Tahoe-EFI-share` 那份不是"稍微改一下就能用"，它把你这台机器上**已经验证过能开机**的 6 处关键配置改掉了
（ACPI 表、DMAR 丢弃、Booter 两个内存修复、ScanPolicy、APFS Jumpstart、CSR），这些恰好属于"能过 OpenCore
但卡在内核交接"那一类。所以我没有以它为底包，而是只从它里面取 macOS 26 专属的驱动。

---

## 1. 两个包，怎么选

| 目录 | 用途 | 什么时候用 |
| --- | --- | --- |
| `EFI-Tahoe/` | **主用**（本文件对应的包） | 正常启动 macOS 26。配置里已按 NullMoth 要求排除 `com.apple.iokit.IONDRVSupport`，适合**已装 / 将装** NVIDIA 驱动 |
| （诊断变体，未随仓库发布） | 兜底 | 还没装驱动、要进 Recovery / 安装器时用；做法是把 `Kernel > Block` 里 `com.apple.iokit.IONDRVSupport` 那条**禁用**（`Enabled=false`），装完驱动再打开 |

> 现状：驱动已经装好、实机已验证能进桌面，所以兜底包不需要常驻，已经删掉了。

两个包**只差一条** `Kernel > Block`：

```
主用包   : com.apple.iokit.IONDRVSupport   Strategy = Exclude   (MinKernel 25.0.0 / MaxKernel 25.99.99)
兜底包   : 没有这条
```

这条是 NullMoth 驱动文档明确要求的 —— 不排除它，固件 framebuffer 会抢走 display 0，NVRMFB 就拿不到屏幕。
**但同一份文档也写了：安装器和 Recovery 是跑在固件 framebuffer 上的，那时不能排除它。**
所以"装驱动前"和"装驱动后"必须用两份配置，这就是我为什么做成两个包。

> 判断依据（在 macOS 15 上执行，26 卷假设挂在 `/Volumes/Tahoe`）：
> ```sh
> ls /Volumes/Tahoe/Library/Extensions | grep -i nv      # 有 NVRM.kext 等 4 个就说明装了
> ls /Volumes/Tahoe/Library/GPUBundles                   # 应有 NVMTLDriver.bundle
> ```

---

## 2. 26 参考包里被改掉、我改回来的东西（逐条）

| # | 项目 | 你的 15 EFI（能开机） | `Tahoe-EFI-share` | 本包采用 | 为什么 |
| --- | --- | --- | --- | --- | --- |
| 1 | ACPI 表 | 整机补丁 `DSDT.aml`（671 KB）+ 9 个 SSDT（含 HPET、PS2K-HID） | **删掉 DSDT**，换成另一套 SSDT（SBUS/MCHC 拆开、加 `APIC-CPU24`、`SSDT-USB-Reset`），HPET / PS2K 那两条没了 | **15 的** | 这套表是你机器上验证过的；26 那套是"统计 CPU 数量"的实验组合，没在你机器上验证过 |
| 2 | ACPI > Delete | 丢弃 `DMAR` | **改成"替换 856 字节 APIC"**，DMAR 这条没了 | **15 的** | 项目 README 写得很清楚：Core Ultra 上留着 DMAR 会在内核交接处卡住 |
| 3 | ACPI > Patch | HPET/IPIC/RTC/TIMR/PS2K 五条 + 2 条 DSDT 补丁 | 只剩 2 条 + 一条按字节偏移改 `PC02` 的补丁 | **15 的** | 同上，属于已验证组合 |
| 4 | Booter Quirks | `DevirtualiseMmio=1`、`SetupVirtualMap=1`、MMIO 白名单 `0xFF000000` | **两个都改成 0**，白名单**清空** | **15 的** | 这两项关掉是最典型的"能过 OpenCore、卡在内核"的原因 |
| 5 | `Misc > Security > ScanPolicy` | `0`（扫所有盘） | **`2817`** | **0** | 2817 = `0x0B01`，只有 FS 位（APFS/HFS/NTFS），**没有设备位**（NVMe `0x80000`、SATA `0x10000`）→ 可能根本扫不到系统盘 |
| 6 | `UEFI > APFS > EnableJumpstart` | `true` | **`false`** ＋ 塞了个 `apfs_aligned.efi`（其实就是 Apple 的 `apfs.efi`，2025-04-18 构建） | **`true`，不要那个驱动** | 你 15 用 OpenCore 内置 jumpstart 就能读这块 NVMe；两套 APFS 驱动同时在场只会多一个变量 |
| 7 | `csr-active-config` | `0x0A43` | **`0xFF0F0000`** | **`0x0A43`** | NullMoth 驱动文档写的就是 `0x0A43`（"the tested value"）。`0xFF0F0000` 是 OCLP 时代"全关 SIP"的老写法 |
| 8 | `Kernel > Block` | 只有 `AppleEthernetRL` | **换成 `IONDRVSupport`**，`AppleEthernetRL` 没了 | **两条都要** | `AppleEthernetRL` 被屏蔽后 AppleIGC 才能接管 I226 有线网；`IONDRVSupport` 的 Exclude 是 NullMoth 要求的 |
| 9 | `boot-args` | 含 `alcid=13 alcverbs=1 nvrmacpibl=1 itlwm_he=1` | **少了 `alcid` / `alcverbs` / `itlwm_he`**，多了 `-amfipassbeta debug=0x100` | **合并**（见第 4 节） | `-ibtcompatbeta` 是 Dortania 明确写的"macOS 26 上用 Intel 蓝牙必须加"；`gfxrst=4` 是"装了 WhateverGreen + NVIDIA 时必须加，否则 panic" |
| 10 | CPUFriend + DataProvider | 没有 | 有（按 `MacBookPro16,4` 采的 275HX 电压表） | **不加** | 属于能效调优，和开机无关；而且它是按 16,4 采的数据，配 16,2 会错配 |
| 11 | SMBIOS | `MacBookPro16,2` | `MacBookPro16,4` | **`MacBookPro16,2`** | 16,2 在 Dortania 的 Tahoe 支持列表里（16" 2019 / 13" 2020 4口 / MacPro7,1 / iMac20,x），而且是你机器验证过的 |
| 12 | 三码 | 空 | `REPLACE_WITH_YOUR_OWN_VALUE`（长度都不对） | **空（同 15）** | 非法字符串比空更糟。iServices 要用请自己跑 GenSMBIOS |
| 13 | 启动菜单 | `PickerMode=External` + OpenCanopy + ResetNvramEntry | `Builtin`，**HideAuxiliary=true**，没有 OpenCanopy / ResetNvramEntry | **15 的** | 26 那份看不到 Recovery、"Reset NVRAM" 入口，出问题时连自救手段都没有 |
| 14 | `Misc > Debug > Target` | `3` | `0`（全关） | **`67`** | 加上文件日志。黑屏时唯一证据就是 EFI 分区里的 `OC\Logs\opencore-*.txt` |

---

## 3. 从 26 参考包换进来的驱动（都只在 Darwin 25 生效）

`MinKernel` 我保留了原作者的值，等于"只给 macOS 26 用"，你在 15 上继续用旧 EFI 就行。

| kext | 版本 | MinKernel | 作用 |
| --- | --- | --- | --- |
| `NMHDA.kext` | 1.0.0 | 25.0.0–25.99.99 | Tahoe 的 HDA 控制器适配（macOS 26 把 AppleHDA 从系统里拿掉了） |
| `SimpleHDA.kext` | 1.0.0 | 25.0.0–25.99.99 | 在 Tahoe 上把 AppleHDA 找回来，配合 AppleALC 才能出声音 |
| `AirportItlwm-Tahoe-BE200.kext` | 2.4.0 `_FIX26_20261031` | 25.4.0–25.99.99 | BE200 的 Tahoe 版（IO80211 / Skywalk ABI 和 15 不一样，不能混用） |
| `IntelBluetoothFirmware-2.5.1.kext` | 2.5.1 | 全部 | Intel 蓝牙固件（26 用） |
| `IntelBTPatcher-BE200-25x.kext` | 2.5.0 | 全部 | BE200 专用 patcher（"25x" 就是给 Darwin 25） |
| `BlueToolFixup.kext` | 2.7.3 **FixA2DP**（42,464 B） | 21.0.0+ | 蓝牙栈修正 + A2DP 快连门控（`-btlfxa2dpcheck`）；原来的 BE200 实验版（`-btlfxbe200key`）已替换 |
| `AW88399Driver.kext` | 0.2 | 25.0.0–25.99.99 | 两颗 AW88399 功放（0x34 / 0x35） |

**被替换掉的 15 专用驱动**：`AirportItlwm-Sequoia-BE200`、`IntelBluetoothFirmware 2.5.0`、`IntelBTPatcher 2.5.0`
（这三个已从包内删除，不是留着不用，避免误加载）。

其余 28 个 kext 全部原样沿用你 15 的包（Lilu 1.7.3、VirtualSMC 1.3.9、AppleALC 1.9.8、WhateverGreen 1.7.2、
VoodooI2C 2.9.1、USBToolBox + 你的 UTBMap、YogaSMC、NVMeFix…）。

---

## 4. 最终 `boot-args`

```text
-v keepsyms=1 -vi2c-force-polling -ibtcompatbeta gfxrst=4
nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0
alcid=13 alcverbs=1 nvrmacpibl=1 itlwm_he=1 -btlfxa2dpcheck
```

| 参数 | 来源 | 为什么必须在 |
| --- | --- | --- |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | 15 | NullMoth 驱动的启动前提（少一个驱动就不接管屏幕） |
| `amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | 15 | 让 WindowServer 能加载未签名的 `NVMTLDriver.bundle` |
| `gfxrst=4` | 26 | **装了 WhateverGreen 就必须加**，否则 WEG 的开机画面拷贝会读到已释放内存 → panic |
| `-ibtcompatbeta` | 26 | macOS 26 上用 Intel 蓝牙必须加（Dortania 明确写的） |
| `-btlfxa2dpcheck` | 26（2026-10-31 起） | 启用 `BlueToolFixup` FixA2DP 的 A2DP 快连门控（解决 AirPods 连上没声）；取代原来的 `-btlfxbe200key`（BE200 实验版） |
| `alcid=13 alcverbs=1` | 15 | ALC287 layout 13 + 共享 DAC 的 verb hook |
| `itlwm_he=1` | 15 | BE200 的 HE / Wi-Fi 6 能力 |
| `-vi2c-force-polling` | 15 | 触摸板 / SPKR 枚举更稳 |
| `nvrmacpibl=1` | 15 | 让 NVKMS 自己注册内屏背光（亮度滑块 / 亮度键） |
| `-v` | 15 | 详细日志，稳定后可以删 |

**没有** `nv_disable=1`、`-wegnoegpu`、`agdpmod=pikera` —— 这三个都会把 NVIDIA 卡藏起来，是驱动文档里明确禁止的。

---

## 5. 关于"进不了桌面"：这才是关键，EFI 只能解决一半

先把结论摊开说，免得你反复白试：

**你这台机器的内屏接在独显上，核显（Arrow Lake `8086:7D67`）macOS 根本没有驱动，而且配置里已经用
`disable-gpu` 关掉了。**

**实测结论（2026-10-31 更正）：没有 NVIDIA 驱动时，macOS 26 仍然能进桌面，但只有约 1–3 FPS**
—— 鼠标要拖很久才动、窗口几乎画不出来，因为这时是固件/旧帧缓冲在推像素，没有 GPU 加速。
所以"能进系统但卡成幻灯片"不是 EFI 配错了，而是**还没装显卡驱动**；装上 NullMoth 驱动后恢复正常帧率。
（更早的版本里我写过"没有驱动就一定是黑屏 + 鼠标"，那是按别人机器的情况推断的，本机实测不成立。）

NullMoth 驱动自己的文档给了几条硬事实（[README](https://github.com/nullmoth/nvidia-macos-driver)）：

- 支持范围：`macOS 15.5 Sequoia 或更新，或 26 Tahoe, x86_64` —— **Tahoe 是支持的**，所以 26 有戏；
- 必须：`boot-args` 那串 + `csr-active-config` 含 `0x0A43` + `SecureBootModel = Disabled` + `Lilu` 和 `AMFIPass` 在 `Kernel > Add` 里启用；
- 必须：`Kernel > Block` 排除 `com.apple.iokit.IONDRVSupport`（Strategy `Exclude`），否则固件 framebuffer 抢 display 0；
- **NVAccel 分 15 / 26 两套构建**（`NM_TAHOE=1`）。文档原话：*"an accelerator built against an older ABI loads,
  but NVRMFB refuses all its VRAM requests and the desktop stays black."*
  → 也就是说：**在 26 上如果用的是给 15 编的那套，驱动能加载，但桌面就是黑的。**
- 安装器 / Recovery 跑在固件 framebuffer 上，那时候**不能**排除 `IONDRVSupport`。

对着这几条回头看之前的现象，最可能是这两个原因之一：

1. **26 那个卷上压根没装 Tahoe 版驱动**（RDR 恢复出来的卷不会带 `/Library/Extensions` 里的驱动）。
   → 装了驱动但没改 OpenCore 那条 Block，或者改了 Block 但驱动没装，两种都会黑屏。
2. **驱动装了，但装的是 15 的那套 NVAccel**，或者 OpenCore 这侧没按文档配（`csr` 用了 `0xFF0F0000`、
   `IONDRVSupport` 不在 Block 里、缺 `gfxrst=4`）。

我这份包把**第 2 类问题**全部按驱动文档校正了；**第 1 类问题只能靠你去装驱动**（见第 6 节步骤 2）。

---

## 6. 测试步骤

### 步骤 1：备份

把现在能开机的 EFI 整个拷到 U 盘或另一块盘。两个新包都没有动你原来的 `Legion-Y9000P-IAX10H-EFI` 和 `Tahoe-EFI-share`。

### 步骤 2：确认 / 安装 26 卷上的 NVIDIA 驱动

先按第 1 节那两条命令确认 `/Volumes/<26卷>/Library/Extensions` 里有没有 `NVRM.kext`。

- **有** → 直接步骤 3（用主用包）。
- **没有** → 用 `1401-Mac-2.6.2.dmg` 里的 1401 app 在 26 卷上装，
  或者从 15 卷的 `/Library/Extensions` + `/Library/GPUBundles` + `/Library/NullMoth` 拷过去之后重建辅助内核集合（aux KC）。

> ⚠️ 1401 app 会去改"它找到的那份 OpenCore 配置"（加 Block、改 `csr`、改 `boot-args`）。
> 它改的就是你现在生效的那份 `config.plist`。所以：
> **要么**先用我的包启动、确认能进桌面之后再让 app 装驱动；
> **要么**让 app 装完驱动后，把它的改动和我这份 `config.plist` 对一下（差的也就是那条 `IONDRVSupport` 和 `csr`）。
> 它每次改之前会备份，出问题能退回去。

### 步骤 3：先跑一次诊断启动

1. 把 `EFI-macOS26-Tahoe-NoNVIDIA\EFI` 复制到 EFI 分区根目录（保留 `EFI\Microsoft`，否则 Windows 引导会丢）。
2. 开机进 OpenCore → 选 macOS 26 → **先只跑这一份**。
   - 能看到一屏一屏的文本往下滚（`-v` 生效）→ 说明引导链是通的，接着看它停在哪一行；
   - 滚到 `launchd` 前后黑屏但鼠标能动 → 就是"没有可用的显示驱动"，换主用包 + 装驱动；
   - 进 Recovery（菜单里 `HideAuxiliary` 是关的，能看到）→ 用"磁盘工具"确认 26 卷是完整的。

### 步骤 4：换成主用包

把 `EFI-macOS26-Tahoe\EFI` 覆盖上去，直接选 macOS 26。装了驱动的话，正常就会进桌面
（第一次带驱动启动会在 `PCI configuration end` 停最多一分钟，属正常）。

### 步骤 5：黑屏了怎么取证

文件日志已经打开（`Misc > Debug > Target = 67`）。重启回 Windows，把 EFI 分区里的
`EFI\OC\Logs\opencore-*.txt` 拷出来，重点看最后 30 行和这几个关键字：

```text
OC: Prelinked status          -> Success 表示 kext 全部注入成功
EXITBS                        -> 内核交接完成
nvrm / NVRMFB / NVAccel       -> 有没有加载
Waiting for / Service exited  -> 卡在哪个服务
```

拿到日志，就能区分是"内核没起来"（EFI 的事）还是"内核起来了、WindowServer 没画面"（驱动的事）。

---

## 7. 已知取舍 / 限制

| 项目 | 说明 |
| --- | --- |
| **VT-d / 有线网** | 我保留了"丢弃 `DMAR`"（Core Ultra 留着会在内核交接处卡）。代价：社区反馈 macOS 26 的以太网更依赖 VT-d，所以 **I226 有线网在 26 上可能不认**。Wi-Fi 走 BE200，不受影响。如果确认能开机后要修有线网，那是"改 DMAR 表 + 开 BIOS VT-d"的活，得另做，且有可能把开机卡回去。 |
| **Wi-Fi 的 `MinKernel`** | `AirportItlwm-Tahoe-BE200` 我按参考包保留 `25.4.0–25.99.99`（= macOS 26.4 及以上）。你在 26.7，没问题；如果哪天装 26.0–26.3，把这条的 `MinKernel` 改成 `25.0.0`。 |
| **三码** | 沿用了 15 包的空值。开机不受影响，iCloud / iMessage / App Store 要用请自己用 GenSMBIOS 生成 `MacBookPro16,2` 的三码填进 `PlatformInfo > Generic`。 |
| **SMBIOS 备选** | 如果进系统后独显画面异常（例如 AGDP 策略问题），可以试 `MacPro7,1`（纯独显机型，也在 Tahoe 支持列表里）。这个改动会连带影响 CPU 电源管理表现，属于第二选择。 |
| **WhateverGreen** | 社区反馈 WEG 在 26 上对 AMD 有兼容问题；你这台没有 AMD，也没有被支持的核显，WEG 基本是空转。但 NullMoth 文档要求"装了 WEG 就加 `gfxrst=4`"，所以我留着 WEG 并加了 `gfxrst=4`。如果日志里出现 WEG 相关的 panic，可以整条移除 WEG。 |
| **`-v` 详细日志** | 目前是开着的，方便排错。稳定后删掉 `-v` 和把 `Misc > Debug` 关掉都行。 |

---

## 8. 回退

1. 把备份的原 EFI 覆盖回去即可 —— 本包没有改动机器上任何原有文件。
2. 本包会覆盖 NVRAM 里的 `boot-args` 和 `csr-active-config`（`NVRAM > Delete` 里已列入，每次启动重写）。
   想恢复原值，用旧 EFI 启动一次就行。
3. 如果进了系统但显示不对，OpenCore 菜单里还有 `1401: Start once without NVIDIA driver`（本次不加载驱动）
   和 `1401: Remove NVIDIA driver`（永久移除）两个入口，这两个是 15 包里原有的，我保留了。

---

## 9. 这个包里到底改了什么文件

```
EFI/OC/config.plist                     ← 主要改动都在这（对比基线见第 2 节表格）
EFI/OC/Kexts/                            ← 删 3 个、换入 6 个（见第 3 节），其余 28 个原样
EFI/OC/ACPI/                             ← 完全沿用 15 包（10 张表，一张没动）
EFI/OC/Drivers/                          ← 完全沿用 15 包（HfsPlus / OpenRuntime / ResetNvramEntry / OpenCanopy）
EFI/OC/Tools/NullMothSafe.efi            ← 沿用
EFI/OC/Resources/                        ← 沿用（OpenCanopy 图标）
EFI/BOOT/BOOTx64.efi                     ← 沿用
```

`config.plist` 里实际动到的字段，只有这些：

- `Kernel > Add`（重建顺序 + 换驱动）
- `Kernel > Block`（加 `IONDRVSupport`，主用包）
- `Booter > Patch`（删掉一条已禁用的 `macOS to hacOS` 残留）
- `Misc > Debug > Target / DisplayLevel / AppleDebug / ApplePanic`（开日志）
- `NVRAM > Add > boot-args`、`csr-active-config`
- `UEFI > APFS > EnableJumpstart`（=true）、`UEFI > Drivers`（去掉 `apfs_aligned.efi`）
- `Misc > Security > ScanPolicy`（=0）、`SecureBootModel`（Disabled）

`ACPI`、`DeviceProperties`、`PlatformInfo`、`NVRAM` 的其余键、`UEFI > Quirks`、`Booter > Quirks`、`Misc > Boot`
**一个字节都没动**，全部保持你 15 包里的值。

---

## 10. 校验结果

`VALIDATION.txt` 是同目录下的自动校验输出，内容包括：

- `config.plist` 能被正常解析（plist 语法 OK）
- 37 条 `Kernel > Add` 的 bundle 全部存在、`Info.plist` 可读、可执行文件齐全
- 33 条启用项**没有重复 Bundle ID**
- 10 张 ACPI 表、4 个 UEFI 驱动、2 个 Tools 入口全部存在
- `MinKernel <= MaxKernel` 全部合法
- `ScanPolicy=0`、`SecureBootModel=Disabled`、`EnableJumpstart=true`、`csr=0x0A43`
- NullMoth 要求的那 7 个 boot-arg 全部在，禁止的 3 个都不在
- 主用包有 `IONDRVSupport` 排除项、兜底包没有

> 说明：没有跑 `ocvalidate`（这台机器上取不到 OpenCorePkg 的发布包），所以上面是我自己写的等价比对。
> 现在日志开关已经关掉（见第 12 节），要复查的时候按那一节把 `Target`/`AppleDebug` 打开即可。

生成 / 校验用的脚本（可复查、可重跑）：

```text
E:\macos\_work\build_tahoe.py              ← 从 15 包生成这两个 26 包（改什么、取哪个 kext，全在脚本里）
E:\macos\_work\validate.py                ← 上表所有检查项的代码
E:\macos\_work\apply_fix24_and_logoff.py  ← 关日志 + 换 FIX24 驱动
E:\macos\_work\verify_fix24.py            ← 四个 EFI 的复核脚本
```

---

## 11. 包与校验值

| 目录 | 内容 |
| --- | --- |
| `EFI-Tahoe/EFI/` | **仓库里的 macOS 26 包**：里面就是 `BOOT/` + `OC/`，整个 `EFI` 拷到 ESP 根目录即可，不用改名 |
| `EFI-Sequoia/EFI/` | 同仓库的 macOS 15 包，结构相同 |

放 EFI 分区时，把选中那份的 `EFI` 目录整个拷到分区根目录即可（**不用改名**）；两份**不要同时拷**。

校验（在仓库根目录）：

```powershell
Get-FileHash "EFI-Tahoe/EFI/OC/config.plist" -Algorithm SHA256
Get-FileHash "EFI-Sequoia/EFI/OC/config.plist" -Algorithm SHA256
```

---

## 12. 变更记录（2026-10-31 晚）

1. **实机验证通过。** `E:\macos\EFI\EFI`（就是本包）已在这台机器上进 macOS 26 桌面。1401 装驱动时留下的备份
   `config.plist.before-1401-20261031-142644` 与当前 `config.plist` **逐字节相同**，说明驱动要求的设置
   （`IONDRVSupport` 排除、`csr 0x0A43`、那串 boot-args、`SecureBootModel=Disabled`、Lilu + AMFIPass）
   本来就已经齐了，1401 没有需要改的地方。

2. **关闭日志生成。** `Misc > Debug` 改为 `Target=0`、`DisplayLevel=0`、`AppleDebug=false`、`ApplePanic=false`，
   不再往 EFI 分区写 `OC\Logs\opencore-*.txt`。四个 EFI 都改了，每个 `config.plist` 旁边都留了
   `config.plist.before-fix24-<时间戳>` 备份。
   要临时恢复排错，把这四个值改回 `67 / 2147483650 / true / true` 即可。

3. **BE200 驱动换成 `2.4.0_FIX24_20261030`（当晚又升到 `_FIX26_20261031`，见第 5 条）。** macOS 26 的 EFI 用 `AirportItlwm-Tahoe-BE200.kext`，
   macOS 15 的 EFI 用 `AirportItlwm-Sequoia-BE200.kext`。新包 `IOPCIMatch` 自带 `8086:272B`，
   不需要再像以前那样手改 Info.plist。`itlwm_he=1` 已经在 boot-args 里，HE/Wi-Fi 6 开关不用动。

4. **日志复核结论。** 拷贝过来的三份完整日志（13:47 / 14:11 / 14:28 本地时间，OpenCore 记的是 UTC）都走到了
   `EXITBS:START` —— 这是 OpenCore 日志的最后一行，代表已把控制权交给 `boot.efi`，属正常结束；
   途中 `OC: Prelinked blocker (Exclude) result 1 for com.apple.iokit.IONDRVSupport` 命中、
   `CSR:IN 0x0A43` → `CSR:OUT 0x0A43`、`usr\standalone\OS.dmg.root_hash` 正常加载。
   最后一份只有一行 `OC: Failed to drop ACPI 52414D44 (DMAR) - Not Found`，这是**正常现象**：
   BIOS 里关掉 VT-d 之后固件就不提供 DMAR 表，没有东西可丢。

---

5. **（2026-10-31 晚，仓库版）实测补充与结构整理。**

   - **不装 NVIDIA 驱动也能进桌面**，只是 **约 1–3 FPS**（见第 5 节更正）。这意味着"能不能进系统"和"有没有驱动"是两件事：
     进不了 → 查 EFI；进得去但卡成幻灯片 → 装驱动。
   - 仓库结构改为 `EFI-Sequoia/` + `EFI-Tahoe/` 两份并列；两份的 ACPI / Booter / DeviceProperties / USB 图 / SMBIOS 完全相同，
     差异只在 Wi-Fi、蓝牙、AppleHDA 这几组 kext 与 `boot-args`。
   - Wi-Fi 升到 **`2.4.0 _FIX26_20261031`**（26 用 `AirportItlwm-Tahoe-BE200`，15 用 `AirportItlwm-Sequoia-BE200`）；这一版修「关联/认证通过但链路不建立、拿不到地址」的端口授权问题，另含 RX 校验、Fast Lane、160→20 降带宽等。
   - **明确：macOS 15 不支持 Wi-Fi 7（EHT/802.11be）**，驱动只到 802.11ax；26 上 EHT/MLO 仍为公测、未实测。
   - `Misc > Debug` 默认关闭（`Target=0`）；排错时改回 `67 / 2147483650 / true / true`。

---

6. **（2026-10-31 晚）蓝牙换成 FixA2DP 版。**

   - `EFI-Tahoe/EFI/OC/Kexts/BlueToolFixup.kext`：`BE200 stored-key 实验版（39,808 B，`-btlfxbe200key`）` → **FixA2DP 2.7.3（42,464 B，`-btlfxa2dpcheck`）**，修 AirPods「连上但没声」；
   - `boot-args`：去掉 `-btlfxbe200key`，加 `-btlfxa2dpcheck`；`-ibtcompatbeta` 保留；`-btlfxbeta` 在 26.x 上不需要；
   - `IntelBluetoothFirmware-2.5.1` / `IntelBTPatcher-BE200-25x` **不动**（与修复包里的哈希一致）；
   - 回滚：换回旧 `BlueToolFixup.kext`（仓库外备份 `EFI/_backup-bluetooth/BlueToolFixup-BE200-Darwin25-20261016.kext`）并把参数换回 `-btlfxbe200key`；
   - 两个补丁（A2DP 快连门控 / BE200 stored-key）目前没有合并版，只能二选一。

---

## 13. 参考

- [Dortania — macOS 26: Tahoe](https://github.com/dortania/OpenCore-Install-Guide/blob/master/extras/tahoe.md)（Tahoe 支持机型、AppleHDA 移除、`-ibtcompatbeta`、WhateverGreen 注意点）
- [NullMoth NVIDIA Driver](https://github.com/nullmoth/nvidia-macos-driver)（`IONDRVSupport` 排除、`gfxrst=4`、`csr 0x0A43`、NVAccel 分版本）
- 项目自身文档：`EFI\Legion-Y9000P-IAX10H-EFI\docs\EFI-DETAILS.md`、`docs\TROUBLESHOOTING.md`
