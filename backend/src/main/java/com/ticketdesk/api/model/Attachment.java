package com.ticketdesk.api.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import java.time.Instant;

/**
 * Wired up in Milestone 5 (serverless attachments). The table exists from the
 * start (see schema.sql) so the schema migration story stays a single file,
 * but the presign / upload endpoints are only added when M5 is built -
 * keeps the M0-M4 image free of the AWS SDK dependency.
 */
@Entity
@Table(name = "attachments")
public class Attachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ticket_id", nullable = false)
    @JsonIgnore
    private Ticket ticket;

    @Column(nullable = false)
    private String originalFilename;

    @Column(nullable = false)
    private String s3Key;

    private String thumbnailKey;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Ticket getTicket() { return ticket; }
    public void setTicket(Ticket ticket) { this.ticket = ticket; }

    public String getOriginalFilename() { return originalFilename; }
    public void setOriginalFilename(String originalFilename) { this.originalFilename = originalFilename; }

    public String getS3Key() { return s3Key; }
    public void setS3Key(String s3Key) { this.s3Key = s3Key; }

    public String getThumbnailKey() { return thumbnailKey; }
    public void setThumbnailKey(String thumbnailKey) { this.thumbnailKey = thumbnailKey; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
