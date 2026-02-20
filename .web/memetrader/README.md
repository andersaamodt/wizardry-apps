# Memetrader Template

Memetrader is a local-first meme trading and curation app.

## Current MVP

- Trade unit = one media artifact file
- Raw artifact preserved under `~/.memes/artifacts/raw`
- Canon artifact derived under `~/.memes/artifacts/canon`
- Identity via `sha256_canon`
- Perceptual hash + cluster id for similarity/dedupe assists
- MSIG and families stored in sidecar `.meta` files
- Vote logs append to `~/.memes/votes/<sha>.votes`
- Temperature tiers: `hot`, `warm`, `cold`
- Uniform cluster draw + optional heat tilt draw
- Curator patch proposal/apply flow via flat patchfiles

## Runtime

- Frontend: `/pages/index.html`
- API: `/cgi/memetrader-api`
- Backend implementation: `/cgi/memetrader-backend.sh`

This template remains local-first and file-first, with no global database.
