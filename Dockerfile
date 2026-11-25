# Deliberately unpinned: every build uses the latest rocker/shiny-verse image and
# installs the current release of each extra package below. Packages that ship
# in the base image stay at the versions it provides. Builds are not reproducible
# by design; see "Dockerfile Details" in README.md.
FROM rocker/shiny-verse

RUN install2.r \
    --error \
    --skipinstalled \
    thematic \
    quantmod \
    PerformanceAnalytics \
    ichimoku \
    prophet \
    patchwork \
    future \
    promises

RUN rm -rf /srv/shiny-server/*

COPY app.R /srv/shiny-server/app.R
