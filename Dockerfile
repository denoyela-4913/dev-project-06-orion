# Images de base épinglées par version ET par digest (sha256), jamais `latest`: un tag peut être
# déplacé par son auteur, un digest est immuable (builds reproductibles, sécurité de la chaîne
# d'approvisionnement). La version exacte est notée en commentaire au-dessus de chaque FROM.
# Les digests sont ceux des listes de manifestes multi-architectures, relevés le 18/11/2026.

# Node 24.22.3 (LTS, fin de support 30/04/2028), Debian 12. Remplace `node` (latest).
FROM node:24-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54 AS front-build

COPY ./front /src

WORKDIR /src

# `--ignore-scripts`: n'exécute pas les scripts d'installation des dépendances (vecteur d'attaque de
# la chaîne d'approvisionnement, Sonar S6505). `npm run build` lance `ng build` avec l'Angular CLI du
# package-lock.json au lieu de `npx @angular/cli` qui peut télécharger un paquet à la volée (S6505, S8543).
RUN npm ci --ignore-scripts \
    && npm run build -- --optimization

# Gradle 9.9.1 (celui du wrapper) avec JDK 21 (LTS, celui de build.gradle et de l'image d'exécution).
# `./gradlew` télécharge sa propre distribution: l'image apporte surtout le JDK.
FROM gradle:9.9.1-jdk21@sha256:607055593f1acc874a98aa7c1cb5adb414b3879bb0a5e1e7240180020fb97277 AS back-build

COPY ./back /src

WORKDIR /src

RUN ./gradlew build

# Alpine 3.24.4 (LTS, fin de support 01/06/2028).
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS front

COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /app/Caddyfile

RUN apk add caddy

WORKDIR /app

EXPOSE 80
EXPOSE 443

CMD ["/usr/sbin/caddy", "run"]

# Alpine 3.24.4, cf. ci-dessus.
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS back

COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar

RUN apk add openjdk21-jre-headless

WORKDIR /app

EXPOSE 8080

CMD ["java", "-jar", "/app/back/microcrm-0.0.1-SNAPSHOT.jar"]

# Alpine 3.24.4, cf. ci-dessus.
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS standalone

COPY --from=front / /
COPY --from=back / /
COPY misc/docker/supervisor.ini /app/supervisor.ini

RUN apk add supervisor

WORKDIR /app

CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]
