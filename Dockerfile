FROM ruby:2.5.1

WORKDIR /usr/src/app

COPY Gemfile* ./
RUN bundle install --without development test

COPY . .

CMD ["./bin/worker"]

# docker build -t my-ruby-app .
# docker run -it --name my-running-script my-ruby-app
