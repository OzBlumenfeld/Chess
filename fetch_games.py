import requests, json

def lichess_games(user, max_games=100, **params):
    r = requests.get(
        f"https://lichess.org/api/games/user/{user}",
        params={"max": max_games, "pgnInJson": "true", "clocks": "true",
                "evals": "true", "opening": "true", **params},
        headers={"Accept": "application/x-ndjson", "User-Agent": "chess-maia"},
        stream=True,
    )
    r.raise_for_status()
    for line in r.iter_lines():
        if line:
            yield json.loads(line)

def chesscom_games(user, max_games=100, time_class=None, rated=None, **_):
    """Yield chess.com games (newest first) as dicts; each has a "pgn" key like lichess's pgnInJson."""
    headers = {"User-Agent": "chess-maia"}
    r = requests.get(f"https://api.chess.com/pub/player/{user.lower()}/games/archives", headers=headers)
    r.raise_for_status()
    n = 0
    for url in reversed(r.json().get("archives", [])):
        m = requests.get(url, headers=headers)
        m.raise_for_status()
        for g in reversed(m.json().get("games", [])):
            if time_class and g.get("time_class") != time_class:
                continue
            if rated is not None and str(g.get("rated")).lower() != str(rated).lower():
                continue
            yield g
            n += 1
            if max_games and n >= max_games:
                return

SOURCES = {"lichess": lichess_games, "chesscom": chesscom_games}

def save_games(user, path, max_games=100, source="lichess", **params):
    with open(path, "w") as f:
        n = 0
        for g in SOURCES[source](user, max_games, **params):
            f.write(json.dumps(g) + "\n")
            n += 1
    return n

if __name__ == "__main__":
    n = save_games("ozblumen", "games.ndjson", max_games=100, perfType="blitz", rated="true")
    print(f"Saved {n} games to games.ndjson")