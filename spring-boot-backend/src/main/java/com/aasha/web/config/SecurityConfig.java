package com.aasha.web.config;

import com.aasha.web.entity.AppUser;
import com.aasha.web.repository.UserRepository;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.web.client.RestTemplate;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;

import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public RestTemplate restTemplate() { return new RestTemplate(); }

    private final JwtAuthFilter jwtAuthFilter;
    private final UserRepository userRepo;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter, UserRepository userRepo) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.userRepo = userRepo;
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return email -> {
            var userOpt = userRepo.findByEmail(email);
            if (userOpt.isEmpty()) {
                throw new UsernameNotFoundException("User not found: " + email);
            }
            AppUser user = userOpt.get();
            return new User(
                user.getEmail(),
                user.getPasswordHash(),
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().toUpperCase()))
            );
        };
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                .ignoringRequestMatchers("/api/**")
            )
            .authorizeHttpRequests(auth -> auth
                // Public entry and information pages; response tools require login.
                .requestMatchers("/", "/about", "/health").permitAll()
                .requestMatchers("/search", "/search/**", "/critical", "/critical/**", "/camps", "/camps/**").authenticated()
                .requestMatchers("/css/**", "/js/**", "/images/**").permitAll()
                // Auth pages
                .requestMatchers("/login", "/register", "/logout").permitAll()
                // Public API
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/stats", "/api/camps", "/api/camps/list/**", "/api/normal-records/**", "/api/critical-records/**").authenticated()
                .requestMatchers(HttpMethod.GET, "/api/alerts/active").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/sos").authenticated()
                .requestMatchers("/api/normal-records/**", "/api/critical-records/**", "/api/camps/**").authenticated()
                // Image upload API
                .requestMatchers("/api/v1/images/**").permitAll()
                // Match API
                .requestMatchers("/api/v1/match", "/api/v1/match/**").authenticated()
                // Saved searches belong to signed-in citizens
                .requestMatchers("/api/saved-searches", "/api/saved-searches/**").authenticated()
                // Webhook for n8n
                .requestMatchers("/api/webhook/**").permitAll()
                // All other API requests need auth
                .requestMatchers("/api/**").authenticated()
                // Everything else public
                .anyRequest().permitAll()
            )
            .formLogin(form -> form
                .loginPage("/login")
                .loginProcessingUrl("/login")
                .usernameParameter("email")
                .defaultSuccessUrl("/search", false)
                .failureUrl("/login?error")
                .permitAll()
            )
            .exceptionHandling(errors -> errors.authenticationEntryPoint((request, response, exception) -> {
                if (request.getRequestURI().startsWith(request.getContextPath() + "/api/")) {
                    response.sendError(401);
                } else {
                    new org.springframework.security.web.authentication.LoginUrlAuthenticationEntryPoint("/login")
                        .commence(request, response, exception);
                }
            }))
            .logout(logout -> logout
                .logoutUrl("/logout")
                .logoutSuccessUrl("/login")
                .permitAll()
            )
            .userDetailsService(userDetailsService())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
