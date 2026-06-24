from transformers import pipeline


class ToxicCommentScorer:
    def __init__(self):
        self.classifier = pipeline(
            "text-classification",
            model="unitary/toxic-bert",
            top_k=None,
        )

    def score(self, text: str):
        labels = {
            "toxic": 0.0,
            "obscene": 0.0,
            "severe_toxic": 0.0,
            "threat": 0.0,
            "insult": 0.0,
            "identity_hate": 0.0,
        }

        output = self.classifier(text or "")
        for item in self._flatten_output(output):
            label = str(item.get("label", "")).lower()
            if label in labels:
                labels[label] = float(item.get("score", 0.0))

        return {
            "toxic_score": max(
                labels["toxic"],
                labels["severe_toxic"],
                labels["threat"],
                labels["insult"],
                labels["identity_hate"],
            ),
            "obscene_score": labels["obscene"],
        }

    def _flatten_output(self, output):
        if not isinstance(output, list):
            return []
        if len(output) == 0:
            return []
        if isinstance(output[0], list):
            return output[0]
        return output


scorer = ToxicCommentScorer()
