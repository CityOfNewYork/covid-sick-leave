#!/bin/bash
rm -rf vendor
gem install bundler:1.17.3
bundle update --bundler
bundle install --no-deployment
bundle install --deployment