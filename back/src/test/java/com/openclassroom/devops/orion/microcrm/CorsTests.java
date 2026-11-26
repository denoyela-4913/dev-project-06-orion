package com.openclassroom.devops.orion.microcrm;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// CORS: seules les origines du front sont autorisées à appeler l'API depuis un navigateur.
@SpringBootTest
@AutoConfigureMockMvc
class CorsTests {

    private static final String UNKNOWN_ORIGIN = "https://unknown.example";

    @Autowired
    private MockMvc mockMvc;

    @ParameterizedTest
    @ValueSource(strings = { "/persons", "/organizations", "/persons/search/findByEmail" })
    void whenOriginIsUnknown_thenRequestIsRejected(String path) throws Exception {
        mockMvc.perform(get(path).header(HttpHeaders.ORIGIN, UNKNOWN_ORIGIN))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    @ParameterizedTest
    @CsvSource({ "/persons, POST", "/persons/1, PUT", "/organizations/1, DELETE" })
    void whenOriginIsUnknown_thenPreflightIsRejected(String path, String method) throws Exception {
        mockMvc.perform(options(path).header(HttpHeaders.ORIGIN, UNKNOWN_ORIGIN)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, method))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    // Tous les appels du front (person.service.ts, organization.service.ts), depuis ses deux origines:
    // serveur de développement Angular et images Docker (Caddy en HTTPS).
    @ParameterizedTest
    @CsvSource({
            "http://localhost:4200, /persons, GET",
            "http://localhost:4200, /persons, POST",
            "http://localhost:4200, /persons/1, PUT",
            "http://localhost:4200, /persons/1, DELETE",
            "http://localhost:4200, /organizations/1, PUT",
            "http://localhost:4200, /organizations/1/persons, POST",
            "http://localhost:4200, /organizations/1/persons/1, DELETE",
            "https://localhost, /persons/1, PUT",
            "https://localhost, /organizations/1/persons/1, DELETE" })
    void whenOriginIsTheFront_thenPreflightIsAccepted(String origin, String path, String method) throws Exception {
        mockMvc.perform(options(path).header(HttpHeaders.ORIGIN, origin)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, method)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "content-type"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, origin));
    }

    // CORS ne concerne que les navigateurs: un appel sans en-tête Origin (curl, autre serveur) reste servi.
    @Test
    void whenRequestHasNoOrigin_thenItIsServed() throws Exception {
        mockMvc.perform(get("/persons")).andExpect(status().isOk());
    }
}
