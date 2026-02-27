// slow-path-profile.js
const { performance } = require('perf_hooks');
const fs = require('fs');
function simulateSlowPath() {
    let sum = 0;
    for (let i = 0; i < 10000000; i++) {
        sum += Math.sqrt(i