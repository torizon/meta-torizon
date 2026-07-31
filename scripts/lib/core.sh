#!/bin/bash
# -*- mode: shell-script-mode; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
#
# Copyright (C) 2012-13 O.S. Systems Software LTDA.
# Copyright (C) 2017 Open Source Foundries Ltd.
# Copyright (C) 2020-2026 Toradex AG
# Authored-by:  Otavio Salvador <otavio@ossystems.com.br>
# Adopted to Angstrom:  Khem Raj <raj.khem@gmail.com>
#
# SPDX-License-Identifier: GPL-2.0-only
#
# core.sh - shared library for scripts
#
# This file is intended to be *sourced* by a vendor's setup-environment
# script, not executed directly. It provides a set of common functions and
# variables for all vendor scripts.
# 
# Public API functions start with tdx_*, and functions starting with _tdx_*
# are private helpers.
#
#   - Every function uses `local` for its own bookkeeping variables. Nothing
#     is allowed to leak into the caller's shell except the small set of
#     variables explicitly documented as intentional (PATH, BUILDDIR,
#     BB_ENV_PASSTHROUGH_ADDITIONS, DISTRO, MACHINE, SDKMACHINE.
#   - Nothing here ever calls `exit` - only `return`. A stray `exit` would
#     kill the user's whole shell.
#   - Nothing here calls `cd` except the two functions whose documented job
#     is precisely to change the caller's directory (tdx_set_builddir and,
#     trivially, tdx_compute_oeroot re-cd'ing into the already-resolved
#     OEROOT). Both are called out explicitly in their own comments below.
#   - `mapfile`/`readarray` are avoided throughout in favor of
#     `while IFS= read -r`, since mapfile isn't available in zsh.

# Double-sourcing guard.
[ -n "${_TDX_CORE_SH_LOADED:-}" ] && return 0
_TDX_CORE_SH_LOADED=1

# Locating this file's own directory
if [ -n "${BASH_SOURCE:-}" ]; then
    _TDX_CORE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
elif [ -n "${ZSH_VERSION:-}" ]; then
    # shellcheck disable=SC2296  # zsh-only prompt-escape parameter expansion
    _TDX_CORE_DIR=$(cd "$(dirname "${(%):-%N}")" >/dev/null 2>&1 && pwd)
fi

# _tdx_lib_conf_path <filename>
# 
# Print the resolved path to <filename> or return 1 if it cannot be found.
_tdx_lib_conf_path() {
    local fname="${1:-}"
    if [ -n "${_TDX_CORE_DIR:-}" ] && [ -f "${_TDX_CORE_DIR}/${fname}" ]; then
        printf '%s\n' "${_TDX_CORE_DIR}/${fname}"
        return 0
    fi
    if [ -n "${_TDX_LAYERS_DIR:-}" ] && \
       [ -f "${_TDX_LAYERS_DIR}/meta-toradex-torizon/scripts/lib/${fname}" ]; then
        printf '%s\n' "${_TDX_LAYERS_DIR}/meta-toradex-torizon/scripts/lib/${fname}"
        return 0
    fi
    return 1
}

# Wrappers around _tdx_lib_conf_path for each data file.
_tdx_machines_conf_path() { _tdx_lib_conf_path machines.conf; }
_tdx_distros_conf_path() { _tdx_lib_conf_path distros.conf; }

# tdx_compute_oeroot
#
# resolve and export _TDX_OEROOT, _TDX_LAYERS_DIR, _TDX_MANIFESTS and _TDX_SCRIPTS, and apply
# the one-time bash/zsh compatibility settings.
tdx_compute_oeroot() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt sh_word_split
        setopt clobber
    elif [ -n "${BASH_VERSION:-}" ]; then
        set +o noclobber
    fi

    # compute OEROOT path relative to _TDX_CORE_DIR
    _TDX_OEROOT=$(cd "${_TDX_CORE_DIR}/../../../.." >/dev/null 2>&1 && pwd)
    cd "${_TDX_OEROOT}" || return 1
    # Preserve the dispatcher's own _TDX_LAYERS_DIR if it already resolved one
    : "${_TDX_LAYERS_DIR:=${_TDX_OEROOT}/layers}"
    _TDX_MANIFESTS="${_TDX_OEROOT}/.repo/manifests"
    _TDX_SCRIPTS="${_TDX_LAYERS_DIR}/meta-toradex-torizon/scripts"
}

# tdx_set_builddir <builddir name> <distro>
#
# builddir resolution that normalizes the (optional) explicit builddir
# argument (default build-<distro>), and export both _TDX_BUILDDIR and
# BUILDDIR consistently.
tdx_set_builddir() {
    local arg="${1:-}" distro="${2:-}" builddir

    builddir="${arg:-build-${distro}}"
    # If relative, get full path
    case "${builddir}" in
        /*) ;;
        *) builddir=$(readlink -f "${builddir}") ;;
    esac
    # Get rid of a trailing slash, some OE sed calls trip on the double
    # slash it would otherwise produce.
    builddir="${builddir%%/}"

    _TDX_BUILDDIR="${builddir}"
    BUILDDIR="${builddir}"
    # Set for recipetool's benefit
    BBPATH="${builddir}"
    export _TDX_BUILDDIR BUILDDIR BBPATH

    mkdir -p "${_TDX_BUILDDIR}/conf" && cd "${_TDX_BUILDDIR}" || return 1
}

# tdx_set_builddir_from_cwd
# 
# builddir resolution called *after* the vendor's own tooling
# (oe-init-build-env, imx-setup-release.sh, ...) has already cd'd into the
# build directory. Exports _TDX_BUILDDIR/BUILDDIR from $PWD.
tdx_set_builddir_from_cwd() {
    _TDX_BUILDDIR=$(pwd)
    BUILDDIR="${_TDX_BUILDDIR}"
    export _TDX_BUILDDIR BUILDDIR
}

# tdx_vendor_for_machine <machine>
#
# print the VENDOR column for <machine>, or return 1 if not found.
tdx_vendor_for_machine() {
    local machine="${1:-}" conf line m v bsp pol rest
    conf=$(_tdx_machines_conf_path) || return 1
    while IFS= read -r line; do
        case "${line}" in ''|'#'*) continue ;; esac
        read -r m v bsp pol rest <<< "${line}"
        if [ "${m}" = "${machine}" ]; then
            printf '%s\n' "${v}"
            return 0
        fi
    done < "${conf}"
    return 1
}

# tdx_distro_policy_for_machine <machine>
#
# print the raw DISTRO_POLICY column ('-', '=<value>' or '?<value>')
# for <machine>, or return 1 if not found.
tdx_distro_policy_for_machine() {
    local machine="${1:-}" conf line m v bsp pol rest
    conf=$(_tdx_machines_conf_path) || return 1
    while IFS= read -r line; do
        case "${line}" in ''|'#'*) continue ;; esac
        read -r m v bsp pol rest <<< "${line}"
        if [ "${m}" = "${machine}" ]; then
            printf '%s\n' "${pol}"
            return 0
        fi
    done < "${conf}"
    return 1
}

# tdx_apply_distro_policy <machine>
#
# apply <machine>'s DISTRO_POLICY to the $DISTRO variable:
#   -            leave $DISTRO untouched, the vendor script decides
#   =<value>     force $DISTRO to <value>, unconditionally
#   ?<value>     default $DISTRO to <value>, only if currently unset/empty
tdx_apply_distro_policy() {
    local machine="${1:-}" policy
    policy=$(tdx_distro_policy_for_machine "${machine}") || return 1
    case "${policy}" in
        '='*) DISTRO="${policy#=}" ;;
        '?'*) [ -z "${DISTRO:-}" ] && DISTRO="${policy#?}" ;;
        *) : ;;  # '-' (or empty/unknown): vendor script decides
    esac
    return 0
}

# tdx_menu_pairs [-v] <filter-regex>
#
# print "MACHINE<TAB>BSP_DISPLAY" lines whose VENDOR column matches
# <filter-regex>, or does NOT match it if -v is given. Used to build
# whiptail/dialog menu arrays without hardcoding the machine list.
tdx_menu_pairs() {
    local invert=0
    if [ "${1:-}" = "-v" ]; then
        invert=1
        shift
    fi
    local filter="${1:-}" conf line m v bsp pol rest matched
    conf=$(_tdx_machines_conf_path) || return 1
    while IFS= read -r line; do
        case "${line}" in ''|'#'*) continue ;; esac
        read -r m v bsp pol rest <<< "${line}"
        if printf '%s\n' "${v}" | grep -qE "${filter}"; then
            matched=1
        else
            matched=0
        fi
        if [ "${invert}" = "1" ]; then
            [ "${matched}" = "0" ] && printf '%s\t%s\n' "${m}" "${bsp}"
        else
            [ "${matched}" = "1" ] && printf '%s\t%s\n' "${m}" "${bsp}"
        fi
    done < "${conf}"
}

# tdx_distro_pairs
#
# print "DISTRO_ID<TAB>DESCRIPTION" lines. Used to build whiptail/dialog
# menu arrays and tdx_usage's listing without hardcoding the distro list.
tdx_distro_pairs() {
    local conf line d desc
    conf=$(_tdx_distros_conf_path) || return 1
    while IFS= read -r line; do
        case "${line}" in ''|'#'*) continue ;; esac
        read -r d desc <<< "${line}"
        printf '%s\t%s\n' "${d}" "${desc}"
    done < "${conf}"
}

# tdx_usage
#
# print the help/usage text to stderr.
tdx_usage() {
    cat >&2 <<EOF

Usage: [DISTRO=<DISTRO>] [MACHINE=<MACHINE>] [EULA=1] source setup-environment [-h] [BUILDDIR]

If no MACHINE is set, list of all distros will be shown for user to choose, and then the desired machine.
If no DISTRO is set, it is inferred from MACHINE (see scripts/lib/machines.conf's DISTRO_POLICY column) -
Toradex machines default to 'torizon' or 'torizon-upstream' per setup-environment-toradex's own logic. The
Xenomai3/4 distro variants are only reachable via explicit interactive/DISTRO selection.
If no EULA is set, user will be asked to read it and to accept it (if the selected machine requires it).
If no BUILDIR is set, it will be set to build-\$DISTRO.

Options:
  -h    Show this help message.
EOF

    echo "Distros"
    while IFS=$'\t' read -r d desc; do
        printf "\t%s\t%s\n" "${d}" "${desc}"
    done < <(tdx_distro_pairs)
    echo ""
    echo "Toradex Machines"
    while IFS=$'\t' read -r m d; do
        printf "\t%s\t%s\n" "${m}" "${d}"
    done < <(tdx_menu_pairs '^toradex$')
    echo ""
    echo "Common Torizon Machines"
    while IFS=$'\t' read -r m d; do
        printf "\t%s\t%s\n" "${m}" "${d}"
    done < <(tdx_menu_pairs -v '^toradex$')
}

# tdx_setup_path
#
# rebuild $PATH: strip any empty/current-directory tokens
# (a stray "::" or leading/trailing ":" can otherwise make wrong binaries
# get picked up during task execution), prepend the OE-required directories,
# then dedupe while preserving order.
tdx_setup_path() {
    PATH=$(echo "${PATH}" | sed 's/\(:.\|:\)*:/:/g;s/^.\?://;s/:.\?$//')
    PATH="${_TDX_OEROOT}/bitbake/bin:${_TDX_OEROOT}/.repo/repo:${PATH}"
    PATH="${_TDX_OEROOT}/layers/openembedded-core/bitbake/bin:${PATH}"
    PATH="${_TDX_OEROOT}/layers/openembedded-core/scripts:${PATH}"
    PATH=$(echo "${PATH}" |
           awk -F: '{for (i=1;i<=NF;i++) { if ( !x[$i]++ ) printf("%s:",$i); }}' |
           sed 's/:$//')
    export PATH
}

# tdx_dedupe_sort <words...>
#
# flatten all arguments into a single whitespace-separated word list,
# then dedupe+sort it (LC_ALL=C, unique).
# Order is NOT preserved - only use this where order doesn't matter!
tdx_dedupe_sort() {
    echo "$*" | tr ' ' '\n' | LC_ALL=C sort --unique | tr '\n' ' '
}

# tdx_setup_bb_env_passthrough [extra-vars...]
#
# (re)build and export BB_ENV_PASSTHROUGH_ADDITIONS from the standard
# OE variable-name list, any pre-existing value of
# $BB_ENV_PASSTHROUGH_ADDITIONS, and any extra vendor-specific variable
# names passed in.
tdx_setup_bb_env_passthrough() {
    local base_vars="MACHINE DISTRO TCMODE TCLIBC HTTP_PROXY http_proxy \
HTTPS_PROXY https_proxy FTP_PROXY ftp_proxy FTPS_PROXY ftps_proxy ALL_PROXY \
all_proxy NO_PROXY no_proxy SSH_AGENT_PID SSH_AUTH_SOCK BB_SRCREV_POLICY \
SDKMACHINE BB_NUMBER_THREADS BB_NO_NETWORK PARALLEL_MAKE GIT_PROXY_COMMAND \
SOCKS5_PASSWD SOCKS5_USER SCREENDIR STAMPS_DIR BBPATH_EXTRA BB_SETSCENE_ENFORCE"

    BB_ENV_PASSTHROUGH_ADDITIONS="$(tdx_dedupe_sort "${BB_ENV_PASSTHROUGH_ADDITIONS:-}" "${base_vars}" "$*")"
    export BB_ENV_PASSTHROUGH_ADDITIONS
}

# tdx_native_conf_is_current [<eula-conf-var>]
#
# compares the current $MACHINE/$DISTRO/$EULA against what's
# recorded in conf/auto.conf (and, if <eula-conf-var> is given, the matching
# ACCEPT_*-style line in conf/local.conf), and validates conf/checksum
# against the calling vendor script's own file.
# Returns 0 only if everything still matches; otherwise returns 1.
#
# As a side effect, this sets the handoff variable $_TDX_AUTO_CONF_CREATED to
# "1" if conf/auto.conf already existed, "0" otherwise.
#
# Passing an empty/omitted <eula-conf-var> skips the EULA half of the
# comparison entirely.
tdx_native_conf_is_current() {
    local eula_var="${1:-}"
    local oldmach="" olddisto="" eulaacpt="" eula_ok=1

    _TDX_AUTO_CONF_CREATED=0
    if [ -f conf/auto.conf ]; then
        oldmach=$(grep -E '^MACHINE \?=' conf/auto.conf | sed -e 's%^MACHINE ?= %%' -e 's/^"//' -e 's/"$//')
        olddisto=$(grep -E '^DISTRO \?=' conf/auto.conf | sed -e 's%^DISTRO ?= %%' -e 's/^"//' -e 's/"$//')
        _TDX_AUTO_CONF_CREATED=1
    fi

    if [ -n "${eula_var}" ] && [ -f conf/local.conf ]; then
        eulaacpt=$(grep -E "^[[:space:]]*${eula_var}[[:space:]]*=[[:space:]]*\".*\"" conf/local.conf |
                   sed -e "s%^[[:space:]]*${eula_var}[[:space:]]*=[[:space:]]*%%" -e 's/^"//' -e 's/"$//')
        if [ -n "${EULA:-}" ]; then
            [ "${EULA}" = "${eulaacpt}" ] || eula_ok=0
        else
            [ -n "${eulaacpt}" ] || eula_ok=0
        fi
    fi

    if [ -e conf/checksum ] && [ "${MACHINE:-}" = "${oldmach}" ] && \
       [ "${DISTRO:-}" = "${olddisto}" ] && [ "${eula_ok}" = "1" ]; then
        sha512sum --quiet -c conf/checksum >/dev/null 2>&1 && return 0
    fi
    return 1
}

# tdx_write_checksum <script-path>
#
# record the checksum of the calling vendor script itself.
tdx_write_checksum() {
    local script_path="${1:-}"
    sha512sum "${script_path}" > conf/checksum 2>&1
}

# tdx_conf_from_template <file...>
#
# for each <file>, if conf/<file> doesn't already exist, copy it from
# conf/template/<file> and substitute @OEROOT@ with $_TDX_OEROOT.
# No-op per-file if conf/<file> already exists.
tdx_conf_from_template() {
    local f
    for f in "$@"; do
        if [ ! -f "conf/${f}" ]; then
            cp "${_TDX_SCRIPTS}/../conf/template/${f}" "conf/${f}" || return 1
            sed -i "s|@OEROOT@|${_TDX_OEROOT}|g" "conf/${f}"
        fi
    done
}

# tdx_write_auto_conf <distro> <machine> <sdkmachine> <inherit-string>
#
# (re)write conf/auto.conf's DISTRO/MACHINE/SDKMACHINE ?= lines and the
# INHERIT += "<inherit-string>" line.
tdx_write_auto_conf() {
    local distro="${1:-}" machine="${2:-}" sdkmachine="${3:-}" inherit="${4:-}"

    if [ "${_TDX_AUTO_CONF_CREATED:-0}" = "0" ]; then
        cat >> conf/auto.conf <<EOF
DISTRO ?= "${distro}"
MACHINE ?= "${machine}"
SDKMACHINE ?= "${sdkmachine}"

# Extra options that can be changed by the user
INHERIT += "${inherit}"
EOF
    else
        sed -i "s/^DISTRO ?= \"[^\"]*\"\$/DISTRO ?= \"${distro}\"/" conf/auto.conf
        sed -i "s/^MACHINE ?= \"[^\"]*\"\$/MACHINE ?= \"${machine}\"/" conf/auto.conf
        sed -i "s/^SDKMACHINE ?= \"[^\"]*\"\$/SDKMACHINE ?= \"${sdkmachine}\"/" conf/auto.conf
    fi
}

# tdx_write_site_conf <oeroot> <builddir>
#
# (re)write conf/site.conf
tdx_write_site_conf() {
    local oeroot="${1:-}" builddir="${2:-}"

    cat > conf/site.conf <<EOF
SCONF_VERSION = "1"

# Where to store sources
DL_DIR ?= "${oeroot}/downloads"

# Where to save shared state
SSTATE_DIR ?= "${oeroot}/sstate-cache"
BB_HASHSERVE_DB_DIR ?= "\${SSTATE_DIR}"

# Where to save the build system work output
TMPDIR = "${builddir}/tmp"

# Where to save the packages and images
_TDX_DEPLOY_BASE = "${builddir}/deploy"
DEPLOY_DIR = "\${_TDX_DEPLOY_BASE}\${@'' if d.getVar('BB_CURRENT_MC') == 'default' else '/\${BB_CURRENT_MC}'}"

# Go through the Firewall
#HTTP_PROXY = "http://${PROXYHOST}:${PROXYPORT}/"
EOF
}

# tdx_is_integration_build
#
# returns 0 if manifest.xml resolves to/mentions integration.xml or next.xml,
# 1 otherwise.
tdx_is_integration_build() {
    local manifest_file="${_TDX_OEROOT}/.repo/manifest.xml"
    if [ ! -e "${manifest_file}" ] && [ ! -L "${manifest_file}" ]; then
        manifest_file="${_TDX_OEROOT}/.repo/manifests/manifest.xml"
    fi

    if [ -L "${manifest_file}" ]; then
        case "$(basename "$(readlink -f "${manifest_file}")")" in
            integration.xml|next.xml) return 0 ;;
            *) return 1 ;;
        esac
    elif [ -f "${manifest_file}" ]; then
        grep -qE '(integration\.xml|next\.xml)' "${manifest_file}" && return 0
    fi
    return 1
}

# tdx_apply_integration_override <target-conf-file>
#
# if tdx_is_integration_build, idempotently append the DISTROOVERRIDES
# ":use-head-next" block to <target-conf-file>.
# no-op if already present or not an integration build.
tdx_apply_integration_override() {
    local target="${1:-}"

    tdx_is_integration_build || return 0
    [ -f "${target}" ] && grep -qF 'DISTROOVERRIDES .= ":use-head-next"' "${target}" && return 0

    cat >> "${target}" <<'EOF'

# This is needed when building on integration. With use-head-next you
# always get the newest software (u-boot, kernel, aktualizr-torizon, etc).
# Building on integration without use-head-next your build may fail.
DISTROOVERRIDES .= ":use-head-next"
EOF
}

# tdx_needs_once <file> [<marker, default "# Torizon">]
#
# returns 0 if <file> doesn't exist, or exists but doesn't contain <marker> yet
# (i.e. the once-only block still needs to be appended); returns 1 if
# <marker> is already present.
tdx_needs_once() {
    local file="${1:-}" marker="${2:-# Torizon}"
    [ -f "${file}" ] || return 0
    grep -qF "${marker}" "${file}" && return 1
    return 0
}

# tdx_append_once <file> <marker> <<EOF ... EOF
#
# check file for <marker>, if file not create or marker not found, append stdin to
# <file>. Otherwise, drain stdin and do nothing.
#
# Usage example:
#   tdx_append_once conf/local.conf "# Torizon" <<EOF
#   # Torizon
#   INHERIT += "rm_work"
#   EOF
tdx_append_once() {
    local file="${1:-}" marker="${2:-}"
    if tdx_needs_once "${file}" "${marker}"; then
        cat >> "${file}"
    else
        cat >/dev/null  # drain stdin so callers can always pipe a heredoc in
    fi
}

# tdx_license_flag_accept <question-text> [<eula-file>]
#
# low-level interactive y/n prompt primitive.
# If <eula-file> is given, first asks if user wants to read it, then ask the
# actual accept/decline question. If <eula-file> is not given, only the
# accept/decline <question-text> is asked.
# All questions default answer is NO.
tdx_license_flag_accept() {
    local question="${1:-}" eula_file="${2:-}" reply=""

    if [ -n "${eula_file}" ]; then
        reply=""
        while [ -z "${reply}" ]; do
            echo -n "Would you like to read the EULA ? (y/N) "
            # EOF/closed stdin (e.g. a non-interactive run with no EULA env
            # var set) defaults to "n", same as a real answer of "n" - just
            # don't read it, still go on to ask the actual accept question.
            read -r reply || reply="n"
            case "${reply}" in
                y|Y) more -d "${eula_file}"; echo ;;
                n|N) : ;;
                *) reply="" ;;
            esac
        done
    fi

    reply=""
    while [ -z "${reply}" ]; do
        echo -n "${question} "
        # EOF/closed stdin defaults to "n" here too, same as a real decline.
        read -r reply || reply="n"
        case "${reply}" in
            y|Y) echo "EULA has been accepted."; return 0 ;;
            n|N) echo "EULA has not been accepted."; return 1 ;;
            *) reply="" ;;
        esac
    done
}

# tdx_eula_prompt <conf-var> <eula-file> [<label>]
#
# High-level EULA flow. Checks, in order:
#   1. an existing "<conf-var> = "..."" line already in conf/local.conf.
#   2. the $EULA environment variable.
#   3. otherwise, prompt interactively via tdx_license_flag_accept.
#
# <label>, if given, is used in the generated comment ("BSP depends on
# <label> packages and firmware..."); omit it for generic wording.
#
# Machines that need no EULA at all should skip this function.
#
# Returns 0 if accepted (or already accepted), 1 if declined.
tdx_eula_prompt() {
    local conf_var="${1:-}" eula_file="${2:-}" label="${3:-}"
    local accepted=""
    if [ -f conf/local.conf ] && \
       grep -qE "^[[:space:]]*${conf_var}[[:space:]]*=[[:space:]]*\"[^\"]*\"" conf/local.conf; then
        accepted=1
    fi

    if [ -z "${accepted}" ] && [ -n "${EULA:-}" ]; then
        cat >> conf/local.conf <<EOF

# BSP depends on ${label:+${label} }packages and firmware which are covered by an
# End User License Agreement (EULA). To have the right to use these
# binaries in the image, ${conf_var} must be set to '1'
${conf_var} = "${EULA}"
EOF
        return 0
    elif [ -n "${accepted}" ]; then
        if [ -n "${EULA:-}" ]; then
            sed -i "s/^[[:space:]]*${conf_var}[[:space:]]*=[[:space:]]*\"[^\"]*\"\$/${conf_var} = \"${EULA}\"/" conf/local.conf
        fi
        return 0
    else
        cat <<EOF

The BSP for ${MACHINE} depends on packages and firmware which are covered by an
End User License Agreement (EULA). To have the right to use these binaries
in your images, you need to read and accept the following...

EOF
        if tdx_license_flag_accept "Do you accept the EULA you just read? (y/N)" "${eula_file}"; then
            cat >> conf/local.conf <<EOF

# BSP depends on ${label:+${label} }packages and firmware which are covered by an
# End User License Agreement (EULA). To have the right to use these
# binaries in the image, ${conf_var} must be set to '1'
${conf_var} = "1"
EOF
            return 0
        else
            return 1
        fi
    fi
}

# tdx_append_license_flags <file> <flag...>
#
# append a LICENSE_FLAGS_ACCEPTED += "<flag> ..." line to <file>.
tdx_append_license_flags() {
    local file="${1:-}"
    shift
    cat >> "${file}" <<EOF

LICENSE_FLAGS_ACCEPTED += "$*"
EOF
}

# tdx_print_banner <title> <show-sdkmachine:yes|no> [<trailer-fn-name>]
#
# print the standard "Welcome to <title>" banner.
# If <trailer-fn-name> is given and names a currently-declared function,
# it is called after the banner.
tdx_print_banner() {
    local title="${1:-}" show_sdk="${2:-no}" trailer_fn="${3:-}"

    cat <<EOF

Welcome to ${title}

For more information about OpenEmbedded see their website:

    http://www.openembedded.org/

Your build environment has been configured with:

    MACHINE = ${MACHINE}
EOF

    if [ "${show_sdk}" = "yes" ]; then
        cat <<EOF
    SDKMACHINE = ${SDKMACHINE}
EOF
    fi

    cat <<EOF
    DISTRO = ${DISTRO}

You can now run 'bitbake <target>'

Some of common targets are:

    torizon-docker
    torizon-minimal
    torizon-podman

EOF

    if [ -n "${trailer_fn}" ] && declare -F "${trailer_fn}" >/dev/null 2>&1; then
        "${trailer_fn}"
    fi
}

# tdx_cleanup_internal_state
#
# unset every internal _TDX_* helper variable and _tdx_*/tdx_* function this file
# (and the dispatcher) introduce, via a fixed, explicit allowlist. User-visible
# variables (MACHINE, DISTRO, SDKMACHINE, BUILDDIR, PATH,
# BB_ENV_PASSTHROUGH_ADDITIONS) are intentionally never touched
# here - they must survive for the user's shell/bitbake invocations.
#
# Vendor scripts (rewritten in a later phase against this API) may register
# their own additional one-off internal names for cleanup by appending to
# the _TDX_EXTRA_CLEANUP_VARS/_TDX_EXTRA_CLEANUP_FUNCS arrays before
# returning, e.g.:
#   _TDX_EXTRA_CLEANUP_VARS+=("_TDX_MY_HELPER")
# without needing to modify this fixed allowlist.
tdx_cleanup_internal_state() {
    local -a allow_vars=(
        _TDX_CORE_SH_LOADED
        _TDX_CORE_DIR
        _TDX_LAYERS_DIR
        _TDX_SOURCE_PATH
        _TDX_SCRIPTS
        _TDX_SCRIPTS_PATH
        _TDX_MANIFESTS
        _TDX_BUILDDIR
        _TDX_DIALOG_UTIL
        _TDX_DISTRO_SELECT
        _TDX_VENDOR
        _TDX_MENU_ARGS
        _TDX_MENU_M
        _TDX_MENU_D
        _TDX_AUTO_CONF_CREATED
        _TDX_OEROOT
    )
    local -a allow_funcs=(
        _tdx_lib_conf_path
        _tdx_machines_conf_path
        _tdx_distros_conf_path
        tdx_distro_pairs
        _tdx_dispatch
        _tdx_run_dispatch
        tdx_compute_oeroot
        tdx_set_builddir
        tdx_set_builddir_from_cwd
        tdx_vendor_for_machine
        tdx_distro_policy_for_machine
        tdx_apply_distro_policy
        tdx_menu_pairs
        tdx_usage
        tdx_setup_path
        tdx_dedupe_sort
        tdx_setup_bb_env_passthrough
        tdx_native_conf_is_current
        tdx_write_checksum
        tdx_conf_from_template
        tdx_write_auto_conf
        tdx_write_site_conf
        tdx_is_integration_build
        tdx_apply_integration_override
        tdx_needs_once
        tdx_append_once
        tdx_license_flag_accept
        tdx_eula_prompt
        tdx_append_license_flags
        tdx_print_banner
        tdx_cleanup_internal_state
    )
    local v f

    for v in "${_TDX_EXTRA_CLEANUP_VARS[@]:-}"; do
        [ -n "${v}" ] && unset -v "${v}" 2>/dev/null
    done
    for f in "${_TDX_EXTRA_CLEANUP_FUNCS[@]:-}"; do
        [ -n "${f}" ] && unset -f "${f}" 2>/dev/null
    done
    unset -v _TDX_EXTRA_CLEANUP_VARS _TDX_EXTRA_CLEANUP_FUNCS 2>/dev/null

    for v in "${allow_vars[@]}"; do
        unset -v "${v}" 2>/dev/null
    done
    for f in "${allow_funcs[@]}"; do
        unset -f "${f}" 2>/dev/null
    done
}
