.PHONY: build push deploy

all: build push deploy

build:
	docker-compose build

push:
	docker-compose push

deploy:
	docker stack deploy -c docker-stack.yml flexibee

clean:
	docker stack rm flexibee
