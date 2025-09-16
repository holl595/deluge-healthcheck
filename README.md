This is a healthcheck that will re-start deluge if it looses connectivity when using it behind a VPN container such as gluetun.

If you have changed the default password for Deluge, it will need to be updated on line 3 of healthcheck.sh

The **healthcheck.sh** should be placed inside the config directory of Deluge, and the healthcheck defined for the container

```
  deluge:
    network_mode: "service:gluetun"
    image: lscr.io/linuxserver/deluge:latest
    container_name: deluge
    environment:
      - PUID=297536
      - PGID=297536
      - TZ=Europe/London
    volumes:
      - /path/to/config/deluge:/config
    depends_on:
      - gluetun
    restart: always
    healthcheck:
      test: ["CMD", "./config/healthcheck.sh"]
      interval: 5m
      start_period: 5s
```
