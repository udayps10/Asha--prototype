package com.aasha.web.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Service
public class N8nService {

    private final RestClient restClient = RestClient.create();

    @Value("${n8n.webhook.url}")
    private String webhookUrl;

    public void sendToN8n(Map<String, Object> data) {

        restClient.post()
                .uri(webhookUrl)
                .body(data)
                .retrieve()
                .toBodilessEntity();
    }
}