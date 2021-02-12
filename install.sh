#!/usr/bin/env bash

### OBTÉM O IP LOCAL DO SERVIDOR E URL DE API
IP="$(hostname -i)"
VERSAO_SO="$(cat /etc/redhat-release)"
read -p "Informe o domínio público da API ex: ( api.dominio.com.br ) : " API_URL
read -p "Informe o domínio público da CDN ex: ( cdn.dominio.com.br ) : " CDN_URL

echo "Clonar plataforma de B2B?"
select yn in "y" "n"; do
    case ${yn} in
        Yes ) cd /opt/bdti && git clone git@gitlab.com:bdti/bd-2b-client.git b2b; break;;
    esac
done
