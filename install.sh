#!/usr/bin/env bash

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
echo "Instalando dependências e utilitários"
sudo yum -y install git wget
curl https://raw.githubusercontent.com/creationix/nvm/v0.25.0/install.sh | bash
nvm install 10.14.1
npm install pm2@latest -g

### CONFIGURAR VERSÃO PADRÃO DO NODE
echo "Configurando versão default do node"
nvm alias default v10.14.1
nvm use v10.14.1

### INSTALAÇÃO DO DOCKER
echo "Instalando docker ..."
wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker root
sudo systemctl enable docker.service
sudo systemctl start docker.service

### INSTALAÇÃO DO DOCKER-COMPOSE
sudo curl -L --fail https://github.com/docker/compose/releases/download/1.25.0/run.sh -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

### INSTALAÇÃO DO POSTGRES
if isinstalled "postgresql11"; then
    echo "Postgres já foi instalado anteriormente"
else
    echo "Instalando postgres ..."
    sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    sudo yum install -y postgresql11 postgresql11-server postgresql11-contrib
    /usr/pgsql-11/bin/postgresql-11-setup initdb
    systemctl enable postgresql-11
    systemctl start postgresql-11
fi;


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

### CLONE DAS PLATAFORMAS
echo "Clonando repositório HYDRA"
mkdir /opt/bdti
cd /opt/bdti && git clone git@gitlab.com:bdti/hydra.git

echo "Clonar plataforma de B2B?"
select yn in "y" "n"; do
    case $yn in
        Yes ) cd /opt/bdti && git clone git@gitlab.com:bdti/bd-2b-client.git b2b; break;;
    esac
done

echo "Clonar plataforma de Call Center?"
select yn in "y" "n"; do
    case $yn in
        Yes ) cd /opt/bdti && git clone git@gitlab.com:bdti/bd-call-client.git call; break;;
    esac
done

cd /opt/bdti && git clone git@gitlab.com:bdti/bd-call-client.git adm
cd /opt/bdti && git clone git@gitlab.com:bdti/bd-cdn.git cdn

## CONFIGURAÇÃO DO CALLCENTER ( SE O DIRETÓRIO EXISTIR )
if [[ -d "/opt/bdti/call" ]]; then
    echo "CONFIGURANDO CALLCENTER"
    cd "/opt/bdti/call"
    cp .env-example .env
    cp .env-example external.env
    sed -i "s/localhost/$IP/" .env
    sed -i "s/localhost:7777/$API_URL/" external.env
    sed -i "s/localhost:8086/$API_URL/" external.env
    sed -i "s/localhost/$API_URL/" external.env
    npm install
    pm2 start server.js --name=call
fi

## CONFIGURAÇÃO DO B2B ( SE O DIRETÓRIO EXISTIR )
if [[ -d "/opt/bdti/b2b" ]]; then
    echo "CONFIGURANDO B2B"
    cd "/opt/bdti/b2b"
    cp .env-example .env
    cp .env-example external.env
    sed -i "s/localhost/$IP/" .env
    sed -i "s/localhost:7777/$API_URL/" external.env
    sed -i "s/localhost:8086/$API_URL/" external.env
    sed -i "s/localhost/$API_URL/" external.env
    npm install
    pm2 start server.js --name=b2b
fi

## CONFIGURAÇÃO DO ADM
echo "CONFIGURANDO PAINEL ADM"
cd "/opt/bdti/adm"
cp .env-example .env
cp .env-example external.env
sed -i "s/localhost/$IP/" .env
sed -i "s/localhost:7777/$API_URL/" external.env
sed -i "s/localhost:8086/$API_URL/" external.env
sed -i "s/localhost/$API_URL/" external.env
npm install
pm2 start server.js --name=adm

### CONFIGURAÇÃO DA CDN
echo "CONFIGURANDO CDN"
cd "/opt/bdti/cdn"
cp .env-example .env
npm install
pm2 start src/index.js --name=cdn

### CONFIGURAÇÃO DO BACKEND E CONTAINERS
echo "CONFIGURANDO APIS BACKEND"
cd "/opt/bdti/hydra"
cp .env-example .env
sed -i "s/localhost/$API_URL/" .env
cd "/opt/bdti/hydra/laradock"
cp env-example .env
sed -i "s/localhost/$IP/" .env

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
