package com.aasha.web;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AashaWebApplication {
    public static void main(String[] args) {
        SpringApplication.run(AashaWebApplication.class, args);
    }
}
