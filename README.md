# 📈 Trading Assistant - Financial Analysis Dashboard

A modern, interactive Shiny web application for comprehensive stock analysis using Ichimoku cloud strategies and Prophet forecasting.

[![R](https://img.shields.io/badge/R-4.0%2B-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-1.7%2B-green.svg)](https://shiny.rstudio.com/)
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
- **Decomposition Analysis** showing trend, seasonality, and holidays
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

# Method 2: Source the file
source("app.R")

# Method 3: Run in background
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
```

This provides:
- Pre-configured R environment with tidyverse
- Shiny server ready for production
- All required financial analysis packages

**Unpinned by design.** The base image tag and R package versions are intentionally
not pinned: every build uses the latest `rocker/shiny-verse` image and upgrades all
packages to current CRAN releases (`update.r`). This keeps the app on the latest
versions of R, Shiny, and the analysis packages without manual version bumps. The
trade-off is that builds are not reproducible and a new upstream release can break
a rebuild; if that happens, fix forward or temporarily pin the tag (e.g.
`rocker/shiny-verse:4.6.1`) until it is resolved. Please don't flag the lack of
pinning in code reviews.

Docker Compose also defines a healthcheck, so `docker ps` reports the container as unhealthy if Shiny Server stops responding.

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
  PROPHET_FORECAST_DAYS = 90,
  SYMBOL_MAX_LENGTH = 10,
  STRATEGY_LEVELS = c(1, 2, 3),
  STRATEGY_N = 1,
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
- Enter any valid Yahoo Finance ticker (e.g., `AAPL`, `BRK-B`, `^GSPC`, `EURUSD=X`)
- Symbols may contain letters, numbers, and `.` `-` `^` `=` (max 10 characters)
- Validation with helpful error messages (invalid format, unknown symbol, download failure)

### 2. Navigation Tabs

#### **Summary Tab**
- **Recommendations**: Buy/Hold/Sell signals for all strategy levels
- **Data Overview**: Raw OHLCV data structure and recent prices
- **Company Information**: Automatic company name lookup

#### **Analysis Charts Tab**
- **Candlestick**: Full technical analysis chart with indicators
- **Strategy L1/L2/L3**: Ichimoku cloud visualizations for each level

#### **Performance Charts Tab**
- **Strategy Performance**: Cumulative returns of the strategy vs. buy-and-hold
- **Period Returns and Drawdown**: Daily returns and drawdown from peak

#### **Strategy Details Tab**
- **Summary Statistics**: Detailed strategy performance metrics
- **Outperformance Reports**: Probability analysis vs benchmark

#### **Prophet Forecast Tab**
- **Forecast**: 90-calendar-day price predictions (trading days only) with confidence bands
- **Decomposition**: Trend, seasonal, and holiday components

### 3. Dark Mode Toggle
- Click the moon/sun icon in the top navigation
- Automatically adjusts all charts and UI components
- Preference persists during session

## 🔧 Technical Details

### Data Sources
- **Stock Data**: Yahoo Finance via `quantmod` package, last 5 years, adjusted for splits and dividends
- **Company Information**: NASDAQ symbol database
- **Technical Indicators**: Calculated using `TTR` package

### Ichimoku Strategy Levels

Each level uses `ichimoku::autostrat()`, which tests every combination of Ichimoku
conditions and picks the best-performing one. The specific conditions chosen
therefore vary by symbol.

| Level | Description | Signals Used | Complexity |
|-------|-------------|--------------|------------|
| L1 | Simple | s1 (one automatically selected condition) | Basic |
| L2 | Complex | s1 & s2 (two conditions combined) | Intermediate |
| L3 | Asymmetric | s1 × s2 (separate entry and exit conditions) | Advanced |

> **Note:** the best strategy is selected and evaluated on the same historical
> data (in-sample), so reported performance is optimistic and will usually
> look better than buy-and-hold. It is not an out-of-sample backtest.

### Technical Indicators

- **Bollinger Bands**: 20-period SMA ± 2 standard deviations
- **Moving Averages**: SMA20 (orange), SMA50 (purple)
- **RSI**: 14-period Relative Strength Index
- **MACD**: 12,26,9 Moving Average Convergence Divergence
- **Ichimoku Cloud**: Full Ichimoku Kinko Hyo system

### Performance Features

- **Reactive Caching**: Ichimoku, strategy, and Prophet results are cached across sessions, keyed on the downloaded data so they refresh when new prices arrive
- **Background Forecasting**: Prophet models are fitted in background R processes (`future`), so a slow fit doesn't block other users
- **Debounced Input**: Typing a symbol waits 1 second before downloading or recomputing anything
- **Error Handling**: Failures show a short message in the affected output; full error details are logged server-side

## ⚙️ Configuration

### Customization Options

The app has no environment-variable configuration. Edit the `CONFIG` object in `app.R`:

```r
CONFIG <- list(
  DATA_HISTORY_YEARS = 3,             # Years of price history to download
  PROPHET_FORECAST_DAYS = 60,         # Forecast horizon in calendar days
  SYMBOL_MAX_LENGTH = 15,             # Allow longer symbols
  STRATEGY_LEVELS = c(1, 2, 3),
  STRATEGY_N = 1,
  PROPHET_WORKERS = 2                 # Background processes for Prophet fits
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
```r
# Recommended security headers
options(
  shiny.sanitize.errors = TRUE,
  shiny.trace = FALSE,
  shiny.error = function() {
    "An error occurred. Please try again."
  }
)
```

## 📊 Performance Optimization

### Recommended Settings
```r
# For production deployment
options(
  shiny.maxRequestSize = 30*1024^2,  # 30MB upload limit
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