#!/bin/bash

function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

### OBTÉM O IP LOCAL DO SERVIDOR E URL DE API
IP="$(hostname -i)"
VERSAO_SO="$(cat /etc/redhat-release)"
read -p "Informe o domínio público da API ex: ( api.dominio.com.br ) : " API_URL
read -p "Informe o domínio público da CDN ex: ( cdn.dominio.com.br ) : " CDN_URL

### INSTALAR PACOTES NECESSÁRIOS
if isinstalled "git"; then
    echo "Dependências já foram instaladas anteriormente ..."
else
    echo "Instalando dependências e utilitários"
    sudo yum -y install git wget
    curl https://raw.githubusercontent.com/creationix/nvm/v0.25.0/install.sh | bash
fi;

### CONFIGURAR VERSÃO PADRÃO DO NODE
if [[ $(which npm) ]]; then
    echo "Configurando versão default do node";
    nvm install 10.14.1;
    nvm alias default v10.14.1;
    nvm use v10.14.1;
    npm install pm2@latest -g
fi;

### INSTALAÇÃO DO DOCKER
if [[ $(which docker) && $(docker --version) ]]; then
    echo "Docker já foi instalado anteriormente ..."
else
    echo "Instalando docker ..."
    wget -qO- https://get.docker.com/ | sh
    sudo usermod -aG docker root
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
fi;

### INSTALAÇÃO DO DOCKER-COMPOSE
if [[ $(which docker-compose) ]]; then
    echo "Docker-Compose já foi instalado anteriormente ..."
else
    sudo curl -L --fail https://github.com/docker/compose/releases/download/1.25.0/run.sh -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi;

### INSTALAÇÃO DO POSTGRES
if isinstalled "postgresql11"; then
    echo "Postgres já foi instalado anteriormente ..."
else
    echo "Instalando postgres ..."
    sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    sudo yum install -y postgresql11 postgresql11-server postgresql11-contrib
    /usr/pgsql-11/bin/postgresql-11-setup initdb
    systemctl enable postgresql-11
    systemctl start postgresql-11

    ### LIBERAÇÃO DO POSTGRES PARA ACESSO EXTERNO
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/11/data/postgresql.conf
    echo "host   all        all    0.0.0.0/0      md5" >> /var/lib/pgsql/11/data/pg_hba.conf
    systemctl restart postgresql-11

    ### CONFIGURAÇÃO INICIAL DO POSTGRES, CRIAÇÃO DO BANCO E SCHEMAS
    echo "create database plataforma;" | sudo -u postgres psql
    echo "grant all privileges on database plataforma to postgres;" | sudo -u postgres psql
    echo "\connect plataforma; create schema autoatendimento;" | sudo -u postgres psql
    echo "create schema autoatendimento;" | sudo -u postgres psql --dbname=plataforma
    echo "ALTER USER postgres with password 'default';" | sudo -u postgres psql
fi;

### CLONE DAS PLATAFORMAS
echo "Clonando repositório HYDRA"

if ! [[ -d "/opt/bdti" ]]; then
    mkdir /opt/bdti
fi;

if ! [[ -d "/opt/bdti/hydra" ]]; then
    cd /opt/bdti && git clone --depth 1 -b master git@gitlab.com:bdti/hydra.git
fi;

if ! [[ -d "/opt/bdti/b2b" ]]; then
    while true; do
        read -p "Clonar plataforma de B2B? [y/n]?" yn
        case $yn in
            [Yy]* ) cd /opt/bdti && git clone --depth 1 -b master git@gitlab.com:bdti/bd-2b-client.git b2b; break;;
            [Nn]* ) break;;
            * ) echo "Apenas Y ou N";;
        esac
    done
fi;

if ! [[ -d "/opt/bdti/call" ]]; then
    while true; do
        read -p "Clonar plataforma de CallCenter? [y/n]?" yn
        case $yn in
            [Yy]* ) cd /opt/bdti && git clone --depth 1 -b master git@gitlab.com:bdti/bd-call-client.git call; break;;
            [Nn]* ) break;;
            * ) echo "Apenas Y ou N";;
        esac
    done
fi;

if ! [[ -d "/opt/bdti/adm" ]]; then
    cd /opt/bdti && git clone --depth 1 -b master git@gitlab.com:bdti/bd-call-client.git adm;
fi;

if ! [[ -d "/opt/bdti/cdn" ]]; then
    cd /opt/bdti && git clone --depth 1 -b master git@gitlab.com:bdti/bd-cdn.git cdn;
fi;

## CONFIGURAÇÃO DO CALLCENTER ( SE O DIRETÓRIO EXISTIR )
if [[ -d "/opt/bdti/call" ]]; then

    if ! [[ -f "/opt/bdti/call/.env" ]]; then
        echo "CONFIGURANDO CALLCENTER"
        cd "/opt/bdti/call" \
            && cp .env-example .env \
            && cp .env-example external.env \
            && sed -i "s/localhost/$IP/" .env \
            && sed -i "s/localhost:7777/$API_URL/" external.env \
            && sed -i "s/localhost:8086/$API_URL/" external.env \
            && sed -i "s/localhost/$API_URL/" external.env \
            && npm install \
            && pm2 start server.js --name=call
    fi;

fi

## CONFIGURAÇÃO DO B2B ( SE O DIRETÓRIO EXISTIR )
if [[ -d "/opt/bdti/b2b" ]]; then
    if ! [[ -f "/opt/bdti/b2b/.env" ]]; then
        echo "CONFIGURANDO B2B"
        cd "/opt/bdti/b2b" \
            && cp .env-example .env \
            && cp .env-example external.env \
            && sed -i "s/localhost/$IP/" .env \
            && sed -i "s/localhost:7777/$API_URL/" external.env \
            && sed -i "s/localhost:8086/$API_URL/" external.env \
            && sed -i "s/localhost/$API_URL/" external.env \
            && npm install \
            && pm2 start server.js --name=b2b
    fi;
fi

## CONFIGURAÇÃO DO ADM
if ! [[ -f "/opt/bdti/adm/.env" ]]; then
    echo "CONFIGURANDO PAINEL ADM"
    cd "/opt/bdti/adm" \
        && cp .env-example .env \
        && cp .env-example external.env \
        && sed -i "s/localhost/$IP/" .env \
        && sed -i "s/localhost:7777/$API_URL/" external.env \
        && sed -i "s/localhost:8086/$API_URL/" external.env \
        && sed -i "s/localhost/$API_URL/" external.env \
        && npm install \
        && pm2 start server.js --name=adm\
fi;

### CONFIGURAÇÃO DA CDN
if ! [[ -f "/opt/bdti/cdn/.env" ]]; then
    echo "CONFIGURANDO CDN"
    cd "/opt/bdti/cdn" \
        && cp .env-example .env \
        && npm install \
        && pm2 start src/index.js --name=cdn
fi;

### CONFIGURAÇÃO DO BACKEND E CONTAINERS
if ! [[ -f "/opt/bdti/hydra/.env" ]]; then
    echo "CONFIGURANDO APIS BACKEND"
    cd "/opt/bdti/hydra" \
        && cp .env-example .env \
        && sed -i "s/localhost/$API_URL/" .env \
        && cd "/opt/bdti/hydra/laradock" \
        && cp env-example .env \
        && sed -i "s/localhost/$IP/" .env
fi;

echo "Adicionando entradas no iptables e firewall";

### LIBERAÇÃO DE PORTAS NO IPTABLES E FIREWALL
sudo iptables -A INPUT -p tcp --dport 5432 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8081 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8082 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8083 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8084 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8085 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8086 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 7777 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9999 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=8081/tcp
sudo firewall-cmd --permanent --add-port=8082/tcp
sudo firewall-cmd --permanent --add-port=8083/tcp
sudo firewall-cmd --permanent --add-port=8084/tcp
sudo firewall-cmd --permanent --add-port=8085/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --permanent --add-port=7777/tcp
sudo firewall-cmd --permanent --add-port=9999/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp

sudo firewall-cmd --reload
