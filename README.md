# LMStudio Markdown Content Generator

A PowerShell script that automatically fills blank markdown files with comprehensive content using LM Studio's local API. The script can also perform web searches to gather information before generating content.

## Features

- **Automatic Content Generation**: Processes blank markdown files with only a header
- **Web Search Integration**: Gathers information from the web before generating content
- **Intelligent File Processing**: Validates files based on filename/header similarity
- **Robust Error Handling**: Implements retry mechanisms with exponential backoff
- **Scheduling Capabilities**: Configurable execution timing through `$SCHEDULE_CONFIG`
- **Flexible Configuration**: Customizable API and search settings
- **Archive Service Fallbacks**: Attempts multiple sources when direct web access fails
- **Destination Management**: Moves processed files to a specified directory

## Requirements

- PowerShell 7+ (install from https://aka.ms/install-powershell)
- LM Studio with a running local model
- Internet connection (for web search functionality)

## Installation

1. **Install PowerShell 7+**
   ``` powershell
   winget install --id Microsoft.Powershell --source winget


2. **Install LM Studio**
   
   - Download from LM Studio's website
   - Install and set up a local model

   
3.**Download the Script**
   
   - Save the script to your desired location
   - Ensure it has execution permissions
     
## Configuration
The script uses several configuration hashtables that can be modified:

### API Configuration ($LMSTUDIO_CONFIG)
```powershell
$LMSTUDIO_CONFIG = @{
    BaseURL         = "http://localhost:1234/v1/chat/completions"  # Change to your port
    Model           = "local-model"
    SystemMessage   = "You are a scientific reasoning expert..."
    Temperature     = 0.7
    MaxTokens       = 16384
    # Other settings...
}
```


### Search Configuration ($SEARCH_CONFIG)
``` powershell
$SEARCH_CONFIG = @{
    EnableSearch    = $true    # Set to $ false to disable search
    ResultCount     = 10       # Maximum search results
    MaxPageSearch   = 10       # Maximum pages to analyze
    # Other settings...
}
```


### Scheduling Configuration ($SCHEDULE_CONFIG)
```powershell
$SCHEDULE_CONFIG = @{
    StartDelayHours = 0.0001   # Delay before starting
    TimeoutHours    = 10000    # Maximum runtime
    CheckInterval   = 30       # Seconds between checks
}
```


## Usage
1. Start LM Studio
   
   - Launch LM Studio
   - Load your preferred model
   - Start the local server (usually on port 1234)
2. Prepare Markdown Files
   
   - Create markdown files with only a header (e.g., # Topic Name )————for example: The content of "workload.md" is only one line:# workload
   - Place them in the directory where you'll run the script
3. Run the Script
   
   ``` powershell
   # Basic usage (processed files stay in current directory)
   .\mcp_md_done.ps1
   
   # Specify destination for processed files
   .\mcp_md_done.ps1 -DestinationPath "E:\Processed_Files"

## How It Works
1. The script scans the current directory for markdown files
   
2. It validates each file to ensure it:
   - Has only a header
   - Has a filename similar to the header content
   - Doesn't contain existing content
     
3. For each valid file, it:
   - Performs a web search (if enabled) to gather information
   - Generates comprehensive content using LM Studio's API
   - Adds the generated content to the file
   - Moves the processed file to the destination directory
     
## Troubleshooting
- LM Studio Connection Issues : Ensure LM Studio is running and the server is started
- Port Configuration : Verify the port in $LMSTUDIO_CONFIG.BaseURL matches your LM Studio server
- Search Failures : Web search may fail due to rate limiting; try disabling search or reducing frequency
- File Processing Issues : Check log files generated in the script directory
## Advanced Usage
### Custom System Message
Modify the SystemMessage in $LMSTUDIO_CONFIG to change the AI's behavior:

```powershell
$LMSTUDIO_CONFIG = @{
    # Other settings...
    SystemMessage = "You are a technical documentation expert..."
    # Other settings...
}
   ```


### Disable Web Search
Set EnableSearch to $false in $SEARCH_CONFIG to skip the web search step:

``` powershell
$SEARCH_CONFIG = @{
    # Other settings...
    EnableSearch = $false
    # Other settings...
}
```

### Scheduled Execution
Adjust the $SCHEDULE_CONFIG parameters to control execution timing:

``` powershell
$SCHEDULE_CONFIG = @{
    StartDelayHours = 1        # Start after 1 hour
    TimeoutHours    = 48       # Run for up to 48 hours
    CheckInterval   = 60       # Check every minute
}
```


## Example Output
The script generates markdown content with:

- Comprehensive analysis of the topic
- Mathematical formulas in LaTeX format
- Tables for data presentation
- Mermaid diagrams for visual representation
- References section
Each processed file includes a footer with:

```plaintext
# Generated by LMStudio Reasoner
**Model**: local-model
**Timestamp**: YYYY-MM-DD HH:MM:SS
```

## License
This script is provided as-is with no warranty. Use at your own risk.