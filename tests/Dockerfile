FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       iverilog=12.0-2build2 yosys=0.33-5build2 yosys-abc=0.33-5build2 python3 openssl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /app /logs/verifier

WORKDIR /app
COPY . /tests/
RUN chmod 0755 /tests/test.sh
