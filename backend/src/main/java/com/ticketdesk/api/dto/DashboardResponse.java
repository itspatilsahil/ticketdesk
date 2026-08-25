package com.ticketdesk.api.dto;

import java.util.Map;

public class DashboardResponse {
    public Map<String, Long> byStatus;
    public Map<String, Long> byPriority;

    public DashboardResponse(Map<String, Long> byStatus, Map<String, Long> byPriority) {
        this.byStatus = byStatus;
        this.byPriority = byPriority;
    }
}
