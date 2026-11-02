from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ChessGame:
    id: str
    rated: bool
    variant: str
    speed: str
    perf: str
    created_at: int
    last_move_at: int
    status: str
    source: str
    white: dict
    black: dict
    moves: str
    winner: Optional[str] = None
    opening: Optional[dict] = None
    clocks: list[int] = field(default_factory=list)
    pgn: Optional[str] = None
    analysis: Optional[list[dict]] = None
