"""Analyze one game by ID or URL and print a report.

Usage:
    python analyze_game.py lichess.org/PHJ0pedH
    python analyze_game.py https://www.chess.com/game/live/123456789 [--user ozblumen]
    python analyze_game.py single_game_example.json --moves --json out.json

Results are cached in MongoDB (collection `analyses`) when it is reachable.
"""
import argparse
import json
import logging
import shutil
import sys

import chess.engine

from analyze_games import analyze_pgn, summarize
from fetch_game import fetch_game, game_info
from mongo_store import ANALYSIS_COLLECTION, get_collection

logger = logging.getLogger(__name__)

SYMBOL = {"inaccuracy": "?!", "mistake": "?", "blunder": "??"}


def _cache():
    """The analyses collection, or None if MongoDB isn't running."""
    try:
        coll = get_collection(name=ANALYSIS_COLLECTION, serverSelectionTimeoutMS=1000)
        coll.database.client.admin.command("ping")
        return coll
    except Exception:  # noqa: BLE001 - any connection problem just disables caching
        logger.info("MongoDB not reachable; analysis won't be cached")
        return None


def analyze(ref, depth=15, engine_path=None, threads=1, user=None, use_cache=True):
    """Fetch and analyze a game. Returns {"info", "moves", "summary"}."""
    source, game = fetch_game(ref, user=user)
    info = {**game_info(game), "source": source}
    key = f"{source}:{info['id']}:d{depth}"
    cache = _cache() if use_cache else None
    if cache is not None and (hit := cache.find_one({"_id": key})):
        moves = hit["moves"]
    else:
        engine_path = engine_path or shutil.which("stockfish") or "/usr/games/stockfish"
        engine = chess.engine.SimpleEngine.popen_uci(engine_path)
        try:
            engine.configure({"Threads": threads})
            moves = analyze_pgn(game["pgn"], engine, depth)
        finally:
            engine.quit()
        if cache is not None:
            cache.replace_one({"_id": key}, {"_id": key, "info": info, "moves": moves}, upsert=True)
    return {"info": info, "moves": moves, "summary": summarize(moves)}


def _move_str(m):
    dots = "." if m["color"] == "white" else "..."
    return f"{m['move_number']}{dots} {m['san']}{SYMBOL.get(m['label'], '')}"


def _eval_str(cp, color):
    white_cp = cp if color == "white" else -cp
    if abs(white_cp) >= 9000:
        return "#" if white_cp > 0 else "-#"
    return f"{white_cp / 100:+.1f}"


def _player(p):
    return f"{p['name']} ({p['rating']})" if p.get("rating") else str(p["name"])


def report(result, show_moves=False):
    info, s = result["info"], result["summary"]
    w, b = info["white"], info["black"]
    lines = [
        f"{info.get('opening') or 'Unknown opening'}"
        + (f" ({info['eco']})" if info.get("eco") else "")
        + f"  ·  {info.get('speed') or '?'}  ·  {info['result']}",
        f"{_player(w)}  vs  {_player(b)}",
        "",
        f"{'':8}{'Accuracy':>9}{'Inacc.':>8}{'Mistake':>9}{'Blunder':>9}",
    ]
    for color in ("white", "black"):
        c = s[color]
        acc = f"{c['accuracy']:.1f}%" if c["accuracy"] is not None else "-"
        lines.append(f"{color.title():8}{acc:>9}{c['inaccuracy']:>8}{c['mistake']:>9}{c['blunder']:>9}")

    lines += ["", "Key moments"]
    if not s["key_moments"]:
        lines.append("  No mistakes or blunders. Clean game!")
    for m in s["key_moments"]:
        best = f"best: {m['best_move']}" if m["best_move"] else ""
        line = " ".join(m["best_line"][1:4])
        lines.append(
            f"  {_move_str(m):14} {m['color']} win {m['win_before']:.0f}% → {m['win_after']:.0f}%"
            f"   {best}" + (f"  ({line} …)" if line else "")
        )

    if show_moves:
        lines += ["", f"{'Move':16}{'Eval':>6}   {'Engine W/D/L':18}Best"]
        for m in result["moves"]:
            wdl = "{:>3.0f} /{:>3.0f} /{:>3.0f}".format(*m["wdl"])
            best = "" if m["label"] in ("best", "good") else m["best_move"] or ""
            lines.append(f"{_move_str(m):16}{_eval_str(m['eval_after'], m['color']):>6}   {wdl:18}{best}")
    return "\n".join(lines)


def main(argv=None):
    p = argparse.ArgumentParser(description="Analyze a chess game by ID or URL.")
    p.add_argument("game", help="Lichess/chess.com game ID or URL, or a .json/.pgn file")
    p.add_argument("--depth", type=int, default=15)
    p.add_argument("--engine", help="path to Stockfish (default: stockfish on PATH)")
    p.add_argument("--threads", type=int, default=1)
    p.add_argument("--user", help="chess.com username, if the game can't be found by ID")
    p.add_argument("--moves", action="store_true", help="print every move")
    p.add_argument("--json", metavar="PATH", help="also write the full analysis as JSON")
    p.add_argument("--no-cache", action="store_true", help="don't read/write MongoDB")
    args = p.parse_args(argv)

    logging.basicConfig(level=logging.WARNING)
    try:
        result = analyze(args.game, args.depth, args.engine, args.threads, args.user,
                         use_cache=not args.no_cache)
    except (ValueError, LookupError) as e:
        sys.exit(f"error: {e}")
    print(report(result, show_moves=args.moves))
    if args.json:
        with open(args.json, "w") as f:
            json.dump(result, f, indent=2)


if __name__ == "__main__":
    main()
