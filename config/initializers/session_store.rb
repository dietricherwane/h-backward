# Be sure to restart your server when you modify this file.

HubsBackOffice::Application.config.session_store :active_record_store#:cookie_store, key: '_HubsBackOffice_session'

ActiveRecord::SessionStore::Session.attr_accessible :data, :session_id
