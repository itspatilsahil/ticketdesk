package com.ticketdesk.api.repository;

import com.ticketdesk.api.model.Category;
import com.ticketdesk.api.model.Priority;
import com.ticketdesk.api.model.Ticket;
import com.ticketdesk.api.model.TicketStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface TicketRepository extends JpaRepository<Ticket, Long>, JpaSpecificationExecutor<Ticket> {

    long countByStatus(TicketStatus status);

    long countByPriority(Priority priority);
}
