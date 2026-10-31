  # chess-maia

Fine-tune a small language model to predict the move a human of a given rating would play (Maia-style), then evaluate and serve it.

## Layout

```
data/       PGN filtering + example generation
training/   LoRA fine-tuning (week 2)
eval/       baselines + move-match / illegal-move metrics
serve/      quantized inference + demo (week 4)
```

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e .
```

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

- [ ] Week 1: data pipeline, baselines (random legal move, low-depth Stockfish), metric code
- [ ] Week 2-3: LoRA fine-tune, track move-match accuracy and illegal-move rate
- [ ] Week 4: quantize, serve, demo, write-up
