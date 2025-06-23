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
  "ichimoku", "prophet", "TTR", "patchwork"
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

# Run the container
docker run -p 3838:3838 trading-app
```

#### Dockerfile Details

The application uses a multi-stage Docker setup based on `rocker/shiny-verse`:

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
    patchwork

RUN rm -rf /srv/shiny-server/*

COPY app.R /srv/shiny-server/app.R
```

This provides:
- Pre-configured R environment with tidyverse
- Shiny server ready for production
- All required financial analysis packages
- Optimized for containerized deployment

## 📚 Application Structure

### Core Components

```
trading-assistant/
├── app.R                 # Main application file
├── Dockerfile           # Docker container configuration
├── docker-compose.yml   # Docker Compose orchestration
└── README.md            # This documentation
```

### Architecture Overview

```r
# Configuration Management
CONFIG <- list(
  DATA_HISTORY_YEARS = "5 years",
  PROPHET_FORECAST_DAYS = 90,
  SYMBOL_MAX_LENGTH = 10,
  STRATEGY_LEVELS = c(1, 2, 3)
)

# Factory Pattern Implementation
create_strategy(level)           # Strategy generation
create_recommendation(level)     # Buy/sell signals
create_showcase_plot(level)     # Mini trend charts
create_candlestick_chart()      # Main chart visualization
```

## 🎯 Usage Guide

### 1. Stock Symbol Input
- Enter any valid stock ticker (e.g., `AAPL`, `GOOGL`, `TSLA`)
- Supports NASDAQ and major exchanges
- Real-time validation with helpful error messages

### 2. Navigation Tabs

#### **Summary Tab**
- **Recommendations**: Buy/Hold/Sell signals for all strategy levels
- **Data Overview**: Raw OHLCV data structure and recent prices
- **Company Information**: Automatic company name lookup

#### **Analysis Charts Tab**
- **Candlestick**: Full technical analysis chart with indicators
- **Strategy L1/L2/L3**: Ichimoku cloud visualizations for each level

#### **Performance Charts Tab**
- **Strategy Performance**: Comparative returns analysis
- **Risk Metrics**: Sharpe ratio, maximum drawdown, volatility

#### **Strategy Details Tab**
- **Summary Statistics**: Detailed strategy performance metrics
- **Outperformance Reports**: Probability analysis vs benchmark

#### **Prophet Forecast Tab**
- **Forecast**: 90-day price predictions with confidence bands
- **Decomposition**: Trend, seasonal, and holiday components

### 3. Dark Mode Toggle
- Click the moon/sun icon in the top navigation
- Automatically adjusts all charts and UI components
- Preference persists during session

## 🔧 Technical Details

### Data Sources
- **Stock Data**: Yahoo Finance via `quantmod` package
- **Company Information**: NASDAQ symbol database
- **Technical Indicators**: Calculated using `TTR` package

### Ichimoku Strategy Levels

| Level | Description | Signals Used | Complexity |
|-------|-------------|--------------|------------|
| L1 | Simple | s1 (Tenkan-Kijun cross) | Basic |
| L2 | Complex | s1 & s2 (Cloud position) | Intermediate |
| L3 | Asymmetric | s1 × s2 (Combined) | Advanced |

### Technical Indicators

- **Bollinger Bands**: 20-period SMA ± 2 standard deviations
- **Moving Averages**: SMA20 (orange), SMA50 (purple)
- **RSI**: 14-period Relative Strength Index
- **MACD**: 12,26,9 Moving Average Convergence Divergence
- **Ichimoku Cloud**: Full Ichimoku Kinko Hyo system

### Performance Features

- **Reactive Caching**: Expensive calculations cached automatically
- **Error Boundaries**: Graceful handling of API failures
- **Input Validation**: Real-time symbol format checking
- **Memory Optimization**: Efficient data structures and garbage collection

## ⚙️ Configuration

### Environment Variables

```r
# Optional: Set custom configuration
Sys.setenv(
  TRADING_CACHE_SIZE = "100MB",
  TRADING_DEBUG = "FALSE",
  TRADING_TIMEOUT = "30"
)
```

### Customization Options

```r
# Modify CONFIG object in app.R
CONFIG <- list(
  DATA_HISTORY_YEARS = "3 years",     # Adjust data history
  PROPHET_FORECAST_DAYS = 60,         # Change forecast horizon
  SYMBOL_MAX_LENGTH = 15,             # Allow longer symbols
  NOTIFICATION_DURATION = list(       # Adjust notification timing
    ERROR = 10,
    WARNING = 5
  )
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
```r
# Prophet requires Python backend
install.packages("prophet")

# If issues persist, try:
Sys.setenv(RETICULATE_PYTHON = "/usr/bin/python3")
install.packages("prophet")
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
- All calculations performed client-side
- External API calls limited to public market data

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