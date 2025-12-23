#!/usr/bin/env zsh

set -e -u -o pipefail

local VAULT_PASS_DIR="$HOME/bin"
local VAULT_PASS_FILE="$VAULT_PASS_DIR/ansible-vault-pass.sh"
local ANSIBLE_CFG_FILE="$HOME/.ansible.cfg"
local UNDER_CI="${CI:-false}"

echo "Running under CI: $UNDER_CI"

if [ -f $VAULT_PASS_FILE ]; then
    chmod u+x $VAULT_PASS_FILE
else
    local VAULT_PASS="${ANSIBLE_VAULT_PASSWORD:-}"

    echo "Warning: $VAULT_PASS_FILE not found."

    if [ "$UNDER_CI" = "true"  ]; then
        if [ -z "$VAULT_PASS" ]; then
            echo "Warning: ANSIBLE_VAULT_PASSWORD environment variable is not set in CI environment."
        fi
    else
        read -s "VAULT_PASS?Enter Ansible Vault password: "
    fi
    if [ ! -z "$VAULT_PASS" ]; then
        mkdir -p "$VAULT_PASS_DIR"
        printf "#!/bin/sh\necho -n '%s'\n" "$VAULT_PASS" > "$VAULT_PASS_FILE"
        VAULT_PASS=""
        unset VAULT_PASS
        chmod u+x "$VAULT_PASS_FILE"
        echo "Created vault password file at $VAULT_PASS_FILE"
    else
        echo "No vault password provided. Skipping vault password file creation."
    fi
fi
echo ""

local ANSIBLE_CONFIGURED=$(test -f "$ANSIBLE_CFG_FILE" && grep -F "vault_password_file=" "$ANSIBLE_CFG_FILE")
if [ -z "$ANSIBLE_CONFIGURED" ]; then
    echo "Ansible configuration located at $ANSIBLE_CFG_FILE"
    local venvs=$(pipx list | grep -F "venvs are in " | awk '{print $4;}')
    local python_version=$(python3 --version | awk '{print $2;}' | cut -d. -f1,2)
    local mitogen_base_dir="$venvs/ansible-core/lib/python$python_version/site-packages/ansible_mitogen"
    echo "Enabling Ansible Mitogen strategy plugin."
    sudo sed -i 's/^\(ANSIBLE_VERSION_MAX *= *(\)[0-9]\+, *[0-9]\+)\(.*\)$/\1 2, 20)\2/' "$mitogen_base_dir/loaders.py"
cat << EOF > $ANSIBLE_CFG_FILE
[defaults]
callback_result_format=yaml
bin_ansible_callbacks=True
callbacks_enabled=ansible.posix.profile_tasks,ansible.posix.timer
strategy_plugins=$mitogen_base_dir/plugins/strategy
strategy=mitogen_linear
EOF
    if [ -f "$VAULT_PASS_FILE" ]; then
        echo "vault_password_file=$VAULT_PASS_FILE" >> $ANSIBLE_CFG_FILE
    fi
else
    echo "Ansible is already configured."
fi
