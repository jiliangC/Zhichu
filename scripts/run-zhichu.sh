#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d build.noindex/知处.app ]] || ./build.sh
open build.noindex/知处.app
