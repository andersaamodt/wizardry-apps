import React, { useState } from 'react';
const CommentInput = ({ postId }) => {
  const [commentText, setCommentText] = useState('');
  const handleSubmit = async (event) => {
    event.preventDefault();
    // Submit comment to the API
    await fetch(`/api/posts/${postId}/comments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ text: commentText })
    });
    setCommentText('');
  };
  return (
    <form onSubmit={handleSubmit}>
      <textarea
        value={commentText}
        onChange={(e) => setCommentText(e.target.value)}
        placeholder="Add a comment..."
      />
      <button type="submit">Submit</button>
    </form>
  );
};
export default CommentInput;