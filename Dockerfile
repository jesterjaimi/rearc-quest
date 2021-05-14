FROM node:10
RUN mkdir -p /opt/app
WORKDIR /opt/app
RUN adduser app --no-create-home
COPY quest/ .
RUN npm install
RUN chown -R app /opt/app
USER app
EXPOSE 8080
CMD ["npm", "start"]
