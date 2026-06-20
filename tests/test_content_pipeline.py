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

    def test_validate_article_rejects_original_under_120_words(self):
        article = self.valid_article_with_body_words(119)

        with self.assertRaisesRegex(
            ValueError,
            "original article body must contain at least 120 words",
        ):
            content_pipeline.validate_article(article)

    def test_validate_article_accepts_original_at_120_words(self):
        content_pipeline.validate_article(self.valid_article_with_body_words(120))

    def test_clean_article_paragraphs_removes_publisher_chrome_and_duplicates(self):
        paragraphs = [
            "Posts from this topic will be added to your daily email digest and your homepage feed.",
            'Loading the player… var playerInstance = jwplayer("video");',
            "\ufeffRelativity Space will launch NASA's Aeolus payload to Mars in 2028.",
            "Relativity Space will launch NASA's Aeolus payload to Mars in 2028.",
            "NASA says the instruments will study winds, temperatures, dust, and clouds.",
            "Subscribe to this show on YouTube and all podcast apps.",
            "A related story that must not leak into the article body.",
        ]

        self.assertEqual(
            content_pipeline.clean_article_paragraphs(paragraphs),
            [
                "Relativity Space will launch NASA's Aeolus payload to Mars in 2028.",
                "NASA says the instruments will study winds, temperatures, dust, and clouds.",
            ],
        )

    def test_reading_candidate_rejects_video_and_podcast_pages(self):
        self.assertFalse(
            content_pipeline.is_reading_candidate(
                {"urlString": "https://techcrunch.com/video/example/"}
            )
        )
        self.assertFalse(
            content_pipeline.is_reading_candidate(
                {"urlString": "https://example.com/podcasts/daily-show"}
            )
        )
        self.assertTrue(
            content_pipeline.is_reading_candidate(
                {"urlString": "https://example.com/science/mars-mission"}
            )
        )

    def test_validate_article_rejects_duplicate_original_paragraphs(self):
        article = self.valid_article_with_body_words(120)
        article["body"] = article["body"] * 2
        article["paragraphTranslations"] = article["paragraphTranslations"] * 2

        with self.assertRaisesRegex(
            ValueError,
            "duplicate or boilerplate paragraphs",
        ):
            content_pipeline.validate_article(article)

    def test_translation_validation_rejects_trillionaire_as_billionaire(self):
        self.assertFalse(
            content_pipeline.translations_preserve_critical_terms(
                ["The company was founded by a trillionaire."],
                ["这家公司由一位亿万富翁创立。"],
            )
        )
        self.assertTrue(
            content_pipeline.translations_preserve_critical_terms(
                ["The company was founded by a trillionaire."],
                ["这家公司由一位万亿富翁创立。"],
            )
        )

    def test_contextual_word_requests_keep_same_word_separate_by_context(self):
        article = {
            "title": "Bank technology",
            "body": [
                "The bank approved the loan.",
                "They rested on the river bank.",
            ],
        }
        learning = {
            "standard": {
                "paragraphs": ["A bank can mean a company or the side of a river."]
            }
        }

        requests = content_pipeline.contextual_word_requests(article, learning)

        self.assertEqual(len(requests), 4)
        self.assertIn(
            "bank",
            requests[content_pipeline.context_fingerprint("The bank approved the loan.")]["words"],
        )
        self.assertIn(
            "bank",
            requests[content_pipeline.context_fingerprint("They rested on the river bank.")]["words"],
        )

    @staticmethod
    def valid_article_with_body_words(count):
        body = [" ".join(f"word{index}" for index in range(count))]
        learning_version = {
            "paragraphs": ["A valid learning paragraph."],
            "paragraphTranslations": ["有效的学习段落。"],
            "targetWords": 100,
            "cefr": "B1-B2",
        }
        vocabulary = [
            {
                "word": f"term{index}",
                "meaningZh": "释义",
                "phonetic": "",
                "example": "Example.",
                "exampleZh": "例句。",
            }
            for index in range(5)
        ]
        return {
            "id": "article-id",
            "title": "A sufficiently detailed article",
            "source": "Source",
            "body": body,
            "urlString": "https://example.com/article",
            "editionDate": "2026-06-19",
            "editionSlot": "morning",
            "curationStatus": "approved",
            "paragraphTranslations": ["原文翻译。"],
            "learningContent": {
                "easy": learning_version,
                "standard": learning_version,
                "vocabulary": vocabulary,
                "wordMeaningsByContext": {
                    content_pipeline.context_fingerprint("A valid learning paragraph."): {
                        "a": "一个",
                        "valid": "有效的",
                    }
                },
            },
        }


if __name__ == "__main__":
    unittest.main()
