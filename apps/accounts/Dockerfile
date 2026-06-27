
FROM node:20-bullseye-slim AS builder
WORKDIR /app

COPY package*.json ./
COPY tsconfig*.json nest-cli.json ./
RUN npm ci

COPY apps ./apps
COPY libs ./libs

RUN npx nest build accounts


FROM node:20-bullseye-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /app/dist ./dist

EXPOSE 3000
CMD ["node", "dist/apps/accounts/main.js"]