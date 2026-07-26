# Shared parser for the repository's machine-local Vivado settings.

load_local_settings() {
    local settings_file=$1
    local line key value
    local line_number=0
    local -A seen=()

    if [[ -f "$settings_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_number += 1))
            line=${line%$'\r'}
            case "$line" in
                ''|'#'*) continue ;;
            esac

            if [[ "$line" != *=* ]]; then
                printf 'error: %s:%d: expected KEY=VALUE\n' \
                    "$settings_file" "$line_number" >&2
                return 2
            fi
            key=${line%%=*}
            value=${line#*=}
            case "$key" in
                VIVADO_BIN|VIVADO_STAGE_ROOT|VIVADO_JOBS) ;;
                *)
                    printf 'error: %s:%d: unknown local setting: %s\n' \
                        "$settings_file" "$line_number" "$key" >&2
                    return 2
                    ;;
            esac
            if [[ -n "${seen[$key]:-}" ]]; then
                printf 'error: %s:%d: duplicate local setting: %s\n' \
                    "$settings_file" "$line_number" "$key" >&2
                return 2
            fi
            seen[$key]=1
            if [[ -z "$value" ]]; then
                printf 'error: %s:%d: empty value for %s\n' \
                    "$settings_file" "$line_number" "$key" >&2
                return 2
            fi
            if [[ "$key" == VIVADO_JOBS && ! "$value" =~ ^[1-9][0-9]*$ ]]; then
                printf 'error: %s:%d: VIVADO_JOBS must be a positive integer\n' \
                    "$settings_file" "$line_number" >&2
                return 2
            fi

            [[ -n "${!key:-}" ]] || export "$key=$value"
        done <"$settings_file"
    fi

    if [[ -n "${VIVADO_JOBS:-}" && ! "$VIVADO_JOBS" =~ ^[1-9][0-9]*$ ]]; then
        printf 'error: VIVADO_JOBS must be a positive integer\n' >&2
        return 2
    fi
}
