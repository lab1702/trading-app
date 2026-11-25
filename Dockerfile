# Deliberately unpinned: every build uses the latest rocker/shiny image and
# installs the current release of each package below. Packages that ship in the
# base image stay at the versions it provides. Builds are not reproducible by
# design; see "Dockerfile Details" in README.md.
FROM rocker/shiny

# The packages app.R attaches with library(), in the same order. Keep the two
# lists in sync. --skipinstalled leaves the ones the base image already ships
# (shiny and its dependencies) untouched.
RUN install2.r \
    --error \
    --skipinstalled \
    ggplot2 \
    shiny \
    bslib \
    thematic \
    quantmod \
    xts \
    PerformanceAnalytics \
    ichimoku \
    prophet \
    TTR \
    patchwork \
    future \
    promises

RUN rm -rf /srv/shiny-server/*

COPY app.R /srv/shiny-server/app.R
