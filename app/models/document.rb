class Document < ApplicationRecord
  has_many :document_chunks, dependent: :destroy

  validates :filename, presence: true
  validates :content, presence: true
end