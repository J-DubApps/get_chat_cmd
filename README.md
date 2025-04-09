# get-chat-cmd-bash: AI Command Generator for Bash

<img 
  src="https://raw.githubusercontent.com/J-DubApps/get_chat_cmd/main/get_chat_cmd.gif" 
  alt="Animated GIF" 
  width="600" 
  height="350">

Inspired by my PowerShell "**get-chat-cmd**" project [**here**](https://github.com/J-DubApps/get-chat-cmd).

**Generate bash commands from natural language using AI APIs directly from your terminal**. This project provides bash functions that interact with OpenRouter, OpenAI, Anthropic, and locally-hosted AI models (like those served by LM Studio or Ollama).

## Features

-   **Multiple AI Providers**: Supports OpenRouter, OpenAI, Anthropic, and locally-hosted models.
-   **Bash-Idiomatic**: Designed for standard bash environments (Linux, macOS, WSL - only tested so far on Ubuntu 24.04 LTS).
-   **Natural Language Input**: Describe the command you need in plain English.
-   **Clipboard Integration**: Automatically copies the generated command to your clipboard (optional, requires `xclip`, `pbcopy`, or `clip.exe`).
-   **Configurable**: Use a configuration file for API keys and settings.
-   **Minimal Dependencies**: Primarily uses standard bash features and common utilities (`curl`/`wget`, `jq`/`python`).

## Usage limitations

***NOTE***: you **must** have *your own* API keys with all 3 AI providers to use all features, as-written.  If you are new to using API calls in the bash terminal, info on obtaining API keys is below. You can also choose to *only* use a single AI provider ***or*** make API calls to your own ***locally-hosted*** Chat model (via `get-chat-local` which supports LM Studio and Ollama). 

If you do not know how to locally-host your own Chat models and don't like the idea of giving "big AI" your money: might I suggest [**Openrouter.ai**](https://openrouter.ai) which is a fantastic gateway for [many different free and paid models](https://openrouter.ai/models), and their pricing for "big AI models" is usually resonable.

This solution is intented to run with most major Linux distros and MacOS, but so far I have only tested with Ubuntu 24.04 LTS. Engineers & Vibe-Coders listen-up: see disclaimer below or the license-agreement. This code is NOT tested in, or intended for, any prod environment.


## Installation

1.  **Download the Script**:
    ```bash
    # Choose a location, e.g., ~/.local/bin or ~/scripts
    mkdir -p ~/scripts
    cd ~/scripts
    # Download using curl
    curl -o ai_bash_commands.sh https://raw.githubusercontent.com/J-DubApps/get_chat_cmd/main/ai_bash_commands.sh 
    # OR download using wget
    # wget -O ai_bash_commands.sh https://raw.githubusercontent.com/J-DubApps/get_chat_cmd/main/ai_bash_config.sh.example/ai_bash_commands.sh
    chmod +x ai_bash_commands.sh 
    ```
    <!--
    *(Note: Replace `YOUR_USERNAME/get-chat-cmd-bash` with the actual repository path once created)*
    -->
    
3.  **Source the Script**:
    Add the following line to your `~/.bashrc` or `~/.zshrc` file (**note** on MacOS the default is Zshell (zsh) may use `~/.zprofile` instead of `~/.zshrc`)
    
    ```bash
    source ~/scripts/ai_bash_commands.sh
    ```
    
    (adjust the path above if you downloaded the .sh file elsewhere)  
   
    Restart your shell or run `source ~/.bashrc` (or `source ~/.zshrc`).

5.  **Configure API Keys**:
    -   Copy the example configuration file:
        ```bash
        mkdir -p ~/.config
        # Download using curl
        curl -o ~/.config/ai_bash_config.sh https://raw.githubusercontent.com/J-DubApps/get_chat_cmd/main/ai_bash_config.sh.example
        # OR download using wget
        # wget -O ~/.config/ai_bash_config.sh https://raw.githubusercontent.com/J-DubApps/get_chat_cmd/main/ai_bash_config.sh.example
        ```
    -   Edit `~/.config/ai_bash_config.sh` and add your API keys.
    -   Secure the file: `chmod 600 ~/.config/ai_bash_config.sh`

6.  **Install Dependencies (Optional but Recommended)**:
    -   **jq**: For robust JSON parsing.
        ```bash
        # Debian/Ubuntu
        sudo apt update && sudo apt install jq -y
        # Fedora/CentOS/RHEL
        sudo dnf install jq -y 
        # macOS (using Homebrew)
        brew install jq
        ```
    -   **Clipboard Tools**: For automatic copying.
        -   **Linux (X11)**: `xclip`
            ```bash
            # Debian/Ubuntu
            sudo apt update && sudo apt install xclip -y
            # Fedora/CentOS/RHEL
            sudo dnf install xclip -y
            ```
        -   **macOS**: `pbcopy` (usually pre-installed)
        -   **WSL**: `clip.exe` (usually available)

## Usage

Once installed and configured, you can use the functions directly in your terminal:

```bash
# Using OpenRouter (Default: quasar-alpha)
get_chat_cmd1 "List all running processes sorted by memory usage"

# Using OpenAI (Default: gpt-4o-mini)
get_chat_cmd2 "Find files modified in the last 24 hours"

# Using Anthropic (Default: claude-3-haiku)
get_chat_cmd3 "List all running processes"

# Using Local Model
get_chat_local "Show disk usage for the current directory" 
```

The generated command will be displayed in the terminal and (if clipboard tools are available and enabled) copied to your clipboard.

## TODO

-   Implement core utility functions (API requests, JSON parsing, clipboard, dependency checks).
-   Implement provider-specific functions (`get_chat_cmd1`, `get_chat_cmd2`, `get_chat_cmd3`, `get_chat_local`).
-   Refine prompt engineering for better accuracy.
-   Add comprehensive error handling.
-   Add testing across different environments.

## Obtaining API Keys

You can create accounts and obtain API keys inexpensively from these links:

 [https://openrouter.ai/keys](https://openrouter.ai/keys)  
 [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)  
 [https://console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)

## Disclaimer

The functions provided in this repository are intended to assist in generating PowerShell commands through AI models in a *test environment only* and they are not intended for use in any production scenario. **Users are responsible for reviewing and understanding the commands generated *before* execution**. **The author assumes *zero liability* for unintended consequences resulting from the use or misuse of these functions, including but not limited to poor-prompting which might create undesired command outputs**. **Additionally, the author is not responsible for *any* API usage charges incurred while using these functions**. **Users should monitor their API usage to avoid unexpected costs**.  

## License

This project is licensed under the MIT License: 

MIT License

Copyright (c) 2025 Julian West

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.  

For more details, refer to the [MIT License](https://opensource.org/licenses/MIT). [oai_citation_attribution:0‡Wikipedia](https://en.wikipedia.org/wiki/MIT_License?utm_source=chatgpt.com)
