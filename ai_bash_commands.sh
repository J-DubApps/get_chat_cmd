#!/bin/bash
#
# ai_bash_commands.sh
#
# Bash functions to generate shell commands from natural language using AI APIs.
# Supports OpenRouter, OpenAI, Anthropic, and locally-hosted models.
#

# --- Configuration ---
# Source the configuration file if it exists
CONFIG_FILE="${HOME}/.config/ai_bash_config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Configuration file not found: $CONFIG_FILE" >&amp;2
    echo "Please create it based on ai_bash_config.sh.example" >&amp;2
    # Optionally, define default placeholders or exit here
fi

# --- Dependencies Check ---

# Variables to store detected tools
_HTTP_CLIENT=""
_JSON_PARSER=""
_CLIPBOARD_CMD=""

# Function to check for required commands
_check_dependencies() {
    # Check for HTTP Client (curl or wget)
    if [[ -z "$PREFERRED_HTTP_CLIENT" ]]; then
        if command -v curl &> /dev/null; then
            _HTTP_CLIENT="curl"
        elif command -v wget &> /dev/null; then
            _HTTP_CLIENT="wget"
        else
            echo "Error: Neither curl nor wget found. Please install one." >&amp;2
            return 1
        fi
    elif [[ "$PREFERRED_HTTP_CLIENT" == "curl" ]] && command -v curl &> /dev/null; then
         _HTTP_CLIENT="curl"
    elif [[ "$PREFERRED_HTTP_CLIENT" == "wget" ]] && command -v wget &> /dev/null; then
         _HTTP_CLIENT="wget"
    else
        echo "Error: Preferred HTTP client '$PREFERRED_HTTP_CLIENT' not found or invalid." >&amp;2
        return 1
    fi

    # Check for JSON Parser (jq or python)
    if [[ -z "$PREFERRED_JSON_PARSER" ]]; then
        if command -v jq &> /dev/null; then
            _JSON_PARSER="jq"
        elif command -v python &> /dev/null || command -v python3 &> /dev/null; then
             # Check if python can import json
             local python_cmd
             python_cmd=$(command -v python3 || command -v python)
             if "$python_cmd" -c "import json" &> /dev/null; then
                _JSON_PARSER="python"
             fi
        fi
        if [[ -z "$_JSON_PARSER" ]]; then
             echo "Warning: Neither jq nor Python with json module found. JSON parsing might fail." >&amp;2
             # Allow script to continue, but parsing will likely fail
        fi
    elif [[ "$PREFERRED_JSON_PARSER" == "jq" ]] && command -v jq &> /dev/null; then
        _JSON_PARSER="jq"
    elif [[ "$PREFERRED_JSON_PARSER" == "python" ]] && (command -v python &> /dev/null || command -v python3 &> /dev/null); then
        local python_cmd
        python_cmd=$(command -v python3 || command -v python)
        if "$python_cmd" -c "import json" &> /dev/null; then
            _JSON_PARSER="python"
        else
             echo "Error: Preferred JSON parser 'python' found, but cannot import 'json' module." >&amp;2
             return 1
        fi
    else
        echo "Error: Preferred JSON parser '$PREFERRED_JSON_PARSER' not found or invalid." >&amp;2
        return 1
    fi

    # Check for Clipboard command (optional)
    local enable_clipboard_flag=${ENABLE_CLIPBOARD:-true} # Default to true if not set
    if [[ "$enable_clipboard_flag" == "true" ]]; then
        if command -v pbcopy &> /dev/null; then # macOS
            _CLIPBOARD_CMD="pbcopy"
        elif command -v xclip &> /dev/null; then # Linux (X11)
            # Check if X11 display is available
            if [[ -n "$DISPLAY" ]]; then
                 _CLIPBOARD_CMD="xclip -selection clipboard"
            else
                 echo "Warning: xclip found, but no X11 display detected. Clipboard disabled." >&amp;2
            fi
        elif command -v clip.exe &> /dev/null; then # WSL
            _CLIPBOARD_CMD="clip.exe"
        else
            echo "Warning: No clipboard command (pbcopy, xclip, clip.exe) found. Clipboard disabled." >&amp;2
        fi
    fi

    # Debugging output (optional)
    # echo "Dependencies: HTTP=$_HTTP_CLIENT, JSON=$_JSON_PARSER, CLIPBOARD=$_CLIPBOARD_CMD" >&2

    return 0
}

# Call dependency check when script is sourced
_check_dependencies || return 1 # Exit/return if critical dependencies fail

# --- Utility Functions ---

# Function to make API requests using detected HTTP client (_HTTP_CLIENT)
# Arguments:
#   $1: URL
#   $2: JSON data payload
#   $3: Authorization Header value (e.g., "Bearer YOUR_API_KEY")
#   $4...: Additional Header key-value pairs (e.g., "Content-Type: application/json" "X-Api-Key: value")
# Outputs:
#   Writes HTTP response body to stdout
#   Returns 0 on success (HTTP 2xx), 1 on failure
_make_api_request() {
    local url="$1"
    local data="$2"
    local auth_header="$3"
    shift 3
    local headers=("$@")
    local response
    local http_code

    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        local curl_opts=(-s -S -X POST -d "$data") # -s silent, -S show error, -X POST, -d data
        
        # Add Authorization header if provided
        if [[ -n "$auth_header" ]]; then
            curl_opts+=(-H "Authorization: $auth_header")
        fi

        # Add additional headers
        for header in "${headers[@]}"; do
            curl_opts+=(-H "$header")
        done

        # Add Content-Type header if not already present
        local content_type_present=false
        for header in "${headers[@]}"; do
            if [[ "$header" == "Content-Type:"* ]]; then
                content_type_present=true
                break
            fi
        done
        if ! $content_type_present; then
             curl_opts+=(-H "Content-Type: application/json")
        fi

        # Capture response and status code separately
        response=$(curl "${curl_opts[@]}" --write-out "\n%{http_code}" "$url")
        http_code=$(echo "$response" | tail -n1)
        response=$(echo "$response" | sed '$d') # Remove status code line

        if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
            echo "$response"
            return 0
        else
            echo "Error: API request failed with HTTP status $http_code" >&2
            echo "Response: $response" >&2
            return 1
        fi

    elif [[ "$_HTTP_CLIENT" == "wget" ]]; then
        local wget_opts=(--quiet --output-document=- --post-data="$data") # --quiet, -O -, --post-data

        # Add Authorization header if provided
        if [[ -n "$auth_header" ]]; then
            wget_opts+=(--header="Authorization: $auth_header")
        fi

        # Add additional headers
        for header in "${headers[@]}"; do
            wget_opts+=(--header="$header")
        done
        
        # Add Content-Type header if not already present
        local content_type_present=false
        for header in "${headers[@]}"; do
            if [[ "$header" == "Content-Type:"* ]]; then
                content_type_present=true
                break
            fi
        done
        if ! $content_type_present; then
             wget_opts+=(--header="Content-Type: application/json")
        fi

        # Wget doesn't easily provide status code with output, so we rely on exit status
        response=$(wget "${wget_opts[@]}" "$url")
        local wget_status=$?

        if [[ $wget_status -eq 0 ]]; then
            echo "$response"
            return 0
        else
            # Try to get error details from stderr (wget prints errors there)
            # This is tricky and might not capture everything reliably
            echo "Error: API request failed (wget exit status $wget_status)." >&2
            # Wget might have printed errors to stderr already
            return 1
        fi
    else
        echo "Error: No valid HTTP client (curl or wget) detected." >&2
        return 1
    fi
}

# Function to parse JSON response using detected JSON parser (_JSON_PARSER)
# Arguments:
#   $1: JSON string
#   $2: Provider type (e.g., "openai", "anthropic", "openrouter", "local") - used to select appropriate parsing logic
# Outputs:
#   Writes extracted command text to stdout
#   Returns 0 on success, 1 on failure
_parse_json_response() {
    local json_string="$1"
    local provider="$2"
    local command_text=""

    if [[ -z "$json_string" ]]; then
        echo "Error: Empty JSON string received for parsing." >&2
        return 1
    fi

    if [[ "$_JSON_PARSER" == "jq" ]]; then
        # --- jq parsing logic ---
        # This needs to be adapted based on the actual response structure of each API
        # Example for OpenAI/OpenRouter compatible structure:
        if [[ "$provider" == "openai" || "$provider" == "openrouter" || "$provider" == "local" ]]; then
             # Try common paths for command content
             command_text=$(echo "$json_string" | jq -r '.choices[0].message.content // .choices[0].text // .text // ""' 2>/dev/null)
        elif [[ "$provider" == "anthropic" ]]; then
             # Example for Anthropic structure (needs verification)
             command_text=$(echo "$json_string" | jq -r '.content[0].text // ""' 2>/dev/null)
        else
             echo "Error: Unknown provider '$provider' for jq parsing." >&2
             return 1
        fi
        
        if [[ $? -ne 0 || -z "$command_text" ]]; then
             echo "Error: Failed to parse JSON or extract command using jq." >&2
             echo "JSON received: $json_string" >&2 # Log the problematic JSON
             return 1
        fi

    elif [[ "$_JSON_PARSER" == "python" ]]; then
        # --- Python parsing logic ---
        local python_cmd
        python_cmd=$(command -v python3 || command -v python)
        local script
        # Python script needs to handle different structures based on provider
        # This is a simplified example, needs refinement
        script=$(cat <<-EOF
import json
import sys

try:
    data = json.loads(sys.stdin.read())
    provider = sys.argv[1]
    command = ""
    if provider in ["openai", "openrouter", "local"]:
        # Try common paths
        command = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        if not command:
             command = data.get("choices", [{}])[0].get("text", "")
        if not command:
             command = data.get("text", "")
    elif provider == "anthropic":
         # Try Anthropic path
         command = data.get("content", [{}])[0].get("text", "")
    
    if command:
        print(command)
        sys.exit(0)
    else:
        # print("Error: Could not extract command text from JSON.", file=sys.stderr) # Avoid stderr clutter
        sys.exit(1)
except Exception as e:
    # print(f"Error parsing JSON with Python: {e}", file=sys.stderr) # Avoid stderr clutter
    sys.exit(1)
EOF
)
        command_text=$(echo "$json_string" | "$python_cmd" -c "$script" "$provider")
        if [[ $? -ne 0 || -z "$command_text" ]]; then
            echo "Error: Failed to parse JSON or extract command using Python." >&2
            # Avoid logging potentially large JSON string here unless debugging
            return 1
        fi
    else
        echo "Error: No valid JSON parser (jq or python) detected." >&2
        return 1
    fi

    # --- Post-processing ---
    # Remove potential ```bash ... ``` markdown blocks or similar artifacts
    command_text=$(echo "$command_text" | sed -e 's/^```bash[[:space:]]*//' -e 's/[[:space:]]*```$//' -e 's/^```[[:space:]]*//' -e 's/[[:space:]]*```$//')
    # Trim leading/trailing whitespace
    command_text=$(echo "$command_text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [[ -z "$command_text" ]]; then
         echo "Error: Extracted command text is empty after parsing/processing." >&2
         return 1
    fi

    echo "$command_text"
    return 0
}

# Function to copy text from stdin to clipboard using detected command (_CLIPBOARD_CMD)
# Arguments: None (reads from stdin)
# Outputs: None
# Returns: 0 on success, 1 on failure or if clipboard is disabled/unavailable
_copy_to_clipboard() {
    if [[ -z "$_CLIPBOARD_CMD" ]]; then
        # echo "Debug: Clipboard command not set or disabled." >&2 # Optional debug
        return 1 # Clipboard not available or disabled
    fi

    # Read from stdin and pipe to the clipboard command
    if ! cat | $_CLIPBOARD_CMD; then
        echo "Error: Failed to copy text to clipboard using '$_CLIPBOARD_CMD'." >&2
        return 1
    fi

    return 0
}

# Function to display the generated command and attempt to copy it to clipboard
# Arguments:
#   $1: The generated command string
# Outputs:
#   Prints the command to stdout
#   Prints status message about clipboard to stderr
_display_command() {
    local command_text="$1"

    if [[ -z "$command_text" ]]; then
        echo "Error: No command text provided to display." >&2
        return 1
    fi

    # --- Display Command ---
    # Simple display for now. Could add syntax highlighting later if desired.
    echo "--- Generated Command ---"
    echo "$command_text"
    echo "-------------------------"

    # --- Copy to Clipboard ---
    if echo "$command_text" | _copy_to_clipboard; then
        echo "(Command copied to clipboard)" >&2
    else
        # Don't print error if clipboard was just unavailable/disabled
        if [[ -n "$_CLIPBOARD_CMD" ]]; then
             echo "(Failed to copy command to clipboard)" >&2
        fi
    fi

    return 0
}

# --- Provider Functions ---

# Function to get bash command using OpenRouter API
# Arguments: $@ - Natural language prompt
# Uses: $OPENROUTER_API_KEY, $OPENROUTER_MODEL (optional)
get_chat_cmd1() {
    local user_prompt="$*"
    local api_key="${OPENROUTER_API_KEY}"
    # Use model from config or default to auto-detection by OpenRouter
    local model="${OPENROUTER_MODEL:-openrouter/auto}"
    local api_url="https://openrouter.ai/api/v1/chat/completions"

    if [[ -z "$user_prompt" ]]; then
        echo "Usage: get_chat_cmd1 <your natural language prompt>" >&2
        return 1
    fi

    if [[ -z "$api_key" ]]; then
        echo "Error: OPENROUTER_API_KEY is not set in the configuration file ($CONFIG_FILE)." >&2
        return 1
    fi

    # --- Prompt Engineering ---
    # System prompt to guide the AI
    local system_prompt="You are an expert bash command generator. Your task is to take the user's natural language request and provide the single, most appropriate bash command that achieves the user's goal.
The command should be directly executable in a standard bash environment (Linux, macOS, WSL).
Output ONLY the bash command itself, without any explanation, comments, markdown formatting (like \`\`\`bash), or introductory text.
Ensure the command is safe and avoids destructive actions unless explicitly requested and confirmed. Prioritize portable commands where possible."

    # --- Construct JSON Payload ---
    # Using jq if available for safer JSON construction, otherwise manual string building
    local json_payload
    if [[ "$_JSON_PARSER" == "jq" ]]; then
        json_payload=$(jq -n \
            --arg model "$model" \
            --arg sys_prompt "$system_prompt" \
            --arg user_prompt "$user_prompt" \
            '{model: $model, messages: [{role: "system", content: $sys_prompt}, {role: "user", content: $user_prompt}]}')
        if [[ $? -ne 0 ]]; then
             echo "Error: Failed to construct JSON payload using jq." >&2
             return 1
        fi
    else
        # Manual JSON construction (less safe, prone to escaping issues)
        # Basic escaping for quotes and backslashes
        local escaped_sys_prompt=$(echo "$system_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        local escaped_user_prompt=$(echo "$user_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        json_payload="{\"model\": \"$model\", \"messages\": [{\"role\": \"system\", \"content\": \"$escaped_sys_prompt\"}, {\"role\": \"user\", \"content\": \"$escaped_user_prompt\"}]}"
    fi

    # --- Make API Request ---
    echo "Requesting command from OpenRouter ($model)..." >&2
    local response
    response=$(_make_api_request "$api_url" "$json_payload" "Bearer $api_key")
    local request_status=$?

    if [[ $request_status -ne 0 ]]; then
        echo "Error: API request failed." >&2
        return 1
    fi

    # --- Parse Response ---
    local command_text
    command_text=$(_parse_json_response "$response" "openrouter")
    local parse_status=$?

    if [[ $parse_status -ne 0 ]]; then
        echo "Error: Failed to parse API response." >&2
        return 1
    fi

    # --- Display Command ---
    _display_command "$command_text"

    return 0
}

# Function to get bash command using OpenAI API
# Arguments: $@ - Natural language prompt
# Uses: $OPENAI_API_KEY, $OPENAI_MODEL (optional)
get_chat_cmd2() {
    local user_prompt="$*"
    local api_key="${OPENAI_API_KEY}"
    # Use model from config or default to gpt-4o-mini
    local model="${OPENAI_MODEL:-gpt-4o-mini}"
    local api_url="https://api.openai.com/v1/chat/completions"

    if [[ -z "$user_prompt" ]]; then
        echo "Usage: get_chat_cmd2 <your natural language prompt>" >&2
        return 1
    fi

    if [[ -z "$api_key" ]]; then
        echo "Error: OPENAI_API_KEY is not set in the configuration file ($CONFIG_FILE)." >&2
        return 1
    fi

    # --- Prompt Engineering ---
    # Reusing the same system prompt as OpenRouter for consistency
    local system_prompt="You are an expert bash command generator. Your task is to take the user's natural language request and provide the single, most appropriate bash command that achieves the user's goal.
The command should be directly executable in a standard bash environment (Linux, macOS, WSL).
Output ONLY the bash command itself, without any explanation, comments, markdown formatting (like \`\`\`bash), or introductory text.
Ensure the command is safe and avoids destructive actions unless explicitly requested and confirmed. Prioritize portable commands where possible."

    # --- Construct JSON Payload ---
    local json_payload
    if [[ "$_JSON_PARSER" == "jq" ]]; then
        json_payload=$(jq -n \
            --arg model "$model" \
            --arg sys_prompt "$system_prompt" \
            --arg user_prompt "$user_prompt" \
            '{model: $model, messages: [{role: "system", content: $sys_prompt}, {role: "user", content: $user_prompt}]}')
        if [[ $? -ne 0 ]]; then
             echo "Error: Failed to construct JSON payload using jq." >&2
             return 1
        fi
    else
        # Manual JSON construction
        local escaped_sys_prompt=$(echo "$system_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        local escaped_user_prompt=$(echo "$user_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        json_payload="{\"model\": \"$model\", \"messages\": [{\"role\": \"system\", \"content\": \"$escaped_sys_prompt\"}, {\"role\": \"user\", \"content\": \"$escaped_user_prompt\"}]}"
    fi

    # --- Make API Request ---
    echo "Requesting command from OpenAI ($model)..." >&2
    local response
    response=$(_make_api_request "$api_url" "$json_payload" "Bearer $api_key")
    local request_status=$?

    if [[ $request_status -ne 0 ]]; then
        echo "Error: API request failed." >&2
        return 1
    fi

    # --- Parse Response ---
    local command_text
    command_text=$(_parse_json_response "$response" "openai") # Specify provider type
    local parse_status=$?

    if [[ $parse_status -ne 0 ]]; then
        echo "Error: Failed to parse API response." >&2
        return 1
    fi

    # --- Display Command ---
    _display_command "$command_text"

    return 0
}

# Function to get bash command using Anthropic API
# Arguments: $@ - Natural language prompt
# Uses: $ANTHROPIC_API_KEY, $ANTHROPIC_MODEL (optional)
get_chat_cmd3() {
    local user_prompt="$*"
    local api_key="${ANTHROPIC_API_KEY}"
    # Use model from config or default to claude-3-haiku
    local model="${ANTHROPIC_MODEL:-claude-3-haiku-20240307}"
    local api_url="https://api.anthropic.com/v1/messages"
    local anthropic_version="2023-06-01" # Required header

    if [[ -z "$user_prompt" ]]; then
        echo "Usage: get_chat_cmd3 <your natural language prompt>" >&2
        return 1
    fi

    if [[ -z "$api_key" ]]; then
        echo "Error: ANTHROPIC_API_KEY is not set in the configuration file ($CONFIG_FILE)." >&2
        return 1
    fi

    # --- Prompt Engineering ---
    # Anthropic uses a slightly different prompt structure (no separate system prompt in the main messages array)
    # We'll put the system guidance here.
    local system_guidance="You are an expert bash command generator. Your task is to take the user's natural language request and provide the single, most appropriate bash command that achieves the user's goal. The command should be directly executable in a standard bash environment (Linux, macOS, WSL). Output ONLY the bash command itself, without any explanation, comments, markdown formatting (like \`\`\`bash), or introductory text. Ensure the command is safe and avoids destructive actions unless explicitly requested and confirmed. Prioritize portable commands where possible."

    # --- Construct JSON Payload (Anthropic format) ---
    local json_payload
    # Max tokens can be adjusted
    local max_tokens=512
    if [[ "$_JSON_PARSER" == "jq" ]]; then
        json_payload=$(jq -n \
            --arg model "$model" \
            --arg system "$system_guidance" \
            --arg user_prompt "$user_prompt" \
            --argjson max_tokens "$max_tokens" \
            '{model: $model, system: $system, messages: [{role: "user", content: $user_prompt}], max_tokens: $max_tokens}')
        if [[ $? -ne 0 ]]; then
             echo "Error: Failed to construct JSON payload using jq." >&2
             return 1
        fi
    else
        # Manual JSON construction
        local escaped_system=$(echo "$system_guidance" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        local escaped_user_prompt=$(echo "$user_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        json_payload="{\"model\": \"$model\", \"system\": \"$escaped_system\", \"messages\": [{\"role\": \"user\", \"content\": \"$escaped_user_prompt\"}], \"max_tokens\": $max_tokens}"
    fi

    # --- Make API Request ---
    echo "Requesting command from Anthropic ($model)..." >&2
    local response
    # Anthropic uses x-api-key header, not Authorization
    response=$(_make_api_request "$api_url" "$json_payload" "" "x-api-key: $api_key" "anthropic-version: $anthropic_version" "Content-Type: application/json")
    local request_status=$?

    if [[ $request_status -ne 0 ]]; then
        echo "Error: API request failed." >&2
        return 1
    fi

    # --- Parse Response ---
    local command_text
    command_text=$(_parse_json_response "$response" "anthropic") # Specify provider type
    local parse_status=$?

    if [[ $parse_status -ne 0 ]]; then
        echo "Error: Failed to parse API response." >&2
        return 1
    fi

    # --- Display Command ---
    _display_command "$command_text"

    return 0
}

# Function to get bash command using a locally-hosted API (OpenAI compatible)
# Arguments: $@ - Natural language prompt
# Uses: $LOCAL_MODEL_API_BASE, $LOCAL_MODEL_API_KEY (optional), $LOCAL_MODEL_NAME (optional)
get_chat_local() {
    local user_prompt="$*"
    local api_base="${LOCAL_MODEL_API_BASE}"
    local api_key="${LOCAL_MODEL_API_KEY}" # Optional key
    # Use model name from config or let the local server decide (if it supports that)
    local model="${LOCAL_MODEL_NAME}"
    
    if [[ -z "$api_base" ]]; then
        echo "Error: LOCAL_MODEL_API_BASE is not set in the configuration file ($CONFIG_FILE)." >&2
        echo "Please set it to your local API endpoint (e.g., http://localhost:1234/v1 for LM Studio)." >&2
        return 1
    fi

    # Ensure API base ends with /v1/chat/completions or similar standard path
    # Basic check, might need refinement depending on local server variations
    if [[ ! "$api_base" == *"/v1"* ]]; then
         echo "Warning: LOCAL_MODEL_API_BASE ('$api_base') might not point to a standard OpenAI-compatible chat completions endpoint (e.g., ending in /v1/chat/completions)." >&2
    fi
    # Append /chat/completions if not present, handling potential trailing slashes
    local api_url="${api_base%/}/chat/completions"
    # Ensure only one /v1/ if base was like http://host/v1
    api_url=${api_url/v1\/\//v1\/}
    # Ensure /v1/ if base was like http://host
    if [[ ! "$api_url" == *"/v1/"* ]]; then
        api_url=${api_url/\/chat/\/v1\/chat}
    fi


    if [[ -z "$user_prompt" ]]; then
        echo "Usage: get_chat_local <your natural language prompt>" >&2
        return 1
    fi

    # --- Prompt Engineering ---
    # Reusing the same system prompt
    local system_prompt="You are an expert bash command generator. Your task is to take the user's natural language request and provide the single, most appropriate bash command that achieves the user's goal.
The command should be directly executable in a standard bash environment (Linux, macOS, WSL).
Output ONLY the bash command itself, without any explanation, comments, markdown formatting (like \`\`\`bash), or introductory text.
Ensure the command is safe and avoids destructive actions unless explicitly requested and confirmed. Prioritize portable commands where possible."

    # --- Construct JSON Payload ---
    local json_payload
    if [[ "$_JSON_PARSER" == "jq" ]]; then
        # Include model only if it's set in the config
        local jq_args=(-n --arg sys_prompt "$system_prompt" --arg user_prompt "$user_prompt")
        if [[ -n "$model" ]]; then
            jq_args+=(--arg model "$model")
            json_payload=$(jq "${jq_args[@]}" '{model: $model, messages: [{role: "system", content: $sys_prompt}, {role: "user", content: $user_prompt}]}')
        else
             # Don't include model field if not specified, let the local server default
             json_payload=$(jq "${jq_args[@]}" '{messages: [{role: "system", content: $sys_prompt}, {role: "user", content: $user_prompt}]}')
        fi

        if [[ $? -ne 0 ]]; then
             echo "Error: Failed to construct JSON payload using jq." >&2
             return 1
        fi
    else
        # Manual JSON construction
        local escaped_sys_prompt=$(echo "$system_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        local escaped_user_prompt=$(echo "$user_prompt" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
        if [[ -n "$model" ]]; then
             json_payload="{\"model\": \"$model\", \"messages\": [{\"role\": \"system\", \"content\": \"$escaped_sys_prompt\"}, {\"role\": \"user\", \"content\": \"$escaped_user_prompt\"}]}"
        else
             json_payload="{\"messages\": [{\"role\": \"system\", \"content\": \"$escaped_sys_prompt\"}, {\"role\": \"user\", \"content\": \"$escaped_user_prompt\"}]}"
        fi
    fi

    # --- Make API Request ---
    echo "Requesting command from Local Model ($api_url)..." >&2
    local response
    local auth_header=""
    if [[ -n "$api_key" ]]; then
        auth_header="Bearer $api_key"
    fi
    response=$(_make_api_request "$api_url" "$json_payload" "$auth_header")
    local request_status=$?

    if [[ $request_status -ne 0 ]]; then
        echo "Error: API request failed. Ensure your local model server is running and accessible at $api_url." >&2
        return 1
    fi

    # --- Parse Response ---
    local command_text
    command_text=$(_parse_json_response "$response" "local") # Specify provider type
    local parse_status=$?

    if [[ $parse_status -ne 0 ]]; then
        echo "Error: Failed to parse API response." >&2
        return 1
    fi

    # --- Display Command ---
    _display_command "$command_text"

    return 0
}

# --- Main Logic (Example Alias/Function Definitions) ---
# Example of how functions might be called or aliased in .bashrc/.zshrc
# alias cmd1='get_chat_cmd1'
# alias cmd2='get_chat_cmd2'
# alias cmd3='get_chat_cmd3'
# alias cmdlocal='get_chat_local'

echo "AI Bash Commands script loaded."
