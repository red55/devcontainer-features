#!/usr/bin/env zsh

set -e -u -o pipefail

local VAULT_PASS_DIR="$HOME/bin"
local VAULT_PASS_FILE="$VAULT_PASS_DIR/ansible-vault-pass.sh"
local ANSIBLE_CFG_FILE="$HOME/.ansible.cfg"
local UNDER_CI="false"

if [[ -z "$CI" || "$CI" == "false" ]]; then
    UNDER_CI="false"
else
    UNDER_CI="true"
fi

echo "Running under CI: $UNDER_CI"

if [ -f $VAULT_PASS_FILE ]; then
    chmod u+x $VAULT_PASS_FILE
else
    local VAULT_PASS=""
    echo "Warning: $VAULT_PASS_FILE not found, creating it."
    if [ "$UNDER_CI" = "true" ]; then
        if [ -z "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
            echo "Warning: ANSIBLE_VAULT_PASSWORD environment variable is not set in CI environment."
        fi
        VAULT_PASS="$ANSIBLE_VAULT_PASSWORD"
    else
        read -s "VAULT_PASS?Enter Ansible Vault password: "
    fi
    mkdir -p "$VAULT_PASS_DIR"
    printf "#!/bin/sh\necho -n '%s'\n" "$VAULT_PASS" > "$VAULT_PASS_FILE"
    VAULT_PASS=""
    unset VAULT_PASS
    chmod u+x "$VAULT_PASS_FILE"
fi
echo ""

local ANSIBLE_CONFIGURED=$(test -f "$ANSIBLE_CFG_FILE" && grep -F "vault_password_file=" "$ANSIBLE_CFG_FILE")
if [ -z "$ANSIBLE_CONFIGURED" ]; then
    echo "Ansible configuration located at $ANSIBLE_CFG_FILE"
    echo "[defaults]" >> $ANSIBLE_CFG_FILE
    if [ -f "$VAULT_PASS_FILE" ]; then
        echo "vault_password_file=$VAULT_PASS_FILE" >> $ANSIBLE_CFG_FILE
    fi
    echo "callbacks_enabled = ansible.posix.profile_tasks, ansible.posix.timer" >> $ANSIBLE_CFG_FILE
    echo "Enabling Mitogen for Ansible."
    local venvs=$(pipx list | grep -F "venvs are in " | awk '{print $4;}')
    local python_version=$(python3 --version | awk '{print $2;}' | cut -d. -f1,2)
    echo "strategy_plugins=$venvs/ansible-core/lib/python$python_version/site-packages/ansible_mitogen/plugins/strategy" >> $ANSIBLE_CFG_FILE
    echo "strategy=mitogen_linear" >> $ANSIBLE_CFG_FILE
else
    echo "Ansible is already configured."
fi
