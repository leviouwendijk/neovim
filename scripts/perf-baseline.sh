#!/bin/sh
# Reproducible cold-ish startup samples; run before and after the ATP on the same host.
set -eu
out="${1:-/tmp/nvim-performance-baseline}"
mkdir -p "$out"
for i in 1 2 3 4 5; do
    nvim --headless --startuptime "$out/config-$i.log" +qa
    nvim --clean --headless --startuptime "$out/clean-$i.log" +qa
done
printf 'Startup samples saved in %s\n' "$out"
printf 'Compare each log final startup entry and use the median; headless startup is not interactive latency.\n'
