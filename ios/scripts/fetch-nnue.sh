#!/bin/sh
# Downloads the Stockfish 17 networks the bundled engine (ChessKitEngine) expects.
# They are too big for git, so the app bundles them from ChessAnalyzer/Resources.
set -eu
dir="$(cd "$(dirname "$0")/.." && pwd)/ChessAnalyzer/Resources"
mkdir -p "$dir"
for net in nn-1111cefa1111.nnue nn-37f18f62d772.nnue; do
  if [ -s "$dir/$net" ]; then
    echo "have $net"
  else
    echo "fetching $net"
    curl -fsSL --retry 3 -o "$dir/$net.part" "https://tests.stockfishchess.org/api/nn/$net"
    mv "$dir/$net.part" "$dir/$net"
  fi
done
