[[ ! -f /etc/environment ]] && return

while read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    
    # First, check if we have a valid variable name before the equals
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*) ]]; then
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        
        # Only handle simple quoted values - skip anything complex
        if [[ "$var_value" =~ ^\'[^[:cntrl:]\']*\'$ ]]; then
            # Simple quoted value without any control characters or nested quotes
            var_value="${var_value#\'}"
            var_value="${var_value%\'}"
            export "$var_name=$var_value"
        elif [[ "$var_value" =~ ^[^[:space:]\']+$ ]]; then
            # Simple unquoted value without spaces or quotes
            export "$var_name=$var_value"
        fi
    fi
done < /etc/environment