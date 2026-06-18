# OneRead editorial pipeline

The pipeline has an explicit human-review gate:

```sh
export ONE_READ_LLM_API_KEY="..."
export ONE_READ_LLM_BASE_URL="https://api.deepseek.com"
export ONE_READ_LLM_MODEL="deepseek-chat"

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
