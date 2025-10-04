# trigger gh action
FROM node:22 AS build
ENV NODE_ENV=production 
WORKDIR /app
COPY my-portal/package*.json ./
RUN npm install @sveltejs/kit
RUN npm install
COPY my-portal/ ./
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
COPY --from=build /app .
ENV HOST=0.0.0.0
EXPOSE 4173
CMD ["npm","run", "preview","--", "--host", "0.0.0.0"]
