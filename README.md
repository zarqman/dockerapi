# dockerapi

Interact directly with Docker API from Ruby code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dockerapi'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install dockerapi

## Usage

### Images

```ruby
# Pull from a public repository
Docker::API::Image.create( fromImage: "nginx:latest" )

# Pull from a private repository
Docker::API::Image.create( {fromImage: "private/repo:tag"}, {username: "janedoe", password: "password"} )

# Create image from local tar file
Docker::API::Image.create( fromSrc: "/path/to/file.tar", repo: "repo:tag" )

# Create image from remote tar file
Docker::API::Image.create( fromSrc: "https://url.to/file.tar", repo: "repo:tag" )

# List images
Docker::API::Image.list
Docker::API::Image.list( all:true )

# Inspect image
Docker::API::Image.inspect("image")

# History
Docker::API::Image.history("image")

# Search image
Docker::API::Image.search(term: "busybox", limit: 2)
Docker::API::Image.search(term: "busybox", filters: {"is-automated": {"true": true}})
Docker::API::Image.search(term: "busybox", filters: {"is-official": {"true": true}})

# Tag image
Docker::API::Image.tag("current:tag", repo: "new:tag") # or
Docker::API::Image.tag("current:tag", repo: "new", tag: "tag")

# Push image
Docker::API::Image.push("repo:tag") # to dockerhub
Docker::API::Image.push("localhost:5000/repo:tag") # to local registry
Docker::API::Image.push("private/repo", {tag: "tag"}, {username: "janedoe", password: "password"} # to private repository

# Remove container
Docker::API::Image.remove("image")
Docker::API::Image.remove("image", force: true)

# Remove unsued images (prune)
Docker::API::Image.prune(filters: {dangling: {"false": true}})

# Create image from a container (commit)
Docker::API::Image.commit(container: container, repo: "my/image", tag: "latest", comment: "Comment from commit", author: "dockerapi", pause: false )

# Build image from a local tar file
Docker::API::Image.build("/path/to/file.tar")

# Build image from a remote tar file
Docker::API::Image.build(nil, remote: "https://url.to/file.tar")

# Build image from a remote Dockerfile
Docker::API::Image.build(nil, remote: "https://url.to/Dockerfile")

# Delete builder cache
Docker::API::Image.delete_cache

# Export repo
Docker::API::Image.export("repo:tag", "~/exported_image.tar")

# Import repo
Docker::API::Image.import("/path/to/file.tar")
```

### Containers 

Let's test a Nginx container

```ruby
# Pull nginx image
Docker::API::Image.create( fromImage: "nginx:latest" )

# Create container
Docker::API::Container.create( {name: "nginx"}, {Image: "nginx:latest", HostConfig: {PortBindings: {"80/tcp": [ {HostIp: "0.0.0.0", HostPort: "80"} ]}}})

# Start container
Docker::API::Container.start("nginx")

# Open localhost or machine IP to check the container running

# Restart container
Docker::API::Container.restart("nginx")

# Pause/unpause container
Docker::API::Container.pause("nginx")
Docker::API::Container.unpause("nginx")

# List containers
Docker::API::Container::list

# List containers (including stopped ones)
Docker::API::Container::list(all: true)

# Inspect container
Docker::API::Container.inspect("nginx")

# View container's processes
Docker::API::Container.top("nginx")

# Let's enhance the output
JSON.parse(Docker::API::Container.top("nginx").body)

# View filesystem changes
Docker::API::Container.changes("nginx")

# View filesystem logs
Docker::API::Container.logs("nginx", stdout: true)
Docker::API::Container.logs("nginx", stdout: true, follow: true)

# View filesystem stats
Docker::API::Container.stats("nginx", stream: true)

# Export container
Docker::API::Container.export("nginx", "~/exported_container")

# Get files from container
Docker::API::Container.archive("nginx", "~/html.tar", path: "/usr/share/nginx/html/")

# Stop container
Docker::API::Container.stop("nginx")

# Remove container
Docker::API::Container.remove("nginx")

# Remove stopped containers (prune)
Docker::API::Container.prune
```

### Volumes

```ruby
# Create volume
Docker::API::Volume.create( Name:"my-volume" )

# List volumes
Docker::API::Volume.list

# Inspect volume
Docker::API::Volume.inspect("my-volume")

# Remove volume
Docker::API::Volume.remove("my-volume")

# Remove unused volumes (prune)
Docker::API::Volume.prune
```

### Network

```ruby
# List networks
Docker::API::Network.list

# Inspect network
Docker::API::Network.inspect("bridge")

# Create network
Docker::API::Network.create( Name:"my-network" )

# Remove network
Docker::API::Network.remove("my-network")

# Remove unused network (prune)
Docker::API::Network.prune

# Connect container to a network
Docker::API::Network.connect( "my-network", Container: "my-container" )

# Disconnect container to a network
Docker::API::Network.disconnect( "my-network", Container: "my-container" )
```

### System

```ruby
# Ping docker api
Docker::API::System.ping

# Docker components versions
Docker::API::System.version

# System info
Docker::API::System.info

# System events (stream)
Docker::API::System.events(until: Time.now.to_i)

# Data usage information
Docker::API::System.df
```

### Requests

Requests should work as described in [Docker API documentation](https://docs.docker.com/engine/api/v1.40). Check it out to customize your requests.

### Response

All requests return a response class that inherits from Excon::Response. Available attribute readers and methods include: `status`, `data`, `body`, `headers`, `json`, `path`, `success?`.

```ruby
response = Docker::API::Image.create(fromImage: "busybox:latest")

response
=> #<Docker::API::Response:0x000055bb390b35c0 ... >

response.status
=> 200

response.data
=> {:body=>"...", :cookies=>[], :host=>nil, :headers=>{ ... }, :path=>"/images/create?fromImage=busybox:latest", :port=>nil, :status=>200, :status_line=>"HTTP/1.1 200 OK\r\n", :reason_phrase=>"OK"}

response.headers
=> {"Api-Version"=>"1.40", "Content-Type"=>"application/json", "Docker-Experimental"=>"false", "Ostype"=>"linux", "Server"=>"Docker/19.03.11 (linux)", "Date"=>"Mon, 29 Jun 2020 16:10:06 GMT"}

response.body
=> "{\"status\":\"Pulling from library/busybox\" ... "

response.json
=> [{:status=>"Pulling from library/busybox", :id=>"latest"}, {:status=>"Pulling fs layer", :progressDetail=>{}, :id=>"76df9210b28c"}, ... , {:status=>"Status: Downloaded newer image for busybox:latest"}]

response.path
=> "/images/create?fromImage=busybox:latest"

response.success?
=> true
```

### Error handling

`Docker::API::InvalidParameter` and `Docker::API::InvalidRequestBody` may be raised when an invalid option is passed as argument (ie: an option not described in Docker API documentation for request query parameters nor request body (json) parameters). Even if no errors were raised, consider validating the status code and/or message of the response to check if the Docker daemon has fulfilled the operation properly.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Road to 1.0.0

NS: Not Started

WIP: Work In Progress


| Class | Tests | Implementation | Refactoring |
|---|---|---|---|
| Container | Ok | Ok | NS |
| Image | Ok | Ok | NS |
| Volume | Ok | Ok | NS |
| Network | Ok | Ok | NS |
| System | Ok | Ok | NS |
| Exec | NS | NS | NS |
| Swarm | NS | NS | NS |
| Node | NS | NS | NS |
| Service | NS | NS | NS |
| Task | NS | NS | NS |
| Secret | NS | NS | NS |

Misc: 
* ~~Improve response object~~
* ~~Improve error objects~~

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nu12/dockerapi.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

