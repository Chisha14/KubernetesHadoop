FROM hash14/myhadoopbase


WORKDIR /usr/local/hadoop

ADD slaves etc/hadoop
ADD start.sh /
RUN chmod +x /start.sh

EXPOSE 8088 50070

ENTRYPOINT ["/start.sh"]
