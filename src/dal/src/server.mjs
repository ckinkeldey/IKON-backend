import express from 'express';
import compression from 'compression';
import helmet from 'helmet';
import cors from 'cors';
import bodyParser from 'body-parser';
import https from 'https';
import openapi from 'express-openapi';
import fs from 'fs-extra';
import path from 'path';

import { initGeolocations } from './services/geocode';
import { initKnowledgeTransferActivities } from './services/knowledgeTransferActivities';
import { initProjects } from './services/projects';

import apidocs from './apidocs'


const app = express();

app.use(cors());
app.use(helmet());
app.use(compression({ level: 3 }));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

openapi.initialize({
  app,
  apiDoc: { 
    ... apidocs,
    promiseMode: true,
  dependencies: {
    geolocationService: initGeolocations,
    ktaService: initKnowledgeTransferActivities,
    projectService: initProjects
  },
  paths: './src/routes',
  docsPath: '/docs'
});

// Server setting
const PORT = process.env.PORT || 8080;


https.createServer({
  key: fs.readFileSync('/run/secrets/ssl_key'),
  cert: fs.readFileSync('/run/secrets/ssl_crt'),
}, app).listen(PORT, () => {
  console.log(`API Server Started On Port ${PORT}!`);
});

// exit strategy
process.on('SIGINT', async (err) => {
  console.log(err);
  await pool.end();
  process.exit(0);
});
