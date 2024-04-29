//Updated for v1.1
//Note, this MIGHT fail. Please create a issue request and i will try to fix the issue!
//Also note, i am not great at node.js. This is my first public, open-source project.

const { exec } = require("child_process");
const { v4: uuidv4 } = require('uuid')
const axios = require("axios")
const os = require("os");

const express = require("express")
const app = express()

const PORT = 3001
const activeEndpoints = {}

app.use(express.json())

app.get("/s", (req, res) => {
    if (req.get("Authorization") === "x-x-x-x-x") { //Set an Code here if you want to access endpoints used.
        const filteredEndpoints = Object.entries(activeEndpoints).reduce((acc, [key, value]) => {
            const { requestQueue, ...rest } = value;
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

app.post('/s/:endpoint/i-n-t/req', async (req, res) => {
    const endpoint = req.params.endpoint;
    const name = parseInt(req.headers["request-index"]) - 1;
    const content = req.body;

    async function isValidStatusCode(code) {
        try {
            const response = await axios.get('https://status.js.org/codes.json');
            const validStatusCodes = response.data;
            return validStatusCodes.hasOwnProperty(code);
        } catch (error) {
            console.error("Error fetching valid status codes:", error);
            return false;
        }
    }

    if (activeEndpoints[endpoint]) {
        if (req.headers["authorization"] === activeEndpoints[endpoint].auth) {
            if (activeEndpoints[endpoint].requestQueue[name]) {
                const statusCode = parseInt(content.status);

                // Check if the status code is valid
                if (await isValidStatusCode(statusCode)) {
                    activeEndpoints[endpoint].requestQueue[name].res.status(statusCode).send(content.msg);
                    activeEndpoints[endpoint].requestQueue.splice(name, 1);
                    activeEndpoints[endpoint].readableRequestQueue.splice(name, 1);
                    res.sendStatus(204);
                } else {
                    // If the status code is invalid, send a 400 error to the requestor
                    res.status(400).send("Invalid status code");
                    activeEndpoints[endpoint].requestQueue[name].res.status(500).send("Server Attempted to send a invalid HTTP Code");
                    activeEndpoints[endpoint].requestQueue.splice(name, 1);
                    activeEndpoints[endpoint].readableRequestQueue.splice(name, 1);
                }
            } else {
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
            res.status(200).send(`luexp-server luexp/1.1; (express@?; Node ?; ?)`)
            return;
        }
        const packageVersion = require('express/package.json').version;
        let server = req.hostname
        if (server === undefined) {
            server = "undefined (likely api.perox.dev?) "
        }
        res.status(200).send(`luexp-server luexp/1.1; (express@${packageVersion}; Node ${stdout}; ${os.platform()}; ${os.arch()}; ${os.release()}; Server ${server})`)
    })
})

app.use('/s/:endpoint/*', express.raw({ type: '*/*' }));

app.all('/s/:endpoint/*', (req, res) => {
    let bodyString;

    if (req.is('json')) {
        bodyString = JSON.stringify(req.body);
    } else {
        bodyString = req.body.toString();
    }

    const endpoint = req.params.endpoint;
    const remainingPath = "/" + req.params[0];

    if (activeEndpoints[endpoint]) {
        activeEndpoints[endpoint].requestQueue.push({ req, res, endpoint, remainingPath });
        const nonredIndex = activeEndpoints[endpoint].requestQueue.length;
        const readableRequestQueue = {
            req: {
                baseUrl: req.baseUrl,
                headers: req.headers,
                body: bodyString,
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
    let url = `${req.protocol}://${req.hostname}`
    if (req.hostname === "localhost") {
        url = `${url}:${PORT}`
    }
    url = `${url}/s/${req.params.endpoint}`
    res.status(200).json({ url: url, auth: activeEndpoints[req.params.endpoint].auth })
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
