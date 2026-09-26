package com.aasha.web.service;

import com.aasha.web.entity.Alert;
import com.aasha.web.repository.AlertRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/**
 * Polls the NDMA SACHET national alert feed and ingests active alerts.
 *
 * Feed: GET https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails
 * Returns: flat JSON array of active alerts (identifiers discovered dynamically —
 * no hard-coded alert IDs anywhere).
 */
@Service
public class SachetPollerService {

    private static final Logger log = LoggerFactory.getLogger(SachetPollerService.class);
    private static final String FEED_URL =
            "https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails";
    private static final DateTimeFormatter SACHET_TIME =
            DateTimeFormatter.ofPattern("EEE MMM dd HH:mm:ss yyyy", Locale.ENGLISH);

    private final AlertRepository repository;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    @Value("${aasha.sachet.enabled:true}")
    private boolean enabled;

    public SachetPollerService(AlertRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    @Scheduled(initialDelay = 15_000, fixedDelay = 120_000)
    public void poll() {
        if (!enabled) return;
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(FEED_URL))
                    .timeout(Duration.ofSeconds(20))
                    .header("Accept", "application/json")
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.warn("[SACHET] feed returned HTTP {}", response.statusCode());
                return;
            }
            int inserted = ingest(response.body());
            log.info("[SACHET] poll complete — {} new alert(s) ingested", inserted);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("[SACHET] poll interrupted");
        } catch (Exception e) {
            log.warn("[SACHET] poll failed: {}", e.getMessage());
        }
    }

    int ingest(String jsonBody) throws Exception {
        JsonNode alerts = objectMapper.readTree(jsonBody);
        if (!alerts.isArray()) {
            log.warn("[SACHET] unexpected payload shape (not an array)");
            return 0;
        }
        LocalDateTime now = LocalDateTime.now();
        int inserted = 0;
        for (JsonNode node : alerts) {
            try {
                if (saveIfNew(node, now)) inserted++;
            } catch (Exception e) {
                log.debug("[SACHET] skipped alert {}: {}", node.path("identifier").asText(), e.getMessage());
            }
        }
        return inserted;
    }

    private boolean saveIfNew(JsonNode node, LocalDateTime now) {
        String identifier = node.path("identifier").asText(null);
        if (identifier == null || identifier.isBlank()) return false;
        if (repository.existsByExternalId(identifier)) return false;

        LocalDateTime expiresAt = parseTime(node.path("effective_end_time").asText(null));
        if (expiresAt != null && !expiresAt.isAfter(now)) return false;

        String type = node.path("disaster_type").asText("Disaster Alert");
        String district = truncate(node.path("area_description").asText(null), 255);

        Alert alert = new Alert();
        alert.setExternalId(identifier);
        alert.setSource("NDMA");
        alert.setType(truncate(type, 255));
        alert.setTitle(truncate(type + " — " + district, 255));
        alert.setMessage(node.path("warning_message").asText(null));
        alert.setSeverity(mapSeverity(node));
        alert.setDistrict(district);
        alert.setState(truncate(cleanState(node.path("alert_source").asText(null)), 255));
        applyCentroid(alert, node.path("centroid").asText(null));
        alert.setExpiresAt(expiresAt);
        alert.setActive(true);
        repository.save(alert);
        return true;
    }

    /** red → critical, orange → severe, yellow → moderate, anything else → low. */
    private String mapSeverity(JsonNode node) {
        String color = node.path("severity_color").asText("").toLowerCase(Locale.ROOT);
        return switch (color) {
            case "red" -> "critical";
            case "orange" -> "severe";
            case "yellow" -> "moderate";
            default -> "low";
        };
    }

    /** SACHET centroid format is "longitude,latitude". */
    private void applyCentroid(Alert alert, String centroid) {
        if (centroid == null || centroid.isBlank()) return;
        String[] parts = centroid.split(",");
        if (parts.length != 2) return;
        try {
            double lon = Double.parseDouble(parts[0].trim());
            double lat = Double.parseDouble(parts[1].trim());
            if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                alert.setLongitude(lon);
                alert.setLatitude(lat);
            }
        } catch (NumberFormatException ignored) {
        }
    }

    private LocalDateTime parseTime(String raw) {
        if (raw == null || raw.isBlank()) return null;
        try {
            // "Sat Sep 26 08:30:00 IST 2026" → drop the zone token, keep IST wall-clock
            String cleaned = raw.replace(" IST ", " ").trim();
            return LocalDateTime.parse(cleaned, SACHET_TIME);
        } catch (Exception e) {
            return null;
        }
    }

    private String cleanState(String source) {
        if (source == null) return null;
        return source.replace(" SDMA", "").trim();
    }

    private String truncate(String value, int max) {
        if (value == null) return null;
        return value.length() <= max ? value : value.substring(0, max);
    }
}
