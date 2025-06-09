// stan/qhcr_model_upgraded.stan
// -----------------------------------------------------------------------------
// Hierarchical Neg-Binomial with quarter effects and AR(1) autocorrelation
// Data: D districts × T quarters
// ----------------------------------------------------------------------------- 
data {
  int<lower=1> D;
  int<lower=1> T;
  int<lower=0> y[D, T];
}
parameters {
  // Hyper-priors
  real<lower=0> alpha;          // shape of Gamma prior
  real<lower=0> beta;           // rate of Gamma prior

  // District abundance (non-centred)
  vector<lower=0>[D] lambda_raw;

  // Quarter effects (AR-1)
  vector[T] delta_raw;
  real<lower=-1,upper=1> rho;   // AR(1) coefficient
  real<lower=0> sigma_delta;    // SD of innovations

  // Over-dispersion for Neg-Bin
  real<lower=0> phi;
}
transformed parameters {
  vector<lower=0>[D] lambda = lambda_raw ./ beta;   // rescale
  vector[T] delta;                                  // quarter effect

  // AR(1) recursion
  delta[1] = delta_raw[1] * sigma_delta / sqrt(1 - square(rho));
  for (t in 2:T)
    delta[t] = rho * delta[t - 1] + delta_raw[t] * sigma_delta;
}
model {
  // Weakly-informative hyperpriors
  alpha ~ exponential(1);
  beta  ~ exponential(1);

  // Non-centred abundance prior
  lambda_raw ~ gamma(alpha, 1);

  // AR(1) components
  delta_raw ~ normal(0, 1);
  rho ~ uniform(-1, 1);
  sigma_delta ~ exponential(1);

  // Over-dispersion prior
  phi ~ exponential(1);

  // Likelihood
  for (d in 1:D)
    for (t in 1:T)
      y[d, t] ~ neg_binomial_2(lambda[d] * exp(delta[t]), phi);
}
generated quantities {
  vector[D] log_lambda = log(lambda);      // for mapping
}
