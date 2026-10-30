# 第三方组件与许可

本包不包含 Apple 系统驱动。各组件的版权与许可归上游作者所有；使用、再分发前请阅读对应项目的 LICENSE。

## 核心组件

| 组件 | 版本 | 上游 | 许可（以仓库为准） |
| --- | --- | --- | --- |
| OpenCorePkg（OpenCore.efi / BOOTx64.efi / Drivers / Tools） | 自定义 2025-09 构建 | <https://github.com/acidanthera/OpenCorePkg> | BSD-3-Clause |
| Lilu | 1.7.3 | <https://github.com/acidanthera/Lilu> | BSD-3-Clause |
| VirtualSMC | 1.3.9 | <https://github.com/acidanthera/VirtualSMC> | BSD-3-Clause |
| WhateverGreen | 1.7.2 | <https://github.com/acidanthera/WhateverGreen> | BSD-3-Clause |
| AppleALC（共享 DAC 分支） | 1.9.8 | <https://github.com/Ersiter/AppleALC> | BSD-3-Clause |
| AW88399Driver | 0.2 | <https://github.com/Ersiter/Legion-ALC287-AW88399-macOS> | GPL-2.0-only |
| VoodooI2C（dual-resource 补丁） | 2.9.1 | <https://github.com/VoodooI2C/VoodooI2C> | GPL-3.0 |
| VoodooI2CHID | 1 | <https://github.com/VoodooI2C/VoodooI2C> | GPL-3.0 |
| VoodooPS2Controller | 2.3.8 | <https://github.com/acidanthera/VoodooPS2> | GPL-2.0 |
| AirportItlwm（BE200 Sequoia，**内测分支**） | 2.4.0 `_FIX22_20261030` | <https://github.com/Ersiter/AirportItlwm-BE200>（源自 <https://github.com/OpenIntelWireless/itlwm>） | GPL-2.0 |
| IntelBluetoothFirmware | 2.5.0 | <https://github.com/OpenIntelWireless/IntelBluetoothFirmware> | GPL-2.0 |
| IntelBTPatcher | 2.5.0 | 同上 | GPL-2.0 |
| BlueToolFixup（**FixA2DP 补丁版**） | 2.7.3 | <https://github.com/hexxyan/BlueToolFixup-FixA2DP>（基于 <https://github.com/acidanthera/BrcmPatchRAM>） | BSD-3-Clause |
| AppleIGC | 1.9d2 | <https://github.com/SongXiaoXi/AppleIGC> | 见上游 |
| NVMeFix | 1.1.4 | <https://github.com/acidanthera/NVMeFix> | BSD-3-Clause |
| RestrictEvents | 1.1.7 | <https://github.com/acidanthera/RestrictEvents> | BSD-3-Clause |
| BrightnessKeys | 1.0.4 | <https://github.com/acidanthera/BrightnessKeys> | BSD-3-Clause |
| CpuTscSync | 1.1.3 | <https://github.com/lvs1974/CpuTscSync> | 见上游 |
| YogaSMC | 1.5.3 | <https://github.com/zhen-zen/YogaSMC> | GPL-2.0 |
| USBToolBox / UTBMap | 1.2.0 / 1.1 | <https://github.com/USBToolBox/kext> | MIT |
| AMFIPass | 1.4.1 | <https://github.com/dhinakg/AMFIPass> | BSD-3-Clause |
| HoRNDIS | 9.2 | <https://github.com/jwise/HoRNDIS> | GPL-2.0 |
| AppleMCEReporterDisabler | 1.2 | 见 OpenCore / Dortania 相关发布页 | 见上游 |
| ECM-Override | 9.9.9 | <https://github.com/dortania/OpenCore-Install-Guide> | 见上游 |
| CpuTopologyRebuild | 2.0.2 | <https://github.com/b00t0x/CpuTopologyRebuild> | 见上游 |
| NullMothSafe（Tools） | — | NullMoth 2.6.2 工具链（见其发布说明） | 见上游 |

> 上表中标注“见上游”的条目，本包未逐一复制 LICENSE 文件；再分发时请从对应仓库获取完整许可文本。

## ACF 固件

`AW88399Driver.kext` 内置的 `aw88399_acf.bin`：

- 长度：152416 字节
- SHA-256：`1e927c9bca76d868181c0f81df2bccef3cf19c7d0910219f229360c87babd42c`
- 来源：Lenovo Windows 驱动包中的 Awinic ACF；Awinic 曾向 `linux-firmware` 提交同内容文件，许可为可再分发（Redistributable）。
- 上游说明：<https://github.com/Ersiter/Legion-ALC287-AW88399-macOS/blob/main/docs/FIRMWARE.md>
- Linux 参考：<https://github.com/nadimkobeissi/16iax10h-linux-sound-saga>

如果你再分发本包，请保留本文件和上游版权声明。

## Apple 材料

本包不包含：

- AppleHDA / AppleHDAController / IOAudioFamily 等 Apple 系统驱动；
- macOS 安装镜像；
- Apple 的商业字体、图标或其它受版权保护资源（OpenCore `Resources` 中的图标来自 OpenCanopy 主题，按其许可使用）。

## 商标

Lenovo、Legion、Realtek、Awinic、Intel、NVIDIA、Apple、macOS 等名称和商标归各自所有者。本包与上述公司无隶属关系。
