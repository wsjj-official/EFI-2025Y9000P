# EFI-Sequoia-83WW — macOS 15 Sequoia + BIOS 83WW

这份是 **`EFI-Sequoia-78WW/`（macOS 15）与 `EFI-Tahoe-83WW/`（BIOS 83WW 的 ACPI 配方）的组合**，
用来解决一个具体场景：

> **BIOS 83WW + macOS 26 + 未装 NVIDIA 驱动 = 黑屏只剩光标。**
> 26 上没有驱动就没有可用的合成后端（`IONDRVSupport` 被排除、Apple 的通用加速器是 Apple Silicon 的
> `IOVersatile`，在 Intel 上加载不了），所以无法"先点亮桌面再装驱动"。
> 而 15 上通用帧缓冲那条路是开着的 —— 没有驱动也能进桌面（约 1–3 FPS）。

## 用途（过渡站，不是最终形态）

1. 用这份 EFI 安装 / 引导 **macOS 15.8**；
2. 进桌面（慢，1–3 FPS，正常现象）；
3. 装 **NullMoth 2.9**（1401 app 或 `install.sh`），重启后恢复正常帧率；
4. 升级到 **macOS 26**；
5. 升级完**换回 [`EFI-Tahoe-83WW/`](../EFI-Tahoe-83WW/)**，并在 26 上**重跑一次 `install.sh`**
   （15 装的是 15 的 `NVAccel`，26 需要 26 的，否则"驱动加载成功但桌面全黑"）。

## 与 `EFI-Sequoia-78WW/` 的差异

| 项目 | `EFI-Sequoia-78WW/`（78WW） | 本目录（83WW） |
| --- | --- | --- |
| `ACPI/` | 注入 `DSDT.aml` + 9 个 SSDT | **无 DSDT**；`APIC-CPU24.aml` + 9 个 SSDT |
| `ACPI > Delete` | 只丢 `DMAR` | 丢 `DMAR` + **替换 856 字节 APIC** |
| `ACPI > Patch` | 78WW 的 9 条 | 83WW 的 10 条（含两条 `PC02`） |
| `UTBMap.kext` | 78WW 端口表 | **83WW 端口表**（`TXHC` 5 口，雷电 USB 3.2） |
| `boot-args` | — | 追加 **`TSC_sync_margin=0`**（配 `CpuTscSync`，83WW 关 VT-d 时避免 `Non-monotonic time`） |
| `Kernel > Block` | 只有 `AppleEthernetRL` | 同左（**没有** `IONDRVSupport`，这是无驱动也能出画面的前提） |

其余（kext 集合、`Booter`/`UEFI` quirks、`DeviceProperties`、SMBIOS）与 `EFI-Sequoia-78WW/` 一致。

## 两个 config

| 文件 | `Kernel > Block` | 什么时候用 |
| --- | --- | --- |
| `config.plist` | 只有 `AppleEthernetRL` | **装驱动之前**（默认） |
| `config-with-driver.plist` | 多一条 `IONDRVSupport`（`Exclude`，`MinKernel 20.0.0`） | 装好驱动之后；出现"驱动在、画面黑/不刷新"时切过去 |

切换方法：把 `config.plist` 改名留档，再把要用的那份改名成 `config.plist`。

## 验证（进系统后）

```sh
kmutil showloaded --list-only | grep -i nullmoth     # 装驱动后应有 4 条
system_profiler SPDisplaysDataType | head -20        # 装驱动后应出现 Metal: Supported
```
