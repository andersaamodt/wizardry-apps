const { Given, When, Then } = require('@cucumber/cucumber');
const { expect } = require('chai');
Given('the user is on the post detail page for "{string}"', async function(postId) {
  await browser.url(`http://localhost:3000/posts/${postId}`);
});
When('the user enters "{string}" into the comment input', async function(commentText) {
  await $('#comment-input').setValue(commentText);
});
When('the user submits the comment form', async function() {
  await $('#submit-comment-button').click();
});
Then('the comment should be visible on the post detail page', async function() {
  const comments = await $$('[data-test="post-comment"]');
  expect(comments.length).to.be.gt(0);
  expect(await comments[comments.length - 1].getText()).to.include(commentText);
});
Then('the comment should be saved in the database', async function() {
  // Assuming we have a way to query the database
  const result = await db.query("SELECT * FROM comments WHERE post_id = '123' AND text = 'Great post!'");
  expect(result.length).to.be.gt(0);
});