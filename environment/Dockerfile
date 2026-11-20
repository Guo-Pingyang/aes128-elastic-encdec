FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       iverilog=12.0-2build2 yosys=0.33-5build2 yosys-abc=0.33-5build2 python3 openssl patch \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY aes128.sv smoke.sv check.sh /app/
RUN chmod 0755 /app/check.sh
