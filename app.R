library(ggplot2)
library(shiny)
library(bslib)
library(thematic)
library(quantmod)
library(xts)
library(PerformanceAnalytics)
library(ichimoku)
library(prophet)
library(TTR)
library(patchwork)
library(future)
library(promises)

# Suppress R CMD check notes for ggplot2 aesthetics
utils::globalVariables(c(
  "BB_lower", "BB_upper", "BB_mavg", "Low", "High", "Open", "Close",
  "Volume", "SMA20", "SMA50", "RSI", "MACD", "MACD_signal", "Date",
  "posn", "index"
))

# Configuration constants
CONFIG <- list(
  DATA_HISTORY_YEARS = 5,
  PROPHET_FORECAST_DAYS = 90, # calendar days; weekends are dropped from the forecast
  SYMBOL_MAX_LENGTH = 10,
  STRATEGY_LEVELS = c(1, 2, 3),
  STRATEGY_N = 1,
  # ichimoku() can segfault on shorter series; 52 + 26 periods covers the cloud
  MIN_ICHIMOKU_ROWS = 78,
  # Bars dated on or after today in this timezone are still forming and are dropped
  MARKET_TZ = "America/New_York",
  PROPHET_WORKERS = 2
)

# Completed Prophet fits, shared by all sessions in this R process
prophet_cache <- cachem::cache_mem(max_size = 200 * 1024^2)

# Prophet fits run in background R processes so one slow fit doesn't block
# every other session sharing this R process
plan(multisession, workers = CONFIG$PROPHET_WORKERS)

stock_syms <- tryCatch(
  {
    stockSymbols()
  },
  error = function(e) {
    data.frame(Symbol = character(0), Name = character(0))
  }
)

# Configure thematic for automatic ggplot2 theming
thematic_on(font = font_spec(scale = 1.5))

ui <- page_navbar(
  id = "nav",
  header = useBusyIndicators(),
  theme = bs_theme(preset = "bootstrap"),
  title = "lab1702's Trading Assistant",
  sidebar = sidebar(
    card(
      textInput(
        inputId = "stock",
        label = "Symbol:",
        placeholder = "Enter symbol..."
      )
    ),
    card(
      textOutput("info")
    ),
    card(
      card_title("DISCLAIMER"),
      markdown("*This app is purely for entertainment and does NOT constitute financial advice!*")
    )
  ),
  nav_spacer(),
  nav_panel(
    title = "Summary",
    card(
      fill = FALSE,
      card_title("Recommendations"),
      layout_columns(
        value_box(
          title = "Ichimoku Level 1 Strategy",
          value = textOutput("rec1"),
          subtitle = "Simple (s1)",
          theme = "primary",
          showcase = plotOutput("sc1"),
          showcase_layout = "bottom"
        ),
        value_box(
          title = "Ichimoku Level 2 Strategy",
          value = textOutput("rec2"),
          subtitle = "Complex (s1 & s2)",
          theme = "primary",
          showcase = plotOutput("sc2"),
          showcase_layout = "bottom"
        ),
        value_box(
          title = "Ichimoku Level 3 Strategy",
          value = textOutput("rec3"),
          subtitle = "Asymmetric (s1 x s2) [Experimental]",
          theme = "secondary",
          showcase = plotOutput("sc3"),
          showcase_layout = "bottom"
        )
      )
    ),
    card(
      card_title("Downloaded Data"),
      verbatimTextOutput("loaded", placeholder = TRUE),
      tableOutput("recent")
    )
  ),
  nav_panel(
    title = "Analysis Charts",
    navset_card_underline(
      nav_panel(
        title = "Candlestick",
        plotOutput("candle")
      ),
      nav_panel(
        title = "Strategy L1",
        plotOutput("cloud1")
      ),
      nav_panel(
        title = "Strategy L2",
        plotOutput("cloud2")
      ),
      nav_panel(
        title = "Strategy L3",
        plotOutput("cloud3")
      )
    )
  ),
  nav_panel(
    title = "Performance Charts",
    navset_card_underline(
      nav_panel(
        title = "Strategy L1",
        plotOutput("perf1")
      ),
      nav_panel(
        title = "Strategy L2",
        plotOutput("perf2")
      ),
      nav_panel(
        title = "Strategy L3",
        plotOutput("perf3")
      )
    )
  ),
  nav_panel(
    title = "Strategy Details",
    navset_card_underline(
      nav_panel(
        title = "Strategy L1",
        layout_columns(
          col_widths = c(5, 7),
          card(
            card_title("Strategy Summary"),
            verbatimTextOutput("summary1", placeholder = TRUE)
          ),
          card(
            card_title("Outperformance Report"),
            tableOutput("outperf1")
          )
        )
      ),
      nav_panel(
        title = "Strategy L2",
        layout_columns(
          col_widths = c(5, 7),
          card(
            card_title("Strategy Summary"),
            verbatimTextOutput("summary2", placeholder = TRUE)
          ),
          card(
            card_title("Outperformance Report"),
            tableOutput("outperf2")
          )
        )
      ),
      nav_panel(
        title = "Strategy L3",
        layout_columns(
          col_widths = c(5, 7),
          card(
            card_title("Strategy Summary"),
            verbatimTextOutput("summary3", placeholder = TRUE)
          ),
          card(
            card_title("Outperformance Report"),
            tableOutput("outperf3")
          )
        )
      )
    )
  ),
  nav_panel(
    title = "Prophet Forecast",
    navset_card_underline(
      nav_panel(
        title = "Forecast",
        plotOutput("prophet")
      ),
      nav_panel(
        title = "Decomposition",
        plotOutput("prophet_decomp")
      )
    )
  ),
  nav_spacer(),
  nav_item(
    input_dark_mode(id = "darkmode")
  )
)


# Log the full error server-side; users only see the friendly validate() message
log_error <- function(context, e) {
  message(sprintf("[%s] %s: %s", format(Sys.time()), context, conditionMessage(e)))
}

download_candles <- function(symbol) {
  from <- seq(Sys.Date(), length.out = 2, by = paste0("-", CONFIG$DATA_HISTORY_YEARS, " years"))[2]
  not_found <- FALSE

  d <- withCallingHandlers(
    tryCatch(
      getSymbols(Symbols = symbol, auto.assign = FALSE, from = from),
      error = function(e) {
        log_error(paste("download", symbol), e)
        NULL
      }
    ),
    # quantmod reports an unknown symbol as an HTTP 404 warning followed by a generic error
    warning = function(w) {
      if (grepl("404", conditionMessage(w))) not_found <<- TRUE
      invokeRestart("muffleWarning")
    }
  )

  validate(need(!is.null(d) || not_found, paste("Could not download data for", symbol, "- try again later")))
  validate(need(!is.null(d), paste("No data found for", symbol, "- check the spelling")))

  # quantmod prefixes columns with the ticker (e.g. "LOW.Open"), which confuses
  # ichimoku's name matching for tickers like LOW or HIGH
  colnames(d) <- c("Open", "High", "Low", "Close", "Volume", "Adjusted")

  # Drop rows Yahoo returns without prices (volume may legitimately be missing)
  d <- d[complete.cases(d[, -5]), ]

  # Drop today's still-forming bar so signals only use completed bars
  d <- d[as.Date(index(d)) < as.Date(Sys.time(), tz = CONFIG$MARKET_TZ), ]
  validate(need(nrow(d) >= 2, paste("Not enough price history for", symbol)))

  # Adjust OHLC for splits and dividends so returns and signals aren't distorted
  adjustOHLC(d, use.Adjusted = TRUE)
}

# Base plots need an explicit message; ggplot/validate outputs show it automatically
plot_message <- function(msg) {
  plot.new()
  text(0.5, 0.5, msg, cex = 1.2)
}

server <- function(input, output, session) {
  # Debounce stock input to prevent excessive API calls while typing
  stock_debounced <- reactive({
    input$stock
  }) |> debounce(1000) # 1 second delay

  symbol <- reactive({
    toupper(trimws(stock_debounced() %||% ""))
  })

  get_raw_data <- reactive({
    sym <- symbol()
    validate(need(nzchar(sym), "Enter a stock symbol"))
    validate(need(
      grepl("^[A-Z0-9.^=-]+$", sym) && nchar(sym) <= CONFIG$SYMBOL_MAX_LENGTH,
      "Invalid symbol. Use letters, numbers, and . - ^ = only."
    ))

    list(data = download_candles(sym), ticker = sym)
  })

  # Cache key tied to the downloaded data, so cached results refresh when new bars
  # arrive instead of living for the lifetime of the server process
  data_key <- reactive({
    x <- get_raw_data()
    list(x$ticker, end(x$data), as.numeric(xts::last(x$data)))
  })

  get_company_name <- reactive({
    d <- get_raw_data()

    if (nrow(stock_syms) == 0) {
      return(paste("Company name unavailable for", d$ticker))
    }

    # A symbol can be listed on several exchanges; take the first name
    company_name <- stock_syms$Name[toupper(stock_syms$Symbol) == d$ticker]
    company_name <- company_name[!is.na(company_name)][1]

    if (is.na(company_name)) {
      paste("Company name not found for", d$ticker)
    } else {
      company_name
    }
  })

  # Prophet fits run as an ExtendedTask in a background worker, so neither other
  # sessions nor this session's inputs wait on them. Only successful fits are
  # cached, so a transient failure is retried on the next visit to the tab.
  # ExtendedTask queues calls made while a fit is running, so a queued fit for a
  # symbol the user has since moved past (or one already cached) is skipped.
  wanted_prophet_key <- NULL
  prophet_task <- ExtendedTask$new(function(d, periods, ticker, key) {
    if (!identical(wanted_prophet_key, key) || prophet_cache$exists(key)) {
      return(promise_resolve(NULL))
    }

    future_promise(
      {
        m0 <- prophet::prophet(df = d, weekly.seasonality = FALSE, daily.seasonality = FALSE)
        d0 <- prophet::make_future_dataframe(m = m0, periods = periods)
        # Only forecast weekdays the symbol actually trades on (no weekends for
        # stocks, every day for crypto)
        d0 <- d0[as.POSIXlt(d0$ds)$wday %in% unique(as.POSIXlt(d$ds)$wday), , drop = FALSE]
        f0 <- predict(m0, d0)

        list(ticker = ticker, model = m0, data = d0, forecast = f0)
      },
      seed = TRUE
    ) |>
      then(function(res) {
        prophet_cache$set(key, res)
        res
      })
  })

  prophet_key <- reactive({
    rlang::hash(data_key())
  })
  prophet_task_key <- reactiveVal(NULL)

  # Start a fit when the forecast tab is open and the result isn't cached. A key
  # whose fit failed is retried the next time the tab is opened.
  observe({
    req(input$nav == "Prophet Forecast")
    key <- prophet_key()
    wanted_prophet_key <<- key
    req(!prophet_cache$exists(key))
    # The task status isn't key-specific: a fit for this key that was skipped while
    # queued also ends as "success", so restart whenever this key isn't in flight
    req(!identical(isolate(prophet_task_key()), key) || isolate(prophet_task$status()) != "running")

    x <- get_raw_data()
    prophet_task_key(key)
    prophet_task$invoke(
      d = data.frame(ds = index(x$data), y = as.numeric(Cl(x$data))),
      periods = CONFIG$PROPHET_FORECAST_DAYS,
      ticker = x$ticker,
      key = key
    )
  })

  get_prophet <- reactive({
    key <- prophet_key()
    status <- prophet_task$status()

    res <- prophet_cache$get(key)
    if (!cachem::is.key_missing(res)) {
      return(res)
    }

    if (status == "error" && identical(prophet_task_key(), key)) {
      log_error(paste("prophet", symbol()), tryCatch(prophet_task$result(), error = identity))
      validate(need(FALSE, paste("Forecast unavailable for", symbol())))
    }
    validate(need(FALSE, paste("Fitting forecast model for", symbol(), "...")))
  })

  get_ichimoku <- reactive({
    x <- get_raw_data()
    validate(need(
      nrow(x$data) >= CONFIG$MIN_ICHIMOKU_ROWS,
      paste("Not enough price history for Ichimoku analysis of", x$ticker)
    ))

    ichimoku(x = x$data, ticker = x$ticker)
  }) |> bindCache(data_key())

  # Positions held on each bar, ending with the next (not yet traded) bar, as a data
  # frame of dates and positions. Follows ichimoku::strat(): positions are taken
  # one bar after the signal. For asymmetric (level 3) strategies the entry
  # condition alone isn't the position: once entered, the position is held until
  # the exit condition (s2) turns true. strat()'s own posn column can't be used
  # for this because it drops a trailing position that has no exit yet, so the
  # entry/exit logic is replayed over the whole history.
  replay_positions <- function(s) {
    core <- coredata(s)
    end <- max(which(!is.na(core[, "close"])))
    cond <- as.numeric(core[, "cond"])
    posn <- rep(NA_real_, end + 1)

    rule <- strsplit(unlist(attr(s, "strat")["Strategy", 1]), " x ", fixed = TRUE)[[1]]
    if (length(rule) == 1) {
      posn[-1] <- cond[seq_len(end)]
      return(data.frame(index = index(s)[seq_len(end + 1)], posn = posn))
    }

    s2 <- strsplit(rule[2], " > ", fixed = TRUE)[[1]]
    p2 <- attr(s, "periods")[2L]
    offset2 <- (p2 - 1L) * ("chikou" %in% s2)
    s2cond <- as.numeric(c(rep(NA, offset2), (core[, s2[1]] > core[, s2[2]])[seq_len(nrow(core) - offset2)]))

    # Whether a signal position (one bar after its condition) turns on at bar t.
    # Like strat(), a position that is already on at its first defined bar counts.
    turns_on <- function(v, t) {
      isTRUE(v[t - 1] == 1) && (t < 3 || is.na(v[t - 2]) || v[t - 2] == 0)
    }

    # One step of strat()'s entry/exit loop: s1 entry when the s1 position turns on,
    # s2 exit when the s2 position turns on
    step <- function(prev, t) {
      if (prev == 1) as.numeric(!turns_on(s2cond, t)) else as.numeric(turns_on(cond, t))
    }

    # strat() defines the position wherever the s1 position is defined
    first <- which(!is.na(cond))[1]
    held <- 0
    for (t in seq(first + 1, end + 1)) {
      held <- step(held, t)
      posn[t] <- held
    }
    data.frame(index = index(s)[seq_len(end + 1)], posn = posn)
  }

  # Note: autostrat picks the best combination in-sample, on the same data it is
  # then evaluated on, so its results flatter the strategy
  create_best_strategy <- function(level) {
    strategy <- reactive({
      d <- get_ichimoku()

      s <- tryCatch(
        autostrat(
          x = d,
          n = CONFIG$STRATEGY_N,
          level = level,
          quietly = TRUE
        ),
        error = function(e) {
          log_error(paste0("strategy L", level, " ", symbol()), e)
          NULL
        }
      )
      validate(need(length(s) > 0, paste0("Strategy L", level, " unavailable for ", symbol())))
      s[[1]]
    }) |> bindCache(data_key(), level)
  }

  best_strategy <- lapply(CONFIG$STRATEGY_LEVELS, create_best_strategy)

  # Helper function to create ggplot candlestick chart; colors and fonts come from thematic
  create_candlestick_chart <- function(stock_data, ticker) {
    # Convert xts to data frame
    df <- data.frame(
      Date = index(stock_data),
      Open = as.numeric(stock_data[, 1]),
      High = as.numeric(stock_data[, 2]),
      Low = as.numeric(stock_data[, 3]),
      Close = as.numeric(stock_data[, 4]),
      Volume = as.numeric(stock_data[, 5])
    )
    n <- nrow(df)

    # Calculate technical indicators, leaving them empty when history is too short
    df$SMA20 <- if (n > 20) TTR::SMA(df$Close, n = 20) else NA_real_
    df$SMA50 <- if (n > 50) TTR::SMA(df$Close, n = 50) else NA_real_

    # Bollinger Bands
    if (n > 20) {
      bb <- TTR::BBands(df[, c("High", "Low", "Close")])
      df$BB_upper <- bb[, "up"]
      df$BB_lower <- bb[, "dn"]
      df$BB_mavg <- bb[, "mavg"]
    } else {
      df$BB_upper <- df$BB_lower <- df$BB_mavg <- NA_real_
    }

    # RSI
    df$RSI <- if (n > 14) TTR::RSI(df$Close) else NA_real_

    # MACD
    if (n > 35) {
      macd <- TTR::MACD(df$Close)
      df$MACD <- macd[, "macd"]
      df$MACD_signal <- macd[, "signal"]
    } else {
      df$MACD <- df$MACD_signal <- NA_real_
    }

    # Color for candles
    candle_color <- ifelse(df$Close >= df$Open, "#26a69a", "#ef5350")

    no_x_title <- theme(axis.title.x = element_blank())

    # Main candlestick chart
    p1 <- ggplot(df, aes(x = Date)) +
      # Bollinger Bands
      geom_ribbon(aes(ymin = BB_lower, ymax = BB_upper),
        alpha = 0.1, fill = "blue"
      ) +
      geom_line(aes(y = BB_upper), color = "blue", alpha = 0.6, linewidth = 0.5) +
      geom_line(aes(y = BB_lower), color = "blue", alpha = 0.6, linewidth = 0.5) +
      geom_line(aes(y = BB_mavg), color = "blue", alpha = 0.8, linewidth = 0.7) +

      # Candlesticks - wicks
      geom_segment(aes(x = Date, xend = Date, y = Low, yend = High),
        color = candle_color,
        linewidth = 0.5
      ) +

      # Candlesticks - bodies
      geom_segment(aes(x = Date, xend = Date, y = Open, yend = Close),
        color = candle_color,
        linewidth = 2
      ) +

      # Moving averages
      geom_line(aes(y = SMA20), color = "orange", linewidth = 0.8, alpha = 0.8) +
      geom_line(aes(y = SMA50), color = "purple", linewidth = 0.8, alpha = 0.8) +
      labs(
        title = paste(ticker, "- Candlestick Chart with Technical Indicators"),
        y = "Price ($)"
      ) +
      no_x_title +
      theme(plot.title = element_text(hjust = 0.5, face = "bold"))

    # Volume subplot
    p2 <- ggplot(df, aes(x = Date)) +
      geom_col(aes(y = Volume),
        fill = candle_color,
        alpha = 0.7, width = 0.8
      ) +
      labs(y = "Volume") +
      no_x_title

    # RSI subplot
    p3 <- ggplot(df, aes(x = Date)) +
      geom_line(aes(y = RSI), color = "cyan", linewidth = 0.8) +
      geom_hline(yintercept = 70, color = "red", linetype = "dashed", alpha = 0.7) +
      geom_hline(yintercept = 30, color = "green", linetype = "dashed", alpha = 0.7) +
      geom_hline(yintercept = 50, linetype = "dotted", alpha = 0.5) +
      labs(y = "RSI") +
      ylim(0, 100) +
      no_x_title

    # MACD subplot
    p4 <- ggplot(df, aes(x = Date)) +
      geom_line(aes(y = MACD), color = "blue", linewidth = 0.8) +
      geom_line(aes(y = MACD_signal), color = "red", linewidth = 0.8) +
      geom_hline(yintercept = 0, linetype = "dotted", alpha = 0.5) +
      labs(y = "MACD", x = "Date")

    # Combine plots
    p1 / p2 / p3 / p4 +
      plot_layout(heights = c(3, 1, 1, 1))
  }

  output$candle <- renderPlot({
    d <- get_raw_data()

    create_candlestick_chart(stock_data = d$data, ticker = d$ticker)
  })

  output$info <- renderText({
    get_company_name()
  })

  # Factory function for recommendation logic
  create_recommendation <- function(level) {
    renderText({
      position <- tail(replay_positions(best_strategy[[level]]())$posn, 1)
      if (length(position) == 0 || is.na(position)) {
        "NO DATA"
      } else if (position == 1) {
        "BUY / HOLD"
      } else {
        "SELL / WAIT"
      }
    })
  }

  output$rec1 <- create_recommendation(1)
  output$rec2 <- create_recommendation(2)
  output$rec3 <- create_recommendation(3)

  output$loaded <- renderPrint({
    str(get_raw_data()$data)
  })

  output$recent <- renderTable(
    {
      tail(get_raw_data()$data)
    },
    striped = TRUE,
    rownames = TRUE
  )

  # Factory function for showcase plots of the position held (not the entry
  # condition, which differs from the position for level 3)
  create_showcase_plot <- function(level) {
    renderPlot({
      replay_positions(best_strategy[[level]]()) |>
        ggplot(aes(x = index, y = posn)) +
        geom_line() +
        theme(
          axis.title = element_blank(),
          axis.text.y = element_blank()
        )
    })
  }

  output$sc1 <- create_showcase_plot(1)
  output$sc2 <- create_showcase_plot(2)
  output$sc3 <- create_showcase_plot(3)

  # Factory function for cloud plots
  create_cloud_plot <- function(level) {
    renderPlot({
      d <- best_strategy[[level]]()

      if (isTRUE(input$darkmode == "dark")) {
        plot(d, theme = "dark")
      } else {
        plot(d)
      }
    })
  }

  output$cloud1 <- create_cloud_plot(1)
  output$cloud2 <- create_cloud_plot(2)
  output$cloud3 <- create_cloud_plot(3)

  # Factory function for performance plots
  create_performance_plot <- function(level) {
    renderPlot({
      d <- best_strategy[[level]]()

      # Built from the parts of charts.PerformanceSummary(), whose ggplot2 engine
      # ignores the title
      tryCatch(
        {
          r <- d[, c("sret", "ret")]
          p_cum <- chart.CumReturns(
            r,
            main = "Cumulative Return", ylab = "Cumulative Return",
            legend.loc = "topleft", plot.engine = "ggplot2"
          )
          p_dd <- chart.Drawdown(r, main = "Drawdown", ylab = "Drawdown", plot.engine = "ggplot2")

          print(p_cum / p_dd +
            plot_annotation(title = paste("L", level, "Performance", attributes(d)$ticker)))
        },
        error = function(e) {
          log_error(paste0("performance L", level, " ", symbol()), e)
          plot_message(paste0("Performance chart L", level, " unavailable"))
        }
      )
    })
  }

  output$perf1 <- create_performance_plot(1)
  output$perf2 <- create_performance_plot(2)
  output$perf3 <- create_performance_plot(3)

  # Factory function for strategy summaries
  create_summary <- function(level) {
    renderPrint({
      # Evaluate first: S4 dispatch in summary() would wrap a validation error
      # in a generic error and show its raw text
      s <- best_strategy[[level]]()
      summary(s)
    })
  }

  # Factory function for outperformance tables
  create_outperformance <- function(level) {
    renderTable(
      {
        d <- best_strategy[[level]]()
        table.ProbOutPerformance(d$sret, d$ret)
      },
      striped = TRUE
    )
  }

  output$summary1 <- create_summary(1)
  output$summary2 <- create_summary(2)
  output$summary3 <- create_summary(3)

  output$outperf1 <- create_outperformance(1)
  output$outperf2 <- create_outperformance(2)
  output$outperf3 <- create_outperformance(3)

  output$prophet <- renderPlot({
    d <- get_prophet()

    plot(d$model, d$forecast) +
      add_changepoints_to_plot(m = d$model)
  })

  output$prophet_decomp <- renderPlot({
    d <- get_prophet()

    # Draws directly; return NULL so renderPlot doesn't print the plot list again
    prophet_plot_components(m = d$model, fcst = d$forecast)
    NULL
  })
}

shinyApp(ui = ui, server = server)
