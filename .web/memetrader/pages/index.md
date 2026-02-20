---
title: ""
pagetitle: "Memetrader"
---

<link rel="stylesheet" href="/static/style.css" />
<link id="memetrader-theme-stylesheet" rel="stylesheet" href="/static/themes/psionic.css?v=memetrader20260220b" />

<div class="memetrader-app">
  <header class="hero">
    <h1>Memetrader</h1>
    <p>Local-first meme inventory with canonical identity hashing, cluster draws, MSIG tagging, and vote-driven temperature.</p>
    <div id="status" class="status">Loading…</div>
  </header>

  <section class="panel row2">
    <div>
      <h3>Ingest</h3>
      <label>File path on host</label>
      <input id="path" type="text" placeholder="/absolute/path/to/meme.file" spellcheck="false" />
      <label>MSIG</label>
      <input id="msig" type="text" placeholder="reaction,absurdism" spellcheck="false" />
      <label>Families</label>
      <input id="families" type="text" placeholder="family:cats" spellcheck="false" />
      <button id="ingest" type="button">Ingest</button>
    </div>
    <div>
      <h3>Actions</h3>
      <label>Selected SHA</label>
      <input id="sha" type="text" placeholder="pick from gallery" spellcheck="false" />
      <div class="inline">
        <button id="refresh" type="button">Refresh</button>
        <button id="draw" type="button">Draw</button>
        <button id="draw-tilt" type="button">Tilt Draw</button>
      </div>
      <div class="inline">
        <button id="upvote" type="button">Daily Upvote</button>
        <button id="meh" type="button">Meh</button>
      </div>
    </div>
  </section>

  <section class="panel row2">
    <div>
      <h3>Tagging</h3>
      <label>MSIG update</label>
      <input id="tag-msig" type="text" spellcheck="false" />
      <label>Families update</label>
      <input id="tag-families" type="text" spellcheck="false" />
      <button id="apply-tags" type="button">Apply Tags</button>
    </div>
    <div>
      <h3>Relations</h3>
      <label>Relation</label>
      <select id="rel-type">
        <option value="related">related</option>
        <option value="contrast">contrast</option>
        <option value="often-combined">often-combined</option>
        <option value="visually-similar">visually-similar</option>
      </select>
      <label>Target SHA</label>
      <input id="rel-target" type="text" spellcheck="false" />
      <button id="apply-rel" type="button">Add Relation</button>
      <label>Lineage precursor SHA</label>
      <input id="lineage-target" type="text" spellcheck="false" />
      <button id="apply-lineage" type="button">Set Lineage</button>
    </div>
  </section>

  <section class="panel">
    <h3>Gallery</h3>
    <table>
      <thead><tr><th>SHA</th><th>Name</th><th>Kind</th><th>Cluster</th><th>Temp</th><th>MSIG</th></tr></thead>
      <tbody id="gallery"></tbody>
    </table>
  </section>

  <section class="panel">
    <h3>Log</h3>
    <pre id="log"></pre>
  </section>
</div>
<div class="theme-dock">
  <div class="menu-anchor">
    <button id="theme-picker-btn" type="button" class="theme-picker-btn" aria-haspopup="menu" aria-expanded="false">Psionic</button>
    <div id="theme-picker-menu" class="floating-menu hidden" role="menu" aria-label="Theme selector">
      <div id="theme-picker-list" class="menu-list"></div>
    </div>
  </div>
</div>

<script src="/static/app.js"></script>
