#!/bin/sh

# The URL of the script project is:
# https://github.com/XTLS/Xray-install

FILES_PATH=${FILES_PATH:-./}

# Gobal verbals

# Xray current version
CURRENT_VERSION=''

# Xray latest release version
RELEASE_LATEST=''

get_current_version() {
    # Get the CURRENT_VERSION
    if [[ -f "${FILES_PATH}/ray" ]]; then
        CURRENT_VERSION="$(${FILES_PATH}/ray -version | awk 'NR==1 {print $2}')"
        CURRENT_VERSION="v${CURRENT_VERSION#v}"
    else
        CURRENT_VERSION=""
    fi
}

get_latest_version() {
    # Get Xray latest release version number
    local tmp_file
    tmp_file="$(mktemp)"
    if ! curl -sS -H "Accept: application/vnd.github.v3+json" -o "$tmp_file" 'https://api.github.com/repos/XTLS/Xray-core/releases/latest'; then
        "rm" "$tmp_file"
        echo 'error: Failed to get release list, please check your network.'
        exit 1
    fi
    RELEASE_LATEST="$(jq .tag_name "$tmp_file" | sed 's/\"//g')"
    if [[ -z "$RELEASE_LATEST" ]]; then
        if grep -q "API rate limit exceeded" "$tmp_file"; then
            echo "error: github API rate limit exceeded"
        else
            echo "error: Failed to get the latest release version."
        fi
        "rm" "$tmp_file"
        exit 1
    fi
    "rm" "$tmp_file"
}

download_xray() {
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$RELEASE_LATEST/Xray-linux-64.zip"
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    return 0
    if ! wget -qO "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        return 1
    fi

    # Verification of Xray archive
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$(${LISTSUM}sum "$ZIP_FILE" | sed 's/ .*//')"
        CHECKSUM="$(grep ${LISTSUM^^} "$ZIP_FILE".dgst | grep "$SUM" -o -a | uniq)"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            echo 'error: Check failed! Please check your network or try again.'
            return 1
        fi
    done
}

decompression() {
    busybox unzip -q "$1" -d "$TMP_DIRECTORY"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
}

install_xray() {
    install -m 755 ${TMP_DIRECTORY}/xray ${FILES_PATH}/web
}

# Two very important variables
TMP_DIRECTORY="$(mktemp -d)"
ZIP_FILE="${TMP_DIRECTORY}/web.zip"

get_current_version
get_latest_version
if [ "${RELEASE_LATEST}" = "${CURRENT_VERSION}" ]; then
    "rm" -rf "$TMP_DIRECTORY"
    exit 0
fi
download_xray
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]; then
    :
else
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
fi
decompression "$ZIP_FILE"
install_xray
"rm" -rf "$TMP_DIRECTORY"

cp -f ./config.yaml /tmp/config.yaml
sed -i "s|PASSWORD|${PASSWORD}|g;s|WSPATH|${WSPATH}|g" /tmp/config.yaml
./web -c /tmp/config.yaml 2>&1 >/dev/null