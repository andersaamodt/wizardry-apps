(function (global) {
  function ready(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function normalizeSearchText(value) {
    var text = String(value || '').toLowerCase();
    if (text.normalize) {
      text = text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    }
    return text;
  }

  function searchTokens(value) {
    return normalizeSearchText(value)
      .split(/[^a-z0-9]+/)
      .filter(function (token) { return token.length > 1; });
  }

  function escapeRegExp(value) {
    return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function tokenMatchesSearchText(text, token) {
    if (token.length <= 3) {
      return new RegExp('(^|[^a-z0-9])' + escapeRegExp(token) + '([^a-z0-9]|$)').test(text);
    }
    return text.indexOf(token) !== -1;
  }

  function uniqueStrings(values) {
    var seen = Object.create(null);
    return (values || []).filter(function (value) {
      var key = String(value || '');
      if (!key || seen[key]) return false;
      seen[key] = true;
      return true;
    });
  }

  function titleCaseLabel(value) {
    return String(value || '')
      .replace(/[_-]+/g, ' ')
      .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/\b\w/g, function (char) { return char.toUpperCase(); });
  }

  function distanceMetersBetween(a, b) {
    var lat1 = Number(a && a.latitude);
    var lon1 = Number(a && a.longitude);
    var lat2 = Number(b && b.latitude);
    var lon2 = Number(b && b.longitude);
    if (![lat1, lon1, lat2, lon2].every(Number.isFinite)) return Infinity;
    var toRad = Math.PI / 180;
    var dLat = (lat2 - lat1) * toRad;
    var dLon = (lon2 - lon1) * toRad;
    var s1 = Math.sin(dLat / 2);
    var s2 = Math.sin(dLon / 2);
    var x = s1 * s1 + Math.cos(lat1 * toRad) * Math.cos(lat2 * toRad) * s2 * s2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
  }

  function compareSortableValues(a, b, key, direction, type) {
    var ascending = direction === 'asc';
    var aValue = a.getAttribute('data-sort-' + key) || '';
    var bValue = b.getAttribute('data-sort-' + key) || '';
    var aMissing = aValue === '' || aValue === null;
    var bMissing = bValue === '' || bValue === null;
    if (aMissing && bMissing) return 0;
    if (aMissing) return 1;
    if (bMissing) return -1;
    if (type === 'number') {
      var aNum = parseFloat(aValue);
      var bNum = parseFloat(bValue);
      if (aNum < bNum) return ascending ? -1 : 1;
      if (aNum > bNum) return ascending ? 1 : -1;
      return 0;
    }
    return ascending ? aValue.localeCompare(bValue) : bValue.localeCompare(aValue);
  }

  function queryAll(root, selector) {
    return Array.prototype.slice.call((root || document).querySelectorAll(selector));
  }

  function setupSortableTables(options) {
    options = options || {};
    var root = options.root || document;
    var tables = root.querySelectorAll(options.tableSelector || 'table.sortable-table');
    if (!tables || tables.length === 0) return;
    Array.prototype.forEach.call(tables, function (table) {
      var tbody = table.querySelector('tbody');
      if (!tbody) return;
      var rows = queryAll(tbody, options.rowSelector || 'tr[data-sort-row]');
      if (rows.length === 0) return;
      var sortButtons = table.querySelectorAll(options.buttonSelector || 'button[data-sort-key][data-sort-type][data-sort-direction]');
      if (sortButtons.length === 0) return;
      var activeButton = null;
      Array.prototype.forEach.call(sortButtons, function (button) {
        var key = button.getAttribute('data-sort-key');
        var type = button.getAttribute('data-sort-type');
        var defaultDirection = button.getAttribute('data-sort-direction');
        button.addEventListener('click', function () {
          var ascending = defaultDirection === 'asc';
          if (activeButton === button) ascending = button.getAttribute('aria-sort') === 'desc';
          if (activeButton && activeButton !== button) activeButton.removeAttribute('aria-sort');
          button.setAttribute('aria-sort', ascending ? 'asc' : 'desc');
          activeButton = button;
          rows.sort(function (rowA, rowB) {
            return compareSortableValues(rowA, rowB, key, ascending ? 'asc' : 'desc', type);
          });
          rows.forEach(function (row) { tbody.appendChild(row); });
          table.dispatchEvent(new CustomEvent('directory-sorted', { bubbles: true }));
        });
      });
      var autoSortKey = table.getAttribute('data-sort-auto');
      if (!autoSortKey) return;
      Array.prototype.forEach.call(sortButtons, function (button) {
        if (button.getAttribute('data-sort-key') === autoSortKey) button.click();
      });
    });
  }

  function setupDirectoryTablePan(options) {
    options = options || {};
    var wrap = (options.root || document).querySelector(options.wrapSelector || '.directory-table-wrap');
    if (!wrap) return;
    var state = null;
    var dragThreshold = options.dragThreshold || 6;

    wrap.addEventListener('pointerdown', function (event) {
      if (event.button !== 0) return;
      if (event.pointerType === 'touch') return;
      if (event.target.closest('button, input, select, textarea, label, [data-directory-column-resizer]')) return;
      var selection = window.getSelection && window.getSelection();
      if (selection && !selection.isCollapsed) return;
      if (wrap.scrollWidth <= wrap.clientWidth && wrap.scrollHeight <= wrap.clientHeight) return;
      state = {
        pointerId: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        scrollLeft: wrap.scrollLeft,
        scrollY: window.scrollY || window.pageYOffset || 0,
        dragging: false
      };
      if (event.pointerId !== undefined && wrap.setPointerCapture) {
        try { wrap.setPointerCapture(event.pointerId); } catch (_error) {}
      }
    });

    wrap.addEventListener('pointermove', function (event) {
      if (!state || event.pointerId !== state.pointerId) return;
      var deltaX = event.clientX - state.startX;
      var deltaY = event.clientY - state.startY;
      if (!state.dragging && Math.hypot(deltaX, deltaY) < dragThreshold) return;
      state.dragging = true;
      wrap.classList.add('is-panning');
      wrap.scrollLeft = state.scrollLeft - deltaX;
      window.scrollTo(window.scrollX || window.pageXOffset || 0, state.scrollY - deltaY);
      event.preventDefault();
    });

    function finishPan(event) {
      if (!state || event.pointerId !== state.pointerId) return;
      var wasDragging = state.dragging;
      state = null;
      wrap.classList.remove('is-panning');
      try { wrap.releasePointerCapture(event.pointerId); } catch (_error) {}
      if (!wasDragging) return;
      event.preventDefault();
      wrap.dataset.suppressRowClick = 'true';
      wrap.dispatchEvent(new CustomEvent('directory-pan-finished', { bubbles: true }));
      window.setTimeout(function () { delete wrap.dataset.suppressRowClick; }, 450);
    }

    wrap.addEventListener('pointerup', finishPan);
    wrap.addEventListener('pointercancel', finishPan);
    wrap.addEventListener('click', function (event) {
      if (wrap.dataset.suppressRowClick !== 'true') return;
      event.preventDefault();
      event.stopPropagation();
    }, true);
  }

  function setupDirectoryColumnResize(options) {
    options = options || {};
    var root = options.root || document;
    var table = root.querySelector(options.tableSelector || '.directory-table');
    if (!table) return;
    var headers = queryAll(table, options.headerSelector || '[data-directory-resizable-column]');
    if (!headers.length) return;
    var storageKey = options.storageKey || 'rating-site-directory-column-widths-v1';
    var saved = {};
    try { saved = JSON.parse(window.localStorage.getItem(storageKey) || '{}') || {}; } catch (_error) {}

    function cssVarFor(key) {
      return '--directory-' + key + '-width';
    }

    function clamp(value, min, max) {
      return Math.max(min, Math.min(max, value));
    }

    function applyWidth(key, width) {
      table.style.setProperty(cssVarFor(key), width + 'px');
      saved[key] = width;
      try { window.localStorage.setItem(storageKey, JSON.stringify(saved)); } catch (_error) {}
    }

    headers.forEach(function (header) {
      var key = header.getAttribute('data-directory-resize-key');
      if (!key) return;
      if (saved[key]) applyWidth(key, Number(saved[key]));
      var handle = header.querySelector('[data-directory-column-resizer]');
      if (!handle) return;
      var state = null;
      var minWidth = Number(header.getAttribute('data-directory-resize-min')) || 120;
      var maxWidth = Number(header.getAttribute('data-directory-resize-max')) || 640;
      handle.addEventListener('pointerdown', function (event) {
        if (event.button !== 0) return;
        state = { pointerId: event.pointerId, startX: event.clientX, startWidth: header.getBoundingClientRect().width };
        header.classList.add('is-resizing');
        document.body.classList.add('is-directory-column-resizing');
        handle.setPointerCapture(event.pointerId);
        event.preventDefault();
        event.stopPropagation();
      });
      handle.addEventListener('pointermove', function (event) {
        if (!state || event.pointerId !== state.pointerId) return;
        var nextWidth = clamp(Math.round(state.startWidth + event.clientX - state.startX), minWidth, maxWidth);
        applyWidth(key, nextWidth);
        event.preventDefault();
        event.stopPropagation();
      });
      function finishResize(event) {
        if (!state || event.pointerId !== state.pointerId) return;
        state = null;
        header.classList.remove('is-resizing');
        document.body.classList.remove('is-directory-column-resizing');
        try { handle.releasePointerCapture(event.pointerId); } catch (_error) {}
        event.preventDefault();
        event.stopPropagation();
      }
      handle.addEventListener('pointerup', finishResize);
      handle.addEventListener('pointercancel', finishResize);
      handle.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
      });
    });
  }

  function setupDirectoryDetailColumns(options) {
    options = options || {};
    var root = options.root || document;
    var toggle = root.querySelector(options.toggleSelector || '[data-directory-detail-toggle]');
    var columnHeaders = queryAll(root, options.headerSelector || '.directory-table thead [data-directory-column-key]');
    var detailCells = queryAll(root, options.detailSelector || '[data-directory-detail-column]');
    var trigger = root.querySelector(options.triggerSelector || '[data-directory-column-customize-trigger]');
    var wrap = root.querySelector(options.wrapSelector || '.directory-table-wrap');
    if (!toggle || detailCells.length === 0) return;
    var initialized = false;
    var storageKey = options.storageKey || 'rating-site-directory-column-visibility-v1';
    var stored = {};
    var columns = [];
    var state = {};
    var panel = null;
    var checkboxByKey = {};
    try { stored = JSON.parse(window.localStorage.getItem(storageKey) || '{}') || {}; } catch (_error) {}

    columnHeaders.forEach(function (header) {
      var key = header.getAttribute('data-directory-column-key');
      if (!key || state[key] !== undefined) return;
      var label = header.getAttribute('data-directory-column-label') || header.textContent.trim() || key;
      var detailColumn = header.hasAttribute('data-directory-detail-column');
      var defaultVisible = !detailColumn && !header.hidden;
      var visible = Object.prototype.hasOwnProperty.call(stored, key) ? stored[key] !== false : defaultVisible;
      columns.push({ key: key, label: label, detailColumn: detailColumn, defaultVisible: defaultVisible, index: header.cellIndex });
      state[key] = visible;
    });

    function saveState() {
      try { window.localStorage.setItem(storageKey, JSON.stringify(state)); } catch (_error) {}
    }

    function detailColumnKeys() {
      return columns.filter(function (column) { return column.detailColumn; }).map(function (column) { return column.key; });
    }

    function syncBulkToggle() {
      var keys = detailColumnKeys();
      var checkedCount = keys.filter(function (key) { return state[key] !== false; }).length;
      toggle.checked = keys.length > 0 && checkedCount === keys.length;
      toggle.indeterminate = checkedCount > 0 && checkedCount < keys.length;
    }

    function setColumnVisible(key, visible) {
      state[key] = Boolean(visible);
      columns.filter(function (column) { return column.key === key; }).forEach(function (column) {
        columnHeaders.forEach(function (header) {
          if (header.cellIndex === column.index) header.hidden = !state[key];
        });
        var table = columnHeaders[0] && columnHeaders[0].closest('table');
        if (!table) return;
        Array.prototype.forEach.call(table.tBodies, function (tbody) {
          Array.prototype.forEach.call(tbody.rows, function (row) {
            if (row.cells[column.index]) row.cells[column.index].hidden = !state[key];
          });
        });
      });
      if (checkboxByKey[key]) checkboxByKey[key].checked = state[key];
    }

    function sync() {
      columns.forEach(function (column) { setColumnVisible(column.key, state[column.key] !== false); });
      syncBulkToggle();
      if (wrap) {
        wrap.setAttribute('data-directory-expanded', detailColumnKeys().some(function (key) { return state[key] !== false; }) ? 'true' : 'false');
      }
      initialized = true;
      return initialized;
    }

    function setDetailColumnsVisible(visible) {
      detailColumnKeys().forEach(function (key) { state[key] = Boolean(visible); });
      saveState();
      sync();
    }

    function closePanel() {
      if (!panel || panel.hidden) return;
      panel.hidden = true;
      if (trigger) trigger.setAttribute('aria-expanded', 'false');
    }

    function positionPanel() {
      if (!trigger || !panel || panel.hidden) return;
      var rect = trigger.getBoundingClientRect();
      var maxLeft = Math.max(8, window.innerWidth - panel.offsetWidth - 8);
      var left = Math.min(Math.max(8, rect.left), maxLeft);
      var top = Math.min(rect.bottom + 6, Math.max(8, window.innerHeight - panel.offsetHeight - 8));
      panel.style.left = left + 'px';
      panel.style.top = top + 'px';
    }

    function buildPanel() {
      if (!trigger || panel) return;
      panel = document.createElement('div');
      panel.className = 'directory-column-popover';
      panel.hidden = true;
      panel.setAttribute('role', 'dialog');
      panel.setAttribute('aria-label', 'Customize directory columns');
      panel.innerHTML = '<div class="directory-column-popover-head"><strong>Columns</strong><button type="button" class="directory-column-popover-close" data-directory-column-popover-close aria-label="Close column customizer">&times;</button></div><div class="directory-column-list" data-directory-column-list></div>';
      var list = panel.querySelector('[data-directory-column-list]');
      columns.forEach(function (column) {
        var label = document.createElement('label');
        label.className = 'directory-column-choice';
        var input = document.createElement('input');
        input.type = 'checkbox';
        input.checked = state[column.key] !== false;
        input.setAttribute('data-directory-column-choice', column.key);
        var span = document.createElement('span');
        span.textContent = column.label;
        label.appendChild(input);
        label.appendChild(span);
        list.appendChild(label);
        checkboxByKey[column.key] = input;
        input.addEventListener('change', function () {
          state[column.key] = input.checked;
          saveState();
          sync();
        });
      });
      trigger.insertAdjacentElement('afterend', panel);
      panel.querySelector('[data-directory-column-popover-close]').addEventListener('click', closePanel);
    }

    toggle.addEventListener('change', function () { setDetailColumnsVisible(toggle.checked); });
    if (trigger) {
      buildPanel();
      trigger.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (!panel) return;
        var shouldOpen = panel.hidden;
        panel.hidden = !shouldOpen;
        trigger.setAttribute('aria-expanded', shouldOpen ? 'true' : 'false');
        if (shouldOpen) {
          positionPanel();
          var firstCheckbox = panel.querySelector('input[type="checkbox"]');
          if (firstCheckbox) firstCheckbox.focus();
        }
      });
      window.addEventListener('resize', positionPanel);
      window.addEventListener('scroll', positionPanel, true);
      document.addEventListener('click', function (event) {
        if (!panel || panel.hidden) return;
        if (panel.contains(event.target) || trigger.contains(event.target)) return;
        closePanel();
      });
      document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') closePanel();
      });
    }
    sync();
  }

  function setupFilterableDirectory(options) {
    options = options || {};
    var root = options.root || document;
    var input = root.querySelector(options.inputSelector || '#entity-filter');
    var clearQueryButton = root.querySelector(options.clearQuerySelector || '[data-directory-clear-query]');
    var compareToggle = root.querySelector(options.compareToggleSelector || '[data-directory-compare-toggle]');
    var compareItems = queryAll(root, options.compareItemSelector || '[data-directory-compare-item]');
    var rows = queryAll(root, options.rowSelector || '[data-entity-row]');
    var emptyState = root.querySelector(options.emptyStateSelector || '[data-directory-empty-state]');
    var resultCount = root.querySelector(options.resultCountSelector || '[data-directory-result-count]');
    var loadMoreWrap = root.querySelector(options.loadMoreWrapSelector || '[data-directory-load-more-wrap]');
    var loadMoreButton = root.querySelector(options.loadMoreButtonSelector || '[data-directory-load-more]');
    var autoLoadOnly = options.autoLoadOnly === true;
    var pageSize = options.pageSize || 150;
    var displayedRowLimit = pageSize;
    var directoryAutoloadTicking = false;
    var filterSyncTimer = 0;
    var filterConfigs = options.filterConfigs || [];
    var loadMoreObserver = null;
    if (!rows.length) return null;

    rows.forEach(function (row) {
      row._ratingSiteSearchText = normalizeSearchText(row.getAttribute('data-search') || row.textContent || '');
    });

    function currentFilters() {
      var filters = { query: input ? input.value.trim() : '', compareOnly: compareToggle ? compareToggle.checked : false };
      filterConfigs.forEach(function (config) {
        if (!config.element) return;
        if (config.type === 'checkbox') filters[config.key] = config.element.checked;
        else filters[config.key] = config.element.value;
      });
      return filters;
    }

    function countMatches(filters, overrides) {
      return rows.filter(function (row) {
        return options.rowMatches(row, filters, overrides || {}, {
          normalizeSearchText: normalizeSearchText,
          tokenMatchesSearchText: tokenMatchesSearchText,
          searchTokens: searchTokens
        });
      }).length;
    }

    function updateResultCount(visibleCount) {
      if (resultCount) {
        var shownCount = Math.min(visibleCount, displayedRowLimit);
        resultCount.textContent = options.resultCountText
          ? options.resultCountText(visibleCount, shownCount)
          : ('Showing ' + shownCount + ' of ' + visibleCount + ' ' + (visibleCount === 1 ? 'entry' : 'entries'));
      }
      if (loadMoreWrap) loadMoreWrap.hidden = Math.min(visibleCount, displayedRowLimit) >= visibleCount;
      if (loadMoreButton) {
        var remaining = Math.max(0, visibleCount - Math.min(visibleCount, displayedRowLimit));
        loadMoreButton.hidden = autoLoadOnly;
        loadMoreButton.textContent = remaining ? 'Load ' + Math.min(pageSize, remaining) + ' more' : 'Load more';
      }
      if (loadMoreWrap) loadMoreWrap.setAttribute('data-directory-autoload-only', autoLoadOnly ? 'true' : 'false');
    }

    function updateClearQueryButton() {
      if (!clearQueryButton || !input) return;
      clearQueryButton.hidden = input.value.trim().length === 0;
    }

    function updateEmptyState(filters, visibleCount) {
      if (!emptyState) return;
      if (visibleCount > 0) {
        emptyState.hidden = true;
        emptyState.textContent = '';
        return;
      }
      emptyState.textContent = options.emptyStateText
        ? options.emptyStateText(filters, countMatches)
        : 'No entries match the current filters.';
      emptyState.hidden = false;
    }

    function sync() {
      window.clearTimeout(filterSyncTimer);
      rows = queryAll(root, options.rowSelector || '[data-entity-row]');
      var filters = currentFilters();
      var selectedCount = compareItems.filter(function (item) { return item.checked; }).length;
      if (compareToggle) {
        compareToggle.disabled = selectedCount < 2;
        if (selectedCount < 2) compareToggle.checked = false;
      }
      filters.compareOnly = compareToggle ? compareToggle.checked : false;
      var visibleCount = 0;
      var shownCount = 0;
      rows.forEach(function (row) {
        var matches = options.rowMatches(row, filters, {}, {
          normalizeSearchText: normalizeSearchText,
          tokenMatchesSearchText: tokenMatchesSearchText,
          searchTokens: searchTokens
        });
        if (matches) visibleCount += 1;
        var shown = matches && shownCount < displayedRowLimit;
        row.hidden = !shown;
        row.toggleAttribute('data-directory-match-hidden', matches && !shown);
        if (shown) shownCount += 1;
      });
      updateResultCount(visibleCount);
      updateClearQueryButton();
      updateEmptyState(filters, visibleCount);
      if (typeof options.onSync === 'function') options.onSync({ filters: filters, visibleCount: visibleCount, shownCount: shownCount, countMatches: countMatches });
      scheduleDirectoryAutoloadCheck();
    }

    function resetDisplayedRowLimit() {
      displayedRowLimit = pageSize;
    }

    function loadMoreDirectoryRows() {
      if (!loadMoreWrap || loadMoreWrap.hidden) return false;
      displayedRowLimit += pageSize;
      sync();
      scheduleDirectoryAutoloadCheck();
      return true;
    }

    function checkDirectoryAutoload() {
      directoryAutoloadTicking = false;
      if (!loadMoreWrap || loadMoreWrap.hidden) return;
      var rect = loadMoreWrap.getBoundingClientRect();
      var viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
      if (rect.top <= viewportHeight + 480) loadMoreDirectoryRows();
    }

    function scheduleDirectoryAutoloadCheck() {
      if (directoryAutoloadTicking) return;
      directoryAutoloadTicking = true;
      if (window.requestAnimationFrame) window.requestAnimationFrame(checkDirectoryAutoload);
      else window.setTimeout(checkDirectoryAutoload, 16);
      window.setTimeout(function () {
        if (directoryAutoloadTicking) checkDirectoryAutoload();
      }, 160);
    }

    function scheduleTextFilterSync() {
      updateClearQueryButton();
      window.clearTimeout(filterSyncTimer);
      filterSyncTimer = window.setTimeout(sync, options.debounceMs || 120);
    }

    function setupLoadMoreObserver() {
      if (!loadMoreWrap || !window.IntersectionObserver || loadMoreObserver) return;
      loadMoreObserver = new window.IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) loadMoreDirectoryRows();
        });
      }, {
        root: null,
        rootMargin: '480px 0px 480px 0px'
      });
      loadMoreObserver.observe(loadMoreWrap);
    }

    if (input) {
      input.addEventListener('input', function () { resetDisplayedRowLimit(); scheduleTextFilterSync(); });
      input.addEventListener('search', function () { resetDisplayedRowLimit(); sync(); });
    }
    if (clearQueryButton && input) {
      clearQueryButton.addEventListener('click', function () {
        input.value = '';
        input.focus();
        resetDisplayedRowLimit();
        sync();
      });
    }
    filterConfigs.forEach(function (config) {
      if (!config.element) return;
      config.element.addEventListener('change', function () { resetDisplayedRowLimit(); sync(); });
    });
    if (compareToggle) compareToggle.addEventListener('change', function () { resetDisplayedRowLimit(); sync(); });
    compareItems.forEach(function (item) {
      item.addEventListener('change', function () { resetDisplayedRowLimit(); sync(); });
    });
    if (loadMoreButton) loadMoreButton.addEventListener('click', loadMoreDirectoryRows);
    setupLoadMoreObserver();
    window.addEventListener('scroll', scheduleDirectoryAutoloadCheck, { passive: true });
    window.addEventListener('resize', scheduleDirectoryAutoloadCheck);
    document.addEventListener('directory-sorted', function () {
      resetDisplayedRowLimit();
      sync();
    });
    sync();
    return { sync: sync, resetDisplayedRowLimit: resetDisplayedRowLimit, countMatches: countMatches };
  }

  var existing = global.RatingSiteShared || {};
  global.RatingSiteShared = {
    ready: existing.ready || ready,
    escapeHtml: existing.escapeHtml || escapeHtml,
    normalizeSearchText: existing.normalizeSearchText || normalizeSearchText,
    searchTokens: existing.searchTokens || searchTokens,
    tokenMatchesSearchText: existing.tokenMatchesSearchText || tokenMatchesSearchText,
    uniqueStrings: existing.uniqueStrings || uniqueStrings,
    titleCaseLabel: existing.titleCaseLabel || titleCaseLabel,
    distanceMetersBetween: existing.distanceMetersBetween || distanceMetersBetween,
    compareSortableValues: existing.compareSortableValues || compareSortableValues,
    setupSortableTables: existing.setupSortableTables || setupSortableTables,
    setupDirectoryTablePan: existing.setupDirectoryTablePan || setupDirectoryTablePan,
    setupDirectoryColumnResize: existing.setupDirectoryColumnResize || setupDirectoryColumnResize,
    setupDirectoryDetailColumns: existing.setupDirectoryDetailColumns || setupDirectoryDetailColumns,
    setupFilterableDirectory: existing.setupFilterableDirectory || setupFilterableDirectory
  };
})(window);
