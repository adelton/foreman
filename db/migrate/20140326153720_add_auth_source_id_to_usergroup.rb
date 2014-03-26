class AddAuthSourceIdToUsergroup < ActiveRecord::Migration
  def change
    add_column :usergroups, :auth_source_id, :integer, :null => true
  end
end
