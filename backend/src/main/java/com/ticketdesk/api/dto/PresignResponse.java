package com.ticketdesk.api.dto;

public class PresignResponse {
    public String uploadUrl;
    public String s3Key;

    public PresignResponse(String uploadUrl, String s3Key) {
        this.uploadUrl = uploadUrl;
        this.s3Key = s3Key;
    }
}
