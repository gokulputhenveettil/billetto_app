# config/initializers/clerk.rb
require "clerk"

publishable_key = ENV["CLERK_PUBLISHABLE_KEY"]
secret_key = ENV["CLERK_SECRET_KEY"]

if Rails.env.test?
  publishable_key ||= "pk_test_ZXhhbXBsZS5jb20k"
  secret_key ||= "sk_test_dummy"
end

Clerk.configure do |config|
  config.publishable_key = publishable_key
  config.secret_key = secret_key
end
