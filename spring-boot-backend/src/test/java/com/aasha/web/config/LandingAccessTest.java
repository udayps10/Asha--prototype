package com.aasha.web.config;

import com.aasha.web.repository.UserRepository;
import com.aasha.web.service.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(LandingAccessTest.Probe.class)
@Import({SecurityConfig.class, JwtAuthFilter.class})
class LandingAccessTest {
    @Autowired MockMvc mvc;
    @MockBean UserRepository users;
    @MockBean JwtService jwt;

    @RestController
    static class Probe {
        @GetMapping({"/", "/about", "/login", "/register", "/search", "/critical", "/camps", "/api/camps", "/api/normal-records/list", "/api/critical-records/list"})
        String page() { return "ok"; }
        @PostMapping({"/api/v1/match", "/api/v1/match/more", "/api/saved-searches"})
        String api() { return "ok"; }
    }

    @Test void entryPagesRemainPublic() throws Exception {
        for (String route : new String[]{"/", "/about", "/login", "/register"}) mvc.perform(get(route)).andExpect(status().isOk());
    }
    @Test void responsePagesRedirectAnonymousVisitorsToLogin() throws Exception {
        for (String route : new String[]{"/search", "/critical", "/camps"}) mvc.perform(get(route)).andExpect(status().is3xxRedirection()).andExpect(redirectedUrlPattern("**/login"));
    }
    @Test void directSearchAndRecordsApisRequireLogin() throws Exception {
        for (String route : new String[]{"/api/v1/match", "/api/v1/match/more", "/api/saved-searches"}) mvc.perform(post(route)).andExpect(status().isUnauthorized());
        for (String route : new String[]{"/api/camps", "/api/normal-records/list", "/api/critical-records/list"}) mvc.perform(get(route)).andExpect(status().isUnauthorized());
    }
    @Test @WithMockUser void authenticatedUsersCanReachResponseTools() throws Exception {
        for (String route : new String[]{"/search", "/critical", "/camps", "/api/camps", "/api/normal-records/list"}) mvc.perform(get(route)).andExpect(status().isOk());
        mvc.perform(post("/api/v1/match")).andExpect(status().isOk());
    }
}
