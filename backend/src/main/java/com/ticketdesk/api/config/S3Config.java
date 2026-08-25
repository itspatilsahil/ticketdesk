package com.ticketdesk.api.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

@Configuration
public class S3Config {

    // Not set at all until Milestone 5's ecs.tf revision adds ATTACHMENTS_BUCKET
    // as a plain (non-secret) environment variable - no default here on
    // purpose, so a missing config surfaces immediately rather than
    // silently writing to the wrong place.
    @Value("${app.attachments.bucket:}")
    private String attachmentsBucket;

    @Bean
    public S3Presigner s3Presigner() {
        // Credentials and region are picked up automatically from the
        // ECS task role and the container's AWS_REGION env var - nothing
        // hardcoded, nothing to configure by hand.
        return S3Presigner.create();
    }

    public String getAttachmentsBucket() {
        return attachmentsBucket;
    }
}
