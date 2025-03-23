# README.md for LMStudio Markdown Content Generator

I'll create a comprehensive README.md file that explains the functionality, installation process, and usage instructions for the monitoring script.

# LMStudio Markdown Content Generator

## Overview

This project contains a PowerShell monitoring script that automatically restarts a content generation script (`mcp_md_done.ps1`) if it exits. The monitoring system ensures continuous operation of the content generation process with minimal manual intervention.

## Features

- Automatic monitoring and restarting of the main content generation script
- Configurable retry attempts and wait times between restarts
- Detailed logging of script execution status
- Graceful error handling

## Requirements

- Windows operating system
- PowerShell 7 (pwsh)
- Sufficient permissions to execute PowerShell scripts

## Installation

1. Clone or download this repository to your local machine
2. Ensure PowerShell 7 is installed on your system
   - You can download it from [Microsoft's GitHub repository](https://github.com/PowerShell/PowerShell/releases)
3. Verify that script execution is enabled on your system
   - Open PowerShell as Administrator and run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned`

## Configuration

The monitoring script (`monitor_script.ps1`) contains several configurable parameters:

- `$scriptPath`: Path to the main content generation script
- `$maxRetries`: Maximum number of restart attempts (default: 100000)
- `$waitTime`: Seconds to wait between restart attempts (default: 5)

You can modify these values directly in the script to suit your needs.

## Usage

### Starting the Monitoring Script

1. Open PowerShell 7
2. Navigate to the project directory
3. Execute the monitoring script:

```powershell
cd "your path to\LMStudio-Markdown-Content-Generator"
.\monitor_script.ps1
```

### Stopping the Monitoring Script

- Press `Ctrl+C` to stop the monitoring process
- The script will display a message and wait for a key press before exiting

## How It Works

The monitoring script operates as follows:

1. Initializes configuration parameters
2. Enters a loop that continues until the maximum retry count is reached
3. Starts the content generation script using PowerShell 7
4. Waits for the script to complete execution
5. Captures the exit code and logs the result
6. Waits for the configured time period
7. Restarts the script and increments the retry counter
8. Handles any errors that occur during execution

## Troubleshooting

### Common Issues

1. **Script Execution Policy Errors**
   - Solution: Ensure your PowerShell execution policy allows script execution

2. **Path Not Found Errors**
   - Solution: Verify that the path to the content generation script is correct

3. **Permission Issues**
   - Solution: Run PowerShell with appropriate permissions

### Logs

The monitoring script outputs detailed logs to the console, including:
- Start and stop events
- Retry attempts
- Exit codes
- Error messages

## License

[Include your license information here]

## Contact

[Include your contact information here]
```

This README.md provides a comprehensive guide to understanding, installing, and using the monitoring script. You can customize the License and Contact sections with your specific information.