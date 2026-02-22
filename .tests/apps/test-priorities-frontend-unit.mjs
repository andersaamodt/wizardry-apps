#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import vm from 'vm';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const appFile = path.join(root, '.apps', 'priorities', 'index.html');

function fail(msg) {
  console.error(`FAIL: ${msg}`);
  process.exit(1);
}

function assert(condition, msg) {
  if (!condition) {
    fail(msg);
  }
}

function assertEq(actual, expected, msg) {
  if (actual !== expected) {
    fail(`${msg} (expected '${expected}', got '${actual}')`);
  }
}

function extractFunctionSource(source, functionName) {
  const sig = `function ${functionName}(`;
  const start = source.indexOf(sig);
  if (start < 0) {
    throw new Error(`missing function: ${functionName}`);
  }
  const bodyStart = source.indexOf('{', start);
  if (bodyStart < 0) {
    throw new Error(`malformed function: ${functionName}`);
  }
  let depth = 0;
  let i = bodyStart;
  for (; i < source.length; i += 1) {
    const ch = source[i];
    if (ch === '{') depth += 1;
    if (ch === '}') {
      depth -= 1;
      if (depth === 0) {
        return source.slice(start, i + 1);
      }
    }
  }
  throw new Error(`unterminated function: ${functionName}`);
}

const html = fs.readFileSync(appFile, 'utf8');
const functionNames = [
  'parseListOutput',
  'comparePriorityItems',
  'normalizeMarkdownLineText',
  'getVisiblePrioritiesMarkdown'
];

const snippets = functionNames.map((name) => extractFunctionSource(html, name)).join('\n\n');

const context = {
  Number,
  String,
  Array,
  treeEl: null
};
vm.createContext(context);
vm.runInContext(snippets, context);

const parseListOutput = context.parseListOutput;
const comparePriorityItems = context.comparePriorityItems;
const getVisiblePrioritiesMarkdown = context.getVisiblePrioritiesMarkdown;

assert(typeof parseListOutput === 'function', 'parseListOutput should load');
assert(typeof comparePriorityItems === 'function', 'comparePriorityItems should load');
assert(typeof getVisiblePrioritiesMarkdown === 'function', 'getVisiblePrioritiesMarkdown should load');

{
  const parsed = parseListOutput(
    [
      '/tmp/a\tTask A\tfile\t2\t3\t0\t0\t0',
      'invalid-line',
      '/tmp/p\tProj\tdir\t5\t1\t1\t2\t1'
    ].join('\n')
  );
  assertEq(parsed.length, 2, 'parseListOutput should keep only valid 8-field rows');
  assertEq(parsed[0].path, '/tmp/a', 'parseListOutput should parse path');
  assertEq(parsed[0].echelon, 2, 'parseListOutput should parse echelon');
  assertEq(parsed[1].hasSubpriorities, true, 'parseListOutput should parse hasSubpriorities');
}

{
  const items = [
    { name: 'z', path: '/z', echelon: 1, priority: 9 },
    { name: 'b', path: '/b', echelon: 3, priority: 8 },
    { name: 'a', path: '/a', echelon: 3, priority: 2 },
    { name: 'c', path: '/c', echelon: 3, priority: 2 }
  ];
  items.sort(comparePriorityItems);
  assertEq(items[0].name, 'a', 'comparePriorityItems should sort higher echelon first');
  assertEq(items[1].name, 'c', 'comparePriorityItems should tie-break by name for same echelon/priority');
  assertEq(items[3].name, 'z', 'comparePriorityItems should place lower echelon later');
}

function row({ depth, checked, name }) {
  return {
    getAttribute(key) {
      if (key === 'data-depth') return String(depth);
      return '';
    },
    querySelector(selector) {
      if (selector === '.chk') {
        return { checked: !!checked };
      }
      if (selector === '.name-edit') {
        return null;
      }
      if (selector === '.name') {
        return { textContent: name };
      }
      return null;
    }
  };
}

{
  const rows = [
    row({ depth: 0, checked: false, name: 'Top task' }),
    row({ depth: 1, checked: true, name: 'Child task' }),
    row({ depth: 2, checked: false, name: 'line one\nline two' })
  ];
  context.treeEl = function treeElMock() {
    return {
      querySelectorAll(selector) {
        assertEq(selector, '.row[data-path]', 'serializer should query visible row selector');
        return rows;
      }
    };
  };

  const md = getVisiblePrioritiesMarkdown();
  const expected = [
    '- [ ] Top task',
    '  - [x] Child task',
    '    - [ ] line one line two'
  ].join('\n');
  assertEq(md, expected, 'markdown serializer should honor depth, checked state, and newline normalization');
}

console.log('priorities frontend unit tests passed');
