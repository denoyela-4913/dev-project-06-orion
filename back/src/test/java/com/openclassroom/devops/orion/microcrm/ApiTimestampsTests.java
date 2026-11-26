package com.openclassroom.devops.orion.microcrm;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Contrat JSON consommé par le front (Person.createdAt/updatedAt, Organization.createdAt/updatedAt):
// il ne doit pas changer quand le code commun des entités est déplacé dans une classe parente.
@SpringBootTest
@AutoConfigureMockMvc
class ApiTimestampsTests {

    @Autowired
    private MockMvc mockMvc;

    // L'API répond 201 sans corps: on relit la ressource créée par l'URL de l'en-tête Location.
    private String create(String path, String json) throws Exception {
        return mockMvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(json))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getHeader("Location");
    }

    @Test
    void whenPersonIsCreated_thenTheResponseHasTheTimestampsAndTheId() throws Exception {
        String location = create("/persons",
                "{\"firstName\":\"John\",\"lastName\":\"Doe\",\"email\":\"jdoe@example.net\"}");

        mockMvc.perform(get(location))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.createdAt").isNotEmpty())
                .andExpect(jsonPath("$.updatedAt").isNotEmpty())
                .andExpect(jsonPath("$.id").isNumber());
    }

    @Test
    void whenOrganizationIsCreated_thenTheResponseHasTheTimestampsAndTheId() throws Exception {
        String location = create("/organizations", "{\"name\":\"Orion\"}");

        mockMvc.perform(get(location))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.createdAt").isNotEmpty())
                .andExpect(jsonPath("$.updatedAt").isNotEmpty())
                .andExpect(jsonPath("$.id").isNumber());
    }
}
