# BIOS 版本对照：78WW 与 83WW 各用哪份 EFI

本机（Legion Y9000P IAX10H / 83F5 / Ultra 9 275HX）实测了两个 BIOS 版本，**它们对 macOS 的影响完全不同，EFI 不能互换**。

---

## 1. 结论：怎么选

| BIOS 版本 | 用哪份 EFI | 触控板 | 雷电口 USB 3.2 | 关键手段 |
| --- | --- | --- | --- | --- |
| **78WW** | `EFI-Tahoe/EFI` | ✅ | ✅ | 加载 **`DSDT.aml`**（78WW 预打补丁，已拆 `If (PCHA)`） |
| **83WW** | `EFI-Tahoe-83WW/EFI` | ✅（预期） | ✅（预期） | **不加载 DSDT**；`APIC-CPU24.aml` + 两条 PC02 补丁 + `TXHC` 5 口 |

macOS 15（`EFI-Sequoia/`）目前只做了 78WW 的验证；83WW 上要不要另做一份，取决于后续有没有人在 15 上测。

---

## 2. 为什么必须分两套：`If (PCHA)` 里装的东西不一样

83WW 的固件把 `Device (PC02)` 和它下面的 I2C 设备收进了 **两层** `If (PCHA)`：

| 层 | 补丁 Find（83WW） | 内容 |
| --- | --- | --- |
| 第一层 | `a0 4e 2f 92 93 PCHA 00 5b 82 43 2f PC02` | `Device (PC02)` 本身 |
| 第二层 | `a0 8e 77 16 92 93 PCHA 00` | `Scope (\_SB.PC02)` 下的 **I2C0 / I2C1 / I2C2** 等设备 |

在 83WW 上把这两层拆掉，`\_SB.PC02.I2C1.TPD0`（触控板）和 `\_SB.PC02.I2C2.SPKR`（两颗 AW88399 功放）就都出来了，可以用。

**但 78WW 的第一层 `If (PCHA)` 块里还包着更多东西**：`UBTC`（USB4/雷电控制器）、`UCM1/UCM2`、`UCH1/UCH2`（Type-C 端口设备）、`UBST`、`DGPB/DGPS`（独显供电）。这些设备的 `_INI` 会去读 `UBSC`（运行期 Region）、`TDC1`、`IPC1`、`STB1` 之类的对象——而这些对象在 macOS 侧并不存在。于是拆开后就是：

```
ACPI Error: Method parse/execution failed [\_SB.UBTC._INI] ... AE_NOT_FOUND
ACPI Error: [UBSC] Namespace lookup failure, AE_NOT_FOUND
ACPI Exception: AE_NOT_FOUND, Could not execute arguments for [UBSC] (Region)
ACPI Error: [TDC1] Namespace lookup failure
... _SB.UCM1._INI / _SB.UCH1 / UBST / DGPB / DGPS ...
```

→ 内核在 `_INI` 阶段陷进去，**开不了机**（2026-11-09 实测，78WW + 83WW 配方）。

78WW 之所以能开，是因为它走的是**另一条路**：把 78WW 整张 DSDT 预打补丁后当附加表加载（`EFI-Tahoe/EFI/OC/ACPI/DSDT.aml`），`PC02` 在表里就已经是无条件的，且没有触发上面那条 `_INI` 链。

---

## 3. 两套 EFI 的具体差异

| 项目 | `EFI-Tahoe/`（78WW） | `EFI-Tahoe-83WW/`（83WW） |
| --- | --- | --- |
| `ACPI > Add` | `DSDT.aml` **启用** + 9 张 SSDT | **无 DSDT**；9 张 SSDT + `APIC-CPU24.aml` |
| `ACPI > Delete` | `DMAR` | `DMAR` + **`APIC`（OEM `CB-01   `，TableLength 856）** |
| `ACPI > Patch` | 9 条（含一条 0 命中的占位补丁） | 10 条：8 条通用 + **两条 PC02** |
| `UTBMap` `TXHC` | 3 口（`HS01@1`、`SS01@2`、`SS02@3`） | **5 口**（额外 `SS03@4`、`SS04@5`） |
| boot-args | 见 §7 | 多一个 **`TSC_sync_margin=0`**（CpuTscSync 的防 panic 选项） |
| 其余（kext / Block / Tools / SMBIOS） | 相同 | 相同（蓝牙保留 **FixA2DP**，`-btlfxa2dpcheck`） |

> `EFI-Tahoe-83WW/` **没有**加入核显驱动相关的东西（`XeGfxIntelFB.kext`、`SSDT-DGPU-HYB.aml`、`-nmintelfboff`、`nvfbhidpi=1`、`nvmaxbpc=12`）。本机内屏由独显输出，这套只影响 iGPU/HDMI 音频等场景。

---

## 4. 83WW 变体的来源与验证状态

- 来源：一份**同机型、已在 83WW 上实测可用**的 EFI（触控板与雷电口 USB 3.2 均正常），其关键改动就是本页 §2 的两条 PC02 补丁 + `APIC-CPU24`；
- 本仓库的处理：以 `EFI-Tahoe/` 为底，套用上述 ACPI 改动与 5 口 USB 映射，**去掉核显部分**，保留我们的蓝牙 A2DP 修复、`Kernel>Block`（`IONDRVSupport` / `AppleEthernetRL`）、`NullMothSafe` 工具、`MacBookPro16,2`；
- **状态：尚未实机验证**（2026-11-09 整理，等待在 83WW 上测试）。

### 首次在 83WW 上启动的注意事项

1. **保留 `-v`**，方便看是停在哪一步；
2. 如果卡在 `APIC` 相关或 CPU 识别异常：先停用 `ACPI > Add > APIC-CPU24.aml` 再试（固件 APIC 没被删掉时会出现两张 APIC 表）；
3. 如果卡在 `\_SB.UBTC._INI` 之类：说明这台机器的 83WW 表结构与来源机不同，把 `ACPI > Patch` 里的 `83F5 PC02 declaration before scope (83WW)` 停用，只保留第二条 `83WW PC02 scope (I2C devices) unconditional`；
4. 只要触控板 + 外放**同时**可用，就说明 `PC02` 已经正确就位（两者都挂在它下面）。

---

## 5. 回滚 / 切换

- 78WW ↔ 83WW：**整份 `EFI` 目录替换**（不是只换 config），因为 `ACPI/` 里的文件集合不同（有无 `DSDT.aml`、有无 `APIC-CPU24.aml`）；
- 换完建议进 OpenCore 菜单做一次 **`Reset NVRAM`**；
- BIOS 升级/回退后，重新确认：Secure Boot = Disabled、VT-d 相关按 README 第 6 节、**Thunderbolt Security = No Security 或 SL1**。

---

## 6. 历史尝试记录（为什么不再试"通用补丁"）

| 时间 | 尝试 | 结果 |
| --- | --- | --- |
| 2026-11-02 | 83WW + 78WW 预打补丁 DSDT + 配置层 PC02 补丁 | `\_SB.UBTC._INI` / `UBSC` 连锁，**卡死** |
| 2026-11-02 | 83WW + 强制 `TPD0._STA = 0x0F` | 能进系统，但 **USB-C 口状态被破坏**（U 盘不识别） |
| 2026-11-05 | 83WW + 自建 `SSDT-TPD1`（`\_SB.PC02.I2C1` 下新设备） | `Scope` 引用触发 PC02 子树，**雷电 USB 3.2 又失效** |
| 2026-11-09 | 78WW + 83WW 配方（两条 PC02 + APIC 替换） | **开不了机**，见 §2 的 `UBTC` 连锁 |

结论：**`PC02` 能不能打开，由 BIOS 版本决定子树内容；不是补丁写法问题。** 78WW 走 DSDT，83WW 走补丁，两套并存。
