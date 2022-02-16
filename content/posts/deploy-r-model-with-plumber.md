---
title: "Deploying R Models As A Service"
subtitle: Turning Your Machine Learning Models Into Products
date: 2020-06-13T22:18:10-07:00
draft: false
---

### R Excels at Rapid Development

The R programming language has cultivated an ecosystem of statistics and data science tools that democratize access to machine learning. It's easier than ever to conduct data exploration, analysis and train machine learning models: packages like `glmnet`, `dplyr` (and the `tidyverse`), and `xgboost` offer incredibly accessible APIs to build valuable data processing pipelines.

But when the time comes to deliver your model to the masses, how will you do it? I recently had need to prototype a system built around a `glmnet` model. As a software engineer first (and a machine learning enthusiast second), I wanted to approach this problem like I would any other.

### Deployment Options

So you've built a model in R, now you want to build a product around predictions from that model. Let's talk about the usual suspects:

- Embed the model in the product
- Serve the predictions as an API

Embedding the model either requires the product to be based on the R runtime, or you are looking at serializing the model and wrapping it in your language runtime of choice, probably using [PMML](https://en.wikipedia.org/wiki/Predictive_Model_Markup_Language) (but we'll have to save that for another post).

For my specific project, serving the predictions via an API provided the most value. In this way, prediction inputs are received by a server and we can build that server in R, maintaining access to our entire ecosystem of R libraries we love to use.

### Plumber

Serving the model over the network means we want to run an http server from an R session. The R ecosystem doesn't quite have the myriad web frameworks of Python or Java for instance, but it does have a promising option in [plumber](https://www.rplumber.io/). 

So let's say we have a simple model trained on the `mtcars` dataset. 3 covariates: cylinders, displacement, and horsepower are used to predict MPG.

```r
# train.R
library(glmnet)
# data processing
model = glmnet(x, y)
saveRDS(model, 'my-mpg-model.Rds')
```

We can create a prediction API with plumber like so:

```r
# api.R
library(plumber)
library(jsonlite)
library(glmnet)

# load the model
model = readRDS("my-mpg-model.Rds")

#* Predict MPG
#* @post /predict
function (req) {
  json = jsonlite::fromJSON(req$postBody)
  cyl = json$cyl
  disp = json$disp
  hp = json$hp
  mpg = predict(model, rbind(c(cyl, disp, hp)), s=0.5)[1]
  list(mpg=mpg)
}
```

This accepts a POST request to `/predict` and reads the json body with the following structure: 

```r
{ 
  "cyl": 6,
  "disp": 130,
  "hp": 115
}
```

It runs `glmnet::predict` on our model, and returns the results as json. We call the route like so:

```bash
curl -X POST "http://127.0.0.1:8000/predict" -H  "accept: application/json" --data '{"disp": 200, "cyl": 8, "hp": 245}'

{
	"mpg": [20.55566]
}
```

### Dockerize

My favorite way to deploy applications is [docker](https://www.docker.com/). Let's see how we can dockerize this API.

Luckily, the plumber author provides a [base docker image](https://www.rplumber.io/docs/hosting.html) we can use.

Our dockerfile is actually very simple. We just install the packages we need, and add our API definition source file. Plumber takes care of the rest.

```dockerfile
FROM trestletech/plumber

RUN R -e "install.packages('glmnet')"
RUN R -e "install.packages('jsonlite')"

WORKDIR /opt/api

COPY ./api.R .

CMD ["/opt/api/api.R"]
```

The docker container starts the server at port 8000. It's that simple!

### Next Steps

So now you've got a prediction API, built into a docker image that you can deploy however you like -- my personal favorite is [DigitalOcean](https://m.do.co/c/f5e9f6a309a8) (referral link).

Of course, the application isn't quite complete without something _consuming_ the API. But we've built an API that let's us build that consumer however we'd like -- as long as it can talk HTTP.
