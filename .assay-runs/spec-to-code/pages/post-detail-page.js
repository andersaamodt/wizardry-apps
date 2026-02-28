import React, { useState, useEffect } from 'react';
const PostDetailPage = ({ postId }) => {
  const [comments, setComments] = useState([]);
  useEffect(() => {
    // Fetch comments from the API
    fetch(`/api/posts/${postId}/comments`)
      .then(response => response.json())
      .then(data => setComments(data));
  }, [postId]);
  return (
    <div>
      <h1>Post Detail</h1>
      <div data-test="post-comment" className="comment">
        {comments.map((comment, index) => (
          <div key={index}>{comment.text}</div>
        ))}
      </div>
      <CommentInput postId={postId} />
    </div>
  );
};
export default PostDetailPage;