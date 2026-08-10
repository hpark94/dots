#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for font-install's download path. curl, unzip and fc-cache are
# stubbed and HOME points at BATS_TEST_TMPDIR, so nothing is fetched and the real
# font directory is never written to.

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${HOME}"
    SCRIPT="${BATS_TEST_DIRNAME}/../font-install"

    STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "${STUB_BIN}"
    PATH="${STUB_BIN}:${PATH}"
    export FC_CACHE_LOG="${BATS_TEST_TMPDIR}/fc-cache.log"
    : >"${FC_CACHE_LOG}"
    printf '#!/usr/bin/env bash\nexit 0\n' >"${STUB_BIN}/unzip"
    cat >"${STUB_BIN}/fc-cache" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${FC_CACHE_LOG}"
STUB_EOF
    chmod +x "${STUB_BIN}/unzip" "${STUB_BIN}/fc-cache"
}

@test "font-install aborts loudly when a download returns an HTTP error" {
    # A 404 answered the way curl does: exit 22 when -f asked it to treat the
    # status as an error, otherwise exit 0 with the error page as the payload.
    cat >"${STUB_BIN}/curl" <<'STUB_EOF'
#!/usr/bin/env bash
if [[ "$1" == -f* ]]; then
    exit 22
fi
printf '<html>404 Not Found</html>\n' >"${@: -1}"
STUB_EOF
    chmod +x "${STUB_BIN}/curl"

    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"[ERROR]"* ]]
    [[ "${output}" == *"Failed to download Maple_Mono_NF"* ]]
    [ ! -s "${FC_CACHE_LOG}" ]
    # A run that aborts before installing anything must not leave the font's
    # directory behind as evidence of a success.
    [ ! -e "${HOME}/.local/share/fonts/Maple_Mono_NF" ]
}

@test "font-install downloads with -f into a private temporary directory" {
    export CURL_LOG="${BATS_TEST_TMPDIR}/curl.log"
    : >"${CURL_LOG}"
    # Records its args and creates the empty file the -o path names, which is the
    # last argument, so the script's own cleanup finds something to remove.
    cat >"${STUB_BIN}/curl" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_LOG}"
: >"${@: -1}"
STUB_EOF
    chmod +x "${STUB_BIN}/curl"

    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    local first
    first=$(head -1 "${CURL_LOG}")
    [[ "${first}" == "-fL http"* ]]
    # A fixed /tmp/<font>.zip is pre-creatable by anyone; mktemp -d is not.
    [[ "${first}" != *"-o /tmp/Maple_Mono_NF.zip" ]]
}
