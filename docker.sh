#!/bin/bash

# Atualiza e instala dependências necessárias
sudo apt update && sudo apt upgrade -y
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Adiciona a chave GPG do Docker e o repositório
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# Atualiza o índice de pacotes e instala o Docker CE
sudo apt update
sudo apt install docker-ce -y

# Adiciona o usuário ao grupo Docker e instala docker-compose
sudo usermod -aG docker ${USER}
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Aguarda até que o docker-compose esteja disponível (opcional)
while ! type docker-compose > /dev/null 2>&1; do
  sleep 1
done

# Clona e configura o Sentry
git clone https://github.com/getsentry/onpremise.git
cd onpremise
# Configura .env aqui se necessário
echo "y" | sudo ./install.sh
sudo docker-compose up -d
