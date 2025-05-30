# 000_setup_cmdstanr.R
#
# This script gets **CmdStanR** up and running on Windows so you can compile
# and run Stan models from R.
#
# What happens, step by step:
#   1. Install the *R package* **cmdstanr** (one-time).
#   2. Make sure R can find a C++ compiler (comes with RTools).
#   3. Download & build the CmdStan C++ source (only first time; ~1 GB).
#   4. Compile the tiny built-in Bernoulli example model.
#   5. Run a quick 8-data-point MCMC sample to prove everything works.
#
# Re-running is safe: most steps notice they’re already done and skip.
# -----------------------------------------------------------------------------

# 1) Install cmdstanr if it’s missing ------------------------------------------
if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  install.packages(
    "cmdstanr",
    repos = c("https://mc-stan.org/r-packages/", getOption("repos"))
  )
} else {
  message("cmdstanr already installed — nice!")
}

# 2) Load the package so we can call its helpers --------------------------------
library(cmdstanr)

# 3) Check that the C++ toolchain (gcc/make) is visible to R --------------------
#    `fix = TRUE` tries to patch common PATH problems for you.
cmdstanr::check_cmdstan_toolchain(fix = TRUE)

# 4) Download + build CmdStan itself -------------------------------------------
#    `overwrite = FALSE` means “skip if the same version is already built”.
cmdstanr::install_cmdstan(overwrite = FALSE)

# 5) Compile the built-in Bernoulli model --------------------------------------
stan_file <- file.path(
  cmdstanr::cmdstan_path(),
  "examples", "bernoulli", "bernoulli.stan"
)
mod <- cmdstanr::cmdstan_model(stan_file)
message("Compiled Bernoulli model to: ", mod$exe_file())

# 6) Run a super-small sample (takes a few seconds) ----------------------------
data_list <- list(
  N = 8,
  y = c(1, 0, 1, 1, 0, 0, 1, 0)
)
fit <- mod$sample(
  data    = data_list,
  seed    = 123,   # reproducible each run
  refresh = 0      # keep console output minimal
)

# 7) Print the summary for the only parameter, `theta` -------------------------
message("Posterior summary for 'theta':")
print(fit$summary(variables = "theta"))

# 8) (Optional) Delete the compiled executable ----------------------------------
#    Comment this out if you’d rather keep it and skip recompilation later.
file.remove(mod$exe_file())
message("Deleted the Bernoulli executable.")