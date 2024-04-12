const { exec } = require("child_process");
const { v4: uuidv4 } = require('uuid')
const os = require("os");

const express = require("express")
const app = express()

const PORT = 3001
const activeEndpoints = {}

app.use(express.json())

app.get("/s", (req, res) => {
    if (req.get("Authorization") === "f963207d-b49d-44d5-91ab-b9962b02cc46") {
        // Clone activeEndpoints while omitting the requestQueue property
        const filteredEndpoints = Object.entries(activeEndpoints).reduce((acc, [key, value]) => {
            // Destructure value to separate requestQueue from the rest of the properties
            const { requestQueue, ...rest } = value;
            // Accumulate the result without the requestQueue
            acc[key] = rest;
            return acc;
        }, {});

        res.send(JSON.stringify(filteredEndpoints));
    } else {
        res.status(401).send("Forbidden. You require an authorization key to access /s.\n\nDid you mean to access a custom endpoint?");
    }
});

app.get('/s/:endpoint/i-n-t/poll', (req, res) => {
    const endpoint = req.params.endpoint;
    if (activeEndpoints[endpoint]) {
        if (req.headers["authorization"] === activeEndpoints[endpoint].auth) {
            res.status(200).send(JSON.stringify(activeEndpoints[endpoint].readableRequestQueue))
        } else {
            res.status(401).send("Invalid authorization")
        }
    } else {
        res.status(404).send("Invalid endpoint")
    }
})

app.post('/s/:endpoint/i-n-t/req', (req, res) => {
    const endpoint = req.params.endpoint;
    const name = parseInt(req.headers["request-index"]) - 1;
    const content = req.body;

    if (activeEndpoints[endpoint]) {
        if (req.headers["authorization"] === activeEndpoints[endpoint].auth) {
            if (activeEndpoints[endpoint].requestQueue[name]) {
                activeEndpoints[endpoint].requestQueue[name].res.status(parseInt(content.status)).send(content.msg);
                activeEndpoints[endpoint].requestQueue.splice(name, 1); // This removes the item
                activeEndpoints[endpoint].readableRequestQueue.splice(name, 1) // Removes readable as well so Module cant get it.
                res.sendStatus(204);
            } else {
                // If the request at 'name' index does not exist, send an error response
                res.status(400).send("Request at index does not exist.");
            }
        } else {
            res.status(401).send("Invalid authorization");
        }
    } else {
        res.status(404).send("Invalid endpoint");
    }
});

app.get('/s/ver', async (req, res) => {
    exec("node -v", (error, stdout, stderr) => {
        if (error) {
            console.error(`exec error: ${error}`);
            res.status(200).send(`luexp-server luexp/1.0; (express@?; Node ?; ?)`)
            return;
        }
        const packageVersion = require('express/package.json').version;
        let server = req.hostname
        if (server === undefined) {
            server = "undefined (likely api.perox.dev?) "
        }
        res.status(200).send(`luexp-server luexp/1.0; (express@${packageVersion}; Node ${stdout}; ${os.platform()}; ${os.arch()}; ${os.release()}; Server ${server})`)
    })
})

app.all('/s/:endpoint/*', (req, res) => {
    const endpoint = req.params.endpoint;
    const remainingPath = "/" + req.params[0]; // Access the captured wildcard (*) using req.params[0]

    // Now you can work with both endpoint and remainingPath as needed
    if (activeEndpoints[endpoint]) {
        activeEndpoints[endpoint].requestQueue.push({ req, res, endpoint, remainingPath });
        const nonredIndex = activeEndpoints[endpoint].requestQueue.length;
        const readableRequestQueue = {
            req: {
                baseUrl: req.baseUrl,
                headers: req.headers,
                body: req.body,
                cookies: req.cookies,
                hostname: req.hostname,
                ip: req.get("X-Forwarded-For"),
                method: req.method,
                originalUrl: req.originalUrl,
                path: req.path,
                query: req.query,
                secure: req.secure,
                signedCookies: req.signedCookies,
                stale: req.stale,
                subdomains: req.subdomains,
                xhr: req.xhr
            },
            res: {
                headersSent: res.headersSent,

            },
            method: req.method,
            endpoint,
            remainingPath,
            nonredIndex
        };
        activeEndpoints[endpoint].readableRequestQueue.push(readableRequestQueue);
    } else {
        res.status(404).send("Invalid endpoint");
    }
});

app.put('/s/:endpoint', (req, res) => {
    if (activeEndpoints[req.params.endpoint]) {
        return res.status(409).send("Server Already Used!")
    }
    activeEndpoints[req.params.endpoint] = {
        requestQueue: [],
        readableRequestQueue: [],
        auth: uuidv4()
    }
    res.status(200).json({ url: `https://api.perox.dev/s/${req.params.endpoint}`, auth: activeEndpoints[req.params.endpoint].auth })
})

app.delete('/s/:endpoint', (req, res) => {
    const endpoint = req.params.endpoint;

    if (activeEndpoints[endpoint]) {
        if (req.headers["authorization"] === activeEndpoints[endpoint].auth) {
            delete activeEndpoints[endpoint];
            res.status(204).send();
        } else {
            res.status(401).send("Invalid authorization");
        }
    } else {
        res.status(404).send("Invalid endpoint");
    }
});        

app.listen(PORT, () => {
    console.log(`Server started on http://localhost:${PORT}/`)
})
