package com.openclassroom.devops.orion.microcrm;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.rest.core.config.RepositoryRestConfiguration;
import org.springframework.data.rest.core.event.ValidatingRepositoryEventListener;
import org.springframework.data.rest.webmvc.config.RepositoryRestConfigurer;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import org.springframework.web.servlet.config.annotation.CorsRegistry;

@Configuration
public class SpringDataRestCustomization implements RepositoryRestConfigurer {

    private final LocalValidatorFactoryBean validator;

    public SpringDataRestCustomization(LocalValidatorFactoryBean validator) {
        this.validator = validator;
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
        cors.addMapping("/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "POST", "PATCH", "DELETE")
                .exposedHeaders("Access-Control-Allow-Origin")
                .allowCredentials(false).maxAge(3600);
        RepositoryRestConfigurer.super.configureRepositoryRestConfiguration(config, cors);
    }
}
