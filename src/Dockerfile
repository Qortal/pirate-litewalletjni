FROM rust:1.60.0-slim-buster
RUN apt-get update && apt-get install -y tar unzip wget curl jq build-essential mingw-w64
RUN cd /opt && curl https://codeload.github.com/raspberrypi/tools/tar.gz/master | tar -xz --strip=2 tools-master/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf
RUN wget "https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz?revision=61c3be5d-5175-4db6-9030-b565aae9f766&la=en&hash=0A37024B42028A9616F56A51C2D20755C5EBBCD7" -O gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz && mkdir -p /opt/arm/9 && tar Jxf gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz -C /opt/arm/9
WORKDIR /build
