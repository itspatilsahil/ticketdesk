package com.ticketdesk.api.dto;

import com.ticketdesk.api.model.Category;
import com.ticketdesk.api.model.Priority;

public class CreateTicketRequest {
    public String title;
    public String description;
    public Category category;
    public Priority priority;
}
