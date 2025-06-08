// stan/qhcr_model.stan
// -----------------------------------------------------------------------------
// Hierarchical Poisson model for quarterly rat counts by Community District
// Implements a simple QHCR proxy: each district’s abundance \n// follows a common Gamma prior, and counts are Poisson-distributed.
// Data:
//   D    = number of districts
//   T    = number of quarterly occasions
//   y[d,t] = observed count for district d in quarter t
// -----------------------------------------------------------------------------
data {
  int<lower=1> D;            // number of spatial units (Community Districts)
  int<lower=1> T;            // number of capture occasions (quarters)
  int<lower=0> y[D, T];      // observed counts per district and quarter
}
parameters {
  real<lower=0> alpha;       // shape hyperparameter for abundance prior
  real<lower=0> beta;        // rate hyperparameter for abundance prior
  vector<lower=0>[D] lambda; // true abundance per district (mean rats per quarter)
}
model {
  // Hyperpriors on abundance distribution
  alpha ~ gamma(0.01, 0.01);
  beta  ~ gamma(0.01, 0.01);

  // Prior on district-level abundance
  lambda ~ gamma(alpha, beta);

  // Likelihood: counts are Poisson given true abundance
  for (d in 1:D)
    for (t in 1:T)
      y[d, t] ~ poisson(lambda[d]);
}
generated quantities {
  vector[D] log_lambda;
  for (d in 1:D)
    log_lambda[d] = log(lambda[d]);
}
