"""Fetch a single game by ID or URL from Lichess or chess.com.

Accepted references:
    lichess.org/PHJ0pedH, lichess.org/PHJ0pedHabcd/black, PHJ0pedH
    chess.com/game/live/123456789, chess.com/game/daily/123456789, 123456789
    path/to/game.json (Lichess or chess.com JSON) or path/to/game.pgn
"""
import json
import re
from pathlib import Path

import requests

from fetch_chesscom_games import API as CHESSCOM_API, HEADERS, _opening, _pgn_header

LICHESS_RE = re.compile(r"lichess\.org/(?:game/export/)?([A-Za-z0-9]{8})")
CHESSCOM_RE = re.compile(r"chess\.com/(?:game/)?(live|daily)/(?:game/)?(\d+)")


def parse_game_ref(ref):
    """Return (source, game_id, kind). source is "lichess", "chesscom" or "file"."""
    ref = ref.strip()
    if Path(ref).suffix.lower() in (".json", ".pgn") and Path(ref).exists():
        return "file", ref, None
    if m := LICHESS_RE.search(ref):
        return "lichess", m.group(1), None
    if m := CHESSCOM_RE.search(ref):
        return "chesscom", m.group(2), m.group(1)
    if re.fullmatch(r"[A-Za-z0-9]{8}", ref) and not ref.isdigit():
        return "lichess", ref, None
    if ref.isdigit():
        return "chesscom", ref, "live"
    raise ValueError(f"Not a Lichess/chess.com game ID, URL or file: {ref!r}")


def lichess_game(game_id):
    r = requests.get(
        f"https://lichess.org/game/export/{game_id}",
        params={"pgnInJson": "true", "clocks": "true", "evals": "true", "opening": "true"},
        headers={"Accept": "application/json", "User-Agent": "chess-maia"},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def _chesscom_month(user, year, month, game_id):
    r = requests.get(f"{CHESSCOM_API}/{user.lower()}/games/{year}/{month:02d}",
                     headers=HEADERS, timeout=30)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    for g in r.json().get("games", []):
        if g.get("url", "").rstrip("/").endswith(f"/{game_id}"):
            return {**g, "id": g["uuid"], "opening": _opening(g.get("pgn"))}
    return None


def chesscom_game(game_id, kind="live", user=None, max_months=24):
    """chess.com's public API has no fetch-by-ID, so find the game in a player's archive.

    The player and month come from chess.com's (unofficial) callback endpoint. If
    that fails, pass `user` and the most recent `max_months` archives are searched.
    """
    try:
        r = requests.get(f"https://www.chess.com/callback/{kind}/game/{game_id}",
                         headers=HEADERS, timeout=30)
        r.raise_for_status()
        headers = r.json()["game"]["pgnHeaders"]
        user = user or headers["White"]
        year, month = (int(x) for x in headers["Date"].split(".")[:2])
        # Archives are filed by end date, so a game can spill into the next month.
        for y, m in ((year, month), (year + month // 12, month % 12 + 1)):
            if g := _chesscom_month(user, y, m, game_id):
                return g
    except (requests.RequestException, KeyError, ValueError):
        pass

    if not user:
        raise LookupError(f"chess.com game {game_id} not found; pass a username to search")
    r = requests.get(f"{CHESSCOM_API}/{user.lower()}/games/archives", headers=HEADERS, timeout=30)
    r.raise_for_status()
    for url in list(reversed(r.json()["archives"]))[:max_months]:
        year, month = (int(x) for x in url.rstrip("/").split("/")[-2:])
        if g := _chesscom_month(user, year, month, game_id):
            return g
    raise LookupError(f"chess.com game {game_id} not found in {user}'s last {max_months} months")


def load_file(path):
    text = Path(path).read_text()
    if path.lower().endswith(".pgn"):
        return {"id": _pgn_header(text, "GameId") or Path(path).stem, "pgn": text}
    return json.loads(text)


def fetch_game(ref, user=None):
    """Return (source, game_dict) for any supported reference."""
    source, game_id, kind = parse_game_ref(ref)
    if source == "file":
        game = load_file(game_id)
        source = "chesscom" if "uuid" in game else "lichess"
        return source, game
    if source == "lichess":
        return source, lichess_game(game_id)
    return source, chesscom_game(game_id, kind, user)


def game_info(game):
    """Players, ratings, result and opening, normalized across Lichess and chess.com."""
    pgn = game.get("pgn", "")

    def player(color):
        if "players" in game:  # Lichess
            p = game["players"][color]
            return {"name": p.get("user", {}).get("name", "Anonymous"), "rating": p.get("rating")}
        if color in game:  # chess.com
            return {"name": game[color].get("username"), "rating": game[color].get("rating")}
        elo = _pgn_header(pgn, f"{color.title()}Elo")
        return {"name": _pgn_header(pgn, color.title()),
                "rating": int(elo) if elo and elo.isdigit() else None}

    opening = game.get("opening") or {}
    return {
        "id": game.get("id"),
        "white": player("white"),
        "black": player("black"),
        "result": _pgn_header(pgn, "Result") or "*",
        "speed": game.get("speed") or game.get("time_class"),
        "opening": opening.get("name") or _pgn_header(pgn, "Opening"),
        "eco": opening.get("eco") or _pgn_header(pgn, "ECO"),
    }
