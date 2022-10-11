
# https://docs.docker.com/engine/reference/builder/
# sudo docker compose build --progress=plain
# sudo docker compose up

FROM postgres:latest

LABEL version="0.1"
LABEL description="Crestfall"

ENV LD_LIBRARY_PATH="/usr/local/lib:${PATH}"

RUN apt update
RUN apt install curl git postgresql-server-dev-14 libcurl4-openssl-dev make g++ -y

# https://github.com/pramsey/pgsql-http
RUN curl -L https://github.com/pramsey/pgsql-http/archive/refs/tags/v1.5.0.tar.gz > ./pgsql-http.tar.gz && \
    tar xzvf ./pgsql-http.tar.gz && \
    cd ./pgsql-http-1.5.0/ && \
    make && \
    make install

# https://github.com/citusdata/pg_cron
RUN curl -L https://github.com/citusdata/pg_cron/archive/refs/tags/v1.4.2.tar.gz > ./pg_cron.tar.gz && \
    tar xzvf ./pg_cron.tar.gz && \
    cd ./pg_cron-1.4.2/ && \
    make && \
    make install

# TODO: https://github.com/michelp/pgjwt
# TODO: https://github.com/supabase/postgres/blob/develop/ansible/tasks/postgres-extensions/06-pgjwt.yml
RUN git clone https://github.com/michelp/pgjwt.git && \
    cd ./pgjwt/ && \
    make install

# TODO: https://github.com/michelp/pgsodium
# TODO: https://github.com/supabase/postgres/blob/develop/ansible/tasks/postgres-extensions/18-pgsodium.yml
# https://doc.libsodium.org/installation
# https://download.libsodium.org/libsodium/releases/
RUN curl -L https://download.libsodium.org/libsodium/releases/LATEST.tar.gz > ./libsodium.tar.gz && \
    tar xzvf ./libsodium.tar.gz && \
    cd ./libsodium-stable/ && \
    ./configure && \
    make check && \
    make install
RUN git clone https://github.com/michelp/pgsodium.git && \
    cd ./pgsodium/ && \
    make && \
    make install
COPY ./scripts/postgresql/pgsodium/pgsodium_getkey_urandom.sh ./pgsodium_getkey_urandom.sh
RUN cp ./pgsodium_getkey_urandom.sh `pg_config --sharedir`/extension/pgsodium_getkey
RUN chmod +x `pg_config --sharedir`/extension/pgsodium_getkey
RUN chown postgres:postgres `pg_config --sharedir`/extension/pgsodium_getkey
# RUN echo $(cat ./pgsodium_getkey_urandom.sh)
# RUN echo $(ls -l ./pgsodium_getkey_urandom.sh)
# RUN echo $(./pgsodium_getkey_urandom.sh)
# -c pgsodium.getkey_script=./pgsodium_getkey_urandom.sh
# TODO: https://github.com/pgaudit/pgaudit

# TODO: https://github.com/pgbouncer/pgbouncer

# TODO: https://github.com/citusdata/citus

# RUN apt remove postgresql-server-dev-14 libcurl4-openssl-dev make g++ -y
# RUN apt autoremove --purge -y && apt clean && apt purge