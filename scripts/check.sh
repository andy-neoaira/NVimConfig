#!/bin/sh
# 复用已安装插件，但把状态、缓存、日志隔离到临时目录。
# 临时目录保留供失败排查，不清理个人 Neovim 数据。
set -eu
check_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$check_root"
check_tmp=$(mktemp -d "${TMPDIR:-/tmp}/nvim-config-check.XXXXXX")
export XDG_STATE_HOME="$check_tmp/state"
export XDG_CACHE_HOME="$check_tmp/cache"
export NVIM_LOG_FILE="$check_tmp/nvim.log"
stylua --check lua tests init.lua
nvim --headless -u NONE -i NONE -l tests/core.lua
nvim --headless -u NONE -i NONE -l tests/async.lua
nvim --headless -u NONE -i NONE -l tests/integration.lua
git diff --check
printf '检查完成，诊断目录：%s\n' "$check_tmp"
