# Load the packages we need for spatial work and joins
library(sf)       # handles spatial objects
library(dplyr)    # for joining & data wrangling
library(readr)    # fast CSV import

# Read in the cleaned 311 CSV you made earlier
rat_clean <- read_csv("data/311_clean.csv")
