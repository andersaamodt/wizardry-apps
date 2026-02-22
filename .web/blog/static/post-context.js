(function () {
  function isPostPage(pathname) {
    return /^\/pages\/posts\/.+\.html$/.test(pathname || '');
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function ensureMeta(name, value, attrType) {
    if (!value) {
      return;
    }
    var selector = attrType === 'property'
      ? 'meta[property="' + name + '"]'
      : 'meta[name="' + name + '"]';
    var node = document.querySelector(selector);
    if (!node) {
      node = document.createElement('meta');
      node.setAttribute(attrType === 'property' ? 'property' : 'name', name);
      document.head.appendChild(node);
    }
    node.setAttribute('content', value);
  }

  function renderTags(tags) {
    var clean = Array.isArray(tags) ? tags : [];
    if (!clean.length) {
      return '';
    }
    var chips = clean.map(function (tag) {
      var t = String(tag || '').trim();
      if (!t) {
        return '';
      }
      return '<a class="tag" href="/pages/tags.html#' + encodeURIComponent(t) + '">' + escapeHtml(t) + '</a>';
    }).filter(Boolean);
    if (!chips.length) {
      return '';
    }
    return '<div class="tags post-context-tags">' + chips.join('') + '</div>';
  }

  function renderPostMeta(current) {
    var summary = current.summary ? '<p class="post-context-summary">' + escapeHtml(current.summary) + '</p>' : '';
    var detail = [
      '<span class="post-context-date">' + escapeHtml(current.published_date || '') + '</span>',
      '<span aria-hidden="true">•</span>',
      '<span class="post-context-reading">' + escapeHtml(String(current.reading_minutes || 1)) + ' min read</span>',
      '<span aria-hidden="true">•</span>',
      '<span class="post-context-words">' + escapeHtml(String(current.word_count || 0)) + ' words</span>'
    ].join(' ');

    return '<section class="post-context-card">' +
      '<div class="post-context-detail">' + detail + '</div>' +
      summary +
      '</section>';
  }

  function renderPostEndTags(tags) {
    var content = renderTags(tags);
    if (!content) {
      return '';
    }
    return '<section class="post-end-tags">' +
      '<p class="post-end-tags-label">Tags</p>' +
      content +
      '</section>';
  }

  function navColumn(label, post, cls) {
    if (!post) {
      return '<div class="' + cls + '"><span class="post-nav-empty">' + escapeHtml(label) + ': none</span></div>';
    }
    return '<div class="' + cls + '">' +
      '<span class="post-nav-label">' + escapeHtml(label) + '</span>' +
      '<a href="' + escapeHtml(post.url || '#') + '">' + escapeHtml(post.title || 'Untitled') + '</a>' +
      '</div>';
  }

  function renderPostNav(payload) {
    return '<nav class="post-nav post-nav-enhanced" aria-label="Post navigation">' +
      navColumn('Newer', payload.newer, 'post-nav-prev') +
      navColumn('Older', payload.older, 'post-nav-next') +
      '</nav>';
  }

  function applyEnhancements(payload) {
    if (!payload || !payload.current || document.querySelector('.post-context-card')) {
      return;
    }

    var heading = document.querySelector('h1[id]') || document.querySelector('h1');
    if (!heading) {
      return;
    }

    heading.insertAdjacentHTML('afterend', renderPostMeta(payload.current));

    if (!document.querySelector('.post-end-tags')) {
      var tagsHtml = renderPostEndTags(payload.current.tags);
      if (tagsHtml) {
        var tagAnchor = document.querySelector('#main-content') || document.body;
        tagAnchor.insertAdjacentHTML('beforeend', tagsHtml);
      }
    }

    if (!document.querySelector('.post-nav-enhanced')) {
      var anchor = document.querySelector('#main-content') || document.body;
      anchor.insertAdjacentHTML('beforeend', renderPostNav(payload));
    }

    ensureMeta('description', payload.current.summary || '', 'name');
    ensureMeta('og:description', payload.current.summary || '', 'property');
    ensureMeta('article:published_time', payload.current.published_at || '', 'property');
    ensureMeta('twitter:description', payload.current.summary || '', 'name');
  }

  function loadPostContext() {
    if (!isPostPage(window.location.pathname)) {
      return;
    }

    var relPath = window.location.pathname.replace(/^\/pages\/posts\//, '');
    fetch('/cgi/blog-post-context?path=' + encodeURIComponent(relPath), { credentials: 'same-origin' })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (!data || !data.success) {
          return;
        }
        applyEnhancements(data);
      })
      .catch(function () {
        // Post page should remain readable even if enhancement fetch fails.
      });
  }

  document.addEventListener('DOMContentLoaded', loadPostContext);
})();
