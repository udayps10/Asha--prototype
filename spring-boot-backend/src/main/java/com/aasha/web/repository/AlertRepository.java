package com.aasha.web.repository;

import com.aasha.web.entity.Alert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AlertRepository extends JpaRepository<Alert, Long> {
    List<Alert> findByActiveTrueOrderByCreatedAtDesc();
    List<Alert> findByDistrictAndActiveTrue(String district);
    List<Alert> findByStateAndActiveTrue(String state);
    boolean existsByExternalId(String externalId);
}
