package com.ticketdesk.api.controller;

import com.ticketdesk.api.dto.*;
import com.ticketdesk.api.model.*;
import com.ticketdesk.api.repository.CommentRepository;
import com.ticketdesk.api.repository.TicketRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/tickets")
public class TicketController {

    private final TicketRepository ticketRepository;
    private final CommentRepository commentRepository;

    public TicketController(TicketRepository ticketRepository, CommentRepository commentRepository) {
        this.ticketRepository = ticketRepository;
        this.commentRepository = commentRepository;
    }

    @GetMapping("/")
    public String home() {
        return "redirect:/api/tickets";
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Ticket create(@RequestBody CreateTicketRequest req) {
        Ticket ticket = new Ticket();
        ticket.setTitle(req.title);
        ticket.setDescription(req.description);
        ticket.setCategory(req.category);
        ticket.setPriority(req.priority);
        ticket.setStatus(TicketStatus.OPEN);
        return ticketRepository.save(ticket);
    }

    @GetMapping
    public List<Ticket> list(
            @RequestParam(required = false) TicketStatus status,
            @RequestParam(required = false) Priority priority,
            @RequestParam(required = false) Category category) {

        return ticketRepository.findAll().stream()
                .filter(t -> status == null || t.getStatus() == status)
                .filter(t -> priority == null || t.getPriority() == priority)
                .filter(t -> category == null || t.getCategory() == category)
                .toList();
    }

    @GetMapping("/{id}")
    public Ticket get(@PathVariable Long id) {
        return ticketRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Ticket not found"));
    }

    @PatchMapping("/{id}/status")
    public Ticket updateStatus(@PathVariable Long id, @RequestBody UpdateStatusRequest req) {
        Ticket ticket = ticketRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Ticket not found"));
        ticket.setStatus(req.status);
        return ticketRepository.save(ticket);
    }

    @PostMapping("/{id}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public Comment addComment(@PathVariable Long id, @RequestBody AddCommentRequest req) {
        Ticket ticket = ticketRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Ticket not found"));
        Comment comment = new Comment();
        comment.setTicket(ticket);
        comment.setBody(req.body);
        return commentRepository.save(comment);
    }

    @GetMapping("/dashboard")
    public DashboardResponse dashboard() {
        Map<String, Long> byStatus = new LinkedHashMap<>();
        for (TicketStatus s : TicketStatus.values()) {
            byStatus.put(s.name(), ticketRepository.countByStatus(s));
        }
        Map<String, Long> byPriority = new LinkedHashMap<>();
        for (Priority p : Priority.values()) {
            byPriority.put(p.name(), ticketRepository.countByPriority(p));
        }
        return new DashboardResponse(byStatus, byPriority);
    }
}