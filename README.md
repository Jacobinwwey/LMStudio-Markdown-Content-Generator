# Multi-LLM Markdown Content Generator

A PowerShell script that automatically fills blank markdown files with comprehensive content using various Large Language Model (LLM) providers (including local models like LM Studio/Ollama and cloud APIs like OpenAI, Anthropic, Google, etc.). The script can also perform web searches to gather information before generating content.

## Features

- **Multi-LLM Support**: Works with LM Studio, Ollama, DeepSeek, OpenAI, Anthropic, Google, Mistral, Azure OpenAI, and OpenRouter.
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
- **Adaptive Chunking**: Intelligently splits large content into manageable chunks for processing.
- **Token Management**: Configurable token limits to optimize LLM usage and prevent truncation.

## Requirements

- **PowerShell 7+**: Install from [Microsoft Docs](https://aka.ms/install-powershell) or using `winget install --id Microsoft.Powershell --source winget`.
- **LLM Access**:
    - **Local**: LM Studio or Ollama installed and running with a loaded model.
    - **Cloud**: API keys for your chosen provider(s) (DeepSeek, OpenAI, Anthropic, Google, Mistral, Azure OpenAI, OpenRouter).
- **Internet Connection**: Required for web search (if enabled) and cloud LLM APIs.
- **`.env` File**: A configuration file named `.env` in the script's directory.

## Installation

1. **Install PowerShell 7+**
   ``` powershell
   winget install --id Microsoft.Powershell --source winget

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
# Choose your LLM provider: lmstudio, deepseek, openai, anthropic, google, mistral, azure_openai, ollama, openrouter
LLM_PROVIDER=lmstudio

# --- API Keys & Endpoints (Fill only for the provider you use) ---
# LM Studio (Default: http://localhost:1234/v1/chat/completions)
LMSTUDIO_ENDPOINT=http://localhost:1234/v1/chat/completions
LMSTUDIO_API_KEY=EMPTY # Usually 'EMPTY' or 'lm-studio'
LMSTUDIO_MODEL=local-model

# DeepSeek (Get key: https://platform.deepseek.com/)
DEEPSEEK_ENDPOINT=https://api.deepseek.com/v1/chat/completions
DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY
DEEPSEEK_MODEL=deepseek-reasoner

# OpenAI (Get key: https://platform.openai.com/api-keys)
OPENAI_ENDPOINT=https://api.openai.com/v1/chat/completions
OPENAI_API_KEY=YOUR_OPENAI_API_KEY
OPENAI_MODEL=gpt-4o

# OpenRouter (Get key: https://openrouter.ai/keys)
OPENROUTER_ENDPOINT=https://openrouter.ai/api/v1/chat/completions
OPENROUTER_API_KEY=YOUR_OPENROUTER_API_KEY
OPENROUTER_MODEL=deepseek/deepseek-chat-v3-0324:free
OPENROUTER_FALLBACK_MODEL=mistralai/mistral-small-3.1-24b-instruct:free

# Anthropic (Get key: https://console.anthropic.com/)
ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY
ANTHROPIC_MODEL=claude-3-5-sonnet-20241022 # Check for latest model

# Google (Get key: https://ai.google.dev/)
GOOGLE_API_KEY=YOUR_GOOGLE_API_KEY
GOOGLE_MODEL=gemini-2.0-flash-exp

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

# --- Token Configuration ---
MAX_TOKENS=16384 # Max tokens for LLM response
MAX_CHUNK_SIZE=48000 # Max characters per content chunk
MIN_TOKEN_THRESHOLD=5000 # Min tokens for intermediate summaries
MAX_TOKEN_THRESHOLD=20000 # Max tokens for intermediate summaries

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
# Maximum number of processing cycles before exiting
SCHEDULE_MAX_CYCLES=1000

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
    - For LM Studio: Launch the application, load your model, and start the local server (Server tab → Start Server).
    - For Ollama: Ensure the service is running ( `ollama serve` ) and you've pulled your desired model ( `ollama pull llama3` ).
2.  **Configure `.env`**
    - Ensure your `.env` file is created and correctly configured with your chosen `LLM_PROVIDER`, API keys/endpoints, and other settings.
    - Double-check that the model names match exactly what your provider expects.
3.  **Prepare Markdown Files**
    - Create markdown files (`.md`) in the script directory.
    - Each file should contain **only one line**: a header matching the desired topic (e.g., the file `Heat Transfer.md` should contain only `# Heat Transfer`).
    - For best results, use descriptive and specific titles that clearly define the topic.
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
5.  **Advanced Usage Options**

- Batch Processing : Place multiple markdown files in the directory for sequential processing.
- Scheduled Operation : Use the `SCHEDULE_*` parameters to control when and how long the script runs.
- Search Customization : Adjust `SEARCH_*` parameters to control web search behavior and depth.
- Output Management : Configure `OUTPUT_*` parameters to determine where processed files are stored.

## How It Works

1.  **Load Configuration**: Reads settings from the `.env` file.
- Configures the selected LLM provider and its parameters.
- Sets up token limits, search behavior, and scheduling parameters.
2.  **Scan Directory**: Finds `.md` files in the current directory.
3.  **Validate Files**: Checks each file to ensure it:
    -   Is not already processed (doesn't contain the generated footer).
    -   Has a filename similar to its header content (using Jaccard similarity).
    -   Contains only the header line (is effectively empty otherwise).
    -   Meets other validation criteria (proper markdown format, etc.).
4.  **Process Valid Files**: For each valid file:
    -   **(Optional) Web Search**: If `SEARCH_ENABLED=true`, performs a DuckDuckGo search using the filename as the query.
        - Prioritizes authoritative sources like Wikipedia.
        - Collects up to `SEARCH_MAX_RESULTS` search results.
    -   **(Optional) Fetch Content**: Retrieves content from the top search result URLs (up to `SEARCH_MAX_PAGES`), attempting archive services if direct access fails.
        -   Uses multiple fallback methods if direct access fails:
            - Internet Archive (Wayback Machine)
            - archive.today
            - Google Cache
        -   Shows progress if `SEARCH_SHOW_PROGRESS=true` .
    -   (Optional) Content Processing : Handles large content intelligently:
        - Splits content into manageable chunks based on `MAX_CHUNK_SIZE` .
        - Generates intermediate summaries for each chunk.
        - Ensures token counts stay within `MIN_TOKEN_THRESHOLD` and `MAX_TOKEN_THRESHOLD` .
    -   **(Optional) Summarize**: Uses the configured LLM to summarize the fetched web content.
        - Creates a comprehensive summary that preserves technical details.
        - Maintains mathematical formulas in LaTeX format.
    -   **Generate Content**: Sends a structured prompt (including the web summary, if available) to the configured LLM API (`LLM_PROVIDER`).
        - Includes the web summary if available.
        - Uses provider-specific API parameters (temperature, max tokens, etc.).
        - Implements retry logic with exponential backoff for API failures.
    -   **Write Content**: Appends the LLM's response to the markdown file, adding a standard footer.
        - Adds a standard footer with LLM provider, model, and timestamp.
        - Ensures proper markdown formatting.
    -   **Fix Mermaid**: Checks and potentially corrects Mermaid syntax within the generated content.
        - Ensures proper opening and closing tags.
        - Validates diagram structure.
    -   **Move/Copy File**: Moves or copies the processed file to `OUTPUT_DESTINATION_PATH` based on `OUTPUT_MOVE_PROCESSED`.
        - Behavior controlled by `OUTPUT_MOVE_PROCESSED` setting.
5.  **Scheduling**: Applies start delay and cycle timeouts as configured in `.env`. The `monitor_script.ps1` handles restarting the main script if it exits unexpectedly.
    - Waits `SCHEDULE_START_DELAY_HOURS` before beginning processing.
    - Runs for up to `SCHEDULE_TIMEOUT_HOURS` before pausing.
    - The `monitor_script.ps1` handles restarting the main script if it exits unexpectedly.
    - Limits total execution to `SCHEDULE_MAX_CYCLES` if specified.

## Advanced Features
### Multi-LLM Provider Support
The script supports multiple LLM providers through a unified interface, allowing you to:

- Switch between providers by changing a single setting ( `LLM_PROVIDER` ).
- Configure provider-specific parameters (endpoints, models, API keys).
- Use local models (LM Studio, Ollama) or cloud APIs (OpenAI, Anthropic, etc.).
- Leverage OpenRouter for access to multiple models through a single API.
### Intelligent Content Handling
- Adaptive Chunking : Automatically splits large content into manageable pieces.
- Progressive Summarization : Creates intermediate summaries for large documents.
- Token Management : Ensures content stays within token limits for each LLM provider.
- Error Recovery : Implements multiple fallback mechanisms for web content retrieval.
### Customizable Output
- Scientific Content : Optimized for technical and scientific content with LaTeX support.
- Diagram Generation : Creates Mermaid diagrams for visual representation.
- Structured Format : Consistent markdown formatting with sections, tables, and references.
- Mathematical Precision : Preserves mathematical formulas and technical details.

## Troubleshooting
### LLM Connection Issues
- Local Models (LM Studio/Ollama) :
  
  - Verify the server is running ( `http://localhost:1234` for LM Studio, `http://localhost:11434` for Ollama).
  - Ensure the specified model is loaded and available.
  - Check server logs for errors or resource limitations.
  - For LM Studio, verify the API is enabled in settings.
- Cloud APIs :
  
  - Verify API keys are correct and have sufficient permissions/credits.
  - Check for rate limiting or quota issues.
  - Ensure network connectivity to the API endpoint.
  - Verify the model name exactly matches what the provider expects.
### Search and Content Issues
- Search Failures :
  
  - DuckDuckGo may temporarily block automated requests. Try reducing `SEARCH_MAX_RESULTS` .
  - Network issues may prevent search. Check connectivity.
  - Try disabling search ( `SEARCH_ENABLED=false` ) if persistent issues occur.
- Content Retrieval Problems :
  
  - Some websites block automated access. The script attempts multiple fallbacks.
  - Reduce `SEARCH_MAX_PAGES` to limit the number of sites accessed.
  - Increase `SEARCH_TIMEOUT` for slow connections.
### Script Execution Problems
- Permission Issues :
  
  - `monitor_script.ps1` requires running PowerShell as Administrator.
  - Ensure write permissions to the script directory and `OUTPUT_DESTINATION_PATH` .
- Timeout Errors :
  
  - Increase `SEARCH_TIMEOUT` for slow web connections.
  - Check for very large files that may exceed processing capacity.
- API Errors :
  
  - Check `Error_*.json` files in the script directory for detailed error information.
  - Verify API configuration in `.env` file.
  - Some models have context length limitations. Adjust `MAX_TOKENS` accordingly.

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