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

# Gradle 8.7 (celui du wrapper) avec JDK 17.0.11. Remplace `gradle:jdk17` (dernier Gradle).
# `./gradlew` télécharge sa propre distribution: l'image apporte surtout le JDK.
FROM gradle:8.7-jdk17@sha256:4ad3845d9ee2843537747bd5f067cc6c7a18e737d0079a880a5a074feda392a4 AS back-build

COPY ./back /src

WORKDIR /src

RUN ./gradlew build

# Alpine 3.19.9 (fin de support dépassée: mise à jour prévue, cf. docs/BACKLOG.md).
FROM alpine:3.19@sha256:6baf43584bcb78f2e5847d1de515f23499913ac9f12bdf834811a3145eb11ca1 AS front

COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /app/Caddyfile

RUN apk add caddy

WORKDIR /app

EXPOSE 80
EXPOSE 443

CMD ["/usr/sbin/caddy", "run"]

# Alpine 3.19.9, cf. ci-dessus.
FROM alpine:3.19@sha256:6baf43584bcb78f2e5847d1de515f23499913ac9f12bdf834811a3145eb11ca1 AS back

COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar

RUN apk add openjdk21-jre-headless

WORKDIR /app

EXPOSE 4200

CMD ["java", "-jar", "/app/back/microcrm-0.0.1-SNAPSHOT.jar"]

# Alpine 3.19.9, cf. ci-dessus.
FROM alpine:3.19@sha256:6baf43584bcb78f2e5847d1de515f23499913ac9f12bdf834811a3145eb11ca1 AS standalone

COPY --from=front / /
COPY --from=back / /
COPY misc/docker/supervisor.ini /app/supervisor.ini

RUN apk add supervisor

WORKDIR /app

CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]
