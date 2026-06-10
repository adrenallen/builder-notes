#!/bin/bash
# 🧨 Run on a FRESH Ubuntu box (22.04/24.04) as a user with sudo.
# Resumable: progress is tracked in .setup-progress, answers in .setup-vars
# (next to this script). Re-run after a failure and completed steps are skipped.
set -Eeuo pipefail

# 🎨 Colors because who doesn't love a colorful terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (back to boring black and white)

# Anchor state files next to the script so re-running from another cwd still resumes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
PROGRESS_FILE="$SCRIPT_DIR/.setup-progress"
VARS_FILE="$SCRIPT_DIR/.setup-vars"

# Create files if they don't exist (they probably don't, because when do things ever work the first time?)
touch "$PROGRESS_FILE"
touch "$VARS_FILE"
chmod 600 "$VARS_FILE" # it'll hold your DB password, keep prying eyes out

# Source variables file if it exists (plot twist: it actually exists!)
# shellcheck disable=SC1090
source "$VARS_FILE"

# Defaults so `set -u` doesn't explode on first run
APP_NAME="${APP_NAME:-}"
LINUX_USER="${LINUX_USER:-}"
DB_CHOICE="${DB_CHOICE:-}"
DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-}"
DB_PASS="${DB_PASS:-}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-}"
GIT_REPO="${GIT_REPO:-}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
SETUP_QUEUE_WORKERS="${SETUP_QUEUE_WORKERS:-}"
SETUP_CRON_JOBS="${SETUP_CRON_JOBS:-}"

# 💻 BEHOLD THE "WORKS ON MY MACHINE" LARAVEL SETUP SCRIPT 💻
cat << "EOF"
 ██████╗██╗   ██╗██████╗ ███████╗███████╗██████╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔════╝██╔══██╗
██║     ██║   ██║██████╔╝███████╗█████╗  ██║  ██║
██║     ██║   ██║██╔══██╗╚════██║██╔══╝  ██║  ██║
╚██████╗╚██████╔╝██║  ██║███████║███████╗██████╔╝
 ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═════╝

██╗      █████╗ ██████╗  █████╗ ██╗   ██╗███████╗██╗
██║     ██╔══██╗██╔══██╗██╔══██╗██║   ██║██╔════╝██║
██║     ███████║██████╔╝███████║██║   ██║█████╗  ██║
██║     ██╔══██║██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝  ██║
███████╗██║  ██║██║  ██║██║  ██║ ╚████╔╝ ███████╗███████╗
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚══════╝

███████╗███████╗████████╗██╗   ██╗██████╗
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
███████╗█████╗     ██║   ██║   ██║██████╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
███████║███████╗   ██║   ╚██████╔╝██║
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝
EOF

echo -e "${PURPLE}🚀 Welcome to the 'hopefully this doesn't break production' Laravel setup! 🚀${NC}"
echo -e "${CYAN}💻 This script will attempt to deploy your app (narrator: it actually works?) 💻${NC}"
echo -e "${YELLOW}☕ Grab some coffee, this might take a while... or break spectacularly ☕${NC}"
echo ""

# Prompt for a required value, with optional default. Saved values are reused on re-runs.
# Usage: prompt_required "VAR_NAME" "prompt text" ["default_value"]
prompt_required() {
    local var_name=$1
    local prompt=$2
    local default_value="${3:-}"
    local current_value="${!var_name:-}"

    if [[ -n "$current_value" ]]; then
        export "$var_name"="$current_value"
        echo -e "${YELLOW}🎯 Using saved value for $var_name: $current_value (you lazy genius!)${NC}"
        return
    fi

    local prompt_text="🤔 $prompt"
    if [[ -n "$default_value" ]]; then
        prompt_text="🤔 $prompt (default: $default_value)"
    fi

    while true; do
        read -r -p "$prompt_text: " value
        # Use default if provided and input is empty
        if [[ -z "$value" && -n "$default_value" ]]; then
            value="$default_value"
        fi

        if [[ -n "$value" ]]; then
            export "$var_name"="$value"
            echo "$var_name=\"$value\"" >> "$VARS_FILE"
            break
        else
            echo -e "${RED}⚠️ This field is required! Please enter a value.${NC}"
        fi
    done
}

# 📝 Time to collect configuration (aka the "it works on localhost" settings)
echo -e "${PURPLE}⚙️ Let's gather some config values (hopefully you remember what you named things)...${NC}"
prompt_required "APP_NAME" "🏷️ Enter your app name" "laravel"
prompt_required "LINUX_USER" "👤 Enter Linux user to create/manage" "laravel"

# 🗄️ Database choice (the "what flavor of data storage today?" question)
if [[ -z "$DB_CHOICE" ]]; then
    echo ""
    echo -e "${CYAN}🗄️ === DATABASE CONFIGURATION === 🗄️${NC}"
    echo -e "${YELLOW}Choose your database setup:${NC}"
    echo "  1) SQLite (simple, file-based, great for small apps)"
    echo "  2) PostgreSQL - Install locally (we'll set it up on this server)"
    echo "  3) PostgreSQL - Use remote (you have an existing PG server)"
    echo "  4) None (I'll configure the database myself later)"
    echo ""
    read -r -p "🤔 Enter your choice (1-4): " db_choice_input
    case "$db_choice_input" in
        1) DB_CHOICE="sqlite" ;;
        2) DB_CHOICE="postgres_local" ;;
        3) DB_CHOICE="postgres_remote" ;;
        4) DB_CHOICE="none" ;;
        *)
            echo -e "${YELLOW}⚠️ Invalid choice, defaulting to SQLite (the safe choice)${NC}"
            DB_CHOICE="sqlite"
            ;;
    esac
    echo "DB_CHOICE=\"$DB_CHOICE\"" >> "$VARS_FILE"
fi

# 🐘 Get PostgreSQL details based on choice
if [[ "$DB_CHOICE" == "postgres_local" ]]; then
    prompt_required "DB_NAME" "🗄️ Enter PostgreSQL database name"
    prompt_required "DB_USER" "🔐 Enter PostgreSQL database user"
    if [[ -z "$DB_PASS" ]]; then
        read -r -s -p "🔒 Enter PostgreSQL password for user '$DB_USER': " DB_PASS
        echo ""
        echo "DB_PASS=\"$DB_PASS\"" >> "$VARS_FILE"
    fi
    DB_HOST="127.0.0.1"
    DB_PORT="5432"
elif [[ "$DB_CHOICE" == "postgres_remote" ]]; then
    echo ""
    echo -e "${CYAN}🌐 === REMOTE POSTGRESQL CONNECTION DETAILS === 🌐${NC}"
    prompt_required "DB_HOST" "🏠 Enter PostgreSQL host (e.g. db.example.com)"
    prompt_required "DB_PORT" "🔌 Enter PostgreSQL port" "5432"
    prompt_required "DB_NAME" "🗄️ Enter PostgreSQL database name"
    prompt_required "DB_USER" "🔐 Enter PostgreSQL database user"
    if [[ -z "$DB_PASS" ]]; then
        read -r -s -p "🔒 Enter PostgreSQL password for user '$DB_USER': " DB_PASS
        echo ""
        echo "DB_PASS=\"$DB_PASS\"" >> "$VARS_FILE"
    fi
fi

prompt_required "GIT_REPO" "📦 Enter Git repo SSH URL to clone"

if [[ -z "$DOMAIN_NAME" ]]; then
    read -r -p "🌐 Enter domain name (leave blank if you're just testing): " DOMAIN_NAME
    echo "DOMAIN_NAME=\"$DOMAIN_NAME\"" >> "$VARS_FILE"
fi

# ⚡ Queue workers and cron jobs options
echo ""
echo -e "${CYAN}⚡ === BACKGROUND SERVICES CONFIGURATION === ⚡${NC}"

if [[ -z "$SETUP_QUEUE_WORKERS" ]]; then
    read -r -p "🔄 Set up queue workers with Supervisor? (y/n, default: y): " queue_choice
    case "$queue_choice" in
        [nN]|[nN][oO]) SETUP_QUEUE_WORKERS="no" ;;
        *) SETUP_QUEUE_WORKERS="yes" ;;
    esac
    echo "SETUP_QUEUE_WORKERS=\"$SETUP_QUEUE_WORKERS\"" >> "$VARS_FILE"
fi

if [[ -z "$SETUP_CRON_JOBS" ]]; then
    read -r -p "⏰ Set up Laravel scheduler cron job? (y/n, default: y): " cron_choice
    case "$cron_choice" in
        [nN]|[nN][oO]) SETUP_CRON_JOBS="no" ;;
        *) SETUP_CRON_JOBS="yes" ;;
    esac
    echo "SETUP_CRON_JOBS=\"$SETUP_CRON_JOBS\"" >> "$VARS_FILE"
fi

# 🧮 Set derived variables (the math nobody wants to do manually)
APP_PATH="/var/www/$APP_NAME"
PHP_VERSION="8.5"
NVM_VERSION="v0.40.3"

# 🚨 Validate required variables (because bash doesn't have TypeScript checking)
if [[ -z "$APP_NAME" || -z "$LINUX_USER" || -z "$GIT_REPO" ]]; then
    echo -e "${RED}💥 ERROR: Missing required values! This isn't gonna work chief, run it again! 💥${NC}"
    exit 1
fi

# Validate DB credentials if postgres is selected
if [[ "$DB_CHOICE" == "postgres_local" || "$DB_CHOICE" == "postgres_remote" ]]; then
    if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
        echo -e "${RED}💥 ERROR: Missing PostgreSQL credentials! Can't connect without them! 💥${NC}"
        exit 1
    fi
fi

# Validate DB_HOST for remote postgres
if [[ "$DB_CHOICE" == "postgres_remote" && -z "$DB_HOST" ]]; then
    echo -e "${RED}💥 ERROR: Missing PostgreSQL host for remote connection! 💥${NC}"
    exit 1
fi

# Display database choice nicely
case "$DB_CHOICE" in
    sqlite) DB_DISPLAY="SQLite (file-based)" ;;
    postgres_local) DB_DISPLAY="PostgreSQL (local install)" ;;
    postgres_remote) DB_DISPLAY="PostgreSQL (remote: $DB_HOST:$DB_PORT)" ;;
    none) DB_DISPLAY="None (manual configuration)" ;;
esac

echo -e "${GREEN}📋 ALRIGHT, HERE'S WHAT WE'RE WORKING WITH:${NC}"
echo "🏷️ App Name: $APP_NAME"
echo "👤 Linux User: $LINUX_USER"
echo "🐘 PHP Version: $PHP_VERSION"
echo "📦 Node Version: latest (via nvm)"
echo "🗄️ Database: $DB_DISPLAY"
if [[ "$DB_CHOICE" == "postgres_local" || "$DB_CHOICE" == "postgres_remote" ]]; then
    echo "   📦 DB Name: $DB_NAME"
    echo "   🔐 DB User: $DB_USER"
fi
echo "📦 Git Repo: $GIT_REPO"
echo "🌐 Domain: ${DOMAIN_NAME:-'(localhost life chosen)'}"
echo "📁 App Path: $APP_PATH"
echo "🔄 Queue Workers: $SETUP_QUEUE_WORKERS"
echo "⏰ Cron Jobs: $SETUP_CRON_JOBS"
echo ""

# 🏃 Step runner: skips completed steps, records success, dies loudly on failure.
# Steps are plain bash functions — no eval, no quoting hell. With set -Ee a
# failure anywhere inside a step aborts the script BEFORE the step is marked
# done, so re-running resumes exactly where things blew up.
CURRENT_STEP=""

on_error() {
    echo -e "${RED}💀 FAILED: ${CURRENT_STEP:-startup} broke everything! Time to Google the error! 💀${NC}"
    echo -e "${YELLOW}🔁 Fix the issue and re-run this script — completed steps will be skipped.${NC}"
}
trap on_error ERR

STEP() {
    local name=$1
    local fn=$2

    if grep -qx "$name" "$PROGRESS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⏭️ Skipping $name (already did this, thank goodness!)${NC}"
        return 0
    fi

    CURRENT_STEP="$name"
    echo -e "${PURPLE}🔧 ATTEMPTING: $name (fingers crossed) 🔧${NC}"
    "$fn"
    echo "$name" >> "$PROGRESS_FILE"
    echo -e "${GREEN}✅ SUCCESS: $name actually worked! 🎉${NC}"
}

# Set (or append) a KEY=VALUE in the app's .env, uncommenting it if needed.
set_env() {
    local key=$1
    local value=$2
    # Escape sed replacement specials so passwords with & | \ don't corrupt the file
    local escaped
    escaped=$(printf '%s' "$value" | sed -e 's/[&|\\]/\\&/g')
    if grep -qE "^#?[[:space:]]*${key}=" "$APP_PATH/.env"; then
        sudo -u "$LINUX_USER" sed -i -E "s|^#?[[:space:]]*${key}=.*|${key}=${escaped}|" "$APP_PATH/.env"
    else
        echo "${key}=${value}" | sudo -u "$LINUX_USER" tee -a "$APP_PATH/.env" > /dev/null
    fi
}

# Comment out a KEY in the app's .env (for settings that don't apply, e.g. DB_HOST with SQLite)
comment_env() {
    local key=$1
    sudo -u "$LINUX_USER" sed -i -E "s|^(${key}=.*)|# \1|" "$APP_PATH/.env"
}

# 🔄 System update (feeding the apt monster)
step_system_update() {
    echo "📦 Updating packages (this is where things usually break first)..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl git unzip zip software-properties-common lsb-release ca-certificates apt-transport-https gnupg
    echo "🎉 Package updates completed without any dependency hell!"
}
STEP "system_update" step_system_update

# 🌐 Install Nginx (because Apache is so 2010)
step_nginx_install() {
    echo "🌐 Installing Nginx (the cool web server)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo "🚀 Nginx is running! (probably serving the default welcome page right now)"
}
STEP "nginx_install" step_nginx_install

# 🐘 Install PHP (the language everyone loves to hate)
step_php_install() {
    echo "🐘 Installing PHP $PHP_VERSION (its cool now)..."
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "php$PHP_VERSION" \
        "php$PHP_VERSION-fpm" \
        "php$PHP_VERSION-cli" \
        "php$PHP_VERSION-mbstring" \
        "php$PHP_VERSION-xml" \
        "php$PHP_VERSION-curl" \
        "php$PHP_VERSION-pgsql" \
        "php$PHP_VERSION-sqlite3" \
        "php$PHP_VERSION-bcmath" \
        "php$PHP_VERSION-zip" \
        "php$PHP_VERSION-gd" \
        "php$PHP_VERSION-intl" \
        "php$PHP_VERSION-common"
    sudo systemctl enable "php$PHP_VERSION-fpm"
    sudo systemctl start "php$PHP_VERSION-fpm"
    echo "🐘 PHP $(php -r 'echo PHP_VERSION;') is installed and probably not causing any issues yet!"
}
STEP "php_install" step_php_install

# 🎼 Install Composer (dependency management that sometimes works)
step_composer_install() {
    echo "🎼 Installing Composer (the dependency manager we cant live without)..."
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
    echo "🎼 Composer installed! Ready to download half the internet!"
}
STEP "composer_install" step_composer_install

# 🐘 Install PostgreSQL (local) or just the client tools (remote)
step_postgres_install() {
    echo "🐘 Installing PostgreSQL (the database that actually follows standards)..."
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/postgresql.gpg
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-17 postgresql-client-17
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    echo "🐘 PostgreSQL is running! Now we can store data properly!"
}

step_postgres_client_install() {
    echo "🐘 Installing PostgreSQL client tools (for connecting to remote database)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-client
    echo "🐘 PostgreSQL client installed! You can now connect to your remote database with psql."
}

if [[ "$DB_CHOICE" == "postgres_local" ]]; then
    STEP "postgres_install" step_postgres_install
elif [[ "$DB_CHOICE" == "postgres_remote" ]]; then
    STEP "postgres_client_install" step_postgres_client_install
else
    echo -e "${YELLOW}⏭️ Skipping PostgreSQL installation (not using postgres)${NC}"
fi

# 👤 Create user (birth of a new digital identity)
step_user_create() {
    echo "👤 Creating user: $LINUX_USER (hopefully this username isnt taken)..."
    if ! id "$LINUX_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" "$LINUX_USER"
        echo "🎉 User $LINUX_USER created! Welcome to the server life!"
    else
        echo "👤 User $LINUX_USER already exists (smart, reusing things that work)"
    fi
    sudo usermod -aG www-data "$LINUX_USER"
}
STEP "user_create" step_user_create

# 🔑 Generate SSH key (because passwords are for peasants)
step_ssh_keygen() {
    echo "🔑 Generating SSH key (because memorizing passwords is hard)..."
    sudo -u "$LINUX_USER" mkdir -p "/home/$LINUX_USER/.ssh"
    sudo -u "$LINUX_USER" chmod 700 "/home/$LINUX_USER/.ssh"
    if [[ ! -f "/home/$LINUX_USER/.ssh/id_ed25519" ]]; then
        sudo -u "$LINUX_USER" ssh-keygen -t ed25519 -N "" -f "/home/$LINUX_USER/.ssh/id_ed25519"
        echo "🔑 SSH key generated! Modern crypto for the win!"
    else
        echo "🔑 SSH key already exists (you planned ahead, nice!)"
    fi
}
STEP "ssh_keygen" step_ssh_keygen

# 🔑 SSH key upload prompt (the manual step nobody remembers)
if ! grep -qx "ssh_key_uploaded" "$PROGRESS_FILE"; then
    echo ""
    echo -e "${CYAN}🔐 === TIME FOR SOME MANUAL LABOR === 🔐${NC}"
    echo -e "${YELLOW}📋 Copy this SSH key and add it to your Git provider (GitHub/GitLab/etc):${NC}"
    echo ""
    sudo cat "/home/$LINUX_USER/.ssh/id_ed25519.pub"
    echo ""
    echo -e "${PURPLE}⚡ Go add this to your repo settings, I'll wait... (seriously, go do it now) ⚡${NC}"
    read -r -p "🎯 Press ENTER after you've added the SSH key and tested it works..."
    echo "ssh_key_uploaded" >> "$PROGRESS_FILE"
    echo -e "${GREEN}✅ Cool, assuming you actually did that and didn't just hit enter!${NC}"
fi

# 📦 Install NVM and the latest Node.js (because modern web dev requires JavaScript everywhere)
step_nvm_install() {
    echo "📦 Installing NVM $NVM_VERSION and the latest Node.js (welcome to dependency hell)..."
    sudo -u "$LINUX_USER" bash -c "
    set -e
    export NVM_DIR=\"/home/$LINUX_USER/.nvm\"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
    source \"\$NVM_DIR/nvm.sh\"
    nvm install node
    nvm alias default node
    echo \"📦 Node \$(node --version) installed! Now we can run JavaScript on the server (what a time to be alive)\"
    "
}
STEP "nvm_install" step_nvm_install

# 🏗️ Clone repository (downloading the code that definitely works locally)
step_repo_clone() {
    echo "🏴‍☠️ Cloning the repo (crossing fingers that the code actually works)..."
    if [[ -d "$APP_PATH/.git" ]]; then
        echo "🏴‍☠️ Repo already cloned at $APP_PATH (skipping the download)"
        return 0
    fi
    sudo mkdir -p "$APP_PATH"
    sudo chown -R "$LINUX_USER":"$LINUX_USER" "$APP_PATH"
    sudo -u "$LINUX_USER" bash -c "
    set -e
    ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    ssh-keyscan -H gitlab.com >> ~/.ssh/known_hosts 2>/dev/null || true
    git clone \"$GIT_REPO\" \"$APP_PATH\"
    echo \"🏴‍☠️ Code successfully downloaded! (now lets see if it runs anywhere other than localhost)\"
    "
}
STEP "repo_clone" step_repo_clone

# 🗄️ Configure PostgreSQL (only if local postgres was chosen)
step_postgres_config() {
    echo "🗄️ Setting up PostgreSQL database (hopefully no permission errors)..."
    # Escape single quotes for SQL, and make everything idempotent for re-runs
    local db_pass_sql="${DB_PASS//\'/\'\'}"
    sudo -u postgres psql -v ON_ERROR_STOP=1 <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE "$DB_USER" LOGIN PASSWORD '$db_pass_sql';
    ELSE
        ALTER ROLE "$DB_USER" WITH LOGIN PASSWORD '$db_pass_sql';
    END IF;
END
\$\$;
EOF
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
        sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
    fi
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME" <<EOF
GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
GRANT USAGE, CREATE ON SCHEMA public TO "$DB_USER";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$DB_USER";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$DB_USER";
EOF
    echo "🗄️ Database configured! User has ALL the permissions (probably too many, but whatever)"
}

if [[ "$DB_CHOICE" == "postgres_local" ]]; then
    STEP "postgres_config" step_postgres_config
else
    echo -e "${YELLOW}⏭️ Skipping local PostgreSQL configuration (not using local postgres)${NC}"
fi

# 📦 Install Laravel dependencies (composer install that takes forever)
step_composer_dependencies() {
    echo "📦 Running composer install (this is where we download the entire PHP ecosystem)..."
    cd "$APP_PATH"
    sudo -u "$LINUX_USER" composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist
    echo "📦 Composer finished! Only downloaded 200MB of dependencies!"
}
STEP "composer_dependencies" step_composer_dependencies

# ⚙️ Configure Laravel environment (the .env file dance)
step_laravel_env_config() {
    echo "⚙️ Configuring Laravel environment (the .env file that will definitely be committed by accident)..."
    cd "$APP_PATH"
    if [[ ! -f .env && -f .env.example ]]; then
        sudo -u "$LINUX_USER" cp .env.example .env
        echo "📋 .env file created from example (hope all the defaults make sense)!"
    fi
    sudo -u "$LINUX_USER" php artisan key:generate --force
    echo "🔑 Laravel app key generated (security through obscurity activated)!"

    # Production environment settings
    set_env "APP_ENV" "production"
    set_env "APP_DEBUG" "false"
    if [[ -n "$DOMAIN_NAME" ]]; then
        set_env "APP_URL" "http://$DOMAIN_NAME"
    fi
    echo "🚀 Environment set to PRODUCTION (no more debug traces for hackers to see)!"

    # Configure database connection based on choice
    case "$DB_CHOICE" in
        sqlite)
            echo "🗄️ Configuring SQLite database..."
            set_env "DB_CONNECTION" "sqlite"
            set_env "DB_DATABASE" "$APP_PATH/database/database.sqlite"
            comment_env "DB_HOST"
            comment_env "DB_PORT"
            comment_env "DB_USERNAME"
            comment_env "DB_PASSWORD"
            if [[ ! -f "$APP_PATH/database/database.sqlite" ]]; then
                sudo -u "$LINUX_USER" touch "$APP_PATH/database/database.sqlite"
                echo "📁 SQLite database file created!"
            fi
            echo "🗄️ SQLite database configured (simple and effective)!"
            ;;
        postgres_local|postgres_remote)
            echo "🗄️ Configuring PostgreSQL connection..."
            set_env "DB_CONNECTION" "pgsql"
            set_env "DB_HOST" "$DB_HOST"
            set_env "DB_PORT" "$DB_PORT"
            set_env "DB_DATABASE" "$DB_NAME"
            set_env "DB_USERNAME" "$DB_USER"
            set_env "DB_PASSWORD" "$DB_PASS"
            echo "🗄️ PostgreSQL connection configured (hope the firewall allows it)!"
            ;;
        *)
            echo "⏭️ Skipping database configuration (you chose to configure it yourself, brave soul!)"
            ;;
    esac

    echo "⚙️ Laravel environment configured! (probably no syntax errors this time)"
}
STEP "laravel_env_config" step_laravel_env_config

# 🗄️ Run database migrations and optimize Laravel (the moment of truth)
step_laravel_database_setup() {
    echo "🗄️ Running database migrations (please dont have any foreign key conflicts)..."
    cd "$APP_PATH"
    echo "🔮 Running php artisan migrate (hoping all migrations actually work)..."
    sudo -u "$LINUX_USER" php artisan migrate --force
    echo "⚡ Optimizing Laravel (making it go zoom zoom)..."
    sudo -u "$LINUX_USER" php artisan config:cache
    sudo -u "$LINUX_USER" php artisan route:cache
    sudo -u "$LINUX_USER" php artisan view:cache
    if [[ ! -e public/storage ]]; then
        sudo -u "$LINUX_USER" php artisan storage:link
    fi
    echo "🗄️ Database migrations completed and Laravel is optimized! (no errors = success!)"
}

step_laravel_optimize_only() {
    echo "⚡ Optimizing Laravel (skipping migrations since no database was configured)..."
    cd "$APP_PATH"
    sudo -u "$LINUX_USER" php artisan config:cache
    sudo -u "$LINUX_USER" php artisan route:cache
    sudo -u "$LINUX_USER" php artisan view:cache
    if [[ ! -e public/storage ]]; then
        sudo -u "$LINUX_USER" php artisan storage:link
    fi
    echo "⚡ Laravel optimized! (remember to run migrations manually when you set up the database)"
}

if [[ "$DB_CHOICE" != "none" ]]; then
    STEP "laravel_database_setup" step_laravel_database_setup
else
    STEP "laravel_optimize_only" step_laravel_optimize_only
fi

# 🎨 Build frontend assets (webpack/vite compilation roulette)
step_frontend_build() {
    echo "🎨 Building frontend assets (pray to the webpack gods)..."
    cd "$APP_PATH"
    if [[ -f package.json ]]; then
        sudo -u "$LINUX_USER" bash -c "
        set -e
        source \"/home/$LINUX_USER/.nvm/nvm.sh\"
        cd \"$APP_PATH\"
        echo '📦 Installing npm dependencies (downloading the entire internet again)...'
        if [[ -f package-lock.json ]]; then
            npm ci
        else
            npm install
        fi
        echo '🏗️ Running npm run build (this either works or takes 20 minutes to fail)...'
        npm run build
        echo '🏗️ Frontend build successful! (CSS and JS are probably minified correctly)'
        "
    else
        echo "📦 No package.json found - either you're old school or forgot to commit it! 🤷"
    fi
}
STEP "frontend_build" step_frontend_build

# 🔒 Set permissions (chmod dance time)
step_permissions_config() {
    echo "🔒 Setting file permissions (the chmod lottery)..."
    sudo chown -R "$LINUX_USER":www-data "$APP_PATH"
    sudo find "$APP_PATH" -path "$APP_PATH/node_modules" -prune -o -type d -exec chmod 755 {} \;
    sudo find "$APP_PATH" -path "$APP_PATH/node_modules" -prune -o -type f -exec chmod 644 {} \;
    sudo chmod 755 "$APP_PATH/artisan"
    echo "📁 Basic file permissions set! (hopefully not too restrictive or too permissive)"
    if [[ -d "$APP_PATH/storage" ]]; then
        sudo chmod -R 775 "$APP_PATH/storage"
        echo "🗄️ Storage directory now has write permissions (logs and cache can flow freely)!"
    fi
    if [[ -d "$APP_PATH/bootstrap/cache" ]]; then
        sudo chmod -R 775 "$APP_PATH/bootstrap/cache"
        echo "⚡ Bootstrap cache directory is writable (performance optimization unlocked)!"
    fi
    if [[ "$DB_CHOICE" == "sqlite" ]]; then
        # SQLite needs the web server (www-data) to write BOTH the db file and its directory
        sudo chmod 775 "$APP_PATH/database"
        sudo chmod 664 "$APP_PATH/database/database.sqlite"
        echo "🗄️ SQLite file and database/ directory are writable by www-data (no more 'readonly database' errors)!"
    fi
    echo "🔒 File permissions configured! (everything should be readable and writable by the right people)"
}
STEP "permissions_config" step_permissions_config

# 🌐 Configure Nginx (reverse proxy configuration hell)
step_nginx_config() {
    echo "🌐 Configuring Nginx (welcome to config file hell)..."
    sudo rm -f /etc/nginx/sites-enabled/default
    local server_name_block="_"
    if [[ -n "$DOMAIN_NAME" ]]; then
        server_name_block="$DOMAIN_NAME www.$DOMAIN_NAME _"
    fi
    local nginx_conf="/etc/nginx/sites-available/$APP_NAME"
    echo "📝 Writing Nginx config (copying from Stack Overflow)..."
    sudo tee "$nginx_conf" > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name $server_name_block;

    root $APP_PATH/public;
    index index.php index.html;

    access_log /var/log/nginx/$APP_NAME.access.log;
    error_log /var/log/nginx/$APP_NAME.error.log;

    # Client and buffer settings (because some requests are chonky)
    client_max_body_size 100M;
    client_body_buffer_size 128k;
    client_header_buffer_size 32k;
    large_client_header_buffers 8 32k;

    # FastCGI buffer settings for handling large headers (no header shaming here)
    fastcgi_buffer_size 32k;
    fastcgi_buffers 8 32k;
    fastcgi_busy_buffers_size 64k;
    fastcgi_temp_file_write_size 64k;

    # Security headers (keeping the script kiddies out)
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";

        # FastCGI buffer settings (because PHP can be chatty)
        fastcgi_buffer_size 32k;
        fastcgi_buffers 8 32k;
        fastcgi_busy_buffers_size 64k;
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 60s;
        fastcgi_read_timeout 60s;

        include fastcgi_params;
    }

    # Deny access to hidden files (no peeking at .env!)
    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Deny access to sensitive files (nice try hackers)
    location ~* \.(htaccess|htpasswd|ini|log|sh|sql|conf|sqlite)\$ {
        deny all;
    }
}
EOF
    sudo ln -sf "$nginx_conf" /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx
    echo "🌐 Nginx configured and reloaded! (config test passed, miracle!)"
}
STEP "nginx_config" step_nginx_config

# 👁️ Install and configure Supervisor (the process babysitter) - only if queue workers enabled
step_supervisor_install() {
    echo "👁️ Installing Supervisor (the process babysitter we all need)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y supervisor
    sudo systemctl enable supervisor
    sudo systemctl start supervisor
    echo "👁️ Supervisor is now watching your processes like a helicopter parent!"
}

step_supervisor_config() {
    echo "⚡ Configuring Laravel queue workers (because async is life)..."
    local supervisor_conf="/etc/supervisor/conf.d/$APP_NAME-worker.conf"
    sudo tee "$supervisor_conf" > /dev/null <<EOF
[program:$APP_NAME-worker]
process_name=%(program_name)s_%(process_num)02d
command=php $APP_PATH/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=$LINUX_USER
numprocs=1
redirect_stderr=true
stdout_logfile=$APP_PATH/storage/logs/worker.log
stopwaitsecs=3600
EOF
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start "$APP_NAME-worker:*" || true # already running on re-runs, that's fine
    echo "⚡ Queue workers are now running in the background (doing the work while you sleep)!"
}

if [[ "$SETUP_QUEUE_WORKERS" == "yes" ]]; then
    STEP "supervisor_install" step_supervisor_install
    STEP "supervisor_config" step_supervisor_config
else
    echo -e "${YELLOW}⏭️ Skipping Supervisor/queue workers setup (you opted out)${NC}"
fi

# ⏰ Configure Laravel Scheduler Cron Job (because manual tasks are for peasants)
step_laravel_cron_config() {
    echo "⏰ Setting up Laravel scheduler (automation is beautiful)..."
    local cron_command="* * * * * cd $APP_PATH && php artisan schedule:run >> /dev/null 2>&1"
    # Check if cron job already exists to avoid duplicates
    sudo -u "$LINUX_USER" bash -c "
    if ! crontab -l 2>/dev/null | grep -F \"$APP_PATH && php artisan schedule:run\" > /dev/null; then
        (crontab -l 2>/dev/null; echo \"$cron_command\") | crontab -
        echo \"⏰ Cron job added! Laravel scheduler will run every minute (as it should)\"
    else
        echo \"⏰ Cron job already exists (someone was thinking ahead)\"
    fi
    "
    echo "⏰ Laravel scheduler is now automated! (set it and forget it)"
}

if [[ "$SETUP_CRON_JOBS" == "yes" ]]; then
    STEP "laravel_cron_config" step_laravel_cron_config
else
    echo -e "${YELLOW}⏭️ Skipping Laravel scheduler cron job setup (you opted out)${NC}"
fi

PUBLIC_IP="$(curl -4 -s --max-time 10 ifconfig.me || echo "<this-server's-ip>")"

echo ""
echo -e "${PURPLE}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${NC}"
echo -e "${GREEN}🚀 HOLY CRAP, IT ACTUALLY WORKED! 🚀${NC}"
echo -e "${CYAN}💻 Your Laravel app '$APP_NAME' is now live and probably not broken! 💻${NC}"
echo -e "${YELLOW}🌐 Check it out at: http://$PUBLIC_IP 🌐${NC}"
if [[ -n "$DOMAIN_NAME" ]]; then
    echo -e "${PURPLE}🏠 Or if DNS is working: http://$DOMAIN_NAME 🏠${NC}"
fi
echo -e "${PURPLE}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${NC}"

echo ""
echo -e "${YELLOW}🔧 TODO: STUFF YOU STILL NEED TO DO (sorry, not everything is automated): 🔧${NC}"
echo -e "${CYAN}   🌐 Point your domain's DNS to this server's IP${NC}"
echo -e "${GREEN}   🔒 Get SSL working with: sudo apt install certbot python3-certbot-nginx && sudo certbot --nginx${NC}"
echo -e "${PURPLE}   👀 Double-check your .env file for any missing secrets${NC}"
echo -e "${RED}   🧹 Delete $VARS_FILE and $PROGRESS_FILE when you're done (the vars file holds your DB password!)${NC}"
if [[ "$DB_CHOICE" != "none" ]]; then
    echo -e "${YELLOW}   💾 Set up database backups (because things break)${NC}"
fi
if [[ "$DB_CHOICE" == "none" ]]; then
    echo -e "${RED}   🗄️ Configure your database connection in .env and run migrations!${NC}"
fi
if [[ "$SETUP_QUEUE_WORKERS" == "no" ]]; then
    echo -e "${CYAN}   🔄 Set up queue workers if your app uses background jobs${NC}"
fi
if [[ "$SETUP_CRON_JOBS" == "no" ]]; then
    echo -e "${CYAN}   ⏰ Set up the Laravel scheduler cron job if your app uses scheduled tasks${NC}"
fi
echo ""
echo -e "${PURPLE}🎊 Congrats! You just deployed to production without breaking everything! 🎊${NC}"
