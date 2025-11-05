#!/bin/bash
set -euo pipefail

export PIPX_USE_EMOJI=0
pipx install -q ansible-lint

cp default-ansible-config.zsh /
chmod +x /default-ansible-config.zsh
