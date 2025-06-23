FROM rocker/shiny-verse

RUN usr/local/lib/R/site-library/littler/examples/update.r

RUN install2.r \
    --error \
    --skipinstalled \
    thematic \
    quantmod \
    PerformanceAnalytics \
    ichimoku \
    prophet \
    patchwork

RUN rm -rf /srv/shiny-server/*

COPY app.R /srv/shiny-server/app.R
