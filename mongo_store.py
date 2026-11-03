"""Save Lichess games (as yielded by fetch_games.lichess_games) to MongoDB."""
import logging
import os

from pymongo import MongoClient
from pymongo.errors import DuplicateKeyError

logger = logging.getLogger(__name__)

MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.environ.get("MONGO_DB", "chess_maia")
COLLECTION = "games"
CHESSCOM_COLLECTION = "chesscom_games"
ANALYSIS_COLLECTION = "analyses"


def get_collection(uri=MONGO_URI, db=DB_NAME, name=COLLECTION, **client_kwargs):
    return MongoClient(uri, **client_kwargs)[db][name]


def save_game(game, collection=None):
    """Insert one game keyed by Lichess game id.

    Returns True if inserted, False if a game with that id already exists
    (logged, not raised).
    """
    collection = collection if collection is not None else get_collection()
    try:
        collection.insert_one({**game, "_id": game["id"]})
    except DuplicateKeyError:
        logger.warning("Game %s already exists, skipping", game["id"])
        return False
    return True


def save_games(games, collection=None):
    """Insert many games, skipping existing ones. Returns (inserted, skipped)."""
    collection = collection if collection is not None else get_collection()
    inserted = skipped = 0
    for g in games:
        if save_game(g, collection):
            inserted += 1
        else:
            skipped += 1
    return inserted, skipped
