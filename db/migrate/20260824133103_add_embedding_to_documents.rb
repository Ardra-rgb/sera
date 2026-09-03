class AddEmbeddingToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :embedding, :text
  end
end
