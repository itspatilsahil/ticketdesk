package com.ticketdesk.api.repository;

import com.ticketdesk.api.model.Attachment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AttachmentRepository extends JpaRepository<Attachment, Long> {
}
