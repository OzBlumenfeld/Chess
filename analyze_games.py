"""Stockfish analysis for games from fetch_games.py (Lichess or chess.com).

Requires: pip install python-chess, and a `stockfish` binary on PATH.
"""
import io
import json
import sys

import chess
import chess.engine
import chess.pgn

MATE_CP = 10000  # mate scores are clamped to +/- this many centipawns


def _cp(score, color):
    """Score in centipawns from `color`'s point of view."""
    return score.pov(color).score(mate_score=MATE_CP)


def label(cp_loss):
    if cp_loss < 20:
        return "best"
    if cp_loss < 50:
        return "good"
    if cp_loss < 100:
        return "inaccuracy"
    if cp_loss < 300:
        return "mistake"
    return "blunder"


def analyze_pgn(pgn, engine, depth=15):
    """Return one dict per move: san, color, eval_before/after, cp_loss, label."""
    game = chess.pgn.read_game(io.StringIO(pgn))
    if game is None:
        return []
    board = game.board()
    limit = chess.engine.Limit(depth=depth)
    before = engine.analyse(board, limit)["score"]
    moves = []
    for move in game.mainline_moves():
        mover = board.turn
        san = board.san(move)
        best_cp = _cp(before, mover)
        board.push(move)
        after = engine.analyse(board, limit)["score"]
        played_cp = _cp(after, mover)
        loss = max(0, best_cp - played_cp)
        moves.append({
            "san": san,
            "color": "white" if mover == chess.WHITE else "black",
            "eval_before": best_cp,
            "eval_after": played_cp,
            "cp_loss": loss,
            "label": label(loss),
        })
        before = after
    return moves


def analyze_file(in_path, out_path, depth=15, engine_path="stockfish", threads=1):
    """Read games.ndjson (each line has a `pgn` field), write analysis ndjson."""
    engine = chess.engine.SimpleEngine.popen_uci(engine_path)
    engine.configure({"Threads": threads})
    n = 0
    try:
        with open(in_path) as fin, open(out_path, "w") as fout:
            for line in fin:
                if not line.strip():
                    continue
                g = json.loads(line)
                pgn = g.get("pgn")
                if not pgn:
                    continue
                gid = g.get("id") or g.get("uuid") or g.get("url")
                fout.write(json.dumps({"id": gid, "moves": analyze_pgn(pgn, engine, depth)}) + "\n")
                n += 1
    finally:
        engine.quit()
    return n


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "games.ndjson"
    dst = sys.argv[2] if len(sys.argv) > 2 else "analysis.ndjson"
    print(f"Analyzed {analyze_file(src, dst)} games -> {dst}")
