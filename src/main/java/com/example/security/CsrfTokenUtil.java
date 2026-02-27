package com.example.security;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.util.UUID;

public class CsrfTokenUtil {
    public static final String CSRF_TOKEN_ATTRIBUTE = "CSRF_TOKEN";

    public static void setCsrfToken(HttpServletRequest request, HttpServletResponse response) {
        String csrfToken = UUID.randomUUID().toString();
        request.getSession().setAttribute(CSRF_TOKEN_ATTRIBUTE, csrfToken);
        response.setHeader("X-CSRF-Token", csrfToken);
    }

    public static boolean validateCsrfToken(HttpServletRequest request, String token) {
        return token != null && token.equals(request.getSession().getAttribute(CSRF_TOKEN_ATTRIBUTE));
    }

