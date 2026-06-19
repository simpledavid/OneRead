import unittest
from unittest.mock import patch

from scripts import content_pipeline


class EditorialScoringTests(unittest.TestCase):
    def test_editorial_analysis_clamps_and_normalizes_values(self):
        analysis = content_pipeline.editorial_analysis(
            {
                "relevance": 12,
                "quality": 7.5,
                "timeliness": 0,
                "category": "SECURITY",
                "keywords": ["AI safety", "AI safety", 42, "policy"],
                "reason": "  Important   public impact.  ",
            },
            local_score_value=70,
        )

        self.assertEqual(analysis["relevance"], 10)
        self.assertEqual(analysis["quality"], 7.5)
        self.assertEqual(analysis["timeliness"], 1)
        self.assertEqual(analysis["category"], "security")
        self.assertEqual(analysis["keywords"], ["AI safety", "policy"])
        self.assertEqual(analysis["reason"], "Important public impact.")
        self.assertEqual(analysis["weightedScore"], 70)

    def test_rerank_uses_three_dimensions_and_keeps_metadata(self):
        candidates = [
            {
                "candidateID": "C01",
                "localScore": 80.0,
                "editorialScore": None,
                "finalScore": 80.0,
                "article": {
                    "source": "Source A",
                    "title": "Large launch",
                    "summary": "A consequential launch.",
                    "body": ["Detailed reporting with evidence."],
                    "publishedAt": "2026-06-19T00:00:00Z",
                    "sourceCount": 2,
                },
            },
            {
                "candidateID": "C02",
                "localScore": 82.0,
                "editorialScore": None,
                "finalScore": 82.0,
                "article": {
                    "source": "Source B",
                    "title": "Minor update",
                    "summary": "A small product update.",
                    "body": ["Short announcement."],
                    "publishedAt": "2026-06-19T00:00:00Z",
                    "sourceCount": 1,
                },
            },
        ]
        response = {
            "scores": [
                {
                    "id": "C01",
                    "relevance": 10,
                    "quality": 9,
                    "timeliness": 9,
                    "category": "model_release",
                    "keywords": ["launch", "model"],
                    "reason": "Material industry impact.",
                },
                {
                    "id": "C02",
                    "relevance": 4,
                    "quality": 3,
                    "timeliness": 7,
                    "category": "developer_tools",
                    "keywords": ["update"],
                    "reason": "Timely but minor.",
                },
            ]
        }

        with patch.object(content_pipeline, "llm_config", return_value=("base", "model", "key")):
            with patch.object(content_pipeline, "llm_json", return_value=response):
                ranked = content_pipeline.rerank_with_llm(candidates)

        self.assertEqual(ranked[0]["candidateID"], "C01")
        self.assertEqual(ranked[0]["editorialCategory"], "model_release")
        self.assertEqual(ranked[0]["editorialKeywords"], ["launch", "model"])
        self.assertEqual(ranked[0]["scoreBreakdown"]["relevance"], 10)
        self.assertGreater(ranked[0]["finalScore"], ranked[1]["finalScore"])

    def test_rerank_falls_back_when_llm_call_fails(self):
        candidates = [
            {
                "candidateID": "C01",
                "localScore": 75.0,
                "editorialScore": None,
                "finalScore": 75.0,
                "article": {
                    "source": "Source",
                    "title": "Story",
                    "summary": "Summary",
                    "body": [],
                },
            }
        ]

        with patch.object(content_pipeline, "llm_config", return_value=("base", "model", "key")):
            with patch.object(content_pipeline, "llm_json", side_effect=RuntimeError("bad JSON")):
                ranked = content_pipeline.rerank_with_llm(candidates)

        self.assertEqual(ranked, candidates)
        self.assertEqual(ranked[0]["finalScore"], 75.0)

    def test_rerank_falls_back_when_llm_schema_is_invalid(self):
        candidates = [
            {
                "candidateID": "C01",
                "localScore": 68.0,
                "editorialScore": None,
                "finalScore": 68.0,
                "article": {
                    "source": "Source",
                    "title": "Story",
                    "summary": "Summary",
                    "body": [],
                },
            }
        ]

        with patch.object(content_pipeline, "llm_config", return_value=("base", "model", "key")):
            with patch.object(content_pipeline, "llm_json", return_value={"scores": "invalid"}):
                ranked = content_pipeline.rerank_with_llm(candidates)

        self.assertEqual(ranked, candidates)
        self.assertEqual(ranked[0]["finalScore"], 68.0)


if __name__ == "__main__":
    unittest.main()
