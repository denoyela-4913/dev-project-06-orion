package com.openclassroom.devops.orion.microcrm;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

// Comportement commun à Person et Organization (identifiant, horodatages) et gestion de leur relation.
// Ces tests protègent le regroupement du code dupliqué des deux entités (Sonar: 14 lignes dupliquées).
@DataJpaTest
class EntityTests {

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void whenPersonIsSaved_thenItGetsAnIdAndTimestamps() {
        Person person = entityManager.persistFlushFind(new Person("John", "Doe", "jdoe@example.net"));

        assertTrue(person.getId() > 0);
        assertNotNull(person.getCreatedAt());
        assertNotNull(person.getUpdatedAt());
    }

    @Test
    void whenOrganizationIsSaved_thenItGetsAnIdAndTimestamps() {
        Organization org = new Organization();
        org.setName("Orion");
        org = entityManager.persistFlushFind(org);

        assertTrue(org.getId() > 0);
        assertEquals("Orion", org.getName());
        assertNotNull(org.getCreatedAt());
        assertNotNull(org.getUpdatedAt());
    }

    @Test
    void whenPersonIsAddedThenRemoved_thenTheListFollowsEvenOnAnOrganizationWithoutList() {
        Organization org = new Organization();
        Person person = new Person("John", "Doe", "jdoe@example.net");

        org.removePerson(person); // liste encore absente: elle est créée vide
        assertEquals(List.of(), org.getPersons());
        assertEquals(List.of(person), org.addPerson(person));
        assertEquals(List.of(), org.removePerson(person));
    }

    @Test
    void whenPersonIsSaved_thenItsPhoneAndBioAreKept() {
        Person person = new Person("John", "Doe", "jdoe@example.net");
        person.setPhone("+1 988 112 8197");
        person.setBio("Developer");
        person = entityManager.persistFlushFind(person);

        assertEquals("+1 988 112 8197", person.getPhone());
        assertEquals("Developer", person.getBio());
        assertEquals("John", person.getFirstName());
        assertEquals("Doe", person.getLastName());
    }

    // @PreRemove: supprimer une personne la retire de ses organisations, sinon la contrainte de clé étrangère
    // de la table de jointure bloquerait la suppression.
    @Test
    void whenPersonIsDeleted_thenItDisappearsFromItsOrganizations() {
        Organization org = new Organization();
        org.setName("Orion");
        Person person = new Person("John", "Doe", "jdoe@example.net");
        org.addPerson(person);
        entityManager.persist(org);
        entityManager.flush();
        entityManager.clear(); // recharge depuis la base: la liste `organizations` de la personne est alors remplie

        Person loaded = entityManager.find(Person.class, person.getId());
        entityManager.remove(loaded);
        entityManager.flush();
        entityManager.clear();

        assertEquals(List.of(), entityManager.find(Organization.class, org.getId()).getPersons());
    }
}
