class AddSessionToAnalysis < ActiveRecord::Migration
  def self.up
     add_column :analyses, :session_id, :string
  end

  def self.down
    remove_column :analyses, :session_id
  end
end
