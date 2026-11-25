# 📈 Trading Assistant - Financial Analysis Dashboard

A modern, interactive Shiny web application for comprehensive stock analysis using Ichimoku cloud strategies and Prophet forecasting.

[![R](https://img.shields.io/badge/R-4.4%2B-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-1.9.0%2B-green.svg)](https://shiny.rstudio.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🌟 Features

### 📊 Interactive Charts
- **Candlestick Charts** with technical indicators (Bollinger Bands, SMA20/50)
- **Volume Analysis** with color-coded directional bars
- **RSI Oscillator** with overbought/oversold levels
- **MACD Analysis** with signal lines and crossovers

### 🔮 Trading Strategies
- **Level 1**: Simple Ichimoku signals (s1)
- **Level 2**: Complex signals combining s1 & s2
- **Level 3**: Asymmetric signals using s1 × s2 (experimental)

### 🧠 AI-Powered Forecasting
- **Prophet Time Series Model** for price predictions
- **Decomposition Analysis** showing trend and yearly seasonality
- **90-day Forward Projections** with confidence intervals

### 🎨 Modern UI/UX
- **Dark/Light Mode** support with automatic theme switching
- **Responsive Design** optimized for desktop and mobile
- **Real-time Error Handling** with contextual user feedback
- **Loading Indicators** for better user experience

## 🚀 Quick Start

### Option 1: Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/lab1702/trading-app
cd trading-app

# Start with Docker Compose
docker-compose up --build
```

The application will be available at `http://localhost:8001`

### Option 2: Local R Installation

#### Prerequisites

```r
# Install required R packages
install.packages(c(
  "shiny", "bslib", "thematic", "ggplot2",
  "quantmod", "xts", "PerformanceAnalytics", 
  "ichimoku", "prophet", "TTR", "patchwork",
  "future", "promises"
))
```

#### Running the Application

```r
# Clone or download the repository
# Navigate to the project directory

# Method 1: Run directly
shiny::runApp()

# Method 2: Run the app file by path
shiny::runApp("app.R")

# Method 3: Run on a fixed port
shiny::runApp(launch.browser = TRUE, port = 3838)
```

### Docker Deployment

#### Using Docker Compose (Recommended)

```bash
# Build and run the application
docker-compose up --build

# Run in detached mode
docker-compose up -d

# Stop the application
docker-compose down
```

The application will be available at `http://localhost:8001`

#### Manual Docker Build

```bash
# Build the Docker image
docker build -t trading-app .

# Run the container (same port as Docker Compose)
docker run -p 8001:3838 trading-app
```

#### Dockerfile Details

The application uses a single-stage Docker setup based on `rocker/shiny-verse`:

```dockerfile
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
```

This provides:
- Pre-configured R environment with tidyverse
- Shiny server ready for production
- All required financial analysis packages

**Unpinned by design.** The base image tag and R package versions are intentionally
not pinned: every build uses the latest `rocker/shiny-verse` image and installs the
current release of each additional package. Packages that ship in the base image
(R, Shiny, the tidyverse) stay at the versions it provides and move forward when
`rocker/shiny-verse` is rebuilt upstream. They are not upgraded during the build:
littler's `update.r` can replace littler itself with a prebuilt binary whose `r`
cannot load the image's `libR.so`, which breaks `install2.r`. The
trade-off is that builds are not reproducible and a new upstream release can break
a rebuild; if that happens, fix forward or temporarily pin the tag (e.g.
`rocker/shiny-verse:4.6.1`) until it is resolved. Please don't flag the lack of
pinning in code reviews.

Docker Compose also defines a healthcheck, so `docker ps` reports the container as unhealthy if Shiny Server stops accepting connections. It only opens a TCP connection to port 3838 rather than requesting the app, because each app request would start an R process that Shiny Server stops again once idle.

## 📚 Application Structure

### Core Components

```
trading-app/
├── app.R                 # Main application file
├── Dockerfile           # Docker container configuration
├── docker-compose.yml   # Docker Compose orchestration
├── LICENSE              # MIT license
└── README.md            # This documentation
```

### Architecture Overview

```r
# Configuration Management
CONFIG <- list(
  DATA_HISTORY_YEARS = 5,
  DATA_REFRESH_MINUTES = 30,
  DOWNLOAD_TIMEOUT_SECS = 15,
  PROPHET_FORECAST_DAYS = 90,
  SYMBOL_MAX_LENGTH = 20,
  SYMBOL_LIST_RETRY_MINUTES = 10,
  MIN_ICHIMOKU_ROWS = 104,
  MIN_RELIABLE_STRATEGY_ROWS = 130,
  PROPHET_WORKERS = 2
)

# Factory Pattern Implementation
create_best_strategy(level)      # Strategy generation (one per level, shared by outputs)
create_recommendation(level)     # Buy/sell signals
create_showcase_plot(level)      # Mini trend charts
create_candlestick_chart()       # Main chart visualization
```

## 🎯 Usage Guide

### 1. Stock Symbol Input
- Enter any valid Yahoo Finance ticker (e.g., `AAPL`, `BRK-B`, `^GSPC`, `EURUSD=X`, `M&M.NS`)
- Symbols may contain letters, numbers, and `.` `-` `^` `=` `&` `_` (max 20 characters)
- Validation with helpful error messages (invalid characters, too long, unknown symbol, download failure)

### 2. Navigation Tabs

#### **Summary Tab**
- **Recommendations**: a BUY, HOLD, SELL, or WAIT call for each strategy level, with the date of the last daily bar they are based on, how long the position has been held or been out, and a notice when the last bar changed the rule the call comes from
- **Data Overview**: Structure of the downloaded OHLCV data and recent prices
- **Company Information**: Automatic company name lookup

#### **Analysis Charts Tab**
- **Candlestick**: Full technical analysis chart with indicators
- **Strategy L1/L2/L3**: Ichimoku cloud visualizations for each level

#### **Performance Charts Tab**
- **Strategy Performance**: Cumulative returns of the strategy vs. buy-and-hold
- **Drawdown**: Decline of the strategy and buy-and-hold from their previous peaks

#### **Strategy Details Tab**
- **Summary Statistics**: Detailed strategy performance metrics
- **Outperformance Reports**: Probability analysis vs benchmark

#### **Prophet Forecast Tab**
- **Forecast**: 90-calendar-day price predictions (only on weekdays the symbol trades, judged from its latest 60 bars) with confidence bands
- **Decomposition**: Trend and yearly seasonality components

### 3. Dark Mode Toggle
- Click the moon/sun icon in the top navigation
- Automatically adjusts all charts and UI components
- Preference persists during session

## 🔧 Technical Details

### Data Sources
- **Stock Data**: Yahoo Finance chart API, last 5 years, adjusted for splits and dividends. Each daily bar is dated by its exchange's local calendar
- **Dividend Adjustment**: the app adjusts the prices itself, from the dividends Yahoo lists, by scaling every bar before an ex-dividend date by `1 - dividend / previous close`. Yahoo's own adjusted close is not used: it differs slightly on every request, which made the same symbol give different strategies from one download to the next. For a few symbols the app's adjusted prices differ from Yahoo's (London listings, where Yahoo's adjusted close barely reflects the dividends)
- **Automatic Refresh**: an open session downloads its symbol again every 30 minutes, so the recommendation follows new bars. If such a refresh fails, the data already shown stays
- **Completed Bars Only**: today's still-forming bar (by the exchange's local date) is dropped, along with the live quote bar Yahoo adds for a session that is still open, so signals don't flip intraday. A day's bar is used from the next calendar day on the exchange's calendar, once Yahoo has published its closing price (for some markets that takes hours after the close)
- **Minimum History**: Ichimoku strategies need at least 104 daily bars; newer listings show a "not enough history" message. Up to about 130 bars a strategy level may find no combination with any trades, which also shows a "not enough history" message
- **Company Information**: NASDAQ symbol database, downloaded in the background when the app starts (names show as unavailable until it has arrived; a failed download is retried every 10 minutes)
- **Technical Indicators**: Calculated using `TTR` package

### Ichimoku Strategy Levels

Each level tests every combination of Ichimoku conditions and picks the
best-performing one, so the conditions chosen vary by symbol. L1 and L2 use
`ichimoku::autostrat()`; the app ranks the L3 combinations itself (see below).
Combinations are compared over the bars where every condition is defined, while
the statistics of the chosen strategy cover all bars where its own conditions
are defined.

| Level | Description | Signals Used | Complexity |
|-------|-------------|--------------|------------|
| L1 | Simple | s1 (one automatically selected condition) | Basic |
| L2 | Complex | s1 & s2 (two conditions combined) | Intermediate |
| L3 | Asymmetric | s1 × s2 (separate entry and exit conditions) | Advanced |

The recommendation compares the position the strategy holds for the next bar
with the one it held on the last completed bar:

| Call | Last bar | Next bar | Meaning |
|------|----------|----------|---------|
| BUY | out | in | New signal: enter at the next open |
| HOLD | in | in | Already in: stay in |
| SELL | in | out | New signal: exit at the next open |
| WAIT | out | out | Already out: stay out |

The next open is the open of the bar after the last completed one, the price the
strategy statistics also trade at. For L3 the position follows the entry/exit
logic (enter when s1 turns true, hold until s2 turns true), not just the current
s1 condition.

Under the call, the box describes the position through the last completed bar:
the bar at whose open it was entered or exited, the number of completed bars
since then and, for a position that is held, its return from that open to the
last close (`In since 2026-11-16 (6 bars): -3.7%`, `Out since 2026-11-17 (5 bars)`).
With a BUY that is the time spent out before the entry, with a SELL the trade
that is about to be closed.

Both positions are those of the combination that ranks best on the current data.
A new bar can change which combination that is, so from one day to the next the
call can go from WAIT to HOLD, or from HOLD to WAIT, without a BUY or SELL in
between. To show when that happens, the app searches once more without the last
bar. If another combination ranked best then, the box says that the rule changed
with the last bar, and names the new rule, the rule before it and the call that
rule gave.
That search uses today's download without its last bar, which starts a day later
than the download of the day before, so in rare cases it can differ from what
the app showed then.

When the second condition of an L2 combination involves the chikou span,
`ichimoku` builds the strategy with that condition one bar later than in the
ranking it chose the combination by. The app removes the extra bar, so the L2
recommendation, charts, and statistics are those of the combination as ranked.

`ichimoku` leaves a still-open L3 position out of its positions, returns, and
summary for as long as the exit condition has stayed true since the entry. The
app adds that position back, so the L3 charts and statistics show the same
position as the recommendation.

`ichimoku`'s own L3 ranking takes every position one bar before it can be
traded, which favors combinations that only do well with that head start. The
app therefore ranks the same L3 combinations on the positions described above,
including a still-open one.

> **Note:** the best strategy is selected and evaluated on the same historical
> data (in-sample), so reported performance is optimistic and will usually
> look better than buy-and-hold. It is not an out-of-sample backtest.

### Technical Indicators

- **Bollinger Bands**: 20-period SMA ± 2 standard deviations
- **Moving Averages**: SMA20 (orange), SMA50 (purple)
- **RSI**: 14-period Relative Strength Index
- **MACD**: 12,26,9 Moving Average Convergence Divergence
- **Ichimoku Cloud**: Full Ichimoku Kinko Hyo system. The projected part of the cloud is dated on Monday-Friday, or on every day for symbols that also trade on weekends (crypto); for markets with a Sunday-Thursday week those future dates are off by a day or two

### Performance Features

- **Reactive Caching**: Ichimoku, strategy, previous-bar rule, outperformance report, and Prophet results are cached across sessions, keyed on the downloaded data so they refresh when new prices arrive
- **Background Forecasting**: Prophet models are fitted in background R processes (`ExtendedTask` + `future`) only when the forecast tab is open, so a slow fit doesn't block other users or the rest of the app. Successful fits are cached; failed fits are retried the next time the tab is opened or the data is refreshed
- **Download Timeout**: a price download gives up after 15 seconds, because it holds up every session while it runs
- **Debounced Input**: Typing a symbol waits 1 second before downloading or recomputing anything
- **Error Handling**: Failures show a short message in the affected output; full error details are logged server-side

## ⚙️ Configuration

### Customization Options

The app has no environment-variable configuration. Edit the `CONFIG` object in `app.R`:

```r
CONFIG <- list(
  DATA_HISTORY_YEARS = 3,             # Years of price history to download
  DATA_REFRESH_MINUTES = 15,          # How often an open session downloads its symbol again
  DOWNLOAD_TIMEOUT_SECS = 15,         # Give up on a price download after this long
  PROPHET_FORECAST_DAYS = 60,         # Forecast horizon in calendar days
  SYMBOL_MAX_LENGTH = 30,             # Allow longer symbols
  SYMBOL_LIST_RETRY_MINUTES = 10,     # Wait before retrying a failed company name download
  MIN_ICHIMOKU_ROWS = 104,            # Minimum daily bars for Ichimoku analysis
  MIN_RELIABLE_STRATEGY_ROWS = 130,   # Below this, a failed strategy search means short history
  PROPHET_WORKERS = 2                 # Background processes (Prophet fits, company name download)
)
```

## 🐛 Troubleshooting

### Common Issues

**1. Package Installation Errors**
```r
# For Ubuntu/Debian systems
sudo apt-get install libssl-dev libcurl4-openssl-dev libxml2-dev

# Then reinstall packages
install.packages(c("quantmod", "prophet"))
```

**2. Prophet Installation Issues**
The R `prophet` package uses Stan (`rstan`/`StanHeaders`), not Python, and needs a C++ toolchain when built from source.
```r
# Windows: install Rtools matching your R version, then
install.packages("prophet")

# Linux: install a compiler toolchain first, e.g. sudo apt-get install build-essential
# macOS: install the Xcode command line tools (xcode-select --install)
```

**3. Stock Symbol Not Found**
- Verify symbol exists on Yahoo Finance
- Try alternative tickers (e.g., `GOOGL` vs `GOOG`)
- Check for recent delistings or symbol changes

**4. Network/API Errors**
- Check internet connection
- Verify Yahoo Finance API accessibility
- Consider proxy settings if behind corporate firewall

### Debug Mode

```r
# Enable verbose logging
options(shiny.trace = TRUE)
runApp()

# Check reactive dependencies
library(reactlog)
reactlog_enable()
runApp()
```

## 🔒 Security Considerations

### Input Validation
- Stock symbols validated with regex patterns
- Maximum length limits enforced
- XSS protection through Shiny's built-in escaping

### Data Privacy
- No user data stored permanently
- All calculations run server-side in R; the browser only displays results
- The server makes outbound requests to Yahoo Finance (prices) and NASDAQ (symbol list) for public market data

### Production Deployment
- The app shows its own short error messages and logs full error details to stderr (the Shiny Server log in Docker)
- Shiny Server sanitizes any other error messages by default (`sanitize_errors` in `shiny-server.conf`); when running with `shiny::runApp()`, set `options(shiny.sanitize.errors = TRUE)`

## 📊 Performance Optimization

### Recommended Settings
```r
# For production deployment
options(
  shiny.reactlog = FALSE,            # Disable in production
  repos = c(CRAN = "https://cran.rstudio.com/")
)
```

### Scaling Considerations
- Use `shiny-server` or `RStudio Connect` for multiple users
- Consider `shinyproxy` for containerized deployment
- Implement connection pooling for high-traffic scenarios

## 🤝 Contributing

### Development Setup
```bash
git clone https://github.com/lab1702/trading-app
cd trading-app
R -e "install.packages(c('shiny', 'devtools', 'testthat'))"
```

### Code Style
- Follow `tidyverse` style guide
- Use `styler` package for formatting
- Run `lintr` for code quality checks

### Pull Request Process
1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open Pull Request with description

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

**IMPORTANT**: This application is for educational and entertainment purposes only. It does NOT constitute financial advice, investment recommendations, or trading signals. Always conduct your own research and consult with qualified financial advisors before making investment decisions.

- Past performance does not guarantee future results
- All investments carry risk of loss
- Trading strategies may not be suitable for all investors
- Market conditions can change rapidly

## 🙏 Acknowledgments

### R Packages
- **Shiny**: RStudio team for the amazing web framework
- **Prophet**: Facebook's Core Data Science team
- **Ichimoku**: `ichimoku` package authors
- **Quantmod**: Jeffrey Ryan and Joshua Ulrich
- **ggplot2**: Hadley Wickham and the tidyverse team

### Data Sources
- **Yahoo Finance**: Historical stock price data
- **NASDAQ**: Company symbol and name database

### Inspiration
Built with ❤️ for the R and quantitative finance communities.

---

**Happy Trading! 📈📊🚀**

For questions, issues, or contributions, please visit the [project repository](https://github.com/lab1702/trading-app).