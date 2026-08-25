package com.ticketdesk.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Runs against the default profile's in-memory H2 database - no AWS, no
 * network, nothing external. This is exactly what the CI pipeline's
 * "runs unit tests" step executes on every push, before anything is
 * built into an image.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
class TicketControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthEndpointReportsUp() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void createListAndUpdateTicketLifecycle() throws Exception {
        String createBody = """
                {"title":"Printer jam","description":"Floor 3 printer","category":"HARDWARE","priority":"MEDIUM"}
                """;

        String response = mockMvc.perform(post("/api/tickets")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("OPEN"))
                .andReturn().getResponse().getContentAsString();

        long id = ((Number) com.jayway.jsonpath.JsonPath.read(response, "$.id")).longValue();

        mockMvc.perform(get("/api/tickets"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == " + id + ")]").exists());

        mockMvc.perform(patch("/api/tickets/{id}/status", id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"IN_PROGRESS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"));
    }

    @Test
    void dashboardReturnsCountsByStatusAndPriority() throws Exception {
        mockMvc.perform(get("/api/tickets/dashboard"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.byStatus").exists())
                .andExpect(jsonPath("$.byPriority").exists());
    }
}
