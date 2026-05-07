export NOTIZEN_CONFIG_PATH="${HOME}/.config/notes"
export NOTIZEN_TEMPL_PATH="${NOTIZEN_CONFIG_PATH}/templates"
export SYNC_FOLDER_PATH="${HOME}/Sync"
export VAULT_BASE_PATH="${SYNC_FOLDER_PATH}/vault"

export VAULT_ASSETS_PATH="${VAULT_BASE_PATH}/assets"
export VAULT_DAILY_PATH="${VAULT_BASE_PATH}/daily"
export VAULT_SCRATCH_PATH="${VAULT_BASE_PATH}/scratch"
export VAULT_TEMPL_PATH="${VAULT_BASE_PATH}/templates"
export VAULT_ZETTEL_PATH="${VAULT_BASE_PATH}/zettelkasten"

check_dirs() {
    local vault_paths=(
        "${VAULT_ASSETS_PATH}"
        "${VAULT_DAILY_PATH}"
        "${VAULT_SCRATCH_PATH}"
        "${VAULT_TEMPL_PATH}"
        "${VAULT_ZETTEL_PATH}"
    )

    for path in "${vault_paths[@]}"; do
        if [[ ! -d "${path}" ]]; then
            mkdir -p "${path}" 2>/dev/null
        fi
    done
}

normalize_filename() {
    local title="$1"
    echo "${title}" | python3 -c "
import sys, re
s = sys.stdin.read().strip().lower()
s = re.sub(r'[^a-z0-9äöüß가-힣ㄱ-ㅎㅏ-ㅣ -]', '', s)
s = s.strip()
s = re.sub(r' +', '-', s)
s = re.sub(r'-+', '-', s)
print(s, end='')
"
}

handle_exe() {
    local filename="$1"
    local nvim_mode="$2"

    if [[ "${nvim_mode}" = "--nvim-mode" ]] || [[ "${nvim_mode}" = "true" ]]; then
        realpath "${filename}"
    else
        nvim "${filename}"
    fi
}

check_args() {
    if [[ -z "$2" || "$2" == --* || "$2" == -* ]]; then
        echo "Error: Second argument ist not valid." >&2
        exit 1
    fi
}
