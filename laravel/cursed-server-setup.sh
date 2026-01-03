#!/bin/bash
set -e

# 🎨 Colors because who doesn't love a colorful terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (back to boring black and white)

PROGRESS_FILE=".setup-progress"
VARS_FILE=".setup-vars"

# Create files if they don't exist (they probably don't, because when do things ever work the first time?)
touch "$PROGRESS_FILE"
touch "$VARS_FILE"

# Source variables file if it exists (plot twist: it actually exists!)
if [[ -f "$VARS_FILE" ]]; then
    source "$VARS_FILE"
fi

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

prompt_if_empty() {
    local var_name=$1
    local prompt=$2
    local current_value="${!var_name}"
    
    if [[ -z "$current_value" ]]; then
        read -p "🤔 $prompt: " value
        if [[ -n "$value" ]]; then
            export "$var_name"="$value"
            echo "$var_name=\"$value\"" >> "$VARS_FILE"
        fi
    else
        export "$var_name"="$current_value"
        echo -e "${YELLOW}🎯 Using saved value for $var_name: $current_value (you lazy genius!)${NC}"
    fi
}

# Same as prompt_if_empty but supports default values for required fields
# Usage: prompt_required "VAR_NAME" "prompt text" ["default_value"]
prompt_required() {
    local var_name=$1
    local prompt=$2
    local default_value="${3:-}"
    local current_value="${!var_name}"
    
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
        read -p "$prompt_text: " value
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
    read -p "🤔 Enter your choice (1-4): " db_choice_input
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
        read -s -p "🔒 Enter PostgreSQL password for user '$DB_USER': " DB_PASS
        echo ""
        echo "DB_PASS=\"$DB_PASS\"" >> "$VARS_FILE"
    fi
    DB_HOST="127.0.0.1"
    DB_PORT="5432"
elif [[ "$DB_CHOICE" == "postgres_remote" ]]; then
    echo ""
    echo -e "${CYAN}🌐 === REMOTE POSTGRESQL CONNECTION DETAILS === 🌐${NC}"
    prompt_required "DB_HOST" "🏠 Enter PostgreSQL host (e.g. db.example.com)"
    if [[ -z "$DB_PORT" ]]; then
        read -p "🔌 Enter PostgreSQL port (default: 5432): " db_port_input
        DB_PORT="${db_port_input:-5432}"
        echo "DB_PORT=\"$DB_PORT\"" >> "$VARS_FILE"
    else
        echo -e "${YELLOW}🎯 Using saved value for DB_PORT: $DB_PORT (you lazy genius!)${NC}"
    fi
    prompt_required "DB_NAME" "🗄️ Enter PostgreSQL database name"
    prompt_required "DB_USER" "🔐 Enter PostgreSQL database user"
    if [[ -z "$DB_PASS" ]]; then
        read -s -p "🔒 Enter PostgreSQL password for user '$DB_USER': " DB_PASS
        echo ""
        echo "DB_PASS=\"$DB_PASS\"" >> "$VARS_FILE"
    fi
fi

prompt_required "GIT_REPO" "📦 Enter Git repo SSH URL to clone"

if [[ -z "$DOMAIN_NAME" ]]; then
    read -p "🌐 Enter domain name (leave blank if you're just testing): " DOMAIN_NAME
    echo "DOMAIN_NAME=\"$DOMAIN_NAME\"" >> "$VARS_FILE"
fi

# ⚡ Queue workers and cron jobs options
echo ""
echo -e "${CYAN}⚡ === BACKGROUND SERVICES CONFIGURATION === ⚡${NC}"

if [[ -z "$SETUP_QUEUE_WORKERS" ]]; then
    read -p "🔄 Set up queue workers with Supervisor? (y/n, default: y): " queue_choice
    case "$queue_choice" in
        [nN]|[nN][oO]) SETUP_QUEUE_WORKERS="no" ;;
        *) SETUP_QUEUE_WORKERS="yes" ;;
    esac
    echo "SETUP_QUEUE_WORKERS=\"$SETUP_QUEUE_WORKERS\"" >> "$VARS_FILE"
fi

if [[ -z "$SETUP_CRON_JOBS" ]]; then
    read -p "⏰ Set up Laravel scheduler cron job? (y/n, default: y): " cron_choice
    case "$cron_choice" in
        [nN]|[nN][oO]) SETUP_CRON_JOBS="no" ;;
        *) SETUP_CRON_JOBS="yes" ;;
    esac
    echo "SETUP_CRON_JOBS=\"$SETUP_CRON_JOBS\"" >> "$VARS_FILE"
fi

# 🧮 Set derived variables (the math nobody wants to do manually)
APP_PATH="/var/www/$APP_NAME"
PHP_VERSION="8.4"

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

STEP() {
    local name=$1
    shift
    
    if grep -q "^$name$" "$PROGRESS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⏭️ Skipping $name (already did this, thank goodness!)${NC}"
        return 0
    fi
    
    echo -e "${PURPLE}🔧 ATTEMPTING: $name (fingers crossed) 🔧${NC}"
    
    if eval "$@"; then
        echo "$name" >> "$PROGRESS_FILE"
        echo -e "${GREEN}✅ SUCCESS: $name actually worked! 🎉${NC}"
    else
        echo -e "${RED}💀 FAILED: $name broke everything! Time to Google the error! 💀${NC}"
        exit 1
    fi
}

# 🔄 System update (feeding the apt monster)
STEP "system_update" '
echo "📦 Updating packages (this is where things usually break first)..." &&
sudo apt update && 
sudo apt upgrade -y && 
sudo apt install -y curl git unzip zip software-properties-common lsb-release ca-certificates apt-transport-https gnupg &&
echo "🎉 Package updates completed without any dependency hell!"
'

# 🌐 Install Nginx (because Apache is so 2010)
STEP "nginx_install" '
echo "🌐 Installing Nginx (the cool web server)..." &&
sudo apt install -y nginx &&
sudo systemctl enable nginx &&
sudo systemctl start nginx &&
echo "🚀 Nginx is running! (probably serving the default welcome page right now)"
'

# 🐘 Install PHP (the language everyone loves to hate)
STEP "php_install" '
echo "🐘 Installing PHP '"$PHP_VERSION"' (its cool now)..." &&
sudo add-apt-repository ppa:ondrej/php -y &&
sudo apt update &&
sudo apt install -y php'"$PHP_VERSION"' php'"$PHP_VERSION"'-fpm php'"$PHP_VERSION"'-cli php'"$PHP_VERSION"'-mbstring php'"$PHP_VERSION"'-xml php'"$PHP_VERSION"'-curl php'"$PHP_VERSION"'-pgsql php'"$PHP_VERSION"'-sqlite3 php'"$PHP_VERSION"'-bcmath php'"$PHP_VERSION"'-zip php'"$PHP_VERSION"'-gd php'"$PHP_VERSION"'-common &&
sudo systemctl enable php'"$PHP_VERSION"'-fpm &&
sudo systemctl start php'"$PHP_VERSION"'-fpm &&
echo "🐘 PHP is installed and probably not causing any issues yet!"
'

# 🎼 Install Composer (dependency management that sometimes works)
STEP "composer_install" '
echo "🎼 Installing Composer (the dependency manager we cant live without)..." &&
curl -sS https://getcomposer.org/installer | php &&
sudo mv composer.phar /usr/local/bin/composer &&
sudo chmod +x /usr/local/bin/composer &&
echo "🎼 Composer installed! Ready to download half the internet!"
'

# 🐘 Install PostgreSQL (local) or just the client tools (remote)
if [[ "$DB_CHOICE" == "postgres_local" ]]; then
    STEP "postgres_install" '
    echo "🐘 Installing PostgreSQL (the database that actually follows standards)..." &&
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg &&
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list &&
    sudo apt update &&
    sudo apt install -y postgresql-17 postgresql-client-17 &&
    sudo systemctl enable postgresql &&
    sudo systemctl start postgresql &&
    echo "🐘 PostgreSQL is running! Now we can store data properly!"
    '
elif [[ "$DB_CHOICE" == "postgres_remote" ]]; then
    STEP "postgres_client_install" '
    echo "🐘 Installing PostgreSQL client tools (for connecting to remote database)..." &&
    sudo apt update &&
    sudo apt install -y postgresql-client &&
    echo "🐘 PostgreSQL client installed! You can now connect to your remote database with psql."
    '
else
    echo -e "${YELLOW}⏭️ Skipping PostgreSQL installation (not using postgres)${NC}"
fi

# 👤 Create user (birth of a new digital identity)
STEP "user_create" '
echo "👤 Creating user: $LINUX_USER (hopefully this username isnt taken)..." &&
if ! id "$LINUX_USER" &>/dev/null; then
    sudo adduser --disabled-password --gecos "" "$LINUX_USER" &&
    sudo usermod -aG www-data "$LINUX_USER" &&
    echo "🎉 User $LINUX_USER created! Welcome to the server life!"
else
    echo "👤 User $LINUX_USER already exists (smart, reusing things that work)"
fi
'

# 🔑 Generate SSH key (because passwords are for peasants)
STEP "ssh_keygen" '
echo "🔑 Generating SSH key (because memorizing passwords is hard)..." &&
sudo -u "$LINUX_USER" mkdir -p /home/"$LINUX_USER"/.ssh &&
sudo -u "$LINUX_USER" chmod 700 /home/"$LINUX_USER"/.ssh &&
if [[ ! -f /home/"$LINUX_USER"/.ssh/id_ed25519 ]]; then
    sudo -u "$LINUX_USER" ssh-keygen -t ed25519 -N "" -f /home/"$LINUX_USER"/.ssh/id_ed25519 &&
    echo "🔑 SSH key generated! Modern crypto for the win!"
else
    echo "🔑 SSH key already exists (you planned ahead, nice!)"
fi
'

# 🔑 SSH key upload prompt (the manual step nobody remembers)
if ! grep -q "^ssh_key_uploaded$" "$PROGRESS_FILE"; then
    echo ""
    echo -e "${CYAN}🔐 === TIME FOR SOME MANUAL LABOR === 🔐${NC}"
    echo -e "${YELLOW}📋 Copy this SSH key and add it to your Git provider (GitHub/GitLab/etc):${NC}"
    echo ""
    sudo cat /home/"$LINUX_USER"/.ssh/id_ed25519.pub
    echo ""
    echo -e "${PURPLE}⚡ Go add this to your repo settings, I'll wait... (seriously, go do it now) ⚡${NC}"
    read -p "🎯 Press ENTER after you've added the SSH key and tested it works..."
    echo "ssh_key_uploaded" >> "$PROGRESS_FILE"
    echo -e "${GREEN}✅ Cool, assuming you actually did that and didn't just hit enter!${NC}"
fi

# 📦 Install NVM and Node.js (because modern web dev requires JavaScript everywhere)
STEP "nvm_install" '
echo "📦 Installing NVM and Node.js (welcome to dependency hell)..." &&
sudo -u "$LINUX_USER" bash -c "
export NVM_DIR=\"/home/$LINUX_USER/.nvm\" &&
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash &&
source \"/home/$LINUX_USER/.nvm/nvm.sh\" &&
nvm install --lts &&
nvm use --lts &&
echo \"📦 Node.js installed! Now we can run JavaScript on the server (what a time to be alive)\"
"
'

# 🏗️ Clone repository (downloading the code that definitely works locally)
STEP "repo_clone" '
echo "🏴‍☠️ Cloning the repo (crossing fingers that the code actually works)..." &&
sudo mkdir -p "$APP_PATH" &&
sudo chown -R "$LINUX_USER":"$LINUX_USER" "$APP_PATH" &&
sudo -u "$LINUX_USER" bash -c "
cd /home/$LINUX_USER &&
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null || true &&
ssh-keyscan -H gitlab.com >> ~/.ssh/known_hosts 2>/dev/null || true &&
git clone \"$GIT_REPO\" \"$APP_PATH\" &&
echo \"🏴‍☠️ Code successfully downloaded! (now lets see if it runs anywhere other than localhost)\"
"
'

# 🗄️ Configure PostgreSQL (only if local postgres was chosen)
if [[ "$DB_CHOICE" == "postgres_local" ]]; then
    STEP "postgres_config" '
    echo "🗄️ Setting up PostgreSQL database (hopefully no permission errors)..." &&
    sudo -i -u postgres psql <<EOF
CREATE DATABASE "$DB_NAME";
CREATE USER "$DB_USER" WITH PASSWORD '"'"'$DB_PASS'"'"';
GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
\c "$DB_NAME"
GRANT USAGE, CREATE ON SCHEMA public TO "$DB_USER";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$DB_USER";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$DB_USER";
EOF
    echo "🗄️ Database configured! User has ALL the permissions (probably too many, but whatever)"
    '
else
    echo -e "${YELLOW}⏭️ Skipping local PostgreSQL configuration (not using local postgres)${NC}"
fi

# 📦 Install Laravel dependencies (composer install that takes forever)
STEP "composer_dependencies" '
echo "📦 Running composer install (this is where we download the entire PHP ecosystem)..." &&
cd "$APP_PATH" &&
sudo -u "$LINUX_USER" composer install --no-dev --optimize-autoloader &&
echo "📦 Composer finished! Only downloaded 200MB of dependencies!"
'

# ⚙️ Configure Laravel environment (the .env file dance)
STEP "laravel_env_config" '
echo "⚙️ Configuring Laravel environment (the .env file that will definitely be committed by accident)..." &&
cd "$APP_PATH" &&
if [[ ! -f .env && -f .env.example ]]; then
    sudo -u "$LINUX_USER" cp .env.example .env &&
    echo "📋 .env file created from example (hope all the defaults make sense)!"
fi &&
sudo -u "$LINUX_USER" php artisan key:generate --force &&
echo "🔑 Laravel app key generated (security through obscurity activated)!" &&
# Set production environment settings
sudo -u "$LINUX_USER" sed -i "s/^#*APP_ENV=.*/APP_ENV=production/" .env &&
sudo -u "$LINUX_USER" sed -i "s/^#*APP_DEBUG=.*/APP_DEBUG=false/" .env &&
echo "🚀 Environment set to PRODUCTION (no more debug traces for hackers to see)!" &&

# Configure database connection based on choice
if [[ "$DB_CHOICE" == "sqlite" ]]; then
    echo "🗄️ Configuring SQLite database..." &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_CONNECTION=.*/DB_CONNECTION=sqlite/" .env &&
    # Comment out or remove postgres-specific settings for sqlite
    sudo -u "$LINUX_USER" sed -i "s/^DB_HOST=.*/#DB_HOST=/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^DB_PORT=.*/#DB_PORT=/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^DB_DATABASE=.*/#DB_DATABASE=/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^DB_USERNAME=.*/#DB_USERNAME=/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^DB_PASSWORD=.*/#DB_PASSWORD=/" .env &&
    # Create the SQLite database file if it doesnt exist
    if [[ ! -f "$APP_PATH/database/database.sqlite" ]]; then
        sudo -u "$LINUX_USER" touch "$APP_PATH/database/database.sqlite" &&
        echo "📁 SQLite database file created!"
    fi &&
    if ! grep -q "^DB_CONNECTION=" .env; then
        echo "DB_CONNECTION=sqlite" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    echo "🗄️ SQLite database configured (simple and effective)!"
elif [[ "$DB_CHOICE" == "postgres_local" ]]; then
    echo "🗄️ Configuring local PostgreSQL database..." &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_CONNECTION=.*/DB_CONNECTION=pgsql/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_HOST=.*/DB_HOST=127.0.0.1/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_PORT=.*/DB_PORT=5432/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env &&
    # If the lines dont exist at all, add them
    if ! grep -q "^DB_CONNECTION=" .env; then
        echo "DB_CONNECTION=pgsql" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_HOST=" .env; then
        echo "DB_HOST=127.0.0.1" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_PORT=" .env; then
        echo "DB_PORT=5432" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_DATABASE=" .env; then
        echo "DB_DATABASE=$DB_NAME" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_USERNAME=" .env; then
        echo "DB_USERNAME=$DB_USER" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_PASSWORD=" .env; then
        echo "DB_PASSWORD=$DB_PASS" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    echo "🗄️ Local PostgreSQL connection configured!"
elif [[ "$DB_CHOICE" == "postgres_remote" ]]; then
    echo "🗄️ Configuring remote PostgreSQL database..." &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_CONNECTION=.*/DB_CONNECTION=pgsql/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_HOST=.*/DB_HOST=$DB_HOST/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_PORT=.*/DB_PORT=$DB_PORT/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env &&
    sudo -u "$LINUX_USER" sed -i "s/^#*DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env &&
    # If the lines dont exist at all, add them
    if ! grep -q "^DB_CONNECTION=" .env; then
        echo "DB_CONNECTION=pgsql" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_HOST=" .env; then
        echo "DB_HOST=$DB_HOST" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_PORT=" .env; then
        echo "DB_PORT=$DB_PORT" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_DATABASE=" .env; then
        echo "DB_DATABASE=$DB_NAME" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_USERNAME=" .env; then
        echo "DB_USERNAME=$DB_USER" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    if ! grep -q "^DB_PASSWORD=" .env; then
        echo "DB_PASSWORD=$DB_PASS" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
    fi &&
    echo "🗄️ Remote PostgreSQL connection configured (hope the firewall allows it)!"
else
    echo "⏭️ Skipping database configuration (you chose to configure it yourself, brave soul!)"
fi &&

# If the lines dont exist at all, add production settings
if ! grep -q "^APP_ENV=" .env; then
    echo "APP_ENV=production" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
fi &&
if ! grep -q "^APP_DEBUG=" .env; then
    echo "APP_DEBUG=false" | sudo -u "$LINUX_USER" tee -a .env > /dev/null
fi &&
echo "⚙️ Laravel environment configured! (probably no syntax errors this time)"
'

# 🗄️ Run database migrations and optimize Laravel (the moment of truth)
if [[ "$DB_CHOICE" != "none" ]]; then
    STEP "laravel_database_setup" '
    echo "🗄️ Running database migrations (please dont have any foreign key conflicts)..." &&
    cd "$APP_PATH" &&
    echo "🔮 Running php artisan migrate (hoping all migrations actually work)..." &&
    sudo -u "$LINUX_USER" php artisan migrate --force &&
    echo "⚡ Optimizing Laravel (making it go zoom zoom)..." &&
    sudo -u "$LINUX_USER" php artisan config:cache &&
    sudo -u "$LINUX_USER" php artisan route:cache &&
    sudo -u "$LINUX_USER" php artisan view:cache &&
    echo "🗄️ Database migrations completed and Laravel is optimized! (no errors = success!)"
    '
else
    STEP "laravel_optimize_only" '
    echo "⚡ Optimizing Laravel (skipping migrations since no database was configured)..." &&
    cd "$APP_PATH" &&
    sudo -u "$LINUX_USER" php artisan config:cache &&
    sudo -u "$LINUX_USER" php artisan route:cache &&
    sudo -u "$LINUX_USER" php artisan view:cache &&
    echo "⚡ Laravel optimized! (remember to run migrations manually when you set up the database)"
    '
fi

# 🎨 Build frontend assets (webpack/vite compilation roulette)
STEP "frontend_build" '
echo "🎨 Building frontend assets (pray to the webpack gods)..." &&
cd "$APP_PATH" &&
if [[ -f package.json ]]; then
    echo "📦 Installing npm dependencies (downloading the entire internet again)..." &&
    sudo -u "$LINUX_USER" bash -c "
    source /home/$LINUX_USER/.nvm/nvm.sh &&
    npm install &&
    echo \"📦 npm install completed without any vulnerability warnings (narrator: there were 47 vulnerabilities)\"
    " &&
    echo "🏗️ Running npm run build (this either works or takes 20 minutes to fail)..." &&
    sudo -u "$LINUX_USER" bash -c "
    source /home/$LINUX_USER/.nvm/nvm.sh &&
    npm run build &&
    echo \"🏗️ Frontend build successful! (CSS and JS are probably minified correctly)\"
    "
else
    echo "📦 No package.json found - either you'"'"'re old school or forgot to commit it! 🤷"
fi
'

# 🔒 Set permissions (chmod dance time)
STEP "permissions_config" '
echo "🔒 Setting file permissions (the chmod lottery)..." &&
sudo chown -R "$LINUX_USER":www-data "$APP_PATH" &&
sudo find "$APP_PATH" -type d -exec chmod 755 {} \; &&
sudo find "$APP_PATH" -path "$APP_PATH/node_modules" -prune -o -type f -exec chmod 644 {} \; &&
echo "📁 Basic file permissions set! (hopefully not too restrictive or too permissive)" &&
if [[ -d "$APP_PATH/storage" ]]; then
    sudo chmod -R 775 "$APP_PATH/storage" &&
    sudo chown -R "$LINUX_USER":www-data "$APP_PATH/storage" &&
    echo "🗄️ Storage directory now has write permissions (logs and cache can flow freely)!"
fi &&
if [[ -d "$APP_PATH/bootstrap/cache" ]]; then
    sudo chmod -R 775 "$APP_PATH/bootstrap/cache" &&
    sudo chown -R "$LINUX_USER":www-data "$APP_PATH/bootstrap/cache" &&
    echo "⚡ Bootstrap cache directory is writable (performance optimization unlocked)!"
fi &&
echo "🔒 File permissions configured! (everything should be readable and writable by the right people)"
'

# 🌐 Configure Nginx (reverse proxy configuration hell)
STEP "nginx_config" '
echo "🌐 Configuring Nginx (welcome to config file hell)..." &&
sudo rm -f /etc/nginx/sites-enabled/default &&
SERVER_NAME_BLOCK="_" &&
if [[ -n "$DOMAIN_NAME" ]]; then
    SERVER_NAME_BLOCK="$DOMAIN_NAME www.$DOMAIN_NAME _"
fi &&
NGINX_CONF="/etc/nginx/sites-available/$APP_NAME" &&
echo "📝 Writing Nginx config (copying from Stack Overflow)..." &&
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80 default_server;
    server_name $SERVER_NAME_BLOCK;

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
    add_header X-XSS-Protection "1; mode=block";

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
    location ~* \.(htaccess|htpasswd|ini|log|sh|sql|conf)\$ {
        deny all;
    }
}
EOF
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ &&
sudo nginx -t &&
sudo systemctl reload nginx &&
echo "🌐 Nginx configured and reloaded! (config test passed, miracle!)"
'

# 👁️ Install and configure Supervisor (the process babysitter) - only if queue workers enabled
if [[ "$SETUP_QUEUE_WORKERS" == "yes" ]]; then
    STEP "supervisor_install" '
    echo "👁️ Installing Supervisor (the process babysitter we all need)..." &&
    sudo apt install -y supervisor &&
    sudo systemctl enable supervisor &&
    sudo systemctl start supervisor &&
    echo "👁️ Supervisor is now watching your processes like a helicopter parent!"
    '

    # ⚡ Configure Supervisor for Laravel queues (background job management)
    STEP "supervisor_config" '
    echo "⚡ Configuring Laravel queue workers (because async is life)..." &&
    SUPERVISOR_CONF="/etc/supervisor/conf.d/laravel-worker.conf" &&
    sudo tee "$SUPERVISOR_CONF" > /dev/null <<EOF
[program:laravel-worker]
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
    sudo supervisorctl reread &&
    sudo supervisorctl update &&
    sudo supervisorctl start laravel-worker:* &&
    echo "⚡ Queue workers are now running in the background (doing the work while you sleep)!"
    '
else
    echo -e "${YELLOW}⏭️ Skipping Supervisor/queue workers setup (you opted out)${NC}"
fi

# ⏰ Configure Laravel Scheduler Cron Job (because manual tasks are for peasants)
if [[ "$SETUP_CRON_JOBS" == "yes" ]]; then
    STEP "laravel_cron_config" '
    echo "⏰ Setting up Laravel scheduler (automation is beautiful)..." &&
    CRON_COMMAND="* * * * * cd $APP_PATH && php artisan schedule:run >> /dev/null 2>&1" &&
    # Check if cron job already exists to avoid duplicates
    sudo -u "$LINUX_USER" bash -c "
    if ! crontab -l 2>/dev/null | grep -F \"$APP_PATH && php artisan schedule:run\" > /dev/null; then
        (crontab -l 2>/dev/null; echo \"$CRON_COMMAND\") | crontab -
        echo \"⏰ Cron job added! Laravel scheduler will run every minute (as it should)\"
    else
        echo \"⏰ Cron job already exists (someone was thinking ahead)\"
    fi
    " &&
    echo "⏰ Laravel scheduler is now automated! (set it and forget it)"
    '
else
    echo -e "${YELLOW}⏭️ Skipping Laravel scheduler cron job setup (you opted out)${NC}"
fi

echo ""
echo -e "${PURPLE}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${NC}"
echo -e "${GREEN}🚀 HOLY CRAP, IT ACTUALLY WORKED! 🚀${NC}"
echo -e "${CYAN}💻 Your Laravel app '$APP_NAME' is now live and probably not broken! 💻${NC}"
echo -e "${YELLOW}🌐 Check it out at: http://$(curl -4 -s ifconfig.me) 🌐${NC}"
if [[ -n "$DOMAIN_NAME" ]]; then
    echo -e "${PURPLE}🏠 Or if DNS is working: http://$DOMAIN_NAME 🏠${NC}"
fi
echo -e "${PURPLE}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${NC}"

echo ""
echo -e "${YELLOW}🔧 TODO: STUFF YOU STILL NEED TO DO (sorry, not everything is automated): 🔧${NC}"
echo -e "${CYAN}   🌐 Point your domain's DNS to this server's IP${NC}"
echo -e "${GREEN}   🔒 Get SSL working with: sudo certbot --nginx${NC}"
echo -e "${PURPLE}   👀 Double-check your .env file for any missing secrets${NC}"
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
