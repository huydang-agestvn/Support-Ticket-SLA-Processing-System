from fastapi import FastAPI
from pydantic import BaseModel
from model import scorer

app = FastAPI()


class ScoreRequest(BaseModel):
    text: str


class ScoreResponse(BaseModel):
    toxic_score: float
    obscene_score: float


@app.post("/score", response_model=ScoreResponse)
def score(req: ScoreRequest):
    return scorer.score(req.text)


@app.get("/health")
def health():
    return {"status": "ok"}
