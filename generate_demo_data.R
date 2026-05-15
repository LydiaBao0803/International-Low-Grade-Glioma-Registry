# ============================================================
# generate_demo_data.R
# Run this script ONCE from the LYDIA_BAO_Final/ directory to
# create the synthetic demo dataset used for public deployment.
#
# Usage (in R console):
#   source("generate_demo_data.R")
#
# Output: Glioma_BIS679A_2025_demo.xlsx  (in the same folder)
# ============================================================

# Install writexl if needed
if (!requireNamespace("writexl", quietly = TRUE)) {
  install.packages("writexl")
}
library(writexl)

set.seed(42)

n <- 480   # synthetic participants

# ---- ZIP code pools ----
us_zips <- c(
  rep(c("06510","06511","06516","06902","06830"), 5),       # CT
  rep(c("10001","10022","10065","11201","14202","14850"), 5),# NY
  rep(c("02115","02116","02134","01701","02062"), 5),        # MA
  rep(c("90210","94102","94115","90027","94305","95814"), 5),# CA
  rep(c("77002","77030","78201","75201","78712"), 5),        # TX
  rep(c("33101","33139","32601","33612","32801"), 5),        # FL
  rep(c("60601","60611","60614","60637","62701"), 4),        # IL
  rep(c("19104","19103","15213","17601"), 3),                # PA
  rep(c("44106","44195","98101","98195","27514","30308",
        "48109","80203","55414","85004","37232","22903",
        "21201","63110","53706","97201","07030","46202",
        "40536","70112","29208","84112","52242","66045"), 2) # other states
)

intl_codes <- c(
  "M5S 2C6", "V6T 1Z4", "T6G 2R3",
  "SW7 2AZ", "EC1A 1BB", "OX1 2JD",
  "10117",   "80539",   "69120",
  "2006",    "3010",    "4000",
  "75005",   "69001",   "13001"
)

# ---- Diagnosis pool: weighted toward oligo (3), astro (1), mixed (2) ----
diag_pool <- c(rep(1, 28), rep(2, 15), rep(3, 32),
               rep(4,  5), rep(5,  7), rep(6,  3),
               rep(7,  2), rep(8,  4), rep(9,  2),
               rep(10, 1), rep(11, 1), rep(NA_real_, 8))

# ---- Enrollment year weights ----
yr_seq  <- 2000:2025
yr_wts  <- c(1,2,2,3,4,5,6,7,8,9,11,12,14,15,16,18,18,20,20,22,18,20,22,24,25,15)

enroll_years <- sample(yr_seq, n, replace = TRUE, prob = yr_wts)

# ---- Build data frame row by row ----
dob_col    <- vector("list", n)
zip_col    <- character(n)
diag_col   <- numeric(n)
enroll_col <- vector("list", n)

for (i in seq_len(n)) {
  yr <- enroll_years[i]
  mo <- sample(1:12, 1)
  dy <- sample(1:28, 1)
  if (yr == 2025) mo <- sample(1:11, 1)   # keep ≤ Dec 2025
  enroll_date <- as.Date(sprintf("%d-%02d-%02d", yr, mo, dy))

  # Age ~Normal(45,13), truncated [18, 80]
  age <- -1L
  while (age < 18 || age > 80) age <- round(rnorm(1, 45, 13))

  dob <- as.Date(
    sprintf("%d-%02d-%02d", yr - age, sample(1:12, 1), sample(1:28, 1))
  )

  zip  <- if (runif(1) < 0.85) sample(us_zips, 1) else sample(intl_codes, 1)
  diag <- sample(diag_pool, 1)

  dob_col[[i]]    <- dob
  zip_col[i]      <- zip
  diag_col[i]     <- diag
  enroll_col[[i]] <- enroll_date
}

demo_df <- data.frame(
  `Date of Birth (MM/DD/YYYY)` = as.Date(unlist(dob_col),    origin = "1970-01-01"),
  `Zip Code`                   = zip_col,
  `Pathology (1=astrocytoma, 2=mixed, 3=oligodendroglioma, 4=gbm, 5=glioma nos, 6=meningioma, 7=DNET, 8=pilocytic astrocytoma, 9=ependymoma, 10=lymphoma, 11=ganglioglioma, 12=hypercellular)` = diag_col,
  `Date of Enrollment`         = as.Date(unlist(enroll_col), origin = "1970-01-01"),
  check.names      = FALSE,
  stringsAsFactors = FALSE
)

# Sort chronologically
demo_df <- demo_df[order(demo_df$`Date of Enrollment`), ]
rownames(demo_df) <- NULL

# Write — writexl preserves Date class as Excel date cells
out_file <- "Glioma_BIS679A_2025_demo.xlsx"
write_xlsx(demo_df, out_file)

cat(sprintf("Done: %s written (%d rows, no real patient data)\n", out_file, nrow(demo_df)))
