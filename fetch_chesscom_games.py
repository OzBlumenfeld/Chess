"""Fetch games from the chess.com public API and save them to their own Mongo collection."""
import re
import requests

HEADERS = {"User-Agent": "chess-maia"}
API = "https://api.chess.com/pub/player"


def _pgn_header(pgn, tag):
    m = re.search(rf'\[{tag} "([^"]*)"\]', pgn or "")
    return m.group(1) if m else None


def _opening(pgn):
    """Opening from PGN headers. chess.com only gives a slug URL, e.g.
    .../openings/Scotch-Game-Scotch-Gambit-4.Bc4, so the name is derived from it."""
    url = _pgn_header(pgn, "ECOUrl")
    name = None
    if url:
        slug = url.rsplit("/", 1)[-1]
        name = re.sub(r"-\d+\..*$", "", slug).replace("-", " ")
    return {"eco": _pgn_header(pgn, "ECO"), "name": name}


def chesscom_games(user, max_games=100, time_class=None, rated=None):
    """Yield games newest first, each tagged with `id` (the chess.com uuid) and `opening`.

    time_class: e.g. "blitz"; rated: True/False; None means no filter.
    """
    r = requests.get(f"{API}/{user}/games/archives", headers=HEADERS)
    r.raise_for_status()
    n = 0
    for archive_url in reversed(r.json()["archives"]):  # archives are oldest first
        r = requests.get(archive_url, headers=HEADERS)
        r.raise_for_status()
        for g in reversed(r.json()["games"]):
            if time_class and g.get("time_class") != time_class:
                continue
            if rated is not None and g.get("rated") != rated:
                continue
            if n >= max_games:
                return
            n += 1
            yield {**g, "id": g["uuid"], "opening": _opening(g.get("pgn"))}


if __name__ == "__main__":
    import logging
    from mongo_store import CHESSCOM_COLLECTION, get_collection, save_games

    logging.basicConfig(level=logging.INFO)
    inserted, skipped = save_games(
        chesscom_games("ozblumen", max_games=100, time_class="blitz", rated=True),
        collection=get_collection(name=CHESSCOM_COLLECTION),
    )
    print(f"Inserted {inserted}, skipped {skipped} existing")
