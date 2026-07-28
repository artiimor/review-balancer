# Review Balancer — MVP

Reparte revisiones de código combinando **carga actual** y **expertise por
tecnología**, derivada automáticamente de los PRs mergeados de cada persona.

Ya es una app Rails completa (API-only) con Postgres + Redis/Sidekiq, y está
dockerizada: `docker compose up` deja todo funcionando (web, worker de
Sidekiq, base de datos y Redis).

## 1. Arrancar con Docker (recomendado)

Requisitos: Docker + Docker Compose.

```bash
cp .env.example .env
```

Rellena `.env` con valores reales:
- `SECRET_KEY_BASE`: genera uno con `docker compose run --rm web bin/rails secret`.
- `AR_ENCRYPTION_PRIMARY_KEY` / `AR_ENCRYPTION_DETERMINISTIC_KEY` /
  `AR_ENCRYPTION_KEY_DERIVATION_SALT`: genera las tres con
  `docker compose run --rm web bin/rails db:encryption:init` (imprime un
  bloque `config.active_record.encryption.*`; copia cada valor a su variable).
- `GITHUB_ACCESS_TOKEN` / `SLACK_BOT_TOKEN`: credenciales reales de tus
  integraciones (ver sección 3).

> Nota: este repo incluye un `.env` con valores de ejemplo autogenerados
> (funcionales para levantar el stack en local) — cámbialos antes de usar
> esto en un entorno real.

Levanta todo:

```bash
docker compose up -d
```

Esto construye la imagen, arranca Postgres y Redis, corre las migraciones
automáticamente (`bin/docker-entrypoint` hace `db:prepare` al arrancar `web` o
`sidekiq`) y deja:
- la API en `http://localhost:3050` (mapeado a `3000` dentro del contenedor;
  cambia el puerto host en `docker-compose.yml` si `3000` ya está libre en tu
  máquina),
- Sidekiq procesando el `default` queue en background.

Comprueba que arrancó:

```bash
curl http://localhost:3050/up
```

## 2. Correr los tests dentro de Docker

```bash
docker compose run --rm -e RAILS_ENV=test web bash -c "./bin/rails db:prepare && bundle exec rspec"
```

`docker-compose.yml` monta el directorio del proyecto en `/rails` dentro de
`web`/`sidekiq` (`volumes: - .:/rails`), así que comandos como `rubocop -A`
corridos con `docker compose exec` modifican tus archivos reales, no solo la
copia dentro de la imagen:

```bash
docker compose exec web bundle exec rubocop -A
```

## 3. Configurar el webhook en GitHub

En el repo (o en la GitHub App si gestionas varios repos a la vez):
- Payload URL: `https://tu-dominio.com/webhooks/github`
- Content type: `application/json`
- Secret: el mismo que guardes cifrado en el registro `Repository`
  correspondiente
- Eventos: solo "Pull requests"

Crea el registro del repo desde la consola de Rails:

```bash
docker compose exec web bin/rails console
```

```ruby
Repository.create!(github_full_name: "tu-org/tu-repo", webhook_secret: "el-secreto-que-pusiste-en-github")
```

## 4. Desarrollo sin Docker (alternativa)

Necesitas Ruby 3.2.3, Postgres y Redis corriendo localmente.

```bash
bundle install
bin/rails db:prepare
bundle exec rspec
bin/rails server          # en una terminal
bundle exec sidekiq        # en otra
```

Las mismas variables de entorno de `.env.example` aplican (cárgalas con
`dotenv`, `direnv`, o exportándolas a mano).

## Arquitectura en una frase por pieza

- `WebhooksController` — recibe el POST de GitHub, verifica la firma, encola el job.
- `ProcessPullRequestJob` — al abrir una PR asigna revisor; al mergear, registra qué archivos se tocaron.
- `FileLanguageMapper` — traduce una ruta de archivo a una categoría de tecnología legible.
- `ExpertiseCalculator` — calcula cuánto sabe cada persona de cada tecnología, con más peso a lo reciente (vida media de 90 días).
- `ReviewerSelector` — combina expertise relevante + carga actual para elegir revisor.
- `SlackNotifier` — avisa por DM al elegido.

## Lo que falta para ser un producto vendible (no está en este MVP a propósito)

- Multi-tenant real (ahora mismo un `Repository` no está ligado a una cuenta/organización cliente).
- Panel visual para ver el mapa de expertise del equipo (ahora mismo solo existe como datos).
- Instalación self-service vía GitHub App (ahora mismo el `Repository` y el token se crean a mano).
- Facturación (Stripe) — no tiene sentido hasta que alguien confirme que pagaría.
