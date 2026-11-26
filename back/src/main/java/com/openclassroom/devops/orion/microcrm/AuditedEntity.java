package com.openclassroom.devops.orion.microcrm;

import java.util.Date;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.Temporal;
import jakarta.persistence.TemporalType;

// Identifiant et horodatages communs à Person et Organization. Ils étaient dupliqués dans les deux classes
// (Sonar: 14 lignes dupliquées dans chacune). @MappedSuperclass: les colonnes restent dans la table de chaque
// entité, le schéma et le JSON de l'API ne changent pas (cf. ApiTimestampsTests).
@MappedSuperclass
public abstract class AuditedEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  private long id;

  @Temporal(TemporalType.TIMESTAMP)
  @CreationTimestamp
  private Date createdAt;

  @Temporal(TemporalType.TIMESTAMP)
  @UpdateTimestamp
  private Date updatedAt;

  public long getId() {
    return id;
  }

  // Copies: `Date` est modifiable, l'appelant ne doit pas pouvoir changer l'horodatage de l'entité
  // (SpotBugs EI_EXPOSE_REP). Hibernate accède aux champs directement (@Id sur le champ), pas à ces méthodes.
  public Date getCreatedAt() {
    return copyOf(createdAt);
  }

  public Date getUpdatedAt() {
    return copyOf(updatedAt);
  }

  private static Date copyOf(Date date) {
    return date == null ? null : new Date(date.getTime());
  }
}
