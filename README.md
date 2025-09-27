This is seperate repository for adding express-gateway and nginx configuration files.

# Project Setup

```
git init
npm init

npm i -g express-gateway

eg gateway create

Below is logged on execution of above command. A MicroservicesAPIGateway folder is created with many files.

C:\Users\User\angular\node-microservices\gateway>eg gateway create
Configuring yargs through package.json is deprecated and will be removed in a future major release, please use the JS API instead.
Configuring yargs through package.json is deprecated and will be removed in a future major release, please use the JS API instead.
Configuring yargs through package.json is deprecated and will be removed in a future major release, please use the JS API instead.
? What's the name of your Express Gateway? MicroservicesAPIGateway
? Where would you like to install your Express Gateway? MicroservicesAPIGateway
? What type of Express Gateway do you want to create? Getting Started with Express Gateway
   create package.json
   create server.js
   create config\gateway.config.yml
   create config\system.config.yml
   create config\models\applications.json
   create config\models\credentials.json
   create config\models\users.json

```


For logging, we have installed Winston and for loading environment variables from local.env when running locally, installed
dotenv as a dev dependency.



# Local Development

For local development, we will route all requests from client(browser) to the express-gateway, which in turn will route it to the
microservice.
For microservice-A to communicate with microservice-B, microservice-A will send request to the express-gateway, which in turn
will send the request to microservice-B.

To start the express-gateway, we run the below script.

`
    "local": "set DOTENV_CONFIG_PATH=./local.env&&node -r dotenv/config MicroservicesAPIGateway/server.js >> combined.log 2> error.log"

`

This script uses the local.env environment file and executes the server.js in the MicroservicesAPIGateway folder.

So we have used >> to append the standard output (stdout) of the node command to the combined.log file.
Also we are using 2> to redirect the standard error(stderr) of the node command to the error.log file.

=> Load Balancing: Locally, there is only 1 instance of each microservice as you see below, so there is no way to demonstrate load balancing capability of express-gateway. In docker this can be demonstrated.

```
serviceEndpoints:
  productService:
    urls:  
     - http://localhost:3601
    
  cartService:
    urls: 
      - http://localhost:3602
    
```

=> Logging:

Express-Gateway provides a in-built "log" plugin to write a log message.

```

- log: 
          - action:
              message: |
                    Request received:
                    Protocol: "${req.protocol}"
                    Method: "${req.method}"
                    Host: ${req.headers.host}
                    URL: ${req.originalUrl}
                    Headers: ${JSON.stringify(req.headers)}
                    Timestamp: ${new Date().toISOString()}

```

We can integrate Winston logger with Express-Gateway using a custom plugin.

In Express Gateway, policies and plugins are closely related but serve distinct roles in extending and customizing the gateway’s behavior. 

Plugin: A container for reusable functionality that can include policies, conditions, and schemas.
Pipline:A specific function that modifies request/response behavior in the gateway pipeline.

So I have created a logger-plugin which acts as a container for the custom-logger policy.

For this, i have created a plugins folder within MicroservicesAPIGateway.
Within the plugins folder , create a folder with the same name as your plugin i.e logger-plugin

Within the logger-plugin folder, created policies folder and an index.js file.

The policies folder contains 2 .js files: logger-policy.js and winstonLogger.js

In winstonLogger.js, we  have configured to display the log messages created using .info, .debug,
.error methods of winston on the console and also in files.
So any errors reported using the .error() in the app will get appended to the error.log
Messages created via .debug or .info will be appended to the combined.log

For local run, the files remain error.log and combined.log. With docker, the file paths change
and is available in the common.env file.

```
            filename:process.env.stderrPath || 'error.log',
            filename:process.env.stdoutPath || 'combined.log'


```


In the logger-policy.js, we have defined the message to created via the winston logger.

```
winstonLogger.info(`Received a request on ${req.protocol}://${req.headers.host}${req.originalUrl}`);

```

If you need to pass dynamic parameters from the .yml file to the policy,  you can add properties
in the logger-policy.js. The same properties can be accessed in the yml and you can feed values to these
properties in the yml dynamically.

```
 properties: {
        message: {
          type: 'string',
          default: ''
        }
      }
```

We have also given a name to the policy

```
    name: 'custom-logger',

```

In the yml, we have accessed the custom-logger policy as below.

```
 - custom-logger:
           - action:
               message: 'Writing a log message to Winston logger'

```

Finally in the index.js, we have provided the path to the logger-policy.js file.

```
 init: function (pluginContext) {
      pluginContext.registerPolicy(require('./policies/logger-policy'));
    },

```

In the system.config.yml, we have provided the name of plugin i.e logger-plugin and also the path to the plugin
in the package field. In docker, we use the env variable pluginPath defined in the common.env and for local we use the
./plugins/logger-plugin path. Note : ":-" means the value on the LHS is the default value if env variable value is not defined.

```
plugins:
   logger-plugin:
      package: ${pluginPath:-./plugins/logger-plugin}
```

So we have 3 kinds of logs here:
=>Using log policy
=>Express gateway stdout and stderr
=>Using custom-logger policy

Since we are using winston in the custom-logger policy, we can transport the logs to a file.
With docker, fi

Moving to rate-limit policy,

We can define how many times a particular api endpoint can be called based on multiple parameters.
Below is an example for productApi endpoint. 
rateLimitBy is the parameter based on which the limiting will be done. req.headers.host will contain the hostname:port.
If the same hostname:port is calling the productApi endpoint more than 4 times in 1 min, you will receive a message as mentioned below.

```
- rate-limit:
           - action:
              max: 4
              windowMs: 60000
              message: 'You have exceeded 4 requests/min'
              rateLimitBy: ${req.headers.host}

```

If you dont have different rate-limit policies for different apiEndpoints, you can consider writing a single rate-limit policy
under common apiendpoint.

Ensure the rate-limit policy is before the proxy policy so that it is evaluated first
Otherwise the rate-limit policy will not work

## Communication between microservices:

Microservice A will not directly communicate with Microservice B

Microservice A will send a request to nginx/express-gateway.
express-gateway/nginx will forward the request to Microservice B, get the response 
and send it to Microservice A.

Its important that in the request, we are including the path that helps the express
gateway route to the correct microservice to fulfill that request.


# Docker

There is no need for giving container names because docker assigns a name based on the service name.

When using docker, we will combining nginx and express-gateway

Client(browser) will send requests to nginx. Nginx will loadbalance between 3 express-gateway instances.
The express-gateway instance to which the request is routed, will loadbalance between 3 instances of the cart and
product microservice respectively. We have 3 instances of each microservices.
Based on the request path, the express-gateway will decide which microservice the request needs to be routed to and will also
loadbalance between different instances of that microservice.

```
For DEV - build the docker image

docker compose -p dev-gateway -f docker/docker-compose.yml -f docker/docker-compose.dev.override.yml build

docker compose -p dev-gateway -f docker/docker-compose.yml -f docker/docker-compose.dev.override.yml up -d --remove-orphans --no-build

For PROD -just run using the built docker image

docker compose -p prod-gateway -f docker/docker-compose.yml -f docker/docker-compose.prod.override.yml up -d --remove-orphans --no-build

```

NGINX

In nginx.dev.conf, we have defined the 3 instances of the express-gateway to which nginx will
proxy the request. Nginx here acts as a loadbalancer for the 3 instances of express-gateway.
The hostname is nothing but the docker service name.

```
upstream express_gateway_api{
    server express-gateway-service-1:8300;
    server express-gateway-service-2:8301;
    server express-gateway-service-3:8302;

}

```

Below will proxy all requests from client to one of the 3 instances of express-gateway.

```

 location / {
            proxy_set_header Host $http_host;  # $host only sends the hostname and not the port. $http_host sends both
            proxy_set_header X-Real-IP $remote_addr;
            add_header X-Proxy-Cache $upstream_cache_status;
            proxy_hide_header X-Powered-By;
            proxy_pass http://express_gateway_api;
            
        }

```


nginx logs available in the below locations in docker container. to include the upstream server details
in logs, we need to make changes in the http {} of the conf

```
  error_log /var/log/nginx/myerror.log debug;
  access_log /var/log/nginx/myaccess.log upstream_log;

```

For this reason, we have created nginx_default.conf, where we have added the below log format

```
 log_format upstream_log '$remote_addr - $remote_user [$time_local] "$request" '
                            '$status $body_bytes_sent "$http_referer" '
                            '"$http_user_agent" "$http_x_forwarded_for" '
                            '$upstream_addr $upstream_response_time';

```

Express Gateway

express-gateway will be used for routing the request from Nginx to the correct microservice. It also loadbalances the different instances
of the product and cart microservice in dev and prod. 

```
serviceEndpoints:
  productService:
    urls:  
     - http://product-node-1:${PRODUCT_SVCS_PORT_1}
     - http://product-node-2:${PRODUCT_SVCS_PORT_2}
     - http://product-node-3:${PRODUCT_SVCS_PORT_3}
    
  cartService:
    urls: 
     - http://cart-node-1:${CART_SVCS_PORT_1}
     - http://cart-node-2:${CART_SVCS_PORT_2}
     - http://cart-node-3:${CART_SVCS_PORT_3}
    
```

# SSL

For express-gateway, we have a seperate config file for prod, where we make use of ssl: gateway.config.prod.yml

```
1. We have generated a single Root CA Certificate used by all the microservices and gateways

openssl req -x509 -sha256 -days 1825 -newkey rsa:2048 -keyout rootCA.key -out rootCA.crt

2. NGINX

=>Generate private key
openssl genrsa -out nginx.key 2048

=>Generate csr using private key
openssl req -key nginx.key -new -out nginx.csr

=>Sign csr with root ca and generate nginx.crt using nginx-config.ext

openssl x509 -req -CA rootCA.crt -CAkey rootCA.key -in nginx.csr -out nginx.crt -days 365 -CAcreateserial -extfile nginx-config.ext

Below are the contents of the nginx-config.ext. Observe that in addition to localhost, we have included
the dockerservice name also in the DNS names.

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = nginx

3. Express Gateway

=> Generate private key
openssl genrsa -out express.key 2048

=> Generate csr using private key
openssl req -key express.key -new -out express.csr


=>Sign csr with root ca and generate express.crt using express-config.ext

openssl x509 -req -CA rootCA.crt -CAkey rootCA.key -in express.csr -out express.crt -days 365 -CAcreateserial -extfile express-config.ext

Below are the contents of the express-config.ext. Note that the docker service names are also included
in the DNS

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = express-gateway-service-1
DNS.3 = express-gateway-service-2
DNS.4 = express-gateway-service-3


```

In nginx, theres certificates are mounted from the host onto the container

```
 volumes:
       - C:/Users/User/certificates/self-signed-custom-ca/nginx.key:/etc/nginx/ssl/nginx.key
       - C:/Users/User/certificates/self-signed-custom-ca/nginx.crt:/etc/nginx/ssl/nginx.crt
```

In nginx.prod.conf, the ssl certificates mounted onto the container are referenced as below.

```
 ssl_certificate /etc/nginx/ssl/nginx.crt;
 ssl_certificate_key /etc/nginx/ssl/nginx.key;

```

In express-gateway, the certificicates are mounted as below:

```
 volumes:
        - C:/Users/User/certificates/self-signed-custom-ca/express.key:/var/lib/certs/express.key
        - C:/Users/User/certificates/self-signed-custom-ca/express.crt:/var/lib/certs/express.crt
        - C:/Users/User/certificates/self-signed-custom-ca/rootCA.crt:/var/lib/certs/rootCA.crt
```

These mounted paths are referenced in the prod.env file:

```
NODE_EXTRA_CA_CERTS=/var/lib/certs/rootCA.crt
keyPath=/var/lib/certs/express.key
certPath=/var/lib/certs/express.crt
```

NODE_EXTRA_CA_CERTS is required to be set to avoid ssl issues with self-signed certificates in 
express-gateway

The other 2 variables are references in the tls section in the gateway.config.prod.yml

```
tls:
    "default":
        key: ${keyPath}
        cert: ${certPath}
```

# Logging

Using winston + morgan for logging

npm i --save winston morgan
npm i --save-dev @types/morgan

set LOG_LEVEL=debug in local.env and common.env for usage in winstonLogger.js
If you dont set this, even debug logs appear as info.

As mentioned earlier, morgan is used for logging http requests and winston is a more genralised logger.

In src/logger, we have 2 files for winston and logger respectively.

Locally we are using combined.log and error.log in the root to store info+debug and error messages
respectively.

In docker, check the below variables set in common.env. The paths are different

```
stdoutPath=/var/log/express-gateway/combined.log
stderrPath=/var/log/express-gateway/error.log

```

Also in order to integrate this with ELK, we have done few more steps

1. Observe the filebeat folder in the root. Each microservice has the filebeat configured to pick up
the log messages from configured path, send them to logstash, which in turn sends them to elastic search. 
Kibana provides a visual display.

2. Logstash,Elastic Search and Kibana are configured in a seperate project. But filebeat needs to be in
every project, where log messages need to be collect, processed and displayed in kibana.

Moving to the docker-compose.yml

```
  filebeat:
      restart: always
      build:
        context: ../
        dockerfile: filebeat/Dockerfile
      environment:
         - strict.perms=false
      volumes:
         - nginx-logs-volume:/var/log/nginx/:ro
         - express-logs-volume:/var/log/express-gateway/:ro
      networks:
         - elk-network

```

In Docker, both named volumes and bind mounts are used to persist and share data between containers and the host system—but they serve different purposes and behave differently.
Here’s a clear comparison to help you choose the right one:

📦 Named Volumes
- Managed by Docker: Stored in Docker’s internal storage (/var/lib/docker/volumes/).
- Created by name: You can create them explicitly (docker volume create mydata) or implicitly when starting a container.
- Portable: Easier to use across environments (e.g., dev, staging, prod).
- Safe and isolated: Docker controls access, reducing risk of accidental deletion or modification.
- Backups and drivers: Can be backed up easily and support volume drivers (e.g., for cloud storage).
Use when:
- You want Docker to manage the storage.
- You need portability and isolation.
- You're deploying to production or orchestrating with Docker Compose or Swarm.

📂 Bind Mounts
- Direct host path: Maps a specific file or folder from the host system into the container.
- Full control: You can edit files directly on the host and see changes instantly in the container.
- Less portable: Depends on host file paths, which may vary across systems.
- More flexible: Useful for development, debugging, or sharing config files.
Use when:
- You need real-time access to host files (e.g., source code).
- You're developing locally and want to see changes instantly.
- You need to mount specific host directories.

So we have created 2 named volumes called nginx-logs-volume and express-logs-volume to store the
express-gateway logs and nginx logs.

```
  volumes:
         - nginx-logs-volume:/var/log/nginx/:ro
         - express-logs-volume:/var/log/express-gateway/:ro
```

- nginx-logs-volume is a named volume managed by Docker.
- Docker mounts this volume into the container at /var/log/nginx/.
- The :ro flag makes it read-only inside the container
- So inside the container, when it accesses /var/log/nginx/, it's actually reading data from the nginx-logs-volume —not from a specific host directory.

- express-logs-volume is a named volume managed by Docker.
- Docker mounts this volume into the container at /var/log/express-gateway/.
- The :ro flag makes it read-only inside the container
- So inside the container, when it accesses /var/log/express-gateway/, it's actually reading data from the express-logs-volume —not from a specific host directory.

🧠 Key Distinction
If you had used a bind mount like this:
volumes:
  - ./host-logs:/var/log/nginx/:ro


Then the container would be reading directly from the host path ./host-logs.
But with a named volume (logs-volume), Docker abstracts away the host path and manages the storage internally.


Observe that the docker service for the express-gateway and nginx also references the named volume. 
The express-gateway will write the logs using winston to the combined.log/error.log within /var/log/express-gateway folder. So this also means that these logs will be available in the express-logs-volume.

```
  volumes:
         - express-logs-volume:/var/log/express-gateway/
```

Nginx will write the logs using winston to the access.log/error.log within /var/log/nginx folder. So this also means that these logs will be available in the nginx-logs-volume.

```
volumes:
         - nginx-logs-volume:/var/log/nginx/
```

The filebeat service has ro access to the volume and can access the log messages.

- express-logs-volume or nginx-logs-volume: A Docker-managed volume that stores data persistently.
- /var/log/nginx or /var/log/express-gateway: The location inside the container where the volume is mounted.
- No :ro flag: So the mount is read-write by default—the container can read from and write to this volume.
- any logs or files written by the container to /var/log/express-gateway or /var/log/nginx will be stored in express-logs-volume/nginx-logs-volume.
- This data persists even if the container is stopped or removed.
- Multiple containers can share this volume if needed.

Observe that the filebeat service is connected to an external network: elk-network. This is nothing but the network connecting
elasticsearch,logstash and kibana services. In order to communicate with logstash and other services, filbeat needs to be connected
to the same network.

```
networks:
         - elk-network
```

No ports specified for filebeat in docker compose ?

Filebeat is a log shipper, not a service that listens for incoming network traffic. It typically:
- Reads log files from mounted volumes or paths.
- Sends data out to Elasticsearch, Logstash, or other endpoints.
Because it acts as a client, it doesn’t expose ports by default—so you don’t need to specify any ports: unless you’re doing something custom, like exposing its monitoring endpoint.

So unless you're explicitly enabling monitoring or debugging, no ports is perfectly normal.

In the filebeat.yml, observe that we have 2 types of inputs: from express-gateway and nginx

observe the service_name field added. This field will be used in the elk project
to differentiate between the logs of different microservices and gateways.

```
  fields:
           event.dataset: express-gateway
           service_name: express-gateway

   fields:
           event.dataset: nginx-gateway
           service_name: nginx-gateway
```
Filebeat picks up log messages from the location specified in the path field and sends to logstash
*.log ensures that both combined.log and error.log are picked.

```
paths:
            - /var/log/express-gateway/*.log

 paths:
            - /var/log/nginx/*.log


```


## What is an API gateway ?

Microservices are made accessible to the clients via the api gateway.
It acts as a gatekeeper orchestrating the flow of requests and responses between clients
and backend services.

Functions:

1. API routing to the correct microservice

2. Load balancing -They distribute traffic amongst different instances of the microservice.

3. Manage authentication and enforce access control policies for user authorisation.

4. Security like encryption,denial of service protection and often act as web app firewall.

5. Rate limiting/throttling to prevent abuse/overuse of services to ensure fair usage and system
stability.

6. Caching

We will be using Express Gateway to achieve this. Check the structure in public/images

=> Policies are a predefined set of rules/functionalities that can be applied to incoming request
or response. These policies define actions like authentication, rate limiting, transformations,security etc.
Each policy handles a specific aspect of the request-response flow.

=> Conditions are used to determine when a policy should be executed. They act as a trigger/criteria
that decides when a policy should be applied to an incoming request.

=>Actions are the actual transformations or functionalities that policies perform when a condition is met.


# how to check if container in 1 network is accessible to container in another network ?

In cmd, exeucte below to check if express-gateway-container can access product-node-1

```
docker exec -it express-gateway-container ping product-node-1

```

# Why favicon.ico ?

The "favicon.ico" is an original and universal file format for favicons, small icons that identify a website in browser tabs and bookmarks.
The .ico format is recognized by all web browsers, and it was the only format supported by older versions of Internet Explorer. 
Favicons, including the .ico file, provide a visual brand identity for a website, making it easier for users to identify and find it when multiple tabs are open. 
While .ico is still functional, other image formats have become more popular due to their advantages:
png,jpeg,gif and svg.

Using favicon.ico/ to generate your own favicon.

# Basics of Microservices

In a monolithic architecture, the entire code is in 1 codebase and is deployed as a single unit.
OK for smaller applications

In a microservices architectire, we do a functional decomposition into multiple services.
Each service has a single task or responsibility to focus on.
The services should be independently deployed with no dependencies on each other.
Single DB per service so each service can also use a different type of DB.
Communication only via API's. No shared data in memmory or DB or any other form.

An API gateway is used for routing the request to the correct microservice.
We will be using express-gateway as the API gateway.

Client app --->nginx --->api gateway ---> microservice ---> some other microservice or DB


Benefits:

1. Scale only specific services which are under heavy load and not the entire app.

2. Each service can use the same or a different framwork or technology without disturbing the rest of the application.

3. Each service can be release independently because there is no dependency.

4. Since the services are functioning independent of each other, a fault in 1 service does not bring the entire service down.

Challenges:

1. Integration and E2E tests are required to ensure2 that the communication between services is working as expected.

2. Harder to deploy.

3. Increased complexity when moving from a single code base to multiple codebases.

4. Monitoring,logging and tracing becomes difficult when you have multiple services.

Communication between the microservices can be achieved using REST API's i.e GET,POST,PUT, DELETE.

There are different communication patterns that can be used:

1. Event driven communication using EventEmitter.

2. Webhooks

3. Message based communication

4. Remote Procedure Call

5. WebSockets for real time communication.


Synchronous vs Asynchronous Communication between the microservices

1. Order service communicating with an inventory service is an example of synchronous communication.
The former checks with the latter if an item is in stock before placing an order. 
This also introduces a depndency. If the inventory service is down, then the order cannot be placed.
Synchronous communication is needed for immediate real time interactions.

2. Once an order is placed, the the Order service asynchronously informs the delivery service. An immediate confirmation is not required
from the delivery service.
If the delivery service is down, the message can be queued for processing later.
But this doesnt stop the order service from doing its work.
So Async communication between microservice is great when immediate feedback is not needed.


# Basics of MongoDB

https://github.com/Distinctlyminty/MicroserviceFundamentals/blob/main/VehicleService/src/services/vehicleService.js


In MongoDB, data is organized hierarchically:
## Databases:
A MongoDB instance refers to a single running process of the MongoDB database server, typically the mongod process. This process is responsible for managing the data files, handling client connections, and executing database operations.
A single process represents one active mongod process running on a server.

Each instance/single mongod process has its own configuration, often defined in a configuration file, which specifies details like data file locations, port number for connections, and other operational parameters.

Each instance/single mongod process manages its own set of data files where the actual MongoDB documents are stored.

Each instance/single mongod process listens on a specific port for incoming client connections.

A MongoDB instance can operate as a standalone server or as part of a larger cluster, such as a replica set or a sharded cluster. In a clustered environment, multiple instances work together to provide high availability and scalability.

A MongoDB instance can host multiple databases, each containing a distinct set of collections.

While a single MongoDB instance can host multiple databases, using separate databases for different environments within that instance is generally preferred


## Collections:
Analogous to tables in relational databases, a collection is a grouping of MongoDB documents. Unlike relational tables, collections are schema-less, meaning documents within the same collection can have varying fields and data types. Collections are automatically created when the first document is inserted into them.

## Documents:
Documents are the fundamental units of data storage in MongoDB, similar to rows in relational databases. They are stored in BSON (Binary JSON) format and consist of key-value pairs, which are essentially JSON objects. Each document within a collection must contain a unique _id field, which serves as a primary key. If not explicitly provided, MongoDB automatically generates an ObjectId for this field.

## Fields:
Within a document, individual key-value pairs represent fields, akin to columns in a relational table. Fields can hold various data types, including strings, numbers, booleans, arrays, embedded documents, and more. MongoDB's flexible schema allows for dynamic addition or removal of fields within documents in a collection without requiring a predefined schema for the entire collection.

## Schema:

In MongoDB, a schema is defined for a collection, not for an entire database.
While MongoDB is known for its schema flexibility, meaning you aren't strictly required to define a schema before inserting data, 
it's common practice to enforce a structure, especially in application development. This is typically done at the collection level, 
often using an Object Data Modeling (ODM) library like Mongoose in Node.js.

A schema defines:
1. The structure of documents: within a specific collection.
2. The fields: that documents in that collection should contain.
3. Data types: for each field (e.g., String, Number, Date, Boolean).
4. Validation rules: to ensure data integrity.
5. Default values: for fields.



