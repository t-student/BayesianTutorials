#Author: Arman Oganisian

library(LaplacesDemon)
library(invgamma)
library(MASS)
library(profvis)

################################################################################
### 0 - Simulate Data 
################################################################################
set.seed(10)
N<-1000

d<-data.frame(age_group=sample(x = c(0,1,2), size = N, replace = T))
d$age_1<-ifelse(d$age_group==1,1,0)
d$age_2<-ifelse(d$age_group==2,1,0)

d$trt<-rbinom(n = N, size = 1,prob = invlogit(0 + 2*d$age_1 + - 2*d$age_2))

d$y<-rbinom(n = N, size = 1,
            prob = invlogit(-1 + .7*d$age_1 + 1.1*d$age_2 + 1.1*d$trt))

X<-as.matrix(cbind(1,d[,2:4])) # model matrix
Y<-matrix(d$y, ncol=1) # outcome vector

p<-ncol(X)

################################################################################
### 1 - functions to sample from conditional posterior distributions
################################################################################

# unnormalized log posterior of beta vector
log_posterior<-function(beta, X, Y){

    # calculate likelihood
  xb <- X %*% beta
  xb <- ifelse(xb>10, 10, ifelse( xb< (-10) ,-10, xb))
  p_i <- invlogit(xb)
  
  lik <- sum(dbern(Y, p_i, log = T))
  
  # calculate prior 
  pr <- dnorm(x = beta, mean = 0, sd = 1000, log = T)
  
  log_cond_post <- lik + pr
  return(log_cond_post)
}

# use Metropolis Hastings algorithm to sample from cond. post. of beta
sample_mh<-function(X, Y, iter, jump_v){
  
  # create shells
  p <- ncol(X)
  beta_shell <- matrix(NA, nrow = iter, ncol = p)
  accept_shell <- numeric(length = iter)
  
  # starting values
  beta_shell[1,] <- rep(10, p)
  
  for(i in 2:iter){
    beta_0 <- beta_shell[i-1, ]
    
    # draw from proposal distribution
    beta_c <- mvrnorm(n = 1, beta_0, Sigma = jump_v*diag(p))
    
    # calculate ratio of conditional posterior densities
    r_num <- log_posterior(beta_c, X, Y )
    r_denom <- log_posterior(beta_0, X, Y )
    
    # calculate acceptance probability
    r <- exp(r_num - r_denom)
    rmin<-min(r,1)
    
    # accept or reject proposal
    if( rbinom(1,1,rmin) == 1 ){ 
      beta_shell[i, ] <- beta_c
    }else{
      beta_shell[i, ] <- beta_0
    }
    accept_shell[i] <- rmin
    
  }
  
  return(list(beta_shell, accept_shell) )
}

# Adaptive Metropolis Hastings
sample_amh<-function(X, Y, iter, jump_v, 
                              ad_start, ad_stop, ad_int, ad_period){
  
  # create shells
  p <- ncol(X)
  beta_shell <- matrix(NA, nrow = iter, ncol = p)
  accept_shell <- numeric(length = iter)
  
  # starting values
  beta_shell[1,] <- rep(10, p)
  
  s <- 1
  
  for(i in 2:iter){
    beta_0 <- beta_shell[i-1, ]
    
    if(i >= ad_start & i <= ad_stop ){
      accept_rate <- mean(accept_shell[  (i - ad_period):i ])
      s <- s * (accept_rate/.234) # optimal acceptance rate
      jump_v <- s * cov(beta_shell[ (i - ad_period):(i-1) , ])
    }
    # draw from proposal distribution
    beta_c <- mvrnorm(n = 1, beta_0, Sigma = jump_v )
    
    # calculate ratio of conditional posterior densities
    r_num <- log_posterior(beta_c, X, Y )
    r_denom <- log_posterior(beta_0, X, Y )
    
    # calculate acceptance probability
    r <- exp(r_num - r_denom)
    rmin<-min(r,1)
    
    # accept or reject proposal
    if( rbinom(1,1,rmin) == 1 ){ 
      beta_shell[i, ] <- beta_c
    }else{
      beta_shell[i, ] <- beta_0
    }
    accept_shell[i] <- rmin
    
  }
  
  return(list(beta_shell, accept_shell) )
}


################################################################################
### 2 - Run Sampler
################################################################################
iter <- 10000
p <- ncol(X)

res <- sample_mh(X, Y, iter = iter, jump_v = .01)
gibbs_res <- res[[1]]
plot(cumsum(res[[2]])/1:iter, type='l')


res <- sample_amh(X, Y, iter = iter, jump_v = diag(p), 
                  ad_start = 102, ad_stop = 500, ad_int = 100, ad_period = 100)
gibbs_res <- res[[1]]
plot(cumsum(res[[2]])/1:iter, type='l')


################################################################################
### 3 - Plot Results
################################################################################

par(mfrow=c(2,2))
plot(gibbs_res[,1],type='l',xlab='MCMC Iterations',ylab=c('Coefficient Draw'),
     main='Intercept')
abline(h=-1,col='red')
plot(gibbs_res[,2],type='l',xlab='MCMC Iterations',ylab=c('Coefficient Draw'),
     main='Age1')
abline(h=.7,col='red')
plot(gibbs_res[,3],type='l',xlab='MCMC Iterations',ylab=c('Coefficient Draw'),
     main='Age2')
abline(h=1.1,col='red')
plot(gibbs_res[,4],type='l',xlab='MCMC Iterations',ylab=c('Coefficient Draw'),
     main='Treatment')
abline(h=1.1,col='red')

