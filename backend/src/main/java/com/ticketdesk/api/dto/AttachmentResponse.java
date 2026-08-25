package com.ticketdesk.api.dto;

public class AttachmentResponse {
    public Long id;
    public String filename;
    public String downloadUrl;
    public String thumbnailUrl; // may 404 client-side until the Lambda has finished

    public AttachmentResponse(Long id, String filename, String downloadUrl, String thumbnailUrl) {
        this.id = id;
        this.filename = filename;
        this.downloadUrl = downloadUrl;
        this.thumbnailUrl = thumbnailUrl;
    }
}
