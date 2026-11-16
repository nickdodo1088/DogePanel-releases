#!/bin/bash
# Installs or upgrades DogePanel (docs/refactor-plan.md 5.13):
#
#   bash quick_start.sh [options] [options of install.sh or upgrade.sh]
#
# It downloads the release package for this machine from GitHub Releases, checks its
# signature, decrypts it with the password of the release files, extracts it and runs
# install.sh, or upgrade.sh when DogePanel is installed. With --package it uses a package
# that is already here, for servers without Internet access; --decrypt decrypts one other
# release file, such as the aaPanel export tool. Nothing is decrypted or run before it is
# checked, no other script is downloaded, and nothing is reported anywhere.
#
# The files of the version this script was released with are checked against the SHA-256
# built into it. Other versions are checked against their signed manifest, which needs
# OpenSSL 3.0 or newer (ed25519 with -rawin). Decrypting needs OpenSSL 1.1.1 (-pbkdf2).
set -euo pipefail

# The release files are published, encrypted, in a public repository of their own
# (docs/refactor-plan.md 5.13).
DP_REPO=nickdodo1088/DogePanel-releases
DP_RELEASES=https://github.com/$DP_REPO/releases
# Base64 ed25519 public keys of the release signing key, separated by spaces (the same as
# PublicKeys in core/utils/signature). scripts/package.sh fills them in.
DP_RELEASE_PUBKEYS="biFqQWT6/o8hKRA1Cgk51RdAecdpywA8/xaHq6sRZsE="
# The version this script was released with, and the SHA-256 of every file of that release,
# encrypted and plain, as "name=sha256" separated by spaces: scripts/package.sh fills them
# in. They check the files of this version without OpenSSL 3 (docs/refactor-plan.md 5.13).
# They come from the same release as the public keys above, so they are trusted as much.
DP_PINNED_VERSION="v2.3.2-dp.47"
DP_PINNED_SHA256="1panel-v2.3.2-dp.47-linux-amd64.tar.gz=2fcb6066c1c4d72d7d4258d7b6bb07b8beae04852a0b0508da79a8352babfcfe aapanel-export-linux-amd64=522303d2fde3773f42a2a01dc7c718692b44b537353ea925c3d85994039eaed6 1panel-v2.3.2-dp.47-linux-arm64.tar.gz=ba7b1c7cfd538a2480cac6928777166021203885deea8db253e8080d407eca09 aapanel-export-linux-arm64=0a9cc894bcc5de8f7e904797fddd6324aea868cca0695c178fe434a1849edb9b dogepanel-v2.3.2-dp.47-source.tar.gz=f8e837a32fe258de2bd7d516b599baf86e09e1911df828b79135f094bb89706f 1panel-v2.3.2-dp.47-linux-amd64.tar.gz.enc=e355f816066ee287aa70a5b0d4b3a7a9727df444ec2013b135695961043799cf aapanel-export-linux-amd64.enc=758008b878b45ad18578613d797fa385da70bbdd7a8a0ca44631abebab3a01c7 1panel-v2.3.2-dp.47-linux-arm64.tar.gz.enc=cd202aaa3e3c0743e4bd2c1802c5aa7929fc3343349249ac885ffba54b098c5e aapanel-export-linux-arm64.enc=2a45df784ce57bbac94713422ee3d3c8ef9553bffe997969036a46458fad9f68 dogepanel-v2.3.2-dp.47-source.tar.gz.enc=8eba81bef70e52d8a1bd8e2e1ef4bf5889a862f5a983407ca9d0056aa0e61ef0"
# PBKDF2 iterations of the encryption of the release files: the same as ENC_ITER in
# scripts/package.sh.
DP_ENC_ITER=600000

VERSION=''
PACKAGE=''
MANIFEST=''
SIGNATURE=''
PASSWORD_FILE=''
DECRYPT=''
VERIFY_ONLY=0
KEEP=0
PASS=()
WORK=''
RELEASE_PASSWORD=''
PLAIN=''
# How files are checked: "pinned" against DP_PINNED_SHA256, "signed" against MANIFEST once its
# signature is checked.
CHECK=''

if [[ ${LC_ALL:-${LC_MESSAGES:-${LANG:-}}} == zh* ]]; then MSG_LANG=zh; else MSG_LANG=en; fi

# text prints message $1, formatted with the other arguments, in the language of the system.
text() {
    local zh en
    case "$1" in
    root) zh="请用 root 运行，比如先执行：sudo -i" en="Run this script as root, for example with: sudo -i" ;;
    tool) zh="缺少命令：%s" en="Missing command: %s" ;;
    openssl) zh="校验 %s 的签名需要 OpenSSL 3.0 或更新的版本（这台机器是：%s）。请重新下载最新的 quick_start.sh 再运行：它不用 OpenSSL 3.0 就能装自己那个版本。" en="Checking the signature of %s needs OpenSSL 3.0 or newer (found: %s). Download the latest quick_start.sh and run it again: it installs its own version without OpenSSL 3.0." ;;
    noopenssl) zh="解密需要 OpenSSL 1.1.1 或更新的版本，这台机器上没有 openssl。请先安装它（Debian、Ubuntu：apt install -y openssl；CentOS、Rocky：yum install -y openssl），再运行一次。" en="Decrypting needs OpenSSL 1.1.1 or newer, and there is no openssl here. Install it (Debian, Ubuntu: apt install -y openssl; CentOS, Rocky: yum install -y openssl), then run this again." ;;
    oldopenssl) zh="这台机器的 OpenSSL（%s）太旧，解不了密。请在一台 OpenSSL 1.1.1 以上的机器上运行 bash quick_start.sh --decrypt <文件>.enc，把解出来的 .tar.gz 和 quick_start.sh 复制到这里，再运行 bash quick_start.sh --package <.tar.gz 文件>。" en="The OpenSSL here (%s) is too old to decrypt the release files. On a machine with OpenSSL 1.1.1 or newer, run bash quick_start.sh --decrypt <file>.enc, copy the .tar.gz and quick_start.sh here, then run bash quick_start.sh --package <the .tar.gz>." ;;
    nokey) zh="这个脚本里没有发版公钥，无法校验安装包。请从 DogePanel 的发布页下载 quick_start.sh。" en="This script has no release public key, so no package can be checked. Download quick_start.sh from the DogePanel releases page." ;;
    arch) zh="不支持的架构：%s" en="Unsupported architecture: %s" ;;
    latest) zh="取不到最新版本号（%s）。可以用 --version 指定版本。" en="Could not find the latest version (%s). Give one with --version." ;;
    download) zh="正在下载 %s" en="Downloading %s" ;;
    fetch) zh="下载失败：%s" en="Download failed: %s" ;;
    missing) zh="找不到文件：%s" en="No such file: %s" ;;
    badsig) zh="校验失败：%s。没有安装任何东西。" en="Check failed: %s. Nothing was installed." ;;
    verified) zh="已校验：%s（%s）" en="Verified: %s (%s)" ;;
    extracted) zh="已解压到 %s" en="Extracted to %s" ;;
    option) zh="参数 %s 缺少值" en="Option %s needs a value" ;;
    password) zh="请输入安装密码（向维护者索取，输入时不显示）：" en="Installation password (from the maintainer; it is not shown): " ;;
    passfile) zh="读不到密码文件：%s" en="Cannot read the password file: %s" ;;
    nopassword) zh="需要安装密码：请在终端里运行本脚本并输入密码，或者用 --release-password-file 指定密码文件。" en="The installation password is needed: run this script at a terminal and type it, or give a file with --release-password-file." ;;
    wrongpass) zh="解密失败：%s。安装密码不对，或者文件已损坏。" en="Could not decrypt %s: wrong installation password, or a damaged file." ;;
    notenc) zh="不是加密的发布文件（.enc）：%s" en="Not an encrypted release file (.enc): %s" ;;
    decrypted) zh="已解密：%s" en="Decrypted: %s" ;;
    *) zh=$1 en=$1 ;;
    esac
    local format=$en
    [ "$MSG_LANG" = zh ] && format=$zh
    shift
    # shellcheck disable=SC2059 # the messages are the formats
    printf "$format" "$@"
}

msg() {
    text "$@"
    printf '\n'
}

die() {
    msg "$@" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: bash quick_start.sh [options] [options of install.sh or upgrade.sh]

  --version VERSION    install this version (default: the latest release)
  --package FILE       use this package instead of downloading one: the encrypted
                       1panel-<version>-linux-<arch>.tar.gz.enc of a release, or the
                       decrypted .tar.gz; for another version than this script's,
                       manifest.json and manifest.json.sig are looked for next to it
  --manifest FILE      the manifest.json of --package or --decrypt
  --signature FILE     the manifest.json.sig of --package or --decrypt
  --release-password-file FILE
                       read the installation password from the first line of FILE
                       instead of asking for it
  --decrypt FILE       check and decrypt one release file, such as
                       aapanel-export-linux-amd64.enc; one of another release than this
                       script's needs manifest.json and manifest.json.sig next to it;
                       the result goes next to it
  --verify-only        check, decrypt and extract the package, then stop
  --keep               keep the downloaded and extracted files
  -h, --help           show this help

Other options go to install.sh (see ./install.sh --help in the package) or upgrade.sh.

The files of this script's own version are checked against the SHA-256 built into it;
other versions need OpenSSL 3.0 to check their signature. Decrypting needs OpenSSL 1.1.1.
EOF
}

value() {
    [ $# -ge 2 ] || die option "$1"
    printf '%s' "$2"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
        --version)
            VERSION=$(value "$@")
            shift
            ;;
        --package)
            PACKAGE=$(value "$@")
            shift
            ;;
        --manifest)
            MANIFEST=$(value "$@")
            shift
            ;;
        --signature)
            SIGNATURE=$(value "$@")
            shift
            ;;
        --release-password-file)
            PASSWORD_FILE=$(value "$@")
            shift
            ;;
        --decrypt)
            DECRYPT=$(value "$@")
            shift
            ;;
        --verify-only) VERIFY_ONLY=1 ;;
        --keep) KEEP=1 ;;
        --lang)
            local language
            language=$(value "$@")
            case "$language" in
            zh | zh-* | zh_*) MSG_LANG=zh ;;
            *) MSG_LANG=en ;;
            esac
            PASS+=("--lang" "$language")
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) PASS+=("$1") ;;
        esac
        shift
    done
}

arch() {
    case "$(uname -m)" in
    x86_64 | amd64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    armv7l | armv7*) echo armv7 ;;
    ppc64le) echo ppc64le ;;
    s390x) echo s390x ;;
    *) die arch "$(uname -m)" ;;
    esac
}

need_tools() {
    local tool
    for tool in tar sha256sum awk mktemp; do
        command -v "$tool" >/dev/null 2>&1 || die tool "$tool"
    done
}

# need_signature makes sure the signature of version $1 can be checked: ed25519 with -rawin
# came with OpenSSL 3.0.
need_signature() {
    local tool version
    for tool in base64 openssl; do
        command -v "$tool" >/dev/null 2>&1 || die tool "$tool"
    done
    version=$(openssl version 2>/dev/null) || version=openssl
    case "$version" in
    "OpenSSL "[3-9].* | "OpenSSL "[1-9][0-9].*) ;;
    *) die openssl "$1" "$version" ;;
    esac
}

# need_decrypt makes sure OpenSSL can decrypt the release files: -pbkdf2 came with 1.1.1.
need_decrypt() {
    local help
    command -v openssl >/dev/null 2>&1 || die noopenssl
    # Not a pipe: under pipefail, the status of "openssl enc -help" would count.
    help=$(openssl enc -help 2>&1) || true
    [[ $help == *-pbkdf2* ]] || die oldopenssl "$(openssl version 2>/dev/null || echo openssl)"
}

# fetch downloads URL $1 to file $2 over HTTPS, checking the certificate.
fetch() {
    msg download "$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 15 -o "$2" "$1" || die fetch "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --https-only --tries=3 --timeout=30 -O "$2" "$1" || die fetch "$1"
    else
        die tool "curl / wget"
    fi
}

# latest_version follows the redirect of releases/latest to the tag of the newest
# release, without the GitHub API and its rate limit.
latest_version() {
    local url=''
    if command -v curl >/dev/null 2>&1; then
        url=$(curl -fsSIL --proto '=https' --tlsv1.2 -o /dev/null -w '%{url_effective}' "$DP_RELEASES/latest") || url=''
    elif command -v wget >/dev/null 2>&1; then
        url=$(wget --https-only --max-redirect=5 -S --spider "$DP_RELEASES/latest" 2>&1 | awk 'tolower($1) == "location:" { location = $2 } END { print location }') || url=''
    fi
    url=${url%$'\r'}
    printf '%s' "${url##*/}"
}

valid_version() {
    [[ $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-dp\.[0-9]+)?$ ]]
}

# verify_manifest checks the signature $2 of manifest $1 against the built-in keys and, when
# $3 is given, that the manifest is for version $3.
verify_manifest() {
    local manifest=$1 signature=$2 version=$3 tmp key verified=0
    [ -n "$DP_RELEASE_PUBKEYS" ] || die nokey
    tmp=$(mktemp -d)
    if ! base64 -d <"$signature" >"$tmp/signature.bin" 2>/dev/null; then
        rm -rf "$tmp"
        die badsig "manifest.json.sig"
    fi
    for key in $DP_RELEASE_PUBKEYS; do
        [[ $key =~ ^[A-Za-z0-9+/]{43}=$ ]] || continue
        # The DER prefix of an ed25519 public key, base64 encoded, makes the raw key a PEM.
        printf -- '-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA%s\n-----END PUBLIC KEY-----\n' "$key" >"$tmp/key.pem"
        if openssl pkeyutl -verify -pubin -inkey "$tmp/key.pem" -rawin -in "$manifest" \
            -sigfile "$tmp/signature.bin" >/dev/null 2>&1; then
            verified=1
            break
        fi
    done
    rm -rf "$tmp"
    [ "$verified" = 1 ] || die badsig "manifest.json"
    # The manifest is the indented JSON of release-sign: one "name": "value" per line.
    if [ -n "$version" ]; then
        [ "$(awk -F'"' '$2 == "version" { print $4; exit }' "$manifest")" = "$version" ] || die badsig "version $version"
    fi
}

# pinned_version reports whether version $1 is the one this script was released with, whose
# files it checks against the SHA-256 built in.
pinned_version() {
    [ -n "$DP_PINNED_VERSION" ] && [ "$1" = "$DP_PINNED_VERSION" ]
}

# expected_sum prints the SHA-256 listed for the file named $1: built in (CHECK=pinned) or in
# MANIFEST (CHECK=signed).
expected_sum() {
    local entry
    if [ "$CHECK" = pinned ]; then
        for entry in $DP_PINNED_SHA256; do
            if [ "${entry%%=*}" = "$1" ]; then
                printf '%s' "${entry#*=}"
                return 0
            fi
        done
        return 0
    fi
    # The manifest is the indented JSON of release-sign: one "name": "value" per line.
    awk -F'"' -v name="$1" '$2 == name { print $4; exit }' "$MANIFEST"
}

# check_file reports whether file $1 has the SHA-256 listed for the name $2, by default the
# name of the file.
check_file() {
    local want got
    want=$(expected_sum "${2:-$(basename "$1")}")
    got=$(sha256sum "$1" | awk '{ print $1 }')
    [ -n "$want" ] && [ "$want" = "$got" ]
}

# choose_check decides how the files of version $3 are checked: against the SHA-256 built in
# when it is this script's own version, else against manifest $1, once its signature $2 is
# checked.
choose_check() {
    MANIFEST=$1
    if pinned_version "$3"; then
        CHECK=pinned
        return 0
    fi
    need_signature "$3"
    verify_manifest "$1" "$2" "$3"
    CHECK=signed
}

# read_password gets the password of the release files, once: from --release-password-file,
# or typed at the terminal without being shown. It is never written anywhere.
read_password() {
    [ -z "$RELEASE_PASSWORD" ] || return 0
    if [ -n "$PASSWORD_FILE" ]; then
        [ -f "$PASSWORD_FILE" ] && [ -r "$PASSWORD_FILE" ] || die passfile "$PASSWORD_FILE"
        IFS= read -r RELEASE_PASSWORD <"$PASSWORD_FILE" || true
    elif { exec 3</dev/tty; } 2>/dev/null; then
        read -r -s -u 3 -p "$(text password)" RELEASE_PASSWORD || RELEASE_PASSWORD=''
        exec 3<&-
        echo >&2
    fi
    RELEASE_PASSWORD=${RELEASE_PASSWORD%$'\r'}
    [ -n "$RELEASE_PASSWORD" ] || die nopassword
}

# decrypt writes file $2, the decryption of release file $1 (encrypt in scripts/package.sh).
# The password goes through the environment, not the command line.
decrypt() {
    DP_RELEASE_PASSWORD=$RELEASE_PASSWORD openssl enc -d -aes-256-cbc -pbkdf2 -iter "$DP_ENC_ITER" -md sha256 \
        -in "$1" -out "$2" -pass env:DP_RELEASE_PASSWORD 2>/dev/null
}

# verify_package checks package $3 of version $4, against the SHA-256 built in or manifest $1
# signed with $2 (choose_check), and sets PLAIN to the checked package to extract. An
# encrypted package (.enc) is decrypted into WORK only after its own check, and the result
# is checked too; a decrypted one is checked as it is.
verify_package() {
    local package=$3 version=$4 name
    choose_check "$1" "$2" "$version"
    name=$(basename "$package")
    check_file "$package" || die badsig "$name"
    if [[ $name == *.enc ]]; then
        name=${name%.enc}
        need_decrypt
        read_password
        PLAIN=$WORK/$name
        if ! decrypt "$package" "$PLAIN" || ! check_file "$PLAIN"; then
            rm -f "$PLAIN"
            die wrongpass "$(basename "$package")"
        fi
    else
        PLAIN=$package
    fi
    msg verified "$name" "$version"
}

# decrypt_file checks and decrypts release file $1 (.enc), such as the aaPanel export tool or
# the source code, and writes the result next to it, without the .enc. A file of this
# script's own release is checked against the SHA-256 built in, any other against the
# signed manifest next to it.
decrypt_file() {
    local file=$1 plain
    [[ $file == *.enc ]] || die notenc "$file"
    [ -f "$file" ] || die missing "$file"
    CHECK=pinned
    if ! check_file "$file"; then
        MANIFEST=${MANIFEST:-$(dirname "$file")/manifest.json}
        SIGNATURE=${SIGNATURE:-$(dirname "$file")/manifest.json.sig}
        need_signature "$(basename "$file")"
        verify_manifest "$MANIFEST" "$SIGNATURE" ''
        CHECK=signed
        check_file "$file" || die badsig "$(basename "$file")"
    fi
    need_decrypt
    read_password
    plain=${file%.enc}
    if ! decrypt "$file" "$plain.part" || ! check_file "$plain.part" "$(basename "$plain")"; then
        rm -f "$plain.part"
        die wrongpass "$(basename "$file")"
    fi
    mv -f "$plain.part" "$plain"
    msg decrypted "$plain"
}

cleanup() {
    if [ "$KEEP" = 0 ] && [ -n "$WORK" ]; then
        rm -rf "$WORK"
    fi
}

main() {
    local arch_name name dir
    parse_args "$@"
    if [ "$VERIFY_ONLY" = 0 ] && [ -z "$DECRYPT" ] && [ "$(id -u)" -ne 0 ]; then
        die root
    fi
    need_tools
    if [ -n "$DECRYPT" ]; then
        decrypt_file "$DECRYPT"
        return 0
    fi
    arch_name=$(arch)
    WORK=$(mktemp -d /tmp/dogepanel.XXXXXX)
    trap cleanup EXIT

    if [ -n "$PACKAGE" ]; then
        [ -f "$PACKAGE" ] || die missing "$PACKAGE"
        name=$(basename "${PACKAGE%.enc}")
        VERSION=${name#1panel-}
        VERSION=${VERSION%-linux-*}
        MANIFEST=${MANIFEST:-$(dirname "$PACKAGE")/manifest.json}
        SIGNATURE=${SIGNATURE:-$(dirname "$PACKAGE")/manifest.json.sig}
        valid_version "$VERSION" || die badsig "$name"
    else
        if [ -z "$VERSION" ]; then
            VERSION=$(latest_version)
            valid_version "$VERSION" || die latest "$DP_RELEASES/latest"
        fi
        valid_version "$VERSION" || die badsig "$VERSION"
        name=1panel-$VERSION-linux-$arch_name.tar.gz
        PACKAGE=$WORK/$name.enc
        MANIFEST=$WORK/manifest.json
        SIGNATURE=$WORK/manifest.json.sig
        # What this machine lacks shows before the download, not after it.
        need_decrypt
        if ! pinned_version "$VERSION"; then
            need_signature "$VERSION"
            fetch "$DP_RELEASES/download/$VERSION/manifest.json" "$MANIFEST"
            fetch "$DP_RELEASES/download/$VERSION/manifest.json.sig" "$SIGNATURE"
        fi
        fetch "$DP_RELEASES/download/$VERSION/$name.enc" "$PACKAGE"
    fi

    # Nothing from the package is decrypted or opened before this check.
    verify_package "$MANIFEST" "$SIGNATURE" "$PACKAGE" "$VERSION"
    tar -xzf "$PLAIN" -C "$WORK"
    dir=$WORK/${name%.tar.gz}
    [ -f "$dir/install.sh" ] || die badsig "$name"
    msg extracted "$dir"
    if [ "$VERIFY_ONLY" = 1 ]; then
        KEEP=1
        return 0
    fi
    # The installation password goes on to the panel, for its own upgrades
    # (docs/refactor-plan.md 11), in the environment of the script, not on a command line.
    # ${PASS[@]+...}: bash before 4.4 calls an empty array unbound under set -u.
    # An installation is in /opt/dogepanel; a dgpctl in /usr/local/bin alone may be a link to
    # another one, such as that of a development instance, which install.sh refuses to replace.
    if [ -f /opt/dogepanel/dgpctl ]; then
        DP_RELEASE_PASSWORD=$RELEASE_PASSWORD bash "$dir/upgrade.sh" ${PASS[@]+"${PASS[@]}"}
    else
        DP_RELEASE_PASSWORD=$RELEASE_PASSWORD bash "$dir/install.sh" ${PASS[@]+"${PASS[@]}"}
    fi
}

# Run unless sourced (the tests source the functions); "return" works only when sourced.
# This also holds for "curl ... | bash", where there is no script file.
if ! (return 0 2>/dev/null); then
    main "$@"
fi
