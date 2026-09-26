package com.aasha.web.service;

import com.aasha.web.dto.AlertRequest;
import com.aasha.web.dto.AlertResponse;
import com.aasha.web.entity.Alert;
import com.aasha.web.repository.AlertRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Comparator;

@Service
public class AlertService {
    private final AlertRepository repository;

    public AlertService(AlertRepository repository) {
        this.repository = repository;
    }

    public List<AlertResponse> activeAlerts() {
        LocalDateTime now = LocalDateTime.now();
        return repository.findByActiveTrueOrderByCreatedAtDesc()
                .stream()
                .filter(a -> a.getExpiresAt() == null || a.getExpiresAt().isAfter(now))
                .map(AlertResponse::from).toList();
    }

    public List<AlertResponse> allAlerts() {
        return repository.findAll().stream()
            .sorted(Comparator.comparing(Alert::getCreatedAt,
                Comparator.nullsLast(Comparator.reverseOrder())))
                .map(AlertResponse::from).toList();
    }

    public AlertResponse create(AlertRequest request) {
        validateLocation(request);
        Alert alert = new Alert();
        alert.setTitle(request.getTitle().trim());
        alert.setMessage(request.getMessage());
        alert.setType(request.getType().trim());
        alert.setSeverity(request.getSeverity().trim());
        alert.setDistrict(request.getDistrict());
        alert.setState(request.getState());
        alert.setLatitude(request.getLatitude());
        alert.setLongitude(request.getLongitude());
        alert.setRadiusKm(request.getRadiusKm());
        alert.setActive(request.getActive() == null || request.getActive());
        return AlertResponse.from(repository.save(alert));
    }

    public AlertResponse setActive(Long id, boolean active) {
        Alert alert = repository.findById(id)
                .orElseThrow(() -> new AlertNotFoundException(id));
        alert.setActive(active);
        return AlertResponse.from(repository.save(alert));
    }

    private void validateLocation(AlertRequest request) {
        Double latitude = request.getLatitude();
        Double longitude = request.getLongitude();
        Double radius = request.getRadiusKm();
        if ((latitude == null) != (longitude == null)) {
            throw new IllegalArgumentException("latitude and longitude must be provided together");
        }
        if (latitude != null && (!Double.isFinite(latitude) || latitude < -90 || latitude > 90)) {
            throw new IllegalArgumentException("latitude must be between -90 and 90");
        }
        if (longitude != null && (!Double.isFinite(longitude) || longitude < -180 || longitude > 180)) {
            throw new IllegalArgumentException("longitude must be between -180 and 180");
        }
        if (radius != null && (latitude == null || longitude == null)) {
            throw new IllegalArgumentException("radiusKm requires latitude and longitude");
        }
        if (radius != null && (!Double.isFinite(radius) || radius <= 0)) {
            throw new IllegalArgumentException("radiusKm must be positive");
        }
    }

    public static class AlertNotFoundException extends RuntimeException {
        public AlertNotFoundException(Long id) { super("Alert not found: " + id); }
    }
}