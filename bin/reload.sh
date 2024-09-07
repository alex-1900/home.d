#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$(realpath "$BASH_SOURCE")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

source "$PROJECT_DIR"/.env

process_apt_package() {
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Installing..."
        sudo apt update && sudo apt install -y jq
    else
        echo "jq is already installed."
    fi

    if ! command -v op &> /dev/null; then
        echo "op is not installed. Installing..."

        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
        sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
        sudo tee /etc/apt/sources.list.d/1password.list

        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
        sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
        sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

        sudo apt update && sudo apt install -y 1password-cli
    else
        echo "op is already installed."
    fi
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
    cat <<EOF > ~/.my_profile
export PROXY_HOST=\$(ip route | grep default | awk '{print \$3}')
export PROXY_HTTP_HOST=10809
export PROXY_SOCK_HOST=10808

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
