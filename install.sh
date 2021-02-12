#!/bin/bash

echo "Clonar plataforma de B2B?"
select yn in "y" "n"; do
    case ${yn} in
        Yes ) cd /opt/bdti && git clone git@gitlab.com:bdti/bd-2b-client.git b2b; break;;
    esac
done
