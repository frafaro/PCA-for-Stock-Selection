#### 1. DATA PREP AND LOADING ####
library(readxl)
library(tidyverse)
library(psych)
library(ggrepel)
library(corrplot)

# DATASET: HEALTHCARE_PCA.xlsx
#
# rows: companies belonging to the health sector in SP500
# columns: balance sheet indicators and multiples for each company
health_raw <- read_excel("HEALTHCARE_PCA.xlsx", sheet = "Sheet5")

# descriptive columns
# created for later plots
meta_cols <- c("Ticker", "Company") 

# NA values are transformed in the mean of the respective column in a new table
health_clean <- health_raw %>%
  mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))

#### 2. CORRELATION MATRIX ####
cor_matrix <- health_clean %>% 
  select(where(is.numeric)) %>% # is.numeric is used to identify numeric obs so we dont have to exclude the 
  cor()                         # descriptive variables every time

corrplot(cor_matrix, method = "circle", tl.col = "black", tl.srt = 90)
# the output is very informative as we can see different group of correlated variables
# in particular we can distinguish within these 3 groups
#
# 1. valuation multiples
# 2. performance indicator
# 3. liquidity indicators
#
# IMPORTANT: gross margin and roe doesnt have strong correlation with any of the variables
# for this reason they are excluded from the PCA

#### 3. PCA MODEL ####

# we create a new dataset with only numeric variables without gross margin and roe
financial_data <- health_clean %>% 
  select(where(is.numeric), -`Gross M`, -ROE)

# we perform the PCA
# 
# nfactors = 3 since from corrplot it was already possible to distinguish within 3 subgroups
# this corresponds to the number of components to extract
# rotate = "varimax" is a way to transform the solution in order to maximizes the variance between the PC.
fit_3factors <- principal(financial_data, nfactors = 3, rotate = "varimax", scores = TRUE)

# OUTPUT
print(fit_3factors$loadings, cut = 0.3)
# the first 3 rotate components explain 84.1% of the variability in the dataset
# it is possible to observe the weight of the loadings over the 3 RCs, in particular as we 
# hypothesised with the corrplot output we have:
#
# valuation multiples: high positive correlation over RC1 (it means that we need to search for small values over RC1 to find low mutiple valuations)
# permormance indicators: positive correlation over RC2 
# liquidity indicators: higly positive correlation over RC3


#### 4. SCORES DATASET ####
#
# we extract the scorings in order to be able to plot them and identify the subgroups
# with the strongest financial indicators together with low valuation multiples

df_scores <- as.data.frame(fit_3factors$scores) %>%
  bind_cols(health_clean %>% select(all_of(meta_cols)))

# renaming the 3 RCs based on their interpretation
df_scores <- df_scores %>% 
  rename(
    Valuation = RC1, 
    Profitability = RC2,
    Solvency = RC3
  )

#### 5. FINAL STOCK SCREENING ####
#
# - Profitability > 0
# - Solvency > 0
# - Valuation < 0 
#
# instead of splitting the stocks using 0 as benchmark
# it is also useful to create a list with order by 
# then selecting the first 10/15 best stock from the list and analyze them based on valuation
#
# However if we want to find cheap stocks this approach is correct 

target_companies <- df_scores %>%
  filter(Profitability > 0, Solvency > 0, Valuation < 0)

print("Selected Companies")
print(target_companies %>% select(Ticker, Company, Profitability, Solvency, Valuation))

#### 6. PLOT THE RESULTS (ggrepel) ####
#
# profitability vs solvency

ggplot(df_scores, aes(x = Profitability, y = Solvency)) +
  geom_point(aes(color = Valuation), size = 3) +
  scale_color_gradient2(low = "green", mid = "gray", high = "red", midpoint = 0, name = "Valuation Score") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "darkgray") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "darkgray") +
  geom_text_repel(aes(label = Ticker), max.overlaps = 15, size = 3.5) +
  labs(
    title = "Quality screening: Profitability vs Solvency",
    subtitle = "Green = Low multiples (cheap), Red = High multiples (Expensive)",
    x = "Profitability (Score)",
    y = "Solvency (Score)"
  ) +
  theme_minimal()
# INTERPRETATION
#
# Upper right square: best companies high profitability and high solvency
# within that group the green dots represents cheap companies
# Lower left square: worse companies