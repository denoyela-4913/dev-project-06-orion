package com.openclassroom.devops.orion.microcrm;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Vérifie le comportement de l'API REST: un email invalide est refusé avec une erreur 400 (et non 500).
@SpringBootTest
@AutoConfigureMockMvc
class PersonEmailValidationTests {

    @Autowired
    private MockMvc mockMvc;

    private static String person(String email) {
        return "{\"firstName\":\"John\",\"lastName\":\"Doe\",\"email\":\"" + email + "\"}";
    }

    @Test
    void whenEmailHasInvalidFormat_thenApiAnswers400WithTheError() throws Exception {
        mockMvc.perform(post("/persons").contentType(MediaType.APPLICATION_JSON).content(person("not-an-email")))
                .andExpect(status().isBadRequest())
                .andExpect(content().string(containsString("must be a well-formed email address")));
    }

    @Test
    void whenEmailIsValid_thenApiAnswers201() throws Exception {
        mockMvc.perform(post("/persons").contentType(MediaType.APPLICATION_JSON).content(person("jdoe@example.net")))
                .andExpect(status().isCreated());
    }

    @Test
    void whenEmailIsEmpty_thenApiAnswers201() throws Exception {
        mockMvc.perform(post("/persons").contentType(MediaType.APPLICATION_JSON).content(person("")))
                .andExpect(status().isCreated());
    }
}
