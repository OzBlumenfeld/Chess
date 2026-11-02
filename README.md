# chess-maia

A chess analysis tool for your own games. Give it a Lichess or chess.com game ID and it shows where the game turned, what the best moves were, and the odds for each side.

It starts on Stockfish. Later, two models trained on human games take over the parts an engine can't do:

- **Move model** (Maia-style): the move a human of a given rating would play.
- **Value model:** win/draw/loss odds *at a given rating*, not under perfect play.

## Layout

```
analyze_game.py          CLI: analyze one game by ID/URL, print a report
analyze_games.py         Stockfish per-move analysis (also batch over ndjson)
fetch_game.py            fetch one game from Lichess / chess.com / a local file
fetch_games.py           fetch a Lichess player's games
fetch_chesscom_games.py  fetch a chess.com player's games
mongo_store.py           MongoDB storage (games + cached analyses)
reports.py               player stats: openings, W/D/L by color
data/                    PGN filtering + example generation for training
training/                model training (planned)
eval/                    baselines + metrics (planned)
```

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e .
docker compose up -d     # optional: MongoDB for caching analyses
```

You also need a [Stockfish](https://stockfishchess.org/download/) binary on your `PATH` (or pass `--engine`).

## Analyze a game

```bash
python analyze_game.py lichess.org/PHJ0pedH
python analyze_game.py https://www.chess.com/game/live/123456789
python analyze_game.py single_game_example.json --moves --json analysis.json
```

| Flag | |
|---|---|
| `--moves` | print every move with eval, W/D/L and best move |
| `--depth N` | Stockfish depth (default 15) |
| `--json PATH` | save the full analysis |
| `--user NAME` | chess.com username, if the game can't be found by ID |
| `--no-cache` | skip MongoDB |

Example output:

```
French Defense: Advance Variation, Nimzowitsch System (C02)  ·  blitz  ·  0-1
ozblumen (1412)  vs  PolAA-5 (1441)

         Accuracy  Inacc.  Mistake  Blunder
White       74.3%       5        5        1
Black       81.4%       9        5        0

Key moments
  4... c4?       black win 50% → 34%   best: cxd4  (Qxd4 Ne7 Bd3 …)
  16. Nb5?       white win 59% → 40%   best: Rfe1  (Rf8 Qg3 Qc5 …)
  30. Re2??      white win 55% → 12%   best: Qxf4  (Rxf4 Rd1 Rd8 …)
```

**Per move:** eval, label (best / good / inaccuracy / mistake / blunder), best move and engine line, win % before and after, accuracy, and Stockfish's W/D/L.

**Notes**
- Win % and accuracy use Lichess's formulas. Game accuracy is a simplified version (average of the mean and harmonic mean of move accuracies).
- Engine W/D/L is calibrated to engine play, so it shows a lot of draws. The value model is meant to replace it with odds for human players.
- chess.com's public API has no fetch-by-ID. The tool finds the player and month through chess.com's unofficial callback endpoint, then searches that archive. If that fails, pass `--user`.

## Data pipeline

1. Download one monthly dump from https://database.lichess.org (standard rated games, `.pgn.zst`) into `data/raw/`.
2. Filter to a rating band and split by game:

```bash
python data/prepare_data.py \
  --input data/raw/lichess_db_standard_rated_2024-01.pgn.zst \
  --out-dir data/processed --min-elo 1500 --max-elo 1600 --max-games 100000
```

3. Build next-move examples:

```bash
python data/make_examples.py --in-dir data/processed --out-dir data/examples
```

## Design notes

- **No leakage:** the split is a stable hash of the game id, so every position from a game lands in the same split.
- **Filters:** both players inside the Elo band, standard variant, no bullet, normal or time-forfeit endings, at least 20 plies.
- **Example format:** `<elo=1550> 1. e4 e5 2.` -> `Nf3`. Each example also stores the FEN and legal moves for cheap eval.

## Roadmap

**v1: Stockfish analysis tool**
- [x] Fetch player games from Lichess and chess.com into MongoDB
- [x] Per-move Stockfish analysis with labels
- [x] Fetch a single game by ID or URL
- [x] Best move + engine line, win %, accuracy, key moments
- [x] CLI report, cached in MongoDB
- [ ] HTML report with an interactive board and eval graph

**v2: models trained on human games** (supervised learning)
- [ ] Data pipeline and baselines (random legal move, low-depth Stockfish), metric code
- [ ] Move model: predict a human's move given position + rating; track move-match accuracy and illegal-move rate
- [ ] Value model: predict W/D/L given position + ratings, labeled with game results
- [ ] One network with two heads (move + value) sharing a trunk

**v3: plug models into the tool**
- [ ] Rating-aware win %: "at 1400 this position wins 58% of the time"
- [ ] Human-move hints: "players at your rating find the best move here 12% of the time"
- [ ] Extras: blunder-risk and position-difficulty scores, rating guesser
- [ ] Serve: quantize the model, small web demo

**Later: reinforcement learning (optional)**
- [ ] Learn RL basics on a toy environment (Tic-Tac-Toe / Connect-4)
- [ ] Fine-tune the supervised model with a Stockfish-based reward
