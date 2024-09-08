#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$(realpath "$BASH_SOURCE")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

source "$PROJECT_DIR"/.env

load_app_frp() {
    local url=$(cat "$PROJECT_DIR"/app.json | jq -r ".frp.url")
    local version=$(echo "$url" | grep -oP '(?<=releases/download/)[^/]+')
    if [ "$version" != "$FRP_VERSION" ]; then
        local file_name=$(echo "$url" | grep -oP "(?<=$version/)[^/]+$")
        local dir_name=$(echo "$url" | grep -oP "(?<=$version/)[^/]+(?=.tar.gz$)")

        local proxy=$(ip route | grep default | awk '{print $3}')
        export https_proxy="$proxy:10809"
        wget -P /tmp/ "$url"
        mkdir -p "$HOME"/app/frp/bin
        tar xf /tmp/"$file_name" -C "$HOME"/app/frp/
        ln -svf "$HOME"/app/frp/"$dir_name"/frpc "$HOME"/app/frp/bin/frpc
    fi
}

process_apt_package() {
    if ! command -v op &> /dev/null; then
        echo "op is not installed. Installing..."
        exit;
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Installing..."
        sudo apt update && sudo apt install -y jq
    else
        echo "jq is already installed."
    fi

    if ! command -v wget &> /dev/null; then
        echo "wget is not installed. Installing..."
        sudo apt update && sudo apt install -y wget
    else
        echo "wget is already installed."
    fi

    load_app_frp
}

op_item_list=""

process_cert_from_op() {
    if [ -z "$op_item_list" ]; then
        op_item_list=$(op item list --format json)
    fi
    local id=$(echo "$op_item_list" | jq -r ".[] | select(.title == \"$1\" and .category == \"SSH_KEY\") | .id")
    local item=$(op item get "$id" --reveal --format json)
    local private_key=$(echo "$item" | jq -r '.fields[] | select(.id == "private_key") | .ssh_formats.openssh.value')
    local public_key=$(echo "$item" | jq -r '.fields[] | select(.id == "public_key") | .value')
    local deploy_id=$(echo "$item" | jq -r '.fields[] | select(.label == "deploy_id") | .value')
    local key_type=$(echo "$item" | jq -r '.fields[] | select(.id == "key_type") | .value')

    local prefix='ed25519'
    if [ "$key_type" = 'rsa' ]; then
        prefix='rsa'
    fi

    echo SshKey process: "$deploy_id"

    local priv_key_path="$PROJECT_DIR"/configs/ssh/certs/id_"$deploy_id"_"$prefix"
    local public_key_path="$PROJECT_DIR"/configs/ssh/certs/id_"$deploy_id"_"$prefix".pub

    echo "$private_key" > "$priv_key_path"
    echo "$public_key" | tr -d '\n' > "$public_key_path"

    chmod 600 "$priv_key_path"
    chmod 644 "$public_key_path"
}

create_profile() {
    local frp_url=$(cat "$PROJECT_DIR"/app.json | jq -r ".frp.url")
    local frp_version=$(echo "$frp_url" | grep -oP '(?<=releases/download/)[^/]+')

    cat <<EOF > ~/.my_profile
export PROXY_HOST=\$(ip route | grep default | awk '{print \$3}')
export PROXY_HTTP_HOST=10809
export PROXY_SOCK_HOST=10808

# app frp
export PATH="$HOME/app/frp/bin:\$PATH"
export FRP_VERSION="$frp_version"
alias frpc='frpc -c "$PROJECT_DIR"/configs/frp/frpc.toml'

EOF
}

make_env() {
    process_apt_package

    if [[ ! -L ~/.ssh ]]; then
        if [ -d ~/.ssh ]; then
            mv "$HOME"/.ssh "$HOME"/.ssh_backup
        fi
    else
        rm "$HOME"/.ssh
    fi

    ln -svf "$PROJECT_DIR"/configs/ssh "$HOME"/.ssh

    rm -f "$PROJECT_DIR"/configs/ssh/certs/id_*

    process_cert_from_op 'ssh_github_ann'
    process_cert_from_op 'ssh_github_alex'
    process_cert_from_op 'ssh_codeup_fanyou'
    process_cert_from_op 'ssh_fanyou124'
    process_cert_from_op 'ssh_mime'

    chmod 700 "$PROJECT_DIR"/configs/ssh
    chmod 700 "$PROJECT_DIR"/configs/ssh/certs

    echo 'refresh main ssh key'
    ssh-keygen -t ed25519 -f "$PROJECT_DIR"/configs/ssh/id_ed25519 -N "" -C "$USER_EMAIL"
    chmod 600 "$PROJECT_DIR"/configs/ssh/id_ed25519
    chmod 644 "$PROJECT_DIR"/configs/ssh/id_ed25519.pub

    create_profile

    echo '添加到 .profile 或 .zprofile: '
    echo ''
    echo "source ~/.my_profile"
}

make_env
