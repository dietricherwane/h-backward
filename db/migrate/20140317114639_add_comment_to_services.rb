class AddCommentToServices < ActiveRecord::Migration
  def change
    add_column :services, :comment, :string
  end
end
