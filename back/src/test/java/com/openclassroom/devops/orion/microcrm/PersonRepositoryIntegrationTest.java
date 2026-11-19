package com.openclassroom.devops.orion.microcrm;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.boot.test.context.SpringBootTest;

import jakarta.validation.ConstraintViolationException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@DataJpaTest
public class PersonRepositoryIntegrationTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private PersonRepository personRepository;

    @Test
    public void whenFindByEmail_thenReturnPerson() {
        // given
        Person jdoe = new Person();
        jdoe.setEmail("jdoe@example.net");
        entityManager.persist(jdoe);
        entityManager.flush();

        // when
        Optional<Person> found = personRepository.findByEmail("jdoe@example.net");

        assertEquals(jdoe.getEmail(), found.get().getEmail());
    }

    @Test
    public void whenEmailHasInvalidFormat_thenSaveIsRejected() {
        Person person = new Person("John", "Doe", "not-an-email");

        assertThrows(ConstraintViolationException.class, () -> {
            entityManager.persist(person);
            entityManager.flush();
        });
    }

    @Test
    public void whenEmailIsEmpty_thenSaveIsAccepted() {
        Person person = new Person("John", "Doe", "");

        entityManager.persist(person);
        entityManager.flush();

        assertEquals("", person.getEmail());
    }
}
