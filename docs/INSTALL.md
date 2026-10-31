# 安装步骤

本文假设目标机器是 **Legion Y9000P IAX10H / 83F5 / ALC287 + 双 AW88399**。其他型号不要直接套用。

---

## 1. 准备

- 一个 FAT32 的 U 盘（≥ 64 MB），或能挂载本机 EFI 分区的 macOS/Windows 环境
- 你当前能启动的 EFI 完整备份
- [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS)
- [ProperTree](https://github.com/corpnewt/ProperTree) 或 Xcode
- 目标系统：macOS 15 Sequoia（实测 15.8 / 24H23）或 macOS 26 Tahoe（实测 26.7）

> **先选 EFI**：macOS 15 用 `EFI-Sequoia/EFI/`，macOS 26 用 `EFI-Tahoe/EFI/`（整个 `EFI` 目录拷到 ESP 根目录，不用改名；两份不要混拷）。
> macOS 26 的取舍与装驱动顺序见 [README-macOS26-Tahoe.md](../README-macOS26-Tahoe.md)。

> 先把当前 EFI 整个 `EFI` 目录复制到 U 盘或另一块硬盘。不要在没有回退手段的情况下覆盖唯一可启动的 EFI。

---

## 2. 生成自己的 SMBIOS 三码

发布包已经清空原机三码，直接使用会导致 iCloud/iMessage/App Store 不可用。每台机器必须生成自己的。

### 2.1 用 GenSMBIOS

```sh
git clone https://github.com/corpnewt/GenSMBIOS
cd GenSMBIOS
./GenSMBIOS.command
```

菜单选择：

1. `Install/Update ProperTree`（可选）
2. `Select config.plist`（可选）
3. `Generate SMBIOS`

机型输入：

```text
MacBookPro16,2
```

记下输出中的：

```text
Serial:        XXXXXXXXXXXX
Board Serial:  XXXXXXXXXXXXXXXX
SmUUID:        XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

### 2.2 生成 ROM

`ROM` 是 6 字节网卡 MAC，不是随机数。取本机有线网卡或 Wi-Fi 的 MAC，去掉 `:` 或 `-`：

```sh
ifconfig en0 | grep ether
# 例如 13:2e:6f:cc:af:08 -> 132e6fccaf08
```

在 `config.plist` 里填为 Data（6 字节）：

```text
13 2E 6F CC AF 08
```

### 2.3 填写 `PlatformInfo > Generic`

| 键 | 值 |
| --- | --- |
| `SystemProductName` | `MacBookPro16,2`（保持） |
| `SystemSerialNumber` | GenSMBIOS 的 Serial |
| `MLB` | GenSMBIOS 的 Board Serial |
| `SystemUUID` | GenSMBIOS 的 SmUUID |
| `ROM` | 6 字节 MAC |
| `ProcessorType` | `3841`（保持） |
| `SpoofVendor` | `true`（保持） |

用 ProperTree 打开 `EFI/OC/config.plist`，按 `Cmd+F` 搜索 `SystemSerialNumber`，逐项替换。`ROM` 的类型必须是 **Data**，不是 String。

> 生成的三码只属于你自己，不要发到公开群/仓库。发布包里为空是正常的。

---

## 3. BIOS 设置

不同 BIOS 版本的选项名可能不同；以下是本机验证环境相关的设置。进入 BIOS：开机按 `F2`（Legion 常见），部分机型需要先关 Fast Boot。

| 项目 | 建议 | 说明 |
| --- | --- | --- |
| Secure Boot | Disabled | 未签名 OpenCore/kext 必需 |
| CSM / Legacy Boot | Disabled | 纯 UEFI |
| Fast Boot | Disabled | 便于进 BIOS/USB |
| Above 4G Decoding | Enabled | 大显存/ReBAR 需要 |
| Re-Size BAR | Enabled | 与 `ResizeAppleGpuBars=0` 配合；如启动异常可尝试 Disabled |
| VT-d | Enabled | 本 EFI 删除 DMAR；如遇启动/设备问题可尝试 Disabled |
| CFG Lock | Disabled（如可改） | 不改也可以，`AppleXcpmCfgLock=true` 会绕过 |
| Intel SGX | Disabled（如可改） | 避免额外变量 |
| Thunderbolt / USB4 | 保持默认 | 本版未验证 |
| Boot Order | UEFI: OpenCore 所在盘优先 | 安装/升级时 |

> 如果 BIOS 没有开放 CFG Lock / VT-d / ReBAR 等选项，保持默认即可；本 EFI 的 Quirks 已覆盖常见情况。

---

## 4. 复制 EFI

### 4.1 macOS 下

```sh
diskutil list
# 找到 EFI 分区，例如 disk1s1
diskutil mount disk1s1
```

把本包的 `EFI` 目录复制到 EFI 分区根目录：

```sh
cp -R /path/to/Legion-Y9000P-IAX10H-EFI-v1.0/EFI /Volumes/EFI/
```

如果 EFI 分区已有 `EFI/Microsoft`（Windows Boot Manager），**不要删除**；只替换/合并 `EFI/BOOT` 和 `EFI/OC`。

### 4.2 Windows 下

用 DiskGenius / `mountvol` 挂载 EFI 分区，把 `EFI` 目录复制进去，保留 `EFI/Microsoft`。

### 4.3 检查

```text
EFI/
├── BOOT/BOOTx64.efi
├── OC/...
└── Microsoft/...     # 如果你有 Windows，保留
```

确认 `EFI/OC/config.plist` 里已经填好三码。

---

## 5. 首次启动

1. 插上 U 盘或从硬盘 EFI 启动，进入 OpenCore 选择界面。
2. 先选 `Reset NVRAM`（本包 `HideAuxiliary=false`，应直接可见；若隐藏，按空格）。
3. 机器重启后再次进入 OpenCore。
4. 选择 `macOS` 启动。
5. 首次启动会较慢，`-v` 会显示大量日志；能进桌面即成功。

### 5.1 如果进不了系统

- 确认 BIOS Secure Boot 已关闭；
- 确认 `EFI/OC/config.plist` 的 `PlatformInfo > Generic` 三码格式正确（尤其 `ROM` 是 6 字节 Data）；
- 确认没有把 `EFI/Microsoft` 覆盖掉；
- 用你备份的原 EFI 启动，或进 macOS Recovery/Windows 恢复。

---

## 6. 进入系统后的检查

### 6.1 声卡

```sh
bash tools/check-audio.sh
```

或手动：

```sh
kmutil showloaded | grep -Ei 'AppleALC|VoodooI2C|AW88399'
ioreg -l -w0 -r -c AW88399Driver | grep AW88399
```

期望：

- `AppleALC 1.9.8`
- `VoodooI2C 2.9.1`
- `AW88399Driver 0.2`
- 两个 `SPKR` nub（0x34 / 0x35）
- `AW88399Ready = Yes`

播放一段音乐，确认高音和低音都有输出，音量滑块有效。

### 6.2 Wi-Fi

```sh
system_profiler SPAirPortDataType | grep -E 'Card Type|Firmware|MAC'
```

应看到 `itlwm 2.4.0` 和 BE200（`8086:272b`）。

### 6.3 蓝牙

```sh
system_profiler SPBluetoothDataType | head -30
```

### 6.4 触摸板 / 键盘

- 触摸板应能移动、点击、双指滚动；
- 键盘应正常；
- 如果触摸板不工作，确认 `-vi2c-force-polling` 仍在，且 `VoodooI2C` 在 `VoodooI2CHID` 之前。

### 6.5 电池 / 传感器

```sh
pmset -g batt
```

应显示电池百分比和充电状态。

---

## 7. 安装后

### 7.1 iServices

三码正确后，登录 Apple ID，确认 iCloud、App Store、iMessage。首次登录可能需要：

- 有线/无线网卡 MAC 与 `ROM` 一致；
- `SystemUUID` 唯一；
- 不要在多台机器共用同一套三码。

### 7.2 NVIDIA 独显

本包 **不含** NVIDIA 驱动。当前系统显示：

```text
NVIDIA (0x10de) Device ID: 0x2f58
Kernel Extension Info: No Kext Loaded
```

需要按 NullMoth 2.6.2 的说明单独安装。OpenCore 里已保留：

- `NullMothSafe.efi` 的 `Remove NVIDIA driver` / `Start once without NVIDIA driver`
- `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth`
- `amfi_get_out_of_my_way=0x1 amfi=0x80`

安装/升级 NVIDIA 驱动前，先用 `NullMothSafe` 的“本次不加载”入口确认能进系统。

### 7.3 更新 macOS

- 更新前备份 EFI 和三码；
- macOS 大版本更新可能改变 AppleHDA/IOAudioFamily，AppleALC 和 AW88399Driver 可能需要重编；
- 更新后先确认能进系统，再检查声卡；
- 保留 `OC` 备份和可启动 U 盘。

### 7.4 更新 OpenCore / kext

- 不要只替换 `OpenCore.efi`；按 OpenCorePkg 的升级流程同步 `BOOTx64.efi`、`Drivers`、`config.plist` 结构；
- 更新 AppleALC/VoodooI2C 时，必须保留共享 DAC 分支和 dual-resource 补丁，不要直接换原版；
- 更新 AW88399Driver 时，确认内置 ACF 仍在，且 `MinKernel/MaxKernel` 适合当前系统。

---

## 8. 恢复

发布包不包含你的原机备份。请自己保留：

- 原 EFI 的完整副本；
- 本包解压后的 `EFI`；
- 一个可启动的 macOS Recovery/U 盘。

如果新 EFI 启动失败：

1. 用原 EFI 或 U 盘启动；
2. 挂载 EFI 分区；
3. 把原 `EFI/OC` 覆盖回去；
4. 保留 `EFI/Microsoft`。

macOS Recovery 终端示例：

```sh
diskutil list
diskutil mount disk1s1
cp -R "/Volumes/EFI-BACKUP/EFI/OC" "/Volumes/EFI/EFI/OC"
```

---

## 9. 注意

- 本 EFI 只针对 83F5 + ALC287 + 双 AW88399；其他 Legion 的 codec/功放拓扑不同。
- `DSDT.aml` 是整机补丁表，升级 BIOS 后建议重新提取核对。
- 发布包的三码为空是刻意为之，不是配置错误。
- 如果只是想要声音而不关心 iServices，空三码也能启动；但登录 Apple ID 前请先补齐。
