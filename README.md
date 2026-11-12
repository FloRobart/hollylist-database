# FlollyList — Base de données

Ce dépôt contient **tout ce qui concerne la base de données** de FlollyList :

- les migrations du schéma PostgreSQL, gérées avec [dbmate](https://github.com/amacneil/dbmate) ;
- l'image Docker de migrations `florobart/flollylist-migrations` ;
- les fichiers Docker Compose pour lancer la base en développement et en production.

L'API (`flollylist-api`) ne contient rien sur la base : elle s'y connecte par un réseau Docker. En production, c'est le réseau interne `flollylist-database-net`, déclaré à l'identique dans les deux dépôts ; en développement, c'est `flollylist-net`, créé par `docker-compose.dev.yml`.

# Table des matières

- [Structure](#structure)
- [Principe](#principe)
- [Schéma](#schéma)
- [Règles à respecter](#règles-à-respecter)
- [Développement](#développement)
- [Créer une migration](#créer-une-migration)
- [Publier l'image de migrations](#publier-limage-de-migrations)
- [Déployer en production](#déployer-en-production)
- [En cas de problème](#en-cas-de-problème)
- [Reprendre les données de l'ancienne installation](#reprendre-les-données-de-lancienne-installation)

# Structure

```
flollylist-database/
├── db/
│   ├── migrations/          ← une migration = un fichier, horodaté, immuable
│   └── schema.sql           ← état complet de la base, généré par dbmate (ne pas modifier à la main)
├── .github/                 ← CI (test des migrations + publication de l'image) et Dependabot
├── Dockerfile               ← image de migrations (dbmate + db/migrations)
├── docker-compose.yml       ← production : postgres + migrations + rôle de l'API
├── docker-compose.dev.yml   ← développement : postgres + dbmate
└── .env.example
```

# Principe

- En production, la base tourne sur l'image durcie `dhi.io/postgres:18` ; en développement, sur l'image officielle `postgres:18`. La version majeure est fixée, car changer de version majeure rend le volume illisible sans migration des données.
- En production, les images de base sont épinglées par digest : mettre à jour Postgres, c'est changer ce digest dans `docker-compose.yml`. Dependabot le propose chaque mois. Sans cela, aucun correctif de sécurité n'est récupéré.
- Chaque changement de schéma est un **fichier de migration** dans `db/migrations/`. Il contient une section `up` (appliquer) et une section `down` (annuler).
- dbmate enregistre les migrations appliquées dans la table `schema_migrations`. `dbmate up` n'exécute **que** celles qui manquent, dans l'ordre de leur horodatage.
- Chaque migration est exécutée dans une transaction : si elle échoue, rien n'est appliqué.
- En production, l'API ne se connecte pas avec le propriétaire de la base, mais avec le rôle `flollylist_api`, qui peut seulement lire et écrire les lignes des tables : ni modifier le schéma, ni toucher à la table `schema_migrations`. Une injection SQL dans l'API ne pourrait donc ni modifier le schéma ni exécuter de code sur le serveur.
- Le service ponctuel `flollylist-api-role` crée ce rôle, lui donne ses droits et applique le mot de passe de `secrets/api_db_password`. Il tourne à chaque déploiement, après les migrations : une nouvelle table est donc accessible à l'API sans rien faire de plus.

# Schéma

| Table | Contenu |
|---|---|
| `peoples` | Les proches d'un utilisateur : prénom, nom, date de naissance |
| `gifts` | Les cadeaux d'un proche : nom, description, année, prix, lien |

Chaque ligne porte le `user_id` de son propriétaire, l'identifiant de l'utilisateur chez Floraccess. La base garantit elle-même qu'un cadeau appartient à un proche **du même utilisateur** (clé étrangère sur `(people_id, user_id)`) : même une erreur de l'API ne pourrait pas rattacher un cadeau au proche d'un autre utilisateur. Supprimer un proche supprime ses cadeaux.

Le schéma complet, tel que dbmate le voit, est dans [db/schema.sql](db/schema.sql).

# Règles à respecter

- **Ne jamais modifier une migration déjà appliquée en production.** Pour corriger, on crée une nouvelle migration.
- **Ne jamais modifier le schéma de production à la main** (psql, DBeaver...). Tout passe par une migration.
- **Une migration = un changement logique**, petit et facile à relire.
- **Toujours écrire la section `down`** et la tester en local.
- **Changements destructifs en deux temps** (supprimer ou renommer une colonne utilisée par l'API) :
  1. déployer une API qui n'utilise plus la colonne ;
  2. déployer ensuite la migration qui la supprime.
- **Pas de données de test dans les migrations.** Seules les données de référence indispensables au fonctionnement y ont leur place.
- **Faire une sauvegarde avant chaque déploiement** en production. `deploy.sh` de `flollylist-wrapper` le fait déjà.

# Développement

Copier le fichier d'environnement. Les variables de développement y sont commentées car elles ont une valeur par défaut : les décommenter seulement pour les changer (`HOST_UID` et `HOST_GID` : résultats de `id -u` et `id -g`).

```bash
cp .env.example .env
```

Démarrer la base et appliquer toutes les migrations :

```bash
docker compose -f docker-compose.dev.yml up -d
```

`flollylist-migrate` applique les migrations, régénère `db/schema.sql`, puis s'arrête. La base reste accessible sur `127.0.0.1:5433` (`DB_PORT`, pour ne pas gêner la base de développement d'Éconoris sur le port 5432), et l'API en développement la joint via le réseau `flollylist-net`.

Commandes dbmate utiles (aucune installation nécessaire, tout passe par Docker) :

```bash
docker compose -f docker-compose.dev.yml run --rm flollylist-migrate status
```

```bash
docker compose -f docker-compose.dev.yml run --rm flollylist-migrate up
```

```bash
docker compose -f docker-compose.dev.yml run --rm flollylist-migrate rollback
```

- `status` : liste les migrations appliquées et en attente.
- `up` : applique les migrations en attente et régénère `db/schema.sql`.
- `rollback` : annule la dernière migration appliquée (section `down`).

Repartir d'une base vide (⚠️ supprime les données de développement) :

```bash
docker compose -f docker-compose.dev.yml down -v
```

# Créer une migration

1. Générer le fichier (le nom décrit le changement, en anglais, en snake_case) :

    ```bash
    docker compose -f docker-compose.dev.yml run --rm flollylist-migrate new add_wish_to_gifts
    ```

    dbmate crée `db/migrations/<horodatage>_add_wish_to_gifts.sql`.

2. Remplir les deux sections :

    ```sql
    -- migrate:up
    ALTER TABLE gifts ADD COLUMN is_wish BOOLEAN NOT NULL DEFAULT FALSE;

    -- migrate:down
    ALTER TABLE gifts DROP COLUMN is_wish;
    ```

3. Tester : `up`, puis `rollback`, puis `up` (voir [Développement](#développement)).
4. Adapter l'API si nécessaire (repositories, schémas zod...).
5. Commiter la migration **et** `db/schema.sql`. Le diff de `schema.sql` montre l'effet réel du changement.

Une nouvelle table n'a pas besoin de `GRANT` pour l'API : `flollylist-api-role` lui donne ses droits au déploiement suivant.

Pour modifier une fonction ou un trigger, créer une nouvelle migration avec `CREATE OR REPLACE FUNCTION ...` dans `up`, et l'ancienne définition dans `down`.

# Publier l'image de migrations

L'image `florobart/flollylist-migrations` contient dbmate et toutes les migrations. Au démarrage, elle applique les migrations en attente, puis s'arrête.

**Automatiquement (GitHub Actions)** : la CI ([Github-ci](https://github.com/FloRobart/github-ci), type « database ») teste les migrations sur une base vide à chaque pull request : `up`, `up` à nouveau (rien à faire), `rollback` de toutes les migrations, puis `up`. À chaque merge sur `main`, elle publie l'image sur GHCR et Docker Hub avec les tags `<version>` et `latest`.

Les secrets `DOCKERHUB_USERNAME` et `DOCKERHUB_TOKEN` doivent être configurés dans le dépôt GitHub, dans **Actions** et dans **Dependabot** : `docker-compose.yml` utilise une image `dhi.io`, que Dependabot doit pouvoir lire.

**À la main** :

```bash
docker build -t florobart/flollylist-migrations:1.0.0 -t florobart/flollylist-migrations:latest .
```

```bash
docker push --all-tags florobart/flollylist-migrations
```

# Déployer en production

En production, `flollylist-wrapper` déploie ce dépôt avec le reste de l'écosystème : il crée les secrets, sauvegarde la base, applique les migrations, puis démarre l'API. Voir son README.

Cette section décrit comment lancer ce dépôt seul, depuis le dossier contenant son `docker-compose.yml` et son `.env`.

**Toujours déployer la base avant l'API.** L'API a besoin du schéma à jour.

Prérequis, à préparer une seule fois :

- Le serveur doit être authentifié sur le registre des images durcies :

    ```bash
    docker login dhi.io
    ```

- Les secrets doivent exister dans le dossier `secrets/` (jamais commité) :

    - `secrets/db_password` : le mot de passe de la base, seul dans le fichier ;
    - `secrets/migrations.env` : une seule ligne, avec le mot de passe encodé pour une URL :

        ```
        DATABASE_URL=postgres://<DB_USER>:<DB_PASSWORD>@flollylist-database:5432/<DB_NAME>?sslmode=disable
        ```

    - `secrets/api_db_password` : le mot de passe du rôle `flollylist_api` de l'API, seul dans le fichier, avec des lettres et des chiffres uniquement.

    Le dossier protège les fichiers sur l'hôte. Les fichiers restent lisibles, car les conteneurs les lisent avec un utilisateur non-root :

    ```bash
    chmod 700 secrets
    ```

    ```bash
    chmod 644 secrets/db_password secrets/migrations.env secrets/api_db_password
    ```

Déploiement :

1. Sauvegarder la base. Sans les droits, qui nomment le rôle de l'API : il n'existe pas encore dans une base vide, et la restauration échouerait. `flollylist-api-role` les redonne au déploiement suivant :

    ```bash
    docker compose exec flollylist-database pg_dump --no-privileges -U <DB_USER> -d <DB_NAME> > backup_$(date +%F).sql
    ```

2. Récupérer les images. La dernière release est prise par défaut ; pour une autre version, la définir dans `MIGRATIONS_VERSION` :

    ```bash
    docker compose pull
    ```

3. Démarrer. La base démarre, puis `flollylist-migrate` applique **uniquement** les migrations manquantes et s'arrête. `flollylist-api-role` donne ensuite au rôle de l'API ses droits et son mot de passe, puis s'arrête à son tour :

    ```bash
    docker compose up -d
    ```

4. Vérifier que les migrations et le rôle de l'API sont passés (les deux services doivent être `Exited (0)`) :

    ```bash
    docker compose ps -a
    ```

    ```bash
    docker compose logs flollylist-migrate flollylist-api-role
    ```

5. Déployer ensuite l'API, depuis son propre dossier, avec `DB_USER=flollylist_api` et le mot de passe de `secrets/api_db_password`.

S'il n'y a aucune migration en attente, `flollylist-migrate` ne fait rien. On peut relancer `docker compose up -d` autant de fois que nécessaire.

# En cas de problème

- **La migration échoue** : elle est annulée (transaction), la base reste dans son état précédent et `flollylist-migrate` se termine en erreur (`Exited (1)`). Ne pas déployer la nouvelle API. Corriger avec une nouvelle migration, publier une nouvelle image, redéployer.
- **La migration passe mais elle est fausse** : écrire une nouvelle migration corrective. En dernier recours, restaurer la sauvegarde.
- **Le `rollback` est réservé au développement.** En production, on corrige vers l'avant.

# Reprendre les données de l'ancienne installation

L'ancienne base (image `florobart/flollylist-db`, créée par des scripts `docker-entrypoint-initdb.d`) n'a pas de schéma fiable : ces scripts ont changé après sa création (colonne `price`, `last_name` facultatif...), et ils ne tournent qu'à la création du volume. Son schéma n'est donc **jamais repris** : la nouvelle base est créée par les migrations, puis seules les **données** de l'ancienne y sont importées.

La procédure complète, avec les commandes, est dans le README de `flollylist-wrapper`, section « Reprendre les données de l'ancienne installation ».
