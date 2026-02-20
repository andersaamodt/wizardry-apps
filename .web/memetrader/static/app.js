(function () {
  'use strict';

  function el(id) { return document.getElementById(id); }

  function setStatus(text, isErr) {
    var node = el('status');
    node.textContent = text;
    node.style.color = isErr ? '#ffb4aa' : '#8cf7d5';
  }

  function log(text) {
    var out = el('log');
    out.textContent = '[' + new Date().toLocaleTimeString() + '] ' + text + '\n' + out.textContent;
  }

  async function api(params) {
    var body = new URLSearchParams(params || {});
    var res = await fetch('/cgi/memetrader-api', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });
    if (!res.ok) {
      throw new Error('HTTP ' + res.status);
    }
    var json = await res.json();
    if (!json.ok) {
      throw new Error(json.error || 'request failed');
    }
    return json;
  }

  function render(items) {
    var tbody = el('gallery');
    tbody.textContent = '';
    (items || []).forEach(function (item) {
      var tr = document.createElement('tr');
      tr.innerHTML = '<td><code>' + (item.sha || '') + '</code></td>' +
        '<td>' + (item.name || '') + '</td>' +
        '<td>' + (item.kind || '') + '</td>' +
        '<td>' + (item.cluster || '') + '</td>' +
        '<td>' + (item.temperature || '') + '</td>' +
        '<td>' + (item.msig || '') + '</td>';
      tr.addEventListener('click', function () {
        el('sha').value = item.sha || '';
      });
      tbody.appendChild(tr);
    });
  }

  function selectedSha() {
    return String(el('sha').value || '').trim();
  }

  async function refresh() {
    setStatus('Refreshing…', false);
    var st = await api({ action: 'status' });
    var list = await api({ action: 'list', limit: '120' });
    render(list.items || []);
    setStatus('Ready - ' + st.total + ' memes (' + st.hot + ' hot, ' + st.warm + ' warm, ' + st.cold + ' cold)', false);
  }

  async function doIngest() {
    var path = String(el('path').value || '').trim();
    if (!path) throw new Error('path required');
    var out = await api({ action: 'ingest', path: path, msig: el('msig').value || '', families: el('families').value || '' });
    el('sha').value = out.sha256_canon || '';
    log('Ingested ' + (out.sha256_canon || 'unknown'));
    await refresh();
  }

  async function vote(kind) {
    var sha = selectedSha();
    if (!sha) throw new Error('select a meme first');
    var out = await api({ action: 'vote', sha: sha, vote: kind });
    log('Vote ' + kind + ': ' + out.temperature + ' (' + out.temp_score + ')');
    await refresh();
  }

  async function draw(tilt) {
    var out = await api({ action: 'draw', tilt: tilt ? '1' : '0' });
    el('sha').value = out.sha || '';
    log('Draw: ' + out.sha + ' cluster=' + out.cluster + ' temp=' + out.temperature);
  }

  async function applyTags() {
    var sha = selectedSha();
    if (!sha) throw new Error('select a meme first');
    await api({ action: 'tag', sha: sha, msig: el('tag-msig').value || '', families: el('tag-families').value || '' });
    log('Tags updated for ' + sha);
    await refresh();
  }

  async function applyRel() {
    var sha = selectedSha();
    if (!sha) throw new Error('select a meme first');
    var target = String(el('rel-target').value || '').trim();
    if (!target) throw new Error('target required');
    await api({ action: 'relate', sha: sha, rel: el('rel-type').value, target: target });
    log('Relation added: ' + sha + ' -> ' + target);
  }

  async function applyLineage() {
    var sha = selectedSha();
    if (!sha) throw new Error('select a meme first');
    var precursor = String(el('lineage-target').value || '').trim();
    if (!precursor) throw new Error('precursor required');
    await api({ action: 'lineage', sha: sha, precursor: precursor });
    log('Lineage set: ' + precursor + ' -> ' + sha);
  }

  async function run(fn) {
    try {
      setStatus('Working…', false);
      await fn();
      setStatus('Ready', false);
    } catch (err) {
      setStatus(String(err && err.message ? err.message : err), true);
      log('Error: ' + String(err && err.message ? err.message : err));
    }
  }

  window.addEventListener('DOMContentLoaded', function () {
    el('refresh').addEventListener('click', function () { run(refresh); });
    el('ingest').addEventListener('click', function () { run(doIngest); });
    el('upvote').addEventListener('click', function () { run(function () { return vote('up'); }); });
    el('meh').addEventListener('click', function () { run(function () { return vote('meh'); }); });
    el('draw').addEventListener('click', function () { run(function () { return draw(false); }); });
    el('draw-tilt').addEventListener('click', function () { run(function () { return draw(true); }); });
    el('apply-tags').addEventListener('click', function () { run(applyTags); });
    el('apply-rel').addEventListener('click', function () { run(applyRel); });
    el('apply-lineage').addEventListener('click', function () { run(applyLineage); });
    run(refresh);
  });
})();
