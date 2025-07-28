FROM node:20

WORKDIR /app

COPY package*.json ./
RUN npm ci --force

COPY . .

EXPOSE 8545

CMD ["npx", "hardhat", "node"]