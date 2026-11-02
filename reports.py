"""Player statistics computed from games stored in MongoDB."""
from collections import Counter

from mongo_store import get_collection


def _pct(count, total):
    return round(100 * count / total, 2) if total else 0.0


def player_stats(name, collection=None, top_openings=10):
    """Opening usage and win/draw/loss ratios for one player (case-insensitive).

    Returns a dict with:
      games: total games found
      results: {"win"|"draw"|"loss": {"count", "pct"}}
      openings: top openings as [{"name", "eco", "count", "pct", "win_pct", "draw_pct", "loss_pct"}]
      by_color: the same results breakdown for "white" and "black"
    A game with no "winner" field counts as a draw (stalemate, agreement, etc.).
    """
    collection = collection if collection is not None else get_collection()
    uid = name.lower()

    cursor = collection.find(
        {"$or": [{"players.white.user.id": uid}, {"players.black.user.id": uid}]},
        {"players": 1, "winner": 1, "opening": 1},
    )

    results = Counter()
    color_results = {"white": Counter(), "black": Counter()}
    openings = {}  # (eco, name) -> Counter of results
    total = 0

    for g in cursor:
        color = "white" if g["players"]["white"].get("user", {}).get("id") == uid else "black"
        winner = g.get("winner")
        result = "draw" if winner is None else "win" if winner == color else "loss"

        total += 1
        results[result] += 1
        color_results[color][result] += 1
        op = g.get("opening") or {}
        key = (op.get("eco"), op.get("name", "Unknown"))
        openings.setdefault(key, Counter())[result] += 1

    def summarize(counter):
        n = sum(counter.values())
        return {r: {"count": counter[r], "pct": _pct(counter[r], n)} for r in ("win", "draw", "loss")}

    opening_rows = []
    for (eco, op_name), c in sorted(openings.items(), key=lambda kv: -sum(kv[1].values()))[:top_openings]:
        n = sum(c.values())
        opening_rows.append({
            "name": op_name,
            "eco": eco,
            "count": n,
            "pct": _pct(n, total),
            "win_pct": _pct(c["win"], n),
            "draw_pct": _pct(c["draw"], n),
            "loss_pct": _pct(c["loss"], n),
        })

    return {
        "games": total,
        "results": summarize(results),
        "openings": opening_rows,
        "by_color": {col: summarize(c) for col, c in color_results.items()},
    }


if __name__ == "__main__":
    import json
    import sys

    # print(json.dumps(player_stats(sys.argv[1]), indent=2))
    print(json.dumps(player_stats("ozblumen"), indent=2))
