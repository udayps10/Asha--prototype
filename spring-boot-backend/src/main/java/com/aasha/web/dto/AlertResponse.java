package com.aasha.web.dto;

import com.aasha.web.entity.Alert;
import java.time.LocalDateTime;

public record AlertResponse(
        Long id,
        String title,
        String message,
        String type,
        String severity,
        String district,
        String state,
        Double latitude,
        Double longitude,
        Double radiusKm,
        boolean active,
        LocalDateTime createdAt,
        String source,
        LocalDateTime expiresAt
) {
    public static AlertResponse from(Alert alert) {
        return new AlertResponse(
                alert.getId(), alert.getTitle(), alert.getMessage(), alert.getType(),
                alert.getSeverity(), alert.getDistrict(), alert.getState(),
                alert.getLatitude(), alert.getLongitude(), alert.getRadiusKm(),
                alert.isActive(), alert.getCreatedAt(),
                alert.getSource(), alert.getExpiresAt()
        );
    }
}
