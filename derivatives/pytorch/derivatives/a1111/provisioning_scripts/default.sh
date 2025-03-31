#!/bin/bash

source /venv/main/bin/activate
A1111_DIR=${WORKSPACE}/stable-diffusion-webui

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
    "https://huggingface.co/rimOPS/TESTModels/resolve/main/NDDN3v3_VAE.safetensors"
    "https://huggingface.co/rimOPS/TESTModels/resolve/main/NELLv2_VAE.safetensors"
)

UNET_MODELS=(
)

LORA_MODELS=(
    "https://huggingface.co/rimOPS/latestLora/resolve/main/Concept/%E7%94%BB%E9%A2%A8%EF%BC%8F194-flat/flat.safetensors"
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
    "https://huggingface.co/rimOPS/upscaler/resolve/main/RealESRGAN_x4plus_anime_6B.pth"
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/webui/ControlNet-modules-safetensors/resolve/main/t2iadapter_openpose-fp16.safetensors"
    "https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/ip-adapter_sd15_plus.pth"
    "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11f1e_sd15_tile_fp16.safetensors"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###


function base_config(){
    cd "${WORKSPACE}/stable-diffusion-webui/embeddings"
    wget -q "https://huggingface.co/rimOPS/embeddings/resolve/main/EasyNegative.pt"

    cd "${WORKSPACE}/stable-diffusion-webui/"
    wget -q "https://raw.githubusercontent.com/osuiso-depot/docker-vastia-base-image/refs/heads/main/derivatives/pytorch/derivatives/a1111/config.json"
    wget -q "https://raw.githubusercontent.com/osuiso-depot/docker-vastia-base-image/refs/heads/main/derivatives/pytorch/derivatives/a1111/ui-config.json"
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
    mv "wildcards" "${WORKSPACE}/stable-diffusion-webui-forge/extensions/sd-dynamic-prompts/"
    if [ $? -ne 0 ]; then
        echo "Failed to move wildcards directory"
    fi

    # Lora-block-weight プリセットを目的のディレクトリに移動
    mv "lbwpresets.txt" "${WORKSPACE}/stable-diffusion-webui-forge/extensions/sd-webui-lora-block-weight/scripts"
    if [ $? -ne 0 ]; then
        echo "Failed move lbwpresets.txt"
    fi

    # styles.csv を目的のディレクトリに移動
    mv "styles.csv" "${WORKSPACE}/stable-diffusion-webui-forge"
    mv "styles_integrated.csv" "${WORKSPACE}/stable-diffusion-webui-forge"
    if [ $? -ne 0 ]; then
        echo "Failed move styles.csv"
    fi


}


function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    base_config
    provisioning_get_extensions
    provisioning_get_pip_packages
    provisioning_get_files \
        "${A1111_DIR}/models/Stable-diffusion" \
        "${CHECKPOINT_MODELS[@]}"

    extensions_config

    # Avoid git errors because we run as root but files are owned by 'user'
    export GIT_CONFIG_GLOBAL=/tmp/temporary-git-config
    git config --file $GIT_CONFIG_GLOBAL --add safe.directory '*'

    # Start and exit because webui will probably require a restart
    cd "${A1111_DIR}"
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
        path="${A1111_DIR}/extensions/${dir}"
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

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
