"""Stream a Lichess PGN dump, filter to a rating band, and write split JSONL games.

Usage:
    python data/prepare_data.py \
        --input data/raw/lichess_db_standard_rated_2024-01.pgn.zst \
        --out-dir data/processed --min-elo 1500 --max-elo 1600 --max-games 100000

Each output line: {"game_id", "white_elo", "black_elo", "result", "moves": [SAN, ...]}
Splits are assigned per GAME via a stable hash of the game id, so there is no
leakage between train/val/test.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

import chess.pgn

try:
    import zstandard as zstd
except ImportError:  # only needed for .zst input
    zstd = None

ALLOWED_SPEEDS = {"Blitz", "Rapid", "Classical"}  # no Bullet / UltraBullet
ALLOWED_TERMINATIONS = {"Normal", "Time forfeit"}


def open_pgn(path: str):
    p = Path(path)
    if p.suffix == ".zst":
        if zstd is None:
            raise SystemExit("pip install zstandard to read .zst files")
        reader = zstd.ZstdDecompressor().stream_reader(p.open("rb"))
        return io.TextIOWrapper(reader, encoding="utf-8", errors="replace")
    return p.open("r", encoding="utf-8", errors="replace")


def speed_from_event(event: str) -> str:
    # e.g. "Rated Blitz game", "Rated Rapid tournament https://lichess.org/tournament/..."
    parts = event.split()
    return parts[1] if len(parts) > 1 else ""


def accept(headers, lo: int, hi: int) -> bool:
    """Header-only filter (cheap, runs before move parsing)."""
    try:
        w, b = int(headers.get("WhiteElo", "")), int(headers.get("BlackElo", ""))
    except ValueError:
        return False
    if not (lo <= w <= hi and lo <= b <= hi):
        return False
    if headers.get("Variant", "Standard") != "Standard":
        return False
    if speed_from_event(headers.get("Event", "")) not in ALLOWED_SPEEDS:
        return False
    return headers.get("Termination", "Normal") in ALLOWED_TERMINATIONS


class FilteredBuilder(chess.pgn.GameBuilder):
    """Skips move parsing for games that fail the header filter."""

    def __init__(self, lo: int, hi: int):
        super().__init__()
        self.lo, self.hi = lo, hi

    def end_headers(self):
        return None if accept(self.game.headers, self.lo, self.hi) else chess.pgn.SKIP


def game_id(headers) -> str:
    return headers.get("Site", "").rstrip("/").split("/")[-1]


def split_for(gid: str, val_pct: int, test_pct: int) -> str:
    bucket = int(hashlib.md5(gid.encode()).hexdigest(), 16) % 100
    if bucket < test_pct:
        return "test"
    if bucket < test_pct + val_pct:
        return "val"
    return "train"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help=".pgn or .pgn.zst")
    ap.add_argument("--out-dir", default="data/processed")
    ap.add_argument("--min-elo", type=int, default=1500)
    ap.add_argument("--max-elo", type=int, default=1600)
    ap.add_argument("--max-games", type=int, default=100_000)
    ap.add_argument("--min-plies", type=int, default=20)
    ap.add_argument("--val-pct", type=int, default=5)
    ap.add_argument("--test-pct", type=int, default=5)
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    outs = {s: (out_dir / f"{s}.jsonl").open("w") for s in ("train", "val", "test")}
    counts = {s: 0 for s in outs}

    kept = scanned = 0
    fh = open_pgn(args.input)
    try:
        while kept < args.max_games:
            game = chess.pgn.read_game(
                fh, Visitor=lambda: FilteredBuilder(args.min_elo, args.max_elo)
            )
            if game is None:
                break
            scanned += 1
            if scanned % 100_000 == 0:
                print(f"scanned {scanned:,} | kept {kept:,}", flush=True)
            if not accept(game.headers, args.min_elo, args.max_elo):
                continue

            board = game.board()
            sans = []
            for move in game.mainline_moves():
                sans.append(board.san(move))
                board.push(move)
            if len(sans) < args.min_plies:
                continue

            gid = game_id(game.headers)
            split = split_for(gid, args.val_pct, args.test_pct)
            record = {
                "game_id": gid,
                "white_elo": int(game.headers["WhiteElo"]),
                "black_elo": int(game.headers["BlackElo"]),
                "result": game.headers.get("Result", "*"),
                "moves": sans,
            }
            outs[split].write(json.dumps(record) + "\n")
            counts[split] += 1
            kept += 1
    finally:
        for f in outs.values():
            f.close()
        fh.close()

    print(f"done. scanned {scanned:,}, kept {kept:,} -> {counts}")


if __name__ == "__main__":
    main()
