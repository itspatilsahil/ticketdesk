package com.ticketdesk.api.controller;

import com.ticketdesk.api.config.S3Config;
import com.ticketdesk.api.dto.*;
import com.ticketdesk.api.model.Attachment;
import com.ticketdesk.api.model.Ticket;
import com.ticketdesk.api.repository.AttachmentRepository;
import com.ticketdesk.api.repository.TicketRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

/**
 * Milestone 5. The API never reads or writes a file's bytes - it only
 * issues short-lived presigned URLs. The browser uploads straight to S3;
 * a separate Lambda (see lambda-thumbnail/) turns that into a thumbnail
 * without this service being involved at all.
 */
@RestController
@RequestMapping("/api/tickets/{ticketId}/attachments")
public class AttachmentController {

    private static final String UPLOAD_PREFIX = "uploads/";
    private static final String THUMBNAIL_PREFIX = "thumbnails/";

    private final TicketRepository ticketRepository;
    private final AttachmentRepository attachmentRepository;
    private final S3Presigner s3Presigner;
    private final S3Config s3Config;

    public AttachmentController(TicketRepository ticketRepository,
                                 AttachmentRepository attachmentRepository,
                                 S3Presigner s3Presigner,
                                 S3Config s3Config) {
        this.ticketRepository = ticketRepository;
        this.attachmentRepository = attachmentRepository;
        this.s3Presigner = s3Presigner;
        this.s3Config = s3Config;
    }

    @PostMapping("/presign")
    public PresignResponse presign(@PathVariable Long ticketId, @RequestBody PresignRequest req) {
        requireTicket(ticketId);
        String key = UPLOAD_PREFIX + ticketId + "/" + UUID.randomUUID() + "-" + sanitize(req.filename);

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(s3Config.getAttachmentsBucket())
                .key(key)
                .contentType(req.contentType != null ? req.contentType : "application/octet-stream")
                .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(5))
                .putObjectRequest(putRequest)
                .build();

        PresignedPutObjectRequest presigned = s3Presigner.presignPutObject(presignRequest);
        return new PresignResponse(presigned.url().toString(), key);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AttachmentResponse confirm(@PathVariable Long ticketId, @RequestBody ConfirmAttachmentRequest req) {
        Ticket ticket = requireTicket(ticketId);
        Attachment attachment = new Attachment();
        attachment.setTicket(ticket);
        attachment.setOriginalFilename(req.filename);
        attachment.setS3Key(req.s3Key);
        attachment.setThumbnailKey(thumbnailKeyFor(req.s3Key));
        attachment = attachmentRepository.save(attachment);
        return toResponse(attachment);
    }

    @GetMapping
    public List<AttachmentResponse> list(@PathVariable Long ticketId) {
        requireTicket(ticketId);
        return attachmentRepository.findAll().stream()
                .filter(a -> a.getTicket().getId().equals(ticketId))
                .map(this::toResponse)
                .toList();
    }

    private AttachmentResponse toResponse(Attachment a) {
        return new AttachmentResponse(
                a.getId(),
                a.getOriginalFilename(),
                presignedGet(a.getS3Key()),
                presignedGet(a.getThumbnailKey())
        );
    }

    private String presignedGet(String key) {
        GetObjectPresignRequest req = GetObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(10))
                .getObjectRequest(GetObjectRequest.builder()
                        .bucket(s3Config.getAttachmentsBucket())
                        .key(key)
                        .build())
                .build();
        PresignedGetObjectRequest presigned = s3Presigner.presignGetObject(req);
        return presigned.url().toString();
    }

    // The Lambda mirrors this same substitution in reverse - see
    // lambda-thumbnail/handler.py. Keeping the mapping this simple (same
    // path, different top-level prefix) means neither side needs a
    // database to agree on where a thumbnail lives.
    private String thumbnailKeyFor(String uploadKey) {
        return THUMBNAIL_PREFIX + uploadKey.substring(UPLOAD_PREFIX.length());
    }

    private Ticket requireTicket(Long id) {
        return ticketRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Ticket not found"));
    }

    private String sanitize(String filename) {
        if (filename == null || filename.isBlank()) return "file";
        return filename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
