# Purpose: Install and verify the full Stan toolchain (CmdStanR + Rtools) on Windows.
# This script ensures you can compile and run Stan models from R.

# 1) Install the cmdstanr R package if it's not already present.
#    - requireNamespace() checks for the package without loading it.
#    - install.packages() fetches from the Stan-maintained CRAN-like repository.
if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  install.packages(
    "cmdstanr",
    repos = c("https://mc-stan.org/r-packages/", getOption("repos"))
  )
} else {
  # Informative message if cmdstanr is already installed
  message("✔ cmdstanr package already installed, loading it now...")
}

# 2) Load the cmdstanr package into the current R session.
#    This makes the functions cmdstan_model(), install_cmdstan(), etc. available.
library(cmdstanr)

# 3) Verify your C++ compiler (Rtools) and Make are accessible to R.
#    - check_cmdstan_toolchain(fix = TRUE) will attempt to configure missing tools.
#    - After this, you should see green check marks for all requirements.
cmdstanr::check_cmdstan_toolchain(fix = TRUE)

# 4) Install CmdStan itself (the underlying C++ codebase).
#    - Downloads & compiles CmdStan (~1 GB). Safe to re-run: overwrite = FALSE skips if installed.
#    - Compiling may take several minutes, depending on your system.
cmdstanr::install_cmdstan(overwrite = FALSE)

# 5) Compile the built-in Bernoulli example model
#    - Locate the .stan file within the CmdStan installation using cmdstan_path().
#    - cmdstan_model() will compile it into an executable binary if needed.
stan_file <- file.path(
  cmdstanr::cmdstan_path(),
  "examples", "bernoulli", "bernoulli.stan"
)
mod <- cmdstanr::cmdstan_model(stan_file)
message("✅ Compiled Bernoulli example to: ", mod$exe_file())

# 6) Run a tiny sample to confirm the full pipeline works
#    - Define a minimal data list matching the model's 'data' block.
#    - seed = 123 ensures reproducibility of the MCMC run.
#    - refresh = 0 suppresses progress output for a cleaner console.
data_list <- list(
  N = 8,
  y = c(1, 0, 1, 1, 0, 0, 1, 0)
)
fit <- mod$sample(
  data    = data_list,
  seed    = 123,
  refresh = 0
)

# 7) Inspect and display the results
#    - fit$summary() returns a data frame of posterior summaries.
#    - We focus on 'theta', the Bernoulli success probability.
message("Posterior summary for 'theta':")
print(fit$summary(variables = "theta"))

# 8) (Optional) Clean up the compiled executable
#    - Removes the binary file to save disk space in your project.
file.remove(mod$exe_file())
message("🧹 Cleaned up the Bernoulli executable.")
