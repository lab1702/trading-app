FROM rocker/shiny-verse

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
