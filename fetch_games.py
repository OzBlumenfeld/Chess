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

def save_games_to_file(user, path, max_games=100, **params):
    with open(path, "w") as f:
        n = 0
        for g in lichess_games(user, max_games, **params):
            f.write(json.dumps(g) + "\n")
            n += 1
    return n

if __name__ == "__main__":
    import logging
    from mongo_store import save_games

    logging.basicConfig(level=logging.INFO)
    inserted, skipped = save_games(
        lichess_games("ozblumen", max_games=100, perfType="blitz", rated="true")
    )
    print(f"Inserted {inserted}, skipped {skipped} existing")
