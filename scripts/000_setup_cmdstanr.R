# ───────────────────────────────────────────────────────────
# Script: 000_setup_cmdstanr.R
# Purpose: Install and verify CmdStanR tooling on Windows
# Inputs:  None
# Outputs: Compiled Bernoulli example model; MCMC fit on toy data
# Depends: cmdstanr (R package), RTools (C++ compiler)
# ───────────────────────────────────────────────────────────

# 1. Install CmdStanR package if missing
if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  install.packages(
    "cmdstanr",
    repos = c("https://mc-stan.org/r-packages/", getOption("repos"))
  )
} else {
  message("cmdstanr already installed — skipping install.")
}

# 2. Load CmdStanR so we can use its helper functions
library(cmdstanr)

# 3. Ensure a working C++ toolchain is visible to R (attempt fixes if needed)
cmdstanr::check_cmdstan_toolchain(fix = TRUE)

# 4. Download and build the CmdStan C++ source (skip if already built)
cmdstanr::install_cmdstan(overwrite = FALSE)

# 5. Compile the built-in Bernoulli example model as a sanity check
stan_file <- file.path(cmdstanr::cmdstan_path(), "examples", "bernoulli", "bernoulli.stan")
mod <- cmdstanr::cmdstan_model(stan_file)
message("CmdStan model compiled to: ", mod$exe_file())

# 6. Run a brief MCMC sample on the example model
data_list <- list(N = 8, y = c(1,0,1,1,0,0,1,0))
fit <- mod$sample(data = data_list, seed = 123, refresh = 0)

# 7. Print posterior summary for the only parameter, theta
message("Posterior summary for 'theta':")
print(fit$summary(variables = "theta"))

# 8. (Optional) Remove the compiled executable to save space
file.remove(mod$exe_file())
message("Deleted example executable.")
