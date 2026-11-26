package com.openclassroom.devops.orion.microcrm;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.rest.core.config.RepositoryRestConfiguration;
import org.springframework.data.rest.core.event.ValidatingRepositoryEventListener;
import org.springframework.data.rest.webmvc.config.RepositoryRestConfigurer;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import org.springframework.web.servlet.config.annotation.CorsRegistry;

@Configuration
public class SpringDataRestCustomization implements RepositoryRestConfigurer {

    private final LocalValidatorFactoryBean validator;

    private final String[] allowedOrigins;

    public SpringDataRestCustomization(LocalValidatorFactoryBean validator,
            @Value("${app.cors.allowed-origins}") String[] allowedOrigins) {
        this.validator = validator;
        // Copie: le tableau reçu reste modifiable par l'appelant (SpotBugs EI_EXPOSE_REP2).
        this.allowedOrigins = allowedOrigins.clone();
    }

    // Applique les contraintes Bean Validation (@Email, ...) avant la création et l'enregistrement: une valeur
    // invalide donne une réponse 400 avec le détail des erreurs, au lieu d'une erreur 500 au commit.
    @Override
    public void configureValidatingRepositoryEventListener(ValidatingRepositoryEventListener listener) {
        listener.addValidator("beforeCreate", validator);
        listener.addValidator("beforeSave", validator);
    }

    @Override
    public void configureRepositoryRestConfiguration(RepositoryRestConfiguration config, CorsRegistry cors) {
        config.exposeIdsFor(Person.class, Organization.class);
        // Seule configuration CORS de l'API (pas de @CrossOrigin sur les dépôts, qui autoriserait toutes les
        // origines, Sonar S5122). PUT est requis: le front s'en sert pour modifier personnes et organisations.
        cors.addMapping("/**")
                .allowedOrigins(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE")
                .exposedHeaders("Access-Control-Allow-Origin")
                .allowCredentials(false).maxAge(3600);
        RepositoryRestConfigurer.super.configureRepositoryRestConfiguration(config, cors);
    }
}
