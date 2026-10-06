FROM node:24-bookworm-slim AS verify
WORKDIR /app
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev
COPY backend/src ./src
COPY backend/migrations ./migrations
COPY backend/test ./test
RUN npm run check && npm test

FROM node:24-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=verify --chown=node:node /app/package.json /app/package-lock.json ./
COPY --from=verify --chown=node:node /app/node_modules ./node_modules
COPY --from=verify --chown=node:node /app/src ./src
COPY --from=verify --chown=node:node /app/migrations ./migrations
USER node
EXPOSE 3000
CMD ["node", "src/main.js"]
