RSpec.describe Docker::API::Image do
    image = "busybox:1.31.1-uclibc"

    after(:all) { described_class.prune(filters: {dangling: {"false": true}}) }

    describe "::create" do
        after(:each) { described_class.remove(image) }
        it { expect{described_class.create(invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
        context "from repository without authentication" do
            it { expect(described_class.create(fromImage: image).status).to eq(200) }
            it { expect(described_class.create(fromImage: "doesn-exist").status).to eq(404) }
        end
        context "from local tar file" do
            let(:path) { "resources/busybox.tar" }
            it { expect(described_class.create(fromSrc: path).status).to eq(200) }
            it { expect(described_class.create(fromSrc: path, repo: image, message: "Imported with dockerapi").status).to eq(200) }
        end
        context "from remote tar file" do
            let(:url) { "https://github.com/nu12/dockerapi/blob/master/resources/busybox.tar?raw=true" }
            it { expect(described_class.create(fromSrc: url).status).to eq(200) }
            it { expect(described_class.create(fromSrc: url, repo: image, message: "Imported with dockerapi").status).to eq(200) }
            it { expect(described_class.create(fromSrc: "http://404").status).to eq(500) }
        end
    end

    context "after ::create" do 
        before(:all) { described_class.create(fromImage: image) }

        describe "::list" do
            describe "status code" do
                it { expect(described_class.list.status).to eq(200) }
                it { expect(described_class.list(all: true).status).to eq(200) }
                it { expect(described_class.list(digests: true).status).to eq(200) }
                it { expect(described_class.list(all: true, digests: true).status).to eq(200) }
                it { expect(described_class.list(all: true, filters: {dangling: {"true": true}}).status).to eq(200) }
                it { expect(described_class.list(all: true, filters: {label: {"label-here": true}}).status).to eq(200) }
                it { expect(described_class.list(all: true, filters: {reference: {"#{image}": true}}).status).to eq(200) }
                it { expect(described_class.list(all: true, filters: {before: {"#{image}": true}}).status).to eq(200) }
                it { expect(described_class.list(all: true, filters: {since: {"#{image}": true}}).status).to eq(200) }
            end
            describe "request path" do
                it { expect(described_class.list(all: true).path).to eq("/images/json?all=true") }
                it { expect(described_class.list(digests: true).path).to eq("/images/json?digests=true") }
                it { expect(described_class.list(all: true, digests: true).path).to eq("/images/json?all=true&digests=true") }
                it { expect(described_class.list(all: true, filters: {dangling: {"true": true}}).path).to eq("/images/json?all=true&filters={\"dangling\":{\"true\":true}}") }
                it { expect(described_class.list(all: true, filters: {label: {"label-here": true}}).path).to eq("/images/json?all=true&filters={\"label\":{\"label-here\":true}}") }
                it { expect(described_class.list(all: true, filters: {reference: {"#{image}": true}}).path).to eq("/images/json?all=true&filters={\"reference\":{\"#{image}\":true}}") }
                it { expect(described_class.list(all: true, filters: {before: {"#{image}": true}}).path).to eq("/images/json?all=true&filters={\"before\":{\"#{image}\":true}}") }
                it { expect(described_class.list(all: true, filters: {since: {"#{image}": true}}).path).to eq("/images/json?all=true&filters={\"since\":{\"#{image}\":true}}") }
            end
            it { expect{described_class.list(invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
        end

        describe "::inspect" do
            it { expect(described_class.inspect(image).status).to eq(200) }
            it { expect(described_class.inspect("doesn-exist").status).to eq(404) }
            
        end
        describe "::history" do
            it { expect(described_class.history(image).status).to eq(200) }
            it { expect(described_class.history("doesn-exist").status).to eq(404) }
        end
        describe "::tag" do
            it { expect(described_class.tag(image).status).to eq(500) }
            it { expect(described_class.tag(image, repo: "dockerapi/tag:1").status).to eq(201) }
            it { expect(described_class.tag(image, repo: "dockerapi/tag", tag: "2").status).to eq(201) }
            it { expect(described_class.tag("doesn-exist", repo: "dockerapi/tag").status).to eq(404) }
            it { expect{described_class.tag(image, invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
            
        end

        describe "::push" do
            before(:all) do
                described_class.create(fromImage: "registry:2.7.1")
                Docker::API::Container.create(
                    {name: "registry"}, 
                    {Image: "registry:2.7.1",
                    HostConfig: {
                        Memory: 6000000,
                        PortBindings: {
                            "5000/tcp": [ {HostIp: "0.0.0.0", HostPort: "5000"} ]
                        }
                    }}
                )
                Docker::API::Container.start("registry")
                described_class.tag(image, repo: "localhost:5000/push:1")
            end
            after(:all) do
                Docker::API::Container.stop("registry")
                Docker::API::Container.remove("registry")
                described_class.remove("registry:2.7.1")
            end

            it { expect{described_class.push("localhost:5000/push:1", invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
            it { expect(described_class.push("localhost:5000/push:1").status).to be(200) }
            it { expect(described_class.push("localhost:5000/push", tag: "1").status).to be(200) }

            describe "returns status 200 with error message" do
                subject { described_class.push("localhost:5000/doesn-exist") }
                it { expect(subject.status).to be(200) }
                it { expect(subject.body).to match(/(An image does not exist locally with the tag)/) }
            end
        end

        describe "::commit" do
            container = "rspec-test"
            before(:all) { Docker::API::Container.create({name: container}, {Image: image}) }
            after(:all) { Docker::API::Container.remove(container) }
            it { expect(described_class.commit.status).to eq(301) }
            it { expect(described_class.commit(container: container).status).to eq(201) }
            it { expect(described_class.commit(container: container, repo: "dockerapi/#{container}:1" ).status).to eq(201) }
            it { expect(described_class.commit(container: container, repo: "dockerapi/#{container}", tag: "2" ).status).to eq(201) }
            it { expect(described_class.commit(container: container, repo: "dockerapi/#{container}", tag: "3", comment: "Comment from commit" ).status).to eq(201) }
            it { expect(described_class.commit(container: container, repo: "dockerapi/#{container}", tag: "4", author: "dockerapi" ).status).to eq(201) }
            it { expect(described_class.commit(container: container, repo: "dockerapi/#{container}", tag: "5", pause: false ).status).to eq(201) }
            it { expect(described_class.commit({container: container, repo: "dockerapi/#{container}:6"}, {OpenStdin: false, Cmd: "echo dockerapi", Entrypoint: [""]} ).status).to eq(201) }
            it { expect(described_class.commit(container: "doesn-exist").status).to eq(404) }
            it { expect{described_class.commit(invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
            it { expect{described_class.commit({invalid: "invalid"}, {invalid: "invalid"})}.to raise_error(Docker::API::InvalidParameter) }
            it { expect{described_class.commit({}, {invalid: "invalid"})}.to raise_error(Docker::API::InvalidRequestBody) }
        end
        
        describe "::export" do
            after(:all) { File.delete(File.expand_path("~/exported_image.tar")) }
            it { expect{File.open(File.expand_path("~/exported_image"))}.to raise_error(Errno::ENOENT) }
            it { expect(described_class.export(image, "~/exported_image.tar").status).to eq(200) }
            it { expect{File.open(File.expand_path("~/exported_image.tar"))}.not_to raise_error }
            it { expect(described_class.export("doesn-exist", "~/wont-exist.tar").status).to eq(404) }
            it { expect{File.open(File.expand_path("~/wont-exist.tar"))}.to raise_error(Errno::ENOENT) }
            

            context "having the exported image" do
                describe "::import" do
                    it { expect(described_class.import("~/exported_image.tar").status).to eq(200) }
                    it { expect(described_class.import("~/exported_image.tar", quiet: true).status).to eq(200) }
                    it { expect{described_class.import("~/exported_image.tar", invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
                end
            end
        end
    end
    
    describe "::search" do
        it { expect(described_class.search.status).to eq(200) }
        it { expect(described_class.search(term: "busybox").status).to eq(200) }
        it { expect(described_class.search(term: "busybox", limit: 2).status).to eq(200) }
        it { expect(described_class.search(term: "busybox", filters: {"is-automated": {"true": true}}).status).to eq(200) }
        it { expect(described_class.search(term: "busybox", filters: {"is-official": {"true": true}}).status).to eq(200) }
        it { expect(described_class.search(term: "busybox", filters: {stars: {"20": true}}).status).to eq(200) }
        it { expect{described_class.search(invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
    end
    
    describe "::remove" do
        before(:all)  { described_class.prune(filters: {dangling: {"false": true}}) }
        before(:each) { described_class.create(fromImage: image) }

        context "having a container" do
            before(:all)   { Docker::API::Container.create( {}, { Image: image }) }
            after(:all)   { Docker::API::Container.prune }

            it { expect(described_class.remove(image).status).to eq(409) }
            it { expect(described_class.remove(image, force: true).status).to eq(200) }    
        end
        it { expect(described_class.remove(image).status).to eq(200) }
        it { expect(described_class.remove("doesn-exist").status).to eq(404) }
        it { expect(described_class.remove(image, noprune: false).status).to eq(200) }
        it { expect(described_class.remove("doesn-exist", noprune: true).status).to eq(404) }
        it { expect{described_class.remove(image, invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
        it { expect{described_class.remove("doesn-exist", invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
    end

    describe "::prune" do        
        describe "status code" do
            it { expect(described_class.prune.status).to eq(200) }
            it { expect(described_class.prune(filters: {dangling: {"true": true}}).status).to eq(200) }
            it { expect(described_class.prune(filters: {dangling: {"1": true}}).status).to eq(200) }
            it { expect(described_class.prune(filters: {dangling: {"false": true}}).status).to eq(200) }
            it { expect(described_class.prune(filters: {until: {"10m": true}}).status).to eq(200) }
            it { expect(described_class.prune(filters: {label: {"LABEL": true}}).status).to eq(200) }
            it { expect(described_class.prune(filters: {label: {"LABEL": true}, dangling: {"1": true}}).status).to eq(200) }
        end
        describe "request path" do 
            it { expect(described_class.prune(filters: {dangling: {"true": true}}).path).to eq("/images/prune?filters={\"dangling\":{\"true\":true}}") }
            it { expect(described_class.prune(filters: {dangling: {"1": true}}).path).to eq("/images/prune?filters={\"dangling\":{\"1\":true}}") }
            it { expect(described_class.prune(filters: {until: {"10m": true}}).path).to eq("/images/prune?filters={\"until\":{\"10m\":true}}") }
            it { expect(described_class.prune(filters: {label: {"LABEL": true}}).path).to eq("/images/prune?filters={\"label\":{\"LABEL\":true}}") }
            it { expect(described_class.prune(filters: {label: {"LABEL": true}, dangling: {"1": true}}).path).to eq("/images/prune?filters={\"label\":{\"LABEL\":true},\"dangling\":{\"1\":true}}") }
        end
        it { expect{described_class.prune( invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
    end

    describe "::build" do
        it { expect(described_class.build("resources/build.tar.xz").status).to eq(200) }
        it { expect(described_class.build("resources/build.tar.xz", q: true).status).to eq(200) }
        it { expect(described_class.build("resources/build.tar.xz", q: true, rm: false).status).to eq(200) }
        it { expect(described_class.build("resources/build.tar.xz", memory: 4000000, rm: true, forcerm:true).status).to eq(200) }
        it { expect(described_class.build("resources/build.tar.xz", memory: 4000000, rm: true, forcerm:true, pull:true).status).to eq(200) }
        it { expect(described_class.build(nil, remote: "https://github.com/nu12/dockerapi/blob/master/resources/build.tar.xz?raw=true").status).to eq(200) }
        it { expect(described_class.build(nil, remote: "https://raw.githubusercontent.com/nu12/dockerapi/master/resources/Dockerfile").status).to eq(200) }
        it { expect{described_class.build("resources/build.tar.xz", invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
        it { expect{described_class.build(nil, remote: "https://github.com/nu12/dockerapi/blob/master/resources/build.tar.xz?raw=true", invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
        it { expect{described_class.build(nil, invalid: "invalid")}.to raise_error(Docker::API::Error) }
    end

    describe "::delete_cache" do
        it { expect(described_class.delete_cache.status).to eq(200) }
        it { expect(described_class.delete_cache(all:true, "keep-storage": 100000, filters: {until: {"24h": true}, inuse: {"true": true}, shared: {"true": true}}).status).to eq(200) }
        it { expect{described_class.delete_cache(invalid: "invalid")}.to raise_error(Docker::API::InvalidParameter) }
    end
    
end