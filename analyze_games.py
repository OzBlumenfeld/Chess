"""Stockfish analysis for games from fetch_games.py (Lichess or chess.com).

Requires: pip install python-chess, and a `stockfish` binary on PATH.
"""
import io
import json
import math
import sys

import chess
import chess.engine
import chess.pgn

MATE_CP = 10000  # mate scores are clamped to +/- this many centipawns
LINE_LEN = 6  # plies of the engine's best line to keep


def _cp(score, color):
    """Score in centipawns from `color`'s point of view."""
    return score.pov(color).score(mate_score=MATE_CP)


def win_pct(cp):
    """Lichess win chance (0-100) for a centipawn eval."""
    return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * cp)) - 1)


def move_accuracy(win_before, win_after):
    """Lichess per-move accuracy (0-100) from the mover's win chance before/after."""
    acc = 103.1668 * math.exp(-0.04354 * max(0.0, win_before - win_after)) - 3.1669
    return max(0.0, min(100.0, acc))


def _wdl(score, ply):
    """White's win/draw/loss chances in percent, from Stockfish's WDL model."""
    w = score.white().wdl(model="sf", ply=ply)
    return [round(w.wins / 10, 1), round(w.draws / 10, 1), round(w.losses / 10, 1)]


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


def _line(board, pv):
    b = board.copy(stack=False)
    sans = []
    for mv in pv[:LINE_LEN]:
        sans.append(b.san(mv))
        b.push(mv)
    return sans


def analyze_pgn(pgn, engine, depth=15):
    """Return one dict per move.

    Fields: ply, move_number, san, uci, color, eval_before/eval_after (cp, mover's view),
    cp_loss, label, best_move, best_line, win_before/win_after (mover's win %),
    accuracy, wdl (White's [win, draw, loss] % after the move).
    """
    game = chess.pgn.read_game(io.StringIO(pgn))
    if game is None:
        return []
    board = game.board()
    limit = chess.engine.Limit(depth=depth)
    before = engine.analyse(board, limit)
    moves = []
    for move in game.mainline_moves():
        mover = board.turn
        san = board.san(move)
        pv = before.get("pv") or []
        best = pv[0] if pv else None
        best_san, best_line = (board.san(best), _line(board, pv)) if best else (None, [])
        move_number = board.fullmove_number
        best_cp = _cp(before["score"], mover)
        board.push(move)
        after = engine.analyse(board, limit)
        played_cp = _cp(after["score"], mover)
        # Re-searching the same move can give a slightly different score; don't penalize it.
        loss = 0 if move == best else max(0, best_cp - played_cp)
        w_before, w_after = win_pct(best_cp), win_pct(best_cp - loss)
        moves.append({
            "ply": board.ply(),
            "move_number": move_number,
            "san": san,
            "uci": move.uci(),
            "color": "white" if mover == chess.WHITE else "black",
            "eval_before": best_cp,
            "eval_after": best_cp - loss,
            "cp_loss": loss,
            "label": label(loss),
            "best_move": best_san,
            "best_line": best_line,
            "win_before": round(w_before, 1),
            "win_after": round(w_after, 1),
            "accuracy": round(move_accuracy(w_before, w_after), 1),
            "wdl": _wdl(after["score"], board.ply()),
        })
        before = after
    return moves


def summarize(moves, key_moments=5):
    """Per-color accuracy and label counts, plus the biggest win-chance swings.

    Game accuracy is the average of the arithmetic and harmonic means of move
    accuracies, a simplified take on Lichess's formula (harmonic mean punishes blunders).
    """
    out = {}
    for color in ("white", "black"):
        accs = [m["accuracy"] for m in moves if m["color"] == color]
        if accs:
            mean = sum(accs) / len(accs)
            harmonic = len(accs) / sum(1 / max(a, 1.0) for a in accs)
            acc = round((mean + harmonic) / 2, 1)
        else:
            acc = None
        counts = {lab: sum(1 for m in moves if m["color"] == color and m["label"] == lab)
                  for lab in ("inaccuracy", "mistake", "blunder")}
        out[color] = {"accuracy": acc, **counts}
    swings = sorted((m for m in moves if m["label"] in ("mistake", "blunder")),
                    key=lambda m: m["win_after"] - m["win_before"])
    out["key_moments"] = sorted(swings[:key_moments], key=lambda m: m["ply"])
    return out


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
