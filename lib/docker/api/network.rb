module Docker
    module API        
        class Network < Docker::API::Base

            def base_path
                "/networks"
            end

            def inspect *args
                return super.inspect if args.size == 0
                name, params = args[0], args[1] || {}
                validate Docker::API::InvalidParameter, [:verbose, :scope], params
                @connection.get(build_path([name], params))
            end

            def list params = {}
                validate Docker::API::InvalidParameter, [:filters], params
                @connection.get(build_path("/networks", params))
            end

            def create body = {}
                validate Docker::API::InvalidRequestBody, [:Name, :CheckDuplicate, :Driver, :Internal, :Attachable, :Ingress, :IPAM, :EnableIPv6, :Options, :Labels], body
                @connection.request(method: :post, path: build_path(["create"]), headers: {"Content-Type": "application/json"}, body: body.to_json)
            end

            def remove name
                @connection.delete(build_path([name]))
            end

            def prune params = {}
                validate Docker::API::InvalidParameter, [:filters], params
                @connection.post(build_path(["prune"], params))
            end

            def connect name, body = {}
                validate Docker::API::InvalidRequestBody, [:Container, :EndpointConfig], body
                @connection.request(method: :post, path: build_path([name, "connect"]), headers: {"Content-Type": "application/json"}, body: body.to_json)
            end

            def disconnect name, body = {}
                validate Docker::API::InvalidRequestBody, [:Container, :Force], body
                @connection.request(method: :post, path: build_path([name, "disconnect"]), headers: {"Content-Type": "application/json"}, body: body.to_json)
            end

        end
    end
end