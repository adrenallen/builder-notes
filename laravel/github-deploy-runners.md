Example of a github runner to deploy laravel app on a given server using .env vars from github.

Not perfect and use at your own risk!

```
name: Deploy main to Production

on:
  workflow_dispatch:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: [self-hosted, prod-app]
    environment: production-app
    defaults:
      run:
        working-directory: /var/www/laravel

    steps:
      - name: Deploying to laravel
        run: echo "🚀 Starting deployment..."

      - name: Reset Local Changes
        run: git checkout -- .

      - name: Pull Latest Code
        run: git pull origin main

      - name: Build .env from secrets and variables
        run: |
          jq -n --argjson secrets '${{ toJSON(secrets) }}' \
            '$secrets | to_entries | .[] | select(.key | test("^(GITHUB_TOKEN|github_token)$") | not) | "\(.key)=\(.value | @json)"' -r > .env
          jq -n --argjson vars '${{ toJSON(vars) }}' \
            '$vars | to_entries | .[] | "\(.key)=\(.value | @json)"' -r >> .env

      - name: Install NPM Dependencies
        run: npm ci

      - name: Install Composer Dependencies
        run: composer install

      - name: Run Database Migrations
        run: php artisan migrate --force

      - name: Build Frontend Assets
        run: npm run build

      - name: Clear Optimizations
        run: php artisan optimize:clear

      - name: Cache Config
        run: php artisan config:cache

      - name: Dump Autoload
        run: composer dump-autoload

```
