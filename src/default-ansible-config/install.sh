#!/usr/bin/env zsh

set -e -u -o pipefail
#sudo chown -R "$(whoami):$(whoami)" /home/vscode/.ssh
#chmod 700 /home/vscode/.ssh
#chmod 600 /home/vscode/.ssh/*

pipx install -q ansible-lint

local VAULT_PASS_DIR="$HOME/bin"
local VAULT_PASS_FILE="$VAULT_PASS_DIR/ansible-vault-pass.sh"
local ANSIBLE_CFG_FILE="$HOME/.ansible.cfg"

if [ -f $VAULT_PASS_FILE ]; then
    chmod +x $VAULT_PASS_FILE
else
    echo "Warning: $VAULT_PASS_FILE not found, creating it."
    read -s "VAULT_PASS?Enter Ansible Vault password: "
    mkdir -p "$VAULT_PASS_DIR"
    printf "#!/bin/sh\necho -n '%s'\n" "$VAULT_PASS" > "$VAULT_PASS_FILE"
    chmod +x "$VAULT_PASS_FILE"
fi
echo ""

local ANSIBLE_CONFIGURED=$(test -f "$ANSIBLE_CFG_FILE" && grep -F "vault_password_file=" "$ANSIBLE_CFG_FILE")
if [ -z "$ANSIBLE_CONFIGURED" ]; then
    echo "Ansible configuration located at $ANSIBLE_CFG_FILE"
    echo "[defaults]" >> $ANSIBLE_CFG_FILE
    echo "vault_password_file=$VAULT_PASS_FILE" >> $ANSIBLE_CFG_FILE
    echo "callbacks_enabled = ansible.posix.profile_tasks, ansible.posix.timer" >> $ANSIBLE_CFG_FILE
    local ENABLE_MITOGEN=${ENABLEMITOGEN:-"true"}
    if [ "$ENABLE_MITOGEN" = "true" ]; then
        echo "Enabling Mitogen for Ansible."
        local venvs=$(pipx list | grep -F "venvs are in " | awk '{print $4;}')
        local python_version=$(python3 --version | awk '{print $2;}' | cut -d. -f1,2)
        echo "strategy_plugins=$venvs/ansible-core/lib/python$python_version/site-packages/ansible_mitogen/plugins/strategy" >> $ANSIBLE_CFG_FILE
        echo "strategy=mitogen_linear" >> $ANSIBLE_CFG_FILE
    fi

else
    echo "Ansible is already configured."
fi
