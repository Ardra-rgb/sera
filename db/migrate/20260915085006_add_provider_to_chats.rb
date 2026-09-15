class AddProviderToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :provider, :string
  end
end
