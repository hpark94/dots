#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# BATS test suite for cltex, run inside a throwaway directory because the script
# deletes recursively below the working directory.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../cltex"
    work="${BATS_TEST_TMPDIR}/work"
    mkdir -p "${work}"
}

@test "cltex aborts and deletes nothing when the directory holds no *.tex" {
    printf 'keep' >"${work}/notes.log"
    printf 'keep' >"${work}/data.out"
    printf 'keep' >"${work}/book.toc"

    cd "${work}"
    run "${SCRIPT}"
    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no *.tex in the current directory"* ]]
    [ -f "${work}/notes.log" ]
    [ -f "${work}/data.out" ]
    [ -f "${work}/book.toc" ]
}

@test "cltex removes build artifacts next to a *.tex but spares slurm*.out" {
    printf '\\documentclass{article}' >"${work}/paper.tex"
    printf 'log' >"${work}/paper.log"
    printf 'out' >"${work}/paper.out"
    printf 'slurm' >"${work}/slurm-1.out"

    cd "${work}"
    run "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -e "${work}/paper.log" ]
    [ ! -e "${work}/paper.out" ]
    [ -f "${work}/slurm-1.out" ]
    [ -f "${work}/paper.tex" ]
}
