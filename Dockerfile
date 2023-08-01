FROM node:lts AS builder

WORKDIR /app

COPY package.json yarn.lock tsconfig* nest-cli.json ./

RUN yarn install --production

COPY . .

RUN yarn add @nestjs/cli

RUN yarn build

FROM node:lts

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/dist ./dist
EXPOSE 3000
CMD [ "node", "dist/main" ]