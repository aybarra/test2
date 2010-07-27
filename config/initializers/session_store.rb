# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_test2_session',
  :secret      => '2b78cc86c1ec9cdad94f66bf76d88de5e207a57b7060e9217efbca60fff02dd9ecc6f1c66e56cebb9741bb26cd4301ee8dd5f4f85a4883698b5fffb637cae2f1'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
