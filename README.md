# 🎣 Fake "Zoom Update" MSI → ScreenConnect RAT Deployment

![Threat Level](https://img.shields.io/badge/threat%20level-medium-yellow)
![Type](https://img.shields.io/badge/type-RMM%20abuse%20%2F%20RAT-orange)
![TLP](https://img.shields.io/badge/TLP-CLEAR-white)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Status](https://img.shields.io/badge/status-active%20research-brightgreen)

> Educational, defensive-security threat intelligence writeup documenting an obfuscated BAT/PowerShell dropper chain that installs a legitimate remote-access tool (ScreenConnect) reconfigured to give an attacker full remote control, delivered via a fake "Zoom Update" lure hosted on a typosquatted SharePoint-lookalike domain.

---

## ⚠️ Disclaimer

This repository exists for **educational, malware-analysis, and defensive-security purposes only**.
No functional malicious payload or working C2 client is included or reproduced here.
All indicators are provided to support detection engineering and threat hunting — **not** to enable reuse.
Do not execute anything from this repo. Do not visit the listed domains. All network indicators are defanged.

---

## 📌 Executive Summary

| | |
|---|---|
| **Campaign type** | Trojanized software update → RMM tool abuse (initial access) |
| **Lure** | Fake "Zoom" update package |
| **Delivery** | Obfuscated `.bat` loader → dynamically generated PowerShell → silent MSI install |
| **Final payload** | Legitimate, unmodified **ScreenConnect Client** installer, reconfigured with attacker infrastructure |
| **Attacker C2** | `relay.hochoukisenmontenmoriyamas[.]click:8041` |
| **Sophistication** | Low–Medium (2/5) — commodity dropper kit, legitimate RMM abuse |
| **Primary risk** | Full remote desktop control + persistence, not automated data theft |

Two near-identical `.bat` loader variants were recovered during analysis, both self-elevating via UAC and both downloading the same payload from the same infrastructure. Static analysis of the final MSI confirmed it is the **genuine, unmodified ScreenConnect (ConnectWise Control) installer** — reconfigured via install-time parameters to connect to attacker-controlled relay infrastructure. This is a classic **"RMM-as-a-RAT"** access-broker pattern: no custom malware code, just a signed legitimate tool with malicious configuration.

> **Note:** only the deobfuscated/clear version of the loader is included in this repository, for readability and to avoid distributing a directly copy-pasteable obfuscated dropper. The obfuscation differences between the two variants encountered are described below for reference.

> **Note:** the `Zoom_Update_V0226.msi` payload itself is also included in this repository, password-protected (`infected`) inside a zip archive, for researchers who want to reproduce the static/dynamic analysis. Do not extract or run it outside an isolated VM/sandbox.

---

## 🧬 Infection Chain

```mermaid
flowchart TD
    A[".bat loader obtained/executed"] --> B{"Already elevated?<br/>(arg == 'hidden')"}
    B -- No --> C["Self-relaunch via<br/>Start-Process -Verb RunAs<br/>(UAC prompt shown)"]
    C --> B
    B -- Yes --> D["Generate randomly-named<br/>.ps1 in %TEMP%"]
    D --> E["Download Zoom_Update_V0226.msi<br/>from fake SharePoint domain"]
    E --> F["Silent install:<br/>msiexec /quiet /norestart"]
    F --> G["ScreenConnect Client<br/>service installed"]
    G --> H["Beacons to attacker relay server"]
    H --> I["Attacker has full<br/>remote desktop access"]
    D --> J["Cleanup: temp .ps1 / .msi deleted"]
```

---

## 🧱 Stage 1 — The Obfuscated BAT Loader

Two variants of the same loader were recovered — same campaign, re-obfuscated to evade hash-based detection:

```mermaid
flowchart LR
    subgraph V1["Variant 1"]
        direction TB
        A1["arg check: ('hid'+'den')<br/>string-split obfuscation"] --> A2["temp files: t_*.ps1 / s_*.msi"]
        A2 --> A3["URL built from 3 split vars"]
    end
    subgraph V2["Variant 2"]
        direction TB
        B1["arg check: 'hidden'<br/>plain text"] --> B2["temp files: sc_task_*.ps1 / setup_*.msi"]
        B2 --> B3["URL as single string"]
    end
    A3 -.->|"identical C2 + payload"| C[("zoom-us02web-us<br/>.sharepoint-externals.com<br/>/j/98765432101/<br/>Zoom_Update_V0226.msi")]
    B3 -.->|"identical C2 + payload"| C
```

**Behavior:**
1. **Self-elevation** — checks its own argument; if not `"hidden"`, relaunches itself via `Start-Process -Verb RunAs`, triggering the Windows UAC prompt
2. **Dynamic script generation** — writes a randomly-named `.ps1` to `%TEMP%` at runtime (evades static file signatures)
3. **Fake SharePoint domain** — downloads the MSI from a typosquatted domain impersonating Microsoft SharePoint (`sharepoint-externals.com`)
4. **Silent MSI install** — `msiexec /i ... /quiet /norestart /L*v <logfile>`
5. **Anti-forensics cleanup** — deletes the generated `.ps1` and downloaded `.msi` after execution

| MITRE ATT&CK | Technique |
|---|---|
| T1548.002 | Abuse Elevation Control Mechanism: Bypass UAC |
| T1036.005 | Masquerading: Match Legitimate Name or Location |
| T1218.007 | System Binary Proxy Execution: Msiexec |
| T1105 | Ingress Tool Transfer |
| T1070.004 | Indicator Removal: File Deletion |

---

## 📦 Stage 2 — The Payload: Legitimate ScreenConnect, Reconfigured

Static analysis of the MSI (via `lessmsi`) confirmed this is the **genuine, unmodified ScreenConnect Client installer** — not a fork or patched binary. The abuse is entirely in the configuration, not the code.

**Key MSI properties recovered:**

| Property | Value |
|---|---|
| Manufacturer | ScreenConnect Software |
| ProductName | ScreenConnect Client (be1534bbe323c228) |
| ProductVersion | 24.3.7.9067 |
| ProductCode | `{C84F5988-7F52-A155-E292-DE9E64BA3437}` |
| UpgradeCode | `{E91251D9-DEE3-0FDB-BE15-34BBE323C228}` |

**The critical parameter — `SERVICE_CLIENT_LAUNCH_PARAMETERS`:**
```
?e=Access&y=Guest&h=relay.hochoukisenmontenmoriyamas[.]click&p=8041&k=<session key>
```
This single string configures the client to phone home to the attacker's own ScreenConnect relay/panel, using an attacker-specific instance ID (`be1534bbe323c228`).

**MSI Custom Actions observed** (`CustomAction` table) — these match the standard, official ScreenConnect installer structure (service install/config, process termination for updates, client launch). No custom/injected code was found; the executable payload itself is stock ScreenConnect.

| MITRE ATT&CK | Technique |
|---|---|
| T1219 | Remote Access Software |
| T1036.005 | Masquerading (legitimate signed binary, malicious config) |

---

## 🎯 Why "It Doesn't Steal Anything Itself" Is the Wrong Takeaway

ScreenConnect has no built-in credential dumper, browser-cookie grabber, or keylogger. But it doesn't need one:

- **Full interactive desktop control** — the operator can manually browse to and exfiltrate anything: saved browser sessions, password manager vaults, documents
- **Built-in file transfer** — no automation needed, the operator just drags and drops
- **Remote shell access** — the operator can launch any secondary tool (credential dumpers, ransomware, lateral movement frameworks) manually, once inside
- **Persistent Windows service** — unlike a one-shot stealer, the access stays open until removed

This is an **access broker tool**: the real damage happens *after* install, driven by a human operator, not by the installer itself. This pattern is frequently seen as a precursor to ransomware or manual data theft in documented incidents.

---

## 🚨 Indicators of Compromise (IOCs)

> All network indicators below are defanged.

| Type | Value |
|---|---|
| SHA256 (MSI) | `3A29D4F3C9A914FA31C854C32629B0B32C417AABAEDE35396FFEFBEF4F7C5809` |
| MD5 (MSI) | `4F27900F71125CD74BC3157153EB548B` |
| Payload filename | `Zoom_Update_V0226.msi` |
| Staging domain | `zoom-us02web-us[.]sharepoint-externals[.]com` |
| Staging URL | `hxxps://zoom-us02web-us[.]sharepoint-externals[.]com/j/98765432101/Zoom_Update_V0226.msi` |
| **C2 / relay server** | `relay.hochoukisenmontenmoriyamas[.]click:8041` |
| Attacker instance ID | `be1534bbe323c228` |
| ScreenConnect ProductCode | `{C84F5988-7F52-A155-E292-DE9E64BA3437}` |
| Temp file patterns | `%TEMP%\t_*.ps1`, `%TEMP%\s_*.msi`, `%TEMP%\sc_task_*.ps1`, `%TEMP%\setup_*.msi` |
| Installed service name | `ScreenConnect Client (be1534bbe323c228)` |

---

## 🛡️ Detection

### YARA — BAT loader

```yara
rule Dropper_BAT_FakeZoomUpdate_UACBypass_v2
{
    meta:
        description = "Detects BAT dropper family using UAC self-elevation and fake Zoom MSI installer - covers obfuscated and clear-text variants"
        malware_family = "FakeZoomInstaller"
        date = "2026-09-13"

    strings:
        $uac1 = "-Verb RunAs" ascii wide
        $uac2 = "RunAs" ascii wide
        $uac3 = /\(\s*'hid'\s*\+\s*'den'\s*\)/ ascii wide
        $uac4 = "\"hidden\"" ascii wide

        $c2_domain = "sharepoint-externals.com" ascii wide nocase
        $c2_full = "zoom-us02web-us" ascii wide nocase
        $payload_name = "Zoom_Update_V0226.msi" ascii wide nocase
        $payload_path = "/j/98765432101/" ascii wide

        $msi1 = "/quiet /norestart" ascii wide
        $msi2 = "msiexec" ascii wide nocase
        $msi3 = "/L*v" ascii wide

        $dl1 = "System.Net.WebClient" ascii wide
        $dl2 = "DownloadFile" ascii wide

        $struct1 = "EnableDelayedExpansion" ascii
        $struct2 = "PassThru" ascii wide
        $struct3 = /del \/f \/q .*\.ps1/ ascii wide
        $struct4 = /del \/f \/q .*\.msi/ ascii wide

    condition:
        uint16(0) != 0x5A4D and
        (
            ($c2_domain and $c2_full and $payload_name)
            or
            (1 of ($uac*) and 2 of ($msi*) and all of ($dl*) and 2 of ($struct*))
        )
}
```

### YARA — Network IOC (payload-agnostic)

```yara
rule Network_IOC_FakeZoomInstaller_C2
{
    meta:
        description = "Matches exact malicious infrastructure regardless of loader wrapper"
        type = "network_ioc"

    strings:
        $url_full = "https://zoom-us02web-us.sharepoint-externals.com/j/98765432101/Zoom_Update_V0226.msi" ascii wide

    condition:
        $url_full
}
```

### Detection ideas (SOC / EDR)

- Alert on `msiexec.exe` spawned as a child of `powershell.exe`, itself a child of `cmd.exe`, with the MSI path under `%TEMP%`
- Alert on `Start-Process ... -Verb RunAs` originating from a `.bat`/`.cmd` script re-invoking itself
- Monitor for ScreenConnect service installs where `SERVICE_CLIENT_LAUNCH_PARAMETERS` points to a relay host not on your organization's approved ScreenConnect allowlist
- Flag DNS/network requests to `*.click` TLD domains combined with ScreenConnect relay traffic on non-standard ports

---

## 📊 Sophistication Assessment

**Score: 2 / 5 (Low–Medium)**

| Factor | Assessment |
|---|---|
| Obfuscation | Trivial (string concat, or none at all in variant 2) |
| Payload encryption/packing | None |
| Anti-VM / anti-sandbox | None observed |
| C2 infrastructure | Static, reused across variants — no DGA/rotation |
| Domain quality | Fairly crude typosquat, human-noticeable |
| Persistence | None in the loader itself (payload provides persistence via Windows service) |
| Social engineering quality | Well executed (Zoom + SharePoint lure is coherent for corporate targets) |
| Payload choice | Smart — reuses a signed, trusted RMM tool instead of custom malware |

**Conclusion:** likely a **commodity dropper kit**, reused by a moderately-skilled operator rather than a custom build from an advanced actor. The social-engineering design (fake update, fake SharePoint host) is more mature than the loader's software engineering.

---

## 📚 References

- ScreenConnect/RMM abuse as an initial access vector is a documented pattern across multiple public vendor threat reports, frequently observed as a precursor to ransomware or manual data theft
- MalwareBazaar submission guidelines: https://bazaar.abuse.ch/

---

## 🤝 Contributing

Found a related sample, a new variant, or additional infrastructure tied to this campaign? Open an issue or PR with the hash and any new IOCs — please keep all samples password-protected (`infected`) if attached, and defang all URLs/domains.

---

*This research is shared under TLP:CLEAR for the benefit of the defensive security community.*
