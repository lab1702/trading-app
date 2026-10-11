# Deliberately unpinned: the image and all R packages track the latest releases
# on every build. Builds are not reproducible by design; see "Dockerfile Details"
# in README.md.
FROM rocker/shiny-verse

RUN /usr/local/lib/R/site-library/littler/examples/update.r

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
