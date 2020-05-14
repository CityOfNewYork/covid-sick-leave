# # COVID Paid Leave - Backend

Digital form process for COVID isolation and quartine order forms

## Access tokens and keys

Create .env file, and copy contents of .env.sample. Required keys can be set as follow:

Database: see Keypass file on share drive
Google sheet: see "authorize" function in src/clients/sheets.rb, or obtain from team member
FORMSTACK_HMAC_KEY: obtain from team member
DOCUMENT_PASSWORD: make it something complex that won't be guessed by people receiving the documents (13+ characters incl. numbers and special characters)

## Architecture

Code is hosted on AWS lambda/API Gateway. It is triggered via [FormStack](https://www.formstack.com) webhook.

## To Build Docker Env

We build native and gem dependencies in a docker container that closely mirrors the AWS lambda environment to align dependency behavior.

the -v flag tells docker to place files from our local environment into docker container.
the --rm flag tells docker to remove the container the container it creates on 'run'

```
docker build . -t covid-paid-leave
docker run --rm -v $(pwd):/var/task -t covid-paid-leave:latest bash scripts/vendor.sh
```

Once the container is built and dependencies installed, you can do the following:

### Deploy:
```
    docker run --rm -v $(pwd):/var/task -t covid-paid-leave:latest bash scripts/zip.sh
    # should produce a local deploy.zip file
    # upload that file to lambda to LATEST ALIAS
    # test LATEST, publish new version, and point production to that version
```


## About NYCO

NYC Opportunity is the [New York City Mayor's Office for Economic Opportunity](http://nyc.gov/opportunity). We are committed to sharing open source software that we use in our products. Feel free to ask questions and share feedback. Follow @nycopportunity on [Github](https://github.com/orgs/CityOfNewYork/teams/nycopportunity), [Twitter](https://twitter.com/nycopportunity), [Facebook](https://www.facebook.com/NYCOpportunity/), and [Instagram](https://www.instagram.com/nycopportunity/).
