FROM jekyll/jekyll

WORKDIR /tmp
ADD ./Gemfile .

# To cache all Gems 
RUN bundle install
RUN rm /tmp/Gemfile

WORKDIR /srv/jekyll

ENTRYPOINT [ "jekyll", "serve" ]