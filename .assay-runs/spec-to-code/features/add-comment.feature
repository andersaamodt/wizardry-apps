Feature: Add Comment to Post
  Scenario Outline: User adds a comment to a post
    Given the user is on the post detail page for "<postId>"
    When the user enters "<commentText>" into the comment input
    And the user submits the comment form
    Then the comment should be visible on the post detail page
    And the comment should be saved in the database
    Examples:
      | postId  | commentText |
      | "123"   | "Great post!"|
      | "456"   | "Thanks for sharing!"|