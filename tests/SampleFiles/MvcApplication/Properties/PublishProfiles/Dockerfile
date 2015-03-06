FROM {{DockerBaseImageName}}

MAINTAINER {{ShouldNotBeReplaced}} - {{DockerBaseImageName}}

ADD . /k

WORKDIR /k/approot/src/{{ProjectName}}

ENTRYPOINT ["k", "Kestrel", "--server.urls", "http://localhost:{{DockerPublishContainerPort}}"]