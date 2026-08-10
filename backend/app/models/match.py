"""
Pydantic models for request/response validation on the matches API.
"""

from pydantic import BaseModel
from uuid import UUID
from typing import Optional


class RecordMatchRequest(BaseModel):
    sport_id: int
    player1_id: UUID
    player2_id: UUID
    winner_id: UUID
    score_json: dict          # e.g. {"sets": [[11,9],[9,11],[11,7]]}
    recorded_by: UUID


class ConfirmMatchRequest(BaseModel):
    user_id: UUID
    action: str                # 'confirmed' or 'disputed'


class MatchResponse(BaseModel):
    id: UUID
    sport_id: int
    player1_id: UUID
    player2_id: UUID
    winner_id: UUID
    status: str
    score_json: dict