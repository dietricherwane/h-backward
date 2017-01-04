class AddSalesAreaAndUrlOnSuccessAndUrlOnErrorAndUrlOnSessionExpiredAndUrlOnHoldSuccessAndUrlOnHoldErrorAndUrlOnHoldListenerAndAuthenticationTokenToServices < ActiveRecord::Migration
  def change
    add_column :services, :sales_area, :string
    add_column :services, :url_on_success, :string
    add_column :services, :url_on_error, :string
    add_column :services, :url_on_session_expired, :string
    add_column :services, :url_on_hold_success, :string
    add_column :services, :url_on_hold_error, :string
    add_column :services, :url_on_hold_listener, :string
    add_column :services, :authentication_token, :string
  end
end
