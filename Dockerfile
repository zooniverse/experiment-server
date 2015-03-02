FROM zooniverse/ruby:2.2.0

WORKDIR /app

ENV DEBIAN_FRONTEND noninteractive

ADD Gemfile ./
ADD Gemfile.lock ./

RUN apt-get install -y git
RUN apt-get update && apt-get -y upgrade && \
    bundle install

EXPOSE 80

ADD ./ ./

ENTRYPOINT [ "bundle", "exec", "ruby", "server.rb", "-p", "80", "-o", "0.0.0.0" ]
