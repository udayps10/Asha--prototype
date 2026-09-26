package com.aasha.web.controller;

import com.aasha.web.entity.AppUser;
import com.aasha.web.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Controller
public class WebAuthController {

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;

    public WebAuthController(UserRepository userRepo, PasswordEncoder passwordEncoder) {
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
    }

    @GetMapping("/login")
    public String loginPage(@RequestParam(value = "error", required = false) String error,
                            @RequestParam(value = "registered", required = false) String registered,
                            @RequestParam(value = "role", required = false) String role,
                            Model model) {
        if (error != null) {
            model.addAttribute("error", "Invalid email or password");
        }
        if (registered != null) {
            model.addAttribute("success", "Account created successfully. Please sign in.");
        }
        model.addAttribute("officialLogin", "official".equals(role));
        return "login";
    }

    @GetMapping("/register")
    public String registerPage(@RequestParam(value = "error", required = false) String error, Model model) {
        if (error != null) {
            model.addAttribute("error", "Email already registered. Please sign in.");
        }
        return "register";
    }

    @PostMapping("/register")
    public String register(@RequestParam String name,
                           @RequestParam String email,
                           @RequestParam String password,
                           @RequestParam String phone,
                           @RequestParam(defaultValue = "user") String role,
                           Model model) {
        if (userRepo.existsByEmail(email)) {
            model.addAttribute("error", "Email already registered. Please sign in.");
            return "register";
        }

        AppUser user = new AppUser();
        user.setUid(UUID.randomUUID().toString());
        user.setName(name);
        user.setEmail(email);
        user.setPhone(phone);
        user.setPasswordHash(passwordEncoder.encode(password));
        user.setRole(role);
        user.setApproved(true);
        userRepo.save(user);

        return "redirect:/login?registered";
    }

    @GetMapping("/logout")
    public String logout() {
        return "redirect:/login";
    }
}
