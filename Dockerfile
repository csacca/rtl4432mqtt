# Docker file to create an image for a hass.io add-on that contains enough software to listen to events via RTL_SDR/RTL_433 and then publish them to a MQTT broker.
# The script resides in a volume and can be modified to meet your needs.
# This hass.io addon is based on Chris Kacerguis' project here: https://github.com/chriskacerguis/honeywell2mqtt,
# which is in turn based on Marco Verleun's rtl2mqtt image here: https://github.com/roflmao/rtl2mqtt

# IMPORTANT: The container needs privileged access to /dev/bus/usb on the host.

ARG BUILD_FROM=hassioaddons/base:6.0.1
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

ENV LANG C.UTF-8

LABEL \
  io.hass.name="rtl_443 to MQTT" \
  io.hass.description="Configurable rtl_443 to MQTT gateway and control panel." \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="addon" \
  io.hass.version=${BUILD_VERSION} \
  maintainer="Christopher Sacca <csacca@addons.community>"

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

#
# First install software packages needed to compile rtl_433 and to publish MQTT events
#
# hadolint ignore=DL3018
RUN \
  apk add --no-cache --virtual .build-dependencies \
  build-base \
  alpine-sdk \
  cmake \
  git \
  libusb-dev

# hadolint ignore=DL3018
RUN \
  apk add --no-cache \
  libusb \
  mosquitto-clients \
  jq

WORKDIR /tmp/src
RUN git clone git://git.osmocom.org/rtl-sdr.git

WORKDIR /tmp/src/rtl-sdr/build
RUN \
  cmake ../ \
  -DINSTALL_UDEV_RULES=ON \
  -DDETACH_KERNEL_DRIVER=ON \
  -DCMAKE_INSTALL_PREFIX:PATH=/usr/local
RUN make
RUN make install
RUN chmod +s /usr/local/bin/rtl_*

WORKDIR /tmp/src
RUN git clone https://github.com/merbanan/rtl_433

WORKDIR /tmp/src/rtl_433/build
RUN cmake ../
RUN make
RUN make install

WORKDIR /
RUN apk del --no-cache .build-dependencies
RUN rm -r /tmp/src

#
# Define an environment variables
#
# Use this variable when creating a container to specify the MQTT broker host.
ENV MQTT_HOST="hassio.local"
ENV MQTT_USER="guest"
ENV MQTT_PASS="guest"
ENV MQTT_TOPIC="homeassistant/rtl433"

COPY rtl4432mqtt.sh /
RUN chmod +x /rtl4432mqtt.sh
CMD ["/rtl4432mqtt.sh"]