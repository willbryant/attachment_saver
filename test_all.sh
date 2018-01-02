#!/bin/sh

set -e

for version in 4.2.10 5.0.6 5.1.4 5.2.0.beta2
do
	RAILS_VERSION=$version bundle update activerecord
	bundle exec rake
done