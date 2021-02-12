#!/bin/bash

### OBTÉM O IP LOCAL DO SERVIDOR E URL DE API
IP="$(hostname -i)";
VERSAO_SO="$(cat /etc/redhat-release)";
read -p "Informe o domínio público da API ex: ( api.dominio.com.br ) : " API_URL;
read -p "Informe o domínio público da CDN ex: ( cdn.dominio.com.br ) : " CDN_URL;

echo "TESTE";
