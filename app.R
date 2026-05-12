# ========================== APP OVERVIEW ==========================
# This Shiny dashboard summarizes enrollment patterns in the 
# International Low Grade Glioma Registry:
#   - Enrollment trends over time
#   - Age and diagnosis distributions
#   - U.S. participant map (final cumulative counts)

# -------------------------- DATA CLEANING --------------------------
# The dataset includes U.S. and international participants. 
# Key cleaning steps:
#   1. **ZIP / Postal codes**  
#      - Keep raw ZIP as character (supports international formats).  
#      - For U.S.–style ZIPs (digits + optional "-"):  
#         * Strip ZIP+4, extract digits, left-pad to 5 digits → zip5  
#         * Invalid values (e.g., "00000") set to NA  
#      - U.S. ZIP→state mapping done only for valid zip5 values;  
#        international participants are kept but excluded from the U.S. map.

#   2. **Dates & Age**  
#      - Convert DOB and enrollment date to Date type.  
#      - Keep only enrollment dates between 2000–2025.  
#      - Compute age: interval(dob, date_of_enroll) / years(1).  
#      - Exclude impossible ages (<0 or >100).


# -------------------------- UI / SERVER ----------------------------
# UI uses 3 rows:  
#   (1) Time slider + total participants  
#   (2) Age histogram + diagnosis pie chart  
#   (3) U.S. enrollment map (final cumulative)

# Server:  
#   - Reactively filters by selected year  
#   - Generates summary counts and plots  
#   - U.S. map uses discrete bins (0, 1–10, 11–50, 51–200, 200+)
# ====================================================================

# ---- Load Required packages ----
library(shiny)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(ggplot2)
library(plotly)
library(zipcodeR)
library(maps)

# ==========================DATA LAYER===============================
# Main functions:               
#  - Read & clean data
#  - Derive age groups, diagnosis labels
#  - Clean zipcode -> 5-digit ZIP -> US state (for US participants)
#  - Keep international participants for overall stats
#  - Prepare helper functions and values for Shiny

## ---- 1. Read raw data & basic ZIP processing ----
raw_glioma <- read_excel(
  "Glioma_BIS679A_2025.xls",
  col_types = c("date", "text", "numeric", "date")
) %>% 
  rename(
    dob            = "Date of Birth (MM/DD/YYYY)",
    zipcode        = "Zip Code",
    diagnosis      = "Pathology (1=astrocytoma, 2=mixed, 3=oligodendroglioma, 4=gbm, 5=glioma nos, 6=meningioma, 7=DNET, 8=pilocytic astrocytoma, 9=ependymoma, 10=lymphoma, 11=ganglioglioma, 12=hypercellular)",
    date_of_enroll = "Date of Enrollment"
  ) %>%
  mutate(
    # Keep original ZIP/postal code as character (for international formats)
    zipcode_raw = as.character(zipcode),
    
    # For ZIP codes that look like US-style (digits and optional "-"),
    # try to derive a 5-digit ZIP; for clearly non-US formats (letters, etc.),
    # leave zip5 as NA so they are kept in the data but excluded from US map.
    zip_main = if_else(
      str_detect(zipcode_raw, "^[0-9\\-]+$"),
      sub("-.*$", "", zipcode_raw),        # remove ZIP+4 part if present
      NA_character_                        # non-US formats -> NA here
    ),
    
    # Extract digits only from zip_main (if it exists)
    zipcode_digits = if_else(
      !is.na(zip_main),
      str_extract(zip_main, "\\d+"),
      NA_character_
    ),
    
    # Pad to 5 digits for US ZIP codes
    zip5 = if_else(
      !is.na(zipcode_digits),
      str_pad(zipcode_digits, width = 5, side = "left", pad = "0"),
      NA_character_
    ),
    
    # Treat "00000" as invalid
    zip5 = if_else(zip5 == "00000", NA_character_, zip5)
  )
# Note: At this point, international / non-US participants are still kept.
#       Only US-like ZIPs will have a non-NA zip5.

## ---- 2. Basic cleaning and derived variables ----
glioma <- raw_glioma %>% 
  # Convert dates to Date class
  mutate(
    dob            = as.Date(dob),
    date_of_enroll = as.Date(date_of_enroll)
  ) %>% 
  
  # Keep only reasonable enrollment dates (non-missing and not after 2025-12-01)
  filter(
    !is.na(date_of_enroll),
    date_of_enroll <= as.Date("2025-12-01"),
    date_of_enroll >= as.Date("2000-01-01")
  ) %>%
  
  # Compute age at enrollment (in years)
  mutate(
    age = as.numeric(interval(dob, date_of_enroll) / years(1))
  ) %>%
  
  # Remove unreasonable ages
  filter(
    !is.na(age),
    age >= 0,
    age <= 100
  ) %>%
  
  # Derive year, age group, and clean diagnosis
  mutate(
    # Enrollment year for time-based filtering (slider)
    enroll_year = year(date_of_enroll),
    
    # 10-year age groups for histogram
    age_group_10 = cut(
      age,
      breaks = seq(0, 100, by = 10),
      include.lowest = TRUE,
      right = FALSE
    ),
    
    # Clean diagnosis: set diagnosis > 12 to NA (invalid codes)
    diagnosis_clean = if_else(
      !is.na(diagnosis) & diagnosis > 12,
      NA_real_,
      diagnosis
    ),
    
    # Diagnosis label:
    # 1,2,3 as named; NA -> Unknown; other valid codes (4–12) -> Other
    diagnosis_label = case_when(
      diagnosis_clean == 1 ~ "Astrocytoma",
      diagnosis_clean == 2 ~ "Mixed glioma",
      diagnosis_clean == 3 ~ "Oligodendroglioma",
      is.na(diagnosis_clean) ~ "Unknown",
      TRUE ~ "Other"
    )
  ) %>%
    select(
    -zipcode_digits,
    -zip_main,
    -diagnosis_clean
  )

## ---- 3. US state mapping (for US participants only) ----

# Get unique non-missing US-like ZIPs from glioma
unique_zips <- unique(na.omit(glioma$zip5))

# Look up ZIP info (US only) using zipcodeR
zip_info <- suppressMessages(
  reverse_zipcode(unique_zips)
)

# Join state back to main glioma data
glioma <- glioma %>%
  left_join(
    zip_info %>% select(zipcode, state),
    by = c("zip5" = "zipcode")
  )

# Separate dataset for US-only participants (for the state-level map)
glioma_us <- glioma %>%
  filter(!is.na(state))

## ---- 4. Available years for time control ----
available_years <- glioma %>% 
  pull(enroll_year) %>% 
  unique() %>% 
  sort()

# Year range for UI controls
min_year <- min(available_years, na.rm = TRUE)
max_year <- max(available_years, na.rm = TRUE)

## ---- 5. Aggregation helper functions ----

# (1) Return data up to a given year-end (Dec 31 of that year) - ALL participants
get_data_upto_year <- function(year){
  cutoff_date <- as.Date(paste0(year, "-12-31"))
  glioma %>% 
    filter(date_of_enroll <= cutoff_date)
}

# (2) Total number of participants up to that year (ALL participants)
get_total_participants <- function(year){
  get_data_upto_year(year) %>% 
    summarise(n_total = n()) %>% 
    pull(n_total)
}

# (3) Age histogram data (10-year age groups) up to that year (ALL participants)
get_age_hist_data <- function(year){
  get_data_upto_year(year) %>% 
    filter(!is.na(age_group_10)) %>% 
    count(age_group_10, name = "n")
}

# (4) Diagnosis pie chart data up to that year (ALL participants)
get_dx_pie_data <- function(year){
  get_data_upto_year(year) %>% 
    count(diagnosis_label, name = "n")
}

# (5) State-level counts for the FINAL time point (US participants only)
state_counts_final <- glioma_us %>% 
  count(state, name = "n_participants")

state_counts_final_full <- tibble(state = state.abb) %>%
  left_join(state_counts_final, by = "state") %>%
  mutate(
    n_participants = replace_na(n_participants, 0)
  )

state_counts_final_full <- state_counts_final_full %>%
  mutate(
    # Enrollment bins
    enroll_bin = cut(
      n_participants,
      breaks = c(-Inf, 0, 10, 50, 200, Inf),
      labels = c("0", "1–10", "11–50", "51–200", "200+"),
      right = TRUE
    ),
    bin_id = as.numeric(enroll_bin)
  )

# ==========================UI LAYER===============================

ui <- fluidPage(
  
  titlePanel("International Low Grade Glioma Registry Dashboard"),
  hr(),
  
  # ---------- Row 1: controls + total participants ----------
  fluidRow(
    column(
      width = 8,
      wellPanel(
        h4("Enrollment Over Time"),
        sliderInput(
          inputId = "year",
          label   = "View data up to year (Dec 31):",
          min     = min_year,
          max     = max_year,
          value   = max_year,
          step    = 1,
          sep     = ""
        )
      )
    ),
    column(
      width = 4,
      wellPanel(
        h4("Total Participants"),
        h2(textOutput("total_participants")),
        helpText("Cumulative up to selected year (U.S. and international).")
      )
    )
  ),
  
  # ---------- Row 2: Age histogram + Diagnosis pie ----------
  fluidRow(
    column(
      width = 6,
      wellPanel(
        h4("Age Distribution (10-year groups)"),
        plotOutput("age_histogram", height = "280px")
      )
    ),
    column(
      width = 6,
      wellPanel(
        h4("Diagnosis Distribution"),
        plotlyOutput("diagnosis_pie", height = "280px")
      )
    )
  ),
  
  # ---------- Row 3: US map ----------
  fluidRow(
    column(
      width = 12,
      wellPanel(
        h4("U.S. Participants by State (Overall)"),
        plotlyOutput("state_map", height = "400px"),
        helpText(
          "Hover over a state to see the number of enrolled participants. ",
          "Map is not affected by the year selection above."
        )
      )
    )
  )
)

# ==========================SERVER LAYER===============================

server <- function(input, output, session){
  
  # ---- total participants ----
  output$total_participants <- renderText({
    n <- get_total_participants(input$year)
    format(n, big.mark = ",")
  })
  
  # ---- age histogram ----
  output$age_histogram <- renderPlot({
    
    df_age <- get_age_hist_data(input$year)
    
    full_groups <- levels(glioma$age_group_10)
    
    df_age <- df_age %>%
      mutate(age_group_10 = factor(age_group_10, levels = full_groups)) %>%
      complete(age_group_10, fill = list(n = 0))
    
    ggplot(df_age, aes(x = age_group_10, y = n)) +
      geom_col(fill = "#468faf") +
      #theme_minimal() +
      labs(
        title = "Age at Enrollment",
        x = "Age Group (years)",
        y = "Number of Participants"
      ) +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 11),
        axis.text.y = element_text(size = 11),
        axis.title  = element_text(size = 13, face = "bold"),
        plot.title  = element_text(size = 14, face = "bold"),
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA)
      )
  }, bg = "transparent")
  
  # ---- diagnosis pie chart ----
  output$diagnosis_pie <- renderPlotly({
    df_dx <- get_dx_pie_data(input$year) 
    diagnosis_colors <- c(
      "Astrocytoma"        = "#468faf",  
      "Mixed glioma"       = "#4fb3a5",  
      "Oligodendroglioma"  = "#90d5cc",  
      "Other"              = "#bfc8cf",  
      "Unknown"            = "#7d8b99"   
    )
    
    # ensure the label order is fixed
    df_dx$diagnosis_label <- factor(
      df_dx$diagnosis_label,
      levels = names(diagnosis_colors)
    )
    
    plot_ly(
      data = df_dx,
      labels = ~diagnosis_label,
      values = ~n,
      type = "pie",
      textinfo = "percent",
      marker = list(colors = diagnosis_colors[levels(df_dx$diagnosis_label)]),
      hovertemplate = paste(
        "%{label}<br>",
        "N = %{value}<br>",
        "Percent = %{percent}<br>",
        "<extra></extra>"
      )
    ) %>% 
      layout(
        showlegend = TRUE,
        paper_bgcolor = 'rgba(0,0,0,0)',
        plot_bgcolor  = 'rgba(0,0,0,0)',
        legend = list(orientation = "v")
      )
  })
    
  # ---- US state map ----
  
  output$state_map <- renderPlotly({
    
    df <- state_counts_final_full
    
    plot_ly(
      data = df,
      type = "choropleth",
      locations = ~state,
      locationmode = "USA-states",
      z = ~bin_id,
      text = ~paste0(
        "<b>", state, "</b><br>",
        n_participants, " participants"
      ),
      hoverinfo = "text",
      
      # 5-level colorscale: light blue → blue → light orange → orange → deep orange
      colorscale = list(
        list(0.00, "#f0f4ff"),  # 0
        list(0.25, "#bdd7e7"),  # 1–10
        list(0.50, "#6baed6"),  # 11–50
        list(0.75, "#fdae6b"),  # 51–200
        list(1.00, "#e6550d")   # 200+
      ),
      zmin = 1,
      zmax = 5,
      
      marker = list(
        line = list(color = "black", width = 1.2)
      ),
      colorbar = list(
        title = "Enrollment",
        tickmode = "array",
        tickvals = c(1, 2, 3, 4, 5),
        ticktext = c(
          "0 Enrollment",
          "1–10 Enrollment",
          "11–50 Enrollment",
          "51–200 Enrollment",
          "200+ Enrollment"
        )
      )
    ) %>%
      layout(
        geo = list(
          scope      = "usa",
          projection = list(type = "albers usa"),
          showlakes  = TRUE,
          lakecolor  = "rgba(0,0,0,0)",
          showland   = TRUE,
          landcolor  = "rgba(0,0,0,0)",
          bgcolor    = "rgba(0,0,0,0)"
        ),
        margin = list(l = 0, r = 0, t = 0, b = 0),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)"
      )
  })
}

# ==========================RUN APP===============================
shinyApp(ui = ui, server = server)
