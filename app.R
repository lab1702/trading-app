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

# Suppress R CMD check notes for ggplot2 aesthetics
utils::globalVariables(c(
  "BB_lower", "BB_upper", "BB_mavg", "Low", "High", "Open", "Close",
  "Volume", "SMA20", "SMA50", "RSI", "MACD", "MACD_signal", "Date",
  "cond", "index"
))

# Configuration constants
CONFIG <- list(
  DATA_HISTORY_YEARS = "5 years",
  PROPHET_FORECAST_DAYS = 90,
  SYMBOL_MAX_LENGTH = 10,
  STRATEGY_LEVELS = c(1, 2, 3),
  STRATEGY_N = 1,
  NOTIFICATION_DURATION = list(
    ERROR = 5,
    WARNING = 3
  )
)

stock_syms <- tryCatch(
  {
    stockSymbols()
  },
  error = function(e) {
    data.frame(Symbol = character(0), Name = character(0))
  }
)


ui <- page_navbar(
  useBusyIndicators(),
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


server <- function(input, output, session) {
  thematic_on(font = font_spec(scale = 1.5))

  # Helper function to categorize and format error messages
  get_error_message <- function(context, level = NULL, error_obj = NULL) {
    # Check if no symbol is entered
    if (is.null(input$stock) || trimws(input$stock) == "") {
      return(list(
        type = "empty",
        message = "Enter a stock symbol",
        plot_message = "Enter a stock symbol to view chart"
      ))
    }

    # Check for data availability issues
    if (!is.null(error_obj) && grepl("No data available|symbol not found", error_obj$message, ignore.case = TRUE)) {
      return(list(
        type = "no_data",
        message = paste("No data found for", toupper(trimws(input$stock))),
        plot_message = paste("No data available for", toupper(trimws(input$stock)))
      ))
    }

    # Check for network/API errors
    if (!is.null(error_obj) && grepl("network|timeout|connection|HTTP", error_obj$message, ignore.case = TRUE)) {
      return(list(
        type = "network",
        message = "Network error - check internet connection",
        plot_message = "Network error - unable to fetch data"
      ))
    }

    # Strategy-specific errors
    if (context == "strategy" && !is.null(level)) {
      return(list(
        type = "strategy",
        message = paste("Strategy L", level, "calculation failed"),
        plot_message = paste("Strategy L", level, "data unavailable")
      ))
    }

    # Prophet-specific errors
    if (context == "prophet") {
      return(list(
        type = "forecast",
        message = "Forecast model failed - insufficient data",
        plot_message = "Forecast unavailable - need more data points"
      ))
    }

    # Generic error fallback
    return(list(
      type = "error",
      message = "Calculation error occurred",
      plot_message = "Error generating visualization"
    ))
  }

  download_candles <- function(x) {
    d <- tryCatch(
      {
        result <- getSymbols(Symbols = x, auto.assign = FALSE)
        if (is.null(result) || nrow(result) == 0) {
          stop("No data available for symbol: ", x)
        }
        result
      },
      error = function(e) {
        showNotification(
          paste("Error downloading data for", x, ":", e$message),
          type = "error",
          duration = CONFIG$NOTIFICATION_DURATION$ERROR
        )
        return(NULL)
      }
    )

    if (!is.null(d)) {
      xts::last(d, n = CONFIG$DATA_HISTORY_YEARS)
    } else {
      NULL
    }
  }

  get_stocks_data <- reactive({
    req(nchar(toupper(trimws(input$stock))) > 0)

    symbol <- toupper(trimws(input$stock))

    # Basic symbol validation
    if (!grepl("^[A-Z0-9.-]+$", symbol) || nchar(symbol) > CONFIG$SYMBOL_MAX_LENGTH) {
      showNotification(
        "Invalid symbol format. Use only letters, numbers, dots, and hyphens.",
        type = "warning",
        duration = CONFIG$NOTIFICATION_DURATION$WARNING
      )
      return(NULL)
    }

    download_candles(x = symbol)
  })

  get_raw_data <- reactive({
    req(d <- get_stocks_data())

    list(data = d, ticker = toupper(trimws(input$stock)))
  })

  get_company_name <- reactive({
    req(d <- get_raw_data())

    if (nrow(stock_syms) == 0) {
      return(paste("Company name unavailable for", d$ticker))
    }

    company_name <- stock_syms$Name[toupper(stock_syms$Symbol) == toupper(d$ticker)]

    if (length(company_name) == 0 || is.na(company_name)) {
      paste("Company name not found for", d$ticker)
    } else {
      company_name
    }
  })

  get_prophet <- reactive({
    req(x <- get_raw_data())

    d <- data.frame(
      ds = index(x$data),
      y = as.numeric(x$data[, 4])
    )

    tryCatch(
      {
        m0 <- prophet(df = d, weekly.seasonality = FALSE, daily.seasonality = FALSE)
        d0 <- make_future_dataframe(m = m0, periods = CONFIG$PROPHET_FORECAST_DAYS)
        f0 <- predict(m0, d0)

        list(ticker = x$ticker, model = m0, data = d0, forecast = f0)
      },
      error = function(e) {
        showNotification(
          paste("Error creating Prophet forecast:", e$message),
          type = "error",
          duration = CONFIG$NOTIFICATION_DURATION$ERROR
        )
        return(NULL)
      }
    )
  }) |> bindCache(input$stock)

  get_ichimoku <- reactive({
    req(x <- get_raw_data())

    ichimoku(x = x$data, ticker = x$ticker)
  }) |> bindCache(input$stock)

  # Factory function for creating strategy reactives
  create_strategy <- function(level) {
    reactive({
      req(d <- get_ichimoku())

      tryCatch(
        {
          autostrat(
            x = d,
            n = CONFIG$STRATEGY_N,
            level = level,
            quietly = TRUE
          )
        },
        error = function(e) {
          showNotification(
            paste("Error creating strategy L", level, ":", e$message),
            type = "error",
            duration = CONFIG$NOTIFICATION_DURATION$ERROR
          )
          return(NULL)
        }
      )
    }) |> bindCache(input$stock, level)
  }

  # Factory function for getting best strategy
  create_best_strategy <- function(level) {
    strategy_func <- create_strategy(level)
    reactive({
      req(s <- strategy_func())
      if (!is.null(s) && length(s) > 0) {
        s[[1]]
      } else {
        NULL
      }
    })
  }

  # Strategy reactives are created dynamically in factory functions
  # No need to pre-create them as they're called directly in outputs

  # Helper function to create ggplot candlestick chart
  create_candlestick_chart <- function(stock_data, ticker, dark_mode = FALSE) {
    # Convert xts to data frame
    df <- data.frame(
      Date = index(stock_data),
      Open = as.numeric(stock_data[, 1]),
      High = as.numeric(stock_data[, 2]),
      Low = as.numeric(stock_data[, 3]),
      Close = as.numeric(stock_data[, 4]),
      Volume = as.numeric(stock_data[, 5])
    )

    # Calculate technical indicators
    df$SMA20 <- TTR::SMA(df$Close, n = 20)
    df$SMA50 <- TTR::SMA(df$Close, n = 50)

    # Bollinger Bands
    bb <- TTR::BBands(df[, c("High", "Low", "Close")])
    df$BB_upper <- bb[, "up"]
    df$BB_lower <- bb[, "dn"]
    df$BB_mavg <- bb[, "mavg"]

    # RSI
    df$RSI <- TTR::RSI(df$Close)

    # MACD
    macd <- TTR::MACD(df$Close)
    df$MACD <- macd[, "macd"]
    df$MACD_signal <- macd[, "signal"]

    # Color for candles
    df$direction <- ifelse(df$Close >= df$Open, "up", "down")

    # Set theme colors
    if (dark_mode) {
      bg_color <- "#1e1e1e"
      text_color <- "white"
      grid_color <- "#404040"
      up_color <- "#00ff88"
      down_color <- "#ff4444"
    } else {
      bg_color <- "white"
      text_color <- "black"
      grid_color <- "#e0e0e0"
      up_color <- "#00aa44"
      down_color <- "#cc2222"
    }

    # Main candlestick chart
    p1 <- ggplot(df, aes(x = Date)) +
      # Bollinger Bands
      geom_ribbon(aes(ymin = BB_lower, ymax = BB_upper),
        alpha = 0.1, fill = "blue"
      ) +
      geom_line(aes(y = BB_upper), color = "blue", alpha = 0.6, size = 0.5) +
      geom_line(aes(y = BB_lower), color = "blue", alpha = 0.6, size = 0.5) +
      geom_line(aes(y = BB_mavg), color = "blue", alpha = 0.8, size = 0.7) +

      # Candlesticks - wicks
      geom_segment(aes(x = Date, xend = Date, y = Low, yend = High),
        color = ifelse(df$direction == "up", up_color, down_color),
        size = 0.5
      ) +

      # Candlesticks - bodies
      geom_segment(aes(x = Date, xend = Date, y = Open, yend = Close),
        color = ifelse(df$direction == "up", up_color, down_color),
        size = 2
      ) +

      # Moving averages
      geom_line(aes(y = SMA20), color = "orange", size = 0.8, alpha = 0.8) +
      geom_line(aes(y = SMA50), color = "purple", size = 0.8, alpha = 0.8) +
      labs(
        title = paste(ticker, "- Candlestick Chart with Technical Indicators"),
        y = "Price ($)"
      ) +
      theme_minimal() +
      theme(
        plot.background = element_rect(fill = bg_color, color = NA),
        panel.background = element_rect(fill = bg_color, color = NA),
        text = element_text(color = text_color, size = 14),
        axis.text = element_text(color = text_color, size = 12),
        axis.title = element_text(color = text_color, size = 14),
        panel.grid = element_line(color = grid_color, size = 0.3),
        plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
        axis.title.x = element_blank()
      )

    # Volume subplot
    p2 <- ggplot(df, aes(x = Date)) +
      geom_col(aes(y = Volume),
        fill = ifelse(df$direction == "up", up_color, down_color),
        alpha = 0.7, width = 0.8
      ) +
      labs(y = "Volume") +
      theme_minimal() +
      theme(
        plot.background = element_rect(fill = bg_color, color = NA),
        panel.background = element_rect(fill = bg_color, color = NA),
        text = element_text(color = text_color, size = 12),
        axis.text = element_text(color = text_color, size = 11),
        axis.title = element_text(color = text_color, size = 13),
        panel.grid = element_line(color = grid_color, size = 0.3),
        axis.title.x = element_blank()
      )

    # RSI subplot
    p3 <- ggplot(df, aes(x = Date)) +
      geom_line(aes(y = RSI), color = "cyan", size = 0.8) +
      geom_hline(yintercept = 70, color = "red", linetype = "dashed", alpha = 0.7) +
      geom_hline(yintercept = 30, color = "green", linetype = "dashed", alpha = 0.7) +
      geom_hline(yintercept = 50, color = text_color, linetype = "dotted", alpha = 0.5) +
      labs(y = "RSI") +
      ylim(0, 100) +
      theme_minimal() +
      theme(
        plot.background = element_rect(fill = bg_color, color = NA),
        panel.background = element_rect(fill = bg_color, color = NA),
        text = element_text(color = text_color, size = 12),
        axis.text = element_text(color = text_color, size = 11),
        axis.title = element_text(color = text_color, size = 13),
        panel.grid = element_line(color = grid_color, size = 0.3),
        axis.title.x = element_blank()
      )

    # MACD subplot
    p4 <- ggplot(df, aes(x = Date)) +
      geom_line(aes(y = MACD), color = "blue", size = 0.8) +
      geom_line(aes(y = MACD_signal), color = "red", size = 0.8) +
      geom_hline(yintercept = 0, color = text_color, linetype = "dotted", alpha = 0.5) +
      labs(y = "MACD", x = "Date") +
      theme_minimal() +
      theme(
        plot.background = element_rect(fill = bg_color, color = NA),
        panel.background = element_rect(fill = bg_color, color = NA),
        text = element_text(color = text_color, size = 12),
        axis.text = element_text(color = text_color, size = 11),
        axis.title = element_text(color = text_color, size = 13),
        panel.grid = element_line(color = grid_color, size = 0.3)
      )

    # Combine plots
    combined_plot <- p1 / p2 / p3 / p4 +
      plot_layout(heights = c(3, 1, 1, 1))

    return(combined_plot)
  }

  output$candle <- renderPlot({
    # Handle empty input
    if (is.null(input$stock) || trimws(input$stock) == "") {
      return(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = "Enter stock symbol to view chart", size = 6) +
          theme_void() +
          theme(
            plot.background = element_rect(fill = ifelse(input$darkmode == "dark", "#1e1e1e", "white"))
          )
      )
    }

    tryCatch(
      {
        req(d <- get_raw_data())

        create_candlestick_chart(
          stock_data = d$data,
          ticker = d$ticker,
          dark_mode = (input$darkmode == "dark")
        )
      },
      error = function(e) {
        error_info <- get_error_message("chart", NULL, e)

        bg_color <- ifelse(input$darkmode == "dark", "#1e1e1e", "white")
        text_color <- ifelse(input$darkmode == "dark", "white", "black")

        ggplot() +
          annotate("text",
            x = 0.5, y = 0.6, label = error_info$plot_message,
            size = 6, color = text_color
          ) +
          {
            if (error_info$type == "no_data") {
              annotate("text",
                x = 0.5, y = 0.4, label = "Check symbol spelling",
                size = 4, color = text_color
              )
            } else if (error_info$type == "network") {
              annotate("text",
                x = 0.5, y = 0.4, label = "Try again later",
                size = 4, color = text_color
              )
            }
          } +
          theme_void() +
          theme(
            plot.background = element_rect(fill = bg_color, color = NA)
          )
      }
    )
  })

  output$info <- renderText({
    req(cname <- get_company_name())

    cname
  })

  # Factory function for recommendation logic
  create_recommendation <- function(level) {
    best_strategy_func <- create_best_strategy(level)
    renderText({
      # Handle empty input first
      if (is.null(input$stock) || trimws(input$stock) == "") {
        return("Enter Symbol")
      }

      tryCatch(
        {
          req(d <- best_strategy_func())

          last_condition <- tail(d$cond[!is.na(d$close)], 1)
          if (length(last_condition) == 0 || is.na(last_condition)) {
            "NO DATA"
          } else {
            ifelse(
              as.numeric(last_condition) == 1,
              "BUY / HOLD",
              "SELL / WAIT"
            )
          }
        },
        error = function(e) {
          error_info <- get_error_message("strategy", level, e)
          switch(error_info$type,
            "no_data" = "SYMBOL NOT FOUND",
            "network" = "NETWORK ERROR",
            "strategy" = paste("L", level, "ERROR"),
            "ERROR"
          )
        }
      )
    })
  }

  output$rec1 <- create_recommendation(1)
  output$rec2 <- create_recommendation(2)
  output$rec3 <- create_recommendation(3)

  output$loaded <- renderPrint({
    req(d <- get_raw_data())

    str(d$data)
  })

  output$recent <- renderTable(
    {
      req(d <- get_raw_data())

      tail(d$data)
    },
    striped = TRUE,
    rownames = TRUE
  )

  # Factory function for showcase plots
  create_showcase_plot <- function(level) {
    best_strategy_func <- create_best_strategy(level)
    renderPlot({
      # Handle empty input
      if (is.null(input$stock) || trimws(input$stock) == "") {
        return(
          ggplot() +
            annotate("text", x = 0.5, y = 0.5, label = "Enter stock symbol", size = 4) +
            theme_void()
        )
      }

      tryCatch(
        {
          req(d <- best_strategy_func())
          df <- xts_df(d)

          df |>
            ggplot(aes(x = index, y = cond)) +
            geom_line() +
            theme(
              axis.title = element_blank(),
              axis.text.y = element_blank()
            )
        },
        error = function(e) {
          error_info <- get_error_message("strategy", level, e)
          ggplot() +
            annotate("text", x = 0.5, y = 0.5, label = error_info$plot_message, size = 4) +
            theme_void()
        }
      )
    })
  }

  output$sc1 <- create_showcase_plot(1)
  output$sc2 <- create_showcase_plot(2)
  output$sc3 <- create_showcase_plot(3)

  # Factory function for cloud plots
  create_cloud_plot <- function(level) {
    best_strategy_func <- create_best_strategy(level)
    renderPlot({
      # Handle empty input
      if (is.null(input$stock) || trimws(input$stock) == "") {
        plot.new()
        text(0.5, 0.5, "Enter stock symbol", cex = 1.5)
        return()
      }

      tryCatch(
        {
          req(d <- best_strategy_func())

          if (input$darkmode == "dark") {
            plot(d, theme = "dark")
          } else {
            plot(d)
          }
        },
        error = function(e) {
          error_info <- get_error_message("strategy", level, e)
          plot.new()
          text(0.5, 0.5, error_info$plot_message, cex = 1.2)
        }
      )
    })
  }

  output$cloud1 <- create_cloud_plot(1)
  output$cloud2 <- create_cloud_plot(2)
  output$cloud3 <- create_cloud_plot(3)

  # Factory function for performance plots
  create_performance_plot <- function(level) {
    best_strategy_func <- create_best_strategy(level)
    renderPlot({
      # Handle empty input
      if (is.null(input$stock) || trimws(input$stock) == "") {
        plot.new()
        text(0.5, 0.5, "Enter stock symbol", cex = 1.5)
        return()
      }

      tryCatch(
        {
          req(d <- best_strategy_func())

          charts.PerformanceSummary(
            d[, c("sret", "ret")],
            main = paste("L", level, "Performance", attributes(d)$ticker),
            plot.engine = "ggplot2"
          )
        },
        error = function(e) {
          error_info <- get_error_message("strategy", level, e)
          plot.new()
          text(0.5, 0.5, error_info$plot_message, cex = 1.1)
        }
      )
    })
  }

  output$perf1 <- create_performance_plot(1)
  output$perf2 <- create_performance_plot(2)
  output$perf3 <- create_performance_plot(3)

  # Factory function for strategy summaries
  create_summary <- function(level) {
    best_strategy_func <- create_best_strategy(level)
    renderPrint({
      # Handle empty input
      if (is.null(input$stock) || trimws(input$stock) == "") {
        cat("Enter a stock symbol to view strategy L", level, "summary\n")
        return()
      }

      tryCatch(
        {
          req(d <- best_strategy_func())
          summary(d)
        },
        error = function(e) {
          error_info <- get_error_message("strategy", level, e)
          switch(error_info$type,
            "no_data" = cat("Symbol not found - check spelling\n"),
            "network" = cat("Network error - check internet connection\n"),
            "strategy" = cat("Strategy L", level, "calculation failed - insufficient data\n"),
            cat("Error: Summary unavailable for strategy L", level, "\n")
          )
        }
      )
    })
  }

  # Factory function for outperformance tables
  create_outperformance <- function(level) {
    best_strategy_func <- create_best_strategy(level)
    renderTable(
      {
        # Handle empty input
        if (is.null(input$stock) || trimws(input$stock) == "") {
          return(data.frame(Message = "Enter stock symbol"))
        }

        tryCatch(
          {
            req(d <- best_strategy_func())
            table.ProbOutPerformance(d$sret, d$ret)
          },
          error = function(e) {
            error_info <- get_error_message("strategy", level, e)
            switch(error_info$type,
              "no_data" = data.frame(Error = "Symbol not found"),
              "network" = data.frame(Error = "Network error"),
              "strategy" = data.frame(Error = paste("L", level, "calculation failed")),
              data.frame(Error = "Data unavailable")
            )
          }
        )
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
    # Handle empty input
    if (is.null(input$stock) || trimws(input$stock) == "") {
      return(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = "Enter stock symbol for forecast", size = 5) +
          theme_void()
      )
    }

    tryCatch(
      {
        req(d <- get_prophet())

        plot(d$model, d$forecast) +
          add_changepoints_to_plot(m = d$model)
      },
      error = function(e) {
        error_info <- get_error_message("prophet", NULL, e)
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = error_info$plot_message, size = 4) +
          {
            if (error_info$type == "no_data") {
              annotate("text", x = 0.5, y = 0.4, label = "Symbol not found", size = 3)
            } else if (error_info$type == "network") {
              annotate("text", x = 0.5, y = 0.4, label = "Check connection", size = 3)
            } else {
              annotate("text", x = 0.5, y = 0.4, label = "Need more data points", size = 3)
            }
          } +
          theme_void()
      }
    )
  })

  output$prophet_decomp <- renderPlot({
    # Handle empty input
    if (is.null(input$stock) || trimws(input$stock) == "") {
      return(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = "Enter stock symbol for decomposition", size = 5) +
          theme_void()
      )
    }

    tryCatch(
      {
        req(d <- get_prophet())

        prophet_plot_components(m = d$model, fcst = d$forecast)
      },
      error = function(e) {
        error_info <- get_error_message("prophet", NULL, e)
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = error_info$plot_message, size = 4) +
          {
            if (error_info$type == "no_data") {
              annotate("text", x = 0.5, y = 0.4, label = "Symbol not found", size = 3)
            } else if (error_info$type == "network") {
              annotate("text", x = 0.5, y = 0.4, label = "Check connection", size = 3)
            } else {
              annotate("text", x = 0.5, y = 0.4, label = "Insufficient data", size = 3)
            }
          } +
          theme_void()
      }
    )
  })
}

shinyApp(ui = ui, server = server)
