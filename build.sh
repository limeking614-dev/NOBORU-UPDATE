#!/bin/sh
# Package the Lua application with its bundled runtime, UI fonts and fallbacks.
set -eu
cd "$(dirname "$0")"
output=${1:-Noboru-UI.vpk}
vita-pack-vpk \
  -s source/sce_sys/param.sfo \
  -b source/eboot.bin \
  -a source/index.lua=index.lua \
  -a source/main.lua=main.lua \
  -a source/assets=assets \
  -a source/SourceSans3-Regular.ttf=SourceSans3-Regular.ttf \
  -a source/SourceSans3-SemiBold.ttf=SourceSans3-SemiBold.ttf \
  -a source/SourceSans3-LICENSE.md=SourceSans3-LICENSE.md \
  -a source/roboto.ttf=roboto.ttf \
  -a source/robboto.ttf=robboto.ttf \
  -a source/updater=updater \
  -a source/sce_sys/icon0.png=sce_sys/icon0.png \
  -a source/sce_sys/livearea=sce_sys/livearea \
  "$output"
