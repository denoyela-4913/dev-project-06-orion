package com.openclassroom.devops.orion.microcrm;

import java.util.List;

import jakarta.persistence.Entity;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.PreRemove;
import jakarta.validation.constraints.Email;

@Entity
public class Person extends AuditedEntity {
  public Person() {
  }

  public Person(String firstName, String lastName, String email) {
    this.setFirstName(firstName);
    this.setLastName(lastName);
    this.setEmail(email);
  }

  private String firstName;

  public String getFirstName() {
    return firstName;
  }

  public void setFirstName(String firstName) {
    this.firstName = firstName;
  }

  private String lastName;

  public String getLastName() {
    return lastName;
  }

  public void setLastName(String lastName) {
    this.lastName = lastName;
  }

  // Format vérifié côté serveur: le contrôle du front ne protège pas l'API. Une valeur vide reste acceptée.
  @Email
  private String email;

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  private String phone;

  public String getPhone() {
    return phone;
  }

  public void setPhone(String phone) {
    this.phone = phone;
  }

  private String bio;

  public String getBio() {
    return bio;
  }

  public void setBio(String bio) {
    this.bio = bio;
  }

  @ManyToMany(mappedBy = "persons")
  private List<Organization> organizations;

  @PreRemove
  private void remoteFromOrganization() {
    for (Organization org : organizations) {
      org.removePerson(this);
    }
  }

}
