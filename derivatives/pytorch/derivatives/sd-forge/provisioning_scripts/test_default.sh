#!/bin/bash

source /venv/main/bin/activate
FORGE_DIR=${WORKSPACE}/stable-diffusion-webui-forge

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(

)

EXTENSIONS=(
    # "https://github.com/deforum-art/sd-webui-deforum"
    # "https://github.com/Tok/sd-forge-deforum.git"
    "https://github.com/adieyal/sd-dynamic-prompts"
    # "https://github.com/ototadana/sd-face-editor"
    "https://github.com/AlUlkesh/stable-diffusion-webui-images-browser"
    # "https://github.com/Haoming02/sd-forge-couple"
    "https://github.com/Katsuyuki-Karasawa/stable-diffusion-webui-localization-ja_JP"
    "https://github.com/altoiddealer/--sd-webui-ar-plusplus"
    "https://github.com/hako-mikan/sd-webui-lora-block-weight"
    "https://github.com/zixaphir/Stable-Diffusion-Webui-Civitai-Helper"
    "https://github.com/DominikDoom/a1111-sd-webui-tagcomplete"
    "https://github.com/Bing-su/adetailer"
    # "https://github.com/Zyin055/Config-Presets"
)

CHECKPOINT_MODELS=(
    "https://huggingface.co/rimOPS/IllustriousBased/resolve/main/vxpILXL_v12.safetensors"
)

UNET_MODELS=(
)

LORA_MODELS=(
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
    "https://huggingface.co/rimOPS/upscaler/resolve/main/4x_NMKD-YandereNeoXL_200k.pth"
)

CONTROLNET_MODELS=(
)

function base_config(){
    cd "${FORGE_DIR}/"
    wget -q "https://raw.githubusercontent.com/osuiso-depot/docker-stable-diffusion-webui-forge/refs/heads/main/config/provisioning/config.json"
    wget -q "https://raw.githubusercontent.com/osuiso-depot/docker-stable-diffusion-webui-forge/refs/heads/main/config/provisioning/ui-config.json"
}

function extensions_config() {
    # まず、$WORKSPACE 内に tmp フォルダを作成
    mkdir -p "${WORKSPACE}/tmp"
    if [ $? -ne 0 ]; then
        echo "Failed to create tmp directory"
    fi

    # tmp フォルダに移動
    cd "${WORKSPACE}/tmp"
    if [ $? -ne 0 ]; then
        echo "Failed to change directory to tmp"
    fi

    # リポジトリをクローン
    git clone "https://${GITHUB_TOKEN}@github.com/osuiso-depot/MySDWEBUI_config_private.git"
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository"
    fi

    # クローンしたリポジトリがある場所に移動
    cd "${WORKSPACE}/tmp/MySDWEBUI_config_private"
    if [ $? -ne 0 ]; then
        echo "Failed to change directory to cloned repository"
    fi

    # wildcards フォルダを目的のディレクトリに移動
    mv "wildcards" "${FORGE_DIR}/extensions/sd-dynamic-prompts/"
    if [ $? -ne 0 ]; then
        echo "Failed to move wildcards directory"
    fi

    # Lora-block-weight プリセットを目的のディレクトリに移動
    mv "lbwpresets.txt" "${FORGE_DIR}/extensions/sd-webui-lora-block-weight/scripts"
    if [ $? -ne 0 ]; then
        echo "Failed move lbwpresets.txt"
    fi

    # styles.csv を目的のディレクトリに移動
    mv "styles.csv" "${FORGE_DIR}"
    mv "styles_integrated.csv" "${FORGE_DIR}"
    if [ $? -ne 0 ]; then
        echo "Failed move styles.csv"
    fi


}


### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_extensions
    provisioning_get_pip_packages
    provisioning_get_files \
        "${FORGE_DIR}/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${FORGE_DIR}/models/Lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${FORGE_DIR}/models/ControlNet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${FORGE_DIR}/models/VAE" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${FORGE_DIR}/models/ESRGAN" \
        "${ESRGAN_MODELS[@]}"

    # Avoid git errors because we run as root but files are owned by 'user'
    export GIT_CONFIG_GLOBAL=/tmp/temporary-git-config
    git config --file $GIT_CONFIG_GLOBAL --add safe.directory '*'

    base_config
    extensions_config

    # Start and exit because webui will probably require a restart
    cd "${FORGE_DIR}"
    LD_PRELOAD=libtcmalloc_minimal.so.4 \
        python launch.py \
            --skip-python-version-check \
            --no-download-sd-model \
            --do-not-download-clip \
            --no-half \
            --port 11404 \
            --exit

    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_extensions() {
    for repo in "${EXTENSIONS[@]}"; do
        dir="${repo##*/}"
        path="${FORGE_DIR}/extensions/${dir}"
        if [[ ! -d $path ]]; then
            printf "Downloading extension: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi

    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    # 認証トークンを選択
    if [[ $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
        if [[ -n $auth_token ]]; then
            echo "Downloading with token..."
            wget --header="Authorization: Bearer $auth_token" --content-disposition --show-progress -q -P "$2" "$1"
        else
            echo "Downloading without token..."
            wget --content-disposition --show-progress -q -P "$2" "$1"
        fi
    elif [[ $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|/api/download/models/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
        if [[ -n $auth_token ]]; then
            echo "Downloading with token..."
            wget "$1?token=$auth_token" --content-disposition --show-progress -q -P "$2"
        else
            echo "Downloading without token..."
            wget "$1" --content-disposition --show-progress -q -P "$2"
        fi
    fi

}

provisioning_start
