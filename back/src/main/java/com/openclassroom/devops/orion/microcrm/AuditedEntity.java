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

  public Date getCreatedAt() {
    return createdAt;
  }

  public Date getUpdatedAt() {
    return updatedAt;
  }
}
