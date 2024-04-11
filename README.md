### luexp - API Framework for Roblox

**luexp** is an API framework designed for Roblox, allowing developers to easily create RESTful APIs within Roblox games. With **luexp**, you can quickly set up endpoints to handle HTTP requests and build powerful APIs for your Roblox projects.

### Features

- **Easy-to-Use**: Create APIs with simple, expressive syntax.
- **HTTP Method Support**: Handle GET, POST, PUT, DELETE, and other HTTP methods.
- **Route Handling**: Define routes and their corresponding actions.
- **Middleware and Routers** (Coming Soon): Additional features for advanced API development.

### Getting Started

To start using **luexp**, follow these simple steps:

1. **Installation**: Import the `luexp` module into your Roblox game.

```lua
local luexp = require(game:GetService("ReplicatedStorage").luexp)
local app = luexp()
```

2. **Define Routes**: Define your API endpoints and their corresponding actions.

```lua
app.get("/", function(req, res)
    res.status(200, "Hello, world!")
end)
```

3. **Start Listening**: Start the server and specify the URL and authentication key.

```lua
app.listen("app", function(url, auth)
    print("Listening on " .. url)
    print("Auth Key: " .. auth)
end)
```

### Example

```lua
local luexp = require(game:GetService("ReplicatedStorage").luexp)
local app = luexp()

-- Define routes
app.get("/", function(req, res)
    res.status(200, "Hello, world!")
end)

-- Start listening
app.listen("app", function(url, auth)
    print("Listening on " .. url)
    print("Auth Key: " .. auth)
end)
```

### Support and Community

Join us on [Discord](https://discord.gg/tq9vQfH9Au) to get help, share your ideas, and connect with other developers using **luexp**.

### License

This project is licensed under the Creative Commons CC0 1.0 Universal License. Feel free to use and modify it for your own projects.
