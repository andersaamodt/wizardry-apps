const express = require('express');
const router = express.Router();
function validateCommentInput(req, res, next) {
  const { content } = req.body;
  if (!content) {
    return res.status(400).json({ error: 'Comment content is required' });
  }
  if (content.length > 1000) {
    return res.status(40