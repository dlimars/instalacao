#!/usr/bin/env bash

### INSTALAÇÃO DO POSTGRES
echo "Instalando postgres ..."
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum install -y postgresql11 postgresql11-server postgresql11-contrib
/usr/pgsql-11/bin/postgresql-11-setup initdb
systemctl enable postgresql-11
systemctl start postgresql-11

### LIBERAÇÃO DO POSTGRES PARA ACESSO EXTERNO
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/11/data/postgresql.conf
echo "host   all        all    0.0.0.0/0      md5" >> sudo vi /var/lib/pgsql/11/data/pg_hba.conf
