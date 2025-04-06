# README for Monitor Script (`monitor_script.ps1`)

## Overview

This PowerShell script (`monitor_script.ps1`) monitors the main Multi-LLM Markdown Content Generator script (`mcp_md_done.ps1`) and automatically restarts it if it exits unexpectedly. It provides enhanced logging, configuration loading from `.env`, and basic error diagnostics to ensure the content generation process runs reliably.

## Features

- **Automatic Restart**: Monitors `mcp_md_done.ps1` and restarts it upon exit.
- **`.env` Integration**: Loads configuration (like API endpoints) from the `.env` file used by the main script.
- **Endpoint Validation**: Checks the format of `LMSTUDIO_ENDPOINT` in `.env` and attempts to auto-correct if needed.
- **File Logging**: Logs monitoring activities, script starts/exits, and errors to `monitor_log.txt`.
- **Error Diagnostics**: Checks the exit code of `mcp_md_done.ps1` and reads the latest `Error_*.json` log file to provide basic diagnostic information (e.g., API endpoint errors).
- **Admin Privileges**: Runs the main script with elevated privileges (`-Verb RunAs`) if required by its operations.
- **Configurable Retries**: Set maximum restart attempts and wait time between attempts.

## Requirements

- **Windows Operating System**
- **PowerShell 7+ (`pwsh`)**: Required to run both the monitor and the main script.
- **Administrator Privileges**: The monitor script needs to be run as Administrator because it uses `-Verb RunAs` to launch the main script.
- **`.env` File**: A correctly configured `.env` file in the same directory (see `README.md` for the main script).
- **`mcp_md_done.ps1`**: The main content generation script must be present at the path specified within `monitor_script.ps1`.

## Installation & Setup

1.  **Ensure Requirements Met**: Verify PowerShell 7+ is installed and you have the `mcp_md_done.ps1` script and a configured `.env` file.
2.  **Configure Script Path**:
    -   Open `monitor_script.ps1` in a text editor.
    -   **Crucially, update the `$scriptPath` variable** to the correct full path of your `mcp_md_done.ps1` file.
    -   Optionally, update `$logFile` if you want the log stored elsewhere.
    ```powershell
    $scriptPath = "D:\path\to\your\LMStudio-Markdown-Content-Generator\mcp_md_done.ps1"
    $logFile = "D:\path\to\your\LMStudio-Markdown-Content-Generator\monitor_log.txt"
    ```
3.  **Set Execution Policy (if needed)**: If you haven't already, you might need to allow script execution. Open PowerShell **as Administrator** and run:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
    (Use `-Scope Process` for temporary permission if preferred).

## Configuration Parameters (Inside `monitor_script.ps1`)

-   `$scriptPath`: **(Required)** Full path to `mcp_md_done.ps1`.
-   `$maxRetries`: Maximum number of times the script will attempt to restart `mcp_md_done.ps1` (default: 100,000).
-   `$waitTime`: Seconds to wait between restart attempts (default: 5).
-   `$logFile`: **(Required)** Full path where the monitor log file (`monitor_log.txt`) will be created/appended.

## Usage

1.  **Open PowerShell 7 as Administrator**.
2.  Navigate to the directory containing `monitor_script.ps1`.
3.  Execute the script:
    ```powershell
    .\monitor_script.ps1
    ```
4.  The script will start logging to the console and the specified `$logFile`. It will then attempt to start `mcp_md_done.ps1`.
5.  Leave the monitor script running. It will automatically restart `mcp_md_done.ps1` if it closes, up to `$maxRetries` times.

### Stopping the Monitor

-   Press `Ctrl+C` in the PowerShell window where `monitor_script.ps1` is running.

## How It Works

1.  **Initialization**: Sets paths, retry limits, and wait times. Defines a logging function.
2.  **Log Start**: Writes a starting message to the log file and console.
3.  **Load `.env`**: Checks for `.env`, loads environment variables, and validates/fixes `LMSTUDIO_ENDPOINT` if present.
4.  **Monitoring Loop**:
    -   Starts `mcp_md_done.ps1` using `Start-Process pwsh -Verb RunAs`.
    -   Waits for `mcp_md_done.ps1` to exit using `WaitForExit()`.
    -   Logs the exit code.
    -   **Error Check**: If the exit code indicates an error (e.g., 1), it checks for the latest `Error_*.json` file created by `mcp_md_done.ps1` and logs its content, looking specifically for API endpoint issues.
    -   Increments the retry counter.
    -   Waits `$waitTime` seconds.
    -   Repeats until `$maxRetries` is reached or `Ctrl+C` is pressed.
5.  **Termination**: Logs when max retries are reached or if an error occurs within the monitor script itself.

## Troubleshooting

-   **Monitor Script Doesn't Start `mcp_md_done.ps1`**:
    -   **Permissions**: Ensure you are running `monitor_script.ps1` in PowerShell **as Administrator**.
    -   **Path Error**: Double-check that `$scriptPath` inside `monitor_script.ps1` points *exactly* to your `mcp_md_done.ps1` file.
    -   **PowerShell 7 Not Found**: Make sure `pwsh` (PowerShell 7+) is correctly installed and in your system's PATH.
-   **`mcp_md_done.ps1` Exits Immediately**:
    -   Check the `monitor_log.txt` file for the exit code and any error messages logged by the monitor.
    -   Check for `Error_*.json` files in the same directory for errors logged by `mcp_md_done.ps1` itself (e.g., invalid API keys, connection issues).
    -   Verify the `.env` file configuration is correct for the selected `LLM_PROVIDER`.
-   **Endpoint Validation Warning/Error**: If the monitor logs warnings about `LMSTUDIO_ENDPOINT`, ensure it's correctly formatted in your `.env` file (e.g., `http://localhost:1234/v1/chat/completions`).
-   **Log File Issues**: Ensure the path specified in `$logFile` is writable.

### Log Files

-   **`monitor_log.txt`**: Contains logs from the `monitor_script.ps1` itself (start/stop times, restarts, exit codes, basic error diagnostics).
-   **`Error_*.json`**: Created by `mcp_md_done.ps1` when it encounters a critical error during file processing. Contains details about the specific error.
-   **`Retry_*.log` / `Timeout_*.log`**: Created by `mcp_md_done.ps1` during API call retries or timeouts.
-   **(Debug) `Search_*.txt`, `Content_*.txt`, `Summary_*.txt`**: Created by `mcp_md_done.ps1` if `DEBUG_SAVE_JSON_DUMPS=true` in `.env`.

## License

This project follows the MIT license, see the LICENSE file for details.

## Contact

jacob.hxx.cn@outlook.com
```

This README.md provides a comprehensive guide to understanding, installing, and using the monitoring script. You can customize the License and Contact sections with your specific information.
