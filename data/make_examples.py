"""Turn split JSONL games into (prompt, completion) next-move examples.

Usage:
    python data/make_examples.py --in-dir data/processed --out-dir data/examples \
        --per-game 10 --min-ply 6

Prompt format (movetext, with the mover's Elo as a tag):
    <elo=1550> 1. e4 e5 2. Nf3 Nc6 3.      -> completion: "Bb5"
    <elo=1548> 1. e4                       -> completion: "e5"

Each line also carries `fen` (position before the move) and `legal_moves`, so the
eval script can compute legal-move rate and move-match accuracy without replaying games.
Positions are sampled per game with an RNG seeded by game_id (reproducible).
"""
import argparse
import json
import random
import zlib
from pathlib import Path

import chess


def movetext(sans: list[str], upto: int) -> str:
    """Movetext for plies [0, upto), ending ready for ply `upto` to be played."""
    parts = []
    for i in range(upto):
        if i % 2 == 0:
            parts.append(f"{i // 2 + 1}.")
        parts.append(sans[i])
    if upto % 2 == 0:  # white to move: open the next move number
        parts.append(f"{upto // 2 + 1}.")
    return " ".join(parts)


def examples_for_game(game: dict, per_game: int, min_ply: int):
    sans = game["moves"]
    n = len(sans)
    candidates = list(range(min_ply, n))
    if not candidates:
        return
    rng = random.Random(zlib.crc32(game["game_id"].encode()))
    picks = sorted(rng.sample(candidates, min(per_game, len(candidates))))

    board = chess.Board()
    pick_set = set(picks)
    for ply, san in enumerate(sans):
        if ply in pick_set:
            elo = game["white_elo"] if ply % 2 == 0 else game["black_elo"]
            yield {
                "game_id": game["game_id"],
                "ply": ply,
                "elo": elo,
                "prompt": f"<elo={elo}> {movetext(sans, ply)}",
                "completion": san,
                "fen": board.fen(),
                "legal_moves": sorted(board.san(m) for m in board.legal_moves),
            }
        board.push_san(san)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in-dir", default="data/processed")
    ap.add_argument("--out-dir", default="data/examples")
    ap.add_argument("--per-game", type=int, default=10)
    ap.add_argument("--min-ply", type=int, default=6)
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    for split in ("train", "val", "test"):
        src = Path(args.in_dir) / f"{split}.jsonl"
        if not src.exists():
            continue
        n_games = n_ex = 0
        with src.open() as fin, (out_dir / f"{split}.jsonl").open("w") as fout:
            for line in fin:
                game = json.loads(line)
                n_games += 1
                for ex in examples_for_game(game, args.per_game, args.min_ply):
                    fout.write(json.dumps(ex) + "\n")
                    n_ex += 1
        print(f"{split}: {n_games:,} games -> {n_ex:,} examples")


if __name__ == "__main__":
    main()
