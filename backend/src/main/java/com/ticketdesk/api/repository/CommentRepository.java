package com.ticketdesk.api.repository;

import com.ticketdesk.api.model.Comment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CommentRepository extends JpaRepository<Comment, Long> {
}
