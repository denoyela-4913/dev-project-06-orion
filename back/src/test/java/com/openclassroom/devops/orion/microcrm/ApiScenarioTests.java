package com.openclassroom.devops.orion.microcrm;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.ArrayList;
import java.util.List;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.annotation.DirtiesContext;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

// Tests fonctionnels: l'application complète écoute sur un port réel, et les scénarios suivent les appels du
// front (person.service.ts et organization.service.ts), de la création à la suppression.
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
// La base en mémoire est remise à neuf après la classe: ces scénarios écrivent dans les données partagées.
@DirtiesContext
class ApiScenarioTests {

    private static final String JSON = "application/json";
    private static final String URI_LIST = "text/uri-list";

    private final HttpClient client = HttpClient.newHttpClient();

    @LocalServerPort
    private int port;

    @Test
    void whenAPersonIsCreatedModifiedAndDeleted_thenEachStepIsVisibleThroughTheApi() throws Exception {
        long id = create("/persons", """
                {"firstName":"Ada","lastName":"Lovelace","email":"ada@example.net","phone":"1","bio":"math"}""");
        assertEquals("Ada", read("/persons/" + id, "$.firstName"));

        // Le front modifie avec PUT en envoyant tous les champs.
        assertStatus(200, send("PUT", "/persons/" + id, JSON, """
                {"firstName":"Ada","lastName":"King","email":"ada@example.net","phone":"2","bio":"code"}"""));
        assertEquals("King", read("/persons/" + id, "$.lastName"));
        assertEquals("code", read("/persons/" + id, "$.bio"));

        // Avec `Accept`, la suppression d'une ressource répond 200 et rend la ressource supprimée.
        assertStatus(200, send("DELETE", "/persons/" + id, null, null));
        assertStatus(404, send("GET", "/persons/" + id, null, null));
    }

    @Test
    void whenPersonsAreLinkedThenUnlinked_thenOnlyTheTargetedLinkChanges() throws Exception {
        long organization = create("/organizations", "{\"name\":\"Scenario Corp\"}");
        long first = create("/persons", "{\"firstName\":\"First\",\"lastName\":\"Member\"}");
        long second = create("/persons", "{\"firstName\":\"Second\",\"lastName\":\"Member\"}");
        String members = "/organizations/" + organization + "/persons";

        // POST ajoute un lien; un second ajout ne remplace pas le premier.
        assertStatus(204, send("POST", members, URI_LIST, url("/persons/" + first)));
        assertStatus(204, send("POST", members, URI_LIST, url("/persons/" + second)));
        assertEquals(List.of("First", "Second"), names(members));
        assertEquals(List.of("Scenario Corp"),
                readList("/persons/" + second + "/organizations", "$._embedded.organizations[*].name"));

        assertStatus(204, send("DELETE", members + "/" + first, null, null));
        assertEquals(List.of("Second"), names(members));
        // La personne retirée existe toujours.
        assertStatus(200, send("GET", "/persons/" + first, null, null));
    }

    // Derrière le proxy du front, l'adresse envoyée est relative (/api/persons/{id}).
    @Test
    void whenTheLinkUsesARelativeAddressBehindTheProxy_thenTheLinkIsCreated() throws Exception {
        long organization = create("/organizations", "{\"name\":\"Relative Corp\"}");
        long person = create("/persons", "{\"firstName\":\"Relative\",\"lastName\":\"Link\"}");
        String members = "/organizations/" + organization + "/persons";

        assertStatus(204, send("POST", members, URI_LIST, "/api/persons/" + person));

        assertEquals(List.of("Relative"), names(members));
    }

    @Test
    void whenAMemberIsDeleted_thenTheOrganizationRemainsWithoutIt() throws Exception {
        long organization = create("/organizations", "{\"name\":\"Remaining Corp\"}");
        long person = create("/persons", "{\"firstName\":\"Gone\",\"lastName\":\"Soon\"}");
        String members = "/organizations/" + organization + "/persons";
        assertStatus(204, send("POST", members, URI_LIST, url("/persons/" + person)));

        assertStatus(200, send("DELETE", "/persons/" + person, null, null));

        assertEquals(List.of(), names(members));
        assertEquals("Remaining Corp", read("/organizations/" + organization, "$.name"));
        assertStatus(200, send("DELETE", "/organizations/" + organization, null, null));
        assertStatus(404, send("GET", "/organizations/" + organization, null, null));
    }

    @Test
    void whenAnInvalidEmailIsSentOnUpdate_thenItIsRefusedAndNothingChanges() throws Exception {
        long id = create("/persons", "{\"firstName\":\"Keep\",\"lastName\":\"Me\",\"email\":\"keep@example.net\"}");

        assertStatus(400, send("PUT", "/persons/" + id, JSON,
                "{\"firstName\":\"Keep\",\"lastName\":\"Me\",\"email\":\"not-an-email\"}"));

        assertEquals("keep@example.net", read("/persons/" + id, "$.email"));
    }

    @Test
    void whenTheListIsRead_thenItHasTheShapeTheFrontExpects() throws Exception {
        List<String> organizations = readList("/organizations", "$._embedded.organizations[*].name");

        assertTrue(organizations.contains("Orion Incorporated"), organizations.toString());
    }

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    private HttpResponse<String> send(String method, String path, String type, String body)
            throws IOException, InterruptedException {
        // `Accept` comme le navigateur: sans lui, Spring Data REST répond à POST et PUT sans corps.
        HttpRequest.Builder request = HttpRequest.newBuilder(URI.create(url(path)))
                .header("Accept", "application/json, text/plain, */*")
                .method(method, body == null
                        ? HttpRequest.BodyPublishers.noBody()
                        : HttpRequest.BodyPublishers.ofString(body));
        if (type != null) {
            request.header("Content-Type", type);
        }
        return client.send(request.build(), HttpResponse.BodyHandlers.ofString());
    }

    private static void assertStatus(int expected, HttpResponse<String> response) {
        assertEquals(expected, response.statusCode(), response.request() + " " + response.body());
    }

    private long create(String path, String body) throws Exception {
        HttpResponse<String> response = send("POST", path, JSON, body);
        assertStatus(201, response);
        return ((Number) JsonPath.read(response.body(), "$.id")).longValue();
    }

    private <T> T read(String path, String expression) throws Exception {
        HttpResponse<String> response = send("GET", path, null, null);
        assertStatus(200, response);
        return JsonPath.read(response.body(), expression);
    }

    private List<String> readList(String path, String expression) throws Exception {
        return read(path, expression);
    }

    private List<String> names(String path) throws Exception {
        List<String> names = new ArrayList<>(readList(path, "$._embedded.persons[*].firstName"));
        names.sort(null);
        return names;
    }
}
