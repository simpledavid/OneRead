# OneRead editorial pipeline

## Automatic edition (no human review)

`auto` clusters the day's items across sources, ranks them, and publishes two
diverse stories in one step:

```sh
export ONE_READ_LLM_API_KEY="..."
export ONE_READ_LLM_BASE_URL="https://api.deepseek.com"
export ONE_READ_LLM_MODEL="deepseek-chat"

python3 scripts/content_pipeline.py auto \
  --date 2026-06-18 \
  --output-dir /tmp/oneread-published

python3 scripts/content_pipeline.py validate \
  --file /tmp/oneread-published/2026-06-18.json
```

How it selects:

- **Cross-source clustering** merges the same event reported by different
  outlets (stdlib Jaccard + shared-entity matching, no embeddings). The
  representative is the highest-authority source in each cluster.
- **Corroboration ranking** boosts events covered by several independent
  sources — the more outlets report it, the more it matters.
- **Trending signal** gives a small boost to entities highlighted in today's
  [smol.ai AINews](https://news.smol.ai/) digest. Pass `--no-trending` to skip;
  any fetch failure degrades silently and never blocks the edition.
- **Multi-dimensional editorial scoring** evaluates the strongest candidates
  for relevance, reporting quality, and timeliness. The review JSON preserves
  the three scores, a category, keywords, and a concise selection reason. If
  the model call or response format fails, local ranking remains usable.
  The rubric is a OneRead-specific adaptation of the public design used by
  [ai-daily-digest](https://github.com/vigorX777/ai-daily-digest).
- Original source text must contain at least **150 words**. Thin RSS snippets
  are rejected during candidate preparation and checked again before publish.
- Morning is the top-ranked story; afternoon is the top-ranked story on a
  different topic (`diversity_key`). After the afternoon edition is released,
  the app displays that newer story above the morning story.

`--dry-run` clusters, selects, and prints a source-health report without writing
an edition. Leave `ONE_READ_LLM_API_KEY` unset for a no-LLM smoke test. Every
run writes `sources_health.json` (per-source fetched / kept / AI-relevance %)
next to the output.

Feeds are fetched and enriched in parallel (thread pool), so adding sources
does not slow the run linearly.

## Source filtering

Each entry in `content/sources.json` accepts:

- `filterKeywords` — include gate: the item must contain at least one term.
- `excludeKeywords` — exclude gate: the item is dropped on any match (used to
  strip deals, sponsored posts, and how-to noise from broad tech feeds).
- `filterScope` — `"title"` matches the title only; the default `"summary"`
  matches title + RSS summary.

## Manual edition (optional human-review gate)

```sh
python3 scripts/content_pipeline.py prepare \
  --date 2026-06-18 \
  --output /tmp/oneread-review.json

# Review the five candidates, then publish exactly two IDs in morning/afternoon order.
python3 scripts/content_pipeline.py publish \
  --review /tmp/oneread-review.json \
  --select C01,C03 \
  --output-dir /tmp/oneread-published

python3 scripts/content_pipeline.py validate \
  --file /tmp/oneread-published/2026-06-18.json
```

Upload the published directory to static hosting and set the app target's
`ONE_READ_CONTENT_BASE_URL` Info.plist value to its public base URL. The client
requests `YYYY-MM-DD.json`, then falls back to `latest.json`.

The analytics collector is optional. Set `ONE_READ_ANALYTICS_URL` to an HTTP
endpoint accepting:

```json
{"events":[{"id":"UUID","name":"article_complete","timestamp":"ISO-8601","articleID":"...","level":1,"metadata":{}}]}
```

Without either URL, the app uses its bundled approved preview edition and keeps
retention events queued locally.
