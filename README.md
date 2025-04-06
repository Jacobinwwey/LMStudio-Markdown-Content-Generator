# Multi-LLM Markdown Content Generator

A PowerShell script that automatically fills blank markdown files with comprehensive content using various Large Language Model (LLM) providers (including local models like LM Studio/Ollama and cloud APIs like OpenAI, Anthropic, Google, etc.). The script can also perform web searches to gather information before generating content.

## Features

- **Multi-LLM Support**: Works with LM Studio, Ollama, DeepSeek, OpenAI, Anthropic, Google, Mistral, and Azure OpenAI.
- **`.env` Configuration**: Centralized configuration for API keys, endpoints, and behavior via a `.env` file.
- **Automatic Content Generation**: Processes blank markdown files containing only a header matching the filename.
- **Web Search Integration (Optional)**: Gathers information from DuckDuckGo (prioritizing Wikipedia) before generating content.
- **Intelligent File Processing**: Validates files based on filename/header similarity and emptiness.
- **Robust Error Handling**: Implements retry mechanisms with exponential backoff for API calls and web requests.
- **Enhanced Logging**: Detailed logging for operations, retries, timeouts, and errors.
- **Scheduling Capabilities**: Configurable start delay and execution timeout.
- **Flexible Configuration**: Customizable LLM provider, model, temperature, tokens, search behavior, file paths, etc.
- **Archive Service Fallbacks**: Attempts Internet Archive, archive.today, and Google Cache if direct web access fails.
- **Destination Management**: Moves or copies processed files to a specified directory based on `.env` settings.
- **Mermaid Formatting Fixes**: Automatically attempts to fix common Mermaid syntax issues in generated files.

## Requirements

- **PowerShell 7+**: Install from [Microsoft Docs](https://aka.ms/install-powershell) or using `winget install --id Microsoft.Powershell --source winget`.
- **LLM Access**:
    - **Local**: LM Studio or Ollama installed and running with a loaded model.
    - **Cloud**: API keys for your chosen provider(s) (DeepSeek, OpenAI, Anthropic, Google, Mistral, Azure OpenAI).
- **Internet Connection**: Required for web search (if enabled) and cloud LLM APIs.
- **`.env` File**: A configuration file named `.env` in the script's directory.

## Installation

1. **Install PowerShell 7+**
   ``` powershell
   winget install --id Microsoft.Powershell --source winget


2. **Install LM Studio**
   
2. **Set up Local LLM (if using LM Studio or Ollama)**
   - **LM Studio**: Download from [LM Studio's website](https://lmstudio.ai/), install, download a model, and start the local server (usually on port 1234).
   - **Ollama**: Install from [Ollama's website](https://ollama.com/), pull a model (e.g., `ollama pull llama3`), ensure the Ollama service is running (usually on port 11434).

3. **Download the Script Files**
   - Save `mcp_md_done.ps1`, `monitor_script.ps1`, and `mermaid.py` to your desired location.
   - Ensure `mcp_md_done.ps1` has execution permissions.

4. **Create and Configure `.env` File**
   - Create a file named `.env` in the same directory as the scripts.
   - Populate it with your desired configuration. See the **Configuration** section below for details. **This step is mandatory.**

## Configuration (`.env` File)

Create a file named `.env` in the script directory and add the following variables as needed. Lines starting with `#` are comments.

```dotenv
# --- Core Settings ---
# Choose your LLM provider: lmstudio, deepseek, openai, anthropic, google, mistral, azure_openai, ollama
LLM_PROVIDER=lmstudio

# --- API Keys & Endpoints (Fill only for the provider you use) ---
# LM Studio (Default: http://localhost:1234/v1/chat/completions)
LMSTUDIO_ENDPOINT=http://localhost:1234/v1/chat/completions
LMSTUDIO_API_KEY=EMPTY # Usually 'EMPTY' or 'lm-studio'

# DeepSeek (Get key: https://platform.deepseek.com/)
DEEPSEEK_ENDPOINT=https://api.deepseek.com/v1/chat/completions
DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
DEEPSEEK_MODEL=deepseek-reasoner

# OpenAI (Get key: https://platform.openai.com/api-keys)
OPENAI_ENDPOINT=https://api.openai.com/v1/chat/completions
OPENAI_API_KEY=YOUR_OPENAI_API_KEY
OPENAI_MODEL=gpt-4o

# Anthropic (Get key: https://console.anthropic.com/)
ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY
ANTHROPIC_MODEL=claude-3-5-sonnet-20240620 # Check for latest model

# Google (Get key: https://ai.google.dev/)
GOOGLE_API_KEY=YOUR_GOOGLE_API_KEY
GOOGLE_MODEL=gemini-1.5-flash-latest

# Mistral (Get key: https://console.mistral.ai/)
MISTRAL_ENDPOINT=https://api.mistral.ai/v1/chat/completions
MISTRAL_API_KEY=YOUR_MISTRAL_API_KEY
MISTRAL_MODEL=mistral-large-latest

# Azure OpenAI (Get from Azure Portal)
AZURE_OPENAI_ENDPOINT=YOUR_AZURE_ENDPOINT # e.g., https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=YOUR_AZURE_API_KEY
AZURE_OPENAI_MODEL=YOUR_DEPLOYMENT_NAME # e.g., gpt-4o
AZURE_OPENAI_API_VERSION=2024-02-01 # Check Azure docs for current version

# Ollama (Default: http://localhost:11434/api/chat)
OLLAMA_ENDPOINT=http://localhost:11434/api/chat
OLLAMA_MODEL=llama3 # Or any model you have pulled

# --- General LLM Behavior ---
TEMPERATURE=0.7 # Controls randomness (0.0 to 1.0)
MAX_TOKENS=16384 # Max tokens for the LLM response

# --- Web Search Configuration ---
SEARCH_ENABLED=true # Set to false to disable web search
SEARCH_MAX_RESULTS=10 # How many search results to retrieve
SEARCH_MAX_PAGES=5 # How many result pages to fetch content from
SEARCH_TIMEOUT=120 # Max seconds for the entire search + fetch operation
SEARCH_SHOW_PROGRESS=true # Show progress bar during fetching

# --- File Handling ---
# Path where processed markdown files will be moved or copied
OUTPUT_DESTINATION_PATH=E:\Knowledge\Study\dp_know\Processed_MD
# Set to false to copy files instead of moving them
OUTPUT_MOVE_PROCESSED=true

# --- Scheduling ---
# Delay in hours before the script starts processing files (e.g., 0.5 for 30 mins)
SCHEDULE_START_DELAY_HOURS=0.0001
# Max hours the script will run in a single cycle before pausing (e.g., 8)
SCHEDULE_TIMEOUT_HOURS=10000
# Interval in seconds for internal checks (usually leave as default)
CHECK_INTERVAL=30

# --- Debugging ---
DEBUG_LOG_REQUESTS=true # Log API request details
DEBUG_SAVE_JSON_DUMPS=true # Save intermediate search/summary results to files
DEBUG_SHOW_FULL_ERRORS=true # Display more detailed error messages

# --- Python Integration (for mermaid.py) ---
# Optional: Specify the path to your Python executable if not in PATH
# PYTHON_EXE=C:\Python311\python.exe
```

## Usage

1.  **Start Local LLM Server (if applicable)**
    - If using `lmstudio` or `ollama`, ensure the respective server is running and the model specified in `.env` is loaded/available.
2.  **Configure `.env`**
    - Ensure your `.env` file is created and correctly configured with your chosen `LLM_PROVIDER`, API keys/endpoints, and other settings.
3.  **Prepare Markdown Files**
    - Create markdown files (`.md`) in the script directory.
    - Each file should contain **only one line**: a header matching the desired topic (e.g., the file `Heat Transfer.md` should contain only `# Heat Transfer`).
4.  **Run the Script**

    ```powershell
    # Run the main script directly (will process files and exit)
    .\mcp_md_done.ps1

    # Recommended: Use the monitor script for continuous processing and error recovery
    # Requires running PowerShell as Administrator
    .\monitor_script.ps1

    # Optional: After processing, run the Python script to render Mermaid diagrams
    # Requires Python and necessary libraries (see mermaid.py comments)
    python .\mermaid.py
    ```


## How It Works

1.  **Load Configuration**: Reads settings from the `.env` file.
2.  **Scan Directory**: Finds `.md` files in the current directory.
3.  **Validate Files**: Checks each file to ensure it:
    -   Is not already processed (doesn't contain the generated footer).
    -   Has a filename similar to its header content (using Jaccard similarity).
    -   Contains only the header line (is effectively empty otherwise).
4.  **Process Valid Files**: For each valid file:
    -   **(Optional) Web Search**: If `SEARCH_ENABLED=true`, performs a DuckDuckGo search using the filename as the query.
    -   **(Optional) Fetch Content**: Retrieves content from the top search result URLs (up to `SEARCH_MAX_PAGES`), attempting archive services if direct access fails.
    -   **(Optional) Summarize**: Uses the configured LLM to summarize the fetched web content.
    -   **Generate Content**: Sends a structured prompt (including the web summary, if available) to the configured LLM API (`LLM_PROVIDER`).
    -   **Write Content**: Appends the LLM's response to the markdown file, adding a standard footer.
    -   **Fix Mermaid**: Checks and potentially corrects Mermaid syntax within the generated content.
    -   **Move/Copy File**: Moves or copies the processed file to `OUTPUT_DESTINATION_PATH` based on `OUTPUT_MOVE_PROCESSED`.
5.  **Scheduling**: Applies start delay and cycle timeouts as configured in `.env`. The `monitor_script.ps1` handles restarting the main script if it exits unexpectedly.

## Troubleshooting

-   **LLM Connection Issues**:
    -   Verify the `LLM_PROVIDER` in `.env` is correct.
    -   Ensure the corresponding `*_ENDPOINT` and `*_API_KEY` (or local server) are correctly configured and accessible.
    -   Check network connectivity.
    -   For local models (LM Studio/Ollama), ensure the server is running and the specified model is loaded/available.
-   **API Key Errors**: Double-check that the API keys in `.env` are correct and have sufficient permissions/credits.
-   **Search Failures**: Web search might fail due to network issues, timeouts (`SEARCH_TIMEOUT`), or websites blocking access. Try disabling search (`SEARCH_ENABLED=false`) or reducing `SEARCH_MAX_PAGES`.
-   **File Processing Issues**:
    -   Check `Error_*.json` files in the script directory for errors related to specific file processing.
    -   If using `monitor_script.ps1`, check `monitor_log.txt` for monitor-related errors or script exit codes.
-   **Permissions**: `monitor_script.ps1` requires running PowerShell as Administrator.

## Example Output

The script generates markdown content typically including:

-   Comprehensive analysis of the topic based on the LLM's knowledge and optional web search summary.
-   Mathematical formulas in LaTeX format (`$$...$$`).
-   Tables for data presentation.
-   Mermaid diagrams (` ```mermaid ... ``` `) for visual representation.
-   References section (if provided by the LLM).

Each processed file includes a footer like this:

```markdown
# Generated by [LLM Provider Name] LLM
**Model**: [Model Name Used]
**Timestamp**: YYYY-MM-DD HH:MM:SS
```

## License

This project follows the MIT license, see the LICENSE file for details.

## Contact

jacob.hxx.cn@outlook.com
```