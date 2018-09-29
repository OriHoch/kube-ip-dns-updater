FROM alpine

RUN wget -qO kubectl https://storage.googleapis.com/kubernetes-release/release/$(wget -qO - https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl &&\
    chmod +x kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN apk --update --no-cache add bash python curl

COPY entrypoint.sh templater.sh /

ENTRYPOINT ["./entrypoint.sh"]
